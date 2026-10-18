#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_the_asm_allocator_carves_reused_ground_after_a_collection.sh -- THE ARMED ASM CARVE (rtx_alloc.s) USED TO REFUSE ANY
# BLOCK BELOW THE VIRGIN MARK, so after the first collection EVERY allocation of the process fell to c_rt_gcheap_alloc: table_access
# at the shipped 128 KB arena made 398,079 allocations and the C entry answered 398,079 of them, ~250 Ir each against ~35 in the
# armed path (ceo 2026-09-25, CEO-1256; callgrind of the 60-iteration twin). Since this landing the armed path carves reused ground
# too: it zeroes the payload in line (the tail 32 bytes of a string, the whole payload otherwise, exactly as rt_gcheap_carve does),
# keeps the virgin mark the maximum it ever was, and stops at g_hp_fr.line, which is now the LOWER of the pacing line and the
# quarantine's low bound (gc_fr_line_sync), so it can never carve into PROT_NONE ground; C is reached only at a line or quarantine
# boundary. THE MEASUREMENT: gdb counts the C entry's hits over a churning witness at 128 KB (a breakpoint with an ignore count)
# beside the collection count; the bound is a few C entries per collection, where the old behaviour is one per allocation.
# ARMS: (1) the witness prints the oracle's answer under the shipped arena; (2) collections >= 50 (else the population is a
# refusal); (3) C entry hits <= 8 * collections + 64. FAIL_ONCE (recorded): the pre-cure runtime at 0f560a28e read 398,079 hits
# over 2,482 collections; this tree reads 4,965 (two per collection: the pacing line and the quarantine boundary).
# EXIT 0 all arms; 1 a red (named); 2 REFUSED (gdb, sbl or the build missing, or too few collections to grade).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
command -v gdb >/dev/null 2>&1 || { echo "REFUSED(2): gdb missing -- the C-entry hit count is read through a breakpoint ignore count"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/churn.sno" <<'SNO'
        &TRIM = 1
        DEFINE('fill(n)t,i')                            :(fill_end)
fill    t = TABLE(512)
        i = 1
fill_1  t[i] = 'v' i
        i = LT(i, 500) i + 1                            :S(fill_1)
        fill = t                                        :(RETURN)
fill_end
        k = 0
loop    t = fill()
        s = s SIZE(t[7]) '-'
        k = LT(k, 400) k + 1                            :S(loop)
        OUTPUT = SIZE(s) ' ' t[250] ' ' k
END
SNO
"$SBL" $(sbl_lang_flags) "$W/churn.sno" < /dev/null > "$W/churn.ref" 2>&1 || true
[ -s "$W/churn.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
( cd "$W" && "$ROOT/scrip" --compile -o "$W/churn.s" churn.sno < /dev/null > /dev/null 2>&1 ) || { echo "REFUSED(2): the witness did not compile"; exit 2; }
gcc "$W/churn.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/churn.bin" 2>/dev/null || { echo "REFUSED(2): the witness did not link"; exit 2; }
red=0
unset SCRIP_HEAP_MB; export SCRIP_HEAP_KB=128
( cd "$W" && SCRIP_GC_EXERCISE=1 timeout -k 5 60 ./churn.bin < /dev/null > "$W/churn.out" 2> "$W/churn.err" )
cmp -s "$W/churn.out" "$W/churn.ref" && echo "ok  (1) the witness prints the oracle's answer at SCRIP_HEAP_KB=128: $(cat "$W/churn.ref")" || { echo "RED (1) the witness differs from the oracle:"; diff "$W/churn.ref" "$W/churn.out" | head -4; red=1; }
coll=$(grep -o 'collections=[0-9]*' "$W/churn.err" | head -1 | cut -d= -f2); coll=${coll:-0}
[ "$coll" -ge 50 ] || { echo "REFUSED(2): only $coll collections at 128 KB -- the population cannot grade an after-collection allocator"; exit 2; }
echo "ok  (2) collections=$coll (population)"
hits=$( cd "$W" && timeout -k 5 300 gdb -q -batch -ex 'set breakpoint pending on' -ex 'break c_rt_gcheap_alloc' -ex 'ignore 1 100000000' -ex 'run < /dev/null > /dev/null 2>&1' -ex 'info breakpoints' ./churn.bin 2>&1 | grep -o 'already hit [0-9]* time' | grep -o '[0-9]*' | head -1 )
[ -n "$hits" ] || { echo "REFUSED(2): gdb did not report a hit count for c_rt_gcheap_alloc"; exit 2; }
bound=$((8 * coll + 64))
if [ "$hits" -le "$bound" ]; then echo "ok  (3) c_rt_gcheap_alloc hits=$hits <= 8*collections+64=$bound: after a collection the armed asm carve serves the allocations"
else echo "RED (3) c_rt_gcheap_alloc hits=$hits > $bound over $coll collections: allocations below the virgin mark are falling to the C entry again"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: the armed asm allocator carves reused ground; C is entered only at the line and quarantine boundaries"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
