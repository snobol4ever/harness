#!/usr/bin/env bash
# ../harness/scripts/test_gate_no_hidden_global_in_emitted.sh
#
# GATE: no visibility("hidden") global in the runtime may be NAMED IN EMITTED PROGRAM TEXT.
#
# WHY THIS GATE EXISTS (s214, 2026-07-29). g_cap_gen was promoted static -> visibility("hidden") so
# rtx_match.s could reach it. That is correct for a .S INSIDE libscrip_rt.so and WRONG for emitted
# mode-4 code OUTSIDE it: a hidden symbol is absent from the dynamic table, so the separately-linked
# mode-4 object cannot resolve it. 173 of 316 crosscheck programs failed to LINK. Mode 3 bakes the
# address in-process and is STRUCTURALLY INCAPABLE of expressing the failure, so the defect survived
# >=11 commits while every session reported m3 green.
#
# THREE VISIBILITY TIERS, NOT TWO -- ARCH s7 step 0(c) documents only the first column:
#     linkage   reachable from .S inside the .so   reachable from emitted mode-4 code
#     static                  no                              no
#     hidden                  YES                             NO   <-- the trap
#     default                 yes (via GOT)                   yes
#
# AND IF YOU EXPORT ONE, THE .so-INTERNAL ACCESSES MUST BECOME @GOTPCREL. A -no-pie executable takes
# a COPY RELOCATION and owns the storage; direct PC-relative access inside the .so would then be a
# DIFFERENT VARIABLE -- silent divergence, no diagnostic at any stage. ld refusing R_X86_64_PC32 on
# the shared-object side is the lucky half of that fix, not the whole of it.
#
# This gate is STATIC and runs in about a second, which is the point: the dynamic instrument that
# catches this class is the mode-4 crosscheck, and mode 4 is the expensive half that sessions skip.
# Exit 0 = clean. Exit 1 = a hidden global is named in emitted text.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SRC:-$HERE/../../SCRIP/src}"
CORPUS="${CORPUS:-$S4E/corpus}"

echo "=== GATE: no hidden-visibility global named in emitted text ==="

# 1. Harvest hidden globals from the BUILT OBJECTS, not from source text. ELF is ground truth and is
#    immune to prose. ⛔ THE FIRST VERSION OF THIS GATE PARSED `grep visibility("hidden")` OVER THE .c
#    FILES AND IMMEDIATELY FALSE-POSITIVED ON ITS OWN FIX: the warning comment left on g_cap_gen's
#    declaration ("DO NOT re-add visibility(\"hidden\")") contains the very string the harvester
#    matched, so the gate reported the symbol it had just been written to protect. A gate that reads
#    prose inherits every defect prose has. Data only -- a hidden FUNCTION is a different question
#    (emitted code calls runtime functions through the PLT and those must be exported anyway, so a
#    hidden one fails loudly at link on the first program that reaches it).
OBJS=$(ls "$HERE/../../SCRIP/out/rt_pic/"*.o 2>/dev/null)
# ⭐ V2-5 GATE HONESTY: absent .o files is the literal state of every fresh clone, and it was
# indistinguishable from "checked, clean".  UNPROVEN(2) now, never a pass.
. "$(dirname "$0")/lib_gate.sh"
if [ -z "$OBJS" ]; then
  echo "GATE UNPROVEN(2) [no_hidden_global_in_emitted]: out/rt_pic/*.o absent -- run 'make libscrip_rt' first"
  echo "    This is NOT a pass: with no objects to read, no hidden global can be observed either way."
  exit 2
fi
HIDDEN=$(readelf -sW $OBJS 2>/dev/null \
  | awk '$4=="OBJECT" && $5=="GLOBAL" && $6=="HIDDEN" {print $8}' \
  | sed 's/@.*//' | grep -E '^[A-Za-z_][A-Za-z0-9_]*$' | sort -u)

if [ -z "$HIDDEN" ]; then
  echo "GATE UNPROVEN(2) [no_hidden_global_in_emitted]: readelf reported ZERO hidden-visibility globals across $(echo "$OBJS" | wc -w) object(s)."
  echo "    The runtime is built -fvisibility=hidden, so zero is not a clean tree -- it means the scan did not read them."
  exit 2
fi
echo "  hidden globals under test: $(echo "$HIDDEN" | tr '\n' ' ')"

# 2. Emitted artifacts are the oracle. They are a LOWER BOUND: a template can name a symbol on a path
#    no committed artifact exercises, which is why step 3 also reads the templates.
ART=$(ls "$CORPUS"/benchmarks/*/*.s "$CORPUS"/*/demo/*.s 2>/dev/null)
if [ -z "$ART" ]; then echo "  SKIP no .s artifacts found under $CORPUS"; exit 0; fi

FAIL=0
for sym in $HIDDEN; do
    n=$(grep -rhoE "\b$sym\b" $ART 2>/dev/null | wc -l)
    if [ "$n" -gt 0 ]; then
        echo "  FAIL  $sym is visibility(\"hidden\") and appears $n time(s) in emitted .s"
        echo "        -> mode 4 cannot link it. Export it AND convert every .so-internal"
        echo "           access to [rip+$sym@GOTPCREL] (see the header of this script)."
        FAIL=1
    fi
done

# 3. Advisory: a hidden global NAMED IN A TEMPLATE is the same defect waiting for a program to
#    exercise it. Warn rather than fail -- s214 measured that a template can mention a symbol in a
#    COMMENT ONLY (g_pcall/g_pcall_top in bb_call_proc_staged.cpp), which is not a defect, and this
#    grep cannot tell a comment from an emitted operand. READ THE REFERENCE BEFORE BELIEVING IT.
for sym in $HIDDEN; do
    hits=$(grep -rl "\b$sym\b" "$SRC/templates/" "$SRC/emitter/" 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' ')
    [ -n "$hits" ] && echo "  WARN  $sym named in emitter/template: $hits (verify it is a comment, not an emitted operand)"
done

echo "------------------------------------------------------------"
[ "$FAIL" -eq 0 ] && echo "GATE CLEAN" || echo "GATE FAILED"
exit $FAIL
