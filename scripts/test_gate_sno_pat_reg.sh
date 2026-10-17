#!/usr/bin/env bash
# test_gate_sno_pat_reg.sh — SNOBOL4 PATTERN-FAMILY REGISTER-CONFORMANCE gate (REG ladder, GOAL-SNOBOL4-BB.md).
#
# The SNOBOL pattern boxes must run on the ratified subject model — Σ=R13 (subject base), δ=R14 (cursor),
# Δ=R15 (length), ζ=R12 (frame) — and must NOT bake the emitter-process global addresses &Σ / &Σlen
# (TEMPLATE_ADDR_SIGMA / TEMPLATE_ADDR_SIGLEN), which are mode-3-in-process-only and block mode-4 relocation.
#
# TWO TIERS (mirrors test_gate_no_vstack.sh / test_gate_no_handencoded_bytes.sh house style):
#   TIER 1 — TEMPLATE_ADDR_SIG* : HARD. Already at ZERO family-wide (the &Σ/&Σlen bake removal is DONE).
#            --strict exits 1 if any reappears. This is the convention-compliance invariant the gate LOCKS.
#   TIER 2 — r10 residue        : HARD (REG-RO landed 2026-06-06). The cursor is r14; the [r10] cursor-MIRROR
#            writes in bb_lit, the shared xa_flat non-frame epilogue's [r10] cursor read (migrated to r14d,
#            TEXT + BINARY), and the push r10 / pop r10 guards around memcmp/strchr are all GONE — call-site
#            16-byte alignment is sub/add rsp,8. Any r10 reappearance in the family fails this gate.
#
# Usage: bash ../harness/scripts/test_gate_sno_pat_reg.sh [--strict]
#   (no --strict) : report both tiers; exit 0 unless TIER 1 is non-zero.
#   --strict      : TIER 1 must be 0 (enforced); TIER 2 still informational until REG-RO lands (see NOTE below).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
strict=0
[ "${1:-}" = "--strict" ] && strict=1

# The SNOBOL pattern family: all bb_match_*.cpp leaves/combinators + the literal matcher bb_lit.cpp, EXCLUDING the
# three statement-level MATCH drivers (bb_match_begin/retry/advance, FIX-5 split-born): head carries the sanctioned
# lea-r10 cursor-mirror, historically outside this glob (RENAME 2026-06-07 bb_pat_*->bb_match_* widened it). (bb_capture
# and bb_arbno no longer exist — capture folded away, ARBNO is bb_match_arb — so they are not listed; a glob is
# used so the set tracks the directory rather than a stale hand-list.)
FAMILY=$(ls src/templates/bb/bb_match_*.cpp src/templates/bb/bb_lit.cpp 2>/dev/null | grep -v 'bb_match_begin\.cpp\|bb_match_retry\.cpp\|bb_match_advance\.cpp')

# strip_comments FILE — code only (so a comment naming a token does not count as a live reference).
strip_comments() { sed -E 's://.*$::' "$1" | perl -0777 -pe 's{/\*.*?\*/}{}gs'; }

# ---- TIER 1: TEMPLATE_ADDR_SIG* (HARD) ----
sig_total=0
sig_report=""
for f in $FAMILY; do
  h=$(strip_comments "$f" | grep -cE 'TEMPLATE_ADDR_SIGMA|TEMPLATE_ADDR_SIGLEN')
  if [ "$h" -gt 0 ]; then sig_total=$((sig_total + h)); sig_report="${sig_report}  ${h}\t${f}\n"; fi
done

# ---- TIER 2: r10 residue (INFORMATIONAL until REG-RO) ----
r10_total=0
r10_report=""
for f in $FAMILY; do
  h=$(strip_comments "$f" | grep -cE '\br10\b')
  if [ "$h" -gt 0 ]; then r10_total=$((r10_total + h)); r10_report="${r10_report}  ${h}\t${f}\n"; fi
done

echo "=== REG-FENCE: SNOBOL4 pattern-family register conformance (code refs, comments stripped) ==="
echo ""
echo "TIER 1 (HARD) — TEMPLATE_ADDR_SIGMA / TEMPLATE_ADDR_SIGLEN bake: ${sig_total}  (MUST be 0)"
if [ "$sig_total" -gt 0 ]; then printf "%b" "$sig_report" | sort -rn; fi
echo ""
echo "TIER 2 (HARD) — r10 references: ${r10_total}  (MUST be 0)"
if [ "$r10_total" -gt 0 ]; then printf "%b" "$r10_report" | sort -rn; fi
echo ""

if [ "$sig_total" -ne 0 ]; then
  echo "FAIL (TIER 1): a SNOBOL pattern box re-baked &Σ/&Σlen — that is the mode-4 relocation blocker; use r13/r15."
  exit 1
fi

if [ "$r10_total" -ne 0 ]; then
  echo "FAIL (TIER 2): r10 reappeared in the SNOBOL pattern family — REG-RO landed 2026-06-06; the cursor is r14, no [r10] mirror or push/pop guard is permitted (use sub/add rsp,8 for call alignment)."
  exit 1
fi

if [ "$strict" -eq 1 ]; then
  echo "OK (strict): zero &Σ/&Σlen bake AND zero r10 references in the SNOBOL pattern family (TIER 1 + TIER 2 both HARD)."
else
  echo "OK: zero &Σ/&Σlen bake AND zero r10 references in the SNOBOL pattern family (TIER 1 + TIER 2 both HARD)."
fi
exit 0
