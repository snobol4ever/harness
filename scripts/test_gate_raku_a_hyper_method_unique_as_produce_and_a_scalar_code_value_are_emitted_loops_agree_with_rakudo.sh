#!/usr/bin/env bash
# test_gate_raku_a_hyper_method_unique_as_produce_and_a_scalar_code_value_are_emitted_loops_agree_with_rakudo.sh -- THE RESIDUAL C LOOPS THAT CALLED USER CODE ARE EMITTED LOOPS
# (row raku-hyper-methods-unique-as-produce-and-a-code-value-in-a-scalar-are-emitted-loops-not-c-loops-ceo-1600; ARCH-RAKU-BOXES section 4 step 1; CEO-1576).
#
# THE DEFECT: after the step-1 landings four C loops still reached user code and so CEO-1576's named bomb (rk_proc_descr_rq ... reached user code with no request channel, rc 139):
# __rk_hyper_meth called meth_call per element from C (a hyper method over objects with a user method), rk_list_more_methods called the block for unique / squish / repeated :as and for
# produce, and map over a code value held in a $-variable fell to the C list loop.
# THE CURE (lower_raku.c): rk_hyper_meth_walk (before capture analysis) rewrites @x>>.m(args) into a .map over a block calling .m(args) on the topic -- the emitted loop, each call
# through meth_call's open road -- with __rk_hyper_done keeping an Array receiver's container; rk_lower_iter_meth emits produce (k 6: __rk_produce_init / _step / _last / _done
# hold the running value and the results in a typed two-slot record) and unique / squish / repeated :as (k 7: __rk_keyed_init / _step / _done keep the keys, compared as strings exactly
# as the C loop did), and calls a $-scalar code value given to map through TT_INVOKE (map requires a Callable). The C loops keep only their no-user-code arms.
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), every non-open C-to-BB trace entry required to be 0, then under
# SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP 626d52fae before the cure: rc 139 at the first hyper method in both modes.
#
# EXIT: 0 every witness matches in both modes with 0 non-open entries; 1 a mismatch, a crash or an entry; 2 REFUSED (stale binary, no gcc).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_hyper_method_unique_as_produce_and_a_scalar_code_value_are_emitted_loops_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/residual.raku" <<'EOF'
class P { has $.v; method n { $!v * 2 }; method add($k) { $!v + $k } }
my @ps = P.new(v => 1), P.new(v => 2), P.new(v => 3);
say @ps>>.n;
say (@ps>>.add(10));
sub tw { my $off = 100; say @ps>>.add($off) }
tw();
say <a b c>>>.uc;
my @w = <x y>; say @w>>.uc; say (@w>>.uc).WHAT;
say (1,2,3,4,5).unique(:as({ $_ % 3 }));
say (1,1,2,2,1).squish(:as({ $_ }));
say <a A b B a>.repeated(:as({ .lc }));
say (1,2,3,4).produce({ $^a + $^b });
say ().produce({ $^a + $^b });
sub pr { my $m = 10; say (1,2,3).produce({ $^a * $m + $^b }) }
pr();
my $c = { $_ * 2 }; say (1,2,3).map($c);
my $sq = -> $x { $x * $x }; say (1..4).map($sq);
EOF
cat > "$W/residual.ref" <<'EOF'
[2 4 6]
[11 12 13]
[101 102 103]
(A B C)
[X Y]
(Array)
(1 2 3)
(1 2 1)
(A B a)
(1 3 6 10)
()
(1 12 123)
(2 4 6)
(1 4 9 16)
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
ST=""; for w in residual; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in residual; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a hyper method, keyed unique, produce or scalar code value that disagrees with Rakudo, a crash, or a non-open C-to-BB entry"
