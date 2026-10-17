#!/usr/bin/env bash
# util_zframe_ab.sh <label> -- run a fixed 22-program batch under whatever scrip/.so pair is
# currently installed at /home/claude/SCRIP, and report ok/crash counts.
# Used to VERIFY (not inherit) the ZC_FRAME_RBP-does-not-run claim. Same batch, same order,
# same timeout for both arms, so the two runs are comparable by construction.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
LABEL="$1"
S=$S4E/SCRIP; C=$S4E/corpus
export LD_LIBRARY_PATH=$S/out:${LD_LIBRARY_PATH:-}
# ⭐ RE-POINTED 2026-08-30 (seat12, repo-wide dead-suite-path consumer sweep): feat/f04_pattern_primitives.sno
# and parser/pat_arbno.sno were absorbed into THE ONE FLAT RUNGS and their loose files deleted;
# lib_rungs_extract.sh materializes both back out by origin into a scratch dir.
RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$S/../harness/scripts/lib_rungs_extract.sh"
ZFAB_W="$(mktemp -d)"; trap 'rm -rf "$ZFAB_W"' EXIT
rungs_extract_origin feat__f04_pattern_primitives "$ZFAB_W/f04_pattern_primitives.sno" >/dev/null 2>&1
rungs_extract_origin parser_pat_arbno__parser_pat_arbno "$ZFAB_W/pat_arbno.sno" >/dev/null 2>&1
PROGS="
$ZFAB_W/f04_pattern_primitives.sno
$ZFAB_W/pat_arbno.sno
$C/benchmarks/snobol4/pattern_bt.sno
$C/benchmarks/snobol4/string_pattern.sno
$C/benchmarks/snobol4/arith_loop.sno
$C/benchmarks/snobol4/fibonacci.sno
$C/benchmarks/snobol4/string_concat.sno
$C/benchmarks/snobol4/table_access.sno
$C/benchmarks/snobol4/var_access.sno
$C/benchmarks/snobol4/roman.sno
$C/benchmarks/snobol4/func_call.sno
$C/benchmarks/snobol4/op_dispatch.sno
$C/icon/rung36_jcon_args.icn
$C/icon/rung36_jcon_btrees.icn
$C/icon/rung36_jcon_string.icn
$C/icon/rung36_jcon_sieve.icn
$C/benchmarks/icon/concord.icn
$C/benchmarks/icon/deal.icn
$C/tests/prolog/rung11_findall_findall_basic.pl
$C/tests/prolog/rung10_assert_assertz_basic.pl
$C/icon/rung36_jcon_cxprimes.icn
$C/tests/snobol4/feat/f01_hello.sno
"
ok=0; crash=0; miss=0
for p in $PROGS; do
  [ -f "$p" ] || { miss=$((miss+1)); continue; }
  n=$(basename "$p")
  timeout -k 5 20 "$S/scrip" --run "$p" > /tmp/ab_out.txt 2>/tmp/ab_err.txt < /dev/null
  rc=$?
  # crash = signal death (128+n): 139 SEGV, 134 abort, 136 SIGFPE, etc.
  if [ $rc -ge 128 ]; then
    crash=$((crash+1)); printf '  CRASH rc=%-4s %s\n' "$rc" "$n"
  else
    ok=$((ok+1));    printf '  ok    rc=%-4s %s\n' "$rc" "$n"
  fi
done
echo "=== $LABEL: ok=$ok crash=$crash missing=$miss (total=$((ok+crash))) ==="
