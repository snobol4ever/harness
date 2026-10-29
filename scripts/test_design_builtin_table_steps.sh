#!/usr/bin/env bash
# test_design_builtin_table_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: builtin-table (the cto, 2026-10-29, CEO-1996; .github/ARCH-BUILTIN-TABLE.md).
# The plan is corpus/tests/shared/builtin_table/STEPS.tsv; the witnesses are the .sno, .icn and .raku programs beside it, each with a .ref cut from its
# oracle (SPITBOL sbl -bf; Arizona Icon icont -s then the binary; Rakudo), stdout compared exactly.
#
#   --list       print the steps and run nothing
#   --step N     grade step N: every witness in mode 3 and mode 4 (-d131072k -s4096k), then the step's probe tokens:
#                strcmpfn:N bidchain:N strcmpmeth:N (counts of strcmp(fn, ", _bid == BID_ and strcmp(meth, " in src/runtime/by_name_dispatch.c, at most N)
#                boxcensus=L:N (call_byname, call_try, call_method and call_gen boxes over corpus/benchmarks/L in mode 4, at most N; the box kinds that carry a name)
#                ircall=W:N (callgrind Ir per call of loop witness W's mode-4 binary, 200000 calls, at most N)
#                nosym=a,b (no definition or reference of the names under SCRIP/src, read) | gate=name (bash name.sh rc 0) | smoke=L|ALL (test_smoke_L.sh green; ALL = the eight)
#                rows=L|ALL (SUITES.tsv today_pass not below the pass recorded in ROWS0.tsv beside STEPS.tsv) | rowsmin=N (harness/scripts/builtins.tsv holds at least N rows) | -
#   --cut        re-cut every witness ref from its oracle (the design seat's road; an HQ that changes a witness re-cuts it the same way)
#   --rows0      record SUITES.tsv's rows into ROWS0.tsv (the reading the rows probe compares against; the design seat records it once; an executor re-records before its step)
#   --out DIR    where the runs go (default <root>/.scratch/builtin_table)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> probe=<token:reading ...> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
WD="$ROOT/corpus/tests/shared/builtin_table"
BENCH="$ROOT/corpus/benchmarks"
STEPS="$WD/STEPS.tsv"
ROWS0="$WD/ROWS0.tsv"
OUT="$ROOT/.scratch/builtin_table"
SUITES=/home/resources/progress/SUITES.tsv
SBL=/home/resources/x64/bin/sbl
ICONT=/home/resources/icon-master/bin/icont
DISPATCH="$SC/src/runtime/by_name_dispatch.c"
TSV="$HERE/builtins.tsv"
SMOKES="snobol4 snocone rebus icon prolog raku pascal polyglot"
CALLS=200000
refuse() { echo "REFUSE(2): $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
mode=""; step=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "--step takes a number"; shift 2 ;;
        --cut) mode=cut; shift ;;
        --rows0) mode=rows0; shift ;;
        --out) OUT="${2:-}"; shift 2 ;;
        *) refuse "usage: $0 --list | --step N [--out DIR] | --cut | --rows0" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N [--out DIR] | --cut | --rows0"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
wext() { local w="$1"; for e in sno icn raku; do [ -f "$WD/$w.$e" ] && { echo "$e"; return 0; }; done; return 1; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: builtin-table -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6' "$STEPS" | wc -l) steps (STEPS.tsv); witnesses in corpus/tests/shared/builtin_table (refs from SPITBOL, Arizona Icon, Rakudo)"
    printf '%-4s %-74s %-10s %-7s %s\n' step slug executor depends witnesses
    for n in $(awk -F'\t' '!/^#/ && $1 != "step" {print $1}' "$STEPS"); do
        printf '%-4s %-74s %-10s %-7s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 4)" "$(col "$n" 6)"
    done
    exit 0
fi
if [ "$mode" = rows0 ]; then
    [ -r "$SUITES" ] || refuse "no $SUITES"
    awk -F'\t' 'NR == 2 { for (i = 1; i <= NF; i++) h[$i] = i; print "suite\tlang\tpass\ttotal"; next } NR > 2 && $4 != "" { print $1 "\t" $4 "\t" $(h["today_pass"]) "\t" $(h["today_total"]) }' "$SUITES" > "$ROWS0"
    echo "recorded $(( $(wc -l < "$ROWS0") - 1 )) rows into $ROWS0 ($(date '+%Y-%m-%d %H:%M'))"; exit 0
fi
if [ "$mode" = cut ]; then
    [ -x "$SBL" ] || refuse "no sbl at $SBL (ORACLES.md: the SPITBOL correctness oracle)"
    [ -x "$ICONT" ] || refuse "no icont at $ICONT (ORACLES.md: the Icon oracle)"
    RAKU="$(. "$HERE/lib_oracle_flags.sh" && rakudo_bin)" || refuse "no rakudo (lib_oracle_flags.sh rakudo_bin)"
    T="$(mktemp -d "${TMPDIR:-/tmp}/bt_cut.XXXXXX")"
    for w in $(awk -F'\t' '!/^#/ && $1 != "step" && $6 != "-" {print $6}' "$STEPS" | tr ' ' '\n' | sort -u); do
        e="$(wext "$w")" || refuse "witness $w has no .sno, .icn or .raku in $WD"
        case "$e" in
            sno) ( cd "$T" && timeout -k 5 120 "$SBL" -bf "$WD/$w.sno" < /dev/null > "$WD/$w.ref" 2> "$T/$w.err" ) ;;
            icn) ( cd "$T" && "$ICONT" -s -o "$T/$w.ix" "$WD/$w.icn" > "$T/$w.err" 2>&1 && timeout -k 5 120 "$T/$w.ix" < /dev/null > "$WD/$w.ref" 2>> "$T/$w.err" ) ;;
            raku) ( cd "$T" && timeout -k 5 300 "$RAKU" "$WD/$w.raku" < /dev/null > "$WD/$w.ref" 2> "$T/$w.err" ) ;;
        esac
        echo "cut $w.ref: $(wc -l < "$WD/$w.ref") lines$(grep -q . "$T/$w.err" && echo " (THE ORACLE COMPLAINED: $(head -c 120 "$T/$w.err" | tr '\n' ' '))")"
    done
    rm -rf "$T"; exit 0
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
    e="$(wext "$w")" || refuse "witness $w has no .sno, .icn or .raku in $WD"
    ref="$WD/$w.ref"; [ -f "$ref" ] || refuse "witness $w has no .ref in $WD (--cut)"
    n=$((n + 1))
    for m in m3 m4; do
        d="$OUT/step$step/$w.$m"; rm -rf "$d"; mkdir -p "$d"; cp "$WD/$w.$e" "$d/$w.$e"
        if [ "$m" = m3 ]; then
            ( cd "$d" && timeout -k 5 300 "$SC/scrip" -d131072k -s4096k "$w.$e" < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
        else
            if ( cd "$d" && timeout -k 5 300 "$SC/scrip" --compile --out="$d/run.s" "$w.$e" < /dev/null > /dev/null 2> "$d/cerr" ) \
               && gcc -c "$d/run.s" -o "$d/run.o" 2> /dev/null && gcc "$d/run.o" -L"$SC/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$SC/out" -o "$d/run.bin" 2> /dev/null; then
                ( cd "$d" && timeout -k 5 300 "$d/run.bin" -d131072k -s4096k < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
            else rc=no-binary; fi
        fi
        if [ "$rc" = 0 ] && diff -q "$d/out" "$ref" > /dev/null 2>&1; then [ "$m" = m3 ] && m3p=$((m3p + 1)) || m4p=$((m4p + 1)); else reds="$reds $m:$w(rc$rc)"; fi
    done
done
count_in_dispatch() { [ -f "$DISPATCH" ] || { echo REFUSED; return; }; grep -c -- "$1" "$DISPATCH"; }
boxcensus() { # $1 language -> the named-callee call boxes over its benchmark kernels, mode 4
    local l="$1" c=0 t f d="$OUT/step$step/census_$1"; mkdir -p "$d"
    for f in "$BENCH/$l"/*.sno "$BENCH/$l"/*.sc "$BENCH/$l"/*.reb "$BENCH/$l"/*.icn "$BENCH/$l"/*.pl "$BENCH/$l"/*.pas "$BENCH/$l"/*.raku; do
        [ -f "$f" ] || continue
        ( cd "$d" && timeout -k 2 300 "$SC/scrip" --compile --out="$d/x.s" "$f" < /dev/null > /dev/null 2>&1 ) || { echo "REFUSED"; return; }
        t="$(grep -cE '^n[0-9]+_(call_byname|call_try|call_method|call_gen)_α:' "$d/x.s")"; c=$((c + t))
    done
    echo "$c"
}
ircall() { # $1 witness -> Ir per call of its mode-4 binary under callgrind
    local w="$1" b="$OUT/step$step/$1.m4/run.bin" ir
    [ -x "$b" ] || { echo "REFUSED"; return; }
    command -v valgrind > /dev/null || { echo "REFUSED"; return; }
    ir="$(cd "$OUT/step$step/$w.m4" && SCRIP_DIAG=0 timeout -k 10 1800 valgrind --tool=callgrind --callgrind-out-file="$OUT/step$step/$w.cg" "$b" -d131072k -s4096k < /dev/null 2>&1 > /dev/null | sed -n 's/.*I *refs: *\([0-9,]*\).*/\1/p' | tr -d ,)"
    [ -n "$ir" ] || { echo "REFUSED"; return; }
    echo $(( ir / CALLS ))
}
readings=""; pgreen=1
[ "$probe" = "-" ] && probe=""
for tok in $probe; do
    key="${tok%%=*}"; val="${tok#*=}"
    case "$key" in
        strcmpfn:*|bidchain:*|strcmpmeth:*)
            k="${tok%%:*}"; lim="${tok##*:}"
            case "$k" in strcmpfn) pat='strcmp(fn, "' ;; bidchain) pat='_bid == BID_' ;; strcmpmeth) pat='strcmp(meth, "' ;; esac
            c="$(count_in_dispatch "$pat")"; [ "$c" = REFUSED ] && refuse "no $DISPATCH"; readings="$readings $k=$c(at_most $lim)"; [ "$c" -le "$lim" ] || pgreen=0 ;;
        boxcensus) l="${val%%:*}"; lim="${val##*:}"; c="$(boxcensus "$l")"; [ "$c" = REFUSED ] && refuse "a $l kernel did not compile for the census"
            readings="$readings boxcensus[$l]=$c(at_most $lim)"; [ "$c" -le "$lim" ] || pgreen=0 ;;
        ircall) w="${val%%:*}"; lim="${val##*:}"; c="$(ircall "$w")"; [ "$c" = REFUSED ] && refuse "witness $w has no mode-4 binary in this step or valgrind is missing"
            readings="$readings ircall[$w]=$c(at_most $lim)"; [ "$c" -le "$lim" ] || pgreen=0 ;;
        nosym) bad=0; for s in ${val//,/ }; do grep -rqw "$s" "$SC/src" && bad=$((bad + 1)); done; readings="$readings nosym_present=$bad"; [ "$bad" = 0 ] || pgreen=0 ;;
        gate) [ -f "$HERE/$val.sh" ] || { readings="$readings gate[$val]=missing"; pgreen=0; continue; }
            if ( cd "$SC" && timeout -k 10 1800 bash "$HERE/$val.sh" > "$OUT/step$step/$val.log" 2>&1 ); then readings="$readings gate[$val]=green"; else readings="$readings gate[$val]=red"; pgreen=0; fi ;;
        smoke) [ "$val" = ALL ] && ls="$SMOKES" || ls="${val//,/ }"
            for l in $ls; do if ( cd "$SC" && timeout -k 10 900 bash "$HERE/test_smoke_$l.sh" > "$OUT/step$step/smoke_$l.log" 2>&1 ); then readings="$readings smoke[$l]=green"; else readings="$readings smoke[$l]=red"; pgreen=0; fi; done ;;
        rows) [ -r "$SUITES" ] || refuse "no $SUITES"; [ -r "$ROWS0" ] || refuse "no $ROWS0 (--rows0 records it)"
            [ "$val" = ALL ] && ls="icon pascal prolog raku rebus scriptix snobol4 snocone" || ls="${val//,/ }"
            short=""
            for l in $ls; do
                short="$short$(awk -F'\t' -v L="$l" 'FNR == NR { if (FNR > 1 && $2 == L) r[$1] = $3; next } FNR == 2 { for (i = 1; i <= NF; i++) h[$i] = i } FNR > 2 && $4 == L && ($1 in r) && $(h["today_pass"]) + 0 < r[$1] + 0 { printf "%s %s<%s ", $1, $(h["today_pass"]), r[$1] }' "$ROWS0" "$SUITES")"
            done
            bad="$(printf '%s' "$short" | wc -w)"; readings="$readings rows_below=$bad[${short% }]"; [ "$bad" = 0 ] || pgreen=0 ;;
        rowsmin) if [ -f "$TSV" ]; then c="$(grep -cv '^#' "$TSV")"; else c=0; fi; readings="$readings tsv_rows=$c(at_least $val)"; [ "$c" -ge "$val" ] || pgreen=0 ;;
        *) refuse "unknown probe token $tok in step $step" ;;
    esac
done
verdict=GREEN; [ "$m3p" = "$n" ] && [ "$m4p" = "$n" ] && [ "$pgreen" = 1 ] || verdict=RED
echo "STEP $step $slug: m3=$m3p/$n m4=$m4p/$n probe=${readings# } -> $verdict${reds:+ reds:$reds}"
[ "$verdict" = GREEN ] && exit 0 || exit 1
