#!/usr/bin/env python3
import os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
KINDS = {"RTX_DECLINE": "AL", "RTX_DECLINE_INT": "INT", "RTX_DECLINE_PTR": "PTR", "RTX_NOT_HANDLED": "AL", "RTX_NOT_HANDLED_INT": "INT", "RTX_NOT_HANDLED_PTR": "PTR"}
FUNC = re.compile(r"^RTX_FUNC\((\w+)\)")
ENDF = re.compile(r"^RTX_ENDF\((\w+)\)")
ENTRY = re.compile(r"^RTX_ENTRY\((\w+)\)")
ROW = re.compile(r"^RTX_TWIN\((AL|INT|PTR),\s*[^,]+,\s*(\w+),\s*(\w+),")
READS = re.compile(r"^\s*(cmp|test)\b")


def verdict_kinds(ln):
    if READS.match(ln):
        return []
    return [KINDS[tok] for tok in re.findall(r"\bRTX_[A-Z_]+\b", ln) if tok in KINDS]


def declining_leaves(rtx_dir):
    out = {}
    for fn in sorted(os.listdir(rtx_dir)):
        if not fn.endswith(".s"):
            continue
        cur = None
        names = []
        for ln in open(os.path.join(rtx_dir, fn), encoding="utf-8"):
            m = FUNC.match(ln)
            if m:
                cur = m.group(1)
                names = [cur]
                continue
            if ENDF.match(ln):
                cur = None
                names = []
                continue
            if cur:
                m = ENTRY.match(ln)
                if m:
                    names.append(m.group(1))
                    continue
                for k in verdict_kinds(ln):
                    for nm in names:
                        out.setdefault(nm, set()).add(k)
    return out


def table_rows(path):
    rows = {}
    for ln in open(path, encoding="utf-8"):
        m = ROW.match(ln)
        if m:
            rows[m.group(2)] = (m.group(1), m.group(3))
    return rows


def check(leaves, rows, symbols):
    bad = []
    for leaf, kinds in sorted(leaves.items()):
        if len(kinds) != 1:
            bad.append("%s declines in more than one kind (%s)" % (leaf, ",".join(sorted(kinds))))
        elif leaf not in rows:
            bad.append("%s declines (%s) and is no row of rtx_twin_table.inc: the box would take the verdict byte for a value" % (leaf, next(iter(kinds))))
        elif rows[leaf][0] not in kinds:
            bad.append("%s declines as %s and its row says %s" % (leaf, next(iter(kinds)), rows[leaf][0]))
    for leaf, (kind, twin) in sorted(rows.items()):
        if leaf not in leaves:
            bad.append("row %s names a leaf that never declines: dead weight at every call site" % leaf)
        if symbols is not None and leaf not in symbols:
            bad.append("row %s names a leaf the runtime does not define" % leaf)
        if symbols is not None and twin not in symbols:
            bad.append("row %s names a twin %s the runtime does not define" % (leaf, twin))
    return bad


STRLIT = re.compile(r'"(?:\\.|[^"\\])*"')
DECL = re.compile(r"^\s*(?:extern\s+)?[\w\s\*]+\b(\w+)\s*\([^()]*\)\s*;\s*$")


def c_uses(lines, leaves):
    out = []
    for i, ln in enumerate(lines, 1):
        code = STRLIT.sub('""', ln)
        if DECL.match(code):
            continue
        for leaf in leaves:
            if re.search(r"(?<!\w)" + leaf + r"\b", code):
                out.append((i, leaf))
    return out


def c_callers(root, leaves):
    bad = []
    base = os.path.join(root, "src", "runtime")
    for d, _, files in os.walk(base):
        if os.path.relpath(d, base).split(os.sep)[0] == "rtx":
            continue
        for f in sorted(files):
            if not f.endswith((".c", ".h")) or f == "rtx_try.h":
                continue
            p = os.path.join(d, f)
            for i, leaf in c_uses(open(p, encoding="utf-8", errors="replace").read().splitlines(), leaves):
                bad.append("%s:%d calls the declining leaf %s from C: the verdict byte would be taken for a value -- call its twin, or rtx_try_%s in rtx_try.h" % (os.path.relpath(p, root), i, leaf, leaf))
    return bad


def runtime_symbols(so):
    r = subprocess.run(["nm", "-D", "--defined-only", so], capture_output=True, text=True)
    if r.returncode != 0:
        return None
    return set(ln.split()[-1] for ln in r.stdout.splitlines() if ln.strip())


def selftest(leaves, rows, symbols):
    fails = []
    some = sorted(rows)[0]
    p = dict(rows); del p[some]
    if not any(some in b and "no row" in b for b in check(leaves, p, symbols)): fails.append("a leaf without a row was not caught")
    p = dict(rows); p["rt_never_declines_planted"] = ("AL", "c_rt_never_declines_planted")
    if not any("never declines" in b for b in check(leaves, p, symbols)): fails.append("a row without a decline was not caught")
    p = dict(rows); k = "INT" if rows[some][0] != "INT" else "AL"; p[some] = (k, rows[some][1])
    if not any("row says" in b for b in check(leaves, p, symbols)): fails.append("a wrong kind was not caught")
    if symbols is not None:
        s = set(symbols); s.discard(rows[some][1])
        if not any("twin" in b for b in check(leaves, rows, s)): fails.append("a missing twin was not caught")
    if verdict_kinds("    cmp     al, RTX_NOT_HANDLED") or verdict_kinds("    test    rax, RTX_NOT_HANDLED_PTR"): fails.append("a leaf reading its callee's verdict was read as a decline")
    if verdict_kinds("    RTX_DECLINE") != ["AL"] or verdict_kinds("    mov     eax, RTX_NOT_HANDLED_INT") != ["INT"]: fails.append("a decline statement was not read as one")
    planted = ["            DESCR_t v = (strict ? %s : c_rt_subscript_var)(a, b);" % some, "    return RT_GC_CALLBACK(%s(argv[0], argv[1]));" % some]
    quiet = ["        extern DESCR_t %s(DESCR_t, DESCR_t);" % some, "        extern DESCR_t c_%s(DESCR_t, DESCR_t);" % some, '    fprintf(stderr, "BOMB %s: no");' % some, "    DESCR_t r = c_%s(a, b);" % some]
    if [i for i, _ in c_uses(planted, [some])] != [1, 2]: fails.append("a C call of a declining leaf (a call, a function-pointer pick) was not caught")
    if c_uses(quiet, [some]): fails.append("a declaration, a twin call or a string naming a declining leaf was read as a C call")
    return fails


def main():
    rtx = os.path.join(ROOT, "src", "runtime", "rtx")
    tab = os.path.join(ROOT, "src", "templates", "x86", "rtx_twin_table.inc")
    so = os.path.join(ROOT, "out", "libscrip_rt.so")
    if not os.path.isfile(tab) or not os.path.isdir(rtx):
        print("REFUSED(2): the twin table or the rtx directory is missing")
        return 2
    leaves = declining_leaves(rtx)
    rows = table_rows(tab)
    symbols = runtime_symbols(so) if os.path.exists(so) else None
    if symbols is None:
        print("REFUSED(2): %s cannot be read with nm -D" % so)
        return 2
    if len(leaves) < 10 or len(rows) < 10:
        print("REFUSED(2): only %d declining leaves and %d rows were read" % (len(leaves), len(rows)))
        return 2
    bad = check(leaves, rows, symbols) + c_callers(ROOT, sorted(set(leaves) | set(rows)))
    st = selftest(leaves, rows, symbols)
    for b in bad:
        print("  VIOLATION  " + b)
    for f in st:
        print("  SELF-TEST FAIL  " + f)
    print("RTX TWIN TABLE: %d declining leaves, %d rows, %d violations, self-test %s" % (len(leaves), len(rows), len(bad), "FAIL" if st else "PASS (a leaf without a row, a row without a decline, a wrong kind and a missing twin each read red by name; a cmp or test of a callee's verdict is no decline; a C call of a declining leaf reads red, its declaration, its twin and a string naming it do not)"))
    return 1 if (bad or st) else 0


if __name__ == "__main__":
    sys.exit(main())
