#!/usr/bin/env bash
# test_gate_sno_an_output_associated_variable_keeps_the_value_it_was_assigned.sh -- a variable associated for output (OUTPUT(.X) on
# the standard stream, or OUTPUT(.V, unit, file) on a file) writes its record AND keeps the value: reading it back gives what was
# last assigned, by plain assignment, by immediate ($) or conditional (.) pattern capture, and through a name ($N) as SPITCORE's IN() does.
#
# ⛔ THE DEFECT (row snobol4-an-output-associated-variable-loses-the-value-it-was-assigned, ceo 2026-09-24 witness; walked on aisnobol
# SIR 2026-09-25 by hq_snobol4). NV_SET_fn's I/O-channel arm wrote the record and RETURNED, so the value never reached the variable's
# slot and every later read gave the null string. SPITCORE's IN(.OUTPUT.) assigns the input line to the output-associated OUTPUT.
# (the echo) and returns $IN...N -- which came back empty, so GET.SENTENCE never assembled a sentence, SIR read to end of file and
# printed none of its answers. THE CURE: the arm writes the record and then falls through to the ordinary store (goto nv_store), so
# the value is kept and the assignment is seen like any other; the OUTPUT/TERMINAL special cases are skipped for a channel variable.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  STDOUT m3 / m4: OUTPUT(.X); X = / $ X / . X each written once and each read back
#   3-4  FILE   m3 / m4: OUTPUT(.V, 7, file); the file holds each record once and V reads back the last one
#   5    NAME   m3: SPITCORE's IN() idiom -- $N = value where N = .OUT. (output-associated), then IN = $N returns the value
#   6    CONTROL m3: the same reads on a variable with no association answer the oracle
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, oracle shape moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_an_output_associated_variable_keeps_the_value_it_was_assigned
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/stdout.sno" <<'EOF'
        OUTPUT(.X)
        X = 'v'
        OUTPUT = 'read1 ' X
        'ab' LEN(2) $ X
        OUTPUT = 'read2 ' X
        'abc' LEN(3) . X
        OUTPUT = 'read3 ' X
END
EOF
sed "s/^        OUTPUT(.X)$/        Y = 0/" "$T/stdout.sno" > "$T/control.sno"
cat > "$T/file.sno" <<'EOF'
        OUTPUT(.V, 7, 'out.txt')
        V = 'first'
        OUTPUT = 'read1 ' V
        'second' LEN(6) . V
        OUTPUT = 'read2 ' V
        ENDFILE(7)
END
EOF
cat > "$T/name.sno" <<'EOF'
        OUTPUT(.OUT.)
        DEFINE('IN(N)')                         :(IN_END)
IN      $N = 'line one'
        IN = $N                                 :(RETURN)
IN_END
        OUTPUT = 'IN gave [' IN(.OUT.) ']'
END
EOF
oracle() { ( cd "$T" && rm -f out.txt && timeout -k 5 10 "$SBL" -bf "$1.sno" < /dev/null > "$1.oracle" 2>/dev/null && { [ ! -f out.txt ] || { echo '--file--'; cat out.txt; } >> "$1.oracle"; } ) || refuse "the oracle did not run $1 cleanly"; }
for w in stdout control file name; do oracle "$w"; done
[ "$(tr '\n' '|' < "$T/stdout.oracle")" = "v|read1 v|ab|read2 ab|abc|read3 abc|" ] || refuse "the oracle's STDOUT answer moved: [$(tr '\n' '|' < "$T/stdout.oracle")]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
m3() { ( cd "$T" && rm -f out.txt && SCRIP_SNO_STMTKW=1 timeout -k 5 10 "$SCRIP" "$1.sno" < /dev/null > "$1.m3" 2>/dev/null; rc=$?; [ ! -f out.txt ] || { echo '--file--'; cat out.txt; } >> "$1.m3"; echo $rc ); }
m4() { ( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 20 "$SCRIP" --compile -o "$1.s" "$1.sno" < /dev/null > /dev/null 2>&1 ) || { echo cc; return; }
       gcc "$T/$1.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$T/$1.bin" > /dev/null 2>&1 || { echo link; return; }
       ( cd "$T" && rm -f out.txt && timeout -k 5 10 "./$1.bin" < /dev/null > "$1.m4" 2>/dev/null; rc=$?; [ ! -f out.txt ] || { echo '--file--'; cat out.txt; } >> "$1.m4"; echo $rc ); }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(head -c 90 "$T/$2" | tr '\n' '|')] want [$(head -c 90 "$T/$3" | tr '\n' '|')]"; }
rc=$(m3 stdout); arm "STDOUT m3: written once and read back after =, \$ and ." "$(same "$rc" stdout.m3 stdout.oracle)"
rc=$(m4 stdout); arm "STDOUT m4: written once and read back after =, \$ and ." "$(same "$rc" stdout.m4 stdout.oracle)"
rc=$(m3 file); arm "FILE m3: each record once and V reads back the last" "$(same "$rc" file.m3 file.oracle)"
rc=$(m4 file); arm "FILE m4: each record once and V reads back the last" "$(same "$rc" file.m4 file.oracle)"
rc=$(m3 name); arm "NAME m3: \$N = v then \$N reads v through an output-associated name (SPITCORE IN)" "$(same "$rc" name.m3 name.oracle)"
rc=$(m3 control); arm "CONTROL: the same reads with no association answer the oracle" "$(same "$rc" control.m3 control.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
