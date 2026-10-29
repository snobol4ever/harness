#!/usr/bin/env bash
# test_gate_pl_a_local_definition_overrides_the_weak_import_of_a_module_file_as_swipl.sh -- A PREDICATE THE PROGRAM DEFINES LOCALLY WINS OVER THE SAME NAME AND ARITY A MODULE FILE EXPORTS AND
# THE PROGRAM IMPORTS WITH use_module/1, AND THE MODULE'S OWN CALLS KEEP THE MODULE'S DEFINITION, AS swipl RUNS IT (hq_prolog 2026-10-28, ProPuzzles hakank_swi_quasigroup_completion).
#
# swipl: the import is weak, "Local definition of user:bar/1 overrides weak import from u" -- the program's bar/1 is the only bar/1 it sees, while module u's helper/1, which calls bar/1 inside u,
# still reaches u's own bar/1. SCRIP flattens modules by qualified rename (prolog_lower.c pl_module_flatten): an EXPORTED predicate kept the plain key, and the program's clauses and the
# module's clauses of that key merged into one predicate (local([2,3,1]) and helper([2,3,1]) where swipl prints local([1]) and helper([2,3]); quasigroup_completion printed its solution
# 128 times, its domain_matrix/2 defined locally and exported by hakank_utils). Now, in the SWI dialect, an export the program's own context also defines is module-private (u:bar).
#
# Three programs, each a main file beside the module file u.pl, expected text cut from swipl 9 in THIS run (swipl_bin), mode 3 and mode 4:
#   a  the program defines bar/1 and imports u            -> local([1]) helper([2,3])
#   b  the program defines nothing and imports u           -> imp([2,3]) helper([2,3])   (the import still reaches the module's clauses)
#   c  the program defines bar/1 under :- multifile bar/1 -> mf([1])                      (swipl still lets the local definition win; the module's bar/1 is another predicate)
# rc=0 every cell agrees with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build, swipl did not answer).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=pl_a_local_definition_overrides_the_weak_import_of_a_module_file_as_swipl
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -f "$ROOT/out/libscrip_rt.so" ] || { echo "GATE REFUSED(2) [$G]: out/libscrip_rt.so is not built -- mode 4 cannot link"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plwimp.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/u.pl" <<'EOF'
:- module(u, [bar/1, helper/1]).
bar(2).
bar(3).
helper(X) :- bar(X).
EOF
cat > "$W/a.pl" <<'EOF'
:- use_module(u).
bar(1).
main :- findall(X, bar(X), L), write(local(L)), nl, findall(Y, helper(Y), M), write(helper(M)), nl.
:- initialization(main).
EOF
cat > "$W/b.pl" <<'EOF'
:- use_module(u).
main :- findall(X, bar(X), L), write(imp(L)), nl, findall(Y, helper(Y), M), write(helper(M)), nl.
:- initialization(main).
EOF
cat > "$W/c.pl" <<'EOF'
:- use_module(u).
:- multifile bar/1.
bar(1).
main :- findall(X, bar(X), L), write(mf(L)), nl.
:- initialization(main).
EOF
bad=0
for c in a b c; do
    ( cd "$W" && timeout -k 5 20 "$SW" -q -t halt "$c.pl" < /dev/null > "$c.ref" 2> /dev/null )
    [ -s "$W/$c.ref" ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer program $c"; exit 2; }
    ( cd "$W" && timeout -k 5 30 "$ROOT/scrip" "$c.pl" < /dev/null > "$c.m3" 2>&1 ); r3=$?
    ( cd "$W" && timeout -k 5 60 "$ROOT/scrip" --compile --out="$c.s" "$c.pl" < /dev/null > "$c.cerr" 2>&1 && gcc -no-pie -o "$c.bin" "$c.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$c.lerr" 2>&1 ) || { echo "GATE REFUSED(2) [$G]: program $c does not compile or link in mode 4 ($(head -c 120 "$W/$c.cerr" "$W/$c.lerr" 2>/dev/null | tr '\n' ' '))"; exit 2; }
    ( cd "$W" && timeout -k 5 20 "./$c.bin" < /dev/null > "$c.m4" 2>&1 ); r4=$?
    for m in m3 m4; do rc=$([ $m = m3 ] && echo $r3 || echo $r4)
        if [ "$rc" -eq 0 ] && cmp -s "$W/$c.ref" "$W/$c.$m"; then echo "  ok  $c $m: rc=0, as swipl ($(tr '\n' ' ' < "$W/$c.ref"))"
        else echo "  RED $c $m: rc=$rc, swipl prints $(tr '\n' ' ' < "$W/$c.ref") and SCRIP prints $(tr '\n' ' ' < "$W/$c.$m")"; bad=1; fi
    done
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a local definition overrides the weak import of a module file and the module keeps its own, a plain import still reaches the module, in both modes as swipl (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a local definition and a module file's export of the same predicate answer differently from swipl (tree SCRIP=$TREE)"; exit 1
