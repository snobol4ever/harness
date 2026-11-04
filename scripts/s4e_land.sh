#!/usr/bin/env bash
# s4e_land.sh -- ONE LANDING COMMAND: fetch, rebase, regenerate every generated table, rebuild, re-derive the tables read from the binary, run the
# row's gate, push SCRIP and verify it on origin, then harness, then corpus, then .github last (DESIGN-PLAN box-scheduler step 18, the cao
# 2026-11-04, CTO-496; the design text in the shared-box skill's DESIGN section 8; Lon 2026-11-04, verbatim: "There has been talk, and only talk,
# about using industry recognized ways of doing make and build load balancing and management." / "So get to it.").
# THE MECHANISM is the merge queue's (a landing is tested on the tree it will become, and pushed only if that tree is green), run by the lander:
#   preflight   every repo present is a git repo with no tracked change and no rebase in progress; the gate is named; one landing per root (flock)
#   fetch       git fetch origin main in SCRIP, harness, corpus and .github (each under timeout)
#   rebase      a repo with commits rebases onto origin/main, a repo without fast-forwards to it; a conflict aborts the rebase and reads RED
#   regenerate  every source-phase generator of generated_tables.tsv is checked (through util_check_cache.sh) and a stale one is rewritten,
#               re-checked and committed in its own repo as a separate commit; a generator that writes outside its declared outputs reads RED
#   build       make -j8 in SCRIP (the Makefile joins the box-wide jobserver and fetches the build cache's entry for a clean tree)
#   derive      every binary-phase table is re-derived from the built runtime and every built-phase table checked; a stale one is rewritten,
#               the source tables regenerated again, committed, and SCRIP rebuilt
#   gate        the row's DONE-WHEN (--row TOPIC) or --gate CMD, run from the root with S4E_HOME set; rc 0 lands, rc 1 RED, rc 2 refuses
#   push:<repo> git push origin HEAD:main, then git ls-remote must name the local HEAD; SCRIP, harness, corpus, .github in that order. A push
#               the origin refused (it moved after the rebase) is recorded by s4e_push_rejected.sh and the landing goes round again from fetch
#               (--tries, default 3), so the gate always reads the tree that is pushed
# USAGE: s4e_land.sh [--home DIR] (--row TOPIC | --gate CMD) [--gate-timeout S] [--tries N] [REPO...]
#   --home DIR   the root holding SCRIP harness corpus [.github] (default: the root this script sits in); a clean worktree layout
#                outside the root is the usual DIR. REPO names the repos whose commits land (default: every repo ahead of origin);
#                a repo that carries commits and is not named refuses, since its tree is what the gate reads.
#   --probe      the step's proof, against scratch origins (bare repos borrowing this root's objects; corpus sparse): arm 1 lands with a red
#                gate and must push nothing; arm 2 moves every origin first, plants a push race on corpus inside the gate, and must land all
#                four repos with the race rejected, recorded in a scratch postoffice and re-landed. Prints LAND dry-run ok stages=N.
#   --tables     print the generated-table registry (generated_tables.tsv) and run nothing
# OUTPUT: one line per stage, LAND stage=<name> ...; the verdict LAND ok stages=N rejected=R pushed=..., or LAND RED stage=<name> ...
# (rc 1), or LAND REFUSE(2) ... (rc 2). Logs under /tmp/s4e/<seat>/land.<pid>, deleted on a green verdict and kept on any other.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$HERE/$(basename "${BASH_SOURCE[0]}")"
ORDER=(SCRIP harness corpus .github)
home=""; gate=""; row=""; gt=1800; tries=3; mode=land; names=()
refuse() { echo "LAND REFUSE(2) $*"; [ -n "${LOG:-}" ] && echo "LAND logs kept: $LOG"; exit 2; }
red() { echo "LAND RED stage=$1 $2"; [ -n "${LOG:-}" ] && echo "LAND logs kept: $LOG"; exit 1; }
while [ $# -gt 0 ]; do
    case "$1" in
        --home) home="${2:-}"; shift 2 ;;
        --row) row="${2:-}"; shift 2 ;;
        --gate) gate="${2:-}"; shift 2 ;;
        --gate-timeout) gt="${2:-}"; shift 2 ;;
        --tries) tries="${2:-}"; shift 2 ;;
        --probe) mode=probe; shift ;;
        --tables) mode=tables; shift ;;
        SCRIP|harness|corpus|.github) names+=("$1"); shift ;;
        *) refuse "usage: s4e_land.sh [--home DIR] (--row TOPIC | --gate CMD) [--gate-timeout S] [--tries N] [SCRIP|harness|corpus|.github ...] | --probe | --tables" ;;
    esac
done
[ -n "$home" ] || home="$(cd "$HERE/../.." && pwd)"
home="$(cd "$home" 2>/dev/null && pwd)" || refuse "no root at $home"
TSV="$home/harness/scripts/generated_tables.tsv"
seat="${S4E_SEAT:-$(bash "$HERE/s4e_msg.sh" whoami 2>/dev/null | tail -1 | tr -d '[:space:]')}"
[ -n "$seat" ] || seat="$(id -un)"
mkdir -p "/tmp/s4e/$seat" || refuse "cannot make /tmp/s4e/$seat"
if [ "$mode" = tables ]; then
    [ -f "$TSV" ] || refuse "no registry at $TSV"
    awk -F'\t' '!/^#/' "$TSV" | column -t -s $'\t'
    exit 0
fi
probe() {
    local src="$home" T r sha objs b n rc log k RACE="probe: a racer lands on corpus during the gate"
    T="$(mktemp -d "/tmp/s4e/$seat/land-probe.XXXXXX")" || refuse "cannot make a scratch directory"
    trap 'rm -rf "$T" "/tmp/s4e/$seat/land.$(printf "%s" "$T/work" | sha1sum | cut -c1-12).lock"' EXIT
    mkdir -p "$T/origin" "$T/work" "$T/po"
    for r in "${ORDER[@]}"; do
        [ -e "$src/$r/.git" ] || refuse "probe: no $src/$r to borrow"
        sha="$(git -C "$src/$r" rev-parse HEAD)" || refuse "probe: $r has no HEAD"
        objs="$(cd "$src/$r" && git rev-parse --path-format=absolute --git-common-dir)/objects"
        b="$T/origin/$r.git"
        git init -q --bare "$b" && echo "$objs" > "$b/objects/info/alternates" || refuse "probe: cannot make the scratch origin of $r"
        git -C "$b" update-ref refs/heads/main "$sha" && git -C "$b" symbolic-ref HEAD refs/heads/main || refuse "probe: cannot point the scratch origin of $r at $sha"
        if [ "$r" = corpus ]; then
            git clone -q --shared --no-checkout "$b" "$T/work/$r" || refuse "probe: cannot clone $r"
            git -C "$T/work/$r" sparse-checkout set --cone tests/shared/box_scheduler && git -C "$T/work/$r" reset -q --hard HEAD || refuse "probe: cannot check out $r sparse"
        else
            git clone -q --shared "$b" "$T/work/$r" || refuse "probe: cannot clone $r"
        fi
        git -C "$T/work/$r" config user.name LCherryholmes; git -C "$T/work/$r" config user.email lcherryh@yahoo.com
        git -C "$T/work/$r" commit -q --allow-empty -m "probe: the landing's own commit in $r" || refuse "probe: cannot commit in $r"
        advance "$b" "probe: origin moved under $r before the landing"
    done
    log="$T/arm1.log"
    declare -A was
    for r in "${ORDER[@]}"; do was[$r]="$(git -C "$T/origin/$r.git" rev-parse main)"; done
    S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" bash "$SELF" --home "$T/work" --gate 'echo "probe: this gate reads red"; exit 1' > "$log" 2>&1; rc=$?
    sed 's/^/    arm1| /' "$log" | tail -12
    k="$(sed -n 's/^LAND logs kept: \(\/tmp\/s4e\/.*\/land\.[0-9]*\)$/\1/p' "$log")"; [ -n "$k" ] && rm -rf "$k"
    [ "$rc" = 1 ] && grep '^LAND RED stage=gate' "$log" > /dev/null || { echo "LAND dry-run RED: arm 1 (a red gate) returned rc=$rc without LAND RED stage=gate"; exit 1; }
    for r in "${ORDER[@]}"; do
        [ "$(git -C "$T/origin/$r.git" rev-parse main)" = "${was[$r]}" ] || { echo "LAND dry-run RED: arm 1 pushed $r past a red gate"; exit 1; }
    done
    printf '#!/usr/bin/env bash\n[ -e "%s/raced" ] && exit 0\n: > "%s/raced"\nb="%s/origin/corpus.git"\n' "$T" "$T" "$T" > "$T/race.sh"
    printf 'c="$(git -C "$b" commit-tree "main^{tree}" -p main -m "%s")" && git -C "$b" update-ref refs/heads/main "$c" main\n' "$RACE" >> "$T/race.sh"
    log="$T/arm2.log"
    S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" bash "$SELF" --home "$T/work" --gate "bash harness/scripts/util_require_fresh.sh --gate s4e_land_probe && bash $T/race.sh" > "$log" 2>&1; rc=$?
    sed 's/^/    arm2| /' "$log" | tail -16
    [ "$rc" = 0 ] || { echo "LAND dry-run RED: arm 2 (moved origins and a planted race) returned rc=$rc"; exit 1; }
    n="$(sed -n 's/^LAND ok stages=\([0-9]*\) rejected=1 .*/\1/p' "$log")"
    [ -n "$n" ] || { echo "LAND dry-run RED: arm 2 did not read LAND ok with exactly one rejected push"; exit 1; }
    for r in "${ORDER[@]}"; do
        b="$T/origin/$r.git"
        [ "$(git -C "$b" rev-parse main)" = "$(git -C "$T/work/$r" rev-parse HEAD)" ] || { echo "LAND dry-run RED: origin of $r is not the landed HEAD"; exit 1; }
        git -C "$b" log --format=%s main | grep -x "probe: the landing's own commit in $r" > /dev/null || { echo "LAND dry-run RED: the landing's commit is not on origin $r"; exit 1; }
        git -C "$b" log --format=%s main | grep -x "probe: origin moved under $r before the landing" > /dev/null || { echo "LAND dry-run RED: origin $r lost its own commit"; exit 1; }
    done
    git -C "$T/origin/corpus.git" log --format=%s main | grep -x "$RACE" > /dev/null || { echo "LAND dry-run RED: the racer's corpus commit is not on origin"; exit 1; }
    [ "$(awk -F'\t' '$3 == "corpus"' "$T/po/PUSH_REJECTED.tsv" 2>/dev/null | wc -l)" = 1 ] || { echo "LAND dry-run RED: the rejected corpus push was not recorded once in PUSH_REJECTED.tsv"; exit 1; }
    echo "LAND dry-run ok stages=$n rejected=1 repos=${#ORDER[@]} arms=2 (scratch origins borrowing $home; a red gate pushed nothing;"\
         "moved origins rebased; a push race rejected, recorded, re-landed and verified)"
    exit 0
}
advance() {
    local c
    c="$(git -C "$1" commit-tree "main^{tree}" -p main -m "$2")" && git -C "$1" update-ref refs/heads/main "$c" main || refuse "probe: cannot advance $1"
}
[ "$mode" = probe ] && probe
LOG="/tmp/s4e/$seat/land.$$"
mkdir -p "$LOG" || refuse "cannot make $LOG"
declare -A stage_done
mark() { stage_done[$1]=1; echo "LAND stage=$1 $2"; }
present=()
for r in "${ORDER[@]}"; do [ -e "$home/$r/.git" ] && present+=("$r"); done
for r in SCRIP harness corpus; do [ -e "$home/$r/.git" ] || refuse "no $home/$r: a landing builds SCRIP beside harness and corpus"; done
[ -f "$TSV" ] || refuse "no registry at $TSV"
exec 9> "/tmp/s4e/$seat/land.$(printf '%s' "$home" | sha1sum | cut -c1-12).lock"
flock -n 9 || refuse "another landing holds $home"
g() { local r="$1"; shift; timeout -k 5 180 git -C "$home/$r" "$@"; }
if [ -n "$row" ]; then
    tf="${S4E_POSTOFFICE:-/home/resources/postoffice}/tasks/$row.task.md"
    [ -f "$tf" ] || refuse "no baton $tf"
    gate="$(sed -n 's/^DONE-WHEN: //p' "$tf" | head -1)"
    [ -n "$gate" ] || refuse "the baton of $row carries no DONE-WHEN"
fi
[ -n "$gate" ] || refuse "no gate: name the row (--row TOPIC) or the command (--gate CMD); a landing is never pushed ungated"
named() { local x; [ "${#names[@]}" = 0 ] && return 0; for x in "${names[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }
for r in "${present[@]}"; do
    [ -n "$(git -C "$home/$r" status --porcelain --untracked-files=no)" ] && refuse "$r has uncommitted tracked changes: a landing lands commits"
    for d in rebase-merge rebase-apply MERGE_HEAD; do [ -e "$(git -C "$home/$r" rev-parse --git-path "$d")" ] && refuse "$r has a $d in progress"; done
done
for x in "${names[@]}"; do [ -e "$home/$x/.git" ] || refuse "named $x, and there is no $home/$x"; done
mark preflight "home=$home seat=$seat repos=${present[*]} gate=$(printf '%s' "$gate" | cut -c1-120)"
ahead() { git -C "$home/$1" rev-list --count origin/main..HEAD; }
fetch() {
    local r
    for r in "${present[@]}"; do g "$r" fetch -q origin main > "$LOG/fetch.$r" 2>&1 || red fetch "repo=$r $(tail -1 "$LOG/fetch.$r")"; done
    mark fetch "$(for r in "${present[@]}"; do printf '%s@%s ' "$r" "$(git -C "$home/$r" rev-parse --short=9 origin/main)"; done)"
}
rebase() {
    local r a u
    for r in "${present[@]}"; do
        a="$(ahead "$r")"
        if [ "$a" -gt 0 ]; then
            named "$r" || refuse "$r carries $a unlanded commit(s) and is not named: the gate would read a tree that is not pushed"
            if ! g "$r" rebase -q origin/main > "$LOG/rebase.$r" 2>&1; then
                u="$(git -C "$home/$r" diff --name-only --diff-filter=U | head -20 | tr '\n' ' ')"
                git -C "$home/$r" rebase --abort > /dev/null 2>&1
                red rebase "repo=$r conflicts=${u:-?} (the rebase was aborted; the tree is as it was)"
            fi
        else
            g "$r" merge -q --ff-only origin/main > "$LOG/rebase.$r" 2>&1 || red rebase "repo=$r cannot fast-forward to origin/main: $(tail -1 "$LOG/rebase.$r")"
        fi
    done
    mark rebase "$(for r in "${present[@]}"; do printf '%s+%s ' "$r" "$(ahead "$r")"; done)"
}
written=(); summary=""; binfo=""
regen() {
    local phase="$1" k c w rc stale=() pids=()
    written=()
    mapfile -t ks < <(awk -F'\t' -v p="^($phase)\$" '!/^#/ && $1 != "name" && $2 ~ p && !s[$1]++ {print $1}' "$TSV")
    [ "${#ks[@]}" -gt 0 ] || refuse "the registry has no $phase-phase table"
    for k in "${ks[@]}"; do
        c="$(awk -F'\t' -v k="$k" '!/^#/ && $1 == k {print $4; exit}' "$TSV")"
        ( cd "$home" && S4E_HOME="$home" timeout -k 5 900 bash "$home/harness/scripts/util_check_cache.sh" "land-$k" -- bash -c "$c" > "$LOG/check.$k" 2>&1; echo $? > "$LOG/check.$k.rc" ) &
        pids+=($!)
    done
    wait "${pids[@]}"
    for k in "${ks[@]}"; do
        rc="$(cat "$LOG/check.$k.rc")"
        case "$rc" in
            0) ;;
            1) stale+=("$k") ;;
            2) refuse "$phase table $k cannot be checked: $(tail -1 "$LOG/check.$k")" ;;
            *) red "$2" "table=$k check rc=$rc: $(tail -1 "$LOG/check.$k")" ;;
        esac
    done
    for k in "${stale[@]}"; do
        w="$(awk -F'\t' -v k="$k" '!/^#/ && $1 == k {print $5; exit}' "$TSV")"
        c="$(awk -F'\t' -v k="$k" '!/^#/ && $1 == k {print $4; exit}' "$TSV")"
        ( cd "$home" && timeout -k 5 900 bash -c "$w" ) > "$LOG/write.$k" 2>&1 || red "$2" "table=$k write failed: $(tail -1 "$LOG/write.$k")"
        ( cd "$home" && timeout -k 5 900 bash -c "$c" ) > "$LOG/recheck.$k" 2>&1 || red "$2" "table=$k is still stale after its own write: $(tail -1 "$LOG/recheck.$k")"
        written+=("$k")
    done
    summary="${#ks[@]} checked, ${#stale[@]} stale${stale[*]:+ (${stale[*]})}"
}
commit_regen() {
    local r o k f outs msg
    [ "${#written[@]}" = 0 ] && return 0
    for r in "${present[@]}"; do
        outs=()
        for k in "${written[@]}"; do
            while IFS= read -r o; do [ "${o%%/*}" = "$r" ] && outs+=("${o#*/}"); done < <(awk -F'\t' -v k="$k" '!/^#/ && $1 == k {print $3}' "$TSV")
        done
        [ "${#outs[@]}" = 0 ] && continue
        git -C "$home/$r" add -- "${outs[@]}" || red "$1" "repo=$r cannot stage the regenerated tables"
        git -C "$home/$r" diff --cached --quiet && continue
        msg="LAND: regenerate ${written[*]} on origin $(git -C "$home/$r" rev-parse --short=9 origin/main) (s4e_land.sh: a generated table is regenerated, never edited)"
        git -C "$home/$r" -c user.name=LCherryholmes -c user.email=lcherryh@yahoo.com commit -q -m "$msg" > "$LOG/commit.$r" 2>&1 ||
            red "$1" "repo=$r cannot commit the regenerated tables: $(tail -1 "$LOG/commit.$r")"
        named "$r" || [ "${#names[@]}" = 0 ] || names+=("$r")
    done
    for r in "${present[@]}"; do
        f="$(git -C "$home/$r" status --porcelain --untracked-files=no | head -5 | tr '\n' ' ')"
        [ -n "$f" ] && red "$1" "repo=$r a generator wrote outside its declared outputs: $f"
    done
    return 0
}
build() {
    ( cd "$home/SCRIP" && timeout -k 5 1800 make -j8 ) > "$LOG/make.$1.log" 2>&1 || red "$1" "make -j8 rc=$?: $(grep -m1 -E 'error|Error' "$LOG/make.$1.log" | cut -c1-200)"
    binfo="$(sed -n 's/^source //p' "$home/SCRIP/out/buildinfo" 2>/dev/null | head -1)"
}
gate_run() {
    local rc
    ( cd "$home" && S4E_HOME="$home" timeout -k 5 "$gt" bash -c "$gate" ) > "$LOG/gate.log" 2>&1; rc=$?
    tail -5 "$LOG/gate.log" | sed 's/^/    gate| /'
    case "$rc" in
        0) mark gate "rc=0 on $(git -C "$home/SCRIP" rev-parse --short=9 HEAD)" ;;
        2) refuse "the gate could not measure (rc 2): nothing pushed" ;;
        124|137) refuse "the gate ran past its $gt s budget: nothing pushed" ;;
        *) red gate "rc=$rc: nothing pushed" ;;
    esac
}
push_one() {
    local r="$1" mine theirs
    [ "$(ahead "$r")" -gt 0 ] || { echo "LAND stage=push:$r nothing to push (origin $(git -C "$home/$r" rev-parse --short=9 origin/main))"; return 0; }
    named "$r" || refuse "$r carries commits and is not named"
    mine="$(git -C "$home/$r" rev-parse HEAD)"
    g "$r" push -q origin HEAD:refs/heads/main > "$LOG/push.$r" 2>&1
    theirs="$(g "$r" ls-remote origin refs/heads/main | cut -f1)"
    [ -n "$theirs" ] || red "push:$r" "git ls-remote origin read nothing after the push"
    if [ "$theirs" = "$mine" ]; then
        g "$r" fetch -q origin main > /dev/null 2>&1
        mark "push:$r" "${mine:0:9} verified on origin"
        pushed+=("$r@${mine:0:9}")
        return 0
    fi
    bash "$home/harness/scripts/s4e_push_rejected.sh" "$home/$r" > "$LOG/rejected.$r" 2>&1
    echo "LAND stage=push:$r REJECTED: origin is ${theirs:0:9}, not ${mine:0:9} ($(tail -1 "$LOG/push.$r" | cut -c1-120)); recorded, going round again"
    return 3
}
pushed=(); rejected=0; attempt=1
while :; do
    fetch
    rebase
    regen source regenerate
    commit_regen regenerate
    mark regenerate "$summary"
    build build
    mark build "${binfo:-built}"
    regen 'binary|built' derive; d="$summary"; dw=("${written[@]}")
    if [ "${#dw[@]}" -gt 0 ]; then
        commit_regen derive
        regen source derive; written+=("${dw[@]}"); commit_regen derive
        build derive
        d="$d; source again: $summary; rebuilt ${binfo:-built}"
    fi
    mark derive "$d"
    gate_run
    again=0
    for r in "${ORDER[@]}"; do
        [ -e "$home/$r/.git" ] || continue
        push_one "$r"; rc=$?
        [ "$rc" = 3 ] && { again=1; break; }
    done
    [ "$again" = 0 ] && break
    rejected=$((rejected + 1)); attempt=$((attempt + 1))
    [ "$attempt" -gt "$tries" ] && red push "the origin moved under $tries attempts; pushed so far: ${pushed[*]:-none}"
done
rm -rf "$LOG"
echo "LAND ok stages=${#stage_done[@]} rejected=$rejected pushed=${pushed[*]:-none} attempts=$attempt ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
exit 0
