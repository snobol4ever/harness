#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ==============================================================================================
# GATE / DONE-WHEN for row snobol4-generator-exhaustive-expressions-graded-against-the-oracle
# (seat16, hq_T / GENERATORS lane, FLEET-20; task file at
# /home/resources/postoffice/tasks/snobol4-generator-exhaustive-expressions-graded-against-the-oracle.task.md).
#
# Runs util_generate_snobol4_exhaustive_expressions.py's rung 1 (length-1 and length-2 expressions, single
# '+' operator, population 110 by construction -- a number this gate states and checks, per the task's own
# requirement that the first rung's denominator be "checkable by hand"), grading every program against BOTH
# scrip and the shared correctness oracle (sbl_correctness_bin, ALWAYS -bf -- lib_oracle_flags.sh, the one
# authority; never a hand-rolled path).
#
# ⛔ REFUSES rc=2 on: missing python3/generator/scrip/oracle, a dead or -bf-incapable oracle (the generator's
# own capability probe), an empty (zero) population, or a rung-1 population that is not exactly the stated
# 110 (a silent change to the vocabulary without updating this gate's stated denominator is itself a defect
# this gate exists to catch -- "the shrunken-denominator law", corpus README / util_build_rungs_suite.py).
# ⛔ FAILS rc=1 on: any infra failure during grading (timeout/exec error on a nonzero population -- distinct
# from "could not measure at all"), or any real divergence between scrip and the oracle. A divergence is a
# genuine finding, routed to hq_P (SNOBOL4) per the task file, never swallowed here to keep the board green.
# PASSES rc=0 only when the full stated population graded clean with zero divergence.
# ==============================================================================================
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
GEN="$HERE/util_generate_snobol4_exhaustive_expressions.py"
RUNG=1
EXPECT_GENERATED=110

command -v python3 >/dev/null 2>&1 || { echo "⛔ REFUSED-TO-GRADE rc=2: python3 not on PATH"; exit 2; }
[ -f "$GEN" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: generator missing: $GEN"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: scrip is not built at $ROOT/scrip -- run make"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ORACLE="$(sbl_correctness_bin 2>/dev/null)" || ORACLE=""
[ -n "$ORACLE" ] && [ -x "$ORACLE" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: no SNOBOL4 correctness oracle (sbl_correctness_bin)"; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/gate_gen_oracle.XXXXXX")" || { echo "⛔ REFUSED-TO-GRADE rc=2: mktemp failed"; exit 2; }
trap 'rm -rf "$WORK"' EXIT

echo "=== gate: generator/oracle agreement, rung $RUNG -- $(date -u +%FT%TZ) ==="
echo "  scrip:  $ROOT/scrip"
echo "  oracle: $ORACLE"

out="$(python3 "$GEN" --rung "$RUNG" --out-dir "$WORK" --scrip "$ROOT/scrip" --oracle "$ORACLE" 2>&1)"
gen_rc=$?
printf '%s\n' "$out"

if [ "$gen_rc" -eq 2 ]; then
    echo "⛔ REFUSED-TO-GRADE rc=2: generator itself refused (see REFUSED-TO-GRADE line above)"
    exit 2
elif [ "$gen_rc" -ne 0 ]; then
    echo "⛔ REFUSED-TO-GRADE rc=2: generator exited $gen_rc (unexpected -- neither 0 nor its own refusal 2)"
    exit 2
fi

summary="$(printf '%s\n' "$out" | grep -o 'SUMMARY generated=[0-9]* graded=[0-9]* infra_failed=[0-9]* diverged=[0-9]*' | tail -1)"
[ -n "$summary" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: no SUMMARY line in generator output -- cannot state a denominator"; exit 2; }
generated="$(printf '%s\n' "$summary" | grep -o 'generated=[0-9]*' | cut -d= -f2)"
graded="$(printf '%s\n' "$summary" | grep -o 'graded=[0-9]*' | cut -d= -f2)"
infra_failed="$(printf '%s\n' "$summary" | grep -o 'infra_failed=[0-9]*' | cut -d= -f2)"
diverged="$(printf '%s\n' "$summary" | grep -o 'diverged=[0-9]*' | cut -d= -f2)"

echo "  denominator: generated=$generated graded=$graded infra_failed=$infra_failed diverged=$diverged (expected generated=$EXPECT_GENERATED)"

if [ "${generated:-0}" -eq 0 ] || [ "${graded:-0}" -eq 0 ]; then
    echo "⛔ REFUSED-TO-GRADE rc=2: vacuous run (generated=$generated graded=$graded) -- a gate that passes over an empty population is the false-green shape this row exists to prevent"
    exit 2
fi
if [ "$generated" -ne "$EXPECT_GENERATED" ]; then
    echo "⛔ REFUSED-TO-GRADE rc=2: rung $RUNG population is $generated, expected exactly $EXPECT_GENERATED -- the vocabulary changed without this gate's stated denominator being updated"
    exit 2
fi
if [ "${infra_failed:-0}" -ne 0 ]; then
    echo "⛔ FAIL rc=1: $infra_failed program(s) hit an infra failure (timeout/exec error) mid-grade -- a nonzero population that did not fully grade is not a clean run"
    exit 1
fi
if [ "${diverged:-0}" -ne 0 ]; then
    echo "⛔ FAIL rc=1: $diverged divergence(s) between scrip and the oracle over rung $RUNG's full population -- see DIVERGE lines above and $WORK before it is cleaned up; file as a class row routed to hq_P (SNOBOL4), per the task file, before re-running"
    exit 1
fi

echo "✅ PASS: rung $RUNG exhaustive population ($EXPECT_GENERATED/$EXPECT_GENERATED) graded clean, 0 divergence from the oracle"
exit 0
