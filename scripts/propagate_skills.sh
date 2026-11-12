#!/usr/bin/env bash
# propagate_skills_ceo_2071.sh [--check] -- EVERY SEAT GETS THE FLEET'S SKILLS (Lon 2026-10-31, in-chat to the ceo: the seats specialise through
# skills, each language's knowledge in one place every seat loads on demand; ceo CEO-2071). The source of truth is .github/skills/<name>/SKILL.md
# (committed); this script copies each skill into every root's project skills folder /home/claude_<seat>/.claude/skills/<name>/ so a seat loads it
# as /<name>, and removes a root copy whose source is gone. --check only reports which roots differ (rc 1 when any does). Idempotent; never a
# symlink (CEO-1853). Re-run after every skill landing. Only skills from .github/skills are touched; a root's other skills are left alone.
HERE=$(cd "$(dirname "$0")" && pwd)
if [ -d "$HERE/../skills" ]; then G=$HERE/..; else G=$HERE/../../.github; fi; SRC=$G/skills   # harness/scripts since 2026-11-11 (Lon: "move scripts to harness."); a .github clone's scripts/ copy (the behind probe) still finds its own skills
CHECK=0; PROBE=0; case "${1:-}" in --check) CHECK=1;; --probe-behind) PROBE=1;; esac
ROOTDIR="${S4E_PROPAGATE_ROOTS:-/home}"
# THE CUT (DESIGN-PLAN skills-complete step 7, the cio 2026-11-07): the source of the copy is whichever root ran this, so a run from a
# .github BEHIND origin/main installs a stale skill set into every seat (the audit of 09:3x: all 32 roots identical and behind the cio's
# .github/skills). The script fetches origin under the fetch slot and REFUSES (rc 2, nothing copied) when origin/main is not an ancestor
# of its own HEAD. S4E_PROPAGATE_ROOTS names the roots to write (default /home; the probe's scratch dir).
behind_state() {   # sets H (HEAD), O (origin/main after a fetch) and B (1 when origin/main is not an ancestor of HEAD); rc 1 when that cannot be measured
  command -v sem >/dev/null 2>&1 || return 1
  sem --id s4e-fetch -j 4 --fg git -C "$G" fetch -q origin 2>/dev/null || return 1
  H="$(git -C "$G" rev-parse HEAD 2>/dev/null)" && O="$(git -C "$G" rev-parse origin/main 2>/dev/null)" || return 1
  if git -C "$G" merge-base --is-ancestor "$O" "$H" 2>/dev/null; then B=0; else B=1; fi; }
probe_behind() {   # --probe-behind: a bare copy of this repo stands for origin, and a clone one commit behind it runs this script with its roots in a scratch dir; it must refuse and install nothing. Writes no live root.
  local W rc out
  W="$(mktemp -d "${TMPDIR:-/tmp}/propagate_behind.XXXXXX")" || { echo "PROPAGATE probe RED: no scratch dir"; return 1; }
  if ! { git clone -q --bare "$G" "$W/origin.git" && git -C "$W/origin.git" update-ref refs/heads/main "$(git -C "$G" rev-parse HEAD)" && git clone -q -b main "$W/origin.git" "$W/clone" && git -C "$W/clone" reset -q --hard HEAD~1; } >/dev/null 2>&1; then
    rm -rf "$W"; echo "PROPAGATE probe RED: could not build a clone one commit behind a scratch origin"; return 1; fi
  cp "$HERE/propagate_skills.sh" "$W/clone/scripts/propagate_skills.sh"   # the script under test runs FROM the behind clone: its own committed copy is one commit old
  mkdir -p "$W/roots/claude_probe" && : > "$W/roots/claude_probe/CLAUDE.md"
  out="$(S4E_PROPAGATE_ROOTS="$W/roots" bash "$W/clone/scripts/propagate_skills.sh" 2>&1)"; rc=$?
  if [ "$rc" = 2 ] && printf '%s\n' "$out" | grep -q '^PROPAGATE behind=1 refused=1 installed=0 ' && [ ! -e "$W/roots/claude_probe/.claude" ]; then
    rm -rf "$W"; echo "PROPAGATE behind=1 refused=1 installed=0"; return 0; fi
  echo "PROPAGATE probe RED: rc=$rc, scratch root $( [ -e "$W/roots/claude_probe/.claude" ] && echo was written || echo was not written ); first line: $(printf '%s\n' "$out" | head -1 | cut -c1-160)"
  rm -rf "$W"; return 1; }
[ "$PROBE" = 1 ] && { probe_behind; exit $?; }
[ -d "$SRC" ] || { echo "REFUSE(2): no $SRC"; exit 2; }
if ! behind_state; then echo "PROPAGATE REFUSE(2): cannot measure whether $G is behind origin (no sem, no fetch, or no origin/main): nothing copied"; exit 2; fi
if [ "$B" = 1 ]; then echo "PROPAGATE behind=1 refused=1 installed=0 head=$H origin=$O"; exit 2; fi
diff_n=0; roots=0
for root in "$ROOTDIR"/claude_*; do
  [ -f "$root/CLAUDE.md" ] || continue; roots=$((roots+1))
  for s in "$SRC"/*/; do
    n=$(basename "$s"); dst=$root/.claude/skills/$n
    if [ -d "$dst" ] && diff -rq "$s" "$dst" >/dev/null 2>&1; then continue; fi
    diff_n=$((diff_n+1))
    if [ $CHECK = 1 ]; then echo "DIFF $(basename "$root") $n"; else mkdir -p "$dst" && rm -rf "$dst"/* && cp -r "$s"/. "$dst"/ && echo "INSTALLED $(basename "$root") $n"; fi
  done
done
echo "SKILLS roots=$roots skills=$(ls -d "$SRC"/*/ | wc -l) $([ $CHECK = 1 ] && echo differing || echo installed)=$diff_n behind=$B"
[ $CHECK = 0 ] || [ $diff_n = 0 ]
