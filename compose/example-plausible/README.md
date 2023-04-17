# Self-hosted Plausible instance

```
cp .env.dist .env
```

Configure `.env` and `plausible-conf.env` files.


## Check registered users

Right after installing, you should allow registering to allow your team members to create accounts. Then 
pass `DISABLE_REGISTRATION` variable to `true` in  `plausible-conf.env` file.

You still can check who is registered to your instance:

```
docker-compose exec plausible_db psql -U postgres --password -d plausible_dev -c "SELECT * FROM users"
```

## Backup

```crontab
# Plausible
30 4 * * * cd /path/to/docker-server-env/compose/plausible.test; /usr/local/bin/docker-compose run --rm --no-deps backup;
```
