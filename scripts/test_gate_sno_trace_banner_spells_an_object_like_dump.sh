#!/bin/bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the SNOBOL4 statement instrumentation (the --stlimit switch; Lon 2026-09-24 16:0x: the feature is off by default and never inferred from the source, the correctness graders turn it on because the oracle always has it)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ WITNESS GATE for the rung17 form `trace_banner_spells_an_object_with_its_prototype_and_serial` of row
# snobol4-ladder-every-feature-in-isolation-with-variations (cfo 2026-09-13).  A TRACE banner spells an
# ARRAY, a TABLE or a DATA instance the way &DUMP does -- its PROTOTYPE and its CREATION SERIAL -- because
# that is what `sbl -bf` prints: ARRAY(3) #1, ARRAY(2:4) #2, ARRAY(2,3) #3, TABLE(11) #4, TABLE(7) #5,
# NODE #6.  MEASURED on 202d8bfff, BOTH modes: the banner spelled the value from VARVAL_fn instead and
# printed ARRAY('1:3') for ARRAY(3), TABLE(7,3) for TABLE(7,3), a bare NODE with no serial, and -- worst --
# ARRAY('1:2') for the two-dimensional ARRAY('2,3'), dropping its second dimension, while dump_obj_head in
# the SAME FILE already had the oracle's exact shape.  The manual (Ch10 pp.147-150) shows only string
# values, so THE ORACLE IS THE REFERENCE for the object spelling and every expectation below is cut from it
# at run time, never typed.  ⛔ ARM 4 IS A CONTROL, NOT DECORATION: the string/integer/real/name spellings
# were already correct and are the branches a rewrite of trace_spell_value would most easily move.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
[ -f "$ROOT/../harness/scripts/util_sno_trace_witness.sh" ] || { echo "⛔ REFUSE(2): no ../harness/scripts/util_sno_trace_witness.sh"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/array.sno" <<'EOF'
	&TRACE = 100
	TRACE('N', 'VALUE')
	N = ARRAY(3)
	N = ARRAY('2:4')
	N = ARRAY('2,3')
	OUTPUT = 'trace=' &TRACE
END
EOF
cat > "$T/table.sno" <<'EOF'
	&TRACE = 100
	TRACE('N', 'VALUE')
	N = TABLE()
	N = TABLE(7,3)
	OUTPUT = 'trace=' &TRACE
END
EOF
cat > "$T/data.sno" <<'EOF'
	&TRACE = 100
	DATA('NODE(L,R)')
	TRACE('N', 'VALUE')
	N = NODE(1,2)
	N = NODE(3,4)
	OUTPUT = 'trace=' &TRACE
END
EOF
cat > "$T/scalar.sno" <<'EOF'
	&TRACE = 100
	TRACE('N', 'VALUE')
	N = 'str'
	N = 12
	N = 1.5
	N = LEN(3)
	N = .X
	OUTPUT = 'trace=' &TRACE
END
EOF
rc=0; ran=0
for arm in "array:ARRAY(3) #1" "table:TABLE(11) #" "data:NODE #" "scalar:N = 'str'"; do
  w="$T/${arm%%:*}.sno"; must="${arm#*:}"
  out="$(cd "$ROOT" && bash ../harness/scripts/util_sno_trace_witness.sh "$w" "$must" 2>&1)"; arc=$?
  [ "$arc" = 2 ] && { printf '%s\n' "$out" | tail -3; echo "⛔ REFUSE(2): could not measure ${arm%%:*}"; exit 2; }
  ran=$((ran + 1)); [ "$arc" = 0 ] || { rc=1; printf '%s\n' "$out" | grep -E '^(FAIL|[<>])' | head -8 | sed "s/^/⛔ RED ${arm%%:*}: /"; }
done
[ "$ran" = 4 ] || { echo "⛔ REFUSE(2): measured $ran of 4 arms"; exit 2; }
[ "$rc" = 0 ] && echo "GATE OK: 4 arms x 2 modes -- an ARRAY, a TABLE and a DATA instance in a trace banner carry the oracle's own prototype and creation serial, and the scalar spellings are unmoved"
exit $rc
