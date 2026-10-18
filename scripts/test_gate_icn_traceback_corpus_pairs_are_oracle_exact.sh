#!/usr/bin/env bash
# ⭐⭐ GATE: THE TWO ON-DISK TRACEBACK WITNESSES MATCH THEIR ORACLE-CUT REFS, BYTE FOR BYTE, IN BOTH MODES.
# Clause 1 of FINDING-2026-09-10-ceo-a-generator-records-no-activation-so-three-symptoms-in-three-lanes-are-
# one-root.md, made mechanical (ceo CEO-541: "make that generator witness permanent and gradable AS clause 1
# of the finding"). The cure is the cto's `3e68226ea` -- the flat_gen prologue now records an activation, as
# a record-only tap so the trace lines stay exactly as they were.
# ⛔ WHY THIS EXISTS BESIDE test_gate_icn_generator_records_its_activation.sh RATHER THAN INSTEAD OF IT, since
# a duplicate gate is worse than none. That gate is the cto's and grades the MECHANISM through witnesses it
# writes into a scratch dir at run time, against expectations typed into the gate. This one grades the two
# PERMANENT corpus pairs against refs CUT FROM icont+iconx, which is a different and stronger kind of
# evidence and covers something no inline gate can: the corpus pairs themselves, which nothing globs and
# nothing else runs, so they would bit-rot ungraded exactly when someone needs them. ⭐ I checked the
# overlap rather than assuming it: the cto's hand-typed `g3.want` was re-cut from live iconx here and came
# back BYTE-IDENTICAL, so their expectations are sound and this gate is not a correction of them.
# ⛔ THE HISTORY THAT MAKES THE SECOND PAIR LOAD-BEARING, and it is the whole reason this gate has a control
# arm. The finding's ORIGINAL clause 1 named an ordinary three-frame witness (main -> f -> g, 1/0 in g).
# That witness was CURED BY A NEIGHBOUR's work on the ordinary call path within the hour, so the clause went
# green while the generator gap it was written for stood untouched -- an open row grading as done, on the
# wrong evidence. The generator pair replaced it. Keeping the ordinary pair as the CONTROL is what stops the
# reverse mistake: a change that made the record tap fire for everything, or that disturbed the ordinary
# prologue, is invisible to the generator arm alone and shows up here.
# ARMS: (1)(2) generator pair, m3 and m4, byte-equal to its oracle-cut ref
#       (3) the generator frame line is PRESENT BY NAME in both mode outputs -- a probe asserts its named
#           witness, never a positional diff count (RULES.md)
#       (4)(5) CONTROL: ordinary-call pair, m3 and m4, byte-equal to its ref -- the ordinary path still
#           records every frame after the generator cure
#       (6) ANTI-TAMPER SELF-CHECK: each ref itself still carries the frame line it exists to pin, so
#           "fixing" a red by blanking a ref REFUSES rc=2 instead of passing
# ⛔ REFUSES rc=2 (never green) when it cannot measure: no scrip, no gcc, or either corpus pair missing.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; RT_DIR="${RT_DIR:-$ROOT/out}"
CORPUS="${CORPUS:-$S4E/corpus/tests/icon}"
GEN=a_generator_frame_appears_in_the_traceback_like_an_ordinary_call
ORD=an_ordinary_call_chain_prints_every_frame_in_the_traceback
refuse(){ echo "⛔ REFUSE(2): $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip at $SCRIP"
command -v gcc >/dev/null || refuse "no gcc, so mode 4 cannot be graded"
for n in "$GEN" "$ORD"; do
    [ -f "$CORPUS/$n.icn" ] || refuse "witness missing: $CORPUS/$n.icn"
    [ -f "$CORPUS/$n.ref" ] || refuse "ref missing: $CORPUS/$n.ref"
done
T=$(mktemp -d) || refuse "mktemp failed"; trap 'rm -rf "$T"' EXIT
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
# Run one witness in BOTH modes from a scratch dir holding only its own source. ⛔ The program's own file
# NAME is in every line of its expected output, so it must be run under that exact basename and never under
# a path -- this is hq_V's name-echoing class, and it is why both pairs are loose-KEEP in the corpus.
run_pair(){
    # ⛔ SEPARATE `local` STATEMENTS, NOT ONE. `local n="$1" o3="$T/$n.m3"` expands EVERY argument before the
    # builtin assigns any of them, so `$n` there is whatever `n` held in the CALLER's scope -- and the ref
    # self-check above leaves a global `n` behind from its `for n in ...` loop. The first call wrote its
    # output under the OTHER witness's name and the second call read it back, which cost arm (1) a
    # "No such file" and would have let a wrong-witness comparison pass unnoticed on a luckier day.
    local n="$1"
    local o3="$T/$n.m3"
    local o4="$T/$n.m4"
    cp "$CORPUS/$n.icn" "$T/$n.icn" || return 1
    ( cd "$T" && timeout -k 5 30 "$SCRIP" --run "$n.icn" </dev/null >"$o3" 2>&1 )
    # ⛔⭐ THE BUILD'S EXIT STATUS AND THE PROGRAM'S ARE TWO DIFFERENT QUESTIONS, AND CHAINING THEM ATE A
    # GREEN RESULT. Both witnesses END IN A RUNTIME ERROR by design -- that IS their expected output -- so
    # the binary exits 1 every time it works. Written as one `&& ... && timeout ./bin >"$o4"` chain with a
    # `|| : > "$o4"` fallback, the fallback fired on the PROGRAM's honest nonzero exit and TRUNCATED the
    # output that had just been captured correctly, so a perfect m4 run read as an empty one. Same class
    # the jcon suite already records ("a nonzero rc is not a failure in this suite"), met from the other
    # side: here the rc came from the thing under test, and the harness threw its own evidence away.
    if ( cd "$T" && timeout -k 5 60 "$SCRIP" --compile --target=x86 "$n.icn" </dev/null >"$n.s" 2>/dev/null \
            && as "$n.s" -o "$n.o" 2>/dev/null \
            && gcc -no-pie "$n.o" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$n.bin" 2>/dev/null ); then
        ( cd "$T" && timeout -k 5 30 "./$n.bin" </dev/null >"$o4" 2>&1 ); :
    else
        : > "$o4"   # the BUILD failed -- an empty m4 output is then the honest reading, and arm (2) says so
    fi
}
echo "=== gate: the two traceback corpus pairs are oracle-exact in both modes ==="
# (6) FIRST, because every other arm is meaningless if the refs no longer pin what they were cut to pin.
for _rn in "$GEN" "$ORD"; do
    grep -q '^g() from line 11 in '"$_rn"'\.icn$' "$CORPUS/$_rn.ref" \
      || refuse "$_rn.ref no longer carries its own 'g() from line 11' frame line -- a ref cannot be edited to make this gate green"
done
ck ok "(6) SELF-CHECK: both refs still carry the frame line they exist to pin -- blanking a ref refuses, never passes"
run_pair "$GEN"
for _f in "$T/$GEN.m3" "$T/$GEN.m4"; do python3 "$HERE/util_render_error_voice.py" icon < "$_f" > "$_f.rendered" && mv "$_f.rendered" "$_f"; done
diff -q "$T/$GEN.m3" "$CORPUS/$GEN.ref" >/dev/null 2>&1 \
  && ck ok "(1) generator pair, m3: byte-equal to its icont+iconx ref" \
  || ck no "(1) generator pair m3 differs: $(diff "$T/$GEN.m3" "$CORPUS/$GEN.ref" | head -3 | tr '\n' ' ')"
diff -q "$T/$GEN.m4" "$CORPUS/$GEN.ref" >/dev/null 2>&1 \
  && ck ok "(2) generator pair, m4: byte-equal to its icont+iconx ref" \
  || ck no "(2) generator pair m4 differs: $(diff "$T/$GEN.m4" "$CORPUS/$GEN.ref" | head -3 | tr '\n' ' ')"
# ⛔ `$(grep -c ... || echo 0)` yields "0\n0" when there is no match: grep -c PRINTS 0 and THEN exits 1, so
# the fallback appends a second zero and every numeric test downstream dies with "integer expression expected".
# grep -c already answers for the empty case; the only thing needing a guard is a missing file.
g3=0; [ -f "$T/$GEN.m3" ] && g3=$(grep -c '^g() from line 11 in '"$GEN"'\.icn$' "$T/$GEN.m3")
g4=0; [ -f "$T/$GEN.m4" ] && g4=$(grep -c '^g() from line 11 in '"$GEN"'\.icn$' "$T/$GEN.m4")
[ "$g3" -eq 1 ] && [ "$g4" -eq 1 ] \
  && ck ok "(3) THE GENERATOR'S OWN FRAME is present by name in both modes -- the line whose absence was the defect" \
  || ck no "(3) the generator frame line is missing (m3 count=$g3, m4 count=$g4) -- this is the defect itself, not a formatting drift"
run_pair "$ORD"
for _f in "$T/$ORD.m3" "$T/$ORD.m4"; do python3 "$HERE/util_render_error_voice.py" icon < "$_f" > "$_f.rendered" && mv "$_f.rendered" "$_f"; done
diff -q "$T/$ORD.m3" "$CORPUS/$ORD.ref" >/dev/null 2>&1 \
  && ck ok "(4) CONTROL, ordinary-call pair, m3: the non-generator path still records every frame" \
  || ck no "(4) CONTROL m3 differs -- the generator cure disturbed the ORDINARY prologue: $(diff "$T/$ORD.m3" "$CORPUS/$ORD.ref" | head -3 | tr '\n' ' ')"
diff -q "$T/$ORD.m4" "$CORPUS/$ORD.ref" >/dev/null 2>&1 \
  && ck ok "(5) CONTROL, ordinary-call pair, m4: the non-generator path still records every frame" \
  || ck no "(5) CONTROL m4 differs -- the generator cure disturbed the ORDINARY prologue: $(diff "$T/$ORD.m4" "$CORPUS/$ORD.ref" | head -3 | tr '\n' ' ')"
echo "---"
if [ "$fails" -eq 0 ]; then printf '✅ GATE PASS: %d/%d arms — 2 corpus pairs x 2 modes, refs cut from icont+iconx (Icon v9.5.25a)\n' "$checks" "$checks"; exit 0
else printf '⛔ GATE FAIL: %d of %d arms red\n' "$fails" "$checks"; exit 1; fi
