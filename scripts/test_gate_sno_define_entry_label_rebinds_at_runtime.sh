#!/usr/bin/env bash
# DEFINE(proto, entry) rebinds an already-DEFINE'd function's ENTRY POINT, and the binding in force is the
# one the LAST EXECUTED DEFINE established -- never the last TEXTUAL one.  Gimpel's re-DEFINE idiom (COPYL,
# Algorithms in SNOBOL4 5.8) guards a self-call with it, so a statically-resolved entry is unbounded
# recursion, which is why this arrived filed as a stack-overflow-guard defect.  Both media, graded against
# the live oracle: the m4 half is the one that regressed silently before, because x86_load_ro emits the
# SYMBOLIC label in TEXT but bakes a compile-time pointer in BINARY, so a cure can pass one medium alone.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
[ -x ./scrip ] || { echo "GATE REFUSES(2): no ./scrip binary -- build first"; exit 2; }
. ../harness/scripts/lib_oracle_flags.sh || { echo "GATE REFUSES(2): oracle flags lib missing"; exit 2; }
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "GATE REFUSES(2): correctness oracle absent"; exit 2; }
SD="$(pwd)"; RT_DIR="$SD/out"; W="$(mktemp -d)" || exit 2; trap 'rm -rf "$W"' EXIT
cat > "$W/f.sno" <<'EOF'
	DEFINE('G(L)T')
	                                :(GEND)
G	OUTPUT = 'at-G'
	DEFINE('G(L)', 'G_1')
	G = G(L)
	DEFINE('G(L)T')                 :(RETURN)
G_1	OUTPUT = 'at-G1'
	G = 'done'                      :(RETURN)
GEND
	OUTPUT = G('x')
	OUTPUT = 'second call:'
	OUTPUT = G('y')
END
EOF
SINK="$(sbl_listing_sink_flag "$W")" || { echo "GATE REFUSES(2): no writable listing sink"; exit 2; }
EXP="$(cd "$W" && timeout -k 5 10s "$SBL" $(sbl_lang_flags) $SINK f.sno </dev/null 2>&1)"; orc=$?
[ "$orc" -eq 0 ] || { echo "GATE REFUSES(2): the oracle itself did not grade the witness (rc=$orc)"; exit 2; }
printf '%s' "$EXP" | grep -q 'at-G1' || { echo "GATE REFUSES(2): oracle output does not carry the re-DEFINE'd entry -- witness or oracle changed under this gate"; exit 2; }
bad=0
GOT3="$(cd "$W" && timeout -k 5 10s "$SD/scrip" --run f.sno </dev/null 2>&1)"
if [ "$GOT3" != "$EXP" ]; then bad=1; echo "  FAIL  m3 entry rebinding"; diff <(printf '%s\n' "$GOT3") <(printf '%s\n' "$EXP") | head -6; else echo "  ok    m3 entry rebinding"; fi
T="$(mktemp -d)" || exit 2
if ( cd "$W" && timeout -k 5 60s "$SD/scrip" --compile f.sno ) > "$T/p.s" 2>"$T/cc.err" \
   && gcc -c "$T/p.s" -o "$T/p.o" 2>/dev/null \
   && gcc "$T/p.o" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$W/f.bin" 2>/dev/null; then
    GOT4="$(cd "$W" && timeout -k 5 10s ./f.bin </dev/null 2>&1)"
    if [ "$GOT4" != "$EXP" ]; then bad=1; echo "  FAIL  m4 entry rebinding"; diff <(printf '%s\n' "$GOT4") <(printf '%s\n' "$EXP") | head -6; else echo "  ok    m4 entry rebinding"; fi
else
    rm -rf "$T"; echo "GATE REFUSES(2): mode-4 compile/link failed -- no program answer to grade"; exit 2
fi
rm -rf "$T"
[ "$bad" -eq 0 ] || { echo "GATE RED: DEFINE's entry label is not the binding in force at the call"; exit 1; }
echo "GATE GREEN [sno_define_entry_label_rebinds_at_runtime]: both media take the executing DEFINE's entry"
exit 0
