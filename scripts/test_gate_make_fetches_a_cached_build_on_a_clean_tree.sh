#!/usr/bin/env bash
bash "$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_make_fetches_a_cached_build_on_a_clean_tree.sh -- ONE BUILD PER TREE (the cto, ARCH-SHARED-DEVELOPMENT.md section 3.2, R-2041 step 6).
# THE QUESTION: does `make` in a clean worktree whose tree is already in the build cache fetch the artifacts and start no compiler, and does a
# dirty tree build locally and publish nothing? THE FIXTURE: a scratch cache under mktemp (S4E_BUILD_CACHE_DIR), seeded by `publish` from THIS
# root's own built artifacts (so the root must be clean and fresh: a dirty or stale root REFUSES, it cannot seed a truthful entry); a detached
# worktree of SCRIP at HEAD with harness and corpus worktrees beside it; a PATH shim in front of gcc and g++ that logs every compiler start.
#   arm 1  make in the worktree prints FETCHED <key>, the shim log is empty, the fetched scrip runs a program, the freshness guard admits it, and
#          the fetched scrip resolves libscrip_rt.so inside the WORKTREE (an $ORIGIN rpath), never in the producer's root
#   arm 2  a second make reads "already in place" and starts nothing
#   arm 3  a dirty worktree: fetch refuses DIRTY (rc 1) and publish stores nothing (the entry count is unchanged)
#   arm 4  a different runtime tag is a different key: fetch reads MISS
# RED on the Makefile before the landing: make compiles (the shim log fills within seconds) and prints no FETCHED; the run is killed at the first
# compiler start, so the red arm costs seconds, not a build. rc 0 GREEN, 1 RED, 2 REFUSE (no built root, a dirty root, no git worktree, no gcc).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
NAME=test_gate_make_fetches_a_cached_build_on_a_clean_tree
BC="$HERE/util_build_cache.sh"
refuse() { echo "REFUSE(2): $*"; exit 2; }
[ -f "$BC" ] || refuse "no $BC (the cache script is the thing under test)"
[ -x "$SC/scrip" ] && [ -f "$SC/out/libscrip_rt.so" ] && [ -f "$SC/out/scrip-ipp" ] || refuse "no built root at $SC (make first)"
command -v gcc > /dev/null && command -v g++ > /dev/null || refuse "no gcc or g++ on PATH"
TAG="$(make -s -C "$SC" buildinfo 2>/dev/null | sed -n 's/^RT_TAG *: *//p' | head -1)"
[ -n "$TAG" ] || refuse "make buildinfo printed no RT_TAG"
[ -n "$(ls "$SC/out/rt_pic-$TAG"/*.o 2>/dev/null)" ] || refuse "no runtime objects under out/rt_pic-$TAG in the root"
T="$(mktemp -d /tmp/s4e_build_cache_gate.XXXXXX)"
cleanup() {
    [ -n "${MK_PGID:-}" ] && kill -- -"$MK_PGID" 2>/dev/null
    for r in SCRIP harness corpus; do [ -d "$T/wt/$r" ] && git -C "$ROOT/$r" worktree remove --force "$T/wt/$r" > /dev/null 2>&1; done
    rm -rf "$T"
}
trap cleanup EXIT
export S4E_BUILD_CACHE_DIR="$T/cache"
unset S4E_NO_BUILD_CACHE
mkdir -p "$T/cache" "$T/shim" "$T/wt"
# the shim logs a COMPILE or LINK (a version query is the cache script's own toolchain line, not a compiler start)
for c in gcc g++; do printf '#!/bin/sh\ncase " $*" in *" --version"*|*" -dumpversion"*|*" -dumpmachine"*|*" -print-"*) ;; *) echo "%s $*" >> "%s/compiles" ;; esac\nexec /usr/bin/%s "$@"\n' "$c" "$T" "$c" > "$T/shim/$c"; chmod +x "$T/shim/$c"; done
: > "$T/compiles"
seed="$(bash "$BC" publish --root "$SC" --tag "$TAG" 2>&1)"
case "$seed" in PUBLISHED*) ;; *"DIRTY tree"*) refuse "the root is dirty, it cannot seed a truthful entry ($seed)";; *) refuse "seeding the fixture cache failed: $seed";; esac
key="$(bash "$BC" key --root "$SC" --tag "$TAG")"
[ -f "$T/cache/$key/MANIFEST" ] || refuse "the seeded entry $key has no MANIFEST"
for r in SCRIP harness corpus; do git -C "$ROOT/$r" worktree add -q --detach "$T/wt/$r" HEAD 2> /dev/null || refuse "git worktree add failed for $r"; done
W="$T/wt/SCRIP"
[ "$(git -C "$W" rev-parse 'HEAD^{tree}')" = "$(git -C "$SC" rev-parse 'HEAD^{tree}')" ] || refuse "the worktree's tree differs from the root's"
red=""; fetched=0; compiles=0
# arm 1: make with the shim in front of the compilers, killed at the first compiler start
setsid bash -c "cd '$W' && PATH='$T/shim:$PATH' exec make 2>&1" > "$T/make1.log" 2>&1 &
MK_PID=$!; MK_PGID="$(ps -o pgid= -p "$MK_PID" 2>/dev/null | tr -d ' ')"
for i in $(seq 1 600); do
    kill -0 "$MK_PID" 2>/dev/null || break
    [ -s "$T/compiles" ] && { kill -- -"$MK_PGID" 2>/dev/null; break; }
    sleep 1
done
wait "$MK_PID" 2>/dev/null; mk_rc=$?; MK_PGID=""
compiles="$(grep -c . "$T/compiles" 2>/dev/null)"; compiles="${compiles:-0}"
if grep -q "^FETCHED $key" "$T/make1.log"; then fetched=1; else red="$red arm1:no-FETCHED-line(make rc $mk_rc)"; fi
[ "$compiles" = 0 ] || red="$red arm1:$compiles-compiler-start(s)"
[ -x "$W/scrip" ] && [ -f "$W/out/libscrip_rt.so" ] && [ -f "$W/out/scrip-ipp" ] || red="$red arm1:artifacts-missing"
if [ -x "$W/scrip" ]; then
    printf "\tOUTPUT = 'fetched'\nEND\n" > "$T/t.sno"
    out="$( cd "$T" && timeout -k 5 60 "$W/scrip" t.sno < /dev/null 2>/dev/null )"
    [ "$out" = "fetched" ] || red="$red arm1:fetched-scrip-does-not-run(got '$out')"
    ( cd "$W" && bash "$T/wt/harness/scripts/util_require_fresh.sh" --gate "$NAME" > "$T/fresh.log" 2>&1 ) || red="$red arm1:freshness-guard-refuses-the-fetched-binary"
    grep -q '^source FETCHED' "$W/out/buildinfo" 2>/dev/null || red="$red arm1:buildinfo-does-not-say-FETCHED"
    foreign="$(grep -l '/SCRIP/' "$W"/out/rt_pic-*/*.d 2>/dev/null | xargs -r grep -lE "(^|[[:space:]])/[^[:space:]]*/SCRIP/" 2>/dev/null | xargs -r grep -LE "(^|[[:space:]])$W/" 2>/dev/null | wc -l)"
    foreign2="$(grep -lE "(^|[[:space:]])/[^[:space:]]*/SCRIP/" "$W"/out/rt_pic-*/*.d 2>/dev/null | xargs -r grep -lE "(^|[[:space:]])/[^[:space:]]*/SCRIP/" | xargs -r awk -v w="$W/" 'BEGIN{n=0} {for(i=1;i<=NF;i++) if ($i ~ /^\/.*\/SCRIP\//) { if (index($i, w)!=1) n++ } } END{print n+0}')"
    [ "${foreign2:-0}" = 0 ] || red="$red arm1:fetched-.d-files-name-$foreign2-paths-in-another-SCRIP-tree(a-header-edit-here-would-not-rebuild-them)"
    rt="$(ldd "$W/scrip" 2>/dev/null | awk '/libscrip_rt/ {print $3}')"
    case "$rt" in "$W"/out/libscrip_rt.so) ;; *) red="$red arm1:fetched-scrip-loads-another-roots-runtime($rt)";; esac
fi
# arm 2: idempotent
if [ "$fetched" = 1 ]; then
    : > "$T/compiles"
    ( cd "$W" && PATH="$T/shim:$PATH" timeout -k 5 600 make > "$T/make2.log" 2>&1 ) || red="$red arm2:second-make-rc"
    grep -q "^FETCHED $key (already in place)" "$T/make2.log" || red="$red arm2:no-already-in-place-line"
    [ -s "$T/compiles" ] && red="$red arm2:compiler-started"
fi
# arm 3: a dirty worktree fetches nothing and publishes nothing
n0="$(ls -d "$T/cache"/*/ 2>/dev/null | wc -l)"
printf '\n' >> "$W/src/driver/scrip.c"
if bash "$BC" fetch --root "$W" --tag "$TAG" > "$T/dirty_fetch.log" 2>&1; then red="$red arm3:dirty-fetch-succeeded"; else grep -q DIRTY "$T/dirty_fetch.log" || red="$red arm3:dirty-fetch-refused-for-another-reason"; fi
bash "$BC" publish --root "$W" --tag "$TAG" > "$T/dirty_pub.log" 2>&1
n1="$(ls -d "$T/cache"/*/ 2>/dev/null | wc -l)"
[ "$n0" = "$n1" ] || red="$red arm3:dirty-publish-stored-an-entry"
grep -q "DIRTY tree, nothing published" "$T/dirty_pub.log" || red="$red arm3:dirty-publish-did-not-say-so"
git -C "$W" checkout -q -- src/driver/scrip.c
# arm 4: another tag, another key
if bash "$BC" fetch --root "$W" --tag deadbeef00 > "$T/tag_fetch.log" 2>&1; then red="$red arm4:other-tag-fetched"; else grep -q MISS "$T/tag_fetch.log" || red="$red arm4:other-tag-refused-for-another-reason"; fi
echo "BUILD_CACHE_FETCH_BOARD fetched=$fetched compiles=$compiles key=$key entries=$n1 (tree $(git -C "$SC" rev-parse --short HEAD))"
if [ -z "$red" ]; then echo "GATE OK [$NAME]: a clean worktree fetched $key from the cache, started no compiler, runs, and is fresh; a dirty tree fetched nothing and published nothing"; exit 0; fi
echo "GATE FAIL [$NAME]:$red"; exit 1
