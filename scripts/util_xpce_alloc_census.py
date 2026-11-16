#!/usr/bin/env python3
"""util_xpce_alloc_census.py -- THE ALLOCATION CLASSES OF THE XPCE KERNEL LIBRARY, read from its built objects
(DESIGN-PLAN prolog-xpce step 2, the cio 2026-11-16; skill prolog reference, THE XPCE FACILITY; ENGINE.md 6.2).

A DIRECT ALLOCATION SITE is a relocation of a built object against malloc, calloc, realloc, strdup or free: what the compiled
kernel really calls, whatever the source spells. The table harness/xpce/ALLOC-CLASSES.tsv gives every site one class:
  KERNEL   the kernel itself releases the block: the site goes through the kernel's own three slots (pceMalloc, pceRealloc,
           pceFree), which SCRIP's binding points at the graphics arena. THE CONVERSION IS OF THE OBJECT, NOT OF THE SOURCE:
           objcopy renames the five names to xpce_k_malloc, xpce_k_calloc, xpce_k_realloc, xpce_k_strdup and xpce_k_free
           (xpce_host.c), in every object whose rows are all KERNEL. No source line and no source copy is changed.
  XOWNED   X or the C library itself releases or keeps the block (an image's data freed by XDestroyImage, an XpmImage freed
           by libXpm, argv handed to the toolkit, the environment handed to libc): it stays libc's.
  DEFAULT  the kernel's own default slots in itf/interface.c, the three functions pceMalloc calls when no host fills them.
A class is decided by who releases the block, never by who makes it.

  census BUILD          print every site of the objects under BUILD: object, function, callee, count, state
                        (state libc: the object still calls the libc name; kernel: it calls the xpce_k_ name)
  convert BUILD TABLE   read the census against TABLE, rename the five names in every object whose rows are all KERNEL,
                        read the census again, and write BUILD/ALLOC-CENSUS.tsv. Run twice it changes nothing.
  check CENSUS TABLE    read a written census (the one a build kept beside its library) against TABLE
rc 0 whole; rc 1 a site's state is not its class's (a KERNEL site still calls libc, or another calls the kernel's layer);
rc 2 REFUSE: a site with no row, a row with no site, a count that differs, an object that mixes KERNEL with another class
(no per-site conversion is built: no object of the tree mixes, MEASURED 2026-11-16), an unknown class, usage.
"""
import os
import re
import subprocess
import sys

LIBC = ("malloc", "calloc", "realloc", "strdup", "free")
KNAME = {n: "xpce_k_" + n for n in LIBC}
BACK = {v: k for k, v in KNAME.items()}
CLASSES = ("KERNEL", "XOWNED", "DEFAULT")
SECTION = re.compile(r"^Relocation section '\.rela([^']*)'")


def refuse(msg):
    print("REFUSE(2): " + msg)
    sys.exit(2)


def object_key(path):
    """The name a row uses for an object: the kernel's source path under src/, STREAM/<file> for the stream files, the bare file name for the recipe's own."""
    p = path[:-2] if path.endswith(".o") else path
    if "/streams/os/" in p:
        return "STREAM/" + p.split("/streams/os/", 1)[1]
    m = re.search(r"/xpce-[^/]*/src/(.+)$", p)
    if m:
        return m.group(1)
    return os.path.basename(p)


def function_of(section):
    """.text.NAME is the function NAME (the objects are compiled -ffunction-sections); a data section is named as it stands."""
    for pre in (".text.unlikely.", ".text.startup.", ".text.exit.", ".text.hot.", ".text."):
        if section.startswith(pre):
            return section[len(pre):]
    return "(" + section.lstrip(".") + ")"


def objects(build):
    out = []
    for dp, _dn, fn in os.walk(build):
        if "/CMakeFiles/" not in dp + "/" or "/CMakeFiles/find_names.dir" in dp or "/CompilerId" in dp or "/CMakeScratch" in dp or "/CMakeTmp" in dp:
            continue
        for n in fn:
            if n.endswith(".o"):
                out.append(os.path.join(dp, n))
    return sorted(out)


def census(build):
    """{(object, function, callee): [count, state]} over every object of the build."""
    sites = {}
    objs = objects(build)
    if not objs:
        refuse("no built object under %s" % build)
    for o in objs:
        r = subprocess.run(["readelf", "-rW", o], capture_output=True, text=True)
        if r.returncode != 0:
            refuse("readelf could not read %s: %s" % (o, r.stderr.strip()[:120]))
        key, fn = object_key(o), None
        for line in r.stdout.splitlines():
            m = SECTION.match(line)
            if m:
                fn = function_of(m.group(1))
                continue
            c = line.split()
            if len(c) < 5 or fn is None or fn == "(eh_frame)":
                continue
            sym = c[4]
            if sym in LIBC:
                callee, state = sym, "libc"
            elif sym in BACK:
                callee, state = BACK[sym], "kernel"
            else:
                continue
            k = (key, fn, callee)
            if k in sites and sites[k][1] != state:
                refuse("%s %s calls %s both as libc's and as the kernel's: an object half converted" % k)
            sites.setdefault(k, [0, state])[0] += 1
    return sites, objs


def read_table(path):
    rows = {}
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError as e:
        refuse("no class table at %s (%s)" % (path, e.strerror))
    for n, line in enumerate(lines, 1):
        if not line.strip() or line.startswith("#"):
            continue
        c = line.split("\t")
        if c[0] == "object":
            continue
        if len(c) < 5:
            refuse("%s line %d has %d cells, a row has object, function, callee, count, class and why" % (path, n, len(c)))
        if c[4] not in CLASSES:
            refuse("%s line %d: class %s is none of %s" % (path, n, c[4], " ".join(CLASSES)))
        if not c[3].isdigit():
            refuse("%s line %d: count %s is no number" % (path, n, c[3]))
        k = (c[0], c[1], c[2])
        if k in rows:
            refuse("%s line %d: a second row for %s %s %s" % ((path, n) + k))
        rows[k] = (int(c[3]), c[4])
    return rows


def read_census(path):
    sites = {}
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError as e:
        refuse("no census at %s (%s)" % (path, e.strerror))
    for line in lines:
        c = line.split("\t")
        if line.startswith("#") or len(c) < 5 or c[0] == "object":
            continue
        sites[(c[0], c[1], c[2])] = [int(c[3]), c[4]]
    return sites


def whole(sites, rows):
    """rc 2 unless every site has its row with its count and every row its site."""
    bad = []
    for k in sorted(sites):
        if k not in rows:
            bad.append("a site with no row: %s %s calls %s %d time(s)" % (k + (sites[k][0],)))
        elif rows[k][0] != sites[k][0]:
            bad.append("the count differs: %s %s calls %s %d time(s) and its row says %d" % (k + (sites[k][0], rows[k][0])))
    for k in sorted(rows):
        if k not in sites:
            bad.append("a row with no site: %s %s %s" % k)
    if bad:
        for b in bad[:12]:
            print("XPCE-ALLOC " + b)
        refuse("the class table is not whole: %d fault(s) (a site is a relocation of a built object; each needs one row)" % len(bad))


def classes_by_object(rows):
    by = {}
    for (obj, _fn, _callee), (_n, cls) in rows.items():
        by.setdefault(obj, set()).add(cls)
    return by


def states(sites, rows):
    """rc 1 when a site's state is not what its class says: KERNEL calls the kernel's layer, XOWNED and DEFAULT call libc."""
    bad = []
    for k in sorted(sites):
        want = "kernel" if rows[k][1] == "KERNEL" else "libc"
        if sites[k][1] != want:
            bad.append("%s %s calls %s as %s's and its class %s says %s's" % (k + (sites[k][1], rows[k][1], want)))
    for b in bad[:12]:
        print("XPCE-ALLOC " + b)
    return len(bad)


def tally(sites, rows):
    t = {c: 0 for c in CLASSES}
    for k, (n, _s) in sites.items():
        t[rows[k][1]] += n
    return " ".join("%s=%d" % (c, t[c]) for c in CLASSES) + " sites=%d rows=%d" % (sum(t.values()), len(rows))


def write_census(path, sites, rows):
    with open(path, "w", encoding="utf-8") as f:
        f.write("# ALLOC-CENSUS.tsv -- every direct allocation site of this build's objects as readelf -r reads them, after the conversion (util_xpce_alloc_census.py convert); state kernel: the object calls the xpce_k_ name\n")
        f.write("object\tfunction\tcallee\tcount\tstate\tclass\n")
        for k in sorted(sites):
            f.write("%s\t%s\t%s\t%d\t%s\t%s\n" % (k + (sites[k][0], sites[k][1], rows[k][1])))


def main(argv):
    if len(argv) == 3 and argv[1] == "census":
        sites, _objs = census(argv[2])
        print("object\tfunction\tcallee\tcount\tstate")
        for k in sorted(sites):
            print("%s\t%s\t%s\t%d\t%s" % (k + (sites[k][0], sites[k][1])))
        return 0
    if len(argv) == 4 and argv[1] == "convert":
        build, table = argv[2], argv[3]
        rows = read_table(table)
        sites, objs = census(build)
        whole(sites, rows)
        by = classes_by_object(rows)
        mixed = sorted(o for o, cs in by.items() if "KERNEL" in cs and len(cs) > 1)
        if mixed:
            refuse("an object mixes KERNEL with another class (%s): one object is converted whole or not at all, and no per-site conversion is built" % " ".join(mixed))
        args = []
        for n in LIBC:
            args += ["--redefine-sym", "%s=%s" % (n, KNAME[n])]
        done = 0
        for o in objs:
            if by.get(object_key(o)) == {"KERNEL"}:
                r = subprocess.run(["objcopy"] + args + [o], capture_output=True, text=True)
                if r.returncode != 0:
                    refuse("objcopy could not convert %s: %s" % (o, r.stderr.strip()[:120]))
                done += 1
        sites, _objs = census(build)
        whole(sites, rows)
        n = states(sites, rows)
        write_census(os.path.join(build, "ALLOC-CENSUS.tsv"), sites, rows)
        print("XPCE_ALLOC_BOARD %s objects converted=%d %s" % (tally(sites, rows), done, "CLASSES FAIL (%d)" % n if n else "CLASSES OK"))
        return 1 if n else 0
    if len(argv) == 4 and argv[1] == "check":
        rows = read_table(argv[3])
        sites = read_census(argv[2])
        whole(sites, rows)
        n = states(sites, rows)
        print("XPCE_ALLOC_BOARD %s %s" % (tally(sites, rows), "CLASSES FAIL (%d)" % n if n else "CLASSES OK"))
        return 1 if n else 0
    refuse("usage: util_xpce_alloc_census.py census BUILD | convert BUILD TABLE | check CENSUS TABLE")


if __name__ == "__main__":
    sys.exit(main(sys.argv))
