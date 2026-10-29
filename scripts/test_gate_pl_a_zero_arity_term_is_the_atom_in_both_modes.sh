#!/usr/bin/env bash
# test_gate_pl_a_zero_arity_term_is_the_atom_in_both_modes.sh -- `foo()` read from source and by read_term_from_atom/3 is a ZERO-ARITY COMPOUND
# in both modes, answering as swipl 9 answers it (the file name keeps the retired pin's words: the Makefile, gate_wiring.tsv and the blocking
# set name it, and a rename is a separate landing). atom/1 fails, compound/1 holds, functor/3, =../2 and compound_name_arity/3 raise or answer
# exactly as swipl does, arg/3 fails, `foo() == foo` fails, and the two modes agree with the oracle line for line.
#
# HISTORY. Pinned at R1.3 (SCRIP cf3ed3dd5, cto 2026-09-27) as "the reader yields the atom": the expected text was WRITTEN HERE, not cut from an
# oracle, because the choice was SCRIP's own. SCRIP ec412dc27 (2026-10-17, cfo) reversed the choice on purpose -- `a()` is a zero-arity compound
# distinct from the atom `a`, as SWI-7 reads it, core/test_term 50 -> 53 of 54 -- and left this pin behind, so the blocking arm read RED on a
# tree that was right (the ceo found it red at c33d10f89 and at 037114866, CEO-1995). The probe below is cut from swipl in THIS run
# (swipl_bin), never from SCRIP's output and never written by hand, so the gate can no longer disagree with the oracle it claims to follow.
# ISO 13211-1 has no `foo()` (a syntax error, GNU Prolog refuses it too); SWI-Prolog 7+ is the oracle for the superset choice.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=pl_a_zero_arity_term_is_the_atom_in_both_modes
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plzero.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/z.pl" <<'EOF'
t(G) :- catch((G -> write(yes) ; write(no)), error(E, _), writeq(E)), nl.
main :- X = foo(), t(atom(X)), t(compound(X)), t(functor(X, _, _)), t(arg(1, X, _)), t(X == foo),
    t(compound_name_arity(X, _, _)), t(X =.. _),
    read_term_from_atom('bar()', T, []), t(atom(T)), t(compound(T)), t(T == bar), t(compound_name_arguments(T, _, _)).
:- initialization(main).
EOF
timeout -k 5 20 "$SW" -q -t halt "$W/z.pl" < /dev/null > "$W/z.ref" 2> "$W/ref.err"
[ "$(grep -c . "$W/z.ref")" -eq 11 ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the 11 probe lines ($(grep -c . "$W/z.ref") of them; $(head -c 160 "$W/ref.err"))"; exit 2; }
"$ROOT/scrip" "$W/z.pl" < /dev/null > "$W/m3.out" 2>&1; r3=$?
"$ROOT/scrip" --compile --out="$W/z.s" "$W/z.pl" < /dev/null > "$W/c.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not compile ($(head -c 120 "$W/c.err"))"; exit 2; }
gcc -no-pie -o "$W/z.bin" "$W/z.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/link.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not link ($(head -c 120 "$W/link.err"))"; exit 2; }
timeout -k 5 8 "$W/z.bin" < /dev/null > "$W/m4.out" 2>&1; r4=$?
bad=0
for m in m3 m4; do rc=$([ $m = m3 ] && echo $r3 || echo $r4)
  if [ "$rc" -eq 0 ] && cmp -s "$W/$m.out" "$W/z.ref"; then echo "  ok  $m: rc=0, the 11 lines as swipl"; else echo "  RED $m: rc=$rc, output differs from swipl:"; diff "$W/z.ref" "$W/$m.out" | head -6; bad=1; fi; done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: foo() is a zero-arity compound in both modes and every probe line answers as swipl -- atom/1 fails, compound/1 holds, functor/3 and =../2 raise domain_error(compound_non_zero_arity, foo()), read_term_from_atom agrees (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a zero-arity term answers differently from swipl in one mode, or the modes disagree (tree SCRIP=$TREE)"; exit 1
