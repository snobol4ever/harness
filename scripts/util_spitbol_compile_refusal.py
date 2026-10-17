#!/usr/bin/env python3
"""util_spitbol_compile_refusal.py -- a SPITBOL COMPILE REFUSAL, read by code and line (ceo CEO-1323, 2026-09-27, on Lon's
"I want to see TPgm go to 8/8. I'm tired of seeing that 1/8.").

WHAT IT GRADES. sbl -bf refuses to compile some programs: it prints its listing lines and one or more diagnostics of the shape
    <file>(<line>) : ERROR <code> -- <text>          or          <file>(<line>,<col>) : ERROR <code> -- <text>
and exits nonzero without running anything (spitbol_testpgms/test2.spt: rc 231, ERROR 214 at line 238, measured deterministic
30 of 30 runs on 2026-09-27). CEO-1323 grades such a program the way CEO-1316 grades a post-mortem: SCRIP passes by refusing
where SPITBOL x64 refuses, and the grade is the CODE and the LINE of every diagnostic, read through the one error voice
(util_render_error_voice.py spitbol renders SCRIP's "scrip: error <code>: <text> / at <file>:<line>" into this same shape).
The rc alone never grades (the cfo's condition): an rc of 231 from a different error must read red.

MODES
    oracle <sbl-stdout-file> <sbl-rc>   rc 0: a compile refusal -- prints one "<line>\t<code>" per diagnostic, sorted, unique
                                        rc 3: not a compile refusal (sbl answered, timed out, or printed no diagnostic) -- the
                                              caller keeps its existing classification
                                        rc 2: REFUSE -- a diagnostic is present beside a run-time post-mortem, or sbl exited 0
                                              with a diagnostic and no post-mortem: a shape this grader was not measured on
    pairs <file|->                      prints the "<line>\t<code>" pairs found in an already-rendered stream, sorted, unique
"""
import re, sys

DIAG = re.compile(r'^\S.*?\((\d+)(?:,\d+)?\) : ERROR (\d+) -- ')
POST_MORTEM = re.compile(r'^(in statement \d+|stmts executed|memory used \(bytes\)|memory left \(bytes\))')

def pairs_of(lines):
    out = set()
    for l in lines:
        m = DIAG.match(l)
        if m: out.add((int(m.group(1)), int(m.group(2))))
    return sorted(out)

def emit(ps):
    for ln, code in ps: print('%d\t%d' % (ln, code))

def read(path):
    data = sys.stdin.buffer.read() if path == '-' else open(path, 'rb').read()
    return data.decode('utf-8', 'surrogateescape').split('\n')

def main(argv):
    if len(argv) == 4 and argv[1] == 'oracle':
        try: rc = int(argv[3])
        except ValueError: sys.stderr.write('REFUSE(rc=2): the sbl rc %r is not an integer\n' % argv[3]); return 2
        if rc == 124: return 3
        lines = read(argv[2]); ps = pairs_of(lines); pm = any(POST_MORTEM.match(l) for l in lines)
        if not ps: return 3
        if pm:
            sys.stderr.write('REFUSE(rc=2): sbl printed a diagnostic AND a run-time post-mortem -- a run-time error, not a compile refusal; '
                             'util_spitbol_post_mortem.py is its grader\n'); return 2
        if rc == 0:
            sys.stderr.write('REFUSE(rc=2): sbl printed a diagnostic and exited 0 with no post-mortem -- a shape this grader was not measured on\n')
            return 2
        emit(ps); return 0
    if len(argv) == 3 and argv[1] == 'pairs':
        emit(pairs_of(read(argv[2]))); return 0
    sys.stderr.write('REFUSE(rc=2): usage: util_spitbol_compile_refusal.py oracle <sbl-stdout> <sbl-rc> | pairs <file|->\n'); return 2

if __name__ == '__main__':
    sys.exit(main(sys.argv))
