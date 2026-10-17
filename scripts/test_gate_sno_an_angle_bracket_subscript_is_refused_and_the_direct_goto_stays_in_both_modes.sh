#!/usr/bin/env bash
# test_gate_sno_an_angle_bracket_subscript_is_refused_and_the_direct_goto_stays_in_both_modes.sh
#
# THE RULING (Lon 2026-10-02, in-chat to the ceo, CEO-1447, RULES.md FACT RULE -- SQUARE BRACKETS ARE THE ONE SUBSCRIPT): "remove SCRIP's support for these [< and >] as array indices. We do NOT [want]
# TWO ways to do the same thing. We might NEED the angle brackets to implement LAMBDA code syntax." SCRIP's SNOBOL4 grammar no longer has the A<I> subscript: a program that spells one is a compile error
# (main compile, both modes), EVAL and CODE of text that spells one raise a trappable error (222, the left-bracket syntax error); A[I] and the DIRECT GOTO :<C> :S<C> :F<C> (the goto field's angle
# brackets, which are not subscripts) keep working. sbl -bf still accepts A<I>: that divergence is the ruling's, not a defect, so this gate cuts nothing from the oracle for the refusal arms and
# cuts the accepted forms' answers from sbl -bf at run time. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent -- the accepted forms' answers cannot be cut"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/ok.sno" <<'SNO'
        A = ARRAY(3)
        A[1] = 'one'
        T = TABLE()
        T['k'] = 'v'
        OUTPUT = A[1] ' ' T['k']
        C1 = CODE(" OUTPUT = 'S direct' :(N1)")
        C2 = CODE(" OUTPUT = 'F direct' :(N2)")
        C3 = CODE(" OUTPUT = 'plain direct' :(END)")
        EQ(1, 1)                        :S<C1>
        OUTPUT = 'S not taken'
N1      EQ(1, 2)                        :F<C2>
        OUTPUT = 'F not taken'
N2      :<C3>
END
SNO
cat > "$D/bad1.sno" <<'SNO'
        A = ARRAY(2)
        A<1> = 5
        OUTPUT = A<1>
END
SNO
cat > "$D/bad2.sno" <<'SNO'
        T = TABLE()
        T['k'] = 'v'
        OUTPUT = T<'k'>
END
SNO
cat > "$D/bad3.sno" <<'SNO'
        A = ARRAY('2,2')
        OUTPUT = 'before'
        X = A<1,1>
END
SNO
cat > "$D/ev.sno" <<'SNO'
        &ERRLIMIT = 10
        A = ARRAY(2)
        A[1] = 5
        SETEXIT('E1')
        OUTPUT = EVAL('A<1>')           :S(E2)
        OUTPUT = 'eval failed'          :(E2)
E1      OUTPUT = 'eval refused ' &ERRTYPE
E2      SETEXIT('E3')
        C = CODE(' OUTPUT = A<1>')      :S(E4)
        OUTPUT = 'code failed'          :(E4)
E3      OUTPUT = 'code refused ' &ERRTYPE
E4      OUTPUT = EVAL('A[1]')
END
SNO
( cd "$D" && timeout -k 5 10 "$SBL" -bf ok.sno < /dev/null 2>/dev/null > ok.want )
[ -s "$D/ok.want" ] || refuse "sbl -bf gave no answer for the accepted forms"
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc -no-pie "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
( cd "$D" && timeout -k 5 20 "$B/scrip" ok.sno < /dev/null > ok.m3 2>&1 )
( cd "$D" && m4bin ok && timeout -k 5 20 ./ok.bin < /dev/null > ok.m4 2>&1 )
for m in m3 m4; do
    if cmp -s "$D/ok.want" "$D/ok.$m"; then arm "accepted forms $m (square subscripts, :S<L> :F<L> :<C>) equal sbl -bf" ok
    else arm "accepted forms $m" "got [$(tr '\n' '|' < "$D/ok.$m")] want [$(tr '\n' '|' < "$D/ok.want")]"; fi
done
for p in bad1 bad2 bad3; do
    o="$( cd "$D" && timeout -k 5 20 "$B/scrip" "$p.sno" < /dev/null 2>&1 )"; rc=$?
    if [ $rc -ne 0 ] && ! printf '%s' "$o" | grep -qE '^(5|v|before)$'; then arm "$p m3 refused at compile (rc $rc)" ok
    else arm "$p m3" "an angle subscript ran (rc $rc): [$(printf '%s' "$o" | head -2 | tr '\n' '|')]"; fi
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile "$p.sno" < /dev/null > "$p.s" 2>/dev/null ); crc=$?
    if [ $crc -ne 0 ]; then arm "$p m4 refused at compile (rc $crc)" ok
    else arm "$p m4" "an angle subscript compiled"; fi
done
( cd "$D" && timeout -k 5 20 "$B/scrip" ev.sno < /dev/null > ev.m3 2>&1 )
( cd "$D" && m4bin ev && timeout -k 5 20 ./ev.bin < /dev/null > ev.m4 2>&1 )
for m in m3 m4; do
    if [ "$(tr '\n' '|' < "$D/ev.$m")" = "eval refused 222|code refused 222|5|" ]; then arm "EVAL and CODE $m raise the trappable left-bracket error 222" ok
    else arm "EVAL/CODE $m" "got [$(tr '\n' '|' < "$D/ev.$m")]"; fi
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): an angle-bracket subscript is a compile error in both modes and a trappable error in EVAL and CODE; the direct goto and the square subscript stand; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
