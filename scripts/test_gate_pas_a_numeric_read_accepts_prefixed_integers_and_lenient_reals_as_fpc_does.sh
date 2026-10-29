#!/usr/bin/env bash
# test_gate_pas_a_numeric_read_accepts_prefixed_integers_and_lenient_reals_as_fpc_does.sh -- read(f, i) takes a hexadecimal ($ff, 0xff, xff),
# binary (%101) or octal (&17) integer, optionally signed, and read(f, r) takes a real written without digits before or after the point (.5, 5., -.25);
# an ordinary decimal numeral reads as before.
#
# MEASURED 2026-10-04 by hq_pascal on FPC test_tisoread (halt/err in iso mode: `the characters read do not form a signed-integer`): pas_read_number
# (by_name_dispatch.c) knew only decimal digits and a point that needed digits on both sides. fpc -Miso, the oracle, accepts the forms above.
#
# ARMS, both modes, expectations cut LIVE from fpc (each program writes its own text file, reads it back, prints what it read): (int) prefixed
# integers and their signs, with the digits of the next number following directly; (real) the lenient real forms and exponents; (dec) plain decimals,
# signs and blanks, unchanged. FAIL_ONCE=1 corrupts the int arm's ref.
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
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }

cat > "$T/int.pas" <<'PAS'
{$mode iso}
program int(output);
var f: text; a, b, c, d, e, g: integer;
begin
  assign(f, 'gi.tmp'); rewrite(f);
  writeln(f, '$ff 0x1F xAB %1011 &777 -$10');
  writeln(f, '+0x20 0X7f');
  close(f); reset(f);
  read(f, a, b, c, d, e, g); writeln(a, ' ', b, ' ', c, ' ', d, ' ', e, ' ', g);
  read(f, a, b); writeln(a, ' ', b);
  close(f); erase(f)
end.
PAS
cat > "$T/real.pas" <<'PAS'
{$mode iso}
program rdr(output);
var f: text; r, s, t, u: real;
begin
  assign(f, 'gr.tmp'); rewrite(f);
  writeln(f, '+123. -.125 .5 7.');
  writeln(f, '1e2 +1e-2');
  close(f); reset(f);
  read(f, r, s, t, u); writeln(round(r), ' ', round(s * 1000), ' ', round(t * 10), ' ', round(u));
  read(f, r, s); writeln(round(r), ' ', trunc(s * 100));
  close(f); erase(f)
end.
PAS
cat > "$T/dec.pas" <<'PAS'
{$mode iso}
program dec(output);
var f: text; a, b, c: integer; r: real;
begin
  assign(f, 'gd.tmp'); rewrite(f);
  writeln(f, '   12  -34 +56 ');
  writeln(f, '0 007 1.5');
  close(f); reset(f);
  read(f, a, b, c); writeln(a, ' ', b, ' ', c);
  read(f, a, b); writeln(a, ' ', b);
  read(f, r); writeln(round(r * 10));
  close(f); erase(f)
end.
PAS
for p in int real dec; do
  frc=$(fpcrun $p)
  if [ "$p" = int ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a numeric read accepts the prefixed and lenient forms as fpc does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
