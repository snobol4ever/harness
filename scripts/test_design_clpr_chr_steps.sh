#!/usr/bin/env bash
# test_design_clpr_chr_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: clpr-chr (the cto, 2026-10-28, CEO-1996/1998;
# .github/ARCH-PROLOG-CLPR-CHR.md). The plan is corpus/tests/prolog/clpr_chr/STEPS.tsv; the witnesses are the .pl programs beside it, each
# with a .ref cut from swipl 9.0.4 (`swipl -q -t halt w.pl < /dev/null`, stdout only).
#
#   --list       print the steps and run nothing
#   --step N     grade step N: every witness in mode 3 and mode 4 (the declared -d131072k -s4096k, stdout compared exactly with the ref), then
#                the step's probe tokens: entries=... (the named rosetta-prolog entries through corpus_suite_harness.py smoke under the feature directive, which every entry carries; no progress
#                row, at most eight: the handful of CEO-1677), latest=... (results.tsv's latest reading per entry PASS in both modes, READ),
#                row=N (SUITES.tsv's rosetta-prolog today_pass at least N, READ), nolib=path (swi_tests UNGRADED.tsv does not list the path,
#                READ). Red before the step lands, green after.
#   --cut        re-cut every witness ref from swipl (the design seat's road; an HQ that changes a witness re-cuts it the same way)
#   --out DIR    where the runs go (default <root>/.scratch/clpr_chr)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> probe=<token:reading ...> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
WD="$ROOT/corpus/tests/prolog/clpr_chr"
STEPS="$WD/STEPS.tsv"
OUT="$ROOT/.scratch/clpr_chr"
RESULTS=/home/resources/progress/results.tsv
SUITES=/home/resources/progress/SUITES.tsv
UNGRADED="$ROOT/corpus/packages/prolog/swi_tests/UNGRADED.tsv"
refuse() { echo "REFUSE(2): $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
mode=""; step=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "--step takes a number"; shift 2 ;;
        --cut) mode=cut; shift ;;
        --out) OUT="${2:-}"; shift 2 ;;
        *) refuse "usage: $0 --list | --step N [--out DIR] | --cut" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N [--out DIR] | --cut"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: clpr-chr -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6' "$STEPS" | wc -l) steps (STEPS.tsv); witnesses in corpus/tests/prolog/clpr_chr (refs from swipl 9.0.4)"
    printf '%-4s %-38s %-12s %-12s %s\n' step slug executor depends witnesses
    for n in $(awk -F'\t' '!/^#/ && $1 != "step" {print $1}' "$STEPS"); do
        printf '%-4s %-38s %-12s %-12s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 4)" "$(col "$n" 6)"
    done
    exit 0
fi
if [ "$mode" = cut ]; then
    command -v swipl > /dev/null || refuse "no swipl on PATH (ORACLES.md: the SWI oracle)"
    for w in $(awk -F'\t' '!/^#/ && $1 != "step" && $6 != "-" {print $6}' "$STEPS" | tr ' ' '\n' | sort -u); do
        ( cd "$WD" && timeout -k 5 120 swipl -q -t halt "$w.pl" < /dev/null > "$WD/$w.ref" 2> /dev/null ); echo "cut $w.ref: $(wc -l < "$WD/$w.ref") lines"
    done
    exit 0
fi
[ -n "$(col "$step" 1)" ] || refuse "no step $step in $STEPS (--list names them)"
slug="$(col "$step" 2)"; probe="$(col "$step" 5)"; wits="$(col "$step" 6)"
[ -x "$SC/scrip" ] || refuse "no $SC/scrip"
mkdir -p "$OUT/step$step"
# one box-wide run slot for the step (CEO-1894)
if [ -z "${S4E_RUN_SLOT_HELD:-}" ]; then
    nslots="${S4E_RUN_SLOTS:-8}"; slotdir_="${S4E_RUN_SLOT_DIR:-/tmp/s4e-run-slots}"; mkdir -p "$slotdir_"; got=""
    while [ -z "$got" ]; do
        for i in $(seq 0 $((nslots - 1))); do exec 9>"$slotdir_/slot$i"; flock -n 9 && { got=$i; break; }; done
        [ -n "$got" ] || sleep 0.5
    done
    export S4E_RUN_SLOT_HELD=1
fi
m3p=0; m4p=0; n=0; reds=""
[ "$wits" = "-" ] && wits=""
for w in $wits; do
    ref="$WD/$w.ref"
    [ -f "$WD/$w.pl" ] && [ -f "$ref" ] || refuse "witness $w has no .pl or .ref in $WD"
    n=$((n + 1))
    for m in m3 m4; do
        d="$OUT/step$step/$w.$m"; rm -rf "$d"; mkdir -p "$d"; cp "$WD/$w.pl" "$d/$w.pl"
        if [ "$m" = m3 ]; then
            ( cd "$d" && timeout -k 5 120 "$SC/scrip" -d131072k -s4096k "$w.pl" < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
        else
            if ( cd "$d" && timeout -k 5 300 "$SC/scrip" --compile --out="$d/run.s" "$w.pl" < /dev/null > /dev/null 2> "$d/cerr" ) \
               && gcc -c "$d/run.s" -o "$d/run.o" 2> /dev/null && gcc "$d/run.o" -L"$SC/out" -lscrip_rt -lm -Wl,-rpath,"$SC/out" -o "$d/run.bin" 2> /dev/null; then
                ( cd "$d" && timeout -k 5 120 "$d/run.bin" -d131072k -s4096k < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
            else rc=no-binary; fi
        fi
        if [ "$rc" = 0 ] && diff -q "$d/out" "$ref" > /dev/null 2>&1; then [ "$m" = m3 ] && m3p=$((m3p + 1)) || m4p=$((m4p + 1)); else reds="$reds $m:$w(rc$rc)"; fi
    done
done
readings=""; pgreen=1
[ "$probe" = "-" ] && probe=""
for tok in $probe; do
    key="${tok%%=*}"; val="${tok#*=}"
    case "$key" in
        entries) es="${val//,/ }"; cnt=0; for e in $es; do cnt=$((cnt + 1)); done; [ "$cnt" -le 8 ] || refuse "step $step names $cnt entries; the handful is at most eight (CEO-1677)"
                 sm="$(cd "$ROOT" && S4E_HOME="$ROOT" timeout -k 10 1500 python3 "$HERE/corpus_suite_harness.py" smoke directive --tables packages/prolog/rosetta-prolog --entries "$es" --modes m3,m4 2>&1)"
                 printf '%s\n' "$sm" > "$OUT/step$step/smoke.log"
                 ok=0; for e in $es; do printf '%s\n' "$sm" | grep -E "^AREA_SMOKE_ENTRY .*entry=$e .*m3=PASS.*m4=PASS" > /dev/null && ok=$((ok + 1)); done
                 readings="$readings entries=$ok/$cnt"; [ "$ok" = "$cnt" ] || pgreen=0 ;;
        latest) [ -r "$RESULTS" ] || refuse "no $RESULTS"; bad="$(awk -F'\t' -v es="$val" 'BEGIN { n = split(es, a, ","); for (i = 1; i <= n; i++) { f[a[i]] = 1; o[a[i] "\tm3"] = "NONE"; o[a[i] "\tm4"] = "NONE" } }
                    NR > 1 && $6 == "rosetta-prolog" && ($8 in f) { k = $8 "\t" $9; if ($1 > ts[k]) { ts[k] = $1; o[k] = $10 } }
                    END { b = 0; for (k in o) if (o[k] != "PASS") b++; print b }' "$RESULTS")"; readings="$readings latest_not_pass=$bad"; [ "$bad" = 0 ] || pgreen=0 ;;
        row) [ -r "$SUITES" ] || refuse "no $SUITES"; tp="$(awk -F'\t' 'NR == 2 { for (i = 1; i <= NF; i++) h[$i] = i } $1 == "rosetta-prolog" { print $(h["today_pass"]) }' "$SUITES" | tail -1)"
             readings="$readings row_today_pass=${tp:-?}(need $val)"; [ -n "$tp" ] && [ "$tp" -ge "$val" ] 2>/dev/null || pgreen=0 ;;
        nolib) [ -r "$UNGRADED" ] || refuse "no $UNGRADED"; if grep -q "^$val	" "$UNGRADED"; then readings="$readings ungraded[$val]=listed"; pgreen=0; else readings="$readings ungraded[$val]=absent"; fi ;;
        *) refuse "unknown probe token $tok in step $step" ;;
    esac
done
verdict=GREEN; [ "$m3p" = "$n" ] && [ "$m4p" = "$n" ] && [ "$pgreen" = 1 ] || verdict=RED
echo "STEP $step $slug: m3=$m3p/$n m4=$m4p/$n probe=${readings# } -> $verdict${reds:+ reds:$reds}"
[ "$verdict" = GREEN ] && exit 0 || exit 1
