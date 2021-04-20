#!/bin/bash

docker exec nextcloud_redis redis-cli FLUSHALL
docker exec --user www-data nextcloud php occ files:scan --all
docker exec --user www-data nextcloud php occ files:scan-app-data
exit 0
