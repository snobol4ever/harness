#!/usr/bin/env bash
# ../harness/scripts/util_rtx_claims.sh -- THE RTX LEDGER GATE.
#
# WHY THIS EXISTS
# ---------------------------------------------------------------------------
# .github/RTX-CLAIMS.md specifies this script and asserts it is run at session
# start and session close: "a hand-maintained ledger will rot ... so the ledger
# is checked by a script that derives truth from the tree, not from itself."
#
# ⛔ IT HAD NEVER BEEN WRITTEN. Measured s212-ICN: absent from ../harness/scripts/, while
# three sessions' prose asserted it was the thing keeping the ledger honest.
# s209-SN4 recorded in the ledger's own message board that it "took the OUT:/FREE
# rows at face value ... that was luck, not verification." s212-ICN then refused
# to port rt_binop_overload purely on a hand-asserted allocation row. Both were
# correct BY LUCK. This closes that.
#
# The ledger is PROSE and stays prose -- humans read it. This script does not
# rewrite it; it recomputes the tree's truth and reports where the two disagree.
#
# THE FIVE ASSERTIONS (RTX-CLAIMS.md "THE GATE"):
#   1 DOUBLE-CLAIM     symbol OUT: to two ladders                    -> FATAL
#   2 PHANTOM-LEDGER   THREE diseases, reported apart (s216, was a single AND):
#                      no def + calls -> FATAL (the rt_frame class: unportable symbol)
#                      def + no calls -> WARN  (fails step 0(f): NOT-A-TARGET)
#                      neither        -> FATAL (ledger rot)
#   3 STALE-PORTED     row not DONE for a symbol already assembly    -> FATAL
#   4 UNLEDGERED-HOT   symbol above threshold, absent from ledger    -> warn
#   5 STALE-CHECKOUT   an OUT: older than 2 sessions                 -> warn
#
# EXIT: 0 = clean (warnings allowed), 1 = at least one FATAL.
#
# ⚠ SCOPE, STATED SO IT IS NOT OVERSOLD: this checks the ledger against the
# tree. It CANNOT check that a ladder honoured a claim it read, and it cannot
# see work in an unpushed clone -- the s202 ancestry check and handoff_status.sh
# remain separate obligations. It makes rot cheap to detect, not impossible.

set -uo pipefail

SCRIP_ROOT="${SCRIP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)}"
GITHUB_ROOT="${GITHUB_ROOT:-}"
CORPUS_ROOT="${CORPUS_ROOT:-}"
CUR_SESSION="${CUR_SESSION:-0}"
HOT_MIN="${HOT_MIN:-100}"

for cand in "$GITHUB_ROOT" "$SCRIP_ROOT/../.github" "$HOME/.github" "$SCRIP_ROOT/../dotgithub"; do
  [ -n "$cand" ] && [ -f "$cand/RTX-CLAIMS.md" ] && GITHUB_ROOT="$(cd "$cand" && pwd)" && break
done
for cand in "$CORPUS_ROOT" "$SCRIP_ROOT/../corpus" "$HOME/corpus"; do
  [ -n "$cand" ] && [ -d "$cand/programs" ] && CORPUS_ROOT="$(cd "$cand" && pwd)" && break
done

LEDGER="${GITHUB_ROOT:-}/RTX-CLAIMS.md"
if [ ! -f "$LEDGER" ]; then
  echo "RTX-CLAIMS GATE: cannot locate RTX-CLAIMS.md (set GITHUB_ROOT=)" >&2; exit 1
fi
echo "=== RTX LEDGER GATE ==="
echo "    ledger  = $LEDGER"
echo "    scrip   = $SCRIP_ROOT"
echo "    corpus  = ${CORPUS_ROOT:-<none: surface checks limited>}"
echo

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FATAL=0; WARN=0
fatal() { echo "  ⛔ FATAL  $*"; FATAL=$((FATAL+1)); }
warn()  { echo "  ⚠  WARN   $*"; WARN=$((WARN+1)); }

# ---------------------------------------------------------------------------
# TREE TRUTH 1 -- symbols that are ALREADY ASSEMBLY. Step 0(e)'s instrument.
# BYTE-CLASS pattern, NOT [A-Za-z_0-9]: the four Greek-named runtime symbols
# (rt_proc_call_epilogue_gamma/omega, rt_gen_spine_pass_gamma/omega) are multi-byte
# UTF-8 and an ASCII-only class TRUNCATES them silently.  That is the ARCH section
# 5(ii) trap, documented after s214 made it -- and this script was making it too.
grep -rhoE '^[[:space:]]*RTX_FUNC\([^)]+\)' \
     "$SCRIP_ROOT/src" --include=*.S 2>/dev/null \
  | sed -E 's/.*RTX_FUNC\(([^)]+)\).*/\1/' > "$TMP/asm_syms"
grep -rhoE '^[^[:space:]:;.#/][^[:space:]:;]*:' "$SCRIP_ROOT/src" --include=*.S 2>/dev/null \
  | sed -E 's/:$//' >> "$TMP/asm_syms"
sort -u "$TMP/asm_syms" -o "$TMP/asm_syms"

# TREE TRUTH 2 -- symbols that HAVE A DEFINITION, taken from the BUILT .so via nm.
# REWRITTEN s216.  The previous version grepped C sources for a definition whose name
# matched `(c_)?rt_[A-Za-z_0-9]*` PLUS A HAND-MAINTAINED ALLOWLIST of five names.  Two
# consequences, both measured: (a) every runtime symbol NOT named rt_* was invisible --
# dat_field_get, data_field_ptr, subscript_set, subscript_get2, DATCON_fn all read as
# HAVING NO DEFINITION; (b) a hand-maintained symbol list is the doc-rot class this very
# script exists to police (util_rtx_arm_census.sh says so in its own header).
# nm on the linked .so is the HONEST definition of "this symbol exists and is callable",
# it needs no prefix rule and no allowlist, and it cannot rot.
: > "$TMP/c_syms"
SO="$SCRIP_ROOT/out/libscrip_rt.so"
# ⛔ THE .so MUST BE CURRENT OR THIS VERDICT IS ABOUT A BUILD NOBODY SHIPS (row stale-binary-preflight-also-
# covers-out-libscrip_rt-so). A stale OLDER .so still exports what src/ deleted and cannot show what src/
# added, so a clean nm surface here is a FALSE GREEN. Shared authority -- sourced, never copied.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_build_currency.sh"
assert_so_current "$SO" "$SCRIP_ROOT" || exit 2
if [ -f "$SO" ]; then
  nm -D --defined-only "$SO" 2>/dev/null | awk '{print $3}' >> "$TMP/c_syms"
  nm    --defined-only "$SO" 2>/dev/null | awk '{print $3}' >> "$TMP/c_syms"
else
  warn "out/libscrip_rt.so not built -- definition truth is UNAVAILABLE, so PHANTOM checks are SUPPRESSED (build first: make libscrip_rt)"
  NO_SO=1
fi
sed -i '/^$/d' "$TMP/c_syms" 2>/dev/null || true
sort -u "$TMP/c_syms" -o "$TMP/c_syms"

# TREE TRUTH 3 -- static call surface, DERIVED FROM THE COMPILER (step 0(i)).
# REWRITTEN s216.  The previous version swept corpus/**/*.s with a first-line
# `.intel_syntax` live-marker filter.  s213 PROVED that tree is permanently frozen:
# 255 of Icon's 265 "live" artifacts were last regenerated 2026-06-27, RULES.md step 4
# FORBIDS regenerating them, and update_icon_bench_asm.sh actively REFUSES to.  All 255
# call rt_frame@PLT -- a symbol DELETED at RUNG ZS-1 s57 that has no definition anywhere
# and that the current compiler emits ZERO times.  So the ledger GATE was itself computed
# on the stale tree it exists to police.  Step 0(i): sweep the COMPILER, never artifacts.
# Cached on the md5 of the driver + .so, so a repeat run inside one session is instant.
: > "$TMP/live_calls"
if [ -n "${CORPUS_ROOT:-}" ]; then
  KEY="$( { md5sum "$SCRIP_ROOT/scrip" "$SCRIP_ROOT/out/libscrip_rt.so" 2>/dev/null || echo none; } | md5sum | cut -c1-16)"
  CACHE="${TMPDIR:-/tmp}/rtx_callsurf_$KEY.txt"
  if [ -s "$CACHE" ] && [ "${RTX_CLAIMS_NOCACHE:-0}" != "1" ]; then
    echo "    call surface: CACHED for this exact binary ($CACHE)"
    cp "$CACHE" "$TMP/live_calls"
  else
    for lang in icon snobol4 prolog; do
      case "$lang" in icon) ext=icn ;; snobol4) ext=sno ;; prolog) ext=pl ;; esac
      # RECURSIVE, and the count is PRINTED.  s216: a -maxdepth 1 sweep saw 316/20/192
      # programs against 1365/210/839 on disk, so a "ZERO call sites" verdict was really a
      # COVERAGE artifact wearing the costume of a measurement -- this ladder's own
      # recurring failure, caught inside the fix for it.  The count is printed and carried
      # into the verdict text so a thin surface can never read as proof of absence.
      find "$CORPUS_ROOT/$lang" "$CORPUS_ROOT/benchmarks/$lang" \
           -name "*.$ext" 2>/dev/null > "$TMP/progs_$lang"
      n=$(wc -l < "$TMP/progs_$lang" 2>/dev/null || echo 0)
      echo "$lang $n" >> "$TMP/surface_sizes"
      echo "    compiling $n $lang programs for the call surface (recursive) ..."
      [ "$n" -eq 0 ] && continue
      # BYTE-CLASS pattern (step 0(f) / section 5(ii) Greek trap) and @PLT ONLY, so locally
      # emitted BB labels (`call main_alpha`, `call proc_X_dcalpha`) are NOT counted as
      # runtime symbols -- that is the phantom class step 0(f) was minted for.
      # EACH WORKER WRITES ITS OWN FILE, then we concatenate.  s216: piping `xargs -P 8`
      # output straight into one grep INTERLEAVES eight compilers' stdout and corrupts
      # matches mid-line.  The tell was unmistakable and is worth recording: a sweep of
      # 2414 programs produced FEWER distinct symbols (142) than a sweep of 316 (152), and
      # subscript_get2 -- which has 52 real sites -- came back ZERO.  A parallel sweep whose
      # shards share a pipe is not a measurement.
      mkdir -p "$TMP/shard_$lang"
      xargs -a "$TMP/progs_$lang" -P 8 -I{} bash -c '
          out="$1/$(echo "$2" | md5sum | cut -c1-16)"
          timeout -k 5 25 "$3" --compile "$2" 2>/dev/null \
            | grep -aoE "call[[:space:]]+[^[:space:],;()]+@PLT" > "$out" || true
        ' _ "$TMP/shard_$lang" {} "$SCRIP_ROOT/scrip"
      cat "$TMP/shard_$lang"/* 2>/dev/null \
        | sed -E 's/^call[[:space:]]+//; s/@PLT$//' \
        | sort | uniq -c | awk -v L="$lang" '{print $2" "L" "$1}' >> "$TMP/live_calls"
      rm -rf "$TMP/shard_$lang"
    done
    cp "$TMP/live_calls" "$CACHE" 2>/dev/null || true
  fi
  echo "    call-surface rows: $(wc -l < "$TMP/live_calls")"
fi
echo

# ---------------------------------------------------------------------------
# LEDGER TRUTH -- every table row naming a symbol in a `code` cell.
grep -oE '^\|[[:space:]]*`[A-Za-z_][A-Za-z_0-9]*`[[:space:]]*\|.*' "$LEDGER" > "$TMP/rows" || true
awk -F'`' '{print $2}' "$TMP/rows" \
  | grep -vE '^(FREE|DONE|OUT|BLOCKED|static|ALL|—|-)$' \
  | grep -E '^[A-Za-z_][A-Za-z_0-9]*$' | sort -u > "$TMP/ledger_syms"
echo "    ledger rows: $(wc -l < "$TMP/rows")  distinct symbols: $(wc -l < "$TMP/ledger_syms")"
echo

state_of() { grep -m1 -E "^\|[[:space:]]*\`$1\`[[:space:]]*\|" "$TMP/rows"; }

echo "--- 1. DOUBLE-CLAIM (a symbol OUT: to two ladders) ---"
while IFS= read -r sym; do
  row="$(state_of "$sym")"
  n=$(grep -oE 'OUT:[A-Z0-9-]+-RTX' <<<"$row" | sort -u | wc -l)
  [ "$n" -gt 1 ] && fatal "$sym is OUT: to $n ladders: $(grep -oE 'OUT:[A-Z0-9-]+-RTX' <<<"$row" | sort -u | tr '\n' ' ')"
done < "$TMP/ledger_syms"
[ "$FATAL" -eq 0 ] && echo "  ok"
echo

echo "--- 2. PHANTOM-LEDGER (three separate diseases; s213 flagged the AND, s216 fixed it) ---"
# WAS: `if hasdef == 0 AND hascall == 0`.  s213 measured why that is wrong and asked for an
# OR; three sessions passed and nobody changed it.  The AND cannot see the ONE case that
# actually occurred: rt_frame has 255 call sites and NO definition, so hascall==1 makes the
# conjunction false and a symbol that CANNOT BE PORTED BECAUSE IT DOES NOT EXIST passes CLEAN.
# The two halves are DIFFERENT DISEASES with different remedies, so they are reported apart:
#   NO-DEF + CALLS  -> the surface names a symbol the tree cannot define.  Either the artifacts
#                      are stale (pre-s216 bug) or a real link break.  FATAL.
#   DEF + NO-CALLS  -> the symbol exists but nothing reaches it across the call boundary, so it
#                      FAILS step 0(f) and is NOT-A-TARGET.  WARN, because it is a legitimate
#                      ledger state to record (subscript_set, rt_case_eq at s216) but must never
#                      be presented as an available port.
#   NEITHER         -> total ledger rot.  FATAL.
P=0
if [ "${NO_SO:-0}" = "1" ]; then
  echo "  SUPPRESSED (no .so: definition truth unavailable -- a missing build must not manufacture phantoms)"
else
while IFS= read -r sym; do
  hasdef=0
  grep -qx "$sym"   "$TMP/asm_syms" && hasdef=1
  grep -qx "$sym"   "$TMP/c_syms"   && hasdef=1
  grep -qx "c_$sym" "$TMP/c_syms"   && hasdef=1
  hascall=0
  [ -s "$TMP/live_calls" ] && grep -q "^$sym " "$TMP/live_calls" && hascall=1
  row="$(state_of "$sym")"
  if grep -qE 'static' <<<"$row"; then
    [ "$hasdef" -eq 0 ] && echo "  note: $sym is ledgered *static* -- no exported def expected, skipping"
    continue
  fi
  if [ "$hasdef" -eq 0 ] && [ "$hascall" -eq 1 ]; then
    sites=$(awk -v s="$sym" '$1==s {t+=$3} END{print t+0}' "$TMP/live_calls")
    fatal "$sym: NO DEFINITION but $sites live @PLT call site(s) -- the surface names a symbol the tree cannot define (the rt_frame class). A row like this looks like a legal claim on an unportable symbol."
    P=1
  elif [ "$hasdef" -eq 1 ] && [ "$hascall" -eq 0 ]; then
    grep -qE 'NOT-A-TARGET|PHANTOM|DONE|BLOCKED' <<<"$row" \
      || { warn "$sym: defined but ZERO live @PLT call sites across the swept surface ($(tr '\n' ' ' < "$TMP/surface_sizes" 2>/dev/null)programs). Fails step 0(f) ON THIS SURFACE => probably NOT-A-TARGET, but a zero is a COVERAGE statement until the surface is known complete -- confirm before marking the row."; P=1; }
  elif [ "$hasdef" -eq 0 ] && [ "$hascall" -eq 0 ]; then
    fatal "$sym: no definition in the built .so AND no live @PLT call site -- ledger rot"
    P=1
  fi
done < "$TMP/ledger_syms"
fi
[ "$P" -eq 0 ] && echo "  ok"
echo

echo "--- 3. STALE-PORTED (already assembly but the row does not say DONE) ---"
S=0
while IFS= read -r sym; do
  if grep -qx "$sym" "$TMP/asm_syms"; then
    row="$(state_of "$sym")"
    grep -q 'DONE' <<<"$row" || { fatal "$sym is assembly in src/**/*.S but its row is not DONE (step 0(e))"; S=1; }
  fi
done < "$TMP/ledger_syms"
[ "$S" -eq 0 ] && echo "  ok"
echo

echo "--- 4. UNLEDGERED-HOT (>= $HOT_MIN static sites in a live surface, no row) ---"
U=0
if [ -s "$TMP/live_calls" ]; then
  awk -v m="$HOT_MIN" '$3 >= m {print $1" "$2" "$3}' "$TMP/live_calls" | sort -k3 -rn | while read -r sym lang n; do
    grep -qx "$sym" "$TMP/ledger_syms" && continue
    grep -qx "$sym" "$TMP/asm_syms" && continue
    echo "  ⚠  WARN   $sym: $n static sites in $lang, absent from the ledger"
  done
  U=$(awk -v m="$HOT_MIN" '$3 >= m {print $1}' "$TMP/live_calls" | sort -u | while read -r s; do
        grep -qx "$s" "$TMP/ledger_syms" || grep -qx "$s" "$TMP/asm_syms" || echo x; done | wc -l)
  WARN=$((WARN+U))
fi
[ "${U:-0}" -eq 0 ] && echo "  ok"
echo

echo "--- 5. STALE-CHECKOUT (an OUT: older than 2 sessions) ---"
T=0
if [ "$CUR_SESSION" != "0" ]; then
  while IFS= read -r sym; do
    row="$(state_of "$sym")"
    s=$(grep -oE 'OUT:[A-Z0-9-]+-RTX:s([0-9]+)' <<<"$row" | grep -oE 's[0-9]+$' | tr -d 's' | head -1)
    [ -z "$s" ] && continue
    age=$(( CUR_SESSION - s ))
    [ "$age" -gt 2 ] && { warn "$sym checked out at s$s, $age sessions ago -- confirm or release"; T=1; }
  done < "$TMP/ledger_syms"
else
  echo "  skipped (pass CUR_SESSION=<n> to enable)"
  T=1
fi
[ "$T" -eq 0 ] && echo "  ok"
echo

echo "============================================================"
if [ "$FATAL" -gt 0 ]; then
  echo "RTX LEDGER GATE: BLOCKED — $FATAL fatal, $WARN warning(s)"
  exit 1
fi
echo "RTX LEDGER GATE: CLEAN — 0 fatal, $WARN warning(s)"
exit 0
