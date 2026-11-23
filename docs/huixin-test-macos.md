# Huixin test macOS installer

The manual workflow `.github/workflows/huixin-test-macos.yml` builds an Apple Silicon installer from a pinned `enterprise` commit of `OtterMind/ottermind`.

- `source_sha` is the full SHA of the source already deployed to the Huixin test site.
- `version` is the installer version in `major.minor.patch` format.
- The installer is `huixin_test_ottermind-<version>-arm64.dmg`. The desktop uses `https://test.ottermind.cn`, the application ID `com.ottermind.huixin.test` and the login callback `ottermind-huixin-test://`. The deployed Studio must use that callback.

The workflow signs the desktop, the OtterDrive host, the File Provider extension and the disk image. It checks the contents of the mounted image and notarizes and staples the final DMG.

## Signing configuration

Use the existing `MAC_CERTS`, `MAC_CERTS_PASSWORD`, `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD` and `APPLE_TEAM_ID` secrets for the signing team. The two Huixin secrets hold the base64-encoded Developer ID provisioning profiles.

| Secret | Bundle ID |
| --- | --- |
| `HUIXIN_MAC_HOST_PROFILE` | `com.ottermind.huixin.test.drive-host` |
| `HUIXIN_MAC_EXTENSION_PROFILE` | `com.ottermind.huixin.test.drive-host.file-provider` |

Both profiles must allow the shared keychain access group `<team-id>.com.ottermind.huixin.test.drive-host`. The `PRIVATE_REPO_PAT` secret needs read access to the source and write access to Release drafts in the private source repository.

## Start a build

```sh
gh workflow run huixin-test-macos.yml --repo juliet0416/otter-pipeline \
  --field 'source_sha=<deployed-enterprise-sha>' --field version=0.1.0
```

## Delivery

Open the private Release draft linked in the workflow summary to download the signed DMG. Its notes record the source SHA and installer SHA-256. Each run attempt has a distinct draft tag. The first package uses manual distribution with update checks disabled.

After installing on a test Mac, verify browser login, Finder personal space, on-demand reading and sign-out cleanup.
