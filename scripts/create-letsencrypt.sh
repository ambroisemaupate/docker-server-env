#!/bin/bash
#
docker stop front-proxy;

# According to official documentation
# http://letsencrypt.readthedocs.org/en/latest/using.html#running-with-docker
docker run -it --rm -p 443:443 -p 80:80 --name letsencrypt \
            -v "/etc/letsencrypt:/etc/letsencrypt" \
            -v "/var/lib/letsencrypt:/var/lib/letsencrypt" \
            quay.io/letsencrypt/letsencrypt:latest auth;

docker start front-proxy;
