#!/usr/bin/env bash
# test_gate_pas_format_matches_fpc_sysutils.sh -- sysutils' Format(fmt, [args]) in the FPC dialects reads as fpc does: every conversion
# (d u x s f e g n p and %%), index (n:), left (-), width, precision and the * forms, real conversions through FloatToStrF's fixed,
# exponent, general and number shapes on the 80-bit path Format takes (the double widened exactly, 21 digits, FPC's round_digits with
# HALF_ROUNDUP and AGRESSIVE_ROUNDUP, FloatToStrF's leading-minus removal on a zero result); a user routine named format still wins.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta (CEO-1562, row pascal-every-suite-to-100-under-nonet-ceo-1266): 30 of the package's
# 206 non-passing programs call Format, which no prelude or runtime defined -- an integer-only bracket lowered as a set and died at run
# time with "error 22: undefined function called", a bracket holding a string or a real stopped at compile time with an ISO 7185 6.7.1
# set-constructor violation. THE CURE: lower_pascal_tree.c's pas_format_call lowers Format(fmt, [e1..eN]) -- no user format in scope,
# a bracket of plain expressions -- to __pas_format(fmt, e1..eN), char members wrapped as strings; by_name_dispatch.c's pas_format ports
# FPC 3.2.2's sysformt.inc loop and FloatToStrFIntl (rtl/objpas/sysutils), its digits glibc's correctly rounded %.20e of the double and
# its rounding flt_core.inc's round_digits / try_return_fixed / return_exponential. Errors print EConvertError and exit 217 as fpc does.
#
# ARMS: three programs, both modes, stdout and exit code cut LIVE from fpc -Mobjfpc: fmtall (every conversion and shape), fmtown (a
# user function format taking a set: the user's routine is called), fmtexpr (Format in a concatenated format, nested in an argument, as a
# function result, over computed reals). OPEN, NOT GRADED HERE: a real LITERAL fpc types as 80-bit Extended (Format('%.1f', [0.15])
# reads 0.2 in fpc, 0.1 for a double variable holding 0.15) -- SCRIP has no Extended; writeln(x:w:d) of a double rounds the exact binary
# value where fpc rounds Grisu's 17 digits (0.15:0:1 reads 0.1 here, 0.2 in fpc) -- a row of its own.
# MEASURED on the parent 3f01913e2 (a worktree build): fmtall and fmtexpr red in both modes (the 6.7.1 refusal; an integer-only bracket
# dies with error 22 instead); fmtown green on both -- the guard the cure must keep. FAIL_ONCE=1 corrupts fmtall's expectation.
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
fpcrun() { mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" -Mobjfpc -v0 -FE"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Mobjfpc would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/fmtall.pas" <<'PAS'
program fmtall;
{$mode objfpc}
uses sysutils;
var i: integer; r, z, b: real; s: string; c: char; q: int64;
begin
  i := -42; r := 2.5; z := 0.000123456; b := 123456789.125; s := 'hello'; c := 'Z'; q := 12345678901;
  writeln(Format('[%d][%6d][%-6d][%.5d][%8.5d][%u][%x][%8x][%.4x]', [i, i, i, i, i, 7, 255, 4095, 10]));
  writeln(Format('[%s][%8s][%-8s][%.3s][%s][%d]', [s, s, s, s, c, q]));
  writeln(Format('[%f][%.0f][%.3f][%10.4f][%-10.1f][%f][%.2f]', [r, r, z, b, r, z, -r]));
  writeln(Format('[%e][%.3e][%12.4e][%e]', [r, b, z, -r]));
  writeln(Format('[%g][%.3g][%g][%g][%g]', [r, b, z, b, 100.0]));
  writeln(Format('[%n][%.1n][%n]', [b, b, r]));
  writeln(Format('[%*d][%-*d][%.*f][%%]', [5, 3, 4, 7, 2, r]), Format('[%1:s %0:s %s]', ['a', 'b']));
  writeln(Format('%d%s', [1, 'x']), Format('none', []));
  r := 0.05; z := 0.15; b := 0.715; writeln(Format('[%d][%f]', [0, 0.0]), Format('[%.1f][%.1f][%.2f][%.0f][%.0f][%.2f]', [r, z, b, 0.5, 1.5, -0.001]));
end.
PAS
cat > "$T/fmtown.pas" <<'PAS'
program fmtown;
{$mode objfpc}
type tset = set of 0..9;
function format(k: integer; t: tset): integer;
var j, n: integer;
begin
  n := 0; for j := 0 to 9 do if j in t then n := n + j; format := n * k
end;
begin
  writeln(format(2, [1, 3, 5]), ' ', format(1, []))
end.
PAS
cat > "$T/fmtexpr.pas" <<'PAS'
program fmtexpr;
{$mode objfpc}
uses sysutils;
var a: array [1..4] of integer; i: integer; sep, acc: string; x: real;
function Pair(k: integer; v: real): string;
begin
  Pair := Format('%s=%.3f', [IntToStr(k), v])
end;
begin
  for i := 1 to 4 do a[i] := i * i * 7;
  acc := ''; sep := '';
  for i := 1 to 4 do begin acc := acc + Format(sep + '%d', [a[i]]); sep := ',' end;
  writeln(acc);
  writeln(Format('<%s>', [Format('%5.2f|%-4d|', [a[2] / 3, a[1]])]), ' ', Length(Format('%10s', ['ab'])));
  x := 1.0; for i := 1 to 3 do begin x := x / 7; writeln(Pair(i, x), ' ', Format('%.12e', [x]), ' ', Format('%g', [x])) end
end.
PAS
for p in fmtall fmtown fmtexpr; do
  frc=$(fpcrun $p) || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = fmtall ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Mobjfpc ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: Format reads as fpc -Mobjfpc's sysutils does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined three programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
