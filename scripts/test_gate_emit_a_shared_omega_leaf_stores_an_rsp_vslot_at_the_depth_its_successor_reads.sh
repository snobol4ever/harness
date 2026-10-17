#!/usr/bin/env bash
# test_gate_emit_a_shared_omega_leaf_stores_an_rsp_vslot_at_the_depth_its_successor_reads.sh
#
# THE DEFECT (row emit-an-rsp-relative-vslot-assigned-in-a-box-that-two-binop-test-omega-edges-reach-at-different-spine-depths-
# is-stored-at-the-wrong-depth, hq_pascal 2026-09-26, SCRIP aa3adedf8's message; met again by the coo 2026-10-02 as a cross-
# language red of the cto's f8acc813e): two tests in one zd run whose omega edges reach ONE shared leaf (a value context's
# false leaf: LIT 0 -> ASSIGN __tmp -> VAR __tmp) used to have that leaf's run seeded at the zout of the FIRST such test in
# node order. When the first test is the shallower one (a call before the test of its result), the leaf ran shallow, stored
# the rsp-relative temporary there, and only then pushed (add rsp, -N) to meet its successor's depth -- so the successor
# read the TRUE leaf's cell. Pascal's write(eoln(input)) after a read at end of line printed the previous iteration's
# true; fpc -Miso prints false. f8acc813e made IR_CALL an omega test, which turned eoln's call into that first test.
# THE CURE (emit.cpp zd_omega_seed): the shared omega head is seeded at the DEEPEST zout among the same-run tests that reach
# it, the depth the true arm starts at -- so any reconciliation is a push on an omega edge, before the leaf stores anything,
# and the leaf stores at the depth its successor reads.
#
# Two programs x two modes, their expected lines cut from fpc 3.2.2 -Miso on 2026-10-02 (hermetic: the oracle is never
# called). rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
printf 'ab\nc\n' > "$D/in.txt"
cat > "$D/eolc.pas" <<'PAS'
program eolc;
var ch: char; n: integer;
begin n := 0;
  while not eof(input) do begin read(input, ch); n := n + 1; write(ord(ch):4); if not eof(input) then write(eoln(input):6) end;
  writeln; writeln(n)
end.
PAS
cat > "$D/eolc.want" <<'REF'
  97 false  98  true  32 false  99  true  32
          5
REF
cat > "$D/eolf.pas" <<'PAS'
program eolf;
var ch: char;
begin
  while not eof(input) do begin read(input, ch); if not eof(input) then writeln(ord(ch):4, eoln(input):6) end
end.
PAS
cat > "$D/eolf.want" <<'REF'
  97 false
  98  true
  32 false
  99  true
REF
red=0; n=0
for p in eolc eolf; do
    ( cd "$D" && timeout -k 5 30 "$B/scrip" "$p.pas" < in.txt > "$p.m3" 2>/dev/null )
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile "$p.pas" < /dev/null > "$p.s" 2>/dev/null && gcc -no-pie "$p.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$p.bin" 2>/dev/null ) || refuse "$p: mode 4 did not build"
    ( cd "$D" && timeout -k 5 30 "./$p.bin" < in.txt > "$p.m4" 2>/dev/null )
    for m in m3 m4; do
        n=$((n + 1))
        if cmp -s "$D/$p.want" "$D/$p.$m"; then echo "  ok   $p $m"; else echo "  FAIL $p $m"; diff "$D/$p.want" "$D/$p.$m" | head -6 | sed 's/^/       /'; red=$((red + 1)); fi
    done
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): a shared omega leaf stores its temporary at the depth its successor reads, $n arm(s)"; exit 0; fi
echo "GATE FAIL(1): $red of $n arm(s) read the other leaf's cell"; exit 1
