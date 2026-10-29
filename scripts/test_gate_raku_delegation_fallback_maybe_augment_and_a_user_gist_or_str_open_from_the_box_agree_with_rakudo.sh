#!/usr/bin/env bash
# test_gate_raku_delegation_fallback_maybe_augment_and_a_user_gist_or_str_open_from_the_box_agree_with_rakudo.sh -- THE METHOD ROADS C USED TO WALK ARE OPEN ROADS
# (row raku-no-c-site-calls-user-code-the-21-rt-call-proc-descr-roads-become-open-roads-or-emitted-loops-ceo-1600, ARCH-RAKU-BOXES section 4 step 1; CEO-1576).
#
# THE DEFECT: five method roads reached user code from C and so died on CEO-1576's named bomb (rt_call_proc_descr: <Class>__<method> reached a C road into a box, DELETED; rc 139):
# a `handles` delegation (meth_call's C arm re-dispatched to the delegate and invoked its method), FALLBACK, `.?method`, a method added to a built-in type by `augment`, and
# a user gist / Str reached from say, put, print, ~ and interpolation (rk_obj_stringify invoked it). RakRungs class_method_say_replace_21 22 23 24 25 26 53 54.
# THE CURE: rk_method_open (by_name_dispatch.c rk_method_open_d / rk_method_open_at, the CEO-1552 open road the meth_call box already takes) resolves all of them and RETURNS
# THE ADDRESS: a user method, `.?` (the name without its `?`), a delegation chain (the delegate replaces self in the grant's argv), FALLBACK when no method and no Mu method
# answers (argv kept whole: self, the name, the arguments), and an augmented built-in type (the value's type, then Cool, Any, Mu; never a name Rakudo's core defines).
# A user gist or Str is opened through the request channel: __rk_str (the ~ and interpolation coercion), and __rk_gist_pre / __rk_str_pre, which the lowerer wraps around
# say's and put/print's arguments only in a program that declares such a method. The SCRIP_C2BB_TRACE marks of shape `<road>.open` are the box entering (CEO-1576) and are
# not counted.
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), every non-open C-to-BB trace entry required to be 0, then under
# SCRIP_GC_STRESS 1 3 5 in both modes, with 200 iterations of a delegation and a Str coercion so the collector runs on the open roads.
# FAILED ONCE, measured on SCRIP c5b26a2a8 before the cure: rc 139 at the first delegated call in both modes.
#
# EXIT: 0 every witness matches in both modes with 0 non-open entries; 1 a mismatch, a crash or an entry; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_delegation_fallback_maybe_augment_and_a_user_gist_or_str_open_from_the_box_agree_with_rakudo.sh   (~10s, no oracle at run time)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_delegation_fallback_maybe_augment_and_a_user_gist_or_str_open_from_the_box_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/methroads.raku" <<'EOF'
use MONKEY-TYPING;
class Engine { method start() { "vroom" }; method stop() { "halt" } }
class Car { has $.engine handles <start stop>; has $.name; }
my $c = Car.new(engine => Engine.new, name => "tesla");
say $c.start; say $c.stop; say $c.name;
class Fleet { has $.lead handles <start>; }
say Fleet.new(lead => $c).start;
class Dyn { method FALLBACK($name) { "fb:" ~ $name } }
say Dyn.new.hello;
class Dyn1 { method FALLBACK($name, $x) { "fb1:" ~ $name ~ ":" ~ $x } }
say Dyn1.new.twice(21);
class Mb { method hi() { "hi" } }
say Mb.new.?hi;
say Mb.new.?nope // "nope-nil";
augment class Int { method double() { self * 2 } }
say 21.double;
augment class Str { method shout() { self.uc ~ "!" } }
say "hey".shout;
class Animal { has $.name; method gist() { "DOG:" ~ $.name } }
class Dog is Animal { }
say Dog.new(name => "Rex");
my @pets = Dog.new(name => "A"), Dog.new(name => "B");
for @pets -> $p { say $p }
class Point { has $.x; has $.y; method Str() { "(" ~ $.x ~ "," ~ $.y ~ ")" } }
my $pt = Point.new(x => 3, y => 4);
say "at " ~ $pt;
say "pt=$pt";
say $pt ~ "!";
put $pt;
my $n = 0;
for 1..200 -> $i { $n += ("" ~ Point.new(x => $i, y => $i)).chars; $n += Car.new(engine => Engine.new, name => "x").start.chars }
say $n;
EOF
cat > "$W/methroads.ref" <<'EOF'
vroom
halt
tesla
vroom
fb:hello
fb1:twice:21
hi
nope-nil
42
HEY!
DOG:Rex
DOG:A
DOG:B
at (3,4)
pt=(3,4)
(3,4)!
(3,4)
2584
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
ST=""; for w in methroads; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in methroads; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a delegated, FALLBACK, .?, augmented or stringified method call that disagrees with Rakudo, a crash, or a non-open C-to-BB entry"
