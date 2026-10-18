#!/usr/bin/env bash
# test_gate_pas_dynamic_array_fields_of_records_and_classes_and_a_methods_own_name.sh -- a field declared `array of X` (or an alias of one,
# nested to any depth) in a record or class: SetLength on the field or on an element of it, Length, High, Low and indexed reads and writes act
# on a real dynamic array; and inside a function method the bare method name reads its result variable in the FPC dialects.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta (CEO-1562, CEO-1709; the 12 programs of the empty-output class that use the classes unit
# need a TStringList whose storage is a dynamic-array field): SetLength(FItems, n) on a field took the STRING SetLength (n spaces) and
# stored it back; Length(FItems) read 1 or the string length; High(FItems) was an undefined call; an `array of string` field read back
# character codes ("44/44 52/52" for TWO/three); and a method `Total` whose body read `Total` recursed to a stack overflow (fpc reads the
# result). THE CURE: (1) E_record_field computes the field's dynamic depth from its type tree and pas_pend_add records the field's type
# name as "$dyn<depth>$<element>" (pas_pend_dyn leaked between fields, so the tree is the authority); (2) pas_dyn_depth answers the
# remaining depth of a variable, a field select or an element of a deeper array, and SetLength of any non-variable target of depth > 0
# lowers to __pas_dynset with the element prototype; (3) Length, High and Low of an element-select argument lower to the Pascal-only
# __pas_len and __pas_bound, which read the array block's own bounds (or the string length); (4) lower_pascal_class.c keeps a function
# method's own bare name a plain identifier so mk_ident maps it to the result, and mk_ident maps the mangled method name.
# OPEN, NOT GRADED HERE: a record with a STATIC-array field breaks as soon as any class is declared (6.5.3.2; the parent too); the delphi
# dialect reads a bare function name as a call and SCRIP's switch cannot tell delphi from fpc.
#
# ARMS: dynfields (record and class fields of integer, string, nested and alias element types), methresult (Total := Total + ...; Twice :=
# Total * 2) and classbag (an indexed default property over a dynamic-array field, Add/Delete/Clear/Count), each against fpc -Mobjfpc, both
# modes, cut LIVE. MEASURED on the parent (in-tree swap): all red. FAIL_ONCE=1 corrupts dynfields.
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
cat > "$T/dynfields.pas" <<'PAS'
program dynfields;
{$mode objfpc}
type
  TIA = array of integer;
  TRec = record n: integer; a: array of integer; s: string; w: array of string; end;
  TBag = class
    cnt: integer;
    items: array of string;
    grid: array of array of integer;
    ids: TIA;
    name: string;
    procedure Fill(k: integer);
    function Total: integer;
  end;
procedure TBag.Fill(k: integer);
var i, j: integer;
begin
  SetLength(items, k); SetLength(ids, k); SetLength(grid, k);
  for i := 0 to High(items) do
  begin
    items[i] := StringOfChar(chr(ord('a') + i), i + 1);
    ids[i] := (i + 1) * 10;
    SetLength(grid[i], i + 1);
    for j := 0 to High(grid[i]) do grid[i][j] := i * 10 + j
  end;
  cnt := Length(items); name := 'bag'
end;
function TBag.Total: integer;
var i, j: integer;
begin
  Total := 0;
  for i := Low(ids) to High(ids) do Total := Total + ids[i];
  for i := 0 to Length(grid) - 1 do for j := 0 to Length(grid[i]) - 1 do Total := Total + grid[i][j]
end;
var r: TRec; b: TBag; i: integer;
begin
  r.n := 1; SetLength(r.a, 4); SetLength(r.w, 2); r.s := 'str';
  for i := 0 to High(r.a) do r.a[i] := i * i;
  r.w[0] := 'p'; r.w[1] := 'qq';
  writeln(Length(r.a), ' ', High(r.a), ' ', Low(r.a), ' ', r.a[3], ' ', Length(r.w), ' ', r.w[1], ' ', Length(r.s), ' ', r.s);
  b := TBag.Create; b.Fill(4);
  writeln(b.cnt, ' ', Length(b.items), ' ', b.items[3], ' ', High(b.ids), ' ', b.ids[2], ' ', Length(b.grid[3]), ' ', b.grid[3][2], ' ', b.Total, ' ', Length(b.name));
  SetLength(b.items, 2); SetLength(b.ids, 0);
  writeln(Length(b.items), ' ', b.items[1], ' ', Length(b.ids), ' ', High(b.ids));
  b.Free
end.
PAS
cat > "$T/methresult.pas" <<'PAS'
program methresult;
{$mode objfpc}
type TB = class
  x: integer;
  function Total: integer;
  function Twice: integer;
end;
function TB.Total: integer;
var i: integer;
begin
  Total := 0;
  for i := 1 to 3 do Total := Total + i * x
end;
function TB.Twice: integer;
begin
  Twice := Total * 2
end;
var b: TB;
begin b := TB.Create; b.x := 2; writeln(b.Total, ' ', b.Twice) end.
PAS
cat > "$T/classbag.pas" <<'PAS'
program classbag;
{$mode objfpc}
type
  TBag = class
  private
    FItems: array of string;
    FCount: integer;
    function GetItem(i: integer): string;
    procedure SetItem(i: integer; const v: string);
  public
    constructor Create;
    function Add(const s: string): integer;
    procedure Delete(i: integer);
    procedure Clear;
    property Count: integer read FCount;
    property Items[i: integer]: string read GetItem write SetItem; default;
  end;
constructor TBag.Create; begin FCount := 0; SetLength(FItems, 0) end;
function TBag.GetItem(i: integer): string; begin GetItem := FItems[i] end;
procedure TBag.SetItem(i: integer; const v: string); begin FItems[i] := v end;
function TBag.Add(const s: string): integer;
begin
  if FCount = Length(FItems) then SetLength(FItems, FCount * 2 + 4);
  FItems[FCount] := s; Add := FCount; FCount := FCount + 1
end;
procedure TBag.Delete(i: integer);
var k: integer;
begin
  for k := i to FCount - 2 do FItems[k] := FItems[k + 1];
  FCount := FCount - 1
end;
procedure TBag.Clear; begin FCount := 0 end;
var b: TBag; i: integer;
begin
  b := TBag.Create;
  b.Add('one'); b.Add('two'); b.Add('three');
  b[1] := 'TWO';
  b.Delete(0);
  for i := 0 to b.Count - 1 do write(b[i], '/', b.Items[i], ' ');
  writeln(b.Count);
  b.Clear; writeln(b.Count);
  b.Free
end.
PAS
for pm in "dynfields -Mobjfpc" "methresult -Mobjfpc" "classbag -Mobjfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = dynfields ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: dynamic-array fields and a method's own name act as fpc's do, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined three programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
