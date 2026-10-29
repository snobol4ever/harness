#!/usr/bin/env bash
# test_gate_pl_a_pipe_stream_has_a_position_as_swipl_and_phrase_from_file_reads_standard_input_through_it.sh -- swipl answers stream_property(S, position(P))
# for a stream on a pipe with '$stream_position'(CharCount, LineNo, LinePos, ByteCount), counted from what the program consumed, and library(pure_input)
# (phrase_from_file/2) needs it to read a pipe: /dev/stdin opened as a file. SCRIP answered the property only for a seekable stream (ftell), so a pipe-fed
# phrase_from_file failed (ProRosetta reverse-the-order-of-lines-in-a-text-file-while-preserving-the-contents-of-each-line, graded with stdin a pipe, CEO-1926).
# Two probes, each cut from swipl in THIS run with stdin a pipe and compared byte for byte with SCRIP's m3 and m4: (1) the position before any read, after one
# character and after one line (swipl: 0,1,0,0 then 1,1,1,1 then 4,2,0,4 for "abc\nde\n"); (2) a phrase_from_file that reads the three lines of stdin
# and writes them back reversed. The self-test feeds the comparison a corrupted reference and requires it seen.
set -u
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plpipe.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/pos.pl" <<'PL'
:- open('/dev/stdin', read, S), stream_property(S, position(P0)), writeln(P0), get_char(S, C), writeln(C), stream_property(S, position(P1)), writeln(P1),
   read_line_to_string(S, L), writeln(L), stream_property(S, position(P2)), writeln(P2), close(S).
PL
cat > "$W/rev.pl" <<'PL'
:- use_module(library(pure_input)).
:- use_module(library(dcg/basics), [string_without/4]).
:- use_module(library(dcg/high_order), [sequence/4]).
lines(Lines) --> sequence(line, Lines).
line(Line) --> string_without("\n", Line), "\n".
:- phrase_from_file(lines(Lines), '/dev/stdin'), reverse(Lines, R), phrase(lines(R), Codes), format("~s", [Codes]).
PL
printf 'abc\nde\n' > "$W/pos.in"
printf 'one\ntwo words\nthree\n' > "$W/rev.in"
build() { "$ROOT/scrip" --compile --out="$W/$1.s" "$W/$1.pl" < /dev/null > "$W/$1.c.err" 2>&1 && gcc -no-pie -o "$W/$1.bin" "$W/$1.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/$1.l.err" 2>&1; }
bad=0
for p in pos rev; do
  cat "$W/$p.in" | timeout -k 5 30 "$SW" -q -t halt "$W/$p.pl" > "$W/$p.ref" 2> "$W/$p.ref.err"
  [ "$(grep -c . "$W/$p.ref")" -ge 3 ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the $p probe ($(head -c 160 "$W/$p.ref.err"))"; exit 2; }
  cat "$W/$p.in" | timeout -k 5 30 "$ROOT/scrip" "$W/$p.pl" > "$W/$p.m3" 2>&1
  build $p || { echo "GATE REFUSED(2) [$G]: the $p probe does not build ($(head -c 160 "$W/$p.c.err" "$W/$p.l.err"))"; exit 2; }
  cat "$W/$p.in" | timeout -k 5 30 "$W/$p.bin" > "$W/$p.m4" 2>&1
  sed '1s/.*/corrupted/' "$W/$p.ref" > "$W/$p.bad"
  if cmp -s "$W/$p.m3" "$W/$p.bad"; then echo "GATE REFUSED(2) [$G]: the comparison accepted a corrupted reference -- the gate could not fail"; exit 2; fi
  for m in m3 m4; do
    if cmp -s "$W/$p.$m" "$W/$p.ref"; then echo "  ok  $m $p: as swipl with stdin a pipe"; else echo "  RED $m $p: differs from swipl:"; diff "$W/$p.ref" "$W/$p.$m" | head -6; bad=1; fi
  done
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a pipe stream's position is swipl's four-argument term counted from what was consumed, and phrase_from_file reads /dev/stdin through a pipe, in both modes (self-test: a corrupted reference is seen) (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a pipe stream's position or a pipe-fed phrase_from_file differs from swipl (tree SCRIP=$TREE)"; exit 1
