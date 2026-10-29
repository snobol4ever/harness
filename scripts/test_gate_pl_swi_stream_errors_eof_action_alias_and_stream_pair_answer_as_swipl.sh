#!/usr/bin/env bash
# test_gate_pl_swi_stream_errors_eof_action_alias_and_stream_pair_answer_as_swipl.sh -- SWI'S STREAM ERRORS, eof_action(error), AN ALIAS
# IN USE AND stream_pair/3 ANSWER AS swipl DOES (cfo 2026-10-14, SWI core/test_io.pl 1 -> 11 of 11).
#
# Five behaviors, measured against swipl 9.0.4 and cured in by_name_dispatch.c / the base prelude:
#  (1) open(F, read, S, [eof_action(abc)]): the SWI dialect raises domain_error(eof_action, abc) (ISO keeps domain_error(stream_option, ..)).
#  (2) A stream opened with eof_action(error) raises permission_error(input, past_end_of_stream, S) on a text read past the end
#      (get_char, peek_char, get_code, peek_code; the byte readers already did); SCRIP answered end_of_file/-1 again.
#  (3) current_input/1 and current_output/1 in the SWI dialect: an unknown alias or a closed stream is existence_error(stream, X), a
#      non-stream term domain_error(stream_or_alias, X) (ISO keeps domain_error(stream, X)), and an alias that DENOTES the current
#      stream (user_output) succeeds.
#  (4) An alias already in use is permission_error(open, source_sink, alias(A)) BEFORE the file is looked at (SCRIP opened first).
#  (5) stream_pair/3: a plain stream splits into its direction's component (the other side unbound); stream_pair(-P, +In, +Out) builds
#      a '$stream_pair'(In, Out) the stream resolver sends to Out for output and In for input, whose close/1 closes both; a closed pair
#      dissolves; In must be an input stream and Out an output stream (permission_error(input|output, stream, S)).
#
# THE ARM: one program, 28 lines, stdout cut against swipl in this run (stream blobs and variable names normalised), mode 3 and mode 4.
# FAIL-ONCE, measured on the parent e629b91a5 rebuilt: 23 of 28 lines differ in both modes; with the cure 28 of 28 as swipl in both modes.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_swi_stream_errors_eof_action_alias_and_stream_pair_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- use_module(library(lists)).
:- initialization((main1, main2)).
t(N, G) :- catch((G -> R = yes ; R = no), error(E, _), R = err(E)), \+ \+ (numbervars(N-R, 0, _), write_term(N-R, [quoted(true), numbervars(true)]), nl).
main1 :- t(eof_dom, open('/dev/null', read, _, [eof_action(abc)])),
  t(eof2, setup_call_cleanup(open('/dev/null', read, In, [eof_action(error)]), (get_code(In, C1), get_code(In, C2), writeq(c(C1,C2))), close(In))),
  t(cur_in_bad, current_input(unlikely)),
  t(cur_out_closed, (open_null_stream(S), close(S), current_output(S))),
  t(input_is_not_output, (current_input(X), current_output(X))),
  t(reuse_alias, setup_call_cleanup((open_null_stream(S2), set_stream(S2, alias(a))), open(nonexisting, read, _, [alias(a)]), close(S2))),
  t(pair1, (stream_pair(user_input, I1, O1), writeq(I1-O1), nl)),
  t(pair2, (stream_pair(user_output, I2, O2), writeq(I2-O2), nl)),
  t(set_after_close, (open_null_stream(S3), close(S3), set_stream(S3, timeout(0)))),
  t(double_close, (open_null_stream(S4), close(S4), close(S4))).
main2 :- t(atom, current_input(unlikely)), t(int, current_input(1)), t(comp, current_input(f(x))), t(str, current_output("s")), t(user_input_as_output, current_output(user_input)), t(alias_in, current_input(user_input)), t(alias_out, current_output(user_output)),
  t(alias_out_for_input, current_input(user_output)), t(closed, (open_null_stream(S), close(S), current_input(S))), t(var, current_input(_)), t(good, (current_output(O), is_stream(O))),
  t(pair_out, (open_null_stream(S2), stream_pair(P, user_input, S2), stream_pair(P, I, O2), writeq(is(I, O2)), nl, close(P))),
  t(pair_plain_out, (stream_pair(user_output, I3, O3), writeq(I3-O3), nl)),
  t(pair_in_no_in, (open_null_stream(S4), stream_pair(P4, S4, user_input))).
PL
norm() { sed -E "s/<stream>\\(0x[0-9a-f]+\\)/<stream>/g; s/'\\\$stream'\\([0-9]+\\)/<stream>/g; s/_G?[0-9]+/_/g" | grep .; }
want="$(cd "$D" && timeout -k 5 20 "$SW" -q w.pl -t halt < /dev/null 2>/dev/null | norm)"
[ "$(printf '%s\n' "$want" | grep -c .)" = 28 ] || refuse "swipl did not answer the twenty-eight lines: [$(printf '%s\n' "$want" | grep -c .)]"
m4ok=1   # a program SCRIP refuses to compile is this gate's red, never a refusal
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1" got n; shift
    got="$(cd "$D" && "$@" 2>/dev/null | norm)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 28 of 28 lines as swipl"
    else echo "  $label RED: $n of 28 swipl lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 30 "$B/scrip" --run w.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 30 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
