#!/usr/bin/env bash
# util_one_disk_probe.sh -- THE PROOF OF THE ABSOLUTE MODEL ON SCRATCH (row harness-corpus-and-harness-live-once-on-disk-one-seat-owns-them, officer_02 2026-11-13; Lon 18:0x CST,
# in the coo's window, verbatim: "So I'm creating /home/corpus and /home/harness for the ENTIRE FLEET to share. So get those scripts fixed."; 18:1x: "a root folder is either a
# SCRIP, snobol4dotnet, or snobol4jvm clone with no siblings ... all shell scripts will change from the SIBLING model to the ABSOLUtE model.").
# A scratch box T mirrors the real one: T/origin/<repo>.git are bare scratch origins borrowing this checkout's objects; T/corpus, T/harness and T/.github are the one-disk
# checkouts (S4E_ONE_DISK_TOP=T, so lib_paths.sh reads them as it reads /home/corpus, /home/harness and /home/.github); T/root is a seat's root that IS the SCRIP clone,
# with no sibling, so its Makefile's ../harness is T/harness as /home/claude_<seat>/../harness is /home/harness. Nothing live is read or written: the postoffice is T/po.
#   arm 1  lib_paths.sh, run from the one-disk harness with S4E_HOME=T/root, names T/root as S4E_SCRIP and T/corpus, T/harness, T/.github as one-disk
#   arm 2  the root builds (make in T/root fetches its build from the cache through T/harness) and grades a SNOBOL4 entry from T/corpus in mode 3, PASS
#   arm 3  a SCRIP change lands from the root: s4e_land.sh --home T/root, its gate run with S4E_SCRIP=T/root and the one-disk corpus, pushes SCRIP alone
#   arm 4  the bus runs against the root: mint, claim and done of a scratch row whose DONE-WHEN reads the root's binary and the one-disk corpus
# Prints ONE_DISK_PROBE ok arms=4 ..., or ONE_DISK_PROBE RED: <arms> and keeps T; rc 0 green, 1 red, 2 cannot measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_paths.sh"
SEAT="${S4E_SEAT:-probe}"
die() { echo "ONE_DISK_PROBE REFUSE(2): $*"; exit 2; }
g() { git -c user.name=LCherryholmes -c user.email=lcherryh@yahoo.com "$@"; }
T="$(mktemp -d "/tmp/s4e/$SEAT/one-disk-probe.XXXXXX" 2>/dev/null)" || { mkdir -p "/tmp/s4e/$SEAT" && T="$(mktemp -d "/tmp/s4e/$SEAT/one-disk-probe.XXXXXX")"; } || die "cannot make a scratch box"
why=""; declare -A h0=()   # each source's HEAD at the start: /home/corpus moves under a run (the grader's minute update), so arm 3 compares with this, never the live HEAD
src_of() { case "$1" in SCRIP) printf '%s' "$S4E_SCRIP" ;; corpus) printf '%s' "$S4E_CORPUS" ;; harness) printf '%s' "$S4E_HARNESS" ;; .github) printf '%s' "$S4E_GITHUB" ;; esac; }
for r in SCRIP corpus harness .github; do
    s="$(src_of "$r")"; [ -e "$s/.git" ] || die "no $r checkout at $s to borrow"
    objs="$(cd "$s" && git rev-parse --path-format=absolute --git-common-dir)/objects"; b="$T/origin/$r.git"
    h0[$r]="$(git -C "$s" rev-parse HEAD)"
    mkdir -p "$T/origin" && git init -q --bare "$b" && echo "$objs" > "$b/objects/info/alternates" && git -C "$b" update-ref refs/heads/main "${h0[$r]}" && git -C "$b" symbolic-ref HEAD refs/heads/main || die "cannot make the scratch origin of $r"
done
git clone -q --shared "$T/origin/SCRIP.git" "$T/root" || die "cannot clone the root"
git clone -q --shared "$T/origin/harness.git" "$T/harness" || die "cannot clone the one-disk harness"
git clone -q --shared "$T/origin/.github.git" "$T/.github" || die "cannot clone the one-disk .github"
git clone -q --shared --no-checkout "$T/origin/corpus.git" "$T/corpus" && git -C "$T/corpus" sparse-checkout set --no-cone /tests/snobol4/ /include/ /library/ && git -C "$T/corpus" reset -q --hard || die "cannot check out the one-disk corpus"
mkdir -p "$T/po/tasks" "$T/po/claims" "$T/po/$SEAT/inbox" && : > "$T/po/QUEUE.tsv" && : > "$T/po/BOARD.md" && { cp /home/resources/postoffice/MODE "$T/po/MODE" 2>/dev/null || printf 'TENET\n' > "$T/po/MODE"; }
E=(env -u S4E_SCRIP -u S4E_CORPUS -u S4E_HARNESS -u S4E_GITHUB -u SCRIP -u RT_DIR S4E_HOME="$T/root" S4E_ONE_DISK_TOP="$T" S4E_POSTOFFICE="$T/po" S4E_POST="$T/po" S4E_SEAT="$SEAT" S4E_NO_BANNER=1)
# arm 1
o="$("${E[@]}" bash "$T/harness/scripts/lib_paths.sh" --show 2>&1)"
[ "$o" = "S4E_SCRIP=$T/root (root) S4E_CORPUS=$T/corpus (one-disk) S4E_HARNESS=$T/harness (one-disk) S4E_GITHUB=$T/.github (one-disk)" ] || why="$why arm 1: lib_paths.sh says '$o';"
# arm 2
( cd "$T/root" && env -u MAKEFLAGS -u MFLAGS -u MAKELEVEL "${E[@]}" timeout -k 5 1800 make -j8 ) > "$T/make.log" 2>&1 || why="$why arm 2: make in the root failed ($(grep -m1 -E 'error|Error' "$T/make.log" | cut -c1-120));"
grep -q '^FETCHED ' "$T/make.log" || echo "    note: the root's build was not fetched from the cache ($(tail -1 "$T/make.log" | cut -c1-100))"
ent="$(awk -F, 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "entry") c = i; next } c && $c != "" { print $c; exit }' "$T/corpus/tests/snobol4/ALL.csv" 2>/dev/null)"
[ -n "$ent" ] || why="$why arm 2: no entry in the one-disk corpus's tests/snobol4/ALL.csv;"
if [ -n "$ent" ]; then
    o="$( cd "$T/root" && "${E[@]}" S4E_PROGRESS_OFF=1 SUITE_LIST_ALL=1 timeout -k 5 600 python3 "$T/harness/scripts/corpus_suite_harness.py" run "$T/corpus/tests/snobol4/ALL.sno" "$T/corpus/tests/snobol4/ALL.ref" --lang snobol4 --modes m3 --partition "entry:$ent" 2>&1 )"
    printf '%s\n' "$o" | grep -m1 '^SUITE_BOARD' | cut -c1-160 | sed 's/^/    arm2| /'
    printf '%s\n' "$o" | grep -q '^SUITE_BOARD .* m3_pass=1 ' || why="$why arm 2: the entry $ent did not read m3_pass=1 ($(printf '%s\n' "$o" | grep -m1 -E 'SUITE_BOARD|REFUS' | cut -c1-140));"
fi
# arm 3
g -C "$T/root" commit -q --allow-empty -m "probe: a SCRIP change landed from a root that is the clone" || die "cannot commit in the root"
gate="[ \"\$S4E_SCRIP\" = \"$T/root\" ] && [ \"\$S4E_HOME\" = \"$T/root\" ] && [ -x \"\$S4E_SCRIP/scrip\" ] && bash \"\$S4E_HARNESS/scripts/lib_paths.sh\" --show | grep -q 'S4E_CORPUS=$T/corpus '"
( cd "$T/root" && "${E[@]}" bash "$T/harness/scripts/s4e_land.sh" --home "$T/root" --gate "$gate" SCRIP ) > "$T/land.log" 2>&1; rc=$?
grep -E 'stage=(preflight|gate|push)|LAND ok|LAND RED|REFUSE' "$T/land.log" | cut -c1-180 | sed 's/^/    arm3| /' | tail -8
[ "$rc" = 0 ] && grep -q '^LAND ok ' "$T/land.log" || why="$why arm 3: the landing from the root returned rc=$rc;"
[ "$(git -C "$T/origin/SCRIP.git" rev-parse main)" = "$(git -C "$T/root" rev-parse HEAD)" ] || why="$why arm 3: SCRIP's origin is not the root's HEAD;"
for r in corpus harness .github; do [ "$(git -C "$T/origin/$r.git" rev-parse main)" = "${h0[$r]}" ] || why="$why arm 3: $r's origin moved;"; done
# arm 4
dw="test -x \"\$S4E_SCRIP/scrip\" && [ \"\$S4E_SCRIP\" = \"$T/root\" ] && test -f \"\$S4E_CORPUS/tests/snobol4/ALL.csv\""
o="$( cd "$T/root" && "${E[@]}" bash "$T/harness/scripts/s4e_msg.sh" mint one-disk-probe-row --owner "$SEAT" --stdin 2>&1 <<BODY
GOAL: the one-disk probe's row: the bus runs against a root that is the SCRIP clone.
DONE-WHEN: $dw
PREMISE-WHEN: ! test -f "$T/root/.one-disk-probe-done"
BODY
)"; [ -f "$T/po/tasks/one-disk-probe-row.task.md" ] || why="$why arm 4: mint wrote no baton ($(printf '%s' "$o" | tail -1 | cut -c1-120));"
o="$( cd "$T/root" && "${E[@]}" S4E_NO_PREMISE_CHECK=1 bash "$T/harness/scripts/s4e_msg.sh" claim one-disk-probe-row 2>&1 )" || why="$why arm 4: claim refused ($(printf '%s' "$o" | tail -1 | cut -c1-120));"
o="$( cd "$T/root" && "${E[@]}" bash "$T/harness/scripts/s4e_msg.sh" done one-disk-probe-row 2>&1 )"; rc=$?
printf '%s\n' "$o" | grep -E 'DONE-WHEN exited|^done ' | cut -c1-160 | sed 's/^/    arm4| /'
[ "$rc" = 0 ] && printf '%s\n' "$o" | grep -q 'DONE-WHEN exited 0' || why="$why arm 4: done rc=$rc ($(printf '%s' "$o" | grep -E 'REFUS|exited' | head -1 | cut -c1-140));"
if [ -z "$why" ]; then rm -rf "$T"; echo "ONE_DISK_PROBE ok arms=4 (a root that IS the SCRIP clone, with no corpus or harness, read the one-disk checkouts, built, graded $ent PASS in mode 3, landed a SCRIP change alone, and ran mint, claim and done on the bus)"; exit 0; fi
echo "ONE_DISK_PROBE RED:$why"; echo "    kept: $T"; exit 1
