#!/usr/bin/env python3
# util_score_row.py -- THE ONE HELPER EVERY RUNNER CALLS to rewrite its suite's row in the ONE
# LEADERBOARD, .github/SCORE.md.  Row `score-md-rows-are-rewritten-by-the-runner-that-measured-them`
# (rank 0, hq_T; rowed to hq_B at CEO-167 and reassigned when /home/claude_T opened -- GOAL-HQ-TEST
# mandate 2).
#
# THE LAW IT IMPLEMENTS, verbatim from RULES.md FACT RULES (Lon 2026-09-03 ~16:05 CDT to ceo): "Make a
# FACT RULE that any run of a test suite by any session will update the ONE LEADERBOARD. Make it
# official so the file DOES stay up-to-date always." -- and ten minutes earlier, the WHY, which is the
# design spec and not just motivation: "go to a LEADER BOARD that is kept up-to-date. So whenever we
# want to know the state it is there not an hour away of running tests."
#
# ⛔⭐ WHY THIS IS NOT util_build_score_md.py, AND WHY IT MUST NOT BECOME IT. That generator answers a
# different question and answers it well: it REGENERATES THE WHOLE GRID by invoking all seven
# languages' floor gates and all seven rungs boards. That is ~30-40 minutes on a loaded box -- which
# is the exact cost Lon was ruling against in the sentence that created this file. A helper that
# re-runs anything to record a measurement someone ALREADY MADE has reintroduced the hour-away wait it
# was written to remove. So the hard rule for this file: IT RUNS NO SUITE, NO GATE AND NO COMPILER. It
# reads git for provenance, the Makefile for RT_OPT, and the numbers the caller hands it. If you ever
# find yourself adding a subprocess call to a test script here, you are writing the other tool.
#
# ⛔ AND IT REFUSES RATHER THAN GUESSES (RULES.md: a test that cannot measure REFUSES with rc=2).
# Unknown language, unknown column, a board line carrying no digit, a pipe character that would
# silently corrupt the table, a missing measurer, a grid whose shape does not match -- every one of
# these exits 2 with a named reason.  There is no path here that writes a plausible row it did not get
# told.  A leaderboard that invents a cell is worse than one that is stale: stale says so.
#
# ⛔⭐ THE PROVENANCE COLUMN IS A LIST, NOT A LINE, AND THAT IS DELIBERATE. One row's cells are
# routinely measured by different sessions on different trees -- Icon's STRICT rung suite, its rungs
# board and its Arizona/JCON vendor numbers were three trees and three measurers on the day this was
# written.  A single "Tree - clock - by" string for the whole row would therefore be false for at
# least two of its cells, and falsely PRECISE, which is worse than vague.  So the last cell holds one
# `<column>: <stamp>` clause per measured column, and rewriting a column rewrites ONLY its own clause.
import argparse
import datetime
import difflib
import importlib.util
import os, re, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
S4E = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SCORE_MD = os.path.join(S4E, ".github", "SCORE.md")
REPOS = ["SCRIP", "corpus"]

# The grid's columns, keyed by the short name a runner passes to --column.  Index is the cell position
# in the markdown row.  These are READ BACK from the live header line and cross-checked (see
# find_table) -- the table below is the naming authority, never the shape authority, so a column
# renamed upstream refuses loudly here instead of writing into the wrong cell.
COLUMNS = {
    "entries": (1, "Rungs suite"),
    "floor":   (2, "Floor / smoke gate"),
    "board":   (3, "Rungs board"),
    "vendor":  (4, "Vendor / package suites"),
}
PROV_COL = 5
STALE_WARN_COMMITS = 25

# ⭐ THE FALLBACK cmd_write USES WHEN A PLAIN OVERWRITE WOULD LOSE PROSE (see cell_prose_loss below), row
# score-writer-models-the-snobol4-board-cell-so-the-runner-can-write-it. hq_T RULED REFUSE on 2026-09-04
# (task score-md-runners-rewrite-a-cell-in-place-and-silently-discard-the-prose-they-never-modelled) for a
# NAMED reason: silently carrying an old caveat forward attaches it to a new number as though it still
# describes the CURRENT measurement, when its truth is unknown by construction (the Raku
# unknown_defaulted_to_run=10 incident -- a stale claim that would have read as current and correct).
# ⛔ THIS IS NOT THAT. A silent merge and a labelled supersession are different claims. What follows never
# asserts `before` is still true -- it demotes it, explicitly, to "the reading THIS one supersedes", which
# is exactly the rhetorical move every hand-edit of the snobol4 board/entries cells already makes (`⛔
# SUPERSEDED READING BELOW`, `⚠ SUPERSEDES the reading below ... kept verbatim`) -- this only mechanizes it.
# Carrying `before` forward BYTE-FOR-BYTE also makes loss structurally impossible: cell_prose_loss(before,
# result) is empty by construction, because `before` is a literal substring of `result` (see the assert in
# cmd_write). A cell whose entire un-modelled history is already labelled "superseded" by an earlier write
# is not the case hq_T's ruling was written against; a cell carrying a LIVE, un-superseded caveat about the
# measurement being replaced still is, and this fallback does not (cannot) launder that case quiet -- it
# just refuses to leave the runner permanently unable to write a cell that has grown enough history, which
# was becoming the status quo hand-editing was creating anyway. Surfaced back to hq_T as a QA note on this
# row rather than decided silently: this is a seat's reading of an HQ ruling, not a re-ruling of it.

# ⛔⭐⭐ A FOLDED-FORWARD READING CARRIES NO DIGIT FRACTION, EVER (hq_T, ceo CEO-475, on the coo's 18:03
# report and hq_P's 819a56a6). THE DEFECT: the fold below wrote the superseded reading back into the cell
# VERBATIM, digits and all, and `agree` (cell_fractions) then read `739/751` out of the ARCHIVE and
# compared it against the grid's live 740 -- RED on every tick a suite MOVES, and green by accident on
# every tick it does not. Latent from the day the fold landed; it fires on the first movement of anything.
# ⛔ cell_fractions ALREADY tries to drop a superseded fraction (PROGRESS_SUPERSEDED), and that is exactly
# why this sat unnoticed: the drop is CLAUSE-scoped, and a folded board reading is many clauses long, so
# the marker covers the FIRST fraction and every later one reads as live. A guard that half-works on the
# common case is worse than none, because its author stops looking.
# ⭐⭐ THE CURE IS THIS FILE'S OWN CONVENTION, WHICH THIS FILE ALREADY TELLS HUMANS TO USE AND DID NOT USE
# ITSELF: the suite_target_conflict die() above instructs its reader to "take the NUMBER out of it -- spell
# the numerals out" and warns that "this guard sees DIGITS, not labels, so a relabelled archive is still a
# competing reading". The writer knew the rule, printed the rule, and exempted itself from it. SCORE.md is
# already full of hand-spelled archives ("thirty-four of eight-hundred-fifty-one") for this exact reason.
_ONES = ("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven",
         "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen")
_TENS = ("", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety")
def _spell_int(n):
    # Hyphenated, matching the spelled archives already in SCORE.md. Above six digits it gives up and
    # returns None -- the caller then leaves the fraction alone rather than emitting something unreadable,
    # and the parser hardening below is what keeps that case honest.
    if n < 0 or n > 999999:
        return None
    if n < 20:
        return _ONES[n]
    if n < 100:
        return _TENS[n // 10] + ("" if n % 10 == 0 else "-" + _ONES[n % 10])
    if n < 1000:
        return _ONES[n // 100] + "-hundred" + ("" if n % 100 == 0 else "-" + _spell_int(n % 100))
    return _spell_int(n // 1000) + "-thousand" + ("" if n % 1000 == 0 else "-" + _spell_int(n % 1000))
# ⛔ THE SAME REGEX THE PARSER READS WITH, so the neutraliser and the reader cannot drift apart. If
# cell_fractions ever learns a new fraction shape, this must learn it in the same edit -- which is why it
# is written once, here, and referenced by both rather than typed out twice.
FRACTION_RE = re.compile(r"(?<![\d/])(\d+)\s*/\s*(\d+)(?![\d/])")
def spell_fractions(text):
    # ⭐ NOT a general digit scrub: tree hashes, dates, RT_OPT=-O0 and box clocks all carry digits and none
    # of them is a population. Only the fraction shape is neutralised, and only into words that say the
    # same thing -- the archived reading stays READABLE, which is the whole reason it is folded forward.
    def one(m):
        ps, t = _spell_int(int(m.group(1))), _spell_int(int(m.group(2)))
        return m.group(0) if ps is None or t is None else "%s of %s" % (ps, t)
    return FRACTION_RE.sub(one, text)

# ⛔⭐⭐ THE FOLD SPLITS ON THIS PREFIX, NOT ON THE FULL MARKER, AND THAT IS A CORRECTNESS BOUND RATHER THAN
# A CONVENIENCE. The depth cap below works by cutting `before` at its existing marker; if the constant's
# WORDING ever changes, cells written by the previous version stop matching it, the cut silently finds
# nothing, and every one of them grows by a whole extra archived reading on the next write -- the exact
# unbounded growth the cap exists to prevent, reintroduced by an edit that looks purely editorial.
# ⭐ MEASURED, not hypothesised: it happened in this very commit. Rewording the marker to stop claiming
# "verbatim" (it no longer is -- fractions are spelled now) produced a cell carrying TWO nested archives on
# the first write, and it was visible only because a fixture run printed the cell in full. A constant that
# is both WRITTEN into data and MATCHED against old data has two different compatibility requirements, and
# only the matching half may never change. So: match the stable prefix, write the full sentence.
SUPERSEDE_PREFIX = "⛔ SUPERSEDES the reading below"
SUPERSEDE_MARKER = "⛔ SUPERSEDES the reading below (util_score_row.py folded it forward as provenance -- prose byte-for-byte, fractions spelled into words so no parser reads an archive as a live number; not hand-edited, not asserted still true):"


def supersede_marker(prov_before, key, when, measurer):
    # ⛔ THE FOLDED TAIL NAMES ITS OWN DATE AND TREE, MACHINE-INSERTED (coo 2026-09-16; hq_prolog's third observation, row
    # util-score-row-board-write-folds-the-replaced-cells-tail-forward-as-provenance-without-a-machine-marker): the fixed
    # SUPERSEDE_MARKER above says the tail is not asserted, but not WHEN it was true or on WHICH tree -- so hq_prolog's fresh
    # 542/563 shipped glued to '334 is DOWN from 340' and they hand-labelled the tail 'RETAINED PROVENANCE FROM THE SUPERSEDED
    # 2026-09-05 READING (b812fb6d1)'.  A seat remembering to write that label is the failure mode; this builder reads the
    # replaced reading's own `<key>:` provenance clause (the stamp the fold retires) and puts its hash, date and measurer into
    # the marker.  The hash is written PLAIN (no `SCRIP \`h\`` form) on purpose: TREE_HASH_RX must not read an archived tree as
    # a claim of the cell (check: the claim is the clause, never a quote), and a later fold splits on SUPERSEDE_PREFIX, which
    # this marker still begins with.
    old = ""
    for clause in (prov_before or "").split(";"):
        mm = re.match(r"^\s*([A-Za-z0-9_.-]+)\s*:", clause)
        if mm and mm.group(1) == key:
            hs = TREE_HASH_RX.findall(clause)
            dm = re.search(r"(\d{4}-\d{2}-\d{2})(?:[ T]\d{2}:\d{2}(?: [A-Z]{2,5})?)?", clause)
            sm = re.search(r"·\s*\d{4}-\d{2}-\d{2}[^·]*·\s*([A-Za-z0-9_-]+)", clause)
            old = "the reading below was stamped %s: SCRIP %s on %s by %s" % (
                key, hs[0] if hs else "(no tree)", dm.group(1) if dm else "(no date)", sm.group(1) if sm else "(no seat)")
            break
    if not old:
        old = "the reading below carried no `%s:` provenance clause of its own" % key
    return SUPERSEDE_MARKER.replace("(util_score_row.py folded it forward",
                                    "(superseded %s by %s; %s; util_score_row.py folded it forward" % (when, measurer, old), 1)


# ⛔⭐⭐ EVERY REFUSAL ASSERTS ITS OWN "NOTHING WAS WRITTEN", AT ALL 44 die() SITES, BY CONSTRUCTION
# (coo 2026-09-20, on the ceo's reported finding; row a-refused-score-row-write-still-moved-a-provenance-
# stamp-on-a-row-nobody-measured).  THE REPORT AND WHAT IT TURNED OUT TO BE: the ceo saw a provenance stamp
# move on the raku row -- tree, corpus, date and measurer all forward, the NUMBER unchanged -- in a sitting
# whose only score-row runs had REFUSED and printed "NOTHING WAS WRITTEN: SCORE.md and SUITES.tsv are both
# untouched".  Measured here: those refusal paths are innocent (all three reproduce byte-identical, see the
# selftest arms below), and the stamp was moved by a SUCCESSFUL raku/floor write whose reading did not change.
# ⭐ THE ARM IS STILL THE RIGHT ONE AND THAT IS THE POINT.  Fourteen of this file's refusal messages PROMISE
# byte-identity in words, and until now the promise was kept by four hand-written selftest arms covering four
# of the paths -- i.e. the guarantee was a per-path habit, and the ten paths nobody had written an arm for
# were asserting something no instrument had ever checked.  A promise printed at 14 sites and checked at 4 is
# indistinguishable, to its reader, from one checked at 14.
# ⛔ SO THE CHECK LIVES IN die() RATHER THAN IN N ARMS: one site, every refusal, no per-path maintenance, and
# it CANNOT fall out of date as refusals are added -- which is the same reasoning _write_score_md records for
# routing nine writers into one.  It never repairs and never hides the refusal: the refusal's own rc and text
# are untouched, and the finding is printed BESIDE them.
# ⭐ IT READS IN BOTH DIRECTIONS, because a refusal AFTER a deliberate write is a different animal from one
# before it.  suite_sync's banner-failure die and the grid read-back die are both REAL partial states that
# already say "⛔ PARTIAL" in prose; there the check CONFIRMS the prose and names the files, so PARTIAL stops
# being an author's claim and becomes a measurement.  A file that moved with NO deliberate write behind it is
# the defect the ceo described, and it is named as one.
_REFUSAL_WATCH = {}          # path -> digest as of the last moment this process knows it to be unwritten
_WROTE_DELIBERATELY = set()  # paths this process meant to write, so a later refusal is PARTIAL, not manufacture


def _digest(path):
    try:
        import hashlib
        return hashlib.md5(open(path, "rb").read()).hexdigest()
    except OSError:
        return None            # absent is a state, not an error: a first write creates the file


def refusal_watch_arm():
    """Record what the leaderboard files look like BEFORE this command can touch them."""
    for _p in (SCORE_MD, SUITES_TSV):
        _REFUSAL_WATCH[_p] = _digest(_p)


def refusal_watch_wrote(path):
    """Declare a write this command MEANT to make, and re-baseline it."""
    _WROTE_DELIBERATELY.add(path)
    _REFUSAL_WATCH[path] = _digest(path)


def _refusal_watch_report():
    moved = [p for p, d in _REFUSAL_WATCH.items() if d != _digest(p)]
    if not moved:
        return ""
    undeclared = [p for p in moved if p not in _WROTE_DELIBERATELY]
    out = []
    if undeclared:
        out.append("  ⛔⛔ AND THE REFUSAL ABOVE IS NOT TRUE OF %s: %s CHANGED ON DISK during this refused run,\n"
                   "     with no deliberate write behind it. A refusal that half-writes is worse than none -- the file now\n"
                   "     carries a stamp from a run that reported writing nothing, which is the ADRIFT class (a tree and a\n"
                   "     measurer moving forward under a number nobody re-measured). ⛔ REVERT IT (git checkout the file)\n"
                   "     AND REPORT THIS LINE: it is a defect in util_score_row.py, not in your invocation."
                   % (("it" if len(undeclared) == 1 else "them"), ", ".join(sorted(undeclared))))
    declared = [p for p in moved if p in _WROTE_DELIBERATELY]
    if declared:
        out.append("  ⛔ PARTIAL, MEASURED: %s WAS written before this refusal (its digest moved), so this run left the\n"
                   "     board half-moved. The refusal text above is true only of the files NOT named here."
                   % ", ".join(sorted(declared)))
    return "\n" + "\n".join(out)


def die(msg, rc=2):
    sys.stderr.write("REFUSED(%d) util_score_row: %s%s\n" % (rc, msg, _refusal_watch_report()))
    raise SystemExit(rc)


# ⛔⭐⭐ THE ONE WRITER OF SCORE.md, AND THE INVARIANT IT EXISTS TO HOLD (hq_T 2026-09-08, on hq_C's
# observation, with hq_V's independent occurrence as the second witness).
# ⭐ THE OBSERVATION: a `PACKAGE_INVENTORY package=gimpel` clause was present in SCORE.md at .github
# 932016de and absent immediately after that row closed, while every other package in the SAME CELL kept
# its clause; hq_V saw the identical shape on snoflake and attributed it to a CONFLICT RESOLUTION. Two
# candidate paths, one occurrence each, and hq_C explicitly declined to name a cause it could not isolate.
# ⛔ WHY IT MATTERS MORE THAN A LOST LINE: inventory_clauses() keeps the LAST clause per package and feeds
# the September-10 progress readers their GRADED POPULATION. So a dropped clause does NOT read as missing --
# the package silently stops contributing a population and THE PERCENTAGE ABOVE IT STILL PRINTS, confidently.
# Absence and correctness look identical, which is this tree's favourite failure and the reason for gates.
# ⭐⭐ AND THE REAL FINDING IS THE SHAPE, NOT THE CLAUSE: this file had NINE independent
# `open(SCORE_MD,"w").write(...)` sites. A FILE WITH NINE WRITERS HAS NO INVARIANT -- there was nowhere to
# put "no package may vanish", so it was nobody's job at nine call sites at once. Routing all nine through
# here is what makes the guarantee statable at all; the check below is only the first thing worth stating.
# ⛔ REFUSES, NEVER REPAIRS. A dropped package means the caller built content from something that had already
# lost it (a conflicted rebase, a hand edit), so silently re-adding the clause would republish a number
# nobody measured -- stamped current by this run's provenance. Losing it loudly beats keeping it falsely.
_INV_PKG_RX = re.compile(r"PACKAGE_INVENTORY\s+package=([A-Za-z0-9_./-]+)")
# ⛔⭐⭐ THE SECOND INVARIANT OF THE ONE WRITER: A ROW MAY NOT CHANGE ITS COLUMN COUNT (hq_U 2026-09-12,
# on CEO-610 / COO-62 -- my own x64tests write, which is why it is stated here rather than reported).
# ⭐ THE OCCURRENCE, character-exact: the x64tests vendor clause landed INSIDE the snobol4 DISPLAY row's
# provenance cell, at its first ';' -- which falls inside "hq_B (postoffice-gates row; incremental build
# ..." -- followed by a LITERAL ' | '.  The row went from 6 cells to 7 against a 6-column header.  Note
# what that is NOT: the vendor cell was never touched, so merge_clause did not fragment it and a better
# matcher would not have helped.  Whatever produced it, the result reached this function and was written.
# ⛔ WHY IT IS WORSE THAN A WRONG NUMBER, and the coo's words for it: "a grid row with the wrong column
# count is silently invisible, which is the worst failure shape we have."  Every reader that parses the
# table by column DROPS the row whole -- test_gate_score_tables_agree reported `1 language(s) MALFORMED`
# and compared snobol4 against nothing at all, fleet-wide, for an hour; the logtalk runner's own write
# printed the same SKIP on the coo's pass.  A language that scores nothing conflicts with nothing, so
# the damage reads as calm.
# ⭐⭐ THE CHECK IS DIFFERENTIAL ON PURPOSE, and that is the whole reason it is landable today.  Refusing
# every ragged row outright would make this writer refuse for as long as ANY row anywhere in the file is
# ragged -- i.e. it would punish thirteen seats for one seat's damage and be reverted within the hour.
# It refuses only a row THIS WRITE makes ragged, keyed by the row's first cell so an edit elsewhere in
# the row does not look like a new offence.  ⛔ REFUSES, NEVER REPAIRS: which cell the stray text belongs
# in is a judgement about what the prose MEANS (the same reason merge_clause refuses rather than guesses),
# and this function cannot make it.
def _table_shapes(text):
    """{(table index, first cell) -> column count} for every markdown row under a `|---|` header."""
    shapes, ti, hdr = {}, -1, None
    lines = text.split("\n")
    for n, ln in enumerate(lines):
        t = ln.strip()
        if not t.startswith("|"):
            hdr = None
            continue
        if re.match(r"^\|[\s:|-]*\|\s*$", t) and "-" in t and n and lines[n - 1].strip().startswith("|"):
            ti += 1; hdr = t.count("|") - 1; continue      # the separator row OPENS a table; cells, not pipes
        if hdr is None:
            continue
        key = (ti, t.split("|")[1].strip() if t.count("|") > 1 else "")
        shapes.setdefault(key, t.count("|") - 1)            # first spelling of a key wins; duplicates are not this guard's business
    return shapes




def _write_score_md(lines, seeding=False):
    """Write SCORE.md. Every writer in this file goes through here. Refuses rc=2 if the write would drop a
    PACKAGE_INVENTORY package key the file already carried. `seeding` is for the paths that legitimately
    build the file from nothing -- they cannot drop what was never there, and they say so explicitly."""
    new = "\n".join(lines)
    try:
        old = open(SCORE_MD, encoding="utf-8").read()
    except OSError:
        old = ""
    was, now = _table_shapes(old), _table_shapes(new)
    ragged = sorted(k for k, v in now.items() if k in was and was[k] != v)
    if ragged and not seeding:
        die("this write would change the COLUMN COUNT of %d table row(s), and a row whose column count "
            "disagrees with its header is not read wrong -- it is DROPPED WHOLE by every reader that "
            "parses the table, while the tables around it still print confidently (CEO-610/COO-62):\n%s\n"
            "  ⛔ Nothing was written, and this guard does not repair: which cell the extra text belongs "
            "in is a judgement about what the prose means.  Look at the row, put the text in the cell it "
            "was measured for, then re-run the runner that measured it."
            % (len(ragged), "\n".join("  - table %d, row %r: %d columns -> %d" % (t, k, was[(t, k)], now[(t, k)])
                                      for (t, k) in ragged)))
    lost = sorted(set(_INV_PKG_RX.findall(old)) - set(_INV_PKG_RX.findall(new)))
    if lost and not seeding:
        die("this write would DROP the PACKAGE_INVENTORY clause for %s. Those clauses carry the GRADED "
            "POPULATION the September-10 progress readers use, and a package with no clause does not read "
            "as missing -- it silently stops contributing a population while the percentage above it still "
            "prints. Nothing was written. The content you are writing already lost it (a conflicted rebase "
            "of SCORE.md is the known way), so re-run the runner that measured %s and land that, rather "
            "than re-adding digits nobody measured in this sitting."
            % (", ".join(lost), lost[0]))
    open(SCORE_MD, "w", encoding="utf-8").write(new)
    refusal_watch_wrote(SCORE_MD)   # a refusal AFTER this point is PARTIAL, and die() says so with the digest


def git(repo, *args):
    p = os.path.join(S4E, repo)
    if not os.path.exists(os.path.join(p, ".git")):
        return None
    try:
        out = subprocess.run(["git", "-C", p] + list(args), capture_output=True, text=True, timeout=30)
    except Exception:
        return None
    return out.stdout.strip() if out.returncode == 0 else None


def tree_stamp():
    # The SCORE.md-column rendering of lib_gate.sh's gate_stamp tree line -- same three facts (short
    # hash, -DIRTY when the worktree has uncommitted changes, one entry per repo the measurement
    # reads), rendered as markdown instead of as a gate's stdout.  `-e` not `-d` on .git, because in a
    # git WORKTREE .git is a FILE and `-d` silently skips every repo (hq_B measured that one live on
    # 2026-09-02; it printed a stamp with nothing after it).
    # ⛔⭐⭐ THE STAMP NAMES THE TREE THE RUN GRADED, NOT HEAD AT WRITE TIME, WHENEVER THE RUNNER SAID SO
    # (hq_T 2026-09-08, after tripping this three times in one sitting, twice while doing the disciplined thing).
    # A board takes ten to forty minutes; this function runs at the END of it.  A seat who commits and pushes
    # mid-run -- which is exactly what the CEO-174 dirty-tree guard pushes you toward, because a dirty tree skips
    # the write entirely -- moves HEAD under a measurement that already happened, and the row then names a tree
    # containing commits it never ran.  The number is real and its provenance is fiction, which is strictly worse
    # than a number that refuses: the row is checkoutable, reproducible-looking, and wrong about what it measured.
    # ⭐ S4E_TREE_AT_START is set by the runner at its START, as `SCRIP=<hash>,corpus=<hash>`.  Absent, this
    # behaves exactly as before -- so no runner is broken by not knowing about it, and the ones that do know get
    # an honest stamp.  A hash that no longer resolves is reported as given rather than silently swapped for HEAD.
    at_start = {}
    for kv in (os.environ.get("S4E_TREE_AT_START", "") or "").split(","):
        if "=" in kv:
            k, v = kv.split("=", 1)
            if k.strip() and v.strip():
                at_start[k.strip()] = v.strip()
    parts = []
    for r in REPOS:
        h = git(r, "rev-parse", "--short", "HEAD")
        if h is None:
            parts.append("%s=unknown" % r)
            continue
        dirty = "-DIRTY" if git(r, "status", "--porcelain") else ""
        start = at_start.get(r)
        if start and not h.startswith(start) and not start.startswith(h):
            # ⭐ BOTH FACTS, because the reader needs to know the tree moved AND that the number predates it.
            parts.append("%s `%s%s` (graded; HEAD moved to `%s` during the run)" % (r, start, dirty, h))
        else:
            parts.append("%s `%s%s`" % (r, h, dirty))
    return " · ".join(parts)


# ⛔⭐ ONE REGEX FOR "WHICH SCRIP TREE DOES THIS TEXT NAME", because two copies of it drift apart and
# the drift is invisible: `check` grew this pattern to grade cells, `write` needs the same answer to
# refuse a stale rewrite, and a second copy would eventually disagree with the first about what counts
# as a stamp -- one of them would then quietly stop seeing half the board.
TREE_HASH_RX = re.compile(r"SCRIP `([0-9a-f]{7,40})(?:-DIRTY)?`")


def git_rc(repo, *args):
    # The RETURN CODE of a git command, where git() above gives its stdout.
    # ⛔⭐ git() COLLAPSES "RAN AND SAID NO" INTO "COULD NOT RUN": it returns None for rc=1 and for a
    # missing checkout alike. `merge-base --is-ancestor` answers ENTIRELY in its exit status (0 yes,
    # 1 no, >1 broken), so asking it through git() would make "these two trees are unrelated" and
    # "there is no SCRIP repo here" the same answer -- and the safe default is OPPOSITE for the two:
    # the first is a real finding, the second means the question was never asked.
    p = os.path.join(S4E, repo)
    if not os.path.exists(os.path.join(p, ".git")):
        return None
    try:
        return subprocess.run(["git", "-C", p] + list(args), capture_output=True, text=True, timeout=30).returncode
    except Exception:
        return None


def tree_ancestry(new, old, repo="SCRIP"):
    """How the tree a write is about to STAMP relates to the tree that measurement ALREADY stamps.

    "older"     new is a strict ancestor of old -- the write would publish a number measured further
                BACK than the one already on the board.
    "newer"     old is a strict ancestor of new -- the ordinary case, a re-measure moving forward.
    "same"      both abbreviations resolve to one commit.
    "unrelated" neither reaches the other (two branches); ancestry does not rank them and this does
                not pretend it can.
    None        one of them is not a commit THIS checkout knows, so the question went unanswered.

    ⛔⭐ THE INCIDENT (hq_S, 2026-09-10, CEO-492): two runners minutes apart rewrote one SCORE.md row in
    place and git handed the loser a textual conflict, whose correct resolution is per-row TREE
    ANCESTRY and not ours-vs-theirs -- hq_S's 750/756 on 64292dee1 was an ancestor of 754/757 on
    b9f9bc465, so keeping its own side would have published a LOWER AND STALER number that looked
    exactly like an update. ⭐ Nothing in the row TEXT carries the ancestry: both sides are a real
    number with a real hash and a real measurer, and the newer one is not longer, not larger, and not
    later in the file. A human resolving that conflict has no signal to resolve it BY, which is why
    hq_S had to run merge-base by hand and why the rule belongs in the writer.
    ⛔ NOT `git rev-list --count`. Distance-to-origin ranks two hashes only while history is linear,
    and for two unrelated branches it returns a confident ordering shaped exactly like a real answer --
    the narrower-question-than-you-asked defect this tree keeps meeting (CLAUDE.md, `command -v`)."""
    if not new or not old:
        return None
    if new == old:
        return "same"
    fn = git(repo, "rev-parse", "--verify", "-q", "%s^{commit}" % new)
    fo = git(repo, "rev-parse", "--verify", "-q", "%s^{commit}" % old)
    if not fn or not fo:
        return None
    if fn == fo:
        return "same"
    if git_rc(repo, "merge-base", "--is-ancestor", fn, fo) == 0:
        return "older"
    if git_rc(repo, "merge-base", "--is-ancestor", fo, fn) == 0:
        return "newer"
    return "unrelated"


def stamped_trees(cell, prov, key):
    # Every SCRIP tree the row ALREADY claims for the measurement about to be rewritten, as
    # (where, hash) -- the provenance clause keyed for it, plus any hash in the LIVE reading of the
    # cell itself.
    # ⭐ BOTH SOURCES, because the board is full of hand-edits and they land in opposite places: a write
    # through this helper stamps the Tree column, a hand re-measure writes the hash into the prose
    # ("LANE RE-MEASURE ... on SCRIP `f3f4870d7`") and touches no clause. `check` learned that lesson on
    # 2026-09-05; a guard that reads only one of the two is blind to whichever half it did not pick.
    # ⛔ ONLY THE LIVE READING. Everything past SUPERSEDE_PREFIX was labelled not-asserted by an earlier
    # fold, so the trees buried in it are retired by construction -- ranking a new measurement against an
    # archived one would refuse a perfectly ordinary forward write for disagreeing with history.
    out = []
    for c in [x.strip() for x in (prov or "").split(";") if x.strip()]:
        if re.match(r"^%s\s*(?::|(?=\s|$))" % re.escape(key), c):
            hs = TREE_HASH_RX.findall(c)
            if hs:
                out.append(("the `%s:` provenance clause" % key, hs[0]))
            break
    head = (cell or "").split(SUPERSEDE_PREFIX, 1)[0]
    for h in TREE_HASH_RX.findall(head):
        if h not in [x[1] for x in out]:
            out.append(("the cell's own text", h))
    return out


def rt_opt():
    # ⛔ READ IT, NEVER TYPE IT.  RT_OPT is -O0 by Lon's s262 FACT RULE and the Makefile carries that at
    # exactly one line -- but this file quoting "-O0" from memory is precisely the transcription defect
    # RULES.md names (a second stale RT_OPT was deleted from the Makefile so a grep could not land on
    # the wrong one; a hardcoded copy here would put it back, one directory over).
    mk = os.path.join(S4E, "SCRIP", "Makefile")
    try:
        for line in open(mk, encoding="utf-8"):
            m = re.match(r"\s*RT_OPT\s*\??=\s*(\S+)", line)
            if m:
                return m.group(1)
    except OSError:
        pass
    return "RT_OPT=unreadable"


def table_shape_error(cells):
    # Return why this header is NOT the standardized display, or None if it IS.  Split out of
    # find_table so the same proof can be applied to EVERY candidate header rather than only the first.
    if len(cells) != PROV_COL + 1:
        return "has %d columns, this helper knows %d (%s)" % (len(cells), PROV_COL + 1, ", ".join(COLUMNS))
    for key, (idx, expect) in COLUMNS.items():
        if not cells[idx].startswith(expect):
            return "column %d is %r, expected it to start with %r (--column %s)" % (idx, cells[idx], expect, key)
    return None


def tree_is_dirty():
    # ⛔⭐ A DIRTY-TREE NUMBER DESCRIBES NO CHECKABLE TREE, SO IT IS NOT A LEADERBOARD ROW (ceo CEO-174,
    # policy for every suite that ever sits inside `make test`). It is a SCOUTING DATUM: real, useful to
    # the person who ran it, and unverifiable by anyone else -- the row would name a hash whose working
    # tree nobody else can reconstruct, which is the unfalsifiable-row defect SCORE.md's own text spends
    # three paragraphs on, merely wearing a real hash as a disguise.
    # ⭐ THE CONDITION IS COMPUTED FROM THE TREE, NEVER CHOSEN. There is deliberately no --force and no env
    # override: an opt-out would make the highest-traffic board the one exception to the FACT RULE, and the
    # exception would be taken by whoever was in the biggest hurry. The clean run IS the landing run, and
    # its SCORE.md change rides the landing's own .github-last push -- so no other seat ever meets an
    # unexplained dirty .github mid-work, which was the whole objection this answers.
    return [r for r in REPOS if git(r, "status", "--porcelain")]


def tree_is_unpushed():
    """⛔⭐ THE GUARD ABOVE TESTS DIRTINESS AND THE RULE IS ABOUT CHECKOUTABILITY, AND THOSE ARE NOT THE SAME
    PREDICATE (hq_S, 2026-09-05, found by tripping it rather than by reading it -- measured twice on one box).
    A CLEAN tree sitting on a LOCAL UNPUSHED COMMIT passes tree_is_dirty() perfectly and still names a tree
    that exists nowhere but that one root: their run wrote `snobol4/board` naming 9b9acce28, a merge commit on
    a feature branch in a single seat's checkout. The refusal sentence one line up already says the real
    reason out loud -- "a tree nobody else can check out" -- so the fix is to make the test say what the
    sentence says.

    ⭐ THE PREDICATE IS "REACHABLE FROM ANY REMOTE BRANCH", NOT "ANCESTOR OF origin/main", and the difference
    is the whole reason this is safe to add. hq_S's objection to the strict form is correct: a mid-work
    measurement on a PUSHED feature branch is legitimate state, and demanding descent from main would silence
    it. `git branch -r --contains HEAD` answers the question actually being asked -- can another seat check
    this out -- and says yes for any pushed branch, main or not.

    ⛔ IT REFUSES RATHER THAN STAMPING THE ROW PROVISIONAL, deliberately, and against the other option hq_S
    offered. SCORE.md is read AS STATE -- that is the entire point of the FACT RULE ("so whenever we want to
    know the state it is there not an hour away of running tests") -- and a provisional row still occupies
    the cell, still answers "what is the score", and is still what `check` reads for staleness. A row that
    must be disbelieved is worse than an absent one. The dirty case already chose SKIP-with-a-notice for the
    identical reason; two treatments for one reason is how the exception gets taken by whoever is in the
    biggest hurry.

    ⭐ WHY IT MATTERED EVEN THOUGH IT SELF-CORRECTED: hq_S's false row was overwritten by their very next
    measurement on a real pushed tree -- but by the LUCK OF THEIR RUNNING ORDER, not by design. A session
    that had stopped one run earlier would have left the false row standing and pushed it.

    Returns the repos whose HEAD no remote branch contains. A repo with no remote-tracking refs at all is
    NOT reported: it cannot answer the question, and a check that cannot measure must not manufacture a
    verdict -- tree_is_dirty() above is the guard that still applies there."""
    out = []
    for r in REPOS:
        if git(r, "rev-parse", "--short", "HEAD") is None:
            continue
        remotes = git(r, "branch", "-r", "--format=%(refname)")
        if not remotes:
            continue
        contains = git(r, "branch", "-r", "--contains", "HEAD")
        if not contains:
            out.append(r)
    return out


def find_table(lines):
    # Locate the standardized-display grid by its header, and PROVE its shape rather than assuming it.
    # ⛔ EVERY '| Language |' header is a CANDIDATE, not just the first.  SCORE.md carries more than one
    # such grid (ceo CEO-174 added the September-10 M/L/V grid ABOVE this one on 2026-09-03), and binding
    # to the first match made this helper refuse rc=2 for EVERY language and EVERY column -- i.e. the one
    # mechanism the ONE LEADERBOARD fact rule tells every runner to call was dead for the whole fleet,
    # while the grid it was meant to protect sat directly below it.  Shape is the identity here, never
    # position: we take the first header that PROVES it is the standardized display, and if none does we
    # report what each candidate was instead, so the refusal names the real problem.
    candidates = [i for i, l in enumerate(lines) if l.startswith("| Language |")]
    if not candidates:
        die("no '| Language |' grid header in %s -- the standardized display is gone or renamed" % SCORE_MD)
    why = []
    hdr = None
    for i in candidates:
        cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
        err = table_shape_error(cells)
        if err is None:
            hdr = i
            break
        why.append("line %d %s" % (i + 1, err))
    if hdr is None:
        die("no '| Language |' grid in %s is the standardized display -- refusing to write into the wrong cell. Candidates: %s"
            % (SCORE_MD, "; ".join(why)))
    cells = [c.strip() for c in lines[hdr].strip().strip("|").split("|")]
    rows = {}
    skipped = {}
    for i in range(hdr + 2, len(lines)):
        if not lines[i].startswith("|"):
            break
        c = [x.strip() for x in lines[i].strip().strip("|").split("|")]
        if len(c) == PROV_COL + 1:
            rows[c[0]] = (i, c)
        elif c and c[0]:
            # ⛔⭐⭐ A ROW OF THE WRONG WIDTH IS *SKIPPED*, NEVER *ABSENT*, AND COLLAPSING THAT DISTINCTION IS
            # THE WHOLE DEFECT. This loop used to have no `else` at all: a mis-shaped row was dropped on the
            # floor in silence, and every reader below then described a table it could not see all of. The
            # cost, measured live (seat07 → hq_P, 2026-09-04): a hand edit appended a cross-confirmation note
            # to the snobol4 row as a SEVENTH cell (dc87ee1c), and that one stray `|` deleted snobol4 from
            # every reader of this table at once -- `write` refused for the entire fleet with "no row for
            # language 'snobol4'", `check` quietly stopped reporting its staleness, and `agree` went on
            # printing GATE PASS over 11 mirrored pairs that held not one of snobol4's cells.
            # ⭐ THE SHAPE WORTH REMEMBERING IS THE MESSAGE, NOT THE MISSING `else`. "No row for language
            # 'snobol4'. Rows present: icon, pascal, ..." is well-formed, confident, and points AWAY from the
            # defect sitting one line above it -- so seat07 read it exactly as written and went looking for a
            # missing entry in an internal registry that does not exist. An instrument that answers a
            # NARROWER question than the one it is thought to answer (here: "is it in my dict?" read as "does
            # it have a row?") is this project's recurring bug, the same shape as `command -v` for an oracle.
            # The header already PROVES its shape via table_shape_error; a row is owed the same courtesy.
            skipped[c[0]] = (i, len(c))
            sys.stderr.write("⚠ SCORE.md line %d: row %r has %d columns, this table has %d -- SKIPPED, so every "
                             "reading below OMITS it. It is malformed, not absent: fix that row's '|' count.\n"
                             % (i + 1, c[0], len(c), PROV_COL + 1))
    return hdr, rows, skipped


def merge_clause(existing, key, value):
    # ⛔⭐ ONE CELL, SEVERAL MEASUREMENTS, AND NO RUNNER MAY CLOBBER ITS SIBLINGS. The `Vendor / package
    # suites` cell holds MORE THAN ONE suite per language -- Icon carries Arizona AND JCON, Prolog carries
    # SWI AND GNU -- so a runner that wrote the whole cell would delete the other suite's number every time
    # it ran, and the two would take turns erasing each other with nobody ever seeing a wrong value sit
    # still long enough to be questioned. Keyed clauses make each runner the author of ITS OWN clause and
    # nothing else. Same mechanism the provenance column uses, which is why it is one function.
    clauses = [c.strip() for c in existing.split(";") if c.strip()] if existing and existing != "—" else []
    new = "%s: %s" % (key, value)
    for i, c in enumerate(clauses):
        # ⛔⭐ MATCH `Key: text` OR `Key text` -- the colon is NOT guaranteed, and assuming it costs a TWIN.
        # Measured live while wiring this (hq_T 2026-09-03): the icon vendor cell already read
        # "Arizona 40/89 · 41/89; JCON 43/81 · 41/81" -- keyed by NAME but with no colon, written by hand
        # months before this helper existed. A colon-only regex missed them, appended "Arizona: 40/89 ..."
        # beside the original, and produced exactly the stale-twin shape the gate on this file exists to
        # prevent -- in the one function whose whole job is to prevent it. A legacy format nobody wrote
        # down is still the format; the migration has to meet it where it is, not where the new code wishes
        # it were. The trailing (?=\s|$) keeps `Arizona` from matching a clause about `ArizonaExtended`.
        if re.match(r"^%s\s*(?::|(?=\s|$))" % re.escape(key), c):
            clauses[i] = new
            return "; ".join(clauses)
    clauses.append(new)
    return "; ".join(clauses)


# ⛔⭐⭐ merge_clause ASSUMES THE CELL IS A ';'-JOINED KEYED CLAUSE LIST AND NEVER CHECKS THAT IT IS.
# The vendor cells are PROSE: their top-level separator is '·', and the ';'s live INSIDE parentheses.
# So every clause boundary merge_clause computes there is fictional, and a key match against a
# fictional clause is a coin flip. Measured by hq_I 2026-09-06, caught by --dry-run and NOT written:
# `write --lang icon --column vendor --suite Arizona` put the new number 80% of the way into the cell
# (offset 1641 of 2052), inside the passage beginning "hq_I's 16:42 lane re-measure is SUPERSEDED by
# this run", and left the cell's LEADING bolded figure `**arizona m3 46/89 · m4 46/89**` untouched --
# while stamping the provenance clause current. One cell, two Arizona numbers, the stale one first,
# both reading as this run's. ⛔ The same cell has it a second time for `IPL`, which nobody reported:
# leading `**ipl run m3 34/60**` against an archived `IPL: compile_pass=615`. One report, two cells.
# ⛔ AND IT IS NOT "THE MATCHER PICKED THE WRONG ONE OF TWO CANDIDATES". The live figure is
# STRUCTURALLY INVISIBLE to it: `**arizona` opens with emphasis and is lower-case, so
# `^Arizona\s*(?::|(?=\s|$))` fails on two counts, and the only thing in that cell it can ever match is
# the archived `Arizona:` clause. The matcher found its sole reachable candidate and that candidate was
# the wrong one -- hq_B's "the icon M cell had become an archive", one column over: a cell carrying its
# own history gives a label-matcher somewhere to land that is not the load-bearing number.
# ⭐⭐ SO THE CURE IS A REFUSAL, NOT A BETTER MATCHER, and that is the part worth keeping. Teaching the
# regex to see `**arizona` would aim it at clause[0] -- which is `**arizona m3 46/89 · m4 46/89**
# graded (124 shipped, 35 never graded — no oracle-cut ref, so they have never been executed against
# one`, a fragment ending mid-sentence, because the ';' that ends it is inside parentheses. Replacing
# that wholesale would strand "`test_icon_arizona_suite.sh`, m3_fail=43 ...) · **jcon ..." as an
# orphan. A better matcher makes the corruption worse and quieter. Which occurrence is load-bearing is
# a judgement about what the prose MEANS, and this helper does not get to make it (RULES.md: a test
# that cannot measure REFUSES with rc=2 -- the same shape as every other guard in this file).
_HEAD_NEAR = re.compile(r"\d+\s*/\s*\d+|PASS=|FAIL=|\bm[34]\b\s*[:=]?\s*\d", re.I)


def measurement_heads(existing, key):
    # Every place this cell STATES A MEASUREMENT for `key`: the bare word, case- and emphasis-blind so
    # `**arizona` and `Arizona:` both count, with a fraction / PASS= / FAIL= / `m3 <n>` within the next
    # 40 characters.
    # ⛔ THE PROXIMITY WINDOW IS WHAT KEEPS THIS FROM BEING NOISE, and it is measured, not guessed: the
    # same icon cell also says "the arizona/jcon pass counts agree exactly" -- a MENTION of the suite,
    # not a reading of it -- and it is excluded because no number follows inside the window. A guard
    # that counted every mention would refuse cells that merge perfectly well today, and a guard with
    # false positives is one that gets switched off.
    # ⛔ THE UNDERSCORE IN THE BOUNDARY IS LOAD-BEARING TOO: without it `test_icon_arizona_suite.sh`
    # scores as an Arizona head (twice), and every icon vendor write refuses over a script name.
    out = []
    for mo in re.finditer(r"(?<![A-Za-z0-9_])" + re.escape(key) + r"(?![A-Za-z0-9_])", existing or "", re.I):
        if _HEAD_NEAR.search((existing or "")[mo.end():mo.end() + 40]):
            out.append(mo.start())
    return out



def suite_readings(cell, key, window=90):
    # The fractions this cell states FOR `key`: every measurement head, then the N/M pairs within its
    # window. Used to ask whether two lines of the board disagree about one suite, which is a different
    # question from whether either is stale.
    out = []
    for off in measurement_heads(cell or "", key):
        seg = (cell or "")[off:off + window]
        out.extend("%s/%s" % (m2.group(1), m2.group(2)) for m2 in re.finditer(r"(\d+)\s*/\s*(\d+)", seg))
    return out


def clauses_with_offsets(existing):
    # merge_clause's own view of the cell, but keeping each clause's offset so a head can be located in
    # it. Same split, same strip, same drop-the-empties -- if this ever disagrees with merge_clause the
    # guard is measuring a different cell than the one being written.
    out, pos = [], 0
    for piece in (existing or "").split(";"):
        s = piece.strip()
        if s:
            off = pos + (len(piece) - len(piece.lstrip()))
            out.append((off, off + len(s), s))
        pos += len(piece) + 1
    return out



def head_blockers(existing, key, off):
    # ⛔⭐ WHY merge_clause CANNOT REACH THE HEAD AT `off` -- the SPECIFIC wall, never a list of the three
    # walls there are. hq_I needed THREE attempts to make one icon reading writable (2026-09-06), and the
    # refusal text is why: it said the head was "bolded, lower-cased, or mid-sentence", which is accurate,
    # enumerates the real causes, and does not say WHICH ONE IS YOURS. Each attempt fixed one wall and hit
    # the next, and the third -- no ';' boundary -- was not in the cure steps at all.
    # ⭐ THE ENUMERATION WAS THE DEFECT, not an incomplete enumeration. A refusal that lists what MIGHT be
    # wrong makes the reader bisect their own cell; one that names what IS wrong is a single edit. Adding a
    # third bullet would have made the list longer and the bisection worse.
    reasons = []
    clauses = clauses_with_offsets(existing)
    holder = next(((cs, ce, ct) for cs, ce, ct in clauses if cs <= off <= ce), None)
    if holder is None:
        reasons.append("it is not inside any ';'-delimited clause at all")
    else:
        lead = existing[holder[0]:off]
        bare = lead.strip(" *`_~")
        if bare:
            # ⛔ THE ONE hq_I'S THIRD ATTEMPT HIT, and the only one whose cure is STRUCTURAL rather than
            # cosmetic: these cells separate their readings with '·', while merge_clause splits on ';'.
            # So a correctly keyed, unbolded reading can still sit INSIDE a neighbouring clause and never
            # be a clause head. The fix is a separator, not a spelling.
            reasons.append("there is no ';' before it -- it sits INSIDE the clause that starts %r, because "
                           "this cell separates readings with '·' while merge_clause splits on ';'. Put a "
                           "';' immediately before it" % (holder[2][:40] + ("..." if len(holder[2]) > 40 else "")))
        elif lead:
            reasons.append("it opens with markdown emphasis (%r) -- unbold the KEY (the number may stay "
                           "bolded)" % lead)
    if existing[off:off + len(key)] != key:
        reasons.append("it is spelled %r where you passed %r -- the match is case-SENSITIVE"
                       % (existing[off:off + len(key)], key))
    return reasons



def _blockers_block(existing, key, heads):
    # ⭐ NAME THE WALL THIS HEAD ACTUALLY HIT. Empty when nothing is diagnosable, so the generic steps below
    # still stand on their own -- a diagnosis that guesses is worse than the enumeration it replaces.
    out = []
    for off, _ctx in heads:
        rs = head_blockers(existing, key, off)
        if rs:
            out.append("  ⛔ head @%d cannot be targeted because %s" % (off, "; and ".join(rs)))
    return ("%s\n" % "\n".join(out)) if out else ""


def suite_target_conflict(existing, key):
    # ("", []) when a --suite write will land on the place this cell states its number; otherwise a
    # named conflict and the heads that prove it. Returns heads as (offset, context) so the refusal can
    # print the offsets -- hq_I asked for exactly that, and an offset is the one thing that makes two
    # occurrences of one word distinguishable in a 2 KB single-line cell.
    if not existing or existing == "—":
        return "", []
    heads = measurement_heads(existing, key)
    if not heads:
        return "", []
    clauses = clauses_with_offsets(existing)
    target = None
    for n, (_s, _e, text) in enumerate(clauses):
        if re.match(r"^%s\s*(?::|(?=\s|$))" % re.escape(key), text):
            target = n
            break

    def ctx(h):
        return (h, existing[max(0, h - 45):h + 75])

    def clause_of(off):
        for n, (s, e, _t) in enumerate(clauses):
            if s <= off <= e:
                return n
        return -1
    if target is None:
        # The cell states a number for this suite and merge_clause will match NONE of it, so it appends
        # -- planting a second reading beside the first. That is the stale twin merge_clause exists to
        # prevent, produced by merge_clause. Silent, and it looks like a successful first write.
        return "unreachable", [ctx(h) for h in heads]
    outside = [h for h in heads if clause_of(h) != target]
    if not outside:
        # ⭐ HEADS INSIDE THE TARGETED CLAUSE ARE NOT A CONFLICT -- the rewrite replaces that whole
        # clause, so they all go together. Measured on the live snobol4 vendor cell, which reads
        # `aisnobol: aisnobol 0/2 m3 · 0/2 m4 SCORED`: the key twice, ten characters apart, one clause.
        # Without this the guard would refuse a cell that merges correctly, which is the false positive
        # that would have made this whole check worthless.
        return "", []
    return "multi", [ctx(h) for h in heads]


def merge_prov(existing, column, stamp):
    # One `<column>: <stamp>` clause per measured column, ';'-joined.  Rewrite ours IN PLACE (never
    # append beside a stale twin -- that is the defect the FACT RULE names by name), keep everyone
    # else's clause untouched, and preserve their order so a diff of this file reads as one cell
    # changing rather than as the whole row churning.
    clauses = [c.strip() for c in existing.split(";") if c.strip()] if existing and existing != "—" else []
    new = "%s: %s" % (column, stamp)
    for i, c in enumerate(clauses):
        if re.match(r"^%s\s*:" % re.escape(column), c):
            clauses[i] = new
            return "; ".join(clauses)
    clauses.append(new)
    return "; ".join(clauses)


def prov_duplicate_keys(prov):
    # ⛔⭐⭐ TWO STAMPS UNDER ONE KEY, AND merge_prov CAN ONLY EVER REWRITE THE FIRST. Flagged by hq_P
    # 2026-09-06 on the live snobol4 row, measured here: 23 provenance clauses carrying NINE duplicated
    # keys (board, entries, Snoflake, CSNOBOL4, port-trace, cross-confirm, gimpel, aisnobol, vendor),
    # every twin stamping an OLDER tree. handoff_status.sh reads a `vendor:` clause and cannot know it is
    # one of two.
    # ⛔ HOW IT GOT THERE IS THE PART THAT GENERALISES, and no script did it: a hand resolution of a
    # concurrent landing (.github d91410c7) kept both sides by pasting the origin-side provenance in as
    # ONE clause value, labelled "concurrent board stamp merged from origin: ...". Because ';' is this
    # column's delimiter and the pasted value contained nine of them, that single clause SPLIT into nine
    # top-level siblings the moment anything read the cell. The resolution looked conservative -- nothing
    # deleted, both sides kept, one honest label -- and it was the append-twin defect the FACT RULE names,
    # arriving one level up from the cell, through the one door no writer watches: a git merge.
    # ⭐ SO THE CHECK IS ON THE DATA, NOT ON THE WRITER. Nothing in this file produced these clauses and no
    # guard inside `write` could have; the only thing that can catch it is reading the cell back and
    # noticing one key answers twice. That is why this is REPORTED by both `write` and `check` rather than
    # refused: a refusal would block every snobol4 write until someone hand-repairs a shared board, which
    # is precisely the hand-surgery-on-a-live-row hq_P declined to do for good reason.
    seen, dups = {}, {}
    for c in [x.strip() for x in (prov or "").split(";") if x.strip()]:
        mo = re.match(r"^([^:]{1,60}?)\s*:", c)
        if not mo:
            continue
        k = mo.group(1)
        if k in seen:
            dups.setdefault(k, [seen[k]]).append(c)
        else:
            seen[k] = c
    return dups


def prov_duplicate_note(lang, prov, indent="  "):
    # One rendered warning, shared by `write` and `check` so the two can never drift into describing the
    # same defect differently -- the whole reason this helper exists is that the board has ONE authority.
    dups = prov_duplicate_keys(prov)
    if not dups:
        return ""
    out = ["%s⚠ %s provenance carries %d DUPLICATED key(s) -- merge_prov rewrites only the FIRST, so the "
           "other(s) can never be updated again and a reader (handoff_status.sh included) may take either:"
           % (indent, lang, len(dups))]
    for k in sorted(dups):
        out.append("%s  `%s:` x%d" % (indent, k, len(dups[k])))
        for c in dups[k]:
            out.append("%s      - %s" % (indent, c[:150]))
    out.append("%s  Keep the NEWEST stamp per key and delete the rest. ⛔ Check for a clause whose VALUE is "
               "itself a ';'-joined provenance list (e.g. one labelled 'merged from origin') -- that is one "
               "clause on the page and N clauses to every reader, and it is how these arrive." % indent)
    return "\n".join(out)


def cell_prose_loss(before, new):
    # ⛔⭐ THE DEFECT THIS GUARDS: a wholesale cell overwrite silently drops whatever hand-written prose it
    # never modelled, WITH THE MEASURED NUMBERS UNCHANGED -- so nothing about the diff looks wrong (task
    # score-md-runners-rewrite-a-cell-in-place-and-silently-discard-the-prose-they-never-modelled, minted
    # off hq_B's 2026-09-03 ICN4 finding; repaired by hand in .github 46ff295c). That repair is the fixture:
    # `before` carried "... rc=0). Re-confirmed on a newer tree and identical across two consecutive runs
    # (before and after a rebase onto origin), as the control arm for the rung-11 LCO landing: the shared
    # alternative-trampoline change in emit.cpp moved nothing here." and the runner's own `new` carried only
    # the measurement up to "rc=0)." -- the whole trailing sentence had no home in the new text.
    # ⛔ MATCHED BY CONTENT, NEVER BY POSITION OR EXACT PREFIX. The SAME repair shows why: the runner's own
    # boilerplate drifted in punctuation between the two captures ("SKIP=0 · MISSING=0" became "SKIP=0
    # MISSING=0"; a comma moved beside the citation backtick) with no human involved -- an exact-prefix or
    # exact-substring check would have flagged that reformatting exactly as hard as the real sentence loss,
    # which is how a helper like this earns a "too noisy, ignore it" reputation and stops getting listened to.
    # So a chunk of `before` only counts as LOST when most of it cannot be found, in one contiguous run,
    # anywhere in `new` -- reformatting leaves a chunk overwhelmingly intact; a dropped sentence leaves none
    # of it.
    if not before or before == "—" or before == new:
        return []
    chunks = [c.strip() for c in re.split(r'(?<=[.!?])\s+(?=[A-Z0-9⚠⛔⭐✅])', before) if c.strip()]
    lost = []
    for chunk in chunks:
        if chunk in new:
            continue
        # ⛔ SUM every matching block, never just the longest one. Two independent formatting nips close
        # together (a dropped '·', a comma that moved) fragment one legitimate reformat into three short
        # contiguous pieces that individually clear nowhere near a single-block threshold, even though
        # together they cover nearly all of `chunk` -- measured against the real 46ff295c drift, which
        # carries exactly two such nips in one sentence.
        sm = difflib.SequenceMatcher(None, new, chunk, autojunk=False)
        matched = sum(blk.size for blk in sm.get_matching_blocks())
        coverage = (matched / len(chunk)) if chunk else 1.0
        if coverage < 0.6:
            lost.append(chunk)
    return lost


# ⛔⭐ "unknown-seat" DEFEATED THE MEASURER GUARD BELOW BY BEING NON-EMPTY. Every runner spelled its default
# `${S4E_SEAT:-}`, so a board run from a plain shell (no hook exporting S4E_SEAT) satisfied the
# "an unattributed row is a claim with nobody behind it" check with a string carrying exactly zero attribution
# -- measured live on this root's own snobol4 board row, 2026-09-03 22:45. ⭐ The identity was never unknown:
# it is a FACT ON DISK, the same root-path map `s4e_msg.sh:91-99` reads, so the cure is to DERIVE it rather
# than to refuse harder. Refusal is kept for the case the map cannot answer -- an unrecognised root.
_PLACEHOLDER_MEASURERS = ("unknown-seat", "unknown", "unknown-hq", "-", "?")
def derive_measurer():
    root = os.path.abspath(S4E).rstrip("/")
    fixed = {"/home/claude": "ceo", "/home/claude_C": "hq_C", "/home/claude_P": "hq_P",
             "/home/claude_B": "hq_B", "/home/claude_T": "hq_T", "/home/claude_U": "hq_U",
             "/home/claude_S": "hq_S", "/home/claude_I": "hq_I", "/home/claude_R": "hq_R", "/home/claude_V": "hq_V", "/home/claude_icon": "hq_icon", "/home/claude_prolog": "hq_prolog", "/home/claude_raku": "hq_raku", "/home/claude_pascal": "hq_pascal", "/home/claude_snocone": "hq_snocone", "/home/claude_snobol4": "hq_snobol4", "/home/claude_templates": "hq_templates", "/home/claude_runtime": "hq_runtime", "/home/claude_collector": "hq_collector", "/home/claude_zetas": "hq_zetas", "/home/claude_dotnet": "hq_dotnet", "/home/claude_jvm": "hq_jvm", "/home/claude_ceo": "ceo", "/home/claude_cto": "cto", "/home/claude_coo": "coo", "/home/claude_cfo": "cfo"}
    if root in fixed:
        return fixed[root]
    m = re.match(r"^/home/claude([0-9]{1,2})$", root)
    if m:
        return "seat%02d" % int(m.group(1))
    return ""


# ⛔⭐⭐ THE ROSTER IS ASKED AT THE WRITE PATH, BECAUSE THE MITIGATION WAS A SEAT'S MEMORY (hq_I 2026-09-13, row
# instruments-a-suite-runner-writes-a-score-md-row-for-every-seat-while-one-runner-allows-only-the-coo).  MODE NONET
# cuts ONE RUNNER: every seat but the one MODE line 2 names grades with the per-group development aids and writes no
# SCORE.md row.  This helper predates that lane cut and faithfully obeys the older FACT RULE ("any run of a test suite
# by any session will update the ONE LEADERBOARD"), so NOBODY MADE A MISTAKE -- two rules held at once and the older
# one is on the code path.  ⛔ THE FAILURE WAS NOT A SEAT WRITING THE ROW DELIBERATELY, IT WAS VERSION-CONTROL HYGIENE
# PICKING IT UP AS COLLATERAL: hq_I declined a rank raise on the grounds that it watched the file at every push, and
# within the hour a pull-with-rebase refused on the dirty SCORE.md, an ordinary stage-everything swept the row in, and
# a row only the one runner may write sat on origin for about four minutes -- a TRUE number with the wrong provenance,
# indistinguishable from the runner's own.  The rule was never evaluated and skipped; it simply was not on the path a
# seat was standing in.  ⭐ SO THE NO-OP IS WORTH MORE THAN THE ANNOUNCEMENT FOR THIS CLASS, which is hq_I's own
# correction and the reason the cure is here and not in a discard ritual: if the file is never modified, a
# stage-everything has nothing to sweep and the whole class is gone, whereas a loud line still leaves a dirty file in
# the tree waiting for the next rebase.  The announcement is kept anyway, because a silent no-op and a silent success
# look identical, which is the trap one layer up.
# ⛔ THE ROSTER IS READ LIVE AND NEVER HARD-CODED.  A hard-coded population never announces what it left out: this
# root's own digest gate carried a literal ROOTS array, was green for months, and that greenness was about nineteen
# other files while two seats' digests went unread; the queue's owner column was 44 rows behind this very lane cut.
# So the seat who may write is lifted out of MODE line 2 at the moment of the write, and a MODE that names no ONE
# RUNNER cuts no writer, so nothing is refused.
MODE_SEAT_RE = r"(?:ceo|cto|coo|cfo|hq_[A-Za-z0-9]+)"


def mode_file():
    f = os.environ.get("S4E_MODE_FILE", "").strip()
    if f:
        return f
    root = (os.environ.get("S4E_POSTOFFICE", "").strip() or os.environ.get("S4E_POST", "").strip()
            or "/home/resources/postoffice")
    return os.path.join(root, "MODE")


def lane_writer_seat(lang):
    """The seat MODE's `LANES:` line names for this board's LANGUAGE, plus the provenance -- the same line
    lib_one_runner.sh:one_runner_who reads (CEO-775, NO CENTRAL RUNNER: one runner per language; rebus=cfo today).
    Returns (seat, why); seat is None with a reason when the line is absent or does not name this language.
    (coo 2026-09-16, ceo CEO-786; row instruments-every-board-write-prints-one-runner-not-determined-under-no-central-
    runner-read-the-lanes-line: this file used to look only for THE ONE RUNNER on line 2, find none under CEO-775,
    print 'the older not-determined notice ... this row is yours to discard' to the very seat that OWNS the row, and write.)"""
    p = mode_file()
    try:
        with open(p) as fh:
            lines = fh.read().split("\n")
    except Exception as e:
        return None, "could not read %s (%s)" % (p, e.__class__.__name__)
    lanes = next((l[len("LANES:"):] for l in lines if l.startswith("LANES:")), None)
    if lanes is None:
        return None, "%s carries no LANES: line" % p
    table = {}
    for tok in lanes.split():
        if "=" in tok:
            k, v = tok.split("=", 1)
            table[k.strip().lower()] = v.strip()
    seat = table.get((lang or "").strip().lower())
    if not seat:
        return None, "the LANES: line of %s names no seat for language %r (it names: %s)" % (p, lang, ", ".join(sorted(table)) or "nothing")
    return seat, "LANES: line of %s (%s=%s)" % (p, lang, seat)


def board_writer_seat():
    """The seat MODE line 2 names as THE ONE RUNNER, plus the provenance of that answer.

    ⛔ SINCE CEO-775 (Lon 2026-09-16, NO CENTRAL RUNNER) MODE line 2 names no THE ONE RUNNER on purpose, so this returns
    None and the write path falls back to the 2026-09-03 FACT RULE: every language HQ runs its own suites and rewrites its
    own rows. The clause stays for any future mode that cuts one writer again.

    Returns (seat, why).  seat is None when the question CANNOT BE ANSWERED -- unreadable file, no line 2, no ONE
    RUNNER clause, or a clause naming no seat -- and `why` then says which of those it was.  ⛔ A None is never read
    as "nobody may write": an instrument that cannot measure must not be allowed to print an answer, and the honest
    fallback here is the older FACT RULE (write the row, say the roster could not be read), never a silent refusal
    that would make an unreadable MODE file look exactly like a seat correctly declining.
    """
    p = mode_file()
    try:
        with open(p) as fh:
            lines = fh.read().split("\n")
    except Exception as e:
        return None, "could not read %s (%s)" % (p, e.__class__.__name__)
    if len(lines) < 2 or not lines[1].strip():
        return None, "%s carries no line 2, which is where the lanes are cut" % p
    l2 = lines[1]
    m = re.search(r"THE ONE RUNNER", l2)
    if not m:
        return None, "line 2 of %s names no THE ONE RUNNER, so this mode cuts no single board writer" % p
    seats = re.findall(r"(?:^|[\s;,.(])(%s)\b" % MODE_SEAT_RE, l2[:m.start()])
    if not seats:
        return None, "line 2 of %s says THE ONE RUNNER and names no seat before it" % p
    return seats[-1], "named on line 2 of %s" % p


def score_md_is_the_shared_board():
    """Is the file about to be written THE leaderboard every seat reads, or a scratch copy?

    ⛔⭐ WHAT MAKES A WRITE A LEADERBOARD WRITE IS THE FILE IT LANDS IN, NOT THE ENTRY POINT -- the same rule the coo
    landed for boards (CEO-547 part 1: what makes a run a board is the population it grades).  The shared board is a
    tracked file in a clone with an `origin`, so every other seat meets it; a gate's mktemp .github copy is read by
    nobody, publishes nothing, and must never be refused, or the gates that prove this writer could not run at all.
    """
    d = os.path.dirname(os.path.abspath(SCORE_MD))
    try:
        top = subprocess.run(["git", "-C", d, "rev-parse", "--show-toplevel"], capture_output=True, text=True, timeout=30)
        if top.returncode != 0:
            return False
        url = subprocess.run(["git", "-C", d, "remote", "get-url", "origin"], capture_output=True, text=True, timeout=30)
        return url.returncode == 0 and bool(url.stdout.strip())
    except Exception:
        return False


def one_runner_declines(measurer, what, lang=None):
    """The announcement to print INSTEAD of writing `what`, or None to go ahead and write it.

    ⛔⭐ THE RUN AND THE WRITE ARE TWO CONSENTS, NOT ONE (ceo CEO-961, 2026-09-20, on the coo's report; row
    one-runner-override-gates-the-run-and-the-leaderboard-write-needs-its-own-consent).  Until now S4E_ONE_RUNNER_OVERRIDE
    opened BOTH doors, so there was NO WAY TO SAY "run the arm and publish nothing": a runner driven as a CONTROL ARM --
    the shape RULES.md § SHARED-NODE VERDICT SCOPE requires of every landing on another seat's frontend -- published a
    leaderboard row AS A SIDE EFFECT OF BEING USED AS A MEASUREMENT.  Measured: the coo's gimpel control arm of COO-115
    wrote snobol4/vendor on the ceo's lane and the row had to be reverted BY HAND.  That is a defect in the instrument,
    not in the seat's discipline, so the doors are split here: S4E_ONE_RUNNER_OVERRIDE admits THE RUN (lib_one_runner.sh
    keeps it, unchanged) and says NOTHING about publication; a leaderboard write needs ITS OWN loud recorded consent,
    S4E_SCORE_WRITE="why", or the seat MODE's LANES: line names for this board's language.  ⭐ A RUNNER DRIVEN AS A
    CONTROL ARM DEFAULTS TO WRITE NOTHING, which is the only default under which forgetting is safe.
    ⛔⭐ AND THE BUS'S COMPUTED `done` IS NO LONGER A DOOR EITHER (ceo CEO-997 ONE, 2026-09-20, on this writer's own
    QA-2).  `S4E_DONE_WHEN_RUN=1` opened the write exactly as the override did -- a DONE-WHEN that runs a board the seat
    does not own published a row AS A SIDE EFFECT OF BEING USED AS A MEASUREMENT, which is CEO-961's sentence with a
    different variable.  It was wider than the bus: util_queue_visibility_census.py runs EVERY baton's DONE-WHEN body
    with that variable set, so the coo's own hygiene census was a fleet-wide publish button.  ⭐ CLOSING IT COSTS THE
    LEGITIMATE CASE NOTHING, which is the ruling's own argument and is graded: the LANE OWNER's `done` writes either
    way, because the lane check above passes before this door is ever read; only the control-arm case is shut.  The RUN
    door in lib_one_runner.sh keeps that variable, unchanged -- the two guards govern two consents and are MEANT to
    differ here, exactly as they already differ about S4E_ONE_RUNNER_OVERRIDE.  This NARROWS hq_B's standing arm 6 in
    test_gate_score_row_only_the_one_runner_writes.sh (wired 2026-09-13 to keep one run per closure usable) rather than
    deleting it; that gate now grades both directions.  A --dry-run writes nothing, so it is previewed, never refused.
    """
    if not score_md_is_the_shared_board():
        return None
    nw = os.environ.get("S4E_SCORE_NO_WRITE", "").strip()
    # ⛔⭐ A FIXTURE RUN PUBLISHES NOTHING, BY CONSTRUCTION (coo 2026-09-28, COO-216): CEO-1342 made the coo the lane owner of every
    # language, so the lane check below now ADMITS every run the coo makes -- including a blocking-set gate driving a real package
    # runner over a two-program scratch suite (test_gate_package_runners_read_each_units_declared_compile_args.sh arm P5 over
    # test_snobol4_csnobol4_suite.sh, S4E_PROGRESS_DB scratch, .github real). MEASURED: the 09-27 19:03 pass left SUITES.tsv's
    # csnobol4 row reading 1 of 2 on c724bb9e1 with zero progress rows behind it, and it reached origin. CEO-547's definition has
    # two halves that hold together -- publishes no row, writes no score -- so a run that declares itself a fixture
    # (S4E_ONE_RUNNER_FIXTURE) or sends its progress rows to a scratch table (S4E_PROGRESS_DB off the live record) writes no score
    # cell, whatever seat it runs as. The lane owner's real pass sets neither and writes as before.
    fx = os.environ.get("S4E_ONE_RUNNER_FIXTURE", "").strip()
    if not nw and fx:
        nw = "a runner invoked as a gate fixture publishes nothing (S4E_ONE_RUNNER_FIXTURE): %s" % fx
    pdb = os.environ.get("S4E_PROGRESS_DB", "").strip()
    if not nw and pdb and os.path.realpath(pdb) != os.path.realpath("/home/resources/progress/results.tsv"):
        nw = ("this run appends its progress rows to a scratch table (%s), not the live record -- a run that publishes no row "
              "writes no score (CEO-547, both halves)" % pdb)
    if nw:
        # ⛔⭐ A GATE NEVER PUBLISHES A LEADERBOARD ROW (ceo CEO-997 TWO, 2026-09-20, on the coo's report): a gate is an
        # INVARIANT CHECK, a board is a MEASUREMENT OF RECORD, and an invariant check that writes to the record makes the
        # record a function of who ran which gate today.  Until this door existed there was no way for a caller to say it:
        # the lane owner's own runs write by lane ownership, so three gates that invoke test_smoke_raku.sh published
        # raku/floor every time hq_raku ran them -- and the publication was INVISIBLE because the reading did not change,
        # which is why it survived.  This door beats every other, INCLUDING lane ownership, and is loud and recorded.
        return ("⚠ SCORE.md NOT UPDATED — this run publishes nothing by its caller's own declaration (S4E_SCORE_NO_WRITE): %s\n"
                "  NOTHING WAS WRITTEN and the file is untouched. The measurement below stands as this run's own board "
                "line -- %s -- and the record moves when a BOARD measures it, never when a gate runs.\n"
                "  If this run IS the measurement of record, it is not a gate: drop the declaration." % (nw, what))
    # ⛔⭐ THE LANE OWNER FIRST (CEO-775/786): the seat MODE's LANES: line names for this board's language is the writer;
    # a mode that cuts ONE runner for every board (THE ONE RUNNER on line 2) is read only when no LANES: line answers.
    writer, why = lane_writer_seat(lang) if lang else (None, "no language given for this write")
    if writer is None:
        writer, why2 = board_writer_seat()
        why = "%s; %s" % (why, why2)
    if writer is None:
        print("⚠ LANE OWNER NOT DETERMINED: %s -- writing %s as the 2026-09-03 FACT RULE requires (any suite run "
              "updates the leaderboard); the seat that measured it stays the writer of record." % (why, what))
        return None
    if (measurer or "").strip() == writer:
        print("  lane owner: %s writes %s rows (%s)" % (writer, lang or "these", why))
        return None
    sw = os.environ.get("S4E_SCORE_WRITE", "").strip()
    if sw:
        print("⚠ LEADERBOARD WRITE CONSENT by %s (%s is the lane owner, %s): %s" % (measurer, writer, why, sw))
        return None
    ov = os.environ.get("S4E_ONE_RUNNER_OVERRIDE", "").strip()
    if ov:
        # ⛔ THE OVERRIDE ADMITTED THE RUN AND SAYS NOTHING ABOUT THE WRITE (CEO-961). Named, so the seat that set it
        # reads WHY its row did not land instead of meeting a bare refusal it thinks it already answered.
        return ("⚠ SCORE.md NOT UPDATED — S4E_ONE_RUNNER_OVERRIDE admitted THE RUN, not the WRITE (ceo CEO-961): seat %s is "
                "not %s, the lane owner for this board (%s), and a runner driven as a CONTROL ARM publishes nothing by "
                "default. NOTHING WAS WRITTEN and the file is untouched, deliberately: a row left in your working tree is "
                "swept in by the next stage-everything.\n"
                "  The override you set was: %s\n"
                "  The measurement below stands as your own board line -- %s -- and lands when the lane owner's next pass "
                "measures it. If you MEANT to publish, say so separately and loudly: S4E_SCORE_WRITE=\"why\"."
                % (measurer or "?", writer, why, ov, what))
    return ("⚠ SCORE.md NOT UPDATED — seat %s is not %s, the lane owner for this board (%s), and under ONE RUNNER PER LANGUAGE, "
            "ONE BOARD only that seat writes its rows. NOTHING WAS WRITTEN and the file is untouched, deliberately: a row "
            "left in your working tree is swept in by the next stage-everything.\n"
            "  The measurement below stands as your own board line -- %s -- and lands when the one runner's next "
            "pass measures it. THE ONE DOOR, loud and recorded: S4E_SCORE_WRITE=\"why\" writes the row and prints the "
            "reason. S4E_ONE_RUNNER_OVERRIDE is NOT one (CEO-961 -- it admits the board RUN and leaves publication to "
            "its own consent) and neither is the bus's computed `done` (CEO-997 -- a DONE-WHEN that runs a board its "
            "seat does not own publishes as a side effect of being used as a measurement; the lane owner's own `done` "
            "writes here regardless, through the lane check above)."
            % (measurer or "?", writer, why, what))


def write_grid_direct(a):
    gkey = GRID_DIRECT[a.column]
    text = a.text.strip()
    if "|" in text or "|" in (a.measurer or ""):
        die("a '|' in the cell text would silently split the markdown row into the wrong columns -- rephrase it")
    if ";" in text:
        text = text.replace(";", "·")
    if not re.search(r"\d+\s*/\s*\d+", text):
        die("--text for the grid %s column carries no N/M fraction (%r); the ladder cell states PASS p/t over the graded population" % (gkey, text))
    if "\n" in text:
        die("--text spans lines; a markdown table row is one line")
    if os.path.abspath(SCORE_MD) == os.path.abspath(os.path.join(S4E, ".github", "SCORE.md")):
        dirty = tree_is_dirty()
        if dirty:
            print("⚠ SCORE.md ROW SKIPPED — %s %s uncommitted; this run measured a tree nobody else can check out."
                  % (", ".join(dirty), "has" if len(dirty) == 1 else "have"))
            return 0
        unpushed = tree_is_unpushed()
        if unpushed:
            print("⚠ SCORE.md ROW SKIPPED — %s %s on a local commit no remote branch contains; this run measured a tree nobody else can check out."
                  % (", ".join(unpushed), "is" if len(unpushed) == 1 else "are"))
            return 0
    lines = open(SCORE_MD, encoding="utf-8").read().split("\n")
    _gh, grows, gskip = find_grid(lines)
    if a.lang in gskip:
        _gl, _gn = gskip[a.lang]
        die("the September-10 grid row for %r is MALFORMED, NOT ABSENT (line %d has %d columns, the grid has %d)" % (a.lang, _gl + 1, _gn, GRID_NCOLS))
    if a.lang not in grows:
        die("no row for language %r in the September-10 grid. Rows present: %s" % (a.lang, ", ".join(sorted(grows))))
    gi = GRID_COLUMNS[gkey][0]
    gbefore = grows[a.lang][gi]
    gbare = re.sub(r"\s*" + GRID_STAMP_RE + r"\s*$", "", gbefore).strip()
    gchunks = [c for c in re.split(r'(?<=[.!?])\s+(?=[A-Z0-9⚠⛔⭐✅])', gbare) if c.strip()]
    if len(gchunks) > 1:
        die("grid %s for %s carries %d sentences no runner models -- a person wrote them; fold what is still true into --text or hand-edit the cell:\n%s"
            % (gkey, a.lang, len(gchunks), "\n".join("  - %s" % c[:160] for c in gchunks)))
    gnew = (text + " " + GRID_STAMP % (time.strftime("%Y-%m-%d"), a.measurer or derive_measurer() or "unknown")).strip()
    if a.dry_run:
        print("WOULD REWRITE grid %s for %s\n  was: %s\n  now: %s" % (gkey, a.lang, gbefore, gnew))
        return 0
    done, _gline_no = False, 0
    for gl, gline in enumerate(lines):
        if gline.startswith("| %s |" % a.lang):
            gc = [x.strip() for x in gline.strip().strip("|").split("|")]
            if len(gc) == GRID_NCOLS and gc[0] == a.lang:
                gc[gi] = gnew
                lines[gl] = "| " + " | ".join(gc) + " |"
                done = True
                _gline_no = gl + 1
                print("SCORE.md: grid %s for %s rewritten in place (line %d)\n  was: %s\n  now: %s" % (gkey, a.lang, gl + 1, gbefore, gnew))
                break
    if not done:
        die("internal: find_grid saw a %s row but no line matched it" % a.lang)
    _un = unchanged_reading_note("grid %s" % gkey, a.lang, gbefore, gnew, "", "", _gline_no)
    if _un:
        print(_un)
    lines = mark_grid_stamp(lines)
    _write_score_md(lines)
    print("⛔ NOT DONE UNTIL PUSHED: commit .github/SCORE.md with the landing that carried this measurement.")
    return 0


# ⭐⭐ THE SUITE-TABLE SYNC (ceo CEO-363, 2026-09-06; row
# suite-table-row-rewritten-by-the-runner-through-util-suite-banner-set).  SCORE.md's grid and
# .github/SUITES.tsv are TWO records of one measurement, and only SUITES.tsv feeds the banner and Lon's
# read.  Three fixers in one hour wrote the grid cell here and left SUITES.tsv untouched (hq_I: IPL, Jcon;
# hq_U: IcnRungs; hq_T: AIS), so the ceo was setting rows BY HAND off flip lines -- a second record kept by
# discipline is a record kept by nobody.  A write that moves a V (vendor) or M (rungs board) cell now
# moves the suite row in the SAME call, or REFUSES naming the row.
# ⛔ IT NEVER GUESSES A FRACTION.  Auto-extraction fires only when the runner's own --text carries EXACTLY
# ONE N/M; two fractions or none is a REFUSAL, not a pick, because picking the wrong one writes a wrong
# number under a correct-looking provenance stamp -- strictly worse than the hand-editing it replaces.
# --suite-pass/--suite-total say it outright; --suite-key names a row auto-resolution cannot reach;
# --no-suite-sync is the labelled escape for a write that genuinely has no suite row.
# ⛔⭐⭐ THE SUITE TABLE IS ONE FILE (Lon 2026-10-09 15:2x CDT, in-chat to the coo, verbatim: "You choose to put the one single data location to be
# spread across all root via GitHub instead of choosing one file in /home/resources. That was stupid."): every seat root reads and writes
# /home/resources/progress/SUITES.tsv beside the progress database. A scratch root (a fixture's S4E_HOME, never /home/claude_<seat>) keeps its
# scratch .github/SUITES.tsv, so a fixture that redirects the root without naming S4E_SUITES_TSV still never writes the real record.
REAL_SUITES_TSV = "/home/resources/progress/SUITES.tsv"
def _root_suites_tsv():
    if re.fullmatch(r"/home/claude_[A-Za-z0-9_]+", os.path.realpath(S4E)):
        return REAL_SUITES_TSV
    return os.path.join(S4E, ".github", "SUITES.tsv")
SUITES_TSV = os.environ.get("S4E_SUITES_TSV") or _root_suites_tsv()
# ⛔⭐ ONE WRITER AT A TIME ON THE SUITE TABLE (coo 2026-09-25, hq_pascal's report: parallel runners of one lane lost each other's
# SCORE.md line -- SUITES.tsv read fpc 158/181 while SCORE.md's FPC line read 156, twice, the last writer putting back what it had
# read). A write holds an exclusive flock on SUITES.tsv.lock beside the record from before its first read of SCORE.md or SUITES.tsv until the
# process exits, and hands S4E_SUITE_TABLE_LOCKED to the util_suite_banner.py --set it runs, which takes the same lock otherwise.
# A lock not granted within S4E_SUITE_TABLE_LOCK_S (120 s) refuses rc 2 -- never a hang. No SUITES.tsv (a fixture) means no lock.
_SUITE_TABLE_LOCK_FD = None
def _suite_table_lock():
    global _SUITE_TABLE_LOCK_FD
    if os.environ.get("S4E_SUITE_TABLE_LOCKED") or not os.path.exists(SUITES_TSV):
        return
    import fcntl
    fd = os.open(SUITES_TSV + ".lock", os.O_RDWR | os.O_CREAT, 0o664)
    limit = time.monotonic() + float(os.environ.get("S4E_SUITE_TABLE_LOCK_S", "120"))
    while True:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB); break
        except BlockingIOError:
            if time.monotonic() > limit:
                die("another writer has held the suite-table lock on %s.lock past %s s -- NOTHING WAS WRITTEN; re-run when it finishes"
                    % (SUITES_TSV, os.environ.get("S4E_SUITE_TABLE_LOCK_S", "120")))
            time.sleep(0.05)
    _SUITE_TABLE_LOCK_FD = fd
    os.environ["S4E_SUITE_TABLE_LOCKED"] = str(os.getpid())
SUITE_BANNER = os.path.join(S4E, ".github", "scripts", "util_suite_banner.py")
SUITE_SYNC_ROW = "suite-table-row-rewritten-by-the-runner-through-util-suite-banner-set"
# ⭐⭐ A COLUMN THAT IS A SUITE-TABLE ROW AND NO GRID CELL (Lon 2026-09-23 17:2x, in-chat to the ceo, verbatim: "You messed up and
# forgot to have the benchmarks in the test suite grid." -- "The reason to force a benchmark to also be a test is to guarantee it is
# not vacuous."; CEO-1221; row instruments-benchmarks-enter-the-suite-grid-one-row-per-language-graded-by-ref-through-the-three-
# angle-harness, the coo). Each language's benchmark programs, graded as tests -- a program passes when it prints its REF under all
# three angles in both modes -- are a row of THE SUITE TABLE. They have NO cell of their own in SCORE.md's grids, and they must not
# borrow one: the September-10 grid's B cell (`--column bench`) is the TIMING reading and waits for the quiet-box re-run (CEO-1219),
# and V feeds the PROGRESS percent, so a correctness fraction in either would give one cell two meanings. The key resolves from
# --lang alone: the ONE SUITES.tsv row of that language whose key ends in the suffix. The key IS the progress table's suite name,
# so the CEO-750 cross-check reads `<lang>-bench-ref` rows and no key-to-DB map anywhere needs an entry.
# ⭐ AND THE DEMO ROWS (Lon 2026-09-27: "all demos are also benchmarks. They are work-horse benchmarks."; ceo CEO-1312/1313; coo COO-206): a
# <lang>-demos row is written by test_demos_suite.sh <lang> through this same path -- no grid cell, the key the progress table's suite name.
SUITE_ONLY = {"bench-ref": "-bench-ref", "demos": "-demos"}
SUITE_SYNC_COLUMNS = ("board", "vendor") + tuple(SUITE_ONLY)


def suite_tree_stamp():
    """SUITES.tsv's tree column is a BARE SCRIP short hash (e68e35fd4), not tree_stamp()'s markdown pair."""
    h = git("SCRIP", "rev-parse", "--short", "HEAD") or "unknown"
    return h + ("-DIRTY" if git("SCRIP", "status", "--porcelain") else "")


def suites_rows():
    if not os.path.exists(SUITES_TSV):
        return [], "no SUITES.tsv at %s" % SUITES_TSV
    rows, head = [], None
    for ln in open(SUITES_TSV, encoding="utf-8").read().split("\n"):
        if not ln.strip() or ln.startswith("#"):
            continue
        f = ln.split("\t")
        if head is None:
            head = f
            continue
        rows.append(dict(zip(head, f)))
    return rows, None


def resolve_suite_key(lang, column, suite, explicit):
    """Return (key, None) or (None, why-this-cannot-be-resolved).  Never a guess."""
    if explicit:
        return explicit, None
    rows, err = suites_rows()
    if err:
        return None, err
    if column == "board":
        hits = [r["key"] for r in rows if r.get("lang") == lang and r["key"].endswith("-rungs")]
        if len(hits) == 1:
            return hits[0], None
        return None, ("--column board --lang %s matches %d rungs rows in SUITES.tsv (%s); name it with --suite-key"
                      % (lang, len(hits), ", ".join(hits) or "none"))
    if column in SUITE_ONLY:
        hits = [r["key"] for r in rows if r.get("lang") == lang and r["key"].endswith(SUITE_ONLY[column])]
        if len(hits) == 1:
            return hits[0], None
        return None, ("--column %s --lang %s matches %d rows whose key ends in %s in SUITES.tsv (%s)"
                      % (column, lang, len(hits), SUITE_ONLY[column], ", ".join(hits) or "none"))
    if not suite:
        return None, "--column vendor writes ONE measurement inside a shared cell, so the suite row cannot be inferred -- pass --suite (or --suite-key)"
    want = suite.strip().lower()
    hits = [r["key"] for r in rows if r["key"].lower() == want or r.get("nick", "").lower() == want]
    if len(hits) == 1:
        return hits[0], None
    return None, ("--suite %r matches %d rows in SUITES.tsv (%s); name it with --suite-key"
                  % (suite, len(hits), ", ".join(hits) or "none"))


BOARD_LINE_ANY_RX = re.compile(r"(?m)^.*?\b[A-Z0-9_]*SUITE_BOARD\b.*$")


def board_field_by_name(line, name):
    """lib_board_line.sh's board_field, in python: a WORD-BOUNDED NAME=VALUE read.  `all_n` never matches
    inside `m3_all_n`, and an ABSENT field is None, never the empty string treated as 0."""
    m = re.search(r"(?:^|\s)%s=(\S+)" % re.escape(name), line)
    return m.group(1) if m else None


def board_line_fraction(text):
    """(pass, total, None) read BY NAME off a canonical SUITE_BOARD line, or (None, None, why|None).

    why is None when the text simply carries no board line at all (the caller's own message is the right one);
    it is a sentence when a board line IS present but cannot be read -- a reader must not have to guess which
    of those two they are looking at."""
    lines = [l for l in BOARD_LINE_ANY_RX.findall(text or "") if l.strip()]
    if not lines:
        return None, None, None
    # ⛔ A SHARD BOARD IS NOT THE SUITE: its total= is this shard's entries, so its fraction is a fact about a
    # quarter of a population and the suite row is about all of it.  Named rather than skipped.
    # ⛔ AND A PARTITION BOARD IS NOT THE SUITE (CEO-1676 row (a)): `run --partition core|shell:F|chunk:NN` grades a stored subset and its
    # line carries partition=NAME; the suite row is assembled from the per-program readings (row (b)), never from one subset's fraction.
    parts = [l for l in lines if board_field_by_name(l, "partition")]
    shards = [l for l in lines if board_field_by_name(l, "shard")]
    whole = [l for l in lines if l not in shards and l not in parts]
    if not whole and parts:
        return None, None, ("the --text's only SUITE_BOARD line carries partition=%s -- a PARTITION board is a stored subset, not the "
                            "suite (CEO-1676), so its fraction cannot be the suite row's -- the row is assembled from the per-program "
                            "readings (util_score_row.py from-progress)" % board_field_by_name(parts[0], "partition"))
    if not whole:
        return None, None, ("the --text's only SUITE_BOARD line carries shard=%s -- a SHARD board is not the suite "
                            "(its total= is that shard's entries), so its fraction cannot be the suite row's -- "
                            "hand the combined board, or pass --suite-pass/--suite-total"
                            % board_field_by_name(shards[0], "shard"))
    pairs, half = set(), []
    for l in whole:
        p, t = board_field_by_name(l, "all_pass"), board_field_by_name(l, "all_n")
        if p is not None and t is not None:
            pairs.add((p, t))
        elif p is not None or t is not None:
            half.append("all_pass=%s all_n=%s" % (p, t))
    if len(pairs) == 1:
        return sorted(pairs)[0][0], sorted(pairs)[0][1], None
    if len(pairs) > 1:
        return None, None, ("the --text carries %d SUITE_BOARD lines whose all_pass/all_n DISAGREE (%s), so which one the "
                            "suite row means is a judgement, not a reading -- pass --suite-pass/--suite-total"
                            % (len(pairs), ", ".join("%s/%s" % p for p in sorted(pairs))))
    if half:
        return None, None, ("the --text's SUITE_BOARD line carries only HALF the pair (%s); a fraction needs both fields "
                            "read by name -- pass --suite-pass/--suite-total" % half[0])
    return None, None, ("the --text's SUITE_BOARD line carries neither all_pass= nor all_n=, so the suite row's pass/total "
                        "cannot be read from it -- pass --suite-pass/--suite-total")


def fraction_from_text(text, p_override, t_override):
    """(pass, total, None) or (None, None, why).  EXACTLY ONE N/M or it refuses -- see the banner above."""
    if p_override is not None and t_override is not None:
        return str(p_override), str(t_override), None
    if (p_override is None) != (t_override is None):
        return None, None, "--suite-pass and --suite-total are a pair; give both or neither"
    # ⛔ A SHARD BOARD IS NOT THE SUITE, AND ITS `shard=k/N` LOOKS EXACTLY LIKE A FRACTION (coo 2026-09-20).
    # `--shard k/N` makes corpus_suite_harness.py print `shard=k/N` beside a `total=` that is THIS SHARD's
    # entries, so a shard line handed as --text used to read as pass=k total=N and write a real number under a
    # provenance stamp saying it was measured.  The token is blanked BEFORE the scan -- never read, never
    # silently preferred -- and a text whose ONLY board line is a shard line refuses by name below.
    scan = re.sub(r"(?:^|\s)shard=\d+\s*/\s*\d+", " ", text or "")
    found = re.findall(r"(?<![\d/])(\d+)\s*/\s*(\d+)(?![\d/])", scan)
    bp, bt, bwhy = board_line_fraction(text)
    # ⭐ ONE fraction, or SEVERAL THAT AGREE.  A two-mode board line ("m3 1852/1854 · m4 1852/1854") is the
    # COMMON shape, not the exceptional one, so refusing every text with more than one fraction would make
    # this unusable and push runners straight back to hand-editing -- the failure being cured.  But when the
    # modes DISAGREE there is no fact of the matter about which one the suite row means, and that is exactly
    # when a human must say: refuse and name the row.  ⛔ Never min(), never first-wins -- either would write
    # a real number under a provenance stamp that says it was measured, which is the one outcome worse than
    # refusing.
    uniq = sorted(set(found))
    if len(uniq) == 1:
        # ⛔ TWO READINGS OF ONE SUITE THAT DISAGREE ARE A JUDGEMENT, WHOEVER PRINTED THEM.  A prose fraction
        # beside a board line whose all_pass/all_n say something else is the same fault as two disagreeing
        # modes: there is no fact of the matter about which the row means, so refuse and name both.
        if bp is not None and (bp, bt) != (uniq[0][0], uniq[0][1]):
            return None, None, ("the --text carries the fraction %s/%s AND a SUITE_BOARD line reading all_pass=%s all_n=%s; "
                                "which one the suite row means is a judgement, not a reading -- pass --suite-pass/--suite-total"
                                % (uniq[0][0], uniq[0][1], bp, bt))
        return uniq[0][0], uniq[0][1], None
    if not found:
        # ⛔⭐ THE CANONICAL BOARD LINE IS SELF-SUFFICIENT AND WAS BEING RETYPED (hq_raku 2026-09-20, to the coo,
        # on their first real write of raku-rungs 830/927).  CEO-827 tells a runner to hand this writer its
        # VERBATIM SUITE_BOARD line; that line states the suite's fraction as `all_pass=830 all_n=927` -- the
        # harness's OWN AND-per-program count over its OWN population -- in key=value form and with no N/M
        # anywhere.  So the writer refused the very line the law asks for, and every board-column write had to
        # restate its number on the command line: the fraction reached SUITES.tsv by being TYPED rather than by
        # being READ off the line that measured it, which is a transcription seam of exactly the kind this file
        # exists to close.  Read BY NAME, word-bounded (lib_board_line.sh's discipline, CEO-839), never by
        # position, and never derived from pass/(pass+fail) -- that denominator is not the population.
        if bp is not None:
            return bp, bt, None
        if bwhy:
            return None, None, bwhy
        return None, None, ("the runner's --text carries no N/M fraction, so the suite row's pass/total cannot be read "
                            "from it -- pass --suite-pass/--suite-total")
    return None, None, ("the runner's --text carries %d DIFFERENT N/M fractions (%s), so which one the suite row means is "
                        "a judgement, not a reading -- pass --suite-pass/--suite-total"
                        % (len(uniq), ", ".join("%s/%s" % u for u in uniq)))


# ⭐⭐ A BOARD RECEIPT KEEPS THE RUNNER'S VERBATIM LINE (ceo CEO-827, 2026-09-17, on the coo's ask; read by the ceo as
# the COMPLETION of the standing "a watermark without its command is void" rule rather than a new one).  A receipt that
# PARAPHRASES its own board cannot be compared by util_suite_population_diff.py -- which is exactly the gap that bit
# this fleet the same morning: the SNOBOL4 rungs went m4_skip 0 -> 3 and back again across two landings, and neither
# reading survived anywhere in .github as anything but prose, so the pair the defect lived in could not be diffed at
# all.  This writer is the ONE write path for a row, so the line rides with the row write: every `write` archives the
# verbatim SUITE_BOARD line it was handed, and when it was handed none it SAYS SO in a greppable line rather than
# leaving the reader to assume one was kept.
BOARD_LINE_RX = re.compile(r"(?m)^.*?\b([A-Z0-9_]*SUITE_BOARD\b.*)$")
BOARD_LINES_DIR = os.path.join(S4E, ".github", "board-lines")
BOARD_LINES_HEADER = (
    "# VERBATIM RUNNER BOARD LINES, kept so any two readings of one suite are diffable after the fact (ceo CEO-827).\n"
    "# Each line is the runner's OWN board output, unedited. A receipt that paraphrases a board cannot be compared by\n"
    "# util_suite_population_diff.py, which is the gap the coo measured on the 2026-09-17 SNOBOL4 pair.\n"
    "# tree\tsuite\tmeasurer\tverbatim line\n")


def archive_board_line(text, suite, measurer, tree, dry=False, out=print):
    """append the verbatim board line this write was handed; return the path written, or None with a printed reason"""
    m = BOARD_LINE_RX.search(text or "")
    if not m:
        out("  ⛔ BOARD LINE NOT ARCHIVED: --text carries no SUITE_BOARD line, so this receipt is PROSE and no later "
            "comparison can read it (CEO-827). Pass the runner's own line as --text where one exists.")
        return None
    line = " ".join(m.group(1).split())          # one physical line, spacing normalised, tokens untouched
    row = "\t".join([tree, suite or "<unnamed-suite>", measurer or "<unnamed>", line]) + "\n"
    path = os.path.join(BOARD_LINES_DIR, "%s-%s.tsv" % (time.strftime("%Y-%m-%d"), (measurer or "unnamed").replace("/", "_")))
    if dry:
        out("  board line: WOULD archive to %s" % path)
        out("    %s" % line[:160])
        return path
    try:
        os.makedirs(BOARD_LINES_DIR, exist_ok=True)
        existing = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
        if not existing:
            existing = BOARD_LINES_HEADER
        if row in existing:
            out("  board line: already archived for this tree and suite in %s (unchanged)" % path)
            return path
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(existing if existing.endswith("\n") else existing + "\n")
            fh.write(row)
    except OSError as e:
        out("  ⛔ BOARD LINE NOT ARCHIVED: %s (%s) -- the row was still written; archive it by hand" % (path, e))
        return None
    out("  board line ARCHIVED verbatim: %s  (tree %s, suite %s)" % (path, tree, suite or "<unnamed-suite>"))
    return path


def suite_sync_decide(a):
    """Settle EVERY suite-mirror refusal BEFORE the board is persisted.  Returns (key, p, t) or a note; dies on a refusal.
    ⛔⭐ THE ORDER IS THE POINT (cfo 2026-09-07, ceo-assigned row score-row-write-rewrites-the-board-then-refuses).
    cmd_write used to write SCORE.md and only then call this, so a refusal exited 2 over a board that HAD moved, and the
    three runners that read the rc printed "SCORE.md NOT UPDATED -- record this row by hand" over a row they had just
    written.  A refusal now leaves BOTH files byte-identical, so rc=2 means nothing was written and the runner's own
    message is true.  cmd_selftest's byte-identity arm is the proof and fails if this is ever reordered back."""
    if a.column not in SUITE_SYNC_COLUMNS:
        return None, None, None, "  suite table: --column %s is not a V or M cell, so no suite row is owed" % a.column
    if getattr(a, "no_suite_sync", False):
        return None, None, None, "  ⚠ suite table: --no-suite-sync given -- SUITES.tsv NOT updated, and the banner will read this row STALE"
    key, why = resolve_suite_key(a.lang, a.column, a.suite, getattr(a, "suite_key", "") or "")
    if key is None:
        die("this write moves a %s cell, so it owes SUITES.tsv a row -- and %s.\n"
            "        Row %s: the suite table is what the banner and Lon read; a grid cell written without it\n"
            "        is a measurement only this file can see.  Use --suite-key / --suite-pass / --suite-total,\n"
            "        or --no-suite-sync if this write genuinely has no suite row.\n"
            "        NOTHING WAS WRITTEN: SCORE.md and SUITES.tsv are both untouched." % (a.column.upper(), why, SUITE_SYNC_ROW))
    p, t, why = fraction_from_text(a.text, getattr(a, "suite_pass", None), getattr(a, "suite_total", None))
    if p is None:
        die("this write moves a %s cell and resolved suite row %r, but %s.\n"
            "        Row %s.\n"
            "        NOTHING WAS WRITTEN: SCORE.md and SUITES.tsv are both untouched." % (a.column.upper(), key, why, SUITE_SYNC_ROW))
    # ⛔ A CRITERION CHANGE IS STAMPED BY THE WRITER, NEVER BY A HAND (coo 2026-09-16, CEO-785; row instruments-util-score-row-
    # cannot-stamp-a-criterion-change-so-every-denominator-move-is-hand-edited-or-unstamped). Two shapes owe the stamp and
    # REFUSE rc=2 here, BEFORE anything is written: a write whose total differs from the row's previous today_total (the
    # denominator moved -- CEO-749's shape says the row names why), and a --text that names an INSTRUMENT CHANGE (the
    # criterion moved even when the total did not: hq_pascal's PAT m4 rejection arm, SCRIP fe37edc72, 284 -> 296 at 427).
    stamp = getattr(a, "criterion_changed", None) or ""
    if stamp and not re.match(r"^\d{4}-\d{2}-\d{2}:\S", stamp):
        die("--criterion-changed takes '<YYYY-MM-DD>:<reason in words>' (the day the criterion moved, a colon, then why); got %r.\n"
            "        NOTHING WAS WRITTEN: SCORE.md and SUITES.tsv are both untouched." % stamp)
    rows, _err = suites_rows()
    prev = next((r.get("today_total", "") for r in rows if r.get("key") == key), "").strip()
    if prev and str(t) != prev and not stamp:
        die("this write moves suite row %r's DENOMINATOR %s -> %s and no --criterion-changed '<YYYY-MM-DD>:<reason>' names why.\n"
            "        A denominator move without its stamp is the dishonest-denominator class (CEO-546, CEO-749): pass the stamp\n"
            "        (it is APPENDED to SUITES.tsv column 12, never a hand edit), or keep the total.\n"
            "        NOTHING WAS WRITTEN: SCORE.md and SUITES.tsv are both untouched." % (key, prev, t))
    if "INSTRUMENT CHANGE" in (a.text or "").upper() and not stamp:
        die("this --text names an INSTRUMENT CHANGE for suite row %r and no --criterion-changed '<YYYY-MM-DD>:<reason>' stamps it.\n"
            "        The criterion moved even if the total did not; the row names why, by the writer, in column 12.\n"
            "        NOTHING WAS WRITTEN: SCORE.md and SUITES.tsv are both untouched." % key)
    # ⛔⭐ THE STAMP IS A TWO-REPO FEATURE, AND THE GUARD WAS ONE-SIDED (hq_raku 2026-09-16, raku-rungs 925 -> 927 with column 12
    # byte-identical; row util-score-row-forwards-the-criterion-stamp-to-a-banner-it-never-checked-and-never-reads-the-row-back):
    # this file (SCRIP) refuses without the stamp and forwards it; util_suite_banner.py (.github) stores it. A root whose SCRIP is
    # ahead of its .github ran an old banner that read --set by index and dropped the flag -- the dishonest denominator reached
    # THROUGH the guard, with the writer saying the stamp was recorded. So: the banner this write will call must carry the flag
    # BEFORE anything is written, and the row is READ BACK after it returns (suite_sync below).
    if stamp:
        try:
            _btxt = open(SUITE_BANNER, encoding="utf-8").read()
        except OSError:
            _btxt = ""
        if "--criterion-changed" not in _btxt:
            die("--criterion-changed was given but the banner this write would call, %s, does not know the flag (an older\n"
                "        util_suite_banner.py reads --set by index and would DROP the stamp while this writer reports it recorded).\n"
                "        Pull .github to origin (the flag landed at .github 49ca418e) and re-run.\n"
                "        NOTHING WAS WRITTEN: SCORE.md and SUITES.tsv are both untouched." % SUITE_BANNER)
    db_crosscheck(key, p, t)
    return key, p, t, None


def db_crosscheck(key, p, t):
    # ⛔ THE SETTER TAKES ITS NUMBER FROM THE APPEND, NOT FROM THE PRINT (hq_raku 2026-09-16, row instruments-a-suite-row-set-
    # from-a-runners-printed-line-can-drift-from-the-append-behind-it-the-writer-reads-the-db-at-write-time): raku-rungs read
    # 830/927 on db4a6b1fc while the progress DB on that tree read 829 -- the 830 was a printed line from a pass on
    # 7b21dcb5b-dirty, stamped with the later tree; the printed fail list (capped at 40) read zero regressed, and only the
    # DB, 1854 rows key for key, named benchmark_point_class_add m3 PASS -> CRASH.  A row set from a printed line can always
    # drift from the data behind it, so this write reads the DB for the suite ON THE TREE IT STAMPS and refuses when the
    # numerator is not the DB's count (bounded, not equal, where the rows carry a criterion label -- the batch audit's rule,
    # SCRIP e00dd73b1); no rows on that tree is a refusal naming CEO-750, never a pass.  The denominator is WARNED, not
    # refused: the SNOBOL4 package rows' UNGRADABLE/UNGRADED vocabulary is a ruled, open reconciliation and this writer
    # does not close it by blocking the numerator.  S4E_DB_CHECK_OVERRIDE='why' is the one door, printed loudly, for a
    # fixture that plants no rows; a runner never sets it.
    ov = os.environ.get("S4E_DB_CHECK_OVERRIDE", "")
    if ov:
        print("  ⚠ progress DB cross-check OVERRIDDEN (S4E_DB_CHECK_OVERRIDE): %s" % ov)
        return
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import util_suite_rows_vs_progress as _aud
    import collections as _c
    db = os.environ.get("S4E_PROGRESS_DB", "/home/resources/progress/results.tsv")
    if not os.path.exists(db):
        die("the progress DB %s does not exist, so this write's --suite-pass cannot be held against the append behind it.\n"
            "        NOTHING WAS WRITTEN: SCORE.md and SUITES.tsv are both untouched." % db)
    tree = suite_tree_stamp().replace("-DIRTY", "-dirty")
    suite = _aud.dbname(key)
    last = _aud.read_db(db, {(suite, tree): key})
    if not last:
        die("no progress rows for suite %r on tree %s in %s: a row without per-program evidence is DARK wearing a number\n"
            "        (CEO-750: a runner may not write a SCORE row while its own progress append refused).  Append first, or\n"
            "        if this is a fixture that plants no rows, S4E_DB_CHECK_OVERRIDE='why' (printed).\n"
            "        NOTHING WAS WRITTEN: SCORE.md and SUITES.tsv are both untouched." % (suite, tree, db))
    d = _c.defaultdict(dict)
    for (_s, _t, prog, m), (o, note, _who, _ts) in last.items():
        d[prog][m] = (o, note)
    corpus = os.environ.get("S4E_CORPUS_ROOT") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "corpus")
    d, side, s_ungradable, s_ungraded = _aud.population_inputs(corpus, key, d)   # containers out of the population (CEO-1272), as the batch audit counts it
    cnt, pop, _xpass, labels, bounded, shards = _aud.tally(d, side, s_ungradable, s_ungraded)
    p, t = int(p), int(t)
    if bounded:
        if p > cnt["PASS"]:
            die("--suite-pass %d for row %r EXCEEDS the progress DB's %s upper bound %d on %s (the DB's per-entry criterion is\n"
                "        looser than the row's, so its count bounds the row from above and this write is above it).\n"
                "        NOTHING WAS WRITTEN: SCORE.md and SUITES.tsv are both untouched." % (p, key, "/".join(sorted(labels)), cnt["PASS"], tree))
        print("  progress DB: %s on %s reads %d PASS under criterion %s -- an upper bound on --suite-pass %d, held" % (suite, tree, cnt["PASS"], "/".join(sorted(labels)), p))
    elif p != cnt["PASS"]:
        die("--suite-pass %d for row %r is NOT what the progress DB reads on the tree this write stamps: %s on %s reads %d PASS\n"
            "        (population %d: PASS %d FAIL %d OUTSIDE %d UNGRADABLE %d UNGRADED %d DEFERRED %d).  A number from a printed line\n"
            "        stamped with another tree's hash is a transcribed figure (hq_raku 2026-09-16: 830 printed on 7b21dcb5b-dirty,\n"
            "        829 in the DB on db4a6b1fc).  Take the number from the append: re-run the suite on this tree, or stamp the tree\n"
            "        the print came from.\n"
            "        NOTHING WAS WRITTEN: SCORE.md and SUITES.tsv are both untouched."
            % (p, key, suite, tree, cnt["PASS"], pop, cnt["PASS"], cnt["FAIL"], cnt["OUTSIDE"], cnt["UNGRADABLE"], cnt["UNGRADED"], cnt["DEFERRED"]))
    else:
        print("  progress DB: %s on %s reads %d PASS -- agrees with --suite-pass %d" % (suite, tree, cnt["PASS"], p))
    if t != pop:
        print("  ⚠ suite row %r denominator %d vs the DB population %d on %s (PASS %d FAIL %d OUTSIDE %d UNGRADABLE %d UNGRADED %d DEFERRED %d) -- the batch audit will name it"
              % (key, t, pop, tree, cnt["PASS"], cnt["FAIL"], cnt["OUTSIDE"], cnt["UNGRADABLE"], cnt["UNGRADED"], cnt["DEFERRED"]))
    if shards:
        print("  ⚠ the newest rows on %s are PARTIAL (%s) -- a shard, not a board" % (tree, ", ".join(sorted(shards))))


# ⛔⭐⭐ THE ROW FROM THE LATEST PER-PROGRAM READINGS (Lon 2026-10-11 13:0x CDT, in-chat to the ceo, verbatim: "One reason for the subsets on
# large suites is so they can be run in chunks even when the full regressions are being run in its "spare" time."; ceo CEO-1676 row (b);
# ARCH-SUITE-PARTITIONS.md section 4 (b)). With the long suites read a chunk at a time, no single run grades the whole population, so the row is
# ASSEMBLED: every entry of the suite's table at its LATEST reading in each mode, whatever tree read it; the AND per program over m3 and m4 is
# the numerator, the table's entries the denominator. The row is CURRENT at a tree when every entry has a reading at or after it -- so it names
# the OLDEST reading's tree beside the newest, per chunk too, and a write stamps the oldest (the tree every reading is at or after).
# the packages whose suite key is not their directory's progress key (the coo's measurement of 2026-10-15: from-progress could not reach them)
FROM_PROGRESS_PACKAGES = {"x64tests": "packages/snobol4/spitbol_x64_tests", "x32tests": "packages/snobol4/spitbol_x32_tests", "logtalk": "packages/prolog/logtalk_iso"}
FROM_PROGRESS_MASTERS = {"sno-rungs": "tests/snobol4", "icn-rungs": "tests/icon", "pl-rungs": "tests/prolog", "pas-rungs": "tests/pascal",
                         "raku-rungs": "tests/raku", "snc-rungs": "tests/snocone", "reb-rungs": "tests/rebus"}
# ⭐ THE BENCH AND DEMO TREES CARRY NO ALL.csv, so their population is the CENSUS their runner grades (CEO-1822; Lon 2026-10-18, in-chat to
# hq_dotnet, verbatim: "Get all SNOBOL4 package runners working with snobol4dotnet."): test_snobol4_bench_suite.sh grades every *.sno directly
# under the tree, keyed by its stem; test_demos_suite.sh every program three levels deep that CONTAINERS.tsv does not name, keyed
# demos/<lang>/<path>. A PORT's row only: SCRIP's bench and demo rows are written from their runner's board line, as before.
FROM_PROGRESS_CENSUS = {"snobol4-bench-ref": "benchmarks/snobol4", "snobol4-demos": "demos/snobol4"}
_DEMO_EXTS = (".sno", ".icn", ".pl", ".sc", ".pas", ".raku", ".reb")


def _census_population(tdir, key):
    """The programs a bench or demo runner grades under tdir, keyed as its progress rows key them (see FROM_PROGRESS_CENSUS)."""
    if key.endswith("-bench-ref"):
        return sorted(f[:-4] for f in os.listdir(tdir) if f.endswith(".sno") and os.path.isfile(os.path.join(tdir, f)))
    cont = set()
    cp = os.path.join(tdir, "CONTAINERS.tsv")
    if os.path.exists(cp):
        cont = {l.split("\t")[0].strip() for l in open(cp, encoding="utf-8", errors="replace") if l.strip() and not l.startswith("#")}
    pre = "demos/%s/" % os.path.basename(tdir.rstrip(os.sep))
    progs = []
    for root, dirs, files in os.walk(tdir):
        rel = os.path.relpath(root, tdir)
        depth = 0 if rel == "." else rel.count(os.sep) + 1
        if depth >= 3:
            dirs[:] = []
        for f in files:
            r = f if rel == "." else os.path.join(rel, f)
            if f.endswith(_DEMO_EXTS) and depth <= 2 and r not in cont:
                progs.append(pre + r)
    return sorted(progs)


def _logtalk_case_population(tdir, names):
    """Logtalk's population as util_logtalk_grade.py keys it: ALL.csv lists every vendored case, group:case, once per instance; an EXCLUDED_CASES.tsv
    row of a guard class (WINDOWS_ONLY, EXCLUSIVE_BRANCH) takes out the ONE instance its :- if(...) decides false, a row of any other class takes out
    every instance of its name; a name left with k > 1 instances is keyed name#1..name#k, else name. Returns (population keys, excluded count)."""
    import collections
    cnt = collections.Counter(names)
    excl = {}
    xp = os.path.join(tdir, "EXCLUDED_CASES.tsv")
    if os.path.exists(xp):
        for l in open(xp, encoding="utf-8", errors="replace"):
            r = l.rstrip("\n").split("\t")
            if l.strip() and not l.lstrip().startswith("#") and len(r) >= 2:
                excl[r[0].strip()] = r[1].strip()
    keys, nex = set(), 0
    for n, c in cnt.items():
        cls = excl.get(n)
        gone = 0 if cls is None else (min(1, c) if cls in ("WINDOWS_ONLY", "EXCLUSIVE_BRANCH") else c)
        nex += gone
        k = c - gone
        keys |= ({n} if k == 1 else {"%s#%d" % (n, j) for j in range(1, k + 1)})
    return keys, nex


def _swi_case_census(tdir, files):
    """SWI's population, case by case, as test_prolog_swi_suite.sh grades it: per table file <f> (<f>.pl beside its oracle ref <f>.ref), every case
    util_swi_match.py enumerates from the source and the ref alone (the runner's own matcher, run on no output: the case list is the oracle's), less a case
    the oracle gives no answer (UNGRADED: BLOCKED, an EMPTY or UNGRADABLE unit; NO_ORACLE_ANSWER, CEO-1696) and then a case EXCLUDED_CASES.tsv names
    (file + unit:test#k, or unit:test for every instance; CEO-1710/1766), in the runner's order. Returns (declared, {"<f>.pl:<unit:test#k>"}, excluded),
    or a REFUSE line when a file has no ref or the matcher refuses."""
    match_py = os.path.join(os.path.dirname(os.path.abspath(__file__)), "util_swi_match.py")
    excl = set()
    xp = os.path.join(tdir, "EXCLUDED_CASES.tsv")
    if os.path.exists(xp):
        for l in open(xp, encoding="utf-8", errors="replace"):
            r = l.rstrip("\n").split("\t")
            if l.strip() and not l.startswith("#") and len(r) >= 2:
                excl.add((r[0].strip(), r[1].strip()))
    declared, graded, noref = 0, set(), []
    for f in files:
        rel = f + ".pl"
        ref = os.path.join(tdir, f + ".ref")
        if not os.path.exists(ref):
            noref.append(rel)
            continue
        out = subprocess.run([sys.executable, match_py, os.path.join(tdir, rel), ref, os.devnull, "0"], capture_output=True, text=True)
        if out.returncode != 0:
            return "REFUSE(2): from-progress: util_swi_match.py refused %s (rc %d): %s" % (rel, out.returncode, (out.stderr or out.stdout).strip()[:200])
        for line in out.stdout.split("\n"):
            c = line.split("\t")
            if len(c) < 2 or line.startswith("MATCH "):
                continue
            declared += 1
            if c[1] == "UNGRADED" or (rel, c[0]) in excl or (rel, c[0].rsplit("#", 1)[0]) in excl:
                continue
            graded.add(rel + ":" + c[0])
    if noref:
        return "REFUSE(2): from-progress: %d SWI file(s) carry no oracle ref, so their cases are unknown: %s" % (len(noref), " ".join(noref[:10]))
    return declared, graded, declared - len(graded)


def _gimpel_population(tdir):
    """Gimpel's population is its LIBRARIES (ceo CEO-1269: the program is the library, the driver is how it is graded), keyed as its rows
    key them (packages/snobol4/gimpel/<lib>.<ext>), by the runner's own _lib_of rule: x_driver.sno drives x.spt|x.inc|x.sno|x.INC, and
    x_lib_driver.sno drives x.inc. Returns (every shipped library key, the keys a driver grades); the rest are owed with no reading."""
    names = sorted(os.listdir(tdir))
    libs = {f for f in names if f.rsplit(".", 1)[-1] in ("inc", "spt", "sno", "INC") and not f.startswith("ALL.") and not f.endswith("_driver.sno")}
    driven = set()
    for d in names:
        if not d.endswith("_driver.sno"):
            continue
        stem = d[:-len("_driver.sno")]
        hit = next((stem + "." + e for e in ("spt", "inc", "sno", "INC") if stem + "." + e in libs), None)
        if hit is None and stem.endswith("_lib") and stem[:-4] + ".inc" in libs:
            hit = stem[:-4] + ".inc"
        if hit:
            driven.add(hit)
    pre = "packages/snobol4/gimpel/"
    return sorted(pre + f for f in libs), {pre + f for f in driven}


def from_progress_table(corpus, key):
    """(table dir, progress suite name) for a SUITES.tsv key: the seven masters by name, a package by the harness's own key rule
    (PROGRESS_PACKAGE_KEYS: a package directory's progress key, else its name), or (None, None)."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import util_suite_rows_vs_progress as _aud
    full, key = key, key.partition("@")[0]   # a port key (sno-rungs@dotnet) reads its bare key's table; its progress name keeps the engine
    if key in FROM_PROGRESS_MASTERS:
        return os.path.join(corpus, FROM_PROGRESS_MASTERS[key]), _aud.dbname(full)
    if "@" in full and key in FROM_PROGRESS_CENSUS and os.path.isdir(os.path.join(corpus, FROM_PROGRESS_CENSUS[key])):
        return os.path.join(corpus, FROM_PROGRESS_CENSUS[key]), _aud.dbname(full)
    if key in FROM_PROGRESS_PACKAGES and os.path.exists(os.path.join(corpus, FROM_PROGRESS_PACKAGES[key], "ALL.csv")):
        return os.path.join(corpus, FROM_PROGRESS_PACKAGES[key]), _aud.dbname(full)
    import corpus_suite_harness as _h
    for lang in sorted(os.listdir(os.path.join(corpus, "packages"))) if os.path.isdir(os.path.join(corpus, "packages")) else []:
        ld = os.path.join(corpus, "packages", lang)
        for pkg in sorted(os.listdir(ld)) if os.path.isdir(ld) else []:
            if _h.PROGRESS_PACKAGE_KEYS.get(pkg, pkg) == key and os.path.exists(os.path.join(ld, pkg, "ALL.csv")):
                return os.path.join(ld, pkg), _aud.dbname(full)
    return None, None


def _wall_only_without_a_table(full_key, _aud):
    """--wall-only for a key with no ALL.csv under corpus (a benchmark or demo row, graded whole by its runner): the Wall is still the sum of each member's
    minimum (Lon 2026-10-18), the members being the programs the progress table holds readings for under the key's suite name, in the modes it holds."""
    import util_progress_append as _upa
    db = os.environ.get("S4E_PROGRESS_DB", "/home/resources/progress/results.tsv")
    if not os.path.exists(db):
        print("REFUSE(2): from-progress --wall-only: the progress DB %s does not exist" % db)
        return 2
    mn = _upa.min_secs_table(db)
    if not mn:
        print("REFUSE(2): from-progress --wall-only: no minimum-seconds ledger beside %s -- the Wall is the sum of minimums and none exists to sum" % db)
        return 2
    dbs = _aud.dbname(full_key)
    present = set()
    with open(db, encoding="utf-8", errors="replace") as fh:
        fh.readline()
        for line in fh:
            fl = line.rstrip("\n").split("\t")
            if len(fl) >= 10 and fl[5] == dbs and fl[8] in ("m3", "m4"):
                present.add((fl[7], fl[8]))
    wall = int(round(sum(mn.get((dbs, p, m), 0.0) for (p, m) in present)))
    env = dict(os.environ); env["S4E_SUITES_TSV"] = SUITES_TSV; env["S4E_SCORE_MD"] = SCORE_MD
    r = subprocess.run([sys.executable, SUITE_BANNER, "--set-wall", full_key, str(wall)], capture_output=True, text=True, env=env)
    sys.stdout.write(r.stdout); sys.stderr.write(r.stderr)
    return r.returncode


def cmd_from_progress(a):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import csv as _csv, collections as _c
    import util_suite_rows_vs_progress as _aud
    # ⛔ A PORT ENGINE'S KEY (sno-rungs@dotnet, CEO-1822) reads its bare key's table and is graded in m3 alone -- a port has no mode 4 --
    # while every line this prints and the row it writes carry the full key, so the port's row and SCRIP's are never one another's
    full_key = a.suite
    key, _at, port = full_key.partition("@")
    modes = ("m3",) if port else ("m3", "m4")
    corpus = os.environ.get("S4E_CORPUS_ROOT") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "corpus")
    tdir, dbsuite = from_progress_table(corpus, full_key)
    if not tdir:
        if getattr(a, "wall_only", False):
            return _wall_only_without_a_table(full_key, _aud)
        print("REFUSE(2): from-progress: no suite table for key %r under %s (the seven masters and the packages with an ALL.csv)" % (full_key, corpus))
        return 2
    if key in FROM_PROGRESS_CENSUS:
        pop = _census_population(tdir, key)
    else:
        with open(os.path.join(tdir, "ALL.csv"), encoding="utf-8", errors="replace", newline="") as f:
            pop = [r.get("entry", "") for r in _csv.DictReader(f) if r.get("entry", "")]
    part = {}
    pp = os.path.join(tdir, "PARTITION.tsv")
    if os.path.exists(pp):
        for line in open(pp, encoding="utf-8", errors="replace"):
            fl = line.rstrip("\n").split("\t")
            if line.startswith("#") or len(fl) < 2 or fl[0] == "entry":
                continue
            part[fl[0]] = fl[1]
    db = os.environ.get("S4E_PROGRESS_DB", "/home/resources/progress/results.tsv")
    if not os.path.exists(db):
        print("REFUSE(2): from-progress: the progress DB %s does not exist" % db)
        return 2
    # ⛔⭐ A PACKAGE'S ROW IS SHIPPED MINUS EXCLUDED, AS ITS RUNNER WRITES IT (ceo CEO-1802/1803, Lon 2026-10-15 via the ceo: "Why is not the suite board a
    # list of tests and not a list of suites?"; the coo measured 16 of 24 packages assembling a different total from ALL.csv's entry count): a package's
    # population is its ALL.csv entries together with every shipped <name>.<ext> beside the container, less the EXCLUDED.tsv rows and the CONTAINERS.tsv
    # fragments (CEO-1286/1288/1696), so shipped = denominator + Excl as lib_container_package_runner.sh publishes it. A shipped program the container does
    # not grade is debt with no reading needed (the runner's UNGRADED row). A reading names its program with or without the extension (GNU writes x.pl).
    pkg = key not in FROM_PROGRESS_MASTERS and key not in FROM_PROGRESS_CENSUS
    ext, shipped, xnames, cnames, nex = "", set(), set(), set(), 0
    if pkg:
        _EXTS = ("sno", "spt", "sbl", "icn", "pl", "pas", "raku", "sc", "reb")
        for f in sorted(os.listdir(tdir)):
            m = re.match(r"^ALL\.(sno|spt|sbl|icn|pl|pas|raku|sc|reb)$", f)
            if m:
                ext = m.group(1)
                break
        if not ext:   # a package with no container (Flake, Dotnet, x64, x32): the extension its shipped programs carry most
            _ec = _c.Counter(f.rsplit(".", 1)[1] for f in os.listdir(tdir) if "." in f and f.rsplit(".", 1)[1] in _EXTS and not f.startswith("ALL."))
            ext = _ec.most_common(1)[0][0] if _ec else ""
        def _stem(n):
            n = n.strip()
            for e in ((ext,) if ext else ()) + _EXTS:
                if n.endswith("." + e):
                    return n[:-len(e) - 1]
            return n
        if ext:
            shipped = {f[:-len(ext) - 1] for f in os.listdir(tdir) if f.endswith("." + ext) and f != "ALL." + ext}
            # a table whose entries are not <name>.<ext> files beside it (INRIA's entries are tests inside family files) ships its table
            if pop and sum(1 for e in pop if e in shipped) * 2 < len(pop):
                shipped = set()
        for fn, acc in (("EXCLUDED.tsv", xnames), ("CONTAINERS.tsv", cnames)):
            fp = os.path.join(tdir, fn)
            if os.path.exists(fp):
                for line in open(fp, encoding="utf-8", errors="replace"):
                    if line.strip() and not line.startswith("#"):
                        acc.add(_stem(line.split("\t")[0]))
                        nex += fn == "EXCLUDED.tsv"
        pkg_pop = (set(pop) | shipped) - xnames - cnames
    _owed = set()
    if pkg and os.sep + os.path.join("packages", "icon") + os.sep in tdir + os.sep:
        # ⭐ AN ICON PACKAGE GRADES A LIBRARY THROUGH ITS DRIVER and keys the row by the library (lib_package_keys.board_key, the harness's own rule),
        # and a PREPROCESS.tsv contract (program<TAB>argv<TAB>rc) grades each argv program by preprocessing alone: Arizona's general/tpp and
        # general/tpp9, JCON's tpp -- shipped programs its ALL.csv does not list
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from lib_package_keys import board_key as _bk
        _mapped = []
        for e in pop:
            k_ = _bk(tdir, "icon", e)
            if k_ not in _mapped:
                _mapped.append(k_)
        _pp = os.path.join(tdir, "PREPROCESS.tsv")
        if os.path.exists(_pp):
            for l in open(_pp, encoding="utf-8", errors="replace"):
                _r = l.rstrip("\n").split("\t")
                if len(_r) >= 2 and l.strip() and not l.startswith("#"):
                    _ps = os.path.dirname(_r[0].strip())
                    for _a in _r[1].split():
                        k_ = (_ps + "/" if _ps not in ("", ".") else "") + (_a[:-4] if _a.endswith(".icn") else _a)
                        if k_ not in _mapped:
                            _mapped.append(k_)
        pop = _mapped
        # ALL.excluded.txt names the units the container does not grade on their own (graded through another unit, an oracle that refuses...):
        # a shipped file it names is not debt the table forgot
        _ae = os.path.join(tdir, "ALL.excluded.txt")
        if os.path.exists(_ae):
            _aen = {_stem(l.split(":", 1)[0]) for l in open(_ae, encoding="utf-8", errors="replace") if l.strip()}
            shipped = {x for x in shipped if x in set(pop) or x not in _aen}
        pkg_pop = (set(pop) | shipped) - xnames - cnames
    if key == "gimpel":   # its rows are keyed by library, its table by driver (CEO-1269)
        pop, _driven = _gimpel_population(tdir)
        _owed = set(pop) - _driven
        shipped = set()
        _gst = lambda k: k.rsplit("/", 1)[-1].rsplit(".", 1)[0]   # EXCLUDED.tsv and CONTAINERS.tsv name a library by file; _stem dropped its extension
        _gx, _gc = xnames, cnames
        xnames = {k for k in pop if _gst(k) in _gx}
        cnames = {k for k in pop if _gst(k) in _gc}
        pkg_pop = set(pop) - xnames - cnames
    want = set(pop)
    # (program, mode) -> (outcome, note, tree, ts, secs) at the NEWEST timestamp: the table is compacted (older keys kept ahead of today's
    # appends, 380 backward steps measured 2026-10-11), so file order is not time order; a tie keeps the later line, the later append
    last = {}
    with open(db, encoding="utf-8", errors="replace") as fh:
        fh.readline()
        for line in fh:
            fl = line.rstrip("\n").split("\t")
            if len(fl) < 10 or fl[5] != dbsuite or fl[8] not in ("m3", "m4"):
                continue
            if key == "swi":   # SWI's rows name a CASE of a table file, file.pl:unit:test#k (its table lists files)
                _sf = fl[7].split(":", 1)[0]
                if (_sf[:-3] if _sf.endswith(".pl") else None) in want:
                    k = (fl[7], fl[8])
                    if k not in last or fl[0] >= last[k][3]:
                        last[k] = (fl[9], fl[11] if len(fl) > 11 else "", fl[1], fl[0], fl[10])
                continue
            if key == "logtalk":   # a repeated case's rows are name#k (util_logtalk_grade.py's key); the table lists the name
                _lm = re.match(r"^(.*)#\d+$", fl[7])
                if (_lm.group(1) if _lm else fl[7]) in want:
                    k = (fl[7], fl[8])
                    if k not in last or fl[0] >= last[k][3]:
                        last[k] = (fl[9], fl[11] if len(fl) > 11 else "", fl[1], fl[0], fl[10])
                continue
            if pkg and fl[7] not in want:
                fl[7] = _stem(fl[7])   # GNU writes BipsPl/x.pl for the table's BipsPl/x
            if fl[7] not in want:
                continue
            k = (fl[7], fl[8])
            if k not in last or fl[0] >= last[k][3]:
                last[k] = (fl[9], fl[11] if len(fl) > 11 else "", fl[1], fl[0], fl[10])
    d = _c.defaultdict(dict)
    for (prog, m), (o, note, _tree, _ts, _secs) in last.items():
        d[prog][m] = (o, note)
    d, side, s_ungradable, s_ungraded = _aud.population_inputs(corpus, key, dict(d))
    def _f(x):
        try:
            return float(x)
        except ValueError:
            return 0.0
    # the row's Wall is the MINIMUM time to run the suite (Lon 2026-10-18: "That column is meant to represent the MINIMUM amount of time to run the test"):
    # the sum, over the suite's programs and modes, of the smallest PASS seconds ever recorded for each (<db>.min, util_progress_append's ledger); the
    # latest reading is a loaded run's, a timeout's or a crash's and says how long that one run took. Where the ledger does not exist (a scratch database)
    # the latest readings' own seconds stand, as before (row (c)).
    import util_progress_append as _upa
    _mn = _upa.min_secs_table(db)
    _have_ledger = bool(_mn)
    if _mn:
        def _mnv(prog, m):   # a reading may be keyed by its stem here and by file name in the ledger (GNU writes BipsPl/x.pl, the table lists BipsPl/x)
            for sfx in ("", ".pl", ".sno", ".spt", ".sbl", ".icn", ".pas", ".raku", ".sc", ".reb", ".inc", ".INC"):
                if (dbsuite, prog + sfx, m) in _mn:
                    return _mn[(dbsuite, prog + sfx, m)]
            return 0.0
        wall = int(round(sum(_mnv(prog, m) for (prog, m) in last)))
        # the ledger spans every PASS ever recorded, so a subset re-take cannot shrink the sum (the reason for the timed == len(last) guard below): the Wall is
        # complete when every program that PASSES NOW has its minimum; a program that does not pass has no run time to add
        _ledger_complete = all(_mnv(prog, m) > 0 for (prog, m), v in last.items() if v[0] == "PASS")
    else:
        _ledger_complete = None
        wall = int(round(sum(_f(v[4]) for v in last.values())))
    timed = sum(1 for v in last.values() if _f(v[4]) > 0)        # a reading taken before the runner recorded seconds carries 0
    if _ledger_complete is not None:
        timed = len(last) if _ledger_complete else 0
    cnt, _pop, _xp, _labels, _bounded, _shards = _aud.tally(d, side, s_ungradable, s_ungraded)
    unread = [e for e in pop if e not in d and e not in side]
    halfread = [e for e in pop if e in d and set(d[e]) != set(modes)]
    excluded = None
    if pkg:
        def _both(e):
            r = last_by.get(e, {})
            return all(r.get(m, ("",))[0] == "PASS" for m in modes)
        last_by = _c.defaultdict(dict)
        for (prog, m), v in last.items():
            last_by[prog][m] = v
        # ⭐ AN ENTRY THE ORACLE REFUSES IN BOTH MODES LEAVES THE DENOMINATOR (CEO-1696: no oracle answer is excluded, never debt): its latest
        # readings are OUTSIDE in m3 and m4, the shape INRIA's three file_manip entries and every package's oracle-refused programs record
        _swi_excl = None
        if key == "swi":
            # ⭐ SWI's POPULATION IS THE ORACLE'S ENUMERATION OF ITS CASES (the row counts cases; the table lists files), less the cases with no oracle
            # answer and the EXCLUDED_CASES.tsv rows, as the runner grades them (_swi_case_census); Excl is declared - graded, as the runner writes it,
            # so it moves with the corpus and never with an old row (the first cut read SUITES.tsv's own today_excluded back: 167 where the corpus says 211)
            _sc = _swi_case_census(tdir, sorted(want))
            if isinstance(_sc, str):
                print(_sc)
                return 2
            _swi_decl, pkg_pop, _swi_excl = _sc
            pop, shipped = sorted(pkg_pop), set()
            print("SUITE_ROW_SWI files=%d declared=%d graded=%d excluded=%d (NO_ORACLE_ANSWER and EXCLUDED_CASES.tsv, by util_swi_match.py's enumeration)"
                  % (len(want), _swi_decl, len(pkg_pop), _swi_excl))
        if key == "logtalk":
            # ⭐ LOGTALK's TABLE LISTS CASES and its rows key a repeated name name#k (_logtalk_case_population, the grader's own rule); its row is
            # the runner's: OUTSIDE stays in the denominator (util_logtalk_grade.py's BOARD_FOR_SHELL population), Excl the EXCLUDED_CASES.tsv cases
            # (its CONTAINERS.tsv names files, not cases)
            pkg_pop, _swi_excl = _logtalk_case_population(tdir, pop)
            pop, shipped, cnames = sorted(pkg_pop), set(), set()
            print("SUITE_ROW_LOGTALK cases=%d excluded=%d graded=%d (EXCLUDED_CASES.tsv by class; OUTSIDE stays in the denominator, as the runner's row)"
                  % (len(pop) + _swi_excl, _swi_excl, len(pkg_pop)))
        _outside = set() if key == "logtalk" else \
            {e for e in pkg_pop if all(last_by.get(e, {}).get(m, ("",))[0] == "OUTSIDE" for m in modes) and e in last_by}
        _outside_new = _outside - xnames - cnames
        pkg_pop = pkg_pop - _outside
        cnt = _c.Counter(cnt)
        cnt["PASS"] = sum(1 for e in pkg_pop if _both(e))
        unread = [e for e in pop if e in pkg_pop and e not in last_by and e not in _owed]
        halfread = [e for e in pop if e in pkg_pop and e in last_by and set(last_by[e]) != set(modes)]
        excluded = nex + len(cnames - xnames) + len(_outside_new)
        if _swi_excl is not None:
            excluded = _swi_excl
    # the row is current at the OLDEST reading of its POPULATION: an excluded or ungraded program's old reading is not one of the row's
    reads = sorted((v[3], v[2]) for (prog, _m), v in last.items() if not pkg or prog in pkg_pop)
    oldest, newest = (reads[0], reads[-1]) if reads else (("-", "-"), ("-", "-"))
    total = len(pkg_pop) if pkg else len(pop)
    if pkg:
        print("SUITE_ROW_PACKAGE suite=%s shipped=%d table=%d excluded_rows=%d containers=%d outside=%d excluded=%d denominator=%d debt_unread_by_design=%d"
              % (full_key, len(set(pop) | shipped), len(pop), nex, len(cnames - xnames), len(_outside_new), excluded, total, len(pkg_pop - set(pop))))
    print("SUITE_ROW suite=%s pass=%d total=%d read=%d unread=%d half_read=%d oldest_tree=%s@%s newest_tree=%s@%s secs=%d db_suite=%s table=%s "
          "(PASS %d FAIL %d OUTSIDE %d UNGRADABLE %d UNGRADED %d DEFERRED %d) timed=%d"
          % (full_key, cnt["PASS"], total, len(d), len(unread), len(halfread), oldest[1], oldest[0], newest[1], newest[0], wall, dbsuite,
             os.path.relpath(tdir, corpus), cnt["PASS"], cnt["FAIL"], cnt["OUTSIDE"], cnt["UNGRADABLE"], cnt["UNGRADED"], cnt["DEFERRED"], timed))
    if part:
        byc = _c.defaultdict(list)
        _pk = (lambda p: p.split(":", 1)[0][:-3]) if key == "swi" else (lambda p: p)   # an SWI case is in its file's part
        for (prog, m), v in last.items():
            byc[part.get(_pk(prog), "?")].append((v[3], v[2]))
        sizes = _c.Counter(part.get(_pk(e), "?") for e in pop)
        for c in sorted(sizes, key=lambda c: (c != "core", c)):
            r = sorted(byc.get(c, []))
            nread = len({prog for (prog, _m) in last if part.get(_pk(prog), "?") == c})
            print("SUITE_ROW_PART %s entries=%d read=%d oldest=%s newest=%s" % (c, sizes[c], nread, "%s@%s" % (r[0][1], r[0][0]) if r else "-",
                                                                              "%s@%s" % (r[-1][1], r[-1][0]) if r else "-"))
    if unread:
        print("SUITE_ROW_UNREAD %d: %s%s" % (len(unread), " ".join(unread[:30]), " ..." if len(unread) > 30 else ""))
    if getattr(a, "wall_only", False):
        # ⛔⭐ THE WALL IS THE SUM OF EACH MEMBER'S MINIMUM TIME (Lon 2026-10-18, in-chat to the coo, verbatim: "Fix the test-suite display banner to show the sum of
        # minimum times of eac member. NOT the maximum nor the current."): this arm sets the Wall and no other cell, so the loop and every row writer can keep it
        # current without a pass, a total or a tree; a suite whose members have no minimum yet is set blank (a zero), never left at a run's clock
        if not _have_ledger:
            print("REFUSE(2): from-progress --wall-only: no minimum-seconds ledger beside %s -- the Wall is the sum of minimums and none exists to sum" % db)
            return 2
        env = dict(os.environ); env["S4E_SUITES_TSV"] = SUITES_TSV; env["S4E_SCORE_MD"] = SCORE_MD
        r = subprocess.run([sys.executable, SUITE_BANNER, "--set-wall", full_key, str(wall)], capture_output=True, text=True, env=env)
        sys.stdout.write(r.stdout); sys.stderr.write(r.stderr)
        return r.returncode
    if a.dry_run:
        print("from-progress --dry-run: nothing written (would set %s -> %d/%d%s stamped %s, the oldest reading's tree)" % (full_key, cnt["PASS"], total, "" if excluded is None else " excluded=%d" % excluded, oldest[1]))
        return 0
    if unread or halfread:
        print("REFUSE(2): from-progress: %d entr(y/ies) have no reading and %d only one mode's -- the row is current when every chunk has a "
              "reading (CEO-1676); nothing written" % (len(unread), len(halfread)))
        return 2
    env = dict(os.environ); env["S4E_SUITES_TSV"] = SUITES_TSV; env["S4E_SCORE_MD"] = SCORE_MD
    # ⛔⭐ A PORT ENGINE'S ROW IS OPENED BY ITS FIRST PUBLISH, HERE (ceo CEO-1822): --set refuses a key with no row, so the engine's first
    # from-progress opens <key>@<engine> through the table's own writer (util_suite_banner.py --open: the bare row's nick, emoji and lang,
    # readings empty, under the same lock and the history writer) and the --set below fills it. Never by hand; a no-op once it is open.
    if port:
        o = subprocess.run([sys.executable, SUITE_BANNER, "--open", full_key, key], capture_output=True, text=True, env=env)
        sys.stdout.write(o.stdout); sys.stderr.write(o.stderr)
        if o.returncode != 0:
            return o.returncode
    cmd = [sys.executable, SUITE_BANNER, "--set", full_key, str(cnt["PASS"]), str(total), _box_clock_day(), oldest[1]]
    if (a.criterion_changed or os.environ.get("S4E_CRITERION_CHANGED", "")).strip():
        cmd += ["--criterion-changed", (a.criterion_changed or os.environ.get("S4E_CRITERION_CHANGED", "")).strip()]
    # ⛔ the Wall is written only when EVERY reading carries its seconds: a sum over the few readings a subset re-took is a fraction of the
    # suite's time printed as all of it (IcnRungs read WALL=221s from one tier-2 subset, 2026-10-11 14:1x); until then the row keeps its own
    if excluded is not None:
        cmd += ["--excluded", str(excluded)]
    r = subprocess.run(cmd, capture_output=True, text=True, env=env)
    sys.stdout.write(r.stdout); sys.stderr.write(r.stderr)
    if r.returncode == 0 and _have_ledger:
        # the Wall is the sum of each member's minimum (see --wall-only): REPLACED here, so a run's clock or an older, larger sum never stands
        w = subprocess.run([sys.executable, SUITE_BANNER, "--set-wall", full_key, str(wall)], capture_output=True, text=True, env=env)
        sys.stdout.write(w.stdout); sys.stderr.write(w.stderr)
        return w.returncode
    return r.returncode


def _box_clock_day():
    """The day SUITES.tsv's rows are dated in: the BOX's zone (/etc/timezone, else the /etc/localtime link), never this process's
    TZ (coo 2026-09-23, CEO-1229). The banner REFUSES a date later than its own box_clock_day(), and this writer used to pass its
    own datetime.now(): a caller in another zone would be refused AFTER a board write had already rewritten SCORE.md -- a
    PARTIAL. ⛔ COMPUTED HERE, NOT BORROWED BY EXECUTING THE BANNER FILE: the first cut exec'd util_suite_banner.py to call its
    function, and a stub banner whose body calls sys.exit(0) (test_gate_score_row_criterion_change_is_stamped.sh arm g) ended
    THIS process with rc=0 -- a false success. The two functions must agree; the date-guard gate holds them to each other."""
    tz = ""
    try:
        tz = open("/etc/timezone", encoding="utf-8").read().strip()
    except OSError:
        pass
    if not tz:
        try:
            _l = os.readlink("/etc/localtime")
            tz = _l.split("zoneinfo/", 1)[1] if "zoneinfo/" in _l else ""
        except OSError:
            pass
    try:
        from zoneinfo import ZoneInfo
        return (datetime.datetime.now(ZoneInfo(tz)) if tz else datetime.datetime.now()).strftime("%Y-%m-%d")
    except Exception:
        return datetime.datetime.now().strftime("%Y-%m-%d")


def suite_sync(a, tree, dry_run, decided=None):
    """Mirror this write into SUITES.tsv.  Every refusal is already settled by suite_sync_decide."""
    key, p, t, note = decided if decided is not None else suite_sync_decide(a)
    if note is not None:
        return note
    if dry_run:
        return "  suite table: WOULD set %s -> %s/%s (tree %s) via util_suite_banner.py --set" % (key, p, t, tree)
    if not os.path.exists(SUITE_BANNER):
        die("suite row %r is owed but %s is missing.\n        Row %s." % (key, SUITE_BANNER, SUITE_SYNC_ROW))
    day = _box_clock_day()
    # ⛔ BOTH OUTPUTS ARE NAMED TO THE BANNER (the coo 2026-10-10): given S4E_SUITES_TSV alone, util_suite_banner.py renders SCORE.md
    # BESIDE THE TABLE -- correct for a fixture's scratch pair, wrong since the table moved to /home/resources/progress (SCRIP 0eb163da2,
    # 2026-10-09): every write from then on rendered into a SCORE.md that does not exist there, the banner's "suite table NOT rendered"
    # went unread, and .github/SCORE.md's suite table kept 10-09's readings through a whole pass whose rows all landed in SUITES.tsv.
    env = dict(os.environ); env["S4E_SUITES_TSV"] = SUITES_TSV; env["S4E_SCORE_MD"] = SCORE_MD
    cmd = [sys.executable, SUITE_BANNER, "--set", key, str(p), str(t), day, tree]
    if getattr(a, "criterion_changed", None):
        cmd += ["--criterion-changed", a.criterion_changed]
    _exc = getattr(a, "excluded", None)
    if _exc is not None:
        try:
            _btxt = open(SUITE_BANNER, encoding="utf-8").read()
        except OSError:
            _btxt = ""
        if "--excluded" not in _btxt:
            die("--excluded was given but the banner this write would call, %s, does not know the flag (an older util_suite_banner.py would\n"
                "        DROP the count while this writer reports it recorded). Pull .github to origin (CEO-1286) and re-run.\n"
                "        NOTHING WAS WRITTEN: SCORE.md and SUITES.tsv are both untouched." % SUITE_BANNER)
        cmd += ["--excluded", str(_exc)]
    # ⛔⭐ A RUN'S CLOCK IS NOT THE WALL (Lon 2026-10-18, in-chat to the coo, verbatim: "Fix the test-suite display banner to show the sum of minimum times of eac
    # member. NOT the maximum nor the current."): this writer used to forward now - S4E_RUN_T0 (CEO-1562, Lon 10-08) as --secs, the CURRENT run's seconds; the
    # Wall is the sum of each member's minimum, set by from-progress (and --wall-only after this write), so no clock is forwarded.
    _secs = None
    r = subprocess.run(cmd, capture_output=True, text=True, env=env)
    # ⛔ THE BANNER IS A SUBPROCESS, SO ITS WRITE IS DECLARED HERE ON ITS RC, NOT ASSUMED FROM THE CALL.
    # A banner that moved the row and THEN failed is a real partial state, and the digest is what tells
    # the two apart -- the message below has always called itself PARTIAL in prose about SCORE.md; now
    # die() names which files actually moved, so PARTIAL is a measurement and not the author's claim.
    if r.returncode == 0:
        refusal_watch_wrote(SUITES_TSV)
    # ⛔ A RENDER THE BANNER SKIPPED IS A SPLIT STATE, SAID ALOUD: SUITES.tsv took the row and SCORE.md's suite table did not.
    if r.returncode == 0 and "suite table NOT rendered" in (r.stdout or "") + (r.stderr or ""):
        die("util_suite_banner.py --set %s %s %s set SUITES.tsv and did NOT render SCORE.md's suite table:\n        %s\n"
            "        ⛔ PARTIAL: SUITES.tsv carries the row and %s does not. Render it: util_suite_banner.py --render --only %s."
            % (key, p, t, ((r.stdout or "") + (r.stderr or "")).strip()[:300], SCORE_MD, key))
    if r.returncode != 0:
        die("util_suite_banner.py --set %s %s %s failed rc=%d: %s\n        Row %s.\n"
            "        ⛔ PARTIAL: SCORE.md WAS rewritten and SUITES.tsv was NOT -- this is the one case where the board\n"
            "        moved and its suite row did not.  Do not re-write the cell by hand; fix the banner and re-run,\n"
            "        or set the row with util_suite_banner.py --set %s %s %s."
            % (key, p, t, r.returncode, (r.stderr or r.stdout).strip()[:300], SUITE_SYNC_ROW, key, p, t))
    # ⛔ READ THE ROW BACK: the banner exited 0, so SUITES.tsv must now carry the numbers AND the stamp this writer forwarded. A
    # banner that dropped either is caught here, loudly -- SCORE.md WAS written, so the split state is named, never implied.
    _rows, _err = suites_rows()
    _r = next((x for x in _rows if x.get("key") == key), None)
    _cc = (_r or {}).get("criterion_changed", "")
    _stamp = getattr(a, "criterion_changed", None) or ""
    _exc_bad = (_exc is not None and (_r or {}).get("today_excluded", "") != str(_exc))
    _exc_bad = _exc_bad or (_secs is not None and (_r or {}).get("today_secs", "") != str(_secs))
    if _r is None or _r.get("today_pass") != str(p) or _r.get("today_total") != str(t) or (_stamp and not _cc.endswith(_stamp)) or _exc_bad:
        die("util_suite_banner.py --set returned 0 but the row READ BACK from %s does not carry what was forwarded: pass %r total %r stamp %s.\n"
            "        ⛔ PARTIAL: SCORE.md WAS rewritten and SUITES.tsv did NOT take the write -- the banner beside this writer is not the one\n"
            "        this flag was landed with (pull .github to origin; the stamp landed at 49ca418e), then re-run this write.\n"
            "        Row util-score-row-forwards-the-criterion-stamp-to-a-banner-it-never-checked-and-never-reads-the-row-back."
            % (SUITES_TSV, (_r or {}).get("today_pass"), (_r or {}).get("today_total"), ("PRESENT" if (_stamp and _cc.endswith(_stamp)) else ("ABSENT" if _stamp else "none forwarded")))
            + ("\n        excluded forwarded %r, row carries %r; secs forwarded %r, row carries %r" % (_exc, (_r or {}).get("today_excluded"), _secs, (_r or {}).get("today_secs")) if _exc_bad else ""))
    if SUITES_TSV == _root_suites_tsv() and not os.environ.get("S4E_SUITES_TSV") and not os.environ.get("S4E_PROGRESS_OFF"):
        # the REAL table only (a fixture's scratch table has no ledger to sum): keep this row's Wall the sum of each member's minimum, best effort -- a suite
        # whose key has no table (a bench or demo row graded whole) is left as it stood, and a refusal here never fails the row just written
        try:
            subprocess.run([sys.executable, os.path.abspath(__file__), "from-progress", "--suite", key, "--wall-only"], capture_output=True, text=True, timeout=300)
        except Exception:
            pass
    return "  suite table: %s -> %s/%s on %s (tree %s) -- SUITES.tsv rewritten in the same call%s%s%s" % (key, p, t, day, tree, (" · criterion stamped and read back" if _stamp else ""), (" · EXCLUDED=%d read back" % _exc if _exc is not None else ""), (" · WALL=%ds read back" % _secs if _secs is not None else ""))


def write_suite_row_only(a):
    """--column bench-ref: the SUITES.tsv row and its SCORE.md suite-table line, and NO grid cell (see SUITE_ONLY).

    Every guard a board write passes is kept, in the same order: the roster, the cgroup kill and the moved binary are
    checked by cmd_write before this is reached; here the clean pushed tree, then suite_sync_decide (every refusal settled
    before a byte moves -- the denominator stamp, the CEO-750 cross-check against the progress rows on the stamped tree),
    then per-row TREE ANCESTRY (CEO-492, read from the row's own tree column, since this path has no cell to read it
    from), then the write, which util_suite_banner.py --set makes, re-rendering the one table line, and READS BACK; then
    the verbatim board line is archived (CEO-827)."""
    suffix = SUITE_ONLY[a.column]
    text = (a.text or "").strip()
    if "\n" in text:
        die("--text spans lines; a board line is one line")
    if not re.search(r"\d", text):
        die("--text carries no digit (%r). A suite row states a measurement; pass the runner's own board line" % text)
    if os.path.abspath(SUITES_TSV) == os.path.abspath(_root_suites_tsv()):
        dirty = tree_is_dirty()
        if dirty:
            print("⚠ SUITE ROW SKIPPED — %s %s uncommitted; this run measured a tree nobody else can check out."
                  % (", ".join(dirty), "has" if len(dirty) == 1 else "have"))
            print("  The number above stands as a scouting datum. Commit the tree and re-run to land the row (ceo CEO-174).")
            return 0
        unpushed = tree_is_unpushed()
        if unpushed:
            print("⚠ SUITE ROW SKIPPED — %s %s on a local commit no remote branch contains; this run measured a tree nobody else can check out."
                  % (", ".join(unpushed), "is" if len(unpushed) == 1 else "are"))
            print("  The number above stands as a scouting datum. Push the branch and re-run to land the row.")
            return 0
    key, why = resolve_suite_key(a.lang, a.column, a.suite, getattr(a, "suite_key", "") or "")
    rows, _err = suites_rows()
    row = next((r for r in rows if r.get("key") == key), None) if key else None
    # ⛔ THIS PATH WRITES A ROW WITH NO GRID CELL, SO IT WRITES ONLY THE ROWS THAT HAVE NONE: an explicit --suite-key naming a rung suite
    # or a package row would publish that row while its grid cell kept the old number -- the two-records split CEO-363 closed.
    if key and (not key.endswith(suffix) or row is None or row.get("lang") != a.lang):
        die("--column %s writes only a %s-language row whose key ends in %s, and %r is %s. A rung suite or a package row is written\n"
            "        with its grid cell (--column board / vendor), never through this path.\n"
            "        NOTHING WAS WRITTEN: SCORE.md and SUITES.tsv are both untouched."
            % (a.column, a.lang, suffix, key, ("not a SUITES.tsv key" if row is None else "language %r" % row.get("lang"))))
    decided = suite_sync_decide(a)
    tree = suite_tree_stamp()
    old_tree = (row or {}).get("tree", "").strip()
    rel = tree_ancestry(tree.replace("-DIRTY", ""), re.sub(r"-(DIRTY|dirty)$", "", old_tree)) if old_tree else "newer"
    if rel == "older":
        die("suite row %r is ALREADY STAMPED ON A NEWER TREE than the one this write measured: this write measured SCRIP `%s`, the row\n"
            "        reads `%s`, and `%s` is a strict ANCESTOR of it. Rewriting it would move the board BACKWARDS while looking like an\n"
            "        update (CEO-492). Pull, re-run on the tree you now hold, and write THAT number.\n"
            "        NOTHING WAS WRITTEN: SCORE.md and SUITES.tsv are both untouched." % (key, tree, old_tree, tree))
    if rel is None:
        print("  ⚠ ancestry NOT checked against SCRIP `%s` (the row's tree): this checkout does not know that commit, so whether "
              "this write moves the row forward or backward was not established." % old_tree)
    if a.dry_run:
        print(suite_sync(a, tree, True, decided))
        archive_board_line(a.text, key, a.measurer, tree, dry=True)
        print("  grid: --column %s is a suite-table row only; no SCORE.md grid cell is written (the B cell is the timing reading)" % a.column)
        print("  (DRY RUN -- nothing written)")
        return 0
    print(suite_sync(a, tree, False, decided))
    _arch = archive_board_line(a.text, key, a.measurer, tree)
    print("⛔ NOT DONE UNTIL PUSHED: commit .github/SCORE.md (its suite-table line, re-rendered in this call; SUITES.tsv is %s, written in place)" % SUITES_TSV
          + (" AND %s" % os.path.relpath(_arch, os.path.join(S4E, ".github")) if _arch else "")
          + " with the landing that carried this measurement.")
    return 0


def cmd_write(a):
    # ⛔ A PORT ENGINE NEVER WRITES SCRIP'S ROW (CEO-1822): write sets the bare suite's cell, which is SCRIP's reading; a package runner run
    # under S4E_ENGINE=<port> records its rows keyed <suite>@<port>, and the port's row is from-progress --suite <suite>@<port>
    _eng = os.environ.get("S4E_ENGINE", "").strip() or "scrip"
    if _eng != "scrip":
        die("S4E_ENGINE=%s: write sets SCRIP's row for %s; a port engine's row is from-progress --suite <key>@%s -- nothing written" % (_eng, a.suite, _eng))
    _suite_table_lock()
    if not a.measurer or a.measurer.strip().lower() in _PLACEHOLDER_MEASURERS:
        stale = a.measurer
        a.measurer = os.environ.get("S4E_SEAT", "").strip() or derive_measurer()
        if not a.measurer:
            die("--measurer is required: an unattributed row is a claim with nobody behind it "
                "(got %r, and the root %r is not in the seat map, so it could not be derived)" % (stale, S4E))
        if stale:
            print("⚠ measurer %r is a placeholder, not an identity -- derived %r from the root %s instead "
                  "(the caller should pass ${S4E_SEAT:-} and let this helper resolve it)."
                  % (stale, a.measurer, S4E))
    # ⛔ THE ROSTER IS ASKED BEFORE EITHER WRITE PATH (see one_runner_declines): the grid-direct columns write the
    # leaderboard just as the display columns do, so a guard on one of the two would have left half the runners
    # writing -- and the half it left would be the half nobody was watching.  Checked here, once, ahead of the
    # dispatch, so there is exactly one site to read and no way for the two paths to drift apart.
    # ⛔⭐ A DRY RUN PREVIEWS THE WRITE **AND** THE REFUSAL, OR IT IS NOT A PREVIEW OF THIS COMMAND
    # (hq_T 2026-09-13, on the cfo's measured report; this call site previously skipped the roster check
    # entirely under --dry-run, on the reasoning below that a preview writes nothing so cannot need
    # refusing). The reasoning was right about the MECHANISM and wrong about the QUESTION. --dry-run is
    # what a seat runs to find out whether their cell will land before they land it, and on the same tree
    # where the real write refused for identity it printed a clean "WOULD REWRITE grid L for snobol4"
    # with was/now cells and no hint that the real path would decline -- so the preview promised a write
    # the command refuses. ⭐ The cure is NOT to refuse the dry run, which would throw away the was/now
    # comparison that is the whole reason to run one: it is to preview BOTH halves, the cell AND the
    # verdict on whether it lands. Same principle as the --dry-run fix at the display/grid split below:
    # a preview that covers one of a command's two outcomes is a preview of a different command.
    # ⛔ A CGROUP MEMORY KILL CUT THIS RUN -> no row (row instrument-698-runners-..., the coo 2026-09-23): a board whose scope's
    # oom_kill count rose since the board started (S4E_MEM_OOM_AT_START) graded some program into a kill, which is COULD-NOT-
    # MEASURE, so the row it would publish is DARK wearing a number (CEO-750's rule, one level up).
    try:
        sys.path.insert(0, HERE); import util_mem_scope as _ms
        _mk = _ms.kills_since_start()
    except Exception:
        _mk = None
    if _mk and not getattr(a, "dry_run", False):
        die("A CGROUP MEMORY KILL CUT THE RUN THAT PRODUCED THIS ROW -- %s NOTHING WAS WRITTEN." % _mk)
    # ⛔ THE BINARY MOVED UNDER THIS BOARD -> no row (coo 2026-09-16, hq_raku's RakRungs 764/927 graded across a mid-run make): the stamp
    # one_runner_guard exported at the board's start is compared to the binary now, before anything is written.
    try:
        sys.path.insert(0, HERE); import util_progress_append as _upa
        _moved = _upa.binary_moved_since_start()
    except Exception:
        _moved = None
    if _moved and not getattr(a, "dry_run", False):
        die("THE BINARY MOVED UNDER THIS BOARD -- start [%s] end [%s]: ./scrip or out/libscrip_rt.so was rebuilt while the board that produced "
            "this row graded, so the row describes no single binary. NOTHING WAS WRITTEN. Re-run the board on a quiet tree." % _moved)
    _decl = one_runner_declines(a.measurer, "%s / %s = %s" % (a.lang, a.column, a.text.strip()), a.lang)
    if _decl:
        if not getattr(a, "dry_run", False):
            # NAMED, byte-unchanged, and NON-FATAL (rc=0): test_gate_score_row_only_the_one_runner_writes.sh arm 1 holds the
            # standing ruling that a bookkeeping refusal must never red a MEASURED board; CEO-786's baton wording (rc=2)
            # is reported to the ceo as a conflict with that ruling, not resolved here by one seat (coo 2026-09-16).
            print(_decl)
            return 0
        # ⛔ THE DRY-RUN VERDICT IS ITS OWN SENTENCE, NOT A REPLAY OF THE REAL-RUN REFUSAL, and the
        # distinction is not cosmetic. The real path says "SCORE.md NOT UPDATED", which is a statement
        # about a write that was ATTEMPTED and declined; under --dry-run no write is attempted either
        # way, so replaying that line asserts something false about what just happened AND makes a
        # preview indistinguishable from a refused write -- which is precisely what
        # test_gate_score_row_only_the_one_runner_writes.sh arm 9 exists to forbid, and it caught this
        # draft. ⭐ The arm was right and its own title said so ("--dry-run is PREVIEWED, never
        # refused"); the first cure here would have satisfied the cfo's complaint by breaking hq_B's
        # guard, and the cure that satisfies both is to say the true thing in the right tense.
        print("⚠ PREVIEW ONLY, AND THE REAL WRITE WOULD DECLINE: seat %s is not %s, the lane owner for this board, so "
              "re-running this WITHOUT --dry-run would write nothing either. The cell below is what the "
              "row WOULD say when the one runner next measures it -- read it as your own board line, not "
              "as a row that is about to land. (THE ONE DOOR: S4E_SCORE_WRITE=\"why\" writes the row and prints the "
              "reason. S4E_ONE_RUNNER_OVERRIDE admits the board RUN only, never the write -- ceo CEO-961; the bus's "
              "computed `done` is not a door either -- ceo CEO-997; and S4E_SCORE_NO_WRITE=\"why\" shuts the write "
              "from the caller's side, above every other door, for a gate or a control arm.)"
              % (a.measurer or "?", (lane_writer_seat(a.lang)[0] or board_writer_seat()[0] or "?")))
        print("--- preview follows (nothing is written under --dry-run) ---")
    if a.column in GRID_DIRECT:
        return write_grid_direct(a)
    if a.column in SUITE_ONLY:
        return write_suite_row_only(a)
    if a.column not in COLUMNS:
        die("unknown --column %r. Known: %s" % (a.column, ", ".join(sorted(COLUMNS))))
    text = a.text.strip()
    if "|" in text or "|" in a.measurer:
        die("a '|' in the cell text would silently split the markdown row into the wrong columns -- rephrase it")
    # ⛔ ';' IS merge_clause's OWN DELIMITER (and merge_prov's), so text carrying one gets silently
    # torn apart the NEXT time anyone writes into a shared clause cell -- measured live landing the
    # IPL row: a --text with two internal ';'s left two orphaned clause fragments (neither started
    # with the --suite key, so neither matched, so neither got replaced or removed) sitting beside
    # the real clause on the very next write. ⭐ REFUSING outright used to make this PERMANENT for any
    # cell whose only honest phrasing needs one: the snobol4 vendor cell was hand-written with
    # semicolons months before this guard existed, so no runner could ever write that cell again --
    # measured twice in one sitting landing spitbol_testpgms (row
    # score-row-write-refuses-a-semicolon-forever-so-a-hand-edited-cell-can-never-be-runner-written).
    # NORMALISE instead of refusing: a runner's ';' becomes '·' (the project's own convention already
    # used throughout SCORE.md), which keeps the ONE property this guard exists for -- the stored cell
    # never contains a raw ';' that isn't merge_clause's own inserted delimiter, so nothing fragments
    # on the next write -- without ever locking a cell out of being rewritten again.
    if ";" in text:
        normalised = text.replace(";", "·")
        print("⚠ ';' in --text is merge_clause's own clause delimiter -- normalised to '·' so this "
              "write cannot fragment on the next one: %r -> %r" % (text, normalised))
        text = normalised
    if not re.search(r"\d", text):
        die("--text carries no digit (%r). A leaderboard cell states a measurement; a cell with no number "
            "is prose, and the FACT RULE asks for the runner's own board line" % text)
    if "\n" in text:
        die("--text spans lines; a markdown table row is one line")
    # The clean-tree condition guards the REAL leaderboard only. selftest writes to a scratch copy, whose
    # whole purpose is to be written while the working tree is mid-change; applying it there would make the
    # gate fail for every seat who ran it during a landing, i.e. exactly when it matters.
    if os.path.abspath(SCORE_MD) == os.path.abspath(os.path.join(S4E, ".github", "SCORE.md")):
        dirty = tree_is_dirty()
        if dirty:
            print("⚠ SCORE.md ROW SKIPPED — %s %s uncommitted; this run measured a tree nobody else can check out."
                  % (", ".join(dirty), "has" if len(dirty) == 1 else "have"))
            print("  The number above stands as a scouting datum. Commit the tree and re-run to land the row"
                  "  (ceo CEO-174: a dirty-tree number describes no checkable tree).")
            return 0
        unpushed = tree_is_unpushed()
        if unpushed:
            print("⚠ SCORE.md ROW SKIPPED — %s %s on a local commit no remote branch contains; this run measured a tree nobody else can check out."
                  % (", ".join(unpushed), "is" if len(unpushed) == 1 else "are"))
            print("  The number above stands as a scouting datum. Push the branch and re-run to land the row"
                  "  (hq_S 2026-09-05: the guard tested dirtiness, but the rule is about checkoutability).")
            return 0
    lines = open(SCORE_MD, encoding="utf-8").read().split("\n")
    hdr, rows, skipped = find_table(lines)
    if a.lang in skipped:
        _ln, _n = skipped[a.lang]
        die("row %r EXISTS at %s line %d but carries %d columns where this table has %d, so it was SKIPPED -- "
            "it is MALFORMED, NOT ABSENT. Repair that row's '|' count and re-run; nothing about this language "
            "or this helper's registry is at fault. (Every other reader omits it too, and the other two do so "
            "SILENTLY: `check` drops its staleness and `agree` mirrors none of its cells.)"
            % (a.lang, SCORE_MD, _ln + 1, _n, PROV_COL + 1))
    if a.lang not in rows:
        die("no row for language %r in the grid. Rows present: %s" % (a.lang, ", ".join(sorted(rows))))
    i, cells = rows[a.lang]
    idx = COLUMNS[a.column][0]
    stamp = "%s · RT_OPT=%s · %s · %s" % (tree_stamp(), rt_opt(), time.strftime("%Y-%m-%d %H:%M %Z"), a.measurer)
    if a.modes:
        stamp = "%s · modes %s" % (stamp, a.modes)
    before = cells[idx]
    # --suite names ONE measurement inside a cell that holds several. Without it the cell is replaced
    # wholesale, which is right for `board`/`entries` (one suite, one number) and wrong for `vendor`.
    # ⭐ The provenance clause is keyed by the SUITE name when there is one, not "column/suite" -- because
    # the cell already uses bare suite names (`Arizona:`, `JCON:`, `STRICT:`, `smoke:`) and a new key shape
    # would sit beside the old clause instead of replacing it. Match the file's convention, don't impose one.
    key = a.suite or a.column
    # ⛔⭐⭐ A REWRITE WHOSE TREE IS AN ANCESTOR OF THE TREE ALREADY STAMPED IS REFUSED (ceo CEO-492, off
    # hq_S's 2026-09-10 incident -- see tree_ancestry for the full witness). It publishes a number measured
    # further BACK than the one it replaces, and every surface reads it as an update: the row is rewritten
    # in place, the provenance clause is stamped with this run's clock and this run's measurer, and `check`
    # then grades the row against the OLDER tree and calls it fresh. The board goes backwards while every
    # instrument on it says forwards.
    # ⭐ THE COMMON WAY IN IS NOT A RACE, IT IS A CHECKOUT NOBODY PULLED. A seat measures a suite on the tree
    # it happens to hold, another seat lands a cure and writes the row, and the first seat's write arrives
    # minutes later carrying an honest number about a tree that no longer describes the compiler. Both
    # numbers are real; only one of them is about the head of the project. Ancestry is the ONLY fact that
    # separates them, and it is the one fact the row text does not carry.
    # ⛔ NO --force AND NO ENV OVERRIDE, for the reason the dirty-tree guard gives one screen up: an opt-out
    # on the highest-traffic board becomes the path taken by whoever is in the biggest hurry, which is
    # exactly the seat racing another seat's landing. The cure is to pull and re-run -- which is the same
    # work the number was going to need anyway, merely done before it is published rather than after.
    _new_tree = (TREE_HASH_RX.findall(stamp) or [None])[0]
    _unknown = []
    for _where, _old_tree in stamped_trees(before, cells[PROV_COL], key):
        _rel = tree_ancestry(_new_tree, _old_tree)
        if _rel is None:
            _unknown.append((_where, _old_tree))
        elif _rel == "older":
            die("%s/%s is ALREADY STAMPED ON A NEWER TREE than the one this write measured, and rewriting it "
                "would move the board BACKWARDS while looking like an update.\n"
                "  this write measured : SCRIP `%s`\n"
                "  already on the board: SCRIP `%s`  (from %s)\n"
                "  and `%s` is a strict ANCESTOR of `%s` -- git merge-base says so; the row text does not, "
                "which is why nobody catches this by reading it.\n"
                "  currently on the board: %s\n"
                "  you were about to write: %s\n"
                "  ⭐ CURE: pull, re-run the suite on the tree you now hold, and write THAT number. If the "
                "older measurement is genuinely the one to publish (the newer row is wrong, not merely "
                "later), that is a judgement about two measurements and a human makes it by hand -- this "
                "helper does not rank them for you.\n"
                "  NOTHING WAS WRITTEN."
                % (a.lang, a.column, _new_tree, _old_tree, _where, _new_tree, _old_tree,
                   before[:200], text[:200]))
    for _where, _old_tree in _unknown:
        # ⛔ SAY WHEN THE QUESTION WENT UNANSWERED. A guard that is silent both when it checked and when it
        # could not check teaches the reader that silence means checked -- the false-green shape this file
        # spends its length on. This is a note, not a refusal: an unresolvable hash is usually a tree this
        # checkout has never fetched, and refusing on it would block a correct write over a missing fetch.
        print("  ⚠ ancestry NOT checked against SCRIP `%s` (%s): this checkout does not know that commit, so "
              "whether this write moves the board forward or backward was not established." % (_old_tree, _where))
    # ⛔ A WHOLESALE OVERWRITE MUST NOT SILENTLY DISCARD PROSE IT NEVER MODELLED (see cell_prose_loss).
    # Scoped to the no-suite path on purpose: --suite already merges via merge_clause, touching only its
    # own clause, and no incident has been measured against that narrower path -- guarding it too would be
    # speculative rather than measured, so it is left for a future row if one ever is.
    # ⭐ MODELLED AS A SUPERSESSION, NOT A REFUSAL (see SUPERSEDE_MARKER above for the full reasoning and
    # why this does not reopen hq_T's REFUSE ruling). The MOST RECENT reading inside `before` rides
    # forward BYTE-FOR-BYTE, so nothing live is lost by construction -- the defensive re-check below is
    # what makes that a proof, not an assumption.
    # ⛔⭐ FOLD DEPTH IS CAPPED AT ONE ARCHIVED READING (hq_T ruling on
    # ruling-supersede-fold-approved-with-a-bound). Carrying the FULL `before` forward every time embeds
    # an already-superseded chain again on every later fold, so the cell grows by its whole history on
    # every landing -- measured live: the snobol4 board cell is already ~20 KB on one line. Anything past
    # the first SUPERSEDE_MARKER in `before` was already labelled not-asserted by an earlier fold, so
    # dropping it loses no claim anyone was still entitled to rely on.
    if a.suite:
        # ⛔⭐ THE --suite WRITE MUST LAND ON THE NUMBER THE CELL LEADS WITH, OR REFUSE (see
        # suite_target_conflict: hq_I's 2026-09-06 dry-run on icon/vendor/Arizona). A label match is not
        # enough to say which of several readings is load-bearing once a cell carries its own history.
        kind, heads = suite_target_conflict(before, a.suite)
        if kind:
            # ⛔⭐ THE CURE TEXT IS PER-KIND, because the two kinds need OPPOSITE edits and a combined list
            # sends half its readers the wrong way (hq_I, 2026-09-06, three attempts). `unreachable` means
            # the ONE reading present cannot be reached -- the fix is structural, on that reading, and the
            # blocker line above already names it exactly; telling that reader to "give it a bare key" is
            # wrong advice when it already has one. `multi` means several readings compete -- the fix is to
            # retire the archived one, which is a judgement about the prose.
            head_lines = "\n".join("  head @%d of %d: ...%s..." % (off, len(before), c.replace("\n", " "))
                                   for off, c in heads)
            blockers = _blockers_block(before, a.suite, heads)
            if kind == "multi":
                what = ("states a measurement for it in %d separate places and merge_clause would rewrite "
                        "exactly ONE of them" % len(heads))
                cure = ("  The cell carries its own history, so which occurrence is load-bearing is a "
                        "judgement about what the prose MEANS -- this helper does not make it.\n"
                        "  ⭐ RETIRE THE ARCHIVED READING, and the way to do it is THIS FILE'S OWN CONVENTION, "
                        "not a new one: take the NUMBER out of it -- spell the numerals out (`forty-six of one "
                        "hundred twenty-four`) or move it to the detail row. SCORE.md already does this and "
                        "says why: \"NUMERALS IN THIS EXPLANATION ARE SPELLED OUT ON PURPOSE: as digits they "
                        "are re-parsed as live cells, so the explanation RECREATES the conflict it "
                        "describes.\"\n"
                        "  ⛔ Re-labelling it (`%s (superseded): 46/124`) does NOT work -- this guard sees "
                        "DIGITS, not labels, so a relabelled archive is still a competing reading.\n" % a.suite)
            else:
                what = ("already states a measurement for it, in a form merge_clause cannot match -- so it "
                        "would APPEND a second reading beside the first")
                cure = ("  ⭐ FIX THE READING THAT IS ALREADY THERE -- do NOT add a second one, and do not "
                        "re-key it if it is already keyed. The blocker above names the one thing standing in "
                        "the way; there is exactly one reading here and it only has to become reachable.\n")
            die("--suite %r cannot be targeted in %s/%s: the cell %s, silently, leaving the other(s) in "
                "place and stamped current by this run's provenance. That is one cell asserting two "
                "numbers, and the one a reader sees first is not necessarily the one that moved.\n"
                "%s\n%s%s"
                "  Then re-run. NOTHING WAS WRITTEN."
                % (a.suite, a.lang, a.column, what, head_lines, blockers, cure))
        cells[idx] = merge_clause(before, a.suite, text)
    else:
        new_text = text
        lost = cell_prose_loss(before, text)
        if lost:
            # ⛔⭐ SPELLED **BEFORE** THE LOSS CHECK, and that ordering is the whole trick. The invariant
            # this fallback rests on is that `carried` is a LITERAL SUBSTRING of the result, which is what
            # makes cell_prose_loss empty by construction rather than by hope. Neutralising the fractions
            # afterwards would break that substring silently and the die() below would fire on every fold;
            # neutralising first keeps the proof exact, with the spelled text as its own reference.
            carried = spell_fractions(before.split(SUPERSEDE_PREFIX, 1)[0].rstrip())
            new_text = "%s %s %s" % (text, supersede_marker(cells[PROV_COL], key, time.strftime("%Y-%m-%d"), a.measurer or "unknown"), carried)
            still_lost = cell_prose_loss(carried, new_text)
            if still_lost:
                die("internal error modelling %s/%s: folding the kept reading forward still lost %d "
                    "sentence(s), which should be impossible when it rides forward verbatim -- "
                    "hand-edit the cell instead of trusting this writer:\n%s"
                    % (a.lang, a.column, len(still_lost), "\n".join("  - %s" % l for l in still_lost)))
        cells[idx] = new_text
    _prov_before = cells[PROV_COL]
    cells[PROV_COL] = merge_prov(cells[PROV_COL], key, stamp)
    newline = "| " + " | ".join(cells) + " |"
    lines[i] = newline
    # ⛔⭐⭐ WRITE UPDATES BOTH TABLES, OR SAYS OUT LOUD THAT IT COULD NOT. Until now a runner wrote only the
    # standardized DISPLAY row, so every board run silently staled the September-10 grid cell beside it --
    # the dual-write gap the agree gate reports as one-sided populations (20 of them the day this landed),
    # and the reason that gate re-reds itself no matter who reconciled it last. hq_C measured the same
    # thing independently and named the cure: the writer must move both halves.
    # ⛔ IT NEVER OVERWRITES PROSE TO DO IT. The grid's M and V cells carry hand-written commentary that no
    # runner models, so the grid write is attempted ONLY when it would drop nothing (cell_prose_loss empty
    # -- the same detector hq_B validated on the real .github 46ff295c incident). When prose IS at risk the
    # display still lands, the grid is left alone, and the runner NAMES the cell and the sentence.
    # ⭐ THAT REFUSAL IS THE POINT, NOT A SHORTFALL. hq_B's preserve-or-refuse question is RULED REFUSE here
    # (see the ask on that row): the endangered prose was written ABOUT THE OLD MEASUREMENT, so carrying it
    # forward automatically would attach an old sentence to a new number -- silently converting a true
    # statement into a false one, which is the very failure class the prose guard exists to stop, merely
    # relocated. A human decides whether a sentence survives its number. What changes today is that a
    # staling grid cell stops being SILENT: before, it just drifted; now the write that stales it says so
    # at the moment it happens, with the cell and the blocking sentence named.
    gkey = GRID_MIRROR.get(a.column)
    gnote = ""
    _gconflict = False
    _gnum_update = False
    _gexpect = None   # (grid line index, suite, fraction) to READ BACK after the write
    if gkey:
        try:
            _gh, growsg, gskipw = find_grid(lines)
        except SystemExit:
            growsg, gskipw = {}, {}
        if a.lang in gskipw:
            # ⛔ The grid row EXISTS and cannot be read. Saying nothing here would let a write land in the
            # display while its grid twin quietly stops being staleness-checked -- the silence this whole
            # patch is about. It is a note, not a refusal: the display write itself is still honest.
            _gl, _gn = gskipw[a.lang]
            gnote = ("\n  ⚠ the September-10 grid row for %s is MALFORMED, NOT ABSENT (line %d has %d columns, "
                     "the grid has %d) -- its cell was NOT staleness-checked against this write" % (a.lang, _gl + 1, _gn, GRID_NCOLS))
        if a.lang in growsg:
            gi = GRID_COLUMNS[gkey][0]
            grow = growsg[a.lang]
            gbefore = grow[gi]
            # Strip any prior stamp before comparing, or the marker this write appended last time would
            # itself read as prose the next write is about to lose.
            gbare = re.sub(r"\s*" + GRID_STAMP_RE + r"\s*$", "", gbefore).strip()
            gnew = merge_clause(gbare, a.suite, text) if a.suite else text
            # ⛔⭐⭐ THE SAME LANGUAGE+SUITE LIVES ON TWO LINES OF THIS FILE, AND ONLY ONE OF THEM IS BEING
            # WRITTEN (hq_I 2026-09-06, measured: icon vendor sits at BOTH the September-10 grid and the
            # standardized display; a hand-edit reached one, this helper targets the other, and the board
            # asserted 47/90 on one line and 46/89 on the other -- both stamped current -- for about an
            # hour). That is the within-cell ambiguity guard's defect one level up: BETWEEN cells rather
            # than inside one, and invisible to a guard that only ever reads the cell it is writing.
            # ⭐ REPORTED, NOT REFUSED, and the asymmetry is deliberate. Within a cell, the write would land
            # in the WRONG PLACE, so refusing is the only honest answer. Here the write lands correctly and
            # it is the OTHER line that is stale -- and that line refuses auto-update by design (it carries
            # prose no runner models), so a refusal would lock every vendor write out of the board forever
            # to punish a staleness this very message exists to announce.
            # ⛔ WHAT WAS MISSING WAS NEVER THE WARNING, IT WAS THE NUMBER. The grid note already said "NOT
            # updated"; it did not say what the grid currently CLAIMS, so a reader could not tell a stale
            # restatement of the same figure from a live contradiction. hq_I found the conflict only by
            # checking WHERE the text landed rather than that rc=0. Name both readings and it is one glance.
            if a.suite:
                # ⛔⭐ THE BARE-N/M FALLBACK IS DELETED, and seat02 measured why (routed by hq_P 2026-09-06).
                # It read `suite_readings(text) or re.findall(r"\d+/\d+", text)`, so when a runner writes its
                # clause as PASS=/FAIL= with no literal pass-over-total -- test_snoflake_suite.sh does -- the
                # fallback matched the first bare fraction ANYWHERE in the cell. It grabbed an NSTD
                # sub-fraction (1/7, 1/6) and raised a CONFLICT against a grid cell of 129/180 that was not
                # stale at all: verified by hand against a fresh m3 measurement. A false alarm on a correct
                # board is worse than silence, because the reader who checks it and finds nothing wrong stops
                # checking. ⭐ hq_P's sentence is the rule: A FALLBACK THAT MATCHES ANY N/M ANYWHERE IN THE
                # TEXT IS NOT A FALLBACK, IT IS A SECOND, WORSE PARSER -- and the second parser answers a
                # different question than the first while wearing its name. No reading is NO READING: the
                # comparison is simply not made, and the note below says so, rather than inventing one.
                _gr, _tr = suite_readings(gbare, a.suite), suite_readings(text, a.suite)
                _grs, _trs = {x.replace(" ", "") for x in _gr}, {x.replace(" ", "") for x in _tr}
                if _grs and not _trs:
                    gnote = ("  ⚠ grid %s NOT compared for `%s`: that line states %s, and this write's board "
                             "line carries no pass-over-total fraction for that suite, so there is nothing to "
                             "compare it against. This is NOT agreement -- it is one reading, unchecked.\n"
                             "      Give the board line an N/M fraction for the suite if you want the grid "
                             "conflict check to cover it."
                             % (gkey, a.suite, " · ".join(sorted(_grs))))
                # ⛔⭐ A CONFLICT REQUIRES A SHARED DENOMINATOR, and this is the rule the sibling gate already
                # runs on: test_gate_score_tables_agree fails a SAME-DENOMINATOR disagreement ("both tables
                # name an 81-population, one says 39 and the other 41 -- one is wrong and a reader cannot tell
                # which") and merely REPORTS a population present on one side only, because the two lines
                # legitimately summarise at different grains. This check had no such rule and convicted on
                # bare set-disjointness, so ANY two readings that were not identical read as a contradiction.
                # ⛔ seat02 measured the cost (routed by hq_P): their snoflake clause is written PASS=/FAIL=
                # with an NSTD aside, so the readings came back 1/7 and 1/6 and were declared to CONFLICT with
                # a grid cell of 129/180 that was not stale at all -- verified by hand against a fresh m3
                # measurement. ⭐ AND MY FIRST CURE WAS AIMED AT THE WRONG FUNCTION: the diagnosis handed to me
                # blamed the bare-N/M fallback below, but measuring it showed suite_readings ITSELF returns
                # 1/7 and 1/6 -- it takes every fraction within 90 characters of the head, so a parenthetical
                # aside reads exactly like a headline. Deleting the fallback was right on its own terms and
                # does not fix this; narrowing that window would decide another lane's cell semantics on my
                # judgement, and a wrong narrowing SUPPRESSES REAL CONFLICTS, which is far worse than a false
                # alarm. The denominator rule needs no such judgement: two readings over different populations
                # are not in disagreement, they are not comparable, and the note now says which.
                elif _grs and _trs and not ({x.split("/")[1] for x in _grs} & {x.split("/")[1] for x in _trs}):
                    gnote = ("  ⚠ grid %s NOT compared for `%s`: that line states %s and this write states %s, "
                             "over DIFFERENT populations -- no shared denominator, so these are not two "
                             "readings of one thing and disagreement cannot be inferred.\n"
                             "      If one of them is the stale one, land the same number on both lines."
                             % (gkey, a.suite, " · ".join(sorted(_grs)), " · ".join(sorted(_trs))))
                elif _grs and _trs and not (_grs & _trs):
                    # ⛔⭐ ONE MEASUREMENT, TWO CELLS, ONE WRITE (coo 2026-09-16; hq_pascal's PAT 297 display / 296 grid V, and 271 / 283 the
                    # other way the same day; row util-score-row-write-can-leave-the-grid-cell-behind-the-display-cell-...). The grid clause
                    # for this suite carries a fraction over the SAME denominator: that is a NUMBER to move, not prose to model, so it is
                    # replaced IN PLACE -- the grid's own provenance prose survives -- and read back after the write (below). A conflict
                    # that used to leave the grid stale by design now lands on both lines or on neither.
                    _new = sorted(_trs)[0]
                    _gfix = gbare
                    for _old in sorted(_grs):
                        _n, _d = _old.split("/")
                        _gfix = re.sub(r"\b%s\s*/\s*%s\b" % (re.escape(_n), re.escape(_d)), _new, _gfix)
                    if set(x.replace(" ", "") for x in suite_readings(_gfix, a.suite)) == {_new}:
                        gnew = _gfix; _gnum_update = True
                        gnote = ("  grid %s: the `%s` fraction moved in place with the display, %s -> %s (the grid cell's own prose kept)"
                                 % (gkey, a.suite, " · ".join(sorted(_grs)), _new))
                    else:
                        gnote = ("  ⛔ grid %s CONFLICTS with what you are writing for `%s`: that line states %s, "
                                 "this write states %s, and the fraction could not be replaced in place (%d readings in the cell's clause)."
                                 "\n      Land the same number on BOTH lines in this sitting -- hand-edit the grid cell."
                                 % (gkey, a.suite, " · ".join(sorted(_grs)), " · ".join(sorted(_trs)), len(_grs)))
                        _gconflict = True
            # ⛔⭐ cell_prose_loss ALONE IS THE WRONG GATE HERE AND MEASURING IT SAID SO. It answers "does
            # `new` still contain everything `before` said", so the OLD MEASUREMENT -- which this write
            # exists to supersede -- always reads as a lost sentence. Run against the live board it blocked
            # snobol4's grid cell, whose entire content is one measurement line and nothing else: the
            # dual-write would have refused every cell on the file and been useless while looking careful.
            # ⭐ So the auto-update is scoped to the case that is UNAMBIGUOUS rather than merely passing a
            # check: a grid cell that is ONE sentence carrying a measurement is a pure mirror of the display
            # number, with no human commentary to lose. The moment a cell has a second sentence, a person
            # wrote it, and a runner does not get to decide whether it survives its number.
            gchunks = [c for c in re.split(r'(?<=[.!?])\s+(?=[A-Z0-9⚠⛔⭐✅])', gbare) if c.strip()]
            gpure = len(gchunks) <= 1 and re.search(r"\d+\s*/\s*\d+|PASS=|FAIL=|\bpass\b", gbare or "", re.I)
            if _gnum_update:
                gpure = True   # an in-place fraction move loses no prose by construction
            glost = [] if gpure else cell_prose_loss(gbare, gnew)
            # ⛔⭐ THE GRID HALF READS THE SAME LINE BY NAME INSTEAD OF REFUSING IT (coo 2026-09-20, on hq_raku's
            # report of their first real write).  The refusal below is RIGHT about pass/(pass+fail) -- that
            # denominator is not the population and would publish 100% -- but `all_n=` IS the population, printed
            # by the harness itself beside `all_pass=`, so reading those two BY NAME is not a derivation at all.
            # Refusing the canonical board line on both halves is what forced every board-column write to restate
            # its own fraction on the command line.  The number is RESTATED into the grid cell as an explicit
            # `p/t` (the grid column is parsed for one) and the addition is PRINTED, never silent: the cell must
            # say what the display line already said, in the form the parser reads.
            # ⭐ PRINTED WHERE IT HAPPENS, NOT FOLDED INTO THE SUCCESS NOTE: the restatement is a fact about the TEXT,
            # and it is true whether or not the cell then survives the prose guard below.  A reader who meets that
            # guard must still be able to see that the fraction seam was closed.
            if not cell_fractions(gnew)[0]:
                _bgp, _bgt, _ = board_line_fraction(gnew)
                if _bgp is not None:
                    gnew = "%s · %s/%s" % (gnew, _bgp, _bgt)
                    print("  grid %s: the board line carries no N/M, so its OWN all_pass=%s all_n=%s were read by name "
                          "and restated as %s/%s in the cell (never derived from pass/(pass+fail))"
                          % (gkey, _bgp, _bgt, _bgp, _bgt))
            gnew = (gnew + " " + GRID_STAMP % (time.strftime("%Y-%m-%d"), a.measurer or derive_measurer() or "unknown")).strip()
            # ⛔⭐⭐ THE TWO COLUMNS HAVE DIFFERENT CONTRACTS AND A VERBATIM COPY BETWEEN THEM PUBLISHES A
            # WRONG PERCENTAGE. Measured by hq_P as the first customer of the dual-write, on the live board:
            # the DISPLAY board column wants "the runner's OWN printed board line", and `test_corpus_snobol4.sh`
            # prints `m3 PASS=1698 FAIL=0 · m4 PASS=1698 FAIL=0 SKIP=0 MISSING=0` -- which contains NO N/M
            # fraction. The GRID M column is PARSED for one. So the copy left a fractionless grid cell,
            # cell_fractions returned nothing for M, and the progress line silently fell back to the V column
            # alone: snobol4 read **55%** instead of 91% -- confidently wrong by 36 points, on the exact line
            # the ceo reads to answer Lon, and NOT marked `?`.
            # ⭐ PASCAL HID IT, which is the part worth keeping: pascal's board line happens to be phrased
            # `166/166 · 5/5 · 161/161`, so its fraction survived the copy and pascal stayed correct the whole
            # time. One language passing and one failing off the same code path for no reason but PROSE STYLE
            # -- which is exactly why it read as a snobol4 problem rather than as a dual-write problem, and why
            # checking one language would have cleared it.
            # ⛔ DERIVING A FRACTION IS THE OBVIOUS FIX AND IT IS WORSE THAN THE BUG. `PASS=1698 FAIL=0` does
            # not carry the population: the real denominator is 1736 (xfail and friends live outside the
            # pass/fail split), so pass/(pass+fail) would publish 1698/1698 = 100%. A silent 100% is far more
            # dangerous than a silent 55%. So this REFUSES the grid half and says what to do, the same shape
            # as the prose guard: wrong is worse than missing on this line.
            if _gconflict:
                pass
            elif not cell_fractions(gnew)[0]:
                gnote = ("  ⚠ grid %s NOT updated -- this board line carries NO `N/M` fraction, and the grid %s "
                         "column is PARSED for one. Writing it would leave a cell that reads as ZERO for this "
                         "population and publish a confidently wrong percentage rather than a `?`.\n"
                         "      text: %s\n"
                         "      Give the board line a fraction (e.g. `m3 1698/1736 FAIL=0`) so ONE text "
                         "satisfies both columns, then re-run. Do NOT let this helper derive pass/(pass+fail) "
                         "-- that denominator is not the population and would publish 100%%."
                         % (gkey, gkey, gnew[:200]))
            elif gbare == gnew:
                gnote = "  grid %s: already agrees, nothing to write" % gkey
            elif not gpure:
                # ⛔⭐ THE COUNT IN THIS MESSAGE USED TO BE A LIE, AND IT UNDERSTATED (hq_T 2026-09-06,
                # off hq_I's icon/vendor report). The fallback was `glost or [gbefore]`, so whenever
                # cell_prose_loss found nothing -- which is the NORMAL case here, since a cell that is
                # pure commentary loses nothing to a number -- it named the WHOLE CELL as one item and
                # printed "1 sentence(s)". The icon grid V cell carries EIGHT; snobol4's carries 26.
                # ⭐ hq_I read "1 sentence" and reasonably asked whether the grid half was a small gap or
                # a second defect. It is neither: it is the ruled REFUSE firing exactly as designed, on a
                # cell that is 1.6 KB of human commentary. But a guard that reports "1" for 8 invites
                # precisely that question, and the next reader will hand-fold one sentence and think they
                # are done. Count what is actually there; cap the LISTING, never the count.
                glost = glost or gchunks or [gbefore]
                _shown = glost[:3]
                _more = ("\n      ... and %d more (read the cell; this listing is capped, the count is not)"
                         % (len(glost) - len(_shown))) if len(glost) > len(_shown) else ""
                # ⛔⭐ STALE BY PROVENANCE AND STALE BY VALUE ARE DIFFERENT READINGS, AND THIS WARNING USED TO SPELL
                # THEM THE SAME (hq_raku 2026-09-20, from inside the guard: they met it on a landing that MOVED NO
                # PROGRAM -- the cell already said 830/927 and the write would have said 830/927 -- and declined both
                # exits on purpose, because hand-editing would have flattened six explanatory sentences to restate a
                # number that did not move).  A no-op write and a real divergence produced the SAME sentence, so the
                # seat had to OPEN the cell to tell which.  ⭐ The guard itself is untouched and still refuses: the
                # judgement stays with a human, which is the whole point of it.  What changes is that the message now
                # says which of the two it is, and the number it would have written is printed either way.
                # ⛔ COMPARED AS A SET OF DISTINCT p/t PAIRS, NEVER AS THE PARSER'S SHAPE. cell_fractions returns a
                # TUPLE per denominator in cell order, so a two-mode text ("m3 43/43 · m4 43/43") yields (43, 43)
                # against a one-mode cell's (43,) -- the same VALUE wearing a different shape. Comparing the raw
                # structures would call that a divergence and reintroduce the very confusion this names.
                def _frset(_g):
                    return {(_p, _d) for _d in (_g or {}) for _p in _g[_d]}
                def _frshow(_g):
                    return ", ".join("%s/%s" % (_p, _d) for _p, _d in sorted(_frset(_g)))
                _fb, _fn = _frset(cell_fractions(gbare)[0]), _frset(cell_fractions(gnew)[0])
                if _fb and _fn and _fb == _fn:
                    gnote = ("  ⚠ grid %s NOT updated -- ⭐ STALE BY PROVENANCE ONLY: the value this write would put in "
                             "the cell (%s) is what the cell ALREADY STATES, so the cell is not misleading -- only its "
                             "stamp is behind. It carries %d sentence(s) no runner models, and folding here would flatten "
                             "them to restate a number that did not move. Folding is OPTIONAL in this case; nothing is "
                             "published wrong by leaving it:\n%s%s"
                             % (gkey, ", ".join("%s/%s" % (_p, _d) for _p, _d in sorted(_fn)), len(glost), "\n".join("      - %s" % l[:160] for l in _shown), _more))
                else:
                    gnote = ("  ⚠ grid %s NOT updated -- STALE BY VALUE: this write's %s differs from the cell's %s, and it "
                             "carries %d sentence(s) no runner models, so this measurement now sits in the display only and "
                             "the grid cell is STALE BY THIS WRITE. Fold what is still true into --text, or hand-edit the "
                             "grid cell:\n%s%s"
                             % (gkey, ", ".join("%s/%s" % (_p, _d) for _p, _d in sorted(_fn)) or "<no fraction>",
                                ", ".join("%s/%s" % (_p, _d) for _p, _d in sorted(_fb)) or "<no fraction>", len(glost),
                                "\n".join("      - %s" % l[:160] for l in _shown), _more))
            else:
                for gl, gline in enumerate(lines):
                    if gline.startswith("| %s |" % a.lang) and gl != i:
                        gc = [x.strip() for x in gline.strip().strip("|").split("|")]
                        if len(gc) == GRID_NCOLS and gc[0] == a.lang:
                            gc[gi] = gnew
                            lines[gl] = "| " + " | ".join(gc) + " |"
                            gnote = ("  grid %s: updated in the same call (line %d)" % (gkey, gl + 1)) if not _gnum_update else gnote + " (line %d)" % (gl + 1)
                            if a.suite:
                                _gexpect = (gl, a.suite, sorted({x.replace(" ", "") for x in suite_readings(text, a.suite)}))
                            break
    # ⛔⭐⭐ --dry-run PREVIEWS BOTH HALVES OR IT IS NOT A PREVIEW OF THIS COMMAND (hq_T 2026-09-05, found
    # while measuring the ceo's minted grid-dual-write row). The early return used to sit ABOVE the entire
    # grid block, so --dry-run showed the display rewrite and NOTHING about the grid -- not the update, and
    # worse, not the loud REFUSALS the dual-write exists to emit (prose at risk, no N/M fraction). So the one
    # way to ask "what will this write do?" answered for half the command and looked complete doing it, and
    # the half it hid is exactly the half a caller cannot recover from later.
    # ⭐ The grid block above mutates `lines` IN MEMORY only; the file is written below. So the preview is
    # produced by running the real code path and declining to persist it, never by a second model of what it
    # would have done -- a preview that reasons about the writer instead of running it is the next drift.
    _provdup = prov_duplicate_note(a.lang, cells[PROV_COL])
    _decided = suite_sync_decide(a)
    if a.dry_run:
        print("WOULD REWRITE %s line %d" % (SCORE_MD, i + 1))
        print("  was: %s" % before)
        print("  now: %s" % cells[idx])
        print("  prov: %s" % cells[PROV_COL])
        if _provdup:
            print(_provdup)
        if gnote:
            print(gnote)
        elif not gkey:
            print("  grid: --column %s has no mirrored grid column, so this write touches the display only" % a.column)
        else:
            print("  ⚠ grid %s: no grid row for %s -- this write touches the display only" % (gkey, a.lang))
        print(suite_sync(a, suite_tree_stamp(), True, _decided))
        archive_board_line(a.text, _decided[0], a.measurer, suite_tree_stamp(), dry=True)
        _un = unchanged_reading_note("display row", a.lang, before, cells[idx], _prov_before, cells[PROV_COL], i + 1, key)
        if _un:
            print(_un)
        print("  (DRY RUN -- nothing written)")
        return 0
    _un = unchanged_reading_note("display row", a.lang, before, cells[idx], _prov_before, cells[PROV_COL], i + 1, key)
    if _un:
        print(_un)
    lines = mark_grid_stamp(lines)
    _write_score_md(lines)
    # ⛔ READ BOTH CELLS BACK: the display's and the grid's fraction for this suite must agree after the write, or the split state is
    # NAMED (one measurement, two cells, one write -- coo 2026-09-16). A gate plants a display-only write and proves this reds.
    if _gexpect:
        _gl, _gs, _want = _gexpect
        _back = open(SCORE_MD, encoding="utf-8").read().split("\n")
        _gc = [x.strip() for x in _back[_gl].strip().strip("|").split("|")]
        _got = sorted({x.replace(" ", "") for x in suite_readings(_gc[GRID_COLUMNS[gkey][0]] if len(_gc) > GRID_COLUMNS[gkey][0] else "", _gs)})
        if _want and _got != _want:
            die("SCORE.md was written but the grid %s cell READ BACK for `%s` states %s while this write states %s -- the display and the grid "
                "disagree on one measurement. ⛔ PARTIAL: fix the grid cell by hand in this sitting (line %d) and re-run test_gate_score_tables_agree.sh."
                % (gkey, _gs, " · ".join(_got) or "no fraction", " · ".join(_want), _gl + 1))
    print("SCORE.md: %s/%s rewritten in place (line %d)" % (a.lang, a.column, i + 1))
    if _provdup:
        print(_provdup)
    print("  was: %s" % before)
    print("  now: %s" % cells[idx])
    print("  prov: %s: %s" % (a.column, stamp))
    if gnote:
        print(gnote)
    print(suite_sync(a, suite_tree_stamp(), False, _decided))
    _arch = archive_board_line(a.text, _decided[0], a.measurer, suite_tree_stamp())
    print("⛔ NOT DONE UNTIL PUSHED: commit .github/SCORE.md (SUITES.tsv is %s, written in place)" % SUITES_TSV
          + (" AND %s" % os.path.relpath(_arch, os.path.join(S4E, ".github")) if _arch else "")
          + " with the landing that carried this measurement.")
    return 0


# ⛔⭐⭐ A WRITE WHOSE READING DID NOT MOVE STILL MOVES ITS STAMP, AND IT HAS TO SAY SO (coo 2026-09-20,
# on the ceo's reported finding; row a-refused-score-row-write-still-moved-a-provenance-stamp-on-a-row-nobody-
# measured).  THE OCCURRENCE, and it is the whole reason this function exists: the ceo found a one-line diff on
# the raku row -- SCRIP `2d403670f` -> `5367103df`, corpus `fcfeb6a92` -> `8d4656ada`, 2026-09-13 17:59 ->
# 2026-09-20 08:25, measurer hq_T -> ceo -- in a sitting where nothing he ran had measured raku, and every
# score-row run had REFUSED saying "NOTHING WAS WRITTEN".  He read it, reasonably, as a refusal manufacturing
# provenance, and reverted it.
# ⭐ IT WAS NOT.  Reproduced here character for character by a SUCCESSFUL `--lang raku --column floor` write
# whose --text was byte-identical to the cell already there: merge_prov restamps the clause, so tree, corpus,
# date and measurer all move and the NUMBER does not.  The only writer of that cell is test_smoke_raku.sh, which
# three gates invoke -- so a gate run had published a leaderboard row, and the publication was invisible BECAUSE
# the reading had not changed.  A diff that shows only a stamp reads, to every reader, as bookkeeping.
# ⛔ SO THE DEFECT IS NOT THE RESTAMP, WHICH IS HONEST -- the smoke really did run on the new tree and a
# re-confirmation IS information.  The defect is that it was SILENT.  A write that moves four provenance fields
# and no number is the one shape whose diff cannot be distinguished, by reading it, from a stamp manufactured by
# something that measured nothing; and the ADRIFT class this board already tracks is exactly "a tree and a
# measurer that moved under a number nobody re-measured".  The cure is not to suppress the restamp (that would
# throw away a true re-confirmation and make the cell read older than it is) -- it is to make the writer NAME
# the case, so the reader of the diff is told which of the two it is instead of having to guess.
def prov_clause_for(prov, key):
    """The `<key>:` clause of a provenance cell, or "".  ⛔ THE KEY MATTERS AND THE WHOLE CELL DOES NOT:
    a prov cell holds one clause per column (`smoke:`, `board:`, `entries:`, `floor:` ...), so reading the
    cell whole and taking its FIRST hash grades whichever clause happens to sort first -- which is how the
    first draft of unchanged_reading_note reported "provenance unchanged" on the exact occurrence it was
    written for: raku's cell leads with `smoke:`, whose tree had not moved, while `floor:` moved by four
    fields.  Same clause-splitting rule as supersede_marker, which is why it is one function."""
    for clause in (prov or "").split(";"):
        mm = re.match(r"^\s*([A-Za-z0-9_.-]+)\s*:", clause)
        if mm and mm.group(1) == key:
            return clause
    return ""


def unchanged_reading_note(kind, lang, before, after, prov_before, prov_after, line_no, key=""):
    """One loud line when a write re-stamps a cell it did not move.  Returns "" when the reading changed."""
    if (before or "").strip() != (after or "").strip():
        return ""
    if key:
        prov_before, prov_after = prov_clause_for(prov_before, key), prov_clause_for(prov_after, key)
    fields = []
    for label, rx in (("SCRIP tree", r"SCRIP `([0-9a-f]{7,40})`"), ("corpus", r"corpus `([0-9a-f]{7,40})`"),
                      ("date", r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2})"), ("measurer", r"·\s*\d{4}-\d{2}-\d{2}[^·]*·\s*([A-Za-z0-9_-]+)")):
        b = re.findall(rx, prov_before or "")
        a_ = re.findall(rx, prov_after or "")
        if b and a_ and b[0] != a_[0]:
            fields.append("%s %s -> %s" % (label, b[0], a_[0]))
        elif a_ and not b:
            fields.append("%s -> %s (none before)" % (label, a_[0]))
    if not fields:
        return "  ℹ reading unchanged and provenance unchanged -- this write is a no-op on %s %s (line %d)." % (kind, lang, line_no)
    return ("  ⛔ READING UNCHANGED, STAMP REFRESHED -- %s %s (line %d): the cell's NUMBER is byte-identical to what\n"
            "     was already there and this write moved only its provenance (%s).\n"
            "     ⭐ That is a RE-CONFIRMATION, not a new measurement, and it is stated because a diff showing only a\n"
            "     moved tree and date is otherwise indistinguishable from a stamp nothing measured (the ADRIFT class).\n"
            "     If you did NOT just re-run the measurement behind this cell, revert this hunk." % (kind, lang, line_no, " · ".join(fields)))


def mark_grid_stamp(lines):
    # ⛔⭐ THE WHOLE-GRID STAMP STOPS SPEAKING FOR ROWS IT NO LONGER MEASURED.  The `_tree: ... generated
    # ..._` line under the grid was written by util_build_score_md.py to pin the ONE tree that produced
    # ALL the cells above it -- true on the day of a full regeneration, and false the moment any row is
    # rewritten from a different tree.  Measured on this file 2026-09-03: the stamp read `generated
    # 2026-09-02T02:35Z` while six of eight rows carried 2026-09-03 provenance from four different
    # sessions.  That is not a stale label, it is a WRONG one -- it claims coverage it does not have,
    # and unlike a stale row nothing about it looks old.  So a row-write demotes it, once, to what it
    # is actually still evidence of.
    tag = "  (LAST FULL REGENERATION ONLY -- rows rewritten since carry their own tree in the last column)"
    for i, l in enumerate(lines):
        if l.startswith("_tree: ") and l.endswith("_"):
            if tag.strip() not in l:
                lines[i] = l[:-1] + tag + "_"
            return lines
    return lines


def cmd_check(a):
    # Staleness is measured against origin, never against the local checkout: a row is stale when the
    # WORLD has moved past the tree it was measured on, and a seat's own unpushed commits are not the
    # world.  A hash origin has never heard of is its own state (UNKNOWN), never silently zero.
    lines = open(SCORE_MD, encoding="utf-8").read().split("\n")
    hdr, rows, _skipped = find_table(lines)
    # ⛔ --no-fetch EXISTS SO THIS CAN SIT IN A TEST LOOP, AND IT DOWNGRADES THE CLAIM, NOT JUST THE COST.
    # Without a fetch, "behind origin/main" means behind the origin/main THIS CHECKOUT LAST HEARD ABOUT,
    # which understates staleness by however long since the last fetch. That is fine for a gate proving the
    # check RUNS, and not fine for a handoff answering "is the board current" -- so the two callers differ,
    # and the output says which question it answered rather than letting the reader assume the stronger one.
    if a.no_fetch:
        print("(--no-fetch: measured against this checkout's last-known origin/main, which may itself be behind)")
    else:
        for r in REPOS:
            if git(r, "fetch", "-q", "origin") is None and git(r, "rev-parse", "HEAD") is not None:
                print("WARN: could not fetch origin for %s -- staleness below may itself be stale" % r)
    worst, unknown, adrift, out = 0, 0, 0, []
    # ⛔⭐⭐ GRADE THE HASH A READER ACTUALLY SEES, NOT ONLY THE ONE IN THE Tree COLUMN (hq_T 2026-09-05,
    # off seat13's make-test refusal report).  Until now this scanned cells[PROV_COL] and nothing else, on the
    # premise that `write` stamps every measurement there -- which it does (merge_prov, one clause per column).
    # The premise holds for writes THROUGH THIS HELPER and silently fails for the hand-edit, and the board is
    # full of hand-edits.  The witness that found it: snobol4's Rungs board CELL reads "LANE RE-MEASURE
    # 2026-09-05 (hq_P) ... on SCRIP `f3f4870d7`", while its `board:` provenance clause still reads hq_B
    # 2026-09-04 on `7d7ff2dc5`.  One cell, two trees, two measurers, and `check` had never once graded
    # f3f4870d7 -- the number every human reader of that row is looking at.
    # ⛔ THE DANGEROUS DIRECTION IS THE QUIET ONE.  Here both trees happened to be past the threshold, so the
    # verdict survived and only the attribution was wrong.  Reverse the freshness and it inverts: a cell
    # re-measured by hand onto today's tree reads STALE off its old stamp (a seat re-runs a suite that was
    # already current), and -- worse -- a cell left stale beside a freshly-stamped clause reads **ok** and
    # nobody re-runs anything.  A staleness check that cannot see the cell it is grading is the FACT RULE's
    # own failure mode wearing the FACT RULE's clothes.
    # ⭐ So: scan every measured cell AND the Tree column, name where each tree came from, and give the
    # hand-edit its own state.  UNSTAMPED is not STALE and not UNKNOWN -- the tree may be perfectly current;
    # what is broken is that no provenance clause claims it, so nobody is named for the number and the next
    # `write` to that column will overwrite the stamp without touching the prose that disagrees with it.
    HASH_RX = TREE_HASH_RX   # ONE pattern for the whole file; see its definition for why not two.
    by_col = sorted((idx, key) for key, (idx, _label) in COLUMNS.items())
    _dist = {}

    def distance(h):
        # commits from h to origin/main; None when origin has never heard of h.  Memoized because the same
        # tree is routinely stamped in several columns and a rev-list per mention is pure cost.
        if h not in _dist:
            n = git("SCRIP", "rev-list", "--count", "%s..origin/main" % h)
            _dist[h] = None if n is None else int(n)
        return _dist[h]

    def newest(hashes):
        # The CURRENT claim of a cell is the newest tree it names -- fewest commits behind origin.  A measured
        # cell is a running history (⛔ SUPERSEDED READING BELOW ... and so on down), so the trees buried in
        # its prose are retired by construction and grading them is noise, not coverage.  Ranking by commit
        # DISTANCE and not by position is what makes that safe: it does not care whether the newest reading
        # was appended at the top, spliced into the middle, or introduced by a word this parser never models.
        ranked = [(distance(h), h) for h in set(hashes)]
        live = sorted((d, h) for d, h in ranked if d is not None)
        return (live[0] if live else (None, sorted(h for d, h in ranked)[0] if ranked else None))

    for lang in sorted(rows):
        i, cells = rows[lang]
        # The Tree column is ';'-joined "<key>: <stamp>" clauses (merge_prov), one per measured column plus a
        # free-form one per vendor suite.  Split it so a stamp can be held against the very cell it stamps.
        stamp_of, extra = {}, []
        for clause in cells[PROV_COL].split(";"):
            hs = HASH_RX.findall(clause)
            if not hs:
                continue
            mm = re.match(r"^\s*([A-Za-z0-9_.-]+)\s*:", clause)
            key = mm.group(1) if mm else "(unkeyed)"
            if key in COLUMNS:
                stamp_of.setdefault(key, hs[0])
            else:
                extra.append((key, hs[0]))
        graded_any = False
        for idx, key in by_col:
            if idx >= len(cells):
                continue
            hs = HASH_RX.findall(cells[idx])
            s = stamp_of.get(key)
            if not hs and s is None:
                continue
            graded_any = True
            # ⛔ A HASH INSIDE THE CELL BODY IS A QUOTE, NEVER THE CLAIM (coo 2026-09-16; hq_prolog: a vendor cell whose SUPERSEDES clause honestly
            # cited the reading it replaced, 'hq_C SCRIP 36e277d17 09-05', was read as CLAIMING that tree -- STALE 1169 behind, ADRIFT -- forever,
            # and the only silence offered was deleting the provenance the rule exists to keep). THE CLAIM IS THE `key:` PROVENANCE CLAUSE's stamp;
            # a cell with none is UNSTAMPED (its own state, no distance graded); the body's hashes matter only when one is NEWER than the stamp
            # (the hand-edited case below, which the ancestry check ranks).
            if s is None:
                out.append("  %-9s %-9s UNSTAMPED no `%s:` provenance clause names this cell; %s quoted inside it (%s) not read as a claim" % (
                    lang, key, key, ("the hash" if len(set(hs)) == 1 else "the hashes"), ", ".join(sorted(set(hs))) if hs else "none"))
                adrift += 1
                continue
            d = distance(s); h = s
            if d is None:
                out.append("  %-9s %-9s UNKNOWN   %s (the `%s:` clause's stamp) is not a commit origin knows" % (lang, key, s, key))
                unknown += 1
                continue
            worst = max(worst, d)
            flag = "STALE" if d >= a.threshold else "ok   "
            note = ""
            _bd, _bh = newest(hs) if hs else (None, None)
            if _bh and _bh != s and _bd is not None and _bd < d:
                h = _bh   # the body carries a NEWER tree than the clause stamps: the hand-edited case, ranked by ancestry below
            if s != h:
                sd = distance(s)
                if sd is None:
                    note = "  ⚠ ADRIFT: `%s:` clause stamps %s, which origin does not know" % (key, s)
                    adrift += 1
                else:
                    # ⛔⭐ RANK THE TWO TREES BY ANCESTRY, NOT BY DISTANCE-TO-ORIGIN (ceo CEO-492, the same
                    # rule `write` now refuses on, applied per row to a board that already carries the
                    # damage). `sd > d` reads "the clause is further behind origin, so it is older", which
                    # is true only while history is linear -- and it is exactly the reasoning hq_S had to
                    # do by hand, with `git merge-base`, to resolve one row correctly. Two hashes on
                    # different branches get a confident ordering out of the arithmetic and NO ordering
                    # out of git, so the arithmetic was answering a question it could not see.
                    # ⭐ UNRELATED IS ITS OWN STATE AND IT IS ADRIFT TOO. Neither tree reaches the other,
                    # so nothing on this board can say which number came later -- and unlike a stale row,
                    # nothing about it looks wrong. Distance ranked those silently and the note it printed
                    # was a guess wearing a measurement's clothes.
                    _rel = tree_ancestry(s, h)
                    if _rel == "older" or (_rel is None and sd > d):
                        _how = ("git merge-base: a strict ANCESTOR of" if _rel == "older"
                                else "%d commit(s) further from origin than" % (sd - d))
                        note = "  ⚠ ADRIFT: `%s:` clause stamps %s (%d behind), %s the tree this cell claims -- hand-edited, not written through this helper" % (
                            key, s, sd, _how)
                        adrift += 1
                    elif _rel == "unrelated":
                        note = "  ⚠ ADRIFT: `%s:` clause stamps %s and the cell claims %s -- NEITHER tree reaches the other, so no ancestry ranks them and this board cannot say which number was measured later" % (
                            key, s, h)
                        adrift += 1
            out.append("  %-9s %-9s %s %4d commits behind origin/main (cell claims %s)%s" % (
                lang, key, flag, d, h, note))
        # Vendor-suite stamps live only in the Tree column -- they have no cell of their own, so they are
        # graded here or nowhere.
        for key, h in sorted(set(extra)):
            if key == "(unkeyed)":
                # an unkeyed provenance clause is a historical cross-check (seat16's INRIA cross-confirm of 09-05), not a suite board: no suite
                # run refreshes it, so it is named and left out of the staleness census (hq_prolog 2026-09-16); key it or retire it
                out.append("  %-9s %-9s CROSS-CHECK (unkeyed clause, stamp %s): historical, not a board -- not graded for staleness" % (lang, key, h))
                continue
            d = distance(h)
            if d is None:
                out.append("  %-9s %-9s UNKNOWN   %s is not a commit origin knows" % (lang, key, h))
                unknown += 1
                continue
            graded_any = True
            worst = max(worst, d)
            out.append("  %-9s %-9s %s %4d commits behind origin/main (Tree-column stamp %s)" % (
                lang, key, "STALE" if d >= a.threshold else "ok   ", d, h))
        if not graded_any:
            out.append("  %-9s UNPINNED  (no checkable SCRIP hash in any measured cell or the Tree column)" % lang)
            unknown += 1
    print("SCORE.md staleness (threshold %d commits):" % a.threshold)
    for l in out:
        print(l)
    # ⭐ Provenance twins are reported from `check` as well as from `write`, because `check` is where the
    # question "is this board trustworthy" is actually asked. A duplicated key is not staleness and not
    # adrift -- both of those describe ONE stamp being wrong; this one is two stamps where the reader
    # cannot tell which answered.
    _dupnotes = []
    for lang in sorted(rows):
        _n = prov_duplicate_note(lang, rows[lang][1][PROV_COL], indent="  ")
        if _n:
            _dupnotes.append(_n)
    print("worst=%d unpinned/unknown=%d adrift=%d provdup=%d" % (worst, unknown, adrift, len(_dupnotes)))
    rc = 0
    if worst >= a.threshold:
        print("⚠ WARN: %d row-measurement(s) at or past the %d-commit staleness threshold -- re-measure and rewrite the row." % (
            sum(1 for l in out if "STALE" in l), a.threshold))
        rc = 1
    if adrift:
        # ⭐ Reported SEPARATELY from staleness because the cure is different and the two are independent.
        # Stale says "re-run the suite"; UNSTAMPED says "the number in that cell did not come through this
        # helper, so its stamp names the wrong tree and the wrong measurer" -- the fix is to re-write the cell
        # with `write --column <col>`, which is what makes the stamp and the prose agree again.  A row can be
        # perfectly current and still adrift, which is exactly why it may not be folded into the WARN above.
        print("⚠ WARN: %d cell(s) ADRIFT from their provenance stamp -- the cell was hand-edited, so the Tree "
              "column names a different tree (and a different measurer) than the number a reader sees. Re-write "
              "each with `write --column <col>` so the stamp and the prose agree again." % adrift)
        rc = 1
    if _dupnotes:
        print("⚠ WARN: %d row(s) carry DUPLICATED provenance keys -- two stamps under one name, only the "
              "first of which any writer or reader will ever reach:" % len(_dupnotes))
        for _n in _dupnotes:
            print(_n)
        rc = 1
    return rc


def cmd_selftest(a):
    # Proves the two things this helper must never get wrong -- that it REWRITES rather than appends,
    # and that every refusal path actually refuses -- against a scratch copy, never the real board.
    import tempfile, shutil
    # ⛔ SUITES_TSV IS REDIRECTED TOO, NOT JUST SCORE_MD.  cmd_write now mirrors a V/M write into the suite
    # table, so a selftest that redirected only the board would have written its fake rebus numbers into the
    # REAL .github/SUITES.tsv -- the banner Lon reads -- while printing that it grades a scratch copy.  A
    # scratch harness that is scratch in one of its two outputs is not a scratch harness.
    # ⛔ AND THE BOARD-LINE ARCHIVE IS THE THIRD OUTPUT, REDIRECTED FROM THE FIRST LINE (CEO-827, coo 2026-09-17):
    # cmd_write archives the verbatim board line it is handed, so a selftest that redirected only SCORE.md and
    # SUITES.tsv would write its fixture lines into the REAL .github/board-lines -- the same lesson as the paragraph
    # above, one output later. Scratch in ALL of its outputs or it is not a scratch harness.
    global SCORE_MD, SUITES_TSV, BOARD_LINES_DIR
    real = SCORE_MD
    real_tsv = SUITES_TSV
    real_bl = BOARD_LINES_DIR
    ok = True
    d = tempfile.mkdtemp(prefix="score_row_selftest.")
    try:
        BOARD_LINES_DIR = os.path.join(d, "board-lines")
        SCORE_MD = os.path.join(d, "SCORE.md")
        shutil.copy(real, SCORE_MD)
        SUITES_TSV = os.path.join(d, "SUITES.tsv")
        # every write arm below plants no progress rows: the DB cross-check (db_crosscheck) is overridden LOUDLY for them
        # and proven by its own arms, which pop this and plant a scratch DB
        os.environ["S4E_DB_CHECK_OVERRIDE"] = "selftest: the write arms plant no progress rows"
        # the caller's run start is not this selftest's: every arm writes without a wall clock but the one that proves it (CEO-1562)
        os.environ.pop("S4E_RUN_T0", None)
        if os.path.exists(real_tsv):
            shutil.copy(real_tsv, SUITES_TSV)
            # ⛔ SEED THE FIXTURE DENOMINATOR THROUGH THE STAMPED PATH (coo 2026-09-16, CEO-785): every arm below writes the
            # rebus board row at N/48 while the live row reads 43/43, and since today a write that MOVES a row's total
            # without --criterion-changed REFUSES rc=2 before touching a byte -- the property the two CEO-785 arms at the
            # end of this selftest prove. Seeding 48 here, stamped, keeps every older arm what it always was: a write at
            # the fixture's own denominator, never a denominator move.
            _seed_env = dict(os.environ); _seed_env["S4E_SUITES_TSV"] = SUITES_TSV; _seed_env["S4E_SCORE_MD"] = SCORE_MD
            _seed = subprocess.run([sys.executable, SUITE_BANNER, "--set", "reb-rungs", "0", "48", "2026-09-16", "selftest",
                                    "--criterion-changed", "2026-09-16:selftest seed -- the fixture denominator is 48, not the row's"],
                                   capture_output=True, text=True, env=_seed_env)
            if _seed.returncode != 0:
                print("SELFTEST FAIL: the fixture seed (reb-rungs -> 0/48, stamped) refused rc=%d: %s" % (_seed.returncode, (_seed.stderr or _seed.stdout).strip()[:200])); ok = False
        # ⛔ SEED A KNOWN CELL BEFORE PROVING REWRITE-IN-PLACE, rather than inherit whatever prose the LIVE
        # rebus/board cell happens to carry that day. This selftest's own claim ("rewrite-in-place holds")
        # has never depended on the starting content -- only on two known writes landing as one cell -- but
        # the live cell is real board prose (see cell_prose_loss below), and coupling a selftest's pass/fail
        # to today's live board text is exactly the kind of incidental fragility this file exists to avoid
        # elsewhere. Seeding it here keeps that claim provably independent of the day it happens to run.
        _seed_lines = open(SCORE_MD, encoding="utf-8").read().split("\n")
        _sh, _sr, _ = find_table(_seed_lines)
        _sri, _src = _sr["rebus"]
        _src[COLUMNS["board"][0]] = "—"
        _seed_lines[_sri] = "| " + " | ".join(_src) + " |"
        _write_score_md(_seed_lines, seeding=True)
        n0 = len(open(SCORE_MD, encoding="utf-8").read().split("\n"))
        class A: pass
        for run in (1, 2):
            a2 = A(); a2.lang = "rebus"; a2.column = "board"; a2.measurer = "selftest"
            a2.text = "rungs: m3 %d/48 · m4 %d/48 (selftest, not a measurement)" % (run, run)
            a2.modes = "m3,m4"; a2.dry_run = False; a2.suite = ""
            cmd_write(a2)
        n1 = len(open(SCORE_MD, encoding="utf-8").read().split("\n"))
        body = open(SCORE_MD, encoding="utf-8").read()
        if n1 != n0:
            print("SELFTEST FAIL: line count moved %d -> %d; a row-write must rewrite IN PLACE, never append" % (n0, n1)); ok = False
        else:
            print("SELFTEST: two writes to one cell left the line count unchanged -- rewrite-in-place holds")
        # ⛔ LOOK ONLY INSIDE THE TABLE find_table BOUND, never across the whole file by row name: SCORE.md
        # carries more than one '| Language |' grid (ceo CEO-174's September-10 M/L/V grid), so every
        # language name appears more than once and a file-wide scan asserts on the wrong row -- the same
        # position-over-shape defect that made find_table itself refuse for the whole fleet.
        _hdr, _rows, _ = find_table(body.split("\n"))
        row = [_rows["rebus"][1]] if "rebus" in _rows else []
        cell = row[0][3] if row else ""
        prov = row[0][PROV_COL] if row else ""
        clauses = len(re.findall(r"(?:^|; )board:", prov))
        if len(row) != 1 or "1/48" in cell or cell.count("2/48") != 2 or clauses != 1:
            print("SELFTEST FAIL: the second write did not replace the first -- %d rebus rows in the bound grid, "
                  "%d board: clauses, first-write text %s" % (len(row), clauses, "SURVIVES" if "1/48" in cell else "gone")); ok = False
        else:
            print("SELFTEST: the second write replaced the first cell and its provenance clause, not appended beside it")
        _lines0 = open(SCORE_MD, encoding="utf-8").read().split("\n")
        _gh0, _gr0, _ = find_grid(_lines0)
        for _gl, _gline in enumerate(_lines0):
            if _gline.startswith("| rebus |"):
                _gc = [x.strip() for x in _gline.strip().strip("|").split("|")]
                if len(_gc) == GRID_NCOLS:
                    _gc[GRID_COLUMNS["L"][0]] = "—"; _lines0[_gl] = "| " + " | ".join(_gc) + " |"
        _write_score_md(_lines0)
        _lines0 = open(SCORE_MD, encoding="utf-8").read().split("\n")
        for run in (1, 2):
            a4 = A(); a4.lang = "rebus"; a4.column = "ladder"; a4.measurer = "selftest"; a4.modes = ""; a4.dry_run = False; a4.suite = ""
            a4.text = "rungs 0..5 PASS %d/22 (selftest, not a measurement)" % run
            try:
                cmd_write(a4)
            except SystemExit as e:
                print("SELFTEST FAIL: ladder grid write %d refused rc=%s on a seeded one-sentence cell" % (run, e.code)); ok = False
        _lines1 = open(SCORE_MD, encoding="utf-8").read().split("\n")
        _gh1, _gr1, _ = find_grid(_lines1)
        _lc = _gr1["rebus"][GRID_COLUMNS["L"][0]]
        if len(_lines1) != len(_lines0) or "1/22" in _lc or _lc.count("2/22") != 1 or _lc.count("⟨measured") != 1:
            print("SELFTEST FAIL: ladder grid write -- line count %d -> %d, cell %r" % (len(_lines0), len(_lines1), _lc[:120])); ok = False
        else:
            print("SELFTEST: ladder column writes the grid L cell in place; the second write replaced the first and its stamp")
        _lp = open(SCORE_MD, encoding="utf-8").read().split("\n")
        for _gl, _gline in enumerate(_lp):
            if _gline.startswith("| rebus |"):
                _gc = [x.strip() for x in _gline.strip().strip("|").split("|")]
                if len(_gc) == GRID_NCOLS:
                    _gc[GRID_COLUMNS["L"][0]] = "rungs 0..5 PASS 22/22. A person wrote this second sentence."; _lp[_gl] = "| " + " | ".join(_gc) + " |"
        _write_score_md(_lp)
        a6 = A(); a6.lang = "rebus"; a6.column = "ladder"; a6.measurer = "s"; a6.modes = ""; a6.dry_run = False; a6.suite = ""; a6.text = "rungs 0..5 PASS 22/22"
        try:
            cmd_write(a6); print("SELFTEST FAIL: ladder write over a two-sentence cell did not refuse"); ok = False
        except SystemExit as e:
            if e.code == 2: print("SELFTEST: ladder write over a hand-written two-sentence cell correctly REFUSED rc=2 and named it")
            else: print("SELFTEST FAIL: ladder prose guard exited %s, expected 2" % e.code); ok = False
        a5 = A(); a5.lang = "rebus"; a5.column = "ladder"; a5.measurer = "s"; a5.modes = ""; a5.dry_run = False; a5.suite = ""; a5.text = "rungs 0..5 all green"
        try:
            cmd_write(a5); print("SELFTEST FAIL: ladder write without a fraction did not refuse"); ok = False
        except SystemExit as e:
            if e.code == 2: print("SELFTEST: ladder write without an N/M fraction correctly REFUSED rc=2")
            else: print("SELFTEST FAIL: ladder no-fraction exited %s, expected 2" % e.code); ok = False
        for label, kw in (("unknown language", dict(lang="klingon", column="board", text="1/1", measurer="s")),
                          ("unknown column", dict(lang="rebus", column="nosuch", text="1/1", measurer="s")),
                          ("no digit", dict(lang="rebus", column="board", text="looks fine", measurer="s")),
                          ("pipe injection", dict(lang="rebus", column="board", text="1/1 | evil", measurer="s"))):
            a3 = A(); a3.modes = ""; a3.dry_run = False; a3.suite = ""
            for k, v in kw.items(): setattr(a3, k, v)
            try:
                cmd_write(a3)
                print("SELFTEST FAIL: %s did not refuse" % label); ok = False
            except SystemExit as e:
                if e.code == 2:
                    print("SELFTEST: %s correctly REFUSED rc=2" % label)
                else:
                    print("SELFTEST FAIL: %s exited %s, expected 2" % (label, e.code)); ok = False

        # ⛔⭐ SEMICOLON NORMALISATION, NOT REFUSAL (row score-row-write-refuses-a-semicolon-forever-so-a-
        # hand-edited-cell-can-never-be-runner-written): a ';' in --text must SUCCEED, by becoming '·', and
        # the round trip must stay safe -- proven by a SECOND write that goes through merge_clause (the
        # thing the guard actually protects) on the SAME cell and checking the first write's clause comes
        # back intact, not split at the '·' that used to be a ';'.
        _fh, _fr, _ = find_table(open(SCORE_MD, encoding="utf-8").read().split("\n"))
        _fri, _frc = _fr["rebus"]
        _frc[COLUMNS["floor"][0]] = "—"
        _flines = open(SCORE_MD, encoding="utf-8").read().split("\n")
        _flines[_fri] = "| " + " | ".join(_frc) + " |"
        _write_score_md(_flines)
        a4 = A(); a4.lang = "rebus"; a4.column = "floor"; a4.measurer = "selftest"
        a4.text = "1/1; semicolon inside"; a4.modes = ""; a4.dry_run = False; a4.suite = ""
        cmd_write(a4)
        _hdr, _rows, _ = find_table(open(SCORE_MD, encoding="utf-8").read().split("\n"))
        cell = _rows["rebus"][1][COLUMNS["floor"][0]] if "rebus" in _rows else ""
        if ";" in cell:
            print("SELFTEST FAIL: semicolon normalisation -- a raw ';' survived into the stored cell: %r" % cell); ok = False
        elif "1/1· semicolon inside" not in cell:
            print("SELFTEST FAIL: semicolon normalisation -- normalised text not found in cell: %r" % cell); ok = False
        else:
            print("SELFTEST: ';' in --text normalised to '·' and written, not refused")
            a5 = A(); a5.lang = "rebus"; a5.column = "floor"; a5.measurer = "selftest"
            a5.text = "2/2"; a5.modes = ""; a5.dry_run = False; a5.suite = "SomeSuite"
            cmd_write(a5)
            _hdr, _rows, _ = find_table(open(SCORE_MD, encoding="utf-8").read().split("\n"))
            cell2 = _rows["rebus"][1][COLUMNS["floor"][0]] if "rebus" in _rows else ""
            clauses2 = [c.strip() for c in cell2.split(";") if c.strip()]
            if len(clauses2) != 2 or clauses2[0] != "1/1· semicolon inside" or not clauses2[1].startswith("SomeSuite:"):
                print("SELFTEST FAIL: round trip -- a later --suite write fragmented or lost the earlier "
                      "normalised clause: %r (split into %r)" % (cell2, clauses2)); ok = False
            else:
                print("SELFTEST: round trip holds -- a later --suite write did not fragment the earlier normalised clause")

        # ⛔⭐ SUITE TARGETING -- FIXTURE IS THE REAL CELL, not an invented one (hq_I 2026-09-06, caught
        # by --dry-run and never written). `hist` is the shape of the live icon vendor cell: a bolded
        # lower-case LEADING figure and, 1.6 KB later inside a SUPERSEDED narrative, a bare `Arizona:`
        # clause. merge_clause can only ever match the second, so the write lands on the archive and the
        # number a reader sees first stays stale while the provenance says otherwise.
        # ⛔ THE THREE NEGATIVE ARMS MATTER AS MUCH AS THE POSITIVE ONE. A guard that refuses cells which
        # merge correctly is a guard someone switches off: `same_clause` is the live snobol4 cell
        # (`aisnobol: aisnobol 0/2 m3`) where the key appears twice ten characters apart inside ONE
        # clause -- not a conflict, because the rewrite replaces that clause whole; `mention` is the same
        # icon cell's "the arizona/jcon pass counts agree exactly", a mention with no number after it;
        # and `script_name` is `test_icon_arizona_suite.sh`, which without the underscore in the word
        # boundary would refuse every icon vendor write over a filename.
        hist = ("**arizona m3 46/89 · m4 46/89** graded (124 shipped; `test_icon_arizona_suite.sh`) "
                "— ⛔ hq_I's re-measure is SUPERSEDED: the arizona/jcon pass counts agree exactly; "
                "Arizona: m3 46/124 · m4 46/124 (of 124 shipped, `test_icon_arizona_suite.sh`)")
        same_clause = "Snoflake: 130/173 m3; aisnobol: aisnobol 0/2 m3 · 0/2 m4 SCORED (of 8 shipped)"
        _targeting_ok = True
        _provdup_ok = True
        for _cell, _key, _want, _why in (
                (hist, "Arizona", "multi", "a bolded leading figure and an archived keyed clause"),
                (same_clause, "aisnobol", "", "the key twice inside ONE clause is not a conflict"),
                (hist, "JCON", "", "a suite the cell only MENTIONS, with no number after it, is not a head"),
                ("**arizona m3 46/89 · m4 46/89** graded", "Arizona", "unreachable",
                 "a head merge_clause cannot match would be APPENDED beside, not rewritten"),
                ("Snoflake: 130/173 m3 · 130/173 m4", "Arizona", "", "a suite absent from the cell is a plain first write"),
                ("—", "Arizona", "", "an empty cell is a plain first write")):
            _got = suite_target_conflict(_cell, _key)[0]
            if _got != _want:
                print("SELFTEST FAIL: suite targeting -- key %r expected %r, got %r (%s)"
                      % (_key, _want or "no conflict", _got or "no conflict", _why))
                ok = False
                _targeting_ok = False
        if _targeting_ok:
            print("SELFTEST: suite targeting refuses a cell that carries its own history, and does NOT "
                  "refuse a same-clause repeat, a bare mention, a script name, or a first write")
        # ⭐ AND THE REFUSAL MUST REACH cmd_write, not just the helper -- the defect was reported against
        # the COMMAND. Proven end to end on the scratch copy, with rc=2 and both offsets named.
        _th, _tr, _ = find_table(open(SCORE_MD, encoding="utf-8").read().split("\n"))
        if "rebus" in _tr:
            _ti, _tc = _tr["rebus"]
            _tc[COLUMNS["vendor"][0]] = hist
            _tl = open(SCORE_MD, encoding="utf-8").read().split("\n")
            _tl[_ti] = "| " + " | ".join(_tc) + " |"
            _write_score_md(_tl)
            a10 = A(); a10.lang = "rebus"; a10.column = "vendor"; a10.suite = "Arizona"
            a10.measurer = "selftest"; a10.modes = ""; a10.dry_run = False; a10.text = "arizona 47/90 m3 · 47/90 m4"
            try:
                cmd_write(a10)
                print("SELFTEST FAIL: suite targeting -- cmd_write WROTE into a cell carrying two "
                      "Arizona readings instead of refusing"); ok = False
            except SystemExit as _e:
                _after = find_table(open(SCORE_MD, encoding="utf-8").read().split("\n"))[1]["rebus"][1][COLUMNS["vendor"][0]]
                if _e.code != 2:
                    print("SELFTEST FAIL: suite targeting -- cmd_write refused with rc=%s, not 2" % _e.code); ok = False
                elif _after != hist:
                    print("SELFTEST FAIL: suite targeting -- REFUSED but the cell changed anyway: %r" % _after); ok = False
                else:
                    print("SELFTEST: cmd_write REFUSES rc=2 on an ambiguous --suite and leaves the cell byte-identical")

        # ⛔⭐ BLOCKER DIAGNOSIS -- fixtures are hq_I's THREE ATTEMPTS (2026-09-06), each of which fixed one
        # wall and hit the next, because the refusal enumerated the three walls instead of naming theirs.
        # The third -- no ';' boundary -- was not in the cure text at all, and is the only one whose fix is
        # STRUCTURAL rather than cosmetic: these cells separate readings with '·' while merge_clause splits
        # on ';', so a correctly keyed, unbolded reading can still sit inside its neighbour's clause.
        _blk_ok = True
        for _cell, _key, _want, _why in (
                ("Arizona: 47/90 m3; **IPL**: run m3 34/60", "IPL", "emphasis",
                 "attempt 2 -- the KEY is bolded, so the clause does not start with it"),
                ("Arizona: m3 47/90 · m4 47/90 · IPL: run m3 34/60", "IPL", "no ';'",
                 "attempt 3 -- keyed and unbolded, but '·'-separated so it is not a clause at all"),
                ("Arizona: 47/90 m3; ipl: run m3 34/60", "IPL", "case-SENSITIVE",
                 "the key is spelled in a different case than the caller passed"),
                ("Arizona: 47/90 m3; IPL: run m3 34/60", "IPL", None,
                 "a properly keyed, unbolded, ';'-separated reading has NO blocker")):
            _offs = measurement_heads(_cell, _key)
            _rs = " ".join(head_blockers(_cell, _key, _offs[-1])) if _offs else ""
            if _want is None:
                if _rs:
                    print("SELFTEST FAIL: blockers -- expected none, got %r (%s)" % (_rs, _why)); ok = False; _blk_ok = False
            elif _want not in _rs:
                print("SELFTEST FAIL: blockers -- expected %r in the reason, got %r (%s)" % (_want, _rs, _why))
                ok = False; _blk_ok = False
        if _blk_ok:
            print("SELFTEST: each unreachable head names ITS OWN wall -- emphasis, missing ';', or case -- "
                  "and a clean reading names none")

        # ⛔⭐ PROVENANCE TWINS -- fixture is the REAL snobol4 row (hq_P 2026-09-06), not an invented one.
        # The load-bearing arm is `wrapped`: ONE clause on the page whose VALUE is itself a ';'-joined
        # provenance list, which is how nine twins arrived without any writer appending anything. A check
        # that only looked for literally repeated clauses would score that cell CLEAN.
        wrapped = ("board: SCRIP `aaa` · 2026-09-06 · hq_T; vendor: SCRIP `bbb` · 2026-09-06 · hq_P; "
                   "concurrent board stamp merged from origin: SCRIP `ccc` · 2026-09-03 · hq_B; "
                   "board: SCRIP `ddd` · 2026-09-05 · hq_S; vendor: SCRIP `eee` · 2026-09-05 · hq_P")
        for _prov, _want, _why in (
                (wrapped, ["board", "vendor"], "a wrapper clause whose value is itself a clause list"),
                ("board: SCRIP `aaa`; entries: SCRIP `bbb`", [], "one stamp per key is the normal row"),
                ("", [], "an empty provenance cell has no twins"),
                ("—", [], "an unmeasured provenance cell has no twins"),
                ("board: SCRIP `aaa`; board: SCRIP `aaa`", ["board"],
                 "byte-identical twins still hide a stamp no writer can reach")):
            _got = sorted(prov_duplicate_keys(_prov))
            if _got != sorted(_want):
                print("SELFTEST FAIL: provenance twins -- expected %r, got %r (%s)" % (sorted(_want), _got, _why))
                ok = False
                _provdup_ok = False
        if _provdup_ok:
            print("SELFTEST: provenance twins found through a wrapper clause, and a clean row stays clean")
        # ⭐ AND THE NOTE MUST NAME BOTH STAMPS, or it cannot be acted on -- naming only the key would say
        # "something is duplicated" and leave the reader to diff a 2 KB cell by eye.
        _note = prov_duplicate_note("snobol4", wrapped)
        if "`board:` x2" not in _note or "aaa" not in _note or "ddd" not in _note:
            print("SELFTEST FAIL: provenance twins -- the note does not name both stamps: %r" % _note[:200])
            ok = False
        else:
            print("SELFTEST: the provenance-twin note names the key and BOTH competing stamps")

        # ⛔⭐ CELL PROSE LOSS -- fixture is the REAL incident, .github 46ff295c, not an invented example.
        # `real_before` is exactly what the snobol4 board cell carried before the runner clobbered it;
        # `reformatted_only` is the SAME sentence with the runner's own boilerplate drift the repair also
        # shows (no human involved, must NOT refuse); `sentence_dropped` is what the runner actually wrote
        # (the trailing sentence gone, must refuse). Both directions matter equally: a check that also
        # catches boilerplate drift is noisy enough that nobody keeps it turned on.
        real_before = ("m3 PASS=1689 FAIL=0 · m4 PASS=1689 FAIL=0 SKIP=0 · MISSING=0 "
                       "(`test_corpus_snobol4.sh` inside `make test`, rc=0). Re-confirmed on a newer tree "
                       "and identical across two consecutive runs (before and after a rebase onto origin), "
                       "as the control arm for the rung-11 LCO landing: the shared alternative-trampoline "
                       "change in emit.cpp moved nothing here.")
        reformatted_only = ("m3 PASS=1689 FAIL=0 · m4 PASS=1689 FAIL=0 SKIP=0 MISSING=0 "
                            "(`test_corpus_snobol4.sh`, inside `make test`, rc=0). Re-confirmed on a newer "
                            "tree and identical across two consecutive runs (before and after a rebase onto "
                            "origin), as the control arm for the rung-11 LCO landing: the shared "
                            "alternative-trampoline change in emit.cpp moved nothing here.")
        sentence_dropped = ("m3 PASS=1689 FAIL=0 · m4 PASS=1689 FAIL=0 SKIP=0 MISSING=0 "
                            "(`test_corpus_snobol4.sh`, inside `make test`, rc=0).")
        if cell_prose_loss(real_before, reformatted_only):
            print("SELFTEST FAIL: cell_prose_loss flagged the real 46ff295c boilerplate drift as lost prose"); ok = False
        else:
            print("SELFTEST: cell_prose_loss did not false-positive on punctuation-only reformatting")
        if not cell_prose_loss(real_before, sentence_dropped):
            print("SELFTEST FAIL: cell_prose_loss missed the real dropped sentence from .github 46ff295c"); ok = False
        else:
            print("SELFTEST: cell_prose_loss correctly caught the real .github 46ff295c dropped sentence")
        # Integration: seed the scratch board directly (bypassing cmd_write, so the seed itself cannot be
        # refused), then prove cmd_write FOLDS a real drop forward instead of losing it (rc=0, both texts
        # present), and still applies a pure reformat as a clean replace (nothing to fold). Each scenario
        # reseeds its own starting cell rather than sharing state, so a7's fold-forward result (which now
        # legitimately contains SUPERSEDE_MARKER) cannot leak into a8's "no marker" assertion.
        def _seed_floor(text):
            _lines = open(SCORE_MD, encoding="utf-8").read().split("\n")
            _h2, _r2, _ = find_table(_lines)
            _ri, _rc = _r2["rebus"]
            _fidx = COLUMNS["floor"][0]
            _rc[_fidx] = text
            _lines[_ri] = "| " + " | ".join(_rc) + " |"
            _write_score_md(_lines)
            return _fidx

        _fidx = _seed_floor(real_before)
        _fold_prov_before = find_table(open(SCORE_MD, encoding="utf-8").read().split("\n"))[1]["rebus"][1][PROV_COL]
        a7 = A(); a7.lang = "rebus"; a7.column = "floor"; a7.measurer = "selftest"; a7.modes = ""; a7.suite = ""
        a7.dry_run = False; a7.text = sentence_dropped
        try:
            cmd_write(a7)
            _h3, _r3, _ = find_table(open(SCORE_MD, encoding="utf-8").read().split("\n"))
            _after = _r3["rebus"][1][_fidx]
            if sentence_dropped not in _after or real_before not in _after:
                print("SELFTEST FAIL: cmd_write's supersede fallback dropped the new text or the old "
                      "reading instead of carrying both forward verbatim: %r" % _after); ok = False
            else:
                print("SELFTEST: cmd_write correctly folded the old reading forward (supersede fallback) "
                      "instead of silently dropping it or refusing -- the prior sentence survives in the cell")
                # ⛔ hq_prolog 2026-09-16: the folded tail names its own stamp, machine-inserted -- the retired `floor:` clause's
                # hash, date and seat appear in the marker, and 'superseded <today> by selftest' beside them.
                _pm = re.search(r"floor:\s*SCRIP `([0-9a-f]{7,40})", _fold_prov_before or "")
                _pd = re.search(r"floor:[^;]*?(\d{4}-\d{2}-\d{2})", _fold_prov_before or "")
                _want = ("the reading below was stamped floor: SCRIP %s on %s" % (_pm.group(1), _pd.group(1))) if (_pm and _pd) \
                        else "the reading below carried no `floor:` provenance clause of its own"
                if _want in _after and ("superseded %s by selftest" % time.strftime("%Y-%m-%d")) in _after:
                    print("SELFTEST: the folded tail's marker names the superseded reading's own stamp (%s) and the fold's date" % _want)
                else:
                    print("SELFTEST FAIL: the folded tail's marker does not name the superseded stamp -- wanted %r in %r" % (_want, _after[:400])); ok = False
        except SystemExit as e:
            print("SELFTEST FAIL: cmd_write refused a lossy overwrite instead of folding the old reading "
                  "forward (rc=%s)" % e.code); ok = False

        _seed_floor(real_before)
        a8 = A(); a8.lang = "rebus"; a8.column = "floor"; a8.measurer = "selftest"; a8.modes = ""; a8.suite = ""
        a8.dry_run = False; a8.text = reformatted_only
        try:
            cmd_write(a8)
            _h4, _r4, _ = find_table(open(SCORE_MD, encoding="utf-8").read().split("\n"))
            _after2 = _r4["rebus"][1][_fidx]
            if SUPERSEDE_PREFIX in _after2:
                print("SELFTEST FAIL: cmd_write folded a PURE REFORMAT through the supersede fallback "
                      "instead of a clean replace -- cell_prose_loss false-positived on punctuation drift, "
                      "this time through the cmd_write integration path"); ok = False
            else:
                print("SELFTEST: cmd_write correctly proceeded on a pure reformat (nothing to lose, no "
                      "supersede clause added)")
        except SystemExit as e:
            print("SELFTEST FAIL: cmd_write refused a pure reformat that loses nothing (rc=%s)" % e.code); ok = False

        # ⛔⭐ FOLD DEPTH STAYS CAPPED ACROSS REPEATED FOLDS (hq_T ruling on
        # ruling-supersede-fold-approved-with-a-bound). The a7/a8 checks above only ever fold ONCE, which
        # cannot catch a bug that only shows up once `before` already carries a marker of its own -- three
        # folds in a row is the minimum depth that can. Three genuinely distinct readings (no shared prose,
        # so every write is a real loss and a real fold) prove the cell keeps exactly one archived reading
        # no matter how many folds land on it, instead of re-embedding its whole prior self every time.
        _seed_floor("—")
        _fold_a = "board reading Alpha: 17 dogs jumped over lake Baldwin at dawn."
        _fold_b = "measurement Bravo shows: 90 cars parked beside river Clifton at dusk."
        _fold_c = "observation Charlie found: 60 birds nested inside forest Denton at noon."
        for _reading in (_fold_a, _fold_b, _fold_c):
            a9 = A(); a9.lang = "rebus"; a9.column = "floor"; a9.measurer = "selftest"
            a9.modes = ""; a9.suite = ""; a9.dry_run = False; a9.text = _reading
            cmd_write(a9)
        _h5, _r5, _ = find_table(open(SCORE_MD, encoding="utf-8").read().split("\n"))
        _after3 = _r5["rebus"][1][_fidx]
        # ⛔⭐ THE CROSS-VERSION FOLD -- a cell written by an EARLIER marker wording must still fold to
        # exactly ONE archive. No arm above can see this: they all fold with the constant the running
        # process holds, so the marker matches itself by construction and the depth cap always looks
        # sound. This arm feeds in a cell carrying the OLD 2026-09-09 wording ("folded it forward
        # verbatim as provenance") and requires the cap to hold anyway. It is the regression this very
        # commit would otherwise have shipped: rewording the marker broke the cut, and the second archive
        # appeared only in a fixture printout nobody was required to read.
        _old_marker = ("⛔ SUPERSEDES the reading below (util_score_row.py folded it forward verbatim as "
                       "provenance, not hand-edited, not asserted still true):")
        _xv_before = "live reading Echo: 44 ships sailed past harbour Ellis at noon. %s stale reading Foxtrot: 12 carts rolled toward village Fenton at dusk." % _old_marker
        _xv_carried = spell_fractions(_xv_before.split(SUPERSEDE_PREFIX, 1)[0].rstrip())
        _xv_after = "%s %s %s" % ("new reading Golf: 71 kites flew above meadow Gilman at dawn.", SUPERSEDE_MARKER, _xv_carried)
        if _xv_after.count(SUPERSEDE_PREFIX) != 1:
            print("SELFTEST FAIL: a cell carrying the PREVIOUS marker wording folded to %d archived "
                  "reading(s), wanted exactly 1 -- the cut is matching the full constant instead of the "
                  "stable prefix, so every cell written by an older version grows on each write: %r"
                  % (_xv_after.count(SUPERSEDE_PREFIX), _xv_after)); ok = False
        elif "Foxtrot" in _xv_after:
            print("SELFTEST FAIL: the twice-superseded reading survived a cross-version fold: %r" % _xv_after); ok = False
        else:
            print("SELFTEST: a cell written under the PREVIOUS marker wording still folds to exactly one "
                  "archived reading -- the depth cap survives a reword of the constant")
        # ⛔⭐ AND THE ARCHIVE CARRIES NO DIGIT FRACTION (CEO-475). The agree parser reads fractions out of
        # a cell; anything the fold leaves in digit form is a number it can mistake for this cell's value.
        _cf_after = "%s %s %s" % ("m3 740/751", SUPERSEDE_MARKER, spell_fractions("run-graded both-modes 739/751 · m3 739/751"))
        _cf_arch = _cf_after.split(SUPERSEDE_PREFIX, 1)[1]
        if FRACTION_RE.search(_cf_arch):
            print("SELFTEST FAIL: the folded archive still carries a digit fraction %r -- the agree gate "
                  "will read it as this cell's number and red every tick a suite moves"
                  % FRACTION_RE.search(_cf_arch).group(0)); ok = False
        elif cell_bar(cell_fractions(_cf_after)[0]) != {751: 740}:
            print("SELFTEST FAIL: a cell with a folded archive parsed as %r, wanted the LIVE {751: 740}"
                  % (cell_bar(cell_fractions(_cf_after)[0]),)); ok = False
        else:
            print("SELFTEST: a folded archive carries no digit fraction and the live number is what "
                  "`agree` reads (CEO-475: the archive used to be parsed as the board number)")
        _markers = _after3.count(SUPERSEDE_PREFIX)
        if _markers != 1:
            print("SELFTEST FAIL: three successive folds left %d SUPERSEDE_MARKER occurrence(s), wanted "
                  "exactly 1 -- fold depth is not bounded, the cell grows by its whole history on every "
                  "landing" % _markers); ok = False
        elif "lake Baldwin" in _after3:
            print("SELFTEST FAIL: the oldest, twice-superseded reading survived a bounded fold -- dropping "
                  "it is the whole point of the bound"); ok = False
        elif "river Clifton" not in _after3 or "forest Denton" not in _after3:
            print("SELFTEST FAIL: the live reading or its one kept archive did not survive the bounded "
                  "fold: %r" % _after3); ok = False
        else:
            print("SELFTEST: three successive folds keep exactly one archived reading -- the cell stops "
                  "growing with fold depth instead of accumulating its whole history")

        # ⭐ THE MEASURER CONTRACT HAS TWO ARMS AND BOTH ARE TESTED. An absent or placeholder measurer on a
        # KNOWN root is DERIVED (the identity is a fact on disk, not a guess); on an UNKNOWN root there is
        # nothing to derive from and it still REFUSES. The old selftest asserted only the refusal, so it went
        # red the moment derivation landed -- correctly: it was pinning the behaviour that was being replaced.
        global S4E
        _real_s4e = S4E
        _saved_seat = os.environ.pop("S4E_SEAT", None)
        # ⛔ RESET rebus/board TO EMPTY FIRST. By this point the rewrite-in-place proof above left it
        # holding "rungs: m3 2/48 ..." -- real prior content that a3.text="1/1" would (correctly, per
        # cell_prose_loss) refuse to clobber, which is not what THIS block is testing. "—" is the file's
        # own empty-cell sentinel, so cell_prose_loss treats it as nothing-to-lose by construction.
        _reset_lines = open(SCORE_MD, encoding="utf-8").read().split("\n")
        _rh, _rr, _ = find_table(_reset_lines)
        _rri, _rrc = _rr["rebus"]
        _rrc[COLUMNS["board"][0]] = "—"
        _reset_lines[_rri] = "| " + " | ".join(_rrc) + " |"
        _write_score_md(_reset_lines, seeding=True)
        try:
            for label, root, want in (("absent measurer, known root", "/home/claude_T", "hq_T"),
                                      ("placeholder measurer, known root", "/home/claude_T", "hq_T"),
                                      ("absent measurer, numbered seat root", "/home/claude7", "seat07")):
                S4E = root
                a4 = A(); a4.modes = ""; a4.dry_run = False; a4.suite = ""
                a4.lang = "rebus"; a4.column = "board"; a4.text = "1/1"
                a4.measurer = "unknown-seat" if "placeholder" in label else ""
                a4.criterion_changed = "2026-09-16:selftest fixture 1/1 -- the measurer-derivation arm moves the fixture denominator (CEO-785)"
                try:
                    cmd_write(a4)
                    if a4.measurer == want:
                        print("SELFTEST: %s correctly DERIVED %r" % (label, want))
                    else:
                        print("SELFTEST FAIL: %s derived %r, wanted %r" % (label, a4.measurer, want)); ok = False
                except SystemExit as e:
                    print("SELFTEST FAIL: %s refused (rc=%s) instead of deriving %r" % (label, e.code, want)); ok = False
            S4E = "/tmp/not-a-seat-root"
            a5 = A(); a5.modes = ""; a5.dry_run = False; a5.suite = ""
            a5.lang = "rebus"; a5.column = "board"; a5.text = "1/1"; a5.measurer = "unknown-seat"
            a5.criterion_changed = "2026-09-16:selftest fixture 1/1 (CEO-785)"
            try:
                cmd_write(a5)
                print("SELFTEST FAIL: placeholder measurer on an UNKNOWN root did not refuse"); ok = False
            except SystemExit as e:
                if e.code == 2:
                    print("SELFTEST: placeholder measurer on an UNKNOWN root correctly REFUSED rc=2")
                else:
                    print("SELFTEST FAIL: unknown-root refusal exited %s, expected 2" % e.code); ok = False
        finally:
            S4E = _real_s4e
            if _saved_seat is not None: os.environ["S4E_SEAT"] = _saved_seat
        # the measurer arms left the fixture row at 1/1; put it back to the fixture denominator, stamped (CEO-785), so
        # every arm below is a write at 48 and never a denominator move
        _rs = subprocess.run([sys.executable, SUITE_BANNER, "--set", "reb-rungs", "0", "48", "2026-09-16", "selftest",
                              "--criterion-changed", "2026-09-16:selftest re-seed after the measurer arms -- back to the fixture denominator 48"],
                             capture_output=True, text=True, env=dict(os.environ, S4E_SUITES_TSV=SUITES_TSV, S4E_SCORE_MD=SCORE_MD))
        if _rs.returncode != 0:
            print("SELFTEST FAIL: the fixture re-seed (reb-rungs -> 0/48, stamped) refused rc=%d: %s" % (_rs.returncode, (_rs.stderr or _rs.stdout).strip()[:200])); ok = False
        # ⛔⭐ A FRACTION LABELLED BY A TRAILING FAILURE WORD IS NOT A PASS FRACTION -- and the two arms that
        # matter pull in OPPOSITE directions, which is why both are pinned. Under-drop and `924/986
        # PARSE-FAIL` convicts raku of a conflict with the grid's correct `4/986`; over-drop and icon's real
        # `153/153, FAIL=0` vanishes from the board. Nothing separates them but the comma and the `=`.
        for label, txt, want in (
                ("trailing PARSE-FAIL is not a pass fraction", "still 924/986 PARSE-FAIL, byte-identical", {}),
                ("a pass fraction survives beside a fail fraction of the SAME denominator",
                 "roast 4/986 pass · 924/986 PARSE-FAIL", {986: 4}),
                ("`FAIL=0` right after a fraction is a labelled count, NOT that fraction's name",
                 "m3 43/89 FAIL=0", {89: 43}),
                ("a comma before FAIL means it labels the clause, not the number",
                 "run-graded 563/569 both modes + ast 153/153, FAIL=0", {569: 563, 153: 153}),
                ("a bare trailing `fail` still drops", "jcon 38/81 fail", {}),
                # ⛔⭐ A SUPERSEDED READING CITED FOR PROVENANCE MUST NOT BECOME THE CELL'S VALUE, and these two
                # arms exist because the first cure of that bug BROKE THE LIVE NUMBER instead (hq_C s295, hq_T
                # 2026-09-04). Populations group by denominator keeping MIN(pass) -- the both-modes bar -- so a
                # cited older figure silently REPLACED the current one for the agree gate and the percentage
                # alike. The reported symptom was a red gate; the real defect was a WRONG VALUE that looked
                # conservative. ⛔ And the fix must not drop the DENOMINATOR: a superseded citation names THE
                # SAME population at an earlier time, so dropping it wholesale deletes the live measurement too
                # (measured: icon read {153: 153}, losing 596 entirely). One fraction leaves; the population stays.
                ("a superseded reading cited for provenance is not the cell's value",
                 "run-graded **596/596 both modes** + ast 153/153, FAIL=0 \u2014 hq_C read **595/596** on the tree before that cure",
                 {596: 596, 153: 153}),
                ("...and the older `was N/M` idiom no longer deletes the live population with it",
                 "**409/409** run-graded \u00b7 was 377/381", {409: 409})):
            got, _w = cell_fractions(txt)
            if cell_bar(got) == want:
                print("SELFTEST: %s" % label)
            else:
                print("SELFTEST FAIL: %s -- read %s, wanted %s (from %r)" % (label, cell_bar(got), want, txt)); ok = False
        # ⛔⭐ THE STALE MARK READS THE PROVENANCE LABEL, NOT PROSE. Arm 1 is the exact live defect Lon
        # named: an M cell measured TODAY that still printed `?` because its own commentary cites an older
        # date. Arm 4 is the opposite guard -- keying on the label must not make the cell's own explicit
        # word unsayable, or a human could never mark a cell stale by hand.
        _t = datetime.date.today()
        _today, _yday = _t.strftime("%Y-%m-%d"), (_t - datetime.timedelta(days=1)).strftime("%Y-%m-%d")
        _grid = [""] * (max(i for i, _n in GRID_COLUMNS.values()) + 1)
        def _prog(mcell, prov):
            # the scratch text goes in the V cell: since Lon 2026-09-04 the percent and its freshness are read
            # from V (the industry-standard packages), and M is printed beside as ours, never counted
            g = list(_grid); g[GRID_COLUMNS["V"][0]] = mcell; g[GRID_COLUMNS["M"][0]] = ""
            return language_progress("snobol4", g, prov)
        _st = lambda day: GRID_STAMP % (day, "hq_T")
        for label, mcell, prov, want in (
                ("an old date in PROSE does not stale a cell stamped TODAY",
                 "m3 10/10 (seat08, 2026-09-03, FINDING-...-09-03-...md) " + _st(_today), "", ""),
                ("a stamp older than today DOES stale it", "m3 10/10 " + _st(_yday), "", "?"),
                ("NO stamp reads STALE -- an undatable number is not a fresh one", "m3 10/10", "", "?"),
                ("the cell's own word STALE still wins over a fresh stamp",
                 "m3 10/10 STALE " + _st(_today), "", "?"),
                ("the stamp itself is never read as a population",
                 "m3 10/10 " + _st(_today), "", "")):
            _pct, mark, _P, _T, _w = _prog(mcell, prov)
            if mark == want:
                print("SELFTEST: %s" % label)
            else:
                print("SELFTEST FAIL: %s -- mark %r, wanted %r (%s)" % (label, mark, want, "; ".join(_w))); ok = False
        # ⛔⭐ THE GRID M COLUMN IS PARSED FOR A FRACTION AND THE DISPLAY COLUMN IS NOT -- a verbatim copy
        # between them published snobol4 at 55%% instead of 91%% (hq_P, as the dual-write's first customer).
        # Both directions pinned: the PASS=N board line -- which is the NATURAL way to print a board -- must
        # never reach the grid, and the fraction form must still land, or the guard would make the whole
        # dual-write inert while looking careful.
        for label, txt, want_frac in (
                ("a PASS=N board line carries no fraction the grid column can parse",
                 "m3 PASS=1698 FAIL=0 · m4 PASS=1698 FAIL=0 SKIP=0 MISSING=0", False),
                ("a board line WITH a fraction is grid-writable", "m3 1698/1736 FAIL=0 · m4 1698/1736", True)):
            got = bool(cell_fractions(txt)[0])
            if got == want_frac:
                print("SELFTEST: %s" % label)
            else:
                print("SELFTEST FAIL: %s -- fraction=%s, wanted %s" % (label, got, want_frac)); ok = False
        # ⛔⭐⭐ THE CELL THAT DISAGREES WITH ITSELF (hq_C 2026-09-06; cured hq_T 2026-09-10). These four arms
        # pin a cure whose whole content is a NEGATIVE -- that nothing is discarded -- and a negative has no
        # symptom to notice when it comes back. The old parser returned {114: 0} for a cell physically
        # holding `m3 82/114 · m4 0/114`; `agree` then compared 0 against 0 and AGREED, while the percent
        # reader took 82, so the published leaderboard was computed from a number the agreement gate had
        # never looked at. ⭐ Arm 3 is the one that keeps the cure honest in the OTHER direction: 24 live
        # cells write an m3/m4 twin with the SAME number in both modes, and a check that convicted those
        # would be switched off within the day.
        for label, txt, want_all, want_bar, want_amb in (
                ("both fractions of a one-denominator twin survive the extractor",
                 "swi_tests m3 82/114 · m4 0/114", {114: (82, 0)}, {114: 0}, [(114, (82, 0))]),
                ("the both-modes bar is still the worse mode, now as a caller's stated choice",
                 "--run 23/118 · --compile 17/118", {118: (23, 17)}, {118: 17}, [(118, (23, 17))]),
                ("a twin REPEATING one number is NOT ambiguous -- it is one measurement written twice",
                 "m3 743/756 · m4 743/756", {756: (743, 743)}, {756: 743}, []),
                ("a lone fraction is a one-tuple, never a scalar, so no caller can read it two ways",
                 "run-graded 85/89", {89: (85,)}, {89: 85}, [])):
            _all, _w = cell_fractions(txt)
            _bar, _amb = cell_bar(_all), cell_ambiguous(_all)
            if (_all, _bar, _amb) == (want_all, want_bar, want_amb):
                print("SELFTEST: %s" % label)
            else:
                print("SELFTEST FAIL: %s -- read all=%r bar=%r ambiguous=%r, wanted %r / %r / %r (from %r)"
                      % (label, _all, _bar, _amb, want_all, want_bar, want_amb, txt)); ok = False
        # ============ THE SUITE-TABLE SYNC (ceo CEO-363) -- the write half AND every refusal ============
        # ⛔ THE REFUSALS ARE THE PRODUCT HERE AS MUCH AS THE WRITE IS.  This mirror exists because three
        # fixers in one hour wrote a grid cell and left SUITES.tsv untouched; a mirror that GUESSED which
        # fraction to copy would replace a visible omission with an invisible wrong number carrying a
        # provenance stamp that says it was measured.  So each arm below proves a refusal refuses.
        def _tsv_row(key):
            for r in suites_rows()[0]:
                if r["key"] == key:
                    return r
            return None
        def _arm(label, fn, want_refuse):
            try:
                fn(); refused = False
            except SystemExit:
                refused = True
            if refused == want_refuse:
                print("SELFTEST: %s" % label); return True
            print("SELFTEST FAIL: %s -- %s" % (label, "refused" if refused else "did NOT refuse")); return False
        def _A(**kw):
            x = A()
            x.lang = "rebus"; x.column = "board"; x.measurer = "selftest"; x.modes = ""; x.suite = ""
            x.dry_run = False; x.text = "m3 7/48 · m4 7/48"; x.suite_key = ""; x.suite_pass = None
            x.suite_total = None; x.no_suite_sync = False
            for k, v in kw.items():
                setattr(x, k, v)
            return x
        # the existing write arms plant no progress rows: the DB cross-check is overridden LOUDLY for them and proven below
        os.environ["S4E_DB_CHECK_OVERRIDE"] = "selftest: the suite-sync arms plant no progress rows"
        _before = _tsv_row("reb-rungs")
        cmd_write(_A(text="m3 7/48 · m4 7/48"))
        _after = _tsv_row("reb-rungs")
        if _after and (_after["today_pass"], _after["today_total"]) == ("7", "48"):
            print("SELFTEST: an M-cell write SET the suite row in the same call (reb-rungs -> 7/48)")
        else:
            print("SELFTEST FAIL: an M-cell write left the suite row at %r" % (_after and (_after["today_pass"], _after["today_total"]),)); ok = False
        if _before is not None and _after is not None and _before["tree"] == _after["tree"] and _before["today_pass"] == "7":
            print("SELFTEST FAIL: suite row looks unchanged -- the arm above may be reading its own seed"); ok = False
        if not _arm("a V-cell write with no --suite REFUSES rather than guessing the suite row",
                    lambda: cmd_write(_A(column="vendor")), True): ok = False
        if not _arm("...and names the row it owes", lambda: cmd_write(_A(column="vendor")), True): ok = False
        if not _arm("DISAGREEING fractions REFUSE -- which mode the suite row means is a judgement",
                    lambda: cmd_write(_A(text="m3 7/48 · m4 6/48")), True): ok = False
        if not _arm("...and --suite-pass/--suite-total settle it",
                    lambda: cmd_write(_A(text="m3 7/48 · m4 6/48", suite_pass=6, suite_total=48)), False): ok = False
        if not _arm("AGREEING fractions across two modes are ONE reading, not an ambiguity",
                    lambda: cmd_write(_A(text="m3 9/48 · m4 9/48")), False): ok = False
        if not _arm("a text with NO fraction REFUSES", lambda: cmd_write(_A(text="m3 PASS=7 FAIL=41")), True): ok = False
        # ⛔⭐ THE CANONICAL BOARD LINE IS READ BY NAME, NOT RETYPED (hq_raku 2026-09-20, to the coo, on their first real
        # write: CEO-827 tells a runner to hand this writer its verbatim SUITE_BOARD line, and that line carries the
        # suite's fraction as `all_pass=830 all_n=927` -- key=value, not N/M -- so the writer refused the very line the
        # law asks for and every board-column write restated its own number on the command line.  A number that reaches
        # SUITES.tsv by being RETYPED is a transcription seam, and this file exists to close those.  Fields are read
        # word-bounded BY NAME (lib_board_line.sh's discipline, CEO-839), never by position.
        _BL = ("SUITE_BOARD family=ALL total=48 shipped=48 outside=0 m3_n=48 m3_pass=7 m3_fail=41 "
               "m4_n=48 m4_pass=7 m4_fail=41 all_pass=7 all_n=48 arena_mb=512")
        if not _arm("a canonical SUITE_BOARD line with NO N/M fraction WRITES -- all_pass=/all_n= are read by name",
                    lambda: cmd_write(_A(text=_BL)), False): ok = False
        _v = _tsv_row("reb-rungs")
        if _v and (_v["today_pass"], _v["today_total"]) == ("7", "48"):
            print("SELFTEST: ...and the row it set is the board line's OWN fraction (reb-rungs -> 7/48, nothing retyped)")
        else:
            print("SELFTEST FAIL: the board-line write left the suite row at %r" % (_v and (_v["today_pass"], _v["today_total"]),)); ok = False
        # ⛔ A SHARD BOARD IS NOT THE SUITE.  `--shard k/N` makes the harness print shard=k/N and a total that is THIS
        # SHARD's entries; the old scan matched that k/N as an N/M fraction, so a shard line handed as --text wrote
        # pass=k total=N -- a real number under a provenance stamp, the one outcome worse than refusing.
        if not _arm("a shard= token is NEVER the suite's fraction (a shard board is not the suite)",
                    lambda: cmd_write(_A(text="SUITE_BOARD family=ALL shard=2/4 total=12 m3_pass=3 m4_pass=3")), True): ok = False
        if not _arm("a board line whose all_pass/all_n DISAGREE with a fraction in the same text REFUSES",
                    lambda: cmd_write(_A(text="m3 9/48 · " + _BL)), True): ok = False
        if not _arm("a board line carrying all_pass= but no all_n= REFUSES naming the missing field",
                    lambda: cmd_write(_A(text="SUITE_BOARD family=ALL total=48 m3_pass=7 all_pass=7")), True): ok = False
        # ⛔ AND THE GRID HALF STOPS REFUSING THE SAME LINE. The `no N/M fraction` guard was RIGHT about
        # pass/(pass+fail) and wrong to fire here: `all_n=` IS the population. The cell may still be held back
        # by the PROSE guard -- that one is a different ruling and is left exactly as it was -- so this arm
        # asserts the two messages by name rather than asserting the cell was written.
        import io as _io, contextlib as _ctx
        _cap = _io.StringIO()
        with _ctx.redirect_stdout(_cap):
            try: cmd_write(_A(text=_BL))
            except SystemExit: pass
        _capped = _cap.getvalue()
        if "carries NO `N/M` fraction" not in _capped and "restated as 7/48 in the cell" in _capped:
            print("SELFTEST: the grid half reads all_pass=/all_n= by name too -- the NO-N/M refusal no longer fires on a canonical board line")
        else:
            print("SELFTEST FAIL: the grid half still refuses the canonical board line for want of an N/M fraction"); ok = False
        # ⛔ THE PROSE GUARD NAMES WHICH KIND OF STALE IT IS (hq_raku 2026-09-20, from inside the guard). The live rebus
        # grid M cell states 43/43 and carries commentary no runner models, so a write of 43/43 is a NO-OP BY VALUE and a
        # write of 7/48 is a real divergence -- and before today both printed the same sentence. The guard still refuses
        # in both cases; only the reading is now distinguishable. (The 43/43 arm moves the fixture denominator 48 -> 43,
        # so it carries its own --criterion-changed; that refusal is proven by its own arms further down.)
        _cap2 = _io.StringIO()
        with _ctx.redirect_stdout(_cap2):
            try: cmd_write(_A(text="m3 43/43 · m4 43/43", criterion_changed="2026-09-20:selftest fixture aligning the write with the grid cell's own fraction to exercise the provenance-only path"))
            except SystemExit: pass
        if "STALE BY PROVENANCE ONLY" in _cap2.getvalue():
            print("SELFTEST: the prose guard says STALE BY PROVENANCE ONLY when the value it would write is the value already there")
        else:
            print("SELFTEST FAIL: a no-op-by-value write still reads as STALE BY THIS WRITE, so a seat cannot tell it from a real divergence\n        what it printed: %s" % (_cap2.getvalue()[-600:] or "<silent>")); ok = False
        _cap3 = _io.StringIO()
        with _ctx.redirect_stdout(_cap3):
            try: cmd_write(_A(text="m3 7/43 · m4 7/43"))
            except SystemExit: pass
        if "STALE BY VALUE" in _cap3.getvalue() and "STALE BY PROVENANCE ONLY" not in _cap3.getvalue():
            print("SELFTEST: ...and STALE BY VALUE when it differs, with both fractions named")
        else:
            print("SELFTEST FAIL: a real divergence did not read as STALE BY VALUE"); ok = False
        # ⛔ PUT THE FIXTURE BACK WHERE THE ARMS BELOW EXPECT IT. The two arms above had to align with the LIVE grid
        # cell's 43/43 to exercise the value comparison at all, which moves the scratch row's denominator off 48; every
        # arm after this one writes N/48 and would meet the (correct) denominator-move refusal instead of its own subject.
        cmd_write(_A(text="m3 9/48 · m4 9/48", criterion_changed="2026-09-20:selftest fixture restored to the 48 denominator the arms below are written against"))
        if not _arm("--no-suite-sync is a labelled escape, not a refusal",
                    lambda: cmd_write(_A(text="m3 PASS=7 FAIL=41", no_suite_sync=True)), False): ok = False
        # ⛔ THE SETTER TAKES ITS NUMBER FROM THE APPEND (hq_raku 2026-09-16): a scratch DB with 7 PASS + 41 FAIL rebus-rungs rows on
        # THIS tree; --suite-pass 7 writes, 8 refuses naming both numbers, a labelled DB bounds (9 PASS outcome-class accepts 7), and a
        # tree with no rows refuses under CEO-750.
        os.environ.pop("S4E_DB_CHECK_OVERRIDE", None)
        _dbp = os.path.join(d, "results.tsv"); _tr = suite_tree_stamp().replace("-DIRTY", "-dirty")
        def _plant(npass, nfail, note=""):
            with open(_dbp, "w", encoding="utf-8") as _fh:
                _fh.write("ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\n")
                for _i in range(npass + nfail):
                    for _m in ("m3", "m4"):
                        _fh.write("2026-09-17T00:00:00\t%s\tc\tselftest\trungs\trebus-rungs\trebus\tr%d\t%s\t%s\t0\t%s\n"
                                  % (_tr, _i, _m, "PASS" if _i < npass else "FAIL", note))
        os.environ["S4E_PROGRESS_DB"] = _dbp; _plant(9, 39)   # the row stands at 9/48 from the arm above and must still after these
        if not _arm("DB CROSS-CHECK: --suite-pass 9 with 9 PASS rows on this tree in the progress DB writes",
                    lambda: cmd_write(_A(text="m3 9/48 · m4 9/48", suite_pass=9, suite_total=48)), False): ok = False
        if not _arm("DB CROSS-CHECK: --suite-pass 10 against 9 PASS rows on this tree REFUSES (a printed number is not the append)",
                    lambda: cmd_write(_A(text="m3 10/48 · m4 10/48", suite_pass=10, suite_total=48)), True): ok = False
        _plant(11, 37, "outcome-class")
        if not _arm("DB CROSS-CHECK: a DB whose rows carry a criterion label BOUNDS the row (11 PASS outcome-class accepts --suite-pass 9)",
                    lambda: cmd_write(_A(text="m3 9/48 · m4 9/48", suite_pass=9, suite_total=48)), False): ok = False
        if not _arm("DB CROSS-CHECK: ...and refuses above the bound (--suite-pass 12 over 11)",
                    lambda: cmd_write(_A(text="m3 12/48 · m4 12/48", suite_pass=12, suite_total=48)), True): ok = False
        open(_dbp, "w", encoding="utf-8").write("ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\n")
        if not _arm("DB CROSS-CHECK: NO rows on this tree REFUSES (CEO-750: a row without per-program evidence is DARK)",
                    lambda: cmd_write(_A(text="m3 9/48 · m4 9/48", suite_pass=9, suite_total=48)), True): ok = False
        os.environ.pop("S4E_PROGRESS_DB", None)
        os.environ["S4E_DB_CHECK_OVERRIDE"] = "selftest: the remaining arms plant no progress rows"
        if not _arm("an unresolvable --suite REFUSES and names the row",
                    lambda: cmd_write(_A(column="vendor", suite="no-such-suite-anywhere")), True): ok = False
        _snap = open(SCORE_MD, encoding="utf-8").read()
        _arm("a refusal in the suite mirror still refuses", lambda: cmd_write(_A(text="m3 5/48 · m4 4/48")), True)
        if open(SCORE_MD, encoding="utf-8").read() == _snap:
            print("SELFTEST: a REFUSED write leaves SCORE.md byte-identical -- rc=2 means NOTHING was written, so a runner reading the rc tells the truth")
        else:
            print("SELFTEST FAIL: a REFUSED write had already rewritten SCORE.md -- the runner that reads rc=2 prints NOT UPDATED over a row it wrote"); ok = False
        _v = _tsv_row("reb-rungs")
        if _v and _v["today_pass"] == "9":
            print("SELFTEST: the last accepted write is the one that stands (9/48) -- rewrite-in-place holds for the suite row too")
        else:
            print("SELFTEST FAIL: suite row reads %r after the arms; a refusal must leave it untouched" % (_v and _v["today_pass"],)); ok = False
        # ⛔⭐⭐ THE ANCESTOR ARM, BOTH WAYS (ceo CEO-492). Proving the refusal alone would be half a proof
        # and the dangerous half: a guard that refuses EVERYTHING also refuses every ancestor, prints the
        # right sentence, and stops the board dead. So the same fixture is run twice with the two trees
        # SWAPPED -- backwards must refuse, forwards must land -- and only the pair says the guard can
        # tell them apart.
        # ⭐ THE FIXTURE IS REAL HISTORY, NOT A MOCK. `S4E_TREE_AT_START` (tree_stamp's own hook, set by a
        # runner at the START of a long board) makes this write stamp a tree we choose, and the seeded
        # provenance clause carries the other -- so `git merge-base` answers about two commits that
        # genuinely exist in this checkout. A stubbed ancestry would prove the plumbing and nothing about
        # whether the question asked of git is the right one.
        _anc_old = git("SCRIP", "rev-parse", "--short", "HEAD~5") or git("SCRIP", "rev-parse", "--short", "HEAD~1")
        _anc_new = git("SCRIP", "rev-parse", "--short", "HEAD")
        if not _anc_old or not _anc_new or _anc_old == _anc_new:
            # ⛔ CANNOT MEASURE IS NOT PASS. Without two real commits there is no ancestor to test, and a
            # silent skip here would report a green selftest for a guard nothing exercised.
            print("SELFTEST FAIL (CANNOT MEASURE): no two distinct SCRIP commits in this checkout, so the "
                  "ancestor arm could not be built -- the ancestry refusal is UNPROVEN, not proven"); ok = False
        else:
            def _seed_prov(tree):
                _l = open(SCORE_MD, encoding="utf-8").read().split("\n")
                _h, _r, _ = find_table(_l)
                _i, _c = _r["rebus"]
                _c[COLUMNS["board"][0]] = "rungs: m3 9/48 · m4 9/48 (selftest seed)"
                _c[PROV_COL] = merge_prov(_c[PROV_COL], "board",
                                          "SCRIP `%s` · RT_OPT=-O0 · seeded · selftest" % tree)
                _l[_i] = "| " + " | ".join(_c) + " |"
                _write_score_md(_l, seeding=True)

            def _anc_write(stamp_tree, label):
                _prev = os.environ.get("S4E_TREE_AT_START")
                os.environ["S4E_TREE_AT_START"] = "SCRIP=%s" % stamp_tree
                a9 = A(); a9.lang = "rebus"; a9.column = "board"; a9.measurer = "selftest"
                a9.text = "rungs: m3 11/48 · m4 11/48 (%s, not a measurement)" % label
                a9.modes = "m3,m4"; a9.dry_run = False; a9.suite = ""
                try:
                    cmd_write(a9)
                    return None
                except SystemExit as e:
                    return e.code
                finally:
                    if _prev is None:
                        os.environ.pop("S4E_TREE_AT_START", None)
                    else:
                        os.environ["S4E_TREE_AT_START"] = _prev

            if tree_ancestry(_anc_old, _anc_new) != "older":
                print("SELFTEST FAIL (CANNOT MEASURE): tree_ancestry does not call %s an ancestor of %s, so "
                      "the fixture itself is wrong and neither arm below proves anything" % (_anc_old, _anc_new)); ok = False
            else:
                _seed_prov(_anc_new)
                _before9 = open(SCORE_MD, encoding="utf-8").read()
                _rc9 = _anc_write(_anc_old, "backwards")
                if _rc9 != 2:
                    print("SELFTEST FAIL: a write stamping %s over a cell stamped %s -- an ANCESTOR tree -- "
                          "exited %r, expected a rc=2 refusal" % (_anc_old, _anc_new, _rc9)); ok = False
                elif open(SCORE_MD, encoding="utf-8").read() != _before9:
                    print("SELFTEST FAIL: the ancestor refusal rewrote SCORE.md anyway -- rc=2 must mean NOTHING was written"); ok = False
                else:
                    print("SELFTEST: a rewrite whose tree is an ANCESTOR of the cell's stamped tree correctly "
                          "REFUSED rc=2 (%s under %s) and left the file byte-identical" % (_anc_old, _anc_new))
                _seed_prov(_anc_old)
                _rc10 = _anc_write(_anc_new, "forwards")
                _cell10 = find_table(open(SCORE_MD, encoding="utf-8").read().split("\n"))[1]["rebus"][1][COLUMNS["board"][0]]
                if _rc10 is not None:
                    print("SELFTEST FAIL: the FORWARD write (tree %s over a cell stamped ancestor %s) refused "
                          "rc=%s -- the ancestry guard is refusing in both directions, which is not a guard" % (_anc_new, _anc_old, _rc10)); ok = False
                elif "11/48" not in _cell10:
                    print("SELFTEST FAIL: the forward write returned 0 but the cell reads %r" % _cell10[:120]); ok = False
                else:
                    print("SELFTEST: the same write with the two trees SWAPPED -- a DESCENDANT tree over an "
                          "older stamp -- landed normally, so the ancestor refusal discriminates rather than blocks")
        # ⛔⭐ THE COLUMN-COUNT ARM (CEO-610 / COO-62).  Fail-once AND pass-once, because a guard proven
        # only on the bad input is indistinguishable from one that refuses everything -- and this one
        # sits in the path of every write in the fleet, so refusing everything is the expensive failure.
        _cc = open(SCORE_MD, encoding="utf-8").read().split("\n")
        _ch, _cr, _ = find_table(_cc)
        _ci, _cc_cells = _cr["rebus"]
        _widened = list(_cc_cells) + ["a stray cell, exactly the CEO-610 shape"]
        _cc[_ci] = "| " + " | ".join(_widened) + " |"
        _before_cc = open(SCORE_MD, encoding="utf-8").read()
        try:
            _write_score_md(_cc)
            print("SELFTEST FAIL: a write that gave the rebus row a SEVENTH cell in a six-column table "
                  "was ACCEPTED -- the column-count invariant is not holding, and a row with the wrong "
                  "count is dropped whole by every reader that parses the table"); ok = False
        except SystemExit as e:
            if e.code != 2 or open(SCORE_MD, encoding="utf-8").read() != _before_cc:
                print("SELFTEST FAIL: the column-count refusal returned rc=%r and/or did not leave the "
                      "file byte-identical -- a refusal that half-writes is worse than none" % (e.code,)); ok = False
            else:
                print("SELFTEST: a write that would widen a row to 7 cells in a 6-column table correctly "
                      "REFUSED rc=2 and left SCORE.md byte-identical (CEO-610's own shape)")
        # ⭐ PASS-ONCE, and the case that matters is not "an ordinary write still works" -- it is that a
        # row somebody ELSE already left ragged does not turn this into a fleet-wide stop.  That is the
        # differential half of the check, and it is the half that would have been quietly wrong.
        _rag = open(SCORE_MD, encoding="utf-8").read().split("\n")
        _rh, _rr, _ = find_table(_rag)
        _rgi, _rgc = _rr["raku"]
        _rag[_rgi] = "| " + " | ".join(list(_rgc) + ["pre-existing damage, not this write's"]) + " |"
        _write_score_md(_rag, seeding=True)
        a8 = A(); a8.lang = "rebus"; a8.column = "board"; a8.measurer = "selftest"
        a8.text = "rungs: m3 12/48 · m4 12/48 (past a ragged neighbour, not a measurement)"
        a8.modes = "m3,m4"; a8.dry_run = False; a8.suite = ""
        try:
            cmd_write(a8)
            if "12/48" in open(SCORE_MD, encoding="utf-8").read():
                print("SELFTEST: an unrelated write still lands while ANOTHER row is already ragged -- the "
                      "invariant is differential, so one seat's damage does not stop the other twelve")
            else:
                print("SELFTEST FAIL: the write past a ragged neighbour reported success but did not land"); ok = False
        except SystemExit as e:
            print("SELFTEST FAIL: a ragged row belonging to ANOTHER language blocked an unrelated write "
                  "(rc=%r) -- that turns one seat's damage into a fleet-wide stop" % (e.code,)); ok = False
        # ⛔ A HASH QUOTED INSIDE A CELL IS NOT THE CELL'S CLAIM (hq_prolog 2026-09-16): plant a rebus vendor cell whose body cites an unknown old
        # tree beside a `vendor:` provenance clause at HEAD -- check must grade the clause (ok/STALE by ITS distance, 'cell claims <HEAD>') and
        # never the quote; with the clause removed the cell reads UNSTAMPED, naming the quoted hash as not a claim.
        import io as _io, contextlib as _ctx
        _head = git("SCRIP", "rev-parse", "--short", "HEAD") or ""
        _ck_lines = open(SCORE_MD, encoding="utf-8").read().split("\n")
        _ch, _cr, _ = find_table(_ck_lines); _cri, _crc = _cr["rebus"]
        _crc[COLUMNS["vendor"][0]] = "Reb: 1/1 both modes; SUPERSEDES the old reading (hq_X SCRIP `deadbeef0` 09-05)"
        _crc[PROV_COL] = "vendor: SCRIP `%s` · corpus `x` · RT_OPT=-O0 · 2026-09-16 · selftest" % _head
        _ck_lines[_cri] = "| " + " | ".join(_crc) + " |"; _write_score_md(_ck_lines, seeding=True)
        _ca = A(); _ca.threshold = 25; _ca.no_fetch = True
        _buf = _io.StringIO()
        with _ctx.redirect_stdout(_buf):
            try: cmd_check(_ca)
            except SystemExit: pass
        _vl = [l for l in _buf.getvalue().split("\n") if l.startswith("  rebus") and " vendor " in l]
        if _vl and "cell claims %s" % _head in _vl[0] and "deadbeef0" not in _vl[0]:
            print("SELFTEST: check grades the `vendor:` clause's stamp (cell claims %s) and never the hash quoted in the cell body" % _head)
        else:
            print("SELFTEST FAIL: quoted hash read as the claim -- %r" % (_vl[:1],)); ok = False
        _crc[PROV_COL] = "board: SCRIP `%s` · selftest" % _head
        _ck_lines[_cri] = "| " + " | ".join(_crc) + " |"; _write_score_md(_ck_lines, seeding=True)
        _buf = _io.StringIO()
        with _ctx.redirect_stdout(_buf):
            try: cmd_check(_ca)
            except SystemExit: pass
        _vl = [l for l in _buf.getvalue().split("\n") if l.startswith("  rebus") and " vendor " in l]
        if _vl and "UNSTAMPED" in _vl[0] and "deadbeef0" in _vl[0] and "not read as a claim" in _vl[0]:
            print("SELFTEST: a cell with no `vendor:` clause reads UNSTAMPED, its quoted hash named as not a claim")
        else:
            print("SELFTEST FAIL: unstamped cell -- %r" % (_vl[:1],)); ok = False
        # ⛔ COLUMN KIND: a rung suite runner named with the vendor suffix classifies M, a vendor runner still V (hq_raku 2026-09-16)
        _ck = (citation_kind("bash ../harness/scripts/test_raku_ir_full_suite.sh"), citation_kind("bash ../harness/scripts/test_icon_ipl_suite.sh"),
               citation_kind("bash ../harness/scripts/test_prolog_rung_suite.sh"))
        if _ck == ("M", "V", "L"):
            print("SELFTEST: citation_kind reads the Raku rungs runner as M (its name ends in the vendor suffix), a vendor runner as V, the Prolog rung runner as L")
        else:
            print("SELFTEST FAIL: citation_kind gave %r for (raku rungs, ipl vendor, prolog rung), wanted ('M', 'V', 'L')" % (_ck,)); ok = False
        # ⭐⭐ --column bench-ref: A SUITE-TABLE ROW WITH NO GRID CELL (coo 2026-09-23, CEO-1221; row instruments-benchmarks-enter-the-
        # suite-grid-...). The fixture PLANTS its own empty rebus-bench-ref row in the scratch table, so these arms read the same on a
        # root whose real SUITES.tsv predates the benchmark rows. Proven: the first write sets the row AND its first_* (a row that
        # entered empty), the grid and display cells for the language stay byte-identical, a second write moves today_* and never
        # first_*, a rung suite key forced through this path refuses byte-identical, a language with no bench row refuses, and a dry run
        # writes nothing.
        _tl = [l for l in open(SUITES_TSV, encoding="utf-8").read().split("\n") if not l.startswith("rebus-bench-ref\t")]
        while _tl and _tl[-1] == "":
            _tl.pop()
        _tl.append("\t".join(["rebus-bench-ref", "RebBench", "⏱️", "rebus"] + [""] * 8))
        open(SUITES_TSV, "w", encoding="utf-8").write("\n".join(_tl) + "\n")
        def _rebus_cells():
            _ls = open(SCORE_MD, encoding="utf-8").read().split("\n")
            _gh, _gr, _ = find_grid(_ls); _th, _tr, _ = find_table(_ls)
            return (_gr.get("rebus"), _tr.get("rebus", (None, None))[1])
        _cells0 = _rebus_cells()
        _bl = "SUITE_BOARD family=rebus-bench-ref total=3 shipped=3 all_pass=2 all_n=3 m3_pass=2 m4_pass=3 (selftest, not a measurement)"
        if not _arm("--column bench-ref resolves rebus-bench-ref from --lang and WRITES the suite row (a board line read by name)",
                    lambda: cmd_write(_A(column="bench-ref", text=_bl)), False): ok = False
        _r = _tsv_row("rebus-bench-ref") or {}
        if (_r.get("today_pass"), _r.get("today_total"), _r.get("first_pass"), _r.get("first_total")) == ("2", "3", "2", "3") and _r.get("first_date"):
            print("SELFTEST: ...the row reads 2/3 and its FIRST reading is filled by the same write (it entered the table empty)")
        else:
            print("SELFTEST FAIL: bench-ref first write -- row %r" % ({k: _r.get(k) for k in ("first_date", "first_pass", "first_total", "today_pass", "today_total")},)); ok = False
        if _rebus_cells() == _cells0:
            print("SELFTEST: ...and the rebus grid row and display row are byte-identical: no grid cell is written for a benchmark row")
        else:
            print("SELFTEST FAIL: a bench-ref write moved a rebus grid or display cell -- the B cell is the timing reading and must not be touched"); ok = False
        if any(l.startswith("| RebBench | rebus | 2/3 |") for l in open(SCORE_MD, encoding="utf-8").read().split("\n")):
            print("SELFTEST: ...and SCORE.md's suite table carries the RebBench line, rendered by the same call")
        else:
            print("SELFTEST FAIL: the bench-ref write left no '| RebBench | rebus | 2/3 |' line in the suite table"); ok = False
        if not _arm("a second bench-ref write lands", lambda: cmd_write(_A(column="bench-ref", text=_bl.replace("all_pass=2", "all_pass=3"))), False): ok = False
        _r = _tsv_row("rebus-bench-ref") or {}
        if (_r.get("today_pass"), _r.get("first_pass")) == ("3", "2"):
            print("SELFTEST: ...today moved to 3/3 and the first reading stayed 2/3 (never re-baselined)")
        else:
            print("SELFTEST FAIL: second bench-ref write -- today_pass %r first_pass %r" % (_r.get("today_pass"), _r.get("first_pass"))); ok = False
        _b_md = open(SCORE_MD, "rb").read(); _b_tsv = open(SUITES_TSV, "rb").read()
        # ⛔ THE FORCED WRITE CARRIES THE RUNGS'S OWN DENOMINATOR, so the ONLY guard that can refuse it is the one under test. The
        # first cut used the bench fixture's 2/3, and a mutant with the guard removed stayed GREEN: CEO-785's stampless-denominator
        # refusal (48 -> 3) fired instead -- an arm green for a reason other than the one its label names (COO-153's shape).
        _mt = (_tsv_row("reb-rungs") or {}).get("today_total", "48")
        _ml = "SUITE_BOARD family=ALL total=%s shipped=%s all_pass=7 all_n=%s (selftest, not a measurement)" % (_mt, _mt, _mt)
        if not _arm("a RUNGS key forced through --column bench-ref (--suite-key reb-rungs, its own denominator %s) REFUSES" % _mt,
                    lambda: cmd_write(_A(column="bench-ref", suite_key="reb-rungs", text=_ml)), True): ok = False
        if not _arm("a language with no bench row (--lang cobol) REFUSES", lambda: cmd_write(_A(column="bench-ref", lang="cobol", text=_bl)), True): ok = False
        if not _arm("a bench-ref --dry-run lands nothing", lambda: cmd_write(_A(column="bench-ref", dry_run=True, text=_bl.replace("all_pass=2", "all_pass=1"))), False): ok = False
        if open(SCORE_MD, "rb").read() == _b_md and open(SUITES_TSV, "rb").read() == _b_tsv:
            print("SELFTEST: ...the two refusals and the dry run left SCORE.md and SUITES.tsv byte-identical")
        else:
            print("SELFTEST FAIL: a bench-ref refusal or dry run wrote something"); ok = False
        # ⛔⭐ CEO-785 -- A CRITERION CHANGE IS STAMPED BY THE WRITER, AND A DENOMINATOR MOVE WITHOUT ITS STAMP REFUSES BEFORE
        # ANY WRITE (coo 2026-09-16; row instruments-util-score-row-cannot-stamp-a-criterion-change-so-every-denominator-move-
        # is-hand-edited-or-unstamped). Last in the selftest because it leaves the fixture row at 49.
        _b_md = open(SCORE_MD, "rb").read(); _b_tsv = open(SUITES_TSV, "rb").read()
        if not _arm("a write that moves the denominator (48 -> 49) without --criterion-changed REFUSES (CEO-785)",
                    lambda: cmd_write(_A(text="m3 7/49 · m4 7/49")), True): ok = False
        if open(SCORE_MD, "rb").read() == _b_md and open(SUITES_TSV, "rb").read() == _b_tsv:
            print("SELFTEST: ...and the refusal left SCORE.md and SUITES.tsv byte-identical")
        else:
            print("SELFTEST FAIL: the stampless denominator refusal wrote something -- a refusal must leave both files byte-identical"); ok = False
        if not _arm("a --text naming an INSTRUMENT CHANGE without --criterion-changed REFUSES (CEO-785)",
                    lambda: cmd_write(_A(text="m3 7/48 · m4 7/48 INSTRUMENT CHANGE fixture")), True): ok = False
        if not _arm("a malformed --criterion-changed (no YYYY-MM-DD: prefix) REFUSES",
                    lambda: cmd_write(_A(text="m3 7/49 · m4 7/49", criterion_changed="because")), True): ok = False
        _stamp = "2026-09-16:selftest -- the fixture denominator moves 48 -> 49"
        if not _arm("the same denominator move WITH --criterion-changed lands",
                    lambda: cmd_write(_A(text="m3 7/49 · m4 7/49", criterion_changed=_stamp)), False): ok = False
        _r = _tsv_row("reb-rungs")
        _cc = (_r or {}).get("criterion_changed", "")
        if _r and _r["today_total"] == "49" and _cc.endswith(_stamp) and " | " + _stamp in _cc:
            print("SELFTEST: the stamped move set reb-rungs to 49 and APPENDED the stamp to column 12 with ' | ' (the seed's stamp kept before it)")
        else:
            print("SELFTEST FAIL: stamped move -- total %r, criterion_changed %r" % ((_r or {}).get("today_total"), _cc)); ok = False
        # ⭐ CEO-827: THE VERBATIM BOARD LINE RIDES WITH THE ROW WRITE.  Three arms, on a scratch archive dir: a
        # board line is archived once, an identical second write does not duplicate it, and a --text that carries
        # NO board line says so loudly instead of leaving the reader to assume a line was kept.
        if True:
            _buf = []
            _line = "SUITE_BOARD family=ALL total=1982 m3_pass=1970 m3_skip=0 m4_pass=1967 m4_skip=3"
            _p1 = archive_board_line("the runner printed: " + _line, "sno-rungs", "coo", "b12714737", out=_buf.append)
            _p2 = archive_board_line(_line, "sno-rungs", "coo", "b12714737", out=_buf.append)
            _p3 = archive_board_line("the snobol4 rungs reads 1967/1982", "sno-rungs", "coo", "b12714737", out=_buf.append)
            _txt = open(_p1, encoding="utf-8").read() if _p1 else ""
            if _p1 and _p2 == _p1 and _p3 is None and _txt.count(_line) == 1 \
               and any("already archived" in x for x in _buf) and any("NOT ARCHIVED" in x for x in _buf):
                print("SELFTEST: the verbatim board line is archived once, not duplicated on a re-write, and a receipt "
                      "with no board line SAYS SO (CEO-827)")
            else:
                print("SELFTEST FAIL: board-line archive -- p1=%r p2=%r p3=%r occurrences=%d" %
                      (_p1, _p2, _p3, _txt.count(_line))); ok = False
        # ⛔⭐ THE REFUSAL SELF-CHECK, BOTH DIRECTIONS (coo 2026-09-20, the ceo's reported finding).
        # Four hand-written arms above already prove byte-identity for four refusal paths.  These two
        # prove the MECHANISM that now covers all 44, so adding a refusal no longer means remembering
        # to add an arm -- and, just as important, that it does NOT fire on an honest refusal.
        _rw_probe = os.path.join(d, "refusal_watch_probe.md")
        open(_rw_probe, "w", encoding="utf-8").write("seed\n")
        _saved_watch = dict(_REFUSAL_WATCH); _saved_wrote = set(_WROTE_DELIBERATELY)
        try:
            _REFUSAL_WATCH.clear(); _WROTE_DELIBERATELY.clear()
            _REFUSAL_WATCH[_rw_probe] = _digest(_rw_probe)
            if _refusal_watch_report() == "":
                print("SELFTEST: a refusal with the file UNTOUCHED reports nothing extra (no false positive on an honest refusal)")
            else:
                print("SELFTEST FAIL: the refusal self-check fired on a file nobody wrote"); ok = False
            open(_rw_probe, "a", encoding="utf-8").write("planted\n")
            _rep = _refusal_watch_report()
            if "NOT TRUE OF" in _rep and _rw_probe in _rep:
                print("SELFTEST: a refusal AFTER an undeclared write is NAMED -- die() contradicts its own "
                      "'NOTHING WAS WRITTEN' and says which file moved (all 44 refusal sites, by construction)")
            else:
                print("SELFTEST FAIL: an undeclared mutation before a refusal was not reported: %r" % _rep[:200]); ok = False
            refusal_watch_wrote(_rw_probe)
            open(_rw_probe, "a", encoding="utf-8").write("declared\n")
            _rep2 = _refusal_watch_report()
            if "PARTIAL, MEASURED" in _rep2 and "NOT TRUE OF" not in _rep2:
                print("SELFTEST: a refusal after a DELIBERATE write reads PARTIAL, not manufacture -- the two are "
                      "different animals and the digest is what tells them apart")
            else:
                print("SELFTEST FAIL: a declared write before a refusal did not read PARTIAL: %r" % _rep2[:200]); ok = False
        finally:
            _REFUSAL_WATCH.clear(); _REFUSAL_WATCH.update(_saved_watch)
            _WROTE_DELIBERATELY.clear(); _WROTE_DELIBERATELY.update(_saved_wrote)
        # ⛔⭐ AND THE NOTICE THAT WOULD HAVE ANSWERED THE ceo's QUESTION AT THE TIME: a write whose reading
        # did not move must SAY it moved only the stamp, and must stay quiet when the reading really moved.
        _pb = "smoke: SCRIP `aaaaaaaaa` · corpus `bbbbbbbbb` · 2026-09-13 17:59 CDT · hq_T; floor: SCRIP `2d403670f` · corpus `fcfeb6a92` · 2026-09-13 17:59 CDT · hq_T"
        _pa = "smoke: SCRIP `aaaaaaaaa` · corpus `bbbbbbbbb` · 2026-09-13 17:59 CDT · hq_T; floor: SCRIP `5367103df` · corpus `8d4656ada` · 2026-09-20 08:25 CDT · ceo"
        _same = unchanged_reading_note("display row", "raku", "smoke 10/10", "smoke 10/10", _pb, _pa, 128, "floor")
        if ("READING UNCHANGED" in _same and "2d403670f -> 5367103df" in _same
                and "fcfeb6a92 -> 8d4656ada" in _same and "hq_T -> ceo" in _same):
            print("SELFTEST: an unchanged reading whose stamp moved is NAMED with all four fields "
                  "(the ceo's own occurrence, replayed)")
        else:
            print("SELFTEST FAIL: unchanged-reading notice did not name the moved fields: %r" % _same[:300]); ok = False
        # ⛔ THE KEY, NOT THE CELL: raku's prov cell LEADS with `smoke:`, whose tree did not move.  Reading
        # the cell whole made the first draft of this notice report "provenance unchanged" on the very
        # occurrence it was written for.  This arm holds the clause-keyed read that fixed it.
        if "provenance unchanged" in unchanged_reading_note("display row", "raku", "x", "x", _pb, _pa, 128, "smoke"):
            print("SELFTEST: the notice reads the clause for ITS OWN key -- an untouched `smoke:` clause reads untouched "
                  "even while `floor:` moved in the same cell")
        else:
            print("SELFTEST FAIL: the unchanged-reading notice is reading the whole prov cell, not its key's clause"); ok = False
        if unchanged_reading_note("display row", "raku", "smoke 10/10", "smoke 9/10", _pb, _pa, 128, "floor") == "":
            print("SELFTEST: a reading that REALLY moved prints no notice (the notice is about stamps, not about writes)")
        else:
            print("SELFTEST FAIL: the unchanged-reading notice fired on a write that moved the reading"); ok = False
        # ⛔⭐ A RUN'S CLOCK NEVER REACHES THE WALL (Lon 2026-10-18: "show the sum of minimum times of eac member. NOT the maximum nor the current."; it replaces the
        # CEO-1562 arm that proved a write under S4E_RUN_T0 landed now - S4E_RUN_T0 as WALL=): the same write leaves today_secs blank and the cell without WALL=.
        os.environ["S4E_RUN_T0"] = str(int(time.time()) - 125)
        try:
            if not _arm("a bench-ref write under S4E_RUN_T0 lands without a wall clock",
                        lambda: cmd_write(_A(column="bench-ref", text=_bl.replace("all_pass=2", "all_pass=3"))), False): ok = False
        finally:
            os.environ.pop("S4E_RUN_T0", None)
        _ws = ((_tsv_row("rebus-bench-ref") or {}).get("today_secs") or "")
        if _ws == "" and not any(l.startswith("| RebBench | rebus | 3/3 WALL=") for l in open(SCORE_MD, encoding="utf-8").read().split("\n")):
            print("SELFTEST: ...a run's clock never reaches today_secs or the WALL= cell (the Wall is the sum of each member's minimum)")
        else:
            print("SELFTEST FAIL: a run's clock reached the Wall -- today_secs %r, RebBench line %r" % (_ws, [l for l in open(SCORE_MD, encoding="utf-8").read().split("\n") if l.startswith("| RebBench ")][:1])); ok = False
    finally:
        SCORE_MD = real
        SUITES_TSV = real_tsv
        BOARD_LINES_DIR = real_bl
        shutil.rmtree(d, ignore_errors=True)
    print("SELFTEST %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


# ============================ THE PROGRESS LINE (Lon 2026-09-03 ~20:15) ============================
# ⛔⭐ THIS READS THE SEPTEMBER-10 GRID, WHICH IS THE **OTHER** TABLE IN SCORE.md. find_table() above binds
# the standardized display (6 columns); this binds the M/L/V/B grid (7 columns) that sits ABOVE it. Both
# headers read `| Language |`, which is exactly the collision that made find_table refuse fleet-wide, so
# this one proves its shape by COLUMN NAME too and refuses naming every candidate. Shape is the identity.
GRID_COLUMNS = {"M": (1, "M ·"), "L": (2, "L ·"), "V": (3, "V ·"), "B": (4, "B ·")}
GRID_NCOLS = 7
# Short names and print order, fixed by the brief.
PROGRESS_LANGS = [("snobol4", "sno"), ("snocone", "sc"), ("icon", "icn"), ("prolog", "pl"),
                  ("raku", "raku"), ("pascal", "pas"), ("rebus", "reb")]
# ⭐ A fraction whose LEFT CONTEXT carries one of these is not this cell's score: a floor/smoke gate, a
# secondary suite quoted for context, or a number the cell itself says it SUPERSEDES. Measured against
# every live cell, not guessed -- `smoke 724/724` (raku M), `smoke 4/4` (rebus M), `corpus suite 10/10`
# (snocone M), `the earlier 144/149` (pascal M). Kept as data so a reader can check the rule against the
# open file, which is the brief's "no hidden weights".
# ⛔ PROGRESS_DROP NAMES A DIFFERENT POPULATION (a smoke set, a corpus suite, the strict rung suite) -- its
# denominator leaves the cell entirely. Supersession words that used to live here ("was ", "the earlier",
# "readings", "supersedes") have MOVED to PROGRESS_SUPERSEDED below, because they name THE SAME population at
# an earlier time and dropping their denominator deleted the live number with them: `**596/596** ... was
# 595/596 before that cure` read as {} for 596, exactly the defect hq_C reported in its other wording.
PROGRESS_DROP = ("smoke", "corpus suite", "strict rung suite")
# ⛔⭐ A FRACTION LABELLED BY WHAT FOLLOWS IT COUNTS FAILURES, NOT PASSES. `924/986 PARSE-FAIL` is the raku
# roast task row's own idiom, and every reader of this parser called it a pass fraction: the agree gate
# convicted raku of a same-denominator conflict against the grid's `4/986` PASS, and both numbers were
# right all along (pass 4 + fail 9 + parse_fail 924 + no_tap 7 + crash 1 = 945, +41 missing = 986). ONE of
# the two tables is wrong is this gate's whole contract, so a false positive there is worse than a miss --
# it sends a reader to reconcile two correct cells. PROGRESS_DROP only ever looked at the 20 chars BEFORE a
# fraction; a label can sit on either side of the number it names.
# ⛔ THE `=` GUARD IS THE WHOLE DIFFICULTY, not an edge case: `ast 153/153, FAIL=0` is a PASS fraction
# followed by the word FAIL, and a naive suffix match drops icon's real number. Two things separate them --
# the marker must follow with NOTHING but whitespace between (a comma means it labels the clause, not the
# fraction), and `FAIL=`/`fail=` is a labelled count that is already read, never this fraction's name.
PROGRESS_FAIL_SUFFIX = ("parse-fail", "fail", "reject", "crash", "no-tap", "xfail", "red", "missing")
# ⛔⭐ A SUPERSEDED READING CITED FOR PROVENANCE IS NOT THIS CELL'S VALUE -- AND IT USED TO WIN (hq_C, s295,
# measured again by hq_T 2026-09-04 on the exact cell). Icon's grid cell read `**596/596 both modes** + ast
# 153/153 ... hq_C read **595/596** on the tree before that cure`, and cell_fractions returned {596: 595}: the
# fraction-grouping keeps MIN(pass) across a denominator, on purpose (the both-modes bar), so the SUPERSEDED
# number silently replaced the current one for every consumer -- the agree gate convicted, and the percentage
# would have published the old figure. ⛔ THE REPORTED SYMPTOM WAS A RED GATE; THE REAL DEFECT WAS A WRONG
# VALUE, which is the more dangerous half and was invisible because it looked like a conservative reading.
# ⭐ hq_C reported that UN-BOLDING the prose fraction fixed it. It did not -- reproduced both ways here, bold
# is not read by this parser at all. What actually changed was the wording: `was 595/596` carries the existing
# "was " marker, `hq_C read ... before that cure` carried none. A cure aimed at the reported mechanism would
# have documented "never bold a superseded fraction" and left the defect exactly where it was.
# ⛔ MARKERS ARE TESTED OVER THE WHOLE CLAUSE, ON BOTH SIDES OF THE NUMBER, not a 20-char lookbehind: this
# board's provenance idiom puts the tell AFTER the fraction ("... on the tree before that cure"), and a clause
# is what a reader sees as one statement. Clause bounds are the cell's own separators -- · — ; and the em dash
# the board already uses to fence provenance off from value -- so a supersession note cannot reach back into
# the measurement it is annotating.
PROGRESS_SUPERSEDED = ("before that", "superseded", "supersedes", "the earlier", "earlier reading", "previously",
                       "prior reading", "stale", "no longer", "used to read", "at the time", "was ", "readings")
# Suites with NO runner or NO number: 0 pass over their file count, so unmeasured coverage reads as
# MISSING rather than as ABSENT. Denominators are the brief's own. Applied only when the cell BOTH names
# the suite and carries a no-number marker, so a suite that later gets a real number stops being estimated.
# ⛔⭐ RETIRED JUSTIFICATION, CURED 2026-09-05 (hq_I) -- IT SURVIVED HERE AS SETTLED HISTORY. This comment
# read: "ipl IS COMPILE-GRADED AND IS DELIBERATELY ABSENT: it compiles 437 of 851 and RUN-grades zero,
# because upstream ships no `.std` oracle output ... counted nowhere". THREE retracted facts in one
# sentence, each still being told as the REASON the code is shaped this way:
#   (1) "deliberately absent / counted nowhere" was retired by Lon 2026-09-04 (EVERY SHIPPED PACKAGE IS A
#       TEST SUITE) -- stated in full TWENTY LINES BELOW THIS ONE, so the file contradicted itself, and ipl
#       has been in PROGRESS_COUNTED ever since;
#   (2) "437" is the pre-linkgap-cure compile figure (SCRIP `55fae9091` moved it to 544);
#   (3) "RUN-grades zero ... upstream ships no .std" stopped being true when util_cut_icon_ipl_refs.sh cut
#       60 oracle refs; the RUN tier exists and is the only oracle-diffed Icon vendor population we have.
# ⭐ A retracted claim is most durable where it is doing a JOB -- explaining why an instrument is built this
# way. Corrected prose gets read as a note and skipped; a justification gets read as the reason and trusted.
# The population 851 in PROGRESS_COUNTED below is CORRECT and was never part of that error -- see its note.
PROGRESS_ESTIMATED = {}   # superseded by counted_fractions: every listed package counts, ungraded ones as zero
# ⛔⭐⭐ ONLY A SHIPPED TEST SUITE COUNTS (Lon 2026-09-04, in-chat to ceo: "Ensure items in that list actually have test
# suites."): the V cell may name every vendored package, but the percent reads ONLY the clauses naming a package that
# ships its own tests or expected results -- csnobol4_suite (Budne's suite, 125 .ref verbatim), snoflake (180 @expect),
# arizona (Icon's tests/general, .std), jcon_tests (.std), swi_tests (SWI's src/Tests, plunit), INRIA (ISO 13211-1),
# fpc_tests (FPC's test programs), PAT (ISO 7185 validation suite, .cmp/.ecp), roast (Raku spec tests, TAP).
# NAMED, NEVER COUNTED: gimpel (a book's modules behind 144 drivers WE wrote), aisnobol and dotnet (program collections),
# ipl (a program library, no tests), gnu_prolog (GNU Prolog's compiler/library source, no tests).
PROGRESS_NO_PUBLIC_SUITE = ("snocone", "rebus")   # no shipped package at all: no percentage, never 100% from our own ladder
# ⛔⭐⭐⭐ READ THIS BEFORE THE PARAGRAPH BELOW IT -- THE ZERO-FOR-UNGRADED HALF IS SUPERSEDED (Lon 2026-09-05, in-chat,
# verbatim: "I want to see accurate numbers for each language as a measurement. I do not know what is a FLOOR, but
# whatever it is, it is not anything I want to see. Show measured numbers from running test suites not FLOORS. I have
# a floor I stand on, that is the only floor I need."). The paragraph below is Lon's 2026-09-04 ruling and its FIRST
# half still governs: every shipped package IS a test suite, and the inventory of what we owe is unchanged -- nothing
# is dropped from the list, nothing stops being owed. What is RETIRED is its SCORING consequence: an unrun package no
# longer contributes 0 of its population to the published percent. It is printed under NOT RUN, named and sized,
# outside every percent.
# ⭐ WHY THE RULING CHANGED, kept because the next reader will otherwise "restore" the zeros as a conservatism: the
# two rulings are not in conflict about the WORK, only about the NUMBER. Counting an unrun suite as zero made icon
# read 8% = 91/1066 with 851 of that denominator never run -- a measurement averaged with an assumption, in which the
# assumption dominated. That is not a conservative measurement, it is an unreadable one; the honest conservatism is
# to name what has not run, which the NOT RUN line does louder than a zero ever did.
# ⛔ DO NOT re-add an unrun package to P/T to make a percent "safe". If that ever looks right again, read the
# before/after in SCRIP 2b806e650 first, and test_gate_score_unreadable_package_is_marked.sh will red on it.
# ⛔⭐⭐ EVERY SHIPPED PACKAGE IS A TEST SUITE (Lon 2026-09-04, in-chat to ceo, verbatim: "If GNU Prolog ships with Prolog
# source; that is the test suite I am talking about. You make the programs run, you measure the output, make a REF
# file, and place it into a ONE-LINER or a MULTI-LINER Python test harness."). So every vendored package counts over
# its SHIPPED POPULATION: a package not yet run-graded counts as 0 of its population (it is on the list, it pulls the
# percent down until its programs run against the oracle), never as absent. The percent is the V column only; our own
# rungs, AST fixtures and ladders are printed as ours and never counted.
PROGRESS_COUNTED = {
    # ⛔ csnobol4's 119 ADDED (row score-v-clause-truncation-publishes-a-graded-package-as-ungraded,
    # hq_T 2026-09-05): the `--compat=csnobol4` dialect switch (ceo R1) moved setexit2 into scope,
    # total=119 in both the grid and the display twin since, superseding 118/124/125 -- kept, not
    # replaced, because older cell text still cites them for provenance and this list is "every
    # population this package has ever legitimately carried", never just the newest one.
    # ⛔ 120 ADDED (hq_S 2026-09-06, row flip-csnobol4-err): the runner's TOTAL moved 119 -> 120 when the
    # four module/* replacement-coverage rows landed (seat08 2026-09-05) and its own PACKAGE_INVENTORY now
    # prints graded=120. ⭐ THE SYMPTOM IS WHY THIS TUPLE MATTERS AND IT DOES NOT LOOK LIKE A LOOKUP MISS:
    # an unlisted population does not warn -- csnobol4 dropped into the banner's "NOT RUN ... these suites
    # exist and have never been run-graded" list, at its OLD size of 119, in the same minute a 120-program
    # board of it finished and wrote 4215 rows into the progress database. A suite reading as never-run
    # because it GREW is the failure mode to expect here, so add the new size in the landing that moves it.
    # ⛔⭐ THE SPITBOL RE-CUT MOVED EVERY SNOBOL4 DENOMINATOR ON 2026-09-08 AND THE NEW SIZES WERE NOT ADDED
    # HERE IN THE LANDINGS THAT MOVED THEM (coo, found on Lon's question "why does SNOBOL4 show 100%"). The
    # comment above says to expect exactly this, and it still happened. THE SYMPTOM WAS THE WORST KIND: under
    # Lon's one-oracle rule (CEO-391) csnobol4 went 120 -> 97 -> 93, snoflake 180 -> 126 and gimpel -> 127,
    # so FOUR of the five packages read UNREADABLE, dropped out of the percent entirely, and left dotnet 5/5
    # as the whole snobol4 population -- which published **sno 100%** for a language whose vendored packages
    # actually run about 310 of 396. A percent that RISES TO 100 because its biggest members became
    # unreadable is the false-clean shape this file exists to refuse, and it is louder than a zero.
    # ⭐ Old sizes are KEPT, never replaced: older cell text still cites them for provenance.
    "snobol4": [("csnobol4", r"csnobol4", (118, 124, 125, 119, 120, 97, 93)), ("snoflake", r"[Ss]noflake", (180, 126)), ("gimpel", r"gimpel", (126, 127, 144, 289)), ("aisnobol", r"aisnobol", (2, 7, 8)), ("dotnet", r"dotnet", (5, 14)), ("testpgms", r"spitbol_testpgms|testpgms", (2, 8))],
    # ⛔ ipl IS 851 AND A BARE `find -name '*.icn'` WILL TELL YOU 852 -- DO NOT "FIX" IT TO 852. The 852nd
    # file is ALL.icn, our OWN generated container, and hq_I corrected this number the wrong way on
    # 2026-09-05 on exactly that evidence. 851 = ALL.csv 78 graded entries + ALL.excluded.txt 773 named
    # exclusions; test_icon_ipl_suite.sh now excludes the container and REFUSES if that identity breaks.
    # ⭐ Only the SHIPPED population is declared, deliberately: ipl's graded set is 60 (the oracle-cut RUN
    # tier), and declaring it would let an honest `34/60` count as 57% of a VENDOR score whose true reading
    # is 34/851. Leaving 60 undeclared makes that cell UNREADABLE -- which counts ZERO and tells the writer
    # what to write instead -- so the only countable form is the POPULATION LAW form Lon ruled.
    # ⛔ arizona GRADED WAS 89 AND IS 90 (hq_T 2026-09-06, CEO-329 audit red). The runner divides by its
    # OWN graded count, so the moment seat12/hq_I cut one more ref the cell read `47/90`, matched NEITHER
    # declared population, and the reader scored the whole package ZERO -- a package going BACKWARDS on the
    # board for getting better. ⭐ THE HARDCODE IS THE DEFECT AND 90 IS ONLY TODAY'S VALUE: every ref cut
    # moves it again. The structural cure is to read the graded count from the runner's own
    # PACKAGE_INVENTORY line instead of declaring it here; recorded rather than done, because the audit is
    # red now and the reader must stop scoring a graded package as ungraded today.
    # ⛔⭐ ipl's PATTERN WAS THE ONLY CASE-SENSITIVE ONE OF THE FOUR AND THAT IS WHY IT SCORED ZERO (hq_I
    # 2026-09-06). Its neighbours spell themselves case-insensitively -- [Aa]rizona, [Jj][Cc][Oo][Nn],
    # [Ss]noflake -- while ipl matched lowercase only, so the ONE spelling every writer actually uses for a
    # package head, `IPL:`, was invisible to this reader. The V cell said `run m3 73/89` in plain sight and the
    # September-10 line published `ipl 71 programs, NOT YET RUN-GRADED`: not a wrong number, a suite reported as
    # never run while its board sat in the same sentence. ⭐ AND THE READING WAS THE STALE ONE TWICE OVER --
    # 71 came from a SUPERSEDED PACKAGE_INVENTORY clause left in machine form further down the cell, because
    # inventory_clauses keeps the LAST clause per package, so an archived clause does not sit beside the current
    # one, it REPLACES it. Both are cured; the general form is the one worth keeping: A READER WHOSE PATTERN IS
    # NARROWER THAN THE THING IT READS REPORTS ABSENCE, NEVER FAILURE, and absence is the one verdict that looks
    # like honest work.
    "icon": [("arizona", r"[Aa]rizona", (90, 124)), ("jcon", r"[Jj][Cc][Oo][Nn]", (81, 91)), ("ipl", r"\b[Ii][Pp][Ll]\b", (60, 851))],
    "prolog": [("swi", r"[Ss][Ww][Ii]", (114, 249)), ("INRIA", r"INRIA|inria|ISO 13211", (445,)), ("gnu", r"[Gg][Nn][Uu]", (62, 91)), ("logtalk", r"[Ll]ogtalk", (3617,))],
    "pascal": [("fpc", r"fpc", (181,)), ("PAT", r"\bPAT\b|validation suite|ISO 7185", (427, 429))],
    "raku": [("roast", r"roast", (986, 1464))],
}
class _Counted(dict):
    """A {denominator: pass} map that also REMEMBERS WHICH PACKAGES COULD NOT BE READ.
    ⛔⭐ WHY AN ATTRIBUTE AND NOT A THIRD RETURN VALUE: the caller's `got, work = counted_fractions(...)` shape is
    used by acceptance fixtures outside this file, and widening the tuple would break them into a ValueError --
    a cure that reds its own graders is indistinguishable from a defect. A dict subclass keeps every existing
    read (`got.get(851)`, `for t in sorted(got)`) exactly as it was and adds the one fact the caller was missing."""
    unreadable = ()
    found = ()      # (name, passes, population) -- a suite that actually RAN and was graded
    notrun = ()     # (name, population)         -- on the list, never run: inventory, never a zero in a percent


# ⛔⭐⭐ WHAT EACH PACKAGE SHIPS, so "graded" and "shipped" can never be read as one number (Lon 2026-09-05:
# "Show measured numbers from running test suites not FLOORS", applied one level DOWN, where the same collapse
# was hiding). MEASURED by hq_T running all three Icon suites on 2026-09-05: arizona grades 89 of 124 shipped,
# jcon 81 of 91, ipl 60 of 851. The published cells said `46/124` and `45/91` -- a real numerator over a
# population a third of which had never been run. Same defect as counting an unrun SUITE as zero, one level in:
# there it was a whole package, here it is the ungraded remainder inside a package that HAS run.
# ⭐ THE FIX IS THE SAME SHAPE: the percent counts what was graded; the ungraded remainder is booked as NOT RUN
# inventory and printed by name and size. Nothing is hidden and nothing is averaged with an assumption.
# ⛔⭐ ONLY MEASURED SHIPPED COUNTS GO IN THIS TABLE. Icon's three are here because hq_T RAN all three suites on
# 2026-09-05 and each runner PRINTS its own shipped/graded/gap on its board line (arizona shipped=124 graded=89
# gap=35; jcon shipped=91 graded=81 gap=10; ipl total=851 run_graded=60). The other languages are deliberately
# ABSENT: their shipped counts would be my transcription of someone else's cell, and an invented inventory number
# is the same defect as an invented score -- it would print "N programs never graded" with authority and no
# measurement behind it. ⭐ Each lane adds its own row here from ITS OWN runner's board line, never from prose.
# ⛔⭐⭐ THE CARRIAGE (CEO-316, off Lon 2026-09-06 09:31: "grade EVERY SINGLE package program from Icon and
# Prolog, and begin fixing them one at a time. What's the hold up?"). PACKAGE_SHIPPED below is a TRANSCRIBED
# population -- three integers typed into this file by a reader of somebody else's board, which is exactly
# what the row `package-shipped-per-lane-printed-by-the-runner-not-transcribed` exists to end. A transcribed
# denominator cannot go stale loudly: it goes stale silently, and every percent computed over it stays
# plausible. Measured on the live board while wiring this: the icon V cell says arizona has "35 never
# graded", and the runner's own inventory line says ungraded=0 ungradable=34. Neither number is 35. The cell
# was right when it was written and nothing told it when it stopped being.
#
# ⭐ SO THE CELL CARRIES THE RUNNER'S OWN LINE and this reader prefers it over anything typed here:
#   PACKAGE_INVENTORY package=<n> shipped=N graded=N ungraded=N ungradable=N [deferred=N] [graded_stream=N graded_narrow=N]
# ⛔ AND THE BUCKETS MUST SUM IN THE CELL TOO, not only inside lib_inventory.sh. A cell is edited by
# hand, so a clause can be pasted stale or half-updated; a sum that held at the runner and not in the cell is
# a transcription error wearing the instrument's clothes, which is the one disguise this whole row is about.
# ⛔ `deferred=` IS OPTIONAL IN THIS PATTERN AND NOT IN THE RUNNER (hq_T 2026-09-12, ceo CEO-593). Every
# runner prints the sixth term from today on, but a V cell is EDITED BY HAND and SCORE.md already carries
# clauses transcribed before the term existed. A required group would stop reading those cells entirely --
# and this reader's whole purpose is to prefer the runner's own line over anything typed, so failing to
# match is the one outcome that puts the typed number back in charge. Absent reads as 0, which is what
# every one of those historical clauses meant.
_INV_CLAUSE_RX = re.compile(
    r"PACKAGE_INVENTORY\s+package=(?P<pkg>[A-Za-z0-9_./-]+)\s+shipped=(?P<shipped>\d+)\s+graded=(?P<graded>\d+)"
    r"\s+ungraded=(?P<ungraded>\d+)\s+ungradable=(?P<ungradable>\d+)(?:\s+deferred=(?P<deferred>\d+))?")


def inventory_clauses(vcell):
    """{package: dict} for every PACKAGE_INVENTORY line a V cell carries, plus a list of complaints.
    A clause whose buckets do not sum is REPORTED AND DROPPED -- never silently used, never silently ignored."""
    out, bad = {}, []
    for m in _INV_CLAUSE_RX.finditer(vcell or ""):
        d = {k: int(m.group(k)) for k in ("shipped", "graded", "ungraded", "ungradable")}
        d["deferred"] = int(m.group("deferred") or 0)
        pkg = m.group("pkg")
        tot = d["graded"] + d["ungraded"] + d["ungradable"] + d["deferred"]
        if tot != d["shipped"]:
            bad.append("V %s INVENTORY CLAUSE DOES NOT SUM: graded(%d)+ungraded(%d)+ungradable(%d)+deferred(%d)=%d but shipped=%d. "
                       "Dropped, not used -- a clause that sums at the runner and not in the cell was transcribed, "
                       "and re-running the runner is the cure, never editing the digits."
                       % (pkg, d["graded"], d["ungraded"], d["ungradable"], d["deferred"], tot, d["shipped"]))
            continue
        # the runner that measured it, if the cell names one after the clause (`by=` or a backticked script)
        rest = vcell[m.end():m.end() + 200]
        mr = re.search(r"by=([A-Za-z0-9_./-]+)", rest) or re.search(r"`([a-z0-9_]*\.sh)`", rest)
        d["runner"] = mr.group(1) if mr else ""
        out[pkg] = d
    return out, bad


PACKAGE_SHIPPED = {
    # ⚠ FALLBACK ONLY, AND EVERY USE OF IT IS NAMED IN THE WORK LINES. A package whose V cell carries a
    # PACKAGE_INVENTORY clause never reaches this dict; one that does not is reported as still transcribed.
    "icon": {"arizona": 124, "jcon": 91, "ipl": 851},
}


def counted_fractions(lang, vcell):
    """{denominator: pass} over EVERY listed package: the first RUN-graded fraction over one of the package's own
    known populations within 160 chars after its name (denominator-anchored, so prose like "the grid's 126/124" can
    never be read as a suite); a package with no such fraction counts as 0 of its shipped population. Returns
    (got, work)."""
    # ⛔⭐ THE WINDOW IS THE PACKAGE'S OWN CLAUSE, NOT 160 CHARACTERS (hq_B 18:59, third instance of one shape
    # today; ceo row score-readers-anchor-on-a-labelled-form-and-say-why-they-found-nothing). A V cell is written
    # in `·`-separated clauses, and a writer is ENTITLED to lead with explanation -- the leaderboard doctrine asks
    # for provenance in the cell. A fixed 160-char window turns that entitlement into a wrong number: the snoflake
    # cell said 103/180 and the grid published `0/180 NOT YET RUN-GRADED`. Measured on the live board while
    # writing this: ALL FIVE snobol4 packages read 0 and "not yet run-graded", every one of which HAS been run.
    # ⛔⛔ AND "I FOUND NO FRACTION" IS NOT "IT SCORED ZERO". Those were one output, and that is the same
    # could-not-measure-vs-measured-red collapse this project refuses everywhere else (lib_gate.sh's three exit
    # codes; the harness's rc=2). They are now three distinct outcomes, and only the first contributes a number:
    #   FOUND            a fraction over one of the package's KNOWN populations -> counted
    #   UNREADABLE       digits are there but not in a countable form (a denominator nobody declared, or
    #                    `PASS=82 FAIL=91` rather than a fraction) -> NOT counted, NOT called zero, and the cell's
    #                    own text is quoted back so the writer can see what the reader saw
    #   ABSENT           the package's clause carries no digits at all -> genuinely not run-graded, counts as 0
    # ⭐ A reader that says WHY it found nothing turns a silent wrong number into a fixable message.
    got, work, unread = _Counted(), [], []
    _found, _notrun = [], []
    inv, inv_bad = inventory_clauses(vcell)
    work.extend(inv_bad)
    _transcribed = []
    # ⛔⭐⭐ THE MATCHED JOIN, RECORDED ONCE AND REUSED — because the 2026-09-06 cure below was applied to ONE
    # OF THE THREE PLACES THIS FUNCTION JOINS A TABLE LABEL TO A RUNNER'S `package=` TOKEN, and the other two
    # kept the spelled `name in inv` that the cure exists to replace (hq_T 2026-09-10). Measured on the live
    # board: pascal's runner emits `PACKAGE_INVENTORY package=pat`, the clause sits in the very cell being
    # read, and this reader printed "⚠ PAT carries NO PACKAGE_INVENTORY clause ... Retrofit the runner to
    # lib_inventory.sh and paste its own line into the cell" — a work item for work already done, against the
    # only instrument that could have reported it. The same three pairs miss as in 2026-09-06: pat/PAT,
    # gnu_prolog/gnu, snoflake_suite/snoflake. ⛔ AND THE SECOND MISS IS THE WORSE ONE: `_ship` fell through to
    # the PACKAGE_SHIPPED dict, which holds no pascal/prolog/snobol4 entry, so `_ship` was 0, `_ship > graded`
    # was false, and THE UNGRADED REMAINDER WAS NEVER BOOKED AS NOT-RUN — the never-graded business hidden by
    # a spelling, in the function written to stop exactly that. ⭐ THE REUSABLE HALF: a cure that replaces a
    # JOIN has to be applied wherever the join is performed, and grep finds those sites by the OLD spelling —
    # which is the string the author has just stopped thinking about. The fix is not vigilance: it is to
    # compute the join ONCE, name it, and leave no second way to spell it.
    _matched = {}
    for name, rx, dens in PROGRESS_COUNTED.get(lang, []):
        # ⭐ THE RUNNER'S OWN POPULATIONS BECOME LEGAL DENOMINATORS WITHOUT A CODE EDIT. Today a lane that
        # re-censuses a package must also edit PROGRESS_COUNTED here or its honest fraction reads UNREADABLE
        # -- a reader that only accepts numbers it was told about in advance cannot follow a live census.
        # ⛔⭐ AND THE JOIN WAS `name in inv`, WHICH NEVER FIRED FOR THREE OF EIGHT PACKAGES (hq_T 2026-09-06,
        # on the coo's report). `inv` is keyed by the RUNNER's own `package=` token and `name` is this table's
        # label, and they are not the same string: `gnu_prolog`/`gnu`, `snoflake_suite`/`snoflake`, `pat`/`PAT`.
        # So the one mechanism built to stop a package scoring ZERO FOR GETTING BETTER was inert on exactly the
        # packages that had moved -- gnu's live 11/11 and swi's 8/118 both read UNREADABLE and counted zero,
        # while the hardcoded (62, 91) and (114, 249) sat here looking maintained. ⭐ THE FAILURE IS SILENT BY
        # CONSTRUCTION: a lookup that misses reports ABSENCE, and absence is the one verdict that looks like
        # honest work -- the same sentence this table already carries about ipl's case-sensitive pattern, which
        # is the THIRD instance of this shape and the reason the join is now matched, not spelled.
        # ⭐ MATCHED BY THE ENTRY'S OWN REGEX, so there is no second naming list to keep in step with this one.
        # IGNORECASE is applied to INVENTORY KEYS ONLY -- never to the cell text, where a case-insensitive
        # `\bPAT\b` would start matching English prose. An inventory key is a runner-emitted token, not prose.
        # ⛔ AMBIGUITY IS REPORTED, NEVER GUESSED: two keys matching one entry means the names have collided and
        # a silently-chosen population is exactly the invented denominator this reader refuses everywhere else.
        _hits = [k for k in inv if re.search(rx, k, re.I)] if inv else []
        if len(_hits) > 1:
            work.append("V %s: %d inventory clauses match this package's pattern (%s) -- POPULATION NOT WIDENED, "
                        "because choosing one would invent a denominator. Give the colliding packages distinct "
                        "`package=` names in their runners." % (name, len(_hits), ", ".join(sorted(_hits))))
        elif _hits:
            _k = _hits[0]
            _matched[name] = _k
            dens = tuple(dict.fromkeys(tuple(dens) + (inv[_k]["shipped"], inv[_k]["graded"])))
        best, saw = None, ""
        for m in re.finditer(rx, vcell):
            # clause = from this package's name to the next clause separator or the next package name, whichever
            # comes first -- so a long, honest explanation stays INSIDE the clause it belongs to, and a neighbour's
            # number can never be borrowed across a `·`.
            rest = vcell[m.end():]
            ends = [x for x in (rest.find(" · "), rest.find(" — "), rest.find("; ")) if x != -1]
            seg = rest[:min(ends)] if ends else rest
            if re.search(r"compile[- ]graded|COMPILE-graded|compile-only", seg[:60]):
                continue
            for f in re.finditer(r"(\d+)\s*/\s*(\d+)", seg):
                pnum, den = int(f.group(1)), int(f.group(2))
                if den in dens and pnum <= den:
                    best = (pnum, den)
                    break
                if not saw:
                    saw = "%d/%d" % (pnum, den)
            if best:
                break
            if not saw:
                mp = re.search(r"PASS\s*=\s*(\d+)", seg, re.I)
                if mp:
                    saw = "PASS=%s (a count, not a fraction)" % mp.group(1)
        if best is None:
            if saw:
                unread.append(name)
                # ⛔ AN UNREADABLE PACKAGE STAYS IN THE DENOMINATOR AND CONTRIBUTES ZERO PASSES. Dropping it from
                # BOTH sides was this cure's own first draft, and it was backwards: it RAISED every affected
                # language's percent (icon 8% -> 48% in one edit) purely because a cell had become unreadable,
                # while the work line called the result a "FLOOR". A floor is the CONSERVATIVE reading, and
                # excluding the unknown is the optimistic one. ⭐ The rule that keeps the two honest: an
                # unreadable cell must never be able to improve a score. It is a zero with a message, not an
                # abstention -- the message is for the writer, the zero is for the reader.
                got[dens[-1]] = got.get(dens[-1], 0)
                # ⛔⭐⭐ IT STAYS BOOKED AS INVENTORY HERE, AND THE FALSE CLAIM IS CURED AT THE BANNER. It was, until 2026-09-11 (hq_I measured the
                # symptom): ipl printed `IPL 108/108 Δ0 ✅ done` in the banner's grid and `ipl 108 programs`
                # under "these suites exist and have never been run-graded" in the same banner, and the equal
                # 108 is the tell -- one number, booked twice, in opposite senses. `notrun` is defined three
                # hundred lines up as "on the list, NEVER RUN", and ipl had run: its cell merely states
                # PASS=816, a count rather than a fraction, so this reader cannot parse it.
                # ⭐⭐ THE GENERAL FORM, and it is the third instance in one sitting: AN INSTRUMENT THAT
                # CANNOT READ SOMETHING MUST SAY "I CANNOT READ IT", NEVER "IT IS NOT THERE". The port-trace
                # gates counted an unpinned witness (NOREF) as a failed check; the package cause reader
                # promised a pass would write a cell whose buckets can never sum; this booked a cell it could
                # not parse as a suite nobody ran. Each collapses an "I don't know" into a definite negative,
                # and each reads as diligence -- the definite negative is always the more actionable-looking
                # of the two.
                # ⛔ MY FIRST CURE DELETED THE `_notrun` BOOKING AND test_gate_score_unreadable_package_is
                # _marked.sh RED, CORRECTLY. That gate pins the package as INVENTORY precisely so it can never
                # drift back into the measured percent, and the membership is the mechanism. ⭐ THE DATA
                # CHANNEL WAS NOT THE LIE -- THE HEADING WAS: `notrun` here means "outside the measured
                # percent", and the banner rendered it as "have never been run-graded", which is a strictly
                # stronger claim than the bucket carries. Fixing the producer to satisfy a reader's wording is
                # backwards, and it cost a gate red to find out.
                _notrun.append((name, dens[-1]))
                work.append("V %s UNREADABLE, counted 0/%d -- the cell carries %s, which is not a fraction over any "
                            "declared population %s. Counted ZERO (an unreadable cell must never raise a score), and "
                            "named here so it can be fixed: write it as `<pass>/<total>` over a declared population, "
                            "or declare the population." % (name, dens[-1], saw, sorted(dens)))
            else:
                got[dens[-1]] = got.get(dens[-1], 0)
                _notrun.append((name, dens[-1]))
                work.append("V %s 0/%d -- on the list, NOT YET RUN-GRADED (no number in its clause at all; counts "
                            "as zero until its programs run against the oracle)" % (name, dens[-1]))
            continue
        got[best[1]] = best[0]
        _found.append((name, best[0], best[1]))
        work.append("V %s %d/%d" % (name, best[0], best[1]))
        # ⛔ THE UNGRADED REMAINDER OF A PACKAGE THAT DID RUN IS STILL NOT-RUN. arizona grades 89 of 124; the
        # other 35 have no oracle-cut ref and have never been executed against one. They are inventory, exactly
        # like a package nobody ran at all -- counting them inside the fraction is what made `46/124` read as a
        # measurement of 124 programs when it measured 89.
        if name in _matched:
            _ship = inv[_matched[name]]["shipped"]
        else:
            _ship = PACKAGE_SHIPPED.get(lang, {}).get(name, 0)
            if _ship:
                _transcribed.append(name)
        if _ship > best[1]:
            _notrun.append(("%s (ungraded remainder)" % name, _ship - best[1]))
    # ⛔ THE REPORT THE ORDER ASKED FOR: a lane whose V cell does not carry its runner's own inventory line is
    # NAMED, every run. It is not an error -- the runner may simply not be retrofitted yet -- but an unnamed
    # gap is indistinguishable from a closed one, and that is the whole "never graded business".
    _missing_inv = [n for n, _rx, _d in PROGRESS_COUNTED.get(lang, []) if n not in _matched]
    if _missing_inv:
        # ⛔⭐⭐ AND THE CURE LINE MUST STOP ENUMERATING CAUSES AND SEND THE READER TO MEASURE ONE. Its history
        # is the whole argument: it named ONE cause ("the runner is not retrofitted") and was wrong for BOTH
        # packages it reported on 2026-09-10 -- arizona and ipl were wired, and their bodies had REFUSED. It
        # was cured to name TWO. On 2026-09-11 both named causes were wrong again, for FOUR of the seven it
        # reports: snobol4's gimpel/aisnobol/dotnet/testpgms are wired AND their sidecars validate (ARM 20
        # pins all four), and their cells are prose only because no suite pass has rewritten them since the
        # carriage landed -- which under ONE RUNNER ONE BOARD (CEO-523) only the coo can do. A fourth cause
        # sits beside them: raku/roast has no vendored package corpus at all, so there is no runner to wire.
        # ⭐⭐ THE GENERAL FORM: A DIAGNOSTIC THAT CAN ONLY OBSERVE AN ABSENCE MUST ENUMERATE EVERY CAUSE OF
        # THE ABSENCE, AND ENUMERATING FROM MEMORY IS HOW YOU GET TWO OF FOUR. Each list was written by
        # someone who had just measured the cause in front of them and then generalised, and each read as
        # more rigorous than the last while staying wrong. The cure is not a longer list: it is to stop
        # enumerating HERE -- this function is called by every runner and may read only its cell -- and hand
        # the reader an instrument that LOOKS. ⛔ A wrong cause is a WORK LIST, not a wording: this row's own
        # baton told its next reader to do "the CARRIAGE half" on four runners that were already correct.
        work.append("⚠ %d package(s) carry NO PACKAGE_INVENTORY clause (%s) -- their shipped population is still "
                    "TRANSCRIBED, so it cannot go stale loudly. ⛔ THIS READER SEES ONLY THE CELL AND THEREFORE "
                    "CANNOT NAME THE CAUSE -- it has at least four (no vendored package corpus at all; the "
                    "runner is not retrofitted; it IS wired and inventory_line REFUSED, which emits nothing "
                    "while the runner stays green; or it is wired AND validates and simply has not been RUN "
                    "since the carriage landed). ⭐ DO NOT GUESS FROM THIS LINE: run "
                    "`bash ../harness/scripts/util_package_inventory_cause.sh <lang> <label> <regex>`, or "
                    "`util_package_shipped_is_runner_written.sh`, which calls it per package and prints the "
                    "MEASURED cause -- only one of the four is carriage work."
                    % (len(_missing_inv), ", ".join(_missing_inv)))
    if _transcribed:
        work.append("⚠ %d package(s) took the shipped population from PACKAGE_SHIPPED (%s), a number typed into "
                    "util_score_row.py rather than measured by the runner that grades it."
                    % (len(_transcribed), ", ".join(_transcribed)))
    _no_runner = sorted(n for n, d in inv.items() if not d["runner"])
    if _no_runner:
        work.append("⚠ %d inventory clause(s) name no runner (%s) -- a number with no instrument beside it cannot "
                    "be re-measured by the next reader." % (len(_no_runner), ", ".join(_no_runner)))
    if unread:
        work.append("⚠ %d package(s) UNREADABLE (%s) -- each counted ZERO over its declared population, so this "
                    "language's percent is a genuine FLOOR: fixing the cell can only raise it." % (len(unread), ", ".join(unread)))
    # ⛔⭐⭐ THE FLOOR MUST REACH THE PUBLISHED LINE, NOT ONLY THE WORKINGS (row score-a-vendor-cell-reporting-counts-
    # not-fractions-publishes-a-reading-failure-as-a-measured-zero, minted by hq_I 2026-09-05 off their ipl fold).
    # Everything above was already correct and already loud: the UNREADABLE line names the package and quotes the
    # cell back. The gap was one level up -- `got` is a dict and never None, so the caller's `if got is None`
    # raised the language-level flag ONLY when the WHOLE cell failed to parse. A per-package reading failure
    # therefore flowed into P/T as an ordinary zero and the percent published with NO marking: icon's ipl read
    # 0/851 while its suite had run-graded 34/60, and had done for as long as that cell reported counts.
    # ⭐ A READING FAILURE PRESENTED AS A MEASUREMENT is the same collapse this project refuses everywhere else
    # (lib_gate.sh's three exit codes; rc=2 versus FAIL; "I found no fraction" is not "it scored zero"). The zero
    # STAYS -- an unreadable cell must never raise a score, measured: dropping it moved icon 8% -> 48% in one edit
    # -- but the number it produces is a FLOOR, and a floor published as a measurement is the defect.
    got.unreadable = tuple(unread)
    got.found = tuple(_found)
    got.notrun = tuple(_notrun)
    return got, work


# ⛔⭐⭐ THE CLAUSE WINDOW THAT MAKES counted_fractions HONEST IS THE SAME WINDOW THAT CAN HIDE A REAL
# NUMBER FROM IT (row score-v-clause-truncation-publishes-a-graded-package-as-ungraded, hq_T
# 2026-09-05, measured live folding a fresh INRIA reading into this exact cell: an em-dash between the
# explanation and the number ended the clause before its fraction, and prolog published twelve percent
# for eight minutes instead of sixty-nine). The window is correct -- a fixed-width scan was the older,
# worse bug it replaced (see counted_fractions' own header) -- but "correct" and "cannot be defeated by
# how a human writes a sentence" are different properties, and the leaderboard doctrine (name your
# provenance) actively encourages the sentence shape that defeats it. This is the INSTRUMENT that
# catches the gap between them: it does not change how the percent is read, it checks whether a
# package reading zero is a genuine zero (NOTRUN/UNREADABLE, stays quiet under Lon's 2026-09-05
# measured-only basis) or a zero the reader was blindsided into (a fraction sits findable elsewhere).
def _wide_window(rx, text, boundary_rx):
    # Every occurrence of `rx` in `text` (case-INSENSITIVE -- this search is evidence-gathering, never
    # the score itself, so it is deliberately more permissive than counted_fractions' own case-exact
    # match), paired with everything from just after the match to the next occurrence of
    # `boundary_rx` (a NEIGHBOUR PACKAGE's own name pattern) or end of string. Bounded by a neighbour's
    # name, never by a separator: a separator is exactly what the narrow reader already stops at, and
    # the defect this hunts is a real fraction sitting past one.
    out = []
    for m in re.finditer(rx, text, re.I):
        rest = text[m.end():]
        bm = re.search(boundary_rx, rest, re.I) if boundary_rx else None
        out.append(rest[:bm.start()] if bm else rest)
    return out


def _fractions_in(seg):
    # Every (pass, total) in seg with pass<=total, in appearance order -- NO denominator filter here.
    # Whether the denominator is currently DECLARED is exactly one of the two things the caller must
    # decide (the other being which source it came from), so filtering it out here would throw away
    # the csnobol4 shape of this defect (a real, current, both-tables-agreed total that PROGRESS_COUNTED
    # simply had not caught up to yet) before the caller ever saw it.
    found = []
    for f in re.finditer(r"(\d+)\s*/\s*(\d+)", seg):
        pnum, den = int(f.group(1)), int(f.group(2))
        if pnum <= den:
            found.append((pnum, den))
    return found


def _narrow_clause(rx, text):
    # Mirrors counted_fractions' OWN first-match clause window, byte for byte (same case-exact `rx`,
    # same three separators), for ONE purpose only: quoting back the literal text the real reader
    # saw. A second copy of the boundary rule would be a maintenance hazard if this computed the
    # SCORE; it does not -- it is read-only evidence for a human, never fed back into `got`/`work`.
    m = re.search(rx, text)
    if not m:
        return None
    rest = text[m.end():]
    ends = [x for x in (rest.find(" · "), rest.find(" — "), rest.find("; ")) if x != -1]
    return rest[:min(ends)] if ends else rest


def clause_fraction_audit(lang, grid_vcell, disp_vcell):
    """For every package PROGRESS_COUNTED lists for `lang`, decide whether counted_fractions' zero (if
    any) is a package genuinely NOTRUN/UNREADABLE, or a package whose real fraction the narrow clause
    window could not reach. Returns a list of conviction dicts, most-evidence-first; an empty list
    means every zero this language's V cell currently reads is honest -- checked, not merely absent
    from this report. See test_gate_score_v_clause_carries_its_fraction.sh for the gate this feeds and
    the task that asked for it (score-v-clause-truncation-publishes-a-graded-package-as-ungraded).

    ⛔ "current"/"cured" percentages mirror language_progress' OWN basis (Lon 2026-09-05, "show
    measured numbers ... not FLOORS"): T/P sum ONLY `got.found` -- a package this function is about
    to convict is NOTRUN or UNREADABLE by definition (that is what makes it convictable), so it
    contributes NOTHING to the current denominator; curing it ADDS its own (pass, population), it
    never replaces a placeholder zero the way the pre-2026-09-05 basis would have required."""
    pkgs = PROGRESS_COUNTED.get(lang, [])
    got, work = counted_fractions(lang, grid_vcell)
    base_T = sum(pop for _n, _p, pop in got.found)
    base_P = sum(p for _n, p, _pop in got.found)
    cur_pct = (100 * base_P) // base_T if base_T else 0
    convictions = []
    for name, rx, dens in pkgs:
        line = next((w for w in work if w.startswith("V %s " % name)), None)
        if line is None or " -- " not in line:
            continue          # FOUND (counted_fractions' own "V name p/t" line, no " -- " tail) -- clean
        # The one guard rail on an otherwise-unbounded search: never let it bleed into a NEIGHBOUR
        # package's own fraction. Empty for a single-package language (raku), which is fine --
        # _wide_window treats an empty boundary as "to end of string", same as counted_fractions' own
        # "no separator found" case.
        boundary = "|".join("(?:%s)" % o_rx for o_name, o_rx, _o_dens in pkgs if o_name != name)
        sources = [("grid", _wide_window(rx, grid_vcell, boundary))]
        if disp_vcell:
            sources.append(("display twin", _wide_window(rx, disp_vcell, boundary)))
        best = None   # (pnum, den, declared, source, seg)
        for source, segs in sources:
            for seg in segs:
                for pnum, den in _fractions_in(seg):
                    declared = den in dens
                    if best is None or (declared and not best[2]):
                        best = (pnum, den, declared, source, seg)
        if best is None:
            continue          # nothing countable anywhere this audit looked -- the zero is genuine
        pnum, den, declared, source, seg = best
        cured_T = base_T + den
        cured_P = base_P + pnum
        convictions.append({
            "lang": lang, "package": name,
            "raw_clause": _narrow_clause(rx, grid_vcell),
            "work_line": line,
            "found_pnum": pnum, "found_den": den, "den_declared": declared,
            "source": source, "found_snippet": _clause_snip(seg, 100),
            "cur_pct": cur_pct,
            "cured_pct": (100 * cured_P) // cured_T if cured_T else 0,
        })
    return convictions


def cmd_clausecheck(a):
    lines = open(SCORE_MD, encoding="utf-8").read().split("\n")
    _gh, grid, gskip = find_grid(lines)
    _dh, disp, _dskip = find_table(lines)
    # ⛔ FAIL CLOSED ON THE PRIMARY SOURCE, exactly like cmd_progress: a language this audit cannot
    # read is a language it did not check, and printing CLEAN over a partial grid is the vacuous-gate
    # class cmd_agree's own header already names. The display table is the SECONDARY (twin) source --
    # missing it narrows one language's search to grid-only rather than voiding the whole run, because
    # the grid is still genuinely readable and worth auditing on its own.
    audited_langs = [l for l, _s in PROGRESS_LANGS if l in PROGRESS_COUNTED]
    unreadable = [l for l in audited_langs if l not in grid]
    if unreadable:
        die("the September-10 grid has no readable row for %s -- refusing a partial clause-check "
            "(malformed rows: %s)" % (", ".join(unreadable), ", ".join("%s(line %d, %d cols)" % (l, gskip[l][0] + 1, gskip[l][1]) for l in unreadable if l in gskip)))
    checked = sum(len(PROGRESS_COUNTED[l]) for l in audited_langs)
    convictions = []
    no_display = []
    for lang in audited_langs:
        grid_vcell = grid[lang][GRID_COLUMNS["V"][0]]
        if lang in disp:
            disp_vcell = disp[lang][1][COLUMNS["vendor"][0]]
        else:
            disp_vcell = ""
            no_display.append(lang)
        convictions.extend(clause_fraction_audit(lang, grid_vcell, disp_vcell))
    if no_display:
        print("⚠ no standardized-display row for %s -- audited grid-only, its display twin unchecked" % ", ".join(no_display))
    if not convictions:
        print("CLAUSE-CHECK CLEAN: %d package(s) checked across %d language(s) in PROGRESS_COUNTED -- "
              "every package reading zero in the September-10 grid was searched (grid, wide window; "
              "display twin, wide window) and found genuinely nowhere-graded." % (checked, len(audited_langs)))
        return 0
    print("CLAUSE-CHECK CONVICTED %d of %d package(s) checked across %d language(s):" % (len(convictions), checked, len(audited_langs)))
    for c in convictions:
        print("  ⛔ %s / %s: scored ZERO -- %s" % (c["lang"], c["package"], c["work_line"]))
        print("      the clause the reader saw: %r" % (c["raw_clause"],))
        pop_note = "" if c["den_declared"] else ("  [population %d is NOT currently declared for %s in PROGRESS_COUNTED -- verify before trusting it]" % (c["found_den"], c["package"]))
        print("      a %d/%d fraction exists in the %s: %s%s" % (c["found_pnum"], c["found_den"], c["source"], c["found_snippet"], pop_note))
        print("      once this cell's clause carries that fraction, %s would read %d%% (currently %d%%)" % (c["lang"], c["cured_pct"], c["cur_pct"]))
    return 1


def find_grid(lines):
    # Same candidate-and-prove discipline as find_table, against the September-10 grid's own column names.
    candidates = [i for i, l in enumerate(lines) if l.startswith("| Language |")]
    if not candidates:
        die("no '| Language |' header in %s -- the September-10 grid is gone or renamed" % SCORE_MD)
    why = []
    for i in candidates:
        cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
        if len(cells) != GRID_NCOLS:
            why.append("line %d has %d columns, the grid has %d" % (i + 1, len(cells), GRID_NCOLS))
            continue
        bad = [k for k, (idx, pre) in GRID_COLUMNS.items() if not cells[idx].startswith(pre)]
        if bad:
            why.append("line %d column(s) %s do not start with their %s prefix" % (i + 1, ",".join(sorted(bad)), "M·/L·/V·/B·"))
            continue
        rows = {}
        skipped = {}
        for j in range(i + 2, len(lines)):
            if not lines[j].startswith("|"):
                break
            c = [x.strip() for x in lines[j].strip().strip("|").split("|")]
            if len(c) == GRID_NCOLS:
                rows[c[0]] = c
            elif c and c[0]:
                # ⛔⭐⭐ THE TWIN OF THE SAME DEFECT, AND IT SURVIVED THE CURE OF ITS SIBLING BY ONE DAY.
                # find_table's row loop got its `else` on 2026-09-04 (cc054250f) after one stray `|` deleted
                # snobol4 from every reader of the DISPLAY table. This loop -- same file, same shape, same
                # consequence -- was left with no `else`, so a malformed row in the SEPTEMBER-10 GRID still
                # vanished in silence. Measured (hq_T 2026-09-05, reproducing hq_B's incident): pasting a
                # minimized Icon witness carrying `||` into the icon grid row widened it 7 cells to 9, the row
                # dropped out of `rows`, and `agree` went from GATE RED on a real same-denominator conflict to
                # GATE PASS(0) over 10 pairs holding none of icon's. Nothing was fixed; the gate stopped
                # looking, and it said PASS in the same breath.
                # ⭐ THE RULE THIS PAYS FOR (hq_B, 2026-09-05, into GOAL-TEST-SUITE-CONSISTENCY.md): A GREEN
                # THAT APPEARS WHILE YOU ARE EDITING THE DATA IS A SUSPECT, NOT A REWARD. And the fix-the-twin
                # lesson beside it: a defect cured in one reader of a file is owed to every reader of that
                # file in the same sitting -- the cure that stops at the function it was reported on leaves
                # the identical hole one screen away, wearing a different table's name.
                skipped[c[0]] = (j, len(c))
                sys.stderr.write("⚠ SCORE.md line %d: September-10 grid row %r has %d columns, the grid has %d -- "
                                 "SKIPPED, so every reading below OMITS it. It is malformed, not absent.\n"
                                 % (j + 1, c[0], len(c), GRID_NCOLS))
        return i, rows, skipped
    die("no '| Language |' table in %s is the September-10 grid. Candidates: %s" % (SCORE_MD, "; ".join(why)))


def _clause_snip(txt, n=72):
    # ⛔⭐ A DROP DIAGNOSTIC THAT NAMES THE MARKER BUT NOT THE CLAUSE CANNOT BE ACTED ON (hq_I -> hq_T,
    # 2026-09-05, measured twice in ten minutes while authoring the icon grid cell). cell_fractions bounds a
    # clause at the nearest middot / em-dash / semicolon, so a sentence like "RETIRES THREE STALE READINGS"
    # written NEXT TO a live fraction lands in the SAME clause, the marker word STALE drops that fraction,
    # and the gate then reports the OPPOSITE defect -- a one-sided population -- on a cell that plainly
    # contains it. The author's only route to the real cause was to guess. The clause is already computed;
    # it was simply never printed. ⭐ This is the general form of a diagnostic bug: naming the RULE that
    # fired without the INPUT it fired on tells the reader what the tool believes and not why.
    t = " ".join(str(txt).split())
    return (t[:n] + "…") if len(t) > n else t
def _drop_note(workings, t):
    # The `drop <pass>/<total> (...)` working for denominator t, if this cell dropped one. Lets a caller that
    # sees a one-sided population say WHY the other cell has no such population instead of only that it has none.
    pre = "/%d " % t
    for w in workings or []:
        if w.startswith("drop ") and pre in w.split("(")[0]:
            return w
    return None
def cell_fractions(raw):
    # Return ({denominator: (pass, ...)}, workings), or (None, workings) when the cell carries a population
    # this parser cannot read -- see the fail-closed contract in language_progress.
    # ⛔⭐ THE VALUE IS A TUPLE OF EVERY SURVIVING FRACTION OVER THAT DENOMINATOR, IN CELL ORDER, AND NOTHING
    # IS EVER SILENTLY DISCARDED. Use cell_bar() for the worse-mode number a verdict reads, and
    # cell_ambiguous() to ask whether the cell can be read to ONE number at all. See the ruling at the tail
    # of this function for why the collapse had to be removed from the parser rather than from its readers.
    # ⛔⭐ THE HARNESS SHAPE IS READ FIRST, AND BEFORE PARENTHESES ARE STRIPPED. Measured (ceo, on seat12's
    # snocone cell): `ast 67/67 · run(206) m3 176 pass/7 fail` printed `sc 100%`, because the run population's
    # TOTAL lives inside `run(206)` that the provenance strip deleted and its PASS is prose, not a fraction.
    s = re.sub(r"`[^`]*`", "", raw)
    groups, dropped, work, logged, consumed = {}, set(), [], set(), []
    m = re.search(r"\brun\((\d+)\)", s)
    if m:
        total = int(m.group(1))
        passes = [int(x) for x in re.findall(r"\bm[34]\s+(\d+)\s+pass\b", s)]
        if not passes:
            work.append("run(%d) present but no 'mN <n> pass' to pair with it -- UNREADABLE" % total)
            return None, work
        groups.setdefault(total, []).append(min(passes))
        logged.add(total)
        work.append("run %d/%d (from %s, worse mode)" % (min(passes), total, ",".join(str(x) for x in passes)))
        s = s[:m.start()] + " " + s[m.end():]
        s = re.sub(r"\bm[34]\s+\d+\s+pass(?:\s*/\s*\d+\s+\w+)*", " ", s)
    s = re.sub(r"\([^()]*\)", "", s)
    # ⭐ GROUP BY DENOMINATOR, KEEP MIN(PASS): collapses an m3/m4 twin into ONE population (the grid's own
    # "PER MODE, never summed") and, where the modes disagree, keeps the WORSE -- the both-modes bar.
    # ⛔ A drop marker drops the whole DENOMINATOR, not the one fraction (measured on snocone, whose
    # `corpus suite 10/10 · 10/10` carries the marker before the FIRST twin only).
    # ⛔⭐⭐ EVERYTHING AFTER A SUPERSEDE MARKER IS ARCHIVE, BY CONSTRUCTION -- so no fraction there can be
    # this cell's value, whatever clause it sits in. The fold writes `<live text> <MARKER> <archive>` and
    # every hand-edit in SCORE.md uses the same rhetorical shape, so the marker is a HARD BOUNDARY and not
    # a hint. This is the second half of CEO-475's cure and it guards the half the writer cannot: the coo
    # hand-spells folded readings today, and the next person to hand-fold one will paste digits.
    # ⛔ The clause-scoped PROGRESS_SUPERSEDED drop below is NOT redundant with this and must stay: it
    # catches a superseded number cited INLINE, ahead of any marker ("hq_C read 595/596 before that cure"),
    # which this boundary never sees. Two different shapes of the same mistake, two different guards.
    # ⭐ Matched on the PREFIX, deliberately: the marker's parenthetical is deleted by the paren strip a few
    # lines up, so the full constant does not survive into `s` and matching it would silently never fire --
    # an instrument answering a narrower question than its author thinks, in the guard against exactly that.
    _sup_at = s.find("SUPERSEDES the reading below")
    for m in FRACTION_RE.finditer(s):
        if _sup_at != -1 and m.start() > _sup_at:
            work.append("drop %s/%s (folded-forward archive: it sits after the supersede marker, so it is a "
                        "reading this cell REPLACES, never its value)" % (m.group(1), m.group(2)))
            consumed.append((m.start(), m.end()))
            continue
        t, ps = int(m.group(2)), int(m.group(1))
        ctx = s[max(0, m.start() - 20):m.start()].lower()
        _cl_start = max([s.rfind(ch, 0, m.start()) for ch in ("\u00b7", "\u2014", ";")] + [-1]) + 1
        _cl_end = min([x for x in (s.find(ch, m.end()) for ch in ("\u00b7", "\u2014", ";")) if x != -1] + [len(s)])
        # ⛔⭐ A CLAUSE MAY NOT SPAN THE SUPERSEDE MARKER. The marker is a hard boundary (see above), so a
        # LIVE fraction in the last clause before it must not inherit the word "supersedes" from the marker
        # sentence that follows it. Measured by this file's own new selftest arm: `m3 740/751 <MARKER> ...`
        # read as {} -- the clause window swallowed the marker, PROGRESS_SUPERSEDED matched, and the cell's
        # ONLY live number was dropped, leaving `agree` to report a one-sided population instead of a value.
        # ⭐ The bug and its guard are the same shape one level apart: the clause window was the thing that
        # made the archive look live, and it is also what makes the live number look archived. Bounding it
        # at the marker fixes both directions with one edit, which is why the marker is a boundary and not
        # just another drop keyword.
        if _sup_at != -1 and m.start() < _sup_at:
            _cl_end = min(_cl_end, _sup_at)
        clause = s[_cl_start:_cl_end].lower()
        # ⛔⭐ TWO DROPS THAT MUST NOT BE THE SAME DROP. A PROGRESS_DROP marker ("smoke", "corpus suite") names a
        # DIFFERENT population, so the whole denominator leaves the cell -- correct, and measured on snocone.
        # A PROGRESS_SUPERSEDED marker names THE SAME population at an earlier time, so dropping the
        # denominator would delete the LIVE number with it: the first cure here did exactly that and read
        # icon's `**596/596** ... hq_C read **595/596** before that cure` as {153: 153}, losing 596 entirely.
        # A superseded citation drops ONE FRACTION, like a trailing failure label.
        sup = [d for d in PROGRESS_SUPERSEDED if d in clause]
        hit = [d for d in PROGRESS_DROP if d in ctx]
        if hit:
            dropped.add(t)
            work.append("drop %d/%d (%r in clause: %s)" % (ps, t, hit[0], _clause_snip(clause)))
            consumed.append((m.start(), m.end()))
            continue
        if sup:
            work.append("drop %d/%d (superseded reading cited for provenance: %r -- the same population at an earlier time, never this cell's value; clause: %s)" % (ps, t, sup[0], _clause_snip(clause)))
            consumed.append((m.start(), m.end()))
            continue
        # ⭐ Drops THIS FRACTION ONLY, never the denominator -- unlike a leading PROGRESS_DROP marker, a
        # trailing label names exactly one number, and the same population may carry a real pass fraction
        # elsewhere in the cell that must survive. If nothing else names the denominator it simply leaves
        # this table, and the gate reports it as the one-sided population it honestly is.
        suf = re.match(r"\s+(%s)\b(?!\s*=)" % "|".join(PROGRESS_FAIL_SUFFIX), s[m.end():], re.I)
        if suf:
            work.append("drop %d/%d (labelled %r -- a FAILURE count, not a pass fraction; clause: %s)" % (ps, t, suf.group(1), _clause_snip(clause)))
            consumed.append((m.start(), m.end()))
            continue
        groups.setdefault(t, []).append(ps)
        consumed.append((m.start(), m.end()))
    # ⛔ BLANK EVERY CONSUMED FRACTION OUT OF THE PROBE TEXT. Without this the leftover check re-reads the
    # TAIL of a fraction it already counted -- snobol4's "csnobol4_suite 52/118 PASS" leaves "118 PASS"
    # behind, which looks exactly like an unconsumed population and made the whole language read MISSING
    # while its number had in fact been read correctly. A fail-closed guard that fires on its own successful
    # work is worse than no guard: it is unfalsifiable noise, and the first response to it is to switch it off.
    _b = list(s)
    for _lo, _hi in consumed:
        for _i in range(_lo, _hi):
            _b[_i] = " "
    s = "".join(_b)
    # ⛔⭐ FAIL CLOSED -- but on the text MINUS every dropped clause. Two measured lessons compose here.
    # (1) An unconsumed population marker means the cell is UNREADABLE and must not be scored: not 100%, not
    #     0%, not silently dropped. (2) A cell often quotes a SECONDARY suite for context -- icon's M carries
    #     "STRICT rung suite 266 PASS · 4 FAIL · ... of 298", which is ladder work that must not count toward
    #     M. Checking leftovers on the RAW text made icon (and with it ALL) read MISSING because of a clause
    #     that was never supposed to be counted. So the clause is excised FOR THE CHECK ONLY -- excising it
    #     for the COUNT as well silently re-admitted snocone's floor and prolog's superseded 271/270, because
    #     removing the marker text also removed the evidence that those fractions were droppable.
    probe = s
    for d in PROGRESS_DROP:
        while True:
            mm = re.search(re.escape(d), probe, re.I)
            if not mm:
                break
            lo = max((probe.rfind(c, 0, mm.start()) for c in ("·", ";", "—")), default=-1)
            hi = min([x for x in (probe.find(c, mm.end()) for c in ("·", ";", "—")) if x != -1] or [len(probe)])
            probe = probe[:lo + 1] + " " + probe[hi:]
    # ⛔ key=value PAIRS ARE NOT A LOOSE POPULATION. `in_tier=986 pass=4` reads as "986 pass" to a naive
    # scan, so a cell written in the harness's OWN board idiom -- the most machine-readable form there is --
    # tripped the guard. The lookbehind rejects a digit run that belongs to `key=986`, and `pass=` is
    # excluded outright: an `=` means the number is already labelled and already read.
    leftover = re.findall(r"(?<![=\w])\d+\s+pass\b(?!\s*=)|\bpass\s+\d+|\brun\(|\bdenominator\s+\d+", probe, re.I)
    if leftover:
        work.append("UNREADABLE: %d unconsumed population marker(s): %s" % (len(leftover), ", ".join(sorted(set(leftover)))))
        return None, work
    out = {}
    for t, ps in groups.items():
        if t in dropped:
            work.append("drop %s/%d (denominator dropped)" % ("/".join(str(x) for x in ps), t))
            continue
        # ⛔⭐⭐ EVERY SURVIVING FRACTION IS RETURNED -- THE VALUE IS A TUPLE, NEVER A SCALAR (hq_C measured
        # 2026-09-06, .github ea220f45; cured here by hq_T 2026-09-10). This used to be `out[t] = min(ps)`,
        # and the collapse was invisible ABOVE this line as well as below it: the prolog V cell physically
        # held `swi_tests m3 82/114 · m4 0/114` and this function returned {114: 0}, so `agree` compared 0
        # against 0, AGREED, and said nothing -- while the percent reader (counted_fractions) took the FIRST
        # fraction in the package's clause, 82/114, and published a number this gate had never looked at.
        # Removing the cell moved prolog 414/621 -> 332/507: exactly the 82 passes over 114 entries that the
        # gate could not see. ⭐ THE SHAPE, which is why the cure is at the EXTRACTOR and not at either
        # reader: a gate that compares two TABLES cannot see a disagreement WITHIN one cell, and both
        # readers were individually correct -- there was no bug to find in either one. If the extractor
        # collapses, no caller can know there were ever two numbers, so the collapse had to stop HERE.
        # ⭐ min(ps) is still the both-modes bar and is still what every verdict uses -- it moved into
        # cell_bar() so that taking the worse mode is now a CALLER'S stated choice rather than a silent
        # property of the parser. Order is cell order: `fr[t][0]` is the fraction a left-to-right reader
        # meets first, which is the one counted_fractions takes.
        out[t] = tuple(ps)
        if t in logged:
            continue
        if len(ps) > 1:
            work.append("%d/%d (from %s, worse mode)" % (min(ps), t, ",".join(str(x) for x in ps)))
        else:
            work.append("%d/%d" % (ps[0], t))
    return out, work


def cell_bar(fr):
    # {denominator: worse-mode pass} -- the both-modes bar, which is what every VERDICT reads. Separated
    # from cell_fractions so that a caller collapsing an m3/m4 twin says so out loud (see the ruling above).
    return {t: min(v) for t, v in (fr or {}).items()}


def cell_ambiguous(fr):
    # [(denominator, values)] for every population this cell names more than once with DIFFERENT pass
    # counts. ⛔⭐ REPEATING ONE NUMBER IS NOT AMBIGUITY -- `m3 743/756 · m4 743/756` is one measurement
    # written twice and convicting on it would red 24 live cells for a house style. What is ambiguous is
    # `m3 82/114 · m4 0/114`: two readers of that cell get two different numbers and neither is wrong.
    # ⛔ AND A DENOMINATOR IS NOT A POPULATION IDENTITY. Two DIFFERENT suites of the same size group here
    # under one key, so a hit is "this cell cannot be read to one number", never "this suite disagrees with
    # itself" -- which is exactly why the caller REPORTS the cell and refuses to pick, rather than guessing.
    return [(t, tuple(v)) for t, v in sorted((fr or {}).items()) if len(set(v)) > 1]


def ladder_score(lang):
    # (built, declared) from corpus/tests/<lang>/config/LADDER.tsv, or None when there is no census.
    path = os.path.join(S4E, "corpus", "tests", lang, "config", "LADDER.tsv")
    if not os.path.isfile(path):
        return None
    built = declared = 0
    for line in open(path, encoding="utf-8", errors="replace"):
        if not re.match(r"^rung\d+", line):
            continue
        declared += 1
        if re.search(r"\bBUILT\b", line):
            built += 1
    return (built, declared) if declared else None


def forms_score(lang):
    # (witnessed, declared) straight from util_ladder_forms_check -- ONE definition of L for the whole org, so
    # the ruling that an oracle-observed census cannot be credited applies here without being restated.
    try:
        sp = importlib.util.spec_from_file_location("_lfc", os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                                        "util_ladder_forms_check.py"))
        m = importlib.util.module_from_spec(sp)
        sp.loader.exec_module(m)
        m.CORPUS = os.path.join(S4E, "corpus")
        st, d, w, miss = m.check_lang(lang, "isolation", verbose=False)
        # ⛔⭐ A PARTIALLY-ENUMERATED STANDARD HAS NO SCORE, exactly as an unwritten one has none. Measured
        # here the moment L entered the percent: rebus declares FORMS for 2 rungs of 12, both fully
        # witnessed, so L read 13/13 and the language printed **100%** on Lon's own line. The ten rungs
        # nobody has enumerated are simply not in the denominator, so the less of the book you have read the
        # better you score -- the vacuity hole, arriving in the headline number rather than in the checker.
        # So an incomplete census returns None and the language reads MISSING with its reason, which is the
        # file's existing doctrine for a census that does not exist at all: 0% would be a claim we have not
        # earned either, and 100% is very much one.
        if st in ("NOT-IN-SCHEMA", "REFUSED"):
            return None
        if any("FORMS cell is empty" in x for x in miss):
            return "incomplete"
        return (w, d) if d else None
    except Exception as e:
        # ⛔ NEVER SWALLOW THIS. A bare `return None` reads downstream as "this language has no census" --
        # a real and expected state -- so an import bug wore the costume of a legitimate answer and printed
        # `L NO census` for all seven at once while looking entirely plausible. Measured: it did exactly that.
        sys.stderr.write("WARN util_score_row.forms_score(%s): %s: %s\n" % (lang, type(e).__name__, e))
        return None


def language_progress(lang, cells, prov=""):
    # ⛔⭐⭐ THE PERCENT IS THE INDUSTRY STANDARD, NEVER OUR OWN TESTS (Lon 2026-09-04, in-chat to ceo, verbatim:
    # "do not consider our stupid tests as part of the percentage; only the packages of industry standard ones
    # count for a percentage. Fix that reporting now." -- after "Is Icon really at 90%? I do not believe it.":
    # icon's 90% was 811/901 with 730 of the denominator our own rungs and AST fixtures, the two public suites at
    # 48% and 47% barely moving it). Basis from here: the V column ONLY -- the vendored industry-standard packages
    # graded by their own oracle. M and AST are printed beside as "ours" and never counted. A language with no
    # public suite (snocone, rebus) prints no-public-suite and is excluded from ALL by design, never scored 100%
    # from its own ladder.
    if lang in PROGRESS_NO_PUBLIC_SUITE:
        return "NOSUITE", "", 0, 0, ["no public industry-standard suite exists for this language -- not scored, not in ALL (Lon 2026-09-04); its ladder to the reference's top is reported in L, not as a percent"]
    # pass/total over the V cells only; xfail is never a pass because the grid prints it BESIDE the
    # fraction, never inside it, so an xfail is already excluded by reading the fraction.
    P = T = 0
    work = []
    unreadable = False
    # ⛔⭐⭐ VALUE AND LABEL COME FROM THE SAME TABLE OR THE LINE IS A LIE ABOUT ITSELF (ceo audit of
    # 3fbee86c5, and the catch is exact). Keying staleness on the display's `board:` clause while still
    # reading the NUMBER from the September-10 grid paired one table's value with the other table's
    # freshness -- snobol4's grid said 1689/1736 labelled 09-03 while the display said 1698/1736 today, so
    # the line published the OLD number wearing the NEW number's timestamp. ⭐ That is the same
    # value-from-one-run stamp-from-another defect I had named in my own SCORE merge receipt an hour
    # earlier and then committed myself, one table over: knowing a failure shape is not the same as
    # recognising it, and the recognition came from someone else re-reading my landing.
    # So BOTH now come from the standardized display, which is the table runners actually write and the
    # only one carrying provenance. The grid stays the human-facing summary; the agree gate is what keeps
    # the two honest about each other.
    incomplete, notrun = [], []
    for key in ("V",):
        idx = GRID_COLUMNS[key][0]
        got, w = counted_fractions(lang, cells[idx])
        work += w
        if got is None:
            unreadable = True
            continue
        # ⛔⭐⭐ THE PUBLISHED NUMBER IS WHAT THE SUITES ACTUALLY MEASURED — LON, 2026-09-05, in-chat, verbatim:
        # "I want to see accurate numbers for each language as a measurement. I do not know what is a FLOOR, but
        # whatever it is, it is not anything I want to see. Show measured numbers from running test suites not
        # FLOORS. I have a floor I stand on, that is the only floor I need."
        # ⛔ WHAT THIS REPLACES, and why it was indefensible once stated plainly: the percent summed EVERY listed
        # package, counting a suite that had never been run as 0 over its whole population. icon read 8% = 91/1066
        # where 851 of that denominator was `ipl`, a suite nobody had run-graded — so "8%" was not a measurement of
        # anything, it was a measurement AVERAGED WITH AN ASSUMPTION. snobol4 carried csnobol4 0/125 the same way,
        # prolog carried gnu 0/91.
        # ⭐ A NOT-RUN SUITE IS INVENTORY, NEVER A SCORE. It is still reported — named, with its population, right
        # beside the number — because hiding it would trade one dishonesty for another. What it must never do is
        # enter the arithmetic and come out looking like a result.
        for _n, _p, _pop in getattr(got, "found", ()):
            P += _p
            T += _pop
        for _n, _pop in getattr(got, "notrun", ()):
            notrun.append((_n, _pop))
        if getattr(got, "unreadable", ()):
            incomplete.extend(got.unreadable)
    # the ladder (L) is OURS too: reported beside the percent, never inside it (Lon 2026-09-04: only the packages count)
    fs = forms_score(lang)
    if fs == "incomplete":
        work.append("L census INCOMPLETE (some rungs have no FORMS) -- reported, not in the percent")
    elif fs is not None:
        work.append("L forms %d/%d witnessed of DECLARED-FROM-THE-REFERENCE -- reported, not in the percent" % fs)
    else:
        work.append("L no usable census -- reported, not in the percent")
    vcell = cells[GRID_COLUMNS["V"][0]]
    _mg, _mw = cell_fractions(cells[GRID_COLUMNS["M"][0]])
    work += ["ours(not counted) M %s" % x for x in _mw]
    for name, n in PROGRESS_ESTIMATED.get(lang, []):
        if name in vcell and any(k in vcell for k in PROGRESS_NO_MARKERS):
            T += n
            work.append("V %s 0/%d (estimated: named, no number)" % (name, n))
    # ⛔⭐⭐ STALENESS KEYS ON THE PROVENANCE LABEL, NEVER ON A DATE FOUND IN PROSE (Lon 2026-09-04, in-chat
    # to ceo: "So I see those cells are unverified. Why are they not verified? Get that fixed."). The old
    # rule scanned the M cell's PROSE for any `MM-DD` and marked the language stale if any of them was older
    # than today. Measured on the live board the hour this was written: snobol4's M cell was measured TODAY
    # at 12:07 and still printed `sno 91%?`, because the cell's own commentary says "seat08, 2026-09-03" --
    # a true sentence about history that the freshness check read as the age of the measurement.
    # ⭐ THE GENERAL SHAPE: a cell that EXPLAINS ITSELF WELL accumulates dates, so the better-documented a
    # cell got the staler it looked, and the only way to clear the mark was to delete the history. A
    # freshness rule that punishes provenance prose is pointed exactly backwards.
    # ⛔ THE LABEL IS THE DISPLAY ROW'S OWN `board:` CLAUSE -- machine-written by cmd_write, one canonical
    # ISO stamp, and the mirror of this very M cell (GRID_MIRROR board->M). No label means the age is
    # UNKNOWN, which reads STALE and NAMES ITSELF rather than passing quietly: an undatable number is not a
    # fresh one. The cell's own explicit word STALE still wins outright.
    # staleness keys on the V cell -- the cell the percent is read from -- by its own ⟨measured …⟩ stamp.
    mcell = vcell
    stale = "STALE" in mcell
    if stale:
        work.append("V reads STALE by the cell's own word")
    label = ""
    if not stale:
        dm = re.search(GRID_STAMP_RE, mcell)
        if dm:
            label = dm.group(0)
            d = datetime.date(int(dm.group(1)), int(dm.group(2)), int(dm.group(3)))
            age = (datetime.date.today() - d).days
            stale = age >= 1
            work.append("V stamp %s (%s)" % (label, "today" if age <= 0 else "%d day(s) old -- STALE" % age))
        else:
            stale = True
            work.append("V carries NO canonical ⟨measured …⟩ stamp -- age UNKNOWN, which is not the same as "
                        "fresh, so it reads STALE until a runner's write stamps this very cell")
    # ⭐ FLOOR, NEVER ROUND. A completion indicator that rounds shows 100% at 99.6%, which is the one
    # number on this line anybody will act on. Floor reaches 100% only when the work is actually done.
    if unreadable:
        return None, "", P, T, work
    pct = (100 * P) // T if T else 0
    # ⛔⭐ TWO MARKERS, TWO MEANINGS, NEVER CONFLATED. `?` says the number may be OLD; `!` says the number is a
    # FLOOR because a package in it could not be read at all. A stale measurement is still a measurement; a
    # reading failure is not, and giving them one glyph would let the louder problem hide inside the quieter one.
    if notrun:
        work.append("NOT RUN (inventory, deliberately OUTSIDE the percent -- Lon 2026-09-05): %s"
                    % " · ".join("%s %d programs" % (n, p) for n, p in notrun))
    if incomplete:
        work.append("⚠ CELL NOT MACHINE-READABLE: %s -- the suite may well have run, but this cell states its "
                    "result in counts rather than `<pass>/<total>` over a declared population, so the reader "
                    "cannot use it. Fix the cell; it is not a score of zero." % ", ".join(incomplete))
    return pct, ("?" if stale else ""), P, T, work


# ⛔⭐ COLUMN SEMANTICS -- THE CLASS NO READABILITY CHECK REACHES (ceo ruling 2026-09-03 22:39, after hq_T
# published `reb 100%`). That number came from a census written into the M column by a "|"-split off-by-one:
# the cell was PERFECTLY READABLE and completely wrong, because "22/22" is a well-formed population in a cell
# that is allowed to contain one. No parse rule reaches that -- only knowing what the COLUMN MEANS does.
# So: every runner a cell cites must be of that column's KIND.
# ⛔ ORDER MATTERS AND IS MEASURED, NOT GUESSED: `test_prolog_rung_suite.sh` ends in `_suite.sh` and is a
# LADDER runner, so the ladder patterns must be tried BEFORE the vendor ones or the L column's own runner
# would be convicted of being a vendor suite.
COLUMN_KINDS = {
    "L": [r"_ladder\.sh$", r"rung_suite\.sh$", r"LADDER\.tsv$"],
    "V": [r"_suite\.sh$", r"^scorecard_", r"roast_scoreboard", r"_packages?\.sh$"],
    "M": [r"corpus_suite_harness\.py$", r"^board_.*_rungs\.sh$", r"^test_corpus_.*\.sh$", r"^test_gate_pascal_m[34].*"],
}
KIND_ORDER = ("L", "V", "M")
# ⛔ RUNGS RUNNERS WHOSE NAME ENDS IN THE VENDOR SUFFIX (hq_raku 2026-09-16; coo, row util-score-row-citation-kind-classifies-the-
# raku-master-runner-as-vendor-by-its-suite-suffix): test_raku_ir_full_suite.sh grades corpus/tests/raku/ALL.raku + ALL.ref -- the
# RAKU RUNGS by population -- but `_suite.sh$` is the V pattern and V is tried before M, so a raku M cell naming its own runner
# went red in test_gate_score_column_semantics.sh and the cell had to omit the runner's name. Named here and tried FIRST, the same
# cure test_prolog_rung_suite.sh has in L. A name enters this list by what it GRADES (a rung suite pair), never by what it is called.
RUNGS_RUNNERS_WITH_SUITE_SUFFIX = [r"^test_raku_ir_full_suite\.sh$"]


def citation_kind(cite):
    base = cite.split("/")[-1]
    for pat in RUNGS_RUNNERS_WITH_SUITE_SUFFIX:
        if re.search(pat, base):
            return "M"
    for k in KIND_ORDER:
        for pat in COLUMN_KINDS[k]:
            if re.search(pat, base) or re.search(pat, cite):
                return k
    return None


def cmd_columns(a):
    lines = open(SCORE_MD, encoding="utf-8").read().split("\n")
    _hdr, rows, gskip = find_grid(lines)
    bad = []
    checked = 0
    for lang in sorted(rows):
        for key in ("M", "L", "V"):
            cell = rows[lang][GRID_COLUMNS[key][0]]
            cites = sorted(set(re.findall(r"[A-Za-z0-9_./-]+\.(?:sh|py|tsv)", cell)))
            for c in cites:
                checked += 1
                k = citation_kind(c)
                if k is None:
                    continue          # an unrecognised tool is not evidence of a wrong column
                if k != key:
                    bad.append("%s %s cell cites %s, which is a %s-column runner" % (lang, key, c, k))
    # ⛔ THE SECOND GATE OVER THE SAME GRID, AND IT HAD THE SAME BLIND SPOT. A malformed row drops out of
    # `rows`, so its citations stop being checked and this gate's PASS silently stops covering that language.
    # Floor first (nothing read at all), then the malformed-row red, then the finding.
    if not rows:
        die("read ZERO rows from the September-10 grid -- a column-semantics gate over no cells is not a PASS")
    if gskip:
        print("⛔ GATE RED [score_column_semantics]: %d grid row(s) are MALFORMED and their citations were not "
              "checked at all -- this gate cannot vouch for a column it could not read" % len(gskip))
        for l in sorted(gskip):
            _ln, _n = gskip[l]
            print("    %s: grid row at line %d has %d columns, the grid has %d" % (l, _ln + 1, _n, GRID_NCOLS))
        return 1
    if bad:
        print("⛔ GATE RED [score_column_semantics]: %d citation(s) in the wrong column" % len(bad))
        for b in bad:
            print("    " + b)
        print("    ⭐ A cell in the wrong column is READABLE AND WRONG -- the one shape no parse check catches.")
        return 1
    print("GATE PASS(0) [score_column_semantics]: %d runner citation(s) across %d grid row(s) all match their column's kind (M rungs · L ladder · V vendor)" % (checked, len(rows)))
    return 0


# ⛔⭐ THE TWO TABLES MUST AGREE BY VALUE (ceo approval, 2026-09-03). SCORE.md holds the September-10 grid
# AND the standardized display, and `write` updates only the display -- so every grid cell goes stale the
# moment a runner records a measurement, and NOTHING SAYS SO. Measured four times in one sitting: the raku
# M cell read 41/42 after 42/42 was pushed; the raku V cell had no roast number while the display had one;
# the prolog V cell had no INRIA number while the display had one; each needed a hand edit to find.
# ⛔ IT COMPARES VALUES, NEVER DATES. Same-day staleness is invisible to a freshness check by construction:
# the raku cell carried TODAY'S date and a superseded number, because the date was written by an earlier
# measurement that really was today. A timestamp cannot separate "true and current" from "true this morning".
GRID_MIRROR = {"board": "M", "vendor": "V"}
GRID_DIRECT = {"ladder": "L", "bench": "B"}
# ⛔⭐ THE GRID CELL CARRIES ITS OWN MACHINE-WRITTEN DATE, so the progress line reads VALUE and LABEL from the
# SAME table. Reading the value from the grid and the freshness from the display row published the OLD number
# wearing the NEW number's timestamp (ceo audit of 3fbee86c5; snobol4 grid 1689/1736 labelled with the display's
# today). The marker is appended by cmd_write's grid half, contains no `N/M`, so no fraction reader ever sees it.
GRID_STAMP = "⟨measured %s · %s⟩"
GRID_STAMP_RE = r"⟨measured (\d{4})-(\d{2})-(\d{2}) · [^⟩]*⟩"


def cmd_agree(a):
    lines = open(SCORE_MD, encoding="utf-8").read().split("\n")
    _gh, grid, gskip = find_grid(lines)
    _dh, disp, dskip = find_table(lines)
    bad, warn, ambiguous = [], [], []
    checked = 0
    # ⛔⭐ A LANGUAGE THIS GATE CANNOT READ IS A MEASUREMENT IT DID NOT MAKE, AND SAYING PASS OVER IT IS THE
    # VACUOUS-GATE CLASS. `if lang not in disp: continue` treated an unreadable display row as nothing to do,
    # so a malformed snobol4 row (see find_table) had this gate printing "GATE PASS(0) ... 11 mirrored cell
    # pair(s)" while blind to the project's LARGEST language -- a green that proved the absence of evidence,
    # not evidence of absence. A gate that cannot measure REFUSES; it never skips-as-success.
    unread = sorted(l for l in grid if l in dskip)
    # ⛔⭐ AND THE SAME QUESTION ASKED OF THE OTHER TABLE, which is the half that was missing. A language whose
    # GRID row is malformed never enters `grid` at all, so the loop below cannot skip it -- it never sees it,
    # and `checked` simply comes out smaller. That is invisible by construction: no arm fails, no language is
    # named, and the summary line's own denominator moves without comment.
    gunread = sorted(gskip)
    for lang in sorted(grid):
        if lang not in disp:
            continue
        _i, dcells = disp[lang]
        for col, gkey in GRID_MIRROR.items():
            dfr_all, _w = cell_fractions(dcells[COLUMNS[col][0]])
            gfr_all, _w2 = cell_fractions(grid[lang][GRID_COLUMNS[gkey][0]])
            if dfr_all is None or gfr_all is None:
                continue          # an unreadable cell is the readability gate's business, not this one
            # ⛔⭐⭐ THE THIRD SIGNAL, AND IT IS THE ONE THIS GATE WAS STRUCTURALLY BLIND TO (hq_C
            # 2026-09-06; cured hq_T 2026-09-10). Everything below compares one table's cell against the
            # other's, and NO amount of that can see a cell that disagrees with ITSELF: `swi_tests m3
            # 82/114 · m4 0/114` names one population twice with two different numbers, the percent reader
            # takes 82 and the bar takes 0, and the two tables can be in perfect agreement the whole time.
            # ⛔ THE GATE DOES NOT PICK. Which of two numbers is "the value" is an INTENT question, and a
            # tool that guesses it manufactures the confident wrong answer this file refuses everywhere
            # else -- so the cell is NAMED with both numbers and handed back to its writer.
            for _t, _vals in cell_ambiguous(dfr_all):
                ambiguous.append("%s: display %s names the %d-population %d times with DIFFERENT counts %s "
                                 "-- first in cell order is %d, the both-modes bar is %d"
                                 % (lang, col, _t, len(_vals), "/".join(str(x) for x in _vals),
                                    _vals[0], min(_vals)))
            for _t, _vals in cell_ambiguous(gfr_all):
                ambiguous.append("%s: grid %s names the %d-population %d times with DIFFERENT counts %s "
                                 "-- first in cell order is %d, the both-modes bar is %d"
                                 % (lang, gkey, _t, len(_vals), "/".join(str(x) for x in _vals),
                                    _vals[0], min(_vals)))
            # ⭐ The VERDICT still reads the both-modes bar, unchanged, deliberately: this landing cures the
            # extractor's silent discard and SURFACES the intra-cell class; it does not re-decide any
            # existing conflict. Comparing full tuples instead would red a cell whose modes simply agree
            # (`743/756 · 743/756` vs `743/756`), which is a house style, not a disagreement.
            dfr, gfr = cell_bar(dfr_all), cell_bar(gfr_all)
            checked += 1
            # Compare the populations both tables actually name. A denominator present in ONE table only is
            # the staleness this gate exists for; a denominator in both must carry the same pass count.
            for t in sorted(set(dfr) & set(gfr)):
                if dfr[t] != gfr[t]:
                    bad.append("%s: display %s says %d/%d, grid %s says %d/%d" % (lang, col, dfr[t], t, gkey, gfr[t], t))
            only_d = sorted(set(dfr) - set(gfr))
            only_g = sorted(set(gfr) - set(dfr))
            # ⛔⭐ IF THE OTHER CELL *HAD* THIS POPULATION AND DROPPED IT, SAY SO AND NAME THE CLAUSE. A
            # one-sided population has two very different causes that this message used to render
            # identically: the dual-write gap (the other table never received the measurement) and a marker
            # word in the author's own prose that swallowed a fraction the cell plainly contains. hq_I hit
            # the second twice in ten minutes and had no way to tell them apart -- the diagnostic named a
            # missing population, which is the OPPOSITE of what had happened. The workings already knew;
            # they were computed into _w/_w2 and discarded one line later.
            for t in only_d:
                _n = _drop_note(_w2, t)
                warn.append("%s: display %s carries a %d-population (%d/%d) the grid %s cell does not%s"
                            % (lang, col, t, dfr[t], t, gkey,
                               ("  -- and the grid cell HAS that fraction but DROPPED it: " + _n) if _n else ""))
            for t in only_g:
                _n = _drop_note(_w, t)
                warn.append("%s: grid %s carries a %d-population (%d/%d) the display %s cell does not%s"
                            % (lang, gkey, t, gfr[t], t, col,
                               ("  -- and the display cell HAS that fraction but DROPPED it: " + _n) if _n else ""))
    # ⛔⭐ TWO SIGNAL STRENGTHS, AND CONFLATING THEM WOULD MAKE THE GATE USELESS. A SAME-DENOMINATOR
    # CONFLICT (both tables name a 81-population, one says 39 and the other 41) is unambiguous: exactly one
    # of them is wrong and a reader cannot tell which. A population present in only ONE table is weaker --
    # it is usually the dual-write gap, but the two tables legitimately summarise at different grains, so
    # convicting on it would red the board for a design choice. Hard conflicts FAIL; one-sided populations
    # are reported as the staleness debt they are.
    for w in warn:
        print("  ⚠ STALE " + w)
    if warn:
        # ⛔ Do NOT attribute the ones that carry a drop note to the dual-write gap -- they are the opposite
        # case (the number IS in the other cell; a marker word in its clause swallowed it), and telling an
        # author to go re-run a measurement they already recorded is the round trip this note exists to end.
        # ⛔⭐ THREE CAUSES, AND THE ADVICE FOR EACH IS DIFFERENT -- so they are counted apart rather than
        # rendered as one number. Telling an author to "fix the prose" when the other cell honestly names a
        # FAILURE count would send them to edit a line that is already correct, which is the same wasted
        # round trip in the other direction.
        _explained = [w for w in warn if "DROPPED it: " in w]
        _failcount = [w for w in _explained if "a FAILURE count" in w]
        _swallowed = [w for w in _explained if w not in _failcount]
        if len(_explained) < len(warn):
            # ⛔⭐ THIS SENTENCE USED TO SAY "`write` updates the display and not the grid" AND THAT HAS BEEN
            # FALSE SINCE THE DUAL-WRITE LANDED -- `write` attempts BOTH and names its refusal. Measured cost
            # of leaving it: the ceo read it off this gate's own output and minted a row on it (2026-09-05),
            # and I had just re-committed the sentence unchanged while editing the lines around it. ⭐ A
            # diagnostic is documentation with a much larger readership than the comment above the code, and
            # nothing warns you when it ages -- a stale EXPLANATION outlives the behaviour it describes and
            # is quoted as current by everyone downstream.
            print("  ⭐ A one-sided population with no drop note above means the two cells were not written together: either `write` ATTEMPTED the grid half and refused it out loud at the time (prose at risk, or a board line carrying no N/M fraction), or one cell was hand-edited outside `write` and its twin kept yesterday's. `write --dry-run` now previews both halves, so you can see which before landing.")
        if _failcount:
            print("  ✅ %d of those need NO action: the other cell names that population only as a FAILURE count, which is not a pass fraction. The one-sided population is honest, not debt." % len(_failcount))
        if _swallowed:
            print("  ⛔ %d of those are NOT the dual-write gap: the other cell CONTAINS the fraction and a marker word in the quoted clause dropped it. Fix the PROSE -- spell a retired figure in words, or bound it in its own clause with `·` or `;` -- and do not re-run anything." % len(_swallowed))
    if ambiguous:
        print("  ⛔ %d CELL(S) CANNOT BE READ TO ONE NUMBER -- one population, named more than once, with "
              "different pass counts. Two readers of such a cell get two different numbers and NEITHER is "
              "wrong, so no gate comparing tables can ever see it:" % len(ambiguous))
        for x in ambiguous:
            print("    " + x)
        print("    ⭐ AN HONEST m3/m4 TWIN IS ON THIS LIST TOO, AND THAT IS THE POINT -- do NOT delete a "
              "correct mode pair. `--run 23/118 · --compile 17/118` is two true measurements, and it is "
              "STILL listed, because a reader taking the first fraction and a reader taking the bar resolve "
              "the same cell to 23 and to 17. The cell is not wrong; it is not resolvable to one number, "
              "and every consumer of this board resolves it anyway.")
        print("    ⭐ FIX THE CELL, not a reader: give each measurement its own clause with `·` so the "
              "populations stop sharing a key, or name the ONE number the cell means and demote the rest to "
              "provenance. ⛔ Note a DENOMINATOR IS NOT A POPULATION IDENTITY -- two different suites of the "
              "same size land under one key here, so a hit may be two unrelated suites, which is itself "
              "worth spelling out in the cell.")
        print("    ⭐ Run `agree --strict` to make this REFUSE rc=2 instead of report (hq_T row "
              "gate-honesty-strict-by-default); it is report-only today so that surfacing the class does "
              "not red a blocking arm fleet-wide on cells whose correct values are other seats' to state.")
    # ⛔⭐⭐ THE POPULATION FLOOR, AND IT IS THE ARM THAT WOULD HAVE CAUGHT hq_B's INCIDENT WITHOUT ANY OF THE
    # ABOVE. A comparison gate whose verdict is "0 conflicts" is computing an emptiness, and `0 conflicts over
    # 10 pairs`, `0 conflicts over 1 pair` and `0 conflicts over NOTHING` are the same arithmetic wearing the
    # same words. Both tables can be perfectly well-formed and still share no comparable cell -- so this floor
    # is not a corollary of the malformed-row checks, it is the independent bar: a gate that graded zero
    # pairs REFUSES rc=2 and never prints the success shape (RULES.md § a test that cannot measure refuses).
    if checked == 0:
        why = ""
        if unread or gunread:
            why = (" -- %d malformed row(s) (%s) are why there was nothing left to compare"
                   % (len(set(unread) | set(gunread)), ", ".join(sorted(set(unread) | set(gunread)))))
        die("compared ZERO mirrored cell pairs across %d grid row(s) and %d display row(s)%s. A gate that "
            "measured nothing does not get to say the two tables agree" % (len(grid), len(disp), why))
    if unread or gunread:
        print("⛔ GATE RED [score_tables_agree]: %d language(s) have a MALFORMED row and were not compared at all "
              "-- this gate cannot claim agreement over a table it could only partly read" % len(set(unread) | set(gunread)))
        for l in unread:
            _ln, _n = dskip[l]
            print("    %s: DISPLAY row at line %d has %d columns, the table has %d" % (l, _ln + 1, _n, PROV_COL + 1))
        for l in gunread:
            _ln, _n = gskip[l]
            print("    %s: SEPTEMBER-10 GRID row at line %d has %d columns, the grid has %d" % (l, _ln + 1, _n, GRID_NCOLS))
        print("    ⭐ A GREEN THAT APPEARS WHILE YOU ARE EDITING THE DATA IS A SUSPECT, NOT A REWARD (hq_B, 2026-09-05):")
        print("      breaking a row is how a population goes to zero, and a population of zero scores as a population with no conflicts.")
        return 1
    if ambiguous and getattr(a, "strict", False):
        die("%d cell(s) name one population more than once with DIFFERENT pass counts (listed above). Under "
            "--strict this gate REFUSES rc=2 rather than reporting: it cannot say the two tables agree about "
            "a number neither table can be read to name" % len(ambiguous))
    if bad:
        print("⛔ GATE RED [score_tables_agree]: %d SAME-DENOMINATOR disagreement(s) -- one of the two tables is wrong and a reader cannot tell which" % len(bad))
        for b in bad:
            print("    " + b)
        print("    ⭐ Compared by VALUE, never by date: same-day staleness (a true date beside a superseded number) is invisible to any freshness check.")
        return 1
    print("GATE PASS(0) [score_tables_agree]: %d mirrored cell pair(s), 0 same-denominator conflicts, %d "
          "one-sided population(s) and %d unreadable-to-one-number cell(s) reported above"
          % (checked, len(warn), len(ambiguous)))
    return 0


def cmd_progress(a):
    """⛔ DELETED ON LON'S WORD, 2026-09-13, in-chat and verbatim: "Do you see that banner with the
    bogus numbers for sno, sc, icn that says PROGRESS 09-13. All bogus. Delete that. Do not show that
    ever again."

    This printed a per-language percentage line and a bar chart derived from SUITES.tsv. The numbers
    were not measurements of anything a reader could act on: a language's percent mixed suites with
    unlike denominators, carried a `?` when a counted suite had not been re-graded today, and read
    `no-public-suite` for two languages, so the row said 100% where four suites happened to be green
    and said nothing at all where none is vendored. Lon read it and called it bogus. It is.

    The function is kept as a silent no-op rather than removed because several instruments still
    invoke `util_score_row.py progress` and a missing subcommand would turn them red for asking --
    the same failure mode as the suite banner's deletion orphaning a gate earlier today. It prints
    NOTHING and exits 0. test_gate_the_progress_line_is_never_printed.sh holds it deleted.
    """
    return 0


def cmd_seat_name(a):
    who = os.environ.get("S4E_SEAT", "").strip() or derive_measurer()
    if not who:
        die("no seat identity: S4E_SEAT is unset and the root %r is not in the seat map, so it could not be "
            "derived. Pass S4E_SEAT=<name> or run from a known root." % S4E)
    print(who)
    return 0


def main():
    p = argparse.ArgumentParser(description="Rewrite one SCORE.md row from numbers a runner already measured. Runs no suite.")
    sub = p.add_subparsers(dest="cmd")
    w = sub.add_parser("write", help="rewrite one language's one column, in place, with provenance")
    w.add_argument("--lang", required=True)
    w.add_argument("--column", required=True, help="one of: " + ", ".join(sorted(COLUMNS)) + " (display, mirrored to the grid) or " + ", ".join(sorted(GRID_DIRECT)) + " (the September-10 grid L/B cells directly) or " + ", ".join(sorted(SUITE_ONLY)) + " (a suite-table row with no grid cell: the language's benchmarks graded as tests)")
    w.add_argument("--text", required=True, help="the runner's OWN printed board line, verbatim where possible")
    w.add_argument("--measurer", required=True, help="seat/HQ identity that ran it")
    w.add_argument("--modes", default="", help="e.g. m3,m4")
    w.add_argument("--suite", default="", help="name ONE measurement inside a shared cell (e.g. Arizona, JCON, SWI, GNU, fpc); "
                                               "without it the whole cell is replaced, which is wrong for the vendor column")
    w.add_argument("--suite-key", default="", help="name the SUITES.tsv row explicitly when --lang/--suite cannot resolve it")
    w.add_argument("--suite-pass", type=int, default=None, help="pass count for the suite row (with --suite-total); required when --text carries no single N/M")
    w.add_argument("--suite-total", type=int, default=None, help="total for the suite row (with --suite-pass)")
    w.add_argument("--criterion-changed", default="", metavar="'YYYY-MM-DD:reason'",
                   help="STAMP a criterion change into SUITES.tsv column 12 (appended with ' | '); REQUIRED when this write moves the row's "
                        "denominator or --text names an INSTRUMENT CHANGE, else the write REFUSES rc=2 before touching either file (CEO-785)")
    w.add_argument("--excluded", type=int, default=None, metavar="N",
                   help="the programs NOT IN THE SPITBOL DIALECT this row's denominator leaves out, named in the package's EXCLUDED.tsv "
                        "(Lon 2026-09-26, CEO-1286); written to SUITES.tsv column today_excluded and shown as EXCLUDED=N in the grid")
    w.add_argument("--secs", type=int, default=None, metavar="N",
                   help="the run's wall clock in seconds (Lon 2026-10-08, CEO-1562); default: now minus S4E_RUN_T0, which one_runner_guard stamps "
                        "at the runner's start; written to SUITES.tsv column today_secs and shown as the grid's Wall")
    w.add_argument("--no-suite-sync", action="store_true", help="labelled escape: this V/M write genuinely has no SUITES.tsv row. The banner will read the row STALE")
    w.add_argument("--dry-run", action="store_true")
    w.set_defaults(fn=cmd_write)
    c = sub.add_parser("check", help="report every row's staleness against origin/main")
    c.add_argument("--threshold", type=int, default=STALE_WARN_COMMITS)
    c.add_argument("--no-fetch", action="store_true", help="do not contact origin; grade against the last-known origin/main (for test loops)")
    c.set_defaults(fn=cmd_check)
    g = sub.add_parser("progress", help="print the ONE progress line from the September-10 grid; runs no suite")
    g.add_argument("--verbose", action="store_true", help="show the per-language workings, plus the L and B cells the one-liner omits")
    g.set_defaults(fn=cmd_progress)
    g2 = sub.add_parser("agree", help="assert the September-10 grid and the standardized display agree BY VALUE")
    g2.add_argument("--strict", action="store_true",
                    help="REFUSE rc=2 (instead of reporting) when a cell names one population more than once "
                         "with different pass counts -- a cell no reader can resolve to one number")
    g2.set_defaults(fn=cmd_agree)
    k = sub.add_parser("columns", help="assert every runner a grid cell cites is of that column's kind")
    k.set_defaults(fn=cmd_columns)
    q = sub.add_parser("clause-check", help="convict a V-cell package clause that reads zero while a fraction for it exists in the grid's wider cell or its display twin")
    q.set_defaults(fn=cmd_clausecheck)
    s = sub.add_parser("selftest", help="prove rewrite-in-place and every refusal path, on a scratch copy")
    s.set_defaults(fn=cmd_selftest)
    fp = sub.add_parser("from-progress", help="assemble ONE SUITE TABLE row from the latest per-program readings in the progress DB (CEO-1676 row (b)): the AND per program over m3 and m4 at each entry's newest reading, any tree; prints SUITE_ROW with the oldest and newest reading's tree (and per partition part); runs no suite")
    fp.add_argument("--suite", required=True, help="the SUITES.tsv key (reb-rungs, swi, ...)")
    fp.add_argument("--dry-run", action="store_true", help="print the row and the population it read; write nothing")
    fp.add_argument("--criterion-changed", default="", metavar="'YYYY-MM-DD:reason'", help="stamp a criterion change on the row (passed to util_suite_banner.py --set; S4E_CRITERION_CHANGED fills it)")
    fp.add_argument("--wall-only", action="store_true", help="set ONLY the row's Wall (the sum of each member's minimum time) and nothing else: no pass, total, date or tree; needs the minimum-seconds ledger")
    fp.set_defaults(fn=cmd_from_progress)
    n = sub.add_parser("seat-name", help="print THE ONE seat identity derived from the root path; runs no suite")
    n.set_defaults(fn=cmd_seat_name)
    a = p.parse_args()
    if not getattr(a, "fn", None):
        p.print_help()
        return 2
    # ⛔⭐ THE ENVIRONMENT'S STAMP IS READ HERE, ONCE, FOR EVERY CALLER (coo 2026-09-25, on hq_icon's measurement). The runners tell a
    # seat that "a denominator move wants S4E_CRITERION_CHANGED='YYYY-MM-DD:reason' on this runner's call", but only the runners that
    # spell ${S4E_CRITERION_CHANGED:+--criterion-changed ...} passed it on: 22 row-writing scripts did not -- board_icon_rungs.sh among
    # them -- so IcnRungs' move 826 -> 828 refused its own write with the stamp set, and hq_icon wrote the row by hand (.github 915c1ff4).
    # The flag, when given, still wins; the environment fills only an absent one.
    if getattr(a, "cmd", "") == "write" and not (getattr(a, "criterion_changed", "") or "").strip():
        _env_cc = os.environ.get("S4E_CRITERION_CHANGED", "").strip()
        if _env_cc:
            a.criterion_changed = _env_cc
    if a.cmd != "seat-name" and not os.path.exists(SCORE_MD):
        die("no leaderboard at %s (S4E_HOME=%s)" % (SCORE_MD, S4E))
    # ⛔ ARMED HERE, BEFORE DISPATCH, so every command's every refusal is covered rather than the write
    # path's alone -- `check`, `agree` and `clause-check` are read-only BY INTENT and nothing until now
    # asserted it. See die()'s banner. `selftest` re-arms per scratch board (it moves SCORE_MD itself).
    refusal_watch_arm()
    return a.fn(a)


if __name__ == "__main__":
    raise SystemExit(main())
