# Docker server environment scripts and configurations

This repository is meant to get a configuration set for installing a fresh server for *Docker* hosting.
It’s specialized for **my personal usage**, but if it fits your needs, feel free to use it and give your feedback.

## Base path

All scripts and configurations files are written in order to perform **in** `/root/docker-server-env` folder.
Please, adapt them if you want to clone this git repository elsewhere.

## Base installation

Skip this part if your hosting provider has already provisionned your server with latest
*docker* and *docker-compose* services.

```bash
#
# Base apps
#
apt-get update;
apt-get install sudo curl nano git zsh;

#
# Install oh-my-zsh
#
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

#
# Clone this repository in root’s home
#
git clone https://github.com/ambroisemaupate/docker-server-env.git /root/docker-server-env;

#
# Execute base installation
# It will install more lib, secure postfix and pull base docker images
#
cd /path/to/docker-server-env
#
# Pass DISTRIB env to install [ubuntu/debian]
# sudo DISTRIB="debian" bash ./install.sh if not root
DISTRIB="debian" bash ./install.sh
```

## Some of the docker images I use in this environment

* *traefik*: as the main front proxy. It handles Let’s Encrypt certificates too.
* *jwilder/nginx-proxy* (deprecated, use [Traefik](https://traefik.io/))
* *alastaircoote/docker-letsencrypt-nginx-proxy-companion*: For automatic *Let’s encrypt* certificate issuing and configuration (deprecated, use [Traefik](https://traefik.io/))
* *roadiz/standard-edition* (for PHP7 and Nginx 1.9.11+)
* *solr* (I limit heap size to 256m because we don’t usually use big document data, and it can be painful on a small VPS server)
* *ambroisemaupate/ftp-backup*
* *ambroisemaupate/ftp-cleanup*
* *ambroisemaupate/light-ssh*, For SSH access directly inside your container with some useful command as `mysqldump`, `git` and `composer`.
* *ambroisemaupate/mariadb*: for older *roadiz/standard-edition* and *roadiz/roadiz* images
* *mariadb*: for latest php72-alpine-nginx images and all official docker images
* *gitlab-ce*: If you want to setup your own Gitlab instance with a dedicated registry, all running on *docker*

## Using *docker-compose*

This server environment is optimized to work with *docker-compose* for declaring your services.

You’ll find examples to launch *front-proxy* and *Roadiz* based containers with *docker-compose*
in `compose/` folder. Just copy the sample `example-se/` folder naming it with your website reference.

```bash
cp -a ./compose/example-se ./compose/mywebsite.tld
```

Then, use `docker-compose up -d --force-recreate` to create in background all your websites containers.

We need to use the same *network* with *docker-compose* to be able
to discover your containers from other global containers, such as the `front-proxy` and your daily backups.
See https://docs.docker.com/compose/networking/#configure-the-default-network for further details. Here is the additional lines to append to your custom docker-compose applications:

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

## Using Traefik as main front-end

https://docs.traefik.io/user-guide/docker-and-lets-encrypt/

If `install.sh` script did not setup traefik conf automatically, do:

```bash
cp ./compose/traefik/traefik.sample.toml ./compose/traefik/traefik.toml;
cp ./compose/traefik/.env.dist ./compose/traefik/.env;
touch ./compose/traefik/acme.json;
chmod 0600 ./compose/traefik/acme.json;
```

Then you can start *traefik* service with *docker-compose*

```bash
cd ./compose/traefik;
docker-compose pull && docker-compose up -d --force-recreate;
```

Traefik *dashboard* will be available on a dedicated domain name: edit `./compose/traefik/.env` file to choose a monitoring **host** and **password**. We strongly encourage you to change default *user and password* using `htpasswd -n`.

## Back-up containers

In order to backup your containers to your FTP. Duplicate `./scripts/bck-mysite.sh.sample`
file without `.sample` suffix for each of your websites and `./scripts/ftp-credentials.sh.sample` once.

Fill all variables in the `scripts/ftp-credentials.sh`. Make sure you are using a volume to hold your site contents.
For example, for `mysite` Roadiz container, all data must be stored in `mysite_DATA` volume.

If you’re using *docker-compose*, check your volume name with `docker volume list`.
If not, check your database link name: `--link ${NAME}_DB_1:mariadb` and remove the `_1` (added for *docker-compose* websites).

Then add execution flag to your backup script: `chmod u+x ./scripts/bck-mysite.sh`.

```bash
# Crontab
# m h  dom mon dow   command
00 0 * * * /bin/bash ~/docker-server-env/scripts/bck-mysite.sh >> ~/docker-server-env/bckup_logs/bck-mysite.log
20 0 * * * /bin/bash ~/docker-server-env/scripts/bck-mysecondsite.sh >> ~/docker-server-env/bckup_logs/bck-mysecondsite.log

# If your system seems to be short in RAM because of linux file cache.
# Claim cached memory
# 00 7 * * * sync && echo 3 | tee /proc/sys/vm/drop_caches
# etc
```

## Clean-up FTP backups

### Using *ftp-cleanup* docker image

This method uses [a dedicated docker image](https://github.com/ambroisemaupate/docker/tree/master/ftp-cleanup) to remove
old backup files based on their creation date. It won't delete any files if you only have 2 backup listed in your `FTP_PATH` directory.
Use this method if you can’t use `sshftpfs` of if you want to handle each website backup separately with more control.

Duplicate `./scripts/cleanup-bck-mysite.sh.sample` file without `.sample` suffix for each of your websites.

**Make sure to fill your `FTP_PATH` correctly, if not, it could delete every files in your FTP account.**

```bash
# Crontab
# m h  dom mon dow   command
00 0 * * * /bin/bash ~/docker-server-env/scripts/cleanup-bck-mysite.sh >> ~/docker-server-env/bckup_logs/bck-mysite.log
```

### Using *sshftpfs*

`cleanup-bck.log` will automatically mount your FTP into `/mnt/ftpbackup` to find backups older than **15 days** and delete them.
This script will perform deletions in `/mnt/ftpbackup/docker-bck` folder. If you want to backup permanently some files
create another folder in your FTP.

```bash
# Crontab
# m h  dom mon dow   command
00 12 * * * /bin/bash ~/docker-server-env/scripts/cleanup-bck.sh >> ~/docker-server-env/bckup_logs/cleanup-bck.log
```

## Rotating logs

Add the `etc/logrotate.d/dockerbck` configuration to your real `logrotate.d` system folder.

## Using custom Docker images for Roadiz

Example files can be found in `./compose/example-roadiz-registry/` and `./scripts/bck-example-roadiz-registry.sh.sample`
if you are building custom Roadiz images with direct *volumes* for your websites and private registry such as *Gitlab* one.

## [deprecated] Naming conventions and containers creation *without docker-compose*

For any *Roadiz* website, you should have:

- One *data* container: `mysite_DATA` using `docker volume` command

```bash
docker volume create --name mysite_DATA;
```

- One database *data* container: `mysite_DBDATA` using `docker volume` command

```bash
docker volume create --name mysite_DBDATA;
```

- One database *process* container: `mysite_DB` using *maxexcloo/mariadb* image

```bash
docker run -d --name="mysite_DB" -v mysite_DBDATA:/data -e "MARIADB_USER=mysite" -e "MARIADB_PASS=password" --restart="always" ambroisemaupate/mariadb;
```

- One SSH *process* container: `mysite_SSH` using *ambroisemaupate/light-ssh* image. You’ll have to link
your *MariaDB* container if you want to dump your database with `mysqldump`.

```bash
docker run -d --name="mysite_SSH" -e PASS=xxxxxxxx -v mysite_DATA:/data --link="mysite_DB:mariadb" -p 22 ambroisemaupate/light-ssh;
```

- One Roadiz *process* container: `mysite` using *ambroisemaupate/roadiz* or *roadiz/standard-edition* image — *see create-roadiz.sh.sample script*
