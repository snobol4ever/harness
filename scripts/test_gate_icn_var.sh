#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⛔ ONE RUN OF THIS GATE AT A TIME ON THE BOX (coo 2026-09-25, hq_icon's measurement): its corpus bucket runs the Icon rungs'
# procedure_every_to_replace_4 (rung37 file_io), which writes and reads the FIXED path /tmp/rung37_fh_test.txt, so two concurrent runs
# of this gate -- two seats' make test, or a sharded blocking set -- overwrite each other's file and read it FAIL; alone it passes 3 of 3
# in m4 on two binaries. The program is right to use a fixed path; the gate serialises itself, and a lock not granted in 600 s refuses.
exec 9>"${TMPDIR:-/tmp}/s4e_test_gate_icn_var.lock" && flock -w "${ICN_VAR_LOCK_S:-600}" 9 || { echo "⛔ REFUSED(2) [test_gate_icn_var]: another run of this gate has held the box lock past ${ICN_VAR_LOCK_S:-600} s -- its corpus bucket shares /tmp/rung37_fh_test.txt, so it waits rather than race; re-run when it finishes"; exit 2; }
# ../harness/scripts/test_gate_icn_var.sh — ICN-VAR-FENCE gate (GOAL-ICON-BB.md, ICN-VAR ladder close-out).
# Four sections per the FENCE spec:
#   (a) IR_ASSIGN + IR_VAR absent from icn_kind_native_stub (they have real templates);
#   (b) ladder probe sweep — VAR-1/VAR-2/VAR-AUGOP/VAR-3 probes, STRICT (m2==m3==m4==expected)
#       except: augop_concat X34 (the ||:= concat BINOP is outside the VAR-2 numrel+arith lens —
#       m2-correct + clean native REFUSE, documented in the AUGOP handoff) and neg_unassigned X34
#       (an unassigned local var read must LOUDLY REFUSE, never the op_off=-1 runtime bomb);
#   (c) corpus IR_ASSIGN bucket — every corpus rung*.icn whose --dump-bb carries IR_ASSIGN,
#       all three modes vs .expected, with ratchet floors (m3/m4 = PASS or REFUSED, never FAIL);
#   (d) standing structural gates: no_bb_bin_t . no_handencoded --strict . icn_no_stack .
#       icn_one_reg_frame (HARD); no_vstack informational; medium-invisible
#       scoped to the var-family templates (bb_assign_local, bb_var_frame).
# Exit 0 iff (a) + (b) + (c floors) + (d) all hold.
# Authors: LCherryholmes . Jeffrey Cooper M.D. . Claude Opus 4.8   DATE: 2026-06-06
#
# ⛔ THE BUCKET AND TWO PROBES WERE MEASURING A DEAD ERA (s247, seat1, rung N-0).  RED at every pristine HEAD
# since s241 for reasons that are entirely instrument rot:
#   (i)  THE BUCKET SELECTOR MATCHED NOTHING.  It admitted a program when `--dump-bb` carried `IR_ASSIGN`;
#        the dump is JSON and spells the kind WITHOUT the `IR_` prefix (`"kind":"ASSIGN"`), so N=0 across all
#        295 corpus programs and the floors (62/12/22) were UNREACHABLE BY CONSTRUCTION.  A gate that cannot
#        go green however good the compiler gets is as uninformative as one that cannot go red — this one had
#        been filed as "pre-existing RED" for six sessions.  Both spellings are accepted now.
#   (ii) `augop_concat` and `neg_unassigned` carried policy X34 = "m3/m4 must LOUDLY REFUSE".  Both are now
#        implemented natively and produce the oracle answer in all three modes with no refusal.  X34 exists so
#        an unsupported construct fails loud rather than answering wrongly; answering CORRECTLY satisfies that
#        safety property strictly better, so both were promoted to STRICT — the strongest policy, not a
#        relaxation.
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
# ⛔ THE FLOORS ARE FROM THE ERA WHEN THE BUCKET LAST WORKED and have not been re-derived; if they fail
# against a live bucket, that is a measurement to report, not a number to edit into a pass.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
RT_SO="${RT_SO:-$ROOT/out/libscrip_rt.so}"
CORPUS="${CORPUS:-$S4E/corpus/tests/icon}"
VAR_M2_MIN="${VAR_M2_MIN:-62}"
VAR_M3_MIN="${VAR_M3_MIN:-12}"
VAR_M4_MIN="${VAR_M4_MIN:-22}"
BAD=0
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built at $SCRIP — run ../harness/scripts/build_scrip.sh"; exit 2; }

A2=""; A3=""; A4=""; SMX3=0; SMX4=0; RC3=0
# ⭐ THE ENTRY'S OWN COMMAND LINE (ceo CEO-1353, clause 8 (g)(4); clause 8 (f)): RUN_SW holds its declared heap and stack as -d<kb>k -s<kb>k
# (never SCRIP_HEAP_KB, the collector's window) and RUN_AV its ALL.argv arguments -- this gate passed neither, so entry 882
# (rung36_jcon_image, dump(args)) read its one declared argument as absent in every mode and the gate stood red.
declare -a RUN_SW=() RUN_AV=()
run3() {
    local f="$1" TO="${2:-8}"
    local IN="${f%.icn}.stdin"; [ -f "$IN" ] || IN="$(dirname "$f")/config/$(basename "$IN")"; [ -f "$IN" ] || IN=/dev/null
    local D; D="$(dirname "$f")"
    A2=$(cd "$D" && timeout -k 5 "$TO" "$SCRIP" --run ${RUN_SW[@]+"${RUN_SW[@]}"} "$f" ${RUN_AV[@]+--} ${RUN_AV[@]+"${RUN_AV[@]}"} 2>/dev/null <"$IN")
    local e3; e3=$(mktemp)
    A3=$(cd "$D" && timeout -k 5 "$TO" "$SCRIP" --run ${RUN_SW[@]+"${RUN_SW[@]}"} "$f" ${RUN_AV[@]+--} ${RUN_AV[@]+"${RUN_AV[@]}"} 2>"$e3" <"$IN"); RC3=$?
    SMX3=0; grep -q '\[SMX\]' "$e3" && SMX3=1; rm -f "$e3"
    A4=""; SMX4=0
    local s4 b4 e4; s4=$(mktemp --suffix=.s); b4=$(mktemp); rm -f "$b4"; e4=$(mktemp)
    timeout -k 5 "$TO" "$SCRIP" --compile "$f" >"$s4" 2>"$e4" </dev/null || true
    grep -q '\[SMX\]' "$e4" && SMX4=1
    if [ "$SMX4" = 0 ] && [ -s "$s4" ] && [ -f "$RT_SO" ]; then
        if gcc -no-pie "$s4" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o "$b4" 2>/dev/null; then
            A4=$(cd "$D" && timeout -k 5 "$TO" "$b4" ${RUN_SW[@]+"${RUN_SW[@]}"} ${RUN_SW[@]+--} ${RUN_AV[@]+"${RUN_AV[@]}"} 2>/dev/null <"$IN")
        fi
    fi
    rm -f "$s4" "$b4" "$e4"
}

PP=0; PF=0
probe() {
    local name="$1" policy="$2" exp="$3"
    local f; f=$(mktemp /tmp/icnvar_XXXXXX.icn); cat > "$f"
    run3 "$f"; rm -f "$f"
    local ok=1 note=""
    case "$policy" in
        STRICT) { [ "$A2" = "$exp" ] && [ "$A3" = "$exp" ] && [ "$A4" = "$exp" ] && [ "$SMX3" = 0 ] && [ "$SMX4" = 0 ]; } || ok=0 ;;
        X34)    { [ "$A2" = "$exp" ] && [ "$SMX3" = 1 ] && [ "$SMX4" = 1 ] && [ "$RC3" = 0 ]; } || ok=0
                note="(m3/m4 LOUD REFUSED by design)" ;;
    esac
    if [ "$ok" = 1 ]; then PP=$((PP+1)); printf "  OK   %-30s %s\n" "$name" "$note"
    else PF=$((PF+1)); BAD=1; printf "  FAIL %-30s m2='%s' m3='%s'(smx=%s) m4='%s'(smx=%s) exp='%s' %s\n" "$name" "$A2" "$A3" "$SMX3" "$A4" "$SMX4" "$exp" "$note"; fi
}

echo "=== ICN-VAR-FENCE gate ==="
echo "--- (a) IR_ASSIGN / IR_VAR absent from icn_kind_native_stub ---"
stub_assign=$(awk '/static int icn_kind_native_stub/{f=1} f{print} f&&/^}/{exit}' "$ROOT/src/driver/scrip.c" | grep -c 'IR_ASSIGN\|IR_VAR\b' || true)
if [ "$stub_assign" = 0 ]; then echo "  OK   stub-list IR_ASSIGN/IR_VAR count = 0"
else echo "  FAIL stub-list IR_ASSIGN/IR_VAR count = $stub_assign (must be 0)"; BAD=1; fi
[ -d "$ROOT/src/ir" ] || { echo "⛔ GATE REFUSES (rc=2): $ROOT/src/ir does not exist -- the spine-type directory moved again and this check cannot measure (it greped the retired src/contracts/ and printed a false red from 2026-08-28 until 2026-09-05)"; exit 2; }
grep -rq 'IR_ASSIGN' "$ROOT/src/ir/" || { echo "  FAIL IR_ASSIGN missing from src/ir/"; BAD=1; }
grep -rq 'IR_VAR\b' "$ROOT/src/ir/" || { echo "  FAIL IR_VAR missing from src/ir/"; BAD=1; }
echo "  OK   IR_ASSIGN and IR_VAR present in src/ir/"

echo "--- (b) ladder probe sweep (three modes per probe) ---"

# VAR-1: local assign + read, basic shapes
probe var1_assign_int STRICT "42" << 'EOF'
procedure main()
  x := 42;
  write(x);
end
EOF

probe var1_assign_str STRICT "hello" << 'EOF'
procedure main()
  s := "hello";
  write(s);
end
EOF

probe var1_var_to_var STRICT "42" << 'EOF'
procedure main()
  x := 42;
  y := x;
  write(y);
end
EOF

probe var1_reassign STRICT "99" << 'EOF'
procedure main()
  x := 42;
  x := 99;
  write(x);
end
EOF

# VAR-2: binop/relop with var operands
probe var2_var_binop_arith STRICT "7" << 'EOF'
procedure main()
  x := 3;
  write(x + 4);
end
EOF

probe var2_var_accumulate STRICT "6" << 'EOF'
procedure main()
  x := 1;
  x := x + 1;
  x := x + 1;
  x := x + 1;
  x := x + 1;
  x := x + 1;
  write(x);
end
EOF

probe var2_var_relop_pass STRICT "yes" << 'EOF'
procedure main()
  x := 10;
  if x > 5 then write("yes");
end
EOF

probe var2_var_relop_fail STRICT "" << 'EOF'
procedure main()
  x := 3;
  if x > 5 then write("yes");
end
EOF

probe var2_var_while STRICT $'0\n1\n2' << 'EOF'
procedure main()
  i := 0;
  while i < 3 do {
    write(i);
    i := i + 1;
  };
end
EOF

probe var2_var_until STRICT "3" << 'EOF'
procedure main()
  i := 0;
  until i >= 3 do i := i + 1;
  write(i);
end
EOF

# VAR-AUGOP: augmented assignment
probe augop_plus STRICT "6" << 'EOF'
procedure main()
  x := 1;
  x +:= 5;
  write(x);
end
EOF

probe augop_star STRICT "12" << 'EOF'
procedure main()
  x := 3;
  x *:= 4;
  write(x);
end
EOF

probe augop_sub_mod STRICT "3" << 'EOF'
procedure main()
  x := 10;
  x -:= 3;
  x %:= 4;
  write(x);
end
EOF

probe augop_concat STRICT "helloworld" << 'EOF'
procedure main()
  s := "hello";
  s ||:= "world";
  write(s);
end
EOF

# VAR-3: var-subject scans
probe var3_augop_scan STRICT "he" << 'EOF'
procedure main()
  s := "hello";
  s ?:= tab(3);
  write(s);
end
EOF

probe var3_augop_scan_fail STRICT "hello" << 'EOF'
procedure main()
  s := "hello";
  s ?:= tab(99);
  write(s);
end
EOF

probe var3_var_subject_scan STRICT "he" << 'EOF'
procedure main()
  s := "hello";
  s ? write(tab(3));
end
EOF

# NEGATIVE: unassigned var must REFUSE (not crash)
probe neg_unassigned STRICT "" << 'EOF'
procedure main()
  write(undef_var);
end
EOF

# static in a single call behaves as local (TT_STATIC_DECL lowers as no-op IR_SUCCEED; the var
# routes through the same bb_varslot path). Cross-call persistence = its own future tier.
probe static_single_call STRICT "hello" << 'EOF'
procedure main()
  static s;
  s := "hello";
  write(s);
end
EOF

echo "  probes: PASS=$PP FAIL=$PF"

echo "--- (c) corpus IR_ASSIGN bucket (ratchet floors m2>=$VAR_M2_MIN m3>=$VAR_M3_MIN m4>=$VAR_M4_MIN) ---"
# ⛔ DISCOVERY RE-SOURCED (row icn-scan-var-buckets-find-a-fraction-of-their-floor-and-the-jcon-family-fails,
# 2026-09-04) — same cause and same cure as the sibling icn_scan gate (read that script's comment at this
# spot for the full account). The old `find $CORPUS -maxdepth 1 -name 'rung*.icn'` walk never reached
# packages/icon at all (maxdepth 1, and none of those files are rung*-named anyway) and only saw N=12 of a
# required 62 because most rung*.icn assign-touching programs are now RUNGS-SUITE entries, not loose
# files. Source the honest population from ALL.csv's `assign` feature column via lib_rungs_extract.sh.
# The loose KEEPER/DEFERRED rung36_jcon_* files stay deliberately excluded from ALL.csv (each already has
# its own LIVE row — see tests/icon/ALL.excluded.txt) so this bucket does not re-litigate them.
BUCKET_TMP="$(mktemp -d)"; trap 'rm -rf "$BUCKET_TMP"' EXIT
RUNGS_DIR="$CORPUS" RUNGS_EXT=.icn
. "$HERE/lib_rungs_extract.sh"
C2P=0; C2F=0; C3P=0; C3F=0; C3E=0; C4P=0; C4F=0; C4E=0; CN=0
while IFS=$'\t' read -r -a ROW; do
    origin="${ROW[0]:-}"; [ -n "$origin" ] || continue
    RUN_SW=(); [ -n "${ROW[1]:-}" ] && RUN_SW+=("-d${ROW[1]}k"); [ -n "${ROW[2]:-}" ] && RUN_SW+=("-s${ROW[2]}k"); RUN_AV=("${ROW[@]:3}")
    safe="$(printf '%s' "$origin" | tr -c 'A-Za-z0-9_' '_')"
    out="$BUCKET_TMP/$safe.icn"; ref="$BUCKET_TMP/$safe.expected"
    rungs_extract_origin "$origin" "$out" "$ref" || { echo "  FAIL: could not extract $origin (rungs_extract_origin refused)"; C3F=$((C3F+1)); continue; }
    [ -f "${out%.icn}.in" ] && cp "${out%.icn}.in" "${out%.icn}.stdin"   # run3 looks for .stdin, extract writes .in
    CN=$((CN+1))
    exp=$(cat "$ref" 2>/dev/null || true)
    # the entry runs at the heap its ALL.csv row declares (heap_kb, CEO-1167/1225), as every suite runner does -- an undeclared
    # entry runs at the shipped default, unchanged
    run3 "$out" 30
    if [ "$A2" = "$exp" ]; then r2=PASS; C2P=$((C2P+1)); else r2=FAIL; C2F=$((C2F+1)); fi
    if [ "$SMX3" = 1 ]; then r3=REFUSED; C3E=$((C3E+1)); elif [ "$A3" = "$exp" ]; then r3=PASS; C3P=$((C3P+1)); else r3=FAIL; C3F=$((C3F+1)); fi
    if [ "$SMX4" = 1 ]; then r4=REFUSED; C4E=$((C4E+1)); elif [ "$A4" = "$exp" ]; then r4=PASS; C4P=$((C4P+1)); else r4=FAIL; C4F=$((C4F+1)); fi
    printf "  %-46s m2=%-4s m3=%-7s m4=%s\n" "$origin" "$r2" "$r3" "$r4"
done < <(python3 - "$CORPUS/ALL.csv" assign <<'PY' | grep -vP '^(rung36_all__rung36_jcon_kwds|rung36_all__rung36_jcon_fncs1)\t'
import csv, os, sys
path, col = sys.argv[1], sys.argv[2]
av = {}
ap = os.path.join(os.path.dirname(path), "ALL.argv")
if os.path.isfile(ap):
    for ln in open(ap, encoding="utf-8"):
        ln = ln.rstrip("\n")
        if ln.strip() and not ln.lstrip().startswith("#"):
            f = ln.split("\t"); av[f[0]] = f[1:]
for r in csv.DictReader(open(path)):
    if r.get(col, "0") not in ("", "0") and r.get("xfail", "0") in ("", "0"):
        print("\t".join([r["origin"], (r.get("heap_kb") or "").strip(), (r.get("stack_kb") or "").strip()] + av.get(r["entry"], [])))
PY
)
# ⛔ THE TWO EXCLUSIONS ABOVE ARE VERIFIED BUCKET-EXTRACTION ARTIFACTS, NOT SCRIP DEFECTS (2026-09-04,
# this row's own investigation — full byte-for-byte diffs kept in the task file's LEDGER):
#   rung36_all__rung36_jcon_kwds:  every line matches the oracle EXCEPT &progname, which legitimately
#     varies with whatever filename a program is run under (Icon keyword, not a stored constant) — the
#     .ref was captured under a different name ("procedure_every_alt_replace_4") than any name this or
#     any other extractor will ever reproduce. A byte-equal comparison on this entry can never pass
#     regardless of correctness; it is not this gate's population to grade.
#   rung36_all__rung36_jcon_fncs1: genuinely does file I/O against a companion data file
#     (corpus/tests/icon/config/fncs1.dat) that lib_rungs_extract.sh's extraction does not fetch (it
#     materializes .icn/.ref/.stdin only) — CLAUDE.md's own suite-eligibility rule states graded entries
#     must be self-contained with "no file I/O", so this entry's presence in ALL.csv's assign==1 column
#     is itself the pre-existing anomaly, not something to chase inside this bucket.
# If lib_rungs_extract.sh ever grows companion-data-file support, re-admit both and re-verify PASS.
echo "  bucket: N=$CN | m2 PASS=$C2P FAIL=$C2F | m3 PASS=$C3P FAIL=$C3F REFUSED=$C3E | m4 PASS=$C4P FAIL=$C4F REFUSED=$C4E"
[ "$C2P" -ge "$VAR_M2_MIN" ] || { echo "  FLOOR FAIL m2 $C2P < $VAR_M2_MIN"; BAD=1; }
[ "$C3P" -ge "$VAR_M3_MIN" ] || { echo "  FLOOR FAIL m3 $C3P < $VAR_M3_MIN"; BAD=1; }
[ "$C4P" -ge "$VAR_M4_MIN" ] || { echo "  FLOOR FAIL m4 $C4P < $VAR_M4_MIN"; BAD=1; }
[ "$C3F" -eq 0 ] || { echo "  HARD FAIL m3 has $C3F unexpected FAILs (must be 0 — only PASS or REFUSED)"; BAD=1; }
[ "$C4F" -eq 0 ] || { echo "  HARD FAIL m4 has $C4F unexpected FAILs (must be 0 — only PASS or REFUSED)"; BAD=1; }

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
if echo "$mi_line" | grep -qE 'bb_assign_local|bb_var_frame|bb_var_frame_ref|bb_assign_frame'; then
    echo "  FAIL medium-invisible: a var-family template carries raw-byte/medium-branch sites"; BAD=1
else
    echo "  OK   medium-invisible (var-family templates clean; global --strict RED = documented Prolog-lane bb_* WIP)"
fi

echo "==="
if [ "$BAD" = 0 ]; then echo "ICN-VAR-FENCE GATE: PASS"; exit 0
else echo "ICN-VAR-FENCE GATE: FAIL"; exit 1; fi
