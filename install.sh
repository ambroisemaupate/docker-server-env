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
apt upgrade -y;
apt install -y \
    ntpdate \
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
    software-properties-common;

# Install latest docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$DISTRIB/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$DISTRIB \
  $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update;
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin;
groupadd docker;

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
cp ./etc/fail2ban/jail.d/traefik.conf /etc/fail2ban/jail.d/traefik.conf;
sed -i 's@/root/@'"$HOME"'/@gi' /etc/fail2ban/jail.d/traefik.conf;

cp ./etc/logrotate.d/docker-server-env /etc/logrotate.d/docker-server-env;
## EDIT script path
sed -i 's@/root/@'"$HOME"'/@gi' /etc/logrotate.d/docker-server-env;
sed -i 's@root@'"$USER"'@gi' /etc/logrotate.d/docker-server-env;

# Copy Docker daemon configuration
cp ./etc/docker/daemon.json /etc/docker/daemon.json;

# Copy defaults for traefik
cp ./compose/traefik/traefik.sample.toml ./compose/traefik/traefik.toml;
cp ./compose/traefik/compose.yml.dist ./compose/traefik/compose.yml;
cp ./compose/traefik/.env.dist ./compose/traefik/.env;
touch ./compose/traefik/acme.json;
touch ./compose/traefik/access.log;
chmod 0600 ./compose/traefik/acme.json;

# Copy defaults for whoami
cp ./compose/whoami/.env.dist ./compose/whoami/.env;

# Copy defaults for watchtower
cp ./compose/watchtower/.env.dist ./compose/watchtower/.env;
cp ./compose/watchtower/compose.yml.dist ./compose/watchtower/compose.yml;

# Copy defaults for metrics
cp ./compose/metrics/.env.dist ./compose/metrics/.env;
cp ./compose/metrics/prometheus.yml.dist ./compose/metrics/prometheus.yml;
cp ./compose/metrics/compose.yml.dist ./compose/metrics/compose.yml;
cp -ar ./compose/metrics/provisioning-dist ./compose/metrics/provisioning;

service fail2ban restart;

#
# create default bridge network
#
docker network create --ipv6 --driver bridge --subnet="fd01:846c:3ae6:fe92::/64" frontproxynet;

# Add your user to docker group
# for non-root installs
usermod -aG docker ${USER}
chown -R  ${USER}:${USER} ${HOME}/docker-server-env
