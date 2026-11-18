#!/bin/bash
# CI build step. "sim": Release build for the simulator. "archive": unsigned App Store archive.
# Writes the full log to ci/<step>.log and every error and warning to ci/<step>-problems.txt,
# and prints errors as GitHub annotations.
set -u
STEP="${1:-sim}"
mkdir -p ci
LOG="ci/$STEP.log"
case "$STEP" in
  sim)
    xcodebuild -project Roomprint.xcodeproj -scheme Roomprint -configuration Release \
      -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build > "$LOG" 2>&1
    ;;
  archive)
    xcodebuild -project Roomprint.xcodeproj -scheme Roomprint -configuration Release \
      -destination 'generic/platform=iOS' -archivePath build/Roomprint.xcarchive \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
      CURRENT_PROJECT_VERSION=1 archive > "$LOG" 2>&1
    ;;
esac
CODE=$?
grep -E "(error|warning): " "$LOG" | sed "s|$PWD/||g" | sort -u > "ci/$STEP-problems.txt"
grep -E "^/.*:[0-9]+:[0-9]+: error: " "$LOG" | sort -u | head -40 | while IFS= read -r line; do
  file="${line%%:*}"; rest="${line#*:}"; lineno="${rest%%:*}"; msg="${line#*error: }"
  echo "::error file=${file#$PWD/},line=$lineno::$msg"
done
echo "--- $STEP: exit $CODE, $(grep -c ' error: ' "$LOG") error lines, $(grep -c ' warning: ' "$LOG") warning lines"
tail -3 "$LOG"
exit $CODE
