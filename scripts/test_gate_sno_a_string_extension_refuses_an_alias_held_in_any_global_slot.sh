#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_a_string_extension_refuses_an_alias_held_in_any_global_slot.sh -- THE IN-PLACE EXTENSION SCAN IS UNROLLED AND STILL SEES EVERY SLOT
# (hq_snobol4 2026-10-15; row snobol4-speed-beauty-self-host-reads-0-22x-spitbol-in-mode-4-and-0-06x-in-mode-3). str_concat_d (rtx_str.s) extends the
# string it just built in place only when at most one global slot holds its pointer: .Lsc_ext_scan walked EVERY global slot (gva_n, 1,143 in a small
# program, 1,311 in the beauty self-host) at seven instructions a slot, per append -- 6.9 M iterations, 48 M Ir, 5.9% of the beauty run. The scan now
# compares eight slots per block with a bare cmp/je pair each (2.5 instructions a slot) and re-scans a block that holds a pointer-equal slot with the
# old precise logic (tag test, count, refuse at the second holder); the last fewer than eight slots take the old loop.
# ARMS: (1) the witness -- 32 alias phases over 400 padded globals (an alias is taken, 300 appends, the alias is released) then 3,000 free appends --
# prints the oracle's lines in m3 and m4; (2) the INJECTION: the free-append loop is stopped in gdb at its 1,501st concat, a copy of x's descriptor is
# written into another global slot (slot 0, 7, 8, 15, 16, 100, 740, 743 and the last 1, 2, 7, 8, 9, 16, 17 of gva_n -- every residue of the 8-slot block
# and the tail) and the run continues: an alias held anywhere in the scanned range must refuse the next in-place extension, so rt_str_alloc is hit
# once more than the uninjected control run (control 1 hit, each injection 2); (3) the instruction slope of the free-append loop over those globals,
# (Ir at 12,000 appends - Ir at 2,000) / 10,000, is at most 5,000 (before the unroll 8,224, now 3,151).
# FAIL_ONCE (recorded): arm 3 reads 8,224 on the runtime before the unroll (parent tree, stash rebuilt) and 3,151 here; arm 2 carries its own control
# (the uninjected run reads 1, every injection must read 2), and an alias written into the slot of a program variable that the loop needs (x's own slot
# and the loop counter's) is skipped, not counted.
# EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle, gdb, valgrind or the build missing, an Ir reading that is not a number).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
. "$HERE/lib_ir_measure.sh" 2>/dev/null || { echo "REFUSED(2): cannot load lib_ir_measure.sh -- this gate will not read Ir by hand"; exit 2; }
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
command -v gdb >/dev/null 2>&1 || { echo "REFUSED(2): gdb missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
build() { ( cd "$W" && "$ROOT/scrip" --compile --out="$W/$1.s" "$1.sno" < /dev/null > /dev/null 2>&1 && gcc "$W/$1.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/$1.bin" 2>/dev/null ) || { echo "REFUSED(2): $1 did not build in mode 4"; exit 2; }; }
pad() { for i in $(seq -w 1 400); do echo "        v$i = 'k$i'"; done; }
{ pad; echo "        x = 'seed'"
for v in 001 002 003 004 005 006 007 008 009 010 011 012 013 014 015 016 200 201 202 203 204 205 206 207 393 394 395 396 397 398 399 400; do
printf "        v$v = x\n        j = 0\nl$v     x = x 'a'\n        j = j + 1\n        LT(j, 300)                                      :S(l$v)\n        OUTPUT = '$v ' SIZE(x) ' ' SIZE(v$v)\n        v$v = 'released'\n"; done
printf "        j = 0\nfree    x = x 'b'\n        j = j + 1\n        LT(j, 3000)                                     :S(free)\n        OUTPUT = 'free ' SIZE(x)\n        OUTPUT = SIZE(v001) ' ' v001 ' ' v400\nEND\n"; } > "$W/alias.sno"
"$SBL" $(sbl_lang_flags) "$W/alias.sno" < /dev/null > "$W/alias.ref" 2>&1 || true
[ "$(wc -l < "$W/alias.ref")" -eq 34 ] || { echo "REFUSED(2): the oracle printed $(wc -l < "$W/alias.ref") lines for the witness, not 34"; exit 2; }
red=0
( cd "$W" && timeout -k 5 60 "$ROOT/scrip" alias.sno < /dev/null > "$W/alias.m3" 2>&1 )
if cmp -s "$W/alias.m3" "$W/alias.ref"; then echo "ok  (1) m3 = oracle over 34 lines"; else echo "RED (1) m3 differs from the oracle:"; diff "$W/alias.ref" "$W/alias.m3" | head -6; red=1; fi
build alias; ( cd "$W" && timeout -k 5 60 ./alias.bin < /dev/null > "$W/alias.m4" 2>&1 )
if cmp -s "$W/alias.m4" "$W/alias.ref"; then echo "ok  (1) m4 = oracle"; else echo "RED (1) m4 differs from the oracle:"; diff "$W/alias.ref" "$W/alias.m4" | head -6; red=1; fi
mk() { { echo "        x = 'seed'"; echo "        j = 0"; pad; printf "free    x = x 'b'\n        j = j + 1\n        LT(j, %s)                                     :S(free)\n        OUTPUT = 'free ' SIZE(x)\nEND\n" "$1"; } > "$W/inj$1.sno"; build "inj$1"; }
mk 3000; mk 2000; mk 12000
( cd "$W" && ./inj3000.bin < /dev/null > "$W/inj.out" 2>&1 ); grep -q '^free 3004$' "$W/inj.out" || { echo "REFUSED(2): the injection twin did not print its line: $(head -1 "$W/inj.out")"; exit 2; }
cat > "$W/inj.gdb" <<'GDB'
set pagination off
set confirm off
set breakpoint pending on
break sno_concat_d
ignore 1 1500
run < /dev/null > /dev/null 2>&1
set $n = g_runtime.abi.sxt_fr.gva_n
set $xk = -1
set $k = 0
while $k < $n
  if *(long*)(0x70001000 + 16*$k + 8) == $rsi && *(unsigned char*)(0x70001000 + 16*$k) == (unsigned char)DT_S
    set $xk = $k
  end
  set $k = $k + 1
end
printf "GVA_N=%d XK=%d\n", $n, $xk
if $B > 0
  set $T = $n - $B
end
if $T >= 0 && $T < $n && $T != $xk && $T != $xk + 1
  set {long}(0x70001000 + 16*$T) = *(long*)(0x70001000 + 16*$xk)
  set {long}(0x70001000 + 16*$T + 8) = *(long*)(0x70001000 + 16*$xk + 8)
  printf "INJECTED T=%d\n", $T
end
delete 1
break rt_str_alloc
ignore 2 100000000
continue
info breakpoints
GDB
hits() { ( cd "$W" && timeout -k 5 300 gdb -q -batch -ex "set \$T=$1" -ex "set \$B=$2" -x "$W/inj.gdb" ./inj3000.bin 2>&1 | grep -E 'already hit|INJECTED' | tr '\n' ' ' ); }
ctl=$(hits -1 0 | grep -o 'already hit [0-9]* time' | grep -o '[0-9]*' | head -1); ctl=${ctl:-0}
[ "$ctl" -ge 1 ] || { echo "REFUSED(2): the control run never reached rt_str_alloc (hits=$ctl) -- the stop at the 1,501st concat did not happen"; exit 2; }
bad=0; n=0
for spec in "0 0" "7 0" "8 0" "15 0" "16 0" "100 0" "740 0" "743 0" "-1 1" "-1 2" "-1 7" "-1 8" "-1 9" "-1 16" "-1 17"; do
  set -- $spec; out=$(hits $1 $2); got=$(printf '%s' "$out" | grep -o 'already hit [0-9]* time' | grep -o '[0-9]*' | head -1); got=${got:-0}
  printf '%s' "$out" | grep -q INJECTED || { echo "REFUSED(2): the injection at spec '$spec' did not happen: $out"; exit 2; }
  n=$((n+1)); [ "$got" -eq $((ctl+1)) ] || { echo "RED (2) an alias injected at spec '$spec' was NOT refused: rt_str_alloc hits=$got, control=$ctl"; bad=1; red=1; }
done
[ "$bad" -eq 0 ] && echo "ok  (2) all $n injected aliases (slots 0 7 8 15 16 100 740 743 and the last 1 2 7 8 9 16 17) refuse the in-place extension: rt_str_alloc hits $((ctl+1)) vs control $ctl"
lo=$( cd "$W" && ir_measure ./inj2000.bin ); hi=$( cd "$W" && ir_measure ./inj12000.bin )
ir_is_number "$lo" && ir_is_number "$hi" || { echo "REFUSED(2): the Ir reading is not a number (lo=$(ir_cell "$lo") hi=$(ir_cell "$hi")): $(ir_reason "$lo") $(ir_reason "$hi")"; exit 2; }
slope=$(( (hi - lo) / 10000 ))
if [ "$slope" -le 5000 ]; then echo "ok  (3) an in-place append over 1,143 global slots costs $slope instructions (<= 5000; before the unroll 8224)"
else echo "RED (3) an in-place append over 1,143 global slots costs $slope instructions (> 5000): the slot scan is the byte-at-a-time loop again"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: the in-place extension scan sees an alias in every global slot, answers the oracle, and costs 2.5 instructions a slot"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
