# Differential sweeps against the oracle

snobol4dotnet mimics SPITBOL, and the oracle is `sbl` (`/home/resources/x64/bin/sbl`). These scripts put many values through
one function, operator or statement shape under both `sbl -bf` and the dotnet console and print where the two differ. They
found the unhandled exceptions on `ARRAY('')`, `S<1>` of a string, `ITEM('x', 1)` and `TRACE` in a statement, and the
aggregate swap (`L = V` then `V = TABLE()` assigned `L`). A difference is a defect of this project unless the oracle itself
crashes (`ARRAY(9223372036854775807)` dumps core).

Run them from an **empty scratch directory** (they write `*.sno`, `*.sbl`, `*.net`) by their full path, as
`python3 /home/harness/scripts/snobol4dotnet_sweep/ctxrun.py 5 6`, after `dotnet build Snobol4/Snobol4.csproj -c Release` in the
clone `S4E_DOTNET_ROOT` names (default `/home/claude_dotnet`, the dotnet seat's root). `SBL` and `DLL` override the two engines,
`CORPUS` (default `$S4E_CORPUS`, else `/home/corpus`) the programs `batchsweep.py` mutates, `SNOLIB` the includes of `compilediff.py`.

Moved here from snobol4dotnet's `scripts/sweep/`, 2026-11-19, on Lon's word: the port's scripts live in harness. The C# test
classes the writers below make (`ctxtest.py`, `progtest.py`, `pagetest.py`) still belong in snobol4dotnet's `TestSnobol4`.

| script | what it does |
|---|---|
| `funcsweep.sh FUNC N` | `FUNC` called with every N-tuple of a pool of 21 values (null, blanks, numbers, reals, a name, signs, exponents), through variables so nothing is folded at compile time; prints the diff of the two runs (`N=40` shows more lines) |
| `funcgen.py FUNC N [SEED]` | the program `funcsweep.sh` runs (for 3 arguments a seeded sample of 350 of the tuples) |
| `opgen.py OP NAME` | the same for an infix operator (`OP` is the operator, `NAME` the file) over every pair of the pool; `set -f` first for `*` |
| `ctxgen.py` | the tables: `VALUES` (a value of every datatype: string, number, null, integer, real, DATA object, array, table, pattern, expression, name, code) and `CTX` (95 statements, each with the value as `V`: operands, function arguments, pattern positions, subscripts, keyword assignments); `python3 ctxgen.py` lists them |
| `ctxrun.py [N...]` | every context (or those numbered) against every value, one program each, on both engines; a run that dies is repeated value by value so a crash shows as `CRASH <Exception>` and a hang as `TIMEOUT` |
| `ctxtest.py CLASS NS OUTFILE SUMMARY 'NAME=CTX;;CTX@VAL,VAL'...` | writes a C# test class whose expected lines are what `sbl -b` printed for the named contexts and values; it refuses to overwrite a file |
| `progtest.py CLASS NS OUTFILE SUMMARY NAME=PROGRAM.sno...` | writes a C# test class with one test a program, expecting the lines `sbl -b` printed that match a regex (default: lines beginning with a digit) |
| `patsweep.py [DEPTH]` | patterns built from a small grammar matched against 8 subjects on both engines; prints the cases that differ, and halves a chunk that loops until the looping pattern stands alone |
| `syntaxsweep.py FILE` | the statements of FILE (one to a line, `\n` and `\t` for a newline and a tab), each a program on its own, under both engines; prints those whose compile errors (code, line, column) differ |
| `compilediff.py LIST` | the programs named in LIST compiled without running (`-n`) under both engines, in their own folders with `SNOLIB` (the console) and `SETL4PATH` (the sbl the oracle is) on the corpus includes; prints those whose compile errors differ (the corpus: `find /home/corpus -name '*.sno' -o -name '*.spt'`; the 8-bit and the CR sources are known to differ) |
| `batchsweep.py SEED PROGRAMS PER [plain]` | mutated statements of the corpus programs, PER to a program, run under `sbl -k` and the console with `&ERRLIMIT` large; prints the first statement of each program whose output differs (found the unary-caret, selection and deferred-assignee crashes and the lost OUTPUT association) |
| `pagetest.py OUTFILE CASES.py` | writes a C# test class whose expected text is the page `sbl -b` printed for each program of CASES.py (head masked), for errors found when a program is compiled |

A sweep gives the *cases*; a fix still needs a test that is red before and green after, with the oracle's line as its
expectation (`TestSnobol4/Function/.../ArgumentRules.cs`, `NonStringValues.cs`, `KeywordAssignment.cs` are examples). Where an old
test asserts a non-SPITBOL answer, run its exact program under `sbl -b` before correcting it.
