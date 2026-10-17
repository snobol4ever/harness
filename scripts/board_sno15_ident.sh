#!/usr/bin/env bash
# board_sno15_ident.sh — CORRECTNESS board for the working-set demos (s158 scope widening). ⛔ THE
# FILENAME SAYS 15; THE ARRAY BELOW CARRIES 14 (mechanically counted 2026-09-04, see the DEMOS= comment)
# -- kept as-is rather than renamed, since the name is cited by board_denominators.sh and multiple
# FINDING-*.md files; ${#DEMOS[@]} is the number of record, never this comment or the filename.
# Generalizes test_demo_full_3way.sh (which covered only claws5 + treebank-list) to every .sno in the
# CLAWS5 / TREEBANK / JSON / CALCULATOR families: base programs, *-match, and *-match-fence.
# Encodes the s107 recipes verbatim: oracle temp-prepend (-CASE 0 control card + tab &TRIM = 0 — NEVER
# patch the corpus source). ⛔ NO SIZE IS TYPED HERE (ceo CEO-1353, RULES.md clause 8 (g)(3)-(4)): each demo's own <stem>.heap/.stack
# reach SCRIP in both modes and its <stem>.oracle_args reaches sbl, through lib_declared_arena.sh -- the s107 recipe this replaced
# (-d512m -i64m, a per-family -s256m, ulimit -s unlimited) is measured unneeded on the full inputs (test_demo_full_3way.sh's header).
# Reports IDENT/DIVERGE PER MODE, because a program failing in exactly one mode is a MODE34 violation.
# NO TIMING HERE BY DESIGN: a ratio on a diverging mode is meaningless (s158 ~8x trap).
#
# B-9 FIX (BOARD): every non-zero exit under `timeout` was previously collapsed to the single label
# "RC!=0" for both m3 and m4 -- a HANG (timeout's own exit 124) and a CRASH (shell's 128+signal, e.g.
# 139=SIGSEGV, 134=SIGABRT) read identically. Per FINDING-2026-08-12n the 13 broken demo-board programs
# are AT LEAST THREE separate mechanisms (a resumable-generator hang, an R12 arena overrun crash, a wild-
# rbx crash) -- a board that cannot tell hang from crash cannot route a failure to its owner. classify_rc()
# below turns the raw $? into HANG / CRASH(sig) / RC=<n> so the printed column carries that distinction.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
TIMEOUT_RETRY="${TIMEOUT_RETRY:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_timeout_retry.sh}"   # every graded timeout is retried once, longer (Lon 2026-10-15, in-chat to the coo: "do a retry with longer timeouts")
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -u
classify_rc() {  # $1 = exit code from `timeout N cmd`
  local rc=$1
  if [ "$rc" -eq 124 ]; then echo "HANG"
  elif [ "$rc" -ge 128 ]; then echo "CRASH($((rc-128)))"
  else echo "RC=$rc"; fi
}
SC=${SC:-$S4E/SCRIP}; D=${D:-$S4E/corpus/demos}
. "$(dirname "${BASH_SOURCE[0]}")/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255)." >&2; exit 3; }
SBL=${SBL:-$S4A/x64/bin/sbl}   # CORRECTNESS oracle -- identity board, no timing, x64/bin/sbl stays authoritative
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
. "$(dirname "${BASH_SOURCE[0]}")/lib_declared_arena.sh" || { echo "REFUSING: cannot load lib_declared_arena.sh -- the one reader of a declared size." >&2; exit 2; }
TMO=${TMO:-300}
inp_for() { case $1 in claws5*) echo "$D/CLAWS5inTASA.dat";; treebank*) echo "$D/VBGinTASA.dat";;
  json*) echo "$D/twitter.json";; calculator*) echo "$D/calculator.input";; *) echo "";; esac; }
printf '%-26s %-10s %-10s %s\n' PROGRAM M3 M4 NOTE
printf '%.0s-' {1..66}; echo
# ⛔ NAMED ARRAY, NOT A BARE `for nm in ...` WORD LIST (found while auditing this file for row every-
# board-wrapper-refuses-on-a-zero-population-instead-of-passing-vacuously, hq_T 2026-09-04): the old
# word-list form let the printed "/15" denominator below and board_denominators.sh's d_demo15() both
# hand-type "15" citing THIS loop as their source, while the loop itself carries fourteen names
# (mechanically counted, not eyeballed: `for nm in <the list>; do echo "$nm"; done | wc -l` = 14) --
# a copied number that quietly went stale relative to the thing it claimed to be copied from. Sizing
# off ${#DEMOS[@]} means it cannot happen again; see the matching correction in board_denominators.sh.
DEMOS=(claws5 claws5-match claws5-match-fence
       treebank treebank-match treebank-match-fence
       json-match json-match-fence
       calculator-1 calculator-1-match calculator-1-match-fence
       calculator-2 calculator-2-match calculator-2-match-fence)
nid=0; nd3=0; nd4=0; nfail=0
for nm in "${DEMOS[@]}"; do
  src="$D/$nm.sno"; inp=$(inp_for "$nm"); note=""
  [ -f "$src" ] || { printf '%-26s %-10s %-10s %s\n' "$nm" - - "NO SOURCE"; nfail=$((nfail+1)); continue; }
  sw="$(declared_switches_beside "$src")" && oa="$(declared_oracle_args_beside "$src")" || { printf '%-26s %-10s %-10s %s\n' "$nm" - - "DECLARATION REFUSED"; nfail=$((nfail+1)); continue; }
  # ---- oracle: temp-prepend the control card, never touch the corpus file ----
  printf -- '-CASE 0\n\t&TRIM = 0\n' > "$W/$nm.sbl.sno"; cat "$src" >> "$W/$nm.sbl.sno"
  if ! "$TIMEOUT_RETRY" $TMO "$SBL" $(sbl_lang_flags) $oa "$W/$nm.sbl.sno" < "$inp" > "$W/$nm.sbl" 2>/dev/null; then
    printf '%-26s %-10s %-10s %s\n' "$nm" - - "SBL FAILED"; nfail=$((nfail+1)); continue; fi
  # ---- mode 3 (in-process native) ----
  "$TIMEOUT_RETRY" $TMO "$SC/scrip" --run $sw "$src" < "$inp" > "$W/$nm.m3" 2>/dev/null; rc3=$?
  if [ "$rc3" -eq 0 ]; then
    cmp -s "$W/$nm.sbl" "$W/$nm.m3" && m3=IDENT || m3=DIVERGE
  else m3=$(classify_rc "$rc3"); fi
  # ---- mode 4 (compile via as+gcc) ----
  if "$TIMEOUT_RETRY" $TMO "$SC/scrip" --compile "$src" > "$W/$nm.s" 2>/dev/null \
     && gcc -no-pie "$W/$nm.s" -L"$SC/out" -lscrip_rt -lm -Wl,-rpath,"$SC/out" -o "$W/$nm.prog" 2>/dev/null; then
    "$TIMEOUT_RETRY" $TMO "$W/$nm.prog" $sw < "$inp" > "$W/$nm.m4" 2>/dev/null; rc4=$?
    if [ "$rc4" -eq 0 ]; then
      cmp -s "$W/$nm.sbl" "$W/$nm.m4" && m4=IDENT || m4=DIVERGE
    else m4=$(classify_rc "$rc4"); fi
  else m4="BUILD-FAIL"; fi
  [ "$m3" = IDENT ] || nd3=$((nd3+1)); [ "$m4" = IDENT ] || nd4=$((nd4+1))
  [ "$m3" = IDENT ] && [ "$m4" = IDENT ] && nid=$((nid+1))
  # a program failing in EXACTLY one mode is a MODE34-IDENTICAL violation — name it
  [ "$m3" != "$m4" ] && note="MODE34-VIOLATION"
  [ -s "$W/$nm.sbl" ] || note="$note (sbl output empty)"
  printf '%-26s %-10s %-10s %s\n' "$nm" "$m3" "$m4" "$note"
done
printf '%.0s-' {1..66}; echo
echo "TRI-IDENTICAL $nid/${#DEMOS[@]}   m3 bad=$nd3   m4 bad=$nd4   harness-fail=$nfail"

# ⛔⭐ A BOARD THAT GRADED NOTHING REFUSES rc=2 (coo 2026-09-18, on the cto's re-measurement of seat10's
# 2026-08-23 list).  WHAT THIS LOOKED LIKE: on a tree with no binary and no corpus every demo took the NO SOURCE
# or SBL FAILED path, so the board printed TRI-IDENTICAL 0/14 with harness-fail=14 -- EVERY PROGRAM IN THE
# POPULATION FAILED TO EXECUTE -- and then fell off the end of the script, which exits with the status of the
# last echo.  ZERO.  A reader checking the exit code recorded a clean board for a run in which nothing was ever
# compared against the oracle, and "0/14 identical" is the most alarming line this board can print.
# ⛔ THE VERDICT SEMANTICS ARE DELIBERATELY UNCHANGED OTHERWISE, and that restraint is the point: these demos
# carry KNOWN divergences (the header names at least three separate mechanisms behind the broken ones), so
# turning divergence into a non-zero exit would red a board that is honestly reporting known debt.  The defect
# is not "it fails to fail on divergence", it is "it cannot tell a graded board from an ungraded one".  Only
# that distinction is added here.
graded=$(( ${#DEMOS[@]} - nfail ))
if [ "$graded" -le 0 ]; then
  echo "BOARD UNPROVEN(2) [board_sno15_ident]: graded 0 of ${#DEMOS[@]} demo(s) -- every program failed the harness"
  echo "    before any oracle comparison was made (missing source, missing binary, or the oracle refused), so"
  echo "    TRI-IDENTICAL 0/${#DEMOS[@]} above describes NO measurement.  Could-not-measure is never a pass."
  exit 2
fi
echo "population: graded $graded of ${#DEMOS[@]} demo(s) against the oracle (harness-fail $nfail)"
