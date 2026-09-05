#!/usr/bin/env bash
# ==============================================================================
# Script: 05_db_install.sh
# Finalidade: Extração do RDBMS 23ai no $ORACLE_HOME, instalação silenciosa
#             dos binários em ambos os nós e criação do banco RAC via DBCA.
# ==============================================================================

set -euo pipefail

SOFTWARE_DIR="/vagrant/software"
DB_ZIP=$(find "${SOFTWARE_DIR}" -maxdepth 1 \( -iname "V982063-01.zip" -o -iname "*db_home*.zip" -o -iname "*database*.zip" -o -iname "*LINUX*db*" \) | head -n 1)
ORACLE_HOME="/u01/app/oracle/product/19.0.0/dbhome_1"
RSP_FILE="/vagrant/templates/db_install.rsp"
DB_NAME="orcl"

export CV_ASSUME_DISTID=OL8

echo "===> [05] Verificando binários do Oracle Database 19c..."

if [ -z "${DB_ZIP}" ] || [ ! -f "${DB_ZIP}" ]; then
    echo "[-] ERRO: Arquivo zip do Oracle Database não encontrado em: ${SOFTWARE_DIR}"
    echo "[-] Coloque o arquivo zip de instalação (ex: V982063-01.zip ou LINUX.X64_193000_db_home.zip) no diretório ./software do host."
    exit 1
fi

echo "[+] Binário encontrado: ${DB_ZIP}"

if [ "$(hostname -s)" = "racnode1" ]; then
    # 1. Extração do zip do RDBMS dentro do $ORACLE_HOME
    if [ ! -f "${ORACLE_HOME}/runInstaller" ]; then
        echo "===> [05] Extraindo Oracle Database zip em ${ORACLE_HOME}..."
        su - oracle -c "unzip -q -o '${DB_ZIP}' -d '${ORACLE_HOME}'"
    fi

    # 2. Execução do instalador do RDBMS silencioso (Cluster RAC)
    echo "===> [05] Instalando binários do Oracle Database RAC nos dois nós..."
    su - oracle -c "export CV_ASSUME_DISTID=OL8; ${ORACLE_HOME}/runInstaller -silent -responseFile '${RSP_FILE}' -ignorePrereqFailure" || true

    echo "============================================================================"
    echo " [AÇÃO REQUERIDA] EXECUÇÃO DO ROOT.SH DO RDBMS NOS DOIS NÓS:"
    echo " No nó 1 (racnode1) como ROOT: ${ORACLE_HOME}/root.sh"
    echo " No nó 2 (racnode2) como ROOT: ${ORACLE_HOME}/root.sh"
    echo "============================================================================"

    if [ "$(id -u)" -eq 0 ]; then
        echo "===> [05] Executando root.sh local do RDBMS no racnode1..."
        [ -f "${ORACLE_HOME}/root.sh" ] && "${ORACLE_HOME}/root.sh" || true
    fi

    # 3. Criação do Banco de Dados RAC via DBCA
    echo "===> [05] Criando Banco de Dados RAC (${DB_NAME}) via DBCA silencioso..."
    su - oracle -c "dbca -silent -createDatabase \
        -templateName General_Purpose.dbc \
        -gdbName ${DB_NAME} \
        -sid ${DB_NAME} \
        -createAsContainerDatabase false \
        -sysPassword 'Oracle_23ai_RAC' \
        -systemPassword 'Oracle_23ai_RAC' \
        -nodelist racnode1,racnode2 \
        -datafileDestination '+DATA' \
        -recoveryAreaDestination '+RECO' \
        -storageType ASM \
        -characterset AL32UTF8 \
        -nationalCharacterSet AL16UTF16 \
        -sampleSchema false \
        -databaseType MULTIPURPOSE" || true

    echo "===> [05] Banco de Dados RAC criado com sucesso."
fi
