#!/usr/bin/env bash
# s4e_take.sh -- NO SEAT HOLDS corpus, harness OR .github: EVERY SEAT SHARES THE THREE THROUGH ONE PROXY, THE GRADER (Lon 2026-11-14 16:4x to 16:5x CST, in the
# cto's window, verbatim: "Well, the GRADER is meant to be the ONE maintainer of both corpus and harness, so ensure those folders do not exist anywhere in
# /home/claude folders." / "Only ONE maintainer has /home/{.github,corpus,harness} and that is GRADER." / "Ensure it no with words but inside the SHELL script." /
# "All seats SHARES these 3 REPOSITORIES through a PROXY/AGENT, named GRADER."; his word of that morning in the cio's window stands under it: "We are meant not to
# have folder .github, harness, and corpus in each /home/claude folder"). IT VOIDS the rule this tool carried since that morning, that a seat takes its own clone
# into its root while it carries a change. MEASURED by the cto at 16:5x: six such folders stood in seat roots, four of them holding work origin lacked.
# THE RULE, BUILT HERE: the three live once, at /home/corpus, /home/harness and /home/.github. A seat reads them there and never holds a copy. A seat that wants a
# change GIVES the grader a patch; the grader alone applies it to the one checkout, commits and pushes. One pusher, so two changes never race.
#   s4e_take.sh corpus|harness|.github          REFUSES rc 2 for every seat and makes nothing; its line names the patch
#   s4e_take.sh give <repo> <patch> "<why>" --proof '<command>'
#                                               a seat hands the grader a patch (unified diff, paths a/... b/... from the repo's top): checked to apply to the
#                                               one checkout as it stands, stored under the patches folder with its seat, its why and its proof; rc 1 when it
#                                               does not apply. THE PROOF IS A COMMAND, NEVER PROSE (the cio 2026-11-16, on the coo's ask and Lon's order of that
#                                               day to put the fleet on Icon graphics, every program of which reaches origin through this queue; MEASURED on the
#                                               148 patches given that day to 18:30Z: median wait 258 s, a tenth over 1050 s, the worst 2673 s; the grader landed
#                                               one patch at a time, its lander busy 57% of the time and idle 43%, the idle part being the grader's own turns, in
#                                               which it read each why and wrote the gate command by hand): one line, run by bash as the gate of the patch's
#                                               landing, rc 0 on the patched tree and not before. IT RUNS IN THE PATCHED REPO'S TOP, so a path is written as the
#                                               patch writes it (scripts/x.sh, skills/y/SKILL.md, packages/icon/z/ALL.csv; the cio 2026-11-16, MEASURED on the
#                                               drain's first hour: the coo's proof named scripts/util_graphics_progress.py and the gate, run in the worktree's
#                                               top, could not open it). It also reads the patched trees as $S4E_HARNESS, $S4E_CORPUS and
#                                               $S4E_HOME/.github, and a SCRIP built at origin/main as $S4E_SCRIP; a longer proof is a script under /home/resources
#                                               that the command names. A give with no --proof is refused rc 2 and stores nothing.
#                                               A PATCH THAT DELETES SAYS SO IN NUMBERS (the cio 2026-11-16, on the cto's measurement and ask: corpus 157acb344, five
#                                               new entries of ipl_gprogs cut as a whole-folder difference from a scratch copy older than the tree, deleted 40 files
#                                               other owners had landed since and reverted 17 answers, and applied clean with its proof green): give counts, on the
#                                               patch applied at its base through a private index, the files it deletes and the rows of an ALL.csv (by entry) or an
#                                               ALL.args (by first column) it drops, and refuses rc 1 unless the giver states exactly those numbers after the proof:
#                                               --deletes N and --drops K. The same for a file the patch PUTS BACK to a text it had before (its new text equal to
#                                               one of that file's last twenty versions, as the 17 answers were): --reverts R. AND FOR WHAT IT CHANGES OF AN ENTRY IT
#                                               DOES NOT ADD (the cto's ruling of 2026-11-16 13:1x CST, the grader's row check folded in): in corpus, under tests,
#                                               packages and demos, each changed file that is no table (an answer, an input, a program, a script of events) and each
#                                               row of an ALL.csv (its rank aside) or ALL.args that stood before and reads differently after: --changes C. The
#                                               refusal names the first five of each, so a giver sees what its patch touches that it did not mean. A patch that
#                                               does none of the four needs no number.
#   s4e_take.sh drain [--wait SECONDS]          THE GRADER ONLY: lands EVERY waiting patch that carries a proof, one after another with no turn of the grader
#                                               between two, each as grader_give.sh landed one (the patches worktree at origin/main, or at the patch's base when it
#                                               applies only there; s4e_land.sh with the proof as its gate). Oldest first, after the patches a line of FIRST.conf in
#                                               the patches folder names (an extended regular expression read against giver, repo and why, tab separated: the one
#                                               switch that says what goes first). LAND ok moves the patch to done; LAND RED moves it to refused with the log's last
#                                               lines beside it and prints one TELL line for its giver; a landing that could not measure leaves the patch waiting
#                                               and is not tried again in this run, and a patch whose PROOF could not measure (the gate's rc 2) a second time
#                                               goes back to its giver like a red one, since a proof that cannot run never will. A patch given before the proof was a command is named NEEDS-GATE and left for
#                                               grader_give.sh. One line a patch in DRAIN.tsv (given, started, ended, seconds, outcome). One drain at a time: a
#                                               second says so and ends rc 0. --wait keeps it waiting that long for the next patch once the queue is empty.
#                                               LANES (the cto 2026-11-16, row harness-the-graders-drain-lands-in-lanes-and-regates-a-patch-only-for-its-own-directories): lanes=N, one
#                                               line of DRAIN.conf in the patches folder, runs N landings at once, lane 1 in the patches worktree and lane K in its sibling
#                                               <worktree>K (made by s4e_worktree.sh as the first was, when missing); a lane claims its patch by a rename into lane<K>/ of the
#                                               patches folder, read as waiting by the count; a patch waits while an OLDER patch of its giver to its repo waits or is in a lane
#                                               (FIRST.conf's patches excepted); DRAIN.tsv's ninth column is the lane. No line: one lane, the drain of before. Each landing is
#                                               given --regate own: it gates again only for a mover in its own directories, never for one under SCRIP's runtime.
#   s4e_take.sh apply <given patch>             THE GRADER ONLY (S4E_SEAT=grader; any other seat rc 2): brings the one checkout to origin/main, applies the patch,
#                                               commits it under its why and its giver, pushes; a patch that no longer applies, or a push origin refuses, leaves
#                                               the checkout at origin/main and the patch where it was
#   s4e_take.sh base <given patch>              prints the commit of the one checkout the patch was checked against: where the grader applies a patch that no longer
#                                               applies at origin/main (a witness added to a container another patch has since renumbered), before its landing's rebase
#   s4e_take.sh check                           rc 1 and one line a folder while ANY seat root under the top holds corpus, harness or .github; rc 0 when none does
#   s4e_take.sh list                            the repos this root still holds, each with what it carries
#   s4e_take.sh drop corpus|harness|.github     remove one this root still holds; refuses rc 1, naming what would be lost, while it holds an edit, an untracked
#                                               file, a stash or a commit origin/main lacks (drop --landed is the lander's call after its push). These two verbs
#                                               stay only to drain the folders made before this rule.
#   s4e_take.sh --probe                         six arms on a scratch origin, top and root; nothing live touched. TAKE probe ok|RED
#   s4e_take.sh --probe-lanes                   five arms (a to e) on scratch origins and a scratch patches folder, the real lander in two; TAKE lanes-probe ok|RED
# HOW A SEAT WRITES A PATCH WITH NO CLONE: copy the files it changes from /home/<repo> to its scratch (/tmp/s4e/<seat>/), edit the copies, and
# diff -u --label a/<path> --label b/<path> /home/<repo>/<path> <its copy>; a new file is a diff against /dev/null with --label a/<path> too.
# The root is S4E_HOME; the top is /home (S4E_ONE_DISK_TOP names another, the probe's seam); the patches folder is /home/resources/postoffice/gives (S4E_GIVES).
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
give_keys() {   # <file name>: the keys of a table on standard input, the entry column of an ALL.csv (its second), the first column of any other
    case "$1" in *ALL.csv) awk -F, 'NR>1 {print $2}' ;; *) grep -v '^#' | cut -f1 ;; esac
}
give_rows() {   # <file name>: key, a tab, the row, of a table on standard input; an ALL.csv's row without its rank, which every insertion counts again
    case "$1" in *ALL.csv) awk 'NR>1 {r=$0; sub(/^[^,]*,/, "", r); k=r; sub(/,.*/, "", k); print k "\t" r}' ;; *) grep -v '^#' | awk -F'\t' '{print $1 "\t" $0}' ;; esac
}
give() {
    local r="$1" p="${2:-}" why="${3:-}" pf="${4:-}" proof="${5:-}" seat="${S4E_SEAT:-}" src err="" out base ob hb at ix say_del=0 say_drop=0 say_rev=0 say_chg=0 ndel=0 ndrop=0 nrev=0 nchg=0 f nb dl="" dr="" rv="" ch=""
    shift 5 2>/dev/null || shift $#
    while [ $# -gt 0 ]; do case "$1" in --deletes) say_del="${2:-0}"; shift 2 ;; --drops) say_drop="${2:-0}"; shift 2 ;; --reverts) say_rev="${2:-0}"; shift 2 ;; --changes) say_chg="${2:-0}"; shift 2 ;; *) die "REFUSE(2): unknown argument '$1' after the proof (--deletes N, --drops K, --reverts R, --changes C)" 2 ;; esac; done
    [ -n "$seat" ] || die "REFUSE(2): S4E_SEAT is unset: a patch names its seat" 2
    [ -n "$p" ] && [ -s "$p" ] || die "REFUSE(2): no patch at '$p' (usage: s4e_take.sh give corpus|harness|.github <patch> \"<why>\")" 2
    [ -n "$why" ] || die "REFUSE(2): a patch says why, the row and what the change does (usage: s4e_take.sh give $r <patch> \"<why>\")" 2
    case "$why" in *$'\t'*|*$'\n'*) die "REFUSE(2): the why is one line with no tab" 2 ;; esac
    [ "$pf" = --proof ] && [ -n "$proof" ] || die "REFUSE(2): a patch carries its proof as a COMMAND, and nothing was given: s4e_take.sh give $r <patch> \"<why>\" --proof '<command>'. The command is one line, run by bash as the gate of the patch's landing: rc 0 on the patched tree and not before. It reads the patched trees as \$S4E_HARNESS, \$S4E_CORPUS and \$S4E_HOME/.github and a SCRIP built at origin/main as \$S4E_SCRIP (name your own root there when the proof needs your unlanded SCRIP); a longer proof is a script under /home/resources that the command names. With it the grader's drain lands the patch with no turn of the grader (the cio 2026-11-16)." 2
    case "$proof" in *$'\t'*|*$'\n'*) die "REFUSE(2): the proof is one line with no tab (a longer proof is a script under /home/resources that the command names)" 2 ;; esac
    src="$TOP/$r"; [ -d "$src/.git" ] || die "REFUSE(2): no checkout at $src" 2
    p="$(readlink -f "$p")"
    # THE CHECK IS AGAINST ORIGIN FIRST, THEN THE CHECKOUT'S HEAD, AND NEVER THE WORKING FILES (the cio 2026-11-15, on the grader's ask): the keeper stood
    # /home/.github at 61ee066a5 for 140 minutes while origin moved twice, and a patch cut on origin was refused here while one cut on the checkout
    # conflicted at the grader's rebase. Each check reads a commit through a private index, so a stalled or dirtied checkout blocks no giver.
    ob="$(git -C "$src" rev-parse -q --verify refs/remotes/origin/main 2>/dev/null)"; hb="$(git -C "$src" rev-parse -q --verify HEAD 2>/dev/null)"; base=""
    for at in "$ob" "$hb"; do
        [ -n "$at" ] && [ -z "$base" ] || continue
        ix="$(mktemp -u "${TMPDIR:-/tmp}/s4e-give-index.XXXXXX")"
        if GIT_INDEX_FILE="$ix" git -C "$src" read-tree "$at" 2>/dev/null && err="$(GIT_INDEX_FILE="$ix" git -C "$src" apply --cached --check "$p" 2>&1)"; then base="$at"; fi
        rm -f "$ix"
    done
    [ -n "$base" ] || die "REFUSE(1): the patch applies neither to origin/main ${ob:0:10} nor to $src at ${hb:0:10}: $(printf '%s' "$err" | head -1). Nothing given." 1
    ix="$(mktemp -u "${TMPDIR:-/tmp}/s4e-give-index.XXXXXX")"
    if GIT_INDEX_FILE="$ix" git -C "$src" read-tree "$base" 2>/dev/null && GIT_INDEX_FILE="$ix" git -C "$src" apply --cached "$p" 2>/dev/null; then
        while IFS=$'\t' read -r at f; do
            case "$at" in D) ndel=$((ndel + 1)); [ "$ndel" -gt 5 ] || dl="$dl $f" ;; esac
            if [ "$at" = M ]; then
                nb="$(GIT_INDEX_FILE="$ix" git -C "$src" ls-files -s -- "$f" 2>/dev/null | cut -d' ' -f2)"
                if [ -n "$nb" ] && git -C "$src" log -n 20 --format= --raw --no-abbrev "$base" -- "$f" 2>/dev/null | cut -d' ' -f3 | grep -q -x "$nb"; then nrev=$((nrev + 1)); [ "$nrev" -gt 5 ] || rv="$rv $f"; fi
            fi
            case "$r:$at:$f" in corpus:M:tests/*|corpus:M:packages/*|corpus:M:demos/*)
                case "${f##*/}" in
                    ALL.csv|ALL.args) nb="$(awk -F'\t' 'NR==FNR {b[$1]=$0; next} ($1 in b) && b[$1] != $0 {n++} END {print n+0}' <(git -C "$src" show "$base:$f" 2>/dev/null | give_rows "$f") <(GIT_INDEX_FILE="$ix" git -C "$src" show ":$f" 2>/dev/null | give_rows "$f"))"
                        [ "$nb" = 0 ] || { nchg=$((nchg + nb)); ch="$ch $nb row(s) of $f"; } ;;
                    ALL.*|PARTITION.tsv|*.tsv|README.md|MULTI-LINERS.md|ONE-LINERS.*) ;;
                    *) nchg=$((nchg + 1)); [ "$(printf '%s' "$ch" | wc -w)" -gt 8 ] || ch="$ch $f" ;;
                esac ;;
            esac
            case "$at:$f" in M:*ALL.csv|M:*ALL.args)
                at="$(comm -23 <(git -C "$src" show "$base:$f" 2>/dev/null | give_keys "$f" | sort -u) <(GIT_INDEX_FILE="$ix" git -C "$src" show ":$f" 2>/dev/null | give_keys "$f" | sort -u))"
                [ -z "$at" ] || { ndrop=$((ndrop + $(printf '%s\n' "$at" | wc -l))); dr="$dr $f:$(printf '%s' "$at" | head -3 | tr '\n' ',')"; } ;;
            esac
        done < <(GIT_INDEX_FILE="$ix" git -C "$src" diff-index --cached --name-status "$base" 2>/dev/null)
    fi
    rm -f "$ix"
    [ "$ndel" = "$say_del" ] && [ "$ndrop" = "$say_drop" ] && [ "$nrev" = "$say_rev" ] && [ "$nchg" = "$say_chg" ] || die "REFUSE(1): the patch DELETES $ndel file(s)${dl:+ ($dl ...)}, DROPS $ndrop table row(s)${dr:+ ($dr)}, PUTS BACK $nrev file(s) to an older text${rv:+ ($rv ...)} and CHANGES $nchg file(s) or row(s) of entries it does not add${ch:+ ($ch ...)}, and you stated --deletes $say_del --drops $say_drop --reverts $say_rev --changes $say_chg. Nothing given. A patch cut as a whole-folder difference from a scratch copy older than the tree deletes what others landed since (MEASURED 2026-11-16: corpus 157acb344 deleted 40 files of ipl_gprogs and applied clean). Cut the patch again from the files YOU changed, each against /home/$r as it stands now; or, if you mean every one of them, state the numbers after the proof: --deletes $ndel --drops $ndrop --reverts $nrev --changes $nchg (a number that is 0 may be left out)." 1
    mkdir -p "$GIVES" 2>/dev/null || die "REFUSE(2): cannot make $GIVES" 2
    out="$GIVES/$(date -u +%Y%m%dT%H%M%SZ)-$seat-${r#.}-$$.patch"
    :   # THE PATCH NAMES ITS BASE (the cio 2026-11-14, ruled with the grader): the commit of the one checkout the patch was checked against. A patch that adds an entry to a container renumbers every row below it, so once another such patch lands it applies nowhere but at its base; the grader applies it there, in a worktree, and its landing's rebase merges the container's tables by entry key (util_table_merge.py, s4e_land.sh)
    cp "$p" "$out" && printf '%s\t%s\t%s\t%s\t%s\n' "$(basename "$out")" "$seat" "$r" "$why" "base=$base	proof=$proof" >> "$GIVES/GIVES.tsv" || die "REFUSE(2): cannot store the patch in $GIVES" 2
    echo "GIVEN $out ($r, by $seat, base ${base:0:10}: $why). The grader alone applies it."
    if flock -n "$GIVES/.drain.lock" true 2>/dev/null; then echo "WAKE: SendMessage to GRADER now with this first line: \"patch $(basename "$out") waits with its proof: run bash $TOP/harness/scripts/s4e_take.sh drain\""
    else echo "NO WAKE IS OWED: the grader's drain is running (lock $GIVES/.drain.lock) and lands this patch on its proof with no turn of the grader; a red proof comes back to you by telegram."; fi
}
drain_tell() {   # <giver> <patch> <one line>: the giver is told by telegram, by the drain itself (the cio 2026-11-16, MEASURED in the drain's first hour: officer_06's red patch was named only in the drain's own output, which stood in the grader's background); never a reason to stop the drain
    local giver="$1" b="$2" line="$3" t
    echo "TELL $giver: $line"
    t="your-patch-$(printf '%s' "${b%%-*}" | tr 'A-Z' 'a-z')-came-back-from-the-graders-drain"
    { printf 'From the grader'"'"'s drain (s4e_take.sh drain), %s. %s\n' "$(date -u +%FT%TZ)" "$line"; [ -s "$GIVES/refused/${b%.patch}.why" ] && { echo "THE LAST LINES OF ITS LANDING:"; cat "$GIVES/refused/${b%.patch}.why"; }; echo "The patch stands in $GIVES/refused/$b. Nothing was pushed."; } \
        | tr -d '`' | sed 's/\$(/(/g' | ( cd "${S4E_HOME:-$WT}" && S4E_SEAT=grader bash "$MSG" send "$giver" "$t" --stdin > /dev/null 2>&1 ) || echo "DRAIN: the telegram to $giver was not sent; pass the TELL line on by hand"
}
drain_next() {   # sets NEXT to the next waiting patch that carries a proof and was not tried in this run: FIRST.conf's patches first, then the oldest; a patch waits while
    # an OLDER patch of its own giver to its own repo waits or is in a lane (the cto 2026-11-16, row harness-the-graders-drain-lands-in-lanes-and-regates-a-patch-only-for-its-own-directories:
    # a giver's second patch is often cut on its first), unless FIRST.conf names it, the one switch that says what goes first
    local f b row key first="" rest="" o ob okey
    for f in "$GIVES"/*.patch; do
        [ -s "$f" ] || continue; b="$(basename "$f")"
        case " $TRIED " in *" $b "*) continue ;; esac
        row="$(awk -F'\t' -v b="$b" '$1==b' "$GIVES/GIVES.tsv" 2>/dev/null | tail -1)"
        case "$(printf '%s' "$row" | cut -f6)" in proof=?*) ;; *) case " $NOGATE " in *" $b "*) ;; *) NOGATE="$NOGATE $b"; echo "NEEDS-GATE $b: given with no proof command; land it by grader_give.sh" >&2 ;; esac; continue ;; esac
        key="$(printf '%s' "$row" | cut -f2-4)"
        if [ -s "$GIVES/FIRST.conf" ] && printf '%s\n' "$key" | grep -q -E -f <(grep -v -e '^#' -e '^$' "$GIVES/FIRST.conf") 2>/dev/null; then [ -n "$first" ] || first="$f"; continue; fi
        [ -n "$rest" ] && continue
        okey="$(printf '%s' "$row" | cut -f2-3)"
        for o in "$GIVES"/*.patch "$GIVES"/lane*/*.patch; do
            [ -f "$o" ] || continue; ob="$(basename "$o")"; [ "$ob" != "$b" ] || continue
            [ "$(printf '%s\n%s\n' "$ob" "$b" | LC_ALL=C sort | head -1)" = "$ob" ] || continue
            [ "$(awk -F'\t' -v b="$ob" '$1==b {k=$2 "\t" $3} END {print k}' "$GIVES/GIVES.tsv" 2>/dev/null)" = "$okey" ] || continue
            case " $WAITED " in *" $b "*) ;; *) WAITED="$WAITED $b"; echo "DRAIN: $b waits for $ob, an older patch of its giver to the same repo" ;; esac
            continue 2
        done
        rest="$f"
    done
    NEXT="${first:-$rest}"
}
drain_one() {   # <given patch>: one landing; rc 0 landed, 1 red (the patch is the giver's again), 2 could not measure (the patch waits)
    local g="$1" b row giver r why base proof d log t0 t1 out given
    b="$(basename "$g")"; row="$(awk -F'\t' -v b="$b" '$1==b' "$GIVES/GIVES.tsv" | tail -1)"
    giver="$(printf '%s' "$row" | cut -f2)"; r="$(printf '%s' "$row" | cut -f3)"; why="$(printf '%s' "$row" | cut -f4)"; base="$(printf '%s' "$row" | cut -f5)"; base="${base#base=}"; proof="$(printf '%s' "$row" | cut -f6)"; proof="${proof#proof=}"
    given="${b%%-*}"; t0="$(date -u +%s)"; out=held; d="$WT/$r"; mkdir -p "$GIVES/logs" "$GIVES/done" "$GIVES/refused"; log="$GIVES/logs/land_${b%.patch}.log"
    fin() { t1="$(date -u +%s)"; printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$b" "$giver" "$r" "$given" "$(date -u -d "@$t0" +%Y%m%dT%H%M%SZ)" "$(date -u -d "@$t1" +%Y%m%dT%H%M%SZ)" "$((t1 - t0))" "$out" "${LANE:-1}" >> "$GIVES/DRAIN.tsv"; }
    if ! repo_ok "$r" || { [ ! -d "$d/.git" ] && [ ! -f "$d/.git" ]; }; then echo "HELD $b: no $r in the patches worktree $WT"; fin; return 2; fi
    if [ -n "$(git -C "$d" status --porcelain 2>/dev/null | grep -v '^??' | head -1)" ]; then echo "HELD $b: $d holds an edit; nothing applied"; fin; return 2; fi
    if ! { git -C "$d" fetch -q origin 2>/dev/null && git -C "$d" checkout -q --detach origin/main 2>/dev/null; }; then echo "HELD $b: cannot bring $d to origin/main"; fin; return 2; fi
    if ! git -C "$d" apply --index "$g" 2>/dev/null; then
        if [ -n "$base" ] && git -C "$d" checkout -q --detach "$base" 2>/dev/null && git -C "$d" apply --index "$g" 2>/dev/null; then :; else
            git -C "$d" checkout -q --detach origin/main 2>/dev/null; out=red:apply; mv "$g" "$GIVES/refused/"; echo "applies neither at origin/main nor at its base ${base:-(none recorded)}" > "$GIVES/refused/${b%.patch}.why"
            echo "REFUSED $b by $giver: it applies neither at origin/main nor at its base ${base:0:10}"; drain_tell "$giver" "$b" "patch $b no longer applies; make it again on today's files and give it again"; fin; return 1
        fi
    fi
    if ! git -C "$d" commit -q -m "$why (given by $giver through the grader: $b)" 2>/dev/null; then
        git -C "$d" reset -q --hard 2>/dev/null; git -C "$d" checkout -q --detach origin/main 2>/dev/null; out=red:empty; mv "$g" "$GIVES/refused/"; echo "nothing to commit: origin already holds it" > "$GIVES/refused/${b%.patch}.why"
        echo "REFUSED $b by $giver: nothing to commit (origin already holds it)"; fin; return 1
    fi
    ( cd "${S4E_HOME:-$WT}" && S4E_SEAT=grader bash "$LANDER" --home "$WT" --gate "cd \"$d\" && ( $proof )" "$r" --regate own > "$log" 2>&1 )
    if grep -q '^LAND ok' "$log"; then out=ok; mv "$g" "$GIVES/done/"; echo "LANDED $b by $giver: $(grep -o 'pushed=[^ ]*' "$log" | tail -1)"; fin; return 0; fi
    git -C "$d" checkout -q --detach origin/main 2>/dev/null
    if grep -q '^LAND RED' "$log"; then
        out="red:$(grep -o '^LAND RED stage=[a-z:_A-Za-z0-9]*' "$log" | tail -1 | sed 's/.*stage=//')"; mv "$g" "$GIVES/refused/"; tail -5 "$log" | cut -c1-400 > "$GIVES/refused/${b%.patch}.why"
        echo "REFUSED $b by $giver: $(grep '^LAND RED' "$log" | tail -1 | cut -c1-200); log $log"; drain_tell "$giver" "$b" "patch $b read red on its own proof ($out); the log is $log; cure it and give it again"; fin; return 1
    fi
    if grep -q 'the gate could not measure' "$log" && awk -F'\t' -v b="$b" '$1==b && $8=="held"' "$GIVES/DRAIN.tsv" 2>/dev/null | grep -q .; then
        out=red:proof-rc2; mv "$g" "$GIVES/refused/"; tail -5 "$log" | cut -c1-400 > "$GIVES/refused/${b%.patch}.why"
        echo "REFUSED $b by $giver: its proof could not measure twice (rc 2); log $log"; drain_tell "$giver" "$b" "patch $b: your proof command could not run or measure, twice (rc 2; the log is $log); it runs in the patched repo's top; cure the command and give the patch again"; fin; return 1
    fi
    echo "HELD $b: the landing could not measure ($(grep -E '^LAND (REFUSE|stage)' "$log" | tail -1 | cut -c1-160)); the patch waits; log $log"; fin; return 2
}
drain_lanes() {   # the lanes of DRAIN.conf in the patches folder: lanes=N, one line (no line, or no file: one lane, the drain of before)
    local v; v="$(awk -F= '!/^#/ && $1 == "lanes" { v = $2 } END { print v }' "$GIVES/DRAIN.conf" 2>/dev/null)"
    case "$v" in ''|*[!0-9]*|0) echo 1 ;; *) echo "$v" ;; esac
}
lane_wt() { if [ "$1" = 1 ]; then printf '%s' "$WT"; else printf '%s%s' "$WT" "$1"; fi; }   # lane 1 is the patches worktree; lane K its sibling <worktree>K (wt-gives2, wt-gives3, ...)
lane_ready() {   # <K>: rc 0 when lane K has its worktree; a missing one beside a worktree s4e_worktree.sh made is made the same way, once a run
    local k="$1" w n lang
    w="$(lane_wt "$k")"; [ -e "$w/corpus/.git" ] || [ -e "$w/harness/.git" ] || [ -e "$w/SCRIP/.git" ] && return 0
    case " $LANE_TRIED " in *" $k "*) return 1 ;; esac; LANE_TRIED="$LANE_TRIED $k"
    [ -f "$WT/.s4e-worktree" ] || { echo "DRAIN: lane $k has no worktree at $w (and $WT was not made by s4e_worktree.sh, so none is made): it runs no patch"; return 1; }
    n="$(basename "$WT")"; n="${n#wt-}$k"; lang="$(sed -n 's/^corpus=sparse://p' "$WT/.s4e-worktree" | head -1)"
    if S4E_SEAT=grader bash "$HERE/s4e_worktree.sh" new "$n" ${lang:+--lang "$lang"} > "$GIVES/logs/lane$k.worktree.log" 2>&1 9>&- && [ -d "$w" ]; then echo "DRAIN: lane $k made its worktree $w"; return 0; fi
    echo "DRAIN: lane $k could not make its worktree $w (log $GIVES/logs/lane$k.worktree.log): it runs no patch"; return 1
}
lane_scrip() {   # <worktree>: the proofs' SCRIP stands at origin/main, built: read at most every two minutes a lane (a stamp file's age)
    local sd="$1/SCRIP" st="$1/.drain-scrip-read"
    [ -e "$sd/.git" ] || return 0
    [ -n "$(find "$st" -mmin -2 2>/dev/null)" ] && return 0
    : > "$st" 2>/dev/null; git -C "$sd" fetch -q origin 2>/dev/null
    [ "$(git -C "$sd" rev-parse HEAD 2>/dev/null)" = "$(git -C "$sd" rev-parse origin/main 2>/dev/null)" ] || { git -C "$sd" checkout -q --detach origin/main 2>/dev/null && make -C "$sd" -j8 > "$GIVES/logs/scrip_build.$(basename "$1").log" 2>&1 || echo "DRAIN: $sd did not build at origin/main (log $GIVES/logs/scrip_build.$(basename "$1").log); proofs that run SCRIP will read red"; }
}
drain() {
    local seat="${S4E_SEAT:-}" wait_s=0 waited=0 g b k rc n_ok=0 n_red=0 n_held=0 nl busy f
    local -A LP=() LB=()
    [ "$seat" = grader ] || die "REFUSE(2): only the grader drains the patches (this seat is '${seat:-unset}'); nothing landed. A seat gives: s4e_take.sh give <repo> <patch> \"<why>\" --proof '<command>'." 2
    [ "${1:-}" = --wait ] && wait_s="${2:-0}"; case "$wait_s" in ''|*[!0-9]*) die "usage: s4e_take.sh drain [--wait SECONDS]" 2 ;; esac
    WT="${S4E_GIVES_WT:-/home/resources/worktrees/grader/wt-gives}"; LANDER="${S4E_TAKE_LANDER:-$HERE/s4e_land.sh}"; MSG="${S4E_TAKE_MSG:-$HERE/s4e_msg.sh}"; TRIED=""; NOGATE=""; NEXT=""; WAITED=""; LANE_TRIED=""
    [ -d "$WT" ] || die "REFUSE(2): no patches worktree at $WT (S4E_GIVES_WT names another)" 2
    mkdir -p "$GIVES" && exec 9> "$GIVES/.drain.lock" || die "REFUSE(2): cannot open $GIVES/.drain.lock" 2
    flock -n 9 || { echo "DRAIN is already running (lock $GIVES/.drain.lock): it lands every waiting patch that carries a proof, this one too"; return 0; }
    mkdir -p "$GIVES/logs" "$GIVES/done" "$GIVES/refused"
    for f in "$GIVES"/lane*/*.patch; do [ -f "$f" ] && mv "$f" "$GIVES/" && echo "DRAIN: $(basename "$f") was left in $(basename "$(dirname "$f")") by a drain that ended; it waits again"; done
    # THE LANES (the cto 2026-11-16, row harness-the-graders-drain-lands-in-lanes-and-regates-a-patch-only-for-its-own-directories; MEASURED 19:59Z: 18 patches waiting, one
    # drain landing one at a time, so one long proof held every patch behind it; nine patches waited 1100 to 1550 s before their landing began). lanes=N of DRAIN.conf runs
    # N landings at once, each in a worktree of its own; a lane claims its patch by a rename into its own folder (lane<K>/ of the patches folder), which the waiting count
    # reads as waiting; DRAIN.tsv's last column names the lane. With no line the drain is one lane, the drain of before. Two lanes that add entries to one container both
    # land: the lander's rebase merges its tables by entry key.
    nl="$(drain_lanes)"; [ "$nl" = 1 ] || echo "DRAIN lanes=$nl (DRAIN.conf)"
    while :; do
        for k in "${!LP[@]}"; do
            kill -0 "${LP[$k]}" 2>/dev/null && continue
            wait "${LP[$k]}"; rc=$?
            case "$rc" in 0) n_ok=$((n_ok + 1)) ;; 1) n_red=$((n_red + 1)) ;; *) n_held=$((n_held + 1)) ;; esac
            [ -f "$GIVES/lane$k/${LB[$k]}" ] && mv "$GIVES/lane$k/${LB[$k]}" "$GIVES/"
            unset "LP[$k]" "LB[$k]"
        done
        g=""
        for k in $(seq 1 "$nl"); do
            [ -n "${LP[$k]:-}" ] && continue
            lane_ready "$k" || continue
            drain_next; g="$NEXT"; [ -n "$g" ] || break
            b="$(basename "$g")"; TRIED="$TRIED $b"; mkdir -p "$GIVES/lane$k"
            mv "$g" "$GIVES/lane$k/$b" 2>/dev/null || continue
            lane_scrip "$(lane_wt "$k")"
            ( WT="$(lane_wt "$k")"; LANE="$k"; drain_one "$GIVES/lane$k/$b" ) 9>&- &
            LP[$k]=$!; LB[$k]="$b"
            [ "$nl" = 1 ] || echo "DRAIN lane $k takes $b"
        done
        busy="${#LP[@]}"
        if [ "$busy" = 0 ] && [ -z "$g" ]; then
            [ "$waited" -lt "$wait_s" ] || break; sleep 5; waited=$((waited + 5)); continue
        fi
        waited=0; sleep 1
    done
    echo "DRAIN done: landed=$n_ok refused=$n_red held=$n_held needs_gate=$(printf '%s' "$NOGATE" | wc -w) waiting=$(ls "$GIVES"/*.patch "$GIVES"/lane*/*.patch 2>/dev/null | wc -l) (ledger $GIVES/DRAIN.tsv)"
    [ "$n_red" = 0 ] && [ "$n_held" = 0 ]
}
apply() {
    local g="${1:-}" seat="${S4E_SEAT:-}" row r giver why src
    [ "$seat" = grader ] || die "REFUSE(2): only the grader applies a patch (this seat is '${seat:-unset}'); nothing applied. A seat gives: s4e_take.sh give <repo> <patch> \"<why>\"." 2
    [ -n "$g" ] && [ -s "$g" ] || die "REFUSE(2): no patch at '$g' (usage: s4e_take.sh apply <given patch>)" 2
    g="$(readlink -f "$g")"
    row="$(awk -F'\t' -v b="$(basename "$g")" '$1==b' "$GIVES/GIVES.tsv" 2>/dev/null | tail -1)"
    [ -n "$row" ] || die "REFUSE(2): $(basename "$g") is not a patch recorded in $GIVES/GIVES.tsv; nothing applied" 2
    giver="$(printf '%s' "$row" | cut -f2)"; r="$(printf '%s' "$row" | cut -f3)"; why="$(printf '%s' "$row" | cut -f4)"
    repo_ok "$r" || die "REFUSE(2): the patch names no repo of the three ('$r')" 2
    src="$TOP/$r"; [ -d "$src/.git" ] || die "REFUSE(2): no checkout at $src" 2
    [ -z "$(git -C "$src" status --porcelain 2>/dev/null | head -1)" ] || die "REFUSE(1): $src is not clean; nothing applied (git -C $src status)" 1
    git -C "$src" fetch -q origin 2>/dev/null || die "REFUSE(2): cannot fetch origin in $src; nothing applied" 2
    git -C "$src" merge -q --ff-only origin/main 2>/dev/null || die "REFUSE(1): $src does not fast-forward to origin/main; nothing applied" 1
    git -C "$src" apply --index "$g" 2>/dev/null || die "REFUSE(1): the patch no longer applies to $src at origin/main $(git -C "$src" rev-parse --short=10 HEAD); nothing applied. Its base is $(printf '%s' "$row" | cut -f5 | sed 's/^base=//;s/^$/not recorded/'): applied there in a worktree and landed with s4e_land.sh, the rebase merges a container's tables by entry key (s4e_take.sh base <patch> prints it); for any other file $giver makes it again on today's files." 1
    if ! git -C "$src" commit -q -m "$why (given by $giver through the grader: $(basename "$g"))" 2>/dev/null; then
        git -C "$src" reset -q --hard origin/main; die "REFUSE(1): the commit was refused; $src is back at origin/main; nothing applied" 1
    fi
    if ! git -C "$src" push -q origin HEAD:main 2>/dev/null; then
        git -C "$src" reset -q --hard origin/main; die "REFUSE(1): origin refused the push; $src is back at origin/main and the patch stands; apply it again" 1
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
    [ "$rc" = 2 ] && [ ! -e "$T/top/claude_x/corpus" ] && printf '%s' "$o" | grep -q 'give' || why="$why arm 1: take did not refuse rc 2 naming the patch, or it made a folder (rc $rc);"
    printf '%s\n' '--- a/a' '+++ b/a' '@@ -1 +1 @@' '-a' '+a2' > "$T/good.patch"; printf '%s\n' '--- a/a' '+++ b/a' '@@ -1 +1 @@' '-zzz' '+q' > "$T/bad.patch"
    o="$(run bash "$me" give corpus "$T/good.patch" "a patch with no proof command" 2>&1)"; rc=$?
    [ "$rc" = 2 ] && [ -z "$(ls "$T/gives" 2>/dev/null | head -1)" ] && printf '%s' "$o" | grep -q -- '--proof' || why="$why arm 2: give took a patch with no proof command, or its refusal does not name --proof (rc $rc);"
    o="$(run bash "$me" give corpus "$T/bad.patch" "a patch that does not apply" --proof true 2>&1)"; rc=$?
    [ "$rc" = 1 ] && [ -z "$(ls "$T/gives" 2>/dev/null | head -1)" ] || why="$why arm 2: give stored or passed a patch that does not apply (rc $rc);"
    o="$(run bash "$me" give corpus "$T/good.patch" "probe row: a becomes a2" --proof true 2>&1)"; rc=$?
    gf="$(ls "$T/gives"/*.patch 2>/dev/null | head -1)"
    [ "$rc" = 0 ] && [ -n "$gf" ] && grep -q "$(printf 'x\tcorpus\tprobe row: a becomes a2')" "$T/gives/GIVES.tsv" 2>/dev/null && [ "$(cat "$T/top/corpus/a")" = a ] || why="$why arm 2: give did not store the patch with its seat and why, or it changed the checkout (rc $rc);"
    [ -n "$gf" ] && [ "$(run bash "$me" base "$gf" 2>/dev/null)" = "$(git -C "$T/top/corpus" rev-parse HEAD)" ] || why="$why arm 2: the patch does not name its base, the commit of the one checkout it was checked against;"
    o="$(run bash "$me" apply "$gf" 2>&1)"; rc=$?
    [ "$rc" = 2 ] && [ "$(cat "$T/top/corpus/a")" = a ] && [ -f "$gf" ] || why="$why arm 3: apply by a seat that is not the grader was not refused rc 2, or it changed something (rc $rc);"
    o="$(SEATAS=grader run bash "$me" apply "$gf" 2>&1)"; rc=$?
    [ "$rc" = 0 ] && [ "$(cat "$T/top/corpus/a")" = a2 ] && [ "$($g --git-dir="$T/origin.git" show main:a 2>/dev/null)" = a2 ] && [ ! -f "$gf" ] && [ -f "$T/gives/done/$(basename "$gf")" ] \
        && [ "$(git -C "$T/top/corpus" rev-parse HEAD)" = "$($g --git-dir="$T/origin.git" rev-parse main)" ] && $g --git-dir="$T/origin.git" log -1 --format=%s main | grep -q 'given by x through the grader' \
        || why="$why arm 4: the grader's apply did not land the patch on origin under its why and giver (rc $rc: $(printf '%s' "$o" | tail -1 | cut -c1-120));"
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
    $g clone -q "$T/origin.git" "$T/w" 2>/dev/null && echo a3 > "$T/w/a" && $g -C "$T/w" commit -qam a3 && $g -C "$T/w" push -q origin HEAD:main 2>/dev/null && $g -C "$T/top/corpus" fetch -q origin
    printf '%s\n' '--- a/a' '+++ b/a' '@@ -1 +1 @@' '-a3' '+a4' > "$T/onorigin.patch"; printf '%s\n' '--- a/a' '+++ b/a' '@@ -1 +1 @@' '-a2' '+a5' > "$T/oncheckout.patch"
    echo dirt >> "$T/top/corpus/a"
    o="$(run bash "$me" give corpus "$T/onorigin.patch" "cut on origin while the checkout stands behind" --proof true 2>&1)"; rc=$?
    gf="$(ls -t "$T/gives"/*.patch 2>/dev/null | head -1)"
    [ "$rc" = 0 ] && [ -n "$gf" ] && [ "$(run bash "$me" base "$gf" 2>/dev/null)" = "$($g --git-dir="$T/origin.git" rev-parse main)" ] || why="$why arm 7: a patch cut on origin was not taken with origin's commit as its base while the checkout stood behind and dirty (rc $rc: $(printf '%s' "$o" | tail -1 | cut -c1-120));"
    sleep 1
    o="$(run bash "$me" give corpus "$T/oncheckout.patch" "cut on the stalled checkout" --proof true 2>&1)"; rc=$?
    gf="$(ls -t "$T/gives"/*.patch 2>/dev/null | head -1)"
    [ "$rc" = 0 ] && [ -n "$gf" ] && [ "$(run bash "$me" base "$gf" 2>/dev/null)" = "$(git -C "$T/top/corpus" rev-parse HEAD)" ] || why="$why arm 7: a patch cut on the stalled checkout's commit was not taken with that commit as its base (rc $rc);"
    o="$(run bash "$me" give corpus "$T/bad.patch" "applies nowhere" --proof true 2>&1)"; rc=$?
    [ "$rc" = 1 ] || why="$why arm 7: a patch that applies to neither commit was not refused rc 1 (rc $rc);"
    [ "$(git -C "$T/top/corpus" status --porcelain | tr -d ' \n')" = "Ma" ] || why="$why arm 7: the patch's checks changed the checkout's index or files;"
    # ARMS 8 TO 10, THE DRAIN (the cio 2026-11-16): a patches worktree of the scratch origin and a stand-in lander that runs the gate on the worktree and pushes on rc 0, as s4e_land.sh does
    rm -f "$T/gives"/*.patch; git -C "$T/top/corpus" checkout -q -- a 2>/dev/null; mkdir -p "$T/wt" && $g clone -q "$T/origin.git" "$T/wt/corpus" 2>/dev/null && git -C "$T/wt/corpus" config user.name probe && git -C "$T/wt/corpus" config user.email probe@localhost
    printf '%s\n' '#!/bin/bash' 'home="$2"; gate="$4"; r="$5"' 'if ( cd "$home" && S4E_HOME="$home" S4E_CORPUS="$home/corpus" bash -c "$gate" ); then git -C "$home/$r" push -q origin HEAD:main 2>/dev/null && echo "LAND ok pushed=$r:$(git -C "$home/$r" rev-parse --short HEAD)"; elif [ $? = 2 ]; then echo "LAND REFUSE(2) the gate could not measure (rc 2): nothing pushed"; exit 2; else echo "LAND RED stage=gate rc=1"; exit 1; fi' > "$T/lander.sh"
    printf '%s\n' '#!/bin/bash' 'echo "$S4E_SEAT $*" >> "$(dirname "$0")/told"; cat >> "$(dirname "$0")/told"' > "$T/msg.sh"
    dr() { SEATAS="${SEATAS:-grader}" run env S4E_GIVES_WT="$T/wt" S4E_TAKE_LANDER="$T/lander.sh" S4E_TAKE_MSG="$T/msg.sh" bash "$me" drain "$@"; }
    $g -C "$T/top/corpus" fetch -q origin; printf 'n1\n' > "$T/n1"; printf 'n2\n' > "$T/n2"; printf 'n3\n' > "$T/n3"
    mk() { ( cd "$T" && diff -u --label /dev/null --label "b/$1" /dev/null "$1" ) > "$T/$1.patch"; }
    mk n1; mk n2; mk n3
    o="$(run bash "$me" give corpus "$T/n1.patch" "adds n1, proved on the patched tree" --proof 'grep -q n1 "$S4E_CORPUS/n1"' 2>&1)" || why="$why arm 8: give with a proof was refused;"; sleep 1
    o="$(run bash "$me" give corpus "$T/n2.patch" "adds n2, its proof reads red" --proof 'grep -q nothing-of-the-kind "$S4E_CORPUS/n2"' 2>&1)" || why="$why arm 8: give with a proof was refused;"; sleep 1
    o="$(run bash "$me" give corpus "$T/n3.patch" "FIRSTLY adds n3" --proof 'test -f "$S4E_CORPUS/n3"' 2>&1)" || why="$why arm 8: give with a proof was refused;"
    printf '%s' "$o" | grep -q 's4e_take.sh drain' || why="$why arm 8: the WAKE line of a give does not name the drain;"
    grep -q "$(printf 'base=[0-9a-f]*\tproof=grep -q n1')" "$T/gives/GIVES.tsv" || why="$why arm 8: the proof command is not the patch's sixth column;"
    o="$(SEATAS=x dr 2>&1)"; rc=$?
    [ "$rc" = 2 ] && [ "$(ls "$T/gives"/*.patch | wc -l)" = 3 ] || why="$why arm 9: a drain by a seat that is not the grader was not refused rc 2, or it moved a patch (rc $rc);"
    ( exec 9> "$T/gives/.drain.lock"; flock -n 9; : > "$T/held"; while [ -e "$T/held" ]; do sleep 0.1; done ) &   # the lock is held until the probe lets go: an order of events, never a sleep (MEASURED 2026-11-16 at load 45: a one-second sleep read arm 14 red once)
    until [ -e "$T/held" ]; do sleep 0.1; done; o="$(dr 2>&1)"; rc=$?; rm -f "$T/held"; wait
    [ "$rc" = 0 ] && printf '%s' "$o" | grep -q 'already running' && [ "$(ls "$T/gives"/*.patch | wc -l)" = 3 ] || why="$why arm 9: a second drain did not stand aside rc 0 while the first held the lock (rc $rc);"
    printf '%s\n' '# what goes first' 'FIRSTLY' > "$T/gives/FIRST.conf"
    o="$(dr 2>&1)"; rc=$?
    [ "$rc" = 1 ] && [ "$($g --git-dir="$T/origin.git" show main:n1 2>/dev/null)" = n1 ] && [ "$($g --git-dir="$T/origin.git" show main:n3 2>/dev/null)" = n3 ] && ! $g --git-dir="$T/origin.git" cat-file -e main:n2 2>/dev/null \
        && [ "$(ls "$T/gives/done" | grep -c -e '-x-corpus-')" -ge 2 ] && [ "$(ls "$T/gives/refused"/*.patch 2>/dev/null | wc -l)" = 1 ] && [ -z "$(ls "$T/gives"/*.patch 2>/dev/null)" ] \
        && printf '%s' "$o" | grep -q '^TELL x: ' && printf '%s' "$o" | grep -q 'landed=2 refused=1 held=0' \
        || why="$why arm 10: the drain did not land the two patches whose proofs pass, refuse the one whose proof reads red with a TELL line, and leave origin without it (rc $rc: $(printf '%s' "$o" | tail -1 | cut -c1-160));"
    [ "$(cut -f1,8 "$T/gives/DRAIN.tsv" 2>/dev/null | sed -n 1p | grep -c "$(printf 'ok')")" = 1 ] && sed -n 1p "$T/gives/DRAIN.tsv" | grep -q -f <(ls "$T/gives/done" | tail -1) \
        && [ "$(cut -f8 "$T/gives/DRAIN.tsv" | tr '\n' ' ')" = "ok ok red:gate " ] || why="$why arm 10: DRAIN.tsv does not show the FIRST.conf patch landed first, then the oldest, then the red one ($(cut -f1,8 "$T/gives/DRAIN.tsv" 2>/dev/null | tr '\n\t' ' ='));"
    [ "$(git -C "$T/wt/corpus" rev-parse HEAD)" = "$($g --git-dir="$T/origin.git" rev-parse main)" ] && [ -z "$(git -C "$T/wt/corpus" status --porcelain)" ] || why="$why arm 10: the patches worktree does not stand clean at origin/main after a refused patch;"
    printf '%s\tx\tcorpus\tan old give with no proof\tbase=%s\n' old-noproof.patch "$($g --git-dir="$T/origin.git" rev-parse main)" >> "$T/gives/GIVES.tsv"; cp "$T/n2.patch" "$T/gives/old-noproof.patch"
    o="$(dr 2>&1)"; rc=$?
    [ "$rc" = 0 ] && printf '%s' "$o" | grep -q '^NEEDS-GATE old-noproof.patch' && [ -f "$T/gives/old-noproof.patch" ] && printf '%s' "$o" | grep -q 'needs_gate=1 waiting=1' || why="$why arm 10: a patch given with no proof was not named NEEDS-GATE and left waiting (rc $rc);"
    rm -f "$T/gives/old-noproof.patch"; printf 'n4\n' > "$T/n4"; printf 'n5\n' > "$T/n5"; mk n4; mk n5; $g -C "$T/top/corpus" fetch -q origin
    run bash "$me" give corpus "$T/n4.patch" "adds n4, its proof a path from the repo's top" --proof 'grep -q n4 n4' > /dev/null 2>&1; sleep 1
    run bash "$me" give corpus "$T/n5.patch" "adds n5, its proof cannot run" --proof 'exit 2' > /dev/null 2>&1
    o="$(dr 2>&1)"; rc=$?
    [ "$rc" = 1 ] && [ "$($g --git-dir="$T/origin.git" show main:n4 2>/dev/null)" = n4 ] && printf '%s' "$o" | grep -q '^HELD .*-x-corpus-' && [ "$(ls "$T/gives"/*.patch 2>/dev/null | wc -l)" = 1 ] || why="$why arm 11: a proof written from the repo's top did not land its patch, or a proof that could not measure was not held once (rc $rc: $(printf '%s' "$o" | tail -1 | cut -c1-160));"
    o="$(dr 2>&1)"; rc=$?
    [ "$rc" = 1 ] && [ -z "$(ls "$T/gives"/*.patch 2>/dev/null)" ] && [ "$(ls "$T/gives/refused"/*.patch | wc -l)" = 2 ] && printf '%s' "$o" | grep -q '^TELL x: .*could not run or measure' && ! $g --git-dir="$T/origin.git" cat-file -e main:n5 2>/dev/null || why="$why arm 12: a patch whose proof could not measure a second time was not returned to its giver (rc $rc);"
    grep -q '^grader send x your-patch-.*-came-back-from-the-graders-drain --stdin' "$T/told" 2>/dev/null && grep -q 'read red on its own proof' "$T/told" && grep -q 'LAND RED stage=gate' "$T/told" || why="$why arm 13: the drain did not send the giver of a red patch a telegram as the grader, with the line and the landing's last lines;"
    printf 'n6\n' > "$T/n6"; mk n6; $g -C "$T/top/corpus" fetch -q origin
    ( exec 9> "$T/gives/.drain.lock"; flock -n 9; : > "$T/held"; while [ -e "$T/held" ]; do sleep 0.1; done ) &
    until [ -e "$T/held" ]; do sleep 0.1; done; o="$(run bash "$me" give corpus "$T/n6.patch" "adds n6 while a drain runs" --proof 'test -f n6' 2>&1)"; rc=$?; rm -f "$T/held"; wait
    [ "$rc" = 0 ] && printf '%s' "$o" | grep -q '^NO WAKE IS OWED' && ! printf '%s' "$o" | grep -q '^WAKE:' || why="$why arm 14: a give while a drain runs still asks for a wake of the grader (rc $rc);"
    mkdir -p "$T/w/packages/p" && $g -C "$T/w" pull -q origin main 2>/dev/null; printf 'rank,entry\n1,ea\n2,eb\n' > "$T/w/packages/p/ALL.csv" && $g -C "$T/w" add packages && $g -C "$T/w" commit -qm table && $g -C "$T/w" push -q origin HEAD:main 2>/dev/null && $g -C "$T/top/corpus" fetch -q origin
    ( cd "$T" && printf '%s\n' '--- a/n1' '+++ /dev/null' '@@ -1 +0,0 @@' '-n1' > del.patch; printf '%s\n' '--- a/packages/p/ALL.csv' '+++ b/packages/p/ALL.csv' '@@ -1,3 +1,2 @@' ' rank,entry' ' 1,ea' '-2,eb' > drop.patch )
    o="$(run bash "$me" give corpus "$T/del.patch" "deletes n1 and does not say so" --proof true 2>&1)"; rc=$?; n0="$(ls "$T/gives"/*.patch 2>/dev/null | wc -l)"
    [ "$rc" = 1 ] && printf '%s' "$o" | grep -q 'DELETES 1 file' || why="$why arm 15: a patch that deletes a file was taken with no --deletes (rc $rc);"
    o="$(run bash "$me" give corpus "$T/drop.patch" "drops the row eb and does not say so" --proof true 2>&1)"; rc=$?
    [ "$rc" = 1 ] && printf '%s' "$o" | grep -q 'DROPS 1 table row' && [ "$(ls "$T/gives"/*.patch 2>/dev/null | wc -l)" = "$n0" ] || why="$why arm 15: a patch that drops a row of an ALL.csv was taken with no --drops (rc $rc);"
    o="$(run bash "$me" give corpus "$T/del.patch" "deletes n1 and says so" --proof true --deletes 1 2>&1)"; rc=$?; sleep 1
    [ "$rc" = 0 ] || why="$why arm 16: a patch that states its one deletion was refused (rc $rc: $(printf '%s' "$o" | tail -1 | cut -c1-120));"
    o="$(run bash "$me" give corpus "$T/drop.patch" "drops the row eb and says so" --proof true --drops 1 2>&1)"; rc=$?
    [ "$rc" = 0 ] || why="$why arm 16: a patch that states its one dropped row was refused (rc $rc: $(printf '%s' "$o" | tail -1 | cut -c1-120));"
    printf '%s\n' '--- a/a' '+++ b/a' '@@ -1 +1 @@' '-a3' '+a2' > "$T/back.patch"
    o="$(run bash "$me" give corpus "$T/back.patch" "puts a back to its older text and does not say so" --proof true 2>&1)"; rc=$?
    [ "$rc" = 1 ] && printf '%s' "$o" | grep -q 'PUTS BACK 1 file' || why="$why arm 17: a patch that puts a file back to an older text was taken with no --reverts (rc $rc: $(printf '%s' "$o" | tail -1 | cut -c1-120));"
    o="$(run bash "$me" give corpus "$T/back.patch" "puts a back to its older text and says so" --proof true --reverts 1 2>&1)"; rc=$?
    [ "$rc" = 0 ] || why="$why arm 17: a patch that states its one revert was refused (rc $rc: $(printf '%s' "$o" | tail -1 | cut -c1-120));"
    $g -C "$T/w" pull -q origin main 2>/dev/null; printf 'one\n' > "$T/w/packages/p/ea.out" && $g -C "$T/w" add packages && $g -C "$T/w" commit -qm ea && $g -C "$T/w" push -q origin HEAD:main 2>/dev/null && $g -C "$T/top/corpus" fetch -q origin
    ( cd "$T" && printf '%s\n' '--- a/packages/p/ea.out' '+++ b/packages/p/ea.out' '@@ -1 +1 @@' '-one' '+two' > chg.patch; printf '%s\n' '--- a/packages/p/ALL.csv' '+++ b/packages/p/ALL.csv' '@@ -1,3 +1,4 @@' ' rank,entry' ' 1,ea' '-2,eb' '+2,ec' '+3,eb' > ins.patch )
    o="$(run bash "$me" give corpus "$T/chg.patch" "changes the answer of ea, an entry it does not add, and does not say so" --proof true 2>&1)"; rc=$?
    [ "$rc" = 1 ] && printf '%s' "$o" | grep -q 'CHANGES 1 file' || why="$why arm 18: a patch that changes an existing entry's answer was taken with no --changes (rc $rc: $(printf '%s' "$o" | tail -1 | cut -c1-120));"
    o="$(run bash "$me" give corpus "$T/chg.patch" "changes the answer of ea and says so" --proof true --changes 1 2>&1)"; rc=$?; sleep 1
    [ "$rc" = 0 ] || why="$why arm 18: a patch that states its one change was refused (rc $rc);"
    o="$(run bash "$me" give corpus "$T/ins.patch" "adds the entry ec above eb, whose rank is counted again" --proof true 2>&1)"; rc=$?
    [ "$rc" = 0 ] || why="$why arm 19: a patch that only adds a row, the ranks below it counted again, was refused (rc $rc: $(printf '%s' "$o" | tail -1 | cut -c1-160));"
    if [ -z "$why" ]; then rm -rf "$T"; echo "TAKE probe ok arms=19 (a patch that changes a file or a row of an entry it does not add says so; a new row whose insertion counts the ranks again is no change; a patch that puts a file back to an older text says so too; a patch that deletes a file or drops a table row says so in numbers or is refused; a patch that deletes a file or drops a table row says so in numbers or is refused; the drain itself telegrams the giver of a patch that comes back; a give while a drain runs owes no wake; a proof runs in the patched repo's top; one that cannot measure is held once and returned the second time; a give carries its proof as a command and one with none is refused; the drain is the grader's alone, one at a time; it lands every waiting patch whose proof reads rc 0 on the patched tree, FIRST.conf's first, refuses the one whose proof reads red and names its giver, leaves the worktree at origin/main and a patch with no proof to the grader's hand; take refuses every seat and makes nothing; give stores a patch that applies with its seat and why and refuses one that does not; apply is the grader's alone; the grader's apply lands the patch on origin and the one checkout holds it; check reads red while a seat root holds one of the three; drop refuses unlanded work and removes a clean folder; a patch is checked against origin first and then the checkout's commit, through a private index)"; return 0; fi
    echo "TAKE probe RED:$why"; echo "    kept: $T"; return 1
}
probe_lanes() {   # THE LANES AND THE OWN-DIRECTORY REGATE (row harness-the-graders-drain-lands-in-lanes-and-regates-a-patch-only-for-its-own-directories), on scratch origins and a
    # scratch patches folder; every reading an order of events in one file, never a wall-clock bound. (a) two givers' patches, lanes=2: the second's proof starts before the
    # first's ends. (b) the REAL lander, lanes=2: two patches adding a row each to one package's ALL.csv, cut on one base, both land and origin's table holds both rows.
    # (c) the real lander: a patch overtaken during its gate by a mover under the scratch SCRIP's src/runtime runs its proof once; one overtaken by a mover in its own
    # directory runs it twice. (d) lanes=2, two patches of one giver to one repo: the second starts after the first ends. (e) no lanes line: two givers' patches run one
    # after the other in lane 1. Then --probe, whose arms read the one-lane drain, stays green.
    local T why="" o rc g="git -c user.name=probe -c user.email=probe@localhost -c init.defaultBranch=main" me="$HERE/s4e_take.sh" ev e1 e2 n
    T="$(mktemp -d "/tmp/s4e/${S4E_SEAT:-seat}/take-lanes.XXXXXX" 2>/dev/null || mktemp -d)" || die "REFUSE(2): no scratch" 2
    mkdir -p "$T/top/claude_x" "$T/po" "$T/gives" || die "REFUSE(2): no scratch" 2
    bare() {   # <name>: a bare scratch origin with one commit holding the files of $T/seed.<name>
        $g init -q --bare "$T/$1.git" && $g clone -q "$T/$1.git" "$T/s.$1" 2>/dev/null && cp -r "$T/seed.$1/." "$T/s.$1/" && $g -C "$T/s.$1" add -A && $g -C "$T/s.$1" commit -qm "seed $1" && $g -C "$T/s.$1" push -q origin HEAD:main 2>/dev/null; }
    clone() { $g clone -q "$T/$1.git" "$2" 2>/dev/null && git -C "$2" config user.name probe && git -C "$2" config user.email probe@localhost; }
    mkdir -p "$T/seed.corpus/packages/probe_pkg" "$T/seed.SCRIP/src/runtime"
    printf 'rank,entry,path\n1,ea,ea.icn\n' > "$T/seed.corpus/packages/probe_pkg/ALL.csv"; echo seed > "$T/seed.corpus/readme"
    printf 'all:\n\t@:\n' > "$T/seed.SCRIP/Makefile"; echo seed > "$T/seed.SCRIP/src/runtime/rt.c"
    bare corpus && bare SCRIP && clone corpus "$T/top/corpus" && $g -C "$T/top/corpus" fetch -q origin || { rm -rf "$T"; die "REFUSE(2): cannot plant the scratch origins" 2; }
    for n in wt wt2; do clone corpus "$T/$n/corpus" || { rm -rf "$T"; die "REFUSE(2): cannot plant the stub lanes" 2; }; done
    for n in rwt rwt2; do clone corpus "$T/$n/corpus" && clone SCRIP "$T/$n/SCRIP" || { rm -rf "$T"; die "REFUSE(2): cannot plant the real lanes" 2; }; done
    printf 'touches=derived\ntables=affected\nlease=none\ntries=1\n' > "$T/po/LAND.conf"; printf 'TENET\n' > "$T/po/MODE"
    printf '%s\n' '#!/bin/bash' 'home="$2"; gate="$4"; r="$5"' 'if ( cd "$home" && S4E_HOME="$home" S4E_CORPUS="$home/corpus" bash -c "$gate" ); then i=0; until git -C "$home/$r" push -q origin HEAD:main 2>/dev/null; do i=$((i+1)); [ "$i" -lt 6 ] || { echo "LAND RED stage=push"; exit 1; }; git -C "$home/$r" pull -q --rebase origin main 2>/dev/null; done; echo "LAND ok pushed=$r:$(git -C "$home/$r" rev-parse --short HEAD)"; elif [ $? = 2 ]; then echo "LAND REFUSE(2) the gate could not measure (rc 2): nothing pushed"; exit 2; else echo "LAND RED stage=gate rc=1"; exit 1; fi' > "$T/lander.sh"
    printf '%s\n' '#!/bin/bash' 'cat > /dev/null' > "$T/msg.sh"
    # a proof: <name> <other> <bound>: it writes "start NAME", waits (at most BOUND tenths of a second) for "start OTHER", writes "end NAME"; it counts its runs in runs.NAME
    printf '%s\n' '#!/bin/bash' 'ev="$1"; me="$2"; other="$3"; bound="$4"; echo r >> "$ev.runs.$me"; echo "start $me" >> "$ev"; i=0' \
        'while ! grep -qx "start $other" "$ev" 2>/dev/null && [ "$i" -lt "$bound" ]; do sleep 0.1; i=$((i+1)); done' '[ -n "${5:-}" ] && [ "$(wc -l < "$ev.runs.$me")" = 1 ] && bash "$5"' 'echo "end $me" >> "$ev"; exit 0' > "$T/proof.sh"
    mk() { mkdir -p "$(dirname "$T/p/$1")"; printf '%s\n' "$2" > "$T/p/$1"; ( cd "$T/p" && diff -u --label /dev/null --label "b/$1" /dev/null "$1" ) > "$T/$3.patch"; rm -f "$T/p/$1"; }
    give_as() { $un_env S4E_ONE_DISK_TOP="$T/top" S4E_GIVES="$T/gives" S4E_HOME="$T/top/claude_x" S4E_SEAT="$1" bash "$me" give corpus "$T/$2.patch" "probe lanes: $2" --proof "$3" > "$T/give.$2.log" 2>&1 || why="$why give of $2 refused ($(tail -1 "$T/give.$2.log" | cut -c1-120));"; sleep 1; }
    un_env="env -u S4E_SCRIP -u S4E_CORPUS -u S4E_GITHUB -u S4E_LAND_SELF"
    dr() {   # <worktree> <lander>: one drain as the grader
        $un_env S4E_ONE_DISK_TOP="$T/top" S4E_GIVES="$T/gives" S4E_HOME="$T/top/claude_x" S4E_SEAT=grader S4E_GIVES_WT="$1" S4E_TAKE_LANDER="$2" S4E_TAKE_MSG="$T/msg.sh" \
            S4E_POSTOFFICE="$T/po" S4E_POST="$T/po" S4E_LAND_UNADMITTED=1 S4E_HOME_TREES_TOP="$T/none" S4E_HARNESS="$(cd "$HERE/.." && pwd)" bash "$me" drain; }
    order() { grep -n -x "$2" "$1" 2>/dev/null | head -1 | cut -d: -f1; }   # the line number of an event, empty if it never happened
    # (e) FIRST, no lanes line: one lane
    ev="$T/ev.e"; mk e/one one e1; mk e/two two e2
    give_as ga e1 "bash $T/proof.sh $ev e1 e2 30"; give_as gb e2 "bash $T/proof.sh $ev e2 e1 0"
    o="$(dr "$T/wt" "$T/lander.sh" 2>&1)"; rc=$?
    e1="$(order "$ev" "end e1")"; e2="$(order "$ev" "start e2")"
    [ "$rc" = 0 ] && [ -n "$e1" ] && [ -n "$e2" ] && [ "$e1" -lt "$e2" ] && [ "$(cut -f9 "$T/gives/DRAIN.tsv" | sort -u | tr '\n' ' ')" = "1 " ] && ! printf '%s' "$o" | grep -q '^DRAIN lanes=' \
        || why="$why arm e: with no lanes line the drain did not run its two patches one after the other in lane 1 (rc $rc; events $(tr '\n' ',' < "$ev" 2>/dev/null); lanes $(cut -f9 "$T/gives/DRAIN.tsv" | tr '\n' ' '));"
    # (d) lanes=2, one giver, one repo: in the order given, the second after the first ends
    printf 'lanes=2\n' > "$T/gives/DRAIN.conf"
    ev="$T/ev.d"; mk d/one one d1; mk d/two two d2
    give_as gx d1 "bash $T/proof.sh $ev d1 d2 30"; give_as gx d2 "bash $T/proof.sh $ev d2 d1 0"
    o="$(dr "$T/wt" "$T/lander.sh" 2>&1)"; rc=$?
    e1="$(order "$ev" "end d1")"; e2="$(order "$ev" "start d2")"
    [ "$rc" = 0 ] && [ -n "$e1" ] && [ -n "$e2" ] && [ "$e1" -lt "$e2" ] && printf '%s' "$o" | grep -q 'waits for .*an older patch of its giver' \
        || why="$why arm d: two patches of one giver to one repo did not land in the order given, the second after the first's end (rc $rc; events $(tr '\n' ',' < "$ev" 2>/dev/null));"
    # (a) lanes=2, two givers: the second starts before the first ends
    ev="$T/ev.a"; mk a/one one a1; mk a/two two a2
    give_as ga a1 "bash $T/proof.sh $ev a1 a2 600"; give_as gb a2 "bash $T/proof.sh $ev a2 a1 600"
    o="$(dr "$T/wt" "$T/lander.sh" 2>&1)"; rc=$?
    e1="$(order "$ev" "end a1")"; e2="$(order "$ev" "start a2")"
    [ "$rc" = 0 ] && [ -n "$e1" ] && [ -n "$e2" ] && [ "$e2" -lt "$e1" ] && [ "$($g --git-dir="$T/corpus.git" show main:a/one 2>/dev/null)" = one ] && [ "$($g --git-dir="$T/corpus.git" show main:a/two 2>/dev/null)" = two ] \
        && [ "$(tail -2 "$T/gives/DRAIN.tsv" | cut -f9 | sort | tr '\n' ' ')" = "1 2 " ] \
        || why="$why arm a: two givers' patches did not run at once in two lanes, the second's start before the first's end, and both land (rc $rc; events $(tr '\n' ',' < "$ev" 2>/dev/null); lanes $(tail -2 "$T/gives/DRAIN.tsv" | cut -f9 | tr '\n' ' '));"
    # (b) the real lander, lanes=2: two rows added to one ALL.csv on one base both land
    $g -C "$T/top/corpus" pull -q origin main 2>/dev/null
    ev="$T/ev.b"
    for n in b1 b2; do cp "$T/top/corpus/packages/probe_pkg/ALL.csv" "$T/all.$n"; printf '2,e%s,e%s.icn\n' "$n" "$n" >> "$T/all.$n"
        diff -u --label a/packages/probe_pkg/ALL.csv --label b/packages/probe_pkg/ALL.csv "$T/top/corpus/packages/probe_pkg/ALL.csv" "$T/all.$n" > "$T/$n.patch"; done
    give_as gc b1 "bash $T/proof.sh $ev b1 b2 600"; give_as gd b2 "bash $T/proof.sh $ev b2 b1 600"
    o="$(dr "$T/rwt" "$HERE/s4e_land.sh" 2>&1)"; rc=$?
    e1="$(order "$ev" "end b1")"; e2="$(order "$ev" "start b2")"
    n="$($g --git-dir="$T/corpus.git" show main:packages/probe_pkg/ALL.csv 2>/dev/null | tr '\n' ' ')"
    case "$n" in "rank,entry,path 1,ea,ea.icn 2,eb1,eb1.icn 3,eb2,eb2.icn "|"rank,entry,path 1,ea,ea.icn 2,eb2,eb2.icn 3,eb1,eb1.icn ") n="both rows: $n" ;; esac
    [ "$rc" = 0 ] && [ -n "$e1" ] && [ -n "$e2" ] && [ "$e2" -lt "$e1" ] && [ "${n#both rows: }" != "$n" ] \
        || why="$why arm b: two patches adding a row each to one ALL.csv in two lanes did not both land through the real lander (rc $rc; origin's table: $n; events $(tr '\n' ',' < "$ev" 2>/dev/null); $(printf '%s' "$o" | grep -E '^(REFUSED|HELD)' | head -2 | cut -c1-200));"
    # (c) the real lander, one lane: a mover under SCRIP's runtime during the gate costs no second run; a mover in the patch's own directory does
    rm -f "$T/gives/DRAIN.conf"; $g -C "$T/top/corpus" pull -q origin main 2>/dev/null
    clone SCRIP "$T/rs"; clone corpus "$T/rc"
    printf '#!/bin/bash\ncd "%s" && git pull -q --rebase origin main && echo m >> src/runtime/probe_mover.txt && git add -A && git commit -qm "probe: a mover under src/runtime" && git push -q origin HEAD:main\n' "$T/rs" > "$T/mover_rt.sh"
    printf '#!/bin/bash\ncd "%s" && git pull -q --rebase origin main && mkdir -p c && echo m >> c/mover.txt && git add -A && git commit -qm "probe: a mover in the patch'"'"'s own directory" && git push -q origin HEAD:main\n' "$T/rc" > "$T/mover_own.sh"
    ev="$T/ev.c"; mk c/one one c1; mk c/two two c2
    give_as ge c1 "bash $T/proof.sh $ev c1 none 0 $T/mover_rt.sh"; give_as gf c2 "bash $T/proof.sh $ev c2 none 0 $T/mover_own.sh"
    o="$(dr "$T/rwt" "$HERE/s4e_land.sh" 2>&1)"; rc=$?
    e1="$(wc -l < "$ev.runs.c1" 2>/dev/null)"; e2="$(wc -l < "$ev.runs.c2" 2>/dev/null)"
    [ "$rc" = 0 ] && [ "$e1" = 1 ] && [ "$e2" = 2 ] && [ "$($g --git-dir="$T/corpus.git" show main:c/one 2>/dev/null)" = one ] && [ "$($g --git-dir="$T/corpus.git" show main:c/two 2>/dev/null)" = two ] \
        && $g --git-dir="$T/SCRIP.git" cat-file -e main:src/runtime/probe_mover.txt 2>/dev/null \
        || why="$why arm c: the proof of a patch overtaken under SCRIP's runtime ran ${e1:-0} time(s) (want 1) and one overtaken in its own directory ${e2:-0} (want 2), or they did not land (rc $rc; $(printf '%s' "$o" | grep -E '^(REFUSED|HELD|LANDED)' | head -3 | cut -c1-160 | tr '\n' ' '));"
    if [ -z "$why" ]; then rm -rf "$T"; echo "TAKE lanes-probe ok arms=5 (e: with no lanes line the drain ran two givers' patches one after the other in lane 1; d: lanes=2 ran one giver's two patches to one repo in the order given, the second after the first ended; a: lanes=2 ran two givers' patches at once, the second started before the first ended, both landed; b: the real lander in two lanes landed two patches that each added a row to one ALL.csv, merged by entry key; c: the real lander ran the proof of a patch overtaken under SCRIP's runtime once and of one overtaken in its own directory twice)"; return 0; fi
    echo "TAKE lanes-probe RED:$why"; echo "    kept: $T"; return 1
}
case "${1:-}" in
    --probe) probe; exit $? ;;
    --probe-lanes) probe_lanes; exit $? ;;
    list) list ;;
    check) check; exit $? ;;
    give) shift; repo_ok "${1:-}" || die "usage: s4e_take.sh give corpus|harness|.github <patch> \"<why>\" --proof '<command>'" 2; give "$@" ;;
    drain) shift; drain "$@"; exit $? ;;
    apply) shift; apply "${1:-}" ;;
    base) shift; b="$(awk -F'\t' -v b="$(basename "${1:-}")" '$1==b {print $5}' "$GIVES/GIVES.tsv" 2>/dev/null | tail -1)"; b="${b#base=}"; [ -n "$b" ] || die "REFUSE(1): no base recorded for '${1:-}' in $GIVES/GIVES.tsv (a patch made before 2026-11-14 18:0x names none)" 1; echo "$b" ;;
    drop) shift; landed=0; [ "${1:-}" = --landed ] && { landed=1; shift; }; repo_ok "${1:-}" || die "usage: s4e_take.sh drop [--landed] corpus|harness|.github" 2; drop "$1" "$landed" ;;
    corpus|harness|.github) take "$1" ;;
    *) die "usage: s4e_take.sh give <repo> <patch> \"<why>\" --proof '<command>' | drain [--wait S] | apply <given patch> | check | list | drop <repo> | --probe   (repo: corpus|harness|.github; a bare repo name REFUSES: no seat holds one)" 2 ;;
esac
