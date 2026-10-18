#!/usr/bin/env bash
# test_gate_pas_the_input_buffer_variable_is_the_next_character.sh -- input^, the buffer variable of the required textfile input,
# is the character the next read will deliver, as fpc -Miso gives it (ISO 7185 6.4.3.5, 6.10; row pascal-p4-self-hosts..., CEO-1311)
#
# MEASURED 2026-09-27 by hq_pascal, both modes. The selector rule sent a buffer variable of a declared textfile to __pas_tbuf_get but
# excluded the standard streams, so input^ fell through to a pointer dereference and every program that read input^ stopped with
# "ISO 7185 6.5.4: the pointer-variable of an identified-variable is undefined". P4's interpreter reads it at start-up
# (store[inputadr].vc := input^), so a SCRIP-built int.pas could run no P-code at all. THE CURE: input^ is the stdin lookahead
# __pas_getbufch -- the same call the parser already gives GetBufCh(input), which the corpus's FPC port of that interpreter writes in
# its place -- and it is a char expression. At end of line fpc -Miso gives the newline itself, not ISO's space; the one oracle wins.
# OPEN, NOT GRADED HERE: input^ at end of file (fpc gives chr(0), SCRIP a space) and get(input) (it reaches the list builtin get).
#
# ARMS, both modes, stdout and exit code cut LIVE from fpc -Miso on the same stdin: (1) walk -- input^ before each read across three
# lines, one of them empty; (2) peek -- input^ equals the character read next, and does not consume it.
# FAILS on the parent 964982d54 in both arms. FAIL_ONCE=1 corrupts arm (2)'s ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
printf 'ab\n\ncd\n' > "$T/in.txt"
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" <"$T/in.txt" >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" <"$T/in.txt" >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc <"$T/in.txt" >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/walk.pas" <<'PAS'
program walk(input, output);
var c: char; n: integer;
begin
  n := 0;
  while not eof(input) do
    begin
      write('[', ord(input^):1, ']');
      if eoln(input) then begin readln; writeln(' eol') end else read(c);
      n := n + 1
    end;
  writeln(n:1)
end.
PAS
cat > "$T/peek.pas" <<'PAS'
program peek(input, output);
var c, d, e: char;
begin
  c := input^; e := input^; read(d);
  writeln('peek=', c, ' again=', e, ' read=', d, ' same=', c = d);
  c := input^; read(d); writeln('peek=', c, ' read=', d, ' same=', c = d)
end.
PAS
for p in walk peek; do
  frc=$(fpcrun $p)
  if [ "$p" = peek ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: input^ is the next character as fpc -Miso gives it, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 2 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
