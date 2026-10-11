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
echo "Atuin server is running on port 8888. Registration is closed."
echo ""
echo "To create the first account, open registration, register, then close it:"
echo "  ATUIN_OPEN_REGISTRATION=true docker compose -f $CONFIG_DIR/docker-compose.yaml up -d"
echo "  atuin register -u <username> -e <email>"
echo "  docker compose -f $CONFIG_DIR/docker-compose.yaml up -d"
echo "  atuin sync"
echo ""
echo "On each other client, with the key from 'atuin key' on a logged-in machine:"
echo "  atuin login -u <username> -k <key>"
echo "  atuin sync"
