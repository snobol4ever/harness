#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_by_name_paths_find_once_dollar_apply_eval.sh -- THREE RUNTIME PATHS REACHED BY NAME STOP LOOKING THINGS UP TWICE (ceo
# 2026-09-25, CEO-1263; Lon, in-chat to the ceo: "Find where our true compiler is slower than an threaded-code interpreter?"; notebook
# section 21: SCRIP reads 2-4x SPITBOL where the compiler resolves an operation and loses only in paths reached by name).
#   $name: SNO$NAME takes its row in the direct builtin table (it carried the leaf bit, so the asm bid entry looked it up and missed
#   into the C dispatcher); a string operand is looked up by its own bytes and length, hashed a word at a time, with no C string built;
#   and a plain variable comes back as its own cell, so the read and the write that follow skip NV_GET and NV_SET -- under the same
#   conditions NV_SET_fn stores through its cell (no monitor, no trace, not INPUT/OUTPUT/TERMINAL, not a protected pattern name).
#   APPLY: the procedure is found once (it was found by rt_proc_is_registered, again by rt_call_open_by_name and a third time by name in
#   the epilogue); the epilogue of every idx-carrying land takes the called record itself.
#   EVAL: a string whose first non-blank character is a letter skips the three number parses in front of the compiled-expression cache
#   (which also cures EVAL('INF'): strtod's inf spelling made it a real where SPITBOL evaluates the variable INF).
# ARMS: (1) the witness -- $ as a read, a write, a capture target (. and $), a table key, inside a DEFINE'd function, over an INPUT- and an
# OUTPUT-associated variable, a traced variable, a protected pattern name and a variable first created through $; APPLY of a DEFINE'd
# function and of a builtin, and of an unknown name (error 22 in both engines); EVAL of expressions, of 'INF' and 'N', of numbers -- answers the oracle in m3 and m4;
# (2) a dynamically created variable written through $ under SCRIP_GC_STRESS=1 answers the oracle in both modes (its cell lives in the
# collected heap and the name must be forwarded across a collection); (3) gdb counts over 2,000 $ reads and writes: rt_sno_indirect_name
# (the old string path) at most 20 and c_rt_call_bid_sn4 (the C tail) at most 20; (4) rt_proc_find over 2,000 APPLY calls at most 2,100;
# (5) strtod over 1,000 EVAL('X + 1') at most 20.
# FAIL_ONCE (recorded): the pre-cure runtime at ddfa57a55 read arm 3 rt_sno_indirect_name 2,000 and c_rt_call_bid_sn4 2,000, arm 4
# 6,005 (three lookups per APPLY), arm 5 2,000 (two per EVAL), and arm 1 lost the EVAL line at EVAL('INF'); this tree reads 0, 0, 2,005, 0.
# ⛔ ARM 1 RUNS UNDER --stlimit (cto 2026-10-02, ceo CEO-1409): its witness TRACEs X, and a trace is the instrumentation
# switch's (Lon 2026-09-24, CEO-1243: "The &STLIMIT feature with trace instrumentation should be controlled by a command-line
# switch."; the correctness graders turn it on because the oracle always has it). Without it a default build carries no
# statement number, so the by-name write's trace banner read ****0 where sbl reads ****28; the same rule Lon applied to
# &LASTNO on 2026-10-02 ("Grade under --stlimit"). The gc and counting witnesses stay default builds, so arms 2-5 measure
# the by-name paths exactly as before.
# EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle, gdb, a breakpoint gdb could not resolve, or the build missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
command -v gdb >/dev/null 2>&1 || { echo "REFUSED(2): gdb missing -- arms 3-5 are breakpoint hit counts"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
printf 'line one\nline two\nline three\n' > "$W/rd.txt"
cat > "$W/w.sno" <<'SNO'
        X = 5
        H = 'X'
        $H = $H + 1
        OUTPUT = X ' ' $H
        V = 'W1'
        'hello world' ? BREAK(' ') . $V
        OUTPUT = W1
        'abc' ? LEN(2) $ $V
        OUTPUT = W1
        DEFINE('F(N)LOC')                               :(FEND)
F       LOC = 'GLOB'
        $LOC = N * 2
        F = $LOC                                        :(RETURN)
FEND    OUTPUT = F(21) ' ' GLOB
        T = TABLE()
        K = 'KEY'
        KEY = 'kv'
        T[$K] = 'stored'
        OUTPUT = T['kv']
        INPUT(.RD, 5, 'rd.txt')
        R = 'RD'
        OUTPUT = $R
        OUTPUT = $R
        G = 'OUTPUT'
        $G = 'to OUTPUT through $'
        TRACE('X', 'VALUE')
        &TRACE = 100
        $H = 7
        &TRACE = 0
        STOPTR('X', 'VALUE')
        A = 'ARB'
        OUTPUT = DATATYPE($A)
        NV = 'NEW' 'VAR'
        $NV = 'fresh'
        OUTPUT = NEWVAR
        DEFINE('ADD1(V)')                               :(ADD1_END)
ADD1    ADD1 = V + 1                                    :(RETURN)
ADD1_END
        FN = 'ADD1'
        OUTPUT = APPLY(FN, 41) ' ' APPLY('SIZE', 'abcd')
        INF = 'var-inf'
        N = 'var-n'
        OUTPUT = EVAL('X + 1') ' ' EVAL('INF') ' ' EVAL('N') ' ' EVAL('-3.5') ' ' EVAL('+7') ' ' EVAL('1e3') ' ' EVAL(' X')
END
SNO
cat > "$W/gc.sno" <<'SNO'
        N = 'DYN' 'VAR'
        $N = 'x'
        I = 0
LOOP    I = I + 1
        $N = $N DUPL('y', 37) I
        $N = GT(SIZE($N), 3000) 'reset' I
        LT(I, 3000)                                     :S(LOOP)
        OUTPUT = SIZE($N) ' ' SIZE(DYNVAR)
END
SNO
cat > "$W/cnt.sno" <<'SNO'
        TARGET = 0
        H = 'TARGET'
        I = 0
L1      $H = $H + 1
        I = LT(I, 999) I + 1                            :S(L1)
        DEFINE('ADD1(V)')                               :(ADD1_END)
ADD1    ADD1 = V + 1                                    :(RETURN)
ADD1_END
        FN = 'ADD1'
        J = 0
L2      S = S + APPLY(FN, J)
        J = LT(J, 1999) J + 1                           :S(L2)
        X = 10
        K = 0
L3      R = EVAL('X + 1')
        K = LT(K, 999) K + 1                            :S(L3)
        OUTPUT = TARGET ' ' S ' ' R
END
SNO
printf "        N = 'NOSUCH' 'FN'\n        OUTPUT = APPLY(N, 1)\nEND\n" > "$W/u.sno"
red=0
for p in w gc; do ( cd "$W" && "$SBL" $(sbl_lang_flags) $p.sno < /dev/null > $p.ref 2>/dev/null ); [ -s "$W/$p.ref" ] || { echo "REFUSED(2): the oracle printed nothing for $p.sno"; exit 2; }
  fl=""; [ $p = w ] && fl="--stlimit"
  ( cd "$W" && "$ROOT/scrip" --compile $fl -o $p.s $p.sno < /dev/null > /dev/null 2>&1 && gcc $p.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o $p.bin 2>/dev/null ) || { echo "REFUSED(2): $p.sno did not build in mode 4"; exit 2; }; done
for m in m3 m4; do
  if [ $m = m3 ]; then o=$( cd "$W" && timeout -k 5 60 "$ROOT/scrip" --stlimit w.sno < /dev/null 2>/dev/null ); else o=$( cd "$W" && timeout -k 5 60 ./w.bin < /dev/null 2>/dev/null ); fi
  [ "$o" = "$(cat "$W/w.ref")" ] && echo "ok  (1) $m: the \$, APPLY and EVAL witness answers the oracle" || { echo "RED (1) $m differs from the oracle: $(diff <(echo "$o") "$W/w.ref" | head -4 | tr '\n' ' ')"; red=1; }
  if [ $m = m3 ]; then o=$( cd "$W" && SCRIP_GC_STRESS=1 timeout -k 5 120 "$ROOT/scrip" gc.sno < /dev/null 2>/dev/null ); else o=$( cd "$W" && SCRIP_GC_STRESS=1 timeout -k 5 120 ./gc.bin < /dev/null 2>/dev/null ); fi
  [ "$o" = "$(cat "$W/gc.ref")" ] && echo "ok  (2) $m: a variable created through \$ answers the oracle across collections at every opportunity ($o)" || { echo "RED (2) $m under SCRIP_GC_STRESS=1: [$o] against [$(cat "$W/gc.ref")]"; red=1; }
done
uo="$( cd "$W" && "$SBL" $(sbl_lang_flags) u.sno < /dev/null 2>/dev/null )"; u3="$( cd "$W" && timeout -k 5 60 "$ROOT/scrip" u.sno < /dev/null 2>&1 >/dev/null )"
( cd "$W" && "$ROOT/scrip" --compile -o u.s u.sno < /dev/null > /dev/null 2>&1 && gcc u.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o u.bin 2>/dev/null ) || { echo "REFUSED(2): u.sno did not build in mode 4"; exit 2; }
u4="$( cd "$W" && timeout -k 5 60 ./u.bin < /dev/null 2>&1 >/dev/null )"
case "$uo" in *"ERROR 022"*) ;; *) echo "REFUSED(2): the oracle did not raise ERROR 022 for APPLY of an unknown name: [$(echo "$uo" | head -3 | tr '\n' ' ')]"; exit 2;; esac
for m in m3 m4; do [ $m = m3 ] && ue="$u3" || ue="$u4"
  case "$ue" in *"error 22:"*) echo "ok  (1) $m: APPLY of an unknown name raises error 22, as the oracle's ERROR 022";; *) echo "RED (1) $m: APPLY of an unknown name did not raise error 22: [$(echo "$ue" | head -2 | tr '\n' ' ')]"; red=1;; esac; done
( cd "$W" && "$ROOT/scrip" --compile -o cnt.s cnt.sno < /dev/null > /dev/null 2>&1 && gcc cnt.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o cnt.bin 2>/dev/null ) || { echo "REFUSED(2): the counting witness did not build"; exit 2; }
cw="$( cd "$W" && "$SBL" $(sbl_lang_flags) cnt.sno < /dev/null 2>/dev/null )"; co="$( cd "$W" && timeout -k 5 60 ./cnt.bin < /dev/null 2>/dev/null )"
[ "$cw" = "$co" ] || { echo "RED (3-5) the counting witness itself does not answer the oracle: [$co] against [$cw]"; red=1; }
hits() { local o; o="$( cd "$W" && timeout -k 5 600 gdb -q -batch -ex 'set breakpoint pending on' -ex "break $1" -ex 'ignore 1 100000000' -ex 'run < /dev/null > /dev/null 2>&1' -ex 'info breakpoints' ./cnt.bin 2>&1 )"
  printf '%s\n' "$o" | grep -q '^1 *breakpoint *keep *y *0x' || { echo "REFUSED(2): gdb did not resolve a breakpoint on $1 -- a hit count of an unset breakpoint is no count" >&2; echo X; return; }
  printf '%s\n' "$o" | grep -o 'already hit [0-9]*' | grep -o '[0-9]*$' | head -1 | grep . || echo 0; }
a=$(hits rt_sno_indirect_name); b=$(hits c_rt_call_bid_sn4); c=$(hits rt_proc_find); d=$(hits strtod)
case "$a$b$c$d" in *X*) exit 2;; esac
[ "$a" -le 20 ] && [ "$b" -le 20 ] && echo "ok  (3) over 2,000 \$ reads and writes: rt_sno_indirect_name hit $a, c_rt_call_bid_sn4 hit $b (the direct table and the length-bounded lookup)" || { echo "RED (3) over 2,000 \$ reads and writes: rt_sno_indirect_name hit $a, c_rt_call_bid_sn4 hit $b (bound 20 each)"; red=1; }
[ "$c" -ge 2000 ] && [ "$c" -le 2100 ] && echo "ok  (4) rt_proc_find hit $c over 2,000 APPLY calls: one lookup per call" || { echo "RED (4) rt_proc_find hit $c over 2,000 APPLY calls (want 2,000..2,100: one lookup per call)"; red=1; }
[ "$d" -le 20 ] && echo "ok  (5) strtod hit $d over 1,000 EVAL('X + 1'): an expression string skips the number parses" || { echo "RED (5) strtod hit $d over 1,000 EVAL('X + 1') (bound 20)"; red=1; }
[ "$red" -eq 0 ] && { echo "GATE OK: \$name, APPLY and EVAL each look their target up once"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
