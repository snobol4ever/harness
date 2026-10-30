#!/usr/bin/env bash
# test_gate_shared_builtin_id_table_is_self_consistent.sh -- the builtin-id numbering is an ABI between
# EMITTED CODE and the RUNTIME, and until this gate nothing checked it in either direction.
#
# THE CONTRACT (row shared-the-baked-builtin-id-in-emitted-code-has-no-gate-revalidating-it-against-the-name,
# filed by hq_I on hq_U's request): bid_bake_of() bakes (namelen << 16 | bid) into a mov32 immediate in the
# emitted code -- from TWO byte-identical hand-written copies, src/templates/bb/bb_call.cpp and
# bb_call_fn.cpp -- and try_call_builtin_by_name_bl reads it back as
#   _fnlen = bidlen >> 16 ; _bid = bidlen & 0xFFFF
# taking BOTH fields from the immediate and never consulting fn. A .s artifact baked under one numbering and
# linked against a libscrip_rt.so built under another dispatches A DIFFERENT BUILTIN with no diagnostic.
#
# builtin-table step 1 (CEO-2016): the 190 names now live in the GENERATED src/runtime/builtin_table.h as bt_legacy_tab (the same nm, len, id fields, BT_LEGACY_TABSZ slots), bid_of IS bt_bid_legacy; this gate reads that table.
# ⛔ WHAT THIS GATE DOES AND DOES NOT COVER, said plainly so nobody reads it as more than it is. It pins the
# TABLE: every name round-trips through the REAL bid_of to its own id, every stored len equals the real
# strlen, no two names share an id, and the entry count never falls below the floor. It does NOT validate a
# baked immediate against fn at dispatch time -- that check costs exactly what baking saves (g_bid_tab is
# HASH-indexed, not id-indexed, so recovering the name from a bid means the hash lookup the bake exists to
# avoid) and it is named as the open remainder rather than pretended away.
#
# ⛔⛔ THE ENTRY FLOOR IS THE LOAD-BEARING ARM AND HERE IS THE MEASUREMENT BEHIND IT. ../harness/scripts/gen_builtin_ids.py
# is a SPENT ONE-SHOT MIGRATION, not a regenerator: it harvests !strcmp(fn,"...") sites and REWRITES them into
# (_bid == BID_...) comparisons, so the sites it feeds on are the ones it already consumed. It exits rc=1
# today only because its FUNC_RE anchors on a DECLARATION at column 0 rather than the definition. MEASURED
# 2026-09-11 by hq_U on a scratch copy, with the anchor corrected to the real definition and declarations
# skipped: it runs rc=0 and writes a table of NINE names where the committed one has 188 -- it would delete
# 179 ids and renumber what survived. So "repair the anchor" is the catastrophe and not the cure, and the
# floor below is what turns that from a silent 95% deletion into a red arm.
#
# ⭐ AND BID_LAST IS THE LARGEST ID (coo 2026-09-25, row snobol4-g-bn-direct-is-indexed-by-a-baked-builtin-id-...,
# ceo CEO-1270): builtin_ids.h asserts at compile time that BID_LAST < BID_TABSZ, because rtx_misc.s indexes the
# BID_TABSZ-row g_bn_direct (0f560a28e) by the baked id masked 0x3FFF, so an id past 1023 would read outside it
# instead of failing to build. The assertion is only as good as BID_LAST, and this checker holds BID_LAST to the
# largest id the table actually carries -- a hand-added builtin that forgets to move it reds here.
# ⭐ IT USES THE REAL HEADER AND THE REAL bid_of RATHER THAN REIMPLEMENTING THE HASH -- a second copy of the
# djb2 walk in this gate would be a third hand-written copy of the very contract the row is about, and would
# agree with itself while the tree drifted.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
NAME=shared_builtin_id_table_is_self_consistent
FLOOR=188
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
HDR="$ROOT/src/runtime/builtin_ids.h"
[ -f "$HDR" ] || refuse "no builtin_ids.h at $HDR -- cannot measure"
command -v gcc >/dev/null 2>&1 || refuse "no gcc -- cannot compile the checker, cannot measure"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/bidcheck.c" <<'EOF'
#include <stdio.h>
#include <string.h>
#include "builtin_ids.h"
int main(void) {
    int seen = 0, bad = 0, dup = 0, maxid = 0;
    static char idseen[65536]; static const char *idname[65536];
    for (int i = 0; i < BT_LEGACY_TABSZ; i++) {
        const char *n = bt_legacy_tab[i].nm;
        if (!n) continue;
        seen++;
        unsigned L = (unsigned)strlen(n);
        if (L != (unsigned)bt_legacy_tab[i].len) { printf("  BAD len: %s stored=%u real=%u\n", n, (unsigned)bt_legacy_tab[i].len, L); bad++; }
        if (bid_of(n, L) != bt_legacy_tab[i].id) { printf("  BAD roundtrip: %s id=%d bid_of=%d\n", n, (int)bt_legacy_tab[i].id, bid_of(n, L)); bad++; }
        int id = (int)bt_legacy_tab[i].id;
        if (id <= 0 || id >= 65536) { printf("  BAD id range: %s id=%d\n", n, id); bad++; continue; }
        if (idseen[id]) { printf("  DUPLICATE id %d: %s and %s\n", id, idname[id], n); dup++; }
        idseen[id] = 1; idname[id] = n;
        if (id > maxid) maxid = id;
    }
    if (maxid != BID_LAST) { printf("  BAD BID_LAST=%d but the largest id in bt_legacy_tab is %d -- point BID_LAST at the largest id, or the static assertion that the id space stays below BID_TABSZ checks the wrong id\n", (int)BID_LAST, maxid); bad++; }
    printf("entries=%d bad=%d duplicate_ids=%d\n", seen, bad, dup);
    return (bad || dup) ? 1 : 0;
}
EOF
gcc -I"$ROOT/src/runtime" -o "$T/bidcheck" "$T/bidcheck.c" 2>"$T/cc.err" || { sed 's/^/       /' "$T/cc.err" | head -5; refuse "the checker did not compile against the real header -- cannot measure"; }
OUT="$("$T/bidcheck")"; RC=$?
printf '%s\n' "$OUT" | sed 's/^/  /'
ENTRIES="$(printf '%s\n' "$OUT" | sed -n 's/^entries=\([0-9]*\).*/\1/p')"
[ -n "$ENTRIES" ] || refuse "the checker printed no entry count -- that is not a score"
if [ "$ENTRIES" -lt "$FLOOR" ]; then
  echo "GATE FAIL(1) [$NAME]: entry count $ENTRIES is BELOW the floor $FLOOR -- ids were deleted, not added."
  echo "    If ../harness/scripts/gen_builtin_ids.py was run, that is the spent one-shot migration and it reduces this table to 9; revert it."
  exit 1
fi
echo "graded=$ENTRIES FAIL=$((RC == 0 ? 0 : 1)) (every name round-trips through the REAL bid_of to its own id, every stored len equals strlen, no id is shared, and the count is at or above the floor $FLOOR. MEASURED discriminating 2026-09-11: storing a wrong len for one entry prints BAD len AND BAD roundtrip and reds; giving two names one id prints DUPLICATE id and reds.)"
[ "$RC" = 0 ] || { echo "GATE FAIL(1) [$NAME]: the table is not self-consistent"; exit 1; }
echo "GATE PASS(0) [$NAME]: $ENTRIES/$ENTRIES"
exit 0
