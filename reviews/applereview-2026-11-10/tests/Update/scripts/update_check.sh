#!/bin/bash
# Update check for Tasquel: live 1.0.2 -> new build, from scratch, on one simulator.
#   1. builds both copies, uninstalls the app (its data goes with it)
#   2. seeds real storage with the LIVE copy (ReviewUpdateSeed), screenshots + trees ("before")
#   3. copies the data container (data-before), installs the NEW build over it (no delete)
#   4. same read-only walk in the new build ("after"), copies data-after, compares
#   5. runs ReviewUpdateCheck (intact across relaunches, first save, new features on old data),
#      copying and comparing the data after the edits
# Usage: update_check.sh [UDID] [--store-only]   (--store-only: step 0 alone, no simulator)     Output: shots/<step>.log, shots/before|after/*, data-*
set -u
UDID="CCB7CB84-384B-40B2-BDA2-BDD00700B3C5"; [ -n "${1:-}" ] && [ "$1" != "--store-only" ] && UDID=$1
BUNDLE=com.symonym.Tasquel
U=/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update
OLD=$U/old-project; NEW=$U/project
OLD_DD=$U/old-derived; NEW_DD=$U/derived
SHOTS=$U/shots; RUN=$SHOTS/run-$(date +%H%M%S)
mkdir -p "$RUN/before" "$RUN/after" "$RUN/check"
echo "output in $RUN"
DEST="id=$UDID"
COMMON=(-parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 480)

ui_test() {  # project derived log shotdir prefix tests...
  local proj=$1 dd=$2 log=$3 dir=$4 prefix=$5; shift 5
  local only=(); for t in "$@"; do only+=(-only-testing:"TasquelUITests/$t"); done
  (cd "$proj" && TEST_RUNNER_SHOT_DIR="$dir" TEST_RUNNER_SHOT_PREFIX="$prefix" xcodebuild -project Tasquel.xcodeproj \
     -scheme Tasquel -destination "$DEST" -derivedDataPath "$dd" "${COMMON[@]}" "${only[@]}" \
     test-without-building > "$log" 2>&1)
  grep -E "error:|Test Case .*(passed|failed)|REVIEW" "$log"
}
snapshot() {  # name
  local c; c=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)
  cp -R "$c" "$RUN/$1"
  # The brief's fixed location too, for the latest run.
  rm -rf "$SHOTS/$1.prev" 2>/dev/null; [ -d "$SHOTS/$1" ] && mv "$SHOTS/$1" "$SHOTS/$1.prev"; cp -R "$c" "$SHOTS/$1"
}
strip_tree() { sed -E 's/0x[0-9a-f]+//g; s/\{\{[^}]*\}, \{[^}]*\}\}//g' "$1"; }

echo "== 0. store-level differential (no simulator): the app's own ChecklistStore + Models, built for macOS"
H=$SHOTS/storeharness; mkdir -p "$RUN/store"
(cd "$H/seed" && swiftc -default-isolation MainActor -O -o "$RUN/store/seed-old" "$OLD/Tasquel/ChecklistStore.swift" "$OLD/Tasquel/Models.swift" main.swift) 2>&1 | grep error:
(cd "$H" && swiftc -default-isolation MainActor -O -o "$RUN/store/h-old" "$OLD/Tasquel/ChecklistStore.swift" "$OLD/Tasquel/Models.swift" main.swift actions-old.swift) 2>&1 | grep error:
(cd "$H" && swiftc -default-isolation MainActor -O -o "$RUN/store/h-new" "$NEW/Tasquel/ChecklistStore.swift" "$NEW/Tasquel/Models.swift" main.swift actions-new.swift) 2>&1 | grep error:
mkdir -p "$RUN/store/docs-old"; "$RUN/store/seed-old" "$RUN/store/docs-old"
for d in 0 7 14; do  # today, a week later, two weeks later
  for v in old new; do mkdir -p "$RUN/store/$v-$d"; cp "$RUN/store/docs-old/"*.json "$RUN/store/$v-$d/"
    "$RUN/store/h-$v" "$RUN/store/$v-$d" $d > "$RUN/store/out-$v-$d.txt" 2>&1; done
  sed -E 's/ \| folded=.*$//' "$RUN/store/out-new-$d.txt" | diff "$RUN/store/out-old-$d.txt" - > /dev/null \
    && echo "STORE same as 1.0.2 at +$d days" || echo "STORE DIFFERS from 1.0.2 at +$d days"
done
grep -A3 "Study\] this-week-only" "$RUN/store/out-new-0.txt" | grep -q "list carryOver" && echo "FINDING still there: carry-over copy in a This week only card (next week's Study)"
mkdir -p "$RUN/store/rt"; cp "$RUN/store/docs-old/"*.json "$RUN/store/rt/"
"$RUN/store/h-new" "$RUN/store/rt" 0 goto:1 fold:Groceries goto:0 twoOn:Errands twoOff:Errands > "$RUN/store/out-roundtrip.txt"
sed -n '/week+1/,/Fitness/p' "$RUN/store/out-roundtrip.txt" | grep -q "Groceries.*folded=false" && echo "FINDING still there: This week only on/off loses next week's fold"
[ "${1:-}" = "--store-only" ] || [ "${2:-}" = "--store-only" ] && exit 0

echo "== 1. build both copies"
(cd "$OLD" && xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination "$DEST" -derivedDataPath "$OLD_DD" build-for-testing > "$RUN/build-old.log" 2>&1) || { echo "old build failed"; exit 1; }
(cd "$NEW" && xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination "$DEST" -derivedDataPath "$NEW_DD" build-for-testing > "$RUN/build-new.log" 2>&1) || { echo "new build failed"; exit 1; }
xcrun simctl boot "$UDID" 2>/dev/null
xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null
xcrun simctl ui "$UDID" appearance light

echo "== 2. seed with the live version (1.0.2)"
ui_test "$OLD" "$OLD_DD" "$RUN/seed.log" "$RUN/before" seed ReviewUpdateSeed/testSeedLiveData
ui_test "$OLD" "$OLD_DD" "$RUN/shots-before.log" "$RUN/before" before ReviewUpdateShots/testDumpScreens
snapshot data-before

echo "== 3. install the new build over it"
xcrun simctl install "$UDID" "$NEW_DD/Build/Products/Debug-iphonesimulator/Tasquel.app"
plutil -p "$(xcrun simctl get_app_container "$UDID" "$BUNDLE" app)/Info.plist" | grep -E "CFBundleShortVersionString|CFBundleVersion"

echo "== 4. after: the same walk, then compare (only new fields allowed)"
ui_test "$NEW" "$NEW_DD" "$RUN/shots-after.log" "$RUN/after" after ReviewUpdateShots/testDumpScreens
snapshot data-after
python3 -I "$SHOTS/compare_data.py" "$RUN/data-before" "$RUN/data-after" | tee "$RUN/compare-after.txt"
for f in "$RUN"/before/before-*.txt; do
  n=$(basename "$f" | sed 's/^before-//'); a="$RUN/after/after-$n"
  [ -f "$a" ] || { echo "TREE missing after: $n"; continue; }
  diff <(strip_tree "$f") <(strip_tree "$a") > "$RUN/tree-diff-$n" && rm "$RUN/tree-diff-$n" || echo "TREE differs: $n (see tree-diff-$n)"
done

echo "== 5. checks on the old data in the new version"
ui_test "$NEW" "$NEW_DD" "$RUN/check-1.log" "$RUN/check" check \
  ReviewUpdateCheck/testOldDataLoadsIntactAcrossRelaunches ReviewUpdateCheck/testOldSettingsKept \
  ReviewUpdateCheck/testCarryOverAndRepeatingCopiesFromOldData ReviewUpdateCheck/testFirstSaveInNewVersionKeepsEverything
snapshot data-after-edit
# Milk was ticked and unticked: nothing old should differ.
python3 -I "$SHOTS/compare_data.py" "$RUN/data-before" "$RUN/data-after-edit" | tee "$RUN/compare-after-edit.txt"
ui_test "$NEW" "$NEW_DD" "$RUN/check-2.log" "$RUN/check" check \
  ReviewUpdateCheck/testOldListsLoadOpenAndFold ReviewUpdateCheck/testThisWeekOnlyOffOnOldCardKeepsTasksOneTime \
  ReviewUpdateCheck/testThisWeekOnlyRoundTripOnOldTasks ReviewUpdateCheck/testOldCarryOverCopyInThisWeekOnlyCardIsOneTime \
  ReviewUpdateRoundTripTests/testThisWeekOnlyRoundTripKeepsNextWeeksFoldAndOrder
snapshot data-final
python3 -I "$SHOTS/compare_data.py" "$RUN/data-before" "$RUN/data-final" | tee "$RUN/compare-final.txt"
echo "done: $RUN"
