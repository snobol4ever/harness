#!/usr/bin/env bash
# s4e_inbox_hook.sh -- ⭐ THE LOOP STEP 1, HARDENED INTO THE HARNESS (hq_C s261, Lon: "But what the loop says
# never happens.  Has this been hardened or do we ask God when you pray?").
#
# ⛔ WHAT WAS BROKEN, AND IT WAS BROKEN FOR EVERY SEAT SIMULTANEOUSLY.  PROTOCOL.md and every CLAUDE.md say
# "At EVERY prompt, before anything else: s4e_msg.sh check".  MEASURED s261: BOTH HQs ran check exactly ONCE,
# at session start, read ten messages each, replied to none, cleared neither, and did not look again for the
# rest of the session.  Four more messages arrived unseen -- including one asking for a receipt, which was the
# very thing Lon was testing.  Lon had to ask "Are you answering your messages?" to discover it.  Two seats,
# no coordination, identical failure: that is not a lapse, it is a MISSING ENFORCEMENT.
#
# ⭐ THE PRECEDENT THAT PROVES THE CURE.  The BANNER law had this exact shape -- "MANDATORY LAST ACT OF EVERY
# SESSION", an instruction no session can follow because a session cannot know which reply is its last.  Lon
# measured the result ("none of the sessions ... NEVER show the required banner") and the fix was NOT a
# sterner rule, it was a `Stop` hook.  Since s255 the banner fires whether the seat finishes, blocks, or is
# cancelled.  THE INBOX LAW HAS THE SAME DEFECT AND NEVER GOT THE SAME FIX.  This is that fix: a
# UserPromptSubmit hook, so the inbox state is in front of the seat at every prompt mechanically.
#
# ⛔ WHY HEADERS AND NOT BODIES.  Dumping 11 dense messages into context at every prompt costs ~10k tokens a
# turn and would itself become the thing a seat learns to skim past.  The hook prints the COUNT and the
# FROM/RE line of each, which is a signal that cannot be misread, and names the command for the bodies.  HQ
# context is the scarcest resource; a reminder that bankrupts it is not a reminder.
#
# ⭐ SEAT-DERIVED, NOT HARDCODED -- the same D-17 PORTABLE-HOME derivation s4e_msg.sh uses, so hq_P, ceo and
# every seat wire the IDENTICAL hook with no per-seat edit.  A hook that hardcodes /home/claude_C would grade
# another seat against this inbox, which is exactly the layer-2 false-GREEN hq_P found in the batons.
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PO="${S4E_POST:-/home/resources/postoffice}"
ME="${S4E_SEAT:-}"
if [ -z "$ME" ]; then case "$S4E" in
    /home/claude)           ME=ceo;;
    /home/claude_ceo)       ME=ceo;;
    /home/claude_cto)       ME=cto;;
    /home/claude_coo)       ME=coo;;
    /home/claude_cfo)       ME=cfo;;
    /home/claude_cao)       ME=cao;;
    /home/claude_cqo)       ME=cqo;;
    /home/claude_icon)           ME=hq_icon;;
    /home/claude_unicon)         ME=hq_unicon;;
    /home/claude_prolog)         ME=hq_prolog;;
    /home/claude_raku)           ME=hq_raku;;
    /home/claude_pascal)         ME=hq_pascal;;
    /home/claude_snocone)        ME=hq_snocone;;
    /home/claude_snobol4)        ME=hq_snobol4;;
    /home/claude_templates)        ME=hq_templates;;
    /home/claude_runtime)          ME=hq_runtime;;
    /home/claude_collector)        ME=hq_collector;;
    /home/claude_zetas)            ME=hq_zetas;;
    /home/claude_packages)         ME=hq_packages;;
    /home/claude_dotnet)           ME=hq_dotnet;;
    /home/claude_jvm)              ME=hq_jvm;;
    # the nine lettered HQ roots were renamed by language on 2026-09-16 (ceo CEO-767, Lon's word); hq_R folded into hq_prolog, hq_U into the cto, hq_V into the cfo
    /home/claude[0-9][0-9]) ME="seat${S4E#/home/claude}";;
    /home/claude[1-9])      ME="seat0${S4E#/home/claude}";;
    *)                      ME="$(basename "$S4E")";; esac; fi
m="$(head -1 "$PO/MODE" 2>/dev/null)"
if [ -n "$m" ]; then printf 'MODE: %s (computed from %s/MODE -- never assume a mode from prose)\n' "$m" "$PO"; else printf '⛔ MODE FILE ABSENT (%s/MODE) -- do not assume a mode; ask ceo.\n' "$PO"; fi
d="$PO/$ME/inbox"
n=$(ls "$d"/*.msg 2>/dev/null | wc -l)
if [ "$n" -gt 0 ]; then
  printf '⛔ POSTOFFICE [%s] -- %s UNREAD. THE LOOP step 1 binds BEFORE anything else: read, then ACT OR REPLY, then clear (an empty inbox IS the acknowledgement). Reading without replying is NOT answering -- that is the s261 failure this hook exists to prevent.\n' "$ME" "$n"
  for f in "$d"/*.msg; do head -1 "$f"; done
  printf 'bodies: bash %s/harness/scripts/s4e_msg.sh check   |   after acting: bash %s/harness/scripts/s4e_msg.sh clear\n' "$S4E" "$S4E"
else
  printf '✅ POSTOFFICE [%s] -- inbox empty. That IS the acknowledgement; nothing owed.\n' "$ME"
fi
# ⭐ SAME DUTY-INTO-HARNESS CLASS AS THIS HOOK ITSELF (hq_B 2026-08-30, row
# commit-trailer-hook-rejects-forbidden-trailers). Git hooks do NOT propagate through clone, so
# the forbidden-trailer commit-msg hook has to be (re)installed per seat, per clone. The row's
# brief offered `make setup` OR the session path; `make setup` runs $ROOT/setup.sh, which DOES
# NOT EXIST in this tree, so it would have installed nothing forever -- the same
# looks-wired-cannot-fire defect this fleet has now measured four times today. This is the live
# path: it runs for every seat at every prompt, costs a cmp per repo, and says nothing unless it
# actually installed something. Never allowed to break the inbox banner above it.
if [ -x "$S4E/harness/scripts/install_commit_msg_hook.sh" ]; then
  _h="$(bash "$S4E/harness/scripts/install_commit_msg_hook.sh" --quiet 2>/dev/null || true)"
  [ -n "$_h" ] && printf '%s\n' "$_h"
fi
