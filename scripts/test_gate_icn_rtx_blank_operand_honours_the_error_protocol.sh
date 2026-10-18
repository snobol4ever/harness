#!/bin/bash
# The rtx assembly fast path for numeric coercion handles DT_SNUL and the empty string ITSELF and
# never consults the error-protocol code the IR node carries, so `2 + &null` and `2 + ""` still
# print 2 where iconx raises run-time error 102. Row
# icon-rtx-icnnum-blank-operand-fast-path-ignores-the-coercion-error-protocol (hq_I lane: rtx_icn*.s).
#
# ⭐ THE ABLATION IS THE PROOF, AND IT IS BUILT INTO THIS GATE: the same two programs under
# SCRIP_RTX_ICNNUM=0 already raise 102 correctly, because c_rt_coerce_num2_d treats a blank operand
# as unconvertible under COERCE_ERR_FAILURE_CONVERTIBLE (SCRIP c12a378f0). So the C semantics are
# right and only the assembly shortcut is wrong -- this gate FAILS if that stops being true in
# either direction, which is what keeps the routing honest: if someone "fixes" this by weakening the
# C path, the control arm goes red rather than the gate going green.
#
# ⛔ REFUSES rc=2 unless all 8 runs (2 witnesses x 2 modes x asm-on/asm-off) are graded, and rc=2 if
# the Icon oracle is missing.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || exit 2
ICONT=/home/resources/icon-master/bin/icont; ICONX=/home/resources/icon-master/bin/iconx
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "⛔ GATE REFUSES (rc=2): scrip/runtime not built at $ROOT"; exit 2; }
[ -x "$ICONT" ] && [ -x "$ICONX" ] || { echo "⛔ GATE REFUSES (rc=2): Icon oracle missing at $ICONT / $ICONX"; exit 2; }
d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT
printf 'procedure main()\n  x := &null;\n  write(2 + x);\nend\n' > "$d/null_operand.icn"
printf 'procedure main()\n  x := "";\n  write(2 + x);\nend\n'    > "$d/empty_operand.icn"
graded=0; bad=0
for w in null_operand empty_operand; do
    "$ICONT" -s -o "$d/$w.ora" "$d/$w.icn" >/dev/null 2>&1 || { echo "⛔ GATE REFUSES (rc=2): icont rejected $w -- cannot measure"; exit 2; }
    want=$(timeout -k 5 20 "$ICONX" "$d/$w.ora" </dev/null 2>/dev/null); wrc=$?
    o=$(SCRIP_RTX_ICNNUM=0 timeout -k 5 20 ./scrip "$d/$w.icn" </dev/null 2>/dev/null); r=$?; graded=$((graded+1))
    if [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
        echo "  ⛔ RED control arm (asm OFF) $w: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|')] -- iconx rc=$wrc out=[$(printf '%s' "$want" | tr '\n' '|')]; the C path itself has regressed, which is a bigger defect than the one this row is about"; bad=1
    fi
    o=$(timeout -k 5 20 ./scrip "$d/$w.icn" </dev/null 2>/dev/null); r=$?; graded=$((graded+1))
    if [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
        echo "  ⛔ RED m3 $w (asm ON, the defect): rc=$r out=[$(printf '%s' "$o" | tr '\n' '|')] -- iconx rc=$wrc out=[$(printf '%s' "$want" | tr '\n' '|')]"; bad=1
    fi
    if timeout -k 5 120 ./scrip --compile -o "$d/$w.s" "$d/$w.icn" </dev/null >/dev/null 2>&1 \
       && gcc -m64 -no-pie "$d/$w.s" -o "$d/$w.m4" -L./out -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null; then
        o=$(timeout -k 5 20 "$d/$w.m4" </dev/null 2>/dev/null); r=$?; graded=$((graded+1))
        if [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
            echo "  ⛔ RED m4 $w (asm ON, the defect): rc=$r out=[$(printf '%s' "$o" | tr '\n' '|')] -- iconx rc=$wrc out=[$(printf '%s' "$want" | tr '\n' '|')]"; bad=1
        fi
        o=$(SCRIP_RTX_ICNNUM=0 timeout -k 5 20 "$d/$w.m4" </dev/null 2>/dev/null); r=$?; graded=$((graded+1))
        if [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
            echo "  ⛔ RED m4 control arm (asm OFF) $w: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|')] -- iconx rc=$wrc out=[$(printf '%s' "$want" | tr '\n' '|')]"; bad=1
        fi
    else
        graded=$((graded+2)); echo "  ⛔ RED m4 $w: does not compile/link"; bad=1
    fi
done
[ "$graded" = 8 ] || { echo "⛔ GATE REFUSES (rc=2): graded $graded of the 8 required runs"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED [icn_rtx_blank_operand_protocol]: the assembly fast path still coerces a blank operand to zero"; exit 1; }
echo "✅ GATE OK [icn_rtx_blank_operand_protocol]: a blank operand raises 102 with the assembly path on AND off, BOTH modes"
