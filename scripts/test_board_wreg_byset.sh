#!/usr/bin/env bash
# BY-SET board for LADDER WREG: crosscheck/patterns, mode 3, BOTH SCRIP_WREG arms, same container, same binary.
# Exists because a NET COUNT CANNOT DISTINGUISH 10-repaired/0-broken FROM 15/5 (s17 law) and counts do not transfer
# across containers (s7 law).  This prints the SETS and the per-arm FAILURE-MODE split, which is the thing the s19
# cursor did not carry: the residual is 19 SIGSEGV + 7 HANG, not one suspension class (s20).
# Usage: bash ../harness/scripts/test_board_wreg_byset.sh [off|on|both]   (default both; run one arm at a time under short tool timeouts)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
SCRIP=${SCRIP_BIN:-$S4E/SCRIP/scrip}
OUT=${WREG_OUT:-/tmp/wreg_board.$$}
PER=${WREG_TIMEOUT:-15}
mkdir -p "$OUT"
# ⭐ RE-POINTED 2026-08-30 (seat12, repo-wide dead-suite-path consumer sweep): crosscheck/patterns/
# is gone -- absorbed into THE ONE FLAT RUNGS. An explicit WREG_CORPUS override is honored as-is;
# the default now materializes the "crosscheck_patterns" family via lib_rungs_extract.sh.
if [ -n "${WREG_CORPUS:-}" ]; then
  DIR="$WREG_CORPUS"
else
  RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$S4E/harness/scripts/lib_rungs_extract.sh"
  DIR="$OUT/crosscheck_patterns_src"; mkdir -p "$DIR"
  rungs_extract_family crosscheck_patterns "$DIR" 2>/dev/null
fi
run_arm() {
  local val="$1" tag="$2"
  : > "$OUT/pass.$tag"; : > "$OUT/fail.$tag"
  cd "$DIR" || exit 1
  for f in *.sno; do
    local b="${f%.sno}" IN=/dev/null
    [ -f "$b.ref" ] || continue
    [ -f "$b.input" ] && IN="$b.input"
    local got rc
    got=$(SCRIP_WREG="$val" timeout -k 5 "$PER" "$SCRIP" --run "$f" < "$IN" 2>/dev/null); rc=$?
    if [ $rc -eq 0 ] && [ "$got" = "$(cat "$b.ref")" ]; then echo "$b" >> "$OUT/pass.$tag"; else echo "$b rc=$rc" >> "$OUT/fail.$tag"; fi
  done
  sort -o "$OUT/pass.$tag" "$OUT/pass.$tag"
  echo "$tag PASS: $(wc -l < "$OUT/pass.$tag") / $(ls "$DIR"/*.sno | wc -l)"
  echo "$tag failure modes (139=SIGSEGV 124=HANG 0=WRONG-OUTPUT):"; awk '{print $NF}' "$OUT/fail.$tag" | sort | uniq -c | sort -rn | sed 's/^/    /'
}
case "${1:-both}" in
  off) run_arm 0 off ;;
  on)  run_arm 1 on ;;
  *)   run_arm 0 off; run_arm 1 on ;;
esac
if [ -s "$OUT/pass.off" ] && [ -s "$OUT/pass.on" ]; then
  echo "REPAIRED (ON passes, OFF fails): $(comm -13 "$OUT/pass.off" "$OUT/pass.on" | wc -l)"
  comm -13 "$OUT/pass.off" "$OUT/pass.on" | sed 's/^/  + /'
  comm -23 "$OUT/pass.off" "$OUT/pass.on" > "$OUT/broken"
  echo "BROKEN (OFF passes, ON fails): $(wc -l < "$OUT/broken")"
  sed 's/^/  - /' "$OUT/broken"
  echo "BROKEN split by failure mode:"; grep -Ff "$OUT/broken" "$OUT/fail.on" | awk '{print $NF}' | sort | uniq -c | sort -rn | sed 's/^/    /'
  echo "BROKEN rc=124 (HANG class -- WREG-4 remaining half, NOT WREG-3 suspension):"
  grep -Ff "$OUT/broken" "$OUT/fail.on" | awk '$NF=="rc=124"{print "    "$1}'
fi
echo "evidence: $OUT"
