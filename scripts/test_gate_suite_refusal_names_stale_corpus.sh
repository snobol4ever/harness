#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
# ../harness/scripts/test_gate_suite_refusal_names_stale_corpus.sh -- row suite-refusal-should-name-stale-corpus.
# CONSTRUCTS the stale-vs-genuinely-gone-vs-undetermined conditions with hermetic scratch git repos
# (never the real corpus) and asserts test_corpus_snobol4.sh's unresolved-suite-path refusal diagnoses
# each one correctly. Self-contained per RULES.md: no network, no shared state, $S4E_HOME redirected
# per-arm so the runner-under-test never touches the real corpus checkout.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${RUNNER:-$HERE/test_corpus_snobol4.sh}"   # override to negative-test an old/reverted runner
[ -f "$RUNNER" ] || { echo "⛔ GATE CANNOT RUN: no runner at $RUNNER"; exit 2; }

FAILED=0
note() { printf '%s\n' "$1"; }
fail() { printf '⛔ FAIL: %s\n' "$1"; FAILED=1; }

GATE_WORK="$(mktemp -d)"
trap 'rm -rf "$GATE_WORK"' EXIT

# The suite family list lives in exactly one place, the runner's own `for family in ...` line --
# extracted here rather than duplicated, so this gate cannot silently drift from the real list.
FAMILIES="$(grep -oP '(?<=for family in )[^;]+' "$RUNNER" | head -1)"
[ -n "$FAMILIES" ] || { echo "⛔ GATE CANNOT RUN: could not extract the suite family list from $RUNNER"; exit 2; }

# ── Build one hermetic scratch corpus checkout ─────────────────────────────────
# $1=checkout dir  $2=add|omit (does origin ever get the suite families)  $3=behind|current (is
# local reset back before the families landed, or left caught up with origin/main)
mk_scratch_corpus() {
    local dir="$1" mode="$2" freshness="$3"
    local seed="$GATE_WORK/seed-$(basename "$dir")"
    local origin="$GATE_WORK/origin-$(basename "$dir").git"
    git init -q -b main "$seed"
    ( cd "$seed" && git -c user.name=gate -c user.email=gate@localhost commit -q --allow-empty -m base )
    git init -q --bare -b main "$origin"
    ( cd "$seed" && git remote add origin "$origin" && git push -q origin main )
    local base_sha; base_sha="$(cd "$seed" && git rev-parse HEAD)"
    if [ "$mode" = add ]; then
        ( cd "$seed"
          for fam in $FAMILIES; do
              mkdir -p "tests/snobol4/$(dirname "$fam")"
              printf 'placeholder -- never executed, only existence is graded\n' > "tests/snobol4/${fam}.sno"
              printf 'placeholder\n' > "tests/snobol4/${fam}.ref"
          done
          git add -A && git -c user.name=gate -c user.email=gate@localhost commit -q -m with-families
          git push -q origin main )
    fi
    git clone -q "$origin" "$dir"
    [ "$freshness" = behind ] && ( cd "$dir" && git reset -q --hard "$base_sha" )
    # Required subtrees the runner refuses on if absent (a DIFFERENT refusal than the one under
    # test) -- deliberately left with no suite-family files in either arm.
    mkdir -p "$dir/crosscheck" "$dir/demo/snobol4" "$dir/tests/snobol4/beauty_suite"
}

run_against() {  # $1=corpus dir -> prints runner's merged stdout+stderr; ITS exit status is the runner's
    local corpus="$1" root="$GATE_WORK/root-$(basename "$1")"
    mkdir -p "$root"
    cp -r "$corpus" "$root/corpus"
    S4E_HOME="$root" timeout -k 5 60 bash "$RUNNER"
}

# ── Arm 1: STALE -- local behind origin, origin HAS every family ──────────────
mk_scratch_corpus "$GATE_WORK/corpus_stale" add behind
out_stale="$(run_against "$GATE_WORK/corpus_stale" 2>&1)"; rc_stale=$?
note "── arm 1 (stale checkout), rc=$rc_stale ──"
[ "$rc_stale" -eq 2 ]                                          || fail "stale arm exited rc=$rc_stale, expected 2 (REFUSED)"
grep -q "CORPUS CHECKOUT IS STALE" <<<"$out_stale"              || fail "stale arm did not diagnose a stale checkout"
grep -qE "behind origin" <<<"$out_stale"                        || fail "stale arm did not name commits-behind-origin"
grep -q "DO NOT REPOINT AND DO NOT RETIRE" <<<"$out_stale"      || fail "stale arm did not forbid the destructive remedy"
grep -q "git -C .* pull --ff-only" <<<"$out_stale"               || fail "stale arm did not print the pull-fix command"

# ── Arm 2: GENUINELY GONE -- local fully caught up, origin never had the families ──
mk_scratch_corpus "$GATE_WORK/corpus_gone" omit current
out_gone="$(run_against "$GATE_WORK/corpus_gone" 2>&1)"; rc_gone=$?
note "── arm 2 (genuinely-gone, caught-up checkout), rc=$rc_gone ──"
[ "$rc_gone" -eq 2 ]                                            || fail "gone arm exited rc=$rc_gone, expected 2 (REFUSED)"
grep -q "CORPUS CHECKOUT IS STALE" <<<"$out_gone"               && fail "gone arm FALSELY claimed a stale checkout"
grep -qE "behind origin" <<<"$out_gone"                          && fail "gone arm emitted the behind-origin hint on a caught-up checkout (this is the false-positive that would send someone to pull a corpus with nothing new to give them)"
grep -q "absent at origin/main too" <<<"$out_gone"              || fail "gone arm did not diagnose the paths as genuinely absent"

# ── Arm 3: UNDETERMINED -- no git repo at all (no origin to ask) ──────────────
corpus_undet="$GATE_WORK/corpus_undet"
mkdir -p "$corpus_undet/crosscheck" "$corpus_undet/demo/snobol4" "$corpus_undet/tests/snobol4/beauty_suite"
out_undet="$(run_against "$corpus_undet" 2>&1)"; rc_undet=$?
note "── arm 3 (no git repo, undetermined), rc=$rc_undet ──"
[ "$rc_undet" -eq 2 ]                                           || fail "undetermined arm exited rc=$rc_undet, expected 2 (REFUSED)"
grep -q "UNDETERMINED" <<<"$out_undet"                          || fail "undetermined arm did not say UNDETERMINED"
grep -q "CORPUS CHECKOUT IS STALE" <<<"$out_undet"              && fail "undetermined arm FALSELY claimed a stale checkout with no origin to check"
grep -q "Repoint or retire" <<<"$out_undet"                     && fail "undetermined arm handed out the destructive repoint/retire advice with no evidence either way"

if [ "$FAILED" -ne 0 ]; then
    echo "⛔ GATE FAIL: the unresolved-suite-path refusal does not correctly distinguish stale/gone/undetermined. Full transcripts:"
    echo "--- stale ---"; printf '%s\n' "$out_stale"
    echo "--- gone ---"; printf '%s\n' "$out_gone"
    echo "--- undetermined ---"; printf '%s\n' "$out_undet"
    exit 1
fi
echo "✅ GATE OK: stale/gone/undetermined all correctly diagnosed (rc=2 + right message, wrong message absent) in all 3 arms"
exit 0
