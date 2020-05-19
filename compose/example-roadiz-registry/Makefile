# Upgrade App docker image and migrate it
upgrade : 
    docker-compose pull app
    # docker-compose up -d --force-recreate --no-deps app varnish
    docker-compose up -d --force-recreate --no-deps app
    docker-compose exec --user www-data app make migrate
    docker-compose exec app chown -R www-data:www-data app files web
