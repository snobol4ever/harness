"""harness_paths.py -- WHERE EACH REPO LIVES, SET ONCE, for Python: THE ABSOLUTE MODEL (row harness-corpus-and-harness-live-once-on-disk-one-seat-owns-them, officer_02
2026-11-13; Lon 18:1x CST: "all shell scripts will change from the SIBLING model to the ABSOLUtE model."). The same rule as lib_paths.sh:
scrip() is $S4E_SCRIP, else the root itself when it is a SCRIP clone (src/ and a Makefile), else <root>/SCRIP; corpus(), harness() and github() are $S4E_CORPUS,
$S4E_HARNESS and $S4E_GITHUB, else /home/corpus, /home/harness and /home/.github once each is a checkout (it holds .git), else the sibling under <root>. <root> is the
argument, else $S4E_HOME, else the root this file sits in. python3 harness_paths.py --show prints what bash lib_paths.sh --show prints."""
import os
import sys
from pathlib import Path


def _root(root=None):
    if root is not None:
        return Path(root)
    return Path(os.environ.get("S4E_HOME") or Path(__file__).resolve().parent.parent.parent)


def _seat_home():
    # the one-disk checkouts are a default only for a real seat (lib_paths.sh _s4e_paths_seat_home): S4E_HOME unset, a seat root /home/claude_<seat>, or
    # S4E_ONE_DISK_TOP named; a scratch S4E_HOME reads every repo as its own sibling (the coo 2026-11-13 20:3x CST, on senior_01's util_score_row.py measurement)
    if os.environ.get("S4E_ONE_DISK_TOP") or not os.environ.get("S4E_HOME"):
        return True
    h = os.environ["S4E_HOME"].rstrip("/")
    n = h[len("/home/claude_"):] if h.startswith("/home/claude_") else ""
    return bool(n) and "/" not in n


def _pick(env, name, root):
    v = os.environ.get(env)
    if v:
        return Path(v), "env"
    one = Path(os.environ.get("S4E_ONE_DISK_TOP", "/home")) / name
    own = _root(root) / name
    # a root's own clone wins while the root holds one (s4e_take.sh makes it, the landing drops it; the cio 2026-11-14, lib_paths.sh _s4e_paths_pick)
    if _seat_home() and str(own) != str(one) and (own / ".git").exists():
        return own, "own"
    if _seat_home() and (one / ".git").exists():
        return one, "one-disk"
    return own, "sibling"


def _scrip(root):
    v = os.environ.get("S4E_SCRIP")
    if v:
        return Path(v), "env"
    r = _root(root)
    if (r / "src").is_dir() and (r / "Makefile").is_file():
        return r, "root"
    return r / "SCRIP", "sibling"


def scrip(root=None):
    return _scrip(root)[0]


def corpus(root=None):
    return _pick("S4E_CORPUS", "corpus", root)[0]


def harness(root=None):
    return _pick("S4E_HARNESS", "harness", root)[0]


def github(root=None):
    return _pick("S4E_GITHUB", ".github", root)[0]


def packages():
    """The home of every package the corpus does not host (Lon 2026-11-18): $S4E_PACKAGES when set, else /home/packages, as lib_paths.sh sets it."""
    v = os.environ.get("S4E_PACKAGES")
    return Path(v) if v else Path(os.environ.get("S4E_ONE_DISK_TOP", "/home")) / "packages"


def one_disk(name, root=None):
    return _pick({"corpus": "S4E_CORPUS", "harness": "S4E_HARNESS", ".github": "S4E_GITHUB"}[name], name, root)[1] == "one-disk"


def _render_pick(root=None):
    # lib_paths.sh EXPORTS what it picked, so a tool run from a shell that sourced it reads S4E_GITHUB=/home/.github and _pick answers "env": the
    # checkout named by the environment is still the checkout (the cio 2026-11-15, on the grader's measurement: SCORE.md in /home/.github rewritten
    # again at 2026-11-15T05:36Z, the keeper stalled 03:48Z to 06:08Z; every suite runner sources lib_paths.sh before it writes its row).
    gh, how = _pick("S4E_GITHUB", ".github", root)
    one = Path(os.environ.get("S4E_ONE_DISK_TOP", "/home")) / ".github"
    if how == "env" and _seat_home() and (one / ".git").exists() and os.path.realpath(str(gh)) == os.path.realpath(str(one)):
        return one, "one-disk"
    return gh, how


def render_dir(suites_tsv=None, root=None):
    """WHERE A TOOL WRITES WHAT IT USED TO WRITE INTO .github (SCORE.md, LATEST.tsv): the .github folder itself while that is a root's own clone, a sibling
    or named by S4E_GITHUB, and NEVER a one-disk checkout (the cio 2026-11-14, on the grader's measurement: a suite row write outside the cycle re-rendered
    /home/.github/SCORE.md in place, the keeper read "it holds tracked changes" 348 times from 18:31Z to 01:00Z, /home/.github stood three landings behind
    origin and every seat loaded stale skills). Under the one-disk layout it is the folder of the suite record (suites_tsv), and when that is unnamed or is
    the checkout itself, <top>/resources/progress, <top> being S4E_ONE_DISK_TOP or /home: the render lives beside the record it is rendered from."""
    gh, how = _render_pick(root)
    if how != "one-disk":
        return gh
    if suites_tsv:
        d = Path(os.path.dirname(os.path.abspath(str(suites_tsv))))
        if d.resolve() != gh.resolve():
            return d
    return Path(os.environ.get("S4E_ONE_DISK_TOP", "/home")) / "resources" / "progress"


def render_file(name, suites_tsv=None, root=None):
    """The path of one such file. Under the one-disk layout a file that is not there yet is seeded once from the checkout's tracked copy, by a link of a
    private copy, so two first writers never overwrite one another's row."""
    gh, how = _render_pick(root)
    p = render_dir(suites_tsv, root) / name
    if how == "one-disk" and not p.exists() and (gh / name).is_file():
        tmp = p.with_name("%s.seed.%d" % (name, os.getpid()))
        try:
            os.makedirs(str(p.parent), exist_ok=True)
            with open(str(gh / name), "rb") as s, open(str(tmp), "wb") as d:
                d.write(s.read())
            os.chmod(str(tmp), 0o664)
            os.link(str(tmp), str(p))
        except OSError:
            pass
        finally:
            try:
                os.unlink(str(tmp))
            except OSError:
                pass
    return p


def _probe_render():
    import subprocess, tempfile, shutil
    t = tempfile.mkdtemp(prefix="harness_paths_render.")
    bad = []
    try:
        top = os.path.join(t, "top"); gh = os.path.join(top, ".github"); os.makedirs(os.path.join(gh, ".git"))
        open(os.path.join(gh, "SCORE.md"), "w").write("tracked\n"); os.chmod(os.path.join(gh, "SCORE.md"), 0o444)
        seat = os.path.join(t, "seat"); os.makedirs(os.path.join(seat, "src")); open(os.path.join(seat, "Makefile"), "w").close()
        rec = os.path.join(t, "rec"); os.makedirs(rec)
        me = os.path.abspath(__file__)

        def ask(code, **env):
            e = {k: v for k, v in os.environ.items() if not k.startswith("S4E_")}
            e.update(env)
            r = subprocess.run([sys.executable, "-I", "-c", "import sys; sys.path.insert(0, %r); import harness_paths as h; print(%s)" % (os.path.dirname(me), code)], capture_output=True, text=True, env=e)
            return r.stdout.strip()
        got = ask("h.render_file('SCORE.md')", S4E_ONE_DISK_TOP=top, S4E_HOME=seat)
        want = os.path.join(top, "resources", "progress", "SCORE.md")
        if got != want or open(want).read() != "tracked\n" or not os.access(want, os.W_OK):
            bad.append("arm 1 (one-disk, no record named: beside the progress record, seeded, writable) got %s" % got)
        open(want, "w").write("a row\n")
        ask("h.render_file('SCORE.md')", S4E_ONE_DISK_TOP=top, S4E_HOME=seat)
        if open(want).read() != "a row\n":
            bad.append("arm 2 (a file already there is never seeded over)")
        got = ask("h.render_file('SCORE.md', %r)" % os.path.join(rec, "SUITES.tsv"), S4E_ONE_DISK_TOP=top, S4E_HOME=seat)
        if got != os.path.join(rec, "SCORE.md"):
            bad.append("arm 3 (one-disk, a record named: beside that record) got %s" % got)
        got = ask("h.render_file('SCORE.md', %r)" % os.path.join(gh, "SUITES.tsv"), S4E_ONE_DISK_TOP=top, S4E_HOME=seat)
        if got != want:
            bad.append("arm 4 (one-disk, the record named inside the checkout: never the checkout) got %s" % got)
        own = os.path.join(seat, ".github"); os.makedirs(os.path.join(own, ".git"))
        got = ask("h.render_file('SCORE.md')", S4E_ONE_DISK_TOP=top, S4E_HOME=seat)
        if got != os.path.join(own, "SCORE.md"):
            bad.append("arm 5 (the root holds its own clone: the clone, which a landing carries) got %s" % got)
        got = ask("h.render_file('SCORE.md')", S4E_HOME=os.path.join(t, "scratchroot"))
        if got != os.path.join(t, "scratchroot", ".github", "SCORE.md"):
            bad.append("arm 6 (a scratch root: its own sibling, as before) got %s" % got)
        got = ask("h.render_file('SCORE.md')", S4E_ONE_DISK_TOP=top, S4E_HOME=seat, S4E_GITHUB=gh)
        if got != want:
            bad.append("arm 8 (the checkout named by S4E_GITHUB, as lib_paths.sh exports it: still never the checkout) got %s" % got)
        got = ask("h.render_file('SCORE.md', %r)" % os.path.join(gh, "SUITES.tsv"), S4E_ONE_DISK_TOP=top, S4E_HOME=seat, S4E_GITHUB=gh)
        if got != want:
            bad.append("arm 9 (the same with the record named inside the checkout) got %s" % got)
        other = os.path.join(t, "other"); os.makedirs(other)
        got = ask("h.render_file('SCORE.md')", S4E_ONE_DISK_TOP=top, S4E_HOME=seat, S4E_GITHUB=other)
        if got != os.path.join(other, "SCORE.md"):
            bad.append("arm 10 (S4E_GITHUB naming any other folder: that folder, as before) got %s" % got)
        if open(os.path.join(gh, "SCORE.md")).read() != "tracked\n" or sorted(os.listdir(gh)) != [".git", "SCORE.md"]:
            bad.append("arm 7 (the one-disk checkout is untouched)")
    finally:
        shutil.rmtree(t, ignore_errors=True)
    for b in bad:
        print("RENDER_HOME RED: " + b)
    print("RENDER_HOME %s arms=10 (a render is never written into a one-disk checkout)" % ("RED" if bad else "ok"))
    return 1 if bad else 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--probe-render"]:
        sys.exit(_probe_render())
    if sys.argv[1:] != ["--show"]:
        print("usage: python3 harness_paths.py --show | --probe-render", file=sys.stderr)
        sys.exit(2)
    parts = [("S4E_SCRIP",) + _scrip(None)] + [(e,) + _pick(e, n, None) for e, n in (("S4E_CORPUS", "corpus"), ("S4E_HARNESS", "harness"), ("S4E_GITHUB", ".github"))]
    print(" ".join("%s=%s (%s)" % p for p in parts))
