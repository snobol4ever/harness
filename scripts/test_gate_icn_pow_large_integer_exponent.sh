#!/bin/bash
# Icon '^' with an exponent NO WORD CAN HOLD. Row icon-jcon-lgint-large-integer-arithmetic-prints-every
# -digit-as-its-shipped-ref-oracle-cannot-finish (Lon 2026-09-10 "Get lgint and toby working.", CEO-491).
#
# THE DEFECT THIS PINS (measured 2026-09-10, hq_I, SCRIP 3bbdfc8c7): rt_big_arith_route returned
# FAILDESCR for EVERY x ^ v with v a large integer, so all sixteen of lgint's bigexp rows printed
# "error 204" -- and the 204 was not even raised, it was the STALE &errornumber left by an earlier
# real overflow. Three separate wrongs wearing one face: no error raised, the wrong number reported,
# and five exactly-computable answers (0^v, 1^v, -1^v, and |x|>=2 with v<0) refused.
#
# ⛔ WHY THIS GATE HAS TWO KINDS OF ARM, AND WHY THAT IS NOT A HEDGE.
# lgint cannot be graded against Arizona iconx as a whole: iconx does not reject a 20-digit exponent,
# so at "-2 ^ 36472996377170786403" it starts squaring bignums toward a ~10^19-bit result and never
# returns (600 s cap, 142 of 452 lines; ceo NOTE on the baton). That is UNBOUNDED, not slow. But the
# unboundedness is confined to |base| >= 2 with a POSITIVE huge exponent -- every other row answers
# instantly. So this gate does NOT fall back to the shipped ref wholesale; it grades against the live
# oracle everywhere the oracle can answer (ARM A, 14 rows) and leans on the CEO-491 jcon-provenance
# ruling ONLY for the four rows that provably cannot be measured (ARM B). Naming which rows are which
# is the point: "the oracle cannot finish this program" is true and would have licensed grading all
# eighteen off jcon, which would have imported jcon's divergences as if they were Icon's semantics.
#
# ARM A -- ORACLE-GRADED, LIVE (never hardcoded): bases -1, 0, 1 for all three v; bases -2, 2 for the
#   NEGATIVE v (bounded: the result truncates to 0); and the real base -1.0 for all three v. The real
#   row is the subtle one -- v = 36472996377170786403 is odd, but AS A DOUBLE it rounds to
#   36472996377170788352, which is EVEN, so C pow() on the converted exponent answers +1.0 where Icon
#   answers -1.0. The parity that governs is the parity of the INTEGER, and this arm is what holds
#   that, since a plausible "just call pow()" cure passes every other row here.
# ARM B -- JCON-PROVENANCE (CEO-491), the four unmeasurable rows: |base| >= 2 with a positive huge
#   exponent raises 203 (integer overflow), NOT 204 (real overflow). &errornumber is PRIMED to 204
#   first -- deliberately the very number the bug printed -- so a regression to "nothing was raised,
#   the stale &errornumber was reported" reads 204 here and goes RED. Without that priming this arm
#   would pass against the very bug it exists to catch. (The prime uses 0 ^ -1, whose 204 is oracle-
#   verified by test_gate_icn_pow_error_cases.sh. 1 / 0 CANNOT be used: SCRIP does not honour &error
#   for integer division by zero -- a separate open defect hq_I named to the ceo 2026-09-10.)
#
# ⛔ READ THE NUMBER, NEVER THE MESSAGE SHAPE (RULES.md THE INSTRUMENT LAWS, EIGHTEENTH BATCH,
# CEO-510): every arm compares a VALUE the program itself printed via &errornumber, so a change to the
# fatal-report format cannot turn this red while the semantics are right.
# ⛔ A GATE THAT CANNOT MEASURE REFUSES rc=2 -- all 36 runs (18 rows x 2 modes) must be graded.
# ⭐ NEGATIVE-TESTED AS A DISCRIMINATOR, not merely watched go green (CEO-510): the two source files
# were restored to their pre-cure content, the runtime rebuilt, and this gate run again -- rc=1, RED
# on BOTH arms in BOTH modes, with armB reading exactly "num=204" (the stale &errornumber) and armA
# missing all nine exact-value rows. Cured tree: rc=0. So it can fail, and it fails on the real bug.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT" || exit 2
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "⛔ GATE REFUSES (rc=2): scrip/runtime not built at $ROOT"; exit 2; }
ICONT=/home/resources/icon-master/bin/icont; ICONX=/home/resources/icon-master/bin/iconx
[ -x "$ICONT" ] && [ -x "$ICONX" ] || { echo "⛔ GATE REFUSES (rc=2): Icon oracle missing at $ICONT / $ICONX -- it is NOT on PATH, so command -v answers a narrower question than this gate is asking"; exit 2; }
. "$ROOT/../harness/scripts/lib_gate.sh" || { echo "⛔ GATE REFUSES (rc=2): ../harness/scripts/lib_gate.sh unreadable"; exit 2; }
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/armA.icn" <<'EOF'
procedure row(v);
   local x, y;
   write("v = ", v);
   every x := (-1 to 1) do write(x, " ^ v = ", (x ^ v) | ("num=" || &errornumber));
   if v < 0 then every x := (-2 | 2) do write(x, " ^ v = ", (x ^ v) | ("num=" || &errornumber));
   y := -1.0;
   write("-1.0 ^ v = ", (y ^ v) | ("num=" || &errornumber));
   return;
end
procedure main();
   &error := -1;
   every row(3 ^ 41 | 6 ^ 25 | -(7 ^ 23));
   &error := 0;
end
EOF
cat > "$d/armB.icn" <<'EOF'
procedure main();
   local v, x;
   &error := -1;
   write("prime=", (0 ^ (-1)) | ("prime=" || &errornumber));
   every v := (3 ^ 41 | 6 ^ 25) do
      every x := (-2 | 2) do write(x, " ^ v = ", (x ^ v) | ("num=" || &errornumber));
   &error := 0;
end
EOF
graded=0; bad=0
run_both() {
    w="$1"; want="$2"; wrc="$3"
    o=$(timeout -k 5 30 ./scrip "$d/$w.icn" </dev/null 2>/dev/null); r=$?; graded=$((graded+ROWS))
    if [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
        echo "  ⛔ RED m3 $w: rc=$r"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$o") | sed 's/^/      /'; bad=1
    fi
    if timeout -k 5 180 ./scrip --compile -o "$d/$w.s" "$d/$w.icn" </dev/null >/dev/null 2>&1 \
       && gcc -m64 -no-pie "$d/$w.s" -o "$d/$w.m4" -L./out -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null; then
        o=$(timeout -k 5 30 "$d/$w.m4" </dev/null 2>/dev/null); r=$?; graded=$((graded+ROWS))
        if [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
            echo "  ⛔ RED m4 $w: rc=$r"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$o") | sed 's/^/      /'; bad=1
        fi
    else
        graded=$((graded+ROWS)); echo "  ⛔ RED m4 $w: does not compile/link"; bad=1
    fi
}
"$ICONT" -s -o "$d/armA.ora" "$d/armA.icn" >/dev/null 2>&1 || { echo "⛔ GATE REFUSES (rc=2): icont rejected armA -- cannot measure"; exit 2; }
wantA=$(timeout -k 5 60 "$ICONX" "$d/armA.ora" </dev/null 2>/dev/null); wrcA=$?
[ "$wrcA" != 124 ] || { echo "⛔ GATE REFUSES (rc=2): the ORACLE timed out on armA -- the bounded rows are supposed to answer instantly, so this is a changed oracle, not a red"; exit 2; }
[ "$(printf '%s\n' "$wantA" | grep -c '\^ v = ')" = 14 ] || { echo "⛔ GATE REFUSES (rc=2): the oracle produced $(printf '%s\n' "$wantA" | grep -c '\^ v = ') of the 14 expected armA rows -- cannot measure"; exit 2; }
ROWS=14; run_both armA "$wantA" "$wrcA"
wantB='prime=prime=204
-2 ^ v = num=203
2 ^ v = num=203
-2 ^ v = num=203
2 ^ v = num=203'
ROWS=4; run_both armB "$wantB" 0
[ "$graded" = 36 ] || { echo "⛔ GATE REFUSES (rc=2): graded $graded of the 36 required runs"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED [icn_pow_large_integer_exponent]: Icon '^' with a large-integer exponent does not answer as the oracle does"; exit 1; }
echo "✅ GATE OK [icn_pow_large_integer_exponent]: 14 oracle-graded rows match iconx live and the 4 unmeasurable rows raise 203 (CEO-491 jcon provenance) -- BOTH modes"
