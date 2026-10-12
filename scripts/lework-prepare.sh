#!/usr/bin/env bash
set -euo pipefail

# Run from the checked-out customer-standalone-deploy source tree.
if [[ ! "${LEWORK_SOURCE_SHA:-}" =~ ^[0-9a-f]{40}$ ]]; then
  echo 'A full, lowercase 40-character source SHA is required' >&2
  exit 1
fi
if [[ ! "${LEWORK_VERSION:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'Version must be major.minor.patch' >&2
  exit 1
fi
actual_sha="$(git rev-parse HEAD)"
if [[ "$actual_sha" != "$LEWORK_SOURCE_SHA" ]]; then
  echo "customer-standalone-deploy moved: expected $LEWORK_SOURCE_SHA, got $actual_sha" >&2
  exit 1
fi

test -f apps/desktop/.env.lework
test -f apps/studio/.env.lework
grep -Fxq 'VITE_APP_CHANNEL=lework' apps/desktop/.env.lework
grep -Fxq 'VITE_APP_ID=com.insmtx.lework' apps/desktop/.env.lework
grep -Fxq 'VITE_APP_URL=https://studio.lework.insmtx.com' apps/desktop/.env.lework
grep -Fxq 'VITE_API_URL=https://api.lework.insmtx.com' apps/desktop/.env.lework
grep -Fxq 'VITE_DESKTOP_SCHEME=lework' apps/studio/.env.lework

node <<'NODE'
const fs = require('node:fs');
const path = 'apps/desktop/package.json';
const pkg = JSON.parse(fs.readFileSync(path, 'utf8'));
pkg.version = process.env.LEWORK_VERSION;
fs.writeFileSync(path, JSON.stringify(pkg, null, 2) + '\n');
NODE

echo "LeWork source verified: $actual_sha (v$LEWORK_VERSION)"
