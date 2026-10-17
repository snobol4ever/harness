#!/usr/bin/env bash
# test_gate_raku_the_activation_frame_is_carved_and_released_by_the_emitted_prologue.sh -- A RAKU CALL CROSSES NO C HELPER TO CARVE, FILL OR RELEASE ITS FRAME
# (row raku-the-block-protocol-reaches-its-own-call-regime-the-six-frame-helpers-leave-every-raku-graph-ceo-1488; Lon 2026-10-03: "Oh you want all languages to use
# the ZETA technique and ASM not C. Yes that one send as high priority since it is huge speed increase."; ceo CEO-1491; design of record
# .github/ARCH-PROLOG-C-OUT-OF-THE-BOX.md section 1 and 1.6a, as landed for Prolog at SCRIP e95282e39).
#
# THE POPULATION. A Raku graph is on the block protocol when lower_raku.c marks it (a TT_SUB_DECL proc with no slurpy and no named rest: IR_graph_t.block_args),
# frame_layout.c zls_g_block_args holds (a zframe graph, not Icon's cells, not pinned, not the root, no locals), and nparams <= 12. Everything else keeps its road
# and its mode-4 text byte-identical (the control arm, run by hand at the landing: 38 non-Raku programs compiled before and after, 0 differing once the gc_poll
# source-line tags are normalised).
#
# THE PROTOCOL. The caller's cells ARE the callee's parameter cells: the direct-call stub (xa_flat.cpp xa_flat_dc_stub_str) carves a 16*nparams block on the spine,
# copies the caller's argument DESCRs into it, loads the two wires and jumps to the graph's block entry (<family>_αblk), past the staged entry; the callee's
# prologue carves kt below the block and zeroes its value region inline (unrolled stores, or rep stosq past 128 bytes), invalidates the string-extension table
# inline as rt_icn_zframe_args_install did (SCRIP c8701b17e: a string held by a frame variable is never extended in place), and addresses parameter i at
# [rsp+kt+16i]; gamma and omega release frame AND block in one instruction (add rsp,kt+16*nparams). EVERY OTHER ROAD INTO THE GRAPH is unchanged: the graph's
# registered entry is a STAGED ENTRY emitted before the block entry (xa_flat_block_staged_entry), which builds the same block from g_call_args (a cell beyond
# the medium's capacity a null DESCR) and falls into the block entry, so rt_proc_enter, rt_proc_call_open*, the c2bb glue, rk_method_open and every
# by-name call site need no edit. A call site whose callee is a block graph asks no NRETURN consult (a Raku callee has none): rt_nret_fix_tiny leaves it.
# The six helpers rt_jmp_frame_lexprep2, rt_icn_zframe_args_install, rt_arg_stage, rt_proc_drop_frame_h, rt_proc_call_open_det and rt_nret_fix_tiny are no longer
# emitted for a Raku call.
#
# THE ARMS.
#  1. THE SIX NAMED NOWHERE: the mode-4 text of the Raku benchmark kernels listed below names none of the six at a call site. FAILED ONCE, measured on SCRIP
#     9e6279478 over the 76 Raku kernels that compile: rt_icn_zframe_args_install 49, rt_arg_stage 92, rt_nret_fix_tiny 15 (the other three 0).
#  2. FIVE WITNESSES, each in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku): calls (recursion, 0 to 7 parameters, nested
#     calls as arguments, a default and an optional parameter, deep recursion), byname (a stored block and a sub in a variable called directly, a sub passed to
#     map, a block to sort and grep, methods and an inherited override, multi dispatch, a reduce with a pointy block), strings (a string passed to a sub and
#     extended there is not extended in the caller: the Icon c8701b17e shape), gcstress (calls whose arguments are heap values, run again under SCRIP_GC_STRESS
#     at the shrunk collector window in both modes: the block cells are visited as the typed DESCRs they are), shapes (12 and 13 parameters, a slurpy and a
#     named parameter: the graphs outside the population keep their road and still answer as Rakudo does).
# NOT HERE: a graph with a slurpy or a named rest parameter, more than 12 parameters, locals, a generator or the root keeps the staged road and its helpers.
# KNOWN GAPS FOUND ON THE WAY, each its own row, unchanged by this landing (base == new): sort with a named sub as comparator, calling a sub object held in a
# list as .(5), a sub named none (collides with the junction function).
#
# EXIT: 0 every arm green; 1 a helper site remains or a witness differs; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_the_activation_frame_is_carved_and_released_by_the_emitted_prologue.sh   (~40s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_activation_frame_is_carved_and_released_by_the_emitted_prologue"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
fails=0; GATE_EXAMINED=0
echo "arm 1: the six helpers named at no call site in the mode-4 text of the Raku kernels"
sites=0; nk=0
for k in rakudo-tools-02-10-000-sub-dispatches rakudo-tools-03-10-000-multi-dispatches rakudo-tools-04-10-000-method-dispatches merge-sort insertion-sort point_class_add point_class_add2 parse-json mb-for_param_sigil string-escape; do
    f="$S4E/corpus/benchmarks/raku/$k.raku"; [ -f "$f" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: kernel $f absent"; exit 2; }
    SCRIP_DIAG=0 timeout -k 5 120 "$ROOT/scrip" --compile -o "$W/$k.s" "$f" < /dev/null > /dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: kernel $k did not compile"; exit 2; }
    nk=$((nk + 1)); GATE_EXAMINED=$((GATE_EXAMINED + 1))
    c=$(grep -cE 'call[[:space:]]+(qword ptr \[rip \+ )?(rt_jmp_frame_lexprep2|rt_icn_zframe_args_install|rt_arg_stage|rt_proc_drop_frame_h|rt_proc_call_open_det|rt_nret_fix_tiny)\b' "$W/$k.s")
    sites=$((sites + c))
done
if [ "$sites" -eq 0 ]; then echo "  ok   0 call sites into the six over $nk Raku kernels"; else echo "  FAIL $sites call site(s) into the six remain over $nk Raku kernels"; fails=$((fails + 1)); fi
cat > "$W/calls.raku" <<'EOF'
sub fib($n) { return $n < 2 ?? $n !! fib($n - 1) + fib($n - 2); }
say fib(18);
sub add2($a, $b) { $a + $b }
sub add3($a, $b, $c) { $a + $b + $c }
sub add4($a, $b, $c, $d) { $a + $b + $c + $d }
sub add5($a, $b, $c, $d, $e) { $a + $b + $c + $d + $e }
sub add7($a, $b, $c, $d, $e, $f, $g) { $a + $b + $c + $d + $e + $f + $g }
say add2(1, 2); say add3(1, 2, 3); say add4(1, 2, 3, 4); say add5(1, 2, 3, 4, 5); say add7(1, 2, 3, 4, 5, 6, 7);
say add2(add2(1, 2), add3(3, 4, 5));
sub nothing() { 42 }
say nothing();
sub dflt($x, $y = 5) { "$x $y" }
say dflt(1); say dflt(1, 2);
sub opt($x, $y?) { $x.defined ~ $y.defined }
say opt(1); say opt(1, 2);
sub ack($m, $n) { $m == 0 ?? $n + 1 !! $n == 0 ?? ack($m - 1, 1) !! ack($m - 1, ack($m, $n - 1)) }
say ack(2, 3);
sub depth($n) { $n == 0 ?? 0 !! 1 + depth($n - 1) }
say depth(3000);
EOF
cat > "$W/calls.ref" <<'EOF'
2584
3
6
10
15
28
15
42
1 5
1 2
TrueFalse
TrueTrue
9
3000
EOF
cat > "$W/byname.raku" <<'EOF'
my $f = -> $x { $x + 1 };
say $f(1);
my &g = sub ($a, $b) { $a * $b };
say g(6, 7);
sub h($x) { $x * 10 }
say (1, 2, 3).map(&h);
say (3, 1, 2).sort({ $^a <=> $^b });
say (1, 2, 3, 4).grep({ $_ %% 2 }).map({ $_ * $_ });
class P {
    has $.v = 3;
    method m($x) { $x * $!v }
    method n($x, $y) { $x + $y + $!v }
}
class Q is P {
    method m($x) { callsame() + 1 }
}
say P.new.m(4); say Q.new(v => 5).m(2); say P.new.n(1, 2);
multi sub mm(Int $x) { "int $x" }
multi sub mm(Str $x) { "str $x" }
say mm(5); say mm("a");
my @subs = (sub ($x) { $x + 1 }, sub ($x) { $x * 2 });
say @subs[0](5) + @subs[1](5);
say (1, 2, 3).reduce(-> $a, $b { $a + $b });
EOF
cat > "$W/byname.ref" <<'EOF'
2
42
(10 20 30)
(1 2 3)
(4 16)
12
11
6
int 5
str a
16
6
EOF
cat > "$W/strings.raku" <<'EOF'
sub f($s) { my $t = $s ~ "x"; return $t ~ "y" }
my $a = "ab"; my $b = f($a); say $a; say $b;
sub g($s) { my $u = $s ~ "1"; my $v = $s ~ "2"; return $u ~ $v }
say g("q"); say g("rs");
my $acc = "";
for 1..5 { $acc = $acc ~ $_ }
say $acc;
sub rep($s, $n) {
    my $r = "";
    for 1..$n { $r = $r ~ $s }
    return $r;
}
say rep("ab", 4); say rep("z", 0);
sub keep($s) { my $t = $s; my $w = $s ~ "!"; return $t ~ $w }
say keep("hi");
EOF
cat > "$W/strings.ref" <<'EOF'
ab
abxy
q1q2
rs1rs2
12345
abababab

hihi!
EOF
cat > "$W/gcstress.raku" <<'EOF'
sub mk($n) { my @a = (1..$n).map({ "s$_" }); return @a }
sub tot($xs, $k) {
    my $c = 0;
    for $xs.list -> $x { $c += $x.chars }
    return $c + $k;
}
sub walk($n, $acc) { $n == 0 ?? $acc !! walk($n - 1, $acc ~ "k") }
my $sum = 0;
for 1..40 {
    my @x = mk(20);
    $sum += tot(@x, $_);
}
say $sum;
say walk(200, "").chars;
sub nest($d, $a, $b) { $d == 0 ?? "$a$b" !! nest($d - 1, $b ~ "L", $a ~ "R") }
say nest(30, "a", "b").chars;
my @r = (1..30).map(-> $i { tot(mk(5), $i) });
say @r.sum;
EOF
cat > "$W/gcstress.ref" <<'EOF'
2860
200
62
765
EOF
cat > "$W/shapes.raku" <<'EOF'
sub twelve($a1,$a2,$a3,$a4,$a5,$a6,$a7,$a8,$a9,$a10,$a11,$a12) { $a1 + $a2 + $a3 + $a4 + $a5 + $a6 + $a7 + $a8 + $a9 + $a10 + $a11 + $a12 }
sub thirteen($a1,$a2,$a3,$a4,$a5,$a6,$a7,$a8,$a9,$a10,$a11,$a12,$a13) { $a1 + $a13 + $a7 }
say twelve(1,2,3,4,5,6,7,8,9,10,11,12);
say thirteen(1,2,3,4,5,6,7,8,9,10,11,12,13);
sub slurp(*@a) { @a.elems }
say slurp(1,2,3);
sub named($x, :$k = 3) { "$x $k" }
say named(1); say named(1, :k(9));
EOF
cat > "$W/shapes.ref" <<'EOF'
78
21
3
1 3
1 9
EOF
echo "arm 2: the witnesses against Rakudo, both modes"
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(timeout -k 5 60 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        out="$(timeout -k 5 60 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-9s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-9s %s\n' "$w" "$m"
    else printf '  FAIL %-9s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
for w in calls byname strings gcstress shapes; do
    if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
       || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
        printf '  FAIL %-9s m4: did not build (%s)\n' "$w" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); continue; fi
    for m in m3 m4; do ck "$w" "$m"; done
done
echo "arm 3: the collector over the argument blocks: calls and gcstress under SCRIP_GC_STRESS at the shrunk window, both modes"
unset SCRIP_HEAP_MB; export SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-128}" SCRIP_HEAP_MAX_MB="${SCRIP_HEAP_MAX_MB:-512}"
for w in calls gcstress strings; do for s in 1 3 5; do for m in m3 m4; do
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(SCRIP_GC_STRESS=$s timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; else out="$(SCRIP_GC_STRESS=$s timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then :; else printf '  FAIL %-9s %s stress=%s: wrong answer under the collector\n' "$w" "$m" "$s"; fails=$((fails + 1)); fi
done; done; done
[ "$fails" -eq 0 ] && echo "  ok   calls gcstress strings x stress 1 3 5 x m3 m4"
gate_verdict "$fails" "check(s) wrong: a helper call site still emitted for a Raku call, a witness that differs from Rakudo, or an argument block the collector lost"
