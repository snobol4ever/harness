#!/usr/bin/env bash
# test_gate_pas_a_constant_is_hidden_by_a_variable_parameter_or_constant_of_the_same_name_in_a_routine.sh -- a routine's own variable, parameter, local constant or enumerator hides an outer constant of the same name (ISO 7185 6.2.2.1, 6.2.2.2).
#
# MEASURED 2026-10-09 by hq_pascal against fpc -Miso: with `const maxsize = 32;` at program level, `procedure u; var minsize, maxsize, lsize: integer; begin maxsize := minsize; ... end` read the constant 32 wherever the body wrote maxsize, in both modes; the same for a parameter named like a
# constant (`procedure q(n: integer)` with `const n = 5`), a local constant that redefines an outer one, and a local variable named like an enumerator (`red`). The constant table was one list keyed by name, and identifier resolution took a constant before it looked at the scope.
# Found running Pascal-P5's compiler: pcom's recordtype has `var minsize, maxsize, lsize: addrrange` under the program constant `maxsize = 32`, so every variant record was sized 32 bytes at most, the record copy of Pascal-P5's Dhrystone dropped the last 11 bytes of a string, and
# the P-code of its record types differed from the native compiler's.
# CURE (pascal.y only; no new global, no new table): a constant records the scope uid of its defining occurrence (pas_scope_uid at pas_const_add) and pas_const_get accepts it only while that is still the innermost visible definition of the name; and a field name declared in a record
# body (a scope definition made while g_pas_recbody_depth is nonzero, now marked fld) no longer counts as a definition of that name in pas_scope_uid, so a record field called like a constant does not hide the constant.
#
# ARMS, both modes: one control cut LIVE from fpc -Miso that must be byte-identical: a local variable, a parameter, a local constant redefining an outer one, a local variable named like an enumerator, three locals one named like the constant, a record field named like the constant,
# and the constants read at program level before and after all of them. FAIL_ONCE=1 corrupts the control's ref.
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
cat > "$T/tctl1.pas" <<'PAS'
program tctl1(output);
const maxsize = 32; n = 5; limit = 9;
type rec = record maxsize: integer; z: integer end;
     color = (red, green, blue);
var r: rec; k: integer;
procedure p; var maxsize: integer; begin maxsize := 7; writeln(maxsize) end;
procedure q(n: integer); begin writeln(n) end;
procedure s;
const limit = 3;
begin writeln(limit) end;
procedure t; var red: integer; begin red := 41; writeln(red + 1) end;
procedure u;
var minsize, maxsize, lsize: integer;
begin minsize := 4; maxsize := minsize; lsize := maxsize + 1; if lsize > maxsize then maxsize := lsize; writeln(minsize, ' ', maxsize, ' ', lsize) end;
begin p; writeln(maxsize); r.maxsize := 3; writeln(r.maxsize); q(8); writeln(n); s; writeln(limit); t; writeln(ord(green)); u; writeln(maxsize) end.
PAS
RC=0; N=0
for c in tctl1; do
  frc=$(fpcrun $c)
  if [ -n "${FAIL_ONCE:-}" ] && [ "$c" = tctl1 ]; then echo "corrupted by FAIL_ONCE" >> "$T/$c.want"; fi
  for m in m3 m4; do run $m $c; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$c.want" "$T/o"; then echo "  $c $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $c $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$c.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a routine's own name hides an outer constant, as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 1 programs in 2 modes"; fi
exit $RC
