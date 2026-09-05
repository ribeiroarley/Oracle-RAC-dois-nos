#!/usr/bin/env bash
# ==============================================================================
# Script: 04_create_asm_diskgroups.sh
# Finalidade: Criação dos diskgroups adicionais (+DATA e +RECO) no ASM via asmca
# ==============================================================================

set -euo pipefail

if [ "$(hostname -s)" = "racnode1" ]; then
    echo "===> [04-ASM] Criando Diskgroups +DATA e +RECO no Oracle ASM..."

    # Criar Diskgroup +DATA
    su - grid -c "asmca -silent -createDiskGroup \
        -diskGroupName DATA \
        -diskList '/dev/oracleasm/disks/asm-data01' \
        -redundancy EXTERNAL \
        -au_size 4 \
        -compatible.asm 23.0.0.0.0 \
        -compatible.rdbms 23.0.0.0.0" || true

    # Criar Diskgroup +RECO
    su - grid -c "asmca -silent -createDiskGroup \
        -diskGroupName RECO \
        -diskList '/dev/oracleasm/disks/asm-reco01' \
        -redundancy EXTERNAL \
        -au_size 4 \
        -compatible.asm 23.0.0.0.0 \
        -compatible.rdbms 23.0.0.0.0" || true

    echo "===> [04-ASM] Diskgroups disponíveis no cluster:"
    su - grid -c "asmcmd lsdg" || true
fi
