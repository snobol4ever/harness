#!/usr/bin/env python3
"""util_skill_check.py <name>... -- A FLEET SKILL IS WELL-FORMED AND CARRIES ITS SEVEN PARTS (ceo CEO-2071). Reads .github/skills/<name>/SKILL.md
beside this harness. GREEN rc 0 when the file exists, opens with YAML frontmatter whose `name:` equals the folder and whose `description:` is 40 to
1024 characters, is 3 to 40 KB, and carries the seven section markers a seat needs: the oracle (## 1), the manuals under /home/resources/manuals
(## 2), the source map (## 3), the ARCH pages (## 4), the suites and their runners (## 5), the debugging order (## 6) and the rulings (## 7).
RED rc 1 names each missing part. REFUSE rc 2 with no name. The DONE-WHEN of every skill row; red on an absent skill by construction.
"""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
MARKS = ["## 1", "## 2", "## 3", "## 4", "## 5", "## 6", "## 7", "/home/resources/manuals", "ARCH-", "harness/scripts", "monitor_run.sh"]
def check(name):
    p = os.path.join(ROOT, ".github", "skills", name, "SKILL.md")
    if not os.path.exists(p):
        return ["no file %s" % p]
    t = open(p, encoding="utf-8").read()
    why = []
    m = re.match(r"---\n(.*?)\n---\n", t, re.S)
    if not m:
        why.append("no frontmatter")
    else:
        fm = m.group(1)
        n = re.search(r"^name:\s*(\S+)\s*$", fm, re.M)
        d = re.search(r"^description:\s*(.+)$", fm, re.M)
        if not n or n.group(1) != name: why.append("frontmatter name != %s" % name)
        if not d or not (40 <= len(d.group(1)) <= 1024): why.append("description missing or not 40..1024 chars")
    sz = len(t.encode())
    if not (3072 <= sz <= 40960): why.append("size %d not in 3..40 KB" % sz)
    for k in MARKS:
        if k not in t: why.append("missing '%s'" % k)
    return why
def main(names):
    if not names:
        print("REFUSE(2): usage: util_skill_check.py <skill-name>..."); return 2
    rc = 0
    for n in names:
        why = check(n)
        print(("OK   %s" % n) if not why else ("RED  %s: %s" % (n, "; ".join(why))))
        rc = rc or (1 if why else 0)
    return rc
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
