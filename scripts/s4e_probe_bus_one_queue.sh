#!/usr/bin/env bash
# s4e_probe_bus_one_queue.sh -- THE PROBES OF DESIGN-PLAN bus-one-queue (CIO-8 phase two: the queue daemon goes, QUEUE.tsv under one flock is the one queue;
# designed by the cio, cut by officer_05 2026-11-08, the eight choices answered by the cio on q-bus-one-source-of-truth-...-cio-8-phase-two-1).
# The table is corpus/tests/shared/bus_one_queue/STEPS.tsv; test_design_bus_one_queue_steps.sh --step N runs "bash harness/scripts/s4e_probe_bus_one_queue.sh N".
# EVERY PROBE RUNS ON A SCRATCH POSTOFFICE (S4E_POST under /tmp/s4e/<seat>/), a scratch TIERS table (junior_97 haiku, senior_97 sonnet, officer_97 opus) and
# the file road, since 2026-11-10 the only road (the acceptance, CIO-82). The live queue and the live batons
# are never read or written. A seat's claude process is a copy of sleep named claude in a scratch scope dir (S4E_SEAT_SCOPES), so the claim pid
# is read from cgroup.procs exactly as on the box (answer Q3 as amended: the pid in s4e-seat-<seat>.scope/cgroup.procs whose comm reads claude).
# One line per probe: BUSQ step=N ok=1 ... (rc 0) or BUSQ step=N ok=0 ... RED:<why> (rc 1); REFUSE(2) when it cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
ME="${S4E_SEAT:-probe}"
N="${1:-}"
refuse() { echo "REFUSE(2) [bus-one-queue probe]: $*"; exit 2; }
[ -n "$N" ] || refuse "usage: $0 <step 1..9>"
mkdir -p "/tmp/s4e/$ME" || refuse "cannot make /tmp/s4e/$ME"
w="$(mktemp -d "/tmp/s4e/$ME/busq_probe.XXXXXX")" || refuse "mktemp failed"
PIDS=""
trap 'for p in $PIDS $(cat "$w/pids" 2>/dev/null); do kill "$p" 2>/dev/null; done; rm -rf "$w"' EXIT
J=junior_97; S=senior_97; O=officer_97
mkdir -p "$w/tasks" "$w/claims" "$w/$J/inbox" "$w/$S/inbox" "$w/$O/inbox" "$w/scopes" || refuse "cannot make the scratch postoffice"
{ head -1 "/home/resources/postoffice/MODE" 2>/dev/null || echo TENET; echo "# probe"; echo "ROSTER: $J $S $O"; } > "$w/MODE"
[ -f /home/resources/postoffice/PROTOCOL-VERSION ] && cp /home/resources/postoffice/PROTOCOL-VERSION "$w/PROTOCOL-VERSION"
printf 'seat\tname\troot\tmodel\teffort\tcolor\ttier\trole\n%s\tPJ97\t/tmp\tclaude-haiku-5-5\txhigh\tblue\t4\tworker\n%s\tPS97\t/tmp\tclaude-sonnet-5-5\txhigh\tblue\t3\tsenior\n%s\tPO97\t/tmp\tclaude-opus-5-5\txhigh\tblue\t2\tofficer\n' "$J" "$S" "$O" > "$w/TIERS.tsv"
: > "$w/QUEUE.tsv"
cp /bin/sleep "$w/claude" || refuse "cannot copy sleep"
live_claude() {   # <seat>: a process whose comm reads claude, in the seat's scratch scope; prints its pid
    "$w/claude" 600 >/dev/null 2>&1 </dev/null & local p=$!; echo "$p" >> "$w/pids"; mkdir -p "$w/scopes/s4e-seat-$1.scope"; printf '%s\n' "$p" > "$w/scopes/s4e-seat-$1.scope/cgroup.procs"; echo "$p"; }
dead_pid() { sh -c 'echo $$'; }
row() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$w/QUEUE.tsv"; }   # rank topic owner state
baton() {   # <topic> [minted-ts] [premise] [done-when]
    printf '# TASK %s\nGOAL: plant\nSKILLS: fleet-bus\nDONE-WHEN: %s\nPREMISE-WHEN: %s\nLINKS: minted via `mint` by probe, %s\n## NEXT\nplant\n## QA\n## LEDGER\n- [probe] minted\n' \
        "$1" "${4:-false}" "${3:-true}" "${2:-2026-11-01T00:00:00Z}" > "$w/tasks/$1.task.md"; }
st() { awk -F'\t' -v t="$1" '$2 == t { print $4; exit }' "$w/QUEUE.tsv"; }
bus() { local s="$1"; shift; env -u S4E_PID_LOCK S4E_POST="$w" S4E_SEAT="$s" S4E_HOME="$S4E" S4E_TIERS="$w/TIERS.tsv" S4E_SEAT_SCOPES="$w/scopes" \
    S4E_NO_BANNER=1 S4E_NO_PREMISE_CHECK="${NOPC:-1}" S4E_LAND_IGNORE_MAIL=probe timeout -k 5 120 bash "$HERE/s4e_msg.sh" "$@" 2>&1; }
why=""
verdict() { if [ -z "$why" ]; then echo "BUSQ step=$N ok=1 $1"; exit 0; fi; echo "BUSQ step=$N ok=0 $1 RED:$why"; exit 1; }
case "$N" in
1)  # next serves a QUEUED row from the file: ask-<tier>, then seat-<me>, then tier-<tier>; within a tube the lowest rank, then the oldest mint stamp (Q4)
    a=busq1-ask-$$; s=busq1-seat-$$; r1=busq1-tier-r1-$$; o=busq1-tier-old-$$; n=busq1-tier-new-$$; x=busq1-sonnet-$$
    row 3 "$a" @haiku QUEUED:ask-haiku; row 3 "$s" "$J" "QUEUED:seat-$J"; row 1 "$r1" @haiku QUEUED:tier-haiku; row 2 "$o" @haiku QUEUED:tier-haiku
    row 2 "$n" @haiku QUEUED:tier-haiku; row 0 "$x" @sonnet QUEUED:tier-sonnet
    baton "$a" 2026-11-05T00:00:00Z; baton "$s" 2026-11-05T00:00:00Z; baton "$r1" 2026-11-04T00:00:00Z; baton "$o" 2026-11-01T00:00:00Z; baton "$n" 2026-11-02T00:00:00Z; baton "$x"
    live_claude "$J" >/dev/null; got=""
    for want in "$a" "$s" "$r1" "$o" "$n"; do
        out="$(bus "$J" next)"; g="$(printf '%s\n' "$out" | sed -n 's/^RESERVED \([^ ]*\) .*/\1/p' | head -1)"; got="$got ${g:-none}"
        [ "$g" = "$want" ] || { why="$why serve wanted $want got ${g:-none} [$(printf '%s' "$out" | grep -m1 -E 'RESERVED|nothing|REFUSE|⛔' | cut -c1-90)];"; break; }
        [ "$(st "$g")" = "CLAIMED:$J" ] || why="$why $g reads $(st "$g") after its serve, not CLAIMED:$J;"
        [ "$(head -1 "$w/claims/$g.claim" 2>/dev/null)" = "$J" ] || why="$why $g has no claim naming $J;"
        awk -F'\t' -v OFS='\t' -v t="$g" '$2 == t { $4 = "DONE" } { print }' "$w/QUEUE.tsv" > "$w/q.tmp" && cat "$w/q.tmp" > "$w/QUEUE.tsv"; rm -f "$w/claims/$g.claim"
    done
    out="$(bus "$J" next)"; printf '%s\n' "$out" | grep -q "^RESERVED $x " && why="$why a tier-sonnet row was served to a haiku seat;"
    verdict "order=ask,seat,tier-rank,tier-oldest served=$(echo $got | tr ' ' ',')";;
2)  # the reserve: next and claim write "RESERVED file tube=<tube> session=<SESSION> pid=<pid> <ts>" and the column, under one flock on PO/.queue.flock (Q2, Q3)
    t=busq2-$$; c=busq2-claim-$$; row 2 "$t" @haiku QUEUED:tier-haiku; row 2 "$c" @haiku QUEUED:tier-haiku; baton "$t"; baton "$c" 2026-11-03T00:00:00Z
    p="$(live_claude "$J")"; out="$(bus "$J" next)"
    l2="$(sed -n 2p "$w/claims/$t.claim" 2>/dev/null)"
    printf '%s' "$l2" | grep -qE "^RESERVED file tube=tier-haiku session=PJ97 pid=$p [0-9]{4}-[0-9]{2}-[0-9]{2}T" || why="$why next's reserve line reads '${l2:-none}', not RESERVED file tube=tier-haiku session=PJ97 pid=$p <ts>;"
    out="$(bus "$J" claim "$c")"; l2="$(grep -m1 '^RESERVED ' "$w/claims/$c.claim" 2>/dev/null)"
    printf '%s' "$l2" | grep -qE "^RESERVED file tube=tier-haiku session=PJ97 pid=$p " || why="$why claim of a QUEUED row wrote '${l2:-no reserve line}';"
    [ "$(st "$c")" = "CLAIMED:$J" ] || why="$why the claimed row reads $(st "$c");"
    k=busq2-lock-$$; row 2 "$k" @haiku FREE; baton "$k"
    ( flock 9; sleep 2; echo released > "$w/released"; ) 9>"$w/.queue.flock" & PIDS="$PIDS $!"
    for i in $(seq 1 50); do [ -e "$w/.queue.flock" ] && ! flock -n "$w/.queue.flock" true 2>/dev/null && break; sleep 0.1; done
    out="$(bus "$O" park "$k" PARKED)"
    [ -e "$w/released" ] || why="$why park wrote the column while another process held PO/.queue.flock (the write did not wait for the lock);"
    [ "$(st "$k")" = PARKED ] || why="$why the park after the lock was not written ($(st "$k"));"
    verdict "reserve_line=file lock=.queue.flock";;
3)  # queue, escalate and assign on the file road: the column moves, a WAKE line prints, no job id is printed and no QUEUE-JOB line is written
    q=busq3-queue-$$; e=busq3-esc-$$; a=busq3-assign-$$
    row 2 "$q" "$O" FREE; row 2 "$e" "$J" "CLAIMED:$J"; row 2 "$a" "$O" FREE; baton "$q"; baton "$e"; baton "$a"
    p="$(live_claude "$J")"; live_claude "$S" >/dev/null; printf '%s\nRESERVED file tube=tier-haiku session=PJ97 pid=%s 2026-11-08T00:00:00Z\n' "$J" "$p" > "$w/claims/$e.claim"
    out="$(bus "$O" queue "$q" --tier haiku)"; rc=$?
    [ "$rc" = 0 ] || why="$why queue exited $rc [$(printf '%s' "$out" | grep -m1 -E '⚠|⛔|REFUSE' | cut -c1-90)];"
    [ "$(st "$q")" = QUEUED:tier-haiku ] || why="$why the queued row reads $(st "$q");"
    printf '%s\n' "$out" | grep -q '^WAKE: SendMessage to PJ97 ' || why="$why queue printed no WAKE line for PJ97;"
    printf '%s\n' "$out" | grep -q 'job=' && why="$why queue printed a job id;"
    out="$(printf 'measured: the probe step 3 escalation\n' | bus "$J" escalate "$e" --stdin)"; rc=$?
    [ "$rc" = 0 ] || why="$why escalate exited $rc [$(printf '%s' "$out" | grep -m1 -E '⚠|⛔|REFUSE' | cut -c1-90)];"
    [ "$(st "$e")" = QUEUED:tier-sonnet ] || why="$why the escalated row reads $(st "$e"), not QUEUED:tier-sonnet;"
    printf '%s\n' "$out" | grep -q '^WAKE: SendMessage to PS97 ' || why="$why escalate printed no WAKE line for PS97;"
    out="$(bus "$O" assign "$J" "$a")"; rc=$?
    [ "$rc" = 0 ] || why="$why assign exited $rc;"
    [ "$(st "$a")" = "ASSIGNED:$J" ] || why="$why the assigned row reads $(st "$a");"
    printf '%s\n' "$out" | grep -q '^WAKE: SendMessage to PJ97 ' || why="$why assign printed no WAKE line for PJ97;"
    m=busq3-mint-$$
    out="$(printf 'GOAL: plant\nSKILLS: fleet-bus\nDONE-WHEN: cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" && test -f /nonexistent-busq3\nPREMISE-WHEN: cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" && true\n## NEXT\nplant\n' | bus "$O" mint "$m" 2 --tier haiku --stdin)"; rc=$?
    [ "$rc" = 0 ] || why="$why mint --tier exited $rc [$(printf '%s' "$out" | grep -m1 -E '⚠|⛔|REFUSE' | cut -c1-90)];"
    [ "$(st "$m")" = QUEUED:tier-haiku ] || why="$why the minted row reads $(st "$m"), not QUEUED:tier-haiku (today mint --tier leaves FREE beside its job);"
    printf '%s\n' "$out" | grep -q '^WAKE: SendMessage to PJ97 ' || why="$why mint printed no WAKE line for PJ97;"
    grep -l '^QUEUE-JOB:' "$w"/tasks/*.task.md >/dev/null 2>&1 && why="$why a baton carries a QUEUE-JOB line;"
    verdict "queue=QUEUED escalate=QUEUED:tier-sonnet assign=ASSIGNED mint=QUEUED wake=4";;
4)  # ask and answer through s4e_ask.sh on the file road (Q5): the question row is QUEUED:ask-<tier above>, the asker BLOCKED-ON it; answer closes it and the asker returns
    k=busq4-$$; row 2 "$k" "$J" "CLAIMED:$J"; baton "$k"; p="$(live_claude "$J")"; live_claude "$S" >/dev/null
    printf '%s\nRESERVED file tube=tier-haiku session=PJ97 pid=%s 2026-11-08T00:00:00Z\n' "$J" "$p" > "$w/claims/$k.claim"
    out="$(printf 'which one, the probe asks\n' | bus "$J" ask "$k" --stdin)"; rc=$?
    qt="$(printf '%s\n' "$out" | sed -n 's/^ASK q=\([^ ]*\) .*/\1/p' | head -1)"
    [ -n "$qt" ] || why="$why ask printed no ASK q= line (rc $rc) [$(printf '%s' "$out" | grep -m1 -E 'ASK|⚠|⛔|REFUSE' | cut -c1-90)];"
    [ -n "$qt" ] && { [ "$(st "$qt")" = QUEUED:ask-sonnet ] || why="$why the question row reads $(st "$qt"), not QUEUED:ask-sonnet;"; }
    case "$(st "$k")" in BLOCKED-ON:"$qt") ;; *) why="$why the asker reads $(st "$k"), not BLOCKED-ON:$qt;";; esac
    printf '%s\n' "$out" | grep -q '^WAKE: SendMessage to PS97 ' || why="$why ask printed no WAKE line for PS97;"
    printf '%s\n' "$out" | grep -qE 'job=[0-9]' && why="$why ask printed a job id;"
    if [ -n "$qt" ]; then
        out="$(printf 'this one, the probe answers\n' | NOPC=1 bus "$S" answer "$qt" --stdin)"
        case "$(st "$qt")" in DONE|"") ;; *) why="$why the answered question reads $(st "$qt"), not DONE or gone [$(printf '%s' "$out" | grep -m1 -E '⚠|⛔|REFUSE' | cut -c1-90)];";; esac   # CLOSED: QUEUE.tsv reads DONE or holds no row (the view moves a done row out; the cio 2026-11-10 14:5x)
        grep -q '^ANSWER: ' "$w/tasks/$qt.task.md" 2>/dev/null || why="$why the answered question's baton carries no ANSWER;"
        case "$(st "$k")" in BLOCKED-ON:*) why="$why the asker is still blocked after the answer;";; esac
        printf '%s\n' "$out" | grep -q '^WAKE: SendMessage to PJ97 ' || why="$why answer printed no WAKE line for PJ97;"
    fi
    verdict "ask=QUEUED:ask-sonnet answer=DONE asker_restored=1";;
5)  # expire by holder pid: a claim whose pid is gone is archived and its row goes back to its tube; a live pid is kept
    d=busq5-dead-$$; l=busq5-live-$$; row 2 "$d" "$J" "CLAIMED:$J"; row 2 "$l" "$J" "CLAIMED:$J"; baton "$d"; baton "$l"
    p="$(live_claude "$J")"; dp="$(dead_pid)"; kill -0 "$dp" 2>/dev/null && refuse "the dead pid $dp is alive"
    printf '%s\nRESERVED file tube=tier-haiku session=PJ97 pid=%s 2026-11-08T00:00:00Z\n' "$J" "$dp" > "$w/claims/$d.claim"
    printf '%s\nRESERVED file tube=tier-haiku session=PJ97 pid=%s 2026-11-08T00:00:00Z\n' "$J" "$p" > "$w/claims/$l.claim"
    out="$(bus "$O" expire "$d")"; rc=$?
    [ "$rc" = 0 ] || why="$why expire of a dead holder exited $rc [$(printf '%s' "$out" | head -1 | cut -c1-90)];"
    [ -e "$w/claims/$d.claim" ] && why="$why the dead holder's claim was not archived;"
    ls "$w/claims/expired/$d.claim."* >/dev/null 2>&1 || why="$why no claims/expired receipt;"
    [ "$(st "$d")" = QUEUED:tier-haiku ] || why="$why the expired row reads $(st "$d"), not QUEUED:tier-haiku;"
    grep -q 'LEASE expired' "$w/tasks/$d.task.md" || why="$why no LEASE expired LEDGER line;"
    out="$(bus "$O" expire "$l")"; rc=$?
    [ "$rc" = 1 ] || why="$why expire of a live holder exited $rc, not 1;"
    [ -e "$w/claims/$l.claim" ] || why="$why the live holder's claim was removed;"
    [ "$(st "$l")" = "CLAIMED:$J" ] || why="$why the live holder's row reads $(st "$l");"
    verdict "dead=expired live=kept";;
6)  # recut reopens SUPERSEDED as it reopens RETIRED; any other state stays
    s=busq6-sup-$$; k=busq6-park-$$; row 2 "$s" "$O" SUPERSEDED:premise-red-at-dispatch-2026-11-08T10:00:00Z; row 2 "$k" "$O" PARKED-AWAITING:probe
    baton "$s"; baton "$k"
    out="$(printf '%s\n' 'test -d "$S4E_HOME"' | bus "$O" recut "$s" --stdin)"; rc=$?
    [ "$rc" = 0 ] || why="$why recut of the superseded row exited $rc [$(printf '%s' "$out" | grep -m1 -E '⛔|REFUSE' | cut -c1-90)];"
    [ "$(st "$s")" = FREE ] || why="$why the superseded row reads $(st "$s") after recut, not FREE;"
    grep -q 'state SUPERSEDED:premise-red-at-dispatch-2026-11-08T10:00:00Z -> FREE' "$w/tasks/$s.task.md" || why="$why the RE-CUT LEDGER line does not record SUPERSEDED -> FREE;"
    out="$(printf '%s\n' 'test -d "$S4E_HOME/harness"' | bus "$O" recut "$k" --stdin)"
    [ "$(st "$k")" = PARKED-AWAITING:probe ] || why="$why a PARKED-AWAITING row moved to $(st "$k") on recut;"
    verdict "superseded=FREE parked=kept";;
7)  # a premise read on a stale binary is a refusal, never red: LANDED by the cio (CIO-9, harness d825b3811), so this probe is the receipt of that cure
    #    (a stale binary cannot be planted without touching a real root's tree; the cure was proved by its lander)
    grep -q 'A STALE BINARY READS NOTHING' "$HERE/s4e_msg.sh" || why="$why s4e_premise_gate carries no stale-binary refusal;"
    grep -q "util_require_fresh.sh >/dev/null 2>&1 ); then" "$HERE/s4e_msg.sh" || why="$why the refusal does not run util_require_fresh before the PREMISE-WHEN;"
    verdict "stale_binary_refusal=landed";;
8)  # the sweep retires every baton's QUEUE-JOB line and rewrites every live claim's RESERVED job= line to the file form, only on the file road
    a=busq8-a-$$; b=busq8-b-$$; row 2 "$a" @haiku QUEUED:tier-haiku; row 2 "$b" "$J" "CLAIMED:$J"; baton "$a"; baton "$b"
    sed -i 's/^LINKS:.*/&\nQUEUE-JOB: 4001 tube=tier-haiku/' "$w/tasks/$a.task.md" "$w/tasks/$b.task.md"
    p="$(live_claude "$J")"; printf '%s\nRESERVED job=4002 tube=tier-haiku 2026-11-08T00:00:00Z\n' "$J" > "$w/claims/$b.claim"
    out="$(bus "$O" sweep --retire-jobs)"; rc=$?
    [ "$rc" = 0 ] || why="$why sweep --retire-jobs exited $rc [$(printf '%s' "$out" | grep -m1 -E '⛔|REFUSE' | cut -c1-90)];"
    grep -l '^QUEUE-JOB:' "$w"/tasks/*.task.md >/dev/null 2>&1 && why="$why a QUEUE-JOB line survived;"
    l2="$(grep -m1 '^RESERVED ' "$w/claims/$b.claim" 2>/dev/null)"
    printf '%s' "$l2" | grep -qE "^RESERVED file tube=tier-haiku session=PJ97 pid=$p " || why="$why the live claim reads '${l2:-none}', not the file form with pid $p;"
    printf '%s\n' "$out" | grep -qE '^RETIRE-JOBS batons=2 claims=1' || why="$why no RETIRE-JOBS batons=2 claims=1 line;"
    out="$(bus "$O" sweep --retire-jobs)"; printf '%s\n' "$out" | grep -qE '^RETIRE-JOBS batons=0 claims=0' || why="$why a second run was not a no-op;"
    verdict "batons=retired claims=file";;
9)  # the bus's own gates read GREEN with no queue daemon: the index gate admits the file road's vocabulary, and next --probe-serve passes on the file road
    for t in busq9-a-$$ busq9-b-$$ busq9-c-$$ busq9-d-$$; do baton "$t"; done
    row 2 busq9-a-$$ @haiku QUEUED:tier-haiku; row 2 busq9-b-$$ @sonnet QUEUED:ask-sonnet; row 2 busq9-c-$$ "$J" "CLAIMED:$J"; row 2 busq9-d-$$ @opus QUEUED:tier-opus
    out="$(S4E_POST="$w" timeout -k 5 120 bash "$HERE/test_gate_queue_is_an_index.sh" 2>&1)"; rc=$?
    [ "$rc" = 0 ] || why="$why test_gate_queue_is_an_index.sh exited $rc on a file-road index [$(printf '%s' "$out" | grep -m1 '⛔' | cut -c1-110)];"
    verdict "index_gate=GREEN";;
*) refuse "no step $N (1..9)";;
esac
