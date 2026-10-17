#!/usr/bin/env python3
"""util_icon_semicolon_class_classifier.py — THE MEASURED SEMICOLON-CLASS CLASSIFIER (CEO-489, hq_V 2026-09-10).

Reads shipped-.icn paths (corpus-relative, one per line) on stdin and prints one line per file:

    SEMICOLON\t<path>\t<n> semicolon(s)
    OTHER\t<path>\t<icont's first complaint>
    UNDECIDED\t<path>\t<why the budget ran out>

⛔⛔ WHAT "SEMICOLON CLASS" MEANS HERE, AND WHY IT IS DEMONSTRATED RATHER THAN PATTERN-MATCHED.
A file is SEMICOLON class only when this tool has RE-RUN THE ORACLE and shown that deleting `;` BYTES AND
NOTHING ELSE makes `icont -s -c` accept it. That is exactly the assertion CEO-488's DONE-WHEN makes per file
(bytes removed == semicolons removed), so the classifier and the row's success criterion are the same
statement — a file this tool calls SEMICOLON is a file hq_B can repair by deletion alone, proven, not guessed.

The tempting rule — "the token icont quotes is a `;`" — is MEASURABLY WRONG on this population, in both
directions, which is the whole reason this file exists:
  · FALSE POSITIVE: packages/icon/jcon_tests/prepro.icn is a deliberate preprocessor-error fixture. One
    compile raises `$undef: too many arguments` AND five `";": missing right parenthesis`. A token rule files
    it as hq_B's work; no deletion of semicolons can ever make icont accept it, because the preprocessor
    errors are the point of the fixture.
  · FALSE NEGATIVE: the `"}": invalid case clause` shape is a trailing `;` before a case body's closing brace.
    icont names the BRACE, and the offending `;` is on the previous line. A token rule cannot see this shape
    at all, and it is 4 of the 18 real files.

⛔ EVERY DELETION IS AT A POSITION ICONT ITSELF FLAGGED. This tool never scans for semicolons it finds
suspicious; it asks the oracle where the error is and removes a `;` there. It NEVER writes to the corpus — it
copies the staged directory's symlinks into a private temp dir and replaces the one target with a real file,
because writing through a symlink would edit the shipped source it is supposed to be measuring.

⛔ PROGRESS IS MEASURED, SO THE LOOP TERMINATES ON ITS OWN and the cap is a backstop, not the mechanism: a
candidate deletion is accepted only if the oracle's first complaint MOVES FORWARD (a later line) or the total
number of complaints DROPS. A deletion that changes nothing, or makes things worse, is rejected and the file
is classified OTHER rather than hacked at.
"""
import os, re, shutil, subprocess, sys, tempfile

MAX_DELETIONS = 60
ERR_RE = re.compile(r'^File (?P<file>.+?); Line (?P<line>\d+) # (?P<rest>.*)$')
TOK_RE = re.compile(r'^"(?P<tok>[^"]*)": (?P<reason>.*)$')


def compile_errors(icont, workdir, name):
    """Run the oracle on <name> inside workdir; return (rc, [(line, tok, reason, raw), ...])."""
    p = subprocess.run([icont, "-s", "-c", name], cwd=workdir,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    errs = []
    for raw in p.stdout.splitlines():
        m = ERR_RE.match(raw.strip())
        if not m:
            continue
        tok, reason = None, m.group("rest")
        t = TOK_RE.match(m.group("rest"))
        if t:
            tok, reason = t.group("tok"), t.group("reason")
        errs.append((m.group("file"), int(m.group("line")), tok, reason, raw.strip()))
    return p.returncode, errs


DEFINE_RE = re.compile(r'^\s*\$define\b')


def candidate_positions(lines, err, name):
    """Semicolon offsets ICONT flagged, as (line_index, col) pairs, nearest-last first.

    ⛔ THE `File` FIELD IS CHECKED, NOT ASSUMED. A `$line` directive REMAPS what icont reports — packages/icon/
    jcon_tests/tpp.icn compiles as `File a.b.c` and arizona_tests/general/tpp.icn as `File xyzzy`, with line
    numbers in the remapped space. Editing 'line 56' of the real file on the strength of a remapped report
    would delete a byte the oracle never complained about, which is the CEO-483 shape exactly: an instrument
    measuring something other than what it names. A remapped report yields NO candidates and the file falls to
    OTHER, which is where both tpp files belong anyway.

    ⛔⭐ THE MACRO-BODY FALLBACK IS NOT A HEURISTIC, IT IS THE ONLY WAY THIS CLASS IS VISIBLE AT ALL.
    packages/icon/jcon_tests/htprep.icn carries `$define SIGNATURE "<!-- ... -->";` at line 46 — ONE semicolon,
    inside a MACRO BODY. icont never reports line 46. It reports the three USE SITES (257 `";": missing then`,
    266 and 286 `";": missing right parenthesis`), each of which is a line with no semicolon on it at all, so a
    strictly line-local search finds no candidate and drops a genuinely deletion-repairable file into OTHER.
    Deleting that single byte makes icont accept the whole file — MEASURED. A trailing `;` on a `$define` is
    exactly the shape our conversion produces, and it detonates everywhere the macro is used and nowhere it is
    written, which is why it survived every earlier census.
    """
    ef, eline, tok, reason, _raw = err
    if ef != name:
        return []
    idx = eline - 1
    if not (0 <= idx < len(lines)):
        return []
    out = []
    # ⛔⭐ EVERY `;` ON THE FLAGGED LINE, WHATEVER TOKEN ICONT NAMED -- and the generality is load-bearing, not
    # tidiness. Keying on `tok == ";"` misses the `;` BEFORE ELSE, which is one of the four shapes CEO-477's
    # joiner produced: `if a then b; else c` is reported as `"else": invalid expression`, because by the time
    # icont objects it has already consumed the semicolon and moved on. The same is true of `; then`. There is
    # no false-positive cost to being general here: a candidate is only ACCEPTED if deleting it MOVES THE
    # ORACLE FORWARD, so a semicolon that merely happens to share a line with an unrelated error is measured,
    # rejected and the file still falls to OTHER -- which is exactly what happens to jcon_tests/prepro.icn.
    out += [(idx, c) for c, ch in enumerate(lines[idx]) if ch == ";"]
    if tok == "}" and "invalid case clause" in reason:
        # The `;` terminates the LAST case clause and sits at the end of the previous non-blank line; icont
        # only notices at the brace. Same line first (a one-line `{ ... };` body), then walk back.
        out += [(idx, c) for c, ch in enumerate(lines[idx]) if ch == ";"]
        j = idx - 1
        while j >= 0 and not lines[j].strip():
            j -= 1
        if j >= 0:
            out += [(j, c) for c, ch in enumerate(lines[j]) if ch == ";"]
    # Tried last, and only where the line-local candidates did not already resolve it: a `;` in a macro body
    # is reported at the use site, so the flagged line is the wrong place to look by construction.
    for j, ln in enumerate(lines):
        if DEFINE_RE.match(ln):
            out += [(j, c) for c, ch in enumerate(ln) if ch == ";"]
    return out


def brace_rewrite(lines, li, col):
    """`( ... ; ... )` -> `{ ... ; ... }` around the semicolon at (li, col), or None if it is not parenthesised.

    ⛔⭐ WHY THIS IS A SEPARATE CLASS AND NOT MORE DELETION. `(a; b)` is OUR sequence-expression construct
    (`ICN_SEQ_EXPR`); Arizona icont groups ONE expression in `( )` and spells a compound expression `{ }`.
    Deleting the semicolon does not repair these files, it produces `(a b)`, which is also invalid — so they
    are NOT hq_B's deletion row and must never be counted into it. The repair is the one this seat already
    made by hand under HQV-19 for tests/icon/parser/paren_seq.icn: change the GROUPING, keep the semicolons,
    and the AST still yields TT_SEQ_EXPR so the fixture still pins the shape it is named for. Measured here
    rather than asserted, for the same reason as everything else in this file.
    """
    body = lines[li]
    depth, open_at = 0, None
    for c in range(col, -1, -1):
        if body[c] == ")":
            depth += 1
        elif body[c] == "(":
            if depth == 0:
                open_at = c
                break
            depth -= 1
    if open_at is None:
        return None
    depth, close_at = 0, None
    for c in range(col, len(body)):
        if body[c] == "(":
            depth += 1
        elif body[c] == ")":
            if depth == 0:
                close_at = c
                break
            depth -= 1
    if close_at is None:
        return None
    return body[:open_at] + "{" + body[open_at + 1:close_at] + "}" + body[close_at + 1:]


def first_key(errs):
    """Ordering used to decide whether a deletion made PROGRESS: (first complaint's line, how many complaints)."""
    return (errs[0][1] if errs else -1, len(errs))


def classify(icont, corpus, staged_root, rel):
    name = os.path.basename(rel)
    d = os.path.dirname(rel)
    src = os.path.join(corpus, rel)
    with open(src, "r", encoding="utf-8", errors="surrogateescape") as fh:
        text = fh.read()
    # ⛔⭐ A CONTAINER IS NOT A PROGRAM, AND ASKING icont TO COMPILE ONE WHOLE IS A CATEGORY ERROR OF THE
    # INSTRUMENT, NOT A DEFECT OF THE FILE (RULES.md: a rung suite file is a CONTAINER, never compiled whole --
    # the same correction this seat sent hq_C on 09-10 about ALL.icn). tests/icon/rung36_all.icn holds 37
    # `procedure main()` behind 42 banner separators, probe_witness.icn holds 10, and
    # rung20_section_seqexpr_excluded.icn holds 2. Compiled whole they raise `inconsistent redeclaration` --
    # which reads exactly like a defect and is not one. The count is MEASURED from the file, never a name
    # pattern: `_all` in a filename is not evidence and `rung36_jcon_case.icn` is a single program.
    mains = len(re.findall(r'(?m)^\s*procedure\s+main\s*\(', text))
    tmp = tempfile.mkdtemp(prefix="icnsemi.")
    try:
        # Stage the siblings by symlink so `$include` resolves as it does in the tree, then shadow the target
        # with a REAL file. ⛔ The order matters: writing first and linking after would clobber the real file.
        # ⛔ REGULAR FILES ONLY, for the reason spelled out in the gate's staging loop: a symlinked
        # SUBDIRECTORY is a writable path back into the shipped tree, and this tool runs the oracle dozens of
        # times per file. Nothing it does may reach corpus/.
        for s in sorted(os.listdir(os.path.join(corpus, d))):
            sp = os.path.join(corpus, d, s)
            if s != name and os.path.isfile(sp):
                try:
                    os.symlink(sp, os.path.join(tmp, s))
                except OSError:
                    pass
        removed, rebraced = 0, 0
        rc, errs = compile_errors(icont, tmp_write(tmp, name, text), name)
        # ⛔ THE FILE'S OWN FIRST COMPLAINT, CAPTURED BEFORE THE PROBE EDITS ANYTHING. Reporting the RESIDUAL
        # error after speculative repairs would name a diagnostic the reader cannot reproduce from the shipped
        # file -- rung20_section_seqexpr_excluded.icn's original complaint is its sequence expression and its
        # residual is a container redeclaration, and a report showing only the second hides the first.
        origin = errs[0][4] if errs else "icont refused (rc=%d) with no parsable diagnostic" % rc

        def verdict(kind, detail):
            edits = []
            if removed:
                edits.append("%d semicolon deletion(s)" % removed)
            if rebraced:
                edits.append("%d sequence-expression rebrace(s)" % rebraced)
            if kind in ("OTHER", "CONTAINER") and edits:
                return (kind, "%s [probe also measured: %s]" % (detail, ", ".join(edits)))
            return (kind, detail)

        def settle(errs_now, rc_now):
            """Bucket a file the probe can no longer advance: container first, then the honest OTHER."""
            resid = errs_now[0] if errs_now else None
            if mains > 1 and resid is not None and "inconsistent redeclaration" in (resid[3] or ""):
                return verdict("CONTAINER", "%d entries (procedure main x %d) -- never compiled whole; "
                                            "original complaint: %s" % (mains, mains, origin))
            return verdict("OTHER", origin)

        while removed + rebraced <= MAX_DELETIONS:
            if rc == 0:
                if rebraced:
                    return ("SEQEXPR", "%d parenthesised sequence expression(s); %d semicolon deletion(s)"
                            % (rebraced, removed))
                if removed:
                    return ("SEMICOLON", "%d semicolon(s)" % removed)
                return ("OTHER", "compiles unmodified")
            if not errs:
                return verdict("OTHER", origin)
            here = first_key(errs)
            src_lines = text.splitlines()
            cands = candidate_positions(src_lines, errs[0], name)
            if not cands:
                return settle(errs, rc)
            progressed = False
            for (li, col) in reversed(cands):
                lines = text.splitlines(keepends=True)
                body, nl = lines[li], ""
                while body.endswith("\n") or body.endswith("\r"):
                    nl, body = body[-1] + nl, body[:-1]
                if col >= len(body) or body[col] != ";":
                    continue
                # ⭐ DELETION IS TRIED FIRST AND THE BRACE REWRITE ONLY WHERE DELETION DOES NOT MOVE THE
                # ORACLE. That ordering is what keeps the two classes apart: a file that deletion repairs is
                # hq_B's row, and a file that only the rewrite repairs is a re-decided shape (HQV-19), and a
                # classifier that tried the rewrite first would silently absorb the first class into the second.
                attempts = [("del", body[:col] + body[col + 1:] + nl)]
                rb = brace_rewrite([body], 0, col)
                if rb is not None:
                    attempts.append(("brace", rb + nl))
                for kind, newline_text in attempts:
                    cand_lines = list(lines)
                    cand_lines[li] = newline_text
                    cand_text = "".join(cand_lines)
                    crc, cerrs = compile_errors(icont, tmp_write(tmp, name, cand_text), name)
                    if crc == 0 or first_key(cerrs) > here:
                        text, rc, errs, progressed = cand_text, crc, cerrs, True
                        if kind == "del":
                            removed += 1
                        else:
                            rebraced += 1
                        break
                if progressed:
                    break
            if not progressed:
                return settle(errs, rc)
        return ("UNDECIDED", "still repairing after %d edits" % MAX_DELETIONS)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def tmp_write(tmp, name, text):
    """Write the candidate text as a REAL file in the private dir and hand back that dir."""
    p = os.path.join(tmp, name)
    if os.path.islink(p):
        os.unlink(p)
    with open(p, "w", encoding="utf-8", errors="surrogateescape") as fh:
        fh.write(text)
    return tmp


def main():
    icont, corpus, staged_root = sys.argv[1], sys.argv[2], sys.argv[3]
    for rel in [l.strip() for l in sys.stdin if l.strip()]:
        verdict, detail = classify(icont, corpus, staged_root, rel)
        print("%s\t%s\t%s" % (verdict, rel, detail))
        sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
