#!/usr/bin/env python3
# batchsweep.py SEED PROGRAMS PER [plain] : statements of the corpus programs, each mutated (a character put in, taken out or changed;
# `plain` leaves them as they are), PER to a program with the marker `OUTPUT = '@n'` before each, run under sbl -bf -k and the console
# with &ERRLIMIT large, so that an error in one statement does not end the program. What each statement printed (between its marker and
# the next) is compared; the first statement of a program where the two differ is printed with what each wrote. A difference is a defect
# of this project unless the statements before it changed what it reads (read the earlier ones first), or sbl itself crashes.
# Statements that read input, call the system, trace, define functions or operators, or end the program are left out. Needs the corpus
# (CORPUS, default $S4E_CORPUS, else /home/corpus) and the Release console of the clone S4E_DOTNET_ROOT names. Run it from an empty scratch directory.
import glob, os, random, re, subprocess, sys

SBL = os.environ.get("SBL", "/home/resources/x64/bin/sbl")
here = os.path.dirname(os.path.abspath(__file__))
DLL = os.environ.get("DLL", os.path.join(os.environ.get("S4E_DOTNET_ROOT", "/home/claude_dotnet"), "Snobol4", "bin", "Release", "net10.0", "Snobol4.dll"))
CORPUS = os.environ.get("CORPUS", os.environ.get("S4E_CORPUS", "/home/corpus"))
seed, programs, per = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
mutate_on = not (len(sys.argv) > 4 and sys.argv[4] == "plain")
rnd = random.Random(seed)

AVOID = ("INPUT", "TERMINAL", "SYSTEM", "EXIT", "HOST", "LOAD", "COLLECT", "DATE", "TIME", "OUTPUT(", "ENDFILE", "REWIND", "DETACH",
         "BACKSPACE", "SET(", "EJECT", "&STLIMIT", "&ERRLIMIT", "&TRACE", "TRACE(", "STOPTR", "SETEXIT", "UNLOAD", "&DUMP", "DUMP(",
         "&CODE", "&FTRACE", "&MAXLNGTH", "&TRIM", "&ANCHOR", "&FULLSCAN", "END", "CODE(", "EVAL(", "OPSYN", "DEFINE(", "DATA(", "&CASE")
pool = []
for path in glob.glob(CORPUS + "/**/*.sno", recursive=True) + glob.glob(CORPUS + "/**/*.spt", recursive=True):
    if os.path.basename(path) == "ALL.sno":
        continue
    try:
        lines = open(path, encoding="latin-1").read().split("\n")
    except OSError:
        continue
    for line in lines:
        if (len(line) > 10 and line[0] in " \t" and ";" not in line and line.strip() and not line.strip().startswith(("*", "-", "+", "."))
                and len(line) < 160 and all(32 <= ord(c) < 127 or c == "\t" for c in line)):
            if any(word in line.upper() for word in AVOID):
                continue
            line = re.sub(r"\s+:\s*[SFsf(<].*$", "", line)
            if ":" not in line[:3] and line.strip():
                pool.append(line)
rnd.shuffle(pool)
CHARS = list("+-*/=?.$@&|%#!~(),<>[]'\" ") + ["A", "1", "F(", "S(", "e", "X"]


def mutate(line):
    for _ in range(rnd.choice([1, 1, 2])):
        i = rnd.randrange(1, len(line) + 1)
        k = rnd.random()
        if k < 0.4:
            line = line[:i] + rnd.choice(CHARS) + line[i:]
        elif k < 0.7 and i < len(line):
            line = line[:i] + line[i + 1:]
        elif i < len(line):
            line = line[:i] + rnd.choice(CHARS) + line[i + 1:]
    return line


VOLATILE = re.compile(r"^(execution time msec|REGENERATIONS|memory used \(bytes\)|memory left \(bytes\)|stmts executed)\s.*$", re.M)


def normal(text):
    text = text.replace("macro spitbol version 4.0f", "V").replace("snobol4dotnet version 0.1", "V")
    return VOLATILE.sub(r"\1 -", re.sub(r"x86-64  .*", "D", text))


def segments(text):
    result, current = {}, None
    for line in text.split("\n"):
        m = re.match(r"^@(\d+)$", line)
        if m:
            current = int(m.group(1))
            result[current] = []
        elif current is not None:
            result[current].append(line)
    return result


different = total = 0
for p in range(programs):
    statements = [mutate(l) if mutate_on else l for l in pool[p * per:(p + 1) * per]]
    prelude = "        &ERRLIMIT = 100000\n        A = 'abc'\n        B = 12\n        C = 3.5\n        D = ARRAY(3)\n        T = TABLE()\n        P = LEN(2)\n"
    body = "".join("        OUTPUT = '@%d'\n%s\n" % (i, s) for i, s in enumerate(statements))
    open("p.sno", "w", encoding="latin-1").write(prelude + body + "        OUTPUT = '@end'\nEND\n")
    try:
        a = subprocess.run([SBL, "-bf", "-k", "p.sno"], capture_output=True, text=True, errors="replace", timeout=60, stdin=subprocess.DEVNULL)
        b = subprocess.run(["dotnet", DLL, "-bf", "-k", "p.sno"], capture_output=True, text=True, errors="replace", timeout=120,
                           stdin=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        print("TIMEOUT program", p)
        continue
    sa, sb = segments(normal(a.stdout)), segments(normal(b.stdout))
    total += len(statements)
    for i in sorted(set(sa) | set(sb)):
        if sa.get(i) != sb.get(i):
            different += 1
            print("=== statement", i, repr(statements[i]) if i < len(statements) else "")
            print("  sbl:", [x[:140] for x in (sa.get(i) or [])][:3])
            print("  net:", [x[:140] for x in (sb.get(i) or [])][:3])
            break
print("statements", total, "programs", programs, "with a difference", different)
