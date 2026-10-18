#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the instrumentation switch (--stlimit): Icon &trace rides the call/return hooks that are off by default since SCRIP 2026-09-24 (Lon: monitor hooks behind the switch)
# test_gate_icn_call_site_parity_at_proc_call_open.sh -- SysV call-site parity at rt_proc_call_open{,_det}.
#
# WHY THIS EXISTS (CEO-458): the Icon generator call site entered rt_proc_call_open_det at rsp 8-mod-16,
# a real ABI violation, because bb_call_proc_staged's N-2 pad kept compensating for a REGION HAND-OFF push
# that N-3 had moved to the OTHER SIDE of the call. A compensating pad outlived the push it compensated for.
# It was latent for weeks and only surfaced when a callee finally reached an aligned SSE store -- a movaps
# inside vsnprintf, reached only when the traced call had an argument to image. A generator with NO argument
# was equally misaligned and passed, which is exactly why a witness-based test could not have caught it.
#
# ⛔ SO THIS GATE MEASURES THE INVARIANT, NOT THE SYMPTOM: rsp % 16 == 0 at EVERY call to
# rt_proc_call_open/rt_proc_call_open_det, in a --compile of each witness, read out of the running process.
# A symptom test (does the tracer crash) goes green the moment any pad happens to re-balance the stack;
# this goes red the moment any pad stops matching its push, which is the class.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
NAME=icn_call_site_parity_at_proc_call_open
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root
CORPUS="${CORPUS:-$S4E/corpus}"
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
command -v gdb >/dev/null 2>&1 || refuse "gdb absent -- this gate reads rsp at a breakpoint and cannot measure without it"
command -v objdump >/dev/null 2>&1 || refuse "objdump absent -- cannot locate the call sites"
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
cat > "$TD/gen_arg.icn" <<'EOF'
procedure main();
    &trace := -1;
    every write(g(1));
end
procedure g(x);
    suspend x;
end
EOF
cat > "$TD/gen_noarg.icn" <<'EOF'
procedure main();
    &trace := -1;
    every write(g());
end
procedure g();
    suspend 1;
end
EOF
# ⛔⭐ THE FOURTH SYNTHETIC WITNESS, AND IT IS THE ONE THAT MAKES THIS GATE HONEST (hq_U, CEO-507).
# The three witnesses below call a generator BY NAME, so every one of them goes through bb_call_proc_staged.
# The surviving face of the alignment class lives in the OTHER door -- bb_call_value -- and its n2_align pad
# needs `flat_gen`, which is a property of the CALL SITE's enclosing procedure, not of the callee.  So a
# by-name witness cannot arm it at any size, and this gate PASSED 5/5 on a tree where the ten lines below
# SIGSEGV in both modes and iconx prints 1 then 2.  ⭐ A GATE WHOSE WITNESSES ALL ENTER BY THE SAME DOOR
# MEASURES THE DOOR, NOT THE INVARIANT: the region cannot tell which door it came through (hq_S's framing),
# which is exactly why exonerating one door tells you nothing about the other.  Measured on 3bbdfc8c7:
# arm B reads rsp%16=0 in FN__h and rsp%16=8 in FN__g here, and 0 everywhere in the three by-name witnesses.
cat > "$TD/gen_via_value.icn" <<'EOF'
procedure main();
    every write(h());
end
procedure h();
    local p;
    p := g;
    suspend p(1);
    suspend p(2);
end
procedure g(x);
    suspend x;
end
EOF
cat > "$TD/nongen_arg.icn" <<'EOF'
procedure main();
    &trace := -1;
    write(g(1));
end
procedure g(x);
    return x;
end
EOF
GRADED=0; FAIL=0
for w in gen_arg gen_noarg nongen_arg gen_via_value; do
  "$SCRIP" --compile -o "$TD/$w.s" "$TD/$w.icn" </dev/null >/dev/null 2>&1 || refuse "$w: --compile failed -- cannot measure"
  gcc -no-pie "$TD/$w.s" -o "$TD/$w.bin" -L "$ROOT/out" -Wl,-rpath,"$ROOT/out" -lscrip_rt -lm -lpthread >/dev/null 2>&1 || refuse "$w: link failed -- cannot measure"
  sites="$(objdump -d "$TD/$w.bin" 2>/dev/null | grep -oE '^ *[0-9a-f]+:.*call.*rt_proc_call_open(_det)?' | awk -F: '{print $1}' | tr -d ' ')"
  [ -n "$sites" ] || { echo "  SKIPPED $w: no rt_proc_call_open call site in this witness"; continue; }
  for a in $sites; do
    GRADED=$((GRADED+1))
    printf '%s\n' 'set debuginfod enabled off' 'set pagination off' "break *0x$a" 'run' 'printf "PARITY=%d\n", ((long)$sp)%16' > "$TD/gdb.cmd"
    rem="$(setarch -R gdb -q -batch -x "$TD/gdb.cmd" --args "$TD/$w.bin" 2>/dev/null | grep -oE 'PARITY=[0-9]+' | head -1 | cut -d= -f2)"
    if [ -z "$rem" ]; then refuse "$w @0x$a: the breakpoint was never reached, so the parity was NOT measured -- a gate that cannot measure REFUSES, it does not report a failure it did not observe"; fi
    if [ "$rem" = "0" ]; then echo "  PASS $w @0x$a: rsp%16=0"
    else echo "  FAIL $w @0x$a: rsp%16=$rem -- SysV requires 0 at a call; a pad no longer matches its push"; FAIL=$((FAIL+1)); fi
  done
done
# ⛔⭐ ARM B, THE CALLEE SIDE (hq_U, CEO-483). ARM A ABOVE IS ON THE WRONG SIDE OF THE PUSH BLOCK TO SEE THIS
# CLASS, and that is measured, not argued: dropping the N-2 pad SIGSEGVs patchu in both modes while arm A
# stays 2/2 GREEN, because rt_proc_call_open is a CALLER-side call ABOVE the push block and the pad moves
# parity BELOW it, at the jmp into the callee. Arm A is correct and is not weakened; it simply cannot reach
# past the jmp. So this arm measures the other side.
#
# ⛔ AND IT DOES NOT MEASURE rsp AT THE CALLEE'S FIRST INSTRUCTION, which is the obvious thing to write and is
# WRONG: since CEO-483 the generator entry frame is FIVE words and entry rsp is 8-mod-16 ON PURPOSE -- the
# odd word moved across the call into the callee's own carve, which absorbs it. A gate pinned to the entry
# instruction would go red on the very landing that cured the bug. What SysV actually requires, and what the
# crash actually violates, is 0-mod-16 AT A CALL: so this arm breaks on the FIRST call the callee BODY makes
# after its carve. That is the exact instruction the record bug died in (a helper reached from a misaligned
# body, movaps inside vsnprintf), it is true under both the old six-word and the new five-word layout, and it
# goes red the moment any carve stops absorbing the parity its call site hands it.
for w in gen_arg gen_noarg nongen_arg gen_via_value; do
  [ -f "$TD/$w.bin" ] || continue
  for fn in $(objdump -d "$TD/$w.bin" 2>/dev/null | grep -oE '^[0-9a-f]+ <FN__[A-Za-z0-9_]+>:' | sed 's/.*<//; s/>:.*//'); do
    body="$(objdump -d --disassemble="$fn" "$TD/$w.bin" 2>/dev/null | grep -E '^ *[0-9a-f]+:' | grep -E '\<call\>' | head -1 | awk -F: '{print $1}' | tr -d ' ')"
    [ -n "$body" ] || { echo "  SKIPPED $w/$fn: the callee body makes no call -- nothing this arm can measure here"; continue; }
    GRADED=$((GRADED+1))
    printf '%s\n' 'set debuginfod enabled off' 'set pagination off' "break *0x$body" 'run' 'printf "PARITY=%d\n", ((long)$sp)%16' > "$TD/gdb.cmd"
    rem="$(setarch -R gdb -q -batch -x "$TD/gdb.cmd" --args "$TD/$w.bin" 2>/dev/null | grep -oE 'PARITY=[0-9]+' | head -1 | cut -d= -f2)"
    if [ -z "$rem" ]; then refuse "$w/$fn @0x$body: the breakpoint was never reached, so the callee-body parity was NOT measured -- a gate that cannot measure REFUSES, it does not report a failure it did not observe"; fi
    if [ "$rem" = "0" ]; then echo "  PASS $w/$fn @0x$body: callee-body rsp%16=0 at its first call"
    else echo "  FAIL $w/$fn @0x$body: callee-body rsp%16=$rem at its first call -- the carve is not absorbing the parity its call site handed it; every helper this body reaches is misaligned and the first aligned SSE store in one of them dies"; FAIL=$((FAIL+1)); fi
  done
done
# ⛔⭐ ARM C, THE FOUR NAMED WITNESSES (hq_U, CEO-507). Arms A and B measure the INVARIANT on ten-line
# programs; this arm measures that the four programs the class was found through still RUN.  It grades
# ONE thing and says so: a parity fault presents as a SIGNAL death, so a rc >= 128 is the verdict here and
# nothing else is.  ⛔ IT DELIBERATELY DOES NOT DIFF ANY OF THEM AGAINST ITS .std -- geddump's output is
# hq_S's row, diffu's and diffn's are hq_R's, and their refs moved twice on 2026-09-10.  A gate that grades
# somebody else's moving denominator goes red for their landings, not for the class it was written for.
# ⭐ AND IT IS NOT A SUBSTITUTE FOR ARMS A AND B, which is the whole lesson of this class: gen_noarg was
# MISALIGNED AND PASSING for weeks, so an outcome arm alone exonerates a broken door whenever no callee on
# that path happens to reach an aligned SSE store.  Outcome arms catch what has already started dying;
# invariant arms catch it the commit it is introduced.
IPL="$CORPUS/packages/icon/ipl/progs"
[ -d "$IPL" ] || refuse "no $IPL -- the four named witnesses cannot be located, so this arm CANNOT MEASURE"
# ⛔ THE ARGV SIDECAR READER IS A SHARED AUTHORITY -- SOURCE IT, NEVER REIMPLEMENT IT. Field 1 of NAME.argv
# is the PROGRAM NAME, not an argument, and hand-rolling the split is how this arm first ran diffu with
# "diffu" as argv[1]: it exited rc=1 on a file that does not exist, never reached the misaligned door, and
# reported PASS on a tree where the program SIGSEGVs. A hand-rolled reader of a shared format does not
# fail loudly -- it grades a different program and prints the reassuring answer.
. "$HERE/lib_icon_ipl_isolation.sh" 2>/dev/null || refuse "lib_icon_ipl_isolation.sh unloadable -- the argv sidecar reader is the one authority, and guessing the split is what this arm is not allowed to do"
cat > "$TD/tracer.icn" <<'EOF'
procedure main();
    &trace := -1;
    every write(g(1));
end
procedure g(x);
    suspend x;
    suspend x + 1;
end
EOF
printf '0 INDI\n' > "$TD/ged.in"
: > "$TD/empty.in"
run_named() {   # $1=label $2=dir $3=source $4=stdin-file ; extra argv in $5.. (relative to $2)
  local dir="$2" src="$3" stdin="$4"; shift 4
  local rc3 rc4 out
  out="$(cd "$dir" && timeout -k 5 60 "$SCRIP" "$src" ${1:+--} "$@" < "$stdin" 2>&1)"; rc3=$?
  GRADED=$((GRADED+1))
  if [ "$rc3" -ge 128 ]; then echo "  FAIL $src m3: died on signal $((rc3-128)) (rc=$rc3) -- a parity fault presents exactly this way"; FAIL=$((FAIL+1))
  else echo "  PASS $src m3: rc=$rc3, no signal death"; fi
  if ! (cd "$dir" && "$SCRIP" --compile -o "$TD/$src.s" "$src" </dev/null >/dev/null 2>&1); then
    refuse "$src: --compile failed -- the m4 arm CANNOT MEASURE"; fi
  if ! gcc -no-pie "$TD/$src.s" -o "$TD/$src.bin" -L "$ROOT/out" -Wl,-rpath,"$ROOT/out" -lscrip_rt -lm -lpthread >/dev/null 2>&1; then
    refuse "$src: link failed -- the m4 arm CANNOT MEASURE"; fi
  out="$(cd "$dir" && timeout -k 5 60 "$TD/$src.bin" "$@" < "$stdin" 2>&1)"; rc4=$?
  GRADED=$((GRADED+1))
  if [ "$rc4" -ge 128 ]; then echo "  FAIL $src m4: died on signal $((rc4-128)) (rc=$rc4) -- a parity fault presents exactly this way"; FAIL=$((FAIL+1))
  else echo "  PASS $src m4: rc=$rc4, no signal death"; fi
}
run_named tracer  "$TD" tracer.icn  "$TD/empty.in"
run_named geddump "$IPL" geddump.icn "$TD/ged.in"
for w in diffu diffn; do
  declare -a WA=(); ipl_argv_read "$IPL/$w.icn" WA; arc=$?
  [ "$arc" -eq 0 ] || refuse "$w: ipl_argv_read returned $arc -- without the declared argv this witness runs a different program, so this arm CANNOT MEASURE"
  run_named "$w" "$IPL" "$w.icn" "$TD/empty.in" "${WA[@]}"
done
# ⛔⭐ ARM D, THE PAD CENSUS (hq_U, CEO-507). Not every `sub rsp, 8` is a pad -- several are ABI WORDS with
# real readers, and their own notes say which ([rsp+16]=REGION, [rsp+24]=L7, the N-2 word).  So this arm
# does NOT count `sub rsp, 8`; it counts the sites that DECLARE THEMSELVES ALIGNMENT COMPENSATION, which is
# the population the class is made of: a self-named PL-CALL-ALIGN pad in the GENERATOR regime, and any
# force_align_arg_pointer wrapper outside the declared PL port-trace reporting set.  ⭐ THE DISCRIMINATOR IS
# THE SELF-DECLARATION ON PURPOSE: a pad that has to announce itself as compensating for a push is a pad
# that will outlive the push, which is literally how this class was born (CEO-458).  Every exemption below
# is NAMED with why it is not a pad -- an allowlist nobody signed is not an allowlist.
pad_hits=0
for f in $(find "$ROOT/src/templates" "$ROOT/src/runtime" -type f \( -name '*.cpp' -o -name '*.c' -o -name '*.h' -o -name '*.s' \) 2>/dev/null | sort); do
  case "$f" in
    */rt/porttrace.cpp|*/rt/portcount.c) continue ;;   # DECLARED: the PL port-trace/port-count REPORTERS are
      # reached from emitted code by a bare call at an arbitrary BB depth and are not on any call path this
      # class covers; they are diagnostics, not the ABI. Retiring them is a separate row, not this census.
  esac
  n="$(/usr/bin/grep -c 'force_align_arg_pointer' "$f" 2>/dev/null || true)"
  [ -n "$n" ] && [ "$n" -gt 0 ] 2>/dev/null && { echo "  FAIL $f: $n force_align_arg_pointer wrapper(s) -- a per-site pad; the parity is fixed at the source, never hidden by a wrapper (CEO-501)"; pad_hits=$((pad_hits+n)); }
done
GRADED=$((GRADED+1))
if [ "$pad_hits" -eq 0 ]; then echo "  PASS pad census: 0 undeclared force_align wrappers under src/templates and src/runtime"
else FAIL=$((FAIL+1)); fi
[ "$GRADED" -eq 0 ] && refuse "graded zero call sites -- the witnesses reached no rt_proc_call_open call, so this gate measured nothing"
echo "graded=$GRADED FAIL=$FAIL (arm A rsp%16 at every rt_proc_call_open/_det call site + arm B rsp%16 at the first call each callee BODY makes after its carve, both read from the running process + arm C the four named witnesses run in both modes, signal death only + arm D the force_align wrapper census; gen_noarg and gen_via_value are in the set ON PURPOSE -- gen_noarg was misaligned and PASSING, and gen_via_value is the only witness that enters by the bb_call_value door at all)"
if [ "$FAIL" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: FAIL=$FAIL of $GRADED"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $GRADED/$GRADED"
exit 0
