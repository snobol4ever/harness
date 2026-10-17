#!/usr/bin/env bash
# util_s_md5_sweep.sh — per-program mode-4 .s md5 sweep, for killswitch byte-identity and blast-radius gates.
#   bash ../harness/scripts/util_s_md5_sweep.sh OUT.md5 [LISTFILE]
# LISTFILE = one .sno path per line; default list = corpus demo (maxdepth 1) + crosscheck + library/probe_reference/bb.
# Compare arms/builds with:  diff A.md5 B.md5   (or join to list movers).  Landed s145 (HQ) — the gate that
# proved ARBNO-TAIL-BETA byte-identity (529/529) and the SEED-NAMES fix .s-invariance ran exactly this shape.
#
# ⛔ rc IS RECORDED AND A FAILED COMPILE IS NEVER HASHED (s149, per s148's instrument brief).  The old test was
# `[ -s p.s ]` alone: a compiler that DIED partway still leaves a non-empty TRUNCATED .s, which was then hashed
# as if it were a legitimate result — the s33 "non-empty is not alive" false-signal class living inside the very
# instrument every codegen rung is validated against.  Two truncated arms hash to two different md5s and
# masquerade as blast radius.  Now: rc!=0 emits COMPILE_RC_<rc>, which is a STABLE label — a program whose
# compile segfaults reads COMPILE_RC_139 in BOTH arms and correctly shows as ZERO movers instead of two random
# hashes.  rc==0 with empty output emits COMPILE_EMPTY.  Only rows carrying a real md5 are byte-identity claims.
# Measured at s149 on 529 programs: rc==0 527, rc!=0 2 (crosscheck/coverage/coverage_sno_nodes.sno,
# demo/expression.sno), and ZERO failed compiles emitted bytes — so the hazard has no live
# instance on this tree today and this change is byte-identical in effect here.  It is landed anyway because the
# next codegen rung that segfaults the compiler is exactly when a silent wrong answer would cost a session.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SC="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$SC/scrip}"; CORPUS="${CORPUS:-$S4E/corpus}"
OUT="${1:?usage: util_s_md5_sweep.sh OUT.md5 [LISTFILE]}"; LIST="${2:-}"
T="$(mktemp)"; trap 'rm -f "$T"' EXIT
# library/probe_reference/bb's loose .sno files converted to suite format 2026-08-28 (probe-consolidate-bb, LON-20260828
# total conversion) -- the library/probe_reference/bb find below now contributes 0 by construction. EXPECTED, not a
# regression (the "demo + crosscheck + library/probe_reference/bb = 529" denominator cited across several FINDING docs
# will read smaller from here on -- that is this comment, not a mystery); pass LISTFILE to include
# tests/snobol4/probe/bb*.sno entries (materialize via corpus_suite_harness.py extract first -- suite
# files are not standalone-runnable .sno programs).
if [ -n "$LIST" ]; then cp "$LIST" "$T"; else
  { find "$CORPUS/demos" -maxdepth 1 -name '*.sno'; find "$CORPUS/crosscheck" -name '*.sno'; find "$CORPUS/library/probe_reference/bb" -name '*.sno'; } | sort > "$T"; fi
gen() { local d n W rc; d="$(dirname "$1")"; n="$(basename "$1" .sno)"; W=$(mktemp -d)
  (cd "$d" && SNO_LIB="$d" timeout -k 5 60 "$SCRIP" --compile "$1" </dev/null >"$W/p.s" 2>/dev/null); rc=$?
  if   [ "$rc" -ne 0 ]; then printf 'COMPILE_RC_%s\t%s\n' "$rc" "$1"
  elif [ -s "$W/p.s" ]; then printf '%s\t%s\n' "$(md5sum < "$W/p.s" | cut -d' ' -f1)" "$1"
  else printf 'COMPILE_EMPTY\t%s\n' "$1"; fi
  rm -rf "$W"; }
export -f gen; export SCRIP
xargs -a "$T" -P "$(nproc)" -I{} bash -c 'gen "$@"' _ {} | sort -k2 > "$OUT"
echo "$(wc -l < "$OUT") programs -> $OUT"
awk -F'\t' '$1 ~ /^COMPILE_RC_/ {x++} $1=="COMPILE_EMPTY" {e++} $1 ~ /^[0-9a-f]{32}$/ {c++}
  END {printf "  comparable(rc=0)=%d  compile_empty=%d  excluded(rc!=0)=%d\n", c, e, x}' "$OUT"
# The summary exists so a byte-identity claim states its own DENOMINATOR (s149): "0 movers" is only as strong as
# the comparable count beside it, and a rung that silently moves programs into the excluded bucket would otherwise
# read as MORE green, not less.  Only `comparable(rc=0)` rows carry byte-identity meaning.
