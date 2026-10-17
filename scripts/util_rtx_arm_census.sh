#!/usr/bin/env bash
# util_rtx_arm_census.sh — DID THE ASM ACTUALLY RUN, OR DID IT BAIL TO C?
#
# Minted s216 (2026-07-29) after RTX-8 slice 3 was written, built, verified
# output-identical, and then PROVED VACUOUS: rt_cap_push took 57,578 dynamic
# calls on json.sno+twitter.json, passed ARCH §7 step 0(d) cleanly (count
# scaled EXACTLY 2.00x on a structurally-doubled input, hottest unported symbol
# in its family), and yet its ported hot path NEVER EXECUTED ONCE — every call
# bailed to the C fallback on a cold arm.  A `ud2` planted on the commit path
# did not fire with the gate ON.
#
# THE GAP THIS CLOSES: step 0(d) counts entries to a SYMBOL.  A gated RTX port
# is a symbol with two or more arms, and the asm covers only the arm(s) the
# author chose.  So 0(d) can pass in full while the ported arm is dead — s215's
# "a call count cannot name an arm" one level down, where the count is dynamic
# and correct and STILL does not license the port.
#
# THE MEASUREMENT: every gated RTX symbol tail-jumps to a `c_*` fallback when it
# refuses an arm (the RTX_GATE / bail-before-mutate shape).  So counting BOTH
# `sym` and `c_sym` splits the traffic mechanically:
#     entries  = calls that reached the asm symbol
#     bailed   = calls that tail-jumped to the C fallback
#     commits  = entries - bailed  = calls the ASM ACTUALLY HANDLED END TO END
# commits == 0 means the port is unfalsifiable on this workload: do not write
# the asm, and do not grade it here.  Run this BEFORE the asm, on the workload
# the rung will be graded on, and again after.
#
# The symbol list is DERIVED FROM THE TREE on every run (RTX_FUNC names in
# src/runtime/rtx/*.s, intersected with the .so's dynamic table), never
# hand-maintained — a checked-in list is the doc-rot class this ladder has paid
# for six times (ARCH §7 step 0, the phantom family).
#
# Usage: bash ../harness/scripts/util_rtx_arm_census.sh <prog.sno> [m3|m4|both] [< input]
#        SCRIP_RTX_<FAM> env vars pass through, so ON/OFF arms are comparable.
#        MODE defaults to m3 (--run) to preserve existing behaviour.
#        m4 compiles prog.sno via scrip --compile, links against libscrip_rt.so,
#        then runs the resulting binary under LD_PRELOAD — same interposer, same
#        symbol set, different runner.  The m4 arm catches the exported/hidden
#        data-symbol class that m3 is structurally blind to (ARCH §7 step 0(c)).
#        Added s_this (2026-08-08) — gap called out in GOAL-SNOBOL4-RTX.md ladder.
set -u
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
SO="$ROOT/out/libscrip_rt.so"
# ⛔ THE .so MUST BE CURRENT OR THIS VERDICT IS ABOUT A BUILD NOBODY SHIPS (row stale-binary-preflight-also-
# covers-out-libscrip_rt-so). A stale OLDER .so still exports what src/ deleted and cannot show what src/
# added, so a clean nm surface here is a FALSE GREEN. Shared authority -- sourced, never copied.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_build_currency.sh"
assert_so_current "$SO" "$ROOT" || exit 2
RT_DIR="$ROOT/out"
PROG="${1:?usage: util_rtx_arm_census.sh <prog.sno> [m3|m4|both]}"
MODE="${2:-m3}"
case "$MODE" in m3|m4|both) ;; *) echo "FATAL: MODE must be m3|m4|both (got '$MODE')"; exit 1; esac
[ -f "$SO" ] || { echo "FATAL: $SO missing — run make libscrip_rt first"; exit 1; }
# THE INTERPOSABLE RUNTIME (cto 2026-10-15, CEO-1795): the shipped runtime binds its own functions (RT_BIND in the Makefile), so a
# preloaded definition no longer reaches a call made inside it or a mode-3 call through an address it took. The interposer runs
# against out/interposable/libscrip_rt.so, the same objects with every symbol preemptible, which LD_LIBRARY_PATH puts ahead of RUNPATH.
make -s -C "$ROOT" out/interposable/libscrip_rt.so > /dev/null || { echo "FATAL: out/interposable/libscrip_rt.so did not link"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "FATAL: $ROOT/scrip missing"; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
compile_m4() {
  local sno="$1" out="$2" tmp; tmp="$(mktemp -d)"
  "$ROOT/scrip" --compile "$sno" > "$tmp/p.s" 2>/dev/null < /dev/null || { rm -rf "$tmp"; return 1; }
  ( cd "$ROOT" && gcc -c "$tmp/p.s" -o "$tmp/p.o" 2>/dev/null ) || { rm -rf "$tmp"; return 1; }
  gcc "$tmp/p.o" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$out" 2>/dev/null || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}
# Derive the symbol set from the tree, then keep only what the .so really exports.
nm -D --defined-only "$SO" | awk '$2=="T"{print $3}' | sort -u > "$TMP/dyn.txt"
grep -rhoP 'RTX_FUNC\(\s*\K[A-Za-z0-9_]+' "$ROOT"/src/runtime/rtx/*.s | sort -u > "$TMP/asm.txt"
: > "$TMP/syms.txt"
while read -r s; do
  grep -qx "$s" "$TMP/dyn.txt" || continue
  echo "$s" >> "$TMP/syms.txt"
  grep -qx "c_$s" "$TMP/dyn.txt" && echo "c_$s" >> "$TMP/syms.txt"
done < "$TMP/asm.txt"
[ -s "$TMP/syms.txt" ] || { echo "FATAL: derived zero symbols — did RTX_FUNC or the .so layout change?"; exit 1; }
# Emit the interposer.  Counters are HIDDEN so `inc [rip+cnt]` is legal in a .so
# (an exported data symbol needs @GOTPCREL — ARCH §7 step 0(c), which bit this
# very tool during its own construction).  The thunk is `inc` + `jmp *ptr`: it
# clobbers only EFLAGS, never an argument register, so it forwards ANY signature
# without knowing it.  Arming is conditional on libscrip_rt.so being present in
# THIS process, because scrip's run spawns a second process that has no runtime
# loaded and whose destructor would otherwise overwrite the census with zeros.
{
  echo '#define _GNU_SOURCE'
  echo '#include <dlfcn.h>'
  echo '#include <stdio.h>'
  echo '#include <stdlib.h>'
  printf '#define SYMS'
  while read -r s; do printf ' X(%s)' "$s"; done < "$TMP/syms.txt"
  echo
  echo '#define HID __attribute__((visibility("hidden")))'
  echo '#define X(n) HID unsigned long cnt_##n = 0; HID void *real_##n = 0;'
  echo 'SYMS'
  echo '#undef X'
  echo '#define X(n) __asm__(".text\n.intel_syntax noprefix\n.globl " #n "\n.type " #n ",@function\n" #n ":\n inc qword ptr [rip+cnt_" #n "]\n jmp qword ptr [rip+real_" #n "]\n.att_syntax\n.previous\n");'
  echo 'SYMS'
  echo '#undef X'
  echo 'static int armed = 0;'
  echo '__attribute__((constructor)) static void ac_init(void) { if (!dlopen("libscrip_rt.so", RTLD_NOW | RTLD_NOLOAD)) return; armed = 1;'
  echo '#define X(n) real_##n = dlsym(RTLD_NEXT, #n); if (!real_##n) fprintf(stderr, "ARMCENSUS UNRESOLVED: %s\n", #n);'
  echo 'SYMS'
  echo '#undef X'
  echo '}'
  echo '__attribute__((destructor)) static void ac_fini(void) { if (!armed) return; unsigned long t = 0;'
  echo '#define X(n) t += cnt_##n;'
  echo 'SYMS'
  echo '#undef X'
  echo '  if (!t) return; const char *p = getenv("ARMCENSUS_OUT"); FILE *f = fopen(p ? p : "/tmp/armcensus.txt", "w"); if (!f) return;'
  echo '#define X(n) fprintf(f, "%s %lu\n", #n, cnt_##n);'
  echo 'SYMS'
  echo '#undef X'
  echo '  fclose(f); }'
} > "$TMP/ac.c"
gcc -O0 -shared -fPIC -o "$TMP/ac.so" "$TMP/ac.c" -ldl || { echo "FATAL: interposer build failed"; exit 1; }
print_table() {
  local outfile="$1" rc="$2" label="$3"
  echo "=== RTX ARM CENSUS — $PROG [$label] (rc=$rc) ==="
  printf "%-34s %10s %10s %10s  %s\n" SYMBOL ENTRIES BAILED_C COMMITS VERDICT
  while read -r s; do
    case "$s" in c_*) continue ;; esac
    e=$(awk -v k="$s" '$1==k{print $2}' "$outfile"); e=${e:-0}
    b=$(awk -v k="c_$s" '$1==k{print $2}' "$outfile"); b=${b:-0}
    [ "$e" = 0 ] && continue
    c=$((e - b))
    if [ "$c" -le 0 ]; then v="VACUOUS HERE — asm never commits"
    elif [ "$b" -gt "$c" ]; then v="MOSTLY BAILS — cold arm dominates"
    else v="asm handles $c"; fi
    printf "%-34s %10s %10s %10s  %s\n" "$s" "$e" "$b" "$c" "$v"
  done < "$TMP/syms.txt"
  echo "(symbols with zero entries are omitted: this workload cannot grade them at all)"
}
if [ "$MODE" = m3 ] || [ "$MODE" = both ]; then
  ARMCENSUS_OUT="$TMP/out3.txt" LD_LIBRARY_PATH="$ROOT/out/interposable" LD_PRELOAD="$TMP/ac.so" \
    "$ROOT/scrip" --run "$PROG" > "$TMP/prog3.out" 2>"$TMP/prog3.err"
  RC3=$?
  if [ -s "$TMP/out3.txt" ]; then
    print_table "$TMP/out3.txt" "$RC3" "m3 --run"
  else
    echo "NO DATA [m3 --run] (rc=$RC3) — the program produced no census output.  Check that it runs at all."
  fi
fi
if [ "$MODE" = m4 ] || [ "$MODE" = both ]; then
  BIN="$TMP/prog.bin"
  if compile_m4 "$PROG" "$BIN"; then
    ARMCENSUS_OUT="$TMP/out4.txt" LD_LIBRARY_PATH="$ROOT/out/interposable" LD_PRELOAD="$TMP/ac.so" \
      "$BIN" > "$TMP/prog4.out" 2>"$TMP/prog4.err"
    RC4=$?
    if [ -s "$TMP/out4.txt" ]; then
      print_table "$TMP/out4.txt" "$RC4" "m4 --compile"
    else
      echo "NO DATA [m4 --compile] (rc=$RC4) — compiled binary produced no census output."
    fi
  else
    echo "SKIP [m4 --compile] — $PROG did not compile/link."
  fi
fi
