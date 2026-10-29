#!/usr/bin/env bash
# test_gate_pas_a_function_returning_a_dynamic_array_holds_an_array.sh -- a function whose return type is a dynamic-array type holds
# an array in its result: SetLength, an element's INC, Length and High of the function name (or Result) inside its body act on the
# array, and the caller receives it, as fpc does.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta's empty-output class (ceo CEO-1709): entropy's frequencies(str, ustr): FArray did
# SetLength(frequencies, n) -- the name was registered only as a scalar of type FArray, so SetLength took the string road (n spaces)
# and INC(frequencies[u]) bumped character codes; entropy printed -24.66549 for 1.84644. THE CURE (lower_pascal_tree.c): at both
# function headings, a return type that pas_arrtype_isdyn names registers the function name as a dynamic array (pas_array_add,
# pas_array_mark_dyn), as a variable of that type is. Rides with the bare-name-is-the-result reading of the FPC dialects.
#
# ARMS: dynresult against fpc -Mobjfpc, both modes, cut LIVE. MEASURED on the parent (in-tree swap): red. FAIL_ONCE=1 corrupts it.
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
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { local mode="$2"; mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" $mode -v0 -FE"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc $mode would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/dynresult.pas" <<'PAS'
program dynresult;
{$mode objfpc}
type FArray = array of cardinal; SArray = array of string;
function freq(n: integer): FArray;
var u: integer;
begin
  SetLength(freq, n + 1);
  for u := 1 to n do begin INC(freq[u]); INC(freq[u], u) end;
  freq[0] := Length(freq) * 10 + High(freq)
end;
function words(n: integer): SArray;
var k: integer;
begin
  SetLength(Result, n);
  for k := 0 to High(Result) do Result[k] := StringOfChar('w', k + 1)
end;
var pf: FArray; ws: SArray; i: integer;
begin
  pf := freq(3);
  for i := 0 to 3 do write(pf[i], ' ');
  writeln(length(pf));
  ws := words(3); for i := 0 to High(ws) do write(ws[i], '/'); writeln(Length(ws))
end.
PAS
for pm in "dynresult -Mobjfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a function returning a dynamic array holds an array in its result, as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined one program in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
