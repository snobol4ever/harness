#!/usr/bin/env bash
# test_gate_raku_a_substitution_block_a_smartmatch_block_a_when_block_and_a_code_variable_are_called_from_emitted_code_agree_with_rakudo.sh -- THE BLOCK ROADS C USED TO WALK ARE EMITTED
# (row raku-no-c-site-calls-user-code-the-21-rt-call-proc-descr-roads-become-open-roads-or-emitted-loops-ceo-1600, ARCH-RAKU-BOXES section 4 step 1; CEO-1576).
#
# THE DEFECT: four block roads called user code from C and died on CEO-1576's named bomb (rt_call_proc_descr: __blk_N reached a C road into a box, DELETED; rc 139): s/// with a code
# replacement or any interpolated replacement (rk_rx_subst_run called the block per match), smartmatch against a block or a code variable (__rk_smartmatch called it), a `when`
# whose condition is a block, and map / grep / first / reduce over a code VARIABLE (`my &f`; the C list loops called it).
# THE CURE (lower_raku.c): rk_subst_code_walk lowers a substitution whose replacement is a block into open / while next { put(block()) } / close over four C leaves that hold the
# match state in a typed sixteen-slot array (by_name_dispatch.c rk_subst_open / _next / _put / _close; the box calls the block, C never does); rk_smartmatch_code_walk and
# rk_case_match make `x ~~ BLOCK` and `when BLOCK` the block's direct call made Bool (rk_code_call1: a literal block, a closure with its refs, or a code variable through TT_INVOKE);
# rk_lower_iter_meth accepts a code variable and calls it through TT_INVOKE in the emitted loop.
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), every non-open C-to-BB trace entry required to be 0, then under
# SCRIP_GC_STRESS 1 3 5 in both modes, with 200 iterations of a code substitution and a smartmatch block so the collector runs inside the emitted loops.
# FAILED ONCE, measured on SCRIP c5b26a2a8 before the cure: rc 139 at the first substitution in both modes.
#
# EXIT: 0 every witness matches in both modes with 0 non-open entries; 1 a mismatch, a crash or an entry; 2 REFUSED (stale binary, no gcc).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_substitution_block_a_smartmatch_block_a_when_block_and_a_code_variable_are_called_from_emitted_code_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/blockroads.raku" <<'EOF'
my $s = "a1b22c333"; $s ~~ s:g/(\d+)/{ $0.chars }/; say $s;
my $t = "hello world"; $t ~~ s/(\w+)/{ $0.uc }/; say $t;
my $u = "abc"; $u ~~ s/x/{ "y" }/; say $u;
my $w = "x1y2"; my $r = $w ~~ s:g/(\d)/<$0>/; say $w; say so $r;
sub f($n) { my $q = "aaa"; $q ~~ s:g/a/{ $n }/; $q }
say f(7);
say S:g/o/0/ given "foo boo";
my $k = 0; my $v = "a b c"; $v ~~ s:g/\w/{ ++$k }/; say $v; say $k;
say 7 ~~ { $_ > 5 };
say "abc" ~~ { .chars == 3 };
say 5 ~~ { 42 };
my &big = { $_ > 3 }; say 5 ~~ &big; say 2 ~~ &big;
sub lim { my $l = 4; say 5 ~~ { $_ > $l } }
lim();
given 7 { when { $_ > 5 } { say "big" }; default { say "small" } }
given 2 { when { $_ > 5 } { say "big" }; default { say "small" } }
my @r = (1..10).grep({ $_ ~~ { $_ %% 3 } }); say @r;
my &tri = { $_ * 3 }; say (1,2,3).map(&tri);
my &odd = { $_ % 2 }; say (1..6).grep(&odd); say (4,5,6).first(&odd);
my &add = { $^a + $^b }; say (1..5).reduce(&add);
my $n = 0; for 1..200 -> $i { my $x = "a$i"; $x ~~ s:g/(\d)/{ $0 + 1 }/; $n += $x.chars; $n += (($i ~~ { $_ %% 2 }) ?? 1 !! 0) }
say $n;
EOF
cat > "$W/blockroads.ref" <<'EOF'
a1b2c3
HELLO world
abc
x<1>y<2>
True
777
f00 b00
1 2 3
3
True
True
True
True
False
True
big
small
[3 6 9]
(3 6 9)
(1 3 5)
5
15
832
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc ent
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} SCRIP_C2BB_TRACE="$W/$w.$m.tr" timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile --out="$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
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
ST=""; for w in blockroads; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in blockroads; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a substitution, smartmatch, when or code-variable block road that disagrees with Rakudo, a crash, or a non-open C-to-BB entry"
