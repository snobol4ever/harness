#!/usr/bin/env bash
# test_gate_suite_argv_sidecar.sh — the invariant gate for the suite format's PROGRAM-ARGUMENTS sidecar
# (row `icon-suite-format-has-no-argv-sidecar-so-argv-taking-witnesses-are-ungradable`, hq_T 2026-09-06,
# dispatched by hq_I; found by seat03 on procedure_scan_while_1, both halves verified by hq_B).
#
# WHAT IT PROTECTS. corpus_suite_harness.py's suite format carried a stdin sidecar and a want-rc sidecar
# and NO ARGV SIDECAR, so run_suite_entry() ran every entry with an EMPTY argv and had no way to say
# otherwise. ⛔⭐ THE DAMAGE IS NOT A RED BOARD — IT IS A GREEN ONE. An Icon witness written
# `n := integer(args[1]) | 6` runs to completion with no arguments at all: it takes the `| 6` default,
# prints the expected text, and the suite scores it PASS. The argument handling the witness exists to
# exercise was never executed, and nothing anywhere says so. That is a pass that documents nothing, and
# it is invisible to every gate in the tree — including this file's ancestors — because a criterion that
# is never evaluated looks exactly like a criterion that was satisfied.
#
# ⛔ AND THE FIRST WITNESS WORE THE WRONG EXPLANATION. procedure_scan_while_1 carried an `.xfail` marker
# reading as "the compiler is known-red here" when the compiler was CORRECT — verified: the driver has
# always passed argv (`scrip p.icn -- -n10 foo` -> argc=2, both args in order), and the harness simply
# had nowhere to declare them. A marker naming a defect that does not exist is a FALSE marker, and the
# stale-marker gate cannot see it: it checks whether a marked entry still fails, never whether the
# reason is true. So the sidecar is the cure and this gate is what keeps the cure honest.
#
# ⭐⭐ THE LOAD-BEARING ARM IS ARM 1, AND IT IS WRITTEN THE ONLY WAY THAT PROVES ANYTHING: the SAME
# entry is graded TWICE against the SAME .ref, once with the sidecar present and once with it renamed
# away. The sidecar run must PASS and the sidecar-less run must FAIL. A gate that only asserted "with
# the sidecar it passes" would go green against a harness that ignored the file entirely — the exact
# failure the sidecar was written against, reproduced inside its own gate.
#
# Usage: bash ../harness/scripts/test_gate_suite_argv_sidecar.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
. "$HERE/lib_board_line.sh"      # board_is: a board field is read BY NAME, never by adjacency (CEO-839)
gate_parse_args "$@"

H="$HERE/corpus_suite_harness.py"
gate_require "$H" "the suite harness corpus_suite_harness.py"
gate_require_exec "$ROOT/scrip" "the scrip binary (this gate RUNS witnesses, in m3 and m4)"
# ⛔⭐ THE FRESHNESS GUARD IS MANDATORY FOR ANY GATE THAT EXECUTES ./scrip, and this file shipped its
# first green WITHOUT it -- caught not by review but by test_gate_runners_refuse_on_a_stale_binary.sh's
# census arm, which counts every scrip-executing test_gate_* and names the ones with no guard. Without
# it this gate would grade a witness on yesterday's binary and report a verdict about a tree that no
# longer exists; ARM 2 in particular ("without the sidecar it must go RED") would keep passing off a
# stale build long after the harness change it protects had been reverted.
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"

violations=0
examined=0
TD="$(mktemp -d "${TMPDIR:-/tmp}/argv_sidecar.XXXXXX")"
trap 'rm -rf "$TD"' EXIT

# ⭐ TWO ENTRIES, AND THE SECOND ONE IS THE CONTROL. `plain` declares no arguments and must grade
# identically either way; without it a whole-suite PASS/FAIL tells you nothing about WHICH entry moved.
cat > "$TD/F.icn" <<'EOF'
#------------------------------------------------------------ 1 takes_args
procedure main(args)
   write("n=", integer(args[1]) | 6);
   write("also=", args[2] | "none");
end
#------------------------------------------------------------ 2 plain
procedure main()
   write("control");
end
EOF
cat > "$TD/F.ref" <<'EOF'
#------------------------------------------------------------ 1 takes_args
n=41
also=two words
#------------------------------------------------------------ 2 plain
control
EOF
# ⛔ TABS ARE THE FORMAT, and `also=two words` above is why: the second argument CONTAINS A SPACE and
# must arrive whole. A space-separated sidecar would split it, so this line is simultaneously the
# round-trip test for the no-quoting-language rule.
printf 'takes_args\t41\ttwo words\n' > "$TD/F.argv"

board() { python3 "$H" run "$TD/F.icn" "$TD/F.ref" --lang icon --modes "$1" 2>&1; }

# ARM 1 — WITH the sidecar, both modes grade the argv-reading entry green.
for m in m3 m4; do
    examined=$((examined + 1))
    out="$(board "$m")"; rc=$?
    # BY NAME, not by adjacency (CEO-839): a board that gains a field between _pass and _fail is still this board
    _ab="$(grep -m1 '^SUITE_BOARD ' <<<"$out")"
    if [ "$rc" -ne 0 ] || ! { board_is "$_ab" "${m}_pass" 2 && board_is "$_ab" "${m}_fail" 0; }; then
        echo "GATE FAIL: with F.argv present, $m did not grade the suite clean (rc=$rc)"
        printf '%s\n' "$out" | sed 's/^/    /'
        violations=$((violations + 1))
    fi
done

# ARM 2 — WITHOUT it, the SAME pair must go RED. This is the arm that proves the file is read at all.
mv "$TD/F.argv" "$TD/F.argv.parked"
for m in m3 m4; do
    examined=$((examined + 1))
    out="$(board "$m")"
    if printf '%s' "$out" | grep -q "${m}_fail=0"; then
        echo "GATE FAIL: with F.argv REMOVED, $m still graded FAIL=0 — the sidecar is not being read,"
        echo "    and a suite that passes with or without a declaration is not honouring it."
        printf '%s\n' "$out" | sed 's/^/    /'
        violations=$((violations + 1))
    fi
done
mv "$TD/F.argv.parked" "$TD/F.argv"

# ARM 3 — the control entry is untouched by any of this: an absent sidecar must leave a no-argument
# entry byte-identical to its pre-sidecar behaviour (no stray `--` reaching the driver, which has no
# unknown-flag diagnostic and would swallow it as a filename).
examined=$((examined + 1))
cat > "$TD/C.icn" <<'EOF'
#------------------------------------------------------------ 1 plain
procedure main()
   write("control");
end
EOF
printf '#------------------------------------------------------------ 1 plain\ncontrol\n' > "$TD/C.ref"
out="$(python3 "$H" run "$TD/C.icn" "$TD/C.ref" --lang icon --modes m3,m4 2>&1)"; rc=$?
_cb="$(grep -m1 '^SUITE_BOARD ' <<<"$out")"   # BY NAME, not by adjacency (CEO-839)
if [ "$rc" -ne 0 ] || ! { board_is "$_cb" m3_pass 1 && board_is "$_cb" m3_fail 0 && board_is "$_cb" m4_pass 1 && board_is "$_cb" m4_fail 0; }; then
    echo "GATE FAIL: a family with NO .argv sidecar no longer grades clean (rc=$rc) — the new parameter"
    echo "    changed behaviour for callers that never asked for it."
    printf '%s\n' "$out" | sed 's/^/    /'
    violations=$((violations + 1))
fi

# ARMS 4-6 — THE REFUSALS, which are as much the product as the writes are. Each must be REFUSED, not
# absorbed: a sidecar that quietly ignores what it cannot honour re-creates the silent-default defect
# one layer up.
# ⛔⭐ THE SIDECAR CONTENT IS AN ARGUMENT, NOT A PIPE, AND THAT IS NOT STYLE. `printf ... | refuses ...`
# runs the function in a SUBSHELL, so every `violations=$((violations + 1))` inside it is discarded when
# the subshell exits -- the gate detects each refusal correctly, reports it on stderr, and then returns
# ZERO violations. Measured on this very file's first run: three real failures printed, "examined 0"
# summarised, and only the exit code of an unrelated arm kept it red. A counter incremented behind a
# pipe is the same class as the $?-after-a-pipeline trap: the shell answers a narrower question than
# the one you meant to ask, and says nothing about the difference.
refuses() {  # refuses <label> <needle> <sidecar-content>
    local label="$1" needle="$2"
    examined=$((examined + 1))
    printf '%s' "$3" > "$TD/F.argv"
    local out rc
    out="$(board m3 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ] || ! printf '%s' "$out" | grep -qi "$needle"; then
        echo "GATE FAIL: $label was not refused (rc=$rc, expected nonzero and a message naming '$needle')"
        printf '%s\n' "$out" | sed 's/^/    /'
        violations=$((violations + 1))
    fi
}
refuses "a declaration naming no entry"      "no matching entry"    "$(printf 'takes_args\t41\ttwo words\nno_such_entry\t9\n')"
refuses "a name declared with no arguments"  "declares no arguments" "$(printf 'takes_args\n')"

# ARM 6 — an ast-only family may not declare arguments: --dump-ast never RUNS the program, so the
# declaration could not reach it, and a criterion that cannot be evaluated must never look satisfied.
examined=$((examined + 1))
printf 'takes_args\t41\ttwo words\n' > "$TD/F.argv"
# ⛔ SINCE 2026-09-25 (coo, row instruments-the-harness-defaults-...-to-the-dead-ast-mode-...) the harness refuses
# --modes ast OUTRIGHT, rc=2, before any entry is read: the grade it asks for is a could-not-measure, so the argv
# declaration can never be silently dropped under it. This arm pins that refusal by its own words. The earlier
# check, rc != 0 and any line matching 'never', read green off the ARENA banner's prose once ast refused
# for a different reason.
out="$(python3 "$H" run "$TD/F.icn" "$TD/F.ref" --lang icon --modes ast 2>&1)"; rc=$?
if [ "$rc" -ne 2 ] || ! printf '%s' "$out" | grep -q 'graded in m3 and m4 only'; then
    echo "GATE FAIL: an ast-only grading accepted an .argv declaration it cannot possibly execute (rc=$rc)"
    printf '%s\n' "$out" | sed 's/^/    /'
    violations=$((violations + 1))
fi

GATE_EXAMINED="$examined arms"
gate_verdict "$violations" "argv-sidecar violations"
