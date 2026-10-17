#!/usr/bin/env bash
# test_gate_pas_a_functions_own_name_reads_its_result_in_the_fpc_dialects.sh -- in fpc's FPC and ObjFPC modes a function's own name
# used bare in an expression inside its body reads the result variable (Build += c, Acc *= 2, g := g + 10 in a parameterless g), and
# every compound assignment (+=, -=, *=, /=) lowers through the same operator rules as its long form (string + char concatenates, set
# union / difference / intersection, real division); in ISO the bare name stays a recursive call (b6 reads 130 4, as fpc -Miso).
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta's empty-output class (ceo CEO-1709): number-names and entropy died "BOMB --
# bb_call_proc_staged: a block-protocol callee is called with the wrong argument count": uniquechars += str[n] inside function
# uniquechars(str) read the bare name as a zero-argument recursive call. And E_assignment's compound desugar built a raw TT_ADD, so
# s += c with c a char summed codes (xyz read 363). fpc -Mfpc and -Mobjfpc read the bare name as the result (b6: 11 1), -Miso and
# -Mdelphi as a call (130 4; delphi refuses u := u * 2 with parameters but accepts u += x). THE CURE (lower_pascal_tree.c): mk_ident
# maps the current function's bare name to its result variable when pas_dialect_fpc holds; the compound desugar calls
# pas_arith_or_set / pas_rdiv. OPEN, NOT GRADED HERE: SCRIP's dialect switch does not tell delphi from fpc, so a delphi program that
# recurses through a bare parameterless name would read its result instead (no graded program is known to).
#
# ARMS: objcompound and objresult against fpc -Mobjfpc, isorecurse against fpc -Miso, both modes, cut LIVE. MEASURED on the parent
# (in-tree swap): objcompound and objresult red, isorecurse green (the guard). FAIL_ONCE=1 corrupts objcompound.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
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
cat > "$T/objcompound.pas" <<'PAS'
program objcompound;
{$mode objfpc}
type tset = set of 0..9;
var s: string; c: char; i: integer; r: real; t: tset; k: integer;
function Build(n: integer): string;
var j: integer;
begin
  Build := '';
  for j := 1 to n do Build += chr(ord('a') + j - 1);
  Build += '!'
end;
function Acc(n: integer): integer;
begin
  Acc := 0;
  while n > 0 do begin Acc += n; n -= 1 end;
  Acc *= 2
end;
begin
  s := 'ab'; c := 'z'; s += c; s += 'cd'; i := 5; i += 3; i -= 1; i *= 4; r := 10; r /= 4; r += 0.5;
  t := [1, 2]; t += [5]; t -= [1]; t *= [2, 5, 7];
  write(s, ' ', i, ' ', r:0:2, ' ');
  for k := 0 to 9 do if k in t then write(k);
  writeln(' ', Build(4), ' ', Acc(4))
end.
PAS
cat > "$T/objresult.pas" <<'PAS'
program objresult;
{$mode objfpc}
var k: integer;
function g: integer;
begin k := k + 1; if k > 3 then g := 100 else begin g := 1; g := g + 10 end end;
begin k := 0; writeln(g, ' ', k) end.
PAS
cat > "$T/isorecurse.pas" <<'PAS'
program isorecurse(output);
var k: integer;
function g: integer;
begin k := k + 1; if k > 3 then g := 100 else begin g := 1; g := g + 10 end end;
begin k := 0; writeln(g, ' ', k) end.
PAS
for pm in "objcompound -Mobjfpc" "objresult -Mobjfpc" "isorecurse -Miso"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = objcompound ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a function's own name reads its result in the FPC dialects and recurses in ISO, compound assignments as their long forms, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined three programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
