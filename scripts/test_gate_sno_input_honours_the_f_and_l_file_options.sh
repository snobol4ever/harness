#!/usr/bin/env bash
# test_gate_sno_input_honours_the_f_and_l_file_options.sh
#
# SPITBOL'S RULE (measured with sbl -bf; ceo CEO-1419 ticket snobol4-the-f0-file-option-is-ignored-so-a-read-of-
# standard-input-never-fails, found by Lon's infinite_snobol4, whose first run filled 839 MB in four minutes):
# INPUT(.v, 5, '[-f0 ...]') associates v with channel 5 on file descriptor 0, so v reads standard input's lines and
# FAILS at end of file; '-l<n>' caps each line at n characters, keeping line boundaries. SCRIP ignored the
# association when no file name preceded the brackets: it rebound the INPUT variable itself, so v kept its null value
# and a read loop never ended. It also ignored -l.
# THE CURE (core.c _INPUT_ and _io_parse_opts): with a channel and -f<fd> and no file name, the variable is
# associated with that channel on fdopen(dup(fd)), as OUTPUT's empty-name branch already did for -f1. '-l<n>' rides
# the record length as -n, which both line readers apply as a cap and the raw reader (-r, rlen > 0) never sees.
# Expectations are cut from sbl -bf AT RUN TIME, both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- the expectations are cut from it at run time"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
printf 'alpha\nbetagamma\n' > "$D/in.txt"
cat > "$D/f0.sno" <<'SNO'
        INPUT(.EXPRIN, 5, '[-f0 -l1000000]')
        OUTPUT(.RESOUT, 6, '[-f1 -w]')
        N = 0
LOOP    LINE = EXPRIN                                   :F(DONE)
        N = N + 1
        RESOUT = N ' ' LINE
        GT(N, 5)                                        :S(DONE)F(LOOP)
DONE    OUTPUT = 'read ' N
END
SNO
cat > "$D/l3.sno" <<'SNO'
        INPUT(.X, 5, '[-f0 -l3]')
L       V = X                                           :F(D)
        OUTPUT = 'got [' V ']'                          :(L)
D       OUTPUT = 'eof'
END
SNO
cat > "$D/reassoc.sno" <<'SNO'
        &ERRLIMIT = 5
        INPUT(.X, 5, '[-f0]')
        OUTPUT = 'first ' X
        INPUT(.Y, 5, '[-f0]')                           :F(F)
        OUTPUT = 'reassoc ok ' Y                        :(E)
F       OUTPUT = 'reassoc fails ' &ERRTYPE
E       OUTPUT = 'end'
END
SNO
cat > "$D/inputl.sno" <<'SNO'
        INPUT(.INPUT, 5, '[-f0 -l4]')
L       V = INPUT                                       :F(D)
        OUTPUT = 'got [' V ']'                          :(L)
D       OUTPUT = 'eof'
END
SNO
ARMS="f0 l3 reassoc inputl"
for a in $ARMS; do (cd "$D" && timeout -k 5 20 "$SBL" -bf "$a.sno" < in.txt > "$a.sbl" 2>/dev/null); done
[ "$(tail -1 "$D/f0.sbl")" = "read 2" ] && grep -qx "got \[alp\]" "$D/l3.sbl" || refuse "the oracle no longer reads two lines through -f0 or caps at -l3 -- re-read sbl"
fails=0; arms=0
for a in $ARMS; do
    (cd "$D" && timeout -k 5 20 "$B/scrip" "$a.sno" < in.txt > "$a.m3" 2>/dev/null)
    "$B/scrip" --compile --out="$D/$a.s" "$D/$a.sno" </dev/null >/dev/null 2>&1 && gcc -no-pie -o "$D/$a.bin" "$D/$a.s" -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" 2>/dev/null || refuse "could not build the m4 arm of $a -- a toolchain failure, not a verdict"
    (cd "$D" && timeout -k 5 20 "./$a.bin" < in.txt > "$a.m4" 2>/dev/null)
    for m in m3 m4; do arms=$((arms+1))
        if cmp -s "$D/$a.sbl" "$D/$a.$m"; then echo "  ok    $m $a"
        else echo "  FAIL  $m $a"; diff "$D/$a.sbl" "$D/$a.$m" | head -6 | sed 's/^/          /'; fails=$((fails+1)); fi
    done
done
[ "$fails" -eq 0 ] || { echo "⛔ GATE FAILED: $fails of $arms arm(s) red -- core.c's _INPUT_ empty-name branch or _io_parse_opts' -l no longer does what sbl does"; exit 1; }
echo "✅ GATE OK: $arms arm(s) -- INPUT honours [-f<fd>] with no file name and [-l<n>] as a line cap, both modes"
exit 0
