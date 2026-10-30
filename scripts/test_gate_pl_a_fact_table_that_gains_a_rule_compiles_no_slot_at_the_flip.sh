#!/usr/bin/env bash
# test_gate_pl_a_fact_table_that_gains_a_rule_compiles_no_slot_at_the_flip.sh -- THE FLIP COMPILES NO SLOT (ARCH-PROLOG-DATABASE section 5 narrowed to the flip and section 13 item 3; hq_runtime, row prolog-a-fact-table-that-gains-a-rule-compiles-no-slot-at-the-flip-only-the-slots-calls-reach, CEO-2018):
# a predicate of ground facts that gains its first rule or non-ground fact leaves the data path and, since f03f48c89, compiled EVERY live slot at that assert (a 100,000-fact table paid
# 100,000 compiles). Now it compiles the new clause and the one slot the entry names, and any other slot when a call's walk first reaches it (the chain-omega calls rt_pl_db_slot_ensure
# on a slot with no fragment and walks on).
#   ARM 1 (answers): a witness over a table that gains a rule (rule among facts, asserta after the flip, a retract, a keyed call into the rule, a call past the facts, a second table with
#     a rule that runs after its facts, a rule asserted first), cut from swipl in THIS run and compared with SCRIP's mode 3 and mode 4.
#   ARM 2 (the count): the runtime's own count of compiled slots, the compiled= field of the [PL-RECLAIM] line under SCRIP_PL_RECLAIM_REPORT=1, read after the flip of a 300-fact table
#     (at most 3: the rule, the entry slot, one spare), after a call that reaches ten facts (between 5 and 40), and after a full enumeration (at least 300, so the count is seen to rise);
#     both modes.
# The count is the runtime's, never a clock or an instruction count of a compile.
set -u
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plflip.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/wit.pl" <<'PL'
:- dynamic f/1, g/2.
:- forall(between(1, 40, I), assertz(f(I))).
:- assertz((f(X) :- between(101, 102, X))).
:- asserta(f(0)).
:- retract(f(5)).
:- findall(X, f(X), L), length(L, N), write(N), nl.
:- f(101), write(yes101), nl.
:- ( f(103) -> write(yes103) ; write(no103) ), nl.
:- f(0), f(40), write(ends), nl.
:- forall(between(1, 40, I), ( J is I * 2, assertz(g(I, J)) )).
:- assertz((g(K, V) :- between(41, 45, K), V is K * 2)).
:- g(41, V), write(V), nl.
:- g(7, V), write(V), nl.
:- findall(K-V, ( g(K, V), K mod 20 =:= 0 ), L2), write(L2), nl.
:- assertz(g(50, odd)), findall(W, g(50, W), L3), write(L3), nl.
:- retract(f(1)), retract(f(2)), findall(X, ( f(X), X < 6 ), L4), write(L4), nl.
:- assertz((h(Z) :- Z = first)), assertz(h(second)), findall(Z, h(Z), L5), write(L5), nl.
PL
cat > "$W/cnt.pl" <<'PL'
:- dynamic f/1.
:- forall(between(1, 300, I), assertz(f(I))).
:- assertz((f(X) :- X = rule)).
:- retract(f(1)).
:- ( f(10) -> true ; true ).
:- retract(f(2)).
:- findall(X, f(X), L), length(L, N), write(N), nl.
:- retract(f(3)).
PL
build() { "$ROOT/scrip" --compile --out="$W/$1.s" "$W/$1.pl" < /dev/null > "$W/$1.c.err" 2>&1 && gcc -no-pie -o "$W/$1.bin" "$W/$1.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/$1.l.err" 2>&1; }
bad=0
norm() { sed -e 's/_G*[0-9][0-9]*/_V/g' "$1"; }
timeout -k 5 60 "$SW" -q -t halt "$W/wit.pl" < /dev/null > "$W/wit.ref" 2> "$W/wit.ref.err"
[ "$(grep -c . "$W/wit.ref")" -ge 8 ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the witness ($(head -c 160 "$W/wit.ref.err"))"; exit 2; }
timeout -k 5 120 "$ROOT/scrip" "$W/wit.pl" < /dev/null > "$W/wit.m3" 2> "$W/wit.m3.err"
build wit || { echo "GATE REFUSED(2) [$G]: the witness does not build ($(head -c 160 "$W/wit.c.err" "$W/wit.l.err"))"; exit 2; }
timeout -k 5 120 "$W/wit.bin" < /dev/null > "$W/wit.m4" 2> "$W/wit.m4.err"
sed '1s/.*/corrupted/' "$W/wit.ref" > "$W/wit.bad"
if cmp -s "$W/wit.m3" "$W/wit.bad"; then echo "GATE REFUSED(2) [$G]: the comparison accepted a corrupted reference -- the gate could not fail"; exit 2; fi
for m in m3 m4; do
  if cmp -s "$W/wit.$m" "$W/wit.ref"; then echo "  ok  arm 1 $m: the table that gains a rule answers as swipl ($(grep -c . "$W/wit.ref") lines)"; else echo "  RED arm 1 $m: differs from swipl:"; diff "$W/wit.ref" "$W/wit.$m" | head -8; bad=1; fi
done
build cnt || { echo "GATE REFUSED(2) [$G]: the count program does not build"; exit 2; }
SCRIP_PL_RECLAIM_REPORT=1 timeout -k 5 120 "$ROOT/scrip" "$W/cnt.pl" < /dev/null > /dev/null 2> "$W/cnt.m3.err"
SCRIP_PL_RECLAIM_REPORT=1 timeout -k 5 120 "$W/cnt.bin" < /dev/null > /dev/null 2> "$W/cnt.m4.err"
for m in m3 m4; do
  c=($(grep -o ' compiled=[0-9]*' "$W/cnt.$m.err" | cut -d= -f2))
  if [ "${#c[@]}" -ne 3 ]; then echo "GATE REFUSED(2) [$G]: $m printed ${#c[@]} reports, want 3 (the instrument could not read the count)"; exit 2; fi
  if [ "${c[0]}" -le 3 ] && [ "${c[1]}" -ge 5 ] && [ "${c[1]}" -le 40 ] && [ "${c[2]}" -ge 300 ]; then
    echo "  ok  arm 2 $m: compiled slots ${c[0]} after the flip of a 300-fact table (want at most 3), ${c[1]} after a call that reaches ten facts, ${c[2]} after a full enumeration"
  else echo "  RED arm 2 $m: compiled slots ${c[0]} / ${c[1]} / ${c[2]} (want at most 3, 5 to 40, at least 300)"; bad=1; fi
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a fact table that gains a rule compiles no slot at the flip, compiles the slots a call reaches, and answers as swipl in both modes (self-test: a corrupted reference is seen, the full enumeration raises the count) (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: the flip compiles slots a call has not reached, or the table differs from swipl (tree SCRIP=$TREE)"; exit 1
