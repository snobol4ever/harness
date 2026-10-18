#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture over a scratch population, not a board (CEO-547)"
# test_gate_every_runner_passes_the_declared_heap_and_stack.sh -- EVERY RUNNER PASSES EACH UNIT'S DECLARED HEAP AND STACK IN BOTH MODES,
# NEVER AS THE WINDOW (Lon 2026-09-28 15:4x CDT, in-chat to the ceo, verbatim: "Ensure that every program in every language as it necessary
# stack size and heap size values stored in the per-program attribute file, and ensure that those command-line switches and environment
# variable values are being used by the harness shell scripts which run all of them."; ceo CEO-1353; half (b) of the coo's row
# instruments-every-runner-passes-each-units-declared-heap-and-stack-in-both-modes-never-as-the-window-names-a-missing-one).
# THE VERDICT-PAIR METHOD of test_gate_package_runners_read_each_units_declared_compile_args.sh, extended to SIZE. Each runner family
# grades FOUR scratch units of two witnesses whose outcome depends on the declared size, in both modes:
#   deepdecl    a 50000-deep recursion declaring stack_kb 262144      -> PASS  (it needs the declared stack)
#   deepnodecl  the same program at the shipped 4096 KB stack          -> FAIL  (ERROR 246 at the default)
#   livedecl    a 30000-entry live set declaring heap_kb 2048          -> FAIL  (HARD CAP at the declared 2 MB)
#   livenodecl  the same program at the shipped 131072 KB cap          -> PASS
# A runner that reads no declaration reads deepdecl FAIL; a runner that hands the declared heap to SCRIP_HEAP_KB (the collector's initial
# WINDOW, cap = max(128 MB, window)) reads livedecl PASS -- both are named. The premise arm W re-measures the four against scrip directly
# (and the window mistake), so the day a witness stops depending on its size this gate says so.
# FAMILIES: H the harness (the rung suites' and package tables' one reader), D test_demos_suite.sh (a standalone unit's .heap/.stack
# sidecars), P1 test_snobol4_dotnet_suite.sh, P2 test_snobol4_csnobol4_suite.sh (the SNOBOL4 package runners through
# run_at_declared_table), L lib_ladder.sh -- the one body of all seven test_<lang>_ladder.sh, driven through test_snobol4_ladder.sh
# over a scratch S4E_HOME whose rungs table carries the four units as ladder__rung00_* origins (the coo, 2026-09-30). PBS PBM PB4 the Prolog bench
# family's row runner and its two correctness scripts over a scratch kernel dir of four Prolog units (the coo, 2026-10-01; FAIL_ONCE reds
# PBM and PB4 through the stubbed declared_switches_beside; PBS runs from ../harness/scripts/ itself, since it finds its binary beside its own script and
# reads the sidecars through declared_arena_kb_beside, which the plant leaves alone, so it stays green). THE MASSIVE SET (the coo 2026-10-03,
# LARGE CHUNKS, CEO-1478..1484): EVERY runner family, each driven through its OWN population override (a scratch package, corpus, kernel
# dir, S4E_HOME or suite variable) and read from its own progress rows or printed verdicts -- SNOBOL4 SF X64 X32 TP GS AIS; Prolog PI PG PS PR
# PL and the timing angles PBT PBF PBP PBV; Icon IA IJ II IB IT ITX IR IAR IBR; Pascal SPF SPW SPT SPB SPTM SPTM4 SPFI SPTR; Raku RR RB RTM RFI RTR;
# Snocone and Rebus SCB RBB RBT SCT; and the coo's own MON (monitor_run.sh --oracle), PT (lib_port_trace.sh) and AS (the area smoke). Each
# language has its own witness pair, measured against its oracle (named above its arms); a runner that grades m3 alone is graded in m3 alone,
# named on its line. bench_pascal_bar.sh and bench_raku_bar.sh grade one kernel THROUGH an angle graded here and are read there. Every
# runner this set had to cure fail-once reds on its pre-cure text (measured 2026-10-03; the commit names each). THE EIGHT BOOTSTRAP PARSER
# TOOLS grade no test unit -- each runs one fixed program per language, the chain -- so they are not a family here: their chain declares its
# sizes beside bootstrap/parser_<lang>.sc and test_gate_oracle_args_sidecar_is_declared_and_reaches_the_oracle.sh holds every tool to it
# (arms C and W, the coo 2026-10-03).
# FAIL_ONCE=1: the harness family runs from a scratch copy of ../harness/scripts/ whose _size_switches returns nothing (the reader removed) -- H reds;
# the ladder family runs from a scratch copy whose lib_declared_arena.sh declared_switches_beside prints nothing -- L reds.
# EXIT 0 every family's pairs hold; 1 a pair failed; 2 could not measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=every_runner_passes_the_declared_heap_and_stack
gate_parse_args "$@"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"   # the sibling root the runners resolve, for the rival preludes the vanroy arm copies
gate_require_exec "$SCRIP" "scrip binary" || exit 2
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_oracle_flags.sh unloadable"; exit 2; }
SBL="$(sbl_correctness_bin 2>/dev/null)"; SBLF="$(sbl_lang_flags 2>/dev/null)"
[ -x "$SBL" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no SNOBOL4 oracle"; exit 2; }
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"; mkdir -p "$SCRATCH" || exit 2
W=$(mktemp -d "$SCRATCH/gate_sizes_XXXXXX") || exit 2
# Every arm's progress rows go to a scratch table unless the arm names its own (the coo 2026-10-03: a probe of
# bench_triangulate_pascal.sh run without one appended 8 fixture rows to the live table -- the runners that write progress
# from a timing angle take the table from the environment like every other writer).
export S4E_PROGRESS_DB="$W/progress-default.tsv"
trap 'rm -rf "$W"' EXIT INT TERM
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   $1: $2"; }
red() { FAIL=$((FAIL+1)); echo "  FAIL $1: $2"; }

# the witnesses
printf "        DEFINE('R(N)')                    :(REND)\nR       R = EQ(N,0) 0                     :S(RETURN)\n        R = R(N - 1) + 1                  :(RETURN)\nREND    OUTPUT = 'depth=' R(50000)\nEND\n" > "$W/deep.sno"
printf "        T = TABLE()\n        I = 0\nL       I = LT(I,30000) I + 1         :F(D)\n        T[I] = DUPL('x',100)          :(L)\nD       OUTPUT = 'built ' I\nEND\n" > "$W/live.sno"
(cd "$W" && timeout -k 5 60 "$SBL" $SBLF deep.sno < /dev/null > deep.ref 2>&1; timeout -k 5 60 "$SBL" $SBLF live.sno < /dev/null > live.ref 2>&1)
[ "$(cat "$W/deep.ref")" = "depth=50000" ] && [ "$(cat "$W/live.ref")" = "built 30000" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the oracle's refs moved: deep '$(head -c 60 "$W/deep.ref")' live '$(head -c 60 "$W/live.ref")'"; gate_stamp; exit 2; }
declare -A HEAP=([deepdecl]=131072 [deepnodecl]=131072 [livedecl]=2048 [livenodecl]=131072)
declare -A STACK=([deepdecl]=262144 [deepnodecl]=4096 [livedecl]=4096 [livenodecl]=4096)
declare -A WANT=([deepdecl]=PASS [deepnodecl]=FAIL [livedecl]=FAIL [livenodecl]=PASS)
UNITS="deepdecl deepnodecl livedecl livenodecl"
src_of() { case "$1" in deep*) echo "$W/deep.sno";; *) echo "$W/live.sno";; esac; }
ref_of() { case "$1" in deep*) echo "$W/deep.ref";; *) echo "$W/live.ref";; esac; }

echo "--- W PREMISE: the four units against scrip directly, both modes, and the window mistake ---"
m4bin() { (cd "$W" && timeout -k 5 120 "$SCRIP" --compile "$1" < /dev/null > "$2.s" 2>/dev/null && gcc -c "$2.s" -o "$2.o" && gcc "$2.o" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$2.bin") >/dev/null 2>&1; }
m4bin "$W/deep.sno" "$W/deepbin"; m4bin "$W/live.sno" "$W/livebin"
prem_ok=1
for u in $UNITS; do
  s=$(src_of "$u"); r=$(ref_of "$u"); b=$W/$([ "${u#deep}" != "$u" ] && echo deepbin || echo livebin).bin
  o3=$(cd "$W" && timeout -k 5 60 "$SCRIP" --run -d${HEAP[$u]}k -s${STACK[$u]}k "$s" < /dev/null 2>/dev/null); o4=$(timeout -k 5 60 "$b" -d${HEAP[$u]}k -s${STACK[$u]}k < /dev/null 2>/dev/null)
  v3=FAIL; [ "$o3" = "$(cat "$r")" ] && v3=PASS; v4=FAIL; [ "$o4" = "$(cat "$r")" ] && v4=PASS
  [ "$v3" = "${WANT[$u]}" ] && [ "$v4" = "${WANT[$u]}" ] || { prem_ok=0; echo "      $u m3=$v3 m4=$v4 want ${WANT[$u]}"; }
done
ow=$(cd "$W" && SCRIP_HEAP_KB=2048 timeout -k 5 60 "$SCRIP" --run "$W/live.sno" < /dev/null 2>/dev/null)
[ "$prem_ok" = 1 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: a witness no longer depends on its declared size -- the pairs below would measure nothing"; gate_stamp; exit 2; }
ok W "deepdecl PASS / deepnodecl FAIL / livedecl FAIL / livenodecl PASS against scrip -d -s directly, m3 and m4; the declared 2 MB handed to SCRIP_HEAP_KB (the window) reads '$(head -c 20 <<<"$ow")' -- PASS, the mistake a pair catches"

# outcome <db> <unit> <mode> -- the program's last outcome in a scratch progress table (a runner names it bare, or with its extension)
outcome() { awk -F'\t' -v p="$2" -v m="$3" 'NR>1 && ($8==p || $8==p".sno" || $8~("/"p"(\\.sno)?$")) && $9==m {v=$10} END {print v}' "$1" 2>/dev/null; }
quad() {  # <arm> <db> <label> [modes] -- the four units' outcomes in each mode (default both) against WANT
  local a="$1" db="$2" lbl="$3" modes="${4:-m3 m4}" bad="" u m v
  for u in $UNITS; do for m in $modes; do v=$(outcome "$db" "$u" "$m"); [ -n "$v" ] || v=MISSING
    { [ "${WANT[$u]}" = PASS ] && [ "$v" = PASS ]; } || { [ "${WANT[$u]}" = FAIL ] && [ "$v" != PASS ] && [ "$v" != MISSING ]; } || bad="$bad $u:$m=$v"; done; done
  if [ -z "$bad" ]; then ok "$a" "$lbl -- deepdecl PASS, deepnodecl not, livedecl not, livenodecl PASS, $([ "$modes" = "m3 m4" ] && echo both modes || echo "$modes only")"
  else red "$a" "$lbl --$bad (want deepdecl PASS, deepnodecl FAIL, livedecl FAIL, livenodecl PASS)"; fi; }
HDR="rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb,compile_args,run_args"
csv4() { printf '%s\n' "$HDR"; local i=1 u; for u in $UNITS; do printf '%s,%s,%s,%s,5,0,0,%s,%s,,\n' "$i" "$u" "$u" "$1" "${HEAP[$u]}" "${STACK[$u]}"; i=$((i+1)); done; }

echo "--- H: the harness (the rung suites' and package tables' one reader) ---"
mkdir -p "$W/h"; python3 - "$HERE" "$W" <<'PY'
import sys; sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h
W = sys.argv[2]; src = []; ref = []
for i, u in enumerate(["deepdecl", "deepnodecl", "livedecl", "livenodecl"], 1):
    b = h.make_banner(i, u); w = "deep" if u.startswith("deep") else "live"
    src.append(b + "\n" + open(f"{W}/{w}.sno").read()); ref.append(b + "\n" + open(f"{W}/{w}.ref").read())
open(f"{W}/h/ALL.sno", "w").write("".join(src)); open(f"{W}/h/ALL.ref", "w").write("".join(ref))
PY
csv4 hfam > "$W/h/ALL.csv"
HSCRIPTS="$HERE"
if [ "${FAIL_ONCE:-0}" = 1 ]; then
  . "$HERE/lib_fixture_root.sh" || exit 2; fixture_root "$W/fo" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot stage a copied root at $W/fo"; exit 2; }; rm -f "$W/fo/harness/scripts/corpus_suite_harness.py"
  sed 's/^def _size_switches(heap_kb, stack_kb):/def _size_switches(heap_kb, stack_kb):\n    return []  # FAIL_ONCE: the reader removed/' "$HERE/corpus_suite_harness.py" > "$W/fo/harness/scripts/corpus_suite_harness.py"
  grep -q 'FAIL_ONCE: the reader removed' "$W/fo/harness/scripts/corpus_suite_harness.py" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: FAIL_ONCE found no _size_switches anchor"; exit 2; }
  HSCRIPTS="$W/fo/harness/scripts"; echo "FAIL_ONCE=1: the harness family runs with _size_switches removed"
fi
oh=$(SCRIP="$SCRIP" RT_DIR="$RT" S4E_PROGRESS_DB="$W/h.tsv" timeout -k 5 600 python3 "$HSCRIPTS/corpus_suite_harness.py" run "$W/h/ALL.sno" "$W/h/ALL.ref" --modes m3,m4 2>&1); rh=$?
[ "$rh" = 2 ] && { echo "      $(grep -m1 -E 'REFUS' <<<"$oh" | cut -c1-200)"; }
# a suite outside the corpus appends no progress rows, so the harness's own output is read: every non-PASS entry prints
# "  <KIND> <mode> <name>: ..." and an entry absent from those lines in a graded run (SUITE_BOARD printed) passed
if grep -q '^SUITE_BOARD ' <<<"$oh"; then
  { printf 'ts\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\n'
    for u in $UNITS; do for m in m3 m4; do k=$(grep -m1 -E "^  [A-Z]+ $m $u: " <<<"$oh" | awk '{print $1}'); printf 'x\tx\tx\tx\tx\th\tsnobol4\t%s\t%s\t%s\n' "$u" "$m" "${k:-PASS}"; done; done; } > "$W/h.tsv"
fi
quad H "$W/h.tsv" "corpus_suite_harness.py run over a scratch SNOBOL4 table (rc $rh)"

echo "--- D: test_demos_suite.sh (a standalone unit's .heap/.stack sidecars) ---"
mkdir -p "$W/d"
for u in $UNITS; do cp "$(src_of "$u")" "$W/d/$u.sno"; cp "$(ref_of "$u")" "$W/d/$u.ref"; printf '%s\t%s\n' "$u" "${HEAP[$u]}" > "$W/d/$u.heap"; printf '%s\t%s\n' "$u" "${STACK[$u]}" > "$W/d/$u.stack"; done
od=$(DEMOS_DIR="$W/d" S4E_PROGRESS_DB="$W/d.tsv" timeout -k 5 600 bash "$HERE/test_demos_suite.sh" snobol4 2>&1); rd=$?
[ "$rd" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$od" | cut -c1-200)"
quad D "$W/d.tsv" "test_demos_suite.sh snobol4 over a scratch demos dir (rc $rd)"

echo "--- P1: test_snobol4_dotnet_suite.sh (live oracle diff, the table's heap_kb/stack_kb through run_at_declared_table) ---"
mkdir -p "$W/p1"; for u in $UNITS; do cp "$(src_of "$u")" "$W/p1/$u.sno"; done; csv4 dotnet > "$W/p1/ALL.csv"
o1=$(DOTNET_SUITE="$W/p1" S4E_PROGRESS_DB="$W/p1.tsv" timeout -k 5 600 bash "$HERE/test_snobol4_dotnet_suite.sh" 2>&1); r1=$?
[ "$r1" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$o1" | cut -c1-200)"
quad P1 "$W/p1.tsv" "test_snobol4_dotnet_suite.sh over a scratch package (rc $r1)"

echo "--- P2: test_snobol4_csnobol4_suite.sh (the Budne runner, ref-graded, run_at_declared_table) ---"
mkdir -p "$W/p2"; for u in $UNITS; do cp "$(src_of "$u")" "$W/p2/$u.sno"; cp "$(ref_of "$u")" "$W/p2/$u.ref"; done; csv4 csnobol4_suite > "$W/p2/ALL.csv"; : > "$W/p2/ALL.ref"
o2=$(CSNOBOL4_SUITE="$W/p2" S4E_PROGRESS_DB="$W/p2.tsv" timeout -k 5 600 bash "$HERE/test_snobol4_csnobol4_suite.sh" 2>&1); r2=$?
[ "$r2" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$o2" | cut -c1-200)"
quad P2 "$W/p2.tsv" "test_snobol4_csnobol4_suite.sh over a scratch package (rc $r2)"

echo "--- L: lib_ladder.sh (the ONE body of all seven ladders) through test_snobol4_ladder.sh over a scratch rungs table ---"
mkdir -p "$W/l/corpus/tests/snobol4"; python3 - "$HERE" "$W" <<'PY'
import sys; sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h
W = sys.argv[2]; src = []; ref = []
for i, u in enumerate(["deepdecl", "deepnodecl", "livedecl", "livenodecl"], 1):
    b = h.make_banner(i, u); w = "deep" if u.startswith("deep") else "live"
    src.append(b + "\n" + open(f"{W}/{w}.sno").read()); ref.append(b + "\n" + open(f"{W}/{w}.ref").read())
open(f"{W}/l/corpus/tests/snobol4/ALL.sno", "w").write("".join(src)); open(f"{W}/l/corpus/tests/snobol4/ALL.ref", "w").write("".join(ref))
PY
{ printf '%s\n' "$HDR"; i=1; for u in $UNITS; do printf '%s,%s,ladder__rung00_%s,ladder,5,0,0,%s,%s,,\n' "$i" "$u" "$u" "${HEAP[$u]}" "${STACK[$u]}"; i=$((i+1)); done; } > "$W/l/corpus/tests/snobol4/ALL.csv"
LSCRIPTS="$HERE"
if [ "${FAIL_ONCE:-0}" = 1 ]; then
  . "$HERE/lib_fixture_root.sh" || exit 2; fixture_root "$W/fl" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot stage a copied root at $W/fl"; exit 2; }; rm -f "$W/fl/harness/scripts/lib_declared_arena.sh"
  { cat "$HERE/lib_declared_arena.sh"; printf '\ndeclared_switches_beside() { return 0; }  # FAIL_ONCE: the reader removed\n'; } > "$W/fl/harness/scripts/lib_declared_arena.sh"
  LSCRIPTS="$W/fl/harness/scripts"; echo "FAIL_ONCE=1: the ladder family runs with declared_switches_beside removed"
fi
ol=$(S4E_HOME="$W/l" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 600 bash "$LSCRIPTS/test_snobol4_ladder.sh" 2>&1); rl=$?
[ "$rl" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$ol" | cut -c1-200)"
# the ladder appends no progress rows; it prints one line per witness, "rung NN  ladder__rung00_<unit>  m3=<v> m4=<v> (...)"
{ printf 'ts\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\n'
  for u in $UNITS; do ln=$(grep -m1 -E "^rung +0 +ladder__rung00_$u " <<<"$ol"); for m in m3 m4; do
    v=$(sed -n "s/.* $m=\([A-Z]*\).*/\1/p" <<<"$ln"); printf 'x\tx\tx\tx\tx\tl\tsnobol4\t%s\t%s\t%s\n' "$u" "$m" "$v"; done; done; } > "$W/l.tsv"
quad L "$W/l.tsv" "test_snobol4_ladder.sh (lib_ladder.sh) over a scratch rungs table (rc $rl)"

echo "--- PB: the Prolog bench family over a scratch kernel dir -- test_prolog_bench_suite.sh (the row runner), test_bench_prolog_modes.sh, test_bench_prolog_4way.sh ---"
# Prolog units, since the SNOBOL4 witnesses cannot run here. MEASURED 2026-10-01 at c1c899df3, m3 and m4: d/2 300000 deep overflows the 4 MB
# default and passes at -s262144k; a findall of 30000 x/2 terms reaches the HARD CAP at -d2048k and passes at the default cap. Both live units
# declare -s65536k because findall and length over 30000 elements also need more than 4 MB of stack, so the live pair differs in heap alone.
declare -A PHEAP=([deepdecl]=131072 [deepnodecl]=131072 [livedecl]=2048 [livenodecl]=131072)
declare -A PSTACK=([deepdecl]=262144 [deepnodecl]=4096 [livedecl]=65536 [livenodecl]=65536)
mkdir -p "$W/pb"
for u in $UNITS; do
  case "$u" in deep*) body=$'bench_work(R) :- d(300000, R).\nd(0, 0) :- !.\nd(N, R) :- M is N - 1, d(M, R0), R is R0 + 1.'; r=300000 ;;
               *) body='bench_work(N) :- findall(x(I, abcdefgh), between(1, 30000, I), L), length(L, N).'; r=30000 ;; esac
  printf '%% *BENCH kernel=%s\n:- initialization(main).\n%s\nmain :- bench_work(Res), write(Res), nl.\n' "$u" "$body" > "$W/pb/$u.pl"
  echo "$r" > "$W/pb/$u.ref"; printf '%s\t%s\n' "$u" "${PHEAP[$u]}" > "$W/pb/$u.heap"; printf '%s\t%s\n' "$u" "${PSTACK[$u]}" > "$W/pb/$u.stack"
done
pbtab() {  # <runner output> <awk program printing the verdict of unit u in mode m> -- the quad table from a runner's printed rows
  local u m; printf 'ts\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\n'
  for u in $UNITS; do for m in m3 m4; do printf 'x\tx\tx\tx\tx\tpb\tprolog\t%s\t%s\t%s\n' "$u" "$m" "$(awk -v u="$u" -v m="$m" "$2" <<<"$1")"; done; done; }
os=$(BENCH_PROLOG_DIR="$W/pb" S4E_PROGRESS_DB="$W/pbs.db" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/test_prolog_bench_suite.sh" 2>&1); rs=$?
[ "$rs" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$os" | cut -c1-200)"
pbtab "$os" '$1==u && $2==m {print $6; exit}' > "$W/pbs.tsv"
quad PBS "$W/pbs.tsv" "test_prolog_bench_suite.sh over a scratch kernel dir, SCRIP_HEAP_CAP_KB and SCRIP_STACK (rc $rs)"
om=$(BENCH_DIR="$W/pb" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$LSCRIPTS/test_bench_prolog_modes.sh" 2>&1); rmo=$?
pbtab "$om" '$1==u {print (m=="m3" ? $2 : $3); exit}' > "$W/pbm.tsv"
quad PBM "$W/pbm.tsv" "test_bench_prolog_modes.sh over a scratch kernel dir, -d/-s switches (rc $rmo)"
o4=$(BENCH_DIR="$W/pb" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$LSCRIPTS/test_bench_prolog_4way.sh" 2>&1); r4=$?
pbtab "$o4" '$1==u {print (m=="m3" ? $4 : $5); exit}' > "$W/pb4.tsv"
quad PB4 "$W/pb4.tsv" "test_bench_prolog_4way.sh over a scratch kernel dir, -d/-s switches (rc $r4)"
# THE FOUR PROLOG TIMING ANGLES (the coo 2026-10-03): the same kernels, each angle's SCRIP rate or time cell per mode -- a number is PASS, a
# SKIP/NA/- cell (the angle's own correctness or rc refusal) is not. Each prints its grid on stdout and writes no row.
num() { printf '$1==u {v=(m=="m3" ? $%s : $%s); print (v ~ /^[0-9][0-9.]*$/ ? "PASS" : "FAIL"); exit}' "$1" "$2"; }
printf 'kernel\tN\tN_rival\n' > "$W/pb.ntsv"; for u in $UNITS; do printf '%s\t2\t2\n' "$u" >> "$W/pb.ntsv"; done
ot=$(BENCH_DIR="$W/pb" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/test_bench_prolog_timed.sh" 2>&1); rt=$?
[ "$rt" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$ot" | cut -c1-200)"
pbtab "$ot" "$(num 5 6)" > "$W/pbt.tsv"
quad PBT "$W/pbt.tsv" "test_bench_prolog_timed.sh (angle 1) over a scratch kernel dir (rc $rt)"
of=$(BENCH_DIR="$W/pb" NTSV="$W/pb.ntsv" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/bench_prolog_fixed_iter.sh" 2>&1); rf=$?
[ "$rf" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$of" | cut -c1-200)"
pbtab "$of" "$(num 6 7)" > "$W/pbf.tsv"
quad PBF "$W/pbf.tsv" "bench_prolog_fixed_iter.sh (angle 2) over a scratch kernel dir and N table (rc $rf)"
op=$(BENCH_DIR="$W/pb" RUNS=1 SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/bench_prolog_perf.sh" 2>&1); rp=$?
[ "$rp" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$op" | cut -c1-200)"
pbtab "$op" "$(num 4 5)" > "$W/pbp.tsv"
quad PBP "$W/pbp.tsv" "bench_prolog_perf.sh over a scratch kernel dir, m3 and m4r (rc $rp)"
# bench_prolog_vanroy.sh --two-number times only a SELF kernel (one that reports work_us on stderr) and only in m3, and buckets each kernel
# by a triangulation table; its scratch PROLOG_DIR carries the kernels self-timed, a triangulation in which both rivals AGREE on all four,
# and the rivals' preludes -- so SCRIP_us is the one column the declaration moves.
PV="$W/pv"; mkdir -p "$PV/bench"; cp "$S4E/corpus/benchmarks/prolog/prelude_gplc.pl" "$S4E/corpus/benchmarks/prolog/prelude_swipl.pl" "$PV/" 2>/dev/null \
  || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the rival preludes are not under $S4E/corpus/benchmarks/prolog"; gate_stamp; exit 2; }
for u in $UNITS; do
  sed 's/^main :- bench_work(Res), write(Res), nl\.$/main :- wall_us(T0), bench_work(Res), wall_us(T1), W is T1 - T0, write(Res), nl, format(user_error, "work_us=~w~n", [W])./' "$W/pb/$u.pl" > "$PV/bench/$u.pl"
  cp "$W/pb/$u.heap" "$W/pb/$u.stack" "$W/pb/$u.ref" "$PV/bench/"
done
grep -q work_us "$PV/bench/deepdecl.pl" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the vanroy kernels did not take their work_us bracket"; gate_stamp; exit 2; }
cp "$W/pb.ntsv" "$PV/fixed-iter-n.tsv"; printf '# EXCLUDED.tsv -- the gate fixture: none\n' > "$PV/EXCLUDED.tsv"
{ printf '# triangulation TSV -- the gate fixture\nkernel\tengine\tangle1_rate\tangle2_rate\tratio\tverdict\tdisk_inblock\tdisk_oublock\n'
  for u in $UNITS; do for e in gnu swi; do printf '%s\t%s\t1\t1\t1.0\tAGREE\t0\t0\n' "$u" "$e"; done; done; } > "$PV/triangulation-20261003T000000Z.tsv"
ov=$(PROLOG_DIR="$PV" NTSV="$PV/fixed-iter-n.tsv" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/bench_prolog_vanroy.sh" --two-number 2>&1); rv=$?
[ "$rv" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$ov" | cut -c1-200)"
pbtab "$ov" '$2==u && $1 ~ /^(MEASURED|DECLARED|REFUSE)$/ {print ($4 ~ /^[0-9]+$/ ? "PASS" : "FAIL"); exit}' > "$W/pbv.tsv"
quad PBV "$W/pbv.tsv" "bench_prolog_vanroy.sh --two-number over a scratch PROLOG_DIR, SCRIP_us (rc $rv)" m3

# THE SNOBOL4 PACKAGE RUNNERS (the coo 2026-10-03, CEO-1353 gate (b), the massive set): each over a scratch package of the four units
# through its own suite override, outcomes from its scratch progress DB; a key a runner spells its own way is mapped back to the unit.
# remap <db> <sed> -- the same table with column 8 rewritten, so outcome() reads the unit name
remap() { awk -F'\t' -v OFS='\t' 'NR==1 {print; next} {print}' "$1" | sed -E "$2"; }
pkg4() {  # <dir> <ext> <package> [prefix] -- the four units as <prefix><u>.<ext> with refs, and the package's ALL.csv
  local d="$1" ext="$2" pk="$3" pre="${4:-}" u i=1; mkdir -p "$d"
  for u in $UNITS; do cp "$(src_of "$u")" "$d/$pre$u.$ext"; cp "$(ref_of "$u")" "$d/$pre$u.ref"; done
  { printf '%s\n' "$HDR"; for u in $UNITS; do printf '%s,%s,%s,%s,5,0,0,%s,%s,,\n' "$i" "$pre$u" "$pre$u" "$pk" "${HEAP[$u]}" "${STACK[$u]}"; i=$((i+1)); done; } > "$d/ALL.csv"; }
echo "--- SF: test_snoflake_suite.sh (live sbl diff, run_at_declared_table) ---"
pkg4 "$W/sf" sno snoflake_suite
osf=$(SNOFLAKE_SUITE="$W/sf" S4E_PROGRESS_DB="$W/sf.tsv" timeout -k 5 600 bash "$HERE/test_snoflake_suite.sh" 2>&1); rsf=$?
[ "$rsf" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$osf" | cut -c1-200)"
quad SF "$W/sf.tsv" "test_snoflake_suite.sh over a scratch package (rc $rsf)"
echo "--- X64 X32: the SPITBOL x64 and x32 suites (.sbl / .spt units, their shipped-count self-check set to the fixture's 4) ---"
pkg4 "$W/x64" sbl spitbol_x64_tests; pkg4 "$W/x32" spt spitbol_x32_tests
ox6=$(SPITBOL_X64_SUITE="$W/x64" SPITBOL_X64_SHIPPED=4 S4E_PROGRESS_DB="$W/x64.tsv" timeout -k 5 600 bash "$HERE/test_snobol4_spitbol_x64_suite.sh" 2>&1); rx6=$?
[ "$rx6" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$ox6" | cut -c1-200)"
quad X64 "$W/x64.tsv" "test_snobol4_spitbol_x64_suite.sh over a scratch package (rc $rx6)"
ox3=$(SPITBOL_X32_SUITE="$W/x32" SPITBOL_X32_SHIPPED=4 S4E_PROGRESS_DB="$W/x32.tsv" timeout -k 5 600 bash "$HERE/test_snobol4_spitbol_x32_suite.sh" 2>&1); rx3=$?
[ "$rx3" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$ox3" | cut -c1-200)"
quad X32 "$W/x32.tsv" "test_snobol4_spitbol_x32_suite.sh over a scratch package (rc $rx3)"
echo "--- TP: test_snobol4_spitbol_testpgms_suite.sh (test*.spt units and the testpgms.in every program reads) ---"
pkg4 "$W/tp" spt spitbol_testpgms test; : > "$W/tp/testpgms.in"
otp=$(SPITBOL_TESTPGMS_SUITE="$W/tp" S4E_PROGRESS_DB="$W/tp0.tsv" timeout -k 5 600 bash "$HERE/test_snobol4_spitbol_testpgms_suite.sh" 2>&1); rtp=$?
[ "$rtp" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$otp" | cut -c1-200)"
remap "$W/tp0.tsv" 's/\ttest([a-z]+)\t(m[34])\t/\t\1\t\2\t/' > "$W/tp.tsv"
quad TP "$W/tp.tsv" "test_snobol4_spitbol_testpgms_suite.sh over a scratch package (rc $rtp)"
echo "--- GS: test_snobol4_gimpel_suite.sh through scorecard_snobol4.sh (a scratch CORPUS whose gimpel package holds four <u>_driver.sno and their libraries) ---"
GSD="$W/gs/corpus/packages/snobol4/gimpel"; mkdir -p "$GSD" "$W/gs/corpus/include"
for u in $UNITS; do cp "$(src_of "$u")" "$GSD/${u}_driver.sno"; cp "$(ref_of "$u")" "$GSD/${u}_driver.ref"; printf '* %s.inc -- the library the fixture driver carries\n' "$u" > "$GSD/$u.inc"; done
{ printf '%s\n' "$HDR"; i=1; for u in $UNITS; do printf '%s,%s_driver,gimpel__%s_driver,gimpel,5,0,0,%s,%s,,\n' "$i" "$u" "$u" "${HEAP[$u]}" "${STACK[$u]}"; i=$((i+1)); done; } > "$GSD/ALL.csv"
ogs=$(CORPUS="$W/gs/corpus" S4E_PROGRESS_DB="$W/gs0.tsv" timeout -k 5 900 bash "$HERE/test_snobol4_gimpel_suite.sh" 2>&1); rgs=$?
[ "$rgs" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$ogs" | cut -c1-200)"
remap "$W/gs0.tsv" 's#\t[^\t]*/([a-z]+)\.inc\t(m[34])\t#\t\1\t\2\t#' > "$W/gs.tsv"
quad GS "$W/gs.tsv" "test_snobol4_gimpel_suite.sh (scorecard_snobol4.sh) over a scratch gimpel package (rc $rgs)"
echo "--- AIS: test_snobol4_aisnobol_suite.sh (the harness over the package's container, AISNOBOL_SUITE) ---"
mkdir -p "$W/ais"; cp "$W/h/ALL.sno" "$W/h/ALL.ref" "$W/ais/"; csv4 aisnobol > "$W/ais/ALL.csv"
oai=$(cd "$ROOT" && AISNOBOL_SUITE="$W/ais" S4E_PROGRESS_DB="$W/ais0.tsv" timeout -k 5 600 bash "$HERE/test_snobol4_aisnobol_suite.sh" 2>&1); rai=$?
[ "$rai" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$oai" | cut -c1-200)"
{ printf 'ts\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\n'
  if grep -q '^SUITE_BOARD ' <<<"$oai"; then for u in $UNITS; do for m in m3 m4; do k=$(grep -m1 -E "^  [A-Z]+ $m $u: " <<<"$oai" | awk '{print $1}'); printf 'x\tx\tx\tx\tx\tais\tsnobol4\t%s\t%s\t%s\n' "$u" "$m" "${k:-PASS}"; done; done; fi; } > "$W/ais.tsv"
quad AIS "$W/ais.tsv" "test_snobol4_aisnobol_suite.sh over a scratch container (rc $rai)"

# THE PROLOG PACKAGE RUNNERS (the coo 2026-10-03). ONE builtin-only witness pair every oracle answers at its own defaults, MEASURED
# 2026-10-03 on f4fde6099: deep = findall(I, between(1,300000,I), L), copy_term(L,L2), length(L2,X) -- ERROR 246 at the shipped 4 MB stack
# in both modes, 300000 at -s262144k; gprolog 1.4.5 and swipl answer it at their defaults (gprolog's copy_term of 300000 FRESH variables
# raises representation_error(too_many_variables) and it has no numlist/3, so the list is ground and built by findall). live = the PB pair's
# findall of 30000 x/2 terms, HARD CAP at -d2048k. Asserted helper clauses are avoided on purpose: an asserted recursive clause raises
# type_error(evaluable,?/0) in m3 only (sent to hq_prolog 2026-10-03).
PLDEEP='findall(I, between(1,300000,I), L), copy_term(L,L2), length(L2,X)'; PLLIVE='findall(x(I,abcdefgh), between(1,30000,I), L), length(L,X)'
plgoal() { case "$1" in deep*) echo "$PLDEEP";; *) echo "$PLLIVE";; esac; }
plwant() { case "$1" in deep*) echo 300000;; *) echo 30000;; esac; }
plcsv() {  # <package> [indexed] -- the four rows; entry <u>, or <u>#<0-based index> when the second argument is "indexed"
  local pk="$1" ix="${2:-}" u e i=0; printf '%s\n' "$HDR"
  for u in $UNITS; do e="$u"; [ "$ix" = indexed ] && e="$u#$i"
    printf '%s,%s,%s,%s,2,0,0,%s,%s,,\n' "$((i+1))" "$e" "$u" "$pk" "${PHEAP[$u]}" "${PSTACK[$u]}"; i=$((i+1)); done; }
echo "--- PI: test_prolog_inria_suite.sh (INRIA [Goal, Expected] files; ALL.csv keys <file>#<global case index>) ---"
mkdir -p "$W/pi"
for u in $UNITS; do printf '/* file %s */\n\n[(%s), [[X <-- %s]]].\n' "$u" "$(plgoal "$u")" "$(plwant "$u")" > "$W/pi/$u"; done
plcsv inriasuite indexed > "$W/pi/ALL.csv"
opi=$(INRIA_SUITE="$W/pi" S4E_PROGRESS_DB="$W/pi0.tsv" timeout -k 5 900 bash "$HERE/test_prolog_inria_suite.sh" 2>&1); rpi=$?
[ "$rpi" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$opi" | cut -c1-200)"
remap "$W/pi0.tsv" 's/\t([a-z]+)#[0-9]+\t(m[34])\t/\t\1\t\2\t/' > "$W/pi.tsv"
quad PI "$W/pi.tsv" "test_prolog_inria_suite.sh over a scratch suite (rc $rpi)"
echo "--- PG: test_prolog_gnu_suite.sh (each .pl three-way against live gprolog at its defaults) ---"
mkdir -p "$W/pg"
for u in $UNITS; do printf ':- initialization(main).\nmain :- %s, write(X), nl.\n' "$(plgoal "$u")" > "$W/pg/$u.pl"; done
plcsv gnu_prolog > "$W/pg/ALL.csv"
opg=$(GNU_PROLOG_SUITE="$W/pg" S4E_PROGRESS_DB="$W/pg0.tsv" timeout -k 5 900 bash "$HERE/test_prolog_gnu_suite.sh" 2>&1); rpg=$?
[ "$rpg" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$opg" | cut -c1-200)"
remap "$W/pg0.tsv" 's/\t([a-z]+)\.pl\t(m[34])\t/\t\1\t\2\t/' > "$W/pg.tsv"
quad PG "$W/pg.tsv" "test_prolog_gnu_suite.sh over a scratch suite, gprolog three-way (rc $rpg)"
echo "--- PS: test_prolog_swi_suite.sh (one plunit unit per file through SCRIP's shim; refs cut from swipl by util_swi_cut_refs.sh) ---"
PSD="$W/ps/corpus/packages/prolog/swi_tests"; mkdir -p "$PSD"
for u in $UNITS; do printf ':- begin_tests(%s).\ntest(w) :- %s, X =:= %s.\n:- end_tests(%s).\n' "$u" "$(plgoal "$u")" "$(plwant "$u")" "$u" > "$PSD/$u.pl"; done
plcsv swi_tests > "$PSD/ALL.csv"
S4E_HOME="$W/ps" timeout -k 5 600 bash "$HERE/util_swi_cut_refs.sh" --write --jobs 4 > "$W/ps.cut" 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: swipl could not cut the fixture refs: $(tail -1 "$W/ps.cut" | cut -c1-160)"; gate_stamp; exit 2; }
ops=$(S4E_CORPUS="$W/ps/corpus" S4E_PROGRESS_DB="$W/ps0.tsv" timeout -k 5 900 bash "$HERE/test_prolog_swi_suite.sh" 2>&1); rps=$?
[ "$rps" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$ops" | cut -c1-200)"
remap "$W/ps0.tsv" 's/\t([a-z]+)\.pl:[^\t]*\t(m[34])\t/\t\1\t\2\t/' > "$W/ps.tsv"
quad PS "$W/ps.tsv" "test_prolog_swi_suite.sh over a scratch suite, plunit refs cut from swipl (rc $rps)"

echo "--- PR: test_prolog_rung_suite.sh --corpus (the loose rung programs, m3 by run_prog and m4 by run_prolog_via_x86_backend.sh, sidecars beside each) ---"
mkdir -p "$W/pr"; i=1
for u in $UNITS; do f="$W/pr/rung0${i}_$u"; sed 1d "$W/pb/$u.pl" > "$f.pl"; cp "$W/pb/$u.ref" "$f.ref"
  printf 'rung0%s_%s\t%s\n' "$i" "$u" "${PHEAP[$u]}" > "$f.heap"; printf 'rung0%s_%s\t%s\n' "$i" "$u" "${PSTACK[$u]}" > "$f.stack"; i=$((i+1)); done
opr=$(SCRIP="$SCRIP" timeout -k 5 900 bash "$HERE/test_prolog_rung_suite.sh" --corpus "$W/pr" 2>&1); rpr=$?
[ "$rpr" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$opr" | cut -c1-200)"
pbtab "$opr" '{k = (m == "m3" ? "interp" : "compile")} $1 == "RED" && $2 == k && $3 ~ ("_" u ":$") {r = "FAIL"} index($0, "--- Prolog (" k "): ") == 1 && /TOTAL=4 / {t = 1} END {print (r ? r : (t ? "PASS" : ""))}' > "$W/prr.tsv"
quad PR "$W/prr.tsv" "test_prolog_rung_suite.sh over a scratch --corpus of loose rungs (rc $rpr)"
echo "--- PL: test_prolog_logtalk_suite.sh (util_logtalk_grade.py: four lgtunit cases in one tests.lgt, each at its own declared arena) ---"
PLD="$W/pl/corpus/packages/prolog/logtalk_iso"; mkdir -p "$PLD/fixture/w"
{ printf ':- object(tests,\n\textends(lgtunit)).\n'
  for u in $UNITS; do printf '\ttest(%s, true(X == %s)) :-\n\t\t{%s}.\n' "$u" "$(plwant "$u")" "$(plgoal "$u")"; done
  printf ':- end_object.\n'; } > "$PLD/fixture/w/tests.lgt"
plcsv logtalk_iso | awk -F, -v OFS=, 'NR==1 {print; next} {$2 = "w:" $2; $3 = "fixture/w/tests.lgt"; print}' > "$PLD/ALL.csv"
opl=$(S4E_CORPUS="$W/pl/corpus" S4E_PROGRESS_DB="$W/pl0.tsv" timeout -k 5 900 bash "$HERE/test_prolog_logtalk_suite.sh" 2>&1); rpl=$?
[ "$rpl" = 2 ] && [ ! -s "$W/pl0.tsv" ] && echo "      $(grep -m1 -E 'REFUS' <<<"$opl" | cut -c1-200)"
remap "$W/pl0.tsv" 's/\tw:([a-z]+)\t(m[34])\t/\t\1\t\2\t/' > "$W/pl.tsv"
quad PL "$W/pl.tsv" "test_prolog_logtalk_suite.sh over a scratch tests.lgt (rc $rpl)"

# THE ICON RUNNERS (the coo 2026-10-03). ONE witness pair, MEASURED 2026-10-03 on f4fde6099 in both modes: deep = d(30000), a non-tail
# recursion -- ERROR 246 at the shipped 4 MB stack, 30000 at -s65536k; iconx answers it only at MSTKSIZE=1000000 (run-time error 301 at its
# default, even 1000 deep), so the deep units declare that in <stem>.oracle_env for the runners that ask the oracle live. live = a list of
# 30000 two-element lists -- the HARD CAP at -d2048k (error 307, an OOM red), 30000 at the default cap; iconx answers it at its default.
declare -A IHEAP=([deepdecl]=131072 [deepnodecl]=131072 [livedecl]=2048 [livenodecl]=131072)
declare -A ISTACK=([deepdecl]=65536 [deepnodecl]=4096 [livedecl]=4096 [livenodecl]=4096)
mkdir -p "$W/icn"
for u in $UNITS; do
  case "$u" in deep*) printf 'procedure d(n);\n  if n = 0 then return 0;\n  return d(n - 1) + 1;\nend\nprocedure main();\n  write(d(30000));\nend\n' ;;
               *) printf 'procedure main();\n  L := [];\n  every i := 1 to 30000 do put(L, [i, "abcdefgh"]);\n  write(*L);\nend\n' ;; esac > "$W/icn/$u.icn"
  echo 30000 > "$W/icn/$u.ref"
done
icsv() {  # <package> <entry prefix> -- the four rows with the Icon sizes
  local i=1 u; printf '%s,stderr\n' "$HDR"
  for u in $UNITS; do printf '%s,%s%s,%s__%s,%s,7,0,0,%s,%s,,,\n' "$i" "$2" "$u" "$1" "$u" "$1" "${IHEAP[$u]}" "${ISTACK[$u]}"; i=$((i+1)); done; }
isides() {  # <dir> [rung] -- each unit's .icn, .ref, .heap, .stack (and the deep units' .oracle_env) into <dir>, named <unit>, or
  # rung0<i>_<unit> with "rung" (the loose-rung runners collect rungNN_*.icn); each sidecar names its own unit
  local d="$1" rg="${2:-}" u n i=1; mkdir -p "$d"
  for u in $UNITS; do n="$u"; [ "$rg" = rung ] && n="rung0${i}_$u"; i=$((i+1))
    cp "$W/icn/$u.icn" "$d/$n.icn"; cp "$W/icn/$u.ref" "$d/$n.ref"
    printf '%s\t%s\n' "$n" "${IHEAP[$u]}" > "$d/$n.heap"; printf '%s\t%s\n' "$n" "${ISTACK[$u]}" > "$d/$n.stack"
    case "$u" in deep*) printf '%s\tMSTKSIZE=1000000\n' "$n" > "$d/$n.oracle_env" ;; esac; done; }
rlines() {  # <runner output> <mode word> <pass regex> -- the quad table from per-unit PASS/FAIL lines, one mode word for both modes
  local u m; printf 'ts\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\n'
  for u in $UNITS; do for m in m3 m4; do printf 'x\tx\tx\tx\tx\tir\ticon\t%s\t%s\t%s\n' "$u" "$m" "$(awk -v u="$u" -v k="$2" "$3" <<<"$1")"; done; done; }
echo "--- IA: test_icon_arizona_suite.sh over a scratch S4E_HOME (general/<unit>) ---"
IAP="$W/ia/corpus/packages/icon/arizona_tests"; mkdir -p "$IAP/special"; isides "$IAP/general"; rm -f "$IAP"/general/*.heap "$IAP"/general/*.stack "$IAP"/general/*.oracle_env
icsv arizona_tests general/ > "$IAP/ALL.csv"
oia=$(S4E_HOME="$W/ia" S4E_PROGRESS_DB="$W/ia.tsv" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/test_icon_arizona_suite.sh" 2>&1); ria=$?
[ "$ria" = 2 ] && [ ! -s "$W/ia.tsv" ] && echo "      $(grep -m1 -E 'REFUS' <<<"$oia" | cut -c1-200)"
quad IA "$W/ia.tsv" "test_icon_arizona_suite.sh over a scratch package (rc $ria)"
echo "--- IJ: test_icon_jcon_suite.sh --corpus ---"
isides "$W/ij"; rm -f "$W"/ij/*.heap "$W"/ij/*.stack "$W"/ij/*.oracle_env; icsv jcon_tests "" > "$W/ij/ALL.csv"
oij=$(S4E_PROGRESS_DB="$W/ij.tsv" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/test_icon_jcon_suite.sh" --corpus "$W/ij" 2>&1); rij=$?
[ "$rij" = 2 ] && [ ! -s "$W/ij.tsv" ] && echo "      $(grep -m1 -E 'REFUS' <<<"$oij" | cut -c1-200)"
quad IJ "$W/ij.tsv" "test_icon_jcon_suite.sh over a scratch --corpus (rc $rij)"
echo "--- II: test_icon_ipl_suite.sh over a scratch S4E_HOME (progs/<unit>; a package shipping only progs/ and procs/) ---"
IIP="$W/ii/corpus/packages/icon/ipl"; mkdir -p "$IIP/procs"; isides "$IIP/progs"; rm -f "$IIP"/progs/*.heap "$IIP"/progs/*.stack "$IIP"/progs/*.oracle_env
icsv ipl progs/ > "$IIP/ALL.csv"
oii=$(S4E_HOME="$W/ii" S4E_PROGRESS_DB="$W/ii.tsv" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/test_icon_ipl_suite.sh" 2>&1); rii=$?
[ "$rii" = 2 ] && [ ! -s "$W/ii.tsv" ] && echo "      $(grep -m1 -E 'REFUS' <<<"$oii" | cut -c1-200)"
quad II "$W/ii.tsv" "test_icon_ipl_suite.sh over a scratch package (rc $rii)"
echo "--- IB: test_icon_bench_suite.sh over a scratch S4E_HOME (sidecars beside each kernel; iconx at each deep kernel's .oracle_env) ---"
isides "$W/ib/corpus/benchmarks/icon"
oib=$(S4E_HOME="$W/ib" S4E_PROGRESS_DB="$W/ib0.tsv" timeout -k 5 1500 bash "$HERE/test_icon_bench_suite.sh" 2>&1); rib=$?
[ "$rib" = 2 ] && [ ! -s "$W/ib0.tsv" ] && echo "      $(grep -m1 -E 'REFUS' <<<"$oib" | cut -c1-200)"
remap "$W/ib0.tsv" 's/\t([a-z]+)\.icn\t(m[34])\t/\t\1\t\2\t/' > "$W/ib.tsv"
quad IB "$W/ib.tsv" "test_icon_bench_suite.sh over scratch kernels, three angles each (rc $rib)"
echo "--- IT: bench_triangulate_icon.sh over the same kernels (ICON_BENCH_DIR) ---"
oit=$(ICON_BENCH_DIR="$W/ib/corpus/benchmarks/icon" BUDGET_MS=300 timeout -k 5 1500 bash "$HERE/bench_triangulate_icon.sh" 2>&1); rit=$?
[ "$rit" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$oit" | cut -c1-200)"
pbtab "$oit" '$1 == u && $2 == m {print ($NF == "PASS" ? "PASS" : "FAIL"); exit}' > "$W/it.tsv"
quad IT "$W/it.tsv" "bench_triangulate_icon.sh over scratch kernels (rc $rit)"
# ITX: the triangulator's ORACLE row reads each kernel at its declared environment -- the deep kernels need MSTKSIZE=1000000 from their
# .oracle_env, so an iconx row that FAILs a deep kernel is a runner that dropped the oracle's declaration (fail once: the 2026-10-03 text
# without OENV reads deepdecl and deepnodecl iconx FAIL here while every SCRIP row is unchanged, which the quad alone cannot see).
nix=0; for u in $UNITS; do awk -v u="$u" '$1 == u && $2 == "iconx" && $NF == "PASS" {f = 1} END {exit !f}' <<<"$oit" && nix=$((nix+1)); done
[ "$nix" = 4 ] && ok ITX "bench_triangulate_icon.sh's iconx row passes all four kernels, the deep two at their declared MSTKSIZE" \
  || red ITX "bench_triangulate_icon.sh's iconx row passes $nix of 4 kernels -- the oracle ran without a kernel's .oracle_env"
echo "--- IR: test_icon_rung_suite.sh --corpus, --mode interp and --mode compile (each names its units) ---"
isides "$W/ir" rung
oi3=$(SCRIP="$SCRIP" timeout -k 5 900 bash "$HERE/test_icon_rung_suite.sh" --mode interp --corpus "$W/ir" 2>&1); ri3=$?
oi4=$(SCRIP="$SCRIP" timeout -k 5 900 bash "$HERE/test_icon_rung_suite.sh" --mode compile --corpus "$W/ir" 2>&1); ri4=$?
{ printf 'ts\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\n'
  for u in $UNITS; do printf 'x\tx\tx\tx\tx\tir\ticon\t%s\tm3\t%s\n' "$u" "$(awk -v u="$u" '$2 ~ ("_" u "$") {print $1; exit}' <<<"$oi3")"
                      printf 'x\tx\tx\tx\tx\tir\ticon\t%s\tm4\t%s\n' "$u" "$(awk -v u="$u" '$2 ~ ("_" u "$") {print $1; exit}' <<<"$oi4")"; done; } > "$W/ir.tsv"
quad IR "$W/ir.tsv" "test_icon_rung_suite.sh over a scratch --corpus of loose rungs (rc $ri3/$ri4)"
echo "--- IAR: test_icon_all_rungs.sh --corpus (mode 3 only: the runner runs --run alone) ---"
oiar=$(SCRIP="$SCRIP" timeout -k 5 900 bash "$HERE/test_icon_all_rungs.sh" --corpus "$W/ir" 2>&1); riar=$?
rlines "$oiar" m3 '($1 == "PASS" || $1 == "FAIL" || $1 == "BADEXIT") && $2 ~ ("_" u "$") {print $1; exit}' > "$W/iar.tsv"
quad IAR "$W/iar.tsv" "test_icon_all_rungs.sh over a scratch --corpus (rc $riar)" m3
echo "--- IBR: board_icon_rungs.sh over a scratch ALL.icn container (CORPUS); a red is named on its own line, an OOM red included ---"
mkdir -p "$W/ibr"; python3 - "$HERE" "$W" <<'PY2'
import sys; sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h
W = sys.argv[2]; src = []; ref = []
for i, u in enumerate(["deepdecl", "deepnodecl", "livedecl", "livenodecl"], 1):
    b = h.make_banner_cfg(i, u, "#", ""); src.append(b + "\n" + open(f"{W}/icn/{u}.icn").read()); ref.append(b + "\n" + open(f"{W}/icn/{u}.ref").read())
open(f"{W}/ibr/ALL.icn", "w").write("".join(src)); open(f"{W}/ibr/ALL.ref", "w").write("".join(ref))
PY2
{ printf 'rank,entry,origin,family,kind,xfail,n_lines,heap_kb,stack_kb,compile_args,run_args\n'; i=1
  for u in $UNITS; do printf '%s,%s,gate__%s,gate,block,0,7,%s,%s,,\n' "$i" "$u" "$u" "${IHEAP[$u]}" "${ISTACK[$u]}"; i=$((i+1)); done; } > "$W/ibr/ALL.csv"
oibr=$(CORPUS="$W/ibr" S4E_PROGRESS_DB="$W/ibr.db" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/board_icon_rungs.sh" 2>&1); ribr=$?
pbtab "$oibr" '{k = (m == "m3" ? "mode-3" : "mode-4")} $1 ~ /^(FAIL|OOM|CRASH|HANG|UNPROVEN)$/ && $2 == m && $3 == (u ":") {r = "FAIL"} index($0, k " ") == 1 && / \/ 4$/ {t = 1} END {print (r ? r : (t ? "PASS" : ""))}' > "$W/ibr.tsv"
quad IBR "$W/ibr.tsv" "board_icon_rungs.sh over a scratch container, every red named (rc $ribr)"

# THE PASCAL RUNNERS (the coo 2026-10-03). ONE witness pair, MEASURED 2026-10-03 on f4fde6099 in both modes, fpc -Miso answering both at its
# defaults: deep = d(30000), a non-tail recursion -- ERROR 246 at the shipped 4 MB stack, 30000 at -s65536k; live = a 30000-node list built
# with new -- error 204 at the HARD CAP at -d2048k, 30000 at the default cap. The bench kernels read their reps from stdin (the corpus
# convention) and DISPOSE each rep's list: Pascal has no collector for new'd records, so a kernel that drops its list without dispose keeps
# every rep live (measured: 1,864,208 blocks at the 128 MB cap after 31 reps, where fpc holds the same 960000 nodes in 30 MB).
declare -A PAHEAP=([deepdecl]=131072 [deepnodecl]=131072 [livedecl]=2048 [livenodecl]=131072)
declare -A PASTACK=([deepdecl]=65536 [deepnodecl]=4096 [livedecl]=4096 [livenodecl]=4096)
mkdir -p "$W/pas"
cat > "$W/pas/deep.pas" <<'PAS'
program deepk(input, output);
var reps, rep, r: integer;
function d(n: integer): integer;
begin
  if n = 0 then d := 0 else d := d(n - 1) + 1
end;
begin
  readln(reps);
  r := 0;
  for rep := 1 to reps do r := d(30000);
  writeln(r)
end.
PAS
cat > "$W/pas/live.pas" <<'PAS'
program livek(input, output);
type p = ^node;
     node = record v: integer; s: packed array[1..8] of char; next: p end;
var h, q: p; i, reps, rep: integer;
begin
  readln(reps);
  i := 0;
  for rep := 1 to reps do begin
    h := nil;
    for i := 1 to 30000 do begin new(q); q^.v := i; q^.s := 'abcdefgh'; q^.next := h; h := q end;
    i := 0; q := h;
    while q <> nil do begin i := i + 1; q := q^.next end;
    while h <> nil do begin q := h; h := h^.next; dispose(q) end
  end;
  writeln(i)
end.
PAS
pfile() { case "$1" in deep*) echo "$W/pas/deep.pas" ;; *) echo "$W/pas/live.pas" ;; esac; }
pacsv() {  # <package> <entry prefix>
  local i=1 u; printf '%s\n' "$HDR"
  for u in $UNITS; do printf '%s,%s%s,%s__%s%s,%s,16,1,0,%s,%s,,\n' "$i" "$2" "$u" "$1" "$2" "$u" "$1" "${PAHEAP[$u]}" "${PASTACK[$u]}"; i=$((i+1)); done; }
echo "--- SPF: test_pascal_fpc_suite.sh (FPC_SUITE scratch; each program at its ALL.csv row, reps 1 on stdin) ---"
mkdir -p "$W/spf"; for u in $UNITS; do cp "$(pfile "$u")" "$W/spf/$u.pas"; echo 1 > "$W/spf/$u.in"; printf '      30000\n' > "$W/spf/$u.ref"; done
pacsv fpc_tests "" > "$W/spf/ALL.csv"
ospf=$(FPC_SUITE="$W/spf" S4E_PROGRESS_DB="$W/spf.tsv" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/test_pascal_fpc_suite.sh" 2>&1); rspf=$?
[ "$rspf" = 2 ] && [ ! -s "$W/spf.tsv" ] && echo "      $(grep -m1 -E 'REFUS' <<<"$ospf" | cut -c1-200)"
quad SPF "$W/spf.tsv" "test_pascal_fpc_suite.sh over a scratch suite (rc $rspf)"
echo "--- SPW: test_pascal_wirth76_suite.sh (WIRTH76_SUITE scratch; each program at its ALL.csv row, reps 1 on stdin) ---"
mkdir -p "$W/spw"; for u in $UNITS; do cp "$(pfile "$u")" "$W/spw/$u.pas"; echo 1 > "$W/spw/$u.in"; printf '      30000\n' > "$W/spw/$u.ref"; done
pacsv wirth1976 "" > "$W/spw/ALL.csv"
ospw=$(WIRTH76_SUITE="$W/spw" S4E_PROGRESS_DB="$W/spw.tsv" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/test_pascal_wirth76_suite.sh" 2>&1); rspw=$?
[ "$rspw" = 2 ] && [ ! -s "$W/spw.tsv" ] && echo "      $(grep -m1 -E 'REFUS' <<<"$ospw" | cut -c1-200)"
quad SPW "$W/spw.tsv" "test_pascal_wirth76_suite.sh over a scratch suite (rc $rspw)"
echo "--- SPT: test_pascal_pat_suite.sh (PAT_SUITE scratch; the acceptance population iso7185pat*, graded live against fpc -Miso) ---"
mkdir -p "$W/spt"; for u in $UNITS; do cp "$(pfile "$u")" "$W/spt/iso7185pat_$u.pas"; echo 1 > "$W/spt/iso7185pat_$u.inp"; done
pacsv pat iso7185pat_ > "$W/spt/ALL.csv"
ospt=$(PAT_SUITE="$W/spt" S4E_PROGRESS_DB="$W/spt0.tsv" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/test_pascal_pat_suite.sh" 2>&1); rspt=$?
[ "$rspt" = 2 ] && [ ! -s "$W/spt0.tsv" ] && echo "      $(grep -m1 -E 'REFUS' <<<"$ospt" | cut -c1-200)"
remap "$W/spt0.tsv" 's/\tiso7185pat_([a-z]+)\t(m[34])\t/\t\1\t\2\t/' > "$W/spt.tsv"
quad SPT "$W/spt.tsv" "test_pascal_pat_suite.sh over a scratch acceptance population (rc $rspt)"
# The three Pascal timing arms run at LIN_TOL=1000000: each angle voids a rate whose three points are not a line, and load alone does that
# (the 2026-10-03/04 runs beside a suite pass read deepdecl's m3 or m4 cell NA, NONLINEAR, while the kernel ran to its answer); these arms ask
# whether the kernel RAN at its declared size, which a SKIP, DNF, NONZERO or correctness-fail still answers, never how linear its timing was.
# the bench kernels: sidecars beside each, reps from stdin, SCALE.tsv sized so each angle's slope is work and not startup (MEASURED
# 2026-10-03: fpc 0.06 ms/rep deep and 0.42 ms/rep live, SCRIP m3 2.5 ms/rep deep and 135 ms/rep live)
PB2="$W/spb/corpus/benchmarks/pascal"; mkdir -p "$PB2"
for u in $UNITS; do cp "$(pfile "$u")" "$PB2/$u.pas"; echo 1 > "$PB2/$u.in"; printf '      30000\n' > "$PB2/$u.ref"
  printf '%s\t%s\n' "$u" "${PAHEAP[$u]}" > "$PB2/$u.heap"; printf '%s\t%s\n' "$u" "${PASTACK[$u]}" > "$PB2/$u.stack"; done
printf '# SCALE -- the gate fixture: kernel, fpc reps, scrip reps\ndeepdecl\t4000\t100\ndeepnodecl\t4000\t100\nlivedecl\t500\t4\nlivenodecl\t500\t4\n' > "$PB2/SCALE.tsv"
printf '# EXCLUDED -- the gate fixture: none\n' > "$PB2/EXCLUDED.tsv"
echo "--- SPB: test_pascal_bench_suite.sh over a scratch S4E_HOME (three angles per kernel, both modes) ---"
ospb=$(S4E_HOME="$W/spb" S4E_PROGRESS_DB="$W/spb.tsv" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/test_pascal_bench_suite.sh" 2>&1); rspb=$?
[ "$rspb" = 2 ] && [ ! -s "$W/spb.tsv" ] && echo "      $(grep -m1 -E 'REFUS' <<<"$ospb" | cut -c1-200)"
quad SPB "$W/spb.tsv" "test_pascal_bench_suite.sh over scratch kernels (rc $rspb)"
echo "--- SPTM: test_bench_pascal_timed.sh, angle 1 (BENCH_DIR, KERNELS) -- its reps=1 correctness check runs m3 at the declaration ---"
ospm=$(BENCH_DIR="$PB2" KERNELS="$UNITS" LIN_TOL=1000000 SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/test_bench_pascal_timed.sh" 2>&1); rspm=$?
[ "$rspm" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$ospm" | cut -c1-200)"
pbtab "$ospm" '$1 == u && $2 ~ /^([0-9.]+|NA|SKIP)$/ {print ($2 == "SKIP" ? "FAIL" : "PASS"); exit}' > "$W/spm.tsv"
quad SPTM "$W/spm.tsv" "test_bench_pascal_timed.sh's reps=1 check over scratch kernels (rc $rspm)" m3
# and m4: the angle runs the compiled binary at the same switches, which a 30000-deep recursion only survives with its declared stack
awk '$1 == "deepdecl" && $4 ~ /^[0-9][0-9.]*$/ {f = 1} END {exit !f}' <<<"$ospm" \
  && ok SPTM4 "test_bench_pascal_timed.sh times deepdecl in m4 -- the binary ran 30000 deep, so its declared stack reached it" \
  || red SPTM4 "test_bench_pascal_timed.sh has no m4 reading for deepdecl ($(awk '$1 == "deepdecl"' <<<"$ospm" | head -1 | cut -c1-120))"
echo "--- SPFI: bench_pascal_fixed_iter.sh, angle 2 (BENCH_DIR; reps from the scratch SCALE.tsv) ---"
ospi=$(BENCH_DIR="$PB2" LIN_TOL=1000000 SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/bench_pascal_fixed_iter.sh" 2>&1); rspi=$?
[ "$rspi" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$ospi" | cut -c1-200)"
pbtab "$ospi" "$(num 5 6)" > "$W/spi.tsv"
quad SPFI "$W/spi.tsv" "bench_pascal_fixed_iter.sh over scratch kernels (rc $rspi)"

echo "--- SPTR: bench_triangulate_pascal.sh (PASCAL_DIR handed to both angles; a cell is graded by its fixed-iteration rate) ---"
optr=$(PASCAL_DIR="$PB2" KERNELS="$UNITS" LIN_TOL=1000000 OUT_TSV="$W/sptr.tri.tsv" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 1500 bash "$HERE/bench_triangulate_pascal.sh" 2>&1); rptr=$?
[ "$rptr" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$optr" | cut -c1-200)"
{ printf 'ts\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\n'
  for u in $UNITS; do for m in m3 m4; do printf 'x\tx\tx\tx\tx\tptr\tpascal\t%s\t%s\t%s\n' "$u" "$m" \
    "$(awk -F'\t' -v u="$u" -v m="$m" 'function pos(v) {return v ~ /^[0-9][0-9.]*$/ && v + 0 > 0} $1 == u && $2 == m {print (pos($3) || pos($4) ? "PASS" : "FAIL"); exit}' "$W/sptr.tri.tsv" 2>/dev/null)"; done; done; } > "$W/sptr.tsv"
# a cell PASSES when EITHER angle measured a positive rate: each angle drops a rate to NA when its own linearity check fails, which load
# alone can do (the 2026-10-03 21:2x run, beside pass 34, read deepdecl m4 and livenodecl NA in angle 2 while SPFI's own run of that angle
# passed); a kernel that died at its size reads 0 or NA in BOTH, so the pair still separates
quad SPTR "$W/sptr.tsv" "bench_triangulate_pascal.sh over scratch kernels, a positive rate in either angle of its TSV (rc $rptr)"

# THE RAKU RUNNERS (the coo 2026-10-03). ONE witness pair, MEASURED 2026-10-03 on the b1bee0c53 build in both modes, Rakudo answering both
# at its defaults: deep = d(30000) -- ERROR 246 at the shipped 4 MB stack, 30000 at -s65536k; live = 30000 two-element arrays pushed onto
# one Array -- error 204 at the HARD CAP at -d2048k, 30000 at the default cap (re-measured 2026-10-04 on 690d3a474 after hq_raku's in-place
# push: 10000 fit in 2 MB once push stopped copying, so the witness went back to 30000, which now runs in 0.06 s). The bench kernels are SELF-TIMED (the wall_us/wall_ms WORK bracket the
# timed angle and the triangulator loop), the live list inside the bracket so each looped iteration starts empty.
declare -A RKHEAP=([deepdecl]=131072 [deepnodecl]=131072 [livedecl]=2048 [livenodecl]=131072)
declare -A RKSTACK=([deepdecl]=65536 [deepnodecl]=4096 [livedecl]=4096 [livenodecl]=4096)
echo "--- RR: raku_roast_scoreboard.sh --run (RAKU_ROAST_TREE, RAKU_ROAST_MANIFEST, RAKU_ROAST_DCSV; TAP graded per file) ---"
RRT="$W/rr/tree/S99-gate"; mkdir -p "$RRT" "$W/rr/home"
for u in $UNITS; do case "$u" in
  deep*) printf 'sub d($n) { $n == 0 ?? 0 !! d($n - 1) + 1 }\nmy $r = d(30000);\nsay "1..1";\nsay $r == 30000 ?? "ok 1 - deep" !! "not ok 1 - deep";\n' ;;
  *) printf 'my @l;\nfor 1..30000 -> $i { @l.push([$i, "abcdefgh"]) }\nmy $n = @l.elems;\nsay "1..1";\nsay $n == 30000 ?? "ok 1 - live" !! "not ok 1 - live";\n' ;;
  esac > "$RRT/$u.t"; done
{ echo "# the gate fixture"; for u in $UNITS; do echo "S99-gate/$u.t"; done; } > "$W/rr/manifest"
{ printf '%s\n' "$HDR"; i=1; for u in $UNITS; do printf '%s,S99-gate/%s,roast__S99-gate/%s,roast,5,0,0,%s,%s,,\n' "$i" "$u" "$u" "${RKHEAP[$u]}" "${RKSTACK[$u]}"; i=$((i+1)); done; } > "$W/rr/ALL.csv"
orr=$(S4E_HOME="$W/rr/home" RAKU_ROAST_TREE="$W/rr/tree" RAKU_ROAST_MANIFEST="$W/rr/manifest" RAKU_ROAST_DCSV="$W/rr/ALL.csv" S4E_PROGRESS_DB="$W/rr0.tsv" timeout -k 5 900 bash "$HERE/raku_roast_scoreboard.sh" --run 2>&1); rrr=$?
[ "$rrr" = 2 ] && [ ! -s "$W/rr0.tsv" ] && echo "      $(grep -m1 -E 'REFUS' <<<"$orr" | cut -c1-200)"
remap "$W/rr0.tsv" 's/\tS99-gate\/([a-z]+)\t(m[34])\t/\t\1\t\2\t/' > "$W/rr.tsv"
quad RR "$W/rr.tsv" "raku_roast_scoreboard.sh --run over a scratch roast tree (rc $rrr)"
RK="$W/rk"; mkdir -p "$RK"; cp "$S4E/corpus/benchmarks/raku/prelude_rakudo.rakumod" "$RK/" 2>/dev/null \
  || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no prelude_rakudo.rakumod under $S4E/corpus/benchmarks/raku"; gate_stamp; exit 2; }
for u in $UNITS; do case "$u" in
  deep*) printf 'sub d($n) { $n == 0 ?? 0 !! d($n - 1) + 1 }\nmy $t0 = wall_us(); my $m0 = wall_ms();\nmy $r = d(30000);\nmy $t1 = wall_us(); my $m1 = wall_ms();\nsay $r;\nnote("BENCH kernel=%s work_us=" ~ ($t1 - $t0) ~ " work_ms=" ~ ($m1 - $m0));\n' "$u"; echo 30000 > "$RK/$u.ref" ;;
  *) printf 'my $t0 = wall_us(); my $m0 = wall_ms();\nmy $n = do { my @l; for 1..30000 -> $i { @l.push([$i, "abcdefgh"]) }; @l.elems };\nmy $t1 = wall_us(); my $m1 = wall_ms();\nsay $n;\nnote("BENCH kernel=%s work_us=" ~ ($t1 - $t0) ~ " work_ms=" ~ ($m1 - $m0));\n' "$u"; echo 30000 > "$RK/$u.ref" ;;
  esac > "$RK/$u.raku"
  printf '%s\t%s\n' "$u" "${RKHEAP[$u]}" > "$RK/$u.heap"; printf '%s\t%s\n' "$u" "${RKSTACK[$u]}" > "$RK/$u.stack"; done
{ printf '# the gate fixture\nkernel\tN\n'; for u in $UNITS; do printf '%s\t1\n' "$u"; done; } > "$RK/fixed-iter-n.tsv"
echo "--- RB: test_raku_bench_suite.sh (BENCH_RAKU_DIR; a population outside the corpus writes no rows, so its printed verdicts are read) ---"
orb=$(BENCH_RAKU_DIR="$RK" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/test_raku_bench_suite.sh" 2>&1); rrb=$?
[ "$rrb" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$orb" | cut -c1-200)"
pbtab "$orb" '$1 == u && $2 == m && $6 ~ /^(PASS|FAIL)$/ {print $6; exit}' > "$W/rb.tsv"
quad RB "$W/rb.tsv" "test_raku_bench_suite.sh over scratch kernels (rc $rrb)"
echo "--- RTM: test_bench_raku_timed.sh, angle 1 (RAKU_DIR, KERNELS) ---"
ortm=$(RAKU_DIR="$RK" KERNELS="$UNITS" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/test_bench_raku_timed.sh" 2>&1); rrtm=$?
[ "$rrtm" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$ortm" | cut -c1-200)"
pbtab "$ortm" "$(num 2 3)" > "$W/rtm.tsv"
quad RTM "$W/rtm.tsv" "test_bench_raku_timed.sh over scratch kernels (rc $rrtm)"
echo "--- RFI: bench_raku_fixed_iter.sh, angle 2 (RAKU_DIR, its fixed-iter-n.tsv) ---"
orfi=$(RAKU_DIR="$RK" KERNELS="$UNITS" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/bench_raku_fixed_iter.sh" 2>&1); rrfi=$?
[ "$rrfi" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$orfi" | cut -c1-200)"
pbtab "$orfi" "$(num 3 4)" > "$W/rfi.tsv"
quad RFI "$W/rfi.tsv" "bench_raku_fixed_iter.sh over scratch kernels (rc $rrfi)"
echo "--- RTR: bench_triangulate_raku.sh (RAKU_DIR; a SCRIP row is graded by the reps it verified, n/3) ---"
ortr=$(RAKU_DIR="$RK" KERNELS="$UNITS" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/bench_triangulate_raku.sh" 2>&1); rrtr=$?
[ "$rrtr" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$ortr" | cut -c1-200)"
pbtab "$ortr" '$1 == u && $2 == m && $3 ~ /^[0-9]+\/[0-9]+$/ {split($3, r, "/"); print (r[1] > 0 ? "PASS" : "FAIL"); exit}' > "$W/rtr.tsv"
quad RTR "$W/rtr.tsv" "bench_triangulate_raku.sh over scratch kernels (rc $rrtr)"

# THE SNOCONE AND REBUS BENCHES (the coo 2026-10-03). Witnesses MEASURED 2026-10-03 on the b1bee0c53 build, both modes: Snocone d(20000)
# and Rebus d(50000) -- ERROR 246 at the shipped 4 MB stack (Snocone from 10000 deep, Rebus only past 20000), their answer at -s262144k;
# live = the SNOBOL4 witness's 30000-entry TABLE of DUPL('x',100) -- error 204 at the HARD CAP at -d2048k, built 30000 at the default.
CR="$W/cr"; CSC="$CR/corpus/benchmarks/snocone"; CSN="$CR/corpus/benchmarks/snobol4"; CRB="$CR/corpus/benchmarks/rebus"; mkdir -p "$CSC" "$CSN" "$CRB"
for u in $UNITS; do case "$u" in
  deep*) printf 'procedure r(n) {\n    if (EQ(n, 0)) { r = 0; } else { r = r(n - 1) + 1; }\n}\nOUTPUT = %sdepth=%s r(20000);\n' "'" "'" > "$CSC/$u.sc"; echo depth=20000 > "$CSC/$u.ref"
         printf 'function r(n)\n  if n = 0 then return 0\n  return r(n - 1) + 1\nend\n\nfunction main()\n  OUTPUT := "depth=" || r(50000)\nend\n' > "$CRB/$u.reb"; echo depth=50000 > "$CRB/$u.ref"
         sed 's/R(50000)/R(20000)/' "$W/deep.sno" > "$CSN/${u}_twin.sno" ;;
  *) printf 't = TABLE();\ni = 0;\nwhile (LT(i, 30000)) {\n    i = i + 1;\n    t[i] = DUPL(%sx%s, 100);\n}\nOUTPUT = %sbuilt %s i;\n' "'" "'" "'" "'" > "$CSC/$u.sc"; echo 'built 30000' > "$CSC/$u.ref"
     printf 'function main()\n  local t, i\n  t := table()\n  i := 0\n  while i < 30000 do {\n    i := i + 1\n    t[i] := dupl("x", 100)\n  }\n  OUTPUT := "built " || i\nend\n' > "$CRB/$u.reb"; echo 'built 30000' > "$CRB/$u.ref"
     cp "$W/live.sno" "$CSN/${u}_twin.sno" ;;
  esac
  for d in "$CSC" "$CRB"; do printf '%s\t%s\n' "$u" "${HEAP[$u]}" > "$d/$u.heap"; printf '%s\t%s\n' "$u" "${STACK[$u]}" > "$d/$u.stack"; done; done
echo "--- SCB: test_snocone_bench_suite.sh over a scratch S4E_HOME (three angles, both modes) ---"
oscb=$(S4E_HOME="$CR" S4E_PROGRESS_DB="$W/scb0.tsv" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/test_snocone_bench_suite.sh" 2>&1); rscb=$?
[ "$rscb" = 2 ] && [ ! -s "$W/scb0.tsv" ] && echo "      $(grep -m1 -E 'REFUS' <<<"$oscb" | cut -c1-200)"
remap "$W/scb0.tsv" 's/\t([a-z]+)\.sc\t(m[34])\t/\t\1\t\2\t/' > "$W/scb.tsv"
quad SCB "$W/scb.tsv" "test_snocone_bench_suite.sh over scratch kernels (rc $rscb)"
echo "--- RBB: test_rebus_bench_suite.sh (BENCH_REBUS_DIR; a population outside the corpus writes no rows, so its printed verdicts are read) ---"
orbb=$(BENCH_REBUS_DIR="$CRB" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/test_rebus_bench_suite.sh" 2>&1); rrbb=$?
[ "$rrbb" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$orbb" | cut -c1-200)"
pbtab "$orbb" '$1 == u && $2 == m && $6 ~ /^(PASS|FAIL)$/ {print $6; exit}' > "$W/rbb.tsv"
quad RBB "$W/rbb.tsv" "test_rebus_bench_suite.sh over scratch kernels (rc $rrbb)"
# the two callgrind boards: a numeric Ir cell is a run that finished; valgrind is given the declared stack plus 1 MB (--main-stacksize)
irq() { pbtab "$1" '$1 == u {v = (m == "m3" ? $2 : $3); print (v ~ /^[0-9]+$/ ? "PASS" : "FAIL"); exit}'; }
echo "--- RBT: bench_triangulate_rebus.sh, callgrind Ir (S4E_HOME, KERNELS) ---"
orbt=$(S4E_HOME="$CR" KERNELS="$UNITS" IR_TMO=300 SCRIP="$SCRIP" timeout -k 5 1800 bash "$HERE/bench_triangulate_rebus.sh" 2>&1); rrbt=$?
[ "$rrbt" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$orbt" | cut -c1-200)"
irq "$orbt" > "$W/rbt.tsv"; quad RBT "$W/rbt.tsv" "bench_triangulate_rebus.sh over scratch kernels (rc $rrbt)"
echo "--- SCT: bench_triangulate_snocone.sh, callgrind Ir against SPITBOL (S4E_HOME, KERNELS with each kernel's SNOBOL4 twin) ---"
osct=$(S4E_HOME="$CR" KERNELS="$(for u in $UNITS; do printf '%s:%s_twin ' "$u" "$u"; done)" IR_TMO=300 SCRIP="$SCRIP" timeout -k 5 1800 bash "$HERE/bench_triangulate_snocone.sh" 2>&1); rsct=$?
[ "$rsct" = 2 ] && echo "      $(grep -m1 -E 'REFUS' <<<"$osct" | cut -c1-200)"
irq "$osct" > "$W/sct.tsv"; quad SCT "$W/sct.tsv" "bench_triangulate_snocone.sh over scratch kernels (rc $rsct)"

# THE COO'S OWN (the coo 2026-10-03): the monitor, the port tracer and the area smoke, over the SNOBOL4 witnesses.
echo "--- MON: monitor_run.sh --oracle (SCRIP against the SPITBOL fork in lock-step; sbl answers both witnesses at its default) ---"
mkdir -p "$W/mon"; for u in $UNITS; do case "$u" in deep*) sed 's/R(50000)/R(30000)/' "$W/deep.sno" ;; *) cat "$W/live.sno" ;; esac > "$W/mon/$u.sno"
  printf '%s\t%s\n' "$u" "${HEAP[$u]}" > "$W/mon/$u.heap"; printf '%s\t%s\n' "$u" "${STACK[$u]}" > "$W/mon/$u.stack"; done
{ printf 'ts\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\n'
  for u in $UNITS; do omon=$(timeout -k 5 600 bash "$HERE/monitor_run.sh" "$W/mon/$u.sno" --oracle 2>&1); rmon=$?
    echo "      $u: rc $rmon -- $(grep -m1 -E '^\[monitor_run\] (AGREE|DIVERGE|UNGRADED)|^REFUSE' <<<"$omon" | cut -c1-110)" >&2
    printf 'x\tx\tx\tx\tx\tmon\tsnobol4\t%s\tm3\t%s\n' "$u" "$([ "$rmon" = 0 ] && echo PASS || echo FAIL)"; done; } > "$W/mon.tsv" 2> "$W/mon.notes"
cat "$W/mon.notes"
quad MON "$W/mon.tsv" "monitor_run.sh --oracle, scr at the unit's declaration against spl (rc 0 = the run reached the oracle's end)" m3
echo "--- PT: test_gate_sno_port_trace.sh --cut over a scratch rungs container (lib_port_trace.sh; its answer column, mode 3) ---"
PTD="$W/pt/corpus/tests/snobol4"; mkdir -p "$PTD" "$W/pt/corpus/include" "$W/pt/corpus/library"
python3 - "$HERE" "$W" "$PTD" <<'PY2'
import sys; sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h
W, D = sys.argv[2], sys.argv[3]
H = {"deepdecl": (131072, 262144), "deepnodecl": (131072, 4096), "livedecl": (2048, 4096), "livenodecl": (131072, 4096)}
src = []; ref = []; rows = ["rank,entry,origin,family,kind,xfail,n_lines,heap_kb,stack_kb,compile_args,run_args,gatefeat"]
for i, u in enumerate(H, 1):
    w = "deep" if u.startswith("deep") else "live"; b = h.make_banner(i, u)
    src.append(b + "\n" + open(f"{W}/{w}.sno").read()); ref.append(b + "\n" + open(f"{W}/{w}.ref").read())
    rows.append(f"{i},{u},gate__{u},gate,block,0,5,{H[u][0]},{H[u][1]},,,1")
open(f"{D}/ALL.sno", "w").write("".join(src)); open(f"{D}/ALL.ref", "w").write("".join(ref)); open(f"{D}/ALL.csv", "w").write("\n".join(rows) + "\n")
PY2
opt=$(S4E_HOME="$W/pt" FAMILIES=gate SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 bash "$HERE/test_gate_sno_port_trace.sh" --cut 2>&1); rpt=$?
[ "$rpt" = 2 ] && echo "      $(grep -m1 -E 'UNPROVEN|REFUS' <<<"$opt" | cut -c1-200)"
pbtab "$opt" '$1 == ("gate__" u) {a = $NF; sub(/^answer=/, "", a); print (a == "ok" ? "PASS" : "FAIL"); exit}' > "$W/pt.tsv"
quad PT "$W/pt.tsv" "lib_port_trace.sh through test_gate_sno_port_trace.sh --cut (rc $rpt)" m3
echo "--- AS: corpus_suite_harness.py smoke (THE AREA SMOKE) over the same container's feature column ---"
oas=$(S4E_HOME="$W/pt" SCRIP="$SCRIP" RT_DIR="$RT" timeout -k 5 900 python3 "$HERE/corpus_suite_harness.py" smoke -- snobol4:gatefeat 2>&1); ras=$?
{ printf 'ts\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\n'
  for u in $UNITS; do l=$(grep -m1 "^AREA_SMOKE_ENTRY .* entry=$u " <<<"$oas")
    for m in m3 m4; do printf 'x\tx\tx\tx\tx\tas\tsnobol4\t%s\t%s\t%s\n' "$u" "$m" "$(sed -nE "s/.* $m=([A-Z]+).*/\1/p" <<<"$l")"; done; done; } > "$W/as.tsv"
quad AS "$W/as.tsv" "the area smoke over a scratch feature column (rc $ras)"

echo "------------------------------------------------------------"
echo "population: $((PASS+FAIL)) verdict(s): the premise W and every runner family -- SNOBOL4 H D P1 P2 L SF X64 X32 TP GS AIS; Prolog PBS PBM PB4 PBT PBF PBP PBV PI PG PS PR PL; Icon IA IJ II IB IT ITX IR IAR IBR; Pascal SPF SPW SPT SPB SPTM SPTM4 SPFI SPTR; Raku RR RB RTM RFI RTR; Snocone and Rebus SCB RBB RBT SCT; the monitor MON, the port tracer PT, the area smoke AS -- each over deepdecl/deepnodecl/livedecl/livenodecl in the modes the runner runs (the bar scripts grade through their angles and are read there)"
if [ "$FAIL" -eq 0 ]; then echo "GATE PASS [$GATE_NAME]: every runner family passes each unit's declared heap and stack in the modes it runs"; gate_stamp; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $FAIL red"; gate_stamp; exit 1
