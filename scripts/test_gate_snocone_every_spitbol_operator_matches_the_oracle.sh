#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_snocone_every_spitbol_operator_matches_the_oracle.sh -- EVERY SPITBOL UNARY AND BINARY OPERATOR IS A SNOCONE OPERATOR (Lon 2026-10-07,
# in-chat to hq_snocone, verbatim: "We want all SPITBOL binary operators implemented in Snocone." / "We want all SPITBOL unary operators implemented in
# Snocone."; cfo ruling on D10: the C grammar gains the binary OPSYN-slot productions and the lowerer gives them the meaning SNOBOL4's slots have).
# The operator chapter of the SPITBOL manual (Chapter 15) is the specification: the unary operators @ ~ ? & + - * $ . are defined and ! % / # = | are OPSYN
# slots; the binary slots & (2, left) @ (5, right) # (7, left) % (10, left) ~ (13, right) sit between the defined binary levels at the priorities the manual
# prints. THREE WITNESSES, each written to a scratch directory, each graded against SPITBOL: the transpile of the Snocone program under sbl -bf is the
# oracle, mode 3 and mode 4 must print the same bytes.
#   1. every binary slot, alone, chained with itself (associativity), against every other slot and against + - * / (precedence), numeric slot functions;
#   2. every defined unary operator and every unary slot;
#   3. an undefined operator with &ERRLIMIT set: the statement fails, &ERRTYPE reads 29 (undefined operator referenced) for the unary and the binary form.
# rc 0 all three agree in both modes; 1 a divergence, named; 2 could not measure (no scrip, no oracle, the transpile or the link refused).
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
SCRIP_DIR="$S4E/SCRIP"; SCRIP="${SCRIP:-$SCRIP_DIR/scrip}"
. "$SCRIP_DIR/../harness/scripts/lib_oracle_flags.sh" 2>/dev/null
SBL="$(sbl_correctness_bin 2>/dev/null)"; [ -n "$SBL" ] || SBL=/home/resources/x64/bin/sbl
G=snocone-every-spitbol-operator
refuse() { echo "⛔ GATE REFUSE(2) [$G]: $*"; exit 2; }
fail() { echo "⛔ GATE FAIL(1) [$G]: $*"; exit 1; }
[ -x "$SCRIP" ] || refuse "no scrip at $SCRIP"
[ -x "$SBL" ] || refuse "no oracle at $SBL"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
python3 - "$T" <<'PY' || refuse "could not write the witnesses"
import sys
T = sys.argv[1]
mul = {'A': 10, 'B': 20, 'C': 30, 'D': 40, 'E': 50}
ops = ['&', '@', '#', '%', '~']
hdr = "".join("procedure %s2(x, y) { %s2 = x * %d + y; }\n" % (k, k, m) for k, m in mul.items())
hdr += "".join("OPSYN('%s', '%s2', 2);\n" % (o, k) for o, k in zip(ops, mul))
body = ["OUTPUT = 3 %s 4;" % o for o in ops] + ["OUTPUT = 1 %s 2 %s 3;" % (o, o) for o in ops]
body += ["OUTPUT = 1 %s 2 %s 3;" % (a, b) for a in ops for b in ops if a != b]
for o in ops:
    for t in ['+', '-', '*', '/']:
        body += ["OUTPUT = 2 %s 3 %s 4;" % (o, t), "OUTPUT = 2 %s 3 %s 4;" % (t, o)]
body += ["OUTPUT = 2 & 3 ^ 2;", "OUTPUT = 2 ^ 2 & 3;", "OUTPUT = 2 @ 3 ^ 2;", "OUTPUT = 2 ^ 2 @ 3;", "OUTPUT = 2 # 3 ^ 2;", "OUTPUT = 2 ^ 2 # 3;"]
body += ["OUTPUT = (1 & 2) # (3 @ 4);", "OUTPUT = 2 ~ 3 ~ 1;", "OUTPUT = -2 ~ 3;", "OUTPUT = 2 ~ -3;", "x = 7; OUTPUT = x # x % x;"]
open(T + "/binary.sc", "w").write(hdr + "\n".join(body) + "\n")
un = "procedure F1(x) { F1 = 'F(' x ')'; }\n" + "".join("OPSYN('%s', 'F1', 1);\n" % o for o in ['!', '%', '/', '#', '=', '|'])
un += "n = 5; nm = 'n';\nOUTPUT = +n;\nOUTPUT = -n;\nOUTPUT = $nm;\nOUTPUT = .n;\nOUTPUT = ?n;\nOUTPUT = IDENT(*n, 'x') 'deferred';\n"
un += "OUTPUT = 'abcdef' ? LEN(2) @p;\nOUTPUT = p;\nOUTPUT = ~DIFFER('a', 'a') 'neg-ok';\nOUTPUT = !n;\nOUTPUT = %n;\nOUTPUT = /n;\nOUTPUT = #n;\nOUTPUT = =n;\nOUTPUT = |n;\n"
open(T + "/unary.sc", "w").write(un)
er = "&ERRLIMIT = 10;\nOUTPUT = 'start';\nx = 3 # 4;\nOUTPUT = 'after-binary:' &ERRTYPE;\ny = #5;\nOUTPUT = 'after-unary:' &ERRTYPE;\n"
er += "z = 6 % 4;\nOUTPUT = 'after-percent:' &ERRTYPE;\nif ('ab' ? 'a' & 'b') { OUTPUT = 'wrong'; } else { OUTPUT = 'amp-tested'; }\nOUTPUT = 'done';\n"
open(T + "/undefined.sc", "w").write(er)
PY
bad=""; n=0
for w in binary unary undefined; do
    "$SCRIP" --transpile "$T/$w.sc" > "$T/$w.sno" 2> "$T/$w.err" || refuse "transpile of $w.sc refused: $(head -2 "$T/$w.err")"
    timeout -k 5 60 "$SBL" -bf "$T/$w.sno" < /dev/null > "$T/$w.ref" 2>&1; [ -s "$T/$w.ref" ] || refuse "oracle printed nothing for $w"
    timeout -k 5 60 "$SCRIP" "$T/$w.sc" < /dev/null > "$T/$w.m3" 2>&1
    "$SCRIP" --compile --out="$T/$w.s" "$T/$w.sc" < /dev/null > /dev/null 2> "$T/$w.cerr" && gcc -m64 -no-pie "$T/$w.s" -Wl,-rpath,"$SCRIP_DIR/out" -L"$SCRIP_DIR/out" -lscrip_rt -lm -lpthread -o "$T/$w.bin" 2> "$T/$w.lerr" || refuse "mode 4 build of $w failed: $(head -2 "$T/$w.cerr" "$T/$w.lerr")"
    timeout -k 5 60 "$T/$w.bin" < /dev/null > "$T/$w.m4" 2>&1
    for m in m3 m4; do n=$((n + 1)); cmp -s "$T/$w.ref" "$T/$w.$m" || bad="$bad $w/$m"; done
done
[ -z "$bad" ] || fail "SCRIP differs from the SPITBOL oracle on:$bad ($n of $n arms graded)"
echo "✅ GATE PASS(0) [$G]: binary slots (& @ # % ~: associativity and precedence), unary operators and slots, and the undefined-operator error 29 agree with SPITBOL in mode 3 and mode 4 ($n arms)"
exit 0
