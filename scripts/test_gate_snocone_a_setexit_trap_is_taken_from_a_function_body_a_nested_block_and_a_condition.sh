#!/usr/bin/env bash
# test_gate_snocone_a_setexit_trap_is_taken_from_a_function_body_a_nested_block_and_a_condition.sh
#
# THE DEFECT (the ceo's rank-1 row snocone-a-setexit-trap-is-not-taken-from-a-function-body-or-an-if-or-while-condition,
# found rewriting infinite_snobol4.md's first section in Snocone, CEO-1437): under SETEXIT a Snocone error was not trapped
# where the same program put through scrip --transpile and run as SNOBOL4 is trapped, under SCRIP and under sbl -bf alike.
# Four causes, one per arm family below:
#   (1) a label inside a function body was never an LBL__ entry, so SETEXIT of it raised 187 and armed nothing
#       (src/lower/lower_snobol4.c registers each body label against the function's graph; src/driver/scrip.c emits its
#       alias inside the function's chain in both modes, one helper for main and for every function);
#   (2) an if / while / until / do-while / for condition fails straight into its else or loop exit, never through a
#       statement failure path, so it held no IR_SETEXIT_TEST (SCRIP bcd3e1765);
#   (3) a statement nested in a block of a structured statement, and a switch's case test, had no IR_SETEXIT_TEST either;
#   (4) a test inside a planned spine run sits above the statement base -- zd_k counted the test as a 16-byte push, and a
#       nested test sits over its enclosing statement's records -- so the trap entered a statement-level handler label with
#       rsp too deep; inside a function, whose frame is rsp-relative, the handler's return jumped through a wrong slot. The
#       test now drops to the statement base before the take sequence and restores its depth on the CONTINUE return.
# A Snocone goto CONTINUE / SCONTINUE / ABORT compiles to the deferred goto SNOBOL4 uses (it was a compile-time fatal).
# A block statement's test sits where its success and failure edges join, ahead of the next statement: on the failure edge
# alone it was reached only from non-test ops, so zd_plan gave it no run and the join cut walled the block there, leaving the
# rest of a loop body on legacy frame slots that a recursive call clobbered (witness lp: the outer loop stopped after the first
# recursion returned, where sbl and the control print 2y 1y 2y 1y).
#
# The expected lines are pinned AND confirmed against sbl -bf on the transpile at run time: a program sbl does not answer
# as pinned is a REFUSAL, never a green. Ten programs x two modes, and a FAIL-ONCE arm: under SCRIP_SETEXIT=0 (no trap
# is ever armed) witness a must read a divergence, so the comparison is shown able to say no.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent -- the pinned lines cannot be confirmed"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/a.sc" <<'SC'
function f(s) { &ERRLIMIT = 10; SETEXIT('f_err'); f = 'FAIL'; f = 'ok ' EVAL(s); return; f_err: f = 'ERROR ' &ERRTYPE; return; }
function g(s) r { &ERRLIMIT = 10; SETEXIT('g_err'); if (r = EVAL(s)) { g = 'ok ' r; return; } g = 'FAIL'; return; g_err: g = 'ERROR ' &ERRTYPE; return; }
OUTPUT = f('1 + 1');
OUTPUT = g('2 + 2');
OUTPUT = f("1 + 'a'");
OUTPUT = g("2 + 'b'");
SC
printf 'ok 2\nok 4\nERROR 2\nERROR 2\n' > "$D/a.want"
cat > "$D/b.sc" <<'SC'
a = 'a';
&ERRLIMIT = 10;
SETEXIT('h1');
if (x = 1 + a) { OUTPUT = 'if: ok'; } else { OUTPUT = 'if: fail'; }
goto n2;
h1: OUTPUT = 'if: trapped ' &ERRTYPE;
n2: SETEXIT('h2');
while (x = 2 + a) { OUTPUT = 'while: ok'; }
OUTPUT = 'while: fail';
goto n3;
h2: OUTPUT = 'while: trapped ' &ERRTYPE;
n3: OUTPUT = 'end';
SC
printf 'if: trapped 2\nwhile: trapped 2\nend\n' > "$D/b.want"
cat > "$D/nf.sc" <<'SC'
function g(s) r { &ERRLIMIT = 10; SETEXIT('g_err'); if (s) { r = EVAL(s); g = 'ok ' r; return; } g = 'FAIL'; return; g_err: g = 'ERROR ' &ERRTYPE; return; }
OUTPUT = g("2 + 'b'");
OUTPUT = 'after';
SC
printf 'ERROR 2\nafter\n' > "$D/nf.want"
cat > "$D/nt.sc" <<'SC'
&ERRLIMIT = 10; SETEXIT('g_err'); s = "2 + 'b'"; if (s) { r = EVAL(s); OUTPUT = 'ok ' r; } OUTPUT = 'FAIL'; goto e;
g_err: OUTPUT = 'ERROR ' &ERRTYPE;
e: OUTPUT = 'after';
SC
printf 'ERROR 2\nafter\n' > "$D/nt.want"
cat > "$D/ct.sc" <<'SC'
&ERRLIMIT = 10; SETEXIT('h');
i = 0;
while (LT(i, 3)) {
  i = i + 1;
  x = EVAL("1 + 'a'");
  OUTPUT = 'after eval ' i;
}
OUTPUT = 'end';
goto e;
h: OUTPUT = 'trap ' &ERRTYPE ' ' i; SETEXIT('h'); goto CONTINUE;
e: OUTPUT = 'done';
SC
printf 'trap 2 1\nafter eval 1\ntrap 2 2\nafter eval 2\ntrap 2 3\nafter eval 3\nend\ndone\n' > "$D/ct.want"
cat > "$D/cf.sc" <<'SC'
function f(n) i, x {
  &ERRLIMIT = 10; SETEXIT('h');
  i = 0;
  while (LT(i, n)) {
    i = i + 1;
    if (GT(i, 1)) { x = EVAL("1 + 'a'"); OUTPUT = 'after eval ' i; }
    else { OUTPUT = 'first ' i; }
  }
  f = 'end ' i;
  return;
  h: OUTPUT = 'trap ' &ERRTYPE ' ' i; SETEXIT('h'); goto CONTINUE;
}
OUTPUT = f(3);
OUTPUT = f(2);
OUTPUT = 'done';
SC
printf 'first 1\ntrap 2 2\nafter eval 2\ntrap 2 3\nafter eval 3\nend 3\nfirst 1\ntrap 2 2\nafter eval 2\nend 2\ndone\n' > "$D/cf.want"
cat > "$D/cn.sc" <<'SC'
function g(n) i, j, s {
  &ERRLIMIT = 20; SETEXIT('h');
  s = '';
  for (i = 1; LE(i, n); i = i + 1) {
    for (j = 1; LE(j, 2); j = j + 1) {
      if (EQ(REMDR(i + j, 2), 0)) { s = s EVAL(i " + 'z'"); }
      else { s = s (i * j) ','; }
    }
  }
  g = s;
  return;
  h: s = s 'E' &ERRTYPE ','; SETEXIT('h'); goto CONTINUE;
}
OUTPUT = g(3);
OUTPUT = 'done';
SC
printf 'E2,2,2,E2,E2,6,\ndone\n' > "$D/cn.want"
cat > "$D/sw.sc" <<'SC'
function g(s) { &ERRLIMIT = 10; SETEXIT('g_err'); switch (EVAL(s)) { case 1: g = 'one'; return; default: g = 'other'; return; } g_err: g = 'ERROR ' &ERRTYPE; return; }
OUTPUT = g('1');
OUTPUT = g('2');
OUTPUT = g("1 + 'a'");
OUTPUT = 'after';
SC
printf 'one\nother\nERROR 2\nafter\n' > "$D/sw.want"
cat > "$D/ei.sc" <<'SC'
function h(s, t) { &ERRLIMIT = 10; SETEXIT('h_err'); if (EVAL(s)) { h = 'first'; } else if (EVAL(t)) { h = 'second'; } else { h = 'neither'; } return; h_err: h = 'ERROR ' &ERRTYPE; return; }
OUTPUT = h('1', '2');
OUTPUT = h("DIFFER(1,1)", '2');
OUTPUT = h("DIFFER(1,1)", "2 + 'q'");
OUTPUT = 'after';
SC
printf 'first\nsecond\nERROR 2\nafter\n' > "$D/ei.want"
cat > "$D/lp.sc" <<'SC'
function F(n, i, t) {
    i = 0;
    while (i = LT(i, n) i + 1) { if ('AP' ? (POS(0) (SPAN('AP') | '') RPOS(0))) t = 'y'; else t = 'q'; OUTPUT = n t; F(n - 1); }
    return;
}
F(2);
OUTPUT = 'after';
SC
printf '2y\n1y\n2y\n1y\nafter\n' > "$D/lp.want"
P="a b nf nt ct cf cn sw ei lp"
for p in $P; do
    ( cd "$D" && timeout -k 5 30 "$B/scrip" --transpile "$p.sc" < /dev/null > "$p.sno" 2>/dev/null && timeout -k 5 30 "$SBL" -bf "$p.sno" < /dev/null > "$p.sbl" 2>/dev/null )
    cmp -s "$D/$p.want" "$D/$p.sbl" || refuse "sbl -bf does not answer $p.sc's transpile as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/$p.sbl")]"
done
red=0; n=0
for p in $P; do
    ( cd "$D" && timeout -k 5 30 "$B/scrip" "$p.sc" < /dev/null > "$p.m3" 2>/dev/null )
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile "$p.sc" < /dev/null > "$p.s" 2>/dev/null && gcc -no-pie "$p.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$p.bin" 2>/dev/null && timeout -k 5 30 "./$p.bin" < /dev/null > "$p.m4" 2>/dev/null )
    for m in m3 m4; do
        n=$((n + 1))
        if [ -f "$D/$p.$m" ] && cmp -s "$D/$p.want" "$D/$p.$m"; then echo "  ok   $p.sc $m"; else echo "  FAIL $p.sc $m: got [$(tr '\n' '|' 2>/dev/null < "$D/$p.$m")] want [$(tr '\n' '|' < "$D/$p.want")]"; red=$((red + 1)); fi
    done
done
( cd "$D" && SCRIP_SETEXIT=0 timeout -k 5 30 "$B/scrip" a.sc < /dev/null > a.off 2>/dev/null )
n=$((n + 1))
if cmp -s "$D/a.want" "$D/a.off"; then echo "  FAIL fail-once: with SCRIP_SETEXIT=0 witness a still reads as pinned -- the comparison cannot say no"; red=$((red + 1)); else echo "  ok   fail-once: with SCRIP_SETEXIT=0 witness a diverges [$(tr '\n' '|' < "$D/a.off")]"; fi
if [ $red -eq 0 ]; then echo "GATE PASS(0): a Snocone SETEXIT trap is taken from a function body, a nested block and a structured condition, and CONTINUE resumes inside them, as sbl -bf answers the transpile; $n arm(s)"; exit 0; fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
