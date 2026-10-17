#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-547)"
# test_gate_package_runners_read_each_units_declared_compile_args.sh -- A TEST UNIT'S COMPILE SWITCHES ARE ITS OWN DECLARATION, AND A
# RUNNER TYPES NONE OF ITS OWN. RULES.md hard-cap rule clause 8 (f); ceo CEO-1281; Lon 2026-09-26 11:1x-11:2x CDT, in-chat to the ceo,
# verbatim: "Basically the command-line arguments for compile time and run time (if needed) should be stored per-test unit."
#
# ⛔⭐ WHY EVERY ARM READS A VERDICT PAIR. Landing 3 of the compile_args row deleted the typing: corpus_suite_harness.py no longer puts
# --stlimit on every snobol4, snocone and rebus compile, and ten package runners no longer export SCRIP_SNO_STMTKW=1 over their whole
# loop; each reads the unit's compile_args instead. On the shipped tables every row declares --stlimit, so a runner that still types
# the switch for everybody and a runner that reads the declaration grade every real board identically. So each arm plants TWO copies
# of one witness whose output depends on the switch -- decl, which declares --stlimit, and nodecl, which declares nothing -- and
# requires the verdicts to DIFFER: decl PASS in both modes, nodecl FAIL in both. A runner that types the switch reads nodecl PASS; a
# runner that reads no declaration reads decl FAIL. The SNOBOL4 witness prints &STCOUNT (SPITBOL always counts, 3; SCRIP 3 with the
# switch and 0 without); the Icon witness sets &trace (the Icon oracle prints three trace lines; SCRIP the same three with the switch,
# none without). The premise arm re-measures both before any arm reads them, so the day the switch stops mattering this gate says so.
#
#   W   PREMISE: both witnesses still depend on the switch, in both modes, and the oracles agree with the switched run
#   L1  declared_memory_table: a declaring row carries its compile_args as a 4th column; a row declaring none prints its three
#       columns byte-identical to a table with no compile_args column; declared_compile_args_from_table returns exactly those words
#   L2  refusals, rc 2 each: a compile_args word outside COMPILE_ARGS_ADMITTED; a run_args cell (no bash reader honours one yet);
#       a lookup with no table
#   H   corpus_suite_harness.py run on a scratch one-line SNOBOL4 family -- the rung suites' path
#   P1..P10  the ten package runners, each on its own scratch suite and scratch progress table: dotnet, snoflake, spitbol_x64,
#       spitbol_testpgms, csnobol4, aisnobol (through the harness), jcon, arizona, ipl, and spitbol_x32 (hq_snobol4's X32T, 1cddec296)
#
#   L3  landing 4: declared_compile_args_beside reads a standalone program's <stem>.cmdline (NAME<TAB>compile_args<TAB>run_args) and
#       refuses rc 2 on another unit's name, a word outside the admitted list and a run_args cell
#   X1  corpus_suite_harness.py extract carries the unit's heap, stack and command line out beside it, named by the output's stem
#       (CEO-1127: an entry extracted standalone is how every seat cures); an undeclaring unit gets no .cmdline
#   X2  extract-family carries <stem>.cmdline, and the harness run on the extracted pair -- no ALL.csv beside it -- applies it
#   S1  scorecard_snobol4.sh on a scratch gimpel table (the path test_snobol4_gimpel_suite.sh grades through)
#   S2  scorecard_snobol4.sh on a scratch benchmarks dir with no table: the <stem>.cmdline sidecar is the only declaration
#   D1  test_corpus_snobol4.sh's own run_test and compile_mode4, lifted out of the runner by sed (never copied) and run on a demo
#       pair: the runner's rungs block cannot be fixtured cheaply, and these two functions are its every direct scrip command line
#   A   landing 5, THE ACCEPT ARM: every word of COMPILE_ARGS_ADMITTED (read from the harness) is accepted by scrip at both compile
#       steps and switches the witness to the oracle's answer, and every compile_args word the corpus declares -- 25 tables and every
#       <stem>.cmdline -- is admitted; FAIL-ONCE inside the arm: --nosuchswitch must be REJECTED at both steps, or acceptance could not
#       be told from indifference and the arm refuses rc 2
#   R   landing 5, THE RATCHET: the scripts that type the switch themselves (an executable line naming SCRIP_SNO_STMTKW, or a literal
#       --stlimit; gates excluded, a grader's instrumentation is not a unit's) are exactly the five named with their reasons below --
#       a new one reds, and so does a named one that no longer types it; FAIL-ONCE inside the arm: a planted runner that exports the
#       switch reds the same census over a scratch dir
#
# NOT COVERED, AND NAMED: the ladder, port-trace and gate graders keep their export, because a grader's instrumentation is not a unit
# attribute. LANDING 4 (coo 2026-09-26): the three exports this header used to name here -- test_corpus_snobol4.sh, scorecard_snobol4.sh
# and test_snobol4_gimpel_suite.sh -- are deleted; measured that day, every one of their table rows declares --stlimit and the 27
# rowless programs the scorecard grades and the 23 demos run byte-identical in both modes without it.
# FAIL-ONCE, MEASURED 2026-09-26 17:4x CDT (coo) on SCRIP 0dd682acd plus this landing, both directions: (1) FAIL_ONCE=1 exports
# SCRIP_SNO_STMTKW=1 around every harness and runner invocation -- the typed switch this row retires -- and nodecl reads PASS/PASS
# everywhere: H and P1..P10 red, 11 of 14; W, L1 and L2 read no runner and stay green by construction. (2) The same gate over origin's
# twelve pre-landing files (the harness, lib_declared_arena.sh and ten runners, restored for the run and put back byte-identical): 13 of
# 14 red -- L1 and L2 (the old table has no 4th column, no refusal and no lookup) and H, P1..P10 (nodecl PASS/PASS); only W is green.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=package_runners_read_each_units_declared_compile_args
unproven() { echo "GATE UNPROVEN(2) [$G]: $*"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "test_gate_$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" >/dev/null 2>&1 || unproven "this tree's binary is stale or unbuilt -- run make"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || unproven "lib_oracle_flags.sh unloadable"
. "$HERE/lib_declared_arena.sh" 2>/dev/null || unproven "lib_declared_arena.sh unloadable"
SBL="$(sbl_correctness_bin)"; ICON="$(icon_bin)"
[ -x "$SBL" ] || unproven "the sbl -bf oracle is absent"
[ -x "$ICON" ] || unproven "the Icon oracle is absent"
SCRIP="$ROOT/scrip"; RT="$ROOT/out"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_cargs.XXXXXX")" || unproven "mktemp failed"
trap 'rm -rf "$W"' EXIT
unset SCRIP_SNO_STMTKW   # the caller's environment never reaches an arm; FAIL_ONCE=1 alone puts it back, around the runners
PASS=0; FAIL=0; UNM=""
ok()  { PASS=$((PASS+1)); echo "  ✅ $1: $2"; }
red() { FAIL=$((FAIL+1)); echo "  ⛔ $1 RED: $2"; }
typed=(); [ "${FAIL_ONCE:-0}" = 1 ] && typed=(SCRIP_SNO_STMTKW=1) && echo "FAIL_ONCE=1: SCRIP_SNO_STMTKW=1 is exported around every harness and runner invocation"

# ── W: the witnesses, and the premise that they depend on the switch ─────────────────────────────────────────────────────────────
printf "        X = 1\n        Y = 2\n        OUTPUT = 'count=' &STCOUNT\nEND\n" > "$W/cnt.sno"
printf 'procedure p(x);\n  return x + 1;\nend\nprocedure main();\n  &trace := -1;\n  write(p(1));\nend\n' > "$W/tr.icn"
m3_of() { ( cd "$W" && timeout -k 5 20 "$SCRIP" --run $2 "$1" < /dev/null 2>&1 ); }
m4_of() { ( cd "$W" && "$SCRIP" --compile $2 "$1" > "$W/w.s" 2>/dev/null < /dev/null && gcc -no-pie "$W/w.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$W/w.bin" 2>/dev/null && timeout -k 5 20 "$W/w.bin" < /dev/null 2>&1 ); }
(cd "$W" && timeout -k 5 20 "$SBL" -bf cnt.sno < /dev/null > sbl.out 2>&1)
(cd "$W" && timeout -k 5 20 "$ICON" tr.icn < /dev/null > icon.out 2>&1)
s3y="$(m3_of cnt.sno --stlimit)"; s3n="$(m3_of cnt.sno '')"; s4y="$(m4_of cnt.sno --stlimit)"; s4n="$(m4_of cnt.sno '')"
i3y="$(m3_of tr.icn --stlimit)"; i3n="$(m3_of tr.icn '')"; i4y="$(m4_of tr.icn --stlimit)"; i4n="$(m4_of tr.icn '')"
sbl_o="$(cat "$W/sbl.out")"; icon_o="$(cat "$W/icon.out")"
if [ "$s3y" = "$sbl_o" ] && [ "$s4y" = "$sbl_o" ] && [ "$s3n" != "$sbl_o" ] && [ "$s4n" != "$sbl_o" ] \
   && [ "$i3y" = "$icon_o" ] && [ "$i4y" = "$icon_o" ] && [ "$i3n" != "$icon_o" ] && [ "$i4n" != "$icon_o" ]; then
    ok W "both witnesses depend on the switch: SNOBOL4 m3/m4 with it '$s3y'/'$s4y' = sbl '$sbl_o', without '$s3n'/'$s4n'; Icon m3/m4 with it = the oracle's $(printf '%s\n' "$icon_o" | wc -l) lines, without $(printf '%s\n' "$i3n" | wc -l)/$(printf '%s\n' "$i4n" | wc -l)"
else
    unproven "a witness no longer depends on the switch, so no arm below can tell a declaration from a default -- SNOBOL4 sbl='$sbl_o' m3 with='$s3y' without='$s3n' m4 with='$s4y' without='$s4n'; Icon m3 with/without equal to the oracle: $([ "$i3y" = "$icon_o" ] && echo y || echo n)/$([ "$i3n" = "$icon_o" ] && echo y || echo n), m4 $([ "$i4y" = "$icon_o" ] && echo y || echo n)/$([ "$i4n" = "$icon_o" ] && echo y || echo n) -- re-derive the witness"
fi

# ── L1, L2: the reader ───────────────────────────────────────────────────────────────────────────────────────────────────────────
HDR='entry,heap_kb,stack_kb,compile_args,run_args'
printf '%s\ndecl,131072,4096,--stlimit,\nnodecl,131072,4096,,\n' "$HDR" > "$W/l.csv"
printf 'entry,heap_kb,stack_kb\ndecl,131072,4096\nnodecl,131072,4096\n' > "$W/l_old.csv"
declared_memory_table "$W/l.csv" > "$W/l.tsv" 2>"$W/l.err"; l_rc=$?
declared_memory_table "$W/l_old.csv" > "$W/l_old.tsv" 2>/dev/null
want_decl="$(printf 'decl\t131072\t4096\t--stlimit')"; want_nodecl="$(printf 'nodecl\t131072\t4096')"
got_decl="$(grep '^decl	' "$W/l.tsv")"; got_nodecl="$(grep '^nodecl	' "$W/l.tsv")"; old_nodecl="$(grep '^nodecl	' "$W/l_old.tsv")"
ca_d="$(declared_compile_args_from_table "$W/l.tsv" decl)"; ca_n="$(declared_compile_args_from_table "$W/l.tsv" nodecl)"
if [ "$l_rc" = 0 ] && [ "$got_decl" = "$want_decl" ] && [ "$got_nodecl" = "$want_nodecl" ] && [ "$got_nodecl" = "$old_nodecl" ] && [ "$ca_d" = "--stlimit" ] && [ -z "$ca_n" ]; then
    ok L1 "the table carries decl's --stlimit as a 4th column, nodecl's line is byte-identical to a table with no compile_args column, and the lookup returns '--stlimit' and ''"
else
    red L1 "rc=$l_rc decl=[$(printf '%s' "$got_decl" | cat -A)] nodecl=[$(printf '%s' "$got_nodecl" | cat -A)] old=[$(printf '%s' "$old_nodecl" | cat -A)] lookup=[$ca_d]/[$ca_n] $(head -1 "$W/l.err")"
fi
printf '%s\nbad,131072,4096,--nosuchswitch,\n' "$HDR" > "$W/bad.csv"; declared_memory_table "$W/bad.csv" >/dev/null 2>&1; r1=$?
printf '%s\nra,131072,4096,,x\n' "$HDR" > "$W/ra.csv"; declared_memory_table "$W/ra.csv" >/dev/null 2>&1; r2=$?
declared_compile_args_from_table "$W/no_such_table.tsv" decl >/dev/null 2>&1; r3=$?
[ "$r1" = 2 ] && [ "$r2" = 2 ] && [ "$r3" = 2 ] && ok L2 "a word outside the admitted list, a run_args cell and a lookup with no table each refuse rc 2" \
    || red L2 "rc for --nosuchswitch=$r1, run_args=$r2, no table=$r3 (want 2, 2, 2)"

# ── the verdict pair ─────────────────────────────────────────────────────────────────────────────────────────────────────────────
outcome() { awk -F'\t' -v p="$2" -v m="$3" 'NR>1 && $8==p && $9==m {print $10}' "$1" 2>/dev/null | tail -1; }
pair() {  # <arm> <runner rc> <decl m3> <decl m4> <nodecl m3> <nodecl m4>
    local a="$1" rc="$2"
    if [ "$rc" = 2 ] || [ "$rc" = 124 ]; then red "$a" "the runner could not measure its fixture (rc=$rc)"; UNM="$UNM $a"; return 1; fi
    if [ "$3" = PASS ] && [ "$4" = PASS ] && [ -n "$5" ] && [ "$5" != PASS ] && [ -n "$6" ] && [ "$6" != PASS ]; then
        ok "$a" "decl PASS/PASS, nodecl $5/$6 -- the declaration reached the compile in both modes and the neighbour got no switch"
    else
        red "$a" "decl ${3:-none}/${4:-none}, nodecl ${5:-none}/${6:-none} (want PASS/PASS and FAIL/FAIL)"; return 1
    fi
}
show_on_red() { printf '%s\n' "$1" | grep -E 'REFUSE|⛔' | head -3 | sed 's/^/        /'; }
csv_pair() { printf '%s\n%s,131072,4096,--stlimit,\n%s,131072,4096,,\n' "$HDR" "$1" "$2"; }

# ── H: the harness, on a one-line SNOBOL4 family (the rung suites' path); the same family feeds P6, the aisnobol runner ────────────────
mkdir -p "$W/fam"
printf " X = 1; Y = 2; OUTPUT = 'count=' &STCOUNT;END;* decl\n X = 1; Y = 2; OUTPUT = 'count=' &STCOUNT;END;* nodecl\n" > "$W/fam/ALL.sno"
printf 'count=3\ncount=3\n' > "$W/fam/ALL.ref"; for n in decl nodecl; do cp "$W/cnt.sno" "$W/fam/$n.sno"; done   # the loose programs a package ships beside its suite
printf 'rank,entry,origin,family,kind,xfail,n_lines,heap_kb,stack_kb,compile_args,run_args\n1,decl,fx__decl,fx,line,0,1,131072,4096,--stlimit,\n2,nodecl,fx__nodecl,fx,line,0,1,131072,4096,,\n' > "$W/fam/ALL.csv"
board_pair() {  # <arm> <rc> <output> -- a harness board prints FAIL lines and a SUITE_BOARD or <PKG>_BOARD count line
    local b3 b4 d3=FAIL d4=FAIL n3=PASS n4=PASS
    b3="$(printf '%s\n' "$3" | grep -oE 'm3_(pass|PASS)=[0-9]+' | head -1 | cut -d= -f2)"; b4="$(printf '%s\n' "$3" | grep -oE 'm4_(pass|PASS)=[0-9]+' | head -1 | cut -d= -f2)"
    printf '%s\n' "$3" | grep -qE 'FAIL m3 nodecl:' && n3=FAIL; printf '%s\n' "$3" | grep -qE 'FAIL m4 nodecl:' && n4=FAIL
    # a PASS prints nothing, so decl passed when it has no FAIL line and the board's pass count holds it beside nodecl's
    local k3=1 k4=1; [ "$n3" = PASS ] && k3=2; [ "$n4" = PASS ] && k4=2
    printf '%s\n' "$3" | grep -qE 'FAIL m3 decl:' || { [ "${b3:-x}" = "$k3" ] && d3=PASS; }
    printf '%s\n' "$3" | grep -qE 'FAIL m4 decl:' || { [ "${b4:-x}" = "$k4" ] && d4=PASS; }
    pair "$1" "$2" "$d3" "$d4" "$n3" "$n4" || show_on_red "$3"
}
out="$(cd "$ROOT" && env "${typed[@]}" timeout -k 5 300 python3 "$HERE/corpus_suite_harness.py" run "$W/fam/ALL.sno" "$W/fam/ALL.ref" --modes m3,m4 2>&1)"; rc=$?
board_pair H "$rc" "$out"

# ── P1..P10: the package runners ──────────────────────────────────────────────────────────────────────────────────────────────────
run_db() {  # <arm> <db> <env...> -- <runner and args>; DBPFX names a runner's rows by path (the ipl runner: progs/decl)
    local a="$1" db="$2" o r; shift 2; local -a e=(); while [ "$1" != -- ]; do e+=("$1"); shift; done; shift
    o="$(cd "$ROOT" && env "${typed[@]}" S4E_PROGRESS_DB="$db" "${e[@]}" timeout -k 5 300 bash "$@" 2>&1)"; r=$?
    local x="${DBPFX:-}"
    pair "$a" "$r" "$(outcome "$db" "${x}decl" m3)" "$(outcome "$db" "${x}decl" m4)" "$(outcome "$db" "${x}nodecl" m3)" "$(outcome "$db" "${x}nodecl" m4)" || show_on_red "$o"
}
mk_sno() {  # <dir> <ext>
    mkdir -p "$1"; for n in decl nodecl; do cp "$W/cnt.sno" "$1/$n.$2"; done; csv_pair decl nodecl > "$1/ALL.csv"; }
mk_icn() {  # <dir> <entry prefix>
    mkdir -p "$1"; for n in decl nodecl; do cp "$W/tr.icn" "$1/$n.icn"; ( cd "$1" && timeout -k 5 20 "$ICON" "$n.icn" < /dev/null > "$n.ref" 2>&1 ); done; }

mk_sno "$W/dot" sno
run_db P1 "$W/p1.tsv" DOTNET_SUITE="$W/dot" -- "$HERE/test_snobol4_dotnet_suite.sh"
mk_sno "$W/flake" sno
run_db P2 "$W/p2.tsv" SNOFLAKE_SUITE="$W/flake" ARM_CSN=0 -- "$HERE/test_snoflake_suite.sh"
mk_sno "$W/x64" sbl
run_db P3 "$W/p3.tsv" SPITBOL_X64_SUITE="$W/x64" SPITBOL_X64_SHIPPED=2 -- "$HERE/test_snobol4_spitbol_x64_suite.sh"
# P4 spitbol_testpgms records no progress row for a scratch suite, so its RED lines and board counts are read
mkdir -p "$W/tp"; for n in testdecl testnodecl; do cp "$W/cnt.sno" "$W/tp/$n.spt"; done; : > "$W/tp/testpgms.in"; csv_pair testdecl testnodecl > "$W/tp/ALL.csv"
out="$(cd "$ROOT" && env "${typed[@]}" SPITBOL_TESTPGMS_SUITE="$W/tp" timeout -k 5 300 bash "$HERE/test_snobol4_spitbol_testpgms_suite.sh" 2>&1)"; rc=$?
b="$(printf '%s\n' "$out" | grep -E '^SPITBOL_TESTPGMS_BOARD ')"
d3=FAIL; d4=FAIL; n3=PASS; n4=PASS
printf '%s\n' "$out" | grep -qE '^  RED  testnodecl m3 ' && n3=FAIL; printf '%s\n' "$out" | grep -qE '^  RED  testnodecl m4 ' && n4=FAIL
k3=1; k4=1; [ "$n3" = PASS ] && k3=2; [ "$n4" = PASS ] && k4=2
printf '%s\n' "$out" | grep -qE '^  RED  testdecl m3 ' || { printf '%s' "$b" | grep -q " m3_pass=$k3 " && d3=PASS; }
printf '%s\n' "$out" | grep -qE '^  RED  testdecl m4 ' || { printf '%s' "$b" | grep -q " m4_pass=$k4 " && d4=PASS; }
pair P4 "$rc" "$d3" "$d4" "$n3" "$n4" || show_on_red "$out"
mk_sno "$W/csn" sno; for n in decl nodecl; do printf '%s\n' "$sbl_o" > "$W/csn/$n.ref"; done
run_db P5 "$W/p5.tsv" CSNOBOL4_SUITE="$W/csn" -- "$HERE/test_snobol4_csnobol4_suite.sh"
out="$(cd "$ROOT" && env "${typed[@]}" AISNOBOL_SUITE="$W/fam" timeout -k 5 300 bash "$HERE/test_snobol4_aisnobol_suite.sh" 2>&1)"; rc=$?
board_pair P6 "$rc" "$out"
mk_icn "$W/jcon"; csv_pair decl nodecl > "$W/jcon/ALL.csv"
run_db P7 "$W/p7.tsv" -- "$HERE/test_icon_jcon_suite.sh" --corpus "$W/jcon"
A="$W/az/corpus/packages/icon/arizona_tests"; mk_icn "$A/general"; mkdir -p "$A/special"; csv_pair general/decl general/nodecl > "$A/ALL.csv"
DBPFX=general/ run_db P8 "$W/p8.tsv" S4E_HOME="$W/az" -- "$HERE/test_icon_arizona_suite.sh"   # the board keys <subdir>/<stem> (b4f66ce42, CEO-1366 (b))
P="$W/ipl/corpus/packages/icon/ipl"; mk_icn "$P/progs"; for d in gprogs procs gprocs incl gincl; do mkdir -p "$P/$d"; done; csv_pair progs/decl progs/nodecl > "$P/ALL.csv"
DBPFX=progs/ run_db P9 "$W/p9.tsv" S4E_HOME="$W/ipl" -- "$HERE/test_icon_ipl_suite.sh"
mk_sno "$W/x32" spt
run_db P10 "$W/p10.tsv" SPITBOL_X32_SUITE="$W/x32" SPITBOL_X32_SHIPPED=2 -- "$HERE/test_snobol4_spitbol_x32_suite.sh"

# ── landing 4: a STANDALONE unit's command line travels in <stem>.cmdline ──────────────────────────────────────────
mkdir -p "$W/sa"; for n in decl nodecl other bad ra; do cp "$W/cnt.sno" "$W/sa/$n.sno"; done
printf 'decl\t--stlimit\t\n' > "$W/sa/decl.cmdline"; printf 'someone_else\t--stlimit\t\n' > "$W/sa/other.cmdline"
printf 'bad\t--nosuchswitch\t\n' > "$W/sa/bad.cmdline"; printf 'ra\t\tx\n' > "$W/sa/ra.cmdline"
b_d="$(declared_compile_args_beside "$W/sa/decl.sno")"; rd=$?; b_n="$(declared_compile_args_beside "$W/sa/nodecl.sno")"; rn=$?
declared_compile_args_beside "$W/sa/other.sno" >/dev/null 2>&1; ro=$?; declared_compile_args_beside "$W/sa/bad.sno" >/dev/null 2>&1; rb=$?
declared_compile_args_beside "$W/sa/ra.sno" >/dev/null 2>&1; rr=$?
cp "$W/cnt.sno" "$W/sa/argvonly.sno"; printf 'a b c\n' > "$W/sa/argvonly.args"   # Icon's <name>.args is an argv, never this declaration
b_v="$(declared_compile_args_beside "$W/sa/argvonly.sno" 2>&1)"; rv=$?
if [ "$rd" = 0 ] && [ "$b_d" = "--stlimit" ] && [ "$rn" = 0 ] && [ -z "$b_n" ] && [ "$ro" = 2 ] && [ "$rb" = 2 ] && [ "$rr" = 2 ] && [ "$rv" = 0 ] && [ -z "$b_v" ]; then
    ok L3 "decl.cmdline reads '--stlimit', nodecl (no sidecar) reads nothing, an Icon argv .args beside a program is not read; another unit's name, a word outside the admitted list and a run_args cell each refuse rc 2"
else red L3 "decl=[$b_d] rc $rd, nodecl=[$b_n] rc $rn, argv .args=[$b_v] rc $rv, other rc $ro, bad word rc $rb, run_args rc $rr (want --stlimit/0, empty/0, empty/0, 2, 2, 2)"; fi
mkdir -p "$W/xt"
python3 "$HERE/corpus_suite_harness.py" extract "$W/fam/ALL.sno" "$W/fam/ALL.ref" decl "$W/xt/one.sno" >/dev/null 2>&1; x1=$?
python3 "$HERE/corpus_suite_harness.py" extract "$W/fam/ALL.sno" "$W/fam/ALL.ref" nodecl "$W/xt/two.sno" >/dev/null 2>&1; x2=$?
x_ca="$(declared_compile_args_beside "$W/xt/one.sno" 2>&1)"; x_sw="$(declared_switches_beside "$W/xt/one.sno" 2>&1)"; x_n="$(declared_compile_args_beside "$W/xt/two.sno" 2>&1)"
if [ "$x1" = 0 ] && [ "$x2" = 0 ] && [ "$x_ca" = "--stlimit" ] && [ "$x_sw" = "-d131072k -s4096k" ] && [ ! -e "$W/xt/two.cmdline" ] && [ -z "$x_n" ]; then
    ok X1 "extract carries decl's --stlimit, 131072 KB and 4096 KB out beside one.sno, and nodecl's two.sno gets no .cmdline"
else red X1 "extract rc $x1/$x2; one.sno reads [$x_ca] and [$x_sw] (want --stlimit and -d131072k -s4096k); two.cmdline $([ -e "$W/xt/two.cmdline" ] && echo present || echo absent), two reads [$x_n]"; fi
mkdir -p "$W/xf"
python3 "$HERE/corpus_suite_harness.py" extract-family "$W/fam/ALL.sno" "$W/fam/ALL.ref" "$W/fam/ALL.csv" fx "$W/xf/fx.sno" "$W/xf/fx.ref" >/dev/null 2>&1 \
    || red X2 "extract-family refused the scratch family"
if [ -f "$W/xf/fx.cmdline" ] && [ ! -e "$W/xf/ALL.csv" ]; then
    out="$(cd "$ROOT" && env "${typed[@]}" timeout -k 5 300 python3 "$HERE/corpus_suite_harness.py" run "$W/xf/fx.sno" "$W/xf/fx.ref" --modes m3,m4 2>&1)"; rc=$?
    board_pair X2 "$rc" "$out"
else red X2 "extract-family wrote no fx.cmdline beside the extracted pair"; fi
# ⛔ THE SCORECARD APPENDS ITS results.tsv TO THE PROGRESS TABLE ON EVERY run, scratch corpus or not, so S1 and S2 name a scratch table:
# the first draft of these arms did not, and one run put 4 fixture rows (decl_driver, nodecl_driver; dev-pass, -dirty) into the live one.
sc_overlay() {  # <corpus dir> <top-level dir the fixture replaces> -- every other top-level dir of the real corpus symlinked in, as the gimpel runner does
    local c="$1" keep="$2" d b; mkdir -p "$c"
    for d in "$ROOT/../corpus"/*/; do b="$(basename "$d")"; [ "$b" = "$keep" ] && continue; ln -s "$d" "$c/$b" 2>/dev/null || true; done; }
sc_pair() {  # <arm> <rc> <results.tsv> <decl program path> <nodecl program path>
    st() { awk -F'\t' -v p="$1" -v c="$2" '$2==p {print $c; exit}' "$3" 2>/dev/null; }
    pair "$1" "$2" "$(st "$4" 3 "$3")" "$(st "$4" 4 "$3")" "$(st "$5" 3 "$3")" "$(st "$5" 4 "$3")"; }
G1="$W/sc1/corpus/packages/snobol4/gimpel"; mkdir -p "$G1"; sc_overlay "$W/sc1/corpus" packages
for n in decl_driver nodecl_driver norow_driver; do cp "$W/cnt.sno" "$G1/$n.sno"; done; csv_pair decl_driver nodecl_driver > "$G1/ALL.csv"
out="$(cd "$ROOT" && env "${typed[@]}" S4E_BOARDS="$W/boards" S4E_PROGRESS_DB="$W/s1.tsv" CORPUS="$W/sc1/corpus" timeout -k 5 300 bash "$HERE/scorecard_snobol4.sh" run --suites gimpel --out "$W/sc1/out" 2>&1)"; rc=$?
sc_pair S1 "$rc" "$W/sc1/out/results.tsv" packages/snobol4/gimpel/decl_driver.sno packages/snobol4/gimpel/nodecl_driver.sno || show_on_red "$out"
# S1u (coo 2026-09-27, COO-205): norow_driver has no row in the suite's ALL.csv, so the scorecard names it UNDECLARED and names no other
_ul="$(printf '%s\n' "$out" | grep -m1 'UNDECLARED (RULES.md 8 (f))')"
if printf '%s' "$_ul" | grep -q ': 1 program(s) ' && printf '%s' "$_ul" | grep -q 'norow_driver' && ! printf '%s' "$_ul" | grep -q 'decl_driver'; then ok S1u "the scorecard names the one program of a table-carrying suite with no row (norow_driver), and no declared one"
else red S1u "the scorecard's UNDECLARED line: [${_ul:-none printed}]"; fi
B2="$W/sc2/corpus/benchmarks/snobol4"; mkdir -p "$B2"; sc_overlay "$W/sc2/corpus" benchmarks
for n in decl nodecl; do cp "$W/cnt.sno" "$B2/$n.sno"; done; printf 'decl\t--stlimit\t\n' > "$B2/decl.cmdline"
out="$(cd "$ROOT" && env "${typed[@]}" S4E_BOARDS="$W/boards" S4E_PROGRESS_DB="$W/s2.tsv" CORPUS="$W/sc2/corpus" timeout -k 5 300 bash "$HERE/scorecard_snobol4.sh" run --suites benchmarks --out "$W/sc2/out" 2>&1)"; rc=$?
sc_pair S2 "$rc" "$W/sc2/out/results.tsv" benchmarks/snobol4/decl.sno benchmarks/snobol4/nodecl.sno || show_on_red "$out"
mkdir -p "$W/dm"; for n in decl nodecl; do cp "$W/cnt.sno" "$W/dm/$n.sno"; printf '%s\n' "$sbl_o" > "$W/dm/$n.ref"; done; printf 'decl\t--stlimit\t\n' > "$W/dm/decl.cmdline"
fns="$(sed -n '/^compile_mode4() {/,/^}/p; /^run_test() {/,/^}/p' "$HERE/test_corpus_snobol4.sh")"
if printf '%s' "$fns" | grep -q '^run_test() {' && printf '%s' "$fns" | grep -q '^compile_mode4() {'; then
    d1="$(cd "$ROOT" && env "${typed[@]}" bash -c '
        . "$1/lib_declared_arena.sh" || exit 2; eval "$2"
        SCRIP="$3/scrip"; RT_DIR="$3/out"; INC="$4"; TIMEOUT=30; WORKDIR="$(mktemp -d)"; HERE="$1"; TIMEOUT_RETRY="$1/util_timeout_retry.sh"
        PASS3=0 FAIL3=0 PASS4=0 FAIL4=0 BOTH=0 SKIP4=0 TMOUT3=0 TMOUT4=0 MISSING=0 T_M3=0 T_M4=0 FAILURES3= FAILURES4= TMOUT_LIST= MISSING_LIST=
        run_test decl "$5/decl.sno" "$5/decl.ref" "" ""; echo "decl $PASS3 $PASS4"
        run_test nodecl "$5/nodecl.sno" "$5/nodecl.ref" "" ""; echo "nodecl $FAIL3 $FAIL4"; rm -rf "$WORKDIR"' _ "$HERE" "$fns" "$ROOT" "$ROOT/../corpus/include" "$W/dm" 2>&1)"; rc=$?
    d3=FAIL; d4=FAIL; n3=PASS; n4=PASS
    printf '%s\n' "$d1" | grep -q '^decl 1 1$' && d3=PASS && d4=PASS
    printf '%s\n' "$d1" | grep -q '^nodecl 1 1$' && n3=FAIL && n4=FAIL
    pair D1 "$rc" "$d3" "$d4" "$n3" "$n4" || show_on_red "$d1"
else red D1 "run_test and compile_mode4 are no longer in test_corpus_snobol4.sh as sed can lift them -- this arm grades nothing"; fi

# ── landing 5: A, the accept arm; R, the ratchet ───────────────────────────────────────────────────────────
adm="$(cd "$ROOT" && python3 -c 'import sys; sys.path.insert(0, "scripts"); import corpus_suite_harness as h; print(" ".join(h.COMPILE_ARGS_ADMITTED))' 2>/dev/null)"
if [ -z "$adm" ]; then red A "COMPILE_ARGS_ADMITTED could not be read from the harness"; else
    # A word is graded on a witness in its own language (cfo 2026-10-17, CEO-1810): --stlimit on cnt.sno against sbl's output, --dialect=gnu on dia.pl,
    # which prints the '$dialect' flag -- gnu with the switch, iso without it (the control: a switch scrip ignored would read iso).
    printf ':- initialization(main).\nmain :- current_prolog_flag(%s, D), write(D), nl.\n' "'\$dialect'" > "$W/dia.pl"
    a_bad=""; for w in $adm; do
        case "$w" in --dialect=gnu) wf=dia.pl; wo=gnu ;; *) wf=cnt.sno; wo="$sbl_o" ;; esac
        [ "$(m3_of "$wf" "$w")" = "$wo" ] || a_bad="$a_bad $w:m3"; [ "$(m4_of "$wf" "$w")" = "$wo" ] || a_bad="$a_bad $w:m4"; done
    [ "$(m3_of dia.pl '')" = iso ] && [ "$(m4_of dia.pl '')" = iso ] || a_bad="$a_bad dia.pl-without-the-switch-is-not-iso"
    ( cd "$W" && timeout -k 5 20 "$SCRIP" --run --nosuchswitch cnt.sno < /dev/null > /dev/null 2>&1 ); u3=$?
    ( cd "$W" && timeout -k 5 20 "$SCRIP" --compile --nosuchswitch cnt.sno < /dev/null > "$W/u.s" 2>/dev/null ); u4=$?
    census="$(cd "$ROOT" && python3 - "$ROOT/../corpus" <<'PYC' 2>&1
import csv, glob, os, sys
sys.path.insert(0, "scripts"); import corpus_suite_harness as h
root = sys.argv[1]; words = 0; cells = 0; bad = []
for t in sorted(glob.glob(os.path.join(root, "tests", "*", "ALL.csv")) + glob.glob(os.path.join(root, "packages", "*", "*", "ALL.csv"))):
    with open(t, newline="") as f:
        for n, r in enumerate(csv.DictReader(f), 2):
            raw = (r.get("compile_args") or "").strip()
            if not raw: continue
            cells += 1
            try: words += len(h.validate_args_cell(raw, "compile_args", "%s:%d" % (t, n)) or [])
            except SystemExit: bad.append("%s:%d" % (os.path.relpath(t, root), n))
for a in sorted(glob.glob(os.path.join(root, "**", "*.cmdline"), recursive=True)):
    try: h.cmdline_declarations(a); cells += 1
    except SystemExit: bad.append(os.path.relpath(a, root))
print("cells=%d words=%d refused=%d %s" % (cells, words, len(bad), " ".join(bad[:5])))
PYC
)"
    if [ "$u3" = 0 ] || { [ "$u4" = 0 ] && [ -s "$W/u.s" ]; }; then
        unproven "scrip ACCEPTED --nosuchswitch (run rc $u3, compile rc $u4) -- acceptance of the admitted words cannot be told from indifference, so arm A grades nothing"
    elif [ -z "$a_bad" ] && printf '%s' "$census" | grep -qE '^cells=[1-9][0-9]* words=[0-9]+ refused=0 '; then
        ok A "scrip accepts [$adm] at both compile steps and each switches its witness (cnt.sno to sbl's '$sbl_o', dia.pl to gnu, iso without it); --nosuchswitch is rejected (run rc $u3, compile rc $u4); the corpus declares $(printf '%s' "$census" | cut -d' ' -f1,2), every word admitted"
    else red A "not accepted:${a_bad:- none}; corpus census: $census"; fi
fi
# R: exactly these scripts may type the switch, each for the reason given; gates are not runners and are not censused
# (lib_ladder.sh left this list 2026-09-28: each ladder witness carries its own --stlimit in its row's compile_args, CEO-1353, the coo)
RATCHET_EXEMPT="lib_port_trace.sh:the port-trace grader's instrumentation, not a unit attribute (landing 3's ruling)
util_stlimit_keeps_three_package_answers.sh:an instrument that measures the switch itself -- its arms type it by design
corpus_suite_harness.py:COMPILE_ARGS_ADMITTED is the switch's one definition
util_gc_safe_point_contract.py:CEO-1250 pins its reach reading's environment to the switch
util_gc_demo_porter_chain_reading.sh:a one-entry GC witness reading (hq_collector's porter reading): --stlimit is tests/snobol4 demo_porter's own ALL.csv compile_args, spelled on its command line as the harness passes it (the coo, ceo CEO-1697)"
ratchet_offenders() {  # <dir> -> the basename of every non-gate .sh/.py in it with an executable line typing the switch
    local f; for f in "$1"/*.sh "$1"/*.py; do [ -f "$f" ] || continue
        case "${f##*/}" in test_gate_*) continue;; esac
        awk '{ l=$0; sub(/^[ \t]*#.*$/, "", l); sub(/[ \t]+#[^"'"'"']*$/, "", l)
               if (l ~ /unset SCRIP_SNO_STMTKW|-u SCRIP_SNO_STMTKW/) next
               if (l ~ /SCRIP_SNO_STMTKW|--stlimit/) { hit=1; exit } } END { exit !hit }' "$f" && printf '%s\n' "${f##*/}"
    done | LC_ALL=C sort; }
exempt="$(printf '%s\n' "$RATCHET_EXEMPT" | cut -d: -f1 | LC_ALL=C sort)"
offend="$(ratchet_offenders "$HERE")"
new="$(comm -13 <(printf '%s\n' "$exempt") <(printf '%s\n' "$offend") | grep . | tr '\n' ' ')"
stale="$(comm -23 <(printf '%s\n' "$exempt") <(printf '%s\n' "$offend") | grep . | tr '\n' ' ')"
mkdir -p "$W/rt"; printf '#!/usr/bin/env bash\nexport SCRIP_SNO_STMTKW=1\n' > "$W/rt/test_planted_suite.sh"; printf '#!/usr/bin/env bash\n# export SCRIP_SNO_STMTKW=1 in a comment is not typing it\nenv -u SCRIP_SNO_STMTKW true\n' > "$W/rt/test_quiet_suite.sh"
planted="$(ratchet_offenders "$W/rt" | tr '\n' ' ')"
if [ "$planted" != "test_planted_suite.sh " ]; then
    unproven "the ratchet's census reads the planted scratch dir as [$planted], want [test_planted_suite.sh] -- a census that cannot see a planted export grades nothing"
elif [ -z "$new$stale" ]; then
    ok R "the scripts typing the switch are exactly the $(printf '%s\n' "$exempt" | grep -c .) named ones ($(printf '%s' "$exempt" | tr '\n' ' ')); a planted exporting runner is seen and a commented or unsetting one is not"
else red R "${new:+NEW, type the switch without a named reason: $new}${stale:+ STALE, named but no longer typing it: $stale}"; fi

echo "------------------------------------------------------------"
N=$((PASS + FAIL))
if [ "$FAIL" = 0 ]; then echo "GATE PASS(0) [$G]: $PASS of $N arms green (denominator: $N arms -- the premise, three reader arms, the harness, ten package runners, the extract and extract-family carry, the scorecard by table and by sidecar, the demo runner's own functions, the accept arm and the ratchet, each runner on a decl/nodecl pair in both modes)"; exit 0; fi
if [ -n "$UNM" ] && [ "$FAIL" = "$(printf '%s' "$UNM" | wc -w)" ]; then echo "GATE UNPROVEN(2) [$G]: $FAIL of $N arms could not measure their fixtures:$UNM"; exit 2; fi
echo "GATE FAIL(1) [$G]: $FAIL of $N arms red${UNM:+ (could not measure:$UNM)}"; exit 1
