#!/usr/bin/env bash
# test_gate_raku_a_named_sub_nested_in_a_sub_reads_and_writes_the_enclosing_locals_through_a_reference.sh -- `my sub` INSIDE A SUB CAPTURES THE ENCLOSING SUB'S LOCALS
# (row raku-every-suite-to-100-under-nonet-ceo-1266, M3 second half; cto q-raku-closure-capture non-escaping road; ceo CEO-1479).
# THE DESIGN. A nested named sub that is only ever CALLED (its name appears nowhere but the callee position of a call) takes the enclosing locals it uses as hidden
# leading by-reference parameters, exactly the road a block handed to a synchronous builtin takes (lower_raku.c rk_cap_nested_find): every call site, in the enclosing
# sub and in the nested sub's own recursion, passes the variables ahead of its arguments (IR_VAR_REF from the enclosing sub, the cell itself from inside), and the body
# reads through IR_DEREF and writes through __rk_byref_assign. A nested sub whose name is taken as a value (&name, passed, stored) is not captured and keeps its refusal.
# THE WITNESSES, refs cut by Rakudo (/usr/bin/raku) at generation: nested (param read, local accumulated and pushed, default argument, recursion, a call from a for loop
# and from a map block, a sub calling a sibling, two levels of nesting) and the corpus benchmark rc-mandelbrot (a `my sub` reading MAIN's $max_iterations), both modes,
# and the nested witness under SCRIP_GC_STRESS 1 3 5 at the shrunk window (rc-mandelbrot is NOT in the stress band: its output already differs at SCRIP_HEAP_KB=128 with the sub taking the bound as a parameter, so it is not this landing's; found, rowed in the baton).
# EXIT: 0 every witness-mode pair equals Rakudo's output; 1 one differs; 2 REFUSED (stale binary, no gcc).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_named_sub_nested_in_a_sub_reads_and_writes_the_enclosing_locals_through_a_reference"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/nested.raku" <<'EOF'
sub outer(Int $n, Str $tag) {
    my $total = 0;
    my @seen;
    my sub add($x) { $total += $x * $n; @seen.push($x); }
    my sub label($y, $z = 2) { return "$tag-$y-$z-$total"; }
    my sub fact($k) { return $k <= 1 ?? 1 !! $k * fact($k - 1) * ($n - $n + 1); }
    add(1); add(2);
    for 1 .. 3 -> $i { add($i); }
    say label(7);
    say label(8, 9);
    say fact(5);
    say (1, 2, 3).map: { label($_) };
    say "total=$total seen=@seen[]";
    return $total;
}
say outer(3, "t");
sub counter(Int $start) {
    my $c = $start;
    my sub bump() { $c++; return $c; }
    my sub twice() { bump(); bump(); }
    twice();
    bump();
    return $c;
}
say counter(10);
sub deep($a) {
    my $b = 5;
    my sub mid($p) {
        my sub inner($q) { return $q + $a + $b; }
        return inner($p) * 2;
    }
    return mid(1);
}
say deep(100);
EOF
cat > "$W/nested.ref" <<'EOF'
t-7-2-27
t-8-9-27
120
(t-1-2-27 t-2-2-27 t-3-2-27)
total=27 seen=1 2 1 2 3
27
13
212
EOF
cat > "$W/mandel.raku" <<'EOF'
constant SQUISH = 1.5;

sub MAIN(Int $w = 31, Int $max_iterations = 50) {
    my $h = round($w / SQUISH);

    my ($re_min, $re_max) = (-2,   1/2);
    my ($im_min, $im_max) = (-5/4, 5/4);

    my $re_step = ($re_max - $re_min) / ($w - 1);
    my $im_step = ($im_max - $im_min) / ($h - 1);

    # Allow SCALE == 0 for compile time testing
    exit(0) if $w < 2;

    my @color_map = ' ', < . , ; * $ # @ >;

    my sub mandelbrot($c) {
        my $z = $c;
        for 1 .. $max_iterations {
            $z = $z * $z + $c;
            return $_ if abs($z) > 2;
        }
        0;
    }

    loop (my $y = $im_max; $y >= $im_min; $y -= $im_step) {
        loop (my $x = $re_min; $x <= $re_max; $x += $re_step) {
            my $iter = mandelbrot($x + $y * i);
            print @color_map[$iter % @color_map];
        }
        print "\n"
    }
}
EOF
cat > "$W/mandel.ref" <<'EOF'
. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @           . , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @
. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @          . , ; * $ # @. , ; * $ # @ . , ; * $ # @ . , ; * $ # @. , ; * $ # @  . , ; * $ # @. , ; * $ # @. , ; * $ # @
. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @         . , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @ . , ; * $ # @   . , ; * $ # @. , ; * $ # @. , ; * $ # @  . , ; * $ # @
. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @         . , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @ . , ; * $ # @ . , ; * $ # @    . , ; * $ # @. , ; * $ # @  
. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @         . , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @ . , ; * $ # @. , ; * $ # @  . , ; * $ # @ . , ; * $ # @  . , ; * $ # @ 
. , ; * $ # @. , ; * $ # @. , ; * $ # @        . , ; * $ # @. , ; * $ # @     . , ; * $ # @       . , ; * $ # @  . , ; * $ # @. , ; * $ # @
. , ; * $ # @. , ; * $ # @      . , ; * $ # @. , ; * $ # @    . , ; * $ # @. , ; * $ # @. , ; * $ # @           . , ; * $ # @. , ; * $ # @ 
. , ; * $ # @   . , ; * $ # @. , ; * $ # @. , ; * $ # @ . , ; * $ # @. , ; * $ # @ . , ; * $ # @. , ; * $ # @  . , ; * $ # @. , ; * $ # @            . , ; * $ # @ 
. , ; * $ # @ . , ; * $ # @. , ; * $ # @. , ; * $ # @      . , ; * $ # @  . , ; * $ # @                
. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @ . , ; * $ # @  . , ; * $ # @      . , ; * $ # @             . , ; * $ # @ 
                             . , ; * $ # @ 
. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @ . , ; * $ # @  . , ; * $ # @      . , ; * $ # @             . , ; * $ # @ 
. , ; * $ # @ . , ; * $ # @. , ; * $ # @. , ; * $ # @      . , ; * $ # @  . , ; * $ # @                
. , ; * $ # @   . , ; * $ # @. , ; * $ # @. , ; * $ # @ . , ; * $ # @. , ; * $ # @ . , ; * $ # @. , ; * $ # @  . , ; * $ # @. , ; * $ # @            . , ; * $ # @ 
. , ; * $ # @. , ; * $ # @      . , ; * $ # @. , ; * $ # @    . , ; * $ # @. , ; * $ # @. , ; * $ # @           . , ; * $ # @. , ; * $ # @ 
. , ; * $ # @. , ; * $ # @. , ; * $ # @        . , ; * $ # @. , ; * $ # @     . , ; * $ # @       . , ; * $ # @  . , ; * $ # @. , ; * $ # @
. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @         . , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @ . , ; * $ # @. , ; * $ # @  . , ; * $ # @ . , ; * $ # @  . , ; * $ # @ 
. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @         . , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @ . , ; * $ # @ . , ; * $ # @    . , ; * $ # @. , ; * $ # @  
. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @         . , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @ . , ; * $ # @   . , ; * $ # @. , ; * $ # @. , ; * $ # @  . , ; * $ # @
. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @          . , ; * $ # @. , ; * $ # @ . , ; * $ # @ . , ; * $ # @. , ; * $ # @  . , ; * $ # @. , ; * $ # @. , ; * $ # @
. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @           . , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @. , ; * $ # @
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(timeout -k 5 20 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(timeout -k 5 20 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-7s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s\n' "$w" "$m"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
for w in nested mandel; do for m in m3 m4; do ck "$w" "$m"; done; done
echo "arm 2: the nested witness under SCRIP_GC_STRESS at the shrunk window, both modes"
unset SCRIP_HEAP_MB; export SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-128}" SCRIP_HEAP_MAX_MB="${SCRIP_HEAP_MAX_MB:-512}"
sf=0
for w in nested; do for s in 1 3 5; do for m in m3 m4; do
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(SCRIP_GC_STRESS=$s timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; else out="$(SCRIP_GC_STRESS=$s timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; fi
    if [ "$out" != "$(cat "$W/$w.ref")" ]; then printf '  FAIL %s %s stress=%s: wrong answer under the collector\n' "$w" "$m" "$s"; fails=$((fails + 1)); sf=1; fi
done; done; done
[ "$sf" -eq 0 ] && echo "  ok   nested x stress 1 3 5 x m3 m4"
unset SCRIP_HEAP_KB SCRIP_HEAP_MAX_MB
echo "arm 3: a nested sub whose name is taken as a value is not captured and keeps its refusal (planted door)"
cat > "$W/door.raku" <<'EOF'
sub e { my $n = 3; my sub f() { return $n }; my $g = &f; return $g(); }
say e();
EOF
for m in m3 m4; do
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(timeout -k 5 20 "$ROOT/scrip" --run "$W/door.raku" 2>&1 </dev/null)"; rc=$?
    else out="$(timeout -k 5 20 "$ROOT/scrip" --compile -o "$W/door.s" "$W/door.raku" 2>&1 </dev/null)"; rc=$?; fi
    if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'never assigned'; then printf '  ok   door %s refused at the guard\n' "$m"
    else printf '  FAIL door %s: rc=%s [%s] -- a nested sub taken as a value must not take the stack road\n' "$m" "$rc" "$(printf '%s' "$out" | head -c 90 | tr '\n' ' ')"; fails=$((fails + 1)); fi
done
echo "arm 4: Roast S05-metasyntax/regex.t (a lexical regex in a sub in a class) is refused or compiled and never crashes the lowerer: the capture pass read a TT_REGEX_DECL node's sval as a parameter name and died at rc 139 (measured on SCRIP 137f4d712, the Roast compile census)"
RX="${ROAST_DIR:-/home/resources/roast-master}/S05-metasyntax/regex.t"
[ -f "$RX" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: $RX absent -- the crash witness cannot be measured"; exit 2; }
cp "$RX" "$W/rx.raku"
GATE_EXAMINED=$((GATE_EXAMINED + 1))
timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/rx.s" "$W/rx.raku" >/dev/null 2>&1 </dev/null; rc=$?
if [ "$rc" -ge 128 ]; then printf '  FAIL regex.t: the compiler died (rc=%s)\n' "$rc"; fails=$((fails + 1)); else printf '  ok   regex.t compile rc=%s (no crash)\n' "$rc"; fi
gate_verdict "$fails" "witness-mode pair(s) wrong: a nested sub does not read or write its enclosing sub's locals as Rakudo's does"
