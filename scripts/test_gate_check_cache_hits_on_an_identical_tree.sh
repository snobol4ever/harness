#!/usr/bin/env bash
# test_gate_check_cache_hits_on_an_identical_tree.sh -- THE CHECK CACHE (ARCH-SHARED-DEVELOPMENT section 3.3; row shared-dev-step-7-the-check-
# cache-a-deterministic-gate-runs-once-per-tree-for-done-and-the-sweep-ceo-2041; the cto's design, built by the cqo 2026-10-31).
# The seam: a scratch root of four tiny git repos (SCRIP corpus harness .github, SCRIP carrying out/buildinfo for its own tree) holding a COPY of
# util_check_cache.sh and of checks_nocache.tsv, and S4E_CHECK_CACHE_DIR pointed at a scratch store, so the gate never reads or writes the fleet's
# store or any real root. The probe command counts its own runs in a file outside the trees, so "the command did not run" is measured.
# ARMS: 1 a miss runs and stores; 2 the second run on the identical trees prints CACHED, the same output and the same rc, and the command did
# not run; 3 a dirty tree (one untracked file) runs live and stores nothing; 4 a name in checks_nocache.tsv runs live every time and stores
# nothing; 5 --fresh runs and says so; 6 an rc-2 refusal is never stored; 7 another argument is another key; 8 a SCRIP whose buildinfo names
# another tree runs live; 9 --cacheable-text admits a gate-only DONE-WHEN and refuses one naming a board; 10 every name of the census of the
# real gates is in the real checks_nocache.tsv; 11 a bash -c command, as s4e_msg.sh done passes, caches and replays. rc 0 all arms hold; rc 1 an arm fails; rc 2 cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
U="$HERE/util_check_cache.sh"
[ -f "$U" ] || { echo "RED: $U does not exist"; exit 1; }
command -v git > /dev/null || { echo "REFUSE(2): no git"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
R="$T/root"; ST="$T/store"; CNT="$T/count"
for r in SCRIP corpus harness .github; do
    mkdir -p "$R/$r" && git -C "$R/$r" init -q && git -C "$R/$r" config user.name gate && git -C "$R/$r" config user.email gate@gate || { echo "REFUSE(2): git init failed"; exit 2; }
    echo "$r" > "$R/$r/README"; [ "$r" = SCRIP ] && printf 'out/\n' > "$R/$r/.gitignore"
    git -C "$R/$r" add -A && git -C "$R/$r" commit -q -m init || { echo "REFUSE(2): git commit failed"; exit 2; }
done
mkdir -p "$R/harness/scripts" "$R/SCRIP/out"
cp "$U" "$R/harness/scripts/util_check_cache.sh"
printf '# scratch\nnever_cached\tthe gate'"'"'s own nocache name\n' > "$R/harness/scripts/checks_nocache.tsv"
git -C "$R/harness" add -A && git -C "$R/harness" commit -q -m scripts
printf 'tree %s\n' "$(git -C "$R/SCRIP" rev-parse 'HEAD^{tree}')" > "$R/SCRIP/out/buildinfo"
probe="$T/probe.sh"; printf '#!/bin/bash\necho run >> "%s"\necho "probe says $1"\nexit "$2"\n' "$CNT" > "$probe"; chmod +x "$probe"
runs() { [ -f "$CNT" ] && wc -l < "$CNT" | tr -d ' ' || echo 0; }
entries() { find "$ST" -mindepth 2 -maxdepth 2 -type d ! -name '.tmp.*' 2>/dev/null | wc -l | tr -d ' '; }
cc() { env -u S4E_NO_CHECK_CACHE -u S4E_ONE_TEST_ADMIT S4E_CHECK_CACHE_DIR="$ST" bash "$R/harness/scripts/util_check_cache.sh" "$@"; }
fail=0
ok() { echo "  ok   arm $1: $2"; }
bad() { echo "  FAIL arm $1: $2"; fail=1; }
o="$(cc g1 -- "$probe" alpha 1 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$(runs)" = 1 ] && [ "$(entries)" = 1 ] && ! printf '%s\n' "$o" | grep -q '^CACHED' && printf '%s\n' "$o" | grep -q 'probe says alpha' \
    && ok 1 "a miss runs the command (rc 1, one run) and stores one entry" || bad 1 "miss: rc=$rc runs=$(runs) entries=$(entries) out=[$o]"
o="$(cc g1 -- "$probe" alpha 1 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$(runs)" = 1 ] && printf '%s\n' "$o" | head -1 | grep -q '^CACHED [0-9a-f]\{40\} 20' && printf '%s\n' "$o" | grep -q 'probe says alpha' \
    && ok 2 "the identical trees replay CACHED, the same output and rc 1, and the command did not run" || bad 2 "hit: rc=$rc runs=$(runs) out=[$o]"
touch "$R/corpus/untracked_file"; n0="$(entries)"
o="$(cc g1 -- "$probe" alpha 1 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$(runs)" = 2 ] && [ "$(entries)" = "$n0" ] && ! printf '%s\n' "$o" | grep -q '^CACHED' && printf '%s\n' "$o" | grep -q 'LIVE .*corpus tree is dirty' \
    && ok 3 "a dirty tree runs live, says why and stores nothing" || bad 3 "dirty: rc=$rc runs=$(runs) entries=$(entries)/$n0 out=[$o]"
rm -f "$R/corpus/untracked_file"
cc never_cached -- "$probe" beta 0 > /dev/null 2>&1; o="$(cc never_cached -- "$probe" beta 0 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ "$(runs)" = 4 ] && [ "$(entries)" = "$n0" ] && printf '%s\n' "$o" | grep -q 'in checks_nocache.tsv' \
    && ok 4 "a name in checks_nocache.tsv runs live twice and stores nothing" || bad 4 "nocache: rc=$rc runs=$(runs) entries=$(entries)/$n0 out=[$o]"
o="$(cc --fresh g1 -- "$probe" alpha 1 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$(runs)" = 5 ] && printf '%s\n' "$o" | head -1 | grep -q '^FRESH ' \
    && ok 5 "--fresh runs the command and says so on its first line" || bad 5 "fresh: rc=$rc runs=$(runs) out=[$o]"
n0="$(entries)"; cc g2 -- "$probe" gamma 2 > /dev/null 2>&1; o="$(cc g2 -- "$probe" gamma 2 2>&1)"; rc=$?
[ "$rc" = 2 ] && [ "$(runs)" = 7 ] && [ "$(entries)" = "$n0" ] && ! printf '%s\n' "$o" | grep -q '^CACHED' \
    && ok 6 "an rc-2 refusal is never stored: the second run runs again" || bad 6 "refusal: rc=$rc runs=$(runs) entries=$(entries)/$n0"
o="$(cc g1 -- "$probe" delta 1 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$(runs)" = 8 ] && printf '%s\n' "$o" | grep -q 'probe says delta' && ! printf '%s\n' "$o" | grep -q '^CACHED' \
    && ok 7 "another argument is another key: a miss" || bad 7 "args: rc=$rc runs=$(runs) out=[$o]"
cc g3 -- bash -c "$probe eps 0" > /dev/null 2>&1; o="$(cc g3 -- bash -c "$probe eps 0" 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ "$(runs)" = 9 ] && printf '%s\n' "$o" | head -1 | grep -q '^CACHED ' && ! printf '%s\n' "$o" | grep -q 'Usage' \
    && ok 11 "a bash -c command (the shape s4e_msg.sh done passes, an argument that looks like an option) caches and replays" || bad 11 "bash -c: rc=$rc runs=$(runs) out=[$o]"
printf 'tree 0000000000000000000000000000000000000000\n' > "$R/SCRIP/out/buildinfo"
o="$(cc g1 -- "$probe" alpha 1 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$(runs)" = 10 ] && printf '%s\n' "$o" | grep -q "LIVE .*buildinfo" \
    && ok 8 "a SCRIP built from another tree runs live" || bad 8 "stale build: rc=$rc runs=$(runs) out=[$o]"
a="$(bash "$U" --cacheable-text 'cd "$S4E_HOME" && bash harness/scripts/test_gate_pl_prolog_cut_to_a_choice_marked_in_the_same_conjunction_commits_the_segment_as_swipl.sh' > /dev/null 2>&1; echo $?)"
b="$(bash "$U" --cacheable-text 'cd "$S4E_HOME" && bash harness/scripts/util_suite_row_at_100.sh swi' > /dev/null 2>&1; echo $?)"
c="$(bash "$U" --cacheable-text 'cd "$S4E_HOME" && test -f README' > /dev/null 2>&1; echo $?)"
nc="$(grep -v '^#' "$HERE/checks_nocache.tsv" 2>/dev/null | cut -f1 | head -1)"
d="$(bash "$U" --cacheable-text "bash harness/scripts/$nc" > /dev/null 2>&1; echo $?)"
[ "$a" = 0 ] && [ "$b" = 1 ] && [ "$c" = 1 ] && [ "$d" = 1 ] && ok 9 "--cacheable-text admits a gate-only DONE-WHEN and refuses a board, a script-less one and a nocache gate" \
    || bad 9 "cacheable-text: gate=$a board=$b none=$c nocache($nc)=$d"
miss="$(bash "$U" --census | cut -f1 | while read -r g; do grep -v '^#' "$HERE/checks_nocache.tsv" | cut -f1 | grep -qxF "$g" || echo "$g"; done)"
[ -z "$miss" ] && ok 10 "every name of the census of the real gates is in checks_nocache.tsv" || bad 10 "census names missing from checks_nocache.tsv: $(echo $miss)"
[ "$fail" = 0 ] && { echo "PASS test_gate_check_cache_hits_on_an_identical_tree (11 arms)"; exit 0; }
echo "FAIL test_gate_check_cache_hits_on_an_identical_tree"; exit 1
