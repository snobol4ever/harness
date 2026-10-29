#!/usr/bin/env bash
# test_gate_pl_gnu_read_raises_gprologs_syntax_error_at_gprologs_position_and_recovers_as_gprolog.sh -- OUTSIDE THE SWI DIALECT, read/1,2 AND read_term/2,3
# RAISE gprolog's syntax_error('FILE:LINE (char:COL) MESSAGE'), RECORD IT FOR syntax_error_info/4, AND LEAVE THE STREAM WHERE gprolog LEAVES IT
# (cfo 2026-10-15, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/read_driver and BipsPl/pl_error_driver).
#
# SCRIP's run-time reader raised syntax_error(cannot_start_term) for every bad term. When it now fails a term outside the SWI dialect, the reader seeks back
# to where the term began and runs gprolog's own parser over the stream -- parse_supp.c's Parse_Term, Parse_Args_Of_Functor, Parse_Bracketed_Term and
# Parse_List ported to C over effebfaf5's scanner, one token of lookahead, SCRIP's operator table -- to find the token gprolog stops at and its message
# (expression expected, ", or ) expected", ", | ] or operator expected in list", ". or operator expected after expression", "right operand expected for infix
# operator", "current or previous operator needs brackets", ...). The position is gprolog's: the line, and the byte column of that token, an end of file one
# column past the last character as gprolog's line_pos counts it. Then gprolog's Pl_Recover_After_Error places the stream (skip to the full stop, quoted
# tokens honoured; no skip when the error token ended the term), so the next read starts where gprolog's does. When gprolog's parser accepts the text SCRIP's
# refused, or the stream cannot seek, the old message stands. The last error is held in the hidden flag $gnu_synerr, which syntax_error_info/4 reads.
#
# THE ARM: one program (no SWI marker), 48 lines, the reference cut from gprolog 1.6.0 (2026-10-15), mode 3 and mode 4: twenty-one bad terms each
# followed by a good one, a file ending inside a quoted atom and inside a compound, syntax_error_info/4, and read_term's syntax_error(fail).
# FAIL-ONCE, measured on the parent (SCRIP effebfaf5 rebuilt): 22 of 48 lines differ in both modes (each error reads cannot_start_term, the reads after an end of file differ).
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~10 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_read_raises_gprologs_syntax_error_at_gprologs_position_and_recovers_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
rd(S) :- catch(read(S, T), error(F, _), T = err(F)), writeq(T), nl, ( T == end_of_file -> true ; rd(S) ).
main :- open('syn.txt', write, W),
  write(W, 'bad( .\nok(1).\nfoo bar.\nok(2).\nf(a b).\nok(3).\n[1 a].\nok(4).\n[1|2 a].\nok(5).\n(a b).\nok(6).\n{a b}.\nok(7).\nf(a,).\nok(8).\n[a,].\nok(9).\nX = .\nok(10).\n'),
  write(W, '- = x.\nok(11).\n) .\nok(12).\n[a|].\nok(13).\nf(- ).\nok(14).\n  g(h(1, [2, 3 | t]), {x , y}) :- ( a ; b ) -> c , d .\nok(15).\nf(a\n  b).\nok(16).\n'),
  write(W, 'X = [1,2|3, 4].\nok(17).\na :- b :- c.\nok(18).\n- 1 + .\nok(19).\nf(a) g.\nok(20).\n'),
  close(W), open('syn.txt', read, S), rd(S), close(S),
  open('syn2.txt', write, W2), write(W2, 'f(a, \'unterminated\nok(21).\nlast(x'), close(W2), open('syn2.txt', read, S2), rd(S2), close(S2),
  ( syntax_error_info(F, L, C, M) -> writeq(info(F, L, C, M)) ; write(noinfo) ), nl,
  open('syn.txt', read, S3), ( read_term(S3, T3, [syntax_error(fail)]) -> writeq(T3) ; write(failed) ), nl, read_term(S3, T4, []), writeq(T4), nl, close(S3).
PL
want="$(cat <<'WANT'
err(syntax_error('syn.txt:1 (char:6) expression expected'))
ok(1)
err(syntax_error('syn.txt:3 (char:5) . or operator expected after expression'))
ok(2)
err(syntax_error('syn.txt:5 (char:5) , or ) expected'))
ok(3)
err(syntax_error('syn.txt:7 (char:4) , | ] or operator expected in list'))
ok(4)
err(syntax_error('syn.txt:9 (char:6) ] or operator expected in list'))
ok(5)
err(syntax_error('syn.txt:11 (char:4) ) or operator expected'))
ok(6)
err(syntax_error('syn.txt:13 (char:4) } or operator expected'))
ok(7)
err(syntax_error('syn.txt:15 (char:5) expression expected'))
ok(8)
err(syntax_error('syn.txt:17 (char:4) expression expected in list'))
ok(9)
err(syntax_error('syn.txt:19 (char:5) right operand expected for infix operator'))
ok(10)
err(syntax_error('syn.txt:21 (char:3) current or previous operator needs brackets'))
ok(11)
err(syntax_error('syn.txt:23 (char:1) expression expected'))
ok(12)
err(syntax_error('syn.txt:25 (char:4) expression expected in list'))
ok(13)
f(-)
ok(14)
g(h(1,[2,3|t]),{x,y}):-(a;b)->c,d
ok(15)
err(syntax_error('syn.txt:32 (char:3) , or ) expected'))
ok(16)
err(syntax_error('syn.txt:34 (char:11) ] or operator expected in list'))
ok(17)
err(syntax_error('syn.txt:36 (char:8) . or operator expected after expression'))
ok(18)
err(syntax_error('syn.txt:38 (char:7) right operand expected for infix operator'))
ok(19)
err(syntax_error('syn.txt:40 (char:6) . or operator expected after expression'))
ok(20)
end_of_file
err(syntax_error('syn2.txt:1 (char:19) unexpected newline'))
ok(21)
err(syntax_error('syn2.txt:3 (char:7) , or ) expected'))
end_of_file
info('syn2.txt',3,7,', or ) expected')
failed
ok(1)
WANT
)"
n_want="$(printf '%s\n' "$want" | wc -l)"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && rm -f syn.txt syn2.txt && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: $n_want of $n_want lines as gprolog"
    else echo "  $label RED: $n of $n_want gprolog lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -20 | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run --dialect=gnu g.pl < /dev/null
if ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --dialect=gnu --out=g.s g.pl < /dev/null > /dev/null 2>&1 && [ -s g.s ] \
     && gcc -m64 -no-pie g.s -o g.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ); then
    arm m4 timeout -k 5 20 ./g.bin < /dev/null
else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
