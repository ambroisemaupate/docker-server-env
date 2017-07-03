#!/bin/bash
#
apt-get update;
apt-get install \
    ntp \
    ntpdate \
    nano \
    htop \
    curl \
    curlftpfs \
    zsh \
    fail2ban \
    postfix \
    mailutils \
    apt-transport-https \
    ca-certificates \
    software-properties-common;

# Install latest docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -;
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable";

apt-get update;
apt-get install docker-ce;

# Add your user to docker group
# for non-root installs
# usermod -aG docker $USER;

# Configure Docker to start on boot
# with systemd
systemctl enable docker;

# Install docker-compose
curl -L https://github.com/docker/compose/releases/download/1.14.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose;
chmod +x /usr/local/bin/docker-compose;

#
# Listen only localhost for Postfix
#
sed -i -e "s/inet\_interfaces = all/inet\_interfaces = loopback-only/" /etc/postfix/main.cf;
echo "root:    ambroise@rezo-zero.com" >> /etc/aliases;
newaliases;
service postfix restart;

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
docker pull roadiz/standard-edition;
docker pull solr;
docker pull ambroisemaupate/ftp-backup;
docker pull ambroisemaupate/light-ssh;
docker pull ambroisemaupate/mariadb;