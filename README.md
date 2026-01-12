# Docker server environment scripts and configurations

This repository is meant to get a configuration set for installing a fresh server for *Docker* hosting.
It’s specialized for **my personal usage**, but if it fits your needs, feel free to use it and give your feedback.

* [Base path](#base-path)
* [Base installation](#base-installation)
  + [Install with postfix](#install-with-postfix)
  + [Install without postfix](#install-without-postfix)
  + [Install without blacklist](#install-without-blacklist)
  + [Install Docker data on different folder](#install-docker-data-on-different-folder)
  + [Enable IPv6 networking](#enable-ipv6-networking)
  + [hub.docker.com mirroring](#hubdockercom-mirroring)
    - [Use registry mirror inside your Gitlab Runners on same host](#use-registry-mirror-inside-your-gitlab-runners-on-same-host)
* [Some of the docker images I use in this environment](#some-of-the-docker-images-i-use-in-this-environment)
* [Using *docker compose*](#using-docker-compose)
* [Using Traefik v3.x as the main front-end](#using-traefik-v3x-as-the-main-front-end)
  + [Enable Traefik dashboard](#enable-traefik-dashboard)
  + [Configure Cloudflare with Traefik](#configure-cloudflare-with-traefik)
* [Back-up containers](#back-up-containers)
  + [Using *docker compose* services](#using-docker-compose-services)
* [Clean-up FTP backups](#clean-up-ftp-backups)
  + [Using *docker compose* services](#using-docker-compose-services-1)
* [Rolling backups](#rolling-backups)
* [Using custom Docker images for Roadiz](#using-custom-docker-images-for-roadiz)
  + [Update and restart your Roadiz image](#update-and-restart-your-roadiz-image)
* [Rotating logs](#rotating-logs)
* [Ban IPs](#ban-ips)
* [Error pages service](#error-pages-service)
  + [Catch-all error page](#catch-all-error-page)
  + [Adapt kernel parameters](#adapt-kernel-parameters)
* [Observability](#observability)
  + [Using *Prometheus* and *Grafana*](#using-prometheus-and-grafana)

## Base path

All scripts and configurations files are written in order to perform **in** `~/docker-server-env` folder.
Please, adapt them if you want to clone this git repository elsewhere.

## Base installation

Skip this part if your hosting provider has already provisioned your server with latest
*docker* and *docker compose* services.

```bash
#
# Base apps
#
sudo apt update;
sudo apt upgrade;
sudo apt install curl nano git zsh;

#
# Install oh-my-zsh
#
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

#
# If you don’t have any password (public key only)
# Change your shell manually…
#
sudo chsh -s /bin/zsh

#
# Clone this repository in root’s home
#
git clone https://github.com/ambroisemaupate/docker-server-env.git ~/docker-server-env;

#
# Execute base installation
# It will install more lib, secure postfix and pull base docker images
#
cd ~/docker-server-env
```

### Install with postfix:
```shell
sudo bash install.sh --email ambroise@rezo-zero.com --user debian
```

### Install without postfix:
```shell
sudo bash install.sh --skip-postfix --user debian
```

### Install without blacklist:

If you want to manage your server with _Rezo Zero Ansible_ `ip_blocklist` role, you may want to skip the blacklist installation
to avoid conflicts.

```shell
sudo bash install.sh --email ambroise@rezo-zero.com --user debian --skip-blacklist
```

### Install Docker data on different folder

When using a dedicated block-storage disk, you may have to change docker default root. **Do not forget to change *containerd* too!**
And make sure you've configured `docker` and `containerd` root folders **before** pulling Docker images and starting containers.

For example, if you mounted your additional drive `/dev/sdb` on `/data`:

1. Stop `docker` and `containerd` services
2. Create `/data/docker` and `/data/containerd` folder with `root` ownership
3. **Change Docker** root folder: `sudo nano /etc/docker/daemon.json`
```json
{
  "data-root": "/data/docker"
}
```
4. **Change Containerd** root folder: `sudo nano /etc/containerd/config.toml`
```
root = "/data/containerd"
state = "/run/containerd"
```
5. Restart `docker` and `containerd`
6. Your system partition (`/`) usage should now stay low:

```shell
# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        20G  7.9G   11G  42% /
/dev/sdb        246G   11G  223G   5% /data
```

### Enable IPv6 networking

If you registered IPv6 and AAAA DNS records for your services, you must enable *Docker* ipv6 networking and make sure
*Traefik* is running on a IPv6 enabled network.

Make sure to [generate a unique local IPv6 range](https://simpledns.plus/private-ipv6) and edit `etc/docker/daemon.json` **before
running** `install.sh` script.
Check your network configuration with `compose/whoami` service which prints your client information.

You can verify if IPv6 is enabled by testing if **traefik** is listening on both interfaces, make sure `frontproxynet` is also
configured with `--ipv6` option to allow traefik listening on `tcp` and `tcp6`:

```bash
netstat -tnlp

tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      2377/docker-proxy   
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      2398/docker-proxy   
tcp6       0      0 :::443                  :::*                    LISTEN      2383/docker-proxy   
tcp6       0      0 :::80                   :::*                    LISTEN      2404/docker-proxy 
```

### hub.docker.com mirroring

Since November 2020, *hub.docker.com* introduced rate limit on API, if you often pull images you'll need to setup a 
Registry mirror. Install and launch `compose/registry-mirror` service with your own *hub.docker.com* credentials in `.env`.

**Only use Registry mirror on private network machines or do not forget to restrict your host access to port 6000.**

Copy `etc/docker/daemon_with_registry.json` to your server `/etc/docker/daemon.json` and restart `docker`, this will setup an insecure Registry mirror on localhost:6000.

#### Use registry mirror inside your Gitlab Runners on same host

Once your Registry mirror is running on `localhost:6000` you may want to use it inside your Gitlab Runners. 

```toml
# /etc/gitlab-runner/config/config.toml
[runners.docker]
    volumes = ["/opt/docker/daemon.json:/etc/docker/daemon.json:ro"]
```

Then configure `/opt/docker/daemon.json` to use your host' local network IP

```json
{
  "registry-mirrors": ["http://192.168.1.xx:6000"],
  "insecure-registries" : ["192.168.1.xx:6000"]
}
```

That way, all gitlab runners will pull Docker image through your host mirror and save precious bandwidth and rate limit.

## Some of the docker images I use in this environment

* *traefik*: as the main front proxy. It handles Let’s Encrypt certificates too.
* *solr* (I limit heap size to 256m because we don’t usually use big document data, and it can be painful on a small VPS server)
* *ambroisemaupate/ftp-backup*: smart FTP/SFTP backup image
* *ambroisemaupate/s3-backup*: smart S3 Object Storage backup image (no need to clean-up, configure lifecycle on your S3 provider)
* *ambroisemaupate/ftp-cleanup*: smart FTP/SFTP backup clean-up image than delete files older than your defined limit. It won’t delete older backup files if they are the only ones available.
* *ambroisemaupate/light-ssh*, For SSH access directly inside your container with some useful command as `mysqldump`, `git` and `composer`.
* *mysql*: for latest php80-alpine-nginx images and all official docker images
* *gitlab-ce*: If you want to setup your own Gitlab instance with a dedicated registry, all running on *docker*
* *plausible/analytics*: Awesome open-source and privacy-friendly analytics tool. Based on https://github.com/plausible/hosting.

## Using *docker compose*

This server environment is optimized to work with *docker compose* for declaring your services.

You’ll find examples to launch *front-proxy* and *Roadiz* based containers with *docker compose*
in `compose/` folder. Just copy the sample `example-se/` folder naming it with your website reference.

```bash
cp -a ./compose/example-se ./compose/mywebsite.tld
```

Then, use `docker compose up -d --force-recreate` to create in background all your websites containers.

We need to use the same *network* with *docker compose* to be able
to discover your containers from other global containers, such as the `front-proxy` and your daily backups.
See https://docs.docker.com/compose/networking/#configure-the-default-network for further details. Here is the additional lines to append to your custom docker compose applications:

```yaml
networks:
  frontproxynet:
    external: true
```

Then add the `frontproxynet` to your backends container that you want to expose to your front-proxy (*traefik* or *nginx-proxy*)

```yaml
services:
  app:
    image: nginx:latest
    networks:
      - default
      - frontproxynet
  db:
    image: mariadb:latest
    networks:
      - default
```

## Using Traefik v3.x as the main front-end

Traefik will be used as a main front-end to route your websites and services. It will also handle SSL certificates with Let’s Encrypt.

HTTP to HTTPS is automatically redirected.

https://docs.traefik.io/providers/docker/

If `install.sh` script did not setup traefik conf automatically, do:

```bash
cp ./compose/traefik/traefik.sample.toml ./compose/traefik/traefik.toml;
cp ./compose/traefik/.env.dist ./compose/traefik/.env;
touch ./compose/traefik/acme.json;
chmod 0600 ./compose/traefik/acme.json;
```

Then you can start *traefik* service with *docker compose*

```bash
cd ./compose/traefik;
docker compose pull && docker compose up -d --force-recreate;
```

Traefik *dashboard* will be available on a dedicated domain name: edit `./compose/traefik/.env` file to choose a monitoring **host** and **password**. We strongly encourage you to change default *user and password* using `htpasswd -n`.

**Warning**: IP whitelisting won’t work correctly if you enabled AAAA (ipv6) record for your domains. Traefik won’t see 
`X-Real-IP`. For the moment, if you need to get correct IP address, just use ipv4. 

### Enable Traefik dashboard

Edit your `traefik.toml` file and add the following lines:

```toml
[api]
  dashboard = true
```

Make sure to add your service labels in `compose.yml` file.

Dashboard will be available on `https://my-domain.tld/dashboard/` URL. **Make sure to add trailing slash after


### Configure Cloudflare with Traefik

- Make sure you set Cloudflare SSL mode to **Full** or **Full (strict)** to avoid SSL errors and `418` errors. https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/ Because *Traefik* will see incoming requests as `http` and not `https` and redirect in loop to 443.
- Add Cloudflare [IPv4 and IPv6 ranges](https://www.cloudflare.com/fr-fr/ips/) to your `traefik.toml` file in `entryPoints.web.forwardedHeaders` / `trustedIPs` section.
- Add them again in `entryPoints.web_secure.forwardedHeaders` / `trustedIPs` section.

## Back-up containers

### Using *docker compose* services

Added *backup* and *backup_cleanup* services to your `compose.yml` file:

```yaml
services:
  #
  # AFTER your app main services (web, db, solr…)
  #
  backup:
    image: ambroisemaupate/ftp-backup
    networks:
      # Container should be on same network as database
      - default
    depends_on:
      # List here your database service
      - db
    environment:
      LOCAL_PATH: /var/www/html
      DB_USER: example
      DB_HOST: db
      DB_PASS: password
      DB_NAME: example
      FTP_PROTO: ftp
      FTP_PORT: 21
      FTP_HOST: ftp.server
      FTP_USER: example
      FTP_PASS: example
      REMOTE_PATH: /home/example/backups/site
    volumes:
      # Populate your local path with your app service volumes
      # this will backup ONLY your critical data, not your app
      # code and vendor.
      - private_files:/var/www/html/files:ro
      - public_files:/var/www/html/web/files:ro
      - gen_src:/var/www/html/app/gen-src:ro

  backup_cleanup:
    image: ambroisemaupate/ftp-cleanup
    networks:
      - default
    environment:
      # Make sure to use the same credentials
      # as backup service
      FTP_PROTO: ftp
      FTP_PORT: 21
      FTP_HOST: ftp.server
      FTP_USER: example
      FTP_PASS: example
      STORE_DAYS: 5
      # this path MUST exists on remote server
      FTP_PATH: /home/example/backups/site
```

Test if your credentials are valid: `docker compose run --rm --no-deps backup && docker compose run --rm --no-deps backup_cleanup`. This should launch the 2 services cleaning up older backups and
creating new ones. One for your files stored in `/var/www/html` (check that you are using your main service volumes here), and a second one for your database dump.

ℹ️ *You can use a `.env` file in your project path to avoid typing FTP and DB credential twice.*

Then add *docker compose* lines to your host `crontab -e` (do not forget to specify your `compose.yml` path):

```bash
MAILTO=""
# crontab

# You must change directory in order to access .env file
# Clean and backup "site_a" files and database at midnight
0  0 * * * cd /root/docker-server-env/compose/site_a && /usr/bin/docker compose run --rm --no-deps backup
0  1 * * * cd /root/docker-server-env/compose/site_a && /usr/bin/docker compose run --rm --no-deps backup_cleanup
# Clean and backup "site_b" files and database 15 minutes later
15 0 * * * cd /root/docker-server-env/compose/site_b && /usr/bin/docker compose run --rm --no-deps backup
15 1 * * * cd /root/docker-server-env/compose/site_b && /usr/bin/docker compose run --rm --no-deps backup_cleanup
```

*backup_cleanup* service uses a FTP/SFTP script that will check files older than `$STORE_DAYS` and delete them after. It will do nothing if there are only one of each *files* and *database* backup available. This is useful to prevent deletion of non-running services by keeping at least one backup. *backup_cleanup* does not use *sshftpfs* volume to perform file listing so you can use it with every FTP/SFTP account.

## Clean-up FTP backups

### Using *docker compose* services

Backup clean-up is already handled by your *docker compose* services (see above).

## Rolling backups

You can add as many backup services as you want to create rolling backups: daily, weekly, monthly: 

```yaml
# …
  # DAILY
  backup_daily:
    image: ambroisemaupate/ftp-backup
    depends_on:
      - db
    environment:
      LOCAL_PATH: /var/www/html
      DB_USER: test
      DB_HOST: db
      DB_PASS: test
      DB_NAME: test
      FTP_PROTO: ftp
      FTP_PORT: 21
      FTP_HOST: ftp.server.test
      FTP_USER: test
      FTP_PASS: test
      REMOTE_PATH: /home/test/backups/daily
    volumes:
      - public_files:/var/www/html/web/files:ro

  backup_cleanup_daily:
    image: ambroisemaupate/ftp-cleanup
    environment:
      FTP_PROTO: ftp
      FTP_PORT: 21
      FTP_HOST: ftp.server.test
      FTP_USER: test
      FTP_PASS: test
      STORE_DAYS: 7
      FTP_PATH: /home/test/backups/daily
  
  # WEEKLY
  backup_weekly:
    image: ambroisemaupate/ftp-backup
    depends_on:
      - db
    environment:
      LOCAL_PATH: /var/www/html
      DB_USER: test
      DB_HOST: db
      DB_PASS: test
      DB_NAME: test
      FTP_PROTO: ftp
      FTP_PORT: 21
      FTP_HOST: ftp.server.test
      FTP_USER: test
      FTP_PASS: test
      REMOTE_PATH: /home/test/backups/weekly
    volumes:
      - public_files:/var/www/html/web/files:ro

  backup_cleanup_weekly:
    image: ambroisemaupate/ftp-cleanup
    environment:
      FTP_PROTO: ftp
      FTP_PORT: 21
      FTP_HOST: ftp.server.test
      FTP_USER: test
      FTP_PASS: test
      STORE_DAYS: 30
      FTP_PATH: /home/test/backups/weekly
  
  # MONTHLY
  backup_monthly:
    image: ambroisemaupate/ftp-backup
    depends_on:
      - db
    environment:
      LOCAL_PATH: /var/www/html
      DB_USER: test
      DB_HOST: db
      DB_PASS: test
      DB_NAME: test
      FTP_PROTO: ftp
      FTP_PORT: 21
      FTP_HOST: ftp.server.test
      FTP_USER: test
      FTP_PASS: test
      REMOTE_PATH: /home/test/backups/monthly
    volumes:
      - public_files:/var/www/html/web/files:ro

  backup_cleanup_monthly:
    image: ambroisemaupate/ftp-cleanup
    environment:
      FTP_PROTO: ftp
      FTP_PORT: 21
      FTP_HOST: ftp.server.test
      FTP_USER: test
      FTP_PASS: test
      STORE_DAYS: 366
      FTP_PATH: /home/test/backups/monthly
```

then launch them once a day, once a week, once a month from your crontab:

```shell
# Rolling backups (do not use same hour of night to save CPU)
# Daily
00 2 * * * cd /root/docker-server-env/compose/site_a && /usr/bin/docker compose run --rm --no-deps backup_daily
30 2 * * * cd /root/docker-server-env/compose/site_a && /usr/bin/docker compose run --rm --no-deps backup_cleanup_daily
# Weekly (on Monday early morning)
00 3 * * 1 cd /root/docker-server-env/compose/site_a && /usr/bin/docker compose run --rm --no-deps backup_weekly
30 3 * * 1 cd /root/docker-server-env/compose/site_a && /usr/bin/docker compose run --rm --no-deps backup_cleanup_weekly
# Monthly (on each 1st day)
00 4 1 * * cd /root/docker-server-env/compose/site_a && /usr/bin/docker compose run --rm --no-deps backup_monthly
30 4 1 * * cd /root/docker-server-env/compose/site_a && /usr/bin/docker compose run --rm --no-deps backup_cleanup_monthly
```

## Using custom Docker images for Roadiz

Example files can be found in `./compose/example-roadiz-registry/` and `./scripts/bck-example-roadiz-registry.sh.sample`
if you are building custom Roadiz images with direct *volumes* for your websites and private registry such as *Gitlab* one.

Copy `.env.dist` to `.env` to store your secrets at one place.

### Update and restart your Roadiz image

After you update your website image:

```bash
docker compose pull app;
# use --no-deps to avoid recreating db and solr service too.
docker compose up -d --force-recreate --no-deps app;
# if you created a Makefile in your docker image
docker compose exec -u www-data app make cache;
```

## Rotating logs

Add the `etc/logrotate.d/docker-server-env` configuration to your real `logrotate.d` system folder.

**Make sure to adapt `/etc/logrotate.d/docker-server-env` file with your traefik folder location and user.**

## Ban IPs

Fail2Ban is configured with a special *jail* `traefik-auth` to block FORWARD rules for IP that trigger
too much 401 errors in `./compose/traefik/access.log` file. If you need to manually ban an IP
you must use this *chain* because it will prevent FORWARD rules to docker.

Make sure to edit `/etc/fail2ban/jail.d/traefik.conf` with the right `logpath` to *Traefik* `access.log` file.

```dotenv
fail2ban-client set traefik-auth banip <IP>
```

## Error pages service

You can add [custom error pages](https://doc.traefik.io/traefik/middlewares/http/errorpages/#service) to your *traefik* 
services by adding labels to your `compose.yml` file.

All `html` files are stored in `compose/traefik/service-error/html` folder, and served by Nginx in `traefik-service-error` service.
Behind the scene, it is an *Nginx* docker container running with a custom `compose/traefik/service-error/default.conf` configuration: 
all requests except for `/css`, `/img` are redirected to `/404.html` or `/503.html` files.

You can use a custom folder by changing volume path in `compose.yml` file: 

```yaml
volumes:
  - ./service-error/html:/usr/share/nginx/html:ro
  - ./service-error/default.conf:/etc/nginx/conf.d/default.conf:ro
labels:
    # Custom error pages
    - "traefik.http.middlewares.${APP_NAMESPACE}_errors.errors.status=500-599"
    - "traefik.http.middlewares.${APP_NAMESPACE}_errors.errors.service=traefik-service-error-traefik"
    - "traefik.http.middlewares.${APP_NAMESPACE}_errors.errors.query=/{status}.html"
```

### Catch-all error page

Traefik is configured to serve a catch-all error page for all other errors and non-existing services.
It will serve `compose/traefik/service-error/503.html` file.

You can change the catch-all behaviour in `compose/traefik/compose.yml` file by editing `traefik-service-error` service labels.

```yaml
labels:
    - "traefik.enable=true"
    # Serve catch-all error pages on HTTP
    - "traefik.http.routers.traefik-service-error-traefik.priority=1"
    - "traefik.http.routers.traefik-service-error-traefik.rule=HostRegexp(`{host:.+}`)"
    - "traefik.http.routers.traefik-service-error-traefik.entrypoints=http"
    # Serve catch-all error pages on HTTPS
    - "traefik.http.routers.traefik-service-error-traefik-secure.priority=1"
    - "traefik.http.routers.traefik-service-error-traefik-secure.rule=HostRegexp(`{host:.+}`)"
    - "traefik.http.routers.traefik-service-error-traefik-secure.entrypoints=https"
    - "traefik.http.routers.traefik-service-error-traefik-secure.tls=true"
    - "traefik.http.routers.traefik-service-error-traefik-secure.tls.certresolver=letsencrypt"
```

### Adapt kernel parameters

If you are hosting multiple database servers on the same server using Docker, you may want to increase the number of
[`fs.aio-max-nr`](https://www.man7.org/linux/man-pages//man5/proc_sys_fs.5.html) to avoid `EAGAIN` errors.

```shell
# Check current value
sudo cat /proc/sys/fs/aio-max-nr

# Set new value (not persistent)
sudo sysctl -w fs.aio-max-nr=200000
```

If you want this value to be persisted, you can add it in `/etc/sysctl.conf` or any `/etc/sysctl.d/*.conf` file.

## Observability

### Using *Prometheus* and *Grafana*

You can use *Prometheus* and *Grafana* to monitor your server and services. 
An example configuration folder is available in `./compose/metrics/` folder, and Traefik metrics are already enabled in `./compose/traefik/traefik.toml` file.
