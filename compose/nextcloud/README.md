# Nextcloud stack

- Nextcloud v21
- MySQL 8
- Redis 6
- Collabora
- Customizable Nextcloud `www-data` user UID/GID to map to existing FS permissions

### Fix /data permissions

```bash
docker-compose exec nextcloud chown -R www-data:www-data /data
```

### Use CLI tool

```bash
docker-compose exec -u www-data nextcloud php occ
```

### Cron jobs

```bash
docker-compose exec -u www-data nextcloud php occ background:cron
chmod -x ./cron.sh
```

Then add these cron jobs to your **host** crontab.

```
0 0 * * * ~/docker-server-env/nextcloud/cron.sh
```

### Collabora config

```bash
docker-compose exec -u www-data nextcloud php occ config:app:set --value https://${COLLABORA_HOSTNAME} richdocuments wopi_url
docker-compose exec -u www-data nextcloud php occ richdocuments:activate-config
```
