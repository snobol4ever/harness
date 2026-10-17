#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_kw_direct.sh — KW-D gate: keyword READS are direct cell loads, not runtime calls
# (GOAL-SNOBOL4-100 line 510, Lon verbatim: "place all the keywords as statics ... use direct references").
#
# SHAPE assertions on emitted mode-4 TEXT — the count-the-calls gate that measures the directive itself,
# which the behavior gates cannot (they were green through five sessions of 0 direct keywords):
#   armed (default):        INT keyword reads emit [rip+sym@GOTPCREL] loads and ZERO rt_kw_read_idx calls;
#                           the ONE permitted call is the STR family (&ALPHABET here — live repository);
#                           every WRITE still calls rt_kw_write_idx (208/210/287/209 + KW-5 validation).
#   SCRIP_KW_DIRECT=0:      every read returns to the indexed call, zero GOTPCREL keyword refs.
# BEHAVIOR assertion: the kw_direct_read witness answers its live-oracle .ref in m3 AND m4 on BOTH arms.
#
# Self-contained per RULES.md: paths from $0, timeout on every run.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -uo pipefail
SCRIP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
SCRIP_BIN="${SCRIP_BIN:-$SCRIP_DIR/scrip}"
# ⭐ RE-POINTED (ceo s283h, probe total-conversion): corpus/probe/kw is GONE -- kw_direct_read lives in
# the kw SUITE and is materialized via the harness `extract` verb (test_arbno_witnesses.sh's idiom).
RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$(dirname "${BASH_SOURCE[0]}")/lib_rungs_extract.sh"   # zero-subfolders cutover: extract by ORIGIN from the rungs
[[ -x "$SCRIP_BIN" ]] || { echo "GATE BLOCKED: no scrip at $SCRIP_BIN"; exit 2; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
WIT="$WORK/kw_direct_read.sno"; REF="$WORK/kw_direct_read.ref"
rungs_extract_origin probe_kw__kw_direct_read "$WIT" "$REF" || { echo "GATE BLOCKED: rungs extract kw_direct_read failed"; exit 2; }
[[ -f "$WIT" && -f "$REF" ]] || { echo "GATE BLOCKED: witness pair missing after extract"; exit 2; }
pass=0; fail=0
say() { if [[ "$2" == ok ]]; then pass=$((pass+1)); echo "PASS  $1"; else fail=$((fail+1)); echo "FAIL  $1 ($3)"; fi; }
# --- armed shape -------------------------------------------------------------------------------------
timeout -k 5 30 "$SCRIP_BIN" --compile "$WIT" < /dev/null > "$WORK/armed.s" 2>/dev/null || { echo "GATE BLOCKED: armed compile rc!=0"; exit 2; }
got=$(grep -c '@GOTPCREL' "$WORK/armed.s" || true)
idx=$(grep -cE 'call.*rt_kw_read_idx' "$WORK/armed.s" || true)
wri=$(grep -cE 'call.*rt_kw_write_idx' "$WORK/armed.s" || true)
leg=$(grep -cE 'call.*rt_keyword_read_snobol4' "$WORK/armed.s" || true)
[[ "$got" -ge 6 ]] && say "armed: >=6 direct GOTPCREL keyword loads (got $got)" ok || say "armed: direct loads" bad "GOTPCREL=$got, want >=6"
[[ "$idx" -eq 1 ]] && say "armed: exactly 1 rt_kw_read_idx call (the STR &ALPHABET)" ok || say "armed: read calls" bad "rt_kw_read_idx=$idx, want 1"
[[ "$wri" -eq 2 ]] && say "armed: both writes still call rt_kw_write_idx (validated writes)" ok || say "armed: write calls" bad "rt_kw_write_idx=$wri, want 2"
[[ "$leg" -eq 0 ]] && say "armed: zero legacy name-string calls" ok || say "armed: legacy calls" bad "rt_keyword_read_snobol4=$leg, want 0"
# --- killswitch shape --------------------------------------------------------------------------------
SCRIP_KW_DIRECT=0 timeout -k 5 30 "$SCRIP_BIN" --compile "$WIT" < /dev/null > "$WORK/off.s" 2>/dev/null || { echo "GATE BLOCKED: =0 compile rc!=0"; exit 2; }
got0=$(grep -c '@GOTPCREL' "$WORK/off.s" || true)
idx0=$(grep -cE 'call.*rt_kw_read_idx' "$WORK/off.s" || true)
[[ "$got0" -eq 0 ]] && say "=0: zero GOTPCREL keyword refs (killswitch reverses)" ok || say "=0: GOTPCREL" bad "got $got0, want 0"
[[ "$idx0" -eq 7 ]] && say "=0: all 7 reads back on the indexed call" ok || say "=0: read calls" bad "rt_kw_read_idx=$idx0, want 7"
# --- behavior, both modes x both arms ----------------------------------------------------------------
run3() { SCRIP_KW_DIRECT="$1" timeout -k 5 30 "$SCRIP_BIN" --run "$WIT" < /dev/null > "$2" 2>&1; }
run4() { local s="$WORK/b$1.s" x="$WORK/b$1.bin"; SCRIP_KW_DIRECT="$1" timeout -k 5 30 "$SCRIP_BIN" --compile "$WIT" < /dev/null > "$s" 2>/dev/null && gcc -no-pie -o "$x" "$s" -L"$SCRIP_DIR/out" -lscrip_rt -lm > /dev/null 2>&1 && LD_LIBRARY_PATH="$SCRIP_DIR/out" timeout -k 5 30 "$x" < /dev/null > "$2" 2>&1; }
for arm in 1 0; do
    run3 "$arm" "$WORK/m3.$arm"; diff -q "$REF" "$WORK/m3.$arm" > /dev/null 2>&1 && say "behavior m3 arm=$arm == oracle" ok || say "behavior m3 arm=$arm" bad "diff vs .ref"
    run4 "$arm" "$WORK/m4.$arm"; diff -q "$REF" "$WORK/m4.$arm" > /dev/null 2>&1 && say "behavior m4 arm=$arm == oracle" ok || say "behavior m4 arm=$arm" bad "diff vs .ref"
done
echo "-----------------------------------------------------------------------"
echo "KW-DIRECT GATE: $pass PASS / $((pass+fail)) total"
[[ "$fail" -eq 0 ]] && { echo "GATE GREEN"; exit 0; } || { echo "GATE RED"; exit 1; }
