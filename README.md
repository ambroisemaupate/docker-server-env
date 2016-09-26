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
apt-get install ntp ntpdate nano git htop curl curlftpfs zsh fail2ban postfix mailutils;

#
# Install oh-my-zsh
#
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

#
# Clone this repository in root’s home
#
git clone https://github.com/ambroisemaupate/docker-server-env.git /root/docker-server-env;
```

* Copy the sample `.zshrc` in your home folder to enable git and docker plugins.
* Copy the sample `etc/fail2ban/jail.conf` in real location to enable ssh monitoring with fail2ban.
* Add your email in `/etc/aliases` to receive all *root* emails and type `newaliases` to update aliases DB.
* Reload Postfix config `postfix reload`
* Create the `/mnt/ftpbackup` mount point for FTP backup: `mkdir -p /mnt/ftpbackup`

## Docker images to use

* *jwilder/nginx-proxy*: I disabled *HTTP/2* due to strange errors with *Dropzone.js* (file upload SSL HTTP/2 proxied to HTTP/1.1)
* *jrcs/letsencrypt-nginx-proxy-companion*: For automatic *Let’s encrypt* certificate issuing and configuration
* *roadiz/roadiz* (for PHP56 and Nginx 1.6.1+) and *ambroisemaupate/roadiz* (for PHP7 and Nginx 1.9.11+)
* *solr* (I limit heap size to 256m because we don’t usually use big document data, and it can be painful on a small VPS server)
* *ambroisemaupate/ftp-backup*
* *ambroisemaupate/light-ssh*, For SSH access directly inside your container with some useful command as `mysqldump`, `git` and `composer`.
* *maxexcloo/mariadb*

## Naming conventions and containers creation

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
docker run -d --name="mysite_DB" -v mysite_DBDATA:/data -e "MARIADB_PASS=password" -e "MARIADB_USER=mysite" --restart="always" maxexcloo/mariadb;
```

- One SSH *process* container: `mysite_SSH` using *maxexcloo/mariadb* image. You’ll have to link
your *MariaDB* container if you want to dump your database with `mysqldump`.

```bash
docker run -d --name="mysite_SSH" -e PASS=xxxxxxxx -v mysite_DATA:/data --link="mysite_DB:mariadb" -p 22 ambroisemaupate/light-ssh;
```

- One Roadiz *process* container: `mysite` using *ambroisemaupate/roadiz* image — *see create-roadiz7.sh.sample script*

## Back-up containers

In order to backup your containers to your FTP. Duplicate `scripts/bck-mysite.sh.sample`
file without `.sample` suffix for each of your websites.
Fill all variables in the `scripts/ftp-credentials.sh`. Make sure you are using a *data* container to hold your site contents.
For example, for `mysite` Roadiz container, all data must be stored in `mysite_DATA` container.

```bash
# Crontab
# m h  dom mon dow   command
00 0 * * * /bin/bash ~/docker-server-env/scripts/bck-mysite.sh >> ~/docker-server-env/bckup_logs/bck-mysite.log
20 0 * * * /bin/bash ~/docker-server-env/scripts/bck-mysecondsite.sh >> ~/docker-server-env/bckup_logs/bck-mysecondsite.log
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

