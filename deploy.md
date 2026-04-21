# Musify Android release from GitHub Codespaces

This guide is optimized for a fresh GitHub Codespace. It sets up Android tooling with one command, prepares signing, and runs the existing release workflow.

## 1) Start a Codespace

1. Open the repository on GitHub.
2. Click **Code → Codespaces → Create codespace on main** (or your release branch).
3. Wait for the terminal to be ready.

## 2) One-command Android setup

Run:

```bash
bash scripts/setup-android-sdk.sh
```

Then refresh your shell:

```bash
source ~/.bashrc
```

Quick verification:

```bash
sdkmanager --version
./gradlew assembleDebug
```

## 3) Generate a release keystore and base64 value

Generate a new keystore (default path and alias):

```bash
./scripts/generate_keystore.sh
```

Or specify both path and alias:

```bash
./scripts/generate_keystore.sh "$HOME/android-release.jks" musify-release-key
```

Create base64 for GitHub Secrets:

```bash
base64 -w 0 "$HOME/android-release.jks" > keystore.b64
```

Keep this file private and do not commit it.

## 4) Set GitHub Actions secrets

In **Repository Settings → Secrets and variables → Actions**, add:

- `ANDROID_KEYSTORE_BASE64` → contents of `keystore.b64`
- `ANDROID_KEYSTORE_PASSWORD` → your keystore password
- `ANDROID_KEY_ALIAS` → your key alias (example: `musify-release-key`)
- `ANDROID_KEY_PASSWORD` → your key password

Optional via GitHub CLI (`gh`) from Codespaces:

```bash
gh secret set ANDROID_KEYSTORE_BASE64 < keystore.b64
gh secret set ANDROID_KEY_ALIAS -b"musify-release-key"
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_PASSWORD
```

## 5) Trigger release workflow

Workflow file: `.github/workflows/android-release.yml`

It builds:

- Signed APK via `:app:assembleUniversalRelease`
- Signed AAB via `:app:bundleUniversalRelease`

Trigger options:

### Manual run

1. Open **Actions → Android Release**.
2. Click **Run workflow**.

### Tag push

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

## 6) Download artifacts

After the workflow finishes, open the run summary and download:

- `release-apk-...`
- `release-aab-...`

## Troubleshooting

### `sdkmanager: command not found`

Run:

```bash
source ~/.bashrc
```

If still missing, rerun setup:

```bash
bash scripts/setup-android-sdk.sh
```

### Java version mismatch

This project expects Java 17+ for Android tooling, and CI uses JDK 21.

Check current Java:

```bash
java -version
```

If needed, rerun:

```bash
bash scripts/setup-android-sdk.sh
```

### Release workflow fails with missing secrets

Make sure all four secrets exist and are non-empty:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The workflow validates these before starting the release build.
