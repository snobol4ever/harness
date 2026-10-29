#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
NAME=icn_global_names_are_not_governed_by_snobol4_keywords
ICN=/home/resources/icon-master/bin
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -x "$ICN/icont" ] && [ -x "$ICN/iconx" ] || refuse "Arizona icont/iconx absent at $ICN -- reach an oracle by ABSOLUTE PATH, never command -v"
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
GRADED=0; FAIL=0
grade() { GRADED=$((GRADED+1)); if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  ⛔ FAIL $1: want [$2] got [$3]"; FAIL=$((FAIL+1)); fi; }
printf 'global PI, TRACE, ANCHOR, OUTPUT, gp\nprocedure main()\n  PI := 10;\n  TRACE := "t";\n  ANCHOR := 3;\n  OUTPUT := 4;\n  gp := 5;\n  write(image(PI), " ", image(TRACE), " ", image(ANCHOR), " ", image(OUTPUT), " ", image(gp));\nend\n' > "$TD/g.icn"
( cd "$TD" && "$ICN/icont" -s g.icn >/dev/null 2>&1 && timeout -k 5 30 "$ICN/iconx" g > g.ref 2>&1 ) || refuse "iconx could not run the witness -- cannot measure"
WANT="$(cat "$TD/g.ref")"
[ -n "$WANT" ] || refuse "oracle produced no output -- cannot measure"
( cd "$TD" && timeout -k 5 30 "$SCRIP" g.icn </dev/null > g.m3 2>&1 ) || true
grade "icon m3: globals named PI TRACE ANCHOR OUTPUT read back their own values" "$WANT" "$(cat "$TD/g.m3")"
( cd "$TD" && timeout -k 5 60 "$SCRIP" --compile --out=g.s g.icn </dev/null >/dev/null 2>&1 && gcc -no-pie g.s -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread -o g.m4b >/dev/null 2>&1 && timeout -k 5 30 ./g.m4b </dev/null > g.m4 2>&1 ) || true
grade "icon m4: same, through the compiled path" "$WANT" "$(cat "$TD/g.m4" 2>/dev/null)"
printf '\tOUTPUT = "hello"\nEND\n' > "$TD/s1.sno"
( cd "$TD" && timeout -k 5 30 "$SCRIP" s1.sno </dev/null > s1.out 2>&1 ) || true
grade "snobol4 CONTROL: OUTPUT still reaches the terminal (the keyword set still governs SNOBOL4)" "hello" "$(cat "$TD/s1.out")"
printf '\tTRIM = 5\n\tORDINARY = 7\n\tOUTPUT = TRIM ORDINARY\nEND\n' > "$TD/s2.sno"
( cd "$TD" && timeout -k 5 30 "$SCRIP" s2.sno </dev/null > s2.out 2>&1 ) || true
grade "snobol4 CONTROL: a variable named TRIM is still refused a GVA slot and reads correctly" "57" "$(cat "$TD/s2.out")"
echo "$NAME: graded=$GRADED fails=$FAIL"
[ "$FAIL" = 0 ] || { echo "⛔ GATE RED [$NAME]: $FAIL of $GRADED arm(s) failed"; exit 1; }
echo "GATE PASS(0) [$NAME]: $GRADED arm(s) -- Icon identifiers are not governed by SNOBOL4's keyword set, and SNOBOL4's own refusal is intact"
