#!/usr/bin/env bash
# lib_slots.sh -- THE ONE RULE OF THE BOX'S TWO POOLS, WITH A SEAT'S SHARE AND THE GRADER'S RESERVATION (the cto, ARCH-SHARED-DEVELOPMENT.md
# section 4.3 and 4.6, R-2041 step 3; Lon 2026-10-31: "Everyone is compiling at the same time" / "Maximize sharing and minimize contention").
# Sourced by util_cc_slot.sh and util_run_slot.sh (the takers that exec a command) and by the design-step harnesses (which hold a run slot in
# their own shell); corpus_suite_harness.py reads the SAME knobs from this file (the S4E_*_DEFAULT lines below, by name) and follows the same
# rule, which test_gate_pools_cap_a_seat_and_reserve_the_grader.sh checks on both.
#
# THE RULE. Two pools of flock files: compile slots /tmp/s4e-cc-slots/slot0..7 and run slots /tmp/s4e-run-slots/slot0..7 (S4E_CC_SLOTS,
# S4E_RUN_SLOTS override the size; S4E_CC_SLOT_DIR, S4E_RUN_SLOT_DIR the place, the gates' seam). A taker FIRST takes one of its SEAT's files
# (<pool dir>/seat/<seat>/0..cap-1, cap S4E_CC_SEAT_CAP 4 or S4E_RUN_SEAT_CAP 3) and ONLY THEN a pool slot, both held on their own fd for the
# process's life (the kernel frees a killed holder's locks), so a seat at its cap waits on its own files and never on the pool: another seat's
# single compile is never behind one seat's eight. A full pool or a full seat is waited on by RESCANNING every file twice a second, never by
# queuing on one (R-2054). THE GRADER (S4E_CLASS=grader: the coo's loop8 and tier1 and everything they start) takes no seat file and may take
# any run slot; every other taker may take only run slots 0..N-1-S4E_RUN_GRADER_RESERVED, so two run slots always answer the grader at once.
# A run already under a harness slot (S4E_RUN_SLOT_HELD) takes nothing (no nested wait, no deadlock); a compile slot is held by a compiler, a
# leaf that starts nothing. The census reads the holders from /proc/*/fd (a held file is open for the holder's life: kernel truth, no sidecar). The seat is S4E_SEAT (every root's settings env sets it),
# else the first path component under /home of the working directory. A wait of a second or more is one line in SLOT_WAITS.tsv (R-2078).
S4E_CC_POOL_DEFAULT=8
S4E_RUN_POOL_DEFAULT=8
S4E_CC_SEAT_CAP_DEFAULT=4
S4E_RUN_SEAT_CAP_DEFAULT=3
S4E_RUN_GRADER_RESERVED_DEFAULT=2
s4e_slot_seat() { if [ -n "${S4E_SEAT:-}" ]; then printf '%s' "$S4E_SEAT"; else pwd -P | sed -n 's|^/home/\([^/]*\).*|\1|p' | grep . || printf 'seat'; fi; }
s4e_slot_note() {   # <kind> <t0> <cmd>... -- one line per wait of a second or more
    local f w k="$1" t0="$2"; shift 2
    f="${S4E_SLOT_WAITS:-/home/resources/progress/SLOT_WAITS.tsv}"; w=$(awk -v a="$t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.1f", b-a}')
    case "$w" in 0.*) return 0;; esac
    [ -s "$f" ] || printf '# at_utc\tseat\tkind\twait_s\tcmd  -- one line per slot wait of a second or more (R-2078: the pools kept no record, so contention could not be measured)\n' > "$f" 2>/dev/null
    printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$(s4e_slot_seat)" "$k" "$w" "$(printf %s "$*" | tr '\t\n' '  ' | cut -c1-80)" >> "$f" 2>/dev/null
    return 0
}
# s4e_slot_hold <kind> -- take a seat file then a pool slot for THIS shell, on fds 7 (seat) and 8 (run pool) or 9 (compile pool); rc 0 held,
# rc 1 the pool directory cannot be made (the caller runs unbounded, as before). Exports S4E_RUN_SLOT_HELD=1 for a run slot.
s4e_slot_hold() {
    local kind="$1" dir n cap lo hi seat sfd pfd i t0 grader=0
    case "$kind" in
        cc)  dir="${S4E_CC_SLOT_DIR:-/tmp/s4e-cc-slots}"; n="${S4E_CC_SLOTS:-$S4E_CC_POOL_DEFAULT}"; cap="${S4E_CC_SEAT_CAP:-$S4E_CC_SEAT_CAP_DEFAULT}"; pfd=9; hi=$((n - 1)) ;;
        run) dir="${S4E_RUN_SLOT_DIR:-/tmp/s4e-run-slots}"; n="${S4E_RUN_SLOTS:-$S4E_RUN_POOL_DEFAULT}"; cap="${S4E_RUN_SEAT_CAP:-$S4E_RUN_SEAT_CAP_DEFAULT}"; pfd=8
             if [ "${S4E_CLASS:-}" = grader ]; then grader=1; hi=$((n - 1)); else hi=$((n - 1 - ${S4E_RUN_GRADER_RESERVED:-$S4E_RUN_GRADER_RESERVED_DEFAULT})); [ "$hi" -ge 0 ] || hi=0; fi ;;
        *) return 2 ;;
    esac
    sfd=7; seat="$(s4e_slot_seat)"
    mkdir -p "$dir/seat/$seat" 2>/dev/null || return 1
    t0=$(date +%s.%N); local bound; bound="${S4E_SLOT_WAIT_MAX:-}"
    if [ -z "$bound" ]; then if [ "$grader" = 1 ]; then bound=900; else case "$(date +%H)" in 0[6-9]|1[0-9]|2[01]) bound=300;; *) bound=900;; esac; fi; fi
    s4e_slot_bound() { awk -v a="$t0" -v b="$(date +%s.%N)" -v m="$bound" 'BEGIN {exit !(b - a >= m)}' || return 0
        s4e_slot_note "$kind-refused" "$t0" "bound=${bound}s"
        printf 'REFUSE(2) [util_%s_slot]: no %s slot within %s s for %s (pool %s of %s slots, seat cap %s): the box is over-admitted, the wait is recorded in SLOT_WAITS.tsv, nothing ran (box-budget step 5).\n' "$kind" "$kind" "$bound" "$seat" "$n" "$dir" "$cap" >&2
        return 2; }
    if [ "$grader" = 0 ]; then
        while :; do
            i=0
            while [ "$i" -lt "$cap" ]; do
                eval "exec $sfd>>\"$dir/seat/$seat/$i\"" || return 1
                if flock -n "$sfd"; then break 2; fi
                eval "exec $sfd>&-"
                i=$((i + 1))
            done
            s4e_slot_bound || return 2
            sleep 0.5
        done
    fi
    while :; do
        i=0
        while [ "$i" -le "$hi" ]; do
            eval "exec $pfd>>\"$dir/slot$i\"" || return 1
            if flock -n "$pfd"; then break 2; fi
            eval "exec $pfd>&-"
            i=$((i + 1))
        done
        s4e_slot_bound || { [ "$grader" = 0 ] && eval "exec $sfd>&-"; return 2; }
        sleep 0.5
    done
    [ "$kind" = run ] && export S4E_RUN_SLOT_HELD=1
    S4E_SLOT_T0="$t0"
    return 0
}
