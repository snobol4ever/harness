#!/usr/bin/env python3
"""util_rungs_content_diff.py -- compare two rungs suites by ENTRY IDENTITY AND CONTENT, not by file bytes.

⛔⭐ WHY THIS EXISTS, AND IT IS A REPAIR TO A PROCEDURE I WROTE MYSELF (hq_C, 2026-08-30).
Law 2's cut-over clause says a cut-over language re-verifies a guard change by BUILDING INTO A SCRATCH TREE
AND DIFFING, never by deleting in place. I landed that procedure in util_build_rungs_suite.py's header.
⛔ IT CANNOT BE EXECUTED AS WRITTEN, because a plain `diff` of the two trees is unreadable:

  MEASURED, snobol4, corpus 5a48a5d5 -- scratch rebuild vs the committed rungs:
      ALL.sno   1438 changed lines      ALL.csv  2632      ALL.xfail  152
  and the CONTENT was IDENTICAL: 1726 entries both sides, 0 lost, 0 gained, 0 bodies differing,
  xfail 77/77 with 76 reasons each.

  THE CAUSE: `seq` is a POSITIONAL index and the rebuild's ordering differs from the committed file's.
  `code_eval_replace_1` sits at seq 1659 in the committed rungs and seq 987 in the rebuild; 694 of 1726
  entries shift by exactly +1 to accommodate, rewriting their banners and their CSV rows. Banner counts
  are identical (908/908). So `build(read(X))` equals X in CONTENT and differs from X in ORDER.

⭐ THE CONSEQUENCE IS THE POINT: a byte diff of a rung suite is ~3000 lines of pure renumbering, and A REAL
CHANGE IS INVISIBLE INSIDE IT. The procedure asked people to look for a needle in a haystack it generated
itself. hq_P predicted exactly this ("a 3154-line diff that would bury any real change") before the
mechanism was known; this tool is the mechanism plus the cure.

⛔ SO THE DIFF THAT VERIFIES A CUT-OVER REBUILD IS THIS ONE, NOT `diff`. It compares what the grader
actually reads -- names, bodies, refs, stdin, xfail, declared rc -- and IGNORES seq and file order, which
carry no meaning the grader consults. A difference this reports is real; a difference `diff` reports may
be nothing at all.
⚠️ AND THE FIELD LIST IS THE WHOLE CORRECTNESS OF THIS TOOL (batch-8 Law 1, and the round-trip law it
came from): a comparison that omits a field the grader reads is not a comparison. Adding a sidecar means
adding it HERE too, or this silently starts passing on a difference that matters.

EXIT: 0 identical in content · 1 differences found (a real result) · 2 could not measure.
Usage: python3 ../harness/scripts/util_rungs_content_diff.py <dirA> <dirB> [--lang snobol4] [--stem ALL]
"""
import sys, os, argparse


def refuse(msg):
    print("⛔ REFUSED(rc=2): " + msg)
    sys.exit(2)


def load(d, stem, lang, h):
    ext = {"snobol4": ".sno"}.get(lang, "." + lang[:3])
    for cand in (stem + ext, stem + ".sno", stem + ".pl", stem + ".icn", stem + ".pas", stem + ".sc", stem + ".raku", stem + ".reb"):
        src = os.path.join(d, cand)
        if os.path.isfile(src):
            break
    else:
        refuse("no %s.<ext> under %s" % (stem, d))
    ref = os.path.join(d, stem + ".ref")
    if not os.path.isfile(ref):
        refuse("no %s.ref beside %s" % (stem, src))
    kw = dict(in_path=h.sidecar_in_path(src), x_path=h.sidecar_xfail_path(src))
    if hasattr(h, "sidecar_wantrc_path"):
        kw["w_path"] = h.sidecar_wantrc_path(src)
    if lang == "snobol4":
        return h.read_suite(src, ref, **kw)
    cfg = h.LANG_CONFIGS[lang]
    return h.read_block_suite(src, ref, h.banner_re_for(cfg["comment_open"], cfg.get("comment_close", "")), **kw)


def fields(e):
    ref = e.ref if isinstance(e.ref, str) else "\n".join(e.ref or [])
    return {"body": "\n".join(e.sno_lines), "ref": ref, "stdin": e.stdin or "",
            "xfail": bool(e.xfail), "reason": e.xfail_reason or "", "want_rc": getattr(e, "want_rc", 0)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir_a"); ap.add_argument("dir_b")
    ap.add_argument("--lang", default="snobol4"); ap.add_argument("--stem", default="ALL")
    a = ap.parse_args()
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
    try:
        import corpus_suite_harness as h
    except Exception as e:
        refuse("cannot import corpus_suite_harness: %s" % e)
    for d in (a.dir_a, a.dir_b):
        if not os.path.isdir(d):
            refuse("not a directory: %s" % d)
    A = {e.name: e for e in load(a.dir_a, a.stem, a.lang, h)}
    B = {e.name: e for e in load(a.dir_b, a.stem, a.lang, h)}
    print("A: %s  %d entries" % (a.dir_a, len(A)))
    print("B: %s  %d entries" % (a.dir_b, len(B)))
    lost, gained = sorted(set(A) - set(B)), sorted(set(B) - set(A))
    changed = []
    for n in sorted(set(A) & set(B)):
        fa, fb = fields(A[n]), fields(B[n])
        d = [k for k in fa if fa[k] != fb[k]]
        if d:
            changed.append((n, d))
    print("  lost (in A, not B) : %d" % len(lost))
    print("  gained (in B, not A): %d" % len(gained))
    print("  same name, differing content: %d" % len(changed))
    for n in lost[:20]:   print("     LOST    %s" % n)
    for n in gained[:20]: print("     GAINED  %s" % n)
    for n, d in changed[:20]: print("     CHANGED %-44s fields: %s" % (n, ",".join(d)))
    for label, lst in (("lost", lost), ("gained", gained), ("changed", changed)):
        if len(lst) > 20:
            print("     ... and %d more %s (this listing is capped at 20; the counts above are complete)" % (len(lst) - 20, label))
    if lost or gained or changed:
        print("\n⛔ CONTENT DIFFERS. These are real -- seq and file order are deliberately ignored.")
        return 1
    print("\n✅ CONTENT IDENTICAL. Any byte difference between these trees is ordering/seq only and carries")
    print("   no meaning the grader reads. Do NOT commit a rebuild whose only change is that reordering:")
    print("   it buries the next real diff for no gain.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
