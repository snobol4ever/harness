#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_rtntype_is_set_by_an_asm_leaf.sh -- &RTNTYPE IS WRITTEN BY AN RTX LEAF AT EVERY FUNCTION RETURN (ceo 2026-09-25,
# CEO-1253). The define box called the C rt_kw_set_rtntype_role through the g_rtccb veneer, which called rt_kw_set_rtntype, which
# ran strlen + memcpy into g_kw_rtntype: 3% of the calculator's cycles for a 7-byte keyword. rt_kw_set_rtntype_role is an
# RTX_FUNC now (rtx_misc.s): role 2 stores FRETURN, else rt_g_ret_by_name selects NRETURN over RETURN, one 8-byte store of the
# little-endian word into g_kw_rtntype[16]; the C rt_kw_set_rtntype keeps the same word store for its other callers.
# TWO ARMS: (1) the witness's .s calls the leaf bare through the GOT (no g_rtccb write-back before it); (2) the witness -- a
# RETURN, an FRETURN, an NRETURN of a name, an NRETURN through a pattern-deferred call, and &RTNTYPE read after each --
# prints the oracle's lines in m3 and m4. EXIT 0 all arms; 1 a red (named); 2 REFUSED.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "REFUSED(2): $ROOT/scrip not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/rt.sno" <<'SNO'
        DEFINE('r()'); DEFINE('f()'); DEFINE('n()'); DEFINE('p()')  :(go)
r       r = 'rv'                        :(RETURN)
f       f = 'fv'                        :(FRETURN)
n       n = .nm                         :(NRETURN)
p       p = .pm                         :(NRETURN)
go      x = r(); OUTPUT = x ' ' &RTNTYPE
        x = f()                         :S(bad)F(okf)
bad     OUTPUT = 'f succeeded'
okf     OUTPUT = 'after f ' &RTNTYPE
        n() = 'stored-through-n'
        OUTPUT = nm ' ' &RTNTYPE
        'abc' LEN(1) . *p()
        OUTPUT = pm ' ' &RTNTYPE
        x = r(); OUTPUT = &RTNTYPE
END
SNO
"$SBL" $(sbl_lang_flags) "$W/rt.sno" < /dev/null > "$W/rt.ref" 2>&1 || true
[ -s "$W/rt.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
red=0
( cd "$W" && "$ROOT/scrip" --compile -o "$W/rt.s" rt.sno < /dev/null > /dev/null 2>&1 ) || { echo "RED: rt.sno did not compile"; exit 1; }
nc=$(grep -c 'call .*\[rip + rt_kw_set_rtntype_role@GOTPCREL\]' "$W/rt.s"); nv=$(grep -B3 'call .*\[rip + rt_kw_set_rtntype_role@GOTPCREL\]' "$W/rt.s" | grep -c 'g_rtccb')
[ "$nc" -gt 0 ] && [ "$nv" -eq 0 ] && echo "ok  rt_kw_set_rtntype_role: $nc bare GOT calls, no veneer" || { echo "RED: calls=$nc veneered=$nv"; red=1; }
( cd "$W" && timeout -k 5 20 "$ROOT/scrip" rt.sno < /dev/null > "$W/rt.m3" 2>&1 ); cmp -s "$W/rt.m3" "$W/rt.ref" && echo "ok  m3 = oracle" || { echo "RED m3 differs from the oracle:"; diff "$W/rt.ref" "$W/rt.m3" | head -8; red=1; }
if gcc "$W/rt.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/rt.bin" 2>/dev/null; then
    ( cd "$W" && timeout -k 5 20 "./rt.bin" < /dev/null > "$W/rt.m4" 2>&1 ); cmp -s "$W/rt.m4" "$W/rt.ref" && echo "ok  m4 = oracle" || { echo "RED m4 differs from the oracle:"; diff "$W/rt.ref" "$W/rt.m4" | head -8; red=1; }
else echo "RED: rt.s did not link"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: &RTNTYPE is written by the asm leaf and reads the oracle's values after RETURN, FRETURN and NRETURN in both modes"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
