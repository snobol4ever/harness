#!/usr/bin/env bash
# test_gate_scriptix_a_snocone_and_a_pascal_fence_compile_through_their_own_frontends.sh
#
# THE DEFECT (the cto 2026-10-02, ceo CEO-1437 row scriptix-a-snocone-or-pascal-fence-is-not-compiled-so-two-of-the-seven-
# languages-cannot-sit-in-one-scriptix-file; Lon: "Change that ugly SNOBOL4 code to Snocone."): the SCRIPtix splitter
# (src/driver/polyglot.c parse_scrip_polyglot) read fences named SNOBOL4 / SCRIP / Scrip, Icon, Prolog, Raku and Rebus and
# skipped every other, so a .md whose fence is Snocone or Pascal compiled nothing and printed "scrip: sm_lower failed".
# THE CURE: a Snocone fence goes through snocone_compile and the SNOBOL4 lowerer, a Pascal fence through pascal_compile and
# lower_pascal_stage2 -- exactly the pair the driver uses for a plain .sc and .pas.
#
# Three documents x two modes; the expected lines are the programs' own semantics. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/sc.md" <<'MD'
```Snocone
OUTPUT = "hello from snocone";
```
MD
printf 'hello from snocone\n' > "$D/sc.want"
cat > "$D/pas.md" <<'MD'
```Pascal
program hi(output);
begin
  writeln('hello from pascal')
end.
```
MD
printf 'hello from pascal\n' > "$D/pas.want"
cat > "$D/mix.md" <<'MD'
```Snocone
procedure twice(x) { twice = x x; return; }
r = id("ab");
OUTPUT = "snocone got " r;
OUTPUT = "twice " twice(r);
if ("abc" ? "b") OUTPUT = "matched";
```

```Icon
procedure id(v)
    return v;
end
```
MD
printf 'snocone got ab\ntwice abab\nmatched\n' > "$D/mix.want"
red=0; n=0
for p in sc pas mix; do
    ( cd "$D" && timeout -k 5 30 "$B/scrip" "$p.md" < /dev/null > "$p.m3" 2>/dev/null )
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile "$p.md" < /dev/null > "$p.s" 2>/dev/null && gcc -no-pie "$p.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$p.bin" 2>/dev/null && timeout -k 5 30 "./$p.bin" < /dev/null > "$p.m4" 2>/dev/null )
    for m in m3 m4; do
        n=$((n + 1))
        if [ -f "$D/$p.$m" ] && cmp -s "$D/$p.want" "$D/$p.$m"; then echo "  ok   $p.md $m"; else echo "  FAIL $p.md $m: got [$(tr '\n' '|' < "$D/$p.$m" 2>/dev/null)] want [$(tr '\n' '|' < "$D/$p.want")]"; red=$((red + 1)); fi
    done
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): a Snocone and a Pascal fence compile through their own frontends, $n arm(s)"; exit 0; fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
