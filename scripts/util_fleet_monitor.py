#!/usr/bin/env python3
# util_fleet_monitor.py (ceo, 2026-08-28) — the per-turn FLEET monitor's computed half (Lon: "at each turn
# you tell me what all Fleet workers are doing" + "fold the spy sweep into the monitor").  Emits, per active
# seat: live claim(s) · board verdict+time · working-tree spy (dirty files, unpushed commits, last activity).
# The plain-English what-it-is sentence stays the CEO's to write per turn (Lon: slugs are unintelligible).
# Reads MODE for the active band; refuses rc=2 if the postoffice is unreadable.
import os, re, subprocess, sys
PO = os.environ.get("S4E_PO", "/home/resources/postoffice")
try:
    mode = open(os.path.join(PO, "MODE")).readline().strip()
except OSError as e:
    print(f"REFUSED (rc=2): {e}", file=sys.stderr); sys.exit(2)
n = int(mode.split('-')[1]) if mode.startswith('FLEET-') else 0
board = {}
for ln in open(os.path.join(PO, "BOARD.md")):
    m = re.match(r'(\S+) \| (.*) \| (\d+:\d+)$', ln.strip())
    if m: board[m.group(1)] = (m.group(2), m.group(3))
claims = {}
cdir = os.path.join(PO, "claims")
for f in os.listdir(cdir):
    if f.endswith('.claim'):
        b = [l.strip() for l in open(os.path.join(cdir, f)) if l.strip()]
        if b and 'DONE' not in b: claims.setdefault(b[0], []).append(f[:-6])
print(f"MODE: {mode}")
for i in range(1, n + 1):
    s = f"seat{i:02d}"; root = f"/home/claude{i:02d}/SCRIP"
    c = ", ".join(claims.get(s, [])) or "-"
    bl, bt = board.get(s, ("(no board line)", "--"))
    verdict = "✅" if "SUCCESS" in bl else ("⛔" if "FAILURE" in bl else "·")
    if os.path.isdir(os.path.join(root, ".git")):
        g = lambda *a: subprocess.run(["git", "-C", root] + list(a), capture_output=True, text=True).stdout.strip()
        dirty = len([l for l in g("status", "--short").splitlines() if l])
        unpushed = len([l for l in g("log", "origin/main..HEAD", "--oneline").splitlines() if l])
        age = g("log", "-1", "--format=%ar")
        spy = f"dirty={dirty} unpushed={unpushed} tip:{age}"
    else:
        spy = "no clone"
    print(f"{s} {verdict} [{bt}] claim: {c} | {spy}")
