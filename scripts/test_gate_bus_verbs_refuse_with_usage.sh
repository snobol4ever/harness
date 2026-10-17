#!/usr/bin/env bash
# test_gate_bus_verbs_refuse_with_usage.sh -- a bus verb invoked with a missing argument REFUSES rc=2 with a
# USAGE MESSAGE, never with a bash diagnostic, and writes nothing.
# cto -> coo 2026-09-20, REPORTED rather than cured because the bus is the coo's instrument. MEASURED,
# verbatim from the cto's terminal on SCRIP d6b8a02c4 and reproduced before the cure: `s4e_msg.sh park` with
# no topic printed the unread banner and then `../harness/scripts/s4e_msg.sh: line 2067: 2: topic` and nothing else --
# `${2:?topic}` firing, i.e. the SHELL's unbound-parameter message, naming a LINE NUMBER and the bare word
# `topic` to a seat who was reaching for the board.
# ⛔ THE COST IS NOT THE MISSING HELP, IT IS WHAT IT READS AS: a line-numbered shell error reads as A BROKEN
# BUS rather than as a usage error, so the seat stops to investigate the tool instead of retyping the command,
# and a seat that cannot see the board picks its next row blind. TEN VERBS SHARED THE SHAPE, so it was never
# one verb's typo -- which is why this gate grades the POPULATION and not the one verb that was reported.
# FOUR ARMS over a scratch postoffice under mktemp -- never the live one:
#   (1) RC       every verb in the table exits 2 (could-not-act), never 0 and never 1. rc=2 is the vocabulary
#                every other refusal in this file speaks, so a caller can tell it from a measured red.
#   (2) USAGE    each refusal prints `usage:` AND names the verb the seat typed. A refusal that does not say
#                what to type instead is the bash diagnostic again in nicer words.
#   (3) NO-SHELL-DIAGNOSTIC  ⛔ THE ARM THAT GRADES THE ACTUAL DEFECT: the output must contain no `line N:`
#                and no `unbound variable`. This is what the cto saw, and it is the one property a
#                well-meaning usage message added ALONGSIDE the old expansion would still fail.
#   (4) WROTE-NOTHING  the whole scratch postoffice is byte-identical before and after every refusal. A
#                refusal that mutates is not a refusal, and this is the property nobody would notice breaking.
#   (5) NO-REGRESSION  no NEW `${N:?word}` site: the bare-word form is the defect's shape, and a gate that
#                only grades today's ten verbs cannot see the eleventh verb minted tomorrow.
# FAIL-ONCE: three mutants -- M1 restores `${2:?topic}` on park (arms 1 and 3 red), M2 makes the helper exit 1
# (arm 1 red), M3 makes it print no usage line (arm 2 red). EXIT 0 all arms hold and all three mutants go red;
# 1 otherwise; 2 REFUSED (fixture unbuildable).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="$HERE/s4e_msg.sh"
[ -f "$MSG" ] || { echo "⛔ REFUSED: $MSG missing"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED: mktemp failed"; exit 2; }
MAINPID=$$; trap '[ "$BASHPID" = "$MAINPID" ] && rm -rf "$W"' EXIT
PO="$W/po"; ME=ceo
FIX() { env -u S4E_PID_LOCK -u S4E_NO_DISPATCH_PROBE S4E_HOME="$W" S4E_POST="$PO" S4E_SEAT="$ME" \
        S4E_NO_BANNER=1 "$@"; }
mk_po() {
  rm -rf "$PO"; mkdir -p "$PO/tasks" "$PO/claims" "$PO/released" "$PO/$ME/inbox" || return 2
  : > "$PO/BOARD.md"; : > "$PO/QUEUE.done.tsv"; printf 'SEPTET\n' > "$PO/MODE"; printf '5\n' > "$PO/PROTOCOL-VERSION"
  printf '%s\n' ceo > "$PO/$ME/HQ"; printf '# gate fixture queue\n0\tt-row\tceo\tFREE\n' > "$PO/QUEUE.tsv"
  printf '# TASK t-row\nGOAL: fixture.\nDONE-WHEN: true\nLINKS: none\n## NEXT\ngo\n## LEDGER\n' > "$PO/tasks/t-row.task.md"; }
# ⛔ THE FINGERPRINT INCLUDES NAMES AND CONTENTS BOTH: a refusal that DELETED a file and one that added one
# would cancel in a count, and a checksum of contents alone cannot see a rename.
fingerprint() { find "$PO" -type f | sort | while IFS= read -r f; do printf '%s  ' "$f"; md5sum < "$f"; done | md5sum; }
arm() {   # arm <label> <script> -> 0 iff every contract holds on <script>
  local lbl="$1" s="$2" ok=1 out rc before after v
  mk_po || return 2
  before="$(fingerprint)"
  while IFS='|' read -r v; do
    [ -n "$v" ] || continue
    out="$(FIX bash "$s" $v 2>&1)"; rc=$?
    # (1) RC
    [ "$rc" = 2 ] || { echo "  [$lbl] (1) \`$v\` with no argument exited $rc, want 2 (could-not-act)"; ok=0; }
    # (2) USAGE
    grep -q 'usage:' <<<"$out" || { echo "  [$lbl] (2) \`$v\` refused without printing a usage line"; ok=0; }
    grep -q -- "$v" <<<"$out"  || { echo "  [$lbl] (2) \`$v\`'s refusal never names the verb the seat typed"; ok=0; }
    # (3) NO-SHELL-DIAGNOSTIC -- the defect itself
    grep -qE 'line [0-9]+:|unbound variable' <<<"$out" && { echo "  [$lbl] (3) \`$v\` died with a SHELL diagnostic, which reads as a broken bus: $(grep -m1 -E 'line [0-9]+:' <<<"$out" | cut -c1-70)"; ok=0; }
  done <<'VERBS'
park
claim
unclaim
done
mint
ask
mailbox
send
assign
reown
VERBS
  # (4) WROTE-NOTHING
  after="$(fingerprint)"
  [ "$before" = "$after" ] || { echo "  [$lbl] (4) the postoffice CHANGED across a run of refusals -- a refusal that mutates is not a refusal"; ok=0; }
  # (5) NO-REGRESSION: the bare-word `${N:?word}` shape, outside comments, is the defect's fingerprint.
  local reint
  reint="$(grep -nE '\$\{[0-9]:\?[^ }]*\}' "$s" | grep -v '^[0-9]*: *#' || true)"
  [ -z "$reint" ] || { echo "  [$lbl] (5) a bare-word \${N:?word} site is back -- that expansion prints a shell diagnostic, not a usage message:"; printf '%s\n' "$reint" | sed 's/^/        /' | cut -c1-110; ok=0; }
  [ "$ok" = 1 ]; }
echo "a bus verb with a missing argument refuses rc=2 with usage, not a shell diagnostic (scratch postoffice under $W)"
if arm PASS "$MSG"; then echo "  [PASS] 10 verbs · rc=2 · usage printed and verb named · no shell diagnostic · nothing written · no bare-word \${N:?} site"; pass=1
else pass=$?; [ "$pass" = 2 ] && { echo "⛔ REFUSED: fixture could not be built (rc=2)"; exit 2; }; pass=0; fi
mut() {  local n="$1" a="$2" b="$3"
  awk -v a="$a" -v b="$b" '$0==a{print b; k++; next} {print} END{exit !k}' "$MSG" > "$W/$n.sh" \
    || { echo "⛔ REFUSED: $n's anchor line is not where the mutant expects it -- the mutation would be a no-op"; exit 2; }
  grep -qF "$b" "$W/$n.sh" || { echo "⛔ REFUSED: $n did not change the file"; exit 2; }
  bash -n "$W/$n.sh" 2>/dev/null || { echo "⛔ REFUSED: the $n mutant does not parse -- fixture, not verdict"; exit 2; }; }
# ⛔ EXACT-STRING awk, never regex sed: a mutation that silently matched nothing would hand back an unmutated
# copy, the arm would pass, and the gate would report a fail-once it never performed.
mut m1 '         topic="$2"; st="${3:-PARKED}"; q="$PO/QUEUE.tsv"' '         topic="${2:?topic}"; st="${3:-PARKED}"; q="$PO/QUEUE.tsv"'
if arm M1-park-regressed "$W/m1.sh" >"$W/m1.log" 2>&1; then echo "  [FAIL-ONCE M1] ⛔ GREEN with park's original \${2:?topic} restored -- the gate cannot see the reported defect"; m1=0
else echo "  [FAIL-ONCE M1] red as required, park regressed: $(grep -m1 -E '\(1\)|\(3\)|\(5\)' "$W/m1.log" | sed 's/^ *//' | cut -c1-100)"; m1=1; fi
mut m2 '    exit 2; }' '    exit 1; }'
if arm M2-wrong-rc "$W/m2.sh" >"$W/m2.log" 2>&1; then echo "  [FAIL-ONCE M2] ⛔ GREEN with the refusal exiting 1 -- rc=1 is a measured red, which this is not"; m2=0
else echo "  [FAIL-ONCE M2] red as required, wrong rc: $(grep -m1 '(1)' "$W/m2.log" | sed 's/^ *//' | cut -c1-100)"; m2=1; fi
mut m3 "    printf '   usage: %s\\\\n' \"\$3\" >&2" '    :'
if arm M3-no-usage "$W/m3.sh" >"$W/m3.log" 2>&1; then echo "  [FAIL-ONCE M3] ⛔ GREEN with the usage line removed -- a refusal that does not say what to type is the diagnostic in nicer words"; m3=0
else echo "  [FAIL-ONCE M3] red as required, no usage line: $(grep -m1 '(2)' "$W/m3.log" | sed 's/^ *//' | cut -c1-100)"; m3=1; fi
if [ "$pass" = 1 ] && [ "$m1" = 1 ] && [ "$m2" = 1 ] && [ "$m3" = 1 ]; then
  echo "✅ GATE OK: every bus verb refuses a missing argument with rc=2 and a usage message, prints no shell diagnostic, and writes nothing."; exit 0; fi
echo "⛔ GATE FAILED (pass=$pass m1-red=$m1 m2-red=$m2 m3-red=$m3)"; exit 1
