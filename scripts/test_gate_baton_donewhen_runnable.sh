#!/bin/bash
# test_gate_baton_donewhen_runnable.sh -- V2-2 cross-verification (hq_P), the companion to hq_C's
# test_gate_fleet_protocol_e2e.sh.
#
# THE QUESTION: hq_C's `done` REFUSES a row whose DONE-WHEN exits non-zero. That is correct and it is LAW 1.
# But it means a DONE-WHEN that is PROSE rather than a command can never exit 0 either -- bash returns 2 on a
# parse error, 127 on an unknown word -- so the row becomes PERMANENTLY UNCLOSEABLE. Safe-by-default, and
# useless: a seat does the work and then cannot close the row, for any amount of correct work.
# LAW 1 already says it -- "a COMMAND that can exit non-zero, never prose" -- and nothing enforced it.
#
# ⛔ THIS GATE NEVER EXECUTES A DONE-WHEN. Running them would build, test and profile the whole tree. It
# checks two static properties instead:
#   (1) does it PARSE as shell?                    bash -n -c
#   (2) does its first command word RESOLVE?        command -v, after skipping VAR=val prefixes
# Both are necessary, neither is sufficient -- a criterion can be runnable and still be a bad test (see
# `DONE-WHEN: true`, which this gate deliberately also refuses).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_gate.sh"
# ⛔ THE ONE AUTHORITY for "what is the first command word" -- never a fifth copy of the old awk one-liner,
# which called two live, one of them CURED, rows PERMANENTLY UNCLOSEABLE (hq_S 2026-09-11). See lib_donewhen.sh.
. "$HERE/lib_donewhen.sh" || { echo "⛔ GATE REFUSES(2): lib_donewhen.sh unloadable -- this gate will not re-derive the first-word rule" >&2; exit 2; }
gate_parse_args "$@"
PO="${S4E_POSTOFFICE:-/home/resources/postoffice}"
TASKS="$PO/tasks"
gate_require "$TASKS" "the postoffice task-baton directory"
# ⛔⭐ THE EXTRACTOR IS GRADED BEFORE IT IS TRUSTED, and arm 1 of its selftest is hq_S's exact input. An
# extractor nobody tested is how `D=$(mktemp -d) && bash x.sh` came to convict a cured row: the rule looked
# obviously right in one line of awk, and no fixture ever put a space inside a substitution in front of it.
if ! donewhen_selftest > /tmp/.dw_selftest.$$ 2>&1; then
    echo "⛔ GATE REFUSES(2): lib_donewhen.sh fails its own selftest -- the first-word rule is wrong, so every verdict below would be" >&2
    cat /tmp/.dw_selftest.$$ >&2; rm -f /tmp/.dw_selftest.$$; exit 2
fi
echo "first-word extractor: $(tail -1 /tmp/.dw_selftest.$$)"; rm -f /tmp/.dw_selftest.$$

# ⛔⭐ THE PLACEHOLDER RULE IS THE SHIPPED ONE, EXTRACTED, NEVER A SECOND SPELLING (coo 2026-09-17, ceo CEO-829;
# the same extraction test_gate_baton_hidden_criterion.sh already uses).  A gate carrying its own idea of what a
# placeholder looks like is how two readers of one file come to disagree.
_MSG_SH="$HERE/s4e_msg.sh"
if [ -f "$_MSG_SH" ]; then
    _PH="$(awk '/^s4e_donewhen_is_placeholder\(\)/ { grab=1; print; next } grab && /^[^[:space:]]/ { grab=0 } grab { print }' "$_MSG_SH")"
    [ -n "$_PH" ] && eval "$_PH"
fi
type s4e_donewhen_is_placeholder >/dev/null 2>&1 || {
    echo "⛔ GATE REFUSES(2): could not load s4e_donewhen_is_placeholder out of $_MSG_SH -- this gate will not re-derive the placeholder rule, and counting placeholders as ordinary rows would hide the population CEO-829 exists to keep visible" >&2; exit 2; }

# ⛔ DECORATED NO-OP EVASION (row `donewhen-decorated-noop-evasion`; proven live by seat10 2026-08-23, see
# FINDING-2026-08-23-seat10-rung-gate-false-green-audit-continued.md and
# FINDING-2026-08-22-hq_P-v2-5-thirty-one-gates-can-now-say-no.md, which names this exact hole). The old
# check here was `tr -d '[:space:]'` then an EXACT-STRING match against true/:/exit0//bin/true -- it caught
# only the bare form. Proven live: `exit 0 # nothing to verify`, `: ok, done`, and `echo done` ALL reported
# "runnable" -- a trailing comment, a decorative argument, or a real-but-unconditionally-succeeding command
# all slide past both an exact-string blocklist and a first-word-resolves check (# is not a word here, and
# echo/true/:/exit all resolve as real builtins). strip_donewhen_comment removes a trailing shell comment
# the way bash itself would -- quote-aware: a `#` starts a comment only outside any quoting and at the
# start of a word -- WITHOUT ever executing $dw. Verified against the real postoffice's own `#`-bearing
# DONE-WHENs (quoted grep patterns, a nested python -c string) before landing: none are touched, because
# none has an unquoted, word-initial `#`.
strip_donewhen_comment() {
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
# ⛔⭐⭐ THE POPULATION IS THE LIVE ROWS, AND THAT IS A RULING, NOT AN OPTIMISATION (ceo CEO-546, on hq_S's
# census 2026-09-11: FINDING-2026-09-11-hq_S-ninety-eight-live-rows-carry-a-done-when-that-can-never-exit-
# zero-and-the-gate-that-says-so-is-unwired.md). Over ALL batons this gate counted 154 uncloseable criteria
# and was therefore unwireable: most belong to rows long since closed, where a dead DONE-WHEN costs nobody
# anything, and reding `make test` for nine seats over that backlog is how a true gate gets disabled rather
# than satisfied. Cross-referenced against QUEUE.tsv for rows a picker can actually SERVE -- state FREE or
# CLAIMED: -- the number that bites is 98, with 55 at rank 0 or 1.
# ⛔ THE CEO'S DISTINCTION, WHICH IS SHARPER THAN THE ASK IT ANSWERS: done-row batons are EXCLUDED BY
# POPULATION, never EXEMPTED BY STATE. An exemption says "this row may carry a dead criterion" -- a
# permanent hole that grows every time a row closes. A population says "the set at risk is the rows that
# can still be served", so a row leaves it BY BEING CLOSED rather than by being forgiven.
# ⛔⛔ ANTI-SILENCE, AND IT IS THE ARM THIS GATE WOULD MOST LIKELY HAVE SHIPPED WITHOUT. A gate whose
# population derives from QUEUE.tsv goes QUIET exactly when QUEUE.tsv breaks -- the file is not version
# controlled, it is rewritten by every seat, and a parse failure or a truncation would read here as "zero
# uncloseable rows", which is the shape of total success. So an unreadable queue and a ZERO-sized live
# population are both rc=2 REFUSALS, never a pass.
QUEUE="$PO/QUEUE.tsv"
[ -r "$QUEUE" ] || { echo "⛔ GATE REFUSES(2): cannot read $QUEUE -- the live-row population is unknowable, and an unknown population is not an empty one"; exit 2; }
LIVE=$(mktemp) || exit 2
trap 'rm -f "$LIVE"' EXIT
awk -F'\t' '$1 ~ /^[0-9]+$/ && $2 != "" && ($4 == "FREE" || $4 ~ /^CLAIMED:/) { print $2 }' "$QUEUE" | sort -u > "$LIVE"
NLIVE=$(grep -c . "$LIVE" || true)
[ "${NLIVE:-0}" -gt 0 ] || { echo "⛔ GATE REFUSES(2): $QUEUE yielded ZERO live rows (FREE or CLAIMED) -- that is the reading an empty or malformed queue produces, and it is indistinguishable from perfect health"; exit 2; }
N=0; BAD=0; WARN=0; PLACE=0; PLACE_ROWS=""
for f in "$TASKS"/*.task.md; do
    [ -f "$f" ] || continue
    _topic="$(basename "$f" .task.md)"
    grep -qxF "$_topic" "$LIVE" || continue
    t=$(basename "$f" .task.md); N=$((N+1))
    dw=$(sed -n 's/^DONE-WHEN:[[:space:]]*//p' "$f" | head -1)
    if [ -z "$dw" ]; then echo "  ⛔ $t: NO DONE-WHEN line"; BAD=$((BAD+1)); continue; fi
    # ⭐ THE PLACEHOLDER IS ITS OWN CLASS, NEITHER UNCLOSEABLE NOR CLEAN (CEO-829).  Since 2026-09-17 mint writes a
    # RUNNABLE always-red placeholder, so such a row is honestly RED -- `done` can never close it -- and counting it
    # as UNCLOSEABLE punished the sanctioned act of minting (twice in one hour that day, both on rows the ceo asked
    # for, both redding make test for every seat).  But it must not vanish into "runnable" either: a row nobody has
    # written a criterion for is real debt, so it is counted, named and ratcheted SEPARATELY below.
    if s4e_donewhen_is_placeholder "$dw"; then
        PLACE=$((PLACE+1)); PLACE_ROWS="$PLACE_ROWS $t"; continue
    fi
    # A "simple" DONE-WHEN (no ; | & ` or $( -- no sequencing/piping/substitution) is checked whole: once
    # its trailing comment is stripped, is it (or does it start with) a command that always exits 0
    # regardless of what follows? true, :, and /bin/true ignore all arguments by POSIX definition; echo
    # cannot fail short of a write error. A NON-simple DONE-WHEN (e.g. `cmd1 && cmd2`) is left to the
    # parse/first-word checks below -- this gate does not attempt to trace exit-status propagation through
    # chains.
    dw_nc=$(printf '%s\n' "$dw" | strip_donewhen_comment)
    dw_norm=$(printf '%s' "$dw_nc" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+/ /g')
    if ! printf '%s' "$dw_norm" | grep -qE '[;|&`]|\$\('; then
        first_nc=$(donewhen_first_word "$dw_norm")
        noop=0
        case "$dw_norm" in "exit 0"|exit0) noop=1 ;; esac
        case "$first_nc" in true|:|/bin/true|echo) noop=1 ;; esac
        if [ "$noop" = "1" ]; then
            echo "  ⛔ $t: NO-OP criterion (decorated) -- '$dw' reduces to '$dw_norm', which certifies nothing"
            BAD=$((BAD+1)); continue
        fi
        case "$first_nc" in
            printf|return)
                echo "  ⚠ $t: WARN -- DONE-WHEN opens with '$first_nc', which can succeed while checking nothing"
                echo "        (or fail only for reasons unrelated to this row's claim) -- review: '$dw'"
                WARN=$((WARN+1))
                ;;
        esac
    fi
    # ⛔ CONTROL CHARACTERS. Learned the hard way, hq_P 2026-08-22: a criterion written through
    # python's re.sub had its \b word-boundaries turned into literal BACKSPACE bytes by the
    # replacement-escape processing. It parsed fine, its first word resolved fine, grep matched
    # NOTHING, and `! grep` therefore returned 0 -- a criterion that could only ever say YES.
    # A control byte in a DONE-WHEN silently changes what it means. Refuse it.
    if [ "$dw" != "$(printf '%s' "$dw" | tr -d '\001-\010\013\014\016-\037')" ]; then
        echo "  ⛔ $t: DONE-WHEN contains a CONTROL CHARACTER -- it does not mean what it looks like"
        echo "        $(printf '%s' "$dw" | cat -v | cut -c1-96)"
        BAD=$((BAD+1)); continue
    fi
    if ! bash -n -c "$dw" 2>/dev/null; then
        echo "  ⛔ $t: DONE-WHEN IS PROSE (does not parse as shell) -- row is PERMANENTLY UNCLOSEABLE"
        echo "        $(echo "$dw" | cut -c1-96)"
        BAD=$((BAD+1)); continue
    fi
    # ⛔⭐ THE FIRST WORD COMES FROM A SCANNER THAT RESPECTS QUOTING AND $( ) NESTING, NEVER FROM WHITESPACE
    # SPLITTING (lib_donewhen.sh; hq_S's measured false positive, 2026-09-11). `D=$(mktemp -d) && bash x.sh`
    # split into `D=$(mktemp` and `-d)`, and this arm convicted the row on `-d)` -- PERMANENTLY UNCLOSEABLE
    # printed over a criterion that parses and runs to rc=0, on a row that had just been CURED. bash -n two
    # checks above had ALREADY proved the line parses; the word had only to be taken the way bash takes it.
    first=$(donewhen_first_word "$dw")
    case "$first" in ''|'['|test|cd) continue ;; esac
    # ⛔⭐ A WORD CARRYING AN EXPANSION OR A QUOTE IS NOT RESOLVABLE BY ANY STATIC CHECK -- AND IT IS NOT
    # SILENTLY SKIPPED EITHER. Both halves were measured on the live queue in one sitting (hq_T 2026-09-11):
    # skipping cleared hq_S's false positive AND lost a true one, `icon-bare-repeated-alternation-...`, whose
    # criterion opens with a BACKTICKED PHRASE and is genuine prose -- the old arm convicted it by accident,
    # and a bare `continue` here would have made real debt invisible. ⭐ THE THIRD ANSWER IS THE RIGHT ONE:
    # a checker that cannot measure says so, out loud, by name. It warns rather than convicting, so no row is
    # called PERMANENTLY UNCLOSEABLE on a word nobody could resolve, and no row disappears from the list.
    if ! donewhen_word_is_resolvable "$first"; then
        echo "  ⚠ $t: first command word is '$first' -- an expansion or quoted word NO STATIC CHECK CAN RESOLVE, so this row is NEITHER cleared NOR convicted here; read it by hand"
        echo "        $(echo "$dw" | cut -c1-96)"
        WARN=$((WARN+1)); continue
    fi
    if ! command -v "$first" >/dev/null 2>&1; then
        echo "  ⛔ $t: first word '$first' is not a command -- row is PERMANENTLY UNCLOSEABLE"
        echo "        $(echo "$dw" | cut -c1-96)"
        BAD=$((BAD+1))
    fi
done
echo ""
echo "examined $N live row(s) of $NLIVE in the queue: runnable=$((N-BAD-PLACE))  UNCLOSEABLE=$BAD  PLACEHOLDER=$PLACE  WARN=$WARN"
# ⭐⭐ THE PLACEHOLDER FLOOR, REPORTED AND NOT BLOCKING, AND THE MARKING IS IN THIS GATE'S OWN TEXT RATHER THAN IN A
# recipe comment (ceo CEO-822: the REPORTED marking travels with the instrument, because a gate that is copied, moved
# between recipes or run by hand keeps only what it says itself).
# ⛔ WHY IT DOES NOT BLOCK: minting a row is the sanctioned way to add work, and a class that reds on GROWTH would red
# make test for every seat the moment the ceo mints anything -- the exact defect CEO-829 was raised to cure.  What it
# must not do is HIDE: this count is named on its own line every run, and a FALL is announced so it gets banked.
# ⭐ THE LIFT, stated so nobody has to ask: when PLACEHOLDER reaches 0 this class goes BLOCKING at 0, and the ceiling
# below joins it -- a row minted from that day carries a real criterion or it is not minted.
PLACE_FLOOR=87
if [ "$PLACE" -gt "$PLACE_FLOOR" ]; then
    echo "  ⚠ PLACEHOLDER $PLACE > floor $PLACE_FLOOR -- REPORTED, NOT BLOCKING: rows minted with no criterion yet. Each is RED (its DONE-WHEN exits 1) and cannot close; write the criterion or unclaim the row."
elif [ "$PLACE" -lt "$PLACE_FLOOR" ]; then
    echo "  ⭐ PLACEHOLDER $PLACE < floor $PLACE_FLOOR -- FELL by $((PLACE_FLOOR-PLACE)). BANK IT: lower PLACE_FLOOR to $PLACE in this gate, in your next commit."
else
    echo "  PLACEHOLDER $PLACE, exactly at its floor $PLACE_FLOOR (REPORTED, NOT BLOCKING; blocking at 0 when it gets there)."
fi
gate_floor "$N" 10 "live rows with batons (a postoffice with no live batons proves nothing)"
# ⭐ CEILING 93 (hq_S 2026-09-11, ceo CEO-546 landing; measured 98 in the finding two hours earlier).
# ⛔⭐ A FALL PASSES HERE, AND THAT IS A DELIBERATE DEPARTURE FROM THE HOUSE RATCHET SHAPE -- read this
# before "fixing" it back. test_gate_orphaned_witnesses_do_not_grow.sh reds on a FALL as well as a rise, so
# that paying debt down forces the floor lower in the same commit, and that is right THERE because its
# population is the CORPUS: version-controlled, and it moves only when someone commits. This gate's
# population is QUEUE.tsv, which is not version-controlled and is rewritten by every seat on every claim,
# close, park and mint. MEASURED: the live count moved 98 -> 93 inside one sitting with nobody paying a
# single DONE-WHEN -- rows simply closed and new ones were minted. A strict ratchet over a population that
# volatile reds the build for nine seats several times an hour for reasons no commit caused, and a gate
# that cries wolf is a gate that gets commented out -- the exact failure the ruling exists to avoid.
# So: GROWTH IS RED, a fall PASSES and says loudly what the new ceiling should be. That is also the ruling's
# own wording ("red only if the count goes UP"). ⛔ THE COST, NAMED RATHER THAN DISCOVERED LATER: a fall that
# nobody banks leaves headroom, so a later regrowth back toward 93 is invisible. The cure for that is to
# bank it -- lower this number whenever you see the ⭐ line -- and step 3 of the ruling is CEILING=0, at
# which point the headroom problem disappears because there is none.
# ⭐ CEILING 93 -> 89 (hq_S 2026-09-11, same sitting, one landing later). SIX of my own rows were paid --
# every hq_S row in the finding's per-owner column, written as real commands and each PROVEN RED before
# being banked -- and the count fell by FOUR, not six, because the live population moved 439 -> 437 under
# the same edit. That is the volatility this gate's header argues about, visible in its own first ratchet
# move: the number is a property of the queue as much as of the debt, which is exactly why a fall here
# passes loudly instead of reding the build.
# ⭐⭐ CEILING 89 -> 3 (coo 2026-09-17, ceo CEO-829). NOT a cure of 86 rows: a MEASUREMENT that 86 of the 89 were
# never broken criteria at all. They were the MINT PLACEHOLDER, which was prose until this sitting and is now a
# runnable always-red command, so they moved to the PLACEHOLDER class above and what is left -- THREE -- is the real
# population this ceiling was always about: DONE-WHEN text that cannot parse or whose first word is not a command.
# ⛔ The two numbers must be read together or the drop looks like work nobody did: UNCLOSEABLE 3 + PLACEHOLDER 87.
CEILING=3
if [ "$BAD" -gt "$CEILING" ]; then
    echo "⛔ GATE FAIL [baton_donewhen_runnable]: $BAD live row(s) carry a DONE-WHEN that can never exit 0, ceiling $CEILING -- GREW by $((BAD-CEILING))"
    echo "   A row in this list can be cured perfectly and still record no flip, because \`done\` cannot pass on it."
    echo "   Fix the criterion on the rows named above, or -- if you minted one -- make it a command before you push."
    exit 1
fi
if [ "$BAD" -lt "$CEILING" ]; then
    echo "⭐ GATE PASS [baton_donewhen_runnable]: $BAD live row(s) uncloseable, ceiling $CEILING -- FELL by $((CEILING-BAD)). BANK IT: lower CEILING to $BAD in this gate, in your next commit."
    exit 0
fi
echo "✅ GATE PASS [baton_donewhen_runnable]: $BAD live row(s) uncloseable, exactly at the ceiling $CEILING -- not grown"
exit 0
