#!/usr/bin/env bash
# test_gate_icn_argcheck_filter_admits_every_table_row.sh -- the two-byte rejection filter in front of
# core_icn_builtin_argcheck() (src/runtime/core/core.c) must NEVER reject a name the table would have matched.
#
# WHY THIS GATE EXISTS. argcheck used to walk all 17 table rows on EVERY strict builtin call; the walk was
# 26.75M of its 28.85M Ir on the deal benchmark (92.7% of the function), because the hot Icon names all share
# their FIRST byte with a table row -- map/move, write/where, left/left, push/pos, string/seek -- so an earlier
# 256-entry first-byte filter rejected NOTHING and measured as no change at all. The cure keys on TWO bytes.
#
# WHAT COULD GO WRONG, AND IT IS THE ONLY THING THAT COULD. The filter is a 64-bit bloom over (c0,c1). A false
# POSITIVE is harmless -- the row scan runs exactly as before and decides. A false NEGATIVE would silently skip
# an argument type check, turning a required runtime error into a wrong answer. The rows and the mask are
# generated from ONE macro list (ICN_ARGCHK_ROWS) precisely so they cannot drift apart, but the per-row key
# CHARS are written beside each name by hand -- 'trim','t','r' -- and C offers no way to assert at compile time
# that 't','r' really are "trim"[0] and "trim"[1] (a string-literal subscript is not a constant expression;
# _Static_assert rejects it). So that one hand-written pairing is the live drift hazard, and this gate is what
# stands under it.
#
# HOW IT CHECKS: it lifts the REAL macro block out of core.c -- never a copy kept in this file, which would
# drift in exactly the way the gate exists to catch -- splices it into a harness, and proves two things by
# execution: (1) every row's c0/c1 equal the first two bytes of that row's own string literal, and
# (2) exhaustively over all 65,280 two-byte prefixes, every prefix any row matches is admitted by the mask.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
SRC=src/runtime/core/core.c
# REFUSES rc=2 WHEN IT CANNOT MEASURE -- never skip-as-success (RULES.md: a test that cannot measure refuses).
[ -f "$SRC" ] || { echo "GATE REFUSED (rc=2): $SRC not found from $ROOT -- nothing was checked" >&2; exit 2; }
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED (rc=2): no gcc -- the proof is compiled, not grepped" >&2; exit 2; }
T=$(mktemp -d) || { echo "GATE REFUSED (rc=2): no temp dir" >&2; exit 2; }
trap 'rm -rf "$T"' EXIT
# Lift the three macros from the source. A line-count check keeps a silent partial extraction from reading as a pass.
sed -n '/^#define ICN_ARGCHK_ROWS(X)/,/^#define ICN_ARGCHK_HASH/p' "$SRC" > "$T/block.h"
rows=$(grep -o 'X("' "$T/block.h" 2>/dev/null | wc -l)
[ "$rows" -ge 1 ] || { echo "GATE REFUSED (rc=2): extracted 0 table rows from $SRC -- the macro block moved or was renamed, so this gate proved NOTHING" >&2; exit 2; }
grep -q '^#define ICN_ARGCHK_BIT' "$T/block.h" || { echo "GATE REFUSED (rc=2): ICN_ARGCHK_BIT not in the extracted block -- cannot rebuild the mask" >&2; exit 2; }
grep -q '^#define ICN_ARGCHK_HASH' "$T/block.h" || { echo "GATE REFUSED (rc=2): ICN_ARGCHK_HASH not in the extracted block -- cannot rebuild the hash" >&2; exit 2; }
cat > "$T/p.c" <<'EOF'
#include <stdio.h>
#include "block.h"
#define ICN_ARGCHK_ROW(s,a,b,i,w,d) {s, a, b, i, w, d},
static const struct { const char *nm; char c0; char c1; int idx; char want; int defaults; } tbl[] = {
    ICN_ARGCHK_ROWS(ICN_ARGCHK_ROW) {(const char *)0,0,0,0,0,0}};
int main(void){
    const unsigned long long present = 0ull ICN_ARGCHK_ROWS(ICN_ARGCHK_BIT);
    int bad = 0, n = 0;
    for (int i = 0; tbl[i].nm; i++) { n++;
        if (tbl[i].nm[0] != tbl[i].c0 || tbl[i].nm[1] != tbl[i].c1) {
            printf("ROW CHARS DISAGREE WITH THE NAME: \"%s\" carries '%c','%c' but its first two bytes are '%c','%c'\n",
                   tbl[i].nm, tbl[i].c0, tbl[i].c1, tbl[i].nm[0], tbl[i].nm[1]); bad = 1; } }
    long fneg = 0, pairs = 0;
    for (int a = 1; a < 256; a++) for (int b = 0; b < 256; b++) {
        int scan = 0;
        for (int i = 0; tbl[i].nm; i++) if ((unsigned char)tbl[i].c0 == a && (unsigned char)tbl[i].c1 == b) scan = 1;
        if (!scan) continue;
        pairs++;
        if (!((present >> ICN_ARGCHK_HASH((char)a,(char)b)) & 1ull)) {
            printf("FALSE NEGATIVE: prefix '%c','%c' is matched by a table row but the filter rejects it\n", a, b);
            fneg++; } }
    if (bad || fneg) { printf("RED: %d row(s) checked, %ld matched prefix pair(s), %ld false negative(s)\n", n, pairs, fneg); return 1; }
    printf("GREEN: %d rows, chars agree with their names, %ld matched prefix pairs, 0 false negatives over 65280 prefixes\n", n, pairs);
    return 0;
}
EOF
gcc -O0 -I"$T" -o "$T/p" "$T/p.c" 2>"$T/err" || { echo "GATE REFUSED (rc=2): the lifted macro block does not compile -- nothing was proven:" >&2; sed -n '1,6p' "$T/err" >&2; exit 2; }
out=$("$T/p"); rc=$?
echo "$out"
[ "$rc" -eq 0 ] || { echo "GATE RED: core_icn_builtin_argcheck's filter can skip a required argument check" >&2; exit 1; }
echo "GATE GREEN: argcheck two-byte filter admits every prefix its table matches ($rows rows lifted from $SRC)"
exit 0
