#!/usr/bin/env python3
"""util_spine_bake_census.py <emitted.s> -- the closing reading of row spine-bake-every-call-and-deferred-pattern-address-no-by-name-lookup-at-run-time-ceo-1362.

Reads the mode-4 asm of the Snocone parser chain and prints two readings:
  (1) THUNK LINES: lines naming a compiler thunk (EXPR$ PAT$ PATV$ SCV$, or a SNO$ hook string): want 0.
  (2) BY-NAME CALL SITES: every call to a by-name entry (rt_call_name_sn4, rt_call_arr_*, rt_call_open_by_name*, try_call_builtin_by_name*). A site whose
      baked callee is a PROTECTED SYSTEM FUNCTION (the cto's ruling on layer 12: it cannot be redefined, and the site already dispatches on the baked builtin id)
      is excluded from the closing count and printed as its own DECLARED count by function; every other by-name site is counted and must read 0.
The declared figure may only fall: each function's count must not exceed its declared figure, and the total must not exceed 22.
rc 0 iff thunk lines == 0, non-system by-name sites == 0, and the declared figures hold; rc 1 otherwise; rc 2 if the file cannot be read."""
import re, sys
DECLARED = {"EVAL": 8, "DATA": 6, "INPUT": 3, "HOST": 2, "APPLY": 2, "ENDFILE": 1}
SYSTEM = {"ANY", "APPLY", "ARBNO", "ARG", "ARRAY", "ATAN", "BREAK", "BREAKX", "CHAR", "CHOP", "CLEAR", "CODE", "COLLECT", "CONVERT", "COPY", "COS", "DATA", "DATATYPE", "DATE", "DEFINE",
    "DIFFER", "DUMP", "DUPL", "ENDFILE", "EQ", "EVAL", "EXP", "FENCE", "FIELD", "GE", "GT", "HOST", "IDENT", "INPUT", "INTEGER", "ITEM", "LE", "LEN", "LEQ", "LGE", "LGT", "LLE", "LLT", "LN", "LNE",
    "LOAD", "LOCAL", "LPAD", "LT", "NE", "NOTANY", "OPSYN", "OUTPUT", "POS", "PROTOTYPE", "REMDR", "REPLACE", "REVERSE", "RPAD", "RPOS", "RSORT", "RTAB", "SET", "SETEXIT", "SIN", "SIZE", "SORT",
    "SPAN", "SQRT", "STOPTR", "SUBSTR", "TAB", "TABLE", "TAN", "TIME", "TRACE", "TRIM", "UNLOAD"}
CALL = re.compile(r"call\s+(rt_call_name_sn4|rt_call_arr_[a-z_0-9]*|rt_call_open_by_name[a-z_0-9]*|try_call_builtin_by_name[a-z_0-9]*)\b")
THUNK = re.compile(r'(EXPR|PAT|PATV|SCV)\$|\.string +"\*?SNO\$[A-Z]+')
LEA = re.compile(r"lea\s+rdi,\s*\[rip \+ ([^\]]+)\]")
def main(path):
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
    except OSError as e:
        print("util_spine_bake_census: cannot read %s: %s" % (path, e)); return 2
    strings = {}
    for ln in lines:
        m = re.match(r'^(\.L[^:\s]*):.*\.string\s+"(.*)"', ln)
        if m: strings[m.group(1)] = m.group(2)
    thunk = sum(1 for ln in lines if THUNK.search(ln))
    sysfn, other = {}, []
    for i, ln in enumerate(lines):
        m = CALL.search(ln)
        if not m: continue
        name = None
        if m.group(1) == "rt_call_arr_bl_sn4_try":
            for j in range(i - 1, max(i - 14, -1), -1):
                lm = LEA.search(lines[j])
                if lm: name = strings.get(lm.group(1).strip()); break
        if name in SYSTEM: sysfn[name] = sysfn.get(name, 0) + 1
        else: other.append((i + 1, m.group(1), name))
    total = sum(sysfn.values())
    rise = [f for f, n in sorted(sysfn.items()) if n > DECLARED.get(f, 0)]
    print("spine-bake census: thunk lines=%d (want 0); by-name call sites outside the protected system functions=%d (want 0)" % (thunk, len(other)))
    print("  protected system-function sites, declared count that may only fall: %s total %d (declared 22)" % (" ".join("%s %d/%d" % (f, sysfn.get(f, 0), DECLARED[f]) for f in sorted(DECLARED)), total))
    for ln, sym, nm in other[:10]: print("  by-name site line %d: %s %s" % (ln, sym, nm if nm else "(no baked name)"))
    for f in rise: print("  RISE: %s reads %d, declared %d" % (f, sysfn[f], DECLARED.get(f, 0)))
    return 0 if thunk == 0 and not other and not rise and total <= 22 else 1
if __name__ == "__main__":
    sys.exit(main(sys.argv[1]) if len(sys.argv) > 1 else 2)
