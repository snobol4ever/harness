#!/usr/bin/env bash
# test_gate_pl_a_binary_stream_has_no_encoding_property.sh -- stream_property/2 must have NO SOLUTION for
# encoding/1 on a stream opened with type(binary), while a TEXT stream still reports the encoding it was
# opened with (row prolog-logtalk-stream-io-family-..., hq_R 2026-09-13, on the coo's board-pass regression
# report of builtins:lgt_unicode_stream_property_2_07 and _09).
#
# THE REGRESSION THIS PINS, AND IT WAS MINE. 94fde5d43 taught open/4 to accept encoding(E) and
# stream_property/2 to report it -- 15 Logtalk unicode cases that had been UNGRADABLE became graded -- and it
# made fh_encoding answer `octet` for a binary stream so a declared name could not win over the type. Two
# cases do not ask WHICH encoding a binary stream reports: they assert `\+ stream_property(S, encoding(_))`,
# so ANY answer satisfies the inner goal and the negation fails. The sibling pair on bom/1 kept passing,
# which is what made the shape specific and findable.
#
# ⛔⭐ THE CRITERION IS THE SUITE'S OWN EXPECTATION AND IT AGREES WITH NEITHER ORACLE -- measured 2026-09-13,
# and this arm exists so nobody "fixes" it back: on type(binary), swipl 9.0.4 answers encoding(octet), so
# SWIPL ITSELF WOULD FAIL those two cases, and gprolog raises domain_error(stream_property, encoding(_))
# because encoding is not a stream property for it at all. ISO/IEC 13211-1 7.10.2.13 lists ten properties and
# encoding is not among them; Logtalk's own comment above the cases says a binary stream should have no bom/1
# or encoding/1. So this is a DELIBERATE divergence from swipl, decided by the standard-derived suite rather
# than by an oracle diff -- and ARM 4 prints both oracles' answers on every run rather than hiding them,
# because an undocumented divergence is what gets "corrected" by the next reader with a swipl prompt open.
#
# ⛔ ARM 2 IS THE ARM THAT STOPS THE OVER-BROAD CURE. Deleting the encoding property outright passes ARM 1
# perfectly and silently un-grades the 15 cases 94fde5d43 unblocked. A cure that trades one case for another
# never lands (CEO-589), so the text-stream arm is graded beside the binary one, always.
# rc 0 green · 1 red · 2 could not measure.
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_oracle_flags.sh"
GATE_NAME=test_gate_pl_a_binary_stream_has_no_encoding_property
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no scrip at $SCRIP -- a missing binary prints a plausible all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$ROOT/out}/libscrip_rt.so" || exit 2
D=$(mktemp -d) || { echo "⛔ REFUSE(2) [$GATE_NAME]: no tmpdir"; exit 2; }
trap 'rm -rf "$D"' EXIT
PASS=0; FAIL=0; N=0
cat > "$D/sp.pl" <<'PLEOF'
:- initialization(main).
main :- open('b.bin', write, B, [type(binary)]),
	( stream_property(B, encoding(E1)) -> write(bin_encoding(E1)) ; write(bin_no_encoding) ), nl,
	( stream_property(B, type(T1)) -> write(bin_type(T1)) ; write(bin_no_type) ), nl,
	close(B),
	open('t.txt', write, S, [type(text), encoding(utf8)]),
	( stream_property(S, encoding(E2)) -> write(txt_encoding(E2)) ; write(txt_no_encoding) ), nl,
	( stream_property(S, type(T2)) -> write(txt_type(T2)) ; write(txt_no_type) ), nl,
	close(S),
	open('p.txt', write, P, []),
	( stream_property(P, encoding(E3)) -> write(plain_encoding(E3)) ; write(plain_no_encoding) ), nl,
	close(P), halt.
PLEOF
# ⛔⭐ THE SPELLING PIN WAS REVISED ON PURPOSE, 2026-09-13 (hq_R, row prolog-logtalk-eleven-unicode-stream-
# cases-...). This gate pinned `utf8` and the engine now answers `UTF-8`, so this gate WENT RED on the cure
# and was updated KNOWINGLY rather than discovered afterwards -- which is the whole reason the pin is here.
# WHAT DID NOT CHANGE IS THE INVARIANT THIS GATE IS NAMED FOR: bin_no_encoding is still the first line, and
# ARM 2's text-stream arm still grades beside it. Only the ATOM changed, and the reason is in driver_globals.c
# above fh_encoding: ISO/IEC 13211-1 does not define encoding/1 at all, so there is no standard name to
# defer to, and the logtalk_iso suite -- the instrument that decides this engine's conformance -- writes the
# IANA name 'UTF-8' in all 81 places it names an encoding and `utf8` in none. `encoding(utf8)` is still an
# ACCEPTED INPUT on open/4 (this witness passes it and still opens), which is the distinction that matters:
# the input vocabulary stayed wide, the reported value became single.
want='bin_no_encoding
bin_type(binary)
txt_encoding(UTF-8)
txt_type(text)
plain_encoding(UTF-8)'
for mode in m3 m4; do
    N=$((N+1))
    if [ "$mode" = m3 ]; then got=$(cd "$D" && timeout -k 5 20 "$SCRIP" "$D/sp.pl" </dev/null 2>&1)
    else
        if (cd "$D" && timeout -k 5 60 "$SCRIP" --compile -o "$D/sp.s" "$D/sp.pl" >/dev/null 2>&1) \
           && gcc -m64 -no-pie "$D/sp.s" -o "$D/sp.bin" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm >/dev/null 2>&1; then
            got=$(cd "$D" && timeout -k 5 20 "$D/sp.bin" 2>&1)
        else echo "  RED  $mode: the witness failed to compile or link"; FAIL=$((FAIL+1)); continue; fi
    fi
    if [ "$got" = "$want" ]; then PASS=$((PASS+1))
    else printf '  RED  %s: got\n%s\n       want\n%s\n' "$mode" "$got" "$want"; FAIL=$((FAIL+1)); fi
done
# ---- ARM 4: THE ORACLES' OWN ANSWERS, PRINTED AND NEVER GRADED. They disagree with the suite and with each
# other, and the record of that is what stops this being "corrected" back into a regression.
cat > "$D/orc.pl" <<'PLEOF'
:- initialization(main).
main :- open('ob.bin', write, B, [type(binary)]),
	( stream_property(B, encoding(E)) -> format("oracle_says=~w~n", [E]) ; write('oracle_says=no_solution'), nl ),
	close(B), halt.
PLEOF
sw="unavailable"; gp="unavailable"
command -v swipl >/dev/null 2>&1 && sw=$(cd "$D" && timeout -k 5 20 swipl -q -g halt "$D/orc.pl" 2>&1 | tr '\n' ' ')
gprolog_bin >/dev/null 2>&1 && gp=$(cd "$D" && timeout -k 5 20 "$(gprolog_bin)" --consult-file "$D/orc.pl" </dev/null 2>&1 | grep -o 'oracle_says=[a-z_]*\|domain_error(stream_property[^)]*)' | head -1)
echo "    NOT GRADED, printed so the divergence cannot be mistaken for a defect: swipl [$sw] · gprolog [${gp:-domain_error(stream_property,encoding(_))}] · this engine: NO SOLUTION, which is the suite's expectation and ISO 7.10.2.13's property list"
[ "$N" -gt 0 ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: graded ZERO witnesses"; exit 2; }
echo "PL BINARY STREAM ENCODING: PASS=$PASS FAIL=$FAIL / $N arms graded (m3+m4; binary has no encoding, text keeps the one it declared)"
[ "$FAIL" -eq 0 ] && { echo "verdict=GREEN -- a binary stream has no encoding property, a text stream still reports the encoding it was opened with, and both type properties are intact"; exit 0; }
echo "verdict=RED"; exit 1
