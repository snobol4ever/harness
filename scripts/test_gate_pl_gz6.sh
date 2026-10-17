#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_gz6.sh — PL-GZ-6 gate: lexical cut as PURE WIRING (the seed's firstpath/1 law). The
# cut box body is the det four-port shape (α falls to γ; def β; jmp ω) IDENTICAL to a vacuous-success
# unify — the ONLY difference is driver-side: gz_emit_callee wires the cut's ω to the callee fail
# landing cl_ω instead of the backward redo chain. That severs redo past the cut (goals before it
# never receive redo; the clause-advance block is unreachable once the cut executed) while goals
# AFTER the cut redo normally; cut-not-reached (forward failure before the cut) still advances
# clauses — ISO-correct. This rung also re-baselined the m2 oracle: cut β re-entry used to
# RE-SUCCEED (the cut's CP-truncate freed the choice's own CP, which the node-state resume layer
# misread as liveness, and the cut's case re-truncated + re-succeeded on resume re-walks). Fix:
# stateful cut (truncate once per activation), cp_cut_away commit detection in IR_CHOICE redo, and
# cut-aware liveness (only the cut's goal-suffix can offer alternatives) in IR_CHOICE + IR_GOAL.
# GATE-1 / GATE-3 counts are byte-identical to the pre-fix baseline (115/115 · 18/0/97 · 105/0/10).
# Probes: m2 == m3 == m4 BYTE-IDENTICAL on the new path. Negatives: cut at QUERY level refuses
# (dynamic territory — paper §4.5 frame gate, a later rung); cut inside a query soft-disj arm
# refuses (it must sever the ;true soft-fail promotion = dynamic). Both branches refuse identically.
set -u
cd "$(dirname "$0")/../../SCRIP"
SCRIP=./scrip
RT=out/libscrip_rt.so
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "GATE-PL-GZ6 FAIL: $1"; exit 1; }
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

# pos1: multi-clause cut COMMIT — the gz5c neg1 ratchet target; redo through the cut fails the
# predicate (no clause 2, bindings undone at cl_ω) so the fail-driven pump prints exactly one a.
run_admitted cutcommit ':- initialization(main).\nf(X) :- X = a, !.\nf(X) :- X = b.\nmain :- f(Q), write(Q), nl, fail ; true.\n' 'a\n'
grep -q "CELL_CUT" "$TMP/cutcommit.s" || fail "cutcommit m4 .s lacks the CELL_CUT box"

# pos2: redo PAST the cut — alternatives created AFTER the cut stay live (s advances a→b); when s
# exhausts, the backward chain hits the cut's β → cl_ω, never the advance block.
run_admitted redopast ':- initialization(main).\nr(X) :- !, s(X).\ns(a).\ns(b).\nmain :- r(Q), write(Q), nl, fail ; true.\n' 'a\nb\n'

# pos3: cut NOT reached — forward failure before the cut (w(z) vs w(q)) still advances to clause 2.
run_admitted notreached ':- initialization(main).\nv(X) :- w(X), !.\nv(z).\nw(q).\nmain :- v(z), write(ok), nl.\n' 'ok\n'

# pos4: the seed's firstpath/1 under fail-driven redo — single-clause callee, cut last; the callee
# β dispatches to the cut's β → cl_ω and NEVER resumes path (the seed's firstpath_β law).
run_admitted firstpath ':- initialization(main).\nedge(a,b).\nedge(b,c).\nedge(b,d).\npath(X,Y) :- edge(X,Y).\npath(X,Z) :- edge(X,Y), path(Y,Z).\nfirstpath(Q) :- path(a,Q), !.\nmain :- firstpath(Q), write(Q), nl, fail ; true.\n' 'b\n'

# neg1: cut at QUERY level (in main's own body) — dynamic cut territory; both branches refuse.
printf ':- initialization(main).\nf(a).\nf(b).\nmain :- f(Q), !, write(Q), nl.\n' > "$TMP/neg1.pl"
"$SCRIP" --run "$TMP/neg1.pl" </dev/null > "$TMP/n13" 2>"$TMP/ne13" || fail "neg1 m3 rc"
grep -q "INTERP-FALLBACK" "$TMP/ne13" || fail "neg1 (query-level cut) m3 did NOT show the loud fallback (GZ wrongly admitted?)"
"$SCRIP" --compile --target=x86 "$TMP/neg1.pl" > "$TMP/n1.s" 2>/dev/null || fail "neg1 m4 compile rc"
grep -q "gzq\|gzp" "$TMP/n1.s" && fail "neg1 (query-level cut) m4 .s has gz labels (GZ wrongly admitted)"

# neg2: cut inside a query soft-disj arm — it must kill the ;true promotion (main would FAIL after
# the pump), i.e. dynamic wiring; both branches refuse identically until that rung lands.
printf ':- initialization(main).\np(a).\np(b).\nmain :- p(X), !, write(X), nl, fail ; true.\n' > "$TMP/neg2.pl"
"$SCRIP" --run "$TMP/neg2.pl" </dev/null > "$TMP/n23" 2>"$TMP/ne23" || fail "neg2 m3 rc"
grep -q "INTERP-FALLBACK" "$TMP/ne23" || fail "neg2 (cut in soft-disj arm) m3 did NOT show the loud fallback (GZ wrongly admitted?)"
"$SCRIP" --compile --target=x86 "$TMP/neg2.pl" > "$TMP/n2.s" 2>/dev/null || fail "neg2 m4 compile rc"
grep -q "gzq\|gzp" "$TMP/n2.s" && fail "neg2 (cut in soft-disj arm) m4 .s has gz labels (GZ wrongly admitted)"

echo "GATE-PL-GZ6 PASS: lexical cut as PURE WIRING (cut box = det four-port shape, driver wires ω→cl_ω; redo never resumes pre-cut goals nor later clauses; post-cut alternatives live; cut-not-reached advances) m2==m3==m4 byte-identical on the GZ path; m2 cut-redo oracle re-baselined with GATE-1/GATE-3 counts unchanged; query-level cut and soft-disj-arm cut refused identically by both branches"
exit 0
