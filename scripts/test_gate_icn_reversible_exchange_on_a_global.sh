#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
NAME=icn_reversible_exchange_on_a_global
ICN=/home/resources/icon-master/bin
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -x "$ICN/icont" ] && [ -x "$ICN/iconx" ] || refuse "Arizona icont/iconx absent at $ICN -- reach an oracle by ABSOLUTE PATH, never command -v"
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
GRADED=0; FAIL=0
grade() { GRADED=$((GRADED+1)); if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  ⛔ FAIL $1: want [$2] got [$3]"; FAIL=$((FAIL+1)); fi; }
cat > "$TD/g.icn" <<'ICNEOF'
global ga, gb
procedure main();
    local y;
    ga := 1; y := 2;
    write("global<->local: ", image(ga <-> y) | "none");
    write("  ga=", image(ga), " y=", image(y));
    ga := 1; gb := 2;
    write("global<->global: ", image(ga <-> gb) | "none");
    write("  ga=", image(ga), " gb=", image(gb));
    every 1 to 2 do { if (ga <-> gb) & &fail then write("unreachable"); write("  recede: ga=", image(ga), " gb=", image(gb)); };
    write("reached the end", "");
end
ICNEOF
( cd "$TD" && "$ICN/icont" -s g.icn >/dev/null 2>&1 && timeout -k 5 30 "$ICN/iconx" g > g.ref 2>&1 ) || refuse "iconx could not run the witness -- cannot measure"
WANT="$(cat "$TD/g.ref")"
[ -n "$WANT" ] || refuse "oracle produced no output -- cannot measure"
case "$WANT" in *"reached the end"*) : ;; *) refuse "oracle output does not reach the end -- the witness itself is broken, not SCRIP" ;; esac
( cd "$TD" && timeout -k 5 30 "$SCRIP" g.icn </dev/null > g.m3 2>&1 ) || true
grade "m3: <-> on a global (was an rc=134 TE-4 compile abort, so nothing ran at all)" "$WANT" "$(cat "$TD/g.m3")"
( cd "$TD" && timeout -k 5 60 "$SCRIP" --compile -o g.s g.icn </dev/null >/dev/null 2>&1 && gcc -no-pie g.s -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread -o g.m4b >/dev/null 2>&1 && timeout -k 5 30 ./g.m4b </dev/null > g.m4 2>&1 ) || true
grade "m4: same, through the compiled path" "$WANT" "$(cat "$TD/g.m4" 2>/dev/null)"
cat > "$TD/l.icn" <<'ICNEOF'
procedure main();
    local a, b;
    a := 1; b := 2;
    write(image(a <-> b) | "none");
    write("a=", image(a), " b=", image(b));
end
ICNEOF
( cd "$TD" && "$ICN/icont" -s l.icn >/dev/null 2>&1 && timeout -k 5 30 "$ICN/iconx" l > l.ref 2>&1 ) || refuse "iconx could not run the locals control -- cannot measure"
( cd "$TD" && timeout -k 5 30 "$SCRIP" l.icn </dev/null > l.m3 2>&1 ) || true
grade "CONTROL: <-> on LOCALS stays green (the cure must not be paid for by the local path)" "$(cat "$TD/l.ref")" "$(cat "$TD/l.m3")"
echo "$NAME: graded=$GRADED fails=$FAIL"
[ "$FAIL" = 0 ] || { echo "⛔ GATE RED [$NAME]: $FAIL of $GRADED arm(s) failed"; exit 1; }
echo "GATE PASS(0) [$NAME]: $GRADED arm(s) -- global<->global parks a cell pointer across a second NV_PTR_fn lookup and the &fail arm drives the recede path"
