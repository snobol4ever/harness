#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_rtx_killswitch_sets.sh — KILL-SWITCH BYTE-IDENTITY, N>=4 PER ARM, HASH *SETS*, **BOTH MODES**.
#
# Minted s219 (2026-07-30).  Implements the correction ARCH-SNOBOL4-RTX.md §7 step 3
# received at s217 and which had no executable form until now.
# m4 ARM ADDED s222 (2026-07-30) — see "WHY THE m4 ARM IS NOT OPTIONAL" below.
#
# WHAT WAS WRONG WITH THE GATE AS PRACTICED: it ran ONE run per arm per program and
# compared the two hashes.  The suite contains at least one program that is
# NON-DETERMINISTIC RUN-TO-RUN ON THE PURE-C PATH (160_pat_alt_inner_gen_resume:
# three distinct hashes in four gate-OFF runs, measured s217).  Against such a
# program a single-run comparison reports MOVER or IDENTICAL BY COIN FLIP, so a
# recorded pass is luck rather than evidence — and the failure mode is severe in
# both directions: a later session either reverts a correct port and hunts a bug
# that does not exist, or ships a real leak because the dice fell the other way.
#
# THE DISCRIMINATION IS FREE: gate OFF *is* the C fallback, so instability that is
# visible with the gate OFF cannot have been caused by the asm.  Hence three
# verdicts, not two:
#   IDENTICAL   ON set == OFF set, both singletons  -> real evidence
#   QUARANTINE  either arm produced >1 distinct hash -> unfalsifiable HERE, and
#               that is a fact about the PROGRAM, reported, never silently skipped
#   MOVER       both arms stable and the hashes differ -> the port changed behaviour
#   SKIP        (m4 only) the program does not compile/link -> not evidence either way
#
# A QUARANTINE verdict is NOT a pass and NOT a failure; it is the third thing, and
# printing it is the entire point (same reason 0(f) prints COMMITS rather than a
# pass/fail).  Do NOT "fix" a quarantined program by excluding it wholesale: 160
# both fails in both modes AND is non-deterministic, and a blanket exclusion fuses
# two independent facts.
#
# ⛔ WHY THE m4 ARM IS NOT OPTIONAL (s222).  ARCH §7 step 3 has mandated "BOTH modes"
# since s217; this script shipped with `--run` only, so s219/s220/s221 each recorded a
# suite-wide PASS that covered m3 alone while the contract read "both".  That gap matters far
# more than it looks, because mode 4 is exactly where this codebase's worst silent
# failure class lives: pattern_match.c:737 records that giving g_cap_gen hidden
# visibility cost 173/316 mode-4 LINK failures while mode 3 stayed green — mode 3 bakes
# the address in-process and is structurally incapable of seeing it.  Any rung that
# touches templates or symbol visibility (RTX-11 collapses call sites in
# bb_match_end; every static->hidden promotion a port needs) is precisely the class
# whose signature failure a gate grading m3 alone cannot detect.  ⇒ DEFAULT IS NOW `both`.
# Pass `m3` explicitly to reproduce the s219-s221 historical numbers.
#
# ⭐ WHY THE m4 ARM IS CHEAP, MEASURED NOT ASSUMED (s222): `--compile` output is
# BYTE-IDENTICAL at gate ON and OFF, because RTX_GATE is a runtime `.byte` test inside
# the .so (rtx_abi.inc:83) whose value is set by the .so's OWN constructor
# (rtx_init.c:24) — and an m4 binary links that same .so, so the env toggle reaches it
# identically.  Verified by cmp on a probe program before this arm was written.  So we
# compile ONCE per program and toggle only the RUNS.
#
# ⚠ STDIN IS /dev/null IN BOTH ARMS AND THAT IS DELIBERATE (s220 fix, RULES.md line 80).
# A program starved of input may fail — irrelevant here, because this gate compares ON
# vs OFF of the SAME program under the SAME stdin.  Identity is still the question.
# Feeding real `.input` files would be more faithful but would silently invalidate the
# s219-s221 m3 baselines, so it is NOT done here; that is its own rung.
#
# Usage: bash ../harness/scripts/test_gate_rtx_killswitch_sets.sh <FAMILY> [glob-dir] [N] [m3|m4|both]
#   FAMILY = the SCRIP_RTX_<FAMILY> gate under test, e.g. MATCH
set -u
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
FAM="${1:?usage: test_gate_rtx_killswitch_sets.sh <FAMILY> [dir] [N] [m3|m4|both]}"
DIR="${2:-$ROOT/../corpus/tests/scrip_test/snobol4}"
N="${3:-4}"
MODE="${4:-both}"
# EXT added s223-PL: this gate was hardcoded to *.sno, so it had NO PROLOG OR ICON ARM AT ALL while three
# RTX ladders depend on it — the same shape as the m3-alone gap this script documents about itself above.
# The per-program logic is already language-agnostic (first dispatch selects the frontend from the
# extension), so one parameter generalizes it; default stays `sno` so every existing invocation is unmoved.
EXT="${5:-sno}"
GATE="SCRIP_RTX_${FAM}"
RT_DIR="$ROOT/out"
[ -x "$ROOT/scrip" ] || { echo "FATAL: $ROOT/scrip missing"; exit 1; }
case "$MODE" in m3|m4|both) ;; *) echo "FATAL: MODE must be m3|m4|both (got '$MODE')"; exit 1 ;; esac
if [ "$MODE" != m3 ]; then
  [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "FATAL: $RT_DIR/libscrip_rt.so missing — run 'make libscrip_rt' (m4 links against it)"; exit 1; }
fi
WORKDIR="$(mktemp -d)"; trap 'rm -rf "$WORKDIR"' EXIT
compile_m4() {
  local sno="$1" out="$2" tmp; tmp="$(mktemp -d)"
  "$ROOT/scrip" --compile "$sno" > "$tmp/p.s" 2>/dev/null < /dev/null || { rm -rf "$tmp"; return 1; }
  ( cd "$ROOT" && gcc -c "$tmp/p.s" -o "$tmp/p.o" 2>/dev/null ) || { rm -rf "$tmp"; return 1; }
  gcc "$tmp/p.o" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$out" 2>/dev/null || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}
build_set() {
  local mode="$1" dir="$2" arm="$3" target="$4" i out rc h acc=""
  for i in $(seq 1 "$N"); do
    if [ "$mode" = m3 ]; then
      out="$( cd "$dir" && env "$GATE=$arm" timeout -k 5 30 "$ROOT/scrip" --run "$target" 2>/dev/null < /dev/null )"; rc=$?
    else
      out="$( cd "$dir" && env "$GATE=$arm" timeout -k 5 30 "$target" 2>/dev/null < /dev/null )"; rc=$?
    fi
    h="$(printf '%s|rc=%d' "$out" "$rc" | md5sum | cut -c1-8)"
    acc="$acc$h"$'\n'
  done
  printf '%s' "$acc" | sort -u | tr '\n' ','
}
i3=0; q3=0; m3c=0; i4=0; q4=0; m4c=0; s4=0; total=0
Q3=""; M3=""; Q4=""; M4=""; S4L=""
while IFS= read -r prog; do
  total=$((total+1))
  pdir="$(dirname "$prog")"; name="$(basename "$prog" ".$EXT")"
  if [ "$MODE" = m3 ] || [ "$MODE" = both ]; then
    on="$(build_set m3 "$pdir" 1 "$prog")"; off="$(build_set m3 "$pdir" 0 "$prog")"
    on_n="$(printf '%s' "$on" | tr ',' '\n' | grep -c .)"; off_n="$(printf '%s' "$off" | tr ',' '\n' | grep -c .)"
    if [ "$on_n" -gt 1 ] || [ "$off_n" -gt 1 ]; then q3=$((q3+1)); Q3="$Q3  $name  ON{$on} OFF{$off}"$'\n'
    elif [ "$on" = "$off" ]; then i3=$((i3+1))
    else m3c=$((m3c+1)); M3="$M3  $name  ON{$on} OFF{$off}"$'\n'; fi
  fi
  if [ "$MODE" = m4 ] || [ "$MODE" = both ]; then
    bin="$WORKDIR/$name.bin"
    if compile_m4 "$prog" "$bin"; then
      on="$(build_set m4 "$pdir" 1 "$bin")"; off="$(build_set m4 "$pdir" 0 "$bin")"
      on_n="$(printf '%s' "$on" | tr ',' '\n' | grep -c .)"; off_n="$(printf '%s' "$off" | tr ',' '\n' | grep -c .)"
      if [ "$on_n" -gt 1 ] || [ "$off_n" -gt 1 ]; then q4=$((q4+1)); Q4="$Q4  $name  ON{$on} OFF{$off}"$'\n'
      elif [ "$on" = "$off" ]; then i4=$((i4+1))
      else m4c=$((m4c+1)); M4="$M4  $name  ON{$on} OFF{$off}"$'\n'; fi
      rm -f "$bin"
    else s4=$((s4+1)); S4L="$S4L $name"; fi
  fi
done < <(find "$DIR" -name "*.$EXT" | sort)
[ "$total" -eq 0 ] && { echo "GATE FAIL: zero programs matched $DIR -- a typo'd path must not report PASS (s220)"; exit 1; }
echo "=== KILL-SWITCH HASH-SET GATE — $GATE, N=$N per arm, $total programs, MODE=$MODE ==="
movers=0
if [ "$MODE" = m3 ] || [ "$MODE" = both ]; then
  echo "  [m3 --run]      IDENTICAL=$i3  QUARANTINE=$q3  MOVER=$m3c"; movers=$((movers+m3c))
fi
if [ "$MODE" = m4 ] || [ "$MODE" = both ]; then
  echo "  [m4 --compile]  IDENTICAL=$i4  QUARANTINE=$q4  MOVER=$m4c  SKIP=$s4"; movers=$((movers+m4c))
fi
[ -n "$Q3" ] && { echo "--- QUARANTINE (m3) ---"; printf '%s' "$Q3"; }
[ -n "$Q4" ] && { echo "--- QUARANTINE (m4) ---"; printf '%s' "$Q4"; }
[ -n "$S4L" ] && echo "--- SKIP (m4, did not compile/link):$S4L"
[ -n "$M3" ] && { echo "--- MOVERS m3 (gate violation) ---"; printf '%s' "$M3"; }
[ -n "$M4" ] && { echo "--- MOVERS m4 (gate violation) ---"; printf '%s' "$M4"; }
[ "$movers" -eq 0 ] && { echo "GATE PASS (zero movers in MODE=$MODE; quarantine and skip reported, not hidden)"; exit 0; }
echo "GATE FAIL ($movers mover(s) in MODE=$MODE)"; exit 1
