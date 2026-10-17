#!/bin/bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the SNOBOL4 statement instrumentation (the --stlimit switch; Lon 2026-09-24 16:0x: the feature is off by default and never inferred from the source, the correctness graders turn it on because the oracle always has it)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ WITNESS GATE for row snobol4-trace-of-an-array-or-table-element-never-registers-because-a-name-of-element-
# carries-no-spelling (cfo 2026-09-13), the blocker of ladder rung23.  TRACE(.A[2]) and TRACE(.T['k'],'VALUE')
# never fired in either mode: the oracle prints a banner in a spelling the plain-variable banner never uses --
# ANGLE BRACKETS, A<2> and T<'k'> -- and SCRIP printed neither.  Every expectation below is cut from `sbl -bf`
# at run time and never typed.
# ⛔ THE ROW'S OWN DIAGNOSIS SAID THE SPELLING MUST BE CAPTURED WHERE THE NAME-OF IS FORMED.  MEASURED, THE
# ORACLE DOES NOT DO THAT, AND ARM 'alias' IS THAT MEASUREMENT KEPT AS A GATE: trace .B[2] where B = A and the
# banner still reads A<2>, so SPITBOL spells the element by REVERSE-LOOKING-UP THE CONTAINER in its variable
# table at print time, not by remembering the source text.  A cure that captured the source spelling would be
# green on the rung and wrong here.
# ⛔ ARM 'rebind' IS THE IDENTITY ARM AND IT IS WHY THE REGISTRY CARRIES THE CONTAINER'S SERIAL: the spelling
# alone is not an identity.  Rebind A to a NEW array and the oracle goes SILENT -- a name-of binds to the CELL
# -- while a cure keyed on the string "A<2>" alone happily traces the new array's cell.  It scored exactly that
# before the eid check went in.
# ⛔ ARM 'stoptr' IS NOT DECORATION EITHER: STOPTR reaches the same spelling through the same path, and it was
# RED for a reason worth keeping -- VARVAL_fn on a NAMETRAP does NOT return the empty string, it returns THE
# CELL'S VALUE, so the element branch was skipped for every cell that had already been written to.
# ⭐ SCOPE, said rather than implied: these arms are ONE-DIMENSIONAL.  A 2-D element trace (the manual's own
# TRACE(.A[2,5]) form) is measured RED and rowed separately -- _TRACE_ is not even entered for it.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
[ -f "$ROOT/../harness/scripts/util_sno_trace_witness.sh" ] || { echo "⛔ REFUSE(2): no ../harness/scripts/util_sno_trace_witness.sh"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/element.sno" <<'EOF'
	&TRACE = 100
	A = ARRAY(3)
	T = TABLE()
	TRACE(.A[2])
	TRACE(.T['k'], 'VALUE')
	A[2] = 5
	A[1] = 6
	T['k'] = 7
	T['j'] = 8
	OUTPUT = 'done ' A[2]
END
EOF
cat > "$T/rebind.sno" <<'EOF'
	&TRACE = 100
	A = ARRAY(3)
	B = A
	TRACE(.A[2])
	B[2] = 5
	A = ARRAY(3)
	A[2] = 9
	OUTPUT = 'end'
END
EOF
cat > "$T/stoptr.sno" <<'EOF'
	&TRACE = 100
	A = ARRAY(3)
	TRACE(.A[2])
	A[2] = 5
	STOPTR(.A[2])
	A[2] = 6
	T = TABLE()
	TRACE(.T['k'], 'VALUE')
	T['k'] = 1
	OUTPUT = 'end'
END
EOF
cat > "$T/alias.sno" <<'EOF'
	&TRACE = 100
	A = ARRAY(3)
	B = A
	TRACE(.B[2])
	A[2] = 5
	OUTPUT = 'end'
END
EOF
cat > "$T/untraced.sno" <<'EOF'
	&TRACE = 100
	A = ARRAY(3)
	C = ARRAY(3)
	TRACE(.A[2])
	C[2] = 1
	A[3] = 2
	A[2] = 5
	OUTPUT = 'end'
END
EOF
rc=0; ran=0
for arm in "element:A<2> = 5" "rebind:A<2> = 5" "stoptr:A<2> = 5" "alias:A<2> = 5" "untraced:A<2> = 5"; do
  w="$T/${arm%%:*}.sno"; must="${arm#*:}"
  out="$(cd "$ROOT" && bash ../harness/scripts/util_sno_trace_witness.sh "$w" "$must" 2>&1)"; arc=$?
  [ "$arc" = 2 ] && { printf '%s\n' "$out" | tail -3; echo "⛔ REFUSE(2): could not measure ${arm%%:*}"; exit 2; }
  ran=$((ran + 1)); [ "$arc" = 0 ] || { rc=1; printf '%s\n' "$out" | grep -E '^(FAIL|[<>])' | head -8 | sed "s/^/⛔ RED ${arm%%:*}: /"; }
done
[ "$ran" = 5 ] || { echo "⛔ REFUSE(2): measured $ran of 5 arms"; exit 2; }
[ "$rc" = 0 ] && echo "GATE OK: 5 arms x 2 modes -- an element trace fires, spells itself with angle brackets like sbl -bf, binds to the CELL and not to the name, stops on STOPTR, and stays silent for every element and container it was not asked about"
exit $rc
