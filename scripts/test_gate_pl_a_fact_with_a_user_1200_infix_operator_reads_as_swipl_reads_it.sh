#!/usr/bin/env bash
# test_gate_pl_a_fact_with_a_user_1200_infix_operator_reads_as_swipl_reads_it.sh -- a top-level term whose principal functor is a USER-DECLARED
# infix operator of priority 1200 (op(1200, xfx, Name), op(1200, xfy, Name)) is a FACT of that operator's functor, in both modes, as swipl reads
# it. The clause reader parsed a head at priority 1199 and took only :-, --> and => as 1200 continuations, so every other 1200 infix fact died
# with "expected . at end of fact": CHR's rule name `Name @ Head <=> Body` (library(chr) exports op(1200, xfx, @)) never reached the lowerer
# (CEO-1960, ARCH-PROLOG-CONSTRAINTS.md section 3). The probe is cut from swipl in THIS run (swipl_bin), never written by hand; the self-test
# feeds the same comparison a corrupted reference and requires it to be seen.
set -u
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot run here"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/pl1200.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/z.pl" <<'EOF'
:- op(1200, xfx, ===>).
:- op(1200, xfy, ====>).
a ===> b.
c ===> (d, e).
p ====> q ====> r.
x :- true.
y.
main :- forall(clause(===>(X, Y), true), (writeq(X-Y), nl)), forall(clause(====>(X, Y), true), (write_canonical(X-Y), nl)), x, y, write(done), nl.
:- initialization(main).
EOF
timeout -k 5 20 "$SW" -q -t halt "$W/z.pl" < /dev/null > "$W/z.ref" 2> "$W/ref.err"
[ "$(grep -c . "$W/z.ref")" -eq 4 ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the 4 probe lines ($(grep -c . "$W/z.ref") of them; $(head -c 160 "$W/ref.err"))"; exit 2; }
timeout -k 5 30 "$ROOT/scrip" "$W/z.pl" < /dev/null > "$W/m3.out" 2>&1; r3=$?
"$ROOT/scrip" --compile -o "$W/z.s" "$W/z.pl" < /dev/null > "$W/c.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not compile ($(head -c 160 "$W/c.err"))"; exit 2; }
gcc -no-pie -o "$W/z.bin" "$W/z.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/link.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not link ($(head -c 160 "$W/link.err"))"; exit 2; }
timeout -k 5 20 "$W/z.bin" < /dev/null > "$W/m4.out" 2>&1; r4=$?
sed '1s/.*/corrupted/' "$W/z.ref" > "$W/z.bad"
if cmp -s "$W/m3.out" "$W/z.bad"; then echo "GATE REFUSED(2) [$G]: the comparison accepted a corrupted reference -- the gate could not fail"; exit 2; fi
bad=0
for m in m3 m4; do rc=$([ $m = m3 ] && echo $r3 || echo $r4)
  if [ "$rc" -eq 0 ] && cmp -s "$W/$m.out" "$W/z.ref"; then echo "  ok  $m: rc=0, the 4 lines as swipl"; else echo "  RED $m: rc=$rc, output differs from swipl:"; diff "$W/z.ref" "$W/$m.out" | head -6; bad=1; fi
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a fact whose principal functor is a user infix operator of priority 1200 (xfx and xfy) reads as swipl reads it in both modes (self-test: a corrupted reference is seen)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a 1200 infix fact reads differently from swipl in one mode, or does not parse (tree SCRIP=$TREE)"; exit 1
