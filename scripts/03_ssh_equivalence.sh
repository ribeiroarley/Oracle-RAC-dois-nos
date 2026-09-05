#!/usr/bin/env bash
# ==============================================================================
# Script: 03_ssh_equivalence.sh
# Finalidade: Configuração de equivalência de usuário SSH sem senha bidirecional
#             entre racnode1 e racnode2 para grid, oracle e root.
# ==============================================================================

set -euo pipefail

TARGET_USERS=("grid" "oracle" "root")
NODES=("racnode1" "racnode2" "racnode1.localdomain" "racnode2.localdomain" "192.168.56.11" "192.168.56.12" "192.168.10.11" "192.168.10.12")
SHARED_KEY_DIR="/vagrant/.ssh_keys"

echo "===> [03] Iniciando configuração de User Equivalence SSH..."
mkdir -p "${SHARED_KEY_DIR}"
chmod 777 "${SHARED_KEY_DIR}"

setup_ssh_for_user() {
    local USER_NAME="$1"
    local USER_HOME
    USER_HOME=$(eval echo "~${USER_NAME}")

    echo "===> [03] Configurando SSH para usuário: ${USER_NAME} (Home: ${USER_HOME})"

    # Criar diretório .ssh
    mkdir -p "${USER_HOME}/.ssh"
    chmod 700 "${USER_HOME}/.ssh"

    # Configuração de ssh_config com StrictHostKeyChecking=no
    cat << 'EOF' > "${USER_HOME}/.ssh/config"
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
EOF
    chmod 600 "${USER_HOME}/.ssh/config"

    # Gerar par de chaves RSA se não existir
    if [ ! -f "${USER_HOME}/.ssh/id_rsa" ]; then
        ssh-keygen -t rsa -b 2048 -N "" -f "${USER_HOME}/.ssh/id_rsa" -q
    fi

    # Exportar chave pública para a área compartilhada
    cp -f "${USER_HOME}/.ssh/id_rsa.pub" "${SHARED_KEY_DIR}/${USER_NAME}_$(hostname -s).pub"
    chmod 644 "${SHARED_KEY_DIR}/${USER_NAME}_$(hostname -s).pub"

    # Se ambas as chaves públicas já existirem na pasta compartilhada, consolidar authorized_keys
    if [ -f "${SHARED_KEY_DIR}/${USER_NAME}_racnode1.pub" ] && [ -f "${SHARED_KEY_DIR}/${USER_NAME}_racnode2.pub" ]; then
        cat "${SHARED_KEY_DIR}/${USER_NAME}_racnode1.pub" "${SHARED_KEY_DIR}/${USER_NAME}_racnode2.pub" | sort -u > "${USER_HOME}/.ssh/authorized_keys"
        chmod 600 "${USER_HOME}/.ssh/authorized_keys"
    else
        cat "${USER_HOME}/.ssh/id_rsa.pub" >> "${USER_HOME}/.ssh/authorized_keys"
        chmod 600 "${USER_HOME}/.ssh/authorized_keys"
    fi

    chown -R "${USER_NAME}:$(id -gn "${USER_NAME}")" "${USER_HOME}/.ssh"
}

for usr in "${TARGET_USERS[@]}"; do
    setup_ssh_for_user "$usr"
done

echo "===> [03] Chaves geradas e sincronizadas. Testando conectividade local..."
su - grid -c "ssh -o BatchMode=yes localhost date" || true
su - oracle -c "ssh -o BatchMode=yes localhost date" || true

echo "===> [03] SSH User Equivalence configurado."
