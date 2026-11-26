import * as THREE from 'three';

const faces = {
    front: { normal: [0, 0, -1], rotation: [0, Math.PI, 0], axes: [0, 1] },
    back: { normal: [0, 0, 1], rotation: [0, 0, 0], axes: [0, 1] },
    left: { normal: [-1, 0, 0], rotation: [0, -Math.PI / 2, 0], axes: [2, 1] },
    right: { normal: [1, 0, 0], rotation: [0, Math.PI / 2, 0], axes: [2, 1] },
    top: { normal: [0, 1, 0], rotation: [-Math.PI / 2, 0, 0], axes: [0, 2] },
    bottom: { normal: [0, -1, 0], rotation: [Math.PI / 2, 0, 0], axes: [0, 2] },
};

export function rgb(values) {
    return new THREE.Color().setRGB(...values, THREE.SRGBColorSpace);
}

export function enumName(value) {
    return String(value ?? '').split('.').at(-1).toLowerCase();
}

export function transform(part, matrix = new THREE.Matrix4(), scaled = false) {
    const [x, y, z, xx, xy, xz, yx, yy, yz, zx, zy, zz] = part.cf;
    const [sx, sy, sz] = scaled ? part.size : [1, 1, 1];
    return matrix.set(
        xx * sx, xy * sy, xz * sz, x,
        yx * sx, yy * sy, yz * sz, y,
        zx * sx, zy * sy, zz * sz, z,
        0, 0, 0, 1,
    );
}

export function facePlacement(part, name) {
    const face = faces[enumName(name)];
    if (!face) return undefined;
    const frame = transform(part);
    const axis = new THREE.Vector3(...face.normal);
    const point = axis.clone().multiply(new THREE.Vector3(...part.size).multiplyScalar(0.5)).applyMatrix4(frame);
    const direction = axis.transformDirection(frame);
    const rotation = new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(...face.rotation));
    const orientation = new THREE.Quaternion().setFromRotationMatrix(frame.multiply(rotation));
    return { point, direction, orientation, size: face.axes.map((axisIndex) => part.size[axisIndex]) };
}

function wedge(halfCorner) {
    const a = [-0.5, -0.5, -0.5];
    const b = [0.5, -0.5, -0.5];
    const c = [0.5, -0.5, 0.5];
    const d = [-0.5, -0.5, 0.5];
    const e = [-0.5, 0.5, 0.5];
    const f = [0.5, 0.5, 0.5];
    const polygons = halfCorner
        ? [[a, b, c, d], [d, c, f], [b, f, c], [a, d, f], [a, f, b]]
        : [[a, b, c, d], [d, c, f, e], [a, d, e], [b, f, c], [a, e, f, b]];
    const positions = [];
    const uv = [];
    for (const vertices of polygons) {
        const edge = new THREE.Vector3(...vertices[1]).sub(new THREE.Vector3(...vertices[0]));
        const other = new THREE.Vector3(...vertices[2]).sub(new THREE.Vector3(...vertices[0]));
        const normal = edge.cross(other).normalize();
        const axes = Math.abs(normal.y) > 0.59 ? [0, 2] : Math.abs(normal.x) > 0.59 ? [2, 1] : [0, 1];
        for (let triangle = 1; triangle < vertices.length - 1; triangle += 1) {
            for (const index of [0, triangle, triangle + 1]) {
                const vertex = vertices[index];
                positions.push(...vertex);
                uv.push(vertex[axes[0]] + 0.5, vertex[axes[1]] + 0.5);
            }
        }
    }
    const mesh = new THREE.BufferGeometry();
    mesh.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
    mesh.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    mesh.computeVertexNormals();
    return mesh;
}

const shapes = {
    block: new THREE.BoxGeometry(1, 1, 1),
    cylinder: new THREE.CylinderGeometry(0.5, 0.5, 1, 18).rotateZ(-Math.PI / 2),
    ball: new THREE.SphereGeometry(0.5, 16, 10),
    wedge: wedge(false),
    cornerwedge: wedge(true),
};

export function buildParts(scene, parts, materials) {
    const bounds = new THREE.Box3();
    const half = new THREE.Vector3();
    const center = new THREE.Vector3();
    const corner = new THREE.Vector3();
    const batchByKey = new Map();
    const planarSurfaces = new Map(['water', 'asphalt'].map((kind) => [kind, { meshes: [], area: 0, surfaces: [] }]));
    let count = 0;
    for (const part of parts) {
        if (part.transparency >= 0.995) continue;
        if (part.size.length !== 3 || part.cf.length !== 12 || !part.size.every((size) => size > 0)) {
            throw new Error(`Invalid size or CFrame for ${part.name || `part ${count + 1}`}.`);
        }
        const [x, y, z, xx, xy, xz, yx, yy, yz, zx, zy, zz] = part.cf;
        const [width, height, depth] = part.size;
        half.set(
            (Math.abs(xx) * width + Math.abs(xy) * height + Math.abs(xz) * depth) / 2,
            (Math.abs(yx) * width + Math.abs(yy) * height + Math.abs(yz) * depth) / 2,
            (Math.abs(zx) * width + Math.abs(zy) * height + Math.abs(zz) * depth) / 2,
        );
        center.set(x, y, z);
        bounds.expandByPoint(corner.copy(center).sub(half)).expandByPoint(corner.copy(center).add(half));

        const shape = enumName(part.shape) || 'block';
        const material = materials.get(part, shape);
        const kind = enumName(part.material);
        const planar = planarSurfaces.get(kind);
        const castsShadow = kind !== 'water' && material.isMeshStandardMaterial && !material.transparent
            && (part.castShadow ?? part.shadow) !== false
            && height > 0.35 && width * height * depth > 4.5 && width * depth > 0.32;
        const key = [Math.floor(x / 320), Math.floor(z / 320), shape, material.id, castsShadow].join('/');
        if (!batchByKey.has(key)) batchByKey.set(key, { material, shape, planar, castsShadow, instances: [] });
        batchByKey.get(key).instances.push(part);
        count += 1;

        if (planar && yy > 0.95) {
            const top = y + height / 2;
            planar.surfaces.push({ top, bounds: new THREE.Box3(center.clone().sub(half), center.clone().add(half)) });
            if (width * depth > planar.area) {
                planar.area = width * depth;
                planar.height = top;
            }
        }
    }
    const matrix = new THREE.Matrix4();
    const tint = new THREE.Color();
    for (const { material, shape, planar, castsShadow, instances } of batchByKey.values()) {
        const mesh = new THREE.InstancedMesh(shapes[shape] ?? shapes.block, material, instances.length);
        for (let index = 0; index < instances.length; index += 1) {
            const part = instances[index];
            mesh.setMatrixAt(index, transform(part, matrix, true));
            mesh.setColorAt(index, tint.setRGB(...(part.color ?? [1, 1, 1]), THREE.SRGBColorSpace));
        }
        mesh.castShadow = castsShadow;
        mesh.receiveShadow = material.isMeshStandardMaterial === true;
        mesh.computeBoundingSphere();
        if (planar) planar.meshes.push(mesh);
        scene.add(mesh);
    }
    if (bounds.isEmpty()) throw new Error('The scene export contains no visible geometry.');
    for (const surface of planarSurfaces.values()) {
        surface.surfaces = surface.surfaces.filter(({ top }) => Math.abs(top - surface.height) < 0.55)
            .map((entry) => entry.bounds);
    }
    return { bounds, count, batches: batchByKey.size, water: planarSurfaces.get('water'), asphalt: planarSurfaces.get('asphalt') };
}

function textTexture(text, aspect, color) {
    const image = document.createElement('canvas');
    image.width = Math.round(THREE.MathUtils.clamp(aspect * 160, 192, 1280));
    image.height = Math.round(THREE.MathUtils.clamp(image.width / aspect, 48, 512));
    const context = image.getContext('2d');
    const lines = text.split(/\r?\n/);
    const font = (size) => `bold ${size}px "Liberation Sans", "DejaVu Sans", sans-serif`;
    let size = image.height * 0.64 / lines.length;
    context.font = font(size);
    const longest = Math.max(1, ...lines.map((line) => context.measureText(line).width));
    size *= Math.min(1, image.width * 0.90 / longest);
    context.font = font(size);
    context.fillStyle = rgb(color).getStyle();
    context.textAlign = 'center';
    context.textBaseline = 'middle';
    for (let index = 0; index < lines.length; index += 1) {
        const y = image.height / 2 + (index - (lines.length - 1) / 2) * size * 1.19;
        context.fillText(lines[index], image.width / 2, y);
    }
    const texture = new THREE.CanvasTexture(image);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.anisotropy = 4;
    return texture;
}

export function buildSigns(scene, parts, signs) {
    const cache = new Map();
    const plane = new THREE.PlaneGeometry(1, 1);
    let count = 0;
    for (const sign of signs) {
        const part = parts[sign.part - 1];
        if (!part || !sign.text) continue;
        const face = facePlacement(part, sign.face);
        if (!face) continue;
        const color = sign.color ?? [1, 1, 1];
        const aspect = face.size[0] / face.size[1];
        const key = JSON.stringify([aspect.toFixed(3), sign.text, color]);
        if (!cache.has(key)) {
            cache.set(key, new THREE.MeshBasicMaterial({
                map: textTexture(sign.text, aspect, color),
                color: new THREE.Color(1.82, 1.82, 1.82),
                transparent: true,
                depthWrite: false,
                alphaTest: 0.02,
            }));
        }
        const mesh = new THREE.Mesh(plane, cache.get(key));
        mesh.position.copy(face.point).addScaledVector(face.direction, 0.018);
        mesh.quaternion.copy(face.orientation);
        mesh.scale.set(...face.size, 1);
        scene.add(mesh);
        count += 1;
    }
    return count;
}
