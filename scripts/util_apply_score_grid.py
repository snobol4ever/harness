#!/usr/bin/env python3
"""util_apply_score_grid.py <SCORE.md> <grid.txt> [--dry-run|--selftest]

MERGE util_build_score_md.py's stdout into SCORE.md's STANDARDIZED DISPLAY, cell by cell. It writes only the
columns the generator actually measures and leaves every other cell -- `Vendor / package suites`, and every
row's provenance -- exactly as it found them.

⛔⭐⭐ THIS SCRIPT USED TO SPLICE, AND A SPLICE IS A DELETION OF EVERYTHING IT DOES NOT REPLACE. It replaced
from the first `| Language |` header through the next `_tree: ..._` stamp, which fails in two independent
ways that compose into a file-destroying one:

  (1) BOUND BY POSITION, NOT SHAPE. SCORE.md carries TWO `| Language |` grids since ceo CEO-174 added the
      September-10 M/L/V/B grid ABOVE the standardized display. `s.index('\\n| Language |')` finds the
      SEPTEMBER-10 GRID -- not the display this script's own docstring named. Measured on the live file
      (hq_T 2026-09-04): the first header is line 57 (7 columns, the Sept-10 grid), the display is line 70
      (6 columns), and the stamp that ends the replacement is at line 81 -- so the "splice" spanned BOTH
      TABLES and would have collapsed them into one. This is precisely the position-over-shape defect that
      `util_score_row.py:find_table` was already cured of, in the sibling script, with the cure written up
      in its own comment -- and the lesson did not travel the six feet between the two files.

  (2) A NARROWER GRID SILENTLY DROPS COLUMNS. The generator emits a 4-column literal; the display is 6.

⛔⭐ THE OLD COLUMN-COUNT GUARD MADE (1) INVISIBLE BY ACCIDENTALLY MASKING IT. It compared 4 generated
columns against the FIRST header's 7 and refused -- so the script failed closed and nobody was hurt. But it
refused with a WRONG DIAGNOSIS ("the live board is 6 columns... those are Vendor and Tree"), naming a table
it was not looking at. Worse, its remedy told the reader to teach the generator the missing columns -- and
had anyone done so, the counts would have MATCHED at 7, the assert would have passed, and the splice would
have eaten both tables. A guard whose suggested fix disarms the guard is not a guard. ⭐ The general form:
a fail-closed check standing in front of a second, unrelated defect reports its own condition and conceals
the other one, and the concealment is strongest exactly when the check looks like it is working.

Merging removes the need for that guard entirely: a column this script cannot MAP BY NAME is never written,
so a narrow grid can no longer delete a wide one. Columns are matched by NAME against the display's own
header, never by index, so the two tables may grow columns independently.
"""
import sys, os, re, time, importlib.util

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("_usr", os.path.join(HERE, "util_score_row.py"))
_usr = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_usr)


def norm(name):
    # Compare column names the way a reader does: case-insensitively, ignoring any parenthesised gloss and
    # the spacing around a slash. `Floor/smoke gate` (generator) and `Floor / smoke gate` (display) are one
    # column; `Rungs suite (\`ALL.csv\`)` and `Rungs suite` are one column. Matching on the raw string
    # would make this script refuse over a space, and matching on the index is what (1) above already cost.
    n = name.split("(")[0]
    n = re.sub(r"`[^`]*`", "", n).strip().lower()
    n = re.sub(r"\s*/\s*", "/", n)
    return re.sub(r"\s+", " ", n)


def load_grid(text):
    lines = [l for l in text.strip("\n").split("\n") if l.startswith("|")]
    if len(lines) < 3:
        _usr.die("generated grid has no data rows -- refusing to merge an empty measurement")
    hdr = [c.strip() for c in lines[0].strip().strip("|").split("|")]
    rows = {}
    for l in lines[2:]:
        c = [x.strip() for x in l.strip().strip("|").split("|")]
        if len(c) == len(hdr):
            rows[c[0]] = c
    return hdr, rows


def apply_grid(score_md, grid_text, stamp, dry_run=False):
    _usr.SCORE_MD = score_md
    lines = open(score_md, encoding="utf-8").read().split("\n")
    hdr_i, disp, disp_skip = _usr.find_table(lines)   # ⭐ BY SHAPE. Never `index('| Language |')` -- see (1).
    # ⛔⭐ THIS SCRIPT SPLICES BY POSITION, SO A ROW IT COULD NOT READ IS THE ONE THING IT MUST NOT WALK PAST.
    # find_table skips any row whose column count is not the table's, and a skipped row is INVISIBLE here --
    # the merge would simply not carry that language and would report success, which is how a measurement
    # goes missing quietly. Refuse instead: a malformed row is a one-line repair, a silently unmerged
    # language is a wrong board nobody can see.
    if disp_skip:
        _usr.die("refusing to splice into a table with %d malformed row(s) -- %s. Repair the '|' count first; "
                 "splicing by position into a table that could only be PARTLY read is how a language silently "
                 "stops being merged." % (len(disp_skip),
                 ", ".join("%s at line %d has %d columns, the table has %d"
                           % (l, i + 1, n, _usr.PROV_COL + 1) for l, (i, n) in sorted(disp_skip.items()))))
    disp_hdr = [c.strip() for c in lines[hdr_i].strip().strip("|").split("|")]
    g_hdr, g_rows = load_grid(grid_text)
    # Map generated column -> display column BY NAME, and say out loud which generated columns are not
    # carried. A column the display does not have is not an error (the two tables may diverge); it is
    # simply not merged, and silence about it is how a measurement gets lost.
    by_name = {norm(c): i for i, c in enumerate(disp_hdr)}
    mapping, unmapped = {}, []
    for gi, gname in enumerate(g_hdr):
        if gi == 0:
            continue
        di = by_name.get(norm(gname))
        (mapping.setdefault(gi, di) if di is not None else unmapped.append(gname))
        if di is None:
            mapping.pop(gi, None)
    if not mapping:
        _usr.die("no generated column maps onto the standardized display by name -- generated %s, display %s"
                 % ([norm(c) for c in g_hdr[1:]], [norm(c) for c in disp_hdr[1:]]))
    # Which display column each mapped index is, in util_score_row's own --column vocabulary, so the
    # provenance clause this writes is the same clause a runner's own `write` would have written.
    col_of_idx = {idx: key for key, (idx, _e) in _usr.COLUMNS.items()}
    changed, skipped, prose_at_risk = [], [], []
    for lang, gcells in sorted(g_rows.items()):
        if lang not in disp:
            skipped.append(lang)
            continue
        row_i, cells = disp[lang]
        touched = []
        for gi, di in sorted(mapping.items()):
            new = gcells[gi].strip()
            if not new or new == cells[di].strip():
                continue
            # ⛔ SAME GUARD AS util_score_row.py:cmd_write, same reason -- a cell overwrite here is just as
            # wholesale (`cells[di] = new`) and just as capable of silently discarding hand-written prose it
            # never modelled (task score-md-runners-rewrite-a-cell-in-place-and-silently-discard-the-...).
            # A merge covers many rows in one call, so ONE risky cell must not abort the rest of the batch:
            # skip that cell only, leave it exactly as it was, and report it the same way `unmapped`/
            # `skipped` already are -- non-fatally, but never silently.
            lost = _usr.cell_prose_loss(cells[di], new)
            if lost:
                prose_at_risk.append("%s %s: %d sentence(s) would be discarded: %s"
                                      % (lang, col_of_idx.get(di, disp_hdr[di]), len(lost), " | ".join(lost)))
                continue
            cells[di] = new
            touched.append(col_of_idx.get(di, disp_hdr[di]))
        if not touched:
            continue
        # ⛔ PROVENANCE FOLLOWS THE NUMBER OR THE NUMBER IS UNFALSIFIABLE. Every column this rewrote gets
        # its own clause restamped; columns it did not touch keep theirs, which is the whole point of
        # merging rather than splicing.
        for key in touched:
            if key in _usr.COLUMNS:
                cells[_usr.PROV_COL] = _usr.merge_prov(cells[_usr.PROV_COL], key, stamp)
        lines[row_i] = "| " + " | ".join(cells) + " |"
        changed.append("%s (%s)" % (lang, ", ".join(touched)))
    if unmapped:
        print("  not merged (no such column on the display): %s" % ", ".join(unmapped))
    if skipped:
        print("  not on the display, left alone: %s" % ", ".join(skipped))
    if prose_at_risk:
        print("⛔ NOT MERGED (would silently discard hand-written prose this generator never modelled):")
        for p in prose_at_risk:
            print("    " + p)
        print("    Fold it into the generator's own text, or write that cell by hand instead -- rc=1 below"
              " marks this run incomplete even where every other cell merged cleanly.")
    if not changed:
        if prose_at_risk:
            return 1
        print("merged: nothing to change -- every generated cell already matches the display")
        return 0
    if dry_run:
        print("DRY-RUN merged %d row(s): %s" % (len(changed), "; ".join(changed)))
        return 1 if prose_at_risk else 0
    open(score_md, "w", encoding="utf-8").write("\n".join(lines))
    print("merged %d row(s) in place: %s" % (len(changed), "; ".join(changed)))
    print("⛔ NOT DONE UNTIL PUSHED: commit .github/SCORE.md with the landing that carried this measurement.")
    return 1 if prose_at_risk else 0


def selftest():
    # ⛔⭐ THE ARM THAT MATTERS IS THE ONE THE OLD SCRIPT WOULD HAVE FAILED: a grid NARROWER than the
    # display must leave the untouched columns -- vendor and provenance -- byte-identical. The old splice
    # deleted them; the column guard only ever refused, which is not the same as being able to do the job.
    import tempfile, shutil
    ok = True
    d = tempfile.mkdtemp(prefix="apply_score_grid.selftest.")
    try:
        real = os.path.join(os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP"), "..", ".github", "SCORE.md")
        real = os.path.abspath(real)
        if not os.path.exists(real):
            print("SELFTEST REFUSED: no SCORE.md at %s -- cannot prove a merge against the real shape" % real)
            return 2
        tmp = os.path.join(d, "SCORE.md")
        shutil.copy(real, tmp)
        before = open(tmp, encoding="utf-8").read().split("\n")
        _usr.SCORE_MD = tmp
        hdr_i, disp, _ = _usr.find_table(before)
        dhdr = [c.strip() for c in before[hdr_i].strip().strip("|").split("|")]
        # A deliberately NARROW grid (Language + Rungs board only), in the generator's own spacing.
        lang = sorted(disp)[0]
        # ⛔ SEED A KNOWN, PROSE-FREE CELL FIRST. The live board column for whichever language sorts first
        # (currently icon) carries real hand-written prose, and this selftest's own claim -- "the mapped
        # column WAS written" -- has never depended on what that cell started as, only on the merge landing.
        # Left un-seeded, cell_prose_loss below would (correctly) skip the write and fail this proof for a
        # reason unrelated to what it is proving. Mirrors the identical seed in util_score_row.py:selftest.
        bi0 = _usr.COLUMNS["board"][0]
        before[disp[lang][0]] = "| " + " | ".join(
            [("—" if i == bi0 else c) for i, c in enumerate(
                [x.strip() for x in before[disp[lang][0]].strip().strip("|").split("|")])]) + " |"
        open(tmp, "w", encoding="utf-8").write("\n".join(before))
        before = open(tmp, encoding="utf-8").read().split("\n")
        grid = ("| Language | Rungs board (`ALL.<ext>` via `corpus_suite_harness.py run`, m3 · m4) |\n"
                "|---|---|\n| %s | SELFTEST-BOARD-VALUE |\n" % lang)
        apply_grid(tmp, grid, "SELFTEST-STAMP")
        after = open(tmp, encoding="utf-8").read().split("\n")
        if len(after) != len(before):
            print("SELFTEST FAIL: line count moved %d -> %d; a merge must never add or drop lines"
                  % (len(before), len(after))); ok = False
        else:
            print("SELFTEST: merge left the line count unchanged")
        _b = [c.strip() for c in before[disp[lang][0]].strip().strip("|").split("|")]
        _a = [c.strip() for c in after[disp[lang][0]].strip().strip("|").split("|")]
        if len(_a) != len(_b):
            print("SELFTEST FAIL: row width moved %d -> %d columns" % (len(_b), len(_a))); ok = False
        else:
            print("SELFTEST: row kept all %d columns (a splice would have left %d)" % (len(_a), 2))
        bi = _usr.COLUMNS["board"][0]
        if _a[bi] != "SELFTEST-BOARD-VALUE":
            print("SELFTEST FAIL: the mapped board column was not written -- got %r" % _a[bi]); ok = False
        else:
            print("SELFTEST: the one mapped column WAS written, matched by name not by index")
        vi = _usr.COLUMNS["vendor"][0]
        if _a[vi] != _b[vi]:
            print("SELFTEST FAIL: the vendor column changed and nothing measured it"); ok = False
        else:
            print("SELFTEST: the unmeasured vendor column is byte-identical -- merge, not splice")
        if "SELFTEST-STAMP" not in _a[_usr.PROV_COL]:
            print("SELFTEST FAIL: provenance was not restamped for the column that changed"); ok = False
        elif not all(c in _a[_usr.PROV_COL] for c in
                     [x.split(":")[0] for x in _b[_usr.PROV_COL].split(";") if ":" in x and "board" not in x.split(":")[0]]):
            print("SELFTEST FAIL: restamping board dropped another column's provenance clause"); ok = False
        else:
            print("SELFTEST: board provenance restamped, every other clause preserved")
        # ⛔⭐ CELL PROSE LOSS -- this file's OWN wholesale overwrite site (`cells[di] = new`) needs proving
        # here, not only in util_score_row.py: the two functions share no call path, only the shared
        # `_usr.cell_prose_loss` helper, so a regression in either file's call site would go unnoticed by
        # the other's gate.
        _seed = "SELFTEST-BOARD-VALUE. Re-confirmed by a human on a later tree: still true, unrelated run."
        _sl = open(tmp, encoding="utf-8").read().split("\n")
        _sh2, _sd2, _ = _usr.find_table(_sl)
        _sl[_sd2[lang][0]] = "| " + " | ".join(
            [(_seed if i == bi else c) for i, c in enumerate(
                [x.strip() for x in _sl[_sd2[lang][0]].strip().strip("|").split("|")])]) + " |"
        open(tmp, "w", encoding="utf-8").write("\n".join(_sl))
        grid2 = ("| Language | Rungs board (`ALL.<ext>` via `corpus_suite_harness.py run`, m3 · m4) |\n"
                 "|---|---|\n| %s | SELFTEST-BOARD-VALUE |\n" % lang)
        rc2 = apply_grid(tmp, grid2, "SELFTEST-STAMP-2")
        _cl = open(tmp, encoding="utf-8").read().split("\n")
        _ch2, _cd2, _ = _usr.find_table(_cl)
        _cc = [x.strip() for x in _cl[_cd2[lang][0]].strip().strip("|").split("|")]
        if rc2 != 1:
            print("SELFTEST FAIL: apply_grid returned %r merging over hand-written prose, wanted 1" % rc2); ok = False
        elif _cc[bi] != _seed:
            print("SELFTEST FAIL: apply_grid overwrote the cell despite detecting prose loss -- got %r" % _cc[bi]); ok = False
        else:
            print("SELFTEST: apply_grid correctly skipped a cell that would have discarded hand-written prose (rc=1)")
        # The other table must be untouched -- this is defect (1), pinned so it cannot come back.
        heads_b = [i for i, l in enumerate(before) if l.startswith("| Language |")]
        heads_a = [i for i, l in enumerate(after) if l.startswith("| Language |")]
        if heads_b != heads_a or len(heads_a) < 2:
            print("SELFTEST FAIL: the September-10 grid moved or was consumed -- %s -> %s" % (heads_b, heads_a)); ok = False
        elif before[heads_b[0]] != after[heads_a[0]] or before[heads_b[0] + 2] != after[heads_a[0] + 2]:
            print("SELFTEST FAIL: the OTHER '| Language |' grid was modified -- position-binding is back"); ok = False
        else:
            print("SELFTEST: both '| Language |' grids still present, the September-10 grid untouched")
    finally:
        shutil.rmtree(d, ignore_errors=True)
    print("SELFTEST %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


def main():
    argv = sys.argv[1:]
    if "--selftest" in argv:
        return selftest()
    argv = [a for a in argv if a != "--dry-run"]
    if len(argv) != 2:
        sys.stderr.write(__doc__ + "\n")
        return 2
    score, grid = argv
    # Same four facts, in the same order, as util_score_row.py:272 -- a row this script stamps and a row a
    # runner's own `write` stamps must be indistinguishable, or the provenance column grows two dialects.
    measurer = os.environ.get("S4E_SEAT", "").strip()
    if not measurer or measurer in _usr._PLACEHOLDER_MEASURERS:
        measurer = _usr.derive_measurer()
    if not measurer:
        _usr.die("cannot attribute this merge: S4E_SEAT is unset and the root %r is not in the seat map "
                 "-- an unattributed row is a claim with nobody behind it" % _usr.S4E)
    stamp = "%s · RT_OPT=%s · %s · %s" % (_usr.tree_stamp(), _usr.rt_opt(),
                                          time.strftime("%Y-%m-%d %H:%M %Z"), measurer)
    return apply_grid(score, open(grid, encoding="utf-8").read(), stamp, "--dry-run" in sys.argv[1:])


if __name__ == "__main__":
    raise SystemExit(main())
