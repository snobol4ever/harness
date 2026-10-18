#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_bb_label_no_silent_truncation.sh — THE PRISON for: A SYMBOL NAME IS NEVER SILENTLY TRUNCATED, AND
# EVERY SPELLING OF ONE SYMBOL IS THE SAME SPELLING.
#
# THE INVARIANT: two distinct source names must never become one symbol, and one source name must never become
# two. Both have happened:
#   (1) bb_label_t.name is a fixed BB_LABEL_NAME_MAX (80) byte field. A plain vsnprintf/strncpy into it dropped
#       whatever distinguished a long name, INCLUDING the alpha/beta/gamma/omega port suffix, so several boxes
#       emitted the SAME symbol and `as` rejected the file. Cured by SCRIP 32cce542: bb_label_name_set() keeps a
#       62-char prefix plus '$' and a 16-hex FNV-1a of the FULL name.
#   (2) bb_ab_sym_name() (src/templates/bb/bb_define.cpp), the mangler every procedure symbol passes through, cut
#       its output at 250 bytes with no disambiguator, so two predicates sharing 83 characters of name became one
#       symbol ("already defined"); and the procedure records in src/driver/scrip.c spelled FN__<name> with the
#       FULL mangled name while the definition went through the 80-byte field's hash, so a predicate whose name
#       mangles past 75 bytes was referenced under one spelling and defined under another and the mode-4 LINK
#       failed (undefined reference). Measured on e42ccddd2, 2026-10-01, by the cto. Cured the same day: the
#       mangler itself shortens a name past 48 bytes to its whole escape units up to 31 bytes, '$' and 16 hex of
#       the FNV-1a of the whole raw name, so every symbol built from it is short enough that the label field
#       never cuts it, and every definition and every text reference spell it the same way.
#
# WITNESS: a fixture this gate writes itself (it was corpus/programs/prolog/rung10_programs_puzzles.pl line 190,
# an unterminated symbolic atom at end of file that the Prolog parser now refuses exactly as swipl does, "190:121
# Syntax error: Unexpected end of file", so it emitted no long label and the gate read red on a witness that no
# longer exercised the class). Two pairs of predicates whose quoted names are '#' and a run of dashes:
#   pair A, 40 dashes: mangles to 129 bytes -- past the 80-byte label field, under the old 250 cut (class 2 link)
#   pair B, 120 dashes: mangles to 369 bytes -- past the old 250 cut, where a and b once collapsed (class 2 as)
# The program's answer is cut from swipl 9.0.4: [[1,2],[3],[4],[5]].
#
# THE LOCKS. A reintroduction must defeat all of them.
#   LOCK 0 (structural) — the label-field cure (bb_label_name_set) is present in emit.h.
#   LOCK 1 (structural) — no raw truncating write into a label name field survives in the emitter.
#   LOCK 2 (behavioral GREEN) — the witness compiles; (a) `as` accepts it; (b) every mangled label DEFINITION is
#       distinct, counted whether or not an instruction follows the colon on the same line; (c) it links and runs
#       in mode 4 and runs in mode 3, printing the oracle's answer in both.
#   LOCK 3 (fail-once RED) — the witness's names, mangled IN FULL by the pre-cure rule, collide under the old cuts:
#       pair A's two names agree on their first 79 bytes and pair B's on their first 250. LOCK 3 is what makes
#       LOCK 2 mean something: the witness is hard, so its distinctness in LOCK 2 is produced by the cure.
#
# PROOF STATUS: class 2 MEASURED RED on e42ccddd2 with the fixture by hand (pair A: undefined reference
# FN__$23$2D...b$2F1 at link; pair B: `as` "symbol ... is already defined") and GREEN after the mangler cure.
# For the full two-part proof against real codegen, build the pre-cure tree in a worktree and run this gate there
# with BBLBL_REVERT_ARM=1: it must print a red REVERT ARM line.
#
# ⛔ LATENT SIBLING, deliberately NOT asserted here: src/emitter/emit.cpp emit_label_intern() dedups by strcmp
# against the STORED name, so two interns of one over-long name still allocate two entries carrying one final
# name. No witness reaches it.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
refuse() { echo "⛔ GATE REFUSES (cannot measure): $*"; exit 2; }
command -v as      >/dev/null 2>&1 || refuse "no 'as' assembler on PATH"
command -v gcc     >/dev/null 2>&1 || refuse "no gcc on PATH"
command -v python3 >/dev/null 2>&1 || refuse "no python3 on PATH"
[ -x "$ROOT/scrip" ]                 || refuse "no built ./scrip at $ROOT/scrip -- run make first"
[ -r "$ROOT/out/libscrip_rt.so" ]    || refuse "no out/libscrip_rt.so -- run make first"
T=$(mktemp -d) || refuse "mktemp failed"
trap 'rm -rf "$T"' EXIT
DA=$(printf '%.0s-' $(seq 1 40)); DB=$(printf '%.0s-' $(seq 1 120))
NA1="#${DA}a"; NA2="#${DA}b"; NB1="#${DB}a"; NB2="#${DB}b"
WITNESS="$T/long_names.pl"
cat > "$WITNESS" <<EOF
:- initialization(main).
'$NA1'(1).
'$NA1'(2).
'$NA2'(3).
'$NB1'(4).
'$NB2'(5).
main :- findall(P, '$NA1'(P), W), findall(Q, '$NA2'(Q), X), findall(R, '$NB1'(R), Y), findall(S, '$NB2'(S), Z), write([W,X,Y,Z]), nl.
EOF
WANT='[[1,2],[3],[4],[5]]'
fail=0
# ⛔ The absence of the cure is a RED, never a refusal. An earlier draft refused (rc=2) here, which
# would have reported a REVERTED emitter as "cannot measure" -- the one case this gate exists to catch.
if ! grep -q 'bb_label_name_set' "$ROOT/src/emitter/emit.h"; then
    echo "  ✗ LOCK 0: bb_label_name_set() is absent from emit.h -- the cure has been reverted or removed"; fail=1
else echo "  ✅ LOCK 0: the cure (bb_label_name_set) is present in emit.h"; fi
# ---- LOCK 1: no raw truncating write into a label name field -------------------------------------
raw=$(grep -nE 'vsnprintf[[:space:]]*\([[:space:]]*lbl->name|strncpy[[:space:]]*\([[:space:]]*lbl\.name' \
        "$ROOT/src/emitter/emit.cpp" "$ROOT/src/emitter/emit.h" 2>/dev/null)
if [ -n "$raw" ]; then echo "  ✗ LOCK 1: a raw truncating write into a label name survives:"; echo "$raw" | sed 's/^/      /'; fail=1
else echo "  ✅ LOCK 1: every label-name write goes through bb_label_name_set()"; fi
# ---- LOCK 2: the witness compiles, assembles, its labels are distinct, and it runs right in both modes ----
S="$T/long_names.s"
if ! (cd "$T" && timeout -k 5 120 "$ROOT/scrip" --compile "$WITNESS" < /dev/null > "$S" 2>/dev/null) || [ ! -s "$S" ]; then
    echo "  ✗ LOCK 2: witness failed to COMPILE (expected a non-empty .s)"; fail=1
else
    if as --64 -o /dev/null "$S" 2>/dev/null; then echo "  ✅ LOCK 2a: witness assembles (as --64 rc=0)"
    else echo "  ✗ LOCK 2a: as --64 REJECTED the emitted asm -- a symbol collision is back:"; as --64 -o /dev/null "$S" 2>&1 | head -3 | sed 's/^/      /'; fail=1; fi
    occ=$(grep -cE '^\$[0-9A-F]{2}\$[^:[:space:]]*:' "$S" 2>/dev/null)
    dis=$(grep -oE '^\$[0-9A-F]{2}\$[^:[:space:]]*:' "$S" 2>/dev/null | sort -u | wc -l)
    if [ "${occ:-0}" -eq 0 ]; then echo "  ✗ LOCK 2b: witness emitted NO mangled labels -- it no longer exercises the class"; fail=1
    elif [ "$occ" -ne "$dis" ]; then echo "  ✗ LOCK 2b: $occ mangled label definitions but only $dis distinct -- names are colliding"; fail=1
    else echo "  ✅ LOCK 2b: $occ mangled label definitions, $dis distinct (1:1)"; fi
    if ! gcc "$S" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o "$T/long_names" > "$T/ld.txt" 2>&1; then
        echo "  ✗ LOCK 2c: the mode-4 LINK failed -- one symbol is spelled two ways:"; grep -v 'TEXTREL\|read-only section' "$T/ld.txt" | head -3 | cut -c1-200 | sed 's/^/      /'; fail=1
    else
        g4=$(cd "$T" && timeout -k 5 30 ./long_names < /dev/null 2>&1)
        g3=$(cd "$T" && timeout -k 5 30 "$ROOT/scrip" "$WITNESS" < /dev/null 2>&1)
        if [ "$g4" = "$WANT" ] && [ "$g3" = "$WANT" ]; then echo "  ✅ LOCK 2c: links, and both modes print the oracle's $WANT"
        else echo "  ✗ LOCK 2c: want $WANT; mode 4 printed '$g4', mode 3 printed '$g3'"; fail=1; fi
    fi
fi
# ---- LOCK 3: fail-once -- the full pre-cure mangling of the witness's names collides under the old cuts ----
agree=$(python3 -c '
import sys
def m(n): return "".join(c if c.isascii() and (c.isalnum() or c in "_$.") else "".join("$%02X" % b for b in c.encode()) for c in n)
def common(a, b):
    k = 0
    while k < min(len(a), len(b)) and a[k] == b[k]: k += 1
    return k
a1, a2, b1, b2 = (m(x + "/1") for x in sys.argv[1:5])
print(len(a1), common(a1, a2), len(b1), common(b1, b2))' "$NA1" "$NA2" "$NB1" "$NB2")
read -r la ca lb cb <<< "$agree"
if [ "${ca:-0}" -ge 79 ] && [ "${la:-0}" -gt 80 ] && [ "${cb:-0}" -ge 250 ]; then
    echo "  ✅ LOCK 3 (fail-once): pair A mangles to $la bytes agreeing on $ca (the old 79-byte field cut collapses it); pair B agrees on $cb (the old 250-byte mangler cut collapses it). LOCK 2 is load-bearing."
else echo "  ✗ LOCK 3: the witness is too easy (pair A $la bytes, common $ca; pair B common $cb) -- the old cuts would not have collapsed it"; fail=1; fi
# ---- optional real-revert arm (two-part proof against real codegen) -------------------------------
if [ "${BBLBL_REVERT_ARM:-0}" = "1" ]; then
    if [ -s "$S" ] && as --64 -o /dev/null "$S" 2>/dev/null && [ -x "$T/long_names" ]; then echo "  ✗ REVERT ARM: built tree assembles AND links the witness, so this is NOT a reverted emitter"; fail=1
    else echo "  ✅ REVERT ARM: reverted emitter rejects the witness -- gate goes red as required"; fi
fi
if [ "$fail" -ne 0 ]; then echo "⛔ GATE FAILED: a symbol name can be silently truncated into a collision, or spelled two ways."; exit 1; fi
echo "✅ GATE OK: symbol names are never silently truncated; distinct names stay distinct symbols and one name is one spelling."
