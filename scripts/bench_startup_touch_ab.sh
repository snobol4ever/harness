#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_startup_touch_ab.sh -- THE MATCHED TWO-ARM A/B FOR THE `-ffunction-sections` + LINK-ORDERING LEVER ON THE RT .so.
# Row rtx-startup-linker-ordering (hq_P, 2026-09-04, FLEET-16). Its DONE-WHEN is this script exiting 0.
#
# THE QUESTION: does clustering the startup-executed functions of libscrip_rt.so at the front of .text lower the
# page-touch floor every SCRIP program pays before doing any work (Aspect 1, FINDING-2026-08-28-hq_P-aspect1-...)?
# The graded metrics are MINOR FAULTS and MAX RSS of a do-nothing witness -- pages spanned is an upper bound, never
# a fault saving (seat07, 2026-09-01: relocations moved -14.26% and faults -0.78% one rung earlier).
#
# ⛔ THE TWO TRAPS THIS SCRIPT EXISTS TO MAKE IMPOSSIBLE (both measured, both in the row's GOAL):
#   1. CROSS-TREE SUBTRACTION. seat14 measured arm A at 248.9 faults on one tree; seat01 and seat07 measured 743.6 on
#      another; subtracting across them manufactures a ~495-fault "saving" out of a tree difference. HERE BOTH ARMS ARE
#      BUILT AND MEASURED ON ONE TREE, BY ONE PROCESS, WITH ONE INSTRUMENT, and every number carries its label.
#   2. `-ffunction-sections` ALONE IS NOT THE A/B. The flag only splits .text per function; the lever is the GNU ld
#      fragment that ORDERS those sections. A flag-only arm reads ~zero (or worse, via padding) and would retire the
#      lever falsely. Arm B here is flag PLUS ordering. The flag-only build is printed too, LABELLED as a control (B0),
#      because it isolates the split's own padding cost -- it is never the headline.
#
# THE ARMS (same tree, same driver object, same witness, same instrument):
#   A  : the tree's own RT build (RT_OPT as `make buildinfo` reports it; NO -O2, ever -- s262 FACT RULE).
#   B0 : RT_OPT + -ffunction-sections, linked by the Makefile's own recipe (its own RT_TAG, so arm A's objects and .so
#        are untouched and the canonical out/libscrip_rt.so symlink is never re-pointed).
#   B  : B0's objects relinked with an ordering fragment (-Wl,-T,order.ld, INSERT BEFORE .text) that pulls every
#        function callgrind saw EXECUTE in the .so on the witness into one contiguous output section .text.startup_hot.
#        The executed set is DERIVED HERE, on arm A, by callgrind (--demangle=no so names match section names) --
#        never inherited from a FINDING, so it cannot go stale.
#   Each arm gets its OWN driver binary linked against its OWN directory (RUNPATH), verified with ldd, so no arm can
#   silently run against another arm's .so. LD_LIBRARY_PATH is unset for the same reason.
#
# EXIT CODES (lib_gate.sh convention): 0 = MEASURED (a GAIN verdict and a NO-GAIN verdict are BOTH green: the row
# asked for the number, not for the lever to win) · 1 = the lever BREAKS the witness (wrong output / non-zero rc on
# any arm) · 2 = REFUSED, could not measure (missing tool, build failure, non-numeric instrument reading, empty hot
# section). A board that cannot fail is the shape the instrument laws exist to stop, so every refusal names itself.
#
# USAGE  bash ../harness/scripts/bench_startup_touch_ab.sh            (from any cwd)
#        RUNS=7 WITNESS=/path/prog.sno KEEP=1 bash ../harness/scripts/bench_startup_touch_ab.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_perf_fmt.sh" 2>/dev/null || { echo "⛔ REFUSE(2): cannot load $HERE/lib_perf_fmt.sh -- the one authority for printing a multiple"; exit 2; }
refuse() { printf '⛔ REFUSE(2): %s\n' "$*" >&2; exit 2; }
red()    { printf '⛔ RED(1): %s\n' "$*" >&2; exit 1; }
RUNS="${RUNS:-7}"; case "$RUNS" in ''|*[!0-9]*) refuse "RUNS must be a positive integer, got '$RUNS'";; esac
[ "$RUNS" -ge 3 ] || refuse "RUNS=$RUNS is below 3 -- a mean of fewer than three runs hides its own spread"
for t in make gcc g++ valgrind readelf ldd md5sum awk python3; do command -v "$t" >/dev/null 2>&1 || refuse "tool '$t' not on PATH"; done
[ -x /usr/bin/time ] || refuse "/usr/bin/time (GNU time, the %R/%M instrument) is missing"
SETARCH=""; command -v setarch >/dev/null 2>&1 && setarch -R true 2>/dev/null && SETARCH="setarch -R"
unset LD_LIBRARY_PATH LD_PRELOAD
cd "$ROOT" || refuse "cannot cd to $ROOT"
T="$(mktemp -d "${TMPDIR:-/tmp}/startup_ab.$$.XXXXXX")" || refuse "mktemp failed"
[ "${KEEP:-0}" = "1" ] && echo "# scratch kept at $T" || trap 'rm -rf "$T"' EXIT
mkdir -p "$T/armA" "$T/armB0" "$T/armB"
# ---- the witness: the do-nothing program, embedded so the instrument has no corpus dependency ----------------------
if [ -n "${WITNESS:-}" ]; then [ -f "$WITNESS" ] || refuse "WITNESS=$WITNESS does not exist"; W="$WITNESS"; WLABEL="$WITNESS"
else W="$T/w.sno"; printf '\tOUTPUT = 1\nEND\n' > "$W"; WLABEL="embedded do-nothing (OUTPUT = 1 / END)"; fi
# ---- arm A: the tree's own build, incremental make (never a stale binary; never pristine -- Lon 2026-09-03) --------
make -s scrip >"$T/makeA.log" 2>&1 || { tail -5 "$T/makeA.log" >&2; refuse "incremental make of arm A failed"; }
bi() { make -s buildinfo "$@" 2>/dev/null; }
OPT_A="$(bi | sed -n 's/^RT_OPT *: *//p' | sed 's/[[:space:]]*$//')"
TAG_A="$(bi | sed -n 's/^RT_TAG *: *//p' | tr -d '[:space:]')"
OBJ_DIR="$(bi | sed -n 's/^compiler *: *//p' | awk '{print $1}')"
[ -n "$OPT_A" ] && [ -n "$TAG_A" ] && [ -d "$OBJ_DIR" ] || refuse "could not read RT_OPT / RT_TAG / compiler objdir from make buildinfo"
case "$OPT_A" in *-O2*) refuse "arm A's RT_OPT carries -O2 ($OPT_A) -- NO -O2 BUILDS, EVER (s262 FACT RULE)";; esac
SO_A="out/libscrip_rt-$TAG_A.so"; [ -f "$SO_A" ] || refuse "arm A's .so is missing: $SO_A"
[ -f "$OBJ_DIR/scrip_driver.o" ] || refuse "driver object missing: $OBJ_DIR/scrip_driver.o"
cp -p "$ROOT/$SO_A" "$T/armA/libscrip_rt.so"
link_driver() { g++ -m64 -no-pie -rdynamic "$OBJ_DIR/scrip_driver.o" -Wl,-rpath,"$1" -L"$1" -lscrip_rt -lm -lpthread -o "$1/scrip" 2>"$T/ld.err" || { cat "$T/ld.err" >&2; refuse "linking the $2 driver failed"; }
  ldd "$1/scrip" | grep -q "libscrip_rt.so => $1/libscrip_rt.so" || { ldd "$1/scrip" | grep libscrip_rt >&2; refuse "$2 driver does not resolve its OWN .so -- the arm would measure the wrong object"; }; }
link_driver "$T/armA" "arm A"
# ---- derive the executed set on arm A: every function callgrind saw run INSIDE the RT .so ---------------------------
valgrind --tool=callgrind --demangle=no --callgrind-out-file="$T/cg.out" "$T/armA/scrip" "$W" </dev/null >"$T/cg.stdout" 2>"$T/cg.err" || { tail -3 "$T/cg.err" >&2; refuse "callgrind run of arm A failed"; }
[ -s "$T/cg.out" ] || refuse "callgrind wrote no profile"
python3 - "$T/cg.out" "libscrip_rt" "$T/hot.txt" <<'PY' || refuse "callgrind parser failed"
import re, sys
cg, want, out = sys.argv[1], sys.argv[2], sys.argv[3]
# ⛔ seat07's two parsing traps (FINDING-2026-09-01-seat07-startup-touch-full-executed-list-...): (1) the name-compression
# table is SHARED between cost-side (ob=/fn=) and call-side (cob=/cfn=) specs -- key by kind (object vs function), never
# by keyword, or 44% of the definitions vanish; (2) callgrind appends a recursion-context suffix ('2) to the same name.
objs, fns, cur_ob, seen, order = {}, {}, None, set(), []
pat = re.compile(r"^(c?ob|c?fn)=(?:\((\d+)\))?\s*(.*)$")
for line in open(cg, errors="replace"):
    m = pat.match(line.rstrip("\n"))
    if not m: continue
    kind, i, name = m.group(1), m.group(2), m.group(3)
    table = objs if kind.endswith("ob") else fns
    if name: 
        if i is not None: table[i] = name
    elif i is not None: name = table.get(i, "")
    if kind == "ob": cur_ob = name
    elif kind == "fn":
        n = re.sub(r"'\d+$", "", name)
        if want in (cur_ob or "") and n and n != "???" and re.fullmatch(r"[A-Za-z_.$][A-Za-z0-9_.$]*", n) and n not in seen:
            seen.add(n); order.append(n)
open(out, "w").write("\n".join(order) + ("\n" if order else ""))
print(f"executed-in-.so functions: {len(order)}", file=sys.stderr)
PY
NHOT=$(wc -l < "$T/hot.txt"); [ "$NHOT" -ge 50 ] || refuse "only $NHOT executed functions found in the .so -- the parser or the run is wrong (seat07 found 480 on the same witness)"
{ echo "SECTIONS"; echo "{"; echo "  .text.startup_hot :"; echo "  {"; sed 's/^/    *(.text./; s/$/)/' "$T/hot.txt"; echo "  }"; echo "}"; echo "INSERT BEFORE .text;"; } > "$T/order.ld"
# ---- arm B0: same tree, RT_OPT + -ffunction-sections, the Makefile's own compile + link, its OWN tag ---------------
OPT_B="$OPT_A -ffunction-sections"
TAG_B="$(bi RT_OPT="$OPT_B" | sed -n 's/^RT_TAG *: *//p' | tr -d '[:space:]')"; [ -n "$TAG_B" ] && [ "$TAG_B" != "$TAG_A" ] || refuse "arm B did not get its own RT_TAG (A=$TAG_A B=$TAG_B)"
SO_B0="out/libscrip_rt-$TAG_B.so"
make -s RT_OPT="$OPT_B" "$SO_B0" >"$T/makeB.log" 2>&1 || { tail -8 "$T/makeB.log" >&2; refuse "build of arm B0 ($SO_B0) failed"; }
[ -f "$SO_B0" ] || refuse "arm B0 .so not produced: $SO_B0"
cp -p "$ROOT/$SO_B0" "$T/armB0/libscrip_rt.so"; link_driver "$T/armB0" "arm B0"
# ---- arm B: B0's objects relinked through the Makefile's OWN link line plus the ordering fragment -------------------
firstobj="$(ls out/rt_pic-$TAG_B/*.o 2>/dev/null | head -1)"; [ -n "$firstobj" ] || refuse "no objects under out/rt_pic-$TAG_B"
LINK_LINE="$(make -n -W "$firstobj" RT_OPT="$OPT_B" "$SO_B0" 2>/dev/null | grep -m1 -- ' -shared ')"; [ -n "$LINK_LINE" ] || refuse "could not recover the Makefile's .so link line for arm B"
case "$LINK_LINE" in *" -o $SO_B0"*) : ;; *) refuse "the recovered link line does not end in -o $SO_B0: $LINK_LINE";; esac
LINK_B="${LINK_LINE% -o $SO_B0} -Wl,-T,$T/order.ld -o $T/armB/libscrip_rt.so"
bash -c "$LINK_B" >"$T/linkB.log" 2>&1 || { tail -8 "$T/linkB.log" >&2; refuse "ordered link of arm B failed"; }
link_driver "$T/armB" "arm B"
secsize() { local h; h="$(readelf -S -W "$1" | sed 's/^ *\[ *[0-9]*\] *//' | awk -v n="$2" '$1==n{print $5; exit}')"; [ -n "$h" ] && printf '%d' "0x$h" || printf '0'; }   # mawk-safe: no strtonum, and the [ N] index column is stripped before fields are counted
HOT_BYTES="$(secsize "$T/armB/libscrip_rt.so" .text.startup_hot)"
[ "${HOT_BYTES:-0}" -gt 0 ] 2>/dev/null || refuse "arm B has no .text.startup_hot section (or it is empty) -- the fragment matched nothing, the lever was not applied"
textsz() { secsize "$1" .text; }
# ---- m4 arm: compile the witness ONCE (the .s does not depend on the .so), link once per arm ------------------------
"$T/armA/scrip" --compile -o "$T/w.s" "$W" </dev/null >/dev/null 2>"$T/m4c.err" || { tail -3 "$T/m4c.err" >&2; refuse "mode-4 compile of the witness failed"; }
for arm in armA armB0 armB; do gcc -no-pie "$T/w.s" -o "$T/$arm/w4" -L"$T/$arm" -lscrip_rt -lm -Wl,-rpath,"$T/$arm" 2>"$T/m4l.err" || { tail -3 "$T/m4l.err" >&2; refuse "mode-4 link against $arm failed"; }; done
# ---- correctness first: a wrong answer is never a fast answer ------------------------------------------------------
"$T/armA/scrip" "$W" </dev/null >"$T/ref.out" 2>/dev/null || red "arm A itself exits non-zero on the witness"
[ -s "$T/ref.out" ] || red "arm A prints nothing on the witness"
for arm in armA armB0 armB; do
  "$T/$arm/scrip" "$W" </dev/null >"$T/$arm.m3.out" 2>/dev/null || red "$arm m3 exits non-zero -- the lever breaks the program"
  cmp -s "$T/$arm.m3.out" "$T/ref.out" || red "$arm m3 output differs from arm A -- the lever breaks the program"
  "$T/$arm/w4" </dev/null >"$T/$arm.m4.out" 2>/dev/null || red "$arm m4 exits non-zero -- the lever breaks the program"
  cmp -s "$T/$arm.m4.out" "$T/ref.out" || red "$arm m4 output differs from arm A -- the lever breaks the program"
done
# ---- measure: RUNS x (arm x mode), one instrument, per-run rows kept so spread is visible -------------------------
measure() { # $1 label $2.. command ; prints "mean_f min_f max_f mean_r min_r max_r"
  local lbl="$1"; shift; local f r line tf=0 tr=0 mnf= mxf= mnr= mxr= i
  for i in $(seq 1 "$RUNS"); do
    line="$(/usr/bin/time -f '%R %M' $SETARCH "$@" </dev/null 2>&1 >/dev/null | tail -1)"
    f="${line%% *}"; r="${line##* }"
    case "$f$r" in ''|*[!0-9]*) refuse "instrument produced a non-numeric reading for $lbl: '$line'";; esac
    tf=$((tf+f)); tr=$((tr+r)); [ -z "$mnf" ] || [ "$f" -lt "$mnf" ] && mnf=$f; [ -z "$mxf" ] || [ "$f" -gt "$mxf" ] && mxf=$f
    [ -z "$mnr" ] || [ "$r" -lt "$mnr" ] && mnr=$r; [ -z "$mxr" ] || [ "$r" -gt "$mxr" ] && mxr=$r
    printf '  run %-8s %-3s minflt=%-6s maxrss_kb=%s\n' "$lbl" "$i" "$f" "$r" >> "$T/runs.txt"
  done
  awk -v tf="$tf" -v tr="$tr" -v n="$RUNS" -v a="$mnf" -v b="$mxf" -v c="$mnr" -v d="$mxr" 'BEGIN{printf "%.1f %d %d %.1f %d %d\n", tf/n, a, b, tr/n, c, d}'; }
: > "$T/runs.txt"
declare -A M
for arm in armA armB0 armB; do M["$arm.m3"]="$(measure "$arm.m3" "$T/$arm/scrip" "$W")"; M["$arm.m4"]="$(measure "$arm.m4" "$T/$arm/w4")"; done
# ---- the report: every number labelled with its tree, RT_OPT, RT_TAG, witness, mode and instrument -----------------
rev() { git -C "$1" rev-parse --short HEAD 2>/dev/null || echo "?"; }; dirty() { [ -z "$(git -C "$1" status --porcelain 2>/dev/null)" ] || echo "+dirty"; }
echo "# bench_startup_touch_ab.sh -- startup-touch A/B, row rtx-startup-linker-ordering"
echo "# box=$(hostname) date=$(date -u +%Y-%m-%dT%H:%MZ) tree: SCRIP $(rev "$ROOT")$(dirty "$ROOT") corpus $(rev "$ROOT/../corpus")$(dirty "$ROOT/../corpus")"
echo "# instrument: /usr/bin/time -f '%R %M' (minor faults, max RSS kB) ${SETARCH:+under $SETARCH }runs=$RUNS per cell; witness: $WLABEL"
echo "# executed set: $NHOT functions callgrind saw run inside libscrip_rt.so on arm A ($(awk '/^summary:/{print $2}' "$T/cg.out") Ir); all $NHOT named in order.ld"
printf '# arm A : RT_OPT=%s RT_TAG=%s %s size=%s .text=%s\n' "'$OPT_A'" "$TAG_A" "$SO_A" "$(stat -c %s "$SO_A")" "$(textsz "$SO_A")"
printf '# arm B0: RT_OPT=%s RT_TAG=%s %s size=%s .text=%s  (flag only, Makefile link -- a CONTROL for section-split padding, NOT the A/B)\n' "'$OPT_B'" "$TAG_B" "$SO_B0" "$(stat -c %s "$SO_B0")" "$(textsz "$SO_B0")"
printf '# arm B : B0 objects + -Wl,-T,order.ld (INSERT BEFORE .text) size=%s .text=%s .text.startup_hot=%s bytes (%s pages)  <- THE LEVER\n' "$(stat -c %s "$T/armB/libscrip_rt.so")" "$(textsz "$T/armB/libscrip_rt.so")" "$HOT_BYTES" "$(( (HOT_BYTES+4095)/4096 ))"
echo "# multiples are A/arm on the FASTER axis (RULES.md § FACT RULES): >1.00x = fewer faults / less RSS than arm A"
printf '  %-4s %-4s %-24s %-28s %-9s %s\n' mode arm "minflt mean (min-max)" "maxrss_kb mean (min-max)" "x faults" "x rss"
verdict_f=""; verdict_r=""
for mode in m3 m4; do
  set -- ${M["armA.$mode"]}; af=$1; afmin=$2; afmax=$3; ar=$4; armin=$5; armax=$6
  for arm in armA armB0 armB; do
    set -- ${M["$arm.$mode"]}; f=$1; fmin=$2; fmax=$3; r=$4; rmin=$5; rmax=$6
    printf '  %-4s %-4s %-24s %-28s %-9s %s\n' "$mode" "${arm#arm}" "$f ($fmin-$fmax)" "$r ($rmin-$rmax)" "$(PERF_COLOR=0 perf_mult "$af" "$f")" "$(PERF_COLOR=0 perf_mult "$ar" "$r")"
    if [ "$arm" = armB ] && [ "$mode" = m3 ]; then verdict_f="$(awk -v a="$af" -v b="$f" 'BEGIN{printf "%.1f", (a-b)/a*100}')"; verdict_r="$(awk -v a="$ar" -v b="$r" 'BEGIN{printf "%.1f", (a-b)/a*100}')"; bfmean="$f"; afmin_keep="$afmin"; fi
  done
done
echo "# per-run rows:"; cat "$T/runs.txt"
if awk -v b="$bfmean" -v a="$afmin_keep" 'BEGIN{exit !(b < a)}'; then
  echo "VERDICT: GAIN -- arm B (flag + ordering) touches ${verdict_f}% fewer minor faults than arm A on m3 (B's mean sits below A's best run); RSS ${verdict_r}% lower. The lever is real on this tree; landing it is a separate, gated decision (SNOBOL4 board + smokes)."
else
  echo "VERDICT: NO GAIN -- arm B's mean minflt ($bfmean) does not beat arm A's best run ($afmin_keep) on m3. Do not land the lever on this evidence; record it and move on. This is a green outcome for the row: the number was the deliverable."
fi
exit 0
