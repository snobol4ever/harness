#!/usr/bin/env bash
# test_design_icon_xwin_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN icon-xwin, THE WINDOW FACILITY (the cto's design, skill icon reference.md
# section 9; the table and the witnesses cut by officer_08 2026-11-16 on the cto's deal). The plan is harness/designs/icon_xwin/STEPS.tsv; its witnesses
# are the package-form fixture harness/fixtures/icon_xwin (ALL.csv with out_files=screen.dump, NAME.icn, NAME.out), graded by corpus_suite_harness.py
# on THE SCREEN ROAD, the road the cycle grades a graphics entry by (skill suites-and-grading section 4): each run on an Xvfb of its own, its answer its
# standard output then its screen line. A witness joins the icon master in its cure's landing (skill design-plans section 0).
#   --list          print the steps and run nothing
#   --step N        run step N's probe tokens; rc 0 GREEN when every token is green, 1 RED, 2 could not measure
#   --cut [--out D] cut every fixture's answer again from the graphics oracle (graphics_icont_bin, graphics_iconx_bin), twice under the screen road, refusing a
#                   disagreement; writes D/NAME.out (default a scratch folder) and says SAME or DIFFERS against the fixture's own NAME.out
# THE PROBE TOKENS (the probe column, space separated; the vocabulary is closed, a token not listed refuses rc 2):
#   baseline            every fixture entry reads red in mode 3 today, each named with its first line (step 0, the fail-once record)
#   entries=a,b         the named fixture entries pass in mode 3 (and mode 4 too when S4E_MODE4=1, COO-487: the grading road is mode 3 only)
#   stress=a,b          the same twice more: under SCRIP_GC_STRESS=1 and SCRIP_GC_PLANT_FLIP=1 (the C collection), and under SCRIP_DIAG=0 with
#                       no plant at a 64 KB heap (the asm collection, the one an ordinary run takes; the cao and the cto 2026-11-16 09:4x CST)
#   fixture=NAME        every entry of the package-form fixture harness/fixtures/NAME passes in mode 3 by its own screen road (W5: icon_xwin_fn, officer_07's
#                       ladder of the 48 window functions, one witness a function, its entry names the function)
#   pkg=P:e1,e2         the named entries of corpus package packages/icon/P pass in mode 3 by its own screen road
#   sym=NAME            NAME is a defined dynamic symbol of SCRIP's out/libscrip_rt.so
#   noneed=LIB          SCRIP's out/libscrip_rt.so carries no NEEDED entry naming LIB (the window object alone links X, CIO-67 (4))
#   obj=FILE            SCRIP's out/FILE stands and names libX11 among its NEEDED libraries (the window object, W3)
#   objsym=FILE:NAME    SCRIP's out/FILE defines the dynamic symbol NAME
#   cmd=xwload          (W3) fixtures/icon_xwin/probe/xwin_load.c, linked against out/libscrip_rt.so, finds bt_DrawLine through rt_xwin_sym
#   loads=e             the fixture entry e, run in mode 3 (and as a mode 4 binary when S4E_MODE4=1), maps libscrip_xwin (LD_DEBUG=libs)
#   noload              a plain one-line program maps no libscrip_xwin (the window object costs a program that does not name it nothing)
#   kind=HB_X:CLASS     harness gc_kind_witnesses.tsv carries the row HB_X with class CLASS
#   cmd=NAME            one command of the closed table below, rc 0 green: rtx (test_rtx_unit.sh), screen (util_screen_run.py --probe),
#                       smoke (test_smoke_icon.sh), events (W7: util_screen_run.py takes --events FILE), screvents (W7: corpus_suite_harness.py --probe-screen-events), gen (the W1 gate, officer_07: util_gen_icon_xwin_device.py --check /home/resources/progress/ICON-XWIN-TREE-W1 --syntax --link-census)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_paths.sh"
. "$HERE/lib_oracle_flags.sh"
. "$HERE/lib_one_runner.sh" && one_runner_mem_scope
STEPS="$HERE/../designs/icon_xwin/STEPS.tsv"
FIX="$HERE/../fixtures/icon_xwin"
CSH="$HERE/corpus_suite_harness.py"
refuse() { echo "REFUSE(2) [test_design_icon_xwin_steps]: $*" >&2; exit 2; }
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
screen_of() { awk -F, -v e="$1" 'NR > 1 && $2 == e {print ($12 == "screen.dump") ? "screen" : "plain"}' "$FIX/ALL.csv"; }
# THE LOADED LIBRARIES ARE THIS RUN'S OWN: each is built from the fixture's lib/NAME.c into a private scratch folder, never committed and never shared,
# and the run exports where they stand: ICON_XWIN_LIBS (a witness loads "$ICON_XWIN_LIBS/NAME.so") and GC_LREC_HELPER (the cao's W2 programs).
# MEASURED 2026-11-16 10:0x CST: one shared folder, /home/resources/progress/icon-xwin-libs, was rebuilt by every copy of this harness from its
# own lib/ source, so the grader's run of a patch that grew the W2 helper loaded the origin copy's older helper halfway through and read RED.
LIBS="$(mktemp -d "${TMPDIR:-/tmp}/s4e_icon_xwin_libs.XXXXXX")" || refuse "cannot make a private library folder"
trap 'rm -rf "${LIBS:?}"' EXIT
export ICON_XWIN_LIBS="$LIBS" GC_LREC_HELPER="$LIBS/xwin_w2_lrec.so"
build_libs() {
    local c n
    for c in "$FIX"/lib/*.c; do
        [ -f "$c" ] || continue; n="$(basename "$c" .c)"
        gcc -shared -fPIC -O1 -w -I"$FIX/lib" -I"$S4E_SCRIP/src" -I"$S4E_SCRIP/src/runtime/rt" -o "$LIBS/$n.so.new" "$c" 2> "$LIBS/$n.build.log" && mv -f "$LIBS/$n.so.new" "$LIBS/$n.so" || { rm -f "$LIBS/$n.so" "$LIBS/$n.so.new"; echo "    lib $n does not build today: $(head -1 "$LIBS/$n.build.log")"; }
    done
}
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: icon-xwin -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 5' "$STEPS" | wc -l) steps (STEPS.tsv), $(fixture_entries | wc -l) witnesses (fixtures/icon_xwin)"
    printf '%-4s %-34s %-11s %-8s %s\n' step slug executor depends probe
    awk -F'\t' '!/^#/ && $1 != "step" && NF >= 5 {printf "%-4s %-34s %-11s %-8s %s\n", $1, $2, $3, $4, substr($5, 1, 90)}' "$STEPS"
    exit 0
fi
if [ "$mode" = cut ]; then
    icont="$(graphics_icont_bin)" || exit 2; iconx="$(graphics_iconx_bin)" || exit 2
    [ -n "$outd" ] || outd="$(mktemp -d "${TMPDIR:-/tmp}/s4e_icon_xwin_cut.XXXXXX")"
    mkdir -p "$outd" || refuse "cannot make $outd"
    bad=0; build_libs
    for e in $(fixture_entries); do
        grep -qx "$e" "$FIX/NOT-ORACLE.txt" 2>/dev/null && { echo "  CUT $e: its answer is not the oracle's (NOT-ORACLE.txt), kept as it stands"; continue; }
        for k in 1 2; do
            d="$outd/.run$k/$e"; mkdir -p "$d"; cp "$FIX/$e.icn" "$d/"; ev=(); [ -f "$FIX/$e.events" ] && { cp "$FIX/$e.events" "$d/"; ev=(--events "$e.events"); }
            ( cd "$d" && timeout -k 5 60 "$icont" -s -o "$e" "$e.icn" < /dev/null ) || { echo "  CUT $e: icont refused"; bad=2; continue 2; }
            if [ "$(screen_of "$e")" = screen ]; then
                ( cd "$d" && rm -f screen.dump && timeout -k 5 120 env -u DISPLAY python3 -I "$HERE/util_screen_run.py" --out screen.dump "${ev[@]}" -- "$iconx" "./$e" < /dev/null > out.txt 2> err.txt; echo "$?" > rc.txt )
            else
                ( cd "$d" && : > screen.dump && timeout -k 5 120 "$iconx" "./$e" < /dev/null > out.txt 2> err.txt; echo "$?" > rc.txt )
            fi
            cat "$d/out.txt" "$d/screen.dump" > "$d/answer" 2>/dev/null
        done
        r1="$(cat "$outd/.run1/$e/rc.txt")"; r2="$(cat "$outd/.run2/$e/rc.txt")"
        if [ "$r1" != 0 ] || [ "$r2" != 0 ]; then echo "  CUT $e: the oracle ended rc $r1 and $r2: $(head -c 200 "$outd/.run1/$e/err.txt")"; bad=2; continue; fi
        cmp -s "$outd/.run1/$e/answer" "$outd/.run2/$e/answer" || { echo "  CUT $e: the two runs disagree (NO_ORACLE_ANSWER)"; bad=2; continue; }
        cp "$outd/.run1/$e/answer" "$outd/$e.out"
        if cmp -s "$outd/$e.out" "$FIX/$e.out"; then echo "  CUT $e: SAME as the fixture"; else echo "  CUT $e: DIFFERS from the fixture"; [ "$bad" = 0 ] && bad=1; fi
    done
    echo "CUT: answers in $outd"; exit "$bad"
fi
probe="$(col "$step" 5)"; slug="$(col "$step" 2)"
[ -n "$slug" ] || refuse "no step $step in $STEPS"
[ -n "$probe" ] && [ "$probe" != "-" ] || refuse "step $step has no probe"
cd "$S4E_SCRIP" || refuse "cannot enter $S4E_SCRIP"
[ -x "$S4E_SCRIP/scrip" ] || refuse "no ./scrip in $S4E_SCRIP"
RT="$S4E_SCRIP/out/libscrip_rt.so"
log="$(mktemp "${TMPDIR:-/tmp}/s4e_icon_xwin_step.XXXXXX")"
board() {  # board DIR ENTRIES [ENV...]: grade by corpus_suite_harness, echo green|red|refuse
    local dir="$1" ents="$2"; shift 2
    local part n modes=m3 o line pass all
    part="$(printf '%s' "$ents" | tr ',' '\n' | sed 's/^/entry:/' | paste -sd, -)"; n="$(printf '%s' "$ents" | tr ',' '\n' | grep -c .)"
    [ "${S4E_MODE4:-0}" = 1 ] && modes=m3,m4
    o="$(env "$@" timeout -k 5 1800 python3 "$CSH" run "$dir/ALL.icn" "$dir/ALL.ref" --lang icon --modes "$modes" --partition "$part" 2>&1)"
    printf '%s\n' "$o" | grep -E '^  (FAIL|CRASH|HANG|PASS) |^⛔ REFUS|REFUSE\(2\)' | head -20 >> "$log"
    line="$(printf '%s\n' "$o" | grep '^SUITE_BOARD ' | tail -1)"
    [ -n "$line" ] || { echo refuse; return; }
    pass="$(printf '%s\n' "$line" | sed -n 's/.* all_pass=\([0-9]*\).*/\1/p')"; all="$(printf '%s\n' "$line" | sed -n 's/.* all_n=\([0-9]*\).*/\1/p')"
    [ "$all" = "$n" ] || { echo "board read $all of $n entries" >> "$log"; echo refuse; return; }
    [ "$pass" = "$n" ] && echo green || echo red
}
verdict=0
case " $probe " in *" baseline "*|*" entries="*|*" stress="*) build_libs >> "$log" ;; esac
note() { echo "  $1 -> $2" >> "$log"; case "$2" in green) ;; red) [ "$verdict" = 2 ] || verdict=1 ;; *) verdict=2 ;; esac; }
for tok in $probe; do
    case "$tok" in
        baseline)
            all="$(fixture_entries | paste -sd, -)"; n="$(fixture_entries | grep -c .)"
            for e in $(fixture_entries); do
                d="$(mktemp -d "${TMPDIR:-/tmp}/s4e_icon_xwin_base.XXXXXX")"; cp "$FIX/$e.icn" "$d/"
                if [ "$(screen_of "$e")" = screen ]; then o="$(cd "$d" && timeout -k 5 120 python3 "$HERE/util_screen_run.py" --out screen.dump -- "$S4E_SCRIP/scrip" --run "$e.icn" < /dev/null 2>&1)"
                else o="$(cd "$d" && timeout -k 5 120 "$S4E_SCRIP/scrip" --run "$e.icn" < /dev/null 2>&1)"; fi
                echo "    $e today, first line: $(printf '%s\n' "$o" | grep -m1 . | cut -c1-110)" >> "$log"
                rm -rf "${d:?}"
            done
            o="$(timeout -k 5 1800 python3 "$CSH" run "$FIX/ALL.icn" "$FIX/ALL.ref" --lang icon --modes m3 2>&1)"
            line="$(printf '%s\n' "$o" | grep '^SUITE_BOARD ' | tail -1)"
            pass="$(printf '%s\n' "$line" | sed -n 's/.* m3_pass=\([0-9]*\).*/\1/p')"; got="$(printf '%s\n' "$line" | sed -n 's/.* m3_n=\([0-9]*\).*/\1/p')"
            if [ -z "$line" ] || [ "$got" != "$n" ]; then note "baseline (the board read ${got:-nothing} of $n)" refuse
            elif [ "$pass" = 0 ]; then note "baseline (0 of $n pass in mode 3: every witness red today)" green
            else note "baseline ($pass of $n already pass: a witness that is not red today proves nothing)" red; fi ;;
        entries=*) note "$tok" "$(board "$FIX" "${tok#entries=}")" ;;
        stress=*)  # two collections: the plants take the C collection; only SCRIP_DIAG=0 with no plant runs the asm collection an ordinary run uses (the cao, SCRIP 8a0dff7d6)
               note "$tok (C collection: stress 1 and flip)" "$(board "$FIX" "${tok#stress=}" SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_FLIP=1)"
               note "$tok (asm collection: SCRIP_DIAG=0, a 64 KB heap)" "$(board "$FIX" "${tok#stress=}" SCRIP_DIAG=0 SCRIP_HEAP_KB=64)" ;;
        fixture=*) fd="$HERE/../fixtures/${tok#fixture=}"; [ -f "$fd/ALL.csv" ] || { echo "    no fixture table $fd/ALL.csv" >> "$log"; note "$tok" refuse; continue; }
               note "$tok" "$(board "$fd" "$(awk -F, 'NR > 1 {print $2}' "$fd/ALL.csv" | paste -sd, -)")" ;;
        pkg=*) p="${tok#pkg=}"; note "$tok" "$(board "$S4E_CORPUS/packages/icon/${p%%:*}" "${p#*:}")" ;;
        sym=*) [ -f "$RT" ] || { note "$tok" refuse; continue; }
               nm -D --defined-only "$RT" 2>/dev/null | awk '{print $NF}' | grep -x "${tok#sym=}" > /dev/null && note "$tok" green || note "$tok" red ;;
        noneed=*) [ -f "$RT" ] || { note "$tok" refuse; continue; }
               readelf -d "$RT" 2>/dev/null | grep 'NEEDED' | grep "${tok#noneed=}" > /dev/null && note "$tok" red || note "$tok" green ;;
        obj=*) o="$S4E_SCRIP/out/${tok#obj=}"; if [ ! -f "$o" ]; then echo "    no $o" >> "$log"; note "$tok" red
               elif readelf -d "$o" 2>/dev/null | grep NEEDED | grep libX11 > /dev/null; then note "$tok" green; else echo "    $o needs no libX11" >> "$log"; note "$tok" red; fi ;;
        objsym=*) o="$S4E_SCRIP/out/${tok#objsym=}"; o="${o%%:*}"; y="${tok#*:}"; [ -f "$o" ] && nm -D --defined-only "$o" 2>/dev/null | awk '{print $NF}' | grep -x "$y" > /dev/null && note "$tok" green || note "$tok" red ;;
        loads=*|noload)  # the window object is loaded by the program that names it, and by no other (LD_DEBUG=libs names every object the loader maps)
               if [ "$tok" = noload ]; then e=""; d="$(mktemp -d "${TMPDIR:-/tmp}/s4e_icon_xwin_load.XXXXXX")"; printf 'procedure main()\n   write("plain");\nend\n' > "$d/plain.icn"; src=plain.icn
               else e="${tok#loads=}"; d="$(mktemp -d "${TMPDIR:-/tmp}/s4e_icon_xwin_load.XXXXXX")"; cp "$FIX/$e.icn" "$d/"; src="$e.icn"; fi
               ( cd "$d" && LD_DEBUG=libs timeout -k 5 120 python3 "$HERE/util_screen_run.py" --out screen.dump -- "$S4E_SCRIP/scrip" --run "$src" < /dev/null > m3.out 2> m3.ld )
               hit=0; grep libscrip_xwin "$d/m3.ld" > /dev/null && hit=1
               if [ "${S4E_MODE4:-0}" = 1 ]; then
                   ( cd "$d" && timeout -k 5 300 "$S4E_SCRIP/scrip" --compile "$src" --out=m4.bin < /dev/null > /dev/null 2>&1 && LD_DEBUG=libs timeout -k 5 120 python3 "$HERE/util_screen_run.py" --out screen.dump -- ./m4.bin < /dev/null > m4.out 2> m4.ld )
                   grep libscrip_xwin "$d/m4.ld" > /dev/null 2>&1 || hit=$((hit + 10))
               fi
               rm -rf "${d:?}"
               if [ "$tok" = noload ]; then [ "$hit" = 0 ] || [ "$hit" = 10 ] && note "$tok" green || note "$tok" red
               else [ "$hit" = 1 ] && note "$tok" green || note "$tok" red; fi ;;
        cmd=xwload)  # W3: a C program linked against out/libscrip_rt.so finds the window object beside the runtime file through rt_xwin_sym
               d="$(mktemp -d "${TMPDIR:-/tmp}/s4e_icon_xwin_cl.XXXXXX")"
               if gcc -O0 -w -o "$d/xwin_load" "$FIX/probe/xwin_load.c" -L"$S4E_SCRIP/out" -Wl,-rpath,"$S4E_SCRIP/out" -lscrip_rt -lm -lpthread > "$d/cc.log" 2>&1; then
                   timeout -k 5 30 "$d/xwin_load" < /dev/null >> "$log" 2>&1 && note "$tok" green || note "$tok" red
               else echo "    the loader probe does not link today: $(grep -m1 -o 'undefined reference to [^ ]*' "$d/cc.log")" >> "$log"; note "$tok" red; fi
               rm -rf "${d:?}" ;;
        kind=*) k="${tok#kind=}"; awk -F'\t' -v n="${k%%:*}" -v c="${k#*:}" '$1 == n && $3 == c {f = 1} END {exit !f}' "$HERE/gc_kind_witnesses.tsv" && note "$tok" green || note "$tok" red ;;
        cmd=rtx) bash "$HERE/test_rtx_unit.sh" >> "$log" 2>&1 && note "$tok" green || note "$tok" red ;;
        cmd=screen) python3 "$HERE/util_screen_run.py" --probe >> "$log" 2>&1; r=$?; [ "$r" = 0 ] && note "$tok" green || { [ "$r" = 2 ] && note "$tok" refuse || note "$tok" red; } ;;
        cmd=events)  # W7: the screen road takes an events script (the cqo's --events FILE); refused today, so red, never a refusal of this harness
               d="$(mktemp -d "${TMPDIR:-/tmp}/s4e_icon_xwin_ev.XXXXXX")"; printf 'wait\n' > "$d/x.events"
               ( cd "$d" && timeout -k 5 120 python3 "$HERE/util_screen_run.py" --events x.events --out screen.dump -- /bin/true < /dev/null >> "$log" 2>&1 ); r=$?
               rm -rf "${d:?}"; [ "$r" = 0 ] && note "$tok" green || note "$tok" red ;;
        cmd=screvents) python3 "$HERE/corpus_suite_harness.py" --probe-screen-events >> "$log" 2>&1 && note "$tok" green || note "$tok" red ;;
        cmd=smoke) bash "$HERE/test_smoke_icon.sh" >> "$log" 2>&1 && note "$tok" green || note "$tok" red ;;
        cmd=gen) python3 "$HERE/util_gen_icon_xwin_device.py" --check /home/resources/progress/ICON-XWIN-TREE-W1 --syntax --link-census >> "$log" 2>&1; r=$?; [ "$r" = 0 ] && note "$tok" green || note "$tok" red ;;
        *) echo "    unknown probe token $tok" >> "$log"; note "$tok" refuse ;;
    esac
done
tail -60 "$log"; rm -f "$log"
case "$verdict" in 0) v=GREEN ;; 1) v=RED ;; *) v=REFUSED ;; esac
echo "VERDICT: STEP $step $slug: -> $v"
exit "$verdict"
