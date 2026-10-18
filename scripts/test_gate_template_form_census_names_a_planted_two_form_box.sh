#!/usr/bin/env bash
# test_gate_template_form_census_names_a_planted_two_form_box.sh — the form census names a box that emits two forms,
# the guard that chooses between them and the break-out it needs, and a kind the emitter hands to two boxes
# (hq_templates, row templates-a-form-census-names-every-box-that-serves-more-than-one-ir-form-and-the-split-each-needs,
# ceo CEO-1321; Lon 2026-09-27: "...to consider having other IR/BB broken out properly by form/pattern").
#
# THE FIXTURE. A scratch copy of this tree's src/templates/bb, src/templates/xa and src/emitter/emit.cpp (the real
# tree is never written), read by the census twice: as copied, and after planting
#   bb_zz_planted_two.cpp  if (_.op_zres) return <form 1>; return <form 2>;       -- TWO live forms
#   bb_zz_planted_one.cpp  a lambda whose ternary is a refusal (alpha + bomb) or one form -- ONE live form, one refusal
# and three case labels at the head of walk_bb_node_inner's switch (nd->op): IR_ZZ_PLANTED_A and _B share a group
# handing both to the two-form box; IR_ZZ_PLANTED_C picks between the two boxes on g_emit.op_zres.
# THE ARMS. The copy names no planted box. The planted copy: the two-form box listed with live=2 forms=2, its three
# kinds and two sites, form 1 guarded by _.op_zres and form 2 the otherwise, the break-out naming two one-form boxes;
# the one-form box NOT listed among multi-form boxes and its TSV row reading one live form and one refusal;
# IR_ZZ_PLANTED_C named as a kind the emitter splits across both boxes; the population up by two files and two
# boxes and the verdict up by one multi-form box and one kind case; rc 1. An empty root refuses rc 2; the real tree
# reads rc 0 or 1 over at least 50 files, never 2.
# ⛔ FAIL-ONCE: TEMPLATE_FORMS=<path> points the gate at another census; the landing's proof ran it on a mutant that
# never splits a return, and the gate read RED.
# Usage: bash ../harness/scripts/test_gate_template_form_census_names_a_planted_two_form_box.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
CENSUS="${TEMPLATE_FORMS:-$HERE/audit_template_forms.py}"
gate_require "$CENSUS" "the form census audit_template_forms.py"
gate_require "$ROOT/src/emitter/emit.cpp" "the emitter whose switch binds kinds to boxes"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
R="$TMP/r"
mkdir -p "$R/src/templates" "$R/src/emitter" "$TMP/empty"
cp -r src/templates/bb src/templates/xa "$R/src/templates/"
cp src/emitter/emit.cpp "$R/src/emitter/"
census() { python3 "$CENSUS" --root "$R" "$@" > "$TMP/out" 2>&1; echo $?; }
fails=0; arms=0
arm() {
    arms=$((arms + 1))
    if [ "$1" = ok ]; then echo "  ok    $2"; else echo "  RED   $2"; fails=$((fails + 1)); fi
}
has() { grep -qF -- "$1" "$TMP/out" && echo ok || echo red; }
hasnt() { grep -qF -- "$1" "$TMP/out" && echo red || echo ok; }
num() { sed -n "$1" "$TMP/out" | head -1; }
rc0="$(census)"
arm "$(hasnt "bb_zz_planted")" "the copy as taken names no planted box (rc $rc0)"
f0="$(num 's/^  population: \([0-9]*\) template files.*/\1/p')"; b0="$(num 's/.*; \([0-9]*\) boxes named by a dispatch site.*/\1/p')"
m0="$(num 's/^  VERDICT: \([0-9]*\) box(es).*/\1/p')"; k0="$(num 's/^  VERDICT: .*, \([0-9]*\) kind case(s).*/\1/p')"
cat > "$R/src/templates/bb/bb_zz_planted_two.cpp" <<'CPP'
#include <string>
#include "emit.h"
#include "x86_asm.h"
std::string bb_zz_planted_two() {
    if (_.op_zres)
        return x86_alpha()
             + x86("mov", "rax", (long)1)
             + x86_gamma();
    return x86_alpha()
         + x86("mov", "rax", (long)2)
         + x86_gamma();
}
CPP
cat > "$R/src/templates/bb/bb_zz_planted_one.cpp" <<'CPP'
#include <string>
#include "emit.h"
#include "x86_asm.h"
std::string bb_zz_planted_one() {
    return [&](long k) {
        return (k < 0) ? x86_alpha()
                       + x86_bomb("planted refusal (the census fixture)")
             : x86_alpha()
             + x86("mov", "rax", k)
             + x86_gamma();
    }(_.op_ival);
}
CPP
python3 - "$R/src/emitter/emit.cpp" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
m = re.search(r"static\s+int\s+walk_bb_node_inner\s*\([^)]*\)\s*\{", s)
w = re.compile(r"switch\s*\(\s*nd->op\s*\)\s*\{").search(s, m.end())
plant = ("\n    case IR_ZZ_PLANTED_A:\n    case IR_ZZ_PLANTED_B: bb_emit_x86(bb_zz_planted_two()); return 0;"
         "\n    case IR_ZZ_PLANTED_C: if (g_emit.op_zres) bb_emit_x86(bb_zz_planted_one()); else bb_emit_x86(bb_zz_planted_two()); return 0;")
open(p, "w").write(s[:w.end()] + plant + s[w.end():])
PY
rc="$(census)"
cp "$TMP/out" "$TMP/out.planted"
[ "$rc" = 1 ] && r=ok || r=red; arm "$r" "the planted copy reads rc 1 (read $rc)"
arm "$(has "live=2 forms=2 refusals=0  bb_zz_planted_two  (src/templates/bb/bb_zz_planted_two.cpp)  kinds: IR_ZZ_PLANTED_A IR_ZZ_PLANTED_B IR_ZZ_PLANTED_C  sites: 2")" "the two-form box is named with two live forms, its three kinds and two sites"
blk="$(sed -n '/  bb_zz_planted_two  (/,/BREAK-OUT/p' "$TMP/out")"
grep -qF "form 1: _.op_zres" <<< "$blk" && r=ok || r=red; arm "$r" "form 1 is guarded by _.op_zres"
grep -qF "form 2: (otherwise)" <<< "$blk" && r=ok || r=red; arm "$r" "form 2 is the otherwise"
grep -qF "BREAK-OUT: 2 one-form boxes bb_zz_planted_two_f1, bb_zz_planted_two_f2" <<< "$blk" && r=ok || r=red; arm "$r" "the break-out names two one-form boxes"
arm "$(hasnt "  bb_zz_planted_one  (")" "the one-form box (a form and a refusal) is not listed among multi-form boxes"
arm "$(has "IR_ZZ_PLANTED_C -> bb_zz_planted_one | bb_zz_planted_two   BREAK-OUT: IR_ZZ_PLANTED_C_ZZ_PLANTED_ONE, IR_ZZ_PLANTED_C_ZZ_PLANTED_TWO")" "IR_ZZ_PLANTED_C is named as a kind the emitter splits across both boxes"
f1="$(num 's/^  population: \([0-9]*\) template files.*/\1/p')"; b1="$(num 's/.*; \([0-9]*\) boxes named by a dispatch site.*/\1/p')"
m1="$(num 's/^  VERDICT: \([0-9]*\) box(es).*/\1/p')"; k1="$(num 's/^  VERDICT: .*, \([0-9]*\) kind case(s).*/\1/p')"
[ -n "$f0" ] && [ "$f1" = "$((f0 + 2))" ] && [ "$b1" = "$((b0 + 2))" ] && r=ok || r=red; arm "$r" "the population rises by two files and two boxes ($f0 -> $f1 files, $b0 -> $b1 boxes)"
[ -n "$m0" ] && [ "$m1" = "$((m0 + 1))" ] && [ "$k1" = "$((k0 + 1))" ] && r=ok || r=red; arm "$r" "the verdict rises by one multi-form box and one kind case ($m0 -> $m1, $k0 -> $k1)"
census --tsv > /dev/null
arm "$(has "$(printf 'bb_zz_planted_one\tsrc/templates/bb/bb_zz_planted_one.cpp\tIR_ZZ_PLANTED_C\t1\t2\t1\t1')")" "the TSV row of the one-form box reads 2 paths, 1 live, 1 refusal"
arm "$(has "$(printf 'bb_zz_planted_two\tsrc/templates/bb/bb_zz_planted_two.cpp\tIR_ZZ_PLANTED_A,IR_ZZ_PLANTED_B,IR_ZZ_PLANTED_C\t2\t2\t2\t0')")" "the TSV row of the two-form box reads 2 paths, 2 live"
python3 "$CENSUS" --root "$TMP/empty" > "$TMP/out" 2>&1; rc=$?
[ "$rc" = 2 ] && r=ok || r=red; arm "$r" "a root with no emitter refuses rc 2 (read $rc)"
python3 "$CENSUS" > "$TMP/out" 2>&1; rc=$?
fr="$(num 's/^  population: \([0-9]*\) template files.*/\1/p')"
{ [ "$rc" = 0 ] || [ "$rc" = 1 ]; } && [ -n "$fr" ] && [ "$fr" -ge 50 ] && r=ok || r=red; arm "$r" "the real tree reads rc $rc over ${fr:-no} files (rc 0 or 1, at least 50)"
if [ "$fails" -gt 0 ]; then
    echo "--- the census's planted-copy output (sections 1 head and 2) ---"
    grep -E 'population|kinds:|zz_planted|VERDICT|IR_ZZ' "$TMP/out.planted"
fi
gate_floor "$arms" 14 "form census arms"
gate_verdict "$fails" "form census arm(s) red"
