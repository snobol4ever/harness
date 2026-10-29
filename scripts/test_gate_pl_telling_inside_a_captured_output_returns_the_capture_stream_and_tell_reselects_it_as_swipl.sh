#!/usr/bin/env bash
# test_gate_pl_telling_inside_a_captured_output_returns_the_capture_stream_and_tell_reselects_it_as_swipl.sh -- telling/1 answers the CURRENT OUTPUT STREAM when output is captured, and tell/1 and see/1 take that stream
# back (hq_packages 2026-10-29, xsb_tests prolog_tests_altindex: `telling(X), compile(...), consult(...), tell(X), writeln(...)` run inside the driver's with_output_to capture). SCRIP answered `user`, so tell(X) put
# the output back on standard output and the program's lines escaped the capture (and the driver's sort): the ref's `1 2 Compiling finished Test results` read `Compiling finished Test results 1 2`.
# THE REF IS swipl'S OWN OUTPUT (the oracle of the SWI dialect), cut when the gate was written and re-cut on every run: swipl that no longer prints it REFUSES rc 2.
# ARMS: (1) ORACLE: swipl prints the carried ref  (2) m3 and (3) m4: SCRIP prints it byte for byte  (4) CAN FAIL: a ref with one changed line reads red
# RED BEFORE (measured 2026-10-29 on SCRIP 94c591de2, the working-tree change reverted and rebuilt): m3 and m4 printed kind(user) and lost `inside2` from the capture.
# rc 0 all arms; rc 1 an arm red; rc 2 could not measure.
set -u
GATE_NAME=test_gate_pl_telling_inside_a_captured_output_returns_the_capture_stream_and_tell_reselects_it_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh is missing"
SWI="$(swipl_bin)" || refuse "the swipl accessor refused"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/w.pl" <<'PL'
:- use_module(library(lists)).
t1 :- telling(X), writeln(inside1), tell(X), writeln(inside2).
t2 :- telling(Y), ( Y == user -> write(user) ; write(stream) ).
t3 :- telling(X), tell(X), write(a), tell(X), write(b).
main :- with_output_to(string(S), t1), write(captured(S)), nl,
        with_output_to(string(S3), t2), write(kind(S3)), nl,
        with_output_to(string(S4), t3), write(retold(S4)), nl,
        telling(Z), write(outside(Z)), nl, writeln(after).
:- initialization((main, halt)).
PL
cat > "$T/ref" <<'REF'
captured(inside1
inside2
)
kind(stream)
retold(ab)
outside(user)
after
REF
total=0; red=0
verdict() { total=$((total+1)); if cmp -s "$2" "$3"; then echo "  ok  $1"; else echo "  RED $1: first differing line: $(diff "$3" "$2" | grep -m1 '^[<>]' | cut -c1-120)"; red=$((red+1)); fi; }
( cd "$T" && timeout -k 5 60 "$SWI" -q w.pl < /dev/null > swi.out 2>/dev/null )
cmp -s "$T/swi.out" "$T/ref" || { diff "$T/ref" "$T/swi.out" | head -4; refuse "swipl no longer prints the carried ref -- re-cut it from the oracle, never from SCRIP"; }
verdict "swipl prints the carried ref" "$T/swi.out" "$T/ref"
( cd "$T" && timeout -k 5 20 "$SCRIP" w.pl < /dev/null > m3.out 2> m3.err ); verdict "SCRIP m3 answers as swipl" "$T/m3.out" "$T/ref"
if ( cd "$T" && "$SCRIP" --compile --out=w.s w.pl < /dev/null > /dev/null 2> m4.cerr ) && gcc -m64 -no-pie "$T/w.s" -o "$T/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> "$T/m4.lerr"; then
    ( cd "$T" && timeout -k 5 20 ./w.bin < /dev/null > m4.out 2> m4.err ); verdict "SCRIP m4 answers as swipl" "$T/m4.out" "$T/ref"
else total=$((total+1)); red=$((red+1)); echo "  RED SCRIP m4 did not compile or link: $(head -c 200 "$T/m4.cerr" "$T/m4.lerr" 2>/dev/null)"; fi
sed '1s/.*/not what swipl prints/' "$T/ref" > "$T/ref_corrupt"; total=$((total+1))
if cmp -s "$T/swi.out" "$T/ref_corrupt"; then echo "  RED CAN FAIL: a corrupted ref read equal to swipl's output"; red=$((red+1)); else echo "  ok  CAN FAIL: a ref with one changed line reads red"; fi
echo "$GATE_NAME: arms=$total red=$red"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
