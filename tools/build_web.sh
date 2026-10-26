#!/usr/bin/env bash
# Builds the web panel with .env compiled in.
#
# Flutter has no runtime .env - a web build is static files - so every
# KEY=VALUE here becomes a --dart-define the compiler bakes in. Lines that are
# blank or start with # are skipped.
#
#   ./tools/build_web.sh                 # release build, .env
#   ./tools/build_web.sh --profile       # anything extra is passed to flutter
set -euo pipefail

cd "$(dirname "$0")/.."
ENV_FILE="${ENV_FILE:-.env}"

defines=()
if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
    defines+=("--dart-define=${line%$'\r'}")
  done < "$ENV_FILE"
  echo "Using $ENV_FILE (${#defines[@]} value(s))"
else
  echo "No $ENV_FILE - building with the defaults compiled into the code"
fi

exec flutter build web --release "${defines[@]}" "$@"
