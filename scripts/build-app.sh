#!/bin/bash
# Assemble PokeTaskBar v1.app and install to /Applications.
# Override: PTB_APP_NAME="PokeTaskBar v1" PTB_BUNDLE_ID="io.github.spawnaudio.poketaskbar.v1" ./scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${PTB_VERSION:-1.0.0}"
PRODUCT_BIN="PokeTaskBar"
APP_NAME="${PTB_APP_NAME:-PokeTaskBar v1}"
BUNDLE_ID="${PTB_BUNDLE_ID:-io.github.spawnaudio.poketaskbar.v1}"
AGENT_LABEL="${BUNDLE_ID}.login"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

echo "==> swift build -c release"
swift build -c release --build-system native --disable-sandbox

echo "==> $APP 조립"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$PRODUCT_BIN" "$APP/Contents/MacOS/$APP_NAME"
# 심볼 strip — 릴리스 바이너리 1.84MB → 0.80MB(-57%). codesign 전에 수행(서명 무효화 방지).
strip -rSTx "$APP/Contents/MacOS/$APP_NAME" 2>/dev/null || strip -rSx "$APP/Contents/MacOS/$APP_NAME"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>PTBOpenMainWindowOnLaunch</key><string>${PTB_OPEN_MAIN_WINDOW:-0}</string>
</dict>
</plist>
PLIST

# 크래시/OOM(exit≠0) 시 자동 재실행 LaunchAgent(KeepAlive) — SMAppService.agent 가 등록해 launchd 가
# 워치독으로 동작. 정상 종료(exit 0: 사용자 종료·업데이트)엔 재실행 안 함(SuccessfulExit=false).
# ProgramArguments 는 brew 설치 경로(/Applications) 고정. codesign 전에 생성해 서명 seal 에 포함.
mkdir -p "$APP/Contents/Library/LaunchAgents"
cat > "$APP/Contents/Library/LaunchAgents/${AGENT_LABEL}.plist" <<AGENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$AGENT_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/$APP_NAME.app/Contents/MacOS/$APP_NAME</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key><false/>
    </dict>
    <key>ThrottleInterval</key><integer>10</integer>
    <key>LimitLoadToSessionType</key><string>Aqua</string>
    <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
AGENT

echo "==> codesign"
SIGN_IDENTITY="${CODESIGN_IDENTITY:-PokeTaskBar Local}"
# 안정적 Keychain ACL 을 위해서는 인증서 존재가 아니라 유효한 codesigning identity 가 필요하다.
if security find-identity -v -p codesigning | grep -F "\"$SIGN_IDENTITY\"" >/dev/null; then
    # 안정적 자체 서명 신원 → 재빌드해도 Keychain "항상 허용" 유지
    codesign --force -s "$SIGN_IDENTITY" "$APP"
else
    # 인증서 없음 → ad-hoc (빌드마다 cdhash 변경 = Keychain 재프롬프트 가능)
    if [[ "${PTB_REQUIRE_STABLE_SIGN:-0}" == "1" ]]; then
        # 릴리스 경로(release.sh 가 세팅). ad-hoc 릴리스는 사용자 Keychain 승인을 깨므로 절대 금지.
        echo "   ✗ PTB_REQUIRE_STABLE_SIGN=1 인데 '$SIGN_IDENTITY' 유효 identity 없음 → ad-hoc 금지, 중단." >&2
        echo "     ./scripts/create-signing-cert.sh 실행 후 다시 시도하세요." >&2
        exit 1
    fi
    echo "   ('$SIGN_IDENTITY' 유효 codesigning identity 없음 → ad-hoc 서명 — 로컬 개발용)"
    echo "   반복 Keychain 허용 프롬프트를 줄이려면 ./scripts/create-signing-cert.sh 실행 후 다시 빌드하세요."
    codesign --force -s - "$APP"
fi

if [[ "${PTB_SKIP_INSTALL:-0}" == "1" ]]; then
    echo "Built: $APP"
    exit 0
fi

echo "==> 기존 인스턴스 종료 + /Applications 설치"
# Never pkill the stock binary when installing a side-by-side named copy.
pkill -x "$APP_NAME" 2>/dev/null || true
rm -rf "/Applications/$APP_NAME.app"
cp -R "$APP" "/Applications/$APP_NAME.app"

echo "완료: open /Applications/$APP_NAME.app"
