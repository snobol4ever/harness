#!/usr/bin/env python3
# progtest.py CLASS NAMESPACE OUTFILE SUMMARY [--lines REGEX] NAME=PROGRAM.sno ... : write a C# test class with one test for each program, whose
# expected output is the lines of `sbl -b PROGRAM.sno` (stdout and stderr) that match REGEX (default: lines that begin with a digit).
# The program should print one such line per case. Run it from the directory that holds the programs; it refuses to overwrite OUTFILE.
import os, re, subprocess, sys

SBL = os.environ.get("SBL", "/home/resources/x64/bin/sbl")
args = sys.argv[1:]
lines_regex = r"^\d"
if "--lines" in args:
    i = args.index("--lines")
    lines_regex = args[i + 1]
    del args[i:i + 2]
cls, namespace, outfile, summary = args[:4]
if os.path.exists(outfile):
    sys.exit("%s exists" % outfile)

quote = lambda s: s.replace('"', '""')
code = "using Test.TestLexer;\n\nnamespace %s;\n\n/// <summary>\n%s\n/// </summary>\n[DoNotParallelize]\n[TestClass]\npublic class %s\n{\n" % (
    namespace, "\n".join("/// " + line for line in summary.split("\\n")), cls)
for argument in args[4:]:
    name, path = argument.split("=", 1)
    program = open(path).read().rstrip("\n")
    r = subprocess.run([SBL, "-b", path], stdin=subprocess.DEVNULL, capture_output=True, text=True, errors="replace")
    expected = [l for l in (r.stdout + r.stderr).split("\n") if re.match(lines_regex, l)]
    # a program that starts on the first line of the string keeps its statement numbers
    code += '    [TestMethod]\n    public void TEST_%s_%s()\n    {\n        var s = @"%s";\n        Assert.AreEqual(@"%s", SetupTests.RunWithInput(s));\n    }\n\n' % (
        cls, name, quote(program), quote("\n".join(expected)))
open(outfile, "w").write(code.rstrip("\n") + "\n}\n")
print("wrote", outfile)
