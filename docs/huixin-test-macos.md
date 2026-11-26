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

## Windows x64 test package

The manual `huixin-test-windows.yml` workflow builds on Windows Server 2022 with
Visual Studio 2022 and checks for the x64 Cloud Files provider in the installer
payload. It runs from `juliet0416/otter-pipeline:main`. The default source
channel, `windows-dev`, accepts a pinned commit on
`feat/enterprise-windows-cloud-files`. Choose `enterprise` after that branch
includes the Windows provider.

```sh
gh workflow run huixin-test-windows.yml --repo juliet0416/otter-pipeline \
  --field source_channel=windows-dev --field 'source_sha=<full-windows-source-sha>' \
  --field version=0.1.0
```

The jobs transfer the installer through a draft Release inside private
`OtterMind/ottermind`. Configure `PRIVATE_REPO_PAT` with source read and Release
write access. The `codesign` runner uses the existing `sign.sh` hardware signer.
The final Windows job checks Authenticode and its timestamp, verifies the
signed SHA-256, removes the unsigned asset from that draft, and gives the
verified installer its delivery name. The draft remains private. If a run
fails after staging, its draft shows signing pending and may contain an
unsigned or unverified candidate. Rerun all jobs for a fresh draft.
If signing fails before the final Windows job runs, rerunning failed jobs can
reuse the existing unsigned asset and replace an earlier signing candidate.
