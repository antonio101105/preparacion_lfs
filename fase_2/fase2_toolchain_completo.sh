#!/bin/bash
# Fase 2 - Parte 1: Construcción de la Cadena de Herramientas (LFS 12.1)
# VERSIÓN DEFINITIVA Y CORREGIDA (Multi-Arquitectura)

set -e # Detener si hay cualquier error

# Corrección 1: Usar whoami en lugar de $USER por el entorno aislado
if [ "$(whoami)" != "lfs" ]; then
  echo "❌ Error: ¡Este script DEBE ejecutarse como el usuario 'lfs'!"
  exit 1
fi

cd $LFS/sources
echo "🚀 INICIANDO FASE 2: COMPILACIÓN DEL TOOLCHAIN (LFS 12.1)"
echo "⚠️ Esto tomará bastante tiempo (dependiendo de tu CPU). No cierres la terminal."

# ==========================================
# 2.1. Binutils (Pase 1)
# ==========================================
echo ">>> [1/5] Compilando Binutils (Pase 1)..."
tar -xf binutils-2.42.tar.xz
cd binutils-2.42
mkdir -v build && cd build
../configure --prefix=$LFS/tools \
             --with-sysroot=$LFS \
             --target=$LFS_TGT   \
             --disable-nls       \
             --enable-gprofng=no \
             --disable-werror    \
             --enable-new-dtags  \
             --enable-default-hash-style=gnu
make -j$(nproc)
make install
cd $LFS/sources && rm -rf binutils-2.42

# ==========================================
# 2.2. GCC (Pase 1)
# ==========================================
echo ">>> [2/5] Compilando GCC (Pase 1)..."
tar -xf gcc-13.2.0.tar.xz
cd gcc-13.2.0
tar -xf ../mpfr-4.2.1.tar.xz && mv -v mpfr-4.2.1 mpfr
tar -xf ../gmp-6.3.0.tar.xz && mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz && mv -v mpc-1.3.1 mpc
sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
mkdir -v build && cd build
../configure                  \
    --target=$LFS_TGT         \
    --prefix=$LFS/tools       \
    --with-glibc-version=2.39 \
    --with-sysroot=$LFS       \
    --with-newlib             \
    --without-headers         \
    --enable-default-pie      \
    --enable-default-ssp      \
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
make -j$(nproc)
make install
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
cd $LFS/sources && rm -rf gcc-13.2.0

# ==========================================
# 2.3. Cabeceras del API del Kernel de Linux
# ==========================================
echo ">>> [3/5] Instalando cabeceras del Kernel..."
tar -xf linux-6.7.4.tar.xz
cd linux-6.7.4
make mrproper
make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $LFS/usr
cd $LFS/sources && rm -rf linux-6.7.4

# ==========================================
# 2.4. Glibc (La librería fundamental)
# ==========================================
echo ">>> [4/5] Compilando Glibc (Esto tardará un rato)..."
tar -xf glibc-2.39.tar.xz
cd glibc-2.39

# Corrección 2: Adaptabilidad a la arquitectura para evitar el error de lib64
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    ;;
esac

patch -Np1 -i ../glibc-2.39-fhs-1.patch
mkdir -v build && cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=4.19               \
      --with-headers=$LFS/usr/include    \
      --disable-nscd                     \
      libc_cv_slibdir=/usr/lib
make -j$(nproc)
make DESTDIR=$LFS install
sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
cd $LFS/sources && rm -rf glibc-2.39

# ==========================================
# 2.5. Libstdc++ (Soporte C++ para GCC)
# ==========================================
echo ">>> [5/5] Compilando Libstdc++..."
tar -xf gcc-13.2.0.tar.xz
cd gcc-13.2.0
mkdir -v build && cd build
../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --build=$(../config.guess)      \
    --prefix=/usr                   \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/13.2.0
make -j$(nproc)
make DESTDIR=$LFS install
cd $LFS/sources && rm -rf gcc-13.2.0

echo "====================================================="
echo "✅ TOOLCHAIN (Parte 1) COMPLETADO CON ÉXITO."
echo "Ya tienes el compilador base y Glibc listos."
echo "====================================================="
