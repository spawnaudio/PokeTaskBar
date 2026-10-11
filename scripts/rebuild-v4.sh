#!/usr/bin/env bash
# Side-by-side PT-v4 experiment. Uses its own app identity, defaults and saves.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ $(uname -s) != Darwin ]]; then
    printf '%s\n' 'PokeTasks v4 requires macOS 14+ with Xcode/Swift 6. This Linux machine can run the portable progression checks only.' >&2
    exit 1
fi
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi
export PATH="$(dirname "$(xcrun --find swift)"):$PATH"
export PTB_APP_NAME="PokeTasks v4 Experiment"
export PTB_BUNDLE_ID="io.github.spawnaudio.poketasks.v4.experiment"
export PTB_STATE_FOLDER_NAME="PokeTasks v4 Experiment"
export PTB_VERSION="4.0.0"
export PTB_REQUIRE_STABLE_SIGN="${PTB_REQUIRE_STABLE_SIGN:-0}"
export PTB_OPEN_MAIN_WINDOW=1
export PTB_DEVELOPMENT_BUILD=1
export PTB_ICON_PATH="assets/PokeBall.icns"
exec bash scripts/build-app.sh
