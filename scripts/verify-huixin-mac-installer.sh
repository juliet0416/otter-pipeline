#!/usr/bin/env bash
set -euo pipefail

installer="apps/desktop/dist/huixin_test_ottermind-${HUIXIN_VERSION}-arm64.dmg"
test -s "$installer"
mount="$(mktemp -d "$RUNNER_TEMP/huixin-installer.XXXXXX")"
trap 'hdiutil detach "$mount" >/dev/null 2>&1 || true; rmdir "$mount"' EXIT
hdiutil attach -readonly -nobrowse -mountpoint "$mount" "$installer" >/dev/null
app="$mount/huixin_test_ottermind.app"
helper="$app/Contents/Helpers/OtterDrive.app"
extension="$helper/Contents/PlugIns/OtterDriveFileProvider.appex"
app_id=com.ottermind.huixin.test
host_id="$app_id.drive-host"

verify_signature() {
  local path="$1" signature
  codesign --verify --strict "$path"
  signature="$(codesign --display --verbose=4 "$path" 2>&1)"
  grep -Fxq "TeamIdentifier=$APPLE_TEAM_ID" <<< "$signature"
  grep -q '^Authority=Developer ID Application:' <<< "$signature"
}

verify_signature "$installer"
codesign --verify --strict --deep "$app"
for bundle in "$app" "$helper" "$extension"; do
  verify_signature "$bundle"
done
test "$(plutil -extract CFBundleIdentifier raw -o - "$helper/Contents/Info.plist")" = "$host_id"
test "$(plutil -extract CFBundleIdentifier raw -o - "$extension/Contents/Info.plist")" = "$host_id.file-provider"
test "$(plutil -extract CFBundleIdentifier raw -o - "$app/Contents/Info.plist")" = "$app_id"
test "$(plutil -extract CFBundleShortVersionString raw -o - "$app/Contents/Info.plist")" = "$HUIXIN_VERSION"
test "$(plutil -extract CFBundleURLTypes json -o - "$app/Contents/Info.plist" | jq -c '[.[].CFBundleURLSchemes[]]')" = '["ottermind-huixin-test"]'
executable="$(plutil -extract CFBundleExecutable raw -o - "$app/Contents/Info.plist")"
test "$(lipo -archs "$app/Contents/MacOS/$executable")" = arm64
test ! -e "$app/Contents/Resources/app-update.yml"

# Let Security.framework decode the signed entitlements on both XML and DER builds.
swift - "$APPLE_TEAM_ID.$host_id" "$helper" "$extension" <<'SWIFT'
import Foundation
import Security

let group = CommandLine.arguments[1]
for path in CommandLine.arguments.dropFirst(2) {
    var code: SecStaticCode?
    let url = URL(fileURLWithPath: path) as CFURL
    guard SecStaticCodeCreateWithPath(url, [], &code) == errSecSuccess, let code else { exit(1) }
    var information: CFDictionary?
    guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
          let info = information as? [String: Any],
          let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any],
          let groups = entitlements["keychain-access-groups"] as? [String], groups.contains(group) else {
        fputs("Invalid shared keychain entitlement for \(path)\n", stderr)
        exit(1)
    }
}
SWIFT

node --input-type=commonjs - "$app/Contents/Resources/app.asar" <<'NODE'
const assert = require('node:assert/strict');
const asar = require('@electron/asar');
const archive = process.argv[2];
const pkg = JSON.parse(asar.extractFile(archive, 'package.json'));
const main = asar.extractFile(archive, pkg.main.replace(/^\.\//, '')).toString('utf8');
assert(main.includes('https://test.ottermind.cn'), 'Packaged main process must target the Huixin test server');
assert(main.includes('ottermind-huixin-test'), 'Packaged main process must use the Huixin protocol');
NODE
