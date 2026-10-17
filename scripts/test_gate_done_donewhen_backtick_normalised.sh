#!/usr/bin/env bash
# ⛔⭐ NEGATIVE-ARM GATE: a markdown-backtick-wrapped DONE-WHEN must RUN, not be executed as command substitution.
# DEFECT (seat06, 2026-08-28, FINDING be4b2257): task files are MARKDOWN, so criteria get authored as `DONE-WHEN: `cmd``.
# `bash -c "$dw"` then runs cmd, captures its stdout, and EXECUTES THAT STDOUT -- a gate printing "GATE OK ..." dies
# `GATE: command not found` rc=127 and the row cannot be closed. 5 of 411 live task files carried a wrapped criterion.
# ⛔ REFUSES rc=2 when it cannot measure. Drives the REAL done path in a scratch world -- not a helper in isolation.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; msg="$here/s4e_msg.sh"
[ -f "$msg" ] || { echo "⛔ REFUSE rc=2: s4e_msg.sh not found beside this gate" >&2; exit 2; }
tmp="$(mktemp -d)" || { echo "⛔ REFUSE rc=2: cannot mktemp" >&2; exit 2; }
trap 'rm -rf "$tmp"' EXIT
ROOT="$tmp/root"; PO="$tmp/po"; SEAT=seat01
mkdir -p "$ROOT/harness/scripts" "$PO/claims" "$PO/tasks" "$PO/$SEAT/inbox" || { echo "⛔ REFUSE rc=2: scratch setup failed" >&2; exit 2; }
printf 'FLEET-12\n' > "$PO/MODE"; : > "$ROOT/marker"
# a criterion that EXAMINES the tree (fails in an empty dir, so it survives done's vacuity probe) and PRINTS on success
PASSY='test -f ./marker && echo "GATE OK -- marker present"'
FAILY='test -f ./nosuch && echo "GATE OK -- marker present"'
mkrow(){ printf '0\t%s\tunassigned\tFREE\n' "$1" >> "$PO/QUEUE.tsv"; }
mktask(){ printf '# TASK %s\nDONE-WHEN: %s\n' "$1" "$2" > "$PO/tasks/$1.task.md"; }
mkclaim(){ printf '%s\nRUNNING\n' "$SEAT" > "$PO/claims/$1.claim"; }
run(){ S4E_HOME="$ROOT" S4E_POST="$PO" S4E_SEAT="$SEAT" S4E_NO_BANNER=1 bash "$msg" done "$1" >"$tmp/out" 2>"$tmp/err"; echo $?; }
fail=0; note(){ printf '%-58s %s\n' "$1" "$2"; }
# ARM 1 -- backtick-WRAPPED, prints on success: must CLOSE (this is the reported rc=127 defect)
mkrow w; mktask w "\`$PASSY\`"; mkclaim w; rc="$(run w)"
if [ "$rc" = 0 ]; then note "ARM1 wrapped + prints on success" "CLOSES rc=0 ✅"; else note "ARM1 wrapped + prints on success" "⛔ rc=$rc (want 0; 127 = unfixed)"; sed -n '1,3p' "$tmp/err" >&2; fail=1; fi
grep -q 'markdown backticks' "$tmp/err" && note "ARM1b strip is ANNOUNCED, not silent" "✅" || { note "ARM1b strip is ANNOUNCED, not silent" "⛔ silent"; fail=1; }
# ARM 2 -- ⭐ THE ONE THAT MATTERS: a wrapped criterion that should FAIL must still FAIL. Stripping must not false-green.
mkrow f; mktask f "\`$FAILY\`"; mkclaim f; rc="$(run f)"
if [ "$rc" != 0 ]; then note "ARM2 wrapped + genuinely failing" "STILL FAILS rc=$rc ✅"; else note "ARM2 wrapped + genuinely failing" "⛔ rc=0 -- FALSE GREEN introduced by the strip"; fail=1; fi
grep -q '^DONE$' "$PO/claims/f.claim" && { note "ARM2 side-effect" "⛔ DONE appended on a failing criterion"; fail=1; }
# ARM 3 -- UNWRAPPED criterion: unaffected
mkrow p; mktask p "$PASSY"; mkclaim p; rc="$(run p)"
if [ "$rc" = 0 ]; then note "ARM3 unwrapped (control)" "UNAFFECTED rc=0 ✅"; else note "ARM3 unwrapped (control)" "⛔ rc=$rc -- the strip broke ordinary criteria"; fail=1; fi
grep -q 'markdown backticks' "$tmp/err" && { note "ARM3b unwrapped must NOT announce" "⛔ over-fired"; fail=1; } || note "ARM3b unwrapped must NOT announce" "✅"
# ARM 4 -- ONE-SIDED backtick must NOT be stripped: a lone ` is real substitution or a typo; it must fail loudly
mkrow o; mktask o "\`$PASSY"; mkclaim o; rc="$(run o)"
if [ "$rc" != 0 ]; then note "ARM4 one-sided backtick not stripped" "FAILS LOUDLY rc=$rc ✅"; else note "ARM4 one-sided backtick not stripped" "⛔ rc=0 -- silently rewrote a malformed criterion"; fail=1; fi
[ "$fail" = 0 ] && { echo "GATE OK -- wrapped criteria run, failing ones still fail, unwrapped untouched, one-sided refused"; exit 0; }
echo "⛔ GATE FAILED"; exit 1
