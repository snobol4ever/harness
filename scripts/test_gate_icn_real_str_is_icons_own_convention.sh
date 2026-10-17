#!/usr/bin/env bash
# ../harness/scripts/test_gate_icn_real_str_is_icons_own_convention.sh -- row
# icon-jcon-class-real-str-icon-real-str-divergence (minted seat02 2026-09-04, cured seat05 SCRIP 19f5bfd9a,
# gated hq_I 2026-09-10).
#
# SCRIP has TWO real-to-string functions and THAT IS CORRECT, not a defect:
#   real_str()      src/runtime/string_ops.c -- SPITBOL's own full-precision convention, SNOBOL4's answer
#   icon_real_str() src/runtime/string_ops.c -- Icon's 10-significant-digit convention, iconx's answer
# The row was minted recommending "delete one function and repoint every caller", and that recommendation is
# WRONG: on the SAME literal 101559956668416.0 the sbl oracle prints `101559956668416.` and iconx prints
# `1.015599567e+14`. They are two correct answers for two languages. Merging them would have silently broken
# SNOBOL4's hard FAIL=0 bar, which is why this gate grades BOTH sides on that one literal -- a future seat who
# "unifies" the two functions trips arm B, not a board six minutes later.
#
# Arm A: Icon, 13 probes, refs cut from /home/resources/icon-master's own icont/iconx, both modes m3 and m4.
#   The probes are not decoration; each pins a constant that was re-derived empirically and that a plausible
#   rewrite gets wrong:
#     101559956668416.0     10 significant digits, and the exponent is SIGNED (`e+14`, never `e14`)
#     9999999999.6          rounding CARRIES into the exponent -> `1e+10`, not `9999999999.6`
#     99999.99999999        the carry lands the other way -> `100000.0`, fixed notation
#     1.0e10                one significant digit survives stripping, so NO decimal point at all -> `1e+10`
#     1.0e-5                the small-magnitude threshold, and a two-digit negative exponent -> `1e-05`
#     0.0001 / 1e100 / 1e-100 / 0.0 / -0.5 / 2.0   the fixed/exponential boundary in both directions
# Arm B: SNOBOL4, the same literal, ref cut from the sbl oracle -- the control arm that keeps the two apart.
#   REFUSES rc=2 if the sbl oracle is absent rather than passing on one arm and calling it a verdict.
#
# Usage: bash ../harness/scripts/test_gate_icn_real_str_is_icons_own_convention.sh
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
cd "$ROOT" || exit 2
SCRIP="$ROOT/scrip"; RT="$ROOT/out/libscrip_rt.so"
[ -x "$SCRIP" ] || { echo "REFUSE rc=2: $SCRIP missing -- build first (make)"; exit 2; }
[ -r "$RT" ]    || { echo "REFUSE rc=2: $RT missing -- build first (make)"; exit 2; }
ICONT=/home/resources/icon-master/bin/icont
SBL=/home/resources/x64/bin/sbl
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
bad=0; n=0
cat > "$W/p.icn" <<'EOF'
procedure main()
   write(101559956668416.0);
   write(-101559956668416.0);
   write(9999999999.6);
   write(99999.99999999);
   write(1.0e10);
   write(1.0e-5);
   write(0.0001);
   write(3.14159265358979);
   write(1.0e100);
   write(1.0e-100);
   write(0.0);
   write(-0.5);
   write(2.0);
end
EOF
cat > "$W/icn.ref" <<'EOF'
1.015599567e+14
-1.015599567e+14
1e+10
100000.0
1e+10
1e-05
0.0001
3.141592654
1e+100
1e-100
0.0
-0.5
2.0
EOF
if [ -x "$ICONT" ]; then
  ( cd "$W" && "$ICONT" -s -o p p.icn >/dev/null 2>&1 && ./p </dev/null >oracle.txt 2>&1 )
  if [ -s "$W/oracle.txt" ]; then
    if ! diff -q "$W/icn.ref" "$W/oracle.txt" >/dev/null; then
      echo "REFUSE rc=2: the pinned Icon refs no longer match this box's icont -- the oracle moved, re-cut the block above"
      diff "$W/icn.ref" "$W/oracle.txt" | head -8; exit 2
    fi
    echo "  ok   ARM 0: the pinned Icon refs are byte-identical to this box's own icont, so arms A1/A2 grade against the oracle and not against a memory of it"
  fi
fi
n=$((n+1))
"$SCRIP" --run "$W/p.icn" </dev/null > "$W/m3.out" 2>&1
if diff -q "$W/icn.ref" "$W/m3.out" >/dev/null; then echo "  ok   ARM A1 (m3): Icon real-to-string is iconx's 10-significant-digit convention, signed exponent, over 13 probes"
else bad=$((bad+1)); echo "  FAIL ARM A1 (m3): Icon real-to-string diverges from icont"; diff "$W/icn.ref" "$W/m3.out" | head -10; fi
n=$((n+1))
if "$SCRIP" --compile -o "$W/p.s" "$W/p.icn" </dev/null >/dev/null 2>&1 &&
   gcc -no-pie "$W/p.s" -o "$W/p.bin" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >/dev/null 2>&1; then
  "$W/p.bin" </dev/null > "$W/m4.out" 2>&1
  if diff -q "$W/icn.ref" "$W/m4.out" >/dev/null; then echo "  ok   ARM A2 (m4): the same 13 probes, byte-identical through the compiled arm"
  else bad=$((bad+1)); echo "  FAIL ARM A2 (m4): Icon real-to-string diverges from icont in mode 4"; diff "$W/icn.ref" "$W/m4.out" | head -10; fi
else echo "REFUSE rc=2: could not build the m4 arm -- a gate that cannot measure never prints the success shape"; exit 2; fi
[ -x "$SBL" ] || { echo "REFUSE rc=2: $SBL missing -- arm B is the whole point of this gate and cannot be skipped as success"; exit 2; }
n=$((n+1))
printf '\tX = 101559956668416.0\n\tOUTPUT = X\n\tY = 3.14159265358979\n\tOUTPUT = Y\nEND\n' > "$W/p.sno"
printf '101559956668416.\n3.14159265358979\n' > "$W/sno.ref"
"$SBL" -bf "$W/p.sno" </dev/null > "$W/sbl.out" 2>&1
if ! diff -q "$W/sno.ref" "$W/sbl.out" >/dev/null; then
  echo "REFUSE rc=2: the pinned SNOBOL4 ref no longer matches this box's sbl -- the oracle moved, re-cut it"
  diff "$W/sno.ref" "$W/sbl.out" | head -6; exit 2
fi
"$SCRIP" --run "$W/p.sno" </dev/null > "$W/sno.out" 2>&1
if diff -q "$W/sno.ref" "$W/sno.out" >/dev/null; then echo "  ok   ARM B: SNOBOL4 keeps SPITBOL's own full-precision convention on the SAME literal Icon prints as 1.015599567e+14 -- the two conventions are still two"
else bad=$((bad+1)); echo "  FAIL ARM B: SNOBOL4 real-to-string no longer matches sbl -- if this went red alongside arm A going green, the two functions were merged"; diff "$W/sno.ref" "$W/sno.out" | head -6; fi
echo "graded=$n bad=$bad"
[ "$bad" -eq 0 ] || { echo "GATE RED: $bad arm(s) failed [test_gate_icn_real_str_is_icons_own_convention]"; exit 1; }
echo "GATE GREEN: Icon and SNOBOL4 each print reals in their own oracle's convention [test_gate_icn_real_str_is_icons_own_convention]"
