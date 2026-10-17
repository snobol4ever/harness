#!/bin/bash
# Icon large integers, RUNG 2: the places a NEW TYPE has to be taught about, once arithmetic works.
# Row icon-bignum-rung-2-image-string-equality-table-keys-and-mixed-real-arithmetic.
#
# Measured 2026-09-06 against iconx on the tree where rungs 0 and 1 are green -- so each of these is a
# gap in a CONSUMER of the value, not in the arithmetic:
#   image(2^100)                        SCRIP prints the string "1267" (truncated, and quoted as a
#                                       STRING image); iconx prints integer(~10^30)
#   string(2^100) == "1267...376"       ⛔ THE FIRST VERSION OF THIS ARM MEASURED SOMEONE ELSE'S DEFECT.
#                                       Written inline it fails -- but so does `write("42" == "42")`, with no
#                                       large integer anywhere, and so does it on a tree built from before
#                                       any of today's changes (worktree control). Icon's string comparison
#                                       yields nothing unless an operand is a VARIABLE; that is a separate,
#                                       PRE-EXISTING defect with its own row and its own two-literal witness.
#                                       The arm now binds the string to a variable first, so what it grades
#                                       is the large integer's rendering rather than the comparison operator.
#   T[2^100] := "big"; T[2^100]         SCRIP's lookup misses; iconx finds it -- a large integer is not
#                                       yet hashable as a table key
#   2^100 + 1.5                         SCRIP returns an integer; iconx returns 1.2676506e+30, because
#                                       MIXED arithmetic promotes to REAL, not to a wider integer
#
# ⭐ THE CONTROL ARMS ARE RUNGS 0 AND 1 THEMSELVES: a plain big comparison and a big remainder are
# graded here too, so a rung-2 cure that reaches back into the arithmetic is caught by this gate rather
# than by the two gates it would also break.
# ⛔ REFUSES rc=2 unless all 12 runs (6 witnesses x 2 modes) are graded, and rc=2 if the oracle is absent.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
ICONT=/home/resources/icon-master/bin/icont; ICONX=/home/resources/icon-master/bin/iconx
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "⛔ GATE REFUSES (rc=2): scrip/runtime not built at $ROOT"; exit 2; }
[ -x "$ICONT" ] && [ -x "$ICONX" ] || { echo "⛔ GATE REFUSES (rc=2): Icon oracle missing at $ICONT / $ICONX"; exit 2; }
d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT
w() { printf 'procedure main()\n  %s\nend\n' "$2" > "$d/$1.icn"; }
w image_of      'write(image(2^100));'
w string_eq     's := string(2^100); write(s == "1267650600228229401496703205376");'
w table_key     'T := table(); T[2^100] := "big"; write(T[2^100]);'
w mixed_real    'write(2^100 + 1.5);'
w compare_ctl   'write(2^200 > 2^199);'
w mod_ctl       'write(2^100 % 7);'
graded=0; bad=0
for t in image_of string_eq table_key mixed_real compare_ctl mod_ctl; do
    "$ICONT" -s -o "$d/$t.ora" "$d/$t.icn" >/dev/null 2>&1 || { echo "⛔ GATE REFUSES (rc=2): icont rejected $t -- cannot measure"; exit 2; }
    want=$(timeout -k 5 20 "$ICONX" "$d/$t.ora" </dev/null 2>/dev/null); wrc=$?
    [ "$wrc" != 124 ] || { echo "⛔ GATE REFUSES (rc=2): the ORACLE timed out on $t -- cannot measure"; exit 2; }
    o=$(timeout -k 5 20 ./scrip "$d/$t.icn" </dev/null 2>/dev/null); r=$?; graded=$((graded+1))
    if [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
        echo "  ⛔ RED m3 $t: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-46)] -- iconx rc=$wrc out=[$(printf '%s' "$want" | tr '\n' '|' | cut -c1-46)]"; bad=1
    fi
    if timeout -k 5 120 ./scrip --compile -o "$d/$t.s" "$d/$t.icn" </dev/null >/dev/null 2>&1 \
       && gcc -m64 -no-pie "$d/$t.s" -o "$d/$t.m4" -L./out -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null; then
        o=$(timeout -k 5 20 "$d/$t.m4" </dev/null 2>/dev/null); r=$?; graded=$((graded+1))
        if [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
            echo "  ⛔ RED m4 $t: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-46)] -- iconx rc=$wrc out=[$(printf '%s' "$want" | tr '\n' '|' | cut -c1-46)]"; bad=1
        fi
    else
        graded=$((graded+1)); echo "  ⛔ RED m4 $t: does not compile/link"; bad=1
    fi
done
[ "$graded" = 12 ] || { echo "⛔ GATE REFUSES (rc=2): graded $graded of the 12 required runs"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED [icn_bignum_rung2]: a consumer of the value -- image, string equality, table keys or mixed real arithmetic -- still does not know the type"; exit 1; }
echo "✅ GATE OK [icn_bignum_rung2]: image, string equality, table keys and mixed real arithmetic all know a large integer -- BOTH modes"
