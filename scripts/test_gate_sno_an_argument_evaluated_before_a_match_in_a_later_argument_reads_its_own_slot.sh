#!/usr/bin/env bash
# test_gate_sno_an_argument_evaluated_before_a_match_in_a_later_argument_reads_its_own_slot.sh
#
# THE DEFECT (row snobol4-an-argument-evaluated-before-a-match-in-a-later-argument-is-read-from-the-wrong-stack-slot; the
# ceo's CEO-1461 seed-1205 GP fault, hq_icon's FINDING-2026-10-03-hq_icon-eval-chain-reads-an-unwritten-stack-slot-as-an-
# alternation-operand, reduced by the cfo): an argument evaluated BEFORE a pattern match that sits in a later argument of the
# same call was read from the wrong stack slot, both modes and inside EVAL -- P = 'k' | ('xyz' ? 'y') lost its left operand,
# DUPL('ab', SIZE('xyz' ? 'y')) and REPLACE('abc', ('xyz' ? 'y'), 'Y') read garbage; stale bytes that were pointer-shaped
# under a zero tag faulted in strlen under rcp_of.
# THE CAUSE (src/emitter/emit.cpp, the zd operand read loop over g_zd_read): the read offset of an operand adds the match
# frame (64 + emit_match_begin_frame_extra) for every IR_MATCH_BEGIN between producer and consumer, as though the consumer
# stood inside that match -- but when the match's IR_MATCH_END lies between them too, the frame is already whacked
# (mov rsp, rbp; pop rbp), so the read landed a whole match frame too high. THE CURE: walking back from the consumer, an
# IR_MATCH_END opens a closed region and nothing inside it, its IR_MATCH_BEGIN included, adds height.
#
# Two programs, every answer cut from sbl -bf at run time and pinned: a pinned line sbl no longer prints is a REFUSAL, never a
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
        P = 'k' | ('xyz' ? 'y')
        'zzk' ? P . V
        OUTPUT = 'alt right ' V
        Q = ('xyz' ? 'y') | 'k'
        'zzk' ? Q . W
        OUTPUT = 'alt left ' W
        OUTPUT = 'dupl ' DUPL('ab', SIZE('xyz' ? 'y'))
        OUTPUT = 'concat ' 'k' ('xyz' ? 'y')
        OUTPUT = 'replace ' REPLACE('abc', ('xyz' ? 'y'), 'Y')
        OUTPUT = 'arith ' (1 + SIZE('xyz' ? 'xy'))
        OUTPUT = 'two ' DUPL('ab', SIZE('xyz' ? 'y') + SIZE('pq' ? 'q'))
        R = 'k' | ('xyz' ? 'y') | 'm'
        'zzm' ? R . U
        OUTPUT = 'alt3 ' U
        OUTPUT = 'lpad ' LPAD('ab', SIZE('xyz' ? ('x' | 'y')) + 3, '*')
END
SNO
printf 'alt right k\nalt left k\ndupl ab\nconcat ky\nreplace abc\narith 3\ntwo abab\nalt3 m\nlpad **ab\n' > "$D/w.want"
cat > "$D/e.sno" <<'SNO'
        &TRIM = 1
L       LINE = INPUT                                     :F(END)
        &ERRLIMIT = 1000
        SETEXIT('H')
        R = EVAL(LINE)                                   :S(OK)
        OUTPUT = 'FAIL'                                  :(L)
OK      OUTPUT = IDENT(DATATYPE(R), 'STRING') 'STRING ' R :S(L)
        OUTPUT = DATATYPE(R)                             :(L)
H       OUTPUT = 'ERROR ' &ERRTYPE                       :(L)
END
SNO
cat > "$D/e.in" <<'TXT'
DUPL('ab', SIZE('xyz' ? 'y'))
REPLACE('abc', ('xyz' ? 'y'), 'Y')
'zzk' ? ('k' | ('xyz' ? 'y'))
LPAD('ab', SIZE('xyz' ? ('x' | 'y')) + 3, '*')
"b" ? LEN(1)^ LEN(2)
FENCE
'(matched [things])' ?&STLIMIT | (']' ? *']')
TXT
printf 'STRING ab\nSTRING abc\nSTRING k\nSTRING **ab\nERROR 233\nPATTERN\nPATTERN\n' > "$D/e.want"
( cd "$D" && timeout -k 5 10 "$SBL" -bf w.sno < /dev/null > w.sbl 2>/dev/null )
cmp -s "$D/w.want" "$D/w.sbl" || refuse "sbl -bf does not answer w as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/w.sbl")]"
( cd "$D" && timeout -k 5 10 "$SBL" -bf e.sno < e.in > e.sbl 2>/dev/null )
cmp -s "$D/e.want" "$D/e.sbl" || refuse "sbl -bf does not answer e as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/e.sbl")]"
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc -no-pie "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
( cd "$D" && timeout -k 5 30 "$B/scrip" w.sno < /dev/null > w.m3 2>/dev/null )
( cd "$D" && m4bin w && timeout -k 5 30 ./w.bin < /dev/null > w.m4 2>/dev/null )
( cd "$D" && timeout -k 5 30 "$B/scrip" e.sno < e.in > e.m3 2>/dev/null )
( cd "$D" && m4bin e && timeout -k 5 30 ./e.bin < e.in > e.m4 2>/dev/null )
red=0; n=0
for p in w e; do for m in m3 m4; do
    n=$((n + 1))
    if [ -f "$D/$p.$m" ] && cmp -s "$D/$p.want" "$D/$p.$m"; then echo "  ok   $p $m"
    else echo "  FAIL $p $m: got [$(tr '\n' '|' 2>/dev/null < "$D/$p.$m")] want [$(tr '\n' '|' < "$D/$p.want")]"; red=$((red + 1)); fi
done; done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): an argument evaluated before a match in a later argument reads its own slot -- alternation, DUPL, REPLACE, LPAD, direct and under EVAL, both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
