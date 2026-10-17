#!/usr/bin/env bash
# ⛔⭐⭐ NEGATIVE-ARM GATE for the ROWD-CLOSE guard in s4e_msg.sh (row done-must-hand-off-manifest-cited-rows, CEO-69 batch 5a + CEO-70).
# THE DEFECT IT PINS: closing a row cited as ROWD evidence in corpus_coverage_manifest.tsv reds `make test` for EVERY seat
# until the manifest is re-pointed by hand. THREE identical fleet-wide reds in one day before the guard existed.
# ⛔ THIS GATE DRIVES THE REAL `done` PATH end-to-end in a scratch world (S4E_HOME/S4E_POST/S4E_SEAT are all overridable) --
# it does NOT test a helper in isolation. A guard proven only through its own helper is not proven through the path that ships.
# ⛔ REFUSES rc=2 when it cannot measure. A test that cannot fail is indistinguishable from one that passed.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; msg="$here/s4e_msg.sh"
[ -f "$msg" ] || { echo "⛔ REFUSE rc=2: s4e_msg.sh not found beside this gate ($msg)" >&2; exit 2; }
grep -q 's4e_manifest_rowd_cite' "$msg" || { echo "⛔ REFUSE rc=2: s4e_msg.sh carries no ROWD guard -- nothing to grade" >&2; exit 2; }
tmp="$(mktemp -d)" || { echo "⛔ REFUSE rc=2: cannot mktemp" >&2; exit 2; }
trap 'rm -rf "$tmp"' EXIT
ROOT="$tmp/root"; PO="$tmp/po"; SEAT=seat01
mkdir -p "$ROOT/harness/scripts" "$PO/claims" "$PO/tasks" "$PO/$SEAT/inbox" || { echo "⛔ REFUSE rc=2: scratch setup failed" >&2; exit 2; }
printf 'FLEET-12\n' > "$PO/MODE"
man="$ROOT/harness/scripts/corpus_coverage_manifest.tsv"
mkrow(){ printf '0\t%s\tunassigned\tFREE\n' "$1" >> "$PO/QUEUE.tsv"; }
mkclaim(){ printf '%s\nRUNNING\n' "$SEAT" > "$PO/claims/$1.claim"; }
mktask(){ printf '# TASK %s\nDONE-WHEN: test -f "%s"\n' "$1" "$man" > "$PO/tasks/$1.task.md"; }
arm(){ S4E_HOME="$ROOT" S4E_POST="$PO" S4E_SEAT="$SEAT" S4E_NO_BANNER=1 bash "$msg" done "$1" >"$tmp/out" 2>"$tmp/err"; echo $?; }
printf '# manifest\nSUBTREE\tbenchmarks/pascal\tROWD\tcited-topic\n' > "$man"
for t in cited-topic other-topic successor-topic; do mkrow "$t"; mktask "$t"; done
fail=0; note(){ printf '%-58s %s\n' "$1" "$2"; }
# ARM 1 -- cited topic, COMPUTED close: must REFUSE rc=1
mkclaim cited-topic; rc="$(arm cited-topic)"
if [ "$rc" = 1 ] && grep -q 'ROWD evidence' "$tmp/err"; then note "ARM1 cited + computed close" "REFUSES rc=1 ✅"; else note "ARM1 cited + computed close" "⛔ rc=$rc (want 1 + ROWD message)"; fail=1; fi
# ARM 1b -- the refusal must NAME the pull-before-close requirement (ceo required it IN the text)
if grep -q 'pull --rebase' "$tmp/err"; then note "ARM1b refusal names pull-before-close" "✅"; else note "ARM1b refusal names pull-before-close" "⛔ absent"; fail=1; fi
# ARM 2 -- cited topic, OVERRIDE close: must STILL refuse (guard sits above the done/OVERRIDE fork)
mkclaim cited-topic; rc="$(S4E_DONE_OVERRIDE='test override' arm cited-topic)"
if [ "$rc" = 1 ]; then note "ARM2 cited + S4E_DONE_OVERRIDE" "REFUSES rc=1 ✅"; else note "ARM2 cited + S4E_DONE_OVERRIDE" "⛔ rc=$rc -- override bypassed the guard"; fail=1; fi
grep -q '^DONE$' "$PO/claims/cited-topic.claim" && { note "ARM2 side-effect" "⛔ DONE was appended despite refusal"; fail=1; }
# ARM 3 -- manifest HANDED OFF to a live successor: the same close must now PASS
printf '# manifest\nSUBTREE\tbenchmarks/pascal\tROWD\tsuccessor-topic\n' > "$man"
mkclaim cited-topic; rc="$(S4E_DONE_OVERRIDE='test override' arm cited-topic)"
if [ "$rc" = 0 ]; then note "ARM3 cited-after-handoff" "PASSES rc=0 ✅"; else note "ARM3 cited-after-handoff" "⛔ rc=$rc (want 0) -- guard does not clear on handoff"; sed -n '1,4p' "$tmp/err" >&2; fail=1; fi
# ARM 4 -- a topic the manifest never cites: unaffected
mkclaim other-topic; rc="$(S4E_DONE_OVERRIDE='test override' arm other-topic)"
if [ "$rc" = 0 ]; then note "ARM4 uncited close" "UNAFFECTED rc=0 ✅"; else note "ARM4 uncited close" "⛔ rc=$rc (want 0) -- guard over-fires"; sed -n '1,4p' "$tmp/err" >&2; fail=1; fi
if [ "$fail" = 0 ]; then echo "GATE OK -- ROWD-close guard: refuses cited (computed AND override), clears on handoff, ignores uncited"; exit 0; fi
echo "⛔ GATE FAILED"; exit 1
