#!/usr/bin/env python3
# util_raku_case_table_pool.py -- the second half of util_raku_case_table_regen.sh: read its rows ("{ cp, A, B, C, D },", each
#   field 0 or a C string of octal escapes) on stdin and print src/runtime/rk_case_table.h as ONE string pool plus 32-bit offsets.
#   A table of char pointers costs one load-time relocation per pointer in every process of every language (5,756 of them,
#   measured 2026-10-17); offsets into one const char array cost none. An offset is the string's index in the pool plus one, so 0
#   still means "maps to itself". Identical strings share one pool entry.
# Usage: ... | python3 util_raku_case_table_pool.py > rk_case_table.h      (rc 2 if no row is read)
import re, sys
ROW = re.compile(r'\{\s*(\d+),\s*(0|"(?:[^"\\]|\\.)*"),\s*(0|"(?:[^"\\]|\\.)*"),\s*(0|"(?:[^"\\]|\\.)*"),\s*(0|"(?:[^"\\]|\\.)*")\s*\}')
def unesc(lit):
    return bytes(int(o, 8) for o in re.findall(r'\\([0-7]{3})', lit[1:-1]))
rows = [m.groups() for m in ROW.finditer(sys.stdin.read())]
if not rows:
    sys.stderr.write("REFUSE rc=2 [util_raku_case_table_pool] -- no row on stdin\n")
    sys.exit(2)
pool, at = bytearray(), {}
def off(f):
    if f == '0':
        return 0
    b = unesc(f)
    if b not in at:
        at[b] = len(pool) + 1
        pool.extend(b + b'\0')
    return at[b]
ents = [(int(r[0]), off(r[1]), off(r[2]), off(r[3]), off(r[4])) for r in rows]
out = ["#ifndef RK_CASE_TABLE_H", "#define RK_CASE_TABLE_H", "typedef struct { unsigned cp, uc, lc, tc, fc; } RkCase;", "static const char rk_case_pool[] ="]
lit = ''.join('\\%03o' % c for c in pool)
for i in range(0, len(lit), 192):
    out.append('    "' + lit[i:i + 192] + '"')
out[-1] += ';'
out.append("static const RkCase rk_case[] = {")
line = "   "
for e in ents:
    cell = " { %d, %d, %d, %d, %d }," % e
    if len(line) + len(cell) > 196:
        out.append(line)
        line = "   "
    line += cell
out.append(line)
out.append("};")
out.append("static inline const char *rk_case_at(unsigned o) { return o ? rk_case_pool + o - 1 : (const char *)0; }")
out.append("#endif")
print('\n'.join(out))
