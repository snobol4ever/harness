#!/usr/bin/env bash
# test_gate_no_rsp_reset_at_beta.sh -- A BETA NEVER RESETS RSP (Lon 2026-10-21, in-chat to the ceo, verbatim: "Ensure that we NEVER reset RSP at
# BETA." · "The reason there is no reason to reset RSP at beta is because allocations are balanced via ALPHA pushes and OMEGA pops." · "I should
# also see a count of RSP resets at BETA and see the count go to ZERO."; ceo CEO-1854/1856).
# Compiles every program of util_spine_population.sh with this root's ./scrip (mode 4 asm) and counts, with util_rsp_reset_by_port_census.py, every
# write of rsp that is not a relative add, sub, push or pop inside a box's beta code, each distinct function body once.
#   test_gate_no_rsp_reset_at_beta.sh [--lang L]
# Board line per language and in total: RSP_RESET_AT_BETA_BOARD lang=<l>|total beta=<n> functions=<f> programs=<p> unmeasured=<u>
# rc 0 beta=0 over a measured population · rc 1 a reset at beta remains · rc 2 could not measure (no ./scrip, a program did not compile, nothing listed).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP/scrip"
L=""; [ "${1:-}" = "--lang" ] && L="${2:-}"
[ -x "$SC" ] || { echo "REFUSE(2): no $SC"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
bash "$HERE/util_spine_population.sh" --corpus "$ROOT/corpus" ${L:+--lang "$L"} > "$T/list" || { echo "REFUSE(2): no population"; exit 2; }
[ -s "$T/list" ] || { echo "REFUSE(2): the population is empty${L:+ for $L}"; exit 2; }
i=0; un=0
while IFS=$'\t' read -r lang f; do
    i=$((i+1)); mkdir -p "$T/$lang"
    ( cd "$(dirname "$f")" && timeout -k 5 300 "$SC" --compile $( [ "$lang" = prolog ] && echo --target=x86 ) --out="$T/$lang/$i.s" "$(basename "$f")" < /dev/null >/dev/null 2>&1 ) || { rm -f "$T/$lang/$i.s"; un=$((un+1)); echo "  unmeasured: $f"; }
done < "$T/list"
tb=0; tf=0; tp=0
for d in "$T"/*/; do
    lang="$(basename "$d")"; n="$(ls "$d"*.s 2>/dev/null | wc -l)"; [ "$n" -gt 0 ] || continue
    line="$(python3 "$HERE/util_rsp_reset_by_port_census.py" "$d"*.s | grep '^RSP_RESET functions=')"
    b="$(echo "$line" | grep -o 'beta=[0-9]*' | cut -d= -f2)"; fn="$(echo "$line" | grep -o 'functions=[0-9]*' | cut -d= -f2)"
    echo "RSP_RESET_AT_BETA_BOARD lang=$lang beta=${b:-0} functions=${fn:-0} programs=$n"
    tb=$((tb + ${b:-0})); tf=$((tf + ${fn:-0})); tp=$((tp + n))
done
echo "RSP_RESET_AT_BETA_BOARD total beta=$tb functions=$tf programs=$tp unmeasured=$un (tree $(git -C "$ROOT/SCRIP" rev-parse --short HEAD))"
[ "$tp" -gt 0 ] || { echo "REFUSE(2): nothing compiled"; exit 2; }
[ "$un" = 0 ] || { echo "REFUSE(2): $un program(s) did not compile -- the count does not cover the population"; exit 2; }
[ "$tb" = 0 ] && { echo "GATE OK [test_gate_no_rsp_reset_at_beta]: no beta resets rsp in $tp programs"; exit 0; }
echo "GATE FAIL [test_gate_no_rsp_reset_at_beta]: $tb beta reset(s) of rsp"; exit 1
