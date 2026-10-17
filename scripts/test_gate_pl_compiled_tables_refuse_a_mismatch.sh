#!/usr/bin/env bash
# test_gate_pl_compiled_tables_refuse_a_mismatch.sh -- a mode-4 program's compiled atom table and functor table are installed into
# the runtime's interners at module_init, and an install whose leading rows disagree with what the runtime already interned must
# REFUSE (exit 2 with the message naming the row) rather than run a program whose ids mean different terms (R1.3, SCRIP cf3ed3dd5;
# the cto's review check 2026-09-27: "that mode 4's .Lpl_functor_tab install refuses rc 2 on a mismatch in a witness, not only in
# prose"; ARCH-PROLOG-BB-REWRITE.md section 3: the compiler interns, module_init registers the table with the one runtime interner).
#
# THE SHAPE, MEASURED. The runtime's prolog_atom_init interns five atoms (. [] true fail !) and the functor ./2 BEFORE the tables are
# installed, in the same order the compiler did, so the tables' leading rows must be exactly those. rt_pl_atom_table_install and
# rt_pl_functor_table_install re-intern every row in order and refuse when a row's id is not its index -- which fires exactly when a
# leading row is not what the runtime already holds. THE BOUNDARY, NAMED: a permutation of two LATER rows is self-consistent to the
# installer (each fresh pair takes the next id) and is NOT caught here -- it would mis-name terms, which the suites see, not this gate.
# MEASURED BEFORE THE CURE (SCRIP cf3ed3dd5): both swapped programs RAN, rc 0, printing mis-named terms ([b|g(1,g(2,[]))] and
# g(b,[](1,[](2,true)))) -- in mode 4 the install is the first Prolog act of the process, so the per-row check (id != index) could
# never fire. The cure: the functor install ends by running prolog_atom_init and refusing unless the five init atoms read ids 0..4 and
# ./2 reads functor 0 -- the order every compiled table carries by construction, because the compiler's parse begins with that init.
#
# METHOD: compile a witness with atoms and compounds to .s; (a) the pristine .s links and runs, its output equal to mode 3's;
# (b) the .s with the functor table's first two data rows swapped links and exits 2 naming the functor row; (c) the .s with the atom
# table's first pointer row swapped with its sixth exits 2 naming the atom row. REFUSE rc=2 when scrip, gcc or the tables are absent.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; G=pl_compiled_tables_refuse_a_mismatch
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/pltab.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/w.pl" <<'EOF'
p(X) :- X = f(a, g(b, [1, 2]), 'Quoted', h(c)).
main :- p(X), writeq(X), nl, X =.. [N | Args], writeq(N), nl, length(Args, K), write(K), nl, functor(X, _, A), write(A), nl.
:- initialization(main).
EOF
"$ROOT/scrip" "$W/w.pl" < /dev/null > "$W/m3.out" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not run in mode 3 ($(head -c 120 "$W/m3.out"))"; exit 2; }
"$ROOT/scrip" --compile -o "$W/w.s" "$W/w.pl" < /dev/null > "$W/c.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not compile ($(head -c 120 "$W/c.err"))"; exit 2; }
grep -q '^\.Lpl_functor_tab:' "$W/w.s" && grep -q '^\.Lpl_atom_tab:' "$W/w.s" || { echo "GATE REFUSED(2) [$G]: the .s carries no .Lpl_functor_tab / .Lpl_atom_tab -- the table emission moved; re-aim this gate"; exit 2; }
link() { gcc -no-pie -o "$2" "$1" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$2.link" 2>&1; }
bad=0
link "$W/w.s" "$W/w.bin" || { echo "GATE REFUSED(2) [$G]: the pristine .s does not link ($(head -c 120 "$W/w.bin.link"))"; exit 2; }
timeout -k 5 8 "$W/w.bin" < /dev/null > "$W/m4.out" 2>&1; rc=$?
if [ $rc -ne 0 ] || ! cmp -s "$W/m3.out" "$W/m4.out"; then echo "  RED (a): the pristine mode-4 binary rc=$rc or its output differs from mode 3"; diff "$W/m3.out" "$W/m4.out" | head -4; bad=1; else echo "  ok  (a): pristine .s links, runs, output equal to mode 3 ($(wc -l < "$W/m4.out") lines)"; fi
# (b) swap the functor table's first two rows (the label and the count share one line; rows are `.quad name, arity`): row 0 must be ./2, the functor the runtime interned at init
awk 'BEGIN{s=0} /^\.Lpl_functor_tab:/{s=1; print; next} s==1 && /^[[:space:]]+\.quad[[:space:]]+[0-9]+, [0-9]+$/ {r0=$0; s=2; next} s==2 && /^[[:space:]]+\.quad[[:space:]]+[0-9]+, [0-9]+$/ {print; print r0; s=3; next} {print}' "$W/w.s" > "$W/f.s"
cmp -s "$W/w.s" "$W/f.s" && { echo "GATE REFUSED(2) [$G]: the functor-table swap changed nothing -- fewer than two functor rows; re-aim the witness"; exit 2; }
if link "$W/f.s" "$W/f.bin"; then timeout -k 5 8 "$W/f.bin" < /dev/null > "$W/f.out" 2>&1; rc=$?
  if [ $rc -eq 2 ] && grep -qE 'compiled (functor table|atom and functor tables) do(es)? not match' "$W/f.out"; then echo "  ok  (b): swapped functor rows -> exit 2, '$(grep -oE 'functor [0-9]+ \([^)]*\) took id [0-9]+|\./2 reads functor [0-9]+' "$W/f.out" | head -1)'"; else echo "  RED (b): swapped functor rows ran rc=$rc without the refusal: $(head -c 160 "$W/f.out")"; bad=1; fi
else echo "  RED (b): the swapped .s did not link ($(head -c 120 "$W/f.bin.link"))"; bad=1; fi
# (c) swap the atom table's first pointer row (atom 0, the runtime's '.') with its sixth (the first program atom); rows are `.quad .Lpl_atomK, LEN` (the text's byte length, so code 0 is an element)
awk 'BEGIN{s=0; n=0} /^\.Lpl_atom_tab:/{s=1; print; next} s==1 && /^[[:space:]]+\.quad[[:space:]]+\.Lpl_atom[0-9]+, [0-9]+$/ { n++; if (n==1) { r0=$0; next } if (n==6) { print; print r0; s=2; next } print; next } {print}' "$W/w.s" > "$W/a.s"
cmp -s "$W/w.s" "$W/a.s" && { echo "GATE REFUSED(2) [$G]: the atom-table swap changed nothing -- fewer than six atom rows; re-aim the witness"; exit 2; }
if link "$W/a.s" "$W/a.bin"; then timeout -k 5 8 "$W/a.bin" < /dev/null > "$W/a.out" 2>&1; rc=$?
  if [ $rc -eq 2 ] && grep -qE 'compiled (atom table|atom and functor tables) do(es)? not match' "$W/a.out"; then echo "  ok  (c): swapped atom rows -> exit 2, '$(grep -oE "atom [0-9]+ '[^']*' took id [0-9]+|read ids [0-9 ]+" "$W/a.out" | head -1)'"; else echo "  RED (c): swapped atom rows ran rc=$rc without the refusal: $(head -c 160 "$W/a.out")"; bad=1; fi
else echo "  RED (c): the swapped .s did not link ($(head -c 120 "$W/a.bin.link"))"; bad=1; fi
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: the compiled atom and functor tables install when they match the runtime's init order and REFUSE exit 2 when a leading row does not (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a compiled-table mismatch did not refuse, or the pristine witness did not run (tree SCRIP=$TREE)"; exit 1
