#!/usr/bin/env bash
# test_gate_pas_a_boolean_local_does_not_make_a_later_routines_variable_of_the_same_name_boolean.sh -- a Boolean declared in one routine is a Boolean only inside that routine (ISO 7185 6.2.2.1, the scope of an identifier is its block).
#
# MEASURED 2026-10-09 by hq_pascal against fpc -Miso: `procedure one; var r, f: boolean; ...` followed by `procedure two; var r: real; f: integer; begin r := 6.5; f := 3; writeln(r:8:3); writeln(f:1) end` printed r as 0.000 and f as t in
# both modes where fpc prints 6.500 and 3. The parser kept every Boolean variable name it had ever seen in one table that was never emptied (pas_boolvar_add, no release), so a later real, integer or character of the
# same name was classified Boolean: writeln of it took the true/false path, and an assignment of a real to it was lowered as a Boolean store. Found while running Pascal-P5's interpreter under the byte-addressed variant overlay:
# its callsp declares `f: integer; r: real` after routines with `r, f: boolean`, and every real it wrote came out 0.000. CURE (pascal.y only; no new global, no new table): each Boolean entry carries the routine nesting depth
# it was declared at (the member beside the name; pas_boolvar_add stamps g_pas_npvmark), pas_ptrvar_release -- the existing routine-exit release that already empties the pointer and record variables -- drops the entries
# deeper than the depth it returns to; a Boolean FUNCTION's name is stamped with the enclosing depth (pas_boolvar_add_outer) so a caller after the body still sees a Boolean call; a forward header saves the Boolean parameters it
# declared with its pointer and record ones (pas_boolvar_collect, the bn/bnames members of the forward table) and the full definition that omits the parameter list re-adds them.
# NOT COVERED, written down: the sibling tables keyed by name alone -- the character, set, single and subrange variable tables are still never released (a character local `c` and a later integer `c` share a class).
#
# ARMS, both modes: one control cut LIVE from fpc -Miso: Boolean locals r and f in one routine and a real r and an integer f in the next (written, computed and printed), a Boolean function used in conditions after its body, a
# forward-declared routine with a Boolean parameter and an integer parameter of the same name in a routine declared between the header and the body, a nested Boolean function whose local shares a name with an integer local
# of its parent; it must be byte-identical. FAIL_ONCE=1 corrupts the control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/tctl.pas" <<'PAS'
program tctl(output);
var g: boolean; n: integer;
function isok(x: integer): boolean;
begin isok := x > 2 end;
procedure one;
var r, f: boolean;
begin r := true; f := false; writeln(r, ' ', f); if isok(3) then writeln('ok3'); if not isok(1) then writeln('no1') end;
procedure two;
var r: real; f: integer;
begin r := 6.5; f := 3; writeln(r:8:3); writeln(f:1); f := f * 2 + 1; writeln(f); r := r * 2.0; writeln(r:6:2) end;
procedure fw(flag: boolean); forward;
procedure three(flag: integer);
begin writeln(flag + 1) end;
procedure fw;
begin if flag then writeln('flag true') else writeln('flag false'); writeln(flag) end;
procedure five;
var flag: integer;
begin flag := 41; writeln(flag + 1) end;
procedure four;
var b: integer;
  function inner(x: integer): boolean;
  var b: boolean;
  begin b := x > 0; inner := b end;
begin b := 5; writeln(b:1); if inner(2) then writeln('in true'); b := b + 1; writeln(b:1); writeln(inner(0)) end;
begin
  g := true; n := 4;
  one; two; three(4); fw(true); fw(false); five; four;
  writeln(g); writeln(n:1); if isok(n) then writeln('n ok')
end.
PAS
RC=0; N=0
frc=$(fpcrun tctl)
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/tctl.want"; fi
for m in m3 m4; do run $m tctl; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/tctl.want" "$T/o"; then echo "  tctl $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ tctl $m FAILED: rc=$rc (fpc $frc)"; diff "$T/tctl.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a Boolean local is Boolean only inside its routine, as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 1 program in 2 modes"; fi
exit $RC
