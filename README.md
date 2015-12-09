# Docker server enviroment scripts and configurations

This repository is meant to get a configuration set for installing a fresh server for *Docker* hosting.
It’s specialized for my personal usage, but it fits your needs, do not hesitate to give your feedback.

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

## Used images

* jwilder/nginx-proxy
* uay.io/letsencrypt/letsencrypt
* roadiz/roadiz
* solr
* ambroisemaupate/ftp-backup
* maxexcloo/data
* maxexcloo/mariadb

## Container backups

In order to backup your containers on your FTP. Duplicate `scripts/bck-mysite.sh.sample` without `.sample` suffix file
and fill variables in the `scripts/ftp-credentials.sh`.

```bash
# Crontab
# m h  dom mon dow   command
0 0 * * * /bin/bash ~/docker-server-env/scripts/bck-mysite.sh >> ~/docker-server-env/bck_logs/bck-mysite.log
```

## Clean up backups

`cleanup-bck.log` will automatically mount your FTP into `/mnt/ftpbackup` to find backups older than **15 days** and delete them.
This script will perform deletions in `/mnt/ftpbackup/docker-bck` folder. If you want to backup permanently some files
create another folder in your FTP.

```bash
# Crontab
# m h  dom mon dow   command
0 12 * * * /bin/bash ~/docker-server-env/scripts/cleanup-bck.sh >> ~/docker-server-env/bck_logs/cleanup-bck.log
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
