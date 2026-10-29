#!/usr/bin/env bash
# test_gate_cas_island_grows_with_the_declared_stack.sh -- the conditional-assignment stack (the r12 CAS island) is sized by the
# program's declared -s stack budget, never a fixed 64 MB, and an overrun is a named ERROR 246, never a core dump.
# Row snobol4-the-deferred-capture-cells-are-a-fixed-4096-word-table-and-a-fixed-island-that-emitted-code-indexes (cfo mint,
# CEO-1507 (4)); cure 2026-10-11, hq_snobol4.
#
# THE DEFECT: rt_dcap_lazy_init took a fixed RT_DCAP_ISLAND_BYTES (64 MB) region with no guard after it. Each pending conditional
# capture is a 24-byte entry, so a match holding more than 2,796,202 of them ran off the end: SIGSEGV, core dumped, at any -s,
# where sbl -bf -s256m runs the same program to completion. sbl keeps a match's history on its own stack, so its limit is the
# -s the program declares and its overrun is ERROR 246; the island now follows the same budget (max(64 MB, -s), MAP_NORESERVE)
# with a PROT_NONE guard after it that the SIGSEGV handler reports as ERROR 246.
#
# THE WITNESS: 400,000 ARBNO iterations of eight one-character captures = 3,200,000 pending entries, 76.8 MB of CAS.
# arm 1 (-s256m): sbl prints the answer; both modes must print the same. Before the cure, SIGSEGV in both.
# arm 2 (-s64m):  sbl reports ERROR 246; both modes must report ERROR 246 and exit 1. Before the cure, SIGSEGV in both.
# Every ref is the oracle's, read at run time.
set -u
G=test_gate_cas_island_grows_with_the_declared_stack
HERE="$(cd "$(dirname "$0")" && pwd)"; SD="$HERE/../../SCRIP"; SCRIP="$SD/scrip"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2) [$G]: no scrip binary at $SCRIP -- build first (make)"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" "$SCRIP" "${RT_DIR:-$SD/out}/libscrip_rt.so" || exit 2
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "⛔ REFUSE(rc=2) [$G]: no correctness oracle ($SBL) -- the refs are cut from the oracle at run time, never typed"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/cas.sno" <<'EOF'
	S  =  DUPL('abcdefgh',400000)
	S  POS(0)  ARBNO(LEN(1) . A LEN(1) . B LEN(1) . C LEN(1) . D LEN(1) . E LEN(1) . F LEN(1) . G LEN(1) . H)  RPOS(0)	:F(BAD)
	OUTPUT  =  'ok ' SIZE(S) ' ' A H	:(END)
BAD	OUTPUT  =  'fail'
END
EOF
(cd "$W" && timeout -k 5 120 "$SCRIP" --compile --out=cas.s cas.sno </dev/null >/dev/null 2>&1) \
    && gcc -no-pie "$W/cas.s" -L"$SD/out" -lscrip_rt -lm -Wl,-rpath,"$SD/out" -o "$W/cas.bin" 2>/dev/null \
    || { echo "⛔ REFUSE(rc=2) [$G]: the witness did not compile and link in mode 4"; exit 2; }
fail=0
echo "== [$G] the CAS island follows the declared -s, graded against $SBL"
want="$(cd "$W" && timeout -k 5 120 "$SBL" $(sbl_lang_flags) -s256m -d1024m cas.sno </dev/null 2>/dev/null)"
[ "$want" = "ok 3200000 ah" ] || { echo "⛔ REFUSE(rc=2) [$G]: the oracle at -s256m printed '$want', not the witness's answer -- the arm cannot grade"; exit 2; }
m3="$(cd "$W" && timeout -k 5 120 "$SCRIP" -s256m cas.sno </dev/null 2>&1)"
m4="$(cd "$W" && timeout -k 5 120 "$W/cas.bin" -s256m -- </dev/null 2>&1)"
for m in m3 m4; do v="${!m}"; if [ "$v" = "$want" ]; then echo "  PASS arm1 $m -s256m = sbl ($want)"; else echo "  ⛔ arm1 $m -s256m RED: got '$v', sbl '$want'"; fail=1; fi; done
osay="$(cd "$W" && timeout -k 5 120 "$SBL" $(sbl_lang_flags) -s64m -d1024m cas.sno </dev/null 2>&1 | grep -o 'ERROR 246 -- stack overflow' | head -1)"
[ -n "$osay" ] || { echo "⛔ REFUSE(rc=2) [$G]: the oracle at -s64m did not report ERROR 246 -- the arm cannot grade"; exit 2; }
for m in m3 m4; do
    if [ "$m" = m3 ]; then out="$(cd "$W" && timeout -k 5 120 "$SCRIP" -s64m cas.sno </dev/null 2>&1)"; rc=$?; else out="$(cd "$W" && timeout -k 5 120 "$W/cas.bin" -s64m -- </dev/null 2>&1)"; rc=$?; fi
    if [ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q "$osay"; then echo "  PASS arm2 $m -s64m reports $osay (rc 1), as sbl does"; else echo "  ⛔ arm2 $m -s64m RED: rc=$rc, said: $(printf '%s' "$out" | head -c 200)"; fail=1; fi
done
[ "$fail" = 0 ] && { echo "OK [$G]: 3,200,000 pending captures run at -s256m and overrun at -s64m as ERROR 246, both modes, as sbl"; exit 0; }
echo "⛔ GATE RED [$G]: the CAS island does not follow the declared stack"; exit 1
