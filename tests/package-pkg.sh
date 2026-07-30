#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Installs shared-cmake from a sibling checkout (see below), which CI does not have -- it uses the
# action. Not applicable there: exit 77 = SKIP (the family convention), rather than failing a run that
# was never going to have a sibling. It failed outright until the suite started running in CI.
[ -d ../mavericks-shared-cmake ] || { echo "no sibling shared-cmake checkout (CI uses the action) -- skipping" >&2; exit 77; }
STAGE="$(mktemp -d)/stage"
SDK="$(xcrun --show-sdk-path)" sh build/build-lib.sh "$STAGE" >/dev/null

printf '1.5.2-mavericks.1\n' > VERSION
tmp="$(mktemp -d)"
MSC_SRC="$(cd ../mavericks-shared-cmake && pwd)"
cmake -S "$MSC_SRC" -B "$tmp/msc" >/dev/null; cmake --install "$tmp/msc" --prefix "$HOME/.local" >/dev/null
cmake -S . -B "$tmp/updater" -DCMAKE_OBJC_COMPILER=/usr/bin/clang >/dev/null
cmake --build "$tmp/updater" --target LegacySupportUpdater >/dev/null

OUT="$tmp/out"
pkg="$(STAGE="$STAGE" UPD_APP="$tmp/updater/LegacySupportUpdater.app" \
       VERSION=1.5.2-mavericks.1 OUT="$OUT" sh build/package-pkg.sh)"
[ -f "$pkg" ] || { echo "no pkg produced"; exit 1; }
X="$(mktemp -d)"; pkgutil --expand "$pkg" "$X/x"
grep -q 'os-version min="10.9.5"' "$X/x/Distribution" || { echo "10.9.5 floor missing"; exit 1; }
# payload must carry the library, the updater .app, and the LaunchAgent.
# On this host, `pkgutil --expand` of a productbuild archive leaves each
# component as an unpacked directory (Bom/Payload/Scripts/PackageInfo)
# rather than a flat .pkg that `pkgutil --payload-files` can open, so read
# the payload listing straight out of the component's Bom via lsbom(8)
# (the same data `pkgutil --payload-files` is documented to report).
COMP="$(ls -d "$X/x/"*.pkg | head -1)"
BOM="$(lsbom "$COMP/Bom")"
printf '%s\n' "$BOM" | grep -q 'usr/local/lib/libMacportsLegacySupport.dylib' || { echo "lib not in payload"; exit 1; }
printf '%s\n' "$BOM" | grep -q 'LegacySupportUpdater.app' || { echo "updater not in payload"; exit 1; }
printf '%s\n' "$BOM" | grep -q 'Library/LaunchAgents/dev.modernmavericks.macports-legacy-support-updatecheck.plist' || { echo "LaunchAgent not in payload"; exit 1; }
echo "package-pkg OK -> $pkg"
