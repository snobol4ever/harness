#!/usr/bin/env bash
# test_gate_digest_matches_rules.sh -- GATE: no sibling-root CLAUDE.md may assert a FACT RULE's
# RETIRED text as if it were still current.
#
# WHY THIS EXISTS (row `claude-md-digest-drifts-from-rules`, minted by hq_P from seat11's find,
# FINDING-2026-08-23-hq_P-the-per-root-claude-md-digest-is-not-git-tracked-and-15-of-19-were-stale.md):
# measured s267, 15 of 19 roots carried the retired "-O2 is used ONLY for benchmark/demo runs" text
# with no mention of the s262 NO--O2 fact rule, and seat11 built at -O2 on it -- a real wasted build.
# Root cause is STRUCTURAL: each root's CLAUDE.md (D-17 PORTABLE-HOME, /home/claudeNN/CLAUDE.md etc)
# is a plain file, not tracked in any git repo, so it never updates when .github/RULES.md does, while
# being the first thing a seat reads and phrased as instruction. A memo fixes today and decays; this
# gate is the structural follow-up (.github/RULES.md's own corollary doctrine, ~line 168: "digests
# never restate law ... law that exists in one versioned file cannot go stale in nineteen unversioned
# ones" -- this gate is how that doctrine gets CHECKED instead of merely stated).
#
# METHOD, AND ITS HONEST LIMITATION: for each table entry below, grep every root's CLAUDE.md for a
# RETIRED-text pattern (a distinctive phrase from wording RULES.md itself has explicitly retired).
# A raw hit is not yet a violation -- a digest is allowed to MENTION retired text while explaining
# it is dead (RULES.md line ~149 does exactly this, on purpose, "quoted once, here, only so a reader
# who remembers it knows it was retired"). So each hit's OWN LINE is checked for a CORRECTIVE SIGNAL
# word list; only a hit with NO corrective signal on that same line counts as a violation. This is a
# substring heuristic, not comprehension -- it can miss a differently-worded stale claim and could in
# principle misfire on an unlucky sentence. It is READ-ONLY and reports for a human (or the owning
# seat) to adjudicate; it does not decide anything by itself.
#
# ⛔ CORRECTED 2026-08-24, SAME DAY AS MINT (seat15 found it, hq_C root-caused it, this seat fixed it
# -- kept here as an addendum, not a silent edit, per this project's own transcription-provenance
# rule). The ORIGINAL version checked a +-2 LINE WINDOW around each hit, and two of the signal
# alternatives were unanchored catch-alls: `correct(ed|ion)?` (the optional group matches the bare
# substring "correct", so it fires on "correctness" -- a word saturating a project whose HQ is named
# HQ-CORRECTNESS) and `csnobol4` alone (fires on any unrelated mention of the oracle tree, which every
# digest's workspace-map section contains). PROVEN BY CONSTRUCTION: a scratch file carrying the exact
# retired SEGV-handler line reported GATE PASS(0) with "correctness" one line above it, and PASS(0)
# again with "csnobol4" one line above it -- a real violation, wrongly exempted by unrelated text in a
# DIFFERENT sentence. Current state was genuinely clean when this fired (verified independently of the
# gate, by direct per-root reading), so it was not masking anything THAT day -- but the instrument
# could not have told a true clean state from a false one, which is the actual defect: a gate needs a
# test for every way it can say NOTHING, not only for every way it can say something, and the exemption
# path never had one. Fix: (1) anchor the signal check to the MATCHED LINE ONLY, never a window -- every
# real corrected example measured (both rules, all fleet roots) puts the correction in the SAME
# sentence/line as the retired text, so this loses no real recall; (2) drop both catch-alls --
# `corrected|correction` (no optional group) and `csnobol4[ -]?oracle` (adjacency required). Re-verified
# against real data after the fix: O2 rule's 3 self-aware hits still correctly exempted (0 violations,
# unchanged); SEGV rule's live violations still correctly caught. Negative-tested the exemption path
# itself, not just the three exit-code arms: hq_C's two proof-by-construction false negatives (word on
# the line ABOVE a real hit) now both correctly report VIOLATION; a same-line "correctness" (no
# "corrected"/"correction") on an otherwise-real hit now also correctly reports VIOLATION, isolating the
# regex-tightening fix from the windowing fix. Full receipts in the task file's own LEDGER and a FINDING.
#
# ⛔ SECOND CORRECTION 2026-08-26 (hq_C, found while rewriting its own root's CLAUDE.md). The 2026-08-24
# addendum above cured an EXEMPTION miss -- the gate SAW a hit and wrongly excused it. This is the
# other half, and it is a RECALL miss: the gate NEVER SAW the hit at all. NO-O2-EVER's retired-text
# pattern was the single literal phrase `used ONLY for benchmark`, so a PARAPHRASE walked straight
# past it. PROVEN BY CONSTRUCTION: hq_C's own root carried "**`-O2` is reserved for benchmark and demo
# runs**, passed explicitly: RT_OPT="-O2 ..." make" -- a live, uncorrected violation that also PRINTS
# THE FORBIDDEN COMMAND -- and the gate reported PASS(0) on it, both alone and inside the full 38-check
# run that was quoted as proof the fleet was clean. ⭐ THE TWO MISSES ARE NOT THE SAME BUG AND A TEST
# FOR ONE DOES NOT COVER THE OTHER: an exemption miss is a wrong ANSWER on a real hit; a recall miss is
# NO QUESTION ASKED. Both present identically to the reader -- as PASS(0). The 2026-08-24 note's own
# line ("a gate needs a test for every way it can say NOTHING") named the class correctly and the fix
# only covered the exemption path; the retired-text pattern was left as a single literal string, which
# is the OTHER way this gate can say nothing. Fix: (1) retired_re gains `reserved for benchmark`,
# `-O2 is (reserved|used only)`, and `RT_OPT=.?-O2` -- the last matters most because a digest printing
# the forbidden BUILD COMMAND is instructing a violation no matter how the prose is worded; (2) the
# signal list gains `never (pass|build|use|quote)` and `NO .?-O2. BUILDS` so a digest that names the
# command in order to FORBID it is still correctly exempt. Negative-tested, five arms: paraphrase alone
# -> VIOLATION; paraphrase + signal on the SAME line -> exempt; paraphrase + signal on a NEIGHBOURING
# line -> VIOLATION (hq_P's requested assertion, the 2026-08-24 anchoring preserved); bare forbidden
# RT_OPT command -> VIOLATION; hq_C's real repaired digest -> clean. Full 19-root run PASS(0) both
# before and after, so this is pure recall gain: no root is newly flagged and no verdict moved.
#
# ⛔ READ-ONLY BY DEFAULT (task's own NEXT step 2) -- THIS SCRIPT NEVER WRITES TO ANY ROOT'S CLAUDE.md.
# hq_P attempted a bulk cross-seat edit at s267 and was correctly blocked by the permission classifier
# -- one bad regex would corrupt every seat's orientation file at once. This gate REPORTS; each seat
# fixes its own copy on sight, per the standing doctrine already in every current CLAUDE.md banner.
#
# EXTENDING THE TABLE: add one more `check_rule` call at the bottom -- id, retired-text grep -E
# pattern, corrective-signal grep -E pattern, and a citation into RULES.md. Not every FACT RULE has
# a quotable retired predecessor text (most don't retire anything, they state a fresh constraint), so
# this table is seeded with the rules that DO, not a mechanical one-per-bullet transcription.
#
# ROOTS: override via DIGEST_GATE_ROOTS (space-separated list of CLAUDE.md paths) for testing against
# scratch files instead of the real fleet -- never point the real invocation anywhere but the real
# seat roots. COUNT THE POPULATION, DO NOT QUOTE IT: this comment said "the 21 real roots" while the
# array held 32, which is the same hard-coded-population defect the array itself keeps re-committing.
# The one-line census that catches a new root nobody added:
#   for r in /home/claude*/CLAUDE.md; do grep -q "$r" ../harness/scripts/test_gate_digest_matches_rules.sh || echo "UNWATCHED $r"; done
# /home/claude_cfo/CLAUDE.md was ABSENT until 2026-09-08 (hq_B, ceo RULED-DO-IT on ask-the-cfo-digest-
# is-unwatched-one-line-in-the-gates-roots-array): the cfo seat went live 2026-09-07 08:06 and the gate
# stayed green about the other 32 roots the whole time. claude_B and claude_T were ABSENT until 2026-09-04 (hq_B, ceo ruling ruling-digest-gate-roots):
# both roots were opened after this list was written, so the two HQs whose lanes are HYGIENE and TESTS
# were the two whose digests no gate read, and the gate was green about the other nineteen the whole
# time -- the same narrow-instrument shape those digests document for `command -v` and for `$?` after a
# pipe. A hard-coded population does not announce what it left out.
#
# Exit codes per lib_gate.sh: 0 CLEAN / 1 VIOLATION / 2 UNPROVEN (a root unreadable -- never silently
# skipped, per this row's own NEXT step 1).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib_gate.sh
. "$HERE/lib_gate.sh"
gate_parse_args "$@"

if [ -n "${DIGEST_GATE_ROOTS:-}" ]; then
    read -r -a ROOTS <<< "$DIGEST_GATE_ROOTS"
else
    ROOTS=(   # the twenty numbered fleet roots and the nine lettered HQ roots were removed by Lon 2026-09-16 (ceo CEO-767); six language HQ roots replace the nine
           /home/claude_icon/CLAUDE.md /home/claude_prolog/CLAUDE.md /home/claude_raku/CLAUDE.md /home/claude_pascal/CLAUDE.md /home/claude_snocone/CLAUDE.md /home/claude_snobol4/CLAUDE.md /home/claude_templates/CLAUDE.md /home/claude_runtime/CLAUDE.md /home/claude_collector/CLAUDE.md /home/claude_zetas/CLAUDE.md /home/claude_packages/CLAUDE.md \
           /home/claude_ceo/CLAUDE.md /home/claude_cto/CLAUDE.md /home/claude_coo/CLAUDE.md /home/claude_cfo/CLAUDE.md /home/claude_cao/CLAUDE.md /home/claude_cqo/CLAUDE.md)
fi

VIOLATIONS=0
EXAMINED=0
SIGNAL_WINDOW=200

# check_rule <rule_id> <retired_text_grep_-E_pattern> <corrective_signal_grep_-E_pattern> <citation> <canary_line>
#
# ⭐⭐ THE CANARY (5th arg) IS NOT OPTIONAL AND IT IS THE POINT OF THIS FUNCTION'S THIRD REVISION.
# hq_P, 2026-08-26: "You cannot fix a recall problem by improving recall, because the failure is
# silent BY CONSTRUCTION -- you have made the next miss less likely without making it any louder."
# Correct, and it is the argument against the 2026-08-26 fix on its own terms: broadening retired_re
# to catch a paraphrase is still A PATTERN, and every pattern shares the property that killed the
# original one -- WHEN IT STOPS MATCHING, NOTHING HAPPENS. So each rule now carries a known-violating
# line that MUST be caught. If the canary goes quiet -- someone "tidies" the regex, a grep flag
# changes, the alternation is broken by an unescaped char -- the gate REFUSES (rc=2) instead of
# printing the PASS(0) it would otherwise print, unchanged, forever. That converts recall from a
# hope into a tested property. ⛔ The canary must ALSO be checked against signal_re: a canary that
# the exemption path would swallow tests nothing, and would itself go quiet silently.
check_rule() {
    local rule_id="$1" retired_re="$2" signal_re="$3" citation="$4" canary="$5"
    local f lineno rest
    if [ -z "$canary" ]; then
        echo "GATE UNPROVEN(2) [$GATE_NAME]: rule $rule_id has no canary -- recall is untested and a silent miss is indistinguishable from a clean root"
        exit 2
    fi
    if ! printf '%s\n' "$canary" | grep -qiE "$retired_re"; then
        echo "GATE UNPROVEN(2) [$GATE_NAME]: CANARY DEAD for rule $rule_id -- its known-violating line is no longer matched by retired_re"
        echo "    canary: $canary"
        echo "    This gate can no longer detect the thing it exists to detect. Fix retired_re; never quiet the canary."
        exit 2
    fi
    if printf '%s\n' "$canary" | grep -qiE "$signal_re"; then
        echo "GATE UNPROVEN(2) [$GATE_NAME]: CANARY SELF-EXEMPTS for rule $rule_id -- signal_re matches the canary, so it would be excused, not caught"
        echo "    canary: $canary"
        exit 2
    fi
    for f in "${ROOTS[@]}"; do
        EXAMINED=$((EXAMINED + 1))
        if [ ! -r "$f" ]; then
            echo "GATE UNPROVEN(2) [$GATE_NAME]: required root digest is not readable at $f"
            echo "    Never counted as clean -- an unreadable root is not a compliant one."
            exit 2
        fi
        while IFS=: read -r lineno rest; do
            [ -n "${lineno:-}" ] || continue
            # ⛔ PROXIMITY, NOT SAME-LINE (ceo CEO-859, 2026-09-18). The 2026-08-24 addendum narrowed this
            # from a multi-line window to SAME LINE because an unrelated word in a different sentence was
            # exempting real violations -- and that fix is incomplete, because a root digest writes one
            # PARAGRAPH PER LINE. /home/claude_cto/CLAUDE.md line 9 is 19 KB of one line, so "same line"
            # was a five-thousand-character window: the bare word `history`, thousands of characters away
            # from the retired sentence, exempted a live NO-FINDING-FILES violation for two days and this
            # gate read PASS over it. The signal must sit NEAR the retired text it claims to correct.
            # Measured: with proximity, the cto root is caught; with it removed, it is not.
            hit=0
            while IFS= read -r window; do
                [ -n "$window" ] || continue
                printf '%s\n' "$window" | grep -qiE "$signal_re" || hit=1
            done < <(printf '%s\n' "$rest" | grep -oiE ".{0,$SIGNAL_WINDOW}($retired_re).{0,$SIGNAL_WINDOW}")
            if [ "$hit" -eq 0 ]; then
                continue
            fi
            VIOLATIONS=$((VIOLATIONS + 1))
            echo "GATE HIT [$rule_id] $f:$lineno -- retired text with no corrective signal within '"$SIGNAL_WINDOW"' chars of it"
            echo "    | $rest"
            echo "    cite: $citation"
        done < <(grep -niE "$retired_re" "$f")
    done
}

check_rule "NO-O2-EVER" \
    'used ONLY for benchmark|reserved for benchmark|-O2 is (reserved|used only)|RT_OPT=.?-O2' \
    'retire|supersed|\bdead\b|corrected|used to (carry|stand)|do not follow|never (pass|build|use|quote)|NO .?-O2. BUILDS' \
    '.github/RULES.md FACT RULE "NO `-O2` BUILDS. EVER." (~line 148-149)' \
    '**`-O2` is reserved for benchmark and demo runs**, passed explicitly: RT_OPT="-O2 -g" make'

check_rule "SEGV-HANDLER-ATTRIBUTION" \
    'CSN_NO_SEGV_HANDLER|SCRIP_NO_SEGV_HANDLER' \
    'not SCRIP|NEVER.{0,15}SCRIP|csnobol4[ -]?oracle|no getenv|corrected|correction|WRONG|never was|externally.clone' \
    '.github/RULES.md ASM-DIFF-FIRST correction, landed 2026-08-24 (~line 47)' \
    'run gdb with CSN_NO_SEGV_HANDLER=1 to get a clean backtrace'

# ⛔ WIDENED 2026-09-26 BY THE coo, ON LON'S /init: `fails loudly` REQUIRED THE ADVERB THE CANARY HAPPENS TO CARRY.
# /home/claude_coo/CLAUDE.md said "make test ... fails on the first red -- and every arm after a red is DARK" from
# its 2026-09-16 audit, five days after CEO-582 made make test loop and report, and this gate read PASS(0) over it
# on every run for ten days (measured: that line alone, rc 0 on the old pattern, rc 1 on this one). `( loudly)?`
# keeps the canary matched and catches the plain verb; the corrected digests that say "NO LONGER ABORTS/DIES ON
# THE FIRST RED" stay exempt through `no longer`, and none of the ten roots is newly flagged.
check_rule "MAKE-TEST-LOOPS-AND-REPORTS" \
    'cheapest-first list|(dies|stops|aborts|fails( loudly)?) on the first red|thirteen (arms|gates|cheap)' \
    'no longer|NOT (a |the )?(cheapest|list)|legacy|retire|supersed|previous digest|used to|history|test-sequential|loops and reports|LOOPS every|CEO-582|until CEO|before CEO' \
    '.github/RULES.md and GOAL-CEO.md CEO-582 (2026-09-11): make test is ../harness/scripts/run_blocking_set.sh, which LOOPS every arm and REPORTS green/red/refused with the denominator; the abort-on-first-red twin is make test-sequential; make preflight is the cheap hermetic set (hq_prolog finding, ceo CEO-768, 2026-09-16)' \
    'make test runs a cheapest-first list of about thirteen arms and fails loudly on the first red'

# ⛔⭐ WIDENED 2026-09-21 BY THE coo, PAID FOR IN A WRONG RUN: EVERY ALTERNATIVE ABOVE THIS LINE NAMES THE
# SEAT IN THE THIRD PERSON, AND A ROOT DIGEST IS WRITTEN IN THE SECOND. /home/claude_coo/CLAUDE.md carried
# "YOU ARE THE ONE RUNNER ... only the coo runs a rung suite or package board" for the five days after CEO-775
# retired it, and this gate read PASS(0) over that root on every run -- the pattern could not match a
# sentence addressed to the reader. MEASURED COST, 2026-09-21 18:5x CDT: on the strength of that line this
# seat ran test_snobol4_gimpel_suite.sh (SNOBOL4 is another lane's board under QUARTET), was refused rc=2
# naming CEO-775 by lib_one_runner.sh -- the RUNTIME guard caught what the DIGEST guard had missed -- and
# then re-ran it under an S4E_ONE_RUNNER_OVERRIDE the rule does not grant for another lane's board.
# ⭐ THE LESSON IS THE RULE'S, NOT THIS ROW'S: a digest speaks to "you", so a retired-text pattern that only
# knows "the coo" is checking a voice nobody writes in. Both voices are matched now, and the second-person
# alternatives are proven by exit code against the uncorrected root, not by reading.
check_rule "NO-CENTRAL-RUNNER" \
    'coo (is |-- )?THE ONE RUNNER|THE ONE RUNNER IS THE coo|one runner \(the coo\)|the coo.s (next )?pass grades|the coo runs every board|admits the coo|you are the one runner \(|you are the one runner\)|only the coo runs a (rungs|board)|the coo runs EVERY rungs and package board|the parked languages are run by nobody but you|the one runner.s alone' \
    'no central|per language|PER LANGUAGE|CEO-775|supersed|retire|history|until|used to|was the|before 09-16|runs NO board|no longer' \
    '.github/RULES.md FACT RULE -- NO CENTRAL RUNNER: ONE RUNNER PER LANGUAGE (Lon 2026-09-16 10:5x, CEO-775): every language HQ runs its own language suites; the coo runs no board' \
    'THE ONE RUNNER IS THE coo under EXECUTIVE: every rung suite or package board runs once per landing batch by the coo'

check_rule "FINDING-FILES-ARE-PERMITTED-AGAIN" \
    'FINDING FILES ARE GONE|never (create |be |write )?a .?FINDING|gone on Lon.s word 2026-09-16|FINDING files? (are|is) GONE|ZERO .?FINDING-\*\.md|no FINDING files? (exist|remain)|FINDING-\*\.md.{0,30}(is|are) (forbidden|retired|gone|ZERO)|FINDING-\*\.md.{0,12}\(gone|CEO-(760|796)|no .?FINDING-\*\.md.? (exists|may be)|FINDING-\*\.md.? IS ZERO|all 874 were removed' \
    'CEO-859|permitted again|may write a .?FINDING|deletes? them periodically|summariz|retired 2026-09-18|no longer forbidden|used to|was the rule|history' \
    '.github/RULES.md FACT RULE -- FINDING FILES ARE PERMITTED AGAIN (Lon 2026-09-18, in-chat to the cto, verbatim: "You can use as many FINDING files as you want. I will just delete them periodically. We should probably do a summarization when I delete."; CEO-859): the CEO-760/796 prohibition is RETIRED. Any seat may write one. The measured claims go into the citing baton or GOAL cursor IN THE SAME LANDING, because Lon deletes them periodically and a measurement living only in a FINDING has a deletion date.' \
    "FINDING FILES ARE GONE on Lon word 2026-09-16 (.github a2a311d0, CEO-760/796): never create a FINDING-*.md"

check_rule "GC-HEAP-HARD-CAP" \
    'refuses no (program|live set)|reserve grows to 8|reserve is the larger of 8x|grows to 8. (it|the window)|so a small (arena|window) refuses no|the window grows and collections FALL|PEAK of (collector )?exasperation|SMALLER IS NOT MONOTONICALLY MORE EXASPERATING|small window collects often and refuses no' \
    'CEO-1101|hard cap|HARD CAP|does not extend past|lazy instantiat|cap_kb=' \
    '.github/RULES.md FACT RULE -- THE GC HEAP HAS A HARD CAP AND DOES NOT EXTEND PAST IT (Lon 2026-09-21, in-chat to the ceo, verbatim: "Place a hard cap on the GC HEAP. Do not extend it." and "Do however use the lazy instantiation of memory as the heap grows."; CEO-1101): the DECLARED size is the CAP, memory inside it is committed page-granular as the heap grows, nothing above it is mapped, SCRIP_HEAP_MAX_MB names the cap itself, and A SMALL CAP CAN REFUSE A LIVE SET -- which is a row, never a reason to raise the default. The arena turn-over of CEO-1095 was an artifact of the retired 2 MB growth step.' \
    'the reserve grows to 8x it or SCRIP_HEAP_MAX_MB, so a small arena refuses no program'

# ⭐ ADDED 2026-10-07 BY THE ceo (CEO-1532), ON THE cto'S MEASUREMENT: RULES.md FACT RULE -- THE TREE IS THE PRUNED PARSE TREE
# (Lon 2026-10-03) closed CEO-1369/1377/1378 four days earlier, and the ceo, coo and cfo roots still carried CEO-1369's
# "THE C TREE IS THE CANONICAL FORM" block -- the ceo had just told the cfo to copy it -- while this gate read PASS over 66
# checks: no rule named the withdrawn text, so nothing could see it. Proved RED on the uncorrected roots before the cure.
check_rule "TREE-IS-THE-PRUNED-PARSE-TREE" \
    'C TREE IS (THE )?CANONICAL|C (parser.s )?tree is the canonical (form|shape)' \
    'WITHDRAWN|PRUNED PARSE TREE|supersed|retire|history|used to|was the' \
    '.github/RULES.md FACT RULE -- THE TREE IS THE PRUNED PARSE TREE (Lon 2026-10-03, in-chat to hq_snocone; restates and closes CEO-1369/1377/1378; ceo CEO-1532): the shape is the one the rule produces, never the C tree' \
    '**THE TREE IS BUILT ONCE, DIRECTLY, IN RECOGNITION ORDER; THE C TREE IS THE CANONICAL FORM; NO POST-PROCESSING (Lon 2026-09-30 morning, in-chat to the cfo)'

gate_floor "$EXAMINED" 2 "root-digest checks (roots × rules)"
gate_verdict "$VIOLATIONS" "root digest(s) asserting retired FACT RULE text uncorrected"
