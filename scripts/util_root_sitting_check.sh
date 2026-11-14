#!/usr/bin/env bash
# util_root_sitting_check.sh ROOT SEAT -- THE CUTOVER'S PROOF: a seat's whole sitting, run as SEAT in ROOT, each step PASS or FAIL with its first error line
# (row harness-a-tool-runs-a-seats-whole-sitting-in-its-root, officer_05 2026-11-13; the coo's lesson of 20:2x CST: every grep pass found a sibling form the last
# one missed, so no pattern is the proof; a seat's full sitting run in a root that holds only its clone is; the cutover is row harness-one-disk-step-6-the-cutover).
# THE STEPS, in a sitting's order (skill fleet-bus 7): sync (util_sync_root.sh); make (make -j8 in the clone, S4E_SCRIP); whoami, check, next (the bus verbs);
# grade:<lang> (corpus_suite_harness.py run of the first entry of each master of SUITE_RUNNERS.tsv, mode 3); hook:inbox, hook:banner, hook:gate (the three hooks
# exactly as ROOT/.claude/settings.json and settings.local.json call them, fed a synthetic event); land (s4e_land.sh --probe-root-home).
# The bus verbs, the hooks and the landing probe run against a SCRATCH POSTOFFICE (a copy of the live one's top-level files, tasks, claims and the seat's own
# folder, its MODE keyed FLEET: LIVE), so next serves from a copy and claims nothing live, check reads nothing live as read, and the seat's identity lock is
# never taken; a grade records into a scratch progress file (S4E_PROGRESS_DB). The scripts run are the ones the sitting names: the bus verbs, the grades and
# the landing probe from the harness lib_paths.sh resolves for ROOT (/home/harness once it is a checkout); the hooks as the root's settings render them.
# It writes nothing outside /tmp/s4e/SEAT and ROOT (the sync and the make write there, as a sitting does).
# OUTPUT: one `STEP <name> PASS|FAIL <secs>s: <first error line, or a summary>` line a step, then `ROOT_SITTING ok steps=N` (rc 0) or
# `ROOT_SITTING RED failed=<names>` (rc 1); REFUSE(2) when it cannot measure (no root, no seat, no scratch). S4E_SITTING_SKIP="make grade" skips named steps
# (each printed SKIP, and a skip is never ok: the tool then ends RED).
set -u
ROOT="${1:-}"; SEAT="${2:-}"
refuse() { echo "REFUSE(2) [util_root_sitting_check]: $*"; exit 2; }
[ -n "$ROOT" ] && [ -n "$SEAT" ] || refuse "usage: util_root_sitting_check.sh ROOT SEAT"
[ -d "$ROOT" ] || refuse "no root $ROOT"
ROOT="$(cd -P "$ROOT" && pwd)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVE_PO="${S4E_POST:-/home/resources/postoffice}"
[ -f "$LIVE_PO/QUEUE.tsv" ] || refuse "no postoffice at $LIVE_PO"
mkdir -p "/tmp/s4e/$SEAT" && W="$(mktemp -d "/tmp/s4e/$SEAT/root_sitting.XXXXXX")" || refuse "cannot make a scratch under /tmp/s4e/$SEAT"
# THE PATHS AS THE SEAT'S SITTING RESOLVES THEM: lib_paths.sh with S4E_HOME the root and nothing inherited
eval "$(env -u S4E_SCRIP -u S4E_CORPUS -u S4E_HARNESS -u S4E_GITHUB S4E_HOME="$ROOT" bash -c '. "$1/lib_paths.sh" && printf "P_SCRIP=%q P_CORPUS=%q P_HARNESS=%q P_GITHUB=%q\n" "$S4E_SCRIP" "$S4E_CORPUS" "$S4E_HARNESS" "$S4E_GITHUB"' _ "$HERE")" \
    || refuse "lib_paths.sh did not resolve the paths for $ROOT"
[ -n "${P_HARNESS:-}" ] && [ -n "${P_SCRIP:-}" ] || { rm -rf "$W"; refuse "lib_paths.sh beside this tool ($HERE) resolved no paths for $ROOT"; }
H="$P_HARNESS/scripts"
# THE SCRATCH POSTOFFICE: top-level files (no held lock, no lander place), tasks, claims, the seat's folder; MODE keyed FLEET: LIVE
PO="$W/po"; mkdir -p "$PO" || refuse "cannot make the scratch postoffice"
for f in "$LIVE_PO"/* "$LIVE_PO"/.[!.]*; do
    b="$(basename "$f")"
    case "$b" in .mint.lock|.land.line.*|.queue.flock|*.bak*|*.tar.gz) continue;; esac
    if [ -f "$f" ]; then [ "$(stat -c %s "$f")" -lt 20000000 ] && cp -p "$f" "$PO/$b" 2>/dev/null
    elif [ -d "$f" ]; then case "$b" in tasks|claims|"$SEAT") cp -rp "$f" "$PO/$b" 2>/dev/null;; esac; fi
done
mkdir -p "$PO/$SEAT/inbox" "$PO/claims" "$PO/tasks"
[ -f "$PO/MODE" ] && { grep -v '^FLEET:' "$PO/MODE" > "$PO/MODE.t"; echo 'FLEET: LIVE' >> "$PO/MODE.t"; mv "$PO/MODE.t" "$PO/MODE"; }
# one environment for every step: the seat's own, as its session has it, the path variables unset so each script resolves them itself
run_env() { env -u S4E_SCRIP -u S4E_CORPUS -u S4E_HARNESS -u S4E_GITHUB -u S4E_PID_LOCK -u S4E_NO_BANNER S4E_HOME="$ROOT" S4E_SEAT="$SEAT" S4E_POST="$PO" \
    CLAUDE_PROJECT_DIR="$ROOT" TMPDIR="$W/tmp" "$@"; }
mkdir -p "$W/tmp"
ERR='error|Error|ERROR|REFUSE|REFUSING|No such file|not found|NOT FOUND|Traceback|cannot|FAILED|⛔'
failed=""; n=0
step() {   # <name> <rc> <secs> <log> [<pass-summary>]: PASS on rc 0, else FAIL with the first error line of the log
    local name="$1" rc="$2" secs="$3" log="$4" sum="${5:-}" first
    n=$((n + 1))
    if [ "$rc" = 0 ]; then echo "STEP $name PASS ${secs}s: ${sum:-rc 0}"; return 0; fi
    first="$(grep -aE -m1 "$ERR" "$log" 2>/dev/null | cut -c1-200)"; [ -n "$first" ] || first="$(grep -a . "$log" 2>/dev/null | tail -1 | cut -c1-200)"
    echo "STEP $name FAIL ${secs}s: rc $rc: ${first:-no output}"; failed="$failed $name"; return 1; }
skipped() { case " ${S4E_SITTING_SKIP:-} " in *" $1 "*) n=$((n + 1)); echo "STEP $1 SKIP: S4E_SITTING_SKIP names it (a skipped step is not ok)"; failed="$failed $1(skipped)"; return 0;; esac; return 1; }
timed() {   # <log> <cmd...>: runs it from the root in the seat's environment, sets RC and SECS
    local log="$1" t0; shift; t0=$(date +%s)
    ( cd "$ROOT" && run_env setsid -w "$@" ) > "$log" 2>&1 < /dev/null; RC=$?; SECS=$(( $(date +%s) - t0 )); }   # its own session: a signal a step sends its process group never reaches this tool

# 1. sync
skipped sync || { timed "$W/sync.log" bash "$H/util_sync_root.sh"; step sync "$RC" "$SECS" "$W/sync.log" "$(grep -c '^SYNC ' "$W/sync.log") repo(s): $(sed -n 's/^SYNC \([^ ]*\) .*/\1/p' "$W/sync.log" | tr '\n' ' ')"; }
# 2. make, in the clone
skipped make || { if [ -f "$P_SCRIP/Makefile" ]; then timed "$W/make.log" timeout -k 30 1800 make -j8 -C "$P_SCRIP"; else echo "no Makefile in S4E_SCRIP=$P_SCRIP" > "$W/make.log"; RC=2; SECS=0; fi
    step make "$RC" "$SECS" "$W/make.log" "make -j8 in $P_SCRIP"; }
# 3. the bus verbs: whoami, check, next (from the scratch postoffice; served there, nothing claimed live)
for v in whoami check next; do
    skipped "$v" && continue
    timed "$W/$v.log" timeout -k 10 600 bash "$H/s4e_msg.sh" "$v"
    case "$v" in
        whoami) [ "$RC" = 0 ] && ! grep -qF "$SEAT" "$W/$v.log" && { echo "whoami did not name $SEAT" >> "$W/$v.log"; RC=1; }; sum="names $SEAT";;
        next) sum="served: $(grep -aoE -m1 'claimed [A-Za-z0-9_.-]+|serving [A-Za-z0-9_.-]+|served [A-Za-z0-9_.-]+' "$W/$v.log" || echo 'nothing (tube empty)')"
              [ "$RC" = 1 ] && grep -aq '^QUEUE EMPTY' "$W/$v.log" && { RC=0; sum="served: nothing (QUEUE EMPTY, next's rc 1 for nothing to serve)"; };;
        *) sum="rc 0";;
    esac
    [ "$RC" = 0 ] && grep -aqE 'REFUSING TO DISPATCH|No such file|NOT FOUND' "$W/$v.log" && RC=1
    step "$v" "$RC" "$SECS" "$W/$v.log" "$sum"
done
# 4. one grade per language family: the first entry of each master, mode 3, the progress record into the scratch
if ! skipped grade; then
    RUNNERS="$H/SUITE_RUNNERS.tsv"
    if [ ! -f "$RUNNERS" ]; then n=$((n + 1)); echo "STEP grade FAIL 0s: no $RUNNERS"; failed="$failed grade"
    else
        while IFS=$'\t' read -r key kind lang _tool _dir; do
            case "$key" in ''|\#*) continue;; esac; [ "$kind" = master ] || continue
            ext="$(case "$lang" in snobol4) echo sno;; icon) echo icn;; prolog) echo pl;; pascal) echo pas;; raku) echo raku;; rebus) echo reb;; snocone) echo sc;; *) echo "$lang";; esac)"
            d="$P_CORPUS/tests/$lang"; e="$(awk -F, 'NR==2 {print $2; exit}' "$d/ALL.csv" 2>/dev/null)"
            if [ -z "$e" ]; then n=$((n + 1)); echo "STEP grade:$lang FAIL 0s: no first entry in $d/ALL.csv"; failed="$failed grade:$lang"; continue; fi
            timed "$W/grade.$lang.log" env S4E_PROGRESS_DB="$W/progress.tsv" SCRIP="$P_SCRIP/scrip" RT_DIR="$P_SCRIP/out" SUITE_LIST_ALL=1 \
                bash "$H/util_run_slot.sh" timeout -k 30 600 python3 "$H/corpus_suite_harness.py" run "$d/ALL.$ext" "$d/ALL.ref" --lang "$lang" --modes m3 --partition "entry:$e"
            b="$(grep -a -m1 '^SUITE_BOARD' "$W/grade.$lang.log")"
            [ -n "$b" ] || { [ "$RC" = 0 ] && RC=1; echo "no SUITE_BOARD line" >> "$W/grade.$lang.log"; }
            [ "$RC" = 1 ] && [ -n "$b" ] && RC=0   # a graded red is SCRIP's, not the root's: the step proves the grade ran and wrote its board line
            step "grade:$lang" "$RC" "$SECS" "$W/grade.$lang.log" "$e: $(printf '%s' "$b" | grep -oE 'm3_n=[0-9]+ m3_pass=[0-9]+')"
        done < "$RUNNERS"
    fi
fi
# 5. the three hooks as the root's settings call them
hookcmd() {   # <event> <file>...: the first hook command of that event in the root's settings files
    python3 -I -c '
import json, sys
ev = sys.argv[1]
for f in sys.argv[2:]:
    try: d = json.load(open(f))
    except Exception: continue
    for e in d.get("hooks", {}).get(ev, []):
        for h in e.get("hooks", []):
            if h.get("command"): print(h["command"]); sys.exit(0)
' "$@"; }
S1="$ROOT/.claude/settings.json"; S2="$ROOT/.claude/settings.local.json"
: > "$W/transcript.jsonl"
hook() {   # <name> <event> <stdin json> <check>: runs the hook command; <check> is a grep -E the output must match
    local name="$1" ev="$2" in="$3" want="$4" c t0
    skipped "$name" && return 0
    c="$(hookcmd "$ev" "$S1" "$S2")"
    if [ -z "$c" ]; then n=$((n + 1)); echo "STEP $name FAIL 0s: no $ev hook in $S1 or $S2"; failed="$failed $name"; return; fi
    t0=$(date +%s); ( cd "$ROOT" && printf '%s' "$in" | run_env setsid -w timeout -k 10 200 bash -c "$c" ) > "$W/$name.log" 2>&1; RC=$?; SECS=$(( $(date +%s) - t0 ))
    if [ "$name" = hook:gate ]; then   # the gate refuses (rc 2) an edit of a gated file with no skill loaded; any other rc is a gate that did not fire
        [ "$RC" = 2 ] && grep -aqiE 'skill' "$W/$name.log" && RC=0 || { echo "the gate did not refuse an edit of $P_SCRIP/src/lower/lower_icon.c with no skill loaded (rc $RC)" >> "$W/$name.log"; [ "$RC" = 0 ] && RC=1; }
        step "$name" "$RC" "$SECS" "$W/$name.log" "refused the unloaded-skill edit, rc 2"; return; fi
    [ "$RC" = 0 ] && { grep -aqE "$want" "$W/$name.log" && ! grep -aqE 'No such file|NOT FOUND' "$W/$name.log"; } || { [ "$RC" = 0 ] && RC=1; grep -aqE "$want" "$W/$name.log" || echo "the hook's output does not match: $want" >> "$W/$name.log"; }
    step "$name" "$RC" "$SECS" "$W/$name.log" "rc 0, $(grep -aoE "$want" "$W/$name.log" | head -1 | grep -oE '\[[a-z_0-9]+\]|SUCCESS|IN-PROGRESS|NOTHING|FAILURE|STOP|DRAIN' | head -1)"; }
hook hook:inbox UserPromptSubmit '{"hook_event_name":"UserPromptSubmit","prompt":"sitting check"}' "POSTOFFICE \\[$SEAT\\]|\\[$SEAT\\] [0-9]+ read, not cleared"   # the inbox hook's three forms: unread, empty (both POSTOFFICE [seat]), read and not cleared ([seat] N read, not cleared)
hook hook:banner Stop '{"hook_event_name":"Stop","stop_hook_active":false}' 'systemMessage.*(SUCCESS|IN-PROGRESS|NOTHING|FAILURE|STOP|DRAIN)'
hook hook:gate PreToolUse "{\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$P_SCRIP/src/lower/lower_icon.c\",\"old_string\":\"a\",\"new_string\":\"b\"},\"transcript_path\":\"$W/transcript.jsonl\",\"cwd\":\"$ROOT\"}" .
# 6. the landing from the root, on its own scratch
skipped land || { timed "$W/land.log" timeout -k 10 900 bash "$H/s4e_land.sh" --home "$ROOT" --probe-root-home   # --home as a seat lands (s4e_land.sh's own default is its harness's parent)
    [ "$RC" = 0 ] && ! grep -aq 'root-home-probe ok' "$W/land.log" && { echo "no LAND root-home-probe ok line" >> "$W/land.log"; RC=1; }
    step land "$RC" "$SECS" "$W/land.log" "LAND root-home-probe ok"; }
if [ -z "$failed" ]; then rm -rf "$W"; echo "ROOT_SITTING ok steps=$n root=$ROOT seat=$SEAT harness=$P_HARNESS scrip=$P_SCRIP"; exit 0; fi
echo "ROOT_SITTING RED failed=${failed# } steps=$n root=$ROOT seat=$SEAT harness=$P_HARNESS scrip=$P_SCRIP logs=$W"; exit 1
