#!/usr/bin/env bash
# test_gate_monitor_grades_the_output_event.sh -- THE OUTPUT EVENT (coo 2026-09-25, row instruments-the-monitor-grades-no-output-event-so-
# a-wrong-value-written-without-an-assignment-reads-agree; ceo CEO-1272 on hq_icon's measurement). The contract graded STMT, VALUE, CALL,
# BIND and RETURN, so a wrong value written straight to standard output -- write(f(x)), OUTPUT = f(X), writeln(g) -- was never an event,
# and both sides agreed event for event over a wrong answer. A participant now sends the bytes it writes to stdout as MWK_OUTPUT records
# and says OUTPUT hello before its first statement; the controller absorbs the records into one byte stream per participant and requires
# the streams to agree, byte for byte, up to the shorter one at every compared step and wholly at the end -- only when every participant
# said hello (THE TWO SIDES LAND IN ORDER: the oracle fork first, then the SCRIP plug; MONITOR-BINARY-DESIGN.md, the OUTPUT paragraph).
# HERMETIC ARMS (two scripted participants on FIFOs, the real controller between them): (1) the same bytes AGREE with OUTPUT=graded;
# (2) the same bytes cut into different pieces AGREE -- chunking is no divergence; (3) one differing byte under identical paired events
# DIVERGEs as OUTPUT, naming the byte; (4) a stream left longer at END DIVERGEs; (5) a participant that never said hello leaves output
# UNGRADED, named, and differing bytes cannot DIVERGE through it. LIVE ARMS: (6) the instrumented Icon oracle icx says hello and sends the
# bytes its write() puts on stdout; (7) the icx/scr pair on a witness whose only wrong value goes straight to write -- write(&version) --
# DIVERGEs at its OUTPUT, and write("same") AGREEs with output graded. Arm 7 needs SCRIP's Icon plug to speak OUTPUT; until it does, it
# REFUSES rc 2 naming the plug as owed, which is the order the ruling set, never a pass.
# ⛔ FAILED ONCE (measured at the landing): on the controller before the OUTPUT event, arms 3 and 4 read AGREE (the bytes were never
# compared) and arm 1 carries no OUTPUT=graded; on the icx fork before it, arm 6 finds no OUTPUT record.
# EXIT 0 every arm holds; 1 an arm is red; 2 REFUSED (a prerequisite is missing, or arm 7 waits on the SCRIP plug).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSED(2): cannot load lib_gate.sh"; exit 2; }; GATE_NAME=monitor_grades_the_output_event
gate_require_fresh "$ROOT" src "$ROOT/scrip" || exit 2
CTRL="$HERE/monitor/monitor_sync_bin.py"; [ -f "$CTRL" ] || { echo "REFUSED(2): $CTRL missing"; exit 2; }
S4A="${S4E_ASSETS:-/home/resources}"; ICON_MON="${ICON_MON_ROOT:-$S4A/icon-mon}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fails=0; checks=0; wait7=""
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
cat > "$T/fake.py" <<'PY'
import os, struct, sys
ready, go, script = sys.argv[1], sys.argv[2], sys.argv[3]
rfd = os.open(ready, os.O_WRONLY); gfd = os.open(go, os.O_RDONLY)
def emit(kind, nid, typ, val):
    os.write(rfd, struct.pack('<IIBI', kind, nid, typ, len(val)) + val)
    if kind != 4 and os.read(gfd, 1) == b'S':
        sys.exit(0)
for line in open(script).read().split('\n'):
    if not line: continue
    op, _, arg = line.partition(' ')
    if op == 'HELLO': emit(11, 0xfffffffe, 0, b'')
    elif op == 'LABEL': emit(5, 0xffffffff, 2, struct.pack('<q', int(arg)))
    elif op == 'OUT': emit(11, 0xffffffff, 1, arg.encode().decode('unicode_escape').encode('latin-1'))
    elif op == 'END': emit(4, 0xffffffff, 0, b'')
PY
pair() {  # pair <label> <script-a> <script-b> -- run the controller between two scripted participants; prints its stderr to $T/<label>.ctrl
  local L="$1"; mkfifo "$T/$L.a.r" "$T/$L.a.g" "$T/$L.b.r" "$T/$L.b.g"
  printf '%b' "$2" > "$T/$L.a.s"; printf '%b' "$3" > "$T/$L.b.s"
  timeout -k 5 60 python3 "$CTRL" "a:$T/$L.a.r:$T/$L.a.g" "b:$T/$L.b.r:$T/$L.b.g" > "$T/$L.ctrl" 2>&1 &
  local cp=$!
  timeout -k 5 60 python3 "$T/fake.py" "$T/$L.a.r" "$T/$L.a.g" "$T/$L.a.s" & local ap=$!
  timeout -k 5 60 python3 "$T/fake.py" "$T/$L.b.r" "$T/$L.b.g" "$T/$L.b.s" & local bp=$!
  wait $cp; local rc=$?; wait $ap $bp 2>/dev/null; return $rc
}
pair p1 'HELLO\nLABEL 1\nOUT hello\\n\nLABEL 2\nEND\n' 'HELLO\nLABEL 1\nOUT hello\\n\nLABEL 2\nEND\n'; r1=$?
[ "$r1" = 0 ] && grep -q 'VERDICT AGREE=3 DIVERGE=0 .*OUTPUT=graded (6 byte(s))' "$T/p1.ctrl" \
  && ck ok "(1) the same bytes AGREE, and the VERDICT line says OUTPUT=graded (6 bytes)" || ck no "(1) rc=$r1 $(grep -m1 VERDICT "$T/p1.ctrl" | cut -c1-200)"
pair p2 'HELLO\nLABEL 1\nOUT hel\nOUT lo\\n\nLABEL 2\nEND\n' 'HELLO\nLABEL 1\nOUT hello\\n\nLABEL 2\nEND\n'; r2=$?
[ "$r2" = 0 ] && grep -q 'OUTPUT=graded (6 byte(s))' "$T/p2.ctrl" \
  && ck ok "(2) the same bytes in different pieces AGREE -- two engines need not split a write alike" || ck no "(2) rc=$r2 $(grep -m1 'VERDICT\|DIVERGE' "$T/p2.ctrl" | cut -c1-200)"
pair p3 'HELLO\nLABEL 1\nOUT 42\\n\nLABEL 2\nEND\n' 'HELLO\nLABEL 1\nOUT 41\\n\nLABEL 2\nEND\n'; r3=$?
[ "$r3" = 1 ] && grep -q 'DIVERGE step 2 (OUTPUT).*differs at byte 1' "$T/p3.ctrl" \
  && ck ok "(3) one differing byte DIVERGEs as OUTPUT at the step after the write, naming byte 1, though every paired event agrees" || ck no "(3) rc=$r3 $(grep -m1 'DIVERGE\|VERDICT' "$T/p3.ctrl" | cut -c1-200)"
pair p4 'HELLO\nLABEL 1\nOUT x\\n\nEND\n' 'HELLO\nLABEL 1\nOUT x\\ny\\n\nEND\n'; r4=$?
[ "$r4" = 1 ] && grep -q 'DIVERGE step .* (OUTPUT).*differs at byte 2' "$T/p4.ctrl" \
  && ck ok "(4) a stream left longer at END DIVERGEs (byte 2: one side wrote a line the other never did)" || ck no "(4) rc=$r4 $(grep -m1 'DIVERGE\|VERDICT' "$T/p4.ctrl" | cut -c1-200)"
pair p5 'HELLO\nLABEL 1\nOUT 42\\n\nLABEL 2\nEND\n' 'LABEL 1\nOUT 41\\n\nLABEL 2\nEND\n'; r5=$?
[ "$r5" = 0 ] && grep -q 'OUTPUT=UNGRADED(b sent no OUTPUT hello' "$T/p5.ctrl" \
  && ck ok "(5) a participant without the hello leaves output UNGRADED, named -- differing bytes cannot DIVERGE through an unplugged side, and no AGREE claims them" || ck no "(5) rc=$r5 $(grep -m1 'VERDICT' "$T/p5.ctrl" | cut -c1-220)"

# ---- live: the instrumented Icon oracle
[ -x "$ICON_MON/bin/icont" ] && [ -x "$ICON_MON/bin/iconx" ] || { echo "⛔ REFUSED(2): no instrumented Icon fork at $ICON_MON (build it: bash ../harness/scripts/monitor/oracles/build_icon_mon.sh)"; exit 2; }
mkdir -p "$T/w"; printf 'procedure main();\n   x := 1;\n   write("hello ", x + 2);\nend\n' > "$T/w/hello.icn"
MONITOR_TRACE_LOG="$T/log6" ICON_MON_ROOT="$ICON_MON" SCRIP_SNO_STMTKW=1 timeout -k 5 300 bash "$HERE/monitor_run.sh" "$T/w/hello.icn" --oracle > "$T/r6.out" 2>&1
icx_out="$(python3 -c 'import ast,re,sys; print(repr(b"".join(ast.literal_eval(m) for m in re.findall(r"OUTPUT (b.*)$", open(sys.argv[1]).read(), re.M))))' "$T/log6.icx.log" 2>/dev/null)"   # the records joined: icx cuts write() into pieces
[ "$icx_out" = "b'hello 3\\n'" ] \
  && ck ok "(6) the icx fork says OUTPUT hello and sends the bytes its write() puts on stdout ('hello 3\\n')" \
  || ck no "(6) icx's OUTPUT records for write(\"hello \", 3) join to ${icx_out:-nothing} -- the fork at $ICON_MON predates the OUTPUT event or its fire-point is silent"
printf 'procedure main();\n   write(&version);\nend\n' > "$T/w/ver.icn"; printf 'procedure main();\n   write("same");\nend\n' > "$T/w/same.icn"
ICON_MON_ROOT="$ICON_MON" SCRIP_SNO_STMTKW=1 timeout -k 5 300 bash "$HERE/monitor_run.sh" "$T/w/same.icn" --oracle > "$T/r7s.out" 2>&1; r7s=$?
ICON_MON_ROOT="$ICON_MON" SCRIP_SNO_STMTKW=1 timeout -k 5 300 bash "$HERE/monitor_run.sh" "$T/w/ver.icn" --oracle > "$T/r7v.out" 2>&1; r7v=$?
if grep -q 'OUTPUT NOT GRADED -- scr' "$T/r7s.out"; then
  wait7="the SCRIP Icon plug speaks no OUTPUT yet, so write(&version) still reads AGREE on the icx/scr pair: $(tail -1 "$T/r7v.out" | cut -c1-160)"
elif [ "$r7s" = 0 ] && grep -q 'output graded' "$T/r7s.out" && [ "$r7v" = 1 ] && grep -q 'OUTPUT' "$T/r7v.out"; then
  ck ok "(7) on the icx/scr pair write(&version) DIVERGEs at its OUTPUT and write(\"same\") AGREEs with output graded"
else
  ck no "(7) the icx/scr pair: same rc=$r7s $(tail -1 "$T/r7s.out" | cut -c1-120) :: version rc=$r7v $(tail -1 "$T/r7v.out" | cut -c1-120)"
fi
echo "population: $checks graded arm(s) -- 5 hermetic pairs of scripted participants through the real controller, the icx fork live on one witness${wait7:+, arm 7 waiting}"
if [ "$fails" != 0 ]; then echo "⛔ GATE FAIL(1) [monitor_grades_the_output_event]: $fails of $checks arms red"; exit 1; fi
if [ -n "$wait7" ]; then echo "⛔ GATE REFUSES(2) [monitor_grades_the_output_event]: $checks of $checks arms hold, and arm 7 waits: $wait7 -- THE TWO SIDES LAND IN ORDER (CEO-1272): the fork's side is proven; the SCRIP plug's MWK_OUTPUT hello and bytes are owed"; exit 2; fi
echo "GATE PASS(0) [monitor_grades_the_output_event]: $checks of $checks arms hold"; exit 0
