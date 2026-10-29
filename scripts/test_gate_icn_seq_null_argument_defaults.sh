#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_seq_null_argument_defaults.sh -- seq()'s OMITTED and &null arguments take the DEFAULT
# (hq_I 2026-09-09, under CEO-445; witness cut from rung36_jcon_misc, which reported 0/4/8 where icont
# reports 1/5/9). In Icon an omitted argument IS &null and a null argument takes the parameter default:
# seq(,4) and seq(&null,4) both mean seq(1,4). lower_seq() honoured the default only for a MISSING
# argument -- nargs==0 -- so `seq(,4)` arrived as (TT_VAR &null) with nargs==2, lowered to the integer 0,
# and the sequence started one low. `seq(10,)` was worse: a null STEP made icn_const_step refuse, the
# lowering fell through to a generic call, and the program died ERROR 022 "Undefined function called".
#
# ⭐ THE SHAPE WORTH KEEPING: "argument absent" and "argument present and null" are the SAME thing to Icon
# and two different code paths here, and only one of them had the default. A defaulting rule keyed on
# ARITY rather than on VALUE is correct for every call that omits trailing arguments and wrong for every
# call that omits an interior one -- which is exactly the call a comma makes visible.
#
# ⛔ REFUSES rc=2 rather than skipping: no scrip, no RT, no icont/iconx, or zero forms graded. Both modes,
# graded against a FRESH icont cut of the SAME source -- never against a stored ref. Since the CEO-1393 oracle swap
# (2026-10-01) icont requires semicolons and reads a newline as whitespace, as SCRIP does, so the one witness carries
# them for both engines; the sed that derived SCRIP's copy from a semicolon-free oracle copy is retired with the swap.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SD="$HERE/../../SCRIP"
SCRIP="$SD/scrip"; RT_DIR="$SD/out"
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; ICONX="${ICONX_BIN:-/home/resources/icon-master/bin/iconx}"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null && { _t="$(icont_bin 2>/dev/null || true)"; [ -n "$_t" ] && [ -x "$_t" ] && ICONT="$_t"; _x="$(iconx_bin 2>/dev/null || true)"; [ -n "$_x" ] && [ -x "$_x" ] && ICONX="$_x"; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2): no scrip binary at $SCRIP"; exit 2; }
[ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ REFUSE(rc=2): no $RT_DIR/libscrip_rt.so"; exit 2; }
[ -x "$ICONT" ] && [ -x "$ICONX" ] || { echo "⛔ REFUSE(rc=2): no icont/iconx -- a missing oracle prints a plausible all-FAIL table, it does not blank one"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/s.icn" <<'EOF'
procedure main()
   every write("A:", seq(,4) \ 3);
   every write("B:", seq(10,) \ 3);
   every write("C:", seq(,) \ 3);
   every write("D:", seq(&null, 4) \ 3);
   every write("E:", seq(3, -2) \ 3);
   every write("F:", seq() \ 3);
   every write("G:", seq(4) \ 3);
end
EOF
( cd "$W" && "$ICONT" -s -o o.ico s.icn >/dev/null 2>&1 ) || { echo "⛔ REFUSE(rc=2): the oracle would not compile its own witness"; exit 2; }
ora="$( cd "$W" && timeout -k 5 20s "$ICONX" ./o.ico < /dev/null 2>&1 )"
[ -n "$ora" ] || { echo "⛔ REFUSE(rc=2): the oracle produced no output -- nothing to grade against"; exit 2; }
forms=$(printf '%s\n' "$ora" | grep -c '^[A-G]:') || true
[ "${forms:-0}" -ge 7 ] || { echo "⛔ REFUSE(rc=2): oracle emitted $forms graded lines, want at least 7"; exit 2; }
m3="$( cd "$W" && timeout -k 5 20s "$SCRIP" s.icn < /dev/null 2>&1 )"; r3=$?
if ( cd "$W" && timeout -k 5 30s "$SCRIP" --compile --out=s.s s.icn >/dev/null 2>&1 ) \
   && ( cd "$W" && gcc -no-pie s.s -o s.bin -L"$RT_DIR" -Wl,-rpath,"$RT_DIR" -lscrip_rt -lm -lpthread >/dev/null 2>&1 ); then
     m4="$( cd "$W" && timeout -k 5 20s ./s.bin < /dev/null 2>&1 )"; r4=$?
else m4="<compile/link failed>"; r4=99; fi
P=0; F=0; BAD=""
[ "$m3" = "$ora" ] && P=$((P+1)) || { F=$((F+1)); BAD="$BAD m3(rc=$r3)"; }
[ "$m4" = "$ora" ] && P=$((P+1)) || { F=$((F+1)); BAD="$BAD m4(rc=$r4)"; }
echo "test_gate_icn_seq_null_argument_defaults: PASS=$P FAIL=$F of 2 modes over $forms seq forms, graded against $ICONT/$ICONX"
if [ "$F" -ne 0 ]; then
    echo "RED:$BAD"; echo "--- oracle ---"; printf '%s\n' "$ora"; echo "--- m3 ---"; printf '%s\n' "$m3"; echo "--- m4 ---"; printf '%s\n' "$m4"; exit 1
fi
echo "✅ seq() omitted and &null arguments take the default in both modes"
exit 0
