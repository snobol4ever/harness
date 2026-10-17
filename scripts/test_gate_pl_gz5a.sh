#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_gz5a.sh — PL-GZ-5a gate: user-predicate CALLS on the Proebsting-pure path — the
# first rung of conj+recursion (PL-GZ-5). The callee entry labels reach the call box as two new
# port fills (δ = callee α, ε = callee β) alongside γ/ω/β: the seed's call IS a port edge to
# another box's α. Single-clause rule callees only (non-recursive, arity ≤ 2): callee shares the
# query ζ=r12 frame at an admit-assigned base; α saves arg CELL POINTERS into its slots (head
# vars ARE the params), re-inits locals per activation (the seed enter() law), marks the trail in
# its own row; γ/ω land verdict-in-rax and ret to the call box's λ; β re-pushes and jumps into
# the body redo chain (δ). Caller const args materialize as synthetic query cells + unify-const.
# Probes (admitted): m2 == m3 == m4 stdout BYTE-IDENTICAL, both branches on the new path.
# Negatives: 2-clause rule pred + nested call refuse IDENTICALLY via pl_gz_admit (m3 loud
# fallback, m4 no gz labels) — recursion therefore stays refused until 5b's rt_enter ζ-tree.
set -u
cd "$(dirname "$0")/../../SCRIP"
SCRIP=./scrip
RT=out/libscrip_rt.so
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "GATE-PL-GZ5A FAIL: $1"; exit 1; }
[ -x "$SCRIP" ] || fail "scrip binary missing (make scrip)"
[ -f "$RT" ]    || fail "libscrip_rt.so missing (make libscrip_rt)"

run_admitted() { # $1=name $2=program(printf-format) $3=expected_stdout(printf-format)
  local NM=$1 PRG=$2 EXP=$3
  printf "$PRG" > "$TMP/$NM.pl"
  "$SCRIP" --run "$TMP/$NM.pl" </dev/null > "$TMP/$NM.o2" 2>/dev/null || fail "$NM m2 rc"
  "$SCRIP" --run    "$TMP/$NM.pl" </dev/null > "$TMP/$NM.o3" 2>"$TMP/$NM.e3" || fail "$NM m3 rc"
  grep -q "INTERP-FALLBACK" "$TMP/$NM.e3" && fail "$NM m3 fell back to the interpreter (GZ path not taken)"
  "$SCRIP" --compile --target=x86 "$TMP/$NM.pl" > "$TMP/$NM.s" 2>/dev/null || fail "$NM m4 compile rc"
  grep -q "gzp" "$TMP/$NM.s" || fail "$NM m4 .s lacks gzp callee labels (call path not taken)"
  as -o "$TMP/$NM.o" "$TMP/$NM.s" 2>/dev/null || fail "$NM m4 as"
  gcc -no-pie "$TMP/$NM.o" -L out -lscrip_rt -Wl,-rpath,"$PWD/out" -o "$TMP/$NM.bin" 2>/dev/null || fail "$NM m4 link"
  "$TMP/$NM.bin" </dev/null > "$TMP/$NM.o4" || fail "$NM m4 run rc"
  cmp -s "$TMP/$NM.o2" "$TMP/$NM.o3" || fail "$NM m2 vs m3 stdout differ"
  cmp -s "$TMP/$NM.o2" "$TMP/$NM.o4" || fail "$NM m2 vs m4 stdout differ"
  printf "$EXP" | cmp -s - "$TMP/$NM.o2" || fail "$NM m2 output is not expected"
}

run_admitted basic    ':- initialization(main).\ngreet(X) :- write(X), nl.\nmain :- greet(hello).\n' 'hello\n'
grep -q "CELL_CALL" "$TMP/basic.s"    || fail "basic m4 .s lacks the CELL_CALL box (call not on the GZ path)"
grep -q "CALLEE_FRAME" "$TMP/basic.s" || fail "basic m4 .s lacks the CALLEE_FRAME box (callee not on the GZ path)"
run_admitted valflow  ':- initialization(main).\nbind(X) :- X = a.\nmain :- bind(Q), write(Q), nl.\n' 'a\n'
run_admitted twocalls ':- initialization(main).\ngreet(X) :- write(X), nl.\nmain :- greet(hi), greet(yo).\n' 'hi\nyo\n'
run_admitted callfail ':- initialization(main).\neq(X, Y) :- X = Y.\nmain :- eq(a, b), write(no), nl.\n' ''
run_admitted localvar ':- initialization(main).\nmk(X) :- Y = b, X = Y.\nmain :- mk(Q), write(Q), nl.\n' 'b\n'
run_admitted realpha  ':- initialization(main).\nfact(a).\nfact(b).\nwant(X) :- X = b.\nmain :- fact(F), want(F), write(F), nl.\n' 'b\n'
run_admitted redocall ':- initialization(main).\nfact(1).\nfact(2).\nok(X) :- X = a.\nmain :- fact(N), ok(Z), N = 2, write(N), nl.\n' '2\n'
run_admitted crossvar ':- initialization(main).\nsame(X, X).\nmain :- same(a, a), write(y), nl, same(b, c).\n' 'y\n'

printf ':- initialization(main).\nt3(A,B,C) :- A = B, B = C.\nmain :- t3(a,X,Y), write(X), write(Y), nl.\n' > "$TMP/neg1.pl"
"$SCRIP" --run "$TMP/neg1.pl" </dev/null > "$TMP/n13" 2>"$TMP/ne13" || fail "neg1 m3 rc"
grep -q "INTERP-FALLBACK" "$TMP/ne13" || fail "neg1 (arity-3 rule pred) m3 did NOT show the loud fallback (GZ wrongly admitted?)"
"$SCRIP" --compile --target=x86 "$TMP/neg1.pl" > "$TMP/n1.s" 2>/dev/null || fail "neg1 m4 compile rc"
grep -q "gzq\|gzp" "$TMP/n1.s" && fail "neg1 (arity-3 rule pred) m4 .s has gz labels (GZ wrongly admitted)"

printf ':- initialization(main).\nq(X) :- X = f(a).\nmain :- q(Z), write(Z), nl.\n' > "$TMP/neg2.pl"
"$SCRIP" --run "$TMP/neg2.pl" </dev/null > "$TMP/n23" 2>"$TMP/ne23" || fail "neg2 m3 rc"
grep -q "INTERP-FALLBACK" "$TMP/ne23" || fail "neg2 (compound in rule body) m3 did NOT show the loud fallback (GZ wrongly admitted?)"
"$SCRIP" --compile --target=x86 "$TMP/neg2.pl" > "$TMP/n2.s" 2>/dev/null || fail "neg2 m4 compile rc"
grep -q "gzq\|gzp" "$TMP/n2.s" && fail "neg2 (compound in rule body) m4 .s has gz labels (GZ wrongly admitted)"

echo "GATE-PL-GZ5A PASS: user-predicate calls via δ/ε port fills (call box + callee frame: arg cell-pointer marshaling, value flow out through head vars, per-activation locals, trail mark/unwind in the callee row, redo re-entry via ε, choice-driven α re-entry, cross-var heads) m2==m3==m4 byte-identical on the GZ path; arity-3 and compound-body rule preds refused identically by both branches"
exit 0
