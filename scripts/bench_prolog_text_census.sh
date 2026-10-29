#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off (Lon 2026-09-25): the census reads the kernels' mode-4 text as a bench compiles it
# bench_prolog_text_census.sh '<extended regex>' -- COUNT THE LINES OF THE 23 PROLOG KERNELS' MODE-4 TEXT THAT MATCH A PATTERN.
# hq_prolog 2026-10-04 (the call-box row, ARCH-PROLOG-C-OUT-OF-THE-BOX section 9). The sibling of bench_prolog_call_census.sh, which
# counts CALL instructions into named runtime helpers; this one counts any instruction line (a registry jump's load of g_rt_gen_procs,
# the staging loop's `mov r9d, 4`), so a row whose DONE-WHEN is "that instruction leaves the emitted road" can measure it.
# GREEN (rc 0) at zero matches, RED (rc 1) otherwise, REFUSED (rc 2) when a kernel does not compile, the binary is missing, or the population is EMPTY
# (a corpus moved or an S4E_CORPUS pointing elsewhere must never read as a vacuous GREEN).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
B="${S4E_CORPUS:-$ROOT/corpus}/benchmarks/prolog/bench"
RE="${1:-}"; [ -n "$RE" ] || { echo "usage: bench_prolog_text_census.sh '<extended regex>'" >&2; exit 2; }
[ -x "$SCRIP" ] || { echo "REFUSED(2): no scrip binary at $SCRIP" >&2; exit 2; }
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
total=0; nk=0; per=""
for p in "$B"/*.pl; do
    k="$(basename "$p" .pl)"; [ -f "$B/$k.ref" ] || continue
    timeout -k 5 120 "$SCRIP" --compile --out="$TMPD/$k.s" "$p" </dev/null 2>/dev/null || { echo "REFUSED(2): $k.pl did not compile" >&2; exit 2; }
    c=$(grep -cE "$RE" "$TMPD/$k.s"); total=$((total + c)); nk=$((nk + 1)); [ "$c" = 0 ] || per="$per $k=$c"
done
[ "$nk" -gt 0 ] || { echo "REFUSED(2): no kernel with a .ref twin under $B -- a census over zero kernels is no reading" >&2; exit 2; }
if [ "$total" = 0 ]; then echo "GREEN: zero lines matching ($RE) in the emitted mode-4 text of $nk kernels"; exit 0; fi
echo "RED: $total line(s) matching ($RE) remain in the emitted mode-4 text of $nk kernels:$per"; exit 1
