#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_pas_every_frame_slot_has_a_kind.sh -- row gc-every-zeta-slot-of-a-pascalpas-graph-registers-its-kind-in-frame-layout (ceo, 2026-09-17, CEO-820;
# EMERGENCY GC RESET, ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 7 F1: the collector guesses nothing, every frame word carries a
# compile-time kind).  POPULATION: every entry of the Pascal rung suite(s), extracted through the harness's own readers and laid out by
# `scrip --dump-zeta`; util_zls_frame_map_census.py reports every word of the zls region no zls_field covers (region-gap, scope-gap,
# overlap, vslot-unmapped, provisional-kind, unknown-kind).  FAIL-ONCE ON ORIGIN 162e8a172: the return-value cell IR_RETURN writes at
# frame +0 was unregistered in every function graph (raku 318, pascal 514, icon 304, prolog 88364 holes) and two Icon pad quads were
# unregistered (scanseq +8, revswap +56); all registered at this landing, every rung suite reads holes=0.
# THE DETECTOR ARM (re-cut 2026-10-14, hq_raku, CEO-1680 + the cto's yes): the one-function fixture is dumped once by
# `--dump-zeta`; the census must read that saved text green (--dumps), and with its first field line dropped by this gate it
# must read rc 1, or this gate REFUSES rc=2. The old SCRIP_TEST_PLANT_ZLS_HOLE seam in zls_dump is deleted: no plant in SCRIP -- a detector that fails open
# reads as "there was never a bug here".  NOT CENSUSED HERE, said so the reader does not over-read a green: the emitter's wire header
# past region_end (saved continuations and rsp) and the spine cells are the cto's F6 step-2 map cell and DESCR discipline.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="${SCRIP:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)/scrip}"
CENSUS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_zls_frame_map_census.py"
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "$SCRIP" "the scrip compiler"
gate_require "$CENSUS" "the frame-map census util_zls_frame_map_census.py"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT
RED=0; SUMMARY=""
for lang in pascal; do
  python3 "$CENSUS" --lang "$lang" > "$W/$lang.txt" 2>&1; rc=$?
  line=$(grep "^zls-frame-map-census\[$lang\]:" "$W/$lang.txt" | tail -1)
  case "$rc" in
    0) echo "PASS $lang: ${line#*: }";;
    1) echo "FAIL $lang: ${line#*: }"; grep '^HOLE' "$W/$lang.txt" | head -20; RED=$((RED+1));;
    *) echo "REFUSE(2) [$(basename "$0" .sh)]: the census could not grade $lang (rc=$rc)"; tail -3 "$W/$lang.txt"; exit 2;;
  esac
  SUMMARY="$SUMMARY $lang=$(echo "$line" | sed -n 's/.* graded=\([0-9]*\) .* holes=\([0-9]*\) .*/holes \2 over \1 graded/p')"
done
cat > "$W/plant.pas" <<'FIX'
program plant;
function add(a, b: integer): integer;
begin add := a + b end;
begin writeln(add(1, 2)) end.
FIX
python3 "$CENSUS" --files "$W/plant.pas" > "$W/clean.txt" 2>&1; rc_clean=$?
if [ "$rc_clean" -ne 0 ]; then echo "FAIL fixture: the one-function fixture is not clean (rc=$rc_clean)"; grep '^HOLE' "$W/clean.txt" | head -5; RED=$((RED+1)); fi
"$SCRIP" --dump-zeta "$W/plant.pas" < /dev/null > "$W/plant.zeta" 2>&1 || { echo "REFUSE(2) [$(basename "$0" .sh)]: --dump-zeta of the one-function fixture failed, so the detector arm has no dump to corrupt"; tail -2 "$W/plant.zeta"; exit 2; }
python3 "$CENSUS" --dumps "$W/plant.zeta" > "$W/dump_clean.txt" 2>&1; rc_dclean=$?
if [ "$rc_dclean" -ne 0 ]; then echo "REFUSE(2) [$(basename "$0" .sh)]: the census read the fixture's saved dump rc=$rc_dclean, wanted 0 -- the --dumps reader disagrees with the compiler run, so the corrupted arm would grade nothing"; tail -2 "$W/dump_clean.txt"; exit 2; fi
awk 'gone || !/^;     \+/ { print; next } { gone = 1 }' "$W/plant.zeta" > "$W/hole.zeta"
if cmp -s "$W/plant.zeta" "$W/hole.zeta"; then echo "REFUSE(2) [$(basename "$0" .sh)]: the fixture's dump carries no field line to drop, so the detector arm corrupted nothing"; exit 2; fi
python3 "$CENSUS" --dumps "$W/hole.zeta" > "$W/plant.txt" 2>&1; rc_plant=$?
if [ "$rc_plant" -ne 1 ]; then echo "REFUSE(2) [$(basename "$0" .sh)]: the detector arm did not fire -- the fixture's dump with its first field line dropped read rc=$rc_plant, wanted 1 (a census that cannot see a corrupted map cannot be trusted with the real ones)"; tail -2 "$W/plant.txt"; exit 2; fi
echo "gc-pas-every-frame-slot-has-a-kind:$SUMMARY fixture=clean corrupted-dump=RED(rc=1) (population: the Pascal rungs entries that lay out, both arms; the wire header past region_end and the spine are not censused)"
if [ "$RED" -eq 0 ]; then echo "GATE PASS(0) [$(basename "$0" .sh)]: 0 holes in every graded Pascal graph"; exit 0; else echo "GATE RED [$(basename "$0" .sh)]: $RED red arm(s)"; exit 1; fi
