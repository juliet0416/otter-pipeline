#!/usr/bin/env bash
set -euo pipefail

umask 077
temp="$(mktemp -d "$RUNNER_TEMP/huixin-signing.XXXXXX")"
trap 'rm -rf "$temp"' EXIT
keychain="$RUNNER_TEMP/huixin-test-signing.keychain"
password="$(openssl rand -base64 24)"
p12="$temp/developer-id.p12"
host_id=com.ottermind.huixin.test.drive-host
profiles_dir="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"

printf '%s' "$MAC_CERTS" | base64 --decode > "$p12"
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$p12" -k "$keychain" -P "$MAC_CERTS_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/productbuild
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" > /dev/null
existing=()
while IFS= read -r path; do
  if [[ -n "$path" ]]; then existing+=("$path"); fi
done < <(security list-keychains -d user | sed -E 's/^[[:space:]]*"(.+)"$/\1/')
security list-keychains -d user -s "$keychain" "${existing[@]}"
security find-identity -v -p codesigning "$keychain" | grep -q 'Developer ID Application'
mkdir -p "$profiles_dir"

install_profile() {
  local role="$1" bundle_id="$2" encoded="$3"
  local profile="$temp/$role.provisionprofile" decoded="$temp/$role.plist" info uuid name
  printf '%s' "$encoded" | base64 --decode > "$profile"
  security cms -D -i "$profile" > "$decoded"
  info="$(python3 - "$decoded" "$APPLE_TEAM_ID" "$bundle_id" "$host_id" <<'PY'
from datetime import datetime, timezone
from fnmatch import fnmatchcase
from pathlib import Path
import plistlib
import sys
from uuid import UUID

path, team, bundle, host = sys.argv[1:]
profile = plistlib.loads(Path(path).read_bytes())
entitlements = profile['Entitlements']
app_id = entitlements.get('com.apple.application-identifier') or entitlements.get('application-identifier')
expiration = profile['ExpirationDate'].replace(tzinfo=timezone.utc)
group = f'{team}.{host}'
if (
    team not in profile.get('TeamIdentifier', [])
    or app_id != f'{team}.{bundle}'
    or expiration <= datetime.now(timezone.utc)
    or entitlements.get('get-task-allow')
    or entitlements.get('com.apple.security.get-task-allow')
    or not any(fnmatchcase(group, allowed) for allowed in entitlements.get('keychain-access-groups', []))
):
    sys.exit(f'Invalid distribution profile for {bundle}: check team, entitlements and expiration')
name = profile['Name']
if not name or any(character in name for character in '\r\n\t'):
    sys.exit(f'Invalid provisioning profile name for {bundle}')
print(f'{UUID(profile["UUID"])}\t{name}')
PY
)"
  IFS=$'\t' read -r uuid name <<< "$info"
  install -m 600 "$profile" "$profiles_dir/$uuid.provisionprofile"
  printf 'OTTERMIND_FILE_PROVIDER_%s_PROFILE=%s\n' "$role" "$name" >> "$GITHUB_ENV"
}

install_profile HOST "$host_id" "$HUIXIN_MAC_HOST_PROFILE"
install_profile EXTENSION "$host_id.file-provider" "$HUIXIN_MAC_EXTENSION_PROFILE"
printf 'CSC_KEYCHAIN=%s\n' "$keychain" >> "$GITHUB_ENV"
