#!/usr/bin/env python3
"""util_finding_fold_before_delete.py -- FOLD A FINDING'S MEASURED CLAIMS INTO ITS LIVE CITERS BEFORE IT IS DELETED.

WHY THIS EXISTS (RULES.md line 31, Lon 2026-09-18 in-chat to the cto, verbatim: "You can use as many FINDING files as
you want. I'll just delete them periodically. We should probably do a summarization when I delete."; ceo CEO-859/861).
A measurement that lives only in a FINDING is a measurement with a deletion date: 2231 FINDING paths have already been
deleted from .github and two live rows were blocked on them this week.

THE QUESTION THE cto PUT IN THE BATON'S ## QA AND THIS TOOL'S ANSWER: automatic prose extraction is unreliable on a
file whose value is an argument rather than a table, and a script that PARAPHRASES a measurement has manufactured a
claim.  So this tool NEVER paraphrases.  It copies CLAIM LINES VERBATIM, and the INVARIANT the gate enforces is not
"the tool wrote the fold" but "the fold block contains lines that are verbatim in the FINDING" -- which a hand-written
seat summary satisfies just as well, and an empty marker or a paraphrase does not.  Automation is the default offer;
the verbatim-subset test is the law.

THE CLAIM-LINE RULE, PRINTED RATHER THAN IMPLIED (a reader must be able to predict what this copies):
  a CLAIM LINE is a line of the FINDING that contains at least one DIGIT, is at least MIN_CLAIM_CHARS characters long
  after markdown decoration is stripped, is not a heading, not a table rule, and not the file's own title line.
A FINDING with ZERO claim lines cannot be folded automatically and --apply REFUSES rc=2 rather than writing an empty
fold block, because an empty fold that satisfies a marker check is this instrument's own vacuous-green disease.

THE MARKER IS TERMINATED AND THE WINDOW IS NEVER GENEROUS -- this is CEO-860's lesson applied before it bites again:
a root digest and a GOAL cursor write ONE PARAGRAPH PER LINE, so any line-count window degrades into a five-thousand
character window that exempts whatever happens to be nearby.  The fold block is delimited by an explicit END marker
and is located by CHARACTER OFFSET, not by lines; an UNTERMINATED block is RED, never "close enough".

REFUSES rc=2 RATHER THAN PASSING VACUOUSLY: an unreadable tree, a tree with no FINDING files indexed, or a citation
scan that read zero files.  A zero from a tool that read nothing is not a zero.
"""
import argparse, os, re, subprocess, sys

MIN_CLAIM_CHARS = 24          # a claim line is a measurement, not "see 2 below"
MIN_FOLDED_CLAIMS = 3         # or every claim line when the FINDING has fewer
NAME_RE = re.compile(r'FINDING-[0-9A-Za-z][0-9A-Za-z._\-]*')
HEADING_RE = re.compile(r'^\s*#')
TABLE_RULE_RE = re.compile(r'^[\s|:\-+]*$')
DECOR_RE = re.compile(r'[*_`>#]')

def die(msg, code=2):
    print("⛔ REFUSED-TO-GRADE(%d): %s" % (code, msg)); sys.exit(code)

def git(repo, *args):
    try:
        out = subprocess.run(["git", "-C", repo] + list(args), capture_output=True, text=True)
    except OSError as e:                       # never swallowed into a wrong diagnosis
        die("could not execute git in %s: %s" % (repo, e))
    if out.returncode != 0:
        return None
    return out.stdout

def norm_name(s):
    """Normalise a FINDING name as it was FOUND IN PROSE, not as a filesystem path.

    ⛔ The name regex has to admit '.' (every name carries '2026-09-18'), so a sentence that ENDS on a FINDING name
    hands back 'NAME.md.' or 'NAME...' with the punctuation glued on, and a prefix test against it silently fails --
    which is how a real citation becomes a non-citation and a delete gets waved through.  Strip trailing punctuation,
    then '.md', then trailing punctuation again."""
    s = s.rstrip(".,;:-_")
    if s.endswith(".md"):
        s = s[:-3]
    return s.rstrip(".,;:-_")

# ---- CLAIM LINES ------------------------------------------------------------------------------------------------
def claim_lines(text):
    seen, out = set(), []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or HEADING_RE.match(line) or TABLE_RULE_RE.match(line):
            continue
        if not any(c.isdigit() for c in line):
            continue
        if len(DECOR_RE.sub("", line).strip()) < MIN_CLAIM_CHARS:
            continue
        if line not in seen:
            seen.add(line); out.append(line)
    return out

# ---- THE FOLD BLOCK ---------------------------------------------------------------------------------------------
def fold_blocks(text, name):
    """Every terminated fold block for `name`, plus every unterminated start. Located by character offset."""
    blocks, unterminated = [], 0
    start_pat = re.compile(r'FOLDED-FROM:\s*' + re.escape(name) + r'\b')
    end_pat = re.compile(r'END-FOLDED-FROM:\s*' + re.escape(name) + r'\b')
    pos = 0
    while True:
        m = start_pat.search(text, pos)
        if not m:
            break
        e = end_pat.search(text, m.end())
        if not e:
            unterminated += 1; pos = m.end(); continue
        blocks.append(text[m.end():e.start()])
        pos = e.end()
    return blocks, unterminated

def fold_state(citer_text, name, claims):
    blocks, unterminated = fold_blocks(citer_text, name)
    if not blocks:
        return ("UNTERMINATED" if unterminated else "UNFOLDED"), 0
    body = "\n".join(blocks)
    hits = sum(1 for c in claims if c in body)
    need = min(MIN_FOLDED_CLAIMS, len(claims)) if claims else 0
    if need == 0:
        return "VACUOUS-SOURCE", 0                       # nothing measurable to fold: a marker proves nothing
    return ("FOLDED" if hits >= need else "THIN"), hits

# ---- THE CITATION INDEX -----------------------------------------------------------------------------------------
def scan_files(gh, scrip, tasks, self_paths):
    files = []
    ls = git(gh, "ls-files")
    if ls is None:
        die("git ls-files failed in %s (not a checkout?)" % gh)
    for rel in ls.splitlines():
        if rel.startswith("findings/"):          # a FINDING is not a durable home for another FINDING's claims
            continue
        files.append(os.path.join(gh, rel))
    if scrip and os.path.isdir(scrip):
        ls = git(scrip, "ls-files")
        if ls is None:
            die("git ls-files failed in %s" % scrip)
        for rel in ls.splitlines():
            if rel.endswith((".sh", ".py", ".md", ".tsv", ".txt")):
                files.append(os.path.join(scrip, rel))
    if tasks and os.path.isdir(tasks):
        for fn in sorted(os.listdir(tasks)):
            if fn.endswith(".md") or fn.endswith(".tsv"):
                files.append(os.path.join(tasks, fn))
    return [f for f in files if os.path.realpath(f) not in self_paths]

MIN_PARTIAL_CHARS = 40    # long enough that the shared "FINDING-YYYY-MM-DD-seat-" stem can never match on its own

def is_same_citation(found, target):
    """Does `found` -- a FINDING name as it appears in some live file -- refer to `target`?

    ⛔ THIS EXISTS BECAUSE THE EXACT-NAME READER WAS WRONG AND I MEASURED IT BEFORE SHIPPING IT: of 724 cited names
    that match no live and no deleted path, 358 are a PROPER PREFIX of a real deleted FINDING -- a prose mention cut
    off by a line wrap or an ellipsis -- and a further population is the name with a trailing '.md.' from a sentence
    that ended on it.  An exact-match index calls every one of those files a non-citer, and a non-citer does not block
    a delete: the reader's failure mode is a SILENT ALLOW, which is the worst direction for this particular tool.
    A truncated citation is a citation.  The 40-character floor is what stops the shared date-and-seat stem (a prefix
    every FINDING in the tree shares) from matching everything against everything."""
    if found.startswith(target):          # 'NAME.md.' and 'NAME,' -- the regex kept the trailing punctuation
        return True
    return len(found) >= MIN_PARTIAL_CHARS and target.startswith(found)

def build_index(files):
    """name -> {path: text}. One regex pass per file, so 2 live names and 2231 dead ones cost the same."""
    index, read = {}, 0
    for path in files:
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError:
            continue
        read += 1
        for m in set(NAME_RE.findall(text)):
            index.setdefault(norm_name(m), {})[path] = text
    return index, read

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tree", default=None, help=".github checkout to grade (default: the sibling of this script's repo)")
    ap.add_argument("--scrip", default=None)
    ap.add_argument("--tasks", default="/home/resources/postoffice/tasks")
    ap.add_argument("--apply", action="store_true", help="write the fold block into every unfolded live citer")
    ap.add_argument("--delete", action="store_true", help="delete each named FINDING, REFUSING rc=2 on a cited-and-unfolded one")
    ap.add_argument("--deleted-since", default=None, help="grade FINDINGs deleted between this rev and HEAD, recovering each from history")
    ap.add_argument("names", nargs="*", help="FINDING names or paths (default: every tracked FINDING)")
    a = ap.parse_args()

    here = os.path.dirname(os.path.abspath(__file__))
    # ⛔ THE SCRIP TREE IS THIS SCRIPT'S OWN REPO, .github S4E_HOME's ELSE THE SIBLING OF THIS CHECKOUT (coo 2026-10-08, CEO-1573):
    # root/SCRIP and root/.github named the directories BESIDE a worktree, so from a worktree under a scratch directory the sweep
    # refused "no such tree" and the gate's arm 9 read that refusal as a deleted, still-cited FINDING.
    root = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(here, "..", "..", "SCRIP", ".."))
    gh = os.path.abspath(a.tree) if a.tree else os.path.join(root, ".github")
    scrip = os.path.abspath(a.scrip) if a.scrip else os.path.abspath(os.path.join(here, "..", "..", "SCRIP"))
    if not os.path.isdir(gh):
        die("no such tree: %s" % gh)
    self_paths = {os.path.realpath(os.path.join(here, n)) for n in
                  ("util_finding_fold_before_delete.py", "util_finding_fold_before_delete.sh",
                   "test_gate_finding_claims_are_folded_before_delete.sh")}

    # ---- the population ------------------------------------------------------------------------------------
    targets = []   # (name, path_or_None, text)
    if a.deleted_since:
        base = a.deleted_since
        names = git(gh, "diff", "--diff-filter=D", "--name-only", "%s..HEAD" % base)
        if names is None:
            die("could not diff %s..HEAD in %s" % (base, gh))
        wt = git(gh, "diff", "--diff-filter=D", "--name-only", "HEAD") or ""
        dels = [p for p in (names + wt).splitlines() if re.search(r'FINDING-[^/]*\.md$', p)]
        for p in sorted(set(dels)):
            src = git(gh, "show", "%s:%s" % (base, p)) or git(gh, "show", "HEAD:%s" % p)
            if src is None:
                die("a FINDING was deleted but is not recoverable from %s or HEAD: %s" % (base, p))
            targets.append((norm_name(os.path.basename(p)), p, src))
        print("DELETIONS EXAMINED: %d FINDING path(s) deleted in %s..HEAD plus the working tree" % (len(targets), base))
    else:
        ls = git(gh, "ls-files")
        if ls is None:
            die("git ls-files failed in %s" % gh)
        tracked = [p for p in ls.splitlines() if re.search(r'FINDING-[^/]*\.md$', p)]
        wanted = {norm_name(os.path.basename(n)) for n in a.names} if a.names else None
        for p in tracked:
            nm = norm_name(os.path.basename(p))
            if wanted and nm not in wanted:
                continue
            fp = os.path.join(gh, p)
            with open(fp, "r", encoding="utf-8", errors="replace") as fh:
                targets.append((nm, p, fh.read()))
        if not targets and not a.names:
            die("indexed ZERO FINDING files under %s -- a zero from a tool that read nothing is not a zero "
                "(RULES.md INSTRUMENT LAWS; if the tree really holds none, there is nothing for this tool to grade)" % gh)
        if a.names and not targets:
            die("named FINDING(s) not tracked under %s: %s" % (gh, ", ".join(a.names)))

    # ---- the citation index --------------------------------------------------------------------------------
    files = scan_files(gh, scrip, a.tasks, self_paths)
    index, read = build_index(files)
    if read == 0:
        die("the citation scan read ZERO files -- the index is empty for a reason that is not the tree's")
    print("POPULATION: %d FINDING(s) graded; citation index built from %d live file(s) "
          "(.github tracked minus findings/, harness/scripts+docs, %s)" % (len(targets), read, a.tasks))
    print("RULE: a CLAIM LINE carries a digit, >=%d chars undecorated, not a heading; a citer is FOLDED when a "
          "TERMINATED 'FOLDED-FROM: <name>' .. 'END-FOLDED-FROM: <name>' block holds >=%d of them VERBATIM "
          "(or all of them when the FINDING has fewer)." % (MIN_CLAIM_CHARS, MIN_FOLDED_CLAIMS))

    blocked, applied, deleted, uncited = [], 0, 0, 0
    for name, path, text in targets:
        claims = claim_lines(text)
        citers = dict(index.get(name, {}))
        partial = {}
        for k, v in index.items():                 # a TRUNCATED mention is still a citation -- see citers_of()
            if k == name:
                continue
            if is_same_citation(k, name):
                for p_, t_ in v.items():
                    if p_ not in citers:
                        citers[p_] = t_; partial[p_] = k
        print("\n%s" % name)
        print("  claims: %d claim line(s)" % len(claims))
        if not citers:
            uncited += 1
            print("  citers: NONE -- free to delete; nothing cites it and no row is blocked on it")
        for cp in sorted(citers):
            state, hits = fold_state(citers[cp], name, claims)
            rel = os.path.relpath(cp, os.path.dirname(gh))
            tag = "  [cites it as %s]" % partial[cp] if cp in partial else ""
            print("  citer %-70s %s (%d/%d claim line(s) present)%s"
                  % (rel, state, hits, min(MIN_FOLDED_CLAIMS, len(claims)), tag))
            if state != "FOLDED":
                blocked.append((name, rel, state))

        if a.apply and citers:
            if not claims:
                die("--apply on %s: it has ZERO claim lines, so an automatic fold would write an EMPTY block and "
                    "a marker with nothing under it is exactly the vacuous green this tool exists to refuse. "
                    "Write the summary by hand -- the gate accepts any block holding lines verbatim from the FINDING." % name)
            keep = claims[:max(MIN_FOLDED_CLAIMS, min(len(claims), 12))]
            block = ("\n<!-- FOLDED-FROM: %s (%d claim line(s), copied verbatim; the FINDING is the long form) -->\n"
                     % (name, len(keep))) + "\n".join("- %s" % c for c in keep) + \
                    ("\n<!-- END-FOLDED-FROM: %s -->\n" % name)
            for cp in sorted(citers):
                state, _ = fold_state(citers[cp], name, claims)
                if state == "FOLDED":
                    continue
                with open(cp, "a", encoding="utf-8") as fh:
                    fh.write(block)
                applied += 1
                print("  FOLDED INTO %s (%d claim line(s) appended verbatim)" % (os.path.relpath(cp, os.path.dirname(gh)), len(keep)))

    if a.apply:
        print("\nAPPLIED: %d fold block(s) written" % applied)
        return 0

    if a.delete:
        still = [b for b in blocked if b[0] in {t[0] for t in targets}]
        if still:
            print("\n⛔ REFUSING THE DELETE(2): %d cited-and-unfolded citer(s) -- the measurement would go with the file:" % len(still))
            for nm, rel, st in still:
                print("    %s  cited by %s  [%s]" % (nm, rel, st))
            print("    cure: util_finding_fold_before_delete.sh --apply <name>, or write the fold block by hand, "
                  "IN THE SAME LANDING as the delete (RULES.md line 31).")
            return 2
        for name, path, _ in targets:
            if path and os.path.exists(os.path.join(gh, path)):
                os.remove(os.path.join(gh, path)); deleted += 1
                print("  DELETED %s (uncited or fully folded)" % path)
        print("\nDELETED: %d FINDING file(s); all claims are in a live citer or nothing cited them" % deleted)
        return 0

    if a.deleted_since:
        if blocked:
            print("\n⛔ RED(1): %d FINDING(s) were DELETED with claims still cited and not folded:" % len(blocked))
            for nm, rel, st in blocked:
                print("    %s  cited by %s  [%s]" % (nm, rel, st))
            return 1
        print("\nOK: every FINDING deleted in this range left its claims behind in a live citer (or was cited by nothing)")
        return 0

    print("\nREPORT ONLY (no --delete, no --apply): %d unfolded citer link(s) standing, %d FINDING(s) cited by nothing"
          % (len(blocked), uncited))
    return 0

if __name__ == "__main__":
    sys.exit(main())
