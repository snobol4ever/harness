#!/usr/bin/env python3
# compilediff.py FILELIST : FILELIST names programs, one path to a line (find /path -name '*.sno' -o -name '*.spt' > list). Each is
# compiled without running (-n) under sbl -bf and the console, in its own folder with SNOLIB naming the corpus includes, and the
# compile errors (code, line, column) are compared; prints the programs where they differ. A program that compiles clean under both is
# the usual outcome, so a difference is either an error that is found by one engine only or at another place.
import os, re, subprocess, sys

SBL = os.environ.get("SBL", "/home/resources/x64/bin/sbl")
DLL = os.environ.get("DLL", os.path.join(os.environ.get("S4E_DOTNET_ROOT", "/home/claude_dotnet"), "Snobol4", "bin", "Release", "net10.0", "Snobol4.dll"))
include = os.environ.get("SNOLIB", os.path.join(os.environ.get("S4E_CORPUS", "/home/corpus"), "include"))
# the include search path: SNOLIB for the console (the manual), SETL4PATH for the sbl the oracle is, as the harness sets them
env = dict(os.environ, SNOLIB=include, SETL4PATH=".:" + include)
pattern = re.compile(r"^(\S+)\((\d+)(?:,(\d+))?\) : ERROR (\d+)", re.M)


def errors(text):
    return [(m.group(4), m.group(2), m.group(3)) for m in pattern.finditer(text)]


files = [l.strip() for l in open(sys.argv[1]) if l.strip()]
count = different = 0
for path in files:
    folder, name = os.path.dirname(path), os.path.basename(path)
    try:
        a = subprocess.run([SBL, "-bf", "-n", name], cwd=folder, capture_output=True, text=True, errors="replace", timeout=30, env=env,
                           stdin=subprocess.DEVNULL)
        b = subprocess.run(["dotnet", DLL, "-bf", "-n", name], cwd=folder, capture_output=True, text=True, errors="replace", timeout=60,
                           env=env, stdin=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        print("TIMEOUT", path)
        continue
    count += 1
    ea, eb = errors(a.stdout), errors(b.stdout)
    if ea != eb:
        different += 1
        print("DIFF", path)
        print("  sbl", ea[:6])
        print("  net", eb[:6])
print("files", count, "differ", different)
