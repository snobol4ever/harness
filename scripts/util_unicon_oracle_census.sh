#!/usr/bin/env bash
# util_unicon_oracle_census.sh -- HOW MANY OF UNICON'S OWN TEST PROGRAMS DOES THE UNICON ORACLE ITSELF ANSWER (ceo CEO-2072; the NO_ORACLE_ANSWER census of CEO-1696; hq_icon 2026-10-31).
# A program the oracle gives NO OUTPUT for (it refuses, crashes, aborts, hangs past its time) or whose answer no two runs reproduce leaves a suite's denominator as an EXCLUDED row of class NO_ORACLE_ANSWER;
# every program the oracle DOES answer stays as debt.  This census runs each .icn directly under /home/resources/unicon/tests/<category>/ the way Unicon's own tests/Makefile.test runs it -- compile with the
# oracle, run with data/NAME.dat on stdin when it exists (else /dev/null), stdout and stderr together, in the category's own directory -- in a SCRATCH COPY (the shared drop is not written), TWICE, and
# diffs the first run against stand/NAME.std when Unicon ships one (informational: a diff is the oracle disagreeing with its own ref, which is a finding, not a grading).
# CLASSES: ANSWERED (compiled, ran, not killed, output present and the two runs equal) - COMPILE_REFUSED - HANG (run past the timeout) - CRASH (killed by a signal) - NO_OUTPUT (nothing written, rc != 0) -
#          NONDETERMINISTIC (the two runs differ) - EXCLUDED_CEO1315 (graphics: counted, not run).  STD column: MATCH, DIFF or NONE.
# COVERS every .icn at every depth of the drop's tests (267 files).  RUNTIME_ERROR = the program ended in a Run-time error its .std does not carry (a capability the oracle build lacks, or a library module with no main);
# UNICON_MAKEFILE_SKIP = the suite's own Makefile skips it on this build (database always; crypto when the oracle lacks OpenSSL); HELPER_INPUT = unicon/data/* are inputs of other tests, not tests; tester.u is prebuilt as unicon/Makefile does.
# MEASURED 2026-10-31 (oracle bin/unicon 13.3 d784f58, timeout 20): see .github/findings/FINDING-2026-10-31-hq_unicon-unicon-oracle-census.tsv and the row's baton.
# Usage: bash ../harness/scripts/util_unicon_oracle_census.sh [--timeout SECS] [--out TSV] [--cat CATEGORY]...     rc 0 census written - rc 2 REFUSAL (no oracle, no tests)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_oracle_flags.sh"
UC="$(unicon_bin)" || exit 2
SRC=/home/resources/unicon/tests
[ -d "$SRC" ] || { echo "REFUSED(2) [census]: no Unicon tests at $SRC"; exit 2; }
TMO=20; OUT=""; CATS=()
while [ $# -gt 0 ]; do case "$1" in --timeout) TMO="$2"; shift 2;; --out) OUT="$2"; shift 2;; --cat) CATS+=("$2"); shift 2;; *) echo "REFUSED(2) [census]: unknown argument $1"; exit 2;; esac; done
[ ${#CATS[@]} -gt 0 ] || CATS=(general container pattern coexpr calling preproc lib ipl graphics database posix crypto mt special udb unicon samples thread bench)
W="$(mktemp -d)" || exit 2; trap 'rm -rf "$W"' EXIT
cp -r "$SRC" "$W/tests" || exit 2
[ -n "$OUT" ] || OUT="$W/census.tsv"
mkdir -p "$W/bin"; FEAT="$("$UC" -features 2>/dev/null)"
printf 'category\tprogram\tclass\tcompile_rc\trun_rc\tstd\n' > "$OUT"
for c in "${CATS[@]}"; do
  d="$W/tests/$c"; [ -d "$d" ] || continue
  if [ "$c" = unicon ]; then ( cd "$d" && timeout -k 5 120 "$UC" -s -u -c data/tester.icn > /dev/null 2>&1 && cp tester.u data/tester.u ); fi
  while IFS= read -r f; do
    rel="${f#$d/}"; dd="$(dirname "$f")"; n="$(basename "$f" .icn)"; pn="${rel%.icn}"; exe="$W/bin/$c.${pn//\//.}"
    if [ "$c" = unicon ] && [ "${rel%%/*}" = data ] && [ "$n" != tester ]; then printf '%s\t%s\tHELPER_INPUT\t-\t-\t-\n' "$c" "$pn" >> "$OUT"; continue; fi
    if [ "$c" = database ] || { [ "$c" = crypto ] && [ "$n" != tlsutil ] && ! printf '%s' "$FEAT" | grep -q 'secure sockets layer encryption'; }; then printf '%s\t%s\tUNICON_MAKEFILE_SKIP\t-\t-\t-\n' "$c" "$pn" >> "$OUT"; continue; fi
    if [ "$c" = graphics ]; then printf '%s\t%s\tEXCLUDED_CEO1315\t-\t-\t-\n' "$c" "$pn" >> "$OUT"; continue; fi
    ( cd "$dd" && timeout -k 5 120 "$UC" -s -o "$exe" "$n.icn" > "$W/comp.out" 2>&1 ); crc=$?
    if [ "$crc" -ne 0 ]; then printf '%s\t%s\tCOMPILE_REFUSED\t%s\t-\t-\n' "$c" "$pn" "$crc" >> "$OUT"; continue; fi
    in=/dev/null; [ -f "$dd/data/$n.dat" ] && in="$dd/data/$n.dat"; [ "$in" = /dev/null ] && [ -f "$dd/$n.dat" ] && in="$dd/$n.dat"
    envs=(); [ "$c/$pn" = general/gc2 ] && envs=(BLKSIZE=1000000)
    ( cd "$dd" && env "${envs[@]}" timeout -k 5 "$TMO" "$exe" < "$in" > "$W/o1" 2>&1 ); r1=$?
    ( cd "$dd" && env "${envs[@]}" timeout -k 5 "$TMO" "$exe" < "$in" > "$W/o2" 2>&1 ); r2=$?
    std=NONE; if [ -f "$dd/stand/$n.std" ]; then if cmp -s <(tr -d '\r' < "$W/o1") <(tr -d '\r' < "$dd/stand/$n.std"); then std=MATCH; else std=DIFF; fi; fi
    cls=ANSWERED
    if grep -q 'Run-time error' "$W/o1" && { [ ! -f "$dd/stand/$n.std" ] || ! grep -q 'Run-time error' "$dd/stand/$n.std"; }; then cls=RUNTIME_ERROR; fi
    if [ "$cls" = RUNTIME_ERROR ] && ! { [ "$r1" = 124 ] || [ "$r1" -ge 128 ]; }; then :
    elif [ "$r1" = 124 ] || [ "$r1" = 137 ] || [ "$r2" = 124 ] || [ "$r2" = 137 ]; then cls=HANG
    elif [ "$r1" -ge 128 ] || [ "$r2" -ge 128 ]; then cls=CRASH
    elif [ ! -s "$W/o1" ] && [ "$r1" -ne 0 ]; then cls=NO_OUTPUT
    elif ! cmp -s "$W/o1" "$W/o2"; then cls=NONDETERMINISTIC; fi
    printf '%s\t%s\t%s\t0\t%s\t%s\n' "$c" "$pn" "$cls" "$r1" "$std" >> "$OUT"
  done < <(find "$d" -name '*.icn' | sort)
done
echo "CENSUS_FILE $OUT"
awk -F'\t' 'BEGIN { n = split("ANSWERED COMPILE_REFUSED HANG CRASH NO_OUTPUT NONDETERMINISTIC RUNTIME_ERROR HELPER_INPUT UNICON_MAKEFILE_SKIP EXCLUDED_CEO1315", cs, " ") }
  NR > 1 { if (!($1 in t)) order[++m] = $1; t[$1]++; k[$1 " " $3]++; C[$3]++; T++ }
  END { printf "%-10s %5s", "category", "progs"; for (i = 1; i <= n; i++) printf " %s", cs[i]; print "";
        for (j = 1; j <= m; j++) { printf "%-10s %5d", order[j], t[order[j]]; for (i = 1; i <= n; i++) printf " %d", k[order[j] " " cs[i]] + 0; print "" }
        printf "%-10s %5d", "TOTAL", T; for (i = 1; i <= n; i++) printf " %d", C[cs[i]] + 0; print "" }' "$OUT"
[ -n "${CENSUS_KEEP:-}" ] && cp "$OUT" "$CENSUS_KEEP"
exit 0
