import * as THREE from 'three';
import { enumName } from './geometry.js';

const surfaces = {
    asphalt: { roughness: 0.44, metalness: 0.07, normal: 0.56 },
    cement: { roughness: 0.83, metalness: 0.01, normal: 0.52 },
    sidewalk: { roughness: 0.75, metalness: 0.02, normal: 0.49 },
    glass: { roughness: 0.14, metalness: 0.31, normal: 0.21, environment: 1.12 },
    steel: { roughness: 0.42, metalness: 0.66, normal: 0.51, environment: 1.07 },
    brick: { roughness: 0.82, metalness: 0.01, normal: 0.67 },
    roof: { roughness: 0.76, metalness: 0.04, normal: 0.57 },
    tile: { roughness: 0.39, metalness: 0.07, normal: 0.45 },
    metal: { roughness: 0.42, metalness: 0.64, normal: 0.53, environment: 1.03 },
    stone: { roughness: 0.86, metalness: 0.02, normal: 0.5 },
    rubber: { roughness: 0.89, metalness: 0.01, normal: 0.2 },
    fabric: { roughness: 0.90, metalness: 0, normal: 0.36 },
    wood: { roughness: 0.81, metalness: 0.02, normal: 0.5 },
    paint: { roughness: 0.42, metalness: 0.07, normal: 0.29 },
    water: { roughness: 0.18, metalness: 0.37, normal: 0.32, environment: 1.17 },
    foliage: { roughness: 0.88, metalness: 0, normal: 0.4 },
};

const materialAliases = {
    concrete: 'cement', pavement: 'sidewalk', slate: 'roof', ceramictiles: 'tile',
    diamondplate: 'steel', corrodedmetal: 'steel', basalt: 'stone', cobblestone: 'stone',
    woodplanks: 'wood', smoothplastic: 'paint', plastic: 'paint', leafygrass: 'foliage',
};

const atlasShader = /* glsl */`
    vec3 previewLightSlice(vec2 uv, int sliceIndex) {
        vec2 quadrant = vec2(float(sliceIndex % 2), float(sliceIndex / 2));
        vec2 bounds = vec2(0.5) - cityLightTexel * 2.0;
        vec3 encoded = texture2D(cityLightingAtlas, quadrant * 0.5 + cityLightTexel + uv * bounds).rgb;
        return encoded * encoded * 3.8;
    }

    vec3 previewLightAt(vec3 worldPoint) {
        vec2 uv = (worldPoint.xz - cityLightBounds.xy) * cityLightBounds.zw;
        if (min(uv.x, uv.y) < 0.0 || max(uv.x, uv.y) > 1.0) return vec3(0.0);
        float relativeY = worldPoint.y - cityLightFloor;
        if (relativeY < 12.0) return mix(previewLightSlice(uv, 0), previewLightSlice(uv, 1), clamp(relativeY / 12.0, 0.0, 1.0));
        if (relativeY < 38.0) return mix(previewLightSlice(uv, 1), previewLightSlice(uv, 2), (relativeY - 12.0) / 26.0);
        if (relativeY < 108.0) return mix(previewLightSlice(uv, 2), previewLightSlice(uv, 3), (relativeY - 38.0) / 70.0);
        return previewLightSlice(uv, 3) * exp(-(relativeY - 108.0) / 25.0);
    }
`;

const waterUniforms = /* glsl */`
    uniform sampler2D cityReflectionMap;
    uniform mat4 cityReflectionMatrix;
    uniform float cityReflectionHeight;
    uniform bool cityReflectionReady;
`;

const waterShader = /* glsl */`
    if (previewWorldNormal.y > 0.67) {
        vec2 waterPoint = cityWorldPosition.xz;
        float waterRipple = sin(dot(waterPoint, vec2(0.21, 1.31))) + sin(dot(waterPoint, vec2(-0.49, 0.63))) * 0.58;
        float waterFoam = sin(dot(waterPoint, vec2(0.062, -2.1)) + waterRipple * 1.6);
        float waterFacing = clamp(dot(geometryNormal, geometryViewDir), 0.0, 1.0);
        float waterFresnel = pow(1.0 - waterFacing, 3.45);
        outgoingLight += vec3(0.006, 0.019, 0.032) * (0.66 + waterFoam * 0.14 + waterFresnel * 0.15);
        if (cityReflectionReady && abs(cityWorldPosition.y - cityReflectionHeight) < 0.55) {
            vec4 reflectionPosition = cityReflectionMatrix * vec4(cityWorldPosition, 1.0);
            vec2 reflectionUv = reflectionPosition.xy / max(reflectionPosition.w, 0.001) * 0.5 + 0.5;
            reflectionUv += vec2(waterRipple, waterFoam) * (0.0015 + waterFresnel * 0.0025);
            float inFrame = smoothstep(0.0, 0.048, min(min(reflectionUv.x, reflectionUv.y), min(1.0 - reflectionUv.x, 1.0 - reflectionUv.y)));
            vec3 reflection = texture2D(cityReflectionMap, clamp(reflectionUv, 0.001, 0.999)).rgb;
            reflection *= vec3(0.70, 0.86, 0.96);
            outgoingLight = mix(outgoingLight, reflection, inFrame * (0.26 + waterFresnel * 0.70));
        }
    }
`;

const streetMirrorUniforms = /* glsl */`
    uniform sampler2D cityStreetMirrorMap;
    uniform mat4 cityStreetMirrorMatrix;
    uniform float cityStreetMirrorHeight;
    uniform bool cityStreetMirrorReady;
`;

const streetMirrorShader = /* glsl */`
    if (cityStreetMirrorReady && previewWorldNormal.y > 0.68 && abs(cityWorldPosition.y - cityStreetMirrorHeight) < 0.33) {
        float wetRatio = pow(1.0 - material.roughness, 1.6);
        float grazing = pow(1.0 - saturate(dot(geometryNormal, geometryViewDir)), 2.0);
        vec4 mirrored = cityStreetMirrorMatrix * vec4(cityWorldPosition, 1.0);
        vec2 mirrorUv = mirrored.xy / max(mirrored.w, 0.001) * 0.5 + 0.5;
        mirrorUv += previewWorldNormal.xz * vec2(0.012, 0.018);
        float inFrame = smoothstep(0.0, 0.046, min(min(mirrorUv.x, mirrorUv.y), min(1.0 - mirrorUv.x, 1.0 - mirrorUv.y)));
        vec3 reflectedStreet = texture2D(cityStreetMirrorMap, clamp(mirrorUv, 0.001, 0.999)).rgb;
        reflectedStreet = min(reflectedStreet, vec3(1.34)) * vec3(0.68, 0.77, 0.86);
        outgoingLight += reflectedStreet * inFrame * wetRatio * (0.055 + grazing * 0.42);
    }
`;

function surfaceKey(value) {
    const key = enumName(value).replace(/^marebaixa_/, '');
    return materialAliases[key] ?? key;
}

function albedoGain(image) {
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = 32;
    const context = canvas.getContext('2d', { willReadFrequently: true });
    context.drawImage(image, 0, 0, 32, 32);
    const { data } = context.getImageData(0, 0, 32, 32);
    const color = new THREE.Color();
    let total = 0;
    for (let index = 0; index < data.length; index += 4) {
        color.setRGB(data[index] / 255, data[index + 1] / 255, data[index + 2] / 255, THREE.SRGBColorSpace);
        total += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722;
    }
    return THREE.MathUtils.clamp(1024 / Math.max(total, 0.001), 1, 31);
}

async function loadMaps(manifest, parts, anisotropy) {
    const loader = new THREE.TextureLoader();
    const maps = new Map();
    const used = new Set(parts.map((part) => surfaceKey(part.material)));
    const entries = Object.entries(manifest.materials ?? manifest).filter(([key, properties]) => properties?.maps && used.has(key));
    await Promise.all(entries.map(async ([key, entry]) => {
        const loaded = { tileStuds: Number(entry.tileStuds ?? entry.studsPerTile) || 12 };
        await Promise.all(Object.entries(entry.maps).filter(([kind]) => ['color', 'normal', 'roughness', 'metalness'].includes(kind))
            .map(async ([kind, path]) => {
                const local = path.split('/').map(encodeURIComponent).join('/');
                const texture = await loader.loadAsync(`/materials/${local}`).catch(() => {
                    throw new Error(`PBR map could not be loaded: ${path}`);
                });
                texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
                texture.anisotropy = anisotropy;
                texture.colorSpace = kind === 'color' ? THREE.SRGBColorSpace : THREE.NoColorSpace;
                loaded[kind] = texture;
            }));
        loaded.gain = loaded.color ? albedoGain(loaded.color.image) : 1;
        maps.set(key, loaded);
    }));
    return maps;
}

function physicalUv(curved) {
    return /* glsl */`
        #ifdef USE_INSTANCING
            vec3 scaleInStuds = vec3(length(instanceMatrix[0].xyz), length(instanceMatrix[1].xyz), length(instanceMatrix[2].xyz));
            vec2 studUv;
            ${curved ? /* glsl */`
                studUv = uv * vec2(3.14159 * max(scaleInStuds.y, scaleInStuds.z), scaleInStuds.x);
            ` : /* glsl */`
                vec3 partOrigin = instanceMatrix[3].xyz;
                vec3 studPosition = position * scaleInStuds + vec3(
                    dot(instanceMatrix[0].xyz, partOrigin) / scaleInStuds.x,
                    dot(instanceMatrix[1].xyz, partOrigin) / scaleInStuds.y,
                    dot(instanceMatrix[2].xyz, partOrigin) / scaleInStuds.z
                );
                vec3 axis = abs(normal);
                if (axis.y > 0.59) studUv = vec2(studPosition.x, -sign(normal.y) * studPosition.z);
                else if (axis.x > 0.59) studUv = vec2(-sign(normal.x) * studPosition.z, studPosition.y);
                else studUv = vec2(sign(normal.z) * studPosition.x, studPosition.y);
            `}
            vec2 tiledUv = studUv / cityTileStuds;
            #ifdef USE_MAP
                vMapUv = tiledUv;
            #endif
            #ifdef USE_NORMALMAP
                vNormalMapUv = tiledUv;
            #endif
            #ifdef USE_ROUGHNESSMAP
                vRoughnessMapUv = tiledUv;
            #endif
            #ifdef USE_METALNESSMAP
                vMetalnessMapUv = tiledUv;
            #endif
        #endif
    `;
}

function configureShader(material, map, shape, kind, uniforms) {
    const curved = ['ball', 'cylinder'].includes(shape);
    const reflection = kind === 'water' || kind === 'asphalt' ? kind : 'none';
    const mirrorParams = reflection === 'water' ? waterUniforms : reflection === 'asphalt' ? streetMirrorUniforms : '';
    const mirrorCode = reflection === 'water' ? waterShader : reflection === 'asphalt' ? streetMirrorShader : '';
    material.customProgramCacheKey = () => `${Boolean(map)}:${curved}:${reflection}`;
    material.onBeforeCompile = (shader) => {
        Object.assign(shader.uniforms, uniforms, {
            cityTileStuds: { value: map?.tileStuds ?? 12 },
            cityAlbedoGain: { value: map?.gain ?? 1 },
        });
        shader.vertexShader = /* glsl */`
            varying vec3 cityWorldPosition;
            uniform float cityTileStuds;
        ` + shader.vertexShader.replace('#include <uv_vertex>', `#include <uv_vertex>\n${map ? physicalUv(curved) : ''}`)
            .replace('#include <project_vertex>', /* glsl */`
                #include <project_vertex>
                #ifdef USE_INSTANCING
                    cityWorldPosition = (modelMatrix * instanceMatrix * vec4(transformed, 1.0)).xyz;
                #else
                    cityWorldPosition = (modelMatrix * vec4(transformed, 1.0)).xyz;
                #endif
            `);
        shader.fragmentShader = /* glsl */`
            varying vec3 cityWorldPosition;
            uniform sampler2D cityLightingAtlas;
            uniform vec4 cityLightBounds;
            uniform vec2 cityLightTexel;
            uniform float cityLightFloor;
            uniform float cityAlbedoGain;
            ${atlasShader}
            ${mirrorParams}
        ` + shader.fragmentShader.replace('#include <map_fragment>', /* glsl */`
            #ifdef USE_MAP
                vec4 tintedMap = texture2D(map, vMapUv);
                vec3 preservedTint = mix(vec3(1.0), min(tintedMap.rgb * cityAlbedoGain, vec3(2.28)), 0.72);
                diffuseColor *= vec4(preservedTint, tintedMap.a);
            #endif
        `).replace('#include <lights_fragment_end>', /* glsl */`
            #include <lights_fragment_end>
            vec3 previewWorldNormal = inverseTransformDirection(geometryNormal, viewMatrix);
            vec3 field = previewLightAt(cityWorldPosition);
            float fieldDiffuse = mix(0.67, 1.0, abs(previewWorldNormal.y));
            reflectedLight.indirectDiffuse += material.diffuseColor * field * fieldDiffuse;
            float fieldFresnel = pow(1.0 - saturate(dot(geometryNormal, geometryViewDir)), 3.0);
            reflectedLight.indirectSpecular += field * (0.022 + 0.12 * fieldFresnel) * pow(1.0 - material.roughness, 2.0);
        `).replace('#include <opaque_fragment>', `${mirrorCode}\n#include <opaque_fragment>`);
    };
}

export async function createMaterials(manifest, parts, anisotropy, uniforms) {
    const allMaps = await loadMaps(manifest, parts, anisotropy);
    const materials = new Map();
    const fallback = { roughness: 0.77, metalness: 0.02, normal: 0.4 };
    return {
        count: allMaps.size,
        get(part, shape) {
            const key = surfaceKey(part.material);
            const opacity = THREE.MathUtils.clamp(1 - (part.transparency || 0), 0, 1);
            const reflectance = THREE.MathUtils.clamp(part.reflectance || 0, 0, 1);
            const curved = ['ball', 'cylinder'].includes(shape);
            const identifier = [key, curved, opacity.toFixed(3), reflectance.toFixed(2)].join('/');
            if (materials.has(identifier)) return materials.get(identifier);
            let material;
            if (key === 'neon') {
                material = new THREE.MeshBasicMaterial({ color: new THREE.Color(3.42, 3.42, 3.42), opacity });
            } else {
                const properties = surfaces[key] ?? fallback;
                const map = allMaps.get(key);
                material = new THREE.MeshStandardMaterial({
                    roughness: map?.roughness ? 1 : properties.roughness * (1 - reflectance * 0.46),
                    metalness: map?.metalness ? 1 : properties.metalness + reflectance * (1 - properties.metalness) * 0.54,
                    envMapIntensity: (properties.environment ?? 0.72) + reflectance * 0.56,
                    map: map?.color ?? null,
                    normalMap: map?.normal ?? null,
                    normalScale: new THREE.Vector2(properties.normal, properties.normal),
                    roughnessMap: map?.roughness ?? null,
                    metalnessMap: map?.metalness ?? null,
                    opacity,
                });
                configureShader(material, map, shape, key, uniforms);
            }
            material.transparent = opacity < 0.998;
            material.depthWrite = !material.transparent;
            materials.set(identifier, material);
            return material;
        },
    };
}
