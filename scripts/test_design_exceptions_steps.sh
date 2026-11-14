#!/usr/bin/env bash
"$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_design_exceptions_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: exceptions, ONE ERROR PROTOCOL FOR EVERY LANGUAGE: A RAISE RETURNS, THE BOX UNWINDS (the cto, 2026-10-29;
# R-1996; Lon in-chat to the cto, verbatim: "Do address the second flaw, i.e. skipping omega and standardizing the exception processes."; .github/ARCH-EXCEPTIONS-ONE-PROTOCOL.md).
# The plan is harness/designs/exceptions/STEPS.tsv; the witnesses are the .sno, .icn, .pl, .pas and .raku programs, each the entry exceptions__<name> of its language's master
# (else, until its language's consolidation enters it, the loose pair corpus/tests/<lang>/exceptions/<name>), each answer cut from its
# oracle (SPITBOL sbl -bf with its listing sent to a file, so a fatal's report never lands in the ref; Arizona Icon icont -s then the binary; swipl -q -t halt; fpc -Miso then the binary; Rakudo), stdout compared exactly AND THE EXIT CODE
# compared with the oracle's (a .rc file beside the .ref when the oracle exited nonzero; absent means 0): an error witness proves what was written before the error is
# flushed and that the process exits with the language's code.
# EVERY WITNESS RUNS FOUR WAYS: mode 3 and mode 4 (-d131072k -s4096k), each plain and under the collector's stress (SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=128
# SCRIP_HEAP_MAX_MB=512, the gc gates' arena): a layout defect is a root the collector cannot see, and only a collection that moves the heap shows it.
#
#   --list       print the steps and run nothing
#   --step N     grade step N: every witness four ways, then the step's probe tokens:
#                gate=name (bash name.sh rc 0) | smoke=L|ALL (test_smoke_L.sh green; ALL = the eight) | nosym=a,b (no definition or reference of the names under SCRIP/src)
#                sym=a,b (every name IS defined or referenced under SCRIP/src)
#                nofile=rel,rel (no such file under SCRIP) | grepmax=REGEX@REL:N (grep -rcE REGEX over SCRIP/REL sums to at most N; REL a file or a directory; a REGEX
#                may not contain @ or whitespace) | tsvmin=FILE:N (harness/scripts/FILE holds at least N non-comment rows) | rule5=N (SCRIP_GC_SITES_REPORT=1 --compile over
#                the gc_witnesses population and this step's witnesses: rule=5 site records at most N; a compile that fails REFUSES) | rspmoves=N (the template rsp-move
#                census: x86("push" | x86("pop" | x86("sub"/"add", "rsp" in src/templates/bb and xa, at most N) | layoutcheck=N (util_zeta_layout_check.py over the step's
#                witnesses' mode-4 asm against --dump-plan, mismatches at most N; REFUSED while the checker does not exist) | rows=L|ALL (SUITES.tsv's pass rate, today_pass over
#                today_total, not below ROWS0.tsv's pass over total; a suite with no today_total reads below; the cto CTO-507: only the finish carries it) | -
#   --cut        re-cut every witness ref from its oracle (the design seat's road; an HQ that changes a witness re-cuts it the same way)
#   --rows0      record SUITES.tsv's rows into ROWS0.tsv (the reading the rows probe compares against)
#   --out DIR    where the runs go (default a fresh /tmp/s4e/<seat>/runner_out.exceptions.<pid>.* deleted at the verdict, lib_runner_out.sh; an explicit DIR is kept)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> m3s=<pass>/<n> m4s=<pass>/<n> probe=<token:reading ...> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_one_runner.sh" && one_runner_mem_scope   # THE MEMORY DOOR (the cio 2026-11-10 12:3x): a witness at its declared heap runs in its own board scope, never in a seat's
. "$HERE/lib_paths.sh"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$S4E_SCRIP"
WD="$HERE/../designs/exceptions"   # the step table and ROWS0.tsv (CIO-56); the witnesses are staged into $ST by design_witness_stage
ST=""
GCW="$HERE/gc_witnesses"
STEPS="$WD/STEPS.tsv"
ROWS0="$WD/ROWS0.tsv"
OUT=""
SUITES=/home/resources/progress/SUITES.tsv
SBL=/home/resources/x64/bin/sbl
SMOKES="snobol4 snocone rebus icon prolog raku pascal polyglot"
STRESS_ENV="SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=128 SCRIP_HEAP_MAX_MB=512"
refuse() { echo "REFUSE(2): $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
. "$HERE/lib_design_witness.sh" || refuse "lib_design_witness.sh unloadable"
allwits() { awk -F'\t' '!/^#/ && $1 != "step" && $6 != "-" {print $6}' "$STEPS" | tr ' ' '\n' | sort -u; }
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
[ -n "$OUT" ] || { . "$HERE/lib_runner_out.sh" && runner_out_default exceptions; } || refuse "no output directory under /tmp/s4e (lib_runner_out.sh)"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
wext() { local w="$1"; for e in sno icn pl pas raku; do [ -f "$ST/$w.$e" ] && { echo "$e"; return 0; }; done; return 1; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: exceptions -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6' "$STEPS" | wc -l) steps (STEPS.tsv); witnesses the entries exceptions__<name> of their masters, else loose in corpus/tests/<lang>/exceptions (refs from SPITBOL, Arizona Icon, swipl, fpc -Miso, Rakudo)"   # one-disk: not a path
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
    T="$(mktemp -d "${TMPDIR:-/tmp}/ex_cut.XXXXXX")"
    ST="$T/wit"; design_witness_stage exceptions "$ST" $(allwits) || refuse "the witnesses did not stage (lib_design_witness.sh)"
    for w in $(awk -F'\t' '!/^#/ && $1 != "step" && $6 != "-" {print $6}' "$STEPS" | tr ' ' '\n' | sort -u); do
        e="$(wext "$w")" || refuse "witness $w has no .sno, .icn, .pl, .pas or .raku in $ST"
        D="$(awk -F'\t' -v w="$w" '$1 == w && $2 == "loose" {print $3; exit}' "$ST/.where")"
        [ -n "$D" ] || { echo "keep $w: it is the entry exceptions__$w, its answer its master's (re-cut by util_add_ladder_witness.py)"; continue; }
        case "$e" in
            sno) ( cd "$T" && timeout -k 5 120 "$SBL" -bf "-o=$T/spitbol_listing" "$D/$w.sno" < /dev/null > "$D/$w.ref" 2> "$T/$w.err" ) ;;
            icn) ( cd "$T" && "$ICONT" -s -o "$T/$w.ix" "$D/$w.icn" > "$T/$w.err" 2>&1 && timeout -k 5 120 "$T/$w.ix" < /dev/null > "$D/$w.ref" 2>> "$T/$w.err" ) ;;
            pl) ( cd "$T" && timeout -k 5 120 "$SWIPL" -q -t halt "$D/$w.pl" < /dev/null > "$D/$w.ref" 2> "$T/$w.err" ) ;;
            pas) ( cd "$T" && fpc -Miso -o"$T/$w.bin" "$D/$w.pas" > "$T/$w.err" 2>&1 && timeout -k 5 120 "$T/$w.bin" < /dev/null > "$D/$w.ref" 2>> "$T/$w.err" ) ;;
            raku) ( cd "$T" && timeout -k 5 300 "$RAKU" "$D/$w.raku" < /dev/null > "$D/$w.ref" 2> "$T/$w.err" ) ;;
        esac
        orc=$?; rm -f "$D/$w.rc"; [ "$orc" = 0 ] || echo "$orc" > "$D/$w.rc"
        echo "cut $w.ref (oracle rc $orc): $(wc -l < "$D/$w.ref") lines$(grep -qi 'error\|fatal\|warning' "$T/$w.err" && echo " (THE ORACLE COMPLAINED: $(grep -i 'error\|fatal\|warning' "$T/$w.err" | head -c 160 | tr '\n' ' '))")"
    done
    rm -rf "$T"; exit 0
fi
[ -n "$(col "$step" 1)" ] || refuse "no step $step in $STEPS (--list names them)"
slug="$(col "$step" 2)"; probe="$(col "$step" 5)"; wits="$(col "$step" 6)"
[ -x "$SC/scrip" ] || refuse "no $SC/scrip"
mkdir -p "$OUT/step$step"
if [ -z "${S4E_RUN_SLOT_HELD:-}" ]; then
    . "$HERE/lib_slots.sh"; s4e_slot_hold run || true   # the one rule (lib_slots.sh): a seat file, then a pool slot; the grader's two slots reserved
fi
declare -A pass=([m3]=0 [m4]=0 [m3s]=0 [m4s]=0)
n=0; reds=""
[ "$wits" = "-" ] && wits=""
ST="$OUT/step$step/wit"; design_witness_stage exceptions "$ST" $(allwits) || refuse "the plan's witnesses did not stage (lib_design_witness.sh: the entry exceptions__<name> of a master, or a loose pair in corpus/tests/<lang>/exceptions)"   # one-disk: not a path
run_one() { # $1 dir $2 binary-or-scrip $3 witness-file-or-empty $4 stress(0|1) -> writes $1/out, returns rc
    local d="$1" bin="$2" f="$3" s="$4" rc
    if [ "$s" = 1 ]; then ( cd "$d" && env -u SCRIP_HEAP_MB $STRESS_ENV timeout -k 5 300 "$bin" -d131072k -s4096k $f < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
    else ( cd "$d" && env -u SCRIP_HEAP_MB -u SCRIP_GC_STRESS -u SCRIP_HEAP_KB timeout -k 5 300 "$bin" -d131072k -s4096k $f < /dev/null > "$d/out" 2> "$d/err" ); rc=$?; fi
    return $rc
}
for w in $wits; do
    e="$(wext "$w")" || refuse "witness $w has no .sno, .icn, .pl, .pas or .raku in $ST"
    ref="$ST/$w.ref"; [ -f "$ref" ] || refuse "witness $w has no .ref in $ST (--cut)"
    n=$((n + 1))
    b="$OUT/step$step/$w"; rm -rf "$b.m4bin"; mkdir -p "$b.m4bin"
    if ( cd "$b.m4bin" && timeout -k 5 300 "$SC/scrip" --compile --out="$b.m4bin/run.s" "$ST/$w.$e" < /dev/null > /dev/null 2> "$b.m4bin/cerr" ) \
       && gcc -c "$b.m4bin/run.s" -o "$b.m4bin/run.o" 2> /dev/null && gcc "$b.m4bin/run.o" -L"$SC/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$SC/out" -o "$b.m4bin/run.bin" 2> /dev/null; then have4=1; else have4=0; fi
    src="$(awk -F'\t' -v w="$w" '$1 == w {print $2 " " $3; exit}' "$ST/.where")"
    for m in m3 m3s $([ "${S4E_MODE4:-0}" = 1 ] && echo m4 m4s); do
        if [ "${src%% *}" = entry ]; then   # the entry is graded by its master's one reader, which renders SCRIP's fatal block into stdout as its answer holds it (R-1344)
            case "$m" in *s) ( unset SCRIP_HEAP_MB; export $STRESS_ENV; design_witness_grade "${src#* }" "exceptions__$w" "${m%s}" ) > "$b.$m.grade" 2>&1; rc=$? ;;
                *) ( unset SCRIP_HEAP_MB SCRIP_GC_STRESS SCRIP_HEAP_KB; design_witness_grade "${src#* }" "exceptions__$w" "$m" ) > "$b.$m.grade" 2>&1; rc=$? ;; esac
            if [ "$rc" = 0 ]; then pass[$m]=$(( ${pass[$m]} + 1 )); else reds="$reds $m:$w(entry rc$rc)"; fi; continue
        fi
        d="$b.$m"; rm -rf "$d"; mkdir -p "$d"; cp "$ST/$w.$e" "$d/$w.$e"
        s=0; case "$m" in *s) s=1 ;; esac
        case "$m" in
            m3*) run_one "$d" "$SC/scrip" "$w.$e" "$s"; rc=$? ;;
            m4*) if [ "$have4" = 1 ]; then run_one "$d" "$b.m4bin/run.bin" "" "$s"; rc=$?; else rc=no-binary; fi ;;
        esac
        want=0; [ -f "$ST/$w.rc" ] && want="$(cat "$ST/$w.rc")"
        if [ "$rc" = "$want" ] && diff -q "$d/out" "$ref" > /dev/null 2>&1; then pass[$m]=$(( ${pass[$m]} + 1 )); else reds="$reds $m:$w(rc$rc,want$want)"; fi
    done
done
rule5_census() { # the gc_witnesses population plus this step's witnesses, mode-4 compile with SCRIP_GC_SITES_REPORT=1; prints the rule=5 count or REFUSED
    local d="$OUT/step$step/rule5" c=0 t f; mkdir -p "$d"; : > "$d/rules.txt"
    for f in "$GCW"/*.sno "$GCW"/*.icn "$GCW"/*.pl "$GCW"/*.pas "$GCW"/*.raku "$GCW"/*.sc; do
        [ -f "$f" ] || continue
        ( cd "$d" && SCRIP_GC_SITES_REPORT=1 timeout -k 2 120 "$SC/scrip" --compile --out="$d/x.s" "$f" < /dev/null 2> "$d/rep" > /dev/null ) || { echo "REFUSED($(basename "$f"))"; return; }
        t="$(grep -c 'rule=5 ' "$d/rep")"; c=$((c + t)); [ "$t" -gt 0 ] && echo "$(basename "$f") $t" >> "$d/rules.txt"
    done
    for w in $wits; do f="$ST/$w.$(wext "$w")"
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
        ( cd "$b.m4bin" && timeout -k 5 300 "$SC/scrip" --dump-plan "$ST/$w.$(wext "$w")" < /dev/null > "$b.m4bin/plan.txt" 2> /dev/null ) || { echo REFUSED; return; }
        t="$(python3 -I "$chk" --asm "$b.m4bin/run.s" --plan "$b.m4bin/plan.txt" 2> "$b.m4bin/check.err" | tail -1 | sed -n 's/.*mismatches=\([0-9]*\).*/\1/p')"
        [ -n "$t" ] || { echo REFUSED; return; }; c=$((c + t))
    done
    echo "$c"
}
readings=""; pgreen=1
[ "$probe" = "-" ] && probe=""
for tok in $probe; do
    key="${tok%%=*}"; val="${tok#*=}"
    case "$key" in
        nosym) bad=0; for s in ${val//,/ }; do grep -rqw -- "$s" "$SC/src" && bad=$((bad + 1)); done; readings="$readings nosym_present=$bad"; [ "$bad" = 0 ] || pgreen=0 ;;
        sym) bad=0; for s in ${val//,/ }; do grep -rqw -- "$s" "$SC/src" || bad=$((bad + 1)); done; readings="$readings sym_missing=$bad"; [ "$bad" = 0 ] || pgreen=0 ;;
        nofile) bad=0; for s in ${val//,/ }; do [ -e "$SC/$s" ] && bad=$((bad + 1)); done; readings="$readings files_present=$bad"; [ "$bad" = 0 ] || pgreen=0 ;;
        grepmax) re="${val%%@*}"; rest="${val#*@}"; rel="${rest%%:*}"; lim="${rest##*:}"
            [ -e "$SC/$rel" ] || refuse "grepmax: no $SC/$rel"
            c="$(grep -rhoE -- "$re" "$SC/$rel" | wc -l)"; readings="$readings grep[$re@$rel]=$c(at_most $lim)"; [ "$c" -le "$lim" ] || pgreen=0 ;;
        tsvmin) f="${val%%:*}"; lim="${val##*:}"; if [ -f "$HERE/$f" ]; then c="$(grep -cv '^#' "$HERE/$f")"; else c=0; fi; readings="$readings tsv[$f]=$c(at_least $lim)"; [ "$c" -ge "$lim" ] || pgreen=0 ;;
        rule5) c="$(rule5_census)"; case "$c" in REFUSED*) refuse "rule5: a program of the population did not compile: $c" ;; esac
            readings="$readings rule5_sites=$c(at_most $val)"; [ "$c" -le "$val" ] || pgreen=0 ;;
        rspmoves) c="$(rspmoves_census)"; readings="$readings template_rsp_moves=$c(at_most $val)"; [ "$c" -le "$val" ] || pgreen=0 ;;
        layoutcheck) c="$(layoutcheck)"; [ "$c" = REFUSED ] && refuse "layoutcheck: util_zeta_layout_check.py, a witness binary or its plan dump is missing (step 2 writes the checker)"
            readings="$readings layout_mismatches=$c(at_most $val)"; [ "$c" -le "$val" ] || pgreen=0 ;;
        gate) [ -f "$HERE/$val.sh" ] || { readings="$readings gate[$val]=missing"; pgreen=0; continue; }
            if ( cd "$SC" && timeout -k 10 1800 bash "$HERE/$val.sh" > "$OUT/step$step/$val.log" 2>&1 ); then readings="$readings gate[$val]=green"; else readings="$readings gate[$val]=red"; pgreen=0; fi ;;
        smoke) [ "$val" = ALL ] && ls="$SMOKES" || ls="${val//,/ }"
            for l in $ls; do if ( cd "$SC" && timeout -k 10 900 bash "$HERE/test_smoke_$l.sh" > "$OUT/step$step/smoke_$l.log" 2>&1 ); then readings="$readings smoke[$l]=green"; else readings="$readings smoke[$l]=red"; pgreen=0; fi; done ;;
        rows) [ -r "$SUITES" ] || refuse "no $SUITES"; [ -r "$ROWS0" ] || refuse "no $ROWS0 (--rows0 records it)"
            [ "$val" = ALL ] && ls="icon pascal prolog raku rebus scriptix snobol4 snocone" || ls="${val//,/ }"
            short=""
            for l in $ls; do
                short="$short$(awk -F'\t' -v L="$l" 'FNR == NR { if (FNR > 1 && $2 == L) { r[$1] = $3; t[$1] = $4 } next } FNR == 2 { for (i = 1; i <= NF; i++) h[$i] = i } FNR > 2 && $4 == L && ($1 in r) && t[$1] + 0 > 0 { p = $(h["today_pass"]) + 0; n = $(h["today_total"]) + 0; if (n <= 0 ? r[$1] + 0 > 0 : p * (t[$1] + 0) < (r[$1] + 0) * n) printf "%s %s/%s<%s/%s ", $1, p, n, r[$1], t[$1] }' "$ROWS0" "$SUITES")"
            done
            bad="$(printf '%s' "$short" | wc -w)"; readings="$readings rows_below=$bad[${short% }]"; [ "$bad" = 0 ] || pgreen=0 ;;
        *) refuse "unknown probe token $tok in step $step" ;;
    esac
done
verdict=GREEN; for m in m3 m3s $([ "${S4E_MODE4:-0}" = 1 ] && echo m4 m4s); do [ "${pass[$m]}" = "$n" ] || verdict=RED; done; [ "$pgreen" = 1 ] || verdict=RED
echo "STEP $step $slug: m3=${pass[m3]}/$n m4=${pass[m4]}/$n m3s=${pass[m3s]}/$n m4s=${pass[m4s]}/$n probe=${readings# } -> $verdict${reds:+ reds:$reds}"
[ "$verdict" = GREEN ] && exit 0 || exit 1
