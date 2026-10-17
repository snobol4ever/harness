#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_emit_dwarf_loc.sh -- DONE-WHEN for task perf-per-statement-loc-emission (slice 2 of
# perf-symbol-attribution-tooling). Per-statement DWARF .file/.loc in TEXT medium, ON BY DEFAULT.
# ⛔ POLARITY INVERTED 2026-08-28 (hq_P): this gate previously asserted the feature was OPT-IN
# (SCRIP_DWARF_LOC=1 to enable). Instrument Law 1 -- a cure behind a flag defaults ON and the flag
# is the control arm -- so the default now EMITS and SCRIP_DWARF_LOC=0 is the killswitch.
# Arms, any of which can say NO:
#   1. the x86("loc",...) encoder exists in x86_asm.h
#   2. DEFAULT build (no env) emits .file/.loc -- the feature is on without being asked for
#   3. SCRIP_DWARF_LOC=0 emits NEITHER -- the killswitch works (clause 10 control arm)
#   4. .file is declared ONCE per file number, not once per .loc
#   5. DWARF decodes, and every file-1 line lies inside the source's real line range
#   6. -INCLUDE witness: statements not in the main file go to file 2, never a bogus file-1 line
#   7. .text is byte-identical default-vs-killswitch, PROVEN NON-VACUOUS by a poison arm
#   8. test_gate_template_medium_invisible.sh still passes
# ⛔ rc=2 REFUSED-TO-GRADE (could not measure) is deliberately distinct from rc=1 FAILED.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
DEMO="${DEMO:-$ROOT/../corpus/demos/snobol4/roman/roman.sno}"
refuse() { echo "⛔ REFUSED TO GRADE: $*" >&2; exit 2; }
fail()   { echo "⛔ FAIL: $*" >&2; exit 1; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- build first"
[ -f "$DEMO" ]  || refuse "demo program not found: $DEMO"
[ -f "$ROOT/src/templates/x86/x86_asm.h" ] || refuse "x86_asm.h not found -- wrong tree layout"
command -v gcc >/dev/null 2>&1 || refuse "gcc not available"
command -v readelf >/dev/null 2>&1 || refuse "readelf not available"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
nloc()  { grep -cE '^[[:space:]]*\.loc'  "$1" 2>/dev/null || true; }
nfile() { grep -cE '^[[:space:]]*\.file' "$1" 2>/dev/null || true; }
grep -q '!strcmp(mnem, "loc")' "$ROOT/src/templates/x86/x86_asm.h" || fail "x86(\"loc\",...) encoder not found in x86_asm.h"
"$SCRIP" --compile -o "$W/def.s" "$DEMO" </dev/null >/dev/null 2>"$W/def.err" || refuse "default compile failed: $(cat "$W/def.err")"
SCRIP_DWARF_LOC=0 "$SCRIP" --compile -o "$W/off.s" "$DEMO" </dev/null >/dev/null 2>"$W/off.err" || refuse "killswitch compile failed: $(cat "$W/off.err")"
[ "$(nloc  "$W/def.s")" -gt 0 ] || fail "DEFAULT build emits no .loc -- the feature is not on by default (Instrument Law 1)"
[ "$(nfile "$W/def.s")" -gt 0 ] || fail "DEFAULT build emits no .file"
[ "$(nloc  "$W/off.s")" -eq 0 ] || fail "SCRIP_DWARF_LOC=0 still emits .loc -- killswitch does not work"
[ "$(nfile "$W/off.s")" -eq 0 ] || fail "SCRIP_DWARF_LOC=0 still emits .file -- killswitch does not work"
FDECL="$(nfile "$W/def.s")"
[ "$FDECL" -le 2 ] || fail ".file declared $FDECL times -- it must be declared once per file number, not once per .loc"
gcc -no-pie "$W/def.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/def.prog" 2>"$W/link.err" || refuse "linking default demo failed: $(cat "$W/link.err")"
LINES="$(readelf --debug-dump=decodedline "$W/def.prog" 2>/dev/null | awk '$1 ~ /\.sno$/ && $2 ~ /^[0-9]+$/ {print $2}' | sort -n -u)"
[ -n "$LINES" ] || fail "readelf found no decoded source lines in the built demo's DWARF line table"
SRC_MAXLINE="$(wc -l < "$DEMO")"
echo "$LINES" | awk -v max="$SRC_MAXLINE" '{ if ($1 < 1 || $1 > max) { print "line " $1 " outside 1.." max; exit 1 } }' \
  || fail "a decoded DWARF line falls outside $(basename "$DEMO")'s real line range -- the line map is wrong"
mkdir -p "$W/inc"
printf "        incval1 = 'I1'\n        incval2 = 'I2'\n" > "$W/inc/gatehelper.inc"
printf "* comment\n        before = 'B'\n-INCLUDE 'gatehelper.inc'\n        after = 'A'\n        OUTPUT = before after incval1 incval2\nEND\n" > "$W/inc/gatewit.sno"
( cd "$W/inc" && "$SCRIP" --compile -o wit.s gatewit.sno </dev/null >/dev/null 2>&1 ) || refuse "-INCLUDE witness failed to compile"
WN="$(wc -l < "$W/inc/gatewit.sno")"
BOGUS="$(awk -v n="$WN" '/^[[:space:]]*\.loc/ && $2 == 1 && $3 > n' "$W/inc/wit.s" | wc -l)"
[ "$BOGUS" -eq 0 ] || fail "$BOGUS .loc directive(s) name file 1 with a line past the main file's end -- included code is being attributed to the main source"
INCROWS="$(awk '/^[[:space:]]*\.loc/ && $2 == 2' "$W/inc/wit.s" | wc -l)"
[ "$INCROWS" -gt 0 ] || fail "-INCLUDE witness produced no file-2 rows -- included statements are not being separated from the main file"
gcc -no-pie "$W/off.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/off.prog" 2>/dev/null || refuse "linking killswitch demo failed"
objcopy -O binary --only-section=.text "$W/def.prog" "$W/def.text" 2>/dev/null || refuse "objcopy unavailable"
objcopy -O binary --only-section=.text "$W/off.prog" "$W/off.text" 2>/dev/null || refuse "objcopy unavailable"
cmp -s "$W/def.text" "$W/off.text" || fail ".text differs between default and killswitch -- .loc is NOT inert, it moved executable bytes"
awk 'BEGIN{d=0}{print} /^main:/ && !d {print "        nop"; d=1}' "$W/def.s" > "$W/poison.s"
gcc -no-pie "$W/poison.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/poison.prog" 2>/dev/null || refuse "poison arm failed to link -- cannot prove the .text check is non-vacuous"
objcopy -O binary --only-section=.text "$W/poison.prog" "$W/poison.text" 2>/dev/null
cmp -s "$W/def.text" "$W/poison.text" && fail "the .text identity check is VACUOUS -- a one-instruction poison did not change it"
bash "$HERE/test_gate_template_medium_invisible.sh" >"$W/medium.out" 2>&1 || fail "test_gate_template_medium_invisible regressed: $(cat "$W/medium.out")"
echo "✅ emit-dwarf-loc gate: default-ON ($(nloc "$W/def.s") .loc, $FDECL .file decls on $(basename "$DEMO")), killswitch clean,"
echo "   DWARF lines all inside 1..$SRC_MAXLINE, -INCLUDE witness routes $INCROWS stmt(s) to file 2 with 0 bogus file-1 lines,"
echo "   .text byte-identical default-vs-killswitch (poison arm proves the check can fail), medium-invisible gate clean."
