#!/usr/bin/env bash
# test_gate_raku_gather_and_the_sequence_operator_are_lazy_generator_boxes_with_no_cap.sh -- `gather`/`take` and the sequence operator `...` are lazy generator boxes
# (row raku-gather-take-and-the-sequence-operator-are-lazy-generator-boxes-with-no-cap-ceo-1600; the cto; CEO-1600 step 2, the escape boundary CEO-1619).
# THE DESIGN (lower_raku.c, by_name_dispatch.c, rt.c). A gather body is a hoisted block that is a GENERATOR PROC on Icon's suspend road: its `take` is IR_SUSPEND, a
# `for` over a gather pumps it through IR_PROC_GEN (the generator's frame retained on the consumer's stack, every value delivered at the γ landing, no collector array,
# no cap), an array assignment, say/print, [i], .head(n) and the eager methods pump it with a bound where one exists. A gather that ESCAPES (a scalar, a return, an
# argument, a take, an infinite sequence assigned to an array, .map/.grep/.first stages) becomes a Seq: a block whose source is the body's Closure and whose cache is a
# List, pulled ONE VALUE AT A TIME through the heap generator handle rt_genp_s (rt_proc_call_gen_h / rt_proc_resume_frame_h, the body on its own coroutine stack) by
# every reader that needs element i, elems, a slice or a pull; a take in a block nested inside the body (map's block) or in a called sub is a DYNAMIC take that delivers
# through the handle (rt_genp_deliver_γ). The parser's __rk_seq call is desugared in the lowerer into a gather whose loop takes the seeds, then the deduced arithmetic,
# geometric or string-successor step (pure leaves __rk_seq_plan/__rk_seq_next/__rk_seq_stop, no user code in C) or the seed block as a compiled call, and stops at the
# endpoint value, block or whatever as Rakudo does; rk_sequence and its 1000/100000 caps are deleted. .map/.grep/.first on a lazy receiver are generator stages.
# THE WITNESS, every ref cut by Rakudo at generation: the five DONE-WHEN programs (an infinite sequence indexed at 5000, a geometric one at 20, .head(3) of an infinite
# gather, an array assignment of a finite gather, a map.grep.head chain over an infinite sequence, .is-lazy, the lazy INTERLEAVING of an escaping gather with its
# consumer, an infinite gather returned from a sub and indexed), Roast's "gather is lazy" count, an infinite sequence assigned to an array and sliced, .first on an
# infinite sequence, a nested gather taken as a value, a Seq read twice, a gather's .is-lazy; both modes; then the five DONE-WHEN programs under the collector plant at a
# 64 KB window (SCRIP_GC_STRESS 1 and 3, both modes) and one chain-checked run (SCRIP_GC_CHAIN_CHECK=3: missing=0, mapdiff=0); then the census that rk_sequence and the
# caps are gone from by_name_dispatch.c. FAIL-ONCE: on the base tree 4f4752498 every DONE-WHEN witness read RED (the eager desugar hit the heap cap or refused).
# RE-CUT (cfo 2026-10-17, row gate-raku-gather-witness-w6-prints-false-where-rakudo-prints-true-in-both-modes-ceo-1807): w6's last line, (gather { take 1 }).is-lazy, was typed as True; Rakudo
# v2026.05 (rakudo-local) and v2022.12 (apt) both print False, and SCRIP has printed False since bc0390872 (a Seq is lazy only when it comes from an infinite range). The whole w6 ref now
# equals both Rakudos' output line for line.
# EXIT: 0 every witness-mode pair equals Rakudo's output and the census is clean; 1 one differs; 2 REFUSED (stale binary, no gcc).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_gather_and_the_sequence_operator_are_lazy_generator_boxes_with_no_cap"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w1.raku" <<'EOF'
say (1 ... *)[5000];
say (1, 2, 4 ... *)[20];
EOF
printf '5001\n1048576\n' > "$W/w1.ref"
cat > "$W/w2.raku" <<'EOF'
say (gather { my $i = 0; loop { take $i++ } }).head(3);
my @g = gather { for 1..5 { take $_ * 2 } }; say @g;
EOF
printf '(0 1 2)\n[2 4 6 8 10]\n' > "$W/w2.ref"
cat > "$W/w3.raku" <<'EOF'
say (1 ... *).map({ $_ * $_ }).grep({ $_ %% 3 }).head(4);
say (1 ... *).is-lazy;
EOF
printf '(9 36 81 144)\nTrue\n' > "$W/w3.ref"
cat > "$W/w4.raku" <<'EOF'
my $s = gather { for 1..3 { say "producing $_"; take $_ } };
say "before";
for @$s -> $x { say "got $x" }
EOF
printf 'before\nproducing 1\ngot 1\nproducing 2\ngot 2\nproducing 3\ngot 3\n' > "$W/w4.ref"
cat > "$W/w5.raku" <<'EOF'
sub lazy-evens { gather { my $i = 0; loop { take $i; $i += 2 } } }
my $e = lazy-evens();
say "before";
say $e[3];
say "after";
EOF
printf 'before\n6\nafter\n' > "$W/w5.ref"
cat > "$W/w6.raku" <<'EOF'
my $count = 0;
my $list = gather { for 1 .. 10 -> $a { take $a; $count++ } };
my $result = $list[2];
say $count;
my @f = 1, 1, * + * ... *;
say @f[0..7];
say (1 ... *).first(* > 5);
my @nested = gather { for 1..2 -> $i { take gather { take $i; take $i * 10 } } };
say @nested[1];
my $twice = gather { take 7; take 8 };
say $twice[0];
say $twice[0];
say $twice[1];
say (gather { take 1 }).is-lazy;
EOF
printf '2\n(1 1 2 3 5 8 13 21)\n6\n(2 20)\n7\n7\n8\nFalse\n' > "$W/w6.ref"
fails=0; GATE_EXAMINED=0
build4() {
    local w="$1"
    timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
      && gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1
}
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(timeout -k 5 30 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! build4 "$w"; then printf '  FAIL %-3s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(timeout -k 5 30 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-3s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-3s %s\n' "$w" "$m"
    else printf '  FAIL %-3s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
echo "arm 1: the five DONE-WHEN witnesses and the laziness witness, both modes, against Rakudo's refs"
for w in w1 w2 w3 w4 w5 w6; do for m in m3 m4; do ck "$w" "$m"; done; done
echo "arm 2: the five DONE-WHEN witnesses under the collector plant at a 64 KB window, SCRIP_GC_STRESS 1 and 3, both modes"
unset SCRIP_HEAP_MB SCRIP_HEAP_KB
sf=0
for s in 1 3; do for m in m3 m4; do for w in w1 w2 w3 w4 w5; do
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=$s timeout -k 5 300 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"
    else out="$(SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=$s timeout -k 5 300 "$W/$w.bin" 2>/dev/null </dev/null)"; fi
    if [ "$out" != "$(cat "$W/$w.ref")" ]; then printf '  FAIL %s %s stress=%s: wrong answer under the collector\n' "$w" "$m" "$s"; fails=$((fails + 1)); sf=1; fi
done; done; done
[ "$sf" -eq 0 ] && echo "  ok   w1..w5 x stress 1 3 x m3 m4 at 64 KB"
echo "arm 3: one chain-checked run of each DONE-WHEN witness (SCRIP_GC_CHAIN_CHECK=3 at 64 KB, stress 1): missing=0 and mapdiff=0"
cf=0
for w in w1 w2 w3 w4 w5; do
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    err="$(SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3 timeout -k 5 300 "$ROOT/scrip" --run "$W/$w.raku" 2>&1 >/dev/null </dev/null | grep 'CHAIN-WALK\] SUMMARY' | tail -1)"
    case "$err" in *"missing=0"*"mapdiff=0"*) ;; *) printf '  FAIL %s chain check: %s\n' "$w" "$(printf '%s' "$err" | cut -c1-120)"; fails=$((fails + 1)); cf=1;; esac
done
[ "$cf" -eq 0 ] && echo "  ok   w1..w5 chain-checked: missing=0 mapdiff=0"
echo "arm 4: the census -- rk_sequence and its caps are gone from by_name_dispatch.c, every Raku take lowers to a suspend or a dynamic take, the parser's __rk_seq is desugared in the lowerer"
GATE_EXAMINED=$((GATE_EXAMINED + 1))
n=$(grep -c 'infinite ? 1000\|static DESCR_t rk_sequence(' "$ROOT/src/runtime/by_name_dispatch.c")
if [ "$n" -ne 0 ]; then printf '  FAIL census: %s line(s) of the C sequence loop or its caps survive in by_name_dispatch.c\n' "$n"; fails=$((fails + 1)); else echo "  ok   census: rk_sequence and its caps are gone"; fi
GATE_EXAMINED=$((GATE_EXAMINED + 1))
if grep -q 'rk_seq_to_gather' "$ROOT/src/lower/lower_raku.c" && grep -q '"__rk_take_dyn"' "$ROOT/src/lower/lower_raku.c"; then echo "  ok   census: the lowerer desugars __rk_seq and lowers a dynamic take"
else echo "  FAIL census: rk_seq_to_gather or __rk_take_dyn missing from lower_raku.c"; fails=$((fails + 1)); fi
gate_verdict "$fails" "witness-mode pair(s) or census arm(s) wrong: a gather or a sequence is not a lazy generator box"
