#!/usr/bin/env bash
# test_gate_pas_under_overflow_checking_an_unsigned_sum_that_goes_negative_is_runtime_error_215.sh -- with {$Q+} (or {$OVERFLOWCHECKS ON}) a subtraction whose
# left operand is a SUM of unsigned variables (a byte, word, cardinal or non-negative subrange) that comes out negative stops with `Runtime error 215`,
# exit 215, as fpc does (it computes the sum in an unsigned 64-bit type); a difference of two unsigned variables, a signed expression and a non-negative
# result are unaffected.
#
# MEASURED 2026-10-04 by hq_pascal on FPC webtbs_tw37875 (want exit 215, read 0). {$Q+} was an unknown directive. The typing rule is MEASURED from
# fpc, not derived from the manual: a+b-8 over bytes or a 0..65535 subrange faults, a-b over the same variables is the signed -1.
#
# CURE: the {$Q} / {$OVERFLOWCHECKS} directives set bit 1 of g_pas_zerobased_strings (bit 0 stays ZeroBasedStrings; both save/restore through Push/Pop;
# a struct-less reuse of an already-granted global, on the cfo's word); pas_arith_or_set wraps such a subtraction in __pas_qchk, which prints and exits 215.
#
# ARMS, both modes, stdout and exit code cut LIVE from fpc: (neg) the tw37875 shape; (pos) a non-negative result runs on; (diff) a-b negative prints;
# (signed) longint operands never fault. FAIL_ONCE=1 corrupts the neg arm's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }

cat > "$T/neg.pas" <<'PAS'
{$MODE ISO}
{$Q+}
program neg(input, output);
type halfword = 0..65535;
var a, b: halfword;
begin
  a := 4095; b := 4096; writeln('go');
  if abs(int(a+b-8192)) < 4096 then halt(0) else halt(1)
end.
PAS
cat > "$T/pos.pas" <<'PAS'
{$MODE ISO}
{$Q+}
program pos(input, output);
var a, b: word;
begin
  a := 7; b := 9; writeln(a+b-3)
end.
PAS
cat > "$T/diff.pas" <<'PAS'
{$MODE ISO}
{$Q+}
program diff(input, output);
var a, b: byte;
begin
  a := 1; b := 2; writeln(a-b)
end.
PAS
cat > "$T/signed.pas" <<'PAS'
{$MODE ISO}
{$Q+}
program signed(input, output);
var a, b: longint;
begin
  a := 1; b := 2; writeln(a+b-8)
end.
PAS
for p in neg pos diff signed; do
  frc=$(fpcrun $p)
  if [ "$p" = neg ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: overflow checking of an unsigned sum behaves as fpc does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 4 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
