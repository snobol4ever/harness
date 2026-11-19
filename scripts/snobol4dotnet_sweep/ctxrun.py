#!/usr/bin/env python3
# ctxrun.py [CTX-INDEX...] : run each context of ctxgen.py against every value, as a separate program, under sbl -bf and the dotnet console, and
# print the differences ("context [VALUE]  sbl: ...  net: ..."). A run that ends early (a crash, a hang) is repeated value by value, so
# each value is accounted for: "CRASH <Exception>" or "TIMEOUT" stand in for the missing line. Run it from an empty scratch directory.
import os, re, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ctxgen import CTX, VALUES, program

REPO = os.environ.get("S4E_DOTNET_ROOT", "/home/claude_dotnet")
SBL = os.environ.get("SBL", "/home/resources/x64/bin/sbl")
NET = ["dotnet", os.environ.get("DLL", os.path.join(REPO, "Snobol4", "bin", "Release", "net10.0", "Snobol4.dll"))]


def run(cmd, path):
    try:
        r = subprocess.run(cmd + ["-bf", path], stdin=subprocess.DEVNULL, capture_output=True, timeout=20, text=True, errors="replace")
        return r.stdout + r.stderr
    except subprocess.TimeoutExpired:
        return "TIMEOUT"


def lines(text):
    return {m.group(1): m.group(0) for m in re.finditer(r"^(\d+\.[A-Z]+) .*$", text, re.M)}


def crash(text):
    m = re.search(r"UNEXPECTED EXCEPTION \*\*\*\s*\n\s*\n(\w+): ", text)
    return "CRASH " + m.group(1) if m else ("TIMEOUT" if text == "TIMEOUT" else None)


if __name__ == "__main__":
    names = list(VALUES)
    for i in [int(a) for a in sys.argv[1:]] or range(len(CTX)):
        open("ctxtmp.sno", "w").write(program(i, names))
        sbl, net = lines(run([SBL], "ctxtmp.sno")), lines(run(NET, "ctxtmp.sno"))
        if len(net) < len(names):
            net = {}
            for vn in names:
                open("ctxtmp.sno", "w").write(program(i, [vn]))
                text = run(NET, "ctxtmp.sno")
                tag = "%d.%s" % (i, vn)
                net[tag] = lines(text).get(tag) or "%s %s" % (tag, crash(text) or "NOOUTPUT")
        for vn in names:
            tag = "%d.%s" % (i, vn)
            a, b = sbl.get(tag, tag + " (no sbl line)"), net.get(tag, tag + " (no net line)")
            if a != b:
                print("%-34s sbl: %-22s net: %s" % (CTX[i].replace("{v}", "V") + " [" + vn + "]", a[len(tag) + 1:], b[len(tag) + 1:]))
