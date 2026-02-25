#!/bin/bash
set -e

echo "🚀 Iniciando automatización Universal (i686)..."
cd $LFS/sources

# --- COMPROBACIÓN PRE-VUELO ---
echo ">>> Comprobando que están todos los archivos..."
for pkg in binutils gcc glibc gmp mpfr mpc linux; do
    if ! ls ${pkg}-*.* >/dev/null 2>&1; then
        echo "❌ ERROR: No encuentro el paquete '$pkg'. ¡Descarga incompleta!"
        exit 1
    fi
done
echo "✅ Todos los paquetes base están presentes."

# --- 1. BINUTILS ---
echo ">>> [1/4] Compilando Binutils..."
tar -xf binutils-*.tar.xz
cd binutils-[0-9]*/
mkdir -v build && cd build
../configure --prefix=$LFS/tools --with-sysroot=$LFS --target=$LFS_TGT --disable-nls --disable-werror
make && make install
cd $LFS/sources && rm -rf binutils-[0-9]*/

# --- 2. GCC ---
echo ">>> [2/4] Compilando GCC... (Paciencia ☕)"
tar -xf gcc-*.tar.xz
cd gcc-[0-9]*/
tar -xf ../mpfr-*.tar.* && mv -v mpfr-[0-9]* mpfr
tar -xf ../gmp-*.tar.* && mv -v gmp-[0-9]* gmp
tar -xf ../mpc-*.tar.* && mv -v mpc-[0-9]* mpc
mkdir -v build && cd build
../configure --target=$LFS_TGT --prefix=$LFS/tools --with-glibc-version=2.42 --with-sysroot=$LFS --with-newlib --without-headers --disable-bootstrap --enable-default-pie --enable-default-ssp --disable-nls --disable-shared --disable-multilib --disable-threads --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libvtv --disable-libstdcxx --enable-languages=c,c++
make && make install
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
cd $LFS/sources && rm -rf gcc-[0-9]*/

# --- 3. LINUX HEADERS ---
echo ">>> [3/4] Instalando Cabeceras del Kernel..."
tar -xf linux-*.tar.xz
cd linux-[0-9]*/
make mrproper && make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $LFS/usr
cd $LFS/sources && rm -rf linux-[0-9]*/

# --- 4. GLIBC ---
echo ">>> [4/4] Compilando Glibc... (Más paciencia ⏳)"
tar -xf glibc-*.tar.xz
cd glibc-[0-9]*/
patch -Np1 -i ../glibc-*-fhs-1.patch
mkdir -v build && cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure --prefix=/usr --host=$LFS_TGT --build=$(../scripts/config.guess) --enable-kernel=4.19 --with-headers=$LFS/usr/include libc_cv_slibdir=/usr/lib
make && make DESTDIR=$LFS install
sed '/"export_dir"/a \ \ \ \ \ \ \ \ "dir": "/var/cache/nscd"' -i $LFS/usr/share/nscd/nscd.stat
cd $LFS/sources && rm -rf glibc-[0-9]*/

# --- EL PARCHE NUCLEAR ---
echo ">>> ☢️ Aplicando el Parche Preventivo para GCC..."
tar -xf gcc-*.tar.xz
find $LFS/tools/lib/gcc -name "limits.h" | while read -r f; do
    cat gcc-[0-9]*/gcc/limitx.h gcc-[0-9]*/gcc/glimits.h gcc-[0-9]*/gcc/limity.h > "$f"
done
rm -rf gcc-[0-9]*/

echo "======================================================="
echo "✅ FASE 2 (HASTA GLIBC) COMPLETADA CON ÉXITO."
echo "======================================================="
