# pi5-stack

Docker Compose stack for self-hosting on a Raspberry Pi 5. Bundles Nextcloud, Pi-hole, Caddy, and Uptime Kuma into one easy setup.

## What is inside

- **Nextcloud** (port 8080): Your own cloud storage, calendar, contacts, and office suite. Backed by MariaDB.
- **Pi-hole** (port 8081): Network-wide ad blocker and DNS server. Blocks ads on every device on your LAN.
- **Uptime Kuma** (port 3001): Status monitoring dashboard with a nice web UI. Checks that your services are actually up.
- **Caddy** (ports 80/443): Reverse proxy with automatic HTTPS. Routes traffic to the other services and handles TLS certificates.

## Requirements

- Raspberry Pi 5 (4 GB or 8 GB RAM recommended)
- Raspberry Pi OS 64-bit (Bookworm) or similar ARM64 Linux
- Docker and Docker Compose installed
- A domain name pointing to your Pi (for automatic HTTPS with Caddy)
- At least 16 GB free on your SD card or SSD

## Quick start

1. Clone the repo:

```bash
git clone https://github.com/cappy-dev/pi5-stack.git
cd pi5-stack
```

2. Copy the example environment file and edit it:

```bash
cp .env.example .env
nano .env
```

Fill in real passwords and your domain name. Do not leave any `changeme` values.

3. Run the setup helper:

```bash
chmod +x setup.sh
./setup.sh start
```

The script checks for Docker, verifies your .env, pulls images, and starts everything.

4. Open your services:

- Nextcloud: `https://your-domain` (via Caddy) or `http://pi-ip:8080` (direct)
- Pi-hole admin: `http://pi-ip:8081/admin`
- Uptime Kuma: `http://pi-ip:3001`

5. Point your router DNS to your Pi IP to enable network-wide ad blocking.

## Manual start (no helper script)

```bash
cp .env.example .env
# edit .env with your values
docker compose pull
docker compose up -d
```

## Commands

The `setup.sh` helper supports a few subcommands:

```bash
./setup.sh start    # check prerequisites and start the stack
./setup.sh stop     # stop all services and preserve data
./setup.sh backup   # export volume data to backups/ directory
./setup.sh help     # show usage info
```

## Configuration

### .env file

| Variable | What it does |
|---|---|
| TZ | Timezone (e.g. America/New_York) |
| NC_ADMIN_USER | Nextcloud admin username |
| NC_ADMIN_PASSWORD | Nextcloud admin password |
| NC_DB_ROOT_PASSWORD | MariaDB root password |
| NC_DB_PASSWORD | MariaDB nextcloud user password |
| NC_DOMAIN | Domain for Nextcloud and Caddy HTTPS |
| PIHOLE_PASSWORD | Pi-hole web admin password |

### Caddyfile

The included Caddyfile routes traffic like this:

- `your-domain` on port 443 proxied to Nextcloud
- Port 8081 proxied to Pi-hole web admin
- Port 3001 proxied to Uptime Kuma

Edit the Caddyfile to add more services or change routes. After editing:

```bash
docker compose restart caddy
```

### Pi-hole DNS settings

By default Pi-hole uses Cloudflare DNS (1.1.1.1 and 1.0.0.1). Change this in the Pi-hole web admin under Settings > DNS after your first login.

## Backing up

```bash
./setup.sh backup
```

This creates a timestamped directory under `backups/` with tar.gz archives of each Docker volume. Restore is manual: stop the stack, extract archives into the corresponding volumes, and restart.

## Restoring from backup

```bash
docker compose down
docker run --rm -v pi5-stack_nextcloud_data:/target -v /path/to/backups/20260625:/source alpine tar xzf /source/pi5-stack_nextcloud_data.tar.gz -C /target
docker compose up -d
```

Repeat for each volume you need to restore.

## Updating

```bash
docker compose pull
docker compose up -d
```

This pulls the latest images and recreates containers that changed. Your data in volumes is preserved.

## Stopping

```bash
./setup.sh stop
```

Or manually:

```bash
docker compose down
```

Data volumes survive `down`. To remove everything including data:

```bash
docker compose down -v
```

## Resource notes

- Nextcloud is the heaviest service. Expect about 600 MB RAM at idle, more during sync.
- Pi-hole uses roughly 50 MB RAM.
- Uptime Kuma uses roughly 80 MB RAM.
- Caddy uses roughly 20 MB RAM.
- Total idle RAM: roughly 750 MB to 1 GB depending on Nextcloud activity.
- A Pi 5 with 4 GB RAM runs the full stack comfortably. An 8 GB model has plenty of headroom for adding more services.

## Security notes

- Change all default passwords in .env before starting.
- Keep your .env file private. Never commit it to version control.
- Caddy automatically provisions TLS certificates via Let's Encrypt for your domain.
- Pi-hole blocks ad and tracking domains for all devices using it as their DNS server.
- Consider enabling Tailscale or WireGuard for remote access instead of exposing ports publicly.

## License

MIT
