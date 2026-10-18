#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_snobol4_noexecute_matches_sbl.sh -- THE -NOEXECUTE CONTROL LINE COMPILES AND DOES NOT EXECUTE, AS SPITBOL DOES, IN BOTH MODES (row
# snobol4-the-noexecute-control-line-is-ignored-so-the-program-runs-where-spitbol-compiles-only). Every witness is run by the correctness oracle (sbl -bf)
# and by SCRIP's mode 3 and mode 4; the gate compares the standard output (the 'x86-64 ' banner lines dropped) and the exit code. The last -NOEXECUTE or
# -EXECUTE card of the program decides, wherever it stands; a -LIST listing is still printed.
# FAIL_ONCE (recorded 2026-10-14, this tree with the lexer and lowerer change stashed): 8 of 14 runs RED -- noex_first, noex_late, noex_last print and exit 0 where sbl prints nothing and exits 231, noex_list loses the exit code; with the cure 14 of 14 agree.
# EXIT 0 every witness in both modes; 1 a red (named); 2 REFUSED (oracle or build missing, or sbl does not answer as pinned).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
W="$(mktemp -d)" || exit 2; trap 'rm -rf "$W"' EXIT
cd "$W" || exit 2
printf -- "-NOEXECUTE\n        OUTPUT = 'error'\nEND\n" > noex_first.sno
printf -- "-NOEXECUTE\n-EXECUTE\n        OUTPUT = 'ran'\nEND\n" > noex_undone.sno
printf -- "        OUTPUT = 'ran'\n-NOEXECUTE\n        OUTPUT = 'ran2'\nEND\n" > noex_late.sno
printf -- "-EXECUTE\n        OUTPUT = 'ran'\n-NOEXECUTE\nEND\n" > noex_last.sno
printf -- "-LIST\n-NOEXECUTE\n        X = 1\n        OUTPUT = X\nEND\n" > noex_list.sno
printf -- "-NOLIST,NOEXECUTE\n        OUTPUT = 'error'\nEND\n" > noex_chain.sno
printf -- "        OUTPUT = 'ran'\nEND\n" > exec_default.sno
run_cut() { grep -v '^x86-64 ' | awk '{print} /^[0-9]+ +END( |$)/{exit}'; }
rc=0; n=0
for src in noex_first noex_undone noex_late noex_last noex_list noex_chain exec_default; do
    timeout -k 5 60 "$SBL" -bf $src.sno < /dev/null 2>/dev/null | run_cut > $src.o; orc=${PIPESTATUS[0]}
    [ -s $src.o ] || [ "$orc" -ne 0 ] || [ $src = exec_default ] || { echo "REFUSED(2): sbl does not answer as pinned for $src (rc $orc)"; exit 2; }
    echo "rc=$orc" >> $src.o
    timeout -k 5 60 "$ROOT/scrip" --stlimit $src.sno < /dev/null 2>/dev/null | run_cut > $src.m3; echo "rc=${PIPESTATUS[0]}" >> $src.m3
    timeout -k 5 60 "$ROOT/scrip" --compile -o $src.s $src.sno < /dev/null > /dev/null 2>&1 \
        && gcc -m64 -no-pie $src.s -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o $src.bin > /dev/null 2>&1 \
        && { timeout -k 5 60 ./$src.bin --stlimit < /dev/null 2>/dev/null | run_cut > $src.m4; echo "rc=${PIPESTATUS[0]}" >> $src.m4; } || echo "no-binary" > $src.m4
    for m in m3 m4; do
        n=$((n+1))
        if cmp -s $src.o $src.$m; then continue; fi
        echo "RED $src $m: sbl [$(tr '\n' '|' < $src.o | cut -c1-60)] scrip [$(tr '\n' '|' < $src.$m | cut -c1-60)]"
        rc=1
    done
done
[ $rc = 0 ] && echo "PASS: $n runs (7 witnesses x 2 modes) agree with sbl on output and exit code"
exit $rc
