#!/usr/bin/env bash
# test_gate_pl_a_library_reaching_with_output_to_pulls_its_stream_sink_road.sh -- A PROGRAM THAT REACHES with_output_to/2 ONLY THROUGH
# A LIBRARY GETS THE PRELUDE PREDICATES ITS LOWERING CALLS (cfo 2026-10-14, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-
# defines-and-scrip-lacks: the GNU atom, const_io and pretty drivers regressed to existence_error('$wot_stream_sink'/1)).
#
# 6e8bfadaf (with_output_to/2 takes a stream as its sink) lowers every with_output_to/2 call through '$wot_stream_sink'/1 and
# '$wot_stream'/2, and the prelude injector (prolog_parse.c) added the two when the PROGRAM names with_output_to -- not when only a
# selected library's body does, as gnu_builtins' write_to_atom/2, writeq_to_atom/2, print_to_atom/2 and format_to_atom/3 do. So a GNU
# program calling write_to_atom/2 raised existence_error('$wot_stream_sink'/1): the drivers read 23 -> 22 of 45 (atom_driver,
# const_io_driver, pretty_driver). The cure adds the two wherever the closure meets a with_output_to call, as it already does for
# current_predicate ('$cp_mq') and erase ('$rec_ref', '$rec_erase').
#
# THE ARM: one program, four lines, the reference cut from gprolog 1.6.0 (the pristine oracle, 2026-10-14) and written out here, mode
# 3 and mode 4. FAIL-ONCE, measured on the parent d231c3680 rebuilt: no line in both modes (the directive raises
# existence_error('$wot_stream_sink'/1)); with the cure 4 of 4 in both modes.
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_a_library_reaching_with_output_to_pulls_its_stream_sink_road
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- initialization(main).
main :- write_to_atom(A, f(x, 'Y z')), write(A), nl, writeq_to_atom(B, f(x, 'Y z')), write(B), nl,
    format_to_atom(C, '~w-~a', [g(1), b]), write(C), nl, print_to_atom(D, [1,2]), write(D), nl.
PL
want="f(x,Y z)
f(x,'Y z')
g(1)-b
[1,2]"
m4ok=1
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s w.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 4 of 4 lines as gprolog"
    else echo "  $label RED: $n of 4 gprolog lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 20 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
