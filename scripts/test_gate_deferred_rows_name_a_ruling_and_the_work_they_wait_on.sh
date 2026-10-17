#!/usr/bin/env bash
# ../harness/scripts/test_gate_deferred_rows_name_a_ruling_and_the_work_they_wait_on.sh
# hq_T 2026-09-12, ceo CEO-593, on Lon's CEO-579 (*"Do not count the FD as failures for us."*).
#
# ⛔⭐ WHAT THIS GRADES AND WHY IT IS NOT A DOCUMENTATION CHECK. `DEFERRED` is the one verdict on this project
# that MOVES PROGRAMS OUT OF THE BUCKET THAT CAN BE RED without anybody fixing them. OUTSIDE-BASELINE at least
# rests on a fact about the oracle that a reader can re-measure; DEFERRED rests on a SCHEDULING DECISION, and
# a scheduling decision decays into an abandonment in total silence -- the score stays lifted, the ruling stays
# quotable, and the work it was waiting on stops being anybody's.
# ⭐ A WRONG EXCLUSION COSTS MORE THAN A WRONG CURE, because a red stays visible and an excluded name cannot be
# red (hq_V, standing practice since 2026-09-10). This gate is that sentence made executable for DEFERRED.
#
# THE THREE CONDITIONS ARE ARCH-PROGRAM-LEDGER.md § DEFERRED's, and they are graded here one arm each:
#   ARM 3/4  A RULING NAMES IT -- CEO number, ISO date, and LON'S OWN WORDS IN QUOTES. No seat defers anything
#            on its own judgement, so a row whose verbatim does not name Lon is not a deferral at all.
#   ARM 7/8  IT IS PRINTED, NEVER SUBTRACTED IN SILENCE -- `deferred=N` is the sixth PACKAGE_INVENTORY term,
#            the names print beside it, and the identity closes WITH it and REFUSES WITHOUT it.
#   ARM 5    IT CARRIES THE WORK IT IS WAITING ON -- a measured size, and not a tautology.
# Plus the two arms nothing in the ledger could ask for because they are about drift, not about the ruling:
#   ARM 6    THE POPULATION IS RE-MEASURED AGAINST THE DISK. A count nobody re-asks is exactly the defect of
#            FINDING-2026-09-09-hq_T (an exclusion list with no staleness arm can only ever lower a
#            denominator): the record says 30, the tree ships 24, and six programs are lifted by a stale row.
#   ARM 9    THE BOARD SAYS DEFERRED, in the word DEFERRED. `◻ no runner` and `⏸ deferred` look alike in the
#            suite table and are opposite facts -- one is unscheduled debt, the other is debt scheduled out on
#            Lon's word. If the banner cannot tell them apart, the record exists and the board still lies.
#
# ⛔ REFUSES rc=2 (never green) when: DEFERRED.tsv is absent (the record this gate grades is gone -- that is
# not "nothing is deferred", it is "the instrument has no subject"), SUITES.tsv is absent, or bash/python is
# missing. ⭐ An EMPTY record (header only) is GREEN and says so: zero deferred populations is a legitimate
# state of the world and the only one that needs no ruling.
#
# Usage: bash ../harness/scripts/test_gate_deferred_rows_name_a_ruling_and_the_work_they_wait_on.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
cd "$ROOT" || exit 2
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
GATE_NAME="$(basename "$0")"
DEF="${S4E_DEFERRED_TSV:-$S4E/.github/DEFERRED.tsv}"
SUITES="$(. "$ROOT/../harness/scripts/lib_suites_tsv.sh"; suites_tsv "$S4E")"
BANNER="$S4E/.github/scripts/util_suite_banner.py"
[ -f "$DEF" ]    || { echo "⛔ GATE REFUSES(2) [$GATE_NAME]: no DEFERRED.tsv at $DEF -- the record this gate grades does not exist. That is not 'nothing is deferred': ARCH-PROGRAM-LEDGER § DEFERRED names gnu_fd's 30 FD programs, so an absent record means the ruling is live and unrecorded, which no green can describe."; exit 2; }
[ -f "$SUITES" ] || { echo "⛔ GATE REFUSES(2) [$GATE_NAME]: no SUITES.tsv at $SUITES -- ARM 2 cannot tie a deferral to the board it lifts"; exit 2; }
[ -f "$BANNER" ] || { echo "⛔ GATE REFUSES(2) [$GATE_NAME]: no util_suite_banner.py at $BANNER -- ARM 9 cannot read what the board prints"; exit 2; }
command -v python3 >/dev/null || { echo "⛔ GATE REFUSES(2) [$GATE_NAME]: no python3"; exit 2; }
bad=0; n=0
fail() { echo "   ⛔ ARM $1: $2"; bad=$((bad + 1)); }
ok()   { n=$((n + 1)); }

# ---------------------------------------------------------------------------------------------------------
# ARM 1 FORMAT -- one header naming the columns, and every data row exactly as wide as it.
HDR="$(awk -F'\t' '!/^#/ && NF { print; exit }' "$DEF")"
NF_HDR=$(printf '%s' "$HDR" | awk -F'\t' '{print NF}')
[ "$(printf '%s' "$HDR" | cut -f1)" = "suite" ] || fail 1 "the first non-comment row must be the header and must start with 'suite'; got: $(printf '%s' "$HDR" | cut -c1-80)"
ok
ROWS=$(awk -F'\t' -v h="$NF_HDR" 'BEGIN{seen=0} !/^#/ && NF { if (!seen) { seen=1; next } print }' "$DEF" | grep -c . || true)
awk -F'\t' -v h="$NF_HDR" 'BEGIN{seen=0} !/^#/ && NF { if (!seen) { seen=1; next } if (NF != h) printf "%d:%d\n", NR, NF }' "$DEF" | while IFS= read -r m; do
    echo "   ⛔ ARM 1: line ${m%%:*} has ${m#*:} field(s), header has $NF_HDR -- a short row silently shifts every column after the gap, and the column that moves is the one carrying the ruling"
done
awk -F'\t' -v h="$NF_HDR" 'BEGIN{seen=0} !/^#/ && NF { if (!seen) { seen=1; next } if (NF != h) bad=1 } END{exit bad?1:0}' "$DEF" || bad=$((bad + 1))
ok
if [ "$ROWS" -eq 0 ]; then
    echo "✅ GATE PASS [$GATE_NAME]: the record is present and holds ZERO deferred populations -- nothing is scheduled out, which is the one state of this file that needs no ruling. $n format arm(s) graded."
    exit 0
fi

# ---------------------------------------------------------------------------------------------------------
# ARMS 2-6, one pass over the rows. Field numbers are resolved FROM THE HEADER, never typed, so a column
# inserted later cannot make this gate grade the wrong text while staying green.
col() { printf '%s' "$HDR" | tr '\t' '\n' | grep -nxF "$1" | cut -d: -f1; }
C_SUITE=$(col suite); C_PKG=$(col package); C_POP=$(col population); C_CNT=$(col count)
C_BY=$(col ruled_by); C_ON=$(col ruled_on); C_VERB=$(col ruling_verbatim); C_WAIT=$(col waiting_on)
for c in C_SUITE C_PKG C_POP C_CNT C_BY C_ON C_VERB C_WAIT; do
    [ -n "$(eval echo \$$c)" ] || { echo "⛔ GATE REFUSES(2) [$GATE_NAME]: the header does not name the column $c expects -- the record's shape moved and this gate would grade the wrong field"; exit 2; }
done
# ⛔ the words that mean "we have not decided", which is what a deferral must never be allowed to mean
TAUTOLOGY='^(later|tbd|todo|n/?a|none|deferred|not built|unbuilt|someday|eventually|when we get to it|unknown|-)$'
awk -F'\t' -v seen=0 '!/^#/ && NF { if (!seen) { seen=1; next } print NR "\t" $0 }' "$DEF" > /tmp/.def_rows.$$ || true
while IFS= read -r row; do
    ln="${row%%$'\t'*}"; rest="${row#*$'\t'}"
    f() { printf '%s' "$rest" | cut -f"$1"; }
    suite="$(f "$C_SUITE")"; pkg="$(f "$C_PKG")"; pop="$(f "$C_POP")"; cnt="$(f "$C_CNT")"
    by="$(f "$C_BY")"; on="$(f "$C_ON")"; verb="$(f "$C_VERB")"; wait="$(f "$C_WAIT")"

    # ARM 2 -- the suite is on the board. A deferral naming a suite the table does not display lifts a
    # number nobody can see, which is the only way this record could be both honest and invisible.
    if ! awk -F'\t' -v k="$suite" '!/^#/ && $1 == k {found=1} END{exit found?0:1}' "$SUITES"; then
        fail 2 "line $ln defers suite '$suite', which is not a key in SUITES.tsv -- a deferral must lift a number the board actually prints"
    fi
    ok
    # ARM 3 -- a CEO ruling number, and a real date.
    printf '%s' "$by" | grep -qE '^CEO-[0-9]+(,CEO-[0-9]+)*$' || fail 3 "line $ln ruled_by='$by' is not one or more CEO-<n> numbers -- a deferral with no ruling to look up is a seat's own judgement wearing a citation"
    printf '%s' "$on" | grep -qE '^20[0-9][0-9]-[01][0-9]-[0-3][0-9]$' || fail 3 "line $ln ruled_on='$on' is not an ISO date -- an undated ruling cannot be aged, and ageing is how a deferral is caught turning into an abandonment"
    ok
    # ARM 4 -- LON'S OWN WORDS, quoted, and long enough to be words. ⛔ The name check is the load-bearing
    # half: no seat, HQ or officer defers anything, ever, so a verbatim attributed to anyone else is not a
    # weaker row -- it is a different kind of row, and it must not be accepted at all.
    printf '%s' "$verb" | grep -q 'Lon' || fail 4 "line $ln ruling_verbatim does not name Lon -- only Lon defers a population; see ARCH-PROGRAM-LEDGER § DEFERRED condition 1"
    printf '%s' "$verb" | grep -qE '"[^"]{10,}"' || fail 4 "line $ln ruling_verbatim carries no quoted utterance of 10+ characters -- the ruling is quoted VERBATIM or it is a paraphrase, and a paraphrase is the seat's words again"
    ok
    # ARM 5 -- the work it waits on, with a measured size.
    lw="$(printf '%s' "$wait" | tr 'A-Z' 'a-z' | sed 's/^ *//; s/ *$//')"
    printf '%s' "$lw" | grep -qE "$TAUTOLOGY" && fail 5 "line $ln waiting_on='$wait' says nothing a reader can act on -- condition 3 asks for the subsystem, the prerequisite and the MEASURED size"
    printf '%s' "$wait" | grep -q '[0-9]' || fail 5 "line $ln waiting_on names no number -- 'a big subsystem' and '11452 lines of C/H' age differently, and only the second can ever be observed to have shrunk"
    [ "$wait" != "$verb" ] || fail 5 "line $ln waiting_on repeats ruling_verbatim -- the ruling says it may wait; this column says what for, and they cannot be the same sentence"
    ok
    # ARM 6 -- RE-MEASURE THE POPULATION. The count is graded against the disk on every run.
    got=0
    for hit in $(eval echo "$S4E/$pop" 2>/dev/null); do [ -f "$hit" ] && got=$((got + 1)); done
    if [ "$got" -eq 0 ]; then
        fail 6 "line $ln population '$pop' matches NO file under $S4E -- the programs moved or were deleted, and a deferral over nothing keeps lifting a score for a population that no longer exists"
    elif [ "$got" -ne "$cnt" ]; then
        fail 6 "line $ln says count=$cnt but '$pop' matches $got file(s) -- the record and the tree disagree, so the number lifting this board was last true at some tree nobody named"
    fi
    ok
done < /tmp/.def_rows.$$
rm -f /tmp/.def_rows.$$

# ---------------------------------------------------------------------------------------------------------
# ARM 7/8 THE IDENTITY, BOTH WAYS, HERMETIC. A scratch package of five programs, one of them deferred by a
# scratch record: with the row the six buckets sum and `deferred=1` prints; with the record redirected away
# the SAME tree REFUSES rc=2. ⛔ And per RULES.md § THE INSTRUMENT LAWS (23rd batch, CEO-594) the negative
# half asserts WHAT THE REFUSAL SAYS, not merely that something failed -- an rc=2 for a missing library would
# satisfy a bare exit-code check and prove nothing about the arithmetic.
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/pkg"
for x in a b c d e; do echo ':- true.' > "$W/pkg/$x.pl"; done
printf '# scratch\nsuite\tpackage\tlang\tpopulation\tcount\truled_by\truled_on\truling_verbatim\twaiting_on\tmeasured_by\ttree\n' > "$W/DEF.tsv"
printf 'scr\tscratchpkg\tprolog\tpkg/c.pl\t1\tCEO-579\t2026-09-11\tLon: "scratch fixture words"\ta scratch subsystem, 1 file\thq_T\tnone\n' >> "$W/DEF.tsv"
inv_run() {
    S4E_HOME="$W" S4E_DEFERRED_TSV="$1" bash -c '
        . "'"$ROOT"'/scripts/lib_inventory.sh"
        INV_PACKAGE=scratchpkg; INV_DIR="'"$W"'/pkg"; INV_EXT=".pl"
        inventory_line 4 0 || exit $?
        inventory_deferred_line || exit $?' 2>&1
}
got="$(inv_run "$W/DEF.tsv")"; rc=$?
case "$got" in
    *"deferred=1 graded_stream=4"*) ;;
    *) fail 7 "with a deferred row the inventory did not print deferred=1 in the sixth position (rc=$rc): $(printf '%s' "$got" | head -2 | tr '\n' '|')" ;;
esac
[ "$rc" -eq 0 ] || fail 7 "the identity did not close with the deferred row counted (rc=$rc)"
printf '%s\n' "$got" | grep -q '^PACKAGE_INVENTORY_DEFERRED package=scratchpkg deferred=1 names=c.pl ruled_by=CEO-579$' \
    || fail 7 "the names did not print beside the count -- condition 2 is PRINTED, NEVER SUBTRACTED IN SILENCE, and a count with no names is where a wrong exclusion hides. Got: $(printf '%s' "$got" | grep DEFERRED | head -1)"
ok
got2="$(inv_run "$W/absent.tsv")"; rc2=$?
[ "$rc2" -eq 2 ] || fail 8 "with the deferred row removed the same tree returned rc=$rc2, not the refusal -- then the sixth bucket is decoration and a deferred program could sit in no bucket at all"
printf '%s\n' "$got2" | grep -q 'buckets do not sum' || fail 8 "the refusal without the deferred row does not say the buckets fail to sum: an rc=2 alone is satisfied by a missing library, a bad path or a typo, so the arm would pass for reasons that have nothing to do with the identity it grades. Got: $(printf '%s' "$got2" | head -1)"
printf '%s\n' "$got2" | grep -q 'deferred(0)' || fail 8 "the refusal does not name deferred(0) among the buckets it summed -- a reader meeting it cannot tell which of the six is missing"
ok

# ---------------------------------------------------------------------------------------------------------
# ARM 9 THE BOARD SAYS DEFERRED. Every deferred suite must render in the word, on both faces of the banner.
md="$(python3 "$BANNER" --md 2>&1)" || { echo "⛔ GATE REFUSES(2) [$GATE_NAME]: util_suite_banner.py --md failed; ARM 9 cannot read the board"; exit 2; }
plain="$(python3 "$BANNER" --plain 2>&1 || python3 "$BANNER" 2>&1)"
for k in $(awk -F'\t' -v seen=0 '!/^#/ && NF { if (!seen) { seen=1; next } print $1 }' "$DEF" | sort -u); do
    nick="$(awk -F'\t' -v k="$k" '!/^#/ && $1 == k {print $2; exit}' "$SUITES")"
    [ -n "$nick" ] || continue   # ARM 2 already reported this row; do not report it twice
    printf '%s\n' "$md" | grep -q "^| $nick |" || { fail 9 "suite '$k' ($nick) is deferred but does not appear in the markdown suite table at all"; continue; }
    # ⛔ THE MARKER, NOT THE WORD. Grading on the word DEFERRED alone passes VACUOUSLY here and I measured it
    # doing so: gnu_fd's own `criterion_changed` cell in SUITES.tsv contains the string
    # "DEFERRED-by-lon-ceo-572", which the no-runner branch prints as its reason -- so a banner with the
    # deferred rendering ripped out entirely still satisfied a `grep DEFERRED` on that row. ⭐ The check must
    # be on a token only the cure can emit (`⏸`) plus the ruling's own number, which is the general form of
    # every vacuous assertion in this project: an arm passing on text that was already there before the cure.
    row_md="$(printf '%s\n' "$md" | grep "^| $nick |" | head -1)"
    printf '%s' "$row_md" | grep -q 'DEFERRED by Lon (' || fail 9 "the markdown row for '$k' carries no 'DEFERRED by Lon (' marker (the phrase only the deferred branch emits; plain text since Lon 2026-09-12) -- it reads as ordinary unscheduled debt, and the ruling that lifted it is invisible where it matters"
    printf '%s' "$row_md" | grep -q 'DEFERRED' || fail 9 "the markdown row for '$k' does not say DEFERRED in words beside the marker"
    printf '%s' "$row_md" | grep -qF "$(awk -F'\t' -v k="$k" -v c="$C_BY" '!/^#/ && $1 == k {print $c; exit}' "$DEF")" || fail 9 "the markdown row for '$k' does not carry its ruling number -- a reader meeting a lifted population on the board must be one grep from the ruling that lifted it"
    printf '%s\n' "$plain" | tr -d '\033' | grep -q "$nick" && { printf '%s\n' "$plain" | tr -d '\033' | grep -o "$nick[^│]*" | grep -qi 'deferr' || fail 9 "the banner cell for '$nick' does not say deferred"; }
done
ok

# ---------------------------------------------------------------------------------------------------------
if [ "$bad" -eq 0 ]; then
    echo "✅ GATE PASS [$GATE_NAME]: $ROWS deferred population(s), $n arm group(s) graded -- every row names Lon's ruling verbatim with its CEO number and date, names the work it waits on with a measured size, re-measures its population against the disk, sums as the sixth PACKAGE_INVENTORY bucket (and refuses without it), and reads DEFERRED on the board."
    exit 0
fi
echo "⛔ GATE FAIL [$GATE_NAME]: $bad violation(s) over $ROWS deferred population row(s). ⛔ A DEFERRED row that fails any of the three conditions is a FAIL, not a weaker deferral (ARCH-PROGRAM-LEDGER § DEFERRED) -- fix the row or withdraw the deferral; never relax this gate."
exit 1
