#!/usr/bin/env bash
# test_gate_pl_gnu_linedit_prompt_and_completion_answer_as_gprolog.sh -- GNU Prolog's LINE-EDITOR INTERFACE get_linedit_prompt/1, set_linedit_prompt/1,
# add_linedit_completion/1 AND find_linedit_completion/2 EXIST AND ANSWER AS gprolog (cfo 2026-10-15, row
# prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/le_interf_driver).
#
# The four were absent from SCRIP. gnu_builtins.pl now keeps them as gprolog's le_interf_c.c and Linedit/completion.c do: the prompt is an atom, '' at
# start; add_linedit_completion/1 takes a non-empty atom of letters, digits and _ only (else fails); find_linedit_completion/2 enumerates, in strcmp order,
# every word with the prefix in gprolog's completion set -- the added words AND every atom the program knows of length over 1 made of letters, digits and
# _ (gprolog adds those as it creates them; SCRIP reads its atom table through the '$gnu_os' op compl, sized by a first counting pass). Argument checks:
# a variable is an instantiation_error, a non-atom type_error(atom, X), the prefix before the completion. The prefix test uses code lists, because
# atom_concat(+, -, +) interns every prefix of its third argument and would put words in the set that the program never made.
#
# THE ARM: one program (no SWI marker), 27 lines, the reference cut from gprolog 1.6.0 (2026-10-15), mode 3 and mode 4; every word starts qzv/Qzv.
# FAIL-ONCE, measured on the parent (SCRIP 49d16141f rebuilt): 27 of 27 lines differ in both modes.
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~8 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_linedit_prompt_and_completion_answer_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \+ \+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl ).
k(qzvfour).
main :- t(get_linedit_prompt(_)), t(set_linedit_prompt('qzv> ')), t(get_linedit_prompt(_)), t(get_linedit_prompt(x)), t(set_linedit_prompt(_)), t(set_linedit_prompt(1)), t(get_linedit_prompt(1)),
  t(set_linedit_prompt('')), t(get_linedit_prompt(_)),
  t(add_linedit_completion(qzvone)), t(add_linedit_completion('QzvTwo')), t(add_linedit_completion('qzv3')), t(add_linedit_completion('qzv x')), t(add_linedit_completion('qzv-y')),
  t(add_linedit_completion('')), t(add_linedit_completion(_)), t(add_linedit_completion(f(x))), t(add_linedit_completion(qzvone)),
  t(find_linedit_completion(qzv, _)), t(find_linedit_completion('Qzv', _)), t(find_linedit_completion(qzvo, _)), t(find_linedit_completion(qzvone, qzvone)), t(find_linedit_completion(qzvf, _)),
  t(find_linedit_completion(qzvnone, _)), t(find_linedit_completion(_, _)), t(find_linedit_completion(1, _)), t(find_linedit_completion(qzv, 1)).
PL
want="$(cat <<'WANT'
get_linedit_prompt(A) => [get_linedit_prompt('')]
set_linedit_prompt('qzv> ') => [set_linedit_prompt('qzv> ')]
get_linedit_prompt(A) => [get_linedit_prompt('qzv> ')]
get_linedit_prompt(x) => []
set_linedit_prompt(A) => error(instantiation_error)
set_linedit_prompt(1) => error(type_error(atom,1))
get_linedit_prompt(1) => error(type_error(atom,1))
set_linedit_prompt('') => [set_linedit_prompt('')]
get_linedit_prompt(A) => [get_linedit_prompt('')]
add_linedit_completion(qzvone) => [add_linedit_completion(qzvone)]
add_linedit_completion('QzvTwo') => [add_linedit_completion('QzvTwo')]
add_linedit_completion(qzv3) => [add_linedit_completion(qzv3)]
add_linedit_completion('qzv x') => []
add_linedit_completion('qzv-y') => []
add_linedit_completion('') => []
add_linedit_completion(A) => error(instantiation_error)
add_linedit_completion(f(x)) => error(type_error(atom,f(x)))
add_linedit_completion(qzvone) => [add_linedit_completion(qzvone)]
find_linedit_completion(qzv,A) => [find_linedit_completion(qzv,qzv),find_linedit_completion(qzv,qzv3),find_linedit_completion(qzv,qzvf),find_linedit_completion(qzv,qzvfour),find_linedit_completion(qzv,qzvnone),find_linedit_completion(qzv,qzvo),find_linedit_completion(qzv,qzvone)]
find_linedit_completion('Qzv',A) => [find_linedit_completion('Qzv','Qzv'),find_linedit_completion('Qzv','QzvTwo')]
find_linedit_completion(qzvo,A) => [find_linedit_completion(qzvo,qzvo),find_linedit_completion(qzvo,qzvone)]
find_linedit_completion(qzvone,qzvone) => [find_linedit_completion(qzvone,qzvone)]
find_linedit_completion(qzvf,A) => [find_linedit_completion(qzvf,qzvf),find_linedit_completion(qzvf,qzvfour)]
find_linedit_completion(qzvnone,A) => [find_linedit_completion(qzvnone,qzvnone)]
find_linedit_completion(A,B) => error(instantiation_error)
find_linedit_completion(1,A) => error(type_error(atom,1))
find_linedit_completion(qzv,1) => error(type_error(atom,1))
WANT
)"
n_want="$(printf '%s\n' "$want" | wc -l)"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep ' => ')"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: $n_want of $n_want lines as gprolog"
    else echo "  $label RED: $n of $n_want gprolog lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -20 | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run g.pl < /dev/null
if ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=g.s g.pl < /dev/null > /dev/null 2>&1 && [ -s g.s ] \
     && gcc -m64 -no-pie g.s -o g.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ); then
    arm m4 timeout -k 5 20 ./g.bin < /dev/null
else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
