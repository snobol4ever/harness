#!/usr/bin/env bash
# test_gate_sno_a_distinct_eval_text_leaves_no_residue_once_its_chain_is_released.sh -- an EVAL whose chain is released (56de2bc13) leaves
# nothing behind: no cache entry the collector must keep, no compile-time arena block (cfo 2026-10-03, row
# snobol4-a-distinct-eval-text-leaves-a-cache-key-and-1-5-kb-of-compile-time-arena-behind-forever-so-150k-distinct-evals-die-at-a-16-mb-cap).
#
# MEASURED 2026-10-03 on SCRIP 745a917ea (the cfo's review of the ceo's 56de2bc13): a program evaluating N DISTINCT texts `i " + 1"` grows without
# bound where sbl -bf stays flat at 3 MB. Peak RSS 67 MB at 20k, 277 MB at 100k, 803 MB at 300k (the same loop over 10 repeated texts: 15 MB flat).
# Two residues per distinct text: (1) THE COLLECTED HEAP: eval_chain_settle inserts a "seen once" marker (key, NULL) for every released chain and the
# cache never drops one, so eval_gc_roots keeps every key alive -- live blocks at exit 20450 at 20k against 460 for the repeated control; under a
# declared -d16m, 150,000 distinct EVALs die with error 204 when the cache table doubles, where sbl -bf -d16m finishes in 0.07 s. (2) THE
# COMPILE-TIME ARENA: ct_arena_bytes() climbs 1472 bytes per distinct EVAL and never comes back (77.6 MB control, 107.3 MB at 20k, 226.3 MB at 100k):
# the reentrant scanner is never destroyed, the parser's statement record and the statement AST's attribute strings and child vector are
# abandoned, the IR_GOTO nodes the optimizer splices out of g->all are never dropped, and IR_free drops no node's operand vector.
# Arms, each in both modes: A live blocks at exit after 20000 distinct EVALs (SCRIP_GC_EXERCISE=1) within 2000 of the 10-text control;
# B peak RSS of 60000 distinct EVALs within 8192 KB of 20000 distinct EVALs (40000 more texts may cost at most ~200 bytes each);
# C every witness's stdout byte-identical to sbl -bf; D 200000 EVALs over 10 texts finish inside 20 s, so a cache that stopped caching reds here.
# FAIL_ONCE=1 adds 1,000,000 to arm A's distinct reading to prove the bound arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ REFUSE(2): no sbl at $SBL -- the expected output is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
TIMEB=/usr/bin/time; [ -x "$TIMEB" ] || { echo "⛔ REFUSE(2): no $TIMEB -- arm B reads the peak RSS through it"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
wit() { printf '        &TRIM = 1\n        i = 0\nloop    i = i + 1\n        V = EVAL(%s " + 1")                 :F(bad)\n        LT(i, %d)                           :S(loop)\n        OUTPUT = '"'"'done '"'"' i '"'"' '"'"' V           :(END)\nbad     OUTPUT = '"'"'FAIL at '"'"' i\nEND\n' "$1" "$2" > "$T/$3.sno"; }
wit i 20000 d20; wit i 60000 d60; wit 'REMDR(i, 10)' 20000 r20; wit 'REMDR(i, 10)' 200000 r200
for W in d20 d60 r20 r200; do ( cd "$T" && "$SBL" -bf $W.sno < /dev/null ) > "$T/$W.ref" 2>&1 || { echo "⛔ REFUSE(2): sbl did not run witness $W"; exit 2; }; done
grep -q '^done 60000 60001$' "$T/d60.ref" && grep -q '^done 200000 1$' "$T/r200.ref" || { echo "⛔ REFUSE(2): sbl's own streams are not the lines this gate expects"; exit 2; }
RC=0
for M in m3 m4; do
  for W in d20 d60 r20 r200; do
    if [ "$M" = m4 ]; then ( cd "$T" && "$SCRIP" --compile -o $W.s $W.sno </dev/null && gcc $W.s -o $W.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness $W did not build"; exit 2; }; fi
    LIM=120; [ "$W" = r200 ] && LIM=20
    ( cd "$T" && if [ "$M" = m3 ]; then SCRIP_GC_EXERCISE=1 "$TIMEB" -f 'MAXRSS_KB=%M' -o $M.$W.rss timeout -k 5 $LIM "$SCRIP" $W.sno </dev/null; else SCRIP_GC_EXERCISE=1 LD_LIBRARY_PATH="$ROOT/out" "$TIMEB" -f 'MAXRSS_KB=%M' -o $M.$W.rss timeout -k 5 $LIM ./$W.bin </dev/null; fi ) >"$T/$M.$W.out" 2>"$T/$M.$W.err"; echo $? > "$T/$M.$W.rc"
    if cmp -s "$T/$W.ref" "$T/$M.$W.out"; then echo "  $M arm C $W PASS (byte-identical to sbl -bf: $(head -1 "$T/$M.$W.out"))"
    else echo "  $M arm C $W FAIL (rc $(cat "$T/$M.$W.rc")): $(diff "$T/$W.ref" "$T/$M.$W.out" | head -3 | tr '\n' '|') $(grep -v '^\[GC-EXERCISE\]' "$T/$M.$W.err" | head -2 | tr '\n' '|' | cut -c1-200)"; RC=1; fi
  done
  bl() { sed -n 's/.*\[GC-EXERCISE\].* blocks=\([0-9]*\) .*/\1/p' "$T/$M.$1.err" | tail -1; }
  rss() { sed -n 's/^MAXRSS_KB=\([0-9]*\)$/\1/p' "$T/$M.$1.rss" | tail -1; }
  BD=$(bl d20); BR=$(bl r20); [ -n "$BD" ] && [ -n "$BR" ] || { echo "⛔ REFUSE(2): $M printed no [GC-EXERCISE] blocks= line (d20 '$BD', r20 '$BR')"; exit 2; }
  [ -n "${FAIL_ONCE:-}" ] && BD=$((BD + 1000000))
  if [ "$BD" -le $((BR + 2000)) ]; then echo "  $M arm A PASS (live blocks at exit: 20000 distinct $BD, 10-text control $BR)"
  else echo "  $M arm A FAIL (live blocks at exit: 20000 distinct $BD against the 10-text control $BR; the bound is control + 2000)"; RC=1; fi
  K20=$(rss d20); K60=$(rss d60); [ -n "$K20" ] && [ -n "$K60" ] || { echo "⛔ REFUSE(2): $M has no peak RSS reading (d20 '$K20', d60 '$K60')"; exit 2; }
  if [ "$K60" -le $((K20 + 8192)) ]; then echo "  $M arm B PASS (peak RSS: 20000 distinct ${K20} KB, 60000 distinct ${K60} KB)"
  else echo "  $M arm B FAIL (peak RSS: 20000 distinct ${K20} KB, 60000 distinct ${K60} KB -- $(( (K60 - K20) * 1024 / 40000 )) bytes per further distinct text; the bound is 8192 KB)"; RC=1; fi
  if [ "$(cat "$T/$M.r200.rc")" = 0 ]; then echo "  $M arm D PASS (200000 EVALs over 10 texts inside 20 s)"; else echo "  $M arm D FAIL (rc $(cat "$T/$M.r200.rc"): 200000 EVALs over 10 texts did not finish inside 20 s -- the cache stopped caching)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: a released EVAL chain leaves no cache key and no compile-time arena behind (4 arms x 2 modes)"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: distinct EVAL texts still leave residue behind (examined 4 arms x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $SBL  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
