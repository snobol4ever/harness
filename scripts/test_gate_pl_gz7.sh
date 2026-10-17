#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# GATE PL-GZ-7 (ITE-commit canon, m2 oracle to paper §4.5 / SWI C_LCUT).
# Pins the LANDED half of PL-GZ-7: the m2 oracle now commits the condition of (Cond -> Then ; Else)
# at first success (IR_ITE marks the CP ledger at entry; IR_ITE_COMMIT on cond.γ truncates the
# condition's choicepoints; IR_ITE_GATE on cond.ω routes post-commit condition exhaustion to ω
# instead of Else — the paper §4.5 E1.fail gate), and \+ / \= share the same bounded condition.
# The headline ( a(X),X>=2 -> true ; X=0 ) fail-driven prints exactly 2 (was 2 3 0), matching m4.
# This gate pins m2 == m3 == m4 == canon on the commit shapes via the legacy ITE path; the ITE is
# semidet at construct level (β = ω_in), agreeing with the m4 flat_drive_ite β→ω tombstone.
# The new-path §4.5 box (IR_CELL_ITE admission onto the GZ substrate) is the rung's REMAINING half
# and is not yet gated here.
set -u
cd "$(dirname "$0")/../../SCRIP"
SCRIP=./scrip
RT=out/libscrip_rt.so
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "GATE-PL-GZ7 FAIL: $1"; exit 1; }
[ -x "$SCRIP" ] || fail "scrip binary missing (make scrip)"
[ -f "$RT" ]    || fail "libscrip_rt.so missing (make libscrip_rt)"
m4_run() { # $1=name ; compiles $TMP/$1.pl -> runs -> stdout in $TMP/$1.o4
  local NM=$1
  "$SCRIP" --compile --target=x86 "$TMP/$NM.pl" > "$TMP/$NM.s" 2>/dev/null || fail "$NM m4 compile rc"
  as -o "$TMP/$NM.o" "$TMP/$NM.s" 2>/dev/null || fail "$NM m4 as"
  gcc -no-pie "$TMP/$NM.o" -L out -lscrip_rt -Wl,-rpath,"$PWD/out" -o "$TMP/$NM.bin" 2>/dev/null || fail "$NM m4 link"
  "$TMP/$NM.bin" </dev/null > "$TMP/$NM.o4" || fail "$NM m4 run rc"
}
pin() { # $1=name $2=program(printf-format) $3=expected_stdout(printf-format) — m2 == m3 == m4 == canon
  local NM=$1 PRG=$2 EXP=$3
  printf "$PRG" > "$TMP/$NM.pl"
  "$SCRIP" --run "$TMP/$NM.pl" </dev/null > "$TMP/$NM.o2" 2>/dev/null || fail "$NM m2 rc"
  "$SCRIP" --run    "$TMP/$NM.pl" </dev/null > "$TMP/$NM.o3" 2>/dev/null || fail "$NM m3 rc"
  m4_run "$NM"
  printf "$EXP" | cmp -s - "$TMP/$NM.o2" || fail "$NM m2 output not canon (got: $(tr '\n' ' ' < "$TMP/$NM.o2"))"
  cmp -s "$TMP/$NM.o2" "$TMP/$NM.o3" || fail "$NM m2 vs m3 stdout differ"
  cmp -s "$TMP/$NM.o2" "$TMP/$NM.o4" || fail "$NM m2 vs m4 stdout differ"
}
pin24() { # $1=name $2=program $3=expected — m2+m4 only; m3 aborts (ITE-in-callee not yet GZ-admitted)
  local NM=$1 PRG=$2 EXP=$3
  printf "$PRG" > "$TMP/$NM.pl"
  "$SCRIP" --run "$TMP/$NM.pl" </dev/null > "$TMP/$NM.o2" 2>/dev/null || fail "$NM m2 rc"
  m4_run "$NM"
  printf "$EXP" | cmp -s - "$TMP/$NM.o2" || fail "$NM m2 output not canon (got: $(tr '\n' ' ' < "$TMP/$NM.o2"))"
  cmp -s "$TMP/$NM.o2" "$TMP/$NM.o4" || fail "$NM m2 vs m4 stdout differ"
}
# headline: the condition a(X),X>=2 commits at the first success (X=2); the X=3 alternative and the
# Else (X=0) are both dead — exactly 2. This is the WAM-CP-9 / paper §4.5 case.
# m3: uses pin24 (m2+m4 only) because f/1 has ITE in its callee body — not yet GZ-admitted.
pin24 commit ':- initialization(main).\na(1). a(2). a(3).\nf(X) :- ( a(X), X >= 2 -> true ; X = 0 ).\nmain :- ( f(R), write(R), nl, fail ; true ).\n' '2\n'
# bare-call condition: a single-solution call as the whole condition commits and Then runs once.
pin barecall ':- initialization(main).\na(1).\nmain :- ( ( a(X) -> true ; fail ), write(X), nl, fail ; true ).\n' '1\n'
# fresh re-entry: an enclosing generator m(X) re-drives the ITE with a NEW binding each solution;
# the condition is re-evaluated fresh (commit state reset on each forward entry) — s, 2, 3.
pin reentry ':- initialization(main).\nm(1). m(2). m(3).\nmain :- ( m(X), ( X >= 2 -> write(X) ; write(s) ), nl, fail ; true ).\n' 's\n2\n3\n'
# semidet construct: ITE redo bypasses to ω (β = ω_in), so the Else generator m(X) is NOT re-satisfied
# on backtracking — single 1, agreeing with the m4 β→ω tombstone.
pin24 semidet ':- initialization(main).\nm(1). m(2).\nmain :- ( ( fail -> true ; m(X) ), write(X), nl, fail ; true ).\n' '1\n'
# \+ and \= share the bounded condition: \+ a(2) succeeds (y); a redo-driven \+ fail commits its
# condition (k printed once); 1 \= 2 succeeds (u).
pin24 negbound ':- initialization(main).\na(1).\nmain :- ( \\+ a(2) -> write(y) ; write(n) ), nl, ( \\+ fail, write(k), nl, fail ; true ), ( 1 \\= 2 -> write(u) ; write(v) ), nl.\n' 'y\nk\nu\n'
# ---- PL-GZ-7b: the new-path §4.5 ifstmt box (IR_CELL_ITE on the GZ substrate) ----
gz_pin() { # $1=name $2=program $3=expected — like pin(), PLUS asserts the GZ path: m3 has NO INTERP-FALLBACK and the m4 .s carries gzi chain labels
  local NM=$1 PRG=$2 EXP=$3
  printf "$PRG" > "$TMP/$NM.pl"
  "$SCRIP" --run "$TMP/$NM.pl" </dev/null > "$TMP/$NM.o2" 2>/dev/null || fail "$NM m2 rc"
  "$SCRIP" --run    "$TMP/$NM.pl" </dev/null > "$TMP/$NM.o3" 2>"$TMP/$NM.e3" || fail "$NM m3 rc"
  grep -q "INTERP-FALLBACK" "$TMP/$NM.e3" && fail "$NM m3 fell back to interp (not GZ-admitted)"
  m4_run "$NM"
  grep -q "gzi" "$TMP/$NM.s" || fail "$NM m4 .s has no gzi chain labels (legacy path?)"
  grep -q "rt_bomb" "$TMP/$NM.s" && fail "$NM m4 .s contains a bomb"
  printf "$EXP" | cmp -s - "$TMP/$NM.o2" || fail "$NM m2 output not canon (got: $(tr '\n' ' ' < "$TMP/$NM.o2"))"
  cmp -s "$TMP/$NM.o2" "$TMP/$NM.o3" || fail "$NM m2 vs m3 stdout differ"
  cmp -s "$TMP/$NM.o2" "$TMP/$NM.o4" || fail "$NM m2 vs m4 stdout differ"
}
gz_pin_noite() { # like gz_pin() but no gzi label check — for GZ programs without ITE
  local NM=$1 PRG=$2 EXP=$3
  printf "$PRG" > "$TMP/$NM.pl"
  "$SCRIP" --run "$TMP/$NM.pl" </dev/null > "$TMP/$NM.o2" 2>/dev/null || fail "$NM m2 rc"
  "$SCRIP" --run    "$TMP/$NM.pl" </dev/null > "$TMP/$NM.o3" 2>"$TMP/$NM.e3" || fail "$NM m3 rc"
  grep -q "INTERP-FALLBACK" "$TMP/$NM.e3" && fail "$NM m3 fell back to interp (not GZ-admitted)"
  m4_run "$NM"
  grep -q "rt_bomb" "$TMP/$NM.s" && fail "$NM m4 .s contains a bomb"
  printf "$EXP" | cmp -s - "$TMP/$NM.o2" || fail "$NM m2 output not canon"
  cmp -s "$TMP/$NM.o2" "$TMP/$NM.o3" || fail "$NM m2 vs m3 differ"
  cmp -s "$TMP/$NM.o2" "$TMP/$NM.o4" || fail "$NM m2 vs m4 differ"
}
# floor: fact-unify condition commits (Then) / const-mismatch condition exhausts (Else) — det branches.
gz_pin gzfloor1 ':- initialization(main).\np(a).\nmain :- ( p(X) -> write(X) ; write(n) ), nl.\n' 'a\n'
gz_pin gzfloor2 ':- initialization(main).\np(a).\nmain :- ( p(b) -> write(y) ; write(n) ), nl.\n' 'n\n'
# MONEY: choice condition commits at first success inside a fail-driven soft-disj — exactly one a.
# E1 resume label UNREFERENCED = the bounded condition (Delete_Choice_Point by wiring).
gz_pin gzmoney ':- initialization(main).\np(a). p(b).\nmain :- ( ( p(X) -> write(X) ; write(n) ), nl, fail ; true ).\n' 'a\n'
# GZ-8: arith conditions now GZ-admitted — const-fold in the box, no INTERP-FALLBACK.
gz_pin gzarith_cmp  ':- initialization(main).\nmain :- ( 1 >= 2 -> write(y) ; write(n) ), nl.\n'  'n\n'
gz_pin_noite gzarith_is   ':- initialization(main).\nmain :- X is 2 * 3, write(X), nl.\n'             '6\n'
gz_pin gzarith_ite  ':- initialization(main).\nmain :- ( 3 < 5 -> write(t) ; write(f) ), nl, ( 5 < 3 -> write(t) ; write(f) ), nl.\n'  't\nf\n'
# GZ-8b: LOGICVAR operands — CMP with bound variable, IS with Y op C shape.
gz_pin gzvarith_cmp ':- initialization(main).\nm(1). m(2). m(3).\nmain :- ( m(X), ( X >= 2 -> write(X) ; write(s) ), nl, fail ; true ).\n' 's\n2\n3\n'
gz_pin_noite gzvarith_is ':- initialization(main).\nmain :- X = 5, Y is X - 3, write(Y), nl.\n' '2\n'
# CORRUPT-PROOF: swap the two gate-stub ROUTING targets in the emitted .s (Then.α <-> Else.α) — the
# committed condition must then enter Else: output flips a -> n, LOUD divergence, restore proves liveness.
# (Gate-VALUE corruption is invisible at the det floor BY DESIGN: β dispatches to tombstones, both routes
# reach ω — the dispatch row becomes observable when GZ-8/9 admit resumable shapes.)
sed -e '/^gzi[0-9]*_c1:/,/jmp/ s/jmp gzi\([0-9]*\)_t$/jmp gzi\1_e/' \
    -e '/^gzi[0-9]*_c2:/,/jmp/ s/jmp gzi\([0-9]*\)_e$/jmp gzi\1_t/' "$TMP/gzmoney.s" > "$TMP/gzcorrupt.s"
cmp -s "$TMP/gzmoney.s" "$TMP/gzcorrupt.s" && fail "corrupt-proof: sed did not alter the stub routing"
as -o "$TMP/gzcorrupt.o" "$TMP/gzcorrupt.s" 2>/dev/null || fail "corrupt-proof as"
gcc -no-pie "$TMP/gzcorrupt.o" -L out -lscrip_rt -Wl,-rpath,"$PWD/out" -o "$TMP/gzcorrupt.bin" 2>/dev/null || fail "corrupt-proof link"
"$TMP/gzcorrupt.bin" </dev/null > "$TMP/gzcorrupt.out" || true
cmp -s "$TMP/gzmoney.o4" "$TMP/gzcorrupt.out" && fail "corrupt-proof: routing swap did NOT diverge (dead wiring)"
echo "GATE-PL-GZ7 PASS: ITE-commit canon (commit · barecall · reentry · semidet · negbound) + 7b §4.5 box (gzfloor1 · gzfloor2 · gzmoney GZ-asserted · corrupt-proven) + GZ-8 arith (gzarith_cmp · gzarith_is · gzarith_ite GZ-admitted) + GZ-8b logicvar (gzvarith_cmp · gzvarith_is GZ-admitted)"
