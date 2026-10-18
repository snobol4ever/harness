#!/usr/bin/env bash
# test_gate_package_contract_merges_stderr_and_a_rebuild_keeps_settings_rows.sh -- a package whose own harness cut its refs as
# `prog < in > out 2>&1` declares it once, in CONTRACT.tsv beside its sources (stderr<TAB>merged<TAB>evidence); the builder
# (util_build_package_suite.py) cuts every ref from stdout and stderr as one stream and writes the ALL.csv stderr cell
# "merged", and corpus_suite_harness.py grades that entry the same way in m3 and m4. A table without the column grades stdout
# alone, as before it existed. AND a rebuild keeps the settings row of every unit that is still shipped but not absorbed.
#
# WHY (the coo 2026-10-01, row icon-package-containers-regenerated-from-the-shipped-files-..., ceo CEO-1366/1392): the three
# Icon boards grade `> out 2>&1` (upstream's own harness, CEO-445) while the containers were cut from stdout alone, so a program
# whose answer is on stderr (jcon cxtrace, traceback, tracing) was excluded as "empty oracle output" and the area smoke graded
# the rest against a different contract than the board. And the containers' ALL.csv is ALSO the table each board reads a unit's
# heap_kb/stack_kb/compile_args from (RULES.md 8 (f), f8282e09c): a plain rebuild of jcon_tests wrote only the absorbed entries
# and dropped 11 rows the board looks up -- measured, util_icon_package_units.py missing read 11.
#
# THE ARMS (a scratch SNOBOL4 package, the oracle sbl -bf; TERMINAL writes stderr in both engines):
#   1  with CONTRACT.tsv stderr=merged, the builder's ref of E is 'out one|err two|out three' and ALL.csv's stderr cell is merged
#   2  m3 and m4 grade E PASS
#   3  the same ref with E's stderr cell blanked reads FAIL in m3 -- the column, not the ref, is what admits stderr
#   4  a stderr cell 'both' refuses rc=2 at read time
#   5  a CONTRACT.tsv row the builder does not admit (stderr=split) refuses rc=2, and so does a row with no evidence
#   6  a rebuild keeps Q's row (shipped, prints nothing, so not absorbed) with its declared heap_kb and blank features, and drops
#      GONE's row (no GONE.sno is shipped)
# AND A SCRATCH ICON PACKAGE (CONTRACT.tsv stderr=merged, units=ref-beside; the oracle icont/iconx, two-step as upstream's harness):
#   7  the builder's refs: T (a run-time error) is iconx's merged report with its traceback; W (an undeclared identifier) is its
#      output alone, no translator warning (the one-step icon driver prints one, 17 of 78 jcon refs); L, which links M shipped
#      beside it, is excluded by the oracle's translator (icont cannot resolve M.u1) and M, which has no M.ref, by units; O,
#      which links the IPL's options with an options.icn shipped beside it, is ABSORBED (icont links ucode, never the sibling
#      .icn: Arizona's shape, 31 programs a sibling-name rule wrongly excluded)
#   8  m3 and m4 grade T and W PASS -- T through the Icon equivalence list, as test_icon_jcon_suite.sh renders its capture
#   9  with the render off (S4E_FATAL_RENDER=0) T reads FAIL in m3 -- the render, not a loose ref, is what passes it
#  10  C, which loads C through a C.clib sidecar, is excluded and named (its board builds the library and sets FPATH)
#  11  sub/K's K.mask travels into ALL.mask under the entry's name (sub/K<TAB>L1), the line that prints &clock
#  12  m3 and m4 grade the nested sub/R PASS -- its R.dat lands beside it where it runs (it was copied to the scratch root and
#      looked up in the package root, so open("R.dat") failed) -- and sub/K PASS through its mask
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
NAME=package_contract_merges_stderr_and_a_rebuild_keeps_settings_rows
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$ROOT/scrip" ] || refuse "no scrip binary -- cannot measure"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "no out/libscrip_rt.so -- cannot measure mode 4"
[ -x /home/resources/x64/bin/sbl ] || refuse "no sbl oracle -- the builder cannot cut a ref"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
P="$T/pkg"; mkdir -p "$P"
printf '%s\n' "        OUTPUT = 'out one'" "        TERMINAL = 'err two'" "        OUTPUT = 'out three'" END > "$P/E.sno"
printf '%s\n' "        OUTPUT = 'plain'" END > "$P/PLAIN.sno"
printf '%s\n' "        X = 1" END > "$P/Q.sno"
printf '%s\n' "# CONTRACT.tsv (gate fixture)" "stderr	merged	the fixture's own harness cuts > out 2>&1" > "$P/CONTRACT.tsv"
build() { ( cd "$ROOT" && python3 ../harness/scripts/util_build_package_suite.py "$P" > "$T/build.log" 2>&1 ); }
build || refuse "the builder did not build the scratch package: $(tail -3 "$T/build.log" | tr '\n' '|')"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
ref_e="$(awk '/ E$/{f=1;next} /^\*-+ [0-9]+ /{f=0} f' "$P/ALL.ref" | tr '\n' '|')"
cell_e="$(python3 -c 'import csv,sys; print(next((r.get("stderr","<none>") for r in csv.DictReader(open(sys.argv[1])) if r["entry"]=="E"), "<no row>"))' "$P/ALL.csv")"
arm "the builder cuts E's ref from both streams and ALL.csv says merged" "$([ "$ref_e" = 'out one|err two|out three|' ] && [ "$cell_e" = merged ] && echo ok || echo "ref [$ref_e] cell [$cell_e]")"
run() { ( cd "$ROOT" && python3 ../harness/scripts/corpus_suite_harness.py run "$P/ALL.sno" "$P/ALL.ref" --modes "$1" 2>&1 ) }
verdict() { printf '%s\n' "$1" | grep -E "^  (FAIL|CRASH|HANG) $2 $3:" > /dev/null && echo red || echo green; }
O3="$(S4E_PROGRESS_OFF=1 run m3)"; O4="$(S4E_PROGRESS_OFF=1 run m4)"
arm "m3 and m4 grade E PASS on the merged stream" "$([ "$(verdict "$O3" m3 E)" = green ] && [ "$(verdict "$O4" m4 E)" = green ] && printf '%s\n' "$O3" | grep -q 'm3_pass=2 ' && printf '%s\n' "$O4" | grep -q 'm4_pass=2 ' && echo ok || echo "$(printf '%s\n%s\n' "$O3" "$O4" | grep -E '^  FAIL|SUITE_BOARD' | cut -c1-160 | tr '\n' '|')")"
setcell() {  # setcell <entry> <stderr value>
python3 - "$P/ALL.csv" "$1" "$2" <<'PY'
import csv, sys
p, e, v = sys.argv[1:4]; rows = list(csv.reader(open(p))); i = rows[0].index("stderr")
for r in rows[1:]:
    if r[1] == e: r[i] = v
csv.writer(open(p, "w", newline=""), lineterminator="\n").writerows(rows)
PY
}
setcell E ""; O3b="$(S4E_PROGRESS_OFF=1 run m3)"
arm "E's stderr cell blanked: stdout alone reads FAIL against the merged ref" "$([ "$(verdict "$O3b" m3 E)" = red ] && echo ok || echo "m3 read $(verdict "$O3b" m3 E)")"
setcell E both; S4E_PROGRESS_OFF=1 run m3 > /dev/null; rc=$?
arm "a stderr cell 'both' refuses rc=2" "$([ "$rc" = 2 ] && echo ok || echo "rc=$rc")"
setcell E merged
bad=""
for row in "stderr	split	a fixture" "stderr	merged"; do
    cp "$P/CONTRACT.tsv" "$T/contract.keep"; printf '%s\n' "$row" >> "$P/CONTRACT.tsv"
    build; rc=$?; [ "$rc" = 2 ] || bad="$bad [$(printf '%s' "$row" | tr '\t' ' ')]:rc=$rc"
    cp "$T/contract.keep" "$P/CONTRACT.tsv"
done
arm "a CONTRACT.tsv row the builder does not admit, or one with no evidence, refuses rc=2" "$([ -z "$bad" ] && echo ok || echo "$bad")"
build || refuse "the builder did not rebuild the scratch package: $(tail -3 "$T/build.log" | tr '\n' '|')"
python3 - "$P/ALL.csv" <<'PY' || refuse "could not plant the settings rows"
import csv, sys
p = sys.argv[1]; rows = list(csv.reader(open(p))); h = rows[0]
for name in ("Q", "GONE"):
    r = [""] * len(h); r[0] = str(len(rows)); r[1] = name; r[2] = "pkg__" + name; r[3] = "pkg"; r[h.index("heap_kb")] = "262144"
    rows.append(r)
csv.writer(open(p, "w", newline=""), lineterminator="\n").writerows(rows)
PY
build || refuse "the builder did not rebuild after the planted rows: $(tail -3 "$T/build.log" | tr '\n' '|')"
kept="$(python3 - "$P/ALL.csv" <<'PY'
import csv, sys
rows = list(csv.DictReader(open(sys.argv[1]))); by = {r["entry"]: r for r in rows}
feat = [c for c in rows[0] if c not in ("rank", "entry", "origin", "package", "n_lines", "stdin", "want_rc", "heap_kb", "stack_kb", "compile_args", "run_args", "out_files", "stderr")]
q = by.get("Q")
print("Q=%s heap=%s feats=%s GONE=%s" % ("row" if q else "none", q and q["heap_kb"], q and ("blank" if all(not q[c] for c in feat) else "set"), "row" if "GONE" in by else "none"))
PY
)"
arm "a rebuild keeps Q's settings row (heap_kb 262144, no feature marked) and drops GONE's" "$([ "$kept" = "Q=row heap=262144 feats=blank GONE=none" ] && echo ok || echo "$kept")"
# ---- the Icon package -------------------------------------------------------------------------------------------------
LIB="$HERE/lib_oracle_flags.sh"
( . "$LIB" && icont_bin && iconx_bin ) > /dev/null 2>&1 || refuse "no icont/iconx oracle (lib_oracle_flags.sh) -- the builder cannot cut an Icon ref"
I="$T/ipkg"; mkdir -p "$I"
printf '%s\n' 'procedure main();' '   write("before");' '   foo(2);' 'end' 'procedure foo(n);' '   if n = 0 then return 1 / n;' '   return foo(n - 1);' 'end' > "$I/T.icn"
printf '%s\n' 'procedure main();' '   x := 3;' '   write("x=", x);' 'end' > "$I/W.icn"
printf '%s\n' 'link M' 'procedure main();' '   write(m());' 'end' > "$I/L.icn"
printf '%s\n' 'procedure m();' '   return "from M";' 'end' > "$I/M.icn"
printf '%s\n' 'link options' 'procedure main();' '   write("ok");' 'end' > "$I/O.icn"; printf 'ok\n' > "$I/O.ref"
printf '%s\n' 'procedure options();' 'end' > "$I/options.icn"
mkdir -p "$I/sub"
printf '%s\n' 'procedure main();' '   local f;' '   f := open("R.dat") | stop("no R.dat");' '   write(read(f));' 'end' > "$I/sub/R.icn"
printf 'a data line\n' > "$I/sub/R.dat"; printf 'a data line\n' > "$I/sub/R.ref"
printf '%s\n' 'procedure main();' '   write(&clock);' '   write("fixed one");' '   write("fixed two");' '   write("fixed three");' 'end' > "$I/sub/K.icn"
printf '00:00:00\nfixed one\nfixed two\nfixed three\n' > "$I/sub/K.ref"; printf 'K\tL1\tthe clock moves (gate fixture)\n' > "$I/sub/K.mask"
printf '%s\n' 'procedure main();' '   write("c");' 'end' > "$I/C.icn"; printf 'c\n' > "$I/C.ref"; printf 'c.c\n' > "$I/C.clib"
printf '%s\n' 'before' '' 'Run-time error 201' 'File T.icn; Line 6' 'division by zero' 'Traceback:' 'main()' 'foo(2) from line 3 in T.icn' \
    'foo(1) from line 7 in T.icn' 'foo(0) from line 7 in T.icn' '{1 / 0} from line 6 in T.icn' > "$I/T.ref"
printf 'x=3\n' > "$I/W.ref"; printf 'from M\n' > "$I/L.ref"
printf '%s\n' "stderr	merged	the fixture's own harness runs ./prog <in >out 2>&1" "units	ref-beside	the fixture grades a source with a .ref beside it" > "$I/CONTRACT.tsv"
( cd "$ROOT" && python3 ../harness/scripts/util_build_package_suite.py "$I" --lang icon > "$T/ibuild.log" 2>&1 ) || refuse "the builder did not build the scratch Icon package: $(tail -3 "$T/ibuild.log" | tr '\n' '|')"
iref() { awk -v e="$1" '$0 ~ "^#-+ [0-9]+ "e"$" {f=1; next} /^#-+ [0-9]+ /{f=0} f' "$I/ALL.ref"; }
ex_l="$(grep -c "^L: the oracle's translator refused it: icont: cannot resolve reference to file 'M.u1'" "$I/ALL.excluded.txt" 2>/dev/null)"; ex_m="$(grep -c '^M: no M.ref beside it' "$I/ALL.excluded.txt" 2>/dev/null)"
arm "the Icon refs: T is iconx's merged report, W carries no translator warning, O (links the IPL beside a sibling) absorbed, L (local link, the translator) and M (no ref) excluded" "$([ "$(iref T)" = "$(cat "$I/T.ref")" ] && [ "$(iref W)" = 'x=3' ] && [ "$(iref O)" = 'ok' ] && [ "$ex_l" = 1 ] && [ "$ex_m" = 1 ] && echo ok || echo "T [$(iref T | tr '\n' '|')] W [$(iref W | tr '\n' '|')] O [$(iref O | tr '\n' '|')] L-excluded=$ex_l M-excluded=$ex_m")"
# O links the IPL's options: SCRIP finds the IPL beside its own binary (../corpus/packages/icon/ipl/procs), which a scratch worktree
# does not have, so the fixture names it on IPATH from the seat root -- the same library either way.
IPL_PROCS="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}/corpus/packages/icon/ipl/procs"
[ -f "$IPL_PROCS/options.icn" ] || refuse "no IPL options.icn at $IPL_PROCS -- O cannot link"
irun() { ( cd "$ROOT" && IPATH="$IPL_PROCS" python3 ../harness/scripts/corpus_suite_harness.py run "$I/ALL.icn" "$I/ALL.ref" --lang icon --modes "$1" 2>&1 ) }
I3="$(S4E_PROGRESS_OFF=1 irun m3)"; I4="$(S4E_PROGRESS_OFF=1 irun m4)"
arm "m3 and m4 grade T (through the Icon equivalence list), W and O PASS" "$(ok=1; for e in T W O; do [ "$(verdict "$I3" m3 $e)" = green ] && [ "$(verdict "$I4" m4 $e)" = green ] || ok=0; done; [ $ok = 1 ] && printf '%s\n' "$I3" | grep -q 'm3_pass=5 ' && printf '%s\n' "$I4" | grep -q 'm4_pass=5 ' && echo ok || echo "$(printf '%s\n%s\n' "$I3" "$I4" | grep -E '^  FAIL|SUITE_BOARD' | cut -c1-160 | tr '\n' '|')")"
I3b="$(S4E_PROGRESS_OFF=1 S4E_FATAL_RENDER=0 irun m3)"
arm "with the render off, T reads FAIL in m3" "$([ "$(verdict "$I3b" m3 T)" = red ] && echo ok || echo "m3 read $(verdict "$I3b" m3 T)")"
arm "C (a C.clib sidecar) is excluded and named" "$(grep -q '^C: loads C through C.clib' "$I/ALL.excluded.txt" 2>/dev/null && echo ok || echo "ALL.excluded.txt: $(grep '^C:' "$I/ALL.excluded.txt" 2>/dev/null | cut -c1-120)")"
arm "sub/K's K.mask is in ALL.mask under its entry name" "$(grep -qP '^sub/K\tL1\t' "$I/ALL.mask" 2>/dev/null && echo ok || echo "ALL.mask: $(head -5 "$I/ALL.mask" 2>/dev/null | tr '\n' '|' | cut -c1-160)")"
arm "m3 and m4 grade the nested sub/R (its R.dat beside it) and sub/K (masked) PASS" "$([ "$(verdict "$I3" m3 sub/R)" = green ] && [ "$(verdict "$I4" m4 sub/R)" = green ] && [ "$(verdict "$I3" m3 sub/K)" = green ] && [ "$(verdict "$I4" m4 sub/K)" = green ] && echo ok || echo "$(printf '%s\n%s\n' "$I3" "$I4" | grep -E '^  (FAIL|CRASH|HANG) m[34] sub/' | cut -c1-140 | tr '\n' '|')")"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
