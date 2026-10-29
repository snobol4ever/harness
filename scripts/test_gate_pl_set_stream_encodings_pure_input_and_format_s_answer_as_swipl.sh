#!/usr/bin/env bash
# test_gate_pl_set_stream_encodings_pure_input_and_format_s_answer_as_swipl.sh -- set_stream/2, THE ONE-BYTE AND wchar_t ENCODINGS,
# library(pure_input) AND format/2's ~s ANSWER AS swipl 9.0.4 (cfo 2026-10-14, row prolog-swi-library-test-pio-every-case-agrees-with-swipl-
# in-both-modes-ceo-1664, CEO-1698: test_pio's engine half; 9 corpus files name set_stream, 9 tmp_file, 10 phrase_from_file).
#
# (1) set_stream/2 is a C leaf ('$set_stream'/2, by_name_dispatch.c): alias (moved from a stream that held it), eof_action, type,
# encoding (wraps the stream in the transcoder, re-kinds a wrapped one, or turns it back to UTF-8), line_position and file_name change the
# stream; buffer, buffer_size, close_on_abort, close_on_exec, tty, timeout, newline, record_position and representation_errors are
# validated and accepted (SCRIP's stream has no state they would change); anything else is domain_error(stream_attribute, P), as swipl
# raises. (2) open/4's and set_stream's encoding names: octet, iso_latin_1 and ascii read and write one byte per code (a new transcoder
# kind, src/driver/driver_globals.c), wchar_t is UTF-32LE, unicode_be/le are UTF-16BE/LE. (3) library(pure_input) is vendored from swipl
# 9.0.4: phrase_from_file/2,3, phrase_from_stream/2, stream_to_lazy_list/2 build a lazy list on an attribute hook. A selected library
# whose text calls put_attr or freeze now arms the attribute wake-up (prolog_parse.c, beside the phrase and bagof keys: the hook never
# fired when only the library named the API); its attr_unify_hook_ndebug/2 goal term is renamed with the predicate (RENAME_TERMS_AS_DATA);
# the base prelude gains what it calls -- read_pending_codes/3, read_pending_chars/3, fill_buffer/1, nb_linkarg/3, '$notrace'/1 -- and
# stream_property/2 answers buffer(full|line|false) and a position on a transcoded stream (the raw file's offset). (4) tmp_file/2,
# tmp_file_stream/3 (both argument forms), getenv/2, and the max_char_code flag (1114111). (5) format/2's ~s wrote each code as ONE
# BYTE -- 233 as the byte 0xE9, U+1F600 as NUL -- where swipl writes the code: plc_fmt_text encodes it in UTF-8 (unification.c).
#
# THE ARMS: four programs (w1 set_stream and the round trips, w2 format ~s, w3 a lazy list over seven encodings, w4 phrase_from_file),
# stdout cut against swipl in this run, mode 3 and mode 4. FAIL-ONCE, measured on the parent 437627f83 rebuilt: every program differs in
# both modes (set_stream/2, tmp_file/2 and phrase_from_file/2 existence errors; ~s wrote h, 0xE9, 0xFF); with the cure all lines agree.
# rc=0 every arm agrees with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~15 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_set_stream_encodings_pure_input_and_format_s_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w1.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
t(N, G) :- catch((G -> R = yes ; R = no), error(E, _), R = E), writeq(N-R), nl.
rt(Enc, Codes) :- atom_concat(f_, Enc, F), open(F, write, O, [encoding(Enc)]), format(O, '~s', [Codes]), close(O), open(F, read, I, [encoding(Enc)]), read_stream_codes(I, Back), close(I),
    open(F, read, B, [type(binary)]), read_bytes(B, Bytes), close(B), length(Bytes, NB), writeq(Enc-NB-(Back == Codes)), nl.
read_stream_codes(S, L) :- get_code(S, C), ( C == -1 -> L = [] ; L = [C|T], read_stream_codes(S, T) ).
read_bytes(S, L) :- get_byte(S, C), ( C == -1 -> L = [] ; L = [C|T], read_bytes(S, T) ).
main :- open(a, write, S), t(alias, (set_stream(S, alias(myout)), write(myout, hi), nl(myout))), t(tty, set_stream(user_output, tty(false))), t(buffer_size, set_stream(S, buffer_size(25))),
    t(buffer, set_stream(S, buffer(line))), t(eof_action, set_stream(S, eof_action(reset))), t(bad_prop, set_stream(S, foo(bar))), t(bad_eof, set_stream(S, eof_action(nope))), t(unbound, set_stream(S, _)),
    t(record_position, set_stream(S, record_position(true))), t(newline, set_stream(S, newline(posix))), close(S),
    open(a, read, R), t(read_back, (read_stream_codes(R, Cs), atom_codes(A, Cs), A == 'hi\n')), close(R),
    rt(octet, [104, 233, 255]), rt(iso_latin_1, [104, 233, 255]), rt(ascii, [104, 105]), rt(wchar_t, [104, 0x1F600]), rt(utf16le, [104, 0x1F600]), rt(utf8, [104, 0x1F600]),
    open(b, write, W), format(W, '~s', [[0x41]]), set_stream(W, encoding(utf16be)), format(W, '~s', [[0x42]]), close(W), open(b, read, BB, [type(binary)]), read_bytes(BB, BBy), close(BB), writeq(switch(BBy)), nl.
PL
cat > "$D/w2.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
main :- format("~s|~n", [[104,233,255]]), format("~s|~n", [[104,128512]]), atom_codes(A, [104,233,128512]), format("~w|~n", [A]), open(o8, write, O), format(O, "~s", [[104,233,128512]]), close(O),
  open(o8, read, I, [type(binary)]), get_byte(I, B1), get_byte(I, B2), get_byte(I, B3), close(I), writeq([B1,B2,B3]), nl.
PL
cat > "$D/w3.pl" <<'PL'
:- use_module(library(pure_input)).
:- initialization(main).
rt(Enc, List) :- tmp_file(x, F), open(F, write, O, [encoding(Enc)]), format(O, '~s', [List]), close(O),
   open(F, read, In, [encoding(Enc), bom(false)]), set_stream(In, buffer_size(25)), stream_to_lazy_list(In, Lazy), ( List = Lazy -> R = ok ; R = bad ), close(In),
   open(F, read, I2, [encoding(Enc), bom(false)]), rd(I2, Back), close(I2), length(Back, NB), ( Back = [B1|_] -> true ; B1 = none ), writeq(Enc-R-NB-B1), nl.
rd(S, L) :- get_code(S, C), ( C == -1 -> L = [] ; L = [C|T], rd(S, T) ).
main :- forall(member(E, [ascii, octet, iso_latin_1, utf8, utf16be, utf16le, wchar_t]), rt(E, [104, 105, 106])).
PL
cat > "$D/w4.pl" <<'PL'
:- use_module(library(pio)).
:- initialization(main).
t(N, G) :- catch((G -> R = yes ; R = no), E, R = E), writeq(N-R), nl.
main :- t(tmp, (tmp_file(plunit_pio, T), atom(T))), tmp_file(x, F), open(F, write, O), format(O, '~s', ["aba"]), close(O),
  t(open_read, (open(F, read, S), close(S))), t(lazy, (open(F, read, S2), stream_to_lazy_list(S2, L), L = [A|_], writeq(A), nl, close(S2))), t(pff, phrase_from_file("aba", F)), t(pff_fail, phrase_from_file("abc", F)).
PL
red=0
for w in w1 w2 w3 w4; do
    mkdir -p "$D/$w.d3" "$D/$w.d4" "$D/$w.dsw"
    ( cd "$D/$w.dsw" && timeout -k 5 30 "$SW" -q ../$w.pl -t halt < /dev/null 2>/dev/null | sed '/^$/d' > ../$w.want )
    [ -s "$D/$w.want" ] || refuse "swipl printed nothing for $w"
    ( cd "$D/$w.d3" && timeout -k 5 30 "$B/scrip" --run ../$w.pl < /dev/null 2>/dev/null | sed '/^$/d' > ../$w.m3 )
    ( cd "$D/$w.d4" && timeout -k 5 60 "$B/scrip" --compile --out=$w.s ../$w.pl < /dev/null > /dev/null 2>&1 && gcc -m64 -no-pie $w.s -o $w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 \
        && timeout -k 5 30 ./$w.bin < /dev/null 2>/dev/null | sed '/^$/d' > ../$w.m4 ) || : > "$D/$w.m4"
    n=$(wc -l < "$D/$w.want")
    for m in m3 m4; do
        if cmp -s "$D/$w.want" "$D/$w.$m"; then echo "  $w $m GREEN: $n of $n lines as swipl"
        else echo "  $w $m RED: $(diff "$D/$w.want" "$D/$w.$m" | grep -c '^<') of $n lines differ from swipl"; diff "$D/$w.want" "$D/$w.$m" | head -6 | sed 's/^/    /'; red=1; fi
    done
done
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
