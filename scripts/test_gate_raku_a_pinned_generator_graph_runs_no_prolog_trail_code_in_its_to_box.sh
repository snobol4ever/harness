#!/usr/bin/env bash
# test_gate_raku_a_pinned_generator_graph_runs_no_prolog_trail_code_in_its_to_box.sh -- a TO box (a range generator) marks and unwinds
# the Prolog trail held in r12 only when the LOWERING says its values are bound through the trail (the payload tag :trl, set on every
# IR_TO the Prolog lowerer builds), never merely because its graph has a pinned frame base. THE RED (hq_raku 2026-10-10 on origin
# 0ab423aaa, the cto's dbd4b7cf1 road; bracketed by the cto under gdb): my @list = gather { take $_ for 1..10 }; say @list.first(
# { $_ > 3 }); prints 4 in mode 3 and dies in mode 4 with [ZGC-STALE] SIGSEGV at the TO box's beta, mov [rax], r12 after
# and rax, -134217728 -- x86_pl_tr_top_sync writing r12 into the header of a 128 MB-aligned TRAIL ARENA, where in a Raku program r12
# is the conditional-assignment island (the main prologue seeded it from 0x70000000, r12 = 0x7ffff15ff040 in a no-PIE build). THE
# CAUSE: xa_to_trail_mark / xa_to_trail_unwind keyed the trail on x86_fb_pinned(), a proxy that held while only Prolog graphs were
# pinned; since dbd4b7cf1 a Raku generator graph is pinned too, so its TO box ran the Prolog trail mark (which also moves r13, the
# youngest-choice register, and stores r12 past the TO's 16-byte record) and the trail unwind. Elems and a subscript were right
# because they carry no TO box. Row: the m4 red of hq_raku's test_gate_raku_first_takes_the_end_..._agree_with_rakudo.sh.
# ARMS: (1) the Raku witness's emitted .s carries no pl_tr_unwind at a TO beta and no trail-arena mask (and ..., -134217728), and
# mode 4 prints 4 (mode 3 agrees);
# (2) a gather with no for, walked by first, prints 2 in mode 4; (3) map over a gather-filled array prints 10 in mode 4; (4) THE
# PROLOG CONTROL: a nondeterministic clause enumerating between/3 under a binding that must be undone on retry still carries the
# pl_tr_unwind note at its TO beta in its .s and answers as swipl in both modes. FAIL_ONCE=1 expects the mask in the Raku .s, so arm 1 reds.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; G=raku_a_pinned_generator_graph_runs_no_prolog_trail_code_in_its_to_box
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
command -v swipl >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: swipl absent (the Prolog control's oracle)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/rkto.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
printf 'my @list = gather { take $_ for 1..10 };\nsay @list.first({ $_ > 3 });\n' > "$W/w.raku"
printf 'my @list = gather { take 1; take 2; take 5 };\nsay @list.first({ $_ > 1 });\n' > "$W/g.raku"
printf 'my @list = gather { take $_ for 1..10 };\nsay @list.map({ $_ * 2 }).elems;\n' > "$W/m.raku"
printf ':- initialization(main).\np(X, Y) :- between(1, 4, X), Y = f(X), X >= 3.\nq(L) :- findall(X-Y, p(X, Y), L).\nmain :- q(L), write(L), nl, ( p(A, B), A > 3 -> write(A-B) ; write(none) ), nl, halt.\n' > "$W/c.pl"
build() { ( cd "$W" && "$ROOT/scrip" --compile -o "$W/$1.s" "$W/$1.$2" < /dev/null > "$W/$1.cerr" 2>&1 ) || { echo "GATE REFUSED(2) [$G]: $1.$2 does not compile ($(head -c 120 "$W/$1.cerr"))"; exit 2; }
          gcc -no-pie -o "$W/$1.bin" "$W/$1.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/$1.lerr" 2>&1 || { echo "GATE REFUSED(2) [$G]: $1 does not link"; exit 2; }
          ( cd "$W" && timeout -k 5 60 "$W/$1.bin" < /dev/null > "$W/$1.m4" 2>&1 ); echo $? > "$W/$1.rc"; }
build w raku; build g raku; build m raku; build c pl
TOU='_to_β:.*pl_tr_unwind'
bad=0
wm=$(grep -c -- "$TOU" "$W/w.s"); wk=$(grep -c -- '-134217728' "$W/w.s"); cm=$(grep -c -- "$TOU" "$W/c.s")
want_none=1; [ "${FAIL_ONCE:-0}" = 1 ] && want_none=0
if { [ "$want_none" = 1 ] && [ "$wm" = 0 ] && [ "$wk" = 0 ]; } || { [ "$want_none" = 0 ] && [ "$wm" -gt 0 ]; }; then echo "  ok  (1) the Raku witness's .s carries $wm TO-beta trail unwind(s) and $wk trail-arena mask(s)"; else echo "  RED (1) the Raku witness's .s carries $wm TO-beta trail unwind(s) ($wk trail-arena masks) -- a TO box in a pinned Raku graph runs the Prolog trail"; bad=1; fi
o=$(head -1 "$W/w.m4" | cut -c1-80); [ "$o" = 4 ] && [ "$(cat "$W/w.rc")" = 0 ] && echo "  ok  (1) mode 4 prints 4" || { echo "  RED (1) mode 4: rc=$(cat "$W/w.rc") '$o' (wanted 4)"; bad=1; }
o3=$(cd "$W" && timeout -k 5 60 "$ROOT/scrip" "$W/w.raku" < /dev/null 2>&1 | head -1); [ "$o3" = 4 ] && echo "  ok  (1) mode 3 prints 4" || { echo "  RED (1) mode 3 prints '$o3'"; bad=1; }
o=$(head -1 "$W/g.m4" | cut -c1-80); [ "$o" = 2 ] && [ "$(cat "$W/g.rc")" = 0 ] && echo "  ok  (2) a gather with no for, walked by first, prints 2 in mode 4" || { echo "  RED (2) mode 4: rc=$(cat "$W/g.rc") '$o' (wanted 2)"; bad=1; }
o=$(head -1 "$W/m.m4" | cut -c1-80); [ "$o" = 10 ] && [ "$(cat "$W/m.rc")" = 0 ] && echo "  ok  (3) map over a gather-filled array prints 10 in mode 4" || { echo "  RED (3) mode 4: rc=$(cat "$W/m.rc") '$o' (wanted 10)"; bad=1; }
( cd "$W" && timeout -k 5 60 swipl -q "$W/c.pl" < /dev/null > "$W/c.ref" 2>/dev/null )
( cd "$W" && timeout -k 5 60 "$ROOT/scrip" "$W/c.pl" < /dev/null > "$W/c.m3" 2>/dev/null )
if [ "$cm" -gt 0 ] && [ -s "$W/c.ref" ] && cmp -s "$W/c.ref" "$W/c.m3" && cmp -s "$W/c.ref" "$W/c.m4"; then echo "  ok  (4) the Prolog control keeps its TO-beta trail unwind ($cm) and answers as swipl in both modes: $(tr '\n' ' ' < "$W/c.ref")"
else echo "  RED (4) the Prolog control: masks=$cm swipl='$(tr '\n' ' ' < "$W/c.ref")' m3='$(tr '\n' ' ' < "$W/c.m3")' m4='$(head -2 "$W/c.m4" | tr '\n' ' ')'"; bad=1; fi
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a TO box runs the Prolog trail only where the lowering tags it :trl; a pinned Raku generator graph iterates in mode 4 (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a TO box in a pinned non-Prolog graph runs the Prolog trail, or the Prolog control lost its trail (tree SCRIP=$TREE)"; exit 1
