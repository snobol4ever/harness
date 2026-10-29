#!/usr/bin/env bash
# util_runtime_leaf_census.sh -- THE LEAF CENSUS: where a program's instructions go, by LAYER, in one mode.
# HQ-RUNTIME's first row (Lon 2026-10-07, CEO-1534/1535): measure before converting a C leaf to asm.
#
# USAGE   util_runtime_leaf_census.sh PROGRAM --mode m3|m4 [--top N]
# PRINTS  LEAF_INPUT program=P stdin=NAME.in|NAME.stdin|NAME.dat|none   (what the run read on stdin, as the bench runners feed it)
#         LEAF_CENSUS program=P mode=M total_ir=N emitted=PCT asm_leaf=PCT c_runtime=PCT libc=PCT other=PCT
#         LEAF_OTHER compiler=PCT loader=PCT rest=PCT              (what `other` is made of, same denominator)
#         LEAF_C fn=NAME ir=INCLUSIVE pct=PCT self=SELF            (the C runtime, ranked by inclusive Ir; top N, default 40)
# EXIT    0 measured; 2 could not measure (no valgrind, stale binary, a program that does not compile or link, a run that
#         died under callgrind, a profile whose layers do not add up to its own total) -- a named reason, never a plausible zero.
#
# THE LAYERS (callgrind self cost of every (object, function), so the five sum to PROGRAM TOTALS exactly; the instrument
# checks that and refuses when they do not):
#   emitted    the program's own code: an anonymous object (the mode-3 slab, and the blobs either mode emits at run time --
#              hence --smc-check=all-non-file in BOTH modes) or the mode-4 executable itself.
#   libc       libc and libm.
#   asm_leaf   every function whose source file is a .s or .S under src/runtime -- each RTX_FUNC and RTX_ENTRY of rtx/*.s, and
#              the hand-written asm outside rtx/ (rt/rt_asm_helpers.S carries rt_gc_poll_asm: booking it as C would grade asm as C),
#              read from the debug info the Makefile assembles them with (-g), so a new leaf counts the day it lands, no list kept.
#   c_runtime  every other function built from SCRIP's own tree that is not the compiler.
#   other      the compiler, the dynamic loader, libstdc++ and the rest.
# ⛔ WHY THE COMPILER IS NOT c_runtime (measured 2026-10-07, SCRIP f5512845c): emit.cpp, x86_asm.h and the lowerers are linked
# INTO libscrip_rt.so, so "every other function of libscrip_rt.so" books a mode-3 run's compile time as C runtime. A function
# whose file sits under src/parsers, src/lower, src/optimizer, src/emitter, src/templates, src/driver or is a src/ir/*.c is the
# compiler, as is every function of the scrip binary itself outside src/runtime (a src/ir/ast.h inline the driver instantiates), and so is a function SCRIP's objects carry from no file under src/ (the std:: template instances); LEAF_OTHER says how
# much of `other` it is, so a mode-3 census is read with its compile cost in view rather than mistaken for a C-runtime share.
#
# INCLUSIVE Ir is self plus every call's cost, a function's calls to ITSELF left out (callgrind's call cost already contains
# them), and callgrind's recursion levels (fn'2) are not ranked apart from fn, whose cost already holds them; mutual recursion
# can still count a frame twice, which ranks rather than sums -- no LEAF_C line is added to another.
#
# THE RUN goes through lib_ir_measure.sh's ir_measure (the one authority for a reading: a run that died is voided, not counted),
# at the program's declared sizes (lib_declared_arena.sh: -d<kb>k -s<kb>k after --run in mode 3, at the head of the binary's argv
# in mode 4; compile args from its .cmdline sidecar), on a binary util_require_fresh.sh has passed. Mode 4 links the suite
# harness's way, PIE (SCRIP 27e4e3960, CEO-1536). LEAF_VG_FLAGS adds valgrind flags (say --main-stacksize=...); LEAF_TMO is
# the callgrind timeout in seconds (default 900); VALGRIND names the valgrind binary; LEAF_CG_OUT keeps the profile (for
# callgrind_annotate or KCachegrind) at that path.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; RT="$ROOT/out"
refuse() { echo "⛔ REFUSED (rc=2): util_runtime_leaf_census: $*"; exit 2; }

PROG=""; MODE=""; TOP=40
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2 ;;
    --mode=*) MODE="${1#--mode=}"; shift ;;
    --top) TOP="${2:-}"; shift 2 ;;
    --top=*) TOP="${1#--top=}"; shift ;;
    -*) refuse "unknown flag $1 (usage: util_runtime_leaf_census.sh PROGRAM --mode m3|m4 [--top N])" ;;
    *) [ -z "$PROG" ] || refuse "two programs named ($PROG, $1) -- the census reads one"; PROG="$1"; shift ;;
  esac
done
[ -n "$PROG" ] || refuse "no program named (usage: util_runtime_leaf_census.sh PROGRAM --mode m3|m4 [--top N])"
[ -f "$PROG" ] || refuse "$PROG does not exist"
case "$MODE" in m3|m4) ;; *) refuse "--mode must be m3 or m4, not '${MODE}'" ;; esac
case "$TOP" in ''|*[!0-9]*) refuse "--top must be a count, not '$TOP'" ;; esac
PROG="$(cd "$(dirname "$PROG")" && pwd)/$(basename "$PROG")"

. "$HERE/lib_ir_measure.sh" 2>/dev/null || refuse "cannot load lib_ir_measure.sh -- this instrument will not read Ir by hand"
. "$HERE/lib_declared_arena.sh" 2>/dev/null || refuse "cannot load lib_declared_arena.sh -- a run at undeclared sizes is not the program's run"
# A leaf census is a benchmark measurement: it runs with every diagnostic off unless the caller sets SCRIP_DIAG itself (Lon
# 2026-09-25, CEO-1262: "For benchmarks turn off diagnostics"); at the default the collector's self-checks (the trap ledger,
# the assert scan, the heap verify, the block index, the fix check) cost concord.icn 209 M of 549 M instructions and read as
# "C runtime" on the LEAF_SHARE line (hq_runtime 2026-10-17).
export SCRIP_DIAG="${SCRIP_DIAG:-0}"
ir_have_valgrind || refuse "valgrind is not installed (${VALGRIND:-valgrind} or callgrind_annotate not found) -- NOT MEASURED"
"$HERE/util_require_fresh.sh" --gate util_runtime_leaf_census "$SCRIP" "$RT/libscrip_rt.so" || exit 2

SW="$(declared_switches_beside "$PROG")" || refuse "$(basename "$PROG"): its .heap or .stack sidecar is refused (the reader said why above)"
CA="$(declared_compile_args_beside "$PROG")" || refuse "$(basename "$PROG"): its .cmdline sidecar is refused (the reader said why above)"
undeclared_beside_named "$PROG" || true
read -r -a SWA <<<"$SW"; read -r -a CAA <<<"$CA"
# THE INPUT the bench runners give the kernel (test_icon_bench_suite.sh stdin_of, test_pascal_bench_suite.sh): NAME.in, else
# NAME.stdin, else NAME.dat, else /dev/null -- a kernel that reads its input and is fed nothing measures a path that never did the work.
IN=/dev/null; for x in in stdin dat; do [ -f "${PROG%.*}.$x" ] && { IN="${PROG%.*}.$x"; break; }; done
echo "LEAF_INPUT program=$(basename "$PROG") stdin=$([ "$IN" = /dev/null ] && echo none || basename "$IN")"

W="$(mktemp -d "${TMPDIR:-/tmp}/leafcensus.XXXXXX")" || refuse "no scratch directory"
trap 'rm -rf "$W"' EXIT
EMIT_OB=""
if [ "$MODE" = m3 ]; then
  CMD=("$SCRIP" --run "${CAA[@]}" "${SWA[@]}" "$PROG")
else
  ( cd "$W" && "$SCRIP" --compile "${CAA[@]}" --out="$W/p.s" "$PROG" ) </dev/null >"$W/compile.out" 2>&1 && [ -s "$W/p.s" ] \
    || { tail -5 "$W/compile.out"; refuse "$(basename "$PROG") does not compile in mode 4"; }
  gcc "$W/p.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$W/p" >"$W/link.out" 2>&1 \
    || { tail -5 "$W/link.out"; refuse "$(basename "$PROG")'s mode-4 assembly does not link"; }
  EMIT_OB="$(readlink -f "$W/p")"
  CMD=("$W/p" "${SWA[@]}")
fi

IRV="$(cd "$W" && IR_OUT="$W/cg.out" IR_VG_FLAGS="--smc-check=all-non-file ${LEAF_VG_FLAGS:-}" IR_PROG_OUT="$W/prog.out" \
       IR_PROG_ERR="$W/vg.log" IR_TMO="${LEAF_TMO:-900}" ir_measure "${CMD[@]}" <"$IN")"
if ! ir_is_number "$IRV"; then
  tail -5 "$W/vg.log" 2>/dev/null
  refuse "$(basename "$PROG") $MODE: $(ir_cell "$IRV") -- $(ir_reason "$IRV")"
fi

[ -n "${LEAF_CG_OUT:-}" ] && cp "$W/cg.out" "$LEAF_CG_OUT"
awk -v total="$IRV" -v prog="$(basename "$PROG")" -v mode="$MODE" -v top="$TOP" -v emit_ob="$EMIT_OB" -v scrip_ob="$(readlink -f "$SCRIP")" -v src="$ROOT/src/" '
function name(ns, v,   id, rest, p) {
  if (v !~ /^\([0-9]+\)/) return v
  p = index(v, ")"); id = substr(v, 2, p - 2); rest = substr(v, p + 1); sub(/^ /, "", rest)
  if (rest != "") nm[ns, id] = rest
  return nm[ns, id]
}
function base(path,   n, a) { n = split(path, a, "/"); return a[n] }
function layer(ob, fl,   b, rel) {
  if (ob == "???" || (emit_ob != "" && ob == emit_ob)) return "emitted"
  b = base(ob)
  if (b ~ /^lib(c|m)([-.].*)?\.so/) return "libc"
  if (ob !~ /libscrip_rt[^\/]*\.so/ && ob != scrip_ob) return (b ~ /^ld-linux/ ? "loader" : "rest")
  if (index(fl, "./src/") == 1) fl = src substr(fl, 7)
  if (index(fl, src) != 1) return "compiler"
  rel = substr(fl, length(src) + 1)
  if (rel ~ /^runtime\/.*\.[sS]$/) return "asm_leaf"
  if (ob == scrip_ob && rel !~ /^runtime\//) return "compiler"
  if (rel ~ /^(parsers|lower|optimizer|emitter|templates|driver)\// || rel ~ /^ir\/[^\/]*\.c$/) return "compiler"
  return "c_runtime"
}
BEGIN { npos = 1 }
/^positions:/ { npos = NF - 1; next }
/^ob=/  { ob = name("ob", substr($0, 4)); next }
/^fl=/  { fl = name("fl", substr($0, 4)); next }
/^f[ie]=/ { name("fl", substr($0, 4)); next }
/^fn=/  { fn = name("fn", substr($0, 4)); key = ob SUBSEP fn; if (!(key in file)) { file[key] = fl; obj[key] = ob; fnm[key] = fn }; next }
/^cob=/ { cob = name("ob", substr($0, 5)); next }
/^cf[il]=/ { name("fl", substr($0, 5)); next }
/^cfn=/ { cfn = name("fn", substr($0, 5)); next }
/^calls=/ { incall = 1; next }
/^[0-9+*-]/ {
  c = (NF > npos) ? $(npos + 1) + 0 : 0
  if (incall) {
    tob = (cob == "") ? ob : cob
    if (!(tob == ob && cfn == fn)) callc[key] += c
    incall = 0; cob = ""
  } else self[key] += c
  next
}
END {
  for (k in self) { L = layer(obj[k], file[k]); lay[L] += self[k]; sum += self[k] }
  if (sum != total) { printf "MISMATCH %d %d\n", sum, total; exit 3 }
  oth = lay["compiler"] + lay["loader"] + lay["rest"]
  printf "LEAF_CENSUS program=%s mode=%s total_ir=%d emitted=%.2f asm_leaf=%.2f c_runtime=%.2f libc=%.2f other=%.2f\n", prog, mode, total,
         100*lay["emitted"]/total, 100*lay["asm_leaf"]/total, 100*lay["c_runtime"]/total, 100*lay["libc"]/total, 100*oth/total
  printf "LEAF_OTHER compiler=%.2f loader=%.2f rest=%.2f\n", 100*lay["compiler"]/total, 100*lay["loader"]/total, 100*lay["rest"]/total
  n = 0
  for (k in fnm) if (fnm[k] !~ /\047[0-9]+$/ && layer(obj[k], file[k]) == "c_runtime") { n++; ck[n] = k; inc[n] = self[k] + callc[k] }
  for (i = 2; i <= n; i++) { k = ck[i]; v = inc[i]; j = i - 1; while (j >= 1 && inc[j] < v) { ck[j+1] = ck[j]; inc[j+1] = inc[j]; j-- } ck[j+1] = k; inc[j+1] = v }
  for (i = 1; i <= n && i <= top; i++) { k = ck[i]; f = fnm[k]; gsub(/[ \t]/, "", f)
    printf "LEAF_C fn=%s ir=%d pct=%.2f self=%d\n", f, inc[i], 100*inc[i]/total, self[k] + 0 }
}' "$W/cg.out" >"$W/census.out"
arc=$?
if [ "$arc" -eq 3 ]; then refuse "the profile's layers add to $(awk '{print $2}' "$W/census.out") but its PROGRAM TOTALS read $(awk '{print $3}' "$W/census.out") -- the parse of callgrind's file is wrong, not the program"; fi
[ "$arc" -eq 0 ] || refuse "the census parse exited rc=$arc"
grep -q '^LEAF_CENSUS ' "$W/census.out" || refuse "the census printed no LEAF_CENSUS line"
cat "$W/census.out"
