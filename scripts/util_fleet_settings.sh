#!/usr/bin/env bash
# util_fleet_settings.sh [--apply] -- LON'S ONE SCRIPT: every seat root's .claude/settings.local.json and the three slices (ARCH-SHARED-
# DEVELOPMENT.md 4.2 and 8 step 2; the cto's design CEO-2041, written by the ceo). No other hand changes a root's settings (section 9).
# WITHOUT --apply it changes nothing: it prints, root by root, the unified diff it would write, then the slice and tmpfiles commands.
# WITH --apply, in this order:
#   (1) the slices FIRST (a weight below app.slice enables the cpu controller there, section 10):
#         app-org.gnome.Terminal.slice CPUWeight=600 MemoryHigh=20G MemoryMax=24G   (the sessions)
#         s4e-grader.slice CPUWeight=300 MemoryMax=10G                               (the grader, step 5 moves the coo's loops in)
#         s4e-batch.slice  CPUWeight=100 MemoryMax=12G                               (batch, step 4 moves the boards and censuses in)
#   (2) /tmp/s4e/<seat> for every seat, made at every login by ~/.config/user-tmpfiles.d/s4e.conf (a reboot empties /tmp; TMPDIR points there)
#   (3) every seat root's settings.local.json, a dated .bak beside it: the env block (S4E_SEAT, S4E_SEAT_JOBS=4, MAKEFLAGS=--jobs=4,
#       TMPDIR=/tmp/s4e/<seat>), a SessionStart hook running that root's harness/scripts/s4e_session_start.sh, and every dead hook removed
#       (a hook that cds into SCRIP and runs scripts/s4e_msg.sh, which has not existed since CEO-1819); everything else left as it is
#   (4) every live Claude session placed now through s4e_session_start.sh --pid (the env block reaches a session at its next start)
#   (5) s4e_session_start.sh --check, printed
# rc 0 done (or a clean dry run); 1 a step failed (named); 2 refused.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLY=0
case "${1:-}" in --apply) APPLY=1;; "") ;; *) echo "usage: util_fleet_settings.sh [--apply]" >&2; exit 2;; esac
command -v systemctl >/dev/null || { echo "REFUSE(2): no systemctl" >&2; exit 2; }
ROOTS=$(ls -d /home/claude_* 2>/dev/null)
[ -n "$ROOTS" ] || { echo "REFUSE(2): no /home/claude_* roots" >&2; exit 2; }
STAMP=$(date +%Y%m%dT%H%M%S)
SLICES=("app-org.gnome.Terminal.slice CPUWeight=600 MemoryHigh=20G MemoryMax=24G" "s4e-grader.slice CPUWeight=300 MemoryMax=10G" "s4e-batch.slice CPUWeight=100 MemoryMax=12G")
TF="$HOME/.config/user-tmpfiles.d/s4e.conf"
SEATS=$(for r in $ROOTS; do x=${r##*/claude_}; case " ceo cto cfo coo cao cqo " in *" $x "*) echo "$x";; *) echo "hq_$x";; esac; done)
fail=0
if [ "$APPLY" -eq 1 ]; then
  for s in "${SLICES[@]}"; do systemctl --user set-property $s && echo "SLICE set: $s" || { echo "FAILED: systemctl --user set-property $s"; fail=1; }; done
  [ "$fail" -eq 0 ] || { echo "STOPPED: a slice was not set, so no settings were written and no scope was weighted"; exit 1; }
  mkdir -p "$(dirname "$TF")" && { for s in $SEATS; do echo "d /tmp/s4e/$s 0700 - - -"; done > "$TF"; } && systemd-tmpfiles --user --create "$TF" && echo "TMPFILES $TF written and created" || { echo "FAILED: the tmpfiles step"; fail=1; }
fi
python3 - "$APPLY" "$STAMP" $ROOTS <<'PY'
import difflib, json, os, re, sys
apply, stamp, roots = sys.argv[1] == "1", sys.argv[2], sys.argv[3:]
OFFICERS = {"ceo", "cto", "cfo", "coo", "cao", "cqo"}
DEAD = re.compile(r"/SCRIP\s*&&\s*bash\s+scripts/s4e_msg\.sh")
changed = 0
for root in roots:
    x = os.path.basename(root)[len("claude_"):]
    seat = x if x in OFFICERS else "hq_" + x
    path = os.path.join(root, ".claude", "settings.local.json")
    try: old_text = open(path).read() if os.path.exists(path) else ""
    except Exception as e: print("REFUSE(2): cannot read %s: %s" % (path, e)); sys.exit(2)
    try: d = json.loads(old_text) if old_text.strip() else {}
    except Exception as e: print("REFUSE(2): %s is not JSON: %s" % (path, e)); sys.exit(2)
    env = d.setdefault("env", {})
    env.update({"S4E_SEAT": seat, "S4E_SEAT_JOBS": "4", "MAKEFLAGS": "--jobs=4", "TMPDIR": "/tmp/s4e/" + seat})
    hooks = d.setdefault("hooks", {})
    for ev in list(hooks):
        groups = []
        for g in hooks[ev]:
            hs = [h for h in g.get("hooks", []) if not DEAD.search(h.get("command", ""))]
            if hs: g["hooks"] = hs; groups.append(g)
        if groups: hooks[ev] = groups
        else: del hooks[ev]
    cmd = "bash %s/harness/scripts/s4e_session_start.sh 2>/dev/null || true" % root
    ss = hooks.setdefault("SessionStart", [])
    if not any(h.get("command") == cmd for g in ss for h in g.get("hooks", [])):
        ss.append({"hooks": [{"type": "command", "command": cmd, "timeout": 10}]})
    new_text = json.dumps(d, indent=2) + "\n"
    if new_text == old_text: print("UNCHANGED %s" % path); continue
    changed += 1
    sys.stdout.writelines(difflib.unified_diff(old_text.splitlines(True), new_text.splitlines(True), path + " (now)", path + " (new)"))
    if apply:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if old_text: open(path + ".bak-" + stamp + "-shared-dev", "w").write(old_text)
        tmp = path + ".tmp-" + stamp
        with open(tmp, "w", newline="\n") as fh: fh.write(new_text)
        os.replace(tmp, path)
        print("WROTE %s" % path)
print("SETTINGS roots=%d changed=%d %s" % (len(roots), changed, "applied" if apply else "(dry run: nothing written)"))
PY
rc=$?
[ "$rc" -eq 0 ] || exit "$rc"
echo "NOTE until step 4 moves the boards into s4e-batch.slice, each s4e-mem board scope is a weight-100 sibling of the sessions' slice (600)"
if [ "$APPLY" -ne 1 ]; then
  echo "SLICES it would set first, before any scope is weighted:"; for s in "${SLICES[@]}"; do echo "  systemctl --user set-property $s"; done
  echo "TMPFILES it would write: $TF, $(echo $SEATS | wc -w) lines 'd /tmp/s4e/<seat> 0700 - - -', then systemd-tmpfiles --user --create"
  echo "DRY RUN: nothing changed. Lon runs: bash $HERE/util_fleet_settings.sh --apply"; exit 0
fi
for p in $(pgrep -x claude); do bash "$HERE/s4e_session_start.sh" --pid "$p"; done
bash "$HERE/s4e_session_start.sh" --check
exit "$fail"
