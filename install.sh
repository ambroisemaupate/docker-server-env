#!/usr/bin/env bash
set -Eeuo pipefail

# ------------------------------------------------------------
# docker-server-env provisioner (improved)
# - idempotent-ish
# - distro autodetect (debian/ubuntu)
# - optional postfix aliases + ip blacklist service
# - robust paths (run from anywhere)
# ------------------------------------------------------------

log()  { printf "\n\033[1;34m[+] %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[!] %s\033[0m\n" "$*" >&2; }
die()  { printf "\033[1;31m[x] %s\033[0m\n" "$*" >&2; exit 1; }

on_err() {
  local code=$?
  warn "Erreur à la ligne ${BASH_LINENO[0]} (exit=${code})."
  exit "$code"
}
trap on_err ERR

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "Ce script doit être exécuté en root (ou via sudo)."
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR}"
DEFAULT_USER="${SUDO_USER:-${USER:-$(id -un)}}"

EMAIL=""
TARGET_USER="$DEFAULT_USER"
SKIP_POSTFIX=0
SKIP_BLACKLIST=0
SKIP_COMPOSE_SETUP=0

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --email <addr>          Email pour l'alias root (Postfix)
  --user <name>           User à ajouter au groupe docker (défaut: ${DEFAULT_USER})
  --skip-postfix          N'installe/configure pas postfix
  --skip-blacklist        Ne configure pas le service add-ip-blacklist
  --skip-compose-setup    Ne copie pas les fichiers compose/ (traefik/metrics/etc.)
  -h, --help              Affiche l'aide
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --email) EMAIL="${2:-}"; shift 2;;
      --user) TARGET_USER="${2:-}"; shift 2;;
      --skip-postfix) SKIP_POSTFIX=1; shift;;
      --skip-blacklist) SKIP_BLACKLIST=1; shift;;
      --skip-compose-setup) SKIP_COMPOSE_SETUP=1; shift;;
      -h|--help) usage; exit 0;;
      *) die "Option inconnue: $1";;
    esac
  done
}

is_container() {
  # Heuristiques robustes
  if [[ -f /.dockerenv ]]; then return 0; fi
  if grep -qaE '(docker|containerd|kubepods|lxc)' /proc/1/cgroup 2>/dev/null; then return 0; fi
  return 1
}

has_systemd() {
  [[ -d /run/systemd/system ]] && command -v systemctl >/dev/null 2>&1
}

restart_service() {
  local svc="$1"
  if has_systemd; then
    systemctl restart "$svc" || true
  else
    warn "Skip restart $svc (pas de systemd dans ce contexte)"
  fi
}

detect_distro() {
  # shellcheck disable=SC1091
  source /etc/os-release

  case "${ID:-}" in
    debian|ubuntu) ;;
    *) die "Distro non supportée: ID=${ID:-unknown}. (Support: debian, ubuntu)";;
  esac

  DISTRIB="$ID"
  CODENAME="${VERSION_CODENAME:-}"
  [[ -n "$CODENAME" ]] || die "Impossible de déterminer VERSION_CODENAME depuis /etc/os-release"
}

apt_install_base() {
  log "Mise à jour APT + packages de base"
  export DEBIAN_FRONTEND=noninteractive

  apt-get update -y
  apt-get upgrade -y

  # ntpdate est souvent remplacé; on installe chrony (plus moderne) si dispo
  local pkgs=(
    cron nano logrotate gnupg htop curl zsh fail2ban
    apt-transport-https ca-certificates
  )

  # software-properties-common n'existe pas partout
  if apt-cache show software-properties-common >/dev/null 2>&1; then
    pkgs+=(software-properties-common)
  else
    warn "software-properties-common indisponible sur cette distro → ignoré"
  fi

  # chrony existe sur debian/ubuntu modernes; sinon on retombe sur ntpdate
  if apt-cache show chrony >/dev/null 2>&1; then
    pkgs+=(chrony)
  else
    pkgs+=(ntpdate)
  fi

  if [[ "$SKIP_POSTFIX" -eq 0 ]]; then
    pkgs+=(postfix mailutils)
  fi

  apt-get install -y "${pkgs[@]}"
}

start_docker_service() {
  # systemd présent ET PID 1 = systemd ?
  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    systemctl daemon-reload || true
    systemctl enable docker.service docker.socket || true
    restart_service docker.service || systemctl start docker.service || true
  else
    warn "systemd n'est pas actif (container/chroot?). Docker installé mais service non démarré automatiquement."
    warn "Si tu es sur une VM normale: redémarre le serveur ou lance le service à la main."
  fi
}

install_docker() {
  log "Installation Docker (repo officiel) pour $DISTRIB ($CODENAME)"

  install -m 0755 -d /etc/apt/keyrings

  curl -fsSL --retry 3 --retry-delay 2 \
    "https://download.docker.com/linux/${DISTRIB}/gpg" \
    -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DISTRIB} ${CODENAME} stable
EOF

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  start_docker_service

  # docker group idempotent
  if ! getent group docker >/dev/null; then
    groupadd docker
  fi

  # Ajout de l'user au groupe docker si user existe
  if id "$TARGET_USER" >/dev/null 2>&1; then
    usermod -aG docker "$TARGET_USER"
  else
    warn "L'utilisateur '$TARGET_USER' n'existe pas: impossible de l'ajouter au groupe docker."
  fi
}

docker_ready() {
  command -v docker >/dev/null 2>&1 || return 1
  docker info >/dev/null 2>&1
}

ensure_docker_running() {
  if docker_ready; then return 0; fi

  # systemd actif ?
  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    systemctl start docker.service || true
    sleep 1
  else
    warn "Docker daemon non démarré (pas de systemd)."
  fi

  docker_ready
}

create_frontproxynet() {
  if ! ensure_docker_running; then
    warn "Création du réseau 'frontproxynet' ignorée."
    return 0
  fi

  log "Création du réseau docker 'frontproxynet' (bridge IPv6)"
  docker network inspect frontproxynet >/dev/null 2>&1 || \
    docker network create --driver bridge --ipv6 frontproxynet
}

configure_postfix_aliases() {
  [[ "$SKIP_POSTFIX" -eq 0 ]] || return 0
  [[ -n "$EMAIL" ]] || die "Postfix activé mais --email n'est pas fourni."

  log "Configuration Postfix + alias root -> $EMAIL"

  # Sécurise postfix: écoute loopback only (comportement que tu avais commenté)
  if [[ -f /etc/postfix/main.cf ]]; then
    if grep -qE '^\s*inet_interfaces\s*=' /etc/postfix/main.cf; then
      sed -i -E 's/^\s*inet_interfaces\s*=.*/inet_interfaces = loopback-only/' /etc/postfix/main.cf
    else
      echo "inet_interfaces = loopback-only" >> /etc/postfix/main.cf
    fi
  fi

  # Alias idempotent: remplace/ajoute root:
  if grep -qE '^root:' /etc/aliases; then
    sed -i -E "s/^root:.*/root: ${EMAIL}/" /etc/aliases
  else
    echo "root: ${EMAIL}" >> /etc/aliases
  fi

  newaliases
  restart_service postfix
}

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    cp -a "$path" "${path}.bak.$(date +%Y%m%d%H%M%S)"
  fi
}

copy_repo_configs() {
  log "Copie des configurations depuis le repo: $REPO_DIR"

  local thome
  thome="$(eval echo "~${TARGET_USER}")"

  # ZSH
  backup_if_exists "${thome}/.zshrc"
  install -m 0644 "${REPO_DIR}/.zshrc" "${thome}/.zshrc"

  # Fail2ban
  if [[ -f "${REPO_DIR}/etc/fail2ban/jail.d/defaults-${DISTRIB}.conf" ]]; then
    install -d /etc/fail2ban/jail.d
    backup_if_exists "/etc/fail2ban/jail.d/defaults-${DISTRIB}.conf"
    install -m 0644 "${REPO_DIR}/etc/fail2ban/jail.d/defaults-${DISTRIB}.conf" "/etc/fail2ban/jail.d/defaults-${DISTRIB}.conf"
  else
    warn "Config fail2ban defaults manquante: etc/fail2ban/jail.d/defaults-${DISTRIB}.conf"
  fi

  if [[ -f "${REPO_DIR}/etc/fail2ban/jail.d/traefik.conf" ]]; then
    backup_if_exists "/etc/fail2ban/jail.d/traefik.conf"
    install -m 0644 "${REPO_DIR}/etc/fail2ban/jail.d/traefik.conf" "/etc/fail2ban/jail.d/traefik.conf"
    # Ajuste /root -> HOME du target user
    sed -i "s@/root/@${thome}/@g" /etc/fail2ban/jail.d/traefik.conf
  fi

  # Logrotate
  if [[ -f "${REPO_DIR}/etc/logrotate.d/docker-server-env" ]]; then
    backup_if_exists "/etc/logrotate.d/docker-server-env"
    install -m 0644 "${REPO_DIR}/etc/logrotate.d/docker-server-env" "/etc/logrotate.d/docker-server-env"
    sed -i "s@/root/@${thome}/@g" /etc/logrotate.d/docker-server-env
    sed -i "s@root@${TARGET_USER}@g" /etc/logrotate.d/docker-server-env
  fi

  # Docker daemon.json
  if [[ -f "${REPO_DIR}/etc/docker/daemon.json" ]]; then
    install -d /etc/docker
    backup_if_exists "/etc/docker/daemon.json"
    install -m 0644 "${REPO_DIR}/etc/docker/daemon.json" "/etc/docker/daemon.json"
    restart_service docker
  fi

  restart_service fail2ban
}

setup_ip_blacklist() {
  [[ "$SKIP_BLACKLIST" -eq 0 ]] || return 0

  log "Mise en place add-ip-blacklist (snippets GitLab)"

  local thome
  thome="$(eval echo "~${TARGET_USER}")"

  install -d -m 0755 "${thome}/docker-server-env"
  cd "${thome}/docker-server-env"

  curl -fsSL --retry 3 --retry-delay 2 \
    "https://gitlab.rezo-zero.com/-/snippets/29/raw/main/add-ip-blacklist.sh" \
    -o "./add-ip-blacklist.sh"
  curl -fsSL --retry 3 --retry-delay 2 \
    "https://gitlab.rezo-zero.com/-/snippets/29/raw/main/ip-blacklist.txt" \
    -o "./ip-blacklist.txt"
  curl -fsSL --retry 3 --retry-delay 2 \
    "https://gitlab.rezo-zero.com/-/snippets/29/raw/main/etc/systemd/system/add-ip-blacklist.service" \
    -o "/etc/systemd/system/add-ip-blacklist.service"

  chmod +x "./add-ip-blacklist.sh"
  chmod 0644 "/etc/systemd/system/add-ip-blacklist.service"

  # Patch chemin du script dans le service: /root -> thome
  sed -i "s@/root/@${thome}/@g" /etc/systemd/system/add-ip-blacklist.service

  systemctl daemon-reload
  ./add-ip-blacklist.sh
  systemctl enable --now add-ip-blacklist.service
}

setup_compose_defaults() {
  [[ "$SKIP_COMPOSE_SETUP" -eq 0 ]] || return 0

  log "Initialisation des fichiers compose/ (traefik, whoami, watchtower, metrics)"
  cd "$REPO_DIR"

  # Traefik
  install -d "./compose/traefik"
  [[ -f "./compose/traefik/traefik.toml" ]] || cp "./compose/traefik/traefik.sample.toml" "./compose/traefik/traefik.toml"
  [[ -f "./compose/traefik/compose.yml" ]] || cp "./compose/traefik/compose.yml.dist" "./compose/traefik/compose.yml"
  [[ -f "./compose/traefik/.env" ]] || cp "./compose/traefik/.env.dist" "./compose/traefik/.env"

  touch "./compose/traefik/acme.json" "./compose/traefik/access.log"
  chmod 0600 "./compose/traefik/acme.json"

  # whoami
  [[ -f "./compose/whoami/.env" ]] || cp "./compose/whoami/.env.dist" "./compose/whoami/.env"

  # metrics
  [[ -f "./compose/metrics/.env" ]] || cp "./compose/metrics/.env.dist" "./compose/metrics/.env"
  [[ -f "./compose/metrics/prometheus.yml" ]] || cp "./compose/metrics/prometheus.yml.dist" "./compose/metrics/prometheus.yml"
  [[ -f "./compose/metrics/compose.yml" ]] || cp "./compose/metrics/compose.yml.dist" "./compose/metrics/compose.yml"
  [[ -d "./compose/metrics/provisioning" ]] || cp -a "./compose/metrics/provisioning-dist" "./compose/metrics/provisioning"
}

fix_ownership() {
  log "Permissions: dossier repo + ${TARGET_USER}"
  local thome
  thome="$(eval echo "~${TARGET_USER}")"

  # Si le repo est déjà dans un autre chemin, on ne force pas un chown arbitraire.
  # On chown uniquement ce qu'on a créé: ${thome}/docker-server-env
  if [[ -d "${thome}/docker-server-env" ]] && id "$TARGET_USER" >/dev/null 2>&1; then
    chown -R "${TARGET_USER}:${TARGET_USER}" "${thome}/docker-server-env"
  fi
}

main() {
  require_root
  parse_args "$@"
  detect_distro

  log "Repo: ${REPO_DIR}"
  log "User docker: ${TARGET_USER}"
  [[ "$SKIP_POSTFIX" -eq 1 ]] && warn "Postfix: SKIP" || log "Postfix: ON"
  [[ "$SKIP_BLACKLIST" -eq 1 ]] && warn "Blacklist: SKIP" || log "Blacklist: ON"

  apt_install_base
  install_docker
  create_frontproxynet
  configure_postfix_aliases
  copy_repo_configs
  setup_ip_blacklist
  setup_compose_defaults
  fix_ownership

  log "Terminé ✅"
  if id "$TARGET_USER" >/dev/null 2>&1; then
    warn "Note: l'ajout au groupe docker nécessite une reconnexion de '${TARGET_USER}' pour prendre effet."
  fi
}

main "$@"
