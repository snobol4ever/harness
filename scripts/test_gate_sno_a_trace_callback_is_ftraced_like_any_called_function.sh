#!/usr/bin/env bash
# test_gate_sno_a_trace_callback_is_ftraced_like_any_called_function.sh
#
# THE DEFECT (row snobol4-ftrace-prints-no-banner-for-a-trace-callbacks-own-call-and-return): with &FTRACE set, sbl prints the TRACE callback function's own call and
# return banners (CB(.X,'tg') ... RETURN CB = '') for every TRACE kind, and a CALL or RETURN trace on a function FTRACED prints the callback BEFORE the function's own banner.
# SCRIP zeroed &FTRACE around the callback (core.c, three sites), returned before the callback for a CALL or RETURN event while &FTRACE ran (the callback never fired), kept the
# recursion guard in front of the banner, and ran a CALL/RETURN callback one &FNCLEVEL too deep (its banner carried an 'i', &FNCLEVEL read 2 where sbl reads 1).
# THE CURE: the callback leaves &FTRACE alone and the recursion guard lets the banner through; a CALL/RETURN event runs the callback first and prints the function's banner after
# (the emitted road defers it to rt_trace_pend_close); the callback runs at the call site's level (rt_k_level and kw_fnclevel lowered by one, restored at the close).
# NOT HERE: the statement number of the function's own RETURN banner after a RETURN-kind callback (sbl prints the caller's statement), a separate row.
# Every expected output is cut from sbl -bf and pinned: a program sbl no longer answers as pinned is a REFUSAL, never a green. Both modes, SCRIP_SNO_STMTKW=1 at compile and run.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent -- the pinned lines cannot be confirmed"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
export SCRIP_SNO_STMTKW=1
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/value.sno" <<'SNO'
        &TRACE = 100
        &FTRACE = 100000
        DEFINE('CB(NAME,TAG)')  :(S)
CB      OUTPUT = 'cb ' NAME ' ' TAG  :(RETURN)
S       TRACE('X', 'VALUE', 'tg', .CB)
        X = 5
        OUTPUT = 'done'
END
SNO
cat > "$D/value.want" <<'TXT'
****6*******  CB(.X,'tg')
cb X tg
****4*******  RETURN CB = ''
done
TXT
cat > "$D/label.sno" <<'SNO'
        &TRACE = 100
        &FTRACE = 100000
        DEFINE('CB(NAME,TAG)')  :(S)
CB      OUTPUT = 'cb ' NAME ' ' TAG  :(RETURN)
S       TRACE('L', 'LABEL', 'tg', .CB)
        :(L)
L       OUTPUT = 'done'
END
SNO
cat > "$D/label.want" <<'TXT'
****6*******  CB(.L,'tg')
cb L tg
****4*******  RETURN CB = ''
done
TXT
cat > "$D/call.sno" <<'SNO'
        &TRACE = 100
        &FTRACE = 100000
        DEFINE('CB(NAME,TAG)')  :(S)
CB      OUTPUT = 'cb ' NAME ' ' TAG  :(RETURN)
S       DEFINE('F(A)')  :(S2)
F       F = A  :(RETURN)
S2      TRACE('F', 'CALL', 'tg', .CB)
        X = F(1)
        OUTPUT = 'done'
END
SNO
cat > "$D/call.want" <<'TXT'
****8*******  CB(.F,'tg')
cb F tg
****4*******  RETURN CB = ''
****8*******  F(1)
****6*******  RETURN F = 1
done
TXT
cat > "$D/stcount.sno" <<'SNO'
        &TRACE = 100
        &FTRACE = 100000
        DEFINE('CB(NAME,TAG)')  :(S)
CB      OUTPUT = 'cb ' NAME ' ' TAG  :(RETURN)
S       TRACE('STCOUNT', 'KEYWORD', 'tg', .CB)
        X = 1
        OUTPUT = 'done'
END
SNO
cat > "$D/stcount.want" <<'TXT'
****6*******  CB(.STCOUNT,'tg')
cb STCOUNT tg
****4*******  RETURN CB = ''
****7*******  CB(.STCOUNT,'tg')
cb STCOUNT tg
****4*******  RETURN CB = ''
done
****8*******  CB(.STCOUNT,'tg')
cb STCOUNT tg
****4*******  RETURN CB = ''
TXT
cat > "$D/access.sno" <<'SNO'
        &TRACE = 100
        &FTRACE = 100000
        DEFINE('CB(NAME,TAG)')  :(S)
CB      OUTPUT = 'cb ' NAME ' ' TAG  :(RETURN)
S       TRACE('X', 'ACCESS', 'tg', .CB)
        X = 5
        OUTPUT = X
END
SNO
cat > "$D/access.want" <<'TXT'
****7*******  CB(.X,'tg')
cb X tg
****4*******  RETURN CB = ''
5
TXT
cat > "$D/level_call.sno" <<'SNO'
        &TRACE = 100
        DEFINE('CB(NAME,TAG)')  :(S)
CB      OUTPUT = 'cb ' NAME ' lvl=' &FNCLEVEL  :(RETURN)
S       DEFINE('F(A)')  :(S2)
F       OUTPUT = 'in F lvl=' &FNCLEVEL
        F = A  :(RETURN)
S2      TRACE('F', 'CALL', 'tg', .CB)
        X = F(1)
        OUTPUT = 'done lvl=' &FNCLEVEL
END
SNO
cat > "$D/level_call.want" <<'TXT'
cb F lvl=1
in F lvl=1
done lvl=0
TXT
cat > "$D/level_return.sno" <<'SNO'
        &TRACE = 100
        DEFINE('CB(NAME,TAG)')  :(S)
CB      OUTPUT = 'cb ' NAME ' lvl=' &FNCLEVEL  :(RETURN)
S       DEFINE('F(A)')  :(S2)
F       OUTPUT = 'in F lvl=' &FNCLEVEL
        F = A  :(RETURN)
S2      TRACE('F', 'RETURN', 'tg', .CB)
        X = F(1)
        OUTPUT = 'done lvl=' &FNCLEVEL
END
SNO
cat > "$D/level_return.want" <<'TXT'
in F lvl=1
cb F lvl=1
done lvl=0
TXT
names="value label call stcount access level_call level_return"
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
for p in $names; do
    ( cd "$D" && timeout -k 5 10 "$SBL" -bf $p.sno < /dev/null 2>/dev/null > $p.sbl )
    cmp -s "$D/$p.want" "$D/$p.sbl" || refuse "sbl -bf does not answer $p as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/$p.sbl")]"
done
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
for p in $names; do
    ( cd "$D" && timeout -k 5 30 "$B/scrip" $p.sno < /dev/null > $p.m3 2>/dev/null )
    ( cd "$D" && m4bin $p && timeout -k 5 30 ./$p.bin < /dev/null > $p.m4 2>/dev/null )
    for m in m3 m4; do
        if [ -f "$D/$p.$m" ] && cmp -s "$D/$p.want" "$D/$p.$m"; then arm "$p $m" ok
        else arm "$p $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/$p.$m")] want [$(tr '\n' '|' < "$D/$p.want")]"; fi
    done
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): &FTRACE banners a TRACE callback's own call and return for VALUE, LABEL, CALL, KEYWORD and ACCESS, the callback of a CALL or RETURN event runs at the call site's level -- both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
