#!/usr/bin/env python3
"""util_sno_bookkeeping_derivation_census.py [--population sample|corpus] [--list]

CAN THE FIVE BOOKKEEPING ATTRIBUTES THE C SNOBOL4 PARSER ATTACHES TO EVERY STATEMENT BE DERIVED FROM ONE START LINE PER STATEMENT AND THE
SOURCE TEXT? (hq_snocone 2026-10-08, ARCH-PARSER-SC-BOOTSTRAP.md section 3.6 G1: the tree-for-tree gate omits :line :lline :file :stno :src
(src/ir/ast_print.c is_bookkeeping_attr) while src/lower/lower_snobol4.c reads them, and the .sc parsers produce none.) This census reads what
the C parser built -- out/parser_snobol4 under PARSER_ATTRS=1 prints one row per TT_STMT/TT_END: line lline stno lbl src file incl -- and tests
the four rules a linked parser's exporter would apply, each statement against the C parser's own value:
  R1 :lline  equals :line (14533 of 14533 statements on the 2026-10-08 corpus reading; the C parser never sets lline apart from line).
  R2 :stno   equals the statement's 1-based ordinal in the program, END included (END carries no :src, so R3 and R4 skip it).
  R3 :src    is the statement's FIRST physical line with trailing blanks/CR removed (stmt_src_slice's n2 is n1 + 1 whenever the statement list
             is walked one statement at a time), or NULL when that line is blank, a comment (*) or a control line (-), when a labelled
             statement's line does not begin with its label, or when an unlabelled one does not begin with a blank or tab; the C fallback text
             "<stmt N, line M: source not resolvable>" is R5 below.
  R5 when R3 yields NULL, :src is the fallback text LABEL + ("  " if labelled else 8 blanks) + "<stmt STNO, line LINE: source not resolvable>".
  R4 :src    is the EMPTY string for a null statement (a blank line or a ';' left over), and a null statement's :line is the PREVIOUS
             statement's :line, or 1 when it is the first, or its own line when that physical line is whitespace-only but not empty, or begins with ';' after blanks (the C lexer
             keeps the line it last read).
One process per file, because the loop harness (PARSER_FILES) hands a file's leading null statement the previous file's last line number.
It tests files WITHOUT -INCLUDE/-COPY (the include line map is G1b and is not derivable from one source text) and reports how many it skipped.
rc 0 = every rule holds on every statement of every measured file; rc 1 = a mismatch (the first five are printed); rc 2 = could not measure
(no instrument, an instrument that does not know PARSER_ATTRS, an empty population). Runs serially under nice 19 (lib_fanout.sh, CEO-1333).
POPULATION sample (default) = corpus/benchmarks/snobol4; corpus = every .sno/.spt/.sbl under corpus/ outside .git, library/ and the ALL.* containers.
"""
import os, re, subprocess, sys, tempfile, collections

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
S4E = os.environ.get("S4E_HOME") or os.path.dirname(ROOT)
CORPUS = os.environ.get("CORPUS") or os.path.join(S4E, "corpus")
INSTR = os.environ.get("PARSER_SNOBOL4") or os.path.join(ROOT, "out", "parser_snobol4")
EXTS = (".sno", ".spt", ".sbl")
ROW = re.compile(r"^(STMT|END)((?: \w+=(?:\"(?:\\.|[^\"\\])*\"|\S+))*)\s*$")
KV = re.compile(r' (\w+)=("(?:\\.|[^"\\])*"|\S+)')


def refuse(msg):
    print("REFUSE(2) [util_sno_bookkeeping_derivation_census]: " + msg)
    sys.exit(2)


def unquote(v):
    if not v.startswith('"'):
        return v
    out, i, body = [], 0, v[1:-1]
    while i < len(body):
        c = body[i]
        if c == "\\" and i + 1 < len(body):
            n = body[i + 1]
            out.append({"n": "\n", "\\": "\\", '"': '"'}.get(n, n))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def population(which):
    base = os.path.join(CORPUS, "benchmarks", "snobol4") if which == "sample" else CORPUS
    if not os.path.isdir(base):
        refuse("no corpus at " + base)
    files = []
    for d, ds, fs in os.walk(base):
        ds[:] = [x for x in ds if x != ".git" and not (which == "corpus" and d == CORPUS and x == "library")]
        for f in fs:
            if f.endswith(EXTS) and not f.startswith("ALL."):
                files.append(os.path.join(d, f))
    return sorted(files)


def measure(files):
    env = dict(os.environ, PARSER_ATTRS="1", SNO_LIB=os.path.join(CORPUS, "include"))
    env.pop("PARSER_FILES", None)
    blocks = {}
    for f in files:
        try:
            r = subprocess.run([INSTR, f], capture_output=True, env=env, timeout=120)
            blocks[f] = [ln for ln in r.stdout.decode("latin-1").split("\n") if ln]
        except subprocess.TimeoutExpired:
            blocks[f] = ["Parse Error"]
    return blocks


def main():
    which = "sample"
    if "--population" in sys.argv:
        which = sys.argv[sys.argv.index("--population") + 1]
    if which not in ("sample", "corpus"):
        refuse("population must be sample or corpus")
    if not os.access(INSTR, os.X_OK):
        refuse("no instrument at %s (make out/parser_snobol4)" % INSTR)
    try:
        os.nice(19)
    except OSError:
        pass
    probe = tempfile.NamedTemporaryFile("w", suffix=".sno", delete=False)
    probe.write("        X = 1\nEND\n")
    probe.close()
    pb = measure([probe.name]).get(probe.name, [])
    os.unlink(probe.name)
    if not pb or not ROW.match(pb[0]) or "line=" not in pb[0]:
        refuse("the instrument does not print statement attributes under PARSER_ATTRS=1 (rebuild out/parser_snobol4 from a tree with that mode)")
    files = population(which)
    if not files:
        refuse("empty population")
    blocks = measure(files)
    st, bad, unres = collections.Counter(), [], []
    for f in files:
        rows = blocks.get(f)
        if rows is None:
            st["not_reported"] += 1
            continue
        if any(r.startswith("Parse Error") for r in rows) or not rows:
            st["refused_or_empty"] += 1
            continue
        parsed = [ROW.match(r) for r in rows]
        if not all(parsed):
            st["unreadable"] += 1
            continue
        recs = [dict(KV.findall(m.group(2)), kind=m.group(1)) for m in parsed]
        raw = open(f, "rb").read()
        if re.search(rb"^-(include|copy)\b", raw, re.I | re.M) or any("incl" in r for r in recs):
            st["skipped_include"] += 1
            continue
        lines = raw.decode("latin-1").split("\n")
        if lines and lines[-1] == "":
            lines.pop()
        st["files"] += 1
        prev = None
        for idx, r in enumerate(recs):
            n1, src = int(r["line"]), unquote(r.get("src", '""'))
            st["statements"] += 1
            if int(r["lline"]) == n1:
                st["R1_lline_eq_line"] += 1
            else:
                st["R1_FAIL"] += 1
                bad.append(("R1", f, n1, r["lline"]))
            if int(r["stno"]) == idx + 1:
                st["R2_stno_eq_ordinal"] += 1
            else:
                st["R2_FAIL"] += 1
                bad.append(("R2", f, idx + 1, r["stno"]))
            if r["kind"] == "END":
                prev = n1
                continue
            if src == "":
                st["null_statements"] += 1
                own = 1 <= n1 <= len(lines) and lines[n1 - 1] != "" and (lines[n1 - 1].strip(" \t\r") == "" or lines[n1 - 1].lstrip(" \t").startswith(";"))
                want = prev if prev is not None else 1
                if n1 == want:
                    st["R4_null_line_ok"] += 1
                elif own:
                    st["R4_null_on_whitespace_line_ok"] += 1
                else:
                    st["R4_FAIL"] += 1
                    bad.append(("R4", f, n1, want))
            elif "source not resolvable" in src and src.endswith(">"):
                label = unquote(r.get("lbl", '""'))
                want = "%s%s<stmt %d, line %d: source not resolvable>" % (label, "  " if label else "        ", int(r["stno"]), n1)
                first = lines[n1 - 1].rstrip(" \t\r") if 1 <= n1 <= len(lines) else None
                rule_none = first is None or first == "" or first[0] in "*-" or (label and not first.startswith(label)) or (not label and first[0] not in " \t")
                if src == want and rule_none:
                    st["R5_fallback_text_ok"] += 1
                else:
                    st["R5_FAIL"] += 1
                    bad.append(("R5", f, n1, "C=%r want=%r rule_none=%r" % (src[:70], want[:70], bool(rule_none))))
                unres.append((os.path.relpath(f, CORPUS), n1, lines[n1 - 1][:50] if 1 <= n1 <= len(lines) else None))
            else:
                first = lines[n1 - 1].rstrip(" \t\r") if 1 <= n1 <= len(lines) else None
                label = unquote(r.get("lbl", '""'))
                if first is None or first == "" or first[0] in "*-":
                    want = None
                elif label and not first.startswith(label):
                    want = None
                elif not label and first[0] not in " \t":
                    want = None
                else:
                    want = first
                if want is not None and src == want:
                    st["R3_src_first_line_ok"] += 1
                else:
                    st["R3_FAIL"] += 1
                    bad.append(("R3", f, n1, "C=%r derived=%r" % (src[:60], None if want is None else want[:60])))
            prev = n1
    print("POPULATION %s: %d files listed, %d measured, %d skipped for -INCLUDE/-COPY (G1b), %d refused or empty, %d statements" % (
        which, len(files), st["files"], st["skipped_include"], st["refused_or_empty"], st["statements"]))
    for k in sorted(k for k in st if k[0] in "R" and k[1].isdigit() or k in ("null_statements", "UNRESOLVABLE")):
        print("  %-24s %d" % (k, st[k]))
    fails = sum(st[k] for k in st if k.endswith("_FAIL"))
    for b in bad[:5]:
        print("  FIRST MISMATCHES:" if b is bad[0] else "", b)
    if "--list" in sys.argv:
        for b in bad:
            print(b)
        for u in unres:
            print(("UNRESOLVABLE",) + u)
    if st["statements"] == 0:
        refuse("no statement was measured")
    print("VERDICT: " + ("every rule holds on every measured statement" if not fails else "%d MISMATCH(ES)" % fails))
    sys.exit(1 if fails else 0)


main()
