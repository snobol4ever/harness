#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icon_gc_share_named_and_rungs_clean_under_forced_collection.sh
#
# THE DONE-WHEN of row icon-gc-the-icon-share-of-the-unmapped-slot-population-censused-by-name-and-the-master-
# clean-at-one-megabyte (hq_icon, 2026-09-20), this lane's FIRST row under MODE TENET: MODE line 2 / CEO-1011 --
# "COMPLETENESS DOES NOT OPEN IN A LANGUAGE UNTIL THAT LANGUAGE'S GC SHARE IS MEASURED CLEAN BY ORACLE DIFF AT
# THE TINY ARENA", the census NAMING and never counting, the rungs graded by ORACLE and never by rc.
#
# ⛔⭐⭐ ARM 1 EXISTS BECAUSE IT REVERSED THIS LANE'S OWN GREEN, AND THAT IS THE MEASUREMENT WORTH READING FIRST.
# hq_icon reported the icon rungs at SCRIP_HEAP_MB=1 reading m3 824/826 m4 825/826 and treated it as this
# language's tiny-arena GC reading. Measured 2026-09-20 over the SAME 826 entries at that SAME arena with NO
# stress plant: COLLECTORS=11, NON-COLLECTORS=815, regenerations=97. EIGHT HUNDRED AND FIFTEEN OF 826 ENTRIES
# NEVER COLLECT AT ALL, so for 815 of them that board was a statement about whether icon programs allocate a
# megabyte and not about the collector. ⛔ SCRIP_GC_STRESS UNSET IS STRESS 0, WHICH IS NO FORCED COLLECTION
# (hq_snobol4) -- a blank plant must never print as a blank, so every line here names the plant as a value.
# The arm is hq_snocone's, who measured the extreme version in their lane (SncRungs 336/336 at 1 MB with
# regenerations=0, not one entry allocating enough to collect) and said to copy it freely. A board over a
# population that CANNOT fail the way you are asking about is not evidence, and no rc, no denominator and no
# FAIL=0 anywhere in it says so -- so this gate REFUSES rc=2 rather than ever reporting green in that case.
#
# ARM 2 is the unmapped-store census over the same population, plus the frame-map census. ⛔ READ BY ITS PRINTED
# VERDICT LINE AND NOT BY ITS rc: util_gc_unmapped_store_census.py exits 1 whenever it names ANY member, and most
# of what it names is BELOW-REGION, which its own header says is where spine words live BY CONSTRUCTION and was
# never the discriminator (CFO-114/CFO-136, named to this lane by hq_snocone). This lane owes class 2, NO-MAP --
# the per-language class the cto assigned to the HQs in writing -- so NO-MAP is what this arm binds on.
# ⛔⭐ AND no_layout IS SPLIT PER CEO-1025, on hq_prolog's fork: (a) THE COMPILER REFUSED THE ENTRY -- nothing
# emitted, no leaf boundary, no store, a completeness debt wearing a GC census's clothes, declared with its rung
# and NOT gating completeness; (b) THE COMPILER EMITTED THE GRAPH AND THE PLANNER GAVE IT NO LAYOUT -- boundaries
# exist and store into unmapped slots, and THAT gates completeness. Icon's no_layout is 0, so BOTH buckets are
# empty for this language and the split is vacuous here -- which is a measurement to re-take, not a fact to keep.
#
# ⛔⭐ ARM 3 GRADES A BAND AND SPANS BOTH ENDS OF IT, NEVER A POINT, AND NEVER MOVES UP INSTEAD. CEO-1024: the
# raku rungs at stress 16 lost 65 gradings over 36 distinct programs that a 1-3-5 band called green. But
# hq_raku's own follow-up is the half people will skip -- their map family is wrong at stress 1 THROUGH 6 and
# INVISIBLE at 8 and above, while their grammar family is wrong at every point above 0, so a lane that moves its
# band from 1-3-5 up to 16 and reports clean has TRADED one blind spot for another. hq_snobol4 has a witness red
# at 25 and green at 10, 12, 16, 20, 35 and 50: the divergence points are NOT MONOTONE in the plant and NOT an
# interval. So the default band spans both ends (ICN_GC_BAND="1 3 5 8 16"), ARM 1's decidability question is
# asked AT EVERY POINT because a HIGH plant collects LESS OFTEN and can be inert for exactly the reason the tiny
# arena was, and whatever this gate reports is A LOWER BOUND ON THE POPULATION and is labelled as one.
#
# ⛔⭐ AND THE NAME SET IS CONTINGENT ON THE PATHS THAT PRODUCED IT (hq_raku, measured): they can flip one program
# between the right answer and a silently wrong one by RENAMING ITS FILE -- the same inode as p/xxxxxxxx.raku
# prints (A B) and as ./p/xxxxxxxx.raku prints (), because the argv string is allocated and the stress plant
# counts ALLOCATIONS, so the pathname decides which allocation the forced collection lands on. This gate
# therefore PRINTS THE PATH ROOT its names were produced under, and a name set from a different root is not
# comparable to this one. That is also why ARM 3 grades through the harness over the rungs in place rather than
# over ARM 1's extracted copies: two populations at two path lengths are two different measurements.
#
# COST ~3 min per band point plus a one-off extraction. LANE gate, run by hq_icon per landing; deliberately NOT
# in `make test` -- the blocking set is the shared resource that does not scale with seats (MODE line 2
# CONDITION 2) and wiring a multi-minute arm into it is the coo's call.
#
# Commit identity: LCherryholmes / lcherryh@yahoo.com  (RULES.md)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP_DIR="$S4E/SCRIP"
SCRIP="${SCRIP:-$SCRIP_DIR/scrip}"
M="$S4E/corpus/tests/icon"
BAND="${ICN_GC_BAND:-1 3 5 8 16}"
ARENA="${ICN_GC_ARENA:-1}"
fail() { echo "⛔ RED: $*" >&2; exit 1; }
refuse() { echo "REFUSES rc=2: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "scrip not built at $SCRIP -- cannot measure"
for f in ALL.icn ALL.ref ALL.csv; do [ -f "$M/$f" ] || refuse "rungs file $M/$f missing -- cannot measure"; done
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cd "$SCRIP_DIR" || refuse "cannot cd to $SCRIP_DIR"
# --- materialize the graded population OUT of the rungs, by ORIGIN, never by a filename glob ---
mkdir -p "$W/e"
rows=0; got=0
while IFS= read -r org; do
    [ -n "$org" ] || continue
    rows=$((rows + 1))
    python3 "$HERE/corpus_suite_harness.py" extract "$M/ALL.icn" "$M/ALL.ref" --origin "$org" \
        "$W/e/$rows.icn" --out-ref "$W/e/$rows.ref" --out-in "$W/e/$rows.in" >/dev/null 2>&1 \
        && { got=$((got + 1)); printf '%s\t%s\n' "$rows" "$org" >> "$W/map.tsv"; }
done < <(awk -F, 'NR>1{print $3}' "$M/ALL.csv")
[ "$rows" -gt 0 ] || refuse "ALL.csv carries no entry rows -- a census over an empty population reads zero by never looking"
[ "$got" -eq "$rows" ] || refuse "materialized $got of $rows entries out of the rungs -- a population that did not come out whole is not the population the board grades"
# ⛔ DECLARED READER BLIND SPOT, inside the printed denominator and never subtracted from it (CEO-749): the
# extractor has no --out-argv, so the 6 argv-bearing entries of ALL.argv run WITHOUT their arguments in ARM 1.
# That can only make an entry do LESS work, so it can only UNDERCOUNT collectors -- it biases ARM 1 toward its
# own refusal and never toward a green. ARM 3 grades through the harness, which reads the argv sidecar itself.
# ⛔ SECOND DECLARED BLIND SPOT, and this one does NOT bias toward refusal, so it is the one to read: ARM 1 asks
# the decidability question in MODE 3 ONLY (the default --run), while ARM 3 grades m3 AND m4. Mode 4 links
# out/libscrip_rt.so and reaches the collector through its own emitted preamble, so an entry that is inert in m3
# is not thereby proven inert in m4 and vice versa. ARM 1 therefore licenses the m3 half of each band point's
# board and merely FAILS TO REFUSE the m4 half. Widening it to both modes doubles the arm's cost and is owed;
# until it lands, this gate's green is a statement about m3 decidability and m3+m4 grading, stated here rather
# than left for the next seat to discover in the way hq_icon discovered the 815.
nargv=$(grep -v '^#' "$M/ALL.argv" 2>/dev/null | awk -F'\t' 'NF>1' | wc -l)
echo "ARM 0 population=$got/$rows materialized whole; argv-bearing entries run WITHOUT argv in ARM 1: $nargv (declared, inside the denominator, biases ARM 1 toward refusal only)"
echo "ARM 0 DECLARED: ARM 1 measures decidability in m3 and not yet in m4; ARM 3 grades m3+m4. The m4 half of every band point is UNLICENSED by ARM 1 -- owed, and not a refusal"
# --- ARM 2: static reads, independent of the plant ---
python3 "$HERE/util_gc_unmapped_store_census.py" "$W/e"/*.icn > "$W/census.txt" 2>&1
crc=$?
[ "$crc" -eq 2 ] && { sed -n '/REFUSED/p' "$W/census.txt" >&2; refuse "the unmapped-store census could not measure this population"; }
line="$(grep -m1 '^CENSUS unmapped-store witnesses=' "$W/census.txt")" || refuse "the census printed no verdict line -- nothing to read"
echo "ARM 2 $line"
grep -c '^CENSUS unmapped-store MEMBER' "$W/census.txt" | sed 's/^/ARM 2 members NAMED in full by the census: /'
nomap="$(printf '%s\n' "$line" | grep -o 'NO-MAP=[0-9]*' | cut -d= -f2)"
[ -n "$nomap" ] || refuse "the census verdict line carries no NO-MAP field -- the criterion cannot be read off it"
# ⛔ AND THE UNDECIDABLE BUCKET IS PRINTED BESIDE IT, BECAUSE FOR ICON IT IS THE LARGER NUMBER AND A ZERO MEMBER
# COUNT HERE IS NOT A READING (the cto, measured: of 1753 icon call sites their fixpoint decides 43, and 0 of
# icon's 10 shielded stores -- ~97% of icon is UNMEASURED by it, structurally, because the wired regime enters
# those boxes through an INDIRECT jump so no path from the frame's own prologue reaches them in the emitted CFG).
und="$(printf '%s\n' "$line" | grep -o 'undecidable=[0-9]*' | cut -d= -f2)"
echo "ARM 2 undecidable=${und:-unread} -- ⛔ for icon this is the load-bearing number, NOT members: a members=0 over an undecidable remainder is a floor, never a clean reading"
zls="$(timeout -k 5 900 python3 "$HERE/util_zls_frame_map_census.py" --lang icon 2>/dev/null | grep -m1 '^ZLS-MAP lang=icon')" \
    || refuse "the frame-map census could not measure icon -- no_layout cannot be split when it cannot be read"
echo "ARM 2 $zls"
# ⛔ measured 2026-09-21: the census now also prints no_layout_emitted_no_layout=N (CEO-1025's split), whose
# tail is itself the literal substring "no_layout=N" -- an unanchored grep -o took BOTH hits, handing this
# variable a two-line value and making the -eq test below die with "integer expression expected". Anchor on
# a preceding space or start-of-line so only the standalone field matches.
nl="$(printf '%s\n' "$zls" | grep -oE '(^| )no_layout=[0-9]+' | tr -d ' ' | cut -d= -f2)"
[ -n "$nl" ] || refuse "the frame-map census verdict carries no no_layout field"
if [ "$nl" -eq 0 ]; then
    echo "ARM 2 CEO-1025 SPLIT: no_layout=0, so (a) never-emitted and (b) emitted-without-a-layout are BOTH EMPTY for icon -- the split is vacuous in this language"
else
    echo "ARM 2 CEO-1025 SPLIT OWED: no_layout=$nl must be split into (a) compiler REFUSED the entry (rc=2, nothing emitted, no boundary, no store -- a completeness debt, declared with its rung, does NOT gate completeness) and (b) EMITTED with no layout (boundaries store into unmapped slots -- gates completeness). Derive it from the rc the census prints, never by hand."
    fail "no_layout=$nl for icon and this gate cannot tell bucket (a) from bucket (b) -- CEO-1025 requires the split before any of it is treated as a GC row"
fi
[ "$nomap" -eq 0 ] || fail "NO-MAP=$nomap -- this lane owns class 2 (a graph the compiler refuses a frame layout for has no map at all), and $nomap site(s) are in it: $(grep -m5 'MEMBER NO-MAP' "$W/census.txt")"
# --- ARM 1 + ARM 3 OVER THE BAND ---
bad=0
for STRESS in $BAND; do
    coll=0; regens=0; to=0
    for f in "$W/e"/*.icn; do
        b="${f%.icn}"; in="$b.in"; [ -s "$in" ] || in=/dev/null
        out=$(SCRIP_ZETA_TELEM=1 SCRIP_HEAP_MB="$ARENA" SCRIP_GC_STRESS="$STRESS" timeout -k 5 20 "$SCRIP" "$f" < "$in" 2>&1 >/dev/null)
        [ $? = 124 ] && to=$((to + 1))
        n=$(printf '%s\n' "$out" | grep -c '^\[ZGC\] regeneration')
        [ "$n" -gt 0 ] && { coll=$((coll + 1)); regens=$((regens + n)); }
    done
    echo "ARM 1 DECIDABILITY arena_mb=$ARENA stress=$STRESS entries=$rows collectors=$coll non_collectors=$((rows - coll)) regenerations=$regens timeouts=$to"
    [ "$coll" -gt 0 ] || refuse "ZERO of $rows entries collected at arena_mb=$ARENA stress=$STRESS -- the board for this band point would be a statement about the icon corpus and not about the collector, so it is not reported at all"
    out="$(SCRIP_HEAP_MB="$ARENA" SCRIP_GC_STRESS="$STRESS" timeout -k 5 3000 python3 "$HERE/corpus_suite_harness.py" run "$M/ALL.icn" "$M/ALL.ref" --lang icon --modes m3,m4 2>&1)"
    board="$(printf '%s\n' "$out" | grep -m1 '^SUITE_BOARD')" || { printf '%s\n' "$out" | tail -5 >&2; refuse "the rungs run at stress=$STRESS printed no SUITE_BOARD line -- a run with no board is not a measurement"; }
    echo "ARM 3 stress=$STRESS $board"
    tot=$(printf '%s\n' "$board" | grep -o 'total=[0-9]*' | cut -d= -f2)
    [ "${tot:-0}" -gt 0 ] || refuse "the board's own denominator at stress=$STRESS is $tot -- a FAIL=0 over nothing is not a reading"
    pbad=0
    for k in m3_fail m3_crash m3_hang m3_unproven m4_fail m4_crash m4_hang m4_unproven; do
        v=$(printf '%s\n' "$board" | grep -o "$k=[0-9]*" | cut -d= -f2)
        [ "${v:-0}" -eq 0 ] || { echo "  stress=$STRESS $k=$v"; pbad=$((pbad + v)); }
    done
    # ⛔ THE NAME SET, NEVER THE COUNT (CEO-1024): a same-count comparison between two band points hides a
    # divergence that MOVED, which is the one comparison this class is built to walk through.
    names="$(printf '%s\n' "$out" | grep -E '^ +(FAIL|CRASH|HANG|UNPROVEN) ' | awk '{print $2"/"$3}' | sort -u | tr '\n' ' ')"
    echo "ARM 3 stress=$STRESS NAME-SET: ${names:-<none>}"
    bad=$((bad + pbad))
done
echo "PATH ROOT of every name above: $M (harness temp roots vary per run) -- ⛔ a name set produced under a different path root is NOT comparable to this one (hq_raku: renaming a file flips a program between right and silently wrong, because the stress plant counts ALLOCATIONS and argv is allocated)"
[ "$bad" -eq 0 ] || fail "$bad non-pass verdict(s) across the band \"$BAND\" at arena_mb=$ARENA over the printed denominator -- read the per-point NAME-SET lines above, never the totals"
echo "✅ icon GC share named (NO-MAP=$nomap, no_layout=$nl) and the rungs is clean across the band \"$BAND\" at arena_mb=$ARENA -- ⛔ A LOWER BOUND ON THE POPULATION, not a clean bill: the band is 5 points of a non-monotone space and ARM 2's undecidable remainder is unmeasured"
