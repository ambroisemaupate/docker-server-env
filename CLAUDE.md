# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

A Docker server provisioning and compose template system for hosting multiple services on a single Debian/Ubuntu server. Designed for personal/agency use at `~/docker-server-env` (the scripts assume this path).

## Provisioning the server

```bash
# Full install (postfix + IP blacklist)
sudo bash install.sh --email admin@example.com --user debian

# Skip postfix (e.g. managed externally)
sudo bash install.sh --skip-postfix --user debian

# Skip IP blacklist (when Ansible handles it)
sudo bash install.sh --email admin@example.com --user debian --skip-blacklist

# Setup Ansible user
sudo bash init-ansible-user.sh
```

`install.sh` is idempotent-ish. It auto-detects Debian vs Ubuntu, installs Docker CE, creates the `frontproxynet` bridge network, configures fail2ban, logrotate, and optionally postfix.

## Deploying services

Each `compose/` subdirectory is a standalone stack. The pattern is always:

```bash
cd compose/<service>/
cp .env.dist .env        # then edit .env with real values
cp compose.yml.dist compose.yml   # if a .dist variant exists
docker compose up -d
```

Some stacks (like `example-roadiz-v2`) ship a ready `compose.yml` without a `.dist` variant.

## Architecture: network and routing

**All services communicate through one external Docker network: `frontproxynet`.**

- Created by `install.sh` as a bridge network
- Traefik attaches to it and reads container labels to configure routing
- Application stacks also declare a private `default` network for internal service-to-service communication (db, redis, etc.)
- Services are never exposed via port bindings — they're routed exclusively through Traefik labels

## Traefik setup (`compose/traefik/`)

Traefik v3.x is the single entry point for all HTTP/HTTPS traffic.

Key files:
- `traefik.toml` (copy from `traefik.sample.toml`): static config — entrypoints, Let's Encrypt resolver, Prometheus metrics on `:8899`, JSON access logs for fail2ban
- `acme.json` (chmod 600): Let's Encrypt certificate storage
- `certs/`: wildcard certificate files (bind-mounted read-only)
- `conf.d/`: dynamic TLS config watched by `[providers.file]`
- `.env`: dashboard host/auth (`htpasswd -n` format), IP ranges

HTTP→HTTPS redirect is handled at the entrypoint level in `traefik.toml`, not per-service.

## Traefik label conventions (Roadiz example)

```yaml
- "traefik.enable=true"
- "traefik.http.services.${APP_NAMESPACE}.loadbalancer.server.port=80"
- "traefik.http.routers.${APP_NAMESPACE}.rule=Host(${HOSTNAME})"
- "traefik.http.routers.${APP_NAMESPACE}.tls.certresolver=letsencrypt"
- "traefik.http.routers.${APP_NAMESPACE}.middlewares=${APP_NAMESPACE}Redirectregex,${APP_NAMESPACE}Sts"
# HSTS
- "traefik.http.middlewares.${APP_NAMESPACE}Sts.headers.stsseconds=31536000"
# www redirect
- "traefik.http.middlewares.${APP_NAMESPACE}Redirectregex.redirectregex.regex=${REDIRECT_REGEX}"
- "traefik.http.middlewares.${APP_NAMESPACE}Redirectregex.redirectregex.replacement=${REDIRECT_REPLACEMENT}"
```

Labels go on the container that Traefik should route to (typically `varnish` for Roadiz, or the app container directly). The `APP_NAMESPACE` env var must be unique per stack to avoid middleware name collisions across stacks.

## Roadiz v2 stack (`compose/example-roadiz-v2/`)

Full production stack: MySQL 8.0 → PHP-FPM app → Nginx → Varnish → Traefik.

- `worker` and `cron` services `extend` the `app` service with different entrypoints
- Restic backup services (`backup_files`, `backup_mysql`, `forget`) are run on-demand via `docker compose run`
- JWT keys (`jwt_private.pem`, `jwt_public.pem`) are generated on the host and bind-mounted read-only
- The compose `.env` file is bind-mounted as `.env.local` inside the PHP container

## Backup strategy

Uses `ambroisemaupate/restic-database` for MySQL dumps + Restic for S3 incremental backups:

```bash
docker compose run --rm backup_files
docker compose run --rm backup_mysql
docker compose run --rm forget
```

## Observability (`compose/metrics/`)

Prometheus scrapes Traefik's `:8899` metrics endpoint. Grafana dashboards are provisioned automatically from `compose/metrics/provisioning/`.

