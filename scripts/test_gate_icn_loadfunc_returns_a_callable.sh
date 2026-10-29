#!/usr/bin/env bash
# test_gate_icn_loadfunc_returns_a_callable.sh — loadfunc() RESOLVES A SYMBOL AND RETURNS SOMETHING YOU CAN CALL.
#
# THE DEFECT THIS PINS (hq_S 2026-09-10, row icon-loadfunc-exits-1-with-no-output-master-procedure-write-254,
# CEO-476).  by_name_dispatch.c's loadfunc arm dlopen'd the library, resolved the symbol with dlsym, and then
# set `*out = FAILDESCR` UNCONDITIONALLY — on the success path too.  So loadfunc could never return a callable
# and f(x) could never work.
#
# ⛔⭐ WHY IT NEEDED A GATE OF ITS OWN, AND IT IS THE WHOLE REASON THIS FILE EXISTS: the defect was INVISIBLE.
# No .so in the corpus could be dlopen'd at all (the one rung suite consumer, procedure_write_254, loads the
# COMBINED ipl/cfuncs library, which is a plug-in against the iconx interpreter's own C runtime and needs 12
# symbols iconx exports from its -rdynamic link), so every call site died at ERROR 216 BEFORE reaching the
# stub — and the raise-216 arm is indistinguishable from a working implementation to every test the tree
# owned.  A stub that can only be reached through a door that is always shut reads exactly like a cure.
# This gate opens the door: it BUILDS ITS OWN self-contained .so at run time, so it needs no vendored binary
# and no permission-gated symbol, and it exercises the marshalling surface a real plug-in uses.
#
# THE STANDING NEGATIVE CONTROL IS ARM N and it is load-bearing: a cure that returns a callable must STILL
# raise 216 when dlopen genuinely fails, or `ladder_rung41_rt_loadfunc_refusal` in the Icon rungs goes red.
#
# EXPECTATIONS ARE PINNED FROM icont/iconx 9.5.25a, cut live 2026-09-10 by hq_S; the gate does not need the
# oracle at run time (it needs gcc and icall.h) and REFUSES rc=2 rather than measuring nothing.
# AUTHORS: Lon Jones Cherryholmes · Jeffrey Cooper M.D. · Claude Opus 5   DATE: 2026-09-10
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../SCRIP" && pwd)"
SCRIP="${ROOT}/scrip"
ICALL="${ICALL_H:-/home/resources/icon-master/ipl/cfuncs/icall.h}"
[ -x "${SCRIP}" ]      || { echo "GATE REFUSE(2): ${SCRIP} is not built — cannot measure."; exit 2; }
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSE(2): no gcc — this gate compiles its own plug-in and cannot measure without one."; exit 2; }
[ -r "${ICALL}" ]      || { echo "GATE REFUSE(2): ${ICALL} unreadable — the iconx C-function ABI header is the gate's subject; cannot measure."; exit 2; }
. "${HERE}/lib_gate.sh"
gate_require_fresh "${ROOT}" src "${SCRIP}" "${ROOT}/out/libscrip_rt.so"
T="$(mktemp -d)" || { echo "GATE REFUSE(2): no temp dir — cannot measure."; exit 2; }
trap 'rm -rf "${T}"' EXIT
cat > "${T}/plug.c" <<'CEOF'
#include <string.h>
#include "icall.h"
int tf_int(int argc, descriptor *argv)  { ArgInteger(1); RetInteger(IntegerVal(argv[1]) * 2); }
int tf_real(int argc, descriptor *argv) { ArgReal(1); RetReal(getdbl(&argv[1]) / 2.0); }
int tf_str(int argc, descriptor *argv)  { ArgString(1); RetString(StringAddr(argv[1])); }
int tf_cstr(int argc, descriptor *argv) { ArgString(1); { char *p = StringVal(argv[1]); RetConstString(p); } }
int tf_null(int argc, descriptor *argv) { (void)argc; (void)argv; RetNull(); }
int tf_fail(int argc, descriptor *argv) { (void)argc; (void)argv; Fail; }
CEOF
gcc -shared -fPIC -I"$(dirname "${ICALL}")" -o "${T}/plug.so" "${T}/plug.c" 2>"${T}/cc.err" || {
    echo "GATE REFUSE(2): could not build the test plug-in — cannot measure."; sed -n '1,5p' "${T}/cc.err"; exit 2; }
UNDEF="$(nm -D --undefined-only "${T}/plug.so" 2>/dev/null | awk '{print $2}' | grep -vE '@GLIBC|^_ITM|^__gmon|^__cxa' | tr '\n' ' ')"
cat > "${T}/w.icn" <<EOF
procedure main()
   local d;
   d := "${T}/plug.so";
   write("int  :", loadfunc(d,"tf_int")(21));
   write("real :", loadfunc(d,"tf_real")(7.0));
   write("str  :", loadfunc(d,"tf_str")("hello"));
   write("cstr :", loadfunc(d,"tf_cstr")("world"));
   write("null :", image(loadfunc(d,"tf_null")()));
   write("fail :", image(loadfunc(d,"tf_fail")()) | "FAILED");
   write("img  :", image(loadfunc(d,"tf_int")));
   write("type :", type(loadfunc(d,"tf_int")));
   write("coerce:", loadfunc(d,"tf_int")("16"));
   write("clash :", image(loadfunc(d,"tf_int")));
   write("proc  :", image(tf_int));
   write("end");
end
procedure tf_int(a)
   return "stub";
end
EOF
cat > "${T}/w.ref" <<'EOF'
int  :42
real :3.5
str  :hello
cstr :world
null :&null
fail :FAILED
img  :function tf_int
type :procedure
coerce:32
clash :function tf_int
proc  :procedure tf_int
end
EOF
cat > "${T}/n.icn" <<'EOF'
procedure main()
   write("before");
   write(loadfunc("/no/such/lib.so","nope"));
   write("after");
end
EOF
echo "=== loadfunc returns a callable — Icon C-function ABI marshalling gate ==="
echo "plug-in undefined iconx symbols: ${UNDEF:-<none>}"
PASS=0; FAIL=0
grade() { # grade <label> <expected-file> <actual-file>
    if cmp -s "$2" "$3"; then echo "  PASS  $1"; PASS=$((PASS+1));
    else echo "  FAIL  $1"; diff "$2" "$3" | sed -n '1,8p' | sed 's/^/        /'; FAIL=$((FAIL+1)); fi
}
( cd "${T}" && timeout -k 5 30 "${SCRIP}" w.icn </dev/null >w.m3 2>&1 ); grade "m3 marshalling (12 arms: int real str cstr null fail image type coercion, NAME CLASH both ways)" "${T}/w.ref" "${T}/w.m3"
if ( cd "${T}" && timeout -k 5 60 "${SCRIP}" --compile --out=w.s w.icn </dev/null >/dev/null 2>&1 ) \
   && gcc -no-pie "${T}/w.s" -L"${ROOT}/out" -lscrip_rt -Wl,-rpath,"${ROOT}/out" -o "${T}/w.m4b" >/dev/null 2>&1; then
    ( cd "${T}" && timeout -k 5 30 ./w.m4b </dev/null >w.m4 2>&1 ); grade "m4 marshalling (same 12 arms)" "${T}/w.ref" "${T}/w.m4"
else
    echo "  FAIL  m4 marshalling — could not compile or link the witness"; FAIL=$((FAIL+1))
fi
( cd "${T}" && timeout -k 5 30 "${SCRIP}" n.icn </dev/null >n.out 2>&1 ); NRC=$?
# ⛔⭐ MATCH THE ERROR NUMBER AND ITS TEXT, NEVER ONE SPELLING OF THE REPORT. This arm was first written
# grep -q 'ERROR 216' and went RED FLEET-WIDE (it is in make test) the moment the fatal-report identity
# leak was cured and Icon errors began printing icont's own shape, "Run-time error 216 / File / Line",
# instead of "(0) : ERROR 216 -- ...". Nothing about loadfunc had changed; the gate was pinned to a
# diagnostic FORMAT rather than to the behaviour it exists to check, so an IMPROVEMENT to the report
# read as a regression in the feature. Caught by hq_I, who reproduced it on clean origin before naming it.
if grep -qE '(^|[^0-9])216([^0-9]|$)' "${T}/n.out" && grep -qi 'external function not found' "${T}/n.out" && [ "${NRC}" -ne 0 ]; then
    echo "  PASS  N negative control — a genuine dlopen failure still raises ERROR 216 (rc=${NRC})"; PASS=$((PASS+1))
else
    echo "  FAIL  N negative control — expected ERROR 216 and a non-zero rc, got rc=${NRC}:"; sed -n '1,5p' "${T}/n.out" | sed 's/^/        /'; FAIL=$((FAIL+1))
fi
echo "--- ${PASS} passed, ${FAIL} failed, denominator $((PASS+FAIL)) ---"
[ $((PASS+FAIL)) -gt 0 ] || { echo "GATE REFUSE(2): graded zero arms — cannot measure."; exit 2; }
[ "${FAIL}" -eq 0 ] || { echo "GATE FAIL(1): loadfunc does not return a working callable."; exit 1; }
echo "GATE OK"
