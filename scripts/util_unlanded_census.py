#!/usr/bin/env python3
"""util_unlanded_census.py -- WORK THAT IS NOT ON origin/main, COUNTED (the cio 2026-11-11, CIO-125; Lon 2026-11-11 08:0x CST, in the cio's window,
verbatim: "Investigate how hundreds of fixes went un-pushed."). MEASURED that day: 466 patches in 147 branches stood off main, on origin and in
26 seat folders, and no tool counted them: the hand-off check reads only the branch a repo has checked out, and the worktree remover's "land or
save it" was answered by pinning the commits on a branch nobody read again.

usage: util_unlanded_census.py [--seat NAME] [--fast] [--check] [--list] | --probe
For origin and for every seat folder /home/claude_<seat> (or the one seat named), for each of the four repos, every branch but main, every extra
worktree's HEAD and the repo's own HEAD are read against origin/main as the folder itself last fetched it: a commit whose patch main lacks
(git cherry) is UNLANDED. Prints one line a place: UNLANDED where=<origin|seat> branches=N patches=N oldest=YYYY-MM-DD, and a total line
UNLANDED_CENSUS places=N branches=N patches=N. --list adds one line a branch. --check: rc 1 when the seat named (or any place) holds an
unlanded patch older than one day, naming the first ten branches; rc 0 otherwise. --probe: a planted pair of repositories (a branch with a
patch main lacks, a branch whose patch main already has) reads UNLANDED_PROBE unlanded=1 landed=0, rc 0. rc 2 refused. It reads; it writes
only in its probe's scratch folder. --fast counts commits, not patches (a moment instead of minutes): the stop banner and the hand-off check use it."""
import datetime, glob, os, shutil, subprocess, sys, tempfile
REPOS = ("SCRIP", "corpus", "harness", ".github")


def git(d, *a):
    r = subprocess.run(["git", "-C", d] + list(a), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, errors="replace")
    return r.returncode, r.stdout.strip()


REF_ROOT = os.environ.get("S4E_HOME") or "/home/claude_cio"
FAST = False   # --fast: count the commits a ref holds that origin/main lacks (git rev-list, a moment) and not their patches (git cherry, minutes over a
               # long history). A landed commit the lander rebased still counts under --fast, so a tidy seat deletes the branch once its work is on main.


def unlanded_of(d, ref, base="origin/main"):
    """(patches main lacks, date of the oldest) for one ref of the repo at d. The main it is read against is the freshest one at hand: origin/main
    of the same repo in the caller's own root (S4E_HOME), which reads d's objects through GIT_ALTERNATE_OBJECT_DIRECTORIES, so a folder that has
    not fetched for a week does not count what landed since as unlanded. With no such root the folder's own origin/main is the base."""
    if FAST:
        rc, c = git(d, "rev-list", "--count", f"{base}..{ref}")
        if rc != 0 or c in ("", "0"):
            return 0, ""
        rc, dt = git(d, "log", "-1", "--format=%ad", "--date=short", ref)
        return int(c), dt
    ref_repo = os.path.join(REF_ROOT, os.path.basename(d))
    rc, tip = git(d, "rev-parse", ref)
    if rc == 0 and os.path.isdir(ref_repo + "/.git") and os.path.realpath(ref_repo) != os.path.realpath(d):
        env = dict(os.environ, GIT_ALTERNATE_OBJECT_DIRECTORIES=os.path.join(d, ".git", "objects"))
        r = subprocess.run(["git", "-C", ref_repo, "cherry", base, tip], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, errors="replace", env=env)
        if r.returncode == 0:
            hs = [l[2:] for l in r.stdout.split("\n") if l.startswith("+ ")]
            if not hs:
                return 0, ""
            rc, dt = git(d, "log", "-1", "--format=%ad", "--date=short", hs[0])
            return len(hs), dt
    rc, ch = git(d, "cherry", base, ref)
    if rc != 0:
        return 0, ""
    hs = [l[2:] for l in ch.split("\n") if l.startswith("+ ")]
    if not hs:
        return 0, ""
    rc, dt = git(d, "log", "-1", "--format=%ad", "--date=short", hs[0])
    return len(hs), dt


def place_rows(where, d):
    rows = []
    rc, refs = git(d, "for-each-ref", "--format=%(refname:short)", "refs/heads")
    names = [b for b in refs.split() if b != "main"]
    for b in names:
        n, dt = unlanded_of(d, "refs/heads/" + b)
        if n:
            rows.append((where, os.path.basename(d), b, n, dt))
    rc, wl = git(d, "worktree", "list", "--porcelain")
    heads = [l.split()[1] for l in wl.split("\n") if l.startswith("HEAD ")]
    seen = set()
    for h in heads:
        if h in seen:
            continue
        seen.add(h)
        n, dt = unlanded_of(d, h)
        if n and not any(r[2] != "(detached)" and git(d, "rev-parse", "refs/heads/" + r[2])[1] == h for r in rows):
            rows.append((where, os.path.basename(d), "(a worktree's HEAD " + h[:9] + ")", n, dt))
    return rows


def census(seat=None, root="/home"):
    rows = []
    for d in sorted(glob.glob(f"{root}/claude_*")):
        s = os.path.basename(d).replace("claude_", "")
        if seat and s != seat:
            continue
        for r in REPOS:
            if os.path.isdir(f"{d}/{r}/.git"):
                rows += place_rows(s, f"{d}/{r}")
    if not seat:
        ref_root = f"{root}/claude_cio"
        for r in REPOS:
            d = f"{ref_root}/{r}"
            if not os.path.isdir(d + "/.git"):
                continue
            rc, o = git(d, "ls-remote", "--heads", "origin")
            for l in o.split("\n"):
                if "\t" not in l or l.endswith("refs/heads/main"):
                    continue
                tip, name = l.split("\t")[0], l.split("\t")[1][len("refs/heads/"):]
                if git(d, "cat-file", "-e", tip)[0] != 0:
                    rows.append(("origin", r, name + " (not fetched)", 1, ""))
                    continue
                n, dt = unlanded_of(d, tip)
                if n:
                    rows.append(("origin", r, name, n, dt))
    return rows


def probe():
    t = tempfile.mkdtemp(prefix="unlanded_probe_", dir=os.environ.get("TMPDIR") or None)
    try:
        up, seat = f"{t}/up.git", f"{t}/home/claude_probe/SCRIP"
        os.makedirs(os.path.dirname(seat))

        def g(d, *a):
            r = subprocess.run(["git", "-C", d, "-c", "user.name=probe", "-c", "user.email=probe@invalid", "-c", "commit.gpgsign=false"] + list(a), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            if r.returncode != 0:
                print(f"REFUSE(2) [util_unlanded_census]: probe: git {' '.join(a)}: {r.stdout.strip()[:120]}")
                sys.exit(2)

        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", up], check=True)
        subprocess.run(["git", "clone", "-q", up, seat], stderr=subprocess.DEVNULL, check=True)
        open(f"{seat}/a.txt", "w").write("one\n"); g(seat, "add", "-A"); g(seat, "commit", "-q", "-m", "base", "--no-verify"); g(seat, "branch", "-M", "main"); g(seat, "push", "-q", "origin", "main")
        g(seat, "checkout", "-q", "-b", "landed"); open(f"{seat}/b.txt", "w").write("landed\n"); g(seat, "add", "-A"); g(seat, "commit", "-q", "-m", "landed work", "--no-verify")
        g(seat, "checkout", "-q", "main"); g(seat, "cherry-pick", "landed"); g(seat, "push", "-q", "origin", "main")
        g(seat, "checkout", "-q", "-b", "pinned"); open(f"{seat}/c.txt", "w").write("pinned\n"); g(seat, "add", "-A"); g(seat, "commit", "-q", "-m", "pinned work", "--no-verify")
        g(seat, "checkout", "-q", "main"); g(seat, "fetch", "-q", "origin")
        global REF_ROOT
        REF_ROOT = f"{t}/none"
        rows = census(seat="probe", root=f"{t}/home")
        un = sum(1 for r in rows if r[2] == "pinned"); la = sum(1 for r in rows if r[2] == "landed")
        print(f"UNLANDED_PROBE unlanded={un} landed={la}")
        return 0 if (un, la) == (1, 0) else 1
    finally:
        shutil.rmtree(t, ignore_errors=True)


def main(argv):
    if argv == ["--probe"]:
        return probe()
    seat = None
    if "--seat" in argv:
        i = argv.index("--seat")
        if i + 1 >= len(argv):
            print("REFUSE(2) [util_unlanded_census]: --seat needs a name"); return 2
        seat = argv[i + 1]; argv = argv[:i] + argv[i + 2:]
    global FAST
    if "--fast" in argv:
        FAST = True; argv = [a for a in argv if a != "--fast"]
    bad = [a for a in argv if a not in ("--check", "--list")]
    if bad:
        print(f"REFUSE(2) [util_unlanded_census]: usage: util_unlanded_census.py [--seat NAME] [--fast] [--check] [--list] | --probe (read {bad[0]!r})"); return 2
    rows = census(seat)
    places = {}
    for w, r, b, n, dt in rows:
        p = places.setdefault(w, [0, 0, "9999"])
        p[0] += 1; p[1] += n; p[2] = min(p[2], dt or "9999")
    if "--list" in argv:
        for w, r, b, n, dt in sorted(rows):
            print(f"  {w}\t{r}\t{b}\t{n}\t{dt}")
    for w in sorted(places):
        print(f"UNLANDED where={w} branches={places[w][0]} patches={places[w][1]} oldest={places[w][2]}")
    print(f"UNLANDED_CENSUS places={len(places)} branches={len(rows)} patches={sum(r[3] for r in rows)}")
    if "--check" in argv:
        day = (datetime.date.today() - datetime.timedelta(days=1)).isoformat()
        old = [r for r in rows if r[4] and r[4] < day]
        for w, r, b, n, dt in sorted(old)[:10]:
            print(f"  OLDER THAN A DAY {w} {r} {b}: {n} patch(es) since {dt}")
        return 1 if old else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
