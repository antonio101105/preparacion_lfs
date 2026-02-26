#!/bin/bash
set -e

# --- CONFIGURACIÓN DE ENTORNO ---
export LFS=/mnt/lfs
export LFS_TGT=i686-pc-linux-gnu
export PATH=$LFS/tools/bin:/usr/bin:/bin
export MAKEFLAGS="-j1"

echo "🛠️ Iniciando Fase 2.5 y 2.6: Compilación de herramientas básicas..."
cd $LFS/sources

# --- 2.5 Libstdc++ (Pase 1) ---
echo ">>> Compilando Libstdc++..."
tar -xf gcc-*.tar.xz
cd gcc-[0-9]*/
mkdir -v build && cd build
../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --build=$(../config.guess)      \
    --prefix=/usr                   \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/15.2.0
make && make DESTDIR=$LFS install
cd $LFS/sources && rm -rf gcc-[0-9]*/

# --- 2.6 EL BATALLÓN DE HERRAMIENTAS (Versiones Automáticas) ---

# Función para compilar paquetes estándar (configure, make, install)
compile_pkg() {
    local name=$1
    echo ">>> Instalando $name..."
    tar -xf ${name}-*.tar.*
    cd ${name}-[0-9]*/
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(../build-aux/config.guess 2>/dev/null || ../config.guess)
    make && make DESTDIR=$LFS install
    cd $LFS/sources && rm -rf ${name}-[0-9]*/
}

# M4
compile_pkg "m4"

# Ncurses
echo ">>> Instalando Ncurses..."
tar -xf ncurses-*.tar.gz
cd ncurses-[0-9]*/
sed -i s/mawk// configure
mkdir build
pushd build
  ../configure
  make -C include
  make -C progs tic
popd
./configure --prefix=/usr                \
            --host=$LFS_TGT              \
            --build=$(./config.guess)    \
            --mandir=/usr/share/man      \
            --with-manpage-format=normal \
            --with-shared                \
            --without-debug              \
            --without-ada                \
            --without-normal             \
            --disable-stripping          \
            --enable-widec
make && make DESTDIR=$LFS install
ln -sv libncursesw.so $LFS/usr/lib/libncurses.so
sed -e 's/^#cur_term/cur_term/' -i $LFS/usr/include/curses.h
cd $LFS/sources && rm -rf ncurses-[0-9]*/

# Bash
echo ">>> Instalando Bash..."
tar -xf bash-*.tar.gz
cd bash-[0-9]*/
./configure --prefix=/usr                   \
            --build=$(sh support/config.guess) \
            --host=$LFS_TGT                 \
            --without-bash-malloc
make && make DESTDIR=$LFS install
ln -sv bash $LFS/bin/sh
cd $LFS/sources && rm -rf bash-[0-9]*/

# Coreutils
echo ">>> Instalando Coreutils..."
tar -xf coreutils-*.tar.xz
cd coreutils-[0-9]*/
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime
make && make DESTDIR=$LFS install
mv -v $LFS/usr/bin/chroot $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"man1"/"man8"/' $LFS/usr/share/man/man8/chroot.8
cd $LFS/sources && rm -rf coreutils-[0-9]*/

# Diffutils, File, Findutils, Gawk, Grep, Gzip, Make, Patch, Sed, Tar, Xz
for p in diffutils file findutils gawk grep gzip make patch sed tar xz; do
    compile_pkg "$p"
done

# Binutils (Pase 2)
echo ">>> Instalando Binutils (Pase 2)..."
tar -xf binutils-*.tar.xz
cd binutils-[0-9]*/
mkdir -v build && cd build
../configure --prefix=/usr --build=$(../config.guess) --host=$LFS_TGT --disable-nls --enable-shared --enable-gprofng=no --disable-werror --enable-64-bit-bfd
make && make DESTDIR=$LFS install
rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.la
cd $LFS/sources && rm -rf binutils-[0-9]*/

# GCC (Pase 2) - EL FINAL
echo ">>> Instalando GCC (Pase 2)..."
tar -xf gcc-*.tar.xz
cd gcc-[0-9]*/
tar -xf ../mpfr-*.tar.* && mv -v mpfr-[0-9]* mpfr
tar -xf ../gmp-*.tar.* && mv -v gmp-[0-9]* gmp
tar -xf ../mpc-*.tar.* && mv -v mpc-[0-9]* mpc
mkdir -v build && cd build
../configure --build=$(../config.guess) --host=$LFS_TGT --target=$LFS_TGT --LDFLAGS="-Wl,-rpath,/tools/lib" --prefix=/usr --with-build-sysroot=$LFS --enable-default-pie --enable-default-ssp --disable-nls --disable-multilib --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libsanitizer --disable-libssp --disable-libvtv --enable-languages=c,c++
make && make DESTDIR=$LFS install
ln -sv gcc $LFS/usr/bin/cc
cd $LFS/sources && rm -rf gcc-[0-9]*/

echo "-------------------------------------------------------"
echo "✅ ¡ENHORABUENA! LA FASE 2 HA TERMINADO POR COMPLETO."
echo "Próximo paso: Entrar en el entorno chroot (Fase 3)."
echo "-------------------------------------------------------"
