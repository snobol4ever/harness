#!/usr/bin/env bash
# test_gate_icn_the_callgen_act_plus_8_word_is_h_or_zero_and_labelled_ptr_frame_h.sh -- THE ICON GENERATOR CALL'S act +8 WORD IS FIXED PER ARM AT EMIT TIME:
# H (the callee's retained generator frame) after a gamma landing and ZERO after the FAIL and the omega landings, LABELLED ZK_PTR_FRAME_H IN THE FRAME MAP, NEVER A SAVED RSP.
# (hq_zetas, the cto's one condition on the Icon H-form, answering hq_collector's ask of 2026-10-11; GC_LAY_PTR_FRAME_H = 5.) THE MEASURED SHAPE: an Icon generator's gamma port
# is only its suspend (gen_gamma saves the resume cell at H+32 and rsp at H+40 and jumps to the caller's landing with rdx = H), so every non-FAIL gamma landing leaves a LIVE retained
# callee frame; the frame is released at the callee's omega port. The old FAIL landing stored the machine rsp into the same word -- one word holding H at one moment and an rsp at
# another, labelled PTR_CODE -- and the omega landing left the released frame's H behind. ONE compile of the fixture grades the layout rows and the stores by offset; ONE m3 run
# grades that a generator still resumes (a store of zero on a gamma landing sends beta through H = 0 and dies at fault address 0x28).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || exit 2
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=icn_the_callgen_act_plus_8_word_is_h_or_zero_and_labelled_ptr_frame_h
FIX="$HERE/fixtures/icn_generator_call_act8_witness.icn"; REF="$HERE/fixtures/icn_generator_call_act8_witness.ref"
[ -f "$FIX" ] && [ -f "$REF" ] || { echo "GATE UNPROVEN(2) [$G]: fixture or ref missing ($FIX)"; exit 2; }
bash "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
SC="${ICN_ACT8_SCRIP:-$ROOT/scrip}"
W="$(mktemp -d "${TMPDIR:-/tmp}/icnact8.XXXXXX")" || exit 2
trap 'rm -rf "$W"' EXIT
timeout -k 5 60 "$SC" --dump-zeta "$FIX" < /dev/null > "$W/zeta.txt" 2> "$W/zeta.err"
timeout -k 5 60 "$SC" --compile -o "$W/w.s" "$FIX" < /dev/null > /dev/null 2> "$W/c.err" || { echo "GATE UNPROVEN(2) [$G]: the fixture did not compile: $(head -2 "$W/c.err")"; exit 2; }
hrows="$(grep -c 'PTR_FRAME_H *callgen.act +8' "$W/zeta.txt")"
crows="$(grep -c 'PTR_CODE *callgen.act +8' "$W/zeta.txt")"
bad=0
echo "  arm 1: $hrows callgen.act +8 rows labelled PTR_FRAME_H, $crows labelled PTR_CODE (want 3 and 0)"
[ "$hrows" -eq 3 ] && [ "$crows" -eq 0 ] || bad=$((bad+1))
rspst=0; zst=0; sites=0
for off in $(grep 'PTR_FRAME_H *callgen.act +8' "$W/zeta.txt" | awk '{print $2}' | tr -d '+'); do
  sites=$((sites+1))
  r="$(grep -c "mov  *qword ptr \[rbp + $off\], rsp" "$W/w.s")"; z="$(grep -c "mov  *qword ptr \[rbp + $off\], 0\$" "$W/w.s")"
  rspst=$((rspst+r)); zst=$((zst+z))
done
want=$((sites * 2)); [ -n "${FAIL_ONCE:-}" ] && want=$((sites * 2 + 1))
echo "  arm 2: over $sites call sites, $rspst stores of rsp into the word (want 0), $zst stores of zero (want $want: the FAIL and the omega landing)"
[ "$sites" -eq 3 ] && [ "$rspst" -eq 0 ] && [ "$zst" -eq "$want" ] || bad=$((bad+1))
got="$(timeout -k 5 60 "$SC" "$FIX" < /dev/null 2>/dev/null)"
if [ "$got" = "$(cat "$REF")" ]; then echo "  arm 3: the generator fixture resumes and prints its ref in mode 3"; else echo "  arm 3: RED, the generator fixture printed: $(printf '%s' "$got" | head -3 | tr '\n' ' ')"; bad=$((bad+1)); fi
if [ "$bad" -ne 0 ]; then echo "GATE FAIL(1) [$G]: $bad arm(s) red -- the act +8 word is not fixed per arm, or a generator no longer resumes"; exit 1; fi
echo "GATE PASS(0) [$G]: the Icon act +8 word is labelled PTR_FRAME_H on every generator call site, is never an rsp, is zeroed on the FAIL and omega landings, and a generator resumes"
