#!/usr/bin/env python3
"""util_board_field_matcher_census.py -- EVERY MATCHER THAT READS A BOARD LINE BY POSITION (coo, CEO-839, row
instruments-rc2-gate-arm9-anchors-on-board-line-position-and-has-been-red-since-shipped-entered-the-line).

THE DISEASE, stated once: a check that matches a SUITE_BOARD line by ADJACENCY breaks the day a correct field is
inserted, and it breaks SILENTLY -- it reports the board as absent, which reads like "the run graded nothing"
rather than "my pattern is stale".  test_gate_harness_refusal_is_rc2.sh arm 9 greps
'^SUITE_BOARD family=ALL total=2 m3_n=2 ' and has been RED since SCRIP 3ade619f2 put `shipped=` and `outside=`
between total= and m3_n= (CEO-749/772).  The board it rejects is correct.  That is the instrument law
EXTRACTION ANCHORS ON IDENTITY, NEVER POSITION failing inside a gate whose whole job is guarding a refusal code.

WHAT THIS COUNTS, and what it deliberately does not:
  MATCHER  a string literal used as a PATTERN -- grep/grep -q/egrep/case, or re.compile/search/match/findall/
           fullmatch/sub, or bash =~.  Only a matcher can go stale against a board it did not write.
  PRINTER  a literal that is EMITTED (echo/printf/print/ck label).  A runner printing its own board line is the
           board's author, not its reader: inserting a field there is the landing, not the breakage.  Counted
           and NAMED on its own line so the next reader does not re-walk the same path, never in the population.
  FIXTURE  a literal ASSIGNED to a variable and written into a scratch file -- sample board text a matcher reads.
           Same reasoning as PRINTER.
  ADJACENT two board fields separated by nothing but literal whitespace: `total=2 m3_n=2`.  ANY insertion between
           them breaks it.  THIS IS THE POPULATION, and its want is 0.
  ORDERED  two board fields separated by a wildcard: `family=\\S+ .*m3_n=(\\d+)`.  Survives an insertion, breaks
           only on a REORDER.  NAMED beside the population with its count, never folded into it -- it is a weaker
           form of the same anchoring and a reader deciding what to cure next needs both numbers.

THE FIELD VOCABULARY IS DERIVED FROM THE PRINTER, NEVER HAND-WRITTEN: this tool reads the f-string fields of
corpus_suite_harness.py's own SUITE_BOARD assembly, so a field added there is a field here on the next run, and
REFUSES rc=2 when it cannot find that printer -- a census whose vocabulary no longer describes the tree reports
zeros that mean nothing.  Per-mode fields are matched by SUFFIX (`_pass`, `_fail`, `_n`, ...) so a regex that
builds the name with a backreference -- `(m[34])_pass=(\\d+) \\1_fail=` -- is still read as two board fields.

rc: 0 no ADJACENT matcher remains; 1 at least one does; 2 the vocabulary could not be derived.
Usage: python3 ../harness/scripts/util_board_field_matcher_census.py [--root DIR] [--selftest] [--verbose]
"""
import argparse, os, re, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "SCRIP"))

# the literal is a PATTERN when one of these introduces it on the same line
# ⛔ THE CONTEXT MUST BE THE LITERAL'S OWN, NOT ANYWHERE EARLIER ON THE LINE: a first pass let `grep ... &&`
# reach across the && into a `ck ok "..."` LABEL and report the label as a matcher.  So no clause here may cross
# a shell operator (| ; & ( )) -- the verb has to be the one that takes THIS literal.
MATCHER_CTX = re.compile(
    r"(?:\bgrep\b[^|;&()]*|\begrep\b[^|;&()]*|\bre\.(?:compile|search|match|fullmatch|findall|finditer|sub|split)\s*\(|"
    r"=~\s*|\bcase\b[^)]*\bin\b)\s*$")
# the literal is EMITTED when one of these does
PRINTER_CTX = re.compile(r"(?:\becho\b[^|;&()]*|\bprintf\b[^|;&()]*|\bprint\s*\(|\bck\s+(?:ok|no)\s+|\bout\s*\(|\brefuse\s+|\bred\s+)\s*$")

LIT_RX = re.compile(r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\"|r\"(?:[^\"\\]|\\.)*\"|r'(?:[^'\\]|\\.)*'")


def derive_vocabulary(root, out=print):
    """the board's field NAMES and per-mode SUFFIXES, read out of the harness's own SUITE_BOARD printer"""
    h = os.path.join(root, "..", "harness", "scripts", "corpus_suite_harness.py")
    if not os.path.exists(h):
        out(f"CENSUS board-matchers REFUSED(2): no corpus_suite_harness.py at {h} -- the field vocabulary has no source")
        return None, None
    src = open(h, encoding="utf-8", errors="replace").read()
    i = src.find('print("SUITE_BOARD ')
    if i < 0:
        out("CENSUS board-matchers REFUSED(2): corpus_suite_harness.py prints no SUITE_BOARD line -- the printer this "
            "vocabulary is derived from has been renamed or removed, and a hand list is exactly what this tool refuses to be")
        return None, None
    # the assembly is the `fields = [...]` / `fields.append(...)` region above the print
    region = src[max(0, i - 4000):i]
    names, suffixes = set(), set()
    for m in re.finditer(r'([A-Za-z_][A-Za-z0-9_]*)=\{', region):
        names.add(m.group(1))
    for m in re.finditer(r'\{m\}(_[A-Za-z0-9_]*)=\{', region):
        suffixes.add(m.group(1))
    names.discard("m")
    if not names:
        out("CENSUS board-matchers REFUSED(2): the SUITE_BOARD assembly yielded no field names")
        return None, None
    return names, suffixes


def is_board_field(name, names, suffixes):
    if name in names:
        return True
    for s in suffixes:
        if name.endswith(s):
            return True
    return False


# A FIELD TOKEN IS FOUND FROM ITS '=' BACKWARD, never by a forward character class: a class permissive enough to
# admit a regex-built name (`(m[34])_pass`, `\1_fail`) is also permissive enough to swallow `.*` and read two
# fields either side of a wildcard as ONE token -- which classified an ORDERED matcher as ADJACENT, the census
# making the very error it exists to find.
_NAME_CHARS = re.compile(r"[A-Za-z0-9_]")
_GROUP_END = re.compile(r"(?:\([^()]*\)|\[[^\]]*\]|\\\d)$")


def _field_tokens(body):
    """[(start, end_of_'='), name] for every NAME= in the pattern, the name read leftward from its '='"""
    toks = []
    for i, ch in enumerate(body):
        if ch != "=" or (i + 1 < len(body) and body[i + 1] == "="):
            continue
        j = i
        while j > 0 and _NAME_CHARS.match(body[j - 1]):
            j -= 1
        g = _GROUP_END.search(body[:j])
        if g:
            j = g.start()
        name = body[j:i]
        if name:
            toks.append((j, i + 1, name))
    return toks


def classify(body, names, suffixes):
    """(n_fields, 'ADJACENT'|'ORDERED'|'SINGLE'|'NONE') for one pattern body"""
    body = body.replace("\\b", "")   # a zero-width anchor is not a separator and must not become part of a field name
    toks = []
    for start, end, name in _field_tokens(body):
        bare = re.sub(r"\\\d|\(|\)|\[[^\]]*\]|\\", "", name)
        if is_board_field(bare, names, suffixes):
            toks.append((start, end))
    if len(toks) < 2:
        return len(toks), ("SINGLE" if toks else "NONE")
    WILD = r"\.\*|\.\+|\\S\*|\[\^|\*\?|\.\{"
    verdict = None
    for (_a, ae), (bs, _be) in zip(toks, toks[1:]):
        gap = body[ae:bs]
        wild = re.search(WILD, gap)
        # ⛔ A PAIR ONLY COUNTS WHEN THE GAP COULD SPAN A BOARD FIELD'S VALUE AND ITS SEPARATOR.  The board always
        # writes `name=value name=value`, so a gap with neither whitespace nor a wildcard -- `shipped=/outside=`
        # inside a sentence -- is two `=` in prose, not two board fields in sequence.  Counting those put a ck
        # LABEL in the population, which is the census making the same unanchored-match error it exists to find.
        if not wild and not re.search(r"\s|\\s|\\t", gap):
            continue
        if not wild:
            return len(toks), "ADJACENT"
        verdict = "ORDERED"
    return (len(toks), verdict) if verdict else (len(toks), "NONE")


def scan_file(path, names, suffixes):
    rows = []
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        return rows
    for n, line in enumerate(lines, 1):
        for m in LIT_RX.finditer(line):
            lit = m.group(0)
            body = lit[2:-1] if lit[:2] in ('r"', "r'") else lit[1:-1]
            cnt, kind = classify(body, names, suffixes)
            if kind in ("NONE", "SINGLE"):
                continue
            head = line[:m.start()]
            if MATCHER_CTX.search(head):
                role = "MATCHER"
            elif PRINTER_CTX.search(head):
                role = "PRINTER"
            else:
                role = "FIXTURE"
            rows.append((path, n, role, kind, cnt, body[:120]))
    return rows


def census(root, verbose=False, out=print):
    names, suffixes = derive_vocabulary(root, out)
    if names is None:
        return 2
    out(f"CENSUS board-matchers VOCABULARY derived from ../harness/scripts/corpus_suite_harness.py's own SUITE_BOARD printer: "
        f"{len(names)} field name(s), {len(suffixes)} per-mode suffix(es) -- never a hand list, and a printer that "
        f"is renamed REFUSES rc=2 rather than report zeros")
    rows = []
    sd = os.path.join(root, "..", "harness", "scripts")
    for d, _s, fs in os.walk(sd):
        for f in sorted(fs):
            if f.endswith((".sh", ".py")) and f != os.path.basename(__file__):
                rows += scan_file(os.path.join(d, f), names, suffixes)
    matchers = [r for r in rows if r[2] == "MATCHER"]
    adj = [r for r in matchers if r[3] == "ADJACENT"]
    ordered = [r for r in matchers if r[3] == "ORDERED"]
    others = [r for r in rows if r[2] != "MATCHER"]
    out(f"CENSUS board-matchers literals_with_2+_board_fields={len(rows)} MATCHER={len(matchers)} "
        f"(PRINTER/FIXTURE={len(others)}, NAMED and excluded: a runner printing its own board line is the board's "
        f"author, not its reader)")
    out(f"CENSUS board-matchers ADJACENT={len(adj)} want=0 -- ORDERED={len(ordered)} NAMED beside it, never folded in "
        f"(a weaker form of the same anchoring: survives an insertion, breaks on a reorder)")
    for p, n, _role, kind, cnt, body in adj:
        out(f"  ADJACENT-MATCHER {os.path.relpath(p, root)}:{n} ({cnt} fields) {body}")
    for p, n, _role, kind, cnt, body in ordered:
        out(f"  ORDERED-MATCHER {os.path.relpath(p, root)}:{n} ({cnt} fields) {body}")
    if verbose:
        for p, n, role, kind, cnt, body in others:
            out(f"  {role}-{kind} {os.path.relpath(p, root)}:{n} ({cnt} fields) {body}")
    out(f"CENSUS board-matchers {'GREEN' if not adj else 'RED'}")
    return 0 if not adj else 1


ARMS_FLOOR = 10


def selftest():
    fails = arms = 0
    def ck(ok, label):
        nonlocal fails, arms
        arms += 1
        print(("  ok    " if ok else "  FAIL  ") + label)
        if not ok:
            fails += 1
    names, suffixes = derive_vocabulary(ROOT)
    ck(names is not None and "total" in names and "shipped" in names and "outside" in names,
       "vocabulary: total, shipped and outside are DERIVED from the harness's printer, not typed here")
    ck(suffixes is not None and "_pass" in suffixes and "_n" in suffixes,
       "vocabulary: the per-mode suffixes _n and _pass come from the same printer")
    ck(classify("^SUITE_BOARD family=ALL total=2 m3_n=2 ", names, suffixes)[1] == "ADJACENT",
       "classify: the exact arm-9 pattern that shipped= broke reads ADJACENT")
    ck(classify(r"SUITE_BOARD family=\S+ total=(\d+)(.*)$", names, suffixes)[1] == "ADJACENT",
       "classify: util_build_score_md's family-then-total regex reads ADJACENT -- it survives today only because nothing was inserted THERE yet")
    ck(classify(r"(m[34])_pass=(\d+) \1_fail=(\d+)", names, suffixes)[1] == "ADJACENT",
       "classify: a regex that BUILDS the field name with a backreference is still two board fields, and adjacent")
    ck(classify(r"^SUITE_BOARD .*\btotal=(\d+)\b.*\bm3_n=(\d+)\b", names, suffixes)[1] == "ORDERED",
       "classify: wildcards between the fields read ORDERED -- survives an insertion, still breaks on a reorder")
    ck(classify("^SUITE_BOARD ", names, suffixes)[1] == "NONE",
       "classify: a presence-only matcher names no field and is not in either population")
    ck(classify("total=2", names, suffixes)[1] == "SINGLE",
       "classify: one field is identity already -- nothing to anchor against")
    w = tempfile.mkdtemp(prefix="board_matcher_census."); __import__("atexit").register(__import__("shutil").rmtree, w, True)
    f1 = os.path.join(w, "t.sh")
    open(f1, "w").write("echo \"SUITE_BOARD total=2 m3_n=2\"\n"
                        "grep -q '^SUITE_BOARD total=2 m3_n=2 ' <<<\"$out\"\n")
    rows = scan_file(f1, names, suffixes)
    roles = sorted((r[2], r[3]) for r in rows)
    ck(roles == [("MATCHER", "ADJACENT"), ("PRINTER", "ADJACENT")],
       "role: the SAME text is a PRINTER after echo and a MATCHER after grep -- only the matcher can go stale")
    f2 = os.path.join(w, "t2.py")
    open(f2, "w").write('B = "SUITE_BOARD family=ALL total=9 m3_n=9"\nopen(p,"w").write(B)\n')
    rows2 = scan_file(f2, names, suffixes)
    ck([r[2] for r in rows2] == ["FIXTURE"],
       "role: a board line ASSIGNED to a variable is FIXTURE text a matcher reads, not a matcher")
    print(f"population: {arms} selftest arm(s), {fails} FAIL")
    if arms < ARMS_FLOOR:
        print(f"SELFTEST REFUSED(2): {arms} arm(s) ran, below the recorded floor {ARMS_FLOOR}")
        return 2
    print("SELFTEST PASS" if fails == 0 else "SELFTEST FAIL")
    return 0 if fails == 0 else 1


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=ROOT)
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--verbose", action="store_true", help="also name every PRINTER and FIXTURE literal")
    a = ap.parse_args(argv)
    if a.selftest:
        return selftest()
    return census(a.root, a.verbose)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
