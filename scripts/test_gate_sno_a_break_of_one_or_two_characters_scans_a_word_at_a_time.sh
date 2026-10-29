#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_a_break_of_one_or_two_characters_scans_a_word_at_a_time.sh -- BREAK(set) OF ONE OR TWO CHARACTERS SCANS EIGHT BYTES PER LOAD
# (hq_snobol4 2026-10-15; row snobol4-speed-beauty-self-host-reads-0-22x-spitbol-in-mode-4-and-0-06x-in-mode-3). rt_sg_scan_member
# (rt_sg_scan.S, the leaf under BREAK and BREAKX) took a set of one or two characters down the byte loop -- about fifteen instructions
# per subject byte, 105,614 calls of the beauty self-host at 496 instructions each, 5.4% of its run -- and a set of three or more through
# a 256-bit bitmap rebuilt on every call. A set of one or two characters now scans the subject eight bytes per load: xor each word with the
# broadcast character and take the zero-byte test (v - 0x01..01) & ~v & 0x80..80, whose lowest flagged byte is always a true match (a
# false flag lies only above a true zero byte), then the first flagged byte is bsf >> 3; the last partial word is one overlapped load at
# end - 8 (its leading bytes were scanned and hold no member) and a subject shorter than eight bytes takes a byte loop. No load leaves
# [pos, end), no stack is used, no SIMD feature is required. A set of three or more characters keeps the bitmap path.
# ARMS: (1) the witness -- six sets (x , xy ,; xyz and two spaces) over every subject length 0..24 with the member at every position and
# a second member three bytes later, nine start positions POS(0 1 2 5 7 8 9 16 30), BREAK and BREAKX -- prints the oracle's 3,900 lines
# in m3 and m4; (2) the instruction slope of `line BREAK(nl) . piece` over a 25-byte line, (Ir at 22,000 iterations - Ir at 2,000) / 20,000,
# is at most 700 (pre-cure 897, this tree 557: the scan itself fell from about 380 to about 45).
# FAIL_ONCE (recorded): arm (2) reads 897 on the pre-cure runtime (parent tree, stash rebuilt) and 557 here; arm (1) is a guard whose
# comparison was shown red once against a ref with one line altered.
# EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle or the build missing, an Ir reading that is not a number).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
. "$HERE/lib_ir_measure.sh" 2>/dev/null || { echo "REFUSED(2): cannot load lib_ir_measure.sh -- this gate will not read Ir by hand"; exit 2; }
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/brk.sno" <<'SNO'
        sets = ARRAY('6')
        sets[1] = 'x'
        sets[2] = ','
        sets[3] = 'xy'
        sets[4] = ',;'
        sets[5] = 'xyz'
        sets[6] = '  '
        starts = ARRAY('9')
        starts[1] = 0
        starts[2] = 1
        starts[3] = 2
        starts[4] = 5
        starts[5] = 7
        starts[6] = 8
        starts[7] = 9
        starts[8] = 16
        starts[9] = 30
        si = 0
sloop   si = si + 1
        GT(si, 6)                                       :S(done)
        set = sets[si]
        len = -1
lloop   len = len + 1
        GT(len, 24)                                     :S(sloop)
        p = -2
ploop   p = p + 1
        GE(p, len)                                      :S(lloop)
        s =
        i = 0
bloop   EQ(i, len)                                      :S(bdone)
        ch = 'a'
        ch = EQ(i, p) SUBSTR(set, 1 + REMDR(i, SIZE(set)), 1)
        ch = EQ(i, p + 3) SUBSTR(set, 1 + REMDR(i + 1, SIZE(set)), 1)
        s = s ch
        i = i + 1                                       :(bloop)
bdone   r =
        ki = 0
kloop   ki = ki + 1
        GT(ki, 9)                                       :S(kdone)
        k = starts[ki]
        s POS(k) BREAK(set) @n                          :S(hit)F(miss)
hit     r = r ' ' n                                     :(kloop)
miss    r = r ' F'                                      :(kloop)
kdone   OUTPUT = si ' ' len ' ' p ':' r
        s POS(0) BREAKX(set) @n                         :S(bx)F(bxf)
bx      OUTPUT = 'bx ' n                                :(ploop)
bxf     OUTPUT = 'bx F'                                 :(ploop)
done
END
SNO
"$SBL" $(sbl_lang_flags) "$W/brk.sno" < /dev/null > "$W/brk.ref" 2>&1 || true
[ "$(wc -l < "$W/brk.ref")" -eq 3900 ] || { echo "REFUSED(2): the oracle printed $(wc -l < "$W/brk.ref") lines for the witness, not 3900"; exit 2; }
red=0
( cd "$W" && timeout -k 5 60 "$ROOT/scrip" brk.sno < /dev/null > "$W/brk.m3" 2>&1 )
if cmp -s "$W/brk.m3" "$W/brk.ref"; then echo "ok  (1) m3 = oracle over 3900 lines"; else echo "RED (1) m3 differs from the oracle:"; diff "$W/brk.ref" "$W/brk.m3" | head -6; red=1; fi
( cd "$W" && "$ROOT/scrip" --compile --out="$W/brk.s" brk.sno < /dev/null > /dev/null 2>&1 && gcc "$W/brk.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/brk.bin" 2>/dev/null ) || { echo "REFUSED(2): the witness did not build in mode 4"; exit 2; }
( cd "$W" && timeout -k 5 60 ./brk.bin < /dev/null > "$W/brk.m4" 2>&1 )
if cmp -s "$W/brk.m4" "$W/brk.ref"; then echo "ok  (1) m4 = oracle"; else echo "RED (1) m4 differs from the oracle:"; diff "$W/brk.ref" "$W/brk.m4" | head -6; red=1; fi
for N in 2000 22000; do
cat > "$W/slope$N.sno" <<SNO
        line = 'abcdefghijklmnopqrstuvwxy' CHAR(10)
        nl = CHAR(10)
        n = 0
loop    line BREAK(nl) . piece
        n = n + 1
        LT(n, $N)                                       :S(loop)
        OUTPUT = n ' ' SIZE(piece)
END
SNO
( cd "$W" && "$ROOT/scrip" --compile --out="$W/slope$N.s" slope$N.sno < /dev/null > /dev/null 2>&1 && gcc "$W/slope$N.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/slope$N.bin" 2>/dev/null ) || { echo "REFUSED(2): the slope twin $N did not build"; exit 2; }
( cd "$W" && ./slope$N.bin < /dev/null > "$W/slope$N.out" 2>&1 ); grep -q "^$N 25\$" "$W/slope$N.out" || { echo "REFUSED(2): the slope twin $N did not print its line: $(head -1 "$W/slope$N.out")"; exit 2; }
done
lo=$( cd "$W" && ir_measure ./slope2000.bin ); hi=$( cd "$W" && ir_measure ./slope22000.bin )
ir_is_number "$lo" && ir_is_number "$hi" || { echo "REFUSED(2): the Ir reading is not a number (lo=$(ir_cell "$lo") hi=$(ir_cell "$hi")): $(ir_reason "$lo") $(ir_reason "$hi")"; exit 2; }
slope=$(( (hi - lo) / 20000 ))
if [ "$slope" -le 700 ]; then echo "ok  (2) BREAK of one character over a 25-byte line costs $slope instructions per iteration (<= 700; pre-cure 897)"
else echo "RED (2) BREAK of one character over a 25-byte line costs $slope instructions per iteration (> 700): the byte loop is back"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: BREAK of one or two characters scans a word at a time and answers the oracle at every length, position and start"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
