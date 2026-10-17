#!/usr/bin/env python3
"""util_arena_pin_census.py -- THE CENSUS OF RECORD for the CEO-1146 arena sweep: which gates PIN the arena,
BY NAME, in what FORM, and whether the pin is reachable from the blocking set.

CEO-1153 (2026-09-22, ruling the coo/ceo overlap option 1): "the arena sweep stays yours under CEO-1146 and its
population is your pinned census BY NAME ... my line-stripped grep reads 27 gates with a literal or brace-default
MB=1, 26 of them in the blocking set; yours is the census of record, the difference is comment stripping."

⛔ WHY THIS IS AN INSTRUMENT AND NOT A grep, stated where the number is.  Two seats greppting the same tree got 27
and 28.  A sweep whose POPULATION is in dispute cannot produce a receipt anyone can check, and "the difference is
comment stripping" is a hypothesis until something prints both halves.  So this census prints, for every gate:
the form, the line, and whether that line SURVIVES comment stripping -- and it prints the DISAGREEING set by name
rather than reconciling the totals silently.  A total that agrees by accident is not agreement.

⛔ THE STRIPPING RULE IS STATED, NOT ASSUMED.  Shell has no tokenizer here, so `#` is treated as starting a comment
only at the start of a line or after whitespace, and NEVER inside single or double quotes on that line.  That rule
is WRONG inside heredocs (a `#` there is data, not a comment) so every heredoc-interior line is reported as
AMBIGUOUS and counted in NEITHER half -- an instrument that guesses on the exact population under dispute is the
defect this row exists to close.

⛔ THE OTHER KNOB IS PART OF THE FORM (the cto, measured 2026-09-22; re-derived at gc_heap.c:191-192 by the coo).
:191 reads SCRIP_HEAP_MB and sets BOTH mb and kb; :192 reads SCRIP_HEAP_KB and OVERWRITES kb.  Last writer wins and
KB is last, so an exported SCRIP_HEAP_KB silently defeats an explicit MB pin -- measured: collector_visits arm 5
read gc2 0 of 5 under an outer KB=64 while passing at its own default.  A pin that does not unset the other knob is
therefore NOT A PIN, and this census grades that per gate (PIN-UNSAFE) instead of treating every pin as equal.
CEO-1153 makes `env -u` a condition of the sweep; two-knobs-set-refuses-rc2 is the ceo's 33rd batch.
"""
import glob, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")

# Gates whose header seat is the cto: converted by them at SCRIP d58ac175b and EXCLUDED from this sweep by CEO-1153.
CTO_NINE = [
    "test_gate_c2bb_the_generator_arm_is_a_coroutine_start_not_a_box_entry_from_c.sh",
    "test_gate_gc_a_safe_point_stores_into_a_mapped_slot.sh",
    "test_gate_gc_emitted_safe_point_matches_its_contract.sh",
    "test_gate_gc_collector_visits_only_mapped_slots.sh",
    "test_gate_gc_the_caller_saved_spill_block_never_holds_a_heap_reference.sh",
    "test_gate_gc_the_plant_says_whether_it_applied.sh",
    "test_gate_gc_the_spine_cell_grid_is_anchored_at_the_region_base.sh",
    "test_gate_gc_the_spine_tagged_cell_walk_is_load_bearing.sh",
    "test_gate_gc_the_unmapped_spine_store_witness_answers_its_oracle_at_every_band_point.sh",
]

# ⛔⭐ ALL FOUR POSIX DEFAULT OPERATORS, AND THE NARROW VERSION OF THIS LINE COST THE CENSUS ITS OWN POPULATION.
# It read `=1` and `${VAR:-1}` and NOT `${VAR:=1}` -- one character apart, the assign-if-unset twin of the form it
# already knew -- so it called two genuinely pinned gates unpinned and reported 16 where the truth is 18
# (nv_cell_caches_honour_the_memo_generation L38, the_pending_prolog_ball_is_a_rooted_cell L48, both spelling it
# `: "${SCRIP_HEAP_MB:=1}"; export SCRIP_HEAP_MB`).  ⛔ THE COUNT WAS THE SMALL HALF: a DONE-WHEN was about to be
# written that trusts THIS READER to say ZERO, so a spelling it cannot see is a FALSE GREEN minted by the very
# instrument the sweep is graded on -- the census preaching "an instrument that guesses on the exact population
# under dispute is the defect this row exists to close" while doing it.  Caught by diffing against a hand grep and
# reading the DISAGREEING SET rather than the totals, which is what the docstring above says to do.
# So the form list is now DERIVED FROM THE SHELL GRAMMAR rather than from the spellings that happened to be in the
# tree: `=` (assignment), `:=` (assign if unset or null), `:-` (substitute if unset or null), `-` (substitute if
# unset).  A form nobody uses today costs nothing and every match is PRINTED BY NAME AND LINE, so a false positive
# is visible to the reader rather than buried in a total -- and --selftest plants one witness per spelling so this
# line can never again be narrower than the grammar without an arm going red.
# ⛔⭐ SPLIT OUT AND NAMED, NEVER FORCED (MODE line 2's standing warning; CEO-1146's population is a sweep, not a
# mandate).  A gate lands here ONLY with a reason printed beside it, so the arithmetic stays checkable by a reader:
# the swept remainder is pinned MINUS the cto's MINUS these, each one readable.  A silent exemption would be the
# census lying about its own population, which is the defect this file exists to stop.
SPLIT_OUT = {
    "test_gate_gc_a_board_can_say_whether_the_collector_ran.sh":
        "ITS MB VALUES ARE THE INSTRUMENT'S OWN TEST VECTOR, NOT AN EXASPERATION PIN. The gate exists to prove the "
        "GC-EXERCISE receipt's arena_mb field TRACKS THE RESOLVED WINDOW, and it does that by running three windows "
        "(1, 4, 512 MB) and requiring three different readings -- a compile-time constant reports 512 three times and "
        "cannot pass. Converting those to KB would delete the gate's subject. It already states this sweep's own "
        "finding in arm 3's own words ('a 4 MB small arena run exercises the collector ZERO times and only this field "
        "can say so'), so it is the one gate in the population that was never confused about the arena. WHAT IT DID "
        "GET in this landing: the CEO-1153 pin-safety cure, because every one of its five arms was defeatable by an "
        "outer SCRIP_HEAP_KB (gc_heap.c:192 wins) -- the exact trap the cto measured on collector_visits arm 5. Its "
        "arm 4 is RED on this tree for a reason that is NOT the sweep's and is reported to the ceo: reserve_mb reads 4 "
        "at a 1 MB window and 512 at a 512 MB window and the arm asserts they are EQUAL, but the reserve is "
        "max(cap, window) and cannot be smaller than a 512 MB window it must hold. The sweep's own control arm for "
        "that concern is measured and clean: reserve_mb is 4 MB with capped=0 at MB=1, KB=128 and KB=64 alike, so "
        "moving 17 gates to the shipped window shrinks no reserve.",
}

MB1 = re.compile(r'SCRIP_HEAP_MB\s*:?[-=]\s*"?\'?1"?\'?(?![0-9])')
ANYMB = re.compile(r'SCRIP_HEAP_MB')
ANYKB = re.compile(r'SCRIP_HEAP_KB')
UNSET = re.compile(r'env\s+(-\w+\s+)*-u\s+SCRIP_HEAP_KB|unset\s+[^\n]*SCRIP_HEAP_KB')

def strip_comment(line):
    """Return (code, ambiguous_reason_or_None).  `#` starts a comment at line start or after whitespace, and never
    inside a quote on that line.  Quote tracking is per line and therefore approximate -- see the docstring."""
    out, sq, dq, prev = [], False, False, ""
    for ch in line:
        if ch == "'" and not dq: sq = not sq
        elif ch == '"' and not sq: dq = not dq
        elif ch == "#" and not sq and not dq and (prev == "" or prev.isspace()):
            break
        out.append(ch); prev = ch
    return "".join(out)

def sq_embedded(line):
    """True when every MB=1 match on the line sits INSIDE a single-quoted shell string AFTER other text in that same
    string -- a fixture's content (printf '\"\"\"a docstring that mentions SCRIP_HEAP_MB=1\"\"\"' > f.py), which no
    shell reading of the line can turn into an assignment.  A quoted WORD that starts with the knob
    (env 'SCRIP_HEAP_MB=1' cmd) is NOT embedded: env takes NAME=VALUE quoted or not, so it stays a pin."""
    ms = list(MB1.finditer(line))
    if not ms: return False
    for m in ms:
        sq, dq, open_at = False, False, -1
        for i, ch in enumerate(line[:m.start()]):
            if ch == "'" and not dq: sq = not sq; open_at = i if sq else -1
            elif ch == '"' and not sq: dq = not dq
        if not sq or not line[open_at + 1:m.start()].strip(): return False
    return True

def heredoc_spans(lines):
    """1-based line numbers that sit INSIDE a heredoc body, where `#` is data and stripping would be wrong."""
    inside, tag, spans = False, None, set()
    for i, ln in enumerate(lines, 1):
        if not inside:
            m = re.search(r"<<-?\s*'?\"?([A-Za-z_][A-Za-z0-9_]*)'?\"?", ln)
            if m: inside, tag = True, m.group(1)
        else:
            if ln.strip() == tag: inside, tag = False, None
            else: spans.add(i)
    return spans

def blocking_set():
    mk = os.path.join(ROOT, "Makefile")
    try: txt = open(mk, encoding="utf-8", errors="replace").read()
    except Exception: return None
    return set(re.findall(r"bash\s+../harness/scripts/(test_gate_[A-Za-z0-9_]+\.sh)", txt))

class Unreadable(Exception):
    """A gate that cannot be read.  Raised, never swallowed: a census that silently skips a file it could not open
    reports a SMALLER population and calls it a measurement (THE INSTRUMENT LAWS -- a missing prerequisite is rc=2)."""


def scan(gatedir):
    """Classify every gate in `gatedir`.  THE ONE CLASSIFIER, shared by the real census and by --selftest, so the
    selftest proves the code the census actually runs rather than a second copy of it (SOURCE THE AUTHORITY, NEVER
    COPY IT -- the rule this file's sibling util_progress_append.py states for the axis predicate)."""
    gates = sorted(f for f in os.listdir(gatedir) if f.startswith("test_gate_") and f.endswith(".sh"))
    rows, ambiguous, mentions_only = [], [], []
    for g in gates:
        try: lines = open(os.path.join(gatedir, g), encoding="utf-8", errors="replace").read().split("\n")
        except Exception as e:
            raise Unreadable("cannot read %s -- %s" % (g, e))
        hd = heredoc_spans(lines)
        body = "\n".join(lines)
        hits_code, hits_comment, hits_ambig = [], [], []
        for i, ln in enumerate(lines, 1):
            if not MB1.search(ln): continue
            code = strip_comment(ln)
            if i in hd: hits_ambig.append((i, ln.strip()))
            elif not MB1.search(code): hits_comment.append((i, ln.strip()))
            elif sq_embedded(code): hits_ambig.append((i, ln.strip()))
            else: hits_code.append((i, ln.strip()))
        if hits_code:
            kb = bool(ANYKB.search(body)); unset = bool(UNSET.search(body))
            rows.append((g, hits_code, hits_ambig, hits_comment, kb, unset))
        elif hits_ambig: ambiguous.append(g)
        elif hits_comment:
            mentions_only.append((g, hits_comment))
    return gates, rows, ambiguous, mentions_only


def declarations():
    """Every heap_kb DECLARATION shipped in a corpus attribute file, as (path, entry, value, verdict).

    ⛔⭐⭐ A DECLARATION IS NOT A PIN, AND THIS FUNCTION EXISTS SO THE TWO ARE TOLD APART BY EVIDENCE RATHER
    THAN BY WHICH FILE THE NUMBER HAPPENS TO SIT IN (Lon 2026-09-23 / CEO-1167).  A PIN is a gate or a runner
    deciding an arena for a program FROM THE OUTSIDE -- that is the population everything above this line
    hunts, and it is a defect because the program never asked and the number is invisible to anyone reading
    the test.  A DECLARATION is the TEST ITSELF saying what live set it has, in its own attribute row, in a
    reviewable diff, carried forward across every rebuild by both suite builders.  Same environment variable,
    opposite direction of authority.  Without this section a reader who cured the 18 pins would go looking
    for the declarations next and find them indistinguishable from the thing they just removed.

    ⛔ THE VERDICT COLUMN APPLIES lib_declared_arena.sh's OWN FLOOR, because a cell the runners REFUSE must
    never be counted here as a declaration in force -- a census that counts what the cure does not apply is
    the worse half of the pair (COO-153)."""
    import csv as _csv
    root = os.environ.get("S4E_HOME") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(HERE))))
    corpus = os.path.join(root, "corpus")
    if not os.path.isdir(corpus):
        corpus = os.path.join(os.path.dirname(os.path.dirname(HERE)), "corpus")
    out, nocol, total_files = [], [], 0
    pats = [os.path.join(corpus, "tests", "*", "ALL.csv"), os.path.join(corpus, "packages", "*", "*", "ALL.csv")]
    for pat in pats:
        for f in sorted(glob.glob(pat)):
            total_files += 1
            try:
                with open(f, newline="", encoding="utf-8") as fh:
                    rdr = _csv.DictReader(fh)
                    if not rdr.fieldnames or "heap_kb" not in rdr.fieldnames:
                        nocol.append(f); continue
                    for row in rdr:
                        v = (row.get("heap_kb") or "").strip()
                        if not v:
                            continue
                        if not v.isdigit():
                            verdict = "REFUSED (unparseable)"
                        elif int(v) < 1024:
                            verdict = "REFUSED (below the 1024 KB initial window: a maximum under the window cannot be honoured, CEO-1261)"
                        elif int(v) > 4096 * 1024:
                            verdict = "REFUSED (above the ceiling SCRIP_HEAP_KB accepts)"
                        else:
                            verdict = "in force"
                        out.append((os.path.relpath(f, corpus), row.get("entry"), v, verdict))
            except OSError:
                nocol.append(f)
    return out, nocol, total_files


def main():
    blocking = blocking_set()
    if blocking is None:
        print("⛔ REFUSE(2): cannot read the Makefile, so blocking-set membership cannot be measured"); return 2
    try: gates, rows, ambiguous, mentions_only = scan(HERE)
    except Unreadable as e:
        print("⛔ REFUSE(2): %s" % e); return 2

    theirs = [r for r in rows if r[0] in CTO_NINE]
    split  = [r for r in rows if r[0] in SPLIT_OUT and r[0] not in CTO_NINE]
    mine   = [r for r in rows if r[0] not in CTO_NINE and r[0] not in SPLIT_OUT]

    print("=" * 118)
    print("ARENA PIN CENSUS -- the CEO-1146 sweep population BY NAME (CEO-1153: this is the census of record)")
    print("=" * 118)
    print("  %d gate script(s) on disk . %d reachable from the Makefile . stripping rule stated in the docstring"
          % (len(gates), len(blocking)))
    print()
    print("  PINNED AT MB=1 ON A CODE LINE (%d) -- the population.  '*' = in the blocking set." % len(rows))
    for g, code, ambig, _c, kb, unset in rows:
        who = "cto (CEO-1153 excludes)" if g in CTO_NINE else "coo"
        mark = "*" if g in blocking else " "
        pin = "PIN-UNSAFE: names no SCRIP_HEAP_KB and does not unset it" if not (kb or unset) else \
              ("pin-safe: unsets the other knob" if unset else "PIN-UNSAFE: names SCRIP_HEAP_KB but never unsets it")
        print("   %s %-92s %s" % (mark, g, who))
        for i, ln in (code + ambig):
            tagged = "AMBIGUOUS(heredoc)" if (i, ln) in ambig else "code"
            print("        %-5s %-18s %s" % ("L%d" % i, tagged, ln[:80]))
        print("        %s" % pin)

    decls, nocol, nfiles = declarations()
    print()
    print("  DECLARED IN A SUITE'S ATTRIBUTE FILE (%d) -- ⛔ NOT PINS, AND THE DISTINCTION IS THE POINT." % len(decls))
    print("    A pin above is a gate deciding an arena for a program from the OUTSIDE, invisible to anyone reading")
    print("    the test.  A declaration is the TEST saying what it needs, in its own row, in a reviewable diff,")
    print("    carried forward by both suite builders (Lon 2026-09-23, CEO-1167).  Same variable, opposite authority.")
    if decls:
        for path, entry, val, verdict in decls:
            print("      %-46s %-40s %8s KB  %s" % (path, (entry or "")[:40], val, verdict))
    else:
        print("      (none yet -- the column landed across all %d attribute file(s) in one landing and every cell is" % nfiles)
        print("       empty, which means every entry runs at the shipped default.  Each HQ writes the values for its")
        print("       own suites in its own lane, with the two readings that justify each number.)")
    if nocol:
        print("    ⛔ %d attribute file(s) carry NO heap_kb column -- no entry in them can declare anything:" % len(nocol))
        for f in nocol:
            print("      %s" % f)
    print()
    print("  MENTIONED ONLY IN A COMMENT, SO NOT PINNED (%d) -- THIS IS THE SET A LINE-STRIPPED grep AND A RAW grep"
          % len(mentions_only))
    print("  DISAGREE ABOUT, and it is printed by name rather than reconciled into a total:")
    for g, c in mentions_only:
        print("      %-92s L%d" % (g, c[0][0]))
    print()
    print("  IDENTITY: pinned %d + comment-only %d == %d gate(s) whose text matches an MB=1 form"
          % (len(rows), len(mentions_only), len(rows) + len(mentions_only)))
    if split:
        print()
        print("  SPLIT OUT AND NAMED (%d) -- pinned, MINE, and DELIBERATELY NOT SWEPT, each carrying its reason:" % len(split))
        for r in split:
            print("      %s" % r[0])
            line = "        "
            for word in SPLIT_OUT[r[0]].split():
                if len(line) + len(word) > 116: print(line); line = "        "
                line += word + " "
            if line.strip(): print(line)
        print()
    print("  THE SWEEP'S OWN POPULATION: %d pinned, MINUS the cto's %d by header seat (CEO-1153), MINUS %d split out"
          " and named above == %d MINE TO SWEEP" % (len(rows), len(theirs), len(split), len(mine)))
    print("  of mine, %d are in the blocking set and %d are not."
          % (sum(1 for r in mine if r[0] in blocking), sum(1 for r in mine if r[0] not in blocking)))
    unsafe = [r[0] for r in mine if not r[5]]
    print("  PIN-UNSAFE (does not unset SCRIP_HEAP_KB, so an outer KB defeats the pin -- gc_heap.c:191-192): %d of %d"
          % (len(unsafe), len(mine)))
    if ambiguous:
        print("  ⛔ AMBIGUOUS, counted in NEITHER half and NOT swept until read by hand (%d): %s"
              % (len(ambiguous), " ".join(ambiguous)))
    print("population: %d gate(s) examined, %d pinned, %d mine" % (len(gates), len(rows), len(mine)))
    print("=" * 118)
    return 0

# ⛔⭐ THE SELFTEST, AND THE REASON IT EXISTS IS THAT THIS FILE DID NOT HAVE ONE.  The MB1 form regex read three of
# the four POSIX default operators and the census under-reported its own population by two gates for as long as it
# existed.  Nothing caught it, because a census with no planted witness can only be checked against the tree it is
# measuring -- and the tree is exactly what is in dispute.  So: ONE PLANTED WITNESS PER SPELLING, plus the negative
# controls that make a green mean something (a 512 pin and a 10 pin are NOT this population; a comment mention is
# not a pin; a heredoc interior is AMBIGUOUS and counted in neither half).  Every arm names what it expected and
# what it read.  FAIL_ONCE=1 corrupts the classifier in memory and requires the arms to GO RED -- a selftest that
# cannot fail is not a selftest (the fail-once proof this root's gates have carried since CEO-513).
SELFTEST_WITNESSES = [
    ("test_gate_zz_plain_assignment.sh",       'SCRIP_HEAP_MB=1 ./scrip w.sno\n',                      "pinned"),
    ("test_gate_zz_assign_if_unset.sh",        ': "${SCRIP_HEAP_MB:=1}"; export SCRIP_HEAP_MB\n',      "pinned"),
    ("test_gate_zz_substitute_if_unset.sh",    'export SCRIP_HEAP_MB="${SCRIP_HEAP_MB:-1}"\n',         "pinned"),
    ("test_gate_zz_substitute_no_colon.sh",    'A="${SCRIP_HEAP_MB-1}"\n',                             "pinned"),
    ("test_gate_zz_shipped_pin_is_not_ours.sh",'SCRIP_HEAP_MB=512 ./scrip w.sno\n',                    "clean"),
    ("test_gate_zz_ten_is_not_one.sh",         'SCRIP_HEAP_MB=10 ./scrip w.sno\n',                     "clean"),
    ("test_gate_zz_kb_pin_is_the_cure.sh",     'env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=64 ./scrip w.sno\n',"clean"),
    ("test_gate_zz_comment_only.sh",           '# once pinned at SCRIP_HEAP_MB=1, converted 2026-09-22\n', "comment"),
    ("test_gate_zz_heredoc_interior.sh",       'cat <<EOF\nSCRIP_HEAP_MB=1\nEOF\n',                    "ambiguous"),
    ("test_gate_zz_pin_safe.sh",               'env -u SCRIP_HEAP_KB SCRIP_HEAP_MB=1 ./scrip w.sno\n', "pinned-safe"),
    ("test_gate_zz_printf_fixture_content.sh", "printf '\"\"\"mentions SCRIP_HEAP_MB=1\"\"\"\\n' > f.py\n",  "ambiguous"),
    ("test_gate_zz_quoted_env_word.sh",        "env -u SCRIP_HEAP_KB 'SCRIP_HEAP_MB=1' ./scrip w.sno\n", "pinned"),
]


def selftest():
    import tempfile
    fail_once = os.environ.get("FAIL_ONCE") == "1"
    if fail_once:
        global MB1
        MB1 = re.compile(r'SCRIP_HEAP_MB\s*=\s*"?\'?1"?\'?(?![0-9])')   # the narrow regex THAT SHIPPED, restored on purpose
    d = tempfile.mkdtemp(prefix="arena_pin_selftest."); __import__("atexit").register(__import__("shutil").rmtree, d, True)
    for name, text, _ in SELFTEST_WITNESSES:
        open(os.path.join(d, name), "w", encoding="utf-8").write("#!/usr/bin/env bash\n" + text)
    try: _g, rows, ambiguous, mentions = scan(d)
    except Unreadable as e:
        print("⛔ REFUSE(2): %s" % e); return 2
    pinned = {r[0]: r for r in rows if r[1]}          # a code-line hit
    ambig  = set(ambiguous)
    ment   = {g for g, _ in mentions}
    bad = 0
    print("  SELFTEST -- one planted witness per spelling, classified by the SAME scan() the census runs%s"
          % ("  [FAIL_ONCE: the shipped narrow regex is restored, the := arm MUST go red]" if fail_once else ""))
    for name, _text, want in SELFTEST_WITNESSES:
        if   want == "pinned":      got = "pinned" if name in pinned else ("comment" if name in ment else ("ambiguous" if name in ambig else "clean"))
        elif want == "pinned-safe": got = "pinned-safe" if (name in pinned and pinned[name][5]) else ("pinned-UNSAFE" if name in pinned else "clean")
        elif want == "ambiguous":   got = "ambiguous" if name in ambig else ("pinned" if name in pinned else "clean")
        elif want == "comment":     got = "comment" if name in ment else ("pinned" if name in pinned else "clean")
        else:                       got = "pinned" if name in pinned else ("comment" if name in ment else "clean")
        ok = (got == want)
        if not ok: bad += 1
        print("    %-4s %-42s want %-13s read %s" % ("ok" if ok else "RED", name[len("test_gate_zz_"):-3], want, got))
    if fail_once:
        if bad: print("  SELFTEST FAIL-ONCE PROVED: %d arm(s) went red under the shipped narrow regex, so these arms can fail" % bad); return 0
        print("  ⛔ SELFTEST FAIL-ONCE DID NOT TRIP -- the arms cannot distinguish the narrow regex from the wide one, so a green here proves nothing"); return 1
    print("  SELFTEST: %d arm(s), %d red" % (len(SELFTEST_WITNESSES), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    if "--selftest" in sys.argv[1:]: sys.exit(selftest())
    sys.exit(main())
