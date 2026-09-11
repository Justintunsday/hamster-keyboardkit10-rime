#!/usr/bin/env bash
# Run the real first-launch RIME deployment flow in an iOS Simulator.
set -euo pipefail

: "${SIMULATOR_APP_PATH:?SIMULATOR_APP_PATH must point to a built Hamster.app}"

bundle_id="${RIME_SIMULATOR_BUNDLE_ID:-dev.fuxiao.app.Hamster}"
app_group="${RIME_SIMULATOR_APP_GROUP:-group.dev.fuxiao.app.Hamster}"
timeout_seconds="${RIME_SIMULATOR_TIMEOUT_SECONDS:-180}"
artifact_dir="${RIME_SIMULATOR_ARTIFACT_DIR:-${RUNNER_TEMP:-/tmp}/rime-simulator-deployment}"

mkdir -p "$artifact_dir"
launch_log="$artifact_dir/simctl-launch.log"
simulator_log="$artifact_dir/simulator.log"
tree_listing="$artifact_dir/container-tree.txt"
screenshot="$artifact_dir/hamster-after-deployment.png"
device_udid=""

collect_artifacts() {
  if [[ -z "$device_udid" ]]; then
    return
  fi

  xcrun simctl spawn "$device_udid" log show --style compact --last 10m \
    --predicate "process == \"Hamster\"" > "$simulator_log" 2>&1 || true
  xcrun simctl io "$device_udid" screenshot "$screenshot" >/dev/null 2>&1 || true
}
trap collect_artifacts EXIT

if [[ ! -d "$SIMULATOR_APP_PATH" ]]; then
  echo "Simulator app does not exist: $SIMULATOR_APP_PATH" >&2
  exit 1
fi

# Use an already installed device on the runner. The workflow selects an Intel
# runner because the checked-in librime simulator slice is x86_64.
device_udid="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ { print $2; exit }')"
if [[ -z "$device_udid" ]]; then
  echo "No available iPhone Simulator device was found." >&2
  exit 1
fi

echo "Using Simulator device: $device_udid"
xcrun simctl boot "$device_udid" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$device_udid" -b

# Uninstalling this one test bundle gives every CI run a true first-launch
# path, including the app's bundled SharedSupport and rime-ice archive.
xcrun simctl uninstall "$device_udid" "$bundle_id" >/dev/null 2>&1 || true
xcrun simctl install "$device_udid" "$SIMULATOR_APP_PATH"

data_container="$(xcrun simctl get_app_container "$device_udid" "$bundle_id" data)"
documents_dir="$data_container/Documents"
rime_dir="$documents_dir/Rime"
build_dir="$rime_dir/build"

echo "Launching $bundle_id"
xcrun simctl launch "$device_udid" "$bundle_id" > "$launch_log" 2>&1

deadline=$(( $(date +%s) + timeout_seconds ))
deployment_ready=0
while (( $(date +%s) < deadline )); do
  if [[ -f "$build_dir/hamster.plist" ]] &&
     find "$build_dir" -type f -name 'rime_ice*.bin' -print -quit | grep -q .; then
    deployment_ready=1
    break
  fi
  sleep 5
done

find "$documents_dir" -maxdepth 5 -print 2>/dev/null | sort > "$tree_listing" || true

if [[ "$deployment_ready" -ne 1 ]]; then
  echo "RIME deployment did not produce the expected build files within ${timeout_seconds}s." >&2
  echo "Expected: $build_dir/hamster.plist and at least one $build_dir/rime_ice*.bin" >&2
  cat "$tree_listing" >&2 || true
  exit 1
fi

# deployment() copies the compiled data into the App Group for the keyboard.
# Resolving this container proves that the Simulator-installed app retained the
# same entitlement needed by both keyboard extensions.
group_container="$(xcrun simctl get_app_container "$device_udid" "$bundle_id" "$app_group" 2>/dev/null || true)"
if [[ ! -d "$group_container" ]]; then
  # Older simctl versions only support the aggregate groups query. Its
  # output may include several unrelated groups, so compare the group ID in
  # the first field exactly and preserve the complete path after removing it.
  group_container="$(xcrun simctl get_app_container "$device_udid" "$bundle_id" groups 2>/dev/null | awk -v group="$app_group" '$1 == group { $1=""; sub(/^[[:space:]]+/, ""); print; exit }')"
fi
if [[ ! -d "$group_container" ]]; then
  echo "Could not resolve App Group container for $app_group." >&2
  exit 1
fi
group_rime_dir="$group_container/InputSchema/Rime"
group_build_dir="$group_rime_dir/build"
if [[ ! -f "$group_build_dir/hamster.plist" ]] ||
   ! find "$group_build_dir" -type f -name 'rime_ice*.bin' -print -quit | grep -q .; then
  echo "RIME build output was not copied to App Group container: $group_build_dir" >&2
  find "$group_container" -maxdepth 6 -print 2>/dev/null | sort >&2 || true
  exit 1
fi

collect_artifacts
if grep -Eiq 'RIME (deploy|start) error|App Group.*(unavailable|不可用)|crash' "$simulator_log"; then
  echo "RIME deployment log contains an error:" >&2
  grep -Ei 'RIME (deploy|start) error|App Group.*(unavailable|不可用)|crash' "$simulator_log" >&2 || true
  exit 1
fi

echo "RIME Simulator deployment passed."
echo "Sandbox build: $build_dir"
echo "App Group build: $group_build_dir"
find "$group_build_dir" -type f -name 'rime_ice*.bin' -print | sort
