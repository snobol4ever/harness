#!/usr/bin/env bash
# s4e_worktree.sh -- ONE WHOLE-ROOT WORKTREE IN ONE COMMAND (box-scheduler step 36, CTO-503; the design text is the shared-box skill's DESIGN section 8).
#
#   s4e_worktree.sh new <name> [--base <ref>] [--lang <l1,l2>] [--cap-mb <n>]     (alias add)
#   s4e_worktree.sh rm <name>                                                      (alias remove)
#   s4e_worktree.sh list
#   s4e_worktree.sh --probe
#
# new makes /tmp/s4e/<seat>/wt-<name>/{SCRIP,harness,corpus,.github}: detached git worktrees of this root's four checkouts at the base (default
# origin/main, as the root last fetched it; new fetches nothing, so a seat syncs first). The corpus is full unless --lang names languages: then it is
# sparse to tests/<lang>/ and tests/shared/ and the root files. The build is FETCHED from the build cache for the worktree's own HEAD tree and RT_TAG
# (util_build_cache.sh fetch); a worktree never builds. The size (du -sm of the whole worktree, the fetched build included) must be at or under the
# cap (4096 MB by default; --cap-mb names another): over the cap new rolls back and refuses. A build that does not fetch keeps the worktree, so a
# seat can run make in it, and refuses rc 1.
# rm removes only what new made: the marker .s4e-worktree in the directory is the proof; each repo's git worktree is removed from its root repo,
# then the directory. list prints every worktree new made and how many of its four are still registered.
# --probe makes one whole-root worktree at origin/main, prints its line and removes it: the proof that step 36 reads green.
# THE LINE: WORKTREE repos=4 build=fetched size_mb=N cap_mb=C corpus=full|sparse:<langs> path=<wt>
# rc 0 made, removed or listed; rc 1 refused by a measurement (no build fetched, over the cap, a name taken, no such worktree); rc 2 usage or cannot measure.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
REPOS="SCRIP harness corpus .github"
CAP_MB=4096
TOP=/tmp/s4e
SEAT="${S4E_SEAT:-}"

die() { echo "$1" >&2; exit "${2:-2}"; }
valid_name() { case "$1" in ""|.*|*[!A-Za-z0-9._-]*) return 1 ;; esac; return 0; }
[ -n "$SEAT" ] || die "REFUSE(2): S4E_SEAT unset -- the worktrees live under $TOP/<seat>/" 2
SEATDIR="$TOP/$SEAT"

drop() {
    local wt="$1" marker="$1/.s4e-worktree" r
    case "$wt" in "$SEATDIR"/wt-?*) ;; *) die "REFUSE(2): $wt is not under $SEATDIR/wt-<name>" 2 ;; esac
    [ -f "$marker" ] || die "REFUSE(1): $wt has no $marker -- new did not make it, so rm leaves it alone" 1
    for r in $REPOS; do
        grep -qx "repo=$r" "$marker" || continue
        git -C "$ROOT/$r" worktree remove --force --force "$wt/$r" >/dev/null 2>&1
        rm -rf "$wt/$r"
        git -C "$ROOT/$r" worktree prune >/dev/null 2>&1
    done
    rm -rf "$wt"
}

new_wt() {
    local name="$1" base="$2" langs="$3" cap="$4" wt corpus_mode=full r l sha made rt fo b size
    local -a pats=()
    wt="$SEATDIR/wt-$name"
    valid_name "$name" || die "REFUSE(2): name '$name' must be [A-Za-z0-9._-], not dot-led" 2
    [ -e "$wt" ] && die "REFUSE(1): $wt exists -- rm $name first" 1
    for r in $REPOS; do
        git -C "$ROOT/$r" rev-parse -q --verify "$base^{commit}" >/dev/null 2>&1 || die "REFUSE(2): base '$base' is not a commit in $ROOT/$r" 2
    done
    if [ -n "$langs" ]; then
        corpus_mode="sparse:$langs"
        for l in $(printf '%s' "$langs" | tr ',' ' '); do
            case "$l" in ""|*[!a-z0-9_]*) die "REFUSE(2): language '$l' must be [a-z0-9_]+" 2 ;; esac
            [ -n "$(git -C "$ROOT/corpus" ls-tree -d "$base" -- "tests/$l")" ] || die "REFUSE(2): corpus at $base has no tests/$l" 2
            pats+=("/tests/$l/")
        done
        pats+=(/tests/shared/ /README.md /LICENSE /NOTICE /.gitignore)
    fi
    mkdir -p "$wt" || die "REFUSE(2): cannot make $wt" 2
    sha="$(git -C "$ROOT/SCRIP" rev-parse --short=12 "$base^{commit}")"
    made="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    {
        printf 'name=%s\nseat=%s\nbase=%s\nsha=%s\nmade=%s\ncorpus=%s\n' "$name" "$SEAT" "$base" "$sha" "$made" "$corpus_mode"
        for r in $REPOS; do printf 'repo=%s\n' "$r"; done
    } > "$wt/.s4e-worktree"
    for r in $REPOS; do
        if [ "$r" = corpus ] && [ -n "$langs" ]; then
            git -C "$ROOT/$r" worktree add -q --no-checkout --detach "$wt/$r" "$base" \
                && git -C "$wt/$r" sparse-checkout set --no-cone "${pats[@]}" \
                && git -C "$wt/$r" reset -q --hard \
                || { drop "$wt"; die "REFUSE(2): could not make the sparse corpus worktree" 2; }
        else
            git -C "$ROOT/$r" worktree add -q --detach "$wt/$r" "$base" \
                || { drop "$wt"; die "REFUSE(2): git worktree add $r failed" 2; }
        fi
    done
    rt="$(cd "$wt/SCRIP" && env -u MAKEFLAGS -u MFLAGS -u MAKELEVEL make -s --no-print-directory --eval='s4e-print-rt-tag: ; @echo $(RT_TAG)' s4e-print-rt-tag 2>/dev/null)" || rt=""
    [ -n "$rt" ] || { drop "$wt"; die "REFUSE(2): make could not print RT_TAG in $wt/SCRIP" 2; }
    fo="$(bash "$ROOT/harness/scripts/util_build_cache.sh" fetch --root "$wt/SCRIP" --tag "$rt" 2>&1)"
    b=not-fetched
    if grep -q '^FETCHED ' <<<"$fo" && [ -x "$wt/SCRIP/scrip" ] && [ -f "$wt/SCRIP/out/libscrip_rt.so" ]; then b=fetched; fi
    size="$(du -sm "$wt" | cut -f1)"
    if [ "$size" -gt "$cap" ]; then
        drop "$wt"
        echo "WORKTREE repos=4 build=$b OVER-CAP size_mb=$size cap_mb=$cap corpus=$corpus_mode path=$wt (rolled back)"
        die "REFUSE(1): the worktree is ${size} MB, over the ${cap} MB cap -- name --lang to sparse the corpus" 1
    fi
    echo "WORKTREE repos=4 build=$b size_mb=$size cap_mb=$cap corpus=$corpus_mode path=$wt"
    [ "$b" = fetched ] && exit 0
    echo "$fo" >&2
    echo "NOT FETCHED: the worktree stays, so a seat can run make in $wt/SCRIP under a run slot; the reason is above" >&2
    exit 1
}

probe() {
    local name="probe-$(date -u +%H%M%S)-$$" wt out rc
    wt="$SEATDIR/wt-$name"
    out="$(new_wt "$name" origin/main "" "$CAP_MB" 2>&1)"; rc=$?
    printf '%s\n' "$out"
    [ -e "$wt" ] && drop "$wt"
    [ -e "$wt" ] && { echo "PROBE removed=no path=$wt"; exit 1; }
    echo "PROBE removed=yes"
    exit "$rc"
}

list_wts() {
    local m wt n b made c reg r found=0
    for m in "$SEATDIR"/wt-*/.s4e-worktree; do
        [ -f "$m" ] || continue
        found=1
        wt="${m%/.s4e-worktree}"
        n="$(sed -n 's/^name=//p' "$m")"; b="$(sed -n 's/^base=//p' "$m")"; made="$(sed -n 's/^made=//p' "$m")"; c="$(sed -n 's/^corpus=//p' "$m")"
        reg=0
        for r in $REPOS; do
            git -C "$ROOT/$r" worktree list --porcelain | grep -Fqx "worktree $wt/$r" && reg=$((reg + 1))
        done
        echo "WORKTREE-LIST name=$n base=$b made=$made corpus=$c registered=$reg/4 path=$wt"
    done
    [ "$found" = 1 ] || echo "WORKTREE-LIST none under $SEATDIR"
    exit 0
}

verb="${1:-}"; [ $# -gt 0 ] && shift
base=origin/main; langs=""; cap=$CAP_MB; name=""
case "$verb" in
    --probe) probe ;;
    list) list_wts ;;
    new|add|rm|remove)
        name="${1:-}"; [ $# -gt 0 ] && shift
        while [ $# -gt 0 ]; do
            case "$1" in
                --base) [ $# -ge 2 ] || die "usage: --base <ref>" 2; base="$2"; shift 2 ;;
                --lang) [ $# -ge 2 ] || die "usage: --lang <l1,l2>" 2; langs="$2"; shift 2 ;;
                --cap-mb) [ $# -ge 2 ] || die "usage: --cap-mb <n>" 2; cap="$2"; shift 2 ;;
                *) die "usage: s4e_worktree.sh new <name> [--base <ref>] [--lang <l1,l2>] [--cap-mb <n>] | rm <name> | list | --probe" 2 ;;
            esac
        done
        valid_name "$name" || die "REFUSE(2): a name is required, [A-Za-z0-9._-], not dot-led" 2
        ;;
    *) die "usage: s4e_worktree.sh new <name> [--base <ref>] [--lang <l1,l2>] [--cap-mb <n>] | rm <name> | list | --probe" 2 ;;
esac
case "$verb" in
    new|add)
        case "$cap" in ""|*[!0-9]*) die "REFUSE(2): --cap-mb needs a number of MB" 2 ;; esac
        new_wt "$name" "$base" "$langs" "$cap" ;;
    rm|remove)
        wt="$SEATDIR/wt-$name"
        [ -d "$wt" ] || die "REFUSE(1): no worktree $name under $SEATDIR" 1
        drop "$wt"
        [ -e "$wt" ] && die "REFUSE(1): $wt is still there after drop" 1
        echo "REMOVED wt-$name path=$wt"; exit 0 ;;
esac
