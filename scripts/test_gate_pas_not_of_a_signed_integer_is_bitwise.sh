#!/usr/bin/env bash
# test_gate_pas_not_of_a_signed_integer_is_bitwise.sh -- not applied to a signed integer expression is the bitwise complement (not 10
# = -11), as fpc reads it in -Miso and in its own modes; not of a Boolean stays logical.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta (CEO-1562, row pascal-every-suite-to-100-under-nonet-ceo-1266): E_expression lowered
# every not as a logical negation, so writeln(not a) with a: integer = 10 printed false (FALSE in an FPC dialect) where fpc prints
# -11. THE CURE (lower_pascal_tree.c): pas_is_signed_intexpr answers yes for an integer literal, a scalar of type integer, longint,
# int64, smallint or shortint, and +, -, *, mod, and / or / xor (iand / ior / ixor) over such operands; not of one lowers to -1 - x.
# A Boolean, a relation, a call and an unsigned type are not classified and keep the logical not -- a missed integer stays as it was,
# a Boolean is never complemented. OPEN, NOT GRADED HERE: not of an unsigned type (byte, word, cardinal: not 10 is 245 as a byte).
#
# ARMS: isonot against fpc -Miso and objnot ({$mode objfpc}) against fpc -Mobjfpc -- integer, sum, and-result, literal and longint
# complements beside Boolean, relation and odd() negations, in expressions and in if-conditions -- both modes, cut LIVE.
# MEASURED on the parent fc4bb9a7e (in-tree swap): both red (not a printed false). FAIL_ONCE=1 corrupts isonot's expectation.
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
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { local mode="$2"; mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" $mode -v0 -FE"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc $mode would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/isonot.pas" <<'PAS'
program isonot(output);
var a, b: integer; p, q: boolean; l: longint;
begin
  a := 10; b := 12; p := true; q := a > b; l := -5;
  writeln(not a, not (a + b), not (a and b), not 0, not l);
  writeln(not p, not q, not (a > b), not (p and q), not odd(a));
  if not (a = b) then writeln('ne');
  if not p or not q then writeln('either')
end.
PAS
cat > "$T/objnot.pas" <<'PAS'
program objnot;
{$mode objfpc}
var a, b: integer; p, q: boolean; l: longint;
begin
  a := 10; b := 12; p := true; q := a > b; l := -5;
  writeln(not a, not (a + b), not (a and b), not 0, not l);
  writeln(not p, not q, not (a > b), not (p and q), not odd(a));
  if not (a = b) then writeln('ne');
  if not p or not q then writeln('either')
end.
PAS
for pm in "isonot -Miso" "objnot -Mobjfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = isonot ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: not of a signed integer is bitwise and not of a Boolean logical, as fpc reads them, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined two programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
