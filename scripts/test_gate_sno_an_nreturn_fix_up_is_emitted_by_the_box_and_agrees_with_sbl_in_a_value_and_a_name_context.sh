#!/usr/bin/env bash
# test_gate_sno_an_nreturn_fix_up_is_emitted_by_the_box_and_agrees_with_sbl_in_a_value_and_a_name_context.sh
#
# THE ROW (ceo CEO-1488, ruled CEO-1574): the six frame helpers leave every SNOBOL4 graph; the last was rt_nret_fix_tiny, which every call to a non-Prolog callee
# consulted after the call (131 sites over 38 kernels). THE CURE: the consult keeps its four instructions (load rt_g_ret_by_name, test, branch) and the work behind
# it is emitted in the box -- wn = rt_g_want_name; with no want-name request the by-name mark is cleared and a NAME result is dereferenced through rt_deref, the call
# every deref box already makes; rt_g_want_name is consumed; rt_cap_name_strict is a compile-time knob (SCRIP_CAP_NAME_STRICT, read at emission) and no run-time call.
# ARMS: (A) the static census -- the compiled witness holds no `call rt_nret_fix_tiny`, `rt_nret_fix` or `rt_cap_name_strict` -- with a positive control (the
# witness has at least one rt_deref call, so the cold path is emitted); (B) both modes, a program whose NRETURN functions return a plain variable, an array element, a
# table element and a keyword, read as a value, assigned through as a name, nested as an argument and asked its DATATYPE, against sbl -bf cut at run time.
# FAIL-ONCE, MEASURED: arm A read 131 rt_nret_fix_tiny sites over the 38 benchmark kernels on 0b8e936c0 and reads 0 here.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- the expectations are cut from it at run time"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
RT="$B/out"; RC=0; n=0
ok()  { n=$((n + 1)); echo "  ok    $*"; }
red() { n=$((n + 1)); RC=1; echo "  RED   $*"; }
cat > "$D/n.sno" <<'SNO'
        DEFINE('F()')                           :(F.E)
F       F = .X                                  :(NRETURN)
F.E     DEFINE('G()')                           :(G.E)
G       G = .A[2]                               :(NRETURN)
G.E     DEFINE('H()')                           :(H.E)
H       H = .T['k']                             :(NRETURN)
H.E     DEFINE('K()')                           :(K.E)
K       K = .&MAXLNGTH                          :(NRETURN)
K.E     DEFINE('P(Z)')                          :(P.E)
P       P = Z                                   :(RETURN)
P.E     X = 'xv'
        A = ARRAY(3)
        A[2] = 'two'
        T = TABLE()
        T['k'] = 'tv'
        Y = F()
        OUTPUT = 'F value ' Y
        F() = 'new'
        OUTPUT = 'F assign ' X
        Y = G()
        OUTPUT = 'G value ' Y
        G() = 'z2'
        OUTPUT = 'G assign ' A[2]
        Y = H()
        OUTPUT = 'H value ' Y
        H() = 'tz'
        OUTPUT = 'H assign ' T['k']
        Y = K()
        OUTPUT = 'K value ' (Y GT 1000 'big')
        OUTPUT = 'nested ' P(F()) ' ' P(G())
        OUTPUT = DATATYPE(F()) ' ' DATATYPE(.F)
        OUTPUT = 'done ' &RTNTYPE
END
SNO
"$B/scrip" --compile -o "$D/n.s" "$D/n.sno" < /dev/null > /dev/null 2>&1 || refuse "the witness does not compile in mode 4"
h=$(grep -cE 'call[[:space:]]+(rt_nret_fix_tiny|rt_nret_fix|rt_cap_name_strict)\b' "$D/n.s"); d=$(grep -cE 'call[[:space:]]+rt_deref\b' "$D/n.s")
[ "$d" -ge 1 ] || refuse "the witness holds no rt_deref call -- the cold path is not emitted, arm A cannot see what it grades"
if [ "$h" = 0 ]; then ok "A census: 0 NRETURN helper call sites, $d rt_deref call site(s)"; else red "A census: $h call site(s) of rt_nret_fix_tiny / rt_nret_fix / rt_cap_name_strict remain"; fi
want="$(cd "$D" && timeout -k 5 60 "$SBL" -bf n.sno < /dev/null 2>&1)"
[ -n "$want" ] || refuse "the oracle printed nothing for the witness"
got3="$(cd "$D" && timeout -k 5 60 "$B/scrip" n.sno < /dev/null 2>&1)"
if [ "$got3" = "$want" ]; then ok "B m3: $(printf '%s' "$want" | tr '\n' '|' | cut -c1-80)"; else red "B m3: want [$(printf '%s' "$want" | tr '\n' '|' | cut -c1-120)] got [$(printf '%s' "$got3" | tr '\n' '|' | cut -c1-120)]"; fi
gcc -no-pie -o "$D/n.bin" "$D/n.s" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2> /dev/null || refuse "the mode-4 witness does not link"
got4="$(cd "$D" && timeout -k 5 60 ./n.bin < /dev/null 2>&1)"
if [ "$got4" = "$want" ]; then ok "B m4: same"; else red "B m4: want [$(printf '%s' "$want" | tr '\n' '|' | cut -c1-120)] got [$(printf '%s' "$got4" | tr '\n' '|' | cut -c1-120)]"; fi
[ "$RC" -eq 0 ] && echo "GREEN: $n arms" || echo "RED: the NRETURN fix-up is still a C helper call, or a by-name result differs from sbl"
exit "$RC"
