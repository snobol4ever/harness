#!/usr/bin/env bash
# test_gate_gc_a_collection_inside_a_snocone_procedure_finds_its_frame_in_both_modes.sh -- a collection inside a Snocone procedure finds
# the procedure's frame and its caller's in both modes (row snobol4-tixdemo-infinite-snobol4-runs-without-a-crash-in-mode-4-ceo-1812:
# TixDemo infinite_snobol4.md CRASH in mode 4 on 371ce73cc, "[GC-CHAIN] REFUSED: the chain over the maps stops short (frameless) after
# 0 frame(s)"). A Snocone procedure is a class-C chain frame with no map: its prologue parks the caller's rcx at kt-24, and on a direct
# call that is the call site's static record {count, gamma landing, omega landing}; the chain's class-C hop reads the gamma landing
# through it (49a7604cd). The hop admitted the record only inside a code block, which held while mode 4 emitted it in .text; 6b0131879
# moved every signature record of mode-4 text to .data.rel.ro, so every collection inside a directly called Snocone procedure bombed in
# mode 4 (mode 3 keeps the record in its code blob). The hop now admits any parked record and still takes only a registered landing.
# THE WITNESSES: four Snocone programs (an allocating procedure called from main, a pattern replacement in a procedure, the capture-
# nulling loop of infinite_snobol4.md, and a SCRIPtix document whose Icon section calls a Snocone procedure), each graded in mode 3 and
# mode 4 at SCRIP_GC_STRESS 0, 1 and 3 against the ref sbl -bf prints for its SNOBOL4 twin -- CUT FROM THE ORACLE at run time.
# FAIL_ONCE (2026-10-17, bd03a04e9 with the cure's gc_heap.c hunk reverted): RED, 7 of 24 arms, every one mode 4 rc 134 frameless --
# all four witnesses at stress 1, capnull and the SCRIPtix document at stress 3, the SCRIPtix document at stress 0 (TixDemo's own crash
# at the shipped arena); mode 3 green throughout. With the cure 24 of 24 arms equal the oracle.
# rc 0 every arm equals the oracle / 1 an arm diverged / 2 could not measure (no scrip, runtime or oracle, a twin the oracle refused,
# or a mode-4 compile or link that failed).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- the ref is cut from the oracle at run time"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cd "$T" || exit 2
printf 'function f() x {\n    x = DUPL('"'"'ab'"'"', 50);\n    f = x;\n    return;\n}\nOUTPUT = SIZE(f());\n' > alloc.sc
printf '\tDEFINE('"'"'f()x'"'"')\t:(main)\nf\tx = DUPL('"'"'ab'"'"', 50)\n\tf = x\t:(RETURN)\nmain\tOUTPUT = SIZE(f())\nEND\n' > alloc.sno
printf 'function f() rest {\n    rest = '"'"'ABC'"'"';\n    rest ? LEN(1) = '"'"''"'"';\n    f = rest;\n    return;\n}\nOUTPUT = f();\n' > replace.sc
printf '\tDEFINE('"'"'f()rest'"'"')\t:(main)\nf\trest = '"'"'ABC'"'"'\n\trest LEN(1) = '"'"''"'"'\n\tf = rest\t:(RETURN)\nmain\tOUTPUT = f()\nEND\n' > replace.sno
CAP='function capnull() rest, letter {\n    rest = &UCASE;\n    while (rest ? LEN(1) . letter = '"'"''"'"') { $letter = '"'"''"'"'; }\n    return;\n}\nfunction judge(n) i {\n    i = 0;\n    while (LT(i, n)) { capnull(); i = i + 1; }\n    judge = i;\n    return;\n}\n'
printf "${CAP}OUTPUT = judge(200);\n" > capnull.sc
printf '\tDEFINE('"'"'capnull()rest,letter'"'"')\n\tDEFINE('"'"'judge(n)i'"'"')\t:(main)\ncapnull\trest = &UCASE\ncn1\trest LEN(1) . letter =\t:F(RETURN)\n\t$letter = '"'"''"'"'\t:(cn1)\njudge\ti = 0\nj1\tLT(i,n)\t:F(j2)\n\tcapnull()\n\ti = i + 1\t:(j1)\nj2\tjudge = i\t:(RETURN)\nmain\tOUTPUT = judge(200)\nEND\n' > capnull.sno
{ printf '```Snocone\n'; printf "${CAP}drive();\n"; printf '```\n\n```Icon\nprocedure drive()\n    local k;\n    every k := 1 to 20 do write(judge(50));\n    return;\nend\n```\n'; } > tix.md
printf '\tDEFINE('"'"'capnull()rest,letter'"'"')\n\tDEFINE('"'"'judge(n)i'"'"')\t:(main)\ncapnull\trest = &UCASE\ncn1\trest LEN(1) . letter =\t:F(RETURN)\n\t$letter = '"'"''"'"'\t:(cn1)\njudge\ti = 0\nj1\tLT(i,n)\t:F(j2)\n\tcapnull()\n\ti = i + 1\t:(j1)\nj2\tjudge = i\t:(RETURN)\nmain\tk = 0\nm1\tk = LT(k, 20) k + 1\t:F(END)\n\tOUTPUT = judge(50)\t:(m1)\nEND\n' > tix.sno
RC=0; n=0; red=""
for w in alloc.sc replace.sc capnull.sc tix.md; do
    b="${w%.*}"
    timeout -k 5 20s "$SBL" -bf $b.sno < /dev/null > $b.ref 2>&1
    [ -s $b.ref ] && ! grep -q 'ERROR' $b.ref || { echo "⛔ GATE REFUSE(2) [$G]: the oracle gave no clean answer for the twin $b.sno -- no ref to grade against"; exit 2; }
    "$SCRIP" --compile --out=$b.s $w < /dev/null > $b.c 2>&1 && gcc $b.s -L"$LIBDIR" -lscrip_rt -lm -Wl,-rpath,"$LIBDIR" -o $b.x 2>> $b.c || { echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link failed for $w: $(grep -m1 . $b.c | cut -c1-160)"; exit 2; }
    for st in 0 1 3; do
        SCRIP_GC_STRESS=$st timeout -k 5 60s "$SCRIP" $w < /dev/null > $b.m3 2> $b.e3; r3=$?
        SCRIP_GC_STRESS=$st timeout -k 5 60s ./$b.x < /dev/null > $b.m4 2> $b.e4; r4=$?
        for m in m3 m4; do
            n=$((n+1)); rc=$r3; [ $m = m4 ] && rc=$r4
            if [ "$rc" = 0 ] && cmp -s $b.$m $b.ref; then echo "  $w $m stress=$st PASS"
            else echo "  $w $m stress=$st FAIL (rc=$rc; $(grep -m1 -aoE 'stops short \([a-z-]+\)|BOMB.*' $b.e${m#m} | cut -c1-120))"; RC=1; red="$red $b.$m@$st"; fi
        done
    done
done
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: a collection inside a Snocone procedure finds its frame -- $n of $n arms equal sbl -bf (4 witnesses x 2 modes x stress 0,1,3)"
else echo "⛔ GATE FAIL(1) [$G]: diverged from sbl -bf:$red"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
