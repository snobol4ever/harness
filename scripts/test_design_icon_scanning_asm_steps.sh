#!/usr/bin/env bash
# test_design_icon_scanning_asm_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: icon-scanning-asm (the cto, 2026-10-28, CEO-1996/1998;
# .github/ARCH-ICON-RTX.md section 11). The plan is corpus/tests/icon/scanning_asm/STEPS.tsv; the witnesses are the .icn programs beside
# it, each with a .ref cut from Arizona Icon (icont -s, the binary's stdout).
#
#   --list       print the steps and run nothing
#   --step N     grade step N: every witness in mode 3 and mode 4 (the declared -d131072k -s4096k, stdout compared exactly with the ref), then
#                the step's probe tokens: census=f1,f2:N (emitted calls to the named C functions over corpus/benchmarks/icon/*.icn and
#                is00_kw.icn in mode 4, at most N; ALL = the nine scan functions, rt_keyword_var and rt_substr), nosym=a,b (no definition
#                or reference of the names under SCRIP/src/runtime, READ), nomirror (no reader of g_runtime.abi.scan_ under SCRIP/src, READ),
#                smoke (test_smoke_icon.sh green), rows (SUITES.tsv's icon rows today_pass equal to total, READ). Red before the step
#                lands, green after.
#   --cut        re-cut every witness ref from iconx (the design seat's road; an HQ that changes a witness re-cuts it the same way)
#   --out DIR    where the runs go (default <root>/.scratch/icon_scanning_asm)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> probe=<token:reading ...> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
WD="$ROOT/corpus/tests/icon/scanning_asm"
BENCH="$ROOT/corpus/benchmarks/icon"
STEPS="$WD/STEPS.tsv"
OUT="$ROOT/.scratch/icon_scanning_asm"
SUITES=/home/resources/progress/SUITES.tsv
ICONT=/home/resources/icon-master/bin/icont
ALLF="rt_scan_enter rt_scan_leave rt_scan_sync_in rt_scan_sync_out rt_scan_live_subj rt_scan_reenter_live rt_scan_needle rt_icn_cset_bits_d rt_icn_cset_member_n rt_keyword_var rt_substr"
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
    echo "DESIGN-PLAN: icon-scanning-asm -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6' "$STEPS" | wc -l) steps (STEPS.tsv); witnesses in corpus/tests/icon/scanning_asm (refs from Arizona Icon)"
    printf '%-4s %-48s %-11s %-11s %s\n' step slug executor depends witnesses
    for n in $(awk -F'\t' '!/^#/ && $1 != "step" {print $1}' "$STEPS"); do
        printf '%-4s %-48s %-11s %-11s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 4)" "$(col "$n" 6)"
    done
    exit 0
fi
if [ "$mode" = cut ]; then
    [ -x "$ICONT" ] || refuse "no icont at $ICONT (ORACLES.md: the Icon oracle)"
    T="$(mktemp -d "${TMPDIR:-/tmp}/icnscan_cut.XXXXXX")"
    for w in $(awk -F'\t' '!/^#/ && $1 != "step" && $6 != "-" {print $6}' "$STEPS" | tr ' ' '\n' | sort -u); do
        ( cd "$T" && "$ICONT" -s -o "$T/$w.ix" "$WD/$w.icn" > "$T/$w.cerr" 2>&1 && timeout -k 5 120 "$T/$w.ix" < /dev/null > "$WD/$w.ref" 2> /dev/null ); echo "cut $w.ref: $(wc -l < "$WD/$w.ref") lines$(grep -q . "$T/$w.cerr" && echo ' (ICONT COMPLAINED: read the log)')"
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
    [ -f "$WD/$w.icn" ] && [ -f "$ref" ] || refuse "witness $w has no .icn or .ref in $WD"
    n=$((n + 1))
    for m in m3 m4; do
        d="$OUT/step$step/$w.$m"; rm -rf "$d"; mkdir -p "$d"; cp "$WD/$w.icn" "$d/$w.icn"
        if [ "$m" = m3 ]; then
            ( cd "$d" && timeout -k 5 120 "$SC/scrip" -d131072k -s4096k "$w.icn" < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
        else
            if ( cd "$d" && timeout -k 5 300 "$SC/scrip" --compile -o "$d/run.s" "$w.icn" < /dev/null > /dev/null 2> "$d/cerr" ) \
               && gcc -c "$d/run.s" -o "$d/run.o" 2> /dev/null && gcc "$d/run.o" -L"$SC/out" -lscrip_rt -lm -Wl,-rpath,"$SC/out" -o "$d/run.bin" 2> /dev/null; then
                ( cd "$d" && timeout -k 5 120 "$d/run.bin" -d131072k -s4096k < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
            else rc=no-binary; fi
        fi
        if [ "$rc" = 0 ] && diff -q "$d/out" "$ref" > /dev/null 2>&1; then [ "$m" = m3 ] && m3p=$((m3p + 1)) || m4p=$((m4p + 1)); else reds="$reds $m:$w(rc$rc)"; fi
    done
done
census() { # $1 space-separated function names -> the emitted call count over the benchmarks and is00_kw, mode 4
    local pat; pat="$(printf '%s' "$1" | sed 's/ /|/g')"; local c=0 t; local d="$OUT/step$step/census"; mkdir -p "$d"
    for f in "$BENCH"/*.icn "$WD/is00_kw.icn"; do
        ( cd "$d" && timeout -k 2 120 "$SC/scrip" --compile -o "$d/x.s" "$f" < /dev/null > /dev/null 2>&1 ) || { echo "REFUSED"; return; }
        t="$(grep -cE "call[[:space:]]+(qword ptr \[rip \+ )?($pat)\b" "$d/x.s")"; c=$((c + t))
    done
    echo "$c"
}
readings=""; pgreen=1
[ "$probe" = "-" ] && probe=""
for tok in $probe; do
    key="${tok%%=*}"; val="${tok#*=}"
    case "$key" in
        census) fl="${val%%:*}"; lim="${val##*:}"; [ "$fl" = ALL ] && fl="$ALLF" || fl="${fl//,/ }"; c="$(census "$fl")"
                [ "$c" = REFUSED ] && refuse "a benchmark did not compile for the census"; readings="$readings census[${val%%:*}]=$c(at_most $lim)"; [ "$c" -le "$lim" ] || pgreen=0 ;;
        nosym) bad=0; for s in ${val//,/ }; do grep -rqw "$s" "$SC/src/runtime" && bad=$((bad + 1)); done; readings="$readings nosym_present=$bad"; [ "$bad" = 0 ] || pgreen=0 ;;
        nomirror) c="$(grep -rc 'abi\.scan_' "$SC/src" --include=*.c --include=*.cpp --include=*.h --include=*.inc 2>/dev/null | awk -F: '{ s += $2 } END { print s + 0 }')"; readings="$readings mirror_readers=$c"; [ "$c" = 0 ] || pgreen=0 ;;
        smoke) if ( cd "$SC" && timeout -k 10 600 bash "$HERE/test_smoke_icon.sh" > "$OUT/step$step/smoke.log" 2>&1 ); then readings="$readings smoke=green"; else readings="$readings smoke=red"; pgreen=0; fi ;;
        rows) [ -r "$SUITES" ] || refuse "no $SUITES"; bad="$(awk -F'\t' 'NR == 2 { for (i = 1; i <= NF; i++) h[$i] = i } $4 == "icon" { if ($(h["today_pass"]) != $(h["today_total"])) b++ } END { print b + 0 }' "$SUITES")"; readings="$readings icon_rows_short=$bad"; [ "$bad" = 0 ] || pgreen=0 ;;
        *) refuse "unknown probe token $tok in step $step" ;;
    esac
done
verdict=GREEN; [ "$m3p" = "$n" ] && [ "$m4p" = "$n" ] && [ "$pgreen" = 1 ] || verdict=RED
echo "STEP $step $slug: m3=$m3p/$n m4=$m4p/$n probe=${readings# } -> $verdict${reds:+ reds:$reds}"
[ "$verdict" = GREEN ] && exit 0 || exit 1
