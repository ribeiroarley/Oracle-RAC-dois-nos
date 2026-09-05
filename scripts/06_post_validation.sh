#!/usr/bin/env bash
# ==============================================================================
# Script: 06_post_validation.sh
# Finalidade: Healthcheck e validação completa do cluster Oracle RAC 23ai
# ==============================================================================

set -euo pipefail

DB_NAME="orcl"

echo "=============================================================================="
echo "                   ORACLE RAC 23ai - CLUSTER HEALTH CHECK                     "
echo "=============================================================================="

echo -e "\n--- 1. Status Geral do Clusterware (crsctl check cluster -all) ---"
su - grid -c "crsctl check cluster -all" || true

echo -e "\n--- 2. Tabela de Recursos do Cluster (crsctl stat res -t) ---"
su - grid -c "crsctl stat res -t" || true

echo -e "\n--- 3. Status dos SCAN Listeners e Listeners Locais ---"
su - grid -c "srvctl status scan" || true
su - grid -c "srvctl status scan_listener" || true
su - grid -c "srvctl status listener" || true

echo -e "\n--- 4. Status dos Diskgroups ASM ---"
su - grid -c "srvctl status asm" || true
su - grid -c "asmcmd lsdg" || true

echo -e "\n--- 5. Status e Configuração do Banco de Dados RAC (${DB_NAME}) ---"
su - oracle -c "srvctl status database -d ${DB_NAME}" || true
su - oracle -c "srvctl config database -d ${DB_NAME}" || true

echo -e "\n=============================================================================="
echo " Validação do Oracle RAC 23ai concluída."
echo "=============================================================================="
