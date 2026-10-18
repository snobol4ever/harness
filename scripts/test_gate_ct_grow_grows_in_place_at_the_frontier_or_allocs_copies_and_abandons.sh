#!/usr/bin/env bash
# test_gate_ct_grow_grows_in_place_at_the_frontier_or_allocs_copies_and_abandons.sh -- ct_grow in src/ir/ct_arena.c grows a compile-time block the
# way Lon ruled twice: realloc's two cheap cases (ARCH-DYNAMIC-STORAGE.md § 4.0, Lon 2026-09-23: "grown in place and copy and grown just
# like realloc does. Of course grow in place only occurs at the frontier."; CEO-1211), and otherwise ALLOC, COPY, ABANDON (Lon 2026-09-24
# 12:4x, in-chat to the cfo: "Use the special compile-time heap, and use alloc/copy/abandon at geometric growth for dynamic arrays and
# buffers."; CEO-1244). RE-PINNED 2026-09-25 by the cfo from test_gate_ct_grow_takes_reallocs_contract_and_frees_the_old_block.sh
# (d2efe8a8f), whose case 3 FREED the old block through ct_drop: CEO-1244 supersedes that contract, and every arm below that read a free
# now reads an abandon. Row compiler-every-population-table-grows-in-the-compile-time-arena-through-ct-grow-no-fixed-limit-a-program-can-reach.
#
# ARM 1, the primitive, through a C harness linked against the allocator's own source (no build of scrip needed). The allocator keeps its state
# in g_lower.ir (CEO-1575, the ceo's ruling of 2026-10-09 14:10), so the harness defines the one g_lower from the same G_LOWER_INIT that
# lower_common.c uses -- ct_poison starts at -1 here exactly as in scrip:
#   1a FITS      a grow within the block's power-of-two class returns the SAME pointer.
#   1b FRONTIER  the last block carved grows IN PLACE: same pointer, payload intact, the frontier advanced.
#   1c MOVES     a block that is not at the frontier moves: a new pointer, the payload copied, and the old block is ABANDONED -- under
#                SCRIP_CT_POISON=1 SCRIP_CT_NORECYCLE=1 its payload still reads the old bytes (a ct_drop would have painted 0xDD), and
#                it is still a block this allocator handed out (a second ct_grow of it returns, where a dropped block refuses rc 3).
#                A cure that went back to freeing reds this arm.
#   1d NO BIN    the abandoned block never returns to a bin: the next same-class allocation is a DIFFERENT block.
#   1e BIG       a block above the 8 MB bin moves to a new mapping with the payload copied, and the old mapping stays readable.
# ARM 2 (RETIRED 2026-09-26 with the SCRIP_AB road, CEO-1274 (2)): the snapshot restore in bb_ab_emit_nodes carried the grown op_arg_slot: SCRIP_AB=1 on a
#   program whose first DEFINE has 60 names and whose second has 20 compiles rc 0 (the regression that found the drop's one broken
#   caller, 2026-09-23; kept as the arm that proves the restore still hands back the grown array).
# rc 0 GREEN · 1 RED (named) · 2 REFUSE (cannot measure).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
GATE_NAME=ct_grow_grows_in_place_at_the_frontier_or_allocs_copies_and_abandons
. "$HERE/lib_gate.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_gate.sh unavailable"; exit 2; }
gate_parse_args "$@"
command -v gcc > /dev/null || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no gcc"; exit 2; }
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
red=0
cat > "$T/h.c" <<'EOF'
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "ct_arena.h"
static int bad = 0;
#define CHECK(c, m) do { if (!(c)) { printf("  RED  %s\n", m); bad = 1; } else printf("  ok   %s\n", m); } while (0)
int main(int argc, char **argv) {
    const char *arm = argc > 1 ? argv[1] : "";
    if (!strcmp(arm, "shape")) {
        unsigned char *p = ct_alloc(100), *q, *r, *s, *t, *u; int k, ok = 1;
        for (k = 0; k < 100; k++) p[k] = (unsigned char) k;
        q = ct_grow(p, 120); CHECK(q == p, "1a FITS: a grow within the 128-byte class returns the same pointer");
        r = ct_grow(p, 200); CHECK(r == p, "1b FRONTIER: the last block carved grows in place");
        for (k = 0; k < 100; k++) if (r[k] != (unsigned char) k) ok = 0;
        CHECK(ok, "1b FRONTIER: the payload is intact after the in-place grow");
        s = ct_alloc(10); (void) s;
        t = ct_grow(r, 1000); CHECK(t != r, "1c MOVES: a block no longer at the frontier moves");
        ok = 1; for (k = 0; k < 100; k++) if (t[k] != (unsigned char) k) ok = 0;
        CHECK(ok, "1c MOVES: the payload is copied");
        u = ct_alloc(200); CHECK(u != r, "1d NO BIN: the abandoned block is not the next allocation of its class");
        { unsigned char *b = ct_alloc((size_t) 9 << 20), *c; b[0] = 7; b[((size_t) 9 << 20) - 1] = 9; c = ct_grow(b, (size_t) 18 << 20);
          CHECK(c != b && c[0] == 7 && c[((size_t) 9 << 20) - 1] == 9, "1e BIG: a block above the 8 MB bin moves to its own mapping, payload copied");
          CHECK(b[0] == 7 && b[((size_t) 9 << 20) - 1] == 9, "1e BIG: the old mapping is abandoned, still readable"); }
        return bad;
    }
    if (!strcmp(arm, "poison")) {
        unsigned char *p = ct_alloc(100), *s, *t; int k, dd = 1;
        memset(p, 0x41, 100); s = ct_alloc(10); (void) s;
        t = ct_grow(p, 1000);
        for (k = 0; k < 100; k++) if (p[k] != 0xDD) dd = 0;
        CHECK(t != p && t[0] == 0x41 && t[99] == 0x41, "1c MOVES: under poison the payload is copied");
        CHECK(!dd && p[0] == 0x41 && p[99] == 0x41, "1c ABANDONS: the old block still reads 0x41 -- ct_grow did not drop it (a ct_drop would paint 0xDD)");
        fflush(stdout);
        { unsigned char *w = ct_grow(p, 2000); CHECK(w && w != p && w[0] == 0x41, "1c ABANDONS: the old block is still one this allocator handed out (a dropped block refuses rc 3)"); }
        return bad;
    }
    return 2;
}
EOF
printf '#include "g_lower.h"\ng_lower_t g_lower = G_LOWER_INIT;\n' > "$T/g.c"
gcc -O0 -I"$ROOT/src/ir" -I"$ROOT/src/lower" "$T/h.c" "$T/g.c" "$ROOT/src/ir/ct_arena.c" -o "$T/h" 2> "$T/cc.err" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the harness did not compile against src/ir/ct_arena.c"; head -5 "$T/cc.err"; exit 2; }
echo "ARM 1 -- the primitive (src/ir/ct_arena.c)"
"$T/h" shape || red=1
SCRIP_CT_POISON=1 SCRIP_CT_NORECYCLE=1 "$T/h" poison > "$T/p.out" 2> "$T/p.err"; prc=$?
cat "$T/p.out"
if [ "$prc" != 0 ]; then echo "  RED  1c ABANDONS: the poison arm exited rc $prc -- $(head -c 160 "$T/p.err" | tr '\n' ' ')"; red=1; fi
grep -q '  RED ' "$T/p.out" && red=1
echo "ARM 2 -- the snapshot restore in bb_ab_emit_nodes carries the grown op_arg_slot"
gate_require_exec "$ROOT/scrip" "the scrip binary"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
python3 - "$T/w.sno" <<'EOF'
import sys
L = ["        DEFINE('BIG(A,B)%s')" % ",".join("L%d" % i for i in range(1, 61)),
     "        DEFINE('MID(P)%s')" % ",".join("K%d" % i for i in range(1, 21)),
     "        DEFINE('TINY(Q)')",
     "                                                   :(GO)",
     "BIG     BIG = A + B                                  :(RETURN)",
     "MID     MID = P * 3                                  :(RETURN)",
     "TINY    TINY = Q + 1                                 :(RETURN)",
     "GO      OUTPUT = BIG(3,4) MID(5) TINY(41)",
     "END"]
open(sys.argv[1], "w").write("\n".join(L) + "\n")
EOF
echo "  arm 2 RETIRED with the SCRIP_AB road (cto 2026-09-26, CEO-1274 (2)): the snapshot restore it witnessed lived in bb_ab_emit_nodes, which is deleted; nothing on a live road restores an op_arg_slot snapshot, so there is nothing to re-witness"
gate_stamp
[ "$red" = 0 ] && { echo "GATE GREEN [$GATE_NAME]"; exit 0; }
echo "GATE RED(1) [$GATE_NAME]"; exit 1
