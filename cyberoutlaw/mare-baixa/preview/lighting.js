import * as THREE from 'three';
import { enumName, facePlacement, rgb } from './geometry.js';

const horizon = new THREE.Color(0x372a43);
const moonDirection = new THREE.Vector3(-0.64, 0.58, 0.50).normalize();
const bakedHeights = [0, 12, 38, 108];

export function makeUniforms() {
    return {
        cityLightingAtlas: { value: null },
        cityLightBounds: { value: new THREE.Vector4() },
        cityLightTexel: { value: new THREE.Vector2() },
        cityLightFloor: { value: 0 },
        cityReflectionMap: { value: null },
        cityReflectionMatrix: { value: new THREE.Matrix4() },
        cityReflectionHeight: { value: 0 },
        cityReflectionReady: { value: false },
        cityStreetMirrorMap: { value: null },
        cityStreetMirrorMatrix: { value: new THREE.Matrix4() },
        cityStreetMirrorHeight: { value: 0 },
        cityStreetMirrorReady: { value: false },
    };
}

const skyVertex = /* glsl */`
    varying vec3 skyDirection;

    void main() {
        skyDirection = position;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
`;

const skyFragment = /* glsl */`
    uniform vec3 skyHorizon;
    uniform vec3 skyZenith;
    uniform vec3 skyNadir;
    uniform vec3 skyWarmth;
    uniform vec3 skyMoon;
    uniform vec3 skyMoonDirection;
    uniform bool envLighting;
    varying vec3 skyDirection;

    float hash(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
    }

    float noise(vec2 p) {
        vec2 cell = floor(p);
        vec2 f = fract(p);
        vec2 t = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash(cell), hash(cell + vec2(1, 0)), t.x),
                   mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), t.x), t.y);
    }

    void main() {
        vec3 direction = normalize(skyDirection);
        float elevation = direction.y;
        float zenithBlend = pow(clamp(elevation, 0.0, 1.0), 0.63);
        vec3 color = mix(skyHorizon.rgb, skyZenith.rgb, zenithBlend);
        color = mix(color, skyNadir, smoothstep(0.015, 0.6, -elevation));
        float warmHorizon = max(dot(direction, normalize(vec3(0.74, 0.07, -0.66))), 0.0);
        color += skyWarmth * pow(warmHorizon, 3.5) * exp(-9.5 * abs(elevation));
        float moon = max(dot(direction, skyMoonDirection), 0.0);
        if (envLighting) {
            color = color * 2.45 + skyMoon * pow(moon, 24.0) * 1.65;
        } else {
            vec2 cloudPlane = direction.xz / (0.26 + max(elevation, 0.0));
            vec2 p = cloudPlane * vec2(3.2, 6.0) + vec2(14.0, 3.0);
            float section = noise(p) * 0.62 + noise(p * 2.14) * 0.24 + noise(p * 4.19) * 0.14;
            float density = smoothstep(0.47, 0.76, section) * smoothstep(-0.02, 0.19, elevation);
            color *= mix(1.0, 0.71, density * (1.04 - zenithBlend * 0.36));
            color += skyMoon * (pow(moon, 86.0) * 0.026 + smoothstep(0.99992, 0.99998, moon) * 0.56);
        }
        gl_FragColor = vec4(color, 1.0);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
    }
`;

function backgroundSphere(radius, environment = false) {
    const material = new THREE.ShaderMaterial({
        uniforms: {
            skyHorizon: { value: horizon },
            skyZenith: { value: new THREE.Color(0x0b132e) },
            skyNadir: { value: new THREE.Color(0x171320) },
            skyWarmth: { value: new THREE.Color(0x3a1826) },
            skyMoon: { value: new THREE.Color(0xadc5fc) },
            skyMoonDirection: { value: moonDirection },
            envLighting: { value: environment },
        },
        vertexShader: skyVertex,
        fragmentShader: skyFragment,
        side: THREE.BackSide,
        depthWrite: false,
    });
    const mesh = new THREE.Mesh(new THREE.SphereGeometry(radius, 24, 14), material);
    mesh.frustumCulled = false;
    mesh.renderOrder = -100;
    return mesh;
}

function exportedLights(parts, lights) {
    const sources = [];
    const attached = new Set();
    for (const light of lights) {
        const part = parts[light.part - 1];
        if (!part || !(light.range > 0) || !(light.brightness > 0)) continue;
        const face = facePlacement(part, light.face);
        const point = face?.point.addScaledVector(face.direction, 0.11) ?? new THREE.Vector3(...part.cf.slice(0, 3));
        sources.push({
            point,
            direction: face?.direction,
            color: rgb(light.color ?? [1, 1, 1]),
            range: light.range,
            brightness: light.brightness,
        });
        attached.add(light.part - 1);
    }
    return { sources, attached };
}

function emissiveBounce(parts, attached, floor) {
    const strongest = new Map();
    for (let index = 0; index < parts.length; index += 1) {
        const part = parts[index];
        if (attached.has(index) || enumName(part.material) !== 'neon' || part.transparency >= 0.995) continue;
        const [x, y, z] = part.cf;
        if (y - floor > 29) continue;
        const [first, second] = part.size.toSorted((a, b) => b - a);
        const area = first * second;
        if (area < 4.5) continue;
        const color = rgb(part.color ?? [1, 1, 1]);
        const key = `${Math.floor(x / 24)}/${Math.floor(z / 24)}`;
        const strength = area * Math.max(color.r, color.g, color.b);
        if ((strongest.get(key)?.strength ?? 0) >= strength) continue;
        strongest.set(key, {
            strength,
            color,
            point: new THREE.Vector3(x, y, z),
            range: THREE.MathUtils.clamp(Math.sqrt(area) * 1.5, 9, 24),
            brightness: THREE.MathUtils.clamp(Math.sqrt(area) * 0.05, 0.13, 0.48),
        });
    }
    return [...strongest.values()];
}

function cityFloor(parts, bounds) {
    let area = 0;
    let floor = bounds.min.y;
    for (const part of parts) {
        if (!['asphalt', 'sidewalk', 'pavement'].includes(enumName(part.material))) continue;
        const [x, y, z] = part.size;
        if (part.transparency >= 0.995 || part.cf[7] < 0.95 || x * z < area || y > Math.min(x, z) * 0.15) continue;
        area = x * z;
        floor = part.cf[1] + y / 2;
    }
    return floor;
}

function bakeLightField(uniforms, sources, bounds, floor) {
    const size = bounds.getSize(new THREE.Vector3());
    const width = size.x + 70;
    const depth = size.z + 70;
    const originX = bounds.min.x - 35;
    const originZ = bounds.min.z - 35;
    const resolution = THREE.MathUtils.clamp(Math.ceil(Math.max(width, depth) / 4), 160, 576);
    const rowWidth = resolution * 2;
    const dx = width / (resolution - 1);
    const dz = depth / (resolution - 1);
    const accum = new Float32Array(rowWidth * rowWidth * 3);
    for (const { point, direction, color, range, brightness } of sources) {
        const fromX = Math.max(0, Math.floor((point.x - range - originX) / dx));
        const toX = Math.min(resolution - 1, Math.ceil((point.x + range - originX) / dx));
        const fromZ = Math.max(0, Math.floor((point.z - range - originZ) / dz));
        const toZ = Math.min(resolution - 1, Math.ceil((point.z + range - originZ) / dz));
        const rangeSquared = range * range;
        for (let slice = 0; slice < bakedHeights.length; slice += 1) {
            const sy = floor + bakedHeights[slice] - point.y;
            if (sy * sy >= rangeSquared) continue;
            const sliceX = (slice % 2) * resolution;
            const sliceZ = Math.floor(slice / 2) * resolution;
            for (let z = fromZ; z <= toZ; z += 1) {
                const sz = originZ + z * dz - point.z;
                for (let x = fromX; x <= toX; x += 1) {
                    const sx = originX + x * dx - point.x;
                    const squared = sx * sx + sy * sy + sz * sz;
                    if (squared >= rangeSquared) continue;
                    const cone = direction && squared > 0.01
                        ? THREE.MathUtils.smoothstep((sx * direction.x + sy * direction.y + sz * direction.z) / Math.sqrt(squared), 0.14, 0.78)
                        : 1;
                    const intensity = brightness * 1.85 * (1 - squared / rangeSquared) ** 2
                        * (0.16 + 0.84 * cone) / (1 + squared / Math.max(28, rangeSquared * 0.23));
                    const index = ((sliceZ + z) * rowWidth + sliceX + x) * 3;
                    accum[index] += color.r * intensity;
                    accum[index + 1] += color.g * intensity;
                    accum[index + 2] += color.b * intensity;
                }
            }
        }
    }
    const pixels = new Uint8Array(rowWidth * rowWidth * 4);
    for (let index = 0; index < rowWidth * rowWidth; index += 1) {
        for (let channel = 0; channel < 3; channel += 1) {
            pixels[index * 4 + channel] = Math.round(255 * Math.sqrt(Math.min(accum[index * 3 + channel] / 3.8, 1)));
        }
        pixels[index * 4 + 3] = 255;
    }
    const map = new THREE.DataTexture(pixels, rowWidth, rowWidth, THREE.RGBAFormat);
    map.magFilter = map.minFilter = THREE.LinearFilter;
    map.needsUpdate = true;
    uniforms.cityLightingAtlas.value = map;
    uniforms.cityLightTexel.value.set(1 / rowWidth, 1 / rowWidth);
    uniforms.cityLightFloor.value = floor;
    uniforms.cityLightBounds.value.set(originX, originZ, 1 / width, 1 / depth);
}

function localLights(scene, sources) {
    const slots = Array.from({ length: Math.min(5, sources.length) }, () => new THREE.PointLight(0xffffff, 0, 0, 2));
    if (slots.length) scene.add(...slots);
    return (camera) => {
        const heading = camera.getWorldDirection(new THREE.Vector3());
        const delta = new THREE.Vector3();
        const mostVisible = sources.map((source) => {
            delta.copy(source.point).sub(camera.position);
            const distance = delta.length();
            const facing = delta.dot(heading) / Math.max(distance, 0.1);
            const power = Math.min(3, source.brightness) * (0.36 + source.range / 44);
            const score = (0.42 + Math.max(0, facing) * 0.58) * power / (11 + distance);
            return { source, score };
        }).sort((a, b) => b.score - a.score);
        for (let index = 0; index < slots.length; index += 1) {
            const { source } = mostVisible[index];
            const slot = slots[index];
            slot.position.copy(source.point);
            slot.color.copy(source.color);
            slot.distance = source.range * 1.06;
            slot.intensity = source.brightness * 90;
        }
    };
}

function moonShadows(sun, scene, floor) {
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    sun.shadow.camera.near = 4;
    sun.shadow.camera.far = 2340;
    sun.shadow.normalBias = 0.062;
    sun.shadow.bias = -0.00009;
    sun.shadow.intensity = 0.62;
    scene.add(sun.target);
    const focus = new THREE.Vector3();
    const groundHeading = new THREE.Vector3();
    return (camera) => {
        const altitude = Math.max(0, camera.position.y - floor);
        const radius = THREE.MathUtils.clamp(126 + altitude * 1.36, 126, 1260);
        camera.getWorldDirection(groundHeading);
        groundHeading.y = 0;
        focus.copy(camera.position).addScaledVector(groundHeading.normalize(), radius * 0.57);
        focus.y = Math.min(floor + 115, Math.max(floor, camera.position.y * 0.22));
        sun.target.position.copy(focus);
        sun.position.copy(focus).addScaledVector(moonDirection, 900);
        sun.shadow.camera.left = sun.shadow.camera.bottom = -radius;
        sun.shadow.camera.right = sun.shadow.camera.top = radius;
        sun.shadow.camera.updateProjectionMatrix();
    };
}

export function buildLighting(scene, renderer, uniforms, parts, lights, bounds, far, fogDensity) {
    const size = bounds.getSize(new THREE.Vector3());
    const density = fogDensity ?? THREE.MathUtils.clamp(0.72 / (Math.max(size.x, size.z) * 0.72), 0.00040, 0.0022);
    if (density > 0) scene.fog = new THREE.FogExp2(horizon, density);
    const sky = backgroundSphere(far * 0.81);
    scene.add(sky);

    const environment = new THREE.Scene();
    environment.add(backgroundSphere(70, true));
    const pmrem = new THREE.PMREMGenerator(renderer);
    scene.environment = pmrem.fromScene(environment, 0.06, 0.5, 100, { size: 64 }).texture;
    pmrem.dispose();
    environment.children[0].geometry.dispose();
    environment.children[0].material.dispose();

    const skyFill = new THREE.HemisphereLight(0xb6c5fb, 0x756a96, 0.92);
    const ambient = new THREE.AmbientLight(0xc7b8d6, 0.2);
    const moon = new THREE.DirectionalLight(0xb9cdfd, 1.03);
    moon.position.copy(moonDirection).multiplyScalar(820);
    const citySky = new THREE.DirectionalLight(0xb790be, 0.23);
    citySky.position.set(90, 230, -270);
    scene.add(skyFill, ambient, moon, citySky);

    const floor = cityFloor(parts, bounds);
    const { sources, attached } = exportedLights(parts, lights);
    const spill = emissiveBounce(parts, attached, floor);
    bakeLightField(uniforms, [...sources, ...spill], bounds, floor);
    const updateLocalLights = localLights(scene, sources);
    const updateShadows = moonShadows(moon, scene, floor);
    return { sky, lights: sources.length, spill: spill.length, updateLocalLights, updateShadows };
}
