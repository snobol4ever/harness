#!/usr/bin/env python3
# util_ir_identity_normalise_asm.py < prog.s > prog.norm.s -- THE ONE NORMALISATION THE IR-IDENTITY GATE APPLIES TO ASSEMBLY WHEN IT IS NOT --strict
# (the cto, ARCH-PARSER-SC-BOOTSTRAP 7.x, 2026-10-30 10:3x CDT, CEO-1888: "the gate compares the observables: --dump-ir exactly, the .loc sequence exactly, the asm
# after a normalisation of ids, the slot base, the two leak tables and the wrap"). Under SCRIP_PARSE_STAGE=sc the parser module's run leaks into the compile
# process, so the same program's assembly differs from the C stage's in exactly five ways, none of them a statement, a line or a source text:
#   (1) ids   -- node ids (n0_ -> n6_) and the emitter's local-label counters (.Lcall_direct_a_39_999 -> _45_999) start later: each digit run of a label is
#                renamed by first appearance within its own family (the label up to that run), an alpha-renaming, so a changed structure still differs;
#   (2) slot base -- the user program's GVA slots begin after the module's cells (743 -> 772): .Lgvan<N>, [r9 + 16*N (+8)] and the two cell-count immediates
#                (mov edi/edx, N before rt_gva_island / gva_register) are made relative to the base, the minimum .Lgvan number (else the count itself);
#   (3) the two leak tables -- the .quad .Lgcmap_rtpat / .Lgcsites_rtpat_<n> entries of __gc_frame_maps and __gc_frame_sites (their count is recomputed) and the
#                .S<k> rodata strings "OPQ$<n>" the module's run named (and the .section .rodata / .text pair they leave empty); the remaining .S<k> are renamed by first appearance;
#   (4) the __gva_names zero padding in front of the first name (its length is the slot base);
#   (5) the wrap -- the printer's column moves with a label's width, a label too wide for its column leaves its instruction on the next line and a `;`-joined
#                statement pair falls apart when it no longer fits: every `;` outside quotes ends a line, whitespace runs
#                outside quotes collapse to one blank and a label alone on its line takes the indented line that follows it.
# --strict skips this whole file: it compares the raw text, as the gate always did. A text this filter leaves different is a difference in the program.
import re, signal, sys

signal.signal(signal.SIGPIPE, signal.SIG_DFL)

LEAK = [re.compile(r'^\s*\.quad\s+\.Lgcmap_rtpat\s*$'), re.compile(r'^\s*\.quad\s+\.Lgcsites_rtpat_\d+\s*$'), re.compile(r'^\.S\d+:\s*\.string\s+"OPQ\$\d+"\s*$')]
GVAN = re.compile(r'\.Lgvan(\d+)')
TOK = re.compile(r'\.Lgvan\d+|\.L[\w.]+|\bn\d+_\w*|\.S\d+\b')
R9 = re.compile(r'\[r9 \+ (\d+)\]')
CNT = re.compile(r'^(\s*mov\s+)(edi|edx)(,\s*)(\d+)\s*$')
LABEL = re.compile(r'^(?!#)[^\s;"]+:$')
TABLE = re.compile(r'^(__gc_frame_maps|__gc_frame_sites):(\s*)\.quad(\s+)(\d+)\s*$')


def collapse(line):
    parts = line.split('"')
    for i in range(0, len(parts), 2):
        parts[i] = re.sub(r'[ \t]+', ' ', parts[i])
    return '"'.join(parts).rstrip()


def statements(line):
    parts = line.split('"')
    for i in range(0, len(parts), 2):
        parts[i] = re.sub(r';[ ]*', ';\n ', parts[i])
    pieces = '"'.join(parts).split('\n')
    return [p.rstrip(';') if i < len(pieces) - 1 else p for i, p in enumerate(pieces)]


def main():
    lines = sys.stdin.read().split('\n')
    lines = [l for l in lines if not any(p.match(l) for p in LEAK)]
    nums = [int(m.group(1)) for l in lines for m in [re.match(r'^\.Lgvan(\d+):', l)] if m]
    base = min(nums) if nums else None
    if base is None:
        for i, l in enumerate(lines[:-1]):
            m = CNT.match(l)
            if m and 'rt_gva_island' in lines[i + 1]:
                base = int(m.group(4))
                break
    seen = {}

    def ident(key, n):
        d = seen.setdefault(key, {})
        return d.setdefault(n, len(d))

    def tok(m):
        t = m.group(0)
        if t.startswith('.Lgvan'):
            return '.Lgvan+%d' % (int(t[6:]) - base) if base is not None else t
        if t.startswith('.S'):
            return '.S#%d' % ident('.S', t[2:])
        if t.startswith('n'):
            k = t.index('_')
            return 'n#%d%s' % (ident('n', t[1:k]), t[k:])
        out = ''
        pos = 0
        for r in re.finditer(r'\d+', t[2:]):
            out += t[pos:r.start() + 2]
            out += '#%d' % ident(out, r.group(0))
            pos = r.end() + 2
        return out + t[pos:]

    def r9(m):
        n = int(m.group(1))
        return '[r9 + %s]' % (('base+%d' % (n - 16 * base)) if base is not None and n >= 16 * base else n)

    out = []
    zeros = False
    for i, l in enumerate(lines):
        if l.startswith('__gva_names:'):
            zeros = True
        elif zeros and re.match(r'^\s*\.quad\s+0\s*$', l):
            continue
        elif zeros and l.strip():
            zeros = False
        m = CNT.match(l)
        if m and base is not None and i + 1 < len(lines) and ('rt_gva_island' in lines[i + 1] or 'gva_register' in lines[i + 1]):
            l = '%s%s%scount+%d' % (m.group(1), m.group(2), m.group(3), int(m.group(4)) - base)
        l = R9.sub(r9, l)
        l = TOK.sub(tok, l)
        for l in statements(collapse(l)):
            if out and LABEL.match(out[-1]) and l.startswith(' ') and not LABEL.match(l.strip()):
                out[-1] = out[-1] + l
            else:
                out.append(l)
    text = '\n'.join(out)
    text = re.sub(r'\n \.section \.rodata\n \.text(?=\n)', '', text)
    for name in ('__gc_frame_maps', '__gc_frame_sites'):
        text = re.sub(r'^(%s:) \.quad (\d+)((?:\n \.quad [^\n]*)*)' % name, lambda m: '%s .quad %d%s' % (m.group(1), m.group(3).count('\n'), m.group(3)), text, flags=re.M)
    sys.stdout.write(text)


main()
