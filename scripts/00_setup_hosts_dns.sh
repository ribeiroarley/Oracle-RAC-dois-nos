#!/usr/bin/env bash
# ==============================================================================
# Script: 00_setup_hosts_dns.sh
# Finalidade: Configuração de rede, /etc/hosts e servidor DNS local (dnsmasq)
#             para resolução adequada do SCAN (3 IPs round-robin).
# ==============================================================================

set -euo pipefail

NODE_NAME="${1:-$(hostname -s)}"

echo "===> [00] Iniciando configuração de rede e DNS no host: ${NODE_NAME}"

# 1. Configuração do /etc/hosts
cat << 'EOF' > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

# Public IPs
192.168.56.11   racnode1.localdomain racnode1
192.168.56.12   racnode2.localdomain racnode2

# Private IPs (Interconnect)
192.168.10.11   racnode1-priv.localdomain racnode1-priv
192.168.10.12   racnode2-priv.localdomain racnode2-priv

# Virtual IPs (VIP)
192.168.56.21   racnode1-vip.localdomain racnode1-vip
192.168.56.22   racnode2-vip.localdomain racnode2-vip
EOF

# 2. Configuração de DNS / dnsmasq para resolução de SCAN sem falha no cluvfy
if [ "${NODE_NAME}" = "racnode1" ]; then
    echo "===> [00] Configurando dnsmasq no racnode1 como servidor DNS local do cluster..."
    dnf install -y dnsmasq bind-utils

    cat << 'EOF' > /etc/dnsmasq.d/rac-cluster.conf
domain-needed
bogus-priv
no-resolv
server=8.8.8.8
local=/localdomain/
listen-address=127.0.0.1,192.168.56.11
bind-interfaces

# Cluster SCAN Round-Robin records
address=/rac-scan.localdomain/192.168.56.31
address=/rac-scan.localdomain/192.168.56.32
address=/rac-scan.localdomain/192.168.56.33

# Nodes
address=/racnode1.localdomain/192.168.56.11
address=/racnode2.localdomain/192.168.56.12
address=/racnode1-vip.localdomain/192.168.56.21
address=/racnode2-vip.localdomain/192.168.56.22
EOF

    systemctl enable --now dnsmasq
    systemctl restart dnsmasq
fi

# 3. Ajuste do resolv.conf para consultar o DNS local (racnode1 / 192.168.56.11)
echo "===> [00] Atualizando /etc/resolv.conf..."
cat << 'EOF' > /etc/resolv.conf
search localdomain
nameserver 192.168.56.11
nameserver 8.8.8.8
EOF

# Proteger o resolv.conf de sobrescrita pelo NetworkManager
chattr +i /etc/resolv.conf || true

echo "===> [00] Teste de resolução do SCAN:"
nslookup rac-scan.localdomain || true
echo "===> [00] Configuração de rede e DNS finalizada com sucesso."
