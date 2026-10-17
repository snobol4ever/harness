#!/usr/bin/env python3
"""util_suite_partition.py -- THE STORED PARTITION OF A SUITE: a core, feature shells and bounded chunks, built once from the attribute table and
committed beside it as PARTITION.tsv, so the verifier loop looks a subset up by name and never queries the attribute file per landing (Lon
2026-10-11 13:0x CDT, in-chat to the ceo, verbatim: "subsets need to be identified independent of a query against the attribute file for the long
running test suites. So to partition them as major cores, and shells around that core with each major feature broken out. Or some kind of clustered
partitioning." and "One reason for the subsets on large suites is so they can be run in chunks even when the full regressions are being run in its
'spare' time."; ceo CEO-1676; ARCH-SUITE-PARTITIONS.md).

usage: util_suite_partition.py build <ALL.csv> [--out PARTITION.tsv] [--core-k 3] [--ubiquitous 0.5] [--chunk-entries 100] [--secs results.tsv --suite-key K]
       util_suite_partition.py check <ALL.csv>      # rebuild in memory, compare with the stored PARTITION.tsv beside it: rc 0 same, 1 differs, 2 missing
       util_suite_partition.py summary <ALL.csv>    # print the shape and nothing else

THE PARTITION (deterministic: the same table gives the same file byte for byte):
  features    the attribute table's feature columns (everything after the fixed columns); a feature marked by more than --ubiquitous of the
              entries is UBIQUITOUS (write, directive, procedure, package...) and belongs to the core by definition; the rest are DISTINCTIVE.
  core        the entries covering every distinctive feature at least --core-k times (the entries marking the most distinctive features first):
              the suite's representative set, 2-11% of the entries on the measured tables, run with every feature subset.
  shells      for each distinctive feature F, every entry marking F (non-disjoint): the subset a landing that touches F runs, with the core.
  clusters    every non-core entry in exactly one cluster: the cluster of its RAREST distinctive feature; an entry marking no distinctive
              feature clusters by its `family` column; a table with no feature columns clusters by the entry's directory, else by its
              name family (the letters before the first digit).
  chunks      the clusters packed whole, largest first, into chunks of at most --chunk-entries entries (a cluster larger than the chunk is split
              in order); a chunk is the unit of the full regression -- bounded, so the loop runs the long suites in pieces in its spare time and a
              smoke or a feature subset waits for one chunk at most. Chunks are sized by entry count until every runner records the program's
              seconds in its progress row (the secs column reads 0 for nearly every suite today); --secs sizes them by seconds when known.
  columns     entry  part(core|chunk:NN)  cluster(feat:F|family:X|dir:D)  shells(the distinctive features the entry marks, space-separated)
"""
import csv, os, sys, collections, io

FIXED = {"rank", "entry", "origin", "family", "kind", "xfail", "n_lines", "heap_kb", "stack_kb", "compile_args", "run_args", "modes", "dialect",
         "wantrc", "mask", "heap", "stack", "oracle_env", "oracle_args", "argv", "stdin", "ref", "tier", "note", "status", "reason", "class"}
MARKED_NO = {"", "0", "-", "no", "false", "n"}


def read_table(path):
    with open(path, encoding="utf-8", errors="replace", newline="") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        raise SystemExit("REFUSE(2): %s has no rows" % path)
    feats = [c for c in rows[0].keys() if c and c not in FIXED]
    return rows, feats


def read_secs(path, key):
    secs = {}
    if not path:
        return secs
    with open(path, encoding="utf-8", errors="replace") as f:
        for row in csv.reader(f, delimiter="\t"):
            if len(row) < 11 or row[0] == "ts_utc" or row[5] != key:
                continue
            try:
                s = float(row[10] or 0)
            except ValueError:
                s = 0.0
            secs[row[7]] = max(secs.get(row[7], 0.0), s)
    return secs


def family_of(entry, row):
    fam = (row.get("family") or "").strip()
    if fam:
        return "family:" + fam
    if "/" in entry:
        return "dir:" + entry.rsplit("/", 1)[0]
    head = entry.split(".")[0]
    letters = "".join(c for c in head if not c.isdigit()).rstrip("_-")
    return "family:" + (letters or head)


def build(rows, feats, core_k=3, ubiquitous=0.5, chunk_entries=100, secs=None):
    secs = secs or {}
    n = len(rows)
    marks = {}
    for e in rows:
        marks[e["entry"]] = {f for f in feats if (e.get(f) or "").strip().lower() not in MARKED_NO}
    cnt = collections.Counter(f for m in marks.values() for f in m)
    live = [f for f in feats if cnt[f] > 0]
    ubiq = [f for f in live if cnt[f] > ubiquitous * n]
    dist = [f for f in live if f not in ubiq]
    dset = set(dist)
    need = {f: min(core_k, cnt[f]) for f in dist}
    core = []
    order = sorted(rows, key=lambda e: (-len(marks[e["entry"]] & dset), int(e.get("rank") or 0), e["entry"]))
    for e in order:
        gain = [f for f in sorted(marks[e["entry"]] & dset) if need[f] > 0]
        if gain:
            core.append(e["entry"])
            for f in gain:
                need[f] -= 1
        if all(v <= 0 for v in need.values()):
            break
    coreset = set(core)
    clusters = collections.OrderedDict()
    for e in rows:
        if e["entry"] in coreset:
            continue
        d = sorted(marks[e["entry"]] & dset, key=lambda f: (cnt[f], f))
        key = ("feat:" + d[0]) if d else family_of(e["entry"], e)
        clusters.setdefault(key, []).append(e["entry"])
    if not dist:
        cap = max(1, n // 10)
        for key in list(clusters.keys()):
            if len(core) >= cap:
                break
            rep = clusters[key].pop(0)
            core.append(rep)
            coreset.add(rep)
            if not clusters[key]:
                del clusters[key]
    weight = (lambda x: max(secs.get(x, 0.0), 0.0)) if secs else (lambda x: 1.0)
    limit = float(chunk_entries)
    chunks = []
    cur, cur_w = [], 0.0
    for key, members in sorted(clusters.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        for m in members:
            w = weight(m) if secs else 1.0
            if cur and cur_w + w > limit:
                chunks.append(cur)
                cur, cur_w = [], 0.0
            cur.append(m)
            cur_w += w
    if cur:
        chunks.append(cur)
    part = {}
    for e in core:
        part[e] = "core"
    for i, ch in enumerate(chunks, 1):
        for e in ch:
            part[e] = "chunk:%02d" % i
    cluster_of = {m: k for k, ms in clusters.items() for m in ms}
    out = []
    for e in rows:
        name = e["entry"]
        shells = " ".join(sorted(marks[name] & dset))
        out.append((name, part.get(name, "core"), cluster_of.get(name, "core"), shells))
    shape = {"entries": n, "features": len(live), "ubiquitous": ubiq, "distinctive": len(dist), "core": len(core), "clusters": len(clusters),
             "chunks": [len(c) for c in chunks]}
    return out, shape


def render(out, shape, params):
    b = io.StringIO()
    b.write("# PARTITION.tsv -- built by ../harness/scripts/util_suite_partition.py (ceo CEO-1676; ARCH-SUITE-PARTITIONS.md); regenerate, never edit by hand; "
            "`util_suite_partition.py check <ALL.csv>` is the gate.\n")
    b.write("# params: core_k=%d ubiquitous=%s chunk_entries=%d secs=%s\n" % (params["core_k"], params["ubiquitous"], params["chunk_entries"], params["secs"] or "none"))
    b.write("# shape: entries=%d features=%d ubiquitous=%d(%s) distinctive=%d core=%d clusters=%d chunks=%d sizes=%s\n" % (
        shape["entries"], shape["features"], len(shape["ubiquitous"]), " ".join(shape["ubiquitous"]), shape["distinctive"], shape["core"],
        shape["clusters"], len(shape["chunks"]), ",".join(str(s) for s in shape["chunks"])))
    b.write("entry\tpart\tcluster\tshells\n")
    for name, part, cluster, shells in out:
        b.write("%s\t%s\t%s\t%s\n" % (name, part, cluster, shells))
    return b.getvalue()


def main(argv):
    if len(argv) < 2 or argv[0] not in ("build", "check", "summary"):
        print(__doc__.strip().split("\n", 1)[0]); print("usage: util_suite_partition.py build|check|summary <ALL.csv> [options]"); return 2
    verb, table = argv[0], argv[1]
    opts = {"out": None, "core_k": 3, "ubiquitous": 0.5, "chunk_entries": 100, "secs": None, "suite_key": None}
    i = 2
    while i < len(argv):
        a = argv[i]
        if a == "--out": opts["out"] = argv[i + 1]; i += 2
        elif a == "--core-k": opts["core_k"] = int(argv[i + 1]); i += 2
        elif a == "--ubiquitous": opts["ubiquitous"] = float(argv[i + 1]); i += 2
        elif a == "--chunk-entries": opts["chunk_entries"] = int(argv[i + 1]); i += 2
        elif a == "--secs": opts["secs"] = argv[i + 1]; i += 2
        elif a == "--suite-key": opts["suite_key"] = argv[i + 1]; i += 2
        else: print("REFUSE(2): unknown option %s" % a); return 2
    if not os.path.isfile(table):
        print("REFUSE(2): no table at %s" % table); return 2
    rows, feats = read_table(table)
    secs = read_secs(opts["secs"], opts["suite_key"]) if opts["secs"] and opts["suite_key"] else {}
    out, shape = build(rows, feats, opts["core_k"], opts["ubiquitous"], opts["chunk_entries"], secs)
    text = render(out, shape, opts)
    dest = opts["out"] or os.path.join(os.path.dirname(os.path.abspath(table)), "PARTITION.tsv")
    line = "%s: entries=%d features=%d (ubiquitous %d, distinctive %d) core=%d clusters=%d chunks=%d sizes=%s" % (
        os.path.relpath(table), shape["entries"], shape["features"], len(shape["ubiquitous"]), shape["distinctive"], shape["core"], shape["clusters"],
        len(shape["chunks"]), ",".join(str(s) for s in shape["chunks"]))
    if verb == "summary":
        print(line); return 0
    if verb == "build":
        with open(dest, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("WROTE %s -- %s" % (os.path.relpath(dest), line)); return 0
    if not os.path.isfile(dest):
        print("PARTITION MISSING: %s has no %s" % (os.path.relpath(table), os.path.basename(dest))); return 2
    stored = open(dest, encoding="utf-8", newline="").read()
    if stored == text:
        print("PARTITION CURRENT: %s" % os.path.relpath(dest)); return 0
    print("PARTITION STALE: %s differs from a rebuild of %s -- run: util_suite_partition.py build %s" % (os.path.relpath(dest), os.path.relpath(table), os.path.relpath(table)))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
