#!/usr/bin/env bash
# util_ref_mint.sh — MINT `.ref` GROUND TRUTH FROM THE LIVE ORACLE FOR PROGRAMS NO BOARD GRADES (row `ref-the-ungraded-suites`, s191).
#
#   bash ../harness/scripts/util_ref_mint.sh <suite> <dir> [<dir>...]            # CENSUS ONLY — classify, write nothing
#   bash ../harness/scripts/util_ref_mint.sh <suite> <dir> [<dir>...] --apply    # mint a .ref beside every LIVE program
#
# ⛔ A SUITE THAT IS NEVER GRADED IS NOT A PASSING SUITE, IT IS AN UNOPENED ONE.  Grading is by `.ref` diff, so a program with no
# `.ref` is invisible to every board -- corpus/tests/snobol4/parser/ held 88 such programs and feat/ 19 more.  These are
# self-checking programs that print their own PASS/FAIL, so they were DESIGNED to be graded.
# ⛔⛔ BUT A .ref MINTED FROM A BROKEN ORACLE RUN PINS A LIE, AND THERE ARE THREE WAYS TO PIN ONE, NOT ONE.  This tool mints ONLY
# on `LIVE` and names every other class instead:
#   DEAD_REPORT -- sbl EXITED 0 WHILE PRINTING A FATAL ERROR DUMP (seat2, s191).  rc is NOT a liveness signal; minting here pins
#                  SPITBOL's error report as the definition of correct, and the program then "passes" forever by failing.
#   EMPTY       -- rc 0 and ZERO BYTES.  A 0-byte .ref grades "produced nothing" as correct.  This is the shape that nearly
#                  manufactured 134 vacuous passes at s191, and it is the most dangerous class precisely because it looks clean.
#   RC<n>/SIG<n>/TIMEOUT -- the oracle could not run the program at all; it has no answer to record.
# ⛔ THE ORACLE IS INVOKED THROUGH `scorecard_snobol4.sh oracle`, NEVER RE-DERIVED HERE.  A .ref minted under a different cwd, lib
# path, stdin or flag set than the board GRADES with is a pin that can never match -- seat5 hit that twice in one session and
# wrote the rule: a census is a harness, copy run_one, never re-derive it.  Validated on a program that already had a pin:
# feat/f13_eval_code minted through this door is BYTE-IDENTICAL to its checked-in .ref.
# ⛔ lon/ AND include/ ARE REFUSED BY CONSTRUCTION, not skipped at run time (RULES.md: lon is a CREDENTIAL rule
# -- do not run, do not read into a transcript; include/ is under HQ's conservative interim pending Lon's boundary ruling).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SC="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$SC/.." && pwd)}"; CORPUS="${CORPUS:-$S4E/corpus}"
BOARD="$SC/../harness/scripts/scorecard_snobol4.sh"
suite="${1:?usage: $0 <suite> <dir>... [--apply]}"; shift
apply=""; dirs=""
for a in "$@"; do case "$a" in --apply) apply=1;; *) dirs="${dirs:+$dirs }$a";; esac; done
[ -n "$dirs" ] || { echo "usage: $0 <suite> <dir>... [--apply]" >&2; exit 2; }
for d in $dirs; do case "$(cd "$d" 2>/dev/null && pwd)/" in *"/programs/lon/"*|*"/programs/include/"*)
  echo "⛔ REFUSED $d: lon and include are excluded BY CONSTRUCTION (RULES.md credential rule / HQ interim). There is no flag that mints them." >&2; exit 2;; esac; done
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
printf 'STATUS\tPROGRAM\tRC\tBYTES\tACTION\n'
n_live=0; n_have=0; n_dead=0; n_empty=0; n_unrun=0; n_mint=0
for f in $(for d in $dirs; do find "$d" -name '*.sno'; done | sort); do
  rel="${f#$CORPUS/}"
  if [ -f "${f%.sno}.ref" ]; then printf 'HAVE_REF\t%s\t-\t-\tkept (pre-existing pin, never overwritten)\n' "$rel"; n_have=$((n_have+1)); continue; fi
  r="$(bash "$BOARD" oracle "$suite" "$f" "$W/out" 2>/dev/null)"
  st="$(printf '%s' "$r" | cut -f1)"; rc="$(printf '%s' "$r" | cut -f2)"; by="$(printf '%s' "$r" | cut -f3)"
  case "$st" in
    LIVE)        n_live=$((n_live+1)); if [ -n "$apply" ]; then cp "$W/out" "${f%.sno}.ref"; n_mint=$((n_mint+1)); act="MINTED"; else act="would mint"; fi;;
    DEAD_REPORT) n_dead=$((n_dead+1));  act="NOT MINTED — oracle exited 0 while printing a FATAL ERROR DUMP; pinning it would define the error as correct";;
    EMPTY)       n_empty=$((n_empty+1)); act="NOT MINTED — oracle produced ZERO BYTES; a 0-byte pin grades 'produced nothing' as correct";;
    *)           n_unrun=$((n_unrun+1)); act="NOT MINTED — oracle-unrunnable, it has no answer to record";;
  esac
  printf '%s\t%s\t%s\t%s\t%s\n' "$st" "$rel" "$rc" "$by" "$act"
done
echo "----"
printf 'TOTALS: LIVE %d (minted %d) · HAVE_REF %d · DEAD_REPORT %d · EMPTY %d · UNRUNNABLE %d\n' "$n_live" "$n_mint" "$n_have" "$n_dead" "$n_empty" "$n_unrun"
[ -n "$apply" ] || echo "(census only — nothing written; re-run with --apply to mint)"
