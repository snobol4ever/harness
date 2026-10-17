#!/usr/bin/env bash
# ⭐⭐ GATE: `next` REFUSES A ROW OF A LANGUAGE THE ORDER OF WORK HAS PARKED -- AND SAYS SO.
# Row `snobol4-icon-postoffice-next-refuses-a-row-of-a-language-parked-by-the-order-of-work-on-mode-line-2`
# (CEO-489, hq_P). ⛔ THE MEASURED DEFECT, 2026-09-10: MODE line 1 read NONET and line 2 carried
# `THE ORDER OF WORK IS ICON ONLY`, and `s4e_msg.sh next` served hq_P a rank-0 SNOBOL4 row through the
# owner-cell pass. The picker DID hold a language-freeze check; its extractor matched exactly one spelling,
# `ON <LANG> ONLY`, and the ceo had written `IS ICON ONLY`. The extractor returned EMPTY, empty is
# documented in the picker as NO FREEZE (never "undetermined"), and so every parked-language row in the
# queue became servable -- silently, with no refusal to read. The only thing between an idle seat and hours
# of parked-language work was the seat remembering to refuse.
# ⛔ WHY THE EXISTING GATE WAS GREEN THROUGH ALL OF IT: test_gate_next_honours_the_lane_cut.sh has a
# freeze arm, and its fixture writes `ON SNOBOL4 ONLY` -- the one spelling the parser knew. The gate and the
# code under test shared the assumption, so the canary died with the guard. ⭐ THIS GATE'S FIRST ARM IS
# THEREFORE THE LIVE PROSE VERBATIM, not a spelling chosen to suit the parser: an arm that grades a fixture
# written to match the implementation grades nothing.
# ✅ THE CURE UNDER TEST: THE ORDER OF WORK is DECLARED in a machine line the bus reads --
#     ORDER-OF-WORK: icon
# -- the whitespace/comma-separated list of LIVE languages, matched BY MARKER anywhere in MODE (never by
# line number: the ceo prepends each dated entry, so a positional line would be shoved down by the next
# announcement and start answering for a superseded order of work). Absent marker falls back to the prose
# parse, now widened to the `IS` form as well, so the cure never reads as a loosening.
# ARMS: (a) the live `IS` spelling parks a rank-0 SNOBOL4 row and the icon row is served instead
#       (b) the skip is PRINTED, naming the parked topic and the order of work -- never a silent skip
#       (c) the marker line alone parks it, with no ONLY clause in prose anywhere
#       (d) the marker is AUTHORITATIVE OVER PROSE in the opening direction (marker snobol4 vs prose ICON)
#       (e) THE ORDER OF WORK IS A SET, not one language: `icon snobol4` serves the SNOBOL4 row
#       (f) `ORDER-OF-WORK: all` restricts nothing
#       (g) POSITIVE CONTROL -- no marker and no ONLY clause: the SNOBOL4 row is served (no misfire)
#       (h) the marker is found deep in the file, and the FIRST of several wins (prepend-newest)
#       (i) a language-neutral topic is never parked by any order of work
#       (j) an EXPLICIT ASSIGNMENT outranks the order of work -- the ceo dispatching a parked-language row
#           by name is a deliberate direction, the same precedent `claim` and the rank cap already set
#       -- ARMS (k)..(o) added hq_S 2026-09-10, THE SAME DEFECT ONE OPERAND OVER (see below) --
#       (k) a row whose SLUG names no language but whose BATON names SNOBOL4's own witnesses is parked
#       (l) POSITIVE CONTROL for (k) -- a slug-neutral row whose baton names NO language's witnesses IS served
#       (m) a DECLARED `LANGUAGE:` line in the baton parks the row on its own, with no witness path anywhere
#       (n) AMBIGUITY STAYS NEUTRAL -- a baton naming TWO languages' witnesses is served, so the cure can
#           only ever TIGHTEN: no row the freeze already refused becomes servable because of it
#       (o) the SLUG still outranks the baton -- an `icon-` row whose baton greps SNOBOL4 is served under ICON
# HERMETIC: builds its own scratch postoffice under mktemp; reads and writes nothing under /home/resources.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="${SUT:-$HERE/s4e_msg.sh}"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$SUT" ] || refuse "picker under test not found: $SUT"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_order_of_work.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/tasks" "$W/claims" "$W/released"
# the seats under test are hq_snobol4 and hq_prolog (coo 2026-09-25): the arms ran as hq_P and hq_S, and since the NONET
# flip at 87701eadb the seat guard admits only the five HQs it names under NONET, so every arm read a guard refusal
# instead of the picker (18 of 19 red on origin); the comments keep the old names, which record who found each arm
for s in ceo hq_C hq_B hq_P hq_S hq_T seat07 hq_snobol4 hq_prolog; do mkdir -p "$W/$s/inbox" "$W/$s/archive"; done
mk(){ printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$W/QUEUE.tsv"; printf '# TASK %s\nGOAL: fixture\nDONE-WHEN: true\n## NEXT\nfixture\n## QA\n## LEDGER\n' "$2" > "$W/tasks/$2.task.md"; }
# ⭐ mkb = mk with a CHOSEN BATON BODY. Arms (k)..(o) turn on what the baton says, and `mk`'s fixed
# "GOAL: fixture" says nothing -- which is exactly why every arm above passed while the live picker was
# handing out parked-language rows whose language lived only in their baton.
mkb(){ printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$W/QUEUE.tsv"; { printf '# TASK %s\n' "$2"; shift 4; printf '%s\n' "$@"; printf '## QA\n## LEDGER\n'; } > "$W/tasks/$2.task.md"; }
run_next(){ S4E_POST="$W" S4E_SEAT="$1" S4E_RELEASE_COOLDOWN=0 bash "$SUT" next 2>&1; }
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
reset_q(){ : > "$W/QUEUE.tsv"; rm -f "$W/claims/"*.claim 2>/dev/null; }
# The MODE fixture: line 1 the bare value, then dated prose entries newest-first, exactly as the live file
# is shaped. Extra lines are passed through verbatim so an arm can place a marker at any depth.
set_mode(){ : > "$W/MODE"; local l; for l in "$@"; do printf '%s\n' "$l" >> "$W/MODE"; done; }
# ⭐ THE LIVE PROSE, COPIED FROM /home/resources/postoffice/MODE line 2 as it stood 2026-09-10 -- the
# spelling that actually defeated the picker. Never rewrite this to suit the parser; that is the defect.
LIVE_L2='# 2026-09-09 09:0x CDT ceo: MODE stays NONET; THE ORDER OF WORK IS ICON ONLY, on Lon'"'"'s word (2026-09-09 09:0x CDT, in-chat to ceo, verbatim: "Switch to Icon completely.").'
OTHER_L2='# 2026-09-08 19:09 CDT ceo: MODE EXECUTIVE -> QUARTET on Lon'"'"'s word; the four HQs work rows and the executives rule.'

echo "=== gate: next refuses a row of a language parked by THE ORDER OF WORK ==="

# --- (a)+(b): THE REGRESSION ITSELF, in the live spelling ------------------------------------------------
# The rank-0 row is SNOBOL4 and carries hq_P's OWN owner cell -- the owner-cell pass, which is exactly how
# the live picker served it. Nothing but the order of work can explain a refusal here: same seat, same lane,
# better rank, and an owner cell that names the seat by name.
set_mode 'NONET' "$LIVE_L2"
reset_q
mk 0 snobol4-rungs-red-fixture  hq_snobol4 FREE
mk 5 icon-jcon-std-recut-fixture hq_snobol4 FREE
out="$(run_next hq_snobol4)"
grep -qE '^LOCKED.*icon-jcon-std-recut-fixture' <<<"$out" && ! grep -qE '^LOCKED.*snobol4-rungs-red-fixture' <<<"$out" \
  && ck ok "(a) THE ORDER OF WORK IS ICON ONLY parks the rank-0 SNOBOL4 row; the rank-5 icon row is served instead" \
  || ck no "(a) a parked-language row must never be served automatically, owner cell or not -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"
grep -q 'snobol4-rungs-red-fixture' <<<"$out" && grep -qE 'SKIP|PARKED|ORDER OF WORK' <<<"$out" \
  && ck ok "(b) the skip is printed and names the parked topic -- a refusal a reader can act on, not silence" \
  || ck no "(b) a parked-language skip must be VISIBLE and NAMED, never silent -- got: $out"

# --- (c): THE MACHINE LINE ALONE, no ONLY clause in prose at all -----------------------------------------
# This is the deliverable the row asked for: the bus reads a declaration, not prose. The prose here names a
# different mode entirely and carries no freeze wording of any spelling.
set_mode 'NONET' "$OTHER_L2" 'ORDER-OF-WORK: icon'
reset_q
mk 0 snobol4-rungs-red-fixture  hq_snobol4 FREE
mk 5 icon-jcon-std-recut-fixture hq_snobol4 FREE
out="$(run_next hq_snobol4)"
grep -qE '^LOCKED.*icon-jcon-std-recut-fixture' <<<"$out" \
  && ck ok "(c) the ORDER-OF-WORK marker alone parks the SNOBOL4 row, with no ONLY clause in prose anywhere" \
  || ck no "(c) the machine line must be sufficient on its own -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"

# --- (d): THE MARKER OUTRANKS PROSE, IN THE OPENING DIRECTION --------------------------------------------
# ⭐ Tested in the direction that can only be explained by precedence: prose says ICON ONLY, the marker says
# snobol4, and the SNOBOL4 row is served. Had the marker merely been ANDed with prose, this row would stay
# parked and the arm would fail. Precedence proven, not assumed.
set_mode 'NONET' "$LIVE_L2" 'ORDER-OF-WORK: snobol4'
reset_q
mk 0 snobol4-rungs-red-fixture  hq_snobol4 FREE
mk 5 icon-jcon-std-recut-fixture hq_snobol4 FREE
out="$(run_next hq_snobol4)"
grep -qE '^LOCKED.*snobol4-rungs-red-fixture' <<<"$out" \
  && ck ok "(d) the marker line is AUTHORITATIVE over prose -- prose ICON ONLY, marker snobol4, SNOBOL4 served" \
  || ck no "(d) the machine line must outrank the prose it replaces -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"

# --- (e): THE ORDER OF WORK IS A SET ---------------------------------------------------------------------
# ⛔ Equality was wrong the moment the order of work named two languages -- and it stood at two on
# 2026-09-08 ("SNOBOL4 AND ICON TO 100%"). An equality test fails CLOSED here, parking a LIVE language.
set_mode 'NONET' "$OTHER_L2" 'ORDER-OF-WORK: icon snobol4'
reset_q
mk 0 snobol4-rungs-red-fixture  hq_snobol4 FREE
mk 5 icon-jcon-std-recut-fixture hq_snobol4 FREE
out="$(run_next hq_snobol4)"
grep -qE '^LOCKED.*snobol4-rungs-red-fixture' <<<"$out" \
  && ck ok "(e) two live languages: a SNOBOL4 row is served when the order of work names icon AND snobol4" \
  || ck no "(e) the order of work is a SET, not one language -- a live language must never be parked: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"

# --- (f): `all` RESTRICTS NOTHING ------------------------------------------------------------------------
set_mode 'NONET' "$LIVE_L2" 'ORDER-OF-WORK: all'
reset_q
mk 0 prolog-inria-red-fixture hq_snobol4 FREE
out="$(run_next hq_snobol4)"
grep -qE '^LOCKED.*prolog-inria-red-fixture' <<<"$out" \
  && ck ok "(f) ORDER-OF-WORK: all restricts nothing -- the explicit way to lift a freeze without deleting the line" \
  || ck no "(f) `all` must open every language -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"

# --- (g): POSITIVE CONTROL, THE ARM THAT PROVES THE CHECK CAN BE SILENT ----------------------------------
# ⛔ A checker that always refuses and one that never refuses BOTH pass every arm above except this one.
set_mode 'NONET' "$OTHER_L2"
reset_q
mk 0 snobol4-rungs-red-fixture hq_snobol4 FREE
out="$(run_next hq_snobol4)"
grep -qE '^LOCKED.*snobol4-rungs-red-fixture' <<<"$out" \
  && ck ok "(g) POSITIVE CONTROL: with no marker and no ONLY clause, the SNOBOL4 row IS served -- no misfire" \
  || ck no "(g) an inactive order of work must restrict nothing -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"

# --- (h): FOUND BY MARKER, NOT BY POSITION; FIRST WINS ---------------------------------------------------
# ⭐ The ceo PREPENDS each dated entry, so a positional read (line 3) would be shoved down by the very next
# announcement and start answering for a superseded order of work. Marker at depth 6 here, with a
# SUPERSEDED marker below it: the first must win, which under prepend-newest is the newest.
set_mode 'NONET' "$LIVE_L2" "$OTHER_L2" '# 2026-09-07 08:15 CDT ceo: CEO-382 announcement shape.' \
         '# 2026-09-06 15:41 CDT ceo: MODE OCTET.' 'ORDER-OF-WORK: icon' \
         '# older entries below' 'ORDER-OF-WORK: prolog'
reset_q
mk 0 prolog-inria-red-fixture    hq_snobol4 FREE
mk 5 icon-jcon-std-recut-fixture hq_snobol4 FREE
out="$(run_next hq_snobol4)"
grep -qE '^LOCKED.*icon-jcon-std-recut-fixture' <<<"$out" && ! grep -qE '^LOCKED.*prolog-inria-red-fixture' <<<"$out" \
  && ck ok "(h) the marker is matched by MARKER at any depth and the FIRST wins -- a superseded marker below it is ignored" \
  || ck no "(h) a positional read would break on the next prepended entry -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"

# --- (i): A LANGUAGE-NEUTRAL TOPIC IS NEVER PARKED -------------------------------------------------------
# Tooling/meta rows name no language and must survive every order of work -- otherwise the instrument that
# repairs the bus is itself unreachable the moment the bus is frozen.
set_mode 'NONET' "$LIVE_L2" 'ORDER-OF-WORK: icon'
reset_q
mk 0 postoffice-tooling-fixture hq_snobol4 FREE
out="$(run_next hq_snobol4)"
grep -qE '^LOCKED.*postoffice-tooling-fixture' <<<"$out" \
  && ck ok "(i) a topic naming no language is language-neutral and is served under any order of work" \
  || ck no "(i) a language-neutral topic must never be parked -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"

# --- (j): AN EXPLICIT ASSIGNMENT OUTRANKS THE ORDER OF WORK ----------------------------------------------
# ⭐ PINNED DELIBERATELY, so nobody later "tightens" the freeze into blocking the ceo's own dispatch. The
# order of work is the DEFAULT a picker applies when choosing for itself; a row an authority pointed at this
# seat BY NAME is a decision already taken -- the same precedent the rank cap states outright ("an explicit
# direction outranks the cap") and that `claim` has always been. This row itself reached hq_P that way: its
# topic begins `snobol4-` and the order of work was ICON ONLY.
set_mode 'NONET' "$LIVE_L2" 'ORDER-OF-WORK: icon'
reset_q
mk 0 snobol4-assigned-tooling-fixture hq_snobol4 ASSIGNED:hq_snobol4
# ⛔ THE ASSIGNMENT LIVES IN THE CLAIM FILE, NOT THE QUEUE COLUMN -- PASS 1 reads `claims/<topic>.claim`
# (first line the assignee, an `ASSIGNED-BY` line, neither DONE nor RUNNING), which is precisely what
# `dispatch` writes. A fixture that set only the ASSIGNED:<seat> column would prove nothing about PASS 1.
{ echo 'hq_snobol4'; echo "ASSIGNED-BY ceo $(date -u +%FT%TZ)"; } > "$W/claims/snobol4-assigned-tooling-fixture.claim"
out="$(run_next hq_snobol4)"
grep -qE 'snobol4-assigned-tooling-fixture' <<<"$out" && ! grep -qE 'QUEUE EMPTY' <<<"$out" \
  && ck ok "(j) a row ASSIGNED to this seat by name is still served -- an explicit direction outranks the default" \
  || ck no "(j) the order of work must not block a deliberate assignment -- got: $out"

# =========================================================================================================
# ⛔⭐⭐ ARMS (k)..(o) -- THE SLUG IS NOT THE ONLY PLACE A ROW'S LANGUAGE LIVES (hq_S 2026-09-10).
# MEASURED, and found by being SERVED one: under this same MODE (NONET, THE ORDER OF WORK IS ICON ONLY),
# `s4e_msg.sh next` LOCKED hq_S onto `input-open-failure-not-signaled` -- a row whose GOAL reads "INPUT() ...
# the oracle (sbl -bf) ... Witness: simple_output_62 in corpus/tests/snobol4/ALL.sno". The freeze check RAN
# and passed it: the slug carries no `snobol4-` prefix, the prefix table returned empty, and empty means
# LANGUAGE-NEUTRAL. The picker printed ⛔ SKIP for four prefixed SNOBOL4 rows and then handed out an
# unprefixed one, in the same run, four lines apart.
# ⭐ THIS IS CEO-489'S OWN DEFECT ON THE OTHER OPERAND, and that is why it belongs in THIS gate rather than a
# new one. CEO-489 cured an extractor that answered "does MODE contain `ON <LANG> ONLY`?" while being read as
# "what is the order of work?". This one is an extractor that answers "does this SLUG start with a language
# prefix?" while being read as "what language is this ROW?". Both fail OPEN -- they leak parked work rather
# than idle a seat -- so neither announces itself: a seat that is served a row does not audit why.
# ⛔ AND ARM (i) ABOVE IS WHY THE GATE COULD NOT CATCH IT: it pins that a language-neutral topic is never
# parked, using a fixture whose baton says "GOAL: fixture". Every slug-neutral row looked like arm (i) to
# this gate, the real ones included. The fixture and the code shared the assumption a second time -- the
# same "a guard and its own canary must not share a failure mode" this file's header already records.
# MEASURED on the live queue the day these arms landed: 452 servable rows, 165 slug-NEUTRAL; of those 165,
# 39 name exactly one language's witness paths or oracle in their baton (28 snobol4, 5 prolog, 6 icon).
# =========================================================================================================

# --- (k): THE REGRESSION ITSELF -- language in the BATON, not the slug ------------------------------------
# The slug is deliberately the live one, and deliberately says nothing: no `snobol4-` prefix, no language
# word at all. Only the baton knows, and it knows the way real batons do -- by naming the witness it grades
# and the oracle it grades against.
set_mode 'NONET' "$LIVE_L2" 'ORDER-OF-WORK: icon'
reset_q
mkb 0 input-open-failure-not-signaled hq_prolog FREE \
    'GOAL: INPUT() on a file it cannot open never signals failure. The oracle (sbl -bf) fails fast with ERROR 116.' \
    'Witness: simple_output_62 in corpus/tests/snobol4/ALL.sno' \
    'DONE-WHEN: true' '## NEXT' 'fixture'
mkb 5 icon-jcon-std-recut-fixture hq_prolog FREE 'GOAL: fixture' 'DONE-WHEN: true' '## NEXT' 'fixture'
out="$(run_next hq_prolog)"
grep -qE '^LOCKED.*icon-jcon-std-recut-fixture' <<<"$out" && ! grep -qE '^LOCKED.*input-open-failure-not-signaled' <<<"$out" \
  && ck ok "(k) a slug-neutral row whose BATON names SNOBOL4's witnesses is parked under ICON ONLY -- the row that was actually served" \
  || ck no "(k) the language may live only in the baton, and the freeze must still see it -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"

# --- (l): POSITIVE CONTROL FOR (k) -----------------------------------------------------------------------
# ⛔ Without this arm, a classifier that called EVERY slug-neutral row snobol4 would pass (k) and would
# quietly park the whole tooling half of the queue -- the exact harm arm (i) exists to prevent, arrived at
# from the opposite direction. Same slug shape, same rank, same seat; only the baton's content differs.
set_mode 'NONET' "$LIVE_L2" 'ORDER-OF-WORK: icon'
reset_q
mkb 0 postoffice-picker-tooling-fixture hq_prolog FREE \
    'GOAL: the picker prints its own denominator when it serves nothing.' 'DONE-WHEN: true' '## NEXT' 'fixture'
out="$(run_next hq_prolog)"
grep -qE '^LOCKED.*postoffice-picker-tooling-fixture' <<<"$out" \
  && ck ok "(l) POSITIVE CONTROL: a slug-neutral row whose baton names no language's witnesses is still served -- no misfire" \
  || ck no "(l) genuinely language-neutral tooling must survive every order of work -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"

# --- (m): THE DECLARED LINE, which is what everyone SHOULD write ------------------------------------------
# ⭐ Same doctrine CEO-489 landed one operand over: a language that is DECLARED cannot be mis-parsed out of
# prose. This baton names no corpus path and no oracle -- inference has nothing to work with -- and the row
# is parked anyway, on the strength of one written line.
set_mode 'NONET' "$LIVE_L2" 'ORDER-OF-WORK: icon'
reset_q
mkb 0 some-unprefixed-row-fixture hq_prolog FREE \
    'LANGUAGE: snobol4' 'GOAL: a row whose baton declares its language and names no witness path at all.' \
    'DONE-WHEN: true' '## NEXT' 'fixture'
mkb 5 icon-jcon-std-recut-fixture hq_prolog FREE 'GOAL: fixture' 'DONE-WHEN: true' '## NEXT' 'fixture'
out="$(run_next hq_prolog)"
grep -qE '^LOCKED.*icon-jcon-std-recut-fixture' <<<"$out" && ! grep -qE '^LOCKED.*some-unprefixed-row-fixture' <<<"$out" \
  && ck ok "(m) a DECLARED 'LANGUAGE:' line in the baton parks the row on its own, with no witness path anywhere" \
  || ck no "(m) declared must beat inferred, and must work where inference has nothing -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"

# --- (n): AN AMBIGUOUS ROW WITH A LIVE CANDIDATE IS STILL SERVED ------------------------------------------
# ⛔⭐ THIS ARM'S RATIONALE WAS REWRITTEN 2026-09-10 (hq_P) WITHOUT ITS FIXTURE OR ITS VERDICT CHANGING, WHICH
# IS THE ONLY REASON IT IS WORTH READING. It used to say "ambiguity stays neutral and is served -- the cure
# tightens, never loosens", and it still passes -- but NOT for that reason any more, and the old reason was
# load-bearing prose that turned out to be false. Its fixture names snobol4 AND icon, and `icon` is the live
# language here, so under the fail-closed rule below it is served BECAUSE A CANDIDATE IS LIVE. Ambiguity is no
# longer a free pass: see arm (p), where every candidate is parked and the row is refused. ⭐ Kept and
# re-explained rather than deleted, because a cross-language row (a shared-node cure, a runner grading two
# suites) must never be assigned to whichever language its grep happens to hit first -- that property is real
# and this arm still holds it. An arm that passes for a reason its comment does not name is the "correct
# procedure, false explanation" class this project keeps paying for.
set_mode 'NONET' "$LIVE_L2" 'ORDER-OF-WORK: icon'
reset_q
mkb 0 shared-node-emitter-fixture hq_prolog FREE \
    'GOAL: a shared-node cure graded on corpus/tests/snobol4/ALL.sno AND corpus/tests/icon/ALL.icn.' \
    'DONE-WHEN: true' '## NEXT' 'fixture'
out="$(run_next hq_prolog)"
grep -qE '^LOCKED.*shared-node-emitter-fixture' <<<"$out" \
  && ck ok "(n) an ambiguous baton with a LIVE candidate (icon) among its languages is still served" \
  || ck no "(n) ambiguity with a live candidate must serve, never guess one language -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"

# --- (o): THE SLUG STILL OUTRANKS THE BATON --------------------------------------------------------------
# ⭐ Tested in the direction only precedence explains: the slug says icon (LIVE), the baton greps as snobol4
# (PARKED), and the row is SERVED. Had the baton been consulted first, or ANDed in, this row would park and
# the arm would fail. The prefix table stays the authority when it answers -- an `icon-` row that diffs
# against sbl to explain a divergence is still an Icon row.
set_mode 'NONET' "$LIVE_L2" 'ORDER-OF-WORK: icon'
reset_q
mkb 0 icon-jcon-loadfunc-fixture hq_prolog FREE \
    'GOAL: an icon row that cites corpus/tests/snobol4/ALL.sno and sbl -bf only to contrast the two runtimes.' \
    'DONE-WHEN: true' '## NEXT' 'fixture'
out="$(run_next hq_prolog)"
grep -qE '^LOCKED.*icon-jcon-loadfunc-fixture' <<<"$out" \
  && ck ok "(o) the SLUG outranks the baton -- an icon- row whose baton greps SNOBOL4 is served under ICON ONLY" \
  || ck no "(o) the prefix table must stay the authority when it answers -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"

# ⛔⭐⭐ ARMS (p)..(s) -- AMBIGUITY WAS NOT A NEUTRAL OUTCOME, IT WAS AN ACTIVE BYPASS (hq_P 2026-09-10, found
# the way both earlier instances of this class were found: BY BEING SERVED ONE). Under MODE NONET with THE
# ORDER OF WORK IS ICON ONLY, `next` printed sixteen ⛔ SKIP lines for snobol4 rows and then LOCKED this seat
# onto `corpus-import-roast-subset` -- a RAKU row (import the roast spec suite into corpus/packages/raku/roast/).
# The witness matcher answered BOTH raku (right) AND snobol4 (WRONG): the baton names the convention it copies,
# "the packages/ import pattern beside gimpel/csnobol4_suite/ipl/jcon", and the `csnobol4_suite` marker convicts
# a row that cites that directory AS A NAMING PRECEDENT. Two candidates, so the classifier returned empty, so
# the freeze read LANGUAGE-NEUTRAL and served it.
# ⛔ THE SHAPE WORTH CARRYING: with ambiguity-returns-neutral, A FALSE POSITIVE IN ANY ONE LANGUAGE'S MATCHER
# DOES NOT MIS-LANE A ROW -- IT DISARMS THE FREEZE FOR THAT ROW ENTIRELY. So the failure surface is the UNION
# of seven regexes, not any one of them, and every one of them is a prose grep. Arm (n)'s old comment claimed
# the design "can only tighten, never loosen"; that is true only for rows the freeze already refused, and false
# in the direction that matters -- a row a CORRECT classifier would have PARKED gets SERVED.
# ✅ THE CURE IS ON THE DECISION, NOT THE MARKERS: chasing false positives out of seven marker sets is unbounded
# and each fix is one witness wide, so the freeze now asks the question that is decidable -- IS EVERY LANGUAGE
# THIS ROW COULD BE PARKED? -- and refuses only then. (p) is the bypass, (q) its positive control.
# --- (p): EVERY CANDIDATE PARKED => REFUSED ---------------------------------------------------------------
set_mode 'NONET' "$LIVE_L2" 'ORDER-OF-WORK: icon'
reset_q
mkb 0 roast-import-fixture hq_prolog FREE \
    'GOAL: import a curated subset into corpus/packages/raku/roast/ (the packages/ import pattern beside gimpel/csnobol4_suite/ipl/jcon).' \
    'DONE-WHEN: true' '## NEXT' 'fixture'
out="$(run_next hq_prolog)"
grep -qE '^LOCKED.*roast-import-fixture' <<<"$out" \
  && ck no "(p) THE BYPASS: every candidate (raku, snobol4) is parked under ICON ONLY and the row was still SERVED" \
  || ck ok "(p) a row whose every candidate language is parked is refused -- ambiguity is not a free pass"
# --- (q): POSITIVE CONTROL FOR (p) -- a live candidate still serves ----------------------------------------
# ⛔ Without this arm a classifier that refused EVERY ambiguous row would pass (p) and would quietly park every
# cross-language row in the queue -- 7 of the 453 servable rows the day this landed, all of them naming icon.
# That is the same harm arm (l) exists to prevent, arrived at from the other side.
set_mode 'NONET' "$LIVE_L2" 'ORDER-OF-WORK: raku'
reset_q
mkb 0 roast-import-fixture hq_prolog FREE \
    'GOAL: import a curated subset into corpus/packages/raku/roast/ (the packages/ import pattern beside gimpel/csnobol4_suite/ipl/jcon).' \
    'DONE-WHEN: true' '## NEXT' 'fixture'
out="$(run_next hq_prolog)"
grep -qE '^LOCKED.*roast-import-fixture' <<<"$out" \
  && ck ok "(q) POSITIVE CONTROL: the same ambiguous row IS served when one of its candidates is the live language" \
  || ck no "(q) refusing every ambiguous row would park the cross-language half of the queue -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"
# --- (r): NEUTRALITY IS DECLARABLE ------------------------------------------------------------------------
# ⛔ THE COST SIDE OF (p), AND IT IS REAL, NOT HYPOTHETICAL: the census over the live queue turned up
# `legacy-dash-flags-dead-scripts` -- a sweep of harness/scripts/*.sh for a dead single-dash CLI convention,
# language-neutral beyond argument -- classified `snobol4 snocone` because its GOAL spells out example
# invocations containing `file.sno` and `file.sc`. PLACEHOLDER filenames, read as witnesses. Teaching the
# matcher about `file.<ext>` is one witness wide and the next placeholder is `prog.sno`; declaring neutrality
# is permanent and readable. DECLARED beats INFERRED, extended to the answer inference cannot safely reach.
set_mode 'NONET' "$LIVE_L2" 'ORDER-OF-WORK: icon'
reset_q
mkb 0 dead-flag-sweep-fixture hq_prolog FREE \
    'LANGUAGE: neutral' \
    'GOAL: sweep the scripts for a dead CLI convention; examples read scrip -x86 file.sno and scrip -sc file.sc.' \
    'DONE-WHEN: true' '## NEXT' 'fixture'
out="$(run_next hq_prolog)"
grep -qE '^LOCKED.*dead-flag-sweep-fixture' <<<"$out" \
  && ck ok "(r) a baton DECLARING 'LANGUAGE: neutral' is served though inference would park it on placeholder filenames" \
  || ck no "(r) declared neutrality must outrank inference, or tooling rows park on prose -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"
# --- (s): A DECORATED MARKER IS STILL A MARKER ------------------------------------------------------------
# ⛔ FOUND BY (r) FAILING THE MOMENT THE HARNESS STOPPED BEING VACUOUS. The marker parser did not strip a
# trailing `#` comment, so `LANGUAGE: neutral   # why` folded the whole comment into the value and matched
# nothing: the declaration read as ABSENT and the row fell back to inference. A marker that looks authoritative
# in the file and is inert in the bus is worse than no marker -- it is believed by the reader and by nobody
# else. The same treatment `s4e_strip_donewhen_comment` already gives a DONE-WHEN, and this arm is why anyone
# writing one may explain it on the same line.
set_mode 'NONET' "$LIVE_L2" 'ORDER-OF-WORK: icon'
reset_q
mkb 0 decorated-marker-fixture hq_prolog FREE \
    'LANGUAGE: neutral   # a tooling row; the examples below are placeholders, not witnesses' \
    'GOAL: sweep the scripts; examples read scrip -x86 file.sno and scrip -sc file.sc.' \
    'DONE-WHEN: true' '## NEXT' 'fixture'
out="$(run_next hq_prolog)"
grep -qE '^LOCKED.*decorated-marker-fixture' <<<"$out" \
  && ck ok "(s) a 'LANGUAGE:' marker with a trailing # comment still parses -- a decorated marker is not an absent one" \
  || ck no "(s) an explained marker must not read as absent -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"

echo "---"
if [ "$fails" -eq 0 ]; then printf '✅ PASS: %d/%d arms — next refuses a parked language under THE ORDER OF WORK, hermetically\n' "$checks" "$checks"; exit 0
else printf '⛔ FAIL: %d of %d arms red\n' "$fails" "$checks"; exit 1; fi
