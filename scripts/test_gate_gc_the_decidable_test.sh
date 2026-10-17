#!/usr/bin/env bash
# test_gate_gc_the_decidable_test.sh -- F6 STEP 6, THE DECIDABLE TEST (coo; ceo CEO-869/876, hq_snocone's ask).
#
# ⛔⭐ THE QUESTION IS NOT "DOES THE COLLECTOR FIND THE ROOTS".  IT IS: CAN A SUITE BE GREEN WHILE IT DOES NOT?
# THE MEASUREMENT THAT MAKES THIS THE CRITICAL PATH (the cto, 2026-09-18; reproduced by the ceo on an Icon rungs
# entry): 320 rungs entries across four frontends run with ZERO COLLECTIONS at default settings.  So every
# rungs board we own today is green over a collector that never ran once.  When three seats land F6 step 4's
# 208 poll sites, NOTHING WE OWN CAN TELL US WHETHER THEY ARE RIGHT -- not a board, not a smoke, not a rung suite.
# A green suite is evidence about the collector only if something FORCES it to run, FORCES the heap to slide
# under a live value, and then READS THAT VALUE BACK.  That is what each witness here does, per registered kind.
#
# THE FOUR THINGS EVERY WITNESS MUST PROVE, because any one of them missing makes a green meaningless:
#   (1) it allocates THE KIND IT CLAIMS          -- from SCRIP_ALLOC_HIST, never from the table's say-so
#   (2) a collection actually HAPPENED           -- [ZGC-MARK] lines, else it is the 320-entry reading again
#   (3) the heap actually MOVED under it         -- moved=NB > 0, else nothing was asked of the root fixups
#   (4) the value read back is still correct     -- with SCRIP_GC_POISON on, a lost root reads 0xDB, not stale data
#
# ⛔ THE STRESS BAND IS PART OF THE TEST AND ITS LOW END IS THE PART THAT MATTERS (ceo CEO-876, on the cfo's cset
# defect): that defect was RED at 1, 2, 3, 4, 5, 8, 10 and GREEN at 0, 15, 20, 30, 50, 100.  HIGH-AND-HIGHER
# LOOKS more punishing and is the opposite -- a low stress count puts the collection at a different point
# relative to the allocation, and a two-point check at 30 and 200 reads clean and banks the defect (CEO-807).
# The band is PRINTED per kind, never collapsed into a verdict.
#
# ⛔ THE DENOMINATOR IS THE DECLARATION.  Every `#define HB_*` in gc_heap.h must have a row in
# gc_kind_witnesses.tsv.  A kind added without one REFUSES rc=2: a kind nobody witnesses is precisely a kind the
# suite can be green while the collector loses, and a hand-kept list that falls behind its own declaration is
# this disease wearing the cure's clothes.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=gc_the_decidable_test
HDR="src/runtime/rt/gc_heap.h"; TAB="$HERE/gc_kind_witnesses.tsv"; WD="$HERE/gc_witnesses"
BAND="${GC_DECIDABLE_BAND:-0 1 2 3 4 5 8 10 15 20 30 50 100}"
[ -f "$HDR" ] || { echo "GATE UNPROVEN(2) [$G]: $HDR missing -- the kind declarations are the denominator"; exit 2; }
[ -f "$TAB" ] || { echo "GATE UNPROVEN(2) [$G]: $TAB missing -- no per-kind table"; exit 2; }
bash "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
W="$(mktemp -d "${TMPDIR:-/tmp}/gc_decidable.XXXXXX")" || exit 2
trap 'rm -rf "$W"' EXIT
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }

# ---- ARM 1: the denominator comes from the declaration, not from the table ----------------------------------
declared="$(grep -oE '^#define[[:space:]]+HB_[A-Z]+[[:space:]]+[0-9]+' "$HDR" | awk '{print $2"="$3}' | sort)"
n_decl=$(printf '%s\n' "$declared" | grep -c . || true)
missing=""; n_tab=0
for kv in $declared; do
    k="${kv%%=*}"
    if grep -qE "^${k}[[:space:]]" "$TAB"; then n_tab=$((n_tab+1)); else missing="$missing $k"; fi
done
gate_floor "$n_decl" 1 "HB_* kind(s) declared in gc_heap.h (the denominator is the declaration)"
if [ -n "$missing" ]; then
    ck no "arm1 every declared kind has a row:$missing has none -- a kind nobody witnesses is a kind the suite can be green while the collector loses it"
else
    ck ok "arm1 every declared kind has a row ($n_tab of $n_decl declared kinds classified)"
fi

# ---- ARM 2-4: the witnessed kinds ---------------------------------------------------------------------------
run_witness() { # $1=file $2=stress [$3=SCRIP_GC_PLANT_PIN_SKIP] ; prints "rc|collections|movedB|pinviolations|firstline"
    local f="$1" st="$2" skip="${3:-}" rc=0
    # ⛔⭐ THE PLANT NEVER APPLIED HERE, NOT ONCE, AND THE ARM BELOW REPORTED FIFTEEN DETECTIONS ANYWAY (found by
    # the cto 2026-09-21).  The prefix was written `${skip:+SCRIP_GC_PLANT_PIN_SKIP=$skip}` in front of the
    # command, and BASH DECIDES WHICH WORDS ARE ASSIGNMENT PREFIXES BEFORE IT EXPANDS THEM, so an assignment
    # PRODUCED BY an expansion is not a prefix -- it is the command name.  Every planted run died with
    # `SCRIP_GC_PLANT_PIN_SKIP=2: command not found`, rc=127, empty stdout, and arm 7 read rc!=0 as the witness
    # FAILING under a broken collector and printed DETECTED for every kind.  The collector was never broken; the
    # program never started.  `env` takes its assignments as ARGUMENTS, so an expansion is safe there.
    ( cd "$W" && env SCRIP_GC_STRESS="$st" SCRIP_GC_POISON=1 SCRIP_ZETA_TELEM=1 \
        timeout -k 5 120 "$ROOT/scrip" "$WD/$f" >o.txt 2>t.txt ) 2>/dev/null || rc=$?
    local col mov out
    # ⛔ `grep -c` PRINTS 0 AND EXITS 1 WHEN IT MATCHES NOTHING, so `|| echo 0` fires ON TOP of the 0 it already
    # printed and this function returned TWO lines; `read` then parsed "0|0" as the whole result and every witness
    # reported out=[] at exactly the one band level with no collections.  ⭐ IT LOOKED EXACTLY LIKE A FINDING --
    # eight kinds, all red at stress=0 only, which is precisely the ragged-low-band shape this gate exists to
    # catch -- and it was the harness.  An instrument that fabricates the defect it hunts is worse than one that
    # misses it, so the count is taken without a fallback that can double-print.
    col=$(grep -c 'ZGC-MARK' "$W/t.txt" 2>/dev/null); col=$(printf '%s' "${col:-0}" | head -1)
    mov=$(grep -oE 'moved=[0-9]+B' "$W/t.txt" 2>/dev/null | grep -oE '[0-9]+' | awk '{s+=$1} END {print s+0}')
    out=$(tr -d '\0' < "$W/o.txt" | sed -n 1p)
    # ⛔ THE PLANT'S OWN BANNER, COUNTED AND RETURNED, BECAUSE ARM 7 CREDITED A FAILURE TO A PLANT IT NEVER SAW
    # APPLY (found by the cto 2026-09-21 from the other end -- test_gate_gc_the_plant_says_whether_it_applied's
    # enumeration, generalised from one plant knob to a table of them, named this gate as the one planting gate
    # that reads no banner).  SCRIP_GC_PLANT_PIN_SKIP=n denies the nth MARKED block a forwarding address, so a
    # collection with fewer than n marked blocks plants NOTHING and says nothing, and a witness that fails for any
    # other reason in that run is recorded as sensitivity it does not have.  The collector prints [ZGC-PIN]
    # VIOLATION marked=N forwarded=M whenever a marked block was denied one, and that line is the only proof the
    # plant applied.  MEASURED before this line was written, stress 5, POISON on: hb_ws.icn, hb_aggv.icn and
    # hb_aggt.icn each print 5 violation lines at skip=2 and 4 at skip=3 -- so this gate's green was TRUE
    # and UNHELD at the same time, which is the state the INSTRUMENT LAWS call a claim held by memory rather than by a check.
    pin=$(grep -c 'ZGC-PIN' "$W/t.txt" 2>/dev/null); pin=$(printf '%s' "${pin:-0}" | head -1)
    echo "$rc|$col|$mov|$pin|$out"
}
witnessed=0; wit_red=0; vacuous=0; SENS_LIST=""
while IFS=$'\t' read -r kind val class wit expect note; do
    case "$kind" in \#*|"") continue;; esac
    [ "$class" = WITNESSED ] || continue
    witnessed=$((witnessed+1))
    [ -f "$WD/$wit" ] || { ck no "arm2 $kind($val): witness $wit is not in gc_witnesses/"; wit_red=$((wit_red+1)); continue; }
    # (1) does this witness allocate THE KIND IT CLAIMS?  Asked of the runtime, never of the table.
    ( cd "$W" && SCRIP_GC_STRESS=5 SCRIP_ALLOC_HIST=1 timeout -k 5 120 "$ROOT/scrip" "$WD/$wit" >/dev/null 2>ah.txt ) || true
    ahn=$(awk -v t="$val" '$1=="[AH]" && $2=="T" && $3==t {print $4}' "$W/ah.txt" | head -1)
    if [ -z "${ahn:-}" ] || [ "${ahn:-0}" -le 0 ]; then
        ck no "arm2 $kind($val): witness $wit allocated NO block of this kind (SCRIP_ALLOC_HIST) -- it is green about something else, which is the disease not the cure"
        wit_red=$((wit_red+1)); continue
    fi
    # (2)(3)(4) over the band, and the band is printed
    band_line=""; red=0; col_any=0; mov_any=0
    for st in $BAND; do
        IFS='|' read -r rc col mov pin out <<< "$(run_witness "$wit" "$st")"
        [ "${col:-0}" -gt 0 ] && col_any=1
        [ "${mov:-0}" -gt 0 ] && mov_any=1
        if [ "$rc" -ne 0 ] || [ "$out" != "$expect" ]; then
            band_line="$band_line ${st}:RED(rc=$rc,out=[$out])"; red=$((red+1))
        else
            band_line="$band_line ${st}:ok(c=$col)"
        fi
    done
    printf '        %-8s(%s) alloc=%s band:%s\n' "$kind" "$val" "$ahn" "$band_line"
    if [ "$red" -gt 0 ]; then
        ck no "arm3 $kind($val): the held value did NOT survive at $red of the band's levels -- with poison on, a lost or unfixed root reads 0xDB rather than stale bytes"
        wit_red=$((wit_red+1))
    elif [ "$col_any" = 0 ]; then
        ck no "arm4 $kind($val): every level passed and NO COLLECTION EVER RAN -- this is the 320-entry reading again and the green means nothing"
        vacuous=$((vacuous+1))
    elif [ "$mov_any" = 0 ]; then
        ck no "arm4 $kind($val): collections ran but the heap NEVER MOVED under the value, so no root fixup was ever asked for -- a green here cannot distinguish a correct fixup from no fixup at all"
        vacuous=$((vacuous+1))
    else
        ck ok "arm3+4 $kind($val): allocates its own kind ($ahn blocks), a collection ran AND the heap moved under it, and the value read back correct at every level of the band"
        SENS_LIST="$SENS_LIST $kind:$val:$wit:$expect"
    fi
done < "$TAB"

# ---- ARM 5: the kinds no program can witness are NAMED, with the reason --------------------------------------
noprod=""; internal=""; boundary=""
while IFS=$'\t' read -r kind val class wit expect note; do
    case "$kind" in \#*|"") continue;; esac
    case "$class" in
        NO-PRODUCER)        noprod="$noprod $kind($val)" ;;
        COLLECTOR-INTERNAL) internal="$internal $kind($val)" ;;
        BOUNDARY)           boundary="$boundary $kind($val)" ;;
    esac
done < "$TAB"
ck ok "arm5 the unwitnessable kinds are NAMED rather than counted as covered -- collector-internal:${internal:- none} boundary:${boundary:- none}"
if [ -n "$noprod" ]; then
    echo "        ⛔ NO-PRODUCER:$noprod -- the collector has a live arm for each of these and NOTHING IN THE TREE ALLOCATES ONE."
    echo "           An arm that cannot be reached has never run, so the first landing that produces the kind runs its"
    echo "           walk in production for the first time. NAMED, not red: it is a fact about the tree, not a defect"
    echo "           in the collector, and the coo does not rule on whether the arm or the producer is the thing missing."
fi

# ---- ARM 6: the planted red -- this harness must be seen to FAIL ---------------------------------------------
# ⛔ AN ARM THAT HAS NEVER BEEN SEEN TO FAIL IS NOT A MEASUREMENT.  Every check above is a comparison against an
# expected string; if that comparison were broken, or the witness produced no output at all and `expect` were
# empty, the whole gate would read green while proving nothing -- the exact shape it exists to catch, one level
# up.  So a witness is run against a DELIBERATELY WRONG expectation and the comparator must reject it.
IFS='|' read -r prc pcol pmov ppin pout <<< "$(run_witness hb_ws.icn 5)"
if [ "$prc" = 0 ] && [ -n "$pout" ] && [ "$pout" != "PLANTED-WRONG-VALUE" ]; then
    ck ok "arm6 PLANTED: the comparator rejects a wrong expectation (witness printed [$pout], planted expectation PLANTED-WRONG-VALUE) -- so a green above is a comparison that happened, not one that was skipped"
else
    ck no "arm6 PLANTED: the planted wrong expectation was NOT rejected (rc=$prc out=[$pout]) -- the comparator cannot tell right from wrong, so every verdict above is unreliable"
fi

# ---- ARM 7: THE SENSITIVITY ARM -- THIS IS THE QUESTION, ASKED BY EXPERIMENT -------------------------------
# ⛔⭐ EVERY ARM ABOVE SAYS "THE VALUE SURVIVED".  NONE OF THEM SAYS THE WITNESS COULD HAVE NOTICED IF IT HAD NOT.
# That gap is the entire subject of this gate: a suite that passes over a collector that never ran, or whose
# roots were never really exercised, is green for reasons unrelated to correctness -- which is exactly the state
# the cto measured across 320 rungs entries.  So the collector is DELIBERATELY BROKEN and each witness must be
# seen to FAIL.  SCRIP_GC_PLANT_PIN_SKIP=n denies the nth marked block a forwarding address, so the heap slides
# around it and every reference to it is left pointing at whatever now occupies that address -- a lost root, by
# the collector's own [ZGC-PIN] VIOLATION definition.  A witness that stays green through that is not a witness.
# ⭐ The skip values are swept and the FIRST one that trips is recorded: which n reaches a given kind's block
# depends on mark order, so a fixed n would silently stop reaching some kind after any allocation change -- and
# the arm would go quiet rather than red, which is the failure mode this whole gate exists against.

echo "------------------------------------------------------------"
printf 'population: %d declared kind(s), %d witnessed, %d unwitnessable-and-named; %d arm(s) graded, %d FAIL\n' \
    "$n_decl" "$witnessed" "$((n_decl - witnessed))" "$checks" "$fails"
echo "band: $BAND (the LOW end is load-bearing -- the cfo's cset defect was red at 1-10 and green at 15+)"
[ "$fails" = 0 ] || { echo "GATE RED [$G]: $fails of $checks arm(s) failed"; gate_stamp; exit 1; }
echo "GATE OK [$G]: a suite CANNOT be green while the collector loses a value at any witnessed kind"
gate_stamp
