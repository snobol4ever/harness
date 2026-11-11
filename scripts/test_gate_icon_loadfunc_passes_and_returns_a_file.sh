#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icon_loadfunc_passes_and_returns_a_file.sh -- A LOADED C FUNCTION RECEIVES A FILE AS A FILE AND CAN RETURN ONE (row
# icon-loadfunc-a-loaded-c-function-receives-a-file-as-a-file-and-can-return-one, CIO-88; staged by the grader 2026-11-11 in the second re-cut,
# CIO-126: the row's DONE-WHEN named this file and it was not on disk). MEASURED by the coo 2026-11-10 on SCRIP 08c716738
# (/home/resources/progress/ICON-LOADFUNC-READING.tsv): fpoll(&input, 10) ends in error 105, file expected, offending value &null, where iconx
# prints file. READ in src/runtime/icn_extfn.c: icn_extfn_marshal_in has no arm for a file (DT_FH), so a file reaches the C side as null;
# icn_extfn_marshal_out has no arm for a file result; alcfile reports itself unprovided.
#
# THE WITNESS: the gate builds its own plug-in of two C functions against the oracle tree's icall.h (file_number(f): 105 unless f is a file,
# else the integer fileno of its stream; open_null(): a file newly opened on /dev/null for reading, returned by RetFile) and an Icon program
# that loads both and writes file_number(&input), type(open_null()), and one line read from the returned file (the read fails: "failed").
# It is run by the oracle (icont and iconx, live) and by SCRIP in mode 3 and in mode 4, standard input /dev/null.
# EXIT: 0 the three outputs are identical; 1 they are not (the first lines that differ are printed); 2 REFUSED (no scrip, no cc, no icall.h,
# no oracle, or the oracle did not answer the witness as this gate expects).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=test_gate_icon_loadfunc_passes_and_returns_a_file
S="$HERE/../../SCRIP/scrip"; O="$HERE/../../SCRIP/out"
[ -x "$S" ] || { echo "REFUSE(2) [$G]: scrip is not built"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null
IC="$(icont_bin 2>/dev/null)"; [ -n "$IC" ] && [ -x "$IC" ] || { echo "REFUSE(2) [$G]: no Icon oracle (icont_bin)"; exit 2; }
ICALL="${ICALL_H:-/home/resources/icon-master/ipl/cfuncs/icall.h}"
[ -r "$ICALL" ] || { echo "REFUSE(2) [$G]: $ICALL is unreadable: the C side's form of a file is the gate's subject"; exit 2; }
command -v cc > /dev/null 2>&1 || { echo "REFUSE(2) [$G]: no cc: the gate compiles its own plug-in"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/loadfunc_file_gate.XXXXXX")" || { echo "REFUSE(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
cat > "$T/plug.c" <<'CEOF'
#include <stdio.h>
#include "icall.h"
int file_number(int argc, descriptor *argv) { if (argc < 1) Error(105); if (IconType(argv[1]) != 'f') ArgError(1, 105); RetInteger(fileno(FileVal(argv[1]))); }
int open_null(int argc, descriptor *argv) { FILE *f = fopen("/dev/null", "r"); (void)argc; if (!f) Fail; RetFile(f, Fs_Read, "null"); }
CEOF
cc -shared -fPIC -I"$(dirname "$ICALL")" -o "$T/plug.so" "$T/plug.c" 2> "$T/cc.err" || { echo "REFUSE(2) [$G]: the plug-in did not build: $(head -2 "$T/cc.err" | tr '\n' ' ')"; exit 2; }
cat > "$T/w.icn" <<WITNESS
procedure main()
   local fnum, onull, f;
   fnum := loadfunc("$T/plug.so", "file_number");
   onull := loadfunc("$T/plug.so", "open_null");
   write("input is stream ", fnum(&input));
   f := onull();
   write("returned a ", type(f));
   write("a line of it: ", read(f) | "failed");
   write("it is stream ", if fnum(f) > 2 then "above 2" else "not above 2");
   write("end");
end
WITNESS
( cd "$T" && timeout -k 5 60 "$IC" -s -o w.ox w.icn > icont.txt 2>&1 < /dev/null && timeout -k 5 60 ./w.ox > oracle.txt 2>&1 < /dev/null ) \
    || { echo "REFUSE(2) [$G]: the oracle did not run the witness: $(cat "$T/icont.txt" "$T/oracle.txt" 2>/dev/null | head -2 | tr '\n' ' ')"; exit 2; }
want="input is stream 0
returned a file
a line of it: failed
it is stream above 2
end"
[ "$(cat "$T/oracle.txt")" = "$want" ] || { echo "REFUSE(2) [$G]: the oracle's answer is not the one this gate measures: $(head -5 "$T/oracle.txt" | tr '\n' '|')"; exit 2; }
( cd "$T" && timeout -k 5 60 "$S" w.icn < /dev/null > m3.txt 2>&1 )
( cd "$T" && timeout -k 5 120 "$S" --compile --out=w.s w.icn < /dev/null > /dev/null 2>&1 ) && cc -no-pie -o "$T/w.x" "$T/w.s" -Wl,-rpath,"$O" -L"$O" -lscrip_rt -lm -lpthread 2> /dev/null \
    || { echo "REFUSE(2) [$G]: mode 4 did not build the witness"; exit 2; }
( cd "$T" && timeout -k 5 60 ./w.x < /dev/null > m4.txt 2>&1 )
red=0
cmp -s "$T/oracle.txt" "$T/m3.txt" || { echo "  mode 3 differs from iconx; it reads: $(head -4 "$T/m3.txt" | tr '\n' '|' | cut -c1-300)"; red=1; }
cmp -s "$T/oracle.txt" "$T/m4.txt" || { echo "  mode 4 differs from iconx; it reads: $(head -4 "$T/m4.txt" | tr '\n' '|' | cut -c1-300)"; red=1; }
echo "ICON_LOADFUNC_FILE_BOARD lines=$(wc -l < "$T/oracle.txt") m3=$(cmp -s "$T/oracle.txt" "$T/m3.txt" && echo same || echo differs) m4=$(cmp -s "$T/oracle.txt" "$T/m4.txt" && echo same || echo differs) (tree $(git -C "$HERE/../../SCRIP" rev-parse --short HEAD 2>/dev/null))"
[ "$red" = 0 ] && { echo "GATE OK [$G]: a loaded C function receives a file as a file and returns one, as iconx, in mode 3 and mode 4"; exit 0; }
echo "GATE FAIL [$G]: a file does not cross into or out of a loaded C function as it does under iconx"; exit 1
