#!/usr/bin/env bash
# test_gate_pl_first_argument_indexing_survives_the_wake_up_lowering_as_swipl.sh -- A TWO-CLAUSE LIST PREDICATE CALLED WITH A BOUND FIRST ARGUMENT LEAVES NO CHOICE POINT IN A PROGRAM THAT WAKES
# ATTRIBUTED VARIABLES, AS swipl RUNS IT (hq_prolog 2026-10-29, row prolog-first-argument-indexing-survives-the-wake-up-lowering-of-attributed-variable-programs; hq_runtime's measurement under
# ARCH-PROLOG-CLPR-CHR section 8, cto CTO-397).
#
# The program lowering of a program that wakes attributed variables (pl_attv_on: the clpfd, CHR or dif runtime is linked) turns the head unification of every clause into a body goal followed by the
# wake-up poll (pl_attv_body in lower_prolog.c). The first-argument index test needs no unification and must stay AHEAD of that road: only a first argument that is an attributed variable takes the wake
# road. Without it len([], N) matches clause 1 and clause 2 stays behind as a choice point, so call_cleanup/2 never sees the goal exit deterministically and a CHR loop leaks a frame per activation
# (hq_runtime's cuts in generated code and the support set stay, harmless under indexing). The witness arms the wake road with one clpfd constraint (X #= 1+1) and asks three calls of
# len/2 whether they exited deterministically; the expected text is cut from swipl 9 in THIS run (swipl_bin), mode 3 and mode 4.
# rc=0 every cell agrees with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build, swipl did not answer).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=pl_first_argument_indexing_survives_the_wake_up_lowering_as_swipl
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -f "$ROOT/out/libscrip_rt.so" ] || { echo "GATE REFUSED(2) [$G]: out/libscrip_rt.so is not built -- mode 4 cannot link"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plidx.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/w.pl" <<'EOF'
:- use_module(library(clpfd)).
len([], 0).
len([_|T], N) :- len(T, M), N is M+1.
t(G) :- call_cleanup(G, Det = true), ( Det == true -> D = det ; D = nondet ), write(G-D), nl.
main :- X #= 1+1, write(X), nl, t(len([], _)), t(len([a], _)), t(len([a,b,c], _)).
:- initialization(main).
EOF
timeout -k 5 20 "$SW" -q -t halt "$W/w.pl" < /dev/null > "$W/w.ref" 2> "$W/ref.err"
[ "$(grep -c . "$W/w.ref")" -eq 4 ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the 4 probe lines ($(grep -c . "$W/w.ref") of them; $(head -c 160 "$W/ref.err"))"; exit 2; }
"$ROOT/scrip" "$W/w.pl" < /dev/null > "$W/m3.out" 2>&1; r3=$?
"$ROOT/scrip" --compile -o "$W/w.s" "$W/w.pl" < /dev/null > "$W/c.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not compile ($(head -c 120 "$W/c.err"))"; exit 2; }
gcc -no-pie -o "$W/w.bin" "$W/w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/link.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not link ($(head -c 120 "$W/link.err"))"; exit 2; }
timeout -k 5 20 "$W/w.bin" < /dev/null > "$W/m4.out" 2>&1; r4=$?
bad=0
for m in m3 m4; do rc=$([ $m = m3 ] && echo $r3 || echo $r4)
    if [ "$rc" -eq 0 ] && cmp -s "$W/$m.out" "$W/w.ref"; then echo "  ok  $m: rc=0, the 4 lines as swipl ($(tr '\n' ' ' < "$W/w.ref"))"; else echo "  RED $m: rc=$rc, swipl prints $(tr '\n' ' ' < "$W/w.ref") and SCRIP prints $(tr '\n' ' ' < "$W/$m.out" | head -c 200)"; bad=1; fi
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: len/2 called with a bound first argument exits deterministically in a program that wakes attributed variables, in both modes as swipl (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a two-clause list predicate leaves a choice point under the wake-up lowering where swipl's first-argument index leaves none (tree SCRIP=$TREE)"; exit 1
