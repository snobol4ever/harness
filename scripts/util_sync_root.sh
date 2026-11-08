#!/usr/bin/env bash
# util_sync_root.sh [--probe] -- THE SITTING'S SYNC OF THE FOUR REPOS, UNDER THE FETCH SLOT (the cio 2026-11-07; Lon's mass-wake spike: twenty seats each
# fetched SCRIP, corpus, harness and .github from github at once; about twelve git index-pack --fix-thin at 50-59 percent CPU each and seven merges, load1
# 44.37 on 16 cores, /proc/pressure/cpu some avg10 76). RULED by the cio: (1) each root's four repos carry objects/info/alternates naming the coo root's
# objects (/home/claude_coo/<repo>/.git/objects), so a fetch moves refs and the few new objects, never a pack; (2) every fetch runs in the GNU sem slot
# s4e-fetch (-j S4E_FETCH_SLOTS, default 4; a wait of S4E_FETCH_WAIT seconds, default 600, that outlasts it refuses rc 2 with nothing merged); (3) --probe
# proves it on scratch: four scratch repos with alternates to this root's objects, each fetched one commit ahead of its base, the pack count must not grow.
# USAGE: bash harness/scripts/util_sync_root.sh            fetch the four repos under $S4E_HOME, then fast-forward each: one `SYNC <repo> <before>..<after>` line each.
#        bash harness/scripts/util_sync_root.sh --probe    one `SYNC slot=sem id=s4e-fetch j=N alternates=A packs_grew=G repos=4` line.
# rc 0 synced (probe: green); 1 a merge refused, or a probe fetch grew a pack; 2 cannot measure (not a repo, a fetch the slot or origin refused).
# The fetches all run before any merge, so a refused fetch never leaves one repo merged and another behind (never half a landing).
set -uo pipefail
ROOT="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"
REPOS="${S4E_SYNC_REPOS:-SCRIP corpus harness .github}"   # S4E_SYNC_REPOS names a subset (next syncs corpus harness .github before a premise read and leaves SCRIP, whose binary would go stale without a make; the cio 2026-11-08 11:1x on the coo's 11:05 defect)
FETCH_SLOTS="${S4E_FETCH_SLOTS:-4}"
FETCH_WAIT="${S4E_FETCH_WAIT:-600}"
SEM_HOME="${S4E_SEM_HOME:-/tmp/s4e-sem}"

# point_at_coo ROOT REPO: the alternates line for one repo, written once (idempotent). The coo's own root gets none, and a repo the coo root lacks gets none.
point_at_coo() {
    local objs="/home/claude_coo/$2/.git/objects" alt="$1/$2/.git/objects/info/alternates"
    [ "$1" = /home/claude_coo ] && return 0
    [ -d "$objs" ] || return 0
    mkdir -p "$(dirname "$alt")" || return 1
    grep -qxF "$objs" "$alt" 2>/dev/null || printf '%s\n' "$objs" >> "$alt"
}

# fetch_slot DIR: git fetch origin in DIR, admitted by the GNU sem slot s4e-fetch (the same sem shape lib_slots.sh uses: a negative timeout refuses).
fetch_slot() {
    mkdir -p "$SEM_HOME" 2>/dev/null || return 2
    PARALLEL_HOME="$SEM_HOME" sem --will-cite --id s4e-fetch -j "$FETCH_SLOTS" --fg --semaphoretimeout "-$FETCH_WAIT" git -C "$1" fetch -q origin
}

packs_in() { ls "$1/objects/pack" 2>/dev/null | grep -c '\.pack$'; }

sync_all() {
    local r dir before after rc=0 frc
    for r in $REPOS; do
        dir="$ROOT/$r"
        git -C "$dir" rev-parse --git-dir > /dev/null 2>&1 || { echo "REFUSE(2): $dir is not a git repo"; return 2; }
        point_at_coo "$ROOT" "$r" || { echo "REFUSE(2): cannot write $dir/.git/objects/info/alternates"; return 2; }
    done
    for r in $REPOS; do
        fetch_slot "$ROOT/$r"; frc=$?
        [ "$frc" = 0 ] || { echo "REFUSE(2): fetch of $r failed (sem/git rc $frc) -- nothing merged"; return 2; }
    done
    for r in $REPOS; do
        dir="$ROOT/$r"
        before="$(git -C "$dir" rev-parse --short HEAD)"
        if git -C "$dir" merge -q --ff-only origin/main; then
            after="$(git -C "$dir" rev-parse --short HEAD)"
            echo "SYNC $r $before..$after"
        else
            echo "SYNC $r $before..$before MERGE REFUSED (not a fast-forward of origin/main)"; rc=1
        fi
    done
    return $rc
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

case "${1:-}" in
    --probe) probe; exit $? ;;
    "") sync_all; exit $? ;;
    *) echo "usage: util_sync_root.sh [--probe]" >&2; exit 2 ;;
esac
