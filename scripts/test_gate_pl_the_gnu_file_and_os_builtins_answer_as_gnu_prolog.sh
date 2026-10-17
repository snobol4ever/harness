#!/usr/bin/env bash
# test_gate_pl_the_gnu_file_and_os_builtins_answer_as_gnu_prolog.sh -- the ten GNU Prolog file and OS builtins Logtalk's GNU adapter
# uses answer as gplc 1.4.5 does, byte for byte, in both modes (row prolog-the-ten-gnu-file-and-os-builtins-logtalk-needs, minted by the
# ceo 2026-10-02 from the Logtalk 3.103.0-b01 run: each was an existence error).
#
# THE TEN: environ/2 and file_property/2 (prelude Prolog over the det leaves $gnu_environ_list/1 and $gnu_file_props/2, so both
# enumerate on backtracking), working_directory/1, change_directory/1, make_directory/1, delete_file/1, file_exists/1,
# directory_files/2 (readdir order), term_hash/2 and prolog_pid/1 (det leaves over the POSIX calls, src/runtime/by_name_dispatch.c).
# WHAT IS GRADED, cut 2026-10-03 from gplc 1.4.5 with this exact program: every success and failure, every error CLASS and its
# CONTEXT (gplc names the predicate; delete_file/1's context is delete_file/2 in gplc and is matched), the property order of
# file_property/2, and the hash VALUES of seventeen terms -- term_hash/2 is GNU's own MurmurHash3 term walk ported from
# /home/resources/gprolog-master/src/BipsPl/term_supp.c and Tools/hash_fct.c (atoms by GNU's atom hash, lists car then cdr with no
# functor, integers as two 32-bit blocks, floats by GNU's frexp mantissa rule, modulo 2^28).
# ⛔ NOT GRADED BY DESIGN: values that differ per run or per box (the environment's contents, the cwd above gate_cwd, times, the pid)
# -- the program prints only facts about them; the gate sets SCRIP_GATE_ENV and SCRIP_GATE_UNIQ itself and runs under LC_ALL=C so
# strerror's text is the oracle's. A bare term_hash(a, H) with a CONSTANT first argument compiled by gplc 1.4.5 answers 924988191
# (above 2^28) where the same call through member/2 answers 115623523; SCRIP answers the runtime value, which is what this gate pins.
# FAIL-ONCE: on the parent every one of the ten raised existence_error(procedure, ...).
# Usage: bash ../harness/scripts/test_gate_pl_the_gnu_file_and_os_builtins_answer_as_gnu_prolog.sh
set -uo pipefail
GATE_NAME=test_gate_pl_the_gnu_file_and_os_builtins_answer_as_gnu_prolog
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
mkdir -p "$d/m3/gate_cwd" "$d/m4/gate_cwd"
cat > "$d/w.pl" <<'PL'
:- initialization(main).
t(G) :- catch((call(G) -> write(yes) ; write(no)), E, (copy_term(E, C), numbervars(C, 0, _), write(caught(C)))), nl.
main :-
    t(environ('SCRIP_GATE_ENV', v1)), t(environ('SCRIP_GATE_ENV', v2)), t(environ(nosuch_gate_var_xyz, _)),
    t((environ(N, v1_unique_gate_value), N == 'SCRIP_GATE_UNIQ')), t((findall(K, environ(K, _), Ks), length(Ks, L), L > 2)),
    t(environ(1, _)), t(environ(_, 1)),
    t((working_directory(W), atom(W), sub_atom(W, _, _, 0, '/gate_cwd'))), t(working_directory(1)),
    t(make_directory(wdir)), t(make_directory(wdir)), t(make_directory(_)), t(make_directory(1)),
    t(file_exists(wdir)), t(file_exists(nosuch)), t(file_exists(_)), t(file_exists(1)),
    t(file_property(wdir, type(directory))), t(file_property(wdir, type(regular))), t(file_property(wdir, permission(search))),
    t(file_property(nosuch, type(_))), t(file_property(_, type(_))), t(file_property(1, type(_))), t(file_property(wdir, foo(_))),
    t((findall(Q, (file_property(wdir, P), functor(P, Q, _)), Qs), write(Qs), write(' '))),
    t((file_property(wdir, last_modification(M)), M = dt(Y, _, _, _, _, _), integer(Y))),
    t(change_directory(wdir)), open('f.txt', write, S), write(S, hello), close(S), t(change_directory('..')),
    t(change_directory(nosuch)), t(change_directory(_)), t(change_directory(1)),
    t(file_property('wdir/f.txt', size(5))), t(file_property('wdir/f.txt', type(regular))), t(file_property('wdir/f.txt', permission(execute))),
    t((file_property('wdir/f.txt', real_file_name(RF)), sub_atom(RF, _, _, 0, '/gate_cwd/wdir/f.txt'))),
    t((directory_files(wdir, Fs), msort(Fs, SF), write(SF), write(' '))), t(directory_files(nosuch, _)), t(directory_files(_, _)), t(directory_files(1, _)),
    t(delete_file('wdir/f.txt')), t(file_exists('wdir/f.txt')), t(delete_file('wdir/f.txt')), t(delete_file(wdir)), t(delete_file(_)),
    forall(member(T, [a, b, foo, bar, f(a), [a], 1, 0, -1, 2.5, [], f(foo), g(1,2), [a,b], foo(bar), 1.5, 'hello world']),
           (term_hash(T, H), writeq(T), write(' '), write(H), nl)),
    t((term_hash(f(_), H2), var(H2))), t(term_hash(a, foo)),
    t((prolog_pid(Pid), integer(Pid), Pid > 0)), t(prolog_pid(foo)).
PL
cat > "$d/want" <<'WANT'
yes
no
no
yes
yes
caught(error(type_error(atom,1),environ/2))
caught(error(type_error(atom,1),environ/2))
yes
caught(error(type_error(atom,1),working_directory/1))
yes
caught(error(system_error(File exists),make_directory/1))
caught(error(instantiation_error,make_directory/1))
caught(error(type_error(atom,1),make_directory/1))
yes
no
caught(error(instantiation_error,file_exists/1))
caught(error(type_error(atom,1),file_exists/1))
yes
no
yes
caught(error(system_error(No such file or directory),file_property/2))
caught(error(instantiation_error,file_property/2))
caught(error(type_error(atom,1),file_property/2))
caught(error(domain_error(os_file_property,foo(A)),file_property/2))
[absolute_file_name,real_file_name,type,size,permission,permission,permission,creation,last_access,last_modification] yes
yes
yes
yes
caught(error(system_error(No such file or directory),change_directory/1))
caught(error(instantiation_error,change_directory/1))
caught(error(type_error(atom,1),change_directory/1))
yes
yes
no
yes
[.,..,f.txt] yes
caught(error(system_error(No such file or directory),directory_files/2))
caught(error(instantiation_error,directory_files/2))
caught(error(type_error(atom,1),directory_files/2))
yes
no
caught(error(system_error(No such file or directory),delete_file/2))
caught(error(system_error(Is a directory),delete_file/2))
caught(error(instantiation_error,delete_file/2))
a 115623523
b 149133811
foo 46241272
bar 100012066
f(a) 52948119
[a] 116904419
1 80695581
0 79100715
-1 85475768
2.5 189970877
[] 207316914
f(foo) 188614967
g(1,2) 94102616
[a,b] 32678982
foo(bar) 84149544
1.5 112434414
'hello world' 46539674
yes
caught(error(type_error(integer,foo),term_hash/2))
yes
caught(error(type_error(integer,foo),prolog_pid/1))
WANT
export LC_ALL=C SCRIP_GATE_ENV=v1 SCRIP_GATE_UNIQ=v1_unique_gate_value
cp "$d/w.pl" "$d/m3/gate_cwd/"; cp "$d/w.pl" "$d/m4/gate_cwd/"
fails=0; graded=0
(cd "$d/m3/gate_cwd" && timeout -k 5 20 "$SCRIP" w.pl </dev/null 2>/dev/null) > "$d/m3.out"; rc=$?; graded=$((graded + 1))
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m3.out"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/want" "$d/m3.out" | head -20; fi
if (cd "$d/m4/gate_cwd" && timeout -k 5 60 "$SCRIP" --compile -o w.s w.pl </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie w.s -L"$OUT" -lscrip_rt -lm -lpthread -Wl,-rpath,"$OUT" -o w.bin 2>/dev/null); then
    (cd "$d/m4/gate_cwd" && timeout -k 5 20 ./w.bin </dev/null 2>/dev/null) > "$d/m4.out"; rc=$?; graded=$((graded + 1))
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m4.out"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/want" "$d/m4.out" | head -20; fi
else graded=$((graded + 1)); fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
[ "$(grep -c '' "$d/want")" -eq 65 ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table is not the 65-line oracle cut it names"; exit 2; }
echo "PLGNUOS_BOARD lines=65 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
