#!/usr/bin/env bash
# test_gate_pas_a_variable_declared_in_one_routine_does_not_give_a_later_routines_variable_its_type.sh -- a variable's kind (set, character, text file, Boolean) belongs to the routine that declares it; a later routine's variable of the same name has its own (ISO 7185 6.2.2.1).
#
# MEASURED 2026-10-09 by hq_pascal against fpc -Miso: `procedure one(var s: settype)` followed by `procedure two; var s, i: integer; begin ... writeln(i * s) end` printed garbage in both modes, because the parser classified every variable named s as a set for the rest of the program and lowered
# the integer product as a set intersection; the same for `c: char` then `c: integer` (the integer printed as a letter), `f: text` then `f: integer`, and a Boolean function with a Boolean parameter followed by an integer of that name (the integer printed true). The parser kept the set, character,
# single, pchar and text-file variable tables as it kept the Boolean one (CEO-ruled landing ab1fe27cb cured only the Boolean table, and left a hole: a function's name is registered after its parameters, so the pop-while-deeper release stopped at the name and left the parameter behind).
# Found running Pascal-P5's interpreter: pint's integer read does `i := i*s` in a routine whose siblings getset and putset declare `s: settype`, and every integer read in every P5 program died in the set operation ("numeric expected").
# CURE (pascal.y only; no new global, no new table): each of the six tables stamps its entries with the routine nesting depth they were declared at (the member beside the name) and PAS_SCOPED_FNS generates its release (remove every entry deeper than the depth being left, wherever it sits), its save and its
# restore; pas_ptrvar_release -- the routine-exit release that already empties the pointer and record variables -- calls the six releases; a forward header saves its parameters' entries (pas_scoped_save, with the pointer and record ones) and the full definition that omits the parameter list restores them;
# the name of a char or Boolean function is registered at the enclosing depth (pas_charvar_add_outer, pas_boolvar_add_outer) so it outlives its body. This replaces the Boolean-only collect and restore of ab1fe27cb.
# NOT COVERED, written down: the array, record-array, string-array, enumerated-array and character-array tables and the variable type table keep their own scoping (the last three key their entries by the scope uid; the array tables carry is_local and is_param), and the single and pchar variable tables are cured by the same
# generated functions but no ISO program can declare them, so no arm reaches them.
#
# ARMS, both modes: four controls cut LIVE from fpc -Miso that must be byte-identical: a set parameter then an integer of the same name, a forward header with a set parameter and a routine declared between header and body whose local has the parameter's name; a char parameter and a text-file parameter then integers of the same
# names, a char function whose parameter shares the name with a later integer; a Boolean function with a Boolean parameter then an integer of that name. FAIL_ONCE=1 corrupts the first control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/tctl1.pas" <<'PAS'
program tctl1(output);
type settype = set of 0..31;
var g: settype; k: integer;
procedure one(var s: settype); begin s := [1, 2] end;
procedure two;
var s, i: integer;
begin s := 3; i := 4; writeln(i * s, ' ', i + s, ' ', i - s) end;
procedure fw(s: settype); forward;
procedure three;
var s: integer;
begin s := 5; writeln(s * 2) end;
procedure fw;
begin if 3 in s then writeln('in') else writeln('out'); if 2 in s then writeln('in2') else writeln('out2') end;
procedure four;
begin g := g + [2]; if 2 in g then writeln('g2') else writeln('not g2') end;
procedure five(var t: settype);
var s: settype; u: integer;
begin s := t * [1, 2, 3]; u := 6; if 1 in s then writeln('s1'); writeln(u * 7) end;
begin
  g := []; one(g); four; two; three; fw([2, 3]); fw([5]); five(g); k := 3; writeln(k * 3)
end.
PAS
cat > "$T/tctl2.pas" <<'PAS'
program tctl2(output);
var g: char; k: integer;
procedure one(c: char; var f: text); begin write(f, c); writeln(f) end;
procedure two;
var c, f: integer;
begin c := 65; f := 66; writeln(c, ' ', f, ' ', c + f) end;
function nxt(c: char): char; begin nxt := succ(c) end;
procedure three;
var c: integer;
begin c := ord(nxt('a')); writeln(c); writeln(nxt('a')) end;
procedure fw(c: char); forward;
procedure four; var c: integer; begin c := 7; writeln(c * 2) end;
procedure fw; begin writeln(c); writeln(ord(c)) end;
begin
  g := 'q'; one(g, output); two; three; four; fw('z'); k := 66; writeln(k); writeln(g)
end.
PAS
cat > "$T/tctl3.pas" <<'PAS'
program tctl3(output);
var d: integer;
function nxt(c: char): char; begin nxt := succ(c) end;
procedure a1; var c: integer; begin c := 98; writeln(c) end;
procedure a2; var c: integer; begin c := ord(nxt('a')); writeln(c) end;
procedure a3; var c: integer; begin c := ord('b'); writeln(c) end;
procedure a4; var c: integer; begin d := ord(nxt('a')); writeln(d) end;
procedure a5; var c: integer; begin c := ord(succ('a')); writeln(c) end;
begin a1; a2; a3; a4; a5 end.
PAS
cat > "$T/tctl4.pas" <<'PAS'
program tctl4(output);
function same(b: boolean): boolean; begin same := b end;
procedure two; var b: integer; begin b := 5; writeln(b) end;
begin writeln(same(true)); two; writeln(same(false)) end.
PAS
RC=0; N=0
for c in tctl1 tctl2 tctl3 tctl4; do
  frc=$(fpcrun $c)
  if [ -n "${FAIL_ONCE:-}" ] && [ "$c" = tctl1 ]; then echo "corrupted by FAIL_ONCE" >> "$T/$c.want"; fi
  for m in m3 m4; do run $m $c; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$c.want" "$T/o"; then echo "  $c $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $c $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$c.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a variable keeps the kind its own routine declared, as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 4 programs in 2 modes"; fi
exit $RC
