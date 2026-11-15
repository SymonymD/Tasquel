#!/bin/bash
# usage: run.sh <logname> <only-testing spec>...   (env vars TEST_RUNNER_* pass through)
P=/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15/Settings
LOG=$P/shots/$1.log; shift
ARGS=()
for t in "$@"; do ARGS+=("-only-testing:TasquelUITests/$t"); done
cd $P/project
export TEST_RUNNER_SHOT_DIR=$P/shots
caffeinate -dims xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination 'id=8954FBD1-188D-4560-A45F-0BB246814969' \
  -derivedDataPath $P/derived -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  "${ARGS[@]}" test > $LOG 2>&1
grep -E "error:|Test Case|REVIEW|XCTAssert|failed" $LOG | grep -v "REVIEW TREE" | head -80
