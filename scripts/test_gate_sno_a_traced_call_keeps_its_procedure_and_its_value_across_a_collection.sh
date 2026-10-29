#!/usr/bin/env bash
# test_gate_sno_a_traced_call_keeps_its_procedure_and_its_value_across_a_collection.sh -- A TRACE FUNCTION MAY COLLECT
#
# MEASURED 2026-10-02 by the cto (row snobol4-ais-test-mode-4-drops-a-return-trace-block-after-a-collection-first-bad-3e494a406,
# ceo CEO-1402/1403): AIS TEST lost the RETURN trace block of ASSOCL and its returned list in mode 4 at the shipped 1024 KB window,
# right at 128 KB and 4 MB, and in BOTH modes under SCRIP_GC_STRESS=1. Two defects, one class -- a C or template holder of a heap
# address kept across a call that runs the user's TRACE function, which allocates and so can collect:
#  (1) src/runtime/rt/rt.c: rt_proc_call_prologue and rt_proc_call_prologue_lex fire the CALL trace (rt_trace_event_args), and
#      every caller then read its raw rt_proc_t pointer into g_rt_gen_procs -- a rooted vector the collector slides -- so
#      rt_call_proc_descr_p computed the epilogue's index from the stale pointer (slot 5 read as slot 6 after a 0x90 slide) and
#      the epilogue restored and returned another procedure's result: a CODE-built function returned null and its RETURN trace
#      never fired. The prologues now take rt_proc_t ** and re-seat the caller's pointer from the slot index after the event.
#  (2) src/templates/bb/bb_define.cpp: the gamma shim pushed the return DESCR as {pointer below, tag above} -- the reverse of a
#      DESCR -- across rt_trace_return_hook and its poll, so the spine walk never forwarded the pointer and the shim returned
#      twelve NUL bytes for a twelve-byte string. The pairs are pushed in DESCR order and the value is re-read from the result
#      cell after the hook, which is also SPITBOL's order: a trace function that assigns F changes what the call returns.
# ARMS: each of three witnesses against the live sbl -bf oracle in m3 and m4 -- (a) a static function with CALL and RETURN
# traces under SCRIP_GC_STRESS=1, (b) a RETURN trace function that assigns the function's value, at the default arena, (c) a
# CODE-built function with a CALL trace under SCRIP_GC_STRESS=1 -- every stress run must report collections>0 on its
# SCRIP_GC_EXERCISE line or the arm REFUSES; then (d) the comparison can say no: each witness run with --stlimit but with every
# TRACE( line deleted and so no trace function called, must differ from the oracle.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"; RT="$ROOT/out"
[ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: cannot load lib_oracle_flags.sh"; exit 2; }
SBL="$(sbl_clean_bin 2>/dev/null)"; [ -x "${SBL:-}" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no SPITBOL oracle"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/wa.sno" <<'EOW'
 DEFINE('F(X,Y)A')
 DEFINE('TF(N,T)')  :(TFE)
TF OUTPUT = 'TF ' N ' ' T ' X=' X ' F=' F :(RETURN)
TFE
 TRACE('F','CALL',,'TF')
 TRACE('F','RETURN',,'TF')
 &TRACE = 10000
 OUTPUT = 'R=' F('abc', 'def')
 OUTPUT = 'after'                  :(END)
F A = X Y
 F = A A                            :(RETURN)
END
EOW
cat > "$T/wb.sno" <<'EOW'
 DEFINE('F(X,Y)A')
 DEFINE('TF(N,T)')  :(TFE)
TF OUTPUT = 'TF ' N ' F=' F
 F = IDENT(T,'RET') 'changed-by-tf'  :(RETURN)
TFE
 TRACE('F','RETURN','RET','TF')
 &TRACE = 10000
 OUTPUT = 'R=' F('abc', 'def')
 OUTPUT = 'F after=' F    :(END)
F A = X Y
 F = A A                            :(RETURN)
END
EOW
cat > "$T/wc.sno" <<'EOW'
 C = CODE(" DEFINE('F(X,Y)A') :(FE)" ';'
+ "F OUTPUT = 'inF X=' X ' Y=' Y ; A = X Y ;"
+ " F = A A :(RETURN) ;"
+ "FE :(BACK)")                            :F(BAD)
 :<C>
BACK
 DEFINE('TF(N,T)')  :(TFE)
TF OUTPUT = 'TF ' N ' ' T ' F=' F :(RETURN)
TFE
 TRACE('F','CALL',,'TF')
 &TRACE = 10000
 OUTPUT = 'R=' F('abc', 'def')
 OUTPUT = 'after'                  :(END)
BAD OUTPUT = 'CODE failed'
END
EOW
RC=0; N=0
run() {
  local m="$1" w="$2" fl="$3" st="$4" x="$T/$2.$1.$4$3"
  if [ "$m" = m3 ]; then
    env SCRIP_GC_STRESS="$st" SCRIP_GC_EXERCISE=1 timeout -k 5 60 "$SCRIP" $fl "$T/$w.sno" </dev/null >"$x.out" 2>"$x.err"
  else
    "$SCRIP" --compile $fl --out="$x.s" "$T/$w.sno" </dev/null >/dev/null 2>&1 || { echo COMPILE-FAIL >"$x.out"; return; }
    gcc -no-pie -o "$x.bin" "$x.s" -L"$RT" -Wl,-rpath,"$RT" -lscrip_rt -lm >/dev/null 2>&1 || { echo LINK-FAIL >"$x.out"; return; }
    env SCRIP_GC_STRESS="$st" SCRIP_GC_EXERCISE=1 timeout -k 5 60 "$x.bin" </dev/null >"$x.out" 2>"$x.err"
  fi
}
grade() {
  local w="$1" st="$2" what="$3" want got col
  want=$("$SBL" -bf "$T/$w.sno" </dev/null 2>/dev/null); [ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for $w"; exit 2; }
  for m in m3 m4; do
    N=$((N+1)); run $m "$w" --stlimit "$st"; local x="$T/$w.$m.$st--stlimit"
    got=$(grep -av '^\[GC-' "$x.out" | tr '\0' '@')
    col=$(cat "$x.out" "$x.err" | grep -ao 'collections=[0-9]*' | tail -1 | cut -d= -f2)
    if [ "$st" != 0 ] && [ "${col:-0}" -eq 0 ]; then echo "⛔ GATE REFUSE(2) [$G]: $w $m under SCRIP_GC_STRESS=$st reported collections=${col:-none} -- a run that never collected proves nothing about a collection"; exit 2; fi
    if [ "$got" = "$want" ]; then echo "  ($what) $w $m stress=$st collections=${col:-?} vs oracle PASS"
    else echo "  ($what) $w $m stress=$st collections=${col:-?} vs oracle FAIL: got [$(printf '%s' "$got" | tr '\n\0' ' @' | cut -c1-120)] want [$(printf '%s' "$want" | tr '\n' ' ' | cut -c1-120)]"; RC=1; fi
  done
}
grade wa 1 a
grade wb 0 b
grade wc 1 c
for w in wa wb wc; do
  want=$("$SBL" -bf "$T/$w.sno" </dev/null 2>/dev/null)
  grep -v "TRACE('F'" "$T/$w.sno" > "$T/${w}n.sno"
  for m in m3 m4; do
    N=$((N+1)); run $m "${w}n" --stlimit 0; got=$(grep -av '^\[GC-' "$T/${w}n.$m.0--stlimit.out" | tr '\0' '@')
    if [ "$got" != "$want" ]; then echo "  (d) $w $m with its TRACE lines deleted differs from the oracle PASS -- the comparison can say no"
    else echo "  (d) $w $m with its TRACE lines deleted EQUALS the oracle FAIL -- the trace is not what this witness grades"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N arms -- a traced call keeps its procedure and its value across a collection in the CALL and RETURN trace functions, m3 and m4, and the RETURN value is read after the trace function as SPITBOL reads it"
else echo "GATE FAIL(1) [$G]: see the arms above"; fi
exit $RC
