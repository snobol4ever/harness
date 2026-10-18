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
# snobol4jvm source each refuse the board rc 2 before any entry.
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

[ $examined -ge 27 ] || { echo "REFUSE(2) [$G]: examined=$examined below the 27 declared arms"; exit 2; }
[ $fail -eq 0 ] && { echo "GATE OK [$G]: $examined arms"; exit 0; }
echo "GATE FAIL(1) [$G]: $fail of $examined arms red"; exit 1
