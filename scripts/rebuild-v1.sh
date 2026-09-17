#!/bin/bash
# Rebuild the isolated "PokeTaskBar v1" app.
# Does not replace /Applications/PokeTokenBar.app or "PokeTokenBar v3.app".
#
#   ./scripts/rebuild-v1.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    sed -n '2,6p' "$0"
    exit 0
fi

if [[ -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
    export PATH="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH"
elif [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

export PTB_APP_NAME="PokeTaskBar v1"
export PTB_BUNDLE_ID="io.github.spawnaudio.poketaskbar.v1"
./scripts/build-app.sh

open "/Applications/PokeTaskBar v1.app"
echo "v1 save stays in ~/Library/Application Support/PokeTaskBar v1"
