#!/usr/bin/env bash
# test_gate_one_function_installs_a_compiled_proc_for_the_mode_3_loop_and_raku_eval.sh -- THE PER-PROC REGISTER, EMIT AND INSTALL IS ONE LIBRARY FUNCTION, CALLED BY THE MODE-3 LOOP AND BY RAKU EVAL,
# AND THE EVAL PATH NAMES NO RAKU TREE KIND (row raku-every-suite-to-100-under-nonet-ceo-1266; the cto's YES to the fold, re-raku-eval-hashes-for-review 2026-10-07, two conditions in one landing).
#
# ⛔ THE DEFECT: scrip.c's mode-3 loop and runtime_eval.c's rk_emit_new_procs each carried a copy of the same thirty steps -- register the proc and its properties, set the frame floor, pick the jmp entry, emit_chain,
# register the GC frame map and site table, set the frame bytes, the fn, the thunk record, the entry cells, the zstatic bit, the patzeta record, the generator region and the direct-call entry. Copies drift: the Prolog run-time
# definer's copy of the two GC registration lines had drifted to none, and the cfo measured 301 polls in 300 asserts that no walk could name. rt_raku_eval_compile also re-parented Raku tree kinds (TT_SUB_DECL,
# TT_CLASS_DECL, the tail return) inside the shared runtime_eval.c, ahead of the lowerer, against A PARSER MOVES NOTHING; THE LOWERER PLACES IT.
# ⛔ THE CURE: src/driver/driver_procs.c owns driver_register_proc (rt_proc_register + nformals), driver_proc_props (generator, jmpentry, pinned, variadic, rest_kind, named_rest, dyn_scope, result_name) and driver_install_proc (everything from
# the frame floor to the direct-call entry, with a before/after hook pair for the SNOBOL4 label-body aliases). scrip.c's register_procs_all and its mode-3 loop, and rk_emit_new_procs, call them and name none of the steps.
# lower_raku_eval_stage2 takes the parsed tree whole, places the EVAL sub, lowers it and returns its name; runtime_eval.c holds only rk_parse_tree, that call and the install.
#
# THE ARMS (source census, no build, ~0.1s):
#   1  src/driver/driver_procs.c defines driver_register_proc, driver_proc_props and driver_install_proc, once each (moved out of emit.cpp by the cfo's road row L3(b), CEO-1990:
#      registration is the driver's, and the emitter takes the planner's road as a parameter)
#   2  rk_emit_new_procs calls driver_register_proc, driver_proc_props and driver_install_proc and names none of the install steps
#   3  scrip.c calls driver_install_proc once, calls driver_register_proc and driver_proc_props from register_procs_all, and its mode-3 loop names no install step
#   4  rt_raku_eval_compile names no tree kind and builds no tree node
#   5  lower_raku.c defines lower_raku_eval_stage2 (returning the EVAL proc's name) and the SUB_DECL placement lives there
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (a source file or a function is missing, so nothing was measured).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
G="test_gate_one_function_installs_a_compiled_proc_for_the_mode_3_loop_and_raku_eval"
refuse() { echo "⛔ GATE REFUSED(2) [$G]: $1"; exit 2; }
EMIT="$ROOT/src/driver/driver_procs.c"; SCR="$ROOT/src/driver/scrip.c"; EVL="$ROOT/src/runtime/runtime_eval.c"; LRK="$ROOT/src/lower/lower_raku.c"
for f in "$EMIT" "$SCR" "$EVL" "$LRK"; do [ -f "$f" ] || refuse "no source file $f -- nothing to measure"; done
body() { awk -v s="$2" 'index($0, s) == 1 { f = 1 } f { print } f && /^}/ { exit }' "$1"; }
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
STEPS='emit_chain|rt_proc_set_fn|bb_thunk_rec_fill|bb_ab_seal_entry_cells|emit_patzeta_register|rt_proc_set_dcfn|emit_gc_tables_register|rt_proc_set_frame_bytes|emit_jmp_entry_for_road|rt_proc_register|rt_proc_set_gen_region_ft'
n=0; for fn in driver_register_proc driver_proc_props driver_install_proc; do c=$(grep -cE "^[a-z][a-z_ *]* \**$fn\(" "$EMIT"); [ "$c" = 1 ] && n=$((n+1)); done
if [ "$n" = 3 ]; then ck ok "(1) driver_procs.c defines driver_register_proc, driver_proc_props and driver_install_proc once each"
else ck no "(1) driver_procs.c defines $n of the 3 install functions exactly once -- the per-proc install has no single home"; fi
RK="$(body "$EVL" 'static int rk_emit_new_procs')"; [ -n "$RK" ] || refuse "no rk_emit_new_procs in runtime_eval.c"
named="$(printf '%s\n' "$RK" | grep -oE "\b($STEPS)\b" | sort -u | tr '\n' ' ')"
calls=0; for fn in driver_register_proc driver_proc_props driver_install_proc; do printf '%s\n' "$RK" | grep -q "$fn(" && calls=$((calls+1)); done
if [ "$calls" = 3 ] && [ -z "$named" ]; then ck ok "(2) rk_emit_new_procs installs through driver_register_proc, driver_proc_props and driver_install_proc and names no install step"
else ck no "(2) rk_emit_new_procs calls $calls of the 3 install functions and names the steps: ${named:-none} -- a copy of the install"; fi
sites=$(grep -c 'driver_install_proc(' "$SCR"); RP="$(body "$SCR" 'static void register_procs_all')"; [ -n "$RP" ] || refuse "no register_procs_all in scrip.c"
rcalls=0; for fn in driver_register_proc driver_proc_props; do printf '%s\n' "$RP" | grep -q "$fn(" && rcalls=$((rcalls+1)); done
M3="$(awk '/int _lbl_owned = sn4_lbl_owners\(s2, _lbl_own\);/{n++} n>=2{print} n>=2&&/core_icn_startup_error_no_main\(\);/{exit}' "$SCR")"; [ -n "$M3" ] || refuse "no mode-3 per-proc loop (the second sn4_lbl_owners site) in scrip.c"
tail_named="$(printf '%s\n' "$M3" | grep -oE "\b($STEPS)\b" | sort -u | tr '\n' ' ')"
if [ "$sites" = 1 ] && [ "$rcalls" = 2 ] && [ -z "$tail_named" ]; then ck ok "(3) scrip.c installs through one driver_install_proc call and registers through driver_register_proc and driver_proc_props"
else ck no "(3) scrip.c has $sites driver_install_proc call(s) (want 1), register_procs_all calls $rcalls of 2 register functions, and its mode-3 loop names the install steps: ${tail_named:-none}"; fi
EV="$(body "$EVL" 'const char *rt_raku_eval_compile')"; [ -n "$EV" ] || refuse "no rt_raku_eval_compile in runtime_eval.c"
kinds="$(printf '%s\n' "$EV" | grep -oE '\b(TT_[A-Z_]+|ast_node_new|ast_push|lc_stmt_subj|lower_raku_tail_return)\b' | sort -u | tr '\n' ' ')"
if [ -z "$kinds" ]; then ck ok "(4) rt_raku_eval_compile names no tree kind and builds no tree node"
else ck no "(4) rt_raku_eval_compile re-parents Raku trees in the shared runtime: ${kinds}-- the lowerer places the EVAL sub"; fi
LE="$(body "$LRK" 'const char * lower_raku_eval_stage2')"
if [ -n "$LE" ] && printf '%s\n' "$LE" | grep -q 'TT_SUB_DECL' && printf '%s\n' "$LE" | grep -q 'rk_stage2_core'; then ck ok "(5) lower_raku_eval_stage2 returns the EVAL proc's name and places the EVAL sub itself"
else ck no "(5) lower_raku.c has no lower_raku_eval_stage2 that places the EVAL sub (TT_SUB_DECL) and lowers it through rk_stage2_core"; fi
echo "population: $checks arm(s) graded, $fails FAIL"
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$G]"; exit 0; fi
echo "⛔ GATE RED [$G]: $fails of $checks arms FAIL"; exit 1
