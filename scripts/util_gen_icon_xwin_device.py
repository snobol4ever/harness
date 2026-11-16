#!/usr/bin/env python3
"""util_gen_icon_xwin_device.py -- the Icon window facility's generated tree, W1 THE GENERATOR (skill icon reference.md section 9).

Copies the oracle's sources to scratch, writes define.h as Config linux and Graphics 1, redefines GRFX_ALLOC to the
collected record allocator, runs the oracle's own translator rtt -x over its six window .r sources (the device layer and
fwindow.r, the function layer) and the conversions cnv.r and def.r, converts every allocation call by the class its site has in the committed table
designs/icon_xwin/ALLOC-CLASSES.tsv, rewrites the includes so no line names a scratch path, copies the oracle's headers,
writes xwin_alloc.h (the class macros), xwin_gen.c (the record layouts, the roots, the detached-image hook) and
xwin_functions.tsv (the 48 functions from their headers), xwin_builtins.tsv (their rows of src/runtime/builtins.tsv)
and xwin_entries.c (one bt_ entry a function, into the adapter rt_xwin_call_h; officer_01's format), applies designs/icon_xwin/xwin.patch and writes the tree to
--out with XWIN-MANIFEST.tsv. xwin_shim.h, W3's shim header, is hand-written: if it stands in the tree the gate does not
compare it and --out keeps it; the generated files include none of it (h/rt.h declares the runtime names they call). Nothing under the oracle tree is written; the scratch is removed unless --keep.

  --out DIR        write the tree (DIR absent, empty, or a tree this script wrote)
  --check DIR      regenerate and compare with DIR byte for byte: the gate, generated plus patch
  --classes        print every site of the translated C with its class; a site no row names, or a row no site has, is refused
  --no-patch       write the tree without the patch (to remake the patch: diff -ru the two trees)
  --syntax         gcc -fsyntax-only every .c of the tree
  --merge-builtins TSV  with --out or --check: write the 48 rows of xwin_builtins.tsv into SCRIP's builtins.tsv, an xwin
                   row already there keeping its bid, a new one taking the next free id
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
TABLE = os.path.join(HARNESS, "designs", "icon_xwin", "ALLOC-CLASSES.tsv")
PATCH = os.path.join(HARNESS, "designs", "icon_xwin", "xwin.patch")
DEFAULT_SRC = "/home/resources/icon-master/src"
RUN_SOURCES = ["rwindow.r", "rcolor.r", "rimage.r", "rwinrsc.r", "rwinsys.r", "fwindow.r", "cnv.r", "def.r"]
OWN_DATA = ("tend", "t_errornumber", "t_errorvalue", "t_have_val")
OWN_DATA_SOURCE = os.path.join("runtime", "init.r")
BY_VALUE = {"kywd_prog": "xwin_kywd_prog"}
RUN_INCLUDES = ["rxwin.ri", "rxrsc.ri"]
PLAIN_SOURCE = os.path.join("common", "xwindow.c")
DEFINE_H = "#define Config linux\n#define Graphics 1\n"
MANIFEST = "XWIN-MANIFEST.tsv"
HAND_WRITTEN = ("xwin_shim.h",)
GRFX_OLD = "var = (struct type *)calloc(1, sizeof(struct type));"
GRFX_NEW = "var = (struct type *)XWIN_LREC(type);"
CALL_RE = re.compile(r"(?<![\w.>$])(malloc|calloc|realloc|salloc|alloc|strdup|free)\s*\(")
LREC_RE = re.compile(r"(\w+)\s*=\s*\(struct (\w+) \*\)XWIN_LREC\((\w+)\)")
CLASSES = ("RECORD", "HELD", "PTRS", "ROOTED", "CALLEXT", "SCRATCH")
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


def translate(src, scratch):
    shutil.copytree(os.path.join(src, "h"), os.path.join(scratch, "h"))
    shutil.copytree(os.path.join(src, "runtime"), os.path.join(scratch, "runtime"))
    os.makedirs(os.path.join(scratch, "common"))
    shutil.copyfile(os.path.join(src, PLAIN_SOURCE), os.path.join(scratch, PLAIN_SOURCE))
    with open(os.path.join(scratch, "h", "define.h"), "w") as f:
        f.write(DEFINE_H)
    grttin = os.path.join(scratch, "h", "grttin.h")
    text = open(grttin).read()
    if text.count(GRFX_OLD) != 1:
        raise Refuse("h/grttin.h holds %d copies of the GRFX_ALLOC body %r, wants 1" % (text.count(GRFX_OLD), GRFX_OLD))
    with open(grttin, "w") as f:
        f.write(text.replace(GRFX_OLD, GRFX_NEW))
    os.makedirs(os.path.join(scratch, "rtt"))
    rtt = os.path.join(scratch, "rtt", "rtt")
    shutil.copy2(os.path.join(src, "rtt", "rtt"), rtt)
    rt = os.path.join(scratch, "runtime")
    r = subprocess.run([rtt, "-x"] + RUN_SOURCES, cwd=rt, capture_output=True, text=True)
    if r.returncode != 0:
        raise Fail("translator rc=%d: %s" % (r.returncode, tail(r.stderr or r.stdout)))
    cfiles = [os.path.join(rt, "x" + name[:-2] + ".c") for name in RUN_SOURCES]
    cfiles.append(os.path.join(scratch, PLAIN_SOURCE))
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
                cl = balanced(line, op)
                if row is None:
                    line = line[:pos] + "XWIN_FREE" + line[op:]
                elif call == "free":
                    if row["cls"] != "CALLEXT":
                        raise Refuse("class table row %d: a free row must be CALLEXT, is %s" % (row["row"], row["cls"]))
                    arg = strip_cast(line[op + 1:cl])
                    if arg != row["target"]:
                        raise Refuse("class table row %d: free(%s) is not of %s" % (row["row"], arg, row["target"]))
                    line = line[:pos] + "XWIN_FREE_NULL(" + arg + ")" + line[cl + 1:]
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


def post_pass(lines, scratch):
    out = []
    marker = scratch.rstrip("/") + "/"
    for i, line in enumerate(lines):
        if i < 4 and re.match(r"^ \* \w{3} \w{3} [ \d]\d \d\d:\d\d:\d\d \d{4}$", line):
            out.append(" * generated by util_gen_icon_xwin_device.py; regenerated, never edited")
            continue
        if re.match(r'^#include "[^"]*/rtt/\.\./h/rt\.h"$', line):
            out.append('#include "xwin_alloc.h"')
            out.append('#include "h/rt.h"')
            continue
        line = re.sub(r'"[^"]*/rtt/\.\./h/', '"h/', line)
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


def layout_fields(pp, tag, types, prefix=""):
    tags, ptr_typedefs, plain_typedefs = types
    body = " ".join(struct_body(pp, tag).split())
    out = []
    for decl in [d.strip() for d in body.split(";") if d.strip()]:
        if "{" in decl or "(" in decl:
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
    r = subprocess.run(["bash", CC_SLOT, "gcc", "-E", "-I.", ".xwin_probe.c"], cwd=tree, capture_output=True, text=True)
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


def write_alloc_h(tree, tags, used):
    lines = ["#ifndef XWIN_ALLOC_H", "#define XWIN_ALLOC_H", "#include <stddef.h>", "#include <stdint.h>", "#include <string.h>",
             "void *rt_lrec_alloc(size_t nbytes, const uint64_t *layout);",
             "void *rt_lrec_realloc(void *p, size_t nbytes, const uint64_t *layout);",
             "void *rt_ws_alloc_raw(size_t nbytes);",
             "struct _XImage;",
             "int xwin_detached_destroy(struct _XImage *im);",
             "struct descrip;"]
    for name, fn in sorted(BY_VALUE.items()):
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
    lines.append("#define XWIN_LREC(tag) rt_lrec_alloc(sizeof(struct tag), xwin_layout_##tag)")
    lines.append("static inline void *xwin_calloc_raw(size_t n, size_t s) { void *p = rt_ws_alloc_raw(n * s); if (p) memset(p, 0, n * s); return p; }")
    lines.append("static inline char *xwin_salloc_raw(const char *s) { size_t n = strlen(s) + 1; char *p = (char *)rt_ws_alloc_raw(n); if (p) memcpy(p, s, n); return p; }")
    if ("HELD", "realloc") in used:
        lines.append("void *rt_rvec_realloc(void *p, size_t nbytes);")
    for key in sorted(used):
        lines.append(MACRO_DEFS[key])
    lines.append("#define XWIN_FREE(p) ((void)0)")
    lines.append("#define XWIN_FREE_NULL(p) ((p) = 0)")
    lines.append("#endif")
    with open(os.path.join(tree, "xwin_alloc.h"), "w") as f:
        f.write("\n".join(lines) + "\n")


def own_data(src):
    text = open(os.path.join(src, OWN_DATA_SOURCE)).read()
    out = []
    for name in OWN_DATA:
        m = re.search(r"(?m)^([A-Za-z_][\w ]*?[\s*]+%s\b[^;]*;)" % re.escape(name), text)
        if not m:
            raise Refuse("%s has no file-scope definition of %s" % (OWN_DATA_SOURCE, name))
        out.append(" ".join(m.group(1).split()))
    return out


def write_gen_c(tree, tags, roots, pp, segs, by_source, src):
    types = oracle_types(segs)
    lines = ['#include "xwin_alloc.h"', '#include "h/rt.h"']
    lines += own_data(src)
    for r in roots:
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


def write_builtins(tree, rows):
    tsv, c = [], ['#include "ir/descr.h"', "DESCR_t rt_xwin_call_h(void *zfn, int nparms, DESCR_t *argv, int n, void **hslot);"]
    for r in rows:
        name, entry, res, nparams, suspends, c_args = r.split("\t")[:6]
        conv = "gen" if suspends == "yes" else "leaf"
        tsv.append("-\ticn\t%s\t0\t%s\tbt_%s\t%s\t-\t-\t0\txwin" % (name, nparams, name, conv))
        c.append(SEPARATOR)
        c.append("extern int %s(%s);" % (entry, "int, void *" if c_args == "r_nargs,r_args" else "void *"))
        if conv == "gen":
            c.append("DESCR_t bt_%s_h(DESCR_t *args, int nargs, void **hslot) { return rt_xwin_call_h((void *)%s, %s, args, nargs, hslot); }" % (name, entry, nparams))
        else:
            c.append("DESCR_t bt_%s(DESCR_t *args, int nargs) { return rt_xwin_call_h((void *)%s, %s, args, nargs, (void **)0); }" % (name, entry, nparams))
    for line in c:
        if len(line) > 200:
            raise Refuse("an entry line is %d columns, over 200: %s" % (len(line), line[:80]))
    with open(os.path.join(tree, "xwin_builtins.tsv"), "w") as f:
        f.write("# the 48 rows of src/runtime/builtins.tsv this tree serves, bid left to --merge-builtins (an id is assigned once and never reused)\n")
        f.write("\n".join(tsv) + "\n")
    with open(os.path.join(tree, "xwin_entries.c"), "w") as f:
        f.write("\n".join(c) + "\n")


def merge_builtins(tree, path):
    rows = [l.rstrip("\n").split("\t") for l in open(os.path.join(tree, "xwin_builtins.tsv")) if not l.startswith("#") and l.strip()]
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


def write_manifest(tree):
    rows = []
    for dp, dn, fn in os.walk(tree):
        dn.sort()
        for n in sorted(fn):
            rel = os.path.relpath(os.path.join(dp, n), tree)
            if rel == MANIFEST or rel in HAND_WRITTEN:
                continue
            data = open(os.path.join(dp, n), "rb").read()
            rows.append("%s\t%d\t%s" % (rel, data.count(b"\n"), hashlib.md5(data).hexdigest()))
    with open(os.path.join(tree, MANIFEST), "w") as f:
        f.write("# path\tlines\tmd5 (util_gen_icon_xwin_device.py; regenerated, never edited)\n" + "\n".join(rows) + "\n")
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
    return ["-I.", "-I" + scrip_src()] if n == "xwin_entries.c" else ["-I."]


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
    cfiles = translate(src, scratch)
    converted, used = classify_and_convert(cfiles, sites, report)
    os.makedirs(os.path.join(tree, "h"))
    by_source = {}
    made_fwindow = ""
    for p in cfiles:
        text = "\n".join(post_pass(converted[p], scratch))
        name = os.path.basename(p)
        with open(os.path.join(tree, name), "w", errors="surrogateescape") as f:
            f.write(text)
        if name == "xfwindow.c":
            made_fwindow = text
        for s in set(re.findall(r'#line \d+ "([^"/]*\.ri?)"', text)):
            by_source[s] = by_source.get(s, "") + "\n" + text
    for n in sorted(os.listdir(os.path.join(scratch, "h"))):
        if n.endswith(".h"):
            shutil.copyfile(os.path.join(scratch, "h", n), os.path.join(tree, "h", n))
    tags = record_tags(sites)
    write_alloc_h(tree, tags, used)
    pp, segs = preprocess(tree)
    write_gen_c(tree, tags, roots, pp, segs, by_source, src)
    nfun = write_functions(src, tree, made_fwindow)
    if nfun != 48:
        raise Fail("xwin_functions.tsv holds %d functions, wants 48" % nfun)
    if use_patch:
        apply_patch(tree, patch)
    for dp, dn, fn in os.walk(tree):
        for n in fn:
            data = open(os.path.join(dp, n), "rb").read()
            if scratch.encode() in data or (n.endswith((".c", ".h")) and b"/tmp/" in data):
                raise Refuse("%s names a scratch or /tmp path" % os.path.relpath(os.path.join(dp, n), tree))
    return write_manifest(tree), len(cfiles)


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


def main():
    ap = argparse.ArgumentParser(description="Regenerate the Icon window facility's tree from the oracle's sources.")
    ap.add_argument("--src", default=DEFAULT_SRC)
    ap.add_argument("--out")
    ap.add_argument("--check")
    ap.add_argument("--classes", action="store_true")
    ap.add_argument("--table", default=TABLE)
    ap.add_argument("--patch", default=PATCH)
    ap.add_argument("--no-patch", action="store_true")
    ap.add_argument("--syntax", action="store_true")
    ap.add_argument("--link-census", action="store_true")
    ap.add_argument("--merge-builtins")
    ap.add_argument("--keep", action="store_true")
    a = ap.parse_args()
    if sum(1 for x in (a.out, a.check, a.classes) if x) != 1:
        print("REFUSE(2): give one of --out DIR, --check DIR, --classes")
        return 2
    src = os.path.abspath(a.src)
    need = ["rtt/rtt", "h/graphics.h", "h/xwin.h", "h/grttin.h", PLAIN_SOURCE, OWN_DATA_SOURCE] + [os.path.join("runtime", n) for n in RUN_SOURCES + RUN_INCLUDES]
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
