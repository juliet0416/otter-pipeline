import { accessSync, constants, copyFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';

const desktopRequire = createRequire(resolve('apps/desktop/package.json'));
const electronDir = dirname(desktopRequire.resolve('electron/package.json'));
const binary = join(electronDir, 'dist', 'electron.exe');
if (!existsSync(binary)) {
  execFileSync(process.execPath, [join(electronDir, 'install.js')], { stdio: 'inherit' });
}
accessSync(binary, constants.F_OK);

const agentRequire = createRequire(resolve('apps/agent/package.json'));
const ffmpeg = agentRequire('ffmpeg-static');
accessSync(ffmpeg, constants.F_OK);
const license = join(dirname(agentRequire.resolve('ffmpeg-static/package.json')), 'ffmpeg.LICENSE');
if (!existsSync(license)) {
  copyFileSync(`${ffmpeg}.LICENSE`, license);
}

const desktopPackage = resolve('apps/desktop/package.json');
const pkg = JSON.parse(readFileSync(desktopPackage, 'utf8'));
pkg.version = process.env.HUIXIN_VERSION;
writeFileSync(desktopPackage, JSON.stringify(pkg, null, 2) + '\n');
