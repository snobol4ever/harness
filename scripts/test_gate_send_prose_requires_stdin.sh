#!/usr/bin/env bash
# test_gate_send_prose_requires_stdin.sh -- DONE-WHEN for row send-argv-prose-body-requires-the-stdin-form
# (hq_I 2026-09-13, occurrence FOUR, routed to hq_B as postoffice tooling; hq_I wrote this DONE-WHEN).
#
# THE DEFECT IS NOT A MISSING REFUSAL. s4e_msg.sh send already refuses a body that still CARRIES a backtick
# or $(, on the shape, with no bypass. THE DEFECT IS THAT THE REFUSAL IS STRUCTURALLY BLIND TO THE CASE THAT
# ACTUALLY BITES: a body whose backticks were already eaten by the CALLER's shell arrives clean, shorter, and
# passes every check. hq_I's witness, twice in one message -- two backtick-wrapped code fragments ran as
# commands, failed, and spliced their empty output back in; send reported SUCCESS, correctly, on a body whose
# entire technical content had been deleted. The evidence is gone before send starts, so the cure is a safe
# INPUT PATH, never a validator (hq_T talked hq_I out of the gutted-body detector, and the reasoning is the
# valuable half: it would be a THIRD instrument reporting success while answering a narrower question).
#
# ⛔ WHAT THIS GATE MUST NOT BECOME: an arm that only proves the refusal fires. ARM 1 is the positive control
# and it is the one that keeps the others honest -- a short operational body MUST still send, or the cure has
# simply broken the bus and every "refuses correctly" arm below would still read green.
#
# ARMS (6 arms, 7 checks -- ARM 6 grades two refusal paths): 1 a short operational argv body still sends (POSITIVE CONTROL) · 2 a prose argv body refuses AND
# delivers nothing · 3 hq_I's DONE-WHEN -- a body with a backtick-wrapped word sent through argv either
# arrives with the word intact or refuses, never silently succeeds · 4 the same body via --stdin arrives
# byte-intact · 5 the refusal names the --stdin form, because a refusal that does not say what to do instead
# is a wall.
# EXIT: 0 all arms · 1 an arm failed · 2 REFUSED (cannot measure).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MSG="$HERE/s4e_msg.sh"
[ -f "$MSG" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: s4e_msg.sh not found at $MSG"; exit 2; }
# ⛔⭐ HERMETIC BY CONSTRUCTION -- ITS OWN SCRATCH POSTOFFICE UNDER mktemp, SO THE LIVE FLEET STATE IS NEVER
# TOUCHED. That is the membership test for `make test-postoffice` (its own banner: every gate there builds a
# scratch postoffice and leaves /home/resources/postoffice byte-identical), and it is not a formality here:
# an earlier draft of this gate sent to the seat's REAL inbox and cleaned up after itself, which means a
# concurrent `check` by that seat could have displayed this gate's fixtures as fleet mail. A test that can put
# words in another seat's inbox is not cheap, whatever it costs in seconds.
PO="$(mktemp -d)"; export S4E_POST="$PO"
ME="gatebox"; export S4E_SEAT="$ME"
mkdir -p "$PO/$ME/inbox" "$PO/$ME/archive" || { echo "⛔ REFUSED-TO-GRADE rc=2: could not build a scratch postoffice under $PO"; exit 2; }
printf 'hq_B\n' > "$PO/$ME/HQ"
BOX="$PO/$ME/inbox"
# ✅ PROVE THE SCRATCH BOX IS REALLY THE ONE IN USE BEFORE GRADING ANYTHING. Without this, a future change
# that stops honouring S4E_POST would send this gate's fixtures into the LIVE fleet inbox and every arm below
# would still read green -- a gate silently grading the wrong postoffice, which is the exact family it is in.
_who="$(bash "$MSG" whoami 2>/dev/null | tr -d '[:space:]')"
[ "$_who" = "$ME" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: s4e_msg.sh reports seat '$_who', not the scratch seat '$ME' -- S4E_SEAT/S4E_POST are not being honoured and this gate would write to the live postoffice"; rm -rf "$PO"; exit 2; }
TAG="gatetest-$$"
cleanup(){ rm -rf "$PO"; }
trap cleanup EXIT
fail=0
delivered(){ ls "$BOX"/*"$1"*.msg >/dev/null 2>&1; }

# --- ARM 1 POSITIVE CONTROL: a short operational body must STILL SEND on the argv path -------------------
out=$(bash "$MSG" send "$ME" "$TAG-short" "queue empty" 2>&1); rc=$?
if [ $rc -ne 0 ] || ! delivered "$TAG-short"; then
    echo "⛔ ARM 1 (positive control): a SHORT operational argv body was not delivered (rc=$rc). The cure has broken the bus." >&2
    echo "$out" | tail -3 | sed 's/^/     /' >&2; fail=1
else echo "  OK   ARM 1 a short operational argv body still sends (positive control -- without this the arms below prove nothing)"; fi

# --- ARM 2: a PROSE argv body refuses, and delivers nothing ----------------------------------------------
PROSE="This is a prose body of the kind seats actually write to one another, long enough to be real. It carries a second sentence and comfortably exceeds two hundred bytes, which is the measured separation between an operational one-liner and composed prose."
out=$(bash "$MSG" send "$ME" "$TAG-prose" "$PROSE" 2>&1); rc=$?
if [ $rc -eq 0 ] || delivered "$TAG-prose"; then
    echo "⛔ ARM 2: a PROSE argv body was accepted (rc=$rc, delivered=$(delivered "$TAG-prose" && echo yes || echo no)) -- the safe input path is optional again" >&2; fail=1
else echo "  OK   ARM 2 a prose argv body refuses and delivers nothing"; fi

# --- ARM 3: hq_I's DONE-WHEN -- intact, or refused; never silently delivered with a hole -----------------
# ⛔ THE BACKTICKS ARE REAL HERE AND THAT IS THE ENTIRE POINT: this arm's own shell eats them exactly as a
# seat's would, so what reaches send is the already-gutted body -- the case no validator can see.
# ⛔⭐ AND THE WORD INSIDE THEM MUST NOT BE A RUNNABLE COMMAND. THE FIRST VERSION OF THIS ARM WRAPPED
# `echo $WORD`, WHICH SUCCEEDS AND SPLICES THE WORD BACK IN -- so the arm passed on the CURED tree and passed
# on the UNCURED tree too, proving nothing while reading green (measured, hq_B 2026-09-13). That is the cto's
# control_f shape a third time in one evening: a name asserting a role the measurement contradicts, written
# by someone who had spent the session hunting exactly it. ✅ hq_I's real witness is an IDENTIFIER in
# backticks -- not a command. It fails, splices its empty output, and the word is GONE. That is the body that
# must not be silently delivered, and only this spelling of the arm can tell the two trees apart.
WORD="s4e_pid_acquire"
out=$(bash "$MSG" send "$ME" "$TAG-tick" "The identifier `s4e_pid_acquire` is the one that matters, and this makes it prose. A second sentence keeps it unmistakably composed." 2>&1); rc=$?
if [ $rc -eq 0 ]; then
    if delivered "$TAG-tick" && grep -q "$WORD" "$BOX"/*"$TAG-tick"*.msg 2>/dev/null; then
        echo "  OK   ARM 3 the argv body was accepted AND the word arrived intact"
    else
        echo "⛔ ARM 3 (hq_I's DONE-WHEN): send reported SUCCESS on a body that lost '$WORD' in transit -- a message with a hole in it and rc=0" >&2; fail=1
    fi
else echo "  OK   ARM 3 a backtick-bearing argv body did not silently succeed (refused rc=$rc, nothing delivered)"; fi

# --- ARM 4: --stdin delivers the same body byte-intact ---------------------------------------------------
bash "$MSG" send "$ME" "$TAG-stdin" --stdin >/dev/null 2>&1 <<STDIN
The identifier $WORD is the one that matters, and this makes it prose. A second sentence keeps it composed.
STDIN
if delivered "$TAG-stdin" && grep -q "$WORD" "$BOX"/*"$TAG-stdin"*.msg 2>/dev/null; then
    echo "  OK   ARM 4 the same prose reaches the inbox intact through --stdin"
else
    echo "⛔ ARM 4: --stdin did not deliver the body intact -- the cure names a route that does not work" >&2; fail=1
fi

# --- ARM 5: the refusal must say what to do instead ------------------------------------------------------
if grep -q -- '--stdin' <<<"$(bash "$MSG" send "$ME" "$TAG-prose2" "$PROSE" 2>&1)"; then
    echo "  OK   ARM 5 the refusal names the --stdin form"
else
    echo "⛔ ARM 5: the refusal does not name --stdin. A refusal that does not say what to do instead is a wall, and the next seat works around it." >&2; fail=1
fi
# --- ARM 6: THE LAST LINE OF A REFUSAL IS THE VERDICT, NOT AN EXAMPLE ------------------------------------
# ⛔ hq_B's own defect, measured and reported by the cfo the same night the guard landed. The refusal above ends
# with a usage block whose final line was the heredoc delimiter `MSG`, so a seat doing the ordinary thing and
# TAILING the output saw `MSG` and read it as an echo of a successful send. The cfo lost FOUR sends before
# bisecting -- by length, then by recipient, then by rate -- and only found them by listing the recipient's inbox.
# ⭐ hq_T lost a ruling to the backtick variant an hour earlier and caught it the same way, and wrote the sentence
# this arm exists to hold: READING A SENDER'S OUTPUT FOR A POSITIVE MARKER CANNOT TELL SENT FROM REFUSED -- the same
# shape as a grep over a runner that cannot tell clean from could-not-measure. Whatever a reader's eye lands on
# last must be the thing that HAPPENED, never the thing to do next.
for _case in prose tick; do
    case $_case in
      prose) _out=$(bash "$MSG" send "$ME" "$TAG-a6p" "$PROSE" 2>&1);;
      tick)  _out=$(bash "$MSG" send "$ME" "$TAG-a6t" "A body carrying a literal backtick U+0060 like this one: x. It is prose and it has two sentences." 2>&1);;
    esac
    _last=$(printf '%s\n' "$_out" | grep -v '^[[:space:]]*$' | tail -1)
    if grep -qE 'REFUSED|NOTHING WAS DELIVERED' <<<"$_last"; then
        echo "  OK   ARM 6/$_case the LAST line of the refusal is the verdict"
    else
        echo "⛔ ARM 6/$_case: the last line a tailing reader sees is not a verdict -- it reads as a successful send" >&2
        echo "     last line was: $_last" >&2; fail=1
    fi
done
cleanup
if [ $fail -eq 0 ]; then echo "✅ GATE PASS(0) [test_gate_send_prose_requires_stdin]: 7 checks over 6 arms, the safe input path is the default and the bus still carries operational sends"; fi
exit $fail
