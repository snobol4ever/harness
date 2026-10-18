#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_dump_matches_spitbol.sh -- &DUMP IS SPITBOL'S DUMP, BYTE FOR BYTE, IN BOTH MODES (cfo 2026-09-08/09,
# on the ceo's 22:2x ruling "your SNOBOL4 bug is &DUMP completeness", measured by hq_S on spitbol_testpgms test1).
#
# Before the cure SCRIP's end-of-run dump omitted every ARRAY, TABLE, DATA, PATTERN, EXPRESSION, NAME and CODE
# value, printed null-valued variables and its own EXPR$n temps, did not wrap at 120 bytes, dumped OUTPUT under
# its internal name, and had no &DUMP = 2 contents section at all. NOTHING GRADED EXERCISED IT (the SNOBOL4 rungs
# never sets &DUMP), which is the regression-protection shape the ceo's 22:1x audit named -- so this gate is the
# instrument: five witnesses, every expectation cut from the LIVE sbl -bf oracle at run time, never a stored ref,
# compared byte for byte (cmp, not a line diff: the 120-byte wrap and the trailing blank lines are the point).
#
#   1 datatypes      every datatype SPITBOL spells in a dump, nulls and internals omitted, serials #n shared
#   2 formats        prototype text kept (ARRAY(1:3)), TABLE(size), CODE, *NAME, the 120-byte wrap, reals
#   3 contents       &DUMP = 2: reachable objects in serial order, A<i> / T<key> / FIELD(NAME) = value
#   4 table order    a table's contents come out in SPITBOL's BUCKET order (hash mod size, insertion within)
#   5 hash           the string hash itself: XOR of little-endian 8-byte words XOR length; ints by magnitude;
#                    reals by bit pattern -- proved against a 1000-bucket table with integers marking every bucket
#
# ⛔ THE WITNESSES DECLARE THE STATEMENT INSTRUMENTATION, --stlimit, ON BOTH SCRIP COMMAND LINES (coo 2026-09-27, ceo CEO-1306, swept
# from hq_snobol4; RULES.md 8 (f)): a dump prints &LASTFILE, &LASTLINE, &LASTNO and &LINE, SPITBOL always tracks them, and SCRIP
# tracks them only under the switch since statement tracking went opt-in (CEO-1243). Typed nowhere, the four dumped blank or zero
# and the gate read red on origin 81aa23aff, a false red: hq_snobol4 measured all four byte-identical to sbl -bf once the switch is
# on, in both modes. This is a gate's own witness, so the gate declares it (arm R of the compile_args ratchet exempts gates). And the
# oracle comes from lib_oracle_flags.sh's sbl_correctness_bin, never a hand-assembled path.
# A missing oracle or binary REFUSES rc=2 (a missing oracle prints a full, plausible, entirely false table).
# Exit: 0 all witnesses identical in both modes . 1 a witness differs . 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
NAME=sno_dump_matches_spitbol
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "lib_oracle_flags.sh unloadable -- cannot name the oracle"
SBL="${SBL:-$(sbl_correctness_bin)}"
[ -x "$SBL" ] || refuse "no sbl oracle at $SBL -- cannot measure"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
cat > "$TD/dump.sno" <<'EOF'
	&DUMP = 1
	A = ARRAY(3)
	A[1] = 7
	T = TABLE()
	T["k"] = "v"
	P = "ab" | "cd"
	E = *(X + 1)
	S = "str"
	N = 42
	R = 1.5
	DATA("rec(f1,f2)")
	D = rec(1,2)
	U = ARRAY("2,2")
END
EOF
cat > "$TD/dump2b.sno" <<'EOF'
	&DUMP = 1
	A1 = ARRAY(3)
	A2 = ARRAY("2,3")
	A3 = ARRAY("-1:1,0:2")
	A4 = ARRAY("1:3", 5)
	T1 = TABLE()
	T2 = TABLE(5)
	T3 = TABLE(5, 3)
	T4 = TABLE(100, 10, "x")
	DATA("point(x,y)")
	D1 = point(1,2)
	D2 = point(3,4)
	C = CODE(" X = 1")
	E1 = *X
	P1 = LEN(3)
	NULLV = ""
	NEG = -17
	Q = "its"
	BIG = 12345678901234
	RL = 1.0
	RL2 = -0.000125
	LONGS = DUPL("abcdefghij", 20)
	S2 = A1
END
EOF
cat > "$TD/dump3.sno" <<'EOF'
	&DUMP = 2
	A = ARRAY(2)
	A[1] = "x"
	T = TABLE()
	T["k"] = 5
	T["j"] = "v"
	DATA("point(x,y)")
	D = point(1,"z")
	N = 3
END
EOF
cat > "$TD/tord.sno" <<'EOF'
	&DUMP = 2
	T = TABLE(10)
	T["CAT"] = 1
	T[7] = 2
	T["DOG"] = 3
	T[3] = 4
	T[12] = 5
	T["A"] = 6
	U = TABLE(2)
	U["CAT"] = 1
	U[7] = 2
	U["DOG"] = 3
	U[3] = 4
END
EOF
cat > "$TD/hash.sno" <<'EOF'
	&DUMP = 2
	T = TABLE(1000)
	I = 0
L	T[I] = 1
	I = I + 1
	LE(I, 999)	:S(L)
	T["A"] = 2
	T["B"] = 2
	T["C"] = 2
	T["AB"] = 2
	T["BA"] = 2
	T["CAT"] = 2
	T["DOG"] = 2
	T["ABC"] = 2
	T["ABCD"] = 2
	T["Z"] = 2
	T["AA"] = 2
	T["a"] = 2
END
EOF
GRADED=0; FAIL=0
for p in dump dump2b dump3 tord hash; do
  (cd "$TD" && timeout -k 5 20s "$SBL" -bf "$p.sno" </dev/null >"$p.want" 2>&1) || refuse "the oracle did not run $p.sno cleanly -- cannot measure"
  [ -s "$TD/$p.want" ] || refuse "the oracle produced no output for $p.sno -- cannot measure"
  grep -q 'dump of natural variables' "$TD/$p.want" || refuse "the oracle printed no dump for $p.sno -- cannot measure"
  for m in 3 4; do
    if [ "$m" = 3 ]; then
      (cd "$TD" && timeout -k 5 20s "$SCRIP" --run --stlimit "$p.sno" </dev/null >"$p.got$m" 2>&1)
    else
      (cd "$TD" && "$SCRIP" --compile --stlimit -o "$p.s" "$p.sno" </dev/null >/dev/null 2>&1) || refuse "mode-4 compile of $p.sno failed -- cannot measure"
      (cd "$TD" && gcc -no-pie "$p.s" -o "$p.bin" -L "$ROOT/out" -lscrip_rt -lm -lpthread >/dev/null 2>&1) || refuse "mode-4 link of $p.sno failed -- cannot measure"
      (cd "$TD" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20s "./$p.bin" </dev/null >"$p.got$m" 2>&1)
    fi
    GRADED=$((GRADED+1))
    if cmp -s "$TD/$p.want" "$TD/$p.got$m"; then echo "  PASS m$m $p ($(wc -l <"$TD/$p.want") lines byte-identical to sbl -bf)"
    else echo "  FAIL m$m $p: SCRIP's dump differs from sbl -bf"; diff -a "$TD/$p.want" "$TD/$p.got$m" | sed 's/^/        /' | head -10; FAIL=$((FAIL+1)); fi
  done
done
[ "$GRADED" -eq 0 ] && refuse "graded zero witnesses"
echo "graded=$GRADED FAIL=$FAIL (five witnesses x two modes; every expectation cut from the LIVE sbl -bf oracle at run time, compared with cmp)"
if [ "$FAIL" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: FAIL=$FAIL of $GRADED"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $GRADED/$GRADED"
exit 0
