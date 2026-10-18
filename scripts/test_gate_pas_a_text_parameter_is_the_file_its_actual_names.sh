#!/usr/bin/env bash
# test_gate_pas_a_text_parameter_is_the_file_its_actual_names.sh -- a var formal of type text is a file inside its routine: f^, eoln,
# read, readln and write act on the file the actual names, the required input and output included (ISO 7185 6.6.3.3, 6.10; row
# pascal-p4-self-hosts-under-scrip..., ceo CEO-1311)
#
# MEASURED 2026-09-27 by hq_pascal, both modes. Only declared text variables were registered as files, so inside procedure
# p(var f: text) the parser took f for a variable: read(f, c) read an integer into f (ISO 6.9.1 error on the first letter), f^ became
# a pointer dereference, eoln(f) and writeln(f, ...) missed. And input or output given as such an actual passed no file at all. P4's
# interpreter reads every character of generation 2 this way (readc(input), readc(prd)). THE CURE: a text formal registers as a
# file; input or output given to a var formal is the standard stream's own file handle (__pas_stdfile), which the lowerer holds in a
# temporary the way it already holds an array element given to a var formal, with nothing to write back.
#
# ARMS, both modes, stdout and exit code cut LIVE from fpc -Miso on the same stdin: (1) tread -- characters, an integer, eoln, f^ and
# readln through var f: text given input, from nested routines; (2) twrite -- write and writeln through var f: text given output,
# interleaved with the program's own writeln, in order.
# FAILS on the parent 964982d54 in arm (1); arm (2) was already green there and keeps the write path under test beside the cure.
# FAIL_ONCE=1 corrupts arm (2)'s ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
printf 'ab12 x\nsecond\n' > "$T/in.txt"
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" <"$T/in.txt" >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" <"$T/in.txt" >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc <"$T/in.txt" >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/tread.pas" <<'PAS'
program tread(input, output);
var n: integer; ch: char;
procedure outer;
  procedure readc(var f: text);
    var c: char;
  begin write('peek[', f^, '] '); read(f, c); writeln('read[', c, ']') end;
  procedure readi(var f: text);
    var k: integer;
  begin read(f, k); writeln('int[', k:1, '] eoln=', eoln(f)) end;
begin readc(input); readc(input); readi(input); readc(input); readc(input) end;
procedure skipline(var f: text);
begin readln(f) end;
begin
  outer; writeln('eoln now ', eoln(input));
  skipline(input); n := 0;
  while not eoln(input) do begin n := n + 1; read(ch) end;
  writeln('second line length ', n:1)
end.
PAS
cat > "$T/twrite.pas" <<'PAS'
program twrite(output);
var i: integer;
procedure say(var f: text; k: integer);
begin write(f, 'value '); writeln(f, k:3) end;
begin
  writeln('start');
  for i := 1 to 3 do begin say(output, i * 7); writeln('between ', i:1) end;
  writeln('end')
end.
PAS
for p in tread twrite; do
  frc=$(fpcrun $p)
  if [ "$p" = twrite ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a text parameter is the file its actual names, as fpc -Miso does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 2 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
