#!/usr/bin/env bash
# util_autobug.sh — ⭐ THE AUTOMATIC BUG FINDER (Lon's design, 2026-08-20 s182, in-chat).
#
#   bash ../harness/scripts/util_autobug.sh <file.sno> [stdin-file]
#
# LON'S TECHNIQUE, VERBATIM IN SUBSTANCE: "2-way monitor reports event of FIRST DIVERGENCE.  The previous event
# then is event of the LAST AGREEMENT.  The BUG is between [them] ... INSTRUMENT the BB at that LAST AGREEMENT BB
# to fire TRACE ON ... and TRACE OFF when it arrives at the FIRST DIVERGENCE BB.  This trace has the BUG in it and
# should be REASONABLY LIMITED in size.  An AUTOMATIC BUG FINDER!!!"
#
# ⭐ THE BRACKET NEEDS NO COUNTER AND NO NEW RUNTIME STATE.  The IPC monitor already closes the window on BOTH
# sides by construction: it sync-steps the two engines and KILLS the scrip child the instant the controller
# answers 'S' (the ack arm in mon_send_bin, runtime/core/core.c) — that is, AT THE FIRST DIVERGENCE.  So the
# process dies inside the bug's own statement, the SCRIP_ZSM atexit reporter runs, and the ZSM four-port ring
# (last ZSM_TRACE=64 ports, execution order, runtime_init.c) IS the bounded trace, ending at the divergence.
# TRACE-ON is "64 ports ago" instead of a counter, which is strictly cheaper and needs no instrumentation pass.
# If 64 ports is too short a window for a given bug, widen ZSM_TRACE — that is the ONE knob.
#
# ⛔ MONITOR-SAFETY (RULES.md): a MONITOR_BIN verdict is a verdict on a DIFFERENT program (GVA forced off,
# optimizer arms diverge).  This tool LOCATES; it never GRADES.  Confirm every bracket it hands you against a
# plain build before believing it, and mint a standalone witness from the bracket rather than citing the trace.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNO="${1:?Usage: util_autobug.sh <file.sno> [stdin-file]}"
IN="${2:-/dev/null}"
RING="${RING:-64}"
[ -f "$SNO" ] || { echo "no such program: $SNO"; exit 2; }
echo "=== AUTOBUG: $SNO   stdin=$IN ==="
export SCRIP_ZSM=1 SCRIP_ZSM_ALL=1 SCRIP_ZSM_RING=1
STDIN_SRC="$IN" timeout -k 5 "${AUTOBUG_TIMEOUT:-400}" bash "$HERE/test_monitor_2way_spitbol_vs_run.sh" "$SNO" > /tmp/autobug_run.$$ 2>&1
rc=$?
ART=/tmp/monitor_auto_last
# ---------------------------------------------------------------- (1) the bracket: last agreement -> first divergence
if grep -q "DIVERGE" /tmp/autobug_run.$$ 2>/dev/null; then
    echo; echo "--- (1) THE BRACKET (from the sync-step controller) ---"
    sed -n '/DIVERGE/,$p' /tmp/autobug_run.$$ | grep -E '^\||DIVERGE' | head -14
else
    echo; echo "--- (1) NO DIVERGENCE — the two engines agreed to END.  Nothing to bracket. ---"
    grep -E "reached END|exit:" /tmp/autobug_run.$$ | head -4
fi
# ---------------------------------------------------------------- (2) the bounded trace, ending AT the divergence
echo; echo "--- (2) THE BUG WINDOW: last $RING four-port events before the kill (oldest first) ---"
if [ -s "$ART/scr.err" ] && grep -q '^\[ZSM\]   ' "$ART/scr.err"; then
    # op=N -> IR_* here, NOT in the runtime: bb_op_name lives in ir/IR.h and the runtime may not
    # know IR (RULES: no SM/BB knowledge at runtime).  The enum is parsed at read time, so it cannot rot.
    grep '^\[ZSM\]' "$ART/scr.err" | tail -n "$((RING+1))" | python3 -c '
import re,sys,os
hdr=os.path.join(os.environ.get("S4E_SRC","'"$S4E"'/SCRIP"),"src/ir/IR.h")
names={}
try:
    txt=open(hdr).read()
    m=re.search(r"typedef\s+enum[^{]*\{(.*?)\}\s*IR_e", txt, re.S)
    body=m.group(1) if m else ""
    body=re.sub(r"/\*.*?\*/","",body,flags=re.S)
    i=0
    for tok in re.findall(r"\b(IR_[A-Z0-9_]+)\b\s*(=\s*[0-9]+)?\s*,", body):
        nm,val=tok
        if val: i=int(val.split("=")[1])
        names[i]=nm; i+=1
except Exception: pass
for ln in sys.stdin:
    mm=re.search(r"op=(\d+)", ln)
    if mm:
        n=int(mm.group(1))
        ln=ln.replace("op=%-5d"%n if False else mm.group(0), "%-24s"%names.get(n,"op=%d"%n),1)
    sys.stdout.write(ln)
'
else
    echo "(no ZSM ring in $ART/scr.err — is this build current?  the ring needs SCRIP_ZSM_RING and a ZSM-armed run)"
    grep -E '^\[ZSM\]' "$ART/scr.err" 2>/dev/null | tail -5
fi
# ---------------------------------------------------------------- (3) what each engine had emitted when it stopped
echo; echo "--- (3) STDOUT AT THE KILL ---"
printf 'spl: '; head -c 200 "$ART/spl.out" 2>/dev/null | tr '\n' '|'; echo
printf 'scr: '; head -c 200 "$ART/scr.out" 2>/dev/null | tr '\n' '|'; echo
echo; echo "artefacts: $ART   (monitor rc=$rc)"
rm -f /tmp/autobug_run.$$
exit 0
