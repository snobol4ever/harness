#!/usr/bin/env bash
# test_gate_icn_link_takes_any_number_of_files.sh -- hq_icon, 2026-09-24, MODE DECTET.
#
# WHAT WAS THERE. icon_driver.c's icn_resolve_links held the names of the files already linked in a local
# `const char * loaded[64]` and refused the 65th with "icon: link: more than 64 linked files", rc 1. Icon has no such
# limit: a legal program that links 70 files is refused by SCRIP and run by Arizona iconx. The fixed-caps census read the
# table as a loud guard (coo, SCRIP ee1654d5c) -- class C by ARCH-DYNAMIC-STORAGE section 2, a population a program grows.
#
# WHAT IS HERE. loaded is a vector in the compile-time arena, doubled through ct_grow (realloc's contract) from 16, dropped
# at the end of the walk; the refusal is gone. BASELINE_FUNCTION_SCOPE falls 523 -> 522 in the same landing.
#
# ARM. ARCH-DYNAMIC-STORAGE section 3 item 4: a witness that EXCEEDS THE OLD CAP and reads the ORACLE's answer. A main
# program links 70 one-procedure files (l1 .. l70, each `return i`) and writes the sum; icont/iconx 9.5.25a must run it
# (a witness the oracle cannot run refuses the gate), and SCRIP must print iconx's answer with iconx's exit status in both
# media. RUN FIRST THEN WIRED (CEO-381): RED on 24dc6f75a -- "more than 64 linked files (at l64)", rc 1, both media.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle is missing"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
N=70
for i in $(seq 1 $N); do printf 'procedure p%d()\n   return %d;\nend\n' "$i" "$i" > "$T/l$i.icn"; done
{ printf 'link '; for i in $(seq 1 $N); do printf 'l%d' "$i"; [ "$i" -lt "$N" ] && printf ', '; done
  printf '\nprocedure main()\n   local s;\n   s := 0;\n'; for i in $(seq 1 $N); do printf '   s +:= p%d();\n' "$i"; done; printf '   write(s);\nend\n'; } > "$T/main.icn"
( cd "$T" && for i in $(seq 1 $N); do "$ICONT" -s -c "l$i.icn" || exit 1; done && "$ICONT" -s -o main.x main.icn ) >/dev/null 2>&1 \
  || { echo "⛔ GATE REFUSE(2) [$G]: icont refuses the $N-file link witness"; exit 2; }
want="$( cd "$T" && ./main.x </dev/null 2>/dev/null )"; wrc=$?
[ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing"; exit 2; }
o3="$( cd "$T" && timeout -k 5 60 "$SCRIP" main.icn </dev/null 2>"$T/m3.err" )"; r3=$?
( cd "$T" && timeout -k 5 120 "$SCRIP" --compile -o main.s main.icn </dev/null >/dev/null 2>"$T/c4.err" && gcc -no-pie -o main.4 main.s -L"$ROOT/out" -lscrip_rt -lm -lstdc++ -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 )
o4="$( cd "$T" && timeout -k 5 60 ./main.4 </dev/null 2>/dev/null )"; r4=$?
echo "  HOLDS: an Icon program may link any number of files, as iconx allows -- no fixed table of linked names"
if [ "$o3" = "$want" ] && [ "$r3" = "$wrc" ] && [ "$o4" = "$want" ] && [ "$r4" = "$wrc" ]; then
  echo "  arm 1 PASS: a $N-file link prints iconx's $want (rc $wrc) in both media"; echo "✅ GATE PASS [$G]"; exit 0; fi
echo "  arm 1 FAIL: iconx [$want] rc=$wrc, m3 [$o3] rc=$r3 ($(head -1 "$T/m3.err")), m4 [$o4] rc=$r4 ($(head -1 "$T/c4.err"))"
echo "⛔ GATE FAIL [$G]"; exit 1
