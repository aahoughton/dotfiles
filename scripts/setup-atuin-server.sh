#!/bin/bash
# Set up self-hosted atuin sync server
# Run manually on the machine that will host the server

set -euo pipefail

CONFIG_DIR="$HOME/.config/atuin"

if ! command -v docker &>/dev/null; then
    echo "Docker is not available. Install OrbStack or Docker Desktop first."
    exit 1
fi

echo "Starting atuin server..."
docker compose -f "$CONFIG_DIR/docker-compose.yaml" up -d

echo ""
echo "Atuin server is running on port 8888."
echo ""
echo "Next steps on each client machine:"
echo "  atuin register -u <username> -e <email> -p <password>"
echo "  atuin sync"
echo ""
echo "Or if already registered on another machine:"
echo "  atuin login -u <username> -p <password>"
echo "  atuin sync"
