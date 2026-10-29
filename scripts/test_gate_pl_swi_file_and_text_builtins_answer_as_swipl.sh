#!/usr/bin/env bash
# test_gate_pl_swi_file_and_text_builtins_answer_as_swipl.sh -- SWI FILE, ENVIRONMENT AND TEXT BUILTINS SCRIP LACKED (hq_prolog 2026-10-15, row prolog-swi-tabling-the-xsb-loader-runs-the-xsb-test-drivers and the SWI census):
# exists_file/1, exists_directory/1, size_file/2, time_file/2, same_file/2, working_directory/2, setenv/2, unsetenv/1, text_to_string/2, open_string/2, directory_file_path/3 and
# make_directory_path/1 (src/parsers/prolog/prelude/swi_builtins.pl, a LOCAL prelude library over the '$gnu_os' stat, cwd, chdir and env operations; directory_file_path and
# make_directory_path are library(filesex)'s own clauses), and file_name_extension(B, '', 'foo.pl') failing as swipl does (the base prelude answered the whole name).
# THE ARM: one witness cut against swipl -q in this run and diffed in mode 3 and mode 4.  RED BEFORE (the parent 7a66c70d2): existence_error(procedure, ...) for each.
# rc=0 both modes agree with swipl - rc=1 a divergence - rc=2 REFUSAL (no swipl, no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
GATE=test_gate_pl_swi_file_and_text_builtins_answer_as_swipl
refuse() { echo "REFUSED(2) [$GATE]: $*"; exit 2; }
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate $GATE || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
t(R, G) :- catch((findall(R, G, L), \+ \+ (numbervars(L, 0, _), writeq(L))), error(E, _), \+ \+ (numbervars(E, 0, _), writeq(caught(E)))), nl.
main :-
    t(B1-E1, file_name_extension(B1, E1, 'foo.pl')),
    t(B2, file_name_extension(B2, '', 'foo.pl')),
    t(B3, file_name_extension(B3, '', 'foo')),
    t(B4, file_name_extension(B4, '.', 'foo.')),
    t(S1, text_to_string(abc, S1)), t(S2, text_to_string("x", S2)), t(S3, text_to_string([0'a], S3)), t(S4, text_to_string([a, b], S4)), t(S5, text_to_string([], S5)),
    t(S6, text_to_string(12, S6)), t(S7, text_to_string(_, S7)),
    t(x, exists_file('/etc/hostname_that_is_not_there')), t(x, exists_directory('/tmp')), t(x, exists_directory('/nonexistent/zz')), t(x, exists_file(_)),
    t(ok, (tmp_file(swb, F), open(F, write, S), write(S, hello), close(S), exists_file(F), \+ exists_directory(F), size_file(F, 5), time_file(F, T), float(T), same_file(F, F), delete_file(F), \+ exists_file(F))),
    t(x, size_file('/nonexistent/zz', _)),
    t(ok, (working_directory(O, O), sub_atom(O, _, 1, 0, /))),
    t(New, (working_directory(Old, '/tmp'), working_directory(New, Old), New == '/tmp/')),
    t(x, working_directory(_, '/nonexistent/zz')),
    t(ok, (setenv(swb_x, hello), getenv(swb_x, V), V == hello, unsetenv(swb_x), \+ getenv(swb_x, _))),
    t(P1, directory_file_path(a, b, P1)), t(P2, directory_file_path('a/', b, P2)), t(P3, directory_file_path('.', b, P3)), t(P4, directory_file_path(a, '/b', P4)),
    t(D5-F5, directory_file_path(D5, F5, 'a/b')), t(F6, directory_file_path(a, F6, 'a/b')), t(D7, directory_file_path(D7, b, 'a/b')),
    t(L8, (open_string("hello(world). foo.", S8), read(S8, T1), read(S8, T2), read(S8, T3), close(S8), L8 = [T1, T2, T3])),
    t(C9, (open_string(abc, S9), get_char(S9, C9), close(S9))),
    t(ok, (tmp_file(swbd, D), make_directory_path(D), exists_directory(D), delete_directory(D))),
    t(ok, (tmp_file(swbd2, D2), atom_concat(D2, '/a/b', DD), make_directory_path(DD), exists_directory(DD), atom_concat(D2, '/a', DA), delete_directory(DD), delete_directory(DA), delete_directory(D2))).
PL
( cd "$D" && timeout -k 5 30 swipl -q -t halt w.pl < /dev/null > want 2> /dev/null )
[ -s "$D/want" ] || refuse "swipl printed nothing for the witness"
( cd "$D" && timeout -k 5 30 "$B/scrip" --run w.pl < /dev/null > m3 2> m3.err )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null 2> m4.err && gcc -no-pie w.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o w 2>> m4.err && timeout -k 5 30 ./w < /dev/null > m4 2>> m4.err )
n=$(wc -l < "$D/want"); red=0
for m in m3 m4; do
    if cmp -s "$D/want" "$D/$m"; then echo "  $m GREEN: $n of $n lines as swipl"
    else echo "  $m RED: $(diff "$D/want" "$D/$m" 2>/dev/null | grep -c '^<') of $n lines differ from swipl"; diff "$D/want" "$D/$m" 2>/dev/null | head -10 | sed 's/^/    /'; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $GATE"
exit "$red"
