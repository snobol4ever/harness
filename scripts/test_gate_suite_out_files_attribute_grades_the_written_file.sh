#!/usr/bin/env bash
# test_gate_suite_out_files_attribute_grades_the_written_file.sh -- a test unit that declares out_files is graded on its stdout
# followed by the bytes of each file it WRITES, identically in the oracle ref cut (util_build_package_suite.py) and in m3 and m4
# (corpus_suite_harness.py); a declared file the run did not write reads FAIL even when a staged copy sits beside the program;
# a cell naming a path refuses rc=2 at read time; a table without the column grades stdout alone, as before it existed.
#
# WHY (Lon 2026-09-27, in-chat to hq_snobol4, picking "Out-file attribute"): aisnobol BUILDLIB.sno prints nothing -- its answer
# is the spitlib.idx it writes -- so a stdout-only harness could only refuse it as a vacuous ref. The shape is the coo's (one
# ALL.csv column out_files, read by header name in read_command_line_columns beside compile_args and run_args, the listed files
# appended in order after the run, a missing file a FAIL and never a refusal); the builder reads a <stem>.outfiles sidecar.
# The delete-before-run is load-bearing: the staging directory copies every companion a unit's text names, so without it the
# package's shipped copy of the file would answer for a program that never wrote one (arm 3 is that case).
#
# THE ARMS (a scratch package, the oracle sbl -bf):
#   1  the builder's ref cut of WRITES (prints 'hdr', writes out.txt) is 'hdr' + out.txt's bytes, and ALL.csv carries out_files
#                                                                                                                    -- RED on base
#   2  m3: WRITES PASS, NOFILE (no column cell) graded on stdout alone PASS
#   3  m3 + m4: SILENT (declares out.txt, names it, never writes it; a staged out.txt beside it) reads FAIL, never PASS
#   4  m4: WRITES PASS
#   5  an out_files cell naming '../x' or '/tmp/x' refuses rc=2                                                      -- RED on base
# (on base the builder cuts stdout alone, so arms 2-4 grade that; arms 1 and 5 are the ones the attribute alone can turn.)
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
NAME=suite_out_files_attribute_grades_the_written_file
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$ROOT/scrip" ] || refuse "no scrip binary -- cannot measure"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "no out/libscrip_rt.so -- cannot measure mode 4"
[ -x /home/resources/x64/bin/sbl ] || refuse "no sbl oracle -- the builder cannot cut a ref"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
P="$T/pkg"; mkdir -p "$P"
printf '%s\n' "        OUTPUT = 'hdr'" "        OUTPUT(.O,2,'out.txt')" "        O = 'line one'" "        O = 'line two'" END > "$P/WRITES.sno"
printf '%s\n' "        F = 'out.txt'" "        OUTPUT = 'silent'" END > "$P/SILENT.sno"
printf '%s\n' "        OUTPUT(.O,2,'side.txt')" "        O = 'ignored'" "        OUTPUT = 'nofile'" END > "$P/NOFILE.sno"
printf 'out.txt\n' > "$P/WRITES.outfiles"
( cd "$ROOT" && python3 ../harness/scripts/util_build_package_suite.py "$P" > "$T/build.log" 2>&1 ) || refuse "the builder did not build the scratch package: $(tail -3 "$T/build.log" | tr '\n' '|')"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
ref_writes="$(python3 "$HERE/corpus_suite_harness.py" list "$P/ALL.sno" "$P/ALL.ref" > /dev/null 2>&1; awk '/ WRITES$/{f=1;next} /^\*-+ [0-9]+ /{f=0} f' "$P/ALL.ref" | tr '\n' '|')"
arm "the builder's ref cut of WRITES is its stdout then out.txt, and ALL.csv declares out_files" "$([ "$ref_writes" = 'hdr|line one|line two|' ] && grep -q '^[0-9]*,WRITES,.*,out.txt,' "$P/ALL.csv" && head -1 "$P/ALL.csv" | grep -q ',out_files,' && echo ok || echo "ref [$ref_writes] csv [$(grep WRITES "$P/ALL.csv" | cut -c1-80)]")"
python3 - "$P" <<'PY' || refuse "could not add SILENT's out_files cell"
import csv, sys
p = sys.argv[1] + "/ALL.csv"; rows = list(csv.reader(open(p)))
if "out_files" not in rows[0]: rows = [r[:11] + ([""] if k else ["out_files"]) + r[11:] for k, r in enumerate(rows)]
i = rows[0].index("out_files")
for r in rows[1:]:
    if r[1] == "SILENT": r[i] = "out.txt"
csv.writer(open(p, "w", newline=""), lineterminator="\n").writerows(rows)
PY
python3 - "$P" <<'PY' || refuse "could not give SILENT a ref"
import sys, re
p = sys.argv[1] + "/ALL.ref"; s = open(p).read()
s = re.sub(r"(\*-+ \d+ SILENT\n)silent\n", r"\1silent\nline one\nline two\n", s); open(p, "w").write(s)
PY
printf 'line one\nline two\n' > "$P/out.txt"
run() { ( cd "$ROOT" && python3 ../harness/scripts/corpus_suite_harness.py run "$P/ALL.sno" "$P/ALL.ref" --modes "$1" 2>&1 ) }
O3="$(run m3)"; O4="$(run m4)"
verdict() { printf '%s\n' "$1" | grep -E "^  (FAIL|CRASH|HANG) $2 $3:" > /dev/null && echo red || echo green; }
arm "m3: WRITES graded on stdout + out.txt PASS, NOFILE graded on stdout alone PASS" "$([ "$(verdict "$O3" m3 WRITES)" = green ] && [ "$(verdict "$O3" m3 NOFILE)" = green ] && printf '%s\n' "$O3" | grep -q 'm3_pass=2 ' && echo ok || echo "$(printf '%s\n' "$O3" | grep -E '^  FAIL|SUITE_BOARD' | cut -c1-160 | tr '\n' '|')")"
arm "m3 + m4: SILENT declares out.txt and never writes it -- FAIL with a staged copy beside it" "$([ "$(verdict "$O3" m3 SILENT)" = red ] && [ "$(verdict "$O4" m4 SILENT)" = red ] && echo ok || echo "m3 $(verdict "$O3" m3 SILENT) m4 $(verdict "$O4" m4 SILENT)")"
arm "m4: WRITES graded on stdout + out.txt PASS" "$([ "$(verdict "$O4" m4 WRITES)" = green ] && printf '%s\n' "$O4" | grep -q 'm4_pass=2 ' && echo ok || echo "$(printf '%s\n' "$O4" | grep -E '^  FAIL|SUITE_BOARD' | cut -c1-160 | tr '\n' '|')")"
bad=""; for cell in ../x /tmp/x; do
    python3 - "$P" "$cell" <<'PY'
import csv, sys
p = sys.argv[1] + "/ALL.csv"; rows = list(csv.reader(open(p)))
if "out_files" not in rows[0]: rows = [r[:11] + ([""] if k else ["out_files"]) + r[11:] for k, r in enumerate(rows)]
i = rows[0].index("out_files")
for r in rows[1:]:
    if r[1] == "NOFILE": r[i] = sys.argv[2]
csv.writer(open(p, "w", newline=""), lineterminator="\n").writerows(rows)
PY
    run m3 > /dev/null; rc=$?; [ "$rc" = 2 ] || bad="$bad $cell:rc=$rc"
done
arm "an out_files cell naming ../x or /tmp/x refuses rc=2" "$([ -z "$bad" ] && echo ok || echo "$bad")"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
