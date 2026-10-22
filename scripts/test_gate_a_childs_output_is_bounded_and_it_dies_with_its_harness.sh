#!/usr/bin/env bash
# test_gate_a_childs_output_is_bounded_and_it_dies_with_its_harness.sh -- corpus_suite_harness.py's ONE child runner (_run_raw) keeps at most
# S4E_OUTPUT_CAP_MB of each stream and kills the child that passes it, and every child it starts dies with the harness however the harness dies.
#
# ⛔ THE DEFECT THIS GRADES (the coo 2026-10-22, COO-394; the ceo's ask at CEO-1883). _run_raw captured a child's output with no bound. A port
# entry printing in a loop through its 600 s timeout retry grew the harness to 8.15 GB anon RSS inside its 8192 MB mem scope. The kernel killed
# the HARNESS (oom-kill 03:36:05, pid 1099808 python3; request 20261022T004850-hq_jvm-sno-rungs-jvm read 59 of 100 and REFUSED rc 2). The java it
# ran lost its reader and spun 3 h 55 min at 100% CPU with no parent, until the ceo killed it by pid.
#
# THE ARMS (a scratch directory, no corpus, no SCRIP, no row; S4E_OUTPUT_CAP_MB=1 so a bounded printer passes it in about a second):
#   1  BOUND: a child printing forever is killed at the bound: kind OVERFLOW, stdout exactly the bound, the child gone, well before the timeout.
#   2  GRADE: classify grades it FAIL with the bound named, and does not retry it (no timeout retry, CEO-1335/Lon 10-15).
#   3  ORACLE: run_oracle hands the oracle-side callers a kind other than RAN, which every one reads as no answer.
#   4  DIES WITH ITS HARNESS: a harness SIGKILLed mid-run takes its child with it within three seconds.
#   5  THE OLD CONTRACT: output under the bound comes back whole; stdin is fed; merge_stderr interleaves as 2>&1; a timeout is HANG with the
#      output so far; a missing program is UNPROVEN; rc 3 and a self-inflicted SIGKILL (-9) come back as they were.
# FAIL-ONCE: on the harness before this landing arms 1 to 4 read red (no OVERFLOW kind; the child outlives a killed harness).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=a_childs_output_is_bounded_and_it_dies_with_its_harness
GATE_STRICT=1
gate_parse_args "$@"
gate_require "$HERE/corpus_suite_harness.py" "the suite harness corpus_suite_harness.py" || exit 2
command -v setpriv >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no setpriv on PATH -- a child cannot be bound to its harness here"; gate_stamp; exit 2; }
WORK=$(mktemp -d "${TMPDIR:-/tmp}/gate_child_bound_XXXXXX") || exit 2
KIDS=()
trap 'for k in "${KIDS[@]}"; do kill -9 "$k" 2>/dev/null; done; rm -rf "$WORK"' EXIT INT TERM
export S4E_OUTPUT_CAP_MB=1 S4E_PROGRESS_OFF=1
PYH="import sys, time; sys.path.insert(0, '$HERE'); import corpus_suite_harness as h"
PRINTER="import sys, time
while True:
    sys.stdout.write('x' * 999 + '\n'); sys.stdout.flush(); time.sleep(0.0005)"
printf '%s\n' "$PRINTER" > "$WORK/printer.py"
fails=0; examined=0; out=""
arm_fail() { fails=$((fails+1)); echo "  FAIL arm$1: $2"; printf '%s\n' "$out" | head -5 | sed 's/^/        /'; }
printer_alive() { local p; for p in $(pgrep -f 'printer[.]py'); do [ "$(readlink /proc/$p/cwd 2>/dev/null)" = "$WORK" ] && { echo "$p"; return 0; }; done; return 1; }

# ARM 1 -- the bound: OVERFLOW, exactly the bound kept, the child gone, long before the 60 s timeout.
examined=$((examined+1))
out=$(cd "$WORK" && timeout 120 python3 -c "$PYH
t0 = time.monotonic()
k, o, e, rc = h._run_raw(['python3', 'printer.py'], 60, cwd='$WORK')
print('KIND', k, 'LEN', len(o), 'CAP', h._OUTPUT_CAP if hasattr(h, '_OUTPUT_CAP') else -1, 'SECS', int(time.monotonic() - t0))" 2>&1)
if ! printf '%s\n' "$out" | grep -qE '^KIND OVERFLOW LEN 1048576 CAP 1048576 SECS ([0-9]|1[0-9]|2[0-9])$'; then arm_fail 1 "a child printing forever is not killed at the 1 MB bound with exactly the bound kept, inside 30 s of a 60 s timeout"
elif kp=$(printer_alive); then KIDS+=("$kp"); arm_fail 1 "the printer pid $kp still runs after the bound killed it"
else echo "  ok  arm1: $out"; fi

# ARM 2 -- the grade: FAIL naming the bound, never retried.
examined=$((examined+1))
out=$(cd "$WORK" && timeout 120 python3 -c "$PYH
v = h.classify(['python3', 'printer.py'], 6, 'x', cwd='$WORK')
print('VERDICT', v.kind, 'RETRY', repr(v.retry), 'DETAIL', v.detail)" 2>&1)
if ! printf '%s\n' "$out" | grep -qE "^VERDICT FAIL RETRY '' DETAIL output passed the S4E_OUTPUT_CAP_MB bound of 1048576 bytes"; then arm_fail 2 "classify does not grade the bounded printer FAIL with the bound named and no retry"
else echo "  ok  arm2: $out"; fi

# ARM 3 -- the oracle side: run_oracle returns a kind other than RAN (every oracle caller's guard reads that as no answer).
examined=$((examined+1))
printf '#!/bin/bash\nexec python3 %s/printer.py\n' "$WORK" > "$WORK/fake_oracle"; chmod +x "$WORK/fake_oracle"; : > "$WORK/p.sno"
out=$(timeout 120 python3 -c "$PYH
text, rc, kind = h.run_oracle('$WORK/fake_oracle', '', '$WORK/p.sno', 6)
print('ORACLE', kind, 'TEXTLEN', len(text))" 2>&1)
if ! printf '%s\n' "$out" | grep -qE '^ORACLE OVERFLOW TEXTLEN [0-9]+$'; then arm_fail 3 "run_oracle does not hand back the OVERFLOW kind for an oracle printing forever"
elif kp=$(printer_alive); then KIDS+=("$kp"); arm_fail 3 "the oracle's printer pid $kp still runs after the bound killed it"
else echo "  ok  arm3: $out"; fi

# ARM 4 -- the child dies with its harness: SIGKILL the harness mid-run, the child must be gone within three seconds.
examined=$((examined+1))
python3 -c "$PYH
h._run_raw(['sleep', '300'], 600, cwd='$WORK')" > /dev/null 2>&1 &
HP=$!; KIDS+=("$HP"); kid=""
for _ in $(seq 1 50); do kid=$(pgrep -P "$HP" | head -1); [ -n "$kid" ] && [ "$(cat /proc/$kid/comm 2>/dev/null)" = sleep ] && break; kid=""; sleep 0.1; done
if [ -z "$kid" ]; then out="no sleep child of harness pid $HP appeared in 5 s"; arm_fail 4 "the arm could not start its child"
else
    KIDS+=("$kid"); kill -9 "$HP"; wait "$HP" 2>/dev/null
    for _ in $(seq 1 30); do kill -0 "$kid" 2>/dev/null || break; sleep 0.1; done
    if kill -0 "$kid" 2>/dev/null; then out="child pid $kid ($(cat /proc/$kid/comm 2>/dev/null)) still alive 3 s after its harness pid $HP was SIGKILLed"; arm_fail 4 "a child outlives its harness"
    else echo "  ok  arm4: the harness pid $HP SIGKILLed, its child pid $kid gone within 3 s"; fi
fi

# ARM 5 -- the old contract.
examined=$((examined+1))
out=$(cd "$WORK" && timeout 120 python3 -c "$PYH
def show(tag, r): print(tag, r[0], repr(r[1][:60]), r[3])
show('PLAIN', h._run_raw(['printf', 'a\\\\nb'], 10))
show('STDIN', h._run_raw(['cat'], 10, stdin_text='hello\\n'))
show('MERGE', h._run_raw(['bash', '-c', 'echo o; echo e >&2; echo o2'], 10, merge_stderr=True))
show('UNDER', (lambda r: (r[0], b'%d' % len(r[1]), b'', r[3]))(h._run_raw(['python3', '-c', 'import sys; sys.stdout.write(\"y\" * 1000000)'], 30)))
show('HANG', h._run_raw(['bash', '-c', 'echo early; exec sleep 30'], 1))
show('MISSING', h._run_raw(['$WORK/no_such_program'], 10))
show('RC3', h._run_raw(['bash', '-c', 'exit 3'], 10))
show('SELFKILL', h._run_raw(['bash', '-c', 'kill -9 \$\$'], 10))" 2>&1)
want="PLAIN RAN b'a\\\\nb' 0
STDIN RAN b'hello\\\\n' 0
MERGE RAN b'o\\\\ne\\\\no2\\\\n' 0
UNDER RAN b'1000000' 0
HANG HANG b'early\\\\n' None
MISSING UNPROVEN b'' None
RC3 RAN b'' 3
SELFKILL RAN b'' -9"
if [ "$out" != "$(printf '%b' "$want")" ]; then arm_fail 5 "the old contract moved; want: $(printf '%b' "$want" | tr '\n' '|')"
else echo "  ok  arm5: plain, stdin, merged stderr, 1 MB under the bound, HANG with partial output, UNPROVEN, rc 3, rc -9 as before"; fi

GATE_EXAMINED=$examined
gate_verdict "$fails" "arm(s) failed (a child's output is bounded at S4E_OUTPUT_CAP_MB and the child dies with its harness)"
