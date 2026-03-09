#!/bin/bash
# Matrix Stack Setup Script
# This script configures the stack with user-provided secrets

set -e

echo "=== Local Matrix Stack Setup ==="
echo ""

# Check for .env file
if [ ! -f .env ]; then
    echo "Error: .env file not found. Copy .env.example to .env and edit it."
    exit 1
fi

source .env

# Validate variables
if [ -z "$MATRIX_SERVER_NAME" ] || [ "$MATRIX_SERVER_NAME" = "matrix.example.com" ]; then
    echo "Error: Please set MATRIX_SERVER_NAME in .env"
    exit 1
fi

if [ -z "$LIVEKIT_DOMAIN" ] || [ "$LIVEKIT_DOMAIN" = "livekit.example.com" ]; then
    echo "Error: Please set LIVEKIT_DOMAIN in .env"
    exit 1
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "Error: Please set POSTGRES_PASSWORD in .env"
    exit 1
fi

if [ -z "$LIVEKIT_SECRET" ]; then
    echo "Error: Please set LIVEKIT_SECRET in .env"
    exit 1
fi

# Update LIVEKIT_URL if not set
if [ -z "$LIVEKIT_URL" ]; then
    LIVEKIT_URL="wss://${LIVEKIT_DOMAIN}"
fi

echo ""
echo "Updating configuration files..."

# Create directories
mkdir -p synapse/data
mkdir -p synapse/data/media_store
mkdir -p postgres/data

# Generate Synapse signing key (one-time, persistent)
if [ ! -f synapse/data/${MATRIX_SERVER_NAME}.signing.key ]; then
    echo "Generating Synapse signing key..."
    python3 -c "
import os
key = ''
for _ in range(4):
    key += os.urandom(32).hex()
print(f'ed25519 a_iKyM {key}')
" > synapse/data/${MATRIX_SERVER_NAME}.signing.key
else
    echo "Using existing Synapse signing key"
fi

# Update synapse config
sed -i "s/YOUR_MATRIX_DOMAIN/${MATRIX_SERVER_NAME}/g" synapse/data/homeserver.yaml
sed -i "s/REPLACE_WITH_GENERATED_SECRET/${POSTGRES_PASSWORD}/g" synapse/data/homeserver.yaml

# Update log config
sed -i "s|SERVER_NAME|${MATRIX_SERVER_NAME}|g" synapse/data/log.config

# Update livekit config
sed -i "s/REPLACE_WITH_GENERATED_SECRET/${LIVEKIT_SECRET}/g" livekit/livekit.yaml

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Review and update your reverse proxy configuration"
echo "2. Run: docker compose up -d"
echo "3. Register your first user:"
echo "   docker exec -it matrix-synapse register_new_matrix_user http://localhost:8008"
echo ""
