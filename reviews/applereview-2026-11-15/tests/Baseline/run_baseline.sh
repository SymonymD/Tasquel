#!/bin/bash
# Re-runs the 2026-11-10 review's tests (iPhone classes, plus the unit tests) on 1.1.
B=/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15/Baseline
SIM=3B8D42B2-2270-43FA-879C-E6275C38C6E9
cd "$B/project" || exit 1
COMMON=(-project Tasquel.xcodeproj -scheme Tasquel -destination "id=$SIM" -derivedDataPath "$B/derived"
        -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 240)

echo "== build-for-testing $(date +%H:%M)"
xcodebuild "${COMMON[@]}" build-for-testing > "$B/shots/build.log" 2>&1
echo "build exit $?"
grep -E "error:" "$B/shots/build.log" | sort -u | head -20

echo "== unit tests $(date +%H:%M)"
xcodebuild "${COMMON[@]}" -only-testing:TasquelTests test-without-building > "$B/shots/unit.log" 2>&1
grep -E "Test run with|✘ Test|TEST (SUCCEEDED|FAILED)" "$B/shots/unit.log" | head -20

echo "== UI tests $(date +%H:%M)"
xcodebuild "${COMMON[@]}" \
  -only-testing:TasquelUITests/ReviewAccessUITests -only-testing:TasquelUITests/ReviewAccessSettingsUITests \
  -only-testing:TasquelUITests/ReviewEdgeTests -only-testing:TasquelUITests/ReviewEverydayTests \
  -only-testing:TasquelUITests/ReviewRegressionTests -only-testing:TasquelUITests/ReviewSettingsRowsTests \
  -only-testing:TasquelUITests/ReviewSettingsSystemDarkTests -only-testing:TasquelUITests/ReviewSettingsThemeTests \
  -only-testing:TasquelUITests/ReviewSettingsWeekTests \
  test-without-building > "$B/shots/ui.log" 2>&1
grep -E "Test Case .*(passed|failed)|Executed [0-9]+ tests" "$B/shots/ui.log" | sed 's/^Test Case //' | tail -120
echo "== done $(date +%H:%M)"
