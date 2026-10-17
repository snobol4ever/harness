#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ZB-VAL-8b GATE (s182, closes s181 FINDING-2026-07-26f HEADLINE 6 "THE FALLBACK IS SILENT").
#
# THE HAZARD: x86_fc_hit(off) returns false when a GRANTED box's flat offset falls outside its own
# fc window, and FR()/FRQ() then QUIETLY emit [rbp+off] instead of [rsp+off-base].  An undersized
# window does not crash and does not emit a wrong address -- it just leaves the box on rbp.  So
# "I converted it" and "it converted" are different facts and nothing in the build distinguished
# them.  Given per-graph flat layout (lt1 and lt2 allocate the SAME construct at different offsets),
# mis-sizing is near-certain at least once as the conversion widens.
#
# WHAT THIS ASSERTS: compile the corpus with SCRIP_FC_AUDIT=1 and count [FC-MISS] events.  A miss is
# emitted by x86_fc_hit exactly when the box IS granted (w>0, base>=0) but the offset misses the
# window -- i.e. precisely the silent fallback, not merely "an rbp reference exists" (ungranted boxes
# legitimately speak rbp; grepping the .s for '[rbp+' cannot tell the two apart, which is why this
# gate reads the COMPILER's own verdict instead of the emitted text).
#
# ================================ s184 CORRECTION -- READ THIS ================================
# The header formerly claimed "BASELINE AT LANDING (s182): 0 misses across 52 demo+feat programs".
# THAT NUMBER WAS NEVER TRUE OF THIS SCRIPT.  Three independent defects made the old headline an
# artifact rather than a measurement, all fixed here:
#
#   (1) TIMEOUT COUNTED AS DATA.  The old body piped `timeout -k 5 20 $SCRIP` straight into grep -c, so
#       the pipeline exit status was grep's and timeout's 124 was DISCARDED.  beauty.sno does not
#       terminate in bounded compile time, so its contribution measured WALL-CLOCK PATIENCE, not the
#       compiler: 3,984 misses @20s -> 26,088 @120s, still killed.  Any "total" including it is
#       unreproducible across machines and across sessions (s183 read ~5,600 total where s184 read
#       5,328 on the identical tree -- same compiler, different truncation point).
#   (2) FAILED COMPILES SCORED AS CLEAN.  A program that emits "no code generated" contributes zero
#       misses and was indistinguishable from a program that compiled perfectly.  Two of the 52 were
#       in this state, one of them hiding the single LARGEST miss population in the corpus.
#   (3) INCLUDES NEVER RESOLVED.  demo/expression.sno -INCLUDEs three files that live in
#       tests/snobol4/beauty_suite/.  The gate set no search path, so it silently took defect (2)
#       and scored 0.  With SNO_LIB seeded it compiles clean and reports 11,662 misses -- a
#       population that was invisible for the whole life of the old gate.  (Note REPO-corpus.md
#       documents an include dir demo/inc/ that does not exist in the tree; beauty_suite/ is real.)
#
# MEASURED BASELINE (s184, tree at e5ce9f12+c98ce1c9, deterministic across repeated passes):
#       OK       50 programs   13,006 misses   <-- the ratchet, byte-stable run to run
#       TIMEOUT   1 program    beauty.sno      <-- unbounded compile, QUARANTINED, contributes nothing
#       NOCODE    1 program    f13_eval_code.sno (direct-goto ":< C >" parse defect, see below)
#
# THE GATE IS A RATCHET, NOT A ZERO-ASSERT.  1,344 of those misses sit outside expression.sno and are
# the number s183 measured; the conversion is mid-flight and zero is not yet reachable, so asserting
# 0 would leave the gate permanently red and therefore ignored.  It fails on REGRESSION ABOVE
# BASELINE, and on any NEW timeout / NEW failed compile.  Lower FC_BASELINE as the conversion widens.
#
# ---- RECLASSIFIED (this session): 13,006 WAS 99.1% CORRECT-BY-DESIGN BEHAVIOUR. TRUE RESIDUE = 108 ----
# The counter fired on ANY granted box whose offset left its window, which conflates three events:
#   OWN + full-cell  -> a box with an fc_geom cell addressing its OWN field outside it. THE DEFECT.
#   OWN + window-only-> IR_MATCH_BEGIN. op_fc_wbytes is DOCUMENTED as a partial window (cell-resident
#                       cursor/zeta_mark/zls2_mark at +0/+8/+16; head.end/dcap_mark/incoming_rbp are
#                       "FLAT on both paths -- post-unwind lifetime", read by RELEASE/REPLACE AFTER the
#                       cell dies). Those accesses MUST land on rbp. Counting them made zero unreachable.
#   CROSS            -> the offset belongs to ANOTHER node (op_own_ci is that node's extent end).
#                       Reading a neighbour's flat slot is normal emitter behaviour, never a fallback.
# MEASURED on demo/expression.sno (11,662 of the old 13,006): OWN/full-cell 108 | OWN/HEAD 6,936
# | CROSS 4,618. Corpus-wide the new count is 108 -- i.e. EVERY other program's misses were by-design,
# and s183's 1,344 "non-expression" misses were too. x86_fc_hit now counts only the defect class; its
# RETURN VALUE is untouched, proven by expression.sno's .s being md5-identical across the change.
# ---- SUPERSEDED SAME SESSION: THE RESIDUAL 108 WERE ALSO A MEASUREMENT ARTIFACT. TRUE COUNT = 0 ----
# The 108 were 2 boxes reading +20/+24 past a 16-byte cell.  Tracing them: IR_MATCH_BREAK, result@63792
# + break.cnt/cur@63808, so its storage truly ENDS at 63824 -- but the reads were at 63828/63832, inside
# the NEXT node's result quad.  They are neighbour reads (every consumer reads its operand's slot), not
# this box's own field falling back.  They scored OWN only because op_own_ci said BREAK ran to 63840:
# zls_off() returns e->loff (the SHIFTED locals base for the zls_locals_shifted family) while
# zls_node_bytes() measures from e->off (the RESULT base), so loff+bytes overstates every shifted node's
# end by exactly the shift.  Same base-convention class as the ZLS-CALL-BASE defect.  emit.cpp now
# computes C_i from zls_result_off(); default-port codegen is unaffected (C_i's only other consumer is
# the dormant ZC_PORT_OWNED arm) -- proven by expression.sno's .s staying md5-identical across BOTH
# changes.  Corpus count is now 0 and FC_BASELINE is 0: a real zero-assert at last.
# ---- WHAT ZERO DOES *NOT* MEAN ----
# It means no GRANTED box addresses its OWN field outside its cell.  It does NOT mean the FORTH
# conversion is complete: fc_geom still grants cells to an enumerated registry only, and IR_MATCH_BEGIN
# (570 local fields/160 programs), IR_CALL (405), SEQUENCE (66), DEFER (64), FENCE1 (32), ARBNO (30)
# and VALUE (6) remain unconverted.  Coverage is tracked by fc_geom's list, never by this counter.
# ==============================================================================================
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
cd "$(dirname "$0")/../../SCRIP" || exit 2
SCRIP=${SCRIP:-./scrip}
CORPUS=${CORPUS:-$S4E/corpus/tests/snobol4}
FC_TIMEOUT=${FC_TIMEOUT:-60}
FC_BASELINE=${FC_BASELINE:-0}
# Programs known NOT to compile cleanly.  These are DEFECTS ON RECORD, not exemptions -- each one is
# reported loudly every run.  A program may leave a list only by being fixed; anything arriving in a
# list that is not already named here FAILS the gate.
KNOWN_TIMEOUT="beauty.sno"
KNOWN_NOCODE="f13_eval_code.sno"
[ -x "$SCRIP" ] || { echo "GATE FAIL: no $SCRIP (run: make scrip)"; exit 2; }
export SNO_LIB="$CORPUS/beauty_suite:$S4E/corpus/include:$S4E/corpus/library${SNO_LIB:+:$SNO_LIB}"
tmp=$(mktemp) || exit 2
trap 'rm -f "$tmp" "$tmp.f"' EXIT
n=0
while IFS= read -r f; do
  n=$((n+1))
  err=$(SCRIP_FC_AUDIT=1 timeout -k 5 "$FC_TIMEOUT" "$SCRIP" --compile "$f" 2>&1 >/dev/null); rc=$?
  m=$(printf '%s' "$err" | grep -c '\[FC-MISS\]')
  e=$(printf '%s' "$err" | grep -c 'error:')
  if   [ "$rc" = 124 ]; then cls=TIMEOUT
  elif [ "$e" -gt 0 ];  then cls=NOCODE
  else                       cls=OK
  fi
  printf '%s\t%s\t%s\n' "$cls" "$m" "$(basename "$f")" >> "$tmp"
done < <(find "$CORPUS/demos" "$CORPUS/feat" -name '*.sno' 2>/dev/null | sort)
ok_n=$(awk -F'\t' '$1=="OK"{c++} END{print c+0}' "$tmp")
ok_m=$(awk -F'\t' '$1=="OK"{s+=$2} END{print s+0}' "$tmp")
fail=0
echo "FC silent-fallback events over $ok_n cleanly-compiled program(s): $ok_m   (baseline $FC_BASELINE)"
echo "  scanned $n program(s); timeout ${FC_TIMEOUT}s; miss counts from TIMEOUT programs are excluded as truncation artifacts"
# --- unbounded compiles ------------------------------------------------------------------------
awk -F'\t' '$1=="TIMEOUT"{print $3}' "$tmp" | while IFS= read -r p; do
  case " $KNOWN_TIMEOUT " in
    *" $p "*) echo "  QUARANTINED (known unbounded compile, excluded from the count): $p" ;;
    *)        echo "  NEW TIMEOUT: $p -- did not finish in ${FC_TIMEOUT}s; its miss count is meaningless. GATE FAIL."; echo FAIL >> "$tmp.f" ;;
  esac
done
# --- compiles that produced nothing ------------------------------------------------------------
awk -F'\t' '$1=="NOCODE"{print $3}' "$tmp" | while IFS= read -r p; do
  case " $KNOWN_NOCODE " in
    *" $p "*) echo "  NO CODE GENERATED (known parse defect, scores no misses because nothing compiled): $p" ;;
    *)        echo "  NEW COMPILE FAILURE: $p -- scores 0 misses only because it emitted no code. GATE FAIL."; echo FAIL >> "$tmp.f" ;;
  esac
done
[ -f "$tmp.f" ] && fail=1; rm -f "$tmp.f"
# --- the ratchet -- reported LAST, because a program that drops out of the OK set (new timeout, new
# failed compile) also drops its misses from ok_m.  Reporting "IMPROVED, lower the baseline" off a
# count that shrank because a program stopped compiling would bake the artifact into the baseline --
# the exact class of bug this rewrite exists to kill.  So: advise a lower baseline ONLY on a clean run.
if [ "$ok_m" -gt "$FC_BASELINE" ]; then
  echo "REGRESSION: $ok_m > baseline $FC_BASELINE (+$((ok_m-FC_BASELINE)))"
  awk -F'\t' '$1=="OK" && $2>0 {printf "    %8d  %s\n",$2,$3}' "$tmp" | sort -rn | head -10
  fail=1
elif [ "$ok_m" -lt "$FC_BASELINE" ]; then
  if [ "$fail" -eq 0 ]; then
    echo "IMPROVED: $ok_m < baseline $FC_BASELINE (-$((FC_BASELINE-ok_m))) -- lower FC_BASELINE in this script to lock the win in."
  else
    echo "NOTE: count $ok_m is below baseline $FC_BASELINE ONLY because a program left the OK set above. NOT an improvement; do NOT lower FC_BASELINE."
  fi
fi
if [ "$fail" -ne 0 ]; then
  echo "Re-run one with SCRIP_FC_AUDIT=1 to see each window: SCRIP_FC_AUDIT=1 $SCRIP --compile <prog>.sno >/dev/null"
  echo "GATE FAIL."
  exit 1
fi
echo "OK: no regression above baseline; no new timeouts; no new failed compiles."
