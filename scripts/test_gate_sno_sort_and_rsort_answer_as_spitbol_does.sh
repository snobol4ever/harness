#!/usr/bin/env bash
# test_gate_sno_sort_and_rsort_answer_as_spitbol_does.sh -- SORT(A [,C]) and RSORT(A [,C]) answer as SPITBOL answers them, in both
# modes: a vector sorts by value (or by the DATA field C names), a two-dimensional array and a table's key/value array sort their
# ROWS by column C (default the second dimension's lower bound) and keep their shape; RSORT sorts descending; ties keep their input
# order in both directions (SPITBOL's sortc breaks a tie on the row offset, so its heapsort answers as a stable sort would); an
# integer and a real compare numerically, a string never converts to a number; and the errors: 256 when A is not an array or table
# or has more than two dimensions, 257 when a vector's C cannot be a name, 258 when C is not an integer in the second dimension's range.
#
# ⛔ THE DEFECT: _SORT_/_RSORT_ were registered with max_args 1 and passed only A -- the column never arrived; any non-array A came
# back unchanged (no 256), so csnobol4_suite tab.sno went on to a wrong error 235 two lines later where sbl stops with 256 at line 18
# statement 14; a two-dimensional array was sorted as a flat list of its rows' first cells; RSORT reversed the ascending order, so
# its ties came out reversed. The one oracle's sort is sorta/sortc/sorth in sbl.min (read in the spitbol-pristine drop).
# NO MONITOR BRACKET: the divergence is inside one builtin call; the program stops at it.
# RE-CUT (CEO-1663): corpus a9f30db68 spelled tab.sno's CONVERT(words,"array") as "ARRAY" (Lon, CEO-1456); under -bf the lower-case
# name failed the CONVERT and RSORT met a null, which was the 256. sbl -bf now runs tab.sno whole (rc 0, 277 lines), so arms 3-4 grade
# its whole stdout: RSORT of the CONVERTed table's rows by column 2 with ties in input order, then SORT of the table by column 1.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4: the SORT/RSORT matrix -- 31 programs, stdout and error code                                  -- RED on base
#   3-4  m3 / m4: csnobol4_suite tab.sno on its post-END input prints sbl's whole stdout                     -- RED on base
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no csnobol4_suite).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
PKG="$S4E/corpus/packages/snobol4/csnobol4_suite"
NAME=sno_sort_and_rsort_answer_as_spitbol_does
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
[ -f "$PKG/tab.sno" ] || refuse "no csnobol4_suite tab.sno under $PKG -- pull corpus"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
SETUP="V = ARRAY(5); V[1] = 'b'; V[2] = 3; V[3] = 'a'; V[4] = 10; V[5] = 'B'; M = ARRAY('4,2'); M[1,1] = 'x'; M[1,2] = 2; M[2,1] = 'y'; M[2,2] = 1; M[3,1] = 'w'; M[3,2] = 2; M[4,1] = 'v'; M[4,2] = 1; T = TABLE(); T['q'] = 2; T['p'] = 1; T['r'] = 2; T['s'] = 1"
SHOW="OUTPUT = DATATYPE(X) ' ' PROTOTYPE(X); IDENT(PROTOTYPE(X), 5) :F(TWO); I = 0; L1 I = I + 1; OUTPUT = X[I] :S(L1)F(END); TWO I = 0; L2 I = I + 1; OUTPUT = X[I,1] ',' X[I,2] :S(L2)"
CASES=()
for e in "SORT(V)" "RSORT(V)" "SORT(M)" "SORT(M,2)" "RSORT(M,2)" "RSORT(M)" "SORT(T)" "SORT(T,2)" "RSORT(T,2)" "RSORT(T)"; do CASES+=("$SETUP; X = $e; $SHOW"); done
CASES+=(
"M = ARRAY('-1:1,0:1'); M[-1,0] = 'b'; M[-1,1] = 9; M[0,0] = 'a'; M[0,1] = 8; M[1,0] = 'c'; M[1,1] = 7; X = SORT(M,1); OUTPUT = PROTOTYPE(X) ' ' X[-1,0] X[-1,1] ' ' X[0,0] X[0,1] ' ' X[1,0] X[1,1]"
"M = ARRAY('-1:1,0:1'); M[-1,0] = 'b'; M[-1,1] = 9; M[0,0] = 'a'; M[0,1] = 8; M[1,0] = 'c'; M[1,1] = 7; X = SORT(M); OUTPUT = X[-1,0] X[0,0] X[1,0]"
"M = ARRAY('-1:1,0:1'); X = SORT(M,2)"
"M = ARRAY('3,2'); M[1,2] = 3; M[2,2] = 1; M[3,2] = 2; X = SORT(M,2.0); OUTPUT = X[1,2] X[2,2] X[3,2]"
"M = ARRAY('3,2'); M[1,2] = 3; M[2,2] = 1; M[3,2] = 2; X = SORT(M,'2'); OUTPUT = X[1,2] X[2,2] X[3,2]"
"&ERRLIMIT = 1; X = SORT(5) :S(Y)F(N); Y OUTPUT = 'succ' :(END); N OUTPUT = 'fail ' &ERRTYPE"
"&ERRLIMIT = 1; M = ARRAY('2,2'); X = SORT(M,9) :S(Y)F(N); Y OUTPUT = 'succ' :(END); N OUTPUT = 'fail ' &ERRTYPE"
"T = TABLE(); T['b'] = 2; T['a'] = 1; A = CONVERT(T,'ARRAY'); X = SORT(A,2); OUTPUT = X[1,1] X[2,1] ' ' A[1,1] A[2,1]"
"T = TABLE(); T['b'] = 2; T['a'] = 1; A = CONVERT(T,'ARRAY'); X = SORT(A); X[1,1] = 'z'; OUTPUT = A[1,1] A[2,1] ' ' X[1,1]"
"M = ARRAY('2,2'); M[1,1] = 'b'; M[2,1] = 'a'; X = SORT(M); X[1,1] = 'z'; OUTPUT = M[1,1] M[2,1] ' ' X[1,1] X[2,1]"
"T = TABLE(); T['b'] = 2; T['a'] = ''; T['c'] = 0; X = SORT(T); OUTPUT = PROTOTYPE(X) ' ' X[1,1] X[2,1]"
"T = TABLE(); T['b'] = ''; X = SORT(T) :S(Y)F(N); Y OUTPUT = 'succ' :(END); N OUTPUT = 'fail'"
"DATA('PT(PX,PY)'); V = ARRAY(3); V[1] = PT(3,'c'); V[2] = PT(1,'a'); V[3] = PT(2,'b'); X = SORT(V,'PX'); OUTPUT = PY(X[1]) PY(X[2]) PY(X[3])"
"DATA('PT(PX,PY)'); V = ARRAY(3); V[1] = PT(3,'c'); V[2] = PT(1,'a'); V[3] = PT(2,'b'); X = RSORT(V,'PY'); OUTPUT = PX(X[1]) PX(X[2]) PX(X[3])"
"V = ARRAY(4); V[1] = 2.5; V[2] = 2; V[3] = '10'; V[4] = 3; X = SORT(V); OUTPUT = X[1] ',' X[2] ',' X[3] ',' X[4]"
"V = ARRAY(4); V[1] = 'b'; V[2] = 3; V[3] = 'a'; V[4] = 1.5; X = SORT(V); OUTPUT = X[1] ',' X[2] ',' X[3] ',' X[4]"
"V = ARRAY(3); V[1] = 'x'; V[2] = 2.0; V[3] = 2; X = SORT(V); OUTPUT = X[1] ' ' DATATYPE(X[1]) ',' X[2] ',' X[3]"
"V = ARRAY(3); V[1] = 'b'; V[2] = 'a'; V[3] = 'b'; X = RSORT(V); OUTPUT = X[1] X[2] X[3]"
"V = ARRAY('0:2'); V[0] = 'c'; V[1] = 'a'; V[2] = 'b'; X = SORT(V); OUTPUT = PROTOTYPE(X) ' ' X[0] X[1] X[2]"
"V = ARRAY(2); X = SORT(V, ARRAY(1))"
"M = ARRAY('2,2,2'); X = SORT(M)"
)
python3 - "$T" "${CASES[@]}" <<'EOF' || refuse "could not write the case programs"
import re, sys
d = sys.argv[1]
for n, line in enumerate(sys.argv[2:]):
    out = []
    for st in line.split("; "):
        m = re.match(r"^([A-Z][A-Z0-9]*) (OUTPUT .*|I = .*)$", st)
        out.append((m.group(1).ljust(8) + m.group(2)) if m else ("        " + st))
    open(f"{d}/c{n}.sno", "w").write("\n".join(out) + "\nEND\n")
EOF
norm() { grep -vE '^\s*$|^in (file|line|statement)|^stmts|^exec|^REGEN|^memory|^  at ' | sed -E 's/^.*ERROR ([0-9]+) --.*$/error=\1/; s/^scrip: error ([0-9]+):.*$/error=\1/'; }
for i in "${!CASES[@]}"; do
    ( cd "$T" && timeout -k 5 20 "$SBL" -bf "c$i.sno" < /dev/null 2>/dev/null | norm > "c$i.oracle" )
done
grep -qx 'error=256' "$T/c30.oracle" && grep -qx 'error=258' "$T/c12.oracle" && grep -qx 'fail 256' "$T/c15.oracle" || refuse "the oracle's SORT answers moved: [$(tr '\n' '|' < "$T/c30.oracle")] [$(tr '\n' '|' < "$T/c12.oracle")]"
mkdir "$T/tab" && cp "$PKG/tab.sno" "$T/tab/" && sed -n '/^END/,$p' "$PKG/tab.sno" | tail -n +2 > "$T/tab/tab.in" || refuse "could not stage tab.sno"
( cd "$T/tab" && timeout -k 5 20 "$SBL" -bf tab.sno < tab.in > sbl.out 2>/dev/null ); TAB_RC=$?
TAB_WANT="rc=$TAB_RC|$(head -1 "$T/tab/sbl.out")|$(wc -l < "$T/tab/sbl.out")|$(grep -c 'ERROR' "$T/tab/sbl.out")|$(sed -n 2p "$T/tab/sbl.out" | tr -s ' ')"
[ "$TAB_WANT" = "rc=0|total words: 271|277|0|13 that" ] || refuse "the oracle's tab.sno answer moved: [$TAB_WANT]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
run() { ( cd "$1" && if [ "$3" = m3 ]; then timeout -k 5 20 "$SCRIP" "$2.sno"; else timeout -k 5 30 "$SCRIP" --compile --out="$2.s" "$2.sno" < /dev/null > /dev/null 2>&1 && gcc "$2.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$2.bin" > /dev/null 2>&1 && timeout -k 5 20 "./$2.bin"; fi ) 2>&1; }
matrix() { local bad=""
    for i in "${!CASES[@]}"; do
        run "$T" "c$i" "$1" < /dev/null | norm > "$T/c$i.$1"
        cmp -s "$T/c$i.$1" "$T/c$i.oracle" || bad="$bad c$i got [$(tr '\n' '|' < "$T/c$i.$1")] want [$(tr '\n' '|' < "$T/c$i.oracle")];"
    done; [ -z "$bad" ] && echo ok || echo "$bad"; }
tab() { run "$T/tab" tab "$1" < "$T/tab/tab.in" > "$T/tab/$1.out"
    cmp -s "$T/tab/$1.out" "$T/tab/sbl.out" && echo ok || echo "stdout differs from sbl's: $(diff "$T/tab/sbl.out" "$T/tab/$1.out" | head -4 | tr '\n' '|')"; }
arm "m3: the SORT/RSORT matrix (${#CASES[@]} programs), stdout and error code" "$(matrix m3)"
arm "m4: the SORT/RSORT matrix (${#CASES[@]} programs), stdout and error code" "$(matrix m4)"
arm "m3: csnobol4_suite tab.sno prints sbl's whole stdout" "$(tab m3)"
arm "m4: csnobol4_suite tab.sno prints sbl's whole stdout" "$(tab m4)"
[ "$fail" = 0 ] && { echo "GATE PASS [$NAME]: $n/$n arms"; exit 0; }
echo "GATE FAIL [$NAME]"; exit 1
