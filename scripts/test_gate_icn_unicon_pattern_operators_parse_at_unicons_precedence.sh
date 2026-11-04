#!/usr/bin/env bash
# test_gate_icn_unicon_pattern_operators_parse_at_unicons_precedence.sh -- THE UNICON PATTERN OPERATORS PARSE WHERE unigram.y PUTS THEM (R-2072, ARCH-UNICON R6; hq_unicon).
# unigram.y: ?? is expr2a (looser than to and .|), .| is expr2 (the level of to), -> and => are expr6 (the additive level: tighter than ||), a prefix .> is expr10, a backquote text is a primary.
# Four arms over one program dumped with scrip --dump-ast: ARM 1 -> and => bind tighter than ||; ARM 2 .| sits below || and ?? below .|; ARM 3 the prefix .> and the backquote primary; ARM 4 FAIL-ONCE: the same
# structure checks run against a deliberately wrong expectation must read red (a criterion fails once before it is trusted, R-1680). rc 0 all hold - rc 1 an arm is red - rc 2 REFUSED (no scrip).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SC="$HERE/../../SCRIP/scrip"
[ -x "$SC" ] || { echo "⛔ REFUSED(2) [pattern_operators_parse]: no scrip at $SC -- run make"; exit 2; }
D="$(mktemp -d)" || exit 2; trap 'rm -rf "$D"' EXIT
cat > "$D/p.icn" <<'ICN'
procedure main()
   p := Span(&digits) => n || Len(`n`) -> f;
   q := ("be" .| "ge") || Fence();
   r := a || b .| c;
   t := s ?? x .| y;
   u := Pos(1) || .> a;
end
ICN
"$SC" --dump-ast "$D/p.icn" < /dev/null > "$D/ast" 2>&1 || { echo "⛔ RED [pattern_operators_parse]: scrip --dump-ast refused the program: $(head -1 "$D/ast")"; exit 1; }
flat="$(tr -d '\n' < "$D/ast" | tr -s ' ' | sed 's/ )/)/g')"
red=0
chk() { if printf '%s' "$flat" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  RED  $1 -- expected: $2"; red=1; fi; }
chk "ARM 1a => binds tighter than ||, -> likewise" '(TT_CAT (TT_CAPT_IMMED_ASGN (TT_FNC (TT_VAR Span) (TT_VAR &digits)) (TT_VAR n)) (TT_CAPT_COND_ASGN (TT_FNC (TT_VAR Len) (TT_DEFER (TT_VAR n))) (TT_VAR f)))'
chk "ARM 1b backquote text is a deferred primary" '(TT_DEFER (TT_VAR n))'
chk "ARM 2a .| is looser than ||" '(TT_ASSIGN (TT_VAR r) (TT_ALT (TT_CAT (TT_VAR a) (TT_VAR b)) (TT_VAR c)))'
chk "ARM 2b ?? is looser than .|" '(TT_ASSIGN (TT_VAR t) (TT_PMATCH (TT_VAR s) (TT_ALT (TT_VAR x) (TT_VAR y))))'
chk "ARM 3 prefix .> is a unary cursor capture" '(TT_CAPT_CURSOR (TT_VAR a))'
chk "ARM 2c parenthesised .| inside || keeps its group" '(TT_CAT (TT_ALT (TT_QLIT "be") (TT_QLIT "ge")) (TT_FNC (TT_VAR Fence)))'
wrong='(TT_CAT (TT_CAPT_IMMED_ASGN (TT_FNC (TT_VAR Span) (TT_VAR &digits)) (TT_CAT (TT_VAR n)'
if printf '%s' "$flat" | grep -qF -- "$wrong"; then echo "  RED  ARM 4 fail-once: a wrong expectation read green -- the checks cannot fail"; red=1; else echo "  ok   ARM 4 fail-once: a deliberately wrong expectation reads red"; fi
[ "$red" -eq 0 ] || { echo "⛔ GATE FAIL [test_gate_icn_unicon_pattern_operators_parse_at_unicons_precedence]"; exit 1; }
echo "✅ GATE PASS [test_gate_icn_unicon_pattern_operators_parse_at_unicons_precedence]: ??, .|, ->, =>, .> and the backquote parse at the levels of unigram.y"
exit 0
