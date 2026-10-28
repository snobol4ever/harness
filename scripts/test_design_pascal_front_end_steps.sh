#!/usr/bin/env bash
# test_design_pascal_front_end_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: pascal-front-end (the cto, 2026-10-28, CEO-1996/1998;
# .github/ARCH-PASCAL-REDESIGN.md section 8). The plan is corpus/tests/pascal/front_end/STEPS.tsv; the witnesses are the .pas programs
# beside it, each with a .ref cut from fpc 3.2.2 (fpc -v0 in the program's own mode, the binary's stdout).
#
#   --list       print the steps and run nothing
#   --step N     grade step N: every witness in mode 3 and mode 4 (the declared -d131072k -s4096k, stdout compared exactly with the ref), then
#                the step's probe tokens: shadow=0 (scrip --dump-pas-types over the witnesses prints PTY-STATS lines with answered = agreed),
#                tables=N (the pas_*[N] arrays of src/lower/lower_pascal_tree.h at most N), entries=... (the named rosetta-pascal entries
#                through corpus_suite_harness.py smoke under the feature writeln, no progress row, at most eight: the handful of CEO-1677),
#                latest=... (results.tsv's latest reading per entry PASS in both modes, READ), row=N (SUITES.tsv's rosetta-pascal
#                today_pass at least N, READ). Red before the step lands, green after.
#   --cut        re-cut every witness ref from fpc (the design seat's road; an HQ that changes a witness re-cuts it the same way)
#   --out DIR    where the runs go (default <root>/.scratch/pascal_front_end)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> probe=<token:reading ...> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
WD="$ROOT/corpus/tests/pascal/front_end"
STEPS="$WD/STEPS.tsv"
OUT="$ROOT/.scratch/pascal_front_end"
RESULTS=/home/resources/progress/results.tsv
SUITES=/home/resources/progress/SUITES.tsv
TABLES_H="$SC/src/lower/lower_pascal_tree.h"
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
    echo "DESIGN-PLAN: pascal-front-end -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6' "$STEPS" | wc -l) steps (STEPS.tsv); witnesses in corpus/tests/pascal/front_end (refs from fpc 3.2.2)"
    printf '%-4s %-50s %-10s %-14s %s\n' step slug executor depends witnesses
    for n in $(awk -F'\t' '!/^#/ && $1 != "step" {print $1}' "$STEPS"); do
        printf '%-4s %-50s %-10s %-14s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 4)" "$(col "$n" 6)"
    done
    exit 0
fi
if [ "$mode" = cut ]; then
    command -v fpc > /dev/null || refuse "no fpc on PATH (ORACLES.md: the Free Pascal oracle)"
    T="$(mktemp -d "${TMPDIR:-/tmp}/pasfe_cut.XXXXXX")"
    for w in $(awk -F'\t' '!/^#/ && $1 != "step" && $6 != "-" {print $6}' "$STEPS" | tr ' ' '\n' | sort -u); do
        ( cd "$T" && fpc -v0 -o"$T/$w.bin" "$WD/$w.pas" > "$T/$w.cerr" 2>&1 && timeout -k 5 120 "$T/$w.bin" < /dev/null > "$WD/$w.ref" 2> /dev/null ); echo "cut $w.ref: $(wc -l < "$WD/$w.ref") lines$(grep -q 'Error' "$T/$w.cerr" && echo ' (FPC REFUSED: read the log)')"
    done
    rm -rf "$T"; exit 0
fi
[ -n "$(col "$step" 1)" ] || refuse "no step $step in $STEPS (--list names them)"
slug="$(col "$step" 2)"; probe="$(col "$step" 5)"; wits="$(col "$step" 6)"
[ -x "$SC/scrip" ] || refuse "no $SC/scrip"
mkdir -p "$OUT/step$step"
# one box-wide run slot for the step (CEO-1894)
if [ -z "${S4E_RUN_SLOT_HELD:-}" ]; then
    nslots="${S4E_RUN_SLOTS:-8}"; mkdir -p /tmp/s4e-run-slots; got=""
    for i in $(seq 0 $((nslots - 1))); do exec 9>"/tmp/s4e-run-slots/slot$i"; flock -n 9 && { got=$i; break; }; done
    [ -n "$got" ] || { exec 9>"/tmp/s4e-run-slots/slot$(( $$ % nslots ))"; flock 9; }
    export S4E_RUN_SLOT_HELD=1
fi
m3p=0; m4p=0; n=0; reds=""
[ "$wits" = "-" ] && wits=""
for w in $wits; do
    ref="$WD/$w.ref"
    [ -f "$WD/$w.pas" ] && [ -f "$ref" ] || refuse "witness $w has no .pas or .ref in $WD"
    n=$((n + 1))
    for m in m3 m4; do
        d="$OUT/step$step/$w.$m"; rm -rf "$d"; mkdir -p "$d"; cp "$WD/$w.pas" "$d/$w.pas"
        if [ "$m" = m3 ]; then
            ( cd "$d" && timeout -k 5 120 "$SC/scrip" -d131072k -s4096k "$w.pas" < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
        else
            if ( cd "$d" && timeout -k 5 300 "$SC/scrip" --compile -o "$d/run.s" "$w.pas" < /dev/null > /dev/null 2> "$d/cerr" ) \
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
        shadow) bad=0; seen=0
                for w in $wits; do d="$OUT/step$step/$w.shadow"; mkdir -p "$d"
                    ( cd "$d" && timeout -k 5 120 "$SC/scrip" --dump-pas-types --compile -o /dev/null "$WD/$w.pas" < /dev/null > "$d/out" 2> "$d/err" )
                    lines="$(grep -c '^PTY-STATS ' "$d/err")"; [ "$lines" -ge 1 ] || { bad=$((bad + 1)); continue; }
                    seen=$((seen + 1)); dis="$(awk '/^PTY-STATS /{ for (i = 1; i <= NF; i++) { split($i, kv, "="); if (kv[1] == "answered") a = kv[2]; if (kv[1] == "agreed") g = kv[2] } d += a - g } END { print d + 0 }' "$d/err")"
                    [ "$dis" = 0 ] || bad=$((bad + 1)); done
                readings="$readings shadow_bad=$bad/$n(census_lines_on=$seen)"; [ "$bad" = 0 ] && [ "$seen" = "$n" ] || pgreen=0 ;;
        tables) [ -f "$TABLES_H" ] || refuse "no $TABLES_H"; cnt="$(grep -o 'pas_[a-z_]*\[[0-9A-Z_]*\]' "$TABLES_H" | sort -u | wc -l)"; readings="$readings tables=$cnt(at_most $val)"; [ "$cnt" -le "$val" ] || pgreen=0 ;;
        entries) es="${val//,/ }"; cnt=0; for e in $es; do cnt=$((cnt + 1)); done; [ "$cnt" -le 8 ] || refuse "step $step names $cnt entries; the handful is at most eight (CEO-1677)"
                 sm="$(cd "$ROOT" && S4E_HOME="$ROOT" timeout -k 10 1500 python3 "$HERE/corpus_suite_harness.py" smoke writeln --tables packages/pascal/rosetta-pascal --entries "$es" --modes m3,m4 2>&1)"
                 printf '%s\n' "$sm" > "$OUT/step$step/smoke.log"
                 ok=0; for e in $es; do printf '%s\n' "$sm" | grep -E "^AREA_SMOKE_ENTRY .*entry=$e .*m3=PASS.*m4=PASS" > /dev/null && ok=$((ok + 1)); done
                 readings="$readings entries=$ok/$cnt"; [ "$ok" = "$cnt" ] || pgreen=0 ;;
        latest) [ -r "$RESULTS" ] || refuse "no $RESULTS"; bad="$(awk -F'\t' -v es="$val" 'BEGIN { n = split(es, a, ","); for (i = 1; i <= n; i++) { f[a[i]] = 1; o[a[i] "\tm3"] = "NONE"; o[a[i] "\tm4"] = "NONE" } }
                    NR > 1 && $6 == "rosetta-pascal" && ($8 in f) { k = $8 "\t" $9; if ($1 > ts[k]) { ts[k] = $1; o[k] = $10 } }
                    END { b = 0; for (k in o) if (o[k] != "PASS") b++; print b }' "$RESULTS")"; readings="$readings latest_not_pass=$bad"; [ "$bad" = 0 ] || pgreen=0 ;;
        row) [ -r "$SUITES" ] || refuse "no $SUITES"; tp="$(awk -F'\t' 'NR == 2 { for (i = 1; i <= NF; i++) h[$i] = i } $1 == "rosetta-pascal" { print $(h["today_pass"]) }' "$SUITES" | tail -1)"
             readings="$readings row_today_pass=${tp:-?}(need $val)"; [ -n "$tp" ] && [ "$tp" -ge "$val" ] 2>/dev/null || pgreen=0 ;;
        *) refuse "unknown probe token $tok in step $step" ;;
    esac
done
verdict=GREEN; [ "$m3p" = "$n" ] && [ "$m4p" = "$n" ] && [ "$pgreen" = 1 ] || verdict=RED
echo "STEP $step $slug: m3=$m3p/$n m4=$m4p/$n probe=${readings# } -> $verdict${reds:+ reds:$reds}"
[ "$verdict" = GREEN ] && exit 0 || exit 1
