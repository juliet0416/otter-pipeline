# LeWork desktop validation build

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
stores the resulting files as GitHub Actions artifacts for seven days.

## First-stage safety boundary

- No GitHub Release is created.
- Nothing is uploaded to Cloudflare R2 or any `latest` directory.
- The LeWork app uses its own bundle ID, `lework://` scheme, user data directory,
  and update URL. Automatic updates are disabled for this validation stage.
- The Mac verification job rejects an app that registers `ottermind://` or
  points its update configuration at the Ottermind release feed.
- The Ottermind production download feed is not a build output of this workflow.

The current icon is provisional. Do not publish these artifacts on the customer
download page until branding, Windows runtime validation, and a dedicated
LeWork update feed have been completed.
