#!/usr/bin/env bash
# test_gate_gc_differential_configs_agree.sh -- row gc-the-differential-oracle-same-program-under-two-gc-
# configurations-must-agree (coo, 2026-09-21, MODE TENET; RULES.md THE INSTRUMENT LAWS; CEO-997 batch 30
# clause 2 -- a census NAMES and never only counts).
#
# THE PRINCIPLE. GC is SEMANTICALLY INVISIBLE, so one program on one input must print the same bytes under
# EVERY GC configuration. A divergence IS a defect with NO oracle and NO .ref required -- which makes every
# program in the corpus a GC test in all seven languages without anyone writing a witness, and that is what
# Lon asked for when he said he did not want things flushed out by hand.
#
# ⛔⭐ WHAT THIS GATE IS REALLY GUARDING, AND IT IS NOT THE PASS COUNT. A differential's pass condition is
# AGREEMENT, and the cheapest way to agree is to run one configuration N times. The hazard was measured
# before the instrument was written, on hb_bignum_length.icn at origin f7669a6a8 with SCRIP_ZETA_TELEM=1:
#     shipped 0 collections | SCRIP_GC_RELOC=1 0 | SCRIP_GC_POISON=0 0 | SCRIP_GC_PLANT_SHIFT=65536 0
#     SCRIP_HEAP_MB=1 1     | SCRIP_GC_STRESS=3 2598
# FOUR OF SIX DECLARED CONFIGURATIONS COLLECTED ZERO TIMES with byte-identical (empty) event fingerprints.
# A six-row md5 table over them prints six matching hashes and reads as "six configurations agree" while
# measuring one. RELOC, POISON and PLANT_SHIFT are MODIFIERS OF A COLLECTION, not independent axes. So every
# configuration is COMPOSED with a collecting axis, and -- because a declaration is not a measurement -- the
# harness re-proves distinctness PER PROGRAM from the collector's own printed events and refuses
# UNDISTINGUISHED rather than passing. The cto measured the same class from the other side the same afternoon
# (SCRIP_GC_PLANT_SHIFT=1048576 applying ZERO times, rc=0, byte-identical stdout; cured at SCRIP 1b317bea3).
# ⛔ hb_arr.sno is the standing proof that this is not hypothetical: 6 declared, 2 DISTINCT, five collapsed.
#
# ⛔ AND THE OPPOSITE ERROR IS ALSO AN ARM, because it discards real axes. arena1_nopoison has a move
# fingerprint IDENTICAL to arena1 -- poison changes what is written to VACATED ground, not what moves -- so a
# fingerprint built from the move columns calls a genuinely distinct configuration undistinguished. The
# fingerprint is taken over EVERY collector tag ([ZGC-POISON] is simply absent under POISON=0). Too narrow
# throws away axes; too wide (addresses, timings) makes every run of ONE configuration look distinct and the
# determinism pre-pass collapses. Arm 5 pins the stable direction, arm 3 the collapsing one.
#
# ⛔ WHY A DIVERGENCE IS rc=2 AND NOT rc=1 IN THE HARNESS. The question a caller asks it is "what does this
# program print?" If two GC configurations disagree there IS NO SINGLE ANSWER, so it refuses rather than hand
# a board whichever configuration it happened to run. The DEFECT is reported by NAME in the text and by this
# gate's ratchet; the rc reports measurability. THIS GATE reds on a NEW divergence -- see arm 1.
#
# ⛔ NO XFAIL AND NO SILENT FLOOR (CEO-753). The floor file records what was measured, and a program in it
# that DIVERGES is a RED here with its name, not a tolerated entry. The floor exists only so that a program
# which has been GRADED cannot quietly stop being graded -- a fall from AGREE to UNDISTINGUISHED or
# NO-COLLECTION is a knob that stopped taking, which is precisely this row's hazard, and it reds.
#
# ⛔ SPELLING IS HELD CONSTANT AND SAYING SO IS LOAD-BEARING (COO-127): the source path is itself a heap block,
# so its length shifts every block after it and one witness reaches interior=1 as ../harness/scripts/x and interior=0 as
# ./scripts/x. Every configuration of one program is invoked with the IDENTICAL path string, so the
# differential is immune to that variable only because it never varies it. The cto measured that the same
# variable does NOT reach their static unmapped-store census (three spellings, calls=6326 on_grid=5295).
#
# ARMS. (1) the declared population is graded, the identity closes, and the RATCHET holds -- no new divergence
# and nothing that was graded has stopped being graded. (2) a PLANTED divergence is caught, naming both
# configurations and the first differing byte -- a differential that cannot report is not a differential.
# (3) a configuration that collapses onto another is UNDISTINGUISHED and NEVER a pass. (4) a program that
# differs from ITSELF is EXCLUDED and NAMED, never silently dropped. (5) the event fingerprint is STABLE
# across repeated runs of ONE configuration -- else every distinctness verdict is noise. (6) an empty or
# ungradable population REFUSES instead of reading as agreement. (7) telemetry does not change the answer, so
# holding it on across the matrix is not itself a variable.
# ⛔ This seat holds no cure lane (CEO-723): every divergence this instrument finds is a telegram to the
# owning seat and a row, never an edit here.
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: cannot source lib_gate.sh"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
[ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
gate_require_fresh "$ROOT" src "$SCRIP" || exit 2
U="$HERE/util_gc_differential.py"
[ -f "$U" ] || { echo "⛔ GATE REFUSE(2) [$G]: the instrument $U does not exist -- it IS the deliverable"; exit 2; }
CFG="$HERE/gc_differential_configs.tsv"
[ -f "$CFG" ] || { echo "⛔ GATE REFUSE(2) [$G]: no declared configurations at $CFG -- the declaration is the
   instrument's vocabulary and may not be defaulted silently"; exit 2; }
FLOOR="$HERE/gc_differential_floor.tsv"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; examined=0
FO="${FAIL_ONCE:-0}"

echo "  HOLDS: one program under N GC configurations prints the same bytes; every configuration is PROVEN"
echo "         DISTINCT before its output is believed; and a program that was graded stays graded"

# The gate's own population is small and fixed so it stays cheap enough for the blocking set (TENET
# condition 2 is this seat's lane -- an instrument that caps ten seats is not a multiplier). The broad sweep
# is the same instrument with --pool and belongs to a board pass, not here.
POP=(
  "$HERE/gc_witnesses/hb_bignum_length.icn"
  "$HERE/gc_witnesses/hb_arr.sno"
)

# ---- arm 1: the declared population grades, the identity closes, and the ratchet holds -------------------
examined=$((examined + 1))
out="$(cd "$ROOT" && timeout -k 5 900 python3 "$U" "${POP[@]}" --timeout 60 --tsv "$T/now.tsv" 2>&1)"; rc=$?
if ! printf '%s\n' "$out" | grep -q '^DIFFERENTIAL: '; then
  echo "  REFUSE ARM 1: the instrument printed no DIFFERENTIAL line -- it measured nothing"
  printf '%s\n' "$out" | tail -6 | sed 's/^/           /'; exit 2
fi
line="$(printf '%s\n' "$out" | grep '^DIFFERENTIAL: ' | tail -1)"
if ! printf '%s\n' "$out" | grep -q 'population [0-9]* OK'; then
  echo "  RED  ARM 1: the verdict identity does not close -- the census is not trustworthy"
  printf '%s\n' "$out" | grep 'IDENTITY' | sed 's/^/           /'; RC=1
fi
dv="$(printf '%s\n' "$line" | sed -n 's/.*diverge=\([0-9]*\).*/\1/p')"
if [ "${dv:-0}" != 0 ]; then
  echo "  RED  ARM 1: $dv program(s) DIVERGE across GC configurations -- GC is not semantically invisible here,"
  echo "       and each of these is a collector defect owed a row (this gate does not tolerate a named divergence:"
  echo "       there is no such thing as XFAIL, CEO-753):"
  printf '%s\n' "$out" | grep -A1 'DIVERGE ' | sed 's/^/           /'
  RC=1
else
  echo "  ok   ARM 1: $line"
fi
# the ratchet: a program that WAS graded may not stop being graded. A fall from AGREE to UNDISTINGUISHED or
# NO-COLLECTION means a knob stopped taking, which is this row's own hazard arriving from the other side.
if [ -f "$FLOOR" ]; then
  while IFS=$'\t' read -r fp fv fd _rest; do
    case "$fp" in ''|'#'*|program) continue;; esac
    nv="$(awk -F'\t' -v p="$fp" '$1==p{print $2}' "$T/now.tsv" 2>/dev/null | head -1)"
    nd="$(awk -F'\t' -v p="$fp" '$1==p{print $3}' "$T/now.tsv" 2>/dev/null | head -1)"
    [ -n "$nv" ] || { echo "  RED  ARM 1 ratchet: $fp is in the floor and was NOT graded this run"; RC=1; continue; }
    if [ "$fv" = AGREE ] && [ "$nv" != AGREE ]; then
      echo "  RED  ARM 1 ratchet: $fp fell AGREE -> $nv; a graded program stopped being graded, which is a knob"
      echo "       that stopped taking and not an improvement"; RC=1
    fi
    if [ "$fv" = AGREE ] && [ "$nv" = AGREE ] && [ "${nd:-0}" -lt "${fd:-0}" ]; then
      echo "  RED  ARM 1 ratchet: $fp agreed over $fd distinct configurations and now only $nd -- a configuration"
      echo "       collapsed onto another and the agreement is weaker than the floor it was pinned at"; RC=1
    fi
  done < "$FLOOR"
  echo "  ok   ARM 1 ratchet: read $(grep -vc '^#' "$FLOOR" 2>/dev/null) floor row(s) from $(basename "$FLOOR")"
else
  echo "  REFUSE ARM 1 ratchet: no floor at $FLOOR -- create it with --tsv; an unpinned differential cannot"
  echo "       notice a configuration going quiet"; RC=2
fi

# ---- arm 1b: THE DIVERGENCE REGISTER IS AN OBLIGATION, NOT AN EXCUSE -------------------------------------
# ⛔ CEO-753: there is no such thing as XFAIL. The broad sweep (--pool, a board pass and NOT this gate) finds
# divergences that this gate's small population does not contain; they are recorded so a seat who did not run
# the sweep can still name them a week later. An entry may therefore never make a divergence pass: every row
# must name an OWNER SEAT and a ROW, and a row missing either is RED here -- that is a defect found with
# nobody told, which is the only thing worse than not finding it.
examined=$((examined + 1))
REG="$HERE/gc_differential_divergences.tsv"
if [ ! -f "$REG" ]; then
  echo "  REFUSE ARM 1b: no divergence register at $REG"; RC=2
else
  nreg=0; bad=0
  while IFS=$'\t' read -r rp ra rb rowner rrow _rest; do
    case "$rp" in ''|'#'*|program) continue;; esac
    nreg=$((nreg + 1))
    if [ -z "${rowner:-}" ] || [ -z "${rrow:-}" ]; then
      echo "  RED  ARM 1b: register row $rp names configs ${ra:-?}/${rb:-?} but has owner='${rowner:-}' row='${rrow:-}'"
      echo "       -- a divergence parked without an owner and a row is an XFAIL, and there is no XFAIL"
      bad=$((bad + 1)); RC=1
    fi
  done < "$REG"
  [ "$bad" = 0 ] && echo "  ok   ARM 1b: $nreg registered divergence(s), each naming an owner seat and a row"
fi

# ---- arm 2: a PLANTED divergence is caught and REPORTED, with both names and the first differing byte -----
examined=$((examined + 1))
p2="$(cd "$ROOT" && timeout -k 5 600 python3 "$U" "$HERE/gc_witnesses/hb_arr.sno" --timeout 60 \
      --plant-divergence arena1_stress3 2>&1)"; rc2=$?
if [ "$rc2" != 2 ]; then
  echo "  RED  ARM 2: a planted divergence exited rc=$rc2, expected 2 -- a differential that cannot refuse is"
  echo "       satisfiable by agreeing with itself"; RC=1
elif ! printf '%s\n' "$p2" | grep -q 'DIVERGE'; then
  echo "  RED  ARM 2: a planted divergence was not classified DIVERGE"; RC=1
elif ! printf '%s\n' "$p2" | grep -q 'FIRST DIFFERING BYTE AT OFFSET'; then
  echo "  RED  ARM 2: the divergence does not name the first differing byte -- the row requires it"; RC=1
elif ! printf '%s\n' "$p2" | grep -q 'arena1 and arena1_stress3 disagree'; then
  echo "  RED  ARM 2: the divergence does not name BOTH configurations"; RC=1
else
  echo "  ok   ARM 2: planted divergence caught, both configurations and the first differing byte named"
fi

# ---- arm 3: a configuration that collapses onto another is UNDISTINGUISHED, never a pass -----------------
# Two rows that are the SAME configuration under two names. This is the header's hazard in its purest form:
# without the distinctness proof this population would report a clean two-configuration agreement.
examined=$((examined + 1))
# ⛔ THE FIXTURE MUST COLLECT UNDER THE REFERENCE CONFIGURATION or NO-COLLECTION preempts UNDISTINGUISHED and
# the arm passes for the wrong reason. hb_arr.sno collects 0 times at arena1 and was the first draft's mistake;
# hb_bignum_length.icn collects once, so the twins genuinely collapse rather than never running.
printf 'twinA\tSCRIP_HEAP_KB=128\tdeliberate twin\ntwinB\tSCRIP_HEAP_KB=128\tthe SAME configuration under a second name\n' > "$T/twin.tsv"
p3="$(cd "$ROOT" && timeout -k 5 600 python3 "$U" "$HERE/gc_witnesses/hb_bignum_length.icn" --configs "$T/twin.tsv" \
      --timeout 60 2>&1)"; rc3=$?
if [ "$rc3" != 2 ]; then
  echo "  RED  ARM 3: two identical configurations under different names exited rc=$rc3, expected 2 -- this is"
  echo "       the vacuous green the whole row exists to prevent"; RC=1
elif ! printf '%s\n' "$p3" | grep -q 'UNDISTINGUISHED'; then
  echo "  RED  ARM 3: a collapsed configuration pair was not classified UNDISTINGUISHED"; RC=1
elif ! printf '%s\n' "$p3" | grep -q 'collapsed onto each other'; then
  echo "  RED  ARM 3: UNDISTINGUISHED was reported without saying the configurations collapsed"; RC=1
else
  echo "  ok   ARM 3: twin configurations refused as UNDISTINGUISHED, not passed as agreeing"
fi

# ---- arm 3b: A CONFIGURATION THAT COLLAPSES BY EFFECT, NOT BY DECLARATION -------------------------------
# Arm 3's twins are caught with CERTAINTY from the declaration. This is the harder and more realistic case
# and it is the exact pair measured at the top of this row: shipped and SCRIP_GC_RELOC=1 are DIFFERENT
# declarations that both collect ZERO times at the shipped arena, so forcing relocation forces nothing and
# the two are one configuration in effect. It must be caught by the collector's own events, not by comparing
# the env. This is the fixture the whole row exists for.
examined=$((examined + 1))
# ⛔ THE PAIR IS PINNED TO A WINDOW NOTHING FILLS (cto 2026-09-24, the seventeen-red row): since CEO-1101 the shipped
# window is 128 KB and hb_arr.sno COLLECTS there, so "shipped" and RELOC=1 are two configurations in effect and the
# tool graded them (rc=0) -- the arm read that truthful reading as a regression.  The collapse this arm exists to
# catch needs zero collections on both sides, which a 512 MB window gives and the shipped one no longer does.
printf 'shipped\tSCRIP_HEAP_KB=524288\ta window nothing fills, no other knob\nflip_only\tSCRIP_HEAP_KB=524288 SCRIP_GC_PLANT_FLIP=1\tasks for a flip but nothing forces a collection\n' > "$T/eff.tsv"
fb="$(cd "$T" && env SCRIP_HEAP_KB=524288 SCRIP_GC_PLANT_FLIP=1 timeout -k 5 60 "$SCRIP" --run "$HERE/gc_witnesses/hb_arr.sno" </dev/null 2>&1 >/dev/null | grep -c "^\[GC-FLIP\] plant:")"; fb=${fb:-0}
p3b="$(cd "$ROOT" && timeout -k 5 600 python3 "$U" "$HERE/gc_witnesses/hb_arr.sno" --configs "$T/eff.tsv" \
       --timeout 60 2>&1)"; rc3b=$?
if [ "$fb" != 0 ]; then
  echo "  RED  ARM 3b: the flip_only side printed the [GC-FLIP] plant: banner $fb time(s) at a 512 MB window -- the pair is DISTINCT in effect and this arm's collapse premise is unmet"; RC=1
elif [ "$rc3b" != 2 ]; then
  echo "  RED  ARM 3b: shipped vs SCRIP_GC_PLANT_FLIP=1 exited rc=$rc3b, expected 2 -- two DIFFERENT declarations"
  echo "       that both collect zero times were read as a real differential"; RC=1
elif ! printf '%s\n' "$p3b" | grep -qE '^DIFFERENTIAL: .*(no_collection|undistinguished)=[1-9]'; then
  echo "  RED  ARM 3b: a pair that collapses BY EFFECT was not counted as no_collection or undistinguished"
  printf '%s\n' "$p3b" | tail -4 | sed 's/^/           /'; RC=1
else
  echo "  ok   ARM 3b: a pair that collapses by EFFECT (shipped vs flip_only, 0 collections each, 0 flip banners) refused,"
  echo "       caught from the collector's events and not from the declaration"
fi

# ---- arm 4: a program that differs from ITSELF is EXCLUDED and NAMED -------------------------------------
examined=$((examined + 1))
# ⛔ THE FIXTURE'S OWN SYNTAX IS LOAD-BEARING AND THE FIRST DRAFT GOT IT WRONG IN A WAY THAT PASSED QUIETLY.
# Written without the frontend's mandatory statement semicolons it did not compile, printed the SAME parse
# error on every run, sailed through the determinism pre-pass as perfectly deterministic and was classified
# NO-COLLECTION -- a statement about the collector from a program that never ran. That hole is now a
# classification of its own (UNMEASURED, did-not-run) in the instrument, found BY this arm rather than by
# reading. It churns 300 allocations so it also collects, and /proc/uptime moves between runs.
cat > "$T/nd.icn" <<'ICN'
procedure main();
   local f, s, i, churn;
   f := open("/proc/uptime", "r");
   s := read(f);
   close(f);
   every i := 1 to 300 do churn := repl("z", 100);
   write("up=", s);
end
ICN
p4="$(cd "$ROOT" && timeout -k 5 600 python3 "$U" "$T/nd.icn" --timeout 60 2>&1)"; rc4=$?
if ! printf '%s\n' "$p4" | grep -q 'EXCLUDED-NONDETERMINISTIC'; then
  echo "  RED  ARM 4: a program that differs from itself was not EXCLUDED-NONDETERMINISTIC (rc=$rc4) -- it would"
  echo "       otherwise be a permanent false divergence blamed on the collector"
  printf '%s\n' "$p4" | tail -5 | sed 's/^/           /'; RC=1
elif ! printf '%s\n' "$p4" | grep -q 'differs from ITSELF'; then
  echo "  RED  ARM 4: the exclusion does not say the program differs from itself"; RC=1
else
  echo "  ok   ARM 4: self-nondeterministic program excluded BY NAME, not silently dropped"
fi

# ---- arm 4b: A PROGRAM THAT NEVER RAN IS UNMEASURED, NOT NO-COLLECTION -----------------------------------
# NO-COLLECTION asserts "this program ran and the collector never fired", which is a claim about the
# collector. A file the frontend REFUSES prints the same error every run, is perfectly deterministic, and
# collects zero times -- so without this classification it would make that claim having never run. This arm
# exists because it is exactly how arm 4's first fixture failed, silently and green.
examined=$((examined + 1))
# ⛔ THE FIXTURE MUST ACTUALLY FAIL TO COMPILE, WHICH THE FIRST TWO ATTEMPTS DID NOT. Omitting statement
# semicolons compiles and runs (rc=0), so that file proved nothing; a real parse error exits rc=1. Measured
# rather than assumed, after one reading of an exit code through a pipeline returned head's rc instead of
# scrip's and nearly produced a finding that was not there.
printf 'procedure main();\n   local x;\n   x := := ;;; @@@\nend\n' > "$T/broken.icn"
# ⛔ AND THIS ARM IS READ FROM THE MACHINE FIELD, NOT THE PROSE, BECAUSE THE PROSE VERSION FAILED FIRST.
# Grepping the report for the word NO-COLLECTION matched the sentence "must not read as NO-COLLECTION" -- the
# explanation that exists to DENY the classification satisfied the search for it. That is the same defect the
# cto's own plant-decline line carries (its advice quotes the literal string '[GC-SHIFT] plant:' that it tells
# a reader to count, so a naive grep scores a DECLINE as an APPLICATION -- measured here the same afternoon),
# and it landed in this gate within the hour of my diagnosing it there. A verdict is read from the
# DIFFERENTIAL summary's counted field; prose is never a machine interface.
p4b="$(cd "$ROOT" && timeout -k 5 300 python3 "$U" "$T/broken.icn" --timeout 60 2>&1)"; rc4b=$?
if printf '%s\n' "$p4b" | grep -q '^DIFFERENTIAL: .*no_collection=[1-9]'; then
  echo "  RED  ARM 4b: a program that does not compile was COUNTED as NO-COLLECTION -- that asserts the"
  echo "       collector never fired for a program that never ran"; RC=1
elif ! printf '%s\n' "$p4b" | grep -q '^DIFFERENTIAL: .*unmeasured=[1-9]'; then
  echo "  RED  ARM 4b: a program that does not compile was not COUNTED as unmeasured (rc=$rc4b)"
  printf '%s\n' "$p4b" | tail -4 | sed 's/^/           /'; RC=1
elif ! printf '%s\n' "$p4b" | grep -q 'did not run'; then
  echo "  RED  ARM 4b: a program that does not compile was not reported as having failed to run (rc=$rc4b)"
  printf '%s\n' "$p4b" | tail -4 | sed 's/^/           /'; RC=1
else
  echo "  ok   ARM 4b: a program that never ran is UNMEASURED and says so, not NO-COLLECTION"
fi

# ---- arm 5: the event fingerprint is STABLE across repeated runs of one configuration --------------------
# If it is not, every distinctness verdict above is noise: addresses and timings would make one configuration
# look like N. Three runs, one configuration, the normalized fingerprint must be identical all three times.
# ⛔ THIS ARM WAS WRITTEN THE WRONG WAY ROUND FIRST AND THE CORRECTION IS THE POINT. It originally asserted
# that the HAND-NORMALIZED fingerprint is stable, and it RED: 24 runs of hb_bignum_length.icn on one tree,
# one configuration and one path spelling gave two fingerprints, 16 and 8, differing in exactly one field --
# slots=600 vs slots=601 (g_gc_nslot, the root slots the collector fixed up), everything else byte-identical.
# So the assertion was false and the instrument's premise -- that hand-normalizing yields a stable
# fingerprint -- was the thing at fault. THE FIX WAS NOT TO WEAKEN THE ARM: the instrument now MEASURES its
# noisy fields from repeated reference runs and excludes them by name, and what must be stable is the
# VERDICT the masked fingerprint produces. That is what this arm now grades, end to end, twice.
examined=$((examined + 1))
s1="$(cd "$ROOT" && timeout -k 5 600 python3 "$U" "$HERE/gc_witnesses/hb_bignum_length.icn" --timeout 60 \
      --tsv "$T/s1.tsv" 2>&1 | grep '^DIFFERENTIAL: ')"
s2="$(cd "$ROOT" && timeout -k 5 600 python3 "$U" "$HERE/gc_witnesses/hb_bignum_length.icn" --timeout 60 \
      --tsv "$T/s2.tsv" 2>&1 | grep '^DIFFERENTIAL: ')"
v1="$(awk -F'\t' 'NR>2{print $2"/"$3}' "$T/s1.tsv" 2>/dev/null)"
v2="$(awk -F'\t' 'NR>2{print $2"/"$3}' "$T/s2.tsv" 2>/dev/null)"
if [ -z "$v1" ] || [ "$v1" != "$v2" ]; then
  echo "  RED  ARM 5: the distinctness VERDICT is not reproducible -- '$v1' then '$v2'. With an unstable"
  echo "       fingerprint two IDENTICAL configurations look distinct, which is exactly the vacuous agreement"
  echo "       this row exists to prevent (it is how the twin arm passed before the noise mask existed)."; RC=1
else
  echo "  ok   ARM 5: verdict reproducible over two independent runs ($v1); the measured noise mask is what"
  echo "       makes it so -- the RAW normalized fingerprint is NOT stable on this program (slots=600/601)"
fi

# ---- arm 6: an empty or ungradable population REFUSES rather than reading as agreement -------------------
examined=$((examined + 1))
p6="$(cd "$ROOT" && timeout -k 5 120 python3 "$U" --pool "$T/empty-does-not-exist" 2>&1)"; rc6=$?
mkdir -p "$T/emptydir"
p6b="$(cd "$ROOT" && timeout -k 5 120 python3 "$U" --pool "$T/emptydir" 2>&1)"; rc6b=$?
if [ "$rc6" != 2 ] || [ "$rc6b" != 2 ]; then
  echo "  RED  ARM 6: a missing pool exited rc=$rc6 and an empty pool rc=$rc6b, expected 2 for both -- measuring"
  echo "       nothing must never read as agreement (RULES.md THE INSTRUMENT LAWS)"; RC=1
elif ! printf '%s\n' "$p6b" | grep -q 'may not read as agreement'; then
  echo "  RED  ARM 6: the empty-population refusal does not say why"; RC=1
else
  echo "  ok   ARM 6: missing pool and empty pool both REFUSE rc=2 with a reason"
fi

# ---- arm 7: telemetry is not itself a variable -----------------------------------------------------------
# The matrix runs with SCRIP_ZETA_TELEM=1 throughout so the fingerprint is readable. That is only sound if
# telemetry does not change the program's answer -- otherwise the instrument perturbs what it measures.
examined=$((examined + 1))
w="$HERE/gc_witnesses/hb_bignum_length.icn"
a="$(cd "$ROOT" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 timeout -k 5 90s ./scrip "$w" 2>/dev/null </dev/null | md5sum)"
b="$(cd "$ROOT" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 SCRIP_ZETA_TELEM=1 timeout -k 5 90s ./scrip "$w" 2>/dev/null </dev/null | md5sum)"
if [ "$a" != "$b" ]; then
  echo "  RED  ARM 7: SCRIP_ZETA_TELEM changes the program's stdout ($a vs $b) -- holding it on across the"
  echo "       matrix would make the instrument a variable of its own measurement"; RC=1
else
  echo "  ok   ARM 7: telemetry does not change stdout, so holding it constant across the matrix is sound"
fi

# ---- FAIL_ONCE: both directions, because a ratchet that cannot fail is not a ratchet ---------------------
if [ "$FO" = 1 ]; then
  echo "  FAIL_ONCE=1: asserting the ratchet notices a graded program going ungraded"
  RC=1
elif [ "$FO" = 2 ]; then
  echo "  FAIL_ONCE=2: asserting the greedy direction -- accepting a collapsed configuration as agreement"
  RC=1
fi

echo "  $G: arms=$examined rc=$RC configurations=$(grep -vc '^#\|^$' "$CFG") population=${#POP[@]} \
tree=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" status --porcelain 2>/dev/null | grep -q . && echo -dirty)"
exit $RC
