#!/usr/bin/env bash
# test_gate_raku_an_exception_is_a_value_that_die_carries_and_catch_and_throws_like_read.sh -- AN EXCEPTION IS A TYPED VALUE: die CARRIES IT, $! HOLDS IT, CATCH CATCHES IN ANY BLOCK, throws-like READS IT
# (row raku-every-suite-to-100-under-nonet-ceo-1266, Lon 2026-09-25: "use IPC sync-step monitor to crawl the test suites to 100%"; the Roast compile census after the Match landing: `$!` 20 first-refusals, and throws-like in 54 of 240 sampled compiled files).
#
# THE DEFECT: an exception was only a message string in one fixed C buffer (g_script_exception). `$!` was refused by the compile guard; X::AdHoc.new(payload=>..) was rewritten by the parser to its bare payload string
# and `when X::AdHoc` to a default arm; a die with an object lost the object; CATCH worked only directly inside `try` (a CATCH in a bare block or a sub body was ignored and the die killed the program); `try` as an
# expression yielded "" instead of its body's value (`my $r = try { 5 }`; `try { die } // "d"` stopped the program); a `return` inside a try body leaked the try depth so every later die was swallowed;
# and throws-like was "PARSED BUT NOT IMPLEMENTED" -- a red on every file that used it, whatever else it did right.
# THE CURE (by_name_dispatch.c, lower_raku.c, rk_tree.c): an exception is a DATA instance of a class that isa Exception -- the builtin X::AdHoc(payload), the runtime-error classes (X::Numeric::DivideByZero,
# X::Multi::NoMatch, X::TypeCheck::Binding/Assignment, X::OutOfRange, ...; a message table classifies what C raises) and any user `class E is Exception`. `die`/.throw store the object in the Raku global "!" (the
# rooted named-variable table: no new C global) and raise its message; try_enter clears "!", the catch path (exc_get, exc_clear) fills it from the pending message when a C-raised error did not; `$!` is the provider
# __rk_pre("!"); `$_` in CATCH is the object (.message, .WHAT, ~~ Type, "$_" all work). A CATCH in any block or sub body wraps the block in the same try with a default arm that rethrows (`__rk_rethrow`) when no
# `when` matched, as Rakudo does; `try` yields its body's last value (Nil on failure); a return inside a try exits the try depth it sits in (rcx_t.try_depth); throws-like { } , Type, [desc], key => matcher...
# is desugared by the tree builder like lives-ok/dies-ok into try + __rk_test_throws_like($!, Type, ...) which checks the class (isa, through the MRO) and each key as a smartmatch of the exception's method.
# NOT HERE (own rows): EVAL of a string (throws-like 'code' and eval-lives-ok need a runtime compile), Failure objects (Rakudo returns a Failure from 5/0 and throws on sink), the exception backtrace,
# .resume, the runtime errors the table does not classify (they are X::AdHoc), and CATCH's `.rethrow` of a modified exception.
#
# THE WITNESSES, each graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku): exc (the value, $!, try, CATCH in blocks and subs, rethrow, nesting, return inside the
# wrapped sub) exact; tl (throws-like pass/fail verdicts over class, message regex/string, user attribute, no-throw, wrong class/message/attribute) compared on its `ok`/`not ok` lines. Then the same two under
# SCRIP_GC_STRESS 1 3 5, both modes.
# FAILED ONCE, measured on SCRIP 889e90550 before the cure: 16 of 16 witness-mode pairs red (exc refused at the compile guard on the bang variable in both modes and empty in m3; tl reds every throws-like line).
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_an_exception_is_a_value_that_die_carries_and_catch_and_throws_like_read.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_an_exception_is_a_value_that_die_carries_and_catch_and_throws_like_read"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/exc.raku" <<'EOF'
class MyE is Exception { has $.n; method message { "MyE " ~ $.n } }
try { die "boom" };
say $!.message; say $!.WHAT; say $!.defined; say $! ~~ X::AdHoc; say $! ~~ Exception; say $!.isa(Exception);
try { 1 }; say $!.defined;
my $r = try { 5 }; say $r;
my $q = try { die "x"; 5 } // "dflt"; say $q;
my $e = X::AdHoc.new(payload => "pp");
say $e.message; say $e.payload; say $e.WHAT;
try { $e.throw }; say "got: ", $!.message;
try { MyE.new(n => 3).throw }; say $!.message; say $!.n; say $!.WHAT; say $! ~~ MyE; say $! ~~ Exception;
try { die MyE.new(n => 6) }; say $!.message; say "str: $!";
{ die "oops"; CATCH { when X::AdHoc { say "adhoc: ", .message } } }
{ die "z"; CATCH { default { say "any: $_" } } }
sub h($x) { die "neg" if $x < 0; return $x * 2; CATCH { default { say "h caught: ", .message } } }
say h(3); say h(-1); say h(4);
sub k { die "boom"; CATCH { when X::AdHoc { say "k adhoc ", .message } } }
k(); say "after k";
sub u { die "bad"; CATCH { when MyE { say "no" } } }
try { u(); say "not reached" }
say "u rethrown: ", $!.message;
try { try { die "inner" }; say "inner: ", $!.message; die "outer" }
say "outer: ", $!.message;
say try { MyE.new(n => 1).message };
EOF
cat > "$W/exc.ref" <<'EOF'
boom
(AdHoc)
True
True
True
True
False
5
dflt
pp
pp
(AdHoc)
got: pp
MyE 3
3
(MyE)
True
True
MyE 6
str: MyE 6
adhoc: oops
any: z
6
h caught: neg
Nil
8
k adhoc boom
after k
u rethrown: bad
inner: inner
outer: outer
MyE 1
EOF
cat > "$W/tl.raku" <<'EOF'
use Test;
class MyE is Exception { has $.n; method message { "MyE " ~ $.n } }
throws-like { die "boom" }, X::AdHoc, "adhoc";
throws-like { die "boom" }, Exception, "exception base", message => "boom";
throws-like { die "boom" }, X::AdHoc, message => /oo/, "regex message";
throws-like { MyE.new(n => 3).throw }, MyE, n => 3, "user class";
throws-like { die MyE.new(n => 4) }, Exception, message => "MyE 4";
throws-like { 1 }, X::AdHoc, "does not throw";
throws-like { die "x" }, MyE, "wrong class";
throws-like { die "boom" }, X::AdHoc, message => "other", "wrong message";
throws-like { die "boom" }, X::AdHoc, message => /^bo/, "anchored";
throws-like { MyE.new(n => 7).throw }, MyE, n => 8, "wrong attribute";
done-testing;
EOF
cat > "$W/tl.ref" <<'EOF'
ok 1 - adhoc
ok 2 - exception base
ok 3 - regex message
ok 4 - user class
ok 5 - did we throws-like Exception?
not ok 6 - does not throw
not ok 7 - wrong class
not ok 8 - wrong message
ok 9 - anchored
not ok 10 - wrong attribute
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
    if [ "$w" = tl ]; then out="$(printf '%s\n' "$out" | grep -E '^(not )?ok ')"; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in exc tl; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in exc tl; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: an exception value, the bang variable, CATCH or throws-like verdict that disagrees with Rakudo"
