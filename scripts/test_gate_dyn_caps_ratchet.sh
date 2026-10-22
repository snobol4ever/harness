#!/usr/bin/env bash
# test_gate_dyn_caps_ratchet.sh -- THE FIXED-CAPS RATCHET: the population of fixed tables in src/ may only fall, and a fall lowers the
# baseline in the same landing (Lon 2026-09-23 14:5x: no fixed limit a program can reach; .github/ARCH-DYNAMIC-STORAGE.md section 5;
# row instruments-the-fixed-caps-ratchet-is-a-blocking-arm-and-every-remaining-cap-refuses-loudly, the coo).
# ⛔ ONE EXCEPTION TO "MAY ONLY FALL" (ceo CEO-1302, 2026-09-27): a ../harness/scripts/fixtures/dyn_caps/CLASS_AB.tsv row licenses a raise of
# exactly the table(s) it declares, and only in the same landing that adds the row with its measurement, the commit naming the raise
# (5d936b498, the opsym row, is the precedent). The only other raise is a like-for-like re-derivation of the instrument on one tree.
#
# THE POPULATION is audit_fixed_caps_census.py's file-, static- and field-scope declarations with a constant bound, counted by
# util_dyn_caps_witness.sh census against ../harness/scripts/fixtures/dyn_caps/BASELINE. ⛔ THE CENSUS WAS CORRECTED BEFORE THIS GATE COULD LAND,
# BECAUSE IT WAS RED FOR A REASON THAT WAS NOT A NEW TABLE: it counted an `extern` re-declaration as a table (13 of them, among
# them the file-scope `extern jmp_buf g_core_errjmp_stk[64];` that read "361 -> 362, a new fixed limit landed"), and it could not
# see a table named after a closing brace, `static struct { fields } name[CAP];` (30 of them, the cfo's finding: five population
# caps in lower_snobol4.c among them). The corrected census reads 379 on the baseline's own tree (ac237a0e7) and 379 today, the
# same tables by name -- so BASELINE was re-derived 361 -> 379 like-for-like: one tree, the corrected instrument, nothing hidden.
# ARMS:
#   1 the census's own selftest: every declared form is counted once or refused as not-storage (typedef, extern, a comparison), and
#     each guard shape (skip, loud abort, clamp, truncating loop, none, const, a literal guarded at N-1, a refusing wrapper) is read
#     as its class, all by NAME
#   2 the real tree reads EXACTLY the baseline: above it a new fixed table landed (make it dynamic, or declare it class A/B on the
#     page); below it a table was converted and BASELINE is lowered to the new count IN THE SAME LANDING, so the ratchet keeps it
#   3 FAIL-ONCE BUILT IN: a scratch copy of src/ with TWO planted file-scope tables reads RED, grown by exactly two from the UNPLANTED
#     count -- ⛔ judged against the tree's own count, not against BASELINE+1: when hq_icon's two constant tables put origin at 366 over
#     364, the old arm expected "364 -> 365", read 367, and one cause redded two arms (the cfo's finding, 2026-09-24)
#   4 THE GUARD CLASSIFIER CAN RED (CEO-1231): of the two planted tables one is never compared and one drops at its cap, and the
#     census's no-guard count and its drop count must each rise by exactly one -- a classifier that read every table the same could
#     not pass both
#   5 THE SECOND POPULATION (CEO-1231 (1), stage 2): the locals a program's data fills -- the census's fill column -- read EXACTLY
#     ../harness/scripts/fixtures/dyn_caps/BASELINE_FUNCTION_SCOPE, with the same rule: above it a new fixed local landed, below it a conversion
#     lowers the baseline in the same landing
#   6 FAIL-ONCE BUILT IN FOR IT: three planted locals, two filled by a list walk with no guard and one the digits of a number (class B
#     by construction, a radix loop), raise the function-scope population by exactly TWO -- the radix buffer stays out -- and the
#     census names the growth RED; one list walk is declared on the scratch CLASS_AB.tsv, so the unguarded count rises by ONE and the
#     declared term by one, and its row is not stale (ceo 2026-10-02, ruling (a) on the coo's arm-5 ask: a local may be declared A/B)
#   7 THE CLASS A/B FIXTURE (ceo CEO-1234 (1)): ../harness/scripts/fixtures/dyn_caps/CLASS_AB.tsv names the tables that stay fixed, each with the
#     measurement that earned its class; the scratch copy declares a third planted table (which must leave the no-guard line: arm 4's
#     +1 holds with two never-compared plants) and one table the tree does not declare, which must read RED by name
#   8 THE WITNESS VERB (CEO-1231: the refusal read at cap+1) CAN RED: util_dyn_caps_witness.sh witness on a scratch WITNESSES.tsv reads
#     the Prolog trail's refusal at 1200000 conditional bindings, counts a program that never reaches RT_GVA_ISLAND_BYTES's cap as SILENT, names a
#     row for no LOUD guard STALE, and exits 1 -- the verb itself is the row's DONE-WHEN, graded there, not here
#   9 THE NOT-SHIPPED DECLARATION (ceo CEO-1235 (3)): ../harness/scripts/fixtures/dyn_caps/NOT_SHIPPED.tsv sets aside the unit tests, tools and
#     demos no program's run reaches, and on the real tree every row passes its check against the scrip and libscrip_rt link lines
#  10 FAIL-ONCE FOR IT: a scratch declaration of only wrong rows -- src/driver/scrip.c (the scrip link), src/runtime/rtx/rtx_str.s (the
#     libscrip_rt link), a header and a missing file -- names each RED and sets NOTHING aside, so the census reads exactly the real
#     counts plus what the real declaration sets aside: the exclusion removes what it says and nothing else
#  11 0 OF 0 IS GREEN (ceo CEO-1235 (1)): with an empty witness table the verb reds on the LOUD guards that remain; with every one of
#     them declared on a scratch CLASS_AB.tsv it reads 0 of 0, says no LOUD guard remains, and exits 0
# The no-guard, drop and function-scope unguarded counts are PRINTED, not graded here: bringing each to zero is the row's criterion
# (CEO-1231), not this gate's.
# ⛔ BASELINE 217 -> 215, 2026-10-11 (the coo, ceo CEO-1692 on hq_pascal's report): two tables CONVERTED, both hq_snobol4's -- the
#   arena src/runtime/pattern_match.c RT_DCAP_ISLAND_BYTES (ca929266d: the CAS island follows the declared -s stack, overrun is ERROR 246) and
#   the field src/emitter/emit.h op_df_clbl (3d3a91085: the deferred-capture cell half deleted). Named by diffing the census's file, static,
#   field and arena rows at abcfc21e9 (the 217 baseline's tree) and 1e3b157b5 by (file, scope, name): 225 -> 223 rows, exactly these two
#   gone, nothing added. The ceo's by-name compare that read "the same 202 at both trees" is not reproduced here: after the not-shipped
#   set-aside the file/static/field rows read 195 -> 194 (op_df_clbl the one), and the arena is outside file/static/field -- the ratchet
#   counts scope `arena` with them on purpose (CEO-1231 stage 2 (b): a constant 64 KiB or more from an allocator).
# ⛔ BASELINE_FUNCTION_SCOPE 24 -> 20, 2026-10-21 (hq_prolog, on the cfo's ask about eb1634198): that landing's memmove under a skip-at-cap guard in pl_real_iso_str moved seven callers' buffers
# out of class B (31 against 24); ddf41edc4 restores the original shape (numeric formats only into the caller's buffer), the seven read fixed by construction again, and the census reads 20, so the
# baseline falls with the conversion in the same landing, as this arm requires.
# ⛔ BASELINE_FUNCTION_SCOPE 404 -> 401, 2026-10-02 (the cto, ceo rank-1 row snocone-a-setexit-trap-is-not-taken-...): the
# three char _ab[300] locals that spelled an LBL__ alias in src/driver/scrip.c (the mode-4 and mode-3 main-chain alias builders and
# the mode-3 alias registration) are gone -- one helper spells each alias in a stack array sized to its need (the lifetime rule).
# ⛔ BASELINE_FUNCTION_SCOPE 409 -> 404, 2026-10-02 (the cfo, ceo CEO-1419 ticket snobol4-real-to-string-differs-in-the-last-digit-...):
# real_str (string_ops.c) is SPITBOL's gts10-gts28 and fills its caller's buffer only through literal formats with no %s (B:fmt by
# construction, at most 23 bytes), where it used to fill two COUNTER work buffers and copy them in with "%s". Out: string_ops.c
# digits and out (gone), core.c b and buf and io_format.c b (each handed to real_str). The two pattern_match.c nb[40] the cure moved
# from "%g" to real_str and bn_size's new rb[40] stay out as B:fmt@real_str.
# ⛔ BASELINE_FUNCTION_SCOPE 410 -> 409, 2026-10-02 (the coo, ceo ruling (a) on the coo's COO-254 arm-5 ask): the cfo's ce5de7180 grew
# three locals with their data (icon_parse.c m, gc_audit_b.c also, xa_flat.cpp gk2), and gc_audit_b.c buf[16384] is DECLARED class A
# in CLASS_AB.tsv with its measurement (the longest /proc/*/maps line on this box 206 bytes vs 16384), so it stays in the count and
# leaves the unguarded term; the tree reads 409.
# ⛔ BASELINE_FUNCTION_SCOPE 393 -> 408, THE CLAMP RULE, RE-DERIVED LIKE-FOR-LIKE 2026-09-28 (the coo, on the cto's finding): the fill
# reader read a for loop as B:trip when ONE conjunct bounded its variable by a literal no larger than the array, even when another
# conjunct let the program's data decide the trip -- `fi < dt->nfields && fi < 64` (a Raku class of 70 attributes lost every named
# value past the 64th) and `sp[k] && sp[k] != '(' && k < 127` (a longer name truncated, read as B:code through its terminator write).
# A literal joined by AND to a data-driven test of the same variable is now a clamp: the loop is DATA and the literal its DROP-truncate
# guard; a conjunct that does not name the variable (`ok && i < 8`) keeps B:trip (selftest l21, l22, l23). On one tree (73cb55741)
# exactly 15 locals move from fixed-by-construction into the population, each COUNTER DROP, and nothing else moves: by_name_dispatch.c
# fvals at 5644, 5676, 5741, 5753, ub 7070, tu 7334 and 9269, nb 9281; driver_data.c nb 466; driver_label.c nb 85; lower_snobol4.c
# fnb 525 and nb 2725; gc_heap.c tx 1284 and 1414; gc_audit_b.c tx 68. The census report's own line reads 432 -> 447 (410 -> 425 dropping).
# ⛔ BASELINE 392 -> 384 AND BASELINE_FUNCTION_SCOPE 522 -> 483, THE NOT-SHIPPED DECLARATION (the coo, 2026-09-24, CEO-1235 (3)): the
# census read every compilation unit under src/, and 11 of them are linked by neither the scrip nor the libscrip_rt link line. On one
# tree (cb1bc6d1b) NOT_SHIPPED.tsv sets aside exactly the 8 tables (rtx_str_test.c 3, emit_per_kind_audit.c 5) and 39 locals a program
# fills (icon_lex_test.c 20, test_lex.c 7, emit_per_kind_audit.c 5, icn_main.c 4, icon_parse_test.c 2, prolog_parse_test.c 1) of those
# units and nothing else: 392 - 8 = 384, 522 - 39 = 483; no-guard 259 -> 253, drop 89 unchanged, locals unguarded 521 -> 482. The two
# CLASS_AB.tsv rows for emit_per_kind_audit.c (g_audit_nodes, g_audit_sm) leave with their file.
# ⛔ BASELINE 352 -> 366, RE-DERIVED LIKE-FOR-LIKE 2026-09-24 (the coo, stage 2): the census scoped a declaration by the brace depth at
# the START of its line, counted in RAW text. A '{' char literal or a "{}" string drifted the depth (re.c, unification.c, emit_str.cpp,
# by_name_dispatch.c ended off 0), emit.cpp's `extern "C" {` made every later global a local, PL_CX_LEAF_HEAD/TAIL (a function body
# opened in one macro and closed in another) drifted by_name_dispatch.c, and a local on its function's opening line read as FILE scope
# -- which is why the ratchet read 353 against BASELINE 352 on origin 4c88f60c9: 411f4dbc6 wrote `char nmb[24]` inside the one-line
# sno_scan_tmp (lower_snobol4.c:140), a local, and HEAD's census counted it as a new file-scope table. On that one tree the corrected
# census moves exactly 9 locals OUT (that nmb[24], emit_str.cpp b, lower_snobol4.c e[4096], by_name_dispatch.c el[4096] b[64] qn[256],
# core.c eb, icn_extfn.c b, rt_coexpr.c w) and 22 file-scope tables and fields IN that the drift read as locals (emit.cpp
# g_flat_data_buf and bb_patch_list after the extern "C", by_name_dispatch.c g_bidprof after the macro drift, 19 one-line or drifted
# struct fields), 353 - 9 + 22 = 366, and drops one phantom declaration inside a string (frame_layout.c "frames from [1]").
# BASELINE_FUNCTION_SCOPE 506 is the new population's first reading on that tree.
# ⛔ BASELINE 366 -> 384 AND BASELINE_FUNCTION_SCOPE 506 -> 528, RE-DERIVED LIKE-FOR-LIKE 2026-09-24 (the coo): ARRAY needs a type word
# before each name, so every array after the first declarator of one statement was invisible -- `static long g_gc_rep_ranges[..],
# g_gc_rep_bytes[..], ...;` counted one table of six, and `static int g_zd_stage, ..., g_zd_read[ZD_NOPS_MAX], g_zd_kind[..];` (a
# scalar first) counted none; and a `static const struct { const char *nm; ... } g_bid_tab[..]` read as writable because of its first
# field's `*`. On one tree (096684141) the corrected census adds exactly 18 file-scope tables and fields (15 comma declarators, 3
# after a scalar: emit.cpp g_zd_read g_zd_kind, frame_layout.c zop_hist) and 22 locals a program fills, removes none, and reads
# g_bid_tab const: 366 + 18 = 384, 506 + 22 = 528.
# ⛔ BASELINE 384 -> 392, RE-DERIVED LIKE-FOR-LIKE 2026-09-24 (the coo, stage 2 (b)): a bound written as a shift was unreadable (rt.c
# g_lvl_own[1 << 16]; emit_per_kind_audit.c bin_buf[16 * 1024] as a product), and FIXED-SIZE ARENAS -- storage a program fills that no
# declaration names, a constant 64 KiB or more from an allocator (CEO-1231 (1): arenas sized by a shift constant join the class) -- were
# not counted: the Prolog trail PL_TR_ARENA_BYTES (LOUD, rt_pl_trail.h:30), the CAS island (LOUD), the GVA island (LOUD), bb_pool's
# BB_POOL_SIZE (DROP: bb_alloc returns NULL past pool_limit), the DCAP island RT_DCAP_ISLAND_BYTES (NONE: its bump and bound live in
# the emitted asm, no C comparison) and the stack-overflow sigaltstack (declared class A in CLASS_AB.tsv). On one tree (c15438d71):
# 384 + 2 + 6 = 392; no-guard 256 -> 259 (g_lvl_own, bin_buf, the DCAP island), drop 88 -> 89 (BB_POOL_SIZE).
# ⛔ BASELINE 363 -> 355, RE-DERIVED LIKE-FOR-LIKE 2026-09-24 (the coo): the census counted 8 COMPARISONS as file-scope tables -- the
# one-line getenv switches `return (e && e[0] == '0');`, read as type `e`, separator `&&`, name `e`, initializer `== '0'` -- and 87
# such phantoms in all scopes. On one tree (c2cdd7480) the corrected census drops exactly those 87 rows, every one a NAME[0]
# expression, and adds none; re-measured after rebasing onto 3680a1d67 (the WASM tables gone, origin at 363), the old census reads 363
# and the corrected one 355, the difference exactly the 8 phantoms by name; the 355 are the same tables by name.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_fanout.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2): ../harness/scripts/lib_fanout.sh is missing -- a census runs serially under nice 19 (CEO-1333)"; exit 2; }
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=dyn_caps_ratchet
GATE_STRICT=1
gate_parse_args "$@"
C="$HERE/audit_fixed_caps_census.py"; WIT="$HERE/util_dyn_caps_witness.sh"; B="$HERE/fixtures/dyn_caps/BASELINE"; BF="$HERE/fixtures/dyn_caps/BASELINE_FUNCTION_SCOPE"
gate_require "$C" "audit_fixed_caps_census.py" || exit 2
gate_require "$WIT" "util_dyn_caps_witness.sh" || exit 2
gate_require "$B" "../harness/scripts/fixtures/dyn_caps/BASELINE" || exit 2
gate_require "$BF" "../harness/scripts/fixtures/dyn_caps/BASELINE_FUNCTION_SCOPE" || exit 2
NSF="$HERE/fixtures/dyn_caps/NOT_SHIPPED.tsv"
gate_require "$NSF" "../harness/scripts/fixtures/dyn_caps/NOT_SHIPPED.tsv" || exit 2
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"
mkdir -p "$SCRATCH" || { echo "REFUSING(2) [$GATE_NAME]: cannot create $SCRATCH"; exit 2; }
WORK=$(mktemp -d "$SCRATCH/gate_dyn_caps_XXXXXX") || exit 2
trap '[ -n "${WORK:-}" ] && rm -rf "$WORK"' EXIT INT TERM
fails=0
ck() { if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
st=$($(fanout_nice) python3 "$C" --selftest 2>&1); st_rc=$?
ck "1 the census selftest: every declared form counted once, a typedef, an extern and a comparison refused, each guard shape read as its class ($(grep -c '^SELFTEST: ' <<<"$st") checks)" '[ "$st_rc" = 0 ] && grep -q "^SELFTEST PASS" <<<"$st"'
[ "$st_rc" = 0 ] || printf '%s\n' "$st" | grep FAIL | sed 's/^/      /'
out=$(cd "$ROOT" && bash "$WIT" census 2>&1); line=$(grep -m1 '^fixed-bound declarations' <<<"$out")
[ -n "$line" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the witness printed no census line -- $(printf '%s\n' "$out" | head -2)"; gate_stamp; exit 2; }
n=$(sed -n 's/^fixed-bound declarations[^:]*: \([0-9]*\) (baseline \([0-9]*\)).*/\1/p' <<<"$line"); b=$(sed -n 's/^fixed-bound declarations[^:]*: \([0-9]*\) (baseline \([0-9]*\)).*/\2/p' <<<"$line")
u=$(sed -n 's/.*never compared in its file: \([0-9]*\)$/\1/p' <<<"$line")
echo "  census: $n fixed-bound declarations at file, static or field scope, baseline $b; $u with no capacity guard at a fill, macro or literal bound (never compared, or compared only as an index or an iteration) -- CEO-1231, printed, not graded here"
ck "2 the tree reads EXACTLY the baseline ($n vs $b)" '[ -n "$n" ] && [ "$n" = "$b" ]'
[ -n "$n" ] && [ "$n" -gt "$b" ] && echo "      a new fixed table landed ($b -> $n): make it dynamic, or declare it class A/B on the page -- list them: python3 ../harness/scripts/audit_fixed_caps_census.py --tsv /tmp/caps.tsv (an OUTPUT path)"
[ -n "$n" ] && [ "$n" -lt "$b" ] && echo "      the population FELL ($b -> $n): lower ../harness/scripts/fixtures/dyn_caps/BASELINE to $n in this landing, so the ratchet keeps the gain"
d=$(sed -n 's/^guards that drop or truncate at the cap: \([0-9]*\)$/\1/p' <<<"$out")
[ -n "$d" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the witness printed no drop line -- $(printf '%s\n' "$out" | head -3 | tr '\n' ' ')"; gate_stamp; exit 2; }
echo "  guards that drop or truncate at the cap: $d (CEO-1231; printed, not graded here)"
fline=$(grep -m1 '^function-scope arrays a program fills: ' <<<"$out")
fn=$(sed -n 's/^function-scope arrays a program fills: \([0-9]*\) (baseline \([0-9]*\)).*/\1/p' <<<"$fline"); fb=$(sed -n 's/^function-scope arrays a program fills: \([0-9]*\) (baseline \([0-9]*\)).*/\2/p' <<<"$fline")
fu=$(sed -n 's/^function-scope arrays a program fills, unguarded: \([0-9]*\)$/\1/p' <<<"$out")
[ -n "$fn" ] && [ -n "$fb" ] && [ -n "$fu" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the witness printed no function-scope lines -- $(printf '%s\n' "$out" | tail -3 | tr '\n' ' ')"; gate_stamp; exit 2; }
echo "  function-scope population: $fn locals a program fills, baseline $fb; $fu of them unguarded (CEO-1231; printed, not graded here)"
mkdir -p "$WORK/harness/scripts/fixtures/dyn_caps" "$WORK/SCRIP" && cp -rL "$ROOT/src" "$WORK/SCRIP/src" && cp "$C" "$WIT" "$HERE/lib_fanout.sh" "$WORK/harness/scripts/" \
  && printf '%s\n' "$n" > "$WORK/harness/scripts/fixtures/dyn_caps/BASELINE" && printf '%s\n' "$fn" > "$WORK/harness/scripts/fixtures/dyn_caps/BASELINE_FUNCTION_SCOPE" \
  && cp "$HERE/fixtures/dyn_caps/CLASS_AB.tsv" "$WORK/harness/scripts/fixtures/dyn_caps/CLASS_AB.tsv" \
  && cp "$NSF" "$WORK/harness/scripts/fixtures/dyn_caps/NOT_SHIPPED.tsv" && cp "$ROOT/Makefile" "$WORK/SCRIP/Makefile" \
  && for sg in $(grep '^SPILL_RULED' "$C" | grep -oE 'test_gate_[A-Za-z0-9_]+[.]sh'); do cp "$HERE/$sg" "$WORK/harness/scripts/" || exit 2; done \
  && printf 'src/planted_by_the_ratchet_gate.c\tg_planted_classab_by_the_ratchet_gate\tA\tthe gate plants it never compared and declares it\nsrc/planted_by_the_ratchet_gate.c\tg_no_such_table_by_the_ratchet_gate\tA\ta stale row the gate plants\nsrc/planted_by_the_ratchet_gate.c\tplanted_local_classab_by_the_ratchet_gate\tA\tthe gate plants a list-walk local and declares it\n' >> "$WORK/harness/scripts/fixtures/dyn_caps/CLASS_AB.tsv" \
  || { echo "REFUSING(2) [$GATE_NAME]: cannot stage the scratch tree"; exit 2; }
cat > "$WORK/SCRIP/src/planted_by_the_ratchet_gate.c" <<'PLANT'
#define PLANTED_BY_THE_RATCHET_GATE_MAX 8
static int g_planted_by_the_ratchet_gate[PLANTED_BY_THE_RATCHET_GATE_MAX];
#define PLANTED_DROP_BY_THE_RATCHET_GATE_MAX 8
static int g_planted_drop_by_the_ratchet_gate[PLANTED_DROP_BY_THE_RATCHET_GATE_MAX];
static int g_planted_drop_by_the_ratchet_gate_n;
static int g_planted_classab_by_the_ratchet_gate[8];
void planted_drop_by_the_ratchet_gate(int v) { if (g_planted_drop_by_the_ratchet_gate_n < PLANTED_DROP_BY_THE_RATCHET_GATE_MAX) g_planted_drop_by_the_ratchet_gate[g_planted_drop_by_the_ratchet_gate_n++] = v; }
struct planted_node_by_the_ratchet_gate { struct planted_node_by_the_ratchet_gate *next; int v; };
void planted_local_by_the_ratchet_gate(struct planted_node_by_the_ratchet_gate *h) {
    int planted_local_by_the_ratchet_gate[16]; int n = 0;
    for (; h; h = h->next) planted_local_by_the_ratchet_gate[n++] = h->v;
}
void planted_local_classab_by_the_ratchet_gate(struct planted_node_by_the_ratchet_gate *h) {
    int planted_local_classab_by_the_ratchet_gate[16]; int n = 0;
    for (; h; h = h->next) planted_local_classab_by_the_ratchet_gate[n++] = h->v;
}
void planted_radix_by_the_ratchet_gate(unsigned long u) {
    char planted_radix_by_the_ratchet_gate[24]; int n = 0;
    do { planted_radix_by_the_ratchet_gate[n++] = (char)('0' + u % 10); u /= 10; } while (u);
}
PLANT
po=$(cd "$WORK/SCRIP" && bash ../harness/scripts/util_dyn_caps_witness.sh census 2>&1); prc=$?
pu=$(sed -n 's/.*never compared in its file: \([0-9]*\)$/\1/p' <<<"$po"); pd=$(sed -n 's/^guards that drop or truncate at the cap: \([0-9]*\)$/\1/p' <<<"$po")
ck "3 FAIL-ONCE: three planted file-scope tables read RED, grown from the unplanted count ($n -> $((n + 3)))" '[ "$prc" != 0 ] && grep -q "grew from $n to $((n + 3))" <<<"$po"'
ck "4 the guard classifier can red, and a declared table leaves its line: of two never-compared plants only the undeclared one raises the no-guard count ($u -> ${pu:-?}) and the dropping plant the drop count by one ($d -> ${pd:-?})" '[ "$pu" = "$((u + 1))" ] && [ "$pd" = "$((d + 1))" ]'
ck "5 the function-scope population reads EXACTLY its baseline ($fn vs $fb)" '[ "$fn" = "$fb" ]'
[ "$fn" -gt "$fb" ] && echo "      a new fixed local that a program fills landed ($fb -> $fn): make it grow -- list them: python3 ../harness/scripts/audit_fixed_caps_census.py --tsv /tmp/caps.tsv (an OUTPUT path), column fill"
[ "$fn" -lt "$fb" ] && echo "      the function-scope population FELL ($fb -> $fn): lower ../harness/scripts/fixtures/dyn_caps/BASELINE_FUNCTION_SCOPE to $fn in this landing"
pfn=$(sed -n 's/^function-scope arrays a program fills: \([0-9]*\) (baseline.*/\1/p' <<<"$po"); pfu=$(sed -n 's/^function-scope arrays a program fills, unguarded: \([0-9]*\)$/\1/p' <<<"$po")
pfa=$(sed -n 's/^function-scope arrays a program fills: .* declared class A or B by [^ ]* \([0-9]*\); fixed by construction.*/\1/p' <<<"$po"); fa=$(sed -n 's/^function-scope arrays a program fills: .* declared class A or B by [^ ]* \([0-9]*\); fixed by construction.*/\1/p' <<<"$out")
ck "6 FAIL-ONCE for the second population: the two list-walk locals read RED, grown by exactly two ($fn -> ${pfn:-?}, the radix buffer out), and the declared one leaves the unguarded line (unguarded $fu -> ${pfu:-?}, declared ${fa:-?} -> ${pfa:-?}) and is not stale" '[ "$pfn" = "$((fn + 2))" ] && [ "$pfu" = "$((fu + 1))" ] && [ -n "$fa" ] && [ "$pfa" = "$((fa + 1))" ] && grep -q "function-scope population grew from $fn to $((fn + 2))" <<<"$po" && ! grep -q "^  src/planted_by_the_ratchet_gate.c:planted_local_classab_by_the_ratchet_gate$" <<<"$po"'
nab=$(sed -n 's/^declared class A or B by .*: \([0-9]*\) table(s); stale declarations: \([0-9]*\)$/\1/p' <<<"$out"); pnab=$(sed -n 's/^declared class A or B by .*: \([0-9]*\) table(s); stale declarations: \([0-9]*\)$/\1 \2/p' <<<"$po")
ck "7 THE CLASS A/B FIXTURE (CEO-1234 (1)): the planted declaration counts ($nab -> ${pnab%% *}) and a row naming a table the tree does not declare reads RED by name (stale ${pnab##* })" '[ -n "$nab" ] && [ "$pnab" = "$((nab + 1)) 1" ] && grep -q "^  src/planted_by_the_ratchet_gate.c:g_no_such_table_by_the_ratchet_gate$" <<<"$po"'
printf 'main :- write(hello), nl.\n:- initialization(main).\n' > "$WORK/silent.pl"
grep -v '^#' "$HERE/fixtures/dyn_caps/WITNESSES.tsv" | grep 'PL_TR_ARENA_BYTES' > "$WORK/witnesses_read.tsv"
wo1=$(cd "$ROOT" && DYN_CAPS_WITNESSES="$WORK/witnesses_read.tsv" bash "$WIT" witness 2>&1); wrc1=$?
{ printf 'src/runtime/rt/rt_pl_trail.c\tPL_TR_ARENA_BYTES\t%s\t\t2\tnever printed\n' "$WORK/silent.pl"
  printf 'src/planted_by_the_ratchet_gate.c\tg_no_such_guard_by_the_ratchet_gate\t%s\t\t2\tnever printed\n' "$WORK/silent.pl"; } > "$WORK/witnesses.tsv"
wo=$(cd "$ROOT" && DYN_CAPS_WITNESSES="$WORK/witnesses.tsv" bash "$WIT" witness 2>&1); wrc=$?
wsum=$(grep -m1 '^refusal read at the cap: ' <<<"$wo")
ck "8 THE WITNESS VERB CAN RED (CEO-1231): with the real row the trail's cap+1 is READ and the verb is green (rc $wrc1); on a scratch table a program that never reaches PL_TR_ARENA_BYTES's cap is SILENT, a row naming no LOUD guard is STALE, and the verb reds ($wsum, rc $wrc) -- one loud guard is left in the tree, so the two readings take two runs" '[ "$wrc1" = 0 ] && grep -q "^  READ .*PL_TR_ARENA_BYTES rc=2: .*trail arena exhausted" <<<"$wo1" && [ "$wrc" = 1 ] && grep -q "^  SILENT .*:PL_TR_ARENA_BYTES rc=0" <<<"$wo" && grep -q "^  STALE .*g_no_such_guard_by_the_ratchet_gate" <<<"$wo" && grep -qE "^refusal read at the cap: 0 of [1-9][0-9]* guards, silent: 1$" <<<"$wo"'
nsk=$(sed -n 's/^set aside as not shipped by .*: \([0-9]*\) table(s) and \([0-9]*\) local(s) a program fills, in \([0-9]*\) of \([0-9]*\) declared file(s); linked, header or stale declarations: \([0-9]*\)$/\1 \2 \3 \4 \5/p' <<<"$out")
read -r nst nsl nsf nsn nsx <<<"${nsk:-- - - - -}"
ck "9 THE NOT-SHIPPED DECLARATION (CEO-1235 (3)): the real tree sets aside $nst tables and $nsl locals a program fills in $nsf of $nsn declared units, every row checked against the scrip and libscrip_rt link lines (linked, header or stale: $nsx)" '[ -n "$nsk" ] && [ "$nsx" = 0 ] && [ "$nsn" -gt 0 ]'
printf 'src/driver/scrip.c\tthe scrip link\nsrc/runtime/rtx/rtx_str.s\tthe libscrip_rt link\nsrc/ir/IR.h\ta header\nsrc/no_such_unit_by_the_ratchet_gate.c\ta file the tree does not have\n' > "$WORK/ns_bad.tsv"
bo=$(cd "$ROOT" && DYN_CAPS_NOT_SHIPPED="$WORK/ns_bad.tsv" bash "$WIT" census 2>&1); brc=$?
bn=$(sed -n 's/^fixed-bound declarations[^:]*: \([0-9]*\) (baseline.*/\1/p' <<<"$bo"); bfn=$(sed -n 's/^function-scope arrays a program fills: \([0-9]*\) (baseline.*/\1/p' <<<"$bo")
ck "10 FAIL-ONCE: a declaration of only wrong rows names each RED and sets nothing aside -- the census reads the real counts plus what the real declaration sets aside ($n + $nst -> ${bn:-?}, $fn + $nsl -> ${bfn:-?}), rc $brc" '[ "$brc" = 1 ] && [ -n "$bn" ] && [ "$bn" = "$((n + nst))" ] && [ "$bfn" = "$((fn + nsl))" ] && grep -q "^  LINKED  src/driver/scrip.c " <<<"$bo" && grep -q "^  LINKED  src/runtime/rtx/rtx_str.s " <<<"$bo" && grep -q "^  HEADER  src/ir/IR.h " <<<"$bo" && grep -q "^  STALE   src/no_such_unit_by_the_ratchet_gate.c " <<<"$bo" && grep -q "linked, header or stale declarations: 4$" <<<"$bo"'
: > "$WORK/no_witnesses.tsv"
zo=$(cd "$ROOT" && DYN_CAPS_WITNESSES="$WORK/no_witnesses.tsv" bash "$WIT" witness 2>&1); zrc=$?
zn=$(grep -c '^  NO WITNESS  ' <<<"$zo")
{ grep -v '^#' "$HERE/fixtures/dyn_caps/CLASS_AB.tsv"; sed -n 's/^  NO WITNESS  \(.*\):\([^:]*\)$/\1\t\2\tA\tthe gate declares every LOUD guard so the verb reads 0 of 0/p' <<<"$zo"; } > "$WORK/ab_all.tsv"
zo2=$(cd "$ROOT" && DYN_CAPS_CLASS_AB="$WORK/ab_all.tsv" DYN_CAPS_WITNESSES="$WORK/no_witnesses.tsv" bash "$WIT" witness 2>&1); zrc2=$?
# ⛔ AND IN THAT STATE A LEFTOVER WITNESS ROW IS STALE: with no LOUD guard the list of guards is an EMPTY file, and an awk reading two files
# with FNR==NR takes the SECOND file's rows as the first's when the first is empty -- the stale check read every row as a live guard and
# a 0 of 0 with the whole witness table left behind read GREEN. The verb reads FILENAME==ARGV[1]; this run holds it.
wr=$(grep -v '^#' "$HERE/fixtures/dyn_caps/WITNESSES.tsv" | awk -F'\t' 'NF >= 6' | wc -l)
zo3=$(cd "$ROOT" && DYN_CAPS_CLASS_AB="$WORK/ab_all.tsv" bash "$WIT" witness 2>&1); zrc3=$?
ck "11 0 OF 0 IS GREEN (CEO-1235 (1)): with no witness the verb reds on the $zn LOUD guards that remain (rc $zrc); with every one of them declared on a scratch CLASS_AB.tsv it reads 0 of 0 and exits $zrc2; and there the $wr rows of the real witness table read STALE, rc $zrc3" '{ [ "$zn" = 0 ] || { [ "$zrc" = 1 ] && grep -q "^refusal read at the cap: 0 of $zn guards, silent: 0$" <<<"$zo"; }; } && [ "$zrc2" = 0 ] && grep -q "^refusal read at the cap: 0 of 0 guards, silent: 0$" <<<"$zo2" && grep -q "^  no LOUD guard remains" <<<"$zo2" && grep -q "^GREEN \[witness\]$" <<<"$zo2" && { [ "$wr" = 0 ] || { [ "$zrc3" = 1 ] && [ "$(grep -c "^  STALE " <<<"$zo3")" = "$wr" ]; }; }'
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: 11 arms -- $n fixed tables and $fn locals a program fills, each exactly its baseline; a planted one of each reds; the classifier tells a drop from no guard and a program's fill from a number's digits; $nab tables declared class A/B, none stale; $nst tables and $nsl locals set aside in $nsn not-shipped units, each checked against the link lines; 0 of 0 reads green"; gate_stamp; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $fails of 11 arms red"; gate_stamp; exit 1
