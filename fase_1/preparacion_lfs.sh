#!/bin/bash
set -e

# Asegurarnos de que estamos en la carpeta de fuentes
cd $LFS/sources

echo "🚀 Iniciando Construcción del Toolchain (i686)..."

# --- 1. BINUTILS (Pase 1) ---
echo ">>> Compilando Binutils (Pase 1)..."
tar -xf binutils-2.42.tar.xz
cd binutils-2.42
mkdir -v build && cd build
../configure --prefix=$LFS/tools \
             --with-sysroot=$LFS \
             --target=$LFS_TGT   \
             --disable-nls       \
             --disable-werror
make
make install
cd $LFS/sources
rm -rf binutils-2.42

# --- 2. GCC (Pase 1) ---
echo ">>> Compilando GCC (Pase 1)..."
tar -xf gcc-13.2.0.tar.xz
cd gcc-13.2.0
# Descomprimir dependencias internas de GCC
tar -xf ../mpfr-4.2.1.tar.xz && mv -v mpfr-4.2.1 mpfr
tar -xf ../gmp-6.3.0.tar.xz && mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz && mv -v mpc-1.3.1 mpc

mkdir -v build && cd build
../configure                  \
    --target=$LFS_TGT         \
    --prefix=$LFS/tools       \
    --with-glibc-version=2.39 \
    --with-sysroot=$LFS       \
    --with-newlib             \
    --without-headers         \
    --disable-nls             \
    --disable-shared          \
    --disable-multilib        \
    --disable-threads         \
    --disable-libatomic       \
    --disable-libgomp         \
    --disable-libquadmath     \
    --disable-libssp          \
    --disable-libvtv          \
    --disable-libstdcxx       \
    --enable-languages=c,c++
make
make install
cd $LFS/sources
rm -rf gcc-13.2.0

# --- 3. LINUX API HEADERS ---
echo ">>> Instalando Linux API Headers..."
tar -xf linux-6.7.4.tar.xz
cd linux-6.7.4
make mrproper
make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $LFS/usr
cd $LFS/sources
rm -rf linux-6.7.4

# --- 4. GLIBC ---
echo ">>> Compilando Glibc..."
tar -xf glibc-2.39.tar.xz
cd glibc-2.39
patch -Np1 -i ../glibc-2.39-fhs-1.patch
mkdir -v build && cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=4.19               \
      --with-headers=$LFS/usr/include    \
      libc_cv_slibdir=/usr/lib
make
make DESTDIR=$LFS install
# Arreglar un enlace duro que a veces falla en Glibc
sed '/"export_dir"/a \ \ \ \ \ \ \ \ "dir": "/var/cache/nscd"' -i $LFS/usr/share/nscd/nscd.stat
cd $LFS/sources
rm -rf glibc-2.39

# --- 5. EL PARCHE NUCLEAR (Prevención MB_LEN_MAX) ---
echo ">>> Aplicando el Parche Nuclear de límites a GCC..."
tar -xf gcc-13.2.0.tar.xz
find $LFS/tools/lib/gcc -name "limits.h" | while read -r f; do
    echo " ---> Forzando parche en: $f"
    cat gcc-13.2.0/gcc/limitx.h gcc-13.2.0/gcc/glimits.h gcc-13.2.0/gcc/limity.h > "$f"
done
rm -rf gcc-13.2.0

echo "======================================================="
echo "✅ TOOLCHAIN (FASE 1) COMPLETADO CON ÉXITO"
echo "======================================================="
