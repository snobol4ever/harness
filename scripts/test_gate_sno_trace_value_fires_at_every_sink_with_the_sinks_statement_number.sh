#!/bin/bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the SNOBOL4 statement instrumentation (the --stlimit switch; Lon 2026-09-24 16:0x: the feature is off by default and never inferred from the source, the correctness graders turn it on because the oracle always has it)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ WITNESS GATE for rung18 of row snobol4-ladder-every-feature-in-isolation-with-variations (cfo 2026-09-13).
# The SPITBOL manual's 'V'/'VALUE' entry (Ch10 p.147) names THREE sink classes -- "Assignment statements, as
# well as conditional and immediate assignments within pattern matching" -- and SCRIP fired at all three.  What
# it got wrong was the BANNER, measured on 119fddd6c in BOTH modes: every sink that is not a plain `NAME = expr`
# printed `****0*******` for its statement number, because every comm_var() call site in the C runtime passed a
# LITERAL 0 for stno and only the code-generated bb_assign_global box baked in the real one -- and the immediate
# ($) sink printed `****18790523`, a HEAP POINTER, because rtx_match.s left rcx/r8/r9 uninitialised at its
# comm_var call (the assembly-thunk shape of FINDING-2026-09-13-hq_C).  Separately the banner printed a captured
# substring to the END OF THE SUBJECT -- 'BCD' for a capture of 'B' out of 'ABCD' -- because trace_spell_value
# ignored the descriptor's slen; the CELL was always right, so only the trace lied.
# ⛔ ARM 5 IS A CONTROL, NOT DECORATION: the plain-assignment sink was already correct before the cure (3 of the
# rung's 10 forms were green on the pre-cure binary) and it is the arm a rewrite of the stno path would move first.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
[ -f "$ROOT/../harness/scripts/util_sno_trace_witness.sh" ] || { echo "⛔ REFUSE(2): no ../harness/scripts/util_sno_trace_witness.sh"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/cond.sno" <<'EOF'
	&TRACE = 100
	TRACE('N', 'VALUE')
	'ABCD' 'B' . N
	OUTPUT = 'trace=' &TRACE
END
EOF
cat > "$T/imm.sno" <<'EOF'
	&TRACE = 100
	TRACE('N', 'VALUE')
	'ABCD' 'B' $ N
	OUTPUT = 'trace=' &TRACE
END
EOF
cat > "$T/indirect.sno" <<'EOF'
	&TRACE = 100
	TRACE('N', 'VALUE')
	$'N' = 8
	V = .N
	$V = 9
	OUTPUT = 'trace=' &TRACE
END
EOF
cat > "$T/replace.sno" <<'EOF'
	&TRACE = 100
	TRACE('N', 'VALUE')
	N = 'ABC'
	N 'B' = 'X'
	OUTPUT = 'trace=' &TRACE
END
EOF
cat > "$T/plain.sno" <<'EOF'
	&TRACE = 100
	TRACE('N', 'VALUE')
	N = 'first'
	N = 2 + 3
	OUTPUT = 'trace=' &TRACE
END
EOF
rc=0; ran=0
for arm in "cond:****3*******  N = 'B'" "imm:****3*******  N = 'B'" "indirect:****5*******  N = 9" "replace:****4*******  N = 'AXC'" "plain:****3*******  N = 'first'"; do
  w="$T/${arm%%:*}.sno"; must="${arm#*:}"
  out="$(cd "$ROOT" && bash ../harness/scripts/util_sno_trace_witness.sh "$w" "$must" 2>&1)"; arc=$?
  [ "$arc" = 2 ] && { printf '%s\n' "$out" | tail -3; echo "⛔ REFUSE(2): could not measure ${arm%%:*}"; exit 2; }
  ran=$((ran + 1)); [ "$arc" = 0 ] || { rc=1; printf '%s\n' "$out" | grep -E '^(FAIL|[<>])' | head -8 | sed "s/^/⛔ RED ${arm%%:*}: /"; }
done
[ "$ran" = 5 ] || { echo "⛔ REFUSE(2): measured $ran of 5 arms"; exit 2; }
[ "$rc" = 0 ] && echo "GATE OK: 5 arms x 2 modes -- a VALUE trace fires at the conditional, immediate, indirect and replacement sinks carrying the SINK'S OWN statement number and the matched extent only, and the plain-assignment sink is unmoved"
exit $rc
