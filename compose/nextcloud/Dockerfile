FROM nextcloud:21

ARG USER_UID=1000
ARG GROUP_UID=1000

RUN usermod -u $USER_UID www-data && \
    groupmod -g $GROUP_UID www-data && \
    id www-data && \
    mkdir -p /data && \
    chown -R www-data:www-data /data

VOLUME /data
