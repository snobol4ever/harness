#!/usr/bin/env bash
# test_gate_sno_stored_pattern_alternation_capture_keeps_its_start.sh -- the coo's four-line witness of 2026-10-01 11:4x
# (round 2 of the testing officer's loop at 934c76f9f, bisected to 093e95d68, the stored-pattern leaf cells on the RSP
# spine): a BREAK, SPAN or REM leaf inside an alternation arm of a stored pattern captured with . lost the capture's start
# cursor on the spine road -- 'ABS x' ? PAT read [BS] for sbl's [ABS], and the SPAN arm refused as a CORRUPT CAPTURE
# ENTRY. It took AIS 8/8 to 6/8 and snoflake's wang-theorem-prover red; the masters did not see it. Ruled CEO-1389: the
# shipped default went back to the leaf-FRAME road until the spine road passed this witness. The cto cured the capture class
# at fe59fc42b (an arm leaf keeps the frame on every road) and, on the ceo's ruling CEO-1391 (a), the coo ran the SNOBOL4
# family under SCRIP_LEAF_FRAME=0 at a53a601fd: 5766 program-mode readings, 0 outcome differences from the default. The
# default is the spine road again, and the SCRIP_LEAF_FRAME switch is deleted (no env chooses a frame placement, RULES.md
# ZETA TIER IS DERIVED; test_gate_no_zeta_frame_switches read it red). ARMS 1-2 grade the one road in both modes against
# sbl -bf and BLOCK.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; SCRIP="$ROOT/scrip"; RT="$ROOT/out"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="${SBL:-$(sbl_correctness_bin 2>/dev/null || echo /home/resources/x64/bin/sbl)}"
[ -x "$SCRIP" ] && [ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSE(2): no ./scrip or out/libscrip_rt.so -- build first"; exit 2; }
[ -x "$SBL" ] || { echo "⛔ REFUSE(2): no SPITBOL oracle at $SBL"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; trap 'rm -rf "$W"; exit 143' TERM; trap 'rm -rf "$W"; exit 130' INT
cat > "$W/cap.sno" <<'SNO'
        &ANCHOR = 1
        PAT = (ANY('ABCDEFGHIJKLMNOPQRSTUVWXYZ') (BREAK(' ') | REM)) . LABEL
        'ABS x' ? PAT
        OUTPUT = '[' LABEL ']'
        'ACOS' ? PAT
        OUTPUT = '[' LABEL ']'
        P2 = (ANY('AB') (SPAN('C') | REM)) . L2
        'ACCD' ? P2
        OUTPUT = '[' L2 ']'
END
SNO
fail=0; ck() { if [ "$1" = ok ]; then echo "  ✅ $2"; else echo "  ⛔ $2"; fail=$((fail+1)); fi; }
ref="$("$SBL" -bf "$W/cap.sno" </dev/null 2>/dev/null)"
[ "$ref" = "$(printf '[ABS]\n[ACOS]\n[ACC]')" ] || { echo "⛔ REFUSE(2): the oracle did not answer [ABS] [ACOS] [ACC] -- got: $ref"; exit 2; }
m3="$(cd "$W" && timeout -k 5 10 "$SCRIP" cap.sno </dev/null 2>&1)"
ck "$([ "$m3" = "$ref" ] && echo ok || echo no)" "mode 3, shipped default: the three captures match sbl (got: $(printf '%s' "$m3" | tr '\n' ' ' | cut -c1-80))"
(cd "$W" && timeout -k 5 10 "$SCRIP" --compile -o cap.s cap.sno </dev/null >/dev/null 2>&1 && gcc -o cap cap.s "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null)
m4="$(cd "$W" && timeout -k 5 10 ./cap </dev/null 2>&1)"
ck "$([ "$m4" = "$ref" ] && echo ok || echo no)" "mode 4, shipped default: the same (got: $(printf '%s' "$m4" | tr '\n' ' ' | cut -c1-80))"
[ "$fail" = 0 ] && { echo "✅ GATE OK: a stored pattern's alternation-arm leaf keeps the capture's start cursor on the spine road, both modes"; exit 0; }
echo "⛔ GATE RED: $fail arm(s) failed"; exit 1
