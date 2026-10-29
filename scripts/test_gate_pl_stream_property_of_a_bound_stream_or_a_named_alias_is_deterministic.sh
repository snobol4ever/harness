#!/usr/bin/env bash
# test_gate_pl_stream_property_of_a_bound_stream_or_a_named_alias_is_deterministic.sh -- stream_property/2 LEAVES NO CHOICE POINT WHEN ITS ANSWER IS UNIQUE, AS swipl
# (cfo 2026-10-15, row prolog-swi-library-test-pio-every-case-agrees-with-swipl-in-both-modes-ceo-1664; the cause measured by the cto, 2026-10-15).
#
# lower_prolog.c lowered stream_property/2 to the gen2 over $pl_sp_count and $pl_sp_nth, which walks every stream x property slot, so even
# stream_property(S, position(P)) with S bound left a choice point after its one answer. swipl is deterministic whenever the stream and the property are
# both bound, and for alias(Atom) with the stream unbound (an alias names one stream). library(pure_input)'s stream_to_lazy_list/3 calls
# stream_property(S, position(Pos)) inside its attribute hook, and the stray choice point there is what kept twelve SWI library/test_pio.pl cases red
# (phrase_from_file over a lazy list) after the cto's young-binding cure (9d31f8ee0). The lowering now commits to the first solution in those two shapes
# and keeps the generator otherwise (stream_property(S, P) with P unbound stays nondeterministic).
#
# THE ARM: one program (an SWI marker), fifteen lines, the reference cut from swipl 9.0.4 (2026-10-15), mode 3 and mode 4; each line is a property and
# whether call_cleanup/2 saw the goal exit deterministically.
# FAIL-ONCE, measured on the parent rebuilt (SCRIP 3eb9e62e0): 12 of the 15 lines differ in both modes (every det line reads nondet).
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_stream_property_of_a_bound_stream_or_a_named_alias_is_deterministic
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/s.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
d(P, G) :- copy_term(G, G1), call_cleanup(G1, D = det), ( var(D) -> R = nondet ; R = D ), !, \+ \+ ( numbervars(P, 0, _), writeq(P-R) ), nl.
d(P, _) :- \+ \+ ( numbervars(P, 0, _), writeq(P-fail) ), nl.
main :- open('sp.txt', write, S), set_stream(S, alias(aa)),
  forall(member(P, [position(_), alias(_), file_name(_), mode(_), output, eof_action(_), reposition(_), type(_), encoding(_), buffer(_), input, mode(read)]), d(P, stream_property(S, P))),
  d(user_output, stream_property(user_output, alias(_))), d(any, stream_property(S, _)), d(unbound_stream, stream_property(_, alias(aa))), close(S).
PL
want="$(cat <<'WANT'
position(A)-det
alias(A)-det
file_name(A)-det
mode(A)-det
output-det
eof_action(A)-det
reposition(A)-det
type(A)-det
encoding(A)-det
buffer(A)-det
input-fail
mode(read)-fail
user_output-det
any-nondet
unbound_stream-det
WANT
)"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && rm -f sp.txt && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 15 of 15 lines as swipl"
    else echo "  $label RED: $n of 15 swipl lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run s.pl < /dev/null
if ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=s.s s.pl < /dev/null > /dev/null 2>&1 && [ -s s.s ] \
     && gcc -m64 -no-pie s.s -o s.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ); then
    arm m4 timeout -k 5 20 ./s.bin < /dev/null
else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
