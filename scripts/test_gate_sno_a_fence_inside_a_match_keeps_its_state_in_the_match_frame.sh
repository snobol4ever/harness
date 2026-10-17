#!/usr/bin/env bash
# test_gate_sno_a_fence_inside_a_match_keeps_its_state_in_the_match_frame.sh
#
# THE DEFECT (the cto 2026-10-02, row snobol4-eval-of-a-match-on-fence-of-x-or-y-where-y-keeps-state-jumps-to-address-0, minted
# from Lon's infinite_snobol4 random set: 189 of its 202 remaining SIG11): EVAL("'z' ? FENCE('a') | ARB") jumped to address 0,
# both modes; sbl answers the null string. A FENCE whose body held nothing complex was not a fence_frame_candidate, so its
# watermark (the alpha-saved rsp, the capture-stack top, the cursor) went to its zls frame slot addressed [rsp + off] as if rsp
# stood at the frame base -- but inside a match rsp stands under the match frame and the subject. In the EVAL chain the slot
# (0xb0) landed on the match frame's saved r12 and rbp (rbp - rsp = 0xb8 at the FENCE), so the match's exit restored a
# capture-stack pointer into rbp and the chain's ret went to 0. The static compile wrote the same way, onto the dead subject
# copy above the frame, and survived by luck.
# THE CURE (emit.cpp fence_frame_candidate): every non-bare FENCE inside a match region is a frame candidate, so its state
# lives in the match frame (rbp-relative, frame_slot_off) and the match frame is carved for it (emit_match_begin_frame_extra
# and frame_slot_scan read the same predicate).
#
# Each arm grades one line of the evaluator against sbl -bf cut AT RUN TIME, both modes; the last program loops 300 times
# through both forms. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
cat > "$D/ev.sno" <<'SNO'
        &TRIM = 1
loop    line = INPUT                                            :F(END)
        &ERRLIMIT = 1000
        SETEXIT('errh')
        r = EVAL(line)                                          :S(ok)
        OUTPUT = 'FAIL'                                         :(loop)
ok      OUTPUT = DATATYPE(r) ' ' SIZE(r)                        :(loop)
errh    OUTPUT = 'ERROR ' &ERRTYPE                              :(loop)
END
SNO
cat > "$D/lines.txt" <<'TXT'
'z' ? FENCE('a') | ARB
'z' ? FENCE('a') | BREAKX('*/')
'' ? FENCE('1') | REM
'z' ? FENCE('a') | 'z'
'z' ? (FENCE('a') | 'b') 'c'
'abc' ? FENCE(ARB 'c')
'abc' ? FENCE(LEN(1)) | TAB(2)
'xy' ? FENCE('x') FENCE('y') | ARB
TXT
cat > "$D/st.sno" <<'SNO'
        &TRIM = 1
        i = 0
loop    i = LT(i, 300) i + 1                        :F(done)
        s = DUPL('ab', i) 'z'
        r = EVAL("'" s "' ? FENCE('a') | ARB")      :F(loop)
        t = s ? FENCE(LEN(1) 'b') | (ARB 'z')       :F(loop)
        u = 'z' ? FENCE('a') | ARB                  :F(loop)
        n = n + 1                                   :(loop)
done    OUTPUT = 'n=' n
END
SNO
N=$(wc -l < "$D/lines.txt")
( cd "$D" && timeout -k 5 30 "$SBL" -bf ev.sno < lines.txt > want 2>/dev/null; timeout -k 5 30 "$SBL" -bf st.sno < /dev/null > st.want 2>/dev/null )
[ "$(wc -l < "$D/want")" = "$N" ] && [ -s "$D/st.want" ] || refuse "sbl -bf gave no expectation to grade against"
( cd "$D" && timeout -k 5 30 "$B/scrip" ev.sno < lines.txt > m3 2>/dev/null; timeout -k 5 60 "$B/scrip" st.sno < /dev/null > st.m3 2>/dev/null )
( cd "$D" && for p in ev st; do timeout -k 5 120 "$B/scrip" --compile $p.sno < /dev/null > $p.s 2>/dev/null && gcc -no-pie $p.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o $p.bin 2>/dev/null || exit 2; done ) || refuse "mode 4 did not build"
( cd "$D" && timeout -k 5 30 ./ev.bin < lines.txt > m4 2>/dev/null; timeout -k 5 60 ./st.bin < /dev/null > st.m4 2>/dev/null )
red=0; i=0
while IFS= read -r t; do
    i=$((i + 1)); w=$(sed -n "${i}p" "$D/want")
    for m in m3 m4; do g=$(sed -n "${i}p" "$D/$m")
        if [ "$g" = "$w" ]; then echo "  ok   $m  $t  ->  $w"; else echo "  FAIL $m  $t  ->  got '${g:-<none: the run died>}' want '$w'"; red=$((red + 1)); fi
    done
done < "$D/lines.txt"
for m in m3 m4; do
    if cmp -s "$D/st.want" "$D/st.$m"; then echo "  ok   $m  st.sno (300 iterations, EVAL'd and static FENCE alternations)"; else echo "  FAIL $m  st.sno: got [$(tr '\n' ' ' < "$D/st.$m")] want [$(tr '\n' ' ' < "$D/st.want")]"; red=$((red + 1)); fi
done
T=$(( (N + 1) * 2 ))
if [ $red -eq 0 ]; then echo "GATE PASS(0): a FENCE inside a match keeps its state in the match frame, $T arm(s)"; exit 0; fi
echo "GATE FAIL(1): $red of $T arm(s) diverge from sbl -bf"; exit 1
