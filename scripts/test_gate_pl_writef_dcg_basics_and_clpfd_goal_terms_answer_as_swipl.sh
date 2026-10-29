#!/usr/bin/env bash
# test_gate_pl_writef_dcg_basics_and_clpfd_goal_terms_answer_as_swipl.sh -- TWO SWI LIBRARIES AND ONE CLPFD ROAD THE CLPFD ROLL-OUT'S
# SMOKE FOUND, ANSWERED AS SWIPL IN BOTH MODES (cfo 2026-10-11; the roll-out of library(clpfd), CEO-1596, over samples of the
# Rosetta and puzzles packages and Triska's clpfd examples; the cfo's lane, the SWI library modules).
#
# (1) library(writef) -- writef/1,2 with %w %p %s %d, the %Nr and %Nl columns, \l -- was absent (157 writef calls in the Prolog
# corpus; Rosetta's caesar-cipher and run-length-encoding died on it).  (2) library(dcg/basics) -- blanks//0, integer//1, digits//1,
# string_without//2, remainder//1, number//1 and kin -- was absent (Rosetta's isbn13-check-digit-1 died on digit//1).  Both are
# vendored verbatim from swipl 9.0.4's installed library through util_gen_prolog_prelude_libs.py (dcg/basics through its LIB_PATH
# table, as dcg_basics.pl, its module's name).  (3) clpfd's all_distinct/1 builds its pruning goals as DATA, [neq_num(V, N)|Gs], and
# runs maplist(call, Gs); the vendoring renamed the predicate neq_num/2 to '$clpfd_neq_num' but not that compound term, so every
# all_distinct that pruned a value raised existence_error(neq_num/2) (Triska's sudoku); the generator's RENAME_TERMS_AS_DATA renames it.
# (4) THE SELECTOR keyed a DCG body's nonterminals at their written arity, two short of the translated predicate, so a program reaching
# dcg/basics only through a rule body or phrase/2,3 (string_without//2, remainder//1) never selected it -- witness 1's bare blanks had
# matched by the any-arity rule; prolog_parse.c's pl_tree_collect_keys now keys a --> body and phrase's first argument at arity + 2.
# And the reverse: dcg/basics' exports are named like library(error)'s type atoms (integer, atom, number, string), so the any-arity
# rule selected dcg_basics for every program reaching error (the prelude cost gate's rbtrees arm read 5 libraries); the generator's
# QUIET_BARE makes its exports quiet at arity 0, so only a full-arity nonterminal reference selects it.
# (6) char_type/2 and code_type/2 answer xdigit(Weight) as they answer digit(Weight) (dcg/basics' xinteger//1 reads hex through it).
# (5) A double-quoted text in a phrase/2,3 body is a terminal (swipl): an SWI-dialect file reads it as a string object, and the
# runtime translator '$dcg_body' called it as a nonterminal ('.'/2 or a/2); it now takes its codes.
# NOT HERE: writef's %p prints through print/1, which quotes in swipl and not in SCRIP -- not graded here. NOT HERE: writef's %Nc centres with floor/1 of an integer, which SWI answers and ISO, gprolog and SCRIP refuse (type_error(float,
# 1)) -- a dialect split for the dialect switch (ARCH-PROLOG-DIALECTS.md), named to hq_prolog.
#
# (7) AN IMPORTED LIBRARY IS NOT QUIET FOR A BARE NAME (cfo 2026-10-14, row prolog-swi-library-test-dcg-high-order-...-ceo-1664):
# QUIET_BARE keeps a data atom from selecting a library the program never asked for, and so also refused the one bare name that IS a
# reference -- a nonterminal passed as a closure, sequence(string, sep, L) in SWI's test_dcg_high_order (existence_error(string/3),
# 30/32). A library the program imports (use_module(library(dcg/basics)) or use_module(library(dcg/basics), [string//1])) is now
# selected by a bare export name; witness w3. FAIL-ONCE: w3 on the parent 34390c91e rebuilt read 1 of 1 line differing in both
# modes (an existence_error ball where swipl writes [ab,cd]).
# THE ARMS: three witnesses (w3 the imported bare closure), stdout cut against swipl -q in this run, each diffed in mode 3 and mode 4 -- w1 writef and the clpfd goal
# term, w2 dcg/basics reached only through a rule body and phrase, and string terminals.  FAIL-ONCE, measured on origin 299e125f8
# (before the cure): w1 existence_error(writef/2) on its first line, 6 of 6 lines differ; w2 5 of 6 differ (its list body already
# passed); both modes, with origin's four source files restored into this tree and rebuilt.  rc=0 both modes
# agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~40 s (the clpfd line's mode-4 compile).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_writef_dcg_basics_and_clpfd_goal_terms_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w1.pl" <<'PL'
:- use_module(library(dcg/basics)).
:- use_module(library(clpfd)).
:- initialization(main).
main :- writef('a %w b %w\n', [x, f(y)]), writef("s=%s\n", [[104,105]]), writef('%d|%3r|%3l|\n', [42, ab, cd]), writef('plain\\l'),
    phrase((blanks, integer(N), blanks, digits(Ds), eos), `  42 007`), atom_codes(A, Ds), writef('%w %w\n', [N, A]),
    [P, Q] ins 1..2, C in 1..3, all_distinct([P, Q, C]), fd_dom(C, Dom), writef('%w\n', [Dom]), halt.
PL
cat > "$D/w2.pl" <<'PL'
:- use_module(library(dcg/basics)).
:- initialization(main).
t(N, G) :- ( catch(G, E, (writeq(N-E), nl)) -> true ; writeq(N-failed), nl ).
r(S, R) --> string_without(`,`, S), [0',], remainder(R).
main :- t(rule, (phrase(r(S, R), `ab,cd`), writeq(S-R), nl)),
    t(phrase3, (phrase(string_without(`,`, S2), `ab`, R2), writeq(S2-R2), nl)),
    t(conj_string, (phrase((string_without(`,`, S3), ",", remainder(R3)), `ab,cd`), writeq(S3-R3), nl)),
    t(string_body, (phrase("lit", `lit`), writeq(lit), nl)),
    t(list_body, (phrase([0'a], `a`), writeq(ok), nl)),
    t(xint, (phrase(xinteger(X), `ff`), writeq(X), nl)), halt.
PL
red=0
cat > "$D/w3.pl" <<'PL'
:- use_module(library(dcg/basics), [string//1]).
:- initialization(main).
seq(E, [X|Xs]) --> call(E, X), ( ",", !, seq(E, Xs) ; { Xs = [] } ).
main :- ( phrase(seq(string, L), `ab,cd`) -> findall(A, (member(C, L), atom_codes(A, C)), As), writeq(As) ; writeq(failed) ), nl, halt.
PL
for w in w1 w2 w3; do
    ( cd "$D" && timeout -k 5 60 "$SW" -q $w.pl < /dev/null 2> /dev/null > $w.want )
    [ -s "$D/$w.want" ] || refuse "swipl printed nothing for $w"
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --run $w.pl < /dev/null 2> $w.m3.err > $w.m3 )
    ( cd "$D" && timeout -k 5 300 "$B/scrip" --compile --out=$w.s $w.pl < /dev/null 2> $w.m4.err && gcc -no-pie $w.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o $w.bin 2>> $w.m4.err && timeout -k 5 60 ./$w.bin < /dev/null 2>> $w.m4.err > $w.m4 )
    n=$(wc -l < "$D/$w.want")
    for m in m3 m4; do
        if cmp -s "$D/$w.want" "$D/$w.$m"; then echo "  $w $m GREEN: $n of $n lines as swipl"
        else echo "  $w $m RED: $(diff "$D/$w.want" "$D/$w.$m" 2>/dev/null | grep -c '^<') of $n lines differ from swipl"; diff "$D/$w.want" "$D/$w.$m" 2>/dev/null | head -6 | sed 's/^/    /'; red=1; fi
    done
done
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
