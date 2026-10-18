#!/usr/bin/env bash
# test_gate_raku_eval_compiles_a_string_in_process_in_both_modes.sh -- EVAL OF A RAKU STRING: PARSE, LOWER, EMIT AND RUN IN THE PROCESS, MODE 3 AND MODE 4 ALIKE, AND THE TEST FORMS THAT READ IT
# (row raku-every-suite-to-100-under-nonet-ceo-1266; the cto's answer to ask-raku-eval-runtime-compile, 2026-10-07: libscrip_rt.so already carries the Raku frontend, so EVAL is the road SNOBOL4 EVAL and Prolog assertz take, in BOTH modes).
#
# THE DEFECT, measured over the 880 Roast files that compile: 169 use EVAL or eval-lives-ok / eval-dies-ok, 131 more reach it through throws-like on a string; none passed and 135 aborted at the first one. A Raku
# EVAL string was handed to the SNOBOL4 EVAL by name, so only a string that is also a SNOBOL4 expression ("1 + 2") worked; "my $x = 5; $x * 2" printed nothing.
# THE CURE: __rk_eval (by_name_dispatch.c) calls rt_raku_eval_compile (runtime_eval.c, the one new function in that shared file): it parses the string with rk_parse_tree, puts the non-declaration statements in a sub
# EVAL$<n> (declarations stay top level, the last statement returns its value), lowers through lower_raku_stage2 (re-entrant now: a second call extends g_stage2 and keeps the multi-name table) and emits the new procs
# with rk_emit_new_procs, which mirrors the driver's per-proc registration and emission (jmpentry, pinned, optimizer, slot assignment, entry cells, GC maps). The eval'd code reads the program's file-scope variables as
# globals (lower_raku_eval_reads_are_globals; a program that calls EVAL keeps its file-scope names in the global table, rk_eval_main_globals), so it works in a mode-4 binary whose compile-time tables are empty.
# A parse error throws X::Syntax::Confused / X::Undeclared / X::Comp::AdHoc; the parser maps EVAL(...) to the builtin and eval-lives-ok / eval-dies-ok / throws-like on a string to try + __rk_eval. A trailing
# if/unless in a sub, a hoisted block or an eval returns its branch value (rk_tail_if).
# NOT HERE (own rows): eval'd code does not see a SUB's locals (only globals), EVAL :lang<Perl5>, EVALFILE, the exact X::Syntax subclass Rakudo picks for a given error, and the Rakudo subtest lines of throws-like (the gate compares
# the ok / not ok verdicts and the program's own output, not the indented subtest body).
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes: values (int, string, list), a sub and a class defined inside an
# EVAL, a global and a file-scope my read and written from EVAL, an exception thrown inside EVAL and read through $!, eval-lives-ok / eval-dies-ok, throws-like on a string, in a block and with a message matcher.
# FAILED ONCE, measured on SCRIP 6d69fc2f1 before the cure: 8 of 8 witness-mode pairs red (EVAL of a Raku statement string printed Nil, eval-lives-ok / eval-dies-ok / throws-like on a string all reported not ok).
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_eval_compiles_a_string_in_process_in_both_modes.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_eval_compiles_a_string_in_process_in_both_modes"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/eval.raku" <<'EOF'
use Test;
say EVAL("1 + 2");
my $r = EVAL 'my $x = 5; $x * 2'; say $r;
say EVAL('"abc".uc');
say EVAL('sub twice($n) { $n * 2 }; twice(21)');
our $g = 10; say EVAL('$g + 1');
my $lex = 7; say EVAL('$lex * 3');
my @a = EVAL('(1,2,3).map(* * 2)'); say @a;
try { EVAL('die "inner"') }; say $!.message;
try { EVAL('die "inner2"') }; say $!.WHAT;
say EVAL('class Foo2 { method m { 42 } }; Foo2.new.m');
say EVAL('my @l = 1..5; @l.sum');
say EVAL('if 1 { "yes" } else { "no" }');
say EVAL('');
EVAL('$g = 99'); say $g;
eval-lives-ok '1 + 2', "lives";
eval-lives-ok 'my $x = 5; $x * 2', "lives 2";
eval-dies-ok 'die "x"', "dies";
eval-dies-ok '1 +', "syntax dies";
eval-lives-ok 'die "x"', "lives but dies";
throws-like 'die "boom"', X::AdHoc, "string throws";
throws-like 'die "boom"', X::AdHoc, message => /oo/, "string throws msg";
throws-like 'die "boom"', X::AdHoc, message => /xx/, "string throws wrong msg";
throws-like '1', X::AdHoc, "string does not throw";
throws-like { EVAL 'die "q"' }, X::AdHoc, "eval in block";
lives-ok { EVAL '1' }, "lives block";
is EVAL('2 * 3'), 6, "EVAL value";
is-deeply EVAL('(1,2,3)'), (1,2,3), "EVAL list";
done-testing;
EOF
cat > "$W/eval.ref" <<'EOF'
3
10
ABC
42
11
21
[2 4 6]
inner
(AdHoc)
42
15
yes
Nil
99
ok 1 - lives
ok 2 - lives 2
ok 3 - dies
ok 4 - syntax dies
not ok 5 - lives but dies
ok 6 - string throws
ok 7 - string throws msg
not ok 8 - string throws wrong msg
not ok 9 - string does not throw
ok 10 - eval in block
ok 11 - lives block
ok 12 - EVAL value
ok 13 - EVAL list
1..13
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
    out="$(printf '%s\n' "$out" | grep -vE '^( |#)')"
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in eval; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in eval; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: an EVAL value, an eval-lives-ok / eval-dies-ok / throws-like-on-a-string verdict that disagrees with Rakudo"
