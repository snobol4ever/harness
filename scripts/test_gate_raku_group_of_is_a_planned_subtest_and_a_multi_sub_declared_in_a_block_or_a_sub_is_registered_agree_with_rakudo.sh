#!/usr/bin/env bash
# test_gate_raku_group_of_is_a_planned_subtest_and_a_multi_sub_declared_in_a_block_or_a_sub_is_registered_agree_with_rakudo.sh -- Test::Util's `group-of N => 'description' => { ... }` AND `multi sub` / `my multi sub` DECLARED BELOW THE TOP LEVEL (in a bare block, a sub body, a nested block)
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by naming the functions behind the "scrip: error 22: undefined function called" aborts of the sampled Roast files with gdb: group-of is used by 40 Roast files, a block-scoped multi by S06-multi/lexical-multis.t).
#
# THE DEFECTS, measured against Rakudo: (1) `group-of` is the helper of Roast's Test::Util (`use lib $*PROGRAM.parent(2).add("packages/Test-Helpers"); use Test::Util;`, 238 files) that runs a block as a subtest with a plan: `group-of 2 => 'desc' => { ok 1; is 2, 2 }`; SCRIP had no such function, so each file died "undefined function called" at its first group and every later assertion was lost: across the 40 files that use it
# the ok lines went from 7 to 899 once it exists (S32-num/rat.t alone 735); (2) a `multi sub foo(Int $x) {...}` / `my multi sub foo(...)` declared inside a bare block, a sub body or a nested block was never registered as a multi (the lowerer discovers multis only among the program's own top-level statements, the same hole classes had): `{ multi sub foo(Int $x) { "int" } multi sub foo(Str $x) { "str" } say foo(1) }`
# died "undefined function called", as did the `my multi sub` forms in a sub (S06-multi/lexical-multis.t).
# THE CURE: (rk_tree.c rk_testop_build, testop_rt) `group-of N => D => BLOCK` is built as `subtest D, { plan N; BLOCK.() }` (the subtest machinery the Test module already has); (lower_raku.c rk_hoist_nested_multis, a pass after rk_hoist_nested_types) a multi declaration below the top level, outside any class, role or grammar, moves to the program's top level and leaves an empty sequence behind, so the existing multi registration sees it.
# NOT HERE (own rows, measured): a hoisted multi does not see the enclosing block's lexical variables, and two blocks declaring the same multi name merge into one family; a lexical (non-multi) sub of the same name in a nested block does not shadow the outer one (`{ my sub foo { 1 } { my sub foo { 2 }; say foo() } }` prints 1 where Rakudo prints 2); fails-like, is-path, doesn't-hang and is_run's process arms of Test::Util; `unshift @unshift, (1, 2, 3)` with an array named like the function (S32-array/unshift.t aborts "undefined function called" at its 71st test).
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku, cwd the roast checkout so Test::Util loads), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP ac10903ab before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_group_of_is_a_planned_subtest_and_a_multi_sub_declared_in_a_block_or_a_sub_is_registered_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_group_of_is_a_planned_subtest_and_a_multi_sub_declared_in_a_block_or_a_sub_is_registered_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
use Test;
use lib "/home/resources/roast-master/packages/Test-Helpers";
use Test::Util;
plan 3;
group-of 2 => 'first group' => {
    ok 1, 'one';
    is 2, 2, 'two';
}
group-of 1 => 'second group' => {
    is 'a', 'a', 'x';
}
my $n = 0;
group-of 3 => 'counted group' => {
    for 1 .. 3 { $n += $_; ok $n > 0, "step $_" }
}
say $n;
{
    multi sub foo(Int $x) { "int" }
    multi sub foo(Str $x) { "str" }
    say foo(1);
    say foo("a");
}
sub w {
    my multi sub bar(Int $x) { "i" }
    my multi sub bar(Str $x) { "s" }
    bar(1) ~ bar("a")
}
say w();
{
    my multi baz(Int $x) { "I" }
    my multi baz(Str $x) { "S" }
    say baz(2);
    say baz("b");
}
sub deeper {
    {
        multi sub qux(Int $x) { "qi" }
        multi sub qux(Str $x) { "qs" }
        return qux(3) ~ qux("c");
    }
}
say deeper();
EOF
cat > "$W/w.ref" <<'EOF'
1..3
# Subtest: first group
    1..2
    ok 1 - one
    ok 2 - two
ok 1 - first group
# Subtest: second group
    1..1
    ok 1 - x
ok 2 - second group
# Subtest: counted group
    1..3
    ok 1 - step 1
    ok 2 - step 2
    ok 3 - step 3
ok 3 - counted group
6
int
str
is
I
S
qiqs
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a group-of / block-scoped multi result that disagrees with Rakudo"
