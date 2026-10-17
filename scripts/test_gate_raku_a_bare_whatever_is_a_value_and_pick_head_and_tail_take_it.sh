#!/usr/bin/env bash
# test_gate_raku_a_bare_whatever_is_a_value_and_pick_head_and_tail_take_it.sh -- THE TERM * THAT IS NOT AN OPERAND IS THE TYPE OBJECT Whatever
# (row raku-whatever-as-a-value-and-an-open-range-end, raku-every-suite-to-100-under-nonet-ceo-1266). After the WhateverCode landing the remaining first-refusals of the Roast
# compile census on the star were 46 files: a * that no operator curries (pick(*), head(*), a => *, a bare my $w = *) reached the driver guard as an unresolved variable.
# lower_raku.c now lowers a leftover * to the Whatever type object (__rk_typeobj), so .WHAT is (Whatever); and pick (new: a random sample without replacement, one element with no
# argument, the whole list shuffled for *), head and tail (the count * means all) accept it.
# NOT HERE: 1..* and the ... sequence operator with a * endpoint (lazy ranges and sequences, their own rows), $p ~~ 7|8|9 (smartmatch against a junction).
# FAILED ONCE, measured on SCRIP 888aca37f: the witness is refused at the guard (variable * is read but never assigned) in both modes.
# EXIT: 0 the witness matches Rakudo in both modes; 1 a mismatch or a crash; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_a_bare_whatever_is_a_value_and_pick_head_and_tail_take_it.sh   (~2s)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_bare_whatever_is_a_value_and_pick_head_and_tail_take_it"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/whatval.raku" <<'EOF'
my $w = *;
say $w.WHAT;
say (a => *).value.WHAT;
say (1, 2, 3, 4).pick(*).elems;
say (1, 2, 3, 4).pick(*).sort;
say (1, 2, 3).pick(2).elems;
say (1, 2, 3).pick(0).elems;
say (1 .. 3).pick(9).elems;
say (1, 2, 3, 4).head(*).elems;
say (1, 2, 3).tail(*);
say (1, 2, 3, 4).head(2);
say (1, 2, 3, 4).tail(2);
my @a = 1, 2, 3;
say @a[*];
say @a[*-1];
EOF
cat > "$W/whatval.ref" <<'EOF'
(Whatever)
(Whatever)
4
(1 2 3 4)
2
0
3
4
(1 2 3)
(1 2)
(3 4)
(1 2 3)
3
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
for w in whatval; do for m in m3 m4; do ck "$w" "$m"; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a bare * that is not the Whatever object, or pick, head or tail that refuses it"
