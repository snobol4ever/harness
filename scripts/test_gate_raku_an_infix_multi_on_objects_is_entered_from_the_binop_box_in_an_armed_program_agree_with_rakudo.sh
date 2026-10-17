#!/usr/bin/env bash
# test_gate_raku_an_infix_multi_on_objects_is_entered_from_the_binop_box_in_an_armed_program_agree_with_rakudo.sh -- AN INFIX MULTI ON OBJECTS IS AN OPEN ROAD FROM THE BINOP BOX
# (row raku-an-infix-multi-on-objects-is-entered-from-the-binop-box-in-an-armed-program-not-from-c-ceo-1600; ARCH-RAKU-BOXES section 4 step 1, the last of the 21 sites; CEO-1576).
#
# THE DEFECT: `$p + $q` on objects with a user `multi sub infix:<+>(Vec, Vec)` (and the relops) reached the candidate from C: the arith box's C arithmetic (rt_add_big and kin) and the
# relop boxes called rt_binop_overload, which called __multi_call by name, which entered the user's sub -- the C road into a box CEO-1576 deleted (rc 139). RakRungs
# class_multi_sub_replace_2 4 5 6 7.
# THE CURE, the cto's design (re-ask-raku-infix-multi-open-road-in-the-binop-boxes): arithmetic.c rt_binop_overload_open selects the winning Rinfix_ candidate (by_name_dispatch.c
# rt_multi_winner, the one selection __multi_call also uses), loads CALL_ARGS and RETURNS ITS ADDRESS, or 0; the boxes enter it through bb_glue_binop_open (bb_glue_flat.cpp; the relop
# test box makes the result Bool-tested, as rt_relop_overload did) and fall through to their old road on 0. The arm is EMITTED ONLY IN AN ARMED PROGRAM: lower_raku.c sets
# g_stage2.rk_infix_armed when a registered proc is a Rinfix_ candidate of an operator rt_binop_overload serves, and the templates read it (RELOP_ARMED / ARITH_ARMED_FR /
# ARITH_ARMED_ZD, x86_asm.h), each appended to an existing template line so no other program's asm moves by a byte.
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), every non-open C-to-BB trace entry required to be 0, then under
# SCRIP_GC_STRESS 1 3 5 in both modes: + and * and == on a class, < as a value and as a condition, - on a subclass, the builtins on Int/Rat/Str in the same armed program (the open declines),
# and 200 additions in a loop so the collector runs between the open and the enter.
# FAILED ONCE, measured on SCRIP 530987afb before the cure: rc 139 at the first addition in both modes.
#
# EXIT: 0 every witness matches in both modes with 0 non-open entries; 1 a mismatch, a crash or an entry; 2 REFUSED (stale binary, no gcc).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_an_infix_multi_on_objects_is_entered_from_the_binop_box_in_an_armed_program_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/infixmulti.raku" <<'EOF'
class Vec { has $.x; has $.y; }
multi sub infix:<+>(Vec $a, Vec $b) { Vec.new(x => $a.x + $b.x, y => $a.y + $b.y) }
multi sub infix:<*>(Vec $a, $n) { Vec.new(x => $a.x * $n, y => $a.y * $n) }
multi sub infix:<==>(Vec $a, Vec $b) { $a.x == $b.x && $a.y == $b.y }
class Box { has $.n; }
multi sub infix:«<»(Box $a, Box $b) { $a.n < $b.n }
class Animal { has $.size; }
class Dog is Animal { }
multi sub infix:<->(Animal $a, Animal $b) { $a.size - $b.size }
my $p = Vec.new(x => 1, y => 2);
my $q = Vec.new(x => 10, y => 20);
my $r = $p + $q;
say $r.x, " ", $r.y;
my $s = $p * 3;
say $s.x, " ", $s.y;
say $p == $q;
say $p == Vec.new(x => 1, y => 2);
say Box.new(n => 3) < Box.new(n => 7);
say Box.new(n => 9) < Box.new(n => 7);
if Box.new(n => 1) < Box.new(n => 2) { say "less" } else { say "not less" }
say Dog.new(size => 30) - Dog.new(size => 12);
say 2 + 3, " ", 7 - 2, " ", 2 * 4, " ", 1/3 + 1/6, " ", 3 < 4, " ", "a" ~ "b";
my $acc = Vec.new(x => 0, y => 0);
for 1..200 -> $i { $acc = $acc + Vec.new(x => $i, y => 1) }
say $acc.x, " ", $acc.y;
EOF
cat > "$W/infixmulti.ref" <<'EOF'
11 22
3 6
False
True
True
False
less
18
5 5 8 0.5 True ab
20100 200
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
ST=""; for w in infixmulti; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in infixmulti; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: an infix multi on objects that disagrees with Rakudo, a crash, or a non-open C-to-BB entry"
