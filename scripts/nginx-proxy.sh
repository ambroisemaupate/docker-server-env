#!/bin/bash
#
#
# We need to use volumes for
# /etc/letsencrypt/archive and
# /etc/letsencrypt/live to avoid dangling symlinks
# with SSL certs
#
#
docker stop front-proxy front-proxy-letsencrypt;
docker rm front-proxy front-proxy-letsencrypt;

docker run  -d -p 80:80 -p 443:443 \
            --name="front-proxy" \
            -v /var/run/docker.sock:/tmp/docker.sock \
            -v /root/docker-server-env/front-proxy/htpasswd:/etc/nginx/htpasswd:ro \
            -v /root/docker-server-env/front-proxy/certs:/etc/nginx/certs:ro \
            -v /root/docker-server-env/front-proxy/vhost.d:/etc/nginx/vhost.d \
            -v /root/docker-server-env/front-proxy/html:/usr/share/nginx/html \
            -v /root/docker-server-env/front-proxy/nginx-proxy.conf:/etc/nginx/conf.d/nginx-proxy.conf:ro \
            --restart="always" \
            jwilder/nginx-proxy

docker run  -d \
            --name="front-proxy-letsencrypt" \
            -v /root/docker-server-env/front-proxy/certs:/etc/nginx/certs:rw \
            --volumes-from "front-proxy" \
            -v /var/run/docker.sock:/var/run/docker.sock:ro \
            --restart="always" \
            jrcs/letsencrypt-nginx-proxy-companion
