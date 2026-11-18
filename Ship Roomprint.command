#!/bin/bash
# Roomprint: build the App Store version, send it to Apple, and update the scan service.
#
# Double-click this file in Finder (or run it in Terminal). It takes about 10 minutes and needs the Mac
# to be online with Xcode signed in to your Apple developer account. Everything it does is written to
# ship.log next to this file. It never submits anything for review by itself.
#
# Steps: 1 get the latest code  2 check Xcode  3 scan service (private key + latest code)
#        4 build the App Store version  5 upload it to App Store Connect  6 what's left for you
set -u

TEAM_ID="Z44959336K"
SCAN_URL="https://roomprint-scan.christophergates-cg.workers.dev"
KEY_FILE="$HOME/.roomprint/scan-key"
ASC_ENV="$HOME/.roomprint/asc.env"   # optional: App Store Connect API key (KEY_ID, ISSUER_ID, KEY_PATH)

REPO="${RP_REPO:-$(cd "$(dirname "$0")" && pwd)}"
cd "$REPO" || exit 1
LOG="$REPO/ship.log"
if [ -z "${RP_PULLED:-}" ]; then
  # Copy everything shown on screen into ship.log. The restart after step 1 keeps this same log.
  : > "$LOG"
  exec > >(tee -a "$LOG") 2>&1
fi

say()  { printf '\n== %s\n' "$*"; }
note() { printf '   %s\n' "$*"; }
notify() { osascript -e "display notification \"$1\" with title \"Roomprint\"" >/dev/null 2>&1 || true; }
fail() {
  printf '\n!! %s\n\nNothing new was sent to Apple. Send the file ship.log (next to this one) to Claude.\n' "$*"
  git -C "$REPO" checkout -- Roomprint/App/ScanKey.swift >/dev/null 2>&1
  notify "Ship stopped: $1"
  exit 1
}

# 1. Latest code. Runs once, then restarts itself from the updated copy of this file.
if [ -z "${RP_PULLED:-}" ]; then
  say "1/6 Getting the latest code ($(date '+%b %d %I:%M %p'))"
  git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || fail "This folder isn't the Roomprint git checkout."
  if [ -n "$(git status --porcelain)" ]; then
    git stash push -u -m "ship-backup-$(date +%Y%m%d-%H%M)" >/dev/null 2>&1 \
      && note "Saved this Mac's local edits in git stash first (nothing is lost)."
  fi
  git fetch --quiet origin main || fail "Couldn't reach GitHub. Check the Mac's internet."
  if ! git merge --ff-only --quiet origin/main 2>/dev/null; then
    BACKUP="mac-backup-$(date +%Y%m%d-%H%M)"
    git branch "$BACKUP" >/dev/null 2>&1 && note "Kept the old local copy on git branch $BACKUP."
    git reset --hard --quiet origin/main || fail "Couldn't update the code."
  fi
  note "Code: $(git log -1 --format='%h  %s')"
  RP_PULLED=1 RP_REPO="$REPO" exec /bin/bash "$REPO/Ship Roomprint.command"
fi

# 2. Xcode
say "2/6 Checking Xcode"
command -v xcodebuild >/dev/null 2>&1 || fail "Xcode isn't installed on this Mac."
note "$(xcodebuild -version 2>/dev/null | head -1)"
AUTH=()
if [ -f "$ASC_ENV" ]; then
  # shellcheck disable=SC1090
  . "$ASC_ENV"
  if [ -n "${KEY_ID:-}" ] && [ -n "${ISSUER_ID:-}" ] && [ -f "${KEY_PATH:-/nonexistent}" ]; then
    AUTH=(-authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER_ID")
    note "Using the App Store Connect API key for signing and upload."
  fi
fi
[ ${#AUTH[@]} -eq 0 ] && note "Using the Apple ID signed in to Xcode (Xcode > Settings > Accounts)."

# 3. Scan service: private key, then the latest service code.
say "3/6 Scan service"
rm -rf build/ship && mkdir -p build/ship
WRANGLER=(npx --yes wrangler@4)
CF_OK=0
if command -v npx >/dev/null 2>&1; then
  WHO="$(cd worker && "${WRANGLER[@]}" whoami 2>&1)"
  if printf '%s' "$WHO" | grep -qiE "wrangler login|not authenticated|not logged in"; then
    note "Cloudflare needs a sign-in. A browser window opens: click Allow, then come back here."
    (cd worker && "${WRANGLER[@]}" login) && CF_OK=1
  elif printf '%s' "$WHO" | grep -qiE "logged in|account"; then
    CF_OK=1
  else
    note "Couldn't check the Cloudflare sign-in: $(printf '%s' "$WHO" | tail -1)"
  fi
else
  note "Node (npx) isn't on this Mac, so the scan service can't be updated from here."
fi

OLD_KEY="$(sed -n 's/.*static let value = "\(.*\)".*/\1/p' Roomprint/App/ScanKey.swift)"
KEY="$OLD_KEY"
key_works() {
  # A wrong key gets 401; the right key gets 400 here because no frames are sent.
  [ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$SCAN_URL/scan" \
        -H "X-Roomprint-Key: $1" -H "X-Roomprint-Device: ship-check" -H "X-Roomprint-Frames: 0")" = "400" ]
}
if [ -s "$KEY_FILE" ]; then
  KEY="$(cat "$KEY_FILE")"
  if key_works "$KEY"; then note "Private scan key: in place."; else
    note "The saved private key isn't accepted; setting it again."
    [ $CF_OK = 1 ] && (cd worker && printf '%s' "$KEY" | "${WRANGLER[@]}" secret put APP_KEY >/dev/null 2>&1)
    sleep 8
    key_works "$KEY" || { note "Still not accepted; building with the current key instead."; KEY="$OLD_KEY"; }
  fi
elif [ $CF_OK = 1 ]; then
  NEW="rp-$(openssl rand -hex 20)"
  note "Switching the scan service to a private key (the current one is visible on GitHub)..."
  if (cd worker && printf '%s' "$NEW" | "${WRANGLER[@]}" secret put APP_KEY >/dev/null 2>&1); then
    OK=0
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do key_works "$NEW" && { OK=1; break; }; sleep 5; done
    if [ $OK = 1 ]; then
      mkdir -p "$(dirname "$KEY_FILE")" && printf '%s' "$NEW" > "$KEY_FILE" && chmod 600 "$KEY_FILE"
      KEY="$NEW"
      note "Done. The private key is saved at ~/.roomprint/scan-key (keep it; don't share it)."
    else
      note "The new key didn't take, so the old one is going back."
      (cd worker && printf '%s' "$OLD_KEY" | "${WRANGLER[@]}" secret put APP_KEY >/dev/null 2>&1)
    fi
  else
    note "Couldn't change the key. Keeping the current one for now."
  fi
fi
if [ $CF_OK = 1 ]; then
  if (cd worker && "${WRANGLER[@]}" deploy > "$REPO/build/ship/worker.log" 2>&1); then
    note "Scan service updated: $(curl -s "$SCAN_URL/health")"
  else
    note "Couldn't update the scan service (the app still works with the running one). Details: build/ship/worker.log"
  fi
fi
key_works "$KEY" || fail "The scan service doesn't accept the key this build would use, so scans would fail in review."

# 4. Build
BUILD_NUMBER="$(date +%Y%m%d%H%M)"
VERSION="$(sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' Roomprint.xcodeproj/project.pbxproj | head -1)"
say "4/6 Building Roomprint $VERSION ($BUILD_NUMBER). About 5 minutes."
sed -i '' "s|static let value = \".*\"|static let value = \"$KEY\"|" Roomprint/App/ScanKey.swift
xcodebuild -project Roomprint.xcodeproj -scheme Roomprint -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/ship/Roomprint.xcarchive \
  -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"} DEVELOPMENT_TEAM="$TEAM_ID" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  archive > build/ship/archive.log 2>&1
STATUS=$?
git checkout -- Roomprint/App/ScanKey.swift
if [ $STATUS -ne 0 ]; then
  grep -E "error:|Signing|provisioning" build/ship/archive.log | sort -u | head -15
  fail "The build failed (details in build/ship/archive.log)."
fi
note "Built."

# 5. Upload
say "5/6 Sending it to App Store Connect"
cat > build/ship/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST
if ! xcodebuild -exportArchive -archivePath build/ship/Roomprint.xcarchive \
     -exportOptionsPlist build/ship/ExportOptions.plist -exportPath build/ship/export \
     -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"} > build/ship/upload.log 2>&1; then
  grep -iE "error|failed|invalid" build/ship/upload.log | sort -u | head -15
  fail "Apple didn't take the upload (details in build/ship/upload.log)."
fi
note "Uploaded."

# 6. What's left
say "6/6 Done: Roomprint $VERSION ($BUILD_NUMBER) is with Apple"
cat <<NEXT

   Apple processes the build in about 15 to 30 minutes. Then, in App Store Connect:
   1. Apps > Roomprint > the iOS 1.0 version page.
   2. In "Build", remove the old build and pick $BUILD_NUMBER.
   3. Paste the review notes from appstore/RESUBMIT.md into "Notes" (App Review Information).
   4. Click "Add for Review", then "Submit to App Review".
      If Apple left a message in App Review, reply there with the text in appstore/RESUBMIT.md first.

NEXT
open "https://appstoreconnect.apple.com/apps" >/dev/null 2>&1 || true
notify "Build $BUILD_NUMBER uploaded to Apple"
