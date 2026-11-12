#!/usr/bin/env python3
"""util_relink_root.py -- ONE COPY ON DISK OF EVERY FILE THE SEATS SHARE (the cio 2026-11-12, row fleet-32-16-8-4-shared-repos; Lon,
16:3x-16:4x in the coo's window, verbatim: "Can not ALL the seats share harness repo." / "Can not ALL the seats share a corpus repo?" /
"We should save huge space this way.").

A seat root keeps its own corpus, harness and .github directories, so every script that finds a sibling by its own path (536 of 1065
in harness/scripts) or by ../corpus from SCRIP (291, and the Makefile's CORPUS) works unchanged, with no symlink (Lon 2026-11-07). The
BYTES are shared: each clean tracked file whose blob equals the pristine checkout's blob at the same path becomes a hard link to the
pristine's file, which is read-only. MEASURED 2026-11-12 on a scratch pair: git status reads clean; git pull and git checkout replace a
changed file by a new inode and leave the other link as it was; an in-place write (shell >>, Python open('w')) fails EACCES instead of
writing through into every seat. A seat's tree still moves only at its own sync.

usage: util_relink_root.py ROOT [--repo corpus|harness|.github ...] [--pristine DIR] [--check] [--verify]
  ROOT        a seat root holding the repos (each a git checkout)
  --pristine  the directory holding the pristine checkouts (default /home/resources/shared, or S4E_SHARED)
  --check     link nothing; rc 1 when a file could be linked and is not
  --verify    compare the bytes of each candidate as well as git's blob id and size
EXIT: 0 done (or nothing to link under --check), 1 --check found files to link, 2 REFUSED (not a repo, another filesystem, a pristine
that is not read-only is never a link source).
"""
import argparse
import filecmp
import os
import stat
import subprocess
import sys

REPOS = ("corpus", "harness", ".github")


def refuse(msg):
    print(f"REFUSE(2) [relink]: {msg}")
    sys.exit(2)


def git(repo, *args):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, timeout=1800)
    if r.returncode != 0:
        refuse(f"git -C {repo} {' '.join(args)} rc {r.returncode}: {r.stderr.decode(errors='replace').strip()[:200]}")
    return r.stdout


def index(repo):
    """{path: (mode, blob)} of the stage-0 entries git tracks in repo."""
    out = {}
    for rec in git(repo, "ls-files", "-s", "-z").split(b"\0"):
        if not rec:
            continue
        meta, _, path = rec.partition(b"\t")
        mode, blob, stage = meta.split(b" ")
        if stage == b"0":
            out[path.decode("utf-8", "surrogateescape")] = (mode, blob)
    return out


def dirty(repo):
    """the paths whose working file differs from the index, after git has refreshed the stat cache (a refresh that finds a change
    is not an error: its exit status is ignored)."""
    subprocess.run(["git", "-C", repo, "update-index", "-q", "--refresh"], capture_output=True, timeout=1800)
    return {p.decode("utf-8", "surrogateescape") for p in git(repo, "diff-files", "--name-only", "-z").split(b"\0") if p}


def relink(seat, pri, check, verify):
    for d in (seat, pri):
        if not os.path.isdir(os.path.join(d, ".git")) and not os.path.isfile(os.path.join(d, ".git")):
            refuse(f"{d} is not a git checkout")
    if os.stat(seat).st_dev != os.stat(pri).st_dev:
        refuse(f"{seat} and {pri} are on two filesystems: a hard link cannot join them")
    si, pi = index(seat), index(pri)
    sd, pd = dirty(seat), dirty(pri)
    n = {"tracked": len(si), "linked": 0, "already": 0, "dirty": 0, "differ": 0, "absent": 0, "special": 0, "pristine_writable": 0, "freed": 0}
    todo = []
    for path, ent in si.items():
        if path not in pi:
            n["absent"] += 1
            continue
        if path in sd or path in pd:
            n["dirty"] += 1
            continue
        if pi[path] != ent or ent[0] not in (b"100644", b"100755"):
            n["differ" if pi[path] != ent else "special"] += 1
            continue
        sp, pp = os.path.join(seat, path), os.path.join(pri, path)
        try:
            ss, ps = os.lstat(sp), os.lstat(pp)
        except FileNotFoundError:
            n["absent"] += 1
            continue
        if not (stat.S_ISREG(ss.st_mode) and stat.S_ISREG(ps.st_mode)):
            n["special"] += 1
            continue
        if ss.st_ino == ps.st_ino:
            n["already"] += 1
            continue
        if ps.st_mode & 0o222:
            n["pristine_writable"] += 1
            continue
        if ss.st_size != ps.st_size or (verify and not filecmp.cmp(sp, pp, shallow=False)):
            n["differ"] += 1
            continue
        todo.append((sp, pp, ss))
    if check:
        print(f"RELINK_CHECK root={seat} pristine={pri} linkable={len(todo)} " + " ".join(f"{k}={v}" for k, v in n.items() if k not in ("linked", "freed")))
        return 1 if todo else 0
    for sp, pp, ss in todo:
        tmp = os.path.join(os.path.dirname(sp), f".relink.{os.getpid()}.{os.path.basename(sp)}")
        try:
            os.link(pp, tmp)
            os.replace(tmp, sp)
        except OSError as e:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            print(f"  skipped {sp}: {e}")
            continue
        n["linked"] += 1
        if ss.st_nlink == 1:
            n["freed"] += ss.st_size
    if todo:
        subprocess.run(["git", "-C", seat, "update-index", "-q", "--refresh"], capture_output=True, timeout=1800)
    left = dirty(seat)
    if left - sd:
        refuse(f"{seat}: {len(left - sd)} file(s) read dirty after the relink that were clean before it, the first {sorted(left - sd)[0]!r}")
    git(seat, "config", "s4e.shared", "true")   # the mark util_sync_root.sh reads: this repo shares its files, so its sync links them again
    print(f"RELINK root={seat} pristine={pri} " + " ".join(f"{k}={v}" for k, v in n.items()) + f" freed_mb={n['freed'] // 1048576}")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("root")
    ap.add_argument("--repo", action="append", choices=REPOS)
    ap.add_argument("--pristine", default=os.environ.get("S4E_SHARED") or "/home/resources/shared")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--verify", action="store_true")
    a = ap.parse_args()
    rc = 0
    for r in a.repo or REPOS:
        s, p = os.path.join(a.root, r), os.path.join(a.pristine, r)
        if not os.path.isdir(s):
            continue
        if os.path.realpath(s) == os.path.realpath(p):
            refuse(f"{s} is the pristine itself")
        if not os.path.isdir(p):
            refuse(f"no pristine {p} (util_shared_pristine.sh init makes it)")
        rc = max(rc, relink(s, p, a.check, a.verify))
    sys.exit(rc)


if __name__ == "__main__":
    main()
