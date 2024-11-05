CONTAINER=exampleroadizregistry_app_1
BCKUP_PATH=/var/www/html/app
BCKUP_PREFIX=roadiz_`date "+%F"`

# Upgrade App docker image and migrate it
upgrade:
	docker compose pull app
	# docker compose up -d --force-recreate --no-deps app varnish
	docker compose up -d --force-recreate --no-deps app
	docker compose exec --user www-data app make migrate
	docker compose exec app chown -R www-data:www-data app files web

# Backup SQL and files, then copy them from app to host
backup:
	docker compose exec --user www-data app bin/roadiz database:dump -cg
	docker compose exec --user www-data app bin/roadiz files:export
	docker compose exec --user www-data app ls -lah app
	docker cp ${CONTAINER}:${BCKUP_PATH}/${BCKUP_PREFIX}.sql.gz ./
	docker cp ${CONTAINER}:${BCKUP_PATH}/${BCKUP_PREFIX}.zip ./
	docker compose exec --user www-data app rm ${BCKUP_PATH}/${BCKUP_PREFIX}.sql.gz
	docker compose exec --user www-data app rm ${BCKUP_PATH}/${BCKUP_PREFIX}.zip
	ls -lah .
