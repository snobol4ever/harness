#!/usr/bin/env bash
# honest_icon_bench.sh — like test_icon_bench_corpus.sh but it DIFFS OUTPUT.
# The stock runner grades on (rc==0 && output non-empty), which cannot distinguish
# "ran the workload fast" from "skipped the workload". This one compares against iconx.
#
# Usage: SCRIPDIR=/path/to/SCRIP bash honest_icon_bench.sh [prog ...]
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255), Icon-aware since row icon-oracle-accessors-shared." >&2; exit 3; }
SCRIPDIR="${SCRIPDIR:-$S4A/work/SCRIP}"
SCRIP="$SCRIPDIR/scrip"
RTDIR="$SCRIPDIR/out"
ICONT="${ICONT:-$(icont_bin)}" || exit 2
ICONX="${ICONX:-$(iconx_bin)}" || exit 2
CORPUS_SRC="${CORPUS_SRC:-$S4A/work/corpus/benchmarks/icon}"
REPS="${REPS:-3}"
# ⛔ SCRATCH ON /home, NEVER BARE /tmp, AND CLEANUP THAT SURVIVES A KILL (row icon-sweep-scratch-hardening, s267 outage).
# /tmp is the 125G ROOT partition; /home is a separate 503G one. This script is the SIBLING of honest_icon_correctness.sh --
# same corpus, same programs, `deal` in its default list -- and carried the identical unbounded-write shape that filled the
# root filesystem and stopped nineteen sessions. Fixed here BEFORE it detonated a second time.
SCRATCH_ROOT="${S4E_SCRATCH:-$S4E/.scratch}"
mkdir -p "$SCRATCH_ROOT" 2>/dev/null || { echo "REFUSING: cannot create scratch root $SCRATCH_ROOT -- set S4E_SCRATCH to a writable dir ON /home. Refusing rather than falling back to /tmp, which is the root partition." >&2; exit 2; }
WORK="$(mktemp -d "$SCRATCH_ROOT/honest_bench_XXXXXX")"
honest_bench_cleanup() { [ "${ICN_KEEP_WORK:-0}" = "1" ] && return 0; [ -n "${WORK:-}" ] && [ -d "$WORK" ] && rm -rf "$WORK"; return 0; }
trap honest_bench_cleanup EXIT INT TERM
# ⛔ OUTPUT CAP VIA `ulimit -f`, NOT A `head -c` PIPE -- DELIBERATE, AND THE REASON IS THAT THIS IS A TIMING HARNESS.
# A pipe inserts a process inside the timed region and measures its buffering along with the program. `ulimit -f` bounds the
# WRITE ITSELF in the subshell: the kernel raises SIGXFSZ at the limit, the runaway dies, and the timed path is untouched.
# The resulting non-zero rc is correct -- a program that blows the cap has not produced a usable time, and the script already
# treats a bad rc as a void measurement. ulimit -f counts 512-byte blocks.
CAP="${ICN_OUT_CAP:-67108864}"
CAP_BLOCKS=$(( CAP / 512 ))
export PATH="$(dirname "$ICONT"):$PATH"

mkdir -p "$WORK/corpus"
cp "$CORPUS_SRC"/*.icn "$CORPUS_SRC"/*.dat "$WORK/corpus/" 2>/dev/null
CORPUS="$WORK/corpus"
IPXIN="$WORK/ipxref_input.icn"; cat "$CORPUS"/*.icn > "$IPXIN"

declare -A STDIN ARGS LINKDEPS
STDIN[concord]="$CORPUS/concord.dat"; ARGS[concord]=""
STDIN[deal]="";                       ARGS[deal]="-h 1000"
STDIN[geddump]="$CORPUS/geddump.dat"; ARGS[geddump]=""
STDIN[ipxref]="$IPXIN";               ARGS[ipxref]=""
STDIN[queens]="";                     ARGS[queens]="-n10"
STDIN[rsg]="$CORPUS/rsg.dat";         ARGS[rsg]=""
STDIN[tgrlink]="";                    ARGS[tgrlink]="$CORPUS/tgrlink.dat"

progs="${*:-concord deal geddump ipxref queens rsg tgrlink}"

# post.icn's banner lines are nondeterministic across engines (&version/&host/&features/
# storage/collections/elapsed time). Strip them so the diff compares REAL PROGRAM OUTPUT.
strip_banner() {
  grep -avE '^(Icon Version|icon version|SCRIP|.*elapsed time =|regions|storage|collections|static|string|block|total|Linux|linux|.*/.*|Version|.*features.*)$' "$1" 2>/dev/null \
    | grep -avE '^\s*[0-9]+\s*$' | sed '/^$/d'
}

printf "%-9s | %-22s | %-24s | %-7s | %s\n" "PROGRAM" "ICONX (oracle)" "SCRIP m4" "SPEEDUP" "OUTPUT vs ORACLE"
printf -- "----------+------------------------+--------------------------+---------+------------------\n"

for name in $progs; do
  icn="$CORPUS/$name.icn"
  sin="${STDIN[$name]:-}"; [ -z "$sin" ] && sin=/dev/null
  read -ra a <<< "${ARGS[$name]}"
  read -ra ld <<< "${LINKDEPS[$name]:-}"

  # ---- oracle ----
  o="?"; obest=999999
  ( cd "$CORPUS" && "$ICONT" -s -o "$WORK/$name.icx" "$name.icn" ) >/dev/null 2>&1
  if [ -f "$WORK/$name.icx" ]; then
    for r in $(seq $REPS); do
      t0=$(date +%s%N); ( ulimit -f "$CAP_BLOCKS"; exec timeout -k 5 60 "$ICONX" "$WORK/$name.icx" "${a[@]}" >"$WORK/$name.orc.out" 2>/dev/null <"$sin" ); rc=$?
      t1=$(date +%s%N); ms=$(( (t1-t0)/1000000 )); [ $ms -lt $obest ] && obest=$ms
    done
    [ $rc -eq 0 ] && o="OK ${obest}ms $(wc -l <"$WORK/$name.orc.out")L" || o="rc=$rc"
  else o="COMPILEFAIL"; fi

  # ---- SCRIP m4 ----
  m="?"; mbest=999999; verdict="-"
  ( cd "$CORPUS" && timeout -k 5 60 "$SCRIP" --compile --target=x86 "$name.icn" "${ld[@]}" \
      >"$WORK/$name.s" 2>"$WORK/$name.cerr" )
  if [ -s "$WORK/$name.s" ] && gcc -no-pie "$WORK/$name.s" -L"$RTDIR" -lscrip_rt \
        -Wl,-rpath,"$RTDIR" -o "$WORK/$name.bin" 2>"$WORK/$name.lerr"; then
    for r in $(seq $REPS); do
      t0=$(date +%s%N); ( ulimit -f "$CAP_BLOCKS"; exec timeout -k 5 60 "$WORK/$name.bin" "${a[@]}" >"$WORK/$name.m4.out" 2>/dev/null <"$sin" ); rc=$?
      t1=$(date +%s%N); ms=$(( (t1-t0)/1000000 )); [ $ms -lt $mbest ] && mbest=$ms
    done
    if [ $rc -eq 0 ]; then
      m="OK ${mbest}ms $(wc -l <"$WORK/$name.m4.out")L"
    elif [ $rc -eq 124 ]; then m="TIMEOUT"; else m="RUNFAIL rc=$rc"; fi
  else
    m="EMITFAIL: $(grep -m1 -oE 'FATAL[^\n]{0,40}' "$WORK/$name.cerr" | head -c40)"
  fi

  # ---- the honest part: compare real program output ----
  # A post.icn-linked program runs this pass with output SUPPRESSED (write := 1), so its stdout is
  # a banner, not program output, and NO honest correctness verdict can be drawn from it here. The
  # banner carries per-run timings/storage stats that survive strip_banner, so such programs always
  # printed DIVERGE — a false red on concord/deal/ipxref/queens, all four of which are byte-identical
  # to the oracle when measured properly. Correctness for these lives in honest_icon_correctness.sh
  # (OUTPUT=1); this runner reports timing only.
  if [ -n "${LINKDEPS[$name]:-}" ] && [[ " ${LINKDEPS[$name]} " == *" post.icn "* ]]; then
    verdict="n/a (output suppressed - use honest_icon_correctness.sh)"
  elif [ -f "$WORK/$name.orc.out" ] && [ -f "$WORK/$name.m4.out" ]; then
    strip_banner "$WORK/$name.orc.out" > "$WORK/$name.orc.clean"
    strip_banner "$WORK/$name.m4.out"  > "$WORK/$name.m4.clean"
    ol=$(wc -l <"$WORK/$name.orc.clean"); ml=$(wc -l <"$WORK/$name.m4.clean")
    if cmp -s "$WORK/$name.orc.clean" "$WORK/$name.m4.clean"; then verdict="IDENTICAL ($ol L)"
    else verdict="DIVERGE orc=${ol}L scrip=${ml}L"; fi
  fi

  sp="-"
  if [ $obest -lt 999999 ] && [ $mbest -lt 999999 ] && [ $mbest -gt 0 ]; then
    sp=$(awk "BEGIN{printf \"%.2fx\", $obest/$mbest}")
  fi
  printf "%-9s | %-22s | %-24s | %-7s | %s\n" "$name" "$o" "$m" "$sp" "$verdict"
done
echo "workdir: $WORK"
echo
echo "SPEEDUP IS MEANINGLESS WITHOUT A CORRECTNESS VERDICT. A program that short-circuits its"
echo "workload looks FAST. Measured case (s164): rsg reported 2.83-3.40x while emitting 1000 blank"
echo "lines instead of the oracle's 5000 sentences - it was not fast, it was not working. Read a"
echo "speedup here ONLY for a program honest_icon_correctness.sh reports IDENTICAL; as of s165 that"
echo "is concord deal ipxref queens tgrlink micsum. geddump and rsg DIVERGE - their times are void."
