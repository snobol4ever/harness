#!/usr/bin/env bash
# test_gate_postoffice_identity.sh -- NEGATIVE-INJECTION GATE for fleet-v2 preflight V2-3 + V2-4 (hq_P, s258).
# ⛔ LAW 0 (ARCH-FLEET-CEO.md): no instrument backs a DONE-WHEN until negative-injection proves it can say NO.
# Every check below was RUN AGAINST THE PRE-PATCH SCRIPT FIRST and observed to FAIL -- that is what makes a
# later green meaningful. The whole gate runs inside a THROWAWAY postoffice ($S4E_POST) so it can never touch
# /home/resources/postoffice; identity is forced with $S4E_SEAT so no test depends on which root it runs in.
set -u
# ⛔ THE BINARY UNDER TEST MUST BE OVERRIDABLE, AND THIS GATE SHIPPED WITHOUT THAT (caught by hq_C's
# cross-verification, s258, in the intended direction). The path was hardcoded to $(dirname $0)/s4e_msg.sh,
# so when hq_C tried to aim the gate at the PRE-PATCH script to confirm my "15 of 18 fail" claim, the
# injection SILENTLY DID NOTHING and the gate reported a confident 18/18 over the wrong binary. ⭐ That is
# the exact class this gate exists to hunt -- an instrument that cannot say NO because it is not looking at
# the thing you think it is (LAW 0, species 3) -- shipped inside the instrument itself. A gate whose subject
# cannot be redirected can only ever confirm the tree it sits in.
S="${S4E_MSG_BIN:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/s4e_msg.sh}"
[ -f "$S" ] || { echo "⛔ no script under test at $S (set S4E_MSG_BIN)" >&2; exit 2; }
printf '  subject: %s\n' "$S"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
no()   { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
newpo(){ rm -rf "$T/po"; mkdir -p "$T/po"/{ceo,hq_C,hq_P,seat01,seat08}/inbox "$T/po/claims"; : > "$T/po/BOARD.md"; : > "$T/po/QUEUE.tsv"; }
run()  { S4E_POST="$T/po" S4E_HOME="$T/root" S4E_SEAT="$1" bash "$S" "${@:2}" 2>&1; }
rc()   { S4E_POST="$T/po" S4E_HOME="$T/root" S4E_SEAT="$1" bash "$S" "${@:2}" >/dev/null 2>&1; echo $?; }
mkdir -p "$T/root/harness/scripts"
printf '%s\n' '#!/bin/sh' 'echo HANDOFF COMPLETE' 'exit 0' > "$T/root/harness/scripts/handoff_status.sh"
echo "== V2-4 identity is asserted, never globbed =="
newpo
# 1. an identity with NO mailbox must FAIL LOUDLY -- this is the phantom-claude01 class at its root.
out="$(run nosuchseat check)"; r=$(rc nosuchseat check)
{ [ "$r" -ne 0 ] && printf '%s' "$out" | grep -qi 'no postoffice mailbox'; } \
  && ok "unknown identity refused (rc=$r)" || no "unknown identity refused" "rc=$r out=${out:0:90}"
# 2. and it must NOT have created the mailbox as a side effect (how phantom claude01 was born).
[ ! -d "$T/po/nosuchseat" ] && ok "refused identity created no mailbox" || no "refused identity created no mailbox" "$T/po/nosuchseat exists"
# 3. sending to a non-existent mailbox must FAIL, not silently mkdir one.
out="$(run seat01 send ghostseat topic "hello")"; r=$(rc seat01 send ghostseat topic "hello")
{ [ "$r" -ne 0 ] && [ ! -d "$T/po/ghostseat" ]; } && ok "send to unknown mailbox refused, none created (rc=$r)" \
  || no "send to unknown mailbox refused" "rc=$r dir=$([ -d "$T/po/ghostseat" ] && echo created || echo absent)"
# 4. legacy unpadded / claude-spelled ids CANONICALISE onto the real mailbox instead of forking a phantom.
run seat01 send seat8 canon "body" >/dev/null 2>&1
n=$(ls "$T/po/seat08/inbox" 2>/dev/null | wc -l)
{ [ "$n" -eq 1 ] && [ ! -d "$T/po/seat8" ]; } && ok "seat8 canonicalises to seat08" || no "seat8 canonicalises to seat08" "seat08 inbox=$n"
newpo
out="$(run claude01 check)"
printf '%s' "$out" | grep -q '^\[seat01\]' && ok "identity claude01 canonicalises to seat01" || no "identity claude01 canonicalises to seat01" "${out:0:70}"
# 5. /home/claude resolves to ceo, not the retiring hq (Lon s257 topology ruling).
# ⛔ `env -u S4E_SEAT` IS LOAD-BEARING, NOT TIDINESS. This is the ONE check here that derives identity from
# the ROOT PATH rather than being handed one, so an ambient exported S4E_SEAT silently overrides the very
# mapping it exists to test. Every other invocation goes through run()/rc(), which set S4E_SEAT explicitly
# and are immune. MEASURED 2026-09-03: green with the variable unset, green with S4E_HOME exported alone,
# and RED ("FAIL /home/claude resolves to ceo", identity read back as hq_B) the moment S4E_SEAT is exported
# -- which is exactly the environment `done` runs a DONE-WHEN in, and this gate is a component of
# test_gate_dispatch_bus_failure_modes, now an arm of `make test` for all sixteen seats. A seat whose shell
# exports its own identity would have gotten a red make test for a reason having nothing to do with its work.
# ⭐ This is the defect s4e_msg.sh's own `done` comment names: a verdict that depends on the grader's
# environment is not a verdict, and it is invisible from both sides -- it passed 5/5 for me at rest.
out="$(env -u S4E_SEAT S4E_POST="$T/po" S4E_HOME=/home/claude bash "$S" check 2>&1)"
printf '%s' "$out" | grep -q '^\[ceo\]' && ok "/home/claude resolves to ceo" || no "/home/claude resolves to ceo" "${out:0:70}"
out="$(env -u S4E_SEAT S4E_POST="$T/po" S4E_HOME=/home/claude_ceo bash "$S" check 2>&1)"
printf '%s' "$out" | grep -q '^\[ceo\]' && ok "/home/claude_ceo resolves to ceo (the root renamed 2026-09-06)" || no "/home/claude_ceo resolves to ceo" "${out:0:70}"
mkdir -p "$T/po/cto/inbox"
out="$(env -u S4E_SEAT S4E_POST="$T/po" S4E_HOME=/home/claude_cto bash "$S" check 2>&1)"
printf '%s' "$out" | grep -q '^\[cto\]' && ok "/home/claude_cto resolves to cto (the CTO seat, 2026-09-06)" || no "/home/claude_cto resolves to cto" "${out:0:70}"
mkdir -p "$T/po/coo/inbox"
out="$(env -u S4E_SEAT S4E_POST="$T/po" S4E_HOME=/home/claude_coo bash "$S" check 2>&1)"
printf '%s' "$out" | grep -q '^\[coo\]' && ok "/home/claude_coo resolves to coo (the COO seat, 2026-09-06)" || no "/home/claude_coo resolves to coo" "${out:0:70}"
# 6. mailbox creation exists but is DELIBERATE, never a side effect.
r=$(rc hq_P mailbox seat99); [ "$r" -eq 0 ] && [ -d "$T/po/seat99/inbox" ] && ok "explicit 'mailbox' subcommand creates one" || no "explicit 'mailbox' subcommand" "rc=$r"
echo "== V2-4 orphaned .msg.* sweep =="
newpo
printf 'FROM seat01 TO seat08 RE stray-topic\nbody text\n' > "$T/po/.msg.ZZtest"
out="$(run hq_P check)"
n=$(ls "$T/po/seat08/inbox" 2>/dev/null | wc -l)
{ [ "$n" -eq 1 ] && [ ! -f "$T/po/.msg.ZZtest" ]; } && ok "orphaned .msg.* re-delivered by check" || no "orphaned .msg.* re-delivered" "seat08 inbox=$n stray=$([ -f "$T/po/.msg.ZZtest" ] && echo left || echo gone)"
newpo
printf 'FROM seat01 TO ghost RE t\nbody\n' > "$T/po/.msg.ZZbad"
out="$(run hq_P check)"
{ [ -f "$T/po/.msg.ZZbad" ] && printf '%s' "$out" | grep -qi 'orphan'; } && ok "undeliverable orphan is REPORTED, not dropped" || no "undeliverable orphan reported" "${out:0:90}"
echo "== V2-4 census enumerates mailboxes, not /home/claude* globs =="
newpo
out="$(run hq_P fleet)"
for m in ceo hq_C hq_P seat01; do printf '%s' "$out" | grep -q "  $m " && ok "fleet sees $m" || no "fleet sees $m" "absent from census"; done
echo "== V2-3 HQ banner refuses the tick on a stale inbox =="
newpo
printf 'FROM seat01 TO hq_P RE q-something\nquestion\n' > "$T/po/hq_P/inbox/1-seat01-q-something.msg"
touch -d '2 minutes ago' "$T/po/hq_P/inbox/1-seat01-q-something.msg"
# ⛔⭐ READ THE VERDICT FROM BOARD.md, NOT FROM STDOUT (hq_B 2026-09-13). Lon ordered the printed banner
# deleted entire (hq_S, SCRIP c902a4b73: "I want the entire text gone. Not just the header."), so the verdict
# box no longer reaches stdout. These two arms grepped stdout, and BOTH broke in the deletion -- but they broke
# in OPPOSITE directions, and only one of them was visible:
#   the stale arm went RED, which is how it was found;
#   the fresh arm went VACUOUSLY GREEN. It asserts the ABSENCE of a string, and nothing prints that string any
#   more, so it now passes for a banner that has no verdict at all -- it could never fail again.
# ⛔ THAT IS THE DANGEROUS HALF AND IT WAS SILENT. A red announces itself; an assertion that has quietly
# become unfalsifiable does not, and it goes on being counted in "21 passed" forever.
# ⭐ THE PROPERTY IS NOT RETIRED, ONLY ITS CHANNEL MOVED. What matters here was never that the banner PRINTS
# a refusal -- it is that an HQ sitting on stale mail is not awarded a ✅. hq_S's cut deleted the DISPLAY and
# deliberately kept the COMPUTE: the verdict is still computed and still written to BOARD.md, which is what
# `fleet` renders and what Lon reads. So these arms read it there, and they can fail again.
_verdict() { grep -m1 "^$1 |" "$T/po/BOARD.md" 2>/dev/null; }
run hq_P banner >/dev/null 2>&1
v="$(_verdict hq_P)"
[ -n "$v" ] || no "banner wrote a BOARD.md verdict at all" "BOARD.md has no hq_P line -- the arms below cannot measure"
printf '%s' "$v" | grep -q '⛔ DRAIN FIRST' && no "fresh mail does not trip the refusal" "tripped at 2 min" || ok "fresh mail (2 min) does not trip the refusal"
touch -d '90 minutes ago' "$T/po/hq_P/inbox/1-seat01-q-something.msg"
run hq_P banner >/dev/null 2>&1
v="$(_verdict hq_P)"
{ printf '%s' "$v" | grep -q '⛔ DRAIN FIRST' && ! printf '%s' "$v" | grep -q '✅ SUCCESS'; } \
  && ok "stale mail (90 min) refuses the HQ ✅ and replaces the headline" || no "stale mail refuses the HQ ✅" "${v:0:140}"
# a SEAT is not an HQ: the drain law binds HQ only, so a seat with old mail keeps its own verdict.
newpo
printf 'FROM hq_P TO seat01 RE x\nbody\n' > "$T/po/seat01/inbox/1-hq_P-x.msg"; touch -d '90 minutes ago' "$T/po/seat01/inbox/1-hq_P-x.msg"
out="$(run seat01 banner)"
printf '%s' "$out" | grep -q '⛔ DRAIN FIRST' && no "seat banner unaffected by drain law" "seat refused" || ok "seat banner unaffected by drain law"
echo "== V2-3 board line carries oldest-unanswered age and the row topic =="
newpo
printf 'FROM seat01 TO hq_P RE q-x\nq\n' > "$T/po/hq_P/inbox/1-seat01-q-x.msg"; touch -d '45 minutes ago' "$T/po/hq_P/inbox/1-seat01-q-x.msg"
echo hq_P > "$T/po/claims/perf-roman-8x.claim"
run hq_P banner >/dev/null 2>&1
bl="$(cat "$T/po/BOARD.md")"
printf '%s' "$bl" | grep -qE 'mail [0-9]+/4[0-9]m' && ok "board line carries oldest-unanswered age" || no "board line carries oldest-unanswered age" "${bl:0:120}"
printf '%s' "$bl" | grep -q 'perf-roman-8x' && ok "board line names the row topic" || no "board line names the row topic" "${bl:0:120}"
printf '\n  %s passed, %s failed\n\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
