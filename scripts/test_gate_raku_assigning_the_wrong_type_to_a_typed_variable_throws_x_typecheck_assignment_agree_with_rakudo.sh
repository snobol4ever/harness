#!/usr/bin/env bash
# test_gate_raku_assigning_the_wrong_type_to_a_typed_variable_throws_x_typecheck_assignment_agree_with_rakudo.sh -- `my Int $i = 5; $i = "a"` THROWS X::TypeCheck::Assignment, ALSO FOR A TYPED ARRAY ELEMENT, push AND A HASH VALUE
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by classifying the throws-like cases of Roast (X::TypeCheck::Assignment is in 45 of them, 104 files declare `my Int` / `my Str` / `my Num`) and by probing: a typed declaration was recorded and never enforced).
#
# THE DEFECT, measured against Rakudo: `my Int $i = 5; try { $i = "a"; CATCH { default { say .^name } } }` printed nothing: the assignment succeeded (same for Str, Num, Bool, a user class, `my Int @a; @a[0] = "z"`, `@a.push("q")` and `my Int %h; %h<b> = "x"`), and `say "x".WHAT` ... a typed declaration only fixed the name in the tree.
# THE CURE: (lower_raku.c rk_typed_vars, a pass before the others) a lexical-scope walk over the tree that remembers `my T $x` / `my T @a` / `my T %h` for T in Int, Str, Num, Bool or a class or role the program declares (never a type scrip cannot judge: Rat, Numeric, Real, Cool, Any, subsets, ...), forgets it when the enclosing block, sub or sequence ends, and wraps the right-hand side of the declaration's initializer, of a later `$x = ...` and of `@a[i] = ...` / `%h<k> = ...` / `@a.push(...)` / append / unshift / prepend in __rk_assign_check; (by_name_dispatch.c) the check passes an undefined value (Nil) and anything whose type isa the declared one (Bool isa Int), and otherwise throws X::TypeCheck::Assignment (attributes got, expected, symbol) with Rakudo's message `Type check failed in assignment to $i; expected Int but got Str ("a")` or `Type check failed for an element of @a; ...`; .raku of a Num carries Rakudo's e0 (5.5e0) and of a type object is its name, which that message needs; the prefix `~` of an Int answers a Str (it answered the Int).
# NOT HERE (own rows, measured): a parameter's type on assignment (parameters are read-only in Rakudo), `my Int $i;` holding the (Int) type object instead of Nil, a return type (`--> Int`: X::TypeCheck::Return), `of` and subset constraints, `my Rat $r = 0.5` (Rat is not enforced: decimal literals are Num here), an inner untyped `my $i` that shadows a typed outer `$i` of the same name (scrip keeps one variable per name per routine, so the check still applies to it), Nil assigned through a list ('' for Nil in a list), `my Int $i = Nil` resetting to the type object.
# THE WITNESS (cut by the INSTALLED Rakudo 2022.12), graded in m3 (--run) and m4 (--compile + link), then under SCRIP_GC_STRESS 1 3 5 in both modes. It also holds ordinary integer-producing expressions assigned to `my Int` (div, %, abs, floor, "42".Int, +"17", **, elems, ord, chars) and Str-producing ones (~, x, Str, join, uc) to prove the check raises no false error.
# FAILED ONCE, measured on the sitting's control build cfcfaf46d: the type errors are never raised (the witness differs on its error lines).
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_assigning_the_wrong_type_to_a_typed_variable_throws_x_typecheck_assignment_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_assigning_the_wrong_type_to_a_typed_variable_throws_x_typecheck_assignment_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
class Dog { has $.n }
my Int $i = 5;
for ("a", 5.5e0, Str, [1], {a=>1}, True, 7) -> $v { try { $i = $v; CATCH { default { say .message } } } }
my Str $s = "x";
my $five = 5;
try { $s = $five; CATCH { default { say .message } } }
try { $s = 5.5e0; CATCH { default { say .message } } }
my Int @a;
try { @a[0] = "z"; CATCH { default { say .message } } }
try { @a.push("q"); CATCH { default { say .message } } }
@a.push(3);
@a[1] = 4;
say @a.elems;
my Dog $d;
try { $d = $five; CATCH { default { say .message } } }
try { $d = Dog.new; say "ok dog"; CATCH { default { say .message } } }
my Num $n = 1e0;
try { $n = $five; CATCH { default { say .message } } }
my Bool $b = True;
$b = False;
say $b;
try { $b = 1; say "bool-int-ok?"; CATCH { default { say .message } } }
my Int $j = 3;
$j += 2;
$j++;
$j = $j * 2;
$j = 10 div 3;
$j = 7 % 3;
$j = abs(-4);
$j = (5.7e0).floor;
$j = "42".Int;
$j = +"17";
$j = 2 ** 10;
$j = @a.elems;
$j = ord("a");
$j = "hello".chars;
say $j;
my Str $t = "a" ~ "b";
$t = "x" x 3;
$t = 5.Str;
$t = ~7;
$t = "abc".uc;
$t = join(",", 1, 2);
say $t;
sub f(Int $x) { my Int $y = $x * 2; return $y }
say f(4);
my Int $k;
$k = 3;
say $k;
my Int %h;
%h<a> = 1;
try { %h<b> = "x"; CATCH { default { say .message } } }
say %h;
EOF
cat > "$W/w.ref" <<'EOF'
Type check failed in assignment to $i; expected Int but got Str ("a")
Type check failed in assignment to $i; expected Int but got Num (5.5e0)
Type check failed in assignment to $i; expected Int but got Str (Str)
Type check failed in assignment to $i; expected Int but got Array ([1])
Type check failed in assignment to $i; expected Int but got Hash ({:a(1)})
Type check failed in assignment to $s; expected Str but got Int (5)
Type check failed in assignment to $s; expected Str but got Num (5.5e0)
Type check failed for an element of @a; expected Int but got Str ("z")
Type check failed for an element of @a; expected Int but got Str ("q")
2
Type check failed in assignment to $d; expected Dog but got Int (5)
ok dog
Type check failed in assignment to $n; expected Num but got Int (5)
False
Type check failed in assignment to $b; expected Bool but got Int (1)
5
1,2
8
3
Type check failed for an element of %h; expected Int but got Str ("x")
{a => 1}
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a typed-assignment result that disagrees with Rakudo"
