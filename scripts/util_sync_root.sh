#!/usr/bin/env bash
# util_sync_root.sh [--probe] -- THE SITTING'S SYNC OF THE FOUR REPOS, UNDER THE FETCH SLOT (the cio 2026-11-07; Lon's mass-wake spike: twenty seats each
# fetched SCRIP, corpus, harness and .github from github at once; about twelve git index-pack --fix-thin at 50-59 percent CPU each and seven merges, load1
# 44.37 on 16 cores, /proc/pressure/cpu some avg10 76). RULED by the cio: (1) each root's four repos carry objects/info/alternates naming the coo root's
# objects (/home/claude_coo/<repo>/.git/objects), so a fetch moves refs and the few new objects, never a pack; (2) every fetch runs in the GNU sem slot
# s4e-fetch (-j S4E_FETCH_SLOTS, default 4; a wait of S4E_FETCH_WAIT seconds, default 600, that outlasts it refuses rc 2 with nothing merged); (3) --probe
# proves it on scratch: four scratch repos with alternates to this root's objects, each fetched one commit ahead of its base, the pack count must not grow.
# USAGE: bash harness/scripts/util_sync_root.sh            fetch the four repos under $S4E_HOME, then fast-forward each: one `SYNC <repo> <before>..<after>` line each.
#        bash harness/scripts/util_sync_root.sh --probe    one `SYNC slot=sem id=s4e-fetch j=N alternates=A packs_grew=G repos=4` line.
#        bash harness/scripts/util_sync_root.sh --probe-landing   a root whose land lock is held is fetched and never merged (the cio 2026-11-14); one `SYNC landing-probe ok` line.
#        bash harness/scripts/util_sync_root.sh --relink [REPO...]   link a shared repo's clean files to the pristine again (s4e_land.sh after a landing from a root)
# A SEAT'S ROOT IS ITS WORKING TREE (officer_02 2026-11-13, row harness-a-worktree-is-scrip-alone-everything-else-from-the-seats-root; Lon 17:4x CST, in the coo's window,
# verbatim: "I want you to work in /home/claude folder. We do not NEED duplication. Nope, dups not needed."): a repo with commits origin/main lacks, or with tracked edits,
# is left exactly as it is and named, `SYNC <repo> <head>..<head> KEPT ...`, rc 0: the sync never stashes, resets, rebases or merges over a seat's work; the seat lands it
# (s4e_land.sh --home <root>), and the lander brings the repo to origin.
# rc 0 synced or kept (probe: green); 1 a merge refused, or a probe fetch grew a pack; 2 cannot measure (not a repo, a fetch the slot or origin refused).
# The fetches all run before any merge, so a refused fetch never leaves one repo merged and another behind (never half a landing).
set -uo pipefail
ROOT="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"
REPOS="${S4E_SYNC_REPOS:-SCRIP corpus harness .github}"   # S4E_SYNC_REPOS names a subset (next syncs corpus harness .github before a premise read and leaves SCRIP, whose binary would go stale without a make; the cio 2026-11-08 11:1x on the coo's 11:05 defect)
FETCH_SLOTS="${S4E_FETCH_SLOTS:-4}"
FETCH_WAIT="${S4E_FETCH_WAIT:-600}"
SEM_HOME="${S4E_SEM_HOME:-/tmp/s4e-sem}"
# THE ABSOLUTE MODEL (officer_02 2026-11-13, row harness-corpus-and-harness-live-once-on-disk-one-seat-owns-them; Lon 18:1x CST: "a root folder is either a SCRIP, snobol4dotnet, or
# snobol4jvm clone with no siblings"): SCRIP is S4E_SCRIP (lib_paths.sh: the root itself once it is the clone, else its sibling); corpus, harness and .github are synced only while the
# root still holds them as siblings. The one-disk checkouts (/home/corpus, /home/harness, /home/.github) are never a seat's to sync: the grader keeps them at origin.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_paths.sh"
repo_dir() { if [ "$1" = SCRIP ]; then printf '%s' "$S4E_SCRIP"; else printf '%s/%s' "$ROOT" "$1"; fi; }

# point_at_store ROOT REPO: the alternates line for one repo, written once (idempotent). NO ROOT BORROWS FROM ANOTHER ROOT (the cio 2026-11-14, row
# harness-one-disk-step-6-the-cutover; until then the line named /home/claude_coo/<repo>, and this function wrote it back at every sync): SCRIP borrows from the
# one store /home/SCRIP.git, and a corpus, harness or .github a root holds for a change (s4e_take.sh) from its one-disk checkout. A store that is absent gets no line.
point_at_store() {
    local objs alt="$1/$2/.git/objects/info/alternates"
    case "$2" in SCRIP) objs="${S4E_SCRIP_STORE:-/home/SCRIP.git}/objects" ;; *) objs="${S4E_ONE_DISK_TOP:-/home}/$2/.git/objects" ;; esac
    [ -d "$objs" ] || return 0
    [ "$(cd "$1/$2/.git/objects" 2>/dev/null && pwd -P)" != "$(cd "$objs" && pwd -P)" ] || return 0
    mkdir -p "$(dirname "$alt")" || return 1
    grep -qxF "$objs" "$alt" 2>/dev/null || printf '%s\n' "$objs" >> "$alt"
}

# fetch_slot DIR: git fetch origin in DIR, admitted by the GNU sem slot s4e-fetch (the same sem shape lib_slots.sh uses: a negative timeout refuses).
fetch_slot() {
    mkdir -p "$SEM_HOME" 2>/dev/null || return 2
    PARALLEL_HOME="$SEM_HOME" sem --will-cite --id s4e-fetch -j "$FETCH_SLOTS" --fg --semaphoretimeout "-$FETCH_WAIT" git -C "$1" fetch -q origin
}

packs_in() { ls "$1/objects/pack" 2>/dev/null | grep -c '\.pack$'; }

# NOTHING IS MERGED UNDER A RUNNING LANDING (the cio 2026-11-14, MEASURED on its own landing 09:33 CST: the tick's sync of the cio root fast-forwarded the root's clean SCRIP while
# the landing's gate was grading from it, the freshness guard then read the binary stale, and the gate read RED on its seventh entry with six green; a boss runs its lander in the
# background and its next sync, or the tick's, lands on the same tree). A landing holds a flock on /tmp/s4e/<seat>/land.<first 12 of sha1 of the home>.lock for its whole life
# (s4e_land.sh); while the kernel's lock table names that file, the sync fetches as ever and merges nothing in this root, each repo named KEPT. The table is read, the lock is never
# tried, so a landing starting at the same instant is never refused by this check. --probe-landing proves it on a scratch root.
land_held() {
    local h f ino; h="$(printf '%s' "$ROOT" | sha1sum | cut -c1-12)"
    for f in /tmp/s4e/*/land."$h".lock; do
        [ -e "$f" ] || continue
        ino="$(stat -c %i "$f" 2>/dev/null)" || continue
        awk -v i=":$ino" '$2 == "FLOCK" && substr($6, length($6) - length(i) + 1) == i { f = 1 } END { exit !f }' /proc/locks 2>/dev/null && return 0
    done
    return 1
}

sync_all() {
    local r dir before after rc=0 frc
    local have=""
    for r in $REPOS; do
        dir="$(repo_dir "$r")"
        if ! git -C "$dir" rev-parse --git-dir > /dev/null 2>&1; then
            [ "$r" = SCRIP ] && { echo "REFUSE(2): $dir is not a git repo"; return 2; }
            [ -e "$dir" ] && { echo "REFUSE(2): $dir is not a git repo"; return 2; }
            echo "SYNC $r absent from $ROOT (the absolute model: $r is read from its one-disk checkout)"; continue
        fi
        have="$have $r"
        [ "$dir" = "$ROOT/$r" ] && { point_at_store "$ROOT" "$r" || { echo "REFUSE(2): cannot write $dir/.git/objects/info/alternates"; return 2; }; }
    done
    for r in $have; do
        fetch_slot "$(repo_dir "$r")"; frc=$?
        [ "$frc" = 0 ] || { echo "REFUSE(2): fetch of $r failed (sem/git rc $frc) -- nothing merged"; return 2; }
    done
    local moved="" landing=0
    land_held && landing=1
    for r in $have; do
        dir="$(repo_dir "$r")"
        before="$(git -C "$dir" rev-parse --short HEAD)"
        if [ "$landing" = 1 ]; then
            echo "SYNC $r $before..$before KEPT: a landing runs from this root and its gate reads this tree; fetched, nothing merged (it syncs at the next call once the landing ends)"
            continue
        fi
        local ah ed; ah="$(git -C "$dir" rev-list --count origin/main..HEAD 2>/dev/null)"; ed="$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null | wc -l)"
        if [ "${ah:-0}" -gt 0 ] || [ "$ed" -gt 0 ]; then
            echo "SYNC $r $before..$before KEPT: ${ah:-0} local commit(s), $ed edited file(s), $(git -C "$dir" rev-list --count HEAD..origin/main 2>/dev/null) behind origin -- this root is the seat's working tree: nothing stashed, reset or merged; land the work with s4e_land.sh --home $ROOT"
            continue
        fi
        if git -C "$dir" merge -q --ff-only origin/main; then
            after="$(git -C "$dir" rev-parse --short HEAD)"
            echo "SYNC $r $before..$after"
            [ "$before" = "$after" ] || moved="$moved $r"
        else
            echo "SYNC $r $before..$before MERGE REFUSED (not a fast-forward of origin/main)"; rc=1
        fi
    done
    relink_shared $moved
    return $rc
}

# A ROOT THAT SHARES ITS FILES KEEPS SHARING THEM (the cio 2026-11-12, row fleet-32-16-8-4-shared-repos): a repo util_relink_root.py has linked
# carries git config s4e.shared=true; when its merge moved, the pristine is brought to this root's HEAD (util_shared_pristine.sh update, only
# when it lags) and the files the merge rewrote are linked again. A root never converted (no mark) is left as it is.
relink_shared() {
    local r todo="" ph sh
    for r in "$@"; do
        case "$r" in corpus|harness|.github) ;; *) continue ;; esac
        [ "$(git -C "$ROOT/$r" config --get s4e.shared 2>/dev/null)" = true ] || continue
        ph="$(git -C "${S4E_SHARED:-/home/resources/shared}/$r" rev-parse HEAD 2>/dev/null)"; sh="$(git -C "$ROOT/$r" rev-parse HEAD)"
        if [ "$ph" != "$sh" ] && ! git -C "$ROOT/$r" merge-base --is-ancestor "$sh" "$ph" 2>/dev/null; then
            bash "$(dirname "${BASH_SOURCE[0]}")/util_shared_pristine.sh" update "$r" | sed 's/^/  /'
        fi
        todo="$todo --repo $r"
    done
    [ -n "$todo" ] && python3 -I "$(dirname "${BASH_SOURCE[0]}")/util_relink_root.py" "$ROOT" $todo | sed 's/^/  /'
    return 0
}

probe() {
    local r src s url base p0 p1 alt_ok=1 grew=0 n=0 red="" seat scratch
    seat="${S4E_SEAT:-sync}"; scratch="/tmp/s4e/$seat/sync-probe.$$"
    rm -rf "$scratch"; mkdir -p "$scratch" || { echo "REFUSE(2): cannot make $scratch"; return 2; }
    for r in $REPOS; do
        src="$ROOT/$r"
        git -C "$src" rev-parse --git-dir > /dev/null 2>&1 || { echo "REFUSE(2): $src is not a git repo"; rm -rf "$scratch"; return 2; }
        url="$(git -C "$src" remote get-url origin 2>/dev/null)" || { echo "REFUSE(2): $r has no origin"; rm -rf "$scratch"; return 2; }
        base="$(git -C "$src" rev-parse --verify -q HEAD~1)" || { echo "REFUSE(2): $r has no parent commit to probe from"; rm -rf "$scratch"; return 2; }
        s="$scratch/$r"; n=$((n + 1))
        git init -q "$s" || { echo "REFUSE(2): cannot init $s"; rm -rf "$scratch"; return 2; }
        mkdir -p "$s/.git/objects/info"
        printf '%s\n' "$src/.git/objects" > "$s/.git/objects/info/alternates"
        [ -d "$(cat "$s/.git/objects/info/alternates")" ] || alt_ok=0
        git -C "$s" remote add origin "$url" && git -C "$s" update-ref refs/remotes/origin/main "$base" || { echo "REFUSE(2): cannot set the probe's refs for $r"; rm -rf "$scratch"; return 2; }
        p0="$(packs_in "$s/.git")"
        fetch_slot "$s" > /dev/null 2>&1 || red="$red fetch of $r refused (slot or origin);"
        p1="$(packs_in "$s/.git")"
        [ "$p1" -gt "$p0" ] && grew=$((grew + 1))
    done
    rm -rf "$scratch"
    [ -n "$red" ] && echo "SYNC PROBE RED:$red"
    echo "SYNC slot=sem id=s4e-fetch j=$FETCH_SLOTS alternates=$alt_ok packs_grew=$grew repos=$n"
    [ -z "$red" ] && [ "$grew" = 0 ] && [ "$alt_ok" = 1 ] && return 0
    return 1
}

probe_landing() {   # on a scratch root whose one repo is behind its scratch origin: with the root's land lock held the sync merges nothing and says KEPT; released, it fast-forwards
    local seat T h lk hp before mid after o1 o2 red=""
    seat="${S4E_SEAT:-sync}"; T="/tmp/s4e/$seat/sync-landing-probe.$$"; rm -rf "$T"; mkdir -p "$T/root" || { echo "REFUSE(2): cannot make $T"; return 2; }
    git init -q --bare "$T/origin.git" && git clone -q "$T/origin.git" "$T/w" 2>/dev/null || { echo "REFUSE(2): cannot make the scratch origin"; rm -rf "$T"; return 2; }
    ( cd "$T/w" && git config user.name probe && git config user.email probe@example.invalid && echo a > f && git add f && git commit -q -m one && git push -q origin HEAD:main ) || { echo "REFUSE(2): cannot commit to the scratch origin"; rm -rf "$T"; return 2; }
    git clone -q -b main "$T/origin.git" "$T/root/harness" || { echo "REFUSE(2): cannot clone the scratch root"; rm -rf "$T"; return 2; }
    ( cd "$T/w" && echo b > f && git commit -q -am two && git push -q origin HEAD:main ) || { echo "REFUSE(2): cannot move the scratch origin"; rm -rf "$T"; return 2; }
    h="$(printf '%s' "$T/root" | sha1sum | cut -c1-12)"; lk="/tmp/s4e/$seat/land.$h.lock"
    before="$(git -C "$T/root/harness" rev-parse HEAD)"
    ( exec 9> "$lk"; flock -n 9 || exit 1; : > "$T/held"; while [ ! -e "$T/release" ]; do sleep 0.2; done ) & hp=$!
    while [ ! -e "$T/held" ] && kill -0 "$hp" 2>/dev/null; do sleep 0.1; done
    [ -e "$T/held" ] || { echo "REFUSE(2): the probe could not hold $lk"; rm -rf "$T" "$lk"; return 2; }
    o1="$(S4E_HOME="$T/root" S4E_SYNC_REPOS=harness S4E_ONE_DISK_TOP="$T/none" bash "${BASH_SOURCE[0]}" 2>&1)"; mid="$(git -C "$T/root/harness" rev-parse HEAD)"
    : > "$T/release"; wait "$hp" 2>/dev/null
    o2="$(S4E_HOME="$T/root" S4E_SYNC_REPOS=harness S4E_ONE_DISK_TOP="$T/none" bash "${BASH_SOURCE[0]}" 2>&1)"; after="$(git -C "$T/root/harness" rev-parse HEAD)"
    [ "$mid" = "$before" ] || red="$red the tree moved under the held land lock;"
    printf '%s\n' "$o1" | grep -q '^SYNC harness .* KEPT: a landing runs from this root' || red="$red the held sync did not say KEPT [$(printf '%s' "$o1" | tail -1 | cut -c1-100)];"
    [ "$after" = "$(git -C "$T/origin.git" rev-parse main)" ] || red="$red with the lock released the tree did not reach origin [$(printf '%s' "$o2" | tail -1 | cut -c1-100)];"
    rm -rf "$T" "$lk"
    if [ -z "$red" ]; then echo "SYNC landing-probe ok held=kept released=merged (a root whose land lock is held is fetched and never merged; once released the same call fast-forwards it)"; return 0; fi
    echo "SYNC landing-probe RED:$red"; return 1
}

case "${1:-}" in
    --probe) probe; exit $? ;;
    --probe-landing) probe_landing; exit $? ;;
    --relink) shift; relink_shared ${@:-corpus harness .github}; exit $? ;;
    "") sync_all; exit $? ;;
    *) echo "usage: util_sync_root.sh [--probe | --relink [REPO...]]" >&2; exit 2 ;;
esac
