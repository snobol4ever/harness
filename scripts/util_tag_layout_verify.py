#!/usr/bin/env python3
"""GATE: verify the DTYPE_t layout in descr.h still supports every inline predicate
the emitted BBs depend on. Reads the TREE, never a hardcoded table (s229).
Exit 0 = all predicates hold. Exit 1 = a renumber broke an inline form."""
import re, sys, os
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP")
h = open(os.path.join(ROOT, 'src/ir/descr.h')).read()
T = {m[0]: int(m[1], 16) for m in re.findall(r'\b(DT_[A-Z0-9_]+)\s*=\s*(0x[0-9A-Fa-f]+)', h)}
NUMBIT, CHARS, REALBIT = 0x01, 0x02, 0x04
NOTSTR, STRIDE, NDATA = 0xFFFFFFFD, 8, 64
I, R, S, SNUL = T['DT_I'], T['DT_R'], T['DT_S'], T['DT_SNUL']
data = [T['DT_DATA'] + STRIDE * k for k in range(NDATA)]
allv = sorted(set(T.values())) + data
num, st = [I, R], [SNUL, S]
F = lambda p: [(a, b) for a in allv for b in allv if not p(a, b)]
fails = []
def ck(name, form, ok):
    print(f"  {'OK ' if ok else 'BAD'}  {name:16} {form}")
    if not ok: fails.append(name)

print("DTYPE_t inline-predicate gate — layout read from src/ir/descr.h")
ck('is numeric', 'test eax,DT_NUMERIC_BIT',
   all(v & NUMBIT for v in num) and all(not (v & NUMBIT) for v in allv if v not in num))
ck('is string', 'test eax,DT_NOTSTR_MASK ->Z',
   all(not (v & NOTSTR) for v in st) and all(v & NOTSTR for v in allv if v not in st))
ck('is real', 'test eax,DT_REAL_BIT', bool(R & REALBIT) and not (I & REALBIT))
ck('NULL vs S', 'test eax,DT_CHARS_BIT ->Z', bool(S & CHARS) and not (SNUL & CHARS))
ck('BOTH INT', 'and eax,ecx; cmp eax,DT_I',
   all((a & b) != I for a, b in F(lambda a, b: a == I and b == I)))
ck('BOTH REAL', 'and eax,ecx; cmp eax,DT_R',
   all((a & b) != R for a, b in F(lambda a, b: a == R and b == R)))
ck('BOTH NUMERIC', 'and eax,ecx; test al,DT_NUMERIC_BIT',
   all((a & b) & NUMBIT for a in num for b in num)
   and all(not ((a & b) & NUMBIT) for a, b in F(lambda a, b: a in num and b in num)))
ck('BOTH STRING', 'or eax,ecx; test eax,DT_NOTSTR_MASK ->Z',
   all(not ((a | b) & NOTSTR) for a in st for b in st)
   and all((a | b) & NOTSTR for a, b in F(lambda a, b: a in st and b in st)))
ck('FAIL is inert', 'neither numeric nor string',
   not (T['DT_FAIL'] & NUMBIT) and bool(T['DT_FAIL'] & NOTSTR))
ck('DATA inert', 'no user datatype reads numeric', all(not (d & NUMBIT) for d in data))
ck('A/T adjacent', 'one subscript range guard', T['DT_T'] - T['DT_A'] == STRIDE)
# ---------------------------------------------------------------------------------------------------------
# s230 ADDITIONS. The 11 predicate checks above verify the LAYOUT IS SOUND. They cannot verify that the tree
# actually USES it -- and that is where the TAG-3 renumber actually broke. Four defects shipped past a green
# layout gate, every one of them an assembly file that had learned a tag number by heart:
#   rt_asm_helpers.S  $9 / $99 / $6                      (AT&T; cannot include the Intel rtx_abi.inc)
#   rtx_icnsub.s      mov rax,0x200000009  x5            (the tag FUSED inside a packed 64-bit literal)
# The fused form is the reason a human reviewer and three greps all missed it: there is no "tag immediate"
# to see, only a nibble. So the gate now reads the TREE, not just the layout.
srcroot = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src')
inc = os.path.join(srcroot, 'ir', 'descr_tags.inc')
itags = {}
for ln in open(inc):
    m = re.match(r'\s*#define\s+(DT_[A-Z0-9_]+|RTX_NOT_HANDLED(?:_INT|_PTR)?)\s+(0x[0-9a-fA-F]+|\d+)\s*$', ln)
    if m:
        itags[m.group(1)] = int(m.group(2), 0)
for vn in ('RTX_NOT_HANDLED', 'RTX_NOT_HANDLED_INT', 'RTX_NOT_HANDLED_PTR'):
    mh = re.search(r'^#define\s+' + vn + r'\s+(0x[0-9a-fA-F]+)\s*$', h, re.M)
    if mh: T[vn] = int(mh.group(1), 16)
mism = [k for k in T if k in itags and itags[k] != T[k]]
missing = [k for k in T if k not in itags]
ck('descr.h == descr_tags.inc', f'{len(itags)} defines cross-checked', not mism and not missing)
if mism or missing:
    print(f'     mismatched={mism} missing_from_inc={missing}')
# Every OLD tag number, so a file that kept a stale literal is caught by VALUE, not by spelling.
asmdirs = [os.path.join(srcroot, 'runtime', 'rtx'), os.path.join(srcroot, 'runtime', 'rt')]
bad = []
for d in asmdirs:
    if not os.path.isdir(d):
        continue
    for fn in sorted(os.listdir(d)):
        if not fn.endswith('.S'):
            continue
        for i, ln in enumerate(open(d + '/' + fn, encoding='utf-8', errors='replace'), 1):
            code = ln.split('/*')[0]
            if not code.strip():
                continue
            # (a) a packed descriptor word: high dword tiny, low dword a tag-sized number.
            for h in re.findall(r'0x[0-9a-fA-F]{9,}', code):
                v = int(h, 16)
                if (v >> 32) < 16 and (v & 0xFFFFFFFF) < 0x200:
                    bad.append(f'{fn}:{i}: packed descriptor literal {h} -- use a DT_* symbol')
            # (b) DT_FAIL/DT_DATA old values as bare immediates; these two are unmistakable.
            if re.search(r'(?:\$|,\s*)(?:99|100)\b', code) and re.search(r'\b(mov|cmp)', code):
                bad.append(f'{fn}:{i}: bare 99/100 -- old DT_FAIL/DT_DATA?')
ck('no hand-encoded tags in .S', f'{len(asmdirs)} asm dirs swept', not bad)
for b in bad:
    print('     ' + b)
print("\nNOTE: `or` is NOT the arithmetic result tag under this layout "
      f"(DT_I|DT_R = {I|R:#04x}, not a tag). Result tag is a constant per inlined arm.")
print("GATE PASS" if not fails else f"GATE FAIL: {fails}")
sys.exit(1 if fails else 0)
