#!/usr/bin/env bash
# test_gate_rtx_ctor_armed.sh — RTX_GATE family armed-state IS observable, and a build that
# drops rtx_gates_init() (the static-archive constructor trap, FINDING-2026-08-22-seat01-
# kill-the-plt-measured-real-but-tiny-and-a-static-archive-constructor-trap.md §5) FAILS this
# gate instead of silently shipping ~14 disarmed fast-path families at 2.05x cost, correct
# output, zero error. Queue row `rung-static-archive-ctor-drop`.
#
# THREE ARMS, not two — a negative test that cannot demonstrate its own negative is worthless
# (same philosophy as test_gate_rtx_killswitch_sets.sh's QUARANTINE verdict: report the fact,
# never assume it). NOTE ON ARM A: the gate bytes are DELIBERATELY `.hidden` (rtx_abi.inc:71-76
# — "scrip links dynamically against libscrip_rt.so, so hidden visibility makes [rip+sym]
# direct and interposition-proof"), which means they are NOT in the .so's dynamic symbol table
# and an externally-linked probe cannot `extern`+dynamically-link against out/libscrip_rt.so to
# read them (verified: that link fails with "undefined reference", not a runtime answer). A
# PLAIN multi-object static link (object files listed directly, never through an archive) is
# not blocked by hidden visibility (that only suppresses DYNAMIC/shared-library export) and
# is not subject to the archive-pull hazard either (every listed .o is unconditionally
# included, unlike archive members) — so it is the correct, meaningful control for "nothing is
# artificially excluding rtx_init.o", verified separately from the shipped .so.
#   A — CONTROL: probe linked against out/rt_pic/*.o directly, as a plain object list (no
#       archive). Every listed .o, including rtx_init.o, is unconditionally pulled in exactly
#       like it is inside out/libscrip_rt.so's own link line (Makefile:353) — this is the
#       object-inclusion half of what makes today's actual .so safe, checked the one way this
#       probe can check it. (The .so's OWN safety additionally rests on ELF shared-object
#       constructors running unconditionally at load time regardless of symbol references —
#       basic dynamic-loader behavior, not specific to this codebase, not re-verified here.)
#       MUST read ARMED (rc=0).
#   B — the trap, reproduced for real: probe linked against a NAIVE `ar rcs` static archive
#       of the exact same objects. Archive members are pulled only to satisfy undefined
#       symbol references; nothing references anything inside rtx_init.o (the constructor is
#       registered via .init_array, not called by name), so it is silently dropped and every
#       gate byte stays at its `.byte 0` link-time default. MUST read DISARMED (rc=1) — if
#       this arm reads ARMED instead, the gate FAILS LOUDLY: it would mean the probe cannot
#       actually detect the hazard it exists to catch, which is worse than not having it.
#   C — the known-good fix (seat01 arm C2): the same static archive, linked with
#       `-Wl,--whole-archive` so every member (rtx_init.o included) is forced in. MUST read
#       ARMED (rc=0) — documents, verified, the one thing that fixes arm B if static linking
#       is ever actually adopted.
#
# GATE PASSES iff A=ARMED and B=DISARMED and C=ARMED. Any other combination is a FAIL with the
# offending arm named — never a silent partial pass.
set -u
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
RT_OBJDIR="$ROOT/out/rt_pic"
SO="$ROOT/out/libscrip_rt.so"
PROBE_SRC="$ROOT/../harness/scripts/probe_rtx_gate_armed.c"
[ -f "$SO" ] || { echo "FATAL: $SO missing — run 'make' or 'make libscrip_rt' first"; exit 1; }
[ -d "$RT_OBJDIR" ] && [ -n "$(ls -A "$RT_OBJDIR"/*.o 2>/dev/null)" ] || { echo "FATAL: $RT_OBJDIR has no .o files — build first"; exit 1; }
[ -f "$PROBE_SRC" ] || { echo "FATAL: $PROBE_SRC missing"; exit 1; }
WORKDIR="$(mktemp -d)"; trap 'rm -rf "$WORKDIR"' EXIT

gcc -c "$PROBE_SRC" -o "$WORKDIR/probe.o" || { echo "FATAL: probe failed to compile"; exit 1; }

run_arm() {
  # run_arm <label> <link-command...> — links, runs, prints ARMED/DISARMED/CRASH, returns the probe's rc (2 on link/run failure)
  local label="$1"; shift
  if ! "$@" 2>"$WORKDIR/$label.linklog"; then
    echo "$label: LINK FAILED"; cat "$WORKDIR/$label.linklog"; return 2
  fi
  local out rc
  out="$("$WORKDIR/$label.bin" 2>&1)"; rc=$?
  printf '%s\n' "$out" | sed "s/^/  [$label] /"
  if [ "$rc" -eq 0 ]; then echo "$label: ARMED (rc=0)"
  elif [ "$rc" -eq 1 ]; then echo "$label: DISARMED (rc=1)"
  else echo "$label: CRASH/UNEXPECTED (rc=$rc)"; fi
  return "$rc"
}

echo "=== ARM A — plain static link against out/rt_pic/*.o directly (control: no archive, nothing excludable) ==="
run_arm A gcc "$WORKDIR/probe.o" "$RT_OBJDIR"/*.o -lm -lstdc++ -lpthread -o "$WORKDIR/A.bin"
rcA=$?

echo "=== ARM B — naive static archive (the trap, reproduced for real) ==="
ar rcs "$WORKDIR/libscrip_rt_static.a" "$RT_OBJDIR"/*.o 2>"$WORKDIR/ar.log" || { echo "FATAL: ar rcs failed"; cat "$WORKDIR/ar.log"; exit 1; }
run_arm B gcc "$WORKDIR/probe.o" "$WORKDIR/libscrip_rt_static.a" -lm -lstdc++ -lpthread -o "$WORKDIR/B.bin"
rcB=$?

echo "=== ARM C — static archive, -Wl,--whole-archive (the fix) ==="
run_arm C gcc "$WORKDIR/probe.o" -Wl,--whole-archive "$WORKDIR/libscrip_rt_static.a" -Wl,--no-whole-archive -lm -lstdc++ -lpthread -o "$WORKDIR/C.bin"
rcC=$?

echo "=== VERDICT (want A=ARMED(0) B=DISARMED(1) C=ARMED(0)) ==="
FAIL=0
[ "$rcA" -eq 0 ] || { echo "FAIL: arm A (plain static link, control) is NOT fully armed — rc=$rcA. This must never regress."; FAIL=1; }
[ "$rcB" -eq 1 ] || { echo "FAIL: arm B (naive static archive) did not read DISARMED as expected — rc=$rcB. Either the trap no longer reproduces (investigate before trusting this gate) or something else broke."; FAIL=1; }
[ "$rcC" -eq 0 ] || { echo "FAIL: arm C (--whole-archive fix) is NOT fully armed — rc=$rcC. The documented fix no longer works."; FAIL=1; }
if [ "$FAIL" -eq 0 ]; then
  echo "GATE PASS: armed-state is observable (probe_rtx_gate_armed.c), a dropped-constructor build fails it (arm B), and the whole-archive fix restores it (arm C)."
  exit 0
fi
echo "GATE FAIL"
exit 1
