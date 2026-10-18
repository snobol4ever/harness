#!/usr/bin/env bash
# test_gate_pas_fpc_system_and_math_routines_answer_as_fpc_and_stay_refused_in_iso.sh -- FPC's System routines str, stringofchar, random
# and randomize, and the math unit's tan, arcsin, arccos, arctan2, log2, logn, hypot, sinh/cosh/tanh, degtorad, radtodeg and IntPower,
# each as fpc answers under its own mode -- and the System routines still refused in an ISO program (the dialects row
# pascal-dialects-...-ceo-1614, chunk 8).
#
# MEASURED 2026-10-11 by hq_pascal on SCRIP c88a51f9d: 17 graded PasRosetta programs died with "undefined function called". Their
# names were random/randomize (6), trimleft/trimright, format, formatfloat, max/min, stringofchar, str, power/IntPower, tan,
# arcsin, arccos, and the file routines.
# THE DIALECT: under CEO-1225 (ISO as oracle) an ISO program that names random is refused with 6.2.2.1. FPC's ISO_EXPECTED_REFUSALS.tsv
# lists test_units_system_trandom for exactly that. So the System routines exist only once the program is fpc or objfpc (a directive or a
# flip point). The math names are reachable only through uses math, which already flips.
# THE LOWERING: the math names map to __pas_mathf (libm: tan, asin, acos, atan2, log2, hypot, sinh, cosh, tanh, ...), unless the program
# defines the name. IntPower joins the math prelude unit. str(v[:w[:d]], s) is s := __pas_strf(v, w, d, dialect), formatted as write
# would. stringofchar is __pas_stringofchar. random and random(n) are __pas_random over libc random(); randomize is srandom of the clock
# and the pid. No runtime global is added.
# NOT COVERED: fpc's math functions return extended, which writes with 20 digits and a 4-digit exponent; SCRIP has no extended, so a
# bare write of one differs (formatted writes match). format, formatfloat and the file routines are not here.
#
# ARMS, both modes, expectations cut LIVE from fpc -Mfpc: sysrt and mathfns. Two ISO controls, each refused with no output:
#   - iso_random: a bare random, refused at compile time with 6.2.2.1, as ISO_EXPECTED_REFUSALS.tsv records for
#     test_units_system_trandom;
#   - iso_stringofchar: a call, refused at compile time with 6.2.2.1 since 2026-10-14 (hq_pascal, PasRosetta, ceo CEO-1709): mk_call reports the
#     identifier of random, randomize and stringofchar when the whole program is ISO and no routine of that name is declared -- until then it
#     was refused at run time as an undefined function ("an older gap this gate does not widen"). FAIL_ONCE=1 corrupts arm sysrt.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 60s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 60s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4 did not compile or link: $(head -1 "$T/e" | cut -c1-120)" >&2; return 99; }
  ( cd "$T" && timeout -k 5 60s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
want() { ( cd "$T" && "$FPC" -M$2 -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -M$2 would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 60s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $? > "$T/$1.wrc"; }
cat > "$T/sysrt.pas" <<'PAS'
{$mode fpc}
program rt1;
var s: string; i: integer;
begin str(42, s); writeln('[', s, ']'); str(7:5, s); writeln('[', s, ']'); str(3.14159:8:3, s); writeln('[', s, ']'); writeln(stringofchar('*', 5)); randomize; i := random(10); writeln((i >= 0) and (i < 10), ' ', random < 1.0) end.
PAS
cat > "$T/mathfns.pas" <<'PAS'
{$mode fpc}
program mt;
uses math;
begin
  writeln(tan(0.5):0:12, ' ', arcsin(0.5):0:12, ' ', arccos(0.5):0:12, ' ', arctan2(1.0, 2.0):0:12);
  writeln(log2(10.0):0:12, ' ', logn(3.0, 81.0):0:12, ' ', hypot(3.0, 4.0):0:6, ' ', sinh(1.0):0:12, ' ', cosh(1.0):0:12, ' ', tanh(0.5):0:12);
  writeln(intpower(2.0, 10):0:1, ' ', intpower(2.0, -2):0:4, ' ', power(2.0, 0.5):0:12, ' ', degtorad(180.0):0:12, ' ', radtodeg(pi):0:6);
end.
PAS
cat > "$T/iso_random.pas" <<'PAS'
program iso_random(output);
begin writeln(random < 1.0) end.
PAS
cat > "$T/iso_stringofchar.pas" <<'PAS'
program iso_stringofchar(output);
begin writeln(stringofchar('*', 3)) end.
PAS
RC=0; N=0
chk() { local m="$1" p="$2" frc; frc=$(cat "$T/$p.wrc"); run $m $p; local rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; }
want sysrt fpc; want mathfns fpc
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/sysrt.want"; fi
for m in m3 m4; do chk $m sysrt; chk $m mathfns; done
refuse() { local p="$1"; ( cd "$T" && timeout -k 5 60s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); local rc=$?; N=$((N + 1))
  if [ "$rc" != 0 ] && [ ! -s "$T/o" ] && grep -q "$2" "$T/e"; then echo "  $p: refused, rc=$rc, with: $(head -1 "$T/e" | cut -c1-80)"
  else echo "  ⛔ $p FAILED: rc=$rc, want a refusal naming [$2]: stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 140 "$T/e")]"; RC=1; fi; }
refuse iso_random '6\.2\.2\.1'; refuse iso_stringofchar '6\.2\.2\.1'
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: FPC's System and math routines answer as fpc and stay refused in ISO, $N of $N arms"
else echo "GATE FAIL(1) [$G]: see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
