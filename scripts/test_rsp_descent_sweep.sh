#!/usr/bin/env bash
# s58 RSP-ONLY DESCENT SWEEP (Lon in-chat: "run the entire test suite in RSP only mode... determine what state it ends").
# The coming-out side is frozen: RETURN/FRETURN/NRETURN are BOMBS.  Classification per program (m4 TEXT, the TINY-REAL scheme):
#   PASS              ran to completion, output == oracle (programs that never call a DEFINE)
#   DESCENT_OK        died at BOMB-RETURN with stdout a PREFIX of the oracle's output — the call made it all the way down
#   BOMB_RETURN_BAD   BOMB-RETURN but pre-bomb stdout is NOT an oracle prefix — descent reached RETURN with corrupted state
#   BOMB_FRETURN/BOMB_NRETURN   died at those floaters (prefix not checked — FRETURN paths diverge from oracle by design here)
#   COMPILE_FAIL / ASM_FAIL / TIMEOUT / SIG<n> / DIFF   everything else — the bugs to fix before only depth-spots remain
#   ORACLE_FAIL       s60: sbl itself produced nothing and scrip agreed — no oracle to grade against (NOT a scrip defect)
# s60: parameterized (SWEEP_DIRS / SWEEP_LIST) + parallel (SWEEP_JOBS) so the corpus checkout can be swept, not just SCRIP test+demo.
#      Classification logic is ONE AUTHORITY (classify_one) shared by every caller.  Default invocation is byte-identical in
#      behaviour to the s58/s59 instrument: SWEEP_DIRS="test demo", SWEEP_JOBS=1.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
cd "$(dirname "$0")/../../SCRIP"
ROOT=$PWD   # include-bearing tests (-include 'lib/*.sno') resolve against the corpus checkout: sbl is CWD-relative, scrip honors SNO_LIB (s59 harness fix; both engines verified on test_case)
OUT=${1:-/tmp/descent_sweep.txt}; : > "$OUT"
: "${SWEEP_DIRS:=test demo}"
: "${SWEEP_JOBS:=1}"
. "$(dirname "$0")/lib_oracle_flags.sh"
if [ -z "${SWEEP_ORACLE:-}" ]; then SWEEP_ORACLE=$(sbl_correctness_bin) || { echo "REFUSE(2): no bf-capable SPITBOL correctness oracle (sbl_correctness_bin refused)" >&2; exit 2; }; fi
: "${SWEEP_ORACLE_FLAGS:=$(sbl_lang_flags)}"
: "${SWEEP_CORPUS:=$S4E/corpus}"
# s68: SWEEP_NORM + SWEEP_RUN_TO.  BOTH DEFAULT TO THE PRE-EXISTING BEHAVIOUR (norm off, 8s run) so every existing caller is byte-identical.
# SWEEP_NORM=1 rewrites ONLY a whole line of the exact form "ms: <digits>" to "ms: <T>" on BOTH sides before comparison.  WHY IT IS NOT A CHEAT:
# the benchmark corpus prints an ELAPSED TIME line by construction (20 of 23 programs), so a byte-compare against the oracle reads DIFF for a
# CORRECT engine and DIFF for a BROKEN one -- the arms COINCIDE, which is the STANDING INSTRUMENT RULE's own definition of an instrument that is
# DARK for the class under test.  Elapsed milliseconds are not a semantic property of the program; the deterministic checksum line beside it is,
# and those stay byte-compared.  The pattern is anchored (^ms: [0-9]+$) so no result line, no numeric output, and no ms-bearing DATA can be caught.
: "${SWEEP_NORM:=0}"
: "${SWEEP_RUN_TO:=8}"
export ROOT SWEEP_ORACLE SWEEP_ORACLE_FLAGS SWEEP_CORPUS SWEEP_NORM SWEEP_RUN_TO
sweep_norm() { if [ "$SWEEP_NORM" = 1 ]; then sed -E 's/^ms: [0-9]+$/ms: <T>/'; else cat; fi; }
export -f sweep_norm
classify_one() {
  f=$1
  case "$f" in /*) src=$f;; *) src=$ROOT/$f;; esac
  tag=$$-$(printf '%s' "$f" | md5sum | cut -c1-10)
  S=/tmp/dsw.$tag.s; X=/tmp/dsw.$tag.x; CE=/tmp/dsw.$tag.cerr; GE=/tmp/dsw.$tag.gerr; RE=/tmp/dsw.$tag.rerr
  ORA=$(cd "$SWEEP_CORPUS" && timeout -k 5 30 "$SWEEP_ORACLE" $SWEEP_ORACLE_FLAGS "$src" </dev/null 2>/dev/null); ost=$?
  ORA=$(printf '%s\n' "$ORA" | sweep_norm)
  st=
  if ! SNO_LIB="$SWEEP_CORPUS" timeout -k 5 30 "$ROOT/scrip" --compile "$src" </dev/null > $S 2>$CE; then st=COMPILE_FAIL
  elif ! gcc -no-pie $S -L "$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o $X 2>$GE; then st=ASM_FAIL
  else
    RO=$(timeout -k 5 "$SWEEP_RUN_TO" $X </dev/null 2>$RE); rc=$?
    RO=$(printf '%s\n' "$RO" | sweep_norm)
    if grep -q "BOMB-RETURN" $RE; then
      case "$ORA" in "$RO"*) st=DESCENT_OK;; *) st=BOMB_RETURN_BAD;; esac
    elif grep -q "BOMB-FRETURN" $RE; then st=BOMB_FRETURN
    elif grep -q "BOMB-NRETURN" $RE; then st=BOMB_NRETURN
    elif [ $rc -eq 124 ]; then st=TIMEOUT
    elif [ $rc -ge 128 ]; then st=SIG$((rc-128))
    elif [ "$RO" = "$ORA" ]; then st=PASS
    else st=DIFF; fi
  fi
  # s66 -- THE -z "$ORA" CONJUNCT IS DELETED.  It was the s33 "NON-EMPTY IS NOT ALIVE" false-signal class living inside the demotion predicate itself: PLAN.md line 22
  # names that class for the MISSING-oracle case, and it reappeared here for the CRASHING-oracle case.  MEASURED over the 226-program census set: exactly 3 programs exit
  # the oracle NONZERO and ALL THREE are NONEMPTY, so the conjunct blocked every demotion -- sbl prints its diagnostic first (expression.sno "ERROR 285 include file
  # cannot be opened"; beauty.sno "ERROR 217 duplicate label" at 568, 1261 bytes) and THEN segfaults, so the harness banked error text as the reference and graded SCRIP
  # against it.  family_snobol4.sno was carrying a DIFF earned exactly that way -- a SCRIP red for disagreeing with a dead engine.  Exit code alone is the test now: you
  # cannot claim PASS or DIFF against a reference from a run that crashed, whether or not it managed to print something first.  SIG-star/COMPILE_FAIL/TIMEOUT stay OUT of
  # the case list ON PURPOSE -- those are SCRIP-side facts (a SCRIP segfault is a SCRIP segfault no matter how healthy the oracle is) and demoting them would hide real
  # defects behind a broken oracle.
  if [ $ost -ne 0 ]; then case "$st" in PASS|DIFF) st=ORACLE_FAIL;; esac; fi
  rm -f $S $X $CE $GE $RE
  echo "$st $f"
}
export -f classify_one
if [ -n "${SWEEP_LIST:-}" ]; then LIST=$(cat "$SWEEP_LIST"); else LIST=$(find $SWEEP_DIRS -name '*.sno' 2>/dev/null | sort); fi
printf '%s\n' "$LIST" | xargs -d '\n' -P "$SWEEP_JOBS" -I{} bash -c 'classify_one "$@"' _ {} >> "$OUT"
sort -o "$OUT" "$OUT"
awk '{print $1}' "$OUT" | sort | uniq -c | sort -rn
echo "detail: $OUT"
