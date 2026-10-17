#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_gz5c.sh — PL-GZ-5c gate: MULTI-CLAUSE rule predicates (the seed's path/2) on the
# Proebsting-pure path. Callee-level choice over rule clauses: ONE frame holds [args | per-clause
# locals+synth | child slots]; mark at [ζ+0], 1-based cursor at [ζ+4] (the seed's ζ->i, init at α);
# per-clause body chains with the backward redo wiring; clause-K-exhausted = advance block
# (cursor=K+2; rt_trail_unwind(entry mark); jmp clause K+1 α — the seed's fK_ω), last clause falls
# to the callee ω landing; β re-entry dispatches through bb_cell_choice's cmp-chain shape, one
# cmp/je fragment per clause wiring that clause's redo (its LAST goal's β; det βs pass through to
# their ω so all-det clauses collapse to the advance block). Facts admit as empty-body rule clauses,
# so multi-clause FACT preds called from callee bodies become framed callees (the seed's edge/2);
# self/mutual recursion terminates at admit time via the visiting list + shell-first memo.
# Probes: m2 == m3 == m4 BYTE-IDENTICAL on the new path. Negatives: cut clauses refuse (PL-GZ-6
# territory); compound/list head args refuse; >4-clause preds refuse (the gz4 clause cap).
set -u
cd "$(dirname "$0")/../../SCRIP"
SCRIP=./scrip
RT=out/libscrip_rt.so
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "GATE-PL-GZ5C FAIL: $1"; exit 1; }
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

# pos1: THE rung target — the seed's path/2: 2 rule clauses, self-recursion, 3-clause fact callee.
run_admitted path ':- initialization(main).\nedge(a,b).\nedge(b,c).\nedge(b,d).\npath(X,Y) :- edge(X,Y).\npath(X,Z) :- edge(X,Y), path(Y,Z).\nmain :- path(a,Q), write(Q), nl, fail ; true.\n' 'b\nc\nd\n'
grep -q "\[r12 + 4\]" "$TMP/path.s" || fail "path m4 .s lacks the cursor row [r12+4] (multi-clause dispatch not emitted)"
grep -q "_adv" "$TMP/path.s"        || fail "path m4 .s lacks clause-advance blocks"
grep -q "rt_enter" "$TMP/path.s"    || fail "path m4 .s lacks rt_enter (ζ-tree path not taken)"

# pos2: 2-clause all-det rule bodies — clause advance via det β→ω pass-through chains.
run_admitted tworule ':- initialization(main).\np(X) :- X = a.\np(X) :- X = b.\nmain :- p(Q), write(Q), nl, fail ; true.\n' 'a\nb\n'

# pos3: mixed FACT + RULE clauses in one pred; body calls a 2-clause FACT pred (framed callee).
run_admitted mixed ':- initialization(main).\nr(a).\nr(X) :- s(X).\ns(b).\ns(c).\nmain :- r(Q), write(Q), nl, fail ; true.\n' 'a\nb\nc\n'

# pos4: recursion depth — every activation owns its frame, hence its cursor and child slots.
run_admitted chain ':- initialization(main).\nedge(a,b).\nedge(b,c).\nedge(c,d).\nedge(d,e).\npath(X,Y) :- edge(X,Y).\npath(X,Z) :- edge(X,Y), path(Y,Z).\nmain :- path(a,Q), write(Q), nl, fail ; true.\n' 'b\nc\nd\ne\n'

# neg1 (ratcheted by PL-GZ-6: cut inside a clause now ADMITS): cut at QUERY level — dynamic territory; both branches must refuse identically.
printf ':- initialization(main).\nf(a).\nf(b).\nmain :- f(Q), !, write(Q), nl.\n' > "$TMP/neg1.pl"
"$SCRIP" --run "$TMP/neg1.pl" </dev/null > "$TMP/n13" 2>"$TMP/ne13" || fail "neg1 m3 rc"
grep -q "INTERP-FALLBACK" "$TMP/ne13" || fail "neg1 (query-level cut) m3 did NOT show the loud fallback (GZ wrongly admitted?)"
"$SCRIP" --compile --target=x86 "$TMP/neg1.pl" > "$TMP/n1.s" 2>/dev/null || fail "neg1 m4 compile rc"
grep -q "gzq\|gzp" "$TMP/n1.s" && fail "neg1 (query-level cut) m4 .s has gz labels (GZ wrongly admitted)"

# neg2: compound/list head args (the rung05 member shape) — beyond 5c head-unify law.
printf ':- initialization(main).\nm(X,[X|_]).\nm(X,[_|T]) :- m(X,T).\nmain :- m(Q,[a,b]), write(Q), nl, fail ; true.\n' > "$TMP/neg2.pl"
"$SCRIP" --run "$TMP/neg2.pl" </dev/null > "$TMP/n23" 2>"$TMP/ne23" || fail "neg2 m3 rc"
grep -q "INTERP-FALLBACK" "$TMP/ne23" || fail "neg2 (list heads) m3 did NOT show the loud fallback (GZ wrongly admitted?)"
"$SCRIP" --compile --target=x86 "$TMP/neg2.pl" > "$TMP/n2.s" 2>/dev/null || fail "neg2 m4 compile rc"
grep -q "gzq\|gzp" "$TMP/n2.s" && fail "neg2 (list heads) m4 .s has gz labels (GZ wrongly admitted)"

# neg3: 5 clauses — over the clause cap; both branches refuse identically.
printf ':- initialization(main).\nc5(a). c5(b). c5(c). c5(d). c5(e).\nmain :- c5(Q), write(Q), nl, fail ; true.\n' > "$TMP/neg3.pl"
"$SCRIP" --run "$TMP/neg3.pl" </dev/null > "$TMP/n33" 2>"$TMP/ne33" || fail "neg3 m3 rc"
grep -q "INTERP-FALLBACK" "$TMP/ne33" || fail "neg3 (5-clause pred) m3 did NOT show the loud fallback (GZ wrongly admitted?)"
"$SCRIP" --compile --target=x86 "$TMP/neg3.pl" > "$TMP/n3.s" 2>/dev/null || fail "neg3 m4 compile rc"
grep -q "gzq\|gzp" "$TMP/n3.s" && fail "neg3 (5-clause pred) m4 .s has gz labels (GZ wrongly admitted)"

echo "GATE-PL-GZ5C PASS: multi-clause RULE predicates (full path/2: callee-level choice, cursor@[ζ+4], per-clause body chains, clause-advance unwind blocks, β cmp-chain dispatch; facts as empty-body clauses; mixed fact+rule preds; self-recursion) m2==m3==m4 byte-identical on the GZ path; cut, list-head, and >4-clause preds refused identically by both branches"
exit 0
