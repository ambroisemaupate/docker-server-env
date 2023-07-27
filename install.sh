#!/bin/bash
#
if [ -z "$EMAIL" ]; then
    echo "Need to set EMAIL env variable for Postfix aliases."
    exit 1
fi

if [ -z "$DISTRIB" ]; then
    echo "Need to set DISTRIB env variable [debian|ubuntu]."
    exit 1
fi

if [ "$DISTRIB" != "debian" -a "$DISTRIB" != "ubuntu" ]; then
    echo "DISTRIB env variable only supports debian or ubuntu."
    exit 1
fi

apt update;
apt install -y \
    cron \
    nano \
    gnupg \
    htop \
    curl \
    zsh \
    fail2ban \
    postfix \
    mailutils \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    clamav \
    clamav-daemon;

# Configure ClamAV
clamconf;

# Install latest docker
install -m 0755 -d /etc/apt/keyrings;
curl -fsSL https://download.docker.com/linux/$DISTRIB/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$DISTRIB \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update;
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin;
groupadd docker;

# Add your user to docker group
# for non-root installs
# usermod -aG docker $USER;

# Configure Docker to start on boot
# with systemd
systemctl enable docker;

#
# Listen only localhost for Postfix
#
sed -i -e "s/inet\_interfaces = all/inet\_interfaces = loopback-only/" /etc/postfix/main.cf;
echo "root: $EMAIL" >> /etc/aliases;
newaliases;
service postfix restart;

#
# go to current script folder
#
cd "$(dirname "$0")";

#
# Download ip block list for known attacker sources
#
curl https://gitlab.rezo-zero.com/-/snippets/29/raw/main/add-ip-blacklist.sh > ./add-ip-blacklist.sh
curl https://gitlab.rezo-zero.com/-/snippets/29/raw/main/ip-blacklist.txt > ./ip-blacklist.txt
curl https://gitlab.rezo-zero.com/-/snippets/29/raw/main/etc/systemd/system/add-ip-blacklist.service > /etc/systemd/system/add-ip-blacklist.service
chmod +x ./add-ip-blacklist.sh
chmod 644 /etc/systemd/system/add-ip-blacklist.service
## EDIT script path
sed -i 's@/root/@'"$HOME"'/@gi' /etc/systemd/system/add-ip-blacklist.service
# Added ip block list into iptables
./add-ip-blacklist.sh
systemctl enable add-ip-blacklist.service

#
# Copy sample config files
#
cp ./.zshrc $HOME/.zshrc;
cp ./etc/fail2ban/jail.d/defaults-${DISTRIB}.conf /etc/fail2ban/jail.d/defaults-${DISTRIB}.conf;
cp ./etc/logrotate.d/docker-server-env /etc/logrotate.d/docker-server-env;
cp ./etc/docker/daemon.json /etc/docker/daemon.json;
cp ./compose/traefik/traefik.sample.toml ./compose/traefik/traefik.toml;
cp ./compose/traefik/docker-compose.yml.dist ./compose/traefik/docker-compose.yml;
cp ./compose/traefik/.env.dist ./compose/traefik/.env;
cp ./compose/netdata/.env.dist ./compose/netdata/.env;
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
# TODO: Generate a new random private subnet
#
docker network create --ipv6 --driver bridge --subnet="fd01:846c:3ae6:fe92::/64" frontproxynet;
