#!/usr/bin/env bash
# test_gate_sno_a_call_saves_binds_and_restores_an_io_associated_name_without_io.sh -- a SNOBOL4 procedure call saves, binds and
# restores its parameters, locals and result name on their VALUE SLOTS: an input-associated local is not read at the call, an
# output-associated local or parameter is not written at the call or at the return, and the monitor sees CALL, not a VALUE per name.
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25, found walking aisnobol SIR under the monitor bracket). rt_name_save_push / rt_name_restore /
# rt_proc_epilogue_p used the variable's cell only while the call fast path was on, and ANY I/O association turns it off
# (g_call_fastpath_off). From then on every save went through NV_GET_fn (which READS a line from an input-associated name), every
# bind and restore through NV_SET_fn (which WRITES a line to an output-associated one), and each set shipped a monitor VALUE event
# before the CALL -- so the bracket diverged at the first call of any program that had opened a file. MEASURED against sbl -bf:
# a local input-associated to 5 lines read b,c at the call (SCRIP printed "in G: c" where SPITBOL prints "in G: b" and ran dry two
# lines early); an output-associated local wrote two extra blank records; an output-associated parameter wrote the argument into
# the file and the body saw an empty V. SPITBOL's call never performs I/O on these names and its value TRACE does not fire on a
# binding. THE CURE: the save, bind, restore and result read use the value cell whenever one exists; the few side-effecting names
# with no cell (rt_name_side_effecting) still go through NV_*_fn, now under g_monitor_quiet_depth like driver_call.c's call path.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  IN-LOCAL   m3 / m4: a local input-associated to a 5-line file reads a,b,c,d,e in order across two calls
#   3-4  OUT-LOCAL  m3 / m4: an output-associated local writes exactly the records the program assigns
#   5-6  OUT-PARAM  m3 / m4: an output-associated parameter is not written at the call, and the body sees the argument
#   7    MONITOR    monitor_run.sh --oracle on a program that opens a file and then calls a function agrees event-for-event
#   8    CONTROL    the IN-LOCAL witness with the INPUT() association removed answers the oracle in m3
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, oracle shape moved, the monitor could not measure).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_call_saves_binds_and_restores_an_io_associated_name_without_io
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
printf 'a\nb\nc\nd\ne\n' > "$T/in.txt"
cat > "$T/inlocal.sno" <<'EOF'
        INPUT(.L, 8, 'in.txt')
        DEFINE('G()L')                          :(G_END)
G       OUTPUT = 'in G: ' L                     :(RETURN)
G_END
        OUTPUT = 'top1: ' L
        G()
        OUTPUT = 'top2: ' L
        G()
        OUTPUT = 'top3: ' L
END
EOF
grep -v "INPUT(.L" "$T/inlocal.sno" | sed "s/^        OUTPUT = 'top1: ' L/        L = 'x'\n        OUTPUT = 'top1: ' L/" > "$T/control.sno"
cat > "$T/outlocal.sno" <<'EOF'
        OUTPUT(.V, 7, 'out.txt')
        V = 'first'
        DEFINE('F()V')                          :(F_END)
F       V = 'inside'                            :(RETURN)
F_END
        F()
        V = 'last'
        ENDFILE(7)
END
EOF
cat > "$T/outparam.sno" <<'EOF'
        OUTPUT(.V, 7, 'out.txt')
        V = 'first'
        DEFINE('F(V)')                          :(F_END)
F       F = 'got ' V                            :(RETURN)
F_END
        OUTPUT = F('arg')
        V = 'last'
        ENDFILE(7)
END
EOF
cat > "$T/mon.sno" <<'EOF'
        INPUT(.L, 8, 'in.txt')
        DEFINE('F(X)K')                         :(F_END)
F       F = X X                                 :(RETURN)
F_END
        OUTPUT = F('ab')
END
EOF
oracle() { ( cd "$T" && rm -f out.txt && timeout -k 5 10 "$SBL" -bf "$1.sno" < /dev/null > "$1.oracle" 2>/dev/null && { [ ! -f out.txt ] || { echo '--file--'; cat out.txt; } >> "$1.oracle"; } ) || refuse "the oracle did not run $1 cleanly"; }
for w in inlocal control outlocal outparam; do oracle "$w"; done
[ "$(sed -n 2p "$T/inlocal.oracle")" = "in G: b" ] || refuse "the oracle's IN-LOCAL answer moved: [$(tr '\n' '|' < "$T/inlocal.oracle")]"
[ "$(tr '\n' '|' < "$T/outlocal.oracle")" = "--file--|first|inside|last|" ] || refuse "the oracle's OUT-LOCAL answer moved: [$(tr '\n' '|' < "$T/outlocal.oracle")]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
m3() { ( cd "$T" && rm -f out.txt && SCRIP_SNO_STMTKW=1 timeout -k 5 10 "$SCRIP" "$1.sno" < /dev/null > "$1.m3" 2>/dev/null; rc=$?; [ ! -f out.txt ] || { echo '--file--'; cat out.txt; } >> "$1.m3"; echo $rc ); }
m4() { ( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 20 "$SCRIP" --compile -o "$1.s" "$1.sno" < /dev/null > /dev/null 2>&1 ) || { echo cc; return; }
       gcc "$T/$1.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$T/$1.bin" > /dev/null 2>&1 || { echo link; return; }
       ( cd "$T" && rm -f out.txt && timeout -k 5 10 "./$1.bin" < /dev/null > "$1.m4" 2>/dev/null; rc=$?; [ ! -f out.txt ] || { echo '--file--'; cat out.txt; } >> "$1.m4"; echo $rc ); }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "differs from the oracle: [$(head -c 90 "$T/$2" | tr '\n' '|')] want [$(head -c 90 "$T/$3" | tr '\n' '|')]"; }
rc=$(m3 inlocal); arm "IN-LOCAL m3: the call does not read the input-associated local" "$(same "$rc" inlocal.m3 inlocal.oracle)"
rc=$(m4 inlocal); arm "IN-LOCAL m4: the call does not read the input-associated local" "$(same "$rc" inlocal.m4 inlocal.oracle)"
rc=$(m3 outlocal); arm "OUT-LOCAL m3: the call and return write no record" "$(same "$rc" outlocal.m3 outlocal.oracle)"
rc=$(m4 outlocal); arm "OUT-LOCAL m4: the call and return write no record" "$(same "$rc" outlocal.m4 outlocal.oracle)"
rc=$(m3 outparam); arm "OUT-PARAM m3: binding writes no record and the body sees the argument" "$(same "$rc" outparam.m3 outparam.oracle)"
rc=$(m4 outparam); arm "OUT-PARAM m4: binding writes no record and the body sees the argument" "$(same "$rc" outparam.m4 outparam.oracle)"
MON="$HERE/monitor_run.sh"; [ -f "$MON" ] || refuse "no monitor_run.sh -- the MONITOR arm cannot measure"
mout=$( cd "$T" && S4E_HOME="$(cd "$ROOT/.." && pwd)" SCRIP_SNO_STMTKW=1 timeout -k 5 200 bash "$MON" "$T/mon.sno" --oracle 2>&1 ); mrc=$?
[ "$mrc" = 2 ] && refuse "the monitor could not measure: $(printf '%s\n' "$mout" | grep -m1 REFUSE | cut -c1-160)"
arm "MONITOR: a call after an I/O association is reported as CALL, not as a VALUE per bound name" "$([ "$mrc" = 0 ] && printf '%s\n' "$mout" | grep -q 'AGREE: participants' && echo ok || echo "rc=$mrc: $(printf '%s\n' "$mout" | grep -aE '^\| \*\*>' | head -1 | cut -c1-160)")"
rc=$(m3 control); arm "CONTROL: without the association the witness answers the oracle" "$(same "$rc" control.m3 control.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
