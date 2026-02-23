#!/bin/bash
# Script de Preparación Fase 1 LFS (Optimizado para Debian 13 - VERSIÓN CORREGIDA)

set -e # Detener en caso de error

if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Por favor, ejecuta este script como root."
  exit 1
fi

DISCO="/dev/sdb"
export LFS="/mnt/lfs"

# === SISTEMA ANTI-BLOQUEOS ===
# Si el disco se quedó montado por un error previo, lo desmontamos primero
echo "Comprobando bloqueos previos del disco..."
umount $LFS 2>/dev/null || true
umount ${DISCO}1 2>/dev/null || true

echo "=== FASE 1.1: Instalando dependencias ==="
apt update && apt upgrade -y
apt install -y build-essential bison gawk texinfo python3 wget m4 flex \
  libncurses-dev bc libelf-dev libssl-dev dwarves zstd curl git coreutils \
  diffutils findutils grep sed tar xz-utils bzip2 gzip patch parted ca-certificates

echo "dash dash/sh boolean false" | debconf-set-selections
dpkg-reconfigure -f noninteractive dash

echo "=== FASE 1.2: Particionado y Montaje en $DISCO ==="
parted -s $DISCO mklabel msdos
parted -s $DISCO mkpart primary ext4 0% 100%
mkfs.ext4 -L LFS-SYSTEM ${DISCO}1
mkdir -pv $LFS
mount -v -t ext4 ${DISCO}1 $LFS

echo "=== FASE 1.3: Recolección de Fuentes y Estructura LFS ==="
mkdir -vp $LFS/sources
chmod -v a+wt $LFS/sources

cd $LFS/sources

# DESCARGAS CORREGIDAS (Sin el -sysv)
wget https://www.linuxfromscratch.org/lfs/downloads/12.1/wget-list
wget https://www.linuxfromscratch.org/lfs/downloads/12.1/md5sums
wget --input-file=wget-list --continue --directory-prefix=$LFS/sources

echo "Verificando integridad de las descargas (MD5)..."
md5sum -c md5sums

mkdir -pv $LFS/{etc,var,tools}
mkdir -pv $LFS/usr/{bin,lib,sbin}

for i in bin lib sbin; do
  [ ! -e $LFS/$i ] && ln -sv usr/$i $LFS/$i
done

case $(uname -m) in
  x86_64) mkdir -pv $LFS/lib64 ;;
esac

echo "=== FASE 1.4: Configuración del usuario 'lfs' y aislamiento ==="
getent group lfs >/dev/null || groupadd lfs
id -u lfs >/dev/null 2>&1 || useradd -s /bin/bash -g lfs -m -k /dev/null lfs

echo "---------------------------------------------------------"
echo "🔑 Por favor, introduce una contraseña para el usuario 'lfs'"
echo "---------------------------------------------------------"
passwd lfs

chown -v lfs $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools}
chown -v lfs $LFS/sources
case $(uname -m) in
  x86_64) chown -v lfs $LFS/lib64 ;;
esac

tee /home/lfs/.bash_profile > /dev/null << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

tee /home/lfs/.bashrc > /dev/null << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE MAKEFLAGS="-j$(nproc)"
EOF

chown lfs:lfs /home/lfs/.bash_profile /home/lfs/.bashrc

echo "====================================================="
echo "✅ ¡FASE 1 COMPLETADA CON ÉXITO!"
echo "Tu entorno LFS está preparado y asilado en Debian 13."
echo "Para iniciar tu sesión aislada y comenzar a compilar, ejecuta:"
echo "su - lfs"
echo "====================================================="
