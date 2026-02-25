#!/bin/bash
set -e

echo "🚀 Iniciando automatización: Toolchain (Parte 1) para i686..."

# Comprobación de seguridad para evitar romper Debian
if [ "$(whoami)" != "lfs" ]; then
    echo "❌ ¡Alto! Debes ejecutar este script como el usuario 'lfs'."
    exit 1
fi

cd $LFS/sources

# --- 2.1 BINUTILS (Pase 1) ---
echo ">>> [1/4] Compilando Binutils (Pase 1)..."
tar -xf binutils-2.42.tar.xz
cd binutils-2.42
mkdir -v build && cd build
../configure --prefix=$LFS/tools --with-sysroot=$LFS --target=$LFS_TGT --disable-nls --disable-werror
make && make install
cd $LFS/sources && rm -rf binutils-2.42

# --- 2.2 GCC (Pase 1) ---
echo ">>> [2/4] Compilando GCC (Pase 1)... (Café time ☕)"
tar -xf gcc-13.2.0.tar.xz
cd gcc-13.2.0
tar -xf ../mpfr-4.2.1.tar.xz && mv -v mpfr-4.2.1 mpfr
tar -xf ../gmp-6.3.0.tar.xz && mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz && mv -v mpc-1.3.1 mpc
mkdir -v build && cd build
../configure --target=$LFS_TGT --prefix=$LFS/tools --with-glibc-version=2.39 --with-sysroot=$LFS --with-newlib --without-headers --enable-default-pie --enable-default-ssp --disable-nls --disable-shared --disable-multilib --disable-threads --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libvtv --disable-libstdcxx --enable-languages=c,c++
make && make install
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
cd $LFS/sources && rm -rf gcc-13.2.0

# --- 2.3 LINUX HEADERS ---
echo ">>> [3/4] Instalando Cabeceras del Kernel..."
tar -xf linux-6.7.4.tar.xz
cd linux-6.7.4
make mrproper && make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $LFS/usr
cd $LFS/sources && rm -rf linux-6.7.4

# --- 2.4 GLIBC ---
echo ">>> [4/4] Compilando Glibc... (Paciencia ⏳)"
tar -xf glibc-2.39.tar.xz
cd glibc-2.39
patch -Np1 -i ../glibc-2.39-fhs-1.patch
mkdir -v build && cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure --prefix=/usr --host=$LFS_TGT --build=$(../scripts/config.guess) --enable-kernel=4.19 --with-headers=$LFS/usr/include libc_cv_slibdir=/usr/lib
make && make DESTDIR=$LFS install
sed '/"export_dir"/a \ \ \ \ \ \ \ \ "dir": "/var/cache/nscd"' -i $LFS/usr/share/nscd/nscd.stat
cd $LFS/sources && rm -rf glibc-2.39

# --- PARCHE NUCLEAR PREVENTIVO ---
echo ">>> ☢️ Aplicando el Parche Nuclear Preventivo..."
tar -xf gcc-13.2.0.tar.xz
find $LFS/tools/lib/gcc -name "limits.h" | while read -r f; do
    cat gcc-13.2.0/gcc/limitx.h gcc-13.2.0/gcc/glimits.h gcc-13.2.0/gcc/limity.h > "$f"
done
rm -rf gcc-13.2.0

echo "======================================================="
echo "✅ FASE 2 (HASTA GLIBC) COMPLETADA."
echo "======================================================="
