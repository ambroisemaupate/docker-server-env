# Cap (standalone)

Self-hosted [Cap](https://trycap.dev/guide/standalone/) — a lightweight,
privacy-friendly proof-of-work CAPTCHA. `cap` app + `valkey` for storage.

## Deploy

```bash
cp .env.dist .env   # then set HOSTNAME and a 32+ char ADMIN_KEY
docker compose up -d
```

The instance must be publicly reachable so the widget can talk to it. Traefik
routes `${HOSTNAME}` to the app (port 3000, no host port binding).

## Usage

1. Open `https://${HOSTNAME}` and log in with `ADMIN_KEY`.
2. Create a site key in the dashboard.
3. Note the **site key** and **secret key** for your application.

No backup profile: state is challenge tokens in Valkey, disposable by design.
Site/secret keys live in your app config, not here.
