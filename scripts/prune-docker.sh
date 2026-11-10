#!/usr/bin/env bash
# Stop and delete every container, image, network, and volume on the local Docker daemon.
set -euo pipefail

cat <<'EOF'
This removes every container, image, network, and volume visible to the local Docker daemon.
Work outside this catalog is included. There is no undo.
EOF

read -r -p "Type prune to continue: " answer
if [[ "$answer" != "prune" ]]; then
  echo "Aborted."
  exit 1
fi

mapfile -t containers < <(docker ps -aq)
if ((${#containers[@]})); then
  docker rm -f "${containers[@]}"
fi

docker system prune --all --volumes --force
echo "Docker daemon pruned."
