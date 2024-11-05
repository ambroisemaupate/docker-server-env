# Matomo

- [Official Matomo image](https://hub.docker.com/_/matomo/)
- [Matomo documentation](https://matomo.org/docs/)

## Installation

- Copy `.env.dist` to `.env` and configure it.
- Launch Matomo installation from website interface.
- Disable browser archiving in `Administration / Système / Paramètres d'archivage` as it is already done by the cron job.
- Configure email sending in `Administration / Système / Paramètres du serveur de courriels`

## Upgrading Matomo

Upgrade Matomo from website interface, then run the following command:

```shell
docker compose exec app php /var/www/html/console core:update
```

## Backup

Backup script uses `ambroisemaupate/s3-backup` image to back up the whole `/var/www/html` directory and database. 
And it's run by a cron job:

```crontab
0 1 * * * cd /path/to/docker-server-env/compose/a.mysite.com && /usr/bin/docker compose run --rm --no-deps backup
```
