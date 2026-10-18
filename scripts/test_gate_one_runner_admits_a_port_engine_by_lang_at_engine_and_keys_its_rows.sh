#!/bin/bash
# test_gate_one_runner_admits_a_port_engine_by_lang_at_engine_and_keys_its_rows.sh -- THE ENGINE IS A RUNNER SETTING (Lon 2026-10-17 to
# hq_dotnet: "The suite banner should represent the snobol4dotnet executable program, not SCRIP." and, asked who runs the SNOBOL4 suites on
# the snobol4dotnet engine, "hq_dotnet runs them"; ceo CEO-1822). Hermetic, no build: a scratch MODE whose LANES line carries
# snobol4@dotnet=hq_dotnet, and a staged root in the real shape -- a COPY of this folder at <root>/harness/scripts, a stub engine tree at
# <root>/snobol4dotnet, a plain-copy two-entry rungs suite at <root>/corpus (no checkout, so the guard judges it a board and the lane
# decides) -- with a stub dotnet host that prints nothing (both entries' refs are empty) and scratch progress tables. Nothing live is read or
# written. ARMS: (1) lib_one_runner.sh one_runner_who looks up <lang>@<engine> under a port engine -- snobol4 under dotnet is hq_dotnet,
# under scrip the coo; "all" stays the bare keys; another language and an unknown engine name no lane. (2) corpus_suite_harness.py run
# under S4E_ENGINE=dotnet as hq_dotnet is ADMITTED, dispatched to run_snobol4dotnet.sh, and every row it writes is keyed
# snobol4-rungs@dotnet, none snobol4-rungs. (3) as hq_dotnet without the engine it is REFUSED rc 2 (ONE SEAT, ONE LANGUAGE). (4) as the coo
# with the engine it is REFUSED rc 2 by the lane. (5) an unknown engine REFUSES rc 2. (6) m4 under dotnet REFUSES rc 2. (7) the runner's
# --binaries is the board's one check: a language the engine has no front end for, and a build older than its source, refuse the board
# rc 2 before any entry. (8) THE UNSET PATH IS SCRIP'S, UNCHANGED (the coo's ask): with no S4E_ENGINE the lane is the coo's and the key is
# the bare snobol4-rungs, and from-progress for the bare sno-rungs key reads none of the @dotnet rows. (9) THE jvm ARM, the same law for the
# second port (hq_jvm; Lon 2026-10-17 to hq_jvm: "The suite banner should represent the snobol4jvm program, not SCRIP."): snobol4 under jvm
# is hq_jvm's lane; hq_jvm under S4E_ENGINE=jvm is admitted, dispatched to run_snobol4jvm.sh (a stub java host over a stub uberjar), keys
# every row snobol4-rungs@jvm and names the jar as its binary; hq_dotnet under jvm is refused; snocone under jvm and a jar older than the
# snobol4jvm source each refuse the board rc 2 before any entry; with that source still newer, both fingerprints name the jar (--paths).
set -u
unset S4E_DONE_WHEN_RUN S4E_ONE_RUNNER_OVERRIDE S4E_ONE_RUNNER_FIXTURE S4E_SEAT S4E_ENGINE S4E_BIN_AT_START S4E_CORPUS_ROOT
H="$(cd "$(dirname "$0")" && pwd)"; L="$H/lib_one_runner.sh"; G=one_runner_admits_a_port_engine; fail=0; examined=0
[ -r "$L" ] && [ -r "$H/corpus_suite_harness.py" ] && [ -r "$H/run_snobol4dotnet.sh" ] && [ -r "$H/run_snobol4jvm.sh" ] || { echo "REFUSE(2) [$G]: the guard, the harness, run_snobol4dotnet.sh or run_snobol4jvm.sh is missing beside this gate -- cannot measure"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
arm() { examined=$((examined+1)); if eval "$2"; then echo "  ok   $1"; else echo "  FAIL $1"; fail=$((fail+1)); fi; }

# the scratch law: SCRIP's bare lanes beside the port lanes (snocone@dotnet exists only so arm 7a reaches the runner's own refusal)
mkdir -p "$T/post"; printf 'TENET\n# scratch MODE for %s\nLANES: snobol4=coo icon=coo snocone=coo snobol4@dotnet=hq_dotnet snocone@dotnet=hq_dotnet snobol4@jvm=hq_jvm snocone@jvm=hq_jvm\n' "$G" > "$T/post/MODE"
# sourced, never named as $0: the library runs its own CLI (and prints its usage) when BASH_SOURCE[0] is $0
who() { S4E_POST="$T/post" S4E_ENGINE="$1" WHO_LIB="$L" WHO_LANG="$2" bash -c '. "$WHO_LIB"; one_runner_who "$WHO_LANG"'; }
arm "1a snobol4 under dotnet is hq_dotnet's lane"        '[ "$(who dotnet snobol4)" = hq_dotnet ]'
arm "1b snobol4 under scrip is still the coo's lane"     '[ "$(who scrip snobol4)" = coo ]'
arm "1c all under dotnet is the bare keys only"          '[ "$(who dotnet all)" = coo ]'
arm "1d icon under dotnet names no lane"                 '[ -z "$(who dotnet icon)" ]'
arm "1e an unknown engine names no lane"                 '[ -z "$(who nope snobol4)" ]'

# the staged root, in the real shape and of real files: harness copied, a stub engine built after its one source, a plain-copy suite
R="$T/root"; B="$R/snobol4dotnet/Snobol4/bin/Release/net10.0"
mkdir -p "$R/harness/scripts" "$R/corpus/tests/snobol4" "$R/corpus/tests/snocone" "$R/corpus/include" "$R/snobol4dotnet/Snobol4.Common" "$B" "$T/bin" "$R/.github"
cp -r "$H/." "$R/harness/scripts/"
: > "$R/.github/SCORE.md"   # util_score_row.py asks only that the leaderboard exists; a dry run reads and writes none of it
printf 'class Stub {}\n' > "$R/snobol4dotnet/Snobol4.Common/Stub.cs"; touch -d '2 minutes ago' "$R/snobol4dotnet/Snobol4.Common/Stub.cs"
printf 'stub driver\n' > "$B/Snobol4.dll"; printf 'stub engine\n' > "$B/Snobol4.Common.dll"
printf '#!/bin/sh\nexit 0\n' > "$T/bin/dotnet"; chmod +x "$T/bin/dotnet"
for d in snobol4 snocone; do
    printf " X = 1;END;* gate_engine_e1\n Y = 2;END;* gate_engine_e2\n" > "$R/corpus/tests/$d/ALL.sno"; printf "\n\n" > "$R/corpus/tests/$d/ALL.ref"
done
printf 'rank,entry\n1,gate_engine_e1\n2,gate_engine_e2\n' > "$R/corpus/tests/snobol4/ALL.csv"
run() {  # run <seat> <engine> <db> [modes] [lang-dir]: the staged harness over a staged suite; prints its rc
    env PATH="$T/bin:$PATH" S4E_POST="$T/post" S4E_HOME="$R" S4E_SEAT="$1" ${2:+S4E_ENGINE="$2"} S4E_PROGRESS_DB="$3" \
        python3 "$R/harness/scripts/corpus_suite_harness.py" run "$R/corpus/tests/${5:-snobol4}/ALL.sno" "$R/corpus/tests/${5:-snobol4}/ALL.ref" \
        --modes "${4:-m3}" > "$T/out" 2>&1
    echo $?
}
rows() { [ -f "$1" ] && awk -F'\t' -v s="$2" 'NR>1 && $6==s' "$1" | wc -l || echo 0; }

rc="$(run hq_dotnet dotnet "$T/admitted.tsv")"
arm "2a hq_dotnet under dotnet is admitted and graded (rc $rc)"       '[ "$rc" = 0 ]'
arm "2b its rows are keyed snobol4-rungs@dotnet (2 of 2)"             '[ "$(rows "$T/admitted.tsv" snobol4-rungs@dotnet)" -eq 2 ]'
arm "2c none of its rows lands in SCRIP's snobol4-rungs"              '[ "$(rows "$T/admitted.tsv" snobol4-rungs)" -eq 0 ]'
arm "2d the board names the runner's files as its binary"             'grep -q "md5/12 of Snobol4.dll, Snobol4.Common.dll; engine dotnet" "$T/out"'
rc="$(run hq_dotnet "" "$T/bare.tsv")"
arm "3 hq_dotnet without the engine is refused rc 2 (got $rc)"        '[ "$rc" = 2 ] && grep -q "ONE SEAT, ONE LANGUAGE" "$T/out"'
rc="$(run coo dotnet "$T/coo.tsv")"
arm "4 the coo under dotnet is refused rc 2 by the lane (got $rc)"    '[ "$rc" = 2 ] && grep -q "ONE RUNNER PER LANGUAGE" "$T/out" && [ "$(rows "$T/coo.tsv" snobol4-rungs@dotnet)" -eq 0 ]'
rc="$(run hq_dotnet nope "$T/nope.tsv")"
arm "5 an unknown engine refuses rc 2 (got $rc)"                      '[ "$rc" = 2 ] && grep -q "names no engine" "$T/out"'
rc="$(run hq_dotnet dotnet "$T/m4.tsv" m3,m4)"
arm "6 m4 under dotnet refuses rc 2 (got $rc)"                        '[ "$rc" = 2 ] && grep -q "has none" "$T/out"'
rc="$(run hq_dotnet dotnet "$T/snc.tsv" m3 snocone)"
arm "7a a language with no front end refuses the board rc 2 (got $rc)" '[ "$rc" = 2 ] && grep -q "NO ENGINE for snocone" "$T/out" && [ ! -s "$T/snc.tsv" ]'
touch "$R/snobol4dotnet/Snobol4.Common/Stub.cs"
rc="$(run hq_dotnet dotnet "$T/stale.tsv")"
arm "7b a build older than its source refuses the board rc 2 (got $rc)" '[ "$rc" = 2 ] && grep -q "build is older than" "$T/out" && [ ! -s "$T/stale.tsv" ]'
# a source edited UNDER a running board is not a moved binary: the fingerprint still names both files (measured: end [] refused a board)
fpy="$(S4E_ENGINE=dotnet python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import util_progress_append as u; print(u.bin_fingerprint())' "$R/harness/scripts" 2>&1)"
fsh="$(S4E_ENGINE=dotnet FP_LIB="$R/harness/scripts/lib_one_runner.sh" bash -c '. "$FP_LIB"; one_runner_bin_fingerprint')"
arm "7c with the source newer than the build, both fingerprints still name both files" '[ "$(echo $fpy | wc -w)" = 2 ] && [ "$(echo $fsh | wc -w)" = 2 ] && [ "$(echo $fpy)" = "$(echo $fsh)" ]'

# the runner passes the harness's include path (SNO_LIB, SCRIP's name) to the engine as SNOLIB, SPITBOL's, ahead of any SNOLIB already set
mkdir -p "$T/snolib_bin"; printf '#!/bin/sh\nprintf "%%s" "$SNOLIB"\n' > "$T/snolib_bin/dotnet"; chmod +x "$T/snolib_bin/dotnet"
got7d="$(cd "$R/corpus/tests/snobol4" && env PATH="$T/snolib_bin:$PATH" SNO_LIB=/shared/include SNOLIB=/seat/lib bash "$R/harness/scripts/run_snobol4dotnet.sh" ALL.sno)"
arm "7d the runner hands SNO_LIB to the engine as SNOLIB, first (got $got7d)" '[ "$got7d" = "/shared/include:/seat/lib" ]'

# the declared heap reaches the engine as its GC hard limit (SPITBOL's -d is a cap), floored at 32 MB so the runtime can start
printf '#!/bin/sh\nprintf "%%s" "$DOTNET_GCHeapHardLimit"\n' > "$T/snolib_bin/dotnet"
got7e="$(cd "$R/corpus/tests/snobol4" && env -u DOTNET_GCHeapHardLimit PATH="$T/snolib_bin:$PATH" bash "$R/harness/scripts/run_snobol4dotnet.sh" -d131072k -s4096k ALL.sno)"
got7f="$(cd "$R/corpus/tests/snobol4" && env -u DOTNET_GCHeapHardLimit PATH="$T/snolib_bin:$PATH" bash "$R/harness/scripts/run_snobol4dotnet.sh" -d64k ALL.sno)"
arm "7e -d131072k reaches the engine as a 128 MB GC hard limit (got $got7e)" '[ "$got7e" = 0x8000000 ]'
arm "7f a tiny -d is floored at 32 MB so the runtime starts (got $got7f)" '[ "$got7f" = 0x2000000 ]'

# the unset path, which the coo's loop takes for every board: SCRIP's lane and SCRIP's bare key, unchanged
probe() { env -u S4E_ENGINE S4E_POST="$T/post" S4E_HOME="$R" python3 -c '
import sys; sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h
p = h.resolve_paths(); print(p["engine"], ",".join(h._one_runner_who("snobol4")), h.progress_suite_for(sys.argv[2], p)[1])' "$R/harness/scripts" "$R/corpus/tests/snobol4/ALL.sno" 2>&1; }
arm "8a no S4E_ENGINE is scrip, the coo's lane and the bare key"      '[ "$(probe)" = "scrip coo snobol4-rungs" ]'
assemble() { env -u S4E_ENGINE S4E_PROGRESS_DB="$1" python3 "$R/harness/scripts/util_score_row.py" from-progress --suite sno-rungs --dry-run 2>&1 | grep -m1 '^SUITE_ROW '; }
arm "8b the bare sno-rungs assembly reads none of the @dotnet rows"   'assemble "$T/admitted.tsv" | grep -q " read=0 unread=2 "'
sed 's/\tsnobol4-rungs@dotnet\t/\tsnobol4-rungs\t/' "$T/admitted.tsv" > "$T/bare_control.tsv"
arm "8c CONTROL: the same rows under the bare key are read (2 of 2)"  'assemble "$T/bare_control.tsv" | grep -q " read=2 unread=0 "'
# THE FIRST PUBLISH OPENS THE PORT ROW (ceo CEO-1822): from-progress --suite sno-rungs@dotnet over a table that holds only SCRIP's bare row
# opens sno-rungs@dotnet through util_suite_banner.py --open (the bare row's nick, emoji, lang) and fills it; a second publish adds no row
B="$H/../../.github/scripts/util_suite_banner.py"
[ -r "$B" ] || { echo "REFUSE(2) [$G]: no util_suite_banner.py at $B beside this harness -- the first-publish arms cannot be measured"; exit 2; }
mkdir -p "$R/.github/scripts"; cp "$B" "$R/.github/scripts/"
printf 'key\tnick\temoji\tlang\tfirst_date\tfirst_pass\tfirst_total\ttoday_date\ttoday_pass\ttoday_total\ttree\tcriterion_changed\ttoday_excluded\ttoday_secs\ttoday_void\n' > "$T/SUITES.tsv"
printf 'sno-rungs\tSnoRungs\tx\tsnobol4\t2026-09-01\t1\t2\t2026-09-01\t2\t2\tabc123\t\t0\t\t\n' >> "$T/SUITES.tsv"
cp "$T/SUITES.tsv" "$T/SUITES.before"
publish() { env -u S4E_ENGINE S4E_SUITES_TSV="$T/SUITES.tsv" S4E_PROGRESS_DB="$T/admitted.tsv" S4E_POST="$T/post" S4E_SEAT=hq_dotnet \
    python3 "$R/harness/scripts/util_score_row.py" from-progress --suite sno-rungs@dotnet > "$T/pub" 2>&1; echo $?; }
rc="$(publish)"
arm "8d the first publish opens sno-rungs@dotnet and fills it 2/2 (rc $rc)" '[ "$rc" = 0 ] && awk -F"\t" "\$1==\"sno-rungs@dotnet\" && \$2==\"SnoRungs\" && \$4==\"snobol4\" && \$9==2 && \$10==2" "$T/SUITES.tsv" | grep -q . && grep -q "sno-rungs@dotnet" "$T/SUITES.history.tsv"'
rc="$(publish)"
arm "8e a second publish opens no second row, and SCRIP's bare row is untouched" '[ "$rc" = 0 ] && [ "$(grep -c "^sno-rungs@dotnet	" "$T/SUITES.tsv")" = 1 ] && [ "$(grep "^sno-rungs	" "$T/SUITES.tsv")" = "$(grep "^sno-rungs	" "$T/SUITES.before")" ]'

# the jvm arm: a stub snobol4jvm tree whose jar is built after its source, and a stub java host that prints nothing
JS="$R/snobol4jvm"; mkdir -p "$JS/src/SNOBOL4clojure" "$JS/target/uberjar"
printf '(ns SNOBOL4clojure.core)\n' > "$JS/src/SNOBOL4clojure/core.clj"; printf '(defproject stub "0")\n' > "$JS/project.clj"
touch -d '2 minutes ago' "$JS/src/SNOBOL4clojure/core.clj" "$JS/project.clj"
printf 'stub jar\n' > "$JS/target/uberjar/SNOBOL4clojure-0.2.0-standalone.jar"
printf '#!/bin/sh\nexit 0\n' > "$T/bin/java"; chmod +x "$T/bin/java"
arm "9a snobol4 under jvm is hq_jvm's lane"                            '[ "$(who jvm snobol4)" = hq_jvm ]'
rc="$(run hq_jvm jvm "$T/jvm.tsv")"
arm "9b hq_jvm under jvm is admitted, its rows keyed snobol4-rungs@jvm (rc $rc)" '[ "$rc" = 0 ] && [ "$(rows "$T/jvm.tsv" snobol4-rungs@jvm)" -eq 2 ] && [ "$(rows "$T/jvm.tsv" snobol4-rungs)" -eq 0 ]'
arm "9c the board names the jar as its binary"                          'grep -q "md5/12 of SNOBOL4clojure-0.2.0-standalone.jar; engine jvm" "$T/out"'
rc="$(run hq_dotnet jvm "$T/jvm_dotnet.tsv")"
arm "9d hq_dotnet under jvm is refused rc 2 (got $rc)"                  '[ "$rc" = 2 ] && [ "$(rows "$T/jvm_dotnet.tsv" snobol4-rungs@jvm)" -eq 0 ]'
rc="$(run hq_jvm jvm "$T/jvm_snc.tsv" m3 snocone)"
arm "9e snocone under jvm refuses the board rc 2 (got $rc)"             '[ "$rc" = 2 ] && grep -q "NO ENGINE for snocone" "$T/out" && [ ! -s "$T/jvm_snc.tsv" ]'
touch "$JS/src/SNOBOL4clojure/core.clj"
rc="$(run hq_jvm jvm "$T/jvm_stale.tsv")"
arm "9f a jar older than its source refuses the board rc 2 (got $rc)"   '[ "$rc" = 2 ] && grep -q "jar .* is older than" "$T/out" && [ ! -s "$T/jvm_stale.tsv" ]'
# 7c's twin: with the source still newer than the jar, run_snobol4jvm.sh --paths names it, so a board's end fingerprint is not "moved"
jpy="$(S4E_ENGINE=jvm python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import util_progress_append as u; print(u.bin_fingerprint())' "$R/harness/scripts" 2>&1)"
jsh="$(S4E_ENGINE=jvm FP_LIB="$R/harness/scripts/lib_one_runner.sh" bash -c '. "$FP_LIB"; one_runner_bin_fingerprint')"
arm "9g with the source newer than the jar, both fingerprints still name the jar" '[ "$(echo $jpy | wc -w)" = 1 ] && [ "$(echo $jsh | wc -w)" = 1 ] && [ "$(echo $jpy)" = "$(echo $jsh)" ]'

# THE PACKAGE RUNNERS TAKE THE PORT (Lon 2026-10-18 to hq_jvm: "Get all SNOBOL4 test suite package runners working with snobol4jvm."): each of
# hq_jvm's four grades a plain copy of its package in the staged root with its own grading, under the stub java (which prints nothing, so every
# graded program is red) and the live sbl oracle: m3 alone, every row keyed <suite>@jvm, no m4 row, the face exec'd (no rc=126, cannot
# execute), no SCRIP row written but its from-progress line printed (and the engine, never SCRIP, on a bash-graded board line), and <key>@jvm
# published by the runner itself through one_runner_port_publish beside the bare row it leaves untouched -- and nothing published under
# S4E_SCORE_NO_WRITE. Unset, the same runner takes SCRIP's path and refuses rc 2 for want of a scrip binary in the staged root.
arm "10a the face is executable, as the runners exec it"               '[ -x "$H/run_port_as_scrip.sh" ]'
touch "$JS/target/uberjar/SNOBOL4clojure-0.2.0-standalone.jar"   # 9f left the stub source newer than the jar
mkdir -p "$R/corpus/packages/snobol4"; cp "$T/SUITES.before" "$T/SUITES.pkg.tsv"
PKGS="aisnobol:aisnobol:aisnobol:AISNOBOL_BOARD:test_snobol4_aisnobol_suite.sh spitbol_testpgms:testpgms:testpgms:SPITBOL_TESTPGMS_BOARD:test_snobol4_spitbol_testpgms_suite.sh
      spitbol_x64_tests:spitbol_x64:x64tests:SPITBOL_X64_BOARD:test_snobol4_spitbol_x64_suite.sh spitbol_x32_tests:spitbol_x32:x32tests:SPITBOL_X32_BOARD:test_snobol4_spitbol_x32_suite.sh"   # package:progress suite:SUITES key:board line:runner
for p in $PKGS; do
    IFS=: read -r pkg _ key _ _ <<< "$p"
    cp -r "$H/../../corpus/packages/snobol4/$pkg" "$R/corpus/packages/snobol4/" || { echo "REFUSE(2) [$G]: no corpus/packages/snobol4/$pkg beside this harness -- the package arms cannot be measured"; exit 2; }
    printf '%s\t%s\tx\tsnobol4\t2026-09-01\t1\t2\t2026-09-01\t1\t2\tabc123\t\t0\t\t\n' "$key" "$key" >> "$T/SUITES.pkg.tsv"
done
cp "$T/SUITES.pkg.tsv" "$T/SUITES.pkg.before"
pkgrun() {  # pkgrun <runner> <db> [engine]: one package runner over its staged package; prints its rc
    env PATH="$T/bin:$PATH" S4E_POST="$T/post" S4E_HOME="$R" S4E_SEAT=hq_jvm ${3:+S4E_ENGINE="$3"} S4E_PROGRESS_DB="$2" S4E_SUITES_TSV="$T/SUITES.pkg.tsv" \
        TIMEOUT=20 bash "$R/harness/scripts/$1" > "$T/out" 2>&1
    echo $?
}
mode_rows() { awk -F'\t' -v m="$2" 'NR>1 && $9==m' "$1" | wc -l; }
for p in $PKGS; do
    IFS=: read -r pkg db key bl r <<< "$p"
    find "$R/corpus/packages/snobol4/$pkg" -type f | LC_ALL=C sort > "$T/pkg.before"
    rc="$(pkgrun "$r" "$T/pkg_$key.tsv" jvm)"; cp "$T/out" "$T/out_$key"
    find "$R/corpus/packages/snobol4/$pkg" -type f | LC_ALL=C sort > "$T/pkg_files_$key"
    arm "10-$key under jvm grades m3 alone, keyed $db@jvm, no m4 row or count, no rc=126 (rc $rc)" \
        'grep -iqE "^$bl .*m4_pass=0 m4_fail=0" "$T/out_$key" && [ "$rc" = 1 ] && [ "$(rows "$T/pkg_$key.tsv" "$db@jvm")" -ge 1 ] && [ "$(rows "$T/pkg_$key.tsv" "$db@jvm")" = "$(mode_rows "$T/pkg_$key.tsv" m3)" ] && [ "$(mode_rows "$T/pkg_$key.tsv" m4)" = 0 ] && [ "$(rows "$T/pkg_$key.tsv" "$db")" = 0 ] && ! grep -q "rc=126" "$T/pkg_$key.tsv"'
    arm "10-$key writes no SCRIP row, prints from-progress --suite $key@jvm, leaves its package as shipped" \
        'cmp -s "$T/pkg.before" "$T/pkg_files_$key" && [ "$(grep "^$key	" "$T/SUITES.pkg.tsv")" = "$(grep "^$key	" "$T/SUITES.pkg.before")" ] && grep -q "its row is util_score_row.py from-progress --suite $key@jvm " "$T/out_$key" && { [ "$key" = aisnobol ] || grep -qE "^$bl .* -- engine jvm " "$T/out_$key"; }'
    arm "10-$key publishes $key@jvm itself, by from-progress over the rows it appended" \
        'awk -F"\t" -v k="$key@jvm" "\$1==k && \$10>=1" "$T/SUITES.pkg.tsv" | grep -q . && grep -q "^SUITE_ROW suite=$key@jvm " "$T/out_$key"'
done
cp "$T/SUITES.pkg.before" "$T/SUITES.pkg.tsv"; rc="$(S4E_SCORE_NO_WRITE="gate arm 10c" pkgrun test_snobol4_spitbol_testpgms_suite.sh "$T/pkg_nowrite.tsv" jvm)"
arm "10c under S4E_SCORE_NO_WRITE a port runner grades and publishes nothing (rc $rc)" '[ "$rc" = 1 ] && cmp -s "$T/SUITES.pkg.tsv" "$T/SUITES.pkg.before" && grep -q "testpgms@jvm NOT PUBLISHED" "$T/out" && [ "$(rows "$T/pkg_nowrite.tsv" testpgms@jvm)" -ge 1 ]'
rc="$(pkgrun test_snobol4_spitbol_testpgms_suite.sh "$T/pkg_unset.tsv")"
arm "10b unset, testpgms takes SCRIP's path: no scrip in the staged root refuses rc 2 (got $rc)" '[ "$rc" = 2 ] && grep -q "no scrip binary at" "$T/out" && [ ! -s "$T/pkg_unset.tsv" ]'

# HQ_DOTNET'S SIX TAKE THE PORT TOO (hq_dotnet asked for them in this loop, 2026-10-18): dotnet, snoflake, csnobol4, gimpel (through
# scorecard_snobol4.sh), SnoDemo and SnoBench, each over a copy of its population in the staged root, the three large packages cut to
# their first four programs and the ALL.csv rows of those (a red board under the stub sends every program to snoflake's CSNOBOL4 classifier,
# and gimpel-asm-machine-m runs away there: the whole package cost 4 min). The staged corpus and the stub engine become scratch git repos,
# since csnobol4's gate_tree_watch reads both HEADs; a scratch repo is still no checkout of the shared corpus. Per runner: m3 alone (its
# board line shows m4 at zero, and names the engine where it names one; its rows are keyed <suite>@jvm, none m4, no rc=126 -- SnoBench, a
# fixture here, writes no row), and no SCRIP row written, its package left exactly as shipped (hq_dotnet's arm: an engine that resolves a
# file name against the program's folder once wrote two stray files into the dotnet package).
for d in packages/snobol4/dotnet packages/snobol4/snoflake_suite packages/snobol4/csnobol4_suite packages/snobol4/gimpel demos/snobol4 benchmarks/snobol4 tests/snobol4; do
    mkdir -p "$R/corpus/$(dirname "$d")"; rm -rf -- "$R/corpus/$d"
    cp -r "$H/../../corpus/$d" "$R/corpus/$d" || { echo "REFUSE(2) [$G]: no corpus/$d beside this harness -- hq_dotnet's arms cannot be measured"; exit 2; }
done
for d in snoflake_suite csnobol4_suite gimpel; do
    n=0; for f in "$R/corpus/packages/snobol4/$d"/*.sno; do [ "${f##*/}" = ALL.sno ] && continue; n=$((n+1)); [ "$n" -gt 4 ] && rm -f -- "$f"; done
    python3 - "$R/corpus/packages/snobol4/$d" <<'PY'
import csv, os, sys
d = sys.argv[1]; keep = {f[:-4] for f in os.listdir(d) if f.endswith(".sno") and f != "ALL.sno"}
rows = list(csv.reader(open(os.path.join(d, "ALL.csv"), newline="")))
i = rows[0].index("entry")
csv.writer(open(os.path.join(d, "ALL.csv"), "w", newline="")).writerows([rows[0]] + [r for r in rows[1:] if r[i] in keep])
PY
done
for g in "$R/corpus" "$JS"; do
    git -C "$g" init -q && git -C "$g" add -A && git -C "$g" -c user.name=gate -c user.email=gate@invalid -c commit.gpgsign=false commit -qm stage --no-verify \
        || { echo "REFUSE(2) [$G]: could not make $g a scratch git repo -- csnobol4's tree watch cannot be staged"; exit 2; }
done
for k in dotnet snoflake csnobol4 gimpel snobol4-demos snobol4-bench-ref; do   # SCRIP's bare rows, which a port run must leave untouched
    printf '%s\t%s\tx\tsnobol4\t2026-09-01\t1\t2\t2026-09-01\t1\t2\tabc123\t\t0\t\t\n' "$k" "$k" | tee -a "$T/SUITES.pkg.tsv" >> "$T/SUITES.pkg.before"
done
SIX="dotnet:packages/snobol4/dotnet:test_snobol4_dotnet_suite.sh:dotnet@jvm:^DOTNET_BOARD .*m4_pass=0 m4_fail=0 m4_skip=0 .*-- engine jvm
     snoflake:packages/snobol4/snoflake_suite:test_snoflake_suite.sh:snoflake@jvm:^SNOFLAKE_BOARD .*m4_stream_pass=0 m4_skip=0
     csnobol4:packages/snobol4/csnobol4_suite:test_snobol4_csnobol4_suite.sh:csnobol4@jvm:^CSNOBOL4_SUITE_BOARD .*m4_PASS=0 m4_FAIL=0
     gimpel:packages/snobol4/gimpel:test_snobol4_gimpel_suite.sh:gimpel@jvm:^GIMPEL_BOARD .*m4_pass=0 m4_fail=0 -- engine jvm
     snobol4-demos:demos/snobol4:test_demos_suite.sh snobol4:snobol4-demos@jvm:^DEMOS_SUITE_BOARD lang=snobol4 .*m4_pass=0 .*tree=jvm@
     snobol4-bench-ref:benchmarks/snobol4:test_snobol4_bench_suite.sh:-:^SUITE_BOARD family=snobol4-bench-ref .*m4_pass=0 .*engine=jvm modes=m3"
while IFS=: read -r key pkg run db board; do
    key="${key#"${key%%[! ]*}"}"; read -r script args <<< "$run"   # the SIX lines are indented; SnoDemo's runner takes its language
    find "$R/corpus/$pkg" -type f | LC_ALL=C sort > "$T/six.before"
    env PATH="$T/bin:$PATH" S4E_POST="$T/post" S4E_HOME="$R" S4E_SEAT=hq_jvm S4E_ENGINE=jvm S4E_PROGRESS_DB="$T/six_$key.tsv" S4E_SUITES_TSV="$T/SUITES.pkg.tsv" \
        TIMEOUT=20 bash "$R/harness/scripts/$script" $args > "$T/out_$key" 2>&1; rc=$?
    find "$R/corpus/$pkg" -type f | LC_ALL=C sort > "$T/six.after"
    arm "11-$key under jvm grades m3 alone: m4 at zero on its board line, rows keyed $db, no m4 row, no rc=126 (rc $rc)" \
        '[ "$rc" = 1 ] && grep -qE "$board" "$T/out_$key" && { [ "$db" = - ] || { [ "$(rows "$T/six_$key.tsv" "$db")" -ge 1 ] && [ "$(rows "$T/six_$key.tsv" "$db")" = "$(mode_rows "$T/six_$key.tsv" m3)" ] && ! grep -q "rc=126" "$T/six_$key.tsv"; }; }'
    arm "11-$key writes no SCRIP row and leaves its package as shipped" \
        '[ "$(grep "^$key	" "$T/SUITES.pkg.tsv")" = "$(grep "^$key	" "$T/SUITES.pkg.before")" ] && grep -qE "writes no SCRIP row|no progress row and no suite row written" "$T/out_$key" && cmp -s "$T/six.before" "$T/six.after"'
done <<< "$SIX"

[ $examined -ge 58 ] || { echo "REFUSE(2) [$G]: examined=$examined below the 58 declared arms"; exit 2; }
[ $fail -eq 0 ] && { echo "GATE OK [$G]: $examined arms"; exit 0; }
echo "GATE FAIL(1) [$G]: $fail of $examined arms red"; exit 1
