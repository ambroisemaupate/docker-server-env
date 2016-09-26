#!/bin/bash
#
apt-get update;
apt-get install ntp ntpdate nano htop curl curlftpfs zsh fail2ban postfix mailutils;

#
# go to current script folder
#
cd "$(dirname "$0")";

#
# Copy sample config files
#
cp ./.zshrc ~/.zshrc;
cp ./fail2ban/jail.conf /etc/fail2ban;
cp ./etc/logrotate.d/dockerbck /etc/logrotate.d/dockerbck;

#
# create a mount point for FTP backup
#
mkdir -p /mnt/ftpbackup;
service fail2ban restart;

#
# Pull base docker images
#
docker pull jwilder/nginx-proxy;
docker pull jrcs/letsencrypt-nginx-proxy-companion;
docker pull ambroisemaupate/roadiz;
docker pull solr;
docker pull ambroisemaupate/ftp-backup;
docker pull ambroisemaupate/light-ssh;
docker pull ambroisemaupate/data;
docker pull maxexcloo/mariadb;