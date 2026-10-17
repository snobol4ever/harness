#!/usr/bin/env bash
# test_gate_scriptix_a_call_into_the_icon_section_returns_with_the_callers_r12.sh
#
# THE DEFECT (the cto 2026-10-02, ceo CEO-1425 row snobol4-a-pattern-match-compiled-after-a-call-into-the-icon-section-of-
# one-scriptix-file-crashes, found by Lon's infinite_snobol4 SCRIPtix demo): in one SCRIPtix .md whose SNOBOL4 section is the
# entry, a call into the Icon section followed by any statically compiled pattern match died of SIGSEGV, both modes -- a
# store into the sealed code slab. The SNOBOL4 side keeps its capture-stack pointer in r12 (home cell [0x70000000]) and the
# match prologue pushes through it; the Icon procedure's call-entered stub (xa_flat_dc_stub, <name>_dcα) popped its return
# address into r12 and left by pop r12; jmp r12, so the caller got its r12 back holding the return address.
# THE CURE: no dc stub touches r12 -- rax carries the return address at entry (dead there in every variant), the Icon and
# zframe stubs leave by ret, and the PL-DC stub carries it in r11, which the C leave function it tail-jumps to clobbers anyway.
#
# Two programs x two modes; the expected lines are the SNOBOL4 and Icon semantics, written out. rc=0 clean · rc=1 a
# divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/p.md" <<'MD'
```SNOBOL4
        r = id('a')
        OUTPUT = 'called ' r
        'abc' 'b'                                               :F(f)
        OUTPUT = 'matched'                                      :(END)
f       OUTPUT = 'failed'
END
```

```Icon
procedure id(v)
    return v;
end
```
MD
printf 'called a\nmatched\n' > "$D/p.want"
cat > "$D/q.md" <<'MD'
```SNOBOL4
        r = id('a')
        'abc' 'b' . x                                       :F(f)
        r2 = id(x)
        'xyz' ('y' . y) $ z                                 :F(f)
        OUTPUT = r r2 x y z
        r3 = twice(y)
        r3 ARB . w 'y' RPOS(0)                              :F(f)
        OUTPUT = r3 ' ' w                                   :(END)
f       OUTPUT = 'failed'
END
```

```Icon
procedure id(v)
    return v;
end
procedure twice(v)
    return v || v;
end
```
MD
printf 'abbyy\nyy y\n' > "$D/q.want"
red=0; n=0
for p in p q; do
    ( cd "$D" && timeout -k 5 30 "$B/scrip" "$p.md" < /dev/null > "$p.m3" 2>/dev/null )
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile "$p.md" < /dev/null > "$p.s" 2>/dev/null && gcc -no-pie "$p.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$p.bin" 2>/dev/null ) || refuse "$p.md: mode 4 did not build"
    ( cd "$D" && timeout -k 5 30 "./$p.bin" < /dev/null > "$p.m4" 2>/dev/null )
    for m in m3 m4; do
        n=$((n + 1))
        if cmp -s "$D/$p.want" "$D/$p.$m"; then echo "  ok   $p.md $m"; else echo "  FAIL $p.md $m: got [$(tr '\n' '|' < "$D/$p.$m")] want [$(tr '\n' '|' < "$D/$p.want")]"; red=$((red + 1)); fi
    done
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): a SNOBOL4 match after a call into the Icon section runs on the caller's r12, $n arm(s)"; exit 0; fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
