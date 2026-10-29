#!/usr/bin/env bash
# test_gate_pl_stream_property_sees_the_standard_streams_before_any_file_operation.sh -- the FIRST
# stream_property/2 of a program, asked before any open, read or write has touched the file-handle table,
# must still find user_input and its properties (the coo's bisect 2026-09-30: Logtalk stream_property_2
# read 58/72 from 9d3f8a061 on, cases 08a..13; FIRST BAD the cto's one-show batch 2d-1).
#
# THE REGRESSION THIS PINS, AND IT WAS MINE. 9d3f8a061 turned g_fh[64] into a grown vector whose three
# standard slots are made by fh_ensure_init on first use. The g_fh accessor initialized; the FH_N length
# macro did not, so a leaf that bounded its index by FH_N before touching g_fh (pl_sp_count, pl_sp_nth,
# pl_sp_check) read a length of 0 and the enumeration had no streams at all. The first
# stream_property(S, alias(user_input)) failed; every later one, after some write had initialized the
# table, answered. FH_N now initializes exactly as g_fh does (driver_private.h).
#
# ⛔ The witness asks its first stream_property BEFORE writing anything: a write first would initialize the
# table and the gate would read green on the broken binary. The lines are the ones swipl 9 and gprolog 1.4.5
# agree on (they disagree on user_input's eof_action, so that property is not graded here; the Logtalk suite
# grades it as ISO states it).
# rc 0 green · 1 red · 2 could not measure.
set -uo pipefail
GATE_NAME=test_gate_pl_stream_property_sees_the_standard_streams_before_any_file_operation
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no scrip at $SCRIP -- a missing binary prints a plausible all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$ROOT/out}/libscrip_rt.so" || exit 2
D=$(mktemp -d) || { echo "⛔ REFUSE(2) [$GATE_NAME]: no tmpdir"; exit 2; }
trap 'rm -rf "$D"' EXIT
PASS=0; FAIL=0; N=0
cat > "$D/sp.pl" <<'PLEOF'
:- initialization(main).
main :- ( stream_property(S, alias(user_input)), stream_property(S, mode(M)) -> R1 = M ; R1 = none ),
	( stream_property(T, alias(user_input)), stream_property(T, input) -> R2 = input ; R2 = none ),
	( stream_property(U, alias(user_input)), stream_property(U, type(Y)) -> R3 = Y ; R3 = none ),
	write(R1), nl, write(R2), nl, write(R3), nl, halt.
PLEOF
want='read
input
text'
for mode in m3 m4; do
    N=$((N+1))
    if [ "$mode" = m3 ]; then got=$(cd "$D" && timeout -k 5 20 "$SCRIP" "$D/sp.pl" </dev/null 2>&1)
    else
        if (cd "$D" && timeout -k 5 60 "$SCRIP" --compile --out="$D/sp.s" "$D/sp.pl" </dev/null >/dev/null 2>&1) \
           && gcc -m64 "$D/sp.s" -o "$D/sp.bin" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm >/dev/null 2>&1; then
            got=$(cd "$D" && timeout -k 5 20 "$D/sp.bin" </dev/null 2>&1)
        else echo "  RED  $mode: the witness failed to compile or link"; FAIL=$((FAIL+1)); continue; fi
    fi
    if [ "$got" = "$want" ]; then PASS=$((PASS+1))
    else printf '  RED  %s: got\n%s\n       want\n%s\n' "$mode" "$got" "$want"; FAIL=$((FAIL+1)); fi
done
[ "$N" -gt 0 ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: graded ZERO witnesses"; exit 2; }
echo "PL STREAM PROPERTY BEFORE ANY FILE OP: PASS=$PASS FAIL=$FAIL / $N arms graded (m3+m4)"
[ "$FAIL" -eq 0 ] && { echo "verdict=GREEN -- the first stream_property of a program finds user_input and its mode, input and type"; exit 0; }
echo "verdict=RED"; exit 1
