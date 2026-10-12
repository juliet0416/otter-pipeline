#!/usr/bin/env bash
set -euo pipefail

# Run from the checked-out ottermind monorepo. Keep the dependency workaround
# aligned with electron-release.yml, without touching the existing workflow.
node <<'NODE'
const fs = require('node:fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.workspaces = ['apps/desktop', 'apps/studio', 'apps/agent', 'apps/otterDriver', 'packages/*'];
pkg.dependencies = {
  ...(pkg.dependencies || {}),
  dotenv: pkg.dependencies?.dotenv || pkg.devDependencies?.dotenv || '^17.4.1',
};
pkg.devDependencies ||= {};
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
fs.writeFileSync('bunfig.toml', '[install]\nregistry = "https://registry.npmjs.org"\nlinker = "hoisted"\n');
fs.writeFileSync('apps/desktop/.npmrc', 'electron_mirror=https://npmmirror.com/mirrors/electron/\nelectron_builder_binaries_mirror=https://npmmirror.com/mirrors/electron-builder-binaries/\n');
NODE

rm -f bun.lock bun.lockb
bun pm cache rm || true

installed=false
for attempt in 1 2 3; do
  if bun install --no-save --no-cache --force --registry=https://registry.npmjs.org; then
    installed=true
    break
  fi
  bun pm cache rm || true
  sleep "$((attempt * 10))"
done
if [ "$installed" != true ]; then
  echo 'Dependency installation failed' >&2
  exit 1
fi

node <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const electronDir = ['node_modules/electron', 'apps/desktop/node_modules/electron']
  .find((candidate) => fs.existsSync(path.join(candidate, 'package.json')));
if (!electronDir) throw new Error('electron package not found');
const dist = path.join(electronDir, 'dist');
if (!fs.existsSync(dist)) {
  const result = spawnSync(process.execPath, [path.join(electronDir, 'install.js')], { stdio: 'inherit' });
  if (result.status !== 0) process.exit(result.status || 1);
}
if (!fs.existsSync(dist)) throw new Error(`Electron dist missing: ${dist}`);
NODE

(cd packages/types && bun run build)
