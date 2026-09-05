#!/usr/bin/env bash
# ==============================================================================
# Script: 01_os_prep.sh
# Finalidade: Preparação do SO Oracle Linux 9 para Oracle RAC 23ai
#             (Preinstall 23ai, Chrony, Grupos/Usuários OFA, Limites, SELinux)
# ==============================================================================

set -euo pipefail

NODE_NAME="${1:-$(hostname -s)}"

echo "===> [01] Preparando Sistema Operacional no host: ${NODE_NAME}"

# 1. Instalação de repositórios e pacote de pré-instalação Oracle 23ai
dnf install -y oracle-database-preinstall-23ai chrony kmod-kvdo libaio libnsl bc sysstat smartmontools expect

# 2. Configuração de Grupos e Usuários (OFA)
echo "===> [01] Configurando grupos e usuários (grid e oracle)..."
groupadd -g 54321 oinstall 2>/dev/null || true
groupadd -g 54322 dba 2>/dev/null || true
groupadd -g 54323 oper 2>/dev/null || true
groupadd -g 54324 backupdba 2>/dev/null || true
groupadd -g 54325 dgdba 2>/dev/null || true
groupadd -g 54326 kmdba 2>/dev/null || true
groupadd -g 54327 asmdba 2>/dev/null || true
groupadd -g 54328 asmoper 2>/dev/null || true
groupadd -g 54329 asmadmin 2>/dev/null || true
groupadd -g 54330 racdba 2>/dev/null || true

# Usuário grid (proprietário do Grid Infrastructure e ASM)
if id "grid" &>/dev/null; then
    usermod -u 54331 -g oinstall -G asmadmin,asmdba,asmoper,dba,racdba grid
else
    useradd -u 54331 -g oinstall -G asmadmin,asmdba,asmoper,dba,racdba -m -d /home/grid -s /bin/bash grid
fi

# Usuário oracle (proprietário do RDBMS)
if id "oracle" &>/dev/null; then
    usermod -u 54321 -g oinstall -G dba,asmdba,oper,backupdba,dgdba,kmdba,racdba oracle
else
    useradd -u 54321 -g oinstall -G dba,asmdba,oper,backupdba,dgdba,kmdba,racdba -m -d /home/oracle -s /bin/bash oracle
fi

echo "oracle:oracle" | chpasswd
echo "grid:grid" | chpasswd

# 3. Estrutura de Diretórios OFA para Oracle 19c
echo "===> [01] Criando estrutura de diretórios OFA..."
mkdir -p /u01/app/19.0.0/grid
mkdir -p /u01/app/grid
mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1
mkdir -p /u01/app/oraInventory

chown -R grid:oinstall /u01
chown -R oracle:oinstall /u01/app/oracle
chown -R grid:oinstall /u01/app/19.0.0
chown -R grid:oinstall /u01/app/grid
chown -R grid:oinstall /u01/app/oraInventory
chmod -R 775 /u01

# 4. Configuração do Chrony (Time Sync)
echo "===> [01] Configurando Chrony para o RAC..."
sed -i '/^server/d' /etc/chrony.conf
cat << 'EOF' >> /etc/chrony.conf
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
makestep 1.0 3
rtcsync
EOF
systemctl enable --now chronyd
systemctl restart chronyd

# 5. Desativação do Firewall e Ajuste do SELinux para Permissive
systemctl stop firewalld || true
systemctl disable firewalld || true
setenforce 0 || true
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

# 6. Variáveis de Ambiente para os usuários grid e oracle (Oracle 19c + OL9 compatibilidade)
cat << 'EOF' > /home/grid/.bash_profile
# .bash_profile - Grid User
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

export ORACLE_SID=+ASM1
if [ "$(hostname -s)" = "racnode2" ]; then
    export ORACLE_SID=+ASM2
fi
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/19.0.0/grid
export CV_ASSUME_DISTID=OL8
export PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
umask 022
EOF
chown grid:oinstall /home/grid/.bash_profile

cat << 'EOF' > /home/oracle/.bash_profile
# .bash_profile - Oracle User
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

export ORACLE_UNQNAME=orcl
export ORACLE_SID=orcl1
if [ "$(hostname -s)" = "racnode2" ]; then
    export ORACLE_SID=orcl2
fi
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export CV_ASSUME_DISTID=OL8
export PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
umask 022
EOF
chown oracle:oinstall /home/oracle/.bash_profile

echo "===> [01] Preparação do SO finalizada com sucesso."
