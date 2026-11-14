#!/usr/bin/env bash
# s4e_take.sh -- A ROOT HOLDS corpus, harness OR .github ONLY WHILE IT CARRIES A CHANGE TO IT (the cio 2026-11-14, row harness-one-disk-step-6-the-cutover; Lon,
# in the cio's window, verbatim: "We are meant not to have folder .github, harness, and corpus in each /home/claude folder, but they have not been cleaned out.
# Complete the new disk/file layout."). A seat root is its SCRIP clone, .claude and CLAUDE.md; corpus, harness and .github live once, at /home/corpus,
# /home/harness and /home/.github, which nobody edits. MEASURED before this tool: nothing said where a seat edits one of the three once its root holds none, and
# every bug row adds a corpus witness. THE RULE: the seat takes its own clone into its root, edits and commits there, and lands from the root as ever
# (s4e_land.sh --row <topic>); the landing drops the clone once it stands clean at origin, so the folder is there only for the life of the change.
#   s4e_take.sh corpus|harness|.github      make <root>/<repo>: a clone at origin/main that borrows the one-disk checkout's objects (no object copied), origin
#                                           github, marked s4e.taken; its clean files are linked to the read-only pristine when there is one (no bytes copied)
#   s4e_take.sh drop corpus|harness|.github remove it; refuses rc 1, naming what would be lost, while it holds an edit, an untracked file, a stash or a commit
#                                           origin/main lacks (drop --landed is the lander's call after its push: the same checks, quiet when there is nothing to drop)
#   s4e_take.sh list                        the repos this root holds, each with what it carries
#   s4e_take.sh --probe                     five arms on a scratch origin, one-disk top and root; nothing live touched. TAKE probe ok|RED
# WHILE THE ROOT HOLDS ONE, EVERY TOOL READS IT: lib_paths.sh and harness_paths.py name a root's own clone before the one-disk checkout, so the seat's runs grade
# its own change with no variable set. The root is S4E_HOME; the one-disk top is /home (S4E_ONE_DISK_TOP names another, the probe's seam).
# rc 0 done; 1 refused by a measurement (it exists, it holds work); 2 usage or cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP="${S4E_ONE_DISK_TOP:-/home}"; SHARED="${S4E_SHARED:-/home/resources/shared}"
die() { echo "$1" >&2; exit "${2:-2}"; }
repo_ok() { case "$1" in corpus|harness|.github) return 0 ;; esac; return 1; }
carries() {   # <clone>: what a removal would lose, one word each; empty when nothing
    local d="$1" out="" b
    [ -z "$(git -C "$d" status --porcelain 2>/dev/null | head -1)" ] || out="$out edits-or-untracked-files"
    [ -z "$(git -C "$d" stash list 2>/dev/null | head -1)" ] || out="$out stash"
    for b in HEAD $(git -C "$d" for-each-ref --format='%(refname)' refs/heads 2>/dev/null); do
        [ -z "$(git -C "$d" cherry origin/main "$b" 2>/dev/null | grep '^+' | head -1)" ] || { out="$out unlanded-commits(${b#refs/heads/})"; }
    done
    printf '%s' "$out"
}
take() {
    local r="$1" home="${S4E_HOME:-}" src d tmp url lo
    [ -n "$home" ] && [ -d "$home" ] || die "REFUSE(2): S4E_HOME is not a root ($home)" 2
    src="$TOP/$r"; d="$home/$r"; tmp="$home/.$r.take.$$"
    [ -d "$src/.git" ] || die "REFUSE(2): no one-disk checkout at $src to borrow from" 2
    [ ! -e "$d" ] || die "REFUSE(1): $d exists already -- it carries:$(carries "$d") (s4e_take.sh list; land it, or s4e_take.sh drop $r)" 1
    url="$(git -C "$src" remote get-url origin 2>/dev/null)" || die "REFUSE(2): $src has no origin" 2
    git clone -q --shared --no-checkout "$src" "$tmp" 2>/dev/null || { rm -rf "$tmp"; die "REFUSE(2): the clone of $src failed" 2; }
    git -C "$tmp" remote set-url origin "$url" && git -C "$tmp" config s4e.taken true && git -C "$tmp" config core.trustctime false \
        && git -C "$tmp" update-ref refs/remotes/origin/main "$(git -C "$src" rev-parse refs/remotes/origin/main 2>/dev/null || git -C "$src" rev-parse HEAD)" \
        && git -C "$tmp" checkout -q -B main refs/remotes/origin/main && git -C "$tmp" branch -q --set-upstream-to=origin/main main \
        || { rm -rf "$tmp"; die "REFUSE(2): the checkout of $r at origin/main failed" 2; }
    mv "$tmp" "$d" || { rm -rf "$tmp"; die "REFUSE(2): cannot name $d" 2; }
    lo="copies"
    if [ -d "$SHARED/$r/.git" ] && [ "$(stat -c %d "$d")" = "$(stat -c %d "$SHARED")" ] && [ -f "$HERE/util_relink_root.py" ]; then
        bash "$HERE/util_shared_pristine.sh" update > /dev/null 2>&1
        lo="$(python3 -I "$HERE/util_relink_root.py" "$home" --repo "$r" --pristine "$SHARED" 2>&1 | grep -oE 'linked=[0-9]+' | head -1)"; lo="${lo:-copies}"
    fi
    echo "TAKEN $d at $(git -C "$d" rev-parse --short=10 HEAD) (origin/main; objects borrowed from $src; files $lo). Edit and commit here; land with s4e_land.sh --row <topic>; the landing drops it."
}
drop() {
    local r="$1" landed="$2" home="${S4E_HOME:-}" d c
    [ -n "$home" ] && [ -d "$home" ] || die "REFUSE(2): S4E_HOME is not a root ($home)" 2
    d="$home/$r"
    if [ ! -d "$d/.git" ]; then [ "$landed" = 1 ] && exit 0; die "REFUSE(1): $home holds no $r" 1; fi
    if [ "$landed" = 1 ] && [ "$(git -C "$d" config --get s4e.taken 2>/dev/null)" != true ]; then exit 0; fi   # the lander drops only what take made
    [ -d "$TOP/$r/.git" ] || die "REFUSE(2): no one-disk checkout at $TOP/$r: dropping $d would leave this root with no $r" 2
    c="$(carries "$d")"
    if [ -n "$c" ]; then [ "$landed" = 1 ] && { echo "KEPT $d: it still carries:$c"; exit 0; }; die "REFUSE(1): $d carries:$c -- land it (s4e_land.sh --row <topic>) or save it first; nothing removed" 1; fi
    if [ -n "$(ls "$d/.git/worktrees" 2>/dev/null | head -1)" ]; then git -C "$d" worktree prune 2>/dev/null; [ -z "$(ls "$d/.git/worktrees" 2>/dev/null | head -1)" ] || die "REFUSE(1): $d has a live worktree; nothing removed" 1; fi
    case "$d" in "$home"/corpus|"$home"/harness|"$home"/.github) rm -rf "$d" ;; *) die "REFUSE(2): $d is not a repo folder of $home" 2 ;; esac
    echo "DROPPED $d (clean at origin/main; this root reads $TOP/$r again)"
}
list() {
    local home="${S4E_HOME:-}" r n=0
    [ -n "$home" ] && [ -d "$home" ] || die "REFUSE(2): S4E_HOME is not a root ($home)" 2
    for r in corpus harness .github; do
        [ -d "$home/$r/.git" ] || continue
        n=$((n + 1)); echo "HELD $home/$r head=$(git -C "$home/$r" rev-parse --short=10 HEAD 2>/dev/null) taken=$(git -C "$home/$r" config --get s4e.taken 2>/dev/null || echo no) carries:$(c="$(carries "$home/$r")"; echo "${c:- nothing}")"
    done
    [ "$n" -gt 0 ] || echo "HELD none: $home reads corpus, harness and .github from $TOP"
}
probe() {
    local T why="" o rc g="git -c user.name=probe -c user.email=probe@localhost -c init.defaultBranch=main" me="$HERE/s4e_take.sh" un="env -u S4E_SCRIP -u S4E_CORPUS -u S4E_HARNESS -u S4E_GITHUB"
    T="$(mktemp -d "/tmp/s4e/${S4E_SEAT:-seat}/take-probe.XXXXXX" 2>/dev/null || mktemp -d)" || die "REFUSE(2): no scratch" 2
    mkdir -p "$T/top" "$T/home" && $g init -q --bare "$T/origin.git" && $g clone -q "$T/origin.git" "$T/top/corpus" 2>/dev/null \
        && echo a > "$T/top/corpus/a" && $g -C "$T/top/corpus" add a && $g -C "$T/top/corpus" commit -qm a && $g -C "$T/top/corpus" push -q origin HEAD:main 2>/dev/null \
        && $g -C "$T/top/corpus" fetch -q origin || { rm -rf "$T"; die "REFUSE(2): cannot plant the scratch origin" 2; }
    run() { $un S4E_ONE_DISK_TOP="$T/top" S4E_SHARED="$T/none" S4E_HOME="$T/home" "$@"; }
    o="$(run bash "$me" corpus 2>&1)"; rc=$?
    [ "$rc" = 0 ] && [ "$(git -C "$T/home/corpus" rev-parse HEAD 2>/dev/null)" = "$(git -C "$T/top/corpus" rev-parse HEAD)" ] && [ "$(cat "$T/home/corpus/.git/objects/info/alternates" 2>/dev/null)" = "$T/top/corpus/.git/objects" ] \
        && [ -z "$(find "$T/home/corpus/.git/objects" -name '*.pack' 2>/dev/null | head -1)" ] || why="$why arm 1: take did not make a clone at origin/main that borrows the checkout's objects (rc $rc: $(printf '%s' "$o" | tail -1 | cut -c1-120));"
    o="$(run bash "$HERE/lib_paths.sh" --show 2>&1)"; case "$o" in *"S4E_CORPUS=$T/home/corpus (own)"*) ;; *) why="$why arm 2: lib_paths.sh does not read the root's own clone ($o);" ;; esac
    o="$(run python3 -I "$HERE/harness_paths.py" --show 2>&1)"; case "$o" in *"S4E_CORPUS=$T/home/corpus (own)"*) ;; *) why="$why arm 2: harness_paths.py does not read the root's own clone ($o);" ;; esac
    echo b > "$T/home/corpus/b" && $g -C "$T/home/corpus" add b && $g -C "$T/home/corpus" commit -qm b
    o="$(run bash "$me" drop corpus 2>&1)"; rc=$?
    [ "$rc" = 1 ] && [ -d "$T/home/corpus" ] && printf '%s' "$o" | grep -q 'unlanded-commits' || why="$why arm 3: drop did not refuse a clone holding an unlanded commit (rc $rc);"
    o="$(run bash "$me" drop --landed corpus 2>&1)"; rc=$?
    [ "$rc" = 0 ] && [ -d "$T/home/corpus" ] || why="$why arm 3: drop --landed removed or failed on a clone holding an unlanded commit (rc $rc);"
    $g -C "$T/home/corpus" push -q origin HEAD:main 2>/dev/null && $g -C "$T/home/corpus" fetch -q origin && $g -C "$T/top/corpus" pull -q --ff-only origin main 2>/dev/null
    o="$(run bash "$me" drop --landed corpus 2>&1)"; rc=$?
    [ "$rc" = 0 ] && [ ! -e "$T/home/corpus" ] || why="$why arm 4: drop --landed kept a clone clean at origin/main (rc $rc: $(printf '%s' "$o" | tail -1 | cut -c1-120));"
    o="$(run bash "$HERE/lib_paths.sh" --show 2>&1)"; case "$o" in *"S4E_CORPUS=$T/top/corpus (one-disk)"*) ;; *) why="$why arm 5: after the drop lib_paths.sh does not read the one-disk checkout ($o);" ;; esac
    [ -f "$T/top/corpus/b" ] || why="$why arm 5: the one-disk checkout does not hold the landed change;"
    $g clone -q "$T/origin.git" "$T/home/corpus" 2>/dev/null   # a clone take did not make: the lander leaves it
    o="$(run bash "$me" drop --landed corpus 2>&1)"; rc=$?
    [ "$rc" = 0 ] && [ -d "$T/home/corpus" ] || why="$why arm 5: drop --landed removed a clone take did not make (rc $rc);"
    if [ -z "$why" ]; then rm -rf "$T"; echo "TAKE probe ok arms=5 (take makes a root's own clone at origin/main borrowing the one-disk objects; lib_paths.sh and harness_paths.py read it while the root holds it; drop refuses unlanded work; the landed drop removes a clean clone and the root reads the one-disk checkout again; a clone take did not make is left)"; return 0; fi
    echo "TAKE probe RED:$why"; echo "    kept: $T"; return 1
}
case "${1:-}" in
    --probe) probe; exit $? ;;
    list) list ;;
    drop) shift; landed=0; [ "${1:-}" = --landed ] && { landed=1; shift; }; repo_ok "${1:-}" || die "usage: s4e_take.sh drop [--landed] corpus|harness|.github" 2; drop "$1" "$landed" ;;
    corpus|harness|.github) take "$1" ;;
    *) die "usage: s4e_take.sh corpus|harness|.github | drop corpus|harness|.github | list | --probe" 2 ;;
esac
