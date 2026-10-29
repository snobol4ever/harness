#!/usr/bin/env bash
# test_gate_raku_whatevercode_curries_as_rakudo_does.sh -- THE BARE TERM `*` AS AN OPERAND BECOMES A CODE VALUE, EAGERLY AT EACH OPERATOR, PARAMETERS MERGING
# (row raku-every-suite-to-100-under-nonet-ceo-1266, M1; Lon 2026-09-25: "use IPC sync-step monitor to crawl the test suites to 100%"; ceo CEO-1479).
#
# THE DEFECT, measured over Roast with scrip --compile and nothing executed: 92 files die at the driver guard graph_native_emittable_mode ("variable '*' is read
# but never assigned") because the lowerer saw the term `*` as an unresolved variable. THE CURE is Rakudo's own rule, applied where the parser builds the tree
# (rk_tree.c rkb_binop / rkb_prefix_apply / rkb_postfix): an operator with a Whatever or an already-curried WhateverCode operand yields a WhateverCode (a
# TT_ANON_BLOCK whose parameters are __wcN) whose arity is the SUM of its operands' -- (* * 2 + 1) is one parameter, (* + *) two, ((* + 1) * (* + 2)) two -- and
# a method call or an element subscript on one extends it (*.uc.lc, *[1]). Measured on /usr/bin/raku: every infix curries except the range operators, =>, ,, ...,
# ||, &&, //, ^^, xx and ?? !!; a prefix curries for - + ? ! ~. A subscript index (@a[*-1]) is NOT curried: its own path substitutes the element count.
# NOT HERE, each its own row: .WHAT of a code value (Block / Sub / WhateverCode all read Str), the lazy infinite range 1..* (even 1..Inf is empty), a Whatever
# stored as a VALUE (a => *), @a[*-2..*-1], .max with a mapper, the R meta-operator, and a WhateverCode that captures a sub's local (M3, closure capture).
# FAILED ONCE, measured on SCRIP 745a917ea: every witness is refused by the guard in both modes.
#
# THE WITNESSES, each graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo: ops (operators, merging, method and index postfix, prefix,
# a stored WhateverCode called later), lists (map grep sort first reduce max-free list operations, chains of them), subscript (the element-count forms).
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_whatevercode_curries_as_rakudo_does.sh   (~3s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_whatevercode_curries_as_rakudo_does"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/ops.raku" <<'EOF'
say ((* * 2 + 1)(3));
say ((* + *)(3, 4));
say (((* + 1) * (* + 2))(3, 4));
say (((* + 1) + (* + 2))(3, 4));
say (((* + 1) * 2)(5));
say (*.uc)("a");
say (*.uc.lc)("A");
say (*[1])((5,6,7));
say (-*)(3);
say (!*)(0);
say (* ~ "x")("a");
say (* > 2)(3);
my $f = * + 1;
say $f(4);
say $f(10);
EOF
cat > "$W/ops.ref" <<'EOF'
7
7
24
10
12
A
a
6
-3
True
ax
True
5
11
EOF
cat > "$W/lists.raku" <<'EOF'
say (1,2,3).map(* * 2);
say (1,2,3,4).grep(* > 2);
say (3,1,2).sort(-*);
say (1,2,3).first(* > 1);
my @a = 1,2,3,4;
say @a.map(* + 10);
say @a.grep(* %% 2).map(* ** 2);
say @a.sort(-*).map(*.Str);
say @a.reduce(* + *);
say (<b a c>).sort(*.ord);
say @a[*-1] + 1;
say @a.map({ $_ * 2 }).map(* - 1);
my $inc = * + 1; my $dbl = * * 2;
say $inc($dbl(5));
say (1,2,3).map(-> $x { $x + 1 });
say <a b c>.map(* ~ "!");
say (* ** 2)(4);
say (2 ** *)(5);
say (* > 1 ?? "a" !! "b")(1) if False;
EOF
cat > "$W/lists.ref" <<'EOF'
(2 4 6)
(3 4)
(3 2 1)
2
(11 12 13 14)
(4 16)
(4 3 2 1)
10
(a b c)
5
(1 3 5 7)
11
(2 3 4)
(a! b! c!)
16
32
EOF
cat > "$W/subscript.raku" <<'EOF'
my @a = 1,2,3;
say @a[*-1];
EOF
cat > "$W/subscript.ref" <<'EOF'
3
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(timeout -k 5 20 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile --out="$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(timeout -k 5 20 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-7s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s\n' "$w" "$m"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
for w in ops lists subscript; do for m in m3 m4; do ck "$w" "$m"; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a Whatever operand the parser does not curry as Rakudo does"
