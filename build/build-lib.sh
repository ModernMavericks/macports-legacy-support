#!/bin/sh
# Cross-build macports-legacy-support to x86_64 / min-10.9 and DESTDIR-install into a
# staging root. Uses the 10.9 SDK ($SDK if set, else mavericks-shipyard's fetch script).
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
MLS_ROOT="$(cd "$SELF/.." && pwd)"; export MLS_ROOT
. "$SELF/lib.sh"

U="$(upstream_version)"
STAGE="${1:-$MLS_ROOT/build/stage}"
src="$(sh "$SELF/fetch-upstream.sh")"
if [ -z "${SDK:-}" ]; then
  SDK="$(sh "$(msc_scripts)/fetch_sdk.sh")"
fi

flags="-isysroot $SDK -mmacosx-version-min=10.9"
make -C "$src" clean >/dev/null 2>&1 || true
make -C "$src" -j"$(sysctl -n hw.ncpu)" \
  PREFIX=/usr/local ARCHS=x86_64 SOCURVERSION="$U" SOCOMPATVERSION=1.0.0 \
  CFLAGS="$flags" LDFLAGS="$flags" all 1>&2

rm -rf "$STAGE"; mkdir -p "$STAGE"
make -C "$src" \
  PREFIX=/usr/local ARCHS=x86_64 SOCURVERSION="$U" SOCOMPATVERSION=1.0.0 \
  DESTDIR="$STAGE" install 1>&2

for f in libMacportsLegacySupport.a libMacportsLegacySupport.dylib; do
  [ -f "$STAGE/usr/local/lib/$f" ] || { echo "build-lib: missing $STAGE/usr/local/lib/$f" >&2; exit 1; }
done
printf '%s\n' "$STAGE"
