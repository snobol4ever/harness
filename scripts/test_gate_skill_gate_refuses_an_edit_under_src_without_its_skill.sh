#!/usr/bin/env bash
# test_gate_skill_gate_refuses_an_edit_under_src_without_its_skill.sh -- THE SKILL GATE's fixtures (the cto, 2026-11-01; Lon: "Ensure the skills
# are described properly so that each seat will use them"). s4e_skill_gate.py is the PreToolUse hook of every root; its --self-test judges
# fourteen planted tool calls against planted transcripts: an edit of a lowerer, a template, an rtx leaf, a parser, a ref, a gate, a generated
# table, a README, and Bash commands with and without write intent, each with the owning skills loaded or not. Hermetic. rc 0 all arms as
# expected; 1 an arm judged wrong; 2 cannot measure (no python3 or no gate script).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; G=skill_gate_refuses_an_edit_under_src_without_its_skill
[ -f "$HERE/s4e_skill_gate.py" ] && command -v python3 >/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: s4e_skill_gate.py or python3 absent"; exit 2; }
out="$(python3 -I "$HERE/s4e_skill_gate.py" --self-test 2>&1)"; rc=$?
printf '%s\n' "$out"
n=$(printf '%s\n' "$out" | grep -c ' ARM ')
if [ "$rc" = 0 ]; then echo "GATE PASS(0) [$G]: $n arms -- the gate refuses an edit of a layer whose skill the session has not loaded, names the skills, and passes everything else"; exit 0
else echo "GATE FAIL(1) [$G]: see the RED arms"; exit 1; fi
