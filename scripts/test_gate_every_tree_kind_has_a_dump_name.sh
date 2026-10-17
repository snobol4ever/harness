#!/usr/bin/env bash
# test_gate_every_tree_kind_has_a_dump_name.sh -- EVERY tree_e KIND IN src/ir/ast.h HAS ITS NAME IN tt_e_name, SPELLED AS ITS
# ENUMERATOR (cfo 2026-09-29, row parser-sc-accuracy-...-ceo-1364; Lon 2026-09-27, verbatim: "Write a C function to dump the AST.
# Write an equivalent Snocone function to dump the tree. ... Get the trees to match 100%.").
#
# WHY: ir_dump_tree (src/ir/ast_print.c) prints a node's kind as tt_e_name[e->t], and the table is kept by hand with designated
# initializers, so a kind left out is a NULL that fputs dereferences. MEASURED 2026-09-29: TT_REPALT (Icon's repeated
# alternation |e) had no entry and out/parser_icon segfaulted in print_head on 45 of the 1715 Icon corpus programs, which the
# tree-for-tree gate counted as C refusals -- 45 files that could never MATCH, and nothing said why. The .sc parsers spell the
# same names (parser_icon.sc reduces 'TT_REPALT'), so a name must also be the enumerator's own spelling.
#
# THE ARMS: (1) every enumerator of `typedef enum tree_e { ... } tree_e;` but TT_KIND_COUNT has an entry `[TT_X] = "TT_X"`;
# (2) no entry names a kind the enum lacks; (3) THE PLANT: the same check over a copy of the header with its first table entry
# deleted must report that kind missing -- a check that cannot see a deleted entry refuses rc=2 instead of passing.
# rc 0 every kind named; rc 1 a kind unnamed or misspelled; rc 2 could not measure (header shape unreadable, plant not seen).
# Hermetic, no build, well under a second: a preflight arm.
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"; H="$ROOT/src/ir/ast.h"
[ -f "$H" ] || { echo "⛔ GATE REFUSE(2) [$G]: no $H"; exit 2; }
python3 - "$H" "$G" <<'PY'
import re, sys
path, g = sys.argv[1], sys.argv[2]
def audit(s):
    a = s.find('typedef enum tree_e'); b = s.find('} tree_e;', a); t = s.find('tt_e_name[TT_KIND_COUNT]'); u = s.find('};', t)
    if min(a, b, t, u) < 0: return None
    kinds = [k for k in re.findall(r'\b(TT_[A-Z0-9_]+)\b', s[a:b]) if k != 'TT_KIND_COUNT']
    pairs = re.findall(r'\[(TT_[A-Z0-9_]+)\]\s*=\s*"([^"]*)"', s[t:u])
    named = {k for k, _ in pairs}
    return kinds, pairs, sorted(set(kinds) - named), sorted(named - set(kinds)), [(k, v) for k, v in pairs if k != v]
s = open(path).read()
r = audit(s)
if r is None or not r[0] or not r[1]:
    print("⛔ GATE REFUSE(2) [%s]: the enum or the name table in src/ir/ast.h is not in the shape this gate reads" % g); sys.exit(2)
kinds, pairs, missing, unknown, misspelled = r
first = pairs[0][0]
m = re.search(r'\[' + first + r'\]\s*=\s*"[^"]*",?', s[s.find('tt_e_name[TT_KIND_COUNT]'):])
planted = audit(s[:s.find('tt_e_name[TT_KIND_COUNT]')] + s[s.find('tt_e_name[TT_KIND_COUNT]'):].replace(m.group(0), '', 1)) if m else None
if planted is None or first not in planted[2]:
    print("⛔ GATE REFUSE(2) [%s]: the plant (%s deleted from a copy of the table) was not reported missing -- the check is blind" % (g, first)); sys.exit(2)
bad = ["%s has no name in tt_e_name" % k for k in missing] + ["[%s] names no tree_e kind" % k for k in unknown] + ["[%s] is spelled \"%s\"" % kv for kv in misspelled]
if bad:
    for x in bad: print("  " + x)
    print("⛔ GATE FAIL(1) [%s]: %d of %d tree kinds are not named as the dumpers print them (ir_dump_tree would crash or print a wrong name)" % (g, len(bad), len(kinds))); sys.exit(1)
print("✅ GATE PASS(0) [%s]: all %d tree_e kinds have their own name in tt_e_name (plant: deleting [%s] is seen)" % (g, len(kinds), first)); sys.exit(0)
PY
