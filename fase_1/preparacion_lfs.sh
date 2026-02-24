# 1. Asegurarnos de estar en tu carpeta de usuario
cd /root

# 2. Crear el script de continuación
cat << 'EOF' > continuar_lfs.sh
#!/bin/bash
set -e
export LFS="/mnt/lfs"

echo "=== REANUDANDO FASE 1.3: Cambiando servidor y descargando ==="
cd $LFS/sources

# Cambiamos las URLs del servidor caído por el mirror oficial de Kernel.org
sed -i 's|https://ftp.gnu.org/gnu|https://mirrors.kernel.org/gnu|g' wget-list

# Continuamos la descarga justo donde se quedó
wget --input-file=wget-list --continue

echo "Verificando integridad de todas las descargas..."
md5sum -c md5sums

echo "=== FASE 1.4: Configuración de usuario lfs ==="
mkdir -pv $LFS/{etc,var,tools}
mkdir -pv $LFS/usr/{bin,lib,sbin}
for i in bin lib sbin; do [ ! -e $LFS/$i ] && ln -sv usr/$i $LFS/$i; done
case $(uname -m) in x86_64) mkdir -pv $LFS/lib64 ;; esac

getent group lfs >/dev/null || groupadd lfs
id -u lfs >/dev/null 2>&1 || useradd -s /bin/bash -g lfs -m -k /dev/null lfs

echo "---------------------------------------------------------"
echo "🔑 Introduce una contraseña para el usuario lfs:"
passwd lfs

chown -v lfs $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools}
chown -v lfs $LFS/sources
case $(uname -m) in x86_64) chown -v lfs $LFS/lib64 ;; esac

tee /home/lfs/.bash_profile > /dev/null << "INNER_EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
INNER_EOF

tee /home/lfs/.bashrc > /dev/null << "INNER_EOF"
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
INNER_EOF
chown lfs:lfs /home/lfs/.bash_profile /home/lfs/.bashrc

echo "====================================================="
echo "✅ ¡FASE 1 COMPLETADA CON ÉXITO!"
echo "====================================================="
EOF

# 3. Darle permisos y ejecutarlo
chmod +x continuar_lfs.sh
./continuar_lfs.sh
