#!/usr/bin/env bash
# audit_template_watch.sh — THE WATCH LOOP'S INSTRUMENT (hq_templates, row
# templates-the-watch-loop-a-census-diff-names-every-template-violation-a-landing-adds-by-file-commit-and-seat,
# ceo CEO-1321). Lon 2026-09-27, verbatim: "But it will just run in a loop always looking for seats creating bad
# code so it can scoop it up and fix it."
#
# Given the commit the last tick read (BASE) and the commit this tick reads (HEAD, default HEAD), it censuses the
# whole template population -- src/templates/bb/bb_*.cpp and src/templates/xa/xa_*.cpp, the population
# audit_bb_fixup_rank.sh globs -- AT BOTH COMMITS, and for every file where any rule class rose it names the
# commits of BASE..HEAD that touched the file, the one(s) that RAISED it, with author, subject, the seat, and the
# class deltas of that commit alone.
#
# ⛔ THE CLASSES ARE audit_bb_fixup_file.sh's TWENTY, READ FROM ITS OWN OUTPUT, NEVER A THIRD COPY OF ITS REGEXES.
# That is the census's eighteen plus cv9_param_str and cv10_graph, the two the census omits (the still-binding
# sweep finding "rank TOTAL != per-file TOTAL", measured again 2026-09-27: bb_match_abort.cpp is CLEAN in the
# census and rc 1 per file). A watch counting the census's eighteen would be blind to a landing that adds an
# ir_call_arg( to a template -- the CV10 violation a seat is likeliest to add.
# ⛔ BOTH SIDES ARE COUNTED BY THE AUDIT OF THE TREE THIS SCRIPT LIVES IN, so a landing that edits the audit
# itself cannot masquerade as a template landing: the diff is always one ruler held against two trees.
# ⛔ IT READS COMMITS, NEVER THE WORKING TREE: a tick measures what landed, and uncommitted edits did not land.
# ⭐ A FILE WHOSE TOTAL FELL WHILE ONE CLASS ROSE IS STILL A FILE THAT GAINED VIOLATIONS -- a cure of five blank
# lines that adds two emit_fmt( calls is two new violations hidden under a smaller total -- so the verdict is
# "a class rose", of which "the total rose" and "clean went dirty" are the common cases.
#
# THE SEAT. Every commit carries the one identity (LCherryholmes), so the author names nobody; the seat is read
# from the message. A row topic the message names ("row <topic>", truncated with ... allowed) that matches a bus
# claim ($S4E_POST/claims/<topic>.claim, first line) is the landing seat, and wins; next, a subject that opens
# with a language ("prolog R1.2:", "lower_snobol4:") names that language's lane owner from s4e_msg.sh's own
# table (TODAY's table: a mode flip since the landing re-points it); every mailbox name the message mentions is
# printed beside it as "named", which may include a relaying ceo or a finding cfo.
#
# Usage: bash ../harness/scripts/audit_template_watch.sh [--repo DIR] BASE [HEAD]
#   rc 0  no rule class rose on any template file in BASE..HEAD
#   rc 1  some class rose: each such file is printed with its raising commit(s)
#   rc 2  BASE or HEAD is not a readable commit, or the population is under the floor
# Env: TEMPLATE_WATCH_JOBS (parallel audits; the default is the fan-out ceiling of ../harness/scripts/lib_fanout.sh, max(2, min(4, cores - demand)), CEO-1333); TEMPLATE_WATCH_CACHE (a directory to keep per-blob
# counts across runs, keyed by the audit's own blob so an edited audit never reads a stale count, and per-commit
# form censuses keyed by the census script's blob and the commit).
# ⭐ AND THE FORMS (Lon, same sitting: "...to consider having other IR/BB broken out properly by form/pattern"):
# audit_template_forms.py is run on both ends (git archive of the templates and emit.cpp), and a box whose LIVE
# FORM count rose past one, or an IR kind the emitter newly splits across boxes, is named with the commit that
# raised it -- a form can arrive with no rule class moving, so the rule census alone would never see it.
# Print the next tick's BASE from the last line: "NEXT TICK BASE: <sha>".
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_fanout.sh" || { echo "REFUSE(2): ../harness/scripts/lib_fanout.sh is missing -- the fan-out ceiling (CEO-1333) has no instrument"; exit 2; }
AUDIT="$HERE/audit_bb_fixup_file.sh"
PO="${S4E_POST:-/home/resources/postoffice}"
REPO="$ROOT"
. "$HERE/lib_gate.sh"
if [ "${1:-}" = "--repo" ]; then REPO="${2:-}"; shift 2 || true; fi
BASE_ARG="${1:-}"; HEAD_ARG="${2:-HEAD}"
if [ -z "$BASE_ARG" ]; then
    echo "Usage: $0 [--repo DIR] BASE [HEAD]" >&2
    exit 2
fi
gate_require "$AUDIT" "the per-file audit audit_bb_fixup_file.sh (the watch's only ruler)"
BASE="$(git -C "$REPO" rev-parse --verify -q "${BASE_ARG}^{commit}" 2>/dev/null)"
if [ -z "$BASE" ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot read the base '$BASE_ARG' as a commit in $REPO"
    echo "    The watch diffs against the commit the last tick read; without it nothing can be attributed."
    gate_stamp
    exit 2
fi
HEADC="$(git -C "$REPO" rev-parse --verify -q "${HEAD_ARG}^{commit}" 2>/dev/null)"
if [ -z "$HEADC" ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot read the head '$HEAD_ARG' as a commit in $REPO"
    gate_stamp
    exit 2
fi
if ! git -C "$REPO" merge-base --is-ancestor "$BASE" "$HEADC"; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: base ${BASE:0:9} is not an ancestor of head ${HEADC:0:9} -- the range names no landings"
    gate_stamp
    exit 2
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
AUDIT_KEY="$(git hash-object "$AUDIT")"
CNT="$TMP/counts"
if [ -n "${TEMPLATE_WATCH_CACHE:-}" ]; then CNT="$TEMPLATE_WATCH_CACHE/$AUDIT_KEY"; fi
mkdir -p "$CNT" "$TMP/blobs"
population() {
    git -C "$REPO" ls-tree -r "$1" -- src/templates/bb src/templates/xa \
        | awk -F'\t' '$2 ~ /^src\/templates\/bb\/bb_[^\/]*\.cpp$/ || $2 ~ /^src\/templates\/xa\/xa_[^\/]*\.cpp$/ { split($1, m, " "); print m[3] "\t" $2 }'
}
count_blob() {
    local sha="$1" f
    [ -s "$CNT/$sha" ] && return 0
    f="$TMP/blobs/$sha.cpp"
    git -C "$REPO" cat-file blob "$sha" > "$f" || return 1
    bash "$AUDIT" "$f" | awk '/^  [a-z0-9_]+ +\(/ { print $1 "=" $NF } /^  TOTAL violations:/ { print "TOTAL=" $NF }' > "$CNT/$sha.tmp.$$"
    mv "$CNT/$sha.tmp.$$" "$CNT/$sha"
    rm -f "$f"
}
export -f count_blob
export REPO AUDIT CNT TMP
class_of() { [ "$1" = "-" ] && { echo 0; return; }; awk -F= -v k="$2" '$1 == k { print $2 }' "$CNT/$1"; }
blob_at() { git -C "$REPO" rev-parse -q --verify "$1:$2" 2>/dev/null || echo -; }
population "$BASE" > "$TMP/base.pop"
population "$HEADC" > "$TMP/head.pop"
cut -f1 "$TMP/base.pop" "$TMP/head.pop" | sort -u | xargs -r -P "${TEMPLATE_WATCH_JOBS:-$(fanout_width)}" -I{} bash -c 'count_blob "$1"' _ {}
for s in $(cut -f1 "$TMP/base.pop" "$TMP/head.pop" | sort -u); do
    [ -s "$CNT/$s" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the audit produced no count for blob $s"; gate_stamp; exit 2; }
done
CLASSES="$(cut -d= -f1 "$CNT/$(head -1 "$TMP/head.pop" | cut -f1)" | grep -v '^TOTAL$')"
tally() {
    local pop="$1" files=0 dirty=0 grand=0 t
    while IFS=$'\t' read -r s p; do
        t="$(class_of "$s" TOTAL)"; files=$((files + 1)); grand=$((grand + t)); [ "$t" -gt 0 ] && dirty=$((dirty + 1))
    done < "$pop"
    echo "$files $dirty $grand"
}
read -r bf bd bg <<< "$(tally "$TMP/base.pop")"
read -r hf hd hg <<< "$(tally "$TMP/head.pop")"
delta_classes() {
    local a="$1" b="$2" c x y out=""
    for c in $CLASSES; do
        x="$(class_of "$a" "$c")"; y="$(class_of "$b" "$c")"
        [ "$y" -gt "$x" ] && out="$out $c +$((y - x))"
    done
    echo "${out# }"
}
declare -A LANE
for l in $(gate_lane_languages "$HERE/s4e_msg.sh"); do LANE[$l]="$(gate_lane_owner_of "$HERE/s4e_msg.sh" "$l")"; done
seat_of() {
    local msg topic t hit seats="" lang
    msg="$(git -C "$REPO" log -1 --format=%B "$1")"
    for topic in $(grep -oE '\brows? `?[a-z0-9][a-z0-9-]{15,}' <<< "$msg" | sed -E 's/^rows? `?//; s/-+$//'); do
        hit="$(ls "$PO/claims/" 2>/dev/null | grep -F -- "$topic" | grep -E '\.claim$' | head -2)"
        if [ -n "$hit" ] && [ "$(wc -l <<< "$hit")" -eq 1 ]; then
            echo "seat: $(head -1 "$PO/claims/$hit") (bus claim ${hit%.claim})"
            return
        fi
    done
    for t in $(grep -oE '\b(ceo|cfo|coo|cto|hq_[A-Za-z0-9]+|seat[0-9]{2})\b' <<< "$msg" | awk '!seen[$0]++'); do
        [ -d "$PO/$t/inbox" ] && seats="$seats $t"
    done
    lang="$(head -1 <<< "$msg" | sed -E 's/^(lower_|emit_)?([a-z0-9]+).*/\2/')"
    if [ -n "${LANE[$lang]:-}" ]; then
        echo "seat: ${LANE[$lang]} (today's lane owner of $lang, the subject's language)${seats:+; named:$seats}"
    elif [ -n "$seats" ]; then
        echo "seats named:$seats"
    else
        echo "seat: unnamed"
    fi
}
echo "=== TEMPLATE WATCH ${BASE:0:9}..${HEADC:0:9} ($(git -C "$REPO" rev-list --count "$BASE..$HEADC") commit(s) in range) ==="
echo "  ruler: audit_bb_fixup_file.sh @ blob ${AUDIT_KEY:0:9}, $(wc -w <<< "$CLASSES") classes (the census's 18 + cv9_param_str + cv10_graph)"
printf "  POPULATION base: %d files / %d dirty / GRAND %d\n" "$bf" "$bd" "$bg"
printf "  POPULATION head: %d files / %d dirty / GRAND %d  (%+d)\n" "$hf" "$hd" "$hg" "$((hg - bg))"
LC_ALL=C join -t $'\t' -a1 -a2 -e - -o 0,1.2,2.2 \
    <(awk -F'\t' '{ print $2 "\t" $1 }' "$TMP/base.pop" | LC_ALL=C sort) \
    <(awk -F'\t' '{ print $2 "\t" $1 }' "$TMP/head.pop" | LC_ALL=C sort) > "$TMP/pairs"
rose=0; arrived=0; fell=""
while IFS=$'\t' read -r path bs hs; do
    [ "$bs" = "$hs" ] && continue
    bt="$(class_of "$bs" TOTAL)"; ht="$(class_of "$hs" TOTAL)"
    d="$(delta_classes "$bs" "$hs")"
    if [ -z "$d" ]; then
        [ "$ht" -lt "$bt" ] && fell="$fell $(basename "$path") $bt->$ht"
        continue
    fi
    rose=$((rose + 1))
    kind="ROSE"; [ "$bt" -eq 0 ] && [ "$ht" -gt 0 ] && kind="CLEAN->DIRTY"; [ "$bs" = "-" ] && kind="NEW"
    [ "$ht" -le "$bt" ] && kind="CLASS ROSE UNDER A FALLING TOTAL"
    echo "  $kind: $path  $bt -> $ht   [$d]"
    raisers=0
    for c in $(git -C "$REPO" log --reverse --no-merges --format=%H "$BASE..$HEADC" -- "$path"); do
        pb="$(blob_at "$c^" "$path")"; cb="$(blob_at "$c" "$path")"
        for s in "$pb" "$cb"; do [ "$s" = "-" ] || count_blob "$s"; done
        cd_="$(delta_classes "$pb" "$cb")"
        subj="$(git -C "$REPO" log -1 --format='%an | %s' "$c" | cut -c1-160)"
        if [ -n "$cd_" ]; then
            raisers=$((raisers + 1))
            for x in $cd_; do case "$x" in +*) arrived=$((arrived + ${x#+})) ;; esac; done
            echo "    RAISED  ${c:0:9}  $(seat_of "$c")  [$cd_]"
        else
            echo "    touched ${c:0:9}  $(seat_of "$c")  [no class rose]"
        fi
        echo "            $subj"
    done
    [ "$raisers" -eq 0 ] && echo "    ⛔ no single non-merge commit in the range raised it -- read the merges of ${BASE:0:9}..${HEADC:0:9}"
done < "$TMP/pairs"
[ -n "$fell" ] && echo "  FELL (cured, no class rose):$fell"
echo "  VERDICT: $rose template file(s) gained violations in ${BASE:0:9}..${HEADC:0:9}, $arrived violation(s) arrived by the raising commits"
FORMS="$HERE/audit_template_forms.py"
FKEY="$(git hash-object "$FORMS" 2>/dev/null | cut -c1-12)"
fpath() { echo "$CNT/forms.$FKEY.$(git -C "$REPO" rev-parse -q --verify "$1^{commit}" 2>/dev/null || echo none)"; }
forms_at() {
    local p d
    p="$(fpath "$1")"
    [ -s "$p" ] && return 0
    d="$TMP/tree.$$.$RANDOM"
    mkdir -p "$d"
    git -C "$REPO" archive "$1" src/templates/bb src/templates/xa src/emitter/emit.cpp 2>/dev/null | tar -x -C "$d" 2>/dev/null
    python3 "$FORMS" --root "$d" --tsv > "$p.tmp.$$" 2>&1
    if [ $? -le 1 ]; then mv "$p.tmp.$$" "$p"; else rm -f "$p.tmp.$$"; rm -rf "$d"; return 1; fi
    rm -rf "$d"
}
live_of() { awk -F'\t' -v b="$2" '$1 == b { print $6; f = 1 } END { if (!f) print 0 }' "$(fpath "$1")"; }
split_of() { awk -F'\t' -v k="$2" '$1 == "kind" && $2 == k { print $3; f = 1 } END { if (!f) print "-" }' "$(fpath "$1")"; }
nboxes() { [ "$1" = "-" ] && echo 0 || tr '|' '\n' <<< "$1" | wc -l; }
formrose=0
if [ ! -f "$FORMS" ]; then
    echo "  FORMS: the form census audit_template_forms.py is absent -- forms not watched this tick"
elif ! forms_at "$BASE" || ! forms_at "$HEADC"; then
    echo "  FORMS: UNPROVEN -- the form census could not read ${BASE:0:9} or ${HEADC:0:9} (no emitter switch there?) -- forms not watched this tick"
else
    for b in $(awk -F'\t' '$1 ~ /^bb_/ { print $1 }' "$(fpath "$HEADC")"); do
        lb="$(live_of "$BASE" "$b")"; lh="$(live_of "$HEADC" "$b")"
        [ "$lh" -gt 1 ] && [ "$lh" -gt "$lb" ] || continue
        formrose=$((formrose + 1))
        f="$(awk -F'\t' -v b="$b" '$1 == b { print $2 }' "$(fpath "$HEADC")")"
        echo "  FORMS ROSE: $b  live forms $lb -> $lh  ($f)"
        for c in $(git -C "$REPO" log --reverse --no-merges --format=%H "$BASE..$HEADC" -- "$f" src/emitter/emit.cpp); do
            forms_at "$c^" && forms_at "$c" || { echo "    ?       ${c:0:9}  the census could not read this commit"; continue; }
            pl="$(live_of "$c^" "$b")"; cl="$(live_of "$c" "$b")"
            [ "$cl" -gt "$pl" ] || continue
            echo "    RAISED  ${c:0:9}  $(seat_of "$c")  [live forms $pl -> $cl]"
            echo "            $(git -C "$REPO" log -1 --format='%an | %s' "$c" | cut -c1-160)"
        done
    done
    for k in $(awk -F'\t' '$1 == "kind" { print $2 }' "$(fpath "$HEADC")"); do
        sb="$(split_of "$BASE" "$k")"; sh="$(split_of "$HEADC" "$k")"
        [ "$(nboxes "$sh")" -gt 1 ] && [ "$(nboxes "$sh")" -gt "$(nboxes "$sb")" ] || continue
        formrose=$((formrose + 1))
        echo "  KIND SPLIT ROSE: $k  ${sb} -> ${sh}  (the emitter now picks among boxes for this kind)"
        for c in $(git -C "$REPO" log --reverse --no-merges --format=%H "$BASE..$HEADC" -- src/emitter/emit.cpp); do
            forms_at "$c^" && forms_at "$c" || continue
            [ "$(nboxes "$(split_of "$c" "$k")")" -gt "$(nboxes "$(split_of "$c^" "$k")")" ] || continue
            echo "    RAISED  ${c:0:9}  $(seat_of "$c")  [$(split_of "$c^" "$k") -> $(split_of "$c" "$k")]"
            echo "            $(git -C "$REPO" log -1 --format='%an | %s' "$c" | cut -c1-160)"
        done
    done
    echo "  FORMS VERDICT: $formrose box(es) or kind(s) gained a form in ${BASE:0:9}..${HEADC:0:9} (a box with more than one live form, or a kind the emitter splits across boxes, that grew)"
fi
gate_floor "$hf" 50 "bb_*/xa_* template files at head"
echo "NEXT TICK BASE: $HEADC"
gate_verdict "$((rose + formrose))" "template file(s) where a rule class rose, or box(es) and kind(s) that gained a form"
