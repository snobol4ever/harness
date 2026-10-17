#!/usr/bin/env bash
# test_gate_pl_a_write_to_a_binary_current_output_raises_permission_error.sh -- EVERY TERM WRITER ON A BINARY CURRENT OUTPUT RAISES
# permission_error(output, binary_stream, S) (ISO 8.14.2.3, 8.14.3.3; hq_prolog 2026-09-25, CEO-1266/1270; the cure is lower_prolog.c's
# pl_curout_writer/pl_curout_text_guard: write/1, writeq/1, print/1, write_canonical/1, write_term/2, writeln/1, format/1 and format/2 run the
# $pl_ioarg text-stream pre-check nl/0 and the put_* forms already ran).
# THE DEFECT. The stream-argument forms raised; the current-output forms wrote their text into the binary stream and succeeded -- a plausible
# success where ISO wants an error. Logtalk write_term_3 sics_022 ({write(a)} after set_binary_output) was red on it.
# ARMS: fourteen forms -- ten called directly, four through call/1 (a meta-call reaches the same lowering through its compiled wrapper) -- each
# read as perm(output,binary_stream); both modes. THE EXPECTATIONS ARE gprolog's (2026-09-25): all fourteen raise.
# RED BEFORE on origin eea1ddd0d, m3 AND m4: w1 q1 p1 c1 t2 f1 and the meta-called w1 q1 f1 read ok.
set -u
GATE_NAME=test_gate_pl_a_write_to_a_binary_current_output_raises_permission_error
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/wb.pl" <<'EOP'
:- initialization(main).
t(N, G) :- open('wb.bin', write, S, [type(binary)]), current_output(O), set_output(S),
    catch((call(G, S), R = ok), E, R = E), set_output(O), close(S),
    ( R = error(permission_error(A, B, _), _) -> write(N-perm(A, B)) ; write(N-R) ), nl.
w1(_) :- write(a).         w2(S) :- write(S, a).        q1(_) :- writeq(a).          p1(_) :- print(a).
c1(_) :- write_canonical(a). t2(_) :- write_term(a, []). t3(S) :- write_term(S, a, []). n1(S) :- nl(S).
f1(_) :- format("x", []).  f2(S) :- format(S, "x", []).
m(G, _) :- call(G).
main :- t(w1, w1), t(w2, w2), t(q1, q1), t(p1, p1), t(c1, c1), t(t2, t2), t(t3, t3), t(n1, n1), t(f1, f1), t(f2, f2),
        t(mw1, m(write(a))), t(mq1, m(writeq(a))), t(mn0, m(nl)), t(mf1, m(format("x", []))).
EOP
want="$(for n in w1 w2 q1 p1 c1 t2 t3 n1 f1 f2 mw1 mq1 mn0 mf1; do echo "$n-perm(output,binary_stream)"; done)"
red=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 20 "$SCRIP" wb.pl </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 60 "$SCRIP" --compile -o "$TMPD/wb.s" "$TMPD/wb.pl" </dev/null 2>"$TMPD/err" || refuse "m4 compile failed: $(head -c 160 "$TMPD/err")"
        gcc -m64 -no-pie "$TMPD/wb.s" -o "$TMPD/wb.bin4" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "m4 link failed: $(head -c 160 "$TMPD/err")"
        got="$(cd "$TMPD" && timeout -k 5 20 ./wb.bin4 </dev/null 2>"$TMPD/err")"; rc=$?
        rm -f "$TMPD/wb.s" "$TMPD/wb.bin4"
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $mode (14 forms)"
    else echo "  RED $mode: rc=$rc wrong: $(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep '^>' | tr '\n' ' ' | cut -c1-200)"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red mode(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: every term writer on a binary current output raises permission_error, direct and meta-called, both modes as gprolog"
exit 0
