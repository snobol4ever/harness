#!/usr/bin/env bash
# test_gate_ir_reading_voids_a_dead_run.sh
#
# ⛔⭐ THE RULE: AN Ir READING FROM A RUN THAT DIED IS NOT A MEASUREMENT AND MUST NOT PRINT AS ONE.
# callgrind counts instructions whatever the client does, so a SEGV, a parse error or a timeout kill still
# hands back a well-formed PROGRAM TOTALS -- the count of the dying path, in the same shape as every honest
# cell.  ⭐ A crash that announces itself as a NUMBER is strictly worse than one that announces itself as a
# HOLE (hq_U -> hq_P, 2026-09-10), and hq_U asked that the void become the rule for EVERY Ir cell rather
# than the one board that caught it.  This gate is that rule with teeth.
#
# ⛔ IT DOES NOT REST ON A GREP.  ARM 1 is BEHAVIOURAL: it builds a program that really dies, really runs it
# under the shared reader, and requires the void.  A gate that only grepped for the word `rc` would pass on
# a script that captured the status and ignored it, and would fail on a correct one that spelled it
# differently.  ARM 2 is the census, and it exists only to answer "did a NEW call site skip the lib" -- so
# it names files, never judges shapes.
#
# ARM 1  the reader itself: clean run -> a number; SEGV -> REFUSED(rc=139); timeout -> REFUSED(rc=124);
#        instrument absent -> NOT-MEASURED(...).  All four DISTINGUISHABLE -- crashed is never unmeasured.
# ARM 2  every `valgrind --tool=callgrind` call site in ../harness/scripts/ either goes through lib_ir_measure.sh or
#        captures the exit status at the call.  A file that does neither is named and the gate FAILS.
#
# EXIT: 0 = both arms pass · 1 = a real violation · 2 = REFUSED, could not measure (never a silent pass).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE=ir-reading-voids-a-dead-run
FAIL=0
. "$HERE/lib_ir_measure.sh" 2>/dev/null || { echo "⛔ GATE REFUSES (rc=2) [$GATE]: cannot load lib_ir_measure.sh"; exit 2; }
command -v gcc >/dev/null 2>&1 || { echo "⛔ GATE REFUSES (rc=2) [$GATE]: gcc absent -- ARM 1 needs a program that really dies"; exit 2; }
ir_have_valgrind || { echo "⛔ GATE REFUSES (rc=2) [$GATE]: valgrind/callgrind_annotate absent -- this gate measures Ir and must not pass on a box that cannot"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/irgate.XXXXXX")" || { echo "⛔ GATE REFUSES (rc=2) [$GATE]: no work dir"; exit 2; }
trap 'rm -rf "$W"' EXIT
echo "=== ARM 1: the reader voids a dead run, and says which kind of dead ==="
cat > "$W/ok.c"    <<'EOF'
#include <stdio.h>
int main(void){ volatile int i,s=0; for(i=0;i<100000;i++) s+=i; printf("%d\n", s); return 0; }
EOF
cat > "$W/crash.c" <<'EOF'
#include <stdio.h>
int main(void){ volatile int i,s=0; for(i=0;i<100000;i++) s+=i; printf("%d\n", s); int *p=0; *p=1; return 0; }
EOF
cat > "$W/red.c"   <<'EOF'
int main(void){ return 3; }
EOF
gcc -O0 -o "$W/ok" "$W/ok.c" 2>/dev/null && gcc -O0 -o "$W/crash" "$W/crash.c" 2>/dev/null && gcc -O0 -o "$W/red" "$W/red.c" 2>/dev/null \
  || { echo "⛔ GATE REFUSES (rc=2) [$GATE]: could not build the witnesses"; exit 2; }
check() {  # label  expected-cell-prefix  value
    local label="$1" want="$2" v="$3" cell; cell="$(ir_cell "$v")"
    case "$cell" in
        "$want"*) echo "  OK   $label -> $cell" ;;
        *)        echo "  FAIL $label -> $cell (expected $want...)"; FAIL=1 ;;
    esac
}
V_OK="$(ir_measure "$W/ok")"
if ir_is_number "$V_OK"; then echo "  OK   clean run -> $V_OK (a number, and it is gradable)"
else echo "  FAIL clean run -> $(ir_cell "$V_OK") -- a program that exits 0 must produce a reading"; FAIL=1; fi
# ⛔ THE LOAD-BEARING ONE.  Prove the crashed run DOES still hand callgrind a well-formed total, so that the
# void below is voiding something real and not merely reporting an absence.  If this stops being true the
# gate should say so rather than quietly congratulate itself.
raw="$(valgrind --tool=callgrind --callgrind-out-file="$W/cg.crash" "$W/crash" >/dev/null 2>&1; callgrind_annotate "$W/cg.crash" 2>/dev/null | awk '/PROGRAM TOTALS/{gsub(/,/,"",$1); print $1; exit}')"
if [ -n "$raw" ]; then echo "  OK   the trap is REAL: the crashed run still yields a well-formed total ($raw Ir) to an unguarded reader"
else echo "  ⚠ NOTE: callgrind printed no total for the crashed run on this box -- the void is still required, but this box does not exhibit the trap"; fi
check "SEGV     " "REFUSED(rc=139)"   "$(ir_measure "$W/crash")"
check "exit 3   " "REFUSED(rc=3)"     "$(ir_measure "$W/red")"
check "timeout  " "REFUSED(rc=124)"   "$(IR_TMO=1 ir_measure sleep 30)"
check "no tool  " "NOT-MEASURED("     "$(PATH=/nonexistent ir_measure "$W/ok")"
# ⭐ AND THE DISTINCTION ITSELF IS THE POINT: a voided cell and an unmeasured cell must not print the same
# string.  This is the one assertion that would have caught the original defect's SECOND half.
if [ "$(ir_cell "$(ir_measure "$W/crash")")" = "$(ir_cell "$(PATH=/nonexistent ir_measure "$W/ok")")" ]; then
    echo "  FAIL a crashed cell and an unmeasured cell print IDENTICALLY -- the difference has been destroyed"; FAIL=1
else
    echo "  OK   crashed and unmeasured print differently"
fi
[ -n "$(ir_reason "$(ir_measure "$W/crash")")" ] || { echo "  FAIL a voided cell carries no reason -- a refusal without its why is a hole again"; FAIL=1; }
echo "=== ARM 2: census -- every callgrind call site is guarded ==="
UNGUARDED=""
for f in "$HERE"/*.sh; do
    # ⛔ A MENTION IS NOT A CALL SITE.  The first cut of this arm matched bench_wrap.sh, whose only hit is the
    # word `valgrind --tool=callgrind` inside a comment listing tools a reader might reach for.  A census that
    # counts prose finds violations that cannot be fixed, which is how a gate teaches people to ignore it.
    grep -vE '^[[:space:]]*#' "$f" | grep -q 'valgrind --tool=callgrind' || continue
    b="$(basename "$f")"
    [ "$b" = lib_ir_measure.sh ] && continue                       # the lib IS the guard
    [ "$b" = "$(basename "${BASH_SOURCE[0]}")" ] && continue        # this gate runs one on purpose, above
    grep -q 'lib_ir_measure.sh' "$f" && continue                    # goes through the one authority
    # otherwise it must capture the status AT the call: `rc=$?` / `|| ...` / `&& ...` on the same or next line
    if grep -vE '^[[:space:]]*#' "$f" | grep -A1 'valgrind --tool=callgrind' | grep -qE '(\|\||&&|rc=\$\?|RC=\$\?|\$\?)'; then continue; fi
    UNGUARDED="$UNGUARDED $b"
done
if [ -n "$UNGUARDED" ]; then
    echo "  FAIL these run callgrind and neither use lib_ir_measure.sh nor check the exit status at the call:"
    for b in $UNGUARDED; do echo "        $b"; done
    echo "        -> route the reading through lib_ir_measure.sh (ir_measure/ir_cell/ir_is_number/ir_reason)."
    FAIL=1
else
    echo "  OK   every callgrind call site in ../harness/scripts/ is guarded"
fi
if [ "$FAIL" -eq 0 ]; then echo "✅ GATE PASS [$GATE]"; exit 0; fi
echo "⛔ GATE FAIL [$GATE]"; exit 1
