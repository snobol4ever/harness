#!/usr/bin/env bash
# s4e_probe_bus_one_queue.sh -- THE PROBES OF DESIGN-PLAN bus-one-queue (CIO-8 phase two: the queue daemon goes, QUEUE.tsv under one flock is the one queue;
# designed by the cio, cut by officer_05 2026-11-08, the eight choices answered by the cio on q-bus-one-source-of-truth-...-cio-8-phase-two-1).
# The table is harness/designs/bus_one_queue/STEPS.tsv; test_design_bus_one_queue_steps.sh --step N runs "bash harness/scripts/s4e_probe_bus_one_queue.sh N".
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
[ -n "$N" ] || refuse "usage: $0 <step 1..16>"
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
        "$1" "${4:-test -f /nonexistent/entry:probe}" "${3:-true}" "${2:-2026-11-01T00:00:00Z}" > "$w/tasks/$1.task.md"; }   # the default criterion is red and names a program (entry:), as a tier-haiku row must (Lon 2026-11-14)
st() { awk -F'\t' -v t="$1" '$2 == t { print $4; exit }' "$w/QUEUE.tsv"; }
bus() { local s="$1"; shift; env -u S4E_PID_LOCK S4E_POST="$w" S4E_SEAT="$s" S4E_HOME="$S4E" S4E_TIERS="$w/TIERS.tsv" S4E_SEAT_SCOPES="$w/scopes" \
    S4E_NO_BANNER=1 S4E_NO_PREMISE_CHECK="${NOPC:-1}" S4E_LAND_IGNORE_MAIL=probe timeout -k 5 120 bash "$HERE/s4e_msg.sh" "$@" 2>&1; }
why=""
verdict() { if [ -z "$why" ]; then echo "BUSQ step=$N ok=1 $1"; exit 0; fi; echo "BUSQ step=$N ok=0 $1 RED:$why"; exit 1; }
case "$N" in
1)  # next serves a QUEUED row from the file: ask-<tier>, then seat-<me>, then tier-<tier>; within a tube the lowest rank, then the seat's own key over the topic (bus-tube-herd-2): the two rank-2 rows are served in either order
    a=busq1-ask-$$; s=busq1-seat-$$; r1=busq1-tier-r1-$$; o=busq1-tier-old-$$; n=busq1-tier-new-$$; x=busq1-sonnet-$$
    row 3 "$a" @haiku QUEUED:ask-haiku; row 3 "$s" "$J" "QUEUED:seat-$J"; row 1 "$r1" @haiku QUEUED:tier-haiku; row 2 "$o" @haiku QUEUED:tier-haiku
    row 2 "$n" @haiku QUEUED:tier-haiku; row 0 "$x" @sonnet QUEUED:tier-sonnet
    baton "$a" 2026-11-05T00:00:00Z; baton "$s" 2026-11-05T00:00:00Z; baton "$r1" 2026-11-04T00:00:00Z; baton "$o" 2026-11-01T00:00:00Z; baton "$n" 2026-11-02T00:00:00Z; baton "$x"
    live_claude "$J" >/dev/null; got=""
    for want in "$a" "$s" "$r1" "$o $n" "$o $n"; do
        out="$(bus "$J" next)"; g="$(printf '%s\n' "$out" | sed -n 's/^RESERVED \([^ ]*\) .*/\1/p' | head -1)"; got="$got ${g:-none}"
        case " $want " in *" $g "*) [ -n "$g" ] && hit=1 || hit=0;; *) hit=0;; esac
        [ "$hit" = 1 ] || { why="$why serve wanted $want got ${g:-none} [$(printf '%s' "$out" | grep -m1 -E 'RESERVED|nothing|REFUSE|⛔' | cut -c1-90)];"; break; }
        [ "$(st "$g")" = "CLAIMED:$J" ] || why="$why $g reads $(st "$g") after its serve, not CLAIMED:$J;"
        [ "$(head -1 "$w/claims/$g.claim" 2>/dev/null)" = "$J" ] || why="$why $g has no claim naming $J;"
        awk -F'\t' -v OFS='\t' -v t="$g" '$2 == t { $4 = "DONE" } { print }' "$w/QUEUE.tsv" > "$w/q.tmp" && cat "$w/q.tmp" > "$w/QUEUE.tsv"; rm -f "$w/claims/$g.claim"
    done
    out="$(bus "$J" next)"; printf '%s\n' "$out" | grep -q "^RESERVED $x " && why="$why a tier-sonnet row was served to a haiku seat;"
    verdict "order=ask,seat,tier-rank,tier-oldest served=$(echo $got | tr ' ' ',')";;
2)  # the reserve: next and claim write "RESERVED file tube=<tube> session=<SESSION> pid=<pid> <ts>" and the column, under one flock on PO/.queue.flock (Q2, Q3)
    t=busq2-$$; c=busq2-claim-$$; row 1 "$t" @haiku QUEUED:tier-haiku; row 2 "$c" @haiku QUEUED:tier-haiku; baton "$t"; baton "$c" 2026-11-03T00:00:00Z
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
    out="$(printf 'GOAL: plant\nSKILLS: fleet-bus\nDONE-WHEN: cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" && test -f "/nonexistent/entry:busq3"\nPREMISE-WHEN: cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" && true\n## NEXT\nplant\n' | bus "$O" mint "$m" 2 --tier haiku --stdin)"; rc=$?
    [ "$rc" = 0 ] || why="$why mint --tier exited $rc [$(printf '%s' "$out" | grep -m1 -E '⚠|⛔|REFUSE' | cut -c1-90)];"
    [ "$(st "$m")" = QUEUED:tier-haiku ] || why="$why the minted row reads $(st "$m"), not QUEUED:tier-haiku (today mint --tier leaves FREE beside its job);"
    printf '%s\n' "$out" | grep -q '^WAKE: SendMessage to PJ97 ' || why="$why mint printed no WAKE line for PJ97;"
    grep -l '^QUEUE-JOB:' "$w"/tasks/*.task.md >/dev/null 2>&1 && why="$why a baton carries a QUEUE-JOB line;"
    # THE TOP RUNG (the cio 2026-11-12 13:2x, on the coo's telegram ladder-top-rung-no-lon-hold; Lon 12:4x: "I release ALL holds."): the coo's own escalation
    # parks PARKED-CHAIRMAN:escalated, telegrams and wakes the cio, and an officer lifts it with a bare park FREE, no S4E_GRANT_BY
    printf 'coo\tPCOO97\t/tmp\tclaude-opus-5-5\txhigh\tblue\t2\tboss\ncio\tPCIO97\t/tmp\tclaude-fable-5-2\txhigh\tblue\t1\tboss\n' >> "$w/TIERS.tsv"
    printf 'BOSSES: cio coo\n' >> "$w/MODE"; mkdir -p "$w/coo/inbox" "$w/cio/inbox"
    c=busq3-chair-$$; row 2 "$c" coo CLAIMED:coo; baton "$c"; pc="$(live_claude coo)"
    printf 'coo\nRESERVED file tube=seat-coo session=PCOO97 pid=%s 2026-11-12T00:00:00Z\n' "$pc" > "$w/claims/$c.claim"
    out="$(printf 'measured: the probe step 3 top rung\n' | bus coo escalate "$c" --stdin)"; rc=$?
    [ "$rc" = 0 ] || why="$why the coo's escalate exited $rc [$(printf '%s' "$out" | grep -m1 -E '⚠|⛔|REFUSE' | cut -c1-90)];"
    [ "$(st "$c")" = PARKED-CHAIRMAN:escalated ] || why="$why the coo's escalated row reads $(st "$c"), not PARKED-CHAIRMAN:escalated;"
    printf '%s\n' "$out" | grep -q '^WAKE: SendMessage to PCIO97 ' || why="$why the coo's escalate printed no WAKE line for the cio;"
    ls "$w/cio/inbox/" 2>/dev/null | grep -q "escalated-$c-rung" || why="$why the cio got no telegram of the top rung;"
    out="$(env -u S4E_GRANT_BY true; bus "$O" park "$c" FREE)"; rc=$?
    [ "$rc" = 0 ] && [ "$(st "$c")" = FREE ] || why="$why an officer's bare park FREE did not lift the chairman's row (rc $rc, reads $(st "$c")) [$(printf '%s' "$out" | grep -m1 -E '⛔|REFUSE' | cut -c1-90)];"
    verdict "queue=QUEUED escalate=QUEUED:tier-sonnet assign=ASSIGNED mint=QUEUED wake=4 top=PARKED-CHAIRMAN lift=park-FREE";;
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
    if [ -n "$qt" ]; then   # the senior's next serves the question: the ask verb's baton carries no mint stamp (officer_03 2026-11-12: next skipped every such row)
        out="$(bus "$S" next)"; printf '%s\n' "$out" | grep -q "^RESERVED $qt " || why="$why next did not serve the question row to $S [$(printf '%s' "$out" | grep -m1 -E 'RESERVED|EMPTY|nothing|REFUSE|⛔' | cut -c1-90)];"
    fi
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
    out="$(printf '%s\n' 'test -d "$S4E_HOME/harness"' | bus "$O" recut "$k" --stdin)"  # one-disk: not a path
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
wake-live-boss)  # CIO-106: a wake for a live boss names that boss; the operating boss is named only when the boss is asleep (the cio as mover, seat-cto tube)
    tw="$w/TIERS-wake.tsv"; { head -1 "$w/TIERS.tsv"; printf 'cio\tCIO\t/tmp\tclaude-fable-5-2\txhigh\tblue\t1\tboss\ncto\tCTO\t/tmp\tclaude-fable-5-2\txhigh\tblue\t1\tboss\ncoo\tCOO\t/tmp\tclaude-opus-5-5\txhigh\tblue\t2\tboss\n'; } > "$tw"
    printf 'BOSSES: cio coo cto\n' >> "$w/MODE"
    wk() { ( export S4E_POST="$w" S4E_TIERS="$tw" S4E_SEAT_SCOPES="$w/scopes" ME=cio; . "$HERE/lib_wake.sh"; s4e_wake_hint seat-cto "$1" queue | head -1 ); }
    rm -rf "$w/scopes"; mkdir -p "$w/scopes"; live_claude cio >/dev/null; live_claude cto >/dev/null
    lv="$(wk wake-live-boss-live)"; ls_="$(printf '%s\n' "$lv" | sed -n 's/^WAKE: SendMessage to .* now (seat \([^;]*\);.*/\1/p')"
    rm -rf "$w/scopes/s4e-seat-cto.scope"
    as="$(wk wake-live-boss-asleep)"; as_="$(printf '%s\n' "$as" | sed -n 's/^WAKE: SendMessage to .* now (seat \([^;]*\);.*/\1/p')"
    [ "$ls_" = cto ] || why="$why the live cto is not named (wake reads '${lv:-none}');"
    [ "$as_" = coo ] || why="$why the asleep cto does not name the operating boss coo (wake reads '${as:-none}');"
    if [ -z "$why" ]; then echo "WAKE_LIVE_BOSS live=$ls_ asleep=$as_"; exit 0; fi
    echo "WAKE_LIVE_BOSS live=${ls_:-none} asleep=${as_:-none} RED:$why"; exit 1;;
10) # CONCURRENT WRITERS (the cio 2026-11-14, on the coo's and officer_02's measurement under the re-cut: of 10 queue moves 4 lost the owner and one read saw an empty QUEUE.tsv; the queue verb
    # rewrote the owner column outside every lock and each writer truncated the file in place): K queue verbs at once move K rows while a reader reads the file without a lock.
    # Every row ends owner @haiku and state QUEUED:tier-haiku, the file keeps its line count, and no read sees a file shorter than it stood (an order of events, no clock).
    # Twelve SEATS, since one identity is one process on the bus: each writer is its own officer of the scratch table.
    K=12; ts=""; seats=""
    for i in $(seq 1 "$K"); do
        t="busq10-$i-$$"; q="officer_$((80 + i))"; ts="$ts $t"; seats="$seats $q"; row 2 "$t" "$q" FREE; baton "$t"; mkdir -p "$w/$q/inbox"
        printf '%s\tPO%s\t/tmp\tclaude-opus-5-5\txhigh\tblue\t2\tofficer\n' "$q" "$((80 + i))" >> "$w/TIERS.tsv"
    done
    sed -i "s/^ROSTER: .*/ROSTER: $J $S $O$seats/" "$w/MODE"
    lines="$(wc -l < "$w/QUEUE.tsv")"
    ( n=0; torn=0; while [ ! -e "$w/stop" ]; do c="$(wc -l < "$w/QUEUE.tsv" 2>/dev/null)"; n=$((n+1)); [ "${c:-0}" = "$lines" ] || torn=$((torn+1)); done; echo "$n $torn" > "$w/reads" ) & rp=$!; PIDS="$PIDS $rp"
    qp=""; i=0; for t in $ts; do i=$((i + 1)); bus "officer_$((80 + i))" queue "$t" --tier haiku > "$w/q.$t.log" 2>&1 & qp="$qp $!"; done
    for q in $qp; do wait "$q"; done
    : > "$w/stop"; wait "$rp"; read -r reads torn < "$w/reads"
    lost=0; unq=0
    for t in $ts; do
        [ "$(awk -F'\t' -v t="$t" '$2 == t { print $3; exit }' "$w/QUEUE.tsv")" = "@haiku" ] || lost=$((lost+1))
        [ "$(st "$t")" = "QUEUED:tier-haiku" ] || unq=$((unq+1))
    done
    [ "$(wc -l < "$w/QUEUE.tsv")" = "$lines" ] || why="$why the file ends with $(wc -l < "$w/QUEUE.tsv") lines, it stood at $lines;"
    said="$(cat "$w"/q.busq10-*.log 2>/dev/null | grep -c '^queued busq10-')"
    [ "$said" = "$K" ] || why="$why only $said of $K queue verbs said queued [$(cat "$w"/q.busq10-*.log | grep -m1 -E 'REFUSE|⛔' | cut -c1-110)];"
    [ "$lost" = 0 ] || why="$why $lost of $K rows lost their owner;"
    [ "$unq" = 0 ] || why="$why $unq of $K rows are not QUEUED:tier-haiku;"
    [ "${torn:-1}" = 0 ] || why="$why $torn of ${reads:-0} unlocked reads saw a file shorter than $lines lines;"
    [ "${reads:-0}" -gt 0 ] || refuse "the reader read nothing"
    ls "$w"/.QUEUE.tsv.* > /dev/null 2>&1 && why="$why a writer left its scratch copy in the postoffice;"
    verdict "writers=$K said_queued=$said rows_owner_lost=$lost rows_not_queued=$unq reads=$reads torn_reads=$torn";;
11) # A QUEUED ROW PARKED BLOCKED-ON RETURNS TO ITS OWN TUBE (the cio 2026-11-14, on the coo's and officer_02's measurement: park recorded RESTORE-STATE: FREE for a row that stood
    # QUEUED:tier-X, so a chained step came back FREE when its blocker landed, and no tier serves a FREE row; 43 of 133 blocked rows stood so)
    # A row minted to a tier and parked before any queue (owner @haiku, state FREE) records FREE and returns to tier-haiku; a seat's own FREE row returns FREE.
    blk="busq11-blocker-$$"; r="busq11-row-$$"; f="busq11-free-$$"; c="busq11-chain-$$"
    row 2 "$blk" "$O" FREE; row 2 "$r" @sonnet QUEUED:tier-sonnet; row 2 "$f" "$O" FREE; row 2 "$c" @haiku FREE; baton "$c"
    baton "$blk" 2026-11-01T00:00:00Z true 'test -f "$S4E_HARNESS/scripts/s4e_msg.sh"'; baton "$r"; baton "$f"; live_claude "$O" >/dev/null
    bus "$O" park "$r" "BLOCKED-ON:$blk" > "$w/park.log" 2>&1; bus "$O" park "$f" "BLOCKED-ON:$blk" >> "$w/park.log" 2>&1; bus "$O" park "$c" "BLOCKED-ON:$blk" >> "$w/park.log" 2>&1
    rec="$(sed -n 's/^RESTORE-STATE: //p' "$w/tasks/$r.task.md" | head -1)"; recf="$(sed -n 's/^RESTORE-STATE: //p' "$w/tasks/$f.task.md" | head -1)"
    [ "$(st "$r")" = "BLOCKED-ON:$blk" ] || why="$why the park did not take: $r reads $(st "$r") [$(tail -1 "$w/park.log" | cut -c1-90)];"
    [ "$rec" = "QUEUED:tier-sonnet" ] || why="$why park recorded RESTORE-STATE '${rec:-none}' for a row that stood QUEUED:tier-sonnet;"
    [ "$recf" = "FREE" ] || why="$why park recorded RESTORE-STATE '${recf:-none}' for a row that stood FREE;"
    bus "$O" claim "$blk" > "$w/done.log" 2>&1; bus "$O" done "$blk" >> "$w/done.log" 2>&1
    grep -q "^done $blk" "$w/done.log" || why="$why the blocker did not close: it reads $(st "$blk") [$(grep -m1 -E 'REFUSED' "$w/done.log" | cut -c1-90)];"
    [ "$(st "$r")" = "QUEUED:tier-sonnet" ] || why="$why after its blocker closed the row reads $(st "$r"), not QUEUED:tier-sonnet;"
    [ "$(st "$f")" = "FREE" ] || why="$why after its blocker closed the FREE row reads $(st "$f");"
    [ "$(st "$c")" = "QUEUED:tier-haiku" ] || why="$why after its blocker closed the tier's FREE chain step reads $(st "$c"), not QUEUED:tier-haiku;"
    verdict "recorded=${rec:-none} returned=$(st "$r") free_row=$(st "$f") chain_step=$(st "$c")";;
12) # A ROW GOES WHERE ITS PROGRAM SAYS, and the bus's own premise check takes no core token (the cio 2026-11-14; Lon: "Ultimately we would have all BATONS go to JUNIORS, and they
    # would escalate only when needed versus us guessing." / "All BAONS going to JUNIORS or SENIORS requires a program."): tier-haiku takes a program row only; tier-sonnet a
    # program row that was escalated; tier-opus a row with no program, or an escalated one. A refused mint writes no row; a refused queue leaves the row as it stood.
    PD='cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" && test -f "/nonexistent/entry:busq12"'; ND='cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" && test -f /nonexistent-busq12'
    mk() { printf 'GOAL: plant\nSKILLS: fleet-bus\nDONE-WHEN: %s\nPREMISE-WHEN: cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" && true\n## NEXT\nplant\n' "$1"; }
    m1="busq12-prog-haiku-$$"; m2="busq12-prog-sonnet-$$"; m3="busq12-noprog-haiku-$$"; m4="busq12-noprog-opus-$$"; m5="busq12-prog-opus-$$"
    mk "$PD" | bus "$O" mint "$m1" 2 --tier haiku --stdin > "$w/m1.log" 2>&1; r1=$?
    mk "$PD" | bus "$O" mint "$m2" 2 --tier sonnet --stdin > "$w/m2.log" 2>&1; r2=$?
    mk "$ND" | bus "$O" mint "$m3" 2 --tier haiku --stdin > "$w/m3.log" 2>&1; r3=$?
    mk "$ND" | bus "$O" mint "$m4" 2 --tier opus --stdin > "$w/m4.log" 2>&1; r4=$?
    mk "$PD" | bus "$O" mint "$m5" 2 --tier opus --stdin > "$w/m5.log" 2>&1; r5=$?
    [ "$r1" = 0 ] && [ "$(st "$m1")" = QUEUED:tier-haiku ] || why="$why mint of a program row to tier-haiku exited $r1, the row reads '$(st "$m1")' [$(grep -m1 REFUSED "$w/m1.log" | cut -c1-90)];"
    [ "$r2" = 2 ] && [ -z "$(st "$m2")" ] && [ ! -e "$w/tasks/$m2.task.md" ] || why="$why mint of a never-escalated program row to tier-sonnet exited $r2 (row '$(st "$m2")');"
    [ "$r3" = 2 ] && [ -z "$(st "$m3")" ] && [ ! -e "$w/tasks/$m3.task.md" ] || why="$why mint of a row with no program to tier-haiku exited $r3 (row '$(st "$m3")');"
    [ "$r4" = 0 ] && [ "$(st "$m4")" = QUEUED:tier-opus ] || why="$why mint of a row with no program to tier-opus exited $r4, the row reads '$(st "$m4")' [$(grep -m1 REFUSED "$w/m4.log" | cut -c1-90)];"
    [ "$r5" = 2 ] && [ -z "$(st "$m5")" ] || why="$why mint of a never-escalated program row to tier-opus exited $r5 (row '$(st "$m5")');"
    q1="busq12-q-prog-$$"; q2="busq12-q-prog-esc-$$"; q3="busq12-q-noprog-$$"
    row 2 "$q1" "$O" FREE; baton "$q1" 2026-11-01T00:00:00Z true "$PD"
    row 2 "$q2" "$O" FREE; baton "$q2" 2026-11-01T00:00:00Z true "$PD"; printf '## ESCALATION\n\n- probe: a junior tried it and measured\n' >> "$w/tasks/$q2.task.md"
    row 2 "$q3" "$O" FREE; baton "$q3" 2026-11-01T00:00:00Z true "$ND"
    bus "$O" queue "$q1" --tier opus > "$w/q1.log" 2>&1; a1=$?; [ "$a1" = 2 ] && [ "$(st "$q1")" = FREE ] || why="$why queue of a never-escalated program row to tier-opus exited $a1, the row reads $(st "$q1");"
    bus "$O" queue "$q1" --tier sonnet > "$w/q1.log" 2>&1; a2=$?; [ "$a2" = 2 ] && [ "$(st "$q1")" = FREE ] || why="$why queue of a never-escalated program row to tier-sonnet exited $a2, the row reads $(st "$q1");"
    bus "$O" queue "$q1" --tier haiku > "$w/q1.log" 2>&1; a3=$?; [ "$a3" = 0 ] && [ "$(st "$q1")" = QUEUED:tier-haiku ] || why="$why queue of a program row to tier-haiku exited $a3, the row reads $(st "$q1");"
    bus "$O" queue "$q2" --tier sonnet > "$w/q2.log" 2>&1; a4=$?; [ "$a4" = 0 ] && [ "$(st "$q2")" = QUEUED:tier-sonnet ] || why="$why queue of an escalated program row to tier-sonnet exited $a4, the row reads $(st "$q2");"
    bus "$O" queue "$q3" --tier haiku > "$w/q3.log" 2>&1; a5=$?; [ "$a5" = 2 ] && [ "$(st "$q3")" = FREE ] || why="$why queue of a row with no program to tier-haiku exited $a5, the row reads $(st "$q3");"
    bus "$O" queue "$q3" --tier sonnet > "$w/q3.log" 2>&1; a6=$?; [ "$a6" = 2 ] && [ "$(st "$q3")" = FREE ] || why="$why queue of a row with no program to tier-sonnet exited $a6, the row reads $(st "$q3");"
    bus "$O" queue "$q3" --tier opus > "$w/q3.log" 2>&1; a7=$?; [ "$a7" = 0 ] && [ "$(st "$q3")" = QUEUED:tier-opus ] || why="$why queue of a row with no program to tier-opus exited $a7, the row reads $(st "$q3") [$(grep -m1 REFUSED "$w/q3.log" | cut -c1-90)];"
    t1="busq12-to-junior-$$"; t2="busq12-to-officer-$$"; row 2 "$t1" "$O" FREE; baton "$t1" 2026-11-01T00:00:00Z true "$ND"; row 2 "$t2" "$O" FREE; baton "$t2" 2026-11-01T00:00:00Z true "$ND"
    bus "$O" queue "$t1" --to "$J" > "$w/t1.log" 2>&1; b1=$?; [ "$b1" = 2 ] && [ "$(st "$t1")" = FREE ] || why="$why queue --to a junior of a row with no program exited $b1, the row reads $(st "$t1");"
    bus "$O" assign "$J" "$t1" > "$w/t1.log" 2>&1; b2=$?; [ "$b2" = 2 ] && [ "$(st "$t1")" = FREE ] || why="$why assign to a junior of a row with no program exited $b2, the row reads $(st "$t1");"
    bus "$O" queue "$t2" --to "$O" > "$w/t2.log" 2>&1; b3=$?; [ "$b3" = 0 ] && [ "$(st "$t2")" = "QUEUED:seat-$O" ] || why="$why queue --to an officer of a row with no program exited $b3, the row reads $(st "$t2") [$(grep -m1 REFUSED "$w/t2.log" | cut -c1-90)];"
    pr="busq12-premise-$$"; row 2 "$pr" "$O" FREE; baton "$pr" 2026-11-01T00:00:00Z 'cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" && test "${S4E_CORE_HELD:-0}" = 1'; live_claude "$O" >/dev/null
    o6="$(NOPC=0 bus "$O" claim "$pr")"
    [ "$(st "$pr")" = "CLAIMED:$O" ] || why="$why a premise that reads S4E_CORE_HELD=1 did not hold: the row reads $(st "$pr") [$(printf '%s' "$o6" | grep -m1 -E 'PREMISE|REFUSE' | cut -c1-90)];"
    verdict "haiku=program-rows-only sonnet=escalated-program-rows opus=no-program-or-escalated mints=$r1,$r2,$r3,$r4,$r5 queues=$a1,$a2,$a3,$a4,$a5,$a6,$a7 to_seat=$b1,$b2,$b3 premise_token=none";;
13) # A MINT IS ONE LOCKED WRITE, and A CURED ROW IS ADMITTED TO BE CLOSED (the cio 2026-11-14, on the coo's two measurements: 5 of 39 rows the feeder minted --to a junior stood
    # FREE with no tube, their second write having lost its lock; and a junior's cured row came back to its tube and claim refused it, its premise being red because the red was
    # gone). Six seats mint to a tube while six queue other rows, all at once: every minted row stands QUEUED in its tube, none FREE and none lost, and every queued row moved.
    PD='cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" && test -f "/nonexistent/entry:busq13"'
    mk() { printf 'GOAL: plant\nSKILLS: fleet-bus\nDONE-WHEN: %s\nPREMISE-WHEN: cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" && true\n## NEXT\nplant\n' "$PD"; }
    K=12; seats=""
    for i in $(seq 1 "$K"); do q="officer_$((80 + i))"; seats="$seats $q"; mkdir -p "$w/$q/inbox"; printf '%s\tPO%s\t/tmp\tclaude-opus-5-5\txhigh\tblue\t2\tofficer\n' "$q" "$((80 + i))" >> "$w/TIERS.tsv"; done
    sed -i "s/^ROSTER: .*/ROSTER: $J $S $O$seats/" "$w/MODE"
    for i in 7 8 9 10 11 12; do row 2 "busq13-q-$i-$$" "officer_$((80 + i))" FREE; baton "busq13-q-$i-$$"; done
    pp=""
    for i in 1 2 3 4 5 6; do ( mk | bus "officer_$((80 + i))" mint "busq13-m-$i-$$" 2 --to "$J" --stdin > "$w/m13.$i.log" 2>&1 ) & pp="$pp $!"; done
    for i in 7 8 9 10 11 12; do bus "officer_$((80 + i))" queue "busq13-q-$i-$$" --tier haiku > "$w/q13.$i.log" 2>&1 & pp="$pp $!"; done
    for x in $pp; do wait "$x"; done
    free=0; lost=0; notq=0
    for i in 1 2 3 4 5 6; do v="$(st "busq13-m-$i-$$")"; [ -n "$v" ] || lost=$((lost + 1)); [ "$v" = FREE ] && free=$((free + 1)); [ "$v" = "QUEUED:seat-$J" ] || notq=$((notq + 1)); done
    for i in 7 8 9 10 11 12; do [ "$(st "busq13-q-$i-$$")" = QUEUED:tier-haiku ] || notq=$((notq + 1)); done
    [ "$lost" = 0 ] || why="$why $lost of 6 minted rows are not in the queue file;"
    [ "$free" = 0 ] || why="$why $free of 6 rows minted --to a junior stand FREE;"
    [ "$notq" = 0 ] || why="$why $notq of 12 rows do not stand in their tube [$(cat "$w"/m13.*.log "$w"/q13.*.log | grep -m1 -E 'REFUSED|NOT updated' | cut -c1-100)];"
    grep -q '^STATE: QUEUED:seat-' "$w/tasks/busq13-m-1-$$.task.md" 2>/dev/null || why="$why a minted baton's STATE line does not read its tube;"
    red="$w/busq13.red"; : > "$red"
    c1="busq13-cured-$$"; c2="busq13-open-$$"
    row 2 "$c1" "$O" FREE; baton "$c1" 2026-11-01T00:00:00Z "test -f $red.gone" "test -f $red"       # premise red (the red is gone), criterion green: cured
    row 2 "$c2" "$O" FREE; baton "$c2" 2026-11-01T00:00:00Z "test -f $red.gone" "test -f $red.gone"  # premise red, criterion red: the premise is simply false
    live_claude "$O" >/dev/null
    NOPC=0 bus "$O" claim "$c1" > "$w/c1.log" 2>&1; NOPC=0 bus "$O" claim "$c2" > "$w/c2.log" 2>&1
    [ "$(st "$c1")" = "CLAIMED:$O" ] || why="$why a cured row (premise red, DONE-WHEN green) was not admitted: it reads $(st "$c1") [$(grep -m1 -E 'REFUSED|PREMISE' "$w/c1.log" | cut -c1-90)];"
    grep -q 'ADMITTED WITH A RED PREMISE, COMPUTED' "$w/tasks/$c1.task.md" || why="$why the cured row's LEDGER carries no computed admission line;"
    [ "$(st "$c2")" = FREE ] || why="$why a row whose premise and criterion are both red was taken: it reads $(st "$c2");"
    verdict "minted=6 queued=6 free=$free lost=$lost not_in_tube=$notq cured_row=$(st "$c1") open_row=$(st "$c2")";;
14) # NOT LANDING IS NO REASON TO ESCALATE (Lon 2026-11-14 13:2x CST, in the coo's window: "So NOT LANDING is not a reason to ESCALATE. Correct?"; the coo 2026-11-14): a worker whose own newest
    # landing of the row ended red:rebase, red:push, refuse or stopped is refused rc 2 with nothing written; one whose newest landing ended red:gate escalates; another seat's lander red does not bind it
    e="busq14-esc-$$"; row 2 "$e" "$J" "CLAIMED:$J"; baton "$e"
    p="$(live_claude "$J")"; live_claude "$S" >/dev/null; printf '%s\nRESERVED file tube=tier-haiku session=PJ97 pid=%s 2026-11-08T00:00:00Z\n' "$J" "$p" > "$w/claims/$e.claim"
    lr() { printf '%s\t%s\t%s\t%s\t1\t0\t0\t9\t0\ttries=1\tgate=1\n' "$1" "$2" "$e" "$3" >> "$w/LANDINGS.tsv"; }
    refused=0
    for o in red:rebase red:push refuse stopped; do
        lr 2026-11-14T19:30:00Z "$J" "$o"
        out="$(printf 'measured: the landing lost its rebase\n' | bus "$J" escalate "$e" --stdin)"; rc=$?
        [ "$rc" = 2 ] && refused=$((refused + 1)) || why="$why escalate after a landing that ended $o exited $rc, not 2;"
        [ "$(st "$e")" = "CLAIMED:$J" ] || why="$why after a refused escalate ($o) the row reads $(st "$e");"
        printf '%s\n' "$out" | grep -q 'NOT LANDING IS NO REASON TO ESCALATE' || why="$why the $o refusal does not name the law;"
    done
    lr 2026-11-14T19:31:00Z "$S" red:rebase
    lr 2026-11-14T19:30:30Z "$J" red:gate
    out="$(printf 'measured: the cure reads red in its own gate\n' | bus "$J" escalate "$e" --stdin)"; rc=$?
    [ "$rc" = 0 ] || why="$why escalate after the seat's own red:gate (another seat's red:rebase newer) exited $rc [$(printf '%s' "$out" | grep -m1 -E '⛔|REFUSE' | cut -c1-90)];"
    [ "$(st "$e")" = QUEUED:tier-sonnet ] || why="$why the row escalated after red:gate reads $(st "$e");"
    verdict "lander_outcomes_refused=$refused/4 after_red_gate=$(st "$e")";;
15) # THE BUS SAVES WHAT AN ESCALATION NAMES UNDER /tmp (the cio 2026-11-14; Lon: "quit using /tmp COMPLETELY for anything important."; MEASURED: all 62 patch and diff files
    # the escalations named under /tmp/s4e were gone). A junior escalates naming a patch file, a folder and a file that is not there: the bus copies the file whole and the
    # folder's hand-made files under PO/escalations/files/<topic>/rung<N>/, and the measurement says where each went and which was absent.
    r="busq15-row-$$"; row 2 "$r" "$J" "CLAIMED:$J"; baton "$r"; p="$(live_claude "$J")"
    printf '%s\nRESERVED file tube=tier-haiku session=probe pid=%s %s\n' "$J" "$p" "$(date -u +%FT%TZ)" > "$w/claims/$r.claim"
    mkdir -p "$w/scratch/try"; printf -- '--- a\n+++ b\n@@ the cure\n' > "$w/scratch/cure.patch"; printf 'note\n' > "$w/scratch/try/note.md"
    out="$(printf 'One honest try. The cure in hand is %s and my attempt is in %s ; the old diff %s is gone.\n' "$w/scratch/cure.patch" "$w/scratch/try" "$w/scratch/gone.diff" | bus "$J" escalate "$r" --stdin)"
    mf="$(ls "$w/escalations/$r".rung*.md 2>/dev/null | head -1)"
    cp1="$(ls "$w/escalations/files/$r"/rung*/*cure.patch 2>/dev/null | head -1)"
    [ -n "$mf" ] || why="$why the escalation wrote no measurement file [$(printf '%s' "$out" | grep -m1 -E 'REFUSED' | cut -c1-90)];"
    [ -n "$cp1" ] && cmp -s "$cp1" "$w/scratch/cure.patch" || why="$why the patch file the escalation named was not copied whole to the postoffice;"
    ls "$w/escalations/files/$r"/rung*/*try/note.md > /dev/null 2>&1 || why="$why the folder the escalation named was not saved;"
    grep -q '^SAVED BY THE BUS' "${mf:-/dev/null}" && grep -q "^SAVED $w/scratch/cure.patch -> " "${mf:-/dev/null}" && grep -q "^ABSENT $w/scratch/gone.diff" "${mf:-/dev/null}" || why="$why the measurement does not say where the files went and which was absent;"
    rm -f "$w/scratch/cure.patch"
    [ -s "$cp1" ] || why="$why the copy did not outlive the scratch file;"
    verdict "named_file=copied named_folder=saved absent=reported copy_outlives_scratch=$([ -s "${cp1:-/x}" ] && echo yes || echo no)";;
16) # A HAND CLAIM OF A SEAT WITH NO SESSION IS LIFTED WHEN NAMED (the cio 2026-11-14; MEASURED: five hand claims of seats that had exited, `expire` answering "the claim
    # holds no file reserve" and `assign` refusing the row). Four hand claims (no RESERVED line): a dead seat's, a seat's alive in its scope, a seat's alive only in a window
    # opened by hand (a process named claude whose working directory is its root, in no scope), and the caller's own. Only the first is lifted, and its row goes FREE.
    d=busq16-dead-$$; l=busq16-scope-$$; h=busq16-hand-$$; m=busq16-mine-$$; pk=busq16-park-$$
    row 2 "$d" "$O" "CLAIMED:$J"; row 2 "$l" "$O" "CLAIMED:$S"; row 2 "$h" "$O" "CLAIMED:grader_97"; row 2 "$m" "$O" "CLAIMED:$O"; row 2 "$pk" "$O" "BLOCKED-ON:$l"
    for t_ in "$d" "$l" "$h" "$m" "$pk"; do baton "$t_"; done
    printf '%s\n' "$J" > "$w/claims/$d.claim"; printf '%s\n' "$S" > "$w/claims/$l.claim"; printf 'grader_97\n' > "$w/claims/$h.claim"; printf '%s\n' "$O" > "$w/claims/$m.claim"; printf '%s\n' "$J" > "$w/claims/$pk.claim"
    live_claude "$S" >/dev/null; live_claude "$O" >/dev/null
    mkdir -p "$w/roots/claude_grader_97"; ( cd "$w/roots/claude_grader_97" && exec "$w/claude" 600 >/dev/null 2>&1 </dev/null ) & echo $! >> "$w/pids"
    for i_ in 1 2 3 4 5 6 7 8 9 10; do [ "$(readlink "/proc/$(tail -1 "$w/pids")/cwd" 2>/dev/null)" = "$w/roots/claude_grader_97" ] && [ "$(cat "/proc/$(tail -1 "$w/pids")/comm" 2>/dev/null)" = claude ] && break; read -r -t 0.2 _ < <(:) || true; done
    xb() { S4E_SEAT_ROOTS="$w/roots" bus "$@"; }
    out="$(S4E_SEAT_ROOTS="$w/roots" bus "$O" expire)"; [ -e "$w/claims/$d.claim" ] || why="$why the walk of every claim lifted a hand claim;"
    out="$(xb "$O" expire "$pk")"; rc=$?; { [ "$rc" = 0 ] && [ ! -e "$w/claims/$pk.claim" ] && [ "$(st "$pk")" = "BLOCKED-ON:$l" ]; } || why="$why a parked row's dead hand claim: rc $rc, row $(st "$pk") (the park must stand, the claim go);"
    out="$(xb "$O" expire "$d")"; rc=$?
    [ "$rc" = 0 ] || why="$why expire of a dead seat's hand claim exited $rc [$(printf '%s' "$out" | head -1 | cut -c1-90)];"
    [ -e "$w/claims/$d.claim" ] && why="$why the dead seat's hand claim was not archived;"
    ls "$w/claims/expired/$d.claim."* >/dev/null 2>&1 || why="$why no claims/expired receipt;"
    [ "$(st "$d")" = FREE ] || why="$why the lifted row reads $(st "$d"), not FREE;"
    grep -q 'HAND CLAIM expired' "$w/tasks/$d.task.md" || why="$why no HAND CLAIM expired LEDGER line;"
    out="$(xb "$O" expire "$l")"; rc=$?; { [ "$rc" = 1 ] && [ -e "$w/claims/$l.claim" ] && [ "$(st "$l")" = "CLAIMED:$S" ]; } || why="$why a hand claim of a seat alive in its scope was lifted (rc $rc);"
    out="$(xb "$O" expire "$h")"; rc=$?; { [ "$rc" = 1 ] && [ -e "$w/claims/$h.claim" ] && [ "$(st "$h")" = "CLAIMED:grader_97" ]; } || why="$why a hand claim of a seat alive in a window opened by hand was lifted (rc $rc) [$(printf '%s' "$out" | head -1 | cut -c1-90)];"
    out="$(xb "$O" expire "$m")"; rc=$?; { [ "$rc" = 1 ] && [ -e "$w/claims/$m.claim" ]; } || why="$why the caller's own hand claim was lifted (rc $rc);"
    out="$(xb "$O" claim "$d")"; [ "$(head -1 "$w/claims/$d.claim" 2>/dev/null)" = "$O" ] || why="$why the finisher could not claim the lifted row [$(printf '%s' "$out" | grep -m1 -E 'REFUSED|CLAIMED' | cut -c1-90)];"
    verdict "dead=lifted,row=FREE scope_alive=kept hand_window_alive=kept own=kept park_stands=1 walk_lifts_none=1 finisher_claims=1";;
*) refuse "no step $N (1..16)";;
esac
