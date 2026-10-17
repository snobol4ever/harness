#!/usr/bin/env python3
# audit_template_locals.py <file> -- prints the number of source lines that declare a local variable inside a function
# body (TEMPLATE SPEC v2: a template has no locals; every value arrives through g_emit from the emitter).
# Replaces the one-regex count of audit_bb_fixup_file.sh, which saw only a line that BEGINS with one of sixteen type
# words: it missed static locals, const-qualified scalars, DESCR_t, uint8/16/32_t, struct and std:: types, and any
# declaration that follows a { or ; on the same line (measured 2026-09-28: 292 counted of 419 real, 29 of 57 files).
# A line counts once however many declarations it holds. Loop heads and lambda parameters are not counted.
import re, sys
KW = {'return', 'else', 'if', 'for', 'while', 'switch', 'case', 'goto', 'delete', 'new', 'throw', 'using',
      'typedef', 'do', 'break', 'continue', 'default', 'sizeof', 'extern'}
DECL = re.compile(r'^\s*((?:const|static|unsigned|signed|volatile|struct|constexpr|thread_local)\s+)*'
                  r'([A-Za-z_][\w:]*(?:<[^;=]*?>)?)(\s*[*&]+\s*|\s+)([A-Za-z_]\w*)\s*(\[[^\]]*\])?\s*(=|;|,|\{|\[)')
def strip(src):
    src = re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group(0).count('\n'), src, flags=re.S)
    src = re.sub(r'//[^\n]*', '', src)
    return re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', src)
def is_decl(piece):
    m = DECL.match(piece)
    return bool(m) and m.group(2) not in KW and m.group(4) not in KW and not m.group(2).startswith('x86')
def count(path):
    depth, n = 0, 0
    for line in strip(open(path, encoding='utf-8', errors='replace').read()).split('\n'):
        if depth > 0 and any(is_decl(p) for p in [line] + re.split(r'[;{]', line)[1:]):
            n += 1
        depth += line.count('{') - line.count('}')
    return n
if __name__ == '__main__':
    print(count(sys.argv[1]))
