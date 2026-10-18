#!/usr/bin/env bash
# test_gate_pl_a_zero_arity_term_is_the_atom_in_both_modes.sh -- `foo()` read from source and by read_term_from_atom/3 is the ATOM
# foo in both modes: atom/1 holds, functor/3 gives foo/0, arg/3 on it raises type_error(compound, foo), and no zero-arity compound
# cell (a DT_PLREF whose functor has arity 0) ever exists. Pinned at R1.3 (SCRIP cf3ed3dd5) because that landing dropped the
# arity-nonzero test from bb_call_pl_leaf.cpp's PLR_COMP guard (a compound's slen is a functor id now, not arity-packed), keeping
# the tag test alone; the cto asked for the zero-arity shape to be a witness in both modes, not prose (2026-09-27).
#
# THE STANDARD AND THE ORACLES, NAMED. ISO 13211-1 has no `foo()` (it is a syntax error); SWI-Prolog 7+ reads it as a compound with
# zero arguments and its functor/3 raises domain_error(compound_non_zero_arity, foo()) -- ORACLE-DIVERGENT by the cto's ruling (an
# SWI-7 extension outside the ISO superset SCRIP carries); GNU Prolog refuses `foo()` as a syntax error. SCRIP's choice, measured
# on the tree before R1.3 and after it: the reader yields the atom. This gate pins that choice and that the two modes agree; the
# expected text is written here, not cut from an oracle, because no oracle carries this superset choice.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=pl_a_zero_arity_term_is_the_atom_in_both_modes
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plzero.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/z.pl" <<'EOF'
main :- X = foo(), ( atom(X) -> write(atom) ; compound(X) -> write(compound) ; write(other) ), nl,
    functor(X, N, A), writeq(N/A), nl,
    catch((arg(1, foo(), _), write(arg_succeeded)), error(E, _), writeq(E)), nl,
    read_term_from_atom('bar()', T, []), ( atom(T) -> write(atom) ; compound(T) -> write(compound) ; write(other) ), nl,
    ( T == bar -> write(same_as_atom) ; write(not_the_atom) ), nl,
    catch((functor(T, TN, TA), writeq(TN/TA)), error(E2, _), writeq(E2)), nl.
:- initialization(main).
EOF
printf 'atom\nfoo/0\ntype_error(compound,foo)\natom\nsame_as_atom\nbar/0\n' > "$W/z.ref"
"$ROOT/scrip" "$W/z.pl" < /dev/null > "$W/m3.out" 2>&1; r3=$?
"$ROOT/scrip" --compile -o "$W/z.s" "$W/z.pl" < /dev/null > "$W/c.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not compile ($(head -c 120 "$W/c.err"))"; exit 2; }
gcc -no-pie -o "$W/z.bin" "$W/z.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/link.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not link ($(head -c 120 "$W/link.err"))"; exit 2; }
timeout -k 5 8 "$W/z.bin" < /dev/null > "$W/m4.out" 2>&1; r4=$?
bad=0
for m in m3 m4; do rc=$([ $m = m3 ] && echo $r3 || echo $r4)
  if [ "$rc" -eq 0 ] && cmp -s "$W/$m.out" "$W/z.ref"; then echo "  ok  $m: rc=0, the six lines as pinned"; else echo "  RED $m: rc=$rc, output differs from the pin:"; diff "$W/z.ref" "$W/$m.out" | head -6; bad=1; fi; done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: foo() is the atom foo in both modes -- atom/1 holds, functor/3 reads foo/0, arg/3 raises type_error(compound, foo), read_term_from_atom agrees (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a zero-arity term is not the atom in one mode, or the modes disagree (tree SCRIP=$TREE)"; exit 1
