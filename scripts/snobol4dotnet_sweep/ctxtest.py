#!/usr/bin/env python3
# ctxtest.py CLASS NAMESPACE OUTFILE SUMMARY NAME=CTX;;CTX@VALUE,VALUE ... : write a C# test class whose tests apply the named contexts of
# ctxgen.py to the named values and expect the lines sbl -b printed for the same program. SUMMARY's \n are line breaks of the doc comment.
# Run it from an empty scratch directory. Never give it an OUTFILE that exists: it would be overwritten.
import os, re, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ctxgen import CTX, HEAD, VALUES

SBL = os.environ.get("SBL", "/home/resources/x64/bin/sbl")
cls, namespace, outfile, summary = sys.argv[1:5]
if os.path.exists(outfile):
    sys.exit("%s exists" % outfile)

tests = []
for argument in sys.argv[5:]:
    name, rest = argument.split("=", 1)
    contexts, values = rest.split("@")
    body = []
    for ii, i in enumerate([CTX.index(c) for c in contexts.split(";;")]):
        for k, vn in enumerate(values.split(",")):
            tag = "%d.%s" % (i, vn)
            body += ["        &ERRTYPE = 0", "        V = %s" % VALUES[vn], "        L = ''",
                     "        %s   :S(S%d_%d)F(F%d_%d)" % (CTX[i].format(v="V"), ii, k, ii, k),
                     "S%d_%d   OUTPUT = '%s ok ' &ERRTYPE   :(N%d_%d)" % (ii, k, tag, ii, k),
                     "F%d_%d   OUTPUT = '%s fail ' &ERRTYPE" % (ii, k, tag), "N%d_%d" % (ii, k)]
    text = "\n".join(HEAD + body) + "\nEND"
    open("ctxtest.sno", "w").write(text + "\n")
    r = subprocess.run([SBL, "-b", "ctxtest.sno"], stdin=subprocess.DEVNULL, capture_output=True, text=True, errors="replace")
    expected = [m.group(0) for m in re.finditer(r"^\d+\.[A-Z]+ .*$", r.stdout + r.stderr, re.M)]
    tests.append((name, text, "\n".join(expected)))

quote = lambda s: s.replace('"', '""')
code = "using Test.TestLexer;\n\nnamespace %s;\n\n/// <summary>\n%s\n/// </summary>\n[DoNotParallelize]\n[TestClass]\npublic class %s\n{\n" % (
    namespace, "\n".join("/// " + line for line in summary.split("\\n")), cls)
for name, text, expected in tests:
    code += '    [TestMethod]\n    public void TEST_%s_%s()\n    {\n        var s = @"\n%s";\n        Assert.AreEqual(@"%s", SetupTests.RunWithInput(s));\n    }\n\n' % (
        cls, name, quote(text), quote(expected))
open(outfile, "w").write(code.rstrip("\n") + "\n}\n")
print("wrote", outfile, len(tests), "tests")
