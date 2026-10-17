#!/usr/bin/env bash
# test_gate_raku_builtin_gaps_and_is_run_agree_with_rakudo.sh -- THE BUILTIN GAPS THE ROAST SWEEP NAMED, THE FILE-SCOPE TOPIC, Order::X / Bool::X, is_run AND is-eqv
# (row raku-every-suite-to-100-under-nonet-ceo-1266, Lon 2026-09-25: "use IPC sync-step monitor to crawl the test suites to 100%"; measured by running all 880 compiled Roast files once and tallying what kills the 558 that abort before their plan completes).
#
# THE DEFECTS, each measured against Rakudo with a one-line probe (a 137-expression sweep: 58 differed): "hello".comb(2) split into single characters; samecase, .codes, "3.7".Num and 0b101 / 0o17 literals were absent or 0;
# list .rotate .pairs .antipairs .batch .repeated .squish were absent; 10.log(10) ignored the base and 12345.6789.round(0.01) ignored the scale; 100.polymod(10,10) was absent; .subst(/re/, "x", :g) ignored the regex and the
# flag; `$_` read at file scope was refused by the compile guard (19 first-refusals); Order::Same / Bool::True printed as type objects, so every is(1 <=> 1, Order::Same) failed; is() stringified a list as ARRAY('0:2');
# and is_run -- 44 of the 145 aborts with "undefined function called", 55 of the 880 files use it -- and is-eqv did not exist.
# THE CURE: rt_str_method arms (comb(n), codes, samecase, Num/Numeric on strings, rotate, pairs, antipairs, batch, repeated, squish, polymod, log(base), round(scale), subst with a regex and :g), rkb_number for 0b/0o/0d,
# the main body pre-assigns `$_` (Nil), Order::X and Bool::X are __rk_pre values (rk_predeclared, and ahead of the qualified-type literal), is() and isnt() stringify through rk_tap_str (lists, objects, type objects),
# and the Test shim gains is_run (writes the program to a temp file, runs this build's scrip on it in a child with the input and :args, compares status/out/err by smartmatch exactly as Test::Util does: status defaults to 0
# unless err is given and non-empty; scrip is /proc/self/exe in mode 3 and <libscrip_rt.so dir>/../scrip in mode 4) and is-eqv (eqv). 
# NOT HERE (own rows): method calls on a standard handle ($*OUT.say crashes at lowering -- BOMB "IR_VAR arg names a local with no LOWER-granted varslot", measured on base too), Rat arithmetic (0.1+0.2 prints
# 0.30000000000000004, 1/3 prints a Num, 1.5.WHAT is Num), Set/Bag/Mix, the Seq flavour of .raku, X and Z returning nested lists, the Range type, IO::Path.
#
# THE WITNESSES, each graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku; the is_run ref is cut with the roast Test::Util module): builtins (exact), isrun (its ok / not ok lines),
# then builtins under SCRIP_GC_STRESS 1 3 5, both modes.
# FAILED ONCE, measured on SCRIP 54f0de728 before the cure: 10 of 10 witness-mode pairs red (builtins refused at the compile guard on the file-scope topic in m4 and empty in m3; isrun empty in both).
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_builtin_gaps_and_is_run_agree_with_rakudo.sh   (~15s, no oracle at run time, no network; is_run spawns this build's scrip)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_builtin_gaps_and_is_run_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/builtins.raku" <<'EOF'
say "hello".comb(2).join("|");
say "hello".comb(3).join("|");
say "Hello".samecase("abc");
say "hello".samecase("AB");
say 0b101; say 0o17; say 0x1f; say 1_000;
say "3.7".Num; say "42".Numeric; say "abc".codes;
say (1,2,3).rotate(1).join(","); say (1,2,3).rotate(-1).join(","); say (1,2,3).rotate(4).join(",");
say (1,2,3).pairs.join(" "); say (1,2,3).antipairs.join(" ");
say (1,2,3,4,5).batch(2).join("|");
say (1,1,2,1).repeated.join(","); say (1,1,2,2,1).squish.join(",");
say 100.log(10); say 8.log(2);
say 12345.6789.round(0.01); say 7.round(5); say 2.5.round;
say 7.polymod(3).join(","); say 100.polymod(10, 10).join(",");
say "aabb".subst(/a/,"X",:g); say "aabb".subst(/a/,"X"); say "a1b22".subst(/\d+/,"#",:g); say "abc".subst(/x/,"Y");
say $_.defined;
say Order::More; say Order::Less == Order::Less;
say (Bool::True, Bool::False).join(",");
EOF
cat > "$W/builtins.ref" <<'EOF'
he|ll|o
hel|lo
hello
HELLO
5
15
31
1000
3.7
42
3
2,3,1
3,1,2
2,3,1
0	1 1	2 2	3
1	0 2	1 3	2
1 2|3 4|5
1,1
1,2,1
2
3
12345.68
5
3
1,2
0,0,1
XXbb
Xabb
a#b#
abc
False
More
True
True,False
EOF
cat > "$W/isrun.raku" <<'EOF'
use Test;
is_run 'say "hi"', { out => "hi\n", status => 0 }, "plain output";
is_run 'say "hi"', { out => "no\n" }, "wrong output";
is_run 'say "hi"', { out => /^hi/ }, "regex output";
is_run 'die "bad"', { status => 1, err => /bad/ }, "die";
is_run 'say 1', { out => "1\n" }, "default status";
is_run 'say 1', { out => "1\n", status => 3 }, "wrong status";
is_run 'say 1; exit 3', { out => "1\n", status => 3 }, "exit code";
is_run 'my @a = 1,2,3; say @a.sum', { out => "6\n" }, "program computes";
is-eqv (1,2), (1,2), "eqv lists";
is-eqv 1, 1.0, "not eqv";
is-eqv "a", "a", "eqv strings";
done-testing;
EOF
cat > "$W/isrun.ref" <<'EOF'
ok 1 - plain output
not ok 2 - wrong output
ok 3 - regex output
ok 4 - die
ok 5 - default status
not ok 6 - wrong status
ok 7 - exit code
ok 8 - program computes
ok 9 - eqv lists
not ok 10 - not eqv
ok 11 - eqv strings
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
    if [ "$w" = isrun ]; then out="$(printf '%s\n' "$out" | grep -E '^(not )?ok ')"; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in builtins isrun; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in builtins; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a builtin result, a file-scope topic or an is_run/is-eqv verdict that disagrees with Rakudo"
