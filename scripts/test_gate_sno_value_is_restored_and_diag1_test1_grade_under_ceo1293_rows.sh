#!/usr/bin/env bash
# test_gate_sno_value_is_restored_and_diag1_test1_grade_under_ceo1293_rows.sh -- VALUE is a function again, and the two programs that call VALUE where sbl -bf traps error 22 grade green through CEO-1293 rows (CEO-1507, hq_snobol4).
#
# # ⛔ THE RULING. Lon, CEO-1293: "Keep the VALUE function we like new features." The deletion of VALUE at 1e16ef2d9 was the defect (CEO-1507); VALUE is restored alone, UCASE and LCASE stay deleted.
#   sbl -bf has no VALUE, so csnobol4_suite/diag1 (two VALUE('b') calls, source lines 175 and 181) and spitbol_testpgms/test1 (statement 137) trap error 22 in the oracle and run on in ours. CEO-1293's own CLASS
#   clause grades each such enhancement one named line at a time: diag1's four &ERRLIMIT / &ERRTEXT / &ERRTYPE / &STCOUNT lines and test1's &STCOUNT line (beside its five older rows) carry CEO-1293 rows in their package's ALL.mask.
#
# THE ARMS:
#   1-2  m3 / m4 VALUE('B') answers the variable's value, VALUE of an unset name answers the null string                                          -- RED on 1e16ef2d9 (error 22)
#   3-4  m3 / m4 diag1 under --stlimit, oracle and ours both masked by the package's real ALL.mask: byte-identical                                 -- RED with the rows gone (arm 5)
#   5    FAIL-ONCE diag1: the same grading with the diag1 rows filtered out of the mask is RED (the rows are what make it green)
#   6-7  m3 / m4 test1 under --stlimit, stdin testpgms.in, the oracle's stream masked --side=oracle, ours --side=scrip: byte-identical
#   8    FAIL-ONCE test1: the same with its &STCOUNT row filtered out is RED
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no corpus, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
CORPUS="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}/corpus"
NAME=sno_value_is_restored_and_diag1_test1_grade_under_ceo1293_rows
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
D1="$CORPUS/packages/snobol4/csnobol4_suite"; T1="$CORPUS/packages/snobol4/spitbol_testpgms"
for f in "$D1/diag1.sno" "$D1/ALL.mask" "$D1/ALL.ref" "$T1/test1.spt" "$T1/ALL.mask" "$T1/testpgms.in"; do [ -f "$f" ] || refuse "missing $f"; done
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
fail=0; pass=0
arm() { local n="$1" what="$2" ok="$3"
    if [ "$ok" = 1 ]; then pass=$((pass + 1)); echo "  arm $n PASS  $what"; else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; fi; }
cat > "$T/va.sno" <<'EOS'
        B = 'bee'
        OUTPUT = VALUE('B')
        OUTPUT = IDENT(VALUE('B'),B) 'same'
        OUTPUT = IDENT(VALUE('NOSUCH')) 'null'
END
EOS
printf 'bee\nsame\nnull\n' > "$T/va.want"
run_m3() { local src="$1" in="$2" out="$3"; shift 3; (cd "$T" && timeout -k 5 60 "$SCRIP" "$@" "$src" < "$in" > "$out" 2>/dev/null); }
run_m4() { local src="$1" in="$2" out="$3"; shift 3; local b="$out.bin"; : > "$out"
    if (cd "$T" && timeout -k 5 120 "$SCRIP" "$@" --compile -o "$out.s" "$src" < /dev/null > /dev/null 2>&1) && gcc -no-pie "$out.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$b" 2>/dev/null
    then (cd "$T" && timeout -k 5 60 "$b" < "$in" > "$out" 2>/dev/null); else echo COMPILE-FAILED > "$out"; fi; }
mask() { python3 "$HERE/util_apply_ceo409_mask.py" "$1" "$2" "$3.n" "--side=$4" < "$3" > "$3.masked" 2>/dev/null || refuse "the mask sidecar of $1 is refused"; }
run_m3 "$T/va.sno" /dev/null "$T/va.m3"; arm 1 "m3 VALUE answers the variable's value and the null string for an unset name" "$(cmp -s "$T/va.want" "$T/va.m3" && echo 1 || echo 0)"
run_m4 "$T/va.sno" /dev/null "$T/va.m4"; arm 2 "m4 VALUE: the same" "$(cmp -s "$T/va.want" "$T/va.m4" && echo 1 || echo 0)"
cp "$D1/diag1.sno" "$T/diag1.sno"; cp "$T1/test1.spt" "$T/test1.spt"
(cd "$T" && timeout -k 5 30 "$SBL" -bf diag1.sno < /dev/null > d1.o 2>/dev/null); grep -q 'number of errors detected  7' "$T/d1.o" || refuse "sbl -bf no longer detects diag1's 7 errors -- the oracle's answer moved"
(cd "$T" && timeout -k 5 60 "$SBL" -bf test1.spt < "$T1/testpgms.in" > t1.o 2>/dev/null); [ -s "$T/t1.o" ] || refuse "sbl -bf produced nothing for test1"
run_m3 diag1.sno /dev/null "$T/d1.m3" --stlimit; run_m4 diag1.sno /dev/null "$T/d1.m4" --stlimit
run_m3 test1.spt "$T1/testpgms.in" "$T/t1.m3" --stlimit; run_m4 test1.spt "$T1/testpgms.in" "$T/t1.m4" --stlimit
mkdir -p "$T/nod" "$T/not"; cp "$D1/ALL.ref" "$T/nod/"; grep -v '^diag1	' "$D1/ALL.mask" > "$T/nod/ALL.mask"
: > "$T/not/ALL.ref"; grep -v '^test1	^&STCOUNT' "$T1/ALL.mask" > "$T/not/ALL.mask"
[ "$(grep -c '^diag1	' "$D1/ALL.mask")" -ge 4 ] || refuse "diag1 has fewer than four rows in ALL.mask"
grep -q '^test1	^&STCOUNT' "$T1/ALL.mask" || refuse "test1 has no &STCOUNT row in ALL.mask"
mask "$D1/ALL.ref" diag1 "$T/d1.o" scrip; mask "$D1/ALL.ref" diag1 "$T/d1.m3" scrip; mask "$D1/ALL.ref" diag1 "$T/d1.m4" scrip
arm 3 "m3 diag1 graded under the real ALL.mask equals the oracle's stream" "$(cmp -s "$T/d1.o.masked" "$T/d1.m3.masked" && echo 1 || echo 0)"
arm 4 "m4 diag1: the same" "$(cmp -s "$T/d1.o.masked" "$T/d1.m4.masked" && echo 1 || echo 0)"
cp "$T/d1.o" "$T/e.o"; cp "$T/d1.m3" "$T/e.m3"; cp "$T/d1.m4" "$T/e.m4"
mask "$T/nod/ALL.ref" diag1 "$T/e.o" scrip; mask "$T/nod/ALL.ref" diag1 "$T/e.m3" scrip; mask "$T/nod/ALL.ref" diag1 "$T/e.m4" scrip
arm 5 "FAIL-ONCE diag1: without its CEO-1293 rows both modes are RED against the oracle" "$({ ! cmp -s "$T/e.o.masked" "$T/e.m3.masked" && ! cmp -s "$T/e.o.masked" "$T/e.m4.masked"; } && echo 1 || echo 0)"
mask "$T1/ALL.ref" test1 "$T/t1.o" oracle; mask "$T1/ALL.ref" test1 "$T/t1.m3" scrip; mask "$T1/ALL.ref" test1 "$T/t1.m4" scrip
arm 6 "m3 test1 graded under the real ALL.mask equals the oracle's stream (oracle --side=oracle, ours --side=scrip)" "$(cmp -s "$T/t1.o.masked" "$T/t1.m3.masked" && echo 1 || echo 0)"
arm 7 "m4 test1: the same" "$(cmp -s "$T/t1.o.masked" "$T/t1.m4.masked" && echo 1 || echo 0)"
cp "$T/t1.o" "$T/f.o"; cp "$T/t1.m3" "$T/f.m3"
mask "$T/not/ALL.ref" test1 "$T/f.o" oracle; mask "$T/not/ALL.ref" test1 "$T/f.m3" scrip
arm 8 "FAIL-ONCE test1: without its &STCOUNT row m3 is RED against the oracle" "$(cmp -s "$T/f.o.masked" "$T/f.m3.masked" && echo 0 || echo 1)"
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- VALUE is a function, diag1 and test1 grade green on their CEO-1293 rows and red without them"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1
