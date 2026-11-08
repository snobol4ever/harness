#!/usr/bin/env bash
"$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate test_design_unicon_steps || exit 2
# test_design_unicon_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: unicon (the cto, 2026-10-31, R-2072; .github/ARCH-UNICON.md). The plan is
# corpus/tests/icon/unicon/STEPS.tsv; the witnesses are the uni_*.icn beside it, each with a .ref cut from unicon 13.3 (/home/resources/unicon/bin/unicon,
# the Unicon oracle through unicon_bin()), except the plain-Icon fallback witness whose ref Arizona icont/iconx cut because unicon refuses that program;
# uni_pkg_shapes.icn is the package file the import witness loads from the folder, not a witness of its own.
#
#   --list         print the steps and run nothing
#   --step N       grade step N: every witness of the step in each mode S4E_MODES names (a comma list of m3 and m4, default m3; CIO-7): mode 3
#                  (./scrip w.icn), mode 4 (--compile, gcc, run), from the witness folder, byte-equal to its .ref with rc 0; an unnamed mode prints
#                  skip; probe 'witnesses' is green when every witness passes every named mode; probe 'markers' adds
#                  --dump-ast rc 0 on every class witness of the folder (the eight words lex and the class, package and import headers parse)
#   --with-smoke   on the finish step (probe 'finish') also run test_smoke_icon.sh, the lander smoke of R-1928
#   --out DIR      where the .s, binaries and logs go (default /tmp/s4e-design-unicon: never under the root, Lon 2026-10-29/31)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> probe=<reading> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure (no ./scrip,
# no witness, no ref). It grades no corpus population: a witness folder is not a suite (R-1342); UniTests is the package suite hq_icon's row grades.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
WD="$ROOT/corpus/tests/icon/unicon"
STEPS="$WD/STEPS.tsv"
OUT="/tmp/s4e-design-unicon"
refuse() { echo "REFUSE(2): $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
mode=""; step=""; smoke=0
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "--step takes a number"; shift 2 ;;
        --with-smoke) smoke=1; shift ;;
        --out) OUT="${2:-}"; shift 2 ;;
        *) refuse "usage: $0 --list | --step N [--with-smoke] [--out DIR]" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N [--with-smoke] [--out DIR]"
do3=0; do4=0; nm=0
for _m in $(printf '%s' "${S4E_MODES:-m3}" | tr ',' ' '); do
    case "$_m" in m3) do3=1;; m4) do4=1;; *) refuse "S4E_MODES=${S4E_MODES:-} names $_m: only m3 and m4 (CIO-7)";; esac
done
nm=$((do3 + do4)); [ "$nm" -gt 0 ] || refuse "S4E_MODES=${S4E_MODES:-} names no mode"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: unicon -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF > 1' "$STEPS" | wc -l) steps (STEPS.tsv); witnesses in $WD"
    printf '%-4s %-24s %-8s %-10s %s\n' step slug executor probe witnesses
    for n in $(awk -F'\t' '!/^#/ && $1 != "step" && NF > 1 {print $1}' "$STEPS"); do
        printf '%-4s %-24s %-8s %-10s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 4)" "$(col "$n" 5)"
    done
    exit 0
fi
[ -n "$(col "$step" 1)" ] || refuse "no step $step in $STEPS (--list names them)"
slug="$(col "$step" 2)"; probe="$(col "$step" 4)"; wits="$(col "$step" 5)"
[ -x "$SC/scrip" ] || refuse "no $SC/scrip"
[ -n "$wits" ] || refuse "step $step names no witnesses"
mkdir -p "$OUT/step$step"
if [ -z "${S4E_RUN_SLOT_HELD:-}" ]; then
    . "$HERE/lib_slots.sh"; s4e_slot_hold run || true   # the one rule (lib_slots.sh): a seat file, then a pool slot; the grader's two slots reserved
fi
m3p=0; m4p=0; n=0; reds=""
for w in $wits; do
    n=$((n + 1)); src="$WD/$w.icn"; ref="$WD/$w.ref"; o="$OUT/step$step/$w"
    [ -f "$src" ] && [ -f "$ref" ] || refuse "witness $w has no .icn or .ref in $WD"
    if [ "$do3" = 1 ]; then
    ( cd "$WD" && timeout -k 5 60 "$SC/scrip" "$w.icn" < /dev/null > "$o.m3.out" 2> "$o.m3.err" ); rc=$?
    if [ "$rc" = 0 ] && cmp -s "$o.m3.out" "$ref"; then m3p=$((m3p + 1)); else reds="$reds m3:$w(rc$rc)"; fi
    fi
    if [ "$do4" = 1 ]; then
    if ( cd "$WD" && timeout -k 5 120 "$SC/scrip" --compile --out="$o.s" "$w.icn" < /dev/null > /dev/null 2> "$o.m4c.err" ) \
       && gcc -c "$o.s" -o "$o.o" 2> /dev/null && gcc "$o.o" -L"$SC/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$SC/out" -o "$o.bin" 2> /dev/null; then
        ( cd "$WD" && timeout -k 5 60 "$o.bin" < /dev/null > "$o.m4.out" 2> "$o.m4.err" ); rc=$?
        if [ "$rc" = 0 ] && cmp -s "$o.m4.out" "$ref"; then m4p=$((m4p + 1)); else reds="$reds m4:$w(rc$rc)"; fi
    else reds="$reds m4:$w(no-build)"; fi
    fi
done
pv="witnesses=$((m3p + m4p))/$((nm * n))"; pr=RED
{ [ "$do3" = 0 ] || [ "$m3p" = "$n" ]; } && { [ "$do4" = 0 ] || [ "$m4p" = "$n" ]; } && pr=GREEN
f3="m3=$m3p/$n"; [ "$do3" = 1 ] || f3="m3=skip"; f4="m4=$m4p/$n"; [ "$do4" = 1 ] || f4="m4=skip"
if [ "$probe" = markers ]; then
    pa=0; na=0
    for f in "$WD"/uni_*.icn; do
        grep -qE '^[[:space:]]*(class|package|import)[[:space:]]' "$f" || continue
        na=$((na + 1)); b="$(basename "$f" .icn)"
        if ( cd "$WD" && timeout -k 5 60 "$SC/scrip" --dump-ast "$b.icn" < /dev/null > "$OUT/step$step/$b.ast" 2> "$OUT/step$step/$b.ast.err" ); then pa=$((pa + 1)); else reds="$reds ast:$b"; fi
    done
    pv="$pv marker-parses=$pa/$na"; [ "$pa" = "$na" ] || pr=RED
fi
if [ "$probe" = finish ] && [ "$smoke" = 1 ]; then
    if S4E_ONE_RUNNER_OVERRIDE="R-1928 lander smoke, design unicon step $step" bash "$HERE/test_smoke_icon.sh" > "$OUT/step$step/smoke_icon.log" 2>&1; then pv="$pv smoke=green"; else pv="$pv smoke=RED"; pr=RED; fi
fi
echo "STEP $step $slug: $f3 $f4 probe=$pv -> $pr${reds:+ (reds:$reds)}"
[ "$pr" = GREEN ]
