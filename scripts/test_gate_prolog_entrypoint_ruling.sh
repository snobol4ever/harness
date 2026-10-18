#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_prolog_entrypoint_ruling.sh — the executable DONE-WHEN for postoffice row
# `prolog-scrip-auto-invokes-main-without-initialization-directive` (hq_C ruling, 2026-08-29).
#
# THE RULING IT ENFORCES, in one line: SCRIP's auto-invoke of `main/0` on a file carrying no
# `:- initialization(main).` is SANCTIONED (an entry-point convention, byte-faithful to the oracle
# once the oracle is invoked with the matching convention) — but "main/0 is the ONLY entry point"
# is a DEFECT with two faces, and those are the two cure rows this gate requires to exist.
#
# ⭐ WHY A GATE AND NOT A PROSE LINE: the ruling's REASON is a measurable claim ("scrip agrees with
# swipl once the goal is supplied on the command line"). RULES.md § TWO-PART PROOF requires a stated
# mechanism to bear weight, so arm C below RE-DERIVES the reason on every run instead of trusting it.
# A ruling whose reason silently stops being true is exactly the "correct procedure, false explanation"
# class this project has been bitten by repeatedly.
#
# ⛔ ARM D IS NOT DECORATION: it proves the cure hq_P proposed (`swipl -q -g main -t halt`) is UNSAFE
# to apply fleet-wide, because it DOUBLE-RUNS every file that does carry the directive. The invocation
# must be selected per-file. A gate that asserted only arm C would license exactly that mistake.
#
# Usage: bash ../harness/scripts/test_gate_prolog_entrypoint_ruling.sh [--informational]
#        GATE_D2_CEILING=<n>  override the arm-E ratchet ceiling
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
GATE_NAME="prolog-entrypoint-ruling"
GATE_STRICT=1
. "$HERE/lib_gate.sh"
gate_parse_args "$@"

ARCH="$ROOT/../.github/ARCH-LANGUAGES.md"
QUEUE="/home/resources/postoffice/QUEUE.tsv"
SWIPL="/usr/bin/swipl"
SCRIP="$ROOT/scrip"
CORPUS="$ROOT/../corpus"
D2_CEILING="${GATE_D2_CEILING:-36}"

gate_require     "$ARCH"   "ARCH-LANGUAGES.md (where the ruling is written)"
gate_require     "$QUEUE"  "postoffice QUEUE.tsv (where the cure rows live)"
gate_require_exec "$SWIPL" "the SWI-Prolog oracle"
gate_require_exec "$SCRIP" "the scrip binary"
gate_require     "$CORPUS/tests/prolog" "the Prolog test corpus"

FAILS=0
note() { echo "    $*"; }
bad()  { echo "  ✗ $*"; FAILS=$((FAILS + 1)); }
good() { echo "  ✓ $*"; }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
printf 'main :- write(hello), nl.\n'                             > "$W/nodir.pl"
printf ':- initialization(main).\nmain :- write(hello), nl.\n'   > "$W/withdir.pl"
printf ':- write(fromdir), nl.\nmain :- write(frommain), nl.\n'  > "$W/both.pl"
printf ':- write(direct), nl.\n'                                 > "$W/nomain.pl"

echo "== A. the ruling is recorded where Prolog behaviour is specified"
if grep -q 'ENTRY-POINT CONVENTION' "$ARCH"; then good "ARCH-LANGUAGES.md carries the entry-point ruling"
else bad "ARCH-LANGUAGES.md has no ENTRY-POINT CONVENTION ruling — the consequence was never written down"; fi

echo "== B. both cure rows exist (the ruling said 'defect', so a cure must be minted)"
for row in prolog-load-directives-dropped-when-main-exists prolog-directive-only-file-fatals-no-main-bb-graph; do
    if cut -f2 "$QUEUE" | grep -qx "$row"; then good "cure row present: $row"
    else bad "cure row MISSING from QUEUE.tsv: $row"; fi
done

echo "== C. POSITIVE CONTROL — the ruling's reason must bear weight"
note "scrip's implicit main/0 == swipl's explicit -g main, on a directive-less file"
a="$(timeout -k 5 8s "$SWIPL" -q -g main -t halt "$W/nodir.pl" </dev/null 2>/dev/null)"
b="$(timeout -k 5 8s "$SCRIP" "$W/nodir.pl" </dev/null 2>/dev/null)"
if [ "$a" = "$b" ] && [ -n "$a" ]; then good "byte-identical ('$a') — auto-invoke is oracle-faithful, ruling stands"
else bad "DIVERGED: swipl -g main=[$a] scrip=[$b] — the ruling's stated reason no longer holds, RE-OPEN the row"; fi

echo "== D. HAZARD CONTROL — -g main must NOT be applied fleet-wide"
note "on a file that DOES carry the directive, -g main runs main twice"
d="$(timeout -k 5 8s "$SWIPL" -q -g main -t halt "$W/withdir.pl" </dev/null 2>/dev/null | grep -c '^hello$')"
h="$(timeout -k 5 8s "$SWIPL" -q -g halt        "$W/withdir.pl" </dev/null 2>/dev/null | grep -c '^hello$')"
if [ "$d" = "2" ] && [ "$h" = "1" ]; then good "confirmed: -g main=2 runs, -g halt=1 run — invocation MUST be per-file"
else bad "expected -g main=2 / -g halt=1, measured -g main=$d / -g halt=$h — re-derive the per-file rule"; fi

echo "== E. the two defects are still the defects the cure rows describe"
o="$(timeout -k 5 8s "$SCRIP" "$W/both.pl" </dev/null 2>&1)"
if [ "$o" = "frommain" ]; then good "D1 open as described: load-time directive dropped (got 'frommain', swipl gives 'fromdir')"
elif echo "$o" | grep -q 'fromdir'; then good "D1 APPEARS CURED (got '$o') — close the cure row and lower this arm"
else bad "D1 changed shape: scrip both.pl = [$o] — re-measure before trusting the cure row's description"; fi
( timeout -k 5 8s "$SCRIP" "$W/nomain.pl" </dev/null >/dev/null 2>&1 ) ; rc=$?
if [ "$rc" -ne 0 ]; then good "D2 open as described: directive-only file fails (rc=$rc), swipl prints 'direct'"
else bad "D2 APPEARS CURED (rc=0) — verify and close the cure row"; fi

echo "== F. D2 ratchet over the real corpus (may not grow)"
n=0; examined=0
for f in $(find "$CORPUS/tests/prolog" "$CORPUS/benchmarks/prolog" -name '*.pl' 2>/dev/null | sort); do
    grep -qE '^[[:space:]]*main[[:space:]]*(:-|\.)' "$f" && continue
    grep -qE '^[[:space:]]*:-' "$f" || continue
    examined=$((examined + 1))
    # ⛔ CAPTURE, NEVER PIPE. Under `set -o pipefail` the FATAL arm ABORTS (rc=134), and a crashing
    # producer makes the whole pipeline non-zero even when grep matched — so `... | grep -q ... && n++`
    # silently counts ZERO on the very files it exists to count. Measured here: the piped form read
    # 0/58 against a hand-sweep's 36. The floor arm does NOT catch it, because the files ARE examined;
    # only the detection is dead. This is the vacuous-gate class, and pipefail is what hides it.
    out="$(timeout -k 5 8s "$SCRIP" "$f" </dev/null 2>&1)"
    case "$out" in *"main BB graph not found"*) n=$((n + 1)) ;; esac
done
gate_floor "$examined" 20 "directive-only Prolog files"
if [ "$n" -le "$D2_CEILING" ]; then good "D2 FATALs $n <= ceiling $D2_CEILING (examined $examined)"
else bad "D2 FATALs GREW: $n > ceiling $D2_CEILING (examined $examined)"; fi

gate_verdict "$FAILS" "failed assertion(s)"
