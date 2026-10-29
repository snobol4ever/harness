#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_replace_is_an_asm_leaf_that_agrees_with_sbl_and_its_c_twin.sh -- REPLACE'S BY-NAME BODY IS AN ASM LEAF
# (hq_snobol4 2026-10-21; row snobol4-speed-beauty-self-host-reads-0-22x-spitbol-in-mode-4-and-0-06x-in-mode-3). g_bn_direct's REPLACE
# entry was the C function bn_replace: three BN_PTRLEN reads, a two-memcmp cache check, rt_heap_alloc_c and rt_translate_bytes behind
# libc, 216 instructions of its own per call at -O0 and 178,802 calls in the beauty self-host (lwr and upr of case.inc, 38.6 M of 646.7 M
# Ir). The entry is now bn_replace_leaf (rtx_str.s): it answers the plain case (three DT_S descriptors with a length, from and to of
# equal length 1..62, a subject with a length) from the existing four-slot map cache (read through bn_replace_cache, so the cache stays
# the function-static it always was; the asm hashes into it and compares from and to sixteen bytes at a time), allocates the result
# through rt_gcheap_alloc and translates in place of the call chain; a cache miss asks bn_replace_map (C, builds the slot) and every
# other shape -- an empty or length-less subject, unequal lengths (error 171), a long map, a non-string argument, SCRIP_REPLMAP_OFF --
# tail-jumps to c_bn_replace, the original body. SCRIP_RTX_STR=0 turns the whole str family of asm leaves off: the twin road.
# ARMS: (1) a witness of 18 map lengths (1..62) x miss/hit/hit and a from-differs-at-p / to-differs-at-p variant at the last and the middle
# position of the SAME cache slot (first byte and length fixed), duplicated from-characters, an empty and a numeric subject, prints the
# live oracle's lines in m3 and m4; (2) m4 with SCRIP_RTX_STR=0 (the twin road) and (3) with SCRIP_REPLMAP_OFF=1 (no cache) print them too;
# (4) gdb counts hits over 1,001 REPLACE calls of one cached map, mode 4: bn_replace_leaf at least 1,000 (the entry is live -- a missing
# symbol reads 0 here and REDS, never passes), c_bn_replace at most 10 (the C body is the decline road only), and with SCRIP_RTX_STR=0
# c_bn_replace at least 1,000 (the control: the same loop reaches the C body when the leaf is off).
# FAIL_ONCE (recorded): the pre-cure runtime (b444ca747, where bn_replace is the table entry) has neither symbol: arm 4 reads
# bn_replace_leaf hits = 0 and RED.
# EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle, gdb or the build missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
command -v gdb >/dev/null 2>&1 || { echo "REFUSED(2): gdb missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/rep.sno" <<'SNO'
        DEFINE('mut(s,p,ch)')                           :(mut_end)
mut     mut = s
        mut ? POS(p - 1) LEN(1) = ch                    :(RETURN)
mut_end
        abc = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
        up = 'ZYXWVUTSRQPONMLKJIHGFEDCBAzyxwvutsrqponmlkjihgfedcba9876543210'
        subj = 'the quick brown fox jumps over the lazy dog 0123456789 THE LAZY DOG'
        lens = '1 2 3 4 5 7 8 9 15 16 17 23 26 31 32 33 47 62 '
next    lens ? POS(0) SPAN('0123456789') . fl ' ' =     :F(dups)
        f = SUBSTR(abc, 1, fl)
        t = SUBSTR(up, 1, fl)
        OUTPUT = fl ' ' REPLACE(subj, f, t)
        OUTPUT = fl ' ' REPLACE(subj, f, t)
        OUTPUT = fl ' ' REPLACE(subj, f, t)
        LT(fl, 2)                                       :S(next)
        p = fl
vary    f2 = mut(f, p, 'z')
        t2 = mut(t, p, 'Q')
        OUTPUT = fl ' f' p ' ' REPLACE(subj, f2, t)
        OUTPUT = fl ' f' p ' ' REPLACE(subj, f, t)
        OUTPUT = fl ' t' p ' ' REPLACE(subj, f, t2)
        OUTPUT = fl ' t' p ' ' REPLACE(subj, f, t)
        q = fl / 2 + 1
        EQ(p, q)                                        :S(next)
        p = q                                           :(vary)
dups    d1 = 'aab'
        d2 = 'xyz'
        OUTPUT = 'dup ' REPLACE(subj, d1, d2)
        OUTPUT = 'dup ' REPLACE(subj, d1, d2)
        e1 = ''
        OUTPUT = 'empty [' REPLACE(e1, f, t) ']'
        n1 = 123456789
        n2 = 135
        n3 = 'abc'
        OUTPUT = 'num ' REPLACE(n1, n2, n3)
        OUTPUT = 'done'
END
SNO
"$SBL" $(sbl_lang_flags) "$W/rep.sno" < /dev/null > "$W/rep.ref" 2>&1 || true
[ -s "$W/rep.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
grep -q '^done$' "$W/rep.ref" || { echo "REFUSED(2): the oracle's witness did not reach its last line: $(tail -1 "$W/rep.ref")"; exit 2; }
[ "$(wc -l < "$W/rep.ref")" -ge 100 ] || { echo "REFUSED(2): the oracle's witness printed only $(wc -l < "$W/rep.ref") lines"; exit 2; }
red=0
chk() { if cmp -s "$2" "$W/rep.ref"; then echo "ok  $1 = oracle over $(wc -l < "$W/rep.ref") lines"; else echo "RED $1 differs from the oracle:"; diff "$W/rep.ref" "$2" | head -6; red=1; fi; }
( cd "$W" && timeout -k 5 60 "$ROOT/scrip" rep.sno < /dev/null > "$W/rep.m3" 2>&1 ); chk "(1) m3" "$W/rep.m3"
( cd "$W" && "$ROOT/scrip" --compile --out="$W/rep.s" rep.sno < /dev/null > /dev/null 2>&1 && gcc "$W/rep.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/rep.bin" 2>/dev/null ) || { echo "REFUSED(2): the witness did not build in mode 4"; exit 2; }
( cd "$W" && timeout -k 5 60 ./rep.bin < /dev/null > "$W/rep.m4" 2>&1 ); chk "(1) m4" "$W/rep.m4"
( cd "$W" && SCRIP_RTX_STR=0 timeout -k 5 60 ./rep.bin < /dev/null > "$W/rep.m4off" 2>&1 ); chk "(2) m4 SCRIP_RTX_STR=0 (the C twin road)" "$W/rep.m4off"
( cd "$W" && SCRIP_REPLMAP_OFF=1 timeout -k 5 60 ./rep.bin < /dev/null > "$W/rep.m4nomap" 2>&1 ); chk "(3) m4 SCRIP_REPLMAP_OFF=1 (no map cache)" "$W/rep.m4nomap"
cat > "$W/loop.sno" <<'SNO'
        u = &UCASE
        l = &LCASE
        s = 'Hello World'
        i = 0
loop    r = REPLACE(s, u, l)
        i = LT(i, 1000) i + 1                           :S(loop)
        OUTPUT = 'done ' i ' ' r
END
SNO
( cd "$W" && "$ROOT/scrip" --compile --out="$W/loop.s" loop.sno < /dev/null > /dev/null 2>&1 && gcc "$W/loop.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/loop.bin" 2>/dev/null ) || { echo "REFUSED(2): the loop did not build"; exit 2; }
( cd "$W" && timeout -k 5 30 ./loop.bin < /dev/null > "$W/loop.out" 2>&1 ); grep -q '^done 1000 hello world$' "$W/loop.out" || { echo "REFUSED(2): the loop printed '$(head -1 "$W/loop.out")', not 'done 1000 hello world'"; exit 2; }
hits() { ( cd "$W" && timeout -k 5 300 env $2 gdb -q -batch -ex 'set breakpoint pending on' -ex "break $1" -ex 'ignore 1 100000000' -ex 'run < /dev/null > /dev/null 2>&1' -ex 'info breakpoints' ./loop.bin 2>&1 | grep -o 'already hit [0-9]* time' | grep -o '[0-9]*' | head -1 ); }
leaf=$(hits bn_replace_leaf X=1); cbody=$(hits c_bn_replace X=1); cctl=$(hits c_bn_replace SCRIP_RTX_STR=0); leaf=${leaf:-0}; cbody=${cbody:-0}; cctl=${cctl:-0}
if [ "$leaf" -ge 1000 ] && [ "$cbody" -le 10 ] && [ "$cctl" -ge 1000 ]; then echo "ok  (4) over 1,001 REPLACE calls of one cached map: bn_replace_leaf hits=$leaf (>= 1000), c_bn_replace hits=$cbody (<= 10), and with SCRIP_RTX_STR=0 c_bn_replace hits=$cctl (>= 1000)"
else echo "RED (4) bn_replace_leaf hits=$leaf (want >= 1000), c_bn_replace hits=$cbody (want <= 10), c_bn_replace hits with SCRIP_RTX_STR=0 = $cctl (want >= 1000): REPLACE does not take the asm leaf on a cached map"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: REPLACE's by-name body is an asm leaf, it prints the oracle's lines on every road, and the C body answers only what the leaf declines"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
