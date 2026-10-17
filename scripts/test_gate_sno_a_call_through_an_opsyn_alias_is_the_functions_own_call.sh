#!/usr/bin/env bash
# test_gate_sno_a_call_through_an_opsyn_alias_is_the_functions_own_call.sh -- after OPSYN(.POP, .UNCONS) a call to POP is a call of
# UNCONS: TRACE on either name traces both spellings of the call and prints UNCONS, and the monitor reports CALL/RETURN UNCONS.
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25; the IPC monitor bracket on a SPITCORE MAPCAR witness, step 2406: spl "@495 CALL UNCONS",
# scr "@495 CALL POP" -- SPITCORE defines UNCONS and makes POP its synonym, and every list walk calls POP). SPITBOL's synonym shares
# the function block, so the call is reported, traced and matched as UNCONS whichever name was written. SCRIP keeps a procedure
# record per name and reported p->name: TRACE('UNCONS') missed every POP() call, and TRACE('POP') printed "POP(...)" and missed
# UNCONS() calls (measured against sbl -bf). THE CURE: the call and return events of the SNOBOL4 call paths (rt_proc_call_prologue,
# rt_proc_epilogue_p, the slim open) report p->result_name when the record has one -- the function the value is read from, which
# OPSYN sets to the original -- and TRACE/STOPTR of a CALL, RETURN or FUNCTION kind register on that same name (rt_proc_trace_canon).
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  TRACE UNCONS m3 / m4: both the POP() and the UNCONS() call are traced, as UNCONS
#   3    TRACE POP m3: both calls are traced, as UNCONS
#   4    MONITOR: a call through the synonym agrees with the SPITBOL fork event-for-event
#   5    CONTROL: DEFINE('F(X)','LBL') is traced as F, as before
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, oracle shape moved, the monitor could not measure).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_call_through_an_opsyn_alias_is_the_functions_own_call
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
MON="$HERE/monitor_run.sh"; [ -f "$MON" ] || refuse "no monitor_run.sh -- the MONITOR arm cannot measure"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
for tn in UNCONS POP; do cat > "$T/tr_$tn.sno" <<EOF
        DEFINE('UNCONS(N)')                     :(UE)
UNCONS  UNCONS = 'u' N                          :(RETURN)
UE      OPSYN(.POP, .UNCONS)
        &TRACE = 100
        TRACE('$tn','CALL')
        TRACE('$tn','RETURN')
        X = POP('a')
        Y = UNCONS('b')
        OUTPUT = X Y
END
EOF
done
cat > "$T/mon.sno" <<'EOF'
        DEFINE('UNCONS(N)')                     :(UE)
UNCONS  UNCONS = 'u' N                          :(RETURN)
UE      OPSYN(.POP, .UNCONS)
        OUTPUT = POP('a') UNCONS('b')
END
EOF
cat > "$T/ctl.sno" <<'EOF'
        DEFINE('F(X)', 'LBL')                   :(E)
LBL     F = 'f' X                               :(RETURN)
E       &TRACE = 100
        TRACE('F','CALL')
        TRACE('F','RETURN')
        OUTPUT = F('a')
END
EOF
for w in tr_UNCONS tr_POP ctl; do ( cd "$T" && timeout -k 5 10 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>&1 ) || refuse "sbl did not run $w cleanly"; done
[ "$(grep -c 'UNCONS(' "$T/tr_POP.oracle")" = 2 ] || refuse "sbl's TRACE POP answer moved: [$(tr '\n' '|' < "$T/tr_POP.oracle")]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 110)] want [$(tr '\n' '|' < "$T/$3" | head -c 110)]"; }
m3() { ( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 10 "$SCRIP" "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
rc=$(m3 tr_UNCONS); arm "TRACE UNCONS m3: POP() and UNCONS() both traced as UNCONS" "$(same "$rc" tr_UNCONS.m3 tr_UNCONS.oracle)"
rc=$( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 20 "$SCRIP" --compile -o u.s tr_UNCONS.sno < /dev/null > /dev/null 2>&1 && gcc u.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o u.bin > /dev/null 2>&1 && timeout -k 5 10 ./u.bin < /dev/null > tr_UNCONS.m4 2>&1; echo $? )
arm "TRACE UNCONS m4: POP() and UNCONS() both traced as UNCONS" "$(same "$rc" tr_UNCONS.m4 tr_UNCONS.oracle)"
rc=$(m3 tr_POP); arm "TRACE POP m3: both calls traced, as UNCONS" "$(same "$rc" tr_POP.m3 tr_POP.oracle)"
mout=$( cd "$T" && S4E_HOME="$(cd "$ROOT/.." && pwd)" SCRIP_SNO_STMTKW=1 timeout -k 5 200 bash "$MON" "$T/mon.sno" --oracle 2>&1 ); mrc=$?
[ "$mrc" = 2 ] && refuse "the monitor could not measure: $(printf '%s\n' "$mout" | grep -m1 REFUSE | cut -c1-140)"
arm "MONITOR: a call through the synonym agrees with the SPITBOL fork" "$([ "$mrc" = 0 ] && printf '%s\n' "$mout" | grep -q 'AGREE: participants' && echo ok || echo "rc=$mrc: $(printf '%s\n' "$mout" | grep -aE '^\| \*\*>' | head -1 | cut -c1-150)")"
rc=$(m3 ctl); arm "CONTROL: DEFINE('F(X)','LBL') is traced as F" "$(same "$rc" ctl.m3 ctl.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
