#!/usr/bin/env bash
# board_patterns_2mode.sh -- two-mode (m3 --run / m4 --compile) census over crosscheck/patterns.
# Reports per-program AGREE (both modes match .ref) / m3-fail-m4-pass / m4-fail-m3-pass / both-fail,
# with failure-mode tags (DIFF/HANG/SIGnn/rcN). Self-contained per RULES.md.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
TIMEOUT_RETRY="${TIMEOUT_RETRY:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_timeout_retry.sh}"   # every graded timeout is retried once, longer (Lon 2026-10-15, in-chat to the coo: "do a retry with longer timeouts")
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT_DIR="${RT_DIR:-$HERE/../../SCRIP/out}"
PER="${PAT_TIMEOUT:-15}"
OUT="${OUT_TSV:-/tmp/patterns_2mode.tsv}"

[ -x "$SCRIP" ] || { echo "no scrip at $SCRIP"; exit 1; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
# ⭐ RE-POINTED 2026-08-30 (seat12, repo-wide dead-suite-path consumer sweep): crosscheck/patterns/
# is gone -- absorbed into THE ONE FLAT RUNGS (tests/snobol4/ALL.{sno,ref,csv}). An explicit
# PAT_CORPUS override is honored as-is (a caller's own standalone dir); the default now materializes
# the "crosscheck_patterns" family via lib_rungs_extract.sh into a scratch dir first.
if [ -n "${PAT_CORPUS:-}" ]; then
  DIR="$PAT_CORPUS"
else
  RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$HERE/lib_rungs_extract.sh"
  DIR="$WORKDIR/crosscheck_patterns_src"; mkdir -p "$DIR"
  rungs_extract_family crosscheck_patterns "$DIR" 2>/dev/null
fi
[ -d "$DIR" ] || { echo "no corpus at $DIR"; exit 1; }

classify_rc() {
  local rc="$1"
  if   [ "$rc" -eq 124 ]; then echo HANG
  elif [ "$rc" -ge 128 ]; then echo "SIG$((rc-128))"
  elif [ "$rc" -ne 0   ]; then echo "rc$rc"
  else echo DIFF
  fi
}

compile_m4() {
  local sno="$1" out="$2" tmp
  tmp="$(mktemp -d)"
  "$SCRIP" --compile "$sno" > "$tmp/p.s" 2>/dev/null || { rm -rf "$tmp"; return 1; }
  [ -s "$tmp/p.s" ] || { rm -rf "$tmp"; return 1; }
  gcc -c "$tmp/p.s" -o "$tmp/p.o" 2>/dev/null || { rm -rf "$tmp"; return 1; }
  gcc -no-pie "$tmp/p.o" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$out" 2>/dev/null || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"; return 0
}

: > "$OUT"
AGREE=0; M3FAIL_M4PASS=0; M4FAIL_M3PASS=0; BOTHFAIL=0; TOTAL=0
cd "$DIR" || exit 1
for s in *.sno; do
  b="${s%.sno}"
  [ -f "$b.ref" ] || continue
  TOTAL=$((TOTAL+1))
  exp="$(cat "$b.ref")"
  IN=/dev/null; [ -f "$b.input" ] && IN="$b.input"

  got3=$("$TIMEOUT_RETRY" "$PER" "$SCRIP" --run "$s" < "$IN" 2>/dev/null); rc3=$?
  if [ $rc3 -eq 0 ] && [ "$got3" = "$exp" ]; then m3=PASS; else m3=$(classify_rc $rc3); fi

  bin="$WORKDIR/${b}.bin"
  if compile_m4 "$s" "$bin"; then
    got4=$("$TIMEOUT_RETRY" "$PER" "$bin" < "$IN" 2>/dev/null); rc4=$?
    if [ $rc4 -eq 0 ] && [ "$got4" = "$exp" ]; then m4=PASS; else m4=$(classify_rc $rc4); fi
  else
    m4=BUILDFAIL
  fi

  echo -e "$b\t$m3\t$m4" >> "$OUT"

  if   [ "$m3" = PASS ] && [ "$m4" = PASS ]; then AGREE=$((AGREE+1))
  elif [ "$m3" = PASS ] && [ "$m4" != PASS ]; then M4FAIL_M3PASS=$((M4FAIL_M3PASS+1))
  elif [ "$m3" != PASS ] && [ "$m4" = PASS ]; then M3FAIL_M4PASS=$((M3FAIL_M4PASS+1))
  else BOTHFAIL=$((BOTHFAIL+1))
  fi
done

echo "TOTAL $TOTAL  AGREE(both PASS) $AGREE  m4-fail-m3-pass $M4FAIL_M3PASS  m3-fail-m4-pass $M3FAIL_M4PASS  both-fail $BOTHFAIL"
echo "tsv: $OUT"
