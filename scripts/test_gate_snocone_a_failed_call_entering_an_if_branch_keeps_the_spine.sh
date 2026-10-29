#!/usr/bin/env bash
# test_gate_snocone_a_failed_call_entering_an_if_branch_keeps_the_spine.sh -- A FAILED OUT-OF-LINE CALL WHOSE OMEGA ENTERS AN IF
# BRANCH LEAVES THE ZETA SPINE WHERE THE BRANCH AND THE JOIN EXPECT IT (hq_snocone 2026-09-27, found under the Snocone beauty port:
# its GenTab's `if (~($'$B' = $'$B' ' ' DUPL(' ', negative)))` SIGSEGVs SCRIP m3 and m4 on corpus/demos/snobol4/beauty/beauty.in
# while the same program transpiled to SNOBOL4 runs byte-identical to the oracle on SCRIP m3, m4 and SPITBOL).
#
# THE WITNESS: function g(p) { if (~DUPL('a', p)) b = '!'; } g(-1);  -- SIGSEGV in m3 and m4 (a return through address 0x4, a DESCR
# tag). Also `if (DUPL('a', p)) b = '!'; else b = '?';` with the call failing, and at global scope inside a loop (the drift
# accumulates until the stack is gone). Fine: an inline predicate in the same place (LT, IDENT), an empty branch, `if (call)` with
# no else, `b = ~DUPL(...) '!'`, and the SNOBOL4 frontend on the transpiled form.
#
# MECHANISM, read from --dump-ir, --compile and SCRIP_ZD_DIAG=1 on the witness: the Snocone TT_IF lowering (lower_snobol4.c) makes
# a branch body a STMT_MARK sub-statement that rejoins the ENCLOSING statement's STATEMENT_END. The zeta-depth runs (emit.cpp,
# the [ZD] pass) cover the gamma spine only, so the body reached through the call's omega (the else body, or the then body under ~)
# belongs to no run: its boxes are emitted unmanaged (a LIT_STRING writes [rsp+80] with no sub), while the call's omega edge unwinds
# through the beta chain to the statement base and the join's STATEMENT_END then pops the full gamma-path depth again -- the
# procedure's gamma exit reads its saved frame 48-64 bytes off. `if (call)` with no else works because that omega edge targets the
# in-run STATEMENT_END and carries its own depth correction (add rsp, -32). Two lowerer-side experiments (strip the ~ into swapped
# branches; enter each branch through an IR_STATEMENT_BEGIN) did not cure it; the second made m4 worse. The cure is in the
# zeta-depth run model: an omega-reached branch body that rejoins an in-run node needs a run of its own (seeded at the depth its
# entry edge delivers) or an entry-edge correction to the depth its first box assumes.
#
# ARMS: 13 programs (9 witnesses, 4 controls) x (1) mode 3 and (2) mode 4; the ref of each is CUT FROM THE ORACLE at run time
# (scrip --transpile | sbl -bf); every program's output must match byte for byte and exit clean. RED BY DESIGN until the cure.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- this gate's refs are CUT FROM THE ORACLE at run time, never typed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
W=(
"W1 ~call then, in a function|function g(p) { if (~DUPL('a', p)) b = '!'; } g(-1); OUTPUT = 'b=' b;"
"W2 call else, failing and succeeding|function g(p) { if (DUPL('a', p)) b = '!'; else b = '?'; OUTPUT = b; } g(-1); g(1); OUTPUT = 'ok';"
"W3 ~~call else|function g(p) { if (~~DUPL('a', p)) b = '!'; else b = '?'; OUTPUT = b; } g(-1); g(1); OUTPUT = 'ok';"
"W4 ~(assign of a failing call), GenTab's shape|function g(p) { if (~(b = DUPL(' ', p))) b = '!'; OUTPUT = '[' b ']'; } g(-2); g(2); OUTPUT = 'ok';"
"W5 ~ of a user function that freturns|function ff(q) { freturn; } function g(p) { if (~ff(p)) b = '!'; OUTPUT = b; } g(1); OUTPUT = 'ok';"
"W6 ~call second in a concatenation|function g(p) { if (EQ(1,1) ~DUPL('a', p)) b = '!'; else b = '?'; OUTPUT = b; } g(-1); g(1); OUTPUT = 'ok';"
"W7 call else at global scope in a loop|i = 0; while (LT(i, 200000)) { if (DUPL('a', -1)) b = '!'; else b = '?'; i = i + 1; } OUTPUT = b i;"
"W8 ~call then at global scope in a loop|i = 0; while (LT(i, 200000)) { if (~DUPL('a', -1)) b = '!'; i = i + 1; } OUTPUT = b i;"
"W9 nested ifs with failing calls|function g(p, x) { if (DUPL('a', p)) { x = 'y' DUPL('b', 2); if (~DUPL('c', -1)) x = x '!'; } else { x = '?'; } OUTPUT = x; } g(-1); g(1);"
"C1 control: call with no else|function g(p) { if (DUPL('a', p)) b = '!'; OUTPUT = 'b=' b; } g(-1); OUTPUT = 'ok';"
"C2 control: inline predicate else|function g(p) { if (LT(p, 0)) b = '!'; else b = '?'; OUTPUT = b; } g(1); OUTPUT = 'ok';"
"C3 control: empty then|function g(p) { if (~DUPL('a', p)) ; OUTPUT = 'ok'; } g(-1);"
"C4 control: ~call inside an expression|function g(p) { b = ~DUPL('a', p) '!'; OUTPUT = b; } g(-1); OUTPUT = 'ok';"
)
RC=0; np=0; nf=0; bad=""
for w in "${W[@]}"; do
    name="${w%%|*}"; src="${w#*|}"; id="${name%% *}"
    printf '%s\n' "$src" > "$T/$id.sc"
    "$SCRIP" --transpile "$T/$id.sc" </dev/null > "$T/$id.sno" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: $id does not transpile -- no ref"; exit 2; }
    ref="$(cd "$T" && timeout -k 5 30s "$SBL" -bf "$id.sno" </dev/null 2>&1)"; rrc=$?
    [ "$rrc" = 0 ] && [ -n "$ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle did not run $id cleanly (rc=$rrc) -- no ref"; exit 2; }
    got3="$(timeout -k 5 30s "$SCRIP" "$T/$id.sc" </dev/null 2>&1)"; r3=$?
    "$SCRIP" --compile "$T/$id.sc" --out="$T/$id.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/$id.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$T/$id" 2>"$T/ld.log" \
        || { echo "⛔ GATE REFUSE(2) [$G]: $id mode-4 compile or link failed, so arm 2 measured nothing"; exit 2; }
    got4="$(timeout -k 5 30s "$T/$id" </dev/null 2>&1)"; r4=$?
    v3=PASS; { [ "$r3" = 0 ] && [ "$got3" = "$ref" ]; } || v3="FAIL(rc=$r3)"
    v4=PASS; { [ "$r4" = 0 ] && [ "$got4" = "$ref" ]; } || v4="FAIL(rc=$r4)"
    echo "  $name: m3 $v3  m4 $v4"
    for v in "$v3" "$v4"; do if [ "$v" = PASS ]; then np=$((np + 1)); else nf=$((nf + 1)); RC=1; fi; done
    [ "$v3$v4" = PASSPASS ] || bad="$bad $id"
done
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: a failed call entering an if branch keeps the spine, in both modes ($np of $((np + nf)) arms, 13 programs)"
else echo "⛔ GATE FAIL(1) [$G]: $nf of $((np + nf)) arms diverge from the oracle ($bad) -- a branch reached through a failed call's omega runs off the zeta spine"; fi
exit $RC
