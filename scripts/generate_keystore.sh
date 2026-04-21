#!/usr/bin/env bash
set -euo pipefail

DEFAULT_KEYSTORE_PATH="$HOME/android-release.jks"
KEYSTORE_PATH="${1:-$DEFAULT_KEYSTORE_PATH}"
KEY_ALIAS="${2:-musify-release-key}"

if ! command -v keytool >/dev/null 2>&1; then
  echo "Error: keytool is not installed or not in PATH." >&2
  echo "Install a JDK first, then run this script again." >&2
  exit 1
fi

if ! command -v base64 >/dev/null 2>&1; then
  echo "Error: base64 is not installed or not in PATH." >&2
  exit 1
fi

mkdir -p "$(dirname "$KEYSTORE_PATH")"

if [ -f "$KEYSTORE_PATH" ]; then
  echo "Error: keystore already exists at $KEYSTORE_PATH" >&2
  echo "Choose a different path or remove the existing file first." >&2
  exit 1
fi

echo "Generating Android release keystore..."
echo "- Keystore: $KEYSTORE_PATH"
echo "- Alias:    $KEY_ALIAS"
echo ""
echo "keytool will now ask for keystore/key passwords and certificate details."

keytool -genkeypair \
  -v \
  -keystore "$KEYSTORE_PATH" \
  -alias "$KEY_ALIAS" \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000

echo ""
echo "Keystore generated successfully."
echo ""
echo "Next steps:"
echo "1) Convert the keystore to base64 for GitHub Secrets"
if base64 --help 2>&1 | grep -q -- "-w"; then
  echo "   base64 -w 0 \"$KEYSTORE_PATH\""
else
  echo "   base64 \"$KEYSTORE_PATH\" | tr -d '\\n'"
fi
echo ""
echo "2) Add the following GitHub repository secrets:"
echo "   - ANDROID_KEYSTORE_BASE64  (output from step 1)"
echo "   - ANDROID_KEYSTORE_PASSWORD"
echo "   - ANDROID_KEY_ALIAS         (use: $KEY_ALIAS)"
echo "   - ANDROID_KEY_PASSWORD"
echo ""
echo "Optional (GitHub CLI):"
echo "   gh secret set ANDROID_KEYSTORE_BASE64 < <(base64 \"$KEYSTORE_PATH\" | tr -d '\\n')"
echo "   gh secret set ANDROID_KEY_ALIAS -b\"$KEY_ALIAS\""
echo "   gh secret set ANDROID_KEYSTORE_PASSWORD"
echo "   gh secret set ANDROID_KEY_PASSWORD"
echo ""
echo "Important: do not commit keystore files or passwords to git."
