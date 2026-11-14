#!/usr/bin/env bash
# propagate_skills_ceo_2071.sh [--check] -- EVERY SEAT GETS THE FLEET'S SKILLS (Lon 2026-10-31, in-chat to the ceo: the seats specialise through
# skills, each language's knowledge in one place every seat loads on demand; ceo CEO-2071). The source of truth is .github/skills/<name>/SKILL.md
# (committed); this script copies each skill into every root's project skills folder /home/claude_<seat>/.claude/skills/<name>/ so a seat loads it
# as /<name>, and removes a root copy whose source is gone. --check only reports which roots differ (rc 1 when any does). Idempotent; never a
# symlink (CEO-1853). Re-run after every skill landing. Only skills from .github/skills are touched; a root's other skills are left alone.
HERE=$(cd "$(dirname "$0")" && pwd)
if [ -d "$HERE/../skills" ]; then G=$HERE/..; else . "$HERE/lib_paths.sh"; G=$S4E_GITHUB; fi; SRC=$G/skills   # scripts/ of the harness since 2026-11-11 (Lon: "move scripts to harness."); a .github clone's scripts/ copy (the behind probe) still finds its own skills
CHECK=0; PROBE=0; MODE=roots; for a in "$@"; do case "$a" in --check) CHECK=1;; --probe-behind) PROBE=1;; --user) MODE=user;; --drop-roots) MODE=drop;; esac; done
# ONE COPY OF THE SKILLS (Lon 2026-11-13 20:1x CST, in the coo's window, verbatim: "Is it not possible for all the seats to not duplicate the skills but to point to the
# /home/.github/skills folder?"; row harness-the-skills-live-once-in-the-users-claude-skills, officer_06). Every seat runs as one Unix user and Claude Code reads the
# user-level skills folder for every session, so one real copy serves the fleet (never a symlink, CEO-1853):
#   --user        copy each skill of $SRC into $S4E_SKILLS_USER (default $HOME/.claude/skills) and remove a copy whose source is gone; only the names this script
#                 installed are touched, read from the manifest $S4E_SKILLS_MANIFEST (default $HOME/.claude/s4e-skills.manifest), so a skill of the user's own
#                 (the synced folder) is never touched. The manifest's presence is the switch: util_keep_home_trees.sh refreshes the copy only once it exists.
#   --drop-roots  remove from each root's .claude/skills every skill $SRC ships (a stale copy too), and the folder once empty; a name $SRC does not ship stays; it refuses (rc 2,
#                 nothing removed) unless --user has installed every skill of $SRC identically, so no seat is ever left without a skill.
# With --check either mode only reports (rc 1 when anything differs). The root mode (no flag) is the copy into every root, as before.
ROOTDIR="${S4E_PROPAGATE_ROOTS:-/home}"
# THE CUT (DESIGN-PLAN skills-complete step 7, the cio 2026-11-07): the source of the copy is whichever root ran this, so a run from a
# .github BEHIND origin/main installs a stale skill set into every seat (the audit of 09:3x: all 32 roots identical and behind the cio's
# .github/skills). The script fetches origin under the fetch slot and REFUSES (rc 2, nothing copied) when origin/main is not an ancestor
# of its own HEAD. S4E_PROPAGATE_ROOTS names the roots to write (default /home; the probe's scratch dir).
behind_state() {   # sets H (HEAD), O (origin/main after a fetch) and B (1 when origin/main is not an ancestor of HEAD); rc 1 when that cannot be measured
  command -v sem >/dev/null 2>&1 || return 1
  [ "${S4E_PROPAGATE_FETCHED:-0}" = 1 ] || sem --id s4e-fetch -j 4 --fg git -C "$G" fetch -q origin 2>/dev/null || return 1   # the keeper has just fetched: it says so and no second fetch runs
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
UDST="${S4E_SKILLS_USER:-$HOME/.claude/skills}"; MAN="${S4E_SKILLS_MANIFEST:-$(dirname "$UDST")/s4e-skills.manifest}"
user_same() { local s n; for s in "$SRC"/*/; do n=$(basename "$s"); diff -rq "$s" "$UDST/$n" >/dev/null 2>&1 || return 1; done; }
if [ "$MODE" = user ]; then
  diff_n=0; mkdir -p "$UDST" || { echo "REFUSE(2): cannot make $UDST"; exit 2; }
  for s in "$SRC"/*/; do n=$(basename "$s"); dst=$UDST/$n
    if [ -d "$dst" ] && diff -rq "$s" "$dst" >/dev/null 2>&1; then continue; fi
    diff_n=$((diff_n+1))
    if [ $CHECK = 1 ]; then echo "DIFF user $n"; else rm -rf "$dst" && cp -r "$s" "$dst" && echo "INSTALLED user $n"; fi
  done
  if [ -f "$MAN" ]; then while IFS= read -r n; do [ -n "$n" ] && [ ! -d "$SRC/$n" ] && [ -d "$UDST/$n" ] || continue
    diff_n=$((diff_n+1)); if [ $CHECK = 1 ]; then echo "STALE user $n"; else rm -rf "${UDST:?}/$n" && echo "REMOVED user $n (its source is gone)"; fi; done < "$MAN"; fi
  [ $CHECK = 1 ] || { ls -d "$SRC"/*/ | xargs -n1 basename > "$MAN.tmp" && mv -f "$MAN.tmp" "$MAN"; }
  echo "SKILLS user=$UDST skills=$(ls -d "$SRC"/*/ | wc -l) $([ $CHECK = 1 ] && echo differing || echo installed)=$diff_n manifest=$MAN behind=$B"
  [ $CHECK = 0 ] || [ $diff_n = 0 ]; exit $?
fi
if [ "$MODE" = drop ]; then
  user_same || { echo "REFUSE(2): $UDST does not hold every skill of $SRC identically: run --user first; nothing removed"; exit 2; }
  diff_n=0; roots=0
  for root in "$ROOTDIR"/claude_*; do d=$root/.claude/skills; [ -d "$d" ] || continue; roots=$((roots+1))
    for s in "$d"/*/; do [ -d "$s" ] || continue; n=$(basename "$s"); [ -d "$SRC/$n" ] || continue   # a fleet skill goes, stale or current (senior_09 to 12 held stale copies, MEASURED 2026-11-13); a name the fleet does not ship stays
      diff_n=$((diff_n+1)); if [ $CHECK = 1 ]; then echo "DUP $(basename "$root") $n"; else rm -rf "${d:?}/$n" && echo "DROPPED $(basename "$root") $n"; fi; done
    [ $CHECK = 1 ] || rmdir "$d" 2>/dev/null || echo "KEPT $(basename "$root")/.claude/skills: it holds what the user-level copy does not: $(ls "$d" | tr '\n' ' ')"
  done
  echo "SKILLS drop roots=$roots $([ $CHECK = 1 ] && echo duplicated || echo dropped)=$diff_n user=$UDST"
  [ $CHECK = 0 ] || [ $diff_n = 0 ]; exit $?
fi
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
