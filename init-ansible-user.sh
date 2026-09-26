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

# 3) Ajout de la clé SSH Ansible (sans doublon si relancé)
touch "${AUTHORIZED_KEYS}"

echo
echo "👉 Colle maintenant la CLÉ PUBLIQUE SSH pour Ansible."
echo "   (ex: ssh-ed25519 AAAA... rezozero-ansible)"
echo "   Valide par Entrée"
echo

IFS= read -r key
if [ -z "${key}" ]; then
  echo "✖ Aucune clé saisie" >&2
  exit 1
fi
if grep -qxF "${key}" "${AUTHORIZED_KEYS}"; then
  echo "• Clé déjà présente"
else
  echo "${key}" >> "${AUTHORIZED_KEYS}"
  echo "• Clé ajoutée"
fi

chmod 600 "${AUTHORIZED_KEYS}"
chown "${ANSIBLE_USER}:${ANSIBLE_USER}" "${AUTHORIZED_KEYS}"

# 4) Sudoers : Ansible élève ses droits via /bin/sh -c, une liste de commandes ne le
# restreindrait pas. On assume un sudo complet, la sécurité repose sur la clé dédiée.
SUDOERS_TMP="$(mktemp)"
echo "${ANSIBLE_USER} ALL=(ALL) NOPASSWD: ALL" > "${SUDOERS_TMP}"
visudo -cf "${SUDOERS_TMP}"
if ! cmp -s "${SUDOERS_TMP}" "${SUDOERS_FILE}"; then
  echo "• Installation du sudoers Ansible"
  install -m 440 -o root -g root "${SUDOERS_TMP}" "${SUDOERS_FILE}"
else
  echo "• Sudoers Ansible déjà à jour"
fi
rm -f "${SUDOERS_TMP}"

echo
echo "✅ Utilisateur '${ANSIBLE_USER}' prêt"
echo "   → SSH par clé"
echo "   → sudo complet sans mot de passe"
echo "   → prêt pour Ansible"
