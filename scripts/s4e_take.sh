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
#                                               one of that file's last twenty versions, as the 17 answers were): --reverts R. A patch that does none needs none.
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
give() {
    local r="$1" p="${2:-}" why="${3:-}" pf="${4:-}" proof="${5:-}" seat="${S4E_SEAT:-}" src err="" out base ob hb at ix say_del=0 say_drop=0 say_rev=0 ndel=0 ndrop=0 nrev=0 f nb dl="" dr="" rv=""
    shift 5 2>/dev/null || shift $#
    while [ $# -gt 0 ]; do case "$1" in --deletes) say_del="${2:-0}"; shift 2 ;; --drops) say_drop="${2:-0}"; shift 2 ;; --reverts) say_rev="${2:-0}"; shift 2 ;; *) die "REFUSE(2): unknown argument '$1' after the proof (--deletes N, --drops K, --reverts R)" 2 ;; esac; done
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
            case "$at:$f" in M:*ALL.csv|M:*ALL.args)
                at="$(comm -23 <(git -C "$src" show "$base:$f" 2>/dev/null | give_keys "$f" | sort -u) <(GIT_INDEX_FILE="$ix" git -C "$src" show ":$f" 2>/dev/null | give_keys "$f" | sort -u))"
                [ -z "$at" ] || { ndrop=$((ndrop + $(printf '%s\n' "$at" | wc -l))); dr="$dr $f:$(printf '%s' "$at" | head -3 | tr '\n' ',')"; } ;;
            esac
        done < <(GIT_INDEX_FILE="$ix" git -C "$src" diff-index --cached --name-status "$base" 2>/dev/null)
    fi
    rm -f "$ix"
    [ "$ndel" = "$say_del" ] && [ "$ndrop" = "$say_drop" ] && [ "$nrev" = "$say_rev" ] || die "REFUSE(1): the patch DELETES $ndel file(s)${dl:+ ($dl ...)}, DROPS $ndrop table row(s)${dr:+ ($dr)} and PUTS BACK $nrev file(s) to an older text${rv:+ ($rv ...)}, and you stated --deletes $say_del --drops $say_drop --reverts $say_rev. Nothing given. A patch cut as a whole-folder difference from a scratch copy older than the tree deletes what others landed since (MEASURED 2026-11-16: corpus 157acb344 deleted 40 files of ipl_gprogs and applied clean). Cut the patch again from the files YOU changed, each against /home/$r as it stands now; or, if you mean every one of them, state the numbers after the proof: --deletes $ndel --drops $ndrop --reverts $nrev." 1
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
drain_next() {   # sets NEXT to the next waiting patch that carries a proof and was not tried in this run: FIRST.conf's patches first, then the oldest
    local f b row key first="" rest=""
    for f in "$GIVES"/*.patch; do
        [ -s "$f" ] || continue; b="$(basename "$f")"
        case " $TRIED " in *" $b "*) continue ;; esac
        row="$(awk -F'\t' -v b="$b" '$1==b' "$GIVES/GIVES.tsv" 2>/dev/null | tail -1)"
        case "$(printf '%s' "$row" | cut -f6)" in proof=?*) ;; *) case " $NOGATE " in *" $b "*) ;; *) NOGATE="$NOGATE $b"; echo "NEEDS-GATE $b: given with no proof command; land it by grader_give.sh" >&2 ;; esac; continue ;; esac
        key="$(printf '%s' "$row" | cut -f2-4)"
        if [ -s "$GIVES/FIRST.conf" ] && printf '%s\n' "$key" | grep -q -E -f <(grep -v -e '^#' -e '^$' "$GIVES/FIRST.conf") 2>/dev/null; then [ -n "$first" ] || first="$f"; else [ -n "$rest" ] || rest="$f"; fi
    done
    NEXT="${first:-$rest}"
}
drain_one() {   # <given patch>: one landing; rc 0 landed, 1 red (the patch is the giver's again), 2 could not measure (the patch waits)
    local g="$1" b row giver r why base proof d log t0 t1 out given
    b="$(basename "$g")"; row="$(awk -F'\t' -v b="$b" '$1==b' "$GIVES/GIVES.tsv" | tail -1)"
    giver="$(printf '%s' "$row" | cut -f2)"; r="$(printf '%s' "$row" | cut -f3)"; why="$(printf '%s' "$row" | cut -f4)"; base="$(printf '%s' "$row" | cut -f5)"; base="${base#base=}"; proof="$(printf '%s' "$row" | cut -f6)"; proof="${proof#proof=}"
    given="${b%%-*}"; t0="$(date -u +%s)"; out=held; d="$WT/$r"; mkdir -p "$GIVES/logs" "$GIVES/done" "$GIVES/refused"; log="$GIVES/logs/land_${b%.patch}.log"
    fin() { t1="$(date -u +%s)"; printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$b" "$giver" "$r" "$given" "$(date -u -d "@$t0" +%Y%m%dT%H%M%SZ)" "$(date -u -d "@$t1" +%Y%m%dT%H%M%SZ)" "$((t1 - t0))" "$out" >> "$GIVES/DRAIN.tsv"; }
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
    ( cd "${S4E_HOME:-$WT}" && S4E_SEAT=grader bash "$LANDER" --home "$WT" --gate "cd \"$d\" && ( $proof )" "$r" > "$log" 2>&1 )
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
drain() {
    local seat="${S4E_SEAT:-}" wait_s=0 waited=0 g rc n_ok=0 n_red=0 n_held=0 last=0 now sd
    [ "$seat" = grader ] || die "REFUSE(2): only the grader drains the patches (this seat is '${seat:-unset}'); nothing landed. A seat gives: s4e_take.sh give <repo> <patch> \"<why>\" --proof '<command>'." 2
    [ "${1:-}" = --wait ] && wait_s="${2:-0}"; case "$wait_s" in ''|*[!0-9]*) die "usage: s4e_take.sh drain [--wait SECONDS]" 2 ;; esac
    WT="${S4E_GIVES_WT:-/home/resources/worktrees/grader/wt-gives}"; LANDER="${S4E_TAKE_LANDER:-$HERE/s4e_land.sh}"; MSG="${S4E_TAKE_MSG:-$HERE/s4e_msg.sh}"; TRIED=""; NOGATE=""; NEXT=""
    [ -d "$WT" ] || die "REFUSE(2): no patches worktree at $WT (S4E_GIVES_WT names another)" 2
    mkdir -p "$GIVES" && exec 9> "$GIVES/.drain.lock" || die "REFUSE(2): cannot open $GIVES/.drain.lock" 2
    flock -n 9 || { echo "DRAIN is already running (lock $GIVES/.drain.lock): it lands every waiting patch that carries a proof, this one too"; return 0; }
    while :; do
        drain_next; g="$NEXT"
        if [ -z "$g" ]; then [ "$waited" -lt "$wait_s" ] || break; sleep 5; waited=$((waited + 5)); continue; fi
        waited=0; now="$(date -u +%s)"; sd="$WT/SCRIP"
        if [ -e "$sd/.git" ] && [ $((now - last)) -ge 120 ]; then   # the proofs' SCRIP stands at origin/main, built: read at most every two minutes
            last="$now"; git -C "$sd" fetch -q origin 2>/dev/null
            [ "$(git -C "$sd" rev-parse HEAD 2>/dev/null)" = "$(git -C "$sd" rev-parse origin/main 2>/dev/null)" ] || { git -C "$sd" checkout -q --detach origin/main 2>/dev/null && make -C "$sd" -j8 > "$GIVES/logs/scrip_build.log" 2>&1 || echo "DRAIN: the patches worktree's SCRIP did not build at origin/main (log $GIVES/logs/scrip_build.log); proofs that run SCRIP will read red"; }
        fi
        TRIED="$TRIED $(basename "$g")"; drain_one "$g" 9>&-; rc=$?
        case "$rc" in 0) n_ok=$((n_ok + 1)) ;; 1) n_red=$((n_red + 1)) ;; *) n_held=$((n_held + 1)) ;; esac
    done
    echo "DRAIN done: landed=$n_ok refused=$n_red held=$n_held needs_gate=$(printf '%s' "$NOGATE" | wc -w) waiting=$(ls "$GIVES"/*.patch 2>/dev/null | wc -l) (ledger $GIVES/DRAIN.tsv)"
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
    ( exec 9> "$T/gives/.drain.lock"; flock -n 9; sleep 3 ) & 
    sleep 1; o="$(dr 2>&1)"; rc=$?; wait
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
    ( exec 9> "$T/gives/.drain.lock"; flock -n 9; sleep 3 ) &
    sleep 1; o="$(run bash "$me" give corpus "$T/n6.patch" "adds n6 while a drain runs" --proof 'test -f n6' 2>&1)"; rc=$?; wait
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
    if [ -z "$why" ]; then rm -rf "$T"; echo "TAKE probe ok arms=17 (a patch that puts a file back to an older text says so too; a patch that deletes a file or drops a table row says so in numbers or is refused; a patch that deletes a file or drops a table row says so in numbers or is refused; the drain itself telegrams the giver of a patch that comes back; a give while a drain runs owes no wake; a proof runs in the patched repo's top; one that cannot measure is held once and returned the second time; a give carries its proof as a command and one with none is refused; the drain is the grader's alone, one at a time; it lands every waiting patch whose proof reads rc 0 on the patched tree, FIRST.conf's first, refuses the one whose proof reads red and names its giver, leaves the worktree at origin/main and a patch with no proof to the grader's hand; take refuses every seat and makes nothing; give stores a patch that applies with its seat and why and refuses one that does not; apply is the grader's alone; the grader's apply lands the patch on origin and the one checkout holds it; check reads red while a seat root holds one of the three; drop refuses unlanded work and removes a clean folder; a patch is checked against origin first and then the checkout's commit, through a private index)"; return 0; fi
    echo "TAKE probe RED:$why"; echo "    kept: $T"; return 1
}
case "${1:-}" in
    --probe) probe; exit $? ;;
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
