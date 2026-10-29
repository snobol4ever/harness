#!/bin/bash
# ⭐ PER-ENTRY GRADER FOR NAMED raku RUNGS ENTRIES -- the development aid, never a board (hq_T 2026-09-13,
# row raku-every-xfail-fixed-as-a-faulty-test-or-cured-as-a-defect). ONE RUNNER, ONE BOARD binds: every rung suite
# and package board is the coo's. This is the other thing -- `corpus_suite_harness.py on one entry`, the grading
# the contract explicitly leaves to each seat -- lifted to a NAMED SET so a class row's DONE-WHEN is one line
# instead of a twenty-line shell loop copied once per row. It writes no SCORE.md cell and prints no board line.
# ⛔ IT REFUSES rc=2 RATHER THAN PRINTING THE SUCCESS SHAPE when it cannot measure: no entry named, an entry the
# rungs does not carry, or a build that is not there. A runner that graded zero witnesses and exited 0 is the
# `make test` false-green trap wearing a different hat (CLAUDE.md § Testing).
# ⛔ rc CONTRACT: the expected rc comes from ALL.wantrc when the entry is declared there and is 0 otherwise --
# a die test whose stdout matches is a PASS, and grading it on stdout alone would score four xfails XPASS that
# are not (measured on this row: simple_program_10, say_die_1, sub_say_12, sub_say_6).
# Usage: util_raku_entry_grade.sh <entry> [entry ...]        rc: 0 all green · 1 a red · 2 could not measure
set -u
here=$(cd "$(dirname "$0")" && pwd); root=$(cd "$here/../../SCRIP" && pwd); corpus="$root/../corpus"
M="$corpus/tests/raku"
[ $# -ge 1 ] || { echo "⛔ REFUSE(2) [util_raku_entry_grade]: no entry named -- a grader with an empty population cannot report a verdict" >&2; exit 2; }
[ -x "$root/scrip" ] || { echo "⛔ REFUSE(2) [util_raku_entry_grade]: no $root/scrip -- run make first" >&2; exit 2; }
[ -f "$M/ALL.raku" ] && [ -f "$M/ALL.ref" ] || { echo "⛔ REFUSE(2) [util_raku_entry_grade]: no raku rungs at $M" >&2; exit 2; }
graded=0; green=0; red=0
for n in "$@"; do
    d=$(mktemp -d) || exit 2
    if ! python3 "$here/corpus_suite_harness.py" extract "$M/ALL.raku" "$M/ALL.ref" "$n" "$d/w.raku" --out-ref "$d/w.ref" >/dev/null 2>&1; then
        echo "⛔ REFUSE(2) [util_raku_entry_grade]: the rungs carries no entry '$n' -- a name that cannot be resolved is not a red, it is an unmeasurable" >&2
        rm -rf "$d"; exit 2
    fi
    want_rc=0
    if [ -f "$M/ALL.wantrc" ]; then w=$(awk -F'\t' -v n="$n" '$1==n{print $2}' "$M/ALL.wantrc" | head -1); [ -n "$w" ] && want_rc="$w"; fi
    stdin_f=/dev/null; [ -f "$d/w.in" ] && stdin_f="$d/w.in"
    out3=$(cd "$d" && timeout -k 5 30 "$root/scrip" w.raku < "$stdin_f" 2>/dev/null); rc3=$?
    bad=""
    [ "$rc3" = "$want_rc" ] || bad="$bad m3-rc=$rc3(want $want_rc)"
    [ "$out3" = "$(cat "$d/w.ref")" ] || bad="$bad m3-stdout"
    if (cd "$d" && timeout -k 5 60 "$root/scrip" --compile --out=w.s w.raku >/dev/null 2>&1) \
       && (cd "$d" && gcc -no-pie w.s -o w.exe -L"$root/out" -lscrip_rt -lm -lpthread >/dev/null 2>&1); then
        out4=$(cd "$d" && LD_LIBRARY_PATH="$root/out" timeout -k 5 30 ./w.exe < "$stdin_f" 2>/dev/null); rc4=$?
        [ "$rc4" = "$want_rc" ] || bad="$bad m4-rc=$rc4(want $want_rc)"
        [ "$out4" = "$(cat "$d/w.ref")" ] || bad="$bad m4-stdout"
    else
        bad="$bad m4-build"
    fi
    graded=$((graded + 1))
    if [ -n "$bad" ]; then red=$((red + 1)); printf '  RED   %-30s%s\n' "$n" "$bad"; else green=$((green + 1)); fi
    rm -rf "$d"
done
[ "$graded" -gt 0 ] || { echo "⛔ REFUSE(2) [util_raku_entry_grade]: graded zero witnesses" >&2; exit 2; }
echo "RAKU_ENTRIES graded=$graded green=$green red=$red (both modes, rc from ALL.wantrc)"
[ "$red" -eq 0 ]
