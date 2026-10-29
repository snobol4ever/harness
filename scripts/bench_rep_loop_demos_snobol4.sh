#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_rep_loop_demos_snobol4.sh -- LON'S TWO-ASPECT PRESENTATION LAW for the tier-1 -match demos.
# Row: bench-rep-loop-demo-harness (hq_P, 2026-08-28). Authority: ARCH-BENCH-CAMPAIGN-README-TABLES.md.
#
#   ASPECT 1  command-line elapsed -- the WHOLE PROCESS as a user runs it (compile included and
#             LABELED), external rusage, never engine self-timing.
#   ASPECT 2  in-program bracket -- TIME() read by the program itself either side of the FIXTURE,
#             so the MATCH phase is isolated from the pattern-COMPILE phase.
#
# ⛔ WHY ASPECT 2 EXISTS AT ALL, MEASURED NOT ASSUMED: at their committed inputs these demos are
# startup/compile dominated -- treebank-match spends 99.3% of its instructions COMPILING patterns and
# 0.7% matching, claws5-match 99.7%, json-match ~100%. A match-path cure measured on aspect 1 alone
# reads as noise no matter how large it is; that is how the s168 PT-3 collapse (a MEASURED 1.41x) sat
# shipped-but-disabled for eight days with every board green.
#
# ⛔⛔ THE TRAP THIS HARNESS EXISTS TO NOT FALL INTO, AND IT COST A 13x WRONG ANSWER IN CALIBRATION:
# THE FIRST MATCH PAYS LAZY PATTERN COMPILATION. A rep loop with too few reps therefore measures
# COMPILE again, wearing a bracket. Measured on treebank-match, m3 vs the clean oracle:
#     reps=20   0.085x        <- warm-up dominated, WRONG BY 13x
#     reps=200  0.863x
#     reps=2000 1.017x        <- converged
#     reps=20000 1.128x
# ⭐ SO REPS IS NOT A CONSTANT AND IS NOT COMMITTED ANYWHERE. This harness RAMPS reps and REFUSES to
# report until the per-match figure CONVERGES (two successive ramp steps within TOL). A committed
# rep count would be a number nobody could tell had gone stale -- the same class as a scale column
# nobody can justify from a measurement.
#
# ⭐ THE BRACKET GOES TO STDERR (ceo ruling): the correctness anchor and the perf instrument never share
# a channel, so stdout stays byte-identical and every committed .ref and the cross-engine agreement gate
# are untouched. ⛔ It was a temp file until 2026-08-28 only because SCRIP silently discarded every write
# to an OUTPUT association on a file descriptor; hq_C cured that (69178c73) and the defect was WIDER than
# the fd2 symptom -- -f1 was discarded identically. Verified in both modes on the cured build.
set -uo pipefail
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
D="${DEMO_DIR:-$S4E/corpus/demos/snobol4}"
MK="${MKREP:-$HERE/mkrep_demo_fixture.py}"
TARGET_MS="${TARGET_MS:-800}"     # bracket window we ramp toward
TOL="${TOL:-8}"                   # % convergence tolerance between successive ramp steps
MAXREPS="${MAXREPS:-4000000}"
ENGINES="${ENGINES:-sbl m3 m4}"
NOHUGE="${NOHUGE:-1}"
STATIC="${STATIC:-0}"    # row m4-static-link-arm: opt-in m4 link arm, out/libscrip_rt.so stays canonical
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority. A private fallback would time a DIFFERENT LANGUAGE (s189: -bf is the only correct arm)." >&2; exit 3; }
. "$HERE/lib_static_link_snobol4.sh" 2>/dev/null || { echo "⛔ REFUSING: cannot load lib_static_link_snobol4.sh -- the ONE static-link-arm authority." >&2; exit 3; }
SBL="${SBL:-$(sbl_clean_bin)}"
# ⛔ NO SIZE IS TYPED HERE (ceo CEO-1485, ruling RULES.md clause 8 (g)(4) over the equal-arena arm): each engine runs at its own shipped
# defaults plus the PROGRAM's declaration -- SCRIP its .heap/.stack as -d/-s switches, sbl its .oracle_args -- read by lib_declared_arena.sh,
# and the window is never typed. CRITERION CHANGED 2026-10-03: every reading before ran sbl -d512m -i64m -s256m and SCRIP under
# SCRIP_HEAP_MB=4096, a 4 GB WINDOW (the collector never ran); the header line says so beside every reading from here on.
. "$HERE/lib_declared_arena.sh" || { echo "⛔ REFUSING: cannot load lib_declared_arena.sh -- the one reader of a declared size" >&2; exit 3; }
decl_of() { SWD="$(declared_switches_beside "$1")" && OAD="$(declared_oracle_args_beside "$1")"; }   # sets SWD (scrip) and OAD (sbl) from $1's sidecars
SWD=""; OAD=""
[ -x "$SCRIP" ] || { echo "⛔ REFUSING: scrip not built at $SCRIP" >&2; exit 3; }
[ -x "$SBL" ]   || { echo "⛔ REFUSING: clean bench oracle missing at $SBL" >&2; exit 3; }
[ -f "$MK" ]    || { echo "⛔ REFUSING: fixture generator missing at $MK" >&2; exit 3; }
if [ "$STATIC" = 1 ]; then
  RT_A="$(static_rt_archive "$ROOT")" || { echo "⛔ REFUSING: STATIC=1 but out/libscrip_rt.a could not be built (make libscrip_rt_static)" >&2; exit 3; }
fi
WRAP="$ROOT/tools/bench_rusage"
[ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" 2>/dev/null || { echo "⛔ REFUSING: cannot build $WRAP -- aspect 1 needs microsecond external timing, and /usr/bin/time's 10 ms tick reports these demos as 0.0" >&2; exit 3; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
RC=0
# ---- compile+assemble+link a .sno into an m4 binary, honoring STATIC (m4-static-link-arm) ----------
# ⛔ NOT an `A && B || C` chain: a static-link failure must REFUSE, never silently fall through to the
# dynamic arm -- that is exactly the "control that doesn't test what it claims" trap FINDING f4f6292c
# warns about (its own `--as-needed` near-miss). Real if/else so STATIC=1 either links static or fails.
m4_build() {  # $1=prog.sno $2=dst.bin $3=workstem (used for $3.s / $3.o)
  local prog="$1" dst="$2" stem="$3"
  "$SCRIP" --compile --out="$stem.s" "$prog" </dev/null >/dev/null 2>&1 || return 1
  as -o "$stem.o" "$stem.s" 2>/dev/null || return 1
  if [ "$STATIC" = 1 ]; then
    m4_link_static "$dst" "$stem.o" "$ROOT"
  else
    gcc -no-pie -o "$dst" "$stem.o" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2>/dev/null
  fi
}
# ---- one bracketed run; echoes "per_match_ns answer" or "" ----------------------------------------
brk() {  # $1=engine $2=variant.sno $3=input $4=reps $5=stem
  local eng="$2x" v="$2" in="$3" r="$4" stem="$5" out ns
  : > "$W/$stem.err"
  case "$1" in
    sbl) out=$(timeout -k 5 600 "$SBL" $(sbl_lang_flags) $OAD "$v" < "$in" 2>"$W/$stem.err" | tail -1) ;;
    m3)  out=$(SCRIP_NOHUGE="$NOHUGE" timeout -k 5 600 "$SCRIP" $SWD "$v" < "$in" 2>"$W/$stem.err" | tail -1) ;;
    m4)  [ -x "$W/$stem.bin" ] || m4_build "$v" "$W/$stem.bin" "$W/$stem"
         [ -x "$W/$stem.bin" ] || { echo ""; return; }
         out=$(SCRIP_NOHUGE="$NOHUGE" timeout -k 5 600 "$W/$stem.bin" $SWD < "$in" 2>"$W/$stem.err" | tail -1) ;;
  esac
  ns=$(grep -oE 'TIME_ns=[0-9]+' "$W/$stem.err" 2>/dev/null | tail -1 | cut -d= -f2)
  case "$ns" in ''|*[!0-9]*) echo ""; return;; esac
  [ -n "$out" ] || { echo ""; return; }     # ⛔ empty answer is never a pass
  echo "$(awk -v n="$ns" -v r="$r" 'BEGIN{printf "%.6f", n/r}') $out"
}
# ---- ASPECT 2 with convergence ramp ---------------------------------------------------------------
aspect2() {  # $1=engine $2=prog $3=input $4=fam ; echoes "per_match_ns reps answer" or REFUSE reason
  local eng="$1" prog="$2" in="$3" fam="$4" r=1 prev="" cur="" ans="" v tot
  decl_of "$prog" || { echo "REFUSE the program's declared sizes are refused"; return; }   # the variants run at the ORIGINAL's declaration
  while [ "$r" -le "$MAXREPS" ]; do
    v="$W/$fam.$eng.$r.sno"
    # ⛔ the bracket path MUST use the same reps-keyed stem brk() reads, or the generator writes one file
    # and the reader looks for another -- which is exactly what the reps-keyed stem fix broke first time.
    python3 "$MK" "$prog" "$v" "$W/$fam.$eng.$r.brk" "$r" >/dev/null 2>&1 || { echo "REFUSE fixture-not-identified"; return; }   # arg 3 retained for call-shape stability; the bracket now goes to stderr
    # ⛔ THE STEM CARRIES THE REP COUNT. Without it the m4 arm builds its binary once (at reps=1) and
    # reuses it for every ramp step while dividing by the CURRENT r -- per-match times wrong by the
    # whole ramp factor, silently, with every run looking healthy. The variant CHANGES with reps, so
    # anything cached per-variant must be keyed by reps.
    local res; res=$(brk "$eng" "$v" "$in" "$r" "$fam.$eng.$r")
    [ -n "$res" ] || { echo "REFUSE no-bracket-or-empty-answer at reps=$r"; return; }
    cur=$(awk '{print $1}' <<<"$res"); ans=$(cut -d' ' -f2- <<<"$res")
    tot=$(awk -v c="$cur" -v r="$r" 'BEGIN{printf "%.0f", c*r/1e6}')
    if [ -n "$prev" ] && [ "$tot" -ge "$TARGET_MS" ]; then
      awk -v a="$prev" -v b="$cur" -v t="$TOL" 'BEGIN{d=(a>b?a-b:b-a); exit !(a>0 && d*100/a<=t)}' \
        && { echo "$cur $r $ans"; return; }
    fi
    prev="$cur"; r=$((r * 4))
  done
  echo "REFUSE did-not-converge-by-reps=$MAXREPS"
}
# ---- --selftest: the harness MECHANISM, not a benchmark number ------------------------------------
# ⛔ WHY THIS EXISTS (row bench-rep-loop-demo-harness): a refusal path that is never itself tested is a
# refusal path that can silently rot -- the "mute correct gate" class this project keeps getting bitten
# by. Runs AFTER the normal preamble (SCRIP/SBL/MK already verified above) and calls brk()/aspect2()
# directly -- the SAME functions a real board run uses -- rather than a lighter parallel reimplementation
# that could drift from what actually ships.
if [ "${1:-}" = "--selftest" ]; then
  echo "=== bench_rep_loop_demos_snobol4.sh --selftest -- harness mechanism check, NOT a benchmark number ==="
  st_ok=1
  # POSITIVE: the core bracket-and-measure primitive returns a real per-rep timing + answer for a
  # known-good demo. This is brk() directly, not the full convergence ramp -- proving the measurement
  # primitive works does not require spending the ramp's wall-clock budget on every selftest run.
  st_v="$W/selftest_pos.m3.8.sno"
  if python3 "$MK" "$D/calculator/calculator-1-match.sno" "$st_v" "$W/selftest_pos.brk" 8 >/dev/null 2>&1; then
    decl_of "$D/calculator/calculator-1-match.sno" || st_ok=0   # brk() runs at the ORIGINAL's declaration, as aspect2() sets it
    st_res=$(brk m3 "$st_v" "$D/calculator/calculator.input" 8 "selftest_pos.m3.8")
    if [ -n "$st_res" ]; then
      echo "  PASS measures-a-real-demo (per-rep-ns + answer: $st_res)"
    else
      echo "  FAIL brk() returned nothing for a known-good demo at reps=8 -- is the demo corpus intact?"; st_ok=0
    fi
  else
    echo "  FAIL fixture generator could not bracket calculator-1-match.sno -- is the demo corpus intact?"; st_ok=0
  fi
  # NEGATIVE 1: REFUSES when the program cannot even be identified/bracketed (the fixture-generator arm).
  st_neg1=$(aspect2 m3 "$D/__selftest_no_such_demo__.sno" "$D/__selftest_no_such_input__.txt" selftest_neg1)
  case "$st_neg1" in
    REFUSE*) echo "  PASS refuses-unbracketable-program ($st_neg1)" ;;
    *) echo "  FAIL expected a REFUSE for a nonexistent program, got: [$st_neg1]"; st_ok=0 ;;
  esac
  # NEGATIVE 2: REFUSES when the convergence ramp cannot run far enough to reach a verdict -- the actual
  # "unmeasurable" case this whole harness exists for (a real demo, artificially starved of ramp budget).
  st_neg2=$(MAXREPS=1 aspect2 m3 "$D/calculator/calculator-1-match.sno" "$D/calculator/calculator.input" selftest_neg2)
  case "$st_neg2" in
    REFUSE*) echo "  PASS refuses-when-ramp-budget-exhausted ($st_neg2)" ;;
    *) echo "  FAIL expected a REFUSE at MAXREPS=1, got: [$st_neg2]"; st_ok=0 ;;
  esac
  if [ "$st_ok" = 1 ]; then echo "SELFTEST OK"; exit 0; else echo "SELFTEST FAILED"; exit 1; fi
fi
printf '%s\n' "=== TWO-ASPECT tier-1 demo board (Lon's presentation law) ===" \
  "  ASPECT 1 = whole process, external elapsed, COMPILE INCLUDED   |  ASPECT 2 = in-program bracket, MATCH ONLY" \
  "  oracle=$(basename "$(dirname "$SBL")")/$(basename "$SBL") -bf | RT_OPT=-O0 | NOHUGE=$NOHUGE | sizes: each program's own .heap/.stack (scrip) and .oracle_args (sbl) over each engine's defaults -- CRITERION CHANGED 2026-10-03 (CEO-1485), earlier readings ran one typed equal arena and a 4 GB SCRIP window (this file's header) | reps RAMPED to convergence (tol ${TOL}%) | m4 link=$([ "$STATIC" = 1 ] && echo STATIC || echo shared)" \
  "  ⛔ aspect 1 is a TOTAL and aspect 2 is a SLOPE -- per the FACT RULE they may never share a column."
printf '%-26s %-4s %12s %14s %8s %10s\n' demo eng "A1_total_ms" "A2_TIME_ns" "reps" "A2_mult"
while IFS=$'\t' read -r fam prog inp; do
  case "$fam" in ''|\#*) continue;; esac
  P="$D/$prog"; IN="$D/$inp"
  [ -f "$P" ] && [ -f "$IN" ] || { echo "⛔ REFUSE $fam -- missing program or input ($prog / $inp); NAMED, not dropped."; RC=1; continue; }
  decl_of "$P" || { echo "⛔ REFUSE $fam -- its declared sizes are refused (named above); NAMED, not dropped."; RC=1; continue; }
  declare -A A2 ANS
  for e in $ENGINES; do
    # ASPECT 1: the ORIGINAL program, whole process, best of 3, via tools/bench_rusage.
    # ⛔ NOT /usr/bin/time -f %e -- that clock has 10 ms RESOLUTION and these demos run in single-digit
    # milliseconds, so it reported a flat "0.0" for treebank/claws5/json: a real measurement rendered as
    # a zero, which reads exactly like "too fast to matter" when it means "below my tick". bench_rusage
    # reports elapsed_ns and is already the ONE external-timing authority for the other bench harnesses.
    b=""
    for i in 1 2 3; do
      case "$e" in
        sbl) "$WRAP" timeout -k 5 600 "$SBL" $(sbl_lang_flags) $OAD "$P" < "$IN" >/dev/null 2>"$W/ru" ;;
        m3)  SCRIP_NOHUGE="$NOHUGE" "$WRAP" timeout -k 5 600 "$SCRIP" $SWD "$P" < "$IN" >/dev/null 2>"$W/ru" ;;
        m4)  [ -x "$W/$fam.a1.bin" ] || m4_build "$P" "$W/$fam.a1.bin" "$W/$fam.a1"
             [ -x "$W/$fam.a1.bin" ] || continue
             SCRIP_NOHUGE="$NOHUGE" "$WRAP" timeout -k 5 600 "$W/$fam.a1.bin" $SWD < "$IN" >/dev/null 2>"$W/ru" ;;
      esac
      t=$(grep -oE 'elapsed_ns=[0-9]+' "$W/ru" 2>/dev/null | tail -1 | cut -d= -f2)
      case "$t" in ''|*[!0-9]*) continue;; esac
      [ -z "$b" ] && b="$t"; [ "$t" -lt "$b" ] && b="$t"
    done
    a1=$(awk -v b="${b:-0}" 'BEGIN{printf "%.2f", b/1e6}')
    r2=$(aspect2 "$e" "$P" "$IN" "$fam")
    case "$r2" in
      REFUSE*) printf '%-26s %-4s %12s %14s %8s %10s   ⛔ %s\n' "$fam" "$e" "$a1" "-" "-" "-" "$r2"; RC=1; continue;;
    esac
    A2[$e]=$(awk '{print $1}' <<<"$r2"); reps=$(awk '{print $2}' <<<"$r2"); ANS[$e]=$(cut -d' ' -f3- <<<"$r2")
    mult="-"; [ -n "${A2[sbl]:-}" ] && mult=$(awk -v s="${A2[sbl]}" -v x="${A2[$e]}" 'BEGIN{printf "%.3fx", (x>0)?s/x:0}')
    printf '%-26s %-4s %12s %14.1f %8s %10s\n' "$fam" "$e" "$a1" "${A2[$e]}" "$reps" "$mult"
  done
  # ⛔ correctness anchor: the ANSWER, never the exit code (sbl returns rc=0 while printing ERROR 246)
  ref=""; bad=0
  for e in $ENGINES; do [ -n "${ANS[$e]:-}" ] || continue; [ -z "$ref" ] && ref="${ANS[$e]}"; [ "${ANS[$e]}" = "$ref" ] || bad=1; done
  [ "$bad" = 0 ] && [ -n "$ref" ] || { echo "   ⛔ ANSWER DISAGREEMENT across engines for $fam -- timings above are NOT comparable"; RC=1; }
  unset A2 ANS
done <<'ROWS'
calculator-1-match	calculator/calculator-1-match.sno	calculator/calculator.input
calculator-1-match-fence	calculator/calculator-1-match-fence.sno	calculator/calculator.input
calculator-2-match	calculator/calculator-2-match.sno	calculator/calculator.input
calculator-2-match-fence	calculator/calculator-2-match-fence.sno	calculator/calculator.input
treebank-match	treebank/treebank-match.sno	treebank/treebank.input
treebank-match-fence	treebank/treebank-match-fence.sno	treebank/treebank.input
claws5-match	claws5/claws5-match.sno	claws5/claws5.input
claws5-match-fence	claws5/claws5-match-fence.sno	claws5/claws5.input
json-match	json/json-match.sno	json/json.input
json-match-fence	json/json-match-fence.sno	json/json.input
ROWS
exit "$RC"
