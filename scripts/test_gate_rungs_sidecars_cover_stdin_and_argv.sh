#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# ../harness/scripts/test_gate_rungs_sidecars_cover_stdin_and_argv.sh -- EVERY RUNGS ENTRY THAT READS STDIN OR TAKES
# ARGUMENTS DECLARES THEM IN A SIDECAR, AND THE NUMBER THAT DO NOT ONLY EVER GOES DOWN.
# AUTHORS: Lon Jones Cherryholmes · Claude Opus 5   DATE: 2026-09-08
#
# Lon 2026-09-08, in-chat to hq_T, verbatim: "Ensure all has sister (side cars) files for the ONE-LINERS and
# MULTI-LINERS such that they have command-line args and an input file for each test along with the ref and
# source files."
#
# ⛔⭐⭐ THE DEFECT THIS CLOSES DOES NOT ANNOUNCE ITSELF, AND WE HAVE A MEASURED SPECIMEN. An entry that reads
# stdin but is graded against /dev/null does not crash and does not error: it takes EOF, prints whatever a
# starved run prints, and the mint records THAT as its .ref. From then on it passes forever, in both modes,
# while executing none of the behaviour it was written to test. corpus 6c94504c0 is one such entry cured --
# icon's 831 (rung36_jcon_recogn), whose input sat in tests/icon/config/ where loose_stdin_companion() did
# not look until SCRIP bc9812abe. Fed and re-cut from iconx, the Icon rungs went from a false 704/704 to an
# honest 703/704, and the red it exposed is a real oracle-confirmed engine defect that three sittings had
# already misattributed to a gate. ONE starved entry hid ONE engine bug for three sittings; this gate exists
# because the census then found 60 more of the same shape.
# ⭐ THE ARGV HALF IS THE SAME DEFECT WEARING A QUIETER FACE: `n := integer(args[1]) | 6` runs GREEN down the
# `| 6` default, so the board reports a pass for a program whose argument handling never ran. The harness has
# had complete argv-sidecar support since 2026-09-06 and NOT ONE rungs has ever carried an ALL.argv, so all
# 34 such entries are graded along their no-arguments path.
#
# ⛔⭐ A RATCHET, NOT A FAIL=0 BAR, AND THE CHOICE IS THE POINT. 95 entries owe a declaration today (61 stdin,
# 34 argv) and each one needs an AUTHORED input plus a ref re-cut from that language's oracle -- that is a
# campaign, not a landing. A FAIL=0 gate here would be red for every seat until the campaign finished, and an
# ignored gate is worse than no gate (hq_P's standing ruling on the retired optbypass watermark). So the bar
# is: THE OWED COUNT MAY NOT GROW. That is green on arrival, which is why it can be BLOCKING from the start,
# and it buys the thing actually worth having tonight -- nobody can add a 96th stdin-reading or argv-taking
# entry to any rung suite without also declaring its input, which is precisely how the first 95 accumulated.
# ⭐ RE-PIN DOWNWARD, NEVER UPWARD. The gate itself prints the new floor when the count falls, and a commit
# that lowers it re-pins in the same push. Raising a floor to make this gate pass is the one edit that voids
# it -- if a change genuinely needs a new undeclared entry, that is a ruling, not a number to bump.
#
# ⛔ THE CENSUS IS A WORK LIST, NEVER A PER-PROGRAM VERDICT. util_rungs_sidecar_census.py finds these by
# SOURCE CONSTRUCT, which is a heuristic: it can name an entry that says INPUT in a comment, and it cannot
# see a program reaching stdin by a route its table does not list. So this gate grades the COUNT, and the
# verdict on any individual entry belongs to the oracle once that entry is fed. It writes no sidecar and
# never invents input -- inventing plausible input is how you manufacture the self-pinned ref this exists
# to find.
#
# EXIT: 0 the owed count is at or below the pinned floor · 1 it GREW (or a floor needs lowering and did not)
#       · 2 REFUSED -- cannot measure (no corpus, no rungs, census returned an empty denominator).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="test_gate_rungs_sidecars_cover_stdin_and_argv"
gate_parse_args "$@"

# ⛔ THE PINNED FLOORS -- measured 2026-09-08 by hq_T at corpus 6c94504c0 over 5086 entries in 7 rung suites.
# Lower them in the commit that earns it; never raise them.
# 61 -> 53 at corpus 687132c48: eight snobol4 entries fed their recovered real input (crosscheck word1-4,
# cross, triplet, fileinfo, expr_eval), refs re-cut from sbl -bf. Zero changed verdict -- SCRIP was already
# right on all eight -- but each had been passing an EMPTY ref produced by a starved run.
# 53 -> 50 at SCRIP <this commit>: NO entry was fed. util_rungs_sidecar_census.py's Icon `reads(` pattern
# was unanchored and matched four entries that never touch stdin -- reads(f,i) reads from FILE f, and only a
# bare reads() defaults to the stream. All four bind their file with open() (one is NAMED ..._reads_from_
# file). ⭐ A FLOOR IS A COUNT OF A HEURISTIC'S OUTPUT, so it moves when the heuristic gets more accurate as
# well as when the campaign feeds an entry, and the two are NOT the same event: this commit lowered the
# floor and cured nothing. The receipt must say which of the two it did, because a floor drop reads as
# ⛔ 34 -> 6 at SCRIP <this commit> (coo 2026-09-19, row instrument-the-nineteen-non-gc-blocking-arms):
# NO entry was fed and NO debt was cured -- THIS IS A HEURISTIC ACCURACY MOVE, the same event as the
# 53 -> 50 above and not the same as the 61 -> 53. The argv count had GROWN to 39 against the pinned 34.
# All 36 raku entries in that count were FALSE POSITIVES of one cause: ARGV_RE is compiled re.I and the
# raku alternative was a bare `\bsub\s+MAIN\s*\(`, so it matched `sub main()` -- an ordinary lowercase
# subroutine with an EMPTY signature. Raku's MAIN is CASE-SENSITIVE; only `sub MAIN` receives @*ARGS.
# 33 of the 36 were exactly `sub main()` with empty parens. The alternative is now pinned case-sensitive
# with (?-i:...) in util_rungs_sidecar_census.py.
# ⭐ WHAT REMAINS IS 6 AND EVERY ONE IS REAL, which is why this is re-pinned to 6 rather than to 0:
#   icon procedure_every_scan_replace_13, _6, procedure_record_scan_replace_2 -- these genuinely READ
#     their arguments (args[1], *args > 0, open(args[1])), so they owe a declaration. Feeding them is a
#     CORPUS question -- what arguments, and their refs were cut bare -- not an instrument question, and
#     it is left to the owner of the Icon corpus rather than smuggled into a gate commit.
#   raku benchmark_spinner, benchmark_rc-forest-fire-stringify, benchmark_rc-mandelbrot -- real
#     `sub MAIN(...)` whose parameters are ALL DEFAULTED. They run correctly bare, so they are arguably
#     inert by the same reasoning as Icon's never-named parameter; but unlike that case they CAN observe
#     an argument if given one, so this seat did NOT widen inert_argv_match() to cover them. Left flagged
#     deliberately and routed to the ceo: extending the inert rule to all-defaulted signatures is a
#     criterion change, and a seat does not quietly make one to lower its own floor.
# campaign progress and would otherwise bank four entries of work nobody performed.
# ⛔⭐ 6 -> 3 at SCRIP <this commit> (coo 2026-09-20, ceo CEO-962 answering the ask the paragraph above
# routed): A THIRD KIND OF FLOOR MOVE, and the receipt must say which one it is, so: this is NOT a feed
# (61 -> 53) and NOT a heuristic-accuracy move (53 -> 50, 34 -> 6). IT IS A DECLARATION. The ceo REFUSED
# the widening, verbatim -- "DO NOT WIDEN inert_argv_match. THE FLOOR STAYS 6. ... A matcher widened to
# cover them silently absolves an unbounded future class of the same shape, and a criterion a widening
# satisfies while the debt stands is FALSE rather than lenient. THE CURE IS A DECLARATION BESIDE THE DATA
# ... The floor then falls honestly, by three named programs rather than by a rule nobody can see." The
# three raku entries are now NAMED, each with its reason, in corpus/tests/raku/ALL.argv.bare, which
# util_rungs_sidecar_census.py reads and corpus_suite_harness.py DOES NOT (`ALL.raku`.with_suffix(".argv")
# is `ALL.argv`, never `ALL.argv.bare`, and the string does not appear in the harness at all) -- so
# grading is byte-for-byte unchanged and a declaration ABOUT the measurement cannot change it.
# ⛔ THE DEBT IS NOT DENIED BY THE DROP: every reason says the entry can observe an argument if given one
# and that what to pass is a corpus question for the raku corpus owner. What is left at 3 is the three
# icon entries that genuinely read `args[1]`/`*args > 0`, and the ceo has taken them as corpus debt.
# ⛔ THE DECLARATION FILE REFUSES rc=2 rather than quietly excusing: a row with no reason, a row naming no
# entry in the rungs, and a name declared in BOTH ALL.argv and ALL.argv.bare are each a refusal, all
# three measured on a scratch tests-dir before this floor moved.
PIN_STDIN="${PIN_STDIN:-50}"
PIN_ARGV="${PIN_ARGV:-3}"

CENSUS="$HERE/util_rungs_sidecar_census.py"
[ -f "$CENSUS" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no census tool at $CENSUS"; gate_stamp; exit 2; }

# ⭐ TESTS_DIR EXISTS SO THIS GATE CAN BE PROVEN RED WITHOUT REDDENING THE REAL CORPUS -- the fail-once arm
# points it at a scratch copy carrying one deliberately undeclared entry. Unset, it censuses the real tree.
CENSUS_ARGS=()
[ -n "${TESTS_DIR:-}" ] && CENSUS_ARGS+=(--tests-dir "$TESTS_DIR")
# ⛔ CAPTURE FIRST, THEN TEST -- never `cmd | head; echo $?`, which reports the pager's status and not the
# census's (CLAUDE.md's own measured trap; it printed rc=0 for a command that exits 1).
out=$(python3 "$CENSUS" ${CENSUS_ARGS[@]+"${CENSUS_ARGS[@]}"} --json 2>&1); rc=$?
if [ "$rc" -ne 0 ]; then
  echo "GATE UNPROVEN(2) [$GATE_NAME]: the census could not measure -- ${out}"; gate_stamp; exit 2
fi

read -r examined n_stdin n_argv <<<"$(printf '%s' "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)
r=d["rows"]
print(d["examined"], sum(1 for x in r if x["owes_stdin"]), sum(1 for x in r if x["owes_argv"]))
')" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: could not parse the census JSON"; gate_stamp; exit 2; }

case "$examined" in ''|*[!0-9]*) echo "GATE UNPROVEN(2) [$GATE_NAME]: census printed no examined count"; gate_stamp; exit 2;; esac
[ "$examined" -gt 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: censused ZERO entries -- an empty denominator is not a clean census"; gate_stamp; exit 2; }
GATE_EXAMINED="$examined rungs entries"

# ⛔⭐ THE PROBE FLOORS EXIST SO THE NAMING BELOW CAN BE FAIL-ONCE PROVEN WITHOUT TOUCHING THE CORPUS (hq_T 2026-09-09,
# ceo CEO-468 item 3). They can only ever make the gate STRICTER: a probe value is used only when it is LOWER than the
# pinned floor, so no operator can smuggle debt past this gate with an environment variable. Same shape and same reason
# as SCRIP_STALE_PROBE_SRC in gate_require_fresh -- a proof that has to edit the thing it grades is how a green gate and
# a dirty tree come to coexist.
if [ -n "${SIDECAR_PROBE_FLOOR_STDIN:-}" ] && [ "$SIDECAR_PROBE_FLOOR_STDIN" -lt "$PIN_STDIN" ] 2>/dev/null; then PIN_STDIN="$SIDECAR_PROBE_FLOOR_STDIN"; _probed=1; fi
if [ -n "${SIDECAR_PROBE_FLOOR_ARGV:-}" ] && [ "$SIDECAR_PROBE_FLOOR_ARGV" -lt "$PIN_ARGV" ] 2>/dev/null; then PIN_ARGV="$SIDECAR_PROBE_FLOOR_ARGV"; _probed=1; fi
[ -n "${_probed:-}" ] && echo "⚠ PROBE FLOORS IN EFFECT (stdin=$PIN_STDIN argv=$PIN_ARGV) -- this run is STRICTER than the pinned gate and is not the tree's verdict"
echo "SIDECAR DEBT: stdin=$n_stdin (floor $PIN_STDIN) · argv=$n_argv (floor $PIN_ARGV) · examined $examined entries in 7 rung suites"
# ⛔⭐ A COUNT WITHOUT NAMES CANNOT BE TRIAGED (ceo CEO-468 item 3, after this gate red every seat's make test with two
# numbers and no way to act on them). The census already carries the per-entry rows; it was simply summing them and
# throwing the names away, so every seat that hit this had to re-run a separate census tool to learn WHAT to fix -- and
# most did not, they just landed past it. ⭐ The general form: a gate that names nothing converts a work item into a
# nuisance, and a nuisance is what a fleet learns to step over. Names are capped so a large regression cannot bury the
# verdict line, with the exact command for the rest.
_owed_names() {
  printf '%s' "$out" | OWEFIELD="$1" python3 -c '
import json,os,sys
f=os.environ["OWEFIELD"]; d=json.load(sys.stdin)
rows=[x for x in d["rows"] if x.get(f)]
for x in rows[:20]: print("     %-10s %s" % (x.get("lang","?"), x.get("name","?")))
if len(rows)>20: print("     ... and %d more" % (len(rows)-20))
' 2>/dev/null
}
bad=0
if [ "$n_stdin" -gt "$PIN_STDIN" ]; then
  echo "⛔ GREW: $n_stdin entries read stdin with no ALL.in block, above the pinned $PIN_STDIN."
  echo "   A new entry that reads stdin must ship its input in the same commit -- unfed, its ref records the"
  echo "   STARVED run and it passes forever while testing nothing (corpus 6c94504c0 is that bug, cured)."
  echo "   THE ENTRIES THAT OWE AN ALL.in BLOCK:"
  _owed_names owes_stdin
  echo "   all of them: python3 ../harness/scripts/util_rungs_sidecar_census.py"
  bad=$((bad+1))
fi
if [ "$n_argv" -gt "$PIN_ARGV" ]; then
  echo "⛔ GREW: $n_argv entries take program arguments with no ALL.argv declaration, above the pinned $PIN_ARGV."
  echo "   Declare them: one 'name<TAB>arg<TAB>arg' line in the rungs' ALL.argv (read_argv_sidecar)."
  echo "   THE ENTRIES THAT OWE AN ALL.argv DECLARATION:"
  _owed_names owes_argv
  echo "   all of them: python3 ../harness/scripts/util_rungs_sidecar_census.py"
  bad=$((bad+1))
fi
if [ "$n_stdin" -lt "$PIN_STDIN" ] || [ "$n_argv" -lt "$PIN_ARGV" ]; then
  echo "⭐ DEBT FELL — re-pin in this commit: PIN_STDIN=$n_stdin PIN_ARGV=$n_argv"
  echo "   (a floor is only ever lowered; the names are in: python3 ../harness/scripts/util_rungs_sidecar_census.py)"
fi
gate_verdict "$bad" "sidecar debt counts above their pinned floor"
