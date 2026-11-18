#!/bin/bash
# Boots a 6.9-inch iPhone simulator, installs the Release simulator build, opens each demo screen
# (launch arguments -RPDemo -RPScreen <name>) and saves a screenshot to ci/shots/<name>.png.
set -u
mkdir -p ci/shots
APP="$(find build/dd/Build/Products -maxdepth 2 -name Roomprint.app -path '*iphonesimulator*' | head -1)"
[ -d "$APP" ] || { echo "No simulator build found"; exit 1; }
BUNDLE="com.christophergates.roomprint"

TYPE="$(xcrun simctl list devicetypes | grep -E 'iPhone 17 Pro Max \(' | head -1 | sed -E 's/.*\((com\.apple[^)]*)\).*/\1/')"
[ -n "$TYPE" ] || TYPE="$(xcrun simctl list devicetypes | grep -E 'iPhone 16 Pro Max \(' | head -1 | sed -E 's/.*\((com\.apple[^)]*)\).*/\1/')"
RUNTIME="$(xcrun simctl list runtimes available | grep -E '^iOS 2[6-9]' | tail -1 | sed -E 's/.* - (com\.apple[^ ]*)[[:space:]]*$/\1/')"
echo "Device type: $TYPE / runtime: $RUNTIME" | tee ci/shots/device.txt
UDID="$(xcrun simctl create RoomprintShots "$TYPE" "$RUNTIME")" || exit 1
echo "$(date -u +%T) booting $UDID"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null
echo "$(date -u +%T) booted"
xcrun simctl ui "$UDID" appearance light || true
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --operatorName "" --batteryState discharging --batteryLevel 100 || true
xcrun simctl install "$UDID" "$APP"
# First-boot system banners (for example "Ready for Apple Intelligence") show up in the first minute or so.
# Open the app once and let them pass before any screenshot.
xcrun simctl launch "$UDID" "$BUNDLE" -RPDemo -RPScreen homes >/dev/null
sleep 45

shoot() {
  local name="$1"; local wait="${2:-8}"
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" -RPDemo -RPScreen "$name" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot --type=png "ci/shots/$name.png" >/dev/null 2>&1 && echo "$(date -u +%T) shot: $name"
}
shoot onboarding 6
shoot homes 7
shoot home 8
shoot room 9
shoot scan 10
shoot review 10
shoot pdf 12
# Keep the PDF the app just made: it becomes the sample record on getroomprint.com.
DATA="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data 2>/dev/null)"
find "$DATA/tmp" -maxdepth 1 -name '*.pdf' -exec cp {} ci/shots/sample-record.pdf \; 2>/dev/null
[ -f ci/shots/sample-record.pdf ] && echo "saved: sample-record.pdf"
shoot export 9
# Dark mode: any unknown screen name opens the home screen.
xcrun simctl ui "$UDID" appearance dark || true
shoot home-dark 8
shoot room-dark 9
xcrun simctl shutdown "$UDID" || true
ls -la ci/shots
