#!/usr/bin/env bash
# test_gate_pl_pipe_2_and_open_null_stream_1_answer_as_swipl.sh -- pipe/2 and open_null_stream/1 answer as swipl 10 does, in both modes
# (rows prolog-swi-builtin-pipe-2-... and prolog-swi-builtin-open-null-stream-1-... agrees-with-swipl-in-both-modes-ceo-1753, minted
# by hq_prolog 2026-10-14 on the ceo's CEO-1753 ruling: both are thread-free builtins of the SWI superset, SWI core/test_answer.pl
# died on existence_error(procedure, pipe/2) in nine of its fourteen cases).
# WHAT IS GRADED: pipe/2 yields a read stream and a write stream joined by the kernel (bytes written and flushed or closed read back
# in order, end_of_file after the writer closes, is_stream/1, stream_property mode(read) and mode(write), existence_error(stream, _)
# writing to a closed end); open_null_stream/1 yields a write stream that discards its bytes (write/nl/format/put_char succeed,
# is_stream/1, mode(write), output, flush_output/1, existence_error(stream, _) after close/1).
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: the two expectation tables below were cut 2026-10-14 from /usr/bin/swipl by
# absolute path, and every run re-cuts both from the live swipl and REFUSES rc=2 when the oracle and the table disagree or swipl is
# absent. No program prints a stream handle (swipl prints <stream>(0x...) addresses that differ per run).
# FAIL-ONCE: on the parent both programs raised existence_error(procedure, pipe/2) and (procedure, open_null_stream/1) in m3 and m4.
# Usage: bash ../harness/scripts/test_gate_pl_pipe_2_and_open_null_stream_1_answer_as_swipl.sh
set -uo pipefail
GATE_NAME=test_gate_pl_pipe_2_and_open_null_stream_1_answer_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/pipe.pl" <<'PL'
:- initialization(main).
main :-
    pipe(In, Out),
    write(Out, hello), nl(Out), flush_output(Out),
    get_code(In, A), get_code(In, B), get_code(In, C), get_code(In, D), get_code(In, E), get_code(In, F),
    write([A,B,C,D,E,F]), nl,
    write(Out, xy), close(Out),
    get_code(In, G), get_code(In, H), get_code(In, I),
    write([G,H,I]), nl,
    close(In),
    pipe(I2, O2),
    ( is_stream(I2), is_stream(O2) -> write(both_streams) ; write(not_streams) ), nl,
    ( stream_property(I2, mode(M1)) -> write(M1) ; write(nomode) ), nl,
    ( stream_property(O2, mode(M2)) -> write(M2) ; write(nomode) ), nl,
    close(O2), close(I2),
    catch(write(O2, x), error(Err, _), true),
    ( nonvar(Err) -> Err =.. [Fn|_], write(Fn) ; write(no_error) ), nl,
    halt.
PL
cat > "$d/pipe.want" <<'WANT'
[104,101,108,108,111,10]
[120,121,-1]
both_streams
read
write
existence_error
WANT
cat > "$d/null.pl" <<'PL'
:- initialization(main).
main :-
    open_null_stream(S),
    write(S, hello), nl(S),
    format(S, "~w~n", [x]),
    put_char(S, a),
    ( is_stream(S) -> write(is_stream) ; write(not_stream) ), nl,
    ( stream_property(S, mode(M)) -> write(M) ; write(nomode) ), nl,
    ( stream_property(S, output) -> write(output) ; write(not_output) ), nl,
    flush_output(S),
    close(S),
    catch(write(S, y), error(Err, _), true),
    ( nonvar(Err) -> Err =.. [Fn|_], write(Fn) ; write(no_error) ), nl,
    halt.
PL
cat > "$d/null.want" <<'WANT'
is_stream
write
output
existence_error
WANT
fails=0; graded=0
for w in pipe null; do
    "$SWIPL" -q -g main -t halt "$d/$w.pl" </dev/null > "$d/$w.oracle" 2>/dev/null
    cmp -s "$d/$w.want" "$d/$w.oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the $w expectation table is not what $SWIPL prints now"; diff "$d/$w.want" "$d/$w.oracle" | head -5; exit 2; }
    timeout -k 5 20 "$SCRIP" "$d/$w.pl" </dev/null 2>/dev/null > "$d/$w.m3"; rc=$?; graded=$((graded + 1))
    if [ $rc -ne 0 ] || ! cmp -s "$d/$w.want" "$d/$w.m3"; then fails=$((fails + 1)); echo "  $w m3 rc=$rc differs:"; diff "$d/$w.want" "$d/$w.m3" | head -10; fi
    graded=$((graded + 1))
    if timeout -k 5 60 "$SCRIP" --compile -o "$d/$w.s" "$d/$w.pl" </dev/null >/dev/null 2>&1 && as --64 -o "$d/$w.o" "$d/$w.s" 2>/dev/null \
        && gcc -no-pie -o "$d/$w.bin" "$d/$w.o" "$OUT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$OUT" 2>/dev/null; then
        timeout -k 5 20 "$d/$w.bin" </dev/null 2>/dev/null > "$d/$w.m4"; rc=$?
        if [ $rc -ne 0 ] || ! cmp -s "$d/$w.want" "$d/$w.m4"; then fails=$((fails + 1)); echo "  $w m4 rc=$rc differs:"; diff "$d/$w.want" "$d/$w.m4" | head -10; fi
    else fails=$((fails + 1)); echo "  $w m4 did not compile or link"; fi
done
echo "PLPIPENULL_BOARD programs=2 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
