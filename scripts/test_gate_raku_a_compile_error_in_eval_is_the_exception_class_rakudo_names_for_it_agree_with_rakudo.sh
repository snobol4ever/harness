#!/usr/bin/env bash
# test_gate_raku_a_compile_error_in_eval_is_the_exception_class_rakudo_names_for_it_agree_with_rakudo.sh -- EVAL OF CODE RAKUDO REJECTS RAISES THE X::Obsolete / X::Syntax::Missing / X::Syntax::Malformed / X::Redeclaration / X::Syntax::Regex::... CLASS RAKUDO NAMES, NOT X::Comp::AdHoc
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by running 240 of the 311 single-line `throws-like 'code', X::Class` tests of Roast under both Rakudo and scrip: Rakudo passes 220, scrip passed 9; of the 211 it failed, 69 ALREADY RAISED an error from the hand-written parser (the messages are translated from Rakudo's Grammar) and only the CLASS was wrong).
#
# THE DEFECT, measured against Rakudo: EVAL's failure path (by_name_dispatch.c __rk_eval) chose the exception class by three needles ("Confused" -> X::Syntax::Confused, "not declared" -> X::Undeclared, everything else X::Comp::AdHoc), so `try { EVAL '/abc\z/'; CATCH { default { say .^name } } }` printed X::Comp::AdHoc where Rakudo prints X::Obsolete, and `throws-like { EVAL '...' }, X::Syntax::Missing` and every other typed compile-error test failed whatever the parser had detected.
# THE CURE: a needle table rk_comp_tab (the parser's own message text -> the class Rakudo names for it, with its parent) is consulted by __rk_eval and registered by rk_exc_init: "Unsupported use of" -> X::Obsolete, "Quantifier quantifies nothing" -> X::Syntax::Regex::SolitaryQuantifier, "Null regex not allowed" -> X::Syntax::Regex::NullRegex, "Missing block" / "Missing initializer" -> X::Syntax::Missing, "Malformed" / "Bogus statement" -> X::Syntax::Malformed, "Redeclaration of" / "already has a method" -> X::Redeclaration, "Cannot declare a match variable" / "a numeric variable" -> X::Syntax::Variable::Match / ::Numeric, "Name component may not be null" -> X::Syntax::Name::Null, "Cannot add tokens of category" -> X::Syntax::Reserved, "Opening bracket required for #`" -> X::Syntax::Comment::Embedded, `"unless" does not take "elsi"` -> X::Syntax::UnlessElse, "Non-variable $ must be backslashed" -> X::Backslash::NonVariableDollar; each is an X::Comp (X::Syntax for the syntax ones) so `throws-like {..}, X::Comp` holds too.
# NOT HERE (own rows, measured): the 112 of the 211 failing single-line cases where scrip raises NOTHING (the check is not implemented: X::Syntax::Number::LiteralType 14, X::Multi::NoMatch 11 for a list method on an Int, X::Undeclared::Symbols 11 and X::Undeclared 8 -- scrip's EVAL reads an undeclared variable as Nil and aborts the whole program on an undeclared routine, X::TypeCheck::Assignment 10, X::Assignment::RO 7, X::Cannot::Map 5, X::ControlFlow::Return 5), `qr/foo/` (the parser does not reach its own "Unsupported use of qr" check and says "Missing required term after infix"), the cases where Rakudo wraps several errors in X::Comp::Group, and the attributes of the exceptions (X::Syntax::Missing.what).
# THE WITNESS (31 probes, one class name per line, cut by the INSTALLED Rakudo 2022.12), graded in m3 (--run) and m4 (--compile + link), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on the sitting's control build cfcfaf46d: every probe printed X::Comp::AdHoc (0 of 31 lines agree).
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_a_compile_error_in_eval_is_the_exception_class_rakudo_names_for_it_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_compile_error_in_eval_is_the_exception_class_rakudo_names_for_it_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
use MONKEY-SEE-NO-EVAL;
sub probe(Str $code) {
    try { EVAL $code; say 'NOERR'; CATCH { default { say .^name } } }
}
probe('/  /');
probe('/\\Qabc d?\\E/');
probe('constant ($a, $b) = (3, 4)');
probe('"foo" ~~ m/o{1,}/');
probe('/  + abc/');
probe('use v6.d; sub meow:sym«bar» {}');
probe('rand(3)');
probe('#`');
probe('if 1; 2');
probe('/abc\\z/');
probe('/\\Z/');
probe('my class C { my method foo { say "OMG" }; my method foo { say "WTF" } }');
probe('{my $x = 2;');
probe('my $a; ${a} = 5');
probe('for (my $i; $i <=3; $i++) { $i; }');
probe('my $<a>');
probe('/\\B/');
probe('/\\Aabc/');
probe('my Any :D $a');
probe('my $0');
probe('my $a::::b');
probe('.::');
probe('my class C { our method foo { say "OMG" }; our method foo { say "WTF" } }');
probe('my $x = ');
probe('/\\b/');
probe('rand()');
probe('unless 1 { } elsif 42 { }');
probe('$_ = "axbycz"; y/abc/def/');
probe('Foo->new');
probe('"$"');
probe(':2');

EOF
cat > "$W/w.ref" <<'EOF'
X::Syntax::Regex::NullRegex
X::Obsolete
X::Syntax::Missing
X::Obsolete
X::Syntax::Regex::SolitaryQuantifier
X::Syntax::Reserved
X::Obsolete
X::Syntax::Comment::Embedded
X::Syntax::Missing
X::Obsolete
X::Obsolete
X::Redeclaration
X::Syntax::Missing
X::Obsolete
X::Obsolete
X::Syntax::Variable::Match
X::Obsolete
X::Obsolete
X::Syntax::Malformed
X::Syntax::Variable::Numeric
X::Syntax::Name::Null
X::Syntax::Malformed
X::Redeclaration
X::Syntax::Malformed
X::Obsolete
X::Obsolete
X::Syntax::UnlessElse
X::Obsolete
X::Obsolete
X::Backslash::NonVariableDollar
X::Syntax::Malformed
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile --out="$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-7s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
        if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in w; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in w; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a compile-error exception class that disagrees with Rakudo"
