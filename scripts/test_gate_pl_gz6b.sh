#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_gz6b.sh — PL-GZ-6b gate: QUERY-PREFIX SOFT-DISJ (two-segment query frame). Admission
# extends gz4's (G ; true) whole-query soft-disj to: disj at goals[0] of a LONGER query conj,
# RESTRICTED to arm0 ending in IR_FAIL (fail-driven — arm0 never succeeds, so no arm0-success wiring
# exists). Wiring (seed q1_ω: goto q2_α, literally): the soft landing becomes a NEW bb_query_frame
# aspect (op_sa=1, op_sb=2) = unwind(query mark [ζ+0]) + jmp B0's α via δ — the advance-block lbl_δ
# precedent — instead of rax=1+ret; flat_drive_gz_query goes two-segment (A from qf->α, B from
# qf->β); B0's ω → the HARD land_ω (unwind + rax=0 + ret); last B's γ → land_γ (rax=1 + ret).
# This runs the FULL PL-GZ-0 seed as ONE program: b c d b.
# LOGGED LATENT m2 DIVERGENCE (do not fix silently — PL-GZ-7 m2-commit cluster, PT-3/WAM-CP-9
# precedent): when the B segment FAILS, m2's disj-resume re-walk RE-ENTERS the exhausted soft-disj
# (re-prints the pump) — gprolog canon (syn_sugar.pl linearize: (P;Q) = 2-clause aux pred;
# indexing.pl: last clause = trust_me_else_fail; wam_inst.c Pl_Delete_Choice_Point) deletes the disj
# CP on entering the LAST arm, so B's failure must NOT re-enter the disj. m3/m4 match canon + seed;
# the B-fail probe pins m3 == m4 == canon and skips the m2 compare.
set -u
cd "$(dirname "$0")/../../SCRIP"
SCRIP=./scrip
RT=out/libscrip_rt.so
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "GATE-PL-GZ6B FAIL: $1"; exit 1; }
[ -x "$SCRIP" ] || fail "scrip binary missing (make scrip)"
[ -f "$RT" ]    || fail "libscrip_rt.so missing (make libscrip_rt)"

m4_run() { # $1=name ; compiles $TMP/$1.pl -> runs -> stdout in $TMP/$1.o4
  local NM=$1
  "$SCRIP" --compile --target=x86 "$TMP/$NM.pl" > "$TMP/$NM.s" 2>/dev/null || fail "$NM m4 compile rc"
  as -o "$TMP/$NM.o" "$TMP/$NM.s" 2>/dev/null || fail "$NM m4 as"
  gcc -no-pie "$TMP/$NM.o" -L out -lscrip_rt -Wl,-rpath,"$PWD/out" -o "$TMP/$NM.bin" 2>/dev/null || fail "$NM m4 link"
  "$TMP/$NM.bin" </dev/null > "$TMP/$NM.o4" || fail "$NM m4 run rc"
}

run_admitted() { # $1=name $2=program(printf-format) $3=expected_stdout(printf-format) — m2==m3==m4
  local NM=$1 PRG=$2 EXP=$3
  printf "$PRG" > "$TMP/$NM.pl"
  "$SCRIP" --run "$TMP/$NM.pl" </dev/null > "$TMP/$NM.o2" 2>/dev/null || fail "$NM m2 rc"
  "$SCRIP" --run    "$TMP/$NM.pl" </dev/null > "$TMP/$NM.o3" 2>"$TMP/$NM.e3" || fail "$NM m3 rc"
  grep -q "INTERP-FALLBACK" "$TMP/$NM.e3" && fail "$NM m3 fell back to the interpreter (GZ path not taken)"
  m4_run "$NM"
  grep -q "gzq.*_b0_" "$TMP/$NM.s" || fail "$NM m4 .s lacks the B-segment gzq*_b*_α labels (two-segment path not taken)"
  cmp -s "$TMP/$NM.o2" "$TMP/$NM.o3" || fail "$NM m2 vs m3 stdout differ"
  cmp -s "$TMP/$NM.o2" "$TMP/$NM.o4" || fail "$NM m2 vs m4 stdout differ"
  printf "$EXP" | cmp -s - "$TMP/$NM.o2" || fail "$NM m2 output is not expected"
}

# pos1: THE FULL PL-GZ-0 SEED AS ONE PROGRAM — the rung's reason to exist. Pump prints b c d (all
# solutions of path(a,Q)); soft landing unwinds the query mark and falls into segment B; the cut in
# firstpath/1 commits to the first solution: b. Output b c d b.
run_admitted fullseed ':- initialization(main).\nedge(a,b).\nedge(b,c).\nedge(b,d).\npath(X,Y) :- edge(X,Y).\npath(X,Z) :- edge(X,Y), path(Y,Z).\nfirstpath(Q) :- path(a,Q), !.\nmain :- ( path(a,Q), write(Q), nl, fail ; true ), firstpath(R), write(R), nl.\n' 'b\nc\nd\nb\n'

# pos2: bindings UNWOUND at the soft landing — B re-solves the same fact pred FRESH from clause 1
# (the soft landing's rt_trail_unwind(mark) is observable: without it p(Y) would see X's binding gone
# wrong or the choice cursor stale). a b from the pump, then a fresh a from B.
run_admitted unwound ':- initialization(main).\np(a).\np(b).\nmain :- ( p(X), write(X), nl, fail ; true ), p(Y), write(Y), nl.\n' 'a\nb\na\n'

# pos3: arm0 is a SINGLE IR_FAIL node (not a GCONJ) — the degenerate prefix form; B is the whole
# observable program.
run_admitted minfail ':- initialization(main).\nmain :- ( fail ; true ), write(ok), nl.\n' 'ok\n'

# pos4: B-segment FAILS → the HARD land_ω (rax=0, no spurious output, no re-entry into the exhausted
# pump). m3 == m4 == gprolog canon == a. m2 prints a a (the LOGGED disj-resume re-walk divergence) —
# m2 is NOT compared here; the pin is m3==m4==canon.
printf ':- initialization(main).\np(a).\nq(z).\nmain :- ( p(X), write(X), nl, fail ; true ), q(w), write(never), nl.\n' > "$TMP/bfail.pl"
"$SCRIP" --run "$TMP/bfail.pl" </dev/null > "$TMP/bfail.o3" 2>"$TMP/bfail.e3" || fail "bfail m3 rc"
grep -q "INTERP-FALLBACK" "$TMP/bfail.e3" && fail "bfail m3 fell back to the interpreter (GZ path not taken)"
m4_run bfail
cmp -s "$TMP/bfail.o3" "$TMP/bfail.o4" || fail "bfail m3 vs m4 stdout differ"
printf 'a\n' | cmp -s - "$TMP/bfail.o3" || fail "bfail m3 output is not canon (expected exactly one a — no re-entry into the exhausted soft-disj)"

# neg1: arm0 does NOT end in IR_FAIL — arm0 can succeed, which needs arm0-success wiring (disj
# success continues to B but a later B failure must redo INTO arm0): out of scope; refuse.
printf ':- initialization(main).\np(a).\np(b).\nmain :- ( p(X), write(X), nl ; true ), write(done), nl.\n' > "$TMP/neg1.pl"
"$SCRIP" --run "$TMP/neg1.pl" </dev/null > "$TMP/n13" 2>"$TMP/ne13" || fail "neg1 m3 rc"
grep -q "INTERP-FALLBACK" "$TMP/ne13" || fail "neg1 (arm0 not ending in fail) m3 did NOT show the loud fallback (GZ wrongly admitted?)"
"$SCRIP" --compile --target=x86 "$TMP/neg1.pl" > "$TMP/n1.s" 2>/dev/null || fail "neg1 m4 compile rc"
grep -q "gzq\|gzp" "$TMP/n1.s" && fail "neg1 (arm0 not ending in fail) m4 .s has gz labels (GZ wrongly admitted)"

# neg2: disj NOT at goals[0] of the query conj — mid/suffix position needs general disj wiring; refuse.
printf ':- initialization(main).\np(a).\nmain :- write(start), nl, ( p(X), write(X), nl, fail ; true ).\n' > "$TMP/neg2.pl"
"$SCRIP" --run "$TMP/neg2.pl" </dev/null > "$TMP/n23" 2>"$TMP/ne23" || fail "neg2 m3 rc"
grep -q "INTERP-FALLBACK" "$TMP/ne23" || fail "neg2 (disj not at goals[0]) m3 did NOT show the loud fallback (GZ wrongly admitted?)"
"$SCRIP" --compile --target=x86 "$TMP/neg2.pl" > "$TMP/n2.s" 2>/dev/null || fail "neg2 m4 compile rc"
grep -q "gzq\|gzp" "$TMP/n2.s" && fail "neg2 (disj not at goals[0]) m4 .s has gz labels (GZ wrongly admitted)"

echo "GATE-PL-GZ6B PASS: query-prefix soft-disj as a TWO-SEGMENT query frame (soft landing = unwind(query mark) + jmp B0 α via δ; B0 ω → hard land_ω; last B γ → land_γ) — the FULL seed runs as ONE program b c d b, m2==m3==m4; soft-landing unwind observable; B-fail = hard ω pinned m3==m4==gprolog canon (m2 disj-resume re-walk divergence LOGGED for PL-GZ-7); non-FAIL arm0 and mid-conj disj refused identically by both branches"
exit 0
