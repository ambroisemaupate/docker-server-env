#!/usr/bin/env bash
set -euo pipefail

ANSIBLE_USER="ansible"
ANSIBLE_HOME="/home/${ANSIBLE_USER}"
SSH_DIR="${ANSIBLE_HOME}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
SUDOERS_FILE="/etc/sudoers.d/ansible"

echo "▶ Initialisation de l'utilisateur '${ANSIBLE_USER}'"

# 1) Création de l'utilisateur si nécessaire
if ! id "${ANSIBLE_USER}" >/dev/null 2>&1; then
  echo "• Création de l'utilisateur ${ANSIBLE_USER}"
  useradd \
    --create-home \
    --shell /bin/bash \
    "${ANSIBLE_USER}"
else
  echo "• Utilisateur ${ANSIBLE_USER} déjà présent"
fi

# 2) Création du dossier .ssh
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"
chown "${ANSIBLE_USER}:${ANSIBLE_USER}" "${SSH_DIR}"

# 3) Ajout de la clé SSH Ansible
if [ ! -f "${AUTHORIZED_KEYS}" ]; then
  touch "${AUTHORIZED_KEYS}"
fi

echo
echo "👉 Colle maintenant la CLÉ PUBLIQUE SSH pour Ansible."
echo "   (ex: ssh-ed25519 AAAA... rezozero-ansible)"
echo "   Termine par Ctrl+D"
echo

cat >> "${AUTHORIZED_KEYS}"

chmod 600 "${AUTHORIZED_KEYS}"
chown "${ANSIBLE_USER}:${ANSIBLE_USER}" "${AUTHORIZED_KEYS}"

# 4) Sudoers minimal (sécurisé)
if [ ! -f "${SUDOERS_FILE}" ]; then
  echo "• Installation du sudoers Ansible"
  cat > "${SUDOERS_FILE}" <<'EOF'
ansible ALL=(root) NOPASSWD: \
  /usr/bin/apt, /usr/bin/apt-get, /usr/bin/dpkg, \
  /usr/bin/systemctl, /usr/sbin/service, \
  /usr/sbin/reboot, /usr/sbin/shutdown, \
  /usr/bin/docker, /usr/bin/docker-compose, /usr/bin/docker\ compose, \
  /bin/mkdir, /bin/chmod, /bin/chown, /bin/cp, /bin/mv, /bin/rm, \
  /usr/bin/curl, /usr/bin/jq, /bin/sh
EOF

  chmod 440 "${SUDOERS_FILE}"
else
  echo "• Sudoers Ansible déjà présent"
fi

# 5) Vérification sudo
echo "• Vérification sudo"
visudo -cf "${SUDOERS_FILE}"

echo
echo "✅ Utilisateur '${ANSIBLE_USER}' prêt"
echo "   → SSH par clé"
echo "   → sudo limité"
echo "   → prêt pour Ansible"
