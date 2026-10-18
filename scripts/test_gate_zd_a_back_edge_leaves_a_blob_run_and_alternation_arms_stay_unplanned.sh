#!/usr/bin/env bash
# test_gate_zd_a_back_edge_leaves_a_blob_run_and_alternation_arms_stay_unplanned.sh -- TWO zd_plan DEFECTS UNDER THE SELF-HOSTED PARSERS
#
# MEASURED 2026-09-23 by hq_snocone (row snocone-the-seven-bootstrap-parser-sc-parse-every-corpus-source-..., Lon: "Get each parser_*.sc
# working"): every bootstrap parser crashed or printed a wrong tree on SCRIP because its tree dumper (bootstrap/tdump.sc) walks the tree
# with a match test whose pattern has an alternation, inside an if that returns, in a function that recurses from a while loop. Two
# defects in the zd depth planner, both pre-existing (the 73e02c870 binary fails the same witnesses):
#  (A) A RUN WHOSE OPERAND CLOSURE REACHES OUTSIDE IT (nblob > 0 -- any match with an alternation, whose unclaimed arm leaves sit in the
#      ALTERNATE's operand list) decided "is this port's target in the run" by membership alone, so a BACK EDGE -- a while loop's
#      return to its head -- counted as staying in the run and released nothing: every lap leaked the body's spine (192 bytes in the
#      witness) and the function's return popped the wrong word. The run rule already treated a back edge as an exit; the blob rule now
#      does the same (killswitch SCRIP_ZD_BLOBBACK=0).
#  (B) ZD-5B ADMITTED ONE ARM OF AN ALTERNATION INTO THE RUN (an arm leaf with an evaluated argument, e.g. SPAN(v) with v not foldable)
#      as a spine box that keeps its 16-byte cell on success. Unreleased, the continuation read the capture's saved cursor 16 bytes off
#      (a garbage deferred capture, "rt_dcap_pump: CORRUPT CAPTURE ENTRY"); released on success, backtracking into the arm popped it a
#      second time (SIGSEGV). Arms are now unplanned by default, the pre-s102 closure-only form, which grades correct on every witness
#      here and on its own original witness (span_any_rpos_branch_2); SCRIP_ZD_5B=1 opts back in.
#  (C) A MATCH IN EXPRESSION POSITION THAT FAILS INSIDE A FUNCTION LEAKED ITS SUBJECT SLOT (measured 2026-09-24 by hq_snocone on
#      the transpiled parser_snocone.sno: every string literal and every call SEGV'd rc 139 in both modes; witness w5 below, and the
#      SNOBOL4 twin `((str ? 'zz') = '') :F(L)` inside a DEFINE). The transpiler writes every match-with-replacement as the
#      parenthesized expression form, so the match's ω exit goes to the statement's own β landing with the subject's 16-byte
#      operand still pushed; the planner's zero-K rule counted that exit as staying inside the run (the statement's begin is
#      earlier in the run), planned no pop, and the function's return popped the wrong word. The rule now excludes a
#      statement-landing target, as the two rules beside it already did (killswitch SCRIP_ZD_OMEGA_STMTLAND=0).
# (D) A JOIN AT DEPTH (cto 2026-10-01, from hq_snocone's FINDING-2026-10-01-hq_snocone-beauty-sigsegv-zd-plan-assign-cond-depth-mismatch):
#      a conditional assignment with an alternative -- if (~(B = B ' ' DUPL(' ', n))) B = B ' '; in corpus/library/Gen.sc GenTab --
#      lowers to a main chain whose every omega unwinds to depth 0 and goes to the alternative statement, which zd_plan leaves
#      unplanned; both paths join at the statement end, which the run builder had pulled into the main chain's run with a fixed
#      release of 192 bytes. The failure arm released 192 it never carved and the det-arm signature epilogue jumped through 0
#      (SncDemo beauty, rc 139 both modes). Cured: after planning, a node an unplanned non-pattern node enters at its alpha while
#      the run has carved depth there is a WALL, the run stops before it (its last node then pops the whole depth on gamma) and
#      the graph is planned again until no wall is added. Witness w6; killswitch SCRIP_ZD_JOIN_CUT=0.
#  (E) A NEGATED USER CALL LEFT ITS OMEGA GATE TO THE LEGACY ROAD (cto 2026-10-02, row snobol4-the-operand-after-a-negated-
#      user-call-..., gimpel infinip): in Q (~P(X) P(X)) the call P's omega edge reaches the negation's gate, which no run
#      claimed -- zd_omega_test_kind counted only tests -- so the second operand was emitted on legacy frame slots ([rsp+288])
#      that nothing reserved inside a called function, clobbering the caller's frame (3,2,1,ok printed nothing). A call now
#      joins the test family beside BINOP_TEST (SCRIP_ZD_TESTFAM, its killswitch), so its omega target heads its own run at the
#      run base the call's omega exit pops to. Witness w7. This also reaches the joins (D) cut: w6 stays green under
#      SCRIP_ZD_JOIN_CUT=0 alone, so its fail-once now turns both killswitches off.
#      w7's FAIL-ONCE IS STRUCTURAL SINCE fc306f22a (cfo, CEO-1422 shape B): every SNOBOL4 statement's failure exits now
#      pass an IR_SETEXIT_TEST, which carries infinip's run past the negated call, so w7 prints the oracle's 3,2,1,ok even
#      under SCRIP_ZD_TESTFAM=0 -- the output can no longer show the defect (measured by the cto on fc306f22a alone; an EVAL'd
#      form, which the cfo's lowering leaves without the node, is green too because an EVAL chain's carve reserves its slots).
#      The property (E) cures is still the planner's: the negated call's omega target heads a run. So w7's control counts
#      the nodes SCRIP_ZD_DIAG reports claimed ([ZD-FINAL] rows) over w7's compile: the killswitch must claim FEWER (Q's
#      i=25 VAR and i=26 CALL drop out of every run under SCRIP_ZD_TESTFAM=0 on fc306f22a), never the same.
# EVERY ARM IS GRADED AGAINST THE ORACLE: the witness's --transpile run on sbl -bf (a Snocone program's oracle), both modes, stdout.
# FAIL-ONCE, BUILT IN UNTIL 2026-10-17: witness 1 went red under SCRIP_ZD_BLOBBACK=0, witness 3 under SCRIP_ZD_5B=1 and w5.sno
# under SCRIP_ZD_OMEGA_STMTLAND=0. THOSE KILLSWITCHES ARE DELETED (hq_zetas, the spine flip, under the cto's review: ZETA HAS NO
# MODES, and CEO-1680 allows no seam in SCRIP for a test); SCRIP_ZD_5B had already been read and never used since the flip's
# ZD-5b went on, so its arm measured nothing. Their fail-once readings stand as history, like w6's and w7's below. w6 (D) and w7 (E) have NO per-run control since 2026-10-14 (hq_zetas, row spine-zd-omega-test-kind-
# ...-ceo-1389, the cto's road (a)): their fail-once needed SCRIP_ZD_TESTFAM=0, which selected the test family's members per op at
# run time and is deleted -- the family is ir_decides_own_failure_kind in src/ir/IR.h, a definition, not a switch, and CEO-1680
# allows no seam in SCRIP for a test. PROVEN ONCE, at that landing, on a local uncommitted build whose family lacked IR_CALL and
# IR_BINOP_TEST (exactly what the switch selected): w6 m3 under SCRIP_ZD_JOIN_CUT=0 printed only [ab ] against the oracle's four
# lines (green with the family alone, as before), and w7's plan claimed 50 nodes against 53 shipped. Both stay graded against the
# oracle in both modes below -- a gate that cannot see
# its own defect is not measuring it.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"; RT="$ROOT/out"
[ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: cannot load lib_oracle_flags.sh"; exit 2; }
SBL="$(sbl_clean_bin 2>/dev/null)"; [ -x "${SBL:-}" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no SPITBOL oracle"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w1.sc" <<'EOF'
function F(n, i, t) {
    if (DIFFER(n)) {
        if ('AP' ? (POS(0) (SPAN('AP') | '') RPOS(0))) t = 'y'; else t = 'q';
        OUTPUT = n t;
        i = 0;
        while (i = LT(i, n) i + 1) F(n - 1);
        return;
    }
    return;
}
F(2);
OUTPUT = 'after';
EOF
cat > "$T/w2.sc" <<'EOF'
struct tree { t, v, n, c }
function TD(x, i, t) {
    if (DIFFER(n(x))) {
        if (~(t(x) ? (POS(0) ANY(&UCASE) (SPAN(&UCASE) | '') RPOS(0)))) t = 'q'; else t = t(x);
        OUTPUT = '(' t;
        i = 0;
        while (i = LT(i, n(x)) i + 1) TD(c(x)[i]);
        OUTPUT = ')';
        return;
    }
    return;
}
a = tree('A', '', 0, ''); b = tree('B', '', 0, ''); p = tree('P', '', 2, ARRAY(2)); c(p)[1] = a; c(p)[2] = b;
TD(p);
OUTPUT = 'after';
EOF
cat > "$T/w3.sc" <<'EOF'
digits = DUPL('0', 1) '123456789';
alpha = DUPL('a', 1) 'bc';
s = '12x';
if (s ? (POS(0) (SPAN(digits) | SPAN(alpha)) RPOS(0))) { OUTPUT = 'ident'; } else { OUTPUT = 'quoted'; }
OUTPUT = 'after';
EOF
cat > "$T/w4.sc" <<'EOF'
digits = DUPL('0', 1) '123456789';
s = '12';
if (s ? (POS(0) (SPAN(digits) | '') RPOS(0))) { OUTPUT = 'ident'; } else { OUTPUT = 'quoted'; }
t = 'T12';
if (t ? (POS(0) ANY('T') (SPAN(digits) | '') RPOS(0))) { OUTPUT = 'ident2'; } else { OUTPUT = 'quoted2'; }
EOF
cat > "$T/w5.sc" <<'EOF'
function F(str) {
    if (str ? (POS(0) 'zz') = ) { F = 'replaced'; return; }
    F = str;
    return;
}
OUTPUT = F('hi');
OUTPUT = F('zzz');
OUTPUT = 'after';
EOF
cat > "$T/w6.sc" <<'EOF'
function GenTab(pos) {
    GenTab = .dummy;
    pos = IDENT(pos) 4;
    B = IDENT(B) X;
    if (~(B = B ' ' DUPL(' ', pos - SIZE(B) - 1)))
        B = B ' ';
    nreturn;
}
function Show(s) { Show = '[' s ']'; return; }
B = 'ab'; X = '';
GenTab(10); OUTPUT = Show(B);
B = 'abcdefghijkl'; X = '';
GenTab(3); OUTPUT = Show(B);
GenTab(); OUTPUT = Show(B);
OUTPUT = 'done';
EOF
run_mode() {  # run_mode <m3|m4> <prog> [ENV=V...] -> stdout on fd 1
  local m="$1" p="$2"; shift 2
  if [ "$m" = m3 ]; then env "$@" timeout -k 5 20 "$SCRIP" "$p" </dev/null 2>/dev/null; return; fi
  env "$@" "$SCRIP" --compile -o "$p.s" "$p" </dev/null >/dev/null 2>&1 || { echo "COMPILE-FAIL"; return; }
  gcc -no-pie -o "$p.x" "$p.s" -L"$RT" -Wl,-rpath,"$RT" -lscrip_rt -lm >/dev/null 2>&1 || { echo "LINK-FAIL"; return; }
  timeout -k 5 20 "$p.x" </dev/null 2>/dev/null; }
RC=0; N=0
for w in w1 w2 w3 w4 w5 w6; do
  "$SCRIP" --transpile "$T/$w.sc" > "$T/$w.sno" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: $w does not transpile"; exit 2; }
  want=$("$SBL" -bf "$T/$w.sno" </dev/null 2>/dev/null)
  [ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for $w"; exit 2; }
  for m in m3 m4; do N=$((N+1)); got=$(run_mode "$m" "$T/$w.sc")
    if [ "$got" = "$want" ]; then echo "  $w $m PASS"; else echo "  $w $m FAIL: got [$(printf '%s' "$got" | tr '\n' ' ' | cut -c1-60)] want [$(printf '%s' "$want" | tr '\n' ' ')]"; RC=1; fi; done
done
# w5 IS GRADED IN ITS TRANSPILED FORM TOO: the Snocone frontend lowers the if-condition replacement as a statement-level match
# (omega to statement_end, which pops), so the .sc form never reaches defect (C); the SNOBOL4 frontend lowers the transpiled
# `((str ? (POS(0) 'zz')) = '')` as an expression-position match (omega to the statement's beta landing) -- the form every
# bootstrap parser runs as, and the one that leaked. Both frontends are graded, against the same oracle output.
cat > "$T/w7.sno" <<'EOF'
        DEFINE('P(X)')
        DEFINE('Q(X)')
        DEFINE('R(N)')                          :(E1)
P       LT(X,0)                                 :S(RETURN)F(FRETURN)
Q       (~P(X)  P(X))                           :S(RETURN)F(FRETURN)
R       R  =  EQ(N,0)  'ok'                     :S(RETURN)
        Q(1)
        R  =  N  ','  R(N - 1)                  :(RETURN)
E1      OUTPUT  =  R(3)
END
EOF
for w in w5 w7; do want=$("$SBL" -bf "$T/$w.sno" </dev/null 2>/dev/null)
  for m in m3 m4; do N=$((N+1)); got=$(run_mode "$m" "$T/$w.sno")
    if [ "$got" = "$want" ]; then echo "  $w.sno $m PASS"; else echo "  $w.sno $m FAIL: got [$(printf '%s' "$got" | tr '\n' ' ' | cut -c1-60)] want [$(printf '%s' "$want" | tr '\n' ' ')]"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N arms (6 witnesses x m3+m4, plus w5's transpiled form x m3+m4) print the SPITBOL oracle's output (every witness's fail-once: proven once at its landing, see the header)"
else echo "GATE FAIL(1) [$G]: see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $SBL -bf  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
