#!/usr/bin/env bash
# util_build_cache.sh -- ONE BUILD PER TREE (the cto, ARCH-SHARED-DEVELOPMENT.md section 3.2, CEO-2041 step 6; Lon 2026-10-31: "Everyone is
# compiling at the same time"). A SCRIP build is a pure function of (the SCRIP tree, the runtime flags, the toolchain), so the first clean build
# of a tree publishes its artifacts under /home/resources/builds/scrip/<key>/ and every other root at the same tree copies them in with `make`
# and compiles nothing. The Makefile's `all` calls `fetch` first and `publish` after a successful build; nothing else changes.
#
#   util_build_cache.sh key     --root SCRIP --tag RT_TAG          print the key (sha256 of HEAD^{tree}, RT_TAG, gcc and ccache versions)
#   util_build_cache.sh fetch   --root SCRIP --tag RT_TAG          rc 0 and `FETCHED <key>` when the entry was copied in (or is in place already);
#                                                                  rc 1 and one reason line otherwise (DIRTY, MISS, OFF, NO-CACHE-DIR)
#   util_build_cache.sh publish --root SCRIP --tag RT_TAG          after a successful build: on a clean tree whose key is absent, copy the
#                                                                  artifacts into a temp dir and rename it into place; the second writer drops its
#                                                                  copy; prints PUBLISHED <key> or one reason; ALWAYS rc 0 (a cache never fails a build)
#   util_build_cache.sh status  --root SCRIP --tag RT_TAG          key, cleanliness, hit or miss, the entry count
#
# THE CLEAN TEST: `git status --porcelain` shows no tracked change and no untracked file under src/, bootstrap/ or the Makefile; a dirty tree
# computes locally and stores nothing (section 3.1). THE ARTIFACTS: what `make all` writes (scrip, out/scrip-ipp, out/libscrip_rt-<tag>.so,
# out/libscrip_rt.so, out/rt_pic-<tag>/*.o and *.d) plus, when the producer built them, the stage-0 pair, the seven parser modules and their
# sc_mod inputs. COPIES, NOT HARD LINKS: the Makefile's canonical-name recipes `rm -f && cp -f` and the assembler writes an object in place, so a
# shared inode would be corrupted by the first dirty rebuild in any root; a copy costs about 120 MB of I/O and no CPU. The fetched files are
# touched newer than every source, so make's own rules and the freshness guard (gate_require_fresh, mtime against the newest tracked source)
# read them as a build of this tree; out/buildinfo records key, tree, toolchain and FETCHED|BUILT. RETENTION: the newest 60 entries by last use
# (<key>/.used, touched at every fetch), pruned at publish. S4E_NO_BUILD_CACHE=1 turns both directions off (the control arm);
# S4E_BUILD_CACHE_DIR points a gate at a scratch cache. Never a symlink (CEO-1817). THE RPATH: a published or fetched binary must name its runtime as $ORIGIN-relative
# (the Makefile since 2026-10-31 16:5x); an absolute rpath is the producer's root, so such an entry is neither published nor fetched (found on the cqo's root, which ran another seat's runtime).
set -u
CACHE="${S4E_BUILD_CACHE_DIR:-/home/resources/builds/scrip}"
KEEP=60
verb="${1:-}"; shift || true
root=""; tag=""
while [ $# -gt 0 ]; do
    case "$1" in
        --root) root="${2:-}"; shift 2 ;;
        --tag) tag="${2:-}"; shift 2 ;;
        *) echo "util_build_cache.sh: unknown argument $1" >&2; exit 2 ;;
    esac
done
[ -n "$verb" ] && [ -n "$root" ] && [ -n "$tag" ] || { echo "usage: util_build_cache.sh key|fetch|publish|status --root SCRIP --tag RT_TAG" >&2; exit 2; }
root="$(cd "$root" 2>/dev/null && pwd -P)" || { echo "util_build_cache.sh: no root" >&2; exit 2; }
tree="$(git -C "$root" rev-parse HEAD^{tree} 2>/dev/null)" || tree=""
tool="$(gcc --version 2>/dev/null | head -1)|$(ccache --version 2>/dev/null | head -1)"
FORMAT=2   # 2: fetched .d files are re-rooted and the entry carries its producer root (2026-10-31 17:4x); a bump makes every root miss once
key="$(printf '%s|%s|%s|format%s\n' "$tree" "$tag" "$tool" "$FORMAT" | sha256sum | cut -c1-40)"
clean() {
    [ -n "$tree" ] || return 1
    [ -z "$(git -C "$root" status --porcelain 2>/dev/null | grep -v '^?? ')" ] || return 1
    [ -z "$(git -C "$root" status --porcelain --untracked-files=all -- src bootstrap Makefile 2>/dev/null | grep '^?? ')" ] || return 1
    return 0
}
rpath_is_own() {   # <binary> -- rc 0 when every rpath entry is $ORIGIN-relative (a fetched binary must find ITS root's out/, never its producer's)
    local r; r="$(readelf -d "$1" 2>/dev/null | sed -n 's/.*(R\(UN\)\?PATH).*\[\(.*\)\].*/\2/p' | tr ':' '\n' | grep -v '^\$ORIGIN' | grep -c .)"
    [ "${r:-0}" = 0 ]
}
required="scrip out/scrip-ipp out/libscrip_rt-$tag.so out/libscrip_rt.so"
optional="out/scrip0 out/libscrip_rt0.so"
for l in snobol4 snocone rebus icon prolog pascal raku; do optional="$optional out/libscrip_parser_$l-$tag.so out/libscrip_parser_$l.so out/sc_mod/scmod_$l.sc out/sc_mod/scmod_$l.o"; done
manifest() {
    local f
    for f in $required; do printf '%s\n' "$f"; done
    for f in $optional; do [ -f "$root/$f" ] && printf '%s\n' "$f"; done
    ( cd "$root" && ls out/rt_pic-"$tag"/*.o out/rt_pic-"$tag"/*.d 2>/dev/null ) || true
}
write_buildinfo() {
    mkdir -p "$1/out"
    printf 'key %s\ntree %s\nrt_tag %s\ntoolchain %s\nsource %s\nroot %s\nutc %s\n' "$key" "$tree" "$tag" "$tool" "$2" "$1" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$1/out/buildinfo"
}
case "$verb" in
    key) echo "$key"; exit 0 ;;
    status)
        c=miss; [ -f "$CACHE/$key/MANIFEST" ] && c=hit
        d=dirty; clean && d=clean
        echo "key=$key tree=${tree:0:12} tag=$tag $d $c entries=$(ls -d "$CACHE"/*/ 2>/dev/null | wc -l) cache=$CACHE"
        exit 0 ;;
    fetch)
        if [ -f "$root/out/scrip0" ] && ! rpath_is_own "$root/out/scrip0"; then echo "build cache: removing the stale out/scrip0 (absolute rpath, fetched before the \$ORIGIN Makefile)"; rm -f "$root/out/scrip0" "$root/out/libscrip_rt0.so"; fi
        [ "${S4E_NO_BUILD_CACHE:-}" = 1 ] && { echo "build cache OFF (S4E_NO_BUILD_CACHE=1)"; exit 1; }
        [ -d "$CACHE" ] || { echo "build cache: NO-CACHE-DIR $CACHE"; exit 1; }
        clean || { [ -f "$root/out/buildinfo" ] && sed -i 's/^source .*/source DIRTY/' "$root/out/buildinfo"; echo "build cache: DIRTY tree, building locally (key $key)"; exit 1; }
        e="$CACHE/$key"
        [ -f "$e/MANIFEST" ] || { echo "build cache: MISS $key"; exit 1; }
        if [ -f "$root/out/buildinfo" ] && [ "$(sed -n 's/^key //p' "$root/out/buildinfo")" = "$key" ] && cmp -s "$e/scrip" "$root/scrip" && cmp -s "$e/out/libscrip_rt.so" "$root/out/libscrip_rt.so" && [ -x "$root/scrip" ] && [ -f "$root/out/libscrip_rt.so" ]; then
            ( cd "$root" && xargs -d '\n' touch < "$e/MANIFEST" 2>/dev/null )
            touch "$e/.used" 2>/dev/null || true
            echo "FETCHED $key (already in place)"; exit 0
        fi
        rpath_is_own "$e/scrip" && rpath_is_own "$e/out/scrip-ipp" || { echo "build cache: entry $key carries an absolute rpath (built before the \$ORIGIN Makefile), building locally"; exit 1; }
        n=0
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            [ -f "$e/$f" ] || { echo "build cache: entry $key lacks $f, building locally"; exit 1; }
            mkdir -p "$root/$(dirname "$f")"
            rm -f "$root/$f"
            cp -p "$e/$f" "$root/$f.fetch.$$" && mv -f "$root/$f.fetch.$$" "$root/$f" || { rm -f "$root/$f.fetch.$$"; echo "build cache: copy of $f failed, building locally"; exit 1; }
            n=$((n + 1))
        done < "$e/MANIFEST"
        grep -l '/SCRIP/' $(sed -n 's/^\(out\/rt_pic-[^/]*\/[^ ]*\.d\)$/\1/p' "$e/MANIFEST" | sed "s|^|$root/|") 2>/dev/null | while IFS= read -r d; do sed -i -E "s#(^|[[:space:]])/[^[:space:]]*/SCRIP/#\1$root/#g" "$d"; done
        ( cd "$root" && xargs -d '\n' touch < "$e/MANIFEST" )
        write_buildinfo "$root" FETCHED
        touch "$e/.used" 2>/dev/null || true
        echo "FETCHED $key ($n files from $e)"
        exit 0 ;;
    publish)
        [ "${S4E_NO_BUILD_CACHE:-}" = 1 ] && { echo "build cache OFF (S4E_NO_BUILD_CACHE=1), nothing published"; exit 0; }
        write_buildinfo "$root" BUILT
        [ -d "$CACHE" ] || mkdir -p "$CACHE" 2>/dev/null || { echo "build cache: NO-CACHE-DIR $CACHE, nothing published"; exit 0; }
        clean || { echo "build cache: DIRTY tree, nothing published"; exit 0; }
        e="$CACHE/$key"
        [ -f "$e/MANIFEST" ] && { echo "build cache: $key already published"; exit 0; }
        for f in $required; do [ -f "$root/$f" ] || { echo "build cache: no $f, nothing published"; exit 0; }; done
        for f in scrip out/scrip-ipp; do rpath_is_own "$root/$f" || { echo "build cache: $f carries an absolute rpath (a binary that would load its producer's runtime in another root), nothing published"; exit 0; }; done
        if [ -f "$root/out/scrip0" ] && ! rpath_is_own "$root/out/scrip0"; then echo "build cache: out/scrip0 carries an absolute rpath (fetched before the \$ORIGIN Makefile; the default make never relinks it), removing it so this build can publish"; rm -f "$root/out/scrip0" "$root/out/libscrip_rt0.so"; fi
        [ -n "$(ls "$root/out/rt_pic-$tag"/*.o 2>/dev/null)" ] || { echo "build cache: no runtime objects under out/rt_pic-$tag, nothing published"; exit 0; }
        t="$CACHE/.tmp.$key.$$"
        rm -rf "$t"; mkdir -p "$t" || { echo "build cache: cannot write $CACHE, nothing published"; exit 0; }
        grep -lE "(^|[[:space:]])/[^[:space:]]*/SCRIP/" "$root"/out/rt_pic-"$tag"/*.d 2>/dev/null | while IFS= read -r d; do sed -i -E "s#(^|[[:space:]])/[^[:space:]]*/SCRIP/#\1$root/#g" "$d"; done
        manifest > "$t/MANIFEST"
        while IFS= read -r f; do
            mkdir -p "$t/$(dirname "$f")"
            cp -p "$root/$f" "$t/$f" || { rm -rf "$t"; echo "build cache: copy of $f failed, nothing published"; exit 0; }
        done < "$t/MANIFEST"
        cp -p "$root/out/buildinfo" "$t/out/buildinfo" && sed -i "s/^key .*/key $key/; s|^root .*|root $root|" "$t/out/buildinfo"
        : > "$t/.used"
        if mv -T "$t" "$e" 2>/dev/null; then
            echo "PUBLISHED $key ($(wc -l < "$e/MANIFEST") files, $(du -sh "$e" | cut -f1))"
        else
            rm -rf "$t"; echo "build cache: $key published by another root meanwhile"
        fi
        ls -1t "$CACHE"/*/.used 2>/dev/null | tail -n +$((KEEP + 1)) | while IFS= read -r u; do rm -rf "$(dirname "$u")"; done
        exit 0 ;;
    *) echo "usage: util_build_cache.sh key|fetch|publish|status --root SCRIP --tag RT_TAG" >&2; exit 2 ;;
esac
