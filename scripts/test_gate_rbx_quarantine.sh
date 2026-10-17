#!/usr/bin/env bash
# test_gate_rbx_quarantine.sh — RBX QUARANTINE gate (GOAL-SNOBOL4-BB RUNG REG-MAP, REG-1 GVA-DEREG slice D).
#
# DOCTRINE (the six-register ruling, s73): GVA is REGISTER-FREE — global slots live on the pinned island at
# build-constant RT_GVA_VA and every template reads them ABSOLUTE ([RT_GVA_VA + 16k], SIB no-base disp32,
# identical bytes both mediums). rbx therefore carries NO GVA contract: no template addresses [rbx + ...],
# no prologue (m3 register-asm or m4 emitted text) establishes rbx, and no g_gva_base reload cell exists.
# rbx is TENANT-FREE until REG-4 re-tenants it as the GC workspace bump top.
#
# SANCTIONED rbx MENTIONS (register-NAME table entries and generic save/restore, not GVA addressing):
#   src/templates/x86/x86_asm.h        — the x86_rnum / x86_is_reg register-name tables ("rbx" as a name literal)
#   src/templates/bb/bb_create.cpp    — the coexpr thread-contract register save (generic contract carry;
#                                    becomes the GC-top carry at REG-4)
#
# Usage: bash ../harness/scripts/test_gate_rbx_quarantine.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
# ⛔ THE POPULATION IS COUNTED BEFORE THE FOUR ARMS RUN (coo 2026-09-18, the cto's finding, seat10's list).  Every
# arm here is a grep -r over src/ asserting a count of ZERO, so an EMPTY src/ satisfies all four at once and the
# gate printed "rbx quarantined (4 arms)" having read no file.  Four arms agreeing about nothing is not four
# arms; the denominator is the whole verdict for a gate whose every arm asserts an absence.
census_files=$(find src/ -name '*.c' -o -name '*.cpp' -o -name '*.h' 2>/dev/null | wc -l)
gate_floor "$census_files" 1 "src/ source file(s) over which all four absence arms are asserted"

# Arm 1 — no rbx-relative GVA operand spelling anywhere in the tree.
n=$(grep -rn 'RDQ("rbx"' src/ 2>/dev/null | grep -cv '\.o:') || true
if [ "${n:-0}" -ne 0 ]; then echo "GATE FAIL arm1: RDQ(\"rbx\" operand spelling present ($n):"; grep -rn 'RDQ("rbx"' src/ | grep -v '\.o:'; fail=1; fi

# Arm 2 — the driver mints no rbx (the m3 register-asm entry and any prologue mov are deleted).
n=$(grep -cn 'rbx' src/driver/scrip.c 2>/dev/null | cut -d: -f1) || true
n=$(grep -c 'rbx' src/driver/scrip.c 2>/dev/null) || true
if [ "${n:-0}" -ne 0 ]; then echo "GATE FAIL arm2: rbx mentioned in src/driver/scrip.c ($n):"; grep -n 'rbx' src/driver/scrip.c; fail=1; fi

# Arm 3 — the g_gva_base reload cell is gone from the whole tree.
n=$(grep -rn 'g_gva_base' src/ 2>/dev/null | grep -cv '\.o:') || true
if [ "${n:-0}" -ne 0 ]; then echo "GATE FAIL arm3: g_gva_base still referenced ($n):"; grep -rn 'g_gva_base' src/ | grep -v '\.o:'; fail=1; fi

# Arm 4 — template rbx mentions only in the sanctioned files (name tables + thread-contract save).
n=$(grep -rln '"rbx"' src/templates/ 2>/dev/null | grep -v 'x86_asm.h' | grep -cv 'bb_create.cpp') || true
if [ "${n:-0}" -ne 0 ]; then echo "GATE FAIL arm4: unsanctioned template file mentions \"rbx\":"; grep -rln '"rbx"' src/templates/ | grep -v 'x86_asm.h' | grep -v 'bb_create.cpp'; fail=1; fi

if [ "$fail" -eq 0 ]; then echo "GATE PASS: rbx quarantined (4 arms) — no GVA register contract; rbx tenant-free until REG-4"; exit 0; fi
exit 1
