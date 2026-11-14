#!/usr/bin/env python3
"""util_scratch_rescue.py -- NOTHING THAT MATTERS IS LOST WITH /tmp (the cio 2026-11-14; Lon, in the cio's window, verbatim: "You are an IDIOT to store things on /tmp where
the are vunerable." / "quit using /tmp COMPLETELY for anything important. Why did I have to say that outloud?").

MEASURED that morning by the coo: all 62 patch and diff files the seats' escalations named under /tmp/s4e were gone, taken by the idle sweep or by a reboot (/tmp is swept and
is cleared at boot); by the rows that named them, 3 still open, 14 done, 14 retired, 31 deleted in the re-cut. The seats had saved cures as files in scratch. A rule told to a
seat did not hold; these two roads are in the tools.

    util_scratch_rescue.py --names DEST < TEXT   every path under /tmp that TEXT names is copied under DEST (the bus's escalate: s4e_msg.sh); one line a path on stdout,
                                                 SAVED <path> -> <copy>, or ABSENT <path> for a path named and not there; rc 0
    util_scratch_rescue.py --tree PATH           what the sweep does before it deletes PATH (util_tmp_sweep.sh): hand-made files are copied to the durable folder; one
                                                 RESCUED line; rc 0
    util_scratch_rescue.py --probe               both roads on a scratch tree; one SCRATCH_RESCUE line; rc 0 ok, 1 red

WHAT IS HAND-MADE: a file a seat or a tool wrote on purpose and no build can regenerate: a patch or a diff, a note, a script, a table, a program in one of our languages, a
C source, a log of 256 KB or less. Never a build output, an assembly dump, a binary, a container named ALL.*, or a file over 1 MB (a named file under --names may be 20 MB).
A git checkout under the tree is not copied file by file: its uncommitted edits are saved as one patch and its commits that its origin lacks as one mailbox of patches.
THE DURABLE FOLDER: /home/resources/saved-scratch/<date>/ (S4E_SCRATCH_SAVE names another), one folder a swept entry, and one line a rescue in its INDEX.tsv.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

SAVE = os.environ.get("S4E_SCRATCH_SAVE") or "/home/resources/saved-scratch"
HAND = {".patch", ".diff", ".md", ".txt", ".sh", ".py", ".tsv", ".csv", ".json", ".conf", ".sno", ".sc", ".icn", ".pl", ".pas", ".pp", ".raku", ".rakumod", ".reb", ".c", ".h", ".cpp", ".inc"}
NEVER = re.compile(r"^(ALL|ONE-LINERS|MULTI-LINERS)\.|\.(s|o|so|a|bin|out|xwam|pyc|tmp)$")
MAX_FILE = 1 << 20; MAX_LOG = 256 << 10; MAX_NAMED = 20 << 20; MAX_FILES = 500


def _flat(path):
    return path.strip("/").replace("/", "__")


def _git(d, *a):
    try:
        return subprocess.run(["git", "--no-optional-locks", "-C", d] + list(a), capture_output=True, timeout=120)
    except Exception:
        return None


def _rescue_git(d, dest):
    """a checkout's uncommitted edits and its unlanded commits, each as one file; returns the files written"""
    n = 0
    r = _git(d, "diff", "HEAD")
    if r is not None and r.returncode == 0 and r.stdout.strip():
        os.makedirs(dest, exist_ok=True); open(os.path.join(dest, "uncommitted.patch"), "wb").write(r.stdout); n += 1
    r = _git(d, "rev-parse", "--verify", "-q", "origin/main")
    if r is not None and r.returncode == 0:
        r = _git(d, "format-patch", "--stdout", "origin/main..HEAD")
        if r is not None and r.returncode == 0 and r.stdout.strip():
            os.makedirs(dest, exist_ok=True); open(os.path.join(dest, "commits-origin-lacks.mbox"), "wb").write(r.stdout); n += 1
    return n


def rescue_tree(path, dest):
    """copy the hand-made files of path under dest; returns (files, bytes)"""
    files = size = 0
    if os.path.isfile(path) and not os.path.islink(path):
        base = os.path.basename(path); ext = os.path.splitext(base)[1].lower()
        try:
            sz = os.path.getsize(path)
        except OSError:
            return 0, 0
        if not NEVER.search(base) and ((ext in HAND and sz <= MAX_FILE) or (ext == ".log" and sz <= MAX_LOG)) and sz > 0:
            os.makedirs(dest, exist_ok=True); shutil.copy2(path, os.path.join(dest, base)); return 1, sz
        return 0, 0
    for d, subs, names in os.walk(path):
        if os.path.exists(os.path.join(d, ".git")):
            files += _rescue_git(d, os.path.join(dest, os.path.relpath(d, path)))
            subs[:] = []
            continue
        subs[:] = [x for x in subs if x not in ("out", "node_modules", "__pycache__") and not os.path.islink(os.path.join(d, x))]
        for nm in sorted(names):
            if files >= MAX_FILES:
                return files, size
            p = os.path.join(d, nm); ext = os.path.splitext(nm)[1].lower()
            try:
                if os.path.islink(p) or not os.path.isfile(p): continue
                sz = os.path.getsize(p)
            except OSError:
                continue
            if sz == 0 or NEVER.search(nm): continue
            if not ((ext in HAND and sz <= MAX_FILE) or (ext == ".log" and sz <= MAX_LOG)): continue
            t = os.path.join(dest, os.path.relpath(p, path))
            try:
                os.makedirs(os.path.dirname(t), exist_ok=True); shutil.copy2(p, t); files += 1; size += sz
            except OSError:
                continue
    return files, size


def sweep_rescue(path):
    """the sweep's call: rescue path into today's folder of the durable store and write the index line; never raises"""
    try:
        day = os.path.join(SAVE, time.strftime("%Y-%m-%d", time.gmtime())); dest = os.path.join(day, _flat(path))
        files, size = rescue_tree(path, dest)
        if files:
            os.makedirs(SAVE, exist_ok=True)
            with open(os.path.join(SAVE, "INDEX.tsv"), "a") as f:
                f.write("%s\t%s\t%d\t%d\t%s\n" % (time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), path, files, size, dest))
        return files, size, dest
    except Exception:
        return 0, 0, ""


def save_named(text, dest):
    """every /tmp path the text names: a file is copied whole (up to MAX_NAMED), a folder by the hand-made rule; yields (path, copy or None)"""
    seen = []
    for m in re.finditer(r"/tmp/[^\s'\"`<>|;,)\]]+", text):
        p = m.group(0).rstrip(".:,;!?")
        if p in seen: continue
        seen.append(p)
        if os.path.isfile(p) and not os.path.islink(p):
            try:
                if os.path.getsize(p) <= MAX_NAMED:
                    os.makedirs(dest, exist_ok=True); t = os.path.join(dest, _flat(p)); shutil.copy2(p, t); yield p, t; continue
            except OSError:
                pass
            yield p, None
        elif os.path.isdir(p):
            t = os.path.join(dest, _flat(p)); files, _sz = rescue_tree(p, t)
            yield p, (t if files else None)
        else:
            yield p, None


def probe():
    why = []
    t = tempfile.mkdtemp(prefix="scratch-rescue.", dir="/tmp")
    global SAVE
    old = SAVE; SAVE = os.path.join(t, "durable")
    try:
        w = os.path.join(t, "seat"); os.makedirs(os.path.join(w, "sub"))
        for nm, body in (("cure.patch", "--- a\n+++ b\n"), ("sub/note.md", "the cause is line 12\n"), ("big.s", "x" * 100), ("ALL.pas", "program p;\n"), ("run.log", "ok\n"), ("blob.bin", "b" * 50)):
            open(os.path.join(w, nm), "w").write(body)
        open(os.path.join(w, "huge.txt"), "w").write("y" * (MAX_FILE + 10))
        g = os.path.join(w, "clone"); os.makedirs(g)
        for a in (["init", "-q"], ["config", "user.name", "probe"], ["config", "user.email", "probe@example.invalid"]):
            subprocess.run(["git", "-C", g] + a, capture_output=True)
        open(os.path.join(g, "f.c"), "w").write("int a;\n"); subprocess.run(["git", "-C", g, "add", "f.c"], capture_output=True); subprocess.run(["git", "-C", g, "commit", "-q", "-m", "one"], capture_output=True)
        open(os.path.join(g, "f.c"), "w").write("int a; int b;\n")
        files, size, dest = sweep_rescue(w)
        have = lambda rel: os.path.isfile(os.path.join(dest, rel))
        if not (have("cure.patch") and have("sub/note.md") and have("run.log")): why.append("arm 1: a patch, a note or a small log was not saved (files=%d)" % files)
        if have("big.s") or have("ALL.pas") or have("blob.bin") or have("huge.txt"): why.append("arm 2: a build output, a container, a binary or a file over 1 MB was saved")
        if not have("clone/uncommitted.patch") or have("clone/f.c"): why.append("arm 3: a checkout's uncommitted edit was not saved as one patch, or its files were copied one by one")
        if not os.path.isfile(os.path.join(SAVE, "INDEX.tsv")): why.append("arm 4: the rescue wrote no index line")
        text = "the cure is %s and the try is in %s; also %s." % (os.path.join(w, "cure.patch"), os.path.join(w, "sub"), os.path.join(w, "gone.diff"))
        got = dict(save_named(text, os.path.join(t, "esc")))
        c = got.get(os.path.join(w, "cure.patch"))
        if not (c and open(c).read() == "--- a\n+++ b\n"): why.append("arm 5: a named file was not copied whole")
        if not got.get(os.path.join(w, "sub")): why.append("arm 6: a named folder's hand-made files were not saved")
        if got.get(os.path.join(w, "gone.diff"), "x") is not None: why.append("arm 7: a path named and absent was not reported absent")
    finally:
        SAVE = old; shutil.rmtree(t, ignore_errors=True)
    print("SCRATCH_RESCUE ok arms=7 (the sweep's road saves a patch, a note and a small log, never a build output, a container, a binary or a big file, and a checkout as one patch; the bus's road copies a named file whole and a named folder's hand-made files, and reports a path that is absent)" if not why else "SCRATCH_RESCUE RED: " + " | ".join(why))
    return 0 if not why else 1


def main(argv):
    if argv[1:] == ["--probe"]:
        return probe()
    if len(argv) == 3 and argv[1] == "--names":
        for p, c in save_named(sys.stdin.read(), argv[2]):
            print("SAVED %s -> %s" % (p, c) if c else "ABSENT %s" % p)
        return 0
    if len(argv) == 3 and argv[1] == "--tree":
        files, size, dest = sweep_rescue(argv[2])
        print("RESCUED %s files=%d bytes=%d -> %s" % (argv[2], files, size, dest or "-"))
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
