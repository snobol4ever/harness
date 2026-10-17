#!/usr/bin/env bash
# lib_declared_arena.sh -- THE ONE READER OF A TEST'S DECLARED ARENA, for every runner that is not the
# Python harness. Source it; never copy a line of it (RULES.md, lib_* are SOURCED AUTHORITIES).
#
# ⛔⭐⭐ WHY THIS EXISTS AT ALL. Lon, 2026-09-23, in-chat to the ceo, verbatim: "Well, each test should have
# the needed amount of memory in the attribute TSV/CSV files." (routed CEO-1167). Before that word, a
# program whose live set did not fit the shipped window was a capacity red and an argument for raising the
# default for EVERYBODY. After it, the program DECLARES what it needs, in KB, in its suite's ALL.csv, and
# the runner exports SCRIP_HEAP_KB FOR THAT PROGRAM ONLY. corpus_suite_harness.py reads the same column
# through heap_declarations(); eight package runners execute programs directly and cannot call it, which is
# exactly how one question gets nine written answers. It gets one here.
#
# ⛔ A DECLARATION IS NOT A PIN. A pin is a runner or a gate deciding an arena for a program from the
# outside; util_arena_pin_census.py hunts those and has since CEO-1146. A declaration is the TEST saying
# what it needs, carried in the test's own attribute row, reviewable in a diff, and carried forward across
# every rebuild by both suite builders. The census learns the column so the two are told apart by evidence
# rather than by which file the number happens to sit in.
#
# ⛔⭐⭐ THE FLOOR IS NOT A STYLE RULE AND IT IS THE ONE THING A READER OF THIS FILE MUST NOT "TIDY AWAY".
# src/runtime/rt/gc_heap.c:
#     cap_kb = (long)GC_HEAP_CAP_KB; if (cap_kb < kb) cap_kb = kb;
# with #define GC_HEAP_CAP_KB 4096. So SCRIP_HEAP_KB moves the INITIAL WINDOW always, and the HARD CAP only
# once it climbs past 4096. MEASURED by the coo 2026-09-23, one binary, one 60000-element Icon witness:
#     SCRIP_HEAP_KB=128  -> rc=134, runtime prints "THE CAP IS 4096 KB"
#     SCRIP_HEAP_KB=2048 -> rc=134, runtime prints "THE CAP IS 4096 KB"
#     SCRIP_HEAP_KB=4096 -> rc=134, runtime prints "THE CAP IS 4096 KB"
#     SCRIP_HEAP_KB=4097 -> rc=134, runtime prints "THE CAP IS 4100 KB"   <- the cap moves here, not before
#     SCRIP_HEAP_KB=8192 -> rc=0
# A cell reading 2048 therefore declares NOTHING ABOUT CAPACITY -- the program it names reaches 4096 KB with
# or without it -- while reading to every downstream consumer exactly like a capacity declaration. That is
# the pin-the-runtime-silently-overrides class COO-151 caught one instrument ago, and the baton's own
# guardrail (matched at that arena, NOT matched one step below) is UNPROVABLE for such a cell: one step
# below carries the same cap, so both arms read the same and the evidence is vacuous. Refused, loudly, rc=2.
# ââ­â­ THE RULE, IN THE READER'S OWN HEADER ON THE ceo'S INSTRUCTION:
#     A DECLARATION IS A NUMBER ABOVE THE COMPILED CAP OR IT IS NOT A DECLARATION (ceo CEO-1171, 2026-09-23, ruling on the coo's ask).
# Verbatim from the ruling: "A heap_kb cell at or below 4096 moves the initial window and not the cap,
# so it declares nothing about capacity while reading to every consumer as if it did -- the pin-that-
# the-runtime-overrides class, and your own guardrail (matched at that arena, not matched one step
# below) is vacuous for it by construction. Refusing rc=2 with that sentence is the loud direction;
# warn-and-pass would mint the false label CEO-1101 exists against."
# â SO THE FLOOR BELOW IS NOT A LOCAL CHOICE AND MAY NOT BE SOFTENED TO A WARNING. It was asked
# for as a ruling rather than taken as one, because refusing is criterion-shaped and criterion-writing
# is not the instruments seat's verb; the answer came back as law and is cited here at the constant it
# governs, so a reader who reaches for the number reaches the rule in the same glance.
# ⛔⭐⭐ CEO-1171's "above the compiled cap or not a declaration" rule is RETIRED (Lon 2026-09-25, in-chat to the ceo, verbatim: "Ensure that all the test suite programs have the stack size and heap size setting placed into the per-program attribute files."; ceo CEO-1261): every program declares its settings, a
# declaration equal to the default is a setting, not a no-op, and heap_kb is the program's MAXIMUM heap (SPITBOL -d), applied as
# SCRIP_HEAP_CAP_KB or -d<kb>k, never as the initial window -- the window stays SPITBOL's -i1m, or the tiny arena of `make test-arena`.
DECLARED_ARENA_CAP_KB=131072        # gc_heap.c #define GC_HEAP_CAP_KB (SPITBOL -d128m)
DECLARED_ARENA_MIN_KB=1024          # gc_heap.c #define GC_HEAP_KB: a maximum below the initial window is refused
DECLARED_ARENA_MAX_KB=4194304       # 4096*1024, the ceiling SCRIP_HEAP_KB itself refuses past
_LDA_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# declared_arena_kb <all_csv> <entry>
#   Echoes the declared KB for <entry>, or NOTHING when the file, the column or the cell is absent --
#   and "nothing" is the shipped default, which is the honest answer and never an error. Returns 2 and
#   echoes nothing on a cell that is present but unusable, so a caller that tests the exit code gets a
#   refusal and a caller that only reads stdout gets the default. ⛔ NOT a grep: the column's index is read
#   from the header every time, because a positional read is the defect that put heap_kb in seven feature
#   denominators the hour it landed (util_feature_coverage_census.py, cured in the same landing).
declared_arena_kb() {
  local csv="$1" entry="$2"
  [ -n "$csv" ] && [ -f "$csv" ] || return 0
  python3 - "$csv" "$entry" "$DECLARED_ARENA_CAP_KB" "$DECLARED_ARENA_MAX_KB" <<'PY'
import csv, sys
path, want, cap, mx = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
cap = 1024
try:
    with open(path, newline="") as f:
        rdr = csv.DictReader(f)
        if not rdr.fieldnames or "heap_kb" not in rdr.fieldnames:
            sys.exit(0)                      # suite not converted yet: shipped default, silently
        for n, row in enumerate(rdr, 2):
            if row.get("entry") != want:
                continue
            v = (row.get("heap_kb") or "").strip()
            if not v:
                sys.exit(0)                  # absent means the shipped default
            if not v.isdigit():
                sys.stderr.write("⛔ REFUSE(2) %s:%d heap_kb=%r is not a plain integer count of KB -- a "
                                 "declaration is a measurement, and a cell no reader can parse is not one\n"
                                 % (path, n, v))
                sys.exit(2)
            k = int(v)
            if k < cap:
                sys.stderr.write("⛔ REFUSE(2) %s:%d heap_kb=%d is below the %d KB initial window: heap_kb is the program's "
                                 "MAXIMUM heap (SPITBOL -d) and a maximum under the window cannot be honoured (ceo CEO-1261)\n"
                                 % (path, n, k, cap))
                sys.exit(2)
            if k > mx:
                sys.stderr.write("⛔ REFUSE(2) %s:%d heap_kb=%d is above the %d KB ceiling SCRIP_HEAP_KB itself "
                                 "refuses -- the runtime would abort on this value rather than run at it\n"
                                 % (path, n, k, mx))
                sys.exit(2)
            print(k)
            sys.exit(0)
    _lg = __import__("os").environ.get("SCRIP_DECL_MISS_LOG")
    if _lg: open(_lg, "a").write("%s\t%s\n" % (path, want))
except OSError:
    sys.exit(0)
PY
}

# declared_arena_kb_beside <program>
#   Echoes the declared KB for a STANDALONE program -- a benchmark, an extracted entry -- from the <stem>.heap
#   sidecar beside it, or NOTHING when there is none. ⭐ WHY A SECOND FUNCTION AND NOT A SECOND FORMAT (coo
#   2026-09-23, row instruments-benchmarks-enter-the-suite-grid-..., on hq_snocone's ask): a benchmark tree has no
#   ALL.csv, and demo/json.sc needs 16384 KB (two ARRAY(262144) abort at the 4096 KB cap). The harness already
#   defines this sidecar (heap_sidecar_path, written by extract-family: one line NAME<TAB>KB), so the benchmark
#   runners read THAT file through THAT code -- corpus_suite_harness.heap_declarations() is CALLED, never copied,
#   and its validator carries CEO-1171's floor. ⛔ A .heap FILE THAT DECLARES NOTHING FOR THE PROGRAM BESIDE IT IS
#   REFUSED rc=2, never read as "no declaration": a bare `16384` line splits on TAB into a name and an EMPTY kb,
#   which the harness reads as absent, so the declaration would vanish while the file sat there claiming it.
#   rc 2 with nothing echoed on any unusable sidecar, so a caller testing the exit code gets the refusal.
declared_arena_kb_beside() {
  local prog="$1"
  [ -n "$prog" ] && [ -f "${prog%.*}.heap" ] || return 0
  python3 - "$prog" "$_LDA_HERE" <<'PY'
import os, sys
prog, here = sys.argv[1], sys.argv[2]
sys.path.insert(0, here)
import corpus_suite_harness as h
side = h.heap_sidecar_path(prog)
decl, src = h.heap_declarations(prog)
stem = os.path.splitext(os.path.basename(prog))[0]
if src != os.path.basename(side) or stem not in decl:
    sys.stderr.write("⛔ REFUSE(2) %s declares no heap for %s: the sidecar's format is one line NAME<TAB>KB with NAME=%s "
                     "(the harness's own, heap_sidecar_path) -- a bare number or another program's name is not a "
                     "declaration for this one, and reading it as absent would drop the declaration silently\n"
                     % (side, os.path.basename(prog), stem))
    sys.exit(2)
print(decl[stem])
PY
}

# run_at_declared_arena <all_csv> <entry> -- <command...>
#   Runs the command with SCRIP_HEAP_KB exported IFF <entry> declares one, and with the caller's
#   environment otherwise byte-identical to what it was before this lib existed. ⛔ THE SUBSHELL IS THE
#   POINT: an export that leaked would put one program's declared arena under every program after it in the
#   loop, which is a runner pinning an arena -- the exact thing a declaration replaces, reintroduced by the
#   mechanism meant to retire it.
run_at_declared_arena() {
  local csv="$1" entry="$2"; shift 2
  [ "$1" = "--" ] && shift
  local kb st; kb=$(declared_arena_kb "$csv" "$entry") || return 2
  st=$(declared_stack_kb "$csv" "$entry") || return 2
  ( [ -n "$kb" ] && export SCRIP_HEAP_CAP_KB="$kb"; [ -n "$st" ] && export SCRIP_STACK="${st}k"; "$@" )
}

# ⭐ THE STACK, THE HEAP'S TWIN (Lon 2026-09-23 18:3x, in-chat to the ceo: "an attribute of stack and heap sizes be added to the TSV
# admin files for the test suites"; CEO-1225; the coo). The runtime raises RLIMIT_STACK at init to SCRIP_STACK when it is set and to
# its 64 MB floor when it is not (src/runtime/core/core.c), in BOTH modes -- the one variable sizes the m3 process and the m4 binary
# alike until the cto's switch row makes it -s. ⛔ THE FLOOR IS CEO-1171's RULE, AND FOR THE STACK IT CUTS BOTH WAYS: the variable
# REPLACES the floor, so a cell below 65536 SHRINKS the stack under every undeclared neighbour's -- MEASURED 2026-09-23 on one binary:
# a 100000-deep Icon recursion completes at the default and dies with ERROR 246 at SCRIP_STACK=16384k, while a 200000-deep one dies
# at the default and completes at 262144k, in m3 and m4 -- and a cell AT the floor changes nothing while reading as a declaration.
DECLARED_STACK_FLOOR_KB=64          # the least stack a declaration may name; SPITBOL's -s4m is the default (rt_stack_overflow.c RT_STACK_DEFAULT_BYTES)
DECLARED_STACK_MAX_KB=4194304       # a declared stack past 4 GB is refused as a typo

# declared_stack_kb <all_csv> <entry> -- the stack_kb twin of declared_arena_kb: the KB, nothing (absent = the floor), or rc 2.
declared_stack_kb() {
  local csv="$1" entry="$2"
  [ -n "$csv" ] && [ -f "$csv" ] || return 0
  python3 - "$csv" "$entry" "$DECLARED_STACK_FLOOR_KB" "$DECLARED_STACK_MAX_KB" <<'PY'
import csv, sys
path, want, flr, mx = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
try:
    with open(path, newline="") as f:
        rdr = csv.DictReader(f)
        if not rdr.fieldnames or "stack_kb" not in rdr.fieldnames:
            sys.exit(0)
        for n, row in enumerate(rdr, 2):
            if row.get("entry") != want:
                continue
            v = (row.get("stack_kb") or "").strip()
            if not v:
                sys.exit(0)
            if not v.isdigit():
                sys.stderr.write("⛔ REFUSE(2) %s:%d stack_kb=%r is not a plain integer count of KB\n" % (path, n, v)); sys.exit(2)
            k = int(v)
            if k < flr:
                sys.stderr.write("⛔ REFUSE(2) %s:%d stack_kb=%d is below the %d KB least stack a declaration may name (ceo CEO-1261)\n" % (path, n, k, flr))
                sys.exit(2)
            if k > mx:
                sys.stderr.write("⛔ REFUSE(2) %s:%d stack_kb=%d is above the %d KB ceiling a stack declaration may name\n" % (path, n, k, mx))
                sys.exit(2)
            print(k); sys.exit(0)
    _lg = __import__("os").environ.get("SCRIP_DECL_MISS_LOG")
    if _lg: open(_lg, "a").write("%s\t%s\n" % (path, want))
except OSError:
    sys.exit(0)
PY
}

# declared_stack_kb_beside <program> -- the <stem>.stack sidecar of a standalone program (a benchmark, an extracted entry), read
# through corpus_suite_harness.stack_declarations(), exactly as declared_arena_kb_beside reads <stem>.heap; rc 2 on a sidecar that
# declares nothing for the program beside it.
declared_stack_kb_beside() {
  local prog="$1"
  [ -n "$prog" ] && [ -f "${prog%.*}.stack" ] || return 0
  python3 - "$prog" "$_LDA_HERE" <<'PY'
import os, sys
prog, here = sys.argv[1], sys.argv[2]
sys.path.insert(0, here)
import corpus_suite_harness as h
side = h.stack_sidecar_path(prog)
decl, src = h.stack_declarations(prog)
stem = os.path.splitext(os.path.basename(prog))[0]
if src != os.path.basename(side) or stem not in decl:
    sys.stderr.write("⛔ REFUSE(2) %s declares no stack for %s: the sidecar's format is one line NAME<TAB>KB with NAME=%s\n"
                     % (side, os.path.basename(prog), stem))
    sys.exit(2)
print(decl[stem])
PY
}

# declared_oracle_env_beside <program> -- the ORACLE's declared environment for a standalone unit (ceo CEO-1353, clause 8 (g)(3)), from
#   its <stem>.oracle_env sidecar (one line NAME<TAB>VAR=VALUE[ VAR=VALUE]), read by corpus_suite_harness.oracle_env_declarations --
#   CALLED, never copied. Echoes the VAR=VALUE words for `env WORDS oracle ...`, nothing when there is no sidecar; rc 2 with nothing
#   echoed on another unit's name, a knob outside ORACLE_ENV_ADMITTED, or a value that is not a positive integer.
declared_oracle_env_beside() {
  local prog="$1"
  [ -n "$prog" ] && [ -f "${prog%.*}.oracle_env" ] || return 0
  python3 - "$prog" "$_LDA_HERE" <<'PY'
import sys
prog, here = sys.argv[1], sys.argv[2]
sys.path.insert(0, here)
import corpus_suite_harness as h
print(" ".join(h.oracle_env_declarations(prog)))
PY
}

# declared_oracle_args_beside <program> -- the ORACLE's declared command-line sizes for a standalone unit (ceo CEO-1353, clause 8 (g)(3)),
#   from its <stem>.oracle_args sidecar (one line NAME<TAB>SWITCH[ SWITCH]), read by corpus_suite_harness.oracle_args_declarations --
#   CALLED, never copied. Echoes the switches for `oracle SWITCHES program`, nothing when there is no sidecar (the oracle's own defaults);
#   rc 2 with nothing echoed on another unit's name, a switch outside ORACLE_ARGS_ADMITTED, a malformed size or a switch named twice.
declared_oracle_args_beside() {
  local prog="$1"
  [ -n "$prog" ] && [ -f "${prog%.*}.oracle_args" ] || return 0
  python3 - "$prog" "$_LDA_HERE" <<'PY'
import sys
prog, here = sys.argv[1], sys.argv[2]
sys.path.insert(0, here)
import corpus_suite_harness as h
print(" ".join(h.oracle_args_declarations(prog)))
PY
}

# declared_arena_receipt <all_csv> -- one line naming every declaration a board is about to honour, so the
# published row says at which arena it was graded. A board that silently honours a declaration is a board
# whose number cannot be reproduced from its own output (RULES.md THE INSTRUMENT LAWS: a number is not
# labelled until it carries its tree, mode, oracle and RT_OPT -- the arena joins that list here).
declared_arena_receipt() {
  local csv="$1"
  [ -n "$csv" ] && [ -f "$csv" ] || return 0
  python3 - "$csv" "$DECLARED_ARENA_CAP_KB" "$DECLARED_ARENA_MAX_KB" "$DECLARED_STACK_FLOOR_KB" "$DECLARED_STACK_MAX_KB" <<'PY'
import csv, sys
cap, mx = int(sys.argv[2]), int(sys.argv[3])
try:
    with open(sys.argv[1], newline="") as f:
        rdr = csv.DictReader(f)
        if not rdr.fieldnames or "heap_kb" not in rdr.fieldnames:
            print("    DECLARED ARENA: this suite's attribute file carries no heap_kb column yet -- every "
                  "entry graded at the shipped default"); sys.exit(0)
        d = [(r.get("entry"), (r.get("heap_kb") or "").strip()) for r in rdr]
    # ⛔⭐ THE RECEIPT APPLIES THE READER'S OWN VALIDATION, AND THE FIRST DRAFT DID NOT. It printed every
    # non-empty cell as an honoured declaration, so a row reading heap_kb=2048 (refused above, because it
    # grants no capacity) and a row reading heap_kb=zzz (unparseable) both came out as "graded at a declared
    # arena" -- a board would have published "3 of 4 graded at a declared arena" over a population where the
    # runner honours exactly ONE. Caught by running the selftest both directions 2026-09-23 rather than by
    # reading the code. A census that counts what the cure does not apply is the worse half of the pair
    # (COO-153, same defect, opposite direction, one tick earlier), so the two share these four lines.
    def usable(v):
        if not v.isdigit():
            return False, "unparseable"
        k = int(v)
        return (1024 <= k <= mx), ("below the 1024 KB initial window" if k < 1024 else "above the %d KB ceiling" % mx)
    named, refused = [], []
    for n, v in d:
        if not v:
            continue
        ok, why = usable(v)
        (named if ok else refused).append((n, v, why))
    if named:
        print("    DECLARED ARENA (CEO-1167): %d of %d entr(y/ies) graded at a declared arena, the rest at the "
              "shipped default -- %s" % (len(named), len(d), ", ".join("%s=%sKB" % (n, v) for n, v, _ in named)))
    else:
        print("    DECLARED ARENA (CEO-1167): 0 of %d entr(y/ies) declare one -- every entry graded at the "
              "shipped default" % len(d))
    if refused:
        print("    ⛔ DECLARED ARENA REFUSED (%d): these cells are present and are NOT honoured by the runner, "
              "so they are named here rather than counted above -- %s"
              % (len(refused), ", ".join("%s=%s (%s)" % r for r in refused)))
    # ⭐ THE STACK, SAME SHAPE (CEO-1225): the same file's stack_kb cells, the reader's own floor applied, so the receipt
    # never counts a cell the runner refuses.
    with open(sys.argv[1], newline="") as f:
        rdr = csv.DictReader(f)
        if rdr.fieldnames and "stack_kb" in rdr.fieldnames:
            st = [(r.get("entry"), (r.get("stack_kb") or "").strip()) for r in rdr]
            flr, smx = int(sys.argv[4]), int(sys.argv[5])
            ok_s = [(n, v) for n, v in st if v.isdigit() and flr <= int(v) <= smx]
            bad_s = [(n, v) for n, v in st if v and (n, v) not in ok_s]
            print("    DECLARED STACK (CEO-1225): %d of %d entr(y/ies) graded at a declared stack, the rest at the runtime's "
                  "%d KB floor%s" % (len(ok_s), len(st), flr, (" -- " + ", ".join("%s=%sKB" % x for x in ok_s)) if ok_s else ""))
            if bad_s:
                print("    ⛔ DECLARED STACK REFUSED (%d): present and NOT honoured -- %s" % (len(bad_s), ", ".join("%s=%s" % x for x in bad_s)))
except OSError:
    pass
PY
}

# ⭐ THE TABLE, FOR A RUNNER THAT GRADES HUNDREDS OF PROGRAMS (CEO-1229, the ceo to the coo 2026-09-23: "wire the ten remaining package
# runners yourself on the SWI pattern, each proven on a fixture"). run_at_declared_arena starts python twice per run, about 80 ms, which
# is over a minute of a 427-program board graded in two modes. declared_memory_table reads the attribute file ONCE and validates every
# cell through corpus_suite_harness.validate_heap_kb() and validate_stack_kb() -- the harness's own validators, CALLED, never copied --
# and run_at_declared_table looks one entry up in the result with one awk. ⛔ NOT heap_declarations(): that reader takes a SUITE path
# and reads the ALL.csv beside it, so handed any other file it read a different one, silently -- caught by this function's own
# refusal arm before it landed. ⛔ A REFUSED CELL REFUSES THE TABLE: every cell is validated before one line is written, the validator
# exits rc=2 naming the cell, and the runner refuses its board; it never grades around a cell it cannot honour. A declaring entry
# named twice is refused too: the awk below would honour the first, the harness the last.

# ⭐ AND THE UNIT'S COMPILE SWITCHES, IN THE SAME READ (clause 8 (f), CEO-1281, landing 3 of 5): a row declaring compile_args gets them as
# a 4th column, validated by corpus_suite_harness.validate_args_cell() -- CALLED, never copied -- so a runner that puts them on its own
# scrip command line reads exactly the words the harness applies, and a row declaring none prints the three columns it always did.
# ⛔ A run_args CELL IS REFUSED HERE: these runners pass argv from their own sidecars, and a declaration no reader honours grades green
# while it is ignored. The harness honours run_args for the tables it grades; this reader learns them when the argv sidecars fold in.

# declared_memory_table <all_csv> -- one line "entry<TAB>heap_kb<TAB>stack_kb" per entry declaring either (the other cell empty), with
#   "<TAB>compile_args" after them when the entry declares compile switches; nothing when the file or every column is absent (every
#   entry at the shipped default); rc 2 naming the cell on a refused cell.
declared_memory_table() {
  local csv="$1"
  [ -n "$csv" ] && [ -f "$csv" ] || return 0
  python3 - "$csv" "$_LDA_HERE" <<'PY'
import csv, sys
csv_path, here = sys.argv[1], sys.argv[2]
sys.path.insert(0, here)
import corpus_suite_harness as h
with open(csv_path, newline="") as f:
    rdr = csv.DictReader(f)
    cols = rdr.fieldnames or []
    rows = list(enumerate(rdr, 2))
out, seen = [], {}
for n, r in rows:
    where = "%s:%d" % (csv_path, n)
    kb = h.validate_heap_kb(r.get("heap_kb"), where) if "heap_kb" in cols else None
    st = h.validate_stack_kb(r.get("stack_kb"), where) if "stack_kb" in cols else None
    ca = " ".join(h.validate_args_cell(r.get("compile_args"), "compile_args", where) or []) if "compile_args" in cols else ""
    if "run_args" in cols and h.validate_args_cell(r.get("run_args"), "run_args", where):
        sys.stderr.write("⛔ REFUSE(2) %s declares run_args, and this reader's runners pass argv from their own sidecars -- a declaration no reader honours is not graded\n" % where); sys.exit(2)
    if kb is None and st is None and not ca:
        continue
    e = (r.get("entry") or "").strip()
    if not e or "\t" in e:
        sys.stderr.write("⛔ REFUSE(2) %s declares memory for an entry with no usable name (%r)\n" % (where, e)); sys.exit(2)
    if e in seen:
        if seen[e][1] == (kb, st, ca):
            continue
        sys.stderr.write("⛔ REFUSE(2) %s declares memory for %s differently from line %d -- one entry, one declaration (the same declaration repeated is one declaration)\n" % (where, e, seen[e][0])); sys.exit(2)
    seen[e] = (n, (kb, st, ca))
    out.append((e, "" if kb is None else kb, "" if st is None else st, ca))
for e, kb, st, ca in out:
    print("%s\t%s\t%s%s" % (e, kb, st, "\t" + ca if ca else ""))
PY
}

# declared_memory_begin <all_csv> <table_file> -- what a runner calls once, before its loop: prints the receipt (the published board
#   says at which heap and stack its programs ran) and writes the table; rc 2 on a refused cell, the table removed so no run can use it.
declared_memory_begin() {
  local csv="$1" tbl="$2"
  export DECL_CSV_OF_TABLE="$csv"
  declared_arena_receipt "$csv"
  declared_memory_table "$csv" > "$tbl" || { rm -f "$tbl"; return 2; }
}

# run_at_declared_table <table_file> <entry> -- <command...>
#   Runs the command with SCRIP_HEAP_KB and SCRIP_STACK exported for <entry> alone when the table declares them, the caller's
#   environment otherwise untouched -- a subshell, as in run_at_declared_arena, so no declaration leaks to the next program.
#   ⛔ rc 2 when the table FILE is missing: a runner that never built it would grade every program at the default while its receipt
#   named the declarations. ⛔ NOT `IFS=$'\t' read`: a TAB is IFS whitespace, so an empty heap cell before a stack cell would
#   collapse and hand the stack's KB to the heap.
# _decl_miss <file> <entry> -- a program looked up with no row in its suite's attribute file is logged to SCRIP_DECL_MISS_LOG when set,
# so a board run names every program the attribute file does not yet list (Lon 2026-09-25: every test program carries its settings;
# ceo CEO-1261). Silent and free when the variable is unset.
_decl_miss() { [ -n "${SCRIP_DECL_MISS_LOG:-}" ] && printf '%s\t%s\n' "$1" "$2" >> "$SCRIP_DECL_MISS_LOG"; return 0; }
run_at_declared_table() {
  local tbl="$1" entry="$2" rec kb st; shift 2
  [ "${1:-}" = "--" ] && shift
  [ -n "$tbl" ] && [ -f "$tbl" ] || { echo "⛔ REFUSE(2) run_at_declared_table: no declared-memory table at '${tbl}' -- build it with declared_memory_begin first" >&2; return 2; }
  rec="$(awk -F'\t' -v e="$entry" '$1 == e { print $2 "|" $3; exit }' "$tbl")"
  [ -n "$rec" ] || _decl_miss "${DECL_CSV_OF_TABLE:-$tbl}" "$entry"
  kb="${rec%%|*}"; st="${rec#*|}"
  ( [ -n "$kb" ] && export SCRIP_HEAP_CAP_KB="$kb"; [ -n "$st" ] && export SCRIP_STACK="${st}k"; "$@" )
}

# ⭐ THE DECLARATION AS SWITCHES (row instruments-ninety-two-scripts-and-the-makefile-size-the-arena-through-the-env-not-the-d-switch;
# CEO-1225/1226: SCRIP sizes the heap with -d and -i and the stack with -s, as SPITBOL does, and a switch is recorded with the run where
# an environment knob is invisible in a transcript). These print the words a runner puts on its OWN scrip command line -- after --run
# for mode 3, leading the compiled binary's arguments for mode 4 -- spelled exactly as corpus_suite_harness.py's _size_switches spells
# them: a declared heap is the program's maximum heap (-d<kb>k; ceo CEO-1261 -- never -i, which would override the tiny arena of GC
# testing), a declared stack is -s<kb>k, nothing declared prints
# nothing. test_gate_declared_arena_switches_agree_with_the_harness.sh holds the two spellings together. MEASURED 2026-09-24: every
# heap_kb declared in the corpus is 8192 KB or more, where -d/-i and the old SCRIP_HEAP_KB export read the same window AND the same cap.
_declared_switch_words() {  # <heap_kb> <stack_kb> -> the words
  local kb="$1" st="$2" sw=""
  [ -n "$kb" ] && sw="-d${kb}k"
  [ -n "$st" ] && sw="${sw:+$sw }-s${st}k"
  printf '%s\n' "$sw"
}

# declared_arena_switches <all_csv> <entry> -- the entry's declared heap and stack as switches; rc 2 on a refused cell.
declared_arena_switches() {
  local kb st
  kb=$(declared_arena_kb "$1" "$2") || return 2
  st=$(declared_stack_kb "$1" "$2") || return 2
  _declared_switch_words "$kb" "$st"
}

# declared_switches_from_table <table_file> <entry> -- the same, from the table declared_memory_begin wrote; rc 2 when it is missing.
declared_switches_from_table() {
  local tbl="$1" entry="$2" rec
  [ -n "$tbl" ] && [ -f "$tbl" ] || { echo "⛔ REFUSE(2) declared_switches_from_table: no declared-memory table at '${tbl}' -- build it with declared_memory_begin first" >&2; return 2; }
  rec="$(awk -F'\t' -v e="$entry" '$1 == e { print $2 "|" $3; exit }' "$tbl")"
  [ -n "$rec" ] || _decl_miss "${DECL_CSV_OF_TABLE:-$tbl}" "$entry"
  _declared_switch_words "${rec%%|*}" "${rec#*|}"
}

# declared_compile_args_from_table <table_file> <entry> -- the entry's declared compile_args, one line of space-separated words for the
#   runner to place right after --run or --compile, before the source, in both modes (the cto's order, 2026-09-26: scrip --run CA -d -s
#   FILE -- RA; scrip --compile CA FILE); nothing when it declares none; rc 2 when the table is missing. The words were validated when
#   the table was written, so they hold no quote, comma or tab and split on spaces as the harness splits them.
declared_compile_args_from_table() {
  local tbl="$1" entry="$2"
  [ -n "$tbl" ] && [ -f "$tbl" ] || { echo "⛔ REFUSE(2) declared_compile_args_from_table: no declared-memory table at '${tbl}' -- build it with declared_memory_begin first" >&2; return 2; }
  awk -F'\t' -v e="$entry" '$1 == e { print $4; exit }' "$tbl"
}

# declared_row_in_table <table_file> <entry> -- rc 0 when the entry declares something in the declared-memory table, rc 1 when it
#   declares nothing (no row, or a row whose heap_kb, stack_kb and compile_args are all empty, which declared_memory_table leaves out
#   of the table), rc 2 when the table is missing. ⛔ A MISSING ROW IS NAMED ON STDERR, EVERY TIME (RULES.md 8 (f): "A declaration that is missing is a gap
#   the runner names, never a default silently taken"): the three lookups above answer "nothing declared" alike for a row that declares
#   nothing and for a unit with no row at all, and _decl_miss logs only when SCRIP_DECL_MISS_LOG is set -- so 382 driver-graded Icon
#   units ran at the runtime's defaults from SCRIP 286483382 until hq_icon asked where IPL iftrace's --stlimit lives (2026-09-27), and
#   no line of any board said so. A runner asks this once per unit it grades and prints the names it collected, empty or not.
declared_row_in_table() {
  local tbl="$1" entry="$2"
  [ -n "$tbl" ] && [ -f "$tbl" ] || { echo "⛔ REFUSE(2) declared_row_in_table: no declared-memory table at '${tbl}' -- build it with declared_memory_begin first" >&2; return 2; }
  awk -F'\t' -v e="$entry" '$1 == e { f = 1; exit } END { exit !f }' "$tbl" && return 0
  _decl_miss "${DECL_CSV_OF_TABLE:-$tbl}" "$entry"
  echo "⛔ UNDECLARED (RULES.md 8 (f)): $entry declares nothing in ${DECL_CSV_OF_TABLE:-its attribute file} (no row, or every cell empty) -- graded at the runtime's defaults, a gap named here, never a default taken silently" >&2
  return 1
}

# declared_switches_beside <program> -- the program's declared heap and stack as SPITBOL's switches (-d<kb>k -s<kb>k), read from its
# <stem>.heap and <stem>.stack sidecars exactly as test_prolog_bench_suite.sh reads them, for a runner that puts them on the scrip
# command line (after --run, before the source) or at the head of a compiled binary's own command line -- the form CEO-1225 chose over
# an environment knob because a switch is recorded with the run. Echoes nothing when neither sidecar exists (the shipped defaults, the
# honest answer) and rc 2 on a sidecar the reader refuses. ⛔ NEVER SCRIP_HEAP_KB: gc_heap.c:218 reads that variable as the INITIAL
# WINDOW, so a declaration equal to the 131072 KB default cap exported through it would hand a benchmark a 128 MB window and a collector
# that never runs. ⛔ WHY (ceo CEO-1281, 2026-09-26): the Prolog benchmark angles ran scrip --run <k>.pl with no declaration at all while
# the suite runner honoured the sidecars, so tak overflowed the shipped 4 MB stack inside angle 1's own correctness gate and was SKIPped
# on every engine -- an instrument gap printed in a kernel finding's words. MEASURED the same sitting: tak(18,12,6) completes at
# -s65536k and overflows at -s32768k in both modes; swipl needs 16 MB of its own (--stack-limit=8m overflows too), so the need is the
# program's choice points and the declaration is the cure, never a raised default (Lon 2026-09-25: every program declares its stack and
# heap; Lon 2026-09-26: the command-line arguments a test unit needs, compile time and run time, are stored with the test unit).
declared_switches_beside() {
  local prog="$1" kb st
  kb=$(declared_arena_kb_beside "$prog") || return 2
  st=$(declared_stack_kb_beside "$prog") || return 2
  _declared_switch_words "$kb" "$st"
}
# undeclared_beside_named <program> -- a STANDALONE unit (a benchmark kernel, a demo) that carries neither a .heap nor a .stack sidecar
#   is NAMED on stdout, in the run's own output, and rc 1; a unit declaring either is silent, rc 0. The standalone counterpart of
#   declared_row_in_table's naming (RULES.md 8 (f): "A declaration that is missing is a gap the runner names, never a default silently
#   taken"; ceo CEO-1353, the coo's ask to hq_raku 2026-09-28: "an undeclared unit is NAMED in the run's own output").
undeclared_beside_named() {
  local prog="$1"
  [ -f "${prog%.*}.heap" ] || [ -f "${prog%.*}.stack" ] && return 0
  echo "⛔ UNDECLARED (RULES.md 8 (f)): $(basename "$prog") has no .heap or .stack sidecar beside it -- run at the runtime's defaults, a gap named here, never a default taken silently"
  return 1
}

# declared_compile_args_beside <program> -- a STANDALONE program's declared compile switches (a demo, a benchmark kernel, an extracted
#   entry: no ALL.csv row to read), from its <stem>.cmdline sidecar, one line NAME<TAB>compile_args<TAB>run_args, read through
#   corpus_suite_harness.cmdline_declarations() -- CALLED, never copied, as the .heap and .stack sidecars are read above. Echoes one line of
#   words for the runner to place right after --run and --compile, before the source, in both modes (the cto's order, as
#   declared_compile_args_from_table); nothing when there is no sidecar (clause 8 (f), CEO-1281, landing 4 of 5: the runner types none of
#   its own). ⛔ rc 2 on a sidecar that declares nothing for the program beside it (the name is the program's stem, as for .heap), on a
#   word outside COMPILE_ARGS_ADMITTED, and on a run_args cell: no standalone runner passes a declared argv yet, and a declaration no
#   reader honours grades green while it is ignored (declared_memory_table's rule).
declared_compile_args_beside() {
  local prog="$1"
  [ -n "$prog" ] && [ -f "${prog%.*}.cmdline" ] || return 0
  python3 - "$prog" "$_LDA_HERE" <<'PY'
import os, sys
prog, here = sys.argv[1], sys.argv[2]
sys.path.insert(0, here)
import corpus_suite_harness as h
side = h.cmdline_sidecar_path(prog)
decl, src = h.cmdline_declarations(prog)
stem = os.path.splitext(os.path.basename(prog))[0]
if src != os.path.basename(side) or stem not in decl:
    sys.stderr.write("⛔ REFUSE(2) %s declares no command line for %s: the sidecar's format is one line NAME<TAB>compile_args<TAB>run_args "
                     "with NAME=%s -- another program's name, or a file of comments, is not a declaration for this one\n"
                     % (side, os.path.basename(prog), stem))
    sys.exit(2)
ca, ra = decl[stem]
if ra:
    sys.stderr.write("⛔ REFUSE(2) %s declares run_args %s for %s, and no standalone runner passes a declared argv yet -- a declaration "
                     "no reader honours is not graded\n" % (side, " ".join(ra), stem))
    sys.exit(2)
print(" ".join(ca or []))
PY
}

# declared_chain_beside <program> <corpus_root> -- THE UNITS A DEMO IS BUILT FROM (hq_snocone and coo 2026-09-27, beauty.sc, coo
# COO-212): the <stem>.chain sidecar lists the source units the program is concatenated AFTER -- one unit per line, its path relative
# to <corpus_root>, in concatenation order, nothing else on a line. The runner concatenates the listed units then the program itself
# into one source under the program's own name and extension and runs THAT under the program's .heap/.stack/.in; the oracle cut is
# the same concatenation. Echoes the units' absolute paths one per line, rc 0; nothing and rc 0 when there is no sidecar; rc 2 on
# a blank or comment line, a line carrying whitespace, an absolute path or a .. component, a repeated unit, a sidecar naming no
# unit, or a unit that is not a file -- ⛔ a missing unit is a refusal, never a skip.
declared_chain_beside() {
  local prog="$1" root="${2:-}" side line seen=" " n=0
  side="${prog%.*}.chain"
  [ -n "$prog" ] && [ -f "$side" ] || return 0
  [ -n "$root" ] && [ -d "$root" ] || { echo "⛔ REFUSE(2) declared_chain_beside: $side needs a corpus root to resolve against (got '$root')" >&2; return 2; }
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '') echo "⛔ REFUSE(2) declared_chain_beside: $side carries a blank line -- one unit per line, nothing else" >&2; return 2 ;;
      '#'*) echo "⛔ REFUSE(2) declared_chain_beside: $side carries a comment line -- one unit per line, nothing else" >&2; return 2 ;;
      *[[:space:]]*) echo "⛔ REFUSE(2) declared_chain_beside: $side line '$line' carries whitespace -- one path per line, nothing else" >&2; return 2 ;;
      /*) echo "⛔ REFUSE(2) declared_chain_beside: $side names an absolute path '$line' -- paths are relative to corpus/" >&2; return 2 ;;
      ..|../*|*/..|*/../*) echo "⛔ REFUSE(2) declared_chain_beside: $side names '$line' with a .. component -- paths are relative to corpus/" >&2; return 2 ;;
    esac
    case "$seen" in *" $line "*) echo "⛔ REFUSE(2) declared_chain_beside: $side names '$line' twice -- each unit is concatenated once" >&2; return 2 ;; esac
    seen="$seen$line "
    [ -f "$root/$line" ] || { echo "⛔ REFUSE(2) declared_chain_beside: $side names '$line', not a file under $root -- a missing unit is a refusal, never a skip" >&2; return 2; }
    printf '%s\n' "$root/$line"; n=$((n+1))
  done < "$side"
  [ "$n" -gt 0 ] || { echo "⛔ REFUSE(2) declared_chain_beside: $side names no unit -- delete the sidecar or list the units" >&2; return 2; }
}

# declared_workhorse_beside <program> -- THE BENCHMARK ROLE OF A DEMO (Lon 2026-09-27, in-chat to the ceo, verbatim: "All demos are
# benchmarks since they can be run at wall clock and perf values extracted. They are not run in loops."; ceo CEO-1313; coo COO-206): the
# <stem>.workhorse sidecar names the FULL input a demo is timed on, once, at wall clock -- its sample input and .ref are the TEST role.
# The format is one KEY<TAB>VALUE per line, '#' comments: stdin (a file beside the program holding the full input, or - for none),
# scale (the stdin file replicated N times, the DEMO-SCALE.tsv precedent), argv (the full run's arguments), why (a note). stdin is
# required. Echoes "stdin=<file|-> scale=<n> argv=<words>" and rc 0; nothing and rc 0 when there is no sidecar (the role is then owed,
# and test_demos_suite.sh counts it); rc 2 on a sidecar the reader refuses -- an unknown or repeated key, no stdin line, a stdin file
# that is not beside the program, a scale that is not a positive integer.
declared_workhorse_beside() {
  local prog="$1" side k v stdin="" scale=1 argv="" seen=" " n=0
  side="${prog%.*}.workhorse"
  [ -n "$prog" ] && [ -f "$side" ] || return 0
  while IFS=$'\t' read -r k v || [ -n "$k" ]; do
    case "$k" in ''|'#'*) continue ;; esac
    n=$((n+1))
    case "$seen" in *" $k "*) echo "⛔ REFUSE(2) declared_workhorse_beside: $side names '$k' twice -- one workhorse run, one answer" >&2; return 2 ;; esac
    seen="$seen$k "
    case "$k" in
      stdin) stdin="$v"; if [ "$v" != - ] && [ ! -f "$(dirname "$prog")/$v" ]; then echo "⛔ REFUSE(2) declared_workhorse_beside: $side's stdin '$v' is not a file beside the program" >&2; return 2; fi ;;
      scale) case "$v" in ''|*[!0-9]*|0) echo "⛔ REFUSE(2) declared_workhorse_beside: $side's scale '$v' is not a positive integer" >&2; return 2 ;; esac; scale="$v" ;;
      argv) argv="$v" ;;
      why) : ;;
      *) echo "⛔ REFUSE(2) declared_workhorse_beside: $side names an unknown key '$k' (stdin scale argv why)" >&2; return 2 ;;
    esac
  done < "$side"
  [ -n "$stdin" ] || { echo "⛔ REFUSE(2) declared_workhorse_beside: $side declares no stdin line (a file beside the program, or - for none)" >&2; return 2; }
  printf 'stdin=%s scale=%s argv=%s\n' "$stdin" "$scale" "$argv"
}

# declared_clib_beside <program> <package_root> -- THE C LIBRARY A PROGRAM LOADS (hq_icon 2026-09-27, Arizona general/cfuncs under
# CEO-1336): the <stem>.clib sidecar is one line, "<libname>.so <dir>", <dir> relative to <package_root>, a vendored C-source
# directory (every *.c in it, the headers beside them). The library is built once per content hash -- gcc -shared -fPIC, the
# distribution's own mklib.sh line -- into a per-user cache, its undefined symbols left to the loading process (libscrip_rt.so
# exports the iconx internals the C interface binds). Echoes the directory holding <libname>.so, which the runner puts on FPATH
# as ". <dir>" -- the value iconx exports for its own bin, where the distribution's build of the same sources lives. Nothing and
# rc 0 when there is no sidecar; rc 2 on a malformed line, a name that is not lib*.so, an absolute path or a .. component, a
# directory with no *.c, or a build that fails -- ⛔ a library that cannot be built is a refusal, never a skip.
declared_clib_beside() {
  local prog="$1" root="${2:-}" side line lib dir src h cache so extra
  side="${prog%.*}.clib"
  [ -n "$prog" ] && [ -f "$side" ] || return 0
  [ -n "$root" ] && [ -d "$root" ] || { echo "⛔ REFUSE(2) declared_clib_beside: $side needs a package root to resolve against (got '$root')" >&2; return 2; }
  [ "$(grep -c . "$side")" = 1 ] || { echo "⛔ REFUSE(2) declared_clib_beside: $side must be exactly one line, '<libname>.so <dir>'" >&2; return 2; }
  read -r lib dir extra < "$side"
  [ -n "$lib" ] && [ -n "$dir" ] && [ -z "$extra" ] || { echo "⛔ REFUSE(2) declared_clib_beside: $side line is not '<libname>.so <dir>'" >&2; return 2; }
  case "$lib" in lib*.so) ;; *) echo "⛔ REFUSE(2) declared_clib_beside: $side names '$lib', not lib*.so" >&2; return 2 ;; esac
  case "$lib" in */*) echo "⛔ REFUSE(2) declared_clib_beside: $side library name '$lib' carries a path" >&2; return 2 ;; esac
  case "$dir" in /*|..|../*|*/..|*/../*) echo "⛔ REFUSE(2) declared_clib_beside: $side names '$dir' -- a path relative to the package, no .. component" >&2; return 2 ;; esac
  src="$root/$dir"
  compgen -G "$src/*.c" >/dev/null || { echo "⛔ REFUSE(2) declared_clib_beside: $side names '$dir', which holds no *.c under $root" >&2; return 2; }
  h="$(cat "$src"/*.c "$src"/*.h 2>/dev/null | sha1sum | cut -c1-12)"
  cache="${TMPDIR:-/tmp}/scrip-clib-$(id -u)/$h"; so="$cache/$lib"
  if [ ! -f "$so" ]; then
    mkdir -p "$cache" && gcc -shared -fPIC -O0 -I"$src" -o "$so.tmp.$$" "$src"/*.c 2>"$cache/build.err" && mv -f "$so.tmp.$$" "$so" \
      || { echo "⛔ REFUSE(2) declared_clib_beside: $lib from $dir did not build: $(head -c 300 "$cache/build.err")" >&2; rm -f "$so.tmp.$$"; return 2; }
  fi
  printf '%s\n' "$cache"
}
