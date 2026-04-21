# Android Release CI/CD

This project includes a GitHub Actions workflow for building **signed Android release artifacts**.

## Workflow

- File: `.github/workflows/android-release.yml`
- Triggers:
  - `workflow_dispatch` (manual run)
  - `push` on tags matching `v*`
  - `push` on `main` and `release/**`

The workflow builds:
- Signed APK: `:app:assembleUniversalRelease`
- Signed AAB: `:app:bundleUniversalRelease`

Artifacts are uploaded in the workflow run under:
- `release-apk-...`
- `release-aab-...`

## Required GitHub Secrets

Add these repository secrets in **Settings → Secrets and variables → Actions**:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

If any are missing, the workflow fails early with a clear error.

## Generate a release keystore locally

Use:

```bash
./scripts/generate_keystore.sh
```

Optional arguments:

```bash
./scripts/generate_keystore.sh /path/to/android-release.jks your-key-alias
```

The script:
1. Generates a keystore with `keytool`
2. Prints how to convert it to base64
3. Prints which GitHub secrets to set

## Local release build with env-based signing

Release signing is wired to env vars (or `local.properties`), without hardcoded credentials.

Environment variables used by Gradle:
- `ANDROID_KEYSTORE_PATH`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Example local build:

```bash
export ANDROID_KEYSTORE_PATH=/absolute/path/to/android-release.jks
export ANDROID_KEYSTORE_PASSWORD='***'
export ANDROID_KEY_ALIAS='your-key-alias'
export ANDROID_KEY_PASSWORD='***'
./gradlew :app:assembleUniversalRelease :app:bundleUniversalRelease
```

Debug signing remains unchanged.
