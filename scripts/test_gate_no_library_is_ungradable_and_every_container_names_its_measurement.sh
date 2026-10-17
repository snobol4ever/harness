#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: the Arizona and Jcon runners invoked on scratch packages as instrument fixtures, not boards (CEO-1272, CEO-523)"
# test_gate_no_library_is_ungradable_and_every_container_names_its_measurement.sh -- THE CONTAINER_OR_LIBRARY SPLIT, HELD (ceo CEO-1272,
# 2026-09-25, on the coo's 886-row ask; CEO-700, CEO-1245, CEO-1269; coo, row instruments-container-or-library-splits-into-a-library-
# owed-its-driver-and-a-container-that-is-not-a-program-and-ipl-publishes-its-shipped-population). The retired UNGRADABLE class
# conflated two facts. A LIBRARY (callable code, no entry point) is a program owed its driver: UNGRADED NEEDS_DRIVER, in the
# denominator. A CONTAINER (not a compilation unit on its own) leaves shipped, named in CONTAINERS.tsv with the measurement that
# makes it one. util_container_or_library.py measures; lib_inventory.sh re-derives every CONTAINERS.tsv row before it prints.
#
# FIXTURE ARMS (a scratch Icon package, inventory_line called directly -- no board): (1) a planted library measures LIBRARY and,
# split, reads NEEDS_DRIVER in the denominator; (2) a planted include fragment measures INCLUDED_BY its includer and, split, leaves
# shipped with containers=1 and the includer named; (3) a class-less row refuses; (4) a measurement that does not re-derive
# refuses; (5) a container also declared UNGRADABLE refuses (two answers); (6) a library written as a container refuses; (7) the
# retired class itself refuses. MEASUREMENT ARMS: (8) Prolog -- a loading tester is SCAFFOLDING, a fact file a test names is
# OPENED_BY, a module of rules is a LIBRARY; (8b) Prolog LOADED_BY (ceo CEO-1621) -- a module a program's use_module loads is
# LOADED_BY that program while an include stays INCLUDED_BY, a CONTAINERS row naming the loader verifies green, and one naming a
# file that does not load it verifies RED (the kind fails once and passes once); (9) SNOBOL4 -- an -INCLUDEd file is INCLUDED_BY, two top-level ENDs are MULTI_PROGRAM,
# DEFINEs with no END are a LIBRARY. RUNNER ARMS: (10) Jcon and (11) Arizona on a scratch package holding one program and the
# fragment it $includes -- shipped=1, graded=1, both modes pass, containers=1 on the inventory line. CORPUS ARMS: (12) no sidecar
# under corpus/ carries CONTAINER_OR_LIBRARY in its class column; (13) every corpus CONTAINERS.tsv re-derives; (14) IPL publishes
# the inventory's shipped count, never the graded subset (CEO-1245).
# ⛔ FAILED ONCE (measured at the landing, recorded in its commit): on bbfc21362's parent lib_inventory.sh, arms 2-7 read red.
# ⛔ (8b) FAILED ONCE (hq_pascal 2026-10-10, CEO-1621): on the parent instrument the use_module-loaded module measured LIBRARY
# NEEDS_DRIVER and a LOADED_BY row was refused as an unknown KIND.
# EXIT 0 every arm holds; 1 an arm is red; 2 REFUSED (an oracle, the fixture or the corpus could not be read -- nothing measured).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
CORPUS_REAL="${S4E_CORPUS:-$(cd "$ROOT/.." && pwd)/corpus}"
U="$HERE/util_container_or_library.py"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSED(2): lib_oracle_flags.sh unloadable"; exit 2; }
ICONT="$(icont_bin 2>/dev/null)"; ICONX="$(iconx_bin 2>/dev/null)"
for b in "$ICONT" "$ICONX"; do [ -n "$b" ] && [ -x "$b" ] || { echo "⛔ REFUSED(2): icont/iconx missing ('$ICONT' '$ICONX') -- a runner fixture's ref cannot be cut"; exit 2; }; done
[ -f "$U" ] && [ -d "$CORPUS_REAL/packages" ] || { echo "⛔ REFUSED(2): $U or $CORPUS_REAL/packages missing"; exit 2; }
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"; mkdir -p "$SCRATCH" || { echo "⛔ REFUSED(2): cannot create $SCRATCH"; exit 2; }
T="$(mktemp -d "$SCRATCH/gate_contlib_XXXXXX")" || { echo "⛔ REFUSED(2): mktemp failed"; exit 2; }; trap 'rm -rf "$T"' EXIT
export S4E_SCORE_NO_WRITE="gate fixture ${0##*/}: a scratch package, never a board"
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
inv() { ( . "$HERE/lib_inventory.sh"; INV_PACKAGE=fx; INV_DIR="$1"; INV_EXT="$2"; inventory_line "$3" 0 ) 2>&1; }
# bf <file> <BOARD> field=value... -- every field on the first <BOARD> line, each matched on its own: a board line read by
# identity, never by position (util_board_field_matcher_census.py, CEO-839), so a field a runner inserts cannot red this gate.
bf() { local f="$1" b="$2" l kv; shift 2; l="$(grep -m1 "^$b " "$f")" || return 1; for kv in "$@"; do grep -qE "(^| )$kv( |\$)" <<<"$l" || return 1; done; }
hdr='# fixture\n# name<TAB>CLASS<TAB>reason\n'

# ---- the Icon fixture: prog $includes frag and links lib; frag and lib start life as CONTAINER_OR_LIBRARY rows, as the corpus did
P="$T/pkg"; mkdir -p "$P"
printf '$include "frag.icn"\nlink lib\nprocedure main();\n   write(frag(), lib());\nend\n' > "$P/prog.icn"
printf 'procedure frag();\n   return "f";\nend\n' > "$P/frag.icn"
printf 'procedure lib();\n   return "l";\nend\n' > "$P/lib.icn"
printf 'fl\n' > "$P/prog.ref"
printf "$hdr"'frag.icn\tCONTAINER_OR_LIBRARY\tfixture row\nlib.icn\tCONTAINER_OR_LIBRARY\tfixture row\n' > "$P/UNGRADABLE.tsv"
m_lib="$(python3 "$U" classify "$P" lib.icn)"; m_frag="$(python3 "$U" classify "$P" frag.icn)"
python3 "$U" split "$P" --apply > "$T/split.out" 2>&1; src=$?
out1="$(inv "$P" .icn 1)"
case "$m_lib" in *$'\tLIBRARY\tNEEDS_DRIVER\t'*) grep -qP '^lib\.icn\tNEEDS_DRIVER\t' "$P/UNGRADED.tsv" 2>/dev/null && grep -q 'shipped=2 graded=1 ungraded=1 ungradable=0 ' <<<"$out1" \
  && ck ok "(1) a planted library measures LIBRARY, splits to UNGRADED NEEDS_DRIVER, and counts in the denominator (shipped=2, ungraded=1)" \
  || ck no "(1) the planted library: split rc=$src, inventory: $(printf '%s' "$out1" | tail -1 | cut -c1-160)" ;;
  *) ck no "(1) the planted library measured: $m_lib" ;; esac
case "$m_frag" in *$'\tCONTAINER\tINCLUDED_BY\tprog.icn') grep -qP '^frag\.icn\tINCLUDED_BY\tprog\.icn ' "$P/CONTAINERS.tsv" 2>/dev/null && grep -q ' containers=1$' <<<"$out1" \
  && ck ok "(2) a planted include fragment measures INCLUDED_BY prog.icn and leaves shipped with its includer named (containers=1)" \
  || ck no "(2) the planted fragment: $(head -c 300 "$P/CONTAINERS.tsv" 2>/dev/null | tail -1) :: $(printf '%s' "$out1" | tail -1 | cut -c1-160)" ;;
  *) ck no "(2) the planted fragment measured: $m_frag" ;; esac
refuses() { local d="$1" want="$2" o; o="$(inv "$d" .icn 1)"; ! grep -q '^PACKAGE_INVENTORY' <<<"$o" && grep -q "$want" <<<"$o"; }
mut() { rm -rf "$T/m"; cp -a "$P" "$T/m"; }
mut; printf 'frag.icn\t\tno kind given\n' > "$T/m/CONTAINERS.tsv.x"; { grep -v '^frag' "$T/m/CONTAINERS.tsv"; cat "$T/m/CONTAINERS.tsv.x"; } > "$T/m/c" && mv "$T/m/c" "$T/m/CONTAINERS.tsv"
refuses "$T/m" 'class-less or unknown\|expected name<TAB>KIND' && ck ok "(3) a class-less container row refuses the inventory" || ck no "(3) a class-less row was accepted: $(inv "$T/m" .icn 1 | tail -1 | cut -c1-160)"
mut; sed -i 's/^frag\.icn\tINCLUDED_BY\tprog\.icn/frag.icn\tINCLUDED_BY\tlib.icn/' "$T/m/CONTAINERS.tsv"
refuses "$T/m" 'does not re-derive' && ck ok "(4) a container whose includer does not include it refuses (the measurement does not re-derive)" || ck no "(4) a false includer was accepted: $(inv "$T/m" .icn 1 | tail -1 | cut -c1-160)"
mut; printf 'frag.icn\tORACLE_REFUSES\tthe oracle refuses it (fixture)\n' >> "$T/m/UNGRADABLE.tsv"
refuses "$T/m" 'two answers' && ck ok "(5) a container also declared UNGRADABLE refuses -- two answers for one file" || ck no "(5) a doubly-declared file was accepted: $(inv "$T/m" .icn 1 | tail -1 | cut -c1-160)"
mut; grep -v '^lib\.icn' "$T/m/UNGRADED.tsv" > "$T/m/u" && mv "$T/m/u" "$T/m/UNGRADED.tsv"; printf 'lib.icn\tNO_DEFINITION\tdeclared a container (fixture)\n' >> "$T/m/CONTAINERS.tsv"
refuses "$T/m" 'measures LIBRARY' && ck ok "(6) a library written as a container refuses -- it measures LIBRARY, so it stays in the denominator" || ck no "(6) a library passed as a container: $(inv "$T/m" .icn 1 | tail -1 | cut -c1-160)"
mut; printf 'lib.icn\tCONTAINER_OR_LIBRARY\tthe retired class (fixture)\n' >> "$T/m/UNGRADABLE.tsv"; grep -v '^lib\.icn' "$T/m/UNGRADED.tsv" > "$T/m/u" && mv "$T/m/u" "$T/m/UNGRADED.tsv"
refuses "$T/m" "not a UNGRADABLE class" && ck ok "(7) the retired class CONTAINER_OR_LIBRARY is refused by the closed vocabulary" || ck no "(7) the retired class was accepted: $(inv "$T/m" .icn 1 | tail -1 | cut -c1-160)"

# ---- (8) Prolog and (9) SNOBOL4 measurements
Q="$T/pl"; mkdir -p "$Q"
printf ':- initialization((consult(tests), run)).\nhelper(1).\n' > "$Q/tester.pl"
printf 't :- open(%s, read, S), read(S, X), close(S), X == a(1).\n' "'data.pl'" > "$Q/tests.pl"
printf 'a(1).\na(2).\n' > "$Q/data.pl"
printf ':- module(m, [p/1]).\np(X) :- X > 0.\n' > "$Q/m.pl"
r8="$(python3 "$U" classify "$Q" tester.pl data.pl m.pl | cut -f1-3 | tr '\t\n' ' |')"
[ "$r8" = "tester.pl CONTAINER SCAFFOLDING|data.pl CONTAINER OPENED_BY|m.pl LIBRARY NEEDS_DRIVER|" ] \
  && ck ok "(8) Prolog: a loading tester is SCAFFOLDING, a fact file a test opens is OPENED_BY, a module of rules is a LIBRARY" || ck no "(8) Prolog measured: $r8"
L="$T/plb"; mkdir -p "$L"
printf ':- use_module(mlib).\n:- include(%s).\n:- initialization(main).\nmain :- q(3), r(1).\n' "'inc.pl'" > "$L/prog.pl"
printf ':- module(mlib, [q/1]).\nq(X) :- X > 0.\n' > "$L/mlib.pl"
printf 'r(X) :- X > 0.\n' > "$L/inc.pl"
printf 'other :- true.\n:- initialization(other).\n' > "$L/other.pl"
r8b="$(python3 "$U" classify "$L" mlib.pl inc.pl | cut -f1-4 | tr '\t\n' ' |')"
printf 'mlib.pl\tLOADED_BY\tprog.pl -- its use_module loads this module (fixture)\ninc.pl\tINCLUDED_BY\tprog.pl -- its include splices this file (fixture)\n' > "$L/CONTAINERS.tsv"
python3 "$U" verify "$L" > "$L/v1" 2>&1; v1=$?
printf 'mlib.pl\tLOADED_BY\tother.pl -- a file that does not load it (fixture)\n' > "$L/CONTAINERS.tsv"
python3 "$U" verify "$L" > "$L/v2" 2>&1; v2=$?
[ "$r8b" = "mlib.pl CONTAINER LOADED_BY prog.pl|inc.pl CONTAINER INCLUDED_BY prog.pl|" ] && [ "$v1" = 0 ] && [ "$v2" = 1 ] && grep -q 'LOADED_BY other.pl does not re-derive' "$L/v2" \
  && ck ok "(8b) Prolog: a module a program's use_module loads is LOADED_BY it, an include stays INCLUDED_BY; the true loader verifies, a wrong one is RED" \
  || ck no "(8b) Prolog LOADED_BY measured: [$r8b] verify true-loader rc=$v1, wrong-loader rc=$v2: $(tail -1 "$L/v2" | cut -c1-120)"
S="$T/sno"; mkdir -p "$S"
printf -- "-INCLUDE 'inc.sno'\n\tOUTPUT = F(1)\nEND\n" > "$S/main.sno"
printf "\tDEFINE('F(X)')\t:(FE)\nF\tF = X\t:(RETURN)\nFE\n" > "$S/inc.sno"
printf "\tOUTPUT = 'one'\nEND\n\tOUTPUT = 'two'\nEND\n" > "$S/two.sno"
printf "\tDEFINE('G(X)')\t:(GE)\nG\tG = X\t:(RETURN)\nGE\n" > "$S/libonly.sno"
r9="$(python3 "$U" classify "$S" inc.sno two.sno libonly.sno | cut -f1-3 | tr '\t\n' ' |')"
[ "$r9" = "inc.sno CONTAINER INCLUDED_BY|two.sno CONTAINER MULTI_PROGRAM|libonly.sno LIBRARY NEEDS_DRIVER|" ] \
  && ck ok "(9) SNOBOL4: an -INCLUDEd file is INCLUDED_BY, two top-level ENDs are MULTI_PROGRAM, DEFINEs with no END are a LIBRARY" || ck no "(9) SNOBOL4 measured: $r9"

# ---- (10) Jcon and (11) Arizona: the runner's own census drops the container
R="$T/rf"; mkdir -p "$R/cut"
printf '$include "frag.icn"\nprocedure main();\n   write(frag());\nend\n' > "$R/prog.icn"; printf 'procedure frag();\n   return "spliced";\nend\n' > "$R/frag.icn"
cp "$R"/*.icn "$R/cut/" && ( cd "$R/cut" && "$ICONT" -s -o p prog.icn && "$ICONX" ./p ) > "$R/prog.ref" 2>&1 </dev/null
grep -qx spliced "$R/prog.ref" || { echo "⛔ REFUSED(2): icont/iconx did not build the include fixture -- $(tr '\n' '|' < "$R/prog.ref")"; exit 2; }
printf "$hdr" > "$R/UNGRADED.tsv"; printf "$hdr" > "$R/UNGRADABLE.tsv"
printf 'frag.icn\tINCLUDED_BY\tprog.icn -- its $include splices it (gate fixture)\n' > "$R/CONTAINERS.tsv"
OJ="$T/oj"; mkdir -p "$OJ" && cp "$R"/prog.icn "$R"/frag.icn "$R"/prog.ref "$R"/*.tsv "$OJ/"
S4E_PROGRESS_DB="$T/oj.tsv" timeout -k 5 600 bash "$HERE/test_icon_jcon_suite.sh" --corpus "$OJ" > "$T/oj.out" 2>&1
bf "$T/oj.out" JCON_SUITE_BOARD shipped=1 graded=1 gap=0 m3_pass=1 m4_pass=1 && bf "$T/oj.out" PACKAGE_INVENTORY package=jcon shipped=1 containers=1 \
  && ck ok "(10) jcon: the \$include'd fragment is out of the runner's census and the inventory's alike (shipped=1, containers=1, both modes pass)" \
  || ck no "(10) jcon: $(grep -m1 '^JCON_SUITE_BOARD' "$T/oj.out" | cut -c1-110) :: $(grep -m1 '^PACKAGE_INVENTORY\|REFUSES' "$T/oj.out" | cut -c1-140)"
OZ="$T/oz/corpus/packages/icon/arizona_tests"; mkdir -p "$OZ/general" "$OZ/special" && cp "$R"/prog.icn "$R"/frag.icn "$R"/prog.ref "$OZ/general/" && cp "$R"/UNGRADED.tsv "$R"/UNGRADABLE.tsv "$OZ/"
sed 's/^frag\.icn/general\/frag.icn/; s/\tprog\.icn/\tgeneral\/prog.icn/' "$R/CONTAINERS.tsv" > "$OZ/CONTAINERS.tsv"
S4E_HOME="$T/oz" S4E_PROGRESS_DB="$T/oz.tsv" timeout -k 5 600 bash "$HERE/test_icon_arizona_suite.sh" > "$T/oz.out" 2>&1
bf "$T/oz.out" ARIZONA_SUITE_BOARD shipped=1 graded=1 gap=0 m3_pass=1 m4_pass=1 && bf "$T/oz.out" PACKAGE_INVENTORY package=arizona shipped=1 containers=1 \
  && ck ok "(11) arizona: the \$include'd fragment is out of the runner's census and the inventory's alike (shipped=1, containers=1, both modes pass)" \
  || ck no "(11) arizona: $(grep -m1 '^ARIZONA_SUITE_BOARD' "$T/oz.out" | cut -c1-110) :: $(grep -m1 '^PACKAGE_INVENTORY\|REFUSES' "$T/oz.out" | cut -c1-140)"

# ---- (12)-(14) the real corpus and the IPL runner
retired="$(find "$CORPUS_REAL/packages" "$CORPUS_REAL/tests" "$CORPUS_REAL/benchmarks" -name '*.tsv' -print0 2>/dev/null | xargs -0 awk -F'\t' '$1 !~ /^#/ && $2 == "CONTAINER_OR_LIBRARY" {print FILENAME ":" FNR}' | sed "s#$CORPUS_REAL/##")"
[ -z "$retired" ] && ck ok "(12) no sidecar under corpus/ carries the retired class CONTAINER_OR_LIBRARY" || ck no "(12) the retired class is still used: $(echo $retired | cut -c1-300)"
nc=0; nr=0; bad=""
while IFS= read -r c; do nc=$((nc+1)); o="$(python3 "$U" verify "$(dirname "$c")" 2>&1)"; rc=$?
  n="$(sed -n 's/.*: \([0-9]*\) row(s).*/\1/p' <<<"$o")"; nr=$((nr + ${n:-0})); [ "$rc" = 0 ] || bad="$bad ${c#"$CORPUS_REAL"/}(rc=$rc: $(grep -m1 RED <<<"$o" | cut -c1-120))"
done < <(find "$CORPUS_REAL/packages" -name CONTAINERS.tsv | sort)
[ "$nc" -gt 0 ] || { echo "⛔ REFUSED(2): no CONTAINERS.tsv under $CORPUS_REAL/packages -- the split this gate holds is absent"; exit 2; }
[ -z "$bad" ] && ck ok "(13) every corpus CONTAINERS.tsv re-derives its measurement ($nr rows over $nc packages)" || ck no "(13) a corpus container does not re-derive:$bad"
grep -qF -- '--suite-total "$IPL_SHIPPED"' "$HERE/test_icon_ipl_suite.sh" && ! grep -qF -- '--suite-total "$RUN_GRADED"' "$HERE/test_icon_ipl_suite.sh" \
  && grep -qE '^IPL_SHIPPED=.*INV_LINE.* shipped=' "$HERE/test_icon_ipl_suite.sh" \
  && ck ok "(14) IPL publishes the inventory's shipped count as its total, never the graded subset (CEO-1245)" || ck no "(14) test_icon_ipl_suite.sh does not publish the inventory's shipped population"

echo "population: $checks arm(s) -- 7 on a scratch Icon package, 2 measurement fixtures (Prolog, SNOBOL4), 2 runner fixtures (Jcon, Arizona), 3 over the real corpus ($nr container rows in $nc packages)"
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [no_library_is_ungradable_and_every_container_names_its_measurement]: $checks of $checks arms hold"; exit 0; fi
echo "⛔ GATE FAIL(1) [no_library_is_ungradable_and_every_container_names_its_measurement]: $fails of $checks arms red"; exit 1
