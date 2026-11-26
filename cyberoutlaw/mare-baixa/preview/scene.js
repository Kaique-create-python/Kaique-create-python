import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { buildParts, buildSigns } from './geometry.js';
import { buildLighting, makeUniforms } from './lighting.js';
import { createMaterials } from './materials.js';

async function readJson(route) {
    const response = await fetch(route);
    if (!response.ok) throw new Error(`Could not load ${route} (${response.status}).`);
    return response.json();
}

function checkCameras(shots) {
    const cameras = new Map();
    for (const shot of shots) {
        if (typeof shot.name !== 'string' || !shot.name.trim() || cameras.has(shot.name)) {
            throw new Error('Each shot needs a unique, nonempty name.');
        }
        const validVectors = [shot.position, shot.look].every((value) => Array.isArray(value)
            && value.length === 3 && value.every(Number.isFinite));
        if (!validVectors || shot.position.every((value, index) => value === shot.look[index])) {
            throw new Error(`Shot ${shot.name} needs distinct position and look vectors.`);
        }
        cameras.set(shot.name, shot);
    }
    return cameras;
}

function prepareRenderer(settings) {
    const renderer = new THREE.WebGLRenderer({
        antialias: false, preserveDrawingBuffer: true, reversedDepthBuffer: true,
    });
    renderer.setSize(settings.width, settings.height);
    renderer.setClearColor(0x100d1d);
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.AgXToneMapping;
    renderer.toneMappingExposure = settings.exposure;
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.shadowMap.autoUpdate = false;
    document.body.appendChild(renderer.domElement);
    return renderer;
}

function captureReflection(renderer, scene, camera, lookingAt, sky, surface, uniforms, dimensions, config) {
    if (!dimensions.reflections || surface.height === undefined) return () => false;
    const target = new THREE.WebGLRenderTarget(
        Math.max(96, Math.round(dimensions.width * config.scale)),
        Math.max(54, Math.round(dimensions.height * config.scale)),
        { type: THREE.HalfFloatType },
    );
    target.texture.name = config.name;
    const matrix = uniforms[`${config.prefix}Matrix`].value;
    const map = uniforms[`${config.prefix}Map`];
    uniforms[`${config.prefix}Height`].value = surface.height;
    const hidden = config.hideMeshes ? surface.meshes : [];

    const inverse = camera.clone();
    const plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -surface.height + config.clipOffset);
    const mirroredAim = new THREE.Vector3();
    const frustum = new THREE.Frustum();
    const projection = new THREE.Matrix4();
    return () => {
        const altitude = camera.position.y - surface.height;
        if (altitude < 0.1 || altitude > config.maxAltitude) return false;
        frustum.setFromProjectionMatrix(projection.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse));
        if (!surface.surfaces.some((bounds) => frustum.intersectsBox(bounds))) return false;

        inverse.copy(camera);
        inverse.position.y = surface.height * 2 - camera.position.y;
        inverse.up.set(0, -1, 0);
        mirroredAim.copy(lookingAt);
        mirroredAim.y = surface.height * 2 - lookingAt.y;
        inverse.lookAt(mirroredAim);
        inverse.updateMatrixWorld();
        matrix.multiplyMatrices(inverse.projectionMatrix, inverse.matrixWorldInverse);

        const previousTarget = renderer.getRenderTarget();
        const previousPlanes = renderer.clippingPlanes;
        for (const mesh of hidden) mesh.visible = false;
        sky.position.copy(inverse.position);
        try {
            renderer.clippingPlanes = [plane];
            // The active render texture cannot also occupy a sampler in this pass.
            map.value = null;
            renderer.setRenderTarget(target);
            renderer.render(scene, inverse);
        } finally {
            renderer.setRenderTarget(previousTarget);
            map.value = target.texture;
            renderer.clippingPlanes = previousPlanes;
            for (const mesh of hidden) mesh.visible = true;
            sky.position.copy(camera.position);
        }
        return true;
    };
}

window.createCityPreview = async (settings) => {
    const [data, manifest] = await Promise.all([
        readJson('/scene.json'),
        settings.manifest ? readJson('/material-manifest.json') : {},
    ]);
    if (!Array.isArray(data.parts) || !Array.isArray(data.shots)) {
        throw new Error('Scene JSON needs both a parts array and a shots array.');
    }
    const shots = checkCameras(data.shots);
    const renderer = prepareRenderer(settings);
    const scene = new THREE.Scene();
    const uniforms = makeUniforms();
    const materials = await createMaterials(manifest, data.parts, Math.min(4, renderer.capabilities.getMaxAnisotropy()), uniforms);
    const world = buildParts(scene, data.parts, materials);
    const signs = buildSigns(scene, data.parts, data.signs ?? []);
    const extent = world.bounds.getSize(new THREE.Vector3()).length();
    const far = Math.max(1400, extent * 1.85);
    const lighting = buildLighting(scene, renderer, uniforms, data.parts, data.lights ?? [], world.bounds, far, settings.fogDensity);
    const camera = new THREE.PerspectiveCamera(55, settings.width / settings.height, 0.28, far);
    const look = new THREE.Vector3();
    const waterReflection = captureReflection(renderer, scene, camera, look, lighting.sky, world.water, uniforms, settings, {
        name: 'Canal reflection', prefix: 'cityReflection', scale: 0.64, maxAltitude: Infinity, clipOffset: 0.018, hideMeshes: true,
    });
    const streetReflection = captureReflection(renderer, scene, camera, look, lighting.sky, world.asphalt, uniforms, settings, {
        name: 'Wet street reflection', prefix: 'cityStreetMirror', scale: 0.48, maxAltitude: 44, clipOffset: -0.068, hideMeshes: false,
    });

    const frames = new THREE.WebGLRenderTarget(settings.width, settings.height, {
        type: THREE.HalfFloatType,
        samples: Math.min(2, renderer.capabilities.maxSamples),
    });
    frames.texture.name = 'City HDR';
    const composer = new EffectComposer(renderer, frames);
    composer.addPass(new RenderPass(scene, camera));
    if (settings.bloom > 0) {
        const resolution = new THREE.Vector2(settings.width, settings.height);
        composer.addPass(new UnrealBloomPass(resolution, settings.bloom, 0.33, 0.73));
    }
    composer.addPass(new OutputPass());

    renderer.info.autoReset = false;
    window.renderCityShot = async (name) => {
        const shot = shots.get(name);
        if (!shot) throw new Error(`Unknown shot ${name}.`);
        camera.fov = THREE.MathUtils.clamp(shot.fov ?? 55, 18, 105);
        camera.position.set(...shot.position);
        look.set(...shot.look);
        camera.lookAt(look);
        camera.updateProjectionMatrix();
        camera.updateMatrixWorld();
        lighting.sky.position.copy(camera.position);
        lighting.updateLocalLights(camera);
        lighting.updateShadows(camera);
        renderer.shadowMap.needsUpdate = true;

        renderer.info.reset();
        uniforms.cityReflectionReady.value = false;
        uniforms.cityStreetMirrorReady.value = false;
        const reflectedWater = waterReflection();
        const reflectedStreet = streetReflection();
        uniforms.cityReflectionReady.value = reflectedWater;
        uniforms.cityStreetMirrorReady.value = reflectedStreet;
        composer.render(0);
        const { calls, triangles } = renderer.info.render;
        await new Promise(requestAnimationFrame);
        return { calls, triangles, reflectedWater, reflectedStreet };
    };

    return {
        shots: [...shots.keys()], parts: world.count, batches: world.batches,
        lights: lighting.lights, spill: lighting.spill, signs, materials: materials.count,
    };
};
