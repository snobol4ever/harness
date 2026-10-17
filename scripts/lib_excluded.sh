#!/usr/bin/env bash
# lib_excluded.sh -- THE ONE EXCLUDED.tsv READER, sourced by lib_inventory.sh and by a runner that needs only the reader (the coo
# 2026-10-14: raku_roast_scoreboard.sh reads Roast's EXCLUDED.tsv, CEO-1696, and sourcing the whole inventory body made
# test_gate_package_runners_print_the_inventory.sh rightly ask it for an inventory stanza Roast has no shipped-file population for).
# Moved here whole from lib_inventory.sh, unchanged; lib_inventory.sh sources it, so every caller reads through the same two functions.
declare -F inventory_refuse >/dev/null 2>&1 || inventory_refuse() { echo "⛔ INVENTORY REFUSES(2): $*" >&2; return 2; }
# ⛔⭐ EXCLUDED.tsv -- THE PROGRAMS OF A PACKAGE THAT ARE NOT IN THE SPITBOL DIALECT, OUT OF THE PUBLISHED DENOMINATOR (Lon
# 2026-09-26, in-chat to the ceo, verbatim: "The task is to identify which of the test programs found in the original package are
# in the SPITBOL dialect. We want to exclude from the denominator all that are not SPITBOL dialect. We want to show this number of
# EXCLUDED tests in the test-suite grid." and the test, verbatim: "So the way to tell if a program is SPITBOL dialect is two-fold,
# 1st is rejected by SPITBOL, and 2nd why it is rejected is a CSNOBOL4 feature not supported. Then if these two are true it is NOT
# SPITBOL dialect."; ceo CEO-1286). One row per program: name<TAB>NOT_SPITBOL_DIALECT<TAB>the feature, the oracle's refusal and
# CSNOBOL4's verdict. An excluded program is STILL SHIPPED and still sits in its UNGRADABLE bucket (the oracle refuses it), so the
# five buckets still sum to shipped; the line gains excluded=N and denominator=shipped-N, and the runner publishes PASS over
# denominator with EXCLUDED=N named (util_score_row.py --excluded, SUITES.tsv column today_excluded). A program the oracle refuses
# for ANY OTHER cause stays in the denominator as debt (CEO-749 unchanged for it). CEO-749's shape and this one differ in exactly one
# subtraction, and the sidecar is the whole of the difference.
# ⭐ AND THE GRAPHICS PROGRAMS OF THE ICON PROGRAM LIBRARY (Lon 2026-09-27, in-chat to hq_icon, verbatim: "Place the graphics programs
# on the exclude list."): class NEEDS_GRAPHICS_FACILITY, a unit whose own source or link closure calls a graphics built-in -- the 48
# names a graphics-built iconx 9.5.25a's function() lists beyond the installed NoGraphics oracle's -- or opens a window. SCRIP has no
# Icon graphics facility yet and the oracle has none, so neither side can run them; they leave the denominator named, and a program
# that merely links a graphics library without reaching it stays in as fixture work.
# ⭐ AND THE TERMINAL AND NETWORK PROGRAMS (Lon 2026-10-03, in-chat to hq_icon, verbatim: "You can have terminal and network test programs marked as excluded."):
# class NEEDS_TERMINAL, a unit whose function is to drive an interactive terminal (cursor addressing, termcap, ANSI control, single-key reads, /dev/tty), and class
# NEEDS_NETWORK, a unit whose function is to talk to a network peer (HTTP); a graded run has neither a terminal nor a peer, so they leave the denominator named,
# exactly as the graphics units do. Each row's evidence is the unit's own purpose and the oracle's verdict, never a failure of ours.
# ⭐ AND THE UNITS THAT REACH LOADFUNC (Lon 2026-10-03 13:0x CDT, in-chat to the ceo, verbatim: "Move the loadfunc feature until later, so exclude those tests."; CEO-1470):
# class NEEDS_LOADFUNC, a unit whose own run loads a C function through loadfunc -- measured, never read, by the dynamic loader's trace of the oracle's run opening libcfunc.so
# (the units that link cfunc: vhttp, htget, and weblinks through vhttp). A unit whose source mentions loadfunc but whose run never reaches the call stays in the denominator.
# ⭐ AND THE PROGRAMS LON DEFERRED PAST THE ANNOUNCEMENT (Lon 2026-09-27 19:3x CDT, in-chat to the ceo, verbatim: "The EXIT() feaure to
# save/resume executables will be done but after the announcement"; ceo CEO-1345): class DEFERRED-AFTER-ANNOUNCEMENT-LON-2026-09-27, a
# program the oracle RUNS but that needs a feature Lon scheduled after the announcement (EXIT(3,file)'s resumable load module). The
# runner still grades it and names its verdicts; it leaves pass, fail, rc and the denominator, and returns to them the day the row lands.
# ⭐ AND THE CLP(FD) PROGRAMS (Lon, CEO-579, verbatim: "Do not count the FD as failures for us."; ceo CEO-1593, on hq_prolog's puzzle package: the
# CLP(FD) programs go INTO the container with their swipl refs and are named in EXCLUDED.tsv under class OUTSIDE_CLPFD, "that class is Lon's by name"):
# class OUTSIDE_CLPFD, a program whose load closure reaches library(clpfd); it is graded and its verdicts named, and it leaves pass, fail and the
# denominator until the FD rows of ARCH-PROLOG-CLPFD.md close. Admitted here 2026-10-10 by the coo: hq_pascal measured inventory_line refusing
# puzzles/EXCLUDED.tsv on every row since the package landed (corpus 0a2d4118d), because the vocabulary did not carry the class the ceo ruled.
# ⭐ AND THE PROGRAMS NO ORACLE ANSWERS (Lon 2026-10-11 16:0x CDT, in-chat to the ceo, verbatim: "Exclude any program in which we have no way to get
# output from an oracle, or in which we do not know the answer."; ceo CEO-1696, RULES.md FACT RULE A PROGRAM WITH NO ORACLE ANSWER IS EXCLUDED, NEVER
# DEBT): class NO_ORACLE_ANSWER, a program the oracle gives no output for (it refuses, crashes, aborts, hangs past its declared time, or cannot run it at
# all) or whose answer is not known (no ref was ever cut, or the output depends on a clock, a seed or the environment). The package's UNGRADABLE.tsv row
# stays as the oracle's measurement -- the inventory's ungradable bucket still counts the program, so the buckets sum to shipped -- and its EXCLUDED.tsv
# row of this class carries that measurement verbatim and takes the program out of the denominator, shown as Excl.
# inventory_excluded_names [<pkgdir>] -- echo column 1 of <pkgdir>/EXCLUDED.tsv (default $INV_DIR); nothing when the file is absent;
# rc 2 on a row that is not name<TAB>CLASS<TAB>evidence with CLASS one of NOT_SPITBOL_DIALECT (Lon's SPITBOL test, one outcome),
# NEEDS_GRAPHICS_FACILITY (Lon's graphics word), NEEDS_TERMINAL, NEEDS_NETWORK or NEEDS_LOADFUNC (Lon's words below), DEFERRED-AFTER-ANNOUNCEMENT-LON-2026-09-27
# (Lon's EXIT() word, CEO-1345), OUTSIDE_CLPFD (CEO-1593), NO_ORACLE_ANSWER (CEO-1696) or SCRIP_EXCEEDS_ORACLE (CEO-1710: the
# oracle's answer comes from a fixed limit SCRIP grows past, or from an oracle defect its own upstream has fixed; Lon 2026-10-14).
inventory_excluded_names() {
    local d="${1:-${INV_DIR:-}}" f
    f="$d/EXCLUDED.tsv"
    [ -f "$f" ] || return 0
    awk -F'\t' '
        $0 ~ /^#/ || NF == 0 { next }
        NF < 3 || ($2 != "NOT_SPITBOL_DIALECT" && $2 != "NEEDS_GRAPHICS_FACILITY" && $2 != "NEEDS_TERMINAL" && $2 != "NEEDS_NETWORK" && $2 != "NEEDS_LOADFUNC" && $2 != "DEFERRED-AFTER-ANNOUNCEMENT-LON-2026-09-27" && $2 != "OUTSIDE_CLPFD" && $2 != "NO_ORACLE_ANSWER" && $2 != "SCRIP_EXCEEDS_ORACLE") || length($3) < 60 { bad = bad " " $1 "(" NF " fields, class " $2 ")"; next }
        { print $1 }
        END { if (bad != "") { print "MALFORMED:" bad > "/dev/stderr"; exit 2 } }' "$f" || { inventory_refuse "$f carries a malformed row (name<TAB>NOT_SPITBOL_DIALECT, NEEDS_GRAPHICS_FACILITY, NEEDS_TERMINAL, NEEDS_NETWORK, NEEDS_LOADFUNC, DEFERRED-AFTER-ANNOUNCEMENT-LON-2026-09-27, OUTSIDE_CLPFD, NO_ORACLE_ANSWER or SCRIP_EXCEEDS_ORACLE<TAB>evidence of 60+ chars naming the feature and the oracle's verdict)"; return 2; }
}
# inventory_is_excluded <pkgdir> <name> -- 0 when EXCLUDED.tsv names <name> (bare or package-relative), 1 otherwise.
inventory_is_excluded() {
    local d="${1:-}" rel="${2:-}" n
    for n in $(inventory_excluded_names "$d"); do [ "$n" = "$rel" ] && return 0; [ "$n" = "${rel##*/}" ] && return 0; done
    return 1
}
