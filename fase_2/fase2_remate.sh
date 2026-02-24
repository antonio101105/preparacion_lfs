#!/bin/bash
# Remate final de la Fase 2 (Coreutils, Herramientas y Compiladores Fase 2)
set -e

if [ "$(whoami)" != "lfs" ]; then echo "❌ Ejecuta como 'lfs'"; exit 1; fi

export PATH=/usr/bin:/bin:/usr/sbin:/sbin:$LFS/tools/bin
cd $LFS/sources

echo "🧹 Limpiando restos anteriores..."
rm -rf coreutils-9.4 gcc-13.2.0 2>/dev/null || true

echo ">>> [1/4] Reparando límites del compilador (El error MB_LEN_MAX)..."
tar -xf gcc-13.2.0.tar.xz
LIMIT_DIR=$(dirname $($LFS_TGT-gcc -print-libgcc-file-name))
mkdir -pv $LIMIT_DIR/install-tools/include
cat gcc-13.2.0/gcc/limitx.h gcc-13.2.0/gcc/glimits.h gcc-13.2.0/gcc/limity.h > $LIMIT_DIR/install-tools/include/limits.h
rm -rf gcc-13.2.0

echo ">>> [2/4] Compilando Coreutils (ls, mkdir, cat)..."
tar -xf coreutils-9.4.tar.xz
cd coreutils-9.4
./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) --enable-install-program=hostname --enable-no-install-program=kill,uptime
make -j$(nproc)
make DESTDIR=$LFS install
mv -v $LFS/usr/bin/chroot $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' $LFS/usr/share/man/man8/chroot.8
cd $LFS/sources && rm -rf coreutils-9.4

echo ">>> [3/4] Compilando utilidades estándar en bucle..."
for pkg in m4-1.4.19 diffutils-3.10 file-5.45 findutils-4.9.0 gawk-5.3.0 grep-3.11 gzip-1.13 make-4.4.1 patch-2.7.6 sed-4.9 tar-1.35 xz-5.4.6; do
  echo " ---> Procesando $pkg..."
  tar -xf $pkg.tar.*
  cd $pkg
  ./configure --prefix=/usr --host=$LFS_TGT --build=$(uname -m)-pc-linux-gnu
  make -j$(nproc)
  make DESTDIR=$LFS install
  cd $LFS/sources && rm -rf $pkg
done

echo ">>> [4/4] Recompilando Binutils y GCC (Pase 2 Final)..."
tar -xf binutils-2.42.tar.xz
cd binutils-2.42
sed '6009s/$add_dir//' -i ltmain.sh
mkdir -v build && cd build
../configure --prefix=/usr --build=$(../config.guess) --host=$LFS_TGT --disable-nls --enable-shared --enable-gprofng=no --disable-werror --enable-64-bit-bfd --enable-new-dtags --enable-default-hash-style=gnu
make -j$(nproc)
make DESTDIR=$LFS install
cd $LFS/sources && rm -rf binutils-2.42

tar -xf gcc-13.2.0.tar.xz
cd gcc-13.2.0
tar -xf ../mpfr-4.2.1.tar.xz && mv -v mpfr-4.2.1 mpfr
tar -xf ../gmp-6.3.0.tar.xz && mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz && mv -v mpc-1.3.1 mpc
sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
mkdir -v build && cd build
../configure --build=$(../config.guess) --host=$LFS_TGT --target=$LFS_TGT LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc --prefix=/usr --with-build-sysroot=$LFS --enable-default-pie --enable-default-ssp --disable-nls --disable-multilib --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libsanitizer --disable-libssp --disable-libvtv --enable-languages=c,c++
make -j$(nproc)
make DESTDIR=$LFS install
cd $LFS/sources && rm -rf gcc-13.2.0

echo "====================================================="
echo "✅ AHORA SÍ: FASE 2 COMPLETADA AL 100%"
echo "====================================================="
