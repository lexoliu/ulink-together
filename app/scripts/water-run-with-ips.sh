#!/usr/bin/env bash
set -euo pipefail

# Runs `water run` and prints the newest macOS crash report (.ips) if one appears.
# You can override the report filename prefix via WATERUI_CRASH_NAME (default: WaterUIApp).

crash_name="${WATERUI_CRASH_NAME:-WaterUIApp}"
ips_dir="${HOME}/Library/Logs/DiagnosticReports"
stamp="$(mktemp -t water-run-ips.XXXXXX)"
trap 'rm -f "$stamp"' EXIT

touch "$stamp"

water run "$@"
status=$?

if [[ -d "$ips_dir" ]]; then
  # Find any reports created after we started.
  mapfile -t ips < <(find "$ips_dir" -maxdepth 1 -type f -name "${crash_name}-*.ips" -newer "$stamp" 2>/dev/null)
  if (( ${#ips[@]} > 0 )); then
    latest="$(ls -t "${ips[@]}" | head -n 1)"
    echo "Crash report detected: ${latest}"
  else
    echo "No new ${crash_name} crash report found."
  fi
else
  echo "Crash report directory not found: ${ips_dir}"
fi

exit "$status"
