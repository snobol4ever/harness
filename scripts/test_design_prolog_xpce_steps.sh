#!/usr/bin/env bash
# test_design_prolog_xpce_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN prolog-xpce, PROLOG GRAPHICS (the cfo's join, DESIGN.md of
# /home/resources/progress/prolog-graphics-design-2026-11-16, to move to skill prolog reference, THE XPCE FACILITY; cut by officer_05 2026-11-16 on the
# cfo's ask, on the pattern of test_design_icon_xwin_steps.sh). The plan is harness/designs/prolog_xpce/STEPS.tsv; its witnesses are the package-form
# fixture harness/fixtures/prolog_xpce (ALL.csv, NAME.pl, NAME.out, NAME.err, NAME.events, the companions cmp_*.pl, the oracle's pre.pl), graded by
# corpus_suite_harness.py; each joins the Prolog master as an entry xpce__NAME, dialect cell swi, in its cure's landing (skill design-plans section 0).
# THE ORACLE IS swipl 9.0.4 ON ONE THREAD (DESIGN J2): swipl pre.pl NAME.pl, pre.pl the one directive that sets xpce_threaded false.
#   --list          print the steps and run nothing
#   --step N        run step N's probe tokens; rc 0 GREEN when every token is green, 1 RED, 2 could not measure
#   --cut [--out D] cut every fixture entry's answer again, twice, from the one-thread oracle (witnesses/cut.sh's body: a private Xvfb, standard input a
#                   fifo held open and silent so it never ends, XDG_CONFIG_HOME emptied before every run, standard error apart; an entry with a NAME.screen
#                   marker by cut_ladder.sh's body instead: util_screen_run.py with --events NAME.events, its answer its standard output then its screen
#                   line), refusing a disagreement; writes D/NAME.out, D/NAME.err and D/NAME.rc (default a scratch folder) and says SAME or DIFFERS
#                   against the fixture's own NAME.out, NAME.err and want_rc
# TWO KINDS OF ENTRY. ALL.xpce names every entry whose run reaches library(pce) (its program, or a file it loads, names it): those run only through
# THE XPCE RUNNER (step 3, officer_04: util_xpce_run.py, which corpus_suite_harness.py's _xpce_wrap puts in front of the oracle's and SCRIP's command of
# every such entry, inside the screen road; GRADING.md section 2, DESIGN J2 J4 J5): XDG_CONFIG_HOME emptied before every run, standard input a pipe held
# open and silent, pre.pl before the program on the oracle's side; an entry with NAME.display runs under the road's --no-screen. This harness's own
# standard-error runs put the same wrap in front of SCRIP (the one marked place: xpce_runner below). Every other entry is PLAIN. Every entry is
# graded: the board of corpus_suite_harness.py (standard output and rc, mode 3, and mode 4 too when S4E_MODE4=1, COO-487), then its standard
# error against NAME.err by the harness itself, since the board reads a package entry's NAME.err (corpus_suite_harness.py line 3602) and compares it
# nowhere (MEASURED 2026-11-16 at harness ab983818: stderr_answer is read and written and never graded).
# THE PROBE TOKENS (the probe column, space separated; the vocabulary is closed, a token not listed refuses rc 2):
#   baseline            every fixture entry reads red in mode 3 today, each named with its first line, run by hand (scrip --run, stdin /dev/null; a
#                       runner entry off its runner, since red needs no runner), and the board of the plain entries reads 0 passing (step 0)
#   entries=a,b         the named entries pass: stdout and rc by the board, stderr against NAME.err (a runner entry through the XPCE runner)
#   stress=a,b          the same under SCRIP_GC_STRESS=1 and SCRIP_GC_PLANT_FLIP=1; the collector's own report lines on standard error ([GC-FLIP]
#                       and its kin, the proof the plant applied) are no part of the answer and are dropped before the comparison
#   c2bb=a,b            each named entry, run in mode 3 with SCRIP_C2BB_TRACE set, ends with its want_rc and the trace holds 0 lines; REFUSED when the
#                       runtime was built without the trace (no SCRIP_C2BB_TRACE string in out/libscrip_rt.so, RT_DIAG off)
#   obj=FILE            the shared object FILE stands: SCRIP's out/FILE, or, for libxpce.so, the kernel library CURRENT names (OBJ_KERNEL below)
#   objsym=FILE:NAME    that object defines the dynamic symbol NAME
#   noneed=LIB          SCRIP's out/libscrip_rt.so carries no NEEDED entry naming LIB (the binding alone needs the kernel, which alone links X: J1)
#   heapfree=FILE       the object file FILE, found under SCRIP's out/, imports no name that out/libscrip_rt.so defines whose name carries gc, alloc,
#                       heap or descr (ENGINE I1; an object file holds no types, so "no header that declares DESCR_t" is read as no such name)
#   libcfree=FILE       the object FILE (as obj=) imports none of malloc calloc realloc strdup free: GREEN; imports one: REFUSED until the allocation
#                       class table of step 2 (the cio's, beside the kernel recipe) stands and its form is written here, since which sites may is the
#                       table's to say and nm names symbols, never sites (the header line before this harness said "only from XOWNED sites")
#   census=NAME:N       the named saved census (officer_03's census.sh, CENSUS_SH below: Bp and A17) reads count=N; a refusal of it refuses
#   instr=PROG:N        util_instr_count.sh scrip on the fixture entry PROG reads total at most N; REFUSED while N is no number
#   smoke=L             test_smoke_L.sh rc 0
#   cmd=NAME            one command of this closed table, rc 0 green:
#                         xpceload    (step 9, officer_05) three arms: (a) probe/xpce_load.c, linked against out/libscrip_rt.so, finds scrip_xpce_load
#                                     through rt_xpce_sym; (b) probe/xpce_load.pl (the directive use_foreign_library(foreign(pl2xpce)), then a write)
#                                     in mode 3 (and mode 4 when S4E_MODE4=1) prints loaded with rc 0 and nothing on standard error, and maps
#                                     libscrip_xpce.so; (c) probe/xpce_plain.pl maps neither libscrip_xpce.so nor libxpce.so
#                         arena       (step 29, the cfo) probe/arena_probe.c built against SCRIP's src/runtime/xpce/xpce_arena.c and the kernel library
#                                     CURRENT names, run on the screen road's display with no screen read: its three lines ARENA-A, ARENA-B, ARENA-C each end
#                                     ok and its rc is 0, and out/libscrip_xpce.so imports no malloc, calloc or strdup; RED while SCRIP has no arena source,
#                                     REFUSED with no kernel library or kernel tree (S4E_XPCE_TREE names another tree)
#                         kernelbuild, hello, classes  (steps 1 and 2, the cio) the verbs check, hello and classes of util_xpce_kernel_build.sh
#                                     (its rc 0 green, 1 red, 2 refused); RED while that script is absent, never a refusal. The kernel witness
#                                     xpce_k_hello and its refs have one home, harness/xpce with the recipe, and are not in this fixture (the cio)
#                         runner      (step 3, officer_04) three arms, rc 0 green: (a) util_xpce_run.py --probe (the runner on swipl, each part
#                                     fail-once by a plant); (b) corpus_suite_harness.py --probe-xpce-runner (the harness's wiring); (c) every ALL.xpce
#                                     entry cut twice from the oracle THROUGH THE RUNNER (corpus_suite_harness.py expect --keep, DISPLAY unset, so a
#                                     display is the road's alone): the two cuts alike and each byte equal to the fixture's NAME.out, NAME.err and want_rc
#                         rosetta4 (step 24), demos7, demos_fontviewer, demos_broadcast and demos_emacs (steps 25
#                                     to 28, the demos' package entries under the screen road, DESIGN J15; officer_04): REFUSED, their commands are not
#                                     yet named by their seat; the seat names each here in its step's landing
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_paths.sh"
. "$HERE/lib_oracle_flags.sh"
. "$HERE/lib_one_runner.sh" && one_runner_mem_scope
STEPS="$HERE/../designs/prolog_xpce/STEPS.tsv"
FIX="$HERE/../fixtures/prolog_xpce"
CSH="$HERE/corpus_suite_harness.py"
KERNEL_HOME="${S4E_XPCE_KERNEL_HOME:-/home/resources/xpce-kernel}"   # THE KERNEL LIBRARY'S ONE HOME (DESIGN section 1, BOX 2.7; util_xpce_kernel_build.sh): CURRENT names the key whose folder holds libxpce.so; the variable is for a scratch proof of this harness only
refuse() { echo "REFUSE(2) [test_design_prolog_xpce_steps]: $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
[ -f "$FIX/ALL.csv" ] || refuse "no fixture table at $FIX/ALL.csv"
mode=""; step=""; outd=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "--step takes a number"; shift 2 ;;
        --cut) mode=cut; shift ;;
        --out) outd="${2:-}"; [ -n "$outd" ] || refuse "--out takes a folder"; shift 2 ;;
        *) refuse "usage: $0 --list | --step N | --cut [--out DIR]" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N | --cut [--out DIR]"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
fixture_entries() { awk -F, 'NR > 1 {print $2}' "$FIX/ALL.csv"; }
cell() { awk -F, -v e="$1" -v k="$2" 'NR == 1 {for (i = 1; i <= NF; i++) if ($i == k) c = i} NR > 1 && $2 == e {print $c; exit}' "$FIX/ALL.csv"; }
is_entry() { fixture_entries | grep -x "$1" > /dev/null; }
needs_runner() { grep -v '^#' "$FIX/ALL.xpce" 2>/dev/null | grep -qx "$1"; }
runner_entries() { grep -v '^#' "$FIX/ALL.xpce" 2>/dev/null | grep .; }
seat_tmp() { mkdir -p "/tmp/s4e/${S4E_SEAT:-anon}" && mktemp -d "/tmp/s4e/${S4E_SEAT:-anon}/prolog_xpce_$1.XXXXXX"; }   # a seat's run scratch (skill seat-conduct 2)
stage() { local d; d="$(seat_tmp "$1")" || return 1; cp -r "$FIX/." "$d/" && echo "$d"; }
# ⭐ THE XPCE RUNNER, THE ONE MARKED PLACE (step 3, officer_04: GRADING.md section 2; DESIGN J2 the one-thread oracle, J4 standard input held open and
# silent with a screen entry's hold a read of it, J5 XDG_CONFIG_HOME a folder emptied before every run, for both systems). The board grades a runner
# entry through corpus_suite_harness.py, whose _xpce_wrap applies the runner itself; this harness's own runs of SCRIP (its standard-error check and
# c2bb) put the same words in front of the command: xpce_runner ENTRY prints them, nothing for a plain entry (the screen road with --no-screen for an
# entry with NAME.display, with --out screen.dump and its events for a graphics entry, then util_xpce_run.py with no pre.pl, SCRIP's side).
xpce_runner() {
    needs_runner "$1" || return 0
    if [ -e "$FIX/$1.display" ]; then printf '%s ' python3 -I "$HERE/util_screen_run.py" --no-screen --
    elif [ "$(cell "$1" out_files)" = screen.dump ]; then printf '%s ' python3 -I "$HERE/util_screen_run.py" --out screen.dump; [ -f "$FIX/$1.events" ] && printf '%s ' --events "$1.events"; printf '%s ' --; fi
    printf '%s ' python3 -I "$HERE/util_xpce_run.py" --
}
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: prolog-xpce -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 5' "$STEPS" | wc -l) steps (STEPS.tsv), $(fixture_entries | wc -l) witnesses (fixtures/prolog_xpce, $(runner_entries | wc -l) through the XPCE runner)"
    printf '%-4s %-38s %-11s %-12s %s\n' step slug executor depends probe
    awk -F'\t' '!/^#/ && $1 != "step" && NF >= 5 {printf "%-4s %-38s %-11s %-12s %s\n", $1, $2, $3, $4, substr($5, 1, 90)}' "$STEPS"
    exit 0
fi
if [ "$mode" = cut ]; then
    swipl="$(swipl_bin)" || exit 2
    [ -n "$outd" ] || outd="$(seat_tmp cut)"
    mkdir -p "$outd" || refuse "cannot make $outd"
    S="$(seat_tmp cutrun)" || refuse "no scratch"
    mkdir -p "$S/stage" && cp -r "$FIX/." "$S/stage/" || refuse "cannot stage the fixture"
    : > "$S/fd"; exec 3> "$S/fd"; Xvfb -displayfd 3 -screen 0 1024x768x24 -nolisten tcp > "$S/xvfb.log" 2>&1 &
    XP=$!; exec 3>&-
    for i in $(seq 40); do [ -s "$S/fd" ] && break; sleep 0.25; done
    DN="$(cat "$S/fd")"; [ -n "$DN" ] || { kill "$XP"; refuse "no private display"; }
    mkfifo "$S/in" && exec 9<> "$S/in" || { kill "$XP"; refuse "no fifo"; }
    bad=0
    for e in $(fixture_entries); do
        for k in 1 2; do
            rm -rf "$S/cfg"; mkdir "$S/cfg"; rm -f "$S/stage/screen.dump"
            if [ -e "$FIX/$e.screen" ]; then
                ev=(); [ -f "$FIX/$e.events" ] && ev=(--events "$e.events")
                ( cd "$S/stage" && env -u DISPLAY -u XAUTHORITY XDG_CONFIG_HOME="$S/cfg" timeout -k 5 120 python3 -I "$HERE/util_screen_run.py" --out screen.dump "${ev[@]}" -- "$swipl" pre.pl "$e.pl" <&9 > "$S/$e.out$k" 2> "$S/$e.err$k"; echo "$?" > "$S/$e.rc$k" )
                cat "$S/stage/screen.dump" >> "$S/$e.out$k" 2>/dev/null
            else
                ( cd "$S/stage" && env -u XAUTHORITY DISPLAY=":$DN" XDG_CONFIG_HOME="$S/cfg" timeout -k 5 120 "$swipl" pre.pl "$e.pl" <&9 > "$S/$e.out$k" 2> "$S/$e.err$k"; echo "$?" > "$S/$e.rc$k" )
            fi
        done
        if cmp -s "$S/$e.out1" "$S/$e.out2" && cmp -s "$S/$e.err1" "$S/$e.err2" && cmp -s "$S/$e.rc1" "$S/$e.rc2"; then
            cp "$S/$e.out1" "$outd/$e.out"; cp "$S/$e.err1" "$outd/$e.err"; cp "$S/$e.rc1" "$outd/$e.rc"
            w="$(cell "$e" want_rc)"; r="$(cat "$outd/$e.rc")"
            if cmp -s "$outd/$e.out" "$FIX/$e.out" && cmp -s "$outd/$e.err" "$FIX/$e.err" && [ "$r" = "$w" ]; then echo "  CUT $e: SAME as the fixture (rc $r)"
            else echo "  CUT $e: DIFFERS from the fixture (rc $r, want_rc $w)"; [ "$bad" = 0 ] && bad=1; fi
        else echo "  CUT $e: the two runs disagree (NO_ORACLE_ANSWER), kept in $S"; bad=2; fi
    done
    exec 9>&-; kill "$XP"; wait "$XP" 2>/dev/null
    echo "CUT: answers in $outd"; exit "$bad"
fi
probe="$(col "$step" 5)"; slug="$(col "$step" 2)"
[ -n "$slug" ] || refuse "no step $step in $STEPS"
[ -n "$probe" ] && [ "$probe" != "-" ] || refuse "step $step has no probe"
cd "$S4E_SCRIP" || refuse "cannot enter $S4E_SCRIP"
[ -x "$S4E_SCRIP/scrip" ] || refuse "no ./scrip in $S4E_SCRIP"
RT="$S4E_SCRIP/out/libscrip_rt.so"
log="$(mktemp "${TMPDIR:-/tmp}/s4e_prolog_xpce_step.XXXXXX")"
sizes() { echo "-d$(cell "$1" heap_kb)k -s$(cell "$1" stack_kb)k"; }
gc_lines_out() { grep -vE '^\[GC-[A-Z0-9-]+\]' "$1"; }   # the collector's own report lines ([GC-FLIP] and its kin, printed under SCRIP_GC_STRESS and the plant): no oracle prints one, so they are no part of a program's answer
err_same() { cmp -s <(gc_lines_out "$1") "$2"; }
run_m3() {  # run_m3 DIR ENTRY [ENV...]: scrip --run in mode 3 in the staged folder; writes DIR/ENTRY.{o,e,r}
    local d="$1" e="$2"; shift 2
    ( cd "$d" && env "$@" timeout -k 5 "$(cell "$e" timeout_s)" $(xpce_runner "$e") "$S4E_SCRIP/scrip" --run --dialect=swi $(sizes "$e") "$e.pl" < /dev/null > "$e.o" 2> "$e.e"; echo "$?" > "$e.r" )
}
m4_build() {  # m4_build DIR SRC BIN [SWITCH...]: mode 4 as corpus_suite_harness.py compile_m4 builds it: scrip --compile writes assembler, gcc -c, a gold link against SCRIP's runtime
    local d="$1" src="$2" bin="$3"; shift 3
    ( cd "$d" && timeout -k 5 300 "$S4E_SCRIP/scrip" --compile "$@" "$src" --out="$bin.s" < /dev/null > /dev/null 2> "$bin.c4" && gcc -c "$bin.s" -o "$bin.o" 2>> "$bin.c4" && gcc "$bin.o" -fuse-ld=gold -L "$S4E_SCRIP/out" -lscrip_rt -lm -Wl,-rpath,"$S4E_SCRIP/out" -o "$bin" 2>> "$bin.c4" )
}
run_m4() {  # run_m4 DIR ENTRY [ENV...]: the entry built by m4_build, then run; writes DIR/ENTRY.{o4,e4,r4}
    local d="$1" e="$2"; shift 2
    ( cd "$d" && if m4_build "$d" "$e.pl" "$e.m4" --dialect=swi $(sizes "$e"); then
        env "$@" timeout -k 5 "$(cell "$e" timeout_s)" $(xpce_runner "$e") "./$e.m4" < /dev/null > "$e.o4" 2> "$e.e4"; echo "$?" > "$e.r4"; else : > "$e.o4"; cp "$e.m4.c4" "$e.e4"; echo 2 > "$e.r4"; fi )
}
board() {  # board ENTRIES [ENV...]: grade plain entries by corpus_suite_harness, then their stderr; echo green|red|refuse
    local ents="$1"; shift
    local e m part n modes=m3 o line pass all d v=green
    for e in $(printf '%s' "$ents" | tr ',' ' '); do
        is_entry "$e" || { echo "    $e is no entry of the fixture" >> "$log"; echo refuse; return; }
    done
    part="$(printf '%s' "$ents" | tr ',' '\n' | sed 's/^/entry:/' | paste -sd, -)"; n="$(printf '%s' "$ents" | tr ',' '\n' | grep -c .)"
    [ "${S4E_MODE4:-0}" = 1 ] && modes=m3,m4
    o="$(env "$@" timeout -k 5 1800 python3 "$CSH" run "$FIX/ALL.pl" "$FIX/ALL.ref" --lang prolog --modes "$modes" --partition "$part" 2>&1)"
    printf '%s\n' "$o" | grep -E '^  (FAIL|CRASH|HANG|PASS) |^⛔ REFUS|REFUSE\(2\)' | head -20 >> "$log"
    line="$(printf '%s\n' "$o" | grep '^SUITE_BOARD ' | tail -1)"
    [ -n "$line" ] || { echo "    the board printed no SUITE_BOARD line" >> "$log"; echo refuse; return; }
    for m in $(printf '%s' "$modes" | tr ',' ' '); do   # each graded mode's own fields: a mode-3 board prints m3_n and m3_pass, no all_ fields
        pass="$(printf '%s\n' "$line" | sed -n "s/.* ${m}_pass=\([0-9]*\).*/\1/p")"; all="$(printf '%s\n' "$line" | sed -n "s/.* ${m}_n=\([0-9]*\).*/\1/p")"
        [ "$all" = "$n" ] || { echo "    board read ${all:-nothing} of $n entries in $m" >> "$log"; echo refuse; return; }
        [ "$pass" = "$n" ] || v=red
    done
    d="$(stage stderr)" || { echo refuse; return; }
    for e in $(printf '%s' "$ents" | tr ',' ' '); do
        [ -d "$d/$e.fixtures" ] && cp -r "$d/$e.fixtures/." "$d/"   # NAME.fixtures/ is staged where the program runs, as corpus_suite_harness.py's fixtures=staged does (officer_03 2026-11-16, xpce_p_module's companions)
        run_m3 "$d" "$e" "$@"
        err_same "$d/$e.e" "$FIX/$e.err" || { echo "    $e: standard error differs from $e.err in mode 3: $(head -1 "$d/$e.e" | cut -c1-110)" >> "$log"; v=red; }
        if [ "${S4E_MODE4:-0}" = 1 ]; then run_m4 "$d" "$e" "$@"
            err_same "$d/$e.e4" "$FIX/$e.err" || { echo "    $e: standard error differs from $e.err in mode 4: $(head -1 "$d/$e.e4" | cut -c1-110)" >> "$log"; v=red; }; fi
    done
    rm -rf "${d:?}"; echo "$v"
}
obj_path() {  # the shared object a token names: SCRIP's out/FILE; libxpce.so is the kernel library CURRENT names (a key folder under KERNEL_HOME, or a path)
    local f="$1" c
    if [ "$f" = libxpce.so ] && [ ! -f "$S4E_SCRIP/out/$f" ]; then
        [ -s "$KERNEL_HOME/CURRENT" ] || { echo ""; return; }
        c="$(head -1 "$KERNEL_HOME/CURRENT")"; case "$c" in /*) ;; *) c="$KERNEL_HOME/$c" ;; esac
        [ -d "$c" ] && c="$c/libxpce.so"; echo "$c"
    else echo "$S4E_SCRIP/out/$f"; fi
}
# THE SAVED CENSUSES (census=NAME:N): officer_03's one script, designs/prolog_xpce/census/census.sh (PROLOG-LAYER.md; given 2026-11-16 10:1x CST), census.sh Bp or A17, run with SCRIP the
# binary and SEAT the seat, writing only a scratch folder under /tmp/s4e/SEAT; it prints ONE line "CENSUS NAME count=N ..." (rc 0 count 0, 1 above,
# 2 refused, then its line carries no count). Bp (step 5): every layer file's own parse errors with pce's operators supplied, over the 286 files, about
# 100 s at 6 jobs. A17 (step 8): one program loading library(pce), its parse errors plus its undefined directive goals plus the files of the 17 it
# loads in swipl whose load proof fails; about 4 s today, about 50 s once the layer loads, its own limit 900 s. A NAME not listed here refuses.
CENSUS_SH="$HERE/../designs/prolog_xpce/census/census.sh"   # carried here unchanged from officer_03's saved folder, with its files.txt and mkb.py
census_cmd() { case "$1" in Bp|A17) echo "SEAT=\"\${S4E_SEAT:-anon}\" bash $CENSUS_SH $1" ;; *) echo "" ;; esac; }
verdict=0
note() { echo "  $1 -> $2" >> "$log"; case "$2" in green) ;; red) [ "$verdict" = 2 ] || verdict=1 ;; *) verdict=2 ;; esac; }
for tok in $probe; do
    case "$tok" in
        baseline)
            d="$(stage base)" || { note "$tok" refuse; continue; }; n=0; same=0
            for e in $(fixture_entries); do
                n=$((n + 1)); run_m3 "$d" "$e"
                if cmp -s "$d/$e.o" "$FIX/$e.out" && cmp -s "$d/$e.e" "$FIX/$e.err" && [ "$(cat "$d/$e.r")" = "$(cell "$e" want_rc)" ]; then same=$((same + 1)); echo "    $e today: PASSES by hand" >> "$log"
                else echo "    $e today, rc $(cat "$d/$e.r"), first line: $( { cat "$d/$e.e"; cat "$d/$e.o"; } | grep -m1 . | cut -c1-110)" >> "$log"; fi
            done
            rm -rf "${d:?}"
            plain="$(fixture_entries | while read -r e; do needs_runner "$e" || echo "$e"; done | paste -sd, -)"; np="$(printf '%s' "$plain" | tr ',' '\n' | grep -c .)"
            o="$(timeout -k 5 1800 python3 "$CSH" run "$FIX/ALL.pl" "$FIX/ALL.ref" --lang prolog --modes m3 --partition "$(printf '%s' "$plain" | tr ',' '\n' | sed 's/^/entry:/' | paste -sd, -)" 2>&1)"
            line="$(printf '%s\n' "$o" | grep '^SUITE_BOARD ' | tail -1)"
            pass="$(printf '%s\n' "$line" | sed -n 's/.* m3_pass=\([0-9]*\).*/\1/p')"; got="$(printf '%s\n' "$line" | sed -n 's/.* m3_n=\([0-9]*\).*/\1/p')"
            if [ -z "$line" ] || [ "$got" != "$np" ]; then note "baseline (the plain board read ${got:-nothing} of $np)" refuse
            elif [ "$pass" = 0 ] && [ "$same" = 0 ]; then note "baseline (0 of $n pass by hand in mode 3, 0 of $np plain on the board: every witness red today)" green
            else note "baseline ($same of $n pass by hand, $pass of $np plain on the board: a witness that is not red today proves nothing)" red; fi ;;
        entries=*) note "$tok" "$(board "${tok#entries=}")" ;;
        stress=*) note "$tok" "$(board "${tok#stress=}" SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_FLIP=1)" ;;
        c2bb=*)
            [ -f "$RT" ] && grep -aq SCRIP_C2BB_TRACE "$RT" || { echo "    $RT carries no SCRIP_C2BB_TRACE: built without the trace" >> "$log"; note "$tok" refuse; continue; }
            v=green; d="$(stage c2bb)" || { note "$tok" refuse; continue; }
            for e in $(printf '%s' "${tok#c2bb=}" | tr ',' ' '); do
                is_entry "$e" || { echo "    $e is no entry of the fixture" >> "$log"; v=refuse; break; }
                rm -f "$d/$e.c2bb"; run_m3 "$d" "$e" SCRIP_C2BB_TRACE="$d/$e.c2bb"
                h=0; [ -f "$d/$e.c2bb" ] && h="$(grep -c . "$d/$e.c2bb")"
                [ "$(cat "$d/$e.r")" = "$(cell "$e" want_rc)" ] || { echo "    $e ended rc $(cat "$d/$e.r"), want_rc $(cell "$e" want_rc)" >> "$log"; v=red; }
                [ "$h" = 0 ] || { echo "    $e: $h C-to-box entries, first: $(head -1 "$d/$e.c2bb")" >> "$log"; v=red; }
            done
            rm -rf "${d:?}"; note "$tok" "$v" ;;
        obj=*) o="$(obj_path "${tok#obj=}")"
               if [ -z "$o" ]; then echo "    no $KERNEL_HOME/CURRENT: no kernel library stands" >> "$log"; note "$tok" red
               elif [ ! -f "$o" ]; then echo "    no $o" >> "$log"; note "$tok" red
               elif readelf -h "$o" 2>/dev/null | grep 'Type: *DYN' > /dev/null; then note "$tok" green; else echo "    $o is no shared object" >> "$log"; note "$tok" red; fi ;;
        objsym=*) f="${tok#objsym=}"; o="$(obj_path "${f%%:*}")"; y="${f#*:}"
               [ -n "$o" ] && [ -f "$o" ] && nm -D --defined-only "$o" 2>/dev/null | awk '{print $NF}' | grep -x "$y" > /dev/null && note "$tok" green || note "$tok" red ;;
        noneed=*) [ -f "$RT" ] || { note "$tok" refuse; continue; }
               readelf -d "$RT" 2>/dev/null | grep 'NEEDED' | grep "${tok#noneed=}" > /dev/null && note "$tok" red || note "$tok" green ;;
        heapfree=*) [ -f "$RT" ] || { note "$tok" refuse; continue; }
               o="$(find "$S4E_SCRIP/out" -name "${tok#heapfree=}" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
               if [ -z "$o" ]; then echo "    no ${tok#heapfree=} under $S4E_SCRIP/out" >> "$log"; note "$tok" red; continue; fi
               hits="$(comm -12 <(nm --undefined-only "$o" 2>/dev/null | awk '{print $NF}' | sort -u) <(nm -D --defined-only "$RT" 2>/dev/null | awk '{print $NF}' | sort -u) | grep -iE 'gc|alloc|heap|descr')"
               [ -z "$hits" ] && note "$tok" green || { echo "    $o imports from the runtime: $(printf '%s' "$hits" | paste -sd' ' - | cut -c1-200)" >> "$log"; note "$tok" red; } ;;
        libcfree=*) o="$(obj_path "${tok#libcfree=}")"
               if [ -z "$o" ] || [ ! -f "$o" ]; then echo "    no ${o:-kernel library}" >> "$log"; note "$tok" red; continue; fi
               hits="$(nm -D --undefined-only "$o" 2>/dev/null | awk '{print $NF}' | sed 's/@.*//' | grep -xE 'malloc|calloc|realloc|strdup|free' | paste -sd' ' -)"
               if [ -z "$hits" ]; then note "$tok" green
               else echo "    $o imports $hits: the allocation class table of step 2 decides which sites may, and its form is not written here yet" >> "$log"; note "$tok" refuse; fi ;;
        census=*) c="${tok#census=}"; nm_="${c%%:*}"; want="${c#*:}"; cmd="$(census_cmd "$nm_")"
               [ -n "$cmd" ] || { echo "    census $nm_ has no command in this harness" >> "$log"; note "$tok" refuse; continue; }
               o="$(SCRIP="$S4E_SCRIP/scrip" timeout -k 5 1200 bash -c "$cmd" 2>> "$log")"; printf '%s\n' "$o" | grep "^CENSUS " | tail -1 | sed 's/^/    /' >> "$log"
               got="$(printf '%s\n' "$o" | sed -n "s/^CENSUS $nm_ count=\([0-9][0-9]*\)\( .*\)\{0,1\}$/\1/p" | tail -1)"
               if [ -z "$got" ]; then echo "    census $nm_ printed no count" >> "$log"; note "$tok" refuse
               elif [ "$got" = "$want" ]; then note "$tok (read $got)" green; else note "$tok (read $got)" red; fi ;;
        instr=*) c="${tok#instr=}"; p="${c%%:*}"; b="${c#*:}"
               case "$b" in ''|*[!0-9]*) echo "    instr bound $b is no number: the step's seat sets it" >> "$log"; note "$tok" refuse; continue ;; esac
               is_entry "$p" || { echo "    $p is no entry of the fixture" >> "$log"; note "$tok" refuse; continue; }
               d="$(stage instr)"; mkdir -p "$d/cfg"
               o="$(cd "$d" && XDG_CONFIG_HOME="$d/cfg" timeout -k 5 1800 bash "$HERE/util_instr_count.sh" scrip "$p.pl" < /dev/null 2>&1)"; rm -rf "${d:?}"
               t="$(printf '%s\n' "$o" | sed -n 's/^INSTR .* total=\([0-9]*\) .*/\1/p' | tail -1)"
               if [ -z "$t" ]; then echo "    util_instr_count.sh did not count: $(printf '%s\n' "$o" | tail -1 | cut -c1-120)" >> "$log"; note "$tok" refuse
               elif [ "$t" -le "$b" ]; then note "$tok (read $t)" green; else note "$tok (read $t)" red; fi ;;
        smoke=*) bash "$HERE/test_smoke_${tok#smoke=}.sh" >> "$log" 2>&1; r=$?; [ "$r" = 0 ] && note "$tok" green || { [ "$r" = 2 ] && note "$tok" refuse || note "$tok" red; } ;;
        cmd=xpceload)
               d="$(seat_tmp load)"; v=green
               if gcc -O0 -w -o "$d/xpce_load" "$FIX/probe/xpce_load.c" -L"$S4E_SCRIP/out" -Wl,-rpath,"$S4E_SCRIP/out" -lscrip_rt -lm -lpthread -ldl > "$d/cc.log" 2>&1; then
                   timeout -k 5 30 "$d/xpce_load" < /dev/null >> "$log" 2>&1 || { echo "    (a) rt_xpce_sym found no scrip_xpce_load" >> "$log"; v=red; }
               else echo "    (a) the loader probe does not link today: $(grep -m1 -o 'undefined reference to [^ ]*' "$d/cc.log")" >> "$log"; v=red; fi
               cp "$FIX/probe/xpce_load.pl" "$FIX/probe/xpce_plain.pl" "$d/"
               ( cd "$d" && LD_DEBUG=libs LD_DEBUG_OUTPUT="$d/m3.ld" timeout -k 5 120 "$S4E_SCRIP/scrip" --run --dialect=swi xpce_load.pl < /dev/null > m3.out 2> m3.err; echo "$?" > m3.rc )
               if [ "$(cat "$d/m3.rc")" != 0 ] || [ "$(cat "$d/m3.out")" != loaded ] || [ -s "$d/m3.err" ]; then echo "    (b) mode 3: rc $(cat "$d/m3.rc"), out [$(head -c 60 "$d/m3.out" | tr '\n' ' ')], first error line: $(head -1 "$d/m3.err" | cut -c1-110)" >> "$log"; v=red
               elif ! cat "$d"/m3.ld.* 2>/dev/null | grep libscrip_xpce > /dev/null; then echo "    (b) mode 3 printed loaded but mapped no libscrip_xpce.so" >> "$log"; v=red; fi
               if [ "${S4E_MODE4:-0}" = 1 ]; then
                   ( m4_build "$d" xpce_load.pl m4.bin --dialect=swi && cd "$d" && LD_DEBUG=libs LD_DEBUG_OUTPUT="$d/m4.ld" timeout -k 5 120 ./m4.bin < /dev/null > m4.out 2> m4.err; echo "$?" > m4.rc )
                   { [ "$(cat "$d/m4.rc")" = 0 ] && [ "$(cat "$d/m4.out")" = loaded ] && [ ! -s "$d/m4.err" ] && cat "$d"/m4.ld.* 2>/dev/null | grep libscrip_xpce > /dev/null; } || { echo "    (b) mode 4: rc $(cat "$d/m4.rc")" >> "$log"; v=red; }
               fi
               ( cd "$d" && LD_DEBUG=libs LD_DEBUG_OUTPUT="$d/pl.ld" timeout -k 5 120 "$S4E_SCRIP/scrip" --run xpce_plain.pl < /dev/null > pl.out 2> pl.err )
               cat "$d"/pl.ld.* 2>/dev/null | grep -E 'libscrip_xpce|libxpce' > /dev/null && { echo "    (c) a plain program maps the binding or the kernel" >> "$log"; v=red; }
               rm -rf "${d:?}"; note "$tok" "$v" ;;
        cmd=arena)
               d="$(seat_tmp arena)"; v=green; K="$KERNEL_HOME/$(cat "$KERNEL_HOME/CURRENT" 2>/dev/null)"; T="${S4E_XPCE_TREE:-/home/resources/xpce-V9.0.4}"; A="$S4E_SCRIP/src/runtime/xpce/xpce_arena.c"
               if [ ! -f "$K/libxpce.so" ] || [ ! -f "$T/src/h/interface.h" ]; then echo "    no kernel library or no kernel tree: cannot measure" >> "$log"; note "$tok" refuse
               elif [ ! -f "$A" ]; then echo "    no $A" >> "$log"; note "$tok" red
               elif ! gcc -O0 -g -o "$d/arena_probe" "$FIX/probe/arena_probe.c" "$A" -I"$S4E_SCRIP/src" -isystem "$T/src" -L"$K" -lxpce -Wl,-rpath,"$K" > "$d/cc.log" 2>&1; then echo "    the arena probe does not build: $(grep -m1 'error' "$d/cc.log" | cut -c1-110)" >> "$log"; note "$tok" red
               else mkdir -p "$d/cfg"
                   ( cd "$d" && XPCE_APPDATA_DIR="$d/cfg" env -u DISPLAY -u XAUTHORITY timeout -k 5 120 python3 -I "$HERE/util_screen_run.py" --no-screen -- ./arena_probe gif > arena.out 2> arena.err; echo "$?" > arena.rc )
                   grep -a '^ARENA-\|^  FAIL' "$d/arena.out" | sed 's/^/    /' >> "$log"
                   { [ "$(cat "$d/arena.rc")" = 0 ] && [ "$(grep -a -c '^ARENA-[ABC] .* ok$' "$d/arena.out")" = 3 ]; } || { echo "    the probe's rc $(cat "$d/arena.rc"), three lines ending ok wanted" >> "$log"; v=red; }
                   b="$S4E_SCRIP/out/libscrip_xpce.so"
                   if [ ! -f "$b" ]; then echo "    no $b" >> "$log"; v=red
                   elif nm -D --undefined-only "$b" | awk '{print $NF}' | sed 's/@.*//' | grep -x -e malloc -e calloc -e strdup > /dev/null; then echo "    the binding imports a libc allocator that makes a block" >> "$log"; v=red; fi
                   note "$tok" "$v"; fi
               rm -rf "${d:?}" ;;
        cmd=kernelbuild|cmd=hello|cmd=classes)
               k="$HERE/util_xpce_kernel_build.sh"; verb="${tok#cmd=}"; [ "$verb" = kernelbuild ] && verb=check
               if [ ! -f "$k" ]; then echo "    no $k" >> "$log"; note "$tok" red
               else bash "$k" "$verb" >> "$log" 2>&1; r=$?; case "$r" in 0) note "$tok" green ;; 2) note "$tok" refuse ;; *) note "$tok" red ;; esac; fi ;;
        cmd=runner)
               v=green; d="$(seat_tmp runner)"
               python3 -I "$HERE/util_xpce_run.py" --probe >> "$log" 2>&1; r=$?; [ "$r" = 0 ] || { [ "$r" = 2 ] && v=refuse || v=red; }
               python3 "$CSH" --probe-xpce-runner >> "$log" 2>&1; r=$?; [ "$r" = 0 ] || { [ "$r" = 2 ] && v=refuse || { [ "$v" = refuse ] || v=red; }; }
               ents="$(runner_entries | paste -sd, -)"
               for k in 1 2; do
                   env -u DISPLAY -u XAUTHORITY timeout -k 5 1800 python3 "$CSH" expect "$FIX/ALL.pl" "$FIX/ALL.ref" --lang prolog --only "$ents" --jobs 4 --timeout 120 --keep "$d/cut$k" > "$d/cut$k.log" 2>&1 || { echo "    (c) the oracle's cut $k through the runner refused: $(tail -1 "$d/cut$k.log" | cut -c1-140)" >> "$log"; v=refuse; }
               done
               n=0; same=0
               for e in $(runner_entries); do n=$((n + 1)); k1="$d/cut1/$e"; k2="$d/cut2/$e"
                   if ! { cmp -s "$k1.out" "$k2.out" && cmp -s "$k1.err" "$k2.err" && cmp -s "$k1.rc" "$k2.rc"; }; then echo "    (c) $e: the two cuts through the runner disagree" >> "$log"; [ "$v" = green ] && v=refuse; continue; fi
                   if cmp -s "$k1.out" "$FIX/$e.out" && cmp -s "$k1.err" <(cat "$FIX/$e.err" 2>/dev/null) && [ "$(cat "$k1.rc")" = "$(cell "$e" want_rc)" ]; then same=$((same + 1))
                   else echo "    (c) $e: the runner's cut differs from the fixture (rc $(cat "$k1.rc"), want_rc $(cell "$e" want_rc))" >> "$log"; [ "$v" = green ] && v=red; fi
               done
               echo "    (c) $same of $n runner entries cut twice alike through the runner and byte equal to the fixture" >> "$log"
               [ "$n" -gt 0 ] || v=refuse
               rm -rf "${d:?}"; note "$tok" "$v" ;;
        cmd=rosetta4|cmd=demos7|cmd=demos_fontviewer|cmd=demos_broadcast|cmd=demos_emacs) echo "    $tok: its command is not yet named by its seat (officer_04)" >> "$log"; note "$tok" refuse ;;
        *) echo "    unknown probe token $tok" >> "$log"; note "$tok" refuse ;;
    esac
done
tail -60 "$log"; rm -f "$log"
case "$verdict" in 0) v=GREEN ;; 1) v=RED ;; *) v=REFUSED ;; esac
echo "VERDICT: STEP $step $slug: -> $v"
exit "$verdict"
