#!/usr/bin/bash

# replaces the `docker volume prune -a -f` line in runner-cleanup.sh
cutoff=$(date -d '2 hours ago' +%s)
docker volume ls -q -f dangling=true | { grep '^runner-' || true; } | while read -r v; do
  created=$(date -d "$(docker volume inspect -f '{{.CreatedAt}}' "$v")" +%s)
  [ "$created" -lt "$cutoff" ] && docker volume rm "$v" >/dev/null || true
done
