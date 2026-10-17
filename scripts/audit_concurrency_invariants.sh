#!/usr/bin/env bash
# audit_concurrency_invariants.sh — the SHARED herding gate for concurrent BB seats.
# Enforces the surviving COMPLETION TESTs of the TEMPLATE-ONLY EMISSION FACT RULE: EMITTER one-dispatch
# (one `case IR_` per kind WITHIN one switch) and no NEW bytes outside templates. Run before every commit
# alongside prove_lower.sh and the emitter gates. Exit non-zero on ANY violation.
#
# ⛔ TWO CHECKS RETIRED s173 (seat6, queue row gates-retire-4) under the HQ-55 ruling "RETIRE ALL FOUR"
# (GOAL-SCRIP-HQ.md row 18; census in FINDING-2026-08-19-s169-eight-audit-gates...). Both enforced
# contracts that no longer exist, and neither is coming back — do NOT re-mint either from this header:
#   (a) LOWER one-case-per-role-switch. It keyed on `static IR_t * lower_(value|pattern|goal)(`, the
#       role-dispatcher shape of the pre-reorg single src/lower/lower.c. That shape survives in NONE of
#       the 7 per-language lowerers (re-measured s173: 0 occurrences of ANY spelling under src/lower/),
#       so the scan was VACUOUS. A LOWER check for the current shape must be written against that shape,
#       not resurrected from this one.
#   (d) FACT-RULE block byte-identity across GOAL-{SNOBOL4,ICON,PROLOG}-BB.md. Those three files were
#       consolidated into the GOAL-*-100.md files, and the SHARED-LOWERER / ONE-DISPATCH blocks it
#       md5-compared did NOT survive the consolidation (re-measured s173: all 4 anchors grep == 0 in all
#       3 files). It was UNRUNNABLE, not mis-pathed — repointing only moved the failure — and it emitted
#       6 VIOLATIONs that held this whole gate permanently RED (rc=1), which is why GOAL-RAKU-BB.md's
#       2026-07-10 entry had to carry it as a stash-A/B-proven pre-existing red. CONCURRENCY_SKIP_D is
#       retired with it; the variable is no longer read.
# PATH CORRECTED s169 (seat1, queue row gates-dead-paths): src/emitter/emit_core.c is now
# src/emitter/emit.cpp; the ref had been dangling since the src reorg, so the emitter dup-label check
# reported "not found" instead of enforcing anything.
set -u
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
EMIT="$ROOT/src/emitter/emit.cpp"
fail=0
say(){ printf '%s\n' "$*"; }
bad(){ printf 'VIOLATION: %s\n' "$*"; fail=1; }

# --- EMITTER (a): no duplicated case IR_ label in emit.cpp (one dispatch case per kind) ---
# PER-SWITCH, not per-file (s169 seat1): emit.cpp now holds 26 switches, so a kind legitimately appears
# once per switch (IR_ACTIVATE is in walk_bb_node_inner AND emit_drive). The old flat
# `grep | sort | uniq -d` over the whole file flagged ~120 kinds the moment the path was corrected from the
# dead emit_core.c -- a FALSE RED. The rule is "one dispatch case per kind WITHIN one switch"; brace-depth
# scoping is what enforces it.
if [ -f "$EMIT" ]; then
  # Comments are stripped, then every `{`, `}` and `case IR_X` is put on its own line so a ONE-LINE switch
  # -- `switch (o) { case IR_MATCH_LIT: ... }`, of which emit.cpp has several -- scopes exactly like a
  # multi-line one. Without that normalisation a one-line switch leaks its labels into the enclosing scope
  # and collides with the next one-line switch (measured: a false IR_MATCH_LIT hit, s169).
  # String literals are deliberately NOT stripped: emit.cpp contains the char literal '"' , and a
  # naive string-strip starts a phantom string there and swallows a real `}` (measured: 1349 open vs 1348
  # close, which silently blinded the whole check). The brace-balance assertion below is what makes that
  # safe -- if a literal ever does unbalance the cheap lexer, this check says so instead of passing.
  norm=$(perl -0777 -pe 's{/\*.*?\*/}{}gs; s{//[^\n]*}{}g' "$EMIT" \
    | sed -E 's/(case IR_[A-Z0-9_]+)/\n\1\n/g; s/\{/\n{\n/g; s/\}/\n}\n/g')
  ob=$(printf '%s\n' "$norm" | grep -c '^{$'); cb=$(printf '%s\n' "$norm" | grep -c '^}$')
  if [ "$ob" -ne "$cb" ]; then
    bad "$(basename "$EMIT"): brace-balance $ob open vs $cb close — the case-label scoper cannot be trusted; fix the lexer before believing this check."
  else
    edups=$(printf '%s\n' "$norm" | awk '
        { if ($0 ~ /switch[ \t]*\(/) pending=1 }
        /^\{$/ { depth++; if (pending) { sp++; sw[sp]=depth; pending=0 }; next }
        /^\}$/ { if (sp>0 && sw[sp]==depth) { for (k in seen) if (index(k, sp ":")==1) delete seen[k]; sp-- } depth--; next }
        /^case IR_[A-Z0-9_]+$/ {
          if (sp>0) { lbl=substr($0,6); key=sp ":" lbl; if (seen[key]++) print "  " lbl }
        }' | sort -u)
    [ -n "$edups" ] && bad "$(basename "$EMIT"): case IR_ label duplicated WITHIN a single switch:$(printf '%s' "$edups")"
  fi
else
  bad "emit.cpp not found at $EMIT"
fi

# --- EMITTER (c): no NEW bytes-outside-templates beyond the sanctioned baseline ---
# util_template_purity_audit.sh reports the sanctioned fail-loud/rel32 side-effects (FACT baseline) and
# exits nonzero by design. We fail only on a REGRESSION above the known baseline count (PURITY_BASELINE).
if [ -x "$ROOT/../harness/scripts/util_template_purity_audit.sh" ]; then
  bash "$ROOT/../harness/scripts/util_template_purity_audit.sh" >/tmp/_purity.out 2>&1
  pc=$(grep -oE '[0-9]+ non-binary side-effect' /tmp/_purity.out | grep -oE '^[0-9]+' | head -1)
  pc=${pc:-0}
  # PURITY_BASELINE tracks the count of SANCTIONED fail-loud/rel32 side-effects (FATAL guards) across all
  # templates. Bumped 6 -> 7 (2026-05-31): the 7th is the pre-existing bb_call.cpp GZ-3 text-arm fail-loud
  # (write(binop) result-slot guard) already in HEAD — NOT from the PB-0 SUBJECT box, whose only fail-loud
  # lives inside MEDIUM_BINARY (audit-exempt) so bb_subject.cpp contributes 0. Catches a NEW 8th.
  # Bumped 7 -> 8 (2026-06-01): the 8th is bb_rk_gather.cpp's single FLAT-take fall-loud guard (RK-EMIT-GATHER).
  # RATCHET RE-BASED 8 -> 4 (s169 seat1, queue row gates-dead-paths): util_template_purity_audit.sh
  # was scanning src/templates TWICE (the reorg sed collapsed BB_ and XA_ onto one dir), so it printed
  # DOUBLE. The doubled 8 exactly matched this stale ceiling, so the ratchet never fired and hid its own
  # defect. TRUE count at s169 = 4 (bb_call, bb_call_write_slot, bb_define, bb_match_replace).
  # RATCHET RE-BASED 4 -> 3 (s173 seat6, queue row gates-retire-4): bb_define.cpp's side-effect went away
  # with the s172 ab-cell-hoist rung (51b73ce9), which moved the AB fn-cell store out of the template and
  # into emit.cpp. Re-measured here with receipts — the audit still prints file:line for the surviving 3
  # (bb_call, bb_call_write_slot, bb_match_replace), so this is a real GAIN, not a blinded scanner. A ratchet
  # left above the true count is the s169 defect exactly (a stale ceiling the doubled count matched, so it
  # never fired): lowering it is what LOCKS THE GAIN IN. May not grow. Negative-tested at ceiling 2 -> fires.
  PURITY_BASELINE="${PURITY_BASELINE:-3}"
  if [ "$pc" -gt "$PURITY_BASELINE" ]; then
    bad "template purity REGRESSED: $pc side-effects outside templates > baseline $PURITY_BASELINE (see /tmp/_purity.out)"
  fi
fi

[ "$fail" -eq 0 ] && say "OK: concurrency invariants hold (EMITTER one-dispatch, no stray bytes). Checks (a) LOWER role-switch and (d) FACT-RULE block byte-identity RETIRED s173 — see header."
exit "$fail"
