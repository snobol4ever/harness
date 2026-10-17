#!/usr/bin/env bash
# build_official_oracles.sh — build UNTAINTED official SPITBOL + CSNOBOL4 oracles from upstream GitHub.
# Idempotent. Safe to run multiple times. Companion: util_bench_snobol4_engines.sh (runs the 16-benchmark
# suite under any engine). This is the OFFICIAL-source counterpart of build_spitbol_oracle.sh /
# build_csnobol4_oracle.sh, which build the snobol4ever FORKS (patched: sbl systm.c TIME() ns→CPU-ms;
# csnobol4 FENCE(P)+STNO on a 2.3.3 base) for the monitor workflow. Do NOT retire the fork scripts —
# the monitor depends on the patched TIME(); use THESE oracles for benchmarks and semantics arbitration.
#
# What this encodes (learned + certified 2026-07-10, GOAL-SNOBOL4-BB s13):
#   SPITBOL  — github.com/spitbol/x64 is self-hosting: repo ships the release binary bin/sbl; `make
#              spitbol` rebuilds ./sbl from sbl.min via that bootstrap (nasm + cc). TIME() differences
#              are NANOSECOND-scale (docstring says µs — stale); divide by 1e6 for ms.
#   CSNOBOL4 — github.com/philbudne/csnobol4 (official) has NO GitHub releases and its git tree lacks
#              the generated SIL tables; 00README.git: building needs an existing snobol4. snobol4.org
#              tarballs are egress-blocked here. ABANDONED PATH (do not retry): running gendata.sno
#              under sbl — even with -CASE stripped and a FREEZE(X) shim it generates SILENTLY WRONG
#              tables (PUNCH/BANRCL dropped). CERTIFIED PATH: two-stage bootstrap. Stage-0: the
#              snobol4ever/csnobol4 fork is a CVS full-kit with ALL generated finals committed; stage
#              the *.2 intermediates from the finals + timestamp ordering and `make` yields xsnobol4
#              (its unanchored-ANY is buggy — test/any.sno — but generators run &ANCHOR=1). Stage-1:
#              official tree `make SNO="<fork>/xsnobol4 -b"` regenerates EVERYTHING from official
#              sources and must pass the official 144-test regression gate (rename → snobol4).
#              CERTIFICATION: fixed point — stage-1 binary regenerates its own tables byte-identically
#              (modulo generated-on/$Id headers), proving the stage-0 engine left no fingerprint.
#              The -b in SNO is load-bearing: genc's stdout is redirected into snobol4.c2.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -euo pipefail
OFF="${OFFICIAL_DIR:-$S4E/official}"
SPIT="$OFF/spitbol-x64"; CSN="$OFF/csnobol4"; FORK="$OFF/csnobol4-fork"
GEN="data.c data.h equ.h res.h data_init.h syn.c syn.h syn_init.h snobol4.c proc.h static.h"
mkdir -p "$OFF"

echo "══ stage: official SPITBOL (spitbol/x64) ══"
[ -d "$SPIT/.git" ] || git clone -q https://github.com/spitbol/x64 "$SPIT"
if [ -x "$SPIT/sbl" ] && [ "${FORCE:-0}" != 1 ]; then echo "SKIP already built: $SPIT/sbl"
else (cd "$SPIT" && make spitbol 2>&1 | tail -2); fi
printf "        OUTPUT = 'spitbol-ok'\nEND\n" > /tmp/_off_smoke.sno
out=$("$SPIT/sbl" -b /tmp/_off_smoke.sno </dev/null 2>/dev/null || true)
[ "$out" = "spitbol-ok" ] || { echo "FAIL spitbol smoke (got: $out)"; exit 1; }
echo "OK  official spitbol: $SPIT/sbl (TIME() diffs = ns; ÷1e6 for ms)"

echo "══ stage-0: fork kit engine (snobol4ever/csnobol4 → xsnobol4) ══"
[ -d "$FORK/.git" ] || git clone -q https://github.com/snobol4ever/csnobol4 "$FORK"
if [ -x "$FORK/xsnobol4" ] && [ "${FORCE:-0}" != 1 ]; then echo "SKIP already built: $FORK/xsnobol4"
else
  cd "$FORK"
  for p in $GEN; do [ -f "${p}2" ] || cp -p "$p" "${p}2" 2>/dev/null || true; done
  touch -d '2020-01-01' v311.sil gendata.sno gensyn.sno genc.sno syntax.tbl procs globals
  touch ./*.h2 ./*.c2 $GEN isnobol4.c 2>/dev/null || true
  make > /tmp/_fork_build.log 2>&1 || true   # regression gate fails on the fork's own any.sno bug — xsnobol4 is what we need
  [ -x xsnobol4 ] || { echo "FAIL fork xsnobol4 did not build; see /tmp/_fork_build.log"; exit 1; }
fi
echo "OK  stage-0 generator: $FORK/xsnobol4 (known fork defect: unanchored ANY skips alternate positions — off the &ANCHOR=1 generator path)"

echo "══ stage-1: official CSNOBOL4 (philbudne/csnobol4) via SNO override ══"
[ -d "$CSN/.git" ] || git clone -q https://github.com/philbudne/csnobol4 "$CSN"
if [ -x "$CSN/snobol4" ] && [ "${FORCE:-0}" != 1 ]; then echo "SKIP already built: $CSN/snobol4"
else
  cd "$CSN" && git checkout -q -- . 2>/dev/null || true
  make SNO="$FORK/xsnobol4 -b" > /tmp/_csn_stage1.log 2>&1 \
    || { echo "FAIL stage-1 (official regression gate?); see /tmp/_csn_stage1.log"; exit 1; }
  [ -x snobol4 ] || { echo "FAIL stage-1 produced no ./snobol4"; exit 1; }
fi
p=$(grep -c 'passed\.' /tmp/_csn_stage1.log 2>/dev/null || echo "cached")
echo "OK  official csnobol4: $CSN/snobol4 (regression: $p passed)"

echo "══ certification: fixed point (stage-1 regenerates its own tables) ══"
cd "$CSN"; SNAP=$(mktemp -d)
for f in $GEN; do cp "$f" "$SNAP/"; done
touch v311.sil gendata.sno gensyn.sno genc.sno syntax.tbl procs globals
make SNO="$CSN/snobol4 -b" > /tmp/_csn_fixedpoint.log 2>&1 \
  || { echo "FAIL fixed-point rebuild; see /tmp/_csn_fixedpoint.log"; exit 1; }
FP=OK
for f in $GEN; do diff -q -I 'generated.*on\|\$Id' "$SNAP/$f" "$f" >/dev/null 2>&1 || { echo "DIFFERS: $f"; FP=FAIL; }; done
rm -rf "$SNAP"
[ "$FP" = OK ] || { echo "FAIL fixed point — stage-0 fingerprint suspected"; exit 1; }
printf "        OUTPUT = 'csnobol4-ok'\nEND\n" > /tmp/_off_smoke.sno
out=$(timeout -k 5 10 "$CSN/snobol4" /tmp/_off_smoke.sno </dev/null 2>/dev/null || true)
[ "$out" = "csnobol4-ok" ] || { echo "FAIL csnobol4 smoke (got: $out)"; exit 1; }
rm -f /tmp/_off_smoke.sno
echo "OK  FIXED-POINT CERTIFIED — official binaries:"
echo "    $SPIT/sbl -b <prog.sno>        (self-ms divisor 1000000)"
echo "    $CSN/snobol4 -f <prog.sno>     (self-ms divisor 1)"
md5sum "$SPIT/bin/sbl" "$SPIT/sbl" "$CSN/snobol4" 2>/dev/null || true
