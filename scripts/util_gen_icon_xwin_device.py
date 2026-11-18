#!/usr/bin/env python3
"""util_gen_icon_xwin_device.py -- the Icon window facility's generated tree, W1 THE GENERATOR (skill icon reference.md section 9).

Copies the oracle's sources to scratch, writes define.h as Config linux and Graphics 1, redefines GRFX_ALLOC to the
collected record allocator, runs the oracle's own translator rtt -x over its six window .r sources (the device layer and
fwindow.r, the function layer) and the conversions cnv.r and def.r, converts every allocation call by the class its site has in the committed table
designs/icon_xwin/ALLOC-CLASSES.tsv, rewrites the includes so no line names a scratch path, copies the oracle's headers,
writes xwin_alloc.h (the class macros), xwin_gen.c (the record layouts, the roots, the detached-image hook) and
xwin_functions.tsv (the 48 functions from their headers), xwin_builtins.tsv (their rows of src/runtime/builtins.tsv)
and xwin_entries.c (one bt_ entry a function, into the adapter rt_xwin_call_h; officer_01's format) and
xwin_exports.map (the linker version script exporting those 48 entries and xwin_kywd_addr, the shim's, and nothing else),
rewrites every read of a list block's size into xwin_list_size (refusing a tree that still reads a list block's member), applies designs/icon_xwin/xwin.patch and writes the tree to
--out with XWIN-MANIFEST.tsv. xwin_shim.h, W3's shim header, is hand-written: if it stands in the tree the gate does not
compare it and --out keeps it; the generated files include none of it (h/rt.h declares the runtime names they call). Nothing under the oracle tree is written; the scratch is removed unless --keep.

  --out DIR        write the tree (DIR absent, empty, or a tree this script wrote)
  --check DIR      regenerate and compare with DIR byte for byte: the gate, generated plus patch
  --classes        print every site of the translated C with its class; a site no row names, or a row no site has, is refused
  --no-patch       write the tree without the patch (to remake the patch: diff -ru the two trees)
  --syntax         gcc -fsyntax-only every .c of the tree
  --merge-builtins TSV  with --out or --check: write the 48 rows of xwin_builtins.tsv into SCRIP's builtins.tsv, an xwin
                   row already there keeping its bid, a new one taking the next free id, each with flags xwin (the merge
                   sets it, so the tree's own rows carry none: the by-name dispatch resolves such a row's entry in the
                   window object through rt_xwin_sym; officer_01 2026-11-16, W5)
  --link-census    compile the tree and name what it needs from outside; a call of the C allocator left is rc 1
rc 0 made, equal or classed; rc 1 the translator, the patch, a syntax check or the comparison failed (named);
rc 2 refused (a source missing, a site with no class, a row with no site, a scratch path left, usage).
"""
import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
HARNESS = os.path.dirname(HERE)
CC_SLOT = next(p for p in (os.path.join(HERE, "util_cc_slot.sh"), "/home/harness/scripts/util_cc_slot.sh") if os.path.isfile(p) or p.startswith("/home/harness/"))
DESIGNS = os.path.join(HARNESS, "designs", "icon_xwin")
DIALECTS = ("arizona", "unicon")
D = {}
report_reads = []


def load_dialect(name):
    path = os.path.join(DESIGNS, name, "DIALECT.tsv")
    if name not in DIALECTS or not os.path.isfile(path):
        raise Refuse("no dialect %s: %s is missing (dialects: %s)" % (name, path, " ".join(DIALECTS)))
    d = {"name": name, "source": [], "include": [], "config": [], "own_data": [], "by_value": {}, "export": [],
         "carry": [], "cc_include": [], "translator_args": "-x", "config_mode": "replace", "plain": None, "arena_define": [], "arena_source": None, "macro_reads": "refuse"}
    for n, line in enumerate(open(path), 1):
        if not line.strip() or line.startswith("#"):
            continue
        k, _, v = line.rstrip("\n").partition("\t")
        if k in ("source", "include", "config", "export", "carry", "cc_include", "arena_define"):
            d[k].append(v)
        elif k == "own_data":
            d[k].append(tuple(v.split()))
        elif k == "by_value":
            a, b = v.split()
            d[k][a] = b
        elif k in ("src", "translator", "translator_place", "translator_args", "plain", "config_file", "config_mode", "functions", "arena_source"):
            d[k] = v
        elif k == "macro_reads" and v in ("refuse", "measure"):
            d[k] = v
        else:
            raise Refuse("%s:%d key %s is unknown" % (path, n, k))
    for k in ("src", "translator", "translator_place", "config_file", "functions"):
        if k not in d:
            raise Refuse("%s names no %s" % (path, k))
    d["functions"] = int(d["functions"])
    d["table"] = os.path.join(DESIGNS, name, "ALLOC-CLASSES.tsv")
    d["patch"] = os.path.join(DESIGNS, name, "xwin.patch")
    d["reads"] = os.path.join(DESIGNS, name, "READ-CLASSES.tsv")
    D.clear()
    D.update(d)
    return d
MANIFEST = "XWIN-MANIFEST.tsv"
HAND_WRITTEN = ("xwin_shim.h",)
GRFX_OLD = "var = (struct type *)calloc(1, sizeof(struct type));"
GRFX_NEW = "var = (struct type *)XWIN_LREC(type);"
CALL_RE = re.compile(r"(?<![\w.>$])(malloc|calloc|realloc|salloc|alloc|strdup|free)\s*\(")
XFREE_RE = re.compile(r"(?<![\w.>$])XFree\s*\(")
LREC_RE = re.compile(r"(\w+)\s*=\s*\(struct (\w+) \*\)XWIN_LREC\((\w+)\)")
CLASSES = ("RECORD", "HELD", "PTRS", "ROOTED", "CALLEXT", "SCRATCH", "RECS")
MACRO_DEFS = {
    ("HELD", "malloc"): "#define XWIN_HELD_MALLOC(n) rt_ws_alloc_raw((size_t)(n))",
    ("HELD", "calloc"): "#define XWIN_HELD_CALLOC(n, s) xwin_calloc_raw((size_t)(n), (size_t)(s))",
    ("HELD", "salloc"): "#define XWIN_HELD_SALLOC(s) xwin_salloc_raw(s)",
    ("HELD", "realloc"): "#define XWIN_HELD_REALLOC(p, n) rt_rvec_realloc((p), (size_t)(n))",
    ("ROOTED", "malloc"): "#define XWIN_ROOTED_MALLOC(n) rt_ws_alloc_raw((size_t)(n))",
    ("CALLEXT", "malloc"): "#define XWIN_CALLEXT_MALLOC(n) rt_ws_alloc_raw((size_t)(n))",
    ("PTRS", "alloc"): "#define XWIN_PTRS_ALLOC(n) rt_lrec_alloc((size_t)(n), xwin_layout_ptrs)",
    ("PTRS", "realloc"): "#define XWIN_PTRS_REALLOC(p, n) rt_lrec_realloc((p), (size_t)(n), xwin_layout_ptrs)",
    ("SCRATCH", "malloc"): "#define XWIN_SCRATCH_MALLOC(n) __builtin_alloca((size_t)(n))",
    ("HELD", "strdup"): "#define XWIN_HELD_STRDUP(s) xwin_salloc_raw(s)",
    ("CALLEXT", "strdup"): "#define XWIN_CALLEXT_STRDUP(s) xwin_salloc_raw(s)",
    ("CALLEXT", "calloc"): "#define XWIN_CALLEXT_CALLOC(n, s) xwin_calloc_raw((size_t)(n), (size_t)(s))",
    ("CALLEXT", "realloc"): "#define XWIN_CALLEXT_REALLOC(p, n) rt_rvec_realloc((p), (size_t)(n))",
    ("PTRS", "malloc"): "#define XWIN_PTRS_MALLOC(n) rt_lrec_alloc((size_t)(n), xwin_layout_ptrs)",
    ("SCRATCH", "calloc"): "#define XWIN_SCRATCH_CALLOC(n, s) memset(__builtin_alloca((size_t)(n) * (size_t)(s)), 0, (size_t)(n) * (size_t)(s))",
}
BUILTIN_BASES = {"char", "short", "int", "long", "unsigned", "signed", "void", "float", "double"}


class Refuse(Exception):
    pass


class Fail(Exception):
    pass


def tail(text):
    return (text or "").strip()[-400:]


def load_table(path):
    if not os.path.isfile(path):
        raise Refuse("the class table %s is missing" % path)
    sites, roots = [], []
    for n, line in enumerate(open(path), 1):
        if not line.strip() or line.startswith("#"):
            continue
        f = line.rstrip("\n").split("\t")
        if len(f) < 6:
            raise Refuse("%s:%d has %d columns, wants 7" % (path, n, len(f)))
        kind, source, lno, call, target, cls = f[:6]
        if kind == "site":
            if cls.split(":")[0] not in CLASSES:
                raise Refuse("%s:%d class %s is none of %s" % (path, n, cls, " ".join(CLASSES)))
            sites.append({"source": source, "line": int(lno), "call": call, "target": target, "cls": cls, "row": n, "seen": 0})
        elif kind == "root":
            if call not in ("ptr", "descr"):
                raise Refuse("%s:%d root kind %s is neither ptr nor descr" % (path, n, call))
            roots.append({"source": source, "kind": call, "name": target, "row": n})
        else:
            raise Refuse("%s:%d row kind %s is neither site nor root" % (path, n, kind))
    return sites, roots


def translate(src, scratch, raw=False, extra_config=()):
    top = scratch
    scratch = os.path.join(top, "src")
    shutil.copytree(os.path.join(src, "h"), os.path.join(scratch, "h"))
    shutil.copytree(os.path.join(src, "runtime"), os.path.join(scratch, "runtime"))
    for c in D["carry"]:
        shutil.copytree(os.path.join(src, c), os.path.join(scratch, c), ignore=shutil.ignore_patterns("*.o", "*.a"))
    if D["plain"]:
        os.makedirs(os.path.join(scratch, os.path.dirname(D["plain"])), exist_ok=True)
        shutil.copyfile(os.path.join(src, D["plain"]), os.path.join(scratch, D["plain"]))
    cfg = os.path.join(scratch, D["config_file"])
    body = "".join(l + "\n" for l in list(D["config"]) + list(extra_config))
    if D["config_mode"] == "append":
        body = open(cfg).read() + body
    with open(cfg, "w") as f:
        f.write(body)
    grttin = os.path.join(scratch, "h", "grttin.h")
    text = open(grttin).read()
    if raw:
        pass
    elif text.count(GRFX_OLD) != 1:
        raise Refuse("h/grttin.h holds %d copies of the GRFX_ALLOC body %r, wants 1" % (text.count(GRFX_OLD), GRFX_OLD))
    if not raw:
        with open(grttin, "w") as f:
            f.write(text.replace(GRFX_OLD, GRFX_NEW))
    rtt = os.path.join(top, D["translator_place"])
    os.makedirs(os.path.dirname(rtt), exist_ok=True)
    shutil.copy2(os.path.join(src, D["translator"]), rtt)
    rt = os.path.join(scratch, "runtime")
    r = subprocess.run([rtt] + D["translator_args"].split() + D["source"], cwd=rt, capture_output=True, text=True)
    if r.returncode != 0:
        raise Fail("translator rc=%d: %s" % (r.returncode, tail(r.stderr or r.stdout)))
    cfiles = [os.path.join(rt, "x" + name[:-2] + ".c") for name in D["source"]]
    if D["plain"]:
        cfiles.append(os.path.join(scratch, D["plain"]))
    for p in cfiles:
        if not os.path.isfile(p):
            raise Fail("not made: %s" % os.path.basename(p))
    return cfiles


def balanced(text, open_at):
    depth = 0
    for i in range(open_at, len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return i
    raise Refuse("unbalanced call at %r" % text[open_at:open_at + 60])


def census(path):
    lines = open(path, errors="surrogateescape").read().split("\n")
    out = []
    src, n, use_src, use_line = None, 0, None, 0
    for i, line in enumerate(lines):
        m = re.match(r'#line (\d+) "([^"]*)"', line)
        if m:
            name = os.path.basename(m.group(2))
            if name.endswith(".h"):
                if src and not src.endswith(".h"):
                    use_src, use_line = src, n
            else:
                use_src, use_line = None, 0
            src, n = name, int(m.group(1))
            continue
        for mm in CALL_RE.finditer(line):
            out.append({"idx": i, "pos": mm.start(), "call": mm.group(1), "source": src, "line": n})
        for mm in XFREE_RE.finditer(line):
            out.append({"idx": i, "pos": mm.start(), "call": "XFree", "source": src, "line": n})
        for mm in LREC_RE.finditer(line):
            if mm.group(2) != mm.group(3):
                raise Refuse("%s line %d: XWIN_LREC(%s) cast to struct %s" % (os.path.basename(path), i + 1, mm.group(3), mm.group(2)))
            out.append({"idx": i, "pos": mm.start(), "call": "GRFX_ALLOC:" + mm.group(3), "var": mm.group(1),
                        "source": use_src or src, "line": use_line or n})
        n += 1
    return lines, out


def strip_cast(arg):
    arg = arg.strip()
    m = re.match(r"^\(\s*\w+\s*\**\s*\)\s*(.*)$", arg)
    return (m.group(1) if m else arg).strip()


def find_row(sites, s):
    for r in sites:
        if r["source"] == s["source"] and r["call"] == s["call"]:
            if r["line"] == s["line"] or (s["call"].startswith("GRFX_ALLOC:") and r["target"] == s.get("var")):
                return r
    return None


def classify_and_convert(cfiles, sites, report):
    used = set()
    converted = {}
    for path in cfiles:
        lines, found = census(path)
        edits = {}
        for s in found:
            row = find_row(sites, s)
            if s["call"].startswith("GRFX_ALLOC:"):
                if row is None or row["target"] != s["var"]:
                    raise Refuse("%s %s:%d %s(%s) has no RECORD row in the class table" % (os.path.basename(path), s["source"], s["line"], s["call"], s.get("var")))
                row["seen"] += 1
                report.append((s["source"], row["line"], s["call"], row["target"], row["cls"]))
                continue
            if s["call"] == "XFree" and row is None:
                continue
            if s["call"] == "free" and row is None:
                edits.setdefault(s["idx"], []).append((s["pos"], "free", None))
                continue
            if row is None:
                raise Refuse("%s %s:%d %s has no class: no row of the class table names it (text: %s)" % (os.path.basename(path), s["source"], s["line"], s["call"], lines[s["idx"]].strip()[:100]))
            row["seen"] += 1
            report.append((s["source"], s["line"], s["call"], row["target"], row["cls"]))
            edits.setdefault(s["idx"], []).append((s["pos"], s["call"], row))
        for idx, es in edits.items():
            line = lines[idx]
            for pos, call, row in sorted(es, key=lambda e: -e[0]):
                op = line.index("(", pos)
                cl = balanced(line, op) if (row is not None and (call in ("free", "XFree") or row["cls"].startswith("RECORD:"))) else None
                if row is None:
                    line = line[:pos] + "XWIN_FREE" + line[op:]
                elif call in ("free", "XFree"):
                    if row["cls"] != "CALLEXT":
                        raise Refuse("class table row %d: a free row must be CALLEXT, is %s" % (row["row"], row["cls"]))
                    arg = strip_cast(line[op + 1:cl])
                    if arg != row["target"]:
                        raise Refuse("class table row %d: free(%s) is not of %s" % (row["row"], arg, row["target"]))
                    line = line[:pos] + "XWIN_FREE_NULL(" + arg + ")" + line[cl + 1:]
                elif row["cls"].startswith("RECS:"):
                    tag = row["cls"].split(":", 1)[1]
                    if call not in ("malloc", "realloc"):
                        raise Refuse("class table row %d: RECS:%s takes malloc or realloc, the site reads %s" % (row["row"], tag, call))
                    line = line[:pos] + "XWIN_RECS_%s(%s, " % (call.upper(), tag) + line[op + 1:]
                elif row["cls"].startswith("RECORD:"):
                    tag = row["cls"].split(":", 1)[1]
                    arg = line[op + 1:cl].strip()
                    if call != "malloc" or arg != "sizeof(struct %s)" % tag:
                        raise Refuse("class table row %d: RECORD:%s wants malloc(sizeof(struct %s)), the site reads %s(%s)" % (row["row"], tag, tag, call, arg))
                    line = line[:pos] + "XWIN_LREC(" + tag + ")" + line[cl + 1:]
                else:
                    key = (row["cls"], call)
                    if key not in MACRO_DEFS:
                        raise Refuse("class table row %d: class %s has no form for %s" % (row["row"], row["cls"], call))
                    used.add(key)
                    line = line[:pos] + "XWIN_%s_%s" % (row["cls"], call.upper()) + line[op:]
            lines[idx] = line
        converted[path] = lines
    stale = [r for r in sites if r["seen"] == 0]
    if stale:
        raise Refuse("%d row(s) of the class table name no site of the translated C: %s" % (len(stale), ", ".join("row %d %s:%d %s" % (r["row"], r["source"], r["line"], r["call"]) for r in stale)))
    twice = [r for r in sites if r["seen"] > 1]
    if twice:
        raise Refuse("class table rows naming more than one site: %s" % ", ".join("%d" % r["row"] for r in twice))
    return converted, used


def post_pass(lines, scratch, raw=False):
    out = []
    marker = scratch.rstrip("/") + "/"
    for i, line in enumerate(lines):
        if i < 4 and re.match(r"^ \* \w{3} \w{3} [ \d]\d \d\d:\d\d:\d\d \d{4}$", line):
            out.append(" * generated by util_gen_icon_xwin_device.py; regenerated, never edited")
            continue
        if re.match(r'^#include "%s[^"]*/h/rt\.h"$' % re.escape(marker), line):
            if not raw:
                out.append('#include "xwin_alloc.h"')
            out.append('#include "h/rt.h"')
            continue
        line = re.sub(r'"%s[^"]*?/h/' % re.escape(marker), '"h/', line)
        line = line.replace('"../h/', '"h/')
        if marker in line or "/tmp/" in line:
            raise Refuse("a scratch path is left after the include post-pass: %s" % line.strip()[:120])
        out.append(line)
    return out


def oracle_types(segs):
    text = "".join(t for f, t in segs if "/h/" in f and f.endswith(".h") and not f.startswith("/usr/"))
    tags = set(re.findall(r"\bstruct\s+(\w+)\s*\{", text))
    ptr_typedefs, plain_typedefs = set(), {}
    depth, start = 0, 0
    for i, c in enumerate(text):
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        elif c == ";" and depth == 0:
            stmt = " ".join(text[start:i].split())
            start = i + 1
            if not stmt.startswith("typedef ") or "(" in stmt.split("}")[-1]:
                continue
            if "}" in stmt:
                base = stmt[len("typedef "):stmt.index("{")].strip()
                decls = stmt[stmt.rindex("}") + 1:]
            else:
                parts = stmt[len("typedef "):].rsplit(None, 1)
                if len(parts) != 2:
                    continue
                base, decls = parts[0], parts[1]
                while base.endswith("*"):
                    base, decls = base[:-1].strip(), "*" + decls
            for d in decls.split(","):
                d = d.strip()
                if not d:
                    continue
                name = d.lstrip("* ").split("[")[0].strip()
                if d.startswith("*"):
                    ptr_typedefs.add(name)
                else:
                    plain_typedefs[name] = base
    return tags, ptr_typedefs, plain_typedefs


def struct_body(pp, tag):
    m = re.search(r"\bstruct\s+%s\s*\{" % re.escape(tag), pp)
    if not m:
        raise Refuse("struct %s is declared in no header the window sources include" % tag)
    depth = 0
    for i in range(m.end() - 1, len(pp)):
        if pp[i] == "{":
            depth += 1
        elif pp[i] == "}":
            depth -= 1
            if depth == 0:
                return pp[m.end():i]
    raise Refuse("struct %s has no closing brace" % tag)


def top_decls(body):
    out, depth, start = [], 0, 0
    for i, c in enumerate(body):
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        elif c == ";" and depth == 0:
            if body[start:i].strip():
                out.append(body[start:i].strip())
            start = i + 1
    return out


def layout_fields(pp, tag, types, prefix="", body=None):
    tags, ptr_typedefs, plain_typedefs = types
    body = " ".join((struct_body(pp, tag) if body is None else body).split())
    out = []
    for decl in top_decls(body):
        if "{" in decl:
            m = re.match(r"^(struct|union)\s*\w*\s*\{(.*)\}\s*(\w+)\s*$", decl)
            if not m:
                raise Refuse("struct %s holds a field the layout pass cannot read: %s" % (tag, decl[:80]))
            inner = layout_fields(pp, tag, types, prefix + m.group(3) + ".", m.group(2))
            if m.group(1) == "union" and inner:
                raise Refuse("struct %s holds a union %s with a pointer or a descriptor: a shape the layout has no word for" % (tag, m.group(3)))
            out.extend(inner)
            continue
        if "(" in decl:
            raise Refuse("struct %s holds a field the layout pass cannot read: %s" % (tag, decl))
        parts = [p.strip() for p in decl.split(",")]
        m = re.match(r"^(.*?)([\s*]+)(\w+)\s*(\[[^\]]*\])?$", parts[0])
        if not m:
            raise Refuse("struct %s field %r is not read" % (tag, parts[0]))
        base = m.group(1).strip()
        dcls = [(m.group(2).count("*"), m.group(3), m.group(4))]
        for p in parts[1:]:
            mm = re.match(r"^(\**)\s*(\w+)\s*(\[[^\]]*\])?$", p)
            if not mm:
                raise Refuse("struct %s field %r is not read" % (tag, p))
            dcls.append((len(mm.group(1)), mm.group(2), mm.group(3)))
        words = base.replace("const ", "").split()
        own_struct = len(words) == 2 and words[0] == "struct" and words[1] in tags
        own_name = len(words) == 1 and (words[0] in ptr_typedefs or words[0] in plain_typedefs)
        builtin = all(w in BUILTIN_BASES for w in words)
        for stars, name, arr in dcls:
            path = prefix + name
            kind = 0
            if stars == 0 and words == ["struct", "descrip"]:
                kind = 2
            elif stars > 0 and (builtin or own_struct or own_name):
                kind = 1
            elif stars == 0 and len(words) == 1 and words[0] in ptr_typedefs:
                kind = 1
            elif stars == 0 and own_struct:
                out.extend(layout_fields(pp, words[1], types, path + "."))
                continue
            elif stars == 0 and len(words) == 1 and words[0] in plain_typedefs:
                pb = plain_typedefs[words[0]].split()
                if len(pb) == 2 and pb[0] == "struct" and pb[1] in tags:
                    out.extend(layout_fields(pp, pb[1], types, path + "."))
                    continue
            if kind and arr:
                raise Refuse("struct %s field %s is an array of %s, a shape the layout has no word for" % (tag, path, "descriptors" if kind == 2 else "pointers"))
            if kind:
                out.append((path, kind))
    return out


def preprocess(tree):
    probe = os.path.join(tree, ".xwin_probe.c")
    with open(probe, "w") as f:
        f.write('#include "h/rt.h"\n')
    r = subprocess.run(["bash", CC_SLOT, "gcc", "-E"] + tree_includes() + [".xwin_probe.c"], cwd=tree, capture_output=True, text=True)
    os.unlink(probe)
    if r.returncode != 0:
        raise Fail("preprocessing h/rt.h for the layouts rc=%d: %s" % (r.returncode, tail(r.stderr)))
    segs, cur, buf = [], "", []
    for line in r.stdout.split("\n"):
        m = re.match(r'^# \d+ "([^"]*)"', line)
        if m:
            segs.append((cur, "\n".join(buf) + "\n"))
            cur, buf = m.group(1), []
            continue
        buf.append(line)
    segs.append((cur, "\n".join(buf) + "\n"))
    return "".join(t for f, t in segs), segs


def recs_tags(sites):
    tags = []
    for r in sites:
        if r["cls"].startswith("RECS:"):
            tag = r["cls"].split(":", 1)[1]
            if tag not in tags:
                tags.append(tag)
    return tags


def record_tags(sites):
    tags = []
    for r in sites:
        tag = None
        if r["call"].startswith("GRFX_ALLOC:"):
            tag = r["call"].split(":", 1)[1]
        elif r["cls"].startswith("RECORD:"):
            tag = r["cls"].split(":", 1)[1]
        if tag and tag not in tags:
            tags.append(tag)
    return tags


def carry_headers(scratch, tree):
    if not D["carry"]:
        return
    src = os.path.join(scratch, "src")
    probe = os.path.join(src, ".xwin_probe.c")
    with open(probe, "w") as f:
        f.write('#include "h/rt.h"\n')
    r = subprocess.run(["bash", CC_SLOT, "gcc", "-M"] + tree_includes() + [".xwin_probe.c"], cwd=src, capture_output=True, text=True)
    os.unlink(probe)
    if r.returncode != 0:
        raise Fail("gcc -M of h/rt.h for the carried headers rc=%d: %s" % (r.returncode, tail(r.stderr)))
    for dep in r.stdout.replace("\\\n", " ").split()[1:]:
        full = os.path.normpath(os.path.join(src, dep))
        rel = os.path.relpath(full, src)
        if rel.split(os.sep)[0] in D["carry"]:
            os.makedirs(os.path.join(tree, os.path.dirname(rel)), exist_ok=True)
            shutil.copyfile(full, os.path.join(tree, rel))


def write_alloc_h(tree, tags, used, rtags=()):
    lines = ["#ifndef XWIN_ALLOC_H", "#define XWIN_ALLOC_H", "#include <stddef.h>", "#include <stdint.h>", "#include <string.h>",
             "void *rt_lrec_alloc(size_t nbytes, const uint64_t *layout);",
             "void *rt_lrec_realloc(void *p, size_t nbytes, const uint64_t *layout);",
             "void *rt_ws_alloc_raw(size_t nbytes);",
             "struct _XImage;",
             "int xwin_detached_destroy(struct _XImage *im);",
             "struct descrip;",
             "long xwin_list_size(struct descrip *d);"]
    for name, fn in sorted(D["by_value"].items()):
        lines.append("struct descrip %s(void);" % fn)
        lines.append("#define %s %s()" % (name, fn))
    lines += [

             "#define XWIN_LW(off, kind) (((uint64_t)(off) << 8) | (uint64_t)(kind))",
             "#define XWIN_LK_PTR 1",
             "#define XWIN_LK_DESCR 2",
             "#define XWIN_LK_PTRS_TO_END 3"]
    for t in tags:
        lines.append("extern const uint64_t xwin_layout_%s[];" % t)
    lines.append("extern const uint64_t xwin_layout_ptrs[];")
    for t_ in rtags:
        lines.append("extern const uint64_t xwin_layout_recs_%s[];" % t_)
    if rtags:
        lines.append("#define XWIN_LK_RECS_STRIDE 4")
        lines.append("#define XWIN_RECS_MALLOC(tag, n) rt_lrec_alloc((size_t)(n), xwin_layout_recs_##tag)")
        lines.append("#define XWIN_RECS_REALLOC(tag, p, n) rt_lrec_realloc((p), (size_t)(n), xwin_layout_recs_##tag)")
    lines.append("#define XWIN_LREC(tag) rt_lrec_alloc(sizeof(struct tag), xwin_layout_##tag)")
    lines.append("static inline void *xwin_calloc_raw(size_t n, size_t s) { void *p = rt_ws_alloc_raw(n * s); if (p) memset(p, 0, n * s); return p; }")
    lines.append("static inline char *xwin_salloc_raw(const char *s) { size_t n = strlen(s) + 1; char *p = (char *)rt_ws_alloc_raw(n); if (p) memcpy(p, s, n); return p; }")
    if ("HELD", "realloc") in used or ("CALLEXT", "realloc") in used:
        lines.append("void *rt_rvec_realloc(void *p, size_t nbytes);")
    for key in sorted(used):
        lines.append(MACRO_DEFS[key])
    lines.append("#define XWIN_FREE(p) ((void)0)")
    lines.append("#define XWIN_FREE_NULL(p) ((p) = 0)")
    lines.append("#endif")
    with open(os.path.join(tree, "xwin_alloc.h"), "w") as f:
        f.write("\n".join(lines) + "\n")


def own_data(src):
    out = []
    for name, source in D["own_data"]:
        text = open(os.path.join(src, "runtime", source)).read()
        m = re.search(r"(?m)^([A-Za-z_][\w ]*?[\s*]+%s\b[^;]*;)" % re.escape(name), text)
        if not m:
            raise Refuse("runtime/%s has no file-scope definition of %s" % (source, name))
        out.append(" ".join(m.group(1).split()))
    return out


READ_CLASSES = ("PENDING", "OWNFILE", "CNV", "DEAD", "V3D")


def load_reads(path):
    if not os.path.isfile(path):
        raise Refuse("the read table %s is missing" % path)
    rows = {}
    for n, line in enumerate(open(path), 1):
        if not line.strip() or line.startswith("#"):
            continue
        f = line.rstrip("\n").split("\t")
        if len(f) < 6 or f[0] != "read":
            raise Refuse("%s:%d is no read row (read, source, line, block, reads, class, why)" % (path, n))
        if f[5] not in READ_CLASSES:
            raise Refuse("%s:%d class %s is none of %s" % (path, n, f[5], " ".join(READ_CLASSES)))
        rows[(f[1], int(f[2]), f[3])] = {"count": int(f[4]), "cls": f[5], "row": n, "seen": 0}
    return rows


def read_sites(line):
    out = []
    for mm in re.finditer(r"BlkLoc\(", line):
        cl = balanced(line, mm.end() - 1)
        m2 = re.match(r"\s*->\s*(\w+)\s*\.(\w+)", line[cl + 1:])
        if m2:
            out.append((mm.start(), cl + 1 + m2.end(), m2.group(1), m2.group(2), line[mm.end():cl]))
    for mm in re.finditer(r"BlkD\(", line):
        cl = balanced(line, mm.end() - 1)
        m2 = re.match(r"^(.*),\s*(\w+)\s*$", line[mm.end():cl])
        if m2:
            m3 = re.match(r"\s*->\s*(\w+)", line[cl + 1:])
            out.append((mm.start(), cl + 1 + (m3.end() if m3 else 0), m2.group(2), m3.group(1) if m3 else None, m2.group(1).strip()))
    return out


def read_pass(lines, path, rows, report, src=None, unrowed=None):
    n = 1 if src else 0
    out = []
    for line in lines:
        m = re.match(r'#line (\d+) "([^"]*)"', line)
        if m:
            src, n = os.path.basename(m.group(2)), int(m.group(1))
            out.append(line)
            continue
        for start, end, block, member, operand in sorted(read_sites(line), key=lambda s: -s[0]):
            row = rows.get((src, n, block))
            if row is None and unrowed is not None:
                unrowed.append("%s:%d %s.%s" % (src, n, block, member))
                continue
            if row is None:
                raise Refuse("%s %s:%d reads a %s block raw and no row of the read table names it: %s" % (os.path.basename(path), src, n, block, line.strip()[:100]))
            row["seen"] += 1
            if row["cls"] == "PENDING":
                if block not in ("list", "List") or member != "size":
                    raise Refuse("%s %s:%d a PENDING read must be a list's size, reads %s %s" % (os.path.basename(path), src, n, block, member))
                line = line[:start] + "xwin_list_size(&(" + operand + "))" + line[end:]
        n += 1
        out.append(line)
    return out


def compile_headers(tree):
    hs = set()
    for n in c_sources(tree):
        r = subprocess.run(["bash", CC_SLOT, "gcc", "-M", "-MG"] + cc_flags(n) + [n], cwd=tree, capture_output=True, text=True)
        if r.returncode != 0:
            raise Fail("gcc -M %s for the headers the C compile reads rc=%d: %s" % (n, r.returncode, tail(r.stderr)))
        for dep in r.stdout.replace("\\\n", " ").split()[1:]:
            rel = os.path.relpath(os.path.normpath(os.path.join(tree, dep)), tree)
            if rel.endswith(".h") and not rel.startswith("..") and os.path.isfile(os.path.join(tree, rel)):
                hs.add(rel)
    return sorted(hs)


def header_pass(tree, rows, report):
    hs = compile_headers(tree)
    unrowed = [] if D["macro_reads"] == "measure" else None
    for rel in hs:
        p = os.path.join(tree, rel)
        lines = open(p, errors="surrogateescape").read().split("\n")
        out = read_pass(lines, p, rows, report, src=os.path.basename(rel), unrowed=unrowed)
        if out != lines:
            with open(p, "w", errors="surrogateescape") as f:
                f.write("\n".join(out))
    if unrowed:
        report.append("MEASURED header reads with no row (macro_reads measure, nothing refused): %d: %s" % (len(unrowed), " ".join(unrowed)))
    return hs


def pp_census(tree, rows, hs, scratch, report):
    work = os.path.join(scratch, "ppcensus")
    shutil.copytree(tree, work)
    marks = {}
    for rel in hs:
        p = os.path.join(work, rel)
        lines = open(p, errors="surrogateescape").read().split("\n")
        for i, line in enumerate(lines):
            for start, end, block, member, operand in sorted(read_sites(line), key=lambda s: -s[0]):
                k = (os.path.basename(rel), i + 1, block)
                marks.setdefault(k, len(marks))
                line = line[:start] + "XWIN_RD_%d(" % marks[k] + line[start + len("BlkLoc("):]
            lines[i] = line
        text = "\n".join(lines)
        text, nb = re.subn(r"#define\s+BlkLoc\(", "#define XWIN_PP_BlkLoc(", text)
        with open(p, "w", errors="surrogateescape") as f:
            f.write(text)
    ids = {v: k for k, v in marks.items()}
    used, bad = {}, []
    for n in c_sources(work):
        direct = {}
        src, ln = None, 0
        for line in open(os.path.join(work, n), errors="surrogateescape").read().split("\n"):
            m = re.match(r'#line (\d+) "([^"]*)"', line)
            if m:
                src, ln = os.path.basename(m.group(2)), int(m.group(1))
                continue
            for s in read_sites(line):
                direct[(src, ln, s[2])] = direct.get((src, ln, s[2]), 0) + 1
            ln += 1
        r = subprocess.run(["bash", CC_SLOT, "gcc", "-E"] + cc_flags(n) + [n], cwd=work, capture_output=True, text=True, errors="surrogateescape")
        if r.returncode != 0:
            raise Fail("gcc -E %s for the read census rc=%d: %s" % (n, r.returncode, tail(r.stderr)))
        plain = {}
        src, ln = None, 0
        for line in r.stdout.split("\n"):
            m = re.match(r'# (\d+) "([^"]*)"', line)
            if m:
                src, ln = os.path.basename(m.group(2)), int(m.group(1))
                continue
            for mm in re.finditer(r"XWIN_RD_(\d+)\(", line):
                k = ids[int(mm.group(1))]
                used.setdefault(k, set()).add("%s %s:%d" % (n, src, ln))
            for s in read_sites(line):
                plain[(src, ln, s[2])] = plain.get((src, ln, s[2]), 0) + 1
            ln += 1
        bad += ["%s %s:%d reads a %s block raw through a macro: %d after the preprocessor, %d in the text" % (n, k[0], k[1], k[2], c, direct.get(k, 0)) for k, c in sorted(plain.items(), key=str) if c > direct.get(k, 0)]
    for k, where in sorted(used.items()):
        row = rows.get(k)
        if row is None:
            bad.append("%s:%d reads a %s block raw and no row of the read table names it (expanded at %s)" % (k[0], k[1], k[2], ", ".join(sorted(where)[:4])))
        elif row["cls"] == "DEAD":
            bad.append("%s:%d is classed DEAD and is expanded at %s" % (k[0], k[1], ", ".join(sorted(where)[:4])))
    if bad and D["macro_reads"] == "measure":
        report.append("MEASURED after the preprocessor (macro_reads measure, nothing refused): %d: %s" % (len(bad), "; ".join(bad)))
    elif bad:
        raise Refuse("the read census after the preprocessor: %s" % "; ".join(bad[:8]))
    report.append("MACRO sites=%d expanded=%d uses=%d" % (len(marks), len(used), sum(len(w) for w in used.values())))
    shutil.rmtree(work)


def check_reads(rows, report):
    bad = ["row %d %s:%d %s reads %d, counted %d" % (r["row"], k[0], k[1], k[2], r["count"], r["seen"]) for k, r in sorted(rows.items()) if r["seen"] != r["count"]]
    if bad:
        raise Refuse("%d read row(s) disagree with the translated C: %s" % (len(bad), "; ".join(bad[:8])))
    tally = {}
    for k, r in rows.items():
        a = tally.setdefault(r["cls"], [0, 0])
        a[0] += 1
        a[1] += r["count"]
    report.extend("%s sites=%d reads=%d" % (c, tally[c][0], tally[c][1]) for c in READ_CLASSES if c in tally)


def write_gen_c(tree, tags, roots, pp, segs, by_source, src, rtags=()):
    types = oracle_types(segs)
    lines = ['#include "xwin_alloc.h"', '#include "h/rt.h"']
    lines += own_data(src)
    own = set(n for n, s in D["own_data"])
    for r in roots:
        if r["name"].split("[")[0] in own:
            continue
        text = by_source.get(r["source"], "")
        m = re.search(r"(?m)^([A-Za-z_][\w ]*?[\s*]+)%s\b\s*(=[^;]*)?;" % re.escape(r["name"]), text)
        if not m:
            raise Refuse("root %s (class table row %d) has no file-scope definition in the translation of %s" % (r["name"], r["row"], r["source"]))
        if not re.search(r"\bextern\b[^;]*\b%s\s*;" % re.escape(r["name"]), pp):
            lines.append("extern %s%s;" % (m.group(1).replace("static ", ""), r["name"]))
        if m.group(1).startswith("static"):
            raise Refuse("root %s is a static of %s: xwin_gen.c cannot name it" % (r["name"], r["source"]))
    for t in tags:
        words = ["XWIN_LW(offsetof(struct %s, %s), %d)" % (t, path, kind) for path, kind in layout_fields(pp, t, types)]
        lines.append("const uint64_t xwin_layout_%s[] = { %s, 0 };" % (t, ", ".join(words)))
    lines.append("const uint64_t xwin_layout_ptrs[] = { XWIN_LW(0, XWIN_LK_PTRS_TO_END), 0 };")
    for t_ in rtags:
        words = ["XWIN_LW(sizeof(struct %s), XWIN_LK_RECS_STRIDE)" % t_] + ["XWIN_LW(offsetof(struct %s, %s), %d)" % (t_, path, kind) for path, kind in layout_fields(pp, t_, types)]
        lines.append("const uint64_t xwin_layout_recs_%s[] = { %s, 0 };" % (t_, ", ".join(words)))
    ptrs = [r for r in roots if r["kind"] == "ptr"]
    descrs = [r for r in roots if r["kind"] == "descr"]
    lines.append("const char *const *const xwin_root_words[] = { %s };" % ", ".join("(const char *const *)&%s" % r["name"] for r in ptrs))
    lines.append("const long xwin_root_word_count = %d;" % len(ptrs))
    lines.append("struct descrip *const xwin_root_descrs[] = { %s };" % ", ".join("&%s" % r["name"] for r in descrs))
    lines.append("const long xwin_root_descr_count = %d;" % len(descrs))
    lines.append("int xwin_detached_destroy(struct _XImage *im) { if (im->obdata) XFree(im->obdata); XFree((char *)im); return 1; }")
    with open(os.path.join(tree, "xwin_gen.c"), "w") as f:
        f.write("\n".join(lines) + "\n")


SEPARATOR = "/*" + "-" * 196 + "*/"
UNICON_BYVALUE = ("DrawCube", "DrawCylinder", "DrawDisk", "DrawSphere", "DrawTorus", "Eye", "IdentityMatrix", "MatrixMode", "MultMatrix", "Normals", "PopMatrix", "PushMatrix", "PushRotate", "PushScale", "PushTranslate", "Refresh", "Rotate", "Scale", "Texcoord", "Texture", "Translate", "WindowContents", "WSection")


def write_builtins(tree, rows):
    tsv, c = [], ['#include "ir/descr.h"', "DESCR_t rt_xwin_call_h(void *zfn, int nparms, DESCR_t *argv, int n, void **hslot);",
                   "#define XWIN_EXPORT __attribute__((visibility(\"default\")))"]
    for r in rows:
        name, entry, res, nparams, suspends, c_args = r.split("\t")[:6]
        conv = "gen" if suspends == "yes" else "leaf"
        if D.get("name") == "unicon" and name in UNICON_BYVALUE:
            entry = "uxw3d_" + name
        tsv.append("-\ticn\t%s\t0\t%s\tbt_%s\t%s\t-\t-\t0\txwin" % (name, nparams, name, conv))
        c.append(SEPARATOR)
        c.append("extern int %s(%s);" % (entry, "int, void *" if c_args == "r_nargs,r_args" else "void *"))
        if conv == "gen":
            c.append("XWIN_EXPORT DESCR_t bt_%s_h(DESCR_t *args, int nargs, void **hslot) { return rt_xwin_call_h((void *)%s, %s, args, nargs, hslot); }" % (name, entry, nparams))
        else:
            c.append("XWIN_EXPORT DESCR_t bt_%s(DESCR_t *args, int nargs) { return rt_xwin_call_h((void *)%s, %s, args, nargs, (void **)0); }" % (name, entry, nparams))
    for line in c:
        if len(line) > 200:
            raise Refuse("an entry line is %d columns, over 200: %s" % (len(line), line[:80]))
    with open(os.path.join(tree, "xwin_builtins.tsv"), "w") as f:
        f.write("# the 48 rows of src/runtime/builtins.tsv this tree serves, bid left to --merge-builtins (an id is assigned once and never reused)\n")
        f.write("\n".join(tsv) + "\n")
    with open(os.path.join(tree, "xwin_entries.c"), "w") as f:
        f.write("\n".join(c) + "\n")
    names = list(D["export"])
    for r in rows:
        f = r.split("\t")
        names.append("bt_%s_h" % f[0] if f[4] == "yes" else "bt_%s" % f[0])
    with open(os.path.join(tree, "xwin_exports.map"), "w") as f:
        f.write("{\n  global:\n" + "".join("    %s;\n" % n for n in names) + "  local: *;\n};\n")


def merge_builtins(tree, path):
    rows = [l.rstrip("\n").split("\t") for l in open(os.path.join(tree, "xwin_builtins.tsv")) if not l.startswith("#") and l.strip()]
    for r in rows:
        r[8] = "xwin"
    lines = open(path).read().split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    bids, have = [], {}
    for i, l in enumerate(lines):
        f = l.split("\t")
        if l.startswith("#") or len(f) < 11 or not f[0].isdigit():
            continue
        bids.append(int(f[0]))
        if f[1] == "icn" and f[10] == "xwin":
            have[f[2]] = i
        elif f[1] == "icn" and f[2] in [r[2] for r in rows]:
            raise Refuse("%s row %s already spells icn %s with src %s, not xwin" % (path, f[0], f[2], f[10]))
    nxt = max(bids) + 1 if bids else 1
    added = kept = 0
    for r in rows:
        if r[2] in have:
            i = have[r[2]]
            lines[i] = "\t".join([lines[i].split("\t")[0]] + r[1:])
            kept += 1
        else:
            lines.append("\t".join([str(nxt)] + r[1:]))
            nxt += 1
            added += 1
    tmp = path + ".xwin-merge"
    with open(tmp, "w") as f:
        f.write("\n".join(lines) + "\n")
    os.replace(tmp, path)
    print("XWIN-BUILTINS %s kept=%d added=%d" % (path, kept, added))


def write_functions(src, tree, made):
    fsrc = open(os.path.join(src, "runtime", "fwindow.r")).read()
    rows = []
    for m in re.finditer(r"(?m)^function\{([^}]*)\}\s*(\w+)\(([^)]*)\)", fsrc):
        res, name, params = "".join(m.group(1).split()), m.group(2), m.group(3).strip()
        proto = re.search(r"(?m)^int Z%s ?\(([^)]*)\);" % name, made)
        if not proto:
            continue
        nparams = -1 if params == "argv[argc]" else len([p for p in params.split(",") if p.strip()])
        nums = res.split(",")
        suspends = "*" in nums or any(x.isdigit() and int(x) > 1 for x in nums)
        c_args = "r_nargs,r_args" if "int r_nargs" in proto.group(1) else "r_args"
        rows.append("%s\tZ%s\t%s\t%d\t%s\t%s\t%s" % (name, name, res, nparams, "yes" if suspends else "no", c_args, params or "-"))
    with open(os.path.join(tree, "xwin_functions.tsv"), "w") as f:
        f.write("# function\tC entry\tresult sequence\tparameters (-1 any number)\tsuspends\tC arguments\tsource parameters\n")
        f.write("\n".join(rows) + "\n")
    write_builtins(tree, rows)
    return len(rows)


def apply_patch(tree, patch):
    if not os.path.isfile(patch):
        raise Refuse("the patch file %s is missing" % patch)
    r = subprocess.run(["patch", "-p1", "-s", "--fuzz=0", "--no-backup-if-mismatch", "-d", tree, "-i", patch], capture_output=True, text=True)
    if r.returncode != 0:
        raise Fail("patch %s rc=%d: %s" % (patch, r.returncode, tail(r.stdout + r.stderr)))
    for dp, dn, fn in os.walk(tree):
        for n in fn:
            if n.endswith((".orig", ".rej")):
                raise Fail("the patch left %s" % os.path.join(dp, n))


def write_manifest(tree, roots=()):
    rows = []
    for dp, dn, fn in os.walk(tree):
        dn.sort()
        for n in sorted(fn):
            rel = os.path.relpath(os.path.join(dp, n), tree)
            if rel == MANIFEST or rel in HAND_WRITTEN:
                continue
            data = open(os.path.join(dp, n), "rb").read()
            rows.append("%s\t%d\t%s" % (rel, data.count(b"\n"), hashlib.md5(data).hexdigest()))
    order = []
    for kind, table in (("ptr", "xwin_root_words"), ("descr", "xwin_root_descrs")):
        for i, r in enumerate([r for r in roots if r["kind"] == kind]):
            order.append("%s[%d]\troot\t%s" % (table, i, r["name"]))
    with open(os.path.join(tree, MANIFEST), "w") as f:
        f.write("# path\tlines\tmd5 (util_gen_icon_xwin_device.py; regenerated, never edited); then each root table's index, the word root, and the oracle name it holds\n" + "\n".join(rows + order) + "\n")
    return rows


def scrip_src():
    s = os.environ.get("S4E_SCRIP")
    return os.path.join(s, "src") if s and os.path.isfile(os.path.join(s, "src", "ir", "descr.h")) else None


def c_sources(tree):
    out = []
    for n in sorted(os.listdir(tree)):
        if n.endswith(".c"):
            if n == "xwin_entries.c" and not scrip_src():
                print("XWIN-GEN SKIP xwin_entries.c: no SCRIP tree (S4E_SCRIP) for ir/descr.h")
                continue
            out.append(n)
    return out


def cc_flags(n):
    return ["-I.", "-I" + scrip_src()] if n == "xwin_entries.c" else tree_includes()


def tree_includes():
    return ["-I."] + ["-I" + c for c in D["cc_include"]]


def syntax(tree):
    for n in c_sources(tree):
        if True:
            r = subprocess.run(["bash", CC_SLOT, "gcc", "-fsyntax-only", "-w"] + cc_flags(n) + [n], cwd=tree, capture_output=True, text=True)
            if r.returncode != 0:
                raise Fail("syntax %s rc=%d: %s" % (n, r.returncode, tail(r.stderr or r.stdout)))


def link_census(tree, work):
    objs = os.path.join(work, "objs")
    os.makedirs(objs, exist_ok=True)
    for n in c_sources(tree):
        if True:
            r = subprocess.run(["bash", CC_SLOT, "gcc", "-c", "-w"] + cc_flags(n) + [n, "-o", os.path.join(objs, n[:-2] + ".o")], cwd=tree, capture_output=True, text=True)
            if r.returncode != 0:
                raise Fail("compile %s rc=%d: %s" % (n, r.returncode, tail(r.stderr or r.stdout)))
    paths = [os.path.join(objs, n) for n in sorted(os.listdir(objs))]
    und = subprocess.run(["nm", "-u"] + paths, capture_output=True, text=True).stdout
    dfn = subprocess.run(["nm", "--defined-only"] + paths, capture_output=True, text=True).stdout
    defined = set(l.split()[-1] for l in dfn.split("\n") if len(l.split()) == 3)
    need = sorted(set(l.split()[-1] for l in und.split("\n") if l.strip() and not l.endswith(":")) - defined)
    xlib = [n for n in need if n.startswith(("X", "_X"))]
    rest = [n for n in need if n not in xlib]
    print("XWIN-NEEDS xlib=%d" % len(xlib))
    print("XWIN-NEEDS other=%d %s" % (len(rest), " ".join(rest)))
    bad = [n for n in need if n in ("malloc", "calloc", "realloc", "free", "strdup", "strndup", "posix_memalign", "aligned_alloc")]
    if bad:
        raise Fail("the tree still calls the C allocator: %s" % " ".join(bad))
    print("XWIN-NO-ALLOCATOR ok")


def generate(src, tree, scratch, table, patch, use_patch, report):
    sites, roots = load_table(table)
    rrows = load_reads(D["reads"])
    rreport = []
    cfiles = translate(src, scratch)
    converted, used = classify_and_convert(cfiles, sites, report)
    os.makedirs(os.path.join(tree, "h"))
    by_source = {}
    made_fwindow = ""
    for p in cfiles:
        text = "\n".join(read_pass(post_pass(converted[p], scratch), p, rrows, rreport))
        name = os.path.basename(p)
        with open(os.path.join(tree, name), "w", errors="surrogateescape") as f:
            f.write(text)
        if name == "xfwindow.c":
            made_fwindow = text
        for s in set(re.findall(r'#line \d+ "([^"/]*\.ri?)"', text)):
            by_source[s] = by_source.get(s, "") + "\n" + text
    for n in sorted(os.listdir(os.path.join(scratch, "src", "h"))):
        if n.endswith(".h"):
            shutil.copyfile(os.path.join(scratch, "src", "h", n), os.path.join(tree, "h", n))
    carry_headers(scratch, tree)
    hs = header_pass(tree, rrows, rreport)
    check_reads(rrows, rreport)
    report_reads[:] = rreport
    tags = record_tags(sites)
    rtags = recs_tags(sites)
    write_alloc_h(tree, tags, used, rtags)
    pp, segs = preprocess(tree)
    write_gen_c(tree, tags, roots, pp, segs, by_source, src, rtags)
    nfun = write_functions(src, tree, made_fwindow)
    if nfun != D["functions"]:
        raise Fail("xwin_functions.tsv holds %d functions, wants %d" % (nfun, D["functions"]))
    if use_patch:
        apply_patch(tree, patch)
    pp_census(tree, rrows, hs, scratch, rreport)
    report_reads[:] = rreport
    for dp, dn, fn in os.walk(tree):
        for n in fn:
            data = open(os.path.join(dp, n), "rb").read()
            if scratch.encode() in data or (n.endswith((".c", ".h")) and b"/tmp/" in data):
                raise Refuse("%s names a scratch or /tmp path" % os.path.relpath(os.path.join(dp, n), tree))
    return write_manifest(tree, roots), len(cfiles)


OBJECT_HOME = "/home/resources/unicon-xwin"
OBJECT_TABLE = "INTERFACE-MEASURED.tsv"
OBJECT_LIBS = ["-lXpm", "-lXft", "-lfreetype", "-lGLU", "-lGL", "-lpng", "-ljpeg", "-lX11", "-lz", "-lm"]
REACH_2D_EXTRA = ("WindowContents",)


def checkout_hash(src):
    r = subprocess.run(["git", "-C", src, "rev-parse", "HEAD"], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else "unversioned"


def nm_names(so, undefined):
    r = subprocess.run(["nm", "-D"] + (["-u"] if undefined else ["--defined-only"]) + [so], capture_output=True, text=True)
    if r.returncode != 0:
        raise Fail("nm %s rc=%d: %s" % (so, r.returncode, tail(r.stderr)))
    out = set()
    for line in r.stdout.split("\n"):
        f = line.split()
        if not f:
            continue
        if undefined or (len(f) == 3 and f[1] not in "Uw"):
            out.add(f[-1].split("@")[0])
    return out


def needed_libs(so):
    r = subprocess.run(["readelf", "-d", so], capture_output=True, text=True)
    return re.findall(r"\(NEEDED\)\s+Shared library: \[([^\]]+)\]", r.stdout)


def lib_defs(so):
    out = {}
    r = subprocess.run(["ldd", so], capture_output=True, text=True)
    for line in r.stdout.split("\n"):
        m = re.match(r"\s*(\S+) => (\S+)", line)
        if m and os.path.isfile(m.group(2)):
            for n in nm_names(m.group(2), False):
                out.setdefault(n, m.group(1))
    return out


def link_object(objs, so, roots, work):
    vmap = so + ".map"
    with open(vmap, "w") as f:
        f.write("{\n  global:\n" + "".join("    %s;\n" % n for n in sorted(roots)) + "  local: *;\n};\n")
    r = subprocess.run(["bash", CC_SLOT, "gcc", "-shared", "-Wl,--gc-sections", "-Wl,--as-needed", "-Wl,--version-script=" + vmap, "-o", so] + objs + OBJECT_LIBS,
                       cwd=work, capture_output=True, text=True)
    if r.returncode != 0:
        raise Fail("link %s rc=%d: %s" % (os.path.basename(so), r.returncode, tail(r.stderr)))


def unicon_prototypes(tree):
    protos = {}
    for n in sorted(os.listdir(os.path.join(tree, "h"))):
        if not n.endswith(".h"):
            continue
        text = open(os.path.join(tree, "h", n), errors="replace").read()
        for m in re.finditer(r"(?m)^[ \t]*(?:extern[ \t]+)?([A-Za-z_][\w \t\*]*?)[ \t\*]+\**([A-Za-z_]\w*)[ \t]*\(([^;{]*?)\)[ \t]*;", text):
            protos.setdefault(m.group(2), (" ".join((m.group(0).strip().rstrip(";")).split()), "h/" + n))
        for m in re.finditer(r"(?m)^[ \t]*extern[ \t]+([^;(]*?[ \t\*])([A-Za-z_]\w*)[ \t]*(\[[^\]]*\])?[ \t]*;", text):
            protos.setdefault(m.group(2), (" ".join(m.group(0).strip().rstrip(";").split()), "h/" + n))
    return protos


def build_object(src, outdir, work, extra_config=(), roots_only=False, extra_cflags=(), patch=None):
    scratch = os.path.join(work, "scratch")
    tree = os.path.join(outdir, "tree")
    os.makedirs(scratch)
    if os.path.isdir(tree):
        shutil.rmtree(tree)
    os.makedirs(os.path.join(tree, "h"))
    cfiles = translate(src, scratch, raw=True, extra_config=extra_config)
    sites = {"allocation": 0, "free": 0}
    for p in cfiles:
        lines, found = census(p)
        for s in found:
            if s["call"] != "XFree":
                sites["free" if s["call"] == "free" else "allocation"] += 1
        text = "\n".join(post_pass(lines, scratch, raw=True))
        with open(os.path.join(tree, os.path.basename(p)), "w", errors="surrogateescape") as f:
            f.write(text)
    for n in sorted(os.listdir(os.path.join(scratch, "src", "h"))):
        if n.endswith(".h"):
            shutil.copyfile(os.path.join(scratch, "src", "h", n), os.path.join(tree, "h", n))
    carry_headers(scratch, tree)
    if patch:
        r = subprocess.run(["patch", "-p1", "-s", "--fuzz=0", "--no-backup-if-mismatch", "-d", tree, "-i", patch], capture_output=True, text=True)
        if r.returncode != 0:
            raise Fail("the arena patch %s does not apply rc=%d: %s" % (patch, r.returncode, tail(r.stdout + r.stderr)))
    objs = []
    for p in cfiles:
        n = os.path.basename(p)
        o = os.path.join(outdir, n[:-2] + ".o")
        r = subprocess.run(["bash", CC_SLOT, "gcc", "-std=c11", "-c", "-w", "-fPIC", "-O0", "-ffunction-sections", "-fdata-sections"] + list(extra_cflags) + tree_includes() + [n, "-o", o],
                           cwd=tree, capture_output=True, text=True)
        if r.returncode != 0:
            raise Fail("compile %s rc=%d: %s" % (n, r.returncode, tail(r.stderr)))
        objs.append(o)
    made = open(os.path.join(tree, "xfwindow.c")).read()
    entries = sorted(set(re.findall(r"(?m)^int (Z\w+) ?\(([^)]*)\);", made)))
    fn_names = [e[0] for e in entries]
    whole = os.path.join(outdir, "libunicon_xwin.so")
    if not roots_only:
        link_object(objs, whole, fn_names, outdir)
    az = sorted(set("Z" + n for n in arizona_functions()) | set("Z" + n for n in REACH_2D_EXTRA))
    missing = [n for n in az if n not in fn_names]
    if missing:
        raise Refuse("the 2D roots are not all Unicon functions: %s" % " ".join(missing))
    two = os.path.join(outdir, "libunicon_xwin_2d.so")
    link_object(objs, two, az, outdir)
    return {"whole": whole, "two": two, "entries": entries, "sites": sites, "tree": tree, "roots2d": az, "objs": objs}


def arizona_functions():
    path = os.path.join(DESIGNS, "arizona", "FUNCTIONS-48.tsv")
    if os.path.isfile(path):
        return [l.split("\t")[0] for l in open(path) if l.strip() and not l.startswith("#")]
    src = "/home/packages/icon/icon-master/src/runtime/fwindow.r"
    names = re.findall(r"(?m)^function\{[^}]*\}\s*(\w+)\(", open(src).read())
    return [n for n in names if not n.startswith("Win")]


def object_rows(b, src):
    exports = nm_names(b["whole"], False) - {"_init", "_fini"}
    und_whole = nm_names(b["whole"], True)
    und_two = nm_names(b["two"], True)
    supplier = lib_defs(b["whole"])
    protos = unicon_prototypes(b["tree"])
    sigs = dict(b["entries"])
    und_flat = nm_names(b["flat"], True) if b.get("flat") else und_two
    rows = []
    for n in sorted(exports):
        reach = "2d" if n in b["roots2d"] else "3d"
        rows.append(("export", n, "int %s(%s)" % (n, sigs[n]) if n in sigs else "-", "xfwindow.c", reach))
    for n in sorted(und_whole):
        if n.startswith("_ITM_") or n == "__gmon_start__":
            continue
        who = supplier.get(n, "unicon run-time")
        sig = protos.get(n, ("-", "-"))[0] if who == "unicon run-time" else "-"
        rows.append(("import", n, sig, who, "2d" if n in und_flat else ("2d-3d-arm" if n in und_two else "3d")))
    two_libs = set(needed_libs(b["two"]))
    for lib in needed_libs(b["whole"]):
        rows.append(("library", lib, "-", "-", "2d" if lib in two_libs else "3d"))
    return rows


def object_header(src, b, rows):
    imp = [r for r in rows if r[0] == "import"]
    rt = [r for r in imp if r[3] == "unicon run-time"]
    return ("# INTERFACE-MEASURED.tsv -- Unicon's window kernel linked as ONE shared object outside every repository of ours (step U1 of the Unicon object, the cto 2026-11-16 11:4x CST, on Lon's ruling of 09:5x: Keep Unicon graphics as a separate replaceable library); written by util_gen_icon_xwin_device.py --dialect unicon --object, held equal by --object-check. Read from nm of the LINKED objects, never from a call-graph walk.\n"
            "# source: the Unicon checkout of designs/icon_xwin/unicon/DIALECT.tsv at git %s, translated raw by its own urtt under the dialect's configuration (Unicon's allocator as Unicon wrote it: %d allocation sites and %d frees, none converted, step U1 point 2)\n"
            "# libunicon_xwin.so: every Z entry exported, linked --gc-sections; libunicon_xwin_2d.so: rooted at Arizona's 48 functions and WindowContents; a third link, the same roots built with NoGL (every Graphics3D arm compiled out), is measurement only. An import's reach: 2d, reached from those roots with no 3D arm; 2d-3d-arm, reached from those roots only through their 3D arms (DrawLine's is_3D arm and kin, which a program that opens no 3D window never runs); 3d, reached only from the 3D functions\n"
            "# counts: exports %d; imports %d, of them the Unicon run-time %d (2d %d, 2d-3d-arm %d); libraries %d\n"
            "# kind <tab> name <tab> C signature (an export's from xfwindow.c, a run-time import's from Unicon's own h/) <tab> defined in or supplied by <tab> reach (2d or 3d)\n"
            % (checkout_hash(src), b["sites"]["allocation"], b["sites"]["free"], sum(1 for r in rows if r[0] == "export"), len(imp), len(rt),
               sum(1 for r in rt if r[4] == "2d"), sum(1 for r in rt if r[4] == "2d-3d-arm"), sum(1 for r in rows if r[0] == "library")))


def object_main(a):
    try:
        load_dialect(a.dialect)
        if a.dialect != "unicon":
            raise Refuse("--object and --object-check are the unicon dialect's verbs")
        src = os.path.abspath(a.src or D["src"])
        for need in (os.path.join(src, D["translator"]), os.path.join(src, "runtime", "fwindow.r")):
            if not os.path.isfile(need):
                raise Refuse("the Unicon checkout lacks %s" % need)
        table = os.path.join(DESIGNS, "unicon", OBJECT_TABLE)
        base = os.path.join("/tmp/s4e", os.environ.get("S4E_SEAT") or "anon", "xwgen")
        os.makedirs(base, exist_ok=True)
        work = tempfile.mkdtemp(prefix="xwobj-", dir=base)
        try:
            if a.object_check:
                outdir = os.path.join(work, "object")
            else:
                outdir = os.path.abspath(a.object) if a.object else os.path.join(OBJECT_HOME, checkout_hash(src))
            os.makedirs(outdir, exist_ok=True)
            b = build_object(src, outdir, os.path.join(work, "build"))
            f = build_object(src, os.path.join(work, "flat"), os.path.join(work, "buildflat"), extra_config=("#define NoGL 1",), roots_only=True)
            b["flat"] = f["two"]
            rows = object_rows(b, src)
            text = object_header(src, b, rows) + "".join("\t".join(r) + "\n" for r in rows)
            if a.object_check:
                if not os.path.isfile(table):
                    raise Refuse("no table %s" % table)
                old = open(table).read()
                if old == text:
                    print("XWIN-OBJECT EQUAL %s" % table)
                    return 0
                want = set(l for l in old.split("\n") if l and not l.startswith("#"))
                got = set(l for l in text.split("\n") if l and not l.startswith("#"))
                for l in sorted(want - got):
                    print("XWIN-OBJECT RED in the table, not in the object: %s" % l)
                for l in sorted(got - want):
                    print("XWIN-OBJECT RED in the object, not in the table: %s" % l)
                if want == got:
                    print("XWIN-OBJECT RED the header differs (counts or the checkout's hash)")
                print("XWIN-OBJECT FAIL %s differs from a fresh build" % table)
                return 1
            with open(table, "w") as f:
                f.write(text)
            print("XWIN-OBJECT BUILT %s and %s" % (b["whole"], b["two"]))
            print("XWIN-OBJECT WROTE %s" % table)
            print(text.split("\n")[3])
            return 0
        finally:
            if not a.keep:
                shutil.rmtree(work, ignore_errors=True)
    except Refuse as e:
        print("REFUSE(2): %s" % e)
        return 2
    except Fail as e:
        print("XWIN-OBJECT FAIL %s" % e)
        return 1


ARENA_TABLE = "ARENA-MEASURED.tsv"
C_ALLOCATORS = ("malloc", "calloc", "realloc", "free", "strdup", "strndup", "salloc", "posix_memalign", "aligned_alloc")
ARENA_EXERCISE = r'''#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "pin_va.h"
void *uxa_malloc(size_t n); void *uxa_calloc(size_t k, size_t n); void *uxa_realloc(void *p, size_t n); void uxa_free(void *p); char *uxa_strdup(const char *s);
static int inside(void *p) { return (uintptr_t)p >= RT_UXWIN_ARENA_VA && (uintptr_t)p < RT_UXWIN_ARENA_VA + ((uintptr_t)1 << 40); }
#define CK(c, m) do { if (!(c)) { printf("ARENA-EXERCISE FAIL %s\n", m); return 1; } printf("ARENA-EXERCISE ok %s\n", m); } while (0)
int main(void) {
    char *p = uxa_malloc(10); CK(p && inside(p), "allocate inside the window");
    strcpy(p, "abcdefghi"); char *q = uxa_realloc(p, 1000); CK(q && inside(q) && !strcmp(q, "abcdefghi"), "grow keeps the bytes");
    uxa_free(q); char *r = uxa_malloc(1000); CK(r == q, "a freed block is reused");
    memset(r, 0xff, 1000); uxa_free(r); unsigned char *z = uxa_calloc(1000, 1); int zero = 1; for (int i = 0; i < 1000; i++) if (z[i]) zero = 0; CK(z && zero, "calloc of a reused block is zero");
    char *a = uxa_malloc(64), *b = uxa_malloc(64); CK(a && b && a != b, "two live blocks are distinct");
    char *big = uxa_malloc((size_t)100 << 20); CK(big && inside(big), "a block larger than a piece grows the window"); big[((size_t)100 << 20) - 1] = 1;
    char *s = uxa_strdup("window"); CK(s && inside(s) && !strcmp(s, "window"), "strdup in the window");
    void *f = malloc(32); uxa_free(f); CK(1, "a foreign pointer is handed to the C library's free");
    CK(uxa_realloc(0, 8) != 0 && uxa_malloc(0) != 0, "realloc of NULL and malloc of 0 allocate");
    printf("ARENA-EXERCISE PASS\n");
    return 0;
}
'''


def scrip_ir():
    s = os.environ.get("S4E_SCRIP")
    if not s:
        raise Refuse("no SCRIP root (S4E_SCRIP) whose src/ir/pin_va.h names the window")
    p = os.path.join(s, "src", "ir")
    if not os.path.isfile(os.path.join(p, "pin_va.h")):
        raise Refuse("%s/pin_va.h is absent" % p)
    return p


def build_arena_object(src, outdir, work):
    ir = scrip_ir()
    arena_src = os.path.join(DESIGNS, "unicon", D["arena_source"] or "uxwin_arena.c")
    if not os.path.isfile(arena_src):
        raise Refuse("no arena source %s" % arena_src)
    defines = list(D["arena_define"])
    if not defines:
        raise Refuse("the dialect names no arena_define line")
    patch = os.path.join(DESIGNS, "unicon", "arena.patch")
    if not os.path.isfile(patch):
        raise Refuse("no arena patch %s" % patch)
    b = build_object(src, outdir, work, roots_only=True, extra_cflags=defines, patch=patch)
    ao = os.path.join(outdir, "uxwin_arena.o")
    r = subprocess.run(["bash", CC_SLOT, "gcc", "-std=gnu11", "-c", "-O0", "-g", "-fPIC", "-Wall", "-Werror", "-I" + ir, arena_src, "-o", ao], capture_output=True, text=True)
    if r.returncode != 0:
        raise Fail("compile %s rc=%d: %s" % (os.path.basename(arena_src), r.returncode, tail(r.stderr)))
    b["arena_o"] = ao
    b["ir"] = ir
    return b


def arena_nm_check(b):
    bad = []
    for o in b["objs"]:
        und = nm_names_o(o)
        named = sorted(n for n in und if n in C_ALLOCATORS)
        if named:
            bad.append("%s names %s" % (os.path.basename(o), " ".join(named)))
    und = nm_names_o(b["arena_o"])
    return bad, sorted(n for n in und if n in C_ALLOCATORS)


def nm_names_o(o):
    r = subprocess.run(["nm", "-u", o], capture_output=True, text=True)
    if r.returncode != 0:
        raise Fail("nm %s rc=%d" % (o, r.returncode))
    return set(l.split()[-1].split("@")[0] for l in r.stdout.split("\n") if l.strip())


def arena_exercise(b, work):
    c = os.path.join(work, "arena_exercise.c")
    with open(c, "w") as f:
        f.write(ARENA_EXERCISE)
    exe = os.path.join(work, "arena_exercise")
    r = subprocess.run(["bash", CC_SLOT, "gcc", "-std=gnu11", "-O0", "-I" + b["ir"], c, b["arena_o"], "-o", exe, "-lX11", "-ldl", "-lpthread"], capture_output=True, text=True)
    if r.returncode != 0:
        raise Fail("the exercise does not link rc=%d: %s" % (r.returncode, tail(r.stderr)))
    stats = os.path.join(work, "arena_exercise.stats")
    r = subprocess.run([exe], capture_output=True, text=True, timeout=120, env=dict(os.environ, UXWIN_ARENA_STATS=stats))
    out = r.stdout.strip().split("\n")
    st = open(stats).read() if os.path.isfile(stats) else ""
    m = re.search(r"foreign_frees=(\d+)", st)
    ok = r.returncode == 0 and out and out[-1] == "ARENA-EXERCISE PASS" and m and m.group(1) == "1"
    return ok, out, st


HEAP_REACH = [("_wbinding", "wbndngs, the binding chain"), ("_wstate", "wstates, the window state chain; a binding's window"), ("_wcontext", "wcntxts, the context chain; a binding's context"),
              ("_wdisplay", "wdsplys, the display chain; a window state's or a context's display"), ("_wfont", "a display's fonts, a context's font"),
              ("_wtexture", "a display's texture table stex (an array of records)"), ("wbind_list", "a window state's children (a child window's binding)")]


def heap_members(tree):
    probe = os.path.join(tree, ".xwin_probe.c")
    with open(probe, "w") as f:
        f.write('#include "h/rt.h"\n')
    r = subprocess.run(["bash", CC_SLOT, "gcc", "-E", "-std=c11"] + tree_includes() + [".xwin_probe.c"], cwd=tree, capture_output=True, text=True)
    os.unlink(probe)
    if r.returncode != 0:
        raise Fail("preprocessing Unicon's h/rt.h rc=%d: %s" % (r.returncode, tail(r.stderr)))
    pp = re.sub(r"(?m)^#.*$", "", r.stdout)
    rows = []
    heapish = re.compile(r"^(?:struct\s+descrip|union\s+block\s*\*|struct\s+b_\w+\s*\*|dptr|struct\s+descrip\s*\*)$")
    def walk(tag, prefix, reach, body=None):
        text = " ".join((struct_body(pp, tag) if body is None else body).split())
        for decl in top_decls(text):
            if "{" in decl:
                m = re.match(r"^(struct|union)\s*\w*\s*\{(.*)\}\s*(\w+)\s*$", decl)
                if m:
                    walk(tag, prefix + m.group(3) + ".", reach, m.group(2))
                continue
            parts = [p.strip() for p in decl.split(",")]
            m = re.match(r"^(.*?)([\s*]+)(\w+)\s*(\[[^\]]*\])?$", parts[0])
            if not m:
                continue
            base = " ".join(m.group(1).split())
            names = [(m.group(2).count("*"), m.group(3), m.group(4))]
            for p in parts[1:]:
                mm = re.match(r"^(\**)\s*(\w+)\s*(\[[^\]]*\])?$", p)
                if mm:
                    names.append((len(mm.group(1)), mm.group(2), mm.group(3)))
            for stars, name, arr in names:
                ty = base + (" " + "*" * stars if stars else "")
                if heapish.match(" ".join(ty.split())) or (base in ("struct descrip", "dptr") and arr):
                    rows.append(("heap-member", tag, prefix + name + (arr or ""), " ".join(ty.split()), reach))
    for tag, reach in HEAP_REACH:
        walk(tag, "", reach)
    return rows


def arena_main(a):
    try:
        load_dialect(a.dialect)
        if a.dialect != "unicon":
            raise Refuse("--arena-check is the unicon dialect's verb")
        src = os.path.abspath(a.src or D["src"])
        for need in (os.path.join(src, D["translator"]), os.path.join(src, "runtime", "fwindow.r")):
            if not os.path.isfile(need):
                raise Refuse("the Unicon checkout lacks %s" % need)
        table = os.path.join(DESIGNS, "unicon", ARENA_TABLE)
        base = os.path.join("/tmp/s4e", os.environ.get("S4E_SEAT") or "anon", "xwgen")
        os.makedirs(base, exist_ok=True)
        work = tempfile.mkdtemp(prefix="xwarena-", dir=base)
        try:
            b = build_arena_object(src, os.path.join(work, "object"), os.path.join(work, "build"))
            bad, arena_names = arena_nm_check(b)
            for x in bad:
                print("ARENA RED a kernel object calls the C allocator itself: %s" % x)
            print("ARENA the arena file alone names the C allocator: %s" % (" ".join(arena_names) or "nothing"))
            ok, out, st = arena_exercise(b, work)
            for l in out:
                print(l)
            print("ARENA exercise stats: %s" % " ".join(st.split("\n")[0].split("\t")[1:]))
            hm = heap_members(b["tree"])
            want = []
            if os.path.isfile(table):
                want = [tuple(l.rstrip("\n").split("\t")) for l in open(table) if l.startswith("heap-member\t")]
            elif not a.arena_write:
                raise Refuse("no table %s" % table)
            if a.arena_write:
                print("ARENA heap members %d" % len(hm))
                for r in hm:
                    print("\t".join(r))
                return 0 if not bad and ok else 1
            drift = sorted(set(want) ^ set(hm))
            for r in drift:
                print("ARENA RED heap member %s: %s" % ("in the table only" if r in want else "in the headers only", "\t".join(r)))
            if bad or not ok or drift:
                print("ARENA FAIL: kernel objects naming the allocator %d, exercise %s, heap-member drift %d" % (len(bad), "PASS" if ok else "FAIL", len(drift)))
                return 1
            print("ARENA OK: no kernel object names the C allocator, the exercise passes, %d heap members as the table holds" % len(hm))
            return 0
        finally:
            if not a.keep:
                shutil.rmtree(work, ignore_errors=True)
    except Refuse as e:
        print("REFUSE(2): %s" % e)
        return 2
    except Fail as e:
        print("ARENA FAIL %s" % e)
        return 1


def tree_files(t):
    s = set()
    for dp, dn, fn in os.walk(t):
        for n in fn:
            s.add(os.path.relpath(os.path.join(dp, n), t))
    return s - set(HAND_WRITTEN)


def compare(a, b):
    fa, fb = tree_files(a), tree_files(b)
    same = set(p for p in fa & fb if open(os.path.join(a, p), "rb").read() == open(os.path.join(b, p), "rb").read())
    return sorted((fa | fb) - same)


SHIM_SOURCE = "uxwin_shim.c"
FORMS_TABLE = "FORMS-MEASURED.tsv"
SHIM_KWD = ("kywd_xwin[XKey_Window]", "kywd_xwin[XKey_Fg]", "amperX", "amperY", "amperCol", "amperRow", "amperInterval", "lastEventWin")
SHIM_OPEN = ("xwin_list_new", "rt_icn_set_errortext")
SHIM_LANG = ("xwin_lang_open", "xwin_lang_open3d", "xwin_lang_close", "xwin_lang_write", "xwin_lang_flush", "xwin_lang_read", "xwin_lang_reads", "xwin_lang_image")
SHIM_LOADER = r'''#include <dlfcn.h>
#include <stdio.h>
int main(int argc, char **argv) {
    if (argc != 3) return 2;
    if (!dlopen(argv[1], RTLD_NOW | RTLD_GLOBAL)) { printf("SHIM-LOAD RED the runtime: %s\n", dlerror()); return 1; }
    void *h = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    if (!h) { printf("SHIM-LOAD RED the object: %s\n", dlerror()); return 1; }
    const char *want[] = { "bt_DrawLine", "xwin_kywd_addr" };
    for (int i = 0; i < 2; i++) { if (!dlsym(h, want[i])) { printf("SHIM-LOAD RED no %s\n", want[i]); return 1; } printf("SHIM-LOAD found %s\n", want[i]); }
    void *(*kw)(int) = (void *(*)(int))dlsym(h, "xwin_kywd_addr");
    for (int i = 0; i < 8; i++) if (!kw(i)) { printf("SHIM-LOAD RED keyword %d has no address\n", i); return 1; }
    printf("SHIM-LOAD ok\n");
    return 0;
}
'''


def interface_rows(root):
    p = os.path.join(root, "src", "runtime", "xwin_interface.tsv")
    if not os.path.isfile(p):
        raise Refuse("no interface table %s" % p)
    rows = [l.rstrip("\n").split("\t") for l in open(p) if l.strip() and not l.startswith("#")]
    return {k: set(r[1] for r in rows if r[0] == k) for k in ("import", "offer", "export", "library")}


def shim_entries(src, tree, made, wanted):
    fsrc = open(os.path.join(src, "runtime", "fwindow.r")).read()
    rows = []
    for m in re.finditer(r"(?m)^function\{([^}]*)\}\s*(\w+)\(([^)]*)\)", fsrc):
        res, name, params = "".join(m.group(1).split()), m.group(2), m.group(3).strip()
        if name not in wanted:
            continue
        proto = re.search(r"(?m)^int Z%s ?\(([^)]*)\);" % name, made)
        if not proto:
            raise Refuse("Unicon's fwindow.r declares %s and its translation has no Z%s" % (name, name))
        nparams = -1 if params == "argv[argc]" else len([p for p in params.split(",") if p.strip()])
        nums = res.split(",")
        suspends = "*" in nums or any(x.isdigit() and int(x) > 1 for x in nums)
        c_args = "r_nargs,r_args" if "int r_nargs" in proto.group(1) else "r_args"
        rows.append("%s\tZ%s\t%s\t%d\t%s\t%s\t%s" % (name, name, res, nparams, "yes" if suspends else "no", c_args, params or "-"))
    missing = sorted(set(wanted) - set(r.split("\t")[0] for r in rows))
    if missing:
        raise Refuse("the interface asks for functions Unicon's fwindow.r does not define: %s" % " ".join(missing))
    keep = list(D["export"])
    D["export"] = keep + [n for n in SHIM_LANG if n not in keep]
    try:
        write_builtins(tree, rows)
    finally:
        D["export"] = keep
    return rows


def shim_gen(src, tree):
    lines = ['#include "h/rt.h"'] + own_data(src)
    roots = [l.rstrip("\n").split("\t") for l in open(D["table"]) if l.startswith("root\t")]
    descrs = [r[4] for r in roots if r[3] == "descr"]
    own = set(n for n, s in D["own_data"])
    lines += ["extern struct descrip %s;" % n for n in descrs if n.split("[")[0] not in own]
    lines.append("struct descrip *const uxw_root_descrs[] = { %s };" % ", ".join("&%s" % n for n in descrs))
    lines.append("const long uxw_root_descr_count = %d;" % len(descrs))
    lines.append("struct descrip *const uxw_kywd[] = { %s };" % ", ".join("&%s" % n for n in SHIM_KWD))
    with open(os.path.join(tree, "uxwin_gen.c"), "w") as f:
        f.write("\n".join(lines) + "\n")
    with open(os.path.join(tree, "uxwin_decl.h"), "w") as f:
        f.write("struct descrip;\nlong xwin_list_size(struct descrip *d);\n")
        f.write("void *uxw_alclist3d(unsigned long size, unsigned long nslots);\nstruct descrip *rec_structor3d(char *name);\n")
        for name, fn in sorted(D["by_value"].items()):
            f.write("struct descrip %s(void);\n#define %s %s()\n" % (fn, name, fn))
    return len(descrs)


def cc(args, cwd, what):
    r = subprocess.run(["bash", CC_SLOT, "gcc"] + args, cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        raise Fail("compile %s rc=%d: %s" % (what, r.returncode, tail(r.stderr)))


def build_shim_object(src, root, outdir, work, wanted):
    ir = scrip_ir()
    scratch = os.path.join(work, "scratch")
    tree = os.path.join(outdir, "tree")
    os.makedirs(scratch)
    os.makedirs(os.path.join(tree, "h"))
    cfiles = translate(src, scratch, raw=True)
    rrows = load_reads(D["reads"])
    rreport = []
    made = ""
    for p in cfiles:
        text = "\n".join(read_pass(post_pass(open(p, errors="surrogateescape").read().split("\n"), scratch, raw=True), p, rrows, rreport))
        with open(os.path.join(tree, os.path.basename(p)), "w", errors="surrogateescape") as f:
            f.write(text)
        if os.path.basename(p) == "xfwindow.c":
            made = text
    for n in sorted(os.listdir(os.path.join(scratch, "src", "h"))):
        if n.endswith(".h"):
            shutil.copyfile(os.path.join(scratch, "src", "h", n), os.path.join(tree, "h", n))
    carry_headers(scratch, tree)
    header_pass(tree, rrows, rreport)
    check_reads(rrows, rreport)
    patch = os.path.join(DESIGNS, "unicon", "arena.patch")
    if not os.path.isfile(patch):
        raise Refuse("no arena patch %s" % patch)
    r = subprocess.run(["patch", "-p1", "-s", "--fuzz=0", "--no-backup-if-mismatch", "-d", tree, "-i", patch], capture_output=True, text=True)
    if r.returncode != 0:
        raise Fail("the arena patch %s does not apply rc=%d: %s" % (patch, r.returncode, tail(r.stdout + r.stderr)))
    nroots = shim_gen(src, tree)
    rows = shim_entries(src, tree, made, wanted)
    defines = list(D["arena_define"])
    objs = []
    for p in cfiles:
        n = os.path.basename(p)
        o = os.path.join(outdir, n[:-2] + ".o")
        cc(["-std=c11", "-c", "-w", "-fPIC", "-O0", "-ffunction-sections", "-fdata-sections", "-include", "uxwin_decl.h"] + defines + tree_includes() + [n, "-o", o], tree, n)
        objs.append(o)
    for n, flags in (("uxwin_gen.c", ["-std=c11", "-w"]), ("xwin_entries.c", ["-std=gnu11", "-Wall", "-Werror", "-I" + os.path.join(root, "src")])):
        o = os.path.join(outdir, n[:-2] + ".o")
        cc(["-c", "-fPIC", "-O0"] + flags + tree_includes() + [n, "-o", o], tree, n)
        objs.append(o)
    for n, inc in ((SHIM_SOURCE, ["-I" + os.path.join(root, "src")]), (D["arena_source"] or "uxwin_arena.c", ["-I" + ir])):
        path = os.path.join(DESIGNS, "unicon", n)
        if not os.path.isfile(path):
            raise Refuse("no %s" % path)
        o = os.path.join(outdir, n[:-2] + ".o")
        cc(["-std=gnu11", "-c", "-fPIC", "-O0", "-g", "-Wall", "-Werror"] + tree_includes() + inc + [path, "-o", o], tree, n)
        objs.append(o)
    so = os.path.join(outdir, "libscrip_xwin.so")
    r = subprocess.run(["bash", CC_SLOT, "gcc", "-shared", "-Wl,-Bsymbolic", "-Wl,--gc-sections", "-Wl,--version-script=" + os.path.join(tree, "xwin_exports.map"), "-Wl,-soname,libscrip_xwin.so",
                        "-o", so] + objs + OBJECT_LIBS, cwd=outdir, capture_output=True, text=True)
    if r.returncode != 0:
        raise Fail("link %s rc=%d: %s" % (so, r.returncode, tail(r.stderr)))
    return {"so": so, "tree": tree, "rows": rows, "roots": nroots, "reads": rreport}


def forms_probe(tree, work, tag, extra):
    exe = os.path.join(work, "forms_" + tag)
    probe = os.path.join(DESIGNS, "unicon", "forms_probe.c")
    if not os.path.isfile(probe):
        raise Refuse("no forms probe %s" % probe)
    cc(["-std=gnu11", "-w"] + extra + [probe, "-o", exe], tree, "the forms probe in " + tag)
    r = subprocess.run([exe], capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise Fail("the forms probe in %s rc=%d" % (tag, r.returncode))
    return dict(l.split("\t", 1) for l in r.stdout.strip().split("\n"))


def shim_main(a):
    try:
        load_dialect(a.dialect)
        if a.dialect != "unicon":
            raise Refuse("--shim-check is the unicon dialect's verb")
        root = os.path.abspath(a.shim_check)
        os.environ.setdefault("S4E_SCRIP", root)
        for need in (os.path.join(root, "out", "libscrip_rt.so"), os.path.join(root, "src", "runtime", "xwin", "h", "rt.h")):
            if not os.path.isfile(need):
                raise Refuse("the SCRIP root lacks %s" % need)
        src = os.path.abspath(a.src or D["src"])
        if not os.path.isfile(os.path.join(src, D["translator"])):
            raise Refuse("the Unicon checkout lacks %s" % D["translator"])
        if not os.path.isfile(os.path.join(DESIGNS, "unicon", FORMS_TABLE)):
            raise Refuse("no forms table %s" % FORMS_TABLE)
        t = interface_rows(root)
        wanted = sorted(n[3:] for n in t["export"] if n.startswith("bt_"))
        base = os.path.join("/tmp/s4e", os.environ.get("S4E_SEAT") or "anon", "xwgen")
        os.makedirs(base, exist_ok=True)
        work = tempfile.mkdtemp(prefix="xwshim-", dir=base)
        bad = 0
        try:
            out = os.path.abspath(a.object) if a.object else os.path.join(work, "object")
            os.makedirs(out, exist_ok=True)
            b = build_shim_object(src, root, out, os.path.join(work, "build"), [n[:-2] if n.endswith("_h") else n for n in wanted])
            print("SHIM built %s: %d entries, %d root descriptors, reads %s" % (b["so"], len(b["rows"]), b["roots"], " ".join(b["reads"])))
            und = nm_names(b["so"], True) - {"__gmon_start__", "_ITM_deregisterTMCloneTable", "_ITM_registerTMCloneTable", "__cxa_finalize"}
            libs = lib_defs(b["so"])
            for n in sorted(und):
                if n in t["import"] or n in t["offer"] or n in libs:
                    continue
                bad += 1
                print("SHIM RED the object asks %s, which the interface neither imports nor offers%s" % (n, " (asked of the cto and ruled; OPEN until it lands)" if n in SHIM_OPEN else ""))
            exp = nm_names(b["so"], False)
            for n in sorted(t["export"] - exp):
                bad += 1
                print("SHIM RED the interface exports %s and the object does not" % n)
            az = forms_probe(os.path.join(root, "src", "runtime", "xwin"), work, "arizona", ["-I."])
            un = forms_probe(b["tree"], work, "unicon", tree_includes())
            alias = {"the error signal (Error)": "the error signal (RunError)"}
            eq = 0
            for k, v in sorted(az.items()):
                u = un.get(alias.get(k, k))
                if u == v:
                    eq += 1
                    continue
                bad += 1
                print("SHIM RED form %s: Arizona %s, Unicon %s" % (k, v, u))
            for k in sorted(set(un) - set(az) - set(alias.values())):
                bad += 1
                print("SHIM RED form %s is Unicon's alone: %s" % (k, un[k]))
            print("SHIM forms equal %d of %d" % (eq, len(az)))
            c = os.path.join(work, "shim_load.c")
            with open(c, "w") as f:
                f.write(SHIM_LOADER)
            exe = os.path.join(work, "shim_load")
            cc([c, "-o", exe, "-ldl"], work, "the loader")
            r = subprocess.run([exe, os.path.join(root, "out", "libscrip_rt.so"), b["so"]], capture_output=True, text=True, timeout=120)
            print(r.stdout.strip())
            if r.returncode != 0:
                bad += 1
            if bad:
                print("SHIM FAIL %d" % bad)
                return 1
            print("SHIM OK: every name the object asks is imported, offered or a library's, every export the interface names is there, the forms are equal, the object loads beside %s" % root)
            return 0
        finally:
            if not a.keep:
                shutil.rmtree(work, ignore_errors=True)
    except Refuse as e:
        print("REFUSE(2): %s" % e)
        return 2
    except Fail as e:
        print("SHIM FAIL %s" % e)
        return 1


def main():
    ap = argparse.ArgumentParser(description="Regenerate the Icon window facility's tree from the oracle's sources.")
    ap.add_argument("--dialect", default="arizona")
    ap.add_argument("--src")
    ap.add_argument("--out")
    ap.add_argument("--check")
    ap.add_argument("--classes", action="store_true")
    ap.add_argument("--table")
    ap.add_argument("--patch")
    ap.add_argument("--no-patch", action="store_true")
    ap.add_argument("--syntax", action="store_true")
    ap.add_argument("--link-census", action="store_true")
    ap.add_argument("--merge-builtins")
    ap.add_argument("--keep", action="store_true")
    ap.add_argument("--object", nargs="?", const="", metavar="DIR")
    ap.add_argument("--object-check", action="store_true")
    ap.add_argument("--arena-check", action="store_true")
    ap.add_argument("--arena-write", action="store_true")
    ap.add_argument("--shim-check", metavar="ROOT")
    a = ap.parse_args()
    if a.shim_check:
        return shim_main(a)
    if a.arena_check or a.arena_write:
        return arena_main(a)
    if a.object is not None or a.object_check:
        return object_main(a)
    if sum(1 for x in (a.out, a.check, a.classes) if x) != 1:
        print("REFUSE(2): give one of --out DIR, --check DIR, --classes")
        return 2
    try:
        load_dialect(a.dialect)
    except Refuse as e:
        print("REFUSE(2): %s" % e)
        return 2
    src = os.path.abspath(a.src or D["src"])
    a.table = a.table or D["table"]
    a.patch = a.patch or D["patch"]
    need = [D["translator"], "h/graphics.h", "h/xwin.h", "h/grttin.h", D["config_file"]] + ([D["plain"]] if D["plain"] else []) + sorted(set(os.path.join("runtime", s) for n, s in D["own_data"])) + [os.path.join("runtime", n) for n in D["source"] + D["include"]]
    missing = [n for n in need if not os.path.isfile(os.path.join(src, n))]
    if missing:
        print("REFUSE(2): the oracle source at %s lacks %s" % (src, " ".join(missing)))
        return 2
    out = os.path.abspath(a.out) if a.out else None
    if out and os.path.isdir(out) and os.listdir(out) and not os.path.isfile(os.path.join(out, MANIFEST)):
        print("REFUSE(2): %s holds files and no %s: not a tree this script wrote" % (out, MANIFEST))
        return 2
    base = os.path.join("/tmp/s4e", os.environ.get("S4E_SEAT") or "anon", "xwgen")
    os.makedirs(base, exist_ok=True)
    work = tempfile.mkdtemp(prefix="xwgen-", dir=base)
    scratch = os.path.join(work, "scratch")
    tree = os.path.join(work, "tree")
    os.makedirs(scratch)
    report = []
    try:
        rows, ncf = generate(src, tree, scratch, a.table, a.patch, not a.no_patch, report)
        if a.classes:
            for r in sorted(report):
                print("XWIN-CLASS %s:%d\t%s\t%s\t%s" % r)
            print("XWIN-CLASSES sites=%d" % len(report))
            for r in report_reads:
                print("XWIN-READS %s" % r)
            return 0
        if a.syntax:
            syntax(tree)
        if a.link_census:
            link_census(tree, work)
        if a.merge_builtins:
            merge_builtins(tree, os.path.abspath(a.merge_builtins))
        if a.check:
            chk = os.path.abspath(a.check)
            if not os.path.isfile(os.path.join(chk, MANIFEST)):
                print("XWIN-GEN FAIL %s holds no %s" % (chk, MANIFEST))
                return 1
            diff = compare(tree, chk)
            if diff:
                print("XWIN-GEN FAIL %s differs from generated plus patch in %d file(s): %s" % (chk, len(diff), " ".join(diff[:20])))
                return 1
            print("XWIN-GEN EQUAL %s files=%d" % (chk, len(rows)))
            return 0
        kept = {}
        for n in HAND_WRITTEN:
            if os.path.isfile(os.path.join(out, n)):
                kept[n] = open(os.path.join(out, n), "rb").read()
        if os.path.isdir(out):
            shutil.rmtree(out)
        shutil.copytree(tree, out, ignore=lambda d, names: [n for n in names if d == tree and n in HAND_WRITTEN])
        for n, data in kept.items():
            with open(os.path.join(out, n), "wb") as f:
                f.write(data)
        for r in rows:
            f = r.split("\t")
            if "/" not in f[0]:
                print("XWIN-GEN %s %s" % (f[0], f[1]))
        print("XWIN-GEN files=%d sources=%d sites=%d patch=%s%s" % (len(rows), ncf, len(report), "no" if a.no_patch else "yes", " syntax=ok" if a.syntax else ""))
        return 0
    except Refuse as e:
        print("REFUSE(2): %s" % e)
        return 2
    except Fail as e:
        print("XWIN-GEN FAIL %s" % e)
        return 1
    finally:
        if a.keep:
            print("XWIN-GEN kept %s" % work)
        else:
            shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
