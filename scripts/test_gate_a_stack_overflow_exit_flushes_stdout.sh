#!/usr/bin/env bash
# test_gate_a_stack_overflow_exit_flushes_stdout.sh -- hq_icon, 2026-10-01, MODE TENET (row icon-an-abandoned-suspended-
# generator-never-releases-its-activation-..., its second finding: "an error exit flushes stdout").
#
# WHAT WAS THERE. rt_stack_overflow.c's SIGSEGV handler names ERROR 246 and calls _exit(1), which skips stdio. Mode 3 never
# showed it -- scrip.c line-buffers stdout -- but a mode-4 binary writing to a file or pipe keeps stdout fully buffered, so
# the unflushed tail was lost: 49,637 of 50,000 lines on the parent 053ffb816 (the Expressions demo witness printed 0 of 291).
# The ordinary runtime-error exit (core_error_voice_at) flushes stdout before its message; the overflow exit now does the same.
#
# ARM. A program writes 50,000 lines, then recurses without bound. icont/iconx 9.5.25a must print the 50,000 and fail
# (a witness the oracle cannot run refuses the gate); SCRIP must print the oracle's stdout byte-for-byte, exit 1 and name
# ERROR 246, in both media.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle is missing"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/so.icn" <<'ICN'
procedure r(n); return r(n + 1); end
procedure main();
   local i;
   every i := 1 to 50000 do write(i);
   r(1);
end
ICN
( cd "$T" && "$ICONT" -s -o so.x so.icn ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: icont refuses the witness"; exit 2; }
( cd "$T" && ./so.x </dev/null > want 2>/dev/null ); wrc=$?
[ "$(wc -l < "$T/want")" -eq 50000 ] && [ "$wrc" -ne 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle did not print 50,000 lines and fail (rc $wrc)"; exit 2; }
( cd "$T" && timeout -k 5 120 "$SCRIP" so.icn </dev/null > m3 2> m3.err ); r3=$?
( cd "$T" && timeout -k 5 120 "$SCRIP" --compile -o so.s so.icn </dev/null >/dev/null 2>&1 && gcc -no-pie -o so.4 so.s -L"$ROOT/out" -lscrip_rt -lm -lstdc++ -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
  || { echo "⛔ GATE REFUSE(2) [$G]: mode-4 build of the witness failed -- cannot measure"; exit 2; }
( cd "$T" && timeout -k 5 120 ./so.4 </dev/null > m4 2> m4.err ); r4=$?
fail=0
for m in m3 m4; do rc=$([ $m = m3 ] && echo $r3 || echo $r4)
  if [ "$rc" -eq 1 ] && cmp -s "$T/$m" "$T/want" && grep -q 'ERROR 246' "$T/$m.err"; then echo "  $m PASS: 50000 lines byte-identical to iconx, rc 1, ERROR 246"
  else echo "  $m FAIL: rc $rc, $(wc -l < "$T/$m") of 50000 lines, stderr: $(head -1 "$T/$m.err" | cut -c1-80)"; fail=1; fi
done
[ $fail = 0 ] && { echo "✅ GATE PASS [$G]: a stack-overflow exit flushes stdout in both media"; exit 0; }
echo "⛔ GATE FAIL [$G]"; exit 1
