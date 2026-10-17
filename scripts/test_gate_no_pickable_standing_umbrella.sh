#!/usr/bin/env bash
# ../harness/scripts/test_gate_no_pickable_standing_umbrella.sh -- row standing-umbrella-rows-must-not-be-pickable.
# A row whose baton carries `STANDING-UMBRELLA: yes` must never be PICKABLE, using the exact same
# pickability test `s4e_msg.sh next` itself uses (PASS 3, s265): state is FREE or empty, AND no
# claims/<topic>.claim exists. A permanently-open row that is also pickable is livelock: the picker
# is rank-sorted, so a rank-0 umbrella row gets served to every idle seat in the fleet, forever.
# Self-contained per RULES.md: proves the detector both ways against a hermetic scratch postoffice
# BEFORE trusting it to grade the real one (task STEP 3 -- a criterion nobody has seen fail or pass
# is not a criterion).
set -u
PO="${S4E_POST:-/home/resources/postoffice}"

FAILED=0
note() { printf '%s\n' "$1"; }
fail() { printf '⛔ FAIL: %s\n' "$1"; FAILED=1; }

# ── the detector, reusable against any postoffice root ─────────────────────
# Prints one "topic (rank R, state S)" line per pickable standing-umbrella row found; exit 0 = none
# found (gate-clean), exit 1 = at least one found (gate-dirty), exit 2 = could not grade (no QUEUE.tsv).
check_postoffice() {
    local root="$1" bad=0
    local q="$root/QUEUE.tsv"
    [ -f "$q" ] || { echo "no QUEUE.tsv at $root"; return 2; }
    while IFS=$'\t' read -r rank topic _owner state; do
        case "$rank" in ''|\#*) continue;; esac
        [ -n "$topic" ] || continue
        tf="$root/tasks/$topic.task.md"
        [ -f "$tf" ] || continue
        grep -qE '^STANDING-UMBRELLA:[[:space:]]*yes[[:space:]]*$' "$tf" || continue
        # mirror s4e_msg.sh next()'s PASS 3 pickability test EXACTLY (state FREE-or-empty, no claim) --
        # a detector using a different rule than the picker could pass while the picker still livelocks.
        case "$state" in FREE|'') : ;; *) continue;; esac
        [ -f "$root/claims/$topic.claim" ] && continue
        echo "$topic (rank $rank, state ${state:-<empty>})"
        bad=1
    done < <(grep -P '^[0-9]+\t' "$q" | sort -t$'\t' -s -k1,1n)
    return $bad
}

# ── self-test: hermetic scratch postoffice, negative-tested BOTH ways ──────
GATE_WORK="$(mktemp -d)"; trap 'rm -rf "$GATE_WORK"' EXIT
SCRATCH="$GATE_WORK/po"
mkdir -p "$SCRATCH/tasks" "$SCRATCH/claims"
cat > "$SCRATCH/tasks/scratch-umbrella.task.md" <<'EOF'
# TASK scratch-umbrella · owner: unassigned · state: FREE
STANDING-UMBRELLA: yes
GOAL: gate self-test fixture -- never a real row.
DONE-WHEN: false
EOF

note "── self-test arm 1: marked row FREE and unclaimed -- detector must FAIL it ──"
printf '0\tscratch-umbrella\tunassigned\tFREE\n' > "$SCRATCH/QUEUE.tsv"
out1="$(check_postoffice "$SCRATCH")"; rc1=$?
if [ "$rc1" -ne 1 ] || ! printf '%s' "$out1" | grep -q '^scratch-umbrella '; then
    fail "self-test arm 1: detector did not flag a FREE+unclaimed standing-umbrella row (rc=$rc1, out: $out1)"
else
    note "  OK: flagged -- $out1"
fi

note "── self-test arm 2: same row PARKED -- detector must PASS (say nothing) ──"
printf '0\tscratch-umbrella\tunassigned\tPARKED\n' > "$SCRATCH/QUEUE.tsv"
out2="$(check_postoffice "$SCRATCH")"; rc2=$?
if [ "$rc2" -ne 0 ] || [ -n "$out2" ]; then
    fail "self-test arm 2: detector still flagged a PARKED standing-umbrella row (rc=$rc2, out: $out2)"
else
    note "  OK: silent, rc=0"
fi

note "── self-test arm 3: same row FREE but claimed -- detector must PASS (matches next()'s own test) ──"
printf '0\tscratch-umbrella\tunassigned\tFREE\n' > "$SCRATCH/QUEUE.tsv"
: > "$SCRATCH/claims/scratch-umbrella.claim"
out3="$(check_postoffice "$SCRATCH")"; rc3=$?
if [ "$rc3" -ne 0 ] || [ -n "$out3" ]; then
    fail "self-test arm 3: detector flagged a FREE-but-claimed row (rc=$rc3, out: $out3) -- disagrees with next()'s own pickability test"
else
    note "  OK: silent, rc=0"
fi

if [ "$FAILED" -ne 0 ]; then
    echo "⛔ GATE CANNOT RUN: the detector failed its own negative self-test above -- refusing to grade the real postoffice on unproven logic."
    exit 2
fi
note "self-test: all 3 arms correct. Grading the real postoffice ($PO)..."

# ── the real check ──────────────────────────────────────────────────────────
real_out="$(check_postoffice "$PO")"; real_rc=$?
if [ "$real_rc" -eq 2 ]; then
    echo "⛔ GATE CANNOT RUN: $real_out"
    exit 2
elif [ "$real_rc" -ne 0 ]; then
    echo "⛔ GATE FAIL: STANDING-UMBRELLA row(s) are currently pickable -- livelock risk, the picker will serve these:"
    printf '%s\n' "$real_out" | sed 's/^/    /'
    echo "   Fix: bash ../harness/scripts/s4e_msg.sh park <topic>   (or ASSIGNED/BLOCKED -- anything but FREE-and-unclaimed)"
    exit 1
fi
echo "✅ GATE OK: no STANDING-UMBRELLA row is currently pickable."
exit 0
