#!/usr/bin/env bash
# ==============================================================================
# Script: 02_udev_rules.sh
# Finalidade: Configuração de regras do udev com identificação por tamanho/SCSI
#             para discos ASM persistentes em /dev/oracleasm/disks/*
# ==============================================================================

set -euo pipefail

echo "===> [02] Configurando UDEV Rules para os discos Oracle ASM..."

mkdir -p /dev/oracleasm/disks
chown -R grid:asmadmin /dev/oracleasm

UDEV_ASM_FILE="/etc/udev/rules.d/99-oracle-asmdevices.rules"
rm -f "${UDEV_ASM_FILE}"

# Mapeamento determinístico por caminho SCSI
cat << 'EOF' > "${UDEV_ASM_FILE}"
# Oracle ASM UDEV Rules por SCSI Target Path
ACTION=="add|change", KERNEL=="sd[a-z]", ENV{ID_PATH}=="*scsi-0:0:1:0", SYMLINK+="oracleasm/disks/asm-crs01", OWNER="grid", GROUP="asmadmin", MODE="0660"
ACTION=="add|change", KERNEL=="sd[a-z]", ENV{ID_PATH}=="*scsi-0:0:2:0", SYMLINK+="oracleasm/disks/asm-crs02", OWNER="grid", GROUP="asmadmin", MODE="0660"
ACTION=="add|change", KERNEL=="sd[a-z]", ENV{ID_PATH}=="*scsi-0:0:3:0", SYMLINK+="oracleasm/disks/asm-crs03", OWNER="grid", GROUP="asmadmin", MODE="0660"
ACTION=="add|change", KERNEL=="sd[a-z]", ENV{ID_PATH}=="*scsi-0:0:4:0", SYMLINK+="oracleasm/disks/asm-data01", OWNER="grid", GROUP="asmadmin", MODE="0660"
ACTION=="add|change", KERNEL=="sd[a-z]", ENV{ID_PATH}=="*scsi-0:0:5:0", SYMLINK+="oracleasm/disks/asm-reco01", OWNER="grid", GROUP="asmadmin", MODE="0660"
EOF

udevadm control --reload-rules
udevadm trigger --type=devices --action=change

echo "===> [02] Verificação dos discos ASM criados:"
ls -la /dev/oracleasm/disks/ || true
echo "===> [02] Configuração do UDEV concluída com sucesso."
