# Matomo

- [Official Matomo image](https://hub.docker.com/_/matomo/)
- [Matomo documentation](https://matomo.org/docs/)

## Upgrading Matomo

Upgrade Matomo from website interface, then run the following command:

```shell
docker-compose exec app php /var/www/html/console core:update
```

## Backup

Backup script uses `ambroisemaupate/s3-backup` image to back up the whole `/var/www/html` directory and database. 
And it's run by a cron job:

```crontab
0 1 * * * cd /path/to/docker-server-env/compose/a.mysite.com && /usr/local/bin/docker-compose run --rm --no-deps backup
```
