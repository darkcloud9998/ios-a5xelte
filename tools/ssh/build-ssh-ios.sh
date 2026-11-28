#!/bin/bash
# Builds, for the S7's iOS userland (arm64, iOS 16), the live channel: Dropbear (public keys only, root only), its scp,
# the dash shell and toybox's utilities. Runs on a macOS CI runner with the iPhoneOS SDK. Usage: build-ssh-ios.sh OUTDIR
set -euo pipefail
OUT=$(mkdir -p "$1" && cd "$1" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=/private/var/herolte/ssh           # where it all lives on the phone
WORK=$(mktemp -d)
SDK=$(xcrun -sdk iphoneos --show-sdk-path)
TARGET="-arch arm64 -isysroot $SDK -miphoneos-version-min=16.0"
CLANG=$(xcrun -sdk iphoneos -f clang)
export CC="$CLANG $TARGET"

fetch() { # url sha256
  local f="$WORK/${1##*/}"
  curl -sSfL --retry 3 -o "$f" "$1"
  echo "$2  $f" | shasum -a 256 -c - >/dev/null
  tar -xf "$f" -C "$WORK"
}
# Dropbear's sum is the one in the release's signed SHA256SUM.asc (signature checked on the PC, 2026-11-27); dash's and
# toybox's are the ones of the files downloaded that day (trust on first use).
fetch https://matt.ucc.asn.au/dropbear/releases/dropbear-2026.94.tar.bz2 e098034a843699200c8c977a991fff73159735bf795d5f72ef672c41a6b1ae81
fetch http://gondor.apana.org.au/~herbert/dash/files/dash-0.5.13.6.tar.gz 26aac476f476cef391c600cb064417d82a5465d8fc7c4fd56158c276e86538c1
fetch https://landley.net/toybox/downloads/toybox-0.8.15.tar.gz 44e2bab43dfe2c171743297631ce558c6d9ed38b87a66fd751cef617574b375e

echo "== dropbear"
cd "$WORK"/dropbear-2026.94
python3 "$HERE/patch-dropbear.py" . "$ROOT/bin/sh"
cat > localoptions.h <<EOF
#define DROPBEAR_SVR_PASSWORD_AUTH 0
#define DROPBEAR_SVR_PAM_AUTH 0
#define DROPBEAR_SVR_PUBKEY_AUTH 1
#define DROPBEAR_REEXEC 0
/* only root logs in (patch-dropbear.py), so there are no privileges to drop; iOS has no setresgid() */
#define DROPBEAR_SVR_DROP_PRIVS 0
#define DROPBEAR_SFTPSERVER 0
#define DROPBEAR_X11FWD 0
#define DROPBEAR_SVR_AGENTFWD 0
#define DROPBEAR_SVR_LOCALTCPFWD 0
#define DROPBEAR_SVR_REMOTETCPFWD 0
#define DROPBEAR_SVR_LOCALSTREAMFWD 0
#define DEFAULT_PATH "$ROOT/bin:/usr/bin:/bin"
#define DEFAULT_ROOT_PATH "$ROOT/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF
./configure --host=aarch64-apple-darwin --disable-zlib --disable-lastlog --disable-utmp --disable-utmpx --disable-wtmp \
  --disable-wtmpx --disable-loginfunc --disable-pututline --disable-pututxline >configure.out 2>&1 || { tail -30 configure.out; exit 1; }
make -j4 PROGRAMS="dropbear scp" >make.out 2>&1 || { grep -m20 -B3 'error' make.out; exit 1; }
cp dropbear scp "$OUT/"

echo "== dash"
cd "$WORK"/dash-0.5.13.6
# strchrnul() is in the SDK but only from iOS 18.4: autoconf finds it, it is NULL on the phone and the shell died on
# its first command (2026-11-27)
./configure --host=arm-apple-darwin CC="$CC" CC_FOR_BUILD="xcrun -sdk macosx clang" ac_cv_func_strchrnul=no >configure.out 2>&1 || { tail -30 configure.out; exit 1; }
make -j4 >make.out 2>&1 || { grep -m20 -B3 'error' make.out; exit 1; }
cp src/dash "$OUT/sh"

echo "== toybox"
cd "$WORK"/toybox-0.8.15
# toybox is optional: if the iPhoneOS SDK lacks something of its macOS configuration, the channel ships without it.
unset CC   # toybox takes CC as one command name; its configuration runs on the Mac
# toybox's scripts expect GNU sed on macOS
brew list gnu-sed >/dev/null 2>&1 || brew install -q gnu-sed >/dev/null 2>&1 || true
PATH="$(brew --prefix)/opt/gnu-sed/libexec/gnubin:$PATH"
# Headers that toybox's macOS side includes and the iPhoneOS SDK leaves out are borrowed from the Mac SDK, one at a
# time, as the compiler asks for them; they only declare what the same XNU kernel provides.
MACSDK=$(xcrun -sdk macosx --show-sdk-path)
SHIM="$WORK/shim"; mkdir -p "$SHIM"
build_toybox() {
  HOSTCC="xcrun -sdk macosx clang" CC="$CLANG" CFLAGS="$TARGET -I$SHIM" LDFLAGS="$TARGET" make -j4 toybox >make.out 2>&1
}
built=
if make macos_defconfig >config.out 2>&1; then
  for round in $(seq 1 40); do
    if build_toybox; then built=1; break; fi
    h=$(sed -n "s/.*fatal error: '\([^']*\)' file not found.*/\1/p" make.out | head -1)
    if [ -n "$h" ] && [ -f "$MACSDK/usr/include/$h" ] && [ ! -f "$SHIM/$h" ]; then
      echo "borrowing $h from the Mac SDK"
      mkdir -p "$SHIM/$(dirname "$h")"; cp "$MACSDK/usr/include/$h" "$SHIM/$h"
      continue
    fi
    # a command the iPhoneOS SDK cannot compile is left out
    bad=$(sed -n 's/.*toys\/[a-z]*\/\([a-z0-9_]*\)\.c:[0-9]*:[0-9]*: .*error: .*/\1/p' make.out | tr 'a-z' 'A-Z' | sort -u)
    changed=
    for c in $bad; do
      if grep -q "^CONFIG_$c=y" .config; then
        echo "leaving out $c"; sed -i.bak "s/^CONFIG_$c=y/# CONFIG_$c is not set/" .config; changed=1
      fi
    done
    [ -n "$changed" ] || break
  done
fi
if [ -n "$built" ]; then
  cp toybox "$OUT/"
  sed -n 's/^CONFIG_\([A-Z0-9_]*\)=y$/\1/p' .config | tr 'A-Z' 'a-z' > "$OUT/toybox.config"
else
  grep -m30 -B3 'error:' make.out | cut -c1-300 || tail -15 config.out
  echo "toybox NOT built"
fi

echo "== hero-images"
"$CLANG" $TARGET -O2 -Wall -o "$OUT/hero-images" "$HERE/hero-images.c"

cd "$OUT"
for f in dropbear scp sh toybox hero-images; do
  [ -f "$f" ] || continue
  strip "$f" 2>/dev/null || true
  codesign -s - -f --entitlements "$HERE/ssh.entitlements" "$f"
  file "$f"
  otool -l "$f" | grep -A4 LC_BUILD_VERSION | grep -E 'platform|minos'
done
# Nothing may be weakly imported: such a symbol is newer than iOS 16 and NULL on the phone.
for f in dropbear scp sh toybox hero-images; do
  [ -f "$f" ] || continue
  weak=$(nm -m "$f" | grep '(undefined) weak external' || true)
  if [ -n "$weak" ]; then
    echo "$f imports symbols that iOS 16 may not have:"; echo "$weak"; exit 1
  fi
done
shasum -a 256 $(ls dropbear scp sh toybox hero-images 2>/dev/null) | tee SHA256SUMS
