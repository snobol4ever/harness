#!/usr/bin/env bash
# test_gate_raku_a_sub_or_method_that_writes_a_file_scope_variable_changes_the_variable_agree_with_rakudo.sh -- A NAMED SUB OR A METHOD THAT ASSIGNS, INCREMENTS, APPENDS TO OR PUSHES ONTO A FILE-SCOPE `my` VARIABLE CHANGES THAT VARIABLE (the outer-lexical gap), A DESTRUCTURING ASSIGNMENT AS A SUB'S LAST STATEMENT, AND AN ASSIGNMENT WHOSE RIGHT SIDE IS A TOP-LEVEL **
# (row raku-every-suite-to-100-under-nonet-ceo-1266; named in the headers of the loose-operator and hyper-operator gates as "a sub that captures a file-scope my @log and pushes to it"; the counter / flag / log idiom of the Roast files: `my $count = 0; sub inc { $count++ }`).
#
# THE DEFECT, measured against Rakudo: a named sub (or a method) that WROTE a variable declared at file scope never changed it. `my $count = 0; sub inc { $count++ }; inc(); inc(); say $count` printed 0 (Rakudo 2); `my @log; sub note($v) { @log.push($v) }` left @log empty;
# `my %seen; sub mark($k) { %seen{$k} = True }` left %seen empty; `$s ~= $t`, `$acc += $n`, `$depth++` in a recursive sub, a flag set by a sub, a counter bumped by a method, `.map: { $n += $_ }` inside a sub: every one printed the value from before the call. Reading worked (rk_file_scope_reads_are_globals), writing did not: in the SNOBOL4-style
# procedure model the names a procedure ASSIGNS are its locals, saved and restored around the call, so the write died with the call; the existing pass made a file-scope name a global only when NO sub writes it (the `!writer` test), which is exactly the case that matters. A second defect on the same path: `($p, $q) = ($q, $p)` as a sub's
# LAST statement dropped the assignment altogether (stmt_tail kept only the left parenthesis); and an ASSIGNMENT WHOSE RIGHT SIDE IS A TOP-LEVEL ** (`my $y = $x ** 3`, `$sq = $sq ** 2`, `$x **= 2`) was refused by the native emitter ("assignment to 'y' has an rhs shape with no native arm": the driver's rhs list has no power arm) unless the target happened to be a global, though `say $x ** 3` and `1 + $x ** 3` compiled.
# THE CURE: (lower_raku.c rk_globalize_file_scope_writes, after rk_cap_file_scope) every file-scope declared variable that some sub or method mutates without declaring a variable of that name itself (rk_gw_collect: rk_cap_mutated on the body, rk_cap_declared_deep on the routine) is RENAMED to NAME__fs through the whole
# program EXCEPT inside a routine or block that declares its own variable of that name (rk_gw_rename), and registered global (global_register), so the sub and the main program share one cell and a sub's own `my $x` stays a separate local; loop variables and names already boxed by the escaping-closure road are left alone; (rk_tree.c stmt_tail) a
# parenthesised-list assignment at a sub's tail is built by stmt_plain, as it is anywhere else; (lower_raku.c rk_assign_pow_rhs, a tree pass) a top-level ** on an assignment's right side is wrapped in the identity builtin __rk_item1, the way rk_scalar_rhs already turns a repetition `x` into a call, so the emitter takes the same BINOP it takes inside any larger expression (the driver's shared rhs list is NOT touched).
# NOT HERE (own rows, measured): `(@a) = (1, 2, 3)` keeps one element; a file-scope variable that is BOTH captured and mutated by an escaping closure AND written by a named sub; a state variable; the eval-string reads.
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP 3436d81e1 before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_a_sub_or_method_that_writes_a_file_scope_variable_changes_the_variable_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_sub_or_method_that_writes_a_file_scope_variable_changes_the_variable_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
my $count = 0;
sub inc { $count++ }
inc(); inc();
say $count;
my $acc = 0;
sub add($n) { $acc += $n }
add(5); add(7);
say $acc;
my @log;
sub note($v) { @log.push($v) }
note(1); note(2);
say @log.elems;
say @log;
my @stack;
sub pu($v) { push @stack, $v }
sub po { @stack.pop }
pu(1); pu(2); pu(3);
say po();
say @stack;
my %seen;
sub mark($k) { %seen{$k} = True }
mark("a"); mark("b");
say %seen.keys.sort;
my $s = "";
sub app($t) { $s ~= $t }
app("a"); app("b");
say $s;
say "s=$s";
my $x = 1;
sub setx { $x = 5; $x }
say setx();
say $x;
my $y = 1;
sub sety { $y = 2 }
sub ylocal { my $y = 10; $y++; $y }
sety();
say ylocal();
say $y;
my $z = 1;
sub zparam($z) { $z + 1 }
sub zset { $z = 9 }
zset();
say zparam(3);
say $z;
my $depth = 0;
sub rec($n) { $depth++; rec($n - 1) if $n > 0 }
rec(3);
say $depth;
my $n = 0;
sub g { (1, 2, 3).map: { $n += $_ } }
g();
say $n;
my $c = 0;
sub tick { $c++ }
my $f = { tick(); tick() };
$f();
say $c;
for 1 .. 3 { tick() }
say $c;
my @r = (1 .. 3).map: { tick(); $_ * 2 };
say @r;
say $c;
my $flag = False;
sub setflag { $flag = True }
say $flag;
setflag();
say $flag;
my ($p, $q) = (1, 2);
sub swap { ($p, $q) = ($q, $p) }
swap();
say "$p $q";
my ($m, $k);
sub fill { ($m, $k) = (7, 8) }
fill();
say "$m $k";
my $total = 0;
class C {
    method bump { $total += 1 }
    method get { $total }
}
my $o = C.new;
$o.bump; $o.bump;
say $o.get;
say $total;
my $keep = 3;
sub readonly { $keep * 2 }
say readonly();
my $base = 2;
my $pw = $base ** 3;
say $pw;
$base **= 2;
say $base;
my $big = 2 ** 70;
say $big;
my $sq = 3;
$sq = $sq ** 2;
say $sq;
sub cube($v) { my $r = $v ** 3; $r }
say cube(4);
EOF
cat > "$W/w.ref" <<'EOF'
2
12
2
[1 2]
3
[1 2]
(a b)
ab
s=ab
5
5
11
2
4
9
4
6
2
5
[2 4 6]
8
False
True
2 1
7 8
2
2
6
8
4
1180591620717411303424
9
64
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile --out="$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-7s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
        if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in w; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in w; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: an outer-variable-write or power-assignment result that disagrees with Rakudo"
