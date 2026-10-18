#!/usr/bin/env bash
# test_gate_sno_eval_chains_nothing_references_are_reclaimed_and_a_full_code_pool_is_loud.sh -- EVAL's compiled chains: reclaimed when nothing
# can reference them, and a full code pool is error 204, never a quiet FAIL (hq_icon 2026-10-03, ceo row
# snobol4-after-about-523000-distinct-evals-every-later-eval-fails-in-one-scrip-process).
#
# MEASURED 2026-10-03 on f7e45d9de: inf_eval.sno over 600,000 DISTINCT lines `'y-z' ? BAL | LEN(i % 3) | 'q<i>'` answers as sbl for 523,251 lines and
# FAIL for every line after. Cause: bb_pool.c is a fixed 2 GB mmap handing out whole pages; since 5dfcab7c5 eval_string_transient RETAINS every
# distinct chain (releasing one that returned a PATTERN was a use-after-free: the pattern's deferred elements live in the chain), one page each:
# 524,288 pages less the program's own ~1,037 is 523,251. bb_alloc then returned NULL, eval_build_chain returned NULL, and the caller read that as
# "no syntax error found" and answered FAIL. Cure (runtime_eval.c, bb_pool.c, gc_heap.c, core.c): (1) a chain is released after its run when it
# provably cannot be referenced -- it created no pattern or expression thunk, its result is a plain value (string, number, array, table, name,
# keyword, data, fail), and nothing was added to the pool above it while it ran -- and only on the first sighting of its text (a second sighting
# is cached as before, so a hot expression compiles twice and runs from the cache); (2) bb_pool_release drops the GC frame maps registered inside
# the pages it frees, a dormant dangling-map hazard of the old release path; (3) a pool with less than 4 MB free (the smallest chain reservation)
# raises error 204 naming the pool instead of FAIL, from EVAL, CONVERT, CODE and runtime pattern builds. SCRIP_CODE_POOL_MB (8..2048) lowers
# the pool so this gate fills it in seconds. Arms, each byte-identical to sbl -bf in both modes except arm C: A 6000 distinct scalar EVALs in a
# 16 MB pool; B pattern- and expression-valued EVALs built, then 3000 distinct scalar EVALs recycle the pool, then the patterns are used; C 20000
# distinct pattern EVALs overflow the same pool: rc != 0, stderr names error 204 and the pool, stdout carries no `FAIL at`. FAIL_ONCE=1 corrupts
# arm A's expected line to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ REFUSE(2): no sbl at $SBL -- the expected output is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/a.sno" <<'SNO'
        &TRIM = 1
        i = 0
loop    r = EVAL("'k" i "' ? LEN(" REMDR(i, 3) ") | 'x'")  :F(bad)
        i = i + 1
        LT(i, 6000)                                          :S(loop)
        OUTPUT = 'all ' i ' answered'                        :(END)
bad     OUTPUT = 'FAIL at ' i
END
SNO
cat > "$T/b.sno" <<'SNO'
        &TRIM = 1
        X = 'b'
        P1 = EVAL("LEN(2) 'x'")
        P2 = EVAL("'a' *X")
        P3 = EVAL("LEN(1) . V")
        Q = EVAL("(P4 = LEN(1) 'z')")
        E1 = EVAL("*X")
        A = EVAL("'abc'")
        T = EVAL("TABLE()")
        i = 0
churn   EVAL("'filler" i "' ? LEN(" REMDR(i, 3) ") | 'x'")
        i = i + 1
        LT(i, 3000)                                          :S(churn)
        'abx' P1                                             :F(f1)
        OUTPUT = 'P1 ok'                                     :(n2)
f1      OUTPUT = 'P1 fail'
n2      'ab' P2                                              :F(f2)
        OUTPUT = 'P2 ok'                                     :(n3)
f2      OUTPUT = 'P2 fail'
n3      'k' P3                                               :F(f3)
        OUTPUT = 'P3 ok ' V                                  :(n4)
f3      OUTPUT = 'P3 fail'
n4      'yz' P4                                              :F(f4)
        OUTPUT = 'P4 ok'                                     :(n5)
f4      OUTPUT = 'P4 fail'
n5      OUTPUT = DATATYPE(E1) ' ' EVAL(E1) ' ' A ' ' DATATYPE(T)
END
SNO
cat > "$T/c.sno" <<'SNO'
        &TRIM = 1
        i = 0
loop    P = EVAL("LEN(" i ") 'z'")                           :F(bad)
        i = i + 1
        LT(i, 20000)                                         :S(loop)
        OUTPUT = 'all ' i ' built'                           :(END)
bad     OUTPUT = 'FAIL at ' i
END
SNO
for W in a b; do ( cd "$T" && "$SBL" -bf $W.sno < /dev/null ) > "$T/$W.ref" 2>&1 || { echo "⛔ REFUSE(2): sbl did not run witness $W"; exit 2; }; done
[ "$(cat "$T/a.ref")" = "all 6000 answered" ] || { echo "⛔ REFUSE(2): sbl's own stream for arm A is not 'all 6000 answered'"; exit 2; }
[ "$(grep -c . "$T/b.ref")" = 5 ] && grep -q '^P1 ok$' "$T/b.ref" || { echo "⛔ REFUSE(2): sbl's own stream for arm B is not the five lines this gate expects"; exit 2; }
RC=0
for M in m3 m4; do
  for W in a b c; do
    if [ "$M" = m4 ]; then ( cd "$T" && "$SCRIP" --compile -o $W.s $W.sno </dev/null && gcc $W.s -o $W.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness $W did not build"; exit 2; }; fi
    ( cd "$T" && if [ "$M" = m3 ]; then SCRIP_CODE_POOL_MB=16 timeout -k 5 120 "$SCRIP" $W.sno </dev/null; else SCRIP_CODE_POOL_MB=16 LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 120 ./$W.bin </dev/null; fi ) >"$T/$M.$W.out" 2>"$T/$M.$W.err"; echo $? > "$T/$M.$W.rc"
  done
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i 's/^all 6000 answered$/all 6000 answeredX/' "$T/$M.a.out"; fi
  for W in a b; do
    if cmp -s "$T/$W.ref" "$T/$M.$W.out"; then echo "  $M arm $W PASS (byte-identical to sbl -bf: $(head -c 60 "$T/$M.$W.out" | head -1))"
    else echo "  $M arm $W FAIL (rc $(cat "$T/$M.$W.rc")): $(diff "$T/$W.ref" "$T/$M.$W.out" | head -4 | tr '\n' '|')"; RC=1; fi
  done
  if [ "$(cat "$T/$M.c.rc")" != 0 ] && grep -q 'error 204' "$T/$M.c.err" && grep -q 'compiled-code pool' "$T/$M.c.err" && ! grep -q 'FAIL at' "$T/$M.c.out"; then echo "  $M arm c PASS (a full pool is error 204 naming the pool, rc $(cat "$T/$M.c.rc"), no quiet FAIL)"
  else echo "  $M arm c FAIL (rc $(cat "$T/$M.c.rc")): stdout [$(head -c 80 "$T/$M.c.out")] stderr [$(head -c 160 "$T/$M.c.err")]"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: distinct scalar EVALs are reclaimed, pattern and expression values survive a recycled pool, and a full code pool is error 204 (3 arms x 2 modes)"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: EVAL's chain reclamation or the full-pool refusal is wrong (examined 3 arms x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $SBL  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
