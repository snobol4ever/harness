#!/usr/bin/env bash
# test_gate_sno_set_positions_a_file_like_sbl_in_every_whence_mode_and_tell_is_undefined_in_both.sh
#
# THE ROW (snobol4-set-and-tell-file-positioning-absent-blocks-ais-buildlib): minted on 2026-09-06 as 'neither TELL(unit) nor SET(unit,pos,whence) exists'. MEASURED 2026-10-15: SET exists and
# matches sbl -bf in every whence mode -- 0 absolute, 1 from the current position, 2 from the end, a negative offset, the returned position, a read after the move, the read that fails at the end, a
# negative absolute offset (position 0, no error), and ERROR 295 'set file does not exist' on a channel nothing is open on. TELL does not exist in sbl either (ERROR 022 'undefined function called',
# SNOBOL4+ only): the oracle gives BUILDLIB.SNO (which calls TELL) no answer, so under the oracle rule the program is EXCLUDED, never debt, and a TELL that returns a position would make SCRIP
# DIVERGE from the oracle on any program that probes for it. This gate pins both facts: SET's behaviour and TELL's undefined-function error, from sbl at run time, in both modes.
# Every expected output is cut from sbl -bf and pinned: a program sbl no longer answers as pinned is a REFUSAL, never a green.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent -- the pinned lines cannot be confirmed"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
printf 'hello world\nsecond line\nthird\n' > "$D/data.txt"
cat > "$D/a.sno" <<'SNO'
        &ERRLIMIT = 10
        INPUT(.IN, 5, 'data.txt')
        A = IN
        OUTPUT = 'A=' A
        R = SET(5, 0, 0)
        OUTPUT = 'rewind ret=[' R ']'
        A = IN
        OUTPUT = 'again A=' A
        R = SET(5, 6, 0)
        OUTPUT = 'abs6 ret=[' R ']'
        A = IN
        OUTPUT = 'abs6 A=' A
        R = SET(5, 0, 2)
        OUTPUT = 'end ret=[' R ']'
        A = IN                          :S(GOT)
        OUTPUT = 'at end: read failed'  :(NEXT)
GOT     OUTPUT = 'at end: got ' A
NEXT    R = SET(5, -5, 2)
        OUTPUT = 'end-5 ret=[' R ']'
        A = IN
        OUTPUT = 'end-5 A=' A
        R = SET(5, 3, 1)
        OUTPUT = 'cur+3 ret=[' R ']'
        R = SET(5, 0, 1)
        OUTPUT = 'cur+0 ret=[' R ']'
        R = SET(5, 2, 0)
        R = SET(5, 4, 1)
        OUTPUT = 'cur ret=[' R ']'
        A = IN
        OUTPUT = 'cur A=' A
        R = SET(5, -100, 0)
        OUTPUT = 'neg abs ret=[' R '] errtype=' &ERRTYPE
        R = SET(9, 0, 0)                :S(OK2)F(BAD2)
OK2     OUTPUT = 'unopened ok [' R ']' :(N3)
BAD2    OUTPUT = 'unopened FAILED errtype=' &ERRTYPE
N3      X = TELL(5)                     :S(OK3)F(BAD3)
OK3     OUTPUT = 'TELL ok [' X ']'      :(N4)
BAD3    OUTPUT = 'TELL FAILED errtype=' &ERRTYPE
N4      OUTPUT = 'done'
END
SNO
cat > "$D/a.want" <<'TXT'
A=hello world
rewind ret=[0]
again A=hello world
abs6 ret=[6]
abs6 A=world
end ret=[30]
at end: read failed
end-5 ret=[25]
end-5 A=hird
cur+3 ret=[30]
cur+0 ret=[30]
cur ret=[6]
cur A=world
neg abs ret=[0] errtype=0
unopened FAILED errtype=295
TELL FAILED errtype=22
done
TXT
( cd "$D" && timeout -k 5 10 "$SBL" -bf a.sno < /dev/null 2>/dev/null > a.sbl )
cmp -s "$D/a.want" "$D/a.sbl" || refuse "sbl -bf does not answer a as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/a.sbl")]"
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
( cd "$D" && timeout -k 5 30 "$B/scrip" a.sno < /dev/null > a.m3 2>/dev/null )
( cd "$D" && m4bin a && timeout -k 5 30 ./a.bin < /dev/null > a.m4 2>/dev/null )
for m in m3 m4; do
    if [ -f "$D/a.$m" ] && cmp -s "$D/a.want" "$D/a.$m"; then arm "a $m (SET in every whence mode, ERROR 295, TELL undefined 22)" ok
    else arm "a $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/a.$m")] want [$(tr '\n' '|' < "$D/a.want")]"; fi
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): SET positions a file like sbl in every whence mode and TELL is undefined (22) in both -- both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
