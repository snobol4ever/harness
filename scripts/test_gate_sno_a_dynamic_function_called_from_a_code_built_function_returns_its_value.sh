#!/usr/bin/env bash
# test_gate_sno_a_dynamic_function_called_from_a_code_built_function_returns_its_value.sh -- a program-defined function called from
# a function whose body CODE() compiled at run time returns its own value and restores its caller's names, as SPITBOL does.
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25; the IPC monitor bracket on aisnobol SIR's witness -- SPITCORE, A = READ('(X Y)'),
# OUTPUT = UNREAD(A) -- step 6153 VALUE MAPCAR = DATA, step 6154 spl "RETURN MAPCAR", scr "CALL CONCAT"). UNREAD.REGULAR is built by
# DEXP through CODE and calls MAPCAR, a dynamic-scope function (its DEFINE ran at run time), by name. The call node in that fragment
# took the legacy flat arm of bb_call_proc_staged (the zd plan does not claim it), which opens a dynamic callee through
# rt_proc_call_open -- the runtime prologue pushes the callee's names -- and closed it with the PLAIN rt_proc_call_epilogue_γ(frame0)
# unconditionally: no result read from the function's name, no name restore, no RETURN event. So CONCAT received whatever rdi:rsi
# held (a STRING where MAPCAR returned a CONS: "Argument number 1 to CONCAT (L) has illegal datatype STRING"), and MAPCAR's
# formals stayed bound. The zd arm already chose the named epilogue whenever the callee has no static index (det_idx < 0).
# THE CURE: the legacy arm makes the same choice on both exits -- det_idx >= 0 ? plain : bcps_epi_named -- SNOBOL4's call template.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME; SPITCORE and its library come from the corpus aisnobol package):
#   1-2  m3 / m4: UNREAD(READ('(X Y)')) is the STRING (X Y)
#   3    m3: a nested list round-trips, UNREAD(READ('(A (B C) D)'))
#   4    MONITOR: the witness agrees with the SPITBOL fork event for event to its end (DIVERGE=0); a monitor refusal is this arm's
#        FAIL when an earlier arm already failed (the pre-cure error cascade is itself what makes the witness not monitor-safe)
#   5    CONTROL: a CODE-built function calling a DEFINEd function through the zd arm, as before
# ⛔ ARM 4 SKIPS VALUE EVENTS ON THE THREE RESERVED CONSTANTS (cto 2026-10-02, ceo CEO-1409): RULES.md FACT RULE (Lon 2026-09-29)
# makes epsilon, NULL and null reserved constants, and SPITCORE's NULL predicate, built as NULL NULL = ?(...) through CODE, keeps its
# right side as a bare statement and stores nothing -- the rule names this program. SPITBOL stores and reports VALUE NULL = '';
# SCRIP by law does not, so without the skip the bracket stopped at step 2561 on a difference the law requires. The skip
# (MONITOR_SKIP_VALUE_NAMES, both streams, cadence kept) drops only those three names; every other event is still compared.
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no aisnobol package, the monitor could not measure).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
PKG="$S4E/corpus/packages/snobol4/aisnobol"
NAME=sno_a_dynamic_function_called_from_a_code_built_function_returns_its_value
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
for f in SPITCORE.sno spitlib.idx spitlib.spt; do [ -f "$PKG/$f" ] || refuse "no $PKG/$f -- the witness needs the aisnobol package (pull corpus)"; done
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
MON="$HERE/monitor_run.sh"; [ -f "$MON" ] || refuse "no monitor_run.sh -- the MONITOR arm cannot measure"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'chmod -R u+w "$T" 2>/dev/null; rm -rf "$T"' EXIT
cp "$PKG/SPITCORE.sno" "$PKG/spitlib.idx" "$PKG/spitlib.spt" "$T/" && chmod a-w "$T/spitlib.idx" "$T/spitlib.spt" || refuse "could not stage the aisnobol library"
printf '%s\n' '-INCLUDE "SPITCORE.sno"' " A = READ('(X Y)')" ' X = UNREAD(A)' " OUTPUT = DATATYPE(X) ' ' X" 'END' > "$T/ur.sno"
printf '%s\n' '-INCLUDE "SPITCORE.sno"' " A = READ('(A (B C) D)')" " OUTPUT = DATATYPE(UNREAD(A)) ' ' UNREAD(A)" 'END' > "$T/ur2.sno"
cat > "$T/ctl.sno" <<'EOF'
        DEFINE('F(X)A')                         :(F.END)
F       F = X X                                 :(RETURN)
F.END   DEFINE('J(X,S)')                        :(J.END)
J       J = X S                                 :(RETURN)
J.END   CODE('G G = "(" J(F(L), " ") ")" :S(RETURN)F(FRETURN) ;')
        DEFINE('G(L)')
        A = 'keep'
        OUTPUT = G('ab') ' ' A
END
EOF
for w in ur ur2 ctl; do ( cd "$T" && timeout -k 5 20 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>&1 ) || refuse "sbl did not run $w cleanly"; done
grep -qx 'STRING (X Y)' "$T/ur.oracle" && grep -qx 'STRING (A (B C) D)' "$T/ur2.oracle" || refuse "sbl's answer moved: [$(cat "$T/ur.oracle" "$T/ur2.oracle" | tr '\n' '|')]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1 [$(tr '\n' '|' < "$T/$2" | head -c 110)]"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 110)] want [$(tr '\n' '|' < "$T/$3" | head -c 110)]"; }
m3() { ( cd "$T" && timeout -k 5 20 "$SCRIP" "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
rc=$(m3 ur); arm "m3: UNREAD(READ('(X Y)')) is the STRING (X Y)" "$(same "$rc" ur.m3 ur.oracle)"
rc=$( cd "$T" && timeout -k 5 60 "$SCRIP" --compile -o u.s ur.sno < /dev/null > /dev/null 2>&1 && gcc u.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o u.bin > /dev/null 2>&1 && timeout -k 5 20 ./u.bin < /dev/null > ur.m4 2>&1; echo $? )
arm "m4: UNREAD(READ('(X Y)')) is the STRING (X Y)" "$(same "$rc" ur.m4 ur.oracle)"
rc=$(m3 ur2); arm "m3: a nested list round-trips through READ and UNREAD" "$(same "$rc" ur2.m3 ur2.oracle)"
mout=$( cd "$T" && MONITOR_SKIP_VALUE_NAMES=NULL,null,epsilon S4E_HOME="$S4E" timeout -k 5 400 bash "$MON" "$T/ur.sno" --oracle 2>&1 ); mrc=$?
[ "$mrc" = 2 ] && [ "$fail" = 0 ] && refuse "the monitor could not measure: $(printf '%s\n' "$mout" | grep -m1 REFUSE | cut -c1-140)"
arm "MONITOR: the witness agrees with the SPITBOL fork to its end" "$([ "$mrc" = 0 ] && printf '%s\n' "$mout" | grep -q 'DIVERGE=0' && echo ok || echo "rc=$mrc: $(printf '%s\n' "$mout" | grep -aE '^\| \*\*>' | head -1 | cut -c1-150)")"
rc=$(m3 ctl); arm "CONTROL: a CODE-built function calling a DEFINEd function" "$(same "$rc" ctl.m3 ctl.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
