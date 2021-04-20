FROM nextcloud:21

ARG USER_UID=1000
ARG GROUP_UID=1000

RUN usermod -u 1000 www-data && \
    groupmod -g 1000 www-data && \
    id www-data && \
    mkdir -p /data && \
    chown -R www-data:www-data /data

VOLUME /data
