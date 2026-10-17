# live_dep_files.awk -- print each compiler dependency file (.d) whose object's FIRST prerequisite, its source, still exists.
# (ceo CEO-1352; the coo's row build-an-incremental-make-survives-a-moved-source-a-dep-file-whose-source-is-gone-is-left-out-by-rule-not-by-name)
# The Makefile's -include reads the objdirs' .d files through this filter: a SOURCE THAT MOVED (re.c from src/parsers/raku to
# src/runtime, CEO-1289; prolog_atom.c from src/parsers/prolog to src/runtime/rt, 481a8cd96) leaves every older objdir a .d naming the
# old path as its object's first prerequisite, and -MP phony-targets headers only, so the next incremental make dies "No rule to make
# target" on a file nobody should build. Left out, the object rebuilds from its pattern rule and the .d is rewritten.
# BY RULE, NEVER BY NAME: the filter reads the path the .d itself names, so the third move needs no edit here.
# Portable to mawk (no ENDFILE, no system() per file): the first prerequisite sits on the target's line or the line after it
# (gcc -MMD writes "obj.o: \" then " src.c \"), and existence is read with getline, which returns -1 for a path it cannot open.
# Usage: find <objdir>... -name '*.d' | xargs -r awk -f live_dep_files.awk
function emit(   i, t, n, a, p, r, x) {
    if (f == "") return
    gsub(/\\/, " ", s)
    i = index(s, ":")
    t = (i > 0) ? substr(s, i + 1) : ""
    n = split(t, a, " ")
    p = (n > 0) ? a[1] : ""
    if (p == "") { print f; f = ""; return }        # no prerequisite to judge: keep the file, as make always did
    r = (getline x < p); close(p)
    if (r >= 0) print f                              # the source is there (readable, empty or not): keep the .d
    f = ""
}
FNR == 1 { emit(); f = FILENAME; s = $0; next }
FNR == 2 && f != "" { s = s " " $0; emit(); next }
END { emit() }
