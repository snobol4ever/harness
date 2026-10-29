#!/usr/bin/env bash
# util_pl_rung9_gamma_fence_witness_set.sh
#
# PROLOG ISO LADDER, RUNG 9 -- THE MEASUREMENT HALF, ordered by CEO-690 after Lon ruled the frame question:
#   Lon 2026-09-13, verbatim: "do a whack-free on GAMMA for a FENCE d (i.e. cut !) or otherwise FENCE d
#   operation."
# The frame STAYS on the machine stack and is torn down sooner: succeed through GAMMA with the operation
# FENCED and BETA is unreachable, so the frame is dead at gamma and is whacked there instead of retained for
# a recession that can never come. hq_U OWNS THE BUILD (frames, concern 3); the cto is the measurer on the
# Prolog half and this file is that measurement. IT LANDS NO CURE AND GRADES NO CURE -- the wired verdict for
# rung 9 is test_gate_pl_iso_rung9_a_backtrackable_recursion_reaches_the_depth_the_oracle_reaches.sh, and
# this script exists so that hq_U can re-run the same population after a teardown lands and read which
# constructs moved. Run it before and after; a construct that does not move is a construct the cure missed.
#
# ⭐ THE QUESTION CEO-690 ASKED, and nobody had enumerated: WHICH PROLOG CONSTRUCTS ARE PROVABLY COMMITTED AT
# GAMMA BUT CARRY NO LEXICAL `!`? Each of those is a cut in effect with no cut in the text -- a frame that
# could be whacked today and is not. This script answers it by measurement rather than by reading the
# lowerer, because the lowerer can only say what was intended.
#
# METHOD. One recursion shape, one variable: the goal that sits between the guard and the recursive call.
#     p(0) :- !.
#     p(N) :- N > 0, <BODY>, N1 is N - 1, p(N1).
# <BODY> is the construct under test. The largest N that completes is found by bisection at a `ulimit -s`
# PINNED IN A SUBSHELL AND PRINTED -- an unpinned run grades the shell and not the compiler. Bytes per
# retained frame is the pinned limit divided by that depth, AND THE DIVISOR IS PART OF THE LABEL: this gate's
# sibling published a 4x unit error in 2026-09-13 by taking a depth at one limit and dividing by another.
#
# ⛔ NO NUMBER HERE MEANS ANYTHING ALONE. Every construct lands between two anchors measured in the same run
# on the same tree:
#   UPPER  anchor_cut  `q(_), !`   -- the same nondeterministic call, lexically fenced. The mechanism works
#                                     where it is wired, so this is what a cured construct must reach.
#   LOWER  anchor_cp   `q(_)`      -- the same call with nothing fenced, and the choicepoints it leaves are
#                                     LIVE (see the SAFETY CONTROL below). This is what un-whacked costs.
# A construct sitting at the lower anchor is a PRIZE. A construct sitting at the upper anchor is already
# reclaimed and is reported as such, because a witness set that lists only the red ones cannot show that the
# mechanism exists in the tree already.
#
# ⛔⭐ THE SAFETY CONTROL IS NOT A FOOTNOTE, IT IS THE GRADING CRITERION (CEO-690, CEO-550). GAMMA IS THE
# SHARED YIELD PORT FOR SUSPEND AND RETURN, so a generator that suspends through gamma expects to be resumed
# INTO THAT VERY FRAME. An unconditional whack tears down a frame a redo is about to re-enter. This script
# therefore runs a pair whose ANSWERS separate the two cases, and any cure must keep both:
#   cp(8)   -- `q(X)` un-fenced under a 3-deep recursion has 2^3 solutions; its frames MUST be retained.
#   once(1) -- the same recursion with `once(q(X))` has exactly 1; its frames may be whacked.
# Both are swipl-confirmed. If a teardown lands and cp(8) becomes anything else, the cure is wrong and the
# depth table is irrelevant.
#
# ⛔ AND THE CLASSIFICATION THAT DECIDES HOW A CURE MAY BE KEYED, which is the other half of CEO-690:
#   PER CALL SITE   -- once/1, \+/1, forall/2, the condition of (->)/2, catch/3 over a committed goal. These
#                      are OPAQUE-GOAL BARRIERS: the text of the call site alone proves beta is unreachable,
#                      whatever the argument goal does. A call-site-keyed cure is sound for these.
#   PER ACTIVATION  -- clause selection. Whether a later clause can still match depends on the ARGUMENTS AT
#                      THIS CALL, not on the call site: `d(1,_)` is deterministic and `d(X,_)` with X unbound
#                      is not, at the same site. A call-site-keyed answer here is right in testing and wrong
#                      in the tree, which is exactly the hazard CEO-690 named.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
MODE=m3
PIN_KB=8192
HI=400000
while [ $# -gt 0 ]; do
    case "$1" in
        --mode) MODE="$2"; shift 2;;
        --stack-kb) PIN_KB="$2"; shift 2;;
        --ceiling) HI="$2"; shift 2;;
        *) echo "usage: $(basename "$0") [--mode m3|m4] [--stack-kb N] [--ceiling N]" >&2; exit 2;;
    esac
done
case "$MODE" in m3|m4) ;; *) echo "⛔ REFUSED-TO-MEASURE(2): --mode must be m3 or m4, got '$MODE'" >&2; exit 2;; esac
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-MEASURE(2): no ./scrip at $SCRIP -- nothing was measured" >&2; exit 2; }
[ -e "$ROOT/out/libscrip_rt.so" ] || { echo "⛔ REFUSED-TO-MEASURE(2): no runtime .so -- nothing was measured" >&2; exit 2; }
( ulimit -s "$PIN_KB" ) 2>/dev/null || { echo "⛔ REFUSED-TO-MEASURE(2): cannot pin the stack to ${PIN_KB} KB, so every number below would grade the shell" >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
git -C "$ROOT" diff --quiet 2>/dev/null || TREE="$TREE-dirty"

emit() {
    local f="$1" body="$2" n="$3" pre="${4:-}"
    cat > "$f" <<EOF
:- initialization(main).
q(a). q(b).
r(_).
s(a).
d(1,one). d(2,two). d(3,three).
f(1,one). f(1,two). f(1,three).
e(a). e(b). e(c).
m(1). m(2). m(3). m(4). m(5). m(6). m(7). m(8). m(9). m(10).
m(11). m(12). m(13). m(14). m(15). m(16). m(17). m(18). m(19). m(20).
m(21). m(22). m(23). m(24). m(25). m(26). m(27). m(28). m(29). m(30).
m(31). m(32). m(33). m(34). m(35). m(36). m(37). m(38). m(39). m(40).
m(41). m(42). m(43). m(44). m(45). m(46). m(47). m(48). m(49). m(50).
$pre
p(0) :- !.
p(N) :- N > 0, $body, N1 is N - 1, p(N1).
main :- ( p($n) -> write(ok) ; write(no) ), nl.
EOF
}
runq() {
    local f="$1"
    if [ "$MODE" = m3 ]; then
        ( ulimit -s "$PIN_KB"; timeout -k 5 180 "$SCRIP" "$f" </dev/null 2>&1 )
    else
        ( ulimit -s "$PIN_KB"
          timeout -k 5 180 "$SCRIP" --compile --out="$W/x.s" "$f" </dev/null >/dev/null 2>&1 || exit 9
          cd "$W" && gcc -no-pie x.s -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o x.bin >/dev/null 2>&1 || exit 9
          timeout -k 5 180 ./x.bin </dev/null 2>&1 )
    fi
}
ok_at() { emit "$W/t.pl" "$2" "$3" "${4:-}"; runq "$W/t.pl" | grep -q '^ok$'; }
bisect() {
    local body="$1" pre="${2:-}" lo=100 hi="$HI" mid
    if ok_at x "$body" "$hi" "$pre"; then echo "${hi}+"; return; fi
    if ! ok_at x "$body" "$lo" "$pre"; then echo "<$lo"; return; fi
    while [ $((hi-lo)) -gt $((lo/200 + 2)) ]; do
        mid=$(( (lo+hi)/2 ))
        if ok_at x "$body" "$mid" "$pre"; then lo=$mid; else hi=$mid; fi
    done
    echo "$lo"
}
row() {
    local tag="$1" body="$2" pre="${3:-}" d bpf
    d="$(bisect "$body" "$pre")"
    case "$d" in *+|\<*) bpf="reclaimed";; *) bpf="$(( PIN_KB*1024 / d )) B";; esac
    printf "  %-20s %-30s %-12s %s\n" "$tag" "$body" "$d" "$bpf"
}
echo "rung 9 -- the gamma-fence witness set: which constructs are committed without a lexical cut"
echo "  tree $TREE · mode $MODE · stack PINNED to ${PIN_KB} KB in a subshell · bisection ceiling $HI"
echo "  every depth below is divided by THIS run's ${PIN_KB} KB and by no other limit"
echo
echo "ANCHORS -- nothing below means anything except between these two"
printf "  %-20s %-30s %-12s %s\n" NAME BODY DEPTH PER-FRAME
row anchor_det   "true"
row anchor_cut   "q(_), !"
row anchor_cp    "q(_)"
echo
echo "THE PRIZE -- committed at gamma, no lexical cut, frame NOT reclaimed today (PER CALL SITE)"
printf "  %-20s %-30s %-12s %s\n" NAME BODY DEPTH PER-FRAME
row once_1        "once(q(_))"
row if_then_cond  "( q(_) -> true ; true )"
row forall_2      "forall(q(X), r(X))"
row negation      "\\+ (q(_), fail)"
row catch_3       "catch(once(q(_)), _, true)"
echo
echo "THE PRIZE -- committed at gamma by its ARGUMENTS, frame NOT reclaimed today (PER ACTIVATION)"
printf "  %-20s %-30s %-12s %s\n" NAME BODY DEPTH PER-FRAME
row indexed_clause_1 "d(1, _)"
row indexed_clause_2 "d(2, _)"
row ctl_same_first   "f(1, _)"
echo
echo "ALREADY RECLAIMED -- the mechanism exists in this tree; these are the shapes it already reaches"
printf "  %-20s %-30s %-12s %s\n" NAME BODY DEPTH PER-FRAME
row last_clause_match "d(3, _)"
row single_clause     "s(_)"
row findall_inner     "findall(X, q(X), _)"
echo
echo "THE BLIND SPOT THIS TABLE WOULD OTHERWISE HAVE -- every prize row above uses q/1, a CLAUSE-DEFINED goal,"
echo "and a barrier's reclamation is NOT uniform in the kind of goal it wraps. Measured 2026-09-13: findall"
echo "over a 50-clause fact predicate reaches the ceiling while findall over between/3 with TWO solutions does"
echo "not, and between/3 WITH A LEXICAL CUT reaches the ceiling, so the generator does not leak on its own --"
echo "it leaks only with a barrier between it and the fence. Without these four rows a cure could green every"
echo "row above and leave the builtin-generator half untouched with nothing here saying so."
printf "  %-20s %-30s %-12s %s\n" NAME BODY DEPTH PER-FRAME
row gen_in_once        "once(between(1,2,X))"
row gen_in_findall     "findall(X, between(1,2,X), _)"
row ctl_gen_cut        "between(1,2,X), !"
row ctl_50_facts       "findall(X, m(X), _)"
echo
echo "SAFETY CONTROL -- answers, not depths. A teardown that moves these is wrong whatever the table says."
cat > "$W/live.pl" <<'EOF'
:- initialization(main).
q(a). q(b).
p(0,[]).
p(N,[X|T]) :- N > 0, q(X), N1 is N - 1, p(N1,T).
o(0,[]).
o(N,[X|T]) :- N > 0, once(q(X)), N1 is N - 1, o(N1,T).
main :- findall(L, p(3,L), Ls), length(Ls,K), write(cp(K)), nl,
        findall(M, o(3,M), Ms), length(Ms,J), write(once(J)), nl.
EOF
LIVE="$(runq "$W/live.pl" | tr '\n' ' ')"
echo "  expected (swipl 2026-09-13):  cp(8) once(1)"
echo "  this tree:                    $LIVE"
case "$LIVE" in
    *"cp(8)"*"once(1)"*) echo "  ✅ the un-fenced choicepoints are LIVE and the fenced ones are not -- the distinction the cure must keep";;
    *) echo "  ⛔ SAFETY CONTROL MOVED -- a frame that a redo re-enters is being torn down, or the barrier is over-committing"; exit 1;;
esac
echo
echo "ORACLE, same three bodies at the same pinned ${PIN_KB} KB (swipl, 2026-09-13): q(_) ok · once(q(_)) ok ·"
echo "d(1,_) ok, all at 400000 -- swipl's choicepoints are compact records on a growable heap stack, ours are"
echo "machine-stack frames by design (ARCH-ENGINE, the three zetas), so the gap is the design's first real cost."
exit 0
