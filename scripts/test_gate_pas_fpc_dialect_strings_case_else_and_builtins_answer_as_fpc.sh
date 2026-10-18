#!/usr/bin/env bash
# test_gate_pas_fpc_dialect_strings_case_else_and_builtins_answer_as_fpc.sh -- the FPC dialect's strings, case ... else and otherwise,
# and the System routines its programs call, every arm byte-identical to fpc in the mode the program's own constructs select (rows
# pascal-fpc-dialect-conditional-compilation-directives-case-else-... (CEO-1612) and pascal-dialects-one-switch-... (CEO-1614)).
#
# THE FLIP POINTS ARE THE CONSTRUCTS fpc -Miso REFUSES, measured: the identifier string ("Identifier not found"), otherwise, and
# (landed earlier) uses and unit. A program using one is in the FPC dialect and is graded against fpc's default mode (bare integers,
# the any-fpc-mode contract). fpc -Miso ACCEPTS case ... else, copy, concat, upcase, paramcount, paramstr, fillchar, sizeof and
# assign, so none of those flips.
# - string flips only in a TYPE position (simple_type, a parameter's or a function's result type) and only when the program has
#   not declared its own type string. P4 declares a VARIABLE named string, and an ISO program's "type string = packed array ..."
#   stays ISO (arm v1).
# - otherwise is a keyword only when blanks and a letter follow it (a statement); pat0001's "otherwise: integer" stays an
#   identifier (arm v1).
# - The final dialect is stamped on the program-name leaf, the first leaf the lowerer reads, so a flip decided deep in a program
#   governs all of it.
# THE GRAMMAR: string[n] in a type position (TT_IDX over string, rewritten to string in type positions by the lowerer's
# pas_shortstrings), and a case_tail -- ELSESY or OTHERWISESY with a statement list -- ending the case statement as a TT_PART.
# THE LOWERER AND RUNTIME: the case tail ends the arm chain in place of the 6.8.3.5 error; copy (Pascal's own, no longer falling
# through to Icon's builtin); concat folds to TT_CAT; upcase of a char or a string; paramcount and paramstr; s[0] reads the
# length as a char; a read or readln into a string variable reads the rest of the line (__pas_read_s / __pas_read_s_f, getline,
# the newline pushed back for readln).
# OPEN, NOT GRADED HERE: string[n]'s declared length (assignment truncation, s[0] := ...), and integer's 16-bit size in fpc's default
# mode (sizeof(integer) is 2 there).
#
# ARMS (expectation CUT LIVE from fpc, both modes): s1 string flip with string[n], s[0], concat, copy, upcase, pos (fpc default); c1
# case ... else with copy and upcase of a char (-Miso); c2 otherwise (fpc default); v1 otherwise as a variable and a program's own
# type string (-Miso); rd readln of a string from stdin and from a file (fpc default, stdin fed); pa paramcount and paramstr with
# two arguments (fpc default). FAIL_ONCE=1 corrupts one ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; ARMS=0
grade() { local p="$1" mode="$2" args="${3:-}" d="$T/$1"
  mkdir -p "$d/fpc"; cp "$T/$p.pas" "$d/"; [ -f "$T/$p.in" ] && cp "$T/$p.in" "$d/" || : > "$d/$p.in"
  ( cd "$d" && "$FPC" $mode -v0 -FE"$d/fpc" -FU"$d/fpc" -o"$d/fpc/$p" "$p.pas" >/dev/null 2>&1 && rm -f zz_out.txt && timeout -k 5 20s "$d/fpc/$p" $args < "$p.in" | head -c 8000 ) > "$d/want" 2>/dev/null
  [ -s "$d/want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output for arm $p"; exit 2; }
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = s1 ]; then echo "corrupted by FAIL_ONCE" >> "$d/want"; fi
  ( cd "$d" && timeout -k 5 20s "$SCRIP" --compile -o "$p.s" "$p.pas" </dev/null >/dev/null 2>"$d/m4.err" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ arm $p m4: did not compile and link"; RC=1; }
  ARMS=$((ARMS + 1))
  for m in m3 m4; do
    if [ "$m" = m3 ]; then ( cd "$d" && rm -f zz_out.txt && timeout -k 5 20s "$SCRIP" --run "$p.pas" ${args:+-- $args} < "$p.in" 2>"$d/$m.err" | head -c 8000 > "$d/$m.out" )
    else ( cd "$d" && rm -f zz_out.txt && timeout -k 5 20s "./$p.m4" $args < "$p.in" 2>"$d/$m.err" | head -c 8000 > "$d/$m.out" ); fi
    if cmp -s "$d/want" "$d/$m.out"; then echo "  arm $p $m: byte-identical to fpc ${mode:-(default mode)}"
    else echo "  ⛔ arm $p $m FAILED"; echo "      want: $(tr '\n' '|' < "$d/want" | cut -c1-300)"; echo "      got : $(tr '\n' '|' < "$d/$m.out" | cut -c1-300)"
         echo "      err : $(tr '\n' '|' < "$d/$m.err" | cut -c1-200)"; RC=1; fi
  done; }
cat > "$T/s1.pas" <<'PAS'
program s1;
var s: string[20]; t: string; i: integer;
begin
  s := 'abc'; s := s + 'de'; t := concat(s, 'fg', 'h'); i := 42;
  writeln(i, ' ', length(s), ' ', s, ' ', t, ' ', ord(s[0]), ' ', upcase(s[1]), upcase('q'), ' ', upcase(t));
  writeln(pos('de', t), ' ', copy(t, 2, 3), '|', copy(t, 7, 10), '|', length(copy(t, 3, 0)), '|', copy(t, 6))
end.
PAS
cat > "$T/c1.pas" <<'PAS'
program c1(output);
var c: char; i: integer;
begin
  for i := 1 to 3 do
  begin
    c := chr(ord('a') + i - 1);
    case c of
      'a': writeln('a ', i);
      'b': writeln(upcase(c), ' ', copy('xyz', i, 2))
    else
      writeln('other ', i);
      writeln('second statement')
    end
  end
end.
PAS
cat > "$T/c2.pas" <<'PAS'
program c2;
var k: integer;
begin
  for k := 1 to 3 do
    case k of
      1: writeln('one ', k);
      2: writeln('two')
      otherwise writeln('many ', k)
    end
end.
PAS
cat > "$T/v1.pas" <<'PAS'
program v1(output);
type string = packed array[1..3] of char;
var otherwise: integer; s: string;
begin
  otherwise := 5; s := 'abc';
  writeln(s, otherwise)
end.
PAS
cat > "$T/rd.pas" <<'PAS'
program rd;
var f: text; t, u: string;
begin
  readln(t); readln(u);
  writeln('[', t, '] [', u, ']');
  assign(f, 'zz_out.txt'); rewrite(f); writeln(f, 'line one'); writeln(f, 'line two'); close(f);
  assign(f, 'zz_out.txt'); reset(f); readln(f, t); readln(f, u); close(f);
  writeln(t, '|', u)
end.
PAS
printf 'hello world\nsecond line\n' > "$T/rd.in"
cat > "$T/pa.pas" <<'PAS'
program pa;
var s: string;
begin
  s := paramstr(1);
  writeln(paramcount, ' ', s, ' ', paramstr(2), ' [', paramstr(3), ']')
end.
PAS
grade s1 ""
grade c1 "-Miso"
grade c2 ""
grade v1 "-Miso"
grade rd ""
grade pa "" "first second"
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $ARMS arms -- the FPC dialect's strings, case else and otherwise, and its System routines answer as fpc in the mode each program selects, both modes"
else echo "GATE FAIL(1) [$G]: examined $ARMS arms in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
