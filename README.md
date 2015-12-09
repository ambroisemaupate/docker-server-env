# Docker server enviroment scripts and configurations

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
apt-get install ntp ntpdate nano git htop curl curlftpfs zsh fail2ban;

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

## Docker images to use

* jwilder/nginx-proxy
* uay.io/letsencrypt/letsencrypt
* roadiz/roadiz
* solr
* ambroisemaupate/ftp-backup
* maxexcloo/data
* maxexcloo/mariadb

## Naming conventions and containers creation

For any *Roadiz* website, you should have:

- One *data* container: `mysite_DATA` using *maxexcloo/data* image

```bash
docker run -d --name="mysite_DATA" maxexcloo/data
```

- One database *data* container: `mysite_DBDATA` using *maxexcloo/data* image

```bash
docker run -d --name="mysite_DBDATA" maxexcloo/data
```

- One database *process* container: `mysite_DB` using *maxexcloo/mariadb* image

```bash
docker run -d --name="mysite_DB"
           --volumes-from="mysite_DBDATA"
           -e "MARIADB_PASS=password"
           -e "MARIADB_USER=mysite"
           -e "MARIADB_DB=mysite"
           --restart="always"
           maxexcloo/mariadb
```

- One Roadiz *process* container: `mysite` using *roadiz/roadiz* image — *see create-roadiz.sh script*

## Back-up containers

In order to backup your containers to your FTP. Duplicate `scripts/bck-mysite.sh.sample`
file without `.sample` suffix for each of your websites.
Fill all variables in the `scripts/ftp-credentials.sh`. Make sure you are using a *data* container to hold your site contents.
For example, for `mysite` Roadiz container, all data must be stored in `mysite_DATA` container.

```bash
# Crontab
# m h  dom mon dow   command
00 0 * * * /bin/bash ~/docker-server-env/scripts/bck-mysite.sh >> ~/docker-server-env/bck_logs/bck-mysite.log
20 0 * * * /bin/bash ~/docker-server-env/scripts/bck-mysecondsite.sh >> ~/docker-server-env/bck_logs/bck-mysecondsite.log
# etc
```

## Clean up backups

`cleanup-bck.log` will automatically mount your FTP into `/mnt/ftpbackup` to find backups older than **15 days** and delete them.
This script will perform deletions in `/mnt/ftpbackup/docker-bck` folder. If you want to backup permanently some files
create another folder in your FTP.

```bash
# Crontab
# m h  dom mon dow   command
00 12 * * * /bin/bash ~/docker-server-env/scripts/cleanup-bck.sh >> ~/docker-server-env/bck_logs/cleanup-bck.log
```

## Rotating logs

Add the `etc/logrotate.d/dockerbck` configuration to your real `logrotate.d` system folder.

## Installing SSL certificates after Let’s encrypt usage

Make symlinks your SSL certs in your `/root/docker-server-env/front-proxy/certs` folder, naming according to *jwilder/nginx-proxy*
documentation: https://github.com/jwilder/nginx-proxy#ssl-support.

```bash
cd /root/docker-server-env/front-proxy/certs;
ln -s /etc/letsencrypt/live/mysite.com/fullchain.pem mysite.com.crt;
ln -s /etc/letsencrypt/live/mysite.com/privkey.pem mysite.com.key;
```
