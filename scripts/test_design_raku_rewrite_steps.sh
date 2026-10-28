#!/usr/bin/env bash
# test_design_raku_rewrite_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: raku-rewrite (the cto, 2026-10-28, CEO-1996/1998;
# .github/ARCH-RAKU-REWRITE.md). The plan is corpus/tests/raku/rewrite/STEPS.tsv; the witnesses are the .raku programs beside it, each
# with a .ref cut from Rakudo (rakudo_bin of lib_oracle_flags.sh: rakudo-local 2026.05).
#
#   --list       print the steps and run nothing
#   --step N     grade step N: every witness in mode 3 and mode 4 (the declared -d131072k -s4096k, stdout compared exactly with the ref), then
#                the step's probe tokens, every one a READ of a stored measurement (the coo's loop measures; a seat runs no board, CEO-1671):
#                  chapter=PREFIX:N   the roast files whose path starts with PREFIX (a comma list is a union) that read PASS in BOTH modes in
#                                     the latest results.tsv readings, at least N
#                  reject=smx:N       the roast files whose latest mode-3 note is the emitter's [SMX] refusal, at most N
#                  row=KEY:N          SUITES.tsv today_pass of suite KEY at least N (roast, raku-demos)
#                  census=SYMBOL:N    occurrences of SYMBOL under SCRIP/src (grep -rc), at most N
#                  smoke              test_smoke_raku.sh green
#                Red before the step lands, green after.
#   --cut        re-cut every witness ref from Rakudo (the design seat's road; an HQ that changes a witness re-cuts it the same way)
#   --out DIR    where the runs go (default <root>/.scratch/raku_rewrite)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> probe=<token:reading ...> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
WD="$ROOT/corpus/tests/raku/rewrite"
STEPS="$WD/STEPS.tsv"
OUT="$ROOT/.scratch/raku_rewrite"
SUITES=/home/resources/progress/SUITES.tsv
RESULTS=/home/resources/progress/results.tsv
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
    echo "DESIGN-PLAN: raku-rewrite -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6' "$STEPS" | wc -l) steps (STEPS.tsv); witnesses in corpus/tests/raku/rewrite (refs from Rakudo 2026.05)"
    printf '%-4s %-46s %-9s %-10s %s\n' step slug executor depends witnesses
    for n in $(awk -F'\t' '!/^#/ && $1 != "step" {print $1}' "$STEPS"); do
        printf '%-4s %-46s %-9s %-10s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 4)" "$(col "$n" 6)"
    done
    exit 0
fi
RAKU="$(. "$HERE/lib_oracle_flags.sh" && rakudo_bin)" || refuse "no rakudo (lib_oracle_flags.sh rakudo_bin)"
if [ "$mode" = cut ]; then
    for w in $(awk -F'\t' '!/^#/ && $1 != "step" && $6 != "-" {print $6}' "$STEPS" | tr ' ' '\n' | sort -u); do
        T="$(mktemp -d "${TMPDIR:-/tmp}/rkrw_cut.XXXXXX")"; cp "$WD/$w.raku" "$T/"
        ( cd "$T" && timeout -k 5 300 "$RAKU" "$w.raku" < /dev/null > "$WD/$w.ref" 2> "$T/err" ); echo "cut $w.ref: $(wc -l < "$WD/$w.ref") lines$(grep -q . "$T/err" && echo " (RAKUDO COMPLAINED: $(head -c 100 "$T/err" | tr '\n' ' '))")"
        rm -rf "$T"
    done
    exit 0
fi
[ -n "$(col "$step" 1)" ] || refuse "no step $step in $STEPS (--list names them)"
slug="$(col "$step" 2)"; probe="$(col "$step" 5)"; wits="$(col "$step" 6)"
[ -x "$SC/scrip" ] || refuse "no $SC/scrip"
mkdir -p "$OUT/step$step"
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
    [ -f "$WD/$w.raku" ] && [ -f "$ref" ] || refuse "witness $w has no .raku or .ref in $WD"
    n=$((n + 1))
    for m in m3 m4; do
        d="$OUT/step$step/$w.$m"; rm -rf "$d"; mkdir -p "$d"; cp "$WD/$w.raku" "$d/$w.raku"
        if [ "$m" = m3 ]; then
            ( cd "$d" && timeout -k 5 120 "$SC/scrip" -d131072k -s4096k "$w.raku" < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
        else
            if ( cd "$d" && timeout -k 5 300 "$SC/scrip" --compile -o "$d/run.s" "$w.raku" < /dev/null > /dev/null 2> "$d/cerr" ) \
               && gcc -c "$d/run.s" -o "$d/run.o" 2> /dev/null && gcc "$d/run.o" -L"$SC/out" -lscrip_rt -lm -Wl,-rpath,"$SC/out" -o "$d/run.bin" 2> /dev/null; then
                ( cd "$d" && timeout -k 5 120 "$d/run.bin" -d131072k -s4096k < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
            else rc=no-binary; fi
        fi
        if [ "$rc" = 0 ] && diff -q "$d/out" "$ref" > /dev/null 2>&1; then [ "$m" = m3 ] && m3p=$((m3p + 1)) || m4p=$((m4p + 1)); else reds="$reds $m:$w(rc$rc)"; fi
    done
done
latest_roast() { # prints program<TAB>m3outcome<TAB>m4outcome<TAB>m3note for every roast program's latest reading per mode
    [ -r "$RESULTS" ] || refuse "no $RESULTS"
    awk -F'\t' 'NR > 1 && $6 == "roast" { k = $8 "\t" $9; if (!(k in t) || $1 > t[k]) { t[k] = $1; o[k] = $10; nt[k] = $12 } }
        END { for (k in t) { split(k, a, "\t"); p[a[1]] = 1; r[k] = o[k] }
              for (q in p) printf "%s\t%s\t%s\t%s\n", q, r[q "\tm3"], r[q "\tm4"], nt[q "\tm3"] }' "$RESULTS"
}
readings=""; pgreen=1
[ "$probe" = "-" ] && probe=""
for tok in $probe; do
    key="${tok%%=*}"; val="${tok#*=}"; arg="${val%%:*}"; lim="${val##*:}"
    case "$key" in
        chapter) c="$(latest_roast | awk -F'\t' -v pre="$arg" 'BEGIN { n = split(pre, ps, ",") } $2 == "PASS" && $3 == "PASS" { for (i = 1; i <= n; i++) if (index($1, ps[i]) == 1) { c++; break } } END { print c + 0 }')"
                 readings="$readings chapter[$arg]=$c(at_least $lim)"; [ "$c" -ge "$lim" ] || pgreen=0 ;;
        reject) c="$(latest_roast | awk -F'\t' '$2 == "REJECT" && index($4, "[SMX]") { c++ } END { print c + 0 }')"; readings="$readings reject_smx=$c(at_most $lim)"; [ "$c" -le "$lim" ] || pgreen=0 ;;
        row) [ -r "$SUITES" ] || refuse "no $SUITES"; c="$(awk -F'\t' -v k="$arg" 'NR == 2 { for (i = 1; i <= NF; i++) h[$i] = i } $1 == k { print $(h["today_pass"]) }' "$SUITES")"; [ -n "$c" ] || refuse "no row $arg in SUITES.tsv"
             readings="$readings row[$arg]=$c(at_least $lim)"; [ "$c" -ge "$lim" ] || pgreen=0 ;;
        census) c="$(grep -rc -- "$arg" "$SC/src" --include=*.c --include=*.cpp --include=*.h --include=*.inc 2>/dev/null | awk -F: '{ s += $2 } END { print s + 0 }')"; readings="$readings census[$arg]=$c(at_most $lim)"; [ "$c" -le "$lim" ] || pgreen=0 ;;
        smoke) if ( cd "$SC" && timeout -k 10 600 bash "$HERE/test_smoke_raku.sh" > "$OUT/step$step/smoke.log" 2>&1 ); then readings="$readings smoke=green"; else readings="$readings smoke=red"; pgreen=0; fi ;;
        *) refuse "unknown probe token $tok in step $step" ;;
    esac
done
verdict=GREEN; [ "$m3p" = "$n" ] && [ "$m4p" = "$n" ] && [ "$pgreen" = 1 ] || verdict=RED
echo "STEP $step $slug: m3=$m3p/$n m4=$m4p/$n probe=${readings# } -> $verdict${reds:+ reds:$reds}"
[ "$verdict" = GREEN ] && exit 0 || exit 1
