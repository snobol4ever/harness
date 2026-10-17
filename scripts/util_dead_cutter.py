import re, sys

# Brace-aware C top-level splitter.
# Emits a list of "items": each is ('func', name, text), ('pp', None, text),
# ('sep', None, text), or ('other', None, text). Text includes trailing newline.
# Function name = last identifier before the '(' of the param list of a definition
# (depth-0 signature whose matching '{' opens a body).

SIG = re.compile(r'([A-Za-z_]\w*)\s*\(')
SEP = re.compile(r'^\s*/\*[-=]{3,}\*/\s*$')

def lex_items(src):
    n = len(src)
    i = 0
    items = []
    line_start = 0
    # We process line-by-line at depth 0, but use char scan for bodies.
    # Helper: from position p (start of a top-level construct), determine if it's a
    # function definition; if so, consume through matching close brace.
    def skip_ws_comments(p):
        while p < n:
            c = src[p]
            if c in ' \t\r\n':
                p += 1
            elif src.startswith('//', p):
                e = src.find('\n', p); p = n if e < 0 else e+1
            elif src.startswith('/*', p):
                e = src.find('*/', p+2); p = n if e < 0 else e+2
            else:
                break
        return p

    while i < n:
        # capture leading separator / pp / blank as their own items to preserve layout
        # find end of current logical line
        nl = src.find('\n', i)
        eol = n if nl < 0 else nl+1
        line = src[i:eol]
        if SEP.match(line):
            items.append(('sep', None, line)); i = eol; continue
        if line.lstrip().startswith('#'):
            # preprocessor: consume continuations
            blk = line; j = eol
            while line.rstrip('\n').endswith('\\') and j < n:
                nl2 = src.find('\n', j); e2 = n if nl2 < 0 else nl2+1
                line = src[j:e2]; blk += line; j = e2
            items.append(('pp', None, blk)); i = j; continue
        if line.strip() == '':
            items.append(('other', None, line)); i = eol; continue
        # Could be a function definition, a comment block, or a global decl.
        # Scan from i with brace/string awareness to find the construct end.
        p = i
        depth = 0
        started_body = False
        sig_text = ''
        construct_end = None
        in_str = in_chr = False
        in_lc = in_bc = False
        saw_semi_at_0 = False
        while p < n:
            c = src[p]
            two = src[p:p+2]
            if in_lc:
                if c == '\n': in_lc = False
                p += 1; continue
            if in_bc:
                if two == '*/': in_bc = False; p += 2; continue
                p += 1; continue
            if in_str:
                if c == '\\': p += 2; continue
                if c == '"': in_str = False
                p += 1; continue
            if in_chr:
                if c == '\\': p += 2; continue
                if c == "'": in_chr = False
                p += 1; continue
            if two == '//': in_lc = True; p += 2; continue
            if two == '/*': in_bc = True; p += 2; continue
            if c == '"': in_str = True; p += 1; continue
            if c == "'": in_chr = True; p += 1; continue
            if c == '{':
                depth += 1; started_body = True; p += 1; continue
            if c == '}':
                depth -= 1; p += 1
                if depth == 0 and started_body:
                    construct_end = p
                    # consume trailing newline
                    if construct_end < n and src[construct_end] == '\n':
                        construct_end += 1
                    break
                continue
            if c == ';' and depth == 0 and not started_body:
                # top-level declaration / prototype — ends here
                construct_end = p+1
                if construct_end < n and src[construct_end] == '\n':
                    construct_end += 1
                break
            p += 1
        if construct_end is None:
            construct_end = n
        text = src[i:construct_end]
        # classify
        if started_body:
            # function definition (or struct/enum with body+;) — extract name
            # take the part before the first '{'
            head = text[:text.index('{')]
            # name = last IDENT before the '(' that starts the param list
            # find the '(' at the signature level: the first '(' in head whose
            # preceding token is an identifier; pick the identifier right before
            # the LAST top-level '(' before '{'.
            name = None
            # strip strings/comments from head for matching
            m = list(SIG.finditer(head))
            # choose the match whose identifier is a plausible function name:
            # the last one before the first '{' that is preceded by type/qualifier.
            # Heuristic: the function name is the identifier immediately before the
            # FIRST '(' that is at signature top-level. Usually the last IDENT( in head
            # for definitions like "static T NAME(args)" works; but "T NAME(args, fn(x))"
            # could fool. Use the FIRST '(' whose name is not a known keyword.
            KW = {'if','for','while','switch','sizeof','return','do','else'}
            for mm in m:
                if mm.group(1) not in KW:
                    name = mm.group(1)
                    # keep scanning: the name is the IDENT right before the param-list '('
                    # which is the LAST plausible ident before the matching '{'.
                    # We'll take the last non-keyword IDENT( instead:
            # better: last non-keyword IDENT(
            cand = [mm.group(1) for mm in m if mm.group(1) not in KW]
            if cand:
                name = cand[-1]
            items.append(('func', name, text))
        else:
            items.append(('other', None, text))
        i = construct_end
    return items

def func_names(path):
    with open(path) as f: src = f.read()
    items = lex_items(src)
    return [it[1] for it in items if it[0]=='func' and it[1]]

if __name__ == '__main__':
    for nm in sorted(set(func_names(sys.argv[1]))):
        print(nm)
