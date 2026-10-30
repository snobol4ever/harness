#!/usr/bin/env bash
# test_design_zeta_layout_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: zeta-layout, ONE SOURCE OF TRUTH FOR THE THREE ZETAS' LAYOUTS (the cto, 2026-10-29;
# CEO-1996; Lon in-chat to the cto, verbatim: "Yes, let's fix the system have ONE SOURCE of TRUTH for the THREE ZETAS memory layouts."; .github/ARCH-ZETA-LAYOUT-ONE-SOURCE-OF-TRUTH.md).
# The plan is corpus/tests/shared/zeta_layout/STEPS.tsv; the witnesses are the .sno, .icn, .pl, .pas and .raku programs beside it, each with a .ref cut from its
# oracle (SPITBOL sbl -bf; Arizona Icon icont -s then the binary; swipl -q -t halt; fpc -Miso then the binary; Rakudo), stdout compared exactly.
# EVERY WITNESS RUNS FOUR WAYS: mode 3 and mode 4 (-d131072k -s4096k), each plain and under the collector's stress (SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=128
# SCRIP_HEAP_MAX_MB=512, the gc gates' arena): a layout defect is a root the collector cannot see, and only a collection that moves the heap shows it.
#
#   --list       print the steps and run nothing
#   --step N     grade step N: every witness four ways, then the step's probe tokens:
#                gate=name (bash name.sh rc 0) | smoke=L|ALL (test_smoke_L.sh green; ALL = the eight) | nosym=a,b (no definition or reference of the names under SCRIP/src)
#                nofile=rel,rel (no such file under SCRIP) | grepmax=REGEX@REL:N (grep -rcE REGEX over SCRIP/REL sums to at most N; REL a file or a directory; a REGEX
#                may not contain @ or whitespace) | tsvmin=FILE:N (harness/scripts/FILE holds at least N non-comment rows) | rule5=N (SCRIP_GC_SITES_REPORT=1 --compile over
#                the gc_witnesses population and this step's witnesses: rule=5 site records at most N; a compile that fails REFUSES) | rspmoves=N (the template rsp-move
#                census: x86("push" | x86("pop" | x86("sub"/"add", "rsp" in src/templates/bb and xa, at most N) | layoutcheck=N (util_zeta_layout_check.py over the step's
#                witnesses' mode-4 asm against --dump-plan, mismatches at most N; RED while the checker does not exist, since the checker is step 1's deliverable) | rows=L|ALL (SUITES.tsv today_pass not below
#                ROWS0.tsv) | -
#   --cut        re-cut every witness ref from its oracle (the design seat's road; an HQ that changes a witness re-cuts it the same way)
#   --rows0      record SUITES.tsv's rows into ROWS0.tsv (the reading the rows probe compares against)
#   --out DIR    where the runs go (default <root>/.scratch/zeta_layout)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> m3s=<pass>/<n> m4s=<pass>/<n> probe=<token:reading ...> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
WD="$ROOT/corpus/tests/shared/zeta_layout"
GCW="$HERE/gc_witnesses"
STEPS="$WD/STEPS.tsv"
ROWS0="$WD/ROWS0.tsv"
OUT="$ROOT/.scratch/zeta_layout"
SUITES=/home/resources/progress/SUITES.tsv
SBL=/home/resources/x64/bin/sbl
SMOKES="snobol4 snocone rebus icon prolog raku pascal polyglot"
STRESS_ENV="SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=128 SCRIP_HEAP_MAX_MB=512"
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
wext() { local w="$1"; for e in sno icn pl pas raku; do [ -f "$WD/$w.$e" ] && { echo "$e"; return 0; }; done; return 1; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: zeta-layout -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6' "$STEPS" | wc -l) steps (STEPS.tsv); witnesses in corpus/tests/shared/zeta_layout (refs from SPITBOL, Arizona Icon, swipl, fpc -Miso, Rakudo)"
    printf '%-4s %-78s %-12s %-7s %s\n' step slug executor depends witnesses
    for n in $(awk -F'\t' '!/^#/ && $1 != "step" {print $1}' "$STEPS"); do
        printf '%-4s %-78s %-12s %-7s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 4)" "$(col "$n" 6)"
    done
    exit 0
fi
if [ "$mode" = rows0 ]; then
    [ -r "$SUITES" ] || refuse "no $SUITES"
    awk -F'\t' 'NR == 2 { for (i = 1; i <= NF; i++) h[$i] = i; print "suite\tlang\tpass\ttotal"; next } NR > 2 && $4 != "" { print $1 "\t" $4 "\t" $(h["today_pass"]) "\t" $(h["today_total"]) }' "$SUITES" > "$ROWS0"
    echo "recorded $(( $(wc -l < "$ROWS0") - 1 )) rows into $ROWS0 ($(date '+%Y-%m-%d %H:%M'))"; exit 0
fi
if [ "$mode" = cut ]; then
    . "$HERE/lib_oracle_flags.sh"
    [ -x "$SBL" ] || refuse "no sbl at $SBL (ORACLES.md: the SPITBOL correctness oracle)"
    ICONT="$(icont_bin)" || refuse "no icont (lib_oracle_flags.sh icont_bin)"
    SWIPL="$(swipl_bin)" || refuse "no swipl (lib_oracle_flags.sh swipl_bin)"
    RAKU="$(rakudo_bin)" || refuse "no rakudo (lib_oracle_flags.sh rakudo_bin)"
    command -v fpc > /dev/null || refuse "no fpc (the Pascal oracle, fpc -Miso)"
    T="$(mktemp -d "${TMPDIR:-/tmp}/zl_cut.XXXXXX")"
    for w in $(awk -F'\t' '!/^#/ && $1 != "step" && $6 != "-" {print $6}' "$STEPS" | tr ' ' '\n' | sort -u); do
        e="$(wext "$w")" || refuse "witness $w has no .sno, .icn, .pl, .pas or .raku in $WD"
        case "$e" in
            sno) ( cd "$T" && timeout -k 5 120 "$SBL" -bf "$WD/$w.sno" < /dev/null > "$WD/$w.ref" 2> "$T/$w.err" ) ;;
            icn) ( cd "$T" && "$ICONT" -s -o "$T/$w.ix" "$WD/$w.icn" > "$T/$w.err" 2>&1 && timeout -k 5 120 "$T/$w.ix" < /dev/null > "$WD/$w.ref" 2>> "$T/$w.err" ) ;;
            pl) ( cd "$T" && timeout -k 5 120 "$SWIPL" -q -t halt "$WD/$w.pl" < /dev/null > "$WD/$w.ref" 2> "$T/$w.err" ) ;;
            pas) ( cd "$T" && fpc -Miso -o"$T/$w.bin" "$WD/$w.pas" > "$T/$w.err" 2>&1 && timeout -k 5 120 "$T/$w.bin" < /dev/null > "$WD/$w.ref" 2>> "$T/$w.err" ) ;;
            raku) ( cd "$T" && timeout -k 5 300 "$RAKU" "$WD/$w.raku" < /dev/null > "$WD/$w.ref" 2> "$T/$w.err" ) ;;
        esac
        echo "cut $w.ref: $(wc -l < "$WD/$w.ref") lines$(grep -qi 'error\|fatal\|warning' "$T/$w.err" && echo " (THE ORACLE COMPLAINED: $(grep -i 'error\|fatal\|warning' "$T/$w.err" | head -c 160 | tr '\n' ' '))")"
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
declare -A pass=([m3]=0 [m4]=0 [m3s]=0 [m4s]=0)
n=0; reds=""
[ "$wits" = "-" ] && wits=""
run_one() { # $1 dir $2 binary-or-scrip $3 witness-file-or-empty $4 stress(0|1) -> writes $1/out, returns rc
    local d="$1" bin="$2" f="$3" s="$4" rc
    if [ "$s" = 1 ]; then ( cd "$d" && env -u SCRIP_HEAP_MB $STRESS_ENV timeout -k 5 300 "$bin" -d131072k -s4096k $f < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
    else ( cd "$d" && env -u SCRIP_HEAP_MB -u SCRIP_GC_STRESS -u SCRIP_HEAP_KB timeout -k 5 300 "$bin" -d131072k -s4096k $f < /dev/null > "$d/out" 2> "$d/err" ); rc=$?; fi
    return $rc
}
for w in $wits; do
    e="$(wext "$w")" || refuse "witness $w has no .sno, .icn, .pl, .pas or .raku in $WD"
    ref="$WD/$w.ref"; [ -f "$ref" ] || refuse "witness $w has no .ref in $WD (--cut)"
    n=$((n + 1))
    b="$OUT/step$step/$w"; rm -rf "$b.m4bin"; mkdir -p "$b.m4bin"
    if ( cd "$b.m4bin" && timeout -k 5 300 "$SC/scrip" --compile --out="$b.m4bin/run.s" "$WD/$w.$e" < /dev/null > /dev/null 2> "$b.m4bin/cerr" ) \
       && gcc -c "$b.m4bin/run.s" -o "$b.m4bin/run.o" 2> /dev/null && gcc "$b.m4bin/run.o" -L"$SC/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$SC/out" -o "$b.m4bin/run.bin" 2> /dev/null; then have4=1; else have4=0; fi
    for m in m3 m4 m3s m4s; do
        d="$b.$m"; rm -rf "$d"; mkdir -p "$d"; cp "$WD/$w.$e" "$d/$w.$e"
        s=0; case "$m" in *s) s=1 ;; esac
        case "$m" in
            m3*) run_one "$d" "$SC/scrip" "$w.$e" "$s"; rc=$? ;;
            m4*) if [ "$have4" = 1 ]; then run_one "$d" "$b.m4bin/run.bin" "" "$s"; rc=$?; else rc=no-binary; fi ;;
        esac
        if [ "$rc" = 0 ] && diff -q "$d/out" "$ref" > /dev/null 2>&1; then pass[$m]=$(( ${pass[$m]} + 1 )); else reds="$reds $m:$w(rc$rc)"; fi
    done
done
rule5_census() { # the gc_witnesses population plus this step's witnesses, mode-4 compile with SCRIP_GC_SITES_REPORT=1; prints the rule=5 count or REFUSED
    local d="$OUT/step$step/rule5" c=0 t f; mkdir -p "$d"; : > "$d/rules.txt"
    for f in "$GCW"/*.sno "$GCW"/*.icn "$GCW"/*.pl "$GCW"/*.pas "$GCW"/*.raku "$GCW"/*.sc; do
        [ -f "$f" ] || continue
        ( cd "$d" && SCRIP_GC_SITES_REPORT=1 timeout -k 2 120 "$SC/scrip" --compile --out="$d/x.s" "$f" < /dev/null 2> "$d/rep" > /dev/null ) || { echo "REFUSED($(basename "$f"))"; return; }
        t="$(grep -c 'rule=5 ' "$d/rep")"; c=$((c + t)); [ "$t" -gt 0 ] && echo "$(basename "$f") $t" >> "$d/rules.txt"
    done
    for w in $wits; do f="$WD/$w.$(wext "$w")"
        ( cd "$d" && SCRIP_GC_SITES_REPORT=1 timeout -k 2 120 "$SC/scrip" --compile --out="$d/x.s" "$f" < /dev/null 2> "$d/rep" > /dev/null ) || { echo "REFUSED($w)"; return; }
        t="$(grep -c 'rule=5 ' "$d/rep")"; c=$((c + t)); [ "$t" -gt 0 ] && echo "$w $t" >> "$d/rules.txt"
    done
    echo "$c"
}
rspmoves_census() { grep -rhoE 'x86\("push"|x86\("pop"|x86\("(sub|add)", *"rsp"' "$SC/src/templates/bb" "$SC/src/templates/xa" | wc -l; }
layoutcheck() { # the harness checker over this step's witnesses' mode-4 asm against the plan dump; prints mismatches or REFUSED
    local chk="$HERE/util_zeta_layout_check.py" c=0 t w b
    [ -f "$chk" ] || { echo REFUSED; return; }
    for w in $wits; do b="$OUT/step$step/$w"; [ -f "$b.m4bin/run.s" ] || { echo REFUSED; return; }
        ( cd "$b.m4bin" && timeout -k 5 300 "$SC/scrip" --dump-plan "$WD/$w.$(wext "$w")" < /dev/null > "$b.m4bin/plan.txt" 2> /dev/null ) || { echo REFUSED; return; }
        t="$(python3 -I "$chk" --asm "$b.m4bin/run.s" --plan "$b.m4bin/plan.txt" 2> "$b.m4bin/check.err" | tee "$b.m4bin/check.out" | tail -1 | sed -n 's/.*mismatches=\([0-9]*\).*/\1/p')"
        [ -n "$t" ] || { echo REFUSED; return; }; c=$((c + t))
    done
    echo "$c"
}
layout_unexercised() { # the GC site rules no witness of the step emits: the intersection of each witness's SITE-UNEXERCISED lines (the checker's output kept by layoutcheck); `-` when none or unread
    local w b n=0 r; local -a fs=()
    for w in $wits; do b="$OUT/step$step/$w"; [ -f "$b.m4bin/check.out" ] || { echo "-"; return; }; fs+=("$b.m4bin/check.out"); n=$((n + 1)); done
    r="$(grep -h '^SITE-UNEXERCISED rule=' "${fs[@]}" | sort | uniq -c | awk -v n="$n" '$1 == n { sub(/.*rule=/, ""); printf "%s%s", sep, $0; sep = "," }')"
    echo "${r:--}"
}
readings=""; pgreen=1
[ "$probe" = "-" ] && probe=""
for tok in $probe; do
    key="${tok%%=*}"; val="${tok#*=}"
    case "$key" in
        nosym) bad=0; for s in ${val//,/ }; do grep -rqw -- "$s" "$SC/src" && bad=$((bad + 1)); done; readings="$readings nosym_present=$bad"; [ "$bad" = 0 ] || pgreen=0 ;;
        nofile) bad=0; for s in ${val//,/ }; do [ -e "$SC/$s" ] && bad=$((bad + 1)); done; readings="$readings files_present=$bad"; [ "$bad" = 0 ] || pgreen=0 ;;
        grepmax) re="${val%%@*}"; rest="${val#*@}"; rel="${rest%%:*}"; lim="${rest##*:}"
            [ -e "$SC/$rel" ] || refuse "grepmax: no $SC/$rel"
            c="$(grep -rhoE -- "$re" "$SC/$rel" | wc -l)"; readings="$readings grep[$re@$rel]=$c(at_most $lim)"; [ "$c" -le "$lim" ] || pgreen=0 ;;
        tsvmin) f="${val%%:*}"; lim="${val##*:}"; if [ -f "$HERE/$f" ]; then c="$(grep -cv '^#' "$HERE/$f")"; else c=0; fi; readings="$readings tsv[$f]=$c(at_least $lim)"; [ "$c" -ge "$lim" ] || pgreen=0 ;;
        rule5) c="$(rule5_census)"; case "$c" in REFUSED*) refuse "rule5: a program of the population did not compile: $c" ;; esac
            readings="$readings rule5_sites=$c(at_most $val)"; [ "$c" -le "$val" ] || pgreen=0 ;;
        rspmoves) c="$(rspmoves_census)"; readings="$readings template_rsp_moves=$c(at_most $val)"; [ "$c" -le "$val" ] || pgreen=0 ;;
        layoutcheck) c="$(layoutcheck)"
            if [ "$c" = REFUSED ]; then readings="$readings layout_checker=missing(step 1 writes util_zeta_layout_check.py; a witness with no mode-4 binary or plan dump also reads here)"; pgreen=0
            else readings="$readings layout_mismatches=$c(at_most $val) site_rules_unexercised=$(layout_unexercised)"; [ "$c" -le "$val" ] || pgreen=0; fi ;;
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
        *) refuse "unknown probe token $tok in step $step" ;;
    esac
done
verdict=GREEN; for m in m3 m4 m3s m4s; do [ "${pass[$m]}" = "$n" ] || verdict=RED; done; [ "$pgreen" = 1 ] || verdict=RED
echo "STEP $step $slug: m3=${pass[m3]}/$n m4=${pass[m4]}/$n m3s=${pass[m3s]}/$n m4s=${pass[m4s]}/$n probe=${readings# } -> $verdict${reds:+ reds:$reds}"
[ "$verdict" = GREEN ] && exit 0 || exit 1
