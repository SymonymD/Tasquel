#!/bin/bash
# Update check, Tasquel 1.0.3 (live) -> 1.1: repeats the review's steps 1-4 from scratch.
#
#   update_check.sh [monday|sunday] [data|sim|all]     (default: monday all)
#
# data: the store code of each copy compiled for macOS (shots/datacheck): 1.0.3's code seeds a
#       long-time user's data through the same store calls the UI makes; 1.1's code loads it the
#       same day, relaunches, edits, and both versions roll it forward 1, 2 and 3 weeks; every
#       old value must be unchanged (compare_data.py). Then new features on the old items.
# sim:  the real thing in the simulator: uninstall, install and seed 1.0.3 through the UI
#       (old-project ReviewUpdateSeedUITests), copy the data (shots/data-before-<run>), install
#       1.1 over it (no delete), run ReviewUpdateCheckUITests, copy the data again
#       (data-after-<run>) and compare; then a fresh 1.1 install for the pill.
# The new build is made as 1.1 (12) (MARKETING_VERSION override) so the What's New logic runs as
# it will for real updaters; drop the override once the project itself says 1.1.
set -u
RUN=${1:-monday}; WHAT=${2:-all}
HERE="$(cd "$(dirname "$0")" && pwd)"            # shots
UPD="$(dirname "$HERE")"                          # .../Update
UDID=795888E6-590B-4F10-9E66-A838A37D18DD
BUNDLE=com.symonym.Tasquel
OLD="$UPD/old-project"; NEW="$UPD/project"
OLDDD="$UPD/old-derived"; NEWDD="$UPD/derived"
VERSION_OVERRIDE="MARKETING_VERSION=1.1 CURRENT_PROJECT_VERSION=12"
SUNDAY=$([ "$RUN" = sunday ] && echo 1 || echo 0)
FAIL=0
say() { echo "=== $*"; }

if [ "$WHAT" = data ] || [ "$WHAT" = all ]; then
  D="$HERE/datacheck"; R="$D/script-$RUN"
  say "data level ($RUN start)"
  swiftc -O -parse-as-library -o "$D/old_driver" "$OLD/Tasquel/Models.swift" "$OLD/Tasquel/ChecklistStore.swift" "$D/driver.swift" || exit 2
  swiftc -O -parse-as-library -D NEW -o "$D/new_driver" "$NEW/Tasquel/Models.swift" "$NEW/Tasquel/ChecklistStore.swift" \
    "$NEW/Tasquel/TypedDate.swift" "$D/stubs_new.swift" "$D/driver.swift" || exit 2
  mkdir -p "$R"; R="$(mktemp -d "$R/run.XXXX")"
  "$D/old_driver" seed "$R/seed" "$RUN" | head -1
  cp -R "$R/seed" "$R/after"
  "$D/new_driver" load "$R/after" 2026-11-15T12:30 "1.1 first launch" | head -2
  "$D/new_driver" load "$R/after" 2026-11-15T13:00 "1.1 second launch" | head -1
  "$D/new_driver" edit "$R/after" 2026-11-15T13:30 "1.1 after an edit" | head -1
  "$D/new_driver" load "$R/after" 2026-11-15T14:00 "1.1 relaunch" | head -1
  python3 -I "$HERE/compare_data.py" "$R/seed" "$R/after" || FAIL=1
  for when in 2026-11-16T09:00 2026-11-23T09:00 2026-12-01T09:00; do
    t=${when%%T*}; cp -R "$R/seed" "$R/old-$t"; cp -R "$R/seed" "$R/new-$t"
    "$D/old_driver" load "$R/old-$t" "$when" > "$R/old-$t.txt"; "$D/new_driver" load "$R/new-$t" "$when" > "$R/new-$t.txt"
    say "rollover to $when: 1.0.3 vs 1.1"; python3 -I "$HERE/compare_data.py" "$R/old-$t" "$R/new-$t" --loose | grep -v "^new: defaults" || FAIL=1
  done
  cp -R "$R/seed" "$R/feat"; say "new features on old items"; "$D/new_driver" features "$R/feat" 2026-11-15T12:30 | grep REVIEW
  echo "(data in $R)"
fi

if [ "$WHAT" = sim ] || [ "$WHAT" = all ]; then
  say "simulator ($RUN start), load: $(uptime | sed 's/.*load/load/')"
  xcrun simctl boot $UDID 2>/dev/null
  xcrun simctl uninstall $UDID $BUNDLE
  (cd "$OLD" && xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination "id=$UDID" -derivedDataPath "$OLDDD" \
     build-for-testing > "$HERE/old-build.log" 2>&1) || { echo "old build failed"; exit 2; }
  (cd "$NEW" && xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination "id=$UDID" -derivedDataPath "$NEWDD" \
     $VERSION_OVERRIDE build-for-testing > "$HERE/new-build.log" 2>&1) || { echo "new build failed"; exit 2; }
  say "1. seed 1.0.3 through the UI"
  (cd "$OLD" && TEST_RUNNER_SHOT_DIR="$HERE" TEST_RUNNER_SEED_SUNDAY=$SUNDAY caffeinate -dims xcodebuild -project Tasquel.xcodeproj -scheme Tasquel \
     -destination "id=$UDID" -derivedDataPath "$OLDDD" -parallel-testing-enabled NO -test-timeouts-enabled YES \
     -maximum-test-execution-time-allowance 600 -only-testing:TasquelUITests/ReviewUpdateSeedUITests/testSeedLiveVersionData \
     test-without-building > "$HERE/seed-$RUN.log" 2>&1)
  grep -E "Test Case|REVIEW|error:" "$HERE/seed-$RUN.log"
  say "2. data before"
  C="$(xcrun simctl get_app_container $UDID $BUNDLE data)"
  B="$HERE/data-before-$RUN"; A="$HERE/data-after-$RUN"
  mkdir -p "$B.tmp"; cp -R "$C/" "$B.tmp/"; rm -rf "$B" 2>/dev/null; mv "$B.tmp" "$B"
  plutil -p "$B/Library/Preferences/$BUNDLE.plist"
  say "3. install 1.1 over it (no delete)"
  xcrun simctl install $UDID "$NEWDD/Build/Products/Debug-iphonesimulator/Tasquel.app"
  say "4. checks"
  say "turkey (-demoTurkey) on the first 1.1 launch, What's New pill pending: look at shots/turkey-$RUN-pill-pending-sheet.png"
  "$HERE/turkey_check.sh" turkey-$RUN-pill-pending | tail -1
  for t in testUpdateKeepsLiveVersionData testWhatsNewPillTwiceThenGone testNewFeaturesWorkOnOldItems; do
    (cd "$NEW" && TEST_RUNNER_SHOT_DIR="$HERE" TEST_RUNNER_SEED_SUNDAY=$SUNDAY caffeinate -dims xcodebuild -project Tasquel.xcodeproj -scheme Tasquel \
       -destination "id=$UDID" -derivedDataPath "$NEWDD" -parallel-testing-enabled NO -test-timeouts-enabled YES \
       -maximum-test-execution-time-allowance 600 -only-testing:TasquelUITests/ReviewUpdateCheckUITests/$t \
       $VERSION_OVERRIDE test-without-building > "$HERE/check-$RUN-$t.log" 2>&1) || FAIL=1
    grep -E "Test Case|REVIEW|error:" "$HERE/check-$RUN-$t.log"
    if [ $t = testWhatsNewPillTwiceThenGone ]; then
      say "turkey again, pill gone (control): shots/turkey-$RUN-pill-done-sheet.png"
      "$HERE/turkey_check.sh" turkey-$RUN-pill-done | tail -1
    fi
    if [ $t = testUpdateKeepsLiveVersionData ]; then
      C="$(xcrun simctl get_app_container $UDID $BUNDLE data)"
      mkdir -p "$A.tmp"; cp -R "$C/" "$A.tmp/"; rm -rf "$A" 2>/dev/null; mv "$A.tmp" "$A"
      say "data before vs after (1.1 launched three times)"; python3 -I "$HERE/compare_data.py" "$B" "$A" || FAIL=1
      plutil -p "$A/Library/Preferences/$BUNDLE.plist" | grep -E "lastLaunchedVersion|whatsNew|didMigrate"
    fi
  done
  C="$(xcrun simctl get_app_container $UDID $BUNDLE data)"
  mkdir -p "$A-edit.tmp"; cp -R "$C/" "$A-edit.tmp/"; rm -rf "$A-edit" 2>/dev/null; mv "$A-edit.tmp" "$A-edit"
  say "data before vs after 1.1's edits (expected: Trip's Just this week off, Standup's day, pins)"
  python3 -I "$HERE/compare_data.py" "$B" "$A-edit"
  say "fresh 1.1 install: no What's New pill"
  xcrun simctl uninstall $UDID $BUNDLE
  xcrun simctl install $UDID "$NEWDD/Build/Products/Debug-iphonesimulator/Tasquel.app"
  (cd "$NEW" && TEST_RUNNER_SHOT_DIR="$HERE" caffeinate -dims xcodebuild -project Tasquel.xcodeproj -scheme Tasquel \
     -destination "id=$UDID" -derivedDataPath "$NEWDD" -parallel-testing-enabled NO -test-timeouts-enabled YES \
     -maximum-test-execution-time-allowance 300 -only-testing:TasquelUITests/ReviewUpdateCheckUITests/testFreshInstallHasNoWhatsNewPill \
     $VERSION_OVERRIDE test-without-building > "$HERE/check-fresh.log" 2>&1) || FAIL=1
  grep -E "Test Case|REVIEW|error:" "$HERE/check-fresh.log"
fi
say "done: $([ $FAIL = 0 ] && echo PASS || echo 'FAILURES above')"
exit $FAIL
