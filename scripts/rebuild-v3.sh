#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi
export PATH="$(dirname "$(xcrun --find swift)"):$PATH"
export PTB_APP_NAME="PokeTasks v3"
# Retain the existing defaults, credentials and save folder across the rename.
export PTB_BUNDLE_ID="io.github.spawnaudio.poketasks.v2.5"
export PTB_STATE_FOLDER_NAME="PokeTasks v2.5"
export PTB_VERSION="3.0.0"
export PTB_REQUIRE_STABLE_SIGN=1
export PTB_OPEN_MAIN_WINDOW=1
export PTB_DEVELOPMENT_BUILD=1
export PTB_ICON_PATH="assets/PokeBall.icns"
exec bash scripts/build-app.sh
