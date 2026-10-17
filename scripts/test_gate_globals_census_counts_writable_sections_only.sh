#!/usr/bin/env bash
# ../harness/scripts/test_gate_globals_census_counts_writable_sections_only.sh -- the globals census counts STATE, never a constant:
# a data symbol in .rodata or .data.rel.ro leaves the count, and one in .data, .bss or their TLS twins stays.
#
# THE RULING (ceo CEO-1575, 2026-10-09, row compiler-globals-collect-into-g-parser-g-lower-g-emitter-g-template-structs-
# lons-housekeeping-ceo-1561): "a table never written is not state" -- it is const-qualified to the pointer in its stage's
# landing so the compiler proves it, never exempted by name, and the census reads SECTIONS (.rodata and .data.rel.ro are
# constants, not globals) as test_gate_pl_no_new_global.sh does since 9e50691a0; the bar of 4 then counts mutable state
# only; "the census re-cut lands first, proven once red on a planted mutable and once green".
#
# THE DEFECT IT CLOSES: audit_runtime_globals_census.py took nm classes B D b d, and nm's d/D also cover .data.rel.ro, so a
# table const-qualified to the pointer still counted as a global and the compiler row's bar of 4 would have forced
# constant lookup tables into mutable structs.
#
# THE ARMS, on a fixture library built in a temp root (src/lower/plant.c, compiled -g -fPIC -shared, read through the
# census's --root), never on the tree's own library: (0) the fixture's constants really sit in .rodata and .data.rel.ro by
# objdump -t, or the gate refuses rc=2 (a fixture that never reached those sections proves nothing by passing); (1) GREEN:
# constants only, census --tree compiler --all --max 0 rc 0 and no constant named; (2) RED: the same file plus a planted
# mutable int and a planted table with writable slots (static const char *t[] -- the pointers are state), rc 1 naming
# both plants and no constant.
#
# Usage: bash ../harness/scripts/test_gate_globals_census_counts_writable_sections_only.sh
set -uo pipefail
GATE_NAME=test_gate_globals_census_counts_writable_sections_only
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
for t in python3 nm objdump gcc; do command -v "$t" >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: $t is not on PATH"; exit 2; }; done
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/src/lower" "$T/out"
build() {
    { printf 'static const int g_k_rodata = 7;\nstatic const char *const g_k_relro[] = {"a", "b"};\nconst char *const g_k_relro_ext[] = {"c"};\n'
      [ "$1" = planted ] && printf 'int g_planted_mutable;\nstatic const char *g_planted_table[] = {"x"};\n'
      printf 'int plant_use(int i) { return g_k_rodata + g_k_relro[i][0] + g_k_relro_ext[0][0]%s; }\n' "$([ "$1" = planted ] && echo ' + g_planted_mutable + g_planted_table[0][0]')"
    } > "$T/src/lower/plant.c"
    rm -f "$T/out/libscrip_rt.so"
    gcc -O0 -g -fPIC -shared -o "$T/out/libscrip_rt.so" "$T/src/lower/plant.c" 2> "$T/cc.err" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the $1 fixture did not compile"; cat "$T/cc.err"; exit 2; }
}
census() { python3 "$HERE/audit_runtime_globals_census.py" --root "$T" --tree compiler --all --max 0 > "$T/census.out" 2>&1; echo $?; }
echo "=== globals census counts writable sections only ==="
build constants
SECT="$(objdump -t "$T/out/libscrip_rt.so" | awk '$NF ~ /^g_k_/ { for (i = 1; i <= NF; i++) if ($i == "O") print $(i + 1), $NF }')"
grep -q '^\.rodata ' <<< "$SECT" && grep -q '^\.data\.rel\.ro' <<< "$SECT" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the fixture's constants did not reach both .rodata and .data.rel.ro:"; echo "$SECT"; exit 2; }
rc="$(census)"
if [ "$rc" != 0 ] || grep -q 'g_k_' "$T/census.out"; then
    echo "  FAIL  (1) constants only: census rc=$rc (want 0) or it named a constant:"; sed 's/^/        /' "$T/census.out"; exit 1
fi
echo "  ok    (1) constants only ($(tr '\n' ' ' <<< "$SECT")): census GREEN at --max 0, no constant counted"
build planted
rc="$(census)"
if [ "$rc" != 1 ] || ! grep -q 'g_planted_mutable' "$T/census.out" || ! grep -q 'g_planted_table' "$T/census.out" || grep -q 'g_k_' "$T/census.out"; then
    echo "  FAIL  (2) planted: census rc=$rc (want 1), it must name g_planted_mutable and g_planted_table and no constant:"; sed 's/^/        /' "$T/census.out"; exit 1
fi
echo "  ok    (2) planted mutable and writable-slot table: census RED rc=1 naming both, no constant counted"
echo "PASS [$GATE_NAME]: the census counts .data/.bss state and leaves .rodata/.data.rel.ro constants out (CEO-1575)"
exit 0
