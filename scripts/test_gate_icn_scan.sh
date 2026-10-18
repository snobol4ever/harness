#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ../harness/scripts/test_gate_icn_scan.sh — ICN-SCAN-FENCE gate (GOAL-ICON-BB.md, ICN-SCAN ladder close-out).
# Four sections per the FENCE spec:
#   (a) all nine IR_SCAN_* kinds OFF icn_kind_native_stub (and present in src/ir, the spine types);
#   (b) the ladder probe sweep — every ICN-SCAN-0..13a probe, three modes, policy per documented flags:
#         STRICT  m2==m3==m4==expected AND no [SMX] (an refuse must not masquerade as a fail-probe pass)
#         M34     m3==m4==expected, m2 recorded informationally (the SCAN-3 pre-existing oracle pos gap)
#         PIN     m2==m3==m4==ONE-SHOT expected (ORACLE SCAN-FN GENERATIVITY flag: goal probes specify
#                 multi-result; the m2 oracle is one-shot for every scan builtin; native matches the oracle
#                 bit-for-bit and is pump-ready. Making m2 generative SHIFTS THE 129 BASELINE — Lon's call.
#                 Until that re-baseline rung, this gate pins three-mode AGREEMENT on the one-shot value.)
#         X34     m2==expected AND m3 AND m4 each print [SMX] with rc=0 (LOUD REFUSE — the =s var-operand
#                 shape, the wave-1 dynamic-arg refuses; SCAN-13b deferral PROMOTED to STRICT at ICN-VAR-3)
#   (c) the corpus scan bucket — every corpus .icn whose --dump-bb graph carries IR_GEN_SCAN, all three
#       modes vs .expected, with ratchet floors (REFUSED->PASS deltas land here as future boxes light up);
#   (d) standing structural gates: no_bb_bin_t . no_handencoded --strict . icn_no_stack .
#       icn_one_reg_frame (HARD); no_vstack informational; medium-invisible scoped to the
#       scan-family templates (the global --strict RED is the documented Prolog-lane bb_* WIP).
# Exit 0 iff (a) + (b) + (c floors) + (d) all hold.
# Authors: LCherryholmes . Jeffrey Cooper M.D. . Claude Opus 4.8   DATE: 2026-06-04
#
# ⛔ SIX PROBES AND THE CORPUS BUCKET WERE MEASURING A DEAD ERA (s247, seat1, rung N-0).  This gate had
# been RED at every pristine HEAD since s241, which recorded the fact honestly and moved on — and every
# reason for the red turned out to be instrument rot, not compiler defect:
#   (i)  THE BUCKET SELECTOR NAMED A RETIRED OPCODE.  It admitted a program when `--dump-bb` output carried
#        `GEN_SCAN`.  `IR_GEN_SCAN` NO LONGER EXISTS IN `src/ir/` AT ALL (it survives only as a stale
#        row in `src/tools/emit_per_kind_audit.c`); the live scan boxes dump as `"kind":"SCAN"`,
#        `"SCAN_ENTER"`, `"SCAN_TAB"`, `"SCAN_UPTO"`, `"SCAN_MATCH"`, `"SCAN_MOVE"`, `"SCAN_FIND"`.
#        So N=0 for the whole corpus and the m2/m3/m4 floors (31/11/11) were UNREACHABLE BY CONSTRUCTION.
#        A gate that cannot go green no matter how good the compiler gets teaches seats to ignore it — the
#        fail-closed twin of the vacuous-green rot found the same session in icn_no_stack/icn_one_reg_frame.
#        The selector now accepts BOTH spellings.
#   (ii) FOUR PROBES PINNED DEFECTS THE COMPILER HAS SINCE FIXED.  `upto_oneshot` pinned "3" for
#        `"hello" ? every write(upto('l'))` and `find_oneshot` pinned "2" for `"banana" ? every write(find("an"))`
#        — the ONE-SHOT answers, flagged in-gate as the "ORACLE GENERATIVITY" marker.  Canonically both are
#        {*} GENERATORS (`refs/icon-master/src/runtime/fstranl.r:237 function{*} upto`), and SCRIP now emits
#        the correct `3 4` / `2 4`.  The pins were promoted to the true expectations under STRICT.
#        `any_dynamic_arg` and `eq_match_var` carried policy X34 = "m3/m4 must LOUDLY REFUSE": both are now
#        implemented natively and produce the oracle answer in all three modes with no refusal.  X34 exists
#        so an unsupported construct fails loud instead of answering wrongly; an implementation that answers
#        CORRECTLY satisfies that safety property strictly better, so those probes were promoted to STRICT —
#        the strongest policy in the table, not a relaxation.
#   (iii) THE BUCKET COUNTED XFAIL PROGRAMS AS FAILURES.  `test_icon_all_rungs.sh` skips a program with a
#        matching `.xfail` marker (30 exist) and reports XFAIL separately; this bucket had no such skip, so
#        every known-unimplemented program arrived in the "unexpected FAIL" count and the HARD rule ("m3/m4
#        must have ZERO unexpected FAILs") could never hold.  The skip is now the SAME test the suite runner
#        uses — one law, two readers — so an unexpected FAIL is once again unexpected.
#   (iv) THE BUCKET GRADED WITH A DIFFERENT INPUT CONTRACT THAN THE SUITE.  `test_icon_all_rungs.sh` feeds a
#        program its `.stdin` file when one exists and runs it with cwd = the corpus directory so relative
#        data-file reads resolve; this gate fed /dev/null from the SCRIP root, so every program that reads
#        input or opens a data file failed HERE and passed THERE.  That is the whole reason its "unexpected
#        FAIL" count read 28 against a suite watermark of 16.  run3 now applies both laws.
#   (v)  `m2` IS A FOSSIL: modes 1 and 2 were DELETED, and both the A2 and A3 columns invoke the SAME
#        `--run` command.  The column is retained because the floors are keyed to it — and it does earn a
#        keep, as a same-binary repeat that would expose a nondeterministic program — but it is NOT an
#        independent mode and must never be read as one.
#   (vi) A PROGRAM WITH NO `.expected` CANNOT BE GRADED, AND THE BUCKET GRADED IT ANYWAY — comparing its
#        output against the empty string and counting the mismatch as a failure.  Two corpus programs carry
#        no oracle (`rung37_every_do_hello` is the one that reaches these buckets); the suite's denominator
#        is 293, not 295, for exactly this reason.  Skipped now, as the suite does.
# ⛔ THE FLOORS BELOW ARE FROM THE ERA WHEN THE BUCKET LAST WORKED and have not been re-derived; if they now
# fail against a live bucket, that is a measurement to report, not a number to edit into a pass.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP:-$ROOT/scrip}"
RT_SO="${RT_SO:-$ROOT/out/libscrip_rt.so}"
CORPUS="${CORPUS:-$S4E/corpus/tests/icon}"
# ⛔ FLOORS RE-DERIVED s247 (seat1, N-0) — 31/11/11 -> 26/26/24, AND THE ARITHMETIC IS THE JUSTIFICATION.
# The old floors were calibrated against a bucket that walked `find $CORPUS -name '*.icn'` RECURSIVELY —
# 1,348 files across jcon-ref/, jcon-compiler/, ipl/, parser/, repro/, of which 1,048 CARRY NO `.expected`.
# Those were graded against the EMPTY STRING, so a library file that prints nothing scored a PASS.  Of the
# 53 programs the GEN_SCAN filter admitted, 22 had no oracle: skipping them removed 18 PASSES and 4 FAILS
# (18+4 = 22, exactly).  ⭐ THE HONEST PASS COUNT DID NOT MOVE — 44 - 18 = 26 — so NO REAL PROGRAM
# REGRESSED, which is the check that distinguishes re-deriving a floor from lowering a bar to buy a green.
# m3 11 -> 26 and m4 11 -> 24 are large TIGHTENINGS; m2 31 -> 26 is a smaller number against an honest
# population.  Measured at SCRIP 0b1b7d4f, pristine, RT_OPT=-O0.
SCAN_M2_MIN="${SCAN_M2_MIN:-26}"
SCAN_M3_MIN="${SCAN_M3_MIN:-26}"
SCAN_M4_MIN="${SCAN_M4_MIN:-24}"
BAD=0
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built at $SCRIP — run ../harness/scripts/build_scrip.sh"; exit 2; }

A2=""; A3=""; A4=""; SMX3=0; SMX4=0; RC3=0
run3() {
    local f="$1" TO="${2:-8}"
    local IN="${f%.icn}.stdin"; [ -f "$IN" ] || IN="$(dirname "$f")/config/$(basename "$IN")"; [ -f "$IN" ] || IN=/dev/null
    local D; D="$(dirname "$f")"
    A2=$(cd "$D" && timeout -k 5 "$TO" "$SCRIP" --run "$f" 2>/dev/null <"$IN")
    local e3; e3=$(mktemp)
    A3=$(cd "$D" && timeout -k 5 "$TO" "$SCRIP" --run "$f" 2>"$e3" <"$IN"); RC3=$?
    SMX3=0; grep -q '\[SMX\]' "$e3" && SMX3=1; rm -f "$e3"
    A4=""; SMX4=0
    local s4 b4 e4; s4=$(mktemp --suffix=.s); b4=$(mktemp); rm -f "$b4"; e4=$(mktemp)
    timeout -k 5 "$TO" "$SCRIP" --compile "$f" >"$s4" 2>"$e4" </dev/null || true
    grep -q '\[SMX\]' "$e4" && SMX4=1
    if [ "$SMX4" = 0 ] && [ -s "$s4" ] && [ -f "$RT_SO" ]; then
        if gcc -no-pie "$s4" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o "$b4" 2>/dev/null; then
            A4=$(cd "$D" && timeout -k 5 "$TO" "$b4" 2>/dev/null <"$IN")
        fi
    fi
    rm -f "$s4" "$b4" "$e4"
}

PP=0; PF=0
probe() {
    local name="$1" policy="$2" exp="$3"
    local f; f=$(mktemp /tmp/icnscan_XXXXXX.icn); cat > "$f"
    run3 "$f"; rm -f "$f"
    local ok=1 note=""
    case "$policy" in
        STRICT) { [ "$A2" = "$exp" ] && [ "$A3" = "$exp" ] && [ "$A4" = "$exp" ] && [ "$SMX3" = 0 ] && [ "$SMX4" = 0 ]; } || ok=0 ;;
        M34)    { [ "$A3" = "$exp" ] && [ "$A4" = "$exp" ] && [ "$SMX3" = 0 ] && [ "$SMX4" = 0 ]; } || ok=0
                note="(m2='$A2' — SCAN-3 documented oracle pos gap)" ;;
        PIN)    { [ "$A2" = "$exp" ] && [ "$A3" = "$exp" ] && [ "$A4" = "$exp" ] && [ "$SMX3" = 0 ] && [ "$SMX4" = 0 ]; } || ok=0
                note="(one-shot pin — ORACLE GENERATIVITY flag)" ;;
        X34)    { [ "$A2" = "$exp" ] && [ "$SMX3" = 1 ] && [ "$SMX4" = 1 ] && [ "$RC3" = 0 ]; } || ok=0
                note="(m3/m4 LOUD REFUSED by design)" ;;
    esac
    if [ "$ok" = 1 ]; then PP=$((PP+1)); printf "  OK   %-22s %s\n" "$name" "$note"
    else PF=$((PF+1)); BAD=1; printf "  FAIL %-22s m2='%s' m3='%s'(smx=%s) m4='%s'(smx=%s) exp='%s' %s\n" "$name" "$A2" "$A3" "$SMX3" "$A4" "$SMX4" "$exp" "$note"; fi
}

echo "=== ICN-SCAN-FENCE gate ==="
echo "--- (a) icn_kind_native_stub carries ZERO IR_SCAN_* kinds ---"
stub_hits=$(awk '/static int icn_kind_native_stub/{f=1} f{print} f&&/^\}/{exit}' "$ROOT/src/driver/scrip.c" | grep -c 'IR_SCAN_' || true)
if [ "$stub_hits" = 0 ]; then echo "  OK   stub-list IR_SCAN_* count = 0"; else echo "  FAIL stub-list IR_SCAN_* count = $stub_hits (must be 0)"; BAD=1; fi
[ -d "$ROOT/src/ir" ] || { echo "⛔ GATE REFUSES (rc=2): $ROOT/src/ir does not exist -- the spine-type directory moved again and this check cannot measure (it greped the retired src/contracts/ and printed a false red from 2026-08-28 until 2026-09-05)"; exit 2; }
for k in POS ANY MATCH MANY TAB MOVE UPTO FIND BAL; do
    grep -rq "IR_SCAN_$k" "$ROOT/src/ir/" || { echo "  FAIL IR_SCAN_$k missing from src/ir/"; BAD=1; }
done
echo "  OK   all nine IR_SCAN_* kinds present in src/ir/"

echo "--- (b) ladder probe sweep (three modes per probe) ---"
probe scan_subject STRICT "hello" << 'EOF'
procedure main()
  "hello" ? write(&subject);
end
EOF
probe scan_concat_subject STRICT "foobar" << 'EOF'
procedure main()
  ("foo" || "bar") ? write(&subject);
end
EOF
probe scan_pos_kw STRICT "1" << 'EOF'
procedure main()
  "hello" ? write(&pos);
end
EOF
probe scan_nested STRICT "inner" << 'EOF'
procedure main()
  "outer" ? ("inner" ? write(&subject));
end
EOF
probe pos_1 M34 "1" << 'EOF'
procedure main()
  "abc" ? write(pos(1));
end
EOF
probe pos_fail STRICT "" << 'EOF'
procedure main()
  "hello" ? write(pos(2));
end
EOF
probe any_h STRICT "2" << 'EOF'
procedure main()
  "hello" ? write(any('h'));
end
EOF
probe any_multi STRICT "2" << 'EOF'
procedure main()
  "hello" ? write(any('xeh'));
end
EOF
probe any_fail STRICT "" << 'EOF'
procedure main()
  "hello" ? write(any('x'));
end
EOF
probe any_empty_subject STRICT "" << 'EOF'
procedure main()
  "" ? write(any('h'));
end
EOF
probe any_dynamic_arg STRICT "2" << 'EOF'
procedure main()
  c := 'h';
  "hello" ? write(any(c));
end
EOF
probe match_he STRICT "3" << 'EOF'
procedure main()
  "hello" ? write(match("he"));
end
EOF
probe match_fail STRICT "" << 'EOF'
procedure main()
  "hello" ? write(match("xx"));
end
EOF
probe match_subj_short STRICT "" << 'EOF'
procedure main()
  "he" ? write(match("hello"));
end
EOF
probe match_empty STRICT "1" << 'EOF'
procedure main()
  "hello" ? write(match(""));
end
EOF
probe many_spaces STRICT "3" << 'EOF'
procedure main()
  "  x" ? write(many(' '));
end
EOF
probe many_fail STRICT "" << 'EOF'
procedure main()
  "hello" ? write(many(' '));
end
EOF
probe tab_3 STRICT "he" << 'EOF'
procedure main()
  "hello" ? write(tab(3));
end
EOF
probe tab_upto STRICT "he" << 'EOF'
procedure main()
  "hello" ? write(tab(upto('l')));
end
EOF
probe move_2 STRICT "he" << 'EOF'
procedure main()
  "hello" ? write(move(2));
end
EOF
probe upto_oneshot STRICT "$(printf '3\n4')" << 'EOF'
procedure main()
  "hello" ? every write(upto('l'));
end
EOF
probe find_oneshot STRICT "$(printf '2\n4')" << 'EOF'
procedure main()
  "banana" ? every write(find("an"));
end
EOF
probe bal_b STRICT "4" << 'EOF'
procedure main()
  "(a)b" ? every write(bal('b'));
end
EOF
probe eq_match_he STRICT "he" << 'EOF'
procedure main()
  "hello" ? write(="he");
end
EOF
probe eq_match_fail STRICT "" << 'EOF'
procedure main()
  "hello" ? write(="x");
end
EOF
probe eq_match_var STRICT "he" << 'EOF'
procedure main()
  s := "he";
  "hello" ? write(=s);
end
EOF
probe augop_scan STRICT "he" << 'EOF'
procedure main()
  s := "hello";
  s ?:= tab(3);
  write(s);
end
EOF
probe augop_scan_fail STRICT "hello" << 'EOF'
procedure main()
  s := "hello";
  s ?:= tab(99);
  write(s);
end
EOF
echo "  probes: PASS=$PP FAIL=$PF"

echo "--- (c) corpus IR_GEN_SCAN bucket (ratchet floors m2>=$SCAN_M2_MIN m3>=$SCAN_M3_MIN m4>=$SCAN_M4_MIN) ---"
# ⛔ DISCOVERY RE-SOURCED (row icn-scan-var-buckets-find-a-fraction-of-their-floor-and-the-jcon-family-fails,
# 2026-09-04). The old `find $CORPUS -name '*.icn'` + --dump-bb-sniff walk measured a fraction of its own
# floor (N=3 of a required 26) because TWO migrations shrank it, one after the other: the 2026-08-24 corpus
# re-grid moved jcon-ref/jcon-compiler/ipl out of tests/icon into corpus/packages/icon (this row's original
# diagnosis), and the later RUNGS-SUITE flattening absorbed most of the remaining loose scan-touching
# programs into tests/icon/ALL.icn. Repointing CORPUS at packages/icon is A DEAD END, verified, not assumed:
# those three trees carry ZERO .expected files (grep -c across all three = 0), so widening the walk there
# admits nothing. The honest current population lives in ALL.csv's own `scan` feature column; source it via
# lib_rungs_extract.sh (CLAUDE.md RUNGS SUITES: "the ONE way" to materialize a witness) instead of
# re-deriving the filter with a second --dump-bb sniff per file. The loose KEEPER/DEFERRED files under
# tests/icon (rung36_jcon_cxprimes/_genqueen/_recogn/_proto/_var, ...) are DELIBERATELY excluded from
# ALL.csv by the suite's own absorption policy (tests/icon/ALL.excluded.txt) because each already has its
# own LIVE row (icon-coexpression-support-design, icn-recogn-genqueen-suspend-shape,
# icon-v9gen-augmented-assign-and-unary-refresh-plus-two-emitter-gaps) — this bucket is not the place to
# re-litigate them under a different name; it grades the population the rest of the project already trusts.
BUCKET_TMP="$(mktemp -d)"; trap 'rm -rf "$BUCKET_TMP"' EXIT
RUNGS_DIR="$CORPUS" RUNGS_EXT=.icn
. "$HERE/lib_rungs_extract.sh"
C2P=0; C2F=0; C3P=0; C3F=0; C3E=0; C4P=0; C4F=0; C4E=0; CN=0
while IFS= read -r origin; do
    [ -n "$origin" ] || continue
    safe="$(printf '%s' "$origin" | tr -c 'A-Za-z0-9_' '_')"
    out="$BUCKET_TMP/$safe.icn"; ref="$BUCKET_TMP/$safe.expected"
    rungs_extract_origin "$origin" "$out" "$ref" || { echo "  FAIL: could not extract $origin (rungs_extract_origin refused)"; C3F=$((C3F+1)); continue; }
    [ -f "${out%.icn}.in" ] && cp "${out%.icn}.in" "${out%.icn}.stdin"   # run3 looks for .stdin, extract writes .in
    CN=$((CN+1))
    exp=$(cat "$ref" 2>/dev/null || true)
    run3 "$out" 30
    if [ "$A2" = "$exp" ]; then r2=PASS; C2P=$((C2P+1)); else r2=FAIL; C2F=$((C2F+1)); fi
    if [ "$SMX3" = 1 ]; then r3=REFUSED; C3E=$((C3E+1)); elif [ "$A3" = "$exp" ]; then r3=PASS; C3P=$((C3P+1)); else r3=FAIL; C3F=$((C3F+1)); fi
    if [ "$SMX4" = 1 ]; then r4=REFUSED; C4E=$((C4E+1)); elif [ "$A4" = "$exp" ]; then r4=PASS; C4P=$((C4P+1)); else r4=FAIL; C4F=$((C4F+1)); fi
    printf "  %-44s m2=%-4s m3=%-7s m4=%s\n" "$origin" "$r2" "$r3" "$r4"
done < <(python3 - "$CORPUS/ALL.csv" scan <<'PY'
import csv, sys
path, col = sys.argv[1], sys.argv[2]
for r in csv.DictReader(open(path)):
    if r.get(col, "0") not in ("", "0") and r.get("xfail", "0") in ("", "0"):
        print(r["origin"])
PY
)
echo "  bucket: N=$CN | m2 PASS=$C2P FAIL=$C2F | m3 PASS=$C3P FAIL=$C3F REFUSED=$C3E | m4 PASS=$C4P FAIL=$C4F REFUSED=$C4E"
[ "$C2P" -ge "$SCAN_M2_MIN" ] || { echo "  FLOOR FAIL m2 $C2P < $SCAN_M2_MIN"; BAD=1; }
[ "$C3P" -ge "$SCAN_M3_MIN" ] || { echo "  FLOOR FAIL m3 $C3P < $SCAN_M3_MIN"; BAD=1; }
[ "$C4P" -ge "$SCAN_M4_MIN" ] || { echo "  FLOOR FAIL m4 $C4P < $SCAN_M4_MIN"; BAD=1; }

echo "--- (d) standing structural gates ---"
gate_hard() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then echo "  OK   $label"
    else echo "  FAIL $label"; BAD=1; fi
}
gate_hard "no_bb_bin_t"            bash "$HERE/test_gate_no_bb_bin_t.sh"
gate_hard "no_handencoded --strict" bash "$HERE/test_gate_no_handencoded_bytes.sh" --strict
gate_hard "icn_no_stack"           bash "$HERE/test_gate_icn_no_stack.sh"
gate_hard "icn_one_reg_frame"      bash "$HERE/test_gate_icn_one_reg_frame.sh"
bash "$HERE/test_gate_no_vstack.sh" 2>/dev/null | tail -1 | sed 's/^/  INFO /'
mi_line=$(bash "$HERE/test_gate_template_medium_invisible.sh" 2>/dev/null | grep '^REMAINING:' || true)
if echo "$mi_line" | grep -qE 'bb_scan_|bb_gen_scan|bb_keyword'; then
    echo "  FAIL medium-invisible: a scan-family template carries raw-byte/medium-branch sites"; BAD=1
else
    echo "  OK   medium-invisible (scan-family templates clean; global --strict RED = documented Prolog-lane bb_* WIP)"
fi

echo "==="
if [ "$BAD" = 0 ]; then echo "ICN-SCAN-FENCE GATE: PASS"; exit 0
else echo "ICN-SCAN-FENCE GATE: FAIL"; exit 1; fi
