#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "${DISCORD_APPLICATION_ID:-}" ]; then
  echo "DISCORD_APPLICATION_ID is required" >&2
  exit 1
fi

id="$DISCORD_APPLICATION_ID"

replace_scheme() {
  local file="$1"
  local tmp
  tmp="$(mktemp)"
  sed \
    -e "s/discord-__DISCORD_APPLICATION_ID__/discord-${id}/g" \
    -e "s/discord-[0-9][0-9]*/discord-${id}/g" \
    "$file" > "$tmp"
  mv "$tmp" "$file"
}

replace_scheme "$root/android/app/src/main/AndroidManifest.xml"
replace_scheme "$root/ios/Runner/Info.plist"
