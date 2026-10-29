#!/usr/bin/env bash
# test_gate_raku_a_tail_call_through_a_builtin_is_entered_by_the_box.sh
#
# THE ROW: gc-rt-c-c-to-bb-entries-leave-no-emitted-code-is-entered-from-c-in-rt-c-except-the-original-invocation (cfo), the
# tail protocol of CEO-1533/1536 option 2 rolled out to Raku. A Raku call that the lowerer routes through a by-name builtin
# (__blk_invoke for a code variable or a pointy block, __multi_call for a multi sub, obj_new for a user `new`,
# __rk_named_call for named arguments, meth_call for a multi method) ended in rt_call_proc_descr entering the procedure
# from C through the rt.c trampoline rt_proc_enter (trace site descr.enter.lex). Now the box calls rt_call_arr_bl_try
# with its own result cell; the same resolution runs and, at the tail, rt_call_open_tail_lex opens the procedure and
# returns {entry, how} instead of entering; the box enters through bb_glue_enter_c2bb and lands on rt_call_land_γ/ω.
#
# ARM 1 (the semantics): three programs x two modes print the Rakudo answers, written out below, a die inside each kind
# of callee reaching the enclosing try among them.
# ARM 2 (who enters): under SCRIP_C2BB_TRACE each program reads lex.open (the box entered) and no descr.enter.lex (C
# entered), both modes. A build without the trace (RT_DIAG off) writes no line at all: that is a REFUSAL, never a pass.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/p.raku" <<'RAKU'
sub dbl($x) { $x * 2 }
my &c = &dbl;
say c(21);
my $k = 10;
my &e = -> $x { $x + $k };
say e(5);
my $f = { $_ * 3 };
say $f(7);
say (-> $a, $b { $a ~ $b })("p", "q");
my &fact = sub ($n) { $n <= 1 ?? 1 !! $n * fact($n - 1) };
say fact(10);
RAKU
printf '42\n15\n21\npq\n3628800\n' > "$D/p.want"
cat > "$D/q.raku" <<'RAKU'
multi sub g(Int $x) { "int $x" }
multi sub g(Str $x) { "str $x" }
say g(3);
say g("a");
class A {
  multi method m(Int $x) { "A int $x" }
  multi method m(Str $x) { "A str $x" }
}
say A.new.m(4);
say A.new.m("z");
class Pt {
  has $.x; has $.y;
  method new($x, $y) { self.bless(x => $x, y => $y) }
  method add($o) { Pt.new($.x + $o.x, $.y + $o.y) }
}
my $p = Pt.new(0, 0);
for 1..200 { $p = $p.add(Pt.new(1, 2)) }
say $p.x, " ", $p.y;
sub named(:$a, :$b = 3) { $a + $b }
say named(a => 4);
RAKU
printf 'int 3\nstr a\nA int 4\nA str z\n200 400\n7\n' > "$D/q.want"
cat > "$D/r.raku" <<'RAKU'
my &c = sub ($x) { die "boom $x" if $x > 1; $x };
say c(1);
try { say c(5); CATCH { default { say "caught: " ~ .message } } }
class P { has $.x; method new($x) { die "neg" if $x < 0; self.bless(x => $x) } }
say P.new(3).x;
try { P.new(-1); CATCH { default { say "caught: " ~ .message } } }
multi sub h(Int $x) { die "int $x" if $x == 0; "int $x" }
multi sub h(Str $x) { "str $x" }
try { h(0); CATCH { default { say "caught: " ~ .message } } }
sub nm(:$n) { die "named $n" if $n > 5; $n * 2 }
try { nm(n => 9); CATCH { default { say "caught: " ~ .message } } }
say "end";
RAKU
printf '1\ncaught: boom 5\n3\ncaught: neg\ncaught: int 0\ncaught: named 9\nend\n' > "$D/r.want"
red=0; n=0
for p in p q r; do
    ( cd "$D" && SCRIP_C2BB_TRACE="$D/$p.t3" timeout -k 5 30 "$B/scrip" "$p.raku" < /dev/null > "$p.m3" 2>/dev/null )
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out="$p.s" "$p.raku" < /dev/null > /dev/null 2>&1 && gcc -no-pie "$p.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$p.bin" 2>/dev/null ) || refuse "$p.raku: mode 4 did not build"
    ( cd "$D" && SCRIP_C2BB_TRACE="$D/$p.t4" timeout -k 5 30 "./$p.bin" < /dev/null > "$p.m4" 2>/dev/null )
    for m in m3 m4; do
        n=$((n + 1))
        if cmp -s "$D/$p.want" "$D/$p.$m"; then echo "  ok   $p.raku $m prints the Rakudo answer"; else echo "  FAIL $p.raku $m: got [$(tr '\n' '|' < "$D/$p.$m")] want [$(tr '\n' '|' < "$D/$p.want")]"; red=$((red + 1)); fi
        t="$D/$p.t${m#m}"; [ -s "$t" ] || refuse "$p.raku $m wrote no SCRIP_C2BB_TRACE line -- the build has no trace (RT_DIAG off) or the road vanished; arm 2 measured nothing"
        o=$(grep -c '^lex\.open' "$t"); c=$(grep -c '^descr\.enter\.lex' "$t")
        n=$((n + 1))
        if [ "$o" -gt 0 ] && [ "$c" -eq 0 ]; then echo "  ok   $p.raku $m: the box entered $o time(s), C entered none"; else echo "  FAIL $p.raku $m: lex.open=$o descr.enter.lex=$c (C still enters emitted code)"; red=$((red + 1)); fi
    done
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): a Raku tail call through a by-name builtin is entered by the box, $n arm(s)"; exit 0; fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
