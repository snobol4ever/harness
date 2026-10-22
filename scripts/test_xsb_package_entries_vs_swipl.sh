#!/usr/bin/env bash
# test_xsb_package_entries_vs_swipl.sh -- grade NAMED entries of the vendored XSB test package (corpus/packages/prolog/xsb_tests) against LIVE swipl, m3 and m4, with no board and no score row.
# (hq_packages 2026-10-22: the rows that class the package's reds need a finish line a seat can run on its named entries; the package's own refs are swipl's output of the driven program
# (README: every ref CUT FROM THE ORACLE), so the live swipl run IS the ref and cannot drift from it.)
# For each entry E: oracle = swipl -q E.pl (stdout, stdin /dev/null); m3 = scrip E.pl; m4 = scrip --compile E.pl, linked, run -- each at the entry's declared heap and stack (ALL.csv, lib_declared_arena.sh),
# stdout equal to the oracle's after trailing newlines (as the harness compares: corpus_suite_harness run_oracle strips them). An entry the oracle gives NO output for is reported ORACLE_SILENT and counts as a failure of the instrument's caller (the package excludes those, CEO-1696).
# Usage: bash ../harness/scripts/test_xsb_package_entries_vs_swipl.sh [--modes m3,m4] ENTRY...       (ENTRY = the package's flat name without .pl, e.g. table_tests_abol_test3)
# rc 0 = every named entry equal in every mode, 1 = a difference, 2 = could not measure (no scrip, no swipl, an unknown entry).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"; OUT="${RT_DIR:-$HERE/../../SCRIP/out}"; PKG="${S4E_CORPUS:-$HERE/../../corpus}/packages/prolog/xsb_tests"; SWIPL=/usr/bin/swipl
MODES="m3,m4"; ENTRIES=()
while [ $# -gt 0 ]; do case "$1" in --modes) MODES="$2"; shift;; -*) echo "⛔ REFUSED(2): unknown switch $1"; exit 2;; *) ENTRIES+=("$1");; esac; shift; done
[ ${#ENTRIES[@]} -gt 0 ] || { echo "usage: test_xsb_package_entries_vs_swipl.sh [--modes m3,m4] ENTRY..."; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2): no scrip at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2): no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate test_xsb_package_entries_vs_swipl "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
. "$HERE/lib_declared_arena.sh" || { echo "⛔ REFUSED(2): lib_declared_arena.sh unloadable"; exit 2; }
d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT
# a program may write files beside itself (tempfile.P): run everything in a scratch copy of the package, never in the corpus
cp -r "$PKG" "$d/pkg" || exit 2; SRC="$PKG"; PKG="$d/pkg"
n=0; pass=0; fail=0
for e in "${ENTRIES[@]}"; do
    [ -f "$PKG/$e.pl" ] || { echo "⛔ REFUSED(2): no entry $e in $SRC"; exit 2; }
    (cd "$PKG" && timeout -k 5 60 "$SWIPL" -q "$e.pl" </dev/null > "$d/oracle" 2>/dev/null)
    for m in ${MODES//,/ }; do
        n=$((n + 1)); : > "$d/got"; rc=0
        if [ "$m" = m3 ]; then (cd "$PKG" && run_at_declared_arena "$PKG/ALL.csv" "$e" -- timeout -k 5 60 "$SCRIP" "$e.pl" </dev/null > "$d/got" 2>/dev/null); rc=$?
        else
            if (cd "$d" && timeout -k 5 120 "$SCRIP" --compile -o "$e.s" "$PKG/$e.pl" </dev/null >/dev/null 2>&1 && gcc -no-pie -o "$e.bin" "$e.s" "$OUT/libscrip_rt.so" -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
                (cd "$PKG" && run_at_declared_arena "$PKG/ALL.csv" "$e" -- timeout -k 5 60 "$d/$e.bin" </dev/null > "$d/got" 2>/dev/null); rc=$?
            else rc=125; fi
        fi
        # the harness compares after .rstrip("\n") (corpus_suite_harness.run_oracle: swipl -q on /dev/null stdin ends with one newline from the toplevel's EOF), so does this
        if [ -z "$(cat "$d/oracle")" ]; then fail=$((fail + 1)); echo "ORACLE_SILENT $e $m"
        elif [ "$(cat "$d/oracle")" = "$(cat "$d/got")" ]; then pass=$((pass + 1)); echo "PASS $e $m"
        else fail=$((fail + 1)); echo "FAIL $e $m rc=$rc oracle_lines=$(wc -l < "$d/oracle") got_lines=$(wc -l < "$d/got")"; fi
    done
done
echo "XSBPKG_ENTRIES entries=${#ENTRIES[@]} cases=$n PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
