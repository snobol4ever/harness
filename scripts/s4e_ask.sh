#!/usr/bin/env bash
# s4e_ask.sh -- fleet-queue step 8 (the cio's design, skill fleet-bus section 8; the coo's assignment 2026-11-05): an ASK is a JOB in the
# tube above the asker, answered by the first free senior, and its answer kicks the asking row. No HQ file, no one addressee.
#   s4e_msg.sh ask <topic> --stdin        (or the question as one argument): the question row q-<topic>-<n> is minted, its job goes into
#                                         ask-<the tier above the asker> at priority 100, and the asking row <topic> is parked BLOCKED-ON:q-...
#   s4e_msg.sh answer <q-topic> --stdin   the answering seat takes the question, claims it, writes its ANSWER: line and runs done; done
#                                         unblocks the asker (its job is kicked, a telegram goes to its owner: fleet-queue step 6 and box-scheduler 35)
#   s4e_msg.sh ask --probe-queue          step 8's probe. It starts its OWN beanstalkd on a private port and a scratch postoffice, and kills
#                                         the daemon it spawned when it ends: the live queue and the live postoffice are never written.
# Printed lines: "ASK q=<q-topic> tube=<ask-tube> pri=100 job=<id> blocked=<asker>"; the probe prints the line the step table reads.
# Env, set by s4e_msg.sh: S4E_POST (the postoffice), S4E_SEAT (this seat), S4E_HOME (the root). S4E_TIERS names the tier table.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib_wake.sh"   # THE WAKE LINE (the cio 2026-11-08): ask and answer end by naming the session to SendMessage
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
PO="${S4E_POST:-/home/resources/postoffice}"
ME="${S4E_SEAT:-}"
TIERS="${S4E_TIERS:-$S4E/.github/TIERS.tsv}"
BUS="$HERE/s4e_msg.sh"
UQ="$HERE/util_queue.py"
VERB="${1:-}"; shift || true

refuse() { echo "REFUSE(2) [$VERB]: $*" >&2; exit 2; }

# The tier of a seat is column 7 of the tiers table (1 fable, 2 opus, 3 sonnet, 4 haiku); the ask tube is the tier ABOVE the asker.
tier_name_of() {
    case "$(awk -F'\t' -v s="$1" '!/^#/ && $1==s {print $7; exit}' "$TIERS" 2>/dev/null)" in
        1) echo fable;; 2) echo opus;; 3) echo sonnet;; 4) echo haiku;; *) return 1;; esac; }
tier_above_of() {
    case "$1" in opus) echo fable;; sonnet) echo opus;; haiku) echo sonnet;; *) return 1;; esac; }

queue_row_of() { awk -F'\t' -v t="$1" '!/^#/ && $2==t {print; exit}' "$PO/QUEUE.tsv" 2>/dev/null; }

# The one column rewrite: read all, write a temporary, refuse a changed row count, move it into place.
queue_set_state() {   # <topic> <state>
    local q="$PO/QUEUE.tsv" t
    t="$(mktemp "$q.ask.XXXXXX")" || return 1
    awk -F'\t' -v OFS='\t' -v tp="$1" -v st="$2" '$2==tp && !/^#/ {$4=st} {print}' "$q" > "$t" \
        && [ "$(wc -l < "$t")" -eq "$(wc -l < "$q")" ] && mv -f "$t" "$q" && return 0
    rm -f "$t"; return 1; }

# Park and claim and done are the bus's own verbs, run as subprocesses: the step 6 and step 35 logic stays in one place.
bus() { env -u S4E_PID_LOCK S4E_POST="$PO" S4E_SEAT="$ME" S4E_HOME="$S4E" S4E_NO_BANNER=1 bash "$BUS" "$@"; }
bus_as_holder() { S4E_POST="$PO" S4E_SEAT="$ME" S4E_HOME="$S4E" S4E_NO_BANNER=1 bash "$BUS" "$@"; }   # keeps S4E_PID_LOCK: a child of the verb that holds the identity passes the one-process guard as its descendant (the secretary 2026-11-07 15:56: answer ran done without the marker and was refused by its own lock, so the question stayed CLAIMED and the answer was never delivered)

ask_queue() {   # <asker-topic> <question text>
    local topic="$1" body="$2" tier above tube n qt base j row
    [ -n "$ME" ] || refuse "S4E_SEAT unset"
    [ -n "$topic" ] || refuse "a topic: s4e_msg.sh ask <topic> --stdin"
    [ -n "$(printf '%s' "$body" | tr -d '[:space:]')" ] || refuse "ask carries no question: give it in quotes or on stdin. Nothing sent."
    tier="$(tier_name_of "$ME")" || refuse "$ME is not in the tiers table ($TIERS)"
    above="$(tier_above_of "$tier")" || refuse "no tier above fable: a fable's question goes to Lon through the cio (the top of the escalation, fleet-queue step 9)"
    tube="ask-$above"
    if [ "$above" = fable ]; then _ob="$(s4e_operating_boss)"; [ -n "$_ob" ] && [ "$ME" != "$_ob" ] && tube="seat-$_ob"; fi   # COO-496: only the operating boss asks the fable tier
    row="$(queue_row_of "$topic")"; [ -n "$row" ] || refuse "no QUEUE row for $topic: the asking row must exist before it can be blocked"
    n=1; while [ -e "$PO/tasks/q-$topic-$n.task.md" ] || [ -n "$(queue_row_of "q-$topic-$n")" ]; do n=$((n+1)); done
    qt="q-$topic-$n"; base="$PO/tasks/$qt.task.md"
    # the job first: a refused put leaves no row and no baton behind
    j="$(python3 "$UQ" put "$tube" "$qt" --pri 100 --ttr 7200 2>/dev/null)" || j=""
    [ -n "$j" ] || refuse "the put into $tube failed (python3 harness/scripts/util_queue.py status tells why); nothing was written"
    {
        printf '# TASK %s\n' "$qt"
        printf 'GOAL: question from %s for %s: %s\n' "$ME" "$topic" "$(printf '%s' "$body" | head -1 | cut -c1-200)"
        printf 'DONE-WHEN: cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" && grep -q "^ANSWER: " "%s"\n' "$base"
        printf 'PREMISE-WHEN: cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" && ! grep -q "^ANSWER: " "%s"\n' "$base"
        printf 'SKILLS: fleet-bus\nTOUCHES: harness/scripts/s4e_ask.sh\nBUDGET: 7200\n'
        printf 'LINKS: asked by %s for %s (fleet-queue step 8)\nASKED-BY: %s\nASKED-ROW: %s\nQUEUE-JOB: %s tube=%s\n' "$ME" "$topic" "$ME" "$topic" "$j" "$tube"
        printf '## NEXT\nAnswer it: s4e_msg.sh answer %s --stdin (the answer unblocks %s).\n## QA\n' "$qt" "$topic"
        printf '%s\n' "$body" | sed 's/^/> /'
        printf '## LEDGER\n- [%s %s] asked: job %s in %s at pri 100; %s parked BLOCKED-ON:%s\n' "$ME" "$(date -u +%FT%TZ)" "$j" "$tube" "$topic" "$qt"
    } > "$base" || refuse "could not write the question baton $base"
    printf '%s\t%s\t%s\tASKED:%s\n' 2 "$qt" "$ME" "$tube" >> "$PO/QUEUE.tsv" || refuse "could not add $qt to QUEUE.tsv"
    if ! bus park "$topic" "BLOCKED-ON:$qt" >/dev/null 2>&1; then
        echo "ASK PARTIAL: q=$qt job=$j is queued in $tube, but $topic was NOT parked: run s4e_msg.sh park $topic BLOCKED-ON:$qt" >&2; exit 1; fi
    echo "ASK q=$qt tube=$tube pri=100 job=$j blocked=$topic"; s4e_wake_hint "$tube" "$qt" ask; }

answer_q() {   # <q-topic> <answer text>
    local q="$1" body="$2" base row st tmpb t rc claim_first=0
    [ -n "$ME" ] || refuse "S4E_SEAT unset"
    case "$q" in q-*) ;; *) refuse "$q is not a question row (q-<asker>-<n>)";; esac
    base="$PO/tasks/$q.task.md"; [ -f "$base" ] || refuse "no baton for $q"
    grep -q '^ANSWER: ' "$base" && refuse "$q is already answered"
    [ -n "$(printf '%s' "$body" | tr -d '[:space:]')" ] || refuse "an answer carries no text. Nothing written."
    row="$(queue_row_of "$q")"; [ -n "$row" ] || refuse "no QUEUE row for $q"
    st="$(printf '%s' "$row" | cut -f4)"
    case "$st" in
        ASKED:*) queue_set_state "$q" "ASSIGNED:$ME" || refuse "could not take $q"; claim_first=1;;
        ASSIGNED:"$ME") claim_first=1;;
        CLAIMED:"$ME") claim_first=0;;   # a senior's next reserved the question's job and already holds the claim
        *) refuse "$q is $st, not an open ask";;
    esac
    # the claim's premise is the unanswered question, so it is taken before the answer is written; a refused claim gives the row back as it was
    if [ "$claim_first" = 1 ] && ! bus claim "$q" >/dev/null 2>&1; then
        queue_set_state "$q" "$st"; refuse "claim of $q refused (s4e_msg.sh claim $q shows why)"; fi
    tmpb="$(mktemp)" || refuse "mktemp failed"
    printf '%s\n' "$body" | awk 'NR==1 {sub(/^ANSWER: */, ""); print "ANSWER: " $0; next} {print}' > "$tmpb"   # a body that begins with its own ANSWER: marker is not doubled
    t="$(mktemp "$base.ask.XXXXXX")" || refuse "mktemp failed"
    awk -v f="$tmpb" 'BEGIN{ins=0} /^## / && !ins { while ((getline l < f) > 0) print l; ins=1 } {print}' "$base" > "$t" && mv -f "$t" "$base"
    rm -f "$tmpb"
    grep -q '^ANSWER: ' "$base" || refuse "could not write the ANSWER line into $base"
    bus_as_holder done "$q"; rc=$?
    [ "$rc" = 0 ] && s4e_wake_hint "seat-$(sed -n 's/^ASKED-BY: *//p' "$base" | head -1)" "$q" answer   # the asker is parked BLOCKED-ON this question: the answer wakes it
    return "$rc"; }

ask_probe() {
    [ -n "$ME" ] || { echo "REFUSE(2) [ask --probe-queue]: S4E_SEAT unset"; exit 2; }
    local w port bpid why="" A jA out q tube j stt st o2 brc kicked stj n0 n1 blocked telegram ready=0 i arc
    w="$(mktemp -d "${TMPDIR:-/tmp}/s4e_ask.XXXXXX")" || { echo "REFUSE(2) [ask --probe-queue]: mktemp failed"; exit 2; }
    port=$((21000 + ($$ % 20000)))
    beanstalkd -l 127.0.0.1 -p "$port" >/dev/null 2>&1 & bpid=$!
    trap 'kill "$bpid" 2>/dev/null; wait "$bpid" 2>/dev/null; rm -rf "$w"' EXIT
    # status exits 1 on a daemon with no binlog (the scratch one): readiness is the status LINE, not its exit code
    for i in $(seq 1 50); do
        sl="$(S4E_QUEUE_PORT="$port" python3 "$UQ" status 2>/dev/null)"
        case "$sl" in "QUEUE daemon=beanstalkd"*) ready=1; break;; esac; sleep 0.1; done
    [ "$ready" = 1 ] || { echo "REFUSE(2) [ask --probe-queue]: a scratch beanstalkd would not start on port $port"; exit 2; }
    export S4E_QUEUE_PORT="$port"
    # ⛔ THE PROBE ASKS AS A PLANTED HAIKU SEAT (the cio's cut, 2026-11-07, fleet-queue step 8): the live seat's own tier is not the probe's subject, so the step reads
    # the same from every root. Its tiers table is scratch: probe-haiku is tier 4, so the tube above it is ask-sonnet, computed from that table, not assumed.
    ME="probe-haiku"
    printf 'seat\tname\troot\tmodel\teffort\tcolor\ttier\trole\nprobe-haiku\tPROBE\t/x\tclaude-haiku-5-5\txhigh\tcyan\t4\tprobe\n' > "$w/TIERS.tsv"
    export S4E_TIERS="$w/TIERS.tsv"
    mkdir -p "$w/claims" "$w/tasks" "$w/$ME/inbox" || { echo "REFUSE(2) [ask --probe-queue]: cannot make the scratch postoffice"; exit 2; }
    { head -1 "$PO/MODE" 2>/dev/null || echo TENET; echo "# probe"; grep -E '^(ROSTER|LANES|ORDER-OF-WORK|BOSSES|ON-CALL):' "$PO/MODE" 2>/dev/null; } > "$w/MODE"
    sed -i 's/^ROSTER: /ROSTER: probe-haiku /' "$w/MODE"   # the planted seat is a standing seat of the scratch roster, so its restored state is ASSIGNED, as a live seat's is
    A="ask-probe-asker-$$"
    jA="$(python3 "$UQ" put "seat-$ME" "$A" --pri 1000 --ttr 3600 2>/dev/null)" || jA=""
    [ -n "$jA" ] || { echo "REFUSE(2) [ask --probe-queue]: no job could be put on the scratch daemon"; exit 2; }
    printf '2\t%s\t%s\tASSIGNED:%s\n' "$A" "$ME" "$ME" > "$w/QUEUE.tsv"
    printf '# TASK %s\nGOAL: plant\nDONE-WHEN: test -f "$S4E_HOME/harness/scripts/s4e_msg.sh"\nLINKS: plant\nQUEUE-JOB: %s tube=seat-%s\n## NEXT\nplant\n## QA\n## LEDGER\n- [plant] minted\n' "$A" "$jA" "$ME" > "$w/tasks/$A.task.md"
    printf '%s\nRUNNING\n' "$ME" > "$w/claims/$A.claim"
    n0="$(ls "$w/$ME/inbox" | wc -l)"
    pe() { env -u S4E_PID_LOCK S4E_POST="$w" S4E_SEAT="$ME" S4E_HOME="$S4E" S4E_NO_BANNER=1 "$@"; }
    out="$(pe bash "$HERE/s4e_ask.sh" ask "$A" --stdin <<< 'probe question: is the queue answered?' 2>&1)"; arc=$?
    q="$(printf '%s' "$out" | sed -n 's/^ASK q=\([^ ]*\) .*/\1/p')"
    tube="$(printf '%s' "$out" | sed -n 's/^ASK q=[^ ]* tube=\([^ ]*\) .*/\1/p')"
    j="$(printf '%s' "$out" | sed -n 's/.* job=\([0-9][0-9]*\) .*/\1/p')"
    [ "$arc" = 0 ] && [ -n "$q" ] || why="$why ask rc $arc [$(printf '%s' "$out" | tail -1 | cut -c1-120)];"
    stt=""; [ -n "$j" ] && stt="$(python3 "$UQ" stats-job "$j" 2>/dev/null)"
    [ "$(printf '%s' "$stt" | cut -f2)" = "$tube" ] && [ "$(printf '%s' "$stt" | cut -f4)" = 100 ] || why="$why the question job is not in ${tube:-?} at pri 100 [$stt];"
    st="$(awk -F'\t' -v t="$A" '$2==t {print $4; exit}' "$w/QUEUE.tsv")"
    blocked=0; [ -n "$q" ] && [ "$st" = "BLOCKED-ON:$q" ] && blocked=1
    [ "$blocked" = 1 ] || why="$why the asker is [$st], not BLOCKED-ON:${q:-?};"
    o2="$(pe bash "$HERE/s4e_ask.sh" answer "${q:-none}" --stdin <<< 'probe answer' 2>&1)"; brc=$?
    [ "$brc" = 0 ] || why="$why answer rc $brc [$(printf '%s' "$o2" | tail -1 | cut -c1-120)];"
    stj="$(python3 "$UQ" stats-job "$jA" 2>/dev/null | cut -f3)"
    kicked=0; [ "$stj" = ready ] && printf '%s' "$o2" | grep -q "kicked_by=done job=$jA" && kicked=1
    [ "$kicked" = 1 ] || why="$why the answer did not kick the asker's job (its state is [$stj]);"
    st="$(awk -F'\t' -v t="$A" '$2==t {print $4; exit}' "$w/QUEUE.tsv")"
    [ "$st" = "ASSIGNED:$ME" ] || why="$why the asker is [$st] after the answer, not ASSIGNED:$ME;"
    n1="$(ls "$w/$ME/inbox" | wc -l)"; telegram=0; [ "$n1" -gt "$n0" ] && telegram=1
    [ "$telegram" = 1 ] || why="$why no telegram reached the asker;"
    if [ -z "$why" ]; then echo "ASK tube=$tube pri=100 blocked=$blocked answered_by=any kicked=$kicked telegram=$telegram"; exit 0; fi
    echo "ASK PROBE RED:$why"; printf '%s\n' "$out" | tail -3 | sed 's/^/  | /'; printf '%s\n' "$o2" | tail -3 | sed 's/^/  | /'; exit 1; }

case "$VERB" in
    ask)
        if [ "${1:-}" = --probe-queue ]; then ask_probe; exit $?; fi
        topic="${1:-}"; shift || true
        if [ "${1:-}" = --stdin ]; then body="$(cat)"; else body="$*"; fi
        ask_queue "$topic" "$body"; exit $? ;;
    answer)
        q="${1:-}"; shift || true
        if [ "${1:-}" = --stdin ]; then body="$(cat)"; else body="$*"; fi
        answer_q "$q" "$body"; exit $? ;;
    *) echo "usage: s4e_ask.sh ask <topic> --stdin | answer <q-topic> --stdin | ask --probe-queue" >&2; exit 2 ;;
esac
