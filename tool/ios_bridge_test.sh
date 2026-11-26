#!/usr/bin/env bash
# Runs the example's bridge test on an iOS simulator: an iPhone of the newest
# iOS runtime, fully booted before the test starts.
#
# On a slow machine a run sometimes stops answering once the app is up. Such a
# run is ended after BRIDGE_TEST_LIMIT seconds and tried once more on a
# restarted simulator. A failing test is never tried again.
#
# Usage: tool/ios_bridge_test.sh
set -euo pipefail

LIMIT=${BRIDGE_TEST_LIMIT:-600}
cd "$(dirname "$0")/../example"

device=$(xcrun simctl list devices available -j | python3 -c "
import json, re, sys
runtimes = json.load(sys.stdin)['devices']
ios = {name: devices for name, devices in runtimes.items() if 'SimRuntime.iOS' in name and devices}
newest = max(ios, key=lambda name: [int(part) for part in re.findall(r'\d+', name)])
print(next(d['udid'] for d in ios[newest] if 'iPhone' in d['name']))")

# Each run gets a process group of its own, so that it can be ended whole.
set -m

# The test's own exit code, or 124 for a run that stopped answering.
run_test() {
  xcrun simctl bootstatus "$device" -b
  # The expanded reporter prints each test as it starts, so the log of a run
  # that stopped answering shows whether the test had begun.
  flutter test integration_test -d "$device" --reporter expanded &
  local run=$! waited=0
  while kill -0 "$run" 2>/dev/null; do
    if [ "$waited" -ge "$LIMIT" ]; then
      kill -- "-$run" 2>/dev/null || true
      sleep 5
      kill -9 -- "-$run" 2>/dev/null || true
      wait "$run" 2>/dev/null || true
      return 124
    fi
    sleep 5
    waited=$((waited + 5))
  done
  wait "$run"
}

status=0
run_test || status=$?
if [ "$status" = 124 ]; then
  echo "::warning::The bridge test stopped answering after ${LIMIT}s. Trying once more on a restarted simulator."
  xcrun simctl shutdown "$device"
  status=0
  run_test || status=$?
  [ "$status" != 124 ] || echo "::error::The bridge test stopped answering twice."
fi
exit "$status"
