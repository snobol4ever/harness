#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_scratch_is_bounded.sh — the regrow-gate for the 2026-08-23 s267 root-filesystem outage.
#
# WHAT HAPPENED: honest_icon_correctness.sh did `mktemp -d /tmp/icn_corr_XXXXXX` with no cleanup trap and no
# bound on program output, under a caller's `timeout 900`.  deal.icn emitted 6.79GB against the oracle's 285KB,
# the timeout killed the script before cleanup could run, and three abandoned 8-12GB scratch dirs took / to
# 100% and stopped nineteen sessions.  Two files were fixed (e6faa54e, cf937987).  THIS GATE IS THE OTHER HALF:
# two fixes are today, a gate is every day.
#
# ⛔ THE ASYMMETRY THAT MAKES THIS INVISIBLE IN REVIEW, and the reason a gate beats vigilance: on this box
# `/tmp` is on the 125G ROOT partition while `/home` is a separate 503G one.  Nothing in the word "/tmp" says
# that.  A reviewer reading `mktemp -d /tmp/...` sees a normal idiom, not a loaded gun.
#
# TWO CHECKS, DELIBERATELY DIFFERENT STRENGTHS — measured, not assumed (hq_P s267 swept all 289 /tmp-touching
# scripts: 142 already trapped, 49 did not; 25 of those 49 combined untrapped + bare-/tmp mktemp -d; but only
# ONE of the 25 also redirected unbounded PROGRAM output).  So:
#   A. ZERO-ASSERT on the DETONATION-CAPABLE shape (untrapped + bare /tmp + unbounded redirect into the scratch
#      dir).  That set is empty today and must stay empty.  This is the check that would have caught the outage.
#   B. COMPUTED RATCHET on the merely-untidy shape (untrapped + bare /tmp, bounded output).  These leak
#      kilobytes, not gigabytes.  Ranked as hygiene on purpose — denying them borrowed urgency is itself a
#      finding.  The ceiling is measured, never typed; it may shrink, never grow.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
GATE_NAME="test_gate_scratch_is_bounded"
. "$HERE/lib_gate.sh" || { echo "REFUSING: cannot load lib_gate.sh -- the three-exit-code authority (V2-5)." >&2; exit 3; }
gate_parse_args "$@"
gate_require "$HERE" "the scripts directory"
RATCHET="${SCRATCH_LEAK_RATCHET:-23}"
examined=0; danger=0; leak=0; danger_list=""; leak_list=""
for f in "$HERE"/*.sh; do
    [ -f "$f" ] || continue
    b="$(basename "$f")"
    case "$b" in lib_gate.sh|test_gate_scratch_is_bounded.sh) continue ;; esac
    examined=$((examined + 1))
    # Does it mint a scratch dir on the ROOT partition?  Either an explicit /tmp template, or a bare `mktemp -d`
    # (which defaults to $TMPDIR, and $TMPDIR is unset for every seat here, so it lands in /tmp all the same).
    grep -qE 'mktemp -d' "$f" || continue
    grep -qE 'mktemp -d +"?/tmp|mktemp -d *$|mktemp -d *\)|mktemp -d *`' "$f" || continue
    # Does cleanup survive a kill?  A trap on EXIT/INT/TERM is the only thing that runs when `timeout` fires,
    # and `timeout` is how these scripts normally die -- so success-path `rm -rf` does not count.
    grep -qE 'trap [^;]*(EXIT|INT|TERM)' "$f" && continue
    # Untrapped + root-partition scratch.  Now: is the write BOUNDED?  Unbounded means a program's own stdout is
    # redirected into the scratch dir with no cap -- that is the shape that turns a wrong answer into an outage.
    if grep -qE '> *"?\$\{?(WORK|TMPD|TMPDIR|TMP|SCRATCH|D)\b' "$f" \
       && ! grep -qE 'head -c|ulimit -f' "$f"; then
        danger=$((danger + 1)); danger_list="$danger_list $b"
    else
        leak=$((leak + 1)); leak_list="$leak_list $b"
    fi
done
gate_floor "$examined" 50 "shell scripts"
if [ "$leak" -gt "$RATCHET" ]; then
    echo "GATE FAIL(1) [$GATE_NAME]: $leak untrapped bare-/tmp scratch scripts, ratchet is $RATCHET (examined $examined)"
    echo "    These leak small scratch dirs -- hygiene, not an outage -- but the count MAY NOT GROW."
    echo "    Offenders:$leak_list"
    echo "    Fix: trap cleanup EXIT INT TERM, and mint scratch under \$S4E/.scratch (on /home), not /tmp."
    [ "$GATE_STRICT" = "1" ] && exit 1
fi
[ "$leak" -lt "$RATCHET" ] && echo "⭐ [$GATE_NAME]: leak count is $leak, below the $RATCHET ratchet -- lower SCRATCH_LEAK_RATCHET to $leak to lock the gain in."
if [ "$danger" -ne 0 ]; then
    echo "GATE FAIL(1) [$GATE_NAME]: $danger script(s) can fill the root filesystem (examined $examined)"
    echo "    Shape: untrapped + scratch on bare /tmp + a program's unbounded output redirected into it."
    echo "    This is EXACTLY the s267 outage.  It is a zero-assert, not a ratchet."
    echo "    Offenders:$danger_list"
    echo "    Fix all three: scratch under \$S4E/.scratch on /home; trap cleanup EXIT INT TERM; and cap the"
    echo "    output -- 'head -c \$CAP' for a correctness harness (it also SIGPIPEs the runaway), or 'ulimit -f'"
    echo "    for a TIMING harness, where a pipe would sit inside the timed region and measure its own buffering."
    [ "$GATE_STRICT" = "1" ] && exit 1
fi
gate_verdict 0 "scripts able to fill the root filesystem (leakers: $leak, ratchet $RATCHET)"
