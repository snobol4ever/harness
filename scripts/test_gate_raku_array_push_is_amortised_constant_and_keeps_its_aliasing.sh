#!/usr/bin/env bash
# test_gate_raku_array_push_is_amortised_constant_and_keeps_its_aliasing.sh -- Array.push IS NOT A COPY OF THE ARRAY
# (row raku-every-suite-to-100-under-nonet-ceo-1266; coo FINDING 2026-10-03: "Array.push is quadratic in the array's length, both modes": 40000 pushes took 18.56 s in
# mode 3, Rakudo 0.18 s; Roast gives each file 5 s). The lowering turns @l.push(x) into @l = push_pure(@l, x) and push_pure built a NEW array of the old elements plus the new
# ones on every call. push_pure and append_pure now append in place (rk_arr_append, amortised doubling) when the receiver is an Array (ARBLK.proto NULL); a List, a
# non-array receiver and the front operations keep the copying road. Aliasing is Rakudo's: a copy made by my @n = @m is a separate array, a by-reference @a parameter and a
# scalar holding the array see the push.
# THE WITNESS (m3 and m4, ref cut by Rakudo): 100000 pushes of a two-element array and 50000 appends, then the aliasing cases. Each run has a 20 s timeout: the quadratic road
# needs about two minutes for it, the amortised one a fraction of a second, so a regression reads as a death, not a slow green.
# FOUND, NOT HERE (its own row): .append((4, 5), 6) keeps the List (4 5) as one element in Rakudo and SCRIP spills it.
# EXIT: 0 the witness matches in both modes; 1 a mismatch or a timeout; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_array_push_is_amortised_constant_and_keeps_its_aliasing.sh   (~3s)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_array_push_is_amortised_constant_and_keeps_its_aliasing"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/pushmany.raku" <<'EOF'
my @l;
for 1..100000 -> $i { @l.push([$i, "abcdefgh"]) }
say @l.elems;
say @l[99999][0];
my @m = 1, 2;
my @n = @m;
@m.push(3);
say @m;
say @n;
my @q;
@q.push(1, 2, 3);
@q.push((7, 8));
say @q;
say @q.elems;
sub f(@a) { @a.push(99) }
f(@m);
say @m;
my $r = @m;
@m.push(5);
say $r;
my @big;
for 1..50000 -> $i { @big.append($i) }
say @big.elems;
say @big[49999];
EOF
cat > "$W/pushmany.ref" <<'EOF'
100000
100000
[1 2 3]
[1 2]
[1 2 3 (7 8)]
4
[1 2 3 99]
[1 2 3 99 5]
50000
50000
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
for w in pushmany; do for m in m3 m4; do ck "$w" "$m"; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: an Array.push that copies the array, or that breaks Rakudo's aliasing"
