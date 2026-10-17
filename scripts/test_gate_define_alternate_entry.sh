#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ WITNESS GATE for row snobol4-define-alternate-entry-binds-one-entry-for-the-whole-program (hq_P).
#
# DEFINE is an EXECUTABLE statement: each execution binds the entry point.  We bind once at compile time, so
# the LAST DEFINE in program TEXT wins for every call, in both modes.  This gate is the smallest witness that
# says so out loud, and it exists because the row was rank 0 and FREE with a mint-placeholder DONE-WHEN --
# whoever took it would have spent the sitting rediscovering a repro.
#
# ⛔ WHY NOT GRADE COPYL_driver INSTEAD.  The Gimpel driver that leads here fails as `ERROR 246 -- stack
# overflow`, because its two-entry re-DEFINE makes COPYL re-enter its own outer body forever.  A stack
# overflow NAMES NO CAUSE and invites a stack-depth hunt.  This witness prints the WRONG ENTRY directly, with
# no recursion, no list structure and no include -- an unambiguous oracle diff instead of a crash to bisect.
#
# ⛔ THE ORACLE IS RUN LIVE, NEVER PINNED, and a missing or unexpected oracle REFUSES rc=2 rather than
# grading -- a missing oracle does not blank a board, it prints a full, plausible, entirely false table.
#
# Exit: 0 = both modes match the oracle.  1 = the defect is present.  2 = REFUSED, could not measure.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"
[ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
SCRIP_BIN="${SCRIP_BIN:-$ROOT/scrip}"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
[ -x "$SCRIP_BIN" ] || { echo "⛔ REFUSE(2): no scrip binary at $SCRIP_BIN -- cannot measure"; exit 2; }
[ -x "$SBL" ]       || { echo "⛔ REFUSE(2): no SPITBOL oracle at $SBL -- cannot measure"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
# Three DEFINEs of ONE name with alternating entry labels.  Tabs are significant in SNOBOL4 source.
cat > "$T/alt3.sno" <<'SNO'
	DEFINE('F(X)')				:(FEND)
F	OUTPUT = 'E0 ' X
	DEFINE('F(X)', 'F_1')
	F = F(X)				:(RETURN)
F_1	OUTPUT = 'E1 ' X
	DEFINE('F(X)', 'F_2')
	F = F(X)				:(RETURN)
F_2	OUTPUT = 'E2 ' X
	F = 'done'				:(RETURN)
FEND
	OUTPUT = F('v')
END
SNO
( cd "$T" && timeout -k 5 20 "$SBL" -bf alt3.sno </dev/null > oracle.out 2>&1 )
[ -s "$T/oracle.out" ] || { echo "⛔ REFUSE(2): the oracle produced no output -- cannot grade against nothing"; exit 2; }
grep -q '^E0 v$' "$T/oracle.out" || { echo "⛔ REFUSE(2): oracle output is not the alternating-entry shape this gate grades; refusing to grade against it"; cat "$T/oracle.out"; exit 2; }
red=0
( cd "$T" && timeout -k 5 20 "$SCRIP_BIN" alt3.sno </dev/null > m3.out 2>&1 ) || true
python3 "$HERE/util_render_error_voice.py" spitbol < "$T/m3.out" > "$T/m3.out.r" && mv "$T/m3.out.r" "$T/m3.out"
cmp -s "$T/oracle.out" "$T/m3.out" || { echo "RED m3: first divergence $(diff "$T/oracle.out" "$T/m3.out" | grep -m1 '^[<>]' | cut -c1-70)"; red=1; }
( cd "$T" && timeout -k 5 60 "$SCRIP_BIN" --compile -o alt3.s alt3.sno </dev/null >/dev/null 2>&1 \
  && gcc -no-pie alt3.s -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o alt3.b >/dev/null 2>&1 \
  && timeout -k 5 20 ./alt3.b </dev/null > m4.out 2>&1 ) || true
python3 "$HERE/util_render_error_voice.py" spitbol < "$T/m4.out" > "$T/m4.out.r" && mv "$T/m4.out.r" "$T/m4.out"
cmp -s "$T/oracle.out" "$T/m4.out" || { echo "RED m4: first divergence $(diff "$T/oracle.out" "$T/m4.out" 2>/dev/null | grep -m1 '^[<>]' | cut -c1-70)"; red=1; }
if [ "$red" != 0 ]; then
    echo "⛔ the LAST DEFINE in program text won: each DEFINE execution must rebind the entry point."
    echo "   oracle: $(tr '\n' ' ' < "$T/oracle.out")"
    echo "   m3    : $(tr '\n' ' ' < "$T/m3.out")"
    exit 1
fi
echo "GATE OK: three DEFINEs with alternating entry labels bind per EXECUTION, both modes, live oracle diff"
exit 0
