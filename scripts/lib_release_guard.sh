#!/bin/bash
# lib_release_guard.sh -- shared predicate for done/unclaim/park: did an authority ruling arrive
# in this seat's inbox archive, for this claim, after the claim was taken, without the baton being
# touched since?  Sourced, never executed.
#
# See release-verbs-refuse-on-unfolded-authority-mail.task.md for the full spec (hq_C, 2026-08-30).
# THE RULE, restated: key the check ONLY on fields the POSTOFFICE ITSELF writes -- the archived
# message's own filename (nanos + sender) and the baton's own mtime -- never message prose, never
# fuzzy topic matching.  A ruling's topic almost never equals the row's topic (measured), so this
# deliberately does NOT filter the archive scan by topic at all: any authority-sender message that
# landed after claim_start counts, on the theory that an occasional false-positive nudge (unclaim/
# park only WARN + append, never refuse) is a far cheaper failure than the one this row was minted
# to kill -- a real ruling silently never reaching the baton that governs the next picker read.
#
# claim_start: real claim files written by plain `claim` carry no embedded timestamp (just the seat
# name); this row's own DONE-WHEN test constructs a synthetic claim file as "<seat> <epoch_seconds>"
# on its first line.  _s4e_rg_claim_start_ns honors that exact format when present (a bare integer
# second field on line 1) and falls back to the claim file's own mtime otherwise -- both are fields
# the postoffice (or the filesystem) writes, never the sender.

_s4e_rg_authority_set=" ceo hq hq_B hq_C hq_P "

# _s4e_rg_claim_start_ns <claim_file> -- prints claim_start in nanoseconds, or fails (return 1).
_s4e_rg_claim_start_ns() {
    local claim_file="$1" line1 ts mt
    [ -f "$claim_file" ] || return 1
    line1="$(head -1 "$claim_file" 2>/dev/null)"
    ts="$(printf '%s' "$line1" | awk '{print $2}')"
    case "$ts" in
        ''|*[!0-9]*) : ;;                                    # not a bare integer -- fall through
        *) printf '%s\n' "$(( ts * 1000000000 ))"; return 0 ;;
    esac
    mt="$(stat -c %Y "$claim_file" 2>/dev/null)" || return 1
    printf '%s\n' "$(( mt * 1000000000 ))"
}

# s4e_unfolded_authority_mail <seat> <topic>
#   return 0 (UNFOLDED, guard fires): an authority-sender archive entry landed after claim_start
#            AND the baton's own mtime predates the newest such entry -- released without the seat
#            ever touching the artifact since the mail arrived.
#   return 1 (not unfolded, or WARN-and-don't-refuse per spec S4): no claim record, no baton, no
#            archive dir, no qualifying entry, or the baton was written at/after the newest entry.
#            A missing claim/baton is a WARN case (absence of a claim is not evidence of unfolded
#            mail), printed to stderr, never a refusal -- callers decide what a WARN means to them.
s4e_unfolded_authority_mail() {
    local seat="$1" topic="$2"
    if [ -z "$seat" ] || [ -z "$topic" ]; then
        echo "s4e_unfolded_authority_mail: usage <seat> <topic>" >&2
        return 2
    fi
    local po="${S4E_PO:-$PO}"
    if [ -z "$po" ]; then
        echo "s4e_unfolded_authority_mail: S4E_PO/PO not set" >&2
        return 2
    fi

    local claim_file="$po/claims/$topic.claim"
    local baton="$po/tasks/$topic.task.md"
    local archive_dir="$po/$seat/archive"

    if [ ! -f "$claim_file" ]; then
        echo "s4e_unfolded_authority_mail: WARN no claim record for '$topic' -- absence of a claim is not evidence of unfolded mail" >&2
        return 1
    fi
    if [ ! -f "$baton" ]; then
        echo "s4e_unfolded_authority_mail: WARN no baton for '$topic'" >&2
        return 1
    fi
    [ -d "$archive_dir" ] || return 1   # never received any mail -- nothing to have missed

    local claim_start_ns
    claim_start_ns="$(_s4e_rg_claim_start_ns "$claim_file")" || return 1

    local baton_mtime_s baton_mtime_ns
    baton_mtime_s="$(stat -c %Y "$baton" 2>/dev/null)" || return 1
    baton_mtime_ns=$(( baton_mtime_s * 1000000000 ))

    local newest=-1 f base nanos sender
    for f in "$archive_dir"/*.msg; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"
        nanos="${base%%-*}"
        case "$nanos" in ''|*[!0-9]*) continue ;; esac       # filename doesn't start with a number -- not ours to parse
        sender="${base#*-}"; sender="${sender%%-*}"
        [ "$sender" = "$seat" ] && continue                  # excluding $ME, per spec S1
        case "$_s4e_rg_authority_set" in
            *" $sender "*) : ;;
            *) continue ;;
        esac
        [ "$nanos" -ge "$claim_start_ns" ] || continue
        [ "$nanos" -gt "$newest" ] && newest="$nanos"
    done

    [ "$newest" -ge 0 ] || return 1   # no qualifying authority mail found

    [ "$baton_mtime_ns" -lt "$newest" ]   # UNFOLDED iff the baton predates the newest qualifying mail
}

# s4e_release_guard_note <topic> <verb> -- appends the pointer block spec S3 requires: never a
# substitute for the ruling itself, always a pointer to go re-read the archived message.  Caller
# (unclaim/park) is responsible for calling this ONLY after s4e_unfolded_authority_mail fired.
s4e_release_guard_note() {
    local topic="$1" verb="$2" seat="$3" po="${S4E_PO:-$PO}"
    local baton="$po/tasks/$topic.task.md"
    local archive_dir="$po/$seat/archive"
    [ -f "$baton" ] || return 1
    local claim_start_ns
    claim_start_ns="$(_s4e_rg_claim_start_ns "$po/claims/$topic.claim")" || claim_start_ns=0
    {
        printf '\n## UNFOLDED-AUTHORITY-MAIL (auto-written by %s, %s)\n' "$verb" "$(date -u +%FT%TZ)"
        local f base nanos sender
        for f in "$archive_dir"/*.msg; do
            [ -e "$f" ] || continue
            base="$(basename "$f")"
            nanos="${base%%-*}"
            case "$nanos" in ''|*[!0-9]*) continue ;; esac
            sender="${base#*-}"; sender="${sender%%-*}"
            [ "$sender" = "$seat" ] && continue
            case "$_s4e_rg_authority_set" in *" $sender "*) : ;; *) continue ;; esac
            [ "$nanos" -ge "$claim_start_ns" ] || continue
            local rest topic_part
            rest="${base#*-}"; rest="${rest#*-}"; topic_part="${rest%.msg}"
            printf -- '- %s · %s · arrived %s · NOT reflected in this baton at release time (re-read the archived message, this line is a pointer, not the ruling)\n' \
                "$sender" "$topic_part" "$(date -u -d "@$(( nanos / 1000000000 ))" +%FT%TZ 2>/dev/null || echo "epoch-ns:$nanos")"
        done
    } >> "$baton"
}
