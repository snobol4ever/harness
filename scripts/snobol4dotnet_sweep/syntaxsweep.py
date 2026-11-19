#!/usr/bin/env python3
# syntaxsweep.py FILE : each non-blank line of FILE that does not start with # is a statement (\n and \t stand for a newline and a tab),
# made into the program `statement / OUTPUT = 'x' / END` and run under sbl -bf and the console; prints the statements whose errors differ
# in code, line or column. A difference is a defect of this project unless sbl itself crashes. Run it from an empty scratch directory.
import os, re, subprocess, sys

SBL = os.environ.get("SBL", "/home/resources/x64/bin/sbl")
DLL = os.environ.get("DLL", os.path.join(os.environ.get("S4E_DOTNET_ROOT", "/home/claude_dotnet"), "Snobol4", "bin", "Release", "net10.0", "Snobol4.dll"))
pattern = re.compile(r"^\S+\((\d+)(?:,(\d+))?\) : ERROR (\d+)", re.M)


def errors(text):
    return [(m.group(3), m.group(1), m.group(2)) for m in pattern.finditer(text)]


statements = [l.rstrip("\n") for l in open(sys.argv[1]) if l.strip() != "" and not l.startswith("#")]
different = 0
for statement in statements:
    statement = statement.replace("\\n", "\n").replace("\\t", "\t")
    open("p.sno", "w").write(statement + "\n        OUTPUT = 'x'\nEND\n")
    a = subprocess.run([SBL, "-bf", "p.sno"], capture_output=True, text=True, errors="replace", timeout=20)
    b = subprocess.run(["dotnet", DLL, "-bf", "p.sno"], capture_output=True, text=True, errors="replace", timeout=60)
    ea, eb = errors(a.stdout), errors(b.stdout)
    if ea != eb:
        different += 1
        print(repr(statement))
        print("   sbl", ea)
        print("   net", eb)
print("cases", len(statements), "differ", different)
