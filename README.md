# Local Matrix Stack

A self-hosted Matrix homeserver with video + voice

## Stack

- Matrix Synapse - Matrix server
- LiveKit - WebRTC for video + voice calls
- PostgreSQL
- JWT Service - Token generation for access LiveKit

## Prerequisites

- Docker
- Domains for both Matrix and LiveKit services
- Ports 8008, 7880-7882, 8070 accessible from internet
- Reverse proxy

## Quick Start

1. Clone the repository
   ```bash
   git clone https://github.com/YOUR_USERNAME/local-matrix-stack.git
   cd local-matrix-stack
   ```

2. Configure environment
   ```bash
   cp .env.example .env
   vim .env
   ```

3. Setup and deploy
   ```bash
   ./setup.sh
   docker compose up -d
   ```

4. Register your first user
   ```bash
   docker exec -it matrix-synapse register_new_matrix_user http://localhost:8008
   ```

## Configuration

### Required .env Variables

All 5 variables must be filled in `.env` before running `setup.sh`:

- `MATRIX_SERVER_NAME`: Your Matrix domain (e.g., matrix.example.com)
- `LIVEKIT_DOMAIN`: Your LiveKit domain (e.g., livekit.example.com)
- `REVERSE_PROXY_IP`: Internal/private IP of your reverse proxy server (e.g., 192.168.1.100)
- `POSTGRES_PASSWORD`: Database password (generate with `openssl rand -base64 32`)
- `LIVEKIT_SECRET`: LiveKit API secret (generate with `openssl rand -base64 32`)

The secrets are critical for security - generate them yourself and do not use defaults.

### Reverse Proxy Setup

Configure your reverse proxy to forward:

- `matrix.example.com:443` → `localhost:8008` (Synapse)
- `livekit.example.com:443` → `localhost:7880` (LiveKit WebSocket)

The JWT service on port 8070 is internal and accessed by the reverse proxy

### Example reverse-proxy configuration (nginx)

```nginx
# Matrix homeserver
server {
    listen 443 ssl http2;
    server_name matrix.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    client_max_body_size 250M;

    location / {
        proxy_pass http://localhost:8008;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
        proxy_read_timeout 600s;
    }

    # Well-known endpoints for client discovery
    location /.well-known/matrix/server {
        return 200 '{"m.server": "matrix.example.com:443"}';
        default_type application/json;
        add_header Access-Control-Allow-Origin *;
    }

    location /.well-known/matrix/client {
        return 200 '{"m.homeserver": {"base_url": "https://matrix.example.com"}}';
        default_type application/json;
        add_header Access-Control-Allow-Origin *;
    }
}

# LiveKit WebRTC
server {
    listen 443 ssl http2;
    server_name livekit.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }

    # JWT service for token generation
    location /jwt {
        proxy_pass http://localhost:8070;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Firewall

Open these ports to the internet:

- **UDP**: 7882 (LiveKit media)
- **TCP**: 7881 (LiveKit fallback), 8008 (Synapse), 8070 (JWT service)

## Usage

Register a new user:
```
docker exec -it matrix-synapse register_new_matrix_user http://localhost:8008
```

## Services

| Service | Port | Purpose |
|---------|------|---------|
| Synapse | 8008 | Matrix homeserver API |
| LiveKit | 7880-7882 | Voice/video media streaming |
| JWT Service | 8070 | LiveKit token generation |
| PostgreSQL | 5432 | Database (internal) |

## Updating

```
docker compose pull
docker compose up -d
```
