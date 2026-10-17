#!/usr/bin/env bash
# test_gate_pl_set_stream_position_round_trips_and_refuses.sh -- set_stream_position/2 must REPOSITION a
# stream to a position stream_property/2 handed out, and must raise each of its four ISO sec 8.11.9 errors
# rather than failing silently (row prolog-logtalk-eleven-unicode-stream-cases-routed-from-the-builtins-
# family-row, hq_R 2026-09-13).
#
# WHAT WAS WRONG. set_stream_position/2 was NAMED in src/lower/pl_control_names.h and lowered by nothing, so
# every call threw existence_error(procedure, set_stream_position/2) -- and there was no position/1 stream
# property to obtain a position from in the first place, so the predicate could not have been called
# correctly even once. Both halves were missing and each hid the other: a seat probing the property saw it
# fail and a seat probing the predicate saw it not exist, and neither reads as "this feature is absent".
#
# ⛔⭐ THE POSITION TERM IS DELIBERATELY OPAQUE AND THAT IS THE STANDARD'S OWN CHOICE. ISO/IEC 13211-1
# 7.10.2.13 makes a stream position an IMPLEMENTATION-DEFINED term, and 8.11.9 requires only that
# set_stream_position/2 accept one previously obtained from the same stream. So this gate grades the
# ROUND TRIP -- read a term, read past it, reposition, read the SAME term again -- and never the shape of
# the term. Measured before choosing: every use of a position in this repo's vendored Prolog suites is
# opaque (obtain it, hand it back); NOTHING inspects its arguments. A gate that pinned the arity would be
# pinning a decision the standard explicitly leaves open.
#
# ⛔ THE FOUR ERROR ARMS ARE WHY THIS IS NOT A ONE-ARM GATE. The cheapest cure that passes the round-trip
# arm is an fseek with no argument checking, and it turns every one of these four into a silent success or
# a silent failure. reposition(false) is the one worth naming: a stream that WAS given a position property
# and then refuses to be repositioned looks like a broken fseek unless the permission_error is explicit.
# rc 0 green · 1 red · 2 could not measure.
set -uo pipefail
GATE_NAME=test_gate_pl_set_stream_position_round_trips_and_refuses
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no scrip at $SCRIP -- a missing binary prints a plausible all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$ROOT/out}/libscrip_rt.so" || exit 2
[ -f "$ROOT/out/libscrip_rt.so" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no out/libscrip_rt.so -- m4 cannot link"; exit 2; }
D=$(mktemp -d) || { echo "⛔ REFUSE(2) [$GATE_NAME]: no tmpdir"; exit 2; }
trap 'rm -rf "$D"' EXIT
PASS=0; FAIL=0; N=0
printf 'alpha(1).\nbeta(2).\ngamma(3).\n' > "$D/terms.pl"
cat > "$D/sp.pl" <<'PLEOF'
:- initialization(main).
p(N, G) :- ( catch(G, E, (write(N-ball(E)), nl)) -> true ; write(N-failed), nl ).
main :-
	p(binary_roundtrip, ( open('terms.pl', read, S1, [type(binary), reposition(true)]),
		stream_property(S1, position(P1)), get_byte(S1, B1), get_byte(S1, _),
		set_stream_position(S1, P1), get_byte(S1, B3), write(same(B1 == B3)), nl, close(S1) )),
	p(instantiation, ( open('terms.pl', read, S2, [reposition(true)]), set_stream_position(S2, _) )),
	p(domain, ( open('terms.pl', read, S3, [reposition(true)]), set_stream_position(S3, foo) )),
	p(permission, ( open('terms.pl', read, S4, [reposition(false)]),
		stream_property(S4, position(P4)), set_stream_position(S4, P4) )),
	p(no_such_stream, set_stream_position(no_such_alias, foo)),
	halt.
PLEOF
want='same(97==97)
instantiation-ball(error(instantiation_error,_G0))
domain-ball(error(domain_error(stream_position,foo),_G0))
permission-ball(error(permission_error(reposition,stream,$stream(N)),_G0))
no_such_stream-ball(error(existence_error(stream,no_such_alias),_G0))'
for mode in m3 m4; do
    N=$((N+1))
    if [ "$mode" = m3 ]; then got=$(cd "$D" && timeout -k 5 20 "$SCRIP" "$D/sp.pl" </dev/null 2>&1)
    else
        if (cd "$D" && timeout -k 5 60 "$SCRIP" --compile -o "$D/sp.s" "$D/sp.pl" >/dev/null 2>&1) \
           && gcc -m64 -no-pie "$D/sp.s" -o "$D/sp.bin" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm >/dev/null 2>&1; then
            got=$(cd "$D" && timeout -k 5 20 "$D/sp.bin" 2>&1)
        else echo "  RED  $mode: the witness failed to compile or link"; FAIL=$((FAIL+1)); continue; fi
    fi
    # ⛔ TWO THINGS ARE NORMALISED AND NEITHER IS THE BEHAVIOUR. A fresh variable's printed name (_G0 vs
    # _G17) is the writer's counter, and the file-handle NUMBER inside $stream(N) is whichever slot the
    # table happened to hand out -- pinning either would make this gate fail on a change that is not about
    # repositioning at all. The ball's SHAPE, its kind, and all four error terms are graded exactly.
    gotn=$(printf '%s\n' "$got" | sed 's/_G[0-9]*/_GN/g; s/\$stream([0-9]*)/$stream(N)/g')
    wantn=$(printf '%s\n' "$want" | sed 's/_G[0-9]*/_GN/g; s/\$stream([0-9]*)/$stream(N)/g')
    if [ "$gotn" = "$wantn" ]; then PASS=$((PASS+1))
    else printf '  RED  %s: got\n%s\n       want\n%s\n' "$mode" "$got" "$want"; FAIL=$((FAIL+1)); fi
done
[ "$N" -gt 0 ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: graded ZERO witnesses"; exit 2; }
echo "PL SET_STREAM_POSITION: PASS=$PASS FAIL=$FAIL / $N arms graded (m3+m4; one round trip and four ISO error terms per arm)"
[ "$FAIL" -eq 0 ] && { echo "verdict=GREEN -- a position round-trips on a repositionable stream, and instantiation, domain, permission and existence each raise their own ISO error"; exit 0; }
echo "verdict=RED"; exit 1
