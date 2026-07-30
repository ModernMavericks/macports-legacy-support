#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
# Prefer the INSTALLED shared-cmake: that is what CI has (install@v1) and what a release is built
# against. Building one from a sibling working copy would test against whatever is checked out there
# -- possibly dirty or unpushed -- and installing it into $HOME/.local is a global side effect a test
# has no business having. Fall back to the sibling only on a dev box that has never installed it, and
# skip (77) when there is neither.
if ! ls "$HOME/.cmake/packages/MavericksSharedCMake/"* >/dev/null 2>&1; then
  [ -d ../mavericks-shared-cmake ] || { echo "no installed shared-cmake and no sibling checkout -- skipping" >&2; exit 77; }
  echo "note: no installed shared-cmake; installing from the sibling checkout (README 'Install (once)')" >&2
  MSC_SRC="$(cd ../mavericks-shared-cmake && pwd)"
  cmake -S "$MSC_SRC" -B "$tmp/msc" >/dev/null
  cmake --install "$tmp/msc" --prefix "$HOME/.local" >/dev/null
fi

printf '1.5.2-mavericks.1\n' > VERSION
B="$tmp/updater"
cmake -S . -B "$B" -DCMAKE_OBJC_COMPILER=/usr/bin/clang >/dev/null
cmake --build "$B" --target LegacySupportUpdater >/dev/null
bin="$B/LegacySupportUpdater.app/Contents/MacOS/LegacySupportUpdater"
[ -x "$bin" ] || { echo "updater binary missing"; exit 1; }
! otool -L "$bin" | grep -qi MacportsLegacySupport || { echo "updater links the library it updates"; exit 1; }
echo "updater-build OK"
