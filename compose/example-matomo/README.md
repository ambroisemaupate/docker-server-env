# Matomo

- [Official Matomo image](https://hub.docker.com/_/matomo/)
- [Matomo documentation](https://matomo.org/docs/)

## Installation

- Copy `.env.dist` to `.env` and configure it.
- Launch Matomo installation from website interface.
- Apply the [recommended config](#recommended-config) (browser archiving is disabled as the `cron` service already archives).
- Configure email sending in `Administration / Système / Paramètres du serveur de courriels`

## Upgrading Matomo

Matomo and MariaDB versions are pinned in `.env` (`MATOMO_VERSION`, `MARIADB_VERSION`).
Matomo code lives in the `matomo` volume: the image entrypoint only copies it when the volume is empty,
so bumping `MATOMO_VERSION` alone upgrades PHP but **not** Matomo. Copy the code from the new image instead.
Do not use the web updater (disabled by `enable_auto_update = 0`, see below): it would make the code drift from the image tag.

```shell
# 1. Maintenance on, stop archiving
docker compose exec -T app php /var/www/html/console config:set 'General.maintenance_mode=1'
docker compose exec -T app php /var/www/html/console config:set 'Tracker.record_statistics=0'
docker compose stop cron
# 2. Backup database and files
docker compose run --rm --no-deps backup
# 3. (optional) Upgrade MariaDB: bump MARIADB_VERSION in .env, MARIADB_AUTO_UPGRADE runs mariadb-upgrade on startup
docker compose pull db && docker compose up -d db
# 4. Bump MATOMO_VERSION in .env, then copy the new code into the volume
docker compose pull app
docker compose run --rm --no-deps --entrypoint sh app -c \
    'tar -C /usr/src/matomo -cf - . | tar -C /var/www/html -xf - && chown -R www-data:www-data /var/www/html'
docker compose up -d app
# 5. Migrate the database and clear caches
docker compose exec -T app php /var/www/html/console core:update --yes
docker compose exec -T app php /var/www/html/console core:clear-caches
# 6. Maintenance off, restart archiving
docker compose exec -T app php /var/www/html/console config:set 'General.maintenance_mode=0'
docker compose exec -T app php /var/www/html/console config:set 'Tracker.record_statistics=1'
docker compose up -d cron
```

Files removed by the new version are not deleted by the copy: *System Check > File integrity* lists them, delete them by hand.
MariaDB cannot be downgraded in place: to roll back, restore the backup dump in a fresh `db` volume with the previous image.

## Recommended config

Matomo always runs behind Traefik, which terminates TLS and forwards `X-Forwarded-*` headers:

```shell
docker compose exec -T app php /var/www/html/console config:set \
    'General.enable_auto_update=0' \
    'General.force_ssl=1' \
    'General.proxy_scheme_headers[]="HTTP_X_FORWARDED_PROTO"' \
    'General.proxy_client_headers[]="HTTP_X_FORWARDED_FOR"' \
    'General.proxy_host_headers[]="HTTP_X_FORWARDED_HOST"' \
    'General.enable_browser_archiving_triggering=0' \
    'General.browser_archiving_disabled_enforce=1' \
    'database.collation="utf8mb4_general_ci"'
```

## Backup

Backup script uses `ambroisemaupate/s3-backup` image to back up the whole `/var/www/html` directory and database. 
And it's run by a cron job:

```crontab
0 1 * * * cd /path/to/docker-server-env/compose/a.mysite.com && /usr/bin/docker compose run --rm --no-deps backup
```
