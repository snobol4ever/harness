#!/usr/bin/env python3
"""util_table_merge.py -- A CONTAINER'S TABLE IS MERGED BY ITS ENTRY KEY, NEVER LINE BY LINE (the cio 2026-11-14, s4e_land.sh's rebase stage).

MEASURED 2026-11-14 with the whole fleet adding witnesses (the coo, officer_05, officer_07, senior_04; LANDINGS.tsv since 15:50Z: 7 of 32 landings ended
red:rebase): one new entry renumbers the rank column of every row below it and moves the chunks of the partition, so a landing that adds ONE entry rewrites 391 to
959 lines of tests/pascal/ALL.csv and 9 to 167 of PARTITION.tsv, and any two landings that add to one container conflict whatever they add.

    util_table_merge.py csv BASE OURS THEIRS OUT          ALL.csv: rows keyed by the `entry` column
    util_table_merge.py partition BASE OURS THEIRS OUT    PARTITION.tsv: rows keyed by their first column, comment lines kept from OURS
    util_table_merge.py lines BASE OURS THEIRS OUT        a package's side table of one line a key (ALL.args, ALL.units, NOT-CUT.tsv, EXCLUDED.tsv, ALL.omit): lines keyed by their
                                                          first column; a line both sides changed differently is a real conflict (the cio 2026-11-16, MEASURED in the
                                                          drain's first hour: two of nine corpus patches of ipl_gprogs read red:rebase on ALL.args and NOT-CUT.tsv alone,
                                                          seven owners each adding a line to the one and deleting a line of the other)
    util_table_merge.py md BASE OURS THEIRS OUT           MULTI-LINERS.md: one section a test, keyed by its `## <entry name>` heading (a heading inside a fence is text)
    util_table_merge.py --probe                           the law on planted tables; one TABLE_MERGE line

OURS is the tree being rebased ONTO (origin), THEIRS the commit being replayed (git's stages 2 and 3 during a rebase), BASE their common ancestor (stage 1).
THE LAW: every row either side added is kept; a row one side deleted and the other left alone is deleted; a cell one side changed is that side's. The order is
OURS', and a row THEIRS added stands after the nearest row before it in THEIRS that the result holds. A `rank` column that counts the rows of OURS one by one is
counted again over the result, so two additions never disagree about it. rc 0 merged and written; rc 1 a REAL conflict (both sides changed one cell differently,
one deleted what the other changed, the two headers differ from the base in different ways), named on stderr, nothing written; rc 2 a file could not be read.
A master's table is then regenerated from its merged container by the lander (util_build_rungs_suite.py --reindex, util_suite_partition.py build), which makes it
exact; a package's table has no such generator and this merge is its whole answer.
"""
import csv
import io
import sys


class Conflict(Exception):
    pass


def _read(path):
    with open(path, newline="", encoding="utf-8", errors="surrogateescape") as f:
        return f.read()


def _write(path, text):
    with open(path, "w", newline="", encoding="utf-8", errors="surrogateescape") as f:
        f.write(text)


def _three_way(key, col, b, o, t):
    """one cell: base, ours, theirs -> the merged value"""
    if o == t:
        return o
    if o == b:
        return t
    if t == b:
        return o
    raise Conflict("row %s, column %s: origin reads %r, the landing %r, their base %r" % (key, col, o, t, b))


def _order(base_keys, ours_keys, theirs_keys, deleted):
    """OURS' order, with each key THEIRS added placed after the nearest earlier THEIRS key the result holds"""
    out = [k for k in ours_keys if k not in deleted]
    have = set(out); base = set(base_keys)
    anchor = None
    for k in theirs_keys:
        if k in have:
            anchor = k
            continue
        if k in base or k in deleted:
            continue          # THEIRS still holds a row OURS deleted: decided by the caller
        i = out.index(anchor) + 1 if anchor is not None else 0
        out.insert(i, k); have.add(k); anchor = k
    return out


def _keyed(rows_b, rows_o, rows_t, cols, skip):
    """rows are {key: {col: value}} in order; returns the merged ordered list of (key, row)"""
    kb, ko, kt = list(rows_b), list(rows_o), list(rows_t)
    deleted = set()
    for k in kb:
        in_o, in_t = k in rows_o, k in rows_t
        if in_o and in_t:
            continue
        if not in_o and not in_t:
            deleted.add(k); continue
        keeper, side = (rows_t, "the landing") if in_t else (rows_o, "origin")
        if any(keeper[k].get(c, "") != rows_b[k].get(c, "") for c in cols if c not in skip):
            raise Conflict("row %s: one side deleted it and %s changed it" % (k, side))
        deleted.add(k)
    out = []
    for k in _order(kb, ko, kt, deleted):
        if k in rows_o and k in rows_t:
            if k in rows_b:
                row = {c: (rows_o[k].get(c, "") if c in skip else _three_way(k, c, rows_b[k].get(c, ""), rows_o[k].get(c, ""), rows_t[k].get(c, ""))) for c in cols}
            else:
                for c in cols:
                    if c not in skip and rows_o[k].get(c, "") != rows_t[k].get(c, ""):
                        raise Conflict("row %s was added by both sides and differs in column %s" % (k, c))
                row = dict(rows_o[k])
        else:
            row = dict(rows_o[k] if k in rows_o else rows_t[k])
        out.append((k, row))
    return out


def _csv_rows(text):
    r = list(csv.reader(io.StringIO(text)))
    if not r:
        return [], {}
    hdr = r[0]
    if "entry" not in hdr:
        raise Conflict("no `entry` column in the header")
    ki = hdr.index("entry"); rows = {}
    for line in r[1:]:
        if not line:
            continue
        line = line + [""] * (len(hdr) - len(line))
        if line[ki] in rows:
            raise Conflict("the entry %s stands twice in one side" % line[ki])
        rows[line[ki]] = dict(zip(hdr, line))
    return hdr, rows


def merge_csv(base, ours, theirs):
    hb, rb = _csv_rows(base); ho, ro = _csv_rows(ours); ht, rt = _csv_rows(theirs)
    hdr = ho if ht == hb or ht == ho else (ht if ho == hb else None)
    if hdr is None:
        raise Conflict("the two sides changed the header in different ways")
    skip = {"rank"} if "rank" in hdr else set()
    merged = _keyed(rb, ro, rt, hdr, skip)
    if skip:
        ranks = [ro[k].get("rank", "") for k in ro]
        counted = bool(ranks) and all(x.isdigit() for x in ranks) and [int(x) for x in ranks] == list(range(int(ranks[0]), int(ranks[0]) + len(ranks)))
        if counted:
            for n, (_k, row) in enumerate(merged, int(ranks[0])):
                row["rank"] = str(n)
        else:
            for k, row in merged:
                row["rank"] = (ro.get(k) or rt[k]).get("rank", "")
    out = io.StringIO(); w = csv.writer(out, lineterminator="\n"); w.writerow(hdr)
    for _k, row in merged:
        w.writerow([row.get(c, "") for c in hdr])
    return out.getvalue()


def _part_rows(text):
    notes, rows = [], {}
    for line in text.split("\n"):
        if not line:
            continue
        if line.startswith("#"):
            notes.append(line); continue
        k = line.split("\t", 1)[0]
        if k in rows:
            raise Conflict("the partition row %s stands twice in one side" % k)
        rows[k] = {"line": line}
    return notes, rows


def merge_partition(base, ours, theirs):
    _nb, rb = _part_rows(base); no, ro = _part_rows(ours); _nt, rt = _part_rows(theirs)
    # a row both sides moved to different chunks is no conflict here: the chunk is the builder's to assign, and origin's stands until the next build
    for k in rt:
        if k in ro and k in rb and ro[k]["line"] != rt[k]["line"] and ro[k]["line"] != rb[k]["line"] and rt[k]["line"] != rb[k]["line"]:
            rt[k] = dict(ro[k])
    merged = _keyed(rb, ro, rt, ["line"], set())
    return "\n".join(no + [row["line"] for _k, row in merged]) + "\n"


def merge_lines(base, ours, theirs):
    _nb, rb = _part_rows(base); no, ro = _part_rows(ours); _nt, rt = _part_rows(theirs)
    merged = _keyed(rb, ro, rt, ["line"], set())
    return "\n".join(no + [row["line"] for _k, row in merged]) + "\n"


def _md_sections(text):
    """(preamble, {name: section text}) of a SCRIPtix container: a section starts at a line `## <name>` that stands outside every fence; a fence opens at a line of three or
    more backticks (with or without a tag) and closes at a line of exactly as many backticks, so a `## ` line of a program or an answer is never taken for a heading."""
    pre, rows, cur, name, fence = [], {}, None, None, 0
    for line in text.split("\n"):
        if fence:
            if line.strip() == "`" * fence:
                fence = 0
        else:
            t = line.lstrip("`")
            n = len(line) - len(t)
            if n >= 3 and "`" not in t:
                fence = n
            elif line.startswith("## "):
                if name is not None:
                    rows[name] = {"text": "\n".join(cur)}
                name = line[3:].strip(); cur = []
                if name in rows:
                    raise Conflict("the section %s stands twice in one side" % name)
        (cur if name is not None else pre).append(line)
    if name is not None:
        rows[name] = {"text": "\n".join(cur)}
    if fence:
        raise Conflict("a fence is left open at the end of one side")
    return "\n".join(pre), rows


def merge_md(base, ours, theirs):
    _pb, rb = _md_sections(base); po, ro = _md_sections(ours); _pt, rt = _md_sections(theirs)
    for d in (rb, ro, rt):                 # the last section owns the file's final newline; every section is compared without its trailing blank lines
        for k in d:
            d[k]["text"] = d[k]["text"].rstrip("\n")
    merged = _keyed(rb, ro, rt, ["text"], set())
    body = "\n\n".join(row["text"] for _k, row in merged)
    return (po.rstrip("\n") + "\n\n" if po.strip() else "") + body + ("\n\n" if ours.endswith("\n\n") else "\n")   # the file ends as origin's ends


def probe():
    why = []
    M = lambda *secs: "".join("## %s\n\n```Pascal\n%s\n```\n\n```stdout\n%s\n```\n\n" % x for x in secs).rstrip("\n") + "\n"
    mb = M(("a", "begin end.", "1"), ("c", "begin end.", "3"))
    mo = M(("a", "begin end.", "1"), ("x_origin", "## not a heading", "x"), ("c", "begin end.", "3"))
    mt = M(("a", "begin end.", "1"), ("y_landing", "begin end.", "y"), ("c", "begin end.", "3"))
    try:
        got = merge_md(mb, mo, mt)
        if got != M(("a", "begin end.", "1"), ("y_landing", "begin end.", "y"), ("x_origin", "## not a heading", "x"), ("c", "begin end.", "3")): why.append("arm 7 (two sections added at one spot of the container, a heading-like line inside a fence): got %r" % got)
    except Conflict as e:
        why.append("arm 7 raised %s" % e)
    try:
        merge_md(mb, M(("a", "begin writeln(1) end.", "1"), ("c", "begin end.", "3")), M(("a", "begin writeln(2) end.", "1"), ("c", "begin end.", "3"))); why.append("arm 8: both sides changed one section differently and it merged")
    except Conflict:
        pass
    H = "rank,entry,family,heap_kb\n"
    base = H + "1,a,f,10\n2,b,f,10\n3,c,f,10\n"
    ours = H + "1,a,f,10\n2,x_origin,f,10\n3,b,f,10\n4,c,f,10\n"            # origin added x_origin after a
    theirs = H + "1,a,f,10\n2,b,f,10\n3,y_landing,f,10\n4,c,f,99\n"         # the landing added y_landing after b and changed c's heap
    want = H + "1,a,f,10\n2,x_origin,f,10\n3,b,f,10\n4,y_landing,f,10\n5,c,f,99\n"
    try:
        got = merge_csv(base, ours, theirs)
        if got != want: why.append("arm 1 (two additions and one changed cell): got %r" % got)
    except Conflict as e:
        why.append("arm 1 raised %s" % e)
    try:
        merge_csv(base, H + "1,a,f,10\n2,b,f,20\n3,c,f,10\n", H + "1,a,f,10\n2,b,f,30\n3,c,f,10\n"); why.append("arm 2: both sides changed one cell differently and it merged")
    except Conflict:
        pass
    try:
        got = merge_csv(base, H + "1,a,f,10\n2,c,f,10\n", H + "1,a,f,10\n2,b,f,10\n3,c,f,10\n4,d,f,10\n")
        if got != H + "1,a,f,10\n2,c,f,10\n3,d,f,10\n": why.append("arm 3 (a row origin deleted stays deleted, the landing's new row is kept): got %r" % got)
    except Conflict as e:
        why.append("arm 3 raised %s" % e)
    try:
        merge_csv(base, H + "1,a,f,10\n2,c,f,10\n", H + "1,a,f,10\n2,b,f,77\n3,c,f,10\n"); why.append("arm 4: one side deleted a row the other changed and it merged")
    except Conflict:
        pass
    P = "# shape: entries=3\n"
    pb = P + "a\tchunk:01\tfeat:x\nb\tchunk:01\tfeat:x\nc\tchunk:02\tfeat:y\n"
    po = "# shape: entries=4\n" + "a\tchunk:01\tfeat:x\nx_origin\tchunk:01\tfeat:x\nb\tchunk:02\tfeat:x\nc\tchunk:02\tfeat:y\n"
    pt = P + "a\tchunk:01\tfeat:x\nb\tchunk:01\tfeat:x\ny_landing\tchunk:02\tfeat:y\nc\tchunk:03\tfeat:y\n"
    try:
        got = merge_partition(pb, po, pt)
        if got != "# shape: entries=4\na\tchunk:01\tfeat:x\nx_origin\tchunk:01\tfeat:x\nb\tchunk:02\tfeat:x\ny_landing\tchunk:02\tfeat:y\nc\tchunk:03\tfeat:y\n": why.append("arm 5 (the partition keeps both new rows): got %r" % got)
    except Conflict as e:
        why.append("arm 5 raised %s" % e)
    try:
        got = merge_csv("entry,heap_kb\na,1\n", "entry,heap_kb\na,1\nb,2\n", "entry,heap_kb\na,1\nc,3\n")
        if got != "entry,heap_kb\na,1\nc,3\nb,2\n" and got != "entry,heap_kb\na,1\nb,2\nc,3\n": why.append("arm 6 (a table with no rank column): got %r" % got)
    except Conflict as e:
        why.append("arm 6 raised %s" % e)
    try:
        got = merge_lines("# n\nk\tw\na\t1\nb\t2\nc\t3\n", "# n\nk\tw\na\t1\nc\t3\nd\t4\n", "# n\nk\tw\nb\t2\nc\t3\ne\t5\n")
        if sorted(got.split("\n")) != sorted("# n\nk\tw\nc\t3\nd\t4\ne\t5\n".split("\n")): why.append("arm 9 (lines: each side deletes one line and adds one): got %r" % got)
    except Conflict as e:
        why.append("arm 9 raised %s" % e)
    try:
        merge_lines("a\t1\n", "a\t2\n", "a\t3\n"); why.append("arm 10 (lines: one line changed differently by both sides) merged")
    except Conflict:
        pass
    if why:
        print("TABLE_MERGE RED: " + "; ".join(why)); return 1
    print("TABLE_MERGE ok arms=10 (a side table's lines are merged by their first column, both sides' new lines kept and deleted lines gone, a line both changed differently a real conflict; two landings' new rows are both kept and the rank counted again; a cell one side changed is that side's; a cell both changed differently, and a row one deleted and the other changed, are real conflicts; a row origin deleted stays deleted; the partition keeps both new rows; two sections added at one spot of a container are both kept, a heading inside a fence is text, and a section both changed differently is a real conflict)" if not why else "TABLE_MERGE RED: " + " | ".join(why))
    return 0 if not why else 1


def main(argv):
    if argv[1:] == ["--probe"]:
        return probe()
    if len(argv) != 6 or argv[1] not in ("csv", "partition", "md", "lines"):
        sys.stderr.write(__doc__)
        return 2
    try:
        b, o, t = _read(argv[2]), _read(argv[3]), _read(argv[4])
    except OSError as e:
        sys.stderr.write("REFUSE(2) [table_merge]: %s\n" % e)
        return 2
    try:
        out = merge_csv(b, o, t) if argv[1] == "csv" else merge_md(b, o, t) if argv[1] == "md" else merge_lines(b, o, t) if argv[1] == "lines" else merge_partition(b, o, t)
    except Conflict as e:
        sys.stderr.write("TABLE_MERGE conflict in %s: %s\n" % (argv[5], e))
        return 1
    except (csv.Error, ValueError) as e:
        sys.stderr.write("REFUSE(2) [table_merge]: %s could not be read as a table: %s\n" % (argv[5], e))
        return 2
    _write(argv[5], out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
