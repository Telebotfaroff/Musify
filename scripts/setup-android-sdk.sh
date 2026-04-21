#!/usr/bin/env bash
set -euo pipefail

DRY_RUN="${SETUP_ANDROID_SDK_DRY_RUN:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_GRADLE_FILE="$REPO_ROOT/app/build.gradle.kts"
BASHRC_FILE="$HOME/.bashrc"

export ANDROID_SDK_ROOT="$HOME/android-sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
CMDLINE_TOOLS_ROOT="$ANDROID_SDK_ROOT/cmdline-tools"
CMDLINE_TOOLS_LATEST="$CMDLINE_TOOLS_ROOT/latest"
SDKMANAGER_BIN="$CMDLINE_TOOLS_LATEST/bin/sdkmanager"

log() {
  echo "[setup-android-sdk] $*"
}

warn() {
  echo "[setup-android-sdk] WARNING: $*" >&2
}

die() {
  echo "[setup-android-sdk] ERROR: $*" >&2
  exit 1
}

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] $*"
    return 0
  fi
  "$@"
}

run_as_root() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] $*"
    return 0
  fi

  if [[ "$EUID" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die "Need root privileges to install system packages, but sudo is unavailable."
  fi
}

prepend_path_if_missing() {
  local path_entry="$1"
  if [[ ":$PATH:" != *":$path_entry:"* ]]; then
    export PATH="$path_entry:$PATH"
  fi
}

apply_android_env() {
  export ANDROID_SDK_ROOT="$HOME/android-sdk"
  export ANDROID_HOME="$ANDROID_SDK_ROOT"
  prepend_path_if_missing "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
  prepend_path_if_missing "$ANDROID_SDK_ROOT/platform-tools"
}

java_major_version() {
  if ! command -v java >/dev/null 2>&1; then
    echo "0"
    return
  fi

  local version_line
  version_line="$(java -version 2>&1 | head -n 1)"

  local major
  major="$(echo "$version_line" | sed -nE 's/.*version "([0-9]+).*/\1/p')"
  if [[ -z "$major" ]]; then
    echo "0"
    return
  fi

  echo "$major"
}

ensure_required_packages() {
  local missing_packages=()

  if ! command -v wget >/dev/null 2>&1; then
    missing_packages+=(wget)
  fi

  if ! command -v unzip >/dev/null 2>&1; then
    missing_packages+=(unzip)
  fi

  local has_openjdk17=0
  if command -v dpkg-query >/dev/null 2>&1; then
    if dpkg-query -W -f='${Status}' openjdk-17-jdk 2>/dev/null | grep -q "install ok installed"; then
      has_openjdk17=1
    fi
  else
    local java_major
    java_major="$(java_major_version)"
    if (( java_major >= 17 )); then
      has_openjdk17=1
    fi
  fi

  if (( has_openjdk17 == 0 )); then
    missing_packages+=(openjdk-17-jdk)
  fi

  if (( ${#missing_packages[@]} == 0 )); then
    log "Required apt packages already available (OpenJDK 17, wget, unzip)."
    return
  fi

  log "Installing missing apt packages: ${missing_packages[*]}"
  run_as_root apt-get update
  run_as_root apt-get install -y "${missing_packages[@]}"
}

ensure_cmdline_tools_at_latest() {
  run mkdir -p "$CMDLINE_TOOLS_ROOT"

  if [[ -x "$SDKMANAGER_BIN" ]]; then
    log "Android cmdline-tools already installed at $CMDLINE_TOOLS_LATEST"
    return
  fi

  if [[ -x "$CMDLINE_TOOLS_ROOT/cmdline-tools/bin/sdkmanager" ]]; then
    log "Found cmdline-tools in legacy layout. Moving to $CMDLINE_TOOLS_LATEST"
    run rm -rf "$CMDLINE_TOOLS_LATEST"
    run mv "$CMDLINE_TOOLS_ROOT/cmdline-tools" "$CMDLINE_TOOLS_LATEST"
    return
  fi

  if [[ -x "$CMDLINE_TOOLS_ROOT/bin/sdkmanager" ]]; then
    log "Found cmdline-tools directly under cmdline-tools/. Moving to latest/."
    run rm -rf "$CMDLINE_TOOLS_LATEST"
    run mkdir -p "$CMDLINE_TOOLS_LATEST"

    local item
    for item in bin lib NOTICE.txt source.properties; do
      if [[ -e "$CMDLINE_TOOLS_ROOT/$item" ]]; then
        run mv "$CMDLINE_TOOLS_ROOT/$item" "$CMDLINE_TOOLS_LATEST/$item"
      fi
    done
    return
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY RUN: would download Android cmdline-tools into $CMDLINE_TOOLS_LATEST"
    return
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local zip_path="$tmp_dir/cmdline-tools.zip"

  local urls=(
    "${ANDROID_CMDLINE_TOOLS_URL:-}"
    "https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip"
    "https://dl.google.com/android/repository/commandlinetools-linux-12266719_latest.zip"
    "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  )

  local downloaded=0
  for url in "${urls[@]}"; do
    [[ -z "$url" ]] && continue
    log "Trying cmdline-tools download: $url"
    if wget -q --show-progress -O "$zip_path" "$url"; then
      downloaded=1
      break
    fi
  done

  if (( downloaded == 0 )); then
    rm -rf "$tmp_dir"
    die "Failed to download Android cmdline-tools. Set ANDROID_CMDLINE_TOOLS_URL and rerun."
  fi

  unzip -q "$zip_path" -d "$tmp_dir"

  if [[ ! -d "$tmp_dir/cmdline-tools" ]]; then
    rm -rf "$tmp_dir"
    die "Unexpected cmdline-tools archive layout."
  fi

  rm -rf "$CMDLINE_TOOLS_LATEST"
  mkdir -p "$CMDLINE_TOOLS_ROOT"
  mv "$tmp_dir/cmdline-tools" "$CMDLINE_TOOLS_LATEST"
  rm -rf "$tmp_dir"

  log "Installed Android cmdline-tools at $CMDLINE_TOOLS_LATEST"
}

ensure_bashrc_config() {
  local block_begin="# >>> musify android sdk >>>"

  if [[ ! -f "$BASHRC_FILE" ]]; then
    run touch "$BASHRC_FILE"
  fi

  if grep -Fq "$block_begin" "$BASHRC_FILE"; then
    log "Android SDK environment block already exists in $BASHRC_FILE"
    return
  fi

  log "Adding Android SDK environment variables to $BASHRC_FILE"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY RUN: would append Android SDK block to $BASHRC_FILE"
    return
  fi

  cat <<'EOF' >> "$BASHRC_FILE"

# >>> musify android sdk >>>
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
if [[ ":$PATH:" != *":$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:"* ]]; then
  export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
fi
if [[ ":$PATH:" != *":$ANDROID_SDK_ROOT/platform-tools:"* ]]; then
  export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"
fi
# <<< musify android sdk <<<
EOF
}

extract_compile_sdk() {
  if [[ ! -f "$APP_GRADLE_FILE" ]]; then
    echo "36"
    return
  fi

  local compile_sdk
  compile_sdk="$(sed -nE 's/^\s*compileSdk\s*=\s*([0-9]+).*/\1/p' "$APP_GRADLE_FILE" | head -n 1)"

  if [[ -z "$compile_sdk" ]]; then
    warn "Could not detect compileSdk from $APP_GRADLE_FILE. Falling back to android-36."
    echo "36"
    return
  fi

  echo "$compile_sdk"
}

extract_build_tools_version() {
  if [[ ! -f "$APP_GRADLE_FILE" ]]; then
    echo ""
    return
  fi

  sed -nE 's/^\s*buildToolsVersion\s*=\s*"([0-9.]+)".*/\1/p' "$APP_GRADLE_FILE" | head -n 1
}

sdkmanager() {
  "$SDKMANAGER_BIN" --sdk_root="$ANDROID_SDK_ROOT" "$@"
}

choose_build_tools_version() {
  local compile_sdk="$1"
  local configured_version="$2"

  if [[ -n "$configured_version" ]]; then
    echo "$configured_version"
    return
  fi

  local candidates=("${compile_sdk}.0.0")
  if (( compile_sdk > 1 )); then
    candidates+=("$((compile_sdk - 1)).0.0")
  fi
  candidates+=("35.0.0" "34.0.0")

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "${candidates[0]}"
    return
  fi

  local available_versions
  available_versions="$(sdkmanager --list 2>/dev/null | sed -nE 's/^\s*build-tools;([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | sort -V -r | uniq)"

  local candidate
  for candidate in "${candidates[@]}"; do
    if grep -Fxq "$candidate" <<< "$available_versions"; then
      echo "$candidate"
      return
    fi
  done

  if [[ -n "$available_versions" ]]; then
    echo "$(head -n 1 <<< "$available_versions")"
    return
  fi

  echo "34.0.0"
}

install_android_packages() {
  local compile_sdk="$1"
  local build_tools_version="$2"

  local packages=(
    "platform-tools"
    "platforms;android-${compile_sdk}"
    "build-tools;${build_tools_version}"
  )

  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY RUN: would accept SDK licenses and install: ${packages[*]}"
    return
  fi

  log "Accepting Android SDK licenses"
  set +o pipefail
  yes | sdkmanager --licenses >/dev/null
  local license_status=$?
  set -o pipefail
  if (( license_status != 0 )); then
    die "Failed to accept Android SDK licenses."
  fi

  log "Installing Android SDK packages: ${packages[*]}"
  sdkmanager "${packages[@]}"
}

main() {
  log "Starting Android SDK setup for Musify"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "Running in dry-run mode (SETUP_ANDROID_SDK_DRY_RUN=1)."
  fi

  ensure_required_packages
  apply_android_env
  ensure_cmdline_tools_at_latest
  apply_android_env
  ensure_bashrc_config

  local compile_sdk
  compile_sdk="$(extract_compile_sdk)"

  local configured_build_tools
  configured_build_tools="$(extract_build_tools_version)"

  local build_tools_version
  build_tools_version="$(choose_build_tools_version "$compile_sdk" "$configured_build_tools")"

  if [[ "$DRY_RUN" != "1" && ! -x "$SDKMANAGER_BIN" ]]; then
    die "sdkmanager not found at $SDKMANAGER_BIN"
  fi

  install_android_packages "$compile_sdk" "$build_tools_version"

  if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    if [[ -f "$BASHRC_FILE" ]]; then
      source "$BASHRC_FILE"
    fi
  fi

  echo
  log "✅ Android environment is ready."
  echo "Android SDK root: $ANDROID_SDK_ROOT"
  echo "compileSdk detected: android-$compile_sdk"
  echo "build-tools installed: $build_tools_version"
  echo
  echo "Next commands:"
  if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "  source ~/.bashrc"
  fi
  echo "  ./gradlew assembleDebug"
  echo "  ./gradlew :app:assembleUniversalRelease :app:bundleUniversalRelease"
  echo "  ./scripts/generate_keystore.sh"
}

main "$@"
