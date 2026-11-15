#!/usr/bin/env bash
# s4e_take.sh -- NO SEAT HOLDS corpus, harness OR .github: EVERY SEAT SHARES THE THREE THROUGH ONE PROXY, THE GRADER (Lon 2026-11-14 16:4x to 16:5x CST, in the
# cto's window, verbatim: "Well, the GRADER is meant to be the ONE maintainer of both corpus and harness, so ensure those folders do not exist anywhere in
# /home/claude folders." / "Only ONE maintainer has /home/{.github,corpus,harness} and that is GRADER." / "Ensure it no with words but inside the SHELL script." /
# "All seats SHARES these 3 REPOSITORIES through a PROXY/AGENT, named GRADER."; his word of that morning in the cio's window stands under it: "We are meant not to
# have folder .github, harness, and corpus in each /home/claude folder"). IT VOIDS the rule this tool carried since that morning, that a seat takes its own clone
# into its root while it carries a change. MEASURED by the cto at 16:5x: six such folders stood in seat roots, four of them holding work origin lacked.
# THE RULE, BUILT HERE: the three live once, at /home/corpus, /home/harness and /home/.github. A seat reads them there and never holds a copy. A seat that wants a
# change GIVES the grader a patch; the grader alone applies it to the one checkout, commits and pushes. One pusher, so two changes never race.
#   s4e_take.sh corpus|harness|.github          REFUSES rc 2 for every seat and makes nothing; its line names the give
#   s4e_take.sh give <repo> <patch> "<why>"     a seat hands the grader a patch (unified diff, paths a/... b/... from the repo's top): checked to apply to the
#                                               one checkout as it stands, stored under the gives folder with its seat and why; rc 1 when it does not apply
#   s4e_take.sh apply <given patch>             THE GRADER ONLY (S4E_SEAT=grader; any other seat rc 2): brings the one checkout to origin/main, applies the give,
#                                               commits it under its why and its giver, pushes; a give that no longer applies, or a push origin refuses, leaves
#                                               the checkout at origin/main and the give where it was
#   s4e_take.sh base <given patch>              prints the commit of the one checkout the give was checked against: where the grader applies a give that no longer
#                                               applies at origin/main (a witness added to a container another give has since renumbered), before its landing's rebase
#   s4e_take.sh check                           rc 1 and one line a folder while ANY seat root under the top holds corpus, harness or .github; rc 0 when none does
#   s4e_take.sh list                            the repos this root still holds, each with what it carries
#   s4e_take.sh drop corpus|harness|.github     remove one this root still holds; refuses rc 1, naming what would be lost, while it holds an edit, an untracked
#                                               file, a stash or a commit origin/main lacks (drop --landed is the lander's call after its push). These two verbs
#                                               stay only to drain the folders made before this rule.
#   s4e_take.sh --probe                         six arms on a scratch origin, top and root; nothing live touched. TAKE probe ok|RED
# HOW A SEAT WRITES A PATCH WITH NO CLONE: copy the files it changes from /home/<repo> to its scratch (/tmp/s4e/<seat>/), edit the copies, and
# diff -u --label a/<path> --label b/<path> /home/<repo>/<path> <its copy>; a new file is a diff against /dev/null with --label a/<path> too.
# The root is S4E_HOME; the top is /home (S4E_ONE_DISK_TOP names another, the probe's seam); the gives folder is /home/resources/postoffice/gives (S4E_GIVES).
# rc 0 done; 1 refused by a measurement (it holds work, it does not apply); 2 usage, the wrong seat, or cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP="${S4E_ONE_DISK_TOP:-/home}"; GIVES="${S4E_GIVES:-/home/resources/postoffice/gives}"
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
    die "REFUSE(2): no seat holds $1, and nothing was made. Lon 2026-11-14: \"Only ONE maintainer has /home/{.github,corpus,harness} and that is GRADER.\" Read it at $TOP/$1. To change it, give the grader a patch: bash $TOP/harness/scripts/s4e_take.sh give $1 <patch> \"<why>\" (the head of this script says how a patch is written with no clone)." 2
}
give() {
    local r="$1" p="${2:-}" why="${3:-}" seat="${S4E_SEAT:-}" src err out base
    [ -n "$seat" ] || die "REFUSE(2): S4E_SEAT is unset: a give names its seat" 2
    [ -n "$p" ] && [ -s "$p" ] || die "REFUSE(2): no patch at '$p' (usage: s4e_take.sh give corpus|harness|.github <patch> \"<why>\")" 2
    [ -n "$why" ] || die "REFUSE(2): a give says why, the row and what the change does (usage: s4e_take.sh give $r <patch> \"<why>\")" 2
    case "$why" in *$'\t'*|*$'\n'*) die "REFUSE(2): the why is one line with no tab" 2 ;; esac
    src="$TOP/$r"; [ -d "$src/.git" ] || die "REFUSE(2): no checkout at $src" 2
    p="$(readlink -f "$p")"
    err="$(git -C "$src" apply --check "$p" 2>&1)" || die "REFUSE(1): the patch does not apply to $src at $(git -C "$src" rev-parse --short=10 HEAD 2>/dev/null): $(printf '%s' "$err" | head -1). Nothing given." 1
    mkdir -p "$GIVES" 2>/dev/null || die "REFUSE(2): cannot make $GIVES" 2
    out="$GIVES/$(date -u +%Y%m%dT%H%M%SZ)-$seat-${r#.}-$$.patch"
    base="$(git -C "$src" rev-parse HEAD 2>/dev/null)"   # THE GIVE NAMES ITS BASE (the cio 2026-11-14, ruled with the grader): the commit of the one checkout the patch was checked against. A give that adds an entry to a container renumbers every row below it, so once another such give lands it applies nowhere but at its base; the grader applies it there, in a worktree, and its landing's rebase merges the container's tables by entry key (util_table_merge.py, s4e_land.sh)
    cp "$p" "$out" && printf '%s\t%s\t%s\t%s\t%s\n' "$(basename "$out")" "$seat" "$r" "$why" "base=$base" >> "$GIVES/GIVES.tsv" || die "REFUSE(2): cannot store the give in $GIVES" 2
    echo "GIVEN $out ($r, by $seat, base ${base:0:10}: $why). The grader alone applies it."
    echo "WAKE: SendMessage to GRADER now with this first line: \"give $(basename "$out"): run bash $TOP/harness/scripts/s4e_take.sh apply $out\""
}
apply() {
    local g="${1:-}" seat="${S4E_SEAT:-}" row r giver why src
    [ "$seat" = grader ] || die "REFUSE(2): only the grader applies a give (this seat is '${seat:-unset}'); nothing applied. A seat gives: s4e_take.sh give <repo> <patch> \"<why>\"." 2
    [ -n "$g" ] && [ -s "$g" ] || die "REFUSE(2): no give at '$g' (usage: s4e_take.sh apply <given patch>)" 2
    g="$(readlink -f "$g")"
    row="$(awk -F'\t' -v b="$(basename "$g")" '$1==b' "$GIVES/GIVES.tsv" 2>/dev/null | tail -1)"
    [ -n "$row" ] || die "REFUSE(2): $(basename "$g") is not a give recorded in $GIVES/GIVES.tsv; nothing applied" 2
    giver="$(printf '%s' "$row" | cut -f2)"; r="$(printf '%s' "$row" | cut -f3)"; why="$(printf '%s' "$row" | cut -f4)"
    repo_ok "$r" || die "REFUSE(2): the give names no repo of the three ('$r')" 2
    src="$TOP/$r"; [ -d "$src/.git" ] || die "REFUSE(2): no checkout at $src" 2
    [ -z "$(git -C "$src" status --porcelain 2>/dev/null | head -1)" ] || die "REFUSE(1): $src is not clean; nothing applied (git -C $src status)" 1
    git -C "$src" fetch -q origin 2>/dev/null || die "REFUSE(2): cannot fetch origin in $src; nothing applied" 2
    git -C "$src" merge -q --ff-only origin/main 2>/dev/null || die "REFUSE(1): $src does not fast-forward to origin/main; nothing applied" 1
    git -C "$src" apply --index "$g" 2>/dev/null || die "REFUSE(1): the give no longer applies to $src at origin/main $(git -C "$src" rev-parse --short=10 HEAD); nothing applied. Its base is $(printf '%s' "$row" | cut -f5 | sed 's/^base=//;s/^$/not recorded/'): applied there in a worktree and landed with s4e_land.sh, the rebase merges a container's tables by entry key (s4e_take.sh base <give> prints it); for any other file $giver makes it again on today's files." 1
    if ! git -C "$src" commit -q -m "$why (given by $giver through the grader: $(basename "$g"))" 2>/dev/null; then
        git -C "$src" reset -q --hard origin/main; die "REFUSE(1): the commit was refused; $src is back at origin/main; nothing applied" 1
    fi
    if ! git -C "$src" push -q origin HEAD:main 2>/dev/null; then
        git -C "$src" reset -q --hard origin/main; die "REFUSE(1): origin refused the push; $src is back at origin/main and the give stands; apply it again" 1
    fi
    git -C "$src" fetch -q origin 2>/dev/null
    mkdir -p "$GIVES/done" && mv "$g" "$GIVES/done/"
    echo "APPLIED $(basename "$g") to $src: $(git -C "$src" rev-parse --short=10 HEAD) is on origin/main (given by $giver: $why)"
}
check() {
    local n=0 d r c
    for d in "$TOP"/claude_*; do
        [ -d "$d" ] || continue
        for r in corpus harness .github; do
            [ -e "$d/$r" ] || continue
            n=$((n + 1)); c=""; [ -d "$d/$r/.git" ] && c="$(carries "$d/$r")"
            echo "HELD $d/$r carries:${c:- nothing}"
        done
    done
    if [ "$n" = 0 ]; then echo "CHECK ok: no seat root under $TOP holds corpus, harness or .github; the grader's three stand at $TOP"; return 0; fi
    echo "CHECK RED: $n folder(s) above stand in a seat root. Each is drained by its holder: what it carries is given to the grader (s4e_take.sh give) or landed, then s4e_take.sh drop <repo> removes it."
    return 1
}
drop() {
    local r="$1" landed="$2" home="${S4E_HOME:-}" d c
    [ -n "$home" ] && [ -d "$home" ] || die "REFUSE(2): S4E_HOME is not a root ($home)" 2
    d="$home/$r"
    if [ ! -d "$d/.git" ]; then [ "$landed" = 1 ] && exit 0; die "REFUSE(1): $home holds no $r" 1; fi
    if [ "$landed" = 1 ] && [ "$(git -C "$d" config --get s4e.taken 2>/dev/null)" != true ]; then exit 0; fi   # the lander drops only what take made
    [ -d "$TOP/$r/.git" ] || die "REFUSE(2): no one-disk checkout at $TOP/$r: dropping $d would leave this root with no $r" 2
    c="$(carries "$d")"
    if [ -n "$c" ]; then [ "$landed" = 1 ] && { echo "KEPT $d: it still carries:$c"; exit 0; }; die "REFUSE(1): $d carries:$c -- give it to the grader (s4e_take.sh give) or land it first; nothing removed" 1; fi
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
    local T why="" o rc gf g="git -c user.name=probe -c user.email=probe@localhost -c init.defaultBranch=main" me="$HERE/s4e_take.sh" un="env -u S4E_SCRIP -u S4E_CORPUS -u S4E_HARNESS -u S4E_GITHUB"
    T="$(mktemp -d "/tmp/s4e/${S4E_SEAT:-seat}/take-probe.XXXXXX" 2>/dev/null || mktemp -d)" || die "REFUSE(2): no scratch" 2
    mkdir -p "$T/top/claude_x" && $g init -q --bare "$T/origin.git" && $g clone -q "$T/origin.git" "$T/top/corpus" 2>/dev/null \
        && git -C "$T/top/corpus" config user.name probe && git -C "$T/top/corpus" config user.email probe@localhost \
        && echo a > "$T/top/corpus/a" && $g -C "$T/top/corpus" add a && $g -C "$T/top/corpus" commit -qm a && $g -C "$T/top/corpus" push -q origin HEAD:main 2>/dev/null \
        && $g -C "$T/top/corpus" fetch -q origin || { rm -rf "$T"; die "REFUSE(2): cannot plant the scratch origin" 2; }
    run() { $un S4E_ONE_DISK_TOP="$T/top" S4E_GIVES="$T/gives" S4E_HOME="$T/top/claude_x" S4E_SEAT="${SEATAS:-x}" "$@"; }
    o="$(run bash "$me" corpus 2>&1)"; rc=$?
    [ "$rc" = 2 ] && [ ! -e "$T/top/claude_x/corpus" ] && printf '%s' "$o" | grep -q 'give' || why="$why arm 1: take did not refuse rc 2 naming the give, or it made a folder (rc $rc);"
    printf '%s\n' '--- a/a' '+++ b/a' '@@ -1 +1 @@' '-a' '+a2' > "$T/good.patch"; printf '%s\n' '--- a/a' '+++ b/a' '@@ -1 +1 @@' '-zzz' '+q' > "$T/bad.patch"
    o="$(run bash "$me" give corpus "$T/bad.patch" "a patch that does not apply" 2>&1)"; rc=$?
    [ "$rc" = 1 ] && [ -z "$(ls "$T/gives" 2>/dev/null | head -1)" ] || why="$why arm 2: give stored or passed a patch that does not apply (rc $rc);"
    o="$(run bash "$me" give corpus "$T/good.patch" "probe row: a becomes a2" 2>&1)"; rc=$?
    gf="$(ls "$T/gives"/*.patch 2>/dev/null | head -1)"
    [ "$rc" = 0 ] && [ -n "$gf" ] && grep -q "$(printf 'x\tcorpus\tprobe row: a becomes a2')" "$T/gives/GIVES.tsv" 2>/dev/null && [ "$(cat "$T/top/corpus/a")" = a ] || why="$why arm 2: give did not store the patch with its seat and why, or it changed the checkout (rc $rc);"
    [ -n "$gf" ] && [ "$(run bash "$me" base "$gf" 2>/dev/null)" = "$(git -C "$T/top/corpus" rev-parse HEAD)" ] || why="$why arm 2: the give does not name its base, the commit of the one checkout it was checked against;"
    o="$(run bash "$me" apply "$gf" 2>&1)"; rc=$?
    [ "$rc" = 2 ] && [ "$(cat "$T/top/corpus/a")" = a ] && [ -f "$gf" ] || why="$why arm 3: apply by a seat that is not the grader was not refused rc 2, or it changed something (rc $rc);"
    o="$(SEATAS=grader run bash "$me" apply "$gf" 2>&1)"; rc=$?
    [ "$rc" = 0 ] && [ "$(cat "$T/top/corpus/a")" = a2 ] && [ "$($g --git-dir="$T/origin.git" show main:a 2>/dev/null)" = a2 ] && [ ! -f "$gf" ] && [ -f "$T/gives/done/$(basename "$gf")" ] \
        && [ "$(git -C "$T/top/corpus" rev-parse HEAD)" = "$($g --git-dir="$T/origin.git" rev-parse main)" ] && $g --git-dir="$T/origin.git" log -1 --format=%s main | grep -q 'given by x through the grader' \
        || why="$why arm 4: the grader's apply did not land the give on origin under its why and giver (rc $rc: $(printf '%s' "$o" | tail -1 | cut -c1-120));"
    o="$(run bash "$me" check 2>&1)"; rc=$?
    [ "$rc" = 0 ] || why="$why arm 5: check read red with no folder in a seat root (rc $rc);"
    $g clone -q "$T/origin.git" "$T/top/claude_x/corpus" 2>/dev/null && git -C "$T/top/claude_x/corpus" config s4e.taken true
    o="$(run bash "$me" check 2>&1)"; rc=$?
    [ "$rc" = 1 ] && printf '%s' "$o" | grep -q "HELD $T/top/claude_x/corpus" || why="$why arm 5: check did not read red on a corpus folder standing in a seat root (rc $rc);"
    echo b > "$T/top/claude_x/corpus/b" && $g -C "$T/top/claude_x/corpus" add b && $g -C "$T/top/claude_x/corpus" commit -qm b
    o="$(run bash "$me" drop corpus 2>&1)"; rc=$?
    [ "$rc" = 1 ] && [ -d "$T/top/claude_x/corpus" ] && printf '%s' "$o" | grep -q 'unlanded-commits' || why="$why arm 6: drop did not refuse a folder holding an unlanded commit (rc $rc);"
    $g -C "$T/top/claude_x/corpus" reset -q --hard origin/main
    o="$(run bash "$me" drop corpus 2>&1)"; rc=$?
    [ "$rc" = 0 ] && [ ! -e "$T/top/claude_x/corpus" ] || why="$why arm 6: drop kept a folder clean at origin/main (rc $rc: $(printf '%s' "$o" | tail -1 | cut -c1-120));"
    o="$(run bash "$me" check 2>&1)"; rc=$?
    [ "$rc" = 0 ] || why="$why arm 6: check still read red after the drop (rc $rc);"
    if [ -z "$why" ]; then rm -rf "$T"; echo "TAKE probe ok arms=6 (take refuses every seat and makes nothing; give stores a patch that applies with its seat and why and refuses one that does not; apply is the grader's alone; the grader's apply lands the give on origin and the one checkout holds it; check reads red while a seat root holds one of the three; drop refuses unlanded work and removes a clean folder)"; return 0; fi
    echo "TAKE probe RED:$why"; echo "    kept: $T"; return 1
}
case "${1:-}" in
    --probe) probe; exit $? ;;
    list) list ;;
    check) check; exit $? ;;
    give) shift; repo_ok "${1:-}" || die "usage: s4e_take.sh give corpus|harness|.github <patch> \"<why>\"" 2; give "$1" "${2:-}" "${3:-}" ;;
    apply) shift; apply "${1:-}" ;;
    base) shift; b="$(awk -F'\t' -v b="$(basename "${1:-}")" '$1==b {print $5}' "$GIVES/GIVES.tsv" 2>/dev/null | tail -1)"; b="${b#base=}"; [ -n "$b" ] || die "REFUSE(1): no base recorded for '${1:-}' in $GIVES/GIVES.tsv (a give made before 2026-11-14 18:0x names none)" 1; echo "$b" ;;
    drop) shift; landed=0; [ "${1:-}" = --landed ] && { landed=1; shift; }; repo_ok "${1:-}" || die "usage: s4e_take.sh drop [--landed] corpus|harness|.github" 2; drop "$1" "$landed" ;;
    corpus|harness|.github) take "$1" ;;
    *) die "usage: s4e_take.sh give <repo> <patch> \"<why>\" | apply <given patch> | check | list | drop <repo> | --probe   (repo: corpus|harness|.github; a bare repo name REFUSES: no seat holds one)" 2 ;;
esac
