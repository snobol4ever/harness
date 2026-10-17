#!/usr/bin/env bash
# test_gate_template_watch_names_a_planted_violation_by_commit.sh — the template watch names the commit, the class
# and the seat of a violation a landing adds (hq_templates, row
# templates-the-watch-loop-a-census-diff-names-every-template-violation-a-landing-adds-by-file-commit-and-seat,
# ceo CEO-1321; Lon 2026-09-27: "it will just run in a loop always looking for seats creating bad code so it can
# scoop it up and fix it").
#
# THE FIXTURE. A shared, no-checkout clone of this tree in a scratch directory (the real tree, its index and its
# refs are never touched), and four commits planted on its HEAD with plumbing, each changing ONE template:
#   C1  a neutral touch of a DIRTY template F2 (a trailing space on line 1: no class moves)
#   C2  a blank line appended to a CLEAN template F1 (blank_lines +1: clean -> dirty), its message naming a row
#       whose bus claim, in a scratch postoffice, is held by hq_templates, and naming the ceo as relay
#   C3  a line PORT_ALPHA appended to F2 (port_english +1: a dirty file's count rises), naming hq_templates
#   C4  a neutral touch of F1 after C2
# F1 and F2 are chosen by the audit itself at HEAD (the first clean and the first dirty template by path), so
# the fixture follows the set as it is cured and never pins a file name.
# THE ARMS. BASE..C4: rc 1, both files named with their class, C2 and C3 named RAISED with that class and their
# seat (C2 by the bus claim, over the ceo its message also names), C1 and C4 named touched and never RAISED, the
# verdict counting two files and two arrived violations, the population read at both ends. BASE..C1: rc 0 and
# nothing RAISED (the watch can say no). Neither range names a form rise. D1, planted on HEAD apart from the chain,
# gives a one-form box (chosen by the form census at HEAD) a second guarded return: B0..D1 names that box 1 -> 2
# live forms and D1 as its raiser -- a form can arrive with no rule class moving, which is why the watch censuses
# both. An unreadable base and a base that is not an ancestor: rc 2.
# ⛔ FAIL-ONCE: TEMPLATE_WATCH=<path> points the gate at another watch; the landing's proof ran it on a mutant
# that credits the first commit touching a file instead of the one that raised it, and the gate read RED.
# Usage: bash ../harness/scripts/test_gate_template_watch_names_a_planted_violation_by_commit.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
WATCH="${TEMPLATE_WATCH:-$HERE/audit_template_watch.sh}"
AUDIT="$HERE/audit_bb_fixup_file.sh"
gate_require "$WATCH" "the template watch audit_template_watch.sh"
gate_require "$AUDIT" "the per-file audit audit_bb_fixup_file.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
W="$TMP/w"
B0="$(git rev-parse HEAD)"
if ! git clone -q --shared --no-checkout "$ROOT" "$W" 2>"$TMP/clone.err"; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: could not make the scratch clone: $(head -1 "$TMP/clone.err")"
    gate_stamp
    exit 2
fi
F1=""; F2=""
while IFS= read -r p; do
    git -C "$W" cat-file blob "$B0:$p" > "$TMP/probe.cpp"
    if bash "$AUDIT" "$TMP/probe.cpp" > /dev/null; then [ -z "$F1" ] && F1="$p"; else [ -z "$F2" ] && F2="$p"; fi
    [ -n "$F1" ] && [ -n "$F2" ] && break
done < <(git -C "$W" ls-tree -r --name-only "$B0" -- src/templates/bb | grep -E '^src/templates/bb/bb_[^/]*\.cpp$')
if [ -z "$F1" ] || [ -z "$F2" ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: the fixture needs one clean and one dirty template at HEAD (clean='$F1' dirty='$F2')"
    gate_stamp
    exit 2
fi
neutral() { sed '1s/$/ /'; }
blank() { sed -e '$a\'; echo; }
port() { sed -e '$a\'; echo 'PORT_ALPHA'; }
plant() {
    local parent="$1" path="$2" xf="$3" msg="$4" mode blob tree
    mode="$(git -C "$W" ls-tree "$parent" -- "$path" | awk '{ print $1 }')"
    blob="$(git -C "$W" cat-file blob "$parent:$path" | "$xf" | git -C "$W" hash-object -w --stdin)" || return 1
    GIT_INDEX_FILE="$TMP/idx" git -C "$W" read-tree "$parent" || return 1
    GIT_INDEX_FILE="$TMP/idx" git -C "$W" update-index --cacheinfo "$mode,$blob,$path" || return 1
    tree="$(GIT_INDEX_FILE="$TMP/idx" git -C "$W" write-tree)" || return 1
    GIT_AUTHOR_NAME=LCherryholmes GIT_AUTHOR_EMAIL=lcherryh@yahoo.com GIT_COMMITTER_NAME=LCherryholmes GIT_COMMITTER_EMAIL=lcherryh@yahoo.com \
        git -C "$W" commit-tree "$tree" -p "$parent" -m "$msg"
}
ROW="templates-watch-gate-planted-fixture-row"
C1="$(plant "$B0" "$F2" neutral "templates watch gate fixture: a neutral touch of a dirty template")"
C2="$(plant "$C1" "$F1" blank "templates watch gate fixture: row $ROW plants a blank line in a clean template (relayed by the ceo)")"
C3="$(plant "$C2" "$F2" port "templates watch gate fixture: hq_templates plants PORT_ALPHA in a dirty template")"
C4="$(plant "$C3" "$F1" neutral "templates watch gate fixture: a neutral touch of the planted clean template")"
if [ -z "$C1" ] || [ -z "$C2" ] || [ -z "$C3" ] || [ -z "$C4" ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: planting the four fixture commits failed (C1='$C1' C2='$C2' C3='$C3' C4='$C4')"
    gate_stamp
    exit 2
fi
PO="$TMP/po"
mkdir -p "$PO/claims" "$PO/ceo/inbox" "$PO/hq_templates/inbox"
printf 'hq_templates\nRUNNING\n' > "$PO/claims/$ROW.claim"
run_watch() { S4E_POST="$PO" TEMPLATE_WATCH_CACHE="$TMP/cache" bash "$WATCH" --repo "$W" "$@" > "$TMP/out" 2>&1; echo $?; }
fails=0; arms=0
arm() {
    arms=$((arms + 1))
    if [ "$1" = ok ]; then echo "  ok    $2"; else echo "  RED   $2"; fails=$((fails + 1)); fi
}
has() { grep -qF -- "$1" "$TMP/out" && echo ok || echo red; }
hasnt() { grep -qF -- "$1" "$TMP/out" && echo red || echo ok; }
echo "fixture: B0=${B0:0:9} F1(clean)=$F1 F2(dirty)=$F2 C1=${C1:0:9} C2=${C2:0:9} C3=${C3:0:9} C4=${C4:0:9}"
rc="$(run_watch "$B0" "$C4")"
cp "$TMP/out" "$TMP/out.planted"
[ "$rc" = 1 ] && r=ok || r=red; arm "$r" "B0..C4 reads rc 1 (read $rc)"
arm "$(has "CLEAN->DIRTY: $F1  0 -> 1   [blank_lines +1]")" "F1 named clean->dirty with blank_lines +1"
arm "$(has "RAISED  ${C2:0:9}  seat: hq_templates (bus claim $ROW)  [blank_lines +1]")" "C2 named RAISED, seat hq_templates by the bus claim, blank_lines +1"
arm "$(has "ROSE: $F2  ")" "F2 named ROSE"
arm "$(grep -F "ROSE: $F2  " "$TMP/out" | grep -qF '[port_english +1]' && echo ok || echo red)" "F2's rise is port_english +1 and nothing else"
arm "$(has "RAISED  ${C3:0:9}  seats named: hq_templates  [port_english +1]")" "C3 named RAISED, seat hq_templates named in its message, port_english +1"
arm "$(has "touched ${C1:0:9}  seat: unnamed  [no class rose]")" "C1 (neutral) named touched, no class rose"
arm "$(has "touched ${C4:0:9}  seat: unnamed  [no class rose]")" "C4 (neutral) named touched, no class rose"
arm "$(hasnt "RAISED  ${C1:0:9}")" "C1 never named RAISED"
arm "$(hasnt "RAISED  ${C4:0:9}")" "C4 never named RAISED"
arm "$(has "VERDICT: 2 template file(s) gained violations in ${B0:0:9}..${C4:0:9}, 2 violation(s) arrived")" "the verdict counts 2 files and 2 arrived violations"
hb="$(sed -n 's/^  POPULATION base: \([0-9]*\) files.*/\1/p' "$TMP/out")"; hh="$(sed -n 's/^  POPULATION head: \([0-9]*\) files.*/\1/p' "$TMP/out")"
[ -n "$hb" ] && [ "$hb" = "$hh" ] && [ "$hb" -ge 50 ] && r=ok || r=red; arm "$r" "the population is read at both ends ($hb -> $hh files, floor 50)"
rc="$(run_watch "$B0" "$C1")"
[ "$rc" = 0 ] && r=ok || r=red; arm "$r" "B0..C1 (neutral only) reads rc 0 (read $rc)"
arm "$(hasnt "RAISED")" "B0..C1 names nothing RAISED"
arm "$(has "FORMS VERDICT: 0 box(es) or kind(s) gained a form")" "B0..C1 names no form rise"
grep -qF "FORMS VERDICT: 0 box(es) or kind(s) gained a form" "$TMP/out.planted" && r=ok || r=red; arm "$r" "B0..C4 (blank line, PORT_ALPHA) names no form rise"
FB=""; FF=""
if [ -f "$HERE/audit_template_forms.py" ]; then
    mkdir -p "$TMP/t0"
    git -C "$W" archive "$B0" src/templates/bb src/templates/xa src/emitter/emit.cpp | tar -x -C "$TMP/t0"
    while IFS=$'\t' read -r b f k st fo li re; do
        [ "$fo" = 1 ] && [ "$li" = 1 ] && [ "$re" = 0 ] || continue
        [ "$(grep -c "^std::string $b() {\$" "$TMP/t0/$f")" = 1 ] || continue
        FB="$b"; FF="$f"; break
    done < <(python3 "$HERE/audit_template_forms.py" --root "$TMP/t0" --tsv | awk -F'\t' '$1 ~ /^bb_/')
fi
addform() { sed "s/^std::string $FB() {\$/&\n    if (_.op_zres) return x86_alpha() + x86_gamma();/"; }
D1=""
[ -n "$FB" ] && D1="$(plant "$B0" "$FF" addform "templates watch gate fixture: hq_templates gives the one-form box $FB a second form")"
if [ -z "$D1" ]; then
    arm red "a one-form box to plant a second form in was found and planted (box='$FB')"
else
    echo "fixture: D1=${D1:0:9} gives $FB ($FF) a second form"
    rc="$(run_watch "$B0" "$D1")"
    [ "$rc" = 1 ] && r=ok || r=red; arm "$r" "B0..D1 (a second form) reads rc 1 (read $rc)"
    arm "$(has "FORMS ROSE: $FB  live forms 1 -> 2  ($FF)")" "the box that gained a form is named, 1 -> 2 live forms"
    arm "$(has "RAISED  ${D1:0:9}  seats named: hq_templates  [live forms 1 -> 2]")" "D1 is named as the commit that raised it, with its seat"
    arm "$(has "FORMS VERDICT: 1 box(es) or kind(s) gained a form")" "the forms verdict counts one"
fi
rc="$(run_watch "no-such-base-$$" "$C4")"
[ "$rc" = 2 ] && r=ok || r=red; arm "$r" "an unreadable base refuses rc 2 (read $rc)"
rc="$(run_watch "$C4" "$B0")"
[ "$rc" = 2 ] && r=ok || r=red; arm "$r" "a base that is not an ancestor of head refuses rc 2 (read $rc)"
if [ "$fails" -gt 0 ]; then
    echo "--- the watch's output on B0..C4 ---"
    cat "$TMP/out.planted"
fi
gate_floor "$arms" 22 "watch arms"
gate_verdict "$fails" "watch arm(s) red"
