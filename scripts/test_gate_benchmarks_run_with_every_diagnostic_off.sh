#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_benchmarks_run_with_every_diagnostic_off.sh -- LON'S WORDS OF 2026-09-25, HELD BY MECHANISM (ceo CEO-1262), verbatim, in-chat to
# the ceo: "Why must there be a heap check at every collection? That seems to be diagnostic. Can the be turned off by a switch?" and
# "For benchmarks turn off all diagnostic code."
# ONE SWITCH, SCRIP_DIAG=0, turns off every diagnostic the default run carries: the heap check at every collection (rt_gcheap_verify),
# the 0xDB poison of vacated ground and the stale-read quarantine. Each keeps its own switch (SCRIP_GC_VERIFY, SCRIP_GC_POISON, SCRIP_GC_TRAP),
# which wins when set. UNSET, EVERY COLLECTOR DIAGNOSTIC STAYS ON: every test and every board runs with them. ⛔ THE COMPILED NODE-ID STORES
# (`mov r11, <id>` at every alpha and beta port) ARE DIAGNOSTIC ONLY AND OFF BY DEFAULT (Lon 2026-09-29, in-chat to the ceo, verbatim: "Also the
# R11, tracking node-ids, should be DIAGNOSTIC only."): only SCRIP_DIAG_REGS=1 at the compile emits them; every benchmark driver exports SCRIP_DIAG=0 on its second line, or on
# its third when its second is the one-runner guard (coo 2026-09-25, ceo CEO-1272: test_gate_one_runner_one_board.sh arm 6a holds the guard
# to line 2, and the guard runs nothing SCRIP_DIAG reads -- one named line of window, never a free search of the header).
# ARMS: (1) every benchmark driver in ../harness/scripts/ (bench_*.sh, test_bench_*.sh, test_<lang>_bench_suite.sh, test_icon_bench_{corpus,rung36}.sh)
# exports SCRIP_DIAG=0; (2) a churning witness compiled by default carries no node-id store, nor one compiled with SCRIP_DIAG=0, and one
# compiled with SCRIP_DIAG_REGS=1 carries them; (3) at run time SCRIP_DIAG=0 reads verify=0 and no poison line in the collector's telemetry, unset reads both, and
# SCRIP_GC_VERIFY=1 turns the check back on under SCRIP_DIAG=0; (4) the witness answers the oracle in m3 and m4 with and without it.
# FAIL_ONCE (recorded): on the pre-landing tree b547d2ea3 no driver exported the switch, the SCRIP_DIAG=0 witness carried 114 node-id stores,
# and its telemetry read verify=<n> and a poison line at every collection (arms 1-3 RED, arm 4 green: the witness's live set is bounded,
# a hundred keys, so it answers under the old 4 MB cap too). EXIT 0 all arms; 1 a red (named); 2 REFUSED.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SBL=/home/resources/spitbol-bench-oracle/sbl; [ -x "$SBL" ] || { echo "REFUSED(2): the SPITBOL oracle $SBL is missing"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
red=0
drivers=$(cd "$HERE" && ls | grep -E '^bench_.*\.sh$|^test_bench_.*\.sh$|^test_[a-z0-9]+_bench_suite\.sh$|^test_icon_bench_(corpus|rung36)\.sh$')
nd=$(echo "$drivers" | grep -c .)
[ "$nd" -gt 0 ] || { echo "REFUSED(2): no benchmark driver found in $HERE"; exit 2; }
miss=$(for f in $drivers; do { sed -n '2p' "$HERE/$f" | grep -q '^export SCRIP_DIAG=0' || { sed -n '2p' "$HERE/$f" | grep -q '^source .*lib_one_runner\.sh' && sed -n '3p' "$HERE/$f" | grep -q '^export SCRIP_DIAG=0'; }; } || echo "$f"; done)
if [ -z "$miss" ]; then echo "ok  (1) all $nd benchmark drivers export SCRIP_DIAG=0 on their second line, or on their third right after the one-runner guard"
else echo "RED (1) $(echo "$miss" | grep -c .) of $nd benchmark drivers do not export SCRIP_DIAG=0: $(echo $miss | cut -c1-300)"; red=1; fi
cat > "$W/churn.sno" <<'SNO'
        T = TABLE()
        I = 0
LOOP    I = I + 1
        T[REMDR(I, 100)] = DUPL('X', 50) I
        S = S 'AB'
        S = GT(SIZE(S), 2000) ''
        LT(I, 60000)                                    :S(LOOP)
        OUTPUT = SIZE(T[REMDR(I, 100)]) ' ' SIZE(S)
END
SNO
( cd "$W" && env -u SCRIP_DIAG SCRIP_DIAG_REGS=1 "$ROOT/scrip" --compile -o on.s churn.sno < /dev/null > /dev/null 2>&1 && gcc on.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o on.bin 2>/dev/null \
  && env -u SCRIP_DIAG_REGS SCRIP_DIAG=0 "$ROOT/scrip" --compile -o off.s churn.sno < /dev/null > /dev/null 2>&1 && gcc off.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o off.bin 2>/dev/null ) \
  || { echo "REFUSED(2): the churn witness did not build in mode 4"; exit 2; }
non=$(grep -cE 'mov[[:space:]]+r11, [0-9]+' "$W/on.s"); noff=$(grep -cE 'mov[[:space:]]+r11, [0-9]+' "$W/off.s")
( cd "$W" && env -u SCRIP_DIAG -u SCRIP_DIAG_REGS "$ROOT/scrip" --compile -o dflt.s churn.sno < /dev/null > /dev/null 2>&1 ) || { echo "REFUSED(2): the churn witness did not compile by default"; exit 2; }
ndef=$(grep -cE 'mov[[:space:]]+r11, [0-9]+' "$W/dflt.s")
if [ "$non" -gt 0 ] && [ "$noff" -eq 0 ] && [ "$ndef" -eq 0 ]; then echo "ok  (2) the node-id stores: $non with SCRIP_DIAG_REGS=1, $ndef by default, $noff with SCRIP_DIAG=0"
else echo "RED (2) the node-id stores do not follow the switch: $non with SCRIP_DIAG_REGS=1, $ndef by default, $noff with SCRIP_DIAG=0 (want >0, 0 and 0)"; red=1; fi
tele() { ( cd "$W" && env -u SCRIP_DIAG -u SCRIP_GC_VERIFY -u SCRIP_GC_POISON -u SCRIP_GC_TRAP -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB SCRIP_HEAP_KB=256 SCRIP_ZETA_TELEM=1 "$@" ./off.bin < /dev/null 2>&1 >/dev/null ) > "$W/t.txt"
  v=$(grep -oE 'verify=[0-9]+/' "$W/t.txt" | grep -vc 'verify=0/'); p=$(grep -c 'ZGC-POISON' "$W/t.txt"); c=$(grep -c '^\[ZGC-WALK\]' "$W/t.txt"); echo "${c}|${v}|${p}"; }
on=$(tele); off=$(tele SCRIP_DIAG=0); back=$(tele SCRIP_DIAG=0 SCRIP_GC_VERIFY=1)
IFS='|' read -r c1 v1 p1 <<< "$on"; IFS='|' read -r c2 v2 p2 <<< "$off"; IFS='|' read -r c3 v3 p3 <<< "$back"
[ "${c1:-0}" -gt 0 ] || { echo "REFUSED(2): the witness ran no collection at SCRIP_HEAP_KB=256 (telemetry read [$on]) -- the arm cannot see a diagnostic that never ran"; exit 2; }
if [ "$v1" = "$c1" ] && [ "$p1" = "$c1" ] && [ "$v2" = 0 ] && [ "$p2" = 0 ] && [ "$v3" = "$c3" ] && [ "$p3" = 0 ]; then
    echo "ok  (3) over $c1 collections: unset verifies the heap at $v1 and poisons at $p1; SCRIP_DIAG=0 at $v2 and $p2; SCRIP_DIAG=0 SCRIP_GC_VERIFY=1 verifies at $v3 and poisons at $p3"
else echo "RED (3) the collector's diagnostics do not follow the switch (collections|verifying collections|poison lines): unset [$on], SCRIP_DIAG=0 [$off], SCRIP_DIAG=0 SCRIP_GC_VERIFY=1 [$back]"; red=1; fi
want=$( cd "$W" && timeout -k 5 30 "$SBL" -bf churn.sno < /dev/null 2>/dev/null )
got=$( cd "$W" && for e in "" "SCRIP_DIAG=0"; do env -u SCRIP_DIAG $e timeout -k 5 30 "$ROOT/scrip" churn.sno < /dev/null 2>/dev/null; env -u SCRIP_DIAG $e timeout -k 5 30 ./on.bin < /dev/null 2>/dev/null; env -u SCRIP_DIAG $e timeout -k 5 30 ./off.bin < /dev/null 2>/dev/null; done | sort -u )
if [ -n "$want" ] && [ "$got" = "$want" ]; then echo "ok  (4) the witness answers the oracle ('$want') in m3 and m4, with and without SCRIP_DIAG=0"
else echo "RED (4) the witness does not answer the oracle ('$want') in every arm: got [$(echo $got)]"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: benchmarks run with every diagnostic off by one switch, and every test keeps them on"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
