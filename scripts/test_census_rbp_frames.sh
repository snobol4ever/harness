#!/usr/bin/env bash
# test_census_rbp_frames.sh -- GOAL-RBP-EARN EARN-2 (2026-08-12/13 s48): re-cut from raw
# frame counting (former GOAL-PASSTHRU-RBP-ERAD PT-0 instrument, Lon directive
# 2026-08-09) to the TWO DEBTS the RUNGS section names: UNEARNED (an establishment
# whose owning construct's classifier says NEVER) and OWED (classifier says
# ALWAYS/hazard-conditional, nothing established). "unearned==0 && owed==0" is the
# ratchet from here, not "frames==0" -- read GOAL-RBP-EARN.md's RUNGS/EARN-2 entry
# before touching this file. Old region-count logic KEPT (still needed for the
# ESTABLISHED side of the debt computation) but is no longer the top-line number.
#
# ⛔ PREREQUISITE LANDED THIS SESSION (SCRIP e73f66b4): frame_need_of()'s diagnostic
# (SCRIP_EARN_DIAG=1, EARN-1 s47) was wired to a choke (bb_prepare) that NONE of its 5
# classified op-kinds ever reached -- [EARN] need=1 was dead code before this fix (5x
# `bb_prepare(nd);` inserted in emit.cpp's IR_MATCH_ARBNO / _FENCE1 / _ASSIGN_{IMM,
# COND,SAVE} case-arms). Byte-identical proven first (crosscheck/patterns 122/122,
# library/probe_reference/bb 14/14) before this script was written against it. If the NEED column below
# reads all-zero on a fresh clone, that fix regressed -- MONITOR-FIRST: do not silently
# reinterpret an all-zero column as "no hazards exist in the corpus".
#
# METHOD
#  NEED side: `SCRIP_EARN_DIAG=1 scrip --compile FILE` (m4). m3 spot-checked per file
#    (scrip --run, same env) and diffed against m4's diag stream -- 0 divergences
#    expected, since the two modes are a 1:1 emission contract by design (PLAN.md
#    architecture); a nonzero divergence count below is itself a finding, not noise.
#    stderr parsed for "[EARN] op=N need=M haz=H ..." lines. N -> name via a table this
#    script DERIVES FRESH FROM IR.h EVERY RUN (never a baked-in table that could go
#    silently stale if the enum is reordered) and refuses to run if any of the 5 names
#    it needs aren't found.
#  ESTABLISHED side: unchanged PT-0 region-label scan (mov rbp,rsp classed by enclosing
#    label prefix) on regenerated mode-4 .s (HONEST CURRENT per the artifact-truth law
#    -- NOT a pinned golden; falls back to a fresh compile if no committed .s exists).
#
#  OWED     = NEED tally for {ARBNO, ASSIGN_IMM, ASSIGN_COND, ASSIGN_SAVE}. FENCE1
#             EXCLUDED (see KEEPER CLASS below). None of the four counted kinds have
#             ANY per-node established mechanism today (ARBNO's old carve died at
#             DEL-T1 -- s46 hand-check: "ARBNO interior frameless post-D-1"; ASSIGN_*
#             never had one), so every firing is unpaid by construction.
#  UNEARNED = PAT-BLOB-class established count ONLY (T1-T3 deletion-target remnants:
#             BLOB-GRANT rbp pin / CLASS D {res,rbp} / legacy in-blob ARBNO rebase).
#  KEEPER CLASS (MAIN + AB-ACT established counts) reported SEPARATELY, counted toward
#             NEITHER debt: {STATEMENT, FUNCTION, MATCH_BEGIN, FENCE1} per the DESIGN OF
#             RECORD's licensed set; EARN-8 explicitly defers their re-examination to a
#             standalone Lon ruling -- scoring them as UNEARNED here would silently
#             answer a question EARN-8 hasn't. ⛔ KNOWN GAP: MAIN-class label scanning
#             cannot distinguish STATEMENT's establishment from FENCE1's -- both land in
#             the same unlabeled main: block. FENCE1's EARNED status is ASSERTED from
#             the design doc (own explicit LEAVE mechanism, bb_match_fence1.cpp) plus
#             its unconditional need=1, not independently proven by per-construct
#             correlation -- the [EARN] line carries no node id to prove it directly.
#             Does not block this rung: FENCE1 sits in neither debt column either way.
#  m3 (BINARY in-process) ESTABLISHED side: NOT INSTRUMENTED. Mode-3 JIT-compiles
#             directly into process memory with no persisted artifact; checked for an
#             existing tool first (test_census_wreg_artifacts.sh's objdump target is
#             libscrip_rt.so, the fixed runtime, not per-program JIT'd code -- doesn't
#             transfer). m4 stands in for both modes' ESTABLISHED count, licensed by the
#             product's own 1:1 mode contract (a separately-gated house law). A real m3
#             probe (gdb JIT-region disasm) is follow-up work, flagged not assumed away.
#
# RATCHET: unearned==0 && owed==0 from here. owed is EXPECTED to be LARGE today and to
# RISE further as EARN classification coverage improves (s29 phase note) -- that is the
# goal succeeding, not regressing.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
CORPUS="${1:-$S4E/corpus}"
# library/probe_reference/bb's loose .sno files converted to suite format 2026-08-28 (probe-consolidate-bb, LON-20260828
# total conversion) -- this DIR now contributes 0 by construction, same as `feat`'s drop under
# tests-consolidate-snobol4-loose. EXPECTED, not a regression; override via EARN2_DIRS if the suite
# entries (tests/snobol4/probe/bb*.sno) need to rejoin this census.
DIRS="${EARN2_DIRS:-crosscheck/patterns library/probe_reference/bb tests/snobol4/probe_loose demo benchmarks/snobol4}"   # re-pointed (ceo s283h): probe/earn0's loose files are converted into suites; probe_loose holds the residual loose witnesses

if [ ! -x "$SCRIP" ]; then echo "SKIP  scrip not built: $SCRIP"; exit 0; fi

IRH="$ROOT/src/ir/IR.h"; [ -f "$IRH" ] || { echo "REFUSE(2): $IRH is missing -- the IR header moved again; repoint this census (until 2026-09-28 it read a retired directory, failed to open it and blamed the enum)"; exit 2; }
OPTAB=$(mktemp)
awk '
/^typedef enum \{/ {inenum=1; n=0; next}
inenum && /^\} /  {inenum=0}
inenum {
  line=$0; gsub(/\/\*.*$/,"",line); gsub(/^[ \t]+/,"",line); gsub(/,.*/,"",line);
  if (line ~ /^IR_[A-Za-z0-9_]+$/) { print n" "line; n++ }
}' "$IRH" > "$OPTAB"
ARBNO_OP=$(awk '$2=="IR_MATCH_ARBNO"{print $1}' "$OPTAB")
FENCE1_OP=$(awk '$2=="IR_MATCH_FENCE1"{print $1}' "$OPTAB")
IMM_OP=$(awk '$2=="IR_MATCH_ASSIGN_IMM"{print $1}' "$OPTAB")
COND_OP=$(awk '$2=="IR_MATCH_ASSIGN_COND"{print $1}' "$OPTAB")
SAVE_OP=$(awk '$2=="IR_MATCH_ASSIGN_SAVE"{print $1}' "$OPTAB")
rm -f "$OPTAB"
for v in ARBNO_OP FENCE1_OP IMM_OP COND_OP SAVE_OP; do
  eval "val=\$$v"
  [ -n "$val" ] || { echo "FATAL  could not derive $v from IR.h -- enum shape changed, fix this script's awk pass"; exit 2; }
done
echo "opcode table (derived this run): ARBNO=$ARBNO_OP FENCE1=$FENCE1_OP ASSIGN_IMM=$IMM_OP ASSIGN_COND=$COND_OP ASSIGN_SAVE=$SAVE_OP"

ASMAWK='
/^[A-Za-z_.$][A-Za-z0-9_.$]*:/ { lbl=$1; sub(/:.*/,"",lbl);
  if (lbl ~ /^\.LTp[0-9]/) cls="PAT-BLOB"; else if (lbl ~ /_act_/) cls="AB-ACT"; else if (lbl ~ /^proc_/) cls="PROC"; else if (lbl ~ /^main/) cls="MAIN"; }
/mov +rbp, rsp/ { est[cls]++ }
END { print "EST_PATBLOB " (est["PAT-BLOB"]+0); print "EST_ABACT " (est["AB-ACT"]+0); print "EST_PROC " (est["PROC"]+0); print "EST_MAIN " (est["MAIN"]+0) }'

T_ARBNO=0; T_FENCE1=0; T_IMM=0; T_COND=0; T_SAVE=0
T_PATBLOB=0; T_ABACT=0; T_PROC=0; T_MAIN=0
T_DIVERGE=0; T_FILES=0; T_M3CRASH=0

for d in $DIRS; do
  D="$CORPUS/$d"; [ -d "$D" ] || { echo "$d: MISSING, skip"; continue; }
  n=$(ls "$D"/*.sno 2>/dev/null | wc -l); [ "$n" -gt 0 ] || { echo "$d: no .sno"; continue; }
  echo "=== $d ($n files) ==="
  d_arbno=0; d_fence1=0; d_imm=0; d_cond=0; d_save=0
  d_patblob=0; d_abact=0; d_proc=0; d_main=0
  for f in "$D"/*.sno; do
    T_FILES=$((T_FILES+1))
    b=$(basename "$f" .sno)
    SCRIP_EARN_DIAG=1 timeout -k 5 15 "$SCRIP" --compile "$f" > /tmp/earn2_fresh.s 2> /tmp/earn2_diag_m4.txt < /dev/null
    SCRIP_EARN_DIAG=1 timeout -k 5 15 "$SCRIP" --run "$f" > /dev/null 2> /tmp/earn2_diag_m3.txt < /dev/null
    m3_rc=$?
    if [ "$m3_rc" != 0 ]; then
      T_M3CRASH=$((T_M3CRASH+1))   # pre-existing mode-3 nondeterminism (verified: identical scatter pre/post this session's fix, repeated-run 0/134/139 on the SAME binary) -- not a diag/classifier signal, not counted as divergence
    elif ! cmp -s /tmp/earn2_diag_m3.txt /tmp/earn2_diag_m4.txt; then
      T_DIVERGE=$((T_DIVERGE+1)); echo "  ⛔ GENUINE DIAG DIVERGE m3 vs m4 (both exited 0): $b"
    fi
    while read -r _tag op_kv need_kv haz_kv _rest; do
      op=${op_kv#op=}; need=${need_kv#need=}
      case "$op" in
        "$ARBNO_OP")  d_arbno=$((d_arbno+need)) ;;
        "$FENCE1_OP") d_fence1=$((d_fence1+need)) ;;
        "$IMM_OP")    d_imm=$((d_imm+need)) ;;
        "$COND_OP")   d_cond=$((d_cond+need)) ;;
        "$SAVE_OP")   d_save=$((d_save+need)) ;;
      esac
    done < /tmp/earn2_diag_m4.txt
    SCAN="$D/$b.s"; [ -f "$SCAN" ] || SCAN=/tmp/earn2_fresh.s
    ESTOUT=$(awk "$ASMAWK" "$SCAN" 2>/dev/null)
    pb=$(echo "$ESTOUT" | awk '/^EST_PATBLOB/{print $2}'); d_patblob=$((d_patblob + ${pb:-0}))
    ab=$(echo "$ESTOUT" | awk '/^EST_ABACT/{print $2}');   d_abact=$((d_abact + ${ab:-0}))
    pc=$(echo "$ESTOUT" | awk '/^EST_PROC/{print $2}');    d_proc=$((d_proc + ${pc:-0}))
    mn=$(echo "$ESTOUT" | awk '/^EST_MAIN/{print $2}');    d_main=$((d_main + ${mn:-0}))
  done
  echo "  NEED  arbno=$d_arbno fence1=$d_fence1 assign_imm=$d_imm assign_cond=$d_cond assign_save=$d_save"
  echo "  EST   PAT-BLOB=$d_patblob AB-ACT=$d_abact PROC=$d_proc MAIN=$d_main"
  T_ARBNO=$((T_ARBNO+d_arbno)); T_FENCE1=$((T_FENCE1+d_fence1))
  T_IMM=$((T_IMM+d_imm)); T_COND=$((T_COND+d_cond)); T_SAVE=$((T_SAVE+d_save))
  T_PATBLOB=$((T_PATBLOB+d_patblob)); T_ABACT=$((T_ABACT+d_abact)); T_PROC=$((T_PROC+d_proc)); T_MAIN=$((T_MAIN+d_main))
done

OWED=$((T_ARBNO + T_IMM + T_COND + T_SAVE))
UNEARNED=$T_PATBLOB

echo ""
echo "================ EARN-2 CENSUS -- files=$T_FILES -- ratchet: unearned==0 && owed==0 ================"
echo "OWED      = $OWED   (arbno=$T_ARBNO  assign_imm=$T_IMM  assign_cond=$T_COND  assign_save=$T_SAVE)"
echo "UNEARNED  = $UNEARNED   (PAT-BLOB established -- T1-T3 deletion-target remnants)"
echo "KEEPER CLASS, not counted, EARN-8 pending: MAIN(STATEMENT/MATCH_BEGIN/FENCE1)=$T_MAIN  AB-ACT(FUNCTION)=$T_ABACT  PROC=$T_PROC"
echo "FENCE1 need=1 total: $T_FENCE1  (asserted EARNED via its own keeper mechanism -- see header correlation-gap note)"
echo "m3/m4 GENUINE diag divergences (both ran clean): $T_DIVERGE  (0 expected)"
echo "m3 nonzero exit (crash, EITHER binary, verified pre-existing + nondeterministic, NOT EARN-related): $T_M3CRASH / $T_FILES  -- see script header + session commit for the ASLR-style repeated-run evidence; flag to Lon for routing, do not chase here"
exit 0
