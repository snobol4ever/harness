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
SCRIP and its out/ are never linked (the cto 2026-11-12, measured: a file's mtime lives on its inode, so one root's make or fetch would
move every root's build times and defeat make and gate_require_fresh; objcopy, strip and a redirect write through a link). In the three
shared repos the mtime is shared too, and nothing reads it but git, which re-hashes and reads clean: no SCRIP Makefile rule has a
prerequisite in ../corpus or ../harness (census 2026-11-12), and the check, oracle and build caches key by tree hash or bytes.

usage: util_relink_root.py ROOT [--repo corpus|harness|.github ...] [--pristine DIR] [--check] [--verify]
  ROOT        a seat root holding the repos (each a git checkout)
  --pristine  the directory holding the pristine checkouts (default /home/resources/shared, or S4E_SHARED)
  --check     link nothing; rc 1 when a file could be linked and is not
  --verify    compare the bytes of each candidate as well as git's blob id and size
EXIT: 0 done (or nothing to link under --check), 1 --check found files to link, 2 REFUSED (not a repo, another filesystem, a pristine
that is not read-only is never a link source).
"""
import argparse
import fcntl
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
    sd = dirty(seat)
    # THE PRISTINE IS READ UNDER THE UPDATER'S LOCK (the cio 2026-11-12, measured: a relink beside another reported 1134 pristine files dirty,
    # since two refreshes of one index race for index.lock and the loser's diff-files reads every stat-moved file as modified; the pristine
    # read clean a minute later): the refresh and the dirty read take the flock util_shared_pristine.sh update holds, so a relink never reads
    # a pristine mid-merge and two relinks never refresh it at once.
    with open(os.path.join(os.path.dirname(os.path.abspath(pri)), ".update.flock"), "a") as lk:
        fcntl.flock(lk, fcntl.LOCK_EX)
        pd = dirty(pri)
    n = {"tracked": len(si), "linked": 0, "already": 0, "dirty": 0, "differ": 0, "absent": 0, "special": 0, "pristine_writable": 0, "mtime_forward": 0, "freed": 0}
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
        print(f"RELINK_CHECK root={seat} pristine={pri} linkable={len(todo)} " + " ".join(f"{k}={v}" for k, v in n.items() if k not in ("linked", "freed", "mtime_forward")))
        return 1 if todo else 0
    # A RELINK NEVER MOVES A FILE'S MTIME BACKWARDS (the cto 2026-11-12, measured: build_monitor_ipc_bin_libraries.sh and
    # util_parser_sc_recognition.sh keep a derived file that reads newer than its source; the seat's merge wrote the source at T3, the pristine's
    # inode carries its own checkout time T1 < T3, so a plain link would make an artifact built from the old bytes between T1 and T3 read fresh).
    # The shared inode takes the later of the two mtimes before it is linked: a forward move is a rebuild in every root, never a stale keep.
    for sp, pp, ss in todo:
        tmp = os.path.join(os.path.dirname(sp), f".relink.{os.getpid()}.{os.path.basename(sp)}")
        try:
            ps = os.stat(pp)
            if ss.st_mtime_ns > ps.st_mtime_ns:
                os.utime(pp, ns=(ps.st_atime_ns, ss.st_mtime_ns))
                n["mtime_forward"] += 1
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
    sus = sorted(left - sd)
    if sus:
        # A REFRESH THAT LOST index.lock READS EVERY LINKED FILE MODIFIED (the coo 2026-11-13 20:3x CST, on senior_01's refusal "11 file(s) read dirty after the
        # relink", the files clean a moment later, the same blob in index and pristine): the refresh's status is ignored, so a git status of a hook or the banner
        # holding the seat's index.lock leaves the stat cache stale and diff-files names each file whose inode just moved. Only content is dirt: each suspect is
        # hashed as git would store it and kept dirty only when that differs from its index blob.
        h = subprocess.run(["git", "-C", seat, "hash-object", "--stdin-paths"], input=b"\n".join(x.encode("utf-8", "surrogateescape") for x in sus) + b"\n", capture_output=True, timeout=1800)
        hs = h.stdout.split() if h.returncode == 0 else []
        real = [x for x, hb in zip(sus, hs) if x not in si or hb != si[x][1]] if len(hs) == len(sus) else sus
        if real:
            refuse(f"{seat}: {len(real)} file(s) read dirty after the relink that were clean before it, the first {real[0]!r}")
        print(f"  {len(sus)} file(s) read stat-dirty after the relink and hash to their index blobs (a refresh lost the index lock): clean")
        subprocess.run(["git", "-C", seat, "update-index", "-q", "--refresh"], capture_output=True, timeout=1800)
    git(seat, "config", "s4e.shared", "true")   # the mark util_sync_root.sh reads: this repo shares its files, so its sync links them again
    git(seat, "config", "core.trustctime", "false")   # a link or unlink in another root moves the shared inode's ctime (the cto, measured)
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
