#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
NAME=sno_captured_substring_compares_by_its_own_length
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="${SBL:-/home/resources/x64/bin/sbl}"
[ -x "$SBL" ] || refuse "no sbl oracle at $SBL -- cannot measure (a missing oracle prints a full, plausible, entirely false table)"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
cat > "$TD/w.sno" <<'EOF'
	DEFINE('A(N)M')                                 :(AE)
A	N LEN(1) . M
	OUTPUT = 'first  M=[' M '] EQ5 ' IDENT(EQ(M,5),) 'T'
	N LEN(1) LEN(1) . M
	OUTPUT = 'mid    M=[' M '] EQ1 ' IDENT(EQ(M,1),) 'T'
	N LEN(2) LEN(1) . M
	OUTPUT = 'last   M=[' M '] EQ2 ' IDENT(EQ(M,2),) 'T'
	N LEN(1) . M
	OUTPUT = 'notGE  M=[' M '] GE100 ' IDENT(GE(M,100),) 'WRONG'
	A = 'done'                                      :(RETURN)
AE
	OUTPUT = A(512)
END
EOF
cat > "$TD/s.sno" <<'EOF'
-INCLUDE "SPELL.INC"
	OUTPUT = SPELL(1976)
END
EOF
GRADED=0; FAIL=0
WANT="$(cd "$TD" && timeout -k 5 20s "$SBL" -bf w.sno </dev/null 2>&1 | grep -v '^$')"
[ -n "$WANT" ] || refuse "the oracle produced no output for the capture witness -- cannot measure"
for m in 3 4; do
  if [ "$m" = 3 ]; then
    GOT="$(cd "$TD" && timeout -k 5 20s "$SCRIP" --run w.sno </dev/null 2>&1)"
  else
    (cd "$TD" && "$SCRIP" --compile -o w.s w.sno </dev/null >/dev/null 2>&1) || refuse "mode-4 compile failed -- cannot measure"
    (cd "$TD" && gcc -no-pie w.s -o w.bin -L "$ROOT/out" -lscrip_rt -lm -lpthread >/dev/null 2>&1) || refuse "mode-4 link failed -- cannot measure"
    GOT="$(cd "$TD" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20s ./w.bin </dev/null 2>&1)"
  fi
  GRADED=$((GRADED+1))
  if [ "$GOT" != "$WANT" ]; then
    echo "  FAIL m$m capture-comparison: SCRIP disagrees with sbl -bf"
    diff <(printf '%s\n' "$WANT") <(printf '%s\n' "$GOT") | sed 's/^/        /' | head -8
    FAIL=$((FAIL+1))
  else
    echo "  PASS m$m capture-comparison (first/mid/last capture of 512 all compare by their own length)"
  fi
done
GIMPEL="$ROOT/../corpus/packages/snobol4/snoflake_suite/gimpel"
if [ -d "$GIMPEL" ]; then
  ln -sf "$GIMPEL"/*.INC "$TD"/ 2>/dev/null || true
  SW="$(cd "$TD" && timeout -k 5 20s "$SBL" -bf s.sno </dev/null 2>&1 | grep -v '^$' | tail -1)"
  SG="$(cd "$TD" && SNO_LIB="$GIMPEL" timeout -k 5 20s "$SCRIP" --run s.sno </dev/null 2>&1 | tail -1)"
  GRADED=$((GRADED+1))
  if [ "$SG" != "$SW" ]; then echo "  FAIL m3 SPELL(1976): got [$SG] want [$SW]"; FAIL=$((FAIL+1));
  else echo "  PASS m3 SPELL(1976) [$SG] -- the recursive witness whose symptom was ERROR 246, two levels downstream"; fi
fi
[ "$GRADED" -eq 0 ] && refuse "graded zero witnesses"
echo "graded=$GRADED FAIL=$FAIL (every expectation cut from the LIVE sbl -bf oracle at run time, never a stored ref)"
if [ "$FAIL" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: FAIL=$FAIL of $GRADED"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $GRADED/$GRADED"
exit 0
