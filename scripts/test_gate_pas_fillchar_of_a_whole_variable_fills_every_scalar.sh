#!/usr/bin/env bash
# test_gate_pas_fillchar_of_a_whole_variable_fills_every_scalar.sh -- fillchar(x, SizeOf(x), v) over a whole variable of any shape (a
# 2-D array through a var parameter, a record with integer, real, char, Boolean and array fields, a Boolean array, a char array) sets
# every scalar inside it to v, as fpc's byte fill reads for the values programs use (0, #0, true, a char).
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta's empty-output class (ceo CEO-1709: 22 of its 141 empty-output programs call
# fillchar): the lowering handled only a 1-D array of known bounds; fillchar(S, Sizeof(S), #0) over a 2-D array type fell through
# to a by-name call and died "error 22: undefined function called" (triangular-numbers), and a record took the 1-D branch as an array
# of its fields and stopped at 6.5.3.2. THE CURE: when the count is SizeOf of the same variable (as a call, or the literal it folds
# to), the lowering emits __pas_fill(x, v); by_name_dispatch.c's pas_fill walks the aggregate in place -- nested arrays and records --
# setting each integer, char and Boolean to v, each real to v, and each string to '' for v = 0. A partial count keeps the old paths.
# OPEN, NOT GRADED HERE: fillchar(s[1], n, c) over a string's characters (additive-primes), and a nonzero fill of a multi-byte integer
# (fpc writes the byte pattern, 16843009 for 1 in a longint).
#
# ARMS: wholefill against fpc -Mobjfpc, both modes, cut LIVE. MEASURED on the parent (in-tree swap): red. FAIL_ONCE=1 corrupts it.
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
cat > "$T/wholefill.pas" <<'PAS'
program wholefill;
{$mode objfpc}
type
  tLine = array [0..4] of int64;
  tGrid = array [1..3] of tLine;
  tRec = record n: integer; r: real; c: char; b: boolean; a: array [1..3] of word end;
var g: tGrid; r: tRec; f: array [1..4] of boolean; i, j: integer; ch: array [1..5] of char;
procedure Clear(var s: tGrid); begin fillchar(s, sizeof(s), #0) end;
begin
  for i := 1 to 3 do for j := 0 to 4 do g[i][j] := i * 10 + j;
  Clear(g); writeln(g[2][3], ' ', g[3][4]);
  r.n := 5; r.r := 2.5; r.c := 'x'; r.b := true; r.a[2] := 9;
  fillchar(r, sizeof(r), 0); writeln(r.n, ' ', r.r:0:1, ' ', ord(r.c), ' ', r.b, ' ', r.a[2]);
  fillchar(f, sizeof(f), true); writeln(f[1], ' ', f[4]);
  fillchar(ch, sizeof(ch), '*'); for i := 1 to 5 do write(ch[i]); writeln
end.
PAS
for pm in "wholefill -Mobjfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: fillchar of a whole variable fills every scalar inside it as fpc reads it, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined one program in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
