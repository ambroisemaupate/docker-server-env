#!/bin/bash
#
if [ -z "$DISTRIB" ]; then
    echo "Need to set DISTRIB env variable [debian|ubuntu]."
    exit 1
fi

if [ "$DISTRIB" != "debian" -a "$DISTRIB" != "ubuntu" ]; then
    echo "DISTRIB env variable only supports debian or ubuntu."
    exit 1
fi

apt-get update;
apt-get install -y \
    ntp \
    ntpdate \
    nano \
    htop \
    curl \
    curlftpfs \
    lftp \
    sshfs \
    zsh \
    fail2ban \
    postfix \
    mailutils \
    apt-transport-https \
    ca-certificates \
    software-properties-common;

# Install latest docker
curl -fsSL https://download.docker.com/linux/$DISTRIB/gpg | apt-key add -;
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$DISTRIB $(lsb_release -cs) stable";

apt-get update;
apt-get install -y docker-ce;
groupadd docker;

# Add your user to docker group
# for non-root installs
# usermod -aG docker $USER;

# Configure Docker to start on boot
# with systemd
systemctl enable docker;

# Install docker-compose
curl -L https://github.com/docker/compose/releases/download/1.23.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

#
# Listen only localhost for Postfix
#
sed -i -e "s/inet\_interfaces = all/inet\_interfaces = loopback-only/" /etc/postfix/main.cf;
echo "root: ambroise@rezo-zero.com" >> /etc/aliases;
newaliases;
service postfix restart;

#
# go to current script folder
#
cd "$(dirname "$0")";

#
# Copy sample config files
#
cp ./.zshrc $HOME/.zshrc;
cp ./etc/fail2ban/jail.d/defaults-${DISTRIB}.conf /etc/fail2ban/jail.d/defaults-${DISTRIB}.conf;
cp ./etc/logrotate.d/dockerbck /etc/logrotate.d/dockerbck;
cp ./compose/traefik/traefik.sample.toml ./compose/traefik/traefik.toml;
cp ./compose/traefik/.env.dist ./compose/traefik/.env;
touch ./compose/traefik/acme.json;
touch ./compose/traefik/access.log;
chmod 0600 ./compose/traefik/acme.json;

#
# create a mount point for FTP backup
#
mkdir -p /mnt/ftpbackup;
service fail2ban restart;

#
# create default bridge network
#
docker network create --driver bridge frontproxynet;
