#!/usr/bin/env bash
# test_gate_sno_an_assignment_whose_value_is_a_match_assigns_and_returns_the_matched_substring.sh
#
# THE DEFECT (the ceo's rank-1 row snobol4-an-assignment-whose-value-is-a-match-aborts-scrip, CEO-1449; 14 of 16 long runs of
# the a..z millions-run died of it): OUTPUT = (k = 'x' ? 'x') aborted SCRIP (libscrip_rt: BOMB with a garbage message, SIGABRT)
# where sbl -bf assigns k the matched substring and returns it; the same in EVAL, inside a concatenation, under SIZE.
# THE CAUSE (src/lower/lower_snobol4.c sx_lower TT_ASSIGN): an assignment V = (S ? P) lowers to a match whose pattern captures
# into V conditionally (S ? (P . V)), which yields no value node -- it answered *res = NULL even when its caller asked for the
# assignment's value, so the consumer (another assignment, a concatenation, a call) read a value nothing produced.
# THE CURE: the capture-into-V form is taken only when no value is wanted; in value context the match's value goes through the
# value-producing match (a capture into a scratch variable read back) into an ordinary IR_ASSIGN, whose node is the value.
#
# One program, every answer cut from sbl -bf at run time and pinned: a pinned line sbl no longer prints is a REFUSAL, never a
# green. Both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent -- the pinned lines cannot be confirmed"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.sno" <<'SNO'
        OUTPUT = (k = 'x' ? 'x')
        OUTPUT = 'k=' k
        OUTPUT = (e = 'abc' ? 'b')
        OUTPUT = 'e=' e
        OUTPUT = '[' (j = '' ? ARBNO('a')) ']'
        X = (m = 'x' ? 'x')
        OUTPUT = 'm=' m ' X=' X
        OUTPUT = 'a' (n = 'xy' ? 'y') 'b'
        OUTPUT = 'n=' n
        p = 'old'
        OUTPUT = (p = 'abc' ? 'z')
        OUTPUT = 'p=' p
        q = ('xy' ? 'y')
        OUTPUT = 'q=' q
        OUTPUT = EVAL("(r = 'x' ? 'x')")
        OUTPUT = 'r=' r
        OUTPUT = EVAL("(s = 'abc' ? 'b')") s
        OUTPUT = SIZE(t = 'abcd' ? LEN(3)) t
END
SNO
printf 'x\nk=x\nb\ne=b\n[]\nm=x X=x\nayb\nn=y\np=old\nq=y\nx\nr=x\nbb\n3abc\n' > "$D/w.want"
( cd "$D" && timeout -k 5 10 "$SBL" -bf w.sno < /dev/null > w.sbl 2>/dev/null )
cmp -s "$D/w.want" "$D/w.sbl" || refuse "sbl -bf does not answer the witness as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/w.sbl")]"
red=0; n=0
( cd "$D" && timeout -k 5 30 "$B/scrip" w.sno < /dev/null > w.m3 2>/dev/null )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile w.sno < /dev/null > w.s 2>/dev/null && gcc -no-pie w.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o w.bin 2>/dev/null && timeout -k 5 30 ./w.bin < /dev/null > w.m4 2>/dev/null )
for m in m3 m4; do
    n=$((n + 1))
    if [ -f "$D/w.$m" ] && cmp -s "$D/w.want" "$D/w.$m"; then echo "  ok   $m"; else echo "  FAIL $m: got [$(tr '\n' '|' 2>/dev/null < "$D/w.$m")] want [$(tr '\n' '|' < "$D/w.want")]"; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): an assignment whose value is a match assigns and returns the matched substring, statement level, nested, failing and in EVAL, as sbl -bf answers; $n arm(s)"; exit 0; fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
