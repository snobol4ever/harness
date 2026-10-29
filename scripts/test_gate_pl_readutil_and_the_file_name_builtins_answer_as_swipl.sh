#!/usr/bin/env bash
# test_gate_pl_readutil_and_the_file_name_builtins_answer_as_swipl.sh -- library(readutil) EXISTS, AS swipl 9.0.4 SHIPS IT, AND THE SWI
# BUILTINS IT STANDS ON ANSWER AS swipl DOES (cfo 2026-10-14, row prolog-swi-library-test-pio-every-case-agrees-with-swipl-in-both-modes-
# ceo-1664, CEO-1698; the corpus names read_line_to_codes in 16 Prolog files, read_line_to_string in 15, read_file_to_string in 12).
#
# (1) library(readutil) is vendored verbatim from swipl 9.0.4 (src/parsers/prolog/prelude/readutil.pl). Its :- initialization(link_foreign,
# now) tries a foreign readutil and otherwise ASSERTS read_line_to_codes/2,3 and read_stream_to_codes/2,3 over its Prolog pl_read_*
# predicates; util_gen_prolog_prelude_libs.py's INIT_AS_CLAUSES replaces the directive's text with those four clauses before the file is
# read, so they are keyed, renamed and exported like any other clause. (2) Base prelude builtins it needs (prolog_parse.c): read_string/3
# (to end of stream, or Length codes), read_string/5 (to a separator code, Sep -1 at end of stream, the pad codes stripped from both
# ends), absolute_file_name/3 (either argument order; extensions, file_type, access, file_errors, solutions, relative_to; an unknown option
# is ignored; existence_error(source_sink, Spec) unless file_errors(fail)), access_file/2 (none, exist, read, write and append -- a new
# file's directory --, execute, search; through '$gnu_os'(access, ...), the access(2) call), file_base_name/2, file_directory_name/2,
# file_name_extension/3 (both directions; '.hidden' splits as base '' and extension hidden, as swipl does). (3) open/3,4 in the SWI
# dialect with iso(false) skips an option it does not know (readutil passes its caller's tail(T) and encoding options to open/4), as
# swipl does; ISO mode still raises domain_error(stream_option, O) (swipl does the same under iso(true)).
#
# THE ARMS: three programs (w1 readutil, w2 the read_string/absolute_file_name/access_file/open shapes, w3 the file-name predicates),
# stdout cut against swipl in this run, mode 3 and mode 4. FAIL-ONCE, measured on the parent 4cb924582 rebuilt: every line of all three
# differs in both modes (existence_error on each predicate); with the cure all lines as swipl.
# rc=0 every arm agrees with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~10 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_readutil_and_the_file_name_builtins_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
printf 'line one\nline two\r\n\nlast' > "$D/ru.txt"
printf 'a(1).\nb("x").\n' > "$D/terms.pl"
printf '  ab  \ncd' > "$D/rs.txt"
cat > "$D/w1.pl" <<'PL'
:- use_module(library(readutil)).
:- initialization(main).
main :- open('ru.txt', read, S), read_line_to_codes(S, L1), read_line_to_string(S, L2), read_line_to_codes(S, L3, T3), T3 = [], read_line_to_string(S, L4), read_line_to_string(S, L5), read_line_to_codes(S, L6), close(S),
    atom_codes(A1, L1), writeq([A1, L2, L3, L4, L5, L6]), nl,
    read_file_to_codes('ru.txt', C, []), length(C, N), writeq(N), nl, read_file_to_codes('ru.txt', C2, [tail(Tl)]), Tl = [0'z], last(C2, X), writeq(X), nl,
    read_file_to_string('ru.txt', Str, []), string_length(Str, SL), writeq(SL), nl, read_file_to_terms('terms.pl', Ts, []), writeq(Ts), nl,
    open('ru.txt', read, S2), read_stream_to_codes(S2, C3), close(S2), length(C3, N3), writeq(N3), nl,
    catch(read_file_to_codes(nosuch, _, []), error(E, _), (writeq(E), nl)).
PL
cat > "$D/w2.pl" <<'PL'
:- use_module(library(lists)).
t(N, G) :- catch((G -> true ; (write(N-no), nl)), E, (write(N-ex), write(' '), print_message(silent, E), E = error(F, _), writeq(F), nl)).
:- initialization(main).
main :- t(rs5a, (open('rs.txt', read, S), read_string(S, "\n", " ", Sep, Str), read_string(S, "\n", " ", Sep2, Str2), read_string(S, "\n", " ", Sep3, Str3), close(S), writeq([Sep-Str, Sep2-Str2, Sep3-Str3]), nl)),
  t(rs3, (open('rs.txt', read, S3), read_string(S3, L, Str4), close(S3), writeq(L-Str4), nl)),
  t(abs3, (absolute_file_name('rs.txt', P, [access(read)]), atom(P), write(abs3-ok), nl)),
  t(abs3_old_order, (absolute_file_name('rs.txt', [access(read)], P2), atom(P2), write(old_ok), nl)),
  t(abs3_ext, (absolute_file_name(rs, P3, [extensions([txt]), access(read)]), file_base_name(P3, B3), writeq(B3), nl)),
  t(abs3_unknown_opt, (absolute_file_name('rs.txt', P4, [encoding(utf8), tail(_)]), atom(P4), write(unknown_ok), nl)),
  t(abs3_missing, absolute_file_name(nosuch, _, [access(read)])),
  t(abs3_missing_fail, absolute_file_name(nosuch, _, [access(read), file_errors(fail)])),
  t(access_file_r, (access_file('rs.txt', read), write(af_ok), nl)), t(access_file_missing, access_file(nosuch, read)), t(access_file_none, (access_file(nosuch, none), write(none_ok), nl)),
  t(access_file_write_new, (access_file(newfile, write), write(w_ok), nl)),
  t(open_unknown_opt, (open('rs.txt', read, S9, [tail(_), foo(bar)]), close(S9), write(open_ok), nl)).
PL
cat > "$D/w3.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
p(X) :- writeq(X), write(' ').
main :- forall(member(P, ['a/b/c.pl', 'c.pl', '/c', '/', 'a/b/', '', 'a//b', '.hidden', 'a.b/c']), ( file_base_name(P, B), file_directory_name(P, D), p(P), p(B), p(D), nl )),
  forall(member(N, ['a/b.pl', 'b', 'a.b/c', 'x.tar.gz', '.hidden', 'a/b.']), ( file_name_extension(B2, E2, N), p(N), p(B2), p(E2), nl )),
  forall(member(B-E, [foo-pl, foo-'.pl', 'foo.pl'-pl, foo-'', 'a/b'-txt]), ( file_name_extension(B, E, N3), p(N3), nl )),
  ( file_name_extension(foo, pl, 'foo.pl') -> p(check_yes) ; p(check_no) ), ( file_name_extension(B4, pl, 'foo.pl') -> p(B4) ; p(b4_no) ), ( file_name_extension(_, txt, 'foo.pl') -> p(b5) ; p(b5_no) ), nl.
PL
red=0
for w in w1 w2 w3; do
    ( cd "$D" && timeout -k 5 30 "$SW" -q $w.pl -t halt < /dev/null 2>/dev/null | sed '/^$/d' > $w.want )
    [ -s "$D/$w.want" ] || refuse "swipl printed nothing for $w"
    ( cd "$D" && timeout -k 5 30 "$B/scrip" --run $w.pl < /dev/null 2>/dev/null | sed '/^$/d' > $w.m3 )
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=$w.s $w.pl < /dev/null > /dev/null 2>&1 && gcc -m64 -no-pie $w.s -o $w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 \
        && timeout -k 5 30 ./$w.bin < /dev/null 2>/dev/null | sed '/^$/d' > $w.m4 ) || : > "$D/$w.m4"
    n=$(wc -l < "$D/$w.want")
    for m in m3 m4; do
        if cmp -s "$D/$w.want" "$D/$w.$m"; then echo "  $w $m GREEN: $n of $n lines as swipl"
        else echo "  $w $m RED: $(diff "$D/$w.want" "$D/$w.$m" | grep -c '^<') of $n lines differ from swipl"; diff "$D/$w.want" "$D/$w.$m" | head -6 | sed 's/^/    /'; red=1; fi
    done
done
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
