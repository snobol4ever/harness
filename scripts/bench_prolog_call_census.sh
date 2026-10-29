#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_prolog_call_census.sh -- THE BYRD-BOX SCORE'S INSTRUMENT (ceo CEO-1280, 2026-09-26; Lon: "tell me where are we not using the BB's
# layout to run the logic, versus having C function run the logic"): compiles every kernel under corpus/benchmarks/prolog/bench to mode-4
# asm in a mktemp dir and counts, over all of them, the emitted CALL SITES into each runtime entry -- the places where a box hands its
# logic to a C function. With no argument it prints the whole census (entry, sites, kernels). With a regex it counts the sites whose
# callee matches and EXITS 1 when any remain (the rewrite row's RED), 0 when none (GREEN), 2 when it could not compile.
#   usage: bench_prolog_call_census.sh [ENTRY-REGEX]      e.g. 'rt_pl_dop_unify|rt_pl_dop_mkc'   'rt_pl_tr_unwind'   'rt_pl_dop_(ax|cmp|is)_'
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
B="$S4E/corpus/benchmarks/prolog/bench"; [ -x "$ROOT/scrip" ] || { echo "⛔ census REFUSE(2): no ./scrip"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT; n=0; bad=0
for p in "$B"/*.pl; do k=$(basename "$p" .pl); "$ROOT/scrip" --compile --out="$T/$k.s" "$p" < /dev/null > "$T/$k.err" 2>&1 || { echo "⛔ census: $k did not compile ($(head -c 100 "$T/$k.err" | tr '\n' ' '))"; bad=1; continue; }; n=$((n+1)); done
[ "$n" -gt 0 ] || { echo "⛔ census REFUSE(2): no kernel compiled"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ census REFUSE(2): a kernel did not compile (above)"; exit 2; }
sites() { cat "$T"/*.s | grep -oE 'call\s+(qword ptr \[rip \+ [A-Za-z_$0-9]+@GOTPCREL\]|[A-Za-z_$][A-Za-z_$0-9]*(@PLT)?)' | sed -E 's/.*\+ ([A-Za-z_$0-9]+)@GOTPCREL.*/\1/; s/^call\s+//; s/@PLT$//'; }
if [ $# -eq 0 ]; then
  echo "PROLOG CALL CENSUS: $n kernels compiled to mode-4 asm on SCRIP $(git -C "$ROOT" log -1 --format=%h 2>/dev/null); call sites into the runtime by entry (every kernel's emitted code summed)"
  sites | sort | uniq -c | sort -rn | awk '{printf "%7d  %s\n", $1, $2}'
  exit 0
fi
RE="$1"; c=$(sites | grep -cE "^($RE)$")
if [ "$c" -gt 0 ]; then echo "RED: $c call site(s) into ($RE) remain in the emitted mode-4 code of $n kernels: $(sites | grep -E "^($RE)$" | sort | uniq -c | sort -rn | awk '{printf "%s x%d, ", $2, $1}' | sed 's/, $//')"; exit 1
else echo "GREEN: zero call sites into ($RE) in the emitted mode-4 code of $n kernels"; exit 0; fi
