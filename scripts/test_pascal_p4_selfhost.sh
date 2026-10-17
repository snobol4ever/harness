#!/bin/bash
# test_pascal_p4_selfhost.sh -- THE P4 SELF-HOST TEST (Lon 2026-08-30 stand-up: "Pascal P4 self host is a test we want
# reported on the README"; Lon 2026-09-12 to the coo: "As a milestone get P4 self hosting." and "For each P4 and P5
# self host test, ensure the speed performance is measured for each program."). Row pascal-p4-selfhost-compile-and-report.
#
# The classic self-host: SCRIP compiles the Pascal-P4 compiler (corpus/packages/pascal/p4/comp.pas, vendored with the
# documented patches in PATCHES.md); that compiler compiles its own (detabbed) source into P-code (generation 1);
# SCRIP compiles the P4 interpreter (int.pas), which runs the generation-1 P-code -- the P4 compiler as a P-code
# program -- on the same source (generation 2); generation 2's P-code must equal generation 1's AS A TOKEN SEQUENCE (ceo CEO-1323,
# 2026-09-27): the same line count, and on every line the same whitespace-separated tokens in the same order -- what P4's
# whitespace-insensitive P-code reader sees. Not byte identity: comp.p writes integers with the DEFAULT field width, which ISO 7185
# 6.10.3.1 leaves to the implementation (fpc -Miso 11 columns, P4's own 10), so generation 1 and generation 2 differ by one column
# on every ldc i, ldc b and label line under any host but P4's own; pcode_bytes_identical prints that fact beside the verdict.
# FAIL_ONCE=1 plants a one-token change in generation 2's P-code (line 5 gains a digit) and must read pcode_identical=no. Every program's
# WORK time is printed as wall seconds and maximum RSS from /usr/bin/time, labelled with the tree and mode.
# Verdict line: "P4_SELFHOST: compile=<rc> gen1=<rc> gen1_pcode_lines=<n> gen1_errors=<n> gen2=<rc|BLOCKED> pcode_identical=<yes|no|n/a> pcode_bytes_identical=<yes|no|n/a>"
# then "SELFHOST OK" (gen2 identical), "SELFHOST PARTIAL" (gen1 clean, gen2 ran but differs) or "SELFHOST BLOCKED" (gen2 cannot run).
# rc=2 REFUSES when a prerequisite is missing (an instrument that reports success while doing nothing is the recurring failure).
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
RT_DIR="${RT_DIR:-$(cd "$(dirname "$0")/../../SCRIP/out" && pwd)}"
PKG="$S4E/corpus/packages/pascal/p4"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
[ -x "$SCRIP" ] || { echo "REFUSE(2): no scrip binary at $SCRIP"; exit 2; }
for f in comp.pas int.pas comp_detab.p PATCHES.md; do [ -f "$PKG/$f" ] || { echo "REFUSE(2): $PKG/$f missing -- the vendored P4 (PATCHES.md) is the population"; exit 2; }; done
[ -x /usr/bin/time ] || { echo "REFUSE(2): /usr/bin/time missing -- no WORK time without it"; exit 2; }
TREE="SCRIP=$(git -C "$S4E/SCRIP" rev-parse --short HEAD 2>/dev/null)$(git -C "$S4E/SCRIP" diff --quiet 2>/dev/null || echo -dirty) corpus=$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null) RT_OPT=-O0 mode=m3"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT
tm() { /usr/bin/time -f "%e %M" -o "$W/t" "$@"; local rc=$?; read -r secs kb < "$W/t"; echo "WORK $1_$(basename "${!#}" 2>/dev/null) wall=${secs}s rss=${kb}KB" >&2; return $rc; }
echo "P4 self-host on $TREE"
# generation 1: the SCRIP-built compiler compiles its own source
( cd "$W" && /usr/bin/time -f "%e %M" -o "$W/t1" timeout -k 5 300s "$SCRIP" --run "$PKG/comp.pas" -- prr < "$PKG/comp_detab.p" > gen1.listing 2> gen1.err ); rc1=$?
read -r s1 k1 < <(tail -1 "$W/t1"); case "$s1" in ""|*[!0-9.]*) s1=unmeasured; k1=unmeasured;; esac; echo "WORK comp.pas(gen1, compiling comp_detab.p) wall=${s1}s rss=${k1}KB  ($TREE)"
g1lines=$(wc -l < "$W/prr" 2>/dev/null); g1lines=${g1lines:-0}; g1err=$(grep -c '^ *\*\*\*\*[[:space:]]*\^[0-9]' "$W/gen1.listing" 2>/dev/null); g1err=${g1err:-0}
echo "gen1: rc=$rc1 listing_lines=$(wc -l < "$W/gen1.listing") pcode_lines=$g1lines p4_errors=$g1err $(head -c 120 "$W/gen1.err" | tr '\n' ' ')"
[ "$rc1" -eq 0 ] && [ "$g1lines" -gt 0 ] && [ "$g1err" -eq 0 ] || { echo "P4_SELFHOST: compile=$rc1 gen1=$rc1 gen1_pcode_lines=$g1lines gen1_errors=$g1err gen2=BLOCKED pcode_identical=n/a pcode_bytes_identical=n/a"; echo "SELFHOST BLOCKED (generation 1 is not clean)"; exit 1; }
cp "$W/prr" "$W/gen1.pcode"
# generation 2: the SCRIP-built interpreter runs the gen1 P-code (the P4 compiler) on the same source
( cd "$W" && rm -f prr && cp gen1.pcode prd && /usr/bin/time -f "%e %M" -o "$W/t2" timeout -k 5 600s "$SCRIP" --run "$PKG/int.pas" -- prd prr < "$PKG/comp_detab.p" > gen2.out 2> gen2.err ); rc2=$?
read -r s2 k2 < <(tail -1 "$W/t2"); case "$s2" in ""|*[!0-9.]*) s2=unmeasured; k2=unmeasured;; esac; echo "WORK int.pas(gen2, running the gen1 P-code on comp_detab.p) wall=${s2}s rss=${k2}KB  ($TREE)"
g2lines=$(wc -l < "$W/prr" 2>/dev/null); g2lines=${g2lines:-0}
echo "gen2: rc=$rc2 out_lines=$(wc -l < "$W/gen2.out") pcode_lines=$g2lines $(grep -v '^Command' "$W/gen2.err" | head -c 160 | tr '\n' ' ')"
if [ "$rc2" -ne 0 ] || [ "$g2lines" -eq 0 ]; then echo "P4_SELFHOST: compile=0 gen1=0 gen1_pcode_lines=$g1lines gen1_errors=0 gen2=BLOCKED pcode_identical=n/a pcode_bytes_identical=n/a"; echo "SELFHOST BLOCKED (generation 2 did not finish: rc=$rc2)"; exit 1; fi
[ -n "${FAIL_ONCE:-}" ] && sed -i '5s/$/9/' "$W/prr"
bytes=no; cmp -s "$W/prr" "$W/gen1.pcode" && bytes=yes
tokseq() { awk '{ $1 = $1; print }' "$1"; }
if cmp -s <(tokseq "$W/prr") <(tokseq "$W/gen1.pcode"); then echo "P4_SELFHOST: compile=0 gen1=0 gen1_pcode_lines=$g1lines gen1_errors=0 gen2=0 pcode_identical=yes pcode_bytes_identical=$bytes"; echo "SELFHOST OK"; exit 0; fi
echo "first line whose tokens differ: $(diff <(tokseq "$W/prr") <(tokseq "$W/gen1.pcode") | head -2 | tr '\n' ' ' | cut -c1-160)"
echo "P4_SELFHOST: compile=0 gen1=0 gen1_pcode_lines=$g1lines gen1_errors=0 gen2=0 pcode_identical=no pcode_bytes_identical=$bytes"; echo "SELFHOST PARTIAL"; exit 1
