#!/usr/bin/env bash
# util_vendor_unicon_tests.sh -- VENDOR UNICON'S OWN TESTS INTO corpus/packages/icon/unicon_tests (hq_unicon, ceo CEO-2072; row icon-unitests-...).
# Source: /home/resources/unicon/tests (the git drop d784f58).  Layout (provenance kept, as arizona_tests keeps upstream's): <category>/NAME.icn beside its
# NAME.dat (upstream's data/NAME.dat is the program's stdin, copied BESIDE the source as the Icon packages' convention reads it), the category's other
# regular files beside, upstream's data/ and stand/ kept verbatim as subdirectories (depth 2: never a unit; stand/NAME.std is upstream's own expected output,
# the oracle's answer is the ref and ALL.ref is cut from the oracle).  Makefiles are not vendored.  --with-crypto adds the crypto category (held until the
# oracle build has OpenSSL).  Idempotent: rsync-free plain cp over an existing tree, never a delete.
# Usage: bash ../harness/scripts/util_vendor_unicon_tests.sh [--with-crypto]      rc 0 vendored - rc 2 REFUSAL (no source tree)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC=/home/resources/unicon/tests
DST="$HERE/../../corpus/packages/icon/unicon_tests"
[ -d "$SRC" ] || { echo "REFUSED(2) [vendor_unicon_tests]: no Unicon tests at $SRC"; exit 2; }
[ -d "$HERE/../../corpus/packages/icon" ] || { echo "REFUSED(2) [vendor_unicon_tests]: no corpus/packages/icon beside the harness"; exit 2; }
CATS="general coexpr pattern lib ipl posix thread unicon samples mt udb special calling database graphics bench"
[ "${1:-}" = --with-crypto ] && CATS="$CATS crypto"
mkdir -p "$DST" || exit 2
n=0
for c in $CATS; do
  [ -d "$SRC/$c" ] || continue
  mkdir -p "$DST/$c"
  for f in "$SRC/$c"/*; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in Makefile|Makefile.*|*.u|*.u1|*.u2|*.exe) continue ;; esac
    cp -p "$f" "$DST/$c/" && n=$((n+1))
  done
  if [ -d "$SRC/$c/data" ]; then
    mkdir -p "$DST/$c/data"; cp -pR "$SRC/$c/data/." "$DST/$c/data/"
    for dat in "$SRC/$c"/data/*.dat; do [ -f "$dat" ] || continue; [ -f "$SRC/$c/$(basename "$dat" .dat).icn" ] && cp -p "$dat" "$DST/$c/"; done
  fi
  if [ -d "$SRC/$c/stand" ]; then mkdir -p "$DST/$c/stand"; cp -pR "$SRC/$c/stand/." "$DST/$c/stand/"; fi
done
echo "vendored $n files from $SRC into $DST (categories: $CATS)"
exit 0
