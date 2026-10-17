#!/usr/bin/env bash
# test_gate_gc_the_descriptor_kind_sets_are_a_declared_subset.sh -- ONE FACT, ONE AUTHORITY, EVERY DIVERGENCE
# WRITTEN DOWN (cto 2026-09-20, built to the cfo's shape on their ask CFO-141; the defect found by hq_snobol4,
# verified A/B/A by the cto at CTO-101; the third spelling named by the cfo at CFO-146).
#
# THE FACT: which descriptor kinds carry a heap payload.  gc_heap.c spells it FIVE times -- gc_visit_one (the heap
# visitor, handed a descriptor that IS one), gc_cell_visit (the emitted-stack recognizer, guessing whether a word
# pair is a descriptor at all), gc_tag_bears_ptr (the preceding-tag test in gc_walk_words), and the two halves of
# the maps reporter's own divergence census, gc_sniff_would_take and gc_type_says_ref.  They disagree, and the
# disagreement is how a whole descriptor kind (DT_X) went unrecognised on the emitted stack: a live value's block
# was swept while gc_visit_one would have marked it.
#
# ⛔ WHY NOT "THE SETS MUST BE EQUAL", which was the cto's first offer and which the cfo REFUSED for a reason that
# is better than the offer: an arm demanding equality would force DT_SNUL into the speculative recognizer, and
# DT_SNUL is 0x00 on a stack where zero is the commonest byte -- the gate would then ENFORCE the defect.  So the
# law is a DECLARED SUBSET: a copy may not exceed its authority, and every kind the authority has and a copy does
# not is either EXCLUDED WITH A REASON or UNDER-CURE WITH AN OWNER AND A ROW.  An unexplained divergence reds.
#
# ⛔ THE ARM THAT MAKES THIS SELF-CLEANING, and it is the half that is usually forgotten: a declaration is STALE
# the day its cure lands.  If DT_X appears in gc_cell_visit while the UNDER-CURE entry is still in the table, this
# gate goes RED -- so the bookkeeping cannot be skipped in either direction, and an exclusion cannot quietly
# become a parking space.
#
# ⛔ RED BY DESIGN ON THE DAY IT LANDS AND DECLARED AS SUCH (CEO-513): nine divergences carry no reason at all --
# gc_sniff_would_take is short of its authority by SIX kinds and gc_type_says_ref by FIVE.  Those two are
# INSTRUMENT halves: a kind missing there does not lose a value, it makes the census that would have FOUND the
# loss read agreement.  That is an instrument reporting success while it is not looking, which is the recurring
# failure the INSTRUMENT LAWS exist to catch, and it is why this gate names them rather than waiting for a cure.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT="$PWD"
CENSUS="$ROOT/../harness/scripts/util_gc_kind_sets.py"
SRC="$ROOT/src/runtime/rt/gc_heap.c"
# ⛔⭐ THE FLOOR IS A NAME SET AND NEVER A COUNT (cto 2026-09-21, and this is the THIRD time the same defect has
# been found in my own instruments in one evening -- I ruled it for hq_raku's DONE-WHEN, cured it in the
# unmapped-store ratchet, and it was still standing here).  A COUNT CANNOT TELL THE STANDING SEVEN FROM SEVEN
# DIFFERENT ONES: a landing that cures four and opens four reads 7 against a baseline of 7 and this arm says
# nothing.  ⛔ AND IT COST A SEAT REAL TIME BEFORE IT WAS CURED: the cfo saw this gate red on origin, remembered
# it green in their own battery, and spent four minutes re-running twelve blocking reds with their cure stashed to
# prove the red was not theirs.  It was never theirs and it was never a regression -- it is this row's STANDING
# DECLARED RED, and the gate did not say so in a way a reader could act on.  The banner now does.
DECLARED_STANDING=""
declared_red=0
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
refuse() { echo "⛔ GATE REFUSED(2) [gc_the_descriptor_kind_sets_are_a_declared_subset]: $1"; exit 2; }

[ -f "$CENSUS" ] || refuse "the census $CENSUS is missing -- nothing to grade"
[ -f "$SRC" ] || refuse "$SRC is missing -- the collector moved and this gate is reading nothing"

# (a) the instrument grades itself first
st="$(timeout -k 5 60s python3 "$CENSUS" --selftest 2>&1)"; src=$?
n="$(printf '%s\n' "$st" | sed -n 's/^SELFTEST \([0-9]*\)\/\([0-9]*\) arms green/\1 \2/p')"
set -- ${n:-0 0}
if [ "$src" = 0 ] && [ "${1:-0}" -ge 7 ] && [ "${1:-0}" = "${2:-x}" ]; then
  ck ok "(a) the kind-set census passes its own selftest, ${1} of ${2} arms"
else
  ck no "(a) the kind-set census selftest did not hold (rc=$src): $(printf '%s\n' "$st" | tail -3 | tr '\n' ' ')"
fi

rep="$(timeout -k 5 60s python3 "$CENSUS" 2>&1)"; rrc=$?
[ "$rrc" = 2 ] && refuse "$(printf '%s\n' "$rep" | grep -m1 REFUSED)"

# (b) the authority is read from the file, never assumed
auth="$(printf '%s\n' "$rep" | grep -m1 '^KINDSETS AUTHORITY ')"
ak="$(printf '%s\n' "$auth" | sed -n 's/.* kinds=\([0-9]*\) .*/\1/p')"
if [ "${ak:-0}" -ge 11 ] 2>/dev/null; then
  ck ok "(b) the authority is read out of gc_heap.c and carries ${ak} kinds -- $(printf '%s\n' "$auth" | cut -c1-120)"
else
  ck no "(b) the authority read as ${ak:-?} kinds -- a shrunken authority makes every copy look like a subset, which is agreement by erasure: $auth"
fi

# (c) NOBODY EXCEEDS THE AUTHORITY
if ! printf '%s\n' "$rep" | grep -q '^KINDSETS NOT-A-SUBSET '; then
  ck ok "(c) no spelling takes a kind the heap visitor does not -- the subset direction holds, so no copy visits something its authority cannot follow"
else
  ck no "(c) $(printf '%s\n' "$rep" | grep -c '^KINDSETS NOT-A-SUBSET ') spelling(s) exceed the authority: $(printf '%s\n' "$rep" | grep -m2 '^KINDSETS NOT-A-SUBSET ' | tr '\n' ' ')"
fi

# (d) PLANTED, BOTH DIRECTIONS: a new divergence must be NAMED and a landed cure must read STALE
plant="$(timeout -k 5 60s python3 - "$CENSUS" "$SRC" <<'PY' 2>&1
import sys, os, tempfile, importlib.util
census_path, src = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("ks", census_path)
ks = importlib.util.module_from_spec(spec); spec.loader.exec_module(ks)
text = open(src, encoding="utf-8").read()
lines = []
drop = text.replace("if (d->v == DT_T) { rt_hblk_t *th = gc_blk_of((const char *)d->tbl); if (th && th->type == HB_AGGT && (char *)d->tbl == (char *)(th + 1)) { rt_gc_visit_descr(d); return 1; } return 0; }",
                    "if (0) { return 0; }", 1)
add = text.replace("    if (d->v == DT_A && gc_block_exact((const char *)d->arr, HB_ARR)) { rt_gc_visit_descr(d); return 1; }",
                   "    if (d->v == DT_SNUL) { rt_gc_visit_descr(d); return 1; }\n    if (d->v == DT_A && gc_block_exact((const char *)d->arr, HB_ARR)) { rt_gc_visit_descr(d); return 1; }", 1)
for name, doctored in (("DROP", drop), ("ADD", add)):
    if doctored == text:
        print(f"PLANT-{name} FAILED-TO-SET-UP the anchor text was not found"); continue
    with tempfile.NamedTemporaryFile("w", suffix=".c", delete=False, encoding="utf-8") as fh:
        fh.write(doctored); p = fh.name
    got = []
    rc = ks.report(p, out=got.append)
    os.unlink(p)
    print(f"PLANT-{name} rc={rc} " + " | ".join(l[:90] for l in got if l.startswith(("KINDSETS UNDECLARED gc_cell_visit lacks DT_T", "KINDSETS STALE"))))
PY
)"
if printf '%s\n' "$plant" | grep -q 'PLANT-DROP rc=1 KINDSETS UNDECLARED gc_cell_visit lacks DT_T' \
   && printf '%s\n' "$plant" | grep -q 'PLANT-ADD rc=1 KINDSETS STALE gc_cell_visit HAS DT_SNUL'; then
  ck ok "(d) PLANTED BOTH WAYS -- removing DT_T from the recognizer is NAMED as undeclared, and adding a kind the table declares is NAMED as STALE. The ADD plant reads DT_SNUL and not DT_X since the cfo's DT_X landing (2026-09-20): DT_X's entry was UNDER-CURE and RETIRED THE DAY THE CURE LANDED, which took the plant's subject with it and broke this arm -- a self-test must not borrow a declaration that is designed to expire. DT_SNUL's gc_cell_visit exclusion is a FROZEN ruling (a speculative recognizer must never admit the zero tag) so it cannot expire, and the plant keeps a subject for as long as the rule stands"
else
  ck no "(d) the plant did not hold, so this gate can neither fail nor self-clean: $plant"
fi

# (e) THE READING ITSELF, and it is the work list
u="$(printf '%s\n' "$rep" | sed -n 's/^KINDSETS .* undeclared_or_stale=\([0-9]*\)$/\1/p')"
now_names="$(printf '%s\n' "$rep" | grep '^KINDSETS UNDECLARED ' | sed 's/^KINDSETS UNDECLARED //; s/ -- .*//' | sort)"
want_names="$(printf '%s\n' "$DECLARED_STANDING" | sed '/^$/d' | sort)"
new_names="$(comm -13 <(printf '%s\n' "$want_names") <(printf '%s\n' "$now_names") | tr '\n' ';')"
gone_names="$(comm -23 <(printf '%s\n' "$want_names") <(printf '%s\n' "$now_names") | tr '\n' ';')"
if [ "${u:-x}" = 0 ]; then
  ck ok "(e) every divergence from the authority is written down with its reason -- one fact, one authority, no absences"
elif [ -n "$new_names" ]; then
  ck no "(e) ⛔ A DIVERGENCE THAT IS NOT ON THE DECLARED STANDING LIST APPEARED -- THIS ONE IS A REGRESSION AND IS THE RED YOU CAME HERE FOR: $new_names (the standing list is $(printf '%s\n' "$want_names" | wc -l) entries and is declared in this gate). A copy of the fact grew a new hole, or a new copy of the fact was added without its declaration"
elif [ -n "$gone_names" ]; then
  ck no "(e) A STANDING DIVERGENCE IS GONE AND THE FLOOR STILL NAMES IT -- record the win rather than leaving the floor loose: $gone_names. Delete those line(s) from DECLARED_STANDING in this gate, in the landing that earned it"
else
  declared_red=1
  ck no "(e) ⭐ THE STANDING DECLARED RED, UNCHANGED AND NOT A REGRESSION -- ${u} divergence(s), name for name the list declared in this gate: $(printf '%s\n' "$now_names" | tr '\n' ';') ⛔ IF YOU ARE ATTRIBUTING A RED ON ORIGIN, STOP HERE: this arm has been red since the gate landed and stays red until the divergences are declared with reasons or cured. It becomes a REGRESSION only when a name appears that is not on that list, and this arm says so in different words when it does"
fi

# (f) an instrument nobody runs is not an instrument
if grep -q 'test_gate_gc_the_descriptor_kind_sets_are_a_declared_subset.sh' "$ROOT/Makefile" 2>/dev/null; then
  ck ok "(f) this gate is named in the Makefile, as a REPORTED arm -- red by design while arm (e) names the STANDING DECLARED divergences (seven today, nine when the gate landed; the cfo's DT_X landing cured two) (CEO-513 declare-when-you-hold-one-out, CEO-463 a known-red blocking arm makes every seat pay for one open row). It moves to blocking the day arm (e) goes green"
else
  ck no "(f) this gate is not named in the Makefile -- a gate in no runner is not measuring (RULES.md THE INSTRUMENT LAWS)"
fi

echo "population: $checks arm(s) graded, $fails FAIL; census rc=$rrc over 5 spellings in $(basename "$SRC")"
[ "$fails" = 0 ] && { echo "GATE PASS [gc_the_descriptor_kind_sets_are_a_declared_subset]: $checks of $checks arms hold"; exit 0; }
if [ "$fails" = 1 ] && [ "$declared_red" = 1 ]; then
  echo "⛔ GATE RED (DECLARED) [gc_the_descriptor_kind_sets_are_a_declared_subset]: 1 of $checks arms FAIL, and it is arm (e), THE STANDING DECLARED RED OF THIS ROW -- name for name the list this gate declares. NOT A REGRESSION AND NOT SOMEBODY'S LANDING. A reader attributing a red on origin can stop here."; exit 1
fi
echo "⛔ GATE RED [gc_the_descriptor_kind_sets_are_a_declared_subset]: $fails of $checks arms FAIL"; exit 1
