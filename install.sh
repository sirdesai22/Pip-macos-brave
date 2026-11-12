#!/bin/bash
# Builds the app and extension, installs the app to ~/Applications and registers the
# Native Messaging host with Brave. Safe to re-run after changes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

APP_DEST="$HOME/Applications/BravePiP.app"
HOST_NAME="com.bravepip.host"
# Brave's documented location, plus Chrome's: current Brave builds (seen with 1.97) look up
# user-level hosts in the Google Chrome folder. allowed_origins limits both to our extension.
HOST_DIRS=(
  "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
  "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
)

echo "==> Building macOS app"
"$ROOT/macos-app/build.sh"
pkill -x BravePiP 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$APP_DEST"
cp -R "$ROOT/macos-app/build/BravePiP.app" "$APP_DEST"

echo "==> Building Brave extension"
cd "$ROOT/brave-extension"
[ -d node_modules ] || npm install --silent
npm run --silent build

# The manifest's fixed "key" makes the unpacked extension's ID deterministic.
EXT_ID=$(node -e '
  const key = require("./manifest.json").key;
  const hex = require("crypto").createHash("sha256").update(Buffer.from(key, "base64")).digest("hex").slice(0, 32);
  console.log([...hex].map((c) => String.fromCharCode(97 + parseInt(c, 16))).join(""));
')

echo "==> Registering Native Messaging host"
for HOST_DIR in "${HOST_DIRS[@]}"; do
  mkdir -p "$HOST_DIR"
  cat > "$HOST_DIR/$HOST_NAME.json" <<EOF
{
  "name": "$HOST_NAME",
  "description": "BravePiP native player",
  "path": "$APP_DEST/Contents/MacOS/BravePiP",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$EXT_ID/"]
}
EOF
  echo "Host manifest:      $HOST_DIR/$HOST_NAME.json"
done

echo
echo "Installed app:      $APP_DEST"
echo "Extension ID:       $EXT_ID"
echo "Load unpacked from: $ROOT/brave-extension  (brave://extensions → Developer mode → Load unpacked)"
