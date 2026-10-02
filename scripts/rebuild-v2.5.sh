#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi
export PATH="$(dirname "$(xcrun --find swift)"):$PATH"
export PTB_APP_NAME="PokeTasks v2.5"
export PTB_BUNDLE_ID="io.github.spawnaudio.poketasks.v2.5"
export PTB_VERSION="2.5.0"
export PTB_OPEN_MAIN_WINDOW=1
export PTB_DEVELOPMENT_BUILD=1
exec bash scripts/build-app.sh
