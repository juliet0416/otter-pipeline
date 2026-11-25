import assert from 'node:assert/strict';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';

const dist = resolve('apps/desktop/dist');
const installer = resolve(dist, `huixin_test_ottermind-${process.env.HUIXIN_VERSION}-setup.exe`);
assert(statSync(installer).size > 0);
const app = resolve(dist, 'win-unpacked');
const binary = readFileSync(resolve(app, 'huixin_test_ottermind.exe'));
assert.equal(binary.readUInt16LE(0), 0x5a4d, 'Missing MZ header');
const pe = binary.readUInt32LE(0x3c);
assert.equal(binary.readUInt32LE(pe), 0x4550, 'Missing PE header');
assert.equal(binary.readUInt16LE(pe + 4), 0x8664, 'Expected x64 Electron executable');
assert(!existsSync(resolve(app, 'resources/app-update.yml')), 'Unexpected auto-update feed');

const require = createRequire(resolve('apps/desktop/package.json'));
const asar = require('@electron/asar');
const archive = resolve(app, 'resources/app.asar');
const pkg = JSON.parse(asar.extractFile(archive, 'package.json'));
assert.equal(pkg.version, process.env.HUIXIN_VERSION);
const main = asar.extractFile(archive, pkg.main.replace(/^\.\//, '')).toString('utf8');
assert(main.includes('https://test.ottermind.cn'), 'Missing Huixin test server');
assert(main.includes('ottermind-huixin-test'), 'Missing Huixin protocol');
console.log('Verified Huixin x64 installer and packaged channel');
