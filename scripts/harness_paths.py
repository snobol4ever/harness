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


if __name__ == "__main__":
    if sys.argv[1:] != ["--show"]:
        print("usage: python3 harness_paths.py --show", file=sys.stderr)
        sys.exit(2)
    parts = [("S4E_SCRIP",) + _scrip(None)] + [(e,) + _pick(e, n, None) for e, n in (("S4E_CORPUS", "corpus"), ("S4E_HARNESS", "harness"), ("S4E_GITHUB", ".github"))]
    print(" ".join("%s=%s (%s)" % p for p in parts))
