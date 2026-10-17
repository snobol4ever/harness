#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture over scratch packages outside corpus, not a board (CEO-547)"
# test_gate_icon_package_units_carry_their_attribute_row.sh -- EVERY UNIT THE THREE ICON PACKAGE RUNNERS LOOK UP HAS ITS ROW, A DRIVER'S
# UNDER ITS LIBRARY'S KEY, AND A UNIT WITH NONE IS NAMED BY THE RUNNER. RULES.md hard-cap rule clause 8 (f) (ceo CEO-1281): "A
# declaration that is missing is a gap the runner names, never a default silently taken."
#
# ⛔⭐ WHY (coo 2026-09-27, on hq_icon's ask of where IPL iftrace's --stlimit lives): corpus 4d805e1bc (2026-09-25) gave every unit the
# runners looked up a row, read off SCRIP_DECL_MISS_LOG over one full pass. The drivers of CEO-1269/1272 came after it, and nothing
# re-read: 382 graded units had no row (IPL 356 -- all 340 driver-graded libraries and 16 progs graded through argv, dat or fixtures
# sidecars -- Arizona 23, Jcon 3) and 275 more IPL files the compile tier looks up. SCRIP 286483382 (compile_args landing 3) then
# stopped the runners typing --stlimit for every program, proven on the compile tier alone, which walks no driver; from 2026-09-26
# 23:01Z the 382 ran with no declared switch, heap or stack, and no line of any board said so, because every lookup answers "nothing
# declared" alike for a row that declares nothing and for no row at all, and _decl_miss logged only when a variable was set. And the
# Jcon runner looked a driver's attributes up under the DRIVER's name ("link2_driver"), a row no table carries.
#
#   W   PREMISE: the witness driver's output is a trace, so it equals the Icon oracle's with --stlimit and differs without it, in both
#       modes, in each runner's own invocation. ⛔ THE TRACED PROCEDURE LIVES IN THE FILE WHOSE NAME SCRIP PRINTS IN THAT INVOCATION:
#       a trace line carries its procedure's file, and on origin a58f8e68c SCRIP names every procedure after the driver when the
#       library is found through IPATH (the IPL and Arizona runners -- hq_icon's open iftrace defect) and after the LAST file when the
#       library is handed over on the command line (the Jcon runner's two-file build). So the IPATH witness traces a procedure the
#       driver defines, and the two-file witness one the library defines: each prints the right name before hq_icon's cure (a linked
#       procedure names its own file) and after it.
#   R   declared_row_in_table (lib_declared_arena.sh): rc 0 for a declaring row; rc 1 AND a "⛔ UNDECLARED (RULES.md 8 (f))" line naming
#       the unit, for no row and for a row whose every cell is empty; rc 2 for no table
#   U   THE CENSUS on the real corpus: util_icon_package_units.py missing reads 0 for ipl, arizona_tests and jcon_tests, the looked-up
#       population printed beside each
#   F   FAIL-ONCE for the census: a scratch Jcon-shaped package whose driver-graded library has no row reads rc 1 naming the library
#   J, A, I   the Jcon, Arizona and IPL runners, each on a scratch package outside corpus and a scratch progress table: the witness
#       library `lib`, graded through lib_driver, with its row keyed by the LIBRARY and declaring --stlimit, reads PASS in both modes
#       (under the driver's key -- Jcon until this landing -- it reads FAIL: no row, no switch, no trace); and `bare`, a program with no
#       row, is named on the runner's "-- undeclared ... : 1 --" line and nothing else is
#
# FAIL-ONCE, MEASURED 2026-09-27 (coo), in a detached worktree of origin a58f8e68c (its lib_declared_arena.sh and three runners, this
# gate and util_icon_package_units.py copied in, the real corpus beside it): 4 of 7 red -- R (declared_row_in_table: command not
# found), and J, A and I print no undeclared line, J reading lib FAIL/FAIL besides (its driver's key found no row, so no switch);
# W and F green by construction. And U over corpus 8a8dcd74c's three tables (a scratch copy): RED, 631, 23 and 3 missing. On this
# landing: 7 of 7.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=icon_package_units_carry_their_attribute_row
unproven() { echo "GATE UNPROVEN(2) [$G]: $*"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "test_gate_$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" >/dev/null 2>&1 || unproven "this tree's binary is stale or unbuilt -- run make"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || unproven "lib_oracle_flags.sh unloadable"
. "$HERE/lib_declared_arena.sh" 2>/dev/null || unproven "lib_declared_arena.sh unloadable"
ICON="$(icon_bin)"; ICONT="$(icont_bin)"; [ -x "$ICON" ] && [ -x "$ICONT" ] || unproven "the Icon oracle (icon, icont) is absent"
CORPUS="${S4E_CORPUS:-$(cd "$ROOT/.." && pwd)/corpus}"; [ -d "$CORPUS/packages/icon" ] || unproven "no corpus at $CORPUS"
SCRIP="$ROOT/scrip"; RT="$ROOT/out"; U="$HERE/util_icon_package_units.py"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_iconrows.XXXXXX")" || unproven "mktemp failed"
trap 'rm -rf "$W"' EXIT
unset SCRIP_SNO_STMTKW
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1: $2"; }
red() { FAIL=$((FAIL+1)); echo "  ⛔ $1 RED: $2"; }

# ── W: the witness ─────────────────────────────────────────────────────────────────────────────────────────────────────────
mkw() {  # <dir> <driver|lib> -- lib.icn and lib_driver.icn, the traced call and its procedure both in the named file; the refs; bare.icn
    mkdir -p "$1"
    if [ "$2" = lib ]; then   # every trace line is the library's: run() turns tracing on around its own call of libp
        printf 'procedure libp(x);\n  return x * 2;\nend\nprocedure run();\n  &trace := -1;\n  write(libp(1));\n  &trace := 0;\nend\n' > "$1/lib.icn"
        printf 'link lib\nprocedure main();\n  run();\nend\n' > "$1/lib_driver.icn"
    else                      # every trace line is the driver's: main calls q, which the driver defines
        printf 'procedure libp(x);\n  return x * 2;\nend\n' > "$1/lib.icn"
        printf 'link lib\nprocedure q(x);\n  return x + 1;\nend\nprocedure main();\n  write(libp(1));\n  &trace := -1;\n  write(q(1));\n  &trace := 0;\nend\n' > "$1/lib_driver.icn"
    fi
    printf 'procedure main();\n  write("bare");\nend\n' > "$1/bare.icn"
    # icont links ucode, never source: the library is translated first (-c), as the ref cutters do, and its ucode leaves with the ref
    ( cd "$1" && "$ICONT" -s -c lib.icn < /dev/null > /dev/null 2>&1 && IPATH="$1" timeout -k 5 20 "$ICON" lib_driver.icn < /dev/null > lib_driver.ref 2>&1 \
      && timeout -k 5 20 "$ICON" bare.icn < /dev/null > bare.ref 2>&1; rm -f lib.u1 lib.u2 )
}
mkw "$W/wd" driver; mkw "$W/wl" lib
run_w() {  # <dir> <mode> <switch> <extra source> -- the witness run as the runner that uses that invocation runs it
    if [ "$2" = m3 ]; then ( cd "$1" && IPATH="$1" timeout -k 5 20 "$SCRIP" --run $3 lib_driver.icn $4 < /dev/null 2>&1 )
    else ( cd "$1" && IPATH="$1" "$SCRIP" --compile $3 lib_driver.icn $4 > "$1/w.s" 2>/dev/null < /dev/null && gcc -no-pie "$1/w.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$1/w.bin" 2>/dev/null && ( cd "$1" && timeout -k 5 20 ./w.bin < /dev/null 2>&1 ); rm -f "$1/w.s" "$1/w.bin" ); fi
}
wbad=""
for v in "wd:" "wl:$W/wl/lib.icn"; do
    d="$W/${v%%:*}"; x="${v#*:}"; o="$(cat "$d/lib_driver.ref")"
    [ "$(printf '%s\n' "$o" | wc -l)" -ge 2 ] || wbad="$wbad ${v%%:*}: the oracle printed $(printf '%s\n' "$o" | wc -l) line(s) ($(head -1 "$d/lib_driver.ref"));"
    for m in m3 m4; do
        [ "$(run_w "$d" $m --stlimit "$x")" = "$o" ] || wbad="$wbad ${v%%:*} $m with the switch differs from the oracle;"
        [ "$(run_w "$d" $m '' "$x")" != "$o" ] || wbad="$wbad ${v%%:*} $m without the switch equals the oracle;"
    done
done
[ -z "$wbad" ] && ok W "both witnesses match the oracle's trace with --stlimit and not without, in m3 and m4: the driver-traced one through IPATH (IPL, Arizona), the library-traced one with the library on the command line (Jcon)" \
    || unproven "a witness no longer tells the switch from its absence --$wbad"

# ── R: the reader ──────────────────────────────────────────────────────────────────────────────────────────────────────────
HDR='rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb,compile_args,run_args'
printf '%s\n1,lib,x__lib,x,3,0,0,131072,4096,--stlimit,\n2,empty,x__empty,x,3,0,0,,,,\n' "$HDR" > "$W/r.csv"
declared_memory_table "$W/r.csv" > "$W/r.tsv" 2>/dev/null
declared_row_in_table "$W/r.tsv" lib 2>"$W/r0.err"; r0=$?
declared_row_in_table "$W/r.tsv" nosuch 2>"$W/r1.err"; r1=$?
declared_row_in_table "$W/r.tsv" empty 2>"$W/re.err"; re=$?
declared_row_in_table "$W/no_such_table.tsv" lib 2>/dev/null; r2=$?
if [ "$r0" = 0 ] && [ ! -s "$W/r0.err" ] && [ "$r1" = 1 ] && grep -q '^⛔ UNDECLARED (RULES.md 8 (f)): nosuch ' "$W/r1.err" \
   && [ "$re" = 1 ] && grep -q '^⛔ UNDECLARED (RULES.md 8 (f)): empty ' "$W/re.err" && [ "$r2" = 2 ]; then
    ok R "a declaring row reads rc 0 silently; no row and an all-empty row each read rc 1 with the UNDECLARED line naming the unit; no table reads rc 2"
else
    red R "rc declaring=$r0 norow=$r1 allempty=$re notable=$r2 (want 0 1 1 2); stderr: $(head -1 "$W/r1.err") | $(head -1 "$W/re.err")"
fi

# ── U: the census on the real corpus, F: its FAIL-ONCE ─────────────────────────────────────────────────────────────────────
ucen=""; ured=0
for p in ipl arizona_tests jcon_tests; do
    m="$(python3 "$U" missing "$CORPUS/packages/icon/$p" 2>"$W/u.err")"; rc=$?
    [ "$rc" = 2 ] && unproven "the census could not read $p: $(head -1 "$W/u.err")"
    ucen="$ucen; $(cat "$W/u.err")"
    [ "$rc" = 0 ] || { ured=1; ucen="$ucen -- missing: $(printf '%s\n' "$m" | head -8 | tr '\n' ' ')$([ "$(printf '%s\n' "$m" | wc -l)" -gt 8 ] && echo '...')"; }
done
[ "$ured" = 0 ] && ok U "every looked-up unit has its row${ucen}" || red U "a unit the runner looks up has no row -- write it with util_icon_package_units.py rows <pkg> --apply${ucen}"
mkdir -p "$W/f/jcon_tests"; cp "$W/wl/"*.icn "$W/wl/"*.ref "$W/f/jcon_tests/"; printf '%s\n1,bare,jcon_tests__bare,jcon_tests,3,0,0,131072,4096,--stlimit,\n' "$HDR" > "$W/f/jcon_tests/ALL.csv"
fm="$(python3 "$U" missing "$W/f/jcon_tests" 2>/dev/null)"; frc=$?
[ "$frc" = 1 ] && [ "$fm" = lib ] && ok F "a driver-graded library with no row reads rc 1 and is named by its library's key ('$fm')" \
    || red F "the census over a package missing lib's row read rc=$frc names=[$fm] (want rc 1, lib)"

# ── J, A, I: the three runners ─────────────────────────────────────────────────────────────────────────────────────────────
outcome() { awk -F'\t' -v p="$2" -v m="$3" 'NR>1 && $8==p && $9==m {print $10}' "$1" 2>/dev/null | tail -1; }
runner_arm() {  # <arm> <db> <progress name of lib> <undeclared key of bare> <env...> -- <runner and args>
    local a="$1" db="$2" lk="$3" bk="$4" o r; shift 4; local -a e=(); while [ "$1" != -- ]; do e+=("$1"); shift; done; shift
    o="$(cd "$ROOT" && env S4E_PROGRESS_DB="$db" S4E_SCORE_NO_WRITE="gate $G" "${e[@]}" timeout -k 5 300 bash "$@" 2>&1)"; r=$?
    local l3 l4 und names
    l3="$(outcome "$db" "$lk" m3)"; l4="$(outcome "$db" "$lk" m4)"
    und="$(printf '%s\n' "$o" | sed -n 's/^-- undeclared (RULES.md 8 (f).*: \([0-9][0-9]*\) --$/\1/p' | tail -1)"
    names="$(printf '%s\n' "$o" | awk '/^-- undeclared \(RULES.md 8 \(f\)/ {f=1; next} f && /^   [^ ]+$/ {sub(/^   /, ""); print; next} f {exit}' | tr '\n' ' ' | sed 's/ $//')"
    if [ "$r" = 2 ] || [ "$r" = 124 ]; then red "$a" "the runner could not measure its fixture (rc=$r): $(printf '%s\n' "$o" | grep -E 'REFUSE|⛔' | head -2 | tr '\n' ' ')"; return; fi
    if [ "$l3" = PASS ] && [ "$l4" = PASS ] && [ "$und" = 1 ] && [ "$names" = "$bk" ]; then
        ok "$a" "lib, graded through lib_driver under its library's row, reads PASS/PASS; the undeclared line names exactly '$names'"
    else
        red "$a" "lib ${l3:-none}/${l4:-none} (want PASS/PASS -- a FAIL means the switch keyed by the library never reached the driver's compile); undeclared=${und:-no line} names=[$names] (want 1 [$bk])"
    fi
}
J="$W/jcon"; mkw "$J" lib; printf '%s\n1,lib,jcon_tests__lib,jcon_tests,3,0,0,131072,4096,--stlimit,\n' "$HDR" > "$J/ALL.csv"
runner_arm J "$W/j.tsv" lib bare -- "$HERE/test_icon_jcon_suite.sh" --corpus "$J"
A="$W/az/corpus/packages/icon/arizona_tests"; mkw "$A/general" driver; mkdir -p "$A/special"; printf '%s\n1,general/lib,arizona_tests__general/lib,arizona_tests,3,0,0,131072,4096,--stlimit,\n' "$HDR" > "$A/ALL.csv"
runner_arm A "$W/a.tsv" general/lib general/bare S4E_HOME="$W/az" -- "$HERE/test_icon_arizona_suite.sh"   # the board keys <subdir>/<stem> (b4f66ce42, CEO-1366 (b))
P="$W/ipl/corpus/packages/icon/ipl"; mkw "$P/procs" driver; for d in progs gprogs gprocs incl gincl; do mkdir -p "$P/$d"; done
mv "$P/procs/bare.icn" "$P/procs/bare.ref" "$P/progs/"
printf '%s\n1,procs/lib,ipl__procs/lib,ipl,3,0,0,131072,4096,--stlimit,\n' "$HDR" > "$P/ALL.csv"
runner_arm I "$W/i.tsv" procs/lib progs/bare S4E_HOME="$W/ipl" -- "$HERE/test_icon_ipl_suite.sh"

echo "GATE $([ "$FAIL" = 0 ] && echo PASS || echo "FAIL($FAIL)") [$G]: $PASS of $((PASS + FAIL)) arms green (population: 3 real tables, 3 runners on scratch packages)"
[ "$FAIL" = 0 ]
