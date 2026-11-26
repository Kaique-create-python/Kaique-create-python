import { createReadStream, existsSync, statSync } from 'node:fs';
import { mkdir } from 'node:fs/promises';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const previewDirectory = path.dirname(fileURLToPath(import.meta.url));
const help = `Usage: node preview/render.mjs --map scene.json [options]

  --materials DIR|FILE   PBR directory or manifest.json (default: ../materials)
  --output DIR          Image directory (default: ./preview/output)
  --shot NAME           Capture only this shot; repeat to select multiple
  --width PX            Output width (default: 1600)
  --height PX           Output height (default: 900)
  --exposure NUMBER     Tone-mapping exposure (default: 1.12)
  --bloom NUMBER        Bloom strength (default: 0.19)
  --fog-density NUMBER  Override distance haze, with 0 to disable it
  --no-reflections      Omit planar canal and wet street reflections
  --help                Show this usage

The app loads Three.js and Playwright from local modules. THREE_ROOT,
PLAYWRIGHT_ROOT and CHROMIUM_PATH can override their locations.`;

function readOptions(args) {
    const options = {
        output: path.join(previewDirectory, 'output'),
        width: 1600,
        height: 900,
        exposure: 1.12,
        bloom: 0.19,
        reflections: true,
        shots: [],
    };
    const values = new Set(['map', 'materials', 'output', 'shot', 'width', 'height', 'exposure', 'bloom', 'fog-density']);
    for (let index = 0; index < args.length; index += 1) {
        const argument = args[index];
        if (argument === '--no-reflections') {
            options.reflections = false;
            continue;
        }
        if (!argument.startsWith('--') || !values.has(argument.slice(2))) {
            throw new Error(`Unknown option ${argument}. Use --help for usage.`);
        }
        const flag = argument.slice(2);
        const value = args[++index];
        if (!value || value.startsWith('--')) throw new Error(`Missing value for ${argument}.`);
        if (flag === 'shot') options.shots.push(value);
        else options[flag] = value;
    }
    if (!options.map) throw new Error('Pass --map with the path to the exported Roblox scene JSON.');
    options.map = path.resolve(options.map);
    options.output = path.resolve(options.output);
    for (const flag of ['width', 'height']) {
        const size = Number(options[flag]);
        if (!Number.isInteger(size) || size < 128 || size > 3840) {
            throw new Error(`--${flag} must be an integer between 128 and 3840.`);
        }
        options[flag] = size;
    }
    for (const [flag, min, max] of [['exposure', 0.1, 5], ['bloom', 0, 2], ['fog-density', 0, 0.05]]) {
        if (options[flag] === undefined) continue;
        const value = Number(options[flag]);
        if (!Number.isFinite(value) || value < min || value > max) {
            throw new Error(`--${flag} must be between ${min} and ${max}.`);
        }
        options[flag] = value;
    }
    return options;
}

function materialManifest(input) {
    if (input) {
        const supplied = path.resolve(input);
        return statSync(supplied).isDirectory() ? path.join(supplied, 'manifest.json') : supplied;
    }
    const manifest = path.join(previewDirectory, '..', 'materials', 'manifest.json');
    return existsSync(manifest) ? manifest : undefined;
}

function localThree() {
    if (process.env.THREE_ROOT) return path.resolve(process.env.THREE_ROOT);
    try {
        return path.resolve(path.dirname(require.resolve('three')), '..');
    } catch (error) {
        const bundled = '/workspace/scratch/bastiao-graficos/node_modules/three';
        if (existsSync(path.join(bundled, 'build', 'three.module.js'))) return bundled;
        throw new Error('Three.js is missing. Install it locally or set THREE_ROOT.', { cause: error });
    }
}

function localPlaywright() {
    if (process.env.PLAYWRIGHT_ROOT) return require(path.resolve(process.env.PLAYWRIGHT_ROOT));
    try {
        return require('playwright');
    } catch (error) {
        const bundled = '/opt/codex/runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright';
        if (existsSync(bundled)) return require(bundled);
        throw new Error('Playwright is missing. Install it locally or set PLAYWRIGHT_ROOT.', { cause: error });
    }
}

const contentTypes = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.jpg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
};

function routeDirectory(urlPath, prefix, root) {
    if (!root || !urlPath.startsWith(prefix)) return undefined;
    const relative = urlPath.slice(prefix.length);
    const target = path.resolve(root, relative);
    if (!target.startsWith(root + path.sep)) return undefined;
    return target;
}

function createPreviewServer(map, manifest, three) {
    return createServer((request, response) => {
        try {
            const uri = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
            if (uri === '/favicon.ico') {
                response.writeHead(204).end();
                return;
            }
            const fixed = {
                '/': path.join(previewDirectory, 'index.html'),
                '/scene.json': map,
                '/material-manifest.json': manifest,
            }[uri];
            const file = fixed ?? routeDirectory(uri, '/preview/', previewDirectory)
                ?? routeDirectory(uri, '/three/', three)
                ?? routeDirectory(uri, '/materials/', manifest && path.dirname(manifest));
            if (!file || !statSync(file, { throwIfNoEntry: false })?.isFile()) {
                response.writeHead(404).end('Preview asset not found.');
                return;
            }
            response.setHeader('Content-Type', contentTypes[path.extname(file)] ?? 'application/octet-stream');
            createReadStream(file).on('error', (error) => response.destroy(error)).pipe(response);
        } catch {
            response.writeHead(400).end('Invalid preview request.');
        }
    });
}

function shotFile(name) {
    const stem = name.normalize('NFKD').replace(/\p{Mark}/gu, '').toLowerCase()
        .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
    if (!stem) throw new Error(`Shot name ${name} cannot be used as a filename.`);
    return `${stem}.png`;
}

async function capture(options) {
    const manifest = materialManifest(options.materials);
    for (const file of [options.map, manifest].filter(Boolean)) {
        if (!statSync(file, { throwIfNoEntry: false })?.isFile()) throw new Error(`File not found: ${file}`);
    }
    const { chromium } = localPlaywright();
    const executablePath = process.env.CHROMIUM_PATH ?? [chromium.executablePath(), '/usr/bin/chromium']
        .find((file) => existsSync(file));
    const server = createPreviewServer(options.map, manifest, localThree());
    await new Promise((resolve, reject) => {
        server.once('error', reject);
        server.listen(0, '127.0.0.1', resolve);
    });
    let browser;
    try {
        browser = await chromium.launch({
            executablePath,
            headless: true,
            args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
        });
        const page = await browser.newPage({
            viewport: { width: options.width, height: options.height },
            deviceScaleFactor: 1,
        });
        const errors = new Set();
        const graphicsError = /\b(?:GL_INVALID_OPERATION|GL_INVALID_FRAMEBUFFER_OPERATION|GL_OUT_OF_MEMORY)\b/;
        page.on('pageerror', (error) => errors.add(error.message));
        page.on('console', (message) => {
            const text = message.text();
            if (message.type() === 'error' || graphicsError.test(text)) errors.add(text);
            else if (message.type() === 'warning') console.warn(text);
        });
        await page.goto(`http://127.0.0.1:${server.address().port}/`);
        await page.waitForFunction(() => typeof window.createCityPreview === 'function');
        const scene = await page.evaluate((settings) => window.createCityPreview(settings), {
            width: options.width,
            height: options.height,
            manifest: Boolean(manifest),
            reflections: options.reflections,
            exposure: options.exposure,
            bloom: options.bloom,
            fogDensity: options['fog-density'],
        });
        if (!scene.shots.length) throw new Error('The scene export contains no shot cameras.');
        const shots = [...new Set(options.shots.length ? options.shots : scene.shots)];
        const filenames = new Set();
        for (const shot of shots) {
            if (!scene.shots.includes(shot)) throw new Error(`Unknown shot ${shot}. Available: ${scene.shots.join(', ')}`);
            const filename = shotFile(shot);
            if (filenames.has(filename)) throw new Error(`Duplicate shot filename ${filename}.`);
            filenames.add(filename);
        }
        console.log(`${scene.parts} visible parts in ${scene.batches} batches, ${scene.materials} PBR surfaces, ${scene.lights} exported lights, ${scene.spill} emissive bounces, ${scene.signs} signs.`);
        await mkdir(options.output, { recursive: true });
        for (const shot of shots) {
            const summary = await page.evaluate((name) => window.renderCityShot(name), shot);
            if (errors.size) throw new Error([...errors].join('\n'));
            const filename = path.join(options.output, shotFile(shot));
            await page.locator('canvas').screenshot({ path: filename, timeout: 120_000 });
            const passes = [summary.reflectedWater && 'canal', summary.reflectedStreet && 'wet pavement'].filter(Boolean);
            const reflection = passes.length ? `${passes.join(' and ')} reflections` : 'main pass';
            console.log(`${filename} (${summary.calls} draw calls, ${summary.triangles} triangles, ${reflection})`);
        }
    } finally {
        try {
            await browser?.close();
        } finally {
            await new Promise((resolve) => server.close(resolve));
        }
    }
}

try {
    const args = process.argv.slice(2);
    if (args.includes('--help') || args.includes('-h')) console.log(help);
    else await capture(readOptions(args));
} catch (error) {
    console.error(error.message);
    process.exitCode = 1;
}
