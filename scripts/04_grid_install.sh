#!/usr/bin/env bash
# ==============================================================================
# Script: 04_grid_install.sh
# Finalidade: Extração do GI 23ai no $GRID_HOME, validação do cluster (cluvfy),
#             instalação silenciosa do Grid Infrastructure e criação dos diskgroups.
# ==============================================================================

set -euo pipefail

SOFTWARE_DIR="/vagrant/software"
GRID_ZIP=$(find "${SOFTWARE_DIR}" -maxdepth 1 \( -iname "V982068-01.zip" -o -iname "*grid*.zip" -o -iname "*LINUX*grid*" \) | head -n 1)
GRID_HOME="/u01/app/19.0.0/grid"
RSP_FILE="/vagrant/templates/grid_install.rsp"

export CV_ASSUME_DISTID=OL8

echo "===> [04] Verificando binários do Grid Infrastructure 19c..."

if [ -z "${GRID_ZIP}" ] || [ ! -f "${GRID_ZIP}" ]; then
    echo "[-] ERRO: Arquivo zip do Grid Infrastructure não encontrado em: ${SOFTWARE_DIR}"
    echo "[-] Coloque o arquivo zip de instalação (ex: V982068-01.zip ou LINUX.X64_193000_grid_home.zip) no diretório ./software do host."
    exit 1
fi

echo "[+] Binário encontrado: ${GRID_ZIP}"

# 1. Extração do zip do Grid Infrastructure dentro do $GRID_HOME (apenas no racnode1)
if [ "$(hostname -s)" = "racnode1" ]; then
    if [ ! -f "${GRID_HOME}/gridSetup.sh" ]; then
        echo "===> [04] Extraindo Grid Infrastructure zip em ${GRID_HOME}..."
        su - grid -c "unzip -q -o '${GRID_ZIP}' -d '${GRID_HOME}'"
    fi

    # 2. Validação prévia com Cluster Verification Utility (cluvfy)
    echo "===> [04] Executando validação de pré-requisitos com cluvfy (CV_ASSUME_DISTID=OL8)..."
    su - grid -c "export CV_ASSUME_DISTID=OL8; ${GRID_HOME}/runcluvfy.sh stage -pre crsinst -n racnode1,racnode2 -verbose" || {
        echo "[!] Aviso: O cluvfy reportou avisos. Verifique se são impeditivos antes de continuar."
    }

    # 3. Execução da instalação silenciosa do Grid Infrastructure
    echo "===> [04] Executando gridSetup.sh silencioso..."
    su - grid -c "export CV_ASSUME_DISTID=OL8; ${GRID_HOME}/gridSetup.sh -silent -responseFile '${RSP_FILE}' -ignorePrereqFailure" || true

    echo "============================================================================"
    echo " [AÇÃO REQUERIDA] EXECUÇÃO DOS SCRIPTS ROOT DE FORMA SEQUENCIAL:"
    echo " No nó 1 (racnode1) como ROOT:"
    echo "   /u01/app/oraInventory/orainstRoot.sh"
    echo "   ${GRID_HOME}/root.sh"
    echo ""
    echo " No nó 2 (racnode2) como ROOT:"
    echo "   /u01/app/oraInventory/orainstRoot.sh"
    echo "   ${GRID_HOME}/root.sh"
    echo "============================================================================"

    # 4. Executar scripts root locais no racnode1 se rodando como root
    if [ "$(id -u)" -eq 0 ]; then
        echo "===> [04] Executando orainstRoot.sh e root.sh no racnode1..."
        [ -f /u01/app/oraInventory/orainstRoot.sh ] && /u01/app/oraInventory/orainstRoot.sh || true
        [ -f "${GRID_HOME}/root.sh" ] && "${GRID_HOME}/root.sh" || true
    fi
fi
