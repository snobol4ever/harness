#!/usr/bin/env bash
# lib_static_link_snobol4.sh -- THE ONE AUTHORITY for the OPT-IN mode-4 STATIC link arm.
# Row m4-static-link-arm (Lon 2026-08-28, FLEET-6, DEMO-floor lane).
#
# ⛔ out/libscrip_rt.so REMAINS CANONICAL -- 73 scripts reference it by that exact name and this file
# changes nothing about that path or about the default (dynamic) link line any caller already has.
# This is an ADDITIONAL, opt-in arm selected by the caller (STATIC=1), never a replacement.
#
# WHY THIS ARM EXISTS: FINDING f4f6292c (hq_P) isolated the tier-1 aspect-1 floor to merely LOADING
# libscrip_rt.so -- a control (`gcc --no-as-needed`, because the DEFAULT --as-needed silently drops an
# unreferenced -l flag and a control that does that agrees with every hypothesis) measured 430 minor
# faults / 7.4MB / ~1.8ms paid before any program work runs. Of the three link-flag levers tried
# (-z pack-relative-relocs, -Bsymbolic-functions, strip --strip-debug), all three measured DEAD (<1.3%
# each, do NOT respend effort there). The one lever that worked: static linking -- do-nothing floor
# -51% faults, treebank-match -29%, answers byte-identical. NOT a default: ~27-30MB per binary vs
# ~16-32KB dynamic, and that price is Lon/ceo's call, not this file's.
#
# MECHANISM: `ar rcs` the SAME $(RT_PIC_OBJS) already compiled for libscrip_rt.so (Makefile target
# `libscrip_rt_static` -> out/libscrip_rt.a) and `gcc -static` the caller's .o against that archive.
# Full -static (not -Wl,-Bstatic/-Bdynamic toggling around a still-dynamic libc): simpler, and it is
# the arm actually measured -- avoiding the loader entirely, not just avoiding libscrip_rt.so's DT_NEEDED.
#
# ⛔ CALLERS MUST REFUSE, NOT FALL BACK to a dynamic link while claiming STATIC=1 was honoured -- a
# silent substitution here would be exactly the "control that doesn't test what it claims" trap this
# row's own brief warns about. verify_static_binary() below is the ldd-not-assumption check for that.

# static_rt_archive ROOT -- ensure out/libscrip_rt.a exists for this ROOT's current RT_TAG, building it
# (a cheap `ar` over already-compiled objects; no new compile flags) if missing. Echoes the .a path on
# success; prints nothing and returns nonzero on failure.
static_rt_archive() {
  local root="$1" rt_a="$1/out/libscrip_rt.a"
  if [ ! -e "$rt_a" ]; then
    ( cd "$root" && make -s libscrip_rt_static ) 1>&2 || return 1
  fi
  [ -e "$rt_a" ] || return 1
  echo "$rt_a"
}

# m4_link_static DST OBJ ROOT -- link OBJ (from `as`) into DST, fully statically, against ROOT's
# libscrip_rt.a. Mirrors the dynamic arm's `gcc -no-pie ... -lscrip_rt -lm` callers already run, minus
# -Wl,-rpath (nothing to find at runtime) and minus -L/-lscrip_rt (the archive is named directly so
# the static archive is never shadowed by a same-named .so on the search path).
m4_link_static() {
  local dst="$1" obj="$2" root="$3" rt_a
  rt_a="$(static_rt_archive "$root")" || return 1
  gcc -no-pie -static -o "$dst" "$obj" "$rt_a" -lm -lstdc++ -lpthread 2>/dev/null
}

# verify_static_binary BIN -- the control-arm-trap check FINDING f4f6292c asks every static-arm caller
# to run: confirm BIN is genuinely static (ldd, never assumption) rather than trusting the link
# succeeded silently against a dynamic fallback.
# ⛔ NOT a pipe to grep: `ldd` itself exits 1 when reporting "not a dynamic executable" (normal ldd
# behaviour for a static binary, not an error) -- under a caller's `set -o pipefail` that nonzero exit
# outranks grep's own (matching) status, so `ldd ... | grep -q ...` reports FAILURE even when the text
# matched. Capture ldd's output first and pattern-match the string in bash, so this function's result
# depends only on what ldd printed, never on ldd's own exit code.
verify_static_binary() {
  local out; out="$(ldd "$1" 2>&1)"
  [[ "$out" == *"not a dynamic executable"* ]]
}
