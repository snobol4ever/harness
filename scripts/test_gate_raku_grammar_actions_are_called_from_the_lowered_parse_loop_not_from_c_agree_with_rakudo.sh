#!/usr/bin/env bash
# test_gate_raku_grammar_actions_are_called_from_the_lowered_parse_loop_not_from_c_agree_with_rakudo.sh -- GRAMMAR ACTIONS ARE BOX CALLS, NOT A C WALK OVER THE MATCH TREE
# (row raku-no-c-site-calls-user-code-the-21-rt-call-proc-descr-roads-become-open-roads-or-emitted-loops-ceo-1600, ARCH-RAKU-BOXES section 4 step 1; CEO-1576; the shape told to the cfo,
# whose regex chunk 2 retires it when an action becomes a call at the rule's gamma).
#
# THE DEFECT: G.parse(str, :actions(A)) ran grammar_parse_core, then rk_apply_actions walked the Match tree in C and invoked each action method through invoke_method_proc, the C road
# into a box CEO-1576 deleted (rt_call_proc_descr: A__num reached a C road into a box, DELETED; rc 139). Two more defects the road hid: `make EXPR` written as a listop with an infix
# argument stayed an undefined call `make`, and a quantified named capture ($<num> of <num>+) and a hyper method over it were Lists where Rakudo has Arrays.
# THE CURE: lower_raku.c rk_parse_actions_walk lowers .parse / .subparse with an actions argument (the pair or the positional the parser leaves) into the parse without it, a C leaf
# __rk_actions_plan that returns the post-order (method name, Match) plan as a typed list, and an emitted loop calling each through __rk_named_call's open road; rk_apply_actions keeps
# only a named bomb. rk_make_walk makes a plain make(x) __rk_make($/, x). rk_rx_slot and __rk_hyper_meth keep the Array container.
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), every non-open C-to-BB trace entry required to be 0, then under
# SCRIP_GC_STRESS 1 3 5 in both modes: the row's witness grammar, a summing calculator, the :actions(...) form, a four-rule key/value grammar, an actions instance, 100 parses in a loop.
# FAILED ONCE, measured on SCRIP c5b26a2a8 before the cure: rc 139 at the first action in both modes.
#
# EXIT: 0 every witness matches in both modes with 0 non-open entries; 1 a mismatch, a crash or an entry; 2 REFUSED (stale binary, no gcc).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_grammar_actions_are_called_from_the_lowered_parse_loop_not_from_c_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/actions.raku" <<'EOF'
grammar G {
  token TOP { <num>+ % "," }
  token num { \d+ }
}
class A {
  method num($/) { make $/.Int * 2 }
  method TOP($/) { make $<num>>>.made }
}
say G.parse("1,2,3", actions => A).made;
grammar Calc {
    token TOP { <term>+ % '+' }
    token term { \d+ }
}
class CalcA {
    method term($/) { make +$/ }
    method TOP($/) { make [+] $<term>>>.made }
}
say Calc.parse("1+2+30", actions => CalcA).made;
my $m = Calc.parse("4+5", :actions(CalcA));
say $m.made;
grammar KV {
    token TOP { <pair>+ % ';' }
    token pair { <key> '=' <val> }
    token key { \w+ }
    token val { \w+ }
}
class KVA {
    method key($/) { make ~$/ }
    method val($/) { make ~$/ }
    method pair($/) { make $<key>.made ~ ":" ~ $<val>.made }
    method TOP($/) { make $<pair>>>.made.join(",") }
}
say KV.parse("a=1;b=2;c=3", actions => KVA).made;
my $obj = KVA.new;
say KV.parse("x=9", actions => $obj).made;
my $tot = 0;
for 1..100 -> $i { $tot += Calc.parse("$i+$i", actions => CalcA).made }
say $tot;
EOF
cat > "$W/actions.ref" <<'EOF'
[2 4 6]
33
9
a:1,b:2,c:3
x:9
10100
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc ent
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} SCRIP_C2BB_TRACE="$W/$w.$m.tr" timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} SCRIP_C2BB_TRACE="$W/$w.$m.tr" timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ne 0 ]; then printf '  FAIL %-7s %s%s: died rc=%s\n' "$w" "$m" "${ST:+ stress=$ST}" "$rc"; fails=$((fails + 1)); return; fi
    ent=0; [ -s "$W/$w.$m.tr" ] && ent=$(grep -vc '\.open	' "$W/$w.$m.tr"); rm -f "$W/$w.$m.tr"
    if [ "$ent" != 0 ]; then printf '  FAIL %-7s %s: %s non-open C-to-BB entries (want 0)\n' "$w" "$m" "$ent"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s%s: got [%s] want [%s]\n' "$w" "$m" "${ST:+ stress=$ST}" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in actions; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in actions; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a grammar action result that disagrees with Rakudo, a crash, or a non-open C-to-BB entry"
