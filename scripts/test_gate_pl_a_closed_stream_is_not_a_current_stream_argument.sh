#!/usr/bin/env bash
# test_gate_pl_a_closed_stream_is_not_a_current_stream_argument.sh -- current_output/1 AND current_input/1 GIVEN A CLOSED STREAM, OR A NON-STREAM, RAISE domain_error(stream, S) (ISO 8.11.1.3, 8.11.2.3).
# hq_prolog 2026-09-25, CEO-1270; the cure is by_name_dispatch.c rt_pl_dop_curstream_guard_c, which accepted ANY '$stream'(K) term and now
# requires its handle to be live. NO MONITOR BRACKET: an error expectation, and the oracles do not agree with each other -- gprolog quietly FAILS
# and swipl raises existence_error -- so the witness is the standard as the Logtalk suite states it (sics_current_output_1_04, sics_current_input_1_04).
# RED BEFORE on origin: both closed-stream lines printed nothing (the goal failed), m3 AND m4.
set -u
GATE_NAME=test_gate_pl_a_closed_stream_is_not_a_current_stream_argument
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/w.pl" <<'EOP'
main :- open('cs.txt', write, S), close(S),
        catch((current_output(S), write(succeeded)), error(E, _), (E = domain_error(stream, _) -> write(domain_error) ; write(E))), nl,
        open('cs.txt', read, S2), close(S2),
        catch((current_input(S2), write(succeeded)), error(E2, _), (E2 = domain_error(stream, _) -> write(domain_error) ; write(E2))), nl,
        catch((current_output(foo), write(succeeded)), error(E3, _), write(E3)), nl,
        current_output(O), ( current_output(O) -> write(live_ok) ; write(live_no) ), nl.
:- initialization(main).
EOP
want='domain_error
domain_error
domain_error(stream,foo)
live_ok'
red=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 20 "$SCRIP" w.pl </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 60 "$SCRIP" --compile --out="$TMPD/w.s" "$TMPD/w.pl" </dev/null 2>"$TMPD/err" || refuse "m4 compile failed: $(head -c 160 "$TMPD/err")"
        gcc -m64 -no-pie "$TMPD/w.s" -o "$TMPD/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "m4 link failed: $(head -c 160 "$TMPD/err")"
        got="$(cd "$TMPD" && timeout -k 5 20 ./w.bin </dev/null 2>"$TMPD/err")"; rc=$?
        rm -f "$TMPD/w.s" "$TMPD/w.bin"
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $mode"
    else echo "  RED $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-200)] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red mode(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: a closed stream and a non-stream raise domain_error(stream, S), the live current output still answers, both modes"
exit 0
