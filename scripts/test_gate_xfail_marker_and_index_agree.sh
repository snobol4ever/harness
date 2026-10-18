#!/usr/bin/env bash
# test_gate_xfail_marker_and_index_agree.sh -- THE XFAIL MARKER AND THE INDEX MUST NAME THE SAME ENTRIES.
# (hq_T 2026-09-05, row test-suite-consistency-seven-languages-one-standard; the half of
# FINDING-2026-09-05-hq_T-every-xfail-promotion-leaves-the-master-unsorted-and-the-csv-stale that had no guard.)
#
# ⛔ WHAT BREAKS IT IS A PROMOTION, AND IT BROKE FIVE TIMES IN ONE DAY. An XFAIL lives in THREE places: the
# banner in the rungs itself, the `xfail` column of ALL.csv, and the reason line in ALL.xfail. A promotion
# rewrites the rungs and the reasons file and LEAVES THE INDEX AT 1. Measured at corpus 5df255b01:
# ALL.sno carried 46 banners while ALL.csv still called 49 entries xfail -- and nothing was inconsistent in a
# way any gate could see, because every gate compared a file with ITSELF. The suite and its index agreed on
# every other column; the marker gates were green; the order gate caught the ORDER half and said nothing
# about this one.
# ⭐ THE RULE THIS ASSERTS: when one fact is stored in three representations, the guard belongs on the
# AGREEMENT, never on any single one of them. Neither file is wrong on its own terms -- they are wrong
# relative to each other, which is a property no single-file check can hold.
#
# ⛔⛔ COMMENT SYNTAX IS PER-LANGUAGE AND A SNOBOL4-SHAPED MATCHER SILENTLY READS ZERO. Measured while
# writing this gate, and it is the reason the regex below leads with \W* instead of a literal '*':
# snobol4 banners are `*--- N name XFAIL`, raku's are `#--- ...`, snocone's are `/*--- ... */`. A `^\*-`
# pattern reports raku as 0 banners against 156 index rows -- a 156-entry catastrophe that does not exist,
# and it would have been filed as one. A census instrument written in one language's punctuation answers
# "how many does MY dialect have", never "how many are there".
#
# Usage: bash ../harness/scripts/test_gate_xfail_marker_and_index_agree.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
TESTS="$S4E/corpus/tests"
gate_require "$TESTS" "the per-language rungs suites"

violations=0
examined=0

# The census both arms share, so the gate and its own witness cannot drift apart.
census() {
python3 - "$1" <<'EOF'
import csv, os, re, sys
RX = re.compile(r'^\W*-{3,}\s+(\d+)\s+(\S+)\s+XFAIL\b')
EXT = {"snobol4":"sno","icon":"icn","prolog":"pl","raku":"raku","pascal":"pas","snocone":"sc","rebus":"reb"}
tests = sys.argv[1]
def names(p):
    if not os.path.isfile(p):
        return None
    out = set()
    with open(p, encoding="utf-8", errors="replace") as fh:
        for l in fh:
            m = RX.match(l)
            if m:
                out.add(m.group(2))
    return out
graded = bad = reasons_missing = 0
for lang in sorted(EXT):
    d = os.path.join(tests, lang)
    rungs, index = os.path.join(d, "ALL." + EXT[lang]), os.path.join(d, "ALL.csv")
    if not (os.path.isfile(rungs) and os.path.isfile(index)):
        continue
    ban = names(rungs)
    # ⛔⭐ THE FOURTH REPRESENTATION, ADDED 2026-09-14 (hq_T, CEO-740's xpass promotion). This gate shipped
    # naming THREE places an XFAIL lives -- the banner, the index, the reason file -- and its own remediation
    # text already said to strip the marker "in the rungs AND its ref". It advised about a representation it
    # never graded. The promotion of raku's 17 both-mode XPASSes proved the gap the expensive way: rungs and
    # index were cured and agreed, this gate went PASS(0), and util_build_rungs_suite.py --resort then REFUSED
    # on `ALL.ref banner mismatch at seq 796` because the ref still carried all 67. The harness caught what the
    # guard did not. ⭐ THE RULE, one turn past the one in this header: when a guard on AGREEMENT is written,
    # its population is every representation that must agree -- and the honest census of that population is
    # whatever REFUSES when one is wrong, not the list the gate's author had in mind.
    refb = names(os.path.join(d, "ALL.ref"))
    with open(index, encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    if not rows:
        continue
    graded += 1
    idx = {r["entry"] for r in rows if r.get("xfail") == "1"}
    only_rungs, only_index = sorted(ban - idx), sorted(idx - ban)
    only_ban_ref = sorted(ban - refb) if refb is not None else []
    only_ref_ban = sorted(refb - ban) if refb is not None else []
    rea = names(os.path.join(d, "ALL.xfail"))
    missing = sorted(idx - rea) if rea is not None else []
    reasons_missing += len(missing)
    print("  %-9s rungs=%-4d index=%-4d ref=%-6s reasons=%-6s %s" % (
        lang, len(ban), len(idx), "-" if refb is None else len(refb),
        "-" if rea is None else len(rea),
        "agree" if not (only_rungs or only_index or only_ban_ref or only_ref_ban) else "⛔ DISAGREE"))
    if only_ban_ref or only_ref_ban:
        bad += 1
        for n in only_ban_ref[:5]:
            print("      banner in the rungs, NO banner in ALL.ref: %s  <-- the half-promotion shape" % n)
            print("          -> the rungs and its ref are ONE suite in two files and the harness reads them in lockstep:")
            print("             util_build_rungs_suite.py --resort REFUSES on this with 'ALL.ref banner mismatch'. Strip or")
            print("             restore ' XFAIL' in BOTH, never one, then re-run the builder.")
        for n in only_ref_ban[:5]:
            print("      banner in ALL.ref, NO banner in the rungs: %s  <-- the half-promotion shape, reversed" % n)
            print("          -> same cure, same reason: the two files must carry the identical banner line.")
    if only_rungs or only_index:
        bad += 1
        # ⛔⭐ EACH SHAPE CARRIES ITS OWN DIRECTION, BECAUSE A DISAGREEMENT HAS TWO RESOLUTIONS AND ONLY ONE OF
        # THEM IS RIGHT PER ENTRY (hq_S 2026-09-13, measured on four Rebus entries this census had just red).
        # Naming a single cure for a two-sided disagreement is not a wording problem: hq_S's four were banner
        # XFAIL / index 0 with the entries PASSING in both modes, so obeying the one cure this gate used to
        # print would have stamped xfail=1 on four passing entries -- MANUFACTURING an xfail, which is the one
        # thing THERE IS NO XFAIL abolishes -- and it would have been reported as a fix.
        for n in only_rungs[:5]:
            print("      banner in the rungs, xfail=0 in the index: %s" % n)
            print("          -> if %s PASSES both modes the BANNER is the stale half: promote it (strip the XFAIL from the banner in the rungs AND its ref, and delete its ALL.xfail reason block in the same commit)" % n)
            print("          -> if it FAILS, the INDEX is the stale half: re-run the builder (--reindex)")
        for n in only_index[:5]:
            print("      xfail=1 in the index, NO banner in the rungs: %s  <-- the promotion shape" % n)
            print("          -> a promotion rewrote the rungs and left the index at 1: re-run the builder (--reindex) so the index follows the suite")
            print("          -> but if %s FAILS today, the promotion itself was wrong and the banner is what is missing" % n)
    if missing:
        print("      %d xfail(s) with no reason recorded in ALL.xfail: %s" % (len(missing), ", ".join(missing[:4])))
if not graded:
    sys.stderr.write("REFUSED: graded ZERO rung suites under %s\n" % tests)
    raise SystemExit(2)
print("GRADED=%d BAD=%d REASONS_MISSING=%d" % (graded, bad, reasons_missing))
EOF
}

# ⛔⭐ THE REMEDIATION IS A FUNCTION, NOT FOUR ECHOES INSIDE THE FAIL BRANCH, FOR ONE REASON: the fail branch
# does not run while the tree is green, so text living only there is text no arm can grade, and the cure hq_S
# reported was a WRONG REMEDIATION printed by a CORRECT detection -- exactly the half that had no arm. ARM 4
# calls this and requires both resolutions and the fact that selects between them, so a future edit that
# collapses it back to one cure reds HERE instead of six months later in somebody else's promotion.
print_remediation() {
echo "GATE FAIL: a rung suite's XFAIL banners and its ALL.csv xfail column name different entries."
echo "           ⛔ THIS GATE DOES NOT KNOW WHICH HALF IS STALE, AND IT WILL NOT PRETEND TO: it is a pure source"
echo "              census and runs no programs, so it can see the disagreement and not its direction. THE FACT"
echo "              THAT SELECTS THE CURE IS WHETHER THE ENTRY PASSES IN BOTH MODES TODAY -- measure that first."
echo "           1. THE ENTRY PASSES  -> the BANNER is stale. PROMOTE it: strip ' XFAIL' from the banner in the"
echo "              rungs AND in its ref, and delete its ALL.xfail reason block, all in the same commit."
echo "           2. THE ENTRY FAILS   -> the INDEX is stale (a promotion rewrote the rungs and left the column"
echo "              at 1). Re-run the builder (--reindex) so the index follows the suite."
echo "           ⛔ DO NOT --reindex A PASSING ENTRY: that stamps xfail=1 on a program that works, which"
echo "              MANUFACTURES the xfail THERE IS NO XFAIL abolished, and it reads as a fix in the receipt."
echo "              Measured 2026-09-13 (hq_S): four Rebus entries were exactly that shape, and the single cure"
echo "              this gate used to print pointed at all four of them."
}

# ARM 1 — THE AGREEMENT ITSELF, pinned at zero. It is pinned rather than ratcheted because it is SATISFIED
# TODAY (corpus e2f9c2f2c re-sorted snobol4 back into agreement, 46 == 46), and a bar you can meet is a bar.
examined=$((examined + 1))
out="$(census "$TESTS" 2>&1)"; crc=$?
printf '%s\n' "$out"
if [ "$crc" -eq 2 ] || ! printf '%s' "$out" | grep -q '^GRADED='; then
    echo "⛔ GATE REFUSES: the marker/index census could not measure (rc=$crc)"
    exit 2
fi
if [ "$(printf '%s' "$out" | sed -n 's/^GRADED=[0-9]* BAD=\([0-9]*\).*/\1/p')" != "0" ]; then
    print_remediation
    violations=$((violations + 1))
fi

# ARM 2 — EVERY XFAIL SHOULD CARRY A REASON, and this one IS ratcheted: snobol4 has 5 xfails with no entry in
# ALL.xfail today, and pinning at zero would red make test over debt this arm was written to expose rather
# than to punish. ⭐ It is a real gap and not bookkeeping: ALL.xfail is where a reader learns whether an xfail
# is a deliberate dialect choice or an open defect, and an xfail with no reason is indistinguishable from one
# nobody has looked at. Lower this when the reasons are written.
REASONS_WATERMARK=5
examined=$((examined + 1))
rm_count="$(printf '%s' "$out" | sed -n 's/^GRADED=[0-9]* BAD=[0-9]* REASONS_MISSING=\([0-9]*\)/\1/p')"
if [ "${rm_count:-0}" -gt "$REASONS_WATERMARK" ]; then
    echo "GATE FAIL: $rm_count xfail(s) carry no recorded reason, above the watermark of $REASONS_WATERMARK"
    violations=$((violations + 1))
fi

# ARM 3 — ⛔ THE WITNESS IS THE REAL DEFECT AS IT LANDED, NOT A HAND-BUILT IMITATION. Graded on a scratch tree
# built from corpus 5df255b01 -- the promotion commit itself, where ALL.sno carried 46 banners against 49
# index rows. If this gate cannot red on the exact tree that motivated it, it does not guard anything.
# Skipped (not failed) where that revision is unreachable, so a shallow or re-cloned corpus cannot turn a
# missing fixture into a false green -- it says which.
examined=$((examined + 1))
W="$(mktemp -d "${TMPDIR:-/tmp}/xfail_agree.XXXXXX")"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/snobol4"
if git -C "$S4E/corpus" cat-file -e 5df255b01:tests/snobol4/ALL.csv 2>/dev/null; then
    git -C "$S4E/corpus" show 5df255b01:tests/snobol4/ALL.sno > "$W/snobol4/ALL.sno" 2>/dev/null
    git -C "$S4E/corpus" show 5df255b01:tests/snobol4/ALL.csv > "$W/snobol4/ALL.csv" 2>/dev/null
    wout="$(census "$W" 2>&1)"
    if printf '%s' "$wout" | grep -q 'GRADED=1 BAD=1'; then
        :
    else
        echo "GATE FAIL: the census did NOT red on corpus 5df255b01, the tree this gate exists for"
        printf '%s\n' "$wout" | sed 's/^/    /'
        violations=$((violations + 1))
    fi
else
    echo "GATE NOTE: corpus 5df255b01 unreachable here -- ARM 3's historical witness was NOT graded"
fi

# ARM 4 — ⛔ THE REMEDIATION IS GRADED, BOTH DIRECTIONS, ON A FIXTURE CARRYING BOTH SHAPES AT ONCE (hq_B
# 2026-09-13, on hq_S's measurement; row instruments-a-two-sided-disagreement-gate-names-one-cure-so-half-its-
# reds-point-at-manufacturing-an-xfail). ⭐ WHY THIS ARM AND NOT A CAREFUL READING: ARMS 1-3 all grade
# DETECTION, and detection was never the defect -- this gate correctly red on hq_S's four Rebus entries. It
# then named ONE cure, --reindex, which for their shape (banner XFAIL, index 0, entries PASSING) would have
# stamped xfail=1 on four working programs and been written up as a fix. A gate that names a single cure for a
# two-sided disagreement is obeyed into the wrong state by whoever trusts it most, and no amount of correct
# detection protects against that. ⛔ IT IS ALSO FALSIFIABLE IN BOTH DIRECTIONS, which the old text was not:
# delete either resolution, or the sentence naming the fact that selects between them, and this arm reds.
examined=$((examined + 1))
W4="$(mktemp -d "${TMPDIR:-/tmp}/xfail_two_sided.XXXXXX")"
trap 'rm -rf "$W" "$W4"' EXIT
mkdir -p "$W4/rebus"
# Both shapes in ONE fixture, because the gate has to say something useful about each without being told which
# it is looking at: stale_banner carries a banner and xfail=0, stale_index carries xfail=1 and no banner.
{ echo "*--- 1 stale_banner XFAIL"; echo "*--- 2 agreeing_entry"; } > "$W4/rebus/ALL.reb"
{ echo "entry,xfail"; echo "stale_banner,0"; echo "agreeing_entry,0"; echo "stale_index,1"; } > "$W4/rebus/ALL.csv"
f4="$(census "$W4" 2>&1)"
r4="$(print_remediation 2>&1)"
a4=0
printf '%s' "$f4" | grep -q 'GRADED=1 BAD=1' || { echo "    ARM 4: the both-shapes fixture did not red at all"; a4=1; }
printf '%s' "$f4" | grep -q 'banner in the rungs, xfail=0 in the index: stale_banner' || { echo "    ARM 4: the stale-BANNER shape was not named"; a4=1; }
printf '%s' "$f4" | grep -q 'xfail=1 in the index, NO banner in the rungs: stale_index' || { echo "    ARM 4: the stale-INDEX shape was not named"; a4=1; }
printf '%s' "$f4" | grep -q 'if stale_banner PASSES both modes the BANNER is the stale half' || { echo "    ARM 4: the stale-banner line does not say what makes the BANNER the stale half"; a4=1; }
printf '%s' "$f4" | grep -q 'stale_index FAILS today, the promotion itself was wrong' || { echo "    ARM 4: the promotion-shape line does not name its own opposite direction"; a4=1; }
printf '%s' "$r4" | grep -qi 'PASSES IN BOTH MODES' || { echo "    ARM 4: the remediation does not name the FACT that selects the cure"; a4=1; }
printf '%s' "$r4" | grep -qi 'PROMOTE it' || { echo "    ARM 4: the remediation does not offer PROMOTION as a resolution"; a4=1; }
printf '%s' "$r4" | grep -q -- '--reindex' || { echo "    ARM 4: the remediation does not offer --reindex as a resolution"; a4=1; }
printf '%s' "$r4" | grep -qi 'MANUFACTURES the xfail' || { echo "    ARM 4: the remediation does not warn that the wrong cure MANUFACTURES an xfail on a passing entry"; a4=1; }
if [ "$a4" = 0 ]; then
    echo "ARM 4 OK: the census names both shapes with their own direction, and the remediation offers BOTH resolutions and the fact that selects between them"
else
    echo "GATE FAIL: the remediation is one-sided again -- a reader who trusts it will --reindex a passing entry"
    violations=$((violations + 1))
fi

GATE_EXAMINED="$examined arms"
# ⛔ THE VERDICT NOUN COVERS BOTH SUBJECTS, because ARM 4 raises the same counter: a red printed as "1 rung_suites
# whose marker and index disagree" while the actual finding was a one-sided remediation would send the reader
# to the corpus to look for a disagreement that is not there -- a true count under a false name.
gate_verdict "$violations" "marker/index disagreements or one-sided remediations"
