#!/bin/bash
# Build the v1.4 app as its own app and save directory.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi
export PATH="$(dirname "$(xcrun --find swift)"):$PATH"
export PTB_APP_NAME="PokeTaskBar v1.4"
export PTB_BUNDLE_ID="io.github.spawnaudio.poketaskbar.v1.4"
export PTB_VERSION="1.4.0"
export PTB_OPEN_MAIN_WINDOW=1
exec bash scripts/build-app.sh
