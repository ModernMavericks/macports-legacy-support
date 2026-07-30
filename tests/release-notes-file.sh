#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Case 1: no matching notes file -> a generated, non-empty default mentioning the version.
f="$(sh build/release-notes-file.sh 9.9.9-mavericks.1 9.9.9-mavericks.1)"
[ -f "$f" ] && [ -s "$f" ] || { echo "generated notes file missing/empty"; exit 1; }
grep -q '9.9.9-mavericks.1' "$f" || { echo "generated notes missing version"; exit 1; }
# Case 2: an existing note supplies the prose, but the returned path is a TEMP COPY -- the shared
# implementation appends a generated build-ingredient section, and must never edit a tracked file to
# do it. (This assertion used to require the tracked path itself, which forbade that section.)
mkdir -p release-notes
real="release-notes/0.0.0-test.md"; printf 'real notes\n' > "$real"
before="$(git hash-object "$real")"
out="$(sh build/release-notes-file.sh 0.0.0-test 0.0.0-test)"
case "$out" in */release-notes/*) echo "returned the tracked file, not a copy: $out"; rm -f "$real"; exit 1;; esac
head -1 "$out" | grep -q 'real notes' || { echo "prose not preserved"; rm -f "$real"; exit 1; }
[ "$before" = "$(git hash-object "$real")" ] || { echo "tracked note was edited in place"; rm -f "$real"; exit 1; }
rm -f "$real" "$out"
echo "release-notes-file OK"
