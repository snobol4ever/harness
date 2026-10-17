#!/usr/bin/env bash
# test_census_wreg_artifacts.sh — WREG r10/r11 ARTIFACT-LEVEL CLAIM CENSUS (GOAL-SN4-HOME-WIRES, rung W-0).
#
# ⛔ WHY THIS FILE EXISTS.  test_gate_wreg_claim.sh sweeps SOURCES.  The r10 clobber that broke the WREG board
# (FINDING-2026-08-11-CLAUDE-SN46-WREG-BOARD-DEAD-MATCH-END-CLOBBERS-R10) did not live in a source grep's
# reach — it lived in EMITTED CODE, and that FINDING says so verbatim: "WREG-0's claim gate was designed to
# catch this, but it sweeps sources — the clobber lives in emitted asm.  An artifact-level grep would have
# caught it at build time."  W-0 makes that explicit: "grep is insufficient — objdump the emitted slab too."
# This script is that second half.  It answers a DIFFERENT question from the source gate:
#   source gate  = "who MENTIONS r10/r11 in a template?"          (scope, pre-emission)
#   THIS script  = "what actually WRITES r10/r11 in shipped code?" (claim reality, post-emission)
# A template can be clean and the shipped byte still clobber, via a raw-byte encoder, a hand-asm .S, or a
# C compiler's own allocation inside the runtime.  Only this side sees those.
#
# ⛔ WRITES, NOT MENTIONS.  A read of r10 is harmless to a wire; a WRITE destroys it.  Mentions conflate the
# two and inflate the number — the s14/s15b instrument-units conviction, in a new costume.  Destination is
# operand 1 in Intel syntax, so `-M intel` is mandatory here and push/cmp/test are excluded as non-writing.
#
# ⛔ SELF-TEST FIRST (s15b law): a silent zero from a grep is a CLAIM ABOUT TEXT.  Patterns are proven against
# a synthetic objdump line before a single number is reported; failure ⇒ exit 2, report nothing.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -uo pipefail
SO=${SO:-$S4E/SCRIP/out/libscrip_rt.so}
SCRIP=${SCRIP:-$S4E/SCRIP/scrip}
# a WRITE = mnemonic + r10/r11 (any spelling) as FIRST operand; push/cmp/test read only.
W_RE='^[[:space:]]*[0-9a-f]+:.*[[:space:]](mov|movabs|lea|xor|add|sub|and|or|shl|shr|sar|imul|inc|dec|neg|not|pop|movzx|movsxd|movsx|xchg|cmov[a-z]+|set[a-z]+)[[:space:]]+(r1[01])(d|w|b)?[[:space:]]*,'
P_RE='^[[:space:]]*[0-9a-f]+:.*[[:space:]]pop[[:space:]]+(r1[01])(d|w|b)?[[:space:]]*$'
probe=$(printf '  4011a3:\t49 89 c2             \tmov    r10,rax\n  4011b0:\t41 5a                \tpop    r10\n  4011c0:\t41 52                \tpush   r10\n  4011d0:\t4d 39 d1             \tcmp    r9,r10\n')
t=0
echo "$probe" | grep -qE "$W_RE" || { echo "SELF-TEST FAIL: write pattern misses 'mov r10,rax'"; t=1; }
echo "$probe" | grep -qE "$P_RE" || { echo "SELF-TEST FAIL: bare-pop pattern"; t=1; }
echo "$probe" | grep -E "$W_RE" | grep -qE '[[:space:]](push|cmp)[[:space:]]' && { echo "SELF-TEST FAIL: write pattern admits push/cmp (read-only)"; t=1; }
[ $t -eq 0 ] || { echo "⛔ INSTRUMENT SELF-TEST FAILED — refusing to report numbers (s15b law)."; exit 2; }
echo "=== WREG ARTIFACT CENSUS (self-test PASSED) ==="
echo
echo "--- A. RUNTIME SLAB: $SO ---"
if [ ! -f "$SO" ]; then echo "  ⛔ absent — run 'make libscrip_rt' first"; else
  TMP=$(mktemp); objdump -d -M intel "$SO" > "$TMP" 2>/dev/null
  awk -v wre="$W_RE" '
    /^[0-9a-f]+ <.*>:$/ { sym=$2; gsub(/[<>:]/,"",sym); next }
    $0 ~ wre { w[sym]++; tot++ }
    END { printf "  total r10/r11 WRITES in shipped runtime: %d\n\n", tot+0;
          printf "  %-42s %s\n", "symbol", "writes";
          n=0; for (s in w) printf "  %-42s %d\n", s, w[s] | "sort -k2 -nr | head -22"; }
  ' "$TMP"
  echo
  echo "  ⛔ RUNTIME (rt_*) — executes WHILE emitted code is on the stack ⇒ a live wire is exposed:"
  echo "     (⛔ a name-shaped filter like /match|scan|pat/ is WRONG here and this script used one first:"
  echo "      it caught bb_match_defer[abi:cxx11]() — a COMPILE-TIME template fn returning std::string,"
  echo "      whose r10 writes are g++'s own allocation and cannot touch a wire. Mangled C++ ⇒ compiler.)"
  awk -v wre="$W_RE" '
    /^[0-9a-f]+ <.*>:$/ { sym=$2; gsub(/[<>:]/,"",sym); next }
    $0 ~ wre && sym ~ /^rt_/ { w[sym]++; t++ }
    END { printf "    rt_ symbols: %d   writes: %d\n", length(w), t+0;
          for (s in w) printf "    %-40s %d\n", s, w[s] | "sort -k2 -nr | head -12"; }
  ' "$TMP"
  echo "     COMPILE-TIME (mangled C++ template/emitter fns) — counted separately, harmless to wires:"
  awk -v wre="$W_RE" '
    /^[0-9a-f]+ <.*>:$/ { sym=$2; gsub(/[<>:]/,"",sym); next }
    $0 ~ wre && sym ~ /^_Z/ { t++; n[sym]=1 }
    END { printf "    symbols: %d   writes: %d\n", length(n), t+0; }
  ' "$TMP"
  rm -f "$TMP"
fi
echo
echo "--- B. EMITTED PROGRAM TEXT (mode 4) ---"
LIST=${1:-}
if [ -z "$LIST" ]; then echo "  (no program list given; pass a glob dir as \$1 to census emitted text)"; else
  printf "  %-34s %6s %6s %6s\n" program wr_r10 wr_r11 blobs
  T10=0; T11=0; NP=0
  for f in $LIST; do
    b=$(basename "$f" .sno)
    s=$(timeout -k 5 25s "$SCRIP" --compile "$f" 2>/dev/null < /dev/null) || continue
    # emitted text is Intel syntax, mnemonics padded with many spaces
    n10=$(echo "$s" | grep -cE '^[[:space:]]*(mov|movabs|lea|xor|add|sub|and|or|pop|movzx|movsxd)[[:space:]]+r10(d|w|b)?[[:space:]]*,')
    n11=$(echo "$s" | grep -cE '^[[:space:]]*(mov|movabs|lea|xor|add|sub|and|or|pop|movzx|movsxd)[[:space:]]+r11(d|w|b)?[[:space:]]*,')
    nb=$(echo "$s" | grep -cE '^\.LTp[0-9]+_α:')
    T10=$((T10+n10)); T11=$((T11+n11)); NP=$((NP+1))
    [ $((n10+n11)) -gt 0 ] && printf "  %-34s %6s %6s %6s\n" "$b" "$n10" "$n11" "$nb"
  done
  echo "  ---- programs censused: $NP   TOTAL writes r10=$T10 r11=$T11"
fi
echo
echo "CENSUS: INFORMATIONAL (exit 0). Writes are the claim surface; reads are harmless to a wire."
exit 0
