#!/usr/bin/env bash
# test_gate_pl_setup_call_cleanup_runs_its_cleanup_on_every_road.sh -- setup_call_cleanup/3 runs its cleanup as swipl does on every
# road out of G: a deterministic exit (at once), a nondeterministic exit (not yet), G's exhaustion, a ball raised inside G, a ball
# raised after a nondeterministic exit (G's bindings undone to the construct's mark, S's kept), and the cut, the if-then-else commit,
# the negation, once/1, a catch/3 goal's cut and an inline call/1's cut that drop G's choices -- with the cleanup goal a heap term that
# survives every forced collection while its record is PENDING. Row prolog-logtalk-setup-call-cleanup-3-runs-cleanup-at-the-first-exit-
# of-a-nondeterministic-goal (cto 2026-10-09); the design and its reviews are in the row's baton.
#
# THE WITNESSES AND THEIR REFS, cut from swipl 9.0.4: ../harness/scripts/fixtures/hb_pl_setup_call_cleanup_runs_its_cleanup_on_every_road.pl
# (eighteen shapes; none prints a variable's name or depends on swipl's last-solution determinism of member/2) and
# ../harness/scripts/gc_witnesses/hb_pl_setup_call_cleanup_pending_record_survives_collections.pl (a cut in the clause, a cut in the caller,
# exhaustion and a ball after a redo, each three times, the cleanup summing a 50-element list it holds while garbage is made).
# ARMS: (1) mode 3 and (2) mode 4 equal the first ref; (3)-(6) the second ref in mode 3 and mode 4 at a 64 KB window under SCRIP_GC_STRESS=1 and 3 with
# SCRIP_GC_CHAIN_CHECK=3, reading bad-link 0, offchain-swept 0, mismatch 0 and missing 0 beside the answer (hq_collector's condition:
# the record's C is visited through the retained frame by the chain, not by the marker scan STEP B removes).
# FAIL_ONCE=1 grades the first witness against a ref with its first cleanup line removed, so arms 1 and 2 must red.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=pl_setup_call_cleanup_runs_its_cleanup_on_every_road
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
S1="$HERE/fixtures/hb_pl_setup_call_cleanup_runs_its_cleanup_on_every_road.pl"; S2="$HERE/gc_witnesses/hb_pl_setup_call_cleanup_pending_record_survives_collections.pl"
for f in "$S1" "$S2"; do [ -f "$f" ] && [ -s "${f%.pl}.ref" ] || { echo "GATE REFUSED(2) [$G]: the witness or its ref is missing ($f)"; exit 2; }; done
W="$(mktemp -d "${TMPDIR:-/tmp}/plscc.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cp "$S1" "$W/r.pl"; cp "$S2" "$W/c.pl"; cp "${S2%.pl}.ref" "$W/c.ref"
if [ "${FAIL_ONCE:-0}" = 1 ]; then awk '!d && /^cleanup/ {d=1; next} {print}' "${S1%.pl}.ref" > "$W/r.ref"; else cp "${S1%.pl}.ref" "$W/r.ref"; fi
for w in r c; do
    ( cd "$W" && "$ROOT/scrip" --compile --out="$W/$w.s" "$W/$w.pl" < /dev/null > "$W/$w.cerr" 2>&1 ) || { echo "GATE REFUSED(2) [$G]: the $w witness does not compile ($(head -c 120 "$W/$w.cerr"))"; exit 2; }
    gcc -no-pie -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/$w.lerr" 2>&1 || { echo "GATE REFUSED(2) [$G]: the $w witness does not link"; exit 2; }
done
run_arm() {
    local n="$1" w="$2" mode="$3" stress="$4" rc
    if [ "$mode" = m3 ]; then ( cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB $stress timeout -k 5 300 "$ROOT/scrip" "$W/$w.pl" < /dev/null > "$W/$n.out" 2> "$W/$n.err" ); rc=$?
    else ( cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB $stress timeout -k 5 300 "$W/$w.bin" < /dev/null > "$W/$n.out" 2> "$W/$n.err" ); rc=$?; fi
    grep -v '^\[GC-' "$W/$n.out" > "$W/$n.txt"
    if [ "$rc" -ne 0 ] || ! cmp -s "$W/$n.txt" "$W/$w.ref"; then echo "  RED ($n) $mode${stress:+ $stress}: rc=$rc, the output differs from swipl's:"; diff "$W/$w.ref" "$W/$n.txt" | head -6; return 1; fi
    if [ -n "$stress" ]; then
        local k v reading=""
        for k in bad-link offchain-swept mismatch missing; do
            v=$(grep -h -o "$k=[0-9]*" "$W/$n.err" "$W/$n.out" | head -1)
            [ -n "$v" ] || { echo "  RED ($n) $mode $stress: the chain check printed no $k reading"; return 1; }
            [ "$v" = "$k=0" ] || { echo "  RED ($n) $mode $stress: the chain reads $v"; return 1; }
            reading="$reading $v"
        done
        echo "  ok  ($n) $mode under $stress: the swipl lines, the chain reads$reading"
    else
        echo "  ok  ($n) $mode: rc 0, the swipl lines"
    fi
    return 0
}
bad=0
run_arm 1 r m3 "" || bad=1
run_arm 2 r m4 "" || bad=1
run_arm 3 c m3 "SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3" || bad=1
run_arm 4 c m3 "SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=3 SCRIP_GC_CHAIN_CHECK=3" || bad=1
run_arm 5 c m4 "SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3" || bad=1
run_arm 6 c m4 "SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=3 SCRIP_GC_CHAIN_CHECK=3" || bad=1
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: setup_call_cleanup runs its cleanup on every road as swipl does in both modes, and its record's cleanup term is visited by the chain under forced collections (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a setup_call_cleanup road answers differently from swipl, or the chain lost the record's frame (tree SCRIP=$TREE)"; exit 1
