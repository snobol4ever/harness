#!/usr/bin/env bash
# s4e_land.sh -- ONE LANDING COMMAND: fetch, rebase, regenerate every generated table, rebuild, re-derive the tables read from the binary, run the
# row's gate, push SCRIP and verify it on origin, then harness, then corpus, then .github last (DESIGN-PLAN box-scheduler step 18, the cao
# 2026-11-04, CTO-496; the design text in the shared-box skill's DESIGN section 8; Lon 2026-11-04, verbatim: "There has been talk, and only talk,
# about using industry recognized ways of doing make and build load balancing and management." / "So get to it.").
# THE MECHANISM is the merge queue's (a landing is tested on the tree it will become, and pushed only if that tree is green), run by the lander:
#   preflight   every repo present is a git repo with no tracked change and no rebase in progress; the gate is named; one landing per root (flock)
#   fetch       git fetch origin main in SCRIP, harness, corpus and .github (each under timeout)
#   rebase      a repo with commits rebases onto origin/main, a repo without fast-forwards to it; a conflict confined to registered generated
#               outputs takes the replayed side and goes on (the regenerate stage rewrites them from the merged sources: step 19, generated tables
#               merge by regeneration, never by hand; --merge-probe proves it); any other conflict aborts the rebase and reads RED
#   regenerate  every source-phase generator of generated_tables.tsv is checked (through util_check_cache.sh) and a stale one is rewritten,
#               re-checked and committed in its own repo as a separate commit; a generator that writes outside its declared outputs reads RED
#   build       make -j8 in SCRIP (the Makefile joins the box-wide jobserver and fetches the build cache's entry for a clean tree)
#   derive      every binary-phase table is re-derived from the built runtime and every built-phase table checked; a stale one is rewritten,
#               the source tables regenerated again, committed, and SCRIP rebuilt
#   gate        the row's DONE-WHEN (--row TOPIC) or --gate CMD, run from the root with S4E_HOME set; rc 0 lands, rc 1 RED, rc 2 refuses
#   lease       taken AFTER the gate (the box-wide flock <postoffice>/.land.lease serializes the pushes, never a gate); under it origin is fetched
#               again and a moved origin rebased: a move under the affected set (SCRIP/src/runtime, SCRIP/src/templates, SCRIP/Makefile, a generated
#               table's output, the row's TOUCHES: prefixes; any move when the row has none) drops the lease and re-runs the gate unleased, a move
#               outside it pushes the rebased tree with the gate standing; the lease is released after the last push (LAND stage=lease released held_s=N)
#   push:<repo> git push origin HEAD:main, then git ls-remote must name the local HEAD; SCRIP, harness, corpus, .github in that order. A push
#               the origin refused (a hand push outside the lease) is recorded by s4e_push_rejected.sh and the landing goes round again from fetch
#               (--tries, default 3), so the gate always reads the tree that is pushed
# USAGE: s4e_land.sh [--home DIR] (--row TOPIC | --gate CMD) [--gate-timeout S] [--tries N] [REPO...]
#   --home DIR   the root holding SCRIP harness corpus [.github] (default: the root this script sits in); a clean worktree layout
#                outside the root is the usual DIR. REPO names the repos whose commits land (default: every repo ahead of origin);
#                a repo that carries commits and is not named refuses, since its tree is what the gate reads.
#   --probe      the step's proof, against scratch origins (bare repos borrowing this root's objects; corpus sparse): arm 1 lands with a red
#                gate and must push nothing; arm 2 moves every origin first, plants a push race on corpus inside the gate, and must land all
#                four repos with the race rejected, recorded in a scratch postoffice and re-landed; arm 3 finds the box-wide landing lease held, waits, names the holder,
#                pushes nothing, then lands once it is free. Prints LAND dry-run ok stages=N.
#   --tables     print the generated-table registry (generated_tables.tsv) and run nothing
# OUTPUT: one line per stage, LAND stage=<name> ...; the verdict LAND ok stages=N rejected=R pushed=..., or LAND RED stage=<name> ...
# (rc 1), or LAND REFUSE(2) ... (rc 2). Logs under /tmp/s4e/<seat>/land.<pid>, deleted on a green verdict and kept on any other.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$HERE/$(basename "${BASH_SOURCE[0]}")"
ORDER=(SCRIP harness corpus .github)
home=""; gate=""; row=""; gt=1800; tries=3; mode=land; names=(); touches=""; proved=""
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
        --merge-probe) mode=merge_probe; shift ;;
        --tables) mode=tables; shift ;;
        --push) mode=push; shift ;;
        --proved) proved="${2:-}"; shift 2 ;;
        --touches) touches="${2:-}"; shift 2 ;;
        SCRIP|harness|corpus|.github) names+=("$1"); shift ;;
        *) refuse "usage: s4e_land.sh [--home DIR] (--row TOPIC | --gate CMD) [--gate-timeout S] [--tries N] [--touches 'prefix ...'] [REPO ...]"\
                  " | --push [--gate CMD | --proved TEXT] [REPO ...] | --probe | --tables" ;;
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
    for k in $(awk -F'\t' '!/^#/ && $1 != "name" && !s[$1]++ {print $1}' "$TSV"); do r="$(awk -F'\t' -v k="$k" '!/^#/ && $1 == k {print $3; exit}' "$TSV")"; r="${r%%/*}"; [ -e "$home/$r/.git" ] || echo "# skipped in this home: $k (no $r checkout under $home)"; done
    exit 0
fi
scratch_clone() {   # <T>: a bare scratch origin of each repo borrowing this root's objects, and a work clone of each under <T>/work (corpus sparse); the probes build on it
    local src="$home" T="$1" r sha objs b
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
    done
}
merge_probe() {   # step 19's proof: origin and the landing each regenerate the same table from a different source; the rebase conflicts on the output alone and the landing regenerates it from the merged source
    local T W O log rc got
    T="$(mktemp -d "/tmp/s4e/$seat/land-merge-probe.XXXXXX")" || refuse "cannot make a scratch directory"
    trap 'rm -rf "$T" "/tmp/s4e/$seat/land.$(printf "%s" "$T/work" | sha1sum | cut -c1-12).lock"' EXIT
    scratch_clone "$T"; W="$T/work/harness"; O="$T/other"
    printf '%s\n' '#!/usr/bin/env bash' 'H="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; src="$H/probe_table.src"; out="$H/probe_table.out"' \
        'want="$(printf "# generated from probe_table.src sha=%s\n" "$(sha1sum < "$src" | cut -c1-12)"; sort "$src")"' \
        'case "${1:-}" in --check) [ -f "$out" ] && [ "$(cat "$out")" = "$want" ] && exit 0; echo "probe_table.out is stale"; exit 1 ;; --write) printf "%s\n" "$want" > "$out"; exit 0 ;; *) exit 2 ;; esac' > "$W/scripts/probe_gen.sh"
    printf 'a\nb\nc\n' > "$W/scripts/probe_table.src"; bash "$W/scripts/probe_gen.sh" --write || refuse "merge-probe: the probe generator cannot write"
    printf 'probe_table\tsource\tharness/scripts/probe_table.out\tbash harness/scripts/probe_gen.sh --check\tbash harness/scripts/probe_gen.sh --write\n' >> "$W/scripts/generated_tables.tsv"
    git -C "$W" add scripts/probe_gen.sh scripts/probe_table.src scripts/probe_table.out scripts/generated_tables.tsv && git -C "$W" commit -q -m "merge-probe: a generated table, its source and its generator" \
        && git -C "$W" push -q origin HEAD:main || refuse "merge-probe: cannot seed the scratch origin"
    git clone -q --shared "$T/origin/harness.git" "$O" || refuse "merge-probe: cannot clone the other side"
    git -C "$O" config user.name LCherryholmes; git -C "$O" config user.email lcherryh@yahoo.com
    { printf 'd\n'; cat "$O/scripts/probe_table.src"; } > "$O/scripts/probe_table.src.new" && mv "$O/scripts/probe_table.src.new" "$O/scripts/probe_table.src"; bash "$O/scripts/probe_gen.sh" --write; git -C "$O" add -A && git -C "$O" commit -q -m "merge-probe: origin adds d and regenerates" && git -C "$O" push -q origin HEAD:main || refuse "merge-probe: cannot move origin"
    printf 'e\n' >> "$W/scripts/probe_table.src"; bash "$W/scripts/probe_gen.sh" --write; git -C "$W" add -A && git -C "$W" commit -q -m "merge-probe: the landing adds e and regenerates" || refuse "merge-probe: cannot commit the landing's side"
    log="$T/merge.log"
    S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" bash "$SELF" --home "$T/work" --gate 'true' harness > "$log" 2>&1; rc=$?
    sed 's/^/    merge| /' "$log" | grep -E 'stage=rebase|stage=regenerate|LAND ok|LAND RED|REFUSE' | tail -4
    [ "$rc" = 0 ] && grep -q '^LAND stage=rebase .*merged_outputs=1 (harness/scripts/probe_table.out' "$log" && grep -q '^LAND stage=regenerate .* 1 stale (probe_table)' "$log" \
        || { echo "MERGE RED: the landing returned rc=$rc without one output merged by regeneration (log kept: $log)"; trap - EXIT; exit 1; }
    git -C "$O" pull -q --rebase origin main || { echo "MERGE RED: the other side cannot pull the landed origin"; exit 1; }
    got="$(grep -vc '^#' "$O/scripts/probe_table.out")"; bash "$O/scripts/probe_gen.sh" --check > /dev/null; rc=$?
    [ "$rc" = 0 ] && [ "$got" = 5 ] && ! grep -q '^<<<<<<<\|^>>>>>>>' "$O/scripts/probe_table.out" && [ "$(grep -c . "$O/scripts/probe_table.src")" = 5 ] \
        || { echo "MERGE RED: origin's output is not the regeneration of the merged source (check rc=$rc rows=$got)"; exit 1; }
    git -C "$O" log --format=%s > "$T/log.txt"; grep -q 'merge-probe: origin adds d' "$T/log.txt" && grep -q 'merge-probe: the landing adds e' "$T/log.txt" || { echo "MERGE RED: a side's commit is missing on origin"; exit 1; }   # a file, not a pipe: grep -q under pipefail kills git log
    git -C "$W" pull -q --rebase origin main || refuse "merge-probe: the landing's side cannot pull the landed origin"
    printf 'g\n' >> "$O/scripts/probe_table.src"; bash "$O/scripts/probe_gen.sh" --write; git -C "$O" add -A && git -C "$O" commit -q -m "merge-probe: origin appends g" && git -C "$O" push -q origin HEAD:main || refuse "merge-probe: cannot move origin again"
    printf 'f\n' >> "$W/scripts/probe_table.src"; bash "$W/scripts/probe_gen.sh" --write; git -C "$W" add -A && git -C "$W" commit -q -m "merge-probe: the landing appends f" || refuse "merge-probe: cannot commit the second side"
    log="$T/merge2.log"
    S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" bash "$SELF" --home "$T/work" --gate 'true' harness > "$log" 2>&1; rc=$?
    sed 's/^/    merge2| /' "$log" | grep -E 'LAND RED|LAND ok|REFUSE' | tail -2
    [ "$rc" = 1 ] && grep -q '^LAND RED stage=rebase repo=harness conflicts= scripts/probe_table.src (not a generated output' "$log" && [ -z "$(git -C "$W" status --porcelain)" ] && [ ! -e "$(git -C "$W" rev-parse --absolute-git-dir)/rebase-merge" ] \
        || { echo "MERGE RED: a conflict in the SOURCE (not a generated output) did not abort the rebase and read RED (rc=$rc)"; trap - EXIT; exit 1; }
    echo "MERGE regenerated=1 conflicts=0 source_conflict=RED (the rebase met a conflict in harness/scripts/probe_table.out alone, took the replayed side, and the regenerate stage rewrote it from the merged source: 5 rows, check rc 0, both commits on origin; a conflict in the source itself aborted the rebase and read RED, the tree left as it was)"
    exit 0
}
probe() {
    local src="$home" T r sha objs b n rc log k RACE="probe: a racer lands on corpus during the gate"
    T="$(mktemp -d "/tmp/s4e/$seat/land-probe.XXXXXX")" || refuse "cannot make a scratch directory"
    trap 'rm -rf "$T" "/tmp/s4e/$seat/land.$(printf "%s" "$T/work" | sha1sum | cut -c1-12).lock"' EXIT
    scratch_clone "$T"
    for r in "${ORDER[@]}"; do
        git -C "$T/work/$r" commit -q --allow-empty -m "probe: the landing's own commit in $r" || refuse "probe: cannot commit in $r"
        advance "$T/origin/$r.git" "probe: origin moved under $r before the landing"
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
    n="$(sed -n 's/^LAND ok stages=\([0-9]*\) rounds=0 .*/\1/p' "$log")"
    [ -n "$n" ] && grep -q '^LAND stage=regate:lease reason=unaffected files=0' "$log" && grep -q '^LAND stage=lease released held_s=[0-9]* (pushed ' "$log" \
        || { echo "LAND dry-run RED: arm 2 did not read LAND ok with the race's empty move rebased under the lease (no file changed, so the gate stands) and no round more"; exit 1; }
    for r in "${ORDER[@]}"; do
        b="$T/origin/$r.git"
        [ "$(git -C "$b" rev-parse main)" = "$(git -C "$T/work/$r" rev-parse HEAD)" ] || { echo "LAND dry-run RED: origin of $r is not the landed HEAD"; exit 1; }
        git -C "$b" log --format=%s main | grep -x "probe: the landing's own commit in $r" > /dev/null || { echo "LAND dry-run RED: the landing's commit is not on origin $r"; exit 1; }
        git -C "$b" log --format=%s main | grep -x "probe: origin moved under $r before the landing" > /dev/null || { echo "LAND dry-run RED: origin $r lost its own commit"; exit 1; }
    done
    git -C "$T/origin/corpus.git" log --format=%s main | grep -x "$RACE" > /dev/null || { echo "LAND dry-run RED: the racer's corpus commit is not on origin"; exit 1; }
    [ "$(awk -F'\t' '$3 == "corpus"' "$T/po/PUSH_REJECTED.tsv" 2>/dev/null | wc -l)" = 0 ] || { echo "LAND dry-run RED: arm 2 had a push rejected although the move was rebased under the lease"; exit 1; }
    log="$T/arm3.log"; declare -A was3
    for r in "${ORDER[@]}"; do was3[$r]="$(git -C "$T/origin/$r.git" rev-parse main)"
        git -C "$T/work/$r" commit -q --allow-empty -m "probe: a third commit in $r" || refuse "probe: cannot commit in $r"; done
    ( exec 8>> "$T/po/.land.lease"; flock 8; printf 'seat=probe-holder pid=%s row=lease-plant since=%s\n' "$$" "$(date -u +%FT%TZ)" > "$T/po/.land.lease"; sleep 300 ) & holder=$!
    sleep 1
    S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" S4E_LAND_LEASE_WAIT=3 bash "$SELF" --home "$T/work" --gate 'true' > "$log" 2>&1; rc=$?
    sed 's/^/    arm3| /' "$log" | tail -4
    kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
    [ "$rc" = 2 ] && grep -q '^LAND stage=gate rc=0' "$log" && grep -q 'LAND stage=lease waiting: held by seat=probe-holder' "$log" && grep -q 'lease is still held after 3 s' "$log" \
        || { echo "LAND dry-run RED: arm 3 (the lease held by another lander) returned rc=$rc, not a gate run unleased and then the refusal rc 2 that waits on and names the holder"; exit 1; }
    for r in "${ORDER[@]}"; do [ "$(git -C "$T/origin/$r.git" rev-parse main)" = "${was3[$r]}" ] || { echo "LAND dry-run RED: arm 3 pushed $r while the lease was held"; exit 1; }; done
    log="$T/arm3b.log"
    S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" bash "$SELF" --home "$T/work" --gate 'true' > "$log" 2>&1; rc=$?
    [ "$rc" = 0 ] && grep -q "LAND stage=lease held seat=$seat" "$log" || { echo "LAND dry-run RED: arm 3 (the lease released) returned rc=$rc without taking the lease"; exit 1; }
    for r in "${ORDER[@]}"; do git -C "$T/origin/$r.git" log --format=%s main | grep -x "probe: a third commit in $r" > /dev/null \
        || { echo "LAND dry-run RED: arm 3 did not land $r once the lease was free"; exit 1; }; done
    git clone -q --shared --no-checkout "$T/origin/corpus.git" "$T/racer" && git -C "$T/racer" sparse-checkout set --cone tests/shared/box_scheduler && git -C "$T/racer" reset -q --hard HEAD \
        || refuse "probe: cannot clone the racer"
    git -C "$T/racer" config user.name LCherryholmes; git -C "$T/racer" config user.email lcherryh@yahoo.com
    racer() {   # racer <script> <marker> <file>: inside the gate, once, land a file under corpus/tests/shared/box_scheduler on the scratch origin
        printf '#!/usr/bin/env bash\n[ -e "%s" ] && exit 0\n: > "%s"\ncd "%s" && git pull -q --rebase origin main' "$T/$2" "$T/$2" "$T/racer" > "$T/$1"
        printf ' && echo race > "tests/shared/box_scheduler/%s" && git add -A && git commit -q -m "probe: a racer lands %s" && git push -q origin HEAD:main\n' "$3" "$3" >> "$T/$1"; }
    racer race4.sh raced4 "probe-race4-$$.txt"
    for r in "${ORDER[@]}"; do git -C "$T/work/$r" commit -q --allow-empty -m "probe: a fourth commit in $r" || refuse "probe: cannot commit in $r"; done
    log="$T/arm4.log"
    S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" bash "$SELF" --home "$T/work" --touches 'harness/scripts/s4e_land.sh' \
        --gate "bash harness/scripts/util_require_fresh.sh --gate s4e_land_probe && echo g >> $T/gates4 && bash $T/race4.sh" > "$log" 2>&1; rc=$?
    sed 's/^/    arm4| /' "$log" | grep -E 'regate|LAND ok|LAND RED|REFUSE' | tail -4
    [ "$rc" = 0 ] && grep -q '^LAND stage=regate:lease reason=unaffected files=1' "$log" && [ "$(wc -l < "$T/gates4")" = 1 ] \
        || { echo "LAND dry-run RED: arm 4 (a race under an untouched path) rc=$rc: expected regate:lease unaffected and one gate run, got $(wc -l < "$T/gates4" 2>/dev/null) run(s)"; exit 1; }
    racer race5.sh raced5 "probe-race5-$$.txt"
    for r in "${ORDER[@]}"; do git -C "$T/work/$r" commit -q --allow-empty -m "probe: a fifth commit in $r" || refuse "probe: cannot commit in $r"; done
    log="$T/arm5.log"
    S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" bash "$SELF" --home "$T/work" --touches 'corpus/tests/shared' \
        --gate "bash harness/scripts/util_require_fresh.sh --gate s4e_land_probe && echo g >> $T/gates5 && bash $T/race5.sh" > "$log" 2>&1; rc=$?
    sed 's/^/    arm5| /' "$log" | grep -E 'regate|LAND ok|LAND RED|REFUSE' | tail -4
    [ "$rc" = 0 ] && grep -q '^LAND stage=regate:2 reason=affected files=1' "$log" && [ "$(wc -l < "$T/gates5")" = 2 ] \
        || { echo "LAND dry-run RED: arm 5 (a race under a touched path) rc=$rc: expected regate:2 affected and two gate runs, got $(wc -l < "$T/gates5" 2>/dev/null) run(s)"; exit 1; }
    git -C "$T/work/corpus" commit -q --allow-empty -m "probe: a hand-proved commit in corpus" || refuse "probe: cannot commit in corpus"
    log="$T/arm6.log"
    S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" bash "$SELF" --push --proved 'probe: proved by hand on this tree' --home "$T/work" corpus > "$log" 2>&1; rc=$?
    sed 's/^/    arm6| /' "$log" | tail -3
    [ "$rc" = 0 ] && grep -q '^LAND ok mode=push .*hand_push=leased' "$log" && git -C "$T/origin/corpus.git" log --format=%s main | grep -x "probe: a hand-proved commit in corpus" > /dev/null \
        && [ "$(grep -vc '^#' "$T/po/HAND_PUSHES.tsv")" = 1 ] || { echo "LAND dry-run RED: arm 6 (a hand push under the lease) rc=$rc"; exit 1; }   # grep -x, not -q: under pipefail a -q that closes the pipe early kills git log with SIGPIPE
    S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" bash "$SELF" --push --home "$T/work" corpus > "$T/arm6b.log" 2>&1
    [ $? = 2 ] || { echo "LAND dry-run RED: a hand push without a proof was not refused rc 2"; exit 1; }
    for r in "${ORDER[@]}"; do git -C "$T/work/$r" commit -q --allow-empty -m "probe: a seventh commit in $r" || refuse "probe: cannot commit in $r"; done
    log="$T/arm7.log"
    S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" bash "$SELF" --home "$T/work" --gate "if flock -n $T/po/.land.lease true; then echo free; else echo held; fi > $T/free7; sleep 2" > "$log" 2>&1; rc=$?
    sed 's/^/    arm7| /' "$log" | grep -E 'lease|LAND ok|LAND RED|REFUSE' | tail -4
    h="$(sed -n 's/^LAND stage=lease released held_s=\([0-9]*\) .*/\1/p' "$log" | tail -1)"
    [ "$rc" = 0 ] && [ "$(cat "$T/free7" 2>/dev/null)" = free ] && [ -n "$h" ] \
        || { echo "LAND dry-run RED: arm 7 (the gate runs unleased, the lease covers only the push) rc=$rc free=$(cat "$T/free7" 2>/dev/null) held_s=${h:-?}"; exit 1; }
    echo "    arm7| held_s=$h is information, never the verdict: a wall clock judges nothing under box load (the cio's ruling, 2026-11-05)"
    racer race8.sh raced8 "probe-race8-$$.txt"
    for r in "${ORDER[@]}"; do git -C "$T/work/$r" commit -q --allow-empty -m "probe: an eighth commit in $r" || refuse "probe: cannot commit in $r"; done
    log="$T/arm8.log"
    S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" S4E_LAND_PLANT="bash $T/race8.sh" bash "$SELF" --home "$T/work" --gate "echo g >> $T/gates8" > "$log" 2>&1; rc=$?
    sed 's/^/    arm8| /' "$log" | grep -E 'REJECTED|regate|lease released|LAND ok|LAND RED|REFUSE' | tail -5
    [ "$rc" = 0 ] && grep -q '^LAND stage=push:corpus REJECTED' "$log" && grep -q '^LAND ok stages=[0-9]* rounds=1 ' "$log" \
        && [ "$(awk -F'\t' '$3 == "corpus"' "$T/po/PUSH_REJECTED.tsv" 2>/dev/null | wc -l)" = 1 ] && [ "$(wc -l < "$T/gates8")" = 2 ] \
        && git -C "$T/origin/corpus.git" log --format=%s main | grep -x "probe: a racer lands probe-race8-$$.txt" > /dev/null \
        && [ "$(git -C "$T/origin/corpus.git" rev-parse main)" = "$(git -C "$T/work/corpus" rev-parse HEAD)" ] \
        || { echo "LAND dry-run RED: arm 8 (a hand push between the lease's fetch and the push) rc=$rc: expected one rejected corpus push recorded, one round more, two gate runs, the racer kept"; exit 1; }
    echo "LAND dry-run ok stages=$n rounds=1 repos=${#ORDER[@]} arms=8 regate=affected hand_push=leased lease=push-only (scratch origins borrowing $home; a red gate pushed nothing;"\
         "moved origins rebased; a move under the gate rebased under the lease and re-gated unleased; a held lease waited on after the gate, its holder named, nothing pushed; landed once free;"\
         "a race under an untouched path did not re-gate, one under a touched path did; a hand push went under the lease with its proof recorded, and without one refused;"\
         "the gate found the lease free and the lease was held $h s; a push rejected by a hand push outside the lease was recorded once and re-landed)"
    exit 0
}
advance() {
    local c
    c="$(git -C "$1" commit-tree "main^{tree}" -p main -m "$2")" && git -C "$1" update-ref refs/heads/main "$c" main || refuse "probe: cannot advance $1"
}
[ "$mode" = probe ] && probe
[ "$mode" = merge_probe ] && merge_probe
# THE LEASE IS HELD ONLY AROUND THE PUSH (the cio 2026-11-04 20:1x CST, on hq_pascal's 14-minute wait behind hq_unicon's gate and seven landings queued behind
# hq_templates' 35-minute gate): the gate runs UNLEASED on the rebased tree; the lease is taken after it, origin is fetched again under the lease, and if it moved
# the tree is rebased there -- a move under the row's affected set drops the lease and re-runs the gate unleased, a move outside it pushes the rebased tree with the
# gate standing (the merge-queue shape: optimistic gating, serialized pushing). A lease is held for the seconds a fetch, a rebase and four pushes take, never a gate.
lease="${S4E_POSTOFFICE:-/home/resources/postoffice}/.land.lease"; lw="${S4E_LAND_LEASE_WAIT:-1800}"; lease_since=0
exec 8>> "$lease" 2>/dev/null || refuse "cannot open the landing lease $lease"
take_lease() {
    if ! flock -n 8; then
        echo "LAND stage=lease waiting: held by $(tail -1 "$lease" 2>/dev/null | cut -c1-120); the lease serializes the pushes box-wide, never a gate (box-scheduler step 18; up to $lw s)"
        flock -w "$lw" 8 || refuse "the landing lease is still held after $lw s by $(tail -1 "$lease" 2>/dev/null | cut -c1-120): the gate ran, nothing pushed; run the landing again"
    fi
    lease_since="$(date +%s)"
    printf 'seat=%s pid=%s row=%s since=%s\n' "$seat" "$$" "${row:-gate}" "$(date -u +%FT%TZ)" > "$lease"
    echo "LAND stage=lease held seat=$seat pid=$$ after_gate=1 (released after the push)"
}
drop_lease() { printf 'free: released by seat=%s pid=%s at %s\n' "$seat" "$$" "$(date -u +%FT%TZ)" > "$lease"; flock -u 8; echo "LAND stage=lease released held_s=$(( $(date +%s) - lease_since )) $1"; }   # the file names the last holder until the next takes it; a waiter reads free:
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
if [ -n "$row" ] && [ -z "$touches" ]; then touches="$(sed -n 's/^TOUCHES: //p' "$tf" | head -1)"; fi
if [ "$mode" = push ]; then
    [ -n "$gate" ] || [ -n "$proved" ] || refuse "a hand push under the lease names its proof: --gate CMD (run here) or --proved 'what was proved, where'" \
        "(recorded in HAND_PUSHES.tsv)"
else [ -n "$gate" ] || refuse "no gate: name the row (--row TOPIC) or the command (--gate CMD); a landing is never pushed ungated"; fi
named() { local x; [ "${#names[@]}" = 0 ] && return 0; for x in "${names[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }
for r in "${present[@]}"; do
    [ -n "$(git -C "$home/$r" status --porcelain --untracked-files=no)" ] && refuse "$r has uncommitted tracked changes: a landing lands commits"
    for d in rebase-merge rebase-apply MERGE_HEAD; do [ -e "$(git_state "$r" "$d")" ] && refuse "$r has a $d in progress"; done
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
            if ! g "$r" rebase -q origin/main > "$LOG/rebase.$r" 2>&1; then resolve_output_conflicts "$r"; fi
        else
            g "$r" merge -q --ff-only origin/main > "$LOG/rebase.$r" 2>&1 || red rebase "repo=$r cannot fast-forward to origin/main: $(tail -1 "$LOG/rebase.$r")"
        fi
    done
    mark rebase "$(for r in "${present[@]}"; do printf '%s+%s ' "$r" "$(ahead "$r")"; done)${merged_names:+merged_outputs=$merged_outputs (${merged_names# }) taken from the replayed side, regenerated by the regenerate stage}"
}
merged_outputs=0; merged_names=""
git_state() { local p; p="$(git -C "$home/$1" rev-parse --git-path "$2")"; case "$p" in /*) printf '%s' "$p" ;; *) printf '%s/%s/%s' "$home" "$1" "$p" ;; esac; }   # --git-path answers relative to the repo, and this script runs elsewhere
resolve_output_conflicts() {   # <repo> (step 19: generated tables merge by regeneration, never by hand): while the rebase stops on conflicts confined to registered generated
    local r="$1" f o is_out other; local -a outs u   # outputs of this repo, take the replayed side and continue; the regenerate stage then rewrites them from the merged sources. Any other conflict aborts and reads RED.
    mapfile -t outs < <(awk -F'\t' -v p="^$r/" '!/^#/ && $1 != "name" && $3 ~ p {sub(p, "", $3); print $3}' "$TSV")
    while [ -e "$(git_state "$r" rebase-merge)" ] || [ -e "$(git_state "$r" rebase-apply)" ]; do
        mapfile -t u < <(git -C "$home/$r" diff --name-only --diff-filter=U)
        other=""
        for f in "${u[@]}"; do is_out=0; for o in "${outs[@]}"; do [ "$f" = "$o" ] && is_out=1; done; [ "$is_out" = 1 ] || other="$other $f"; done
        if [ -n "$other" ] || [ "${#u[@]}" = 0 ]; then
            git -C "$home/$r" rebase --abort > /dev/null 2>&1
            red rebase "repo=$r conflicts=${other:-?} (not a generated output; the rebase was aborted; the tree is as it was)"
        fi
        for f in "${u[@]}"; do
            git -C "$home/$r" checkout --theirs -- "$f" > /dev/null 2>&1 && git -C "$home/$r" add -- "$f" || { git -C "$home/$r" rebase --abort > /dev/null 2>&1; red rebase "repo=$r cannot take the replayed side of $f"; }
            merged_outputs=$((merged_outputs + 1)); merged_names="$merged_names $r/$f"
        done
        GIT_EDITOR=true git -C "$home/$r" rebase --continue > "$LOG/rebase.$r" 2>&1 || true
    done
}
written=(); summary=""; binfo=""
regen() {
    local phase="$1" k c w rc stale=() pids=()
    written=()
    mapfile -t ks < <(awk -F'\t' -v p="^($phase)\$" '!/^#/ && $1 != "name" && $2 ~ p && !s[$1]++ {print $1}' "$TSV")
    [ "${#ks[@]}" -gt 0 ] || refuse "the registry has no $phase-phase table"
    local present_ks=() sk; skipped=()
    for k in "${ks[@]}"; do if sk="$(absent_repo_of "$k")"; then skipped+=("$k:no-$sk"); else present_ks+=("$k"); fi; done   # a table whose output lives in a repo the home lacks is not this landing's (the cfo and the cqo, 2026-11-04: a three-sibling home refused on the .github tables)
    ks=("${present_ks[@]}")
    [ "${#ks[@]}" -gt 0 ] || { summary="0 checked, 0 stale (skipped ${skipped[*]})"; return 0; }
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
    summary="${#ks[@]} checked, ${#stale[@]} stale${stale[*]:+ (${stale[*]})}${skipped[*]:+ skipped=${skipped[*]}}"
}
absent_repo_of() {   # <table name> -> prints the repo of its first output when that repo has no checkout in the home (rc 0), else rc 1
    local o r; o="$(awk -F'\t' -v k="$1" '!/^#/ && $1 == k {print $3; exit}' "$TSV")"; r="${o%%/*}"
    [ -n "$r" ] && [ "$r" != "$o" ] && [ ! -e "$home/$r/.git" ] && { printf '%s' "$r"; return 0; }; return 1
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
# THE AFFECTED SET (the cfo 2026-11-04 19:4x: a 40-minute gate rejected three times; the cao: runtime, templates, the Makefile and every generated table
# change every program). After a rejected push the gate is re-run only when the rebase brought in a commit under SCRIP/src/runtime, SCRIP/src/templates,
# SCRIP/Makefile, a generated table's output, or one of the row's TOUCHES: prefixes; a landing with no TOUCHES re-gates on any change at all.
declare -A origin_seen
note_origins() { local r; for r in "${present[@]}"; do origin_seen[$r]="$(git -C "$home/$r" rev-parse origin/main)"; done; }
affected_since() {   # -> prints "reason=affected|unaffected files=N"; rc 0 affected
    local r f old new n=0 hit=0 t p; local -a outs
    mapfile -t outs < <(awk -F'\t' '!/^#/ && $1 != "name" {print $3}' "$TSV")
    for r in "${present[@]}"; do
        old="${origin_seen[$r]:-}"; new="$(git -C "$home/$r" rev-parse origin/main)"; [ -n "$old" ] && [ "$old" != "$new" ] || continue
        while IFS= read -r f; do
            [ -n "$f" ] || continue; n=$((n+1)); p="$r/$f"
            case "$p" in SCRIP/src/runtime/*|SCRIP/src/templates/*|SCRIP/Makefile) hit=1 ;; esac
            for t in "${outs[@]}"; do [ "$p" = "$t" ] && hit=1; done
            if [ -n "$touches" ]; then for t in $touches; do case "$p" in "$t"|"$t"/*) hit=1 ;; esac; done; else hit=1; fi
        done < <(git -C "$home/$r" diff --name-only "$old" "$new" 2>/dev/null)
    done
    [ "$hit" = 1 ] && { echo "reason=affected files=$n"; return 0; }; echo "reason=unaffected files=$n"; return 1; }
record_hand_push() { local f="${S4E_POSTOFFICE:-/home/resources/postoffice}/HAND_PUSHES.tsv"
    [ -s "$f" ] || printf '# at_utc\tseat\trepo\tsha\tproof  -- hand pushes made under the landing lease (s4e_land.sh --push); the lease is what keeps origin still under a running gate\n' > "$f"
    printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$seat" "$1" "$2" "${proved:-gate: $(printf '%s' "$gate" | cut -c1-100)}" >> "$f"; }
pushed=(); rejected=0; attempt=1
land_round() {   # one attempt: fetch, rebase, (regenerate, build, derive), the gate unleased, then the lease only around a fetch, a rebase and the pushes; rc 3 = go round again
    local r a moved=0 rc
    fetch; rebase
    if [ "$mode" != push ]; then
        regen source regenerate; commit_regen regenerate; mark regenerate "$summary"
        build build; mark build "${binfo:-built}"
        regen 'binary|built' derive; d="$summary"; dw=("${written[@]}")
        if [ "${#dw[@]}" -gt 0 ]; then
            commit_regen derive
            regen source derive; written+=("${dw[@]}"); commit_regen derive
            build derive
            d="$d; source again: $summary; rebuilt ${binfo:-built}"
        fi
        mark derive "$d"
    fi
    if [ -z "$gate" ]; then mark proved "hand proof recorded, no gate run here: $(printf '%s' "$proved" | cut -c1-120)"
    elif [ "$attempt" = 1 ]; then gate_run
    elif a="$(affected_since)"; then mark "regate:$attempt" "$a"; gate_run
    else mark "regate:$attempt" "$a (the gate of attempt $((attempt-1)) stands: the rebase brought nothing under the row's population)"; fi
    note_origins
    take_lease
    fetch
    for r in "${present[@]}"; do [ "${origin_seen[$r]}" = "$(git -C "$home/$r" rev-parse origin/main)" ] || moved=1; done
    if [ "$moved" = 1 ]; then
        rebase
        if a="$(affected_since)"; then drop_lease "(origin moved under the gate, $a: the gate re-runs unleased)"; return 3; fi
        mark "regate:lease" "$a (the gate stands: origin moved outside the row's population; the rebased tree is pushed)"
        note_origins
    fi
    [ -n "${S4E_LAND_PLANT:-}" ] && { bash -c "$S4E_LAND_PLANT" > "$LOG/plant" 2>&1 || true; }   # the probe's plant: a hand push that lands between the lease's fetch and the push
    for r in "${ORDER[@]}"; do
        [ -e "$home/$r/.git" ] || continue
        push_one "$r"; rc=$?
        [ "$rc" = 3 ] && { drop_lease "(a push was rejected: going round again)"; return 3; }
    done
    drop_lease "(pushed ${pushed[*]:-nothing})"
    return 0
}
while :; do
    if land_round; then break; fi
    rejected=$((rejected + 1)); attempt=$((attempt + 1))
    [ "$attempt" -gt "$tries" ] && red push "the origin moved under $tries attempts; pushed so far: ${pushed[*]:-none}"
done
if [ "$mode" = push ]; then
    for x in "${pushed[@]}"; do record_hand_push "${x%@*}" "${x#*@}"; done
    rm -rf "$LOG"; echo "LAND ok mode=push stages=${#stage_done[@]} rounds=$rejected pushed=${pushed[*]:-none} attempts=$attempt hand_push=leased ($(date -u +%Y-%m-%dT%H:%M:%SZ))"; exit 0
fi
rm -rf "$LOG"
echo "LAND ok stages=${#stage_done[@]} rounds=$rejected pushed=${pushed[*]:-none} attempts=$attempt lease=push-only ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
exit 0
