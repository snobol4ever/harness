#!/usr/bin/env bash
# test_gate_monitor_an_untyped_value_grades_ungraded_never_agree.sh -- the sync-step controller grades a pair with an untyped
# value (MWT_UNKNOWN) on either side as UNGRADED: counted and NAMED on its VERDICT line beside AGREE and DIVERGE, never a match.
#
# ⛔ THE DEFECT THIS GRADES (the cfo, CFO-152, 2026-09-23 07:4x; row monitor-the-controller-reads-an-untyped-value-as-agree-so-a-
# wrong-rat-passes-ungraded-is-a-named-count-never-a-match, dispatched to the coo by the ceo 13:4x). monitor_sync_bin.py's
# keys_match WILDCARDED type AND value bytes whenever either side sent MWT_UNKNOWN, so the pair read AGREE with nothing compared.
# rkx sends a Rat as UNKNOWN with no bytes, so a WRONG SCRIP Rat read AGREE; SPITBOL sends every TABLE, ARRAY, PATTERN, NAME,
# CODE and EXPRESSION as UNKNOWN, so anything SCRIP stored there read AGREE too, and monitor_run.sh then printed "agree
# event-for-event" over a run it had not measured. That is a property of every participant on the wire, not of Rakudo.
# ⭐ THE MEASURED RED, before the cure (SCRIP fb57f00ba): the committed witness ../harness/scripts/monitor/witnesses/sync_step_snobol4.sno
# read "[monitor_run] AGREE: participants spl scr agree event-for-event, clean termination at step 41" -- the cured controller
# reads it AGREE=39 DIVERGE=0 UNGRADED=2 (t: spl UNKNOWN | scr TABLE; a: spl UNKNOWN | scr ARRAY). Fail-once/pass-once receipt:
# the Makefile line that wires this gate.
#
# THE ARMS. 1-6 are HERMETIC: two synthetic participants speak the binary wire (13-byte header, NAME_DEF interning, one ack per
# record, END unacked -- monitor_ipc_lib.c's protocol) to the REAL controller, so no oracle, no build and no corpus is read.
#   1  THE ROW'S WITNESS: the oracle sends VALUE r UNKNOWN (a Rat, no bytes), SCRIP a WRONG REAL -> rc 0 and VERDICT
#      AGREE=3 DIVERGE=0 UNGRADED=1 of 4, r named. The pre-cure controller printed no VERDICT and read the run as AGREE.
#   2  the mirror: the untyped value on SCRIP's side -> UNGRADED=1 as well (either side, never only the oracle's).
#   3  an UNGRADED step before a real divergence is marked (u) in the grid, never shown as an agreed row, and counted.
#   4  kind and name are STILL graded under UNKNOWN: VALUE r UNKNOWN against VALUE s REAL diverges (rc 1).
#   5  a typed wrong value still diverges (REAL 1/3 against REAL 0.25) -- the cure loosened nothing.
#   6  a fully typed agreeing run reads AGREE=4 UNGRADED=0, so AGREE is a counted verdict too, not a silence.
#   Every VERDICT line is also checked for its identity AGREE + DIVERGE + UNGRADED == compared steps.
#   7  END TO END through the one command an HQ uses: monitor_run.sh <T = TABLE()> --oracle (spl scr) prints UNGRADED=1 naming
#      T and never "[monitor_run] AGREE:". Needs the SPITBOL fork and a fresh scrip; missing either is UNPROVEN (rc 2).
# GATE_MONITOR_CTRL overrides the controller arms 1-6 run (for the fail-once proof against a pre-cure copy).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=monitor_an_untyped_value_grades_ungraded_never_agree
GATE_STRICT=1
gate_parse_args "$@"
CTRL="${GATE_MONITOR_CTRL:-$HERE/monitor/monitor_sync_bin.py}"
gate_require "$CTRL" "the sync-step controller monitor_sync_bin.py" || exit 2
command -v python3 >/dev/null 2>&1 || { echo "REFUSING(2) [$GATE_NAME]: python3 is not on PATH"; exit 2; }
gate_require_exec "/home/resources/x64/bin/sbl" "the SPITBOL fork (arm 7's oracle)" || exit 2
gate_require_fresh "$ROOT" src "$ROOT/scrip" || exit 2

SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"
mkdir -p "$SCRATCH" || { echo "REFUSING(2) [$GATE_NAME]: cannot create $SCRATCH"; exit 2; }
WORK=$(mktemp -d "$SCRATCH/gate_monitor_ungraded_XXXXXX") || exit 2
trap '[ -n "${WORK:-}" ] && rm -rf "$WORK"' EXIT INT TERM

# One synthetic participant: argv READY GO RECORDS.json; records are [kind, name|null, type, value-hex].
cat > "$WORK/participant.py" <<'PY'
import json, os, struct, sys
ready, go, recs = sys.argv[1], sys.argv[2], json.load(open(sys.argv[3]))
rfd = os.open(ready, os.O_WRONLY)
gfd = os.open(go, os.O_RDONLY)
ids = {}
def emit(kind, nid, typ, val):
    os.write(rfd, struct.pack('<IIBI', kind, nid, typ, len(val)) + val)
    return kind == 4 or os.read(gfd, 1) == b'G'
for kind, name, typ, hexval in recs:
    nid = 0xffffffff
    if name is not None:
        if name not in ids:
            ids[name] = len(ids)
            if not emit(6, ids[name], 1, name.encode()):
                sys.exit(0)
        nid = ids[name]
    if not emit(kind, nid, typ, bytes.fromhex(hexval)):
        sys.exit(0)
PY

# Wire vocabulary: LABEL n, VALUE name type hex, RETURN name type hex, END.
L1='[5,null,2,"0100000000000000"]'; L2='[5,null,2,"0200000000000000"]'; END='[4,null,0,""]'
THIRD='"555555555555d53f"'; QUARTER='"000000000000d03f"'   # REAL 1/3 (the Rat's true value) and REAL 0.25 (a wrong one)
out=""; rc=0
# run_pair TAG ORACLE_RECORDS SCRIP_RECORDS -- the real controller between two synthetic participants; sets $out and $rc.
run_pair() {
    local d="$WORK/$1"; mkdir -p "$d"
    printf '%s\n' "$2" > "$d/orc.json"; printf '%s\n' "$3" > "$d/scr.json"
    local p; for p in orc scr; do mkfifo "$d/$p.ready" "$d/$p.go"; done
    timeout -k 5 60 python3 "$WORK/participant.py" "$d/orc.ready" "$d/orc.go" "$d/orc.json" > "$d/orc.err" 2>&1 & local po=$!
    timeout -k 5 60 python3 "$WORK/participant.py" "$d/scr.ready" "$d/scr.go" "$d/scr.json" > "$d/scr.err" 2>&1 & local ps=$!
    out=$(timeout -k 5 60 python3 "$CTRL" "orc:$d/orc.ready:$d/orc.go" "scr:$d/scr.ready:$d/scr.go" 2>&1); rc=$?
    kill "$po" "$ps" 2>/dev/null; wait "$po" "$ps" 2>/dev/null
    return 0
}
# verdict_is A D U N -- the VERDICT line carries exactly these counts and its identity holds.
verdict_is() {
    local v; v=$(printf '%s\n' "$out" | grep -oE 'VERDICT AGREE=[0-9]+ DIVERGE=[0-9]+ UNGRADED=[0-9]+ of [0-9]+' | head -1)
    [ -n "$v" ] || { why="the controller printed no VERDICT line (AGREE= DIVERGE= UNGRADED=)"; return 1; }
    local a d u n; read -r a d u n < <(printf '%s\n' "$v" | sed -E 's/VERDICT AGREE=([0-9]+) DIVERGE=([0-9]+) UNGRADED=([0-9]+) of ([0-9]+)/\1 \2 \3 \4/')
    [ $((a+d+u)) -eq "$n" ] || { why="the VERDICT identity fails: $a+$d+$u != $n"; return 1; }
    [ "$a $d $u $n" = "$1 $2 $3 $4" ] || { why="VERDICT reads AGREE=$a DIVERGE=$d UNGRADED=$u of $n, want AGREE=$1 DIVERGE=$2 UNGRADED=$3 of $4"; return 1; }
    return 0
}
fails=0; unproven=0; examined=0; why=""
# refused N -- true, and counted UNPROVEN, when the last run could not measure (rc 2: a participant never opened its FIFO pair;
# rc 124: a timeout). A run that could not measure is never a red and never a pass.
refused() {
    if [ "$rc" = 2 ] || [ "$rc" = 124 ]; then
        unproven=$((unproven+1)); echo "  UNPROVEN arm$1: could not measure (rc=$rc): $(printf '%s\n' "$out" | grep -a 'REFUS' | head -1 | cut -c1-160)"; return 0
    fi
    return 1
}
arm_fail() { fails=$((fails+1)); echo "  FAIL arm$1: $2"; printf '%s\n' "$out" | grep -a '\[ctrl\]' | grep -av 'opened ' | head -6 | sed 's/^/        /'; }

# ARM 1 -- THE ROW'S WITNESS: an untyped value on the oracle side against a wrong SCRIP value is UNGRADED=1, named, never AGREE.
examined=$((examined+1))
run_pair a1 "[$L1,[1,\"r\",255,\"\"],$L2,$END]" "[$L1,[1,\"r\",3,$QUARTER],$L2,$END]"
if refused 1; then :
elif [ "$rc" != 0 ]; then arm_fail 1 "rc=$rc, want 0 (no graded event diverged)"
elif ! verdict_is 3 0 1 4; then arm_fail 1 "$why -- the untyped step must be counted UNGRADED, never folded into AGREE (the pre-cure wildcard read this run as AGREE)"
elif ! printf '%s\n' "$out" | grep -qE 'VERDICT .*UNGRADED is never a match: r x1'; then arm_fail 1 "the VERDICT line does not NAME the ungraded value r"
elif ! printf '%s\n' "$out" | grep -qE '^\[ctrl\]   UNGRADED r x1, first at step 2 .*orc: VALUE r = UNKNOWN \| scr: VALUE r = REAL=0\.25'; then arm_fail 1 "no UNGRADED detail line showing both sides of r at step 2"
fi

# ARM 2 -- the mirror: the untyped value on SCRIP's side is UNGRADED too.
examined=$((examined+1))
run_pair a2 "[$L1,[1,\"r\",3,$THIRD],$L2,$END]" "[$L1,[1,\"r\",255,\"\"],$L2,$END]"
if refused 2; then :
elif [ "$rc" != 0 ]; then arm_fail 2 "rc=$rc, want 0"
elif ! verdict_is 3 0 1 4; then arm_fail 2 "$why"
fi

# ARM 3 -- an UNGRADED step in the last-agree trail is marked (u), never presented as an agreed row, and counted.
examined=$((examined+1))
run_pair a3 "[$L1,[1,\"r\",255,\"\"],[1,\"x\",1,\"61\"],$END]" "[$L1,[1,\"r\",3,$QUARTER],[1,\"x\",1,\"62\"],$END]"
if refused 3; then :
elif [ "$rc" != 1 ]; then arm_fail 3 "rc=$rc, want 1 (x = 'a' against x = 'b' diverges at step 3)"
elif ! verdict_is 1 1 1 3; then arm_fail 3 "$why"
elif ! printf '%s\n' "$out" | grep -qE '^\| \(u\)2 \|'; then arm_fail 3 "the ungraded step 2 is not marked (u) in the divergence grid -- it reads as an agreed row"
fi

# ARM 4 -- name and kind are still graded under UNKNOWN.
examined=$((examined+1)); a4=""
run_pair a4n "[$L1,[1,\"r\",255,\"\"],$END]" "[$L1,[1,\"s\",3,$QUARTER],$END]"
if refused 4; then :; elif ! { [ "$rc" = 1 ] && verdict_is 1 1 0 2; }; then a4="name mismatch under UNKNOWN: rc=$rc ${why}"; fi
run_pair a4k "[$L1,[1,\"r\",255,\"\"],$END]" "[$L1,[3,\"r\",3,$QUARTER],$END]"
if refused 4; then :; elif ! { [ "$rc" = 1 ] && verdict_is 1 1 0 2; }; then a4="${a4:+$a4; }kind mismatch under UNKNOWN: rc=$rc ${why}"; fi
[ -z "$a4" ] || arm_fail 4 "$a4 -- want rc 1 and AGREE=1 DIVERGE=1 UNGRADED=0 of 2"

# ARM 5 -- a typed wrong value still diverges.
examined=$((examined+1))
run_pair a5 "[$L1,[1,\"r\",3,$THIRD],$L2,$END]" "[$L1,[1,\"r\",3,$QUARTER],$L2,$END]"
if refused 5; then :
elif [ "$rc" != 1 ]; then arm_fail 5 "rc=$rc, want 1 (REAL 1/3 against REAL 0.25)"
elif ! verdict_is 1 1 0 2; then arm_fail 5 "$why"
fi

# ARM 6 -- a fully typed agreeing run is a COUNTED agreement.
examined=$((examined+1))
run_pair a6 "[$L1,[1,\"r\",3,$QUARTER],$L2,$END]" "[$L1,[1,\"r\",3,$QUARTER],$L2,$END]"
if refused 6; then :
elif [ "$rc" != 0 ]; then arm_fail 6 "rc=$rc, want 0"
elif ! verdict_is 4 0 0 4; then arm_fail 6 "$why"
fi

# ARM 7 -- end to end through monitor_run.sh against the SPITBOL fork, which sends a TABLE untyped.
examined=$((examined+1))
printf '        T = TABLE()\n        X = "ok"\nEND\n' > "$WORK/untyped_table.sno"
out=$(timeout -k 5 120 bash "$HERE/monitor_run.sh" "$WORK/untyped_table.sno" --oracle 2>&1); rc=$?
if refused 7; then :
elif printf '%s\n' "$out" | grep -q '^\[monitor_run\] AGREE:'; then arm_fail 7 "monitor_run.sh printed AGREE over a run whose TABLE was never compared: $(printf '%s\n' "$out" | grep '^\[monitor_run\] AGREE:' | cut -c1-160)"
elif [ "$rc" != 0 ]; then arm_fail 7 "rc=$rc, want 0: $(printf '%s\n' "$out" | tail -1 | cut -c1-160)"
elif ! printf '%s\n' "$out" | grep -qE '^\[monitor_run\] UNGRADED=1: .*\(AGREE=5 DIVERGE=0 UNGRADED=1\)'; then arm_fail 7 "no '[monitor_run] UNGRADED=1' verdict with AGREE=5 DIVERGE=0 UNGRADED=1: $(printf '%s\n' "$out" | tail -2 | cut -c1-160)"
elif ! printf '%s\n' "$out" | grep -qE '^   UNGRADED T x1, first at step 2 .*spl: VALUE T = UNKNOWN \| scr: VALUE T = TABLE'; then arm_fail 7 "the verdict does not NAME the untyped TABLE T"
fi

GATE_EXAMINED=$examined
# A red that was measured is a red whatever else could not be; with no red, one arm that could not measure makes the gate UNPROVEN.
if [ "$fails" -eq 0 ] && [ "$unproven" -gt 0 ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: $unproven run(s) could not measure, 0 arm(s) failed -- NOT a pass (examined $examined)"; gate_stamp; exit 2
fi
gate_verdict "$fails" "arm(s) failed (an untyped value must grade UNGRADED, counted and named, never AGREE)"
