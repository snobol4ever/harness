#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a two-line mktemp witness, not a board (CEO-523/CEO-547)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_snocone_deferred_eval_survives_a_collection.sh
#
# ROW: snocone-gc-the-snocone-share-of-the-unmapped-slot-population-censused-by-name-and-the-master-clean-under-forced-collection
# (hq_snocone, 2026-09-20, TENET CONDITION 1). ⛔ THIS GATE IS RED ON ORIGIN TODAY AND THAT IS THE POINT --
# `make test-arena` sweeps every ../harness/scripts/test_gate_gc_*.sh and its own recipe says every RED here is a collector
# finding that owes a ROW. This one owes the row named above. Read the NAME, not the exit code, until it closes.
#
# THE DEFECT, minimal at two lines and NOT snocone-specific (measured 2026-09-20 by hq_snocone, handed to the cfo):
#     d = *1;                      EVAL of a DEFERRED EXPRESSION value returns the NULL STRING -- not a failure,
#     OUTPUT = EVAL(d);            not a crash, not a diagnostic -- when a collection lands inside EVAL's road.
# `sbl -bf` says 1. SCRIP says 1 with no collection and "" with one, rc=0 BOTH TIMES, and the statement SUCCEEDS
# (a `:F()` branch is not taken), so no conditional in any program can see it. The SNOBOL4 twin of the same two
# lines reproduces it identically, which is why the cure is a SHARED node and not this lane's to land.
#
# ⛔ THE ARENA IS NOT THE DISCRIMINATOR AND A TINY-ARENA-ONLY READING WOULD HAVE MISSED IT. It reproduces at the
# SHIPPED 512 MB arena too; what it needs is a collection at one particular allocation. SCRIP_GC_STRESS=1 is how
# this gate reaches that allocation cheaply -- stress 2,3,4,5,8 all answer CORRECTLY over the same program with
# the SAME number of collections, so the count of collections is not the discriminator either.
#
# ⛔ THE REF COMES FROM THE ORACLE AT GATE TIME, never from a pinned literal and never from our own output: the
# whole class is a plausible wrong answer, so a self-pinned ref would pin the wrong answer the day it regresses.
#
# Commit identity: LCherryholmes / lcherryh@yahoo.com  (RULES.md)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP_DIR="$S4E/SCRIP"
SCRIP="${SCRIP:-$SCRIP_DIR/scrip}"
. "$HERE/lib_oracle_flags.sh" || { echo "REFUSES rc=2: cannot source lib_oracle_flags.sh -- a private -bf default is a different language (s189)"; exit 2; }
fail() { echo "⛔ RED: $*" >&2; exit 1; }
refuse() { echo "REFUSES rc=2: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "scrip not built at $SCRIP -- cannot measure"
SBL="$(sbl_correctness_bin)" || refuse "no SPITBOL correctness oracle -- a missing oracle prints a full, plausible, entirely false table"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
printf 'd = *1;\nOUTPUT = EVAL(d);\n' > "$W/w.sc"
printf '\tD = *1\n\tOUTPUT = EVAL(D)\nEND\n' > "$W/w.sno"
WANT="$("$SBL" $(sbl_lang_flags) "$W/w.sno" < /dev/null 2>/dev/null)" || refuse "the oracle itself refused $W/w.sno -- nothing to grade against"
[ -n "$WANT" ] || refuse "the oracle produced NO output for the witness -- an empty want cannot discriminate the defect, which IS emptiness"
bad=0
for arm in "snocone $W/w.sc" "snobol4 $W/w.sno"; do
    set -- $arm; lang="$1"; src="$2"
    got="$("$SCRIP" "$src" < /dev/null 2>/dev/null)"; rc=$?
    [ "$rc" -eq 0 ] || fail "$lang arm at stress=0 exited rc=$rc -- this gate grades a WRONG ANSWER, so a crash here is a different finding"
    [ "$got" = "$WANT" ] || fail "$lang arm is already wrong WITHOUT a collection (want=[$WANT] got=[$got]) -- that is not this gate's class"
    got="$(SCRIP_GC_STRESS=1 "$SCRIP" "$src" < /dev/null 2>/dev/null)"; rc=$?
    if [ "$rc" -ne 0 ]; then echo "  RED   $lang stress=1 rc=$rc (want [$WANT])"; bad=$((bad + 1))
    elif [ "$got" != "$WANT" ]; then echo "  RED   $lang stress=1 want=[$WANT] got=[$got] rc=0 -- SILENT WRONG ANSWER"; bad=$((bad + 1))
    else echo "  GREEN $lang stress=1 [$got]"; fi
done
echo "deferred-eval-under-collection: arms=2 red=$bad oracle=$SBL $(sbl_lang_flags)"
[ "$bad" -eq 0 ] || fail "$bad of 2 arms return a wrong answer under forced collection -- row snocone-gc-the-snocone-share-of-the-unmapped-slot-population-censused-by-name-and-the-master-clean-under-forced-collection, handed to the cfo (collector / safe-point road)"
echo "✅ deferred EVAL survives a collection in both frontends"
