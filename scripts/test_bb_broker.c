/*============================================================================================================================
 * test_bb_broker.c — Unit test for bb_broker() all three modes (GOAL-UNIFIED-BROKER U-4)
 *
 * Build:
 *   gcc -O0 -g -I src -I src/runtime/x86 -I src/runtime -DDYN_ENGINE_LINKED \
 *       test/test_bb_broker.c src/runtime/x86/bb_broker.c -lgc -lm -o /tmp/test_bb_broker
 *   /tmp/test_bb_broker
 *
 * No frontends involved — pure broker + hand-wired boxes.
 *============================================================================================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "runtime/x86/bb_box.h"
#include "runtime/x86/bb_convert.h"
#include "runtime/x86/bb_broker.h"
#include "runtime/x86/snobol4.h"

/* ── Global match state (defined in stmt_exec.c normally; we define here for test) ── */
const char *Σ = NULL;
int         Δ = 0;
int         Ω = 0;

/*============================================================================================================================
 * Hand-wired test boxes
 *============================================================================================================================*/

/* constant_box: always returns the same DESCR_t on α; FAILDESCR on β.
 * Used to test BB_ONCE and BB_PUMP (single-value generator). */
typedef struct { DESCR_t value; int fired; } const_box_state_t;

static DESCR_t constant_box_fn(void *zeta, int entry) {
    const_box_state_t *z = zeta;
    if (entry == α && !z->fired) { z->fired = 1; return z->value; }
    return FAILDESCR;
}

static bb_node_t make_const_box(DESCR_t val) {
    const_box_state_t *z = calloc(1, sizeof(const_box_state_t));
    z->value = val;
    return (bb_node_t){ (bb_box_fn)constant_box_fn, z, sizeof(const_box_state_t) };
}

/* counter_box: BB_PUMP test — produces integers 1..n then ω. */
typedef struct { int cur; int max; } counter_box_state_t;

static DESCR_t counter_box_fn(void *zeta, int entry) {
    counter_box_state_t *z = zeta;
    if (entry == α) z->cur = 1;
    else            z->cur++;
    if (z->cur > z->max) return FAILDESCR;
    return INTVAL(z->cur);
}

static bb_node_t make_counter_box(int max) {
    counter_box_state_t *z = calloc(1, sizeof(counter_box_state_t));
    z->max = max;
    return (bb_node_t){ (bb_box_fn)counter_box_fn, z, sizeof(counter_box_state_t) };
}

/* lit_box: BB_SCAN test — matches a literal string at current cursor position Δ. */
typedef struct { const char *lit; int len; } lit_box_state_t;

static DESCR_t lit_box_fn(void *zeta, int entry) {
    lit_box_state_t *z = zeta;
    if (entry == α) {
        if (Δ + z->len > Ω) return FAILDESCR;
        if (memcmp(Σ + Δ, z->lit, (size_t)z->len) != 0) return FAILDESCR;
        spec_t matched = spec(Σ + Δ, z->len);
        Δ += z->len;
        return descr_from_spec(matched);
    }
    Δ -= z->len;
    return FAILDESCR;
}

static bb_node_t make_lit_box(const char *lit) {
    lit_box_state_t *z = calloc(1, sizeof(lit_box_state_t));
    z->lit = lit; z->len = (int)strlen(lit);
    return (bb_node_t){ (bb_box_fn)lit_box_fn, z, sizeof(lit_box_state_t) };
}

/*============================================================================================================================
 * body_fn collectors
 *============================================================================================================================*/

typedef struct { DESCR_t vals[16]; int count; } collect_t;

static void collect_fn(DESCR_t val, void *arg) {
    collect_t *c = arg;
    if (c->count < 16) c->vals[c->count++] = val;
}

/*============================================================================================================================
 * Tests
 *============================================================================================================================*/

static int failures = 0;
#define CHECK(cond, msg) do { if (!(cond)) { fprintf(stderr, "FAIL: %s\n", msg); failures++; } else { printf("PASS: %s\n", msg); } } while(0)

static void test_bb_once_success(void) {
    bb_node_t box = make_const_box(INTVAL(42));
    collect_t c = {0};
    int ticks = bb_broker(box, BB_ONCE, collect_fn, &c);
    CHECK(ticks == 1,              "BB_ONCE success: tick count == 1");
    CHECK(c.count == 1,            "BB_ONCE success: body_fn called once");
    CHECK(IS_INT_fn(c.vals[0]),    "BB_ONCE success: result is integer");
    CHECK(c.vals[0].i == 42,       "BB_ONCE success: result value == 42");
}

static void test_bb_once_failure(void) {
    /* box that always fails */
    bb_node_t box = { (bb_box_fn)constant_box_fn, NULL, 0 };   /* NULL zeta → fires == garbage, but fn checks fired */
    /* use a fresh fired=0 box with value FAILDESCR — simpler: make_const_box then mark exhausted */
    const_box_state_t *z = calloc(1, sizeof(const_box_state_t));
    z->value = FAILDESCR; z->fired = 0;
    /* constant_box_fn with FAILDESCR value: α fires, returns FAILDESCR */
    /* Actually: constant_box_fn returns z->value on α when !fired — so FAILDESCR is returned */
    box = (bb_node_t){ (bb_box_fn)constant_box_fn, z, sizeof(const_box_state_t) };
    collect_t c = {0};
    int ticks = bb_broker(box, BB_ONCE, collect_fn, &c);
    CHECK(ticks == 0,   "BB_ONCE failure: tick count == 0");
    CHECK(c.count == 0, "BB_ONCE failure: body_fn not called");
}

static void test_bb_pump_counter(void) {
    bb_node_t box = make_counter_box(5);
    collect_t c = {0};
    int ticks = bb_broker(box, BB_PUMP, collect_fn, &c);
    CHECK(ticks == 5,           "BB_PUMP counter: tick count == 5");
    CHECK(c.count == 5,         "BB_PUMP counter: body_fn called 5 times");
    CHECK(c.vals[0].i == 1,     "BB_PUMP counter: first value == 1");
    CHECK(c.vals[4].i == 5,     "BB_PUMP counter: last value == 5");
}

static void test_bb_pump_empty(void) {
    bb_node_t box = make_counter_box(0);   /* max=0 → immediate ω on α */
    collect_t c = {0};
    int ticks = bb_broker(box, BB_PUMP, collect_fn, &c);
    CHECK(ticks == 0,   "BB_PUMP empty: tick count == 0");
    CHECK(c.count == 0, "BB_PUMP empty: body_fn not called");
}

static void test_bb_scan_match(void) {
    const char *subject = "hello world";
    Σ = subject; Ω = (int)strlen(subject); Δ = 0;
    bb_node_t box = make_lit_box("world");
    collect_t c = {0};
    int ticks = bb_broker(box, BB_SCAN, collect_fn, &c);
    CHECK(ticks == 1,           "BB_SCAN match: tick count == 1");
    CHECK(c.count == 1,         "BB_SCAN match: body_fn called once");
    CHECK(c.vals[0].v == DT_S,  "BB_SCAN match: result is string");
    CHECK(c.vals[0].slen == 5,  "BB_SCAN match: matched length == 5");
    CHECK(memcmp(c.vals[0].s, "world", 5) == 0, "BB_SCAN match: matched text == 'world'");
}

static void test_bb_scan_no_match(void) {
    const char *subject = "hello world";
    Σ = subject; Ω = (int)strlen(subject); Δ = 0;
    bb_node_t box = make_lit_box("xyz");
    collect_t c = {0};
    int ticks = bb_broker(box, BB_SCAN, collect_fn, &c);
    CHECK(ticks == 0,   "BB_SCAN no match: tick count == 0");
    CHECK(c.count == 0, "BB_SCAN no match: body_fn not called");
}

static void test_bb_scan_first_match_wins(void) {
    /* "aa" appears at positions 0 and 1 in "aaa" — BB_SCAN stops at first */
    const char *subject = "aaa";
    Σ = subject; Ω = (int)strlen(subject); Δ = 0;
    bb_node_t box = make_lit_box("aa");
    collect_t c = {0};
    int ticks = bb_broker(box, BB_SCAN, collect_fn, &c);
    CHECK(ticks == 1,   "BB_SCAN first-match-wins: exactly 1 tick");
    CHECK(c.count == 1, "BB_SCAN first-match-wins: body_fn called once");
}

static void test_null_box(void) {
    bb_node_t null_box = { NULL, NULL, 0 };
    int ticks = bb_broker(null_box, BB_PUMP, NULL, NULL);
    CHECK(ticks == 0, "null box: returns 0 ticks safely");
}

/*============================================================================================================================
 * main
 *============================================================================================================================*/
int main(void) {
    printf("=== bb_broker unit tests (U-4) ===\n");
    test_bb_once_success();
    test_bb_once_failure();
    test_bb_pump_counter();
    test_bb_pump_empty();
    test_bb_scan_match();
    test_bb_scan_no_match();
    test_bb_scan_first_match_wins();
    test_null_box();
    printf("=== %s (%d failure%s) ===\n",
           failures == 0 ? "ALL PASS" : "FAILURES",
           failures, failures == 1 ? "" : "s");
    return failures ? 1 : 0;
}
