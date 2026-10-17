#!/usr/bin/env bash
# test_gate_one_runner_fixture_is_admitted_only_outside_the_shared_corpus.sh -- S4E_ONE_RUNNER_FIXTURE ADMITS A GATE'S SCRATCH
# POPULATION AND NEVER THE SHARED CORPUS, IN BOTH COPIES OF THE ONE-RUNNER GUARD (ceo CEO-1302 (c), 2026-09-27, on the coo's COO-198
# report; row instruments-the-one-runner-fixture-exemption-is-admitted-only-for-a-population-outside-the-shared-corpus-...).
#
# ⛔⭐ WHY: lib_one_runner.sh returned 0 on the variable alone, and corpus_suite_harness.py's mirror admitted exactly the case it should
# refuse (its scratch suites return before the check, so the check only ever saw boards). test_gate_nreturn_by_name_value_broken.sh and
# test_gate_snocone_returns_codegen.sh export the variable and ran test_corpus_snobol4.sh over the real 1991-entry rungs as a
# non-regression arm, so the coo's control arm of 2026-09-26 made two whole SnoRungs passes and appended 7964 rows under a seat that runs
# no board -- and both arms then read UNPROVEN anyway, their regex having missed the runner's line since c18cb9811.
#
#   B1  bash: a suite inside the shared corpus under the exemption is REFUSED rc 2, naming the rule (the inert probe seat, so no lane
#       admits it on its own)
#   B2  bash: a suite in a mktemp directory is admitted (not a board, before the exemption is read)
#   B3  bash: a runner naming no suite, its environment resolving the shared corpus, is REFUSED rc 2
#   B4  bash: a runner naming no suite under S4E_HOME=<mktemp root>, bare and `git init`ed, is admitted as a fixture
#   B5  bash: the same under a root whose corpus carries the shared remote is REFUSED rc 2 -- the remote is the fact, not the path
#   P   one_runner_population_of: --corpus X answers X, else CORPUS, else nothing
#   R   the seven runners whose population comes from --corpus or CORPUS hand it to the guard, and one of them (the Jcon runner, a
#       mktemp --corpus with no programs) is admitted by the guard and stops on its own refusal instead
#   H   the harness: a shared-corpus suite under the exemption is refused rc 2, naming the rule; a mktemp suite is admitted
#   G   the two rungs gates grade a scratch rungs: util_scratch_snobol4_rungs.py builds it and test_corpus_snobol4.sh runs only with
#       S4E_HOME at it -- no bare call remains
#   S   util_scratch_snobol4_rungs.py builds a scratch rungs: entries > 0, ALL.sno/ALL.ref/ALL.cmdline, no ALL.csv beside the
#       sidecars, and ROOT/corpus a git world with no remote
#   F   FAIL-ONCE: a copy of lib_one_runner.sh and of the harness with the exemption restored to the old unconditional admission
#       admits B1, B3 and H's shared-corpus suite -- rc 0 -- so those three arms can red
# FAIL-ONCE, MEASURED 2026-09-27 (coo) in a detached worktree of origin b26afab9f with this gate copied in: B1, B3, B5, P, R, H, G and
# S red (8 of the 10 arms before F), and F refuses rc 2 because the old guard carries no block to restore; on this landing 11 of 11.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=one_runner_fixture_is_admitted_only_outside_the_shared_corpus
unproven() { echo "GATE UNPROVEN(2) [$G]: $*"; exit 2; }
L="$HERE/lib_one_runner.sh"; [ -f "$L" ] || unproven "no lib_one_runner.sh"
CORPUS="$(cd "$ROOT/.." && pwd)/corpus"
[ -f "$CORPUS/tests/snobol4/ALL.sno" ] || unproven "no shared corpus rungs at $CORPUS/tests/snobol4/ALL.sno"
. "$L"
one_runner_in_a_shared_checkout "$CORPUS" || unproven "$CORPUS is no checkout of $ONE_RUNNER_SHARED_CORPUS_REMOTE -- B1, B3 and H would measure nothing"
PROBE="$ONE_RUNNER_PROBE_SEAT"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_fxonly.XXXXXX")" || unproven "mktemp failed"
trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1: $2"; }
red() { FAIL=$((FAIL+1)); echo "  ⛔ $1 RED: $2"; }
gb() {  # <lib> <env...> -- <guard args...>: rc and output of one guard call in a clean shell, the probe seat and the exemption set
    local lib="$1"; shift; local -a e=(); while [ "$1" != -- ]; do e+=("$1"); shift; done; shift
    env -u S4E_HOME -u S4E_CORPUS -u S4E_DONE_WHEN_RUN -u S4E_ONE_RUNNER_OVERRIDE -u CORPUS S4E_SEAT="$PROBE" S4E_ONE_RUNNER_FIXTURE="gate $G" \
        "${e[@]}" bash -c 'source "$1"; shift; one_runner_guard "$@"' _ "$lib" "$@" 2>&1
}
hb() {  # <harness dir> <suite> <corpus root>: rc and output of the harness's own guard
    env -u S4E_HOME -u S4E_CORPUS -u S4E_DONE_WHEN_RUN -u S4E_ONE_RUNNER_OVERRIDE S4E_SEAT="$PROBE" S4E_ONE_RUNNER_FIXTURE="gate $G" \
        python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); sys.path.insert(1, sys.argv[4]); import corpus_suite_harness as h; h._one_runner_guard(sys.argv[2], sys.argv[3], "snobol4")' \
        "$1" "$2" "$3" "$HERE" 2>&1
}
RUNGS="$CORPUS/tests/snobol4/ALL.sno"
: > "$W/scratch.sno"
mkdir -p "$W/bare/corpus" "$W/init" "$W/shared"; git init -q "$W/init/corpus"; git init -q "$W/shared/corpus"
git -C "$W/shared/corpus" remote add origin "git@github.com:$ONE_RUNNER_SHARED_CORPUS_REMOTE.git"

# ── B, P: the bash guard ─────────────────────────────────────────────────────────────────────────────────────────────────────
o="$(gb "$L" -- test_x_suite.sh "$RUNGS")"; r=$?
[ "$r" = 2 ] && grep -q 'ONE-RUNNER FIXTURE NOT ADMITTED' <<<"$o" && ok B1 "a shared-corpus suite under the exemption is refused rc 2, naming the rule" || red B1 "rc=$r: $(head -2 <<<"$o" | tr '\n' ' ')"
o="$(gb "$L" -- test_x_suite.sh "$W/scratch.sno")"; r=$?
[ "$r" = 0 ] && ok B2 "a mktemp suite is admitted" || red B2 "rc=$r: $(head -2 <<<"$o" | tr '\n' ' ')"
o="$(gb "$L" -- test_x_suite.sh)"; r=$?
[ "$r" = 2 ] && grep -q "ONE-RUNNER FIXTURE NOT ADMITTED: test_x_suite.sh grades $CORPUS" <<<"$o" && ok B3 "a runner naming no suite, resolving the shared corpus, is refused rc 2 and the refusal names it" || red B3 "rc=$r: $(head -2 <<<"$o" | tr '\n' ' ')"
o1="$(gb "$L" S4E_HOME="$W/bare" -- test_x_suite.sh)"; r1=$?; o2="$(gb "$L" S4E_HOME="$W/init" -- test_x_suite.sh)"; r2=$?
[ "$r1" = 0 ] && [ "$r2" = 0 ] && grep -q 'ONE-RUNNER FIXTURE by' <<<"$o1$o2" && ok B4 "a no-suite runner under a mktemp root is admitted as a fixture, bare and git-initialised" || red B4 "rc bare=$r1 init=$r2: $(head -1 <<<"$o1") | $(head -1 <<<"$o2")"
o="$(gb "$L" S4E_HOME="$W/shared" -- test_x_suite.sh)"; r=$?
[ "$r" = 2 ] && ok B5 "a root whose corpus carries the shared remote is refused rc 2 -- the remote is the fact" || red B5 "rc=$r: $(head -2 <<<"$o" | tr '\n' ' ')"
# B6: a suite UNDER the configured S4E_CORPUS when that corpus is a scratch tree (no git repository at all) and the run appends to a scratch
# progress table is a fixture, not a board; the same suite under the corpus carrying the shared remote is refused (the coo 2026-10-03:
# one_runner_corpus_is_the_shared_population read "not a git repository" as shared, so test_prolog_swi_suite.sh -- whose population is
# S4E_CORPUS itself -- could never run as a gate fixture outside the coo's own root)
mkdir -p "$W/bare/corpus/packages/x" "$W/shared/corpus/packages/x"
o1="$(gb "$L" S4E_CORPUS="$W/bare/corpus" S4E_PROGRESS_DB="$W/b6.tsv" -- test_x_suite.sh "$W/bare/corpus/packages/x")"; r1=$?
o2="$(gb "$L" S4E_CORPUS="$W/shared/corpus" S4E_PROGRESS_DB="$W/b6.tsv" -- test_x_suite.sh "$W/shared/corpus/packages/x")"; r2=$?
[ "$r1" = 0 ] && grep -q 'FIXTURE, not a board' <<<"$o1" && [ "$r2" = 2 ] && ok B6 "a suite under a non-git scratch S4E_CORPUS with a scratch progress table is a fixture; under the shared-remote corpus it is refused" \
    || red B6 "bare rc=$r1 shared rc=$r2: $(head -1 <<<"$o1" | cut -c1-120) | $(head -1 <<<"$o2" | cut -c1-120)"
p1="$(bash -c 'source "$1"; one_runner_population_of run --out x --corpus /pop/a' _ "$L")"; p2="$(CORPUS=/pop/b bash -c 'source "$1"; one_runner_population_of run' _ "$L")"
p3="$(env -u CORPUS bash -c 'source "$1"; one_runner_population_of run' _ "$L")"; p4="$(CORPUS=/pop/b bash -c 'source "$1"; one_runner_population_of --corpus /pop/a' _ "$L")"
[ "$p1" = /pop/a ] && [ "$p2" = /pop/b ] && [ -z "$p3" ] && [ "$p4" = /pop/a ] && ok P "--corpus answers first, then CORPUS, else nothing" || red P "got [$p1] [$p2] [$p3] [$p4] (want /pop/a /pop/b '' /pop/a)"

# ── R: the runners that take their population from --corpus or CORPUS hand it over ─────────────────────────────────────────────
miss=""
for f in test_icon_jcon_suite.sh test_icon_rung_suite.sh test_prolog_rung_suite.sh test_icon_all_rungs.sh board_icon_rungs.sh scorecard_snobol4.sh test_snobol4_gimpel_suite.sh; do
    sed -n '2p' "$HERE/$f" | grep -qF 'one_runner_guard "${0##*/}' && sed -n '2p' "$HERE/$f" | grep -qF '"$(one_runner_population_of "$@")"' || miss="$miss $f"
done
mkdir -p "$W/jc"
o="$(cd "$ROOT" && env -u S4E_HOME -u S4E_CORPUS S4E_SEAT="$PROBE" S4E_ONE_RUNNER_FIXTURE="gate $G" S4E_PROGRESS_DB="$W/jc.tsv" S4E_SCORE_NO_WRITE="gate $G" timeout -k 5 120 bash "$HERE/test_icon_jcon_suite.sh" --corpus "$W/jc" 2>&1)"; r=$?
if [ -z "$miss" ] && ! grep -q 'REFUSE(2) ONE RUNNER\|FIXTURE NOT ADMITTED' <<<"$o"; then
    ok R "all seven runners hand their population to the guard; the Jcon runner on a mktemp --corpus is admitted and stops on its own (rc=$r)"
else
    red R "guard lines without the population:${miss:- none}; Jcon on a mktemp --corpus: $(grep -m1 'REFUSE(2) ONE RUNNER\|FIXTURE NOT ADMITTED' <<<"$o" | cut -c1-160)"
fi

# ── H: the harness ──────────────────────────────────────────────────────────────────────────────────────────────────────────
o1="$(hb "$HERE" "$RUNGS" "$CORPUS")"; r1=$?; o2="$(hb "$HERE" "$W/scratch.sno" "$CORPUS")"; r2=$?
[ "$r1" = 2 ] && grep -q 'ONE-RUNNER FIXTURE NOT ADMITTED' <<<"$o1" && [ "$r2" = 0 ] && ok H "the harness refuses a shared-corpus suite under the exemption rc 2, naming the rule, and admits a mktemp suite" \
    || red H "shared rc=$r1 ($(head -1 <<<"$o1" | cut -c1-120)); mktemp rc=$r2 ($(head -1 <<<"$o2" | cut -c1-120))"

# ── G: the two rungs gates ─────────────────────────────────────────────────────────────────────────────────────────────────
gmiss=""
for f in test_gate_nreturn_by_name_value_broken.sh test_gate_snocone_returns_codegen.sh; do
    x="$(grep -v '^\s*#' "$HERE/$f")"
    grep -q 'util_scratch_snobol4_rungs.py "$SNO_ROOT"' <<<"$x" && grep -q 'S4E_HOME="$SNO_ROOT".* bash ../harness/scripts/test_corpus_snobol4.sh' <<<"$x" \
      && ! grep -qE '(^|[;(]) *bash ../harness/scripts/test_corpus_snobol4.sh' <<<"$x" || gmiss="$gmiss $f"
done
[ -z "$gmiss" ] && ok G "both rungs gates build a scratch rungs and run test_corpus_snobol4.sh only at it" || red G "still reaching the shared rungs:$gmiss"

# ── S: the scratch rungs ───────────────────────────────────────────────────────────────────────────────────────────────────
so="$(python3 "$HERE/util_scratch_snobol4_rungs.py" "$W/sm" '\bNRETURN\b' 2>&1)"; sr=$?
sn="$(sed -n 's/^SCRATCH_RUNGS entries=\([0-9]*\) .*/\1/p' <<<"$so")"; T="$W/sm/corpus/tests/snobol4"
if [ "$sr" = 0 ] && [ "${sn:-0}" -gt 0 ] && [ -s "$T/ALL.sno" ] && [ -s "$T/ALL.ref" ] && [ -s "$T/ALL.cmdline" ] && [ ! -e "$T/ALL.csv" ] \
   && git -C "$W/sm/corpus" rev-parse --git-dir >/dev/null 2>&1 && [ -z "$(git -C "$W/sm/corpus" remote)" ] && [ -d "$W/sm/corpus/demos/snobol4" ]; then
    ok S "a scratch rungs of $sn entries, its sidecars and no ALL.csv, in a git world with no remote, the demos beside it"
else
    red S "rc=$sr entries=${sn:-none}: $(tail -1 <<<"$so" | cut -c1-160)"
fi

# ── F: FAIL-ONCE ────────────────────────────────────────────────────────────────────────────────────────────────────────────
mkdir -p "$W/mut"
python3 - "$L" "$W/mut/lib_one_runner.sh" "$HERE/corpus_suite_harness.py" "$W/mut/corpus_suite_harness.py" <<'PY' || unproven "the mutants could not be written -- the fixture block moved"
import re, sys
s = open(sys.argv[1]).read()
i = s.index('  if [ -n "${S4E_ONE_RUNNER_FIXTURE:-}" ]; then\n    local _fxpop=')
j = s.index('\n  fi\n', i) + len('\n  fi\n')
open(sys.argv[2], "w").write(s[:i] + '  if [ -n "${S4E_ONE_RUNNER_FIXTURE:-}" ]; then printf \'ONE-RUNNER FIXTURE by %s on %s: %s\\n\' "${seat:-?}" "$board" "$S4E_ONE_RUNNER_FIXTURE"; return 0; fi\n' + s[j:])
t = open(sys.argv[3]).read()
a = t.index('    if os.environ.get("S4E_ONE_RUNNER_FIXTURE"):\n')
b = t.index('(suite_path or "a run naming no suite"))\n', a) + len('(suite_path or "a run naming no suite"))\n')
open(sys.argv[4], "w").write(t[:a] + '    if os.environ.get("S4E_ONE_RUNNER_FIXTURE"):\n        print("ONE-RUNNER FIXTURE by %s: %s" % (seat or "?", os.environ["S4E_ONE_RUNNER_FIXTURE"])); return\n' + t[b:])
PY
( o="$(gb "$W/mut/lib_one_runner.sh" -- test_x_suite.sh "$RUNGS")"; echo "$?" ) > "$W/f1"
( o="$(gb "$W/mut/lib_one_runner.sh" -- test_x_suite.sh)"; echo "$?" ) > "$W/f3"
( o="$(hb "$W/mut" "$RUNGS" "$CORPUS")"; echo "$?" ) > "$W/fh"
f1="$(cat "$W/f1")"; f3="$(cat "$W/f3")"; fh="$(cat "$W/fh")"
[ "$f1" = 0 ] && [ "$f3" = 0 ] && [ "$fh" = 0 ] && ok F "the old unconditional exemption admits B1's rungs, B3's default root and H's rungs (rc 0, 0, 0): those arms can red" \
    || red F "under the restored old exemption B1 rc=$f1 B3 rc=$f3 H rc=$fh (want 0 0 0) -- the arms may not distinguish"

echo "GATE $([ "$FAIL" = 0 ] && echo PASS || echo "FAIL($FAIL)") [$G]: $PASS of $((PASS + FAIL)) arms green (population: 2 guards, 7 runners, 2 gates, 1 scratch rungs)"
[ "$FAIL" = 0 ]
