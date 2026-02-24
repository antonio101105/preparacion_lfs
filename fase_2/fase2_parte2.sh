#!/bin/bash
# Fase 2 - Parte 2: Herramientas Base y Pase 2 de Compiladores (LFS 12.1) - CORREGIDO

set -e

if [ "$(whoami)" != "lfs" ]; then
  echo "❌ Error: ¡Este script DEBE ejecutarse como el usuario 'lfs'!"
  exit 1
fi

cd $LFS/sources
echo "🚀 INICIANDO FASE 2 (PARTE 2): HERRAMIENTAS TEMPORALES Y PASE 2"

# Limpieza del intento fallido anterior
rm -rf ncurses-6.4-20230520 2>/dev/null || true

# ==========================================
# 2.6. Herramientas Base Temporales Complejas
# ==========================================
echo ">>> [1/5] Compilando Ncurses (Librería de terminal)..."
tar -xf ncurses-6.4-20230520.tar.xz
cd ncurses-6.4-20230520
sed -i s/mawk// configure
mkdir build
pushd build
  ../configure
  make -C include
  make -C progs tic
popd
./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess) \
            --mandir=/usr/share/man --with-manpage-format=normal \
            --with-shared --without-normal --with-cxx-shared \
            --without-debug --without-ada --disable-stripping --enable-widec
make -j$(nproc)
make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so
cd $LFS/sources && rm -rf ncurses-6.4-20230520

echo ">>> [2/5] Compilando Bash (El intérprete de comandos)..."
tar -xf bash-5.2.21.tar.gz
cd bash-5.2.21
./configure --prefix=/usr --build=$(sh support/config.guess) \
            --host=$LFS_TGT --without-bash-malloc
make -j$(nproc)
make DESTDIR=$LFS install
ln -sv bash $LFS/bin/sh
cd $LFS/sources && rm -rf bash-5.2.21

echo ">>> [3/5] Compilando Coreutils (ls, cat, mkdir, etc.)..."
tar -xf coreutils-9.4.tar.xz
cd coreutils-9.4
./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) \
            --enable-install-program=hostname --enable-no-install-program=kill,uptime
make -j$(nproc)
make DESTDIR=$LFS install
mv -v $LFS/usr/bin/chroot $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' $LFS/usr/share/man/man8/chroot.8
cd $LFS/sources && rm -rf coreutils-9.4

# ==========================================
# 2.6. Bucle de Herramientas Simples (Sed, Grep, Tar, Make...)
# ==========================================
echo ">>> [4/5] Compilando utilidades estándar en lote..."
for pkg in m4-1.4.19 diffutils-3.10 file-5.45 findutils-4.9.0 gawk-5.3.0 grep-3.11 gzip-1.13 make-4.4.1 patch-2.7.6 sed-4.9 tar-1.35 xz-5.4.6; do
  echo " ---> Procesando $pkg..."
  tar -xf $pkg.tar.*
  cd $pkg
  ./configure --prefix=/usr --host=$LFS_TGT --build=$(uname -m)-pc-linux-gnu
  make -j$(nproc)
  make DESTDIR=$LFS install
  cd $LFS/sources && rm -rf $pkg
done

# ==========================================
# 2.5. Binutils y GCC (Pase 2)
# ==========================================
echo ">>> [5/5] Recompilando Binutils (Pase 2)..."
tar -xf binutils-2.42.tar.xz
cd binutils-2.42
sed '6009s/$add_dir//' -i ltmain.sh
mkdir -v build && cd build
../configure --prefix=/usr --build=$(../config.guess) --host=$LFS_TGT \
             --disable-nls --enable-shared --enable-gprofng=no \
             --disable-werror --enable-64-bit-bfd --enable-new-dtags \
             --enable-default-hash-style=gnu
make -j$(nproc)
make DESTDIR=$LFS install
cd $LFS/sources && rm -rf binutils-2.42

echo ">>> [FINAL] Recompilando GCC (Pase 2)..."
tar -xf gcc-13.2.0.tar.xz
cd gcc-13.2.0
tar -xf ../mpfr-4.2.1.tar.xz && mv -v mpfr-4.2.1 mpfr
tar -xf ../gmp-6.3.0.tar.xz && mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz && mv -v mpc-1.3.1 mpc
sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
mkdir -v build && cd build
../configure --build=$(../config.guess) --host=$LFS_TGT --target=$LFS_TGT \
             LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc --prefix=/usr \
             --with-build-sysroot=$LFS --enable-default-pie \
             --enable-default-ssp --disable-nls --disable-multilib \
             --disable-libatomic --disable-libgomp --disable-libquadmath \
             --disable-libsanitizer --disable-libssp --disable-libvtv \
             --enable-languages=c,c++
make -j$(nproc)
make DESTDIR=$LFS install
cd $LFS/sources && rm -rf gcc-13.2.0

echo "====================================================="
echo "✅ ¡FASE 2 COMPLETADA AL 100%!"
echo "Tu entorno cruzado temporal está totalmente listo."
echo "====================================================="
