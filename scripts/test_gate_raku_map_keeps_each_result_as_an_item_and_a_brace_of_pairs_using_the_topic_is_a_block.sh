#!/usr/bin/env bash
# test_gate_raku_map_keeps_each_result_as_an_item_and_a_brace_of_pairs_using_the_topic_is_a_block.sh -- TWO CORE SEMANTICS THE ROAST SURVEY FOUND WRONG
# (row raku-every-suite-to-100-under-nonet-ceo-1266; ceo CEO-1479).
#
# 1. MAP KEEPS EACH RESULT AS ONE ITEM, AND ONLY A SLIP SPILLS. (1, 2).map({ ($_, $_ * 2) }) is ((1 2) (2 4)) in Rakudo, and map({ "k$_" => $_ }) yields two Pairs;
#    SCRIP's inline map accumulation (by_name_dispatch.c __rk_map_append) spilled every typed aggregate, so a List, an Array and a Pair result were flattened:
#    (1 2 2 4), 4 elements, and Pair keys and values as separate items. Now only the Slip marker spills ((1, 2).map({ |($_, $_ * 2) }) is (1 2 2 4)).
# 2. A BRACE THAT HOLDS PAIRS AND USES THE TOPIC IS A BLOCK, NOT A HASH. { Belt => $_ } and { a => $^x } read the topic or a placeholder, so Rakudo compiles a block;
#    the parser's hash composer took them as hashes and the lowerer refused the program ("variable _ is read but never assigned": 20 Roast files first-refuse on it).
#    rk_tree.c rkb_block_term keeps the hash only when the pair list reads neither the topic nor a placeholder.
# FOUND, NOT HERE, its own row: the .hash method of a list of Pairs answers an empty hash.
# FAILED ONCE, measured on SCRIP 35a7e023c: mapitems prints (1 2 2 4) for the first line, braceblock is refused by the lowerer in both modes.
#
# EXIT: 0 both witnesses match Rakudo in both modes; 1 a mismatch or a crash; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_map_keeps_each_result_as_an_item_and_a_brace_of_pairs_using_the_topic_is_a_block.sh   (~2s, no oracle at run time)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_map_keeps_each_result_as_an_item_and_a_brace_of_pairs_using_the_topic_is_a_block"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/mapitems.raku" <<'EOF'
say (1, 2).map({ ($_, $_ * 2) });
say (1, 2).map({ |($_, $_ * 2) });
say (1, 2).map({ [$_, $_ * 2] });
say (1, 2).map({ ("k$_" => $_) });
my @a = (1, 2).map({ "k$_" => $_ });
say @a.elems;
say @a[0].key;
sub f($x) { return ($x, $x * 2) }
my @r = (1, 2).map(&f);
say @r.elems;
say (1, 2, 3).map({ $_ * 2 }).elems;
say (1, 2).map({ ($_, $_) }).flat;
say (1, 2, 3).grep({ $_ > 1 }).map({ ($_,) }).elems;
EOF
cat > "$W/mapitems.ref" <<'EOF'
((1 2) (2 4))
(1 2 2 4)
([1 2] [2 4])
(k1 => 1 k2 => 2)
2
k1
2
3
(1 1 2 2)
2
EOF
cat > "$W/braceblock.raku" <<'EOF'
say (1, 2).map({ Belt => $_ });
say (1, 2).map({ "k$_" => $_ });
my %h = { a => 1, b => 2 };
say %h<a>;
my $f = { a => $^x };
say $f(3);
say { a => 1 }.WHAT;
my %g = (1, 2).map({ $_ => 10 * $_ });
say %g<2>;
sub h { { a => 1 } }
say h().WHAT;
EOF
cat > "$W/braceblock.ref" <<'EOF'
(Belt => 1 Belt => 2)
(k1 => 1 k2 => 2)
1
a => 3
(Hash)
20
(Hash)
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
for w in mapitems braceblock; do for m in m3 m4; do ck "$w" "$m"; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a map that flattens its results, or a brace of pairs that reads the topic taken for a hash"
