#!/usr/bin/env bash
# test_gate_raku_an_array_subscript_slices_by_an_array_of_indexes_as_rakudo_does.sh -- `@a[@idx]`, `@a[@idx.list]`, `@a[(1,2).list]` (rc-forest-fire-stringify: 400 where Rakudo prints 52100)
# (row raku-every-suite-to-100-under-nonet-ceo-1266; ceo CEO-1479). __rk_arr_at took only an integer index, so a subscript whose index is an array answered the first element; it
# now answers the List of the elements at each index (an out-of-range index is Nil/Any). NOT CLAIMED, named so the claim is exact: Rakudo reads an ITEMIZED array index (an Array held in
# an array or a scalar, `@show[@grid[$r]]`, `@a[$list]`) as ONE integer index (its element count); this runtime slices it, as it answered the first element before. The witness always uses
# .list, the form that is a slice in Rakudo. Refs cut by Rakudo (/usr/bin/raku) at generation; both modes.
# EXIT: 0 every witness-mode pair equals Rakudo's output; 1 one differs; 2 REFUSED (stale binary, no gcc).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_an_array_subscript_slices_by_an_array_of_indexes_as_rakudo_does"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/slice.raku" <<'EOF'
my @show = 'a', 'b', 'c', 'd';
my @i = (0, 2);
say @show[@i];
say @show[0, 2];
say @show[0..1];
say @show[@i.list];
say @show[1..*];
say @show[*-1];
say @show[(1,2).list];
say @show[@i].join("+");
say @show[@i.reverse];
say @show[()].elems;

my @grid = [1, 2, 0], [0, 1, 2];
sub row(@g, $r) { join "", @show[@g[$r].list] }
say row(@grid, 0);
say row(@grid, 1);
EOF
cat > "$W/slice.ref" <<'EOF'
(a c)
(a c)
(a b)
(a c)
(b c d)
d
(b c)
a+c
(c a)
0
bca
abc
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
for w in slice; do for m in m3 m4; do ck "$w" "$m"; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: an array subscript does not slice by an array of indexes as Rakudo's does"
