#!/usr/bin/env bash
# test_gate_pas_prelude_units_in_sync.sh -- SCRIP'S PASCAL PRELUDE UNITS AND THE TABLE SCRIP EMBEDS AGREE (hq_pascal 2026-10-10, row
# pascal-uses-and-units-compile-time-whole-program-...; CEO-1611).
#
# The units a uses clause names and no file beside the program supplies -- sysutils, math, strings, strutils -- are SCRIP's own
# Pascal under src/parsers/pascal/prelude/<unit>.pas, embedded by ../harness/scripts/util_gen_pascal_prelude_units.py into the committed
# src/parsers/pascal/pascal_prelude_units.inc, as the Prolog prelude libraries are (test_gate_pl_prelude_libs_in_sync.sh). A unit
# changed without regenerating, or a table edited by hand, would ship a unit SCRIP's source no longer states.
#
# THE ARMS. (1) --check over the committed tree: rc 0 in sync, rc 1 STALE. (0) SELF-TEST, every run, on scratch copies: a table that
# differs from what the generator writes must read STALE; a unit changed beside an unchanged table must read STALE; an empty prelude
# directory must refuse rc=2. An instrument that cannot see its plants proves nothing by passing: the gate refuses. No build; ~1 s.
# rc=0 in sync · rc=1 stale · rc=2 refused.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="$HERE/util_gen_pascal_prelude_units.py"
P="$HERE/../../SCRIP/src/parsers/pascal/prelude"
INC="$HERE/../../SCRIP/src/parsers/pascal/pascal_prelude_units.inc"
refuse() { echo "⛔ REFUSED(2) [test_gate_pas_prelude_units_in_sync]: $*"; exit 2; }
[ -f "$GEN" ] || refuse "no $GEN"
[ -d "$P" ] || refuse "no $P"
[ -f "$INC" ] || refuse "no $INC"
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cp -r "$P" "$D/drift" && mkdir "$D/empty" && cp "$INC" "$D/stale.inc" && cp "$INC" "$D/same.inc" || refuse "could not copy $P"
first="$(ls "$P"/*.pas | head -1)"; b="$(basename "$first")"
printf '\n' >> "$D/stale.inc"
printf '\n' >> "$D/drift/$b"
python3 "$GEN" --out "$D/stale.inc" --check > "$D/o1" 2>&1; r1=$?
python3 "$GEN" --dir "$D/drift" --out "$D/same.inc" --check > "$D/o2" 2>&1; r2=$?
python3 "$GEN" --dir "$D/empty" --out "$D/z.inc" > "$D/o3" 2>&1; r3=$?
[ "$r1" = 1 ] && grep -q STALE "$D/o1" || refuse "self-test: a table that differs from the generator's did not read STALE (rc=$r1: $(head -c 200 "$D/o1"))"
[ "$r2" = 1 ] && grep -q STALE "$D/o2" || refuse "self-test: a unit changed beside an unchanged table did not read STALE (rc=$r2: $(head -c 200 "$D/o2"))"
[ "$r3" = 2 ] && grep -q REFUSED "$D/o3" || refuse "self-test: an empty prelude directory was not refused (rc=$r3: $(head -c 200 "$D/o3"))"
python3 "$GEN" --check; rc=$?
[ "$rc" = 0 ] && echo "PASS test_gate_pas_prelude_units_in_sync (self-test: a stale table, a changed unit and an empty directory all seen)"
exit "$rc"
