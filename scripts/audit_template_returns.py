#!/usr/bin/env python3
# audit_template_returns.py <file> -- prints the number of return statements beyond the first in each top-level function
# (R4: ONE return per template function, the string built from IF() terms). A lambda's own returns do not count against the
# function that holds it. Replaces the file-wide count of audit_bb_fixup_file.sh (returns beyond 2 over the whole file),
# which rose by one with every new single-return function in a file (measured 2026-10-03: bb_glue_flat.cpp 24 returns in
# 22 functions, a0599d00d's new bb_glue_prim_member raised it by one).
import re, sys
LAMBDA = re.compile(r'\[[^\]\n]*\]\s*\([^)]*\)\s*(?:mutable\s*)?(?:->\s*[\w:<>]+\s*)?\{')
RET = re.compile(r'\breturn\b')
def strip(src):
    src = re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group(0).count('\n'), src, flags=re.S)
    src = re.sub(r'//[^\n]*', '', src)
    return re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', src)
def count(path):
    stack, counts, cur = [], [], 0
    for line in strip(open(path, encoding='utf-8', errors='replace').read()).split('\n'):
        if not stack and re.match(r'\s*(extern\s+""|namespace\b)[^;{]*\{\s*$', line):
            continue
        lam_ends = {m.end() - 1 for m in LAMBDA.finditer(line)}
        rets = {m.start() for m in RET.finditer(line)}
        for i, ch in enumerate(line):
            if i in rets and stack and 'lam' not in stack:
                cur += 1
            if ch == '{':
                stack.append('fn' if not stack else ('lam' if i in lam_ends else 'blk'))
                if len(stack) == 1: cur = 0
            elif ch == '}' and stack:
                if stack.pop() == 'fn' and not stack: counts.append(cur)
    return sum(max(0, c - 1) for c in counts)
if __name__ == '__main__':
    print(count(sys.argv[1]))
