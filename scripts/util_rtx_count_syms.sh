#!/usr/bin/env bash
# util_rtx_count_syms.sh — DYNAMIC CALL COUNT FOR *ARBITRARY* SYMBOLS, PRE-PORT.
#
# Minted s217 (2026-07-29).  Closes the scope gap named in GOAL-SNOBOL4-RTX.md:
# util_rtx_arm_census.sh derives its symbol list from RTX_FUNC(...) names in
# src/runtime/rtx/*.s, so it can only see symbols that are ALREADY ported — it
# is the POST-port confirmation.  ARCH §7 step 0(d) has to run BEFORE any asm is
# written, on a symbol that is still pure C and therefore invisible to that
# tool.  This script takes the symbol names on the command line instead of
# deriving them, so it works at any stage.
#
# It answers 0(d) ONLY (entries to a symbol, and whether the count SCALES).  It
# CANNOT answer 0(f) pre-port: with no c_* fallback in the tree yet there is no
# bail edge to count, so a symbol with cold arms still reads as pure entries.
# 0(f) pre-port remains a source-reading obligation — read the C body and prove
# the arms, then confirm with util_rtx_arm_census.sh after the port lands.
#
# FIXED s221 (2026-07-29) — THE rc=139 SEGFAULT ON rt_dcap_lazy_init.  Root cause
# was NOT "an invalid RTLD_NEXT resolution" as the ladder guessed: resolution had
# not happened AT ALL yet.  glibc initialises libscrip_rt.so (a DT_NEEDED of
# scrip) BEFORE it runs an LD_PRELOAD object's constructor, so a symbol called
# during the runtime's own init reaches this thunk while real_<sym> is still 0 and
# `jmp qword ptr [rip+real_<sym>]` jumps to address 0.  Proof: a diagnostic build
# whose constructor printed on entry produced NO output before the crash.  The
# fix is lazy self-resolution IN the thunk (test real_, resolve on first call,
# then forward), preserving the full SysV argument set — the 6 integer arg regs,
# rax (varargs count), r10 (static chain), r11, and xmm0-7 — so it still forwards
# ANY signature without knowing it.  Push count is ODD by design (9) so rsp is
# 16-byte aligned at the `call`.  The constructor is RETAINED as a fast path for
# symbols that are not called that early; the EARLY-INIT column reports which
# symbols resolved lazily, so a future session sees WHY a symbol was special
# instead of rediscovering it.  A symbol with no downstream definition now aborts
# LOUDLY rather than jumping to NULL.
#
# Machinery is lifted verbatim from util_rtx_arm_census.sh (s216) so its three
# hard-won defect fixes are inherited rather than re-earned:
#   * counters are visibility("hidden") => `inc [rip+cnt]` is legal inside a .so
#     (an exported data symbol would need @GOTPCREL — ARCH §7 step 0(c))
#   * the thunk is `inc` + `jmp *ptr`: clobbers EFLAGS only, never an argument
#     register, so it forwards ANY signature without knowing it
#   * arming is conditional on libscrip_rt.so being loaded in THIS process,
#     because scrip's run spawns a second process with no runtime whose
#     destructor would otherwise overwrite the census with zeros
#
# Usage: bash ../harness/scripts/util_rtx_count_syms.sh <prog.sno> <sym> [sym...]
#        SCRIP_RTX_<FAM> env vars pass through.
#        COUNTSYMS_IN=<file> feeds the program's stdin (default /dev/null).
#
# ⛔ THE STDIN REDIRECT IS LOAD-BEARING (added s221, after a 500 s timeout).  As
# minted this line had NO redirect at all, so scrip inherited the caller's stdin.
# On any program that slurps stdin via plain INPUT -- json.sno is the one in the
# tree, and its own line 262 says raw mode "never signals EOF under scrip, so it
# spins forever" -- the measurement HANGS instead of failing, which reads as "the
# tool is slow" rather than "the tool is wrong".  RULES.md line 80 already
# mandated `< /dev/null` on scrip calls; this is the same defect the s220
# kill-switch gate had, inverted (there stdin leaked IN and swallowed a find
# list; here its absence hung the run).  Default is /dev/null per that rule, and
# COUNTSYMS_IN is the explicit opt-in for the stdin-driven case -- 0(d) on
# json.sno genuinely needs `COUNTSYMS_IN=twitter.json`, so a blanket redirect
# would have removed a measurement the ladder depends on.
set -u
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
SO="$ROOT/out/libscrip_rt.so"
# ⛔ THE .so MUST BE CURRENT OR THIS VERDICT IS ABOUT A BUILD NOBODY SHIPS (row stale-binary-preflight-also-
# covers-out-libscrip_rt-so). A stale OLDER .so still exports what src/ deleted and cannot show what src/
# added, so a clean nm surface here is a FALSE GREEN. Shared authority -- sourced, never copied.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_build_currency.sh"
assert_so_current "$SO" "$ROOT" || exit 2
PROG="${1:?usage: util_rtx_count_syms.sh <prog.sno> <sym> [sym...]}"; shift
[ $# -ge 1 ] || { echo "FATAL: name at least one symbol"; exit 1; }
[ -f "$SO" ] || { echo "FATAL: $SO missing — run make libscrip_rt first"; exit 1; }
# THE INTERPOSABLE RUNTIME (cto 2026-10-15, CEO-1795): the shipped runtime binds its own functions (RT_BIND in the Makefile), so a
# preloaded definition no longer reaches a call made inside it or a mode-3 call through an address it took. The interposer runs
# against out/interposable/libscrip_rt.so, the same objects with every symbol preemptible, which LD_LIBRARY_PATH puts ahead of RUNPATH.
make -s -C "$ROOT" out/interposable/libscrip_rt.so > /dev/null || { echo "FATAL: out/interposable/libscrip_rt.so did not link"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "FATAL: $ROOT/scrip missing"; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# Keep only symbols the .so actually exports as text; a typo must FAIL LOUDLY
# rather than silently report zero (the phantom-family failure mode).
nm -D --defined-only "$SO" | awk '$2=="T"{print $3}' | sort -u > "$TMP/dyn.txt"
: > "$TMP/syms.txt"
for s in "$@"; do
  if grep -qx "$s" "$TMP/dyn.txt"; then echo "$s" >> "$TMP/syms.txt"
  else echo "FATAL: '$s' is not an exported text symbol of libscrip_rt.so — check the spelling against the tree (ARCH §7 step 0b)"; exit 1; fi
done
{
  echo '#define _GNU_SOURCE'
  echo '#include <dlfcn.h>'
  echo '#include <stdio.h>'
  echo '#include <stdlib.h>'
  printf '#define SYMS'
  while read -r s; do printf ' X(%s)' "$s"; done < "$TMP/syms.txt"
  echo
  echo '#define HID __attribute__((visibility("hidden")))'
  echo '#define X(n) HID unsigned long cnt_##n = 0; HID unsigned long lazy_##n = 0; HID void *real_##n = 0;'
  echo 'SYMS'
  echo '#undef X'
  echo 'HID void *cs_resolve_one(const char *nm) { void *p = dlsym(RTLD_NEXT, nm); if (!p) { fprintf(stderr, "COUNTSYMS UNRESOLVED: %s — the thunk is exported but no downstream definition exists; refusing to jump to NULL\n", nm); abort(); } return p; }'
  echo '#define X(n) __asm__(".pushsection .rodata\n.Lnm_" #n ": .asciz \"" #n "\"\n.popsection\n.text\n.intel_syntax noprefix\n.globl " #n "\n.type " #n ",@function\n" #n ":\n inc qword ptr [rip+cnt_" #n "]\n cmp qword ptr [rip+real_" #n "], 0\n jne .Lfwd_" #n "\n inc qword ptr [rip+lazy_" #n "]\n push rdi\n push rsi\n push rdx\n push rcx\n push r8\n push r9\n push rax\n push r10\n push r11\n sub rsp, 128\n movups [rsp], xmm0\n movups [rsp+16], xmm1\n movups [rsp+32], xmm2\n movups [rsp+48], xmm3\n movups [rsp+64], xmm4\n movups [rsp+80], xmm5\n movups [rsp+96], xmm6\n movups [rsp+112], xmm7\n lea rdi, [rip+.Lnm_" #n "]\n call cs_resolve_one\n mov qword ptr [rip+real_" #n "], rax\n movups xmm0, [rsp]\n movups xmm1, [rsp+16]\n movups xmm2, [rsp+32]\n movups xmm3, [rsp+48]\n movups xmm4, [rsp+64]\n movups xmm5, [rsp+80]\n movups xmm6, [rsp+96]\n movups xmm7, [rsp+112]\n add rsp, 128\n pop r11\n pop r10\n pop rax\n pop r9\n pop r8\n pop rcx\n pop rdx\n pop rsi\n pop rdi\n.Lfwd_" #n ":\n jmp qword ptr [rip+real_" #n "]\n.att_syntax\n.previous\n");'
  echo 'SYMS'
  echo '#undef X'
  echo '__attribute__((constructor)) static void cs_init(void) { if (!dlopen("libscrip_rt.so", RTLD_NOW | RTLD_NOLOAD)) return;'
  echo '#define X(n) if (!real_##n) real_##n = dlsym(RTLD_NEXT, #n);'
  echo 'SYMS'
  echo '#undef X'
  echo '}'
  echo '__attribute__((destructor)) static void cs_fini(void) { unsigned long t = 0;'
  echo '#define X(n) t += cnt_##n;'
  echo 'SYMS'
  echo '#undef X'
  echo '  if (!t) return; const char *p = getenv("COUNTSYMS_OUT"); FILE *f = fopen(p ? p : "/tmp/countsyms.txt", "w"); if (!f) return;'
  echo '#define X(n) fprintf(f, "%s %lu %lu\n", #n, cnt_##n, lazy_##n);'
  echo 'SYMS'
  echo '#undef X'
  echo '  fclose(f); }'
} > "$TMP/cs.c"
gcc -O0 -shared -fPIC -o "$TMP/cs.so" "$TMP/cs.c" -ldl || { echo "FATAL: interposer build failed"; exit 1; }
COUNTSYMS_IN="${COUNTSYMS_IN:-/dev/null}"
COUNTSYMS_OUT="$TMP/out.txt" LD_LIBRARY_PATH="$ROOT/out/interposable" LD_PRELOAD="$TMP/cs.so" "$ROOT/scrip" --run "$PROG" < "$COUNTSYMS_IN" > "$TMP/prog.out" 2>"$TMP/prog.err"
RC=$?
[ -s "$TMP/out.txt" ] || { echo "NO DATA — every named symbol counted zero (rc=$RC).  Either the program never reaches them, or it does not run at all."; sed -n '1,6p' "$TMP/prog.err"; exit 1; }
echo "=== DYNAMIC CALL COUNT — $PROG (rc=$RC) ==="
printf "%-40s %14s %11s\n" SYMBOL ENTRIES EARLY-INIT
while read -r s; do
  n=$(awk -v k="$s" '$1==k{print $2}' "$TMP/out.txt"); n=${n:-0}
  z=$(awk -v k="$s" '$1==k{print $3}' "$TMP/out.txt"); z=${z:-0}
  printf "%-40s %14s %11s\n" "$s" "$n" "$([ "$z" = 0 ] && echo no || echo YES)"
done < "$TMP/syms.txt"
echo "--- program stdout (first 6 lines, so a broken run cannot masquerade as a measurement) ---"
sed -n '1,6p' "$TMP/prog.out"
