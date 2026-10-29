#!/usr/bin/env bash
# test_gate_pas_a_character_taken_from_a_string_constant_concatenates_as_a_character.sh -- const D = '0123456789ABC' and D[3] + s: indexing a NAMED string constant
# yields a character, so it concatenates (D[3] + 'Z' is '2Z'), where SCRIP appended the character's decimal code ('50Z') and added two of them (D[3] + D[4] was 101).
#
# WHY (PasRosetta digital-root, whose IntToStrBase writes DigitSymbols[Value mod Base + 1] + Result and printed 545055544953 for 627615): the constant is substituted as a string
# literal before it is indexed, so the index node's base is a TT_QLIT, and pas_is_charexpr had a branch for an index into a string VARIABLE (and a typed constant) but none for a
# literal. THE CURE (lower_pascal_tree.c, pas_is_charexpr): an index into a string literal is a character.
#
# MEASURED 2026-10-21 by hq_pascal on the parent, fpc 3.2.2 {$mode objfpc} against scrip, one program of eight lines: fpc 2Z|7Z|yZ|bZ|Z2|23|75|[2]| and scrip 50Z|55Z|yZ|bZ|Z50|101|5553|234|
# (the typed constant E[i] and the variable s[i] were already right). ARMS (both modes, stdout and exit code cut LIVE from fpc): chrobj ({$mode objfpc}) and chrdel ({$mode delphi}),
# each with a literal index, a computed index, a typed constant, a variable, a char on the right of the +, two chars side by side, a function that prepends one, and one inside a bracketed
# literal. FAIL_ONCE=1 corrupts chrobj's expectation.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link ($(head -1 "$T/e" | cut -c1-120))"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { local mode="$2"; mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" $mode -v0 -FE"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc $mode would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
for pm in "chrobj objfpc" "chrdel delphi"; do p=${pm% *}; md=${pm#* }
  cat > "$T/$p.pas" <<PAS
{\$mode $md}{\$H+}
program $p;
const D = '0123456789ABC';
      E: string = 'xyz';
var s, t: string; v: int64; i: integer;
function g(v: int64): string;
begin
  Result := '';
  Result := D[v mod 10 + 1] + Result;
  Result := D[(v div 10) mod 10 + 1] + Result
end;
begin
  s := 'abc'; t := 'Z'; v := 7; i := 2;
  writeln(D[3] + t);
  writeln(D[v + 1] + t);
  writeln(E[i] + t);
  writeln(s[i] + t);
  writeln(t + D[3]);
  writeln(D[3] + D[4]);
  writeln(g(75));
  writeln('[' + D[3] + ']')
end.
PAS
done
arm() { local p="$1" om="$2" frc
  frc=$(fpcrun "$p" "$om") || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = chrobj ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m "$p"; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(tr '\n' '|' < "$T/o" | cut -c1-48))"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; }
arm chrobj -Mobjfpc
arm chrdel -Mdelphi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a character taken from a string constant concatenates as a character, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined two programs over $N arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
