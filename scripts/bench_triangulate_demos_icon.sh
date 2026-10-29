#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_triangulate_demos_icon.sh -- THREE-ANGLE TRIANGULATION FOR THE **ICON DEMO** PROGRAMS.
# Minted 2026-09-03 by hq_B for row `jcon-compiler-is-a-major-demo-with-benchmark-numbers-in-the-readme`
# (Lon, in-chat to ceo ~15:32: "getting the JCON's compiler written in Icon as one of the major demos
# with benchmark numbers for SCRIP's README"). Law: RULES.md § THE TWO-NUMBER BENCHMARK BASIS (three
# angles) and ARCH-BENCH-CAMPAIGN-README-TABLES.md § THREE-ANGLE TRIANGULATION.
# Modelled line-for-line on bench_triangulate_demos_snobol4.sh -- the WHOLE-PROGRAM sibling. Read that
# script's header for why demo totals and kernel slopes are different instruments.
#
# ⛔⭐ WHY THIS EXISTS AS A SEPARATE SCRIPT FROM bench_icon_rate_3way.sh. That script is a KERNEL rate
# harness: its programs read their own &time and loop internally, so it reports a SLOPE with startup
# divided away, and it only implements angle 1 (fixed-time). A JCON demo has no such entry point --
# interfacegen emits its table once and exits. So one "iteration" here is ONE WHOLE PROGRAM RUN and
# every number is a **TOTAL** carrying process startup AND, for m3, the compile.
# ⛔ FACT RULE CONSEQUENCE: a demo total may NEVER share a column, grid or sentence with a kernel
# slope. The basis is printed in this script's own header line so a pasted table cannot lose it.
#
# THE THREE ANGLES, on a whole-program unit:
#   Angle 1 -- TIME-mode : fixed wall-clock budget; count COMPLETED RUNS -> runs/s.
#   Angle 2 -- ITER-mode : fixed RUN COUNT (REPS_A2); measure total external CPU -> runs/s.
#   Angle 3 -- TELEMETRY : tools/bench_rusage wraps every arm -- cpu(user+sys), elapsed, inblock/oublock.
#   CROSS-PROVE OR VOID: angle 1 and angle 2 must land within TOL_PCT per (demo, engine), else the row
#   is marked NOT CITABLE. Disagreement does not delete the readings and does not stop the run.
#
# ⛔⭐ WORK vs OVERHEAD (RULES.md's two-number basis). SCRIP Icon has no `wall_ms` hook and these are
# UNMODIFIED upstream JCON sources -- instrumenting them would make the demo something other than JCON.
# So this script uses the law's explicitly-marked interim: EMPTY-PROGRAM SUBTRACTION. It times a
# do-nothing Icon program on each engine and reports that as OVERHEAD, with WORK = total - overhead.
# ⛔ That basis is STATED IN THE GRID, never silently mixed with self-timed arms.
#
# ⛔⭐ CORRECTNESS GATES THE NUMBER, AND EXIT STATUS IS NOT THE GATE. The gate is cross-engine OUTPUT
# agreement against iconx; a mismatch VOIDs the row and NO MULTIPLE IS PRINTED. (This is not defensive
# boilerplate: it is why oplexgen -- which differs from the oracle only in key(table) ORDER, same 611
# lines -- gets timings but no multiple. A wrong answer is never a fast answer.)
# ⭐ Some demos answer on stderr (jlink); the oracle picks the stream once, as in test_demo_icon_jcon.sh.
#
# ⛔ RT_OPT IS -O0 AND THERE IS NO -O2 ARM (Lon s262 FACT RULE; Makefile:34). Its sibling
# bench_icon_rate_3way.sh carried the VOID instruction "build SCRIP with -O2 before running" until
# 2026-09-03 (ceo CEO-173); that header is now retired and this cross-reference is kept only so the
# next reader knows the sibling was fixed, not that it still needs fixing.
#
# EXIT: 0 = every measured row AGREE. 1 = at least one DISAGREE/VOID/UNPROVEN (grid still printed).
#       2 = REFUSED (scrip unbuilt, icont/iconx missing, bench_rusage stale, demo corpus gone).
# USAGE: bash ../harness/scripts/bench_triangulate_demos_icon.sh [--out FILE] [name ...]
#        BUDGET_MS=3000 REPS_A2=5 TOL_PCT=15 ENGINES="iconx m3 m4"
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="$ROOT/out"
D="${JCON_DEMO_DIR:-$S4E/corpus/demos/icon/jcon}"
PKG="${JCON_PKG_DIR:-$S4E/corpus/packages/icon/jcon-compiler}"
TOL="${TOL_PCT:-15}"; BUDGET_MS="${BUDGET_MS:-3000}"; REPS_A2="${REPS_A2:-5}"
ENGINES="${ENGINES:-iconx m3 m4}"; OUT=""
ARGS_LEFT=""
while [ $# -gt 0 ]; do case "$1" in --out) OUT="$2"; shift;; *) ARGS_LEFT="$ARGS_LEFT $1";; esac; shift; done

refuse() { echo "⛔ ICON DEMO TRIANGULATION REFUSED(2): $*" >&2; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "cannot load lib_oracle_flags.sh -- the ONE oracle-path authority (s200)."
. "$HERE/lib_perf_fmt.sh"     2>/dev/null || refuse "cannot load lib_perf_fmt.sh -- the ONE authority for printing a multiple (s266)."
. "$HERE/lib_icon_ipl_isolation.sh" 2>/dev/null || refuse "cannot load lib_icon_ipl_isolation.sh -- the ONE argv-sidecar reader."
. "$HERE/lib_declared_arena.sh" 2>/dev/null || refuse "cannot load lib_declared_arena.sh -- the ONE declared-size reader."
ICONT="$(icont_bin)" || refuse "the Arizona icont oracle is missing. ⛔ Not a \`command -v\` verdict -- the oracles are not on PATH."
[ -x "$SCRIP" ] || refuse "scrip not built ($SCRIP) -- a table printed without it would be plausible and false."
[ -d "$D" ] || refuse "Icon demo corpus missing ($D)."
[ -d "$PKG" ] || refuse "JCON package missing ($PKG)."
WRAP="$ROOT/tools/bench_rusage"
[ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || refuse "bench_rusage failed to build."
"$WRAP" true 2>&1 | grep -q 'inblock=' || refuse "$WRAP predates the inblock/oublock fields -- angle 3 would report empty. Rebuild it."

W="$(mktemp -d "${TMPDIR:-/tmp}/icondemo3a.XXXXXX")" || refuse "cannot make a work dir."
trap 'rm -rf "$W"' EXIT
[ -d "$D/inputs" ] && cp -r "$D/inputs" "$W/" 2>/dev/null

entry_modules() { sed -n 's/^[[:space:]]*link[[:space:]]*"\([^"]*\)".*$/\1/p' "$1" | sed 's|.*/||'; }

# ---- ONE run. echoes: cpu_ms elapsed_ms inblock oublock rc <TAB> output-digest ----------------
run1() {                               # $1=engine $2=stem $3=args $4=stream
    local eng="$1" stem="$2" a="$3" stream="$4" out rl u s el ib ob rc
    # ⛔ stderr-answer programs share a stream with the wrapper. bench_rusage writes its own
    # BENCH_RUSAGE: line to stderr, so for STREAM=stderr the program's answer and the telemetry
    # arrive interleaved in ONE file -- capturing `2>&1` would fold the timing line into the answer
    # digest and make every run look different. So stderr always lands in e.err, and for a
    # stderr-answering demo the ANSWER is e.err with the BENCH_RUSAGE lines filtered back out.
    case "$eng" in
      iconx) out=$( cd "$W" && "$WRAP" timeout -k 5 300 "./$stem.oracle" $a </dev/null 2>"$W/e.err" ) ;;
      m3)    out=$( cd "$D" && "$WRAP" timeout -k 5 300 "$SCRIP" $SWN "$D/$stem.icn" ${a:+-- $a} </dev/null 2>"$W/e.err" ) ;;
      m4)    [ -x "$W/$stem.m4bin" ] || { echo "- - - - BUILD-ERR	BUILD-ERR"; return; }
             out=$( cd "$D" && "$WRAP" timeout -k 5 300 "$W/$stem.m4bin" $SWN ${a:+-- $a} </dev/null 2>"$W/e.err" ) ;;
    esac
    [ "$stream" = stderr ] && out="$(grep -v '^BENCH_RUSAGE:' "$W/e.err")"
    rl=$(grep '^BENCH_RUSAGE:' "$W/e.err" | tail -1)
    [ -n "$rl" ] || { echo "- - - - CRASH	CRASH"; return; }
    u=$(grep -oE 'user_us=[0-9]+' <<<"$rl"|cut -d= -f2); s=$(grep -oE 'sys_us=[0-9]+' <<<"$rl"|cut -d= -f2)
    el=$(grep -oE 'elapsed_ns=[0-9]+' <<<"$rl"|cut -d= -f2)
    ib=$(grep -oE 'inblock=[0-9]+' <<<"$rl"|cut -d= -f2); ob=$(grep -oE 'oublock=[0-9]+' <<<"$rl"|cut -d= -f2)
    rc=$(grep -oE 'exit=[0-9]+' <<<"$rl"|cut -d= -f2)
    local dg; dg=$(printf '%s' "$out" | md5sum | cut -c1-12); [ -n "$out" ] || dg="EMPTY"
    awk -v u="${u:-0}" -v s="${s:-0}" -v e="${el:-0}" -v i="${ib:-0}" -v o="${ob:-0}" -v r="${rc:-?}" -v d="$dg" \
        'BEGIN{printf "%.2f %.2f %s %s %s\t%s\n",(u+s)/1000,e/1000000,i,o,r,d}'
}
angle1() {                             # fixed TIME budget -> runs_per_s runs cpu_ms digest
    local t0 now n=0 cpu=0 dg="" r c
    t0=$(date +%s%N)
    while :; do
        r=$(run1 "$1" "$2" "$3" "$4"); c=$(awk '{print $1}' <<<"$r")
        [ "$c" = "-" ] && { echo "- 0 - $(cut -f2 <<<"$r")"; return; }
        n=$((n+1)); cpu=$(awk -v a="$cpu" -v b="$c" 'BEGIN{print a+b}'); dg=$(cut -f2 <<<"$r")
        now=$(date +%s%N); [ $(( (now-t0)/1000000 )) -ge "$BUDGET_MS" ] && break
    done
    awk -v n="$n" -v c="$cpu" -v d="$dg" 'BEGIN{printf "%.4f %d %.2f %s",(c>0)?n/(c/1000):0,n,c,d}'
}
angle2() {                             # fixed RUN count -> runs_per_s runs cpu_ms digest ib ob elapsed
    local i n=0 cpu=0 dg="" ib=0 ob=0 el=0 r c
    for ((i=0;i<REPS_A2;i++)); do
        r=$(run1 "$1" "$2" "$3" "$4"); c=$(awk '{print $1}' <<<"$r")
        [ "$c" = "-" ] && { echo "- 0 - $(cut -f2 <<<"$r") 0 0 0"; return; }
        n=$((n+1)); cpu=$(awk -v a="$cpu" -v b="$c" 'BEGIN{print a+b}')
        el=$(awk -v a="$el" -v b="$(awk '{print $2}' <<<"$r")" 'BEGIN{print a+b}')
        ib=$(awk '{print $3}' <<<"$r"); ob=$(awk '{print $4}' <<<"$r"); dg=$(cut -f2 <<<"$r")
    done
    awk -v n="$n" -v c="$cpu" -v d="$dg" -v i="$ib" -v o="$ob" -v e="$el" \
        'BEGIN{printf "%.4f %d %.2f %s %s %s %.2f",(c>0)?n/(c/1000):0,n,c,d,i,o,e}'
}
# ---- OVERHEAD, the marked interim: empty-program subtraction, per engine ----------------------
printf 'procedure main()\nend\n' > "$W/empty.icn"
( cd "$W" && "$ICONT" -o empty.oracle empty.icn ) >/dev/null 2>&1 || refuse "icont could not build the empty-program overhead probe."
"$SCRIP" --compile --out="$W/empty.s" "$W/empty.icn" </dev/null >/dev/null 2>&1 \
  && as --64 -o "$W/empty.o" "$W/empty.s" 2>/dev/null \
  && gcc -no-pie -o "$W/empty.m4bin" "$W/empty.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null \
  || refuse "could not build the empty-program overhead probe under SCRIP m4."
declare -A OVH
for e in $ENGINES; do
    tot=0; for i in 1 2 3 4 5; do
        case "$e" in
          iconx) r=$( cd "$W" && "$WRAP" ./empty.oracle </dev/null 2>&1 >/dev/null ) ;;
          m3)    r=$( "$WRAP" "$SCRIP" "$W/empty.icn" </dev/null 2>&1 >/dev/null ) ;;
          m4)    r=$( "$WRAP" "$W/empty.m4bin" </dev/null 2>&1 >/dev/null ) ;;
        esac
        u=$(grep -oE 'user_us=[0-9]+' <<<"$r"|cut -d= -f2); s=$(grep -oE 'sys_us=[0-9]+' <<<"$r"|cut -d= -f2)
        tot=$(awk -v a="$tot" -v u="${u:-0}" -v s="${s:-0}" 'BEGIN{print a+(u+s)/1000}')
    done
    OVH[$e]=$(awk -v t="$tot" 'BEGIN{printf "%.2f",t/5}')
done

[ -n "$OUT" ] || OUT="$W/icon-demo-triangulation.tsv"
echo "THREE-ANGLE DEMO TRIANGULATION -- JCON (Icon) demo programs"
echo "⛔ BASIS: one iteration = ONE WHOLE PROGRAM RUN. Every number is a TOTAL carrying process startup"
echo "   (and, for m3, the compile) -- NOT a kernel slope. Never share a column with bench_icon_rate_3way.sh."
echo "⛔ OVERHEAD BASIS: EMPTY-PROGRAM SUBTRACTION (the marked interim of RULES.md § THE TWO-NUMBER"
echo "   BENCHMARK BASIS) -- these are unmodified upstream JCON sources with no wall_ms hook. WORK = total - overhead."
echo "instrument: tools/bench_rusage external cpu(user+sys); engines: $ENGINES; budget(a1)=${BUDGET_MS}ms; reps(a2)=$REPS_A2; tol=${TOL}%"
echo "oracle: $ICONT / iconx (Arizona v9.5.25a); RT_OPT=-O0 (no -O2 build exists)"
echo "trees: SCRIP $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)  corpus $(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null)"
for e in $ENGINES; do echo "overhead(empty program, $e): ${OVH[$e]} ms cpu"; done
# ⛔ THE GRID OPENS HERE so no multiple below can print without the load it ran under, and so a cell that
# REFUSES is counted in THIS shell (perf_row is called directly, never inside $( ) -- arm G of the dark-cell gate).
perf_grid_begin "demo vs iconx -- x on the FASTER axis (iconx/ours) · TOTAL basis, whole-program run incl startup · WORK basis = total - empty-program overhead · instrument tools/bench_rusage cpu(user+sys) · RT_OPT=-O0"
echo
printf "%-14s %-6s %11s %11s %8s %-9s %9s %9s %s\n" DEMO ENGINE "a1 runs/s" "a2 runs/s" ratio VERDICT "total ms" "work ms" answer
printf '%s\n' "----------------------------------------------------------------------------------------------------"
: > "$OUT"
printf '# icon-demo-triangulation -- basis=WHOLE-PROGRAM-RUN (total, incl startup); overhead=empty-program subtraction\n' >> "$OUT"
printf 'demo\tengine\ta1_runs_per_s\ta2_runs_per_s\tratio\tverdict\ttotal_cpu_ms\twork_ms\toverhead_ms\tinblock\toublock\tanswer_digest\n' >> "$OUT"

RC=0; ROWS=0; SWN=""
for E in "$D"/*.icn; do
    [ -f "$E" ] || continue
    N="$(basename "$E" .icn)"
    [ -n "${ARGS_LEFT// /}" ] && ! grep -qw "$N" <<<"$ARGS_LEFT" && continue
    # ⭐ ARGV FROM THE ONE READER (ipl_argv_read, NAME.argv): this read NAME.args, a spelling the corpus retired for jtran.argv on 09-12
    # (CEO-609), so jtran ran with no argv on every engine. SIZES: NAME.heap and NAME.stack as switches on the SCRIP engines (CEO-1353).
    declare -a AV=(); ipl_argv_read "$E" AV; [ $? -eq 2 ] && { echo "⛔ UNPROVEN $N -- $N.argv is malformed (the reader said why above)"; RC=1; continue; }
    A="${AV[*]}"
    SWN="$(declared_switches_beside "$E")" || { echo "⛔ UNPROVEN $N -- $N.heap or $N.stack is malformed (the reader said why above)"; RC=1; continue; }
    [ -n "$SWN" ] || echo "    $N: declares no heap and stack beside it -- the SCRIP engines run at the shipped default, NAMED"
    MODS=""; ok=1
    for m in $(entry_modules "$E"); do
        [ -f "$PKG/$m.icn" ] || { echo "⛔ UNPROVEN $N -- entry links '$m' but $PKG/$m.icn is absent; NAMED, not dropped."; ok=0; break; }
        cp "$PKG/$m.icn" "$W/"; MODS="$MODS $m.icn"; done
    [ "$ok" = 1 ] && [ -n "$MODS" ] || { RC=1; continue; }
    ( cd "$W" && "$ICONT" -o "$N.oracle" $MODS ) >/dev/null 2>&1 \
        || { echo "⛔ UNPROVEN $N -- icont refused to build the oracle."; RC=1; continue; }
    ( cd "$D" && "$SCRIP" --compile --out="$W/$N.s" "$E" </dev/null ) >/dev/null 2>&1 \
        && as --64 -o "$W/$N.o" "$W/$N.s" 2>/dev/null \
        && gcc -no-pie -o "$W/$N.m4bin" "$W/$N.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null || rm -f "$W/$N.m4bin"
    # the oracle picks the answer stream, once, for every arm
    o1=$( cd "$W" && timeout -k 5 300 "./$N.oracle" $A </dev/null 2>"$W/$N.oe" ); STREAM=stdout
    [ -z "$o1" ] && [ -s "$W/$N.oe" ] && STREAM=stderr
    declare -A A1 A2 DG CPU IB OB
    for e in $ENGINES; do
        r1=$(angle1 "$e" "$N" "$A" "$STREAM"); r2=$(angle2 "$e" "$N" "$A" "$STREAM")
        A1[$e]=$(awk '{print $1}' <<<"$r1"); A2[$e]=$(awk '{print $1}' <<<"$r2")
        DG[$e]=$(awk '{print $4}' <<<"$r2")
        CPU[$e]=$(awk -v c="$(awk '{print $3}' <<<"$r2")" -v n="$(awk '{print $2}' <<<"$r2")" 'BEGIN{print (n>0)?c/n:0}')
        IB[$e]=$(awk '{print $5}' <<<"$r2"); OB[$e]=$(awk '{print $6}' <<<"$r2")
    done
    for e in $ENGINES; do
        a1="${A1[$e]:--}"; a2="${A2[$e]:--}"; d="${DG[$e]:-CRASH}"
        if [ "$a1" = "-" ] || [ "$a2" = "-" ]; then v="UNPROVEN"; ratio="-"
        else ratio=$(awk -v a="$a1" -v b="$a2" 'BEGIN{m=(a>b)?a:b;n=(a<b)?a:b;printf "%.4f",(n>0)?m/n:0}')
             v=$(awk -v r="$ratio" -v t="$TOL" 'BEGIN{print ((r-1)*100<=t)?"AGREE":"DISAGREE"}'); fi
        [ -n "${DG[iconx]:-}" ] && [ "$d" != "${DG[iconx]}" ] && v="VOID-ANSWER"
        case "$d" in EMPTY|CRASH|BUILD-ERR) v="VOID-$d";; esac
        case "$v" in AGREE) ;; *) RC=1;; esac
        wk=$(awk -v c="${CPU[$e]:-0}" -v o="${OVH[$e]:-0}" 'BEGIN{printf "%.2f",(c-o>0)?c-o:0}')
        printf "%-14s %-6s %11s %11s %8s %-9s %9s %9s %s\n" "$N" "$e" "$a1" "$a2" "$ratio" "$v" "${CPU[$e]:--}" "$wk" "$d"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$N" "$e" "$a1" "$a2" "$ratio" "$v" "${CPU[$e]:--}" "$wk" "${OVH[$e]:--}" "${IB[$e]:--}" "${OB[$e]:--}" "$d" >> "$OUT"
    done
    # ---- the published multiple: only when both sides answered, and answered THE SAME ----------
    if [ -z "${CPU[iconx]:-}" ] || [ "${CPU[iconx]}" = "0" ] || [ "${DG[iconx]:-EMPTY}" = "EMPTY" ]; then
        echo "    ⛔ $N: NO ORACLE COLUMN -- iconx produced no usable answer. No multiple; nothing to be a multiple OF."
    else
        for e in m3 m4; do
            [ -n "${CPU[$e]:-}" ] || continue
            if [ "${CPU[$e]}" = "0" ] || [ "${CPU[$e]}" = "-" ]; then echo "    ⛔ $N $e: no usable timing -- NO MULTIPLE."
            elif [ "${DG[$e]:-}" != "${DG[iconx]}" ]; then
                echo "    ⛔ $N $e: ANSWER DIVERGES FROM THE ORACLE (${DG[$e]:-none} vs ${DG[iconx]}) -- NO MULTIPLE IS PRINTED. A wrong answer is never a fast answer."
            else
                wo=$(awk -v c="${CPU[iconx]}" -v o="${OVH[iconx]:-0}" 'BEGIN{printf "%.4f",(c-o>0)?c-o:0.0001}')
                we=$(awk -v c="${CPU[$e]}"    -v o="${OVH[$e]:-0}"    'BEGIN{printf "%.4f",(c-o>0)?c-o:0.0001}')
                # ⛔⭐ THE SUBTRACTION HAS TO SURVIVE ITS OWN ERROR BARS, AND ON THESE DEMOS IT OFTEN
                # DOES NOT. WORK = total - overhead is a difference of two similar numbers: measured
                # 2026-09-03 on interfacegen, iconx total 4.99ms against a 4.10ms empty-program
                # overhead leaves 0.89ms of "work" -- 82% of the reading is startup, so a few percent
                # of noise on either term moves the multiple by tens of percent. It is worse than
                # noisy, it INVERTS: on totals m4 (3.93ms) beats iconx (4.99ms), while the same run
                # on the work basis reports m4 at 0.465x, i.e. slower. Both cannot be true, and
                # neither belongs in a README. So when startup dominates either arm the work
                # multiple is REFUSED and the total-basis multiple is printed in its place, labelled
                # -- never both, and never the work number with a quiet asterisk.
                ofr=$(awk -v o="${OVH[iconx]:-0}" -v c="${CPU[iconx]}" -v oe="${OVH[$e]:-0}" -v ce="${CPU[$e]}" \
                        'BEGIN{a=(c>0)?o/c:1; b=(ce>0)?oe/ce:1; print ((a>=0.5)||(b>=0.5))?"DOM":"OK"}')
                if [ "$ofr" = DOM ]; then
                    echo "    ⛔ $N $e: WORK MULTIPLE REFUSED -- process startup is >=50% of the reading on at least one arm (overhead iconx=${OVH[iconx]}ms of ${CPU[iconx]}ms, $e=${OVH[$e]}ms of ${CPU[$e]}ms), so total-minus-overhead is dominated by its own error bars."
                    perf_row "  $N $e vs iconx (TOTAL basis -- startup INCLUDED, not the two-number work basis)" "${CPU[iconx]}" "${CPU[$e]}"
                else
                    perf_row "  $N $e vs iconx (WORK basis)" "$wo" "$we"
                fi
            fi
        done
    fi
    unset A1 A2 DG CPU IB OB; ROWS=$((ROWS+1)); echo
done
perf_grid_end || RC=1
echo "rows measured: $ROWS   TSV: $OUT"
[ "$ROWS" -gt 0 ] || refuse "no demo rows measured -- a grid of nothing is not a measurement."
[ "$RC" = 0 ] && echo "✅ every measured row AGREE across angle 1 and angle 2." \
              || echo "⛔ at least one row DISAGREE/VOID/UNPROVEN -- those rows are NOT CITABLE. Raw readings kept above."
exit $RC
