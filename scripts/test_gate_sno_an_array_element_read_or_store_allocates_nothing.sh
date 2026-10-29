#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_an_array_element_read_or_store_allocates_nothing.sh -- A ONE-INDEX SUBSCRIPT IN VALUE CONTEXT (x = A[i], A[i] + 1,
# A[i] as a pattern subject) is lowered with the marker "container-value" and emitted as rt_subscript_val, which returns an array
# element by value without minting the 80-byte name-trap cell rt_subscript_var makes; a store A[i] = v goes through the fused
# subscripted-assignment arm without one either. (ceo 2026-09-24, CEO-1249: array_sum minted 4 M cells for 200 K element accesses
# and collected 9,698 times at the shipped arena; the reads alone were 10.1 G -> 6.1 G Ir.) SCRIP_SUB_VAL=0 is the control arm
# (every such site calls rt_subscript_var_container_only again).
# THREE ARMS: (1) the witness's .s carries rt_subscript_val sites under the cure and none under the control arm; (2) the witness
# -- reads and stores through integer, string-integer, negative, zero and out-of-range indices, a two-dimensional array, a table
# through the same syntax, an array of arrays, the element as a pattern subject, the name form .A[i], PROTOTYPE and COPY after
# stores -- prints the oracle's lines in m3 and m4 under both arms; (3) a 20,000-element read/store loop runs at the shipped
# arena with ZERO collections under the cure (SCRIP_ZETA_TELEM counts them; the control arm collects), so the allocation is gone,
# not merely cheaper. EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle or binary missing).
# ⛔ A NAME VALUE STORED IN AN ELEMENT MUST COME BACK AS A NAME (ceo 2026-09-24, CEO-1251): the first cut of this cure left the lowerer's
# IR_DEREF after the value-context subscript, so A[3] = .hold; q = A[3] read q as hold's VALUE (STRING) where SPITBOL keeps the NAME --
# rt_subscript_val already returns the element (the table arm derefs the trap once), and the second deref read a stored name through.
# The lowerer now wires the subscript's result straight to its consumer under the cure (the control arm keeps the deref because its
# container-only entry returns a name trap for arrays); the witness reads a name back from an array and IDENT-compares it. The TABLE
# case is graded under the cure arm only (arm 4, tbl.sno): rt_subscript_var_container_only returns the pair's VALUE on a table hit,
# so the control arm's deref box reads a stored name through -- a pre-existing divergence, the row
# snobol4-a-name-value-read-from-a-table-element-is-dereferenced; rt_subscript_val now derefs only a trap or a cell pointer.
# ⛔ A subscript on a string is left out of the witness on purpose: SPITBOL raises ERROR 235 (fatal without &ERRLIMIT) where SCRIP
# fails the statement -- a pre-existing divergence on both arms, the row snobol4-a-subscript-on-a-non-aggregate-is-error-235-not-a-statement-failure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "REFUSED(2): $ROOT/scrip not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/arr.sno" <<'SNO'
        A = ARRAY(5)
        A[1] = 'one'; A[2] = 2; A[3] = 3.5; A['4'] = 'four'; A[5] = A[2] + A[3]
        OUTPUT = A[1] ' ' A[2] ' ' A[3] ' ' A[4] ' ' A[5] ' ' A['2']
        A[6] = 'six'                                    :S(bad1)F(ok1)
bad1    OUTPUT = 'store past the end succeeded'         :(n1)
ok1     OUTPUT = 'store past the end failed'
n1      x = A[0]                                        :S(bad2)F(ok2)
bad2    OUTPUT = 'read at zero succeeded'               :(n2)
ok2     OUTPUT = 'read at zero failed'
n2      x = A[-1]                                       :S(bad3)F(ok3)
bad3    OUTPUT = 'read at -1 succeeded'                 :(n3)
ok3     OUTPUT = 'read at -1 failed'
n3      B = ARRAY('0:3')
        B[0] = 'zero'; B[3] = 'three'
        OUTPUT = B[0] ' ' B[3] ' ' (DIFFER(B[1]) 'set' | 'null')
        M = ARRAY('2,2')
        M[1,1] = 'a'; M[2,2] = 'd'; M[1,2] = M[1,1] M[2,2]
        OUTPUT = M[1,1] M[1,2] M[2,2] ' ' PROTOTYPE(M)
        T = TABLE()
        T[1] = 'tone'; T['k'] = 'tk'
        OUTPUT = T[1] ' ' T['k'] ' ' (DIFFER(T[2]) 'set' | 'null')
        R = ARRAY(2); R[1] = ARRAY(2); R[1][2] = 'nested'
        OUTPUT = R[1][2] ' ' DATATYPE(R[1])
        A[1] 'n' . got
        OUTPUT = got
        nm = .A[2]
        $nm = 22
        OUTPUT = A[2] ' ' COPY(A)[2]
        hold = 'held'
        A[3] = .hold
        q = A[3]
        OUTPUT = DATATYPE(q) ' ' DATATYPE(A[3]) ' ' $q ' ' (IDENT(A[3], .hold) 'same' | 'other')
        V = ARRAY(100)
        I = 0
fill    I = I + 1
        V[I] = I * I                                    :S(fill)
        I = 0; SUM = 0
read    I = LT(I, 100) I + 1                            :F(done)
        SUM = SUM + V[I]                                :(read)
done    OUTPUT = SUM
END
SNO
cat > "$W/tbl.sno" <<'SNO'
        hold = 'held'
        T = TABLE()
        T['n'] = .hold
        r = T['n']
        OUTPUT = DATATYPE(r) ' ' DATATYPE(T['n']) ' ' $r ' ' (IDENT(T['n'], .hold) 'same' | 'other')
        U = TABLE(); U['a'] = 1; U['b'] = U['a'] + 1; OUTPUT = U['b'] ' ' DATATYPE(U['zz']) ' ' (DIFFER(U['zz']) 'set' | 'null')
END
SNO
cat > "$W/loop.sno" <<'SNO'
        V = ARRAY(200)
        K = 0
outer   K = LT(K, 100) K + 1                            :F(done)
        I = 0
fill    I = LT(I, 200) I + 1                            :F(sum)
        V[I] = I * 2                                    :(fill)
sum     I = 0; S = 0
read    I = LT(I, 200) I + 1                            :F(outer)
        S = S + V[I]                                    :(read)
done    OUTPUT = S
END
SNO
red=0
"$SBL" $(sbl_lang_flags) "$W/arr.sno" < /dev/null > "$W/arr.ref" 2>&1 || true
[ -s "$W/arr.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
for arm in on off; do
    if [ "$arm" = on ]; then unset SCRIP_SUB_VAL; else export SCRIP_SUB_VAL=0; fi
    ( cd "$W" && "$ROOT/scrip" --compile --out="$W/arr_$arm.s" arr.sno < /dev/null > /dev/null 2>&1 ) || { echo "RED: arr.sno did not compile (arm $arm)"; red=1; continue; }
    nv=$(grep -cE 'call +(qword ptr \[rip \+ )?(c_)?rt_subscript_val@|call +rt_subscript_val( |$)' "$W/arr_$arm.s")
    if [ "$arm" = on ]; then [ "$nv" -ge 12 ] && echo "ok  arm on: $nv value-context subscript sites" || { echo "RED arm on: value sites=$nv (want >= 12)"; red=1; }
    else [ "$nv" -eq 0 ] && echo "ok  arm off: 0 value-context sites" || { echo "RED arm off: $nv value sites under SCRIP_SUB_VAL=0"; red=1; }; fi
    ( cd "$W" && timeout -k 5 20 "$ROOT/scrip" arr.sno < /dev/null > "$W/arr.$arm.m3" 2>&1 ); cmp -s "$W/arr.$arm.m3" "$W/arr.ref" && echo "ok  m3 arm $arm = oracle" || { echo "RED m3 arm $arm differs from the oracle:"; diff "$W/arr.ref" "$W/arr.$arm.m3" | head -8; red=1; }
    if gcc "$W/arr_$arm.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/arr_$arm.bin" 2>/dev/null; then
        ( cd "$W" && timeout -k 5 20 "./arr_$arm.bin" < /dev/null > "$W/arr.$arm.m4" 2>&1 ); cmp -s "$W/arr.$arm.m4" "$W/arr.ref" && echo "ok  m4 arm $arm = oracle" || { echo "RED m4 arm $arm differs from the oracle:"; diff "$W/arr.ref" "$W/arr.$arm.m4" | head -8; red=1; }
    else echo "RED m4 arm $arm did not link"; red=1; fi
    ( cd "$W" && "$ROOT/scrip" --compile --out="$W/loop_$arm.s" loop.sno < /dev/null > /dev/null 2>&1 && gcc "$W/loop_$arm.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/loop_$arm.bin" 2>/dev/null ) || { echo "RED: loop.sno did not build (arm $arm)"; red=1; continue; }
    nc=$( cd "$W" && SCRIP_ZETA_TELEM=1 timeout -k 5 60 "./loop_$arm.bin" < /dev/null 2>&1 >/dev/null | grep -c '^\[ZGC\]' )
    if [ "$arm" = on ]; then [ "$nc" -eq 0 ] && echo "ok  arm on: the 40,000-access loop collected 0 times at the shipped arena" || { echo "RED arm on: $nc collections in the element loop -- an element access still allocates"; red=1; }
    else [ "$nc" -ge 1 ] && echo "ok  arm off: the same loop collects ($nc) -- the control arm still mints the cells" || { echo "RED arm off: 0 collections under SCRIP_SUB_VAL=0 -- the control arm is not a control"; red=1; }; fi
done
unset SCRIP_SUB_VAL
"$SBL" $(sbl_lang_flags) "$W/tbl.sno" < /dev/null > "$W/tbl.ref" 2>&1 || true
[ -s "$W/tbl.ref" ] || { echo "REFUSED(2): the oracle printed nothing for tbl.sno"; exit 2; }
( cd "$W" && timeout -k 5 20 "$ROOT/scrip" tbl.sno < /dev/null > "$W/tbl.m3" 2>&1 ); cmp -s "$W/tbl.m3" "$W/tbl.ref" && echo "ok  m3 cure: a name read from a table element is a NAME" || { echo "RED m3 cure: tbl.sno differs from the oracle:"; diff "$W/tbl.ref" "$W/tbl.m3" | head -6; red=1; }
( cd "$W" && "$ROOT/scrip" --compile --out="$W/tbl.s" tbl.sno < /dev/null > /dev/null 2>&1 && gcc "$W/tbl.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/tbl.bin" 2>/dev/null && timeout -k 5 20 "./tbl.bin" < /dev/null > "$W/tbl.m4" 2>&1 ); cmp -s "$W/tbl.m4" "$W/tbl.ref" && echo "ok  m4 cure: a name read from a table element is a NAME" || { echo "RED m4 cure: tbl.sno differs from the oracle:"; diff "$W/tbl.ref" "$W/tbl.m4" | head -6; red=1; }
[ "$red" -eq 0 ] && { echo "GATE OK: element reads and stores allocate nothing, the control arm restores the cell path, and both arms match the oracle in both modes"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
