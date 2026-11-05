#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_the_icon_list_type_is_one_static_record_registered_once.sh -- AN ICON LIST'S TYPE RECORD IS ONE STATIC DATBLK_t OFF THE HEAP, LINKED INTO THE TYPE
# REGISTRY ONCE AT START-UP (the cto, CTO-510, 2026-11-04, option A, row icon-lists-tables-and-record-fields-are-built-and-read-in-c-from-the-emitted-site-r-1969,
# step 1 slice A1; STATE-GLOBAL under CTO-501). Before it five C sites each guarded a DEFDAT_fn("list(...)") with a static flag and the record was an HB_DATB heap
# block the compactor moved, so no box or leaf could hold its address.
# FOUR READINGS: (a) no DEFDAT_fn("list( ... ") call remains anywhere under src/ (the registry is not asked for the list type by spelling it again); (b) core.c defines
# g_rt_list_type exactly once and calls rt_list_type_install exactly once, from core_lib_init; (c) the built library defines g_rt_list_type in a WRITABLE data section
# (nm class D or d: its serial counter moves) and defines no second symbol of that name; (d) the numbering an Icon program reads is Arizona's: [] and [] are
# list_1 and list_2, then 300 lists [i] are list_3 .. list_302 (cut from icont 9.5.25a), in mode 3, in mode 4 and under SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_FLIP=1.
# Usage: bash ../harness/scripts/test_gate_the_icon_list_type_is_one_static_record_registered_once.sh    (exit 0 green, 1 measured broken, 2 could not measure)
set -u
NAME=test_gate_the_icon_list_type_is_one_static_record_registered_once
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
SO="$ROOT/out/libscrip_rt.so"
[ -x "$ROOT/scrip" ] || { echo "REFUSE(2): scrip is not built"; exit 2; }
[ -e "$SO" ] || { echo "REFUSE(2): $SO is missing"; exit 2; }
[ -f "$ROOT/src/runtime/core/core.c" ] || { echo "REFUSE(2): no src/runtime/core/core.c"; exit 2; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
red=0
n_def=$(grep -rn 'DEFDAT_fn("list(' "$ROOT/src" --include=*.c --include=*.cpp --include=*.h | wc -l)
if [ "$n_def" -eq 0 ]; then echo "  ok    (a) no DEFDAT_fn(\"list(\") call remains under src/"; else echo "  FAIL  (a) $n_def DEFDAT_fn(\"list(\") call(s) remain under src/:"; grep -rn 'DEFDAT_fn("list(' "$ROOT/src" --include=*.c --include=*.cpp --include=*.h | cut -c1-150; red=1; fi
n_rec=$(grep -c '^DATBLK_t g_rt_list_type = ' "$ROOT/src/runtime/core/core.c")
n_ins=$(grep -c 'rt_list_type_install();' "$ROOT/src/runtime/core/core.c")
if [ "$n_rec" -eq 1 ] && [ "$n_ins" -eq 1 ]; then echo "  ok    (b) core.c defines g_rt_list_type once and calls rt_list_type_install once"; else echo "  FAIL  (b) core.c: $n_rec definition(s) of g_rt_list_type, $n_ins call(s) of rt_list_type_install"; red=1; fi
cls=$(nm "$SO" 2>/dev/null | awk '$3 == "g_rt_list_type" {print $2}' | tr '\n' ' ')
if [ "$cls" = "D " ] || [ "$cls" = "d " ]; then echo "  ok    (c) the library defines g_rt_list_type once, in writable data (class $cls)"; else echo "  FAIL  (c) the library defines g_rt_list_type as [${cls}] (want exactly one D or d)"; red=1; fi
cat > "$WORK/lt.icn" <<'EOF'
procedure main()
    local a, b, i;
    a := [];
    b := [];
    write(image(a), " ", image(b));
    every i := 1 to 300 do put(a, [i]);
    write(*a, " ", image(a[1]), " ", image(a[300]));
end
EOF
printf 'list_1(0) list_2(0)\n300 list_3(1) list_302(1)\n' > "$WORK/lt.ref"
( cd "$WORK" && timeout -k 5 60 "$ROOT/scrip" --compile --out="$WORK/lt.s" "$WORK/lt.icn" < /dev/null > /dev/null 2>&1 && gcc "$WORK/lt.s" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o "$WORK/lt.bin" 2> /dev/null ) || { echo "REFUSE(2): could not compile the numbering witness"; exit 2; }
for env in "" "SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_FLIP=1"; do
    env $env timeout -k 5 120 "$ROOT/scrip" "$WORK/lt.icn" < /dev/null 2>&1 | grep -v '^\[GC-' > "$WORK/m3.out"
    env $env timeout -k 5 120 "$WORK/lt.bin" < /dev/null 2>&1 | grep -v '^\[GC-' > "$WORK/m4.out"
    for m in m3 m4; do
        if cmp -s "$WORK/$m.out" "$WORK/lt.ref"; then echo "  ok    (d) $m [${env:-no stress}] reads Arizona's list numbering"; else echo "  FAIL  (d) $m [${env:-no stress}] differs from Arizona's numbering:"; diff "$WORK/$m.out" "$WORK/lt.ref" | head -4; red=1; fi
    done
done
if [ "$red" -eq 0 ]; then echo "GATE OK [$NAME]: one static record, registered once, in writable data, numbering as Arizona's in both modes and under the flip plant"; exit 0; fi
echo "GATE FAIL [$NAME]"
exit 1
