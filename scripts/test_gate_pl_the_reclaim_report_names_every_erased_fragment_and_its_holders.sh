#!/usr/bin/env bash
# test_gate_pl_the_reclaim_report_names_every_erased_fragment_and_its_holders.sh -- ORDER (1) of row
# prolog-the-code-assertz-generates-is-reclaimed-once-nothing-can-reference-it-lon-2026-09-27 (cto 2026-10-09): the report-only
# liveness pass. Under SCRIP_PL_RECLAIM_REPORT=N every Nth erase of a dynamic predicate prints one [PL-RECLAIM] line to stderr:
# its slots, live and erased counts, the erased count kept in the db (erased_n, bumped at rt_pl_db_erase, abolish and the
# retractall erase) beside a recount of the slots, the code pages of the erased fragments (each slot's frag word records its
# fragment's pool pages at pl_db_fragment), and which erased fragments are still HELD: visitor_live counts those named by a
# frame the chain visitor reaches (rt_gc_frames_visit, hq_collector's dac8d2f33: the frame's map lies in the fragment, or a
# PTR_CODE word of its layout points into it), raw_live those named by any word of the running stack, and raw_only those the
# raw scan names and the chain does not -- the frames retained for backtracking, which ORDER (2) must reach through the choice
# links before any drop is decided. The report decides nothing and frees nothing.
#
# ARMS, each in mode 3 and mode 4, each program's stdout equal to swipl's:
#   (1) an assert/retract loop of 200 cycles reported every 50: three lines, erased == recount, unrecorded 0, visitor whole,
#       visitor_live 0 and raw_only 0 (no erased fact is running), erased_pages at least erased; and with no knob, no line at all.
#   (2) a running clause that retracts itself: the chain sees it, visitor whole and visitor_live 1.
#   (3) s/1 erased while q/1's retained frame (q calls s, s leaves a choice, r calls q and exits) holds a resume address into s:
#       raw_live 1, and the holder is accounted -- visitor_live + raw_only == 1. Measured on SCRIP decbcbba5 plus this landing:
#       visitor_live 0 and raw_only 1 in both modes, the gap the choice-link walk closes; the arm stays green when it does.
# FAIL_ONCE=1 requires arm (2) to read visitor_live 0, so it must red.
# THE FACTS-ONLY DATA PATH (hq_runtime, ARCH-PROLOG-DATABASE section 13): a dynamic predicate of ground facts keeps NO code fragment, so the assert/retract loop of arm (1) asserts a clause with a body (true, true), which keeps its fragment and so keeps what this gate reclaims.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=pl_the_reclaim_report_names_every_erased_fragment_and_its_holders
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plrr.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
printf '%s\n' ':- initialization(main).' ':- dynamic(pi/3).' 'loop(0) :- !.' 'loop(N) :- ( retract((pi(a, 1, M) :- _)) -> true ; M = 0 ), M1 is M + 1, assertz((pi(a, 1, M1) :- true, true)), N1 is N - 1, loop(N1).' 'main :- loop(200), pi(a, 1, V), write(V), nl, halt.' > "$W/w1.pl"
printf '200\n' > "$W/w1.ref"
printf '%s\n' ':- initialization(main).' ':- dynamic(p/1).' 'main :- assertz((p(X) :- retract((p(_) :- _)), Y = done, X = Y)), p(A), write(self(A)), nl, halt.' > "$W/w2.pl"
printf 'self(done)\n' > "$W/w2.ref"
printf '%s\n' ':- initialization(main).' ':- dynamic(q/1).' ':- dynamic(s/1).' 'r(X) :- q(X).' 'main :- assertz((s(X) :- member(X, [1, 2, 3]))), assertz((q(X) :- s(Y), X = f(Y))), r(B), B == f(1), retract((s(_) :- _)), write(kept(B)), nl, halt.' > "$W/w3.pl"
printf 'kept(f(1))\n' > "$W/w3.ref"
for w in w1 w2 w3; do
    ( cd "$W" && "$ROOT/scrip" --compile --out="$W/$w.s" "$W/$w.pl" < /dev/null > "$W/$w.cerr" 2>&1 ) || { echo "GATE REFUSED(2) [$G]: $w does not compile ($(head -c 120 "$W/$w.cerr"))"; exit 2; }
    gcc -no-pie -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/$w.lerr" 2>&1 || { echo "GATE REFUSED(2) [$G]: $w does not link"; exit 2; }
done
run() {
    local w="$1" mode="$2" knob="$3" tag="$1.$2.${3:-none}"
    if [ "$mode" = m3 ]; then ( cd "$W" && env ${knob:+SCRIP_PL_RECLAIM_REPORT=$knob} timeout -k 5 60 "$ROOT/scrip" "$W/$w.pl" < /dev/null > "$W/$tag.out" 2> "$W/$tag.err" ); else ( cd "$W" && env ${knob:+SCRIP_PL_RECLAIM_REPORT=$knob} timeout -k 5 60 "$W/$w.bin" < /dev/null > "$W/$tag.out" 2> "$W/$tag.err" ); fi
    echo $? > "$W/$tag.rc"
    grep '^\[PL-RECLAIM\]' "$W/$tag.err" > "$W/$tag.rep"
}
field() { grep -o " $2=[^ ]*" <<<"$1" | head -1 | cut -d= -f2; }
bad=0
for mode in m3 m4; do
    run w1 $mode 50; run w1 $mode ""; run w2 $mode 1; run w3 $mode 1
    for t in w1.$mode.50 w1.$mode.none w2.$mode.1 w3.$mode.1; do
        w=${t%%.*}
        if [ "$(cat "$W/$t.rc")" != 0 ] || ! cmp -s "$W/$t.out" "$W/$w.ref"; then echo "  RED $t: rc=$(cat "$W/$t.rc"), stdout differs from swipl's"; bad=1; fi
    done
    n=$(wc -l < "$W/w1.$mode.50.rep"); ok1=1
    [ "$n" -eq 3 ] || ok1=0
    while IFS= read -r l; do
        [ "$(field "$l" erased)" = "$(field "$l" recount)" ] && [ "$(field "$l" unrecorded)" = 0 ] && [ "$(field "$l" visitor)" = whole ] && [ "$(field "$l" visitor_live)" = 0 ] && [ "$(field "$l" raw_only)" = 0 ] && [ "$(field "$l" erased_pages)" -ge "$(field "$l" erased)" ] || ok1=0
    done < "$W/w1.$mode.50.rep"
    [ -s "$W/w1.$mode.none.rep" ] && ok1=0
    if [ $ok1 = 1 ]; then echo "  ok  (1) $mode: $n reports, erased == recount, nothing unrecorded, the visitor whole, no erased fact held; silent with no knob"; else echo "  RED (1) $mode: the loop's reports are wrong:"; sed 's/^/      /' "$W/w1.$mode.50.rep" "$W/w1.$mode.none.rep" | head -6; bad=1; fi
    l=$(head -1 "$W/w2.$mode.1.rep"); want=1; [ "${FAIL_ONCE:-0}" = 1 ] && want=0
    if [ -n "$l" ] && [ "$(field "$l" visitor)" = whole ] && [ "$(field "$l" visitor_live)" = "$want" ]; then echo "  ok  (2) $mode: the self-erasing clause is held by the chain (visitor_live $want)"; else echo "  RED (2) $mode: want visitor whole and visitor_live $want: ${l:-no report}"; bad=1; fi
    l=$(head -1 "$W/w3.$mode.1.rep")
    if [ -n "$l" ] && [ "$(field "$l" raw_live)" = 1 ] && [ $(( $(field "$l" visitor_live) + $(field "$l" raw_only) )) -eq 1 ]; then echo "  ok  (3) $mode: the two-deep retained holder is seen (visitor_live $(field "$l" visitor_live), raw_only $(field "$l" raw_only))"; else echo "  RED (3) $mode: want raw_live 1 and the holder accounted once: ${l:-no report}"; bad=1; fi
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: the reclaim report counts every erased fragment and names its holders in both modes (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: the reclaim report miscounts an erased fragment or misses a holder (tree SCRIP=$TREE)"; exit 1
