#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_gz5b.sh — PL-GZ-5b gate: ζ-TREE child frames + RECURSION on the Proebsting-pure path.
# Each call SITE owns a child-frame pointer slot in the CALLER's frame (the seed's `&ζ->p2_ζ`);
# `rt_enter(slot,nslots)` = reuse-or-alloc; register protocol mirrors the seed's print form
# `path(&ζ->p2_ζ, α, a0, a1)`: call δ with rdi=child rsi/rdx=arg cell pointers, call ε with rdi=child
# ONLY (args already live in the child frame); callee α/β push the caller ζ and enter the child
# (mov r12,rdi). Callee slots = clause slots DIRECT; mark at [ζ+0]; const args of NESTED calls become
# synthetic cells APPENDED TO THE CALLEE'S LOCALS (covered by its per-activation cells_init); child
# slots sit after locals, OUTSIDE the init range (rt_enter reads before write — fresh frames are
# zeroed by GC_malloc / the query frame by BSS). Recursion depth works because every activation has
# its own frame, hence its own child slots. Admit-time recursion terminates via the shell-first memo;
# emission discovers nested callees via a worklist. Probes: m2 == m3 == m4 BYTE-IDENTICAL on the new
# path. Negatives: arity-3 rule preds refuse (ar>2 is outside the rsi/rdx arg ABI); arith bodies refuse.
set -u
cd "$(dirname "$0")/../../SCRIP"
SCRIP=./scrip
RT=out/libscrip_rt.so
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "GATE-PL-GZ5B FAIL: $1"; exit 1; }
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

run_admitted nested   ':- initialization(main).\ninner(X) :- X = a.\nouter(Y) :- inner(Y).\nmain :- outer(Q), write(Q), nl.\n' 'a\n'
grep -q "rt_enter" "$TMP/nested.s" || fail "nested m4 .s lacks the rt_enter child-frame call (ζ-tree path not taken)"
run_admitted calleesynth ':- initialization(main).\nb(Y) :- Y = done.\na(X) :- write(X), nl, b(done).\nmain :- a(hi), write(ok), nl.\n' 'hi\nok\n'
run_admitted selfrec  ':- initialization(main).\nr(X) :- write(X), nl, X = go, r(stop).\nmain :- r(go).\n' 'go\nstop\n'

printf ':- initialization(main).\nt3(A,B,C) :- A = B, B = C.\nmain :- t3(a,X,Y), write(X), write(Y), nl.\n' > "$TMP/neg1.pl"
"$SCRIP" --run "$TMP/neg1.pl" </dev/null > "$TMP/n13" 2>"$TMP/ne13" || fail "neg1 m3 rc"
grep -q "INTERP-FALLBACK" "$TMP/ne13" || fail "neg1 (arity-3 rule pred) m3 did NOT show the loud fallback (GZ wrongly admitted?)"
"$SCRIP" --compile --target=x86 "$TMP/neg1.pl" > "$TMP/n1.s" 2>/dev/null || fail "neg1 m4 compile rc"
grep -q "gzq\|gzp" "$TMP/n1.s" && fail "neg1 (arity-3 rule pred) m4 .s has gz labels (GZ wrongly admitted)"

printf ':- initialization(main).\nf(X) :- Y is X + 1, write(Y), nl.\ng(Z) :- f(Z).\nmain :- g(1).\n' > "$TMP/neg2.pl"
"$SCRIP" --run "$TMP/neg2.pl" </dev/null > "$TMP/n23" 2>"$TMP/ne23" || fail "neg2 m3 rc"
grep -q "INTERP-FALLBACK" "$TMP/ne23" || fail "neg2 (arith body behind a nested call) m3 did NOT show the loud fallback (GZ wrongly admitted?)"
"$SCRIP" --compile --target=x86 "$TMP/neg2.pl" > "$TMP/n2.s" 2>/dev/null || fail "neg2 m4 compile rc"
grep -q "gzq\|gzp" "$TMP/n2.s" && fail "neg2 (arith body behind a nested call) m4 .s has gz labels (GZ wrongly admitted)"

echo "GATE-PL-GZ5B PASS: ζ-tree child frames (rt_enter reuse-or-alloc, per-site child slots, caller-ζ push/restore) + nested and self-recursive user-predicate calls (callee-frame synth cells for nested const args; per-activation frames make depth sound) m2==m3==m4 byte-identical on the GZ path; arity-3 and deep-arith rule preds refused identically by both branches"
exit 0
