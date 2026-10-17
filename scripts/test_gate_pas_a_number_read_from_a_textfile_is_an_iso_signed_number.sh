#!/usr/bin/env bash
# test_gate_pas_a_number_read_from_a_textfile_is_an_iso_signed_number.sh -- ISO 7185 6.9.1: read skips spaces and end-of-lines, then an
# integer variable takes a signed-integer and a real variable a signed-number; anything else, and end-of-file, is an error
#
# MEASURED 2026-09-25 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. __pas_read_i and __pas_read_i_f read
# with fscanf(" %lld"): 'five' and end-of-file silently gave 0 (PAT iso7185prt1754 ran to rc 0), and there was NO real read at all --
# pascal.y sent a real variable through the integer arm, so 1.5 read as 1 and '10e' raised nothing (PAT 1756). NO BRACKET: an absent
# error sends no event, and the real-read defect is a missing routine. The cure: pas_read_number, one reader in by_name_dispatch.c for
# stdin and text files, and the parser routes a real variable to it with one extra argument (no new builtin name). fpc -Miso agrees on
# 'five', a bare sign, end-of-file and '10e' (runtime error 106); it is lenient on '10.', '.5' and '10e+', which are not signed-numbers
# under 6.9.1, and SCRIP follows ISO there.
#
# ARMS, both modes: (1) a program reading every valid form from stdin (integers over blank lines and signs, reals as 1.5, -2e3,
# +0.25E+02 and 7, an integer stopping at a letter, readln) cut LIVE from fpc -Miso and required byte-identical; (2) five faults --
# integer 'five', integer '+', integer at end-of-file, real '10e', real '10e+' ('10.' and '.5' left this list 2026-10-07: fpc -Miso reads them, CEO-1302, landing 39) -- each must print fpc's stdout
# up to the fault, exit non-zero and name 6.9.1. It FAILS on the parent. FAIL_ONCE=1 corrupts arm 1's ref to prove it can fail.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
build() { local p="$1"
  ( cd "$T" && "$FPC" -Miso -v0 -o"$p.fpc" $p.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $p"; exit 2; }
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) \
    || { echo "  ⛔ $p m4: did not compile or link"; RC=1; }; }
run() { local m="$1" p="$2" in="$3"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" <"$in" >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "./$p.m4" <"$in" >"$T/o" 2>"$T/e" ); return $?; }
cat > "$T/rn.pas" <<'PAS'
program rn(input, output);
var i, j, k: integer; r, s, t, u: real; c: char;
begin
  read(i, j, k); writeln(i, ' ', j, ' ', k);
  read(r, s, t, u); writeln(r:10:3, s:12:3, t:10:3, u:10:3);
  read(i, c); writeln(i, ' [', c, ']');
  readln; read(r); writeln(r:14:6);
  readln(i); writeln(i);
  read(j); writeln(j)
end.
PAS
printf '   12\n\n -34 +56\n 1.5 -2e3 +0.25E+02 7\n42x rest of line\n 3.14159e0\n -8\n\n   77\n' > "$T/rn.in"
printf 'program ri(input, output);\nvar i: integer;\nbegin\n  writeln(%s); read(i); writeln(%s, i)\nend.\n' "'before'" "'after '" > "$T/ri.pas"
printf 'program rr(input, output);\nvar r: real;\nbegin\n  writeln(%s); read(r); writeln(%s, r:8:3)\nend.\n' "'before'" "'after '" > "$T/rr.pas"
for p in rn ri rr; do build $p; done
( cd "$T" && timeout -k 5 20s ./rn.fpc <rn.in ) > "$T/rn.want" 2>/dev/null
[ -s "$T/rn.want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output for arm 1"; exit 2; }
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/rn.want"; fi
for m in m3 m4; do
  run $m rn "$T/rn.in"; rc=$?
  if [ "$rc" = 0 ] && cmp -s "$T/rn.want" "$T/o"; then echo "  arm 1 $m: every valid form reads byte-identical to fpc -Miso"
  else echo "  ⛔ arm 1 $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/rn.want")"; echo "      got : $(tr '\n' '|' < "$T/o")"; RC=1; fi
done
N=0
for f in 'ri: five' 'ri: +' 'ri:' 'rr: 10e ' 'rr: 10e+ '; do
  p=${f%%:*}; inp=${f#*:}; N=$((N+1)); printf '%s' "$inp" > "$T/f.in"
  ( cd "$T" && timeout -k 5 20s ./$p.fpc <f.in ) 2>/dev/null | grep -v '^after' > "$T/f.want"
  for m in m3 m4; do
    run $m $p "$T/f.in"; rc=$?
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 124 ] && cmp -s "$T/f.want" "$T/o" && grep -q 'ISO 7185 6\.9\.1' "$T/e"; then echo "  fault $p '$inp' $m: rc=$rc, stdout = fpc up to the fault, stderr names 6.9.1"
    else echo "  ⛔ fault $p '$inp' $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/f.want")"; echo "      got : $(tr '\n' '|' < "$T/o")"; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: numbers read as ISO 7185 6.9.1 signed-integers and signed-numbers, and $N malformed or missing ones stop with 6.9.1, both modes"
else echo "GATE FAIL(1) [$G]: examined 1 acceptance arm and $N fault arms in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
