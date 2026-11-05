#!/usr/bin/env bash
# s4e_ruling.sh -- FIND A RULING BY ITS NUMBER (CTO-486, COO-474, CIO-12, CEO-2041): the redirect map says where it lives
# (util_redirects.py --resolve), then the bullet whose bold head names it is printed from that file (box-scheduler step 30, CTO-496).
#   s4e_ruling.sh CTO-486     rc 0 GREEN: the ruling is found; every bullet heading it prints, with its continuation lines
#                             rc 1 RED: the series is known but no bullet heads that id in the file the map names
#                             rc 2 REFUSE: not a ruling id, no redirect row, the file is not on disk, or git cannot show a retired file
# The file is the LIVE CURSOR section when the file has one (a ruling moved out of the cursor is RED, by design: the cursor is the record).
# A bullet heads the id when the first ruling id in its bold head is the id. R-NNNN is the alias of CEO-NNNN (CIO-1).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
refuse() { echo "REFUSE(2) [s4e_ruling]: $*" >&2; exit 2; }
id="${1:-}"
[ -n "$id" ] || refuse "usage: $0 <ID>   (e.g. CTO-486)"
case "$id" in R-[0-9]*) id="CEO-${id#R-}" ;; esac
[[ "$id" =~ ^(CEO|CIO|COO|CTO|CAO|CFO|CQO)-[0-9]{1,4}$ ]] || refuse "not a ruling id: $id (want CEO|CIO|COO|CTO|CAO|CFO|CQO-NNNN)"
map="$(cd "$S4E" && python3 harness/scripts/util_redirects.py --resolve "$id" 2>&1)"; rrc=$?
[ "$rrc" = 0 ] || refuse "no redirect row for $id: $map"
read_line="$(printf '%s\n' "$map" | sed -n 's/^  read: //p' | head -1)"
[ -n "$read_line" ] || refuse "the redirect row for $id has no read line: $map"
gitsrc="$(printf '%s\n' "$read_line" | sed -n 's/.*git -C \.github show \([0-9a-f]\{4,\}\)\^:\([^ |]*\).*/\1^:\2/p')"
if [ -n "$gitsrc" ]; then
    where="git .github show $gitsrc"
    git -C "$S4E/.github" show "$gitsrc" >/dev/null 2>&1 || refuse "git cannot show $gitsrc for $id"
    src=(git -C "$S4E/.github" show "$gitsrc")
else
    file="$(printf '%s\n' "$read_line" | awk '{print $NF}')"
    [ -f "$S4E/$file" ] || refuse "the redirect map names $file for $id and it is not on disk"
    where="$file"
    src=(cat "$S4E/$file")
fi
PY="$(cat <<'PYEOF'
import re, sys
ident, where = sys.argv[1], sys.argv[2]
text = sys.stdin.read().split("\n")
lo, hi, cursor = 0, len(text), False
for i, l in enumerate(text):
    if l.startswith("## LIVE CURSOR"):
        lo, cursor = i + 1, True
        for j in range(lo, len(text)):
            if text[j].startswith("## "):
                hi = j
                break
        break
ID = re.compile(r"\b(?:CEO|CIO|COO|CTO|CAO|CFO|CQO)-\d{1,4}\b")
hits = []
for i in range(lo, hi):
    l = text[i]
    if not l.startswith("- **"):
        continue
    m = re.match(r"- \*\*(.*?)\*\*", l)
    head = m.group(1) if m else l[4:]
    ids = ID.findall(head)
    if ids and ids[0] == ident:
        j = i + 1
        while j < hi and text[j].strip() and not text[j].startswith("- ") and not text[j].startswith("#"):
            j += 1
        hits.append((i + 1, text[i:j]))
scope = where + (" (LIVE CURSOR)" if cursor else " (whole file)")
if not hits:
    print("NOT-FOUND %s: no bullet heads it in %s" % (ident, scope))
    sys.exit(1)
print("RULING %s found in %s heads=%d" % (ident, scope, len(hits)))
for ln, body in hits:
    print("  line %d" % ln)
    for b in body:
        print(b)
sys.exit(0)
PYEOF
)"
"${src[@]}" | python3 -c "$PY" "$id" "$where"
exit $?
