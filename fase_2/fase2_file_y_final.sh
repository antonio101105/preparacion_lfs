#!/bin/bash
# Remate Final de Fase 2 (Desde File-5.45 hasta los Compiladores)
set -e

if [ "$(whoami)" != "lfs" ]; then echo "❌ Ejecuta como 'lfs'"; exit 1; fi

export LFS=/mnt/lfs
export LFS_TGT=$(uname -m)-lfs-linux-gnu
export PATH=$LFS/tools/bin:/bin:/usr/bin:/sbin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"

cd $LFS/sources

echo ">>> [1/4] Compilando 'file' (El paquete rebelde)..."
rm -rf file-5.45 2>/dev/null || true
tar -xf file-5.45.tar.gz
cd file-5.45
mkdir build
pushd build
  ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
  make
popd
./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
make FILE_COMPILE=$(pwd)/build/src/file
make DESTDIR=$LFS install
cd $LFS/sources && rm -rf file-5.45

echo ">>> [2/4] Compilando el resto de utilidades base explícitamente..."

echo " -> findutils..."
tar -xf findutils-4.9.0.tar.xz && cd findutils-4.9.0
./configure --prefix=/usr --localstatedir=/var/lib/locate --host=$LFS_TGT --build=$(build-aux/config.guess)
make && make DESTDIR=$LFS install
cd $LFS/sources && rm -rf findutils-4.9.0

echo " -> gawk..."
tar -xf gawk-5.3.0.tar.xz && cd gawk-5.3.0
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
make && make DESTDIR=$LFS install
cd $LFS/sources && rm -rf gawk-5.3.0

echo " -> grep..."
tar -xf grep-3.11.tar.xz && cd grep-3.11
./configure --prefix=/usr --host=$LFS_TGT
make && make DESTDIR=$LFS install
cd $LFS/sources && rm -rf grep-3.11

echo " -> gzip..."
tar -xf gzip-1.13.tar.xz && cd gzip-1.13
./configure --prefix=/usr --host=$LFS_TGT
make && make DESTDIR=$LFS install
cd $LFS/sources && rm -rf gzip-1.13

echo " -> make..."
tar -xf make-4.4.1.tar.gz && cd make-4.4.1
./configure --prefix=/usr --without-guile --host=$LFS_TGT --build=$(build-aux/config.guess)
make && make DESTDIR=$LFS install
cd $LFS/sources && rm -rf make-4.4.1

echo " -> patch..."
tar -xf patch-2.7.6.tar.xz && cd patch-2.7.6
./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
make && make DESTDIR=$LFS install
cd $LFS/sources && rm -rf patch-2.7.6

echo " -> sed..."
tar -xf sed-4.9.tar.xz && cd sed-4.9
./configure --prefix=/usr --host=$LFS_TGT
make && make DESTDIR=$LFS install
cd $LFS/sources && rm -rf sed-4.9

echo " -> tar..."
tar -xf tar-1.35.tar.xz && cd tar-1.35
./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
make && make DESTDIR=$LFS install
cd $LFS/sources && rm -rf tar-1.35

echo " -> xz..."
tar -xf xz-5.4.6.tar.xz && cd xz-5.4.6
./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) --disable-static --docdir=/usr/share/doc/xz-5.4.6
make && make DESTDIR=$LFS install
cd $LFS/sources && rm -rf xz-5.4.6

echo ">>> [3/4] Binutils (Pase 2 Final)..."
tar -xf binutils-2.42.tar.xz && cd binutils-2.42
sed '6009s/$add_dir//' -i ltmain.sh
mkdir -v build && cd build
../configure --prefix=/usr --build=$(../config.guess) --host=$LFS_TGT --disable-nls --enable-shared --enable-gprofng=no --disable-werror --enable-64-bit-bfd --enable-new-dtags --enable-default-hash-style=gnu
make && make DESTDIR=$LFS install
cd $LFS/sources && rm -rf binutils-2.42

echo ">>> [4/4] GCC (Pase 2 Final)..."
tar -xf gcc-13.2.0.tar.xz && cd gcc-13.2.0
tar -xf ../mpfr-4.2.1.tar.xz && mv -v mpfr-4.2.1 mpfr
tar -xf ../gmp-6.3.0.tar.xz && mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz && mv -v mpc-1.3.1 mpc
sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
mkdir -v build && cd build
../configure --build=$(../config.guess) --host=$LFS_TGT --target=$LFS_TGT LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc --prefix=/usr --with-build-sysroot=$LFS --enable-default-pie --enable-default-ssp --disable-nls --disable-multilib --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libsanitizer --disable-libssp --disable-libvtv --enable-languages=c,c++
make && make DESTDIR=$LFS install
ln -sv gcc $LFS/usr/bin/cc
cd $LFS/sources && rm -rf gcc-13.2.0

echo "====================================================="
echo "✅ FASE 2 COMPLETADA. ¡ESTAMOS LISTOS PARA EL CHROOT!"
echo "====================================================="
