#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_snobol4_name_as_pattern_matches_sbl.sh -- A NAME STANDING ALONE AS A PATTERN MATCHES THE STRING OF ITS VARIABLE'S NAME, AS SPITBOL DOES, IN BOTH MODES
# (row snobol4-a-name-used-as-a-pattern-matches-its-variables-name-in-spitbol-where-scrip-fails; found by the ceo's millions-run, CEO-1450). Every witness is
# run by the correctness oracle (sbl -bf) and by SCRIP's mode 3 and mode 4 and the gate compares standard output and exit code. WITNESSES: the name literal as
# the pattern of a statement, a variable holding a NAME as the pattern, the same two inside EVAL (the runtime road), a name that does not occur in the subject
# (the match fails), a name followed by a literal, and a name as one arm of an alternation.
# FAIL_ONCE (recorded 2026-10-14, this tree with the pattern_match.c change stashed): 6 of 6 runs RED -- the statement, the variable and the EVAL witnesses read the failure branch where sbl matches; with the cure 6 of 6 agree.
# EXIT 0 every witness in both modes; 1 a red (named); 2 REFUSED (oracle or build missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
W="$(mktemp -d)" || exit 2; trap 'rm -rf "$W"' EXIT
cd "$W" || exit 2
cat > name_stmt.sno <<'SNO'
        X = 'abc' ? .b
        OUTPUT = 'x=' X
        'abc' ? .b                      :F(NO)
        OUTPUT = 'yes'
NO      'xyz' ? .b                      :S(BAD)
        OUTPUT = 'no match'             :(DONE)
BAD     OUTPUT = 'wrong'
DONE
END
SNO
cat > name_var.sno <<'SNO'
        P = .b
        'abc' ? P                       :F(NO)
        OUTPUT = 'yes'
NO      X = 'abc' ? P
        OUTPUT = 'x=' X
        'abc' ? (.b 'c')                :F(NO2)
        OUTPUT = 'bc'
NO2     'abc' ? (.zz | .c)              :F(NO3)
        OUTPUT = 'alt'
NO3
END
SNO
cat > name_eval.sno <<'SNO'
        P = .b
        X = 'q'
        X = EVAL("'abc' ? .b")
        OUTPUT = 'a:' X
        X = 'q'
        X = EVAL("'abc' ? P")
        OUTPUT = 'b:' X
        X = 'q'
        X = EVAL("'abc' ? (.b)")
        OUTPUT = 'c:' X
        X = 'q'
        X = EVAL("'xyz' ? .b")
        OUTPUT = 'd:' X
        X = EVAL("'(matched [things])' ? .i")
        OUTPUT = 'e:' X
        X = EVAL("'abc' ? (.b 'c')")
        OUTPUT = 'f:' X
END
SNO
rc=0; n=0
for src in name_stmt name_var name_eval; do
    timeout -k 5 60 "$SBL" -bf $src.sno < /dev/null 2>/dev/null | grep -v '^x86-64 ' > $src.o; orc=${PIPESTATUS[0]}
    [ -s $src.o ] || { echo "REFUSED(2): sbl printed nothing for $src (rc $orc)"; exit 2; }
    echo "rc=$orc" >> $src.o
    timeout -k 5 60 "$ROOT/scrip" $src.sno < /dev/null 2>/dev/null | grep -v '^x86-64 ' > $src.m3; echo "rc=${PIPESTATUS[0]}" >> $src.m3
    timeout -k 5 60 "$ROOT/scrip" --compile -o $src.s $src.sno < /dev/null > /dev/null 2>&1 \
        && gcc -m64 -no-pie $src.s -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o $src.bin > /dev/null 2>&1 \
        && { timeout -k 5 60 ./$src.bin < /dev/null 2>/dev/null | grep -v '^x86-64 ' > $src.m4; echo "rc=${PIPESTATUS[0]}" >> $src.m4; } || echo "no-binary" > $src.m4
    for m in m3 m4; do
        n=$((n+1))
        if cmp -s $src.o $src.$m; then continue; fi
        echo "RED $src $m: sbl [$(tr '\n' '|' < $src.o | cut -c1-80)] scrip [$(tr '\n' '|' < $src.$m | cut -c1-80)]"
        rc=1
    done
done
[ $rc = 0 ] && echo "PASS: $n runs (3 witnesses x 2 modes) agree with sbl on output and exit code"
exit $rc
