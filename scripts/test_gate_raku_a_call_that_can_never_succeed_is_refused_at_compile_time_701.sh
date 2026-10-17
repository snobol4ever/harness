#!/usr/bin/env bash
# test_gate_raku_a_call_that_can_never_succeed_is_refused_at_compile_time_701.sh -- a call to a known non-multi user sub whose
# positional argument is a literal that can never satisfy the parameter's declared nominal type is refused before any code runs,
# through the one voice's located form, as error 701 (the cto's ruling on hq_raku's ask, 2026-10-11 04:xx CDT: 700-799 are the
# compile-time semantic refusals of any language; 701 is a call that can never succeed against its callee's declared signature).
# THE RED (master entry sub_say_9, wantrc 1, empty ref): sub f(Int $x) { say($x); } f(7); f("x"); say("after"); -- rakudo-local
# 2026.05 prints nothing and exits 1 (===SORRY!=== Calling f(Str) will never work with declared signature (Int $x)); SCRIP on origin
# ran it, printed 7, then raised the run-time binding error. THE CURE: lower_raku_refuse (src/lower/lower_raku.c), called by the
# driver's Raku branch before a segment is recorded: mode 3 exits 1 before execution, mode 4's compile exits 1 and writes no .s.
# THE SCOPE (narrow, so nothing Rakudo runs is refused): one declaration of the name in the program, not a multi, no @ % & sigil,
# no type holding : ( ) * | or \ (a smiley, a coercion, a slurpy, a capture), no parameter default (Rakudo raises those at run
# time), the call's argument count equal to the parameter count; judged only: a non-numeric Str literal to Int, Num, Rat or Numeric,
# and an Int literal to Str. A numeric word (<42>, an allomorph) and every non-literal argument are never judged.
# ARMS, each in mode 3 and mode 4, stdout and rc as rakudo-local printed them: refused (1) sub_say_9's shape, (2) the call in a sub
# body that never runs, (3) a two-parameter signature; controls that keep running (4) an Int literal to Int, (5) a Str literal to
# Str, (6) a variable holding a Str passed to Int (the run-time error, as Rakudo), (7) a multi sub, (8) a parameter default and
# (9) a :D smiley (both Rakudo's run-time error, not refused), (10) an allomorph word (never judged: graded only as not refused).
# FAIL_ONCE=1 grades arm 1 as a control, so it reds.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; G=raku_a_call_that_can_never_succeed_is_refused_at_compile_time_701
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/rk701.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
n=0
arm() { n=$((n+1)); printf '%s\n' "$4" > "$W/a$n.raku"; printf '%s' "$1" > "$W/a$n.out"; echo "$2" > "$W/a$n.rc"; echo "$3" > "$W/a$n.kind"; }
arm '' 1 refuse 'sub f(Int $x) { say($x); }
 f(7); f("x"); say("after");'
arm '' 1 refuse 'say "b"; sub k(Str $s) { say $s }; sub z { k(5) }; say "c";'
arm '' 1 refuse 'say "b"; sub g(Str $s, Num $n) { say $s }; g("a", "b");'
arm '7
after' 0 run 'sub f(Int $x) { say($x) }; f(7); say "after";'
arm 'x
after' 0 run 'sub f(Str $x) { say($x) }; f("x"); say "after";'
arm 'before' 1 run 'sub f(Int $x) { say($x) }; my $v = "s"; say "before"; f($v); say "after";'
arm 'int 7
str x' 0 run 'multi sub f(Int $x) { say "int $x" }; multi sub f(Str $x) { say "str $x" }; f(7); f("x");'
arm 'b' 1 run 'sub g(Int $x = 3) { say $x }; say "b"; g("x");'
arm 'b' 1 run 'sub g(Int:D $x) { say $x }; say "b"; g("x");'
arm '' 0 unjudged 'sub g(Int $x) { say $x }; say "b"; g(<7>);'
[ "${FAIL_ONCE:-0}" = 1 ] && echo run > "$W/a1.kind"
bad=0
for i in $(seq 1 $n); do
    kind=$(cat "$W/a$i.kind"); want=$(cat "$W/a$i.out"); wrc=$(cat "$W/a$i.rc")
    o3=$(cd "$W" && timeout -k 5 60 "$ROOT/scrip" "$W/a$i.raku" < /dev/null 2> "$W/a$i.e3"); r3=$?
    ( cd "$W" && timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/a$i.s" "$W/a$i.raku" < /dev/null > /dev/null 2> "$W/a$i.ec" ); rc=$?
    v3=$(grep -c '^scrip: error 701: ' "$W/a$i.e3"); vc=$(grep -c '^scrip: error 701: ' "$W/a$i.ec")
    if [ "$kind" = refuse ]; then
        if [ "$o3" = "$want" ] && [ $r3 -eq 1 ] && [ "$v3" -eq 1 ] && [ $rc -eq 1 ] && [ "$vc" -eq 1 ] && [ ! -e "$W/a$i.s" ]; then echo "  ok  ($i) refused 701 before any code: m3 rc 1, no output; m4 compile rc 1, no .s"
        else echo "  RED ($i) want a 701 refusal: m3 rc $r3 701x$v3 out '$(printf '%s' "$o3" | head -1 | cut -c1-40)'; compile rc $rc 701x$vc .s $([ -e "$W/a$i.s" ] && echo written || echo absent)"; bad=1; fi
        continue
    fi
    if [ $rc -ne 0 ] || [ "$vc" -ne 0 ] || [ "$v3" -ne 0 ] || ! gcc -no-pie -o "$W/a$i.bin" "$W/a$i.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > /dev/null 2>&1; then
        echo "  RED ($i) a $kind arm was refused or did not build: m3 701x$v3, compile rc $rc 701x$vc"; bad=1; continue
    fi
    [ "$kind" = unjudged ] && { echo "  ok  ($i) never judged: compiled and ran without a 701 refusal"; continue; }
    o4=$(cd "$W" && timeout -k 5 60 "$W/a$i.bin" < /dev/null 2> /dev/null); r4=$?
    if [ "$o3" = "$want" ] && [ "$o4" = "$want" ] && [ $r3 -eq "$wrc" ] && [ $r4 -eq "$wrc" ]; then echo "  ok  ($i) runs as Rakudo in m3 and m4 (rc $wrc)"
    else echo "  RED ($i) want rc $wrc '$(printf '%s' "$want" | tr '\n' '|')', m3 rc $r3 '$(printf '%s' "$o3" | tr '\n' '|' | cut -c1-40)', m4 rc $r4 '$(printf '%s' "$o4" | tr '\n' '|' | cut -c1-40)'"; bad=1; fi
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a call that can never succeed is refused as error 701 before any code runs, and the $((n - 3)) controls run as Rakudo runs them, both modes (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: the compile-time 701 refusal misjudges a call (tree SCRIP=$TREE)"; exit 1
