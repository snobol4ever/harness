#!/usr/bin/env bash
# s4e_probe_run_switches.sh -- THE PROBES OF DESIGN-PLAN run-switches (the cto, CTO-575, 2026-11-10, amended by the cio's CIO-59 the same hour: the SCRIP
# side of the clean-up of the six masters and of corpus/packages). The table is harness/designs/run_switches/STEPS.tsv;
# test_design_run_switches_steps.sh --step N runs "bash harness/scripts/s4e_probe_run_switches.sh N". Every probe builds its own containers and packages in
# a scratch directory under /tmp/s4e/<seat>/ and reads nothing of the live corpus but the batch-grader Prolog witnesses and (step 5) the indexes; it writes
# nothing outside its scratch. Every expected text is cut from the language's oracle, live or as a committed answer file, never from SCRIP.
# One line per probe: RUNSW step=N ok=1 ... (rc 0) or RUNSW step=N ok=0 RED:<why> (rc 1); REFUSE(2) when it cannot measure (no scrip, no oracle, no scratch).
# A switch or a column SCRIP does not have yet reads RED, never REFUSED: the probe asks for it and SCRIP's refusal is the red.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
ME="${S4E_SEAT:-probe}"
N="${1:-}"
SCRIP="$S4E/SCRIP/scrip"
BG="$S4E/corpus/tests/shared/batch_grader"
refuse() { echo "REFUSE(2) [run-switches probe]: $*"; exit 2; }
[ -n "$N" ] || refuse "usage: $0 <step 1..14>"
mkdir -p "/tmp/s4e/$ME" || refuse "cannot make /tmp/s4e/$ME"
T="$(mktemp -d "/tmp/s4e/$ME/runsw_probe.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$T"' EXIT
why=""
red() { why="$why $1;"; }
verdict() { if [ -z "$why" ]; then echo "RUNSW step=$N ok=1 $1"; exit 0; fi; echo "RUNSW step=$N ok=0 RED:$why"; exit 1; }
need_scrip() {
    [ -x "$SCRIP" ] || refuse "no scrip at $SCRIP"
    printf "        OUTPUT = 'hello'\nEND\n" > "$T/hello.sno"
    [ "$(cd "$T" && timeout -k 5 30 "$SCRIP" --run hello.sno < /dev/null 2>/dev/null)" = hello ] || refuse "scrip --run hello.sno does not print hello"
}
field() { awk -F'\t' -v n="$2" -v k="$3" '$1 == n { print $k; exit }' "$1"; }
want() {   # <report> <entry> <type> [number]
    local got num
    got="$(field "$1" "$2" 2)"; num="$(field "$1" "$2" 3)"
    [ "$got" = "$3" ] || { red "$2 reads type ${got:-none}, want $3"; return 1; }
    [ -z "${4:-}" ] || [ "$num" = "$4" ] || { red "$2 reads number $num, want $4"; return 1; }
    return 0
}
same() {   # <file> <expected text> <label>
    [ -f "$1" ] || { red "$3: no file $(basename "$1")"; return 1; }
    [ "$(cat "$1")" = "$2" ] || { red "$3: reads '$(head -c 80 "$1" | tr '\n' '|')', want '$(printf '%s' "$2" | head -c 80 | tr '\n' '|')'"; return 1; }
    return 0
}
HDR='entry,group,road,nonl,timeout_s,heap_kb,stack_kb,compile_args,run_args,stage_name,dialect'
RD="        INPUT(.F, 5, 'data.txt') :F(NO)
        OUTPUT = F :(END)
NO      OUTPUT = 'absent'
END"
fence() { printf '```%s\n%s\n```\n\n' "$1" "$2"; }

step1() {   # the reader writes file fences and the stage name beside the program and runs the test (CTO-575 (2))
    need_scrip
    local C="$T/c"; mkdir -p "$C"
    printf '%s\n' "$HDR" 'f_staged,multi,staged,,,,,,,,' 'f_direct,multi,direct,,,,,,,,' 'f_after,multi,direct,,,,,,,,' 'f_named,multi,direct,,,,,,,cut_name.icn,' \
        'f_bare,multi,staged,,,,,,,,' > "$C/ALL.csv"
    {
        printf '## f_staged\n\n'; fence SNOBOL4 "$RD"; fence 'file data.txt' 'hello file'
        printf '## f_direct\n\n'; fence SNOBOL4 "$RD"; fence 'file data.txt' 'second file'
        printf '## f_after\n\n'; fence SNOBOL4 "$RD"
        printf '## f_named\n\n'; fence Icon 'procedure main()
   write(&file);
end'
        printf '## f_bare\n\n'; fence SNOBOL4 "        OUTPUT = 'a staged test with no fence and no stage name is not run'
END"
    } > "$C/MULTI.md"
    ( cd "$T" && timeout -k 5 120 "$SCRIP" --run-multi-liners "$C" --out "$T/o" --work "$T/w" > rep.tsv 2> err.txt < /dev/null ); local rc=$?
    [ "$rc" = 0 ] || red "the switch exits $rc ($(head -1 "$T/err.txt" | cut -c1-120))"
    want "$T/rep.tsv" f_staged EXIT 0 && same "$T/o/f_staged.out" 'hello file' f_staged
    want "$T/rep.tsv" f_direct EXIT 0 && same "$T/o/f_direct.out" 'second file' f_direct
    want "$T/rep.tsv" f_after EXIT 0 && same "$T/o/f_after.out" absent "f_after (the companion of the test before it must be gone)"
    want "$T/rep.tsv" f_named EXIT 0 && same "$T/o/f_named.out" cut_name.icn "f_named (the program is written under its stage_name cell)"
    want "$T/rep.tsv" f_bare DEFERRED
    [ -z "$(ls -A "$T/w" 2>/dev/null)" ] || red "the work directory still holds $(ls -A "$T/w" | head -3 | tr '\n' ' ')"
    verdict "file fences and the stage name are written and run; a staged test with neither is DEFERRED"
}

step2() {   # the builder's road rule stages only what the container does not hold (CTO-575 (2))
    local out
    out="$(cd "$S4E" && python3 - "$T" <<'PY' 2>&1
import sys, os
sys.path.insert(0, "harness/scripts")
import corpus_suite_harness as h
d = sys.argv[1] + "/cont"
os.makedirs(d)
def road(name, **kw):
    e = h.Entry("block", 1, name, ["        OUTPUT = 1", "END"], ["1"])
    for k, v in kw.items():
        setattr(e, k, v)
    return h.fmt2_road(e, d, ".sno")
print("slash=%s files=%s plain=%s cwd=%s outfiles=%s grader=%s" % (road("sub/x"), road("y", files={"data.txt": "x\n"}), road("z"), road("c", cwd="sub"),
      road("o", out_files=["a.txt"]), road("g", grader="swi-cases")))
PY
)"
    [ "$out" = "slash=direct files=direct plain=direct cwd=staged outfiles=staged grader=staged" ] || red "fmt2_road reads '$(printf '%s' "$out" | tail -1 | cut -c1-160)'"
    verdict "$out"
}

step3() {   # the reader passes the dialect column as scrip's dialect switch and refuses a dialect token in compile_args (CTO-575 (3))
    need_scrip
    local C="$T/c" D="$T/d" a b
    mkdir -p "$C" "$D" "$T/cut"
    cat > "$T/cut/dswfn.pas" <<'PAS'
program dswfn;
var glob: integer;
function countchars: integer;
begin
  countchars := 255;
  if glob = 5 then countchars := 0
  else begin inc(glob); countchars := 1 + countchars end
end;
begin
  glob := 0;
  writeln(countchars)
end.
PAS
    a="$(cd "$T/cut" && timeout -k 5 60 bash "$HERE/fpc_oracle_run.sh" -Mobjfpc dswfn.pas < /dev/null 2>/dev/null)" || refuse "fpc -Mobjfpc did not answer dswfn"
    b="$(cd "$T/cut" && timeout -k 5 60 bash "$HERE/fpc_oracle_run.sh" -Mdelphi dswfn.pas < /dev/null 2>/dev/null)" || refuse "fpc -Mdelphi did not answer dswfn"
    [ -n "$a" ] && [ -n "$b" ] && [ "$a" != "$b" ] || refuse "the oracle's two answers do not tell the dialects apart ('$a' and '$b')"
    printf '%s\n' "$HDR" 'p_objfpc,multi,direct,,,,,,,,objfpc' 'p_delphi,multi,direct,,,,,,,,delphi' > "$C/ALL.csv"
    { printf '## p_objfpc\n\n'; fence Pascal "$(cat "$T/cut/dswfn.pas")"; printf '## p_delphi\n\n'; fence Pascal "$(cat "$T/cut/dswfn.pas")"; } > "$C/MULTI.md"
    ( cd "$T" && timeout -k 5 120 "$SCRIP" --run-multi-liners "$C" --out "$T/o" > rep.tsv 2> err.txt < /dev/null ); local rc=$?
    [ "$rc" = 0 ] || red "the switch exits $rc ($(head -1 "$T/err.txt" | cut -c1-120))"
    want "$T/rep.tsv" p_objfpc EXIT 0 && same "$T/o/p_objfpc.out" "$a" "p_objfpc against fpc -Mobjfpc"
    want "$T/rep.tsv" p_delphi EXIT 0 && same "$T/o/p_delphi.out" "$b" "p_delphi against fpc -Mdelphi"
    printf '%s\n' "$HDR" 'p_both,multi,direct,,,,,--dialect=tp,,,delphi' > "$D/ALL.csv"
    { printf '## p_both\n\n'; fence Pascal "$(cat "$T/cut/dswfn.pas")"; } > "$D/MULTI.md"
    ( cd "$T" && timeout -k 5 60 "$SCRIP" --run-multi-liners "$D" --out "$T/o2" > rep2.tsv 2> err2.txt < /dev/null ); rc=$?
    [ "$rc" = 2 ] || red "a dialect cell beside a dialect token in compile_args exits $rc, want the refusal 2"
    [ ! -s "$T/rep2.tsv" ] || red "the refused container still ran a test"
    grep -c 'p_both' "$T/err2.txt" > /dev/null 2>&1 || red "the refusal does not name the entry"
    verdict "objfpc reads '$a', delphi '$b', both as fpc answers; the double declaration refuses"
}

step4() {   # one table, one accessor: the oracle's command from the language and the dialect cell (CTO-575 (4))
    local lib="$HERE/lib_oracle_flags.sh" iso fpc obj uni gnu bad rc
    [ -f "$lib" ] || refuse "no $lib"
    q() { bash -c ". '$lib' 2>/dev/null; oracle_cmd_for \"\$1\" \"\$2\"" _ "$1" "$2" 2>/dev/null; }
    iso="$(q pascal '')"; fpc="$(q pascal fpc)"; obj="$(q pascal objfpc)"; uni="$(q icon unicon)"; gnu="$(q prolog gnu)"
    case "$iso" in *-Miso*) ;; *) red "pascal with an empty cell reads '$iso', want fpc under -Miso" ;; esac
    case "$fpc" in '') red "pascal fpc reads nothing" ;; *-M*) red "pascal fpc reads '$fpc', want no mode flag" ;; esac
    case "$obj" in *-Mobjfpc*) ;; *) red "pascal objfpc reads '$obj'" ;; esac
    case "$uni" in *unicon*) ;; *) red "icon unicon reads '$uni'" ;; esac
    case "$gnu" in *gprolog*|*gplc*) ;; *) red "prolog gnu reads '$gnu'" ;; esac
    bad="$(q pascal nosuch)"; rc=$?
    [ "$rc" = 2 ] || red "an unknown dialect exits $rc, want the refusal 2"
    [ -f "$HERE/oracle_dialects.tsv" ] || red "no table harness/scripts/oracle_dialects.tsv"
    for f in corpus_suite_harness.py util_build_package_suite.py util_add_ladder_witness.py; do
        [ "$(grep -c 'oracle_cmd_for' "$HERE/$f" 2>/dev/null)" -ge 1 ] 2>/dev/null || red "$f does not read the accessor"
    done
    verdict "iso '$iso'; fpc '$fpc'; unicon '$uni'"
}

step5() {   # the dialect column is filled and the five other homes of a dialect are gone (CTO-575 (4), (5)); the acceptance over every folder
    local out
    out="$(cd "$S4E" && python3 - <<'PY' 2>&1
import csv, glob, os, re
idx = sorted(glob.glob("corpus/tests/*/ALL.csv") + glob.glob("corpus/packages/*/*/ALL.csv"))
if len(idx) < 7:
    print("REFUSE(2): %d indexes found, the corpus is not here" % len(idx)); raise SystemExit(2)
nocol, tokens, filled, rows = [], 0, 0, 0
for f in idx:
    r = list(csv.DictReader(open(f, newline="")))
    if not r:
        continue
    rows += len(r)
    if "dialect" not in r[0]:
        nocol.append(f)
    tokens += sum(1 for x in r if "--dialect=" in (x.get("compile_args") or ""))
    filled += sum(1 for x in r if (x.get("dialect") or "").strip())
side = sorted(glob.glob("corpus/packages/*/*/ALL.dialect") + glob.glob("corpus/tests/*/ALL.dialect"))
pre = sorted(glob.glob("corpus/packages/*/*/ALL.prelude"))
keys = 0
for c in glob.glob("corpus/packages/*/*/CONTRACT.tsv"):
    keys += sum(1 for l in open(c) if re.match(r"(dialect|unmarked_compile_args)\t", l))
wit = open("harness/scripts/util_add_ladder_witness.py").read()
table = 1 if re.search(r"^ORACLE = \{", wit, re.M) else 0
red = []
if nocol: red.append("%d of %d indexes have no dialect column (first %s)" % (len(nocol), len(idx), nocol[0]))
if tokens: red.append("%d compile_args cells still carry a dialect token" % tokens)
if side: red.append("%d ALL.dialect files remain" % len(side))
if pre: red.append("%d ALL.prelude files remain" % len(pre))
if keys: red.append("%d CONTRACT rows still decide a dialect" % keys)
if table: red.append("the witness tool keeps its own ORACLE table")
if not red and not filled: red.append("no entry of %d carries a dialect: the column is empty everywhere" % rows)
print("indexes=%d rows=%d dialect_cells=%d" % (len(idx), rows, filled))
if red:
    print("RED " + "; ".join(red)); raise SystemExit(1)
PY
)"; local rc=$?
    [ "$rc" = 2 ] && refuse "$(printf '%s' "$out" | tail -1)"
    [ "$rc" = 0 ] || red "$(printf '%s' "$out" | grep '^RED ' | cut -c5-400)"
    verdict "$(printf '%s' "$out" | head -1)"
}

bg_step() {   # <batch-grader step>: that plan's own probe through its own harness
    local out rc
    out="$(cd "$S4E" && S4E_HOME="$S4E" bash "$HERE/test_design_batch_grader_steps.sh" --step "$1" 2>&1)"; rc=$?
    printf '%s\n' "$out" | tail -3 | sed 's/^/    /'
    [ "$rc" = 2 ] && refuse "batch-grader step $1 could not measure"
    [ "$rc" = 0 ] || red "batch-grader step $1 reads red"
}

step6() {   # batch-grader 8b re-cut: the warm compile is ONE function both list loops call (CTO-575 (6))
    local n
    bg_step 8b
    n="$(grep -c 'scrip_warm_prolog(' "$S4E/SCRIP/src/driver/scrip.c" 2>/dev/null)"
    [ "${n:-0}" -ge 3 ] || red "scrip.c names scrip_warm_prolog( on ${n:-0} lines, want its definition and its two callers"
    verdict "batch-grader 8b green and one warm function with two callers"
}

step7() {   # batch-grader 8c: the child of a warm parent compiles only its own program
    bg_step 8c
    verdict "batch-grader 8c green"
}

pl_container() {   # <dir> <dialect cell of the last test> <witness stems...>: a format-2 Prolog container cut from the batch-grader witnesses
    local C="$1" dl="$2" w last; shift 2
    mkdir -p "$C"; printf '%s\n' "$HDR" > "$C/ALL.csv"; : > "$C/MULTI.md"
    for w in "$@"; do last="$w"; done
    for w in "$@"; do
        [ -f "$BG/$w.pl" ] && [ -f "$BG/$w.ref" ] || refuse "no witness $BG/$w.pl with its answer"
        printf '%s,multi,direct,,60,131072,4096,,,,%s\n' "$w" "$([ "$w" = "$last" ] && printf '%s' "$dl")" >> "$C/ALL.csv"
        { printf '## %s\n\n' "$w"; fence Prolog "$(cat "$BG/$w.pl")"; } >> "$C/MULTI.md"
    done
}

step8() {   # the two switches warm a Prolog selection and say so; a selection that names a dialect runs cold (CTO-575 (6))
    need_scrip
    local W="bg10_pl_hello bg11_pl_two_lines bg12_pl_redefines_last bg13_pl_imports_assoc bg14_pl_unknown_procedure_error" w one many per
    pl_container "$T/c" '' $W
    ( cd "$T" && timeout -k 5 300 "$SCRIP" --run-multi-liners "$T/c" --out "$T/o" > rep.tsv 2> err.txt < /dev/null ); local rc=$?
    [ "$rc" = 0 ] || red "the switch exits $rc"
    [ "$(grep -cE '^scrip: --run-multi-liners warm lang=prolog procs=[1-9][0-9]+$' "$T/err.txt")" = 1 ] || red "no warm line on the switch's standard error"
    for w in $W; do want "$T/rep.tsv" "$w" EXIT 0 && same "$T/o/$w.out" "$(cat "$BG/$w.ref")" "$w against swipl"; done
    pl_container "$T/g" gnu bg10_pl_hello bg11_pl_two_lines
    ( cd "$T" && timeout -k 5 300 "$SCRIP" --run-multi-liners "$T/g" --out "$T/og" > repg.tsv 2> errg.txt < /dev/null )
    [ "$(grep -c 'warm' "$T/errg.txt")" = 0 ] || red "a selection that names a dialect was warmed"
    want "$T/repg.tsv" bg10_pl_hello EXIT 0
    command -v perf > /dev/null 2>&1 || refuse "no perf for the instruction count"
    pl_container "$T/c1" '' bg10_pl_hello
    printf '%s\n' "$HDR" > "$T/c21.csv"; mkdir -p "$T/c21"; : > "$T/c21/MULTI.md"
    for w in $(seq -w 1 21); do printf 'h%s,multi,direct,,60,131072,4096,,,,\n' "$w" >> "$T/c21.csv"; { printf '## h%s\n\n' "$w"; fence Prolog "$(cat "$BG/bg10_pl_hello.pl")"; } >> "$T/c21/MULTI.md"; done
    mv "$T/c21.csv" "$T/c21/ALL.csv"
    icount() { ( cd "$T" && perf stat -x, -e instructions:u -o "$T/perf.$2" timeout -k 5 600 "$SCRIP" --run-multi-liners "$1" --out "$T/op.$2" > /dev/null 2>&1 < /dev/null ); awk -F, '/instructions/ {print $1; exit}' "$T/perf.$2"; }
    one="$(icount "$T/c1" a)"; many="$(icount "$T/c21" b)"
    case "$one$many" in ''|*[!0-9]*) refuse "perf stat gave no instruction count ('$one' and '$many')" ;; esac
    per=$(( (many - one) / 20 ))
    [ "$per" -lt 600000000 ] || red "a marginal Prolog test costs $per instructions, want under 600000000"
    verdict "warm line printed, five witnesses match swipl, a marginal test costs $per instructions"
}

pkg() {   # a scratch package in the distribution's own layout (CIO-59): programs in sub/, our files beside them, one index at the root
    local P="$1"
    mkdir -p "$P/sub/deep"
    printf 'top line\n' > "$P/top.txt"; printf 'beside line\n' > "$P/sub/data.txt"
    printf "        INPUT(.F, 5, 'data.txt') :F(NO)\n        OUTPUT = F\n        OUTPUT(.G, 6, 'made.txt')\n        G = 'made'\n        ENDFILE(6)\n        OUTPUT(.H, 7, 'data.txt')\n        H = 'spoiled'\n        ENDFILE(7) :(END)\nNO      OUTPUT = 'absent'\nEND\n" > "$P/sub/a.sno"
    printf "        INPUT(.M, 5, 'made.txt') :S(SEEN)\n        OUTPUT = 'clean'\n        INPUT(.F, 6, 'data.txt')\n        OUTPUT = F\n        INPUT(.U, 7, '../top.txt')\n        OUTPUT = U :(END)\nSEEN    OUTPUT = 'the file of the test before is still here'\nEND\n" > "$P/sub/b.sno"
    printf "LOOP    OUTPUT = INPUT :S(LOOP)\nEND\n" > "$P/sub/c.sno"; printf 'in one\nin two\n' > "$P/sub/c.in"
    printf "        OUTPUT = HOST(0)\nEND\n" > "$P/sub/deep/d.sno"
    printf "        OUTPUT = 'never run by the switch'\nEND\n" > "$P/sub/e.sno"
}

step9() {   # run-files runs a package's own files from a copy, never writes in the package, and restores the test's directory (CTO-575 (7))
    need_scrip
    local P="$T/pkg"; pkg "$P"
    printf '%s\n' 'entry,path,timeout_s,heap_kb,stack_kb,compile_args,dialect,grader' 'sub/a,sub/a.sno,,,,,,' 'sub/b,sub/b.sno,,,,,,' > "$P/ALL.csv"
    ( cd "$P" && find . -type f -exec md5sum {} + | sort -k2 ) > "$T/before.txt"
    ( cd "$T" && timeout -k 5 120 "$SCRIP" --run-files "$P" --out "$T/o" --work "$T/w" > rep.tsv 2> err.txt < /dev/null ); local rc=$?
    [ "$rc" = 0 ] || red "the switch exits $rc ($(head -1 "$T/err.txt" | cut -c1-120))"
    want "$T/rep.tsv" sub/a EXIT 0 && same "$T/o/sub_a.out" 'beside line' "sub/a (a file beside the program is read)"
    want "$T/rep.tsv" sub/b EXIT 0 && same "$T/o/sub_b.out" "$(printf 'clean\nbeside line\ntop line')" "sub/b (the directory is restored; a parent-relative path resolves)"
    ( cd "$P" && find . -type f -exec md5sum {} + | sort -k2 ) > "$T/after.txt"
    cmp -s "$T/before.txt" "$T/after.txt" || red "the package directory changed under the run: $(diff "$T/before.txt" "$T/after.txt" | head -2 | tr '\n' ' ')"
    [ -z "$(find "$T/w" -type l 2>/dev/null | head -1)" ] || red "the work directory holds a link"
    verdict "two tests ran from the copy, the package is byte-identical after, the second saw nothing of the first"
}

step10() {   # run-files reads the package index, NAME.in beside a program and ALL.args at the package root (CIO-59 as amended by CIO-60)
    need_scrip
    local P="$T/pkg"; pkg "$P"
    printf '%s\n' 'entry,path,timeout_s,heap_kb,stack_kb,compile_args,dialect,grader' 'sub/c,sub/c.sno,,,,,,' 'd,sub/deep/d.sno,,,,,,' 'nofile,,,,,,,' \
        'graded,sub/e.sno,,,,,,swi-cases' > "$P/ALL.csv"
    printf '# the arguments of a package, one line an entry: the name, then each argument after a tab (CIO-60)\n\nd\tone two\tthree\n' > "$P/ALL.args"
    ( cd "$T" && timeout -k 5 120 "$SCRIP" --run-files "$P" --out "$T/o" > rep.tsv 2> err.txt < /dev/null ); local rc=$?
    [ "$rc" = 0 ] || red "the switch exits $rc ($(head -1 "$T/err.txt" | cut -c1-120))"
    want "$T/rep.tsv" sub/c EXIT 0 && same "$T/o/sub_c.out" "$(printf 'in one\nin two')" "sub/c (NAME.in beside the program is its stdin)"
    want "$T/rep.tsv" d EXIT 0 && same "$T/o/d.out" 'one two three' "d (its line of ALL.args, an argument after each tab)"
    want "$T/rep.tsv" nofile DEFERRED
    want "$T/rep.tsv" graded DEFERRED
    printf 'missing\n' > "$T/only.txt"
    ( cd "$T" && timeout -k 5 60 "$SCRIP" --run-files "$P" --out "$T/o3" --only "$T/only.txt" > rep3.tsv 2> err3.txt < /dev/null ); rc=$?
    [ "$rc" = 2 ] || red "an --only name the index lacks exits $rc, want the refusal 2"
    printf 'd\tone two\tthree\nstranger\tx\n' > "$P/ALL.args"
    ( cd "$T" && timeout -k 5 60 "$SCRIP" --run-files "$P" --out "$T/o4" > rep4.tsv 2> err4.txt < /dev/null ); rc=$?
    [ "$rc" = 2 ] || red "an ALL.args line naming an entry the index lacks exits $rc, want the refusal 2"
    [ ! -s "$T/rep4.tsv" ] || red "the refused package still ran a test"
    verdict "stdin is read beside the program and the arguments from ALL.args; an empty file cell and a grader are DEFERRED"
}

step11() {   # a package prelude retires into the dialect switch: swi and xsb (CTO-575 (5))
    need_scrip
    local D="$S4E/harness/designs/run_switches" got
    [ -f "$D/rs11_swi_double_quotes.pl" ] && [ -f "$D/rs11_swi_double_quotes.out" ] && [ -f "$D/rs11_xsb_import.pl" ] && [ -f "$D/rs11_xsb_import.out" ] || refuse "the step 11 witnesses are not beside the table"
    cp "$D"/rs11_*.pl "$T/"
    got="$(cd "$T" && timeout -k 5 120 "$SCRIP" --dialect=swi --run rs11_swi_double_quotes.pl < /dev/null 2> "$T/e1")" || red "scrip under the swi dialect exits non-zero ($(head -1 "$T/e1" | cut -c1-100))"
    [ "$got" = "$(cat "$D/rs11_swi_double_quotes.out")" ] || red "the swi witness reads '$(printf '%s' "$got" | tr '\n' '|')', swipl reads '$(tr '\n' '|' < "$D/rs11_swi_double_quotes.out")'"
    got="$(cd "$T" && timeout -k 5 120 "$SCRIP" --dialect=xsb --run rs11_xsb_import.pl < /dev/null 2> "$T/e2")" || red "scrip under the xsb dialect exits non-zero"
    [ ! -s "$T/e2" ] || red "the xsb witness writes to standard error: $(head -1 "$T/e2" | cut -c1-100)"
    [ "$got" = "$(cat "$D/rs11_xsb_import.out")" ] || red "the xsb witness reads '$(printf '%s' "$got" | tr '\n' '|')', XSB reads '$(tr '\n' '|' < "$D/rs11_xsb_import.out")'"
    [ -z "$(ls "$S4E"/corpus/packages/*/*/ALL.prelude 2>/dev/null | head -1)" ] || red "$(ls "$S4E"/corpus/packages/*/*/ALL.prelude 2>/dev/null | wc -l) package preludes remain"
    verdict "both dialects answer their witness with no prelude, and no package holds one"
}

step12() {   # the Python post step and the package runners take the package switch
    local n m
    n="$(grep -c -- '--run-files' "$HERE/corpus_suite_harness.py" 2>/dev/null)"; m="$(grep -lc -- '--run-files' "$HERE"/lib_container_package_runner.sh "$HERE"/lib_harness_road.sh 2>/dev/null | wc -l)"
    [ "${n:-0}" -ge 1 ] || red "corpus_suite_harness.py does not name the package switch"
    [ "${m:-0}" -ge 1 ] || red "no runner library names the package switch"
    verdict "the grader and a runner library name the switch (the acceptance is the coo's same-verdict run, recorded)"
}

coll() {   # a scratch collection read in place (CIO-92, CIO-93): programs and their data in sub/, nothing of ours in it
    local C="$1"
    mkdir -p "$C/sub/deep"
    printf 'beside line\n' > "$C/sub/data.txt"
    printf "        INPUT(.F, 5, 'data.txt') :F(NO)\n        OUTPUT = F\n        OUTPUT(.G, 6, 'made.txt')\n        G = 'made'\n        ENDFILE(6)\n        OUTPUT(.H, 7, 'data.txt')\n        H = 'spoiled'\n        ENDFILE(7) :(END)\nNO      OUTPUT = 'absent'\nEND\n" > "$C/sub/a.sno"
    printf "        INPUT(.M, 5, 'made.txt') :S(SEEN)\n        OUTPUT = 'clean'\n        INPUT(.F, 6, 'data.txt')\n        OUTPUT = F :(END)\nSEEN    OUTPUT = 'the file of the test before is still here'\nEND\n" > "$C/sub/b.sno"
    printf "LOOP    OUTPUT = INPUT :S(LOOP)\nEND\n" > "$C/sub/c.sno"
    printf "        OUTPUT = HOST(0)\nEND\n" > "$C/sub/deep/d.sno"
    printf "        OUTPUT = 'collection copy'\nEND\n" > "$C/sub/h.sno"
}

step13() {   # run-files reads ALL.source: a row's program is read in place from the collection's root, run in a scratch copy of its own folder (CIO-92, CIO-93, CIO-96)
    need_scrip
    local C="$T/coll" P="$T/pkg" rc; coll "$C"
    mkdir -p "$P/sub"
    printf '%s\n' 'entry,path,timeout_s,heap_kb,stack_kb,compile_args,dialect,grader' 'sub/a,sub/a.sno,,,,,,' 'sub/b,sub/b.sno,,,,,,' 'sub/c,sub/c.sno,,,,,,' 'd,sub/deep/d.sno,,,,,,' \
        'h,sub/h.sno,,,,,,' > "$P/ALL.csv"
    printf 'root\t%s\norigin\ta scratch collection of the probe\nversion\tprobe\nlicence\tpublic domain\n' "$C" > "$P/ALL.source"
    printf 'in one\nin two\n' > "$P/sub/c.in"; printf 'd\tone two\tthree\n' > "$P/ALL.args"
    printf "        OUTPUT = 'hosted copy'\nEND\n" > "$P/sub/h.sno"
    ( cd "$C" && find . -type f -exec md5sum {} + | sort -k2 ) > "$T/before.txt"
    ( cd "$T" && timeout -k 5 120 "$SCRIP" --run-files "$P" --out "$T/o" --work "$T/w" > rep.tsv 2> err.txt < /dev/null ); rc=$?
    [ "$rc" = 0 ] || red "the switch exits $rc ($(head -1 "$T/err.txt" | cut -c1-120))"
    want "$T/rep.tsv" sub/a EXIT 0 && same "$T/o/sub_a.out" 'beside line' "sub/a (read from the collection, its data file beside it)"
    want "$T/rep.tsv" sub/b EXIT 0 && same "$T/o/sub_b.out" "$(printf 'clean\nbeside line')" "sub/b (the scratch copy of the folder is restored from the collection)"
    want "$T/rep.tsv" sub/c EXIT 0 && same "$T/o/sub_c.out" "$(printf 'in one\nin two')" "sub/c (NAME.in is read from the package folder)"
    want "$T/rep.tsv" d EXIT 0 && same "$T/o/d.out" 'one two three' "d (ALL.args is read from the package folder)"
    want "$T/rep.tsv" h EXIT 0 && same "$T/o/h.out" 'hosted copy' "h (a program the package itself holds is the one run)"
    ( cd "$C" && find . -type f -exec md5sum {} + | sort -k2 ) > "$T/after.txt"
    cmp -s "$T/before.txt" "$T/after.txt" || red "the collection changed under the run: $(diff "$T/before.txt" "$T/after.txt" | head -2 | tr '\n' ' ')"
    [ -z "$(find "$T/w" -type l 2>/dev/null | head -1)" ] || red "the work directory holds a link"
    printf '%s\n' 'entry,path,timeout_s,heap_kb,stack_kb,compile_args,dialect,grader' 'sub/a,sub/a.sno,,,,,,' 'gone,sub/nothere.sno,,,,,,' > "$P/ALL.csv"; rm -f "$P/ALL.args"
    ( cd "$T" && timeout -k 5 60 "$SCRIP" --run-files "$P" --out "$T/o2" > rep2.tsv 2> err2.txt < /dev/null ); rc=$?
    [ "$rc" = 2 ] || red "a file cell that names no file under the root exits $rc, want the refusal 2"
    [ ! -s "$T/rep2.tsv" ] || red "the package with a missing program still ran a test"
    grep -q 'nothere' "$T/err2.txt" 2>/dev/null || red "the refusal does not name the missing path"
    printf '%s\n' 'entry,path,timeout_s,heap_kb,stack_kb,compile_args,dialect,grader' 'sub/a,sub/a.sno,,,,,,' > "$P/ALL.csv"
    printf 'root\t%s\norigin\tprobe\nversion\tprobe\nlicence\tpublic domain\nconvert\ticon-semicolons\n' "$C" > "$P/ALL.source"
    ( cd "$T" && timeout -k 5 60 "$SCRIP" --run-files "$P" --out "$T/o3" > rep3.tsv 2> err3.txt < /dev/null ); rc=$?
    [ "$rc" = 2 ] || red "an ALL.source with a fifth key exits $rc, want the refusal 2"
    printf 'root\t%s\norigin\tprobe\nversion\tprobe\nlicence\tpublic domain\n' "$T/no_such_root" > "$P/ALL.source"
    ( cd "$T" && timeout -k 5 60 "$SCRIP" --run-files "$P" --out "$T/o4" > rep4.tsv 2> err4.txt < /dev/null ); rc=$?
    [ "$rc" = 2 ] || red "a root that does not exist exits $rc, want the refusal 2"
    [ ! -s "$T/rep4.tsv" ] || red "the package with no root still ran a test"
    verdict "four tests ran in place from the collection, the collection is byte-identical after, the package's own program wins, three malformed forms refuse"
}

step14() {   # run-files reads ALL.launch: around BEFORE AFTER or driver PROGRAM, and a grader cell no longer defers (CIO-83)
    need_scrip
    local P="$T/pkg" rc got
    mkdir -p "$P/shim" "$P/sub"
    printf 'shim_fact(before).\n' > "$P/shim/before.pl"
    printf ':- initialization((shim_fact(B), case_fact(C), write(around(B, C)), nl)).\n' > "$P/shim/after.pl"
    printf 'case_fact(one).\n' > "$P/sub/one.pl"; printf 'case_fact(two).\n' > "$P/sub/two.pl"
    printf '%s\n' 'entry,path,timeout_s,heap_kb,stack_kb,compile_args,dialect,grader' 'one,sub/one.pl,,,,,,verdict-line' 'two,sub/two.pl,,,,,,' > "$P/ALL.csv"
    got="$(cd "$P/sub" && timeout -k 5 60 "$SCRIP" --run "$P/shim/before.pl" one.pl "$P/shim/after.pl" < /dev/null 2>/dev/null)"
    [ "$got" = 'around(before,one)' ] || refuse "scrip does not run three Prolog sources in one launch (reads '$got'): the probe's own premise fails"
    printf '# the launch of a per-case package (CIO-83)\nscrip\taround\tshim/before.pl\tshim/after.pl\noracle\taround\t-\tshim/after.pl\n' > "$P/ALL.launch"
    ( cd "$T" && timeout -k 5 120 "$SCRIP" --run-files "$P" --out "$T/o" > rep.tsv 2> err.txt < /dev/null ); rc=$?
    [ "$rc" = 0 ] || red "around: the switch exits $rc ($(head -1 "$T/err.txt" | cut -c1-120))"
    want "$T/rep.tsv" one EXIT 0 && same "$T/o/one.out" 'around(before,one)' "one (a row with a grader cell runs between BEFORE and AFTER)"
    want "$T/rep.tsv" two EXIT 0 && same "$T/o/two.out" 'around(before,two)' "two"
    printf "        OUTPUT = HOST(0)\nEND\n" > "$P/shim/drive.sno"; printf 'data of one\n' > "$P/sub/one.dat"
    printf '%s\n' 'entry,path,timeout_s,heap_kb,stack_kb,compile_args,dialect,grader' 'one,sub/one.dat,,,,,,verdict-line' > "$P/ALL.csv"
    printf 'one\textra\n' > "$P/ALL.args"; printf 'scrip\tdriver\tshim/drive.sno\n' > "$P/ALL.launch"
    ( cd "$T" && timeout -k 5 120 "$SCRIP" --run-files "$P" --out "$T/o2" > rep2.tsv 2> err2.txt < /dev/null ); rc=$?
    [ "$rc" = 0 ] || red "driver: the switch exits $rc ($(head -1 "$T/err2.txt" | cut -c1-120))"
    want "$T/rep2.tsv" one EXIT 0 && same "$T/o2/one.out" 'one.dat extra' "one (the driver gets the row's file name first, then the entry's arguments)"
    printf 'scrip\taround\tshim/before.pl\n' > "$P/ALL.launch"
    ( cd "$T" && timeout -k 5 60 "$SCRIP" --run-files "$P" --out "$T/o3" > rep3.tsv 2> err3.txt < /dev/null ); rc=$?
    [ "$rc" = 2 ] || red "an around line with one path exits $rc, want the refusal 2"
    printf 'scrip\tdriver\tshim/absent.sno\n' > "$P/ALL.launch"
    ( cd "$T" && timeout -k 5 60 "$SCRIP" --run-files "$P" --out "$T/o4" > rep4.tsv 2> err4.txt < /dev/null ); rc=$?
    [ "$rc" = 2 ] || red "a driver the package does not hold exits $rc, want the refusal 2"
    [ ! -s "$T/rep4.tsv" ] || red "the package with no driver still ran a test"
    printf 'oracle\tdriver\tshim/drive.sno\n' > "$P/ALL.launch"
    ( cd "$T" && timeout -k 5 60 "$SCRIP" --run-files "$P" --out "$T/o5" > rep5.tsv 2> err5.txt < /dev/null ); rc=$?
    [ "$rc" = 0 ] || red "an ALL.launch with an oracle line alone exits $rc"
    want "$T/rep5.tsv" one DEFERRED
    verdict "around runs the row's file between two shim sources, driver hands it to one program, a grader cell runs once the package has a scrip line"
}

case "$N" in
    1) step1 ;; 2) step2 ;; 3) step3 ;; 4) step4 ;; 5) step5 ;; 6) step6 ;; 7) step7 ;; 8) step8 ;; 9) step9 ;; 10) step10 ;; 11) step11 ;; 12) step12 ;; 13) step13 ;; 14) step14 ;;
    *) refuse "no step $N (1..14)" ;;
esac
