#!/usr/bin/env python3
"""util_progress_prune_ghosts.py [--apply] [--db PATH] [--suites-tsv PATH] SUITE=PACKAGE_DIR ...

THE GHOSTS OF A SUITE'S PROGRESS ROWS (ceo CEO-1366 (b), row icon-package-containers-regenerated-from-the-shipped-files-and-every-
container-key-equals-its-boards-progress-key-ceo-1366; the coo 2026-10-09). A ghost is a program key the progress table holds for a
suite that NEITHER the suite's board writes NOR its container names NOR its package excludes -- a key an older board, a replay or a
harness run of another shape wrote, and that no reader will ever write again. Measured 2026-10-09: IPL 613 bare-stem keys from before
its board wrote <subdir>/<stem>; Arizona 90 icon/arizona_tests/general/*.icn keys of the ceo's 09-05 replay, and its 119 bare stems
once its board writes <subdir>/<stem> (SCRIP b4f66ce42).

For each SUITE (its progress key, e.g. arizona) and PACKAGE_DIR (the container's directory):
  K  every key the table holds for the suite
  B  the keys of the board's LATEST run: the rows sharing the newest row's (scrip, corpus) stamp. ⛔ A PARTIAL RUN IS REFUSED: B must
     hold at least the suite's published total (SUITES.tsv column today_total), or a killed run would make live keys read as ghosts.
  C  the container's keys (ALL.csv column entry)
  X  the package's excluded keys (EXCLUDED.tsv and CONTAINERS.tsv, column 1, a trailing source extension dropped)
  G  = K - B - C - X, the ghosts; MISMATCH = C - B - X, container keys the board does not write (the keys gate's arm).
Without --apply it prints the counts and the ghosts and writes nothing. With --apply it rewrites the table WITHOUT the ghost rows,
under the writers' own lock (results.tsv.lock, the flock util_progress_append.py takes), through a temporary file renamed into place,
after a backup beside the table; it prints every removed key with its row count. rc 0 measured, 2 could not measure.
"""
import csv, fcntl, os, re, shutil, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib_package_keys import board_key

DB = "/home/resources/progress/results.tsv"
EXTS = (".icn", ".sno", ".spt", ".sc", ".pl", ".pas", ".raku", ".reb")


def published_total(suites_tsv, suite):
    with open(suites_tsv, encoding="utf-8") as f:
        for ln in f:
            c = ln.rstrip("\n").split("\t")
            if c and c[0] == suite and len(c) > 9 and c[9].isdigit():
                return int(c[9])
    return None


def keys_of(path, col=0, csv_entry=False):
    out = set()
    if not os.path.exists(path):
        return out
    if csv_entry:
        with open(path, encoding="utf-8") as f:
            r = csv.reader(f)
            hdr = next(r, None)
            if not hdr or "entry" not in hdr:
                raise ValueError("%s has no entry column" % path)
            i = hdr.index("entry")
            for row in r:
                if len(row) > i and row[i]:
                    out.add(row[i])
        return out
    with open(path, encoding="utf-8") as f:
        for ln in f:
            if ln.startswith("#") or not ln.strip():
                continue
            k = ln.split("\t")[col].strip()
            for e in EXTS:
                if k.endswith(e):
                    k = k[: -len(e)]
                    break
            out.add(k)
    return out


def measure(rows, suite, pkg, suites_tsv):
    """(K, B, C, X, G, mismatch) for one suite, or raises ValueError naming why it cannot measure."""
    rs = [r for r in rows if len(r) > 9 and r[5] == suite]
    if not rs:
        raise ValueError("the table holds no row for suite %s" % suite)
    last = max(rs, key=lambda r: r[0])
    K = {r[7] for r in rs}
    B = {r[7] for r in rs if (r[1], r[2]) == (last[1], last[2])}
    tot = published_total(suites_tsv, suite)
    if tot is None:
        raise ValueError("SUITES.tsv names no total for %s" % suite)
    if len(B) < tot:
        raise ValueError("the latest %s run (scrip %s, corpus %s) holds %d keys, under the published total %d -- a partial run; "
                         "pruning against it would delete live keys" % (suite, last[1][:9], last[2][:9], len(B), tot))
    C = keys_of(os.path.join(pkg, "ALL.csv"), csv_entry=True)
    if not C:
        raise ValueError("%s/ALL.csv names no entry" % pkg)
    # a container entry graded through its driver is keyed by its library, the rule the harness writes and the board writes
    lang = os.path.basename(os.path.dirname(os.path.abspath(pkg)))
    C = {board_key(pkg, lang, c) for c in C}
    X = keys_of(os.path.join(pkg, "EXCLUDED.tsv")) | keys_of(os.path.join(pkg, "CONTAINERS.tsv"))
    G = K - B - C - X
    return K, B, C, X, G, C - B - X


def main(argv):
    apply = "--apply" in argv
    db = argv[argv.index("--db") + 1] if "--db" in argv else os.environ.get("S4E_PROGRESS_DB", DB)
    here = os.path.dirname(os.path.abspath(__file__))
    sib = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(here, "..", "..", "SCRIP", ".."))
    suites_tsv = argv[argv.index("--suites-tsv") + 1] if "--suites-tsv" in argv else (os.environ.get("S4E_SUITES_TSV") or ("/home/resources/progress/SUITES.tsv" if re.fullmatch(r"/home/claude_[A-Za-z0-9_]+", os.path.realpath(sib)) else os.path.join(sib, ".github", "SUITES.tsv")))
    specs = [a for a in argv[1:] if "=" in a and not a.startswith("--")]
    if not specs:
        print("REFUSE(2): usage: util_progress_prune_ghosts.py [--apply] [--db PATH] [--suites-tsv PATH] SUITE=PACKAGE_DIR ...")
        return 2
    for p in (db, suites_tsv):
        if not os.path.exists(p):
            print("REFUSE(2): %s does not exist" % p)
            return 2
    lock = open(db + ".lock", "a")
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
    try:
        with open(db, encoding="utf-8", newline="") as f:
            text = f.read()
        lines = text.split("\n")
        header, body = lines[0], [ln for ln in lines[1:] if ln]
        rows = [ln.split("\t") for ln in body]
        ghosts = {}
        rc = 0
        for spec in specs:
            suite, pkg = spec.split("=", 1)
            try:
                K, B, C, X, G, mis = measure(rows, suite, pkg, suites_tsv)
            except ValueError as e:
                print("REFUSE(2) [%s]: %s" % (suite, e))
                rc = 2
                continue
            print("GHOSTS %s: keys=%d board_last_run=%d container=%d excluded=%d ghosts=%d container_keys_the_board_does_not_write=%d"
                  % (suite, len(K), len(B), len(C), len(X), len(G), len(mis)))
            for k in sorted(mis)[:10]:
                print("   MISMATCH %s: %s" % (suite, k))
            ghosts[suite] = G
        if rc:
            return rc
        drop = [i for i, r in enumerate(rows) if len(r) > 7 and r[5] in ghosts and r[7] in ghosts[r[5]]]
        per = {}
        for i in drop:
            per[(rows[i][5], rows[i][7])] = per.get((rows[i][5], rows[i][7]), 0) + 1
        for (s, k), n in sorted(per.items()):
            print("   %s %s: %s (%d row%s)" % ("REMOVED" if apply else "WOULD REMOVE", s, k, n, "" if n == 1 else "s"))
        print("TOTAL: %d ghost key(s), %d row(s) %s" % (len(per), len(drop), "removed" if apply else "that --apply would remove (dry run, nothing written)"))
        if apply and drop:
            stamp = time.strftime("%Y%m%dT%H%M%S")
            shutil.copy2(db, "%s.bak.%s-prune-ghosts" % (db, stamp))
            keep = set(range(len(rows))) - set(drop)
            tmp = db + ".tmp-prune-ghosts"
            with open(tmp, "w", encoding="utf-8", newline="") as f:
                f.write(header + "\n" + "".join(body[i] + "\n" for i in sorted(keep)))
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp, db)
            print("WROTE %s (backup %s.bak.%s-prune-ghosts)" % (db, db, stamp))
        return 0
    finally:
        fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
        lock.close()


if __name__ == "__main__":
    sys.exit(main(sys.argv))
