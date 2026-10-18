#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_the_bid_entry_calls_the_builtin_body_through_the_direct_table.sh -- A LEAF BUILTIN CALL WITH A BAKED BID REACHES
# ITS BODY THROUGH ONE TABLE LOAD (ceo 2026-09-25, CEO-1255). rt_call_bid_sn4 is an RTX_FUNC (rtx_misc.s): with no error
# pending, no &ERRLIMIT, a leaf bid and no DATA instance as the single argument, it loads g_bn_direct[bid] (by_name_dispatch.c:
# a const table of the fourteen separately compiled bodies -- SIZE SUBSTR REPLACE TRIM DUPL LPAD RPAD REVERSE INTEGER REMDR DATE
# TIME IDENT DIFFER -- with their op word) and calls the body with the staged args and an out cell; a 1 return hands the cell back,
# anything else and every other case takes the C body c_rt_call_bid_sn4 (the name-keyed dispatcher). json spent 6.9% of its
# cycles in try_call_builtin_by_name_bl_s and porter 5%: the DATA-instance scan, the display test, strlen, the dtax cache and the
# length/first-char switch ran before every SIZE or SUBSTR.
# THREE ARMS: (1) the witness's .s calls rt_call_bid_sn4 bare through the GOT (no rtccb write-back before it); (2) the witness --
# every table body with in-range, out-of-range, empty, numeric and null arguments, the predicates through assignment, a 20,000-
# iteration loop over SIZE / DUPL / REMDR / SUBSTR -- prints the oracle's lines in m3 and m4; (3) the C body stays reachable: the
# same builtins after &ERRLIMIT is set (the entry hands every call to the C body then) print the same answers, and a DATA field
# named like no builtin still reads through the field entry. ⛔ A builtin ARGUMENT ERROR under &ERRLIMIT is left out on purpose:
# SPITBOL sets &ERRTYPE 167 / 193 where SCRIP's builtins fail the statement silently on both arms -- the row
# snobol4-builtin-argument-errors-are-silent-where-spitbol-raises-them-under-errlimit. EXIT 0 all arms; 1 a red (named); 2 REFUSED.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "REFUSED(2): $ROOT/scrip not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/bid.sno" <<'SNO'
        s = 'The Quick Brown Fox'
        OUTPUT = SIZE(s) ' ' SIZE('') ' ' SIZE(12345) ' ' SUBSTR(s, 5, 5) '|' SUBSTR(s, 17) '|' REPLACE(s, 'oq', 'OQ') '|' TRIM('ab   ') '|' DUPL('ab', 3) '|' LPAD('7', 4, '0') '|' RPAD('x', 3) '|' REVERSE('abc') '|' INTEGER('42') ' ' REMDR(17, 5)
        a = 'n'; a = IDENT(s, s) 'y'
        b = 'n'; b = DIFFER(s, 'x') 'y'
        c = 'n'; c = INTEGER('x') 'y'
        d = 'n'; d = INTEGER(2.5) 'y'
        e = 'n'; e = IDENT() 'y'
        f = 'n'; f = DIFFER(u, v) 'y'
        OUTPUT = a b c d e f ' ' SIZE(SUBSTR(s, 1, 100)) ' ' (SUBSTR(s, 100, 1) 'ok' | 'fail') ' ' DUPL('-', 0) '|' REVERSE('') '|' TRIM('') '|' LPAD('abc', 2) '|' REMDR(-7, 3) ' ' REMDR(7, -3)
        DATA('rec(width,other)')
        r = rec(77, 'o')
        OUTPUT = width(r) ' ' other(r) ' ' SIZE(other(r))
        n = 0; t = 0
loop    n = LT(n, 20000) n + 1                  :F(done)
        t = t + SIZE(DUPL('a', REMDR(n, 7))) + REMDR(SIZE(SUBSTR(s, REMDR(n, 10) + 1)), 4)   :(loop)
done    OUTPUT = t
        &ERRLIMIT = 5
        OUTPUT = SIZE(s) ' ' SUBSTR(s, 5, 5) ' ' REPLACE('abc', 'b', 'B') ' ' DUPL('xy', 2) ' ' REVERSE('abc') ' ' REMDR(9, 4) ' ' TRIM('q  ') '|'
END
SNO
"$SBL" $(sbl_lang_flags) "$W/bid.sno" < /dev/null > "$W/bid.ref" 2>&1 || true
[ -s "$W/bid.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
grep -q 'ERROR' "$W/bid.ref" && { echo "REFUSED(2): the oracle rejected the witness:"; grep 'ERROR' "$W/bid.ref" | head -2; exit 2; }
red=0
( cd "$W" && "$ROOT/scrip" --compile -o "$W/bid.s" bid.sno < /dev/null > /dev/null 2>&1 ) || { echo "RED: bid.sno did not compile"; exit 1; }
nc=$(grep -c 'call .*\[rip + rt_call_bid_sn4@GOTPCREL\]' "$W/bid.s"); nv=$(grep -B3 'call .*\[rip + rt_call_bid_sn4@GOTPCREL\]' "$W/bid.s" | grep -c 'rtccb')
[ "$nc" -ge 20 ] && [ "$nv" -eq 0 ] && echo "ok  rt_call_bid_sn4: $nc bare GOT calls, no veneer" || { echo "RED: calls=$nc (want >= 20) veneered=$nv"; red=1; }
( cd "$W" && timeout -k 5 60 "$ROOT/scrip" bid.sno < /dev/null > "$W/bid.m3" 2>&1 ); cmp -s "$W/bid.m3" "$W/bid.ref" && echo "ok  m3 = oracle" || { echo "RED m3 differs from the oracle:"; diff "$W/bid.ref" "$W/bid.m3" | head -8; red=1; }
if gcc "$W/bid.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/bid.bin" 2>/dev/null; then
    ( cd "$W" && timeout -k 5 60 "./bid.bin" < /dev/null > "$W/bid.m4" 2>&1 ); cmp -s "$W/bid.m4" "$W/bid.ref" && echo "ok  m4 = oracle" || { echo "RED m4 differs from the oracle:"; diff "$W/bid.ref" "$W/bid.m4" | head -8; red=1; }
else echo "RED: bid.s did not link"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: leaf builtin calls reach their bodies through the direct table, the C body answers the errors and the field access, and the witness matches the oracle in both modes"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
