#!/bin/bash
# 使い方: appstore_shots.sh <worktree> <シミュレータUDID> <出力フォルダ>
set -e
WT="$1"; UDID="$2"; OUT="$3"
TMP=/Users/harumi.sagawa/.claude/jobs/08ba9cb3/tmp
APP=$TMP/dd/Build/Products/Debug-iphonesimulator/AozoraZunda.app
BUNDLE=harumidiv.AozoraZunda
mkdir -p "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" >/dev/null
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcodebuild -project "$WT/AozoraZunda.xcodeproj" -scheme AozoraZunda -destination "id=$UDID" \
  -derivedDataPath $TMP/dd build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|BUILD' | head
xcrun simctl install "$UDID" "$APP"

launch() {
  xcrun simctl terminate "$UDID" $BUNDLE >/dev/null 2>&1 || true
  SIMCTL_CHILD_SHOT="$1" xcrun simctl launch "$UDID" $BUNDLE >/dev/null
}

# 本を9冊そろえる（作品一覧の取得とダウンロード）
launch seed
DATA=$(xcrun simctl get_app_container "$UDID" $BUNDLE data)
for i in $(seq 1 90); do
  count=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(len(d if isinstance(d,list) else d['books']))" "$DATA/Library/Application Support/Library/library.json" 2>/dev/null || echo 0)
  [ "$count" -ge 9 ] && break
  sleep 2
done
echo "books: $count"

shoot() {
  launch "$1"
  sleep "$2"
  xcrun simctl io "$UDID" screenshot "$OUT/$3.png" >/dev/null 2>&1
  echo "shot $3"
}
shoot map 6 1_map
shoot shelf 10 2_shelf
shoot reader 45 3_reader
shoot librarian 12 4_librarian
shoot room 6 5_room
shoot myshelf 8 6_myshelf
xcrun simctl terminate "$UDID" $BUNDLE >/dev/null 2>&1 || true
