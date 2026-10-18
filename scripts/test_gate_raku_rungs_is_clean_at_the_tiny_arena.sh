#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_raku_rungs_is_clean_at_the_tiny_arena.sh -- RAKU'S ITEM 4 OF THE GC COMMITMENT (hq_raku, row
# raku-gc-zero-gradings-lost-to-the-collector-across-the-arena-and-stress-axes-named-not-counted; ceo CEO-1039/1040,
# TENET). GOAL: "ZERO GRADINGS LOST TO THE COLLECTOR" -- the arena and stress axes must cost this lane nothing,
# proven per entry, on a named tree, with the instrument shown able to catch a real divergence first.
#
# ⛔ THIS IS THE RAKU INSTANCE OF THE SHARED SHAPE, NOT A NEW DESIGN. Ported from
# test_gate_pl_rungs_is_clean_at_the_tiny_arena.sh (SCRIP 46f348488, hq_prolog, built on hq_snobol4's catch that
# an arena-only band reads GREEN over an arena-insensitive stress-sensitive class). Same per-entry oracle-diff
# shape, same decidability positive-control, same VANISHED/DIVERGENT/INCONCLUSIVE-SLOW vocabulary. Nothing here
# was re-derived; only the language, the suite path and the declared axis points changed.
#
# ⛔⭐⭐ WHY THIS LANE IN PARTICULAR CANNOT SKIP THIS GATE. Raku is where the class was FOUND: the rungs at
# SCRIP_HEAP_MB=1 SCRIP_GC_STRESS=16 lost 65 gradings over 36 distinct programs against the same tree and binary
# with stress unset -- every one exit 0, no diagnostic, a plausible wrong answer (row
# raku-gc-thirty-six-programs-return-a-silently-wrong-answer-under-forced-collection..., DONE). TWO CAUSES, BOTH
# CURED AT SCRIP a7ba722b3: a C LOCAL (`__rk_arr_map`'s accumulator) held across a re-entry into emitted code, and
# a C STATIC TABLE (`gram_reg[]`) of heap strings no roots function visited -- NEITHER was an unmapped slot, so no
# per-slot census would ever have found either. This gate is what turns that one-off finding into a standing,
# re-runnable instrument, so a future landing that reopens either class (or a third one like it) is caught the
# same day rather than the same month.
#
# ⛔⭐ TWO AXES, BECAUSE ONE AXIS READS GREEN OVER THE CLASS -- hq_snobol4's catch, inherited via the Prolog gate.
# The cured defects here were ALSO arena-INDEPENDENT BY CONSTRUCTION (a C local and a C static table are
# unreachable at any arena size), so an arena-only A/B at stress=0 would have read clean on this exact class and
# meant nothing -- measured in this row's own baton, not assumed. Confirmed in the mechanism: gc_heap.c
# c_rt_gcheap_alloc reads SCRIP_GC_STRESS once into a static and raises g_gc_pending every N allocations,
# orthogonal to window size; unset means zero forced collections.
#   ARM control  : shipped window (512 MB), no forced collection -- the baseline every other arm is diffed against
#   ARM arena    : SCRIP_HEAP_MB=1, no forced collection          -- does a SMALL WINDOW alone change an answer
#   ARM stress:N : SCRIP_HEAP_MB=1 + SCRIP_GC_STRESS=N             -- does COLLECTING OFTEN change an answer
# ⛔ MEASURED, NOT ASSUMED: SCRIP_GC_STRESS=0 and SCRIP_GC_STRESS unset are THE SAME CONFIGURATION.
# gc_heap.c:245 reads `stress_n = e ? atol(e) : 0` and :246 gates the plant on `stress_n > 0`, so an explicit 0
# and an absent env var both leave the plant permanently off. The task's declared stress point "0" is therefore
# not a missing eighth arm -- it IS the `arena` arm above, and this file does not spend a redundant run on it.
#
# ⛔⭐⭐ A STRESS BAND, NEVER A STRESS POINT, AND SPAN BOTH ENDS -- ceo CEO-1024. hq_raku's own map-family window
# was 1-6 and INVISIBLE at >=8 while the grammar family was wrong at every point above 0; hq_snobol4 has a witness
# red at m4 stress 25 while green at 10/12/16/20/35/50. Whatever a band finds is a lower bound, never a
# population. THE DECLARED BAND HERE IS THE TASK'S OWN AXIS LIST (CEO-1039/1040), not a locally chosen one:
# stress in {1,3,5,8,16} plus the {0 == arena} point above.
#
# ⛔ A TIMEOUT IS NOT A DIVERGENCE. Under stress a correct program can run orders of magnitude slower; rc=124
# cannot distinguish "needs longer" from "never finishes". The stress arm raises the harness per-program TIMEOUT,
# and a pair whose ONLY movement is into HANG is reported INCONCLUSIVE-SLOW and REFUSES rc=2 -- never counted as
# a collector defect, never dropped to keep the gate green.
#
# ⛔ NOT WIRED INTO `make test`, ON PURPOSE -- seven full rungs boards is ~7x a single board, and TENET
# condition 2 is that the blocking set is the shared resource that does not scale with seats. This is a
# DELIBERATE gate: the owning row runs it and a landing claiming raku's GC share is clean cites its output.
#
# ⛔ REFUSES rc=2 RATHER THAN REPORTING A CLEAN IT COULD NOT MEASURE: no binary, no suite, an arm that printed no
# SUITE_BOARD line, a shard that recorded zero progress rows, two arms whose entry sets differ (VANISHED/APPEARED,
# named not counted), or an inconclusive HANG. A short count is never a green here.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP:-$ROOT/scrip}"; P="${RK_SUITE_DIR:-$S4E/corpus/tests/raku}"
SHARDS="${SHARDS:-16}"; TINY_MB="${TINY_MB:-1}"
STRESS_BAND="${STRESS_BAND:-1 3 5 8 16}"
STRESS_TIMEOUT="${STRESS_TIMEOUT:-600}"; SHARD_TIMEOUT="${SHARD_TIMEOUT:-5400}"
ARMS="control arena"; for _n in $STRESS_BAND; do ARMS="$ARMS stress:$_n"; done; ARMS="${ARMS_OVERRIDE:-$ARMS}"
refuse(){ GATE_VERDICT=2; echo "⛔ REFUSED-TO-GRADE(2): $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "scrip not built at $SCRIP"
[ -f "$P/ALL.raku" ] && [ -f "$P/ALL.ref" ] || refuse "rungs suite not found at $P (want ALL.raku + ALL.ref)"
W="$(mktemp -d)" || refuse "mktemp failed"
# ⛔⭐⭐ A REFUSAL MUST NOT DESTROY THE EVIDENCE NEEDED TO DIAGNOSE THE REFUSAL (ported lesson, hq_prolog).
GATE_VERDICT=2
_cleanup(){ if [ "$GATE_VERDICT" = 0 ]; then rm -rf "$W"; else echo "⭐ EVIDENCE KEPT at $W (per-arm .raw harness output, .db progress rows, .tsv per-entry outcomes, .keys, d.* diffs) -- a refusal that deletes its own evidence cannot be diagnosed."; fi; }
trap _cleanup EXIT
# ⭐ THE ARMS SHARE ONE PINNED BINARY FINGERPRINT ON PURPOSE -- a rebuild between arms cannot pass itself off as
# an arena or stress effect (the exact race that refused hq_raku's own shipped-arena arm on this row's history).
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
        control)  unset SCRIP_HEAP_MB SCRIP_GC_STRESS ;;
        arena)    export SCRIP_HEAP_MB="$TINY_MB"; unset SCRIP_GC_STRESS ;;
        stress:*) export SCRIP_HEAP_MB="$TINY_MB" SCRIP_GC_STRESS="${tag#stress:}" TIMEOUT="$STRESS_TIMEOUT" ;;
        *) exit 9 ;;
      esac
      S4E_PROGRESS_DB="$W/$fn.db" timeout -k 5 "$SHARD_TIMEOUT" python3 "$HERE/corpus_suite_harness.py" run \
        "$P/ALL.raku" "$P/ALL.ref" --lang raku --modes m3,m4 --shard "$k/$SHARDS" ) \
      >> "$W/$fn.raw" 2>&1
    # ⛔⭐⭐ "DID THIS SHARD RECORD ANYTHING", NOT "WHAT WAS ITS rc" (ported lesson, hq_prolog -- rc conflates
    # "this board has failing entries" with "this board did not happen"; only the progress-row count separates them.
    _src=$?; _after=$(wc -l < "$W/$fn.db"); _added=$((_after - _before))
    echo "$k $_src $_added" >> "$W/$fn.shardrc"
    case "$_src" in 0|1) ;; 124) echo "SHARD-TIMEOUT arm=$tag shard=$k/$SHARDS rc=124 -- SHARD_TIMEOUT ${SHARD_TIMEOUT}s fired" ;;
                    *) echo "SHARD-REFUSED arm=$tag shard=$k/$SHARDS rc=$_src (rc=2 is could-not-measure; rc=0/1 are both real boards, 1 meaning the board has reds)" ;; esac
    [ "$_added" -gt 0 ] || echo "SHARD-RECORDED-NOTHING arm=$tag shard=$k/$SHARDS rc=$_src -- it added 0 progress rows, so whatever it printed, this shard did not happen"
  done
  _bad=$(awk '$3==0' "$W/$fn.shardrc" | wc -l)
  [ "$_bad" -eq 0 ] || { echo "---- shard  rc  rows_added ----"; cat "$W/$fn.shardrc"; \
    refuse "$tag arm had $_bad shard(s) record ZERO rows -- their boards printed and still sum, so this arm reads complete while its per-entry set is short. Settle the tree (pull, rebuild, push, clean) and re-run: the pinned ground is the REPO SHA, so a commit under a running board costs exactly the shard that straddles it."; }
  boards=$(grep -c '^SUITE_BOARD ' "$W/$fn.raw" || true)
  [ "$boards" -eq "$SHARDS" ] || { echo "---- $tag arm, last 40 lines ----"; tail -40 "$W/$fn.raw"; \
    refuse "$tag arm printed $boards of $SHARDS SUITE_BOARD lines -- no verdict is possible from a short count"; }
  [ -s "$W/$fn.db" ] || refuse "$tag arm recorded no progress rows -- nothing to compare per entry"
  # columns are util_progress_append.COLUMNS: 8=program 9=mode 10=outcome
  awk -F'\t' 'NR>1 && $8!="" {print $8"\x1f"$9"\t"$10}' "$W/$fn.db" | sort -u > "$W/$fn.tsv"
  echo "ARM $tag boards=$boards pairs=$(wc -l < "$W/$fn.tsv") $(grep -h '^ARENA ' "$W/$fn.raw" | head -1 | cut -c1-60)"
}
# ⛔⭐⭐ DID THE POPULATION ACTUALLY COLLECT? (ported, hq_snocone design.) A suite-table cell that NAMES the arena
# is not thereby a reading of the collector -- POSITIVE CONTROL first, so a zero below is a MEASURED zero.
collect_probe(){ # $1 = SCRIP_HEAP_MB, $2 = SCRIP_GC_STRESS -> prints the [GC-WALK] count
  SCRIP_GC_MAPS=1 SCRIP_HEAP_MB="$1" SCRIP_GC_STRESS="$2" timeout -k 5 120 "$SCRIP" "$W/probe.raku" < /dev/null 2>&1 >/dev/null | grep -c '^\[GC-WALK\]' || true
}
printf 'my @a; for 1..20000 { @a.push($_) }; say @a.elems;\n' > "$W/probe.raku"
pos=$(collect_probe "$TINY_MB" 1)
[ "${pos:-0}" -gt 0 ] || refuse "POSITIVE CONTROL FAILED: [GC-WALK] counted 0 at arena ${TINY_MB} MB stress 1, where the collector certainly runs. The decidability instrument is not reporting on this tree, so a zero anywhere below would be uninterpretable -- and an uninterpretable zero reported as 'did not collect' is exactly the false clean this arm exists to prevent."
echo "DECIDABILITY positive-control [GC-WALK]=$pos at arena=${TINY_MB}MB stress=1 -- the counter fires, so a zero below is a MEASURED zero"
for _a in $ARMS; do
  case "$_a" in control) _mb=512; _st=0 ;; arena) _mb="$TINY_MB"; _st=0 ;; stress:*) _mb="$TINY_MB"; _st="${_a#stress:}" ;; esac
  _w=$(collect_probe "$_mb" "$_st")
  echo "DECIDABILITY arm=$_a arena=${_mb}MB stress=${_st} probe_gc_walks=${_w}$([ "${_w:-0}" -eq 0 ] && echo '  ⛔ THIS ARM DOES NOT COLLECT -- any green from it is a statement about the CORPUS, not the collector')"
  case "$_a" in stress:*) [ "${_w:-0}" -gt 0 ] || refuse "arm $_a produced ZERO collections on the probe -- a stress arm that does not collect cannot report on the collector, and a green from it would be the false clean ITEM 4 exists to prevent" ;; esac
done
for a in $ARMS; do run_arm "$a"; done
case "$ARMS" in *control*) ;; *) refuse "the control arm is not in ARMS -- there is nothing to diff against";; esac
rc=0; inconclusive=0; total_div=0; vanished=0
for a in $ARMS; do
  [ "$a" = control ] && continue
  cut -f1 "$W/control.tsv" | sort -u > "$W/c.keys"; cut -f1 "$W/${a/:/_}.tsv" | sort -u > "$W/${a/:/_}.keys"
  # ⛔⭐ VANISHED IS A RESULT, NOT AN UNMEASURABLE COMPARISON (ported lesson, hq_prolog's 68 pairs).
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
  echo "CENSUS rk-rungs-axis axis=$a pairs=$np divergent=$nd inconclusive=$ni vanished=$nv want divergent=0 inconclusive=0 vanished=0"
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
  echo "   Axes varied: window (${TINY_MB} MB) and poll set, as a BAND: SCRIP_GC_STRESS in {0 (== arena arm), ${STRESS_BAND}}. Raku's rungs does not change its answer under collection."; }
GATE_VERDICT=$rc; exit $rc
