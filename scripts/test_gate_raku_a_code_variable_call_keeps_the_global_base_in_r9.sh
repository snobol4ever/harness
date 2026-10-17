#!/usr/bin/env bash
# test_gate_raku_a_code_variable_call_keeps_the_global_base_in_r9.sh
#
# THE DEFECT (the cfo 2026-10-07, row gc-rt-c-c-to-bb-entries-..., found walking the Raku code-variable call road): r9 is the
# global variable area's base for the whole program (RTCC_GLOBAL_R9_GVA: every global reads [r9 + off], rtccb+48 seeds it,
# no box writes it). The staged entry of a block-protocol graph (xa_flat_block_staged_entry, the FN__<name> head that every
# by-name road, glue and C entry jumps to) counted the staged arguments in r9d, so a sub reached through a code variable, a
# pointy block or a recursive code variable died of SIGSEGV at its first read of a global, both modes (fault address 0x8:
# [r9] with r9 = the argument count). A direct call jumps past the staged entry and never showed it.
# THE CURE: the staged entry counts in esi, which already held &g_call_args there and is dead once the block is built.
#
# ARM 1 (the emitted code): in each program's mode-4 .s, the staged entry FN__<name> .. <name>_αblk writes none of r8-r11.
# ARM 2 (the semantics): three programs x two modes print the Rakudo answers, written out below.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/p.raku" <<'RAKU'
my $k = 10;
sub h($x) { $x + $k }
my &e = &h;
say e(5);
RAKU
printf '15\n' > "$D/p.want"
cat > "$D/q.raku" <<'RAKU'
my $k = 10;
my &e = -> $x { $x + $k };
say e(5);
my $n = 0;
my &inc = -> { $n++ };
inc() for 1..5;
say $n;
RAKU
printf '15\n5\n' > "$D/q.want"
cat > "$D/r.raku" <<'RAKU'
my &fact = sub ($k) { $k <= 1 ?? 1 !! $k * fact($k - 1) };
say fact(10);
RAKU
printf '3628800\n' > "$D/r.want"
red=0; n=0; staged=0
for p in p q r; do
    ( cd "$D" && timeout -k 5 30 "$B/scrip" "$p.raku" < /dev/null > "$p.m3" 2>/dev/null )
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o "$p.s" "$p.raku" < /dev/null > /dev/null 2>&1 && gcc -no-pie "$p.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$p.bin" 2>/dev/null ) || refuse "$p.raku: mode 4 did not build"
    ( cd "$D" && timeout -k 5 30 "./$p.bin" < /dev/null > "$p.m4" 2>/dev/null )
    w=$(awk '/^FN__[^ :]*:/ { on = 1; next } /_αblk:/ { on = 0 } on && $1 == "mov" && $2 ~ /^r(8|9|10|11)[dwb]?,$/ { c++ } END { print c + 0 }' "$D/$p.s")
    s=$(grep -c '^FN__[^ :]*:' "$D/$p.s")
    staged=$((staged + s)); n=$((n + 1))
    if [ "$w" -eq 0 ]; then echo "  ok   $p.raku: $s staged entr(y/ies), none writes r8-r11"; else echo "  FAIL $p.raku: a staged entry writes r8-r11 $w time(s)"; red=$((red + 1)); fi
    for m in m3 m4; do
        n=$((n + 1))
        if cmp -s "$D/$p.want" "$D/$p.$m"; then echo "  ok   $p.raku $m"; else echo "  FAIL $p.raku $m: got [$(tr '\n' '|' < "$D/$p.$m")] want [$(tr '\n' '|' < "$D/$p.want")]"; red=$((red + 1)); fi
    done
done
[ "$staged" -gt 0 ] || refuse "no FN__ staged entry was emitted in any program -- arm 1 measured nothing (the entry was renamed or the road moved)"
if [ $red -eq 0 ]; then echo "GATE PASS(0): a code-variable call keeps the global base in r9, $n arm(s) over $staged staged entr(y/ies)"; exit 0; fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
