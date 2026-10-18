#!/usr/bin/env bash
# test_gate_gc_the_cset_registry_is_rooted.sh -- THE INTERNED CSET BYTES ARE ON THE COLLECTED HEAP AND THE ONLY POINTER AT THEM LIVES IN THE ARENA.
# ⛔ THE MEASURED DEFECT (cfo 2026-09-18, found by re-auditing my own fourteen-holder list against "persistence is not reachability"):
# kw_cset_intern (keywords.c) allocates the canonical cset bytes with rt_ws_alloc -- the COLLECTED HEAP -- and stores the pointer into
# g_kw_cset_names[i].ptr, an entry in a ct_grow'd ARENA table. g_kw_cset_names is named nowhere outside keywords.c, keywords.c contained no
# gc walk at all, and NONE of the eight walks the root phase calls touched it. So the bytes were unmarked at every collection and the slot
# was never registered for update, which is the g_name_save shape one table over.
# ⛔ WITNESS, AND IT IS A WRONG ANSWER RATHER THAN A CRASH, WHICH IS WHY NO CRASH-SHAPED ARM WOULD EVER HAVE FOUND IT: an Icon cset UNION
# reads *c = 26 or 256 instead of 16, with a NUL inside the cset. Measured on origin at SCRIP ad42031a9 RED at stress 1,2,3,4,5,8,10 and
# GREEN at 0,15,20,30,50,100 -- a RAGGED BAND, so a two-point DONE-WHEN at 30 and 200 reads clean and banks the defect (CEO-807).
# THE CURE is kw_cset_gc_roots(), called from the root phase, visiting every entry's ptr and name through rt_gc_visit_raw -- which
# range-checks, so a registered pointer into the emitted string table is a safe no-op, and which calls gc_slot_reg so the slot is UPDATED
# when the block moves rather than merely marked.
# ⛔ THE FACT-RULE ARM IS WHY THIS GATE CANNOT BE GREENED THE WRONG WAY (the shape of the cfo's own reverted f62a33aed): it REQUIRES
# kw_cset_intern to still allocate from the COLLECTED HEAP. Moving the interned bytes to the arena or to libc would make the band green
# while taking the object out of the collector's sight, which is the same evasion as pinning it, one name further out.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || exit 2
bash ../harness/scripts/util_require_fresh.sh >/dev/null 2>&1 || { echo "REFUSES rc=2: stale or missing ./scrip -- run make"; exit 2; }
bad=0
if grep -qE 'rt_wsb?_alloc|rt_ws_alloc_descr' src/runtime/keywords.c && ! grep -qE '\b(malloc|calloc|realloc|strdup)\b' src/runtime/keywords.c; then echo "  FACT-RULE PASS: kw_cset_intern still allocates the interned bytes on the COLLECTED heap (rt_ws_alloc or its atomic sibling rt_wsb_alloc -- same rt_gcheap_alloc, same marking, same relocation, only the interior scan differs) AND the interned bytes reach no libc allocator"
else echo "  FACT-RULE RED: keywords.c either stopped allocating on the collected heap or reached an off-heap allocator -- the band may be green because the bytes left the collector's sight, which is the evasion this gate exists to refuse (⛔ rt_wsb_alloc is NOT that evasion: it is rt_gcheap_alloc of kind HB_WSB and test_gate_gc_the_decidable_test grades it with SENSITIVITY DETECTED)"; bad=1; fi
n=$(awk '/^void kw_cset_gc_roots\(void\)/{f=1} f&&/rt_gc_visit_raw/{c++} f&&/^}/{exit} END{print c+0}' src/runtime/keywords.c)
if [ "$n" -ge 2 ]; then echo "  structural PASS: kw_cset_gc_roots visits $n slot kind(s) per entry"; else echo "  structural RED: kw_cset_gc_roots does not visit the registry's ptr and name"; bad=1; fi
grep -q 'kw_cset_gc_roots();' src/runtime/rt/gc_heap.c || { echo "  structural RED: kw_cset_gc_roots is never called from the collector's root phase -- a walk nothing calls is not a root"; bad=1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/c.icn" <<'EOS'
procedure main();
   local i, s, c;
   c := cset("abcdefgh") ++ cset("ijklmnop");
   write(*c);
   c := &null;
   every i := 1 to 400 do s := repl("z", 200);
   c := cset("abcdefgh") ++ cset("ijklmnop");
   write(*c);
   write(c);
end
EOS
red=0; ran=0
for st in 0 1 2 3 4 5 8 10 15 20 30 50 100 200; do
    ( cd "$W" && SCRIP_GC_STRESS=$st timeout -k 5 90 "$ROOT/scrip" c.icn > o.txt 2> e.txt ); rc=$?
    ran=$((ran + 1))
    n1=$(sed -n 1p "$W/o.txt"); n2=$(sed -n 2p "$W/o.txt"); cs=$(tr -d '\0' < "$W/o.txt" | sed -n 3p)
    if [ "$rc" -ne 0 ] || [ "$n1" != "16" ] || [ "$n2" != "16" ] || [ "$cs" != "abcdefghijklmnop" ]; then
        echo "      stress=$st rc=$rc size_before=$n1 size_after=$n2 cset=[$cs] -- want 16/16/abcdefghijklmnop"; red=$((red + 1)); fi
done
if [ "$ran" -lt 14 ]; then echo "REFUSES rc=2: only $ran of 14 band points ran"; exit 2; fi
if [ "$red" -eq 0 ]; then echo "  behavioural PASS: the cset union is byte-correct at all $ran stress points (origin is RED at 1,2,3,4,5,8,10)"
else echo "  behavioural RED: $red of $ran band points wrong -- the interned cset bytes are not surviving collection"; bad=1; fi
if [ "$bad" -ne 0 ]; then echo "GATE FAIL(1) [gc_the_cset_registry_is_rooted]: the cset registry is not a root"; exit 1; fi
echo "GATE PASS(0) [gc_the_cset_registry_is_rooted]: the interned cset bytes survive collection and the registry is walked (3 arms + a 14-point band, 0 red)"
