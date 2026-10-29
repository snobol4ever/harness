#!/usr/bin/env bash
# test_gate_pl_gnu_get_print_stream_inside_portray_answers_as_gprolog.sh -- get_print_stream/1 EXISTS, AND A portray/1 HOOK WRITES TO A STREAM THAT CARRIES THE PRINT TARGET'S ALIAS
# (cfo 2026-10-15, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/print_driver).
#
# get_print_stream(S) is GNU Prolog's way for a portray/1 hook to learn the stream print/1,2 is writing to; SCRIP raised existence_error for it.
# It is now current_output/1 behind gprolog's stream check (an unbound or valid stream, or an alias in use; anything else domain_error(stream, X)).
# For that to answer as gprolog, the stream a portray hook sees as current output -- a scratch stream that keeps the term's text in order -- carries the
# alias of the stream print was writing to (plc_portray_hit gives its scratch handle that alias, and reuses the target's own handle when the writer's FILE
# is a registered stream), so stream_property(S, alias(user_output)) holds inside the hook as it does in gprolog and swipl.
#
# THE ARM: one program, nine lines, the reference cut from gprolog 1.4.5 (2026-10-15), mode 3 and mode 4.
# FAIL-ONCE, measured on the parent rebuilt: the BipsPl/print_driver diff was 7 lines (existence_error for get_print_stream/1 on every portray that used it).
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_get_print_stream_inside_portray_answers_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- initialization(main).
o(G) :- write('<'), catch(( G -> R = true ; R = fail ), E, ( E = error(F, _) -> R = error(F) ; R = ball(E) )), write('> '), writeq(R), nl.
portray(secret(_)) :- get_print_stream(S), write(S, '**hidden**').
portray(where) :- get_print_stream(S), ( stream_property(S, alias(user_output)) -> write(S, user_output) ; write(S, other) ).
main :- o(print([secret(1), open, secret(2)])), o(print(g(secret(x), where))), o(print(where)), o(print(user_output, secret(1))),
  o(print(user_output, f('$VAR'(25), where))),
  o((get_print_stream(S), stream_property(S, alias(user_output)))),
  o(get_print_stream(foo)), o(get_print_stream(3)), o((get_print_stream(S2), get_print_stream(S2))).
PL
want="$(cat <<'WANT'
<[**hidden**,open,**hidden**]> true
<g(**hidden**,user_output)> true
<user_output> true
<**hidden**> true
<f(Z,user_output)> true
<> true
<> error(domain_error(stream,foo))
<> error(domain_error(stream,3))
<> true
WANT
)"
m4ok=1
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 9 of 9 lines as gprolog"
    else echo "  $label RED: $n of 9 gprolog lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 20 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
