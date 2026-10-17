#!/usr/bin/env bash
# test_gate_pl_prelude_libs_in_sync.sh -- THE VENDORED SWI LIBRARIES AND THE TABLE SCRIP EMBEDS AGREE (cfo 2026-10-10, row
# prolog-swi-library-modules-rbtrees-assoc-ordsets-apply-error-pairs-aggregate-option-strings-516-swi-cases; CEO-1473).
#
# THE RULING (CEO-1473): swipl's pure-Prolog libraries are vendored under src/parsers/prolog/prelude/<lib>.pl with their BSD
# headers and embedded by a generator at build like the parsers.  The generator is ../harness/scripts/util_gen_prolog_prelude_libs.py;
# its product src/parsers/prolog/prolog_prelude_libs.inc is committed, as the parsers' .tab.c are, so a vendored file
# changed without regenerating (or a table edited by hand) would ship a library SCRIP's source no longer states.
#
# THE ARMS. (1) --check over the committed tree: rc 0 in sync, rc 1 STALE.  (0) SELF-TEST, every run, on scratch copies: a
# table that differs from what the generator writes must read STALE; a vendored file that is no longer byte-identical to
# swipl's own copy must refuse rc=2 by that reason (the predicate references and meta-predicate declarations are read
# from swipl's copy, so a vendored file that drifted would be renamed by the wrong reading); an unknown directive must
# refuse rc=2 by name (a directive is never dropped silently).  An instrument that cannot see its plants proves nothing by
# passing: the gate refuses.  Needs swipl (the generator reads every library with SWI's own reader), no build; ~2 s.
# rc=0 in sync · rc=1 stale · rc=2 refused.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="$HERE/util_gen_prolog_prelude_libs.py"
P="$HERE/../../SCRIP/src/parsers/prolog/prelude"
INC="$HERE/../../SCRIP/src/parsers/prolog/prolog_prelude_libs.inc"
refuse() { echo "⛔ REFUSED(2) [test_gate_pl_prelude_libs_in_sync]: $*"; exit 2; }
[ -f "$GEN" ] || refuse "no $GEN"
[ -d "$P" ] || refuse "no $P"
[ -f "$INC" ] || refuse "no $INC"
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the generator reads every vendored library with SWI's own reader"
cp -r "$P" "$D/drift" && cp -r "$P" "$D/dir" && cp "$INC" "$D/stale.inc" || refuse "could not copy $P"
first="$(ls "$P"/*.pl | head -1)"; b="$(basename "$first")"
printf '\n' >> "$D/stale.inc"
printf '\nplanted_by_the_sync_gate(x).\n' >> "$D/drift/$b"
printf '\n:- planted_directive(x).\n' >> "$D/dir/$b"
python3 "$GEN" --out "$D/stale.inc" --check > "$D/o1" 2>&1; r1=$?
python3 "$GEN" --dir "$D/drift" --out "$D/x.inc" > "$D/o2" 2>&1; r2=$?
python3 "$GEN" --dir "$D/dir" --out "$D/y.inc" > "$D/o3" 2>&1; r3=$?
[ "$r1" = 1 ] && grep -q STALE "$D/o1" || refuse "self-test: a table that differs from the generator's did not read STALE (rc=$r1: $(head -c 200 "$D/o1"))"
[ "$r2" = 2 ] && grep -q "differs from swipl's own" "$D/o2" || refuse "self-test: a vendored file no longer verbatim was not refused (rc=$r2: $(head -c 200 "$D/o2"))"
[ "$r3" = 2 ] && grep -q planted_directive "$D/o3" || refuse "self-test: an unknown directive was not refused by name (rc=$r3: $(head -c 200 "$D/o3"))"
python3 "$GEN" --check; rc=$?
[ "$rc" = 0 ] && echo "PASS test_gate_pl_prelude_libs_in_sync (self-test: a stale table, a drifted vendored file and an unknown directive all seen)"
exit "$rc"
