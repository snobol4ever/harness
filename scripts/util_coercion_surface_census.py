#!/usr/bin/env python3
"""util_coercion_surface_census.py -- THE COERCION SURFACE CENSUS (hq_T, ceo CEO-662, 2026-09-13).

A new descriptor tag owes an arm in every function that switches on a descriptor's tag. Before this census
nobody could say what that set IS: DT_BOOL leaked three separate times (to_real; to_cstring;
is_numeric_like/to_int_slow/rt_concat_parts_d) and every leak was found by watching a working program break.

This instrument asserts BOTH directions, which is the whole point -- a census that only checks one of them
reports its own blind spot as a pass:

  DECLARED -> TREE   every (file, function) in coercion_surface_sites.tsv exists, and its body mentions
                     every DT_* tag that row requires. A row may instead write `DT_X@delegate` to say the
                     site is covered because it hands DT_X to `delegate`; the census then checks the body
                     really calls that delegate AND that some row declares the delegate as carrying DT_X
                     directly. That keeps a correct-by-delegation site from having to grow a redundant arm
                     just to satisfy a grep, which would be a cargo cult with a green light on it.
  TREE -> DECLARED   every `switch (x.v)` / `switch (x->v)` discovered under the scanned roots belongs to a
                     function the TSV declares. A switch on a descriptor tag that nobody enumerated is RED:
                     that is precisely how a list falls quietly behind the tree.

It proves a tag is MENTIONED in a site, never that the arm is CORRECT -- correctness is the oracle's job.
This is the cheap half that was missing entirely.

REFUSES rc=2 rather than printing a success shape it cannot back: no TSV, zero declared rows, or zero
discovered switch sites (a scanner that has lost its subject must never print 0 uncovered).

EXIT: 0 all declared tags present and nothing uncovered - 1 a missing tag or an uncovered site - 2 REFUSED.
No build, no binary, no network: it reads source and a data file.
"""
import os, re, sys
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP")
TSV = os.path.join(ROOT, "..", "harness", "scripts", "coercion_surface_sites.tsv")
SCAN_ROOTS = [os.path.join(ROOT, "src", "runtime"), os.path.join(ROOT, "src", "driver")]
SWITCH_RE = re.compile(r"switch\s*\(\s*[A-Za-z_][A-Za-z0-9_]*\s*(?:\.|->)\s*v\s*\)")
TAG_RE = re.compile(r"(?<![A-Za-z0-9_])(DT_[A-Z_]+|IS_(?:INT|REAL|STR|NULL|CSET|FAIL|NAMEVAL)_fn)(?![A-Za-z0-9_])")
LOSS_RE = re.compile(r"return\s+(?:FAILDESCR|NULVCL)\s*;")
CLASSIFIER_RE = re.compile(r"\A\{\s*return\b[^;]*;\s*\}\Z", re.S)
MIN_TAGS = 3
def refuse(msg):
    print("REFUSE (rc=2): %s" % msg)
    sys.exit(2)


NOT_A_FUNC = {"if", "for", "while", "switch", "return", "sizeof", "__attribute__", "do", "else"}


def _defn_names(text):
    """Every (position, name) whose `name(...)` is followed by `{` -- i.e. a DEFINITION, not a call or a
    prototype. Paren-matched, so `__attribute__((always_inline)) ... _tbl_hval(const DESCR_t *k) {` names
    _tbl_hval and not __attribute__ (measured: the naive regex named the attribute for both table sites)."""
    out = []
    for m in re.finditer(r"(?<![A-Za-z0-9_])([A-Za-z_][A-Za-z0-9_]*)\s*\(", text):
        if m.group(1) in NOT_A_FUNC:
            continue
        depth, j = 0, m.end() - 1
        while j < len(text):
            if text[j] == "(":
                depth += 1
            elif text[j] == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        k = j + 1
        while k < len(text) and text[k] in " \t\r\n":
            k += 1
        if k < len(text) and text[k] == "{":
            out.append((m.start(), m.group(1)))
    return out


_DEFN_CACHE = {}


def defns(path, text):
    """[(pos, name, body)] for `path`, computed ONCE. Keyed on the PATH, never on id(text): a CPython id is
    reused after the object is collected, so an id-keyed memo can answer for a different file entirely."""
    got = _DEFN_CACHE.get(path)
    if got is None:
        out = []
        for pos, name in _defn_names(text):
            i = text.find("{", pos)
            depth, j = 0, i
            while j < len(text):
                if text[j] == "{":
                    depth += 1
                elif text[j] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            out.append((pos, name, text[i:j + 1]))
        got = _DEFN_CACHE[path] = out
    return got


def enclosing_func(path, text, pos):
    """Name of the function whose definition most recently precedes `pos`."""
    best = None
    for p, n, _b in defns(path, text):
        if p > pos:
            break
        best = n
    return best


def main():
    if not os.path.isfile(TSV):
        refuse("coercion_surface_sites.tsv is not on disk -- the declared surface is this census's subject")
    rows, seen = [], set()
    for ln, line in enumerate(open(TSV, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if parts[0] == "file":
            continue
        if len(parts) < 4:
            refuse("coercion_surface_sites.tsv:%d has %d tab-separated field(s), not 4" % (ln, len(parts)))
        f, fn, tags, why = parts[0].strip(), parts[1].strip(), parts[2].strip(), parts[3].strip()
        key = (f, fn)
        if key in seen:
            refuse("coercion_surface_sites.tsv:%d declares %s %s twice" % (ln, f, fn))
        seen.add(key)
        rows.append((f, fn, [t for t in tags.split(",") if t and t != "-"], why, ln))
    if not rows:
        refuse("coercion_surface_sites.tsv declares zero sites -- a census that cannot see its population must never print 0")

    print("== coercion surface census -- declared sites from ../harness/scripts/coercion_surface_sites.tsv")
    bad = 0
    cache = {}
    checked_tags = 0
    for f, fn, tags, why, ln in rows:
        path = os.path.join(ROOT, f)
        if not os.path.isfile(path):
            print("  RED  %s: declared at line %d but the file is not on disk" % (f, ln))
            bad += 1
            continue
        text = cache.setdefault(path, open(path, encoding="utf-8", errors="replace").read())
        body = next((b for _p, n, b in defns(path, text) if n == fn), None)
        if body is None:
            print("  RED  %s %s(): declared at line %d, no definition found -- the TSV is ahead of the tree" % (f, fn, ln))
            bad += 1
            continue
        missing = []
        for t in tags:
            tag, _, delegate = t.partition("@")
            checked_tags += 1
            if delegate:
                if not re.search(r"(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % re.escape(delegate), body):
                    missing.append("%s (claims to delegate to %s, which its body never calls)" % (tag, delegate))
                elif not any(tag in dt for (df, dfn, dt, _w, _l) in rows
                             if dfn in (delegate, "c_" + delegate) and not any("@" in x for x in dt)):
                    missing.append("%s (delegates to %s, which no row declares as carrying %s directly)" % (tag, delegate, tag))
            elif not re.search(r"(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % re.escape(tag), body):
                missing.append(tag)
        if missing:
            print("  RED  %s %s(): no arm for %s" % (f, fn, ", ".join(missing)))
            print("       why this site owes it: %s" % why)
            bad += 1
        else:
            label = ", ".join(tags) if tags else "(no tag required; %s)" % why.split(":")[0]
            print("  ok   %-28s %-22s %s" % (os.path.basename(f), fn + "()", label))

    print("== discovery -- TWO shapes, because the tag leaks through both (ceo CEO-662)")
    print("   (a) switch on a descriptor tag  (b) an if-chain testing >= %d tags with a value-losing return  (c) a one-expression tag-membership classifier" % MIN_TAGS)
    found, uncovered, seen_site = 0, [], set()
    for r in SCAN_ROOTS:
        for dirpath, _dirs, files in os.walk(r):
            for name in sorted(files):
                if not name.endswith((".c", ".cpp")):
                    continue
                path = os.path.join(dirpath, name)
                rel = os.path.relpath(path, ROOT)
                text = cache.setdefault(path, open(path, encoding="utf-8", errors="replace").read())
                sites = {}
                for m in SWITCH_RE.finditer(text):
                    fn = enclosing_func(path, text, m.start())
                    sites.setdefault(fn, ("switch", text.count("\n", 0, m.start()) + 1))
                for pos, fn, b in defns(path, text):
                    if fn in sites or not b:
                        continue
                    if len(set(TAG_RE.findall(b))) < MIN_TAGS:
                        continue
                    if LOSS_RE.search(b):
                        sites[fn] = ("if-chain", text.count("\n", 0, pos) + 1)
                    elif CLASSIFIER_RE.match(b.strip()):
                        sites[fn] = ("classifier", text.count("\n", 0, pos) + 1)
                for fn, (kind, line) in sites.items():
                    if (rel, fn) in seen_site:
                        continue
                    seen_site.add((rel, fn))
                    found += 1
                    if (rel, fn) not in seen:
                        uncovered.append((rel, fn, line, kind))
    if found == 0:
        refuse("scanned %s and found zero coercion sites of either shape -- the scanner has lost its subject, and 0 uncovered would be a lie"
               % ", ".join(os.path.relpath(p, ROOT) for p in SCAN_ROOTS))
    for rel, fn, line, kind in sorted(uncovered):
        print("  RED  %s:%d %s(): a %s coercion site in no coercion_surface_sites.tsv row" % (rel, line, fn, kind))
        bad += 1
    print("-- declared %d site(s), %d required tag assertion(s); discovered %d coercion site(s), %d uncovered"
          % (len(rows), checked_tags, found, len(uncovered)))
    if bad:
        print("GATE FAIL(1) [coercion_surface_census]: %d problem(s)" % bad)
        return 1
    print("GATE PASS(0) [coercion_surface_census]: %d declared site(s), %d discovered coercion site(s), 0 uncovered"
          % (len(rows), found))
    return 0


if __name__ == "__main__":
    sys.exit(main())
