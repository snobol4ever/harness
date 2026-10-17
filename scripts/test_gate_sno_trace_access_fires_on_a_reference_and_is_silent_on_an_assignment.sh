#!/bin/bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the SNOBOL4 statement instrumentation (the --stlimit switch; Lon 2026-09-24 16:0x: the feature is off by default and never inferred from the source, the correctness graders turn it on because the oracle always has it)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ WITNESS GATE for rung22 of row snobol4-ladder-every-feature-in-isolation-with-variations (cfo 2026-09-13).
# The SPITBOL manual's 'A'/'ACCESS' entry (Ch10 p.147) is "Produces a trace every time the named item is
# referenced.  If you say X = N, that does not change the value of N, but it is a reference -- an 'access' to N",
# and Ch19 p.244 adds that SNOBOL4 has no access trace at all, so the ORACLE is the only reference for it.
# Measured on d1c122fd7 in BOTH modes: SCRIP printed NO access banner anywhere and never decremented &TRACE.
# ⛔ WHY THE ARMS ALL READ THROUGH $() -- A HISTORICAL REASON AS OF 2026-09-13, NOT A LIVE LIMITATION.  A plain
# read of a global WAS the g_gva_active fast path in bb_var_global, two movs straight out of the GVA slot with NO
# call to hook, so the read-tap in NV_GET_fn could not see it at any price, and the manual's own X = N example was
# red.  hq_P REFUSED a runtime guard on that path -- a load-and-branch per global read, shared by all seven
# frontends, paid by every program forever -- and ruled for COMPILE-TIME DEMOTION instead: for a program that
# qualifies, the driver declines to build the GVA island at all.  bb_var_global is UNTOUCHED.  X = N is now GREEN
# and is asserted by test_gate_sno_trace_access_fires_on_a_plain_global_read_via_compile_time_gva_demotion.sh.
# ⭐ THESE ARMS STAY AS THEY ARE ON PURPOSE: they cover the INDIRECTION path, which the demotion does not touch,
# so they are the arms that move first if a future change breaks the tap itself rather than the route to it.
# ⛔ ARM 'silent' IS A CONTROL: an assignment is not an access, and it was already correct before the cure
# (nothing fired at all), so it is the arm that moves first if the tap is ever hung on the store path by mistake.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
[ -f "$ROOT/../harness/scripts/util_sno_trace_witness.sh" ] || { echo "⛔ REFUSE(2): no ../harness/scripts/util_sno_trace_witness.sh"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/reference.sno" <<'EOF'
	&TRACE = 10
	N = 5
	TRACE('N', 'ACCESS')
	X = $('N')
	OUTPUT = 'trace=' &TRACE
END
EOF
cat > "$T/spelling.sno" <<'EOF'
	&TRACE = 10
	N = 5
	TRACE('N', 'A')
	X = $('N')
	OUTPUT = 'trace=' &TRACE
END
EOF
cat > "$T/twice.sno" <<'EOF'
	&TRACE = 10
	N = 5
	TRACE('N', 'ACCESS')
	X = $('N') $('N')
	OUTPUT = 'trace=' &TRACE
END
EOF
cat > "$T/stoptr.sno" <<'EOF'
	&TRACE = 10
	N = 5
	TRACE('N', 'ACCESS')
	X = $('N')
	STOPTR('N', 'ACCESS')
	Y = $('N')
	OUTPUT = 'trace=' &TRACE
END
EOF
cat > "$T/silent.sno" <<'EOF'
	&TRACE = 10
	N = 5
	TRACE('N', 'ACCESS')
	N = 9
	OUTPUT = 'trace=' &TRACE
END
EOF
rc=0; ran=0
for arm in "reference:****4*******  N = 5" "spelling:****4*******  N = 5" "twice:****4*******  N = 5" "stoptr:****4*******  N = 5" "silent:trace=10"; do
  w="$T/${arm%%:*}.sno"; must="${arm#*:}"
  out="$(cd "$ROOT" && bash ../harness/scripts/util_sno_trace_witness.sh "$w" "$must" 2>&1)"; arc=$?
  [ "$arc" = 2 ] && { printf '%s\n' "$out" | tail -3; echo "⛔ REFUSE(2): could not measure ${arm%%:*}"; exit 2; }
  ran=$((ran + 1)); [ "$arc" = 0 ] || { rc=1; printf '%s\n' "$out" | grep -E '^(FAIL|[<>])' | head -8 | sed "s/^/⛔ RED ${arm%%:*}: /"; }
done
[ "$ran" = 5 ] || { echo "⛔ REFUSE(2): measured $ran of 5 arms"; exit 2; }
[ "$rc" = 0 ] && echo "GATE OK: 5 arms x 2 modes -- an ACCESS trace fires once per reference that reaches NV_GET_fn, carries the referencing statement's number, decrements the budget, honours both type spellings and STOPTR, and stays silent on an assignment"
exit $rc
