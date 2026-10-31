#!/usr/bin/env bash
# test_gate_pl_a_directive_goal_wakes_an_attributed_variable_at_the_binding_as_swipl.sh -- a binding made by a DIRECTIVE goal (or an initialization/1 goal) wakes the
# attributed variable's goals right after the binding goal, as swipl does, and not at the next clause entry. THE RED (hq_prolog 2026-10-31, SCRIP 64f869ae8, both modes):
#   :- lazy_findall(X, member(X,[1,2,3]), L), L = [A|_], writeln(first(A)).
# printed first(_G0) where swipl prints first(1); a put_attr/freeze hook fired AFTER the writeln that follows the binding; the hook of a directive's last binding fired in the
# NEXT directive, and the last directive's never ran. The same goals inside a clause body, or in initialization(main), already answered as swipl.
# THE CAUSE: a clause body gets  ( $wake_pending -> $wakeup ; true )  after each binding goal (pl_attv_body / pl_attv_goal in lower_prolog.c, when pl_attv_on()), but the
# top-level main/0 body that carries every directive and initialization goal is built by pl_body_graph from the goals as written, so a wake raised there stayed pending
# until the next clause entry. THE CURE: pl_attv_dir applies pl_attv_goal to dir_goals and the initialization goals. Row
# prolog-lazy-findall-delivers-the-first-element-when-its-lazy-list-is-unified-with-a-cons-as-swipl.
# THE WITNESS AND ITS REF, cut from swipl 9.0.4 with every variable name normalised to _ and blank lines dropped (the same sed runs on SCRIP's output):
# fixtures/hb_pl_attvar_wakes_in_a_directive_goal.pl, 11 shapes: a lazy list's first and first two elements, a hook on a cons, an atom and a structure, freeze under an
# if-then-else, under \+ \+, a hook that fails under an if-then-else, a conjunction after the binding, an initialization/1 goal, and a last directive whose wake used to be lost.
# ARMS: (1) mode 3 and (2) mode 4 equal the ref. THE REF IS RE-CUT from the live swipl on every run and the gate REFUSES rc=2 when the oracle disagrees with the table.
# FAIL_ONCE=1 grades against a ref with its first line removed, so every arm must red.
# Usage: bash ../harness/scripts/test_gate_pl_a_directive_goal_wakes_an_attributed_variable_at_the_binding_as_swipl.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=pl_a_directive_goal_wakes
SWIPL=/usr/bin/swipl
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -x "$SWIPL" ] || { echo "GATE REFUSED(2) [$G]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
S1="$HERE/fixtures/hb_pl_attvar_wakes_in_a_directive_goal.pl"
[ -f "$S1" ] && [ -s "${S1%.pl}.ref" ] || { echo "GATE REFUSED(2) [$G]: the witness or its ref is missing ($S1)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/pldirwake.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cp "$S1" "$W/r.pl"
norm() { sed -E 's/_[A-Z]?[0-9]+/_/g; /^$/d'; }
"$SWIPL" -q "$W/r.pl" -t halt < /dev/null 2> /dev/null | norm > "$W/oracle.ref"
cmp -s "$W/oracle.ref" "${S1%.pl}.ref" || { echo "GATE REFUSED(2) [$G]: the live swipl disagrees with the table's ref (diff follows) -- re-cut the ref from the oracle"; diff "${S1%.pl}.ref" "$W/oracle.ref" | head -6; exit 2; }
if [ "${FAIL_ONCE:-0}" = 1 ]; then sed '1d' "${S1%.pl}.ref" > "$W/r.ref"; else cp "${S1%.pl}.ref" "$W/r.ref"; fi
( cd "$W" && "$ROOT/scrip" --compile --out="$W/r.s" "$W/r.pl" < /dev/null > "$W/r.cerr" 2>&1 ) || { echo "GATE REFUSED(2) [$G]: the witness does not compile ($(head -c 120 "$W/r.cerr"))"; exit 2; }
gcc -o "$W/r.bin" "$W/r.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/r.lerr" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not link"; exit 2; }
run_arm() {
    local n="$1" mode="$2" rc
    if [ "$mode" = m3 ]; then ( cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB timeout -k 5 300 "$ROOT/scrip" "$W/r.pl" < /dev/null > "$W/$n.out" 2> "$W/$n.err" ); rc=$?
    else ( cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB timeout -k 5 300 "$W/r.bin" < /dev/null > "$W/$n.out" 2> "$W/$n.err" ); rc=$?; fi
    norm < "$W/$n.out" > "$W/$n.txt"
    if [ "$rc" -ne 0 ] || ! cmp -s "$W/$n.txt" "$W/r.ref"; then echo "  RED ($n) $mode: rc=$rc, the output differs from swipl's:"; diff "$W/r.ref" "$W/$n.txt" | head -8; return 1; fi
    echo "  ok  ($n) $mode: rc 0, the $(wc -l < "$W/r.ref") swipl lines"
    return 0
}
bad=0
run_arm 1 m3 || bad=1
run_arm 2 m4 || bad=1
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a directive or initialization goal wakes an attributed variable's goals at the binding, as swipl does, in both modes (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a directive or initialization goal wakes an attributed variable's goals late or not at all (tree SCRIP=$TREE)"; exit 1
