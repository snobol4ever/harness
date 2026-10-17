import os, re, sys
NAMES = ("malloc", "calloc", "realloc", "free")
CALL = {"malloc": "ct_alloc", "calloc": "ct_zalloc", "realloc": "ct_grow", "free": "ct_drop", "strdup": "ct_strdup", "strndup": "ct_strndup"}
SRC_EXT = (".c", ".cpp", ".h", ".hpp", ".l", ".y")
def rewrite_calls(text):
    n = 0
    for old, new in CALL.items():
        text, k = re.subn(r"(?<![\w.>])" + old + r"\s*\(", new + "(", text)
        n += k
    return text, n
def rewrite_bison_block(text):
    n = 0
    subs = [
        (r"#(\s*)define YYMALLOC malloc", r"#\1define YYMALLOC ct_alloc"),
        (r"#(\s*)define YYFREE free", r"#\1define YYFREE ct_drop"),
        (r"#(\s*)if ! defined malloc && ! defined EXIT_SUCCESS", r"#\1if 0"),
        (r"#(\s*)if ! defined free && ! defined EXIT_SUCCESS", r"#\1if 0"),
        (r"#(\s*)include <malloc\.h>[^\n]*", r"#\1include \"ct_arena.h\""),
        (r"\(defined YYMALLOC \|\| defined malloc\)", r"(defined YYMALLOC)"),
        (r"\(defined YYFREE \|\| defined free\)", r"(defined YYFREE)"),
        (r"The parser invokes alloca or malloc; define the necessary symbols\.", r"The parser invokes alloca or the compile-time arena; define the necessary symbols."),
        (r"immediate realloc on the next call", r"immediate regrow on the next call"),
    ]
    for pat, rep in subs:
        text, k = re.subn(pat, rep, text)
        n += k
    return text, n
def has_include(text):
    return re.search(r'#\s*include\s+"ct_arena\.h"', text) is not None
def add_include(path, text):
    if has_include(text):
        return text
    if path.endswith((".l", ".y")):
        i = text.find("%{")
        if i >= 0:
            j = text.index("\n", i) + 1
            return text[:j] + '#include "ct_arena.h"\n' + text[j:]
        return '%{\n#include "ct_arena.h"\n%}\n' + text
    m = re.search(r"^#\s*include[^\n]*\n", text, re.M)
    if m:
        return text[: m.end()] + '#include "ct_arena.h"\n' + text[m.end() :]
    m = re.search(r"^#\s*define\s+\w+_H\b[^\n]*\n", text, re.M)
    if m:
        return text[: m.end()] + '#include "ct_arena.h"\n' + text[m.end() :]
    return '#include "ct_arena.h"\n' + text
def walk_targets(paths):
    for root in paths:
        if os.path.isfile(root):
            yield root
            continue
        for dirpath, _, files in os.walk(root):
            for fn in sorted(files):
                yield os.path.join(dirpath, fn)
def sweep(paths, apply):
    total, touched = 0, 0
    for p in walk_targets(paths):
        if not p.endswith(SRC_EXT):
            continue
        if p.endswith("ct_arena.c") or p.endswith("ct_arena.h"):
            continue
        with open(p, encoding="utf-8", errors="surrogateescape") as f:
            text = f.read()
        new, n1 = rewrite_calls(text)
        new, n2 = rewrite_bison_block(new)
        if n1 + n2 == 0:
            continue
        new = add_include(p, new)
        total += n1 + n2
        touched += 1
        print("%-62s calls=%-4d skeleton=%d" % (p, n1, n2))
        if apply:
            with open(p, "w", encoding="utf-8", errors="surrogateescape", newline="\n") as f:
                f.write(new)
    print("SWEEP files=%d sites=%d %s" % (touched, total, "APPLIED" if apply else "DRY-RUN"))
    return 0
if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    sys.exit(sweep(args or ["src"], "--apply" in sys.argv))
