#!/usr/bin/env bash
export SCRIP_DIAG=0
# bench_stages.sh <snobol4|raku> [--reps R] [--only "k1 k2"] [--prog FILE --input FILE] -- each program's RUNTIME and its START-UP+COMPILE, per engine.
# THE METHOD (ceo CEO-1987; Lon 2026-10-26, in-chat to the ceo, verbatim: "The precise time-stamp for the first line and last line of the program
# should be gathered." · "why is not a timing call injected at first source line and last source line sufficient to measure RUNTIME?" · "To report
# compile-time from SCRIP would be total process exec_time - (END_TIME - START_TIME), where END and START times are those just mentioned."): the
# language's wrapper generator writes the program VERBATIM with a clock read at its first line and one at its last (--mode once), the SAME copy runs
# under the rival, SCRIP mode 3 and the mode-4 binary, each run under the external stopwatch tools/bench_rusage; RUNTIME = last - first (the
# program's own BENCH line), START+COMPILE = the stopwatch's elapsed - RUNTIME. For SPITBOL and mode 3 that is process start-up plus the compile
# (both compile every run); for the mode-4 binary it is start-up alone (its compile ran before, by scrip --compile and the link). No hook in any
# compiler: the clock reads are lines of the program. Every run's stdout is held to the program's .ref (or, with --prog, to the rival's answer).
# Medians over the good runs of R (default 5); a run with a wrong answer or no BENCH line is counted and named, never timed. EXIT 0 every run
# of every cell measured; 1 a run failed; 2 REFUSED.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; S4E="$(cd "$ROOT/.." && pwd)"
LANG_="${1:-}"; shift || true
REPS=5; ONLY=""; PROG=""; PIN=""
while [ $# -gt 0 ]; do case "$1" in --reps) REPS="$2"; shift 2;; --only) ONLY="$2"; shift 2;; --prog) PROG="$2"; shift 2;; --input) PIN="$2"; shift 2;; *) echo "⛔ REFUSED: unknown argument $1" >&2; exit 2;; esac; done
. "$HERE/lib_oracle_flags.sh" || { echo "⛔ REFUSED: cannot load lib_oracle_flags.sh" >&2; exit 2; }
. "$HERE/lib_declared_arena.sh" || { echo "⛔ REFUSED: cannot load lib_declared_arena.sh" >&2; exit 2; }
SCRIP="$ROOT/scrip"; RT="$ROOT/out"; WRAP="$ROOT/tools/bench_rusage"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED: scrip not built ($SCRIP)" >&2; exit 2; }
[ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "⛔ REFUSED: tools/bench_rusage did not build" >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
case "$LANG_" in
  snobol4) GEN=(python3 "$HERE/bench_wrap_snobol4.py" --mode once); EXT=sno; D="$S4E/corpus/benchmarks/snobol4"; RIVAL=sbl; RBIN="$(sbl_clean_bin)"
           mkdir -p "$W/cwd" && cp -p "$S4E/corpus/include/"*.inc "$W/cwd/" ;;
  raku)    GEN=(python3 "$HERE/bench_wrap_raku.py" --mode once); EXT=raku; D="$S4E/corpus/benchmarks/raku"; RIVAL=rakudo; RBIN="$(rakudo_bin)"
           mkdir -p "$W/cwd" "$W/prelude" && cp -p "$D/prelude_rakudo.rakumod" "$W/prelude/" && cp -p "$D/"*.json "$W/" ;;
  *) echo "⛔ REFUSED: usage: $0 <snobol4|raku> [--reps R] [--only \"k1 k2\"] [--prog FILE --input FILE]" >&2; exit 2 ;;
esac
[ -x "$RBIN" ] || { echo "⛔ REFUSED: no rival executable ($RBIN)" >&2; exit 2; }
if [ -n "$PROG" ]; then POP=("$PROG"); else POP=(); for f in "$D"/*."$EXT"; do k="$(basename "$f" ."$EXT")"; [ -f "$D/$k.ref" ] || continue; grep -qx "$k"$'\t'.* "$D/OUTSIDE.tsv" 2>/dev/null && continue; [ -n "$ONLY" ] && ! grep -qw -- "$k" <<<"$ONLY" && continue; POP+=("$f"); done; fi
[ "${#POP[@]}" -gt 0 ] || { echo "⛔ REFUSED: no program to measure" >&2; exit 2; }
med() { sort -n | awk '{a[NR]=$1} END{if (NR==0) print "-"; else if (NR%2) print a[(NR+1)/2]; else printf "%.0f\n", (a[NR/2]+a[NR/2+1])/2}'; }
ms() { awk -v v="$1" 'BEGIN{ if (v=="-") print "-"; else printf "%.3f", v/1e6 }'; }
echo "BENCH STAGES -- $LANG_, ${#POP[@]} program(s), $REPS run(s) each, medians; rival $RBIN; SCRIP $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null) RT_OPT=$(readelf --debug-dump=info "$RT/libscrip_rt.so" 2>/dev/null | grep -m1 -o ' -O[0-3sg]' | tr -d ' ') load=$(cut -d' ' -f1 /proc/loadavg)"
printf '%-34s %-7s %12s %12s %16s  %s\n' program engine total_ms runtime_ms start+compile_ms check
RC=0
for f in "${POP[@]}"; do
  k="$(basename "$f" ."$EXT")"; IN="${PIN:-/dev/null}"; [ -z "$PIN" ] && [ -f "$D/$k.in" ] && IN="$D/$k.in"
  SWD="$(declared_switches_beside "$f")" && OAD="$(declared_oracle_args_beside "$f")" || { echo "⛔ $k: declared sizes refused"; RC=1; continue; }
  "${GEN[@]}" -o "$W/$k.once.$EXT" "$f" 2> "$W/gen.err" || { printf '%-34s %-7s %s\n' "$k" all "UNMEASURED -- the generator refused: $(head -1 "$W/gen.err" | cut -c1-120)"; RC=1; continue; }
  if [ -n "$PROG" ]; then (cd "$W/cwd" && timeout -k 5 300 "$RBIN" $(sbl_lang_flags 2>/dev/null) $OAD "$f" < "$IN" > "$W/want" 2>/dev/null); else cp "$D/$k.ref" "$W/want"; fi
  (cd "$W/cwd" && "$SCRIP" --compile --out="$W/$k.s" "$W/$k.once.$EXT" < /dev/null 2> "$W/c.err") && gcc "$W/$k.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$W/$k.m4" 2>> "$W/c.err" || { echo "⛔ $k m4 does not build: $(head -1 "$W/c.err" | cut -c1-120)"; RC=1; }
  for e in "$RIVAL" m3 m4; do
    : > "$W/tot"; : > "$W/run"; : > "$W/oh"; chk=ok; bad=0; why=""
    for ((i=1;i<=REPS;i++)); do
      case "$e" in
        sbl)    (cd "$W/cwd" && "$WRAP" timeout -k 5 300 "$RBIN" $(sbl_lang_flags) $OAD "$W/$k.once.$EXT" < "$IN" > "$W/o" 2> "$W/e") ;;
        rakudo) (cd "$W/cwd" && "$WRAP" timeout -k 5 300 "$RBIN" -I"$W/prelude" -Mprelude_rakudo "$W/$k.once.$EXT" < "$IN" > "$W/o" 2> "$W/e") ;;
        m3)     (cd "$W/cwd" && "$WRAP" timeout -k 5 300 "$SCRIP" --run $SWD "$W/$k.once.$EXT" < "$IN" > "$W/o" 2> "$W/e") ;;
        m4)     [ -x "$W/$k.m4" ] || { chk="no binary"; break; }; (cd "$W/cwd" && "$WRAP" timeout -k 5 300 "$W/$k.m4" $SWD < "$IN" > "$W/o" 2> "$W/e") ;;
      esac
      el="$(grep -o 'elapsed_ns=[0-9]*' "$W/e" | tail -1 | cut -d= -f2)"; ns="$(grep -o 'BENCH mode=once kernel=main iters=1 ns=[0-9]*' "$W/e" | tail -1 | sed 's/.*ns=//')"
      if ! cmp -s "$W/o" "$W/want"; then bad=$((bad+1)); [ -n "$why" ] || why="wrong answer: $(grep -v BENCH "$W/e" | head -1 | cut -c1-90)"; continue; fi
      if [ -z "$el" ] || [ -z "$ns" ]; then bad=$((bad+1)); [ -n "$why" ] || why="no BENCH line"; continue; fi
      echo "$el" >> "$W/tot"; echo "$ns" >> "$W/run"; echo $((el - ns)) >> "$W/oh"
    done
    [ "$bad" = 0 ] || chk="FAILED $bad of $REPS runs ($why)"
    [ "$chk" = ok ] || RC=1
    printf '%-34s %-7s %12s %12s %16s  %s\n' "$k" "$e" "$(ms "$(med < "$W/tot")")" "$(ms "$(med < "$W/run")")" "$(ms "$(med < "$W/oh")")" "$chk"
  done
done
exit "$RC"
