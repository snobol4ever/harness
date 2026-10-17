#!/usr/bin/env python3
"""Census (and with --fix, repair) batons that carry BOTH a real DONE-WHEN and the mint placeholder.

WHY THIS EXISTS. `s4e_msg.sh mint` wrote the placeholder DONE-WHEN line UNCONDITIONALLY, right under
`GOAL: $goal` -- so every mint that supplied a real criterion inline, which is what the ceo asks
minters to do, produced a baton with TWO DONE-WHEN lines. The two readers of that file then disagree:
the extractor takes the FIRST (the real one, so closes worked), while a human reading down the file
takes the LAST and is told the row can never be closed. hq_I hit exactly that on a row hq_B minted for
them, 2026-09-06. The mint side is fixed; this repairs the batons already on disk.

WHAT IT WILL NOT DO. It never removes a placeholder that is the file's ONLY DONE-WHEN -- those rows
genuinely have no criterion and the placeholder is the true statement about them. It refuses rather
than guessing if the tasks directory is unreadable: a census that cannot see its population must never
print 0.
"""
import os, sys
PLACEHOLDER_PREFIX = "DONE-WHEN: ⛔ MUST BE MADE RUNNABLE"
def main():
    fix = "--fix" in sys.argv[1:]
    d = os.environ.get("S4E_POST", "/home/resources/postoffice") + "/tasks"
    if not os.path.isdir(d):
        print("⛔ REFUSES (rc=2): %s is not a directory -- cannot measure" % d); return 2
    try:
        names = sorted(n for n in os.listdir(d) if n.endswith(".task.md"))
    except OSError as e:
        print("⛔ REFUSES (rc=2): cannot list %s (%s)" % (d, e)); return 2
    if not names:
        print("⛔ REFUSES (rc=2): no .task.md files under %s -- a census that cannot see its population must not print 0" % d); return 2
    dbl = placeholder_only = repaired = 0
    for n in names:
        p = os.path.join(d, n)
        try:
            lines = open(p, encoding="utf-8").read().split("\n")
        except OSError as e:
            print("⛔ REFUSES (rc=2): cannot read %s (%s)" % (p, e)); return 2
        idx = [i for i, l in enumerate(lines) if l.startswith("DONE-WHEN:")]
        ph = [i for i in idx if lines[i].startswith(PLACEHOLDER_PREFIX)]
        real = [i for i in idx if i not in ph]
        if ph and not real:
            placeholder_only += 1; continue
        if not ph:
            continue
        dbl += 1
        if fix:
            keep = [l for i, l in enumerate(lines) if i not in ph]
            open(p, "w", encoding="utf-8").write("\n".join(keep))
            repaired += 1
    verb = "REPAIRED" if fix else "would repair"
    print("batons=%d | %s=%d (real criterion + leftover placeholder) | placeholder-only, left alone=%d"
          % (len(names), verb, repaired if fix else dbl, placeholder_only))
    if not fix and dbl:
        print("   run with --fix to delete the leftover placeholder line in those %d" % dbl)
    return 0
if __name__ == "__main__":
    sys.exit(main())
