#!/usr/bin/env python3
"""util_size_setters_census.py [--root DIR] [--allowlist FILE] [--json] -- NO RUNNER TYPES A SIZE OR SETS THE WINDOW.

(Lon 2026-09-28 15:4x CDT, in-chat to the ceo, verbatim: "Ensure that every program in every language as it necessary stack size and heap
size values stored in the per-program attribute file, and ensure that those command-line switches and environment variable values are
being used by the harness shell scripts which run all of them."; ceo CEO-1353; RULES.md hard-cap rule clause 8 (g)(4); the coo's row
instruments-every-runner-passes-each-units-declared-heap-and-stack-in-both-modes-never-as-the-window-names-a-missing-one.)

A test unit's heap and stack live WITH THE UNIT (its ALL.csv heap_kb / stack_kb, or <stem>.heap / <stem>.stack beside a standalone
program) and reach SCRIP through the ONE reader of each shape (corpus_suite_harness.py's -d<kb>k -s<kb>k switches; lib_declared_arena.sh's
run_at_declared_table and declared_switches_beside). A runner therefore TYPES NO SIZE and NEVER SETS THE WINDOW: SCRIP_HEAP_KB /
SCRIP_HEAP_MB are what gc_heap.c reads as the collector's INITIAL WINDOW (cap = max(128 MB, window)), so a declared heap exported there
grades a program at window = cap = 128 MB where the shipped window is 1 MB, and under make test-arena it overrides the 128 KB tiny window.

THE CENSUS reads every script under scripts/ (top level: *.sh, *.py) except the invariant gates (test_gate_*, whose fixtures set sizes
on purpose) and names every CODE line -- never a comment, never a Python docstring -- that:
  WINDOW   sets SCRIP_HEAP_KB or SCRIP_HEAP_MB (VAR=, export VAR=, env VAR=, ("VAR=..."), env["VAR"] =, {"VAR": ...}, dict(VAR=...));
  TYPED    types a literal SCRIP size (SCRIP_STACK / SCRIP_HEAP_CAP_KB / SCRIP_HEAP_MAX_MB = <digits>) or a literal -d/-s/-i size switch
           (-d512m, -s256m, -i64m), a ulimit -s, or an oracle's own size (swipl --stack-limit, gprolog GLOBALSZ/LOCALSZ/TRAILSZ/CSTRSZ,
           iconx BLKSIZE/STRSIZE/MSTKSIZE/COEXPSIZE);
except a file named in THE ONE ALLOWLIST, scripts/fixtures/arena_env_setters_allowlist.txt (path<TAB>reason): the GC instruments that
set the window by design, and a file whose every match is a report line. A row naming a missing file, or a file with no match, is
STALE and reds -- an exception outlives its reason only by nobody reading it.
EXIT 0 no file outside the allowlist sets a size and no row is stale; 1 named; 2 could not read (no scripts, a malformed allowlist).
"""
import argparse, ast, json, os, re, sys
from pathlib import Path

WINDOW_RX = [
    re.compile(r'(?<![A-Za-z0-9_])SCRIP_HEAP_(?:KB|MB)=(?!=)'),            # VAR=, export VAR=, env VAR=, "VAR=..." inside argv strings
    re.compile(r'SCRIP_HEAP_(?:KB|MB)["\']\s*\]\s*=(?!=)'),                # env["VAR"] = ...
    re.compile(r'["\']SCRIP_HEAP_(?:KB|MB)["\']\s*:'),                     # {"VAR": ...}
]
TYPED_RX = [
    (re.compile(r'(?<![A-Za-z0-9_])SCRIP_(?:STACK|HEAP_CAP_KB|HEAP_MAX_MB)=["\']?[0-9]'), "a literal SCRIP size"),
    (re.compile(r'(?:^|[\s"\'(=])-[dsi][0-9]+[kKmMgG](?![A-Za-z0-9_])'), "a literal -d/-s/-i size switch"),
    (re.compile(r'\bulimit\s+-[a-zA-Z]*s\b'), "ulimit -s"),
    (re.compile(r'--stack[-_]limit'), "an oracle size (swipl --stack-limit)"),
    (re.compile(r'(?<![A-Za-z0-9_])(?:GLOBALSZ|LOCALSZ|TRAILSZ|CSTRSZ)='), "an oracle size (gprolog)"),
    (re.compile(r'(?<![A-Za-z0-9_])(?:BLKSIZE|STRSIZE|MSTKSIZE|COEXPSIZE)='), "an oracle size (iconx)"),
]
DEFAULT_ALLOW = "scripts/fixtures/arena_env_setters_allowlist.txt"


def _py_docstring_lines(text):
    """line numbers (1-based) inside a Python docstring or any bare string-expression statement -- prose, never code."""
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return set()
    out = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Expr) and isinstance(getattr(node, "value", None), ast.Constant) and isinstance(node.value.value, str):
            out.update(range(node.lineno, (getattr(node, "end_lineno", node.lineno) or node.lineno) + 1))
    return out


def _code_lines(path):
    """[(lineno, text)] of the lines that are code: a whole-line comment (#, after whitespace) is skipped, a trailing # comment is cut
    in shell only where it is plainly a comment ( #), and a Python docstring or bare string statement is skipped."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    skip = _py_docstring_lines(text) if path.suffix == ".py" else set()
    out = []
    for i, ln in enumerate(text.split("\n"), 1):
        if i in skip:
            continue
        s = ln.lstrip()
        if not s or s.startswith("#"):
            continue
        if path.suffix == ".sh" and " # " in ln:
            ln = ln.split(" # ", 1)[0]
        out.append((i, ln))
    return out


PY_STR_WINDOW = re.compile(r'^\s*SCRIP_HEAP_(?:KB|MB)=')                    # a string that IS an env assignment ("VAR=..." argv/env element)
PY_STR_TYPED = [(re.compile(r'^-[dsi][0-9]+[kKmMgG]$'), "a literal -d/-s/-i size switch"),
                (re.compile(r'^\s*ulimit\s+-[a-zA-Z]*s\b'), "ulimit -s"),
                (re.compile(r'^--stack[-_]limit'), "an oracle size (swipl --stack-limit)"),
                (re.compile(r'^\s*(?:SCRIP_(?:STACK|HEAP_CAP_KB|HEAP_MAX_MB)|GLOBALSZ|LOCALSZ|TRAILSZ|CSTRSZ|BLKSIZE|STRSIZE|MSTKSIZE|COEXPSIZE)=[0-9]'), "a literal size in an env assignment")]
PY_CODE_WINDOW = [re.compile(r'(?<![A-Za-z0-9_"\'])SCRIP_HEAP_(?:KB|MB)\s*=(?!=)'),  # dict(VAR=...), keyword argument
                  re.compile(r'SCRIP_HEAP_(?:KB|MB)["\']\s*\]\s*=(?!=)'),         # env["VAR"] = ...
                  re.compile(r'(?:^|[{,])\s*["\']SCRIP_HEAP_(?:KB|MB)["\']\s*:')]  # {"VAR": ...} (a key, never `== "VAR":` ending an if)


def _py_hits(path):
    """[(lineno, class, text)] for a Python script, read by TOKENS: comments are dropped; a docstring is prose; a string literal counts
    only when its WHOLE content is a setting (an argv or env element: "-d512m", "SCRIP_HEAP_KB=64", "ulimit -s 262144") -- a report
    sentence that mentions a size ("ARENA SCRIP_HEAP_KB=%s", "SPITBOL's -s4m") names it and sets nothing."""
    import io, tokenize
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    doc = _py_docstring_lines(text)
    src_lines = text.split("\n")
    out = {}
    code_by_line = {}
    try:
        toks = list(tokenize.generate_tokens(io.StringIO(text).readline))
    except (tokenize.TokenError, IndentationError, SyntaxError):
        return []
    for t in toks:
        if t.type == tokenize.COMMENT:
            continue
        ln = t.start[0]
        if t.type == tokenize.STRING:
            if ln in doc:
                continue
            try:
                val = ast.literal_eval(t.string)
            except Exception:
                val = None                                   # an f-string or a byte string: its text is a report, never an argv
            code_by_line.setdefault(ln, []).append('"S"')
            if isinstance(val, str):
                if PY_STR_WINDOW.search(val):
                    out.setdefault(ln, "WINDOW")
                else:
                    for rx, why in PY_STR_TYPED:
                        if rx.search(val):
                            out.setdefault(ln, "TYPED (%s)" % why); break
            continue
        code_by_line.setdefault(ln, []).append(t.string)
    for ln, parts in code_by_line.items():
        if ln in out or ln in doc:
            continue
        joined = " ".join(parts)
        raw = src_lines[ln - 1] if ln - 1 < len(src_lines) else ""
        if PY_CODE_WINDOW[0].search(joined) or PY_CODE_WINDOW[1].search(raw.split("#")[0]) or PY_CODE_WINDOW[2].search(raw.split("#")[0]):
            out[ln] = "WINDOW"
    return [(ln, cls, (src_lines[ln - 1] if ln - 1 < len(src_lines) else "").strip()[:160]) for ln, cls in sorted(out.items())]


def _sh_hits(path):
    out = []
    for i, ln in _code_lines(path):
        s = ln.lstrip()
        if s.startswith(("echo ", "printf ", "echo\t", "printf\t")):
            continue                                         # a report line prints the size a run used; it sets nothing
        cls = None
        if any(rx.search(ln) for rx in WINDOW_RX):
            cls = "WINDOW"
        else:
            for rx, why in TYPED_RX:
                if rx.search(ln):
                    cls = "TYPED (%s)" % why
                    break
        if cls:
            out.append((i, cls, ln.strip()[:160]))
    return out


def census(root, allow_path):
    sd = Path(root) / "scripts"
    files = sorted([p for p in sd.glob("*.sh")] + [p for p in sd.glob("*.py")])
    files = [p for p in files if not p.name.startswith("test_gate_")]
    if not files:
        return None, "no scripts under %s" % sd
    allow = {}
    ap = Path(allow_path) if os.path.isabs(allow_path) else Path(root) / allow_path
    if ap.is_file():
        for n, ln in enumerate(ap.read_text(encoding="utf-8").splitlines(), 1):
            if not ln.strip() or ln.lstrip().startswith("#"):
                continue
            parts = ln.split("\t")
            if len(parts) < 2 or not parts[1].strip():
                return None, "%s:%d: an allowlist row is path<TAB>reason and the reason is not optional -- got %r" % (ap, n, ln[:120])
            allow[parts[0].strip()] = parts[1].strip()
    hits = {}
    for p in files:
        rel = "scripts/" + p.name
        if p.name == Path(__file__).name:
            continue                                     # the census's own patterns are not settings
        h = _py_hits(p) if p.suffix == ".py" else _sh_hits(p)
        if h:
            hits[rel] = h
    outside = {k: v for k, v in hits.items() if k not in allow}
    stale = []
    for k in allow:
        if not (Path(root) / k).is_file():
            stale.append((k, "the file does not exist"))
        elif k.startswith("scripts/test_gate_"):
            continue                                   # a gate is outside the census by rule; its row is history, not stale
        elif k not in hits:
            stale.append((k, "the file sets no size any more -- the exception outlived its reason"))
    return {"files": len(files), "hits": hits, "outside": outside, "allowed": {k: v for k, v in hits.items() if k in allow},
            "stale": stale, "allowlist": str(ap)}, None


def main():
    a = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    a.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    a.add_argument("--allowlist", default=DEFAULT_ALLOW)
    a.add_argument("--json", action="store_true")
    o = a.parse_args()
    r, err = census(o.root, o.allowlist)
    if err:
        print("REFUSE(rc=2): util_size_setters_census.py: %s" % err); sys.exit(2)
    if o.json:
        print(json.dumps(r, indent=1)); sys.exit(1 if (r["outside"] or r["stale"]) else 0)
    nl = sum(len(v) for v in r["outside"].values())
    for k in sorted(r["outside"]):
        for i, cls, t in r["outside"][k]:
            print("SIZE_SETTER %s:%d %s :: %s" % (k, i, cls, t))
    for k, why in r["stale"]:
        print("STALE_ALLOWLIST_ROW %s -- %s" % (k, why))
    print("SIZE_SETTERS_CENSUS scripts=%d files_setting_a_size=%d allowlisted=%d outside_the_allowlist=%d (%d line(s)) stale_rows=%d allowlist=%s"
          % (r["files"], len(r["hits"]), len(r["allowed"]), len(r["outside"]), nl, len(r["stale"]), r["allowlist"]))
    sys.exit(1 if (r["outside"] or r["stale"]) else 0)


if __name__ == "__main__":
    main()
