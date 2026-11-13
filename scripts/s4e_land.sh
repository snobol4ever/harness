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
#               (--tries, default 3), so the gate always reads the tree that is pushed. A push the SERVER refused with origin unmoved (GitHub's transient
#               "remote: fatal error in commit_refs", a 5xx, an internal server error) is not a moved origin: the push alone is retried after a backoff
#               (S4E_LAND_PUSH_RETRIES, default 4; S4E_LAND_PUSH_BACKOFF seconds times the retry, default 5), no rebase and no regate, and the lease is held
#               across it; a refusal that outlasts the retries reads RED. The LAND ok line counts push_refused, retried_push, rebased_for_refusal (a round
#               taken while origin had not moved: 0 unless a refusal went unrecognised) and origin_moved_rebases.
# USAGE: s4e_land.sh [--home DIR] (--row TOPIC | --gate CMD) [--gate-timeout S] [--tries N] [REPO...]
#   --home DIR   the root holding SCRIP harness corpus [.github] (default: the root this script sits in); a clean worktree layout
#                outside the root is the usual DIR. REPO names the repos whose commits land (default: every repo ahead of origin);
#                a repo that carries commits and is not named refuses, since its tree is what the gate reads.
#   --probe      the step's proof, against scratch origins (bare repos borrowing this root's objects; corpus sparse): arm 1 lands with a red
#                gate and must push nothing; arm 2 moves every origin first, plants a push race on corpus inside the gate, and must land all
#                four repos with the race rejected, recorded in a scratch postoffice and re-landed; arm 3 finds the box-wide landing lease held, waits, names the holder,
#                pushes nothing, then lands once it is free. Prints LAND dry-run ok stages=N.
#   --probe-push-refusal  the push-refusal proof on scratch origins: a plant lands a real racer on corpus once (one origin-moved round) and arms a
#                pre-receive hook that refuses the next push once with "fatal error in commit_refs" (retried as a push); prints LAND push_refused=server
#                retried_push=N rebased_for_refusal=0 origin_moved_rebases=M. The real origins are never touched.
#   --probe-serial  the serial last round's proof (fleet-queue step 20) on scratch origins: a racer lands on corpus in each of three rounds (round two
#                outside the row's TOUCHES), round three's refused push takes ONE serial gate under the lease, and a second lander queued behind that lease
#                lands once it is free. Prints LAND serial-probe ok ... or LAND serial-probe RED: <what differed>.
#   --probe-orphan-lock  the stopped lander's proof on scratch origins: a landing is sent TERM mid-gate (its gate a 120 s child); once it has exited no
#                process of it remains, its gate held neither lock descriptor, and a second landing from the same home lands; prints LAND probe-orphan-lock second=landed orphans=0.
#   --tables     print the generated-table registry (generated_tables.tsv) and run nothing
#   --probe-rerun  the proof of LAND.conf's switches on scratch origins (four arms); prints LAND rerun-probe ok
#   --probe-root-home  the proof of a landing from a seat's own root on a scratch root (two arms); prints LAND root-home-probe ok
# A SEAT LANDS FROM ITS OWN ROOT (officer_02 2026-11-13, row harness-a-worktree-is-scrip-alone-everything-else-from-the-seats-root; Lon 17:4x CST, in the coo's window,
#   verbatim: "I want you to work in /home/claude folder. We do not NEED duplication. Nope, dups not needed."): no seat makes a worktree; the home is the seat's root,
#   the default. The landing rebases the root's own commits onto origin, gates and pushes as for any home, and then syncs the root: each shared repo it holds
#   (git config s4e.shared, skill shared-box 4) has its clean files linked to the pristine again, since the rebase wrote them as new files (util_sync_root.sh --relink).
# LAND.conf (the cio 2026-11-13, row the-lander-reruns-a-landing-only-for-what-touches-it; Lon: "how are we going to fix the fleet infra-structure?" /
#   "I am willing to try anything and everything and monitor your experiments on the live fleet."): ONE FILE IN THE POSTOFFICE EVERY LANDER READS AT ITS START,
#   key=value a line, so a switch is turned on the live fleet without a landing; an option on the command line wins, then the file, then the default, and
#   WITH NO FILE THE LANDER IS THE LANDER OF 2026-11-12. MEASURED before it: 0 of 859 land commands passed --touches and 12 of 184 live batons carried a
#   TOUCHES line, so 811 of 859 regates read affected; 133 landings took 2.53 attempts each, 76 ended in the serial round; 26 landers ran at once at load 87.
#     tries=N          rounds before the one serial gate under the lease (default 3; 1 = an overtaken landing goes to the serial gate at once)
#     touches=derived  with no --touches and no TOUCHES line, the landing's own diff names its population: the directory of each file it changes
#                      (default declared: nothing named means every moved file is a hit)
#     tables=affected  a landing that changes nothing under SCRIP and no generator skips the regenerate and derive checks (default all)
#     width=N          at most N landings run their rounds at once; the rest wait in the line having run nothing (default 0: no line)
#     line_wait=S      seconds a landing waits in the line before it refuses rc 2 (default 10800)
#   Every landing writes one line to LANDINGS.tsv (the progress store): outcome, attempts, seconds a stage, the switches it ran under.
# OUTPUT: one line per stage, LAND stage=<name> ...; the verdict LAND ok stages=N rejected=R pushed=..., or LAND RED stage=<name> ...
# (rc 1), or LAND REFUSE(2) ... (rc 2). Logs under /tmp/s4e/<seat>/land.<pid>, deleted on a green verdict and kept on any other.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$HERE/$(basename "${BASH_SOURCE[0]}")"
# THE LANDER RUNS FROM A COPY OF ITSELF (worker_08 2026-11-07 16:1x, measured: the rebase stage moved the harness checkout the script was running from, bash reads a script by
# offset as it goes, and git_state's definition moved out from under its call at the preflight; worker_16, worker_17 and worker_20 saw the same "command not found"). The first
# process copies this file to the seat's scratch and re-executes the copy with S4E_LAND_SELF naming the original, so HERE and SELF still point at the harness checkout for the
# libraries and the probes while the running text can no longer be rewritten by its own fetch and rebase. The admitted re-run below runs the same copy.
if [ -z "${S4E_LAND_SELF:-}" ]; then
    _lc="/tmp/s4e/${S4E_SEAT:-land}/land.self.$$.sh"; mkdir -p "$(dirname "$_lc")" && cp "$SELF" "$_lc" && S4E_LAND_SELF="$SELF" exec bash "$_lc" "$@"
    echo "LAND REFUSE(2) could not copy $SELF to $_lc"; exit 2
fi
SELF="$S4E_LAND_SELF"; HERE="$(cd "$(dirname "$SELF")" && pwd)"; RUNNING_COPY="${BASH_SOURCE[0]}"
ORDER=(SCRIP harness corpus .github)
home=""; gate=""; row=""; gt=1800; tries=""; mode=land; names=(); touches=""; proved=""
refuse() { declare -F ledger > /dev/null && ledger refuse; echo "LAND REFUSE(2) $*"; [ -n "${LOG:-}" ] && echo "LAND logs kept: $LOG"; exit 2; }
red() { declare -F ledger > /dev/null && ledger "red:$1"; echo "LAND RED stage=$1 $2"; [ -n "${LOG:-}" ] && echo "LAND logs kept: $LOG"; exit 1; }
ORIG_ARGS=("$@")   # fleet-control step 3: the landing re-runs itself under the land class admission below
while [ $# -gt 0 ]; do
    case "$1" in
        --home) home="${2:-}"; shift 2 ;;
        --row) row="${2:-}"; shift 2 ;;
        --gate) gate="${2:-}"; shift 2 ;;
        --gate-timeout) gt="${2:-}"; shift 2 ;;
        --tries) tries="${2:-}"; shift 2 ;;
        --probe) mode=probe; shift ;;
        --merge-probe) mode=merge_probe; shift ;;
        --probe-push-refusal) mode=probe_push_refusal; shift ;;
        --probe-serial) mode=probe_serial; shift ;;
        --probe-mail) mode=probe_mail; shift ;;
        --probe-orphan-lock) mode=probe_orphan_lock; shift ;;
        --probe-land-class) mode=probe_land_class; shift ;;
        --probe-rerun) mode=probe_rerun; shift ;;
        --probe-root-home) mode=probe_root_home; shift ;;
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
PROBE_GREEN="${S4E_LAND_PROBE_GREEN:-/home/resources/progress/LAND_PROBE_GREEN.tsv}"   # hash, utc, seat, stages: one green probe per lander hash, box-wide
PO_LAND="${S4E_POSTOFFICE:-/home/resources/postoffice}"; CONF="$PO_LAND/LAND.conf"   # the switches of the header's LAND.conf block; a scratch postoffice has its own file, so a probe never reads the live one
conf() { local v; v="$(awk -F= -v k="$1" '!/^#/ && $1 == k { v = $2 } END { print v }' "$CONF" 2>/dev/null)"; printf '%s' "${v:-$2}"; }
tries="${tries:-$(conf tries 3)}"; touches_mode="$(conf touches declared)"; tables_mode="$(conf tables all)"; width="$(conf width 0)"; line_wait="$(conf line_wait 10800)"
for _v in "$tries" "$width" "$line_wait"; do case "$_v" in ''|*[!0-9]*) refuse "LAND.conf or --tries carries a value that is no count ($_v): tries, width and line_wait are whole numbers ($CONF)" ;; esac; done
[ "$tries" -ge 1 ] || refuse "tries is $tries: a landing has one round at least"
if [ "$PO_LAND" = /home/resources/postoffice ]; then LEDGER="${S4E_LAND_LEDGER:-/home/resources/progress/LANDINGS.tsv}"; else LEDGER="${S4E_LAND_LEDGER:-$PO_LAND/LANDINGS.tsv}"; fi
[ -n "$home" ] || refuse "--home is empty: name the root that holds SCRIP harness corpus and .github (worker_02 2026-11-07 16:0x: a backgrounded shell passed an unset variable)"
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
            git -C "$T/work/$r" sparse-checkout set --cone tests/probe_race && git -C "$T/work/$r" reset -q --hard HEAD || refuse "probe: cannot check out $r sparse"
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
    # THE PROBE IS THE LANDER'S OWN TEST, NOT THE LANDING'S (Lon 2026-11-07 12:0x, the cio: 59 landings this morning each ran it, about 280 s of CPU
    # apiece, 4.6 core-hours of self-test on a 16-core box). It runs once per change of the lander, for the whole box: a green probe records the
    # lander's hash in $PROBE_GREEN; a later --probe on the same hash prints the record and exits 0. S4E_LAND_PROBE_FRESH=1 runs it regardless.
    local key rec; key="$(sha256sum "$SELF" "$HERE/util_check_cache.sh" "$HERE/s4e_msg.sh" 2>/dev/null | sha256sum | cut -c1-16)"
    if [ -z "${S4E_LAND_PROBE_FRESH:-}" ] && rec="$(grep -m1 "^$key	" "$PROBE_GREEN" 2>/dev/null)" && [ -n "$rec" ]; then
        echo "LAND dry-run ok (cached: lander $key proved green by $(printf '%s' "$rec" | cut -f3) at $(printf '%s' "$rec" | cut -f2); the probe runs again when s4e_land.sh, util_check_cache.sh or s4e_msg.sh changes, or under S4E_LAND_PROBE_FRESH=1)"
        exit 0
    fi
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
    git clone -q --shared --no-checkout "$T/origin/corpus.git" "$T/racer" && git -C "$T/racer" sparse-checkout set --cone tests/probe_race && git -C "$T/racer" reset -q --hard HEAD \
        || refuse "probe: cannot clone the racer"
    git -C "$T/racer" config user.name LCherryholmes; git -C "$T/racer" config user.email lcherryh@yahoo.com
    racer() {   # racer <script> <marker> <file>: inside the gate, once, land a file under corpus/tests/probe_race on the scratch origin
        printf '#!/usr/bin/env bash\n[ -e "%s" ] && exit 0\n: > "%s"\ncd "%s" && git pull -q --rebase origin main' "$T/$2" "$T/$2" "$T/racer" > "$T/$1"
        printf ' && mkdir -p tests/probe_race && echo race > "tests/probe_race/%s" && git add -A && git commit -q -m "probe: a racer lands %s" && git push -q origin HEAD:main\n' "$3" "$3" >> "$T/$1"; }
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
    S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" bash "$SELF" --home "$T/work" --touches 'corpus/tests/probe_race' \
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
    { mkdir -p "$(dirname "$PROBE_GREEN")"; printf '%s\t%s\t%s\tstages=%s\n' "$key" "$(date -u +%FT%TZ)" "$seat" "$n" >> "$PROBE_GREEN"; } 2>/dev/null
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
probe_push_refusal() {   # the push-refusal proof: a real move and a server refusal on scratch origins, told apart
    local T log rc n m b f
    T="$(mktemp -d "/tmp/s4e/$seat/land-push-refusal.XXXXXX")" || refuse "cannot make a scratch directory"
    trap 'rm -rf "$T" "/tmp/s4e/$seat/land.$(printf "%s" "$T/work" | sha1sum | cut -c1-12).lock"' EXIT
    scratch_clone "$T"
    git clone -q --shared --no-checkout "$T/origin/corpus.git" "$T/racer" && git -C "$T/racer" sparse-checkout set --cone tests/probe_race && git -C "$T/racer" reset -q --hard HEAD \
        || refuse "probe: cannot clone the racer"
    git -C "$T/racer" config user.name LCherryholmes; git -C "$T/racer" config user.email lcherryh@yahoo.com
    printf '#!/usr/bin/env bash\n[ -e "%s" ] || exit 0\nrm -f "%s"\necho "fatal error in commit_refs" >&2\nexit 1\n' "$T/refuse_once" "$T/refuse_once" > "$T/origin/corpus.git/hooks/pre-receive"
    chmod +x "$T/origin/corpus.git/hooks/pre-receive"
    printf '#!/usr/bin/env bash\n[ -e "%s" ] && exit 0\n: > "%s"\ncd "%s" && git pull -q --rebase origin main && mkdir -p tests/probe_race && echo race > tests/probe_race/probe-refusal-race-%s.txt && git add -A && git commit -q -m "probe: a racer lands before the refusal" && git push -q origin HEAD:main && : > "%s"\n' \
        "$T/planted" "$T/planted" "$T/racer" "$$" "$T/refuse_once" > "$T/plant.sh"
    for r in "${ORDER[@]}"; do git -C "$T/work/$r" commit -q --allow-empty -m "probe: the refused landing's commit in $r" || refuse "probe: cannot commit in $r"; done
    log="$T/refusal.log"
    S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" S4E_LAND_PLANT="bash $T/plant.sh" S4E_LAND_PUSH_BACKOFF=1 bash "$SELF" --home "$T/work" --gate 'true' > "$log" 2>&1; rc=$?
    sed 's/^/    refusal| /' "$log" | grep -E 'REFUSED|REJECTED|LAND ok|LAND RED|REFUSE' | tail -5
    f="$(grep -m1 '^LAND ok ' "$log")"
    n="$(printf '%s' "$f" | sed -n 's/.* retried_push=\([0-9]*\) .*/\1/p')"; b="$(printf '%s' "$f" | sed -n 's/.* rebased_for_refusal=\([0-9]*\) .*/\1/p')"
    m="$(printf '%s' "$f" | sed -n 's/.* origin_moved_rebases=\([0-9]*\) .*/\1/p')"
    [ "$rc" = 0 ] && [ -e "$T/planted" ] && [ ! -e "$T/refuse_once" ] && grep -q '^LAND stage=push:corpus REFUSED by the server' "$log" \
        && git -C "$T/origin/corpus.git" log --format=%s main | grep -x "probe: a racer lands before the refusal" > /dev/null \
        && [ "$(git -C "$T/origin/corpus.git" rev-parse main)" = "$(git -C "$T/work/corpus" rev-parse HEAD)" ] \
        || { echo "LAND push-refusal probe RED rc=$rc (the plant ran: $([ -e "$T/planted" ] && echo yes || echo no); the hook fired: $([ -e "$T/refuse_once" ] && echo no || echo yes)); log kept: $log"; trap - EXIT; exit 1; }
    echo "LAND push_refused=server retried_push=${n:-0} rebased_for_refusal=${b:-?} origin_moved_rebases=${m:-0}"
    exit 0
}
probe_serial() {   # the serial last round's proof (fleet-queue step 20), on scratch origins: a racer lands on corpus in each of three rounds (round two outside the row's TOUCHES, so round three's regate stands), round three's refused push takes ONE serial gate under the lease, and a second lander queued behind that lease lands once it is free
    local T r log rc n g h i m
    T="$(mktemp -d "/tmp/s4e/$seat/land-serial-probe.XXXXXX")" || refuse "cannot make a scratch directory"
    trap 'rm -rf "$T" "/tmp/s4e/$seat/land.$(printf "%s" "$T/work" | sha1sum | cut -c1-12).lock"' EXIT
    red9() { echo "LAND serial-probe RED: $*"; echo "    kept: $T"; trap - EXIT; exit 1; }
    scratch_clone "$T"
    git clone -q --shared --no-checkout "$T/origin/corpus.git" "$T/racer" && git -C "$T/racer" sparse-checkout set --cone tests/probe_race tests/probe9 && git -C "$T/racer" reset -q --hard HEAD \
        || refuse "probe: cannot clone the racer"
    git -C "$T/racer" config user.name LCherryholmes; git -C "$T/racer" config user.email lcherryh@yahoo.com
    mkdir -p "$T/waiter"
    for r in "${ORDER[@]}"; do
        if [ "$r" = corpus ]; then git clone -q --shared --no-checkout "$T/origin/$r.git" "$T/waiter/$r" && git -C "$T/waiter/$r" sparse-checkout set --cone tests/probe_race && git -C "$T/waiter/$r" reset -q --hard HEAD
        else git clone -q --shared "$T/origin/$r.git" "$T/waiter/$r"; fi || refuse "probe: cannot clone the waiter's $r"
        git -C "$T/waiter/$r" config user.name LCherryholmes; git -C "$T/waiter/$r" config user.email lcherryh@yahoo.com
    done
    git -C "$T/waiter/corpus" commit -q --allow-empty -m "probe: the waiter's commit in corpus" || refuse "probe: cannot commit the waiter"
    for r in "${ORDER[@]}"; do git -C "$T/work/$r" commit -q --allow-empty -m "probe: the serial landing's own commit in $r" || refuse "probe: cannot commit in $r"; done
    : > "$T/plants"; : > "$T/gates9"
    cat > "$T/plant9.sh" <<'PLANT'
#!/usr/bin/env bash
T="$(cd "$(dirname "$0")" && pwd)"
echo p >> "$T/plants"
n="$(wc -l < "$T/plants")"
d=tests/probe_race; [ "$n" = 2 ] && d=tests/probe9
cd "$T/racer" && git pull -q --rebase origin main && mkdir -p "$d" && echo "probe9 run $n" > "$d/probe9-$n.txt" && git add -A && git commit -q -m "probe: a serial racer lands probe9-$n" && git push -q origin HEAD:main
PLANT
    cat > "$T/gate9.sh" <<'GATE'
#!/usr/bin/env bash
T="$(cd "$(dirname "$0")" && pwd)"
echo g >> "$T/gates9"
n="$(wc -l < "$T/gates9")"
if [ "$n" = 3 ]; then
    env -u S4E_LAND_PLANT S4E_SEAT=probe-waiter bash "$1" --push --proved 'probe: the waiter lands behind the serial round' --home "$T/waiter" corpus > "$T/waiter.log" 2>&1 7>&- 8>&- 9>&- &
    for i in $(seq 1 600); do grep -q '^LAND stage=lease waiting' "$T/waiter.log" 2>/dev/null && break; sleep 0.1; done
    grep -q '^LAND stage=lease waiting' "$T/waiter.log" 2>/dev/null || { echo "probe: the waiter never queued behind the serial gate" >&2; exit 1; }
fi
exit 0
GATE
    log="$T/serial.log"
    S4E_LAND_PLANT="bash $T/plant9.sh" S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" bash "$SELF" --home "$T/work" --tries 3 --touches 'corpus/tests/probe_race' --gate "bash $T/gate9.sh $SELF" > "$log" 2>&1; rc=$?
    sed 's/^/    serial| /' "$log" | grep -E 'regate|LAND ok|LAND RED|REFUSE|lease' | tail -12
    if [ "$rc" = 0 ]; then for i in $(seq 1 3000); do grep -q '^LAND \(ok\|RED\|REFUSE\)' "$T/waiter.log" 2>/dev/null && break; sleep 0.1; done; fi
    sed 's/^/    waiter| /' "$T/waiter.log" 2>/dev/null | tail -4
    n="$(wc -l < "$T/plants")"; g="$(wc -l < "$T/gates9")"
    h="$(sed -n 's/^LAND stage=lease released held_s=\([0-9]*\) .*/\1/p' "$log" | tail -1)"
    [ "$rc" = 0 ] || red9 "the first lander returned rc=$rc: $(grep -E 'LAND RED|REFUSE' "$log" | tail -1 | cut -c1-200)"
    grep -q '^LAND stage=regate:lease:serial ' "$log" || red9 "no LAND stage=regate:lease:serial: the last round did not gate under the lease"
    grep -q '^LAND ok .* attempts=3 .* serial_round=1 ' "$log" || red9 "the landing did not read attempts=3 serial_round=1: $(grep '^LAND ok' "$log" | cut -c1-200)"
    [ "$n" = 3 ] || red9 "the racer ran $n times, expected 3 (one per round)"
    [ "$g" = 3 ] || red9 "the gate ran $g times, expected 3 (attempt 1, regate 2, the serial gate)"
    [ -n "$h" ] || red9 "no LAND stage=lease released held_s= line"
    grep -q "^LAND stage=lease waiting: held by seat=$seat " "$T/waiter.log" 2>/dev/null || red9 "the waiter did not queue behind seat=$seat: $(head -n 1 "$T/waiter.log" 2>/dev/null | cut -c1-160)"
    grep -q '^LAND ok mode=push .*pushed=corpus@' "$T/waiter.log" 2>/dev/null || red9 "the waiter did not land after the lease: $(grep -E 'LAND (ok|RED|REFUSE)' "$T/waiter.log" 2>/dev/null | tail -1 | cut -c1-200)"
    git -C "$T/origin/corpus.git" log --format=%s main > "$T/corpus.log"
    for m in "probe: a serial racer lands probe9-1" "probe: a serial racer lands probe9-2" "probe: a serial racer lands probe9-3" "probe: the serial landing's own commit in corpus" "probe: the waiter's commit in corpus"; do grep -qx "$m" "$T/corpus.log" || red9 "origin corpus lost: $m"; done
    echo "LAND serial-probe ok attempts=3 serial_round=1 regate=lease:serial held_s=$h landed=1 waiter_named=1"
    exit 0
}
tokpids() { local e p; for e in /proc/[0-9]*/environ; do p="${e#/proc/}"; p="${p%/environ}"; grep -qxzF "S4E_ORPHAN_PROBE=$1" "$e" 2>/dev/null && echo "$p"; done; }   # the live processes that carry the first landing's environment token (a zombie's environ reads empty)
probe_orphan_lock() {   # a stopped lander leaves nothing behind (row fleet-land-a-lander-stopped-mid-build-leaves-its-make-holding-the-landing-lock), on scratch origins: a landing whose gate starts
    # a 120 s child is sent TERM once that gate has started; after it has exited (an order of events, never a clock) no process carrying its environment token remains, the gate's own
    # descriptors named neither lock, and a second landing from the same home takes the per-root lock (flock -n, so a held lock refuses at once) and lands
    local T rc rc2 first n left fds r second tok kept
    T="$(mktemp -d "/tmp/s4e/$seat/land-orphan.XXXXXX")" || refuse "cannot make a scratch directory"
    tok="orphan-lock-$$-${T##*.}"
    trap 'for p in $(tokpids "$tok"); do kill -KILL "$p" 2>/dev/null; done; rm -rf "$T" "/tmp/s4e/$seat/land.$(printf "%s" "$T/work" | sha1sum | cut -c1-12).lock"' EXIT
    scratch_clone "$T"
    for r in "${ORDER[@]}"; do git -C "$T/work/$r" commit -q --allow-empty -m "probe: the stopped landing's commit in $r" || refuse "probe: cannot commit in $r"; done
    S4E_ORPHAN_PROBE="$tok" S4E_SEM_HOME="$T/sem" S4E_POSTOFFICE="$T/po" S4E_POST="$T/po" S4E_SEAT="$seat" bash "$SELF" --home "$T/work" \
        --gate "ls -l /proc/\$\$/fd > $T/fds1 2>&1; : > $T/started1; sleep 120; echo 'probe: the gate outlived its stop'" > "$T/first.log" 2>&1 < /dev/null & first=$!
    while [ ! -e "$T/started1" ] && kill -0 "$first" 2>/dev/null; do sleep 1; done
    [ -e "$T/started1" ] || { sed 's/^/    first| /' "$T/first.log" | tail -8; refuse "probe: the first landing exited before its gate started"; }
    kill -TERM "$first"; wait "$first"; rc=$?
    sed 's/^/    first| /' "$T/first.log" | tail -2
    kept="$(sed -n 's/^LAND logs kept: //p' "$T/first.log" | tail -1)"; case "$kept" in "/tmp/s4e/$seat"/land.*) rm -rf "$kept" ;; esac   # the stopped landing keeps its log directory; the probe leaves nothing behind
    left="$(tokpids "$tok" | tr '\n' ' ')"; n="$(printf '%s' "$left" | wc -w)"
    fds="$(grep -oE '/tmp/s4e/[^ ]*/land\.[0-9a-f]{12}\.lock|[^ ]*/\.land\.lease' "$T/fds1" | sort -u | tr '\n' ' ')"
    S4E_SEM_HOME="$T/sem" S4E_POSTOFFICE="$T/po" S4E_POST="$T/po" S4E_SEAT="$seat" bash "$SELF" --home "$T/work" --gate 'true' > "$T/second.log" 2>&1 < /dev/null; rc2=$?
    sed 's/^/    second| /' "$T/second.log" | grep -E 'REFUSE|LAND ok|LAND RED' | tail -2
    second=refused
    if [ "$rc2" = 0 ]; then second=landed
        for r in "${ORDER[@]}"; do git -C "$T/origin/$r.git" log --format=%s main | grep -x "probe: the stopped landing's commit in $r" > /dev/null || second=unlanded; done; fi
    echo "    first| rc=$rc after TERM; orphans: ${left:-none}"
    [ -n "$fds" ] && { echo "LAND probe-orphan-lock second=$second orphans=$n inherited=${fds% }"; exit 1; }
    echo "LAND probe-orphan-lock second=$second orphans=$n"
    [ "$second" = landed ] && [ "$n" = 0 ] && exit 0
    exit 1
}
probe_land_class() {   # the land class guards the build only (row bus-land-the-lander-holds-no-class-across-its-gate-the-land-class-guards-the-build-only-cio-136): on scratch origins a landing runs its gate with no land-class holder and with S4E_ADMITTED unset in the gate's environment; mail that arrives during the gate does not refuse the landing (the CIO's second defect)
    local T gate n a rc mail
    T="$(mktemp -d "/tmp/s4e/$seat/land-class.XXXXXX")" || refuse "cannot make a scratch directory"
    trap 'rm -rf "$T"' EXIT
    scratch_clone "$T"
    for r in "${ORDER[@]}"; do git -C "$T/work/$r" commit -q --allow-empty -m "probe: the land-class commit in $r" || refuse "probe: cannot commit in $r"; done
    gate="n=\$(ls \"$T/sem/semaphores\" 2>/dev/null | grep -c s4e-land); a=\${S4E_ADMITTED:+set}; echo \"\${n:-0} \${a:-unset}\" > \"$T/gate.out\"; mkdir -p \"$T/po/$seat/inbox\"; printf 'FROM coo TO %s RE probe-mail-after-preflight\nbody\n' \"$seat\" > \"$T/po/$seat/inbox/9-mail-after-preflight.msg\"; echo 'probe: gate ran'"
    env -u S4E_ADMITTED -u S4E_LAND_UNADMITTED S4E_SEM_HOME="$T/sem" S4E_POSTOFFICE="$T/po" S4E_POST="$T/po" S4E_SEAT="$seat" bash "$SELF" --home "$T/work" --gate "$gate" > "$T/land.log" 2>&1 < /dev/null; rc=$?
    read -r n a < "$T/gate.out" 2>/dev/null || { n=none; a=none; }
    mail=refused; [ "$rc" = 0 ] && grep -q '^LAND ok ' "$T/land.log" && mail=landed
    if [ "$rc" = 0 ] && grep -q '^LAND ok ' "$T/land.log" && [ "$n" = 0 ] && [ "$a" = unset ] && [ "$mail" = landed ]; then
        echo "LAND_CLASS_PROBE ok held_at_gate=$n gate_admitted=$a mail_after_preflight=$mail"; exit 0
    fi
    sed 's/^/    land| /' "$T/land.log" | tail -4
    echo "LAND_CLASS_PROBE red held_at_gate=$n gate_admitted=$a mail_after_preflight=$mail"; exit 1
}
mail_guard() {   # ⛔ A STOP ORDER LANDS BEFORE THE LANDING (fleet-bus; the cio's ruling on row bus-the-unread-banner-names-an-old-message): rc 2 while seat $2 holds unread mail under PO $1 newer than its claim $3 (any unread mail when there is no claim); a message listed in the seat's .last-check was displayed by check, so it is read
    local po="$1" sd="$2" claim="$3" f b names=""
    for f in "$po/$sd/inbox"/*.msg; do [ -f "$f" ] || continue; b="$(basename "$f")"
        grep -qxF "$b" "$po/$sd/.last-check" 2>/dev/null && continue
        if [ -n "$claim" ] && [ -f "$claim" ]; then [ "$f" -nt "$claim" ] || continue; fi
        names="$names $b"; done
    [ -z "$names" ] && return 0
    echo "REFUSE(2): unread mail newer than your claim:$names; read it (bash harness/scripts/s4e_msg.sh check) before landing, or S4E_LAND_IGNORE_MAIL=\"why\" is loud and goes into the baton LEDGER" >&2
    return 2; }
probe_mail() {   # the mail guard's proof on scratch (row bus-the-unread-banner-names-an-old-message): (a) unread mail newer than the claim refuses; (b) after check reads it the guard passes; (c) the hook names no message check has read, and after a new arrival names only that arrival
    local sc="/tmp/s4e/${S4E_SEAT:-worker}/land-mail.$$" po me=probe-mail rf=0 rp=0 rb=0 h1 h2
    po="$sc/po"; mkdir -p "$po/$me/inbox" "$po/claims" || return 2
    printf '# probe\n' > "$po/MODE"; printf 'claim\n' > "$po/claims/t-mail.claim"; touch -d @1000000000 "$po/claims/t-mail.claim"
    printf 'FROM coo TO %s RE m1-stop-order\nbody\n' "$me" > "$po/$me/inbox/1-m1.msg"; touch -d @2000000000 "$po/$me/inbox/1-m1.msg"
    mail_guard "$po" "$me" "$po/claims/t-mail.claim" 2>/dev/null || rf=1
    S4E_POST="$po" S4E_SEAT="$me" S4E_NO_BANNER=1 bash "$HERE/s4e_msg.sh" check > /dev/null 2>&1
    mail_guard "$po" "$me" "$po/claims/t-mail.claim" 2>/dev/null && rp=1
    h1="$(S4E_HOME="$sc/noharness" S4E_POST="$po" S4E_SEAT="$me" bash "$HERE/s4e_inbox_hook.sh" 2>/dev/null)"
    printf 'FROM coo TO %s RE m2-new-arrival\nbody\n' "$me" > "$po/$me/inbox/2-m2.msg"; touch -d @2000000100 "$po/$me/inbox/2-m2.msg"
    h2="$(S4E_HOME="$sc/noharness" S4E_POST="$po" S4E_SEAT="$me" bash "$HERE/s4e_inbox_hook.sh" 2>/dev/null)"
    if [ "${h1#*RE m1-stop-order}" = "$h1" ] && [ "${h2#*RE m2-new-arrival}" != "$h2" ] && [ "${h2#*RE m1-stop-order}" = "$h2" ]; then rb=1; fi
    rm -rf "$sc"
    printf 'LAND_MAIL unread_newer_refuses=%s read_passes=%s banner_names_new_only=%s\n' "$rf" "$rp" "$rb"
    [ "$rf$rp$rb" = 111 ]; }
probe_rerun() {   # THE PROOF OF LAND.conf's SWITCHES (row the-lander-reruns-a-landing-only-for-what-touches-it), four arms on scratch origins, each a real landing by this lander reading a scratch LAND.conf: (1) touches=derived, tables=affected: a racer lands outside the landing's own directory, the gate stands and runs once, the table stages are skipped, the ledger holds the line; (2) tries=1: a racer lands in the landing's own directory, the one serial gate runs under the lease and no second unleased round; (3) touches=declared: the same race as arm 1 reads affected, the switch off is the lander of before; (4) width=1: with the one place held the landing refuses rc 2 having fetched nothing, and lands once the place is free. Every arm reads an order of events, never a clock.
    local T log rc h
    T="$(mktemp -d "/tmp/s4e/$seat/land-rerun.XXXXXX")" || refuse "cannot make a scratch directory"
    trap 'rm -rf "$T" "/tmp/s4e/$seat/land.$(printf "%s" "$T/work" | sha1sum | cut -c1-12).lock"' EXIT
    rr() { echo "LAND rerun-probe RED: $*"; echo "    kept: $T"; trap - EXIT; exit 1; }
    scratch_clone "$T"
    git clone -q --shared --no-checkout "$T/origin/corpus.git" "$T/racer" && git -C "$T/racer" sparse-checkout set --cone tests/probe_race && git -C "$T/racer" reset -q --hard HEAD || refuse "probe: cannot clone the racer"
    git -C "$T/racer" config user.name LCherryholmes; git -C "$T/racer" config user.email lcherryh@yahoo.com
    racer() {   # racer <script> <marker> <file>: inside the gate, once, land a file under corpus/tests/probe_race on the scratch origin
        printf '#!/usr/bin/env bash\n[ -e "%s" ] && exit 0\n: > "%s"\ncd "%s" && git pull -q --rebase origin main' "$T/$2" "$T/$2" "$T/racer" > "$T/$1"
        printf ' && mkdir -p tests/probe_race && echo race > "tests/probe_race/%s" && git add -A && git commit -q -m "probe: a racer lands %s" && git push -q origin HEAD:main\n' "$3" "$3" >> "$T/$1"; }
    own_change() {   # own_change <repo> <path>: the landing's own commit changes one file
        mkdir -p "$(dirname "$T/work/$1/$2")" && echo own > "$T/work/$1/$2" && git -C "$T/work/$1" add -A && git -C "$T/work/$1" commit -q -m "probe: the landing changes $1/$2" || refuse "probe: cannot commit $1/$2"; }
    lander() { S4E_LAND_UNADMITTED=1 S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" bash "$SELF" --home "$T/work" "$@"; }   # the scratch landing's build takes no place of the live land class
    printf 'tries=1\ntouches=derived\ntables=affected\nwidth=2\n' > "$T/po/LAND.conf"
    racer race1.sh raced1 "probe-rerun1-$$.txt"; own_change harness "probe_own/a-$$.txt"; log="$T/arm1.log"
    lander --gate "echo g >> $T/gates1 && bash $T/race1.sh" > "$log" 2>&1; rc=$?
    sed 's/^/    arm1| /' "$log" | grep -E 'touches|regenerate|regate|line|LAND ok|LAND RED|REFUSE' | cut -c1-220 | tail -7
    [ "$rc" = 0 ] && grep "^LAND touches derived from the landing's own diff: harness/probe_own\$" "$log" > /dev/null && grep '^LAND stage=regenerate skipped' "$log" > /dev/null \
        && grep '^LAND stage=regate:lease reason=unaffected files=1' "$log" > /dev/null && grep '^LAND stage=line place=' "$log" > /dev/null && [ "$(wc -l < "$T/gates1")" = 1 ] \
        || rr "arm 1 (a race outside the landing's own directory) rc=$rc: expected derived touches, the table stages skipped, regate:lease unaffected and one gate run, got $(wc -l < "$T/gates1" 2>/dev/null) run(s)"
    grep -c "	ok	1	" "$T/po/LANDINGS.tsv" > "$T/led1" 2>/dev/null; [ "$(cat "$T/led1")" = 1 ] || rr "arm 1 left no ok line of one attempt in the ledger $T/po/LANDINGS.tsv"
    racer race2.sh raced2 "probe-rerun2-$$.txt"; own_change corpus "tests/probe_race/own2-$$.txt"; log="$T/arm2.log"
    lander --gate "echo g >> $T/gates2 && bash $T/race2.sh" > "$log" 2>&1; rc=$?
    sed 's/^/    arm2| /' "$log" | grep -E 'touches|regate|LAND ok|LAND RED|REFUSE' | cut -c1-220 | tail -5
    [ "$rc" = 0 ] && grep '^LAND stage=regate:lease:serial reason=affected files=1' "$log" > /dev/null && grep '^LAND ok .* attempts=1 .* serial_round=1 ' "$log" > /dev/null \
        && ! grep '^LAND stage=regate:2' "$log" > /dev/null && [ "$(wc -l < "$T/gates2")" = 2 ] \
        || rr "arm 2 (a race in the landing's own directory, tries=1) rc=$rc: expected the one serial gate under the lease, attempts=1 and two gate runs, got $(wc -l < "$T/gates2" 2>/dev/null) run(s)"
    printf 'touches=declared\ntables=affected\n' > "$T/po/LAND.conf"
    racer race3.sh raced3 "probe-rerun3-$$.txt"; own_change harness "probe_own/c-$$.txt"; log="$T/arm3.log"
    lander --gate "echo g >> $T/gates3 && bash $T/race3.sh" > "$log" 2>&1; rc=$?
    sed 's/^/    arm3| /' "$log" | grep -E 'touches|regate|LAND ok|LAND RED|REFUSE' | cut -c1-220 | tail -5
    [ "$rc" = 0 ] && grep '^LAND stage=regate:2 reason=affected files=1' "$log" > /dev/null && ! grep '^LAND touches derived' "$log" > /dev/null && [ "$(wc -l < "$T/gates3")" = 2 ] \
        || rr "arm 3 (touches=declared, the switch off) rc=$rc: expected regate:2 affected, nothing derived and two gate runs, got $(wc -l < "$T/gates3" 2>/dev/null) run(s)"
    printf 'tries=1\ntouches=derived\ntables=affected\nwidth=1\nline_wait=2\n' > "$T/po/LAND.conf"
    ( exec 7>> "$T/po/.land.line.1"; flock 7; : > "$T/held"; sleep 600 ) & h=$!
    while [ ! -e "$T/held" ]; do sleep 0.2; done
    own_change harness "probe_own/d-$$.txt"; log="$T/arm4.log"; was="$(git -C "$T/origin/harness.git" rev-parse main)"
    lander --gate "echo g >> $T/gates4" > "$log" 2>&1; rc=$?
    sed 's/^/    arm4| /' "$log" | grep -E 'line|LAND ok|LAND RED|REFUSE' | cut -c1-220 | tail -4
    kill "$h" 2>/dev/null; wait "$h" 2>/dev/null
    [ "$rc" = 2 ] && grep '^LAND stage=line waiting' "$log" > /dev/null && grep '^LAND REFUSE(2) the landing line is still full' "$log" > /dev/null && ! grep '^LAND stage=fetch' "$log" > /dev/null \
        && [ ! -e "$T/gates4" ] && [ "$(git -C "$T/origin/harness.git" rev-parse main)" = "$was" ] \
        || rr "arm 4 (the one place held) rc=$rc: expected the wait, then the refusal rc 2 with nothing fetched, no gate run and nothing pushed"
    log="$T/arm4b.log"
    lander --gate "echo g >> $T/gates4" > "$log" 2>&1; rc=$?
    [ "$rc" = 0 ] && grep '^LAND stage=line place=1 of 1' "$log" > /dev/null && [ "$(wc -l < "$T/gates4")" = 1 ] && [ "$(git -C "$T/origin/harness.git" rev-parse main)" != "$was" ] \
        || rr "arm 4 (the place free) rc=$rc: expected the place taken and the landing on origin"
    echo "LAND rerun-probe ok arms=4 ledger_lines=$(grep -vc '^#' "$T/po/LANDINGS.tsv") (derived touches kept a gate standing over a race outside the landing's directory and skipped the table stages; tries=1 ran the one serial gate under the lease over a race inside it; touches=declared read the same race affected; width=1 held a landing out with nothing fetched and admitted it once the place was free)"
    exit 0
}
[ "$mode" = probe ] && probe
[ "$mode" = probe_mail ] && { probe_mail; exit $?; }
[ "$mode" = probe_push_refusal ] && probe_push_refusal
probe_root_home() {   # A SEAT LANDS FROM ITS OWN ROOT (row harness-a-worktree-is-scrip-alone-everything-else-from-the-seats-root, recut on Lon's word 2026-11-13 17:4x CST), on a scratch root and scratch origins: (1) an edit committed in the root's corpus while origin moved lands from the root itself: the gate reads the root with the edit, the root's own commit is rebased onto origin and pushed, and the root ends clean at origin; (2) the sync keeps a seat's work: a local commit in harness and a tracked edit in .github stand where they were, named KEPT, with nothing stashed or reset, while the clean corpus fast-forwards to a moved origin
    local T W log rc why="" h0 g0 f c0 r
    T="$(mktemp -d "/tmp/s4e/$seat/land-root-home-probe.XXXXXX")" || refuse "cannot make a scratch directory"
    trap 'rm -rf "$T" "/tmp/s4e/$seat/land.$(printf "%s" "$T/work" | sha1sum | cut -c1-12).lock"' EXIT
    scratch_clone "$T"; W="$T/work"; f="tests/probe_race/root-home-$$.txt"
    mkdir -p "$W/corpus/tests/probe_race" && echo "an edit in the root" > "$W/corpus/$f" && git -C "$W/corpus" add "$f" && git -C "$W/corpus" commit -q -m "probe: an edit in the seat's root" || refuse "root-home-probe: cannot edit the scratch root"
    advance "$T/origin/corpus.git" "probe: origin moved under the root"
    log="$T/arm1.log"
    S4E_POSTOFFICE="$T/po" S4E_SEAT="$seat" bash "$SELF" --home "$W" --gate "[ \"\$S4E_HOME\" = \"$W\" ] && [ \"\$(pwd -P)\" = \"$(cd "$W" && pwd -P)\" ] && grep -qx 'an edit in the root' corpus/$f" corpus > "$log" 2>&1; rc=$?
    sed 's/^/    arm1| /' "$log" | grep -E 'stage=(preflight|rebase|gate|push|sync)|LAND ok|LAND RED|REFUSE' | cut -c1-200 | tail -8
    [ "$rc" = 0 ] && grep -q '^LAND ok ' "$log" || why="$why arm 1: the landing from the root returned rc=$rc without LAND ok;"
    git -C "$T/origin/corpus.git" log --format=%s main > "$T/corpus.log"   # a file, not a pipe: grep -q under pipefail kills git log
    grep -qx "probe: an edit in the seat's root" "$T/corpus.log" || why="$why arm 1: the root's commit is not on origin;"
    grep -qx "probe: origin moved under the root" "$T/corpus.log" || why="$why arm 1: origin lost its own commit;"
    [ "$(git -C "$W/corpus" rev-parse HEAD)" = "$(git -C "$T/origin/corpus.git" rev-parse main)" ] && [ -z "$(git -C "$W/corpus" status --porcelain --untracked-files=no)" ] || why="$why arm 1: the root's corpus is not clean at origin after the landing;"
    echo local > "$W/harness/scripts/probe_local_$$.txt" && git -C "$W/harness" add "scripts/probe_local_$$.txt" && git -C "$W/harness" commit -q -m "probe: a local commit in the root" || refuse "root-home-probe: cannot commit in the scratch root's harness"
    g0="$(git -C "$W/.github" ls-files | head -1)"; [ -n "$g0" ] && echo "a tracked edit in the root" >> "$W/.github/$g0" || refuse "root-home-probe: no tracked file in the scratch .github"
    h0="$(git -C "$W/harness" rev-parse HEAD)"; c0="$(git -C "$W/.github" rev-parse HEAD)"
    for r in harness .github corpus; do advance "$T/origin/$r.git" "probe: origin moved under the sync"; done
    log="$T/arm2.log"
    S4E_HOME="$W" S4E_SYNC_REPOS="harness .github corpus" bash "$HERE/util_sync_root.sh" > "$log" 2>&1; rc=$?
    sed 's/^/    arm2| /' "$log" | cut -c1-200
    [ "$rc" = 0 ] && grep -q '^SYNC harness .* KEPT: 1 local commit' "$log" && grep -q '^SYNC \.github .* KEPT: 0 local commit(s), 1 edited file' "$log" || why="$why arm 2: the sync rc=$rc did not name harness and .github KEPT;"
    [ "$(git -C "$W/harness" rev-parse HEAD)" = "$h0" ] && [ "$(git -C "$W/.github" rev-parse HEAD)" = "$c0" ] && ! git -C "$W/.github" diff --quiet && [ -z "$(git -C "$W/harness" stash list; git -C "$W/.github" stash list)" ] \
        || why="$why arm 2: the sync moved, stashed or reset the seat's work;"
    [ "$(git -C "$W/corpus" rev-parse HEAD)" = "$(git -C "$W/corpus" rev-parse origin/main)" ] || why="$why arm 2: the clean corpus did not fast-forward to its moved origin;"
    if [ -z "$why" ]; then echo "LAND root-home-probe ok arms=2 (an edit in the root landed from the root, rebased onto a moved origin, the gate reading the root, the root clean at origin after; the sync kept a local commit and a tracked edit, KEPT, nothing stashed or reset, and fast-forwarded the clean repo)"; exit 0; fi
    trap - EXIT; echo "LAND root-home-probe RED:$why"; echo "    kept: $T"; exit 1
}
[ "$mode" = probe_serial ] && probe_serial
[ "$mode" = probe_orphan_lock ] && probe_orphan_lock
[ "$mode" = probe_land_class ] && probe_land_class
[ "$mode" = probe_rerun ] && probe_rerun
[ "$mode" = probe_root_home ] && probe_root_home
[ "$mode" = merge_probe ] && merge_probe
# THE LEASE IS HELD ONLY AROUND THE PUSH (the cio 2026-11-04 20:1x CST, on hq_pascal's 14-minute wait behind hq_unicon's gate and seven landings queued behind
# hq_templates' 35-minute gate): the gate runs UNLEASED on the rebased tree; the lease is taken after it, origin is fetched again under the lease, and if it moved
# the tree is rebased there -- a move under the row's affected set drops the lease and re-runs the gate unleased, a move outside it pushes the rebased tree with the
# gate standing (the merge-queue shape: optimistic gating, serialized pushing). A lease is held for the seconds a fetch, a rebase and four pushes take, never a gate.
lease="${S4E_POSTOFFICE:-/home/resources/postoffice}/.land.lease"; lw="${S4E_LAND_LEASE_WAIT:-1800}"; lease_since=0
{ exec 8>> "$lease"; } 2>/dev/null || refuse "cannot open the landing lease $lease"   # the 2>/dev/null is scoped to the group: a bare `exec 8>>f 2>/dev/null` silenced the lander's stderr for the rest of the run (every REFUSE after it, the mail guard's first) -- the "silent rc 2 after preflight" of 2026-11-07, found 15:2x
# BOSSES DO NOT WAIT FOR PUSH LEASES (Lon 2026-11-13 16:3x CST, in the coo's window, verbatim: "Excuse me, BOSSES do not wait for PUSH LEASES."; MEASURED in
# LANDINGS.tsv the same hour: the cto's landing waited about 1650 s of its 2158 behind about fifteen worker landers, and the cio's 22 minutes). A boss is a seat MODE's
# BOSSES: line names, and a boss lander never takes the lease: it fetches, rebases and pushes at once. A worker's push it overtakes is rejected like any push
# outside the lease and goes round again from fetch, re-gating only for what the boss's commits touch (the affected set below), so the boss costs a worker a round,
# never a wrong push. A first cut that queued the boss first behind the flock could not beat landers already blocked in flock -w (MEASURED 17:0x: both coo landers
# waited 25 minutes behind cio, senior_05 and officer_02).
lease_boss() { local b; b="$(sed -n 's/^BOSSES: *//p' "${S4E_POSTOFFICE:-/home/resources/postoffice}/MODE" 2>/dev/null | head -1)"; case " $b " in *" $seat "*) return 0 ;; esac; return 1; }
lease_skipped=0
take_lease() {
    if lease_boss; then
        lease_since="$(date +%s)"; lease_skipped=1
        echo "LAND stage=lease skipped: seat $seat is a boss and never waits for the push lease (Lon 2026-11-13); a worker's push it overtakes is rejected and goes round"
        return 0
    fi
    if ! flock -n 8; then
        echo "LAND stage=lease waiting: held by $(tail -1 "$lease" 2>/dev/null | cut -c1-120); the lease serializes the pushes box-wide, never a gate (box-scheduler step 18; up to $lw s)"
        flock -w "$lw" 8 || refuse "the landing lease is still held after $lw s by $(tail -1 "$lease" 2>/dev/null | cut -c1-120): the gate ran, nothing pushed; run the landing again"
    fi
    lease_since="$(date +%s)"
    printf 'seat=%s pid=%s row=%s since=%s\n' "$seat" "$$" "${row:-gate}" "$(date -u +%FT%TZ)" > "$lease"
    echo "LAND stage=lease held seat=$seat pid=$$ after_gate=1 (released after the push)"
}
drop_lease() { if [ "$lease_skipped" = 1 ]; then lease_skipped=0; echo "LAND stage=lease released held_s=0 (a boss holds no lease) $1"; return 0; fi; printf 'free: released by seat=%s pid=%s at %s\n' "$seat" "$$" "$(date -u +%FT%TZ)" > "$lease"; flock -u 8; echo "LAND stage=lease released held_s=$(( $(date +%s) - lease_since )) $1"; }   # the file names the last holder until the next takes it; a waiter reads free:
LOG="/tmp/s4e/$seat/land.$$"
mkdir -p "$LOG" || refuse "cannot make $LOG"
declare -A stage_done
land_t0="$(date +%s)"; last_mark="$land_t0"; line_waited=0; touches_from=declared; tables_need=1; declare -A stage_secs
mark() { local n b="${1%%:*}"; n="$(date +%s)"; stage_done[$1]=1; stage_secs[$b]=$(( ${stage_secs[$b]:-0} + n - last_mark )); last_mark="$n"; echo "LAND stage=$1 $2"; }   # the seconds since the mark before are this stage's, summed over the rounds
ledger() {   # <outcome>: ONE LINE A LANDING IN THE PROGRESS STORE (the box kept no record of a landing: its rounds were read from the seats' transcripts on 2026-11-13). Written at every end, green, red, refused or stopped; never a reason to fail.
    [ -n "${land_t0:-}" ] || return 0
    local s="" k
    for k in $(printf '%s\n' "${!stage_secs[@]}" | sort); do s="$s$k=${stage_secs[$k]} "; done
    { [ -s "$LEDGER" ] || printf '# at_utc\tseat\trow\toutcome\tattempts\torigin_moved\tserial_round\tseconds\tline_wait_s\tswitches\tstage_seconds  -- one line a landing, written by s4e_land.sh at its end (LAND.conf names the switches)\n'
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$seat" "${row:-gate}" "$1" "${attempt:-1}" "${moved_rounds:-0}" "${serial_round:-0}" "$(( $(date +%s) - land_t0 ))" "${line_waited:-0}" "tries=$tries,touches=$touches_from,tables=$tables_mode,width=$width" "${s% }"; } >> "$LEDGER" 2>/dev/null || true
}
present=()
for r in "${ORDER[@]}"; do [ -e "$home/$r/.git" ] && present+=("$r"); done
for r in SCRIP harness corpus; do [ -e "$home/$r/.git" ] || refuse "no $home/$r: a landing builds SCRIP beside harness and corpus"; done
own_files() {   # the files the landing's own commits change, "repo/path" a line, read against the merge base so a stale origin/main reads the same
    local r f
    for r in "${present[@]}"; do
        while IFS= read -r f; do [ -n "$f" ] && printf '%s/%s\n' "$r" "$f"; done < <(command git -C "$home/$r" diff --name-only origin/main...HEAD 2>/dev/null)
    done
}
own="$(own_files)"
if [ -z "$touches" ] && [ "$touches_mode" = derived ]; then   # THE LANDING'S OWN DIFF NAMES ITS POPULATION (LAND.conf touches=derived): the directory of each file it changes, a file at a repo's top being its own prefix; a path with a blank derives nothing, and with nothing derived every moved file is a hit, as before. The shared layers stay a hit in affected_since whatever is derived.
    touches="$(printf '%s\n' "$own" | awk 'NF == 0 { next } /[[:space:]]/ { bad = 1 } { n = split($0, a, "/"); if (n > 2) sub(/\/[^\/]*$/, ""); d[$0] = 1 } END { if (bad) exit; for (k in d) printf "%s ", k }')"
    touches="${touches% }"
    [ -n "$touches" ] && { touches_from=derived; echo "LAND touches derived from the landing's own diff: $touches"; }
fi
if [ "$tables_mode" = affected ]; then   # A TABLE IS REGENERATED BY THE LANDING THAT CHANGES WHAT IT IS MADE FROM (LAND.conf tables=affected): every generator reads SCRIP's sources or its own script and registry, each SCRIP landing checks them all, so a landing with none of those in its own diff finds origin's tables as origin's last SCRIP landing left them
    tables_need=0
    printf '%s\n' "$own" | grep -E '^(SCRIP/|harness/scripts/(util_gen_[^/]*|generated_tables\.tsv|rt_entries\.tsv|lib_parser_generated_in_sync\.sh|regenerate_parser_and_lexer_from_sources\.sh)$)' > /dev/null && tables_need=1
fi
take_line() {   # THE LANDING LINE (LAND.conf width=N; Lon's go 2026-11-13 on the coo's proposal: "Waiting landers run nothing."): N places, each a lock file in the postoffice held on fd 7 for the life of this process, taken before the first fetch; a landing that finds every place taken has run nothing and waits, and refuses rc 2 after line_wait s. A killed lander's place frees with its process; no child holds fd 7.
    [ "$width" -gt 0 ] || return 0
    [ "$mode" = push ] && return 0
    local i t0 said=0; t0="$(date +%s)"
    while :; do
        for i in $(seq 1 "$width"); do
            { exec 7>> "$PO_LAND/.land.line.$i"; } 2>/dev/null || refuse "cannot open the landing line $PO_LAND/.land.line.$i"
            if flock -n 7; then
                printf 'seat=%s pid=%s row=%s since=%s\n' "$seat" "$$" "${row:-gate}" "$(date -u +%FT%TZ)" > "$PO_LAND/.land.line.$i"
                line_waited=$(( $(date +%s) - t0 )); mark line "place=$i of $width waited_s=$line_waited"; return 0
            fi
            exec 7>&-
        done
        [ "$said" = 0 ] && { said=1; echo "LAND stage=line waiting: $width landing(s) run at once and every place is taken ($(cat "$PO_LAND"/.land.line.* 2>/dev/null | cut -d' ' -f1,3 | tr '\n' ';' | cut -c1-200)); this landing has run nothing and waits up to $line_wait s (LAND.conf width, line_wait)"; }
        [ $(( $(date +%s) - t0 )) -ge "$line_wait" ] && refuse "the landing line is still full after $line_wait s: nothing ran, nothing pushed; run the landing again"
        sleep "$(( 2 + RANDOM % 4 ))"
    done
}
[ -f "$TSV" ] || refuse "no registry at $TSV"
exec 9> "/tmp/s4e/$seat/land.$(printf '%s' "$home" | sha1sum | cut -c1-12).lock"
flock -n 9 || refuse "another landing holds $home"
git() { command git "$@" 7>&- 8>&- 9>&-; }   # NO CHILD HOLDS A LOCK (row fleet-land-a-lander-stopped-mid-build-leaves-its-make-holding-the-landing-lock): every child runs with the lease (fd 8) and the per-root lock (fd 9) closed, so both locks close with this process; --probe-orphan-lock proves it
kid=0
spawn() {   # <log> <dir> <cmd...>: a long child (the build, a gate) in its own session, waited on so a stop's trap runs at once; it holds neither lock
    local log="$1" dir="$2" rc; shift 2
    ( cd "$dir" && exec setsid --wait "$@" ) > "$log" 2>&1 < /dev/null 7>&- 8>&- 9>&- & kid=$!
    wait "$kid"; rc=$?; kid=0; return "$rc"
}
mine_live() {   # the live processes this lander started: its process tree (this enumeration pruned) and the session of a spawned child
    local me="$BASHPID"   # read before the pipeline: inside it each element is its own fork, and this subshell is the parent of both to prune
    ps -e -o pid=,ppid=,sid=,stat= 2>/dev/null | awk -v root=$$ -v skip="$me" -v sid="$kid" '{ pp[$1] = $2; sd[$1] = $3; st[$1] = $4 }
        END { n = 1; q[1] = root; m[root] = 1
              for (h = 1; h <= n; h++) for (i in pp) if (pp[i] == q[h] && !(i in m) && i != skip) { m[i] = 1; q[++n] = i }
              for (i in st) if (st[i] !~ /^Z/ && i != root && i != skip && ((i in m) || (sid > 0 && sd[i] == sid))) print i }'
}
stop_lander() {   # <signal>: a stopped lander takes its children with it (TERM, KILL after five seconds) and refuses; nothing is left holding a lock or running a build
    local left i=0 how=TERM
    trap '' TERM INT HUP
    left="$(mine_live)"; [ -n "$left" ] && kill -TERM $left 2>/dev/null
    while left="$(mine_live)"; [ -n "$left" ] && [ "$i" -lt 10 ]; do sleep 0.5; i=$((i + 1)); done
    if [ -n "$left" ]; then how="TERM, then KILL"; kill -KILL $left 2>/dev/null; i=0
        while left="$(mine_live)"; [ -n "$left" ] && [ "$i" -lt 10 ]; do sleep 0.2; i=$((i + 1)); done; fi
    [ "$kid" -gt 0 ] && wait "$kid" 2>/dev/null
    ledger stopped; echo "LAND REFUSE(2) stopped by $1: its children were stopped with it ($how; left: ${left:-none}); pushed so far: ${pushed[*]:-none}"
    [ -n "${LOG:-}" ] && echo "LAND logs kept: $LOG"
    exit 2
}
trap 'stop_lander TERM' TERM; trap 'stop_lander INT' INT; trap 'stop_lander HUP' HUP
g() { local r="$1"; shift; timeout -k 5 180 git -C "$home/$r" "$@" 7>&- 8>&- 9>&-; }
git_state() { local p; p="$(git -C "$home/$1" rev-parse --git-path "$2")"; case "$p" in /*) printf '%s' "$p" ;; *) printf '%s/%s/%s' "$home" "$1" "$p" ;; esac; }   # --git-path answers relative to the repo, and this script runs elsewhere
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
new_gates() {   # <harness dir>: the test_gate_*.sh files the landing's own commits add (from the merge base, so a stale origin/main reads the same; --no-renames, so a rename into the name is an add)
    git -C "$1" diff --no-renames --name-only --diff-filter=A origin/main...HEAD -- 'scripts/test_gate_*.sh' 2>/dev/null
}
ng="$(new_gates "$home/harness" | tr '\n' ' ')"   # NO NEW GATE (Lon 2026-11-12 13:1x CST, verbatim: "I do not want any STINKING GATES."; skill gates-and-witnesses section 0; the coo's ask 17:4x)
[ -z "$ng" ] || refuse "the landing adds ${ng% }: no new gate is written (Lon 2026-11-12: \"I do not want any STINKING GATES.\"; skill gates-and-witnesses section 0); fold the check into the tool it guards as a selftest verb or flag, or prove it with a program graded against its oracle"
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
    local phase="$1" k c w rc ph stale=() pids=()
    written=()
    mapfile -t ks < <(awk -F'\t' -v p="^($phase)\$" '!/^#/ && $1 != "name" && $2 ~ p && !s[$1]++ {print $1}' "$TSV")
    [ "${#ks[@]}" -gt 0 ] || refuse "the registry has no $phase-phase table"
    local present_ks=() sk; skipped=()
    for k in "${ks[@]}"; do if sk="$(absent_repo_of "$k")"; then skipped+=("$k:no-$sk"); else present_ks+=("$k"); fi; done   # a table whose output lives in a repo the home lacks is not this landing's (the cfo and the cqo, 2026-11-04: a three-sibling home refused on the .github tables)
    ks=("${present_ks[@]}")
    [ "${#ks[@]}" -gt 0 ] || { summary="0 checked, 0 stale (skipped ${skipped[*]})"; return 0; }
    for k in "${ks[@]}"; do
        c="$(awk -F'\t' -v k="$k" '!/^#/ && $1 == k {print $4; exit}' "$TSV")"
        ( cd "$home" && S4E_HOME="$home" S4E_RUN_SLOT_HELD=1 timeout -k 5 900 bash "$home/harness/scripts/util_check_cache.sh" "land-$k" -- bash -c "$c" > "$LOG/check.$k" 2>&1; echo $? > "$LOG/check.$k.rc" ) 7>&- 8>&- 9>&- &   # the table checks run on the landing's own admission (class land), no run slot each: 236 run-slot waits of 4413 s by the checks on 2026-11-08 by 10:35 (SLOT_WAITS.tsv), 14 checks three at a time behind a pool of 8 (the cio 10:4x)
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
        ( cd "$home" && timeout -k 5 900 bash -c "$w" ) > "$LOG/write.$k" 2>&1 7>&- 8>&- 9>&- || red "$2" "table=$k write failed: $(tail -1 "$LOG/write.$k")"
        ph="$(awk -F'\t' -v k="$k" '!/^#/ && $1 == k {print $2; exit}' "$TSV")"
        if [ "$ph" = built ] && [ -n "$(git -C "$home/SCRIP" status --porcelain --untracked-files=no -- src 2>/dev/null)" ]; then build derive-recheck; fi
        ( cd "$home" && timeout -k 5 900 bash -c "$c" ) > "$LOG/recheck.$k" 2>&1 7>&- 8>&- 9>&-; rc=$?
        [ "$rc" = 0 ] || { [ "$rc" = 2 ] && red "$2" "the re-check of table $k refused (rc 2): $(head -1 "$LOG/recheck.$k")"; red "$2" "table=$k is still stale after its own write: $(tail -1 "$LOG/recheck.$k")"; }
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
build() {   # THE LAND CLASS GUARDS THE BUILD ONLY (CIO-136): the make alone takes a land slot, with S4E_ADMITTED unset for the make so the Makefile's compile door takes its own slots; the gate, the fetch and the rebase take none
    local -a adm=(bash "$HERE/util_run_slot.sh" --admit land env -u S4E_ADMITTED)
    [ -n "${S4E_LAND_UNADMITTED:-}" ] && adm=(env)
    spawn "$LOG/make.$1.log" "$home/SCRIP" "${adm[@]}" timeout -k 5 1800 make -j8 || red "$1" "make -j8 rc=$?: $(grep -m1 -E 'error|Error' "$LOG/make.$1.log" | cut -c1-200)"
    binfo="$(sed -n 's/^source //p' "$home/SCRIP/out/buildinfo" 2>/dev/null | head -1)"
}
gate_run() {
    local rc
    spawn "$LOG/gate.log" "$home" env S4E_HOME="$home" timeout -k 5 "$gt" bash -c "$gate"; rc=$?
    tail -5 "$LOG/gate.log" | sed 's/^/    gate| /'
    case "$rc" in
        0) mark gate "rc=0 on $(git -C "$home/SCRIP" rev-parse --short=9 HEAD)" ;;
        2) refuse "the gate could not measure (rc 2): nothing pushed" ;;
        124|137) refuse "the gate ran past its $gt s budget: nothing pushed" ;;
        *) red gate "rc=$rc: nothing pushed" ;;
    esac
}
serial_cap="${S4E_LAND_SERIAL_GATE_S:-900}"; serial_round=0
gate_run_serial() {   # <label>: the last round's ONE gate, run UNDER the lease (fleet-queue step 20); capped at S4E_LAND_SERIAL_GATE_S; a gate past the cap drops the lease and reads RED, nothing pushed
    local rc sgt="$gt"
    [ "$sgt" -gt "$serial_cap" ] && sgt="$serial_cap"
    serial_round=1
    spawn "$LOG/gate.log" "$home" env S4E_HOME="$home" timeout -k 5 "$sgt" bash -c "$gate"; rc=$?
    tail -5 "$LOG/gate.log" | sed 's/^/    gate| /'
    case "$rc" in
        0) mark "regate:lease:serial" "$1 (the gate ran under the lease, cap ${sgt}s)" ;;
        2) drop_lease "(the serial gate could not measure)"; refuse "the serial gate could not measure (rc 2) under the lease: nothing pushed" ;;
        124|137) drop_lease "(the serial gate ran past ${serial_cap}s)"; red push "the serial gate ran past its cap: serial_gate=timeout; pushed so far: ${pushed[*]:-none}" ;;
        *) drop_lease "(the serial gate read red)"; red gate "rc=$rc under the lease: nothing pushed" ;;
    esac
}
SERVER_REFUSAL='fatal error in commit_refs|remote rejected[^(]*\(failure\)|internal server error|returned error: 5[0-9][0-9]|HTTP 5[0-9][0-9]|error: 5[0-9][0-9] '
push_retries="${S4E_LAND_PUSH_RETRIES:-4}"; push_backoff="${S4E_LAND_PUSH_BACKOFF:-5}"; server_refusals=0; retried_push=0; rebased_unmoved=0; moved_rounds=0
push_one() {
    local r="$1" mine theirs seen k=0 w
    [ "$(ahead "$r")" -gt 0 ] || { echo "LAND stage=push:$r nothing to push (origin $(git -C "$home/$r" rev-parse --short=9 origin/main))"; return 0; }
    named "$r" || refuse "$r carries commits and is not named"
    mine="$(git -C "$home/$r" rev-parse HEAD)"; seen="$(git -C "$home/$r" rev-parse origin/main)"
    while :; do
        g "$r" push -q origin HEAD:refs/heads/main > "$LOG/push.$r" 2>&1
        theirs="$(g "$r" ls-remote origin refs/heads/main | cut -f1)"
        [ -n "$theirs" ] || red "push:$r" "git ls-remote origin read nothing after the push"
        if [ "$theirs" = "$mine" ]; then
            g "$r" fetch -q origin main > /dev/null 2>&1
            mark "push:$r" "${mine:0:9} verified on origin"
            pushed+=("$r@${mine:0:9}")
            return 0
        fi
        [ "$theirs" = "$seen" ] && grep -qiE "$SERVER_REFUSAL" "$LOG/push.$r" || break
        k=$((k + 1)); server_refusals=$((server_refusals + 1))
        [ "$k" -gt "$push_retries" ] && red "push:$r" "the server refused the push $k times with origin unmoved at ${seen:0:9} ($(grep -m1 -iE "$SERVER_REFUSAL" "$LOG/push.$r" | cut -c1-100)); nothing rebased; land again"
        w=$((push_backoff * k))
        echo "LAND stage=push:$r REFUSED by the server, origin unmoved at ${seen:0:9} ($(grep -m1 -iE "$SERVER_REFUSAL" "$LOG/push.$r" | cut -c1-100)): the push alone is retried in ${w}s, no rebase, no regate (retry $k of $push_retries)"
        retried_push=$((retried_push + 1)); sleep "$w"
    done
    bash "$home/harness/scripts/s4e_push_rejected.sh" "$home/$r" > "$LOG/rejected.$r" 2>&1 7>&- 8>&- 9>&-
    if [ "$theirs" = "$seen" ]; then
        rebased_unmoved=$((rebased_unmoved + 1))
        echo "LAND stage=push:$r REJECTED with origin unmoved at ${seen:0:9}, an unrecognised refusal ($(tail -1 "$LOG/push.$r" | cut -c1-120)); recorded, going round again"
    else
        moved_rounds=$((moved_rounds + 1))
        echo "LAND stage=push:$r REJECTED: origin moved to ${theirs:0:9}, not ${mine:0:9} ($(tail -1 "$LOG/push.$r" | cut -c1-120)); recorded, going round again"
    fi
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
pushes() {   # the pushes in ORDER; rc 3 when one is refused (land_round decides: round again, or on the last round the one serial gate and the pushes once more)
    local r
    for r in "${ORDER[@]}"; do
        [ -e "$home/$r/.git" ] || continue
        push_one "$r" || return 3
    done
    return 0
}
land_round() {   # one attempt: fetch, rebase, (regenerate, build, derive), the gate unleased, then the lease only around a fetch, a rebase and the pushes; rc 3 = go round again
    local r a moved=0 rc
    fetch; rebase
    if [ "$mode" != push ] && [ "$tables_need" = 0 ]; then
        mark regenerate "skipped (LAND.conf tables=affected: the landing changes nothing under SCRIP and no generator, so origin's tables stand)"
        build build; mark build "${binfo:-built}"
    elif [ "$mode" != push ]; then
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
        if a="$(affected_since)"; then
            moved_rounds=$((moved_rounds + 1))
            if [ "$attempt" -ge "$tries" ] && [ "$serial_round" = 0 ]; then [ "$mode" = push ] || { build serial; mark build:serial "${binfo:-built}"; }; gate_run_serial "$a"; note_origins
            else drop_lease "(origin moved under the gate, $a: the gate re-runs unleased)"; return 3; fi
        else
            mark "regate:lease" "$a (the gate stands: origin moved outside the row's population; the rebased tree is pushed)"
            note_origins
        fi
    fi
    [ -n "${S4E_LAND_PLANT:-}" ] && { bash -c "$S4E_LAND_PLANT" > "$LOG/plant" 2>&1 7>&- 8>&- 9>&- || true; }   # the probe's plant: a hand push that lands between the lease's fetch and the push
    pushes; rc=$?
    if [ "$rc" = 3 ] && [ "$attempt" -ge "$tries" ] && [ "$serial_round" = 0 ]; then
        fetch; rebase; [ "$mode" = push ] || { build serial; mark build:serial "${binfo:-built}"; }; gate_run_serial "rebased after a push the origin refused on the last attempt"; note_origins
        pushes; rc=$?
    fi
    [ "$rc" = 3 ] && { drop_lease "(a push was rejected: going round again)"; return 3; }
    drop_lease "(pushed ${pushed[*]:-nothing})"
    return 0
}
if [ "$mode" = land ]; then   # a stop order lands before the landing: unread mail newer than the claim refuses (the bypass is loud, in the LEDGER)
    mpo="${S4E_POSTOFFICE:-${S4E_POST:-/home/resources/postoffice}}"; claim=""; [ -n "$row" ] && claim="$mpo/claims/$row.claim"
    if mail_guard "$mpo" "$seat" "$claim" 2>/dev/null; then :
    elif [ -n "${S4E_LAND_IGNORE_MAIL:-}" ]; then
        echo "LAND over unread mail (S4E_LAND_IGNORE_MAIL): $S4E_LAND_IGNORE_MAIL"
        [ -n "$row" ] && printf -- '- %s LAND over unread mail: %s\n' "$(date -u +%FT%TZ)" "$S4E_LAND_IGNORE_MAIL" >> "$tf"
    else mail_guard "$mpo" "$seat" "$claim" || exit 2; fi
fi
[ "$width" -gt 0 ] && echo "LAND conf tries=$tries touches=$touches_mode tables=$tables_mode width=$width (from $CONF)"
take_line
while :; do
    if land_round; then break; fi
    rejected=$((rejected + 1)); attempt=$((attempt + 1))
    [ "$attempt" -gt "$tries" ] && red push "the origin moved under $tries attempts; pushed so far: ${pushed[*]:-none} serial_round=$serial_round"
done
relink_root() {   # THEN SYNC: a root's shared repos are linked to the pristine again after the landing moved them (never a reason to fail a pushed landing)
    local r rs=()
    for r in corpus harness .github; do [ -e "$home/$r/.git" ] && [ "$(git -C "$home/$r" config --get s4e.shared 2>/dev/null)" = true ] && rs+=("$r"); done
    [ "${#rs[@]}" -gt 0 ] || return 0
    if S4E_HOME="$home" bash "$HERE/util_sync_root.sh" --relink "${rs[@]}" > "$LOG/relink" 2>&1 7>&- 8>&- 9>&-; then mark sync "relinked ${rs[*]} to the pristine: $(grep -oE '(linked|already)=[0-9]+' "$LOG/relink" | tr '\n' ' ')"
    else echo "LAND stage=sync relink rc=$? (pushed all the same; run util_sync_root.sh): $(tail -1 "$LOG/relink" | cut -c1-160)"; fi
}
relink_root
if [ "$mode" = push ]; then
    for x in "${pushed[@]}"; do record_hand_push "${x%@*}" "${x#*@}"; done
    ledger ok; rm -rf "$LOG"; echo "LAND ok mode=push stages=${#stage_done[@]} rounds=$rejected pushed=${pushed[*]:-none} attempts=$attempt hand_push=leased push_refused=$server_refusals retried_push=$retried_push rebased_for_refusal=$rebased_unmoved origin_moved_rebases=$moved_rounds serial_round=$serial_round ($(date -u +%Y-%m-%dT%H:%M:%SZ))"; exit 0
fi
ledger ok; rm -rf "$LOG"
echo "LAND ok stages=${#stage_done[@]} rounds=$rejected pushed=${pushed[*]:-none} attempts=$attempt lease=push-only push_refused=$server_refusals retried_push=$retried_push rebased_for_refusal=$rebased_unmoved origin_moved_rebases=$moved_rounds serial_round=$serial_round ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
exit 0
