/* The graphics arena under the kernel's three slots, proven at the C level: no Prolog is in this process.
   Arm A (no kernel): the allocator's own laws. Arm B: the box kernel hosted with its slots pointed at the arena; objects made, grown,
   freed and made again; an image read from a GIF whose local colormap is cut short, three times between two good loads.
   Prints one line an arm; rc 0 when every line ends ok. */
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <malloc.h>
#include <h/interface.h>
#include "ir/pin_va.h"
#include "runtime/xpce/xpce_arena.h"
int xpce_host_initialise(int handles, const char *home, const char *appdata, int argc, char **argv);
static PceObject nm(const char *s) { return cToPceName_nA(s, strlen(s)); }
static int bad = 0;
#define CHECK(c, what) do { if (!(c)) { printf("  FAIL %s\n", what); bad++; } } while (0)
static void arm_a(xpce_ctx_t *cx)
{ char *p = xpce_arena_alloc(1), *q = xpce_arena_alloc(17), *big = xpce_arena_alloc(5000000);
  CHECK(p && q && big && xpce_arena_holds(p) && xpce_arena_holds(big) && ((uintptr_t)p & 15) == 0 && ((uintptr_t)big & 15) == 0, "blocks inside the window, 16-aligned");
  memset(big, 0x5a, 5000000); memset(q, 7, 17);
  q = xpce_arena_realloc(q, 32); CHECK(q[16] == 7, "a realloc inside the class keeps the block");
  char *q2 = xpce_arena_realloc(q, 40000); CHECK(q2 != q && q2[16] == 7, "a realloc past the class copies");
  xpce_arena_free(p); char *p2 = xpce_arena_alloc(9); CHECK(p2 == p, "a freed block is the next of its class");
  uint64_t r0 = cx->n_reuse; void *v[1000];
  for (int k = 0; k < 3; k++) { if (k == 1) r0 = cx->n_reuse; for (int i = 0; i < 1000; i++) v[i] = xpce_arena_alloc((size_t)(i * 37 % 1500 + 1)); for (int i = 0; i < 1000; i++) xpce_arena_free(v[i]); }
  CHECK(cx->n_reuse - r0 == 2000, "churn: the second and third rounds carve nothing");
  uintptr_t top = cx->heap_top; for (int i = 0; i < 1000; i++) v[i] = xpce_arena_alloc((size_t)(i * 37 % 1500 + 1)); CHECK(cx->heap_top == top, "churn: the bump pointer stands");
  for (int i = 0; i < 1000; i++) xpce_arena_free(v[i]);
  char *l = malloc(100); uint64_t o0 = cx->n_outside_free; xpce_arena_free(l); CHECK(cx->n_outside_free == o0 + 1, "a libc block reaching free is answered by libc's");
  l = malloc(10); memcpy(l, "outside", 8); l = xpce_arena_realloc(l, 100000); CHECK(!xpce_arena_holds(l) && !strcmp(l, "outside") && cx->n_outside_realloc == 1, "a libc block reaching realloc stays libc's"); free(l);
  char *g = xpce_arena_alloc((size_t)1 << 30); CHECK(g && cx->heap_mapped - (uintptr_t)g >= ((size_t)1 << 30), "a gigabyte is mapped on demand"); g[0] = 1; g[((size_t)1 << 30) - 1] = 1; xpce_arena_free(g);
  CHECK(xpce_arena_open() == cx, "a second open finds the same record");
  printf("ARENA-A allocator: alloc=%llu free=%llu reuse=%llu %s\n", (unsigned long long)cx->n_alloc, (unsigned long long)cx->n_free, (unsigned long long)cx->n_reuse, bad ? "RED" : "ok");
}
static void put(const char *f, const unsigned char *b, size_t n) { FILE *o = fopen(f, "wb"); fwrite(b, 1, n, o); fclose(o); }
static int load(PceObject NIL, const char *f) { PceObject a[1] = { nm(f) }; PceObject i = pceNew(NIL, nm("image"), 1, a); return i != NULL; }
int main(int argc, char **argv)
{ xpce_ctx_t *cx = xpce_arena_open();
  if (!cx) { printf("ARENA-A no window at the fixed address RED\n"); return 1; }
  arm_a(cx);
  if (argc > 1 && !strcmp(argv[1], "alone")) return bad != 0;
  int bad_a = bad; bad = 0;
  pce_callback_functions cb; memset(&cb, 0, sizeof cb);
  cb.malloc = xpce_arena_alloc; cb.realloc = xpce_arena_realloc; cb.free = xpce_arena_free;
  pceRegisterCallbacks(&cb);
  uint64_t a0 = cx->n_alloc;
  const char *home = getenv("XPCE_HOME_DIR") ? getenv("XPCE_HOME_DIR") : "/home/resources/xpce-V9.0.4";
  if (!xpce_host_initialise(0, home, getenv("XPCE_APPDATA_DIR"), argc, argv)) { printf("ARENA-B pceInitialise failed RED\n"); return 1; }
  PceObject NIL = cToPceAssoc("nil");
  uint64_t at_start = cx->n_alloc - a0; CHECK(at_start > 0, "the kernel's start allocates through the slots");
  PceObject pt = pceNew(NIL, nm("point"), 0, NULL); CHECK(pt && xpce_arena_holds(pt), "an object's address is inside the window");
  for (int round = 1; round <= 3; round++)
  { PceObject ch = pceNew(NIL, nm("chain"), 0, NULL);
    for (int i = 1; i <= 2000; i++) { PceObject xy[2] = { cToPceInteger(i), cToPceInteger(i * round) }; PceObject p = pceNew(NIL, nm("point"), 2, xy); PceObject a[1] = { p }; pceSend(ch, 0, nm("append"), 1, a); }
    PceObject sz = pceGet(ch, 0, nm("size"), 0, NULL); PceCValue v; CHECK(sz && pceToC(sz, &v) == PCE_INTEGER && v.integer == 2000, "a chain of 2000 points");
    pceSend(ch, 0, nm("free"), 0, NULL);
  }
  PceObject s = cToPceStringA(NIL, "", 0, 0);
  for (int i = 1; i <= 3000; i++) { char c[2] = { (char)('a' + i % 26), 0 }; PceObject a[1] = { nm(c) }; pceSend(s, 0, nm("append"), 1, a); }
  { PceObject sz = pceGet(s, 0, nm("size"), 0, NULL); PceCValue v; CHECK(sz && pceToC(sz, &v) == PCE_INTEGER && v.integer == 3000, "a string grown to 3000"); }
  PceObject vec = pceNew(NIL, nm("vector"), 0, NULL);
  for (int i = 1; i <= 4000; i++) { PceObject a[2] = { cToPceInteger(i), cToPceInteger((intptr_t)i * i) }; pceSend(vec, 0, nm("element"), 2, a); }
  { PceObject a[1] = { cToPceInteger(4000) }; PceObject e = pceGet(vec, 0, nm("element"), 1, a); PceCValue v; CHECK(e && pceToC(e, &v) == PCE_INTEGER && v.integer == 16000000, "a vector grown to 4000"); }
  printf("ARENA-B kernel on the arena: start=%llu alloc=%llu free=%llu reuse=%llu heap=%lluK %s\n", (unsigned long long)at_start, (unsigned long long)cx->n_alloc, (unsigned long long)cx->n_free, (unsigned long long)cx->n_reuse, (unsigned long long)((cx->heap_top - (RT_XPCE_ARENA_VA + XPCE_ARENA_HEAP)) >> 10), bad ? "RED" : "ok");
  int bad_b = bad; bad = 0;
  if (argc > 1 && !strcmp(argv[1], "gif"))
  { static const unsigned char good[] = { 'G','I','F','8','9','a', 2,0, 2,0, 0x80,0,0, 0,0,0, 255,255,255, ',', 0,0, 0,0, 2,0, 2,0, 0, 2, 2, 0x4C, 0x01, 0, ';' };
    static const unsigned char cut[] = { 'G','I','F','8','9','a', 2,0, 2,0, 0x80,0,0, 0,0,0, 255,255,255, ',', 0,0, 0,0, 2,0, 2,0, 0x81, 9,9,9, 8 };
    PceObject pce = cToPceAssoc("pce"); PceObject ce[1] = { nm("bad_file") }; (void)pce; (void)ce;
    uint64_t o0 = cx->n_outside_free;
    put("arena_g1.gif", good, sizeof good); int g1 = load(NIL, "arena_g1.gif");
    put("arena_c1.gif", cut, sizeof cut); int c1 = load(NIL, "arena_c1.gif");
    put("arena_c2.gif", cut, sizeof cut); int c2 = load(NIL, "arena_c2.gif");
    put("arena_g2.gif", good, sizeof good); int g2 = load(NIL, "arena_g2.gif");
    put("arena_c3.gif", cut, sizeof cut); int c3 = load(NIL, "arena_c3.gif");
    CHECK(g1 && g2, "the two good GIFs load"); CHECK(!c1 && !c2 && !c3, "the three cut GIFs do not");
    CHECK(cx->n_outside_free - o0 >= 3, "each cut GIF's libc buffer reached the arena's free and was answered by libc's");
    PceObject ch = pceNew(NIL, nm("chain"), 0, NULL); CHECK(ch && xpce_arena_holds(ch), "the kernel goes on");
    printf("ARENA-C a GIF cut short: loaded=%d%d refused=%d%d%d outside_free=%llu %s\n", g1, g2, !c1, !c2, !c3, (unsigned long long)(cx->n_outside_free - o0), bad ? "RED" : "ok");
    remove("arena_g1.gif"); remove("arena_c1.gif"); remove("arena_c2.gif"); remove("arena_g2.gif"); remove("arena_c3.gif");
  }
  return (bad_a || bad_b || bad) != 0;
}
