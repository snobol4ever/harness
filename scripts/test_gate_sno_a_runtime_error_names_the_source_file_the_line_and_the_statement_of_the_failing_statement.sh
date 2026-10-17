#!/usr/bin/env bash
# test_gate_sno_a_runtime_error_names_the_source_file_the_line_and_the_statement_of_the_failing_statement.sh
#
# THE ROW (snobol4-runtime-errors-do-not-name-the-source-file-or-line, parts (a) and (b)): a SCRIP runtime error named no source file, no line and statement 0 ('(0) : ERROR 248 ... in
# statement 0'); sbl -bf names 'inc.inc(3) : ERROR 014', then 'in file inc.inc', 'in line 3', 'in statement 4'. Part (c) -- the report on STDOUT with the statistics block -- is the
# termination-report row's and stays out. SCRIP's one voice prints 'scrip: error N: text' then 'at FILE:LINE; statement S' on stderr; this gate reads FILE, LINE and S out of sbl's
# stdout at run time and requires SCRIP's to equal them, from the main file, from an -INCLUDE'd file and from a function DEFINEd in an -INCLUDE'd file, in both modes.
# The expected location is cut from sbl -bf at run time and pinned: a program sbl no longer reports as pinned is a REFUSAL, never a green.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent -- the pinned locations cannot be confirmed"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
printf '        Y = 1\n        OUTPUT = "start"\n        X = Y / 0\n        OUTPUT = "after"\nEND\n' > "$D/main.sno"
printf '        Y = 1\n        OUTPUT = "in inc"\n        X = Y / 0\n        OUTPUT = "after in inc"\n' > "$D/inc.inc"
printf '        OUTPUT = "driver start"\n-INCLUDE "inc.inc"\n        OUTPUT = "driver end"\nEND\n' > "$D/incl.sno"
printf '        DEFINE("BAD()")  :(B_END)\nBAD     Y = 1\n        X = Y / 0   :(RETURN)\nB_END\n' > "$D/fn.inc"
printf '        OUTPUT = "driver start"\n-INCLUDE "fn.inc"\n        BAD()\n        OUTPUT = "driver end"\nEND\n' > "$D/fncall.sno"
printf 'main.sno 3 3\ninc.inc 3 4\nfn.inc 3 4\n' > "$D/pins"
loc_of() { awk '/^in file/{f=$3} /^in line/{l=$3} /^in statement/{s=$3} END{print f, l, s}' ; }
for p in main incl fncall; do
    ( cd "$D" && timeout -k 5 10 "$SBL" -bf $p.sno < /dev/null 2>/dev/null | loc_of > $p.sbl )
done
[ "$(cat "$D/main.sbl")" = "main.sno 3 3" ] || refuse "sbl -bf locates main as [$(cat "$D/main.sbl")], pinned [main.sno 3 3]"
[ "$(cat "$D/incl.sbl")" = "inc.inc 3 4" ] || refuse "sbl -bf locates incl as [$(cat "$D/incl.sbl")], pinned [inc.inc 3 4]"
[ "$(cat "$D/fncall.sbl")" = "fn.inc 3 4" ] || refuse "sbl -bf locates fncall as [$(cat "$D/fncall.sbl")], pinned [fn.inc 3 4]"
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
scrip_loc() { sed -n 's/^  at \([^:]*\):\([0-9]*\); statement \([0-9]*\).*$/\1 \2 \3/p' | head -1; }
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
for p in main incl fncall; do
    ( cd "$D" && timeout -k 5 30 "$B/scrip" $p.sno < /dev/null 2>&1 >/dev/null | scrip_loc > $p.m3 )
    ( cd "$D" && m4bin $p && timeout -k 5 30 ./$p.bin < /dev/null 2>&1 >/dev/null | scrip_loc > $p.m4 )
    for m in m3 m4; do
        if [ "$(cat "$D/$p.$m")" = "$(cat "$D/$p.sbl")" ]; then arm "$p $m ($(cat "$D/$p.sbl"))" ok
        else arm "$p $m" "SCRIP locates [$(cat "$D/$p.$m")] sbl [$(cat "$D/$p.sbl")]"; fi
    done
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): a runtime error names the source file, the line and the statement number sbl names, from the main file and from -INCLUDE'd files -- both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
