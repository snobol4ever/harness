#!/usr/bin/env bash
# util_template_purity_audit.sh — IFT (IO-FREE-TEMPLATES) purity gate. [ADVISORY]
#
# STATUS: ADVISORY / OVER-APPROXIMATING (not yet a hard gate). The arm-scope
# tracking is line-based and does NOT track brace depth, so side-effect calls
# inside a MEDIUM_BINARY block that is NESTED within other conditionals (e.g.
# bb_capture's fnc-name sub-branch) can be mis-counted as non-binary. Treat the
# output as a candidate worklist, not a verdict. TODO (IFT-AUDIT-2): make the
# arm tracker brace-aware (push/pop MEDIUM_* scope on { }) before wiring into the
# session gate. Until then, run manually; cross-check flagged lines by hand.
#
# Invariant (Lon, 2026-05-27): every top-level BB/SM/XA emitter TEMPLATE function
# is a pure `state -> std::string`. NON-binary arms (MEDIUM_TEXT, MEDIUM_MACRO_DEF,
# PLATFORM_JVM/JS/NET/WASM) MUST contain no emission side effects — they build a
# std::string and RETURN it. The CALLER (the thin `extern "C"` dispatch wrapper at
# the bottom of each template file) is the ONLY place that touches a sink.
#
# THE ONE SANCTIONED EXCEPTION: the `MEDIUM_BINARY` arm. x86 binary emission of
# rel32 jumps/calls (`emit_jmp`/`emit_call_label`/`emit_label_define`) needs the
# patch list writing into `bb_emit_buf`, so those arms are imperative and return
# an empty std::string by design (see HQ THREE-MEDIUM + the rel32 fork). Raw-byte
# `bb_sink_str(bytes(...)+...)` is likewise the sanctioned binary sink. This audit
# therefore IGNORES side-effect calls that occur inside a MEDIUM_BINARY block.
#
# A FAIL means a non-binary arm emits via side effect instead of returning a string.
#
# Usage: bash ../harness/scripts/util_template_purity_audit.sh
# Exit 0 = GREEN (no non-binary violations), 1 = violations found.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
# PATH CORRECTED s169 (seat1, queue row gates-dead-paths): the src reorg's blind sed mapped
# BB_templates AND XA_templates both onto src/templates (so every file was scanned TWICE and the
# violation total printed DOUBLE) and left SM_templates dangling at a dir that no longer exists.
TPL_DIRS=(
  "$ROOT/src/templates"
)

# Side-effecting emission calls. The `_str` twins and `s_*asm`/`s_directive`/
# `s_comment` string builders are pure and allowed everywhere.
SIDE_EFFECT_RE='emit_text_n|emit_textf|emit_1asm|emit_2asm|emit_3asm|emit_comment\(|emit_directive|emit_label_define|emit_jmp|emit_call_label|emit_mode_set|wasm_emit_data_segments\(|fprintf|fputs|fputc|fwrite'

violations=0
viol_files=""

for d in "${TPL_DIRS[@]}"; do
  [ -d "$d" ] || continue
  for f in "$d"/*.cpp; do
    [ -f "$f" ] || continue
    # awk state machine: inbin=1 while inside a MEDIUM_BINARY block (until the next
    # arm guard). Skip the extern "C" dispatch wrapper (the sanctioned sink site).
    hits=$(awk -v re="$SIDE_EFFECT_RE" '
      # Track /* ... */ block comments (incl. multi-line) so header prose is skipped.
      { line=$0 }
      incmt && /\*\// { incmt=0; next }
      incmt { next }
      /\/\*/ && !/\*\// { incmt=1; next }
      /MEDIUM_BINARY/                                                      { inbin=1 }
      /MEDIUM_TEXT|MEDIUM_MACRO_DEF|PLATFORM_JVM|PLATFORM_JS|PLATFORM_NET|PLATFORM_WASM/ { inbin=0 }
      /extern[ \t]+"C"[ \t]+(void|int|std::string)/                      { inwrap=1 }
      {
        if (!inbin && !inwrap && line ~ re && line !~ /_str\b/ && line !~ /\/\// && line !~ /\/\*/) {
          print FILENAME ":" NR ": " line
        }
      }
    ' "$f")
    if [ -n "$hits" ]; then
      n=$(printf '%s\n' "$hits" | wc -l)
      violations=$((violations + n))
      viol_files="$viol_files $(basename "$f")($n)"
      echo "$hits"
    fi
  done
done

echo "----"
if [ "$violations" -eq 0 ]; then
  echo "TEMPLATE-PURITY GREEN: no non-binary side effects in any BB/SM/XA template arm."
  exit 0
else
  echo "TEMPLATE-PURITY: $violations non-binary side-effect(s) in:$viol_files"
  echo "(MEDIUM_BINARY arms are exempt — rel32 patch idiom is sanctioned.)"
  exit 1
fi
