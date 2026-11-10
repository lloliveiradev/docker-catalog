#!/usr/bin/env bash
# Parse every stack with Compose. Fails on invalid YAML or unresolved required variables.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
status=0

while IFS= read -r file; do
  dir="$(dirname "$file")"
  echo "==> ${file#"$root"/}"
  if ! docker compose --project-directory "$dir" -f "$file" config >/dev/null; then
    status=1
  fi
done < <(find "$root" -name compose.yaml -not -path '*/.git/*' | sort)

exit "$status"
