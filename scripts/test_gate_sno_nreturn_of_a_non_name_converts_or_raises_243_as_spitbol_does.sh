#!/usr/bin/env bash
# test_gate_sno_nreturn_of_a_non_name_converts_or_raises_243_as_spitbol_does.sh -- a function that leaves by NRETURN with a value that is
# not a NAME answers as sbl -bf does, in both modes (row snobol4-error-243-non-name-nreturn-result-is-not-raised-where-sbl-halts). SPITBOL
# turns a non-null STRING, an INTEGER or a REAL into the name of the variable spelled so -- G = 'ABC' :(NRETURN) makes G() read and assign
# ABC, G = 5 + 5 names the variable '10' -- and raises ERROR 243 "function result in nreturn is not name" for anything else (the null
# string, an ARRAY, a PATTERN). SCRIP handed the value back unchanged: G() read 'ABC' itself, G() = 'set' aborted (BOMB rt_assign_var), and
# no 243 was raised. The cure converts at the call epilogue's by-name consult (rt_nret_name, emitted) and in rt_nret_fix (the C road).
# THE WITNESSES: the direct call in rvalue and lvalue position (string, real, integer, name), the APPLY road, and the three 243 values
# under &ERRLIMIT -- each graded in mode 3 and mode 4 against the ref sbl -bf prints, CUT FROM THE ORACLE at run time.
# FAIL_ONCE (2026-10-17, 7be9d5ee1 with the cure's three files stashed): RED 10 of 10 -- direct and apply abort rc 134 at the lvalue
# G() = 'set' after reading G=[ABC] for hello, and the three 243 witnesses print a value (PATTERN, X=[]) or nothing instead of the error.
# rc 0 every arm equals the oracle / 1 an arm diverged / 2 could not measure (no scrip, runtime or oracle, or the oracle printed nothing).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- the ref is cut from the oracle at run time"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cd "$T" || exit 2
cat > direct.sno <<'EOF'
	DEFINE('G()')
	DEFINE('H()')
	DEFINE('K()')
	DEFINE('I()')	:(M)
G	G = 'ABC'	:(NRETURN)
H	H = 3.5	:(NRETURN)
K	K = .ABC	:(NRETURN)
I	I = 5 + 5	:(NRETURN)
M	ABC = 'hello'
	$'3.5' = 'three'
	OUTPUT = 'G=[' G() ']'
	G() = 'set'
	OUTPUT = 'ABC=[' ABC ']'
	OUTPUT = 'H=[' H() ']'
	OUTPUT = 'K=[' K() ']'
	OUTPUT = 'I=[' I() ']'
	OUTPUT = 'nameof=[' DATATYPE(.G()) ']'
END
EOF
cat > apply.sno <<'EOF'
	&ERRLIMIT = 5
	DEFINE('G()')
	DEFINE('H()')	:(M)
G	G = 'ABC'	:(NRETURN)
H	H = ARRAY(2)	:(NRETURN)
M	ABC = 'hello'
	OUTPUT = 'apply G=[' APPLY('G') ']'
	APPLY('G') = 'via apply'
	OUTPUT = 'ABC=[' ABC ']'
	X = APPLY('H')	:F(F)
	OUTPUT = 'apply H=[' X ']'	:(END)
F	OUTPUT = 'apply H failed ' &ERRTYPE
END
EOF
for v in "ARRAY(2)" "LEN(1)" "''"; do
    n="r243_$(printf '%s' "$v" | tr -cd 'A-Za-z0-9')"; [ "$n" = r243_ ] && n=r243_null
    printf "\t&ERRLIMIT = 5\n\tDEFINE('G()')\t:(M)\nG\tG = %s\t:(NRETURN)\nM\tX = G()\t:F(F)\n\tOUTPUT = 'X=[' X ']'\t:(END)\nF\tOUTPUT = 'failed ' &ERRTYPE ' ' &ERRTEXT\nEND\n" "$v" > $n.sno
done
RC=0; n=0; red=""
for w in direct apply r243_ARRAY2 r243_LEN1 r243_null; do
    timeout -k 5 20s "$SBL" -bf $w.sno < /dev/null > $w.ref 2>&1
    [ -s $w.ref ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for $w"; exit 2; }
    timeout -k 5 20s "$SCRIP" $w.sno < /dev/null > $w.m3 2> $w.e3
    if "$SCRIP" --compile -o $w.s $w.sno < /dev/null > $w.c 2>&1 && gcc $w.s -L"$LIBDIR" -lscrip_rt -lm -Wl,-rpath,"$LIBDIR" -o $w.x 2>> $w.c; then
        timeout -k 5 20s ./$w.x < /dev/null > $w.m4 2> $w.e4
    else echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link failed for $w: $(grep -m1 . $w.c | cut -c1-160)"; exit 2; fi
    for m in m3 m4; do
        n=$((n+1))
        if cmp -s $w.$m $w.ref; then echo "  $w $m PASS"
        else echo "  $w $m FAIL (first difference: $(diff $w.$m $w.ref | grep -m2 '^[<>]' | tr '\n' ' ' | cut -c1-160))"; RC=1; red="$red $w.$m"; fi
    done
done
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: NRETURN of a non-name converts or raises 243 as sbl -bf does -- $n of $n arms (5 witnesses x 2 modes)"
else echo "⛔ GATE FAIL(1) [$G]: diverged from sbl -bf:$red"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
