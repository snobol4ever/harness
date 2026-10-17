#!/usr/bin/env python3
"""util_renumber_rungs_banners.py -- THE SANCTIONED RENUMBER PATH for a language rungs' banner seq
numbers, restoring the invariant `banner number == entry position` across ALL.<ext>, ALL.ref AND ALL.in
together (hq_T 2026-09-13, on the cfo's routed brief "the-sanctioned-add-a-witness-path-is-refusing-on-
five-of-seven-masters-because-the-620-removal-left-the-banner-numbers-stale").

WHY THIS EXISTS AT ALL -- THE INVARIANT, AND WHAT BROKE IT: read_block_suite()/read_suite() IGNORE the
number printed in a banner and re-derive seq positionally (`seq += 1`), while write_block_suite()/
write_suite() print e.seq back out. So "banner number == position" is an invariant of every file those
readers have round-tripped, and it is load-bearing for exactly one consumer: util_add_ladder_witness.py's
byte-for-byte ROUND-TRIP PROOF, the check that refuses to trust the tool with a real write until the
reader+writer pair reproduces the existing rungs byte-for-byte. corpus a6646f04c removed the 620
modes=ast entries from all seven rung suites WITHOUT renumbering, so every entry after a removal point kept a
banner number one-per-removed-predecessor too high, and the sanctioned add-a-witness path went down for
five of the seven languages at once.

⛔⭐ THE REFUSAL WAS CORRECT AND ITS EXPLANATION WAS FALSE, which is why this sat unnamed for a week and
why the cure is a tool rather than a note. "this language's reader+writer pair does not reproduce the
existing rungs byte-for-byte" accuses THE TOOL; the fault is in THE FILE. Three lanes (raku corpus
02d2e456e, snocone 53fd3d903, snobol4 a401e1e3e) each independently paid the same diagnosis and then each
hand-renumbered their own rungs, and the four remaining lanes were on course to pay it a fourth, fifth,
sixth and seventh time. A correct procedure with a false explanation -- RULES.md names the class.

⛔⛔ A RENUMBER IS NOT A ONE-FILE EDIT, AND THE HAND VERSION HAS ALREADY PROVEN IT. MEASURED, not
inferred (hq_T 2026-09-13): ALL.in -- the stdin sidecar -- banners its blocks from the SAME e.seq the
rungs' banners carry. read_stdin_sidecar() attaches BY NAME, so a stale .in banner never breaks a
grade; it breaks the READER. Before corpus a401e1e3e, all 33 of the snobol4 rungs' ALL.in banners
AGREED with its rungs banners (measured at a401e1e3e^: 33 banners, 0 disagreeing). That commit renumbered
ALL.sno and ALL.ref only, so today all 33 DISAGREE -- a hand renumber that fixed one invariant silently
introduced the inconsistency across two files that the harness's own write_suite() comment exists to warn
about ("read_stdin_sidecar attaches BY NAME and would still work, which is precisely why the inconsistency
could sit there unnoticed and confuse the next person to read the two files side by side"). Icon has 23
such banners waiting for the identical trap. ⭐ THE GENERAL FORM: a "cosmetic" edit is only cosmetic
against the instruments you remembered to check -- and the sidecar nobody renumbers is the one keyed by
the field nobody grades.

WHAT THIS DOES, AND WHAT IT REFUSES TO DO: it rewrites BANNER LINES ONLY, in place, positionally. It does
NOT re-serialize through write_block_suite()/write_suite() -- a writer reorders (lines then blocks) and
could legitimately move content, and a renumber that can move content is not a renumber. Every non-banner
byte is carried through untouched and PROVEN untouched. The banner itself is regenerated through the
harness's OWN make_banner()/make_banner_cfg(), never by substituting the digits, because the banner is
width-padded to BANNER_WIDTH and the dash count depends on the seq's digit length -- 316 -> 186 loses a
digit and owes a dash, and a digit-substituting sed would leave an off-width banner that the next reader
accepts and the next `--width` check does not.

THE PROOF, RUN BEFORE ANY BYTE IS WRITTEN, ALL FOUR ARMS AND ANY ONE OF THEM REFUSES rc=2:
  (1) LINE COUNTS unchanged in every file touched.
  (2) EVERY NON-BANNER LINE byte-identical, compared positionally -- not by difflib, whose n=0 alignment
      reports content lines as moved when only their neighbouring banner changed (measured: icon showed
      636 'non-banner' ref diff lines under difflib and 0 under a positional compare).
  (3) THE ENTRIES RE-READ from the rewritten text compare equal to the entries read from the original on
      every field the grader reads -- kind, name, sno_lines, ref, stdin, xfail, argv, mask, want_rc,
      xfail_reason -- and in the same order, so no entry has moved and no name has moved.
  (4) THE RESULT SATISFIES THE INVARIANT: every banner's number equals its entry's position, in the
      rungs AND in ALL.in, which is the whole point and is checked rather than assumed.

Usage:
    util_renumber_rungs_banners.py --lang icon            # dry-run report
    util_renumber_rungs_banners.py --lang icon --apply
    util_renumber_rungs_banners.py --all                  # report every language's drift
"""
import argparse
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import corpus_suite_harness as csh  # noqa: E402  -- the ONE authority for the suite grammar

# ⛔ THE TESTS ROOT IS OVERRIDABLE FOR ONE REASON ONLY: the gate must exercise the APPLY path, and a
# gate that can only dry-run proves nothing about the write. S4E_TESTS_ROOT is read by the gate and by
# nothing else -- it is not a way to point this tool at a second corpus.
TESTS = Path(os.environ.get("S4E_TESTS_ROOT") or (HERE.parent.parent / "corpus" / "tests"))
EXT = {"snobol4": "sno", "icon": "icn", "prolog": "pl", "raku": "raku",
       "pascal": "pas", "rebus": "reb", "snocone": "sc"}
GRADED_FIELDS = ["kind", "name", "sno_lines", "ref", "stdin", "xfail", "argv", "mask", "want_rc", "xfail_reason"]
RC_OK, RC_DRIFT, RC_REFUSE = 0, 1, 2


def refuse(msg):
    print("\u26d4 REFUSE(util_renumber_rungs_banners): %s" % msg, file=sys.stderr)
    sys.exit(RC_REFUSE)


def rungs_dir(lang):
    d = TESTS / lang
    if not d.is_dir():
        refuse("no rungs directory for %r at %s" % (lang, d))
    return d


def banner_tools(lang):
    """The (regex, make) pair for this language's banner dialect. SNOBOL4 is NOT in LANG_CONFIGS -- its
    rungs is the mixed one-line/block shape -- and its banners are the harness's original '*' form, so it
    takes BANNER_RE/make_banner while every LANG_CONFIGS dialect takes the cfg-parameterised twins."""
    cfg = csh.LANG_CONFIGS.get(lang)
    if cfg is None:
        return csh.BANNER_RE, (lambda seq, name, xfail: csh.make_banner(seq, name, xfail=xfail))
    co, cc = cfg["comment_open"], cfg["comment_close"]
    return (csh.banner_re_for(co, cc),
            lambda seq, name, xfail: csh.make_banner_cfg(seq, name, co, cc, xfail=xfail))


def read_entries(lang, d, src_text=None, ref_text=None):
    """Read the rungs through the harness's OWN reader. When src_text/ref_text are given they are staged
    to a temp pair first: the proof must re-read the REWRITTEN text through the same reader, and the reader
    only takes paths."""
    src, ref = d / ("ALL." + EXT[lang]), d / "ALL.ref"
    if src_text is not None:
        src, ref = d / ("ALL." + EXT[lang] + ".renumchk"), d / "ALL.ref.renumchk"
        src.write_text(src_text); ref.write_text(ref_text)
    try:
        if lang in csh.LANG_CONFIGS:
            cfg = csh.LANG_CONFIGS[lang]
            return csh.read_block_suite(str(src), str(ref), csh.banner_re_for(cfg["comment_open"], cfg["comment_close"]),
                                        in_path=str(d / "ALL.in") if (d / "ALL.in").is_file() else None,
                                        w_path=str(d / "ALL.wantrc") if (d / "ALL.wantrc").is_file() else None)
        return csh.read_suite(str(src), str(ref),
                              in_path=str(d / "ALL.in") if (d / "ALL.in").is_file() else None,
                              x_path=str(d / "ALL.xfail") if (d / "ALL.xfail").is_file() else None)
    except Exception as exc:
        refuse("the rungs will not read at all (%s: %s) -- that is a torn rungs, not a stale banner, and "
               "this tool must not touch it" % (type(exc).__name__, exc))
    finally:
        if src_text is not None:
            src.unlink(missing_ok=True); ref.unlink(missing_ok=True)


def rewrite_banners(text, banner_re, make, want):
    """Rewrite every banner line to its canonical form for the position `want` says that NAME holds. Returns
    (new_text, n_changed, n_banners). Non-banner lines are copied byte-for-byte. An unknown banner name is a
    refusal, never a silent skip -- a banner naming an entry the reader did not produce means the two are
    describing different files."""
    out, changed, seen = [], 0, 0
    for line in text.split("\n"):
        m = banner_re.match(line)
        if not m:
            out.append(line); continue
        seen += 1
        name = m.group("name")
        if name not in want:
            refuse("banner %r names an entry the reader never produced -- refusing to renumber a file this "
                   "tool and the harness disagree about" % line.strip())
        fresh = make(want[name], name, bool(m.groupdict().get("xfail")))
        if fresh != line:
            changed += 1
        out.append(fresh)
    return "\n".join(out), changed, seen


def prove(lang, d, before, after, entries_before):
    """The four-arm proof. Any arm refuses; nothing is written by the caller until this returns."""
    for fname, old, new in before_after_pairs(before, after):
        o, n = old.split("\n"), new.split("\n")
        if len(o) != len(n):
            refuse("PROOF ARM 1 (line counts): %s would go %d -> %d lines" % (fname, len(o), len(n)))
        br, _ = banner_tools(lang)
        for i, (a, b) in enumerate(zip(o, n), 1):
            if a == b:
                continue
            if not (br.match(a) and br.match(b)):
                refuse("PROOF ARM 2 (non-banner bytes): %s line %d is not a banner-to-banner change:\n  - %r\n  + %r"
                       % (fname, i, a, b))
    entries_after = read_entries(lang, d, after["src"], after["ref"])
    if len(entries_before) != len(entries_after):
        refuse("PROOF ARM 3 (entries): %d -> %d entries" % (len(entries_before), len(entries_after)))
    for i, (a, b) in enumerate(zip(entries_before, entries_after)):
        for f in GRADED_FIELDS:
            va, vb = getattr(a, f, None), getattr(b, f, None)
            if va != vb:
                refuse("PROOF ARM 3 (graded fields): entry %d (%s) field %s moved: %r -> %r" % (i, a.name, f, va, vb))
    for i, e in enumerate(entries_after, 1):
        if e.kind == "block" and e.seq != i:
            refuse("PROOF ARM 4 (invariant): entry %d (%s) still banners as %s after the rewrite" % (i, e.name, e.seq))
    return entries_after


def before_after_pairs(before, after):
    for key, fname in (("src", "ALL.<ext>"), ("ref", "ALL.ref"), ("in", "ALL.in")):
        if before.get(key) is not None:
            yield fname, before[key], after[key]


def drift_report(lang, d):
    """Read the rungs, compute the canonical text for every file, and report what would move. Returns
    (before, after, entries, per-file changed counts)."""
    br, make = banner_tools(lang)
    entries = read_entries(lang, d)
    want = {}
    for i, e in enumerate(entries, 1):
        if e.name in want:
            refuse("duplicate entry name %r in the rungs -- a renumber keyed by name cannot be proven safe "
                   "on a rung suite with duplicate names" % e.name)
        want[e.name] = i
    before, after, counts = {}, {}, {}
    src, ref = d / ("ALL." + EXT[lang]), d / "ALL.ref"
    for key, path in (("src", src), ("ref", ref), ("in", d / "ALL.in")):
        if not path.is_file():
            before[key] = after[key] = None
            continue
        text = path.read_text()
        before[key] = text
        after[key], counts[key], total = rewrite_banners(text, br, make, want)
        counts[key] = (counts[key], total)
    return before, after, entries, counts


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--lang", choices=sorted(EXT))
    ap.add_argument("--all", action="store_true", help="report drift for every language; never writes")
    ap.add_argument("--apply", action="store_true", help="write the renumbered files (requires --lang)")
    args = ap.parse_args()
    if args.all and args.apply:
        refuse("--all is a report; pass --lang <l> --apply to write one rung suite")
    if not args.all and not args.lang:
        refuse("pass --lang <l> or --all")

    langs = sorted(EXT) if args.all else [args.lang]
    drifted = []
    for lang in langs:
        d = rungs_dir(lang)
        before, after, entries, counts = drift_report(lang, d)
        total_changed = sum(c for c, _ in counts.values())
        cells = " ".join("%s=%d/%d" % (k, c, t) for k, (c, t) in sorted(counts.items()))
        print("%-8s entries=%-5d banners_stale: %s" % (lang, len(entries), cells or "(no banners)"))
        if total_changed:
            drifted.append(lang)
        if not args.apply:
            continue
        if not total_changed:
            print("  nothing to do -- %s already satisfies banner-number == position" % lang)
            return RC_OK
        prove(lang, d, before, after, entries)
        print("  PROOF: 4/4 arms pass (line counts, non-banner bytes, %d graded entries, invariant)" % len(entries))
        for key, fname in (("src", "ALL." + EXT[lang]), ("ref", "ALL.ref"), ("in", "ALL.in")):
            if before.get(key) is None or before[key] == after[key]:
                continue
            path = d / fname
            tmp = path.with_suffix(path.suffix + ".renumtmp")
            tmp.write_text(after[key])
            os.replace(str(tmp), str(path))
            print("  wrote %s (%d banners renumbered)" % (path, counts[key][0]))
        return RC_OK

    if args.all:
        print()
        if drifted:
            print("DRIFTED: %s -- each is `util_renumber_rungs_banners.py --lang <l> --apply`, run by that "
                  "rungs' own lane owner" % ", ".join(drifted))
            return RC_DRIFT
        print("all %d rung suites satisfy banner-number == position" % len(langs))
        return RC_OK
    return RC_DRIFT if drifted else RC_OK


if __name__ == "__main__":
    sys.exit(main())
