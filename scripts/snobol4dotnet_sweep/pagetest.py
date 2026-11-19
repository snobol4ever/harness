#!/usr/bin/env python3
# pagetest.py OUTFILE CASES.py : write a C# test class whose expected text is what `sbl -b Test.sno` printed on standard output for each
# program of CASES.py, with the page head (the engine's name and the clock) masked as the tests mask it. CASES.py defines CLASS (the
# test class), SUMMARY (its comment, each line beginning ///), optionally NAMESPACE (default Test.TestSourceReader) and CASES, a list
# of (name, program) or (name, program, switches), switches as sbl and the test take them after -b (e.g. "-e"). For errors found when the program is compiled, which print the same page whatever the engine; a run-time error's
# report carries the run's time and memory, so give those programs their own tests. It refuses to overwrite OUTFILE.
import os, re, subprocess, sys, tempfile

SBL = os.environ.get("SBL", "/home/resources/x64/bin/sbl")
outfile = sys.argv[1]
namespace = {}
exec(open(sys.argv[2]).read(), namespace)
if os.path.exists(outfile):
    sys.exit("refusing to overwrite " + outfile)


def mask(text):
    text = text.replace("\r\n", "\n")
    text = re.sub(r"^(snobol4dotnet|macro spitbol) version .*$", "<identity>", text, flags=re.M)
    return re.sub(r"^\S+  [A-Z][a-z]{2} [A-Z][a-z]{2} [ \d]\d \d{2}:\d{2}:\d{2} \d{4}$", "<clock>", text, flags=re.M)


def literal(text):
    return '@"' + text.replace('"', '""') + '"'


folder = tempfile.mkdtemp()
body = []
for case in namespace["CASES"]:
    name, program = case[0], case[1]
    switches = case[2] if len(case) > 2 else ""
    open(os.path.join(folder, "Test.sno"), "w").write(program)
    r = subprocess.run([SBL, "-b"] + switches.split() + ["Test.sno"], cwd=folder, capture_output=True, text=True, errors="replace", timeout=30)
    run = 'SetupTests.RunWithInput(program)' if not switches else 'SetupTests.RunWithInputDirectives("-b %s", program)' % switches
    body.append('    [TestMethod]\n    public void TEST_%s_%s()\n    {\n        var program = %s;\n'
                '        Assert.AreEqual(%s, SetupTests.MaskListingHead(%s));\n    }\n'
                % (namespace["CLASS"], name, literal(program.rstrip("\n")), literal(mask(r.stdout).rstrip()), run))
open(outfile, "w").write("using Test.TestLexer;\n\nnamespace %s;\n\n/// <summary>\n%s\n/// </summary>\n[DoNotParallelize]\n[TestClass]\n"
                         "public class %s\n{\n%s}\n" % (namespace.get("NAMESPACE", "Test.TestSourceReader"), namespace["SUMMARY"],
                                                       namespace["CLASS"], "\n".join(body)))
print("wrote", outfile, len(body), "tests")
