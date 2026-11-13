#!/usr/bin/env bash
# s4e_worktree.sh -- ONE WHOLE-ROOT WORKTREE IN ONE COMMAND (box-scheduler step 36, CTO-503; the design text is the shared-box skill's DESIGN section 8).
#
#   s4e_worktree.sh new <name> [--base <ref>] [--lang <l1,l2>] [--full] [--link] [--cap-mb <n>] [--row <topic>]   (alias add)
#   s4e_worktree.sh rm <name>                                                                    (alias remove)
#   s4e_worktree.sh list
#   s4e_worktree.sh --probe
#   s4e_worktree.sh --probe-sweep-land                                                           (the sweep keeps a worktree a lander holds)
#
# new makes /tmp/s4e/<seat>/wt-<name>/{SCRIP,harness,corpus,.github}: detached git worktrees of this root's four checkouts at the base (default
# origin/main, as the root last fetched it; new fetches nothing, so a seat syncs first). THE CORPUS IS SPARSE BY DEFAULT (the coo, 2026-11-05 17:5x: the
# whole corpus is 2.3 G a worktree; the president measured 3.0 G down to 756 M): every path but /benchmarks/ and /demos/. --full keeps the whole corpus
# for the rare row that reads them; --lang names languages (tests/<lang>/ and the root files) and refuses with --full. The build is FETCHED
# from the build cache for the worktree's own HEAD tree and RT_TAG
# (util_build_cache.sh fetch); a worktree never builds. The size (du -sm of the whole worktree, the fetched build included) must be at or under the
# cap (4096 MB by default; --cap-mb names another): over the cap new rolls back and refuses. A build that does not fetch keeps the worktree, so a
# seat can run make in it, and refuses rc 1.
# THE CAP (the cio 2026-11-05 17:4x; changed by the coo's COO-476 on 2026-11-06, row fleet-the-worktree-cap-counts-dead-wt-dirs): new refuses rc 2
# when WT_MAX worktrees that the cap counts already stand under /tmp/s4e/<seat>/ (WT_MAX defaults to 40 since 2026-11-09 03:0x, CIO-17: twenty juniors, each needing one, and dead worktrees the sweep could not reclaim held the 32; before that 32 since 2026-11-07 14:1x: fourteen live seats, each with one or two worktrees, filled 16 inside an hour of the climb and blocked the cao, worker_06 and worker_08 while /tmp held 37 GB free; the environment may name another). A
# wt-* directory is COUNTED only when its .s4e-worktree marker names a seat of .github/TIERS.tsv; every other wt-* directory (hand-made, dead, or of a
# seat no longer in the table) is listed in the refusal and never counted, so it holds no slot. --probe proves the count on a scratch TOP.
# THE BATON (the cio, same day): --row <topic> writes one line WORKTREE: <path> into /home/resources/postoffice/tasks/<topic>.task.md, before the first
# ## section, once; a baton that is absent refuses rc 2 before anything is made. rm <name> deletes that line from every baton that carries it. The bus
# reads these lines at done and park (fleet-queue step 6, worker_06).
# rm removes only what new made: the marker .s4e-worktree in the directory is the proof; each repo's git worktree is removed from its root repo,
# then the directory. list prints every worktree new made and how many of its four are still registered.
# --probe makes one whole-root worktree at origin/main (sparse by default), then one --lang snobol4 worktree that must hold corpus/include/global.inc
# and corpus/library (the .inc programs and the Snocone library; a corpus without include/ reds the snobol4 smoke, the coo 2026-11-05 18:5x). It prints
# its WORKTREE line and PROBE-LANG, removes both, and prints nothing of the WORKTREE line when either check fails: the proof that step 36 reads green.
# THE LINE: WORKTREE repos=4 build=fetched size_mb=N cap_mb=C corpus=full|sparse:<langs> path=<wt>
# rc 0 made, removed or listed; rc 1 refused by a measurement (no build fetched, over the cap, a name taken, no such worktree); rc 2 usage, the cap, a missing baton, or cannot measure.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
REPOS="SCRIP harness corpus .github"
CAP_MB=4096
# THE CAP IS ONE SHARED NUMBER WITH A DISK FLOOR (row the-worktree-cap-is-one-shared-number-with-a-disk-floor, the cio 2026-11-13, MEASURED 11:58 CST: 40 worktrees stood, the
# cap of 2026-11-09 for twenty juniors, held by 25 of 37 seats; 12 seats held none and could make none; /tmp had 18G free, a worktree about 0.8G). What the cap protects is the
# disk, and a count below the seats is a wall. /home/resources/postoffice/WORKTREES.conf (S4E_WT_CONF names another, the probe's seam), key=value a line: max=N the worktrees
# that may stand (WT_MAX in the environment wins; 40 with no file), free_gb=F the floor: new refuses rc 2, making nothing, when the worktrees' filesystem has under F GB free
# (no floor with no file). --show-conf prints what is read; --probe-conf proves it on a scratch file.
WT_CONF="${S4E_WT_CONF:-/home/resources/postoffice/WORKTREES.conf}"
wt_conf() { awk -F= -v k="$1" '!/^#/ && $1 == k { v = $2 } END { if (v ~ /^[0-9]+$/) print v }' "$WT_CONF" 2>/dev/null; }
WT_MAX="${WT_MAX:-$(wt_conf max)}"; WT_MAX="${WT_MAX:-40}"; WT_FREE_GB="$(wt_conf free_gb)"; WT_FREE_GB="${WT_FREE_GB:-0}"
TIERS_TSV="$ROOT/.github/TIERS.tsv"
# THE WORKTREES LIVE ON /home (officer_02 2026-11-13, row worktrees-live-on-home-and-hard-link-their-build; MEASURED by the coo 14:3x CST: /tmp, its own 63 GB
# filesystem, read 87 to 90% full, 48 GB of it worktrees, and new refused box-wide under the free_gb floor). A worktree under /tmp could share no byte with the
# pristine of /home/resources/shared, since a hard link cannot join two filesystems (util_relink_root.py refuses). TOP is WORKTREES.conf's top= line, else
# /home/resources/worktrees; S4E_WT_TOP in the environment wins (the probes' seam). The old top, /tmp/s4e, stays LEGACY while it holds worktrees: the cap counts
# it, the sweep sweeps it and rm finds a worktree there, so nothing made before the move is stranded. With S4E_WT_TOP set there is no legacy top, so a probe's
# sweep never reaches a live worktree. THE LINKS ARE ASKED FOR: new --link runs util_relink_root.py on the worktree's corpus, harness and .github when the
# worktree and the pristine share a filesystem, so each clean file equal to the pristine's is a read-only hard link to it; MEASURED on a scratch pair that day: the
# Edit tool and sed -i write a new inode (the link breaks, the pristine is untouched), and an in-place write (Python open a or w, shell >>) fails EACCES, never
# writing through. So a worktree a seat edits is made WITHOUT links: util_build_package_suite.py and util_suite_partition.py write ALL.csv and PARTITION.tsv in
# place, and a seat's own Python edit of a harness script failed EACCES in a linked worktree (MEASURED, officer_02, same day). --link is for a tree that only
# checks out and reads: the cycle's bases (s4e_cycle.sh base_new), whose full corpus is 2.6 GB.
# SCRIP and its out/ stay copies (the cto 2026-11-12, skill shared-box section 4: a fetch touches every output, and a shared inode would move another tree's
# build times). size_mb is the worktree's own blocks (files with one link, and every directory); linked_mb what it shares with the pristine.
WT_TOP_CONF="$(awk -F= '!/^#/ && $1 == "top" { v = $2 } END { if (v ~ /^\//) print v }' "$WT_CONF" 2>/dev/null)"
TOP="${S4E_WT_TOP:-${WT_TOP_CONF:-/home/resources/worktrees}}"
LEGACY_TOP=""; [ -n "${S4E_WT_TOP:-}" ] || [ "$TOP" = /tmp/s4e ] || LEGACY_TOP=/tmp/s4e
TOPS="$TOP${LEGACY_TOP:+ $LEGACY_TOP}"
SHARED="${S4E_SHARED:-/home/resources/shared}"
PO="${S4E_POSTOFFICE:-/home/resources/postoffice}"
BATONS="$PO/tasks"
SEAT="${S4E_SEAT:-}"

die() { echo "$1" >&2; exit "${2:-2}"; }
valid_name() { case "$1" in ""|.*|*[!A-Za-z0-9._-]*) return 1 ;; esac; return 0; }
[ -n "$SEAT" ] || die "REFUSE(2): S4E_SEAT unset -- the worktrees live under $TOP/<seat>/" 2
SEATDIR="$TOP/$SEAT"
LEGACY_SEATDIR="${LEGACY_TOP:+$LEGACY_TOP/$SEAT}"

drop() {
    local wt="$1" marker="$1/.s4e-worktree" r
    case "$wt" in "$SEATDIR"/wt-?*) ;; "${LEGACY_SEATDIR:-/nonexistent}"/wt-?*) ;; *) die "REFUSE(2): $wt is not under $SEATDIR/wt-<name>" 2 ;; esac
    [ -f "$marker" ] || die "REFUSE(1): $wt has no $marker -- new did not make it, so rm leaves it alone" 1
    for r in $REPOS; do
        grep -qx "repo=$r" "$marker" || continue
        git -C "$ROOT/$r" worktree remove --force --force "$wt/$r" >/dev/null 2>&1
        rm -rf "$wt/$r"
        git -C "$ROOT/$r" worktree prune >/dev/null 2>&1
    done
    rm -rf "$wt"
}

seat_in_tiers() {
    [ -f "$TIERS_TSV" ] || die "REFUSE(2): no $TIERS_TSV -- the cap counts only the seats of that table, so it cannot measure" 2
    awk -F'\t' -v s="$1" '!/^#/ && $1 == s { f = 1 } END { exit !f }' "$TIERS_TSV"
}

# wt_unlanded <wt> -- what a rm would lose: for each repo the marker names, tracked modifications or untracked files (ignored build outputs do not count), and
# commits whose patch is not already on origin/main (git cherry, so a landed commit the lander rebased reads landed). Prints " <repo>:dirty" and
# " <repo>:unlanded-commits" and returns 1 when any; 0 when none.
# wt_dirty_paths <repo dir> -- the paths one rm would lose, measured against origin/main and not the index (CIO-17): a tracked file whose content differs
# from origin/main's (a landed edit that is on origin/main with the same bytes is not lost), and an untracked file that origin/main lacks or holds with
# other bytes. Prints one path per line.
wt_dirty_paths() {
    local d="$1" f
    git -C "$d" diff --name-only HEAD 2>/dev/null | while IFS= read -r f; do git -C "$d" diff --quiet origin/main -- "$f" 2>/dev/null || printf '%s\n' "$f"; done
    git -C "$d" ls-files --others --exclude-standard 2>/dev/null | while IFS= read -r f; do
        git -C "$d" cat-file -e "origin/main:$f" 2>/dev/null && [ "$(git -C "$d" hash-object -- "$f")" = "$(git -C "$d" rev-parse "origin/main:$f")" ] || printf '%s\n' "$f"
    done
}
# wt_unlanded <wt> -- what a rm would lose: for each repo the marker names, the paths of wt_dirty_paths, and commits whose patch is not already on origin/main
# (git cherry, so a landed commit the lander rebased reads landed). Prints " <repo>:dirty" and " <repo>:unlanded-commits" and returns 1 when any; 0 when none.
wt_unlanded() {
    local wt="$1" r out=""
    for r in $REPOS; do
        grep -qx "repo=$r" "$wt/.s4e-worktree" 2>/dev/null && [ -d "$wt/$r" ] || continue
        [ -z "$(wt_dirty_paths "$wt/$r")" ] || out="$out $r:dirty"
        ! git -C "$wt/$r" cherry origin/main HEAD 2>/dev/null | grep -q '^+' || out="$out $r:unlanded-commits"
    done
    [ -z "$out" ] || { printf '%s' "$out"; return 1; }
    return 0
}
# wt_save_patch <wt> <owner> <name> -- writes what a rm of <wt> would lose into $PO/escalations/worktrees/<owner>-<name>-<UTC stamp>.patch: each repo's diff
# against origin/main and each untracked file as a diff from /dev/null. Prints the patch's path; returns 1 when it cannot be written (the sweep then keeps the worktree).
wt_save_patch() {
    local wt="$1" owner="$2" name="$3" r f file
    mkdir -p "$PO/escalations/worktrees" || return 1
    file="$PO/escalations/worktrees/$owner-$name-$(date -u +%Y%m%dT%H%M%SZ).patch"
    : > "$file" || return 1
    for r in $REPOS; do
        grep -qx "repo=$r" "$wt/.s4e-worktree" 2>/dev/null && [ -d "$wt/$r" ] || continue
        git -C "$wt/$r" diff HEAD >> "$file" 2>/dev/null
        git -C "$wt/$r" format-patch -q --stdout origin/main..HEAD >> "$file" 2>/dev/null
        git -C "$wt/$r" ls-files --others --exclude-standard 2>/dev/null | while IFS= read -r f; do git -C "$wt/$r" diff --no-index /dev/null "$f" >> "$file" 2>/dev/null; done
    done
    printf '%s\n' "$file"
}
# wt_cap_scan TOP -- the cap's census of TOP/<seat>/wt-*. COUNTED: a directory whose .s4e-worktree marker names a seat of TIERS.tsv.
# IGNORED: every other wt-* directory, listed in CAP_IGNORED and never counted (a hand-made or dead directory holds no slot).
wt_cap_scan() {
    local top d seat
    CAP_COUNTED=0; CAP_COUNTED_LIST=""; CAP_IGNORED_N=0; CAP_IGNORED=""
    for top in "$@"; do for d in "$top"/*/wt-*; do
        [ -d "$d" ] || continue
        seat=""
        [ -f "$d/.s4e-worktree" ] && seat="$(sed -n 's/^seat=//p' "$d/.s4e-worktree" | head -1)"
        if [ -n "$seat" ] && seat_in_tiers "$seat"; then
            CAP_COUNTED=$((CAP_COUNTED + 1)); CAP_COUNTED_LIST="$CAP_COUNTED_LIST $seat/$(basename "$d")"
        else
            CAP_IGNORED_N=$((CAP_IGNORED_N + 1)); CAP_IGNORED="$CAP_IGNORED $(basename "$(dirname "$d")")/$(basename "$d")"
        fi
    done; done
}

# THE LANDED SWEEP (officer_02 2026-11-13, the same row: the coo MEASURED 17 worktrees landed, clean and idle 45 minutes or more while new refused): a worktree
# with nothing wt_unlanded would lose is removed once idle 30 minutes, whatever its class below; only a worktree of a row its owner holds is never swept.
# sweep_dead -- every marker worktree under $TOP/<seat>/ that a baton names (WORKTREE: <path>) whose row reads DONE, SUPERSEDED or RETIRED (QUEUE.tsv or QUEUE.retired.tsv; a row in neither is DONE),
# idle 30 minutes or more by its directory mtime (a row left by its owner 60, a worktree no baton names 120), with no process whose cwd lies inside it and no
# lander holding its land lock, is removed AS ITS OWNER by this script's own rm (so the guard of wt_unlanded applies) while the sweep holds the owner's land
# lock for it, so a landing that starts in that moment refuses instead of losing its home. Prints one line, SWEPT <n>.
# THE LAND LOCK (officer_04 2026-11-12 21:3x CST, MEASURED: the sweep removed /tmp/s4e/officer_04/wt-fusc at 03:13:21Z while s4e_land.sh --home ran its gate
# in it; the lander read LAND RED stage=gate rc=1 with an empty gate.log): s4e_land.sh --home <wt> holds <LAND_TOP>/<its seat>/land.<sha1 of the path, 12>.lock
# on fd 9 for the whole landing, and its children hold no cwd inside the worktree between steps, so a held lock is the one proof that a landing is using it.
LAND_TOP="${S4E_LAND_LOCK_TOP:-/tmp/s4e}"
wt_land_lock() { printf '%s/%s/land.%s.lock' "$LAND_TOP" "$2" "$(printf '%s' "$1" | sha1sum | cut -c1-12)"; }
wt_landing() {
    local lf h
    h="$(printf '%s' "$1" | sha1sum | cut -c1-12)"
    for lf in "$LAND_TOP"/*/land."$h".lock; do
        [ -f "$lf" ] || continue
        flock -n "$lf" true 2>/dev/null || return 0
    done
    return 1
}
sweep_dead() {
    local top age d b row st owner name n=0 nd=0 nl=0 nu=0 now p t busy cls floor lost pf flag lf
    now="$(date +%s)"
    for top in $TOPS; do for d in "$top"/*/wt-*; do
        [ -f "$d/.s4e-worktree" ] || continue
        row=""; st=""
        owner="$(basename "$(dirname "$d")")"; name="${d##*/wt-}"
        b="$(grep -lxF "WORKTREE: $d" "$BATONS"/*.task.md 2>/dev/null | head -1)"
        if [ -z "$b" ]; then cls=unnamed; floor=7200
        else
            row="$(basename "$b" .task.md)"
            st="$(awk -F'\t' -v t="$row" '!/^#/ && $2 == t { print $4; exit }' "$PO/QUEUE.tsv" 2>/dev/null)"
            [ -n "$st" ] || { grep -qF "$(printf '\t')$row$(printf '\t')" "$PO/QUEUE.retired.tsv" 2>/dev/null && st=RETIRED; }
            [ -n "$st" ] || st=DONE
            case "$st" in
                DONE*|SUPERSEDED*|RETIRED*) cls=done; floor=1800 ;;
                "CLAIMED:$owner"|"ASSIGNED:$owner") continue ;;
                *) cls=left; floor=3600 ;;
            esac
        fi
        age=$((now - $(stat -c %Y "$d"))); [ "$age" -ge 1800 ] || continue
        [ "$age" -ge "$floor" ] || wt_unlanded "$d" > /dev/null || continue
        busy=0; for p in /proc/[0-9]*/cwd; do t="$(readlink "$p" 2>/dev/null)"; case "$t" in "$d"|"$d"/*) busy=1; break ;; esac; done
        [ "$busy" = 0 ] || continue
        ! wt_landing "$d" || continue
        lf="$(wt_land_lock "$d" "$owner")"
        exec 7> "$lf" || continue
        flock -n 7 || { exec 7>&-; continue; }
        if lost="$(wt_unlanded "$d")"; then pf=""; flag=""
        else pf="$(wt_save_patch "$d" "$owner" "$name")" || { exec 7>&-; continue; }; flag=--discard; fi
        S4E_SEAT="$owner" S4E_WT_TOP="$top" bash "${BASH_SOURCE[0]}" rm "$name" ${flag:+$flag} > /dev/null 2>&1 7>&- || { exec 7>&-; continue; }
        rm -f "$lf"; exec 7>&-
        n=$((n + 1))
        case "$cls" in done) nd=$((nd + 1)) ;; left) nl=$((nl + 1)) ;; unnamed) nu=$((nu + 1)) ;; esac
        if [ -n "$pf" ] && [ -n "$b" ]; then printf -- '- [sweep] worktree %s removed %s; patch %s\n' "$d" "$cls" "$pf" >> "$b"; fi
    done; done
    echo "SWEPT $n done=$nd left=$nl unnamed=$nu"
}
wt_cap_check() {
    case "$WT_MAX" in ""|*[!0-9]*) die "REFUSE(2): WT_MAX must be a whole number, got '$WT_MAX'" 2 ;; esac
    wt_cap_scan $TOPS
    sweep_dead
    wt_cap_scan $TOPS
    [ "$CAP_COUNTED" -lt "$WT_MAX" ] || die "REFUSE(2): $CAP_COUNTED worktrees of the cap already stand under $TOPS (each <top>/<seat>/) (WT_MAX=$WT_MAX):$CAP_COUNTED_LIST; not counted (unmarked or unknown seat):${CAP_IGNORED:- none} -- rm one first" 2
    if [ "$WT_FREE_GB" -gt 0 ]; then   # the floor, after the sweep has reclaimed what it can
        local free; mkdir -p "$TOP" 2>/dev/null; free="$(df -BG --output=avail "$TOP" 2>/dev/null | tail -1 | tr -dc 0-9)"
        [ -z "$free" ] || [ "$free" -ge "$WT_FREE_GB" ] || die "REFUSE(2): $TOP has $free GB free, under the floor of $WT_FREE_GB GB (WORKTREES.conf free_gb, $WT_CONF): nothing made -- remove a landed worktree (s4e_worktree.sh rm <name>) or wait for the sweep" 2
    fi
}
conf_probe() {   # --probe-conf: four arms on a scratch file and a scratch top, nothing live touched: the cap and the floor are read from the file; with no file the cap is 40 and there is no floor; WT_MAX in the environment wins; a floor above the free space refuses new rc 2 before anything is made
    local T o rc why="" me="${BASH_SOURCE[0]}"
    T="$(mktemp -d "/tmp/s4e/${SEAT:-seat}/wt-conf-probe.XXXXXX" 2>/dev/null || mktemp -d)"; printf 'max=5\nfree_gb=3\n' > "$T/c"
    o="$(env -u WT_MAX S4E_WT_CONF="$T/c" bash "$me" --show-conf 2>&1)"; [ "$o" = "WT conf max=5 free_gb=3 file=$T/c" ] || why="$why arm 1: the file's numbers were not read ($o);"
    o="$(env -u WT_MAX S4E_WT_CONF="$T/absent" bash "$me" --show-conf 2>&1)"; [ "$o" = "WT conf max=40 free_gb=0 file=$T/absent" ] || why="$why arm 2: with no file the cap is not 40 with no floor ($o);"
    o="$(WT_MAX=7 S4E_WT_CONF="$T/c" bash "$me" --show-conf 2>&1)"; [ "$o" = "WT conf max=7 free_gb=3 file=$T/c" ] || why="$why arm 3: WT_MAX in the environment did not win ($o);"
    printf 'max=5\nfree_gb=99999999\n' > "$T/c"
    o="$(env -u WT_MAX S4E_WT_CONF="$T/c" S4E_WT_TOP="$T/top" bash "$me" new probe-floor 2>&1)"; rc=$?
    [ "$rc" = 2 ] && printf '%s\n' "$o" | grep 'under the floor of 99999999 GB' > /dev/null && [ -z "$(find "$T/top" -maxdepth 2 -name 'wt-*' 2>/dev/null)" ] || why="$why arm 4: a floor above the free space did not refuse new with nothing made (rc $rc: $(printf '%s' "$o" | tail -1 | cut -c1-120));"
    if [ -z "$why" ]; then rm -rf "$T"; echo "WT conf-probe ok arms=4 (the cap and the floor read from one file; 40 and no floor with no file; WT_MAX wins; a floor above the free space refused new with nothing made)"; return 0; fi
    echo "WT conf-probe RED:$why"; echo "    kept: $T"; return 1
}

wt_own_mb() {   # <dir>: the MB only this directory holds: every file with one link, and every directory (a file linked to the pristine costs nothing here)
    find "$1" \( -type f -links 1 -o ! -type f \) -printf '%k\n' 2>/dev/null | awk '{ s += $1 } END { print int(s / 1024) }'
}

baton_add() {
    local f="$BATONS/$1.task.md" line="WORKTREE: $2" tmp="$BATONS/$1.task.md.s4e-worktree.$$"
    grep -qxF "$line" "$f" && return 0
    awk -v L="$line" 'BEGIN { done = 0 } !done && /^## / { print L; done = 1 } { print } END { if (!done) print L }' "$f" > "$tmp" && mv -f "$tmp" "$f"
}

baton_strip() {
    local f line="WORKTREE: $1" tmp
    for f in "$BATONS"/*.task.md; do
        [ -f "$f" ] || continue
        grep -qxF "$line" "$f" || continue
        tmp="$f.s4e-worktree.$$"
        grep -vxF "$line" "$f" > "$tmp"; mv -f "$tmp" "$f"
    done
}

new_wt() {
    local name="$1" base="$2" langs="$3" cap="$4" wt corpus_mode=full r l sha made rt fo b size sparse=0 lk lo linked
    local -a pats=()
    wt="$SEATDIR/wt-$name"
    valid_name "$name" || die "REFUSE(2): name '$name' must be [A-Za-z0-9._-], not dot-led" 2
    [ -e "$wt" ] && die "REFUSE(1): $wt exists -- rm $name first" 1
    wt_cap_check
    if [ -z "$row" ] && [ -n "$SEAT" ]; then   # no --row: the seat's one live claim names the baton, so done and park remove this worktree (the coo 2026-11-08 12:39: WT_MAX full of landed work)
        row="$(for c in "$PO/claims"/*.claim; do [ -f "$c" ] && [ "$(head -1 "$c")" = "$SEAT" ] && ! grep -qx DONE "$c" && basename "$c" .claim; done | awk 'NR == 1 { x = $0 } END { if (NR == 1) print x }')"
        [ -n "$row" ] || echo "WARN: no --row and not exactly one live claim of $SEAT: no baton names $wt, so rm it by hand when done" >&2
    fi
    if [ -n "$row" ]; then
        valid_name "$row" || die "REFUSE(2): --row '$row' must be [A-Za-z0-9._-], not dot-led" 2
        [ -f "$BATONS/$row.task.md" ] || die "REFUSE(2): no baton $BATONS/$row.task.md for --row $row" 2
    fi
    for r in $REPOS; do
        git -C "$ROOT/$r" rev-parse -q --verify "$base^{commit}" >/dev/null 2>&1 || die "REFUSE(2): base '$base' is not a commit in $ROOT/$r" 2
    done
    if [ -n "$langs" ]; then
        sparse=1; corpus_mode="sparse:$langs"
        for l in $(printf '%s' "$langs" | tr ',' ' '); do
            case "$l" in ""|*[!a-z0-9_]*) die "REFUSE(2): language '$l' must be [a-z0-9_]+" 2 ;; esac
            [ -n "$(git -C "$ROOT/corpus" ls-tree -d "$base" -- "tests/$l")" ] || die "REFUSE(2): corpus at $base has no tests/$l" 2
            pats+=("/tests/$l/")
            [ -n "$(git -C "$ROOT/corpus" ls-tree -d "$base" -- "packages/$l")" ] && pats+=("/packages/$l/")   # the language's vendored packages (the coo 2026-11-08 10:57 on officer_05's measurement: a Unicon program that calls a posix builtin links posix.icn from packages/icon/unicon_ipl, so an icon worktree without packages/icon read step 13b RED after its cure)
        done
        pats+=(/include/ /library/ /README.md /LICENSE /NOTICE /.gitignore)
    elif [ "$full" = 0 ]; then
        sparse=1; corpus_mode="sparse:default"
        pats+=('/*' '!/benchmarks/' '!/demos/')
    fi
    mkdir -p "$wt" || die "REFUSE(2): cannot make $wt" 2
    sha="$(git -C "$ROOT/SCRIP" rev-parse --short=12 "$base^{commit}")"
    made="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    {
        printf 'name=%s\nseat=%s\nbase=%s\nsha=%s\nmade=%s\ncorpus=%s\n' "$name" "$SEAT" "$base" "$sha" "$made" "$corpus_mode"
        for r in $REPOS; do printf 'repo=%s\n' "$r"; done
    } > "$wt/.s4e-worktree"
    for r in $REPOS; do
        if [ "$r" = corpus ] && [ "$sparse" = 1 ]; then
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
    lk=copy
    if [ "$link" = 0 ]; then :
    elif [ "$(stat -c %d "$wt" 2>/dev/null)" != "$(stat -c %d "$SHARED" 2>/dev/null)" ]; then lk=copy:other-filesystem
    else
        if lo="$(python3 -I "$ROOT/harness/scripts/util_relink_root.py" "$wt" --repo corpus --repo harness --repo .github --pristine "$SHARED" 2>&1)"; then
            lk="hard-link:$(printf '%s\n' "$lo" | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^linked=/) { sub(/^linked=/, "", $i); s += $i } } END { print s + 0 }')"
        else lk=copy:relink-refused; echo "WARN: util_relink_root.py refused on $wt, so its files stay copies: $(printf '%s' "$lo" | tail -1 | cut -c1-200)" >&2; fi
    fi
    size="$(wt_own_mb "$wt")"; linked="$(( $(du -sm "$wt" | cut -f1) - size ))"; [ "$linked" -ge 0 ] || linked=0
    if [ "$size" -gt "$cap" ]; then
        drop "$wt"
        echo "WORKTREE repos=4 build=$b OVER-CAP size_mb=$size cap_mb=$cap corpus=$corpus_mode path=$wt (rolled back)"
        die "REFUSE(1): the worktree is ${size} MB, over the ${cap} MB cap -- name --lang to sparse the corpus" 1
    fi
    if [ -n "$row" ]; then baton_add "$row" "$wt" || echo "WARN: could not write WORKTREE: $wt into the $row baton" >&2; fi
    echo "WORKTREE repos=4 build=$b size_mb=$size linked_mb=$linked link=$lk cap_mb=$cap corpus=$corpus_mode path=$wt"
    [ "$b" = fetched ] && exit 0
    echo "$fo" >&2
    echo "NOT FETCHED: the worktree stays, so a seat can run make in $wt/SCRIP under a run slot; the reason is above" >&2
    exit 1
}

# cap_probe -- the cap's own proof, on a scratch TOP under the seat's directory: eight unmarked wt-* and one marked do not refuse; sixteen
# marked do (WT_MAX of them). Prints the CAP line the step reads and returns 0 only when both hold and the unmarked directories were ignored.
cap_probe() {
    local pt="$SEATDIR/capprobe-$(date -u +%H%M%S)-$$" i c1 i1 full1 full2
    mkdir -p "$pt/$SEAT" || die "REFUSE(2): cannot make $pt" 2
    for i in 1 2 3 4 5 6 7 8; do mkdir -p "$pt/$SEAT/wt-u$i"; done
    mkdir -p "$pt/$SEAT/wt-m1" && printf 'name=m1\nseat=%s\n' "$SEAT" > "$pt/$SEAT/wt-m1/.s4e-worktree"
    wt_cap_scan "$pt"; c1=$CAP_COUNTED; i1=$CAP_IGNORED_N
    if [ "$CAP_COUNTED" -lt "$WT_MAX" ]; then full1=no; else full1=yes; fi
    for i in $(seq 2 "$WT_MAX"); do mkdir -p "$pt/$SEAT/wt-m$i" && printf 'name=m%s\nseat=%s\n' "$i" "$SEAT" > "$pt/$SEAT/wt-m$i/.s4e-worktree"; done
    wt_cap_scan "$pt"
    if [ "$CAP_COUNTED" -ge "$WT_MAX" ]; then full2=yes; else full2=no; fi
    rm -rf "$pt"
    echo "CAP counted=marked unmarked_ignored=$i1 max=$WT_MAX marked_one=$c1 eight_unmarked_plus_one_marked_refuses=$full1 wtmax_marked_refuses=$full2"
    [ "$full1" = no ] && [ "$full2" = yes ] && [ "$i1" -ge 1 ]
}

# sweep_land_probe -- the land lock's proof (officer_04's find, 2026-11-12), on a scratch TOP, land-lock top and postoffice under the seat's directory: two marked
# worktrees no baton names, idle three hours by mtime; another seat's lander holds the land lock of one. The sweep keeps the held one and removes the free one;
# once the holder is killed by its pid the next sweep removes the first. Prints the SWEEP-LAND line; rc 0 only when all three hold.
sweep_land_probe() {
    local pt="$SEATDIR/sweepprobe-$(date -u +%H%M%S)-$$" w lf holder i kept=no freed=no later=no landed=no out1 out2
    mkdir -p "$pt/$SEAT" "$pt/lander" "$pt/po/tasks" || die "REFUSE(2): cannot make $pt" 2
    for w in held free; do mkdir -p "$pt/$SEAT/wt-$w" && printf 'name=%s\nseat=%s\n' "$w" "$SEAT" > "$pt/$SEAT/wt-$w/.s4e-worktree" && touch -d '3 hours ago' "$pt/$SEAT/wt-$w" || die "REFUSE(2): cannot plant $pt/$SEAT/wt-$w" 2; done
    mkdir -p "$pt/$SEAT/wt-landed" && printf 'name=landed\nseat=%s\n' "$SEAT" > "$pt/$SEAT/wt-landed/.s4e-worktree" && touch -d '45 minutes ago' "$pt/$SEAT/wt-landed" || die "REFUSE(2): cannot plant $pt/$SEAT/wt-landed" 2
    lf="$(LAND_TOP="$pt" wt_land_lock "$pt/$SEAT/wt-held" lander)"
    ( exec 9> "$lf"; flock 9; exec sleep 300 ) 8>&- & holder=$!
    for i in $(seq 1 100); do flock -n "$lf" true 2>/dev/null || break; sleep 0.1; done
    out1="$(S4E_WT_TOP="$pt" S4E_LAND_LOCK_TOP="$pt" S4E_POSTOFFICE="$pt/po" bash "${BASH_SOURCE[0]}" sweep 2>&1)"
    [ -d "$pt/$SEAT/wt-held" ] && kept=yes
    [ -e "$pt/$SEAT/wt-free" ] || freed=yes
    [ -e "$pt/$SEAT/wt-landed" ] || landed=yes
    kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
    out2="$(S4E_WT_TOP="$pt" S4E_LAND_LOCK_TOP="$pt" S4E_POSTOFFICE="$pt/po" bash "${BASH_SOURCE[0]}" sweep 2>&1)"
    [ -e "$pt/$SEAT/wt-held" ] || later=yes
    rm -rf "$pt"
    echo "SWEEP-LAND held_kept=$kept free_swept=$freed released_swept=$later landed_idle_45m_swept=$landed first='$out1' second='$out2'"
    [ "$kept" = yes ] && [ "$freed" = yes ] && [ "$later" = yes ] && [ "$landed" = yes ]
}

probe() {
    cap_probe || { echo "PROBE REFUSED: the cap does not count what the design says -- the step does not read green"; exit 1; }
    local stamp="$(date -u +%H%M%S)-$$" name wt out rc lname lwt lout lrc inc=no lib=no wr=no
    name="probe-$stamp"; wt="$SEATDIR/wt-$name"
    out="$(link=1 new_wt "$name" origin/main "" "$CAP_MB" 2>&1)"; rc=$?
    [ -e "$wt" ] && drop "$wt"
    [ -e "$wt" ] && { echo "PROBE removed=no path=$wt"; exit 1; }
    lname="probe-lang-$stamp"; lwt="$SEATDIR/wt-$lname"
    lout="$(link=0 new_wt "$lname" origin/main snobol4 "$CAP_MB" 2>&1)"; lrc=$?
    [ -w "$lwt/harness/scripts/s4e_worktree.sh" ] && [ -w "$lwt/corpus/include/global.inc" ] && wr=yes
    [ -f "$lwt/corpus/include/global.inc" ] && inc=yes
    [ -d "$lwt/corpus/library" ] && lib=yes
    [ -e "$lwt" ] && drop "$lwt"
    [ -e "$lwt" ] && { echo "PROBE removed=no path=$lwt"; exit 1; }
    echo "PROBE removed=yes"
    if [ "$rc" = 0 ] && [ "$lrc" = 0 ] && [ "$inc" = yes ] && [ "$lib" = yes ] && [ "$wr" = yes ]; then
        printf '%s\n' "$out"
        echo "PROBE-LANG lang=snobol4 include_global_inc=$inc library=$lib writable_without_link=$wr"
        exit 0
    fi
    echo "PROBE REFUSED: default rc=$rc lang rc=$lrc include_global_inc=$inc library=$lib writable_without_link=$wr -- the step does not read green"
    exit 1
}

list_wts() {
    local m wt n b made c reg r found=0
    for m in "$SEATDIR"/wt-*/.s4e-worktree ${LEGACY_SEATDIR:+"$LEGACY_SEATDIR"/wt-*/.s4e-worktree}; do
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
base=origin/main; langs=""; cap=$CAP_MB; name=""; row=""; full=0; link=0; discard=0; save=0
case "$verb" in
    --probe) probe ;;
    --probe-conf) conf_probe; exit $? ;;
    --show-conf) echo "WT conf max=$WT_MAX free_gb=$WT_FREE_GB file=$WT_CONF"; exit 0 ;;
    --show-top) echo "WT top=$TOP legacy=${LEGACY_TOP:-none} shared=$SHARED"; exit 0 ;;
    --probe-sweep-land) sweep_land_probe; exit $? ;;
    list) list_wts ;;
    sweep) sweep_dead; exit 0 ;;
    new|add|rm|remove)
        name="${1:-}"; [ $# -gt 0 ] && shift
        while [ $# -gt 0 ]; do
            case "$1" in
                --base) [ $# -ge 2 ] || die "usage: --base <ref>" 2; base="$2"; shift 2 ;;
                --lang) [ $# -ge 2 ] || die "usage: --lang <l1,l2>" 2; langs="$2"; shift 2 ;;
                --cap-mb) [ $# -ge 2 ] || die "usage: --cap-mb <n>" 2; cap="$2"; shift 2 ;;
                --row) [ $# -ge 2 ] || die "usage: --row <topic>" 2; row="$2"; shift 2 ;;
                --full) full=1; shift ;;
                --link) link=1; shift ;;
                --discard) discard=1; shift ;;
                --save) save=1; shift ;;
                *) die "usage: s4e_worktree.sh new <name> [--base <ref>] [--lang <l1,l2>] [--full] [--link] [--cap-mb <n>] [--row <topic>] | rm <name> [--save | --discard] | list | --probe" 2 ;;
            esac
        done
        valid_name "$name" || die "REFUSE(2): a name is required, [A-Za-z0-9._-], not dot-led" 2
        [ -z "$row" ] || case "$verb" in new|add) ;; *) die "REFUSE(2): --row is for new" 2 ;; esac
        [ "$full" = 0 ] || case "$verb" in new|add) ;; *) die "REFUSE(2): --full is for new" 2 ;; esac
        [ "$link" = 0 ] || case "$verb" in new|add) ;; *) die "REFUSE(2): --link is for new" 2 ;; esac
        [ "$full" = 0 ] || [ -z "$langs" ] || die "REFUSE(2): --full and --lang both name the corpus" 2
        [ "$discard" = 0 ] || case "$verb" in rm|remove) ;; *) die "REFUSE(2): --discard is for rm" 2 ;; esac
        [ "$save" = 0 ] || case "$verb" in rm|remove) ;; *) die "REFUSE(2): --save is for rm" 2 ;; esac
        [ "$save" = 0 ] || [ "$discard" = 0 ] || die "REFUSE(2): --save and --discard are two different answers; give one" 2
        ;;
    *) die "usage: s4e_worktree.sh new <name> [--base <ref>] [--lang <l1,l2>] [--full] [--link] [--cap-mb <n>] [--row <topic>] | rm <name> [--save | --discard] | list | --probe" 2 ;;
esac
case "$verb" in
    new|add)
        case "$cap" in ""|*[!0-9]*) die "REFUSE(2): --cap-mb needs a number of MB" 2 ;; esac
        new_wt "$name" "$base" "$langs" "$cap" ;;
    rm|remove)
        wt="$SEATDIR/wt-$name"
        [ -d "$wt" ] || [ -z "$LEGACY_SEATDIR" ] || [ ! -d "$LEGACY_SEATDIR/wt-$name" ] || wt="$LEGACY_SEATDIR/wt-$name"
        [ -d "$wt" ] || die "REFUSE(1): no worktree $name under $SEATDIR" 1
        if [ "$discard" = 1 ]; then [ "$(sed -n 's/^seat=//p' "$wt/.s4e-worktree" 2>/dev/null | head -1)" = "$SEAT" ] || die "REFUSE(1): only the owner may --discard $wt" 1
        elif lost="$(wt_unlanded "$wt")"; then :
        elif [ "$save" = 1 ]; then
            # rm --save (the cio 2026-11-11, CIO-125): THE WORK GOES WHERE THE NEXT SEAT WILL FIND IT. Until this day "save it" was answered by pinning the commits on a branch of the
            # seat's own folder, which no tool read again: MEASURED 2026-11-11, 466 patches in 147 branches off main. The patch is written to the shared escalations folder and its
            # path into the LEDGER of every baton that names this worktree; with no baton naming it the path is printed and counted by util_unlanded_census.py all the same.
            [ "$(sed -n 's/^seat=//p' "$wt/.s4e-worktree" 2>/dev/null | head -1)" = "$SEAT" ] || die "REFUSE(1): only the owner may rm --save $wt" 1
            pf="$(wt_save_patch "$wt" "$SEAT" "$name")" && [ -s "$pf" ] || die "REFUSE(1): the patch of $wt could not be written; the worktree stays" 1
            nb=0
            for b in $(grep -lxF "WORKTREE: $wt" "$BATONS"/*.task.md 2>/dev/null); do
                printf -- '- [%s·%s] UNLANDED WORK SAVED by s4e_worktree.sh rm --save: worktree %s held work that is not on origin/main (%s ); the patch is %s (git am or git apply it in a fresh worktree); land it or say in this LEDGER why it is dropped\n' "$SEAT" "$(date '+%Y-%m-%d %H:%M CST')" "$wt" "$lost" "$pf" >> "$b"; nb=$((nb + 1))
            done
            echo "SAVED $pf batons=$nb"
        else die "REFUSE(1): $wt holds work that is not on origin/main:$lost -- land it, or rm $name --save (the patch goes to the shared escalations folder and into the row's LEDGER; never pin it on a branch of your own folder), or the owner rm $name --discard" 1; fi
        drop "$wt"
        [ -e "$wt" ] && die "REFUSE(1): $wt is still there after drop" 1
        baton_strip "$wt"
        echo "REMOVED wt-$name path=$wt"; exit 0 ;;
esac
