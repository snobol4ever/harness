#!/usr/bin/env bash
# test_gate_sc_duplicate_label_is_refused_at_parse.sh -- a Snocone label defined twice anywhere in one program is refused at
# parse in BOTH media, as the SNOBOL4 parser refuses it and as sbl -bf refuses the transpile (ERROR 217, duplicate label).
#
# THE DEFECT (row snocone-a-label-defined-in-two-functions-is-error-217-in-the-transpile-where-scrip-compiles-it, the cto's
# finding on the SETEXIT row 95d1f4136, ceo CEO-1499): Snocone labels are SNOBOL4 labels -- global to the program -- yet a
# label defined in two function bodies compiled and ran (printed fg, rc 0, SCRIP 8475d7a65..1e16ef2d9), and a SETEXIT trap
# in the second function walked into the first function's chain. The parser kept no program-wide set of user labels;
# sc_append_label_node (snocone_parse.y) now keeps one (a cv_t on ScParseState, grown on demand) and raises
# "duplicate label 'x'" through sc_error, so neither medium gets code.
#
# THE ARMS:
#   1  the SNOBOL4 twin of the witness (the transpile of 8475d7a65, written by hand) is ERROR 217 to sbl -bf       -- the oracle's word; REFUSE if it moves
#   2  the same twin is refused by SCRIP's SNOBOL4 parser with 'duplicate label'                                   -- the standing control
#   3  m3: the Snocone witness is refused, rc != 0, stderr names 'duplicate label', stdout empty                   -- RED on base (printed fg)
#   4  m4: --compile refuses the witness, rc != 0, stderr names 'duplicate label'                                   -- RED on base
#   5  CONTROL: the same two labels in ONE function body each, distinct names (x in f, y in g), run and print fg in m3 and in m4
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
SBL=/home/resources/x64/bin/sbl
NAME=sc_duplicate_label_is_refused_at_parse
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -x "$SBL" ] || refuse "no oracle at $SBL -- cannot measure"
T=$(mktemp -d) || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cd "$T" || refuse "cannot enter $T"
printf 'function f() { goto x; x: f = \047f\047; return; }\nfunction g() { goto x; x: g = \047g\047; return; }\nOUTPUT = f() g();\n' > dup.sc
printf 'function f() { goto x; x: f = \047f\047; return; }\nfunction g() { goto y; y: g = \047g\047; return; }\nOUTPUT = f() g();\n' > ctl.sc
printf '        DEFINE(\047f()\047)   :(f_end)\nf                       :(x)\nx       f = \047f\047   :(RETURN)\nf_end   DEFINE(\047g()\047)   :(g_end)\ng                       :(x)\nx       g = \047g\047   :(RETURN)\ng_end   OUTPUT = f() g()\nEND\n' > twin.sno
RC=0
timeout -k 5 10 "$SBL" -bf twin.sno > twin.o 2>&1
if grep -q 'ERROR 217' twin.o; then echo "  arm 1 PASS (sbl -bf: the twin is ERROR 217, duplicate label)"; else refuse "the oracle's answer moved: sbl -bf no longer calls the twin a duplicate label: $(head -c 120 twin.o)"; fi
timeout -k 5 30 "$SCRIP" twin.sno < /dev/null > twin.m3 2> twin.e3; rc=$?
if [ $rc -ne 0 ] && grep -qi 'duplicate label' twin.e3; then echo "  arm 2 PASS (the SNOBOL4 parser refuses the twin, rc $rc)"; else echo "  arm 2 FAIL (control gone: SNOBOL4 twin rc $rc, stderr [$(head -c 120 twin.e3)])"; RC=1; fi
timeout -k 5 30 "$SCRIP" dup.sc < /dev/null > dup.m3 2> dup.e3; rc=$?
if [ $rc -ne 0 ] && grep -qi 'duplicate label' dup.e3 && [ ! -s dup.m3 ]; then echo "  arm 3 PASS (m3 refuses: rc $rc, $(grep -i -m1 'duplicate label' dup.e3 | cut -c1-80))"; else echo "  arm 3 FAIL (m3: rc $rc, stdout [$(tr '\n' '|' < dup.m3)], stderr [$(head -c 120 dup.e3)])"; RC=1; fi
timeout -k 5 60 "$SCRIP" --compile -o dup.s dup.sc < /dev/null > /dev/null 2> dup.e4; rc=$?
if [ $rc -ne 0 ] && grep -qi 'duplicate label' dup.e4; then echo "  arm 4 PASS (m4 refuses: rc $rc)"; else echo "  arm 4 FAIL (m4: rc $rc, stderr [$(head -c 120 dup.e4)])"; RC=1; fi
timeout -k 5 30 "$SCRIP" ctl.sc < /dev/null > ctl.m3 2> ctl.e3; rc3=$?
timeout -k 5 60 "$SCRIP" --compile -o ctl.s ctl.sc < /dev/null > /dev/null 2> ctl.e4 && gcc ctl.s -L "$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o ctl > /dev/null 2>&1 && timeout -k 5 30 ./ctl < /dev/null > ctl.m4 2> ctl.e4r; rc4=$?
if [ $rc3 -eq 0 ] && [ "$(cat ctl.m3)" = "fg" ] && [ $rc4 -eq 0 ] && [ "$(cat ctl.m4)" = "fg" ]; then echo "  arm 5 PASS (control: distinct labels in two functions print fg in m3 and m4)"; else echo "  arm 5 FAIL (control: m3 rc $rc3 [$(tr '\n' '|' < ctl.m3)] m4 rc $rc4 [$(tr '\n' '|' < ctl.m4 2>/dev/null)])"; RC=1; fi
if [ $RC -eq 0 ]; then echo "GATE PASS(0) [$NAME]: a duplicate Snocone label is refused at parse in both media, the oracle and the SNOBOL4 parser agree, the distinct-label control runs"; else echo "GATE FAIL(1) [$NAME]"; fi
exit $RC
