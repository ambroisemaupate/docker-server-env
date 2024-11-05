cache:
	docker compose exec -u www-data app php bin/console cache:clear

migrate:
	docker compose exec -u www-data app php bin/console doctrine:migrations:migrate
	docker compose exec -u www-data app php bin/console themes:migrate ./src/Resources/config.yml
