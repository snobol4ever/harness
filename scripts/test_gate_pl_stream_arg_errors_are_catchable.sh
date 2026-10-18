#!/usr/bin/env bash
# test_gate_pl_stream_arg_errors_are_catchable.sh -- row prolog-write-2-on-an-unregistered-stream-alias-
# dies-rc1-with-no-ball-instead-of-throwing-existence-error (cto -> hq_R, 2026-09-13).
#
# ⛔ WHAT THIS GUARDS. A stream-or-alias argument has five distinct wrong answers and ISO/IEC 13211-1
# sec 7.10.2.x gives each its own error term. Before this gate, write/2 on an unregistered alias EXITED
# rc=1 with no output, no ball and no message -- the catch never ran. A guard that DIES instead of
# THROWING turns a missing feature into a silent crash inside the program under test, and it scores
# differently from a throw, so it also corrupts the denominator of every suite that probes an alias.
#
# ⛔ THE SIBLINGS ARE THE POINT, NOT write/2. Ten sinks share the one resolver; a per-sink fix that leaves
# the siblings dying is half a cure (cto). Every sink below is graded in BOTH modes.
#
# rc 0 green · 1 red · 2 could not measure.  Self-contained; run from anywhere.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
[ -f "$ROOT/out/libscrip_rt.so" ] || { echo "⛔ REFUSE(2): no out/libscrip_rt.so -- m4 cannot link"; exit 2; }
D=$(mktemp -d) || { echo "⛔ REFUSE(2): no tmpdir"; exit 2; }
trap 'rm -rf "$D"' EXIT
PASS=0; FAIL=0; N=0
# name | goal | expected single line of output
run_case() {
  local nm="$1" goal="$2" want="$3" got rc
  N=$((N+1))
  cat > "$D/c.pl" <<PLEOF
:- initialization(main).
main :- catch(($goal), error(E, _), (write(caught(E)), nl)), write(alive), nl, halt.
PLEOF
  got=$(timeout -k 5 20 "$SCRIP" "$D/c.pl" 2>/dev/null); rc=$?
  if [ "$got" != "$want" ]; then printf '  m3 RED  %-16s rc=%s got [%s] want [%s]\n' "$nm" "$rc" "$got" "$want"; FAIL=$((FAIL+1)); else PASS=$((PASS+1)); fi
  N=$((N+1))
  if ! timeout -k 5 60 "$SCRIP" --compile -o "$D/c.s" "$D/c.pl" >/dev/null 2>&1; then printf '  m4 RED  %-16s compile failed\n' "$nm"; FAIL=$((FAIL+1)); return; fi
  if ! gcc -m64 -no-pie "$D/c.s" -o "$D/c.bin" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm >/dev/null 2>&1; then printf '  m4 RED  %-16s link failed\n' "$nm"; FAIL=$((FAIL+1)); return; fi
  got=$(timeout -k 5 20 "$D/c.bin" 2>/dev/null); rc=$?
  if [ "$got" != "$want" ]; then printf '  m4 RED  %-16s rc=%s got [%s] want [%s]\n' "$nm" "$rc" "$got" "$want"; FAIL=$((FAIL+1)); else PASS=$((PASS+1)); fi
}
EX='caught(existence_error(stream,st_o))
alive'
echo "=== the ten sinks that share the stream-or-alias resolver: an unknown alias THROWS, it does not die ==="
run_case write_2          'write(st_o, x)'            "$EX"
run_case writeq_2         'writeq(st_o, x)'           "$EX"
run_case write_canonical_2 'write_canonical(st_o, x)' "$EX"
run_case nl_1             'nl(st_o)'                  "$EX"
run_case tab_2            'tab(st_o, 2)'              "$EX"
run_case put_char_2       'put_char(st_o, a)'         "$EX"
run_case write_term_3     'write_term(st_o, x, [])'   "$EX"
run_case format_3         'format(st_o, "x", [])'     "$EX"
run_case read_2           'read(st_o, _X)'            "$EX"
run_case flush_output_1   'flush_output(st_o)'        "$EX"
echo "=== the other four answers of the same resolver, each its own ISO error term ==="
run_case unbound          'write(_S, x)'              'caught(instantiation_error)
alive'
run_case not_a_stream     'write(3, x)'               'caught(domain_error(stream_or_alias,3))
alive'
run_case wrong_direction  'current_input(S), write(S, x)' 'caught(permission_error(output,stream,$stream(0)))
alive'
run_case read_from_output 'current_output(S), read(S, _X)' 'caught(permission_error(input,stream,$stream(1)))
alive'
echo "=== and the control arm: a write by stream HANDLE is untouched ==="
cat > "$D/h.pl" <<PLEOF
:- initialization(main).
main :- open('$D/h.txt', write, S), write(S, hi), nl(S), close(S),
        open('$D/h.txt', read, R), get_char(R, C), close(R), write(handle_ok(C)), nl, halt.
PLEOF
N=$((N+1))
got=$(timeout -k 5 20 "$SCRIP" "$D/h.pl" 2>/dev/null)
if [ "$got" = "handle_ok(h)" ]; then PASS=$((PASS+1)); else printf '  m3 RED  %-16s got [%s] want [handle_ok(h)]\n' handle "$got"; FAIL=$((FAIL+1)); fi
[ "$N" -gt 0 ] || { echo "⛔ REFUSE(2): graded nothing"; exit 2; }
echo "PL STREAM-ARG ERRORS: PASS=$PASS FAIL=$FAIL / $N arms (m3+m4)  verdict=$([ $FAIL = 0 ] && echo GREEN || echo RED)"
[ "$FAIL" = 0 ] || exit 1
exit 0
