#!/usr/bin/env bash
# s4e_msg.sh — the postoffice helper (/home/resources/postoffice/PROTOCOL.md is law). Usage:
#   s4e_msg.sh next                       ONE-SHOT PICK-AND-LOCK: resume your own unfinished
#                                         claim, else atomically lock the topmost free QUEUE.tsv
#                                         row and print its brief pointer + first step
#   s4e_msg.sh done <topic>               ⭐ VERIFIES the task baton's DONE-WHEN and REFUSES if it fails
#                                         (LAW 1: done is COMPUTED, never declared). Override, loudly and
#                                         recorded: S4E_DONE_OVERRIDE="why". Claims persist as done-markers.
#                                         Budget: S4E_DONE_TIMEOUT=<seconds>, default 3600. A criterion that
#                                         does not finish REFUSES rc=2 (could not measure) -- distinct from
#                                         rc=1 (measured, red). Raising the budget never weakens the check.
#   s4e_msg.sh ask <topic> "text"         question box: sends to hq as q-<topic>
#   s4e_msg.sh send <to> <topic> "text"   s4e_msg.sh check   s4e_msg.sh clear
#   s4e_msg.sh claim <topic>              s4e_msg.sh board [my new status text]
#   s4e_msg.sh sweep                      ⭐ LAW 4: move landed (DONE) rows out of QUEUE.tsv into
#                                         QUEUE.done.tsv — the buffer must never become a graveyard again
#   s4e_msg.sh assign <seat> <topic>      ⭐ V2-1/LAW 2 ASSIGNMENT IS THE LOCK: HQ writes <seat>'s claim
#                                         atomically + rings a contentless doorbell; that seat's next serves it FIRST
#   s4e_msg.sh mint <topic> [rank] "GOAL"  ⭐ THE ONLY WAY A SEAT CAN ADD NEW WORK (2026-08-29 ceo ruling):
#                                         atomically writes a QUEUE.tsv row + a skeleton task baton; refuses a
#                                         duplicate topic and a bad-topic filename the same way send does
#   s4e_msg.sh banner [topic]             ⛔ MANDATORY LAST ACT OF EVERY SESSION: prints the COMPUTED
#                                         SUCCESS/FAILURE banner + whether re-firing advances anything
set -u
# ⛔ DOTGLOB (seat8, 2026-08-22): every "$S4E"/*/ or "$root"/*/ directory scan below silently skipped
# .github -- bash's bare `*` glob does not match dot-directories by default. That blinds FOUR checks to
# .github specifically: pre-rewrite-clone divergence (banner), this-session commit attribution (banner's
# NOTHING-LANDED headline), unpushed/dirty "safe to /clear" detection (banner), and the fleet health
# dashboard (`fleet`) -- for every seat, always, silently. Measured: a session with a real, pushed .github
# commit + FINDING and a clean handoff_status.sh still printed "NOTHING LANDED" because cmts only walked
# non-dot dirs. `.claude` also becomes visible under dotglob but is not a git repo, so every site's existing
# `[ -d "$r/.git" ] || continue` guard filters it out for free. No other glob in this file is dot-sensitive
# (claims/msg globs are suffix-anchored, e.g. *.claim/*.msg -- nothing here is ever named with a leading dot).
shopt -s dotglob
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 sibling root
PO="${S4E_POST:-/home/resources/postoffice}"
# ⛔⭐ ONE COLUMN FITTER FOR THE WHOLE SCRIPT (Lon 2026-09-13, in-chat, routed by cto to all seats:
# "That banner printed is nu-formatted and un-readble with wrapping text ... Show as a grid."). Anything this
# script prints for a human goes through here, because a line that wraps in an 80-column terminal is not read
# -- and an instrument whose output is not read has not measured anything. ⛔ It clips on DISPLAY columns, not
# bytes: `cut -c80` would saw the banner's 240-byte box rules into a third of a line while missing every real
# offender. The one width authority is dw() in util_suite_banner.py, imported by util_fit_columns.py.
# ⛔ IT CAN NEVER BREAK ITS CALLER: no fitter, or a fitter that dies, degrades to `cat`. The banner's exit
# status is the seat's computed verdict, and a formatter must never hold veto power over the thing it formats.
S4E_FIT="$(dirname "${BASH_SOURCE[0]}")/util_fit_columns.py"
s4e_fit() { if [ -f "$S4E_FIT" ]; then python3 "$S4E_FIT" "${1:-80}" 2>/dev/null || cat; else cat; fi; }
# ⭐ s266 (ceo request, Lon reporting restarted seats assuming DUO): MODE IS COMPUTED, NEVER ASSUMED FROM PROSE.
# /home/resources/postoffice/MODE (ceo custody, first line = value) is the single authority; absent = LOUD, never
# a silent default -- the identity-assert law applied to mode.
s4e_mode_line() { local m; m="$(head -1 "$PO/MODE" 2>/dev/null)"; if [ -n "$m" ]; then printf 'MODE: %s\n' "$m"; else printf '⛔ MODE FILE ABSENT (%s/MODE) -- DO NOT ASSUME A MODE. Ask ceo; DUO-by-default applies ONLY when ceo has not published the file, and its absence here is an ERROR, not a default.\n' "$PO"; fi; }
ME="${S4E_SEAT:-}"
# ⛔⭐ LAW 6 -- IDENTITY IS ASSERTED, NEVER GLOBBED (ARCH-FLEET-CEO.md, preflight V2-4, hq_P s258). The old block
# ended in `*) ME="$(basename "$S4E")"` and every write path did `mkdir -p` on whatever came out. That pair is
# EXACTLY how the phantom `claude01/` mailbox was born: seat01's clone predated the zero-padding commit, its ME
# resolved to the literal "claude01", the script CREATED /home/resources/postoffice/claude01/inbox on the spot,
# and the seat then read an empty box for a day while HQ's real mail piled up in seat01/. An invented identity
# that silently succeeds is the "non-empty is not alive" false-signal class on the fleet bus itself. Now: the
# guess is CANONICALISED first (the known legacy spellings fold onto their real mailbox), then ASSERTED -- and
# an identity with no mailbox is a loud non-zero exit, never a fresh directory.
# ⭐ /home/claude IS `ceo` (Lon s257 topology ruling). The legacy `hq` mailbox stays readable until its backlog
# drains; it is simply no longer any root's identity.
s4e_canon() { case "$1" in
    claude)                    echo ceo;;
    claude0[1-9]|claude1[0-9]|claude20) echo "seat${1#claude}";;
    claude[1-9])               echo "seat0${1#claude}";;
    seat[1-9])                 echo "seat0${1#seat}";;
    *)                         echo "$1";; esac; }
s4e_boxes() { for _b in "$PO"/*/; do [ -d "$_b/inbox" ] || continue; basename "$_b"; done; }
s4e_assert_box() { [ -d "$PO/$1/inbox" ] && return 0
    # ⛔ EVERY LINE FITTED. This refusal interpolates a filesystem path AND the full mailbox list, so its
    # width is set by the data, not by the format string: measured at 126 columns against a scratch postoffice
    # under /tmp. A refusal that wraps is the worst line in the script to lose -- it is the one a confused
    # reader is trying hardest to read.
    { printf '\n⛔⛔⛔ NO POSTOFFICE MAILBOX FOR %s "%s" ⛔⛔⛔\n' "${2:-identity}" "$1"
      printf '    %s\n' "$PO/$1/inbox"
      printf '    does NOT exist, and this script no longer creates one on the fly (LAW 6:\n'
      printf '    that is how the phantom claude01/ mailbox was born and how seat01 lost\n'
      printf '    a day of HQ mail).\n'
      printf '    known mailboxes: %s\n' "$(s4e_boxes | tr '\n' ' ')"
      printf '    if this identity is genuinely new, an HQ creates it DELIBERATELY:\n'
      printf '        %s mailbox %s\n\n' "$0" "$1"; } | s4e_fit >&2
    exit 3; }
# ⭐ THE OWNING HQ IS A FACT ON DISK, NEVER A GUESS. `ask` used to hardcode `hq`; with hq retiring and two HQs
# owning different questions, guessing would route a correctness question into the perf HQ's backlog. Order:
# $S4E_HQ -> the mailbox's own HQ file -> legacy hq while it still exists -> REFUSE and say so.
s4e_hq() { if [ -n "${S4E_HQ:-}" ]; then echo "$S4E_HQ"
    elif [ -s "$PO/$ME/HQ" ]; then head -1 "$PO/$ME/HQ"
    else echo ""; fi; }
# ⛔⭐ A DRAINED MAILBOX REFUSES DELIVERY -- IT DOES NOT ACCEPT MAIL NOBODY WILL READ.
# A box with a DRAINED file has no reader. Sending there SUCCEEDS at every level this script can see --
# the mv works, the file is non-empty, `sent` prints -- and the message is simply never read by anyone.
# MEASURED 2026-09-03: the ceo found FOUR messages rotting in hq/inbox, including a LON OVERRIDE from
# seat07 unread for eight hours and a cured row whose owner could not close it. ⭐ This is the
# 'non-empty is not alive' false-signal class landing on the bus itself, and it is why the legacy `hq`
# fallback is gone from s4e_hq() above: with every seat carrying an HQ file, that fallback could only
# ever route mail to the one identity guaranteed not to read it.
# ⛔ The rule is DATA, not a hardcoded name: any box may be drained by writing $PO/<box>/DRAINED, and
# the refusal prints that file so the reason travels with the refusal instead of living in this script.
s4e_assert_not_drained() { [ -f "$PO/$1/DRAINED" ] || return 0
    printf '\n⛔⛔⛔ REFUSED: %s IS A DRAINED MAILBOX -- NOTHING WAS SENT ⛔⛔⛔\n' "$1" >&2
    sed 's/^/    /' "$PO/$1/DRAINED" >&2
    _t="$(s4e_hq)"
    if [ -n "$_t" ]; then printf '\n    YOUR HQ is %s, from the HQ file %s.\n' "$_t" "$PO/$ME/HQ" >&2
        printf '    Send it there:  %s send %s <topic> --stdin <<'"'"'MSG'"'"'\n' "$0" "$_t" >&2
        printf '    or let the bus resolve it for you:  %s ask <topic> --stdin <<'"'"'MSG'"'"'\n' "$0" >&2
    else printf '\n    ⛔ AND %s HAS NO HQ FILE (%s) -- an HQ must write one: echo <hq> > %s\n' "$ME" "$PO/$ME/HQ" "$PO/$ME/HQ" >&2; fi
    printf '\n' >&2; exit 2; }
if [ -z "$ME" ]; then case "$S4E" in
    /home/claude)           ME=ceo;;
    /home/claude_ceo)       ME=ceo;;
    /home/claude_cto)       ME=cto;;
    /home/claude_coo)       ME=coo;;
    /home/claude_cfo)       ME=cfo;;
    /home/claude_icon)           ME=hq_icon;;
    /home/claude_prolog)         ME=hq_prolog;;
    /home/claude_raku)           ME=hq_raku;;
    /home/claude_pascal)         ME=hq_pascal;;
    /home/claude_snocone)        ME=hq_snocone;;
    /home/claude_snobol4)        ME=hq_snobol4;;
    /home/claude_templates)        ME=hq_templates;;
    /home/claude_runtime)          ME=hq_runtime;;
    /home/claude_collector)        ME=hq_collector;;
    /home/claude_zetas)            ME=hq_zetas;;
    /home/claude_dotnet)           ME=hq_dotnet;;
    /home/claude_jvm)              ME=hq_jvm;;
    # the nine lettered HQ roots were renamed by language on 2026-09-16 (ceo CEO-767, Lon's word); hq_R folded into hq_prolog, hq_U into the cto, hq_V into the cfo
    /home/claude[0-9][0-9]) ME="seat${S4E#/home/claude}";;
    /home/claude[1-9])      ME="seat0${S4E#/home/claude}";;
    *)                      ME="$(basename "$S4E")";; esac; fi
ME="$(s4e_canon "$ME")"
# release-verbs-refuse-on-unfolded-authority-mail (hq_C 2026-08-30): s4e_unfolded_authority_mail /
# s4e_release_guard_note, used by unclaim/park below. Sourced relative to this script's own
# directory, not cwd, since these subcommands are invoked from anywhere.
. "$(dirname "${BASH_SOURCE[0]}")/lib_release_guard.sh"
# ⭐ SHARED BY next() AND banner() (fix-dispatch-bus-two-failure-modes, s266). Resolve a topic's QUEUE.tsv
# rank, or a large sentinel when the row is absent/orphaned. Hoisted to top level (was a next()-local
# function) so both commands sort candidates the SAME deterministic way instead of each falling back to
# glob (alphabetical) file order whenever a seat holds more than one claim.
qrow()  { grep -P "^[0-9]+\t\Q$1\E\t" "$PO/QUEUE.tsv" 2>/dev/null | head -1; }
qrank() { local row; row="$(qrow "$1")"; [ -n "$row" ] && printf '%s' "$row" | cut -f1 || echo 999999; }
# ⭐ next-tiebreak-by-mint-time-not-file-order (hq_C finding, ceo mint 2026-09-01): a topic's mint
# timestamp, read from its own task file's "minted via `mint` by ..., <ISO-8601>" LINKS line (the
# same line `mint` itself writes). Empty when the file or the line is absent -- PASS 3's sort then
# treats "unknown mint time" as OLDEST within its rank tier (a real timestamp always outranks no
# timestamp), never as a crash or a special case.
s4e_mint_ts() { grep -m1 'minted via `mint`' "$PO/tasks/$1.task.md" 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' | head -1; }
# ⭐ picker-skips-blocked-rows (ceo, 2026-08-28) -- SHARED BY next()'s PASS 3. Is the topic named by a
# BLOCKED-ON:/PARKED-AWAITING: state DONE? `done` only ever APPENDS the DONE marker (never deletes a
# claim) and `park` only ever clears a LIVE non-done claim, so claims/*.claim is the durable record;
# QUEUE.done.tsv is the DONE-WHEN's own belt-and-suspenders for a blocker whose claim some future law
# ever does prune.
s4e_blocker_done() {
    local b="$1"; [ -n "$b" ] || return 1
    [ -f "$PO/claims/$b.claim" ] && grep -q '^DONE$' "$PO/claims/$b.claim" && return 0
    # ⛔⭐ DO NOT "FIX" THIS BY ALSO CHECKING THE ROW'S STATE COLUMN — PRESENCE IS THE WHOLE SIGNAL, AND IT IS SOUND.
    # `sweep` moves a row into QUEUE.done.tsv ONLY IF its claim carries DONE — the IDENTICAL test to the line above
    # (see the sweep) case). So membership here == "claim carried DONE at sweep time", which is exactly what this
    # branch is for. ⛔ QUEUE.done.tsv's col3/col4 are the BUFFER'S values copied verbatim at sweep time and are
    # STALE BY CONSTRUCTION: `done`/OVERRIDE appends DONE to claims/<topic>.claim and nothing rewrites the queue
    # row's state column first, so 171 of 300 landed rows read FREE/ASSIGNED and are nonetheless genuinely DONE.
    # A state check here would reject ~57% of legitimately-done blockers and re-block every row behind them.
    # ⭐ MEASURED, not hypothetical (hq_C 2026-08-28, on seat06's report): this file's HEADER used to name legacy v1
    # columns (`brief`/`first-step-and-done-when`) it has never carried, which makes col4 read as an authoritative
    # state field and makes this branch look like a presence-vs-state bug. It is not. seat06 read this function
    # carefully, reproduced the symptom twice, and released a rank-1 row (tests-consolidate-icon) TWICE on a
    # correctly-observed symptom with a non-existent root cause — the blocker (icon-corpus-semicolonize) had been
    # genuinely DONE by documented OVERRIDE since 2026-08-24, and branch 1 above fires on it anyway.
    # FINDING-2026-08-28-hq_C-the-done-tsv-header-named-columns-the-file-does-not-have.md
    grep -qP "^[0-9]+\t\Q$b\E\t" "$PO/QUEUE.done.tsv" 2>/dev/null
}

# ⭐ s4e-park-adds-a-blocker-and-refuses-an-unresolvable-topic — a state may now be a '+'-joined SET of
# blockers (BLOCKED-ON:B1+B2), each an independently-plausible reason recorded by a separate park rather
# than one overwriting the other. This answers "which one, if any, is done" so the self-heal (and the
# DOES-NOT-CLEAR check, which needs the SPECIFIC blocker) can treat "any member resolves" as sound self-clear.
s4e_first_resolved_blocker() {   # <possibly '+'-joined blockers> -> prints the first resolved one, rc 1 if none
    local blk="${1:-}" b save_IFS
    [ -n "$blk" ] || return 1
    save_IFS="$IFS"; IFS='+'
    for b in $blk; do
        IFS="$save_IFS"
        if s4e_blocker_done "$b"; then printf '%s' "$b"; return 0; fi
        IFS='+'
    done
    IFS="$save_IFS"
    return 1
}

# ⭐ s4e-done-does-not-clear-annotation (ceo 2026-08-29, hq_B's "your call" ask). SELF-CLEAR (above) earns
# its keep and stays; this is the ESCAPE HATCH for the case it measurably got wrong: hq_B found
# `snocone-parser-fixture-ast-drift-ruling` self-clear a dependent while its OWN ledger and the blocker's
# both said, in bold, "closing this row must not be read as clearing it" for that one dependent (the fix
# does not reach family 5) — a counter-finding written in PROSE changed nothing, because the dispatcher
# reads only the thin QUEUE.tsv record, never the baton text. So the annotation lives where the dispatcher
# already looks: the BLOCKER's own state column, spelled `DOES-NOT-CLEAR:<dep1>[,<dep2>,...]` appended
# after its base state (e.g. `DONE:DOES-NOT-CLEAR:snocone-parser-fixture-family5`). ⛔ Deliberately NOT a
# check of `s4e_blocker_done` above — that function's own law is "presence in the claim/QUEUE.done.tsv is
# the WHOLE done-ness signal, never the state column" (the state column is stale on ~57% of landed rows).
# This function answers a DIFFERENT question (did the blocker's author name ME as an exception), which is
# the one place the state column IS the authority per ceo's ruling — the two never overlap in what they
# certify, and neither should read the other's evidence.
s4e_does_not_clear() {   # <blocker-topic> <dependent-topic> -> rc 0 iff blocker's row names dependent
    local blk="${1:-}" dep="${2:-}" st names
    [ -n "$blk" ] && [ -n "$dep" ] || return 1
    st="$(s4e_row_state "$blk")"
    case "$st" in *DOES-NOT-CLEAR:*) ;; *) return 1;; esac
    names="${st#*DOES-NOT-CLEAR:}"          # everything after the marker...
    case "$names" in *:*) names="${names%%:*}";; esac   # ...up to a further ':'-clause, if any follows
    case ",$names," in *",$dep,"*) return 0;; esac
    return 1
}

# ⭐⭐ picker-dependency-and-boomerang-blindness (hq_B, 2026-08-28) — THREE CURES FOR ONE SYMPTOM: THE PICKER
# CANNOT SEE A DEPENDENCY A HUMAN KNOWS, so every seat re-pays the discovery cost. hq_P's census measured FOUR
# instances IN ONE DAY. All three cures below are MECHANISM-level; a per-row fix is precisely what we did four
# times already, and four hand-cures of one disease is the evidence that hand-curing is not the cure.
s4e_row_state() { qrow "${1:-}" | cut -f4; }

# ⭐ CURE 3 — A GRANT-WAIT IS NOT A PARK. `perf-nv-set-fn-o0-overhead` was re-served SEVEN times in one day
# (seat05 four times in NINE MINUTES) on a blocker no seat could ever clear: it needed a governance grant from
# Lon. Neither existing state fits. PARKED is routing, liftable by anyone with `park <topic> FREE`; the
# BLOCKED-ON:/PARKED-AWAITING: family SELF-CLEARS the instant its named topic goes DONE. A grant names no topic
# and never goes DONE, so both spellings are lies about the same wait. GRANT-NEEDED is its own state: the picker
# skips it, it never self-clears, and `park <topic> FREE` REFUSES on it unless S4E_GRANT_BY names the grant.
# ⛔ PARKED-LON-HOLD is honoured as a SYNONYM, not migrated away, because THREE LIVE ROWS ALREADY CARRY IT — the
# fleet invented this state by hand before the tool had one, exactly as it had invented PARKED-AWAITING before
# BLOCKED-ON existed. A canonical spelling that orphans the rows already using the ad-hoc one cures nothing.
# ⭐⭐ RESTRICTED:<x> — THE STATE THAT SURVIVES ITS OWN RELEASE (ceo ruling 2026-08-29, on hq_P's report; implemented hq_P).
# ⛔ WHY IT IS NOT JUST ASSIGNED WITH A DIFFERENT NAME: ASSIGNED:<x> was carrying TWO meanings with DIFFERENT LIFETIMES.
# (1) DISPATCH — HQ handed this work to x; when x lets go the assignment IS spent, and ceo's 2026-08-28 always-FREE
# unclaim ruling is exactly right for it. (2) RESTRICTION — this row may only EVER be worked by x (CEO-19 HQ-only rows):
# releasing a lock does not spend that, because the restriction belongs to the ROW and not to one episode of work on it.
# One spelling, two lifetimes, so no single rule about what release does could serve both -- and the one we had silently
# destroyed (2). MEASURED, not theorised: hq_P released defect-c-zop-flat-regime-depth-compensate with plain `unclaim`,
# the column went FREE, and seat16's `next` locked an HQ-only codegen row within minutes -- precisely the scenario that
# row's own header was minted to prevent. ⛔ THE PATCH WE REFUSED, and the refusal is the load-bearing part: special-case
# ASSIGNED:<hq> inside unclaim. That keys behaviour on WHO the assignee is rather than WHAT the state means, so the first
# restricted row assigned to a non-HQ breaks in silence -- the keyed-on-identity-not-behaviour shape banned elsewhere in
# this project for the same reason. A distinct spelling makes the lifetime a property of the STATE, checkable by machine.
s4e_restricted_to() { case "${1:-}" in RESTRICTED:?*) printf '%s' "${1#RESTRICTED:}"; return 0;; *) return 1;; esac; }
s4e_is_grant_wait() { case "${1:-}" in GRANT-NEEDED|GRANT-NEEDED:*|PARKED-LON-HOLD|PARKED-LON-HOLD:*) return 0;; *) return 1;; esac; }

# ⭐ CURE 2 — THE RELEASE BOOMERANG. seat01 released rank-0 `icon-n2` and the picker served THE SAME ROW BACK
# two minutes later, because a released row is instantly the top free row again and nothing remembered who let
# it go. That is a livelock, not a dispatch: the one seat guaranteed to refuse a row again is the seat that just
# judged it "not mine". `unclaim` now leaves a receipt under released/, and PASS 3 will not serve a row back to
# ITS OWN releaser inside the cooldown. ⛔ IT HIDES THE ROW FROM THE RELEASER ONLY — every other seat still sees
# it, which is the entire point: the row must stay live for the fleet, or this cure becomes the s265 disease it
# is modelled on. Any OTHER seat claiming it, or an HQ assigning it, DELETES the receipt — "without another
# seat/HQ touching it" is the row's own wording for when the cooldown ends early.
s4e_boomerang_hold() {   # <topic> -> rc 0 if THIS seat released it too recently to be served it back
    local r="$PO/released/${1:-}.release" who when now cool
    [ -f "$r" ] || return 1
    who="$(sed -n 1p "$r" 2>/dev/null)"; when="$(sed -n 2p "$r" 2>/dev/null)"
    [ "$who" = "$ME" ] || return 1
    case "$when" in ''|*[!0-9]*) return 1;; esac
    cool="${S4E_RELEASE_COOLDOWN:-3600}"; case "$cool" in ''|*[!0-9]*) cool=3600;; esac
    now="$(date -u +%s)"; [ "$((now - when))" -lt "$cool" ]
}
s4e_release_receipt() { mkdir -p "$PO/released" 2>/dev/null || return 0; printf '%s\n%s\n' "$ME" "$(date -u +%s)" > "$PO/released/${1}.release" 2>/dev/null || true; }
s4e_release_clear()   { rm -f "$PO/released/${1}.release" 2>/dev/null || true; }

# ⭐ CURE 1 — DEPENDENCY INVERSION: THE BLOCKER OUTRANKS THE BLOCKED, WHATEVER THE COLUMNS SAY.
# `prolog-call-n-user-predicate-segfault` (rank 1) blocked `polyglot-scrip-demos-10-working`, the umbrella
# outranked its own blocker, and so the rank-sorted picker served the BLOCKED work first — cured by hand that
# once, by a ceo re-rank 2->1. Re-ranking by hand does not scale and does not survive the next mint: rank is a
# human's GUESS at priority, a dependency is a FACT, and a fact outranks a guess. PASS 3 no longer merely skips
# a blocked row — it walks the chain and serves the blocker AT THE BLOCKED ROW'S OWN RANK POSITION.
# ⛔ Bounded at 8 hops with a seen-set: a dependency CYCLE must degrade to "skip", never spin. Every reason to
# decline promotion returns 1 and lets the caller fall through to the ordinary skip — this function can only
# ever ADD a serve the picker would not otherwise make, never suppress one it would.
s4e_servable_blocker() {   # <blocked-topic> -> prints the topic to serve INSTEAD, or nothing (rc 1)
    local cur="${1:-}" seen=" " blk st depth=0
    while [ "$depth" -lt 8 ]; do
      depth=$((depth+1))
      case "$(s4e_row_state "$cur")" in BLOCKED-ON:*|PARKED-AWAITING:*) st="$(s4e_row_state "$cur")"; blk="${st#*:}";; *) return 1;; esac
      [ -n "$blk" ] || return 1
      case "$seen" in *" $blk "*) return 1;; esac        # cycle -> skip, never spin
      seen="$seen$blk "
      s4e_blocker_done "$blk" && return 1                # resolved: the caller's self-heal owns this case
      [ -n "$(qrow "$blk")" ] || return 1                # dangling blocker: no row exists to serve
      [ -f "$PO/claims/$blk.claim" ] && return 1         # already someone's
      s4e_boomerang_hold "$blk" && return 1              # never promote a row I myself just released
      case "$(s4e_row_state "$blk")" in
        FREE|'')                        printf '%s' "$blk"; return 0;;   # servable -> promote it
        RESTRICTED:*)                   [ "$(s4e_restricted_to "$(s4e_row_state "$blk")")" = "$ME" ] && { printf '%s' "$blk"; return 0; }; return 1;;   # only its own owner
        BLOCKED-ON:*|PARKED-AWAITING:*) cur="$blk";;                     # transitive -> walk deeper
        *)                              return 1;;                       # parked/grant-gated -> nothing to promote
      esac
    done
    return 1
}
# ⭐ THE CHAIN, SPELLED OUT (ceo 2026-09-26, row instruments-next-dependency-inversion-serves-an-officer-another-lane-s-row-
# three-times-in-one-sitting-the-promoted-blocker-must-be-in-the-picker-s-own-lane, case (b)). s4e_servable_blocker walks
# the hops and returns the LAST one, but every line the picker printed named only the FIRST: the ceo read "rank-1
# bench-rivals-raku-pascal is BLOCKED-ON raku-frontend-real-world-syntax-gaps, which is un-DONE, unclaimed and FREE" over
# a lock on raku-roast-100-percent-compile, a row that line never named -- and the first hop was BLOCKED-ON, not FREE.
# Same walk, same 8-hop bound, printed as hop -> hop -> served.
s4e_blocker_chain() {   # <blocked-topic> <promoted-topic> -> "hop1 -> hop2 -> ... -> promoted"
    local _cur="$1" _end="$2" _out="" _st _blk _d=0
    while [ "$_d" -lt 8 ]; do
      _d=$((_d+1))
      _st="$(s4e_row_state "$_cur")"
      case "$_st" in BLOCKED-ON:*|PARKED-AWAITING:*) _blk="${_st#*:}";; *) break;; esac
      _out="${_out:+$_out -> }$_blk"
      [ "$_blk" = "$_end" ] && break
      _cur="$_blk"
    done
    printf '%s' "${_out:-$_end}"
}
# ⭐ WHOSE ROW, BY THE OWNER CELL ALONE: the named owner, or empty when the cell is blank or `unassigned`. The lane a row's
# LANGUAGE maps to is s4e_topic_lane's question and a different one -- an unowned row stays with the lane cut below.
s4e_row_owner_named() { local _o; _o="$(qrow "${1:-}" | cut -f3)"; case "$_o" in ''|unassigned) ;; *) printf '%s' "$_o";; esac; }
# ⭐ AN OWNER CELL IS IN MY LANE when it names me, or names the lane I resolve to and that lane is not me -- a numbered
# seat's HQ (s4e_my_lane reads its HQ file). ⛔ NOT s4e_hq: under the consolidated modes EVERY HQ file names an officer
# (hq_icon's reads ceo, hq_raku's reads cto; the officers' read ceo), which is where `ask` routes, not a lane. Read as a
# lane it handed the coo and hq_icon the ceo's rows and hq_raku the cto's (measured on a TENET fixture 2026-09-26).
s4e_owner_in_my_lane() {   # <owner-cell> -- rc 0 = mine, rc 1 = another seat's
    [ "${1:-}" = "$ME" ] && return 0
    [ -n "${_my_lane:-}" ] && [ "$_my_lane" != "$ME" ] && [ "${1:-}" = "$_my_lane" ]
}
# ⭐ THE BLOCKER'S OWNER IS TOLD (the same row's GOAL: "the blocked row stays blocked, the blocker's owner is told or
# doorbelled"). Rung only from `next` run by the BLOCKED row's own seat -- a seat walking past another seat's blocked row
# is not the one held up -- and at most once per blocker per S4E_BLOCKER_DOORBELL_COOLDOWN seconds (default a day), so
# ten seats typing `next` ring once. The key is a hash: a topic runs to 191 bytes and the file name must stay legal.
s4e_ring_foreign_blocker_owner() {   # <owner> <blocker> <blocked> <rank> <chain>
    local _who="$1" _p="$2" _b="$3" _r="$4" _ch="$5" _dir="$PO/blocker-doorbells" _f _now _then _cool
    _cool="${S4E_BLOCKER_DOORBELL_COOLDOWN:-86400}"; case "$_cool" in ''|*[!0-9]*) _cool=86400;; esac
    _f="$_dir/$(printf '%s' "$_p" | md5sum | cut -c1-16).rung"; _now="$(date -u +%s)"
    _then="$(head -1 "$_f" 2>/dev/null)"; case "$_then" in ''|*[!0-9]*) _then=0;; esac
    if [ "$((_now - _then))" -lt "$_cool" ]; then
      printf '   %s was told about %s %ss ago; not rung again inside %ss.\n' "$_who" "$_p" "$((_now - _then))" "$_cool"; return 0; fi
    if [ ! -d "$PO/$_who/inbox" ] || [ -f "$PO/$_who/DRAINED" ]; then
      printf '   ⛔ NOT RUNG: %s has no live mailbox -- tell its owner yourself.\n' "$_who"; return 1; fi
    if printf '%s\n' "$ME's next reached rank-$_r $_b, which is BLOCKED-ON $_ch. $_p is your row (owner cell $_who), so the picker did not lock it for $ME: a promoted blocker is locked only inside the picker's own lane, in every pass. $_b stays blocked until $_p lands DONE; your own next serves $_p at rank $_r by dependency inversion. The queue row and its task file are authoritative; this is the doorbell, not a request to reply." \
         | S4E_NO_BANNER=1 "$0" send "$_who" "your-row-blocks-rank-$_r-work" --stdin >/dev/null 2>&1; then
      mkdir -p "$_dir" 2>/dev/null && printf '%s\n%s\n%s\n%s\n' "$_now" "$ME" "$_p" "$_b" > "$_f" 2>/dev/null
      printf '   DOORBELL: %s told that %s holds up rank-%s %s (once per %ss per blocker).\n' "$_who" "$_p" "$_r" "$_b" "$_cool"
    else printf '   ⛔ DOORBELL NOT SENT to %s -- tell its owner yourself.\n' "$_who"; return 1; fi
}
# ⭐⭐ PROMOTION ADMISSIBILITY -- next-dependency-promotion-walks-around-the-mode-lane-filter. MEASURED
# (seat01, MODE FLEET-8 ON SNOBOL4 ONLY): `next` served and LOCKED an Icon row via s4e_servable_blocker
# above with NO lane check and NO language-freeze check at all -- the ordinary FREE-row path below applies
# both before it ever claims a row; the dependency-inversion promotion above applied neither. Checked
# BEFORE $promo is ever claimed (not after, the way s4e_dispatch_gate runs post-claim) so a refusal never
# leaves an abandoned claim behind -- a refuse-then-unclaim two-step would race every other seat's own
# `next` against the brief window the claim existed. Two hard preconditions, checked in the same order
# and with the same semantics the ordinary path already uses for $topic, now applied to $promo too:
# (1) the MODE language freeze, never relaxed (see s4e_language_freeze_refuses); (2) the lane cut, relaxed
# only in the any-lane fallback pass, exactly like the ordinary path's own own-lane/any-lane split. rc 0 =
# admissible; rc 1 = refused, and the reason is already printed -- never a silent skip, per this row's own
# explicit requirement.
# ⛔⭐⭐ THE FLEET-12 RANK CAP -- A SEAT NEVER TAKES A ROW OF RANK 6 OR ABOVE (Lon 2026-09-06 11:20 via ceo,
# MASTER-PLAN sec THE FLEET-12 PLAN, verbatim: "A SEAT NEVER TAKES A ROW OF RANK >= 6: park it back to FREE
# with a one-line note and pick again"). Ranks 6-9 are HQ-ONLY -- design, shared engine, ABI, frames, bignum,
# coexpr, DEFINE m3 -- and the CTO seat works the hardest of them by name.
# ⛔ UNTIL THIS EXISTED THE RULE WAS ENFORCED BY NOTHING. It was law from the moment Lon said it, and every
# `next` a seat ran could still hand them a rank-9 ABI row; the seat would then do it, correctly and
# obediently, because the picker served it. A rule whose only enforcement is that twelve seats each remember
# it is a hope -- the same shape as the style law each DONE-WHEN used to opt into by hand, which went red on
# origin twice in one evening with nobody at fault.
# ⭐ THE AUTHORITY TEST IS s4e_is_hq, WHICH DELIBERATELY COUNTS ceo AND cto. That is exactly right here and it
# is worth saying why, because the neighbouring lane check deliberately does NOT use it: this is an authority
# question (may this identity take HQ-ranked work), not a lane question (whose work is this). cto exists to
# take rank >= 6, and refusing the ceo anything is never correct.
s4e_rank_cap_refuses() {   # <rank> -- rc 0 = REFUSE this row for this identity, rc 1 = admissible
    case "${1:-}" in ''|*[!0-9]*) return 1;; esac   # a non-numeric rank is not a cap decision; leave it to the caller
    [ "$1" -ge 6 ] || return 1
    s4e_is_hq "$ME" && return 1
    return 0
}
s4e_promotion_admissible() {   # <promo-topic> <blocked-topic> <rank>
    local _p="$1" _blocked="$2" _rank="$3" _tl _own _bown _ch
    if s4e_language_freeze_refuses "$_p"; then
      printf '⛔ REFUSED PROMOTION: rank-%s %s is BLOCKED-ON %s, but %s is %s and THE ORDER OF WORK is %s ONLY.\n' \
        "$_rank" "$_blocked" "$_p" "$_p" "$(s4e_topic_language_display "$_p")" "$(s4e_mode_live_languages | tr '[:lower:]' '[:upper:]')"
      printf '   Not promoted, not served -- %s stays skipped this pass; a language freeze is never relaxed by a fallback.\n' "$_blocked"
      return 1
    fi
    # ⛔ THE RANK CAP APPLIES HERE TOO, AND THIS FUNCTION'S OWN HEADER IS THE REASON. It records that the
    # dependency-inversion promotion once served and LOCKED a row with NO lane check and NO language freeze
    # at all, because the ordinary path's cuts were written into the ordinary path. Adding a third cut to
    # only one of the two paths would recreate that defect the same day it is quoted.
    if s4e_rank_cap_refuses "$_rank"; then
      printf '⛔ REFUSED PROMOTION: rank-%s %s is BLOCKED-ON %s, but ranks 6+ are HQ-ONLY under THE FLEET-12 PLAN and you are a seat.\n' \
        "$_rank" "$_blocked" "$_p"
      printf '   Not promoted, not served -- %s stays skipped this pass; ask your HQ to take %s.\n' "$_blocked" "$_p"
      return 1
    fi
    # ⛔⭐⭐ THE OWNER CELL CONSTRAINS A PROMOTION EXACTLY AS IT CONSTRAINS AN ORDINARY PICK, IN EVERY PASS, FOR EVERY
    # IDENTITY (ceo 2026-09-26, row instruments-next-dependency-inversion-serves-an-officer-another-lane-s-row-...,
    # CEO-1232: the officers run no board and hold no HQ's row). MEASURED the same sitting under TENET: `next` LOCKED the
    # cto's gc-the-key-collision-plant-... and hq_raku's raku-roast-100-percent-compile for the ceo. The ordinary path
    # skips a FREE row whose owner cell names another seat; this path never read the cell, and the one check that stood
    # in for it -- CEO-779 below -- bites only a seat owning no language, which the ceo stopped being when TENET gave
    # it rebus. So the blocker of another seat is REPORTED to the blocked row's own seat, its owner is rung, and nothing
    # is locked; a seat walking past someone else's blocked row skips it silently, as it skips every row that is not FREE.
    _own="$(s4e_row_owner_named "$_p")"
    if [ -n "$_own" ] && ! s4e_owner_in_my_lane "$_own"; then
      case "${_promo_reported:-}" in *" $_blocked>$_p "*) return 1;; esac
      _promo_reported="${_promo_reported:- }$_blocked>$_p "
      _ch="$(s4e_blocker_chain "$_blocked" "$_p")"
      _bown="$(s4e_row_owner_named "$_blocked")"
      if ! s4e_seat_owns_a_language; then
        _xlane_refused=$(( ${_xlane_refused:-0} + 1 )); _xlane_last="$_p ($_own's, blocker of $_blocked)"
        printf '⛔ REFUSED PROMOTION: rank-%s %s is BLOCKED-ON %s, which is %s'"'"'s row -- and %s holds NO language under MODE line 2 / the LANES line, so it is never served another lane'"'"'s row, own-lane pass or fallback (CEO-779).\n' \
          "$_rank" "$_blocked" "$_ch" "$_own" "$ME"
      elif [ -z "$_bown" ] || s4e_owner_in_my_lane "$_bown"; then
        printf '⛔ REFUSED PROMOTION: rank-%s %s is BLOCKED-ON %s, and %s is %s'"'"'s row; your lane is %s.\n' \
          "$_rank" "$_blocked" "$_ch" "$_p" "$_own" "${_my_lane:-$ME}"
      else return 1; fi
      printf '   REPORTED, not locked: a promoted blocker is locked only inside the picker'"'"'s own lane, in every pass. %s stays blocked; %s stays FREE for %s.\n' "$_blocked" "$_p" "$_own"
      if [ -z "$_bown" ] || s4e_owner_in_my_lane "$_bown"; then s4e_ring_foreign_blocker_owner "$_own" "$_p" "$_blocked" "$_rank" "$_ch"; fi
      return 1
    fi
    _tl="$(s4e_topic_lane "$_p")"
    # ⛔ A SEAT WITH NO LANGUAGE IS REFUSED ANOTHER OWNER'S BLOCKER IN EVERY PASS (CEO-779). This is the check the
    # own-lane cut below skips in the any-lane pass -- which is exactly how the coo claimed the cfo's rung-2 row and
    # the ceo locked a Raku row: the fallback pass asked no lane question at all. It reads $ME, not $_my_lane, so the
    # ceo (whose s4e_my_lane is deliberately empty) is covered too. Printed as information, never a serve.
    if [ -n "$_tl" ] && [ "$_tl" != "$ME" ] && [ "$_tl" != "${_my_lane:-$ME}" ] && ! s4e_seat_owns_a_language; then
      _xlane_refused=$(( ${_xlane_refused:-0} + 1 )); _xlane_last="$_p ($_tl's, blocker of $_blocked)"
      printf '⛔ REFUSED PROMOTION: rank-%s %s is BLOCKED-ON %s, which is %s'"'"'s row -- and %s holds NO language under MODE line 2 / the LANES line, so it is never served another lane'"'"'s row, own-lane pass or fallback (CEO-779).\n' \
        "$_rank" "$_blocked" "$_p" "$_tl" "$ME"
      printf '   Information, not a serve: %s stays FREE for %s. An instrument row reaches %s by assign or mint; another lane'"'"'s row is an ASK to its owner.\n' "$_p" "$_tl" "$ME"
      return 1
    fi
    if [ -n "${_my_lane:-}" ]; then
      if [ -n "$_tl" ] && [ "$_tl" != "$_my_lane" ] && [ "${_lane_filter:-own-lane}" = own-lane ]; then
        printf '⛔ REFUSED PROMOTION: rank-%s %s is BLOCKED-ON %s, but %s is %s'"'"'s lane and yours is %s.\n' \
          "$_rank" "$_blocked" "$_p" "$_p" "$_tl" "$_my_lane"
        if s4e_any_lane_closed; then printf '   Not promoted; %s stays skipped -- the any-lane fallback is CLOSED under TENET and QUINTET (ceo CEO-1302 (b), CEO-1356), so no pass retries it cross-lane.\n' "$_blocked"
        else printf '   Not promoted (own-lane pass); %s stays skipped this pass -- retried cross-lane if your own lane has nothing else.\n' "$_blocked"; fi
        return 1
      fi
      if [ -n "$_tl" ] && [ "$_tl" != "$_my_lane" ] && s4e_any_lane_closed; then
        _xlane_refused=$(( ${_xlane_refused:-0} + 1 )); _xlane_last="$_p ($_tl's, blocker of $_blocked)"
        return 1
      fi
    fi
    return 0
}
# ⭐ SAME SHAPE AS s4e_promotion_admissible ABOVE, ONE CHECK LATER IN THE CHAIN: a promoted blocker is
# claimed and served exactly like any ordinary row (row mint-dispatch-refuses-a-placeholder-done-when),
# so it needs the same pre-claim placeholder refusal the ordinary path gets -- calling
# s4e_predispatch_placeholder_check directly (defined below, safe: bash resolves calls at run time, and
# this is only ever invoked from deep inside the `next)` case, well after every function in this file is
# defined) rather than duplicating its text-match logic a second time.
s4e_promotion_placeholder_ok() {   # <promo-topic> <blocked-topic> <rank>; rc 0 = ok to promote+claim, 1 = refused (printed)
    s4e_predispatch_placeholder_check "$1" || return 0
    printf '⛔ REFUSING TO PROMOTE %s (blocker of %s, rank %s) — %s\n' "$1" "$2" "$3" "$_ppc_why"
    printf '   Not claimed. %s stays BLOCKED-ON %s until the blocker'"'"'s baton gets a real DONE-WHEN.\n' "$2" "$1"
    return 1
}
# ⛔⭐ ONE PROCESS PER IDENTITY (ceo RULING 2026-09-03, row bus-refuses-a-second-live-process-under-one-seat-identity).
# MEASURED by seat11, routed by hq_B 16:40: /home/claude11 held TWO live claude processes at once -- an interactive
# session and a scheduled routine (`claude --name Fleet #11 --model claude-sonnet-5 --effort max`, per
# .claude/scheduled_tasks.lock). LAW 6 above derives identity from the ROOT PATH, so BOTH are seat11 to the bus:
# one $ME, one claim namespace, one inbox. The routine left SCRIP dirty mid-edit while the session closed a row.
# ⛔⛔ AND THE RACE IS SILENT FROM BOTH SIDES, WHICH IS THE WHOLE DEFECT -- a claim HIDES its row from the other
# picker, so neither process can see the other and each reads a coherent, entirely wrong world. This is the
# 'non-empty is not alive' false-signal class the DRAINED and phantom-mailbox blocks above already convict,
# arriving one level down: not a stale FILE, a second live WRITER nobody declared.
# ⭐ THE RULE: one process per identity. A scheduled or cron routine never runs in a seat root -- it runs as its
# own identity in its own root, or not at all. The bus ENFORCES that here rather than trusting it.
# ⛔ IDENTITY IS THE PAIR (pid, starttime), NEVER THE PID ALONE. Linux recycles pids; a bare-pid lock eventually
# names a DIFFERENT live process and refuses a seat that is alone in its root -- a guard manufacturing the very
# false signal it exists to remove. /proc/<pid>/stat field 22 is that process's start time and is stable for its
# whole life, so the pair is unforgeable. ⛔ The comm field can contain BOTH spaces and parens, so it is parsed
# after the LAST ')', never by a positional split of the whole line.
s4e_proc_start() { local _s; _s="$(cat "/proc/$1/stat" 2>/dev/null)" || return 1; [ -n "$_s" ] || return 1
    printf '%s' "${_s##*') '}" | awk '{print $20}'; }
s4e_pid_live() { [ -n "${1:-}" ] && [ -n "${2:-}" ] && [ -d "/proc/$1" ] || return 1
    local _s; _s="$(s4e_proc_start "$1")" || return 1; [ -n "$_s" ] && [ "$_s" = "$2" ]; }
# ⛔ RELEASES ONLY OUR OWN LOCK. An unconditional rm would let a crashed verb's cleanup delete the lock of the
# process that legitimately took it next -- worse than never locking, because it fails in the direction of
# pretending the identity is free.
s4e_pid_release() { local _f="$PO/$ME/.pid" _p _t
    [ -n "${_cl_out:-}" ] && rm -f "$_cl_out"
    [ -f "$_f" ] || return 0; read -r _p _t _ < "$_f" 2>/dev/null || true
    [ "${_p:-}" = "$$" ] && rm -f "$_f"; return 0; }
s4e_pid_arm() { trap 's4e_pid_release' EXIT; trap 's4e_pid_release; exit 130' INT; trap 's4e_pid_release; exit 143' TERM HUP; }
s4e_pid_acquire() {
    local _f="$PO/$ME/.pid" _mine _hs _hp _ht _p _t _at _c _tries=0
    _mine="$(s4e_proc_start $$)" || _mine=""
    [ -n "$_mine" ] || { printf '⚠ one-process-per-identity guard INERT: /proc/%s/stat is unreadable, so process identity cannot be MEASURED. Proceeding UNGUARDED.\n' "$$" >&2; return 0; }
    # ⭐ A NESTED SELF-INVOCATION IS NOT A SECOND PROCESS. This script calls itself EIGHT times ("$0" banner /
    # claim / park / send, plus one `exec "$0" send`): a lock that could not tell a descendant from a stranger
    # would deadlock the bus against ITSELF on the very first `board`. The holder exports its (pid,starttime);
    # a descendant sees a LIVE holder for its own seat and passes straight through, taking nothing, releasing
    # nothing -- the parent's trap owns the lock for the whole tree.
    # ⛔ THE `exec` CASE IS THE SUBTLE ONE: exec REPLACES THE IMAGE BUT KEEPS THE PID *AND* THE STARTTIME, so the
    # new image IS the holder rather than a child -- and exec threw the release trap away with the old image.
    # It must RE-ARM or the lock leaks. Distinguished by pid == $$; a recycled pid cannot reach here, its
    # starttime differs. ⛔ A stale S4E_PID_LOCK inherited from a dead run simply fails the liveness test and
    # falls through to a normal acquire -- it can never wedge a fresh process.
    # ⛔ AND THE MARKER MUST AGREE WITH THE LOCK FILE, NOT MERELY NAME A LIVE PROCESS. S4E_PID_LOCK is inherited
    # environment: a stale one from an earlier run, or one leaking in from an unrelated s4e process that happens
    # to be an ancestor, would otherwise wave a genuine second writer straight through. A real descendant's
    # holder is BY CONSTRUCTION the process that wrote $PO/<seat>/.pid, so requiring the pair to match the file
    # costs a descendant nothing and closes the hole. MEASURED: without this the gate for this very row passed
    # standalone and FAILED under `done`, because `done` had exported the marker into it -- a verdict that
    # depended on the caller's environment, which is no verdict at all.
    if [ -n "${S4E_PID_LOCK:-}" ]; then
      IFS=: read -r _hs _hp _ht <<< "$S4E_PID_LOCK"
      if [ "${_hs:-}" = "$ME" ] && s4e_pid_live "${_hp:-}" "${_ht:-}" && [ -f "$_f" ]; then
        read -r _p _t _ < "$_f" 2>/dev/null || true
        if [ "${_p:-}" = "${_hp:-}" ] && [ "${_t:-}" = "${_ht:-}" ]; then
          [ "${_hp:-}" = "$$" ] && s4e_pid_arm; return 0; fi
      fi
    fi
    # ⛔ AN UNWRITABLE MAILBOX MAKES THE GUARD INERT, NOT FATAL. Refusing here would turn one broken permission
    # into a TOTAL bus outage for that seat, including read-only `check` -- the guard becoming a worse defect
    # than the one it polices. Every verb that actually writes still fails on its own write, loudly.
    if [ ! -w "$PO/$ME" ]; then
      printf '⚠ one-process-per-identity guard INERT: %s is not writable, so the lock cannot be taken. Proceeding UNGUARDED.\n' "$PO/$ME" >&2; return 0; fi
    while :; do
      # ⭐ noclobber makes this redirect O_CREAT|O_EXCL -- atomic on every POSIX filesystem, the same guarantee
      # `mint`'s mkdir lock and `claim`'s `ln` lean on. Two verbs racing here: exactly one creates the file.
      if ( set -o noclobber; printf '%s %s %s %s\n' "$$" "$_mine" "$(date -u +%FT%TZ)" "${cmd:-?}" > "$_f" ) 2>/dev/null; then
        export S4E_PID_LOCK="$ME:$$:$_mine"; s4e_pid_arm; return 0; fi
      _p=""; _t=""; _at=""; _c=""
      [ -f "$_f" ] && { read -r _p _t _at _c < "$_f" 2>/dev/null || true; }
      if s4e_pid_live "${_p:-}" "${_t:-}"; then
        printf '\n⛔⛔⛔ REFUSED: ANOTHER LIVE PROCESS ALREADY HOLDS THE IDENTITY %s ⛔⛔⛔\n' "$ME" >&2
        printf '    INCUMBENT  pid %s  -- running `%s`, lock taken %s\n' "$_p" "${_c:-?}" "${_at:-?}" >&2
        printf '    THIS ONE   pid %s  -- running `%s`\n' "$$" "${cmd:-?}" >&2
        printf '    lock file: %s\n' "$_f" >&2
        printf '\n    WHY THIS IS REFUSED RATHER THAN QUEUED: identity is derived from the ROOT PATH (LAW 6), so both\n' >&2
        printf '    processes in %s are "%s" to the bus -- ONE $ME, ONE claim namespace, ONE inbox. A claim HIDES its\n' "$S4E" "$ME" >&2
        printf '    row from the other picker, so the two would race SILENTLY and each would read a coherent, wrong world.\n' >&2
        printf '\n    ONE PROCESS PER IDENTITY (ceo 2026-09-03). A scheduled or cron routine NEVER runs in a seat root:\n' >&2
        printf '    it runs as its own identity in its own root, or not at all. If a routine is the incumbent here, stop\n' >&2
        printf '    it (check %s/.claude/scheduled_tasks.lock) rather than working around this refusal.\n' "$S4E" >&2
        printf '    If pid %s is a verb of YOURS that is legitimately still running (a long `done` DONE-WHEN holds the\n' "$_p" >&2
        printf '    lock for its whole run), wait for it. The lock self-clears the moment that process is gone.\n\n' >&2
        exit 2; fi
      # stale (holder dead, or a torn/empty file) -> self-clear and retry, bounded. Never loops forever.
      _tries=$((_tries+1))
      if [ "$_tries" -gt 3 ]; then
        printf '\n⛔ REFUSED (rc=2, COULD NOT MEASURE): %s exists, names no live process, and could not be cleared after %s attempts.\n' "$_f" "$_tries" >&2
        printf '    This is not a verdict about a second process -- it is the guard saying it cannot tell. Inspect the file by hand.\n\n' >&2
        exit 2; fi
      rm -f "$_f" 2>/dev/null || true
    done
}
cmd="${1:-check}"
# ⛔ THE LOCK IS TAKEN IN THE SAME CASE ARM AS THE IDENTITY ASSERTION, DELIBERATELY: the set of verbs that have
# an identity is exactly the set that can hold one, so the two can never drift apart into a verb that asserts a
# box but takes no lock. `mailbox` is excluded from both -- it is how a NEW identity is created, and it cannot
# lock a mailbox that does not exist yet. ⛔ `check` and `clear` ARE locked, unlike the unread-mail banner below:
# THE LOOP step 1 is `check`, and a `check` that quietly succeeds beside a second live writer is precisely the
# silent-race reading this row exists to abolish. The refusal IS the diagnostic that surfaces the second process.
# ⛔⭐⭐ THE READ-ONLY REPORTING VERBS DO NOT TAKE THE IDENTITY LOCK (ceo CEO-716, 2026-09-13).
# THE LOCK EXISTS FOR ONE REASON, stated in its own refusal text: "A claim HIDES its row from the other
# picker, so the two would race SILENTLY and each would read a coherent, wrong world." `banner` and
# `check` CLAIM NOTHING -- measured, zero claim writes in either -- so holding it buys nothing.
# ⛔ AND IT COST THE WHOLE FLEET: the ceo installed Stop and UserPromptSubmit hooks in all thirteen roots
# that run exactly these two verbs at every turn boundary. `banner` is SLOW -- it runs handoff_status
# across three repos -- so it held the claim mutex for the length of a report, and any verb the seat ran
# in that window died on "ANOTHER LIVE PROCESS ALREADY HOLDS THE IDENTITY hq_*". Lon: "A weird error keeps
# happening to the seats, another process already own the hq_* and just spazes out."
# ⭐ THE GENERAL RULE: A REPORTING VERB MUST NEVER HOLD A MUTEX MEANT FOR MUTATION. If one does, every
# reader becomes a writer for locking purposes, and the slowest reader sets the outage window.
# ⛔⭐⭐ TWO SEPARATE DUTIES ON TWO SEPARATE LINES, AND COLLAPSING THEM INTO ONE `case` IS WHAT BROKE THE
# EXISTENCE ASSERTION FOR EVERY REPORTING VERB. `s4e_assert_box` answers "does this seat EXIST"; `s4e_pid_acquire`
# answers "is another live process already mutating as this seat". Only the SECOND is a mutation mutex, and only
# the second was the defect 0ae4a57cc cured -- Lon's "another process already owns the hq_* and just spazes out",
# caused by the Stop hook's slow `banner` holding the claim mutex for the length of a report. That cure is RIGHT
# and stands: A REPORTING VERB MUST NEVER HOLD A MUTEX MEANT FOR MUTATION.
# ⛔ BUT THE TWO DUTIES SHARED ONE `case`, so exempting banner|check from the LOCK silently exempted them from the
# EXISTENCE CHECK as well, and an unknown or typo'd S4E_SEAT began reading as a CLEAN EMPTY INBOX at rc=0.
# ⭐ THAT IS THE WORST POSSIBLE DIRECTION FOR THIS PARTICULAR FAILURE, WHICH IS WHY IT IS SPLIT RATHER THAN
# PATCHED: under THE LOOP an EMPTY INBOX **IS** THE ACKNOWLEDGEMENT. So a seat whose identity is wrong does not
# get an error it can act on -- it gets the exact reading that means "you are done, nothing is waiting for you",
# and it gets it from the one verb THE LOOP makes mandatory. A seat that does not exist and a seat with no mail
# became indistinguishable, and the indistinguishable one is the silent one. This is the phantom-claude01 class
# the assertion was written for, re-entering through the door a correct fix left open.
# ⭐ THE REUSABLE HALF: A FIX THAT EXEMPTS A VERB FROM A LINE EXEMPTS IT FROM EVERY DUTY ON THAT LINE. When one
# statement discharges two obligations, a change scoped to one of them cannot be scoped at all. Bisected to
# 0ae4a57cc by hq_C 2026-09-13 (mechanism measured directly: S4E_SEAT=nosuchseat -> rc=3 before, rc=0 after), who
# also named this cure -- keep the existence assertion on its own, ahead of and independent of the lock.
case "$cmd" in mailbox|"") ;; *) s4e_assert_box "$ME" identity;; esac
case "$cmd" in mailbox|banner|check|premise|"") ;; *) s4e_pid_acquire;; esac
# /*------------------------------------------------------------------------------------------------------*/
# ⛔⭐⭐ THE CODEGEN CONTROL ARM -- `done` COMPUTES WHETHER A LANDING TOUCHED CODEGEN, AND CITES A BOARD OF ITS
# OWN TREE RATHER THAN RUNNING ONE.  Row done-runs-the-snobol4-master-arm-itself-for-any-row-whose-commits-touch-
# codegen (ceo, CEO-342 rule 4, minted 2026-09-06).  THE INCIDENT: seat11's DEFINE landing d067ceae4 turned 299
# SNOBOL4 rungs entries red and ITS DONE-WHEN PASSED -- the rule "a codegen landing carries the rungs as its
# control arm" lived in prose, so the one command whose job is to certify completion could not see it, and three
# hours of eight HQs went to the bisect, the revert and the re-measure.
#
# ⛔⭐⭐ THE MECHANISM IS **CITE**, NOT **RUN**, AND THAT IS A RULING AND NOT A PREFERENCE (ceo CEO-697,
# 2026-09-13, verbatim: "NO SEAT RUNS A FULL BLOCKING SET FOR A LANDING VERDICT ... your verdict is your row
# DONE-WHEN, the gates your diff touched, and make preflight").  The row's own GOAL anticipated this and offered
# both branches -- "test_corpus_snobol4.sh, OR the one-board-per-tree CITED board of the same tree" -- and CEO-697
# decided which one is lawful.  ⛔ ITS CENTRAL RUNNER IS RETIRED: CEO-697 quoted MODE line 2 under NONET ("every
# rungs and package board is the coo's"), which died with CEO-775; since CEO-1232 the lander grades its own
# language's suites, the gates it touched and make preflight, and every other language's verdict is that HQ's next
# per-landing pass on origin, which stamps the range it covers.  Cite-not-run survives that ruling unchanged.  ⭐ THE REASON THIS MATTERS MORE HERE THAN
# ANYWHERE ELSE: `done` runs in EVERY seat.  A `done` that auto-ran a rung suite board would not merely repeat the
# drift CEO-697 was issued to stop, it would MECHANISE it and make it compulsory -- thirteen seats each firing a
# board on every codegen landing, which is the 25m55s-at-load-11-13 contention the cfo measured, but automated.
# An instrument that enforces a rule by breaking a newer one is not an instrument, it is a second defect.
#
# ⭐ WHAT SURVIVES THE RULING UNCHANGED IS THE HALF THE BATON FLAGGED AS "THE ONE THING NOT TO GUESS": WHICH
# COMMITS COUNT AS TOUCHING CODEGEN IS COMPUTED FROM THE DIFF, NEVER FROM THE SEAT ASSERTING IT.  A seat that
# is asked "did you touch codegen?" answers from memory of what it MEANT to change; the diff answers from what
# it DID change, and the two differ exactly in the cases that matter.  If this were a declaration, the rule it
# mechanises would still be a promise -- which is the state it was already in, in prose, when seat11 landed.
s4e_codegen_paths() {   # THE ONE LIST, in ONE place, so no second copy can drift from it (the emit_rec_fb lesson)
    printf '%s\n' src/templates/ src/emitter/ src/lower/ src/runtime/ src/ir/
}
# s4e_codegen_touched <repo> <claimfile> -- prints the touched codegen paths, one per line; rc 0 = touched.
# ⛔ THREE SOURCES, UNIONED AND EACH NAMED IN THE RECEIPT, because no single one of them sees every landing:
# unpushed commits (origin/main..HEAD) go dark the moment the seat pushes before closing, which is the ORDINARY
# order; commits since the claim catch those, but only while the claim file's mtime survives; and the working
# tree catches what is not committed at all.  A union of honest sources, with the sources PRINTED, beats one
# source that is silently empty -- an empty answer from a source nobody named reads exactly like "no codegen".
# ⛔⭐ (b) IS THIS CLONE'S OWN COMMITS SINCE THE CLAIM, READ FROM ITS REFLOG -- NEVER `git log --since` (coo 2026-09-25,
# on the cfo's measurement). The fleet commits as ONE author, so a time window over HEAD cannot tell this seat's
# landing from any other seat's: the cto's icon-gc row (claimed 09-24 18:10Z) and the cfo's swx row both closed at
# 20:2xZ on 09-25 with the SAME 30 src/ paths written to codegen-landings.tsv, all of them other seats' landings.
# And the window was also shifted: `date -u` printed UTC digits with no zone and git read them as LOCAL time, so it
# opened five hours AFTER the claim (measured: a 30-minute window read 0 commits, a "5 h 30 m" one read the 7) and a
# seat that pushed inside five hours of its claim was invisible to (b). The reflog records what THIS clone did --
# `commit:`, `commit (amend):`, `cherry-pick:`, `revert:` and a rebase's `(pick):` -- while another seat's landing
# arrives only as `merge origin/main: Fast-forward` or `pull: Fast-forward`. The claim time is the claim file's
# BIRTH (a receipt or an OVERRIDE-BY line appends and moves its mtime); mtime only where the filesystem has no birth.
# Seconds against seconds, strictly after the claim's second; a hash HEAD no longer reaches (a rebased-away
# original) is dropped, its pick is the one that landed.
s4e_own_commits_since() {   # s4e_own_commits_since <repo> <epoch> -- one hash per line
    local h
    git -C "$1" reflog --date=unix --format='%H%x09%gd%x09%gs' HEAD 2>/dev/null \
      | awk -F'\t' -v t="$2" '{ s = $2; sub(/^.*@\{/, "", s); sub(/\}$/, "", s); if (s + 0 <= t + 0) next
            if ($3 ~ /^commit( \((amend|merge|initial)\))?: / || $3 ~ /^(cherry-pick|revert): / || $3 ~ /\((pick|continue|reword|edit|squash|fixup)\): /) print $1 }' \
      | sort -u | while read -r h; do git -C "$1" merge-base --is-ancestor "$h" HEAD 2>/dev/null && printf '%s\n' "$h"; done
}
s4e_claim_epoch() {   # s4e_claim_epoch <claimfile> -- the claim's birth in epoch seconds, its mtime where no birth is kept
    local b; b="$(stat -c %W "$1" 2>/dev/null)"
    case "$b" in ''|0|-*|*[!0-9]*) stat -c %Y "$1" 2>/dev/null ;; *) printf '%s\n' "$b" ;; esac
}
s4e_codegen_touched() {
    local repo="$1" cf="${2:-}" pats since files="" h
    [ -d "$repo/.git" ] || return 1
    pats="$(s4e_codegen_paths | tr '\n' ' ')"
    files="$(git -C "$repo" diff --name-only HEAD 2>/dev/null)"                      # (c) working tree
    files="$files
$(git -C "$repo" diff --name-only origin/main...HEAD 2>/dev/null)"                   # (a) unpushed
    if [ -n "$cf" ] && [ -f "$cf" ]; then                                            # (b) this clone's commits since the claim
        since="$(s4e_claim_epoch "$cf")"
        [ -n "$since" ] && for h in $(s4e_own_commits_since "$repo" "$since"); do files="$files
$(git -C "$repo" show --name-only --pretty=format: "$h" 2>/dev/null)"; done
    fi
    printf '%s\n' "$files" | sed '/^$/d' | sort -u | grep -E "^($(s4e_codegen_paths | sed 's:/$:/:' | paste -sd'|' -))" 2>/dev/null
}
# s4e_baton_inherited <batonfile> -- the INHERITED set, READ LIVE from the baton, one entry per line.
# ⛔ NEVER REMEMBERED AND NEVER DEFAULTED TO A LIST: a hard-coded population never announces what it left out,
# which is the defect class this whole guard exists to end.  An ABSENT INHERITED line and an EMPTY one are the
# same answer here -- "nothing is inherited" -- and that is deliberate: the convention (ceo, this row's own
# ledger) is that the HQ writes the line at assignment from the live board, so its absence means none were named.
s4e_baton_inherited() {
    [ -f "${1:-}" ] || return 0
    sed -n 's/^INHERITED:[[:space:]]*//p' "$1" | head -1 | tr ' ' '\n' | sed '/^$/d' | sort -u
}
# s4e_cite_board <db> <scrip> <corpus> <suite> -- prints the FAIL/CRASH program names of a board measured on
# EXACTLY this tree; rc 0 = a board exists and was cited, rc 1 = NO board of this tree (could not measure).
# ⛔⭐ THE TREE IS PART OF THE CITATION AND NOT A LABEL ON IT (hq_S/hq_B, this sitting, measured twice from both
# ends): A RED IS A CLAIM ABOUT A TREE, AND IT IS ONLY AS FRESH AS THE TREE IT WAS MEASURED ON, NOT AS THE CLOCK.
# So this matches on scrip AND corpus and never on recency -- a two-hour-old board of THIS tree is authoritative
# and a two-minute-old board of a tree sixty commits back is worthless, which is the exact inversion a timestamp
# sort would produce.  ⛔ AND rc=1 IS "I COULD NOT MEASURE", NEVER "IT IS GREEN": the caller must keep them apart.
s4e_cite_board() {
    local db="$1" scrip="$2" corpus="$3" suite="$4" rows
    [ -f "$db" ] || return 1
    rows="$(grep -F "	$scrip	$corpus	" "$db" 2>/dev/null | awk -F'\t' -v s="$suite" '$6==s')"
    [ -n "$rows" ] || return 1
    printf '%s\n' "$rows" | awk -F'\t' '$10=="FAIL"||$10=="CRASH"{print $8}' | sort -u
    return 0
}
# ⛔ ORPHANED .msg.* ARE SWEPT ON EVERY RUN (LAW 6, second half). `send` writes the message to a mktemp
# $PO/.msg.XXXXXX and then mv's it into the destination inbox; when that mv failed the temp file just SAT there
# -- one rotted 46 hours at the postoffice root, a seat-to-seat brief neither end ever knew was lost. A message
# whose header still names a reachable mailbox is RE-DELIVERED here; one that does not is REPORTED loudly and
# left on disk. Never deleted: an undeliverable message is evidence, not garbage.
# ⛔⭐⭐ ROWD-CLOSE HANDS OFF OR REDS THE FLEET (CEO-69 batch 5a + CEO-70; row done-must-hand-off-manifest-cited-rows, hq_P).
# THREE IDENTICAL FLEET-WIDE REDS IN ONE DAY: closing a row cited as ROWD evidence in corpus_coverage_manifest.tsv reds
# `make test` for EVERY seat until someone re-points the manifest BY HAND (pas-display-revival 07:49 -> pascal-bench-quick-
# wrong-biggest 08:08 -> pascal-bool-family-truncated-output 14:35, the last caught mid-re-point). The manifest's own law,
# line 15: "ROWD evidence = a task topic that must exist and NOT be DONE." Nothing enforced it, so `done` could red the
# fleet and report success. ⭐ ONE check, placed BEFORE the done/OVERRIDE fork, so both close paths are covered BY
# CONSTRUCTION and cannot drift -- the emit_rec_fb / icn_gen_host_reserve lesson: two copies of one rule DO drift.
# ⛔ MATCHES ON $3=="ROWD" ALONE, never on $1, so a future kind= still trips the guard. FAILS CLOSED by design.
s4e_manifest_rowd_cite() {   # echo the citing manifest line(s) for topic $1; rc 0 = cited (refuse), rc 1 = not cited
    local t="$1" m="$S4E/harness/scripts/corpus_coverage_manifest.tsv"
    [ -n "$t" ] && [ -f "$m" ] || return 1
    awk -F'\t' -v t="$t" '/^#/ {next} $3=="ROWD" && $4==t {print; f=1} END{exit !f}' "$m"
}
s4e_sweep_orphans() { for _o in "$PO"/.msg.*; do [ -f "$_o" ] || continue
    _h="$(head -1 "$_o")"; _to="$(printf '%s' "$_h" | sed -n 's/^FROM [^ ]* TO \([^ ]*\) RE .*$/\1/p')"
    _tp="$(printf '%s' "$_h" | sed -n 's/^FROM [^ ]* TO [^ ]* RE \([^ :]*\).*$/\1/p')"
    _fr="$(printf '%s' "$_h" | sed -n 's/^FROM \([^ ]*\) TO .*$/\1/p')"
    _to="$(s4e_canon "${_to:-}")"; _fr="$(s4e_canon "${_fr:-}")"
    if [ -n "$_to" ] && [ -d "$PO/$_to/inbox" ] && [ -n "$_tp" ]; then
      if mv "$_o" "$PO/$_to/inbox/$(date +%s%N)-${_fr:-unknown}-${_tp}.msg" 2>/dev/null; then
        printf '⭐ ORPHAN SWEPT: a message stranded at the postoffice root was delivered to %s (topic %s, from %s)\n' "$_to" "$_tp" "${_fr:-unknown}"; continue; fi; fi
    printf '⛔ ORPHAN MESSAGE, UNDELIVERABLE AND LEFT IN PLACE: %s -- header reads: %s\n' "$_o" "$(printf '%s' "$_h" | cut -c1-100)" >&2; done; }
# ⭐ ONE mailbox->root map and ONE HQ-set, used by BOTH `fleet` and `banner` so the two views can never
# disagree about who exists. A mailbox with no root is not an error -- `hq` is exactly that today: retiring,
# still holding a 29-message backlog that must stay VISIBLE until it is drained.
# ⛔⭐ THIS IS THE REVERSE OF THE IDENTITY MAP AT :92-97 AND THE TWO MUST AGREE. hq_T WAS MISSING HERE while the
# forward map had it, so `fleet` could not resolve hq_T's root and printed it as "0 STALLED (no root, retiring)"
# with a FAILURE banner WHILE hq_T WAS LANDING ROWS BY THE HOUR (ceo measured 2026-09-03 22:36). A health view
# that INVENTS a dead seat is worse than one that reports nothing: the ceo acts on it. The forward map gained
# hq_T when the fourth HQ opened; this one did not, because nothing checks that two hand-written tables of the
# same fact still agree -- the same class as the per-root digests drifting from RULES.md.
s4e_root() { case "$1" in ceo|hq) if [ -d /home/claude_ceo ]; then echo /home/claude_ceo; else echo /home/claude; fi;; cto) echo /home/claude_cto;; coo) echo /home/claude_coo;; cfo) echo /home/claude_cfo;; hq_icon) echo /home/claude_icon;; hq_prolog) echo /home/claude_prolog;; hq_raku) echo /home/claude_raku;; hq_pascal) echo /home/claude_pascal;; hq_snocone) echo /home/claude_snocone;; hq_snobol4) echo /home/claude_snobol4;; hq_templates) echo /home/claude_templates;; hq_runtime) echo /home/claude_runtime;; hq_collector) echo /home/claude_collector;; hq_zetas) echo /home/claude_zetas;; hq_dotnet) echo /home/claude_dotnet;; hq_jvm) echo /home/claude_jvm;;
    seat0[1-9]|seat1[0-9]|seat20) echo "/home/claude${1#seat}";; *) echo "";; esac; }
s4e_hqboxes() { for _h in hq hq_icon hq_prolog hq_raku hq_pascal hq_snocone hq_snobol4 hq_templates hq_runtime hq_collector hq_zetas hq_dotnet hq_jvm hq_C hq_P hq_B hq_T hq_U hq_S hq_I hq_R hq_V ceo cto coo cfo; do [ -d "$PO/$_h/inbox" ] && echo "$_h"; done; }
s4e_is_hq() { case "$1" in hq|hq_icon|hq_prolog|hq_raku|hq_pascal|hq_snocone|hq_snobol4|hq_templates|hq_runtime|hq_collector|hq_zetas|hq_dotnet|hq_jvm|hq_C|hq_P|hq_B|hq_T|hq_U|hq_S|hq_I|hq_R|hq_V|ceo|cto|coo|cfo) return 0;; *) return 1;; esac; }
# ⛔⭐⭐ ONE AUTHORITY FOR "IS THIS SEAT STANDING", CALLED TWICE (coo 2026-09-20, ceo CEO-1002, row
# instruments-claim-and-next-announce-the-start-of-work-to-every-standing-seat). This case was INLINE in `next`,
# where it could only ever answer the question about $ME -- and the announcing cure has to ask it about EVERY OTHER
# SEAT, to know who to tell. ⛔ A SECOND COPY OF THIS TABLE IS THE ONE THING THAT MUST NOT HAPPEN HERE: it is the
# roster Lon publishes, it changes twice a day (SEPTET is the fourth mode since 09-19), and a stale copy would
# announce to stood-down seats while missing a standing one -- hq_snobol4 2026-09-20: an instrument that
# re-implements another instrument's setup will drift from it silently, and the drift prints as a property of the
# world. So the body MOVED here whole and `next` now calls it; the refusal text and every CEO citation are the
# originals, unedited. rc=0 the seat stands, rc=1 refused with _REFUSE_KIND/_REFUSE_WHY set for the caller to print.
s4e_mode_stands() {   # <seat> <mode> -> rc 0 stands, rc 1 refused (reason in _REFUSE_KIND/_REFUSE_WHY)
  local _seat="$1" _m="$2"
  _REFUSE_KIND=""; _REFUSE_WHY=""
  _dr() { _REFUSE_KIND="$1"; _REFUSE_WHY="$2"; }
  # ⛔⭐⭐ THE ROSTER LINE DECIDES (Lon 2026-10-17, in-chat to the ceo, verbatim: "You can call this mode TENET mode. You will only have 5 modes, SOLO, DUO,
  # TRIO, QUARTET, and TENET (full with varying)."; ceo CEO-1818): the mode NAME is one of five and no longer encodes who stands; MODE's machine-read
  # ROSTER: line names the standing seats and, when present for the mode in force, it alone admits or refuses. The per-name arms below stay only
  # for a MODE that carries no ROSTER line (the bus gates' scratch fixtures), SOLO beside CEO.
  local _rl; _rl="$(grep -m1 '^ROSTER:' "$PO/MODE" 2>/dev/null)"
  if [ -n "$_rl" ] && [ "$_m" = "$(head -1 "$PO/MODE" 2>/dev/null | tr -d '[:space:]')" ]; then
      case " ${_rl#ROSTER:} " in *" $_seat "*) return 0;; esac
      _dr "a seat" "Under $_m the standing seats are the ones MODE's ROSTER line names --${_rl#ROSTER:} -- and $_seat is not one of them (Lon 2026-10-17, CEO-1818: five modes, SOLO DUO TRIO QUARTET TENET, the roster varies)."
      return 1
  fi
         case "$_seat" in
           ceo) : ;;
           # ⛔⭐ AN OFFICER IS A STOOD-DOWN IDENTITY UNDER MODE CEO, AND THE GUARD DID NOT KNOW IT (ceo CEO-755).
           # The case below matched hq_* and seat* and let ceo through by name; cto, cfo and coo matched NOTHING
           # and fell out of the case entirely, so under MODE CEO -- where line 2 says the ceo works the rows
           # itself -- three seats could still lock rows and hide them from the only seat that is standing.
           # The defect was invisible for exactly the reason the comment above names: falling out of a case
           # returns success, so "not refused" and "permitted" are the same observable.
           # ⛔ MODE DUO (Lon 2026-09-19, in-chat to ceo: "let's move to CEO+CTO mode with CEO as Fable 5.1 effort=xhigh and CTO as
           # Fable 5.1 effort=high"; CEO-907): the ceo and the cto work rows; the cfo and the coo stay stood down. The cto arm is
           # split from cfo|coo for exactly CEO-755's reason -- one pattern for three seats under a mode that admits ONE of them
           # would have to fall out of the case for the admitted seat, and falling out returns success for the other two as well.
           # ⛔⭐ DUO-STUPID ADMITS THE cto AND SAYS SO (ceo CEO-1087): an arm that returns success by FALLING OUT of
           # this case is indistinguishable from a missing arm, which is the defect this whole table keeps re-learning,
           # so the admission is written down beside the refusals rather than left to the shape of the case.
           # ⛔⭐ MODE DUO REDEFINED BY LON AS THE ceo AND THE coo (Lon 2026-10-02, in-chat to the ceo, verbatim: "Let's get COO to run our test
           # suites for us and we do the fixing. Go to DUO mode, CEO + COO."; ceo CEO-1398): the coo is the testing officer, the ceo cures, and
           # the cto, the cfo and every HQ stand down. The CEO-907 DUO (ceo + cto) is history; DUO-STUPID keeps the cto, its own reason (CEO-1087).
           cto)     case "$_m" in
                      CEO|SOLO) _dr "an officer" "Under CEO only the ceo works rows -- the cto, the cfo and the coo are stood down.";;
                      DUO) _dr "an officer" "Under DUO only the ceo and the coo work rows -- the coo runs the suites, the ceo cures, and the cto and the cfo are stood down (Lon 2026-10-02, CEO-1398).";;
                      TRIO) _dr "an officer" "Under TRIO the ceo, the coo and hq_runtime work rows -- hq_runtime finishes the collector in asm, the coo runs the tests, and the cto and the cfo are stood down (Lon 2026-10-15, CEO-1809).";;
                      DUO-STUPID|QUARTET|SEXTET|QUINTET|NONET|UNDECET|SEPTET|OCTET|TENET) : ;; esac;;
           # ⛔⭐ MODE TRIO REDEFINED AGAIN (Lon 2026-10-15 17:4x CDT, in-chat to the ceo, verbatim: "Keep HQ-RUNTIME going until he finishes. Shut down all but CEO and
           # HQ-RUNTIME." then "Go to DUO mode." then "Keep COO. Make that TRIO mode."; ceo CEO-1809): the ceo, the coo and hq_runtime; the cto and the cfo are refused
           # BY NAME and every HQ but hq_runtime is refused (CEO-755b). The CEO-1403 roster below (ceo, cto, coo) is history.
           # ⛔⭐ MODE TRIO REDEFINED BY LON AS THE ceo, THE cto AND THE coo (Lon 2026-10-02, in-chat to the ceo, verbatim: "Let's get CTO to fix
           # our hard bugs. Goto TRIO mode: CEO, CTO, and COO."; ceo CEO-1403): the cto and the coo are admitted BY NAME (the cto used to be
           # admitted under TRIO only by falling out of its case, CEO-755b's class), the cfo is refused; the CEO-910 roster below is history.
           # ⛔ MODE TRIO (Lon 2026-09-19, in-chat to ceo: "Go to TRIO mode" ... "I did not mean to say COO, I meant CFO"; CEO-910): the ceo, the cto and
           # the cfo work rows; the coo stays stood down. The cfo arm is split from the coo arm for CEO-755's reason again: under TRIO one of
           # the two is admitted, and a shared pattern would have to fall out of the case for it, which returns success for the other too.
           cfo)     case "$_m" in
                      CEO|SOLO) _dr "an officer" "Under CEO only the ceo works rows -- the cto, the cfo and the coo are stood down.";;
                      DUO) _dr "an officer" "Under DUO only the ceo and the coo work rows -- the coo runs the suites, the ceo cures, and the cto and the cfo are stood down (Lon 2026-10-02, CEO-1398).";;
                      DUO-STUPID) _dr "an officer" "Under DUO-STUPID only the ceo and the cto work rows -- the cfo and the coo are stood down (Lon 2026-09-21, CEO-1087).";;
                      TRIO) _dr "an officer" "Under TRIO the ceo, the coo and hq_runtime work rows -- hq_runtime finishes the collector in asm, the coo runs the tests, and the cto and the cfo are stood down (Lon 2026-10-15, CEO-1809).";;
                      QUARTET|SEXTET|QUINTET|NONET|UNDECET|SEPTET|OCTET|TENET) : ;; esac;;
           coo)     case "$_m" in
                      CEO|SOLO) _dr "an officer" "Under CEO only the ceo works rows -- the cto, the cfo and the coo are stood down.";;
                      DUO) : ;;
                      DUO-STUPID) _dr "an officer" "Under DUO-STUPID only the ceo and the cto work rows -- the cfo and the coo are stood down (Lon 2026-09-21, CEO-1087).";;
                      TRIO|QUARTET|SEXTET|QUINTET|NONET|UNDECET|SEPTET|OCTET|TENET) : ;; esac;;
           hq|hq_*) case "$_m" in   # hq_* not hq_?: a language HQ is hq_prolog, and a pattern that misses it falls out of the case, which returns success (CEO-755b's class)
                      CEO|SOLO) _dr "an HQ" "Under CEO no HQ is standing -- the ceo works the rows itself.";;
                      DUO) _dr "an HQ" "Under DUO no HQ is standing -- the coo runs the suites and the ceo cures (Lon 2026-10-02, CEO-1398).";;
                      DUO-STUPID) _dr "an HQ" "Under DUO-STUPID no HQ is standing -- the ceo and the cto work the rows (Lon 2026-09-21, CEO-1087).";;
                      TRIO) case "$_seat" in hq_runtime) : ;; *) _dr "an HQ" "Under TRIO only hq_runtime stands among the HQs -- the ceo, the coo and hq_runtime work rows, and $_seat is stood down (Lon 2026-10-15, CEO-1809).";; esac;;
                      QUARTET) _dr "an HQ" "Under QUARTET no HQ is standing -- the four officers work the rows (Lon 2026-09-19, CEO-911).";;
                      # ⛔⭐ MODE QUINTET (Lon 2026-09-28 17:2x, in-chat to the ceo, verbatim: "Bring the fleet into QUARTET mode: CEO, CTO, CFO, and COO. Leave HQ-SNOCONE alone. So QUNTET mode."; ceo CEO-1356).
                      # The four officers and ONE language HQ, hq_snocone, named here so that no other hq_* seat is admitted by falling out of the case (CEO-755b).
                      # ⛔⭐ MODE QUINTET REDEFINED (Lon 2026-10-17 11:4x CDT, in-chat to the ceo, verbatim: "Let's get CTO and CFO to join the fleet."; ceo CEO-1811): TRIO's ceo, coo and
                      # hq_runtime plus the cto and the cfo -- the four officers and ONE HQ, now hq_runtime (the collector in asm); hq_snocone is refused by name. The CEO-1356 roster is history.
                      QUINTET) case "$_seat" in hq_runtime) : ;; *) _dr "an HQ" "Under QUINTET only hq_runtime stands among the HQs -- the four officers and hq_runtime work rows, and $_seat is stood down (Lon 2026-10-17, CEO-1811).";; esac;;
                      # ⛔⭐ MODE NONET (Lon 2026-09-25, in-chat to the ceo: "Go now to NONET mode." and, asked which five HQs stand: "SNO, PL, PAS, SNOCONE, and ICON"; ceo CEO-1266).
                      # Written by name for CEO-755b's reason: before this arm every hq_* seat -- hq_raku and the lettered legacy names included -- was admitted under NONET by FALLING OUT of the case.
                      # ⛔⭐ MODE NONET REDEFINED (Lon 2026-10-15 13:3x CDT, in-chat to the ceo, verbatim: "Have the GC collection code written in ASM versus C. Should I fire up HQ-RUNTIME since that is his job?" then "I started HQ-RUNTIME."; ceo CEO-1793): OCTET's four HQs and hq_runtime, named so no other hq_* seat falls out of the case (CEO-755b). The CEO-1266 roster above is history.
                      NONET) case "$_seat" in hq_snobol4|hq_icon|hq_prolog|hq_zetas|hq_runtime) : ;; *) _dr "an HQ" "Under NONET five HQs stand -- hq_snobol4 hq_icon hq_prolog hq_zetas hq_runtime -- and $_seat is not one of them: the four officers and those five work rows, and $_seat is stood down (Lon 2026-10-15, CEO-1793).";; esac;;
                      # ⛔⭐ MODE UNDECET (Lon 2026-10-17, in-chat to the ceo: "We need to create two new HQ seats ... for finishing and polishing snobol4ever/snobol4dotnet and snobol4ever/snobol4jvm. Call them HQ-DOTNET and HQ-JVM." · "These two HQ's will certainly need to be fully apart of our fleet, they just happen not to be SCRIP."; ceo CEO-1817): NONET's five HQs and hq_dotnet and hq_jvm, named here so no other hq_* seat is admitted by falling out of the case (CEO-755b). The two own no SCRIP language; their roots hold no SCRIP clone and run this bus from the ceo root's SCRIP with S4E_HOME naming their root.
                      UNDECET) case "$_seat" in hq_snobol4|hq_icon|hq_prolog|hq_zetas|hq_runtime|hq_dotnet|hq_jvm) : ;; *) _dr "an HQ" "Under UNDECET seven HQs stand -- hq_snobol4 hq_icon hq_prolog hq_zetas hq_runtime hq_dotnet hq_jvm -- and $_seat is not one of them: the four officers and those seven work rows, and $_seat is stood down (Lon 2026-10-17, CEO-1817).";; esac;;
                      # ⛔⭐ MODE SEXTET REDEFINED (Lon 2026-10-02 19:2x, in-chat to the ceo: "Do it yourself." and "I'll fire up HQ-ICON and HQ-SNOBOL4 to help."; ceo CEO-1433): the four officers and hq_icon and hq_snobol4; the CEO-912 SEXTET (hq_prolog and hq_icon) is history.
                      # ⛔⭐ MODE SEXTET REDEFINED AGAIN (Lon 2026-10-10 09:0x CDT, in-chat to the ceo, verbatim: "Let's continue getting Prolog and Raku at 100% like SNOBOL4 and Icon." then "Let's also have HQ-PROLOG and HQ-RAKU join us."; ceo CEO-1591): the four officers and hq_prolog and hq_raku; the CEO-1433 SEXTET is history.
                      SEXTET) case "$_seat" in hq_prolog|hq_raku) : ;; *) _dr "an HQ" "Under SEXTET only hq_prolog and hq_raku stand among the HQs -- the four officers and those two work rows, and $_seat is stood down (Lon 2026-10-10, CEO-1591).";; esac;;
                      # ⛔⭐ MODE DECTET, EXPLICIT AND NOT A FALLTHROUGH (ceo CEO-979, 2026-09-20, on Lon's "Can you add some seats to fix bugs alongside the GC work?"). Before this arm existed an HQ under DECTET was
                      # admitted by FALLING OUT of this case, which returns success -- the admission was correct and nothing in the file said it was INTENDED, which is CEO-755b's class exactly: the hazard is not that
                      # the wrong seat is admitted, it is that no reader can tell an intended admission from a missing arm. The six LANGUAGE HQs are named; every other hq_* name, the lettered hq_B..hq_V included, is refused.
                      # ⛔⭐ MODE SEPTET (Lon 2026-09-20, in-chat to the ceo: "Go to mode SEPTET, with the four current officers and 3 more HQ's as Opus"; ceo CEO-979). THREE language HQs stand, chosen for GC work and
                      # not for language coverage: hq_raku (31 of the 72 no_layout, the 8,000,486-hit method road), hq_snobol4 (31 no_layout, SnoRungs' two tiny-arena reds, the pattern-replacement class) and hq_prolog
                      # (10 no_layout and the findall enumeration defect, the only reds left in the 108-witness battery). hq_pascal and hq_snocone are REFUSED BY NAME rather than omitted: both have ZERO no_layout and
                      # rung suites at 246/246 and 336/336, so there is no GC work to give them, and hq_icon is refused for the same reason at two entries -- a refusal that states its measurement is a decision, not an oversight.
                      # ⛔⭐ MODE SEPTET REDEFINED (Lon 2026-10-10 10:0x CDT, in-chat to the ceo, verbatim: "Give the tasks of mining and vendoring the Prolog programs in /home/resources to another HQ seat. Which HQ do you want on the team?"; ceo CEO-1595): the four officers, hq_prolog, hq_raku and hq_pascal -- the third HQ vendors the Prolog downloads as demos and suites; the CEO-979 SEPTET (hq_raku hq_snobol4 hq_prolog) is history.
                      # ⛔⭐ MODE SEPTET REDEFINED AGAIN (Lon 2026-10-11 10:3x CDT, in-chat to the ceo, verbatim: "I suppose we should start HQ-SNOBOL4, HQ-ICON, and HQ-PROLOG to help."; ceo CEO-1662): the four officers, hq_snobol4, hq_icon and hq_prolog -- the three languages of CEO-1660's order of work (Icon and SNOBOL4 first, then Prolog); the CEO-1595 SEPTET (hq_prolog hq_raku hq_pascal) is history.
                      SEPTET) case "$_seat" in hq_snobol4|hq_icon|hq_prolog) : ;; *) _dr "an HQ" "Under SEPTET three HQs stand -- hq_snobol4 hq_icon hq_prolog -- and $_seat is not one of them: the four officers and those three work rows, and $_seat is stood down (Lon 2026-10-11, CEO-1662).";; esac ;;
                      # ⛔⭐ MODE OCTET (Lon 2026-10-15 10:5x CDT, in-chat to the ceo, verbatim: "Remember also we have Icon and Prolog needing to move most of their BB's operand and locals onto the
                      # RSP-spine cells versus the RBP-activation frames." then "I can start HQ-ZETAS then."; ceo CEO-1778): SEPTET's three HQs and hq_zetas, named here so no other hq_* seat is admitted by falling out of the case (CEO-755b).
                      OCTET) case "$_seat" in hq_snobol4|hq_icon|hq_prolog|hq_zetas) : ;; *) _dr "an HQ" "Under OCTET four HQs stand -- hq_snobol4 hq_icon hq_prolog hq_zetas -- and $_seat is not one of them: the four officers and those four work rows, and $_seat is stood down (Lon 2026-10-15, CEO-1778).";; esac ;;
                      # ⛔⭐ MODE TENET (Lon 2026-09-20, in-chat to the ceo, verbatim: "Let's got to TENET mode, 4 officers and 6 HQ's all running Opus 5 (xhigh). All officers running Opus 5 (max)."; ceo CEO-1010). TEN WORKING SEATS: the four officers and the SIX language HQs.
                      # ⛔ THIS ARM EXISTS BECAUSE THE coo PREDICTED ITS ABSENCE THIS MORNING, verbatim: "both cures are correct today and NEITHER SURVIVES THE NEXT MODE LON NAMES." TENET is that next mode, and the arm is written BEFORE the MODE file is flipped -- the ec3a99b43 order, never the reverse.
                      # TENET is DECTET's roster under Lon's own name for it; the arm is spelled out rather than aliased to DECTET because an alias makes two modes share one reason, and the reasons differ: DECTET was one-HQ-per-language for the shared nodes, TENET is six HQs driving their languages to 100% while the officers finish the GC.
                      TENET) case "$_seat" in hq_icon|hq_prolog|hq_snobol4|hq_snocone|hq_pascal|hq_raku|hq_templates|hq_runtime|hq_collector|hq_zetas) : ;; *) _dr "an HQ" "Under TENET the six LANGUAGE HQs, HQ-TEMPLATES, HQ-RUNTIME, HQ-COLLECTOR and HQ-ZETAS stand -- hq_icon hq_prolog hq_snobol4 hq_snocone hq_pascal hq_raku hq_templates (Lon 2026-09-27, CEO-1321) hq_runtime (Lon 2026-10-07, CEO-1535) hq_collector (Lon 2026-10-07, CEO-1538) hq_zetas (Lon 2026-10-07, CEO-1539) -- and $_seat is not one of them (Lon 2026-09-20, CEO-1010).";; esac;;
                      DECTET) case "$_seat" in hq_icon|hq_prolog|hq_snobol4|hq_snocone|hq_pascal|hq_raku) : ;; *) _dr "an HQ" "Under DECTET the six LANGUAGE HQs stand -- hq_icon hq_prolog hq_snobol4 hq_snocone hq_pascal hq_raku -- and $_seat is not one of them; the lettered hq_B..hq_V are history (CEO-767, CEO-979).";; esac ;;
                      EXECUTIVE) _dr "an HQ" "Under EXECUTIVE only the executives (ceo, cto, coo, cfo) work rows -- every HQ is stood down (Lon 2026-09-07).";; esac;;
           # ⛔⭐ SEXTET AND SEPTET WERE MISSING FROM THIS LIST AND A NUMBERED SEAT WAS ADMITTED BY FALLING OUT OF THE
           # CASE -- CEO-755b's class exactly, found 2026-09-20 by the coo the first time this table was asked about a
           # seat OTHER than $ME (the announcing cure, ceo CEO-1002: its gate mailed seat07 under SEPTET and that is how
           # the hole printed itself). Neither mode has a fleet: SEPTET is four officers and three language HQs (CEO-979)
           # and SEXTET is the officers plus hq_prolog and hq_icon (CEO-912). ⛔ THE LESSON IS THE ONE THIS FILE KEEPS
           # RE-LEARNING: a guard written as "refuse these modes" grows a hole every time Lon names a new one, and the
           # hole is silent because falling out of a case returns success. Every new mode must be added HERE by name.
           seat*)   case "$_m" in
                      CEO|SOLO|EXECUTIVE|DUO|DUO-STUPID|DUET|TRIO|QUARTET|QUINTET|SEXTET|SEPTET|OCTET|NONET|UNDECET|DECTET|TENET) _dr "a fleet seat" "There is NO FLEET in $_m -- only the ceo, the officers and the standing HQs work rows. (DUO is the pre-rename spelling of DUET and is refused too; SEXTET and SEPTET were added 2026-09-20 after a numbered seat was found admissible under both by falling out of this case.)";; esac;;
         esac
  [ -n "$_REFUSE_WHY" ] && return 1
  return 0; }
# ⭐ THE STANDING ROSTER, DISCOVERED AND NEVER TYPED: postoffice mailboxes (the fleet roster, LAW 6) filtered
# through the ONE dispatch authority above, minus drained boxes. This is who `claim` and `next` announce to.
s4e_standing_boxes() {   # [<mode>] -> one standing seat per line
  local _m="${1:-$(head -1 "$PO/MODE" 2>/dev/null | tr -d "[:space:]")}" _b
  for _b in $(s4e_boxes); do
    [ -f "$PO/$_b/DRAINED" ] && continue
    s4e_mode_stands "$_b" "$_m" && echo "$_b"
  done; }
# ⛔⭐⭐ THE BUS ANNOUNCES THE START OF WORK (coo 2026-09-20, ceo CEO-1002 rank 0, on hq_snobol4's self-reported
# witness). claim and next LOCKED A ROW SILENTLY: the bus had claim, assign, ask and send and not one of them told
# another seat that work had STARTED, so the only instrument that reported a collision was a branch that would not
# fast-forward. MEASURED: hq_snobol4 measured the no_layout census for an hour; the cto spent their own hour on the
# same 30 entries and the same cause and landed first at SCRIP 83fb80ee7; hq_snobol4 found out on a failed pull.
# BOTH SEATS HELD ROWS -- the rows did not overlap BY NAME and did overlap BY POPULATION, which a claim on a topic
# string can never catch and a live claims board shown at the moment of taking the row would have.
# ⛔ LON, IN-CHAT TO THE ceo 2026-09-20, VERBATIM: "Them not telegramming before starting is YOUR FAULT! You set up
# the system." -- so this is a defect in the BUS and not a discipline a seat must remember. The ceo's own first draft
# of the law read TELEGRAM THE LANE WHEN YOU START, and they retracted it in the same ruling: a rule converting a
# structural gap into an instruction is obeyed for a week and then not.
# ⭐ IT CANNOT FAIL THE CLAIM. A lock that succeeded and an announcement that did not are two different facts, and
# the seat owns the row either way; every delivery failure is COUNTED AND NAMED instead of aborting the take.
s4e_announce_claim() {   # <topic> -- deliver the notice to every standing seat, then print the neighbourhood
  local _t="$1" _s _n=0 _bad=0 _f _mode _list="" _c _own _k=0
  _mode="$(head -1 "$PO/MODE" 2>/dev/null | tr -d '[:space:]')"
  for _s in $(s4e_standing_boxes "$_mode"); do
    [ "$_s" = "$ME" ] && continue
    _f="$PO/$_s/inbox/$(date +%s%N)-$ME-claim-notice-$_t.msg"
    if { printf 'FROM %s TO %s RE claim-notice-%s\n' "$ME" "$_s" "$_t"
         printf 'WORK STARTED: %s has taken the row %s at %s. This is the bus announcing a claim, not a request and not a question.\n' "$ME" "$_t" "$(date -u +%FT%TZ)"
         printf 'If it overlaps what YOU are measuring -- by population, not by name, which is the overlap a topic string cannot see -- say so now rather than after a failed fast-forward (ceo CEO-1002).\n'; } > "$_f" 2>/dev/null; then
      _n=$((_n+1)); _list="$_list $_s"
    else _bad=$((_bad+1)); printf '⛔ COULD NOT ANNOUNCE to %s -- the row is YOURS regardless; the announcement is what failed\n' "$_s"; fi
  done
  printf -- '-- the neighbourhood, read at the moment you took this row (ceo CEO-1002) --\n'
  printf '  announced to %d standing seat(s) under MODE %s:%s\n' "$_n" "${_mode:-ABSENT}" "${_list:- NONE}"
  [ "$_bad" -gt 0 ] && printf '  ⛔ %d announcement(s) FAILED and are named above -- do not read this line as delivery\n' "$_bad"
  for _c in "$PO"/claims/*.claim; do [ -f "$_c" ] || continue
    _own="$(head -1 "$_c" 2>/dev/null)"; [ "$_own" = "$ME" ] && continue
    [ "$(s4e_claim_verdict "$(basename "$_c" .claim)")" = "HELD" ] || continue
    _k=$((_k+1)); printf '  LIVE CLAIM  %-11s %s\n' "$_own" "$(basename "$_c" .claim)"
  done
  if [ "$_k" -eq 0 ]; then printf '  (no other seat holds a row right now)\n'
  else printf '  ⛔ %d row(s) are being worked RIGHT NOW by other seats. Read them for a POPULATION you are about to\n     measure, not for a name that matches yours -- the 30-entry collision above matched on neither.\n' "$_k"; fi
  return 0; }
# ⭐⭐ THE LANE — topic->seat and identity->seat, so `next` can restrict dispatch. Topic lane: the owner cell
# (QUEUE.tsv field 3) wins when it already names a standing seat — an explicit, already-made decision beats a
# guess; otherwise derived from the topic's LANGUAGE prefix. A topic naming no language (a postoffice/tooling/
# meta row) returns empty: UNDETERMINED, never defaulted, because guessing wrong here would starve or misroute
# a lane the mapping cannot see. Callers must treat empty as lane-neutral (servable from any lane).
#
# ⛔⭐⭐ THE FALLBACK IS A SECOND COPY OF MODE LINE 2, AND A SECOND COPY OF A LAW IS A LAW THAT ROTS (ceo
# CEO-672, verbatim). It did rot: measured 2026-09-13 by the ceo and re-measured independently here, SIX OF
# SEVEN language fallbacks named a seat that does not own that language under NONET — icon->hq_B where Icon is
# the ceo, snobol4->hq_P where it is the cfo, snocone->hq_P where it is hq_I, pascal->hq_P where it is the coo,
# rebus->hq_T where it is hq_S, prolog->hq_C where the cto owns completeness. Exactly one, raku->hq_T, survived.
# ⛔ AND IT FAILED SILENTLY IN BOTH DIRECTIONS AT ONCE, which is why nobody caught it: `next` served rows to
# seats that do not own them AND skipped them for the seats that do. hq_S watched it skip thirty rows before
# locking a SNOBOL4 row it then released unworked.
# ⭐ THE IRONY IS TWELVE LINES UP, AND IT IS THE WHOLE LESSON: s4e_root's comment already records this exact
# class — "nothing checks that two hand-written tables of the same fact still agree" — written when hq_T was
# missing from one of two identity maps. The lane table was the next instance, sitting directly beneath the
# warning. A lesson filed as a fact about one table does not generalise on its own; only an instrument does.
# ⛔ SO THE TABLE IS WRITTEN ONCE, HERE, AND EVERY OTHER READER DERIVES FROM IT. It used to be written twice in
# this one file — the case arms below and the `mint` help text — and by 2026-09-13 the two were stale in
# DIFFERENT directions (the help text still read "hq_I Icon suites", where hq_I is SNOCONE). A third copy is
# what `mint` printed while refusing the very row that cures this.
# ⛔ IT IS STILL A COPY, AND test_gate_picker_lane_table_agrees_with_mode.sh is what keeps it honest. Deriving
# it from MODE line 2 at call time was the other option the ceo offered and it was MEASURED AND REJECTED: the
# only parseable ownership shape ("THE SEATS: RAKU -- hq_T; ...") appears in ONE of the last TEN MODE versions,
# because line 2's phrasing is reinvented at every mode cut. A parser over it would have silently fallen back
# to this table for nine of ten modes — today's bug, with machinery on top and a false claim of freshness.
s4e_lane_languages() { printf 'icon prolog snobol4 snocone pascal raku rebus'; }
s4e_lane_owner_of_language() {
    case "$1" in
      # ⛔ MODE DECTET (CEO-767, 2026-09-16, Lon: one HQ per language, four officers for the shared nodes): each
      # language's completeness AND speed owner is its HQ, named for the language; Rebus is closed and folded
      # into the cfo as keep-green; the officers own no language (cto the spine, cfo the collector and the
      # SNOBOL4 runtime crash classes, coo the one runner, ceo the loop). Written out per language because the
      # gate beside it compares this table to MODE line 2 LANGUAGE BY LANGUAGE, and a table that collapsed to a
      # default would agree with a line 2 that had drifted on six of them without anything noticing.
      # ⛔ MODE CEO (CEO-903, 2026-09-18, Lon in-chat: "I'm thinking we go to CEO mode"): ONE SEAT HOLDS EVERY
      # LANGUAGE. Written out per language rather than collapsed to a default for the same reason the DECTET
      # table above was: the gate compares this table to MODE line 2 LANGUAGE BY LANGUAGE, and a default would
      # agree with a line 2 that had drifted on six of them without anything noticing. The DECTET mapping is
      # kept in the comment above so the flip back is a seven-line edit and not a reconstruction.
      # ⛔ MODE CEO (CEO-1103, 2026-09-22, Lon in-chat to the ceo: "The fleet is quiet. It is just you, CEO. We will get GC 100%, you and me. Go to CEO mode only."): ONE SEAT HOLDS EVERY LANGUAGE again. Written out per language rather than collapsed to a default, for the reason every table above gives: the gate beside this compares it to MODE line 2 LANGUAGE BY LANGUAGE, and a default agrees with a line 2 that has drifted on six of them without anything noticing.
      # ⛔ MODE SEPTET (CEO-979, 2026-09-20, Lon: "Go to mode SEPTET, with the four current officers and 3 more HQ's as Opus"): THREE language HQs stand and they were chosen by GC DEBT, not by
      # language coverage -- hq_raku 31 of the 72 no_layout plus the 8,000,486-hit method road, hq_snobol4 31 no_layout plus SnoRungs' two tiny-arena reds, hq_prolog 10 no_layout plus the findall
      # enumeration defect. The four languages whose HQ is NOT standing stay with the ceo, and rebus stays the cfo's keep-green as under DECTET. Written out per language, never collapsed to a
      # default, for the reason the two tables above give: the gate beside this compares it to MODE line 2 LANGUAGE BY LANGUAGE, and a default agrees with a line 2 that has drifted on four of them.
      # ⛔ MODE TENET (CEO-1010, 2026-09-20, Lon: 4 officers and 6 HQs): EVERY language goes to its own HQ and the three the ceo was holding -- icon, pascal, snocone -- are handed over. Rebus stays the cfo's keep-green at 43/43. The officers own NO language, which is CEO-802 unchanged: they supervise and take the rows an HQ fails at.
      # ⛔ A GC DEFECT IN AN HQ'S OWN LANGUAGE IS THAT HQ'S ROW AND OUTRANKS ITS COMPLETENESS WORK (CEO-1010 condition 1). This is not a preference: class 2 of the unmapped-slot population -- a graph with no frame layout has no map at all -- is PER-LANGUAGE by construction, and the cto assigned it to the HQs in writing before cutting. Without the rank, a live collector defect sits behind 1,455 roast entries.
      # ⛔ MODE EXECUTIVE (CEO-1038, 2026-09-21, Lon in-chat: "We are currently running with only 4 officers, CEO, CTO, CFO,
      # and COO. Just so you are clear."): the six language HQs are stood down and the REVIEWERS of CEO-802 become the
      # owners -- the cto reviewed hq_prolog and hq_raku, the cfo reviewed the other four and already held rebus. This is
      # the CURE owner; the BOARD RUNNER is the coo for all seven on the MODE LANES line, because the coo holds the measure
      # and by CEO-723 holds no cure lane. Written out per language rather than collapsed to a default for the reason every
      # table above gives: the gate beside this compares it to MODE line 2 LANGUAGE BY LANGUAGE.
      # ⛔ MODE TENET RESTORED (CEO-1040, 2026-09-21, Lon: "Go to TENET mode now."): six language HQs at Sonnet 5
      # effort max plus four officers at Opus 5 effort max. Each language's owner is its HQ again; rebus stays the
      # cfo's keep-green. THE HQs OWN ITEM 4 OF THE GC COMMITMENT -- zero gradings lost to the collector -- which is
      # six-way parallel; the officers own items 1-3, which are single-site landings and are not. Written out per
      # language rather than collapsed to a default: the gate beside this compares it to MODE line 2 LANGUAGE BY
      # LANGUAGE, and a default would agree with a line 2 that had drifted on six of them without anything noticing.
      # ⛔ MODE EXECUTIVE RESTORED (CEO-1051, 2026-09-21 13:0x, Lon in-chat to the ceo, verbatim: "I do not think we
      # can afford running the 6 HQ's today. Let's bring those back down. We'll have to get GC complete without them."):
      # the six language HQs stand down again after one afternoon and the CEO-802 REVIEWERS become the cure owners --
      # the cto reviewed hq_prolog and hq_raku, the cfo reviewed the other four and already held rebus. ⛔ THIS TABLE IS
      # MOVED BEFORE THE MODE FILE, NOT AFTER, which is CEO-1046 landed forty minutes earlier and b36a7f709's procedure:
      # two flips on 2026-09-21 left this table stale and make preflight RED FOR EVERY SEAT in BOTH directions inside
      # twenty minutes, the second red produced by the correct cure of the first. The coo's deeper cure -- the gate reads
      # a COMMITTED declaration so a flip that forgets its table is caught AT THE FLIP -- is rowed to them and not yet
      # landed, so until it is, the ORDER of these two edits is the whole guard. Written out per language rather than
      # collapsed to a default for the reason every table above gives: the gate beside this compares it to MODE line 2
      # LANGUAGE BY LANGUAGE, and a default would agree with a line 2 that had drifted on six of them unnoticed.
      # ⛔ MODE TENET RESTORED AGAIN (CEO-1055, 2026-09-21 13:3x, Lon in-chat to the ceo, verbatim: "Well then, I
      # changed my mind once again. Go to TENET mode."): the six language HQs stand back up, each owning its own
      # language; rebus stays the cfo's keep-green. ⛔ THIS IS THE FOURTH MODE FLIP OF 2026-09-21 -- TENET at 12:08,
      # EXECUTIVE at 12:34, TENET again now, after SEPTET/EXECUTIVE earlier -- AND THE FLIP RATE IS THE ARGUMENT, NOT
      # THE FLIPS. Two of the four left this table stale and turned make preflight RED FOR EVERY SEAT; two did not,
      # because the table moved in its own commit BEFORE the MODE file (CEO-1046, b36a7f709). That is a procedure
      # followed twice and forgotten twice IN ONE DAY, which is the measured failure rate of a guard made of a seat
      # remembering to do two edits in the right order. The coo's row -- the gate reads a COMMITTED declaration, so a
      # flip that forgets its table is caught AT THE FLIP by the flipper's own preflight instead of by whoever lands
      # next -- is ranked up on this evidence (CEO-1055). Written out per language rather than collapsed to a default
      # for the reason every table above gives: the gate beside this compares it to MODE line 2 LANGUAGE BY LANGUAGE.
      # ⛔ MODE CEO (CEO-1069, 2026-09-21 14:0x, Lon in-chat to the ceo, verbatim: "And now you are in CEO mode.
      # The fleet is going quiet now."): ONE SEAT HOLDS EVERY LANGUAGE. The six language HQs AND the three other
      # officers are stood down; rebus comes back to the ceo with the rest. Written out per language rather than
      # collapsed to a default for the reason every table above gives: the gate beside this compares it to MODE
      # line 2 LANGUAGE BY LANGUAGE, and a default would agree with a line 2 that had drifted on six of them.
      # ⛔ THIS TABLE MOVED BEFORE THE MODE FILE, through ../harness/scripts/ceo_mode_flip.sh --preview, which is the
      # mechanism landed at c641a38f one hour earlier after the table-before-the-file procedure was FOLLOWED TWICE
      # AND FORGOTTEN TWICE in a single day. This is its first real use.
      # ⛔ MODE DUO-STUPID (CEO-1087, 2026-09-21 15:5x, Lon in-chat to the ceo, verbatim: "Let's get double stupid
      # going, so go to DUO-STUPID mode, i.e. CEO and CTO."): TWO WORKING SEATS, the ceo and the cto. The split is
      # BY THE WORK IN FRONT OF BOTH SEATS -- the C->BB->C->BB eradication of CEO-1086 -- and the language cells are
      # assigned so that each seat owns the languages whose runtime carries its half of that population: the ceo
      # holds SNOBOL4 and SNOCONE because rt_call_proc_descr and core.c's APPLY road are the ceo's half (1044 of the
      # 1062 live transitions measured on the SnoRungs pass at f177904f6), plus ICON and REBUS; the cto holds PROLOG,
      # RAKU and PASCAL and the by_name_dispatch.c / runtime_eval.c / rt_call_named_proc / rt_proc_call_gen_h half.
      # ⛔ THE NAME IS LON'S AND IT IS SPELLED OUT IN EVERY GUARD RATHER THAN ALIASED TO DUO: an alias would make
      # two modes share one reason, and a mode name that no `case` arm lists is admitted by FALLING OUT, which
      # returns success (CEO-755b). Written out per language rather than collapsed to a default for the reason every
      # table above gives: the gate beside this compares it to MODE line 2 LANGUAGE BY LANGUAGE.
      # ⛔ MODE QUARTET (CEO-1089, 2026-09-21 16:1x, Lon in-chat to the ceo, verbatim: "Let's get four times the
      # stupid going. Go to QUARTET mode, CEO, CTO, CFO, and COO. Have COO do the before and after -O0 old versus new
      # GC and -O2 speed test for all languages."): FOUR WORKING SEATS, the four officers, the six language HQs stood
      # down. ⛔ THE coo OWNS NO LANGUAGE CELL AND THAT IS THE RULE, NOT AN OVERSIGHT (CEO-723, Lon 2026-09-13:
      # "It is not possible for COO to do two jobs. He failed at Pascal."): the coo holds THE MEASURE -- the before/after
      # speed and collector study Lon just ordered, across all seven languages -- and a seat holding the measure holds no
      # cure lane, so pascal moves to the cto rather than to the coo. The cfo takes ICON because its live rank-0 row is
      # the icon builtin root class, and keeps REBUS as keep-green. The ceo keeps SNOBOL4 and SNOCONE, where its half of
      # the C->BB population lives. Written out per language rather than collapsed to a default for the reason every
      # table above gives: the gate beside this compares it to MODE line 2 LANGUAGE BY LANGUAGE.
      # ⛔ MODE DUO (CEO-1108, 2026-09-22, Lon in-chat to the ceo, verbatim: "Go to DUO mode. CEO and CTO as Opus 5
      # effort max."): TWO WORKING SEATS, the ceo and the cto; the cfo and the coo stay stood down and no HQ stands.
      # ⛔ THE SPLIT IS BY LAYER, NOT BY SITE COUNT, and the language cells follow the layer rather than driving it
      # (the ceo's recommendation Lon acted on): the cto takes THE ENFORCEMENT HALF -- the per-safe-point slot-kind
      # table, the planner giving every call result live across a poll a mapped slot, and the emitter REFUSING a safe
      # point that stores outside the map (their four already-claimed rows, of which
      # gc-frame-maps-are-keyed-by-graph-not-by-safe-point-44-polls-2-maps is the keystone) -- while the ceo takes THE
      # SITE CONVERSIONS behind that refusal. ⛔ THE REASON THE ENFORCEMENT COMES FIRST IS MEASURED, NOT ARGUED
      # (CEO-1107): with maps keyed by GRAPH and not by SAFE POINT, "what is live at this poll" is not a question the
      # compiler can answer, so every one of the 120 open sites is a hand liveness judgment audited after the fact by
      # a five-minute rungs run -- 77 insertions by callee return class broke three languages in m3, and the 26 that
      # survived all eight smokes still cost 57 Icon programs against a clean-tree control arm.
      # ⛔ THE LANGUAGE CELLS ARE THE DUO-STUPID SPLIT OF CEO-1087 UNCHANGED, deliberately: the work is layer-split, so
      # re-cutting the language cells would be churn that costs both seats their bearings for no measured reason. The
      # ceo keeps ICON because it is the sharpest detector in the tree (826/826 clean, and it is what caught the 57)
      # and the conversions are the ceo's half; SNOBOL4 and SNOCONE stay with the ceo where its half of the C->BB
      # population lives; REBUS stays the ceo's keep-green with the cfo stood down. The cto holds PROLOG, RAKU and
      # PASCAL. ⛔ A SHARED-NODE LANDING STILL TRAVELS WITH ITS CONTROL ARM whoever lands it (CEO-801/757): the lane
      # names the default picker and the reviewer-after-the-fact, never who may land.
      # ⛔ AND THE TWO SEATS DO NOT RUN RUNG_SUITES AT THE SAME TIME ON THIS BOX: a board taken while the other seat is
      # building or grading is void (the cfo's flakiness finding plus CEO-1107's own rebuild-under-a-board), which is
      # the second reason the layer split is the right one -- the cto's half is compile-and-gate work and needs almost
      # no rungs passes, and the ceo's half is what needs them.
       # ⛔ MODE CEO (CEO-1247, 2026-09-24 18:4x CDT, Lon in-chat to the ceo, verbatim: "The fleet is in CEO only mode." and "You, CEO, are
       # seated as Fable 5.1 with max effort."): ONE SEAT HOLDS EVERY LANGUAGE for the SNOBOL4 speed campaign (CEO-1246). Written out per
       # language, never collapsed to a default, for the reason every table above gives: the gate beside this compares it to MODE line 2
       # LANGUAGE BY LANGUAGE. The DECTET mapping it replaces (icon=hq_icon prolog=hq_prolog snobol4=hq_snobol4 pascal=hq_pascal
       # snocone=hq_snocone raku=hq_raku rebus=ceo, the last since CEO-1178) is the flip-back template; this table moves BEFORE the MODE
       # file (CEO-1051's order: a flip that forgets its table reds make preflight for every seat).
       # ⛔ MODE TENET (CEO-1266, 2026-09-25, minutes after NONET, Lon in-chat to the ceo: "I also included HQ-RAKU. So go to TENET mode, 4 officers + 6 HQ's."): every
       # language goes to its own HQ and RAKU returns to hq_raku; REBUS stays the ceo's keep-green. The NONET block below is the record of the half hour between.
       # ⛔ MODE NONET (CEO-1266, 2026-09-25, Lon in-chat to the ceo: "Go now to NONET mode."; the five HQs by his answer "SNO, PL, PAS, SNOCONE, and ICON"): the four
       # officers and five language HQs; the two languages with no HQ go to an officer -- RAKU to the cto (its reviewer under DECTET, and its seat under QUARTET), REBUS to
       # the ceo (its keep-green seat since CEO-1178). The CEO table above is the flip-back template. Written out per language, never collapsed to a default, for the
       # reason every table above gives: the gate beside this compares it to MODE line 2 LANGUAGE BY LANGUAGE.
       # ⛔ MODE CEO (CEO-1275, 2026-09-26 08:5x, Lon in-chat to the ceo, verbatim: "Just so you are clear, we are in CEO mode only. The fleet is quiet."): ONE SEAT HOLDS EVERY
       # LANGUAGE for the benchmark order of work (every language's kernels and demos against its oracle at -O0 into the README, SNOBOL4 first). The TENET mapping this replaces --
       # icon hq_icon, prolog hq_prolog, snobol4 hq_snobol4, pascal hq_pascal, snocone hq_snocone, rebus ceo, raku hq_raku -- is kept here so the flip back is a seven-line edit.
       # Written out per language rather than collapsed to a default for the reason every table above gives: the gate beside this compares it to MODE line 2 LANGUAGE BY LANGUAGE.
       # ⭐ MODE TENET AGAIN (CEO-1285, 2026-09-26 13:5x, Lon in-chat to the ceo, verbatim: "Switch to TENET mode."): the seven-line edit the CEO block above promised -- every
       # language HQ takes its language back, rebus stays the ceo's (Lon: "There is no HQ-REBUS.").
       # ⛔⭐ MODE QUINTET (CEO-1356, 2026-09-28 17:2x, Lon in-chat to the ceo: "Bring the fleet into QUARTET mode: CEO, CTO, CFO, and COO. Leave HQ-SNOCONE alone. So QUNTET mode."): SNOCONE
       # stays hq_snocone's; the other languages take the QUARTET map of CEO-1123 -- ICON, SNOBOL4 and REBUS to the ceo, PROLOG, RAKU and PASCAL to the cto. The TENET mapping
       # this replaces -- icon hq_icon, prolog hq_prolog, snobol4 hq_snobol4, pascal hq_pascal, snocone hq_snocone, rebus ceo, raku hq_raku -- is the flip-back template.
       # ⛔⭐ MODE CEO (CEO-1357, 2026-09-28 18:1x, Lon in-chat to the ceo, verbatim: "Go to CEO mode. For go all work but what we focus on together here. I want to focus on the 6 Snocone parsers (excluding Raku)."): ONE SEAT
       # HOLDS EVERY LANGUAGE, and the one thing it works is the six self-hosted Snocone parsers with Lon. The QUINTET mapping this replaces -- icon ceo, prolog cto, snobol4 ceo, pascal cto,
       # snocone hq_snocone, rebus ceo, raku cto -- is the flip-back template, and the TENET mapping stays in the QUINTET comment above.
       # ⛔⭐ MODE DUO (CEO-1362, 2026-09-29 16:3x, Lon in-chat to the ceo: "Would it help to get CTO involved and to go to DUO mode? We have the bandwidth and the usage credits." then "Let me know
       # when CTO can start. He is seated as Opus 5.5 with max effort."): TWO WORKING SEATS, split by layer -- the cto bakes every call and deferred-pattern address (no by-name lookup at run
       # time, compile-time site tables, patch on a second DEFINE or assignment; its row is assigned, not picked), the ceo keeps the six parsers, the runtime diagnostics switch and the boards.
       # Every language stays the ceo's, so this table is the MODE CEO table unchanged; the DUO guard arms above already admit the cto.
       # ⛔⭐ MODE QUARTET (CEO-1364, 2026-09-29 18:3x, Lon in-chat to the ceo: "WIll we not benefit from having CFO and COO at work?" then "The goal is parser.sc same as C and 2x faster than SPITBOL."): the four officers,
       # split by layer as DUO was -- the cto bakes the calls, the coo is the testing officer again (LANES: names the coo), the cfo takes the collector and allocation under the parsers, the ceo keeps the
       # parsers and the stored-pattern thunks. Rows are assigned, not picked by language, so this table stays the MODE CEO table unchanged; the QUARTET guard arms above already admit cto, cfo and coo.
      # ⛔ MODE TENET (CEO-1383, 2026-10-01 09:0x CDT, Lon in-chat to the ceo, verbatim: "Let's get all test suites for all
      # languages to 100%. Go to TENET mode, 4 officers, and 7 HQ's."): every language goes back to its own HQ, the eleventh seat
      # hq_templates owns no language, rebus stays the ceo's keep-green as under the 2026-09-25 TENET (CEO-1266). Written out per
      # language, never collapsed to a default, for the reason every table above gives: the gate beside this compares it to MODE
      # line 2 LANGUAGE BY LANGUAGE. THIS TABLE IS MOVED AND COMMITTED BEFORE THE MODE FILE (CEO-1046/1051).
      # ⛔ MODE CEO (SOLO) (CEO-1396, 2026-10-02 09:1x CDT, Lon in-chat to the ceo, verbatim: "The fleet is idle. Go to CEO solo
      # mode."): one working seat, the ceo, every language the ceo's; the officers and the seven HQs stood down with their claims
      # parked in place (no re-lane, the CEO-1357/1372 precedent). The TENET table above is the flip-back template. THIS TABLE IS
      # MOVED AND COMMITTED BEFORE THE MODE FILE (CEO-1046/1051).
      # ⛔ MODE TENET (CEO-1435) was a misreading, reverted to SEXTET the same sitting (CEO-1436, Lon: "Only HQ-ICON and HQ-SNOBOL4 and 4 officers are running.").
      # ⛔⭐ MODE SEXTET (CEO-1433, 2026-10-02 19:2x, Lon in-chat to the ceo: "I'll fire up HQ-ICON and HQ-SNOBOL4 to help."): ICON to hq_icon, SNOBOL4 to hq_snobol4, the other five to the ceo; rows with an owner cell keep their owner.
      # ⛔⭐ MODE TENET (CEO-1530, 2026-10-07 08:5x CDT, Lon in-chat to the ceo, verbatim: "Go to TENET mode with 4 officers and 7 HQ's."): the CEO-1383 TENET
      # table again -- every language to its own HQ, hq_templates owning none, rebus the ceo's keep-green. MOVED AND COMMITTED BEFORE THE MODE FILE (CEO-1046/1051).
      # ⛔⭐ MODE QUARTET (CEO-1587, 2026-10-09 18:2x CDT, Lon in-chat to the ceo, verbatim: "Bring the fleet to QUARTET mode, only four officers."): the ten HQs stand
      # down (Lon had brought them idle at 17:4x); EVERY LANGUAGE TO THE ceo, who assigns, as the QUARTET of CEO-1521 (2026-10-05) and the DUO before it kept it; no
      # re-lane (the CEO-1357/1372/1396 precedent: HQ rows and claims wait in place for the HQs' return). The TENET table above is the flip-back template:
      # icon hq_icon, prolog hq_prolog, snobol4 hq_snobol4, pascal hq_pascal, snocone hq_snocone, rebus ceo, raku hq_raku. MOVED AND COMMITTED BEFORE THE MODE FILE.
      # ⛔⭐ MODE SEXTET (CEO-1591, 2026-10-10 09:0x CDT, Lon in-chat to the ceo, verbatim: "Let's continue getting Prolog and Raku at 100% like SNOBOL4 and Icon." then
      # "Let's also have HQ-PROLOG and HQ-RAKU join us."): PROLOG to hq_prolog, RAKU to hq_raku, the other five to the ceo, who assigns; rows with an owner cell keep their
      # owner. The QUARTET table above is the flip-back template. MOVED AND COMMITTED BEFORE THE MODE FILE (CEO-1046/1051).
      # ⛔⭐ MODE QUARTET (CEO-1659, 2026-10-11 09:3x CDT, Lon in-chat to the ceo, verbatim: "Go to QUARTET mode with all four officers being seated as Opus 5.5 with
      # xhigh effort."): the SEPTET of CEO-1595 ends -- hq_prolog, hq_raku and hq_pascal stand down with their claims and rows in place, nothing re-laned (the
      # CEO-1357/1372/1396/1587 precedent); EVERY LANGUAGE TO THE ceo, who assigns, the table of CEO-1587. The SEXTET table above is the flip-back template:
      # prolog hq_prolog, raku hq_raku, the other five the ceo. MOVED AND COMMITTED BEFORE THE MODE FILE (CEO-1046/1051).
      # ⛔⭐ MODE SEPTET (CEO-1662, 2026-10-11 10:3x CDT, Lon in-chat to the ceo, verbatim: "I suppose we should start HQ-SNOBOL4, HQ-ICON, and HQ-PROLOG to help."):
      # ICON to hq_icon, SNOBOL4 to hq_snobol4, PROLOG to hq_prolog, the other four to the ceo, who assigns; rows with an owner cell keep their owner. The QUARTET
      # table of CEO-1659 is the flip-back template (every language the ceo). MOVED AND COMMITTED BEFORE THE MODE FILE (CEO-1046/1051).
      # ⛔⭐ MODE TENET (CEO-1665, 2026-10-11 11:3x CDT, Lon in-chat to the ceo, verbatim: "I suppose we can get the remaining 7 HQ's up and running all seated as Sonnet 5.5
      # with xhigh effort. Lift the ban on Pascal and Raku."): the four officers and all ten HQs; the CEO-1383/1530 TENET table again -- every language to its own HQ, rebus
      # the ceo's keep-green. The SEPTET table of CEO-1662 is the flip-back template. MOVED AND COMMITTED BEFORE THE MODE FILE (CEO-1046/1051).
      # ⛔⭐ MODE QUARTET (CEO-1773, 2026-10-15 10:2x CDT, Lon in-chat to the ceo, verbatim: "The fleet has yet to start. We'll start officers only for a while."): the
      # TENET of CEO-1665 ends before the fleet starts -- the ten HQs stay down with their claims and rows in place, nothing re-laned (the CEO-1357/1372/1396/1587/1659
      # precedent); EVERY LANGUAGE TO THE ceo, who assigns, the table of CEO-1659; CEO-1765's focus (ORDER-OF-WORK icon prolog snobol4) stands. The TENET table of
      # CEO-1665 is the flip-back template: every language to its own HQ, rebus the ceo's. MOVED AND COMMITTED BEFORE THE MODE FILE (CEO-1046/1051).
      # ⛔⭐ MODE SEPTET (CEO-1777, 2026-10-15 10:5x CDT, Lon in-chat to the ceo, verbatim: "Would we benefit from having HQ-SNOBOL4, HQ-ICON, and HQ-PROLOG join us? I'd
      # start them as Sonnet 5.5 xhigh." then "We can have HQ-ICON work calgrind and optimize based on instruction count."): the SEPTET of CEO-1662 again -- the four
      # officers, hq_snobol4, hq_icon and hq_prolog; ICON to hq_icon, SNOBOL4 to hq_snobol4, PROLOG to hq_prolog, the other four to the ceo, who assigns; rows with an
      # owner cell keep their owner. The QUARTET table of CEO-1773 is the flip-back template (every language the ceo). MOVED AND COMMITTED BEFORE THE MODE FILE.
      # ⛔ MODE QUARTET AGAIN (CEO-1809, 2026-10-15 18:5x CDT, Lon in-chat to the ceo, verbatim: "Let bring the fleet to idle and go to QUARTET mode."): the four officers
      # only; every language to the ceo, who assigns, as CEO-1773's table; the SEPTET/OCTET/NONET table above is the flip-back template. MOVED AND COMMITTED BEFORE THE MODE FILE.
      # ⛔⭐ MODE NONET AGAIN (CEO-1813, 2026-10-17 14:3x CDT, Lon in-chat to the ceo, verbatim: "We should get HQ-SNOBOL4, HQ-ICON, HQ-PROLOG, and HQ=ZETAS also working in
      # the fleet."): QUINTET's five plus those four -- CEO-1793's NONET roster, whose guard arm already admits exactly hq_snobol4 hq_icon hq_prolog hq_zetas hq_runtime.
      # ICON to hq_icon, SNOBOL4 to hq_snobol4, PROLOG to hq_prolog, the other four to the ceo, who assigns; hq_zetas and hq_runtime own no language. The QUINTET table
      # (every language the ceo) is the flip-back template. MOVED AND COMMITTED BEFORE THE MODE FILE.
      # ⛔ MODE QUARTET (CEO-1852, 2026-10-21 09:1x CDT, Lon in-chat to the ceo, verbatim: "Go to QUARTET mode, four officers seated as Opus 5.5 xhigh."): hq_icon and hq_prolog
      # stand down with the rest of the reduced fleet, so ICON and PROLOG route to the ceo, who assigns, as CEO-1773's table; the two lines below this comment were hq_icon and hq_prolog
      # under CEO-1827 and are the flip-back template. MOVED AND COMMITTED BEFORE THE MODE FILE.
       icon)     printf 'ceo';;
       prolog)   printf 'ceo';;
      # ⛔ REDUCED FLEET FOR THE SPINE CONVERSION (CEO-1827, 2026-10-18, Lon in-chat to the ceo: "we should run a reduced fleet until things settle"; roster ceo coo hq_icon hq_prolog hq_zetas hq_dotnet hq_jvm): hq_snobol4 stands down, so SNOBOL4 routes to the ceo, who assigns; hq_zetas is its hands for spine fallout meanwhile. The table moves BEFORE the MODE file (CEO-1046).
       snobol4)  printf 'ceo';;
       pascal)   printf 'ceo';;
       snocone)  printf 'ceo';;
       rebus)    printf 'ceo';;
       raku)     printf 'ceo';;
    esac
}
# One line of prose for the `mint` refusal, DERIVED so it cannot drift from the arms above.
# ⭐ A SEAT THAT OWNS NO LANGUAGE CURES NOTHING IN A LANGUAGE LANE (CEO-779; Lon 2026-09-16 11:22 CDT, verbatim to the ceo:
# "Get the COO helping. The language seats now run their own tests and benchmarks."; CEO-781). Under DECTET the coo, the
# ceo and the cto own no language in the LANES table, so the any-lane fallback -- the ordinary path AND the dependency-
# inversion promotion -- must REFUSE them another owner's row instead of claiming it. MEASURED 2026-09-16 11:00 CDT:
# `next` on coo CLAIMED the cfo's icon-gc-rung-2 row by promotion (released within the minute, unworked); CEO-771: `next`
# on ceo LOCKED a Raku cure row. rc 0 = $ME owns a language in the table (an HQ, or the cfo for rebus); rc 1 = owns none.
# The test is on the seat's RESOLVED lane (s4e_my_lane: an HQ is itself, a numbered seat is whoever its HQ file names,
# an officer is itself, the ceo is empty and falls back to its identity) -- a seat07 whose HQ file reads hq_icon owns
# icon THROUGH its HQ and keeps today's cross-lane fallback; the coo, cto and ceo resolve to themselves and own none.
# An HQ-shaped lane (hq_*) owns the language of its name by definition, table or no table (a legacy hq_C seat under
# FLEET-16 keeps the fallback; test_gate_s4e_next_serves_own_lane arm (c)); the rule bites the OFFICERS the table
# names for nothing: ceo, coo, cto today, and the cfo the day rebus leaves its cell.
s4e_seat_owns_a_language() { local _l _who; _who="$(s4e_my_lane 2>/dev/null)"; [ -n "$_who" ] || _who="$ME"; case "$_who" in hq_*) return 0;; esac; for _l in $(s4e_lane_languages); do [ "$(s4e_lane_owner_of_language "$_l")" = "$_who" ] && return 0; done; return 1; }
# ⛔ THE ANY-LANE FALLBACK CLOSES UNDER TENET FOR EVERY SEAT, ORDINARY AND PROMOTION PATHS ALIKE (ceo CEO-1302 (b), 2026-09-27): an HQ
# runs only its own language (CEO-1232) and holds one row, so a language seat whose lane has nothing servable is told so (rc 2), never
# handed another HQ's row; the census at the ruling found zero live rows owned `unassigned`, so the close strands nothing. MODE line 1.
s4e_any_lane_closed() { case "$(head -1 "$PO/MODE" 2>/dev/null | tr -d '[:space:]')" in TENET|QUINTET) return 0;; esac; return 1; }
s4e_lane_help() { local _l _o _out=""; for _l in $(s4e_lane_languages); do _o="$(s4e_lane_owner_of_language "$_l")"; _out="$_out$_l -> $_o · "; done; printf '%s' "${_out% · }"; }
s4e_topic_lane() {
    local _t="$1" _owner _lang
    _owner="$(qrow "$_t" | cut -f3)"
    # ⛔ THE EXECUTIVES BELONG IN THIS SHORT-CIRCUIT AND WERE MISSING (hq_B 2026-09-13, found while verifying
    # CEO-672). It accepted only hq_* names, so a row whose owner cell EXPLICITLY said ceo/cto/coo/cfo fell
    # through and was re-guessed from its prefix. Under NONET four of the seven completeness owners ARE
    # executives, so "an explicit, already-made decision beats a guess" was switched off for exactly the seats
    # the fallback most often names — and the failure is invisible because a guess still returns something.
    case "$_owner" in ceo|cto|coo|cfo|hq_icon|hq_prolog|hq_raku|hq_pascal|hq_snocone|hq_snobol4|hq_templates|hq_runtime|hq_collector|hq_zetas|hq_dotnet|hq_jvm|hq_C|hq_B|hq_P|hq_T|hq_U|hq_S|hq_I|hq_R|hq_V) printf '%s' "$_owner"; return 0;; esac
    _lang="${_t%%-*}"
    case " $(s4e_lane_languages) " in *" $_lang "*) s4e_lane_owner_of_language "$_lang";; esac
}
# Identity lane: ceo is never restricted — checked by the CALLER against the identity SHAPE, the same
# precedent the MODE guard above already set (⛔ NOT s4e_is_hq(), which counts ceo as an HQ and would
# wrongly lane-restrict the one identity THE LANES table does not partition). An HQ's lane is itself. A
# seat's lane is read from ITS OWN postoffice HQ file — the same file `ask`'s routing already treats as
# authoritative — not a second hardcoded seat-number table that can drift from MASTER-PLAN while nobody
# is watching, the way seat07's own HQ file (checked 2026-09-04) still read hq_C after the 16-seat cut
# moved it to hq_T. An unreadable or unrecognized HQ file returns empty: UNDETERMINED, never restricted,
# so a stale or missing HQ file degrades to today's lane-blind behaviour rather than locking a seat out
# of every row in the queue.
s4e_my_lane() {
    case "$ME" in
      hq_icon|hq_prolog|hq_raku|hq_pascal|hq_snocone|hq_snobol4|hq_templates|hq_runtime|hq_collector|hq_zetas|hq_dotnet|hq_jvm|hq_C|hq_B|hq_P|hq_T|hq_U|hq_S|hq_I|hq_R|hq_V) printf '%s' "$ME"; return 0;;
      # ⭐⭐ AN EXECUTIVE'S LANE IS ITSELF, ON THE SAME LAW AS AN HQ's (ceo CEO-748, under MODE EXECUTIVE).
      # ⛔ THIS IS NOT A NEW RULE, IT IS THE OLD RULE REACHING THE SEATS THAT NOW HOLD THE LANES: the table
      # above gives all seven languages to ceo/cto/cfo, so under EXECUTIVE the set of lane-determinable
      # seats was EMPTY and the own-lane pass could never run for anybody. test_gate_next_honours_the_lane_cut
      # measured it the minute the mode flipped and REFUSED rc=2 rather than passing vacuously -- the gate's
      # own note (line 51) had already named `s4e_my_lane` as the real defect and it came true unchanged.
      # ⛔ THE ceo IS DELIBERATELY ABSENT and stays absent: the comment above this function is law -- the ceo
      # is never lane-restricted, and the own-lane pass would restrict it. coo/cto/cfo degrade safely because
      # the own-lane pass tries the WHOLE rank-sorted queue and then falls through to the any-lane pass, so a
      # seat whose lane is empty (the coo, which holds no cure lane at all) wanders rather than starves.
      cto|cfo|coo) printf '%s' "$ME"; return 0;;
      seat*) local _f="$PO/$ME/HQ" _l
             [ -f "$_f" ] || return 0
             _l="$(head -1 "$_f" | tr -d '[:space:]')"
             # ⭐ A SEAT WHOSE HQ FILE NAMES AN EXECUTIVE HAS THAT EXECUTIVE'S LANE (ceo CEO-748). The law
             # above restricts the ceo IDENTITY, never a seat reporting to it, and under EXECUTIVE every
             # language lane is held by an officer -- so refusing to read an officer's name here would have
             # left every numbered seat lane-blind for the same reason the executives themselves were.
             case "$_l" in hq_icon|hq_prolog|hq_raku|hq_pascal|hq_snocone|hq_snobol4|hq_templates|hq_runtime|hq_collector|hq_zetas|hq_dotnet|hq_jvm|hq_C|hq_B|hq_P|hq_T|hq_U|hq_S|hq_I|hq_R|hq_V|ceo|cto|cfo|coo) printf '%s' "$_l";; esac ;;
    esac
}
# ⭐⭐ THE ORDER OF WORK -- THE SET OF LIVE LANGUAGES, READ FROM A MACHINE LINE (row `snobol4-icon-postoffice-
# next-refuses-a-row-of-a-language-parked-by-the-order-of-work-on-mode-line-2`, CEO-489; hq_P found it by
# being served a rank-0 SNOBOL4 row under MODE NONET while THE ORDER OF WORK IS ICON ONLY stood on line 2).
# ⛔ WHY THE PROSE PARSE WAS THE DEFECT, not merely an incomplete one: it matched the single spelling
# `ON <LANG> ONLY`, and the ceo wrote the live freeze as `THE ORDER OF WORK IS ICON ONLY` -- an `IS`, not an
# `ON`. The extractor returned EMPTY, empty is documented here as NO FREEZE (never "undetermined"), and so
# every parked-language row in the queue became servable, silently, with no refusal to read. ⭐ THE SHAPE IS
# THIS PROJECT'S OWN RECURRING ONE, twice over: an instrument answering a NARROWER question than the one it
# was read as answering (the `command -v` oracle probe, the `ls` on a subdirectoried corpus), AND a law that
# depended on a seat remembering a default (the banner, the inbox check) -- both cured the same way, by
# moving the law into the harness. ⛔ AND THE GATE COULD NOT HAVE CAUGHT IT: the fixture in
# test_gate_next_honours_the_lane_cut.sh writes `ON SNOBOL4 ONLY`, the one spelling the parser knew, so the
# gate and the code under test shared the assumption. A guard and its own canary must not share a failure
# mode -- the identical lesson the argnote sweep's stale prune already taught this project.
# ✅ THE CURE: the order of work is DECLARED, in a line the bus reads, never inferred from prose. Spelling,
# ceo custody, fixed here so the ceo can write it (the row's GOAL: "the ceo writes the MODE line the moment
# the gate defines its spelling"):
#     ORDER-OF-WORK: icon
# -- a line whose FIRST characters are `ORDER-OF-WORK:`, holding the whitespace/comma-separated list of
# language tokens that are LIVE; everything else is PARKED. ⭐ MATCHED BY MARKER, NEVER BY LINE NUMBER: the
# ceo PREPENDS each new dated entry, so a positional line 3 would be shoved to 4 by the next announcement
# and start answering for a superseded order of work -- the same position-splice defect that makes
# util_apply_score_grid.py refuse. The FIRST marker line wins, which under prepend-newest is the newest.
# `ORDER-OF-WORK: all` (any case) means NO restriction, and so does an absent marker: absence falls back to
# the prose parse below rather than silently opening the queue, so this cure never reads as a loosening.
# ⭐ THE PROSE FALLBACK IS KEPT AND WIDENED TO THE `IS` FORM, deliberately: until the ceo writes the marker
# line, the fallback is the only thing standing between an idle seat and a parked language, and today's live
# MODE is exactly the `IS` spelling. It stays a FALLBACK -- the marker line, when present, is the authority.
# Returns a space-separated lowercase list, or empty for NO RESTRICTION (empty is never "undetermined").
s4e_mode_live_languages() {
    local _m
    _m="$(grep -m1 -E '^ORDER-OF-WORK:' "$PO/MODE" 2>/dev/null | sed 's/^ORDER-OF-WORK://' | tr ',' ' ' | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ' | sed 's/^ *//; s/ *$//')"
    if [ -n "$_m" ]; then
        [ "$_m" = "all" ] && return 0
        printf '%s' "$_m"; return 0
    fi
    sed -n 2p "$PO/MODE" 2>/dev/null | grep -oE '(ON|IS) [A-Z][A-Z0-9]* ONLY' | head -1 | awk '{print $2}' | tr '[:upper:]' '[:lower:]'
}
# Companion to s4e_topic_lane, same prefix table, different axis: LANGUAGE, not HQ. gimpel-*/snoflake-*
# are SNOBOL4-suite families with no snobol4- prefix of their own (this session's own aisnobol/snoflake
# census rows) -- named explicitly rather than left to fall through, the same reason s4e_topic_lane names
# every prefix instead of defaulting one. A topic naming no language (tooling/meta, like this row itself)
# returns empty: LANGUAGE-NEUTRAL, never frozen out, the same "empty is never a fifth category" rule
# s4e_topic_lane documents for lane.
# ⛔⭐⭐ THE SLUG IS NOT THE ONLY PLACE A ROW'S LANGUAGE LIVES, AND READING ONLY THE SLUG FAILS OPEN (hq_S
# 2026-09-10, found by being SERVED one: `s4e_msg.sh next` under MODE NONET with `THE ORDER OF WORK IS ICON
# ONLY` locked hq_S onto `input-open-failure-not-signaled`, whose GOAL reads "INPUT() ... the oracle (sbl -bf)
# ... Witness: simple_output_62 in corpus/tests/snobol4/ALL.sno". The freeze check RAN and let it through: the
# slug carries no `snobol4-` prefix, the prefix table returned empty, and empty is documented above as
# LANGUAGE-NEUTRAL -- never frozen out. So a PARKED-language row was handed to a seat by the very picker that
# prints ⛔ SKIP for its prefixed siblings four lines earlier, in the same run.
# ⭐ THIS IS CEO-489'S DEFECT ONE AXIS OVER, and that is the part worth carrying. That row cured an extractor
# that answered a NARROWER question than it was read as answering (it matched `ON <LANG> ONLY`, the ceo wrote
# `IS ICON ONLY`, and empty meant no freeze). This one is the same sentence about the other operand: the
# classifier answers "does this SLUG start with a language prefix?" and is read as "what language is this
# ROW?". Both fail OPEN -- they leak parked work rather than idling a seat -- which is why neither announces
# itself: a seat who is served a row does not go looking for the reason it was served.
# MEASURED on the live queue the day this landed: 452 servable rows (FREE or CLAIMED), 165 of them classified
# LANGUAGE-NEUTRAL by the prefix table alone; of those 165, 39 name exactly one language's own witness paths
# or oracle in their baton -- 28 snobol4, 5 prolog, 6 icon. Under ICON ONLY that is 33 rows of a parked
# language standing servable, of which the bus had already handed out the one in hand.
# ✅ THE CURE, in the order the project's own doctrine ranks evidence -- DECLARED beats INFERRED beats NOTHING:
#   1. the slug prefix table (unchanged, and still the authority when it answers);
#   2. a DECLARED `LANGUAGE: <lang>` marker line in the baton -- the same shape as the ORDER-OF-WORK: line
#      CEO-489 gave the MODE file, and for the same reason: a language that is written down cannot be
#      mis-parsed out of prose. Anyone minting or re-laning a row should write it;
#   3. only then INFERENCE, and only from WITNESS PATHS AND ORACLE BINARIES (`corpus/tests/<lang>/`,
#      `corpus/packages/<lang>/`, sbl/iconx/icont/swipl/gprolog) -- never from a bare file extension and never
#      from prose. ⛔ The extensions were tried first and dropped: `.pl` and a prose mention of SNOBOL4 convict
#      half the instrument rows, which would freeze language-NEUTRAL tooling under any lane cut. A witness path
#      answers the question that actually matters here -- whose suite does this row grade? -- rather than the
#      question of which words it happens to contain.
# ⛔ AMBIGUITY RETURNS EMPTY, DELIBERATELY. A baton naming two languages' witnesses stays NEUTRAL, i.e. it
# keeps TODAY'S behaviour exactly. So this cure can only ever tighten, never loosen: no row that the freeze
# already refused becomes servable by it. And a tooling row wrongly frozen costs one `claim`, which every
# refusal above already prints -- the cheap side of an asymmetry whose expensive side is breaking Lon's freeze.
# ⛔ THE MARKER LINE IS STRIPPED OF A TRAILING `#` COMMENT BEFORE IT IS MATCHED (hq_P 2026-09-10). Without it
# `LANGUAGE: neutral   # why` folds the WHOLE comment into the value and matches nothing -- the declaration
# reads as absent, silently, and the row falls back to inference: a marker that LOOKS authoritative in the file
# and is inert in the bus. Found by the harness arm for the declaration failing the moment it stopped being
# vacuous. Same treatment `s4e_strip_donewhen_comment` already gives a DONE-WHEN, for the same reason.
s4e_baton_declared_language() {
    local _t="${1:-}" _f _d
    [ -n "$_t" ] || return 0
    _f="$PO/tasks/$_t.task.md"; [ -f "$_f" ] || return 0
    _d="$(grep -m1 -E '^LANGUAGE:' "$_f" 2>/dev/null | sed 's/^LANGUAGE://; s/#.*$//' | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    case "$_d" in icon|prolog|snobol4|snocone|pascal|raku|rebus) printf '%s' "$_d";; esac
}
# ⭐ NEUTRALITY IS DECLARABLE TOO, AND FOR THE SAME REASON THE LANGUAGE IS (hq_P 2026-09-10, minted by the cost
# side of the fail-closed cure above). Inference convicts tooling rows on PLACEHOLDER filenames: the census
# turned up `legacy-dash-flags-dead-scripts` -- a sweep of harness/scripts/*.sh for a dead single-dash CLI
# convention, language-neutral beyond argument -- classified `snobol4 snocone` because its GOAL spells out
# example invocations containing `file.sno` and `file.sc`. ⛔ The wrong cure is to teach the matcher about
# `file.<ext>`: that is one witness wide, and the next placeholder is spelled `prog.sno`. ✅ The right one is
# the ladder this file already ranks -- DECLARED beats INFERRED -- extended to the answer inference cannot
# safely reach: a row may say `LANGUAGE: neutral` (or `none`) and be believed, exactly as it is believed when it
# names a language. A tooling row then costs ONE LINE in its baton, permanently, instead of one `claim` per
# freeze per seat forever. ⛔ It does NOT outrank a slug prefix, for the same reason a declared language does
# not: `snobol4-foo` declaring itself neutral is a contradiction, and the slug is the older assertion.
s4e_baton_declares_neutral() {
    local _t="${1:-}" _f _d
    [ -n "$_t" ] || return 1
    _f="$PO/tasks/$_t.task.md"; [ -f "$_f" ] || return 1
    _d="$(grep -m1 -E '^LANGUAGE:' "$_f" 2>/dev/null | sed 's/^LANGUAGE://; s/#.*$//' | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    case "$_d" in neutral|none) return 0;; *) return 1;; esac
}
# ⛔⭐⭐ AMBIGUITY RETURNS NEUTRAL, AND NEUTRAL IS NEVER FROZEN OUT -- SO A FALSE POSITIVE IN ANY ONE LANGUAGE'S
# MATCHER DOES NOT MIS-LANE A ROW, IT DISARMS THE FREEZE FOR THAT ROW (hq_P 2026-09-10, found the same way both
# earlier instances were -- BY BEING SERVED ONE. `next` under MODE NONET with THE ORDER OF WORK IS ICON ONLY
# printed sixteen ⛔ SKIP lines for snobol4 rows and then locked this seat onto `corpus-import-roast-subset`, a
# RAKU row: import the roast spec suite into corpus/packages/raku/roast/. The witness matcher answered BOTH
# raku (correct -- the DONE-WHEN cds to corpus/packages/raku/roast) AND snobol4 (WRONG), because the baton names
# the import convention it follows: "the packages/ import pattern beside gimpel/csnobol4_suite/ipl/jcon". The
# `csnobol4_suite` marker convicted a row that merely cites that directory AS A NAMING PRECEDENT. Two matches,
# so the set was ambiguous, so the classifier returned empty, so the freeze read the row as LANGUAGE-NEUTRAL and
# served it.
# ⭐ THE PRECEDING CURE DOCUMENTED ITSELF AS "can only ever tighten, never loosen", AND THAT CLAIM IS TRUE ONLY
# FOR ROWS THE FREEZE ALREADY REFUSED. It is false in the direction that matters: a row a CORRECT single-language
# classifier would have PARKED gets SERVED the moment a second matcher fires spuriously on it. Ambiguity is not a
# neutral outcome here -- it is an ACTIVE BYPASS, and it is reached by a false positive in ANY of seven regexes,
# i.e. the failure surface is the union of every marker set, not the intersection.
# ✅ THE CURE IS ON THE DECISION, NOT ON THE MARKERS. Chasing false positives out of seven marker sets is
# unbounded and each fix is one witness wide; instead the freeze now asks the question that is actually
# decidable: IS EVERY LANGUAGE THIS ROW COULD BE PARKED? If so, refuse -- it does not matter which candidate is
# the true one, because all of them are frozen. If any candidate is live, serve, which is exactly today's
# behaviour. So a false positive can no longer bypass the freeze; at worst it names an extra parked language in a
# refusal line. ⛔ This can only tighten -- and unlike the claim it replaces, that holds in BOTH directions: a row
# with a live candidate is served as before, and no row that is served today becomes refused unless every
# language it names is parked.
s4e_baton_witness_languages() {
    local _t="${1:-}" _f _out=""
    [ -n "$_t" ] || return 0
    _f="$PO/tasks/$_t.task.md"; [ -f "$_f" ] || return 0
    # ⛔⭐ A WITNESS IS A PATH, AND THE PATH IS OFTEN NOT UNDER corpus/tests/<lang>/ (widened hq_S 2026-09-10,
    # within ONE command of the first cure landing). The freeze refused `input-open-failure-not-signaled` by
    # name -- and the very next row `next` handed out was `conform-trim-tabs-not-stripped`, ALSO SNOBOL4: a
    # TRIM conformance row off the SPITBOL manual whose witness is `corpus/probe/conformance/f83_trim.sno`.
    # Its baton names no corpus/tests path, no oracle invocation, and no language word -- only a `.sno` file,
    # under a directory (`corpus/probe/`) that no longer even exists. A marker set built from the suite
    # directories alone has a RECALL hole exactly the width of every row minted before the corpus re-gridded.
    # ⭐ So the witness EXTENSION is matched too, but only in PATH SHAPE (`<something>/<name>.sno`, or a bare
    # `<name>.sno` token) -- never the bare word -- and the SPITBOL manual counts as a SNOBOL4 witness because
    # nothing else is graded against it. Ambiguity still returns empty, so widening recall cannot mis-park a
    # cross-language row; it can only move a row from "served" to "named and refused".
    # ⛔ PROLOG GETS NO EXTENSION CLAUSE, DELIBERATELY: its witnesses are `.pl`, which is also Perl's, and a
    # `.pl` token appears in tooling rows that have nothing to do with Prolog. Recall there stays on the
    # corpus paths and the two oracle binaries -- a known, named hole, kept open on purpose rather than
    # closed with a matcher that would convict the bus's own scripts.
    grep -qE 'corpus/(tests|packages)/icon/|icon-master/bin/|\b(iconx|icont)\b|jcon_tests|arizona_tests|[A-Za-z0-9_./-]+\.icn\b' "$_f" && _out="$_out icon"
    grep -qE 'corpus/(tests|packages)/snobol4/|csnobol4_suite|sbl -bf|x64/bin/sbl|spitbol-manual|[A-Za-z0-9_./-]+\.sno\b' "$_f" && _out="$_out snobol4"
    grep -qE 'corpus/(tests|packages)/prolog/|\b(swipl|gprolog)\b' "$_f" && _out="$_out prolog"
    grep -qE 'corpus/(tests|packages)/snocone/|[A-Za-z0-9_./-]+\.sc\b' "$_f" && _out="$_out snocone"
    grep -qE 'corpus/(tests|packages)/pascal/|[A-Za-z0-9_./-]+\.pas\b' "$_f" && _out="$_out pascal"
    grep -qE 'corpus/(tests|packages)/raku/|[A-Za-z0-9_./-]+\.raku\b' "$_f" && _out="$_out raku"
    grep -qE 'corpus/(tests|packages)/rebus/|[A-Za-z0-9_./-]+\.reb\b' "$_f" && _out="$_out rebus"
    printf '%s' "${_out# }"
}
# The single-language view, unchanged in behaviour and still what every DISPLAY caller wants: a set of one, or
# empty. The freeze no longer goes through here -- it reads the SET above, because "which one language is this?"
# is the question that has no answer for an ambiguous row, while "are all of them parked?" always does.
s4e_baton_witness_language() {
    local _out _n
    _out="$(s4e_baton_witness_languages "${1:-}")"; _n=$(printf '%s' "$_out" | wc -w)
    [ "$_n" -eq 1 ] || return 0
    printf '%s' "$_out"
}
s4e_topic_language() {
    local _s
    case "${1:-}" in
      icon-*)                        printf 'icon'; return 0;;
      prolog-*)                      printf 'prolog'; return 0;;
      snobol4-*|gimpel-*|snoflake-*) printf 'snobol4'; return 0;;
      snocone-*)                     printf 'snocone'; return 0;;
      pascal-*)                      printf 'pascal'; return 0;;
      raku-*)                        printf 'raku'; return 0;;
      rebus-*)                       printf 'rebus'; return 0;;
    esac
    s4e_baton_declares_neutral "${1:-}" && return 0
    _s="$(s4e_baton_declared_language "${1:-}")"; [ -z "$_s" ] || { printf '%s' "$_s"; return 0; }
    s4e_baton_witness_language "${1:-}"
}
# ⭐ THE SAME LADDER, BUT IT KEEPS THE WHOLE CANDIDATE SET instead of collapsing it: a slug prefix or a DECLARED
# marker still answers alone and outranks inference (both are assertions, not guesses, so neither can be
# ambiguous), and only the witness inference can return more than one. Empty still means NOTHING is known --
# genuinely language-neutral tooling -- and stays servable under any freeze.
s4e_topic_language_candidates() {
    local _s
    _s="$(s4e_topic_language "${1:-}")"; [ -z "$_s" ] || { printf '%s' "$_s"; return 0; }
    s4e_baton_declares_neutral "${1:-}" && return 0
    s4e_baton_witness_languages "${1:-}"
}
# For a refusal line: the one language, or every candidate joined by `|` so the reader sees WHY the row was
# refused without re-deriving it. ⛔ A refusal that named an ambiguous row's language printed EMPTY before this
# -- "this topic is  (PARKED)" -- which is the shape that hides the very defect this cure is about.
s4e_topic_language_display() {
    local _c
    _c="$(s4e_topic_language_candidates "${1:-}")"
    printf '%s' "$(printf '%s' "$_c" | tr ' ' '|')"
}
# rc 0 ("refuses") only when a freeze IS active, the topic's language IS determined, and they DIFFER --
# every other combination (no freeze, language-neutral topic, or topic matches the frozen language) is
# rc 1 ("does not refuse"). Deliberately UNCONDITIONAL, no own-lane/any-lane softening the way the lane
# cut has: Lon's freeze paused even standing HQ assignments fleet-wide (MODE 2026-09-04 17:38 CDT, "All
# HQ's and all Fleet workers are on SNOBOL4 only"), so an automatic pick honours it the same way
# regardless of an owner cell or a cross-lane fallback -- `claim <topic>` remains the deliberate override
# it already is everywhere else in this file, for the rare case a seat has an actual reason to work
# outside the freeze.
# ⭐ NOW A SET-MEMBERSHIP TEST, not an equality one: THE ORDER OF WORK names the languages that are LIVE
# (today one, `icon`; on 2026-09-08 it was two, "SNOBOL4 AND ICON TO 100%"), so a topic refuses when its
# language is DETERMINED and is NOT IN that set. ⛔ Equality was wrong the moment the order of work named a
# second language, and it would have failed CLOSED -- parking a live language -- which is the direction that
# idles seats rather than the one that leaks work; both are defects, and a set answers both.
# ⭐ NOW OVER THE CANDIDATE SET: refuse when the row's language is known to SOME extent and EVERY candidate is
# parked. One candidate is the old rule exactly. Several is the ambiguous case that used to bypass the freeze
# entirely, and it now refuses iff no candidate is live -- so a spurious extra match can widen the refusal's
# reason but can never turn a refusal into a pick. Zero candidates is language-neutral and never refuses.
s4e_language_freeze_refuses() {
    local _live _cand _c _l
    _live="$(s4e_mode_live_languages)"; [ -n "$_live" ] || return 1
    _cand="$(s4e_topic_language_candidates "${1:-}")"; [ -n "$_cand" ] || return 1
    for _c in $_cand; do for _l in $_live; do [ "$_l" = "$_c" ] && return 1; done; done
    return 0
}
# ⛔ DECORATED NO-OP EVASION, COMPANION FIX to `done`'s own no-op blocklist below (row
# `donewhen-decorated-noop-evasion`; the gate `test_gate_baton_donewhen_runnable.sh` carries the identical
# fix and the full rationale). Strips a trailing shell comment the way bash itself would -- quote-aware: a
# `#` starts a comment only when it is outside any quoting and at the start of a word -- WITHOUT ever
# executing its argument. Used so `done`'s blocklist judges `exit 0 # nothing to verify` by what it reduces
# to (`exit 0`), not by its undigested text.
# ⛔⭐ THE FIRST-WORD RULE IS SOURCED, NEVER RE-DERIVED (lib_donewhen.sh, hq_T 2026-09-11). Four copies of the
# old whitespace-splitting one-liner existed -- two in this file, two in the gate -- and hq_S measured it calling
# a CURED row PERMANENTLY UNCLOSEABLE because `D=$(mktemp -d)` splits into two fields. ⛔ IF THE LIB IS MISSING
# THE NO-OP PROBE IS SKIPPED AND SAYS SO: the bus must not die for a missing helper, and it must not quietly
# fall back to the defective line either -- that fallback is how four copies happened in the first place.
# ⛔⭐⭐ THIS SOURCE IS LOAD-BEARING AND IS NO LONGER OPTIONAL (cto's ruling, 2026-09-23). It used to WARN and
# continue, and that was right while the lib carried only the first-word rule and a no-op probe. It now also
# carries THE ONE DONE-WHEN EXTRACTOR that `claim` and `done` read every criterion through, so continuing
# without it would leave s4e_donewhen_text UNDEFINED and every criterion reading EMPTY -- which is the
# false-green direction, not the loud one. A missing lib is a REFUSAL, never an approximation.
if [ -r "$(dirname "${BASH_SOURCE[0]}")/lib_donewhen.sh" ]; then . "$(dirname "${BASH_SOURCE[0]}")/lib_donewhen.sh"
else printf '⛔ REFUSED (rc=2): %s/lib_donewhen.sh is not readable -- it holds the DONE-WHEN extractor and the\n   first-word rule, so this bus CANNOT MEASURE any criterion. Nothing was read and nothing was written.\n' "$(dirname "${BASH_SOURCE[0]}")" >&2; exit 2; fi
# ⛔ AND THE DEFINITIONS ARE ASSERTED, NOT ASSUMED: a lib that is readable but truncated or edited to drop a
# function would otherwise be indistinguishable from a good one until the first empty criterion.
for _dw_fn in s4e_field_criterion_text s4e_donewhen_text s4e_premise_text s4e_donewhen_incomplete donewhen_first_word; do
  command -v "$_dw_fn" >/dev/null 2>&1 || { printf '⛔ REFUSED (rc=2): lib_donewhen.sh sourced but %s is undefined -- the extractor is incomplete, so no criterion can be measured.\n' "$_dw_fn" >&2; exit 2; }
done; unset _dw_fn
s4e_strip_donewhen_comment() {
    awk '
    {
        line = $0; out = ""; state = 0; n = length(line); i = 1
        while (i <= n) {
            c = substr(line, i, 1)
            if (state == 1) {
                out = out c
                if (c == "\047") state = 0
                i++; continue
            }
            if (state == 2) {
                if (c == "\\" && i < n) { out = out c substr(line, i + 1, 1); i += 2; continue }
                out = out c
                if (c == "\"") state = 0
                i++; continue
            }
            if (c == "\\" && i < n) { out = out c substr(line, i + 1, 1); i += 2; continue }
            if (c == "\047") { state = 1; out = out c; i++; continue }
            if (c == "\"") { state = 2; out = out c; i++; continue }
            if (c == "#") {
                prev = (i == 1) ? " " : substr(line, i - 1, 1)
                if (prev == " " || prev == "\t") break
                out = out c; i++; continue
            }
            out = out c; i++
        }
        sub(/[ \t]+$/, "", out)
        print out
    }'
}
# ⛔⭐ RUN A ROW'S DONE-WHEN AT DISPATCH, BEFORE HANDING IT TO ANYONE (ceo ruling 2026-09-03 adopting seat09's
# suggestion; row next-and-assign-re-run-a-rows-done-when-before-serving-it). MEASURED by seat09
# (FINDING-2026-09-03-seat09-pascal-relop-array-field-row-was-already-cured-five-days-before-dispatch.md):
# pascal-relop-into-array-and-field-lvalues-loses-value sat FREE for FIVE DAYS describing a bug that a sibling
# row (pascal-restore-prezeta, ff1df778) had already cured, and its DONE-WHEN grepped an exact "N pass / 0 fail"
# string that corpus growth had made permanently unpassable. ⭐ THE DEFECT IS NOT THE DEAD ROW, IT IS THAT THE
# QUEUE HAD THE ANSWER THE WHOLE TIME AND NOBODY ASKED IT: the criterion that would have closed the row was
# sitting in the baton, one command away, through five days and every picker pass over it.
# THE THREE-WAY SPLIT (the ruling, verbatim in substance): green closes the row DONE with a ledger line
# "already satisfied at dispatch" and serves the next; a REFUSE (rc=2) or timeout serves the row WITH A WARNING;
# only RED serves it silently. ⛔ Red is the ONLY silent outcome, because red is the only one that means
# "there is real work here" -- the other two mean the queue does not know, and a picker that hides what it does
# not know is how a five-day-dead row reads as live work.
# ⛔⭐ THE TIMEOUT IS SHORT AND THAT IS THE POINT. `done`'s budget is 3600s because a close must be allowed to
# run `make test`; a DISPATCH probe must not stall the picker for twenty minutes to answer a question it asked
# on spec. A criterion too slow to probe is NOT a failure of the row -- it times out, which is rc=2, which
# serves the row with a warning. The safe direction is always SERVE.
s4e_dispatch_timeout() { printf '%s' "${S4E_DISPATCH_PROBE_TIMEOUT:-120}"; }
# ⛔ MIRRORS `done`'s vacuity blocklist and is NOT the authority for it -- `done` is (:898 and :916-922). Used
# only by `assign`, which cannot delegate to `done` (that verb requires the claim to be the RUNNER's, and assign
# writes ANOTHER seat's). `next` never calls this: it probes by invoking `done` itself, so its judgement is the
# real one by construction. ⛔ Two copies of one rule DO drift -- this file convicts that everywhere -- so the
# gate asserts the two agree over a table of criteria rather than trusting the comment.
s4e_donewhen_is_noop() {   # $1 = raw DONE-WHEN text; rc 0 = certifies nothing
    local dw="${1:-}" nc nrm first
    case "$(printf '%s' "$dw" | tr -d '[:space:]')" in true|:|exit0|/bin/true|/usr/bin/true|""|"#"*) return 0;; esac
    nc="$(printf '%s' "$dw" | s4e_strip_donewhen_comment)"
    nrm="$(printf '%s' "$nc" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+/ /g')"
    printf '%s' "$nrm" | grep -qE '[;|&`]|\$\(' && return 1
    case "$nrm" in ""|"exit 0"|exit0) return 0;; esac
    command -v donewhen_first_word >/dev/null 2>&1 || return 1
    first="$(donewhen_first_word "$nrm")"
    case "$first" in true|:|/bin/true|/usr/bin/true|echo) return 0;; esac
    return 1; }
# ⛔⭐ S4E-GUARD-COMPILER-ABSENT -- A CRITERION THAT DRIVES AN UNBUILT COMPILER CANNOT BE MEASURED, SO IT IS
# REFUSED (rc=2), NEVER GRADED RED (rc=1). hq_P -> hq_B 2026-09-04, measured on pascal-m4-site1-forloop-backedge-
# 64byte-excess: ~88 batons carry seat05's 09-01 template whose compile step reads
#     timeout -k 5 300s SCRIP/scrip --compile ... || { echo "... compile failed"; exit 1; }
# so a MISSING or not-yet-built ./scrip reports rc=1 -- "there is real work here", which the dispatch probe serves
# SILENTLY -- instead of rc=2 -- "I could not measure", which it serves WITH a warning. The ceo root's binary was
# timestamped 21 minutes AFTER the assign that read that row red. ⭐ THE CURE IS ONE GUARD AT THE TWO RUNNER SITES,
# NOT A SWEEP OF 88 BATONS: a criterion is TEXT, and the property "this text drives the compiler" is readable from
# the text. Sweeping the batons would fix the ones that exist today and none of the ones written tomorrow.
# Returns 0 (and sets $_gca_why) when the criterion names the compiler AND that binary is absent.
s4e_donewhen_needs_compiler() {   # $1 = raw DONE-WHEN text
    local dw="${1:-}" b; _gca_why=""
    printf '%s' "$dw" | grep -qE '(^|[^A-Za-z0-9_./-])(\./)?(SCRIP/)?scrip([[:space:]]|$)' || return 1
    b="$S4E/SCRIP/scrip"
    [ -x "$b" ] && return 1
    _gca_why="the criterion drives the compiler and $b is not built (run make) -- a missing binary is COULD-NOT-MEASURE, never a red row"
    return 0; }
# ⛔⭐ IS-A-PLACEHOLDER, BY KNOWN SHAPE, NEVER BY BARE SUBSTRING (seat13, 2026-09-05, row fifty-seven-
# batons-are-unclosable-because-their-criterion-is-not-at-column-zero). The old test was `case "$dw" in
# *⛔*)` -- ANY occurrence of the glyph anywhere in the line -- which misread 34+ live, correct,
# substantive DONE-WHENs as unwritten placeholders solely because their OWN defensive guard clause
# prints a message containing ⛔, e.g. `[ -n "$S4E_HOME" ] || { echo "⛔ REFUSE(2): ..."; exit 2; };
# <the real check>`. MEASURED (whole postoffice, 2026-09-05): the bare-substring test false-positived on
# 34 S4E_HOME guard-clause batons plus 2 instrument/meta batons whose own DONE-WHEN must reference the
# placeholder text as DATA to detect placeholders in OTHER files -- 36 of 56 files the old detector named
# were never broken. Real placeholders come in exactly two shapes, both known in full: the `mint`
# boilerplate (always starts with this exact text) and the hand-rolled self-refusing stub `echo "⛔
# ..." >&2; false` pre-dating `mint` (6 live instances, e.g. error-code-parity, named-io-channels).
# Neither shape can appear as a SUFFIX of a real command the way the guard clause does, so anchoring
# beats searching.
s4e_donewhen_is_placeholder() {   # $1 = raw column-0 DONE-WHEN text (already extracted); rc 0 = still a placeholder
    local dw="${1:-}"
    [ -z "$dw" ] && return 0
    case "$dw" in "⛔ MUST BE MADE RUNNABLE"*) return 0;; esac
    printf '%s' "$dw" | grep -qE '^echo "⛔[^"]*"( *>&2)?; *(false|exit [1-9][0-9]*)$' && return 0
    return 1; }
# ⛔⭐⭐ THE DONE-WHEN EXTRACTOR MOVED TO lib_donewhen.sh (cto's ruling on their own file, 2026-09-23, relayed
# to the coo: ONE implementation). s4e_field_criterion_text, s4e_donewhen_text, s4e_premise_text,
# s4e_donewhen_incomplete and s4e_donewhen_unterminated_heredoc are DEFINED THERE and sourced above -- the
# bus's private copy is DELETED in the same landing so no second reader can drift. The rule they carry is
# unchanged: the criterion is the FIRST LINE, and the rest of the field block is read only when that line is
# INCOMPLETE SHELL, because the live convention puts PROSE ANNOTATION under a complete one.
# ⛔ THE SOURCE ABOVE IS NO LONGER OPTIONAL AND THE COMMENT THERE SAYS SO. It used to warn and continue,
# because the only thing it carried was a no-op probe; it now carries the extractor `claim` and `done` read
# every criterion through, so a missing lib is a REFUSAL (rc=2, could not measure) and never an approximation.
# ⛔⭐ AND A SECOND, INDEPENDENT GUARD ON THE SAME FAILURE, because the extractor being right today is not a
# property anyone can keep proving: bash does NOT fail on an unterminated heredoc -- `bash -n -c "cat <<'EOF'"`
# exits 0 -- it only WARNS on stderr, which is precisely why the truncation could exit 0 for months. That warning
# is detectable, so any criterion whose text opens a heredoc it never closes is REFUSED (rc=2, could-not-measure),
# never graded. ⭐ This holds even if a future edit re-breaks the extractor, and it also catches a criterion an
# author simply mis-wrote -- the two cases a runner cannot tell apart and must not guess between.
# ⛔⭐⭐ MORE THAN ONE COLUMN-0 `DONE-WHEN:` LINE IS AN AMBIGUOUS CONTRACT, AND ONLY THE FIRST HAS EVER RUN
# (hq_T 2026-09-05, found while censusing the truncation class on the ceo's seed of six suspects). The extractor
# takes the first line by design; a baton carrying a SECOND column-0 DONE-WHEN: whose text is a real command has
# therefore been closing on HALF ITS OWN CONTRACT, silently, with the other half sitting in the file where every
# human reader counts it as part of the bar. ⭐ MEASURED: 39 live batons carry more than one such line; 10 extras
# survive the placeholder filters, but only THREE of those ten are genuinely a second criterion (see the
# byte-identical and prose rulings below -- the first census said ten and that number was wrong). Running the
# never-executed halves of the three: two are green (correctly closed anyway) and
# snobol4-xfail-class-setexit-errlimit-composition-2-entries is RED -- "cross-ref=0 (want 2)" -- a row closed on
# the half of its criterion that passed. That row is the ONE true false-closure this whole class ever contained.
# ⛔ REFUSES rather than running both: which line is the contract is a question about intent, and a tool that
# concatenates them invents a bar nobody wrote. Same call, and the same wording, as s4e_donewhen_hidden_elsewhere
# makes for its own case. The mint placeholder and the self-refusing stub are NOT counted -- a leftover placeholder
# under a real criterion is untidy, not ambiguous, and 4 of the 39 are exactly that.
# ⛔⭐⭐ A BYTE-IDENTICAL SECOND LINE IS NOT A SECOND CONTRACT (hq_T 2026-09-05, ceo's baton-repair order on the
# four open rows of this class). The refusal above rests entirely on "which line is the contract is a question
# about intent" -- and when the two texts are IDENTICAL there is no such question: the extractor taking the first
# loses nothing, no half of any bar went unrun, and the row was never in the false-closure hazard at all. Counting
# it would block a closable row for a COSMETIC reason, which is the exact ground on which the mint placeholder is
# already excluded four lines up. ⭐ MEASURED, whole postoffice, splitting the "10 real commands" this comment used
# to claim: 3 are byte-identical duplicates (prolog-failed-initialization-goal-exits-1-where-swipl-exits-0,
# raku-emitter-smx-coverage, dead-scrip-test-tree-three-raku-suites-report-green-on-nothing), 4 are PROSE at column
# zero, and only 3 are genuinely a second criterion -- all three snobol4-xfail-class rows. So the hidden-bar class
# is THREE, not ten, and exactly one of the three (setexit-errlimit) was ever red.
# ⛔ PROSE IS DELIBERATELY *NOT* DETECTED HERE, and that is a ruling, not an omission. Two of the four prose lines
# are an English spec full of backticks and one is a wrapped narrative sentence; every cheap discriminator I tried
# (shell metacharacters, a leading command word) misclassified at least one of them in BOTH directions. Telling
# prose from a command is the same intent question this function refuses to guess on, so the cure for those four is
# a RELABEL IN THE BATON, done in the same sitting -- never a heuristic here that would eventually eat a real bar.
# ⛔ The comparison is passed through the ENVIRONMENT, never `awk -v`: -v processes backslash escapes, and real
# criteria carry `\\` line continuations that would silently fail to compare equal.
# Sets $_dwm_lines for the message; rc 0 iff a second REAL, DIFFERENT criterion exists.
s4e_donewhen_multiple_contracts() {   # $1 = baton path
    local b="$1"
    _DWM_FIRST="$(sed -n 's/^DONE-WHEN:[[:space:]]*//p' "$b" | head -1)"; export _DWM_FIRST
    _dwm_lines="$(grep -n '^DONE-WHEN:' "$b" | sed -n '2,$p' \
        | grep -vE 'DONE-WHEN:[[:space:]]*⛔ MUST BE MADE RUNNABLE' \
        | grep -vE 'DONE-WHEN:[[:space:]]*echo "⛔[^"]*"( *>&2)?; *(false|exit [1-9][0-9]*)$' \
        | awk '{ txt = $0; sub(/^[0-9]+:DONE-WHEN:[[:space:]]*/, "", txt);
                 if (txt == ENVIRON["_DWM_FIRST"]) next;
                 num = $0; sub(/:.*$/, "", num); print num }' \
        | tr '\n' ' ' | sed 's/ $//')"
    unset _DWM_FIRST
    [ -n "$_dwm_lines" ]; }
# ⛔⭐⭐ THE MINT-TIME LINT (row mint-refuses-a-done-when-whose-first-word-is-not-a-command, hq_T's mint
# 2026-09-13). THE SHAPE, and it is why this belongs at the MINT and not on the rows: a row whose DONE-WHEN
# is prose can be cured PERFECTLY and still record no flip, because `done` executes the criterion and prose
# cannot exit 0. THE COST IS PAID BY WHOEVER LATER CURES THE ROW, NOT BY WHOEVER MINTED IT -- exactly the
# shape that does not self-correct, and the reason test_gate_baton_donewhen_runnable.sh's knowledge ("if you
# minted one, make it a command before you push") sits at the wrong end of the pipeline. hq_T walked into it
# three times in one hour and only found out when a blocking arm said so.
# ⛔ EVERY RULE HERE IS SOURCED, NONE IS RE-DERIVED. s4e_donewhen_is_noop, s4e_donewhen_is_placeholder,
# s4e_donewhen_incomplete and lib_donewhen.sh's donewhen_first_word are the authorities that `done`, the
# dispatch probe and the gate already answer to; a fifth private copy of the first-word rule beside them is
# the very defect lib_donewhen.sh was cut to end (four copies existed, all with one bug, hq_T 2026-09-11).
# ⛔⭐ AND IT NEVER EXECUTES THE CRITERION. mint runs before any work exists, so a criterion that legitimately
# reds today is the NORMAL case -- the only questions asked are the two static ones the gate asks: does it
# PARSE, and does its first command word RESOLVE.
# ⛔ A WORD NO STATIC CHECK CAN RESOLVE IS NOT CONVICTED ("$SCRIP", `which x`) -- same ruling as the gate's:
# a checker that cannot measure says so rather than convicting, because convicting there is precisely the
# false positive that made a seat rewrite two CURED rows' criteria to please an instrument.
# Prints the reason on stdout; rc 0 = REFUSE this criterion, rc 1 = it is acceptable.
s4e_donewhen_unrunnable_why() {   # $1 = criterion text, DONE-WHEN: label already stripped
    local dw="${1:-}" judge first
    [ -n "$(printf '%s' "$dw" | tr -d '[:space:]')" ] || { printf 'it is empty'; return 0; }
    # ⛔ CONTROL CHARACTERS, hq_P's 2026-08-22 measurement: a criterion written through python's re.sub had
    # its \b word-boundaries turned into literal BACKSPACE bytes. It parsed, its first word resolved, grep
    # matched NOTHING, and `! grep` therefore returned 0 -- a criterion that could only ever say YES.
    if [ "$dw" != "$(printf '%s' "$dw" | tr -d '\001-\010\013\014\016-\037')" ]; then
        printf 'it contains a CONTROL CHARACTER, so it does not mean what it looks like'; return 0; fi
    if s4e_donewhen_is_placeholder "$dw"; then
        printf 'it is a placeholder/self-refusing stub, which certifies nothing'; return 0; fi
    # ⛔ THE `true` BYPASS IS SHUT, AND THE ROW'S OWN MINTER ASKED FOR THAT IN SO MANY WORDS ("the guard must
    # not be satisfiable by typing true, or the cure hands everyone a bypass"). A guard whose cheapest escape
    # is one word is not a guard, it is a speed bump with a documented ramp.
    if s4e_donewhen_is_noop "$dw"; then
        printf 'it reduces to a NO-OP that always succeeds (true, :, echo, exit 0), so it certifies nothing'; return 0; fi
    # ⭐ JUDGE THE TEXT THE RUNNER WILL ACTUALLY RUN, which is s4e_donewhen_text's own rule: the first line
    # IS the criterion unless that line is incomplete shell, in which case the whole block is. Judging the
    # whole block unconditionally would convict every criterion that carries the prose annotation this
    # project's convention puts AFTER a complete one-line criterion (121 of 122 multi-line DONE batons).
    judge="$(printf '%s\n' "$dw" | head -1)"
    s4e_donewhen_incomplete "$judge" && judge="$dw"
    if s4e_donewhen_incomplete "$judge"; then
        printf 'it ends mid-heredoc or mid-quote, so bash can never finish reading it'; return 0; fi
    if ! bash -n -c "$judge" 2>/dev/null; then
        printf 'it is PROSE -- it does not parse as shell, so it can never exit 0'; return 0; fi
    first="$(command -v donewhen_first_word >/dev/null 2>&1 && donewhen_first_word "$judge")"
    case "$first" in ''|'['|test|cd) return 1;; esac
    donewhen_word_is_resolvable "$first" || return 1
    if ! command -v "$first" >/dev/null 2>&1; then
        printf "its first command word '%s' is not a command on this box" "$first"; return 0; fi
    return 1; }
# ⛔⭐ HIDDEN-ELSEWHERE: is there a DIFFERENT "DONE-WHEN:"-labeled line sitting in this baton's live text
# (GOAL/NEXT/QA), where a human but not the tool would read it as the contract? Scoped deliberately:
# the ## LEDGER section is excluded outright (it is historical narration -- this project's own ledgers
# routinely discuss "the DONE-WHEN as written" in prose, and a live contract would never legitimately
# live there), and backtick-quoted spans are stripped before matching (a GOAL sentence that says
# `` `sed -n 's/^DONE-WHEN:...'` `` to describe the extractor is a code REFERENCE, not a second
# candidate -- this is what the row's OWN GOAL paragraph and its sibling row's ledger both do, and
# both were false positives under the old whole-line scan). Sets $_dhe_lines (may be multi-line, numbered
# within the live text) for the refusal message; rc 0 iff at least one such line survives.
s4e_donewhen_hidden_elsewhere() {   # $1 = baton path
    local b="$1"
    _dhe_lines="$(awk '/^## LEDGER/{exit} {print}' "$b" \
        | sed -E 's/`[^`]*`//g' \
        | grep -n 'DONE-WHEN:' \
        | grep -vE '^[0-9]+:DONE-WHEN:' \
        | grep -vE '^[0-9]+:[[:space:]]*- ')"
    [ -n "$_dhe_lines" ]; }
# READ-ONLY probe: never closes, never claims, never writes. rc 0 green / 1 red / 2 could-not-measure.
# Sets $_dp_why (one line, why) and $_dp_out (the criterion's own output, which is the thing a reader needs --
# the mute-gate lesson from `done`: "DONE-WHEN exited 2" alone points nowhere).
s4e_dispatch_probe() {
    local t="$1" b="$PO/tasks/$1.task.md" dw to rc; _dp_why=""; _dp_out=""
    [ -f "$b" ] || { _dp_why="no task baton at $b"; return 2; }
    dw="$(s4e_donewhen_text "$b")"
    [ -n "$dw" ] || { _dp_why="the baton has no DONE-WHEN: line"; return 2; }
    if s4e_donewhen_is_placeholder "$dw"; then
        if s4e_donewhen_hidden_elsewhere "$b"; then
            _dp_why="column-0 is still a placeholder AND another DONE-WHEN: line sits elsewhere in the file (${_dhe_lines//$'\n'/ | }) -- refusing to guess which is the contract, hoist or relabel it"
        else
            _dp_why="the DONE-WHEN is still the mint placeholder, not a command"
        fi
        return 2
    fi
    s4e_donewhen_is_noop "$dw" && { _dp_why="the DONE-WHEN certifies nothing (a decorated shell no-op)"; return 2; }
    s4e_donewhen_multiple_contracts "$b" && { _dp_why="the baton carries a SECOND column-0 DONE-WHEN: (line(s) $_dwm_lines) that is a real command and has never run -- refusing to guess which line is the contract, hoist or relabel one"; return 2; }
    s4e_donewhen_unterminated_heredoc "$dw" && { _dp_why="the DONE-WHEN opens a heredoc it never closes -- bash would treat the body as EMPTY and exit 0 having run nothing, which is a false green, so this is COULD-NOT-MEASURE and never a verdict"; return 2; }
    s4e_donewhen_needs_compiler "$dw" && { _dp_why="$_gca_why"; return 2; }   # S4E-GUARD-COMPILER-ABSENT
    to="$(s4e_dispatch_timeout)"
    # ⛔ S4E_HOME EXPORTED, exactly as `done` does it: 11 live rows write `cd "$S4E_HOME/SCRIP" && ...` and
    # without the export that expands to the empty string and runs `cd /SCRIP`. A probe whose verdict depended
    # on the caller's environment would be worse than no probe -- it would close rows on some seats and not others.
    _dp_out="$(S4E_HOME="$S4E" timeout -k 5 "$to" bash -c "$dw" 2>&1)"; rc=$?
    case "$rc" in 124|137) _dp_why="did not finish within ${to}s (probe budget, not the row's fault)"; return 2;; esac
    [ "$rc" = 0 ] && { _dp_why="exited 0"; return 0; }
    _dp_why="exited $rc"; return 1; }
# ⛔⭐ STATIC, PRE-CLAIM PLACEHOLDER REFUSAL (row mint-dispatch-refuses-a-placeholder-done-when, ceo
# CEO-286 2026-09-05): `next` and `assign` used to DISPATCH a row whose DONE-WHEN is still the mint
# boilerplate -- s4e_dispatch_probe already answers "could not measure" (rc=2) for it, correctly, but
# both sides then SERVED the row anyway, indistinguishable from any other rc=2 (a slow criterion, a
# missing compiler). A row opened onto an unmeasurable criterion can never be CLOSED by any amount of
# correct work (`done` executes the DONE-WHEN line whole, and prose is not a command), so serving it is
# strictly worse than refusing: two rows were opened onto exactly this shape on 2026-09-05 alone.
# ⭐ THIS CHECK IS SAFE BEFORE A CLAIM EXISTS, UNLIKE s4e_dispatch_probe: s4e_donewhen_is_placeholder is a
# pure TEXT match on the baton (no execution), so reading it twice or before anyone holds the row changes
# nothing about the answer -- there is no race to protect against, the way there is for actually RUNNING
# the criterion (s4e_dispatch_gate's own comment: probed after the claim, so two seats cannot race the
# same probe). Calling this before the claim is written is what makes "NO claim file written" possible.
s4e_predispatch_placeholder_check() {   # $1 = topic; rc 0 = placeholder (refuse, do not claim), 1 = proceed; sets $_ppc_why
    local t="$1" b="$PO/tasks/$1.task.md" dw
    _ppc_why=""
    [ -f "$b" ] || return 1
    dw="$(s4e_donewhen_text "$b")"
    [ -n "$dw" ] || return 1
    if s4e_donewhen_is_placeholder "$dw"; then
        _ppc_why="the DONE-WHEN is still the mint placeholder, not a command -- $b needs a real DONE-WHEN before this row can be dispatched"
        return 0
    fi
    return 1; }
# ⛔⭐⭐ THE PREMISE GATE — THE SYMMETRIC HALF OF `done` (coo 2026-09-20, row instruments-claim-computes-the-
# rows-premise-the-way-done-computes-its-done-when; ceo CEO-1002, on Lon's rule that a failure the system never
# asked anyone to avoid is a row against the SYSTEM). THE ASYMMETRY BEING CURED: the bus VERIFIES THE EXIT and
# TRUSTS THE ENTRY. `done` runs the baton's DONE-WHEN and refuses on a red, so no seat can forget to prove a row
# finished; `claim` and `next` ran NOTHING about the premise the row is built on, so a stale premise was
# discovered only after the hour was spent. ⭐ MEASURED COST, ONE DAY, 2026-09-20, six wheel-spins and every one
# of them cheap to check: the cfo built a 51-entry return-class taxonomy and withdrew it because the allocator
# never collects (a fact in their own file); hq_prolog banked a trail mark to cure findall and it changed nothing
# because the trail was empty; the cto announced a cure for a raw push a watchpoint then proved dead; the ceo
# inferred effort from `ps` and escalated a wrong finding to Lon; hq_snobol4 opened row 1 on a premise reading red
# in every SnoRungs run when the entry is green at both arenas; hq_prolog inherited an eight-program bisect with three
# claims false on this tree.
# ⛔ A RED PREMISE IS NOT A DEFECT AND NOT A FAILING GATE. It is the row needing REWRITING before anyone spends an
# hour inside it -- which is exactly what hq_snobol4 did by hand, correctly, and reported. So the refusal says so
# in its own words, and it refuses BEFORE the lock: a row nobody can work is worse held than free.
# ⛔ SILENCE IS NEVER THE ANSWER TO "I COULD NOT MEASURE" (THE INSTRUMENT LAWS). rc=0 admits; a criterion that did
# not FINISH, that names an unbuilt compiler, that cannot be read as shell, or that certifies nothing ADMITS TOO --
# loudly, naming what it could not do. Only a premise that RAN and came back red stops the lock. An unverifiable
# premise must never block work; an unspoken one must never read as a verified one.
# ⛔⭐⭐ A BASH DIAGNOSTIC IS NOT A USAGE MESSAGE (cto -> coo 2026-09-20, REPORTED rather than cured because
# the bus is the coo's instrument). MEASURED, verbatim from the cto's terminal on SCRIP d6b8a02c4 and
# reproduced here: `s4e_msg.sh park` with no topic prints the unread-inbox banner and then
#     ../harness/scripts/s4e_msg.sh: line 2067: 2: topic
# and nothing else. That is `${2:?topic}` firing: the shell's own unbound-parameter message, which names a
# LINE NUMBER and the bare word `topic` to a seat who was reaching for the board. ⛔ THE COST IS NOT THE
# MISSING HELP, IT IS WHAT IT READS AS: a line-numbered shell error reads as A BROKEN BUS rather than as a
# usage error, so the seat stops and investigates the tool instead of retyping the command -- and a seat that
# cannot see the board picks its next row blind. TEN VERBS SHARED THE SHAPE (send, ask, mailbox, claim,
# unclaim, park, done, assign, reown, mint), so this was never one verb's typo.
# ⭐ rc=2 AND NOT 1: "I could not act on what you gave me" is the could-not-measure vocabulary every other
# refusal in this file speaks, and a caller scripting around the bus can tell it from a measured red.
# ⛔ NO VERB GAINS A NO-ARGUMENT BEHAVIOUR HERE. The report guessed `park` was dying in "the arm that should
# be its no-argument listing"; there is no such arm and never has been -- `board` is the verb that prints the
# board. Inventing one would be a new feature wearing a bug fix, and it would silently change what `park`
# with a typo'd topic does. The cure is the message, exactly.
s4e_need() {   # $1 = verb, $2 = what is missing, $3 = the usage line, $4 = one sentence on what the verb does
    printf '⛔ REFUSED (rc=2): `%s %s` needs %s -- nothing was read, nothing was written.\n' "${0##*/}" "$1" "$2" >&2
    printf '   usage: %s\n' "$3" >&2
    [ -n "${4:-}" ] && printf '   %s\n' "$4" >&2
    printf '   All verbs: %s\n' "$_S4E_VERBS" >&2
    exit 2; }
_S4E_VERBS="next|claim|unclaim|park|done|assign|reown|mint|ask|send|check|clear|mailbox|sweep|board|banner|fleet|premise|whoami"
s4e_premise_is_placeholder() {   # $1 = raw PREMISE-WHEN text; rc 0 = the field is present but expresses nothing
    case "$(printf '%s' "${1:-}" | tr -d '[:space:]')" in
      ''|'⛔NOTEXPRESSED'*|'NOTEXPRESSED'*|TODO*|TBD*|'⛔TODO'*) return 0;; esac
    return 1; }
# rc 0 = admit (the caller may lock/serve), rc 1 = REFUSE (the caller must NOT lock and must NOT serve).
s4e_premise_gate() {   # $1 = topic, $2 = the verb, for the message only
    local t="$1" verb="${2:-claim}" b="$PO/tasks/$1.task.md" pw log rc to t0 el
    [ "${S4E_NO_PREMISE_CHECK:-0}" = "1" ] && return 0
    [ -f "$b" ] || return 0
    pw="$(s4e_premise_text "$b")"
    # ⛔ THE BACKLOG IS NAMED, NEVER SILENTLY EXEMPT. Most live batons predate this field; they are admitted, and
    # the note says WHICH property went unchecked so a reader never mistakes "nothing ran" for "premise green".
    # ⭐ TWO LINES AND NOT FOUR, DELIBERATELY: on the day this landed it fired on 787 of 787 live rows, and a
    # notice that fires on everything is the one every reader learns to skip -- at which point the field is
    # adopted by nobody and the census below is the only thing still telling the truth. The full argument, the
    # per-owner counts and the names live in util_premise_census.py; this line is the doorbell, not the report.
    if [ -z "$pw" ] || s4e_premise_is_placeholder "$pw"; then
        printf '· PREMISE UNVERIFIED: %s has no runnable PREMISE-WHEN, so its central claim was NOT checked against\n' "$t" >&2
        printf '  today'"'"'s tree. Admitted. Before you spend an hour here, write one line into %s: PREMISE-WHEN: <the one cheap command that proves the premise>\n' "$b" >&2
        return 0; fi
    if s4e_donewhen_is_noop "$pw"; then
        printf '⚠ PREMISE NOT MEASURED: the PREMISE-WHEN in %s is a shell no-op (%s) -- it certifies nothing, so this\n' "$b" "$pw" >&2
        printf '  row'"'"'s premise is UNCHECKED exactly as if the field were absent. Admitted, never counted as verified.\n' >&2
        return 0; fi
    if s4e_donewhen_incomplete "$pw"; then
        printf '⚠ PREMISE NOT MEASURED (rc=2): the PREMISE-WHEN in %s is incomplete shell (an unclosed heredoc or a\n' "$b" >&2
        printf '  dangling continuation). bash would run NOTHING and exit 0, which would read as a verified premise --\n' >&2
        printf '  the false green this whole field exists to prevent. NOT run. Admitted unverified; fix the criterion.\n' >&2
        return 0; fi
    if s4e_donewhen_needs_compiler "$pw"; then
        printf '⚠ PREMISE NOT MEASURED (rc=2): %s. Admitted unverified -- an unbuilt tree is not a false premise.\n' "$_gca_why" >&2
        return 0; fi
    to="${S4E_PREMISE_TIMEOUT:-120}"; log="$(mktemp)"; t0="$(date +%s)"
    # ⭐ THE SAME ENVIRONMENT `done` GIVES A DONE-WHEN, for the same measured reason (hq_C 2026-08-27): S4E_HOME
    # exported, so a premise written as `cd "$S4E_HOME/SCRIP" && ...` -- the idiom the batons already use --
    # resolves against the LOCKING SEAT'S OWN ROOT rather than expanding to the empty string on some seats and
    # not others. A verdict that depends on the grader's environment is not a verdict.
    ( cd "$S4E" && S4E_HOME="$S4E" S4E_SEAT="$ME" S4E_PREMISE_WHEN_RUN=1 timeout -k 5 "$to" bash -c "$pw" ) >"$log" 2>&1; rc=$?
    el="$(( $(date +%s) - t0 ))"
    case "$rc" in
      0) printf '  ✅ PREMISE-WHEN exited 0 in %ss — the row'"'"'s premise still holds on this tree.\n' "$el" >&2
         rm -f "$log"; return 0;;
      124) printf '⚠ PREMISE NOT MEASURED (rc=2): the PREMISE-WHEN did not FINISH within %ss (elapsed %ss). Admitted\n' "$to" "$el" >&2
         printf '  unverified -- a premise that cannot be measured must never block work. ⛔ But a PREMISE-WHEN is meant\n' >&2
         printf '  to be THE ONE CHEAP COMMAND: one that needs more than %ss is a finding about the premise, not a slow\n' "$to" >&2
         printf '  machine. Raise it for this claim with S4E_PREMISE_TIMEOUT=<seconds>, or make it cheaper.\n' >&2
         rm -f "$log"; return 0;;
      126|127|2) printf '⚠ PREMISE NOT MEASURED (rc=2): the PREMISE-WHEN exited %s -- %s -- so it was never graded (CEO-786:\n' "$rc" \
           "$([ "$rc" -eq 127 ] && echo 'command not found' || { [ "$rc" -eq 126 ] && echo 'not executable' || echo 'the criterion itself refused'; })" >&2
         printf '  cannot measure is not red). Admitted unverified. What it said:\n' >&2
         [ -s "$log" ] && sed -e 's/^/  | /' "$log" | tail -8 >&2
         rm -f "$log"; return 0;;
    esac
    # RED, AND MEASURED. This is the only outcome that stops the lock.
    if [ -n "${S4E_PREMISE_OVERRIDE:-}" ]; then
        printf '⚠ PREMISE-WHEN IS RED AND WAS OVERRIDDEN by %s -- reason recorded in the baton LEDGER: %s\n' "$ME" "$S4E_PREMISE_OVERRIDE" >&2
        printf '\n- [%s·%s] **PREMISE OVERRIDDEN** — the PREMISE-WHEN exited %s on tree %s and the row was taken anyway. Reason: %s\n' \
            "$(date -u +%Y-%m-%dT%H:%MZ)" "$ME" "$rc" "$(git -C "$S4E" rev-parse --short HEAD 2>/dev/null || echo '(no tree)')" "$S4E_PREMISE_OVERRIDE" >> "$b"
        rm -f "$log"; return 0; fi
    printf '\n⛔⛔⛔ REFUSED — THE PREMISE OF THIS ROW IS RED ON THIS TREE. No lock was taken, nothing was served,\n' >&2
    printf '    and the QUEUE row is UNCHANGED. %s exited %s after %ss (budget %ss).\n' "PREMISE-WHEN" "$rc" "$el" "$to" >&2
    printf '    row     : %s\n' "$t" >&2
    printf '    baton   : %s\n' "$b" >&2
    printf '    premise : %s\n' "$pw" >&2
    if [ -s "$log" ]; then
      printf '    ⭐ WHAT THE PREMISE ITSELF SAID (last 20 lines) -- read this BEFORE hypothesising:\n' >&2
      sed -e 's/^/    | /' "$log" | tail -20 >&2
    else
      printf '    ⚠ the premise produced NO output at all -- usually a check that never ran rather than one that failed.\n' >&2
    fi
    rm -f "$log"
    printf '    ⭐⭐ THIS IS NOT A DEFECT, NOT A FAILING GATE, AND NOT YOUR WORK GOING WRONG. It is the row'"'"'s central\n' >&2
    printf '       claim no longer being true on this tree -- bought for the price of ONE COMMAND instead of an hour\n' >&2
    printf '       inside a row built on it. Six seats spent that hour on 2026-09-20 alone; that is why this runs.\n' >&2
    printf '    WHAT TO DO, in order: (1) READ the premise output above -- it usually names what changed;\n' >&2
    printf '       (2) REWRITE the row against what is true today (its GOAL, its DONE-WHEN and its PREMISE-WHEN), or\n' >&2
    printf '       (3) if the row is now moot, say so to the ceo in one line and let it be retired -- a premise that\n' >&2
    printf '       went green elsewhere is work someone else already did, which is a finding, not a loss.\n' >&2
    printf '    ⛔ Do NOT weaken the PREMISE-WHEN to get past this. That is the false-green trap in its entry form.\n' >&2
    printf '    If the PREMISE is wrong and the ROW is right, that is a real event and the honest exit is loud:\n' >&2
    printf '       S4E_PREMISE_OVERRIDE="why" %s %s %s   (records the reason in the baton LEDGER)\n\n' "$0" "$verb" "$t" >&2
    return 1; }
# ⛔⭐ THE DISPATCH GATE, CALLED FROM EVERY PATH IN PASS 3 THAT SERVES A ROW -- rc 0 = serve it, 1 = it was
# closed, take the next one. ⛔ IT IS A FUNCTION BECAUSE PASS 3 SERVES FROM **TWO** PLACES AND THE FIRST DRAFT
# OF THIS CURE ONLY WIRED ONE: the ordinary claim-and-serve at the bottom, and the DEPENDENCY INVERSION
# promotion that serves a blocked row's blocker at the blocked row's rank. MEASURED, and it is why this is not
# inline: with only the ordinary path wired, test_gate_s4e_unclaim_keeps_park.sh still passed -- because the
# row it asserts on reaches the seat through the PROMOTION path, which sailed past the probe untouched. A gate
# passing for a reason unrelated to the change is exactly how a half-wired cure reads as a whole one.
# ⭐ THIS IS THE `park`/s4e_mark_row LESSON AGAIN, WRITTEN DOWN ONE FILE LATER: "a cure that enumerates its
# closing verbs silently reopens every time a new closing verb is minted." Same shape, serving side. If you add
# a third way to hand a row to a seat, it calls THIS -- do not copy the block.
s4e_dispatch_gate() {   # $1 = topic (already claimed by us), $2 = rank, for the message only
    local _dgt="$1" _dgr="$2" _dpb
    # ⛔⭐ DISPATCH PROBE (see s4e_dispatch_probe above for the measured cause). PROBED AFTER THE CLAIM,
    # DELIBERATELY: the claim is what makes the answer ours to act on. Probing first would let two seats
    # race the same probe and both close the same row, and closing a row we do not hold is the eviction
    # `park` already refuses to do. ⭐ AND BECAUSE THE CLAIM IS NOW OURS, THE PROBE IS `done` ITSELF --
    # not a reimplementation of it. That buys every guard `done` already carries, for free and without a
    # second copy to drift: the vacuity blocklist, the markdown-backtick strip, the no-baton refusal, the
    # ROWD-manifest guard that stops a close from redding `make test` fleet-wide, the S4E_HOME export,
    # and the claim/column mirroring. A close performed here is byte-for-byte a close performed by hand.
    _dp_out="$(S4E_NO_BANNER=1 S4E_DONE_TIMEOUT="$(s4e_dispatch_timeout)" "$0" done "$_dgt" 2>&1)"; _dp_rc=$?
    if [ "${S4E_NO_DISPATCH_PROBE:-0}" = "1" ]; then _dp_rc=1; _dp_out=""; fi
    case "$_dp_rc" in
      0) # GREEN -- the row was already satisfied. `done` has closed it; record WHY in the baton and move on.
         _dpb="$PO/tasks/$_dgt.task.md"
         [ -f "$_dpb" ] && printf '\n- [%s·%s] **ALREADY SATISFIED AT DISPATCH** — the picker ran this row'"'"'s own DONE-WHEN before serving it and it exited 0, so the row was closed rather than handed to a seat. Nobody worked it; if that is wrong, the DONE-WHEN is wrong (it is passing on a tree where the work is not done) and THAT is the finding. Probe budget %ss; tree %s.\n' "$(date -u +%Y-%m-%dT%H:%MZ)" "$ME" "$(s4e_dispatch_timeout)" "$S4E" >> "$_dpb"
         printf '✅ ALREADY SATISFIED AT DISPATCH — rank-%s %s was NOT served: its own DONE-WHEN exits 0 on this tree.\n' "$_dgr" "$_dgt"
         printf '   Closed DONE (via `done`, so every close guard applied) and a ledger line says why. Looking for the next row...\n'
         printf '   ⛔ If you believe this row is real work, the DONE-WHEN is the defect -- it passes where the work is not done.\n'
         # ⛔ return 1, NOT continue. `continue` inside a function does reach the caller's loop in bash, which
         # is exactly why it is wrong here: it would work by accident from PASS 3 and silently do nothing (or
         # worse) from any future caller that is not inside a loop. The caller spells the control flow.
         return 1;;
      2) # COULD NOT MEASURE -- serve it, but never silently.
         printf '⚠ DISPATCH PROBE COULD NOT MEASURE %s -- serving it anyway, unverified.\n' "$_dgt" >&2
         printf '%s\n' "$_dp_out" | grep -m2 -E '⛔|REFUSED|did NOT FINISH' | sed 's/^/   | /' >&2
         printf '   Probe budget was %ss (S4E_DISPATCH_PROBE_TIMEOUT). A criterion too slow to PROBE is not a failing row.\n' "$(s4e_dispatch_timeout)" >&2;;
      *) # RED is the only silent outcome: it is the only one that means there is real work here.
         # ⭐ Except when `done` refused rather than measured -- it exits 1 for a vacuous criterion too,
         # so rc alone cannot tell "no work needed" from "this row can never be closed". Say so.
         if printf '%s' "$_dp_out" | grep -q 'REFUSED'; then
           printf '⚠ %s has a DONE-WHEN that can never pass -- serving the row, but it cannot be CLOSED until that is fixed.\n' "$_dgt" >&2
           printf '%s\n' "$_dp_out" | grep -m1 'REFUSED' | sed 's/^/   | /' >&2; fi;;
    esac
    return 0; }
# age in whole minutes of the oldest .msg in a mailbox; empty when the box is clear.
s4e_oldest_min() { _old=""; for _f in "$PO/$1/inbox"/*.msg; do [ -f "$_f" ] || continue
    _m=$(( ( $(date +%s) - $(stat -c %Y "$_f" 2>/dev/null || echo 0) ) / 60 ))
    [ -z "$_old" ] && _old=$_m; [ "$_m" -gt "$_old" ] && _old=$_m; done; echo "$_old"; }
# ⭐ compact age for a MTIME, in the units a reader actually compares ("7m", "3h12m", "2d01h"). Empty in -> "-".
s4e_age_compact() { [ -n "${1:-}" ] && [ "$1" -gt 0 ] 2>/dev/null || { echo "-"; return; }
    _s=$(( $(date +%s) - $1 )); [ "$_s" -lt 0 ] && _s=0
    if   [ "$_s" -lt 3600 ]; then printf '%dm\n' $(( _s / 60 ))
    elif [ "$_s" -lt 86400 ]; then printf '%dh%02dm\n' $(( _s / 3600 )) $(( (_s % 3600) / 60 ))
    else printf '%dd%02dh\n' $(( _s / 86400 )) $(( (_s % 86400) / 3600 )); fi; }
# ⛔⭐⭐ THE JOINED LOCK TEST — ONE CENSUS, NOT TWO HALF-CENSUSES (ceo CEO-297, 2026-09-05, reconciling two
# readings that were each wrong in OPPOSITE directions at the FLEET-12 flip). Measured: the ceo censused by the
# claim file's STATUS line and named 52 seat locks older than the flip; `unclaim` then refused 43 of them because
# their QUEUE rows read DONE while the claim file still said RUNNING. hq_T censused by claim status alone and read
# zero live locks by retired seats. A RUNNING status line alone OVER-reports (a closed row whose claim was never
# reconciled looks held) exactly as a queue column alone UNDER-reports (a receipt sitting on an open row looks free).
# ⭐ Neither field is the lock. The JOIN is: a row is HELD iff its queue row is not DONE **and** its claim names a
# holder with a RUNNING status. Everything else is bookkeeping, and the two shapes of bookkeeping are worth telling
# apart because only one of them is ever worth acting on.
#   HELD           queue not DONE + claim RUNNING   -- a real lock; hides the row from the picker for the whole fleet
#   RECEIPT        claim DONE + queue DONE or FREE  -- the DESIGNED steady state between a close and the next sweep
#   AWAITING-SWEEP anything else                    -- a closed row whose two files have not met yet; never a lock
#   ORPHAN         a claim file with no queue row at all -- invisible to every census that starts from QUEUE.tsv
# ⛔ AND THE VERDICT IS NOT THE WHOLE ANSWER, because the picker does not read it: `next` skips a row if a claim file
# EXISTS AT ALL, DONE or not (:2044, :2159). So a RECEIPT or an AWAITING-SWEEP sitting on a queue row that is NOT
# done hides that row from the whole fleet with NOBODY holding it -- a lock in effect with no holder to ask. That
# state has no name in the three-way taxonomy, so the census counts it separately rather than filing it under a
# verdict that says "not a lock" about a row nobody can reach.
s4e_claim_verdict() { _t="${1:-}"; _c="$PO/claims/$_t.claim"
    [ -f "$_c" ] || { echo "-"; return; }
    if grep -q '^DONE$' "$_c"; then _cs=DONE; else _cs=RUNNING; fi
    _qs="$(awk -F'\t' -v T="$_t" '$2==T{print $4; exit}' "$PO/QUEUE.tsv" 2>/dev/null)"
    [ -n "$_qs" ] || { echo "ORPHAN"; return; }
    # ⛔⭐ "NOT DONE" IS THREE STATES, NOT ONE, AND READING IT AS ONE OVER-REPORTS -- measured by this very
    # instrument on its first run (hq_T 2026-09-05). CEO-297 says "queue row is not DONE"; the live vocabulary
    # closes a row THREE ways -- DONE, RETIRED and SUPERSEDED -- so a `DONE*` test called two closed rows open
    # and printed them as hidden work. That is the same shape as the half-census this instrument exists to
    # replace, reproduced inside the replacement, which is why the closed set is spelled out here once.
    case "$_qs" in DONE*|RETIRED*|SUPERSEDED*) _qd=1;; *) _qd=0;; esac
    if [ "$_cs" = RUNNING ]; then [ "$_qd" -eq 1 ] && echo "AWAITING-SWEEP" || echo "HELD"
    else case "$_qs" in DONE*|RETIRED*|SUPERSEDED*|FREE*) echo "RECEIPT";; *) echo "AWAITING-SWEEP";; esac; fi; }
# ⭐ TRUE when a claim hides its row from the picker while nobody is holding it -- the state above that the
# three-way verdict cannot express. Read with the verdict, never instead of it.
s4e_claim_blocks_free_row() { _t="${1:-}"
    [ -f "$PO/claims/$_t.claim" ] || return 1
    [ "$(s4e_claim_verdict "$_t")" = "HELD" ] && return 1
    _q="$(awk -F'\t' -v T="$_t" '$2==T{print $4; exit}' "$PO/QUEUE.tsv" 2>/dev/null)"
    [ -n "$_q" ] || return 1
    # ⛔ ONLY A ROW THE PICKER WOULD OTHERWISE SERVE COUNTS. A PARKED, BLOCKED or GRANT-NEEDED row is deliberately
    # not served, so a claim file on it costs the fleet nothing and naming it "hidden work" trains the eye to skip
    # this alarm. The workable set is exactly what `next` will hand out: FREE, ASSIGNED, CLAIMED.
    case "$_q" in FREE*|ASSIGNED*|CLAIMED*) return 0;; *) return 1;; esac; }
# ⭐ banner-attributes-wrong-row-on-unclaim (s273): a SESSION-SCOPED receipt of the last row THIS seat
# actually closed (released or done'd), written at the moment of the transition. banner's row1 fallback
# (bare invocation, no $pref -- Stop hook, `board`) reads this instead of rescanning ALL historical claims
# under this identity, which is what let an ancient unrelated DONE claim surface as if it were this
# session's work. Two lines: topic, then "STATE ISO-TIMESTAMP". Overwritten each transition -- only the
# LATEST closing action is ever attributed, matching "what did this seat just finish."
# ⛔⭐ THE ONE WRITER OF QUEUE.tsv's STATE COLUMN. Factored out of `park` (which was its only caller) so that
# `done` can mirror a close through the SAME code rather than growing a second, subtly-different rewriter.
# ⭐ WHY THIS EXISTS AT ALL: dispatch state has two homes -- claims/<topic>.claim and QUEUE.tsv's column --
# and until 2026-08-28 NO verb updated the column on completion. `done` latched the claim and left the column,
# so claim=DONE / queue=FREE was the DESIGNED steady state between a close and the next MANUAL sweep. Measured
# that day: 4 rows in that state, 0 in the mirror state. The asymmetry is the point -- the loud direction (a row
# that keeps coming back) gets noticed and fixed; this one is SILENT and produces no symptom until a ruling
# lands on the row and cannot be dispatched. See PROTOCOL-V2-DRAFT § A RESERVED QUESTION GETS AN ASSIGNED OWNER.
# ⛔⭐ THE LOCK IS NOT OPTIONAL, AND ITS NAME IS A LIE (hq_B 2026-08-29, queue-column-unwritten-by-acquiring-verbs).
# QUEUE.tsv is ONE file rewritten read-all/write-tmp/cat-back here, and the cure below puts that rewrite on the
# CLAIM path -- which up to 16 seats hit at every prompt, where before it ran only on a park or a close. That is
# exactly the shape `mint` already takes $PO/.mint.lock for, so this takes THE SAME lock: two differently-named
# locks over one file are not mutual exclusion at all. Reusing .mint.lock rather than renaming it is deliberate --
# a rename silently loses exclusion against any seat whose clone still has the old name, which is the stale-clone
# class this file convicts elsewhere. Renaming it to .queue.lock fleet-wide is a separate, later row.
# ⛔⭐ AND IT FAILS OPEN, NEVER CLOSED. A column write that cannot get the lock WARNS and returns 1; it must never
# abort a claim or a dispatch. The claim file is the authority and the picker reads THAT -- the column is only its
# readable twin, so a missed write costs legibility, while failing closed here would cost the fleet its dispatch.
s4e_set_row_state() {   # <topic> <state>  -- no-op (rc 1) when the topic has no live QUEUE.tsv row
  local _t="$1" _s="$2" _q="$PO/QUEUE.tsv" _tmp _lk="$PO/.mint.lock" _got=0 _i _rc=0
  # ⛔ STRUCTURAL INTEGRITY BELONGS AT THE PRIMITIVE, VOCABULARY AT THE VERB. `park` validates the state against
  # the known vocabulary; here we refuse only what would TEAR the file, because this function is reached by every
  # writer (claim/assign/unclaim/done/park) and a tab in the state column splits the row for every reader. A
  # vocabulary check here would instead risk refusing a legitimate value some future verb computes.
  case "$_s" in *$'\t'*|*$'\n'*) printf '⛔ REFUSED: state for %s contains a tab/newline; that would tear the QUEUE.tsv row. Not written.\n' "$_t" >&2; return 1;; esac
  grep -qP "^[0-9]+\t\Q$_t\E\t" "$_q" 2>/dev/null || return 1
  for _i in $(seq 1 20); do mkdir "$_lk" 2>/dev/null && { _got=1; break; }; sleep 0.1; done
  [ "$_got" = 1 ] || { printf '⚠ QUEUE.tsv state column NOT updated for %s (lock busy 2s). The CLAIM is the authority and dispatch is unaffected; only its readable twin is stale.\n' "$_t" >&2; return 1; }
  _tmp="$(mktemp)"
  if awk -F'\t' -v OFS='\t' -v t="$_t" -v s="$_s" '$2==t&&NF>3{$4=s} {print}' "$_q" > "$_tmp"; then cat "$_tmp" > "$_q" || _rc=1; else _rc=1; fi
  rm -f "$_tmp"; rmdir "$_lk" 2>/dev/null
  return $_rc
}
# ⭐⭐ NO BLANK OWNER CELL, THE OTHER HALF (row next-serves-a-seat-only-rows-in-its-hqs-lane-and-no-row-
# carries-a-blank-owner-cell). Column 3 stays the UMBRELLA-HQ/lane, never the working seat's own name --
# see the "COLUMN 3 IS DELIBERATELY NOT TOUCHED" note at claim's own acquisition site, which documents col3
# hq_B + claim seat12 as a MEANINGFUL pair (umbrella-HQ + working-seat), not drift to be cleaned. So this
# ONLY FILLS AN EMPTY CELL — never overwrites an existing value, deliberate or not; an already-set col3
# stays "a question routed to hq_P/ceo", exactly as that note already ruled. Writes the ASSIGNEE's OWN lane
# (its postoffice HQ file, or itself if the assignee IS an HQ) — never the assignee's bare name, which would
# be the exact drift the existing note warns against.
s4e_backfill_owner_lane() {
  local _t="$1" _seat="$2" _q="$PO/QUEUE.tsv" _row _cur _lane
  _row="$(qrow "$_t")"; [ -n "$_row" ] || return 1
  _cur="$(printf '%s' "$_row" | cut -f3)"
  case "$_cur" in ''|unassigned) : ;; *) return 0;; esac   # already set -- not this function's decision to change
  case "$_seat" in
    hq_icon|hq_prolog|hq_raku|hq_pascal|hq_snocone|hq_snobol4|hq_templates|hq_runtime|hq_collector|hq_zetas|hq_dotnet|hq_jvm|hq_C|hq_B|hq_P|hq_T|hq_U|hq_S|hq_I|hq_R|hq_V) _lane="$_seat" ;;
    seat*) [ -f "$PO/$_seat/HQ" ] && _lane="$(head -1 "$PO/$_seat/HQ" | tr -d '[:space:]')" ;;
  esac
  case "${_lane:-}" in hq_icon|hq_prolog|hq_raku|hq_pascal|hq_snocone|hq_snobol4|hq_templates|hq_runtime|hq_collector|hq_zetas|hq_dotnet|hq_jvm|hq_C|hq_B|hq_P|hq_T|hq_U|hq_S|hq_I|hq_R|hq_V) : ;; *) return 1;; esac   # undeterminable -- leave blank rather than guess
  local _lk="$PO/.mint.lock" _got=0 _i _tmp
  for _i in $(seq 1 20); do mkdir "$_lk" 2>/dev/null && { _got=1; break; }; sleep 0.1; done
  [ "$_got" = 1 ] || return 1
  _tmp="$(mktemp)"
  awk -F'\t' -v OFS='\t' -v t="$_t" -v o="$_lane" '$2==t&&NF>3&&($3==""||$3=="unassigned"){$3=o} {print}' "$_q" > "$_tmp" && cat "$_tmp" > "$_q"
  rm -f "$_tmp"; rmdir "$_lk" 2>/dev/null
}
s4e_mark_row() { mkdir -p "$PO/$ME"; printf '%s\n%s %s\n' "$1" "$2" "$(date -u +%Y-%m-%dT%H:%MZ)" > "$PO/$ME/.last-row"; }
s4e_sweep_orphans
# ⛔ UNREAD MAIL IS SHOUTED ON EVERY COMMAND (HQ, 2026-08-22, after seat2 skipped THE LOOP step 1 and left an HQ
# ruling unread in its inbox while asking Lon the same question in chat). The inbox is HQ's ONLY channel to a
# running seat -- Lon does not relay -- so it cannot depend on the seat remembering to `check`. Every subcommand
# except check/clear now surfaces pending mail first. A seat cannot run `next`, `done`, `board` or `banner`
# without being told it has unread HQ mail.
# ⛔⭐ THE BANNER GOES TO stderr FOR SCRIPTABLE VERBS, AND IS NOT SUPPRESSED FOR ANY OF THEM (hq_B 2026-09-13).
# A human still sees every word on a terminal, where stdout and stderr are the same screen; what changes is that
# `whoami`'s stdout carries the seat name and nothing else, so a caller can use it. ⛔ THE ALTERNATIVE -- exempting
# whoami the way check/clear are exempted -- WAS REJECTED: the law above is that unread mail is shouted on EVERY
# command, and an exemption list is how that law erodes one quiet verb at a time. Moving the stream keeps the shout.
# ⭐ MEASURED, AND IT IS WHY THIS BLOCK CHANGED AT ALL: whoami's first version returned the entire six-line unread
# banner welded into one word as the seat identity, and its caller built a mailbox path out of that. The gate
# REFUSED rc=2 rather than proceed, which is the instrument working -- but a human banner on stdout silently
# corrupts every machine-readable verb, and only the newest verb happened to notice.
_bfd=1; case "$cmd" in whoami) _bfd=2;; esac
case "$cmd" in check|clear) ;; *)
  _n=0; for _f in "$PO/$ME/inbox"/*.msg; do [ -f "$_f" ] && _n=$((_n+1)); done
  if [ "$_n" -gt 0 ]; then
    { printf '\n⛔⛔⛔ %s HAS %s UNREAD HQ MESSAGE(S) — READ THEM BEFORE ANYTHING ELSE ⛔⛔⛔\n' "$ME" "$_n"
      for _f in "$PO/$ME/inbox"/*.msg; do [ -f "$_f" ] || continue; printf '    %s\n' "$(head -1 "$_f")"; done
      printf '    bash harness/scripts/s4e_msg.sh check      <- do this now\n\n'; } >&$_bfd; fi ;;
esac
# ⭐ ONE PROTOCOL NUMBER, HOISTED (ceo 2026-08-29, row s4e-clear-needs-protocol-version-guard): next() and clear() both
# guard on it now, and two inline copies of one value is the drift class this file convicts elsewhere. Bump it HERE and
# in the shared PROTOCOL-VERSION file together.
# ⛔ BUMPED 4 -> 5 (ceo ruling 2026-08-29, on hq_B's ask; "the word is given"). WHY A BUMP RATHER THAN A
# CADENCE: the state-column cure (d1ae2d30) lives in EACH SEAT'S OWN s4e_msg.sh, so a clone that has not
# pulled keeps writing lying FREE rows at every claim. Measured after the one-time reconcile of 18 rows: the
# A count went to 1 within minutes, and that one row was minted by a seat whose clone predates the cure. So
# reconciling on a cadence is symptom management -- the drift regenerates faster than a human sweeps it.
# Raising this number makes next() REFUSE to dispatch from any clone below it, which forces the pull before
# the next serve. That is what the guard was built for (seat09 79 commits behind, seat13 2, both silently
# running v1's picker).
# ⛔⛔ ORDERING IS LOAD-BEARING AND IS THE ONE WAY THIS GOES WRONG: this commit must be PUSHED BEFORE
# $PO/PROTOCOL-VERSION is raised to 5. The shared file is what seats compare against; raise it first and
# every seat is refused work while the commit that would fix them does not yet exist on origin.
# ⛔ BUMPED 5 -> 6 (ceo CEO-1356, 2026-09-28, at the QUINTET flip): the mode-admission table lives in each seat's own clone, and a
# clone older than 3a1b8443b has no QUINTET arm, so a stood-down HQ is ADMITTED by falling out of the case (CEO-755b) -- measured:
# hq_prolog claimed a row at 17:24:49, fifty-four seconds after MODE read QUINTET. Raising the number makes next() and clear()
# refuse from every clone below it until it pulls, and a pulled clone refuses the stood-down seat by name.
# ⛔ BUMPED 6 -> 7 (ceo CEO-1811, 2026-10-17, at the QUINTET redefinition): an older clone's QUINTET arm admits hq_snocone and refuses the live hq_runtime.
S4E_PROTO=7
case "$cmd" in
  send)  [ -n "${2:-}" ] || s4e_need send "a destination seat" "s4e_msg.sh send <to> <topic> --stdin <<'MSG' ... MSG" "A prose body must come through --stdin: a body in double quotes is expanded by YOUR shell before send ever runs."
         [ -n "${3:-}" ] || s4e_need send "a topic" "s4e_msg.sh send <to> <topic> --stdin <<'MSG' ... MSG" "The topic is the subject line the recipient sorts by; it becomes a filename, so keep it a slug."
         to="$(s4e_canon "$2")"; topic="$3"; shift 3; s4e_assert_box "$to" destination; s4e_assert_not_drained "$to"
         # ⛔ THE TOPIC BECOMES A FILENAME, SO IT IS VALIDATED BEFORE IT BECOMES A PATH (s191, seat1).  MEASURED, not hypothetical:
         # calling `send seat8 "<a whole message containing harness/scripts/...>"` made the topic carry slashes, the mv failed with
         # "No such file or directory" -- AND THE SCRIPT PRINTED `sent` ANYWAY.  A seat-to-seat message that is silently dropped
         # while the sender is told it was delivered is unrecoverable and invisible to BOTH ends: the 'non-empty is not alive'
         # false-signal class, on the fleet bus itself.  Two guards, because either alone still lies: refuse a topic that cannot
         # be a filename, and make the RESULT the thing that is reported -- `sent` is now printed only if the mv succeeded.
         case "$topic" in ""|*/*|*$'\n'*) echo "⛔ REFUSED: topic must be a short filename-safe slug (no / and no newline), not the message body. Usage: $0 send <to> <topic> \"text\"" >&2; exit 2;; esac
         # ⭐⭐ --stdin READS THE BODY FROM STDIN, WHICH TAKES THE CALLER'S SHELL OUT OF THE BODY PATH ENTIRELY
         # (hq_C 2026-08-27, on hq_P's find). ⛔ THE DEFECT IT CURES IS NOT A BACKTICK PROBLEM, IT IS A SHELL-EXPANSION
         # PROBLEM: a body written inside DOUBLE QUOTES is expanded by the caller's shell BEFORE this script ever runs,
         # so backticks, $(...) and bare $NAME are all silently REPLACED BY THEIR EXPANSION -- usually nothing. Both HQs
         # hit it the same day: hq_C lost the word `done` from a sentence about the done subcommand; hq_P lost a whole
         # $(subst ...) from a Makefile line, ONE MESSAGE AFTER READING hq_C's warning about it. Discipline demonstrably
         # does not fix this -- hq_P had the warning in hand and still walked in, because the rule was stated as "no
         # backticks" and the metacharacter that bit them was different. ⛔ AND THIS SCRIPT CANNOT DETECT IT: the damage
         # happens in the CALLER's shell, so what arrives here is a well-formed body that simply is not what was typed,
         # with no residue to test for. That is why the cure has to be a SAFE INPUT PATH rather than a validator.
         # ⭐ USE:  s4e_msg.sh send <to> <topic> --stdin <<'MSG'   ... body ...   MSG
         # The QUOTED heredoc delimiter is the load-bearing part: <<'MSG' disables expansion, <<MSG does not.
         if [ "${1:-}" = "--stdin" ] || [ "${1:-}" = "-" ]; then _body="$(cat)"; _via_stdin=1; else _body="$*"; _via_stdin=0; fi
         [ -n "$_body" ] || { echo "⛔ REFUSED: empty message body. With --stdin, check the heredoc actually delivered." >&2; exit 1; }
         # ⛔⭐⭐ A PROSE BODY MUST COME THROUGH --stdin. THE SAFE INPUT PATH IS NOW THE DEFAULT, NOT THE ADVICE
         # (hq_I 2026-09-13, occurrence FOUR, routed to hq_B as postoffice tooling; landed by hq_B).
         # ⛔ WHY A VALIDATOR CANNOT DO THIS AND ONLY THE INPUT PATH CAN: the guard below refuses a body that still
         # CARRIES a backtick or $(. It cannot see the case that actually bites -- a body whose backticks were already
         # eaten by the CALLER's shell arrives here clean, shorter, and passes every check. hq_I's witness, twice in one
         # message: two backtick-wrapped code fragments ran as commands, failed, and spliced their empty output back in;
         # send reported SUCCESS, correctly, on a body whose entire technical content had been deleted. The evidence is
         # gone before this script starts. ⭐ So do not add a smarter check to the wrong side of the boundary -- hq_T
         # talked hq_I out of exactly that, and the reasoning is the valuable half: a gutted-body detector would be a
         # THIRD instrument reporting success while answering a narrower question than it appears to, which is the very
         # family this row is about. Fix the input path.
         # ⛔ DISCIPLINE DEMONSTRABLY DOES NOT FIX IT, WHICH IS THE ARGUMENT FOR A REFUSAL AT THE MOMENT OF THE ACT:
         # hq_P walked into it ONE MESSAGE AFTER READING hq_C's warning; hq_I has this trap written into their own root
         # digest as a named, dated, three-instance lesson, has quoted it to others, and hit it anyway -- because
         # composing prose does not feel like the moment the rule is about. An instrument that refuses when you act is
         # worth more than any number of readings.
         # ⭐ THE THRESHOLD IS MEASURED, NOT GUESSED (hq_B, over 400 real messages in the postoffice): real seat-to-seat
         # bodies run 120..5698 bytes, median 988, p10 271. Operational one-liners the argv path exists for -- "queue
         # empty", "row vanished under me" -- are ~11..25. 200 bytes or a second sentence separates them with room to
         # spare, so this refuses prose and leaves short operational sends alone.
         # ⛔ NO BYPASS, matching the backtick guard directly below: an OPTIONAL safe path is the defect being cured,
         # and nothing in the tree sends a prose body through argv (censused -- the in-tree hits are usage text in echo
         # strings). If automation ever needs one, it can pipe: printf '%s' "$body" | s4e_msg.sh send <to> <topic> --stdin
         if [ "$_via_stdin" = 0 ]; then
           _blen=${#_body}
           _bsent=$(printf '%s' "$_body" | grep -oE '[.!?](  *|$)' | wc -l)
           if [ "$_blen" -ge 200 ] || [ "$_bsent" -ge 2 ]; then
             echo "⛔ REFUSED: a prose body ($_blen bytes) must be sent through --stdin, not as a shell argument. NOTHING WAS DELIVERED." >&2
             echo "   ⛔ THE POINT IS NOT THIS MESSAGE, IT IS THE ONES THAT ARRIVE LOOKING FINE: a body written inside double" >&2
             echo "   quotes is expanded by YOUR shell before send ever runs, so backticks, \$(...) and bare \$NAME are replaced" >&2
             echo "   by their expansion -- usually nothing. The result is well-formed, shorter, and silently missing the words" >&2
             echo "   you cared about most. send cannot detect that: the evidence is gone before it starts." >&2
             echo "   ✅ SEND IT AGAIN THIS WAY -- the QUOTED delimiter is the load-bearing part (<<'MSG' disables expansion, <<MSG does not):" >&2
             echo "       $0 send $to $topic --stdin <<'MSG'" >&2
             echo "       ...your body, exactly as you mean it..." >&2
             echo "       MSG" >&2
             # ⛔⭐⭐ THE LAST LINE OF A REFUSAL IS THE ONE THAT GETS READ, AND MINE WAS THE HEREDOC DELIMITER
             # (cfo 2026-09-13, measured; hq_B's own defect, cured same sitting). The block above is usage-SHAPED, so a
             # seat doing the ordinary thing and tailing the output saw `MSG` and read it as an echo of a successful
             # send. The cfo lost FOUR sends before bisecting -- by length, then by recipient, then by rate -- and only
             # found them by listing the recipient's inbox and seeing nothing there. ⭐ hq_T lost a ruling to the
             # backtick variant an hour earlier and caught it the same way, and wrote the sentence worth keeping:
             # READING A SENDER'S OUTPUT FOR A POSITIVE MARKER CANNOT TELL SENT FROM REFUSED, the same way a grep over
             # a runner cannot tell clean from could-not-measure. ⛔ So a refusal ENDS with its verdict, never with an
             # example: whatever a reader's eye lands on last must be the thing that happened, not the thing to do next.
             echo "⛔ REFUSED — NOTHING WAS DELIVERED. Nothing was written to $to's inbox; re-send with --stdin above." >&2
             exit 1
           fi
         fi
         # ⛔⭐ SHAPE GUARD, NOT A DAMAGE DETECTOR (hq_T, task send-executes-backticks-in-a-message-body...,
         # on hq_C's + hq_P's same-hour hits above). A body that ALREADY lost text to an intervening shell's
         # command substitution arrives here with the backtick/$( already gone -- there is no residue to
         # catch, which is exactly why the --stdin heredoc path above exists as the safe INPUT route rather
         # than relying on a validator. This guard cannot undo that. What it CAN do: refuse every body that
         # still carries a literal backtick or $( by the time it reaches here, unconditionally -- whether
         # that survivor is inert (single-quoted, or a quoted heredoc) or is itself a landmine for the NEXT
         # shell hop that re-embeds this text unquoted. FAIL-ONCE BOTH WAYS is the spec: a literal backtick
         # or $( always refuses, an ordinary body always still sends -- no exception for --stdin, because a
         # sender who genuinely needs literal shell-like text has no safe way to prove it arrived undamaged.
         case "$_body" in
           *'`'*|*'$('*) echo "⛔ REFUSED: message body contains a backtick or \$(. An intervening shell (yours, or whatever built this command) silently command-substitutes these in transit, so send cannot tell safe literal text from the surviving half of an already-mangled message -- it refuses on the SHAPE either way, with no bypass.
   ⛔ --stdin IS NOT AN EXEMPTION AND DELIBERATELY NEVER WAS: a literal backtick refuses on EVERY path, so
   do not reach for the heredoc to smuggle one through. Say it in words -- name the thing instead of quoting it.
   ⭐ WHAT --stdin IS FOR, WHICH IS A DIFFERENT AND BIGGER PROBLEM: it takes your shell out of the body path,
   so nothing is silently EXPANDED before this script runs. Use it for all prose:
       $0 send <to> <topic> --stdin <<'EOF'
       ...body...
       EOF
   The QUOTED delimiter is the load-bearing part -- <<'EOF' disables expansion, <<EOF does not.
   ⛔ AND KNOW WHAT THIS REFUSAL CANNOT SEE (hq_I 2026-09-13, occurrence FOUR, measured): if your shell
   ALREADY ate the backticks, the body arriving here is clean and this check passes. It answers 'does this text
   contain a backtick', never 'did this text lose a word to substitution' -- the second is undecidable here,
   because the evidence is gone before send runs. A message can arrive with a hole in it and rc=0. That is why
   the cure is a safe INPUT path, not a validator." >&2
             # ⛔ SAME RULE AS THE PROSE REFUSAL ABOVE: this one ended on a sentence of doctrine, which is no more a
             # delivery verdict than a heredoc delimiter is. hq_B's own reply to hq_I hit exactly this refusal and was
             # not delivered; the send output's last words were about validators, and the inbox was the only honest
             # witness. The verdict goes last, every time.
             echo "⛔ REFUSED — NOTHING WAS DELIVERED. Nothing was written to $to's inbox." >&2
             exit 1;;
         esac
         t="$(mktemp "$PO/.msg.XXXXXX")"; { echo "FROM $ME TO $to RE $topic"; echo "$_body"; } > "$t"
         d="$PO/$to/inbox/$(date +%s%N)-$ME-$topic.msg"
         if mv "$t" "$d" && [ -s "$d" ]; then echo "sent -> $to/$topic"; else rm -f "$t"; echo "⛔ NOT SENT -- could not write $d. The message was DROPPED; nothing was delivered." >&2; exit 1; fi;;
  ask)   [ -n "${2:-}" ] || s4e_need ask "a topic" "s4e_msg.sh ask <topic> \"your question\"" "Sends q-<topic> to the HQ named in your postoffice HQ file, and refuses rc=2 when none is set."
         topic="$2"; shift 2; _hq="$(s4e_hq)"
         [ -n "$_hq" ] || { echo "⛔ REFUSED: no owning HQ resolved for $ME. Set S4E_HQ=hq_C|hq_P|hq_B, or have your HQ write it: echo hq_C > $PO/$ME/HQ" >&2; exit 2; }
         exec "$0" send "$_hq" "q-$topic" "$*";;
  # ⛔ CLEAR DELETES ONLY WHAT CHECK DISPLAYED (hq_C s269). MEASURED, not hypothetical: a message arrived
  # between this seat's `check` and its `clear`, and the old `rm -f *.msg` destroyed it UNREAD and
  # UNRECOVERABLE -- clear does not archive, and no sent-copy is kept anywhere. The banner had even printed
  # "2 UNREAD" one line above the rm. THE LOOP's own step 1 (read -> act -> clear) makes that window a
  # certainty, not an accident: acting on a brief is exactly when a seat is slowest. So `check` now records
  # what it showed, and `clear` refuses to remove anything it did not.
  check) d="$PO/$ME/inbox"; n=$(ls "$d" 2>/dev/null | wc -l); lc="$PO/$ME/.last-check"
         echo "[$ME] inbox: $n message(s)"; : > "$lc"
         for f in "$d"/*.msg; do [ -f "$f" ] || continue; basename "$f" >> "$lc"; echo "--- $(basename "$f")"; cat "$f"; done;;
  clear) d="$PO/$ME/inbox"; lc="$PO/$ME/.last-check"
         # ⛔⭐ N-guard (ceo 2026-08-29, row s4e-clear-needs-protocol-version-guard, on hq_P's measured hole): clear gets the
         # SAME refusal next has. The archive cure at the mv below protects only clones that carry it — hq_B's stale clone
         # ran the old rm path and destroyed 5 read messages with archive/=0 — and the seats most likely to destroy mail
         # are exactly the stale ones. This guard reaches them through the shared PROTOCOL-VERSION bump: their NEXT already
         # refuses on version, forcing the pull that brings both the archive cure and this guard. INTERIM LAW (until the
         # fleet is fully on protocol >= 4): archive/ counts are NOT ground truth for what was cleared.
         if [ -f "$PO/PROTOCOL-VERSION" ]; then
           need="$(head -1 "$PO/PROTOCOL-VERSION" | tr -cd '0-9')"; need="${need:-0}"
           if [ "$S4E_PROTO" -lt "$need" ]; then
             echo "⛔ REFUSING TO CLEAR — your s4e_msg.sh is PROTOCOL $S4E_PROTO, the fleet is on $need." >&2
             echo "   A stale clone's clear can DESTROY mail (the pre-archive rm path). Nothing was touched." >&2
             echo "   Fix, then re-run:  cd \"$S4E/SCRIP\" && git pull --rebase origin main" >&2
             exit 3; fi; fi
         [ -f "$lc" ] || { echo "⛔ REFUSED: nothing has been read in this seat. Run 'check' first -- clear only removes what check displayed." >&2; exit 2; }
         _cl=0; _kept=0; _fail=0
         for f in "$d"/*.msg; do [ -f "$f" ] || continue; _b="$(basename "$f")"
           if grep -qxF "$_b" "$lc" 2>/dev/null; then
             # ⛔⭐⭐ ARCHIVE, NEVER DESTROY (hq_P 2026-08-28, seat06's witness, ceo-granted).  `.last-check` is written by
             # check's ITERATION LOOP -- one basename per file, unconditionally -- so it records what check ITERATED, never
             # what the reader actually SAW.  This line used to be `rm -f "$f"`, so ANY truncation between check's `cat` and
             # the reader (a pipe through head/tail, a pager, a context clip) destroyed the body permanently while the seat
             # believed it had read its mail.  MEASURED, not hypothetical: it destroyed a message from hq_P to seat06, and
             # one of ceo's the same morning.  ⭐ Note the ORTHOGONAL axis was already guarded -- clear refuses to delete
             # post-check arrivals (KEPT UNREAD below) -- so the arrival race was thought about; this is the other axis.
             # ⛔ AND A FAILED ARCHIVE KEEPS THE MAIL: falling back to rm would reinstate the exact defect being cured.
             if mkdir -p "$PO/$ME/archive" 2>/dev/null && mv -f "$f" "$PO/$ME/archive/$_b" 2>/dev/null; then _cl=$((_cl+1))
             else _fail=$((_fail+1)); echo "⛔ COULD NOT ARCHIVE -- MESSAGE KEPT, NOT DESTROYED: $_b"; fi
           else _kept=$((_kept+1)); echo "⛔ KEPT UNREAD (arrived after your last check): $_b"; fi; done
         rm -f "$lc"
         if [ "$_fail" -gt 0 ]; then echo "[$ME] archived $_cl, KEPT $_kept UNREAD, ⛔ $_fail COULD NOT BE ARCHIVED (still in your inbox)"; exit 1
         elif [ "$_kept" -gt 0 ]; then echo "[$ME] archived $_cl, KEPT $_kept UNREAD -- run 'check' again before you stop"; exit 1
         else echo "[$ME] inbox cleared ($_cl archived to $ME/archive/ -- a truncated read is now recoverable, not lost)"; fi;;
  # ⭐ CREATION IS A DELIBERATE ACT WITH A NAME (V2-4). LAW 6 forbids mailboxes appearing as a side effect of a
  # typo, not mailboxes existing -- Lon adds seats, and a fleet that cannot enrol one is not operable. So the
  # capability survives as ONE explicit subcommand that says what it did, and every implicit mkdir is gone.
  mailbox) [ -n "${2:-}" ] || s4e_need mailbox "a mailbox name" "s4e_msg.sh mailbox <seat>" "Prints that seat's mailbox; it reads, and never clears."
         nm="$(s4e_canon "$2")"
         case "$nm" in ""|*/*|*$'\n'*|.*) echo "⛔ REFUSED: mailbox name must be a plain slug" >&2; exit 2;; esac
         if [ -d "$PO/$nm/inbox" ]; then echo "mailbox $nm already exists"; else mkdir -p "$PO/$nm/inbox" && echo "created mailbox $nm (deliberate, by $ME)"; fi;;
  premise) # ⛔⭐ THE PREMISE FIELD IS READ THROUGH THE BUS AND NEVER BY A PRIVATE COPY (coo 2026-09-20).
         # A census that re-derives the reading rule answers a slightly NARROWER question than the gate does
         # -- multi-line? backticks? placeholder? -- and the two then disagree about which rows are covered,
         # which is the one failure a backlog count may not have. That is the four-copies-of-one-sed defect
         # lib_donewhen.sh was written to end, and this verb is how the next instrument avoids re-opening it.
         # ⛔ A PURE READER: it takes no lock, writes nothing, and is in the pid-guard's exemption list above
         # for the reason that line already gives -- a reporting verb that holds a mutation mutex makes every
         # reader a writer, and the slowest reader sets the outage window.
         case "${2:-}" in
           --census)  # batons on stdin, one path per line -> "CLASS<TAB>path"; used by util_premise_census.py
             while IFS= read -r _pb; do
               [ -n "$_pb" ] || continue
               if [ ! -f "$_pb" ]; then printf 'NOBATON\t%s\n' "$_pb"; continue; fi
               _pt="$(s4e_premise_text "$_pb")"
               if   [ -z "$_pt" ];                     then printf 'NONE\t%s\n' "$_pb"
               elif s4e_premise_is_placeholder "$_pt"; then printf 'STUB\t%s\n' "$_pb"
               elif s4e_donewhen_is_noop "$_pt";       then printf 'VACUOUS\t%s\n' "$_pb"
               elif s4e_donewhen_incomplete "$_pt";    then printf 'BROKEN\t%s\n' "$_pb"
               else                                         printf 'OK\t%s\n' "$_pb"; fi
             done; exit 0;;
           '') printf 'usage: %s premise <topic>    print the row PREMISE-WHEN exactly as claim/next will run it\n' "$0" >&2
               printf '       %s premise --census   classify batons read from stdin (one path per line)\n' "$0" >&2; exit 2;;
           *) topic="$2"; b="$PO/tasks/$topic.task.md"
              [ -f "$b" ] || { printf '⛔ REFUSED (rc=2): no baton at %s -- nothing to read.\n' "$b" >&2; exit 2; }
              pw="$(s4e_premise_text "$b")"
              if [ -z "$pw" ]; then
                printf '⛔ %s carries NO PREMISE-WHEN, so `claim` and `next` dispatch it with its premise UNCHECKED.\n' "$topic" >&2
                printf '   Write the one cheap command that proves this row is still built on something true:\n' >&2
                printf '       PREMISE-WHEN: <command>   in %s\n' "$b" >&2; exit 1; fi
              printf '%s\n' "$pw"; exit 0;;
         esac;;
  claim) [ -n "${2:-}" ] || s4e_need claim "a topic" "s4e_msg.sh claim <topic>" "Takes a row deliberately. Use \`next\` to be served one; this verb is for a row you have chosen by name."
         topic="$2"; c="$PO/claims/$topic.claim"; mkdir -p "$PO/claims"
         # ⭐ AN ASSIGNED ROW ITS OWNER CLAIMS BY NAME IS STARTED, THE SAME MARK `next` WRITES WHEN IT SERVES ONE (the coo 2026-09-27, ceo
         # CEO-1306): PASS 1 appends RUNNING as it serves ASSIGNED->RUNNING, but `claim` on the same row said "already yours" and wrote
         # nothing, so an owner who took an assigned row by name left no trace a sweep could read -- util_queue_visibility_census.py's
         # BLOCKING-RED PAST WINDOW counts an assignment alone as NOT started. Once, with the bus notice, never twice.
         if [ -f "$c" ]; then own="$(head -1 "$c")"; if [ "$own" = "$ME" ]; then echo "already yours"
              if grep -q '^ASSIGNED-BY ' "$c" && ! grep -qx 'RUNNING' "$c" && ! grep -qx 'DONE' "$c"; then echo "RUNNING" >> "$c"; s4e_announce_claim "$topic"; fi
            else echo "CLAIMED by $own — pick other work"; exit 1; fi
         else
              # ⛔⭐ THE PREMISE GATE RUNS HERE: BEFORE THE LOCK EXISTS, AND ONLY ON THE PATH THAT TAKES ONE.
              # BEFORE, because "refuses the lock" is the whole deliverable -- a row nobody can usefully work is
              # worse HELD than free, and a refusal after the claim is written is not a refusal, it is a cleanup
              # problem (the same reasoning `mint` uses to hoist its criterion lint above the queue write).
              # ⛔ ONLY ON THIS PATH: "already yours" and "CLAIMED by someone else" are unchanged, because
              # neither takes a lock -- re-running a premise against a lock that already exists would refuse a
              # seat access to its OWN running row, which is eviction wearing a verification.
              # ⭐ AND HERE RATHER THAN IN EACH VERB, for the reason this file already gives twice on this very
              # line (the queue-column write, hq_B; the claim announcement, CEO-1002): `next` reaches its lock by
              # running `$0 claim`, so one wiring covers the picker, the deliberate claim and any future verb that
              # claims through the primitive instead of re-implementing it. A cure that enumerates its acquiring
              # verbs silently reopens the first time a new one is minted.
              # ⛔ `assign` IS DELIBERATELY NOT GATED: an HQ writes the seat's claim on the HQ's own tree, which
              # is not the tree the work will happen on, so a premise measured there answers about the wrong
              # machine. The ASSIGNED row is gated at SERVE time instead, in PASS 1 of `next`, on the seat's tree.
              # ⛔ A CLAIM LOCKS A ROW, SO A TOPIC WITH NO QUEUE.tsv ROW IS REFUSED rc 2 BEFORE ANY LOCK (coo 2026-10-14:
              # hq_templates claimed zzz-nonexistent-row, the bus wrote claims/zzz-nonexistent-row.claim and announced it
              # fleet-wide, and s4e_set_row_state's no-op on a rowless topic was swallowed by its `|| true` below).
              [ -n "$(qrow "$topic")" ] || { echo "⛔ REFUSED (rc 2): no QUEUE.tsv row is named $topic -- a claim locks a row and there is none to lock; nothing written, nothing announced. Claim the row's exact topic, or ask the ceo to mint it."; exit 2; }
              s4e_premise_gate "$topic" claim || exit 1
              t="$(mktemp "$PO/claims/.c.XXXXXX")"; echo "$ME" > "$t"
              if ln "$t" "$c" 2>/dev/null; then rm -f "$t"
                # ⭐ picker-dependency-and-boomerang-blindness CURE 2: an explicit claim IS the "another seat
                # touched it" event that ends the boomerang cooldown early. Cleared unconditionally, including
                # for the releaser's own deliberate re-claim — `claim` is a chosen act, `next` is a serve, and
                # the guard exists only to stop the SERVE. Never let this cure outlive a human decision.
                s4e_release_clear "$topic"
                # ⭐ queue-column-unwritten-by-acquiring-verbs (hq_B 2026-08-29, on hq_P's queue-wide audit).
                # THE COLUMN LEARNED ABOUT ENDINGS AND NEVER ABOUT BEGINNINGS: park, done and unclaim all wrote it,
                # while claim, `next` and assign -- every verb that TAKES a lock -- wrote only the claim file. Measured
                # before the cure: of 16 rows holding a live claim, 15 read FREE. That is not a column three verbs
                # forgot, it is a column no ACQUIRING verb ever wrote. Enforcing it HERE and not per-verb is hq_P's
                # sharpening and is the load-bearing part: `next` reaches its lock through this line (so does the
                # dependency-inversion promo), so one write covers the primary dispatch path and any future verb that
                # claims through the primitive instead of re-implementing it.
                # ⛔ COLUMN 3 IS DELIBERATELY NOT TOUCHED. serve() prints it as "owner", but on the live queue it
                # carries an HQ on rows a SEAT holds (corpus-crosscheck-probe-total-conversion: col3 hq_B, claim
                # seat12) -- which reads as umbrella-HQ + working-seat, not as drift. Writing the claimant there
                # would destroy that, so col3 stays a question routed to hq_P/ceo, not a field this cure assumes.
                # ⭐ REMEMBER A RESTRICTION BEFORE OVERWRITING IT. The column must still learn about beginnings
                # (hq_B's cure: 15 of 16 claimed rows read FREE before it), so a claimed RESTRICTED row still reads
                # CLAIMED:<x> -- but unclaim would then have no way to know the row was ever restricted, and would
                # correctly-but-destructively drive it to FREE. The claim file is the natural place: it already
                # carries the owner and the DONE/OVERRIDE-BY receipts, it is deleted with the lock, and it cannot
                # outlive the episode it describes. ⛔ ONLY RESTRICTED is remembered: an ASSIGNED dispatch really is
                # spent on release and must NOT be restored (that is ceo's 2026-08-28 ruling, still governing).
                { _pre="$(s4e_row_state "$topic")"; if s4e_restricted_to "$_pre" >/dev/null; then printf 'PRIOR-STATE %s\n' "$_pre" >> "$c"; fi; }
                s4e_set_row_state "$topic" "CLAIMED:$ME" || true
                echo "claimed $topic"
                # ⛔⭐ THE ANNOUNCEMENT IS PART OF TAKING THE ROW (ceo CEO-1002). `next` reaches its lock through this
                # very line (it runs `$0 claim`), so wiring it HERE covers the picker and the deliberate claim both --
                # the same reasoning hq_P used to put the queue-column write here rather than in each verb.
                s4e_announce_claim "$topic"
                else rm -f "$t"; echo "RACE LOST: $(head -1 "$c" 2>/dev/null) owns it"; exit 1; fi; fi;;
  unclaim) # ⭐ s265 — RELEASE AN UNWORKED CLAIM. Minted because THREE seats hit its absence in one day (seat08,
         # seat09, seat13): a stale-clone picker mis-locked a row, the seat correctly refused to work it, and then had
         # NO WAY TO PUT IT BACK. `done` was the only exit and `done` is COMPUTED — closing a row you never worked
         # would have to defeat the DONE-WHEN gate, which is the false-green trap the gate exists to stop. So seats
         # held locks on rows they were not working, and a claimed row hides itself from the picker: one stale clone
         # silently removed a row from the whole fleet's reach. ⛔ REFUSES a claim that is DONE (that is a receipt, not
         # a lock) and one you do not own. The release is APPENDED to the baton's LEDGER, so a lock that was taken and
         # returned leaves a trace instead of vanishing.
         [ -n "${2:-}" ] || s4e_need unclaim "a topic" "s4e_msg.sh unclaim <topic>" "Returns a held row FREE with a receipt under released/. It is the stand-down verb, and the only exit from a row you have not worked."
         topic="$2"; c="$PO/claims/$topic.claim"; q="$PO/QUEUE.tsv"
         [ -f "$c" ] || { echo "no claim on $topic — nothing to release"; exit 1; }
         own="$(head -1 "$c")"
         # ⛔ s272 hq_C — THE CODE CONTRADICTED ITS OWN MESSAGE. The header above and this very string both said "or by
         # an HQ", and the test was a bare $own = $ME, so NO HQ could ever release anything. That is not cosmetic: in
         # FLEET-12 the seats that hold the stalest locks are seat13..seat16, which DO NOT EXIST in this mode and can
         # never come back to release their own claims. 9 rows were hidden from the picker by seats that are not
         # running, with no in-tool way to free them short of rm. An HQ release is ANNOTATED with who forced it.
         if [ "$own" != "$ME" ]; then
             s4e_is_hq "$ME" || { echo "⛔ $topic is claimed by $own, not you — a lock is released by its holder or by an HQ"; exit 1; }
             why="${3:-released by HQ}"; why="$why (forced by $ME over $own's claim)"
         fi
         # ⛔⭐ A COMPUTED DONE AND AN OVERRIDE DONE ARE NOT THE SAME THING, AND UNTIL 2026-08-27 THIS LINE COULD NOT
         # TELL THEM APART (hq_C, as queue custodian, on a ceo audit ask). `done` at :288 appends the SAME bare `DONE`
         # token on BOTH paths -- the DONE-WHEN-passed path and the S4E_DONE_OVERRIDE path -- so a seat who overrode
         # with the reason "Session-boundary pause, not task completion" left a claim indistinguishable from a genuine
         # computed receipt. This refusal then made it PERMANENT: corpus-suites-consolidation, a genuinely open row,
         # was invisible to the picker from 2026-08-24 to 2026-08-27 because the only tool that could free it refused
         # on a token that did not mean what it read as. ⭐ SAME SHAPE AS THE OTHER INSTRUMENTS THIS WEEK: two distinct
         # states collapsing into one indistinguishable output (PASS(0) = "checked, clean" or "never asked"; rc=2 =
         # "work unfinished" or "binary missing"). ⛔ THE RATIONALE IN THE HEADER IS "that is a RECEIPT, not a lock" --
         # and an OVERRIDE done is precisely NOT a receipt: nothing was computed, a human asserted it. So it is
         # releasable, loudly and with a trace. A bare computed DONE still refuses, unchanged.
         if grep -q '^DONE$' "$c"; then
           if grep -q '^OVERRIDE-BY ' "$c"; then
             echo "⚠ $topic is DONE by OVERRIDE, not by a computed DONE-WHEN — releasing (an override is an assertion, not a receipt)."
             sed -n 's/^OVERRIDE-BY /    original override: /p' "$c" | head -1 | cut -c1-200
           else
             echo "⛔ $topic is DONE — that claim is a receipt, not a lock. Leave it."; exit 1
           fi
         fi
         why="${why:-${3:-released unworked}}"
         # ⭐ unclaim-leaves-row-invisible-column-not-freed (ceo, 2026-08-28, on hq_P's icon-n2 measurement) —
         # unclaim removed only the claim FILE and never touched QUEUE.tsv's state column, so a released row
         # stayed ASSIGNED/ASSIGNED:<seat> and next()'s PASS 3 (which serves only FREE|'') never saw it again —
         # the exact "half the hiding" this case's own header already named. Mirrors `park`'s write, same awk
         # shape. The column is always driven to FREE, even over an ASSIGNED-BY state: an assignment is spent
         # the instant its lock is released, never restored to what the assigner intended (ruling: back to FREE).
         # A row whose column already reads FREE is simply rewritten FREE -> FREE: a no-op, not an error.
         # ⭐ WAS A SECOND, INLINE COPY of the awk in s4e_set_row_state -- the exact "second, subtly-different
         # rewriter" that function's own header says it was factored out to prevent, grown back four lines below it.
         # Identical behaviour (col4 -> FREE), now through the one writer, so it inherits the lock instead of racing.
         # ⭐ A RESTRICTION IS NOT SPENT BY LETTING GO OF THE LOCK -- restore it rather than freeing the row.
         # Everything else still goes to FREE, unchanged: ceo's 2026-08-28 ruling governs DISPATCH and is untouched.
         # ⭐ unclaim-clobbers-a-park-written-around-the-claim-so-next-serves-a-superseded-row (ceo MEASURED 2026-09-02 ~14:55,
         # cured hq_B the same day): ceo force-parked AROUND hq_B's live claim (S4E_PARK_FORCE=1 -> SUPERSEDED:folded-into-...),
         # hq_B's unclaim then drove the column to FREE by the unconditional write below, erasing the park, and ceo's own
         # `next` LOCKED the resurrected rank-0 superseded row as topmost work -- twice, because the second unclaim did it
         # again. ⛔ A PARK WRITTEN AROUND A CLAIM IS NOT SPENT BY THE CLAIM'S RELEASE. The 2026-08-28 "always FREE" ruling
         # governs DISPATCH of the CLAIM-SHAPED states only -- CLAIMED:<seat>, ASSIGNED, ASSIGNED:<seat>, FREE, empty -- and is
         # untouched for them. Any other column value (SUPERSEDED*, BLOCKED-ON:*, PARKED-AWAITING:*, PARKED*, RETIRED,
         # GRANT-NEEDED*, RESTRICTED:*) is a park somebody wrote deliberately around the lock: it is KEPT and the receipt
         # names it. Gate: test_gate_s4e_unclaim_keeps_park.sh (both arms, throwaway postoffice, fail-once on a mutated copy).
         { _rst="$(grep -m1 '^PRIOR-STATE ' "$c" 2>/dev/null | sed 's/^PRIOR-STATE //')"; _cur="$(s4e_row_state "$topic")"; _kept=""
           case "$_cur" in
             CLAIMED:*|ASSIGNED|ASSIGNED:*|FREE|"")
               if [ -n "$_rst" ] && s4e_restricted_to "$_rst" >/dev/null; then s4e_set_row_state "$topic" "$_rst" || true
               else s4e_set_row_state "$topic" "FREE" || true; fi;;
             *) _kept="$_cur"; echo "⭐ QUEUE.tsv column KEPT as '$_cur' — a park written around this claim survives its release (only a claim-shaped column is driven to FREE)";;
           esac
           [ -z "$_kept" ] || why="$why (QUEUE.tsv column kept as $_kept)"; }
         b="$PO/tasks/$topic.task.md"
         # release-verbs-refuse-on-unfolded-authority-mail: MUST run before anything below touches the
         # baton's own mtime -- the guard's whole signal is "was the baton written since the mail
         # arrived", so checking it after this verb's own RELEASED-line append would always see a
         # freshly-touched file and could never fire. WARN, never block (a stranded seat is worse than
         # a stale flag) -- but write the pointer INTO the baton, since a message in this terminal is
         # exactly what already failed to reach the artifact twice before.
         if s4e_unfolded_authority_mail "$ME" "$topic"; then
             echo "⚠ authority mail arrived after this claim was taken and the baton was not touched since -- appended a pointer to it, re-read before trusting this row's own NEXT block" >&2
             s4e_release_guard_note "$topic" unclaim "$ME"
         fi
         [ -f "$b" ] && printf '\n- %s **RELEASED** by %s — %s (claim removed; row returns to the picker)\n' "$(date -u +%Y-%m-%dT%H:%MZ)" "$ME" "$why" >> "$b"
         s4e_mark_row "$topic" RELEASED
         # ⭐ picker-dependency-and-boomerang-blindness CURE 2 — leave a RECEIPT so the picker can tell "this row
         # is free" from "this row is free BECAUSE I just let it go". Written after every refusal above has been
         # passed, so a REFUSED unclaim leaves no receipt and cannot hide a row from anyone.
         s4e_release_receipt "$topic"
         rm -f "$c"; echo "released $topic — $why";;
  park)  # ⭐ s265 — TAKE A ROW OUT OF THE PICKER WITHOUT CLOSING IT. Minted with `unclaim`, same day, same cause:
         # `161-o2-red` was PARKED BY LON at s258 and its baton said so, yet QUEUE.tsv still carried it as rank-0 FREE,
         # so the rank-sorted picker served it as the TOPMOST work in the fleet. seat08 read the ruling, refused it,
         # and then had to SIT ON THE CLAIM to stop the next idle seat being handed the same parked row. ⛔ The state
         # column was decorative — 94 of 94 rows read FREE and nothing consulted it. `park` writes it and PASS 3 now
         # obeys it, so a ruling recorded in a baton is finally enforced by the dispatcher instead of by a seat's
         # goodwill. Un-park with: park <topic> FREE.
         # ⭐ picker-skips-blocked-rows: `park <topic> BLOCKED-ON:<other-topic>` (or PARKED-AWAITING:<other-topic>,
         # the pre-existing spelling several rows already use) is not just cosmetic prose — next()'s PASS 3 parses
         # it and un-parks the row back to FREE BY ITSELF the moment <other-topic>'s claim goes DONE (or it is
         # swept into QUEUE.done.tsv). Recording a block this way, not as bare PARKED/BLOCKED text, is what makes
         # it self-clearing instead of needing a human to remember to come back and re-park it.
         [ -n "${2:-}" ] || s4e_need park "a topic" "s4e_msg.sh park <topic> [STATE]" "Takes a row out of the picker WITHOUT closing it (default state PARKED; park <topic> FREE puts it back). It has no no-argument listing -- \`board\` is the verb that prints the board."
         topic="$2"; st="${3:-PARKED}"; q="$PO/QUEUE.tsv"
         # ⛔⭐ ARG 3 IS THE STATE, NOT A REASON — AND IT USED TO ACCEPT ANY STRING AT ALL (hq_P, 2026-08-29,
         # reported against themselves). They ran `park <topic> "<a whole explanatory sentence>"` on the natural
         # assumption that the third argument was a reason, and the entire sentence — commas and all — was written
         # verbatim into QUEUE.tsv's load-bearing state column. They caught it on the verify line inside a minute,
         # so no harm; but the shape is the point. ⛔ THE NEAR MISS IS THE REAL FINDING: their prose happened to
         # contain no TAB. One that did would have SPLIT THE ROW and broken the TSV for every reader, not merely
         # uglified one cell — and a torn row in an unversioned file 16 seats dispatch from has no undo.
         # ⭐ AND AN UNVALIDATED STATE FAILS TOWARD INVISIBILITY: PASS 3 serves only FREE|'', so ANY typo — a
         # reason, a misspelling, a stray quote — silently removes the row from the picker while looking like a
         # deliberate park. The vocabulary below is the MEASURED one (every distinct value live in QUEUE.tsv),
         # not an invented one, plus CLAIMED: which the claim primitive now writes.
         case "$st" in
           *$'\t'*|*$'\n'*) printf '⛔ REFUSED: a state may not contain a tab or newline — that would TEAR the QUEUE.tsv row, not just mis-set it.\n' >&2; exit 2;;
         esac
         case "$st" in
           FREE|PARKED|BLOCKED|ASSIGNED|DONE|SUPERSEDED|RETIRED|GRANT-NEEDED|PARKED-LON-HOLD) : ;;
           PARKED-AWAITING:?*|BLOCKED-ON:?*|ASSIGNED:?*|CLAIMED:?*|RESTRICTED:?*|DONE:?*|SUPERSEDED:?*|GRANT-NEEDED:?*|PARKED-UMBRELLA:?*|PARKED-LON-HOLD:?*) : ;;
           *) printf '⛔ REFUSED: "%s" is not a state. ARG 3 IS THE STATE COLUMN, NOT A REASON — that is the mistake this guard exists for.\n' "$st" >&2
              printf '   Accepted: FREE PARKED BLOCKED ASSIGNED DONE SUPERSEDED RETIRED GRANT-NEEDED PARKED-LON-HOLD\n' >&2
              printf '             PARKED-AWAITING:<topic>  BLOCKED-ON:<topic>  ASSIGNED:<seat>  CLAIMED:<seat>\n' >&2
              printf '             RESTRICTED:<seat>   (only <seat> may ever work it; survives unclaim -- for CEO-19 HQ-only rows)\n' >&2
              printf '             DONE:<why>  SUPERSEDED:<why>  GRANT-NEEDED:<why>  PARKED-UMBRELLA:<why>\n' >&2
              printf '   ⭐ Put the REASON in the baton (%s/tasks/%s.task.md) — the queue is an INDEX, not a brief store.\n' "$PO" "$topic" >&2
              printf '   ⭐ To make a park SELF-CLEARING, spell it PARKED-AWAITING:<blocker> or BLOCKED-ON:<blocker>;\n' >&2
              printf '      next() re-asks whether that blocker is DONE and un-parks this row by itself.\n' >&2
              exit 2;;
         esac
         grep -qP "^[0-9]+\t\Q$topic\E\t" "$q" || { echo "⛔ no QUEUE.tsv row named $topic"; exit 1; }
         # ⛔⭐ picker-dangling-blocker-parks-a-row-forever-in-silence (hq_B mint, cured here). A BLOCKED-ON:/
         # PARKED-AWAITING: value naming a topic with NO row (live or swept-done) can never self-clear: the
         # promotion walk's own dangling branch ("no row exists to serve") and the self-heal check
         # (s4e_blocker_done, which needs a claim/QUEUE.done.tsv hit) both just silently return false forever
         # for a name nothing ever refers to. MEASURED (hq_B, queue-wide sweep): pz4 parked behind
         # "icon-n2-generator-activation-frames-items-3-4" — a sub-item gloss appended to a real row name,
         # itself not a row — with 3 more rows parked behind pz4, all silently permanent. Refuse the bad
         # state before it can be written, the same way `s4e_assert_box` refuses an invented mailbox instead
         # of creating one on the fly (LAW 6, same failure shape: an invented identity that silently succeeds).
         case "$st" in
           BLOCKED-ON:*|PARKED-AWAITING:*)
             _blk="${st#*:}"
             if [ -z "$(qrow "$_blk")" ] && ! s4e_blocker_done "$_blk"; then
               printf '\n⛔⛔⛔ REFUSED: %s names blocker "%s", which has no QUEUE.tsv row (live or swept-done) ⛔⛔⛔\n' "$st" "$_blk" >&2
               printf '    This state can never self-clear — s4e_blocker_done has nothing to ever find true for a\n' >&2
               printf '    name that is not a real row, so the block would be PERMANENT and SILENT.\n' >&2
               printf '    If you meant a SUB-ITEM of an existing row, name the ROW itself here and put the\n' >&2
               printf '    sub-item detail in the baton prose (## NEXT), not in the state string.\n' >&2
               printf '    If the blocker genuinely does not exist yet: mint it first (s4e_msg.sh mint).\n\n' >&2
               exit 2
             fi ;;
         esac
         # ⭐ s4e-park-adds-a-blocker-and-refuses-an-unresolvable-topic — A RE-PARK ADDS A BLOCKER, IT DOES NOT
         # REPLACE ONE. seat11's correct park (BLOCKED-ON:calling-convention-depth-tracked, the row that actually
         # cured it) was overwritten twice by later re-parks recording a DIFFERENT hypothesis, so when the true
         # blocker landed DONE nothing was left naming it and the row could not self-clear — eight seats released
         # it unworked. If this row is ALREADY BLOCKED-ON:/PARKED-AWAITING: something and the new state is ALSO
         # one of those, merge the new blocker into the existing '+'-joined set (deduped) instead of overwriting
         # it — the row then self-clears the moment ANY recorded blocker resolves (next()'s PASS 3), which is
         # sound: each '+' member is a real, independently-plausible reason, and one of them being true is
         # enough to re-open dispatch, exactly the case a wrong re-park used to erase.
         case "$st" in
           BLOCKED-ON:*|PARKED-AWAITING:*)
             _cur_st="$(s4e_row_state "$topic")"
             case "$_cur_st" in
               BLOCKED-ON:*|PARKED-AWAITING:*)
                 _old="${_cur_st#*:}"; _new="${st#*:}"
                 _dup=0; _save_IFS="$IFS"; IFS='+'
                 for _b in $_old; do [ "$_b" = "$_new" ] && _dup=1; done
                 IFS="$_save_IFS"
                 if [ "$_dup" = 0 ]; then st="BLOCKED-ON:${_old}+${_new}"; else st="BLOCKED-ON:${_old}"; fi
                 echo "  (additive park: was $_cur_st, now $st)"
                 ;;
             esac ;;
         esac
         # ⛔ s266 — PARK MUST NOT DESTROY ANOTHER SEAT'S RUNNING CLAIM. hq_C parked rung-E5-suspend-cache as
         # SUPERSEDED while seat13 was mid-flight on it; the rm below deleted their claim, so their computed `done`
         # said "not your claim" AFTER the fix was already landed and pushed. A park is a routing verdict on a ROW;
         # it has no authority over a claim it does not hold. Now: a live claim held by someone else REFUSES the
         # park (like assign); S4E_PARK_FORCE=1 overrides but ANNOTATES the claim instead of deleting it, so the
         # holder's `done` still works.
         c="$PO/claims/$topic.claim"
         if [ -f "$c" ] && ! grep -q '^DONE$' "$c" && [ "$(head -1 "$c")" != "$ME" ]; then
             hold="$(head -1 "$c")"
             if [ "${S4E_PARK_FORCE:-0}" != "1" ]; then echo "⛔ REFUSED: $topic is claimed RUNNING by $hold — a park is not an eviction. Ask them, or S4E_PARK_FORCE=1 to park AROUND the claim (it is preserved)."; exit 1; fi
             printf 'PARKED-AROUND by %s %s (claim preserved; holder done still works)\n' "$ME" "$(date -u +%Y-%m-%dT%H:%MZ)" >> "$c"; echo "  (claim held by $hold PRESERVED — parked around it)"
         elif [ -f "$c" ] && ! grep -q '^DONE$' "$c" ; then
             # release-verbs-refuse-on-unfolded-authority-mail: check BEFORE the claim (and its timestamp)
             # is removed below. WARN, never block, same reasoning as unclaim's own wiring.
             if s4e_unfolded_authority_mail "$ME" "$topic"; then
                 echo "⚠ authority mail arrived after this claim was taken and the baton was not touched since -- appended a pointer to it, re-read before trusting this row's own NEXT block" >&2
                 s4e_release_guard_note "$topic" park "$ME"
             fi
             rm -f "$c"; echo "  (cleared my own holding claim — the state column carries this now, not a lock)"
             # ⛔ park-does-not-write-last-row-so-banner-misattributes-the-session (seat07 2026-09-01, cured hq_B same day).
             # s4e_mark_row was called from exactly two closing verbs, unclaim and done; park ALSO closes a row (it just
             # cleared the claim above) but was minted later and never joined that enumeration, so a session that ended
             # by parking got a Stop banner attributing it to whatever row this seat last RELEASED or DONE'd -- days old,
             # cumulative commit count and all. Measured live by seat07 (pass 39) and reproducible: park as the last act,
             # then banner. ⭐ THE CLASS, in seat07's words, is that "a cure that enumerates its closing verbs silently
             # reopens every time a new closing verb is minted" -- so if you add a verb that removes a claim file, it
             # must call s4e_mark_row too, and the durable shape is one s4e_close_claim writer that does both.
             s4e_mark_row "$topic" PARKED
         fi
         # ⭐ picker-dependency-and-boomerang-blindness CURE 3 — A GOVERNANCE GATE IS NOT LIFTED BY `park FREE`.
         # An ordinary park is routing and anyone may lift it. A GRANT-NEEDED/PARKED-LON-HOLD row waits on a
         # grant only Lon can give, and `perf-nv-set-fn-o0-overhead` proves what happens when the two are the
         # same verb: the row goes back to FREE, the picker serves it, and the next seat re-pays the discovery
         # cost against a wall that has not moved. The gate is lifted by the grant ARRIVING, so lifting it
         # REQUIRES NAMING THE GRANT — S4E_GRANT_BY is recorded into the baton, which is what makes the lift
         # auditable instead of a keystroke. ⛔ Moving BETWEEN grant-wait spellings is not a lift and is allowed.
         cur_st="$(s4e_row_state "$topic")"
         if s4e_is_grant_wait "$cur_st" && ! s4e_is_grant_wait "$st"; then
           if [ -z "${S4E_GRANT_BY:-}" ]; then
             printf '⛔ REFUSED: %s is GOVERNANCE-GATED (%s) — it waits on a GRANT, not on work.\n' "$topic" "$cur_st" >&2
             printf '   `park <topic> FREE` lifts an ordinary park. A grant-wait is lifted only when the grant ARRIVES,\n' >&2
             printf '   and whoever lifts it must say whose word lifted it (RULES.md: you are the only witness to what Lon told you):\n' >&2
             printf '     S4E_GRANT_BY="Lon, in-chat 2026-08-28" bash %s park %s %s\n' "$0" "$topic" "$st" >&2
             exit 1
           fi
           printf '⭐ GRANT RECORDED for %s (was %s) — granted by: %s\n' "$topic" "$cur_st" "$S4E_GRANT_BY"
           _gb="$PO/tasks/$topic.task.md"
           [ -f "$_gb" ] && printf '\n- %s **GOVERNANCE GATE LIFTED** by %s — gate was `%s`; grant: %s\n' "$(date -u +%Y-%m-%dT%H:%MZ)" "$ME" "$cur_st" "$S4E_GRANT_BY" >> "$_gb"
         fi
         s4e_set_row_state "$topic" "$st"
         b="$PO/tasks/$topic.task.md"
         [ -f "$b" ] && printf '\n- %s **STATE -> %s** by %s\n' "$(date -u +%Y-%m-%dT%H:%MZ)" "$st" "$ME" >> "$b"
         echo "$topic state -> $st";;
  done)  [ -n "${2:-}" ] || s4e_need done "a topic" "s4e_msg.sh done <topic>" "Closes a row by RUNNING its baton DONE-WHEN; it refuses on a red or an rc=2. Completion is computed, never declared."
         topic="$2"; c="$PO/claims/$topic.claim"
         # ⛔ THE BANNER FIRES ITSELF HERE (HQ 2026-08-22, after seat4 finished its row and gave NO banner until Lon
         # asked for one). LAW 15 lived only as a step in the seat's CLAUDE.md -- and a step in a markdown file is a
         # hope, not a mechanism, exactly like the inbox before `check` was forced. A seat that closes a row runs
         # `done`, so `done` prints the banner. Same reason `board` does. Suppress with S4E_NO_BANNER=1.
         if [ -f "$c" ] && [ "$(head -1 "$c")" = "$ME" ]; then
              # ⛔⭐⭐ ROWD-CLOSE GUARD -- fires for BOTH the computed close and the S4E_DONE_OVERRIDE close, because it
              # sits ABOVE the fork. An override is an assertion by a human; it still may not red twelve other seats.
              if _cite="$(s4e_manifest_rowd_cite "$topic")"; then
                printf '⛔ REFUSED: "%s" is cited as ROWD evidence in the corpus coverage manifest, so closing it REDS\n' "$topic" >&2
                printf '   `make test` FOR EVERY SEAT until the manifest is re-pointed by hand. This has happened THREE times in one day.\n' >&2
                printf '   The citing line (harness/scripts/corpus_coverage_manifest.tsv):\n       %s\n' "$_cite" >&2
                printf '   HAND OFF FIRST, then close -- in the SCRIP checkout, one of:\n' >&2
                printf '     (a) re-point the ROWD topic to a LIVE successor row that still covers that subtree, or\n' >&2
                printf '     (b) flip the subtree to GATED and name the harness script that now proves it.\n' >&2
                printf '   Commit and push that edit BEFORE re-running done.\n' >&2
                printf '   ⛔ THE MANIFEST LIVES IN SCRIP, NOT THE POSTOFFICE: this check reads YOUR checkout, so a stale\n' >&2
                printf '      clone reads a stale manifest. `git pull --rebase` in SCRIP before you close, or this guard\n' >&2
                printf '      can pass on a manifest that no longer matches origin.\n' >&2
                exit 1; fi
              # ⛔⭐⭐ DONE IS COMPUTED, NEVER DECLARED (ARCH-FLEET-CEO.md LAW 1 "NO HAND-TYPED VERDICTS", γ port).
              # Until now `done` appended the DONE marker UNCONDITIONALLY and never ran the task's DONE-WHEN --
              # so the one command whose entire job is to certify completion accepted the seat's word for it.
              # That is the exact shape of the v1 free-r10 inversion (an HQ ruling DONE on prose), sitting inside
              # the control plane written to forbid it. A law the tooling does not enforce is a hope.
              tf="$PO/tasks/$topic.task.md"
              if [ -f "$tf" ]; then
                dw="$(s4e_donewhen_text "$tf")"
                # ⛔⭐⭐ A MARKDOWN-STYLED DONE-WHEN WAS BEING RUN AS COMMAND SUBSTITUTION (seat06, 2026-08-28; FINDING
                # be4b2257). A criterion authored as `DONE-WHEN: \`bash ../harness/scripts/gate.sh\`` -- backticks meant as CODE
                # STYLING, because this line lives in a MARKDOWN file -- reaches `bash -c "$dw"` as live substitution:
                # bash runs the gate, captures its stdout, and then EXECUTES THAT STDOUT AS A COMMAND. A gate printing
                # "GATE OK -- ..." on success dies `GATE: command not found`, rc=127, and the row cannot be closed.
                # ⛔ IT EXECUTES THE OUTPUT, so this is not merely a wrong exit code -- whatever a gate prints is fed
                # to a shell. ⭐ MEASURED BLAST RADIUS: 5 of 411 live task files carry a wrapped DONE-WHEN today.
                # ⭐ The SILENT case is SAFE and that was checked, not assumed: bash gives a command consisting only of
                # a substitution the SUBSTITUTION's exit status, so `\`false\`` still exits 1 -- no false green. The
                # defect is confined to criteria whose command prints on its success path.
                # ⭐ NORMALISED HERE, AT THE ONE EXTRACTION POINT, so the vacuity probe and the real run cannot disagree
                # about what the criterion IS -- two consumers reading one value, never two copies to drift.
                # ⛔ ONE matched OUTER pair only, and never a one-sided backtick: a lone ` is either real substitution
                # or a typo, and both must fail LOUDLY rather than be silently rewritten. Announced, never silent.
                [ -n "${_dw_backticked:-}" ] && printf '⚠ DONE-WHEN was wrapped in markdown backticks; stripped one matched pair before running.\n   Running: %s\n' "$dw" >&2
                if [ -z "$dw" ]; then
                  echo "⛔ REFUSED: $tf has no DONE-WHEN: line. A task with no computable completion test cannot be closed." >&2; exit 1; fi
                # ⛔⭐ REFUSE rc=2 ON AN UNTERMINATED HEREDOC -- the second, independent guard on the truncation
                # class (see s4e_donewhen_unterminated_heredoc). A criterion bash cannot finish reading is one
                # bash will happily run to a ZERO exit having executed nothing, so it must never reach the run.
                if s4e_donewhen_multiple_contracts "$tf"; then
                  printf '⛔ REFUSED(2): %s carries a SECOND column-0 DONE-WHEN: at line(s) %s.\n' "$tf" "$_dwm_lines" >&2
                  printf '   Only the FIRST has ever been executed, so closing here would certify half the contract while\n' >&2
                  printf '   the other half sits in the file where every human reader counts it as part of the bar.\n' >&2
                  printf '   Hoist the real criterion to the one DONE-WHEN: line, or relabel the other.\n' >&2
                  exit 2; fi
                if s4e_donewhen_unterminated_heredoc "$dw"; then
                  printf '⛔ REFUSED(2): %s\n' "$tf" >&2
                  printf '   Its DONE-WHEN opens a heredoc it never closes. bash does not fail on that -- it warns,\n' >&2
                  printf '   treats the body as EMPTY, and exits 0 having run nothing, so closing on it would certify\n' >&2
                  printf '   a criterion that never executed. Fix the criterion (close the delimiter, or move the\n' >&2
                  printf '   witness into a script file) before closing this row.\n' >&2
                  exit 2; fi
                # ⛔⭐ HIDDEN-CRITERION GUARD (seat13, row fifty-seven-batons-are-unclosable-because-their-
                # criterion-is-not-at-column-zero): mirrors s4e_dispatch_probe's check exactly -- two
                # consumers of one rule, never two copies to drift. See s4e_donewhen_is_placeholder /
                # s4e_donewhen_hidden_elsewhere above for the measured cause and the exact shapes.
                if s4e_donewhen_is_placeholder "$dw" && s4e_donewhen_hidden_elsewhere "$tf"; then
                  printf '⛔ REFUSED (rc=2): %s column-0 DONE-WHEN is still a placeholder, but another DONE-WHEN:-labeled\n' "$tf" >&2
                  printf '   line sits elsewhere in the same file -- the tool can never see it, so this row could stay open\n' >&2
                  printf '   forever even if that work is finished. Never guessed which one is the contract.\n' >&2
                  printf '   column 0  : %s\n' "$dw" >&2
                  printf '%s\n' "$_dhe_lines" | sed 's/^/   elsewhere : /' >&2
                  printf '   Fix: hoist the real criterion to column 0 (verified by RUNNING it, never by moving text), or\n' >&2
                  printf '   relabel the other line (e.g. "ACCEPTANCE, IN PROSE:") if it is not really a second candidate.\n' >&2
                  exit 2
                fi
                # ⛔⭐ A DONE-WHEN MUST EXAMINE SOMETHING (hq_P found this by source-reading the previous version).
                # The old code accepted ANY non-empty string and ANY exit 0 as proof, so `DONE-WHEN: true` — or `:`,
                # or `exit 0` — closed a row having verified nothing. That is EXACTLY the vacuous-gate defect hq_P
                # had just finished removing from 31 gates, reappearing in the one command whose job is to certify
                # completion. Two checks, because either alone still lets something through.
                case "$(printf '%s' "$dw" | tr -d '[:space:]')" in
                  true|:|exit0|/bin/true|/usr/bin/true|""|"#"*)
                    printf '⛔ REFUSED: the DONE-WHEN in %s is a shell no-op (%s). It certifies nothing.\n' "$tf" "$dw" >&2
                    printf '   A DONE-WHEN must be a command that EXAMINES the tree and can exit non-zero when the work is not done.\n' >&2
                    exit 1;; esac
                # ⛔⭐ DECORATED NO-OP EVASION -- THE BLOCKLIST ABOVE ALONE IS NOT ENOUGH (found live, this session,
                # row `donewhen-decorated-noop-evasion`, while proving out the companion fix in
                # test_gate_baton_donewhen_runnable.sh). `tr -d '[:space:]'` then exact-match slides past a
                # trailing comment or a decorative argument -- `exit 0 # nothing to verify` and `: ok, done` are
                # NOT `exit0`/`:`. The VACUITY PROBE below independently catches those two specific witnesses
                # (they contain neither `/` nor `$`, so the probe still runs on them) -- but the probe SKIPS
                # itself whenever `dw` contains `/` or `$` (a path or a variable reference), which a decorated
                # no-op can easily also contain. REPRODUCED LIVE in a scratch postoffice: `: ok, done # see
                # /path/to/notes` and `exit 0 # nothing to verify, cf $HOME` both CLOSED THE ROW (exit 0, DONE
                # appended) under the pre-fix code -- the vacuity probe's own skip condition was the opening.
                # This check runs BEFORE the vacuity probe and does not depend on it: same comment-stripping,
                # same args-tolerant true/:/only-slash-true family, same bare-`echo` refusal as the gate script.
                dw_nc="$(printf '%s\n' "$dw" | s4e_strip_donewhen_comment)"
                dw_norm="$(printf '%s' "$dw_nc" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+/ /g')"
                if ! printf '%s' "$dw_norm" | grep -qE '[;|&`]|\$\('; then
                  _dw_first="$(command -v donewhen_first_word >/dev/null 2>&1 && donewhen_first_word "$dw_norm")"
                  _dw_noop=0
                  case "$dw_norm" in ""|"exit 0"|exit0) _dw_noop=1 ;; esac
                  case "$_dw_first" in true|:|/bin/true|/usr/bin/true|echo) _dw_noop=1 ;; esac
                  if [ "$_dw_noop" = "1" ]; then
                    printf '⛔ REFUSED: the DONE-WHEN in %s is a decorated shell no-op (%s -> reduces to: %s). It certifies nothing.\n' "$tf" "$dw" "$dw_norm" >&2
                    printf '   A DONE-WHEN must be a command that EXAMINES the tree and can exit non-zero when the work is not done.\n' >&2
                    exit 1
                  fi
                fi
                # VACUITY PROBE, borrowed from hq_P V2-5: run it in an EMPTY scratch directory. A criterion that
                # passes with nothing to examine is not examining anything. Skipped when the command names an
                # absolute path, because those legitimately still resolve from anywhere.
                case "$dw" in
                  */*|*'$'*) : ;;                       # names a path or expands a variable — probe would be meaningless
                  *) _vac="$(mktemp -d)"
                     ( cd "$_vac" && timeout -k 5 20 bash -c "$dw" ) >/dev/null 2>&1; _vrc=$?
                     rm -rf "$_vac"
                     # ⛔⭐ A TIMEOUT IS NOT AN ANSWER (hq_P 2026-08-27, source-read; hole was real and unreached).
                     # The probe used to branch on the COMMAND SUCCEEDING, so EVERY non-zero exit counted as proof the
                     # criterion examines the tree -- and `timeout` exits 124, non-zero, on a criterion that NEVER
                     # FINISHED. The two answers this probe exists to separate -- "correctly refused with nothing to
                     # examine" and "never ran to completion" -- shared one output, with no way to say which. That is
                     # fail-OPEN, inside the one command whose whole job is certifying completion. Same shape as the
                     # week's other mute instruments (mtime = lock-taken-not-work; PASS(0) = checked-or-never-asked).
                     # An instrument that cannot measure REFUSES rc=2; it does not pass what it failed to read.
                     if [ "$_vrc" -eq 124 ]; then
                       printf '⛔ REFUSED (rc=2): the DONE-WHEN in %s did not FINISH within 20s in an empty directory, so the\n' "$tf" >&2
                       printf '   vacuity probe could not measure it. This is NOT a pass -- a criterion that hangs when there is\n' >&2
                       printf '   nothing to examine is not evidence that it examines anything.\n   command: %s\n' "$dw" >&2
                       exit 2; fi
                     if [ "$_vrc" -eq 0 ]; then
                       printf '⛔ REFUSED: the DONE-WHEN in %s passes in an EMPTY directory, so it is not examining this tree.\n' "$tf" >&2
                       printf '   command: %s\n   Make it name what it inspects. (hq_P V2-5 used the same probe to find 31 vacuous gates.)\n' "$dw" >&2
                       exit 1; fi;; esac
                if [ -n "${S4E_DONE_OVERRIDE:-}" ]; then
                  # ω-class escape hatch: loud, recorded, and never silent. For the case where the DONE-WHEN itself
                  # is proven wrong -- which is a real event, and is why it must be auditable rather than forbidden.
                  printf 'OVERRIDE-BY %s %s reason: %s\n' "$ME" "$(date -u +%FT%TZ)" "$S4E_DONE_OVERRIDE" >> "$c"
                  printf '⚠ DONE-WHEN OVERRIDDEN by %s -- reason recorded in the claim: %s\n' "$ME" "$S4E_DONE_OVERRIDE"
                else
                  printf 'verifying DONE-WHEN (γ): %s\n' "$dw"
                  # ⛔ bash -c, NOT bare eval: `timeout` execs its argument, so it CANNOT run a shell BUILTIN. A criterion
                  # beginning with `cd` — a natural and common way to write one — died with "timeout: failed to run
                  # command 'cd'" and exit 127, making that row permanently uncloseable. My own certifier rejecting
                  # valid work. Found by running all 86 live criteria from the CWD `done` actually uses.
                  # ⭐⭐ THE OUTPUT IS CAPTURED, NOT DISCARDED (hq_C 2026-08-27, proposed to ceo and approved; CEO-30).
                  # A MUTE CORRECT GATE IS ITS OWN DEFECT CLASS. This refusal used to print ONLY the exit code, so
                  # "DONE-WHEN exited 2" meant "work unfinished" OR "scrip binary missing" OR "path wrong" OR "corpus
                  # subtree moved" -- indistinguishable. MEASURED COST: hq_C's own row refused three times in one
                  # session; two cycles went to a WRONG hypothesis (CWD anchoring, which seat10 had just legitimately
                  # fixed elsewhere and was sitting in the BOARD as a ready-made plausible cause) before the real cause
                  # turned out to be a vanished ./scrip binary -- itself the Stop-hook pristine race, diagnosed the
                  # same day. hq_P hit the identical shape from the other side with a different wrong hypothesis.
                  # ⛔ A MUTE GATE PLUS A PLAUSIBLE NEARBY CULPRIT DOES NOT MERELY FAIL TO NAME THE CAUSE -- IT POINTS
                  # SOMEWHERE ELSE. The criterion's own stderr said "REFUSED TO GRADE: scrip not built at ..." the whole
                  # time; nothing was broken except that nobody could see it. Changes no verdict, weakens no gate, and
                  # has no false-green path: it only makes a correct refusal legible.
                  _dwlog="$(mktemp)"
                  # ⛔⭐ S4E_HOME IS EXPORTED INTO THE CRITERION, AND WITHOUT THIS 11 LIVE ROWS COULD NEVER CLOSE
                  # (hq_C 2026-08-27, found closing srcreorg-ladder). `S4E` is derived here as "${S4E_HOME:-<from $0>}"
                  # -- an INPUT variable, never exported -- so a DONE-WHEN written as `cd "$S4E_HOME/SCRIP" && ...`,
                  # which 11 task files use and which reads as the obviously-correct portable idiom, expanded to the
                  # EMPTY STRING and ran `cd /SCRIP`. ⛔ THE REAL DEFECT IS NOT THAT IT FAILED, IT IS THAT IT FAILED
                  # CONDITIONALLY: a seat whose shell happened to export S4E_HOME graded its own tree and closed the
                  # row, and a seat without it got "No such file or directory" on the identical criterion and identical
                  # tree. rtx29-standdown closed exactly that way. A verdict that depends on the grader's environment
                  # is not a verdict, and it is invisible from either side -- the seat that closes sees nothing wrong,
                  # and the seat that is refused blames its own work. Exported, every criterion resolves against the
                  # LOCKING SEAT'S OWN ROOT, deterministically, for everyone. ⛔ Deliberately NOT exported into the
                  # vacuity probe above: that one must run starved in an empty dir, and handing it a real root is
                  # precisely what would let a vacuous criterion find something to pass on. (Moot today -- the probe
                  # skips anything containing '$' -- but the reason it stays that way belongs written down.)
                  # ⛔⭐ THE DEFAULT IS 3600s, AND A TIMEOUT IS A REFUSAL RATHER THAN A RED (hq_B 2026-09-03, row
                  # s4e-done-timeout-default-below-make-test-under-fleet-load, dispatched rank 0 because it blocked
                  # EVERY seat's close). The default was 900s while `make test` measures ~1100s on this box under
                  # twelve seats -- so every DONE-WHEN containing `make test` (every rung baton, most instrument rows)
                  # died at the default for a reason having NOTHING to do with the work, and said "NOT DONE -- exited
                  # 124", which reads as a red gate and sends the seat off to debug work that was already finished.
                  # ⭐ A timeout tuned to a job's MEASURED duration is not a tight bound, it is a FLAKY one: it belongs
                  # an order of magnitude above the measurement, never beside it -- the same rule the corpus runners
                  # learned when `timeout 30s` SIGTERMed a fully green board and the green board read as a hang.
                  # ⛔ AND THE TWO ANSWERS MAY NOT SHARE AN EXIT CODE. `timeout` exits 124 for a criterion that NEVER
                  # FINISHED -- "I could not measure" -- which the old arm folded into the same rc=1 as "I measured
                  # and it is red". That is precisely the fail-OPEN shape already cured in the vacuity probe twenty
                  # lines above, inside this very command: an instrument that cannot measure REFUSES rc=2, it does
                  # not report a verdict it never took. Now a caller scripting around `done` can tell them apart.
                  # ⭐ AND THE INSTRUMENT QUOTES ITS REFERENCE (RULES batch 14): every outcome prints the budget it ran
                  # under AND the wall-clock it used, so "did it just need more time?" is answered by the receipt
                  # instead of re-run and guessed at.
                  # S4E-GUARD-COMPILER-ABSENT -- ahead of the run, because there is nothing to learn from running it.
                  if s4e_donewhen_needs_compiler "$dw"; then
                    printf '  ⛔⛔ REFUSED (rc=2) — NOT MEASURED, so NOT a verdict: %s\n' "$_gca_why" >&2
                    printf '     The claim and the QUEUE column are UNCHANGED. Build, then re-run `done`.\n' >&2
                    exit 2; fi
                  _dwto="${S4E_DONE_TIMEOUT:-3600}"; _dwt0="$(date +%s)"
                  ( cd "$S4E" && S4E_HOME="$S4E" S4E_SEAT="$ME" S4E_DONE_WHEN_RUN=1 timeout -k 5 "$_dwto" bash -c "$dw" ) >"$_dwlog" 2>&1; rc=$?
                  _dwel="$(( $(date +%s) - _dwt0 ))"
                  if [ "$rc" -eq 0 ]; then
                    rm -f "$_dwlog"
                    printf '  ✅ DONE-WHEN exited 0 in %ss (timeout %ss) — completion is COMPUTED, not claimed.\n' "$_dwel" "$_dwto"
                  else
                    if [ "$rc" -eq 124 ]; then
                      printf '\n⛔ REFUSED (rc=2): the DONE-WHEN did NOT FINISH within %ss (elapsed %ss), so `done` COULD NOT MEASURE it.\n' "$_dwto" "$_dwel" >&2
                      printf '    This is NOT a red criterion, NOT a pass and NOT a skip. The claim is UNCHANGED and the row stays open.\n' >&2
                    elif [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ] || [ "$rc" -eq 2 ]; then
                      # ⛔ CEO-786 (coo 2026-09-16; hq_prolog's rung-9 row exited 127 in zero seconds for eleven days and was read as RED): rc 126/127
                      # (not executable / command not found) and rc 2 (the criterion itself REFUSED) are REFUSALS -- the instrument laws:
                      # cannot measure is not red. The row stays open, the claim unchanged, and the cause is printed from the criterion's own output.
                      printf '\n⛔ REFUSED (rc=2): the DONE-WHEN exited %s -- %s -- so `done` COULD NOT MEASURE it. This is NOT red: fix the criterion (cd into $S4E_HOME/SCRIP, name a script that exists, make it executable) and re-run.\n' \
                        "$rc" "$([ "$rc" -eq 127 ] && echo 'command not found' || { [ "$rc" -eq 126 ] && echo 'not executable' || echo 'the criterion itself refused'; })" >&2
                    else
                      printf '\n⛔⛔⛔ NOT DONE — the task DONE-WHEN exited %s after %ss (timeout %ss). The claim is UNCHANGED and the row stays open.\n' "$rc" "$_dwel" "$_dwto" >&2
                    fi
                    printf '    command : %s\n' "$dw" >&2
                    printf '    task    : %s\n' "$tf" >&2
                    if [ -s "$_dwlog" ]; then
                      printf '    ⭐ WHAT THE CRITERION ITSELF SAID (last 20 lines) -- read this BEFORE hypothesising:\n' >&2
                      sed -e 's/^/    | /' "$_dwlog" | tail -20 >&2
                    elif [ "$rc" -ne 124 ]; then
                      printf '    ⚠ the criterion produced NO output at all -- that is itself a clue: a silent non-zero is\n' >&2
                      printf '      usually a test that never ran (missing file, bad path, rc=127) rather than one that failed.\n' >&2
                    fi
                    rm -f "$_dwlog"
                    if [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ] || [ "$rc" -eq 2 ]; then exit 2; fi
                    if [ "$rc" -eq 124 ]; then
                      printf '    Give it a real budget for THIS close:  S4E_DONE_TIMEOUT=<seconds> s4e_msg.sh done %s\n' "$topic" >&2
                      printf '    ⭐ Giving a check enough wall-clock is NOT weakening it -- raising the budget is always allowed;\n' >&2
                      printf '      editing the criterion to finish sooner is the false-green trap. A criterion that hangs FOREVER\n' >&2
                      printf '      is a finding about the criterion: say so in the LEDGER and fix the criterion, never the clock.\n\n' >&2
                      exit 2
                    fi
                    printf '    If the DONE-WHEN itself is WRONG, that is a real finding: fix it in the task file and say so\n' >&2
                    printf '    in the LEDGER, or re-run with S4E_DONE_OVERRIDE="why" which records the reason in the claim.\n' >&2
                    printf '    ⛔ Do NOT weaken a DONE-WHEN to make it pass -- that is the false-green trap this gate exists to stop.\n\n' >&2
                    exit 1; fi; fi
              else
                # ⛔⭐ HOLE A, CURED 2026-08-28 (hq_B; reproduced in a scratch postoffice before the fix). This arm
                # used to PRINT the law it was breaking -- "closing on the seat word alone, which LAW 1 forbids" --
                # and then FALL THROUGH to the unconditional DONE write below, closing the row with ZERO verification
                # and exit 0. A warning that does not change what happens is not a guard, it is a comment with
                # stdout. ⭐ AND IT WAS INVISIBLE FOR THE SAME REASON EVERY MUTE INSTRUMENT IS: the operator saw a
                # ⚠ line scroll past inside a command that then said "done", so the loud part and the wrong part
                # disagreed and the reassuring one was last. Now it REFUSES rc=2 -- a criterion that cannot be READ
                # cannot be PASSED, exactly as a test that cannot measure refuses rather than skipping as success.
                printf '⛔ REFUSED (rc=2): NO TASK BATON at %s — closing on the seat word alone is what LAW 1 forbids.\n' "$tf" >&2
                printf '   A row with no baton has no computable DONE-WHEN, so its completion cannot be verified, so it\n' >&2
                printf '   cannot be closed. This is NOT a pass and NOT a skip. Mint the baton for this topic, then close.\n' >&2
                exit 2
              fi
              # ⛔⭐⭐ THE CODEGEN CONTROL ARM FIRES HERE -- AFTER the DONE-WHEN has passed and BEFORE the DONE
              # marker is written, because a landing that reds the rungs is NOT DONE however green its own
              # criterion is.  That ordering IS the cure: seat11's DONE-WHEN passed and the row closed, and the
              # 299 red rungs entries were discovered by other seats hours later.  See s4e_codegen_touched above
              # for why the touch set is COMPUTED and why this CITES a board rather than running one (CEO-697, CEO-1232).
              _cg_repo="$S4E/SCRIP"; _cg_touch="$(s4e_codegen_touched "$_cg_repo" "$c")"
              if [ -n "$_cg_touch" ]; then
                printf '\n⭐ CODEGEN CONTROL ARM -- this landing touches codegen, computed from the diff (never asserted):\n'
                printf '%s\n' "$_cg_touch" | sed 's/^/     /'
                if [ -n "${S4E_DONE_SKIP_RUNGS_ARM:-}" ]; then
                  # ω-class escape hatch, LOUD AND RECORDED, exactly like S4E_DONE_OVERRIDE. A silent skip and a
                  # silent pass are indistinguishable one layer up, which is the trap this whole guard is about.
                  printf '⚠⚠ CONTROL ARM SKIPPED by %s -- reason recorded in the baton ledger: %s\n' "$ME" "$S4E_DONE_SKIP_RUNGS_ARM" >&2
                  [ -f "$tf" ] && printf '\n- [%s·%s] ⚠ CODEGEN CONTROL ARM **SKIPPED** via S4E_DONE_SKIP_RUNGS_ARM on a landing touching: %s -- stated reason: %s\n' \
                    "$ME" "$(date -u +%Y-%m-%d)" "$(printf '%s' "$_cg_touch" | tr '\n' ' ')" "$S4E_DONE_SKIP_RUNGS_ARM" >> "$tf"
                else
                  # ⛔ THE SUITES ARE CHOSEN BY WHAT THE DIFF TOUCHED, not by a fixed pair: the SNOBOL4 rungs is the
                  # standing control arm for ANY codegen change, and the Icon watermark joins it exactly when the diff
                  # reaches Icon's own lowerer or templates (this row's GOAL, "the Icon watermark arm likewise").
                  _cg_suites="snobol4-rungs"
                  printf '%s\n' "$_cg_touch" | grep -qE 'lower_icon\.c|templates/.*icn|icn.*\.cpp' && _cg_suites="$_cg_suites icon-rungs"
                  _cg_scrip="$(git -C "$_cg_repo" rev-parse --short HEAD 2>/dev/null)"
                  _cg_corpus="$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null)"
                  _cg_db="${S4E_PROGRESS_DB:-/home/resources/progress/results.tsv}"
                  _cg_inh="$(s4e_baton_inherited "$tf")"
                  printf '   tree: scrip=%s corpus=%s   db=%s\n' "${_cg_scrip:-?}" "${_cg_corpus:-?}" "$_cg_db"
                  [ -n "$_cg_inh" ] && printf '   INHERITED (read live from the baton, never remembered): %s\n' "$(printf '%s' "$_cg_inh" | tr '\n' ' ')"
                  for _cg_s in $_cg_suites; do
                    if _cg_fails="$(s4e_cite_board "$_cg_db" "$_cg_scrip" "$_cg_corpus" "$_cg_s")"; then
                      # ⛔ set -o pipefail is NOT on here; comm needs both sides sorted, which both helpers guarantee.
                      _cg_excess="$(comm -23 <(printf '%s\n' "$_cg_fails" | sed '/^$/d') <(printf '%s\n' "$_cg_inh" | sed '/^$/d'))"
                      if [ -n "$_cg_excess" ]; then
                        printf '\n⛔⛔⛔ NOT DONE -- the CITED %s board of THIS EXACT TREE is red beyond the inherited set.\n' "$_cg_s" >&2
                        printf '   Entries failing that the baton does NOT name as inherited:\n' >&2
                        printf '%s\n' "$_cg_excess" | sed 's/^/       /' >&2
                        printf '   ⭐ This board was CITED, not run: it was measured on scrip=%s corpus=%s, which is your tree.\n' "$_cg_scrip" "$_cg_corpus" >&2
                        printf '   Cure the regression, or -- if these are genuinely inherited -- add them to the baton INHERITED: line\n' >&2
                        printf '   with the board that shows them red BEFORE your change. ⛔ Do NOT widen INHERITED to make this pass.\n' >&2
                        printf '   Escape hatch, loud and recorded: S4E_DONE_SKIP_RUNGS_ARM="why".\n' >&2
                        exit 1; fi
                      printf '   ✅ %s: CITED board of this tree is clean over the inherited set (%s entry/entries inherited).\n' \
                        "$_cg_s" "$(printf '%s' "$_cg_inh" | sed '/^$/d' | grep -c . || echo 0)"
                    else
                      # ⛔⭐⭐ COULD NOT MEASURE IS NOT A VERDICT, AND IT IS ALSO NOT A BLOCKER.  There is no board of
                      # this exact tree in the database, and this seat MAY NOT RUN ONE (CEO-697's cite-not-run), so
                      # refusing here would block every codegen landing in the fleet on a board this seat cannot make.
                      # ⛔ THE STAGE PASS THIS BRANCH ONCE FED IS RETIRED (ceo CEO-1299, 2026-09-26): it recorded the
                      # landing in codegen-landings.tsv "for the coo stage pass", a central board that died with
                      # CEO-775, and nothing but its own gate read the file (46 rows, measured). Under CEO-1232 the
                      # reader of record is each HQ's next per-landing pass on origin, which stamps the range it
                      # covers, so the only record kept is the one on this row's baton.
                      printf '   ⚠⚠ %s: NO BOARD OF THIS TREE EXISTS -- so the control arm COULD NOT MEASURE, which is\n' "$_cg_s" >&2
                      printf '      neither a pass nor a red. Not running one: under CEO-1232 this landing is graded by its lander on\n' >&2
                      printf '      its own language'"'"'s suites, the gates it touched and make preflight; every other language'"'"'s verdict is\n' >&2
                      printf '      that HQ'"'"'s next per-landing pass on origin, which stamps the range it covers.\n' >&2
                      [ -f "$tf" ] && printf '\n- [%s·%s] ⚠ CODEGEN LANDING WITH NO CITABLE BOARD -- touched: %s (scrip=%s corpus=%s). The control arm could not measure and did not pretend to; under CEO-1232 the lander'"'"'s own-language suites and each other HQ'"'"'s next per-landing pass on origin are the verdict.\n' \
                        "$ME" "$(date -u +%Y-%m-%d)" "$(printf '%s' "$_cg_touch" | tr '\n' ' ')" "${_cg_scrip:-?}" "${_cg_corpus:-?}" >> "$tf"
                    fi
                  done
                fi
              fi
              # ⛔⭐ THE RECEIPT (coo 2026-09-16, ceo CEO-790/793; row instruments-a-done-row-with-no-claim-and-no-receipt-was-closed-by-
              # a-path-that-bypassed-the-computed-done-name-and-refuse-it): a DONE is COMPUTED here, so the claim carries the
              # computation -- rc, the tree it ran on, how long, computed or overridden, when, by whom. A DONE row whose claim has
              # no such line reached DONE by a path outside this verb (17 in QUEUE.tsv on 2026-09-16, one reopened RED by audit);
              # util_queue_visibility_census.py names them (class R) and `sweep` refuses to move them.
              _dtree="$(git -C "$S4E/SCRIP" rev-parse --short HEAD 2>/dev/null || echo unknown)"; [ -n "$(git -C "$S4E/SCRIP" status --porcelain 2>/dev/null)" ] && _dtree="$_dtree-DIRTY"
              printf 'RECEIPT done rc=0 tree=%s elapsed=%ss via=%s %s by %s\n' "$_dtree" "${_dwel:-?}" "$([ -n "${S4E_DONE_OVERRIDE:-}" ] && echo override || echo computed)" "$(date -u +%FT%TZ)" "$ME" >> "$c"
              grep -q '^DONE$' "$c" || echo DONE >> "$c"; echo "done $topic"
              # ⛔⭐ (a) DONE CLOSES ITS OWN WINDOW (hq_B scope, 2026-08-28, ratified by ceo as rank 1). Until now
              # this verb latched the CLAIM and never touched QUEUE.tsv -- s4e_mark_row() below writes only the
              # per-seat .last-row despite its name. So a verified close left the column reading FREE, and the row
              # became INVISIBLE IN ALL THREE PICKER PASSES (PASS 1/2 skip a DONE claim even for its owner; PASS 3
              # skips any topic that has a claim file at all) while still reading FREE to any human scanning the
              # queue. ⛔ THE FIX IS CLOSING THE WINDOW, NEVER WIDENING THE PICKER: making `next` serve DONE-claimed
              # rows would reopen landed work. The column is now MIRRORED FROM the claim, which is the authority.
              # ⭐ s4e-done-does-not-clear-annotation: S4E_DONE_DOES_NOT_CLEAR="dep1[,dep2,...]" appends the
              # machine-read exception list (see s4e_does_not_clear() above) to the state this DONE writes.
              # Optional and rare — most closes clear every dependent, which is why self-clear earns its keep.
              _dnc="${S4E_DONE_DOES_NOT_CLEAR:-}"; _dstate="DONE"
              [ -n "$_dnc" ] && _dstate="DONE:DOES-NOT-CLEAR:$_dnc"
              if s4e_set_row_state "$topic" "$_dstate"; then echo "  (QUEUE.tsv state -> $_dstate; claim and column now agree)"
              else echo "  (no live QUEUE.tsv row for $topic — nothing to mirror; the claim is the record)"; fi
              s4e_mark_row "$topic" DONE
              [ "${S4E_NO_BANNER:-0}" = "1" ] || "$0" banner "$topic" "${3:-}"
         elif [ ! -f "$c" ]; then
              # ⛔⭐ hq_C's bus finding (ceo CEO-362, 2026-09-06): an ASSIGNED row with NO claim file used to answer
              # "not your claim", which names the WRONG defect -- it says somebody else holds the row when in fact
              # NOBODY does, so the reader goes looking for the other owner instead of running `claim`. The row is
              # then uncloseable by anyone. Two distinguishable states must not share one diagnostic.
              printf 'no claim exists on this row -- run `claim %s` first\n' "$topic" >&2; exit 1
         else printf 'not your claim -- %s holds it, you are %s\n' "$(head -1 "$c")" "$ME" >&2; exit 1; fi;;
  reown) # ⭐⭐ CHANGE A ROW'S OWNER CELL (QUEUE.tsv field 3). The verb that did not exist, which is why the
         # lane could rot without anyone being able to repair it (hq_B 2026-09-13, ceo CEO-672 part 2).
         # ⛔ REOWN IS NOT ASSIGN, AND CONFLATING THEM IS HOW PART 2 WENT UNDONE FOR AS LONG AS IT DID. `assign`
         # writes a CLAIM -- it locks one row to one seat for one sitting, LAW 2, "assignment is the lock". It
         # never touches column 3. So the queue header's own advice ("to move ownership properly, an HQ or the
         # ceo runs: s4e_msg.sh assign <topic> <seat>") describes something assign does not do, AND states the
         # arguments in the wrong order -- assign takes <seat> <topic>. Two errors in one sentence of guidance,
         # in the file the guidance is about. ⭐ A verb that does not exist is not discovered by reading docs
         # about it; it is discovered by trying to do the thing and finding nothing that does it.
         # OWNERSHIP is "whose lane is this row in" and outlives any sitting; a CLAIM is "who is holding it right
         # now". Changing the first must never silently do the second.
         [ -n "${2:-}" ] || s4e_need reown "a seat" "s4e_msg.sh reown <seat> <topic>" "Moves a row's owner column; it does not move the claim."
         [ -n "${3:-}" ] || s4e_need reown "a topic" "s4e_msg.sh reown <seat> <topic>" "Moves a row's owner column; it does not move the claim."
         seat="$2"; topic="$3"; q="$PO/QUEUE.tsv"
         case "$seat"  in ""|*/*|*$'\n'*) echo "⛔ REFUSED: seat must be a filename-safe mailbox name (hq_S, cfo, ...)" >&2; exit 2;; esac
         case "$topic" in ""|*/*|*$'\n'*) echo "⛔ REFUSED: topic must be a filename-safe slug" >&2; exit 2;; esac
         [ -f "$q" ] || { echo "⛔ REFUSED: no QUEUE.tsv at $q" >&2; exit 2; }
         # LAW 6, same as assign: a seat with no mailbox is not a seat, and this never creates one.
         [ -d "$PO/$seat/inbox" ] || { printf '⛔ REFUSED: seat "%s" has NO postoffice mailbox (%s). reown never creates one (LAW 6).\n' "$seat" "$PO/$seat/inbox" >&2; exit 2; }
         row="$(grep -P "^[0-9]+\t\Q$topic\E\t" "$q" 2>/dev/null | head -1)"
         [ -n "$row" ] || { echo "⛔ REFUSED: no QUEUE.tsv row named '$topic'." >&2; exit 2; }
         _old="$(printf '%s' "$row" | cut -f3)"; _state="$(printf '%s' "$row" | cut -f4)"
         if [ "$_old" = "$seat" ]; then printf 'already owned: %s -> %s (no change)\n' "$topic" "$seat"; exit 0; fi
         # ⛔⭐ A HELD ROW IS NOT REOWNED UNDER ITS HOLDER. The whole point of this verb is repairing a lane cut,
         # and a lane cut that yanks a row out from under the seat currently working it trades one misdispatch for
         # a worse one. --force is a deliberate act and says so; it still never touches the claim.
         _c="$PO/claims/$topic.claim"
         if [ -f "$_c" ] && ! grep -q '^DONE$' "$_c" 2>/dev/null && [ "${4:-}" != "--force" ]; then
           printf '⛔ REFUSED: "%s" is CLAIMED by %s (state %s). Reowning it now would move the row out from under a\n' "$topic" "$(head -1 "$_c")" "$_state" >&2
           printf '   working seat. Wait for it to park or land, or say so deliberately: reown %s %s --force\n' "$seat" "$topic" >&2
           printf '   (--force changes the OWNER CELL only and never releases the claim -- those are two different acts.)\n' >&2
           exit 1; fi
         cp "$q" "$q.bak.reown-$(date -u +%Y%m%dT%H%M%SZ)"
         _tmp="$(mktemp)"
         TOPIC="$topic" NEW="$seat" awk -F'\t' -v OFS='\t' '$2==ENVIRON["TOPIC"] && /^[0-9]/ {$3=ENVIRON["NEW"]} {print}' "$q" > "$_tmp"
         # ⛔ ANTI-VACUITY: a rewrite that changed nothing, or changed the line count, is a broken rewrite and must
         # not be moved over the real queue. The backup above is not a substitute for noticing.
         if [ "$(wc -l < "$_tmp")" -ne "$(wc -l < "$q")" ]; then rm -f "$_tmp"; echo "⛔ REFUSED: rewrite changed the row count -- not applied. QUEUE.tsv untouched." >&2; exit 2; fi
         if ! grep -qP "^[0-9]+\t\Q$topic\E\t\Q$seat\E\t" "$_tmp"; then rm -f "$_tmp"; echo "⛔ REFUSED: rewrite did not take -- not applied. QUEUE.tsv untouched." >&2; exit 2; fi
         mv "$_tmp" "$q"; chmod 664 "$q"
         printf 'reowned: %s  %s -> %s  (state %s unchanged, claim untouched)\n' "$topic" "$_old" "$seat" "$_state"
         ;;
  assign) # ⭐ V2-1 / LAW 2 — ASSIGNMENT IS THE LOCK (ARCH-FLEET-CEO.md). HQ writes the seat's claim ATOMICALLY on HQ's
         # side, which makes the v1 dispatch race UNREPRESENTABLE: v1 mailed a brief AND let the seat run `next`, so two
         # channels answered "what am I working on" with nothing arbitrating -- that race is what killed seat13's session
         # (it held five rows, worked a sixth, and starved). There is now exactly one answer and it is a file on disk.
         [ -n "${2:-}" ] || s4e_need assign "a seat" "s4e_msg.sh assign <seat> <topic>" "ASSIGNMENT IS THE LOCK: it writes that seat's claim atomically and rings a doorbell; their next serves it FIRST."
         [ -n "${3:-}" ] || s4e_need assign "a topic" "s4e_msg.sh assign <seat> <topic>" "ASSIGNMENT IS THE LOCK: it writes that seat's claim atomically and rings a doorbell; their next serves it FIRST."
         seat="$2"; topic="$3"; q="$PO/QUEUE.tsv"; mkdir -p "$PO/claims"
         case "$seat"  in ""|*/*|*$'\n'*) echo "⛔ REFUSED: seat must be a filename-safe mailbox name (seat07, hq_C, ...)" >&2; exit 2;; esac
         case "$topic" in ""|*/*|*$'\n'*) echo "⛔ REFUSED: topic must be a filename-safe slug, not the message body" >&2; exit 2;; esac
         # ⛔ LAW 6 IDENTITY IS ASSERTED, NEVER GLOBBED: refuse a seat with no mailbox, and NEVER create one on the fly --
         # auto-creation is exactly how phantom claude01/ was born, and it marooned two HQ messages where nobody looked.
         [ -d "$PO/$seat/inbox" ] || { printf '⛔ REFUSED: seat "%s" has NO postoffice mailbox (%s). assign never creates one (LAW 6).\n   mailboxes that exist: %s\n' "$seat" "$PO/$seat/inbox" "$(cd "$PO" && ls -d */inbox 2>/dev/null | sed 's|/inbox||' | tr '\n' ' ')" >&2; exit 2; }
         # ⛔ AND REFUSE WORK THAT DOES NOT EXIST OR IS ALREADY LANDED -- v1 re-dispatched finished rows because nothing checked.
         row="$(grep -P "^[0-9]+\t\Q$topic\E\t" "$q" 2>/dev/null | head -1)"
         [ -n "$row" ] || { echo "⛔ REFUSED: no QUEUE.tsv row named '$topic'. You cannot assign work that has no row." >&2; exit 2; }
         c="$PO/claims/$topic.claim"
         if [ -f "$c" ]; then own="$(head -1 "$c")"
           if grep -q '^DONE$' "$c"; then echo "⛔ REFUSED: '$topic' is already DONE (held by $own). Sweep it to QUEUE.done.tsv — do NOT re-dispatch landed work." >&2; exit 1; fi
           if [ "$own" = "$seat" ]; then echo "already assigned: $topic -> $seat"; exit 0; fi
           echo "⛔ REFUSED: '$topic' is held by $own, not $seat. Release that claim first (that is a deliberate act, not a retry)." >&2; exit 1; fi
         # ⛔⭐ PRE-CLAIM PLACEHOLDER REFUSAL (row mint-dispatch-refuses-a-placeholder-done-when, ceo CEO-286
         # 2026-09-05): STATIC and UNCONDITIONAL -- not gated behind S4E_NO_DISPATCH_PROBE the way the
         # dynamic probe below is, because that escape hatch exists for a seat who wants to dispatch a row
         # DESPITE an "already satisfied" reading they believe is wrong; there is no equivalent case for a
         # placeholder, since prose can never become a command no matter who overrides what. rc=2, matching
         # every other could-not-measure refusal in this file; no claim is written either way below this.
         if s4e_predispatch_placeholder_check "$topic"; then
           printf '\n⛔ REFUSED(2): %s HAS A PLACEHOLDER DONE-WHEN -- %s\n' "$topic" "$_ppc_why" >&2
           printf '   Fix the baton'"'"'s DONE-WHEN line to a real command, then assign again. No claim written.\n' >&2
           exit 2
         fi
         # ⛔ AN UNRUNNABLE DONE-WHEN IS REFUSED AT ASSIGN, LIKE THE PLACEHOLDER (CEO-786; coo 2026-09-16): the criterion is run once with the
         # dispatch budget; exit 126/127 (not executable / command not found) or 2 (the criterion refused) is a REFUSAL naming the exit and
         # the first line the criterion said -- never a red, which is rc=1 with a line beginning RED. rc 0 and rc 1 dispatch as before.
         if [ "${S4E_NO_DISPATCH_PROBE:-0}" != "1" ]; then
           _adw="$(s4e_donewhen_text "$PO/tasks/$topic.task.md")"; _alog="$(mktemp)"
           ( cd "$S4E" && S4E_HOME="$S4E" S4E_SEAT="$seat" S4E_DONE_WHEN_RUN=1 timeout "$(s4e_dispatch_timeout)" bash -c "$_adw" ) >"$_alog" 2>&1; _arc=$?
           if [ "$_arc" -eq 126 ] || [ "$_arc" -eq 127 ] || [ "$_arc" -eq 2 ]; then
             printf '\n⛔ REFUSED(2): %s HAS AN UNRUNNABLE DONE-WHEN -- it exited %s (%s) in a probe run; a criterion that cannot run is a refusal, not a red (CEO-786).\n' \
               "$topic" "$_arc" "$([ "$_arc" -eq 127 ] && echo 'command not found' || { [ "$_arc" -eq 126 ] && echo 'not executable' || echo 'the criterion itself refused'; })" >&2
             printf '   first line it said: %s\n   Fix the DONE-WHEN (cd "$S4E_HOME/SCRIP", name a script that exists), then assign again. No claim written.\n' "$(grep -m1 . "$_alog" | cut -c1-160)" >&2
             rm -f "$_alog"; exit 2
           fi
           rm -f "$_alog"
         fi
         # ⛔⭐ DISPATCH PROBE, ASSIGN SIDE (same ruling as next's; see s4e_dispatch_probe above). An HQ dispatching
         # a row that is already satisfied is the seat09 five-day case with a person in the loop instead of a picker.
         # ⛔ THIS SIDE PROBES AND REFUSES; IT DOES NOT CLOSE. Two reasons, and both are about not overreaching:
         # (1) the ruling says the criterion runs "on the seat's own tree", and an HQ's tree is NOT the seat's -- a
         # green here proves the row is satisfied HERE, which is strong evidence and not the same statement; and
         # (2) `assign` cannot delegate to `done` the way next does (done requires the claim to be the RUNNER's, and
         # assign writes ANOTHER seat's), so closing from here would mean a SECOND copy of the close path, and the
         # close is the one thing in this file that must never exist twice. Refusing the dispatch already prevents
         # the whole measured defect: no seat is handed dead work. The HQ then closes it deliberately, or learns
         # that the DONE-WHEN is passing where the work is not done -- which is the more interesting finding anyway.
         if [ "${S4E_NO_DISPATCH_PROBE:-0}" != "1" ]; then
           # ⛔ rc CAPTURED IMMEDIATELY, never read as `$?` from inside an elif -- this file's own banner comment
           # convicts exactly that ("read its verdict line, not a pipeline's $?"), and a probe whose two failure
           # modes silently collapsed into one would serve back the ambiguity it exists to remove.
           s4e_dispatch_probe "$topic"; _dprc=$?
           if [ "$_dprc" = 0 ]; then
             printf '\n⛔ REFUSED: %s IS ALREADY SATISFIED — do not dispatch it.\n' "$topic" >&2
             printf '   Its own DONE-WHEN exits 0 on THIS tree (%s), so %s would be handed work that is already done.\n' "$S4E" "$seat" >&2
             printf '   That is the five-day dead row this check exists to stop (seat09, FINDING-2026-09-03).\n' >&2
             printf '   ⛔ NOT CLOSED FOR YOU: this is the HQ tree, not %s'"'"'s, and a close is a deliberate act. Either\n' "$seat" >&2
             printf '     close it here    : bash %s claim %s && bash %s done %s\n' "$0" "$topic" "$0" "$topic" >&2
             printf '     or fix the row   : if this row IS real work, its DONE-WHEN is the defect -- it passes where\n' >&2
             printf '                        the work is not done, which is exactly how seat09'"'"'s row died. Fix the\n' >&2
             printf '                        criterion in the baton first, then assign.\n' >&2
             printf '   To dispatch anyway, deliberately: S4E_NO_DISPATCH_PROBE=1 bash %s assign %s %s\n\n' "$0" "$seat" "$topic" >&2
             exit 1
           elif [ "$_dprc" = 2 ]; then
             printf '⚠ DISPATCH PROBE COULD NOT MEASURE %s -- assigning anyway, unverified: %s\n' "$topic" "${_dp_why:-?}" >&2
           fi
         fi
         t="$(mktemp "$PO/claims/.c.XXXXXX")"; { echo "$seat"; echo "ASSIGNED-BY $ME $(date -u +%FT%TZ)"; } > "$t"
         if ln "$t" "$c" 2>/dev/null; then rm -f "$t"; else rm -f "$t"; echo "⛔ RACE LOST: $(head -1 "$c" 2>/dev/null) owns '$topic'" >&2; exit 1; fi
         # ⭐ picker-dependency-and-boomerang-blindness CURE 2: an HQ assignment is the loudest possible "another
         # seat/HQ touched it" — it ends the boomerang cooldown outright. (PASS 1 serves assigned rows and never
         # consults the guard, so this is belt-and-braces: it keeps released/ from accumulating dead receipts.)
         s4e_release_clear "$topic"
         # ⭐ Same cure, second acquisition site. assign does NOT route through the `claim` verb (it writes ANOTHER
         # seat's name, which `claim` by construction cannot), so it is the one acquiring path the primitive does not
         # already cover -- an explicit call, not a missed one. ASSIGNED:<seat> is the spelling two live rows already
         # carry by hand; this makes it written. Col3 untouched here too, for the reason given at `claim`.
         s4e_set_row_state "$topic" "ASSIGNED:$seat" || true
         s4e_backfill_owner_lane "$topic" "$seat" || true   # fills col3 ONLY if blank -- see the function's own note
         # THE DOORBELL CARRIES NO CONTENT (ARCH-FLEET-CEO: "the mail never carries content that isn't also in a file").
         # A seat that never reads this message still resumes correctly, because the claim + task file are authoritative.
         # ⭐ THE DOORBELL GOES THROUGH --stdin LIKE EVERY OTHER PROSE BODY, AND THAT IS THE POINT (hq_B 2026-09-13).
         # ⛔ IT WAS AN ARGV SEND AND THE NEW PROSE GUARD REFUSED IT, WHICH BROKE `assign` -- caught by
         # test_gate_s4e_picker_v2.sh's `doorbell` arm, not by me: I censused external callers for argv prose bodies
         # and found none, and never censused s4e_msg.sh's OWN internal sends. A blast-radius census that stops at
         # the file boundary is the narrow-instrument defect wearing a census's clothes. ✅ The fix is the safe path,
         # not an exemption: an internal caller that needed a bypass would be the first argument for the next one.
         if printf '%s' "ASSIGNED: $topic. Run: bash harness/scripts/s4e_msg.sh next — it serves this row FIRST, ahead of anything you picked yourself. The task file is authoritative; this message is only the doorbell." | S4E_NO_BANNER=1 "$0" send "$seat" "task-$topic" --stdin >/dev/null 2>&1
         then echo "assigned $topic -> $seat (claim written, doorbell sent)"
         else echo "assigned $topic -> $seat (claim written; ⛔ DOORBELL NOT SENT — the claim still governs, $seat gets it from next)"; fi;;
  # ⭐⭐ ceo RULING 2026-08-29 (row s4e-mint-subcommand, hq_C's find): A SEAT COULD NOT MINT A ROW — next|claim|
  # unclaim|park|done|assign|ask|send|check|clear|mailbox|sweep|board|banner|fleet, NONE of them creates one. That
  # makes "a finding without a row is a finding nobody had" unreachable from a seat by construction. Two seats left
  # real defects loose in one session for want of this path; hq_B hand-appended to QUEUE.tsv (no lock, 16 live
  # seats) and flagged the race themselves. The mail-your-HQ workaround only functions while an HQ is reading, and
  # a mint-request queue is just a second queue — so this is the real thing, open to every seat.
  # Usage: mint <topic> [rank] "GOAL text"   or   mint <topic> [rank] --stdin <<'EOF' ... EOF
  # rank is sniffed, not fixed-position: the token right after topic is consumed as rank ONLY if it is
  # ALL DIGITS (never true of real GOAL prose, even prose that happens to start with a number — that always
  # has a following space/letter); otherwise it defaults to 2 and the same token starts the goal text.
  mint)  [ -n "${2:-}" ] || s4e_need mint "a topic" "s4e_msg.sh mint <topic> [rank] [--owner <seat>] \"GOAL text\"" "The only sanctioned way to add work: it writes a QUEUE row and a skeleton baton atomically."
         topic="$2"; shift 2
         rank=2
         if [ -n "${1:-}" ]; then case "$1" in *[!0-9]*|'') :;; *) rank="$1"; shift;; esac; fi
         # ⭐⭐ NO BLANK OWNER CELL, HALF 2 OF 2 (row next-serves-a-seat-only-rows-in-its-hqs-lane-and-no-
         # row-carries-a-blank-owner-cell) — a mint used to write field 3 as the literal string "unassigned"
         # UNCONDITIONALLY, which is exactly how this row's own baton was born with no lane a lane-blind
         # `next` could read. `--owner hq_X` is sniffed here, BEFORE the goal text is collected, the same
         # way rank already is, so `mint <topic> [rank] [--owner hq_X] "GOAL text"` never breaks a caller
         # who omits it: for a topic whose language prefix THE LANES table maps (prolog-/icon-/snobol4-/
         # snocone-/pascal-/raku-/rebus-*), s4e_topic_lane derives the owner for free and no flag is ever
         # needed — this is every mint this fleet has actually issued so far. Only a topic naming no
         # language (a postoffice/tooling/meta row, this fix's own first victim) needs the flag; asking for
         # it there, once, is cheaper than another blank cell nobody catches until a seat wanders into it.
         owner=""
         if [ "${1:-}" = "--owner" ]; then owner="${2:?--owner needs an hq_icon|hq_prolog|hq_raku|hq_pascal|hq_snocone|hq_snobol4|hq_templates|hq_runtime|hq_collector|hq_zetas|hq_dotnet|hq_jvm|hq_C|hq_B|hq_P|hq_T|hq_U|hq_S|hq_I|hq_R|hq_V argument}"; shift 2
           # ⛔ THE EXECUTIVES WERE REFUSED HERE (hq_B 2026-09-13, CEO-672's class, found while curing it). This
           # accepted only hq_* names, so under NONET -- where FOUR of the seven completeness owners are the
           # ceo, cto, coo and cfo -- `mint --owner ceo` was rejected outright and an Icon row could not be
           # minted to the seat that owns Icon. s4e_is_hq() is the one roster and already counts all thirteen;
           # a second hand-written list beside it is the very defect this row exists to end.
           if ! s4e_is_hq "$owner"; then echo "⛔ REFUSED: --owner must be a standing seat ($(s4e_hqboxes | tr '\n' ' ')), not '$owner'." >&2; exit 2; fi; fi
         if [ "${1:-}" = "--stdin" ] || [ "${1:-}" = "-" ]; then goal="$(cat)"; else goal="$*"; fi
         # ⛔ THE TOPIC BECOMES A FILENAME TWICE OVER (a QUEUE.tsv row AND tasks/<topic>.task.md) — same guard
         # as send (s191), checked before either write, not after.
         case "$topic" in ""|*/*|*$'\n'*) echo "⛔ REFUSED: topic must be a short filename-safe slug (no / and no newline). Usage: $0 mint <topic> [rank] \"GOAL text\"" >&2; exit 2;; esac
         [ -n "$goal" ] || { echo "⛔ REFUSED: empty GOAL text. Usage: $0 mint <topic> [rank] \"GOAL text\" (or --stdin)" >&2; exit 2; }
         # ⛔⭐ THE SPLIT HAPPENS HERE, BEFORE THE LOCK AND BEFORE EITHER WRITE -- it used to sit inside the
         # lock, next to the baton heredoc. It is hoisted so the criterion can be JUDGED while refusing is
         # still free: a refusal after the queue row is appended is not a refusal, it is a cleanup problem.
         # (A GOAL that already carries its own DONE-WHEN must not get the placeholder underneath it --
         # hq_I 2026-09-06, on a row hq_B minted for them: "the baton carries TWO DONE-WHEN lines, yours and
         # the mint placeholder underneath". The extractor takes the FIRST and a human reading down the file
         # takes the LAST, so the two readers of one file disagreed.)
         # ⛔⭐ THE PLACEHOLDER IS RUNNABLE AND ALWAYS RED (coo 2026-09-17, ceo CEO-829, row instrument-mint-writes-a-
         # runnable-always-red-placeholder-so-a-new-row-is-red-not-permanently-uncloseable). It used to be PROSE, so
         # every mint counted PERMANENTLY UNCLOSEABLE in test_gate_baton_donewhen_runnable.sh and pushed it past its
         # ceiling -- REDDING make test for every seat. That happened TWICE IN ONE HOUR on 2026-09-17, both on rows
         # the ceo asked for, and the ceo wrote both criteria by hand to clear the red: MINTING, THE SANCTIONED WAY
         # TO ADD WORK, RED THE FLEET. The conflation was the defect, not the guard -- "nobody has written the
         # criterion yet, this row is four minutes old" and "this row's criterion is broken prose from six weeks
         # ago" are different facts. ⛔ THE GUARD IS NOT WEAKENED BY ONE INCH: this command EXITS 1, always, so
         # `done` can never close a row wearing it -- a fresh row is RED (honest: not done, not closeable yet)
         # instead of UNCLOSEABLE (a different and worse state). It is deliberately written in the self-refusing
         # stub shape s4e_donewhen_is_placeholder already recognises, so every placeholder-aware reader -- the
         # picker's refusal to dispatch, the hidden-criterion gate, the multiple-contracts scanner -- keeps working
         # with no second spelling of the rule anywhere.
         dw_block="DONE-WHEN: echo \"⛔ NOT MEASURED: this row was minted with no acceptance criterion. Replace this line with a command that MEASURES the GOAL above; until then the row is RED and can never close.\"; exit 1"
         # ⛔⭐⭐ A ROW EXISTS ONLY WHILE A MEASUREMENT SAYS THE PROBLEM EXISTS (Lon 2026-10-01, in-chat to the ceo:
         # "So get your findings=0 or whatever you need to get your act together and the fleet working real needed
         # work."; CEO-1386; RULES.md § FACT RULES). A mint that supplies NO DONE-WHEN used to write the placeholder
         # above and leave a row with no finish line; 80 such rows were live at the zero-base. Now it is REFUSED rc=2
         # with nothing written: a Lon word is minted with its WITNESS as the criterion. The one sanctioned exception
         # is a bus gate's fixture row, which names itself in S4E_MINT_NO_CRITERION; the baton carries the reason on
         # a MINTED-WITHOUT-CRITERION: line and the sweep retires such a row on sight.
         if ! printf '%s\n' "$goal" | grep -q '^DONE-WHEN:'; then
             if [ -n "${S4E_MINT_NO_CRITERION:-}" ]; then
                 dw_block="$dw_block
MINTED-WITHOUT-CRITERION: ${S4E_MINT_NO_CRITERION} (S4E_MINT_NO_CRITERION; CEO-1386 -- the sweep retires this row unless a real DONE-WHEN replaces the placeholder)"
             else
                 printf '⛔ REFUSED: no DONE-WHEN was supplied -- a row exists only while a measurement says the problem exists (CEO-1386).\n' >&2
                 printf '   Nothing was written: no QUEUE.tsv row, no baton. Mint again with the WITNESS as the criterion:\n' >&2
                 printf '      DONE-WHEN: bash ../harness/scripts/test_gate_<thing>.sh\n' >&2
                 printf '      DONE-WHEN: out=$(./scrip w.sno 2>&1); [ "$out" = "want" ] || exit 1; echo PASS\n' >&2
                 printf '   The failing program, the gate that reds, the SUITE TABLE row that is not 100%% -- never a sentence.\n' >&2
                 printf '   (A bus gate minting a FIXTURE row sets S4E_MINT_NO_CRITERION="why"; the baton records it.)\n' >&2
                 exit 2
             fi
         fi
         if printf '%s\n' "$goal" | grep -q '^DONE-WHEN:'; then
             dw_block="$(printf '%s\n' "$goal" | sed -n '/^DONE-WHEN:/,$p')"
             goal="$(printf '%s\n' "$goal" | sed '/^DONE-WHEN:/,$d')"
             # ⛔⭐ REFUSE A PROSE CRITERION AT THE MINT (row mint-refuses-a-done-when-whose-first-word-is-not-
             # a-command). rc=2 and not 1: this is a REFUSAL to create work, the same vocabulary the topic and
             # --owner guards above already speak, and the caller's criterion is handed back verbatim so the
             # fix is a re-mint and not an investigation.
             _dw_why="$(s4e_donewhen_unrunnable_why "$(printf '%s\n' "$dw_block" | sed '1s/^DONE-WHEN:[[:space:]]*//')")" && {
                 printf '⛔ REFUSED: the DONE-WHEN you supplied is not a runnable criterion -- %s.\n' "$_dw_why" >&2
                 printf '   Your DONE-WHEN: %s\n' "$(printf '%s\n' "$dw_block" | sed '1s/^DONE-WHEN:[[:space:]]*//' | head -1 | cut -c1-120)" >&2
                 printf '   Nothing was written: no QUEUE.tsv row, no baton. Fix the criterion and mint again.\n' >&2
                 printf '   ⛔ WHY THIS IS REFUSED HERE AND NOT LATER: `done` EXECUTES the DONE-WHEN, so a criterion\n' >&2
                 printf '      that cannot exit 0 makes the row PERMANENTLY UNCLOSEABLE -- it can be cured perfectly\n' >&2
                 printf '      and still record no flip, and the cost lands on whoever cures it, not on whoever minted it.\n' >&2
                 printf '   A DONE-WHEN is a COMMAND that can exit non-zero, never prose (LAW 1). The shape:\n' >&2
                 printf '      DONE-WHEN: bash ../harness/scripts/test_gate_<thing>.sh\n' >&2
                 printf '      DONE-WHEN: out=$(./scrip w.sno 2>&1); [ "$out" = "want" ] || exit 1; echo PASS\n' >&2
                 printf '   See any of %s/tasks/*.task.md for live examples.\n' "$PO" >&2
                 exit 2; }
         fi
         [ -n "$owner" ] || owner="$(s4e_topic_lane "$topic")"
         if [ -z "$owner" ]; then
           printf '⛔ REFUSED: cannot derive an owner lane for "%s" -- its name starts with no language prefix\n' "$topic" >&2
           printf '   (%s-*). Supply one: mint %s %s --owner <seat> "GOAL"\n' "$(s4e_lane_languages | tr ' ' '|')" "$topic" "$rank" >&2
           # ⛔ DERIVED, NEVER RESTATED. This line used to carry its own hand-written lane list and by
           # 2026-09-13 it was stale in a DIFFERENT direction from the table it was paraphrasing -- it read
           # "hq_I Icon suites" where hq_I is SNOCONE. A help text that confidently misnames a lane is worse
           # than none: it is read at exactly the moment someone does not know the answer.
           printf '   completeness owners, from the one table: %s\n' "$(s4e_lane_help)" >&2
           printf '   any standing seat may be named: %s\n' "$(s4e_hqboxes | tr '\n' ' ')" >&2
           exit 2; fi
         q="$PO/QUEUE.tsv"; d="$PO/QUEUE.done.tsv"; b="$PO/tasks/$topic.task.md"; mkdir -p "$PO/tasks"
         s4e_mint_dup() { grep -qP "^[0-9]+\t\Q$topic\E\t" "$q" 2>/dev/null && return 0
                           [ -f "$d" ] && grep -qP "^[0-9]+\t\Q$topic\E\t" "$d" 2>/dev/null && return 0
                           [ -f "$b" ]; }
         # Cheap pre-check OUTSIDE the lock — refuses the common case (an existing topic) without making
         # every mint wait on the lock for a duplicate that was always going to be refused. This is an
         # optimization, never the actual guard: the lock below re-checks for the real TOCTOU race.
         if s4e_mint_dup; then echo "⛔ REFUSED: '$topic' already exists (a live QUEUE.tsv row, a QUEUE.done.tsv row, or an existing task file) — pick a different name." >&2; exit 1; fi
         # ⭐ THE ATOMIC APPEND THE GOAL DEMANDS. QUEUE.tsv is ONE FILE every topic's row shares, unlike a
         # claim (one file per topic, where the `ln` hard-link trick above is already atomic per-target) — so
         # the lock is a DIRECTORY, not the row: mkdir is atomic on every POSIX filesystem, same guarantee
         # `ln` leans on, just scoped to the whole file instead of one name in it.
         lock="$PO/.mint.lock"; got=0
         for _i in $(seq 1 50); do mkdir "$lock" 2>/dev/null && { got=1; break; }; sleep 0.1; done
         [ "$got" = 1 ] || { echo "⛔ REFUSED: could not acquire the mint lock ($lock) after 5s — another mint is stuck or crashed holding it. Investigate before removing it by hand; do not rm -rf blindly." >&2; exit 3; }
         # ⛔ COMPOSED WITH THE IDENTITY LOCK, NOT LAYERED OVER IT. A bare `trap ... EXIT` here CLOBBERS the
         # one-process-per-identity release armed at startup, and the `trap - EXIT` below then removes it
         # outright -- so every successful `mint` would leak its own .pid. (Self-healing on the next verb via
         # the liveness check, but a lock file naming a dead process is exactly the stale evidence this row
         # exists to stop manufacturing.) Both handlers run, in order, from one trap.
         trap 'rmdir "$lock" 2>/dev/null; s4e_pid_release' EXIT
         if s4e_mint_dup; then echo "⛔ REFUSED: '$topic' was minted by someone else in the race just now — no torn row written, nothing lost." >&2; exit 1; fi
         # Baton BEFORE the queue row, deliberately: a crash between the two writes then leaves an orphan
         # task file (inert — nobody's picker ever finds a file next() never points at) rather than a live
         # QUEUE.tsv row with no baton behind it, which next()'s own "⛔ NO BATON" path can only catch AFTER
         # some seat has already been served the row.
         # ⛔ $goal and $dw_block were split, and the criterion LINTED, before the lock was taken -- see the
         # hoisted block above. Nothing here may re-derive them: a second split would silently re-admit the
         # prose criterion the guard just refused.
         # ⛔⭐ THE PREMISE FIELD IS WRITTEN AT THE MINT, MARKED UNEXPRESSED RATHER THAN OMITTED (coo 2026-09-20,
         # row instruments-claim-computes-the-rows-premise-...). A field that only exists once somebody remembers
         # it is the shape this whole row exists to end: the minter is the ONE reader who knows what the row
         # assumes, and they are looking at the file exactly once. So the line is here, empty and labelled, at the
         # moment it is cheapest to fill. ⛔ THE PLACEHOLDER NEVER REFUSES A LOCK -- s4e_premise_gate admits it with
         # a named "UNVERIFIED" note -- because a row must never be born unclaimable; that is the opposite error
         # from the DONE-WHEN placeholder, which is deliberately RED (a row not yet closeable is honest; a row not
         # yet claimable is a mint that blocks work). Supply a real one by writing PREMISE-WHEN: under your
         # DONE-WHEN in the minted text and this placeholder is not added.
         pw_block="PREMISE-WHEN: ⛔ NOT EXPRESSED -- replace this with the ONE CHEAP COMMAND that proves this row's central claim is still true on today's tree. It is run by \`claim\` and \`next\`, and a RED one refuses the lock and says the row needs rewriting. Until it is written, this row is dispatched with its premise UNCHECKED."
         if printf '%s\n' "$dw_block" | grep -q '^PREMISE-WHEN:'; then pw_block=""; fi
         cat > "$b" <<TASKEOF
# TASK $topic
GOAL: $goal
$dw_block${pw_block:+
$pw_block}
LINKS: minted via \`mint\` by $ME, $(date -u +%FT%TZ)
## NEXT
Distill a real first step from the GOAL above (and a real DONE-WHEN — see the line above), then work it.
## QA
## LEDGER
- [$ME·$(date -u +%F)] Minted via \`s4e_msg.sh mint\`.
TASKEOF
         # ⛔⭐ THE ONE-NEXT-BLOCK RULE IS ENFORCED WHERE A BATON IS WRITTEN, NOT BY A SWEEP (ceo, CEO-1116,
         # 2026-09-22, on the coo's finding of 9 non-conforming live batons against a ratchet ceiling of 1 over
         # 782 checked).  test_gate_baton_one_next_block.sh is unwired BY A ceo RULING OF 2026-09-03 because it
         # reads the LIVE postoffice and reds whenever another seat is mid-edit, so the drift to nine is the
         # PRICE of that ruling rather than an oversight -- and a periodic sweep over shared concurrently-edited
         # state can only ever REPORT, while a writer-side check PREVENTS.  A mint cannot CREATE a second
         # NEXT block from here on; the GOAL text is interpolated into this heredoc, so a goal carrying its own
         # "## NEXT" line is the one way this path could ever have minted a non-conforming baton.
         # ⛔ NOT `grep -c ... || printf 0`: grep -c on ZERO matches PRINTS "0" and still EXITS 1, so a || arm
         # fires anyway and appends a SECOND "0" -- the trap this tree's own gate documents at its scanner.
         _nn="$(grep -c '^## NEXT' "$b" 2>/dev/null || true)"; _nn="${_nn:-0}"
         if [ "$_nn" != 1 ]; then
           rm -f "$b"; rmdir "$lock" 2>/dev/null
           printf '⛔ REFUSED (rc=2): this mint would write a baton carrying %s "## NEXT" heading(s), not exactly one.\n' "$_nn" >&2
           printf '   The GOAL text is interpolated into the baton, so a GOAL containing its own "## NEXT" line is\n' >&2
           printf '   the cause. Nothing was written: no baton, no QUEUE row. Re-mint with that line out of the GOAL.\n' >&2
           printf '   WHY THIS REFUSES RATHER THAN WARNS: `next` tells every seat to work the ONE ## NEXT block, so a\n' >&2
           printf '   baton with two hands the seat a FIRST block that may not be the live one -- hq_B measured five\n' >&2
           printf '   Icon batons scrambled 3-1-2-5-4 on a LIVE rank-1 row (2026-08-29), which is this rule\x27s origin.\n' >&2
           exit 2
         fi
         printf '%s\t%s\t%s\tFREE\n' "$rank" "$topic" "$owner" >> "$q"
         rmdir "$lock" 2>/dev/null; trap 's4e_pid_release' EXIT
         echo "minted $topic (rank $rank, owner $owner, state FREE) -> $b"
         [ -n "$pw_block" ] && {
           printf '⚠ NO PREMISE-WHEN — you are the one reader who knows what this row ASSUMES, and you are looking at\n' >&2
           printf '  it right now. Write the one cheap command that proves that assumption still holds, into %s:\n' "$b" >&2
           printf '      PREMISE-WHEN: grep -q "the thing this row is built on" src/path/file.c\n' >&2
           printf '  `claim` and `next` run it and REFUSE the lock when it goes red, so the row gets rewritten instead of\n' >&2
           printf '  worked. Six seats lost an hour each to a stale premise on 2026-09-20; every one was cheap to check.\n' >&2; }
         exit 0;;
  next)  q="$PO/QUEUE.tsv"; mkdir -p "$PO/claims"
         s4e_mode_line
         # ⛔⭐ MODE GATES DISPATCH -- IT IS NOT DECORATION (row next-refuses-to-dispatch-to-an-hq-seat-when-mode-
         # line-1-is-ceo; hq_C measured 2026-09-03 18:51). `next` printed "MODE: CEO" and dispatched in the SAME
         # PRINTOUT: it served and LOCKED prolog-bagof-setof-...-rung-8b to hq_C at a moment when no HQ was standing.
         # ⛔ The damage is not the wasted turn, it is the LOCK: a claimed row leaves the picker, so a stood-down
         # identity holding a claim HIDES THAT ROW FROM THE WHOLE FLEET -- and it arrives by a route nobody watches.
         # `fleet` is the health view for a seat that STALLS; it has nothing to say about one that was never meant to
         # be running at all. Reading a value only to PRINT it is the same class as the board that computed its
         # failure names and sent them to /dev/null: the information was produced and then not used.
         # ⛔ THE ceo IS NEVER REFUSED. s4e_is_hq() deliberately counts ceo as an HQ (it is an AUTHORITY test, used by
         # unclaim's force path), but under MODE CEO the ceo is precisely who works the rows. So this guard matches on
         # the IDENTITY SHAPE and must NOT be rewritten to call that predicate -- they answer different questions.
         # ⛔ AN ABSENT OR EMPTY MODE DOES NOT REFUSE HERE: s4e_mode_line above already says so loudly, and every
         # existing s4e gate fixture omits the file. Turning that into a refusal is a different row, not a free extra.
         _mode="$(head -1 "$PO/MODE" 2>/dev/null | tr -d '[:space:]')"
         _refuse_dispatch() {
             printf '⛔ REFUSING TO DISPATCH (rc=2): you are %s, %s, and MODE line 1 is %s.\n' "$ME" "$1" "$_mode" >&2
             printf '   Authority: %s/MODE (first line). %s\n' "$PO" "$2" >&2
             printf '   A claim taken by a stood-down identity HIDES that row from the whole fleet -- which is why this\n' >&2
             printf '   is a REFUSAL and not a warning. If the mode is wrong, ask ceo to publish the real one.\n' >&2
             exit 2; }
         # ⛔ THE GUARD BODY MOVED TO s4e_mode_stands (coo 2026-09-20, CEO-1002) so the announcing half can ask it about
         # OTHER seats. Same table, same refusals, same authority -- this line is the only thing that changed here.
         _REFUSE_KIND=""; _REFUSE_WHY=""
         s4e_mode_stands "$ME" "$_mode" || _refuse_dispatch "$_REFUSE_KIND" "$_REFUSE_WHY"
         # ⭐ ONE scratch file for this whole dispatch: `next` takes its lock by running `$0 claim` with both streams
         # suppressed, and the announcement (ceo CEO-1002) has to survive that. Created here, before any serve path,
         # because BOTH lock sites below -- the ordinary serve and the dependency-inversion promotion -- re-print from it.
         # ⛔ NO EXIT TRAP HERE, DELIBERATELY: s4e_pid_arm already owns EXIT (it releases this seat's pid lock), and a
         # second `trap ... EXIT` REPLACES the first rather than adding to it -- a one-line scratch-file convenience
         # would have silently disarmed the pid lock release for every `next`. The file is removed at each use instead.
         _cl_out="$(mktemp "${TMPDIR:-/tmp}/s4e_claim.XXXXXX")"
         # ⛔⭐ s265 — A STALE CLONE SILENTLY REVERTS TO PRE-V2 DISPATCH, AND THAT IS NOW A REFUSAL, NOT A WARNING.
         # Measured the same day by TWO seats: seat09's clone was 79 commits behind and seat13's was 2, so both ran
         # v1's flat file-order picker — no rank sort, no assign-awareness. seat09 locked a rank-1 row while its own
         # HQ assignment sat unserved; seat13 locked rank 4 while ~30 rank-0 rows were FREE. Neither got any warning,
         # because the V2 fix only ever protected a seat whose clone ALREADY had it. ⛔ The check cannot be "git fetch
         # and compare" — a seat that never pulled has a stale origin/main too, so that test passes precisely when it
         # must fail. So the authority is the SHARED postoffice, which no clone can be behind: PROTOCOL-VERSION there
         # is the required protocol, S4E_PROTO below is this script's own, and next() REFUSES rather than dispatching
         # from a picker it cannot vouch for. A seat that mis-locks a row removes it from the whole fleet's reach.
         # (S4E_PROTO is hoisted above the case dispatch — one number, two guards: this one and clear's.)
         if [ -f "$PO/PROTOCOL-VERSION" ]; then
           need="$(head -1 "$PO/PROTOCOL-VERSION" | tr -cd '0-9')"; need="${need:-0}"
           if [ "$S4E_PROTO" -lt "$need" ]; then
             echo "⛔ REFUSING TO DISPATCH — your s4e_msg.sh is PROTOCOL $S4E_PROTO, the fleet is on $need."
             echo "   Your clone is behind origin and would run the OLD picker: no rank sort, no assign-awareness."
             echo "   That mis-locks a row and HIDES IT FROM THE WHOLE FLEET (a claimed row leaves the picker)."
             echo "   Fix, then re-run:  cd \"$S4E/SCRIP\" && git pull --rebase origin main"
             exit 3; fi; fi
         # ⭐ V2-1 SERVE ORDER (LAW 2): my-ASSIGNED  ->  my-unfinished  ->  RANK-SORTED free.
         # v1 served the topmost row in FILE ORDER, which made rank decorative: 53 rank-0 rows sat buried behind lesser
         # ones, and the deliberately fenced rank-99 M1 gate row was one claim away from being served as ordinary work.
         # ONE matcher for BOTH the presence test and the brief print, so they cannot disagree (that disagreement IS a bug
         # this row fixes). Row absent => the claim is an ORPHAN: renamed or retired out from under its holder (HQ LAW 14).
         # Skip it, SAY WHY, keep the claim (it is the record), fall through to live work. ORPHAN-SKIP IS DISARMED WHEN THE
         # QUEUE ITSELF IS DEAD: a missing/empty QUEUE.tsv would make EVERY claim look orphaned and unpin the whole fleet
         # at once -- an infrastructure failure is not a rename, so we pin and say so.
         qrows="$(grep -cP '^[0-9]+\t' "$q" 2>/dev/null)"; qrows="${qrows:-0}"   # qrow/qrank are top-level now, shared with banner()
         # ONE printer for every serve path, so a resumed row and a freshly locked row can never describe themselves differently.
         serve() { local st="$1" verb="$2" sfx="${3:-}" srow; srow="$(qrow "$st")"; printf '%s %s %s\n' "$verb" "$st" "$sfx"
           if [ -f "$PO/tasks/$st.task.md" ]; then printf 'task: %s\n' "$PO/tasks/$st.task.md"
             printf '      ⭐ THE BATON IS THE TASK FILE, NOT THIS PRINTOUT — read GOAL + DONE-WHEN + the ONE ## NEXT block,\n'
             printf '      work THAT, then rewrite ## NEXT before you stop. Questions go in ## QA, receipts in ## LEDGER.\n'
             printf '      ⛔ the current block is the FIRST ^## NEXT — demote the one you replace to ## SUPERSEDED-NEXT\n'
             printf '      (baton-one-next-block-gate, ceo ruling 2026-08-29; a few live batons still predate this).\n'
             printf '      ⛔ a baton with NO ## NEXT block: distill one from GOAL + the latest ledger, write it, THEN work.\n'; fi
           # ⭐ V2-2: QUEUE.tsv is an INDEX (rank·topic·owner·state), not a brief store. Fields 3 and 4 are
           # owner and state now, so printing them as "brief:"/"first:" would announce "brief: unassigned".
           # The baton is the content; the index only says who owns it and what state it is in.
           printf '%s\n' "$srow" | awk -F'\t' 'NF>3{print "owner: " $3 "   state: " $4}
                                                  NF>1&&NF<4{print "brief: " $3; print "first: " $4}'
           [ -f "$PO/tasks/$st.task.md" ] || printf '⛔ NO BATON at %s/tasks/%s.task.md — under V2-2 every live row must have one. Tell your HQ; do not invent the work.\n' "$PO" "$st"; }
         # ⭐⭐ THE LANE FILTER LIVED ONLY IN PASS 3, AND A RE-SEATING WALKS STRAIGHT PAST IT (hq_B, ceo witness
         # 2026-09-03 22:55 CDT). MEASURED: seat07 held raku-roast-100-percent-compile (lane hq_T) while its own
         # lane's rank-0 SC4 snocone census sat FREE. The claim carried NO `ASSIGNED-BY` line, so no HQ dispatched
         # it across lanes; and the CONTROL ARM proves the free-row picker did not either -- with the claim removed,
         # PASS 3 skips that row unconditionally on its owner cell (`↩ skipped 4 free row(s) owned by another seat`).
         # What served it was PASS 2, which resumes ANY unfinished claim of mine with no lane check and no owner-cell
         # check at all. ⛔ A SEAT'S LANE IS MUTABLE AND ITS CLAIM IS NOT: seat07's HQ file was rewritten hq_T -> hq_P
         # at 22:45:05, ten minutes before the release, so a claim that was PERFECTLY IN-LANE when it was taken became
         # cross-lane while it was held. Nothing re-asks the question after a serve, so `next` re-served it every turn.
         # ⛔ THE CURE IS A NOTICE, NEVER AN AUTO-RELEASE. Dropping an in-flight claim to chase a lane would strand
         # real work, and a cross-lane hold is often DELIBERATE -- an HQ may assign across lanes on purpose (PASS 1
         # rows carry ASSIGNED-BY and are attributable already). So this says the mismatch out loud and names the
         # own-lane row that is waiting, and a human decides: keep working, or `unclaim` and let the owner have it.
         # ⭐ Same doctrine PASS 3 already runs on -- "a silent skip is indistinguishable from the row not existing",
         # and its cross-lane fallback is labelled rather than left to be reconstructed from the queue later. A serve
         # that cannot be told from an in-lane one is exactly how this went unseen until the ceo read two claims side
         # by side. ⛔ It NEVER refuses and never changes the exit status: a notice that can block is a notice that
         # gets worked around. Lane-undetermined topics and a seat with no readable HQ file stay silent (empty lane
         # is UNDETERMINED, never a fifth lane), so a missing HQ file degrades to today's behaviour, as everywhere else.
         # ⛔ THE TWO ARRIVAL PATHS ARE NOT THE SAME EVENT AND MUST NOT READ THE SAME. A PASS-1 row was DISPATCHED
         # across lanes by a named HQ (its claim carries ASSIGNED-BY): deliberate, attributable, and the notice only
         # makes it visible. A PASS-2 row is one the seat is holding, where the lane may have moved underneath it and
         # NOBODY decided anything -- that is the defect. Printing the PASS-2 explanation over a PASS-1 serve would
         # accuse an HQ of a slip it did not commit, which is the same class of false attribution as an unlabelled
         # cross-lane serve: a printout that describes a different event than the one that happened.
         s4e_cross_lane_notice() { local _t="$1" _via="$2" _tl _wait
           [ -n "${_my_lane:-}" ] || return 0
           _tl="$(s4e_topic_lane "$_t")"; [ -n "$_tl" ] || return 0; [ "$_tl" != "$_my_lane" ] || return 0
           printf '⛔ CROSS-LANE HOLD — %s is %s'"'"'s lane; your lane is %s (%s/%s/HQ).\n' "$_t" "$_tl" "$_my_lane" "$PO" "$ME"
           case "$_via" in
             assigned) printf '   An HQ DISPATCHED this to you across lanes on purpose -- the claim names who, above. Nothing is\n'
                       printf '   wrong here; you are told because a cross-lane serve must be legible in its own printout.\n';;
             *)        printf '   You are being served it because it is YOUR CLAIM, not because it is your work: the resume pass\n'
                       printf '   never re-asks the lane question, and a RE-SEATING CHANGES YOUR LANE UNDER A HELD CLAIM.\n';;
           esac
           _wait="$(awk -F'\t' -v me="$ME" -v lane="$_my_lane" '/^[0-9]+\t/ && ($4=="FREE"||$4=="") && ($3==lane||$3==me) {printf "%s\trank %s  %s  (owner %s)\n",$1,$1,$2,$3}' "$q" 2>/dev/null | sort -t$'\t' -s -k1,1n | head -1 | cut -f2-)"
           if [ -n "$_wait" ]; then printf '   ⭐ WAITING IN YOUR OWN LANE:  %s\n' "$_wait"
             printf '      A row owned by YOUR OWN HQ is now auto-served (cured 2026-09-04: the owner-cell skip treated an HQ\n'
             printf '      like a rival seat and idled six seats at once). A row owned by a DIFFERENT HQ still needs a\n'
             printf '      deliberate dispatch: that HQ or the ceo runs  s4e_msg.sh assign <topic> %s\n' "$ME"; fi
           printf '   KEEP WORKING IT if that was the intent -- this is a NOTICE, NOT A REFUSAL, and the exit status is\n'
           printf '   unchanged. Otherwise put it back for its owner:  s4e_msg.sh unclaim %s\n' "$_t"; }
         # ⭐ HOISTED: the lane is needed by PASS 1 and PASS 2 as well as PASS 3 now, so it is computed ONCE here
         # rather than re-derived per pass -- two readings of one seat's HQ file could disagree mid-run otherwise.
         _my_lane="$(s4e_my_lane)"
         # PASS 1 -- rows an HQ ASSIGNED to me that I have not started. These outrank anything I picked for myself.
         # ⭐⭐ TIE-BREAK MATCHES PASS 3: rank, THEN mint time (newest first; a topic with no readable mint
         # timestamp sorts last). MEASURED 2026-09-03 on seat11's FLEET-12 dispatch: their three assigned rows
         # were rank 2, 2 and 3, and PASS 1 sorted by RANK ALONE -- so the two rank-2 rows tied and the stable
         # sort fell back to the claims/*.claim GLOB ORDER, i.e. alphabetical. seat11 was served
         # raku-array-params-pass-by-copy where the dispatch had named raku-silent-wrong-answers first.
         # ⛔ TWO PASSES WITH TWO TIE-BREAKS, AND ONLY ONE OF THEM WAS EVER CHOSEN: PASS 3 fixed exactly this
         # for free rows (its own note: eight freshly-minted rank-1 slices sat 40+ minutes behind 15 older
         # ones) and the fix was simply never applied to assigned rows. Alphabetical order is not a priority
         # signal, it is an artifact of naming -- the same class as the file-order picking V2-1 removed.
         # ⭐ The deeper point, which the ceo took as the ruling for seat11: AN ORDER STATED IN PROSE ACROSS
         # EQUAL RANKS IS INVISIBLE TO THE PICKER. Rank is the only ordering the tool can see. This makes the
         # tie DETERMINISTIC and documented; it does not make prose orderable, and it should not be read as
         # doing so -- an intended order still has to be encoded as rank.
         # ⭐ RANK-SORTED even among MY OWN claims (fix-dispatch-bus-two-failure-modes, s266, seat07's
         # q-s4e-msg-banner-attribution-undercount): this used to be a bare glob loop, so a seat holding TWO
         # assigned-not-yet-running claims was served whichever topic sorted first ALPHABETICALLY, not the
         # fleet's own rank priority. Same defect shape V2-1 already fixed for Pass 3 (free rows); it had
         # just never been applied to "mine" too. Candidates are gathered first, THEN sorted by qrank, THEN
         # served -- one lowest-rank winner, deterministic regardless of claims/ directory order.
         while IFS=$'\t' read -r _rk t; do
           [ -n "${t:-}" ] || continue
           c="$PO/claims/$t.claim"
           # ⛔⭐ THE ASSIGNED ROW IS GATED HERE AND NOWHERE ELSE, AND THIS IS THE PATH THAT MATTERS MOST:
           # an assigned row never passes through `claim` at all (the HQ wrote the lock), so wiring the premise
           # only into `claim` would leave the fleet's COMMONEST dispatch -- ASSIGNED->RUNNING -- completely
           # unchecked, which is the half-wired shape s4e_dispatch_gate's own comment was written about.
           # ⛔ THE LOCK ALREADY EXISTS, so the refusal cannot decline to take it; the analogue is to decline to
           # START -- the row stays ASSIGNED, unflipped, un-served, and the seat reads why. Refusing to serve is
           # not unclaiming: putting the row back is the HQ's call or an explicit `unclaim`, never a side effect.
           s4e_premise_gate "$t" next || continue
           echo "RUNNING" >> "$c"
           s4e_cross_lane_notice "$t" assigned
           serve "$t" "ASSIGNED->RUNNING" "(dispatched by $(grep -m1 '^ASSIGNED-BY ' "$c" | cut -d' ' -f2))"; exit 0
         done < <(for c in "$PO"/claims/*.claim; do [ -f "$c" ] || continue
             [ "$(head -1 "$c")" = "$ME" ] || continue
             grep -q '^DONE$' "$c" && continue
             grep -q '^ASSIGNED-BY ' "$c" || continue
             grep -q '^RUNNING$' "$c" && continue
             t="$(basename "$c" .claim)"; printf '%s\t%s\t%s\n' "$(qrank "$t")" "$(s4e_mint_ts "$t")" "$t"
           done | sort -t$'\t' -s -k1,1n -k2,2r | cut -f1,3-)
         # PASS 2 -- my own unfinished work, same rank-sort fix, same reason.
         while IFS=$'\t' read -r _rk t; do
           [ -n "${t:-}" ] || continue
           c="$PO/claims/$t.claim"; row="$(qrow "$t")"
           if [ -z "$row" ] && [ "$qrows" -gt 0 ]; then
             echo "SKIP $t — your unfinished claim names a topic with NO QUEUE.tsv row (renamed or retired out from under you). Claim KEPT as the record; falling through to live work. If you were mid-rung on it: s4e_msg.sh ask $t 'row vanished under me'"
             continue; fi
           if [ -z "$row" ]; then
             echo "⛔ $q IS MISSING OR HAS NO ROWS — cannot tell a renamed row from an unreadable queue, so RESUMING $t rather than unpinning you. Ask hq before trusting any next(1) verdict."; fi
           grep -q '^RUNNING$' "$c" || echo "RUNNING" >> "$c"
           s4e_cross_lane_notice "$t" resume
           serve "$t" "RESUME" "(yours, unfinished — s4e_msg.sh done $t when the handoff clause is met)"; exit 0
         done < <(for c in "$PO"/claims/*.claim; do [ -f "$c" ] || continue
             [ "$(head -1 "$c")" = "$ME" ] || continue
             grep -q '^DONE$' "$c" && continue
             t="$(basename "$c" .claim)"; printf '%s\t%s\n' "$(qrank "$t")" "$t"
           done | sort -t$'\t' -s -k1,1n)
         [ -f "$q" ] || { echo "no QUEUE.tsv — ask hq"; exit 1; }
         # PASS 3 -- free rows, RANK-SORTED numerically; ties inside one rank now tie-break by MINT TIME,
         # newest first (next-tiebreak-by-mint-time-not-file-order, hq_C finding, ceo mint 2026-09-01) --
         # was file order (QUEUE.tsv line position, an accident of mint sequence, not a priority signal:
         # measured, eight freshly-minted rank-1 fleet slices sat unclaimed 40+ minutes behind 15 older
         # rank-1 rows). A topic with no readable mint timestamp sorts as OLDEST in its tier (s4e_mint_ts),
         # never specially -- so this degrades to the old behaviour only in the absence of data, not by design.
         _owned_skipped=0; _owned_first=""
         _rankcap_skipped=0; _rankcap_first=""
         # ⛔ ONE LINE, NOT ONE PER ROW -- the same ruling as the owned-skip report below it, and my first
         # draft got it wrong. Under THE FLEET-12 PLAN ranks 6-9 are a whole tier, so a seat with a quiet
         # lane can meet a dozen of them in one pick; per-row refusals would bury the serve they precede.
         # But it is never SILENT: a skip nobody can see is indistinguishable from the row not existing,
         # which is the failure this picker keeps being fixed for. The GOAL says it in one clause --
         # "skips FREE rows of rank >= 6 ... AND PRINTS HOW MANY IT SKIPPED".
         s4e_report_rankcap_skips() {
           [ "${_rankcap_skipped:-0}" -gt 0 ] || return 0
           printf '↩ skipped %d free row(s) at rank 6+ (HQ-ONLY tier, topmost: %s).\n' "$_rankcap_skipped" "$_rankcap_first"
           printf '   THE FLEET-12 PLAN: seats take bounded rows, rank 0-5; ranks 6-9 are HQ/cto work.\n'
           printf '   If you believe one is yours, ask your HQ; the deliberate override is: s4e_msg.sh claim <topic>.\n'; }
         # ⛔ ONE line, not one per row: 18 of 178 FREE rows carry a named owner today, so per-row skip lines would
         # bury the serve they precede. But it is never SILENT -- a skip nobody can see is indistinguishable from
         # the row not existing, which is the failure this whole picker keeps being fixed for.
         s4e_report_owned_skips() {
           [ "${_owned_skipped:-0}" -gt 0 ] || return 0
           printf '↩ skipped %d free row(s) owned by another seat (topmost: %s).\n' "$_owned_skipped" "$_owned_first"
           printf '   The owner column constrains the pick (ceo 2026-09-03). To take one anyway: s4e_msg.sh claim <topic>.\n'
           # ⛔ THIS LINE WAS WRONG TWICE OVER (hq_B 2026-09-13, ceo CEO-672): it named `assign`, which writes a
           # CLAIM and never touches column 3, and it stated assign's arguments in the wrong order (assign takes
           # <seat> <topic>). It is the line a seat reads at the exact moment they do not know how to move a row
           # -- the worst place for confident wrong guidance, and the reason part 2 of CEO-672 had no tool.
           printf '   To move ownership properly, an HQ or the ceo runs: s4e_msg.sh reown <seat> <topic>.\n'
           printf '   (reown changes the OWNER CELL; assign <seat> <topic> writes the CLAIM. Two different acts.)\n'; }
         s4e_pass3_scan() {
           # ⛔ RESET PER PASS, NOT PER next() -- s4e_pass3_scan is called TWICE (own-lane, then any-lane) and a
           # counter initialised outside it counts every skipped row once per pass. Measured: three rank-6+ rows
           # in a scratch queue reported "skipped 6". The honest number is the LAST pass's, because that is the
           # pass that actually gave up and produced the report the seat is reading.
           # ⛔ THE OWNED-ROW COUNTER HAD THE SAME DEFECT AND KEPT IT: one ceo-owned row read "skipped 2 free row(s)
           # owned by another seat" for any seat with a lane (coo 2026-09-26, measured on a TENET fixture).
           _rankcap_skipped=0; _rankcap_first=""; _owned_skipped=0; _owned_first=""
         while IFS=$'\t' read -r rank topic brief step; do
           case "$rank" in ''|\#*) continue;; esac
           # ⛔ s265 — THE STATE COLUMN IS LOAD-BEARING NOW. It was decorative (94 of 94 rows FREE, nothing read it),
           # which is how `161-o2-red` — PARKED BY LON at s258, and saying so in its own baton — kept being served as
           # the fleet's TOPMOST rank-0 row. A ruling that only a human enforces is not a ruling. Anything not FREE is
           # not work: PARKED, BLOCKED, DONE all skip here.
           # ⭐ picker-skips-blocked-rows (ceo, 2026-08-28): a BLOCKED-ON:<topic>/PARKED-AWAITING:<topic> row used
           # to skip HERE FOREVER, even the session AFTER its named blocker landed DONE, because nothing ever asked
           # again — bench-rivals-raku-pascal sat encoded as plain "FREE" (nobody had even written the block down)
           # through 9+ seats independently re-discovering the identical block, which is the OTHER half of this same
           # defect: a block a human found but never RECORDED is invisible to a check that only reads the column.
           # Self-heals: a resolved dependency lets next() skip past a stale BLOCKED-ON state instead of honoring
           # it forever — re-ask whether the named blocker is done EVERY time this row is considered, and if so
           # `park` the row back to FREE right here (ledger line included) before falling through to the check below.
           case "$step" in
             BLOCKED-ON:*|PARKED-AWAITING:*)
               blk="${step#*:}"
               resolved_blk="$(s4e_first_resolved_blocker "$blk")"
               if [ -n "$resolved_blk" ] && s4e_does_not_clear "$resolved_blk" "$topic"; then
                 # ⭐ s4e-done-does-not-clear-annotation: the blocker IS done, but named THIS topic as an
                 # exception -- honour it instead of the ordinary self-clear. Print the annotation itself,
                 # not just a verdict, per the row's own DONE-WHEN ("prints the annotation text").
                 printf '⛔ %s reached DONE but its state explicitly excludes %s from self-clear (DOES-NOT-CLEAR) — staying %s.\n' "$resolved_blk" "$topic" "$step" >&2
                 printf '   %s state: %s\n' "$resolved_blk" "$(s4e_row_state "$resolved_blk")" >&2
               elif [ -n "$resolved_blk" ] && "$0" park "$topic" FREE >/dev/null 2>&1; then step=FREE
               # ⭐ CURE 1 — DEPENDENCY INVERSION (picker-dependency-and-boomerang-blindness). The blocker is
               # un-DONE, so the old code skipped this row and walked on down the rank order — which is how a
               # blocker RANKED BELOW the umbrella it blocks got served after the work it blocks. Reaching this
               # row at rank N is itself the proof that its blocker deserves rank N: serve the BLOCKER, here.
               elif promo="$(s4e_servable_blocker "$topic")" && [ -n "$promo" ] && s4e_promotion_admissible "$promo" "$topic" "$rank" \
                    && s4e_promotion_placeholder_ok "$promo" "$topic" "$rank" && "$0" claim "$promo" >"$_cl_out" 2>&1; then
                 sed -n '/^-- the neighbourhood/,$p' "$_cl_out"; rm -f "$_cl_out"
                 echo "RUNNING" >> "$PO/claims/$promo.claim"
                 # ⛔ THE PROMOTED BLOCKER IS A SERVED ROW LIKE ANY OTHER, so it is probed like any other. A
                 # blocker that is already satisfied is the WORST row to hand out unprobed: it is blocking
                 # something else, so closing it here also un-blocks the row that named it.
                 s4e_dispatch_gate "$promo" "$rank" || continue
                 # ⭐ THE CHAIN, NOT THE FIRST HOP -- see s4e_blocker_chain: a transitive promotion printed the first
                 # hop as "un-DONE, unclaimed and FREE" and served a row the line never named (the ceo, case (b)).
                 printf '⭐ DEPENDENCY INVERSION — rank-%s %s is BLOCKED-ON %s; %s is un-DONE, unclaimed and FREE.\n' "$rank" "$topic" "$(s4e_blocker_chain "$topic" "$promo")" "$promo"
                 printf '   Rank is a human guess at priority; a dependency is a fact, and a fact outranks a guess.\n'
                 printf '   You are being served THE BLOCKER at the blocked row'"'"'s own rank position.\n'
                 printf '   When %s lands DONE, %s un-blocks ITSELF — its state column is the self-clearing spelling.\n' "$promo" "$topic"
                 serve "$promo" "LOCKED" "(promoted over blocked $topic, rank $rank)"; exit 0
               fi ;;
           esac
           # ⭐ CURE 3 — GOVERNANCE-GATED ROWS SKIP HERE, ATTRIBUTABLY. The generic non-FREE skip below would
           # drop these too, but silently and indistinguishably from a park — and "indistinguishable from a
           # park" is the whole defect: a grant-wait that reads as a park gets `park FREE`d back into the
           # picker by the next tidy-minded seat, and the seven-re-serves-in-one-day loop restarts. Named here
           # so the state is legible to a -x trace, to the QUEUE-EMPTY report below, and to the park refusal.
           if s4e_is_grant_wait "$step"; then continue; fi
           # ⭐ RESTRICTED:<x> IS SERVABLE, BUT ONLY TO x. Unlike ASSIGNED (which hides a row from everyone, its owner
           # included, so the owner must reach for `claim`), a restriction names who MAY work it -- so the picker can and
           # should hand it to that seat. Everyone else falls through to the generic skip below, as before.
           # ⭐⭐ THE OWNER COLUMN CONSTRAINS THE PICK (ceo ruling 2026-09-03, on hq_B's measured case).
           # MEASURED: `next` served hq_B the rank-0 row port-exit-value-contract-untagged-rax-forges-dt-fail
           # whose owner column read hq_P. The picker ordered by rank and read only the STATE column, so
           # ownership was advisory AT THE MOMENT OF THE PICK -- a rank-0 row tagged to a seat in flight went to
           # whoever typed `next` first. That is fine when the owner is idle and wrong when they are working it,
           # and the picker cannot tell the difference, so it must not guess.
           # ⛔ THE COST OF GUESSING IS ASYMMETRIC AND THAT IS WHY THE DEFAULT IS SKIP: a wrongly-served row makes
           # TWO seats hold one piece of work (and a claim HIDES the row from its owner's own picker, so the owner
           # is locked out silently); a wrongly-skipped row costs one `claim` typed on purpose.
           # ⭐ `assign` remains the HQ/ceo verb that MOVES ownership, and `claim <topic>` is the deliberate
           # override -- neither is touched here. Only the automatic pick is constrained.
           _serve_reason="rank $rank"
           case "$step" in
             FREE|'')
               case "$brief" in
                 ''|unassigned) : ;;
                 "$ME") _serve_reason="rank $rank, your OWNER CELL" ;;
                 # ⛔⭐ A ROW OWNED BY THE SEAT'S OWN HQ IS IN THE SEAT'S LANE AND IS SERVED (ceo, URGENT
                 # 2026-09-04 19:52: SIX SEATS IDLE at load 0.65 with sixteen up, every lane reporting "queue
                 # empty" while QUEUE.tsv held 7 FREE rank<=1 rows per lane). The owner-cell skip treated an HQ
                 # exactly like a rival seat -- and under THE SNOBOL4 CUT every class row an HQ mints carries its
                 # OWN owner cell, so the picker skipped the entire body of assigned work in every lane at once.
                 # seat09's words, verbatim: "all in-lane FREE rows are owned by other seats or by hq_P itself".
                 # ⛔ THE SKIP'S OWN ASYMMETRY ARGUMENT DOES NOT REACH THIS CASE, and that is the whole cure.
                 # It reads: a wrongly-SERVED row makes two seats hold one piece of work, a wrongly-SKIPPED row
                 # costs one `claim` typed on purpose -- so when in doubt, skip. True of a row owned by another
                 # SEAT, which may be about to work it. NOT true of a row owned by an HQ: an HQ owner cell marks
                 # a LANE, not work in flight, and an HQ that is actually working a row has CLAIMED it -- and a
                 # claimed row is already hidden from every picker. So the doubt the skip exists to resolve does
                 # not exist here, and the cost it was weighing was one-sided all along.
                 # ⭐ THE GENERAL FORM, worth more than this line: a guard justified by a cost asymmetry must be
                 # re-checked wherever the asymmetry stops holding. This one was written about seats and applied
                 # to every owner cell, and it silently idled four lanes the day HQs started owning rows.
                 # ⛔ ONLY THE SEAT'S OWN HQ. Another HQ's row stays skipped -- that is a lane boundary, and the
                 # cure for wanting it is `claim`, which is still the deliberate override it has always been.
                 # ⛔⭐ AND "YOUR HQ" MEANS THE LANE A NUMBERED SEAT RESOLVES TO, NEVER WHATEVER AN HQ FILE NAMES
                 # (coo 2026-09-26, same row as the owner cut in s4e_promotion_admissible). This arm read s4e_hq, and
                 # under the consolidated modes every HQ file names an officer: measured on a TENET fixture, `next`
                 # LOCKED a ceo-owned row for the coo and for hq_icon, and a cto-owned one for hq_raku, each "owned by
                 # your HQ (your lane)". An HQ and an officer resolve to themselves; only a seat's lane is its HQ.
                 *) if s4e_owner_in_my_lane "$brief"; then _serve_reason="rank $rank, owned by your HQ $brief (your lane)"
                    else _owned_skipped=$((_owned_skipped+1))
                         [ -n "$_owned_first" ] || _owned_first="rank $rank  $topic  (owner $brief)"
                         continue
                    fi;;
               esac ;;
             RESTRICTED:*) [ "$(s4e_restricted_to "$step")" = "$ME" ] || continue ;;
             *) continue;;
           esac
           # ⭐⭐ THE MODE LANGUAGE FREEZE -- see s4e_language_freeze_refuses above. Checked here too, not just
           # in the promotion path, so a FREE row that a park-sweep has not yet caught up to cannot be served
           # by the ordinary path either -- the two checks are companions, not alternatives (item (3) of this
           # row's own GOAL: "add the MODE priority cut... alongside the lane cut"). Unconditional: unlike the
           # lane filter below, there is no any-lane-style fallback for a language freeze, ever.
           if s4e_language_freeze_refuses "$topic"; then
             printf '⛔ SKIP %s (rank %s) — THE ORDER OF WORK is %s ONLY; this topic is %s (PARKED). Not served automatically.\n' \
               "$topic" "$rank" "$(s4e_mode_live_languages | tr '[:lower:]' '[:upper:]')" "$(s4e_topic_language_display "$topic")"
             printf '   Still live for a deliberate override: s4e_msg.sh claim %s\n' "$topic"
             continue
           fi
           # ⭐⭐ THE FLEET-12 RANK CAP -- see s4e_rank_cap_refuses above. Sits beside the language freeze
           # because it is the same KIND of cut: unconditional, no any-lane-style fallback, and never
           # relaxed by a later pass. A seat with nothing else to do does not become entitled to HQ work.
           # ⭐ AN EXPLICIT DIRECTION OUTRANKS THE CAP -- the GOAL's own "assign still outranks", and the
           # SAME precedent the lane filter below already sets ("an explicit OWNER-CELL match always wins
           # regardless of lane"). A rank-6 row an HQ deliberately pointed at THIS seat by name is not the
           # accident the cap exists to prevent; it is an authority overriding the default on purpose.
           # ⛔ ASSIGNED needs no exemption here and must not be given one: it hides a row from the picker
           # ENTIRELY, its owner included, so the cap can never be what withheld it -- the owner reaches for
           # `claim`, which this refusal names and which the cap does not touch.
           if s4e_rank_cap_refuses "$rank" \
              && [ "$brief" != "$ME" ] && [ "$step" != "RESTRICTED:$ME" ]; then
             _rankcap_skipped=$((_rankcap_skipped+1))
             [ -n "$_rankcap_first" ] || _rankcap_first="rank $rank  $topic"
             continue
           fi
           # ⭐⭐ THE LANE FILTER — see s4e_topic_lane/s4e_my_lane above. An explicit OWNER-CELL match
           # (this row is tagged to me by name) always wins regardless of lane; a lane-undetermined topic
           # (s4e_topic_lane returns empty) is lane-neutral and never filtered by either pass. own-lane
           # pass: skip a row whose determined lane is not mine. any-lane pass (reached only when the
           # own-lane pass fell through the WHOLE sorted queue without serving anything): never skip on
           # lane, but relabel the reason so a cross-lane serve is visible in its own printout rather than
           # reconstructed later from the queue (GOAL's own requirement).
           # ⛔ AN OWNER-CELL REASON IS NOT RELABELLED BY THE LANE PASS -- neither the seat's own cell nor its HQ's.
           # "your OWN LANE (hq_P)" and "owned by your HQ hq_P" are both true of the same row, and the second is
           # the one that answers the question a reader actually has when six seats were told the queue was empty:
           # WHY did this one come through? The lane label would have hidden the very mechanism that was just
           # cured, which is how a fix gets quietly re-broken by someone who cannot see it working.
           if [ -n "${_my_lane:-}" ] && [ "$_serve_reason" != "rank $rank, your OWNER CELL" ] \
              && [ "${_serve_reason#rank $rank, owned by your HQ}" = "$_serve_reason" ]; then
             _tl="$(s4e_topic_lane "$topic")"
             if [ "$_lane_filter" = own-lane ]; then
               if [ -n "$_tl" ] && [ "$_tl" != "$_my_lane" ]; then continue; fi
               [ -n "$_tl" ] && _serve_reason="rank $rank, your OWN LANE ($_tl)"
             elif [ -n "$_tl" ] && [ "$_tl" != "$_my_lane" ]; then
               # ⛔ THE FALLBACK IS NOT FOR A SEAT THAT OWNS NO LANGUAGE (CEO-779): the coo/cto wander into an HQ's cure
               # row here exactly as the promotion path did. Counted and reported once at the end, exit 2 -- a refusal
               # to serve, never "QUEUE EMPTY", because the queue is not empty, it is somebody else's.
               if ! s4e_seat_owns_a_language || s4e_any_lane_closed; then
                 _xlane_refused=$(( ${_xlane_refused:-0} + 1 )); _xlane_last="$topic ($_tl's)"
                 continue
               fi
               _serve_reason="rank $rank, CROSS-LANE FALLBACK (your lane $_my_lane had nothing servable; this row is $_tl's)"
             fi
           fi
           [ -f "$PO/claims/$topic.claim" ] && continue
           # ⭐ CURE 2 — RELEASE BOOMERANG. Do not hand a seat back the row it just put down; say so out loud,
           # because a silent skip here is indistinguishable from the row not existing.
           if s4e_boomerang_hold "$topic"; then
             printf '↩ SKIP %s (rank %s) — YOU released this row less than %ss ago; not serving it back to you.\n' "$topic" "$rank" "${S4E_RELEASE_COOLDOWN:-3600}"
             printf '   It is still live for every other seat. To take it back deliberately: s4e_msg.sh claim %s\n' "$topic"
             continue; fi
           if s4e_predispatch_placeholder_check "$topic"; then
             printf '⛔ REFUSING TO DISPATCH %s (rank %s) — %s\n' "$topic" "$rank" "$_ppc_why"
             printf '   Not claimed. An HQ or the mint author fixes the baton; this row stays free for everyone else.\n'
             continue; fi
           # ⛔⭐ THE NEIGHBOURHOOD SURVIVES THE SUPPRESSION (coo 2026-09-20, ceo CEO-1002). `next` takes its lock by
           # running `$0 claim` with BOTH streams sent to /dev/null -- correct for the claim's own chatter and fatal
           # for the announcement, which is the half of the cure the SERVED seat must actually read. So the output is
           # captured and the neighbourhood block is re-printed here. The notices themselves were already delivered by
           # that inner call, under this same identity; re-announcing would double every inbox.
           if "$0" claim "$topic" >"$_cl_out" 2>&1; then
             sed -n '/^-- the neighbourhood/,$p' "$_cl_out"; rm -f "$_cl_out"
             echo "RUNNING" >> "$PO/claims/$topic.claim"
             # ⛔⭐ ONE CALL, TWO SERVE PATHS -- see s4e_dispatch_gate. Never inline this again.
             s4e_dispatch_gate "$topic" "$rank" || continue
             s4e_report_owned_skips
             s4e_report_rankcap_skips
             serve "$topic" "LOCKED" "($_serve_reason)"; exit 0
           elif grep -q 'THE PREMISE OF THIS ROW IS RED' "$_cl_out" 2>/dev/null; then
             # ⛔⭐ A FAILED INNER CLAIM WAS SILENT HERE, AND A SILENT REFUSAL IS THE ONE OUTCOME THIS ROW
             # FORBIDS. `next` captures the claim's streams (CEO-1002, for the announcement), so a premise
             # refusal raised inside that subprocess died in $_cl_out and the picker simply moved on -- the
             # seat would be served the NEXT row and never learn that the one above it needs rewriting, which
             # is how a stale row stays stale forever while every seat quietly steps around it. A lost race is
             # ordinary chatter and stays quiet; a measured red premise is a finding and is printed whole.
             cat "$_cl_out" >&2; rm -f "$_cl_out"
             printf '↩ SKIP %s (rank %s) — PREMISE RED, not claimed. The row stays FREE and is now a REWRITE,\n' "$topic" "$rank"
             printf '   not a cure: whoever rewrites it fixes the premise first. Looking for the next row...\n'
             continue
           fi; rm -f "$_cl_out"
         done < <(grep -P '^[0-9]+\t' "$q" | while IFS=$'\t' read -r rk tp br st; do printf '%s\t%s\t%s\t%s\t%s\n' "$rk" "$(s4e_mint_ts "$tp")" "$tp" "$br" "$st"; done | sort -t$'\t' -s -k1,1n -k2,2r | cut -f1,3-)
         return 1
         }
         # ⭐⭐ TWO PASSES, ONE BODY — s4e_pass3_scan is called once per lane-filter mode so the own-lane
         # attempt and the cross-lane fallback can never disagree about what "servable" means (every other
         # skip rule -- blocked-on, grant-wait, restricted, claimed, boomeranged -- runs identically in
         # both calls; only the lane check inside toggles). A seat/HQ with no determinable lane
         # (s4e_my_lane empty: ceo, an unrecognized identity, or a seat whose HQ file is missing/stale)
         # never enters the own-lane pass at all -- lane-blind, exactly today's behaviour, is the safe
         # degradation for anything the lane mapping cannot see. GOAL's own fallback requirement ("a lane
         # guard that starves a seat whose lane is done is worse than the wandering it prevents") is why
         # the own-lane pass tries the WHOLE rank-sorted queue before giving up, not just rank<=1 -- a
         # strict rank<=1-only trigger would send a seat cross-lane while its own rank-2 work still sat
         # unclaimed.
         _xlane_refused=0; _xlane_last=""; _promo_reported=" "
         if [ -n "$_my_lane" ]; then _lane_filter=own-lane; s4e_pass3_scan; fi
         _lane_filter=any-lane; s4e_pass3_scan
         # ⛔ CEO-779: a seat that owns no language, held back ONLY by other lanes' rows, is REFUSED rc=2 -- not told the
         # queue is empty (it is not; it is the HQs'). rc=2 is "could not serve", the same word every instrument uses.
         if [ "${_xlane_refused:-0}" -gt 0 ] && s4e_seat_owns_a_language && s4e_any_lane_closed; then
           s4e_report_owned_skips
           s4e_report_rankcap_skips
           printf '⛔ REFUSED (rc=2): %s cross-lane row(s) NOT served -- your lane %s has nothing servable, and the any-lane fallback is CLOSED under TENET and QUINTET (ceo CEO-1302 (b), CEO-1356: an HQ runs only its own language, CEO-1232). Last: %s\n' "$_xlane_refused" "${_my_lane:-$ME}" "$_xlane_last"
           printf '   Your lane is empty, not the queue: ask your officer or the ceo for your next row (s4e_msg.sh ask <topic>); another lane'"'"'s row is an ASK to its owner, never a claim.\n'
           exit 2
         fi
         if [ "${_xlane_refused:-0}" -gt 0 ] && ! s4e_seat_owns_a_language; then
           s4e_report_owned_skips
           s4e_report_rankcap_skips
           printf '⛔ REFUSED (rc=2): %s cross-lane row(s) NOT served -- %s holds NO language under MODE line 2 / the LANES line (CEO-779; Lon 2026-09-16: "Get the COO helping. The language seats now run their own tests and benchmarks."). Last skipped: %s\n' "$_xlane_refused" "$ME" "${_xlane_last:-see the REFUSED PROMOTION lines above}"
           printf '   An instrument row reaches %s by assign or mint (s4e_msg.sh assign %s <topic>); another lane'"'"'s row is an ASK to its owner, never a claim.\n' "$ME" "$ME"
           exit 2
         fi
         # ⭐ CURE 3, second half — WHEN NOTHING IS SERVABLE, SAY WHAT GOVERNANCE IS HOLDING. A bare "queue
         # empty" sent seats to ask HQ for work while rows sat waiting on a grant nobody had chased.
         _gw="$(awk -F'\t' '/^[0-9]+\t/ && ($4 ~ /^GRANT-NEEDED/ || $4 ~ /^PARKED-LON-HOLD/) {printf "     rank %s  %s  [%s]\n",$1,$2,$4}' "$q" 2>/dev/null)"
         s4e_report_owned_skips
         s4e_report_rankcap_skips
         echo "QUEUE EMPTY — every row claimed. Ask hq: s4e_msg.sh ask work 'queue empty'"
         [ -n "$_gw" ] && { echo "   ⭐ NOT empty of WORK — these rows are GOVERNANCE-GATED, waiting on a grant, not on a seat:"; printf '%s\n' "$_gw"; echo "   Chase the grant (route via your HQ to ceo), do not re-park these to FREE."; }
         exit 1;;
  banner) # ⛔ FACTS ONLY -- NO PREDICTIONS (Lon 2026-08-22: "Why are you trying to predict the future. Quit saying
         # ⛔ FIRST THING IN THIS CASE, BEFORE ANY EXIT: the first placement was after the verdict line, which always `exit`s
         # (:1308), so the block was unreachable -- proven by deleting a hook and running banner: it did NOT come back. Falsify,
         # do not assume; a block that reads as coverage and cannot fire is the defect it was written to cure.
         # ⛔⭐ THE COMMIT-MSG HOOK IS (RE)INSTALLED FROM HERE TOO (seat04 2026-09-01; census hq_B same day). The installer rode
         # s4e_inbox_hook.sh, which fires on UserPromptSubmit -- and a census of every root's .claude/settings.json found
         # 16 of 19 wire ONLY Stop (all sixteen fleet seats; only the three HQs have UserPromptSubmit). So the row's claim
         # "rejected in every clone" was true in three roots and silently false in sixteen, and nothing on either end could
         # tell: the seat sees no install line (correct, nothing ran) and the HQ sees a landed row and a green gate. Stop is
         # the one event every root demonstrably has -- it is what prints this banner -- so coverage no longer depends on
         # which events a seat happened to wire. Same guard as the inbox hook: quiet, and never allowed to break the banner.
         # ($HERE is NOT a variable of this script -- the first draft of this block used it, tested false forever, and
         #  was caught by the verify line `grep -c HERE=` reading 0: the same silent class one paragraph up.)
         # ⭐⭐ THE SCORE LINE FIRST (Lon 2026-09-04 17:5x: "Ensure the banner is showing the score by each seat at every turn."):
         # measured from seat07's transcript the same hour -- 4 banners, 2 score lines: the line printed LAST, after ~9 s of
         # slower work, where a Stop-hook timeout or a truncated display loses it, and its refusal went to /dev/null. So it
         # prints HERE, 0.18 s, before anything slow, and a refusal prints VISIBLY. Never the verdict: this is a pipeline.
         # ⭐⭐ THE SUITE BANNER FIRST (Lon 2026-09-20 11:20 via ceo, THE FLEET-12 PLAN, MASTER-PLAN § THE
         # FLEET-12 PLAN: "Banner every turn: python3 .github/scripts/util_suite_banner.py (hq_T wires it
         # into s4e_msg.sh banner, rank 0)"). It is the SUITE view -- one line per suite, on/off the curve --
         # and under the plan's own first rule, WORK THE SUITES NOT THE LANGUAGES, it outranks the per-language
         # PROGRESS line below it. Both print: the language line is not retired, it is demoted.
         # ⛔ SAME DISCIPLINE AS THE LINE BELOW, FOR THE SAME MEASURED REASON: it prints HERE, before anything
         # slow, because a Stop-hook timeout or a truncated display loses whatever printed last (measured on
         # seat07: 4 banners, 2 score lines). 0.02 s over three runs, so it costs nothing to put first.
         # ⛔ AND ITS REFUSAL IS VISIBLE, NEVER /dev/null. A banner line that silently vanishes when its data
         # file is missing is indistinguishable from a fleet with no suites -- the not-found/not-there collision
         # this file already carries three instances of. It reads .github/SUITES.tsv relative to its OWN path,
         # so it does not honour S4E_HOME; the probe below points at a nonexistent SCRIPT instead, which is the
         # failure this wiring can actually have.
         # ⭐⭐ THE AHEAD-OF-ORIGIN LINE (ceo -> hq_B 2026-09-08, row instruments-the-banner-reports-a-seat-that-is-ahead-
         # of-origin-because-finished-invisible-work-is-reported-by-nothing; rank 0). ⛔ THE GAP IT CLOSES: the fleet
         # reports a seat that STALLS and a seat that FAILS, and reported NOTHING about a seat whose work is finished,
         # correct and simply unpushed. No red exists anywhere in that state -- handoff_status.sh rc is about the tree,
         # `fleet` is about claims and mail, and the seat's OWN banner says ✅ SUCCESS, because being ahead of origin is
         # not a failure of anything the banner used to ask about. MEASURED COST on 2026-09-08 alone: 45 minutes on the
         # cto's END-statement cure with the coo explicitly waiting for it, and 20 minutes on this seat's digest-gate
         # commit. ⭐ The arithmetic was ALREADY HERE and thrown away: the `onlyhere` loop below computes exactly this
         # count per repo (`rev-list --count origin/$br..$br`) and sums it into a scalar that only ever answers "is it
         # safe to /clear". A number that exists, is correct, and is summed past is the cheapest kind of blind spot.
         # ⛔ IT MUST NEVER PRINT THE WORD FAILURE, and it never changes the verdict or rc: a seat holding an unpushed
         # commit has done nothing wrong except not finish, and a line that scolds gets ignored, which is how the state
         # stayed invisible. It is a DISTINCT, VISIBLE line, printed HERE with the score and the suite view -- before
         # handoff_status.sh's minutes -- for the reason those two print here: whatever prints last is what a Stop-hook
         # timeout or a truncated display eats (measured on seat07, 4 banners and 2 score lines).
         # ⭐ SECOND ARM, AND IT IS THE ONE THAT CATCHES WHAT ACTUALLY COSTS TIME: the AGE of the oldest unpushed commit,
         # in words. Ahead-1-for-thirty-seconds is a seat mid-push and needs no attention; ahead-1-for-forty-five-minutes
         # is a cure nobody else has. A bare count cannot tell those apart and would be noise within a day.
         # ⛔ COUNTS ARE READ LIVE FROM git, NEVER FROM CACHED STATE, and each repo is FETCHED FIRST -- an unfetched
         # origin ref makes a pushed commit read as unpushed, which is the false-positive that would get this line muted.
         # A fetch failure degrades to the local ref and SAYS SO rather than reporting a confident wrong number.
         _ah_home="${S4E_AHEAD_HOME:-$S4E}"; _ah_repos=""; _ah_total=0; _ah_oldest=0; _ah_nofetch=""
         for _ar in "$_ah_home"/*/; do
           [ -d "$_ar/.git" ] || continue
           _ab="$(git -C "$_ar" rev-parse --abbrev-ref HEAD 2>/dev/null)" || continue
           [ -n "$_ab" ] || continue
           git -C "$_ar" fetch -q origin 2>/dev/null || _ah_nofetch="$_ah_nofetch $(basename "$_ar")"
           git -C "$_ar" rev-parse --verify -q "origin/$_ab" >/dev/null 2>&1 || continue
           _an="$(git -C "$_ar" rev-list --count "origin/$_ab..HEAD" 2>/dev/null || echo 0)"; _an="${_an:-0}"
           case "$_an" in ''|*[!0-9]*) _an=0;; esac
           [ "$_an" -gt 0 ] || continue
           _ah_total=$((_ah_total + _an))
           _at="$(git -C "$_ar" log --format=%ct "origin/$_ab..HEAD" 2>/dev/null | tail -1)"
           _aage=0; case "$_at" in ''|*[!0-9]*) :;; *) _aage=$(( ( $(date +%s) - _at ) / 60 ));; esac
           [ "$_aage" -gt "$_ah_oldest" ] && _ah_oldest="$_aage"
           _ah_repos="$_ah_repos $(basename "$_ar")+${_an}(${_aage}m)"
         done
         # ⛔⭐ ALL THREE AHEAD-OF-ORIGIN ARMS ARE FITTED, and this is where the width gate earned itself.
         # These lines are CONDITIONAL -- two of the three print only while a repo is ahead -- so they were
         # absent from every banner measured while building the 80-column cure, and the gate went green over a
         # population that did not contain them. It caught them the moment a rebase left .github ahead: 187
         # columns. ⭐ THE LESSON IS THE ONE THIS WHOLE ROW IS ABOUT, arriving from the other side: a gate is
         # evidence only about the population it actually saw, and a line that fires only in a rare state is
         # exactly the line no routine run will ever show you. When adding a printf here, fit it -- do not wait
         # for the state that reveals it.
         _ah_stale="${S4E_AHEAD_STALE_MIN:-10}"
         if [ "$_ah_total" -eq 0 ]; then
           :
         elif [ "$_ah_oldest" -ge "$_ah_stale" ]; then
           :
         else
           :
         fi
         _ih="$(dirname "${BASH_SOURCE[0]}")/install_commit_msg_hook.sh"
         if [ -x "$_ih" ]; then
           :
         fi
         # in the banner what you will do. You do not know the future."). Every line below is a measured fact about
         # state as it stands. What a later session does is not knowable here: HQ can re-rank the queue, and THE LOOP
         # reads the inbox before the queue. Two laws still hold: the verdict is COMPUTED, never typed, and it turns
         # on ONE question -- did the work land and get pushed (handoff_status.sh rc, the only sanctioned source).
         # An open question to HQ is HQ's backlog, never this seat's failure.
         # ⭐ ceo-only, WARN-only (Lon trust-audit 2026-08-28: health checks must be HARNESS-FIRED, not remembered —
         # the same defect class as the old hand-fired banner). Fast (<1s), reads the postoffice, never flips the
         # verdict; rc=2 from the census prints as its own refusal line rather than a silent green.
         if [ "$ME" = "ceo" ] && [ -x "$S4E/harness/scripts/util_queue_visibility_census.py" ]; then
             _cns="$(python3 "$S4E/harness/scripts/util_queue_visibility_census.py" 2>&1 | tail -1)"
             :
         fi
         hs="$S4E/harness/scripts/handoff_status.sh"
         [ -f "$hs" ] || hs="$(cd "$(dirname "$0")" && pwd)/handoff_status.sh"
         # ⛔ SKIP_S_ARTIFACT_CHECK=1 (ceo 2026-08-27, Lon's "go fix it" — the missing-banners defect, seat09/hq_P diagnosis):
         # the .s-artifact verifier runs `make pristine` (minutes; races and WIPES live builds), so every banner that reached
         # it blew the Stop hook's 100s timeout and Lon saw NO banner — precisely on SUCCESS. The check is WARN-ONLY by design
         # (cannot flip the verdict), so skipping it here changes nothing the banner asserts. The FULL check still runs on a
         # direct handoff_status.sh invocation — the real handoff verdict, where HQ-27 wants the pristine.
         # ⛔ THE BANNER IS BOUNDED (ceo 2026-09-23 CEO-1173, on Lon's ask "is there a problem with the automatic display of the
         # test suite banner"): a ten-seat sweep with a 90 s ceiling read the banner COMPLETE in six seats and TIMED OUT with NO
         # suite table in four (ceo, snocone, prolog, pascal). handoff_status.sh took 107 s on a clean tree at load 9 against the
         # Stop hook's 120 s: 29 s with the seven-language slot-kind sweep (timeout 300) skipped, 11 s with the GC acceptance
         # display skipped too. Both are WARN-ONLY with their own honest skip switches (each prints SKIPPED, never a green). The
         # banner skips the sweep (it runs on a direct handoff_status.sh invocation, the boundary it was wired for) and bounds
         # the whole call at 75 s; a timeout is a REFUSAL that names the load, never a lost banner.
         # ⛔ THE BANNER SKIPS THE GC ACCEPTANCE DISPLAY TOO (ceo 2026-10-14 CEO-1705, the coo's load reading 38 on 16 cores at
         # 12:21): util_gc_acceptance.py spawned util_gc_census.py for 40-70 s at every Stop of every seat, fourteen seats, and
         # `timeout 75` kills only the bash, so the census outlived the banner -- the per-response class CEO-1671 removed. The
         # four numbers still print on a direct handoff_status.sh invocation, the handoff boundary Lon's 09-21 order names.
         if [ -f "$hs" ]; then hout="$(SKIP_S_ARTIFACT_CHECK=1 SKIP_ZLS_ALL=1 SKIP_GC_ACCEPTANCE=1 timeout -k 5 75 bash "$hs" 2>&1)"; hrc=$?; else hout="handoff_status.sh NOT FOUND at $hs"; hrc=2; fi
         if [ "$hrc" = 124 ]; then hout="$hout"$'\n'"⛔ handoff_status.sh NOT MEASURED — timed out at the banner's 75 s budget (load $(cut -d' ' -f1 /proc/loadavg)); this is a refusal, not a red: run bash ../harness/scripts/handoff_status.sh by hand"; hrc=2; fi
         # ⭐ fix-dispatch-bus-two-failure-modes (s266, seat07's q-s4e-msg-banner-attribution-undercount):
         # `held` used to be "whichever of my OPEN claims sorts first ALPHABETICALLY" -- a seat holding two
         # open claims could run `done <topic>` to close ONE and have its OWN banner report the OTHER.
         # `done` already passes the topic it just verified as $2 (see the `done` arm below); when banner
         # gets a real topic (not "-v", the direct-invocation verbose flag) THAT topic wins outright, no
         # scan needed. A bare invocation (Stop hook, `board`) falls back to the same rank-sort next()
         # uses, never glob order.
         pref="${2:-}"; [ "$pref" = "-v" ] && pref=""
         held=""
         if [ -n "$pref" ] && [ -f "$PO/claims/$pref.claim" ] && [ "$(head -1 "$PO/claims/$pref.claim")" = "$ME" ] && ! grep -q '^DONE$' "$PO/claims/$pref.claim"; then
           held="$pref"
         else
           held="$(for c in "$PO"/claims/*.claim; do [ -f "$c" ] || continue
               [ "$(head -1 "$c")" = "$ME" ] || continue
               grep -q '^DONE$' "$c" && continue
               t="$(basename "$c" .claim)"; printf '%s\t%s\n' "$(qrank "$t")" "$t"
             done | sort -t$'\t' -s -k1,1n | head -1 | cut -f2)"
         fi
         qwait=0; for hb in $(s4e_hqboxes); do for f in "$PO/$hb"/inbox/*.msg; do [ -f "$f" ] || continue; case "$(basename "$f")" in *-"$ME"-q-*) qwait=$((qwait+1));; esac; done; done
         inbx=0; for f in "$PO/$ME/inbox"/*.msg; do [ -f "$f" ] && inbx=$((inbx+1)); done
         # ⛔⭐ V2-3 -- DRAIN BEFORE MINT, MADE MECHANICAL (LAW 3, ARCH-FLEET-CEO.md; hq_P s258). Measured basis, from
         # the fleet-v1 retrospective: 29 messages and 15 seat questions sat unread in HQ's inbox for 1h47m while HQ
         # minted new rows; seat13 starved holding five of them; HQ's own board line was the oldest on the board. The
         # rule "answer every pending question before minting" existed and was ignored, for the same reason the banner
         # law was ignored before the Stop hook: a step in a markdown file is a hope, not a mechanism. So the HQ's own
         # verdict now refuses to say ✅ while a seat's question has been rotting. ⛔ Binds HQ ONLY -- a seat's inbox
         # is HQ talking TO it, and holding unread mail is not a seat's protocol failure.
         staleage="$(s4e_oldest_min "$ME")"; stalemin="${S4E_DRAIN_MIN:-30}"; drain=0
         if s4e_is_hq "$ME" && [ -n "$staleage" ] && [ "$staleage" -gt "$stalemin" ]; then drain=1; fi
         freerows=0; nrow=""; nrank=""
         while IFS=$'\t' read -r rank topic brief step; do case "$rank" in ''|\#*) continue;; esac
           [ -f "$PO/claims/$topic.claim" ] && continue; freerows=$((freerows+1))
           [ -z "$nrow" ] && { nrow="$topic"; nrank="$rank"; }; done < "$PO/QUEUE.tsv" 2>/dev/null
         # A clone predating the 2026-08-21 filter-repo rewrite shares no recent history with origin. Must FETCH
         # first: an unfetched pre-rewrite clone has a stale origin/* ref and reads as pristine.
         diverged=""
         for r in "$S4E"/*/; do [ -d "$r/.git" ] || continue
           br=$(git -C "$r" rev-parse --abbrev-ref HEAD 2>/dev/null) || continue
           git -C "$r" fetch -q origin 2>/dev/null || continue
           git -C "$r" rev-parse --verify -q "origin/$br" >/dev/null 2>&1 || continue
           if ! git -C "$r" merge-base --is-ancestor HEAD "origin/$br" 2>/dev/null; then
             bh=$(git -C "$r" rev-list --count "HEAD..origin/$br" 2>/dev/null || echo 0)
             [ "${bh:-0}" -gt 50 ] && diverged="$diverged $(basename "$r")"; fi; done
         pline="$(printf '%s\n' "$hout" | grep -aiE 'HANDOFF (COMPLETE|BLOCKED)|COMPLETE|BLOCKED:' | head -1)"; [ -n "$pline" ] || pline="$(printf '%s\n' "$hout" | tail -1)"
         # ⛔ IT IS A BANNER, NOT A REPORT (Lon 2026-08-22: "You turned a banner into a TL;DR"). ONE line, glanced at.
         # SUCCESS and safe-to-/clear are the SAME fact -- both are handoff_status.sh rc=0 -- so there is one thing
         # to say. Detail is not lost, it moves behind `banner -v`, which nobody has to read.
         b='════════════════════════════════════════════════════════════════════════════════'
         # ⛔ LEVEL OF SUCCESS (Lon 2026-08-22: "Why are you not giving any feedback whatsoever as to the level of
         # success?"). Pushed-and-clean is NOT the same as accomplished -- a seat that did nothing also pushes clean.
         # So the banner counts what actually LANDED in the last 12h: commits across this seat's repos, FINDINGs added,
         # and whether the row closed. All measured from git, none of it typed. NOTHING LANDED is called out loudly.
         # ⛔ ATTRIBUTABLE ONLY. A bare `log --since` counts commits this clone merely PULLED -- it credited a seat
         # that did nothing with 4 commits. This project's commit messages carry the seat id and the row topic, so
         # the level is measured by ATTRIBUTION: commits naming this seat or its row, and FINDING files naming either.
         # Same fix as `held` above, reusing $pref: after `done` marks a row DONE it is no longer "open",
         # so `held`'s open-only pref check would miss it -- row1/rowst must accept a CLOSED pref too, since
         # that is exactly the row `done` just closed and wants attributed here.
         # ⛔⭐ FIXED (banner-attributes-wrong-row-on-unclaim, s273): the OLD else-branch rescanned EVERY
         # claim ever held by $ME, open or DONE, and sorted by (done-flag, rank) -- so a session with ZERO
         # open claims (the exact shape `unclaim` leaves behind) fell through to "whichever ancient DONE
         # claim under this identity sorts first", attributing a stale prior session's row (and, via the
         # cmts/fnd --grep="$row1" below, sometimes its commit/FINDING counts too) to a session that never
         # touched it. Measured 4 independent times (seat08/seat06/seat02 LEDGER, this bundle's own repro).
         # THE FIX: never guess across sessions. $held (computed above) is ALREADY the correct "my lowest-
         # rank OPEN claim, DONE claims excluded" answer -- reuse it outright instead of re-deriving a
         # DONE-admitting variant. When there is no open claim (unclaim left none, or nothing was ever
         # claimed this session), fall back to the SESSION-SCOPED receipt `s4e_mark_row` writes at the
         # moment `unclaim`/`done` actually close a row -- never to claims/*.claim history at large.
         rowst="none"; row1=""; rowmark_ts=""
         if [ -n "$pref" ] && [ -f "$PO/claims/$pref.claim" ] && [ "$(head -1 "$PO/claims/$pref.claim")" = "$ME" ]; then
           row1="$pref"; grep -q '^DONE$' "$PO/claims/$pref.claim" && rowst="CLOSED" || rowst="OPEN"
         elif [ -n "$held" ]; then
           row1="$held"; rowst="OPEN"
         elif [ -s "$PO/$ME/.last-row" ]; then
           row1="$(sed -n 1p "$PO/$ME/.last-row")"; rowst="$(sed -n 2p "$PO/$ME/.last-row" | cut -d' ' -f1)"
           rowmark_ts="$(sed -n 2p "$PO/$ME/.last-row" | cut -d' ' -f2-)"
         fi
         # ⭐ SESSION-SCOPED WINDOW, WIDEN-ONLY (banner-attributes-wrong-row-on-unclaim, s273 -- SELF-
         # CORRECTED same session after this exact code produced a live false "NOTHING LANDED" on this
         # seat's own board post). The marker records WHEN THE ROW CLOSED, not when the session started --
         # using it as a `--since` floor NARROWS the window to "after I finished," which finds ZERO of the
         # commits that led UP TO the close (measured: a session with 7 real attributable commits over the
         # preceding hours read 0 the instant `since` was pinned to its own just-written close marker).
         # So the marker may only WIDEN the window (for a session that ran longer than 12h), never narrow
         # it below the flat default -- take whichever of the two is EARLIER.
         since="12 hours ago"
         if [ -n "$rowmark_ts" ]; then
           m_epoch=$(date -u -d "$rowmark_ts" +%s 2>/dev/null || echo 0)
           cut_epoch=$(date -u -d "12 hours ago" +%s 2>/dev/null || echo 0)
           if [ "$m_epoch" -gt 0 ] 2>/dev/null && [ "$m_epoch" -lt "$cut_epoch" ] 2>/dev/null; then since="$rowmark_ts"; fi
         fi
         # ⛔⭐ THIRD ATTRIBUTION DEFECT IN THIS BLOCK, and the first one the MESSAGE GREP CANNOT EVER FIX
         # (seat05 2026-08-29, msg q-bb-fixup-az-cleanup; verified + generalized by hq_P same session).
         # The grep above can only see a commit that NAMES this seat or its row. Nothing requires that:
         # the ONE-IDENTITY LAW makes every commit's author identical fleet-wide, so the message is the
         # only signal, and long-standing conventions carry neither field -- e.g. this repo's own
         # "FIXUP <file>: <change>" rung convention. seat05 landed 3 real, pushed, gate-verified FIXUP
         # commits and `board` printed "⚠ NOTHING LANDED ... produced NO commit and NO FINDING".
         # ⭐ MEASURED BLAST RADIUS, not just that row: of 20 commits in one 12h window, 15 (75%) named
         # neither a seat/hq id nor ANY QUEUE.tsv topic -- so this under-reports most fleet work, and
         # reports zero whenever a seat's whole session used such a convention.
         # ⭐ THE FIX USES A SIGNAL THAT NEEDS NO CONVENTION AT ALL: every seat has its OWN CLONE, so a
         # commit CREATED HERE is this seat's by construction. `git reflog` distinguishes exactly that --
         # locally-created commits are "commit:"/"commit (amend):" entries, while another seat's work
         # arriving via pull/rebase/merge is "pull ... (start): checkout"/"merge origin/main" and is
         # NEVER counted. (A `pull --rebase (pick)` replays THIS seat's own commit, also not counted --
         # the original "commit:" entry already covers it, and counting unique SUBJECTS de-duplicates
         # the rewritten hash.)
         # ⛔ STRICTLY ADDITIVE BY CONSTRUCTION: we take the MAX of the two counts, never the reflog
         # alone. This can only ever find MORE commits than before, never fewer, so it cannot turn a
         # correct banner red or a landed session into a false NOTHING LANDED -- the failure being cured
         # is a false NEGATIVE, and the fallback's own population ("commits made in this clone inside
         # the window") is this seat's work by definition. A repo with no reflog degrades to the old
         # behaviour silently.
         cmts=0; for r in "$S4E"/*/; do [ -d "$r/.git" ] || continue
           n=$(git -C "$r" log --since="$since" -i --grep="$ME" ${row1:+--grep="$row1"} --oneline 2>/dev/null | wc -l)
           n2=$(git -C "$r" reflog show --since="$since" --format='%gs' 2>/dev/null | sed -n 's/^commit[^:]*: //p' | sort -u | grep -c . 2>/dev/null || true); n2="${n2:-0}"
           [ "$n2" -gt "$n" ] 2>/dev/null && n="$n2"
           cmts=$((cmts+n)); done
         # seat8 2026-08-22: every FINDING-*.md ever written (202/202 checked) names the seat the OLD,
         # unpadded way ("seat8"), because s255's zero-padding change touched $ME fleet-wide but no seat's
         # file-naming habit. Matching $ME alone ("seat08") against the corpus finds ZERO files, always,
         # for every single-digit seat -- so a same-session FINDING silently fails attribution here too.
         mealt="${ME/#seat0/seat}"
         # ⛔⭐ THE ANCHOR WAS A PATH PREFIX A RE-GRID MOVED OUT FROM UNDER IT, AND IT FAILED SILENTLY AND DOWNWARD
         # (hq_snobol4 2026-09-20, measured against their own just-pushed finding; reproduced here on .github 52a2a8bd).
         # This counter matched '^FINDING-'. Since Lon's 2026-09-18 ruling (CEO-859 + CTO-74) every finding lives at
         # .github/findings/FINDING-*.md, so every path this sees begins 'findings/' and THE ANCHOR NEVER MATCHED:
         # same window, same repo, anchored 0 -- unanchored 5, across three seats. ⛔ A WRONG COUNT IS NOT THE HARM.
         # The banner's NOTHING LANDED verdict calls a session EMPTY when it sees no commit and no finding, and a
         # diagnosis row whose cure lives in another seat's file CORRECTLY produces a finding and nothing else -- so
         # the instrument was calling real work nothing, loudest for the seats doing the careful half. It is the
         # digest's own class wearing new clothes: a guard keyed on a NAME is a coincidence, not a guard -- here keyed
         # on a PATH PREFIX. Matched at a path BOUNDARY now, so it counts findings/ and any historical root-level one.
         fnd=$(git -C "$S4E/.github" log --since="$since" --diff-filter=A --name-only --format= 2>/dev/null | grep -E '(^|/)FINDING-' | grep -ci -e "$ME" -e "$mealt" ${row1:+-e "$row1"} || true); fnd="${fnd:-0}"
         if [ "$cmts" -eq 0 ] && [ "$fnd" -eq 0 ]; then lvl="⚠ NOTHING ATTRIBUTABLE LANDED"
         else lvl="row ${rowst}${row1:+ ${row1}} · ${cmts} commit(s) · ${fnd} FINDING(s), attributed since ${since}"; fi
         # ⛔ BEHIND-ONLY IS NOT A FAILURE. handoff_status.sh answers "is this tree in sync"; the banner answers a
         # NARROWER question -- does anything of value live ONLY in this session. A clone merely BEHIND origin (clean
         # tree, nothing unpushed) loses nothing on /clear; it just pulls next time. Measured directly per repo, since
         # calling that FAILURE would have flagged both fireable seats red for something neither seat did.
         onlyhere=0
         for r in "$S4E"/*/; do [ -d "$r/.git" ] || continue
           d=$(git -C "$r" status --porcelain 2>/dev/null | wc -l)
           br=$(git -C "$r" rev-parse --abbrev-ref HEAD 2>/dev/null)
           u=$(git -C "$r" rev-list --count "origin/$br..$br" 2>/dev/null || echo 0)
           onlyhere=$((onlyhere + d + ${u:-0})); done
         if   [ -n "$diverged" ]; then line="⛔ STOP — $ME — PRE-REWRITE CLONE:$diverged — re-clone before use"
         # rc is deliberately NOT changed by the drain refusal, for the same reason NOTHING LANDED did not change it:
         # rc answers "is it safe to /clear", and unread mail is safe to /clear -- it is on disk and waits. What the
         # drain law governs is the VERDICT LON READS, and that is this line.
         elif [ "$drain" -eq 1 ]; then line="⛔ DRAIN FIRST — $ME — ${inbx} unread, oldest ${staleage}m (limit ${stalemin}m). LAW 3: answer every pending question into its task file BEFORE minting or assigning. No ✅ until the inbox is current — $lvl"
         # ⛔⛔ s255, LON: "I never stopped a FLEET worker whose banner did not say SUCCESS after I prompted 'show me
         # the required banner.' So they lied."  THE SEATS DID NOT LIE -- THIS HEADLINE ANSWERED THE WRONG QUESTION.
         # SUCCESS was emitted on handoff_status rc=0, i.e. "tree clean, nothing unpushed" -- which A SEAT THAT DID
         # ABSOLUTELY NOTHING SATISFIES TRIVIALLY. Doing nothing was indistinguishable from doing everything. Proof
         # on the day: two freshly-created empty seats printed "✅ SUCCESS", and seat6 -- which released its row
         # having touched no code -- would have too. The code ALREADY computed the honest fact one screen above
         # ($lvl = "NOTHING ATTRIBUTABLE LANDED" when cmts==0 && fnd==0) and then appended it as DECORATION to a
         # SUCCESS verdict. The wrong one was in the headline. Now: nothing landed => the headline says so.
         # rc is deliberately UNCHANGED -- it still answers "safe to /clear", which is a different question and the
         # one tooling consumes. The banner's TEXT is what Lon reads, and it is now the one that must be earned.
         elif [ "$cmts" -eq 0 ] && [ "$fnd" -eq 0 ]; then line="⚠ NOTHING LANDED — $ME — tree is clean and safe to /clear, but this session produced NO commit and NO FINDING. That is not success; it is an empty session."
         elif [ "$onlyhere" -eq 0 ] && [ "$hrc" -ne 0 ]; then line="✅ SUCCESS — $ME — safe to /clear (behind origin, nothing unpushed) — $lvl"
         elif [ "$hrc" -eq 0 ]; then line="✅ SUCCESS — $ME — safe to /clear — $lvl"
         # ⛔⭐ IN-PROGRESS, NOT FAILURE (Lon 2026-09-13: "Does FAILURE mean IN-PROGRESS?" then "Change FAILURE
         # to IN-PROGRESS."; ceo CEO-713). THIS BRANCH MEASURES ONE FACT AND ONLY ONE: onlyhere > 0 -- dirty
         # files or unpushed commits exist IN THIS CLONE AND NOWHERE ELSE. A seat mid-row holding two
         # uncommitted files HAS NOT FAILED AT ANYTHING; it is working, and calling that FAILURE told Lon a
         # working seat was broken thirteen times an hour. The measured instance: the coo read ⛔ FAILURE on
         # two dirty .github files with nothing unpushed and an OPEN P5 row.
         # ⛔ rc IS DELIBERATELY UNCHANGED. This headline answers "safe to /clear?", which is a DIFFERENT
         # question from "did this seat succeed?" -- the same separation the NOTHING LANDED arm above already
         # keeps. A rename that quietly flipped rc would turn thirteen seats' handoff checks into something
         # else. The real failure states keep their own words and are ABOVE this branch: STOP for a
         # pre-rewrite clone, DRAIN FIRST for unread mail.
         else                        line="⏳ IN-PROGRESS — $ME — do NOT /clear, work is only here — $lvl — $(printf '%s' "$pline" | sed 's/^ *-* *//')"
           fi
         # ⭐ V2-3, second half: the BOARD LINE carries the oldest-unanswered age and the row topic. BOARD.md is what
         # `fleet` renders and what Lon reads when he is not reading a banner, and in v1 it could not show either --
         # so an HQ sitting on a 1h47m question looked exactly like an HQ with an empty inbox.
         # ⛔ BOTH CLAUSES ARE UNCONDITIONAL, and that is the fix for a defect this gate caught in its own first
         # green run: the row topic was riding inside $lvl, and $lvl COLLAPSES to "NOTHING ATTRIBUTABLE LANDED"
         # whenever a session has no attributable commit -- so precisely the sessions worth chasing (a seat holding
         # a row and producing nothing) were the ones whose board line refused to name the row. A field that
         # disappears exactly when it matters is a blind instrument (LAW 0, species 3).
         [ -z "${row1:-}" ]   || line="$line · row ${row1}"
         [ -z "$staleage" ]   || line="$line · mail ${inbx}/${staleage}m"
         # ⭐ THE PROGRESS LINE, LAST (Lon 2026-09-03 ~20:15: "each of the 7 main runners display a score of
         # percentage in a banner ... just to see a progress indicator of any kind"). It READS .github/SCORE.md
         # and runs no suite -- ~60ms, no network, no build -- so a Stop hook can afford it on every response.
         # ⛔ NEVER LET IT BREAK THE BANNER: the banner's exit status is the seat's computed verdict, so a
         # refusal here (a renamed grid column, a missing language row) must be VISIBLE and must not change
         # that verdict. Hence `|| true` and stderr kept -- a progress line that could turn a green handoff red
         # would be a reporting tool with veto power over the thing it reports on.
         # ⛔⛔ THE BANNER WAS FIRING AND NOBODY COULD SEE IT (Lon 2026-08-22 s256: "The FLEET workers are not showing
         # a banner at the end. claude08 just sat silent like an idiot").  MEASURED, from seat08's OWN transcript --
         # two stop_hook_summary records, 3867ms and 4166ms, "hookErrors": [], "hasOutput": true.  The hook fires and
         # SUCCEEDS every time.  The field that decides whether a human ever reads it is "level": "suggestion": the
         # s255 Stop hook wraps this output in {"systemMessage": ...}, which the client files as an ADVISORY HINT, not
         # as transcript output.  The banner has been landing in a drawer since the day it was automated.
         # ⭐ CURE, and it is LAW 18 one level further out: a status that exists only in a display channel we cannot
         # verify is not a status.  PERSIST IT.  The verdict is already computed one line above; write it to BOARD.md
         # so `fleet`, `board`, and Lon reading the file all see the same COMPUTED line whatever the client does with
         # the hint.  Suppressed when `board` is the caller, so a seat's typed status is never clobbered by this.
         # ⛔⭐⭐ THE COMPUTED VERDICT IS PRINTED (ceo CEO-708, 2026-09-13). It had stopped: 92739c0d6 applied
         # Lon's order about the SUITE TABLE to the whole banner and left the seat banner printing nothing at
         # all, so $line went to BOARD.md and never to a human. ⛔ THE COST WAS THIRTEEN SEATS: Lon /cleared
         # all nine HQs and all four officers without a verdict to read, verbatim -- "There was no diplay
         # banner there either." SUCCESS and safe-to-/clear are THE SAME FACT, so a seat with no verdict
         # cannot be cleared safely and nobody can tell whether its work is on origin.
         # ⛔ THIS IS NOT THE DELETED SUITE TABLE AND MUST NEVER GROW BACK INTO ONE: it is ONE line, the
         # seat's own handoff verdict, which the law says must never be typed by hand. The suite table stays
         # deleted. If this ever prints more than one line, it has become the thing Lon ordered removed.
         printf '%s\n' "$line"
         if [ "${S4E_BANNER_NO_BOARD:-0}" != "1" ] && [ -d "$PO" ]; then
           grep -v "^$ME |" "$PO/BOARD.md" 2>/dev/null > "$PO/.b.$$" || true
           printf '%s | %s | %s\n' "$ME" "$line" "$(date -u +%H:%M)" >> "$PO/.b.$$"
           mv "$PO/.b.$$" "$PO/BOARD.md" 2>/dev/null || rm -f "$PO/.b.$$"; fi
         # ⛔⭐⭐ THE PRINTED BANNER IS EXACTLY TWO THINGS AND NOTHING ELSE (Lon 2026-09-13, in-chat to cfo,
         # verbatim, in order: "Hey where is the banner showing SUCCESS and FAILURE?" · "No, it should not print
         # anything but SUCCESS and FAILURE. And a grid of the test suite scores." · "Ensure a grid is output not
         # text from the shell script." · "No, the grid must not be text." · "I want a excel type grid with lines
         # and cells." · "I mean border lines."). THE VERDICT WORD, then THE GRID. No row topic, no commit count,
         # no FINDING count, no safe-to-/clear prose -- $line keeps all of that and goes to BOARD.md ABOVE, which
         # is a FILE and not the print, so `fleet` and `board` lose nothing.
         # ⛔ HISTORY, so nobody re-deletes this: the printed banner was deleted entire at c902a4b73 on Lon's
         # earlier word about the standing status block, and util_suite_banner.py's printer went with it. The
         # deletion took the ONE-LINE VERDICT with the block Lon had actually objected to, and for the hours
         # between that commit and this one EVERY SEAT'S Stop hook fired an EMPTY string -- measured here, rc=0
         # and zero bytes. Lon noticed before any instrument did, because no gate asserts that the banner prints.
         # ⛔ THE GRID IS RENDERED BY util_suite_banner.py AND NEVER ASSEMBLED HERE (Lon: "not text from the
         # shell script"). This case must not format a suite number; if the renderer is missing, SAY SO loudly
         # rather than fall back to shell-built text, which is the exact thing that was ruled out.
         # ⛔⭐ THE WORD IS ONE OF FOUR, NOT ONE OF TWO (Lon 2026-09-13, in-chat to cfo, verbatim: "Change word
         # FAILURE to IN-PROGRESS, and other unique modes if there are more than 2 states."). There ARE more than
         # two: the verdict line above already branches four ways, and collapsing them onto SUCCESS/FAILURE threw
         # away the two that tell a seat what to DO. Each word below is the branch that was already computed --
         # nothing new is inferred, and no state is invented to fill the list out.
         #   STOP        pre-rewrite clone; the tree itself is wrong and must be re-cloned before any work.
         #   DRAIN       unread mail past the staleness limit; LAW 3 says answer before working.
         #   SUCCESS     tree clean and nothing unpushed -- the only state that is actually finished.
         #   IN-PROGRESS uncommitted or unpushed work. ⭐ THIS IS WHAT USED TO PRINT "FAILURE", AND FAILURE WAS
         #     THE WRONG WORD: a seat mid-cure has failed at nothing, and a banner that calls ordinary unfinished
         #     work a failure trains every reader to ignore the one word that should mean something.
         if   [ -n "$diverged" ];   then printf '%s\n' "STOP"
         elif [ "${drain:-0}" -eq 1 ]; then printf '%s\n' "DRAIN"
         elif [ "$hrc" -eq 0 ] || [ "$onlyhere" -eq 0 ]; then printf '%s\n' "SUCCESS"
         else printf '%s\n' "IN-PROGRESS"; fi
         _sb="$S4E/.github/scripts/util_suite_banner.py"
         if [ -f "$_sb" ]; then timeout -k 5 30 python3 "$_sb" || printf '%s\n' "⛔ SUITE GRID REFUSED (rc=$?) -- $_sb ran and did not render"
         else printf '%s\n' "⛔ SUITE GRID MISSING -- no $_sb"; fi
         { [ "$hrc" -eq 0 ] || [ "$onlyhere" -eq 0 ]; } && [ -z "$diverged" ] && exit 0 || exit 1;;
  # ⭐ whoami PRINTS THE RESOLVED SEAT AND NOTHING ELSE, ON stdout, WITH NO SIDE EFFECT (hq_B 2026-09-13).
  # ⛔ IT EXISTS SO NOBODY MAKES A FOURTH COPY OF THE ROOT-PATH MAP. The mapping above is already the ONE
  # authority (util_score_row.derive_measurer and lib_one_runner.sh both defer to it by rule); a gate or a
  # helper that needs the seat had no way to ASK, so its only options were to duplicate the case statement or
  # to scrape it out of another subcommand's output. Scraping is what test_gate_send_prose_requires_stdin.sh
  # tried first, and `check` prefixes an unread-mail banner: the "identity" it recovered was the whole banner
  # welded into one word, and it built a mailbox path out of it. ✅ The gate REFUSED rc=2 rather than proceed
  # on that, which is the behaviour working -- but a verb that answers the question directly is the cure.
  # ⛔ Deliberately silent about mail: this must stay safe to call from a script in a loop.
  whoami) echo "$ME";;
  fleet) # ⛔ LON'S HEALTH VIEW (Lon 2026-08-22: "I'll not read much but I will check on the health").
         # ONE screen for the whole fleet, all COMPUTED. Deliberately does NOT run handoff_status.sh per seat
         # (that walks every repo, 9x over) -- it inspects each seat root's clones directly, which is the same
         # truth for the two things that matter: uncommitted work, and commits that never reached origin.
         # ⛔⭐ THE LOCK-AGE COLUMN IS ANNOTATED IN ITS OWN HEADER, NOT IN A NOTE BESIDE IT (hq_P, 2026-08-27).
         # A caveat that lives next to a field is read by whoever already knows -- and the seat in a hurry, who is
         # exactly who misreads it, never gets there. So the trap is spelled INSIDE the column name: this number is
         # when the LOCK was taken. It is NOT a work signal. A seat that claimed a row and walked away and a seat
         # mid-cure print the IDENTICAL number, and nothing in the field can tell you which you are looking at.
         # ⭐ THE FIX FOR A FIELD THAT ANSWERS A NARROWER QUESTION IS A SECOND FIELD BESIDE IT, NOT A BETTER NAME
         # FOR THE FIRST (hq_P's shape, adopted verbatim): COMMITS-SINCE sits immediately to its right and measures
         # what LOCK AGE cannot -- work actually attributed to that seat or row since the moment it took the lock.
         # Read together they separate the two states; read alone, LOCK AGE reports a stalled row as a busy one,
         # which is precisely how two rows sat 115m and 83m with zero output while the fleet screen looked normal.
         # ⭐ The sub-head is part of the COLUMN, and every cell in it is exactly 10 display columns wide so the
         # annotation sits under the field it annotates rather than drifting one column left of it. ⛔⭐ NO EMOJI IN
         # AN ALIGNED CELL, AND NO FIELD WIDTH CAN RESCUE ONE -- MEASURED, hq_C 2026-08-27, correcting this
         # comment's own earlier mechanism. The cause is not padding, it is that bash truncates `%.Ns` by BYTES
         # while the terminal aligns by COLUMNS, and "⛔" is 1 char / 3 bytes / 2 columns -- three different
         # numbers, which is the whole trap. "⛔ 1 dirty 0 unpushed" is chars=20 bytes=22, so at %-20.20s it
         # rendered "⛔ 1 dirty 0 unpush": a column SHORT (following fields slide LEFT) and a WORD CHOPPED.
         # ⛔ Widening does NOT fix it, tested: %-21.21s still chops ("...unpushe"), and %-22.22s finally fits
         # the text but still paints 21 columns, not 22, because the 3 bytes only ever buy 2 columns. The gap is
         # unclosable by width -- DELETE THE EMOJI, which is what TREE now does (see its cell, fixed).
         printf '\n  SEAT     ROW (open claim)                LOCK AGE    COMMITS     TREE                  Q  MAIL      LAST BOARD LINE\n'
         printf '  %-8s %-30s  %-10s  %-10s  %s\n' "" "" "lock only" "real work" ""
         printf '  ──────── ──────────────────────────────  ──────────  ──────────  ────────────────────  ─  ────────  ─────────────────────\n'
         # ⛔ SEAT LIST IS DISCOVERED, NEVER TYPED (s255): a hand-typed list silently omits any seat Lon adds,
         # and a seat missing from the health screen is a seat nobody looks at. Numeric sort so 10 follows 9.
         # ⛔⭐ THE CENSUS ENUMERATES POSTOFFICE MAILBOXES, NOT /home/claude* GLOBS (LAW 6, V2-4). The glob it
         # replaced could not see hq_C, hq_P or ceo AT ALL -- the two HQs running the fleet were invisible on the
         # fleet's own health screen, and so was every message waiting in their inboxes. It also silently omitted
         # any mailbox whose seat root is not yet cloned, which is the state every new seat starts in. The
         # postoffice IS the fleet roster; the home directories are just where the clones happen to live.
         for seat in $(s4e_boxes | sort); do
           root="$(s4e_root "$seat")"
           row="-"; lockep=0; for c in "$PO"/claims/*.claim; do [ -f "$c" ] || continue
             # ⛔ THE JOINED TEST, NOT THE CLAIM STATUS ALONE (CEO-297): this line used `! grep DONE`, which
             # reports a CLOSED row whose claim was never reconciled as an open lock -- 43 of the ceo's 52 at the
             # FLEET-12 flip. LOCK AGE and "0 STALLED" hang off this row, so the half-test alarmed on rows nobody held.
             if [ "$(head -1 "$c")" = "$seat" ] && [ "$(s4e_claim_verdict "$(basename "$c" .claim)")" = "HELD" ]; then row="$(basename "$c" .claim)"
               # ⛔ THE CLAIM FILE'S MTIME IS THE LOCK-ACQUISITION INSTANT AND NOTHING ELSE. It is not touched by
               # work, by commits, or by the seat running anything -- only by taking (or re-taking) the lock.
               lockep=$(stat -c %Y "$c" 2>/dev/null || echo 0); break; fi; done
           lockage="$(s4e_age_compact "$lockep")"
           dirty=0; unpushed=0; repos=0; csince=0
           for r in "$root"/*/; do [ -n "$root" ] || continue; [ -d "$r/.git" ] || continue; repos=$((repos+1))
             d=$(git -C "$r" status --porcelain 2>/dev/null | wc -l); dirty=$((dirty+d))
             br=$(git -C "$r" rev-parse --abbrev-ref HEAD 2>/dev/null)
             u=$(git -C "$r" rev-list --count "origin/$br..$br" 2>/dev/null || echo 0); unpushed=$((unpushed+${u:-0}))
             # ⭐ ATTRIBUTED, exactly as `banner` measures level-of-success: a bare `log --since` counts commits this
             # clone merely PULLED and would credit an idle seat with the whole fleet's output. Commit messages here
             # carry the seat id and the row topic, so attribution is the measurement. `seat8` and `seat08` are both
             # matched -- every FINDING and many commits still name seats the pre-s255 unpadded way, and matching the
             # padded form alone finds ZERO for every single-digit seat, silently.
             if [ "$lockep" -gt 0 ]; then
               salt="${seat/#seat0/seat}"
               n=$(git -C "$r" log --since="@$lockep" -i --grep="$seat" --grep="$salt" --grep="$row" --oneline 2>/dev/null | wc -l)
               csince=$((csince+${n:-0})); fi; done
           if [ -z "$root" ]; then tree="(no root, retiring)"
           elif [ "$repos" -eq 0 ]; then tree="no clones"
           elif [ "$dirty" -eq 0 ] && [ "$unpushed" -eq 0 ]; then tree="clean"
           # ⛔ NO EMOJI IN A WIDTH-CONSTRAINED CELL (hq_P 2026-08-27, fixed here by hq_C). This cell prints through
           # %-20.20s, and bash truncates by BYTES while a terminal aligns by COLUMNS. "⛔" is 1 char / 3 bytes /
           # 2 columns, so the old text measured chars=20 bytes=22: the precision chopped it to "⛔ 1 dirty 0 unpush"
           # -- ONE COLUMN SHORT (shifting Q/MAIL/BOARD left on exactly the rows that signal trouble) AND a
           # truncated word. Both the alignment and the DATA were lost, on the rows a reader most needs to read.
           # Plain ASCII here, matching the adjacent COMMITS cell's own "0 STALLED": the words are the signal.
           # Emoji stay legal in the LAST column only (bl), which is %s and constrains no width.
           else tree="${dirty} dirty ${unpushed} unpushed"; fi
           # a question can now be waiting in ANY HQ's inbox (hq is retiring, hq_C and hq_P own the two lanes),
           # so the count sums over the whole HQ set -- counting only legacy hq/ would read 0 the day it retires.
           q=0; for hb in $(s4e_hqboxes); do for f in "$PO/$hb"/inbox/*.msg; do [ -f "$f" ] || continue; case "$(basename "$f")" in *-"$seat"-q-*) q=$((q+1));; esac; done; done
           unread=0; for f in "$PO/$seat"/inbox/*.msg; do [ -f "$f" ] && unread=$((unread+1)); done
           if [ "$unread" -eq 0 ]; then mail="-"; else om="$(s4e_oldest_min "$seat")"; mail="$unread/${om:-0}m"; fi
           bl="$(grep -m1 "^$seat |" "$PO/BOARD.md" 2>/dev/null | cut -d'|' -f2- | cut -c1-40)"; [ -n "$bl" ] || bl="(never posted)"
           # ⛔ A ROW LOCKED OVER AN HOUR WITH NOTHING ATTRIBUTED IS THE STATE THIS COLUMN EXISTS TO SURFACE, so it is
           # marked rather than left for the reader to compute across two fields. Under an hour it stays quiet: a
           # freshly-claimed row legitimately has no commits yet, and flagging that would train the eye to ignore it.
           # ⛔⭐ SECOND DISCRIMINATOR, ADDED BY hq_C 2026-09-05 AFTER "0 STALLED" FIRED FALSELY ON THE SAME LIVE
           # SEAT TWICE IN TWENTY MINUTES, from two different HQs (hq_B at 1h25m, ceo at 1h44m). seat05 was mid-cure
           # the whole time: four substantive messages and a baton LEDGER rewritten minutes before each alarm.
           # COMMITS SINCE LOCK cannot see the highest-value work a seat in a census/witness lane does, and under
           # FLEET-<n> -- where seats walk/census/witness while HQs cure, and are often told NOT to touch src/ --
           # that is the MAJORITY of seats, not an edge case. "0 commits" is reachable by "stalled" and by "doing
           # exactly what its HQ told it to do", and this column named only the first, in red (RULES.md § A SIGNAL
           # REACHABLE BY TWO CAUSES THAT NAMES ONLY ONE). The documented remedy for a stall is releasing the claim,
           # so a false positive here costs a working seat its in-flight row. The baton mtime is already on disk and
           # separates the two states for free.
           bmt=0; [ -f "$PO/tasks/$row.task.md" ] && bmt=$(stat -c %Y "$PO/tasks/$row.task.md" 2>/dev/null || echo 0)
           bage=$(( ( $(date +%s) - ${bmt:-0} ) / 60 ))
           # ⛔⭐ THIRD DISCRIMINATOR, ADDED BY seat01 2026-09-05 (row fleet-stalled-is-one-signal-reachable-by-two-
           # causes-and-names-only-one, minted by hq_B after seat05/seat07/seat14 all false-positived in one sitting):
           # baton mtime alone still misses a seat whose HQ lane produces outbound messages (census/witness/ask)
           # without rewriting its own baton in the same window. Same shape as the DONE-WHEN this row grades on:
           # count messages naming this seat, newer than the lock.
           msince=0; [ "$lockep" -gt 0 ] && msince=$(find "$PO" -name "*-$seat-*.msg" -newermt "@$lockep" 2>/dev/null | wc -l)
           if [ "$lockep" -eq 0 ]; then csh="-"
           elif [ "$csince" -eq 0 ] && [ "$(( $(date +%s) - lockep ))" -gt 3600 ]; then
             if [ "${bmt:-0}" -gt 0 ] && [ "$bage" -lt 60 ]; then csh="0 baton${bage}m"; elif [ "${msince:-0}" -gt 0 ]; then csh="0 msgs${msince}"; else csh="0 STALLED"; fi
           else csh="$csince"; fi
           printf '  %-8s %-30.30s  %-10.10s  %-10.10s  %-20.20s  %s  %-8.8s  %s\n' "$seat" "$row" "$lockage" "$csh" "$tree" "$q" "$mail" "$bl"; done
         free=0; tot=0
         while IFS=$'\t' read -r rank topic brief step; do case "$rank" in ''|\#*) continue;; esac
           tot=$((tot+1)); [ -f "$PO/claims/$topic.claim" ] || free=$((free+1)); done < "$PO/QUEUE.tsv" 2>/dev/null
         printf '\n  queue: %s rows, %s free for the picker (a row with ANY claim file, DONE or not, is hidden)\n' "$tot" "$free"
         # ⛔⭐⭐ THE JOINED CLAIM CENSUS -- ONE INSTRUMENT, so the next flip runs this instead of two half-censuses
         # that disagree (ceo CEO-297, asked for by name after the FLEET-12 flip produced exactly that). Verdict logic
         # lives in s4e_claim_verdict; this block only counts and names. It prints EVERY held row with its holder, so
         # "who is holding what" is answerable without reading the seat table above, which shows one row per seat.
         _hf="$(mktemp)"; _bf="$(mktemp)"; nheld=0; nrec=0; nawait=0; norph=0; nblock=0
         for c in "$PO"/claims/*.claim; do [ -f "$c" ] || continue
           t="$(basename "$c" .claim)"; h="$(head -1 "$c")"; v="$(s4e_claim_verdict "$t")"
           case "$v" in
             HELD) nheld=$((nheld+1)); printf '  %-10s %-8s %s\n' "$h" "$(s4e_age_compact "$(stat -c %Y "$c" 2>/dev/null || echo 0)")" "$t" >> "$_hf";;
             RECEIPT) nrec=$((nrec+1));;
             AWAITING-SWEEP) nawait=$((nawait+1));;
             ORPHAN) norph=$((norph+1));;
           esac
           if s4e_claim_blocks_free_row "$t"; then nblock=$((nblock+1))
             printf '  %-10s %-14s %s\n' "$h" "$v" "$t" >> "$_bf"; fi; done
         printf '  CLAIM CENSUS (joined verdict, CEO-297): HELD iff the claim says RUNNING AND the queue row is OPEN --\n'
         printf '    open = not DONE, not RETIRED, not SUPERSEDED (the vocabulary closes a row three ways, not one).\n'
         printf '    %s HELD  ·  %s RECEIPT  ·  %s AWAITING-SWEEP  ·  %s ORPHAN\n' "$nheld" "$nrec" "$nawait" "$norph"
         if [ "$nheld" -gt 0 ]; then printf '    HELD rows (holder / lock age / row) -- the only ones a release would free:\n'; sort "$_hf"; fi
         if [ "$nblock" -gt 0 ]; then
           printf '  ⛔ %s row(s) HIDDEN FROM THE PICKER WITH NOBODY HOLDING THEM -- the queue row is not DONE, so the row is\n' "$nblock"
           printf '     open work, but a claim file exists and `next` skips ANY claimed row (:2044, :2159). No holder to ask,\n'
           printf '     no lock to release by its owner: an HQ frees these with `unclaim <row> "<why>"`.\n'
           sort "$_bf"; fi
         rm -f "$_hf" "$_bf"
         printf '  Q = questions from that seat waiting on ANY HQ.  MAIL = unread in its inbox / age of the oldest.\n'
         printf '  ⛔ LOCK AGE = how long the CLAIM FILE has existed = when the lock was TAKEN. It is NOT a work signal:\n'
         printf '     a seat that claimed a row and stalled prints the same number as a seat mid-cure. COMMITS SINCE LOCK\n'
         printf '     measures work ONLY in a committing lane (attributed to the seat or its row, across that root every\n'
         printf '     repo) -- a census/witness lane reads 0 by design, so read it alongside baton age and outbound mail.\n'
         printf '     "0 STALLED" = locked over an hour, nothing attributed, the baton untouched for an hour, AND zero\n'
         printf '     messages sent since the lock -- a claimed row hides itself from the picker, so that blocks the row\n'
         printf '     for the WHOLE fleet until an HQ releases it. "0 batonNNm" = baton written NNm ago; "0 msgsN" = N\n'
         printf '     messages sent since lock: either means that seat is WORKING, in a lane whose output is\n'
         printf '     census/witness/LEDGER/asks rather than commits. DO NOT release it.\n'
         printf '  Roster is the postoffice mailbox list, never a home-dir glob -- the glob could not see the HQs.\n'
         # ⭐⛔ IS THE LAW CONSISTENT WITH ITSELF? -- REPORTED HERE, BLOCKING NOWHERE (hq_B 2026-09-14, row
         # instruments-mode-line2-can-contradict-itself-and-every-cross-check-is-blind-to-it).
         # Every other lane instrument compares a READER against MODE line 2, so all of them are blind by
         # construction to line 2 contradicting ITSELF -- when CEO-723 left "REBUS IS CLOSED ... carries Pascal
         # and nothing else" standing beside "Rebus moves to hq_S" and "REBUS -- hq_S", the picker gate printed
         # rebus ✅ and the agreement was REAL. hq_I then routed a co-sign to "hq_S (Rebus)" off those words.
         # ⛔ IT IS PRINTED, NEVER ENFORCED, AND THE ASYMMETRY IS DELIBERATE. The gate exits 2 on prose it
         # cannot parse, and line 2 is prose the ceo reinvents at every cut (81 of 91 MODE backups are
         # unparseable to it, measured). As a blocking arm it would red all thirteen seats the next time a
         # correct lane cut used a new phrasing -- which is exactly the defect I shipped once already with the
         # mode-line parser. So the hermetic --selftest is the blocking arm in preflight_arms.txt, and the
         # LIVE verdict surfaces here, in the health view a seat runs on a cadence and the ceo reads.
         _l2g="$(dirname "${BASH_SOURCE[0]}")/test_gate_mode_line2_is_self_consistent.sh"
         if [ -x "$_l2g" ] || [ -r "$_l2g" ]; then
           _l2o="$(timeout -k 5 20 bash "$_l2g" 2>&1)"; _l2r=$?
           case "$_l2r" in
             0) printf '  MODE line 2 vs ITSELF: ✅ every language carries one consistent owner.\n';;
             1) printf '  ⛔ MODE LINE 2 CONTRADICTS ITSELF -- the law disagrees with the law, and every lane gate we own\n'
                printf '     is comparing its table against the contradiction and printing agreement:\n'
                printf '%s\n' "$_l2o" | grep -E 'CONTRADICTION|^      byte ' | sed 's/^/    /'
                printf '     ⛔ This is the ceo'"'"'s line to edit. ASK ceo/inbox with the byte offsets; do not route work\n'
                printf '        for the named language until it is cured -- a wrong-but-LIVE owner is the dangerous case,\n'
                printf '        because the message arrives somewhere that can act on it (hq_S, 2026-09-14).\n';;
             *) printf '  ⚠️  MODE line 2 vs ITSELF: could not measure (rc=%s) -- NOT a clean bill. Run %s\n' "$_l2r" "$_l2g";;
           esac
         fi
         printf '\n';;
  sweep) # ⭐ LAW 4 — THE QUEUE IS A DISPATCH BUFFER, NOT A MEMORY. v1 reached 62% dead rows (112 of 181 DONE) because
         # nothing ever moved a landed row out, so the picker walked a graveyard and HQ re-dispatched finished work.
         # This moves every row whose claim carries DONE into QUEUE.done.tsv (the memory) and rewrites the buffer.
         # ⛔ IT NEVER DELETES: every swept row is appended to QUEUE.done.tsv and the pre-sweep buffer is backed up.
         q="$PO/QUEUE.tsv"; d="$PO/QUEUE.done.tsv"; [ -f "$q" ] || { echo "no QUEUE.tsv"; exit 1; }
         cp "$q" "$q.bak.sweep-$(date -u +%Y%m%dT%H%M%SZ)"
         keep="$(mktemp)"; gone="$(mktemp)"; nk=0; ng=0
         while IFS= read -r line; do
           case "$line" in \#*) printf '%s\n' "$line" >> "$keep"; continue;; '') continue;; esac
           topic="$(printf '%s' "$line" | cut -f2)"
           if [ -f "$PO/claims/$topic.claim" ] && grep -q '^DONE$' "$PO/claims/$topic.claim"; then printf '%s\n' "$line" >> "$gone"; ng=$((ng+1))
           else printf '%s\n' "$line" >> "$keep"; nk=$((nk+1)); fi
         done < "$q"
         if [ "$ng" -gt 0 ]; then
           [ -s "$d" ] || printf '# S4E QUEUE — LANDED ROWS (the MEMORY; QUEUE.tsv is the BUFFER). Append-only.\n# rank\ttopic\tbrief\tfirst-step-and-done-when\n' > "$d"
           printf '# --- swept %s by %s: %s rows ---\n' "$(date -u +%FT%TZ)" "$ME" "$ng" >> "$d"; cat "$gone" >> "$d"
           mv "$keep" "$q"; chmod 664 "$q"; else rm -f "$keep"; fi
         rm -f "$gone"; printf 'sweep: %s live rows kept, %s DONE rows moved to QUEUE.done.tsv (nothing deleted; buffer backed up)\n' "$nk" "$ng"
         # ⛔ A DONE ROW WITH NO COMPUTED RECEIPT IS NOT SWEPT -- AND THAT IS SAID, BY NAME, rc=2 (coo 2026-09-16, CEO-790/793). It used
         # to be kept silently, indistinguishable from a live row; the ceo's audit reads this refusal.
         _nr=0; _nrl=""
         while IFS= read -r line; do
           case "$line" in \#*|'') continue;; esac
           [ "$(printf '%s' "$line" | cut -f4 | cut -d: -f1)" = DONE ] || continue
           topic="$(printf '%s' "$line" | cut -f2)"
           if [ -f "$PO/claims/$topic.claim" ] && grep -q '^DONE$' "$PO/claims/$topic.claim"; then continue; fi
           _nr=$((_nr+1)); _nrl="$_nrl    rank $(printf '%s' "$line" | cut -f1)  $topic  [owner $(printf '%s' "$line" | cut -f3); claim: $([ -f "$PO/claims/$topic.claim" ] && echo 'present, no DONE' || echo none)]\n"
         done < "$q"
         if [ "$_nr" -gt 0 ]; then
           printf '⛔ sweep REFUSES (rc=2) to move %s DONE row(s) that carry NO COMPUTED RECEIPT (no claims/<topic>.claim with DONE): they reached DONE by a path outside `done` and are NOT landed until re-run through it (or reopened):\n' "$_nr"
           printf "$_nrl"
           printf '   util_queue_visibility_census.py --grade-receiptless runs each criterion and classes it prose / refuses / red / green.\n'
           exit 2
         fi
         # ⛔⭐ (b) GARBAGE-COLLECT CLAIMS WHOSE TOPIC HAS NO LIVE ROW (hq_B 2026-08-28; runs AFTER (a) by design --
         # `done` now mirrors its close into the column, so a claim reaching this point has already had every chance
         # to be recorded). ⭐ WHY IT MATTERS AND WHY IT IS NOT COSMETIC: PASS 3 skips ANY topic that has a claim
         # file, DONE or not. Measured that day: 227 claim files against 205 live rows, 195 of them residue for
         # topics already in QUEUE.done.tsv. Re-mint any one of those 195 NAMES and the new row is INVISIBLE ON
         # ARRIVAL -- it never reaches a seat, and the queue still reads FREE. That is a trap armed by ordinary
         # success: the more work the fleet lands, the more names become undispatchable.
         # ⛔ DELETES ONLY THE REDUNDANT ONES. A claim with no live row AND a DONE latch is duplicated by
         # QUEUE.done.tsv, so removing it loses nothing. A claim with no live row and NO DONE latch is NOT residue
         # -- it is a live lock whose row was renamed or dropped underneath it, i.e. possible work in flight -- so
         # it is REPORTED AND KEPT. Deleting that one would destroy the only trace of an in-flight claim, which is
         # the mirror of the bug this whole row exists to fix.
         _gc=0; _orph=""
         for _c in "$PO"/claims/*.claim; do
           [ -f "$_c" ] || continue
           _t="$(basename "$_c" .claim)"
           grep -qP "^[0-9]+\t\Q$_t\E\t" "$q" 2>/dev/null && continue      # still a live row -- leave it alone
           if grep -q '^DONE$' "$_c"; then rm -f "$_c"; _gc=$((_gc+1))
           else _orph="$_orph $_t"; fi
         done
         printf 'sweep: %s residue claim(s) garbage-collected (DONE + no live row; QUEUE.done.tsv keeps the record)\n' "$_gc"
         [ -n "$_orph" ] && printf '⚠ KEPT, NOT DELETED — claim with NO live row and NO DONE latch (a live lock whose row vanished; investigate, do not assume residue):%s\n' "$_orph"
         :;;
  board) if [ $# -gt 1 ]; then shift; grep -v "^$ME |" "$PO/BOARD.md" 2>/dev/null > "$PO/.b.$$" || true; printf '%s | %s | %s\n' "$ME" "$*" "$(date -u +%H:%M)" >> "$PO/.b.$$"; mv "$PO/.b.$$" "$PO/BOARD.md"; fi; cat "$PO/BOARD.md"
         # posting a board line IS the handoff gesture -- so the banner fires here too (see `done` above).
         [ "${S4E_NO_BANNER:-0}" = "1" ] || S4E_BANNER_NO_BOARD=1 "$0" banner;;
  *) echo "usage: next|claim|unclaim|park|done|assign|reown|mint|ask|send|check|clear|mailbox|sweep|board|banner|fleet|whoami"
     # ⛔⭐ THE BACKTICK TRAP -- FIVE MEASURED OCCURRENCES, and it is printed here because THIS SCRIPT CANNOT
     # DETECT IT. A backtick used for emphasis inside a double-quoted body is COMMAND SUBSTITUTION: the
     # caller's shell runs the word, prints "X: command not found" on the CALLER's stderr, and substitutes
     # the EMPTY STRING. The telegram then ships well-formed and quietly missing exactly one word -- and it
     # is reliably the load-bearing one, because emphasis is what you put on the word that matters. By the
     # time send() is reached the substitution has already happened, so there is nothing left here to check;
     # a warning at the point of use is the only cure available. Occurrences on record: hq_B lost `END` from
     # a split_at_end warning, hq_S lost `live` from a paragraph about a liveness flag, plus the three in
     # CLAUDE.md from 2026-09-03 (two by the seat that had just filed the first).
     echo "⛔ in a message BODY use plain quotes or nothing for emphasis -- NEVER a backtick: it is command"
     echo "   substitution, it eats the word silently, and the message still arrives looking complete."
     exit 2;;
esac
