#!/usr/bin/env bash
# test_gate_fleet_protocol_e2e.sh — the FLEET PROTOCOL end to end, in a THROWAWAY postoffice.
#
# WHY THIS EXISTS: V2-1's gate tests the picker and V2-4's tests identity, but NOTHING tested the loop a
# seat actually runs — check → next → work → suspend → resume → done → board — or the four baton ports.
# The hole that proves the point: `done` appended the DONE marker UNCONDITIONALLY and never ran the task's
# DONE-WHEN, so the one command whose job is to certify completion took the seat's word for it. Two gates
# were green over that for a whole session because neither of them ran a whole lifecycle.
#
# ⛔ NEGATIVE-TESTED: S4E_MSG_BIN=<older script> must FAIL this gate. A gate that cannot say NO is not a gate.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="${S4E_MSG_BIN:-$HERE/s4e_msg.sh}"
pass=0; fail=0
ok(){ pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
no(){ fail=$((fail+1)); printf '  FAIL %s\n     expected: %s\n     actual  : %s\n' "$1" "$2" "$3"; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
P="$T/po"; mkdir -p "$P/claims" "$P/tasks" "$P/seatX/inbox" "$P/hq_C/inbox"
printf '# idx\n0\twin-task\tb\ts\n5\tother-task\tb\ts\n' > "$P/QUEUE.tsv"
run(){ local seat="$1"; shift; S4E_POST="$P" S4E_SEAT="$seat" S4E_NO_BANNER=1 bash "$MSG" "$@" 2>&1; }
mktask(){ # $1 topic, $2 done-when command
  cat > "$P/tasks/$1.task.md" <<EOF
# TASK $1 · owner: hq_C · state: FREE
GOAL: exercise the protocol
DONE-WHEN: $2
## NEXT
step one
## QA
## LEDGER
EOF
}

echo "== α  HQ mints a baton and assigns it; the seat is served THAT, first =="
mktask win-task "test -f $T/flag"
run hq_C assign seatX win-task >/dev/null
o="$(run seatX next)"
case "$o" in *"ASSIGNED->RUNNING win-task"*) ok "next serves the assigned task ahead of the rank-0 free row";;
  *) no "assigned-first" "ASSIGNED->RUNNING win-task" "$(echo "$o"|head -1)";; esac
case "$o" in *"$P/tasks/win-task.task.md"*) ok "next prints the BATON path, not just a brief";;
  *) no "baton path printed" "tasks/win-task.task.md" "$(echo "$o"|head -3|tr '\n' ' ')";; esac
case "$o" in *"THE BATON IS THE TASK FILE"*) ok "and tells the seat the file is authoritative, not the printout";;
  *) no "authority notice" "THE BATON IS THE TASK FILE" "(absent)";; esac

echo "== γ  DONE IS COMPUTED — done must REFUSE while the DONE-WHEN fails =="
o="$(run seatX done win-task)"; rc=$?
case "$o" in *"NOT DONE"*) ok "done REFUSES when the DONE-WHEN exits non-zero";;
  *) no "done refuses on failing DONE-WHEN" "⛔ NOT DONE ..." "$(echo "$o"|head -2|tr '\n' ' ')";; esac
grep -q '^DONE$' "$P/claims/win-task.claim" && no "claim must stay open on refusal" "no DONE marker" "DONE marker written" || ok "the claim is left OPEN — a refused close changes nothing"
case "$o" in *"Do NOT weaken a DONE-WHEN"*) ok "and it warns against the false-green cure";;
  *) no "false-green warning" "Do NOT weaken a DONE-WHEN" "(absent)";; esac

echo "== γ  …and ACCEPTS the moment the criterion is genuinely met =="
touch "$T/flag"
o="$(run seatX done win-task)"
case "$o" in *"DONE-WHEN exited 0"*) ok "done verifies and reports the criterion computed";;
  *) no "done accepts on passing DONE-WHEN" "✅ DONE-WHEN exited 0" "$(echo "$o"|head -2|tr '\n' ' ')";; esac
grep -q '^DONE$' "$P/claims/win-task.claim" && ok "and only NOW is the DONE marker written" || no "DONE marker" "present" "absent"

echo "== ω  the override exists, is LOUD, and is RECORDED =="
mktask other-task "false"
run hq_C assign seatX other-task >/dev/null; run seatX next >/dev/null
o="$(S4E_POST="$P" S4E_SEAT=seatX S4E_NO_BANNER=1 S4E_DONE_OVERRIDE="the criterion is provably wrong" bash "$MSG" done other-task 2>&1)"
case "$o" in *"OVERRIDDEN"*) ok "an override is announced, not silent";;
  *) no "override announced" "DONE-WHEN OVERRIDDEN" "$(echo "$o"|head -1)";; esac
grep -q 'OVERRIDE-BY .* reason: the criterion is provably wrong' "$P/claims/other-task.claim" \
  && ok "and the reason is written into the claim, so it is auditable" \
  || no "override recorded" "OVERRIDE-BY ... reason: ..." "$(tr '\n' ' ' < "$P/claims/other-task.claim")"

echo "== a task with a baton but NO DONE-WHEN cannot be closed at all =="
printf '# TASK naked · owner: hq_C\nGOAL: x\n## NEXT\ny\n' > "$P/tasks/naked.task.md"
printf '9\tnaked\tb\ts\n' >> "$P/QUEUE.tsv"
run hq_C assign seatX naked >/dev/null; run seatX next >/dev/null
o="$(run seatX done naked)"
case "$o" in *"no DONE-WHEN"*) ok "a baton with no computable criterion is refused, not waved through";;
  *) no "no-DONE-WHEN refusal" "REFUSED ... no DONE-WHEN" "$(echo "$o"|head -1)";; esac

echo "== γ  a VACUOUS DONE-WHEN must be refused — it certifies nothing (hq_P's find) =="
P=$(mktemp -d); mkdir -p "$P/claims" "$P/tasks" "$P/seatX/inbox" "$P/hq_C/inbox"
printf '# idx\n0\tvac\tb\ts\n0\tvac2\tb\ts\n0\tvac3\tb\ts\n' > "$P/QUEUE.tsv"
vactest(){ # $1 topic, $2 done-when, $3 label
  cat > "$P/tasks/$1.task.md" <<EOF
# TASK $1 · owner: hq_C · state: FREE
GOAL: g
DONE-WHEN: $2
## NEXT
n
EOF
  run hq_C assign seatX "$1" >/dev/null 2>&1; run seatX next >/dev/null 2>&1
  o="$(run seatX done "$1")"
  case "$o" in *REFUSED*) ok "refuses $3";; *) no "refuse $3" "⛔ REFUSED" "$(echo "$o"|head -1)";; esac
  grep -q '^DONE$' "$P/claims/$1.claim" 2>/dev/null && no "$3 must not close the row" "no DONE marker" "row was closed" || true; }
vactest vac  "true"     "DONE-WHEN: true"
vactest vac2 ":"        "DONE-WHEN: :"
vactest vac3 "echo hi"  "a command that passes in an empty directory"
rm -rf "$P"

printf '\n  %s: %d passed, %d failed\n' "$([ "$fail" -eq 0 ] && echo PASS || echo '⛔ FAIL')" "$pass" "$fail"
[ "$fail" -eq 0 ]
