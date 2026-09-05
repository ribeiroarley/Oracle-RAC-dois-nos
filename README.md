# Oracle Database 19c RAC (2 Nós) - Oracle Linux 9 no VirtualBox & Vagrant

Ambiente de automação completa para provisionamento, configuração e orquestração de um cluster **Oracle Real Application Clusters (RAC) 19c (19.3)** de 2 nós (`racnode1` e `racnode2`) sobre **Oracle Linux 9 (UEK7 / Kernel 6.12)** com **Oracle Automatic Storage Management (ASM)**, **Grid Infrastructure** e **Multitenant Database (CDB/PDB)** utilizando discos compartilhados VirtualBox.

---

## 🏛️ Visão Geral da Arquitetura

- **Sistema Operacional:** Oracle Linux 9 (UEK7 / Kernel 6.12, glibc 2.34)
- **Nós do Cluster:** 2 nós (`racnode1.localdomain`, `racnode2.localdomain`)
- **Oracle Grid Infrastructure:** 19c (19.3.0.0.0 Enterprise Edition)
- **Oracle Database (RDBMS):** 19c (19.3.0.0.0 Enterprise Edition Multitenant)
- **Container Database (CDB):** `orcl` (Instâncias ativas: `orcl1` no Nó 1, `orcl2` no Nó 2)
- **Pluggable Database (PDB):** `orclpdb` (Status: `READ WRITE` em ambos os nós)
- **Gerenciamento de Armazenamento:** Oracle ASM com regras persistentes UDEV

```mermaid
graph TD
    subgraph Host["Host Windows (Vagrant + VirtualBox)"]
        subgraph VM1["racnode1 (192.168.56.11 / 192.168.10.11)"]
            CRS1["Grid Infrastructure 19c"]
            ASM1["Instância +ASM1"]
            DB1["Instância orcl1 (Open)"]
            VIP1["racnode1-vip (192.168.56.21)"]
        end

        subgraph VM2["racnode2 (192.168.56.12 / 192.168.10.12)"]
            CRS2["Grid Infrastructure 19c"]
            ASM2["Instância +ASM2"]
            DB2["Instância orcl2 (Open)"]
            VIP2["racnode2-vip (192.168.56.22)"]
        end

        subgraph SCAN["SCAN (Single Client Access Name)"]
            SCAN_NAME["rac-scan.localdomain (192.168.56.31/32/33)"]
        end

        subgraph Storage["Discos Compartilhados ASM (SCSI Shareable)"]
            CRS_DG["+CRS (15 GB - Normal Redundancy / 3 Voting Disks)"]
            DATA_DG["+DATA (30 GB - External Redundancy)"]
            RECO_DG["+RECO (20 GB - External Redundancy / Fast Recovery Area)"]
        end

        VM1 --- Storage
        VM2 --- Storage
        CRS1 <-->|"Cluster Interconnect HAIP (192.168.10.x)"| CRS2
    end
```

---

## ⚙️ Especificações das Máquinas Virtuais e Orquestração Vagrant

A infraestrutura como código (IaC) é definida inteiramente no arquivo `Vagrantfile`, permitindo a criação reprodutível do ambiente:

### 1. Especificações de Hardware & Hypervisor
- **Box Base:** `oraclelinux/9` (Oracle Linux 9 Oficial - UEK7 x86_64).
- **Provedor:** VirtualBox (`virtualbox`).
- **Recursos por Máquina:**
  - **RAM:** `6144 MB` (6 GB por nó / 12 GB dedicados no host).
  - **vCPUs:** `2 vCPUs` por máquina virtual.
  - **Swap Linux:** `4096 MB` (4 GB) por nó para absorver picos de I/O na linkagem e startup.
  - **Promiscuous Mode:** `allow-all` em todas as interfaces de rede do cluster para tráfego VIP/SCAN.

### 2. Arquitetura de Rede Multi-Homed por VM
Cada máquina virtual é provisionada com 3 placas de rede distintas:
1. **Interface 1 (`eth0` - NAT):** Gerenciamento do Vagrant, encaminhamento de portas SSH e acesso externo à internet para download de pacotes.
2. **Interface 2 (`eth1` - Host-Only `192.168.56.x`):** Rede pública do cluster utilizada pelos IPs fixos dos nós, pelos Virtual IPs (VIPs), pelo Single Client Access Name (SCAN) e por clientes externos (SQL Developer, DBeaver, aplicações).
3. **Interface 3 (`eth2` - Internal Network `rac_priv_net` `192.168.10.x`):** Rede isolada de altíssima velocidade do VirtualBox dedicada exclusivamente para o Cluster Interconnect, sincronismo de blocos (Cache Fusion) e High Availability IP (HAIP).

### 3. Armazenamento Compartilhado no VirtualBox (SCSI Shareable)
O Oracle ASM requer que os mesmos discos físicos/virtuais sejam acessíveis simultaneamente por todos os nós sem travamento exclusivo do sistema operacional hospedeiro:
- Criação no diretório `.asm_storage/` de 5 discos virtuais com o tipo `shareable` (`--type shareable` via `VBoxManage createmedium` ou `storageattach`).
- Uma controladora SCSI dedicada é utilizada para o anexo simultâneo sem retenção de lock:
  * `asm-crs01.vdi` (5 GB)
  * `asm-crs02.vdi` (5 GB)
  * `asm-crs03.vdi` (5 GB)
  * `asm-data01.vdi` (30 GB)
  * `asm-reco01.vdi` (20 GB)

### 4. Ciclo de Vida do Ambiente via Vagrant
| Comando | Descrição |
| :--- | :--- |
| `vagrant up` | Cria, configura discos compartilhados e inicializa os nós |
| `vagrant ssh racnode1` | Acesso SSH direto ao nó 1 como usuário `vagrant` |
| `vagrant ssh racnode2` | Acesso SSH direto ao nó 2 como usuário `vagrant` |
| `vagrant halt` | Desligamento gracioso das máquinas virtuais |
| `vagrant reload` | Reinicia as VMs aplicando eventuais novas diretivas do `Vagrantfile` |
| `vagrant status` | Exibe o status atual de execução de cada nó do cluster |

---

## 📸 Evidências de Execução / Validação

### 1. Status Consolidado do Clusterware e Banco (`crsctl stat res -t`)
Evidência dos recursos do clusterware, instâncias `orcl1` e `orcl2`, diskgroups ASM (`+CRS`, `+DATA`, `+RECO`), VIPs e listeners com status `ONLINE` e `STABLE`:
![Status do Clusterware](docs/img/01_cluster_crsctl_status.png)

### 2. Instâncias Ativas no Cluster e PDB Read-Write (`GV$INSTANCE` & `GV$PDBS`)
Consulta no SQL*Plus conectando no cluster e comprovando as instâncias em modo `OPEN` simultaneamente no `racnode1` e `racnode2`, além do PDB `ORCLPDB` em `READ WRITE`:
![Instâncias Ativas GV$INSTANCE](docs/img/02_rac_gv_instance.png)

### 3. Diskgroups ASM e Voting Disks Registrados (`asmcmd lsdg` & `votedisk`)
Evidência do armazenamento ASM e dos 3 voting disks gravados no diskgroup `+CRS`:
![Diskgroups ASM](docs/img/03_asm_storage_lsdg.png)

---

## 💾 Topologia de Armazenamento ASM

Os discos virtuais são configurados como SCSI compartilhados (`shareable`) e mapeados deterministicamente no Linux através de regras de UDEV (`/dev/oracleasm/disks/*`) com permissões `grid:asmadmin`:

| Diskgroup | Discos / UDEV Links | Tamanho Total | Redundância | Finalidade Principal |
| :--- | :--- | :--- | :--- | :--- |
| **`+CRS`** | `/dev/oracleasm/disks/asm-crs01`<br>`/dev/oracleasm/disks/asm-crs02`<br>`/dev/oracleasm/disks/asm-crs03` | 15 GB (3x 5GB) | **NORMAL** | Oracle Cluster Registry (OCR) e 3 Voting Disks |
| **`+DATA`** | `/dev/oracleasm/disks/asm-data01` | 30 GB | **EXTERNAL** | Datafiles, Controlfiles, Redo Logs, SYSTEM/SYSAUX |
| **`+RECO`** | `/dev/oracleasm/disks/asm-reco01` | 20 GB | **EXTERNAL** | Fast Recovery Area (FRA), Arquivos de Redo e Archive Logs |

---

## 🌐 Topologia de Rede

| Hostname | Interface | IP / Subnet | Tipo / Função |
| :--- | :--- | :--- | :--- |
| `racnode1` | `eth1` | `192.168.56.11` / `255.255.255.0` | IP Público / Gestão |
| `racnode1-vip` | `eth1:1` | `192.168.56.21` / `255.255.255.0` | Virtual IP (Failover) |
| `racnode1-priv` | `eth2` | `192.168.10.11` / `255.255.255.0` | Cluster Interconnect / HAIP |
| `racnode2` | `eth1` | `192.168.56.12` / `255.255.255.0` | IP Público / Gestão |
| `racnode2-vip` | `eth1:1` | `192.168.56.22` / `255.255.255.0` | Virtual IP (Failover) |
| `racnode2-priv` | `eth2` | `192.168.10.12` / `255.255.255.0` | Cluster Interconnect / HAIP |
| `rac-scan` | DNS Round-Robin | `192.168.56.31`, `.32`, `.33` | SCAN VIP & SCAN Listeners |

---

## 💻 Pré-requisitos de Hardware e Software

- **Sistema Operacional do Host:** Windows 10/11 x64 ou Linux x86_64
- **Hypervisor:** Oracle VirtualBox 7.0+
- **Orquestrador:** HashiCorp Vagrant 2.3+
- **Memória RAM Host Recomendada:** Mínimo de 16 GB livres (recomendado 32 GB no host para estabilidade de I/O)
- **Recursos por VM:**
  - **RAM:** 6144 MB (6 GB) por nó
  - **Swap:** 4096 MB (4 GB) por nó
  - **vCPUs:** 2 vCPUs por nó
- **Armazenamento:** 80 GB livres em SSD / NVMe

---

## 🛠️ Solução de Problemas Críticos (Troubleshooting & Workarounds)

### 1. Compatibilidade GLIBC 2.34 (Oracle Linux 9) x Oracle 19c Linker
No Oracle Linux 9, a biblioteca C removeu símbolos estáticos legados como `stat`, `lstat` e `fstat` em favor de suas variantes `__xstat`. Para viabilizar a compilação e linkagem de binários do Grid e do Database 19c sem erros de linkers (`libpthread_nonshared.a` e referências indefinidas):
- Criação de stub estático `/usr/lib64/libpthread_nonshared.a`.
- Criação e injeção do shim `/usr/lib64/libstat_shim.a` contendo mapeamento das chamadas de stat e inclusão no `$ORACLE_HOME/lib/sysliblist` e `$GRID_HOME/lib/sysliblist` (`-lstat_shim`).

### 2. Sincronismo de Clock CTSS vs Chrony
Para evitar que o Cluster Synchronization Service daemon (CSSD) ou o Cluster Time Synchronization Service (CTSS) entrem em conflito com o daemon NTP local:
- O serviço `chronyd` foi desativado e mascarado (`systemctl mask chronyd`), permitindo que o CTSS assuma o sincronismo de tempo em modo ativo/passivo entre os nós do cluster.

### 3. Contorno de Checagens do Cluster Verification Utility (CVU)
Como o Oracle 19.3 foi concebido antes da distribuição OL9:
- Definida a variável `export CV_ASSUME_DISTID=OL8` antes da execução dos instaladores (`gridSetup.sh`, `runInstaller` e `dbca`).
- Utilização dos parâmetros `-ignorePrereq` e `-ignorePrereqFailure` para ignorar alertas cosméticos de laboratório.

---

## 🚀 Guia de Execução Passo a Passo

### 1. Posicionamento dos Binários Oficiais Oracle
Coloque os arquivos compactados na pasta `software/` na raiz do projeto:
- `V982068-01.zip` (Oracle Grid Infrastructure 19.3)
- `V982063-01.zip` (Oracle Database Enterprise Edition 19.3)

### 2. Inicialização do Ambiente
```powershell
# Iniciar o provisionamento e subir as VMs
vagrant up
```

### 3. Desligamento Gracioso e Ordenado (Procedimento Recomendado)

Para garantir a integridade dos blocos de dados no ASM, dos voting disks e dos metadados do Clusterware, execute o desligamento na seguinte ordem obrigatória:

#### 1. Parar o Banco de Dados e Serviços (via nó 1)
```powershell
vagrant ssh racnode1 -- -t "sudo su - oracle -c 'srvctl stop database -d orcl -o immediate'"
```

#### 2. Desativar a Pilha do Clusterware (CRS) em Ambos os Nós
```powershell
# No racnode2 primeiro:
vagrant ssh racnode2 -- -t "sudo /u01/app/19.0.0/grid/bin/crsctl stop crs -f"

# No racnode1 em seguida:
vagrant ssh racnode1 -- -t "sudo /u01/app/19.0.0/grid/bin/crsctl stop crs -f"
```

#### 3. Desligar as Máquinas Virtuais no Vagrant
```powershell
vagrant halt racnode2
vagrant halt racnode1
```

### 4. Inicialização Segura do Cluster
Ao reiniciar o laboratório, inicie os nós na ordem canônica para remontagem automática da stack:
```powershell
# Primeiro racnode1 (Master inicial do CRS/ASM):
vagrant up racnode1 --no-provision

# Em seguida racnode2:
vagrant up racnode2 --no-provision
```


---

## 🔍 Guia de Validação Operacional

### 1. Verificar Saúde Geral do Clusterware
```bash
sudo su - grid -c "crsctl check cluster -all"
```
*Saída esperada:* CRS, CSS e EVM com status `online` em ambos os nós.

### 2. Listar Recursos do Cluster
```bash
sudo su - grid -c "crsctl stat res -t"
```

### 3. Verificar Diskgroups ASM e Voting Disks
```bash
sudo su - grid -c "crsctl query css votedisk"
sudo su - grid -c "asmcmd lsdg"
```

### 4. Verificar Status do Banco de Dados RAC
```bash
sudo su - oracle -c "srvctl status database -d orcl"
sudo su - oracle -c "srvctl config database -d orcl"
```

### 5. Consulta de Instâncias e PDBs via SQL*Plus
```bash
sudo su - oracle -c "sqlplus / as sysdba"
```
```sql
SET LINESIZE 200 COLSEP '|';
SELECT inst_id, instance_name, host_name, status, startup_time FROM gv$instance;
SELECT inst_id, con_id, name, open_mode FROM gv$pdbs WHERE name = 'ORCLPDB';
EXIT;
```

---

## 👤 Autor

**Arley Ribeiro**  
👨💻 Técnico em Informática | Suporte, Banco de Dados & SQL

- **LinkedIn:** [linkedin.com/in/ribeiroarley](https://www.linkedin.com/in/ribeiroarley/)
- **GitHub:** [github.com/ribeiroarley](https://github.com/ribeiroarley)

---
⭐ Se este projeto te ajudou a entender ou provisionar um ambiente Oracle RAC 19c no Oracle Linux 9, deixe uma estrela no repositório!


