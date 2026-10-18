#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_ident_and_the_fused_table_store_take_the_asm_entries.sh -- IDENT / DIFFER AND THE FUSED SUBSCRIPTED STORE CALL
# RTX ENTRIES (ceo 2026-09-25, CEO-1252). descr_identical is an RTX_FUNC in rtx_misc.s: FAIL on either side is 0; the null test
# (DT_SNUL, a null pointer, a stamped length of 0, an unstamped empty string) answers both-null = 1 and one-null = 0 without a
# call; two integers compare their words; two stamped strings compare lengths then bytes; everything else (unstamped strings,
# reals, names, tables, records, csets, procedure values) is the C body c_descr_identical through RTX_CTAIL_SAVED.
# rt_table_assign_fast is an RTX_FUNC in rtx_table.s: a TABLE store whose key already exists finds the pair through
# table_find_pair_d and rewrites its value and key descriptor in place (clearing the string-extension frontier when the value is
# the frontier's owner); a miss, an array, a pending collection, an element trace or a trace budget goes to the C body
# c_rt_table_assign_fast. claws5 spent 4.6% of its cycles in the IDENT box + 6.7% in descr_identical + 5.8% in table_set_descr_d,
# each through a veneered C call; the entries are bare through the GOT now and the rtcc-four walker proves them.
# THREE ARMS: (1) the witness's .s calls both entries bare (no rtccb write-back in the three lines before the call); (2) the
# witness -- IDENT/DIFFER over equal and unequal strings, a null against '' and against a null-valued variable, integers, an
# integer against its string spelling, reals, names, the same table, two tables, a stamped string against SUBSTR of it, and
# the fused store over existing keys (integer and string values, a NAME value), new keys, a 5000-key growth loop and a
# counting loop -- prints the oracle's lines in m3 and m4; (3) the C bodies stay reachable: a table store under a live element
# trace still goes through (the value read back is the oracle's). EXIT 0 all arms; 1 a red (named); 2 REFUSED.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "REFUSED(2): $ROOT/scrip not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/id.sno" <<'SNO'
        a = 'abc'; b = 'abc'; c = 'abd'; d = 'abcd'; e = ''; n1 = 3; n2 = 3; n3 = 4; s3 = '3'; r1 = 1.5; r2 = 1.5
        OUTPUT = (IDENT(a, b) 'y' | 'n') (IDENT(a, c) 'y' | 'n') (IDENT(a, d) 'y' | 'n') (IDENT(e) 'y' | 'n') (IDENT(e, u) 'y' | 'n') (IDENT(a) 'y' | 'n')
        OUTPUT = (IDENT(n1, n2) 'y' | 'n') (IDENT(n1, n3) 'y' | 'n') (IDENT(n1, s3) 'y' | 'n') (IDENT(r1, r2) 'y' | 'n') (IDENT(r1, n1) 'y' | 'n') (DIFFER(a, c) 'y' | 'n') (DIFFER(a, b) 'y' | 'n')
        OUTPUT = (IDENT(.a, .a) 'y' | 'n') (IDENT(.a, .b) 'y' | 'n') (IDENT(SUBSTR(d, 1, 3), a) 'y' | 'n') (IDENT(a, SUBSTR(d, 2, 3)) 'y' | 'n') (DIFFER(u) 'y' | 'n') (DIFFER(s3) 'y' | 'n')
        T = TABLE(); T2 = TABLE()
        OUTPUT = (IDENT(T, T) 'y' | 'n') (IDENT(T, T2) 'y' | 'n') (IDENT(T['zz']) 'y' | 'n') (IDENT(a a, 'abcabc') 'y' | 'n')
        T['k'] = 1; T['k'] = T['k'] + 1; T['k'] = T['k'] + 1; T['s'] = 'v1'; T['s'] = 'v2'; T['s'] = T['s'] 'x'
        T['nm'] = .a; T['nm'] = .c
        OUTPUT = T['k'] ' ' T['s'] ' ' DATATYPE(T['nm']) ' ' $T['nm'] ' ' (IDENT(T['k'], 3) 'y' | 'n')
        i = 0
grow    i = LT(i, 5000) i + 1                           :F(gdone)
        T['key' i] = i                                  :(grow)
gdone   i = 0; sum = 0
cnt     i = LT(i, 5000) i + 1                           :F(cdone)
        T['key' i] = T['key' i] + 1
        sum = sum + T['key' i]                          :(cnt)
cdone   OUTPUT = sum ' ' T['key1'] ' ' T['key5000'] ' ' T['k']
        W = TABLE(); w = 'the quick brown fox'
loop    w BREAK(' ') . wd ' ' = 
+                                                       :F(last)
        W[wd] = W[wd] + 1                               :(loop)
last    W[w] = W[w] + 1
        OUTPUT = W['the'] ' ' W['quick'] ' ' W['fox'] ' ' W['none']
END
SNO
"$SBL" $(sbl_lang_flags) "$W/id.sno" < /dev/null > "$W/id.ref" 2>&1 || true
[ -s "$W/id.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
red=0
( cd "$W" && "$ROOT/scrip" --compile -o "$W/id.s" id.sno < /dev/null > /dev/null 2>&1 ) || { echo "RED: id.sno did not compile"; exit 1; }
for f in descr_identical rt_table_assign_fast; do
    nc=$(grep -c "call .*\[rip + $f@GOTPCREL\]" "$W/id.s"); nv=$(grep -B3 "call .*\[rip + $f@GOTPCREL\]" "$W/id.s" | grep -c 'rtccb')
    [ "$nc" -gt 0 ] && [ "$nv" -eq 0 ] && echo "ok  $f: $nc bare GOT calls, no veneer" || { echo "RED $f: calls=$nc veneered=$nv"; red=1; }
done
( cd "$W" && timeout -k 5 60 "$ROOT/scrip" id.sno < /dev/null > "$W/id.m3" 2>&1 ); cmp -s "$W/id.m3" "$W/id.ref" && echo "ok  m3 = oracle" || { echo "RED m3 differs from the oracle:"; diff "$W/id.ref" "$W/id.m3" | head -8; red=1; }
if gcc "$W/id.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/id.bin" 2>/dev/null; then
    ( cd "$W" && timeout -k 5 60 "./id.bin" < /dev/null > "$W/id.m4" 2>&1 ); cmp -s "$W/id.m4" "$W/id.ref" && echo "ok  m4 = oracle" || { echo "RED m4 differs from the oracle:"; diff "$W/id.ref" "$W/id.m4" | head -8; red=1; }
else echo "RED: id.s did not link"; red=1; fi
cat > "$W/tr.sno" <<'SNO'
        T = TABLE()
        T['a'] = 1
        &TRACE = 10
        TRACE('T', 'VALUE')
        T['a'] = T['a'] + 5
        OUTPUT = 'after ' T['a']
END
SNO
"$SBL" $(sbl_lang_flags) "$W/tr.sno" < /dev/null > "$W/tr.ref" 2>&1 || true
( cd "$W" && timeout -k 5 20 "$ROOT/scrip" tr.sno < /dev/null > "$W/tr.m3" 2>&1 ); grep -q '^after 6$' "$W/tr.m3" && echo "ok  a store under a live trace reaches the C body and keeps the value (m3)" || { echo "RED: the traced store lost its value in m3:"; cat "$W/tr.m3" | head -4; red=1; }
[ "$red" -eq 0 ] && { echo "GATE OK: IDENT/DIFFER and the fused table store take the asm entries bare, and every witness line matches the oracle in both modes"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
