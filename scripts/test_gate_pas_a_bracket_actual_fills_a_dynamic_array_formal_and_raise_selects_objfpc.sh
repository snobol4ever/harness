#!/usr/bin/env bash
# test_gate_pas_a_bracket_actual_fills_a_dynamic_array_formal_and_raise_selects_objfpc.sh -- (1) a [...] actual for a formal of a NAMED DYNAMIC-ARRAY type
# (TIntArray) is an array, not a set, with string members kept as strings (Joined(['a','bb'], '-')); (2) a statement-position raise, with no
# try and no {$mode} directive, selects the ObjFPC dialect as try does (fpc's default mode refuses raise; the ref was cut under -Mobjfpc).
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta (CEO-1562, CEO-1709): chinese-remainder-theorem (uses SysUtils, no {$mode}) stopped at
# "pascal parse error line 22" on  if (mod1 = 0) or (mod2 = 0) then raise SysUtils.Exception.Create(...)  because pascal_oo_keyword flipped on class
# and try only; once parsed it died "Arrays are empty" because SolveN([2,3,2], [3,5,7]) passed SETS to TIntArray formals (the open-array
# rewrite keyed on the $open$ mask only), and a one-character string member of an array of string became its character code.
# THE CURE: pascal.l treats a statement-position raise like try (k == 1 || k == 4); E_call_with_args elaborates the actuals of any routine with a known
# signature one by one and converts a bracket for an open-array OR dynamic-array-typed formal (pas_formal_is_dynarr); pas_formal_elem_is_string
# wraps character members in pas_concat_operand when the element type is a string. pascal.lex.c regenerated with the pinned flex 2.6.4.
# OPEN, NOT GRADED HERE: the dynamic-array constructor TIA.Create(1, 2).
#
# ARMS: dynctor and bareraise against fpc -Mobjfpc, both modes, cut LIVE. MEASURED on the parent (in-tree swap): both red. FAIL_ONCE=1 corrupts dynctor.
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
cat > "$T/dynctor.pas" <<'PAS'
program dynctor;
{$mode objfpc}
type TIA = array of integer; TSA = array of string;
function Total(const a: TIA): integer;
var i: integer;
begin Total := 0; for i := 0 to High(a) do Total := Total + a[i] end;
function Joined(a: TSA; sep: string): string;
var i: integer;
begin Joined := ''; for i := 0 to Length(a) - 1 do begin if i > 0 then Joined := Joined + sep; Joined := Joined + a[i] end end;
procedure Show(x, y: TIA);
begin writeln(Length(x), ' ', Length(y), ' ', x[0] + y[High(y)]) end;
var v: TIA;
begin
  writeln(Total([1, 2, 3, 4]), ' ', Total([]), ' ', Joined(['a', 'bb', 'ccc'], '-'));
  Show([5, 6, 7], [8, 9]);
  v := nil; writeln(Length(v))
end.
PAS
cat > "$T/bareraise.pas" <<'PAS'
program bareraise;
uses SysUtils;
type TIntArray = array of integer;
procedure Solve(const m1, m2: integer; out r: integer);
begin
  if (m1 = 0) or (m2 = 0) then
    raise SysUtils.Exception.Create('Solve: modulus cannot be 0');
  r := m1 * 10 + m2
end;
function Sum(const a: TIntArray): integer;
var i: integer;
begin
  if Length(a) = 0 then raise Exception.Create('Arrays are empty');
  Sum := 0;
  for i := 0 to High(a) do Sum := Sum + a[i]
end;
var r: integer;
begin
  Solve(3, 4, r); writeln(r, ' ', Sum([1, 2, 3, 4]));
  try Solve(0, 1, r) except on E: Exception do writeln('caught ', E.Message) end;
  try writeln(Sum([])) except on E: Exception do writeln('caught ', E.Message) end
end.
PAS
for pm in "dynctor -Mobjfpc" "bareraise -Mobjfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = dynctor ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a bracket fills a dynamic-array formal and a bare raise selects ObjFPC, as fpc reads them, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined two programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
