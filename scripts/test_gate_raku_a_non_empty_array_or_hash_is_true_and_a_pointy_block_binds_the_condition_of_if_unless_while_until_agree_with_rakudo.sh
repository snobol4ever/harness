#!/usr/bin/env bash
# test_gate_raku_a_non_empty_array_or_hash_is_true_and_a_pointy_block_binds_the_condition_of_if_unless_while_until_agree_with_rakudo.sh -- `if @q`, `while @queue`, `so @a`, `?@a`, `@a ?? ..`, `@a && ..`, `%h` AS A BOOLEAN, AND `if C -> $x { }` / `elsif C -> $y` / `unless C -> $z` / `while C -> $x` / `until C -> $u`
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by classifying the failing sampled Roast files: S04-statements/while.t (19 failures), S04-statements/if.t, S04-statements/unless.t, S04-statements/sink.t and the integration/advent files that use `while @queue`).
#
# THE DEFECTS, measured against Rakudo (and unchanged on the control build of the sitting's base commit): (1) THE TRUTH OF AN ARRAY WAS FALSE AND THE TRUTH OF AN EMPTY HASH WAS TRUE: `my @q = 1, 2; if @q { say "t" } else { say "f" }` printed f, `while @queue { ... }` never ran, `so @q` and `?@q` were False, `@q ?? "y" !! "n"` answered n, `@q && "and"` answered the array,
# `%z ?? ...` (an EMPTY hash) answered true and `(1, 2).Bool` was True only by luck of the data path; every truthiness entry (rk_is_truthy, __rk_mkbool / __rk_notbool, __rk_bool, __rk_bool_val) treated an array or a table as a string whose text is empty. (2) A POINTY BLOCK ON A CONDITIONAL STATEMENT LOST ITS PARAMETER: `if 5 -> $x { say $x }`, `elsif 7 -> $y`, `unless 0 -> $z`,
# `while $i > 2 -> $x { print $x }` and `until 0 -> $u` were refused by the native emitter ("variable 'x' is read but never assigned"): the recognizer dropped the signature (only `for` used it).
# THE CURE: (by_name_dispatch.c rk_agg_truth) an array is true when it has an element and a hash when it has a key, in all four truthiness entries; (rk_syntax.c r_xblock, rk_tree.c rkb_pointy / rk_pointy_cond) a single-parameter pointy signature on if / elsif / unless / while / until is recorded against its block and the condition becomes the assignment `$x = COND`, whose value is the condition's value, so the binding and the test are one evaluation.
# NOT HERE (own rows, measured): a two-parameter pointy block on a conditional; `with C -> $x` was already handled; `my @x := @todo[$x]; @x.shift` aliasing (RakBench rc-9-billion-names); the `Bool` of a lazy sequence or a range is the count of the realised elements.
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP ac10903ab before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_a_non_empty_array_or_hash_is_true_and_a_pointy_block_binds_the_condition_of_if_unless_while_until_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_non_empty_array_or_hash_is_true_and_a_pointy_block_binds_the_condition_of_if_unless_while_until_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
my @q = 1, 2;
my @e;
my %h = a => 1;
my %z;
say so @q;
say so @e;
say so %h;
say so %z;
say ?@q;
say !@e;
say @q ?? "y" !! "n";
say @e ?? "y" !! "n";
if @q { say "if-q" }
if @e { say "if-e" } else { say "else-e" }
unless @e { say "unless-e" }
if %h { say "if-h" }
if (1, 2) { say "if-list" }
if () { say "no" } else { say "else-empty-list" }
my $c = 0;
my @w = 1, 2, 3;
while @w { @w.shift; $c++ }
say $c;
say (@q && "and");
say (@e || "or");
say (@q).Bool;
say @e.Bool;
my $s = @q;
say so $s;
say (1, 2).Bool;
say ().Bool;
my $i = 5;
while $i > 2 -> $x {
    print $x;
    $i--
}
say "";
my @a = 1, 2, 3;
while @a.shift -> $x {
    print $x;
}
say "";
my $n = 3;
while $n-- -> $x {
    print $x;
}
say "";
if 5 -> $x { say $x }
if 0 { say "no" } elsif 7 -> $y { say $y }
unless 0 -> $z { say $z }
until 0 -> $u {
    say $u;
    last;
}
my @qq = 1, 2;
if @qq -> $l { say $l.elems }
my @queue = 1, 2, 3;
my $sum = 0;
while @queue {
    $sum += @queue.shift;
}
say $sum;
my %seen;
say %seen ?? "has" !! "empty";
%seen<a> = 1;
say %seen ?? "has" !! "empty";
EOF
cat > "$W/w.ref" <<'EOF'
True
False
True
False
True
True
y
n
if-q
else-e
unless-e
if-h
if-list
else-empty-list
3
and
or
True
False
True
True
False
TrueTrueTrue
123
321
5
7
0
0
2
6
empty
has
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a truthiness / pointy-condition result that disagrees with Rakudo"
