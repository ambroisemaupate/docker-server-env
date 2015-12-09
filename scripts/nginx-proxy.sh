#!/bin/bash
#

docker run  -d -p 80:80 -p 443:443 \
            --name="front-proxy" \
            -v /var/run/docker.sock:/tmp/docker.sock \
            -v /etc/letsencrypt/archive:/etc/letsencrypt/archive:ro\
            -v /etc/letsencrypt/live:/etc/letsencrypt/live:ro \
            -v /root/docker-server-env/front-proxy/htpasswd:/etc/nginx/htpasswd:ro \
            -v /root/docker-server-env/front-proxy/certs:/etc/nginx/certs:ro \
            -v /root/docker-server-env/front-proxy/vhost.d:/etc/nginx/vhost.d:ro \
            -v /root/docker-server-env/front-proxy/nginx-proxy.conf:/etc/nginx/conf.d/nginx-proxy.conf:ro \
            --restart="always" \
            jwilder/nginx-proxy
