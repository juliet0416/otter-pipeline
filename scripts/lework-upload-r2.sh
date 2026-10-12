#!/usr/bin/env bash
set -euo pipefail

version="${LEWORK_VERSION:?LEWORK_VERSION is required}"
bucket="${R2_BUCKET_NAME:?R2_BUCKET_NAME is required}"
endpoint="${R2_ENDPOINT:?R2_ENDPOINT is required}"
origin="${LEWORK_CDN_ORIGIN:-https://cdn.ottermind.ai}"
directory="${1:?publication directory is required}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'Invalid LeWork version' >&2
  exit 1
fi
if [[ "$origin" != 'https://cdn.ottermind.ai' ]]; then
  echo 'Unexpected CDN origin; review the LeWork distribution target before publishing' >&2
  exit 1
fi

# These are deliberately disjoint from Ottermind's electron/releases/latest.
prefix='electron/lework/releases'
version_prefix="${prefix}/v${version}"
latest_prefix="${prefix}/latest"
expected=(
  "LeWork-${version}-arm64-mac.zip"
  "lework-${version}-arm64.dmg"
  "LeWork-${version}-mac.zip"
  "lework-${version}-x64.dmg"
  "lework-${version}-setup.exe"
)

existing_manifest="$(aws s3 cp "s3://${bucket}/${latest_prefix}/latest.yml" - \
  --endpoint-url "$endpoint" --only-show-errors 2>/dev/null || true)"
existing_version="$(printf '%s\n' "$existing_manifest" | sed -n 's/^version: \([0-9][0-9.]*\)$/\1/p' | head -n 1)"
if [ -n "$existing_version" ] && [ "$existing_version" != "$version" ] && \
  [ "$(printf '%s\n' "$version" "$existing_version" | sort -V | tail -n 1)" = "$existing_version" ]; then
  echo "Refusing to replace newer LeWork CDN version ${existing_version} with ${version}" >&2
  exit 1
fi

content_type() {
  case "$1" in
    *.dmg) printf 'application/x-apple-diskimage' ;;
    *.exe) printf 'application/x-msdownload' ;;
    *.zip) printf 'application/zip' ;;
    *.yml) printf 'text/yaml' ;;
    *) echo "Unexpected LeWork artifact: $1" >&2; return 1 ;;
  esac
}

upload() {
  local name="$1" key="$2" cache_control="$3"
  aws s3 cp "${directory}/${name}" "s3://${bucket}/${key}" \
    --endpoint-url "$endpoint" \
    --content-type "$(content_type "$name")" \
    --cache-control "$cache_control" \
    --only-show-errors
}

for name in "${expected[@]}" latest-mac.yml latest.yml; do
  test -s "${directory}/${name}"
  upload "$name" "${version_prefix}/${name}" 'public, max-age=31536000, immutable'
done

# Never clear the shared bucket or even the LeWork latest prefix. Upload the
# new installers first, then the two manifests so no manifest points to an
# installer that has not yet arrived.
for name in "${expected[@]}"; do
  upload "$name" "${latest_prefix}/${name}" 'no-cache, must-revalidate'
done
for name in latest-mac.yml latest.yml; do
  upload "$name" "${latest_prefix}/${name}" 'no-cache, must-revalidate'
done

aws s3api head-object --bucket "$bucket" --key "${latest_prefix}/latest-mac.yml" \
  --endpoint-url "$endpoint" --query 'ContentLength' --output text
aws s3api head-object --bucket "$bucket" --key "${latest_prefix}/latest.yml" \
  --endpoint-url "$endpoint" --query 'ContentLength' --output text
echo "LeWork CDN publication complete: ${origin}/${latest_prefix}/"
