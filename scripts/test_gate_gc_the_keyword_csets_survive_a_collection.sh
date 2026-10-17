#!/usr/bin/env bash
# test_gate_gc_the_keyword_csets_survive_a_collection.sh -- cfo, 2026-09-22, MODE QUARTET; row
# gc-a-wsb-result-string-handed-back-from-an-icon-builtin-through-out-is-not-rooted-across-a-later-collection.
#
# WHAT WAS THERE, AND IT WAS TWO HOLDERS OF ONE ADDRESS. &cset and &ascii are the only two keyword csets whose content
# carries a NUL byte, so they cannot go through make_kw_cset (which reads the registry by NAME and therefore always
# hands back the CURRENT pointer): kw_read built each one itself into a 257/129-byte HB_WSB block and remembered the
# block's ADDRESS in a function-local `static const char *cs`. The registry (g_kw_cset_names[i].ptr) is a visited root
# and moves correctly at every collection; that static is not a root and never moved. After one collection &cset handed
# out a pre-move address: measured as the SIGSEGV of procedure_coexpr_suspend_replace_3 at SCRIP_HEAP_MB=1 (the read
# landed on PROT_NONE ground the repl buffer had since occupied, which is why the vacated ledger named the repl block
# and not the cset -- a ledger entry names the LAST occupant of the ground, not the block the pointer meant).
# The second holder is the POINTER-KEYED index: kw_cset_gc_roots visits the .ptr fields, but g_kw_cset_hidx is keyed on
# their pre-move values and was never rebuilt, so kw_cset_find_ptr MISSED a perfectly current pointer after any
# collection, fell through to the content index -- which refuses a string starting with NUL -- and kw_cset_len returned
# -1, i.e. strlen() == 0 for both csets. `every !&cset` then yielded 0 to 24 of its 256 elements, rc=0, silently.
#
# WHAT IS HERE. kw_read caches the registry SLOT (an int, relocation-proof) instead of the address, and reuses the
# entry kw_cset_prime already registered rather than appending a second one; kw_cset_find_ptr rebuilds the pointer
# index when rt_gc_runs_count() moves, which is outside the collection and costs one pass per collection, not per
# lookup. No allocator changed: the cure for an unrooted holder is a root, never a different allocator.
#
# ARMS. (1) STRUCTURE, both directions: no raw `static const char *cs` cache remains in keywords.c, the two branches
# cache an int slot, and the generation-stamped index refresh exists and is reached from kw_cset_find_ptr. (2) BAND,
# both media: the witness matches its icont-cut ref at stress 0,1,3,5 under in a 128 KB arena, and
# EVERY arm reports collections>0 from the run's own report -- a tiny arena states a configuration, a collection count
# states an exercise. (3) LENGTH AFTER A MOVE: *&cset, *&ascii and *&lcase read the icont answer once the blocks have
# moved, which is kw_cset_find_ptr's own path rather than the bang's.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || exit 2
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
K="$ROOT/src/runtime/keywords.c"
WIT="$ROOT/../harness/scripts/gc_witnesses/hb_kw_cset_index_across_a_collection.icn"; REF="${WIT%.icn}.ref"
for f in "$K" "$WIT" "$REF"; do [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing $f"; exit 2; }; done
echo "  HOLDS: &cset and &ascii are found by the registry slot and the pointer index is rebuilt after a move, so a collection cannot make a keyword cset read as the empty string"
raw=$(grep -c 'static const char \*cs = NULL;' "$K")
slot=$(grep -c 'static int csi = -1;' "$K")
ref=$(grep -c 'kw_cset_hindex_refresh' "$K")
gen=$(grep -c 'rt_gc_runs_count' "$K")
if [ "$raw" = 0 ] && [ "$slot" -ge 2 ] && [ "$ref" -ge 2 ] && [ "$gen" -ge 1 ]; then echo "  arm 1 PASS: no raw address cache ($raw), both keyword branches cache a registry slot ($slot), the index refresh exists and is reached ($ref) and is stamped on the collection count ($gen)"
else echo "  arm 1 FAIL: raw_address_caches=$raw int_slot_caches=$slot index_refresh=$ref generation_stamp=$gen"; RC=1; fi
"$SCRIP" --compile -o "$T/w.s" "$WIT" >/dev/null 2>&1 && gcc "$T/w.s" -o "$T/w4" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 || { echo "  arm 2 REFUSE: the witness does not build in mode 4"; RC=1; }
want="$(cat "$REF")"; band=""; bad=0
for st in 0 1 3 5; do
  for md in m3 m4; do
    if [ "$md" = m3 ]; then out="$(cd "$T" && env SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=$st SCRIP_GC_EXERCISE=1 timeout -k 5 120 "$SCRIP" "$WIT" 2>"$T/e" </dev/null)"
    else out="$(cd "$T" && env SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=$st SCRIP_GC_EXERCISE=1 timeout -k 5 120 "$T/w4" 2>"$T/e" </dev/null)"; fi
    n=$(grep -m1 -oE 'collections=[0-9]+' "$T/e" | head -1 | cut -d= -f2)
    if [ "$out" = "$want" ] && [ "${n:-0}" -gt 0 ]; then band="$band @$st$md:ok($n)"; else band="$band @$st$md:RED(collections=${n:-0})"; bad=1; fi
  done
done
if [ "$bad" = 0 ]; then echo "  arm 2 PASS: the bang over &cset and &ascii yields all 256 and all 128 elements while every block relocates, both media --$band"
else echo "  arm 2 FAIL: a keyword cset bang is truncated or the collector never ran --$band"; RC=1; fi
printf 'procedure main()\n   local i, junk;\n   every i := 1 to 400 do junk := repl("q", 512);\n   write(*&cset, " ", *&ascii, " ", *&lcase);\nend\n' > "$T/len.icn"
( cd "$T" && "$ICONT" -s -o len len.icn >/dev/null 2>&1 ) && lw="$( cd "$T" && ./len 2>/dev/null )" || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle did not cut the length want"; exit 2; }
"$SCRIP" --compile -o "$T/len.s" "$T/len.icn" >/dev/null 2>&1 && gcc "$T/len.s" -o "$T/len4" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1
lb=""; lbad=0
for st in 0 5; do
  o3="$(cd "$T" && env SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=$st timeout -k 5 120 "$SCRIP" "$T/len.icn" 2>/dev/null </dev/null)"
  o4="$(cd "$T" && env SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=$st timeout -k 5 120 "$T/len4" 2>/dev/null </dev/null)"
  if [ "$o3" = "$lw" ] && [ "$o4" = "$lw" ]; then lb="$lb @$st:ok"; else lb="$lb @$st:m3=[$o3],m4=[$o4]"; lbad=1; fi
done
if [ "$lbad" = 0 ]; then echo "  arm 3 PASS: *&cset *&ascii *&lcase read the icont answer [$lw] after the blocks have moved, both media --$lb"
else echo "  arm 3 FAIL: a keyword cset reads the wrong length after a move (icont says [$lw]) --$lb"; RC=1; fi
[ "$RC" = 0 ] && echo "✅ GATE PASS [$G]: 3 of 3 arms hold" || echo "⛔ GATE FAIL [$G]"
exit $RC
