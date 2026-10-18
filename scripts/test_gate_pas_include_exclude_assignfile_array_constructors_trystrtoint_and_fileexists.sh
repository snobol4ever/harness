#!/usr/bin/env bash
# test_gate_pas_include_exclude_assignfile_array_constructors_trystrtoint_and_fileexists.sh -- in the FPC dialects: Include and Exclude on a
# set variable; AssignFile / CloseFile as Assign / Close; a bracket actual for an open-array parameter is an ARRAY (Sum([1,2,3]),
# Longest(['ab','abcd']), with string members); sysutils' TryStrToInt (decimal, signed, $hex, rejecting junk) and FileExists.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta's empty-output class (ceo CEO-1709): 8 probes against fpc, every one differing --
# include / exclude, assignfile, closefile, fileexists, trystrtoint died "error 22: undefined function called"; Sum([1,2,3]) read 0 and a
# string bracket stopped at the ISO 6.7.1 set-member check, because a [...] actual was always a SET. THE CURE (lower_pascal_tree.c):
# include / exclude lower to s := s +/- [e] when pas_dialect_fpc holds; assignfile / closefile re-enter mk_call as assign / close;
# E_call_with_args elaborates the actuals of a routine with open-array formals one by one, lets a bracket for an open-array formal skip
# the set-member ordinal check (pas_arrctor), and pas_setcons_elems flattens the nested __pas_setuni / __pas_set tree into the new runtime
# __pas_arrlit (a 0-based dynamic array); sysutils.pas gains TryStrToInt and FileExists (the runtime __pas_fileexists, a regular-file stat).
# OPEN, NOT GRADED HERE: GetMem / FreeMem / Move, FormatFloat, TryStrToFloat, DirectoryExists; Include / Exclude in an ISO program is not refused.
#
# ARMS: rtlbatch against fpc -Mobjfpc, both modes, cut LIVE. MEASURED on the parent (in-tree swap): red. FAIL_ONCE=1 corrupts it.
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
cat > "$T/rtlbatch.pas" <<'PAS'
program rtlbatch;
{$mode objfpc}
uses sysutils;
type s = set of 0..9;
var x: s; i, n: integer; f: text; l: string;
function Sum(const a: array of integer): integer;
var k: integer;
begin
  Sum := 0;
  for k := low(a) to high(a) do Sum := Sum + a[k]
end;
function Longest(const a: array of string): string;
var k: integer;
begin
  Longest := '';
  for k := 0 to high(a) do if length(a[k]) > length(Longest) then Longest := a[k]
end;
begin
  x := [1, 2]; include(x, 3); include(x, 7); exclude(x, 1); exclude(x, 9);
  for i := 0 to 9 do if i in x then write(i); writeln;
  writeln(Sum([1, 2, 3]), ' ', Sum([10]), ' ', Longest(['ab', 'abcd', 'c']));
  assignfile(f, '/tmp/pas_rtlbatch_gate.txt'); rewrite(f); writeln(f, 'line one'); writeln(f, 'two'); closefile(f);
  assign(f, '/tmp/pas_rtlbatch_gate.txt'); reset(f); readln(f, l); close(f); writeln(l);
  writeln(FileExists('/tmp/pas_rtlbatch_gate.txt'), ' ', FileExists('/nonexistent/q'));
  writeln(TryStrToInt('42', n), ' ', n, ' ', TryStrToInt('4x', n), ' ', TryStrToInt('-17', n), ' ', n)
end.
PAS
for pm in "rtlbatch -Mobjfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: Include / Exclude, AssignFile, array-constructor actuals, TryStrToInt and FileExists answer as fpc's do, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined one program in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
