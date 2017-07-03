# Docker server environment scripts and configurations

This repository is meant to get a configuration set for installing a fresh server for *Docker* hosting.
It’s specialized for **my personal usage**, but if it fits your needs, feel free to use it and give your feedback.

## Base path

All scripts and configurations files are written in order to perform **in** `/root/docker-server-env` folder.
Please, adapt them if you want to clone this git repository elsewhere.

## Base installation

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

## Docker images to use

* *jwilder/nginx-proxy*: I disabled *HTTP/2* due to strange errors with *Dropzone.js* (file upload SSL HTTP/2 proxied to HTTP/1.1)
* *alastaircoote/docker-letsencrypt-nginx-proxy-companion*: For automatic *Let’s encrypt* certificate issuing and configuration
* *roadiz/standard-edition* (for PHP7 and Nginx 1.9.11+)
* *solr* (I limit heap size to 256m because we don’t usually use big document data, and it can be painful on a small VPS server)
* *ambroisemaupate/ftp-backup*
* *ambroisemaupate/light-ssh*, For SSH access directly inside your container with some useful command as `mysqldump`, `git` and `composer`.
* *ambroisemaupate/mariadb*

## Naming conventions and containers creation *without docker-compose*

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

## Using *docker-compose*

You’ll find examples to launch *front-proxy* and *Roadiz* based containers with *docker-compose*
in `compose/` folder. Just copy the sample `example-se/` folder naming it with your website reference.

```bash
cp -a ./compose/example-se ./compose/mywebsite.tld
```

Then, use `docker-compose up -d --force-recreate` to create in background all your websites containers.

We need to use [`bridge` networking](https://github.com/jwilder/nginx-proxy/issues/502) with *docker-compose* to be able
to discover your containers from other global containers, such as the `front-proxy` and your daily backups.
See https://docs.docker.com/compose/networking/ for further details.

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
00 7 * * * sync && echo 3 | tee /proc/sys/vm/drop_caches
# etc
```

## Clean up backups

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

