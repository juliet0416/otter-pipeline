import assert from 'node:assert/strict';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';

const dist = resolve('apps/desktop/dist');
const installer = resolve(dist, `huixin_test_ottermind-${process.env.HUIXIN_VERSION}-setup.exe`);
assert(statSync(installer).size > 0);
const app = resolve(dist, 'win-unpacked');
function verifyX64Application(path) {
  const binary = readFileSync(path);
  assert(binary.length >= 64 && binary.readUInt16LE(0) === 0x5a4d, `Missing MZ header in ${path}`);
  const pe = binary.readUInt32LE(0x3c);
  assert(pe >= 64 && pe + 94 <= binary.length, `Invalid PE offset in ${path}`);
  assert.equal(binary.readUInt32LE(pe), 0x4550, `Missing PE header in ${path}`);
  assert.equal(binary.readUInt16LE(pe + 4), 0x8664, `Expected x64 executable in ${path}`);
  assert.equal(binary.readUInt16LE(pe + 24), 0x20b, `Expected PE32+ executable in ${path}`);
  assert.equal(binary.readUInt16LE(pe + 92), 2, `Expected GUI subsystem in ${path}`);
}
verifyX64Application(resolve(app, 'huixin_test_ottermind.exe'));
verifyX64Application(resolve(app, 'resources/cloud-files/OtterDriveProvider.exe'));
assert(!existsSync(resolve(app, 'resources/app-update.yml')), 'Unexpected auto-update feed');

const require = createRequire(resolve('apps/desktop/package.json'));
const asar = require('@electron/asar');
const archive = resolve(app, 'resources/app.asar');
const pkg = JSON.parse(asar.extractFile(archive, 'package.json'));
assert.equal(pkg.version, process.env.HUIXIN_VERSION);
const main = asar.extractFile(archive, pkg.main.replace(/^\.\//, '')).toString('utf8');
assert(main.includes('https://test.ottermind.cn'), 'Missing Huixin test server');
assert(main.includes('com.ottermind.huixin.test'), 'Missing Huixin app ID');
assert(main.includes('ottermind-huixin-test'), 'Missing Huixin protocol');
assert(main.includes('OtterDriveProvider.exe'), 'Missing Windows drive integration');
console.log('Verified Huixin x64 application, packaged channel and Cloud Files provider');
