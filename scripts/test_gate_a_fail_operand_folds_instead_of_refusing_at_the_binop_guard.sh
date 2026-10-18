#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_a_fail_operand_folds_instead_of_refusing_at_the_binop_guard.sh -- AN OPERAND THAT CAN NEVER PRODUCE A
# VALUE MAKES ITS CONSUMER UNREACHABLE, AND AN UNREACHABLE NODE IS FOLDED, NEVER REFUSED AT A GUARD.
# Row icon-a-binop-whose-operand-is-fail-aborts-at-the-emit-guard-instead-of-folding (cto, 2026-09-11), from the
# coo's IPL compile-tier report: corpus/packages/icon/ipl/progs/fset.icn aborted rc=134 with
#   FATAL emit_drive: IR op=3 HAS a template and its own case REFUSED AT A GUARD -- emit.cpp:1571
# op=3 is IR_BINOP and 1571 is its operand-slot guard. `1 || fail` lowers to a BINOP whose second operand is an
# IR_FAIL node, IR_FAIL carries no result slot, so emit_binop_opnd_slot returned -1 and the guard refused a node
# that can never be entered at all. cf_run now folds such a node to IR_FAIL before the emitter ever sees it.
#
# ⛔ `fail` IS NOT `&fail` AND THE ORACLE IS THE ONLY THING THAT SETTLES IT. In Icon, `fail` makes the ENCLOSING
# PROCEDURE fail immediately, so `suspend 1 | fail | 3` yields 1 and NOT 1,3 -- a first cut of this cure rewired
# a fail-entry disjunction branch to the next alternative, which reads like the obvious fix, matched no oracle,
# and was reverted. Every expectation below is PINNED from Arizona icont/iconx 9.5 (/home/resources/icon-master),
# measured 2026-09-11; the gate is hermetic and never consults the oracle at run time.
#
# ⛔ p06/p07 ARE THE LOAD-BEARING CONTROLS, not padding: the fold deletes a node, and the way to break it is to
# delete more than the unreachable one. p06 is the same alternation with no `fail` in it and must still generate
# all three; p07 puts a SIDE EFFECT in the folded BINOP's live operand and must still print it, because the fold
# rewrites only the consumer and must leave the operands it dropped wired and running.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh"
GATE_NAME="a_fail_operand_folds_instead_of_refusing_at_the_binop_guard"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="$ROOT/out"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: scrip not built at $SCRIP"; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: $RT/libscrip_rt.so missing -- mode 4 cannot link"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not on PATH -- mode 4 cannot link"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_failopnd.XXXXXX")" || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
gate_bin_watch "$SCRIP" "$RT/libscrip_rt.so"

probe() { printf '%s\n' "$3" > "$W/$1.icn"; printf '%s' "$2" > "$W/$1.want"; }
probe p01_concat_fail    ''        'procedure main(); every write(f()); end
procedure f(); suspend (1 || fail) | 2; end'
probe p02_two_alts       ''        'procedure main(); every write(f()); end
procedure f(); suspend (1 || fail) | 2 | ("a" || "b"); end'
probe p03_after_a_yield  '7'       'procedure main(); every write(f()); end
procedure f(); suspend 7 | (1 || fail) | 2; end'
probe p04_bare_fail_alt  ''        'procedure main(); every write(f()); end
procedure f(); suspend fail | 2; end'
probe p05_fail_mid_alt   '1'       'procedure main(); every write(f()); end
procedure f(); suspend 1 | fail | 3; end'
probe p06_no_fail_ctl    '1|2|3'   'procedure main(); every write(f()); end
procedure f(); suspend 1 | 2 | 3; end'
probe p07_side_effect    'side'    'procedure main(); every write(f()); end
procedure f(); suspend (write("side") || fail) | 2; end'
probe p08_arith_fail     ''        'procedure main(); every write(f()); end
procedure f(); suspend (1 + fail) | 2; end'

red=0; n=0
for src in "$W"/p*.icn; do
    b="$(basename "$src" .icn)"; want="$(cat "$W/$b.want")"; n=$((n+1))
    m3="$(cd "$W" && timeout -k 5 20 "$SCRIP" "$b.icn" </dev/null 2>/dev/null | tr '\n' '|' | sed 's/|$//')"
    m4="(compile/link failed)"
    if (cd "$W" && "$SCRIP" --compile "$b.icn" </dev/null > "$b.s" 2>/dev/null && gcc -c "$b.s" -o "$b.o" 2>/dev/null \
        && gcc "$b.o" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$b.m4" 2>/dev/null); then
        m4="$(cd "$W" && timeout -k 5 20 "./$b.m4" </dev/null 2>/dev/null | tr '\n' '|' | sed 's/|$//')"
    fi
    v=GREEN; { [ "$m3" = "$want" ] && [ "$m4" = "$want" ]; } || { v=RED; red=$((red+1)); }
    printf '  %-18s want=%-7s m3=%-7s m4=%-7s %s\n' "$b" "[$want]" "[$m3]" "[$m4]" "$v"
done

# THE ABORT ARM: the cure is only real if the guard sink is never reached, and an output-only comparison cannot
# see the difference between a folded node and a node whose abort happened to print nothing on stdout.
for src in "$W"/p*.icn; do
    b="$(basename "$src" .icn)"
    err="$(cd "$W" && "$SCRIP" --compile "$b.icn" </dev/null 2>&1 >/dev/null)"; rc=$?
    n=$((n+1))
    if [ $rc -eq 134 ] || printf '%s' "$err" | grep -q "REFUSED AT A GUARD"; then
        printf '  %-18s m4 compile TRIPPED THE GUARD SINK (rc=%s) RED\n' "$b" "$rc"; red=$((red+1))
    fi
done
gate_bin_unmoved
GATE_EXAMINED="$n arms ($((n/2)) probes x m3+m4 output, $((n/2)) x guard-sink absence)"
gate_floor "$n" 16 "arms run"
gate_verdict "$red" "arm(s) disagree with the pinned iconx 9.5 output or tripped the emit guard sink"
