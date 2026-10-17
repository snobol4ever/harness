#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ WITNESS GATE for row snobol4-gimpel-recursive-list-functions-overflow-the-call-stack-where-spitbol-completes
# (cfo 2026-09-12, on the ceo's CEO-626 naming of the prototype defect).
#
# DEFINE(proto, entry) is executable: EACH execution binds the prototype -- the formal NAMES, the locals list
# and the entry.  0d54a825f made the ENTRY follow the executed DEFINE; the PROTOTYPE still does not: the
# activation binds the argument into the formal name of the LAST TEXTUAL DEFINE (bb_scc_probe reads the
# compile-time registry, where the last registration wins) and saves/nulls the last textual locals list.
# Two witnesses, both cut live from the oracle:
#   W1 rename the formal:  DEFINE('rd(n)') ... DEFINE('rd(rd)','rd2') -- the FIRST call, before any redefine,
#      must bind n (rd(3) = 6, not 0).  Checked at n=3 AND n=5 so 3! = 3*2 cannot hide the last-prototype body
#      (three rungs entries passed by exactly that coincidence until 0d54a825f).
#   W2 drop a local (Gimpel's COPYL idiom): DEFINE('C(L)T') whose body re-DEFINEs 'C(L)' with entry C_1 and
#      sets T before recursing -- the inner calls must NOT save-and-null T (ERROR 235 today).
# Exit: 0 both witnesses match the oracle in both modes · 1 the defect is present · 2 REFUSED (cannot measure).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"
[ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
SCRIP_BIN="${SCRIP_BIN:-$ROOT/scrip}"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
[ -x "$SCRIP_BIN" ] || { echo "⛔ REFUSE(2): no scrip binary at $SCRIP_BIN -- cannot measure"; exit 2; }
[ -x "$SBL" ]       || { echo "⛔ REFUSE(2): no SPITBOL oracle at $SBL -- cannot measure"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w1.sno" <<'SNO'
	DEFINE('rd(n)')                                 :(rd_end)
rd	rd = n * 2                                      :(RETURN)
rd_end
	OUTPUT = 'first rd(3) = ' rd(3)
	OUTPUT = 'first rd(5) = ' rd(5)
	DEFINE('rd(rd)', 'rd2')                         :(rd2_end)
rd2	rd = NE(rd,1) rd * rd(rd - 1)                   :(RETURN)
rd2_end
	OUTPUT = 'after rd(4) = ' rd(4)
	OUTPUT = 'after rd(5) = ' rd(5)
END
SNO
cat > "$T/w2.sno" <<'SNO'
	DEFINE('C(L)T')                                 :(C_END)
C	DEFINE('C(L)', 'C_1')
	T = TABLE(10)
	T['seen'] = 'yes'
	C = C(L)
	DEFINE('C(L)T')                                 :(RETURN)
C_1	C = 'inner sees T<seen> = ' T['seen'] ' with L = ' L   :(RETURN)
C_END
	OUTPUT = C('x')
	OUTPUT = 'outer T after = [' T ']'
END
SNO
red=0
for w in w1 w2; do
    ( cd "$T" && timeout -k 5 20 "$SBL" -bf $w.sno </dev/null > $w.oracle 2>&1 )
    [ -s "$T/$w.oracle" ] || { echo "⛔ REFUSE(2): the oracle produced no output for $w -- cannot grade against nothing"; exit 2; }
    grep -qi 'error' "$T/$w.oracle" && { echo "⛔ REFUSE(2): the oracle itself errs on $w; the witness is wrong, not SCRIP"; cat "$T/$w.oracle"; exit 2; }
    ( cd "$T" && timeout -k 5 20 "$SCRIP_BIN" $w.sno </dev/null > $w.m3 2>&1 ) || true
    cmp -s "$T/$w.oracle" "$T/$w.m3" || { echo "RED m3 $w: $(diff "$T/$w.oracle" "$T/$w.m3" | grep -m1 '^[<>]' | cut -c1-80)"; red=1; }
    ( cd "$T" && timeout -k 5 60 "$SCRIP_BIN" --compile -o $w.s $w.sno </dev/null >/dev/null 2>&1 \
      && gcc -no-pie $w.s -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o $w.b >/dev/null 2>&1 \
      && timeout -k 5 20 ./$w.b </dev/null > $w.m4 2>&1 ) || true
    cmp -s "$T/$w.oracle" "$T/$w.m4" || { echo "RED m4 $w: $(diff "$T/$w.oracle" "$T/$w.m4" 2>/dev/null | grep -m1 '^[<>]' | cut -c1-80)"; red=1; }
done
if [ "$red" != 0 ]; then
    echo "⛔ the PROTOTYPE (formal names, locals list) is baked from the last textual DEFINE; each execution must bind its own."
    for w in w1 w2; do echo "   $w oracle: $(tr '\n' ' ' < "$T/$w.oracle" | cut -c1-120)"; echo "   $w m3    : $(tr '\n' ' ' < "$T/$w.m3" | cut -c1-120)"; done
    exit 1
fi
echo "GATE OK: the executed DEFINE's prototype binds the formals and the locals list, both modes, live oracle diff"
exit 0
