#!/usr/bin/env python3
"""util_sno_include_twin.py -- the SNOBOL4 pre-step as the C front-end reads it: -INCLUDE and -COPY lines replaced by the file's text.

usage: util_sno_include_twin.py file.sno > expanded.sno      (SNO_LIB names the include directories, ':'-separated)

The reference for parser_snobol4.sc's Preprocess pattern (CEO-1483): an independent re-implementation of what snobol4.l does with an include
line, so the C parser reads the SAME generated text the .sc parser generates for itself. The rules, from snobol4.l: a line that begins with -INCLUDE or
-COPY (any case), blanks, then a quoted name ('...' or "...", at least one character, no newline inside), then anything up to the newline. The name is
everything between the first and the LAST quote character of that kind on the line, trailing blanks trimmed; it is tried as written, then in each
directory of SNO_LIB, then in the directory of each file already included. -INCLUDE reads a name once (keyed by the name before trimming), -COPY every
time. The file's text replaces the line, newline included. rc 0 written; 1 a name cannot be opened (the C parser's error); 2 usage.
"""
import os, re, sys

RX = re.compile(r"-(?:include|copy)[ \t]+(?:'[^'\n]+'|\"[^\"\n]+\")[^\n]*\n", re.I)


def expand(text, dirs, seen):
    out = []
    for line in re.findall(r"[^\n]*\n|[^\n]+", text):
        m = RX.fullmatch(line)
        if not m:
            out.append(line)
            continue
        i = 1
        while line[i] not in " \t":
            i += 1
        while line[i] in " \t":
            i += 1
        qc = line[i]
        key = line[line.index(qc) + 1:line.rindex(qc)]
        nm = key.rstrip(" \t")
        once = line[1] in "iI"
        path = None
        for cand in [nm] + [d + "/" + nm for d in dirs]:
            if os.path.isfile(cand):
                path = cand
                break
        if path is None:
            raise FileNotFoundError(nm)
        if once:
            if key in seen:
                continue
            seen.add(key)
        if "/" in path:
            dirs.append(path[:path.rindex("/")])
        with open(path, "rb") as f:
            inc = f.read().decode("latin-1")
        out.append(expand(inc, dirs, seen))
    return "".join(out)


def main():
    if len(sys.argv) != 2:
        print(__doc__.split("\n")[2], file=sys.stderr)
        return 2
    dirs = [d for d in os.environ.get("SNO_LIB", "").split(":") if d]
    with open(sys.argv[1], "rb") as f:
        text = f.read().decode("latin-1")
    try:
        sys.stdout.buffer.write(expand(text, dirs, set()).encode("latin-1"))
    except FileNotFoundError as e:
        print("util_sno_include_twin: cannot open include '%s'" % e.args[0], file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
