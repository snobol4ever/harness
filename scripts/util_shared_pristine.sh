#!/usr/bin/env bash
# util_shared_pristine.sh -- THE PRISTINE CHECKOUTS EVERY SEAT LINKS ITS FILES TO (the cio 2026-11-12, row fleet-32-16-8-4-shared-repos; Lon,
# 16:3x in the coo's window, verbatim: "Can not ALL the seats share a corpus repo?" / "We should save huge space this way.").
#
#   util_shared_pristine.sh init   [repo ...]   clone each repo --shared from the coo root (its objects borrowed, none copied), at origin/main
#   util_shared_pristine.sh update [repo ...]   fetch and fast-forward each one to origin/main, under one lock (any seat may be the updater)
#   util_shared_pristine.sh status [repo ...]   print each one's HEAD, its dirty count and its writable tracked files
#
# repos: corpus harness .github (the default: all three). S4E_SHARED names the directory (default /home/resources/shared), S4E_SHARED_FROM the
# root whose objects they borrow (default /home/claude_coo). Every tracked regular file of a pristine is READ-ONLY: util_relink_root.py makes a
# seat's clean file a hard link to it, so an in-place write anywhere fails loudly instead of writing into every seat (MEASURED 2026-11-12: git's
# own checkout replaces a file by a new inode, so a pull in a seat or here never writes through a link). A pristine is never edited: one that
# reads dirty refuses rc 2 and is not moved. Only a file that is writable is chmodded, so an unchanged file keeps its ctime and no seat's git
# re-reads it.
# EXIT: 0 done, 2 REFUSED (no source repo, a dirty pristine, a fetch or merge that failed).
set -uo pipefail
SH="${S4E_SHARED:-/home/resources/shared}"; SRC="${S4E_SHARED_FROM:-/home/claude_coo}"
cmd="${1:-}"; shift 2>/dev/null
repos=("$@"); [ "${#repos[@]}" -gt 0 ] || repos=(corpus harness .github)
refuse() { echo "REFUSE(2) [shared-pristine]: $*"; exit 2; }
readonly_all() {   # dir -> every tracked regular file that is writable loses its write bits; prints how many
    git -C "$1" ls-files -s -z | python3 -I -c '
import os, stat, sys
d = sys.argv[1]; n = 0
for rec in sys.stdin.buffer.read().split(b"\0"):
    if not rec:
        continue
    meta, _, path = rec.partition(b"\t")
    mode, _, stage = meta.split(b" ")
    if stage != b"0" or mode not in (b"100644", b"100755"):
        continue
    p = os.path.join(d.encode(), path)
    try:
        st = os.lstat(p)
    except FileNotFoundError:
        continue
    if stat.S_ISREG(st.st_mode) and st.st_mode & 0o222:
        os.chmod(p, st.st_mode & ~0o222); n += 1
print(n)' "$1"
}
case "$cmd" in
    init)
        mkdir -p "$SH" || refuse "cannot make $SH"
        for r in "${repos[@]}"; do
            p="$SH/$r"
            if [ -e "$p/.git" ]; then echo "PRISTINE $r exists at $p (init leaves it; update moves it)"; continue; fi
            [ -d "$SRC/$r/.git" ] || refuse "$SRC/$r is not a repo"
            git clone -q --shared --no-checkout "$SRC/$r" "$p" || refuse "clone --shared $SRC/$r failed"
            git -C "$p" remote set-url origin "$(git -C "$SRC/$r" remote get-url origin)" || refuse "$r: no origin url in $SRC/$r"
            git -C "$p" fetch -q origin && git -C "$p" checkout -q -B main origin/main || refuse "$r: fetch or checkout of origin/main failed"
            echo "PRISTINE $r init at $p head=$(git -C "$p" rev-parse --short=9 HEAD) readonly_set=$(readonly_all "$p")"
        done ;;
    update)
        mkdir -p "$SH" || refuse "no $SH"
        exec 9> "$SH/.update.flock"; flock 9
        for r in "${repos[@]}"; do
            p="$SH/$r"; [ -e "$p/.git" ] || refuse "no pristine $p (init makes it)"
            [ -z "$(git -C "$p" status --porcelain --untracked-files=no)" ] || refuse "$p reads dirty: a pristine is never edited; find the writer"
            old="$(git -C "$p" rev-parse HEAD)"
            git -C "$p" fetch -q origin && git -C "$p" merge -q --ff-only origin/main || refuse "$r: fetch or fast-forward failed"
            echo "PRISTINE $r ${old:0:9}..$(git -C "$p" rev-parse --short=9 HEAD) readonly_set=$(readonly_all "$p")"
        done ;;
    status)
        for r in "${repos[@]}"; do
            p="$SH/$r"; [ -e "$p/.git" ] || { echo "PRISTINE $r absent"; continue; }
            w="$(git -C "$p" ls-files -z | (cd "$p" && xargs -0 -r find 2>/dev/null -maxdepth 0 -type f -perm /222) | wc -l)"
            echo "PRISTINE $r head=$(git -C "$p" rev-parse --short=9 HEAD) dirty=$(git -C "$p" status --porcelain --untracked-files=no | wc -l) writable=$w"
        done ;;
    *) refuse "usage: util_shared_pristine.sh init|update|status [corpus|harness|.github ...]" ;;
esac
