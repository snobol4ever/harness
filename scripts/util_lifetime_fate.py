#!/usr/bin/env python3
"""util_lifetime_fate.py SITE... -- for each file:line allocation site, print the allocation line and every later line of the same
function (separator-delimited) that mentions the variable the allocation is assigned to, so the variable's fate --
returned, stored, handed to the program, or dropped at the end of the call -- is visible in a few lines."""
import re, sys
for site in sys.argv[1:]:
    f, n = site.rsplit(':', 1); n = int(n)
    L = open(f, encoding='utf-8', errors='replace').read().split('\n')
    a = n - 1
    while a > 0 and not (L[a - 1].startswith('/*---') or L[a - 1].startswith('/*===')): a -= 1
    b = n - 1
    while b < len(L) - 1 and not (L[b + 1].startswith('/*---') or L[b + 1].startswith('/*===')): b += 1
    line = L[n - 1]
    m = re.search(r'([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?:[^=;]*\?\s*)?(?:\([^()]*\)\s*)*(?:rt_|ct_|PL_CELL|malloc|calloc|realloc|strdup|gv_)', line)
    var = m.group(1) if m else None
    head = next((L[j] for j in range(n - 1, a - 1, -1) if re.match(r'^[A-Za-z_]', L[j])), '?')
    print('=== %s  var=%s  in: %s' % (site.replace('src/runtime/', ''), var, head.strip()[:90]))
    print('  @ ' + line.strip()[:170])
    if not var: continue
    w = re.compile(r'(?<![A-Za-z0-9_])' + re.escape(var) + r'(?![A-Za-z0-9_])')
    k = 0
    for j in range(n, b + 1):
        if w.search(L[j]):
            s = L[j].strip()
            i = w.search(s).start()
            print('    ' + s[max(0, i - 70):i + 100])
            k += 1
            if k >= 6: print('    ...'); break
