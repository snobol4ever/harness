#!/usr/bin/env bash
# audit_m3_native_binary_arms.sh — M3-NATIVE-0/1 coverage audit + stub gate.
# Classifies every SM/BB/XA template's x86 MEDIUM_BINARY arm as REAL / TRIVIAL-JMP / NO-ARM / EMPTY,
# and FAILS if any fake two-jmp placeholder ("\xE9"+u32le(0) doubled) survives outside the known-correct
# trivial set (eps/fail/fence — whose full semantics genuinely are two jumps).
# A silent unimplemented x86 BINARY arm let mode-3 fall through to the C oracle and masked missing native
# bytes; M3-NATIVE-0 requires such arms to fail LOUDLY instead.  This script is that gate.
# ⛔ THE REMEDY CHANGED AT THE s269 STRIP: bomb_bytes()/bomb_text() were deleted as dead (no arm called
# either; CEO-11b, Lon indifferent).  The remedy for a fake-jmp stub is now the emission-discipline law
# itself -- IMPLEMENT the arm, adding an encoder to x86_asm.h if an instruction is missing.  Never
# hand-encode bytes.  The BOMB classification is gone with the functions; pass/fail logic is unchanged.
set -u
here="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
cd "$here" || exit 2
TRIVIAL_OK="bb_eps.cpp bb_fail.cpp bb_match_fence.cpp bb_match_abort.cpp bb_seq.cpp bb_nfa.cpp"
fail=0
echo "=== M3-NATIVE BINARY-arm coverage ==="
# PATH CORRECTED s169 (seat1, gates-dead-paths): was "src/templates/{bb,xa}/*.cpp src/emitter/SM_templates/*.cpp
# src/templates/{bb,xa}/*.cpp" -- the reorg sed collapsed BB_ and XA_ onto one dir (every file audited TWICE) and
# left SM_templates pointing at a directory that no longer exists.
for f in src/templates/{bb,xa}/*.cpp; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  grep -q "MEDIUM_BINARY" "$f" || { printf "  %-30s NO-ARM\n" "$name"; continue; }
  # Two arm styles exist: concat  IF(MEDIUM_BINARY, ...)  and early-return  if (MEDIUM_BINARY) { ... }.
  # Grab a generous window after each MEDIUM_BINARY token (up to the next TEXT/JVM boundary) so both styles
  # are covered, then test that window for real byte-emitters vs comment-only.
  body="$(awk '/MEDIUM_BINARY/{p=1; c=0}
                p{print; c++}
                p && (/IF\(MEDIUM_TEXT/ || /if *\( *MEDIUM_TEXT/ || /PLATFORM_JVM/) {p=0}
                c>60{p=0}' "$f")"
  has_real="$(printf '%s' "$body" | grep -cE 'bytes\(|u64le|u32le|u8\(')"
  fakejmp="$(printf '%s' "$body" | grep -c 'bytes(1, "\\xE9")')"
  # A REAL arm may legitimately end in a jmp; a FAKE stub is ONLY the doubled jmp and nothing else:
  # few byte-emitters, and none of the substantive primitives (movabs / strchr / rt_ / lea / cset).
  nbyte="$(printf '%s' "$body" | grep -oE 'bytes\(|u64le|u32le' | wc -l)"
  substantive="$(printf '%s' "$body" | grep -cE 'movabs|strchr|rt_|lea |\\\\x48|cset|0x|bin\.sites\.push_back|bin\.labels\.push_back')"
  is_fake=0
  if [ "$fakejmp" -gt 0 ] && [ "$nbyte" -le 4 ] && [ "$substantive" -eq 0 ]; then is_fake=1; fi
  if [ "$is_fake" -eq 1 ]; then
    if echo " $TRIVIAL_OK " | grep -q " $name "; then printf "  %-30s TRIVIAL-JMP (ok)\n" "$name"
    else printf "  %-30s ** FAKE-JMP STUB (must implement) **\n" "$name"; fail=1; fi
  elif [ "$has_real" -gt 0 ]; then printf "  %-30s REAL\n" "$name"
  else printf "  %-30s EMPTY/COMMENT\n" "$name"; fi
done
echo "---------------------------------------------"
if [ "$fail" -ne 0 ]; then echo "GATE FAIL: fake-jmp placeholder BINARY arms remain (implement the arm; add an x86_asm.h encoder if an instruction is missing)."; exit 1; fi
echo "GATE OK: no fake-jmp placeholder BINARY arms outside the known-trivial set."
