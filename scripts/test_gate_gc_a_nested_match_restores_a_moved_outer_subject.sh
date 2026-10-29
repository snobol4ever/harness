#!/usr/bin/env bash
# test_gate_gc_a_nested_match_restores_a_moved_outer_subject.sh -- A COLLECTION INSIDE A NESTED PATTERN MATCH NEVER LEAVES THE
# OUTER MATCH ON A MOVED SUBJECT (row gc-a-nested-match-restores-its-callers-subject-from-a-raw-pushed-register-so-a-collection-
# inside-it-leaves-the-outer-match-on-a-moved-subject; found by hq_snocone 2026-09-25 on the parser census, 322 of 944 SNOBOL4 corpus
# sources crashing parser_snobol4; cured by the cfo, CEO-1270).
#
# THE DEFECT: bb_match_begin saves its caller's match registers with push r12..r15 as RAW words -- r13, the outer subject base, at
# rbp-16 -- and rt_match_enter overwrites the rooted global Σ with the inner subject. A collection INSIDE the nested match (a deferred
# *f(x) whose function allocates) moves the outer subject; nothing visits the pushed r13; the nested match's exit (bb_match_begin's
# omega, bb_match_end's release) handed that stale word to rt_match_ctx_restore, which stored it in Σ, and reloaded r13 from it.
# THE CURE (the frozen design, CEO-812: a saved subject is a word the collector visits, never a conservative scan, never a pin),
# AS IT STANDS SINCE CEO-1302 (cfo 2026-09-27): the match box's OWN FRAME carries the outer subject. bb_match_begin writes a tagged
# DESCR cell {DT_S, slen=Σlen, s=Σ} at rbp-56-extra (MATCH_CTX_CELL_OFF, emit.h; the 32 bytes ride emit_match_begin_frame_extra so
# every cross-frame offset sees them) and the pre-move key -Σ beside it -- negated, so it can never read as a heap pointer. The
# collector's spine walk visits the tagged cell and relocates its s. Both exits hand the cell to rt_match_ctx_restore, which returns
# the relocated s when the word the frame pushed is the recorded subject (-r13 == key), and the pushed word unchanged when it is not.
# The first cure (5fc6651ca) kept that record in g_mctx, a runtime vector on the collected heap keyed by rbp: new runtime state that no
# exemption reached (CEO-1302), deleted by this move. FAIL-ONCE measured on the move: tagging the cell DT_SNUL, a tag the spine walk
# never relocates, reds arm 1.
#
# ARM 1 (the row's DONE-WHEN): hq_snocone's 17-line witness in mode 3 and mode 4 at SCRIP_GC_STRESS 1 2 5 20 100 prints what
# sbl -bf prints. The 200000-byte dead block below the subject is what makes the collection move the outer subject far enough to land
# on a quarantined page; without it the stale read lands on the subject's own shifted bytes and passes silently.
# ARM 2 (the arm cannot pass vacuously): at SCRIP_GC_STRESS=5 the mode-3 run reports at least one collection (SCRIP_GC_EXERCISE=1).
# FAIL-ONCE: SCRIP_BIN may name another tree's scrip (its out/ is used for mode 4). On the parent of the cure (origin 40df9b119) arm 1
# reads RED at stress 5, 20 and 100 in mode 3 and at 5 in mode 4 ([ZGC-STALE] SIGSEGV).
# rc 0 GREEN · 1 RED (named) · 2 REFUSE (cannot measure).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
TREE="$(cd "$(dirname "$SCRIP")" && pwd)"; LIBDIR="$TREE/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no correctness oracle ($SBL) -- the ref is cut from the oracle at run time, never typed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
export SNO_LIB="${SNO_LIB:-$ROOT/../corpus/include}"
printf "\tDEFINE('H(s)')\t:(HE)\nH\tH = REPLACE(s, &LCASE, &UCASE)\t:(RETURN)\nHE\n\tDEFINE('G(t)')\t:(GE)\nG\t'ABS AND ANY APPEND' ? *H(t)\t:F(FRETURN)\n\tN = N + 1\n\tG = .dummy\t:(NRETURN)\nGE\n\tN = 0\n\tG1 = DUPL('x', 200000)\n\tS = DUPL('and ', 300)\n\tG1 = ''\n\tS ? ARBNO(SPAN(&LCASE) \$ tx \$ *G(tx) ' ') RPOS(0)\t:S(Y)F(N)\nY\tOUTPUT = 'S ' tx ' ' N\t:(E)\nN\tOUTPUT = 'F ' N\nE\nEND\n" > "$T/w.sno"
( cd "$T" && timeout -k 5 30 "$SBL" $(sbl_lang_flags) w.sno < /dev/null > w.ref 2> /dev/null )
[ -s "$T/w.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for the witness"; exit 2; }
RC=0; red=""
( cd "$T" && timeout -k 5 60 "$SCRIP" --compile --out=w.s w.sno < /dev/null > /dev/null 2>&1 && gcc w.s -o w.bin -L"$LIBDIR" -lscrip_rt -lm -lpthread -Wl,-rpath,"$LIBDIR" 2> /dev/null ) || { echo "⛔ GATE REFUSE(2) [$G]: the witness did not compile or link in mode 4"; exit 2; }
for st in 1 2 5 20 100; do
    ( cd "$T" && SCRIP_GC_STRESS=$st timeout -k 5 60 "$SCRIP" w.sno < /dev/null > m3.$st 2> m3e.$st ); r3=$?
    cmp -s "$T/m3.$st" "$T/w.ref" && [ "$r3" = 0 ] || red="$red m3@$st(rc=$r3 $(head -c 70 "$T/m3e.$st" | tr '\n' ' '))"
    ( cd "$T" && SCRIP_GC_STRESS=$st timeout -k 5 60 ./w.bin < /dev/null > m4.$st 2> m4e.$st ); r4=$?
    cmp -s "$T/m4.$st" "$T/w.ref" && [ "$r4" = 0 ] || red="$red m4@$st(rc=$r4 $(head -c 70 "$T/m4e.$st" | tr '\n' ' '))"
done
if [ -z "$red" ]; then echo "  arm 1 PASS: the nested-match witness prints '$(tr '\n' ' ' < "$T/w.ref")' like sbl -bf in mode 3 and mode 4 at SCRIP_GC_STRESS 1 2 5 20 100 -- a collection inside the nested match leaves the outer match on its moved subject's NEW address"
else echo "  arm 1 RED:$red -- the outer match resumed on a subject the collector moved"; RC=1; fi
( cd "$T" && SCRIP_GC_STRESS=5 SCRIP_GC_EXERCISE=1 timeout -k 5 60 "$SCRIP" w.sno < /dev/null > /dev/null 2> ex.err )
nc=$(sed -n 's/.*\[GC-EXERCISE\].*collections=\([0-9]*\).*/\1/p' "$T/ex.err" | tail -1)
if [ "${nc:-0}" -ge 1 ]; then echo "  arm 2 PASS: the stress-5 run collected $nc time(s) -- arm 1 measured a moving heap, not a quiet one"
else echo "  arm 2 RED: the stress-5 run reported ${nc:-no} collections, so arm 1 could have passed without the subject ever moving"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: a nested match restores the outer subject's current address after a collection inside it (2 arms)"
else echo "GATE FAIL(1) [$G]: a nested match left its caller on a moved subject, or the gate measured no collection (2 arms)"; fi
echo "    tree: SCRIP=$(git -C "$TREE" rev-parse --short HEAD 2>/dev/null)$(git -C "$TREE" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
