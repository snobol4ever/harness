#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_rungs_is_clean_at_the_tiny_arena.sh -- PROLOG'S GC SHARE, HALF TWO (hq_prolog, row
# prolog-gc-the-prolog-share-of-the-unmapped-slot-population-censused-by-name-and-the-master-clean-at-one-megabyte;
# ceo CEO-1011 / TENET condition 1, hardened on Lon's challenge 2026-09-20).
#
# ⛔ WHAT THIS GATE EXISTS FOR, AND WHY NO EXISTING INSTRUMENT SEES IT. The ceo measured hq_snobol4's nine-line
# witness at SCRIP_HEAP_MB=1: four of seven stress points RETURN A WRONG ANSWER, SILENTLY, EXIT 0, NO DIAGNOSTIC.
# Every rc-shaped census reads GREEN over that class -- and so does a pass TOTAL, because a board that loses one
# entry and gains another reads identical (the swap, GOAL-TEST-SUITE-CONSISTENCY's per-entry-identity lesson).
# So this gate grades BY ORACLE DIFF, PER ENTRY, NEVER BY rc AND NEVER BY A TOTAL: it runs the Prolog rungs
# once per ARM on ONE binary and NAMES every (entry, mode) pair whose outcome MOVED against the control arm.
#
# ⛔⭐ TWO AXES, BECAUSE ONE AXIS READS GREEN OVER THE CLASS -- hq_snobol4 measured this and sent it to me
# 2026-09-20, and it was a hole in this gate's FIRST cut, which varied the arena alone. Their witness is
# byte-equal to its ref at stress 0 and wrong from stress>=1, IN BOTH MODES, AT BOTH ARENAS: the band moves with
# the POLL SET, not the window. Confirmed in the mechanism rather than taken on trust -- gc_heap.c
# c_rt_gcheap_alloc reads SCRIP_GC_STRESS once into a static and raises g_gc_pending every N allocations, so it
# is orthogonal to window size, and UNSET MEANS ZERO FORCED COLLECTIONS. A gate that pins the arena, leaves the
# poll set unset and prints "tiny arena" certifies half of what a reader will take it to mean.
#   ARM control  : SCRIP_HEAP_MB=512, no forced collection      -- the loose baseline every other arm is diffed against
#   ARM arena    : compiled default (unset), no forced collection -- does the SMALL WINDOW change an answer
#   ARM stress:N : compiled default (unset) + SCRIP_GC_STRESS=N -- does COLLECTING OFTEN change an answer, one arm per N
#
# ⛔⭐⭐ RE-POINTED 2026-09-22 (hq_prolog), CAUGHT BEFORE A RE-MEASURE COULD BE BUILT ON THE STALE READING, NOT
# AFTER: ceo CEO-1095 (Lon 2026-09-21, "take the default GC arena down to 128 KB") made the compiled default
# GC_HEAP_KB=128 the tiny/exasperating arena FOR EVERY SEAT, and made an explicit SCRIP_HEAP_MB=1 pin (1024 KB)
# 8x LOOSER than that default, collecting 13x LESS (measured by the cfo on bench_icnstr_concat_table.icn: 1613
# collections at 1 MB against 21362 at the 128 KB default). Before CEO-1095 an SCRIP_HEAP_MB=1 pin WAS the
# exasperating arm; today it is the opposite one. This gate's "arena"/"stress:N" arms therefore leave
# SCRIP_HEAP_MB/SCRIP_HEAP_KB UNSET ON PURPOSE, so they always track WHATEVER Lon's current tiny-arena default
# is with no maintenance owed here when it moves again (the same reasoning the Makefile gives for `?=` over
# `:=` on this knob). "control" is the one arm that now needs an EXPLICIT loose pin (512 MB) to keep a genuine
# contrast to diff against, matching the value this gate's own DECIDABILITY probe already assumed for it.
#
# ⛔⭐⭐ A STRESS BAND, NEVER A STRESS POINT -- ceo CEO-1024, 2026-09-20, and it retired MY OWN first number.
# hq_raku ran the raku rungs at SCRIP_HEAP_MB=1 SCRIP_GC_STRESS=16 on the same tree and same binary as two
# green arms: m3 853 -> 817, m4 853 -> 824. SIXTY-FIVE GRADINGS LOST, ZERO GAINED, THIRTY-SIX DISTINCT
# PROGRAMS, every one exit 0 with no diagnostic and a plausible wrong answer, every one MATCHING at stress 0.
# The fleet had been grading at 1, 3 and 5 and calling that clean. ⛔ THE RULING: if your lane is clean at 1, 3
# and 5 you have not measured your lane, YOU HAVE MEASURED THE BAND.
# ⭐ AND THE JUDGEMENT ERROR IS WORTH MORE THAN THE NUMBER, because it is the one a careful seat makes: this
# gate's first cut used STRESS_N=8, picked as the top of hq_snobol4's measured red band {1,2,4,8}. Choosing the
# plant from where the KNOWN defects were is choosing a band that ENDS WHERE THE DEFECTS START -- evidence-based
# in feel and circular in fact. A single point cannot answer "is there a divergence point above this one", and
# that is the only question worth asking. So the band ASCENDS and the gate reports WHERE the divergence point
# is, rather than whether one chosen plant happened to sit on it.
#
# ⛔ A TIMEOUT IS NOT A DIVERGENCE AND THIS GATE REFUSES RATHER THAN GUESSING. Under stress=1 a correct program
# can run two orders of magnitude slower; an rc=124 cannot distinguish "needs 8.1s" from "never finishes". So
# the stress arm raises the harness per-program TIMEOUT, and any pair whose ONLY movement is into HANG is
# reported as INCONCLUSIVE and REFUSES rc=2 -- never counted as a collector defect, and never quietly dropped
# to keep the gate green. A clean this gate could not measure is not a clean.
#
# ⛔ NOT IN `make test`, ON PURPOSE, AND DO NOT WIRE IT THERE. Three full rungs boards is ~3x a single board,
# and TENET condition 2 is that the blocking set is the shared resource that does not scale with seats (367
# serial arms, essentially serial, one 16-core box, ten seats queueing). This is a DELIBERATE gate: the owning
# row runs it, and a landing claiming Prolog's GC share is clean cites its output.
#
# ⛔ REFUSES rc=2 RATHER THAN REPORTING A CLEAN IT COULD NOT MEASURE: no binary, no suite, an arm that printed
# no SUITE_BOARD line, two arms whose entry sets differ, or an inconclusive HANG. A short count is never a green
# here -- the whole failure mode this gate is built against is a plausible wrong answer at exit 0.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP:-$ROOT/scrip}"; P="${PL_SUITE_DIR:-$S4E/corpus/tests/prolog}"
SHARDS="${SHARDS:-16}"; CONTROL_MB="${CONTROL_MB:-512}"
# ⛔ THE DEFAULT BAND GOES WELL ABOVE 5 AND ABOVE 16 ON PURPOSE (CEO-1024). 16 is where hq_raku found 36 silently
# wrong raku programs; a band that STOPS at the highest value anyone has yet found a defect at is the same
# circular choice this gate was just corrected for, so it carries a value ABOVE the known one.
# ⛔⭐⭐ SPAN BOTH ENDS, NON-UNIFORM -- and this default is the THIRD cut of this line, each one corrected by
# a measurement rather than by reasoning. (1) STRESS_N=8, picked as the top of hq_snobol4 known red band {1,2,4,8}:
# a band that ENDS WHERE THE DEFECTS START. (2) {16,32} after CEO-1024, which is the SAME ERROR MIRRORED --
# hq_raku map family window is stress 1..6 and is INVISIBLE at 8 and above, so "a lane that moves its band from
# 1-3-5 up to 16 and reports clean has traded one blind spot for another" (hq_raku, verbatim). (3) This one.
# The cto adds the shape that forbids a straight line in EITHER direction: hq_snobol4 has a witness RED at m4
# stress 25 while GREEN at 10, 12, 16, 20, 35 AND 50. ⛔ WHATEVER A BAND FINDS IS A LOWER BOUND, NEVER A POPULATION.
STRESS_BAND="${STRESS_BAND:-2 5 16 25}"
STRESS_TIMEOUT="${STRESS_TIMEOUT:-1800}"; SHARD_TIMEOUT="${SHARD_TIMEOUT:-5400}"
# ⛔ 600s -> 1800s (hq_prolog, 2026-09-22), MEASURED NOT GUESSED: after the arena-pin fix above raised how
# often the corrected "arena"/"stress:N" arms genuinely collect, benchmark_queensn at stress:2 (both modes)
# read INCONCLUSIVE-SLOW against the old 600s bound. Timed standalone, contention-free: 565s (m3) / 581s
# (m4), both byte-exact against queensn.expected once they finished -- a correct program, not a hang, with
# ZERO headroom under 600s. This box runs several seats' boards concurrently, so contention alone can push a
# borderline case over a tight bound; 1800s gives ~3x headroom over the measured need. Re-run at 1500s on
# this tree (control+stress:2 only, ARMS_OVERRIDE) confirmed clean: divergent=0 inconclusive=0 vanished=0.
ARMS="control arena"; for _n in $STRESS_BAND; do ARMS="$ARMS stress:$_n"; done; ARMS="${ARMS_OVERRIDE:-$ARMS}"
refuse(){ GATE_VERDICT=2; echo "⛔ REFUSED-TO-GRADE(2): $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "scrip not built at $SCRIP"
[ -f "$P/ALL.pl" ] && [ -f "$P/ALL.ref" ] || refuse "rungs suite not found at $P (want ALL.pl + ALL.ref)"
W="$(mktemp -d)" || refuse "mktemp failed"
# ⛔⭐⭐ A REFUSAL MUST NOT DESTROY THE EVIDENCE NEEDED TO DIAGNOSE THE REFUSAL. Measured on this gate's own
# first band run: it refused on a key-set mismatch and then deleted its mktemp workdir on the way out, so the
# per-entry records that would have explained the mismatch were gone before I could read them. That is the ceo's
# exclusion-filter shape (CEO-1019 retraction) inside my own file -- THE MOTION THAT REMOVED THE NOISE REMOVED
# THE ANSWER WITH IT, and no instrument can report that, because the report is what was deleted.
# So: green cleans up, ANYTHING ELSE KEEPS THE WORKDIR AND PRINTS WHERE IT IS.
GATE_VERDICT=2
_cleanup(){ if [ "$GATE_VERDICT" = 0 ]; then rm -rf "$W"; else echo "⭐ EVIDENCE KEPT at $W (per-arm .raw harness output, .db progress rows, .tsv per-entry outcomes, .keys, d.* diffs) -- a refusal that deletes its own evidence cannot be diagnosed."; fi; }
trap _cleanup EXIT
# ⭐ THE ARMS SHARE ONE PINNED BINARY FINGERPRINT ON PURPOSE. The harness refuses its own board if ./scrip or
# libscrip_rt.so moves mid-run; pinning S4E_BIN_AT_START across ALL arms extends that guarantee to the SET, so a
# rebuild between arms cannot pass itself off as an arena or stress effect. This is the REBASE-BASELINE
# COROLLARY in binary form: a before/after pair is a measurement only if both arms are the same tree.
S4E_BIN_AT_START="$(cd "$ROOT" && python3 -c 'import sys; sys.path.insert(0, "../harness/scripts"); import util_progress_append as p; print(p.bin_fingerprint().strip())' 2>/dev/null)"
[ -n "$S4E_BIN_AT_START" ] || refuse "could not fingerprint the binary -- no pinned baseline, so no comparable set"
export S4E_BIN_AT_START
echo "TREE SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null) corpus=$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null) binary=$S4E_BIN_AT_START"
run_arm(){ # $1 = tag
  local tag="$1" k boards
  local fn="${tag/:/_}"
  : > "$W/$fn.db"; : > "$W/$fn.raw"; : > "$W/$fn.shardrc"
  for k in $(seq 1 "$SHARDS"); do
    _before=$(wc -l < "$W/$fn.db")
    ( case "$tag" in
        control)  export SCRIP_HEAP_MB="$CONTROL_MB"; unset SCRIP_GC_STRESS ;;
        arena)    unset SCRIP_HEAP_MB SCRIP_GC_STRESS ;;
        stress:*) unset SCRIP_HEAP_MB; export SCRIP_GC_STRESS="${tag#stress:}" TIMEOUT="$STRESS_TIMEOUT" ;;
        *) exit 9 ;;
      esac
      S4E_PROGRESS_DB="$W/$fn.db" timeout -k 5 "$SHARD_TIMEOUT" python3 "$HERE/corpus_suite_harness.py" run \
        "$P/ALL.pl" "$P/ALL.ref" --lang prolog --modes m3,m4 --shard "$k/$SHARDS" ) \
      >> "$W/$fn.raw" 2>&1
    # ⛔⭐⭐ THE HONEST QUESTION IS "DID THIS SHARD RECORD ANYTHING", NOT "WHAT WAS ITS rc" -- and this gate got
    # that wrong twice in one sitting, in opposite directions. First it DISCARDED the shard rc entirely, and a
    # shard whose rows never landed showed up much later as an unexplained population mismatch. Then it refused
    # on ANY non-zero rc -- which is WRONG, because the harness exits 1 whenever a board merely CONTAINS REDS,
    # so that check would refuse every honest run of a suite that is not already perfect. ⭐ rc CONFLATES "this
    # board has failing entries" with "this board did not happen", and no amount of care about rc separates them.
    # WHAT ACTUALLY SEPARATES THEM IS THE RECORD ITSELF: count the progress rows before and after each shard.
    # A shard that added ZERO rows did not happen, whatever it printed and whatever it exited.
    # MEASURED WHY THIS MATTERS (hq_prolog, 2026-09-20): a shard printed a complete healthy board -- total=36
    # m3_pass=34 m3_fail=2, 95.56 s against a 5400 s bound -- and appended NOTHING, because corpus_suite_harness.py
    # prints SUITE_BOARD BEFORE it calls _progress_record and the record refused ("THE GROUND MOVED UNDER THIS RUN
    # (scrip <a> -> <b>)" -- the pinned ground is the REPO SHA, not only the binary, and I had committed while the
    # board was grading). The signature is a complete-looking boards=N beside a short per-entry set, and NOTHING
    # says so: a board-summing consumer sees a full denominator, a per-entry consumer sees a short one, and
    # neither can see that the other disagrees.
    _src=$?; _after=$(wc -l < "$W/$fn.db"); _added=$((_after - _before))
    echo "$k $_src $_added" >> "$W/$fn.shardrc"
    case "$_src" in 0|1) ;; 124) echo "SHARD-TIMEOUT arm=$tag shard=$k/$SHARDS rc=124 -- SHARD_TIMEOUT ${SHARD_TIMEOUT}s fired" ;;
                    *) echo "SHARD-REFUSED arm=$tag shard=$k/$SHARDS rc=$_src (rc=2 is could-not-measure; rc=0/1 are both real boards, 1 meaning the board has reds)" ;; esac
    [ "$_added" -gt 0 ] || echo "SHARD-RECORDED-NOTHING arm=$tag shard=$k/$SHARDS rc=$_src -- it added 0 progress rows, so whatever it printed, this shard did not happen"
  done
  # ⛔ REFUSE ON A SHARD THAT RECORDED NOTHING -- never on a shard that merely had reds.
  _bad=$(awk '$3==0' "$W/$fn.shardrc" | wc -l)
  [ "$_bad" -eq 0 ] || { echo "---- shard  rc  rows_added ----"; cat "$W/$fn.shardrc"; \
    refuse "$tag arm had $_bad shard(s) record ZERO rows -- their boards printed and still sum, so this arm reads complete while its per-entry set is short. Settle the tree (pull, rebuild, push, clean) and re-run: the pinned ground is the REPO SHA, so a commit under a running board costs exactly the shard that straddles it."; }
  boards=$(grep -c '^SUITE_BOARD ' "$W/$fn.raw" || true)
  # ⛔ THE WHOLE HARNESS OUTPUT IS KEPT AND QUOTED ON A REFUSAL. Piping into `grep SUITE_BOARD` discards the ONE
  # RUNNER refusal, the likeliest reason a shard printed no board -- an honest refusal naming nothing actionable
  # (hq_B's lesson, carried on test_gate_pl_rungs_board_floor.sh).
  [ "$boards" -eq "$SHARDS" ] || { echo "---- $tag arm, last 40 lines ----"; tail -40 "$W/$fn.raw"; \
    refuse "$tag arm printed $boards of $SHARDS SUITE_BOARD lines -- no verdict is possible from a short count"; }
  [ -s "$W/$fn.db" ] || refuse "$tag arm recorded no progress rows -- nothing to compare per entry"
  # columns are util_progress_append.COLUMNS: 8=program 9=mode 10=outcome
  awk -F'\t' 'NR>1 && $8!="" {print $8"\x1f"$9"\t"$10}' "$W/$fn.db" | sort -u > "$W/$fn.tsv"
  echo "ARM $tag boards=$boards pairs=$(wc -l < "$W/$fn.tsv") $(grep -h '^ARENA ' "$W/$fn.raw" | head -1 | cut -c1-60)"
}
# ⛔⭐⭐ DID THE POPULATION ACTUALLY COLLECT? -- hq_snocone design, 2026-09-20, and it VOIDED THIS GATE OWN FIRST
# CLEAN READING. They measured their whole rung suite at SCRIP_HEAP_MB=1 reading 336/336 with collectors=0/336: the
# tiny arena NEVER COLLECTS over it, and the board prints arena_mb=1 in its verdict line while meaning nothing by
# it. Their general form: A SUITE-TABLE CELL THAT NAMES THE ARENA IS NOT THEREBY A READING OF THE COLLECTOR -- a
# reader then draws a collector conclusion from a CORPUS FACT, which is worse than no cell at all, because an
# unlabelled number invites a question and a labelled one closes it.
# MEASURED FOR PROLOG (hq_prolog, SCRIP b300ee332): arena 1 MB, NO stress plant, [GC-WALK] lines under
# SCRIP_GC_MAPS=1 over the 23 benchmark kernels read COLLECTORS 4, NON-COLLECTORS 19. The tiny arena decides the
# collector question for SEVENTEEN PERCENT of that population, so an arena-only arm at stress 0 measures the
# CORPUS, not the collector.
# ⛔ THE INSTRUMENT IS LANGUAGE-DEPENDENT AND ITS ZERO IS THE DANGEROUS READING: hq_snocone arm counts [ZGC]
# regeneration lines, and THAT COUNTER READS ZERO FOR PROLOG IN EVERY CONFIGURATION -- including one where
# [GC-WALK] shows the collector ran 8001 times. A seat copying it across languages gets a clean zero FOR THE
# WRONG REASON and the output cannot tell the two apart. Hence the POSITIVE CONTROL below: this probe must show
# the counter FIRING before a zero anywhere else may be read as "did not collect".
collect_probe(){ # $1 = SCRIP_HEAP_MB or empty (empty = compiled default, currently GC_HEAP_KB=128 per CEO-1095), $2 = SCRIP_GC_STRESS -> prints the [GC-WALK] count
  ( [ -n "$1" ] && export SCRIP_HEAP_MB="$1"
    export SCRIP_GC_MAPS=1 SCRIP_GC_STRESS="$2"
    timeout -k 5 120 "$SCRIP" "$W/probe.pl" < /dev/null 2>&1 >/dev/null | grep -c '^\[GC-WALK\]' || true )
}
printf ':- initialization(main).\nmk(0,[]) :- !.\nmk(N,[N|T]) :- M is N-1, mk(M,T).\nmain :- mk(2000,L), length(L,X), write(X), nl.\n' > "$W/probe.pl"
pos=$(collect_probe "" 1)
[ "${pos:-0}" -gt 0 ] || refuse "POSITIVE CONTROL FAILED: [GC-WALK] counted 0 at the compiled default arena stress 1, where the collector certainly runs. The decidability instrument is not reporting on this tree, so a zero anywhere below would be uninterpretable -- and an uninterpretable zero reported as 'did not collect' is exactly the false clean this arm exists to prevent."
echo "DECIDABILITY positive-control [GC-WALK]=$pos at the compiled default arena (GC_HEAP_KB, currently 128 KB per CEO-1095), stress=1 -- the counter fires, so a zero below is a MEASURED zero"
for _a in $ARMS; do
  case "$_a" in control) _mb="$CONTROL_MB"; _st=0 ;; arena) _mb=""; _st=0 ;; stress:*) _mb=""; _st="${_a#stress:}" ;; esac
  _w=$(collect_probe "$_mb" "$_st")
  echo "DECIDABILITY arm=$_a arena=${_mb:-compiled-default} stress=${_st} probe_gc_walks=${_w}$([ "${_w:-0}" -eq 0 ] && echo '  ⛔ THIS ARM DOES NOT COLLECT -- any green from it is a statement about the CORPUS, not the collector')"
  case "$_a" in stress:*) [ "${_w:-0}" -gt 0 ] || refuse "arm $_a produced ZERO collections on the probe -- a stress arm that does not collect cannot report on the collector, and a green from it would be the false clean CONDITION 1 exists to prevent" ;; esac
done
for a in $ARMS; do run_arm "$a"; done
case "$ARMS" in *control*) ;; *) refuse "the control arm is not in ARMS -- there is nothing to diff against";; esac
rc=0; inconclusive=0; total_div=0; vanished=0
for a in $ARMS; do
  [ "$a" = control ] && continue
  cut -f1 "$W/control.tsv" | sort -u > "$W/c.keys"; cut -f1 "$W/${a/:/_}.tsv" | sort -u > "$W/${a/:/_}.keys"
  # ⛔⭐ VANISHED IS A RESULT, NOT AN UNMEASURABLE COMPARISON -- and this run taught me that, not reasoning.
  # The first cut REFUSED here on any key-set mismatch, on the rule that a diff across unequal populations is not
  # a measurement. That rule is right and this is not its case: my stress:16 arm graded 975 pairs against control's
  # 1043, so SIXTY-EIGHT PAIRS DID NOT COME BACK AT ALL -- not wrong, not hung, ABSENT from the record, while all
  # 16 shards still printed their SUITE_BOARD lines. An entry present in control and ABSENT under stress IS a
  # result, and a blanket refusal throws away the sixty-eight NAMES, which are the only part worth having. That is
  # this gate's own name-them-do-not-count-them rule failing one level up: it counted the mismatch and refused.
  comm -23 "$W/c.keys" "$W/${a/:/_}.keys" | sed 's/\x1f/ mode=/' | sed "s/^/VANISHED /;s/$/ (graded in control, ABSENT under $a)/" > "$W/v.${a/:/_}"
  comm -13 "$W/c.keys" "$W/${a/:/_}.keys" | sed 's/\x1f/ mode=/' | sed "s/^/APPEARED /;s/$/ (ABSENT in control, graded under $a)/" >> "$W/v.${a/:/_}"
  nv=$(wc -l < "$W/v.${a/:/_}")
  [ "$nv" -eq 0 ] || { echo "---- ENTRIES THAT CHANGED EXISTENCE under $a (named, never counted) ----"; cat "$W/v.${a/:/_}"; }
  join -t$'\t' -j1 "$W/control.tsv" "$W/${a/:/_}.tsv" > "$W/j.${a/:/_}"
  awk -F'\t' -v arm="$a" '{split($1,k,"\x1f"); if ($2!=$3) printf "%s %s mode=%s control=%s %s=%s\n", ($3=="HANG" && $2!="HANG" ? "INCONCLUSIVE-SLOW" : "DIVERGENT"), k[1], k[2], $2, arm, $3}' "$W/j.${a/:/_}" | sort > "$W/d.${a/:/_}"
  nd=$(grep -c '^DIVERGENT ' "$W/d.${a/:/_}" || true); ni=$(grep -c '^INCONCLUSIVE-SLOW ' "$W/d.${a/:/_}" || true)
  np=$(wc -l < "$W/j.${a/:/_}")
  echo "---- AXIS $a vs control: $np pair(s) compared ----"
  [ "$nd" -eq 0 ] && [ "$ni" -eq 0 ] && echo "(no movement)" || cat "$W/d.${a/:/_}"
  echo "CENSUS pl-rungs-axis axis=$a pairs=$np divergent=$nd inconclusive=$ni vanished=$nv want divergent=0 inconclusive=0 vanished=0"
  total_div=$((total_div+nd)); inconclusive=$((inconclusive+ni)); vanished=$((vanished+nv))
done
echo "---- PRE-EXISTING REDS (identical in EVERY arm -- completeness debt, NOT this gate's verdict) ----"
awk -F'\t' '$2!="PASS" && $2!="XFAIL" && $2!="SKIP" && $2!="OUTSIDE" {split($1,k,"\x1f"); printf "PRE-EXISTING-RED %s mode=%s outcome=%s\n", k[1], k[2], $2}' "$W/control.tsv" | sort
if [ "$total_div" -ne 0 ]; then
  echo "⛔ RESULT: FAIL -- $total_div (entry,mode) pair(s) CHANGED ANSWER against the control arm, each named above with its axis."
  echo "   Named, not counted: a pass total would have hidden every one of them, and a swap would have read identical."
  rc=1
fi
if [ "$vanished" -ne 0 ]; then
  echo "⛔ RESULT: REFUSE(2) -- $vanished (entry,mode) pair(s) CHANGED EXISTENCE between arms, each NAMED above."
  echo "   An entry that vanishes under stress is in NEITHER the pass set nor the wrong-answer set, so a name set built"
  echo "   by diffing outcomes is blind to it BY CONSTRUCTION. Find out why before reading any verdict on this arm."
  GATE_VERDICT=2; exit 2
fi
if [ "$inconclusive" -ne 0 ]; then
  echo "⛔ RESULT: REFUSE(2) -- $inconclusive pair(s) moved ONLY into HANG, which a timeout cannot tell from slowness."
  echo "   Raise STRESS_TIMEOUT (now ${STRESS_TIMEOUT}s) and re-run those entries, or record the duration. Never counted as a defect, never dropped."
  GATE_VERDICT=2; exit 2
fi
[ "$rc" -eq 0 ] && { echo "✅ RESULT: PASS -- every arm answers identically to control, per entry, BY ORACLE DIFF against ALL.ref."; \
  echo "   Axes varied: window (control=${CONTROL_MB} MB vs the compiled tiny default) and poll set, as a BAND: SCRIP_GC_STRESS in {${STRESS_BAND}}. Prolog's rungs does not change its answer under collection."; }
GATE_VERDICT=$rc; exit $rc
