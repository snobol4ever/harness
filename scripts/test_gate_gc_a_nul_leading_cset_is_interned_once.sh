#!/usr/bin/env bash
# test_gate_gc_a_nul_leading_cset_is_interned_once.sh -- the Icon cset registry finds a cset by its CONTENT whatever its first
# byte, so building the same NUL-leading cset in a loop allocates nothing new (row
# gc-the-cset-registry-keeps-a-memo-of-raw-addresses-and-a-content-index-that-refuses-a-nul-leading-cset, cfo 2026-09-22).
#
# THE DEFECT (src/runtime/keywords.c): the content index hashed and compared C strings, so kw_cset_find_content refused any
# cset whose first byte is NUL and kw_cset_intern (guarded by strlen(canon) == len) appended a fresh registry entry AND a
# fresh heap block on every call -- every cset holding NUL sorts it first, and &cset and &ascii are both NUL-leading.
# MEASURED before the cure: 500 calls of cset("\^@abc") read blocks=1118 against 623 for 5 calls. THE CURE: the index
# hashes len bytes and matches on the entry's stored len plus memcmp; kw_cset_len's C-string lookup keeps refusing an
# unregistered NUL-leading pointer (it would otherwise answer the empty cset's 0).
# THE MEMO HALF (kw_cset_gc_weak): the regc memo of raw addresses is now cleared at EVERY collection, not only when an entry
# dies, so a cset block that lands at a moved block's old address is registered. ⛔ That hazard was NOT witnessed firing; the
# cure is structural and no arm here can fail on it.
# ARM A (memory): blocks after 500 builds of a NUL-leading cset equal blocks after 5, within the CONTROL arm's own movement
# (the plain cset("abc"), which must itself be flat, or the instrument is not measuring dedupe and the gate REFUSES).
# ARM B (meaning): one program over NUL-bearing csets (identity, ++ -- **, &cset, &ascii, a 2000-build loop) prints the output
# cut 2026-10-03 from Arizona Icon (/home/resources/icon-master), in mode 3 and mode 4.
# FAIL-ONCE: arm A read 623 -> 1118 on the parent.
set -uo pipefail
GATE_NAME=test_gate_gc_a_nul_leading_cset_is_interned_once
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
blk() { printf 'procedure main()\n   local i, c, s;\n   s := %s;\n   every i := 1 to %d do c := cset(s);\n   write(*c);\nend\n' "$1" "$2" > "$d/x.icn"
    env SCRIP_HEAP_KB=4096 SCRIP_GC_EXERCISE=1 timeout -k 5 60s "$SCRIP" "$d/x.icn" </dev/null >/dev/null 2>"$d/e"; grep -m1 -oE "blocks=[0-9]+" "$d/e" | head -1 | cut -d= -f2; }
n5=$(blk '"\^@abc"' 5); n500=$(blk '"\^@abc"' 500); p5=$(blk '"abc"' 5); p500=$(blk '"abc"' 500)
[ -n "$n5" ] && [ -n "$n500" ] && [ -n "$p5" ] && [ -n "$p500" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no blocks= reading -- the run did not report"; exit 2; }
[ $((p500 - p5)) -le 2 ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: the control arm grew by $((p500 - p5)) blocks, so the instrument is not measuring dedupe today"; exit 2; }
fails=0
echo "  arm A: NUL-leading cset blocks $n5 -> $n500 ; plain control $p5 -> $p500"
[ $((n500 - n5)) -le $((p500 - p5 + 2)) ] || { fails=$((fails + 1)); echo "  arm A RED: the NUL-leading cset grew $((n500 - n5)) blocks over 495 extra builds"; }
cat > "$d/c.icn" <<'ICN'
procedure main();
   local c, d, e, i, s, t;
   c := cset("\^@abc");
   d := cset("cba\^@");
   write(*c, " ", *d, " ", image(c === d), " ", image(c == d));
   e := c ++ 'xyz';
   write(*e, " ", image(any(c, "\^@zz")), " ", image(any(c, "zz")));
   write(*(&cset -- c), " ", *(&ascii ** c), " ", *(c -- '\^@'));
   s := "";
   every i := 1 to 300 do s ||:= char(i % 7);
   t := cset(s);
   write(*t, " ", *cset(s), " ", image(t === cset(s)));
   every i := 1 to 2000 do c := cset("\^@" || char(65 + i % 26));
   write(*c, " ", image(c));
   write(*(cset("\^@\^Aa") ++ cset("\^@\^Bb")));
   write(image(cset("\^@")), " ", *cset("\^@"), " ", *cset(""));
end
ICN
cat > "$d/want" <<'WANT'
4 4 '\x00abc' "\x00abc"
252 4 3
7 7 '\x00\x01\x02\x03\x04\x05\x06'
2 '\x00Y'
5
'\x00' 1 0
WANT
(cd "$d" && timeout -k 5 20 "$SCRIP" c.icn </dev/null 2>/dev/null) > "$d/m3"; rc=$?
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m3"; then fails=$((fails + 1)); echo "  arm B m3 rc=$rc differs:"; diff "$d/want" "$d/m3" | head -10; fi
if (cd "$d" && timeout -k 5 60 "$SCRIP" --compile --out=c.s c.icn </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie c.s -L"$OUT" -lscrip_rt -lm -lpthread -Wl,-rpath,"$OUT" -o c.bin 2>/dev/null); then
    (cd "$d" && timeout -k 5 20 ./c.bin </dev/null 2>/dev/null) > "$d/m4"; rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m4"; then fails=$((fails + 1)); echo "  arm B m4 rc=$rc differs:"; diff "$d/want" "$d/m4" | head -10; fi
else fails=$((fails + 1)); echo "  arm B m4 did not compile or link"; fi
[ "$(grep -c '' "$d/want")" -eq 6 ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table is not the 6-line oracle cut"; exit 2; }
echo "GCNULCSET_BOARD arms=3 FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
