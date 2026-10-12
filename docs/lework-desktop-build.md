# LeWork desktop build and CDN release

This is a separate, manually triggered workflow in `juliet0416/otter-pipeline`:
`.github/workflows/lework-desktop-build.yml`. It does not call or edit the
Ottermind `electron-release.yml` workflow.

## Source and inputs

- Source: `OtterMind/ottermind`, branch `customer-standalone-deploy` only.
- `source_sha`: the full 40-character HEAD SHA of that branch. Every build job
  compares its checkout to this SHA and fails closed if the branch has moved.
- `version`: `major.minor.patch`, used only for the validation artifacts.

Example:

```sh
gh workflow run lework-desktop-build.yml \
  -R juliet0416/otter-pipeline \
  -f source_sha=<full-standalone-branch-sha> \
  -f version=0.1.3
```

The workflow builds and notarizes macOS arm64/x64, builds a Windows x64 NSIS
installer, signs that installer on the existing hardware-token runner, and
stores the resulting files as GitHub Actions artifacts for seven days. After
all three signing jobs pass, the reusable `lework-cdn-publish.yml` workflow
copies the signed files and fresh manifests to the isolated LeWork CDN prefix.

## Distribution safety boundary

- No GitHub Release is created.
- Only `electron/lework/releases/v<version>/` and
  `electron/lework/releases/latest/` are written in the existing R2 bucket.
  The Ottermind `electron/releases/latest/` prefix is never read, cleared, or
  overwritten by these workflows.
- Installers are uploaded before `latest-mac.yml` and `latest.yml`; manifests
  are generated from the signed bytes, including the hardware-signed Windows
  installer. Existing `latest/` objects are not recursively deleted.
- The customer download page reads those manifests through its own small
  same-origin endpoint (the shared CDN does not grant LeWork browser CORS),
  then links directly to the CDN installer files.
- The LeWork app uses its own bundle ID, `lework://` scheme, user data directory,
  and update URL. Automatic updates remain disabled in this demo build.
- The Mac verification job rejects an app that registers `ottermind://` or
  points its update configuration at the Ottermind release feed.
- The Ottermind production download feed is not a build output of this workflow.

An earlier successful build can be published without rebuilding:

```sh
gh workflow run lework-cdn-publish.yml \
  -R juliet0416/otter-pipeline \
  -f run_id=<successful-lework-build-run-id> \
  -f source_sha=<sha-used-by-that-build> \
  -f version=<version-used-by-that-build>
```

The current icon is provisional. Windows runtime validation and a customer-owned
CDN domain are still separate follow-up work before a final customer release.
