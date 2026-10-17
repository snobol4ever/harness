#!/usr/bin/env bash
# test_unit_rt_arena.sh — RUNG TR-1 kernel unit test (slab pool + arenas + ζ-block reuse)
set -eu
REPO="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
T=$(mktemp -d)
cat > "$T/t.c" <<'EOF'
#include "rt_arena.h"
#include <assert.h>
#include <string.h>
#include <stdio.h>
int main(void) {
    /* 1. bump + zero + align */
    rt_arena_t tr; rt_arena_init(&tr, A_TRANS);
    char *a = rt_arena_alloc(&tr, 100), *b = rt_arena_alloc(&tr, 3);
    assert(((uintptr_t)a & 15) == 0 && ((uintptr_t)b & 15) == 0);
    for (int i = 0; i < 100; i++) assert(a[i] == 0);
    /* 2. mark/release LIFO incl. cross-slab */
    arena_mark_t m = rt_arena_mark(&tr);
    void *big = rt_arena_alloc(&tr, 200000); /* forces a new slab */
    assert(big);
    rt_arena_release(&tr, m);
    char *c = rt_arena_alloc(&tr, 8);
    assert(c == b + 16); /* cursor back at the mark, same slab */
    /* 3. slab recycling: destroy then realloc reuses pooled bytes */
    size_t before = rt_slab_pool_bytes();
    rt_arena_destroy(&tr);
    rt_arena_init(&tr, A_TRANS);
    (void)rt_arena_alloc(&tr, 64);
    assert(rt_slab_pool_bytes() == before); /* no new malloc: slab came from the pool */
    /* 4. A_PROG title word */
    rt_arena_t pr; rt_arena_init(&pr, A_PROG);
    char *s = rt_arena_alloc(&pr, 42);
    uint64_t tw = *(uint64_t *)(s - 16);
    assert((tw >> 8) == 42 && (tw & 0xff) == A_PROG);
    /* 5. A_COEXPR reusable ζ blocks: put then get returns the same block, zeroed */
    rt_arena_t cx; rt_arena_init(&cx, A_COEXPR);
    void *z1 = rt_arena_zblock_get(&cx, 4096);
    memset(z1, 0xAB, 4096);
    rt_arena_zblock_put(&cx, z1);
    void *z2 = rt_arena_zblock_get(&cx, 4096);
    assert(z2 == z1);
    assert(((char *)z2)[100] == 0); /* recycled block re-zeroed */
    puts("PASS rt_arena unit (5/5)");
    return 0;
}
EOF
gcc -I"$REPO/src/runtime/rt" -o "$T/t" "$T/t.c" \
    "$REPO/src/runtime/rt/rt_slab.c" "$REPO/src/runtime/rt/rt_arena.c" -lpthread
"$T/t"
rm -rf "$T"
