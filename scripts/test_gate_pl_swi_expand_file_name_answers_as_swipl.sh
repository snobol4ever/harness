#!/usr/bin/env bash
# test_gate_pl_swi_expand_file_name_answers_as_swipl.sh -- expand_file_name/2 AS SWIPL 9.0.4 ANSWERS IT (hq_icon 2026-10-31, row prolog-swi-to-100-the-failing-cases-ceo-1930, SWI files/test_glob glob_expand:glob).
# THE FEATURE: src/parsers/prolog/prelude/swi_builtins.pl, a LOCAL prelude library over directory_files/2 and wildcard_match/2.  A name with no ? * [ { is returned as the one-element list it was after $VAR and ~ expansion, existing
# or not; a name with one is split at '/', each wildcard segment lists its directory and matches it (a leading '.' only by a segment that starts with '.'; '.' and '..' are entries), a literal segment after a wildcard
# must exist, a trailing '/' is dropped, the whole strings are msort-ed, an unmatched [ or { raises syntax_error(Unmatched ...), an unbound name raises instantiation_error and a compound one type_error(text, _).
# THE WITNESS: 70 labelled patterns over a scratch tree (dotfiles, a dot directory, names with a space, a bracket, a dash that sorts before '/', and accented and Cyrillic letters), absolute patterns, ~ and $VAR with HOME set
# to a scratch directory, a string, a code list, a number and the error shapes, each answered as `label => the matches joined by |` or `label => the formal of the error`; swipl 9.0.4 cuts the want in this run.
# ARMS: the oracle answers the whole witness (its last line is present; an oracle that cannot REFUSES rc 2), then mode 3 and mode 4 each equal it line for line.
# RED BEFORE (measured 2026-10-31 on the tree before the cure): core files/test_glob read glob_expand:glob "existence_error(procedure, plunit_glob_expand:expand_file_name/2)" in both modes, and every line of this witness
# is that error.  FAIL-ONCE: shown red against the oracle's different answer (a scratch copy of this gate whose scrip run is given one pattern the oracle is not).
# NOT COVERED, KNOWN: a backslash before [ ('x\[1\].pl': swipl returns the half-unescaped text 'x[1\].pl' as a name with no wildcard, SCRIP matches the file x[1].pl); ~user for a user other than the current one is read from
# /etc/passwd and is not in the witness (the box's users differ); the three cyrillic cases of test_glob sit under a :- if on a user goal (ARCH-PROLOG-DATABASE s.22, the cqo's row).
# rc 0 both modes agree with swipl - rc 1 a divergence - rc 2 REFUSAL (no swipl, no build).  ~6 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
GATE=test_gate_pl_swi_expand_file_name_answers_as_swipl
refuse() { echo "REFUSED(2) [$GATE]: $*"; exit 2; }
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate $GATE || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
export LC_ALL=C.utf8 LANG=C.utf8
mkdir -p "$D/home" "$D/tree/sub" "$D/tree/sub2" "$D/tree/.hd" "$D/tree/a" "$D/tree/a-b" "$D/tree/zdir" || refuse "cannot build the scratch tree"
( cd "$D/tree" && touch a.pl b.pl C.pl .hid.pl 'a b.txt' sub/x.pl sub/y.txt sub2/x.pl .hd/z.pl 'x[1].pl' a/x a-b/x zdir/q 'é.pl' 'ж.pl' ) || refuse "cannot build the scratch tree"
touch "$D/home/h.txt"
cat > "$D/w.pl" <<'PL'
:- initialization(main).
show(L, R) :- ( is_list(R) -> atomic_list_concat(R, '|', J) ; J = R ), format("~w => ~w~n", [L, J]).
t(L, Spec) :- catch(( expand_file_name(Spec, R) -> show(L, R) ; show(L, failed) ), error(F, _), show(L, F)).
main :-
    forall(member(P, ['a.pl', 'nonexist', 'nonexist*', '*.pl', '.*', '.*.pl', '?.pl', '[ab].pl', '[a-c].pl', '[!a].pl', '{a,b}.pl', '{a,zz,b}.pl', '*', 'sub/*', '*/x.pl', './*.pl', 'sub/../*.pl', '*/*', '**',
                      'a\\ b*', 'a*/x', '*/x', 'sub*/', 'sub/', 'nonexist/*', 'sub/nonexist*', 'sub/nonexist', '{*.pl,*.txt}', '*.{pl,txt}', 'sub/*.pl/x', '*/', '//tmp', 'a//*', '*.pl*', '*[.]pl', '.hd/*',
                      '.h*/*', '.hd/z.pl', '*/.*', '*é*', '?.pl', '.', '..', '../*x', '{sub,sub2}/x.pl', 'a.pl/*', '', '/', 'a}', '{}.pl', '*\\[*', '[', 'a{', '{*.pl,sub/*}', '$NOSUCHVAR', '~nosuchuser_zz']), t(P, P)),
    working_directory(W, W),
    atom_concat(W, '*/x.pl', A1), t(abs1, A1), atom_concat(W, 's*', A2), t(abs2, A2), atom_concat(W, '.h*/*', A3), t(abs3, A3), atom_concat(W, 'sub/', A4), t(abs4, A4),
    getenv('HOME', H), atom_concat(H, '/*', A5), t(home1, A5), t('~', '~'), t('~/', '~/'), t('~/*', '~/*'), t('$HOME', '$HOME'), t('$HOME/*', '$HOME/*'), t('${HOME}/x', '${HOME}/x'),
    atom_string('*.pl', S), t(string, S), t(codes, [0'*, 0'., 0'p, 0'l]), t(number, 1), t(compound, f(x)), t(compound2, sub/'*'), t(unbound, _).
PL
( cd "$D/tree" && HOME="$D/home" timeout -k 5 30 swipl -q -t halt "$D/w.pl" < /dev/null > "$D/want" 2> /dev/null )
[ -s "$D/want" ] || refuse "swipl printed nothing for the witness"
[ "$(wc -l < "$D/want")" -ge 70 ] || refuse "swipl answered fewer than 70 lines -- the witness did not run to its end: $(tail -1 "$D/want")"
( cd "$D/tree" && HOME="$D/home" timeout -k 5 60 "$B/scrip" --run "$D/w.pl" < /dev/null > "$D/m3" 2> "$D/m3.err" )
( cd "$D" && timeout -k 5 120 "$B/scrip" --compile --out=w.s w.pl < /dev/null 2> m4.err && gcc w.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o w 2>> m4.err && cd tree && HOME="$D/home" timeout -k 5 60 ../w < /dev/null > "$D/m4" 2>> "$D/m4.err" )
n=$(wc -l < "$D/want"); red=0
for m in m3 m4; do
    if cmp -s "$D/want" "$D/$m"; then echo "  $m GREEN: $n of $n lines as swipl"
    else echo "  $m RED: $(diff "$D/want" "$D/$m" 2>/dev/null | grep -c '^<') of $n lines differ from swipl"; diff "$D/want" "$D/$m" 2>/dev/null | head -10 | sed 's/^/    /'; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $GATE"
exit "$red"
