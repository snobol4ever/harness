#!/usr/bin/env bash
# util_measure_static_link_arm_snobol4.sh -- the PROVE clause of row m4-static-link-arm: for each of
# the 21 sanctioned demos (util_regen_demo_s_artifacts.sh's own committed DEMOS set -- the .s-artifact
# authority -- resolved by SEARCH, never a hardcoded path, per that script's own s272 re-grid lesson),
# compile+link BOTH the default (shared/dynamic) and the new STATIC (m4-static-link-arm) m4 arms,
# verify both byte-match the committed .ref (BENCHMARK=TEST law), and record binary size plus the
# fault/maxrss delta per demo into a dated TSV under corpus/benchmarks/snobol4/ (the perf-attribution
# naming convention: "never re-run wholesale -- append a new dated file when the tree moves").
#
# ⛔ out/libscrip_rt.so REMAINS CANONICAL. This tool measures the OPT-IN static arm ALONGSIDE it,
# never instead of it -- see lib_static_link_snobol4.sh (the one static-link-arm authority) for why.
# ⛔ CONTROL-ARM TRAP CHECK (FINDING f4f6292c): every "static" binary is verified via `ldd`, not
# assumed, so a link that silently produced a dynamic binary cannot masquerade as the static arm.
set -uo pipefail
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
DEMO="${DEMO_DIR:-$S4E/corpus/demos/snobol4}"
. "$HERE/lib_static_link_snobol4.sh" || { echo "⛔ REFUSING: cannot load lib_static_link_snobol4.sh -- the ONE static-link-arm authority." >&2; exit 3; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSING: scrip not built at $SCRIP" >&2; exit 3; }
RT_A="$(static_rt_archive "$ROOT")" || { echo "⛔ REFUSING: STATIC arm unavailable -- out/libscrip_rt.a could not be built (make libscrip_rt_static)" >&2; exit 3; }
WRAP="$ROOT/tools/bench_rusage"
[ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" 2>/dev/null || { echo "⛔ REFUSING: cannot build $WRAP" >&2; exit 3; }

# THE 21 SANCTIONED DEMO NAMES -- byte-identical to util_regen_demo_s_artifacts.sh's DEMOS var (the
# committed .s-artifact authority). Kept as a literal copy, not sourced from that script, because that
# script's DEMOS is a local shell var with no export contract; a name added there and not here is a
# real gap this tool should surface as UNRESOLVED-here, not silently inherit.
DEMOS="roman wordcount claws5 treebank \
       arithmetic counter hello pattern_test \
       calculator-1 calculator-1-match calculator-1-match-fence \
       calculator-2 calculator-2-match calculator-2-match-fence \
       claws5-match claws5-match-fence \
       json json-match json-match-fence \
       treebank-match treebank-match-fence"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
BDIR="$S4E/corpus/benchmarks/snobol4"
OUT="$BDIR/perf-attribution-${TS}-seat02-static-link-arm.tsv"
[ -d "$BDIR" ] || { echo "⛔ REFUSING: $BDIR does not exist" >&2; exit 3; }
TREE_SCRIP="$(cd "$ROOT" && git rev-parse --short=8 HEAD 2>/dev/null || echo unknown)"
{
  echo "# perf-attribution TSV -- $(date -u +%Y-%m-%d) seat02 -- row m4-static-link-arm: STATIC vs shared m4 link, all 21 sanctioned demos"
  echo "# instrument: tools/bench_rusage (external wait4 rusage, single sample, best-of-1 -- this is a correctness+footprint sweep, not a timing watermark); RT_OPT=-O0"
  echo "# static arm = gcc -no-pie -static + out/libscrip_rt.a (row m4-static-link-arm, opt-in); shared arm = gcc -no-pie -lscrip_rt against out/libscrip_rt.so (canonical, UNCHANGED by this row)"
  echo "# check column: byte-diff of the binary's stdout against the demo's committed .ref (BENCHMARK=TEST law) -- MATCH or MISMATCH, never assumed. static rows also verified genuinely static via ldd (control-arm-trap check, FINDING f4f6292c)"
  echo "# SCRIP tree $TREE_SCRIP -- never re-run wholesale, append a new dated file when the tree moves"
  printf 'demo\tarm\tsize_bytes\tmaxrss_kb\tminflt\tmajflt\tcpu_ms\tcheck\n'
} > "$OUT"

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
FAIL=0
row() { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" >> "$OUT"; }

for name in $DEMOS; do
  hits="$(find "$DEMO" -name "$name.sno" -type f | sort)"
  n="$(printf '%s\n' "$hits" | grep -c . || true)"
  if [ "$n" -ne 1 ]; then
    echo "⛔ REFUSE $name -- $n candidate(s) for $name.sno under $DEMO (0=missing, >1=ambiguous, named not dropped)" >&2
    row "$name" BOTH - - - - - "UNRESOLVED($n)"; FAIL=1; continue
  fi
  sno="$hits"; ref="${sno%.sno}.ref"
  if [ ! -f "$ref" ]; then
    echo "⛔ REFUSE $name -- no .ref beside $sno" >&2
    row "$name" BOTH - - - - - NO-REF; FAIL=1; continue
  fi
  if ! "$SCRIP" --compile -o "$W/$name.s" "$sno" </dev/null >/dev/null 2>&1; then
    echo "⛔ $name: --compile failed" >&2; row "$name" BOTH - - - - - COMPILE-FAIL; FAIL=1; continue
  fi
  if ! as -o "$W/$name.o" "$W/$name.s" 2>/dev/null; then
    echo "⛔ $name: as failed" >&2; row "$name" BOTH - - - - - ASSEMBLE-FAIL; FAIL=1; continue
  fi

  # Input convention observed across the demo corpus: a "-match"/"-match-fence"/"-1"/"-2" suffixed
  # variant shares its family's plain "$fam.input"; a family with no such file takes none (/dev/null).
  fam="$(sed -E 's/-match(-fence)?$//; s/-[12]$//' <<<"$name")"
  in="/dev/null"; [ -f "$(dirname "$sno")/$fam.input" ] && in="$(dirname "$sno")/$fam.input"

  for arm in shared static; do
    bin="$W/$name.$arm.bin"
    if [ "$arm" = static ]; then
      m4_link_static "$bin" "$W/$name.o" "$ROOT"
    else
      gcc -no-pie -o "$bin" "$W/$name.o" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2>/dev/null
    fi
    if [ ! -x "$bin" ]; then
      echo "⛔ $name/$arm: link failed" >&2; row "$name" "$arm" - - - - - LINK-FAIL; FAIL=1; continue
    fi
    if [ "$arm" = static ] && ! verify_static_binary "$bin"; then
      echo "⛔ $name/static: CONTROL-ARM TRAP -- link succeeded but ldd says this is NOT static" >&2
      row "$name" static - - - - - NOT-ACTUALLY-STATIC; FAIL=1; continue
    fi
    size=$(stat -c%s "$bin")
    "$WRAP" timeout -k 5 60 "$bin" < "$in" > "$W/$name.$arm.out" 2>"$W/$name.$arm.err"
    ru=$(grep '^BENCH_RUSAGE:' "$W/$name.$arm.err" | tail -1)
    maxrss=$(grep -oE 'maxrss_kb=[0-9]+' <<<"$ru" | cut -d= -f2); maxrss="${maxrss:-NA}"
    minflt=$(grep -oE 'minflt=[0-9]+'   <<<"$ru" | cut -d= -f2); minflt="${minflt:-NA}"
    majflt=$(grep -oE 'majflt=[0-9]+'   <<<"$ru" | cut -d= -f2); majflt="${majflt:-NA}"
    user_us=$(grep -oE 'user_us=[0-9]+' <<<"$ru" | cut -d= -f2)
    sys_us=$(grep -oE 'sys_us=[0-9]+'   <<<"$ru" | cut -d= -f2)
    cpu_ms=$(awk -v u="${user_us:-0}" -v y="${sys_us:-0}" 'BEGIN{printf "%.2f", (u+y)/1000}')
    if diff -q "$W/$name.$arm.out" "$ref" >/dev/null 2>&1; then chk=MATCH; else chk=MISMATCH; FAIL=1; fi
    row "$name" "$arm" "$size" "$maxrss" "$minflt" "$majflt" "$cpu_ms" "$chk"
    [ "$chk" = MATCH ] || echo "⛔ $name/$arm: stdout MISMATCH vs $ref" >&2
  done
done
echo "wrote $OUT"
if [ "$FAIL" = 0 ]; then
  echo "ALL 21 SANCTIONED DEMOS: shared arm AND static arm both byte-match .ref; every static binary verified genuinely static."
else
  echo "⛔ one or more rows FAILED -- see refusals above and $OUT" >&2
fi
exit "$FAIL"
