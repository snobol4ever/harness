#!/usr/bin/env bash
# test_gate_raku_a_method_holding_a_gather_receives_self_and_its_arguments.sh -- a Raku method whose body holds a gather (or any
# generator call) receives self and its arguments when it is entered by method dispatch, in both modes, as Rakudo does. THE RED
# (hq_raku 2026-10-10 on origin 302521554, the cto's dbd4b7cf1 road; bracketed by the cto under gdb): class K { has @!g; method fill
# { @!g = [1,2],[3,4]; self }; method Str { join '|', gather for ^2 -> $i { take @!g[$i].join(',') } } }; say K.new.fill.Str; prints
# 1,2|3,4 under rakudo-local 2026.05 and stops in SCRIP with error 107 (record expected, &null) -- the method's own first read of
# self, backtrace icn_field_get("x") from emitted code. THE CAUSE: a method holding a generator call resumes it, so its graph is
# pinned, and zls_g_block_args makes every pinned graph read its arguments from a caller-pushed block at [fb+kt+16i]; the method road
# (rk_method_open / rk_redispatch_open -> rt_call_open_by_name -> bb_glue_enter_c2bb's default arm) stages them in CALL_ARGS and pushes
# the two wire cells where the block belongs, so self and every parameter read the wire cells (error 107, a wrong value, or SIGSEGV).
# A method holding a gather that reads no parameter, and a method with no gather, were right -- they are the controls.
# ARMS, each in mode 3 and mode 4 against rakudo-local's line: (1) hq_raku's K; (2) an attribute read inside the gather body;
# (3) a plain local taken inside the gather; (4) a method argument taken inside the gather; (5) self read after the gather;
# (6) three takes through $!x, $.x and self.x; (7) .elems over a gather with a postfix if; controls (8) a gather method reading
# no parameter and (9) a method with no gather. FAIL_ONCE=1 grades arm 1 against a wrong line, so it reds.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=raku_a_method_holding_a_gather_receives_self_and_its_arguments
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/rkmeth.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
n=0
arm() { n=$((n+1)); printf '%s\n' "$2" > "$W/a$n.raku"; printf '%s\n' "$1" > "$W/a$n.ref"; }
arm '1,2|3,4' "class K { has @!g; method fill { @!g = [1,2],[3,4]; self }; method Str { join '|', gather for ^2 -> \$i { take @!g[\$i].join(',') } } }; say K.new.fill.Str;"
arm '5' 'class P { has $.x; method m { my @r = gather { take $!x }; @r.join(" ") } }; say P.new(x => 5).m;'
arm '5' 'class P { has $.x; method m { my $y = $!x; my @r = gather { take $y }; @r.join(" ") } }; say P.new(x => 5).m;'
arm '7 8' 'class P { method m($a) { my @r = gather { take $a; take $a + 1 }; @r.join(" ") } }; say P.new.m(7);'
arm '9' 'class P { has $.x; method m { my $s = self; my @r = gather { take 1 }; $s.x } }; say P.new(x => 9).m;'
arm '5 10 6' 'class P { has $.x; method tw { my @r = gather { take $!x; take $.x * 2; take self.x + 1 }; @r.join(" ") } }; say P.new(x => 5).tw;'
arm '2' 'class Q { has @.v; method pos { (gather for @!v { take $_ if $_ > 0 }).elems } }; say Q.new(v => [1, -2, 3]).pos;'
arm '1 2' 'class P { method m { my @r = gather { take 1; take 2 }; @r.join(" ") } }; say P.new.m;'
arm '10' 'class P { has $.x; method m { my $v = $!x; $v + 1 } }; say P.new(x => 9).m;'
[ "${FAIL_ONCE:-0}" = 1 ] && echo 'not this' > "$W/a1.ref"
bad=0
for i in $(seq 1 $n); do
    o3=$(cd "$W" && timeout -k 5 60 "$ROOT/scrip" "$W/a$i.raku" < /dev/null 2>&1 | head -1)
    if ( cd "$W" && "$ROOT/scrip" --compile --out="$W/a$i.s" "$W/a$i.raku" < /dev/null > "$W/a$i.cerr" 2>&1 ) \
       && gcc -no-pie -o "$W/a$i.bin" "$W/a$i.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/a$i.lerr" 2>&1; then
        o4=$(cd "$W" && timeout -k 5 60 "$W/a$i.bin" < /dev/null 2>&1 | head -1)
    else o4="(no build: $(head -c 80 "$W/a$i.cerr"))"; fi
    want=$(cat "$W/a$i.ref")
    if [ "$o3" = "$want" ] && [ "$o4" = "$want" ]; then echo "  ok  ($i) m3 and m4: $want"
    else echo "  RED ($i) want '$want', m3 '$(printf '%s' "$o3" | cut -c1-70)', m4 '$(printf '%s' "$o4" | cut -c1-70)'"; bad=1; fi
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a method holding a gather receives self and its arguments by method dispatch, $n shapes in both modes as Rakudo prints them (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a method holding a gather reads its self or its arguments wrong (tree SCRIP=$TREE)"; exit 1
