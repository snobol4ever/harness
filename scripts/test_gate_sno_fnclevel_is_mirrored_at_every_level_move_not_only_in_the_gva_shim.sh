#!/bin/bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the SNOBOL4 statement instrumentation (the --stlimit switch; Lon 2026-09-24 16:0x: the feature is off by default and never inferred from the source, the correctness graders turn it on because the oracle always has it)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ CURE GATE for row snobol4-fnclevel-not-incremented-entering-a-defined-function (cfo 2026-09-13, released to
# cfo by hq_P the same hour: under NONET hq_P is CONCERN 2 SPEED and SNOBOL4 completeness is CONCERN 1, cfo's).
# THE DEFECT: &FNCLEVEL read 0 at every depth inside a program-defined function -- a constant, not an off-by-one --
# and every trace banner raised inside a call lost its depth marks with it, because the banner's depth IS g_kw_fnclevel
# (core.c trace_print_banner_args).
# ⛔⭐ WHY A ROW THAT READ DONE WAS STILL LIVE, AND IT IS THE GENERAL SHAPE: the sibling row conform-fnclevel-not-
# tracked landed the enter/leave pair in bb_define's ROLE-4 TINY SHIM (bb_fnclevel_enter/bb_fnclevel_leave), and that
# shim is only CHOSEN when the program builds a GVA island. Every program that does not take that arm kept the
# original defect, and nothing measured it, because the witness that would have shown it lands on the other side of
# an emit-time branch. A CURE CONDITIONAL ON AN EMIT-TIME ARM IS LIVE FOR EVERY PROGRAM THAT DOES NOT TAKE THAT ARM.
# ⭐ THE CAUSE, READ OUT OF THE EMITTED ASSEMBLY RATHER THAN REASONED: a demoted .s carries two g_kw_fnclevel
# references and BOTH ARE READS; the GVA .s carries five, three of them WRITES. In the runtime, g_rt_k_level was MOVED
# at thirteen sites in rt.c and MIRRORED into g_kw_fnclevel at only two of them (rt_ab_enter_env/rt_ab_leave_env) --
# hq_P counted the thirteen independently. THE CURE IS THE INVARIANT, not a site: g_kw_fnclevel == g_rt_k_level - 1
# wherever g_rt_k_level moves, expressed once as rt_k_level_mirror() and called at every move.
# ⛔ THE CONTROL ARM IS THE POINT OF THIS GATE AND IT USES NO TRACE AT ALL. SCRIP_M3_GVA=0 turns the island off for
# a program that would otherwise build one, so arm 'gva_off_control' exercises the slim path on a source with no
# TRACE in it -- which is what proves the defect was never about ACCESS, and what would go red again if a future
# cure moved back into the GVA-conditional arm. Its m4 twin is arm 'banner_depth': an ACCESS trace demotes the
# island at compile time, so that witness reaches the same slim path in BOTH modes without an env knob.
# ⛔⭐ WHICH ARMS ACTUALLY DISCRIMINATE, MEASURED ON THE PRE-CURE BINARY RATHER THAN CLAIMED FOR ALL FOUR: only
# 'banner_depth' (RED in BOTH modes), 'gva_off_control' and the source invariant went red before the cure.
# 'manual_repro', 'nested' and 'ctl_no_call' were ALREADY GREEN there -- they take the GVA shim, which the sibling
# row cured -- and they are kept as the arms that go red if a future cure fixes the slim path by breaking that one.
# A gate whose green arms are counted as evidence of the cure is the same disease this row was minted for.
# ⛔ NOT ASSERTED HERE: Icon's &level. It reads g_rt_k_level DIRECTLY (keywords.c "level"), not g_kw_fnclevel, and this
# cure moves no g_rt_k_level value -- the Icon ladder was measured 688/688 before and after and is the arm for that.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_subject_tree.sh"
ROOT="$(s4e_subject_repo "${BASH_SOURCE[0]}")"
[ -f "$ROOT/../harness/scripts/util_sno_trace_witness.sh" ] || { echo "⛔ REFUSE(2): no ../harness/scripts/util_sno_trace_witness.sh"; exit 2; }
. "$ROOT/../harness/scripts/lib_oracle_flags.sh" || { echo "⛔ REFUSE(2): cannot source lib_oracle_flags.sh"; exit 2; }
O="$(sbl_correctness_bin)" || { echo "⛔ REFUSE(2): no SPITBOL correctness oracle"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/manual_repro.sno" <<'EOF'
	DEFINE('F1()')	:(MAIN)
F1	OUTPUT = 'inside=' &FNCLEVEL	:(RETURN)
MAIN	OUTPUT = 'top=' &FNCLEVEL
	F1()
	OUTPUT = 'after=' &FNCLEVEL
END
EOF
cat > "$T/nested.sno" <<'EOF'
	DEFINE('F1()')
	DEFINE('F2()')	:(MAIN)
F1	OUTPUT = 'in F1=' &FNCLEVEL
	F2()
	OUTPUT = 'back F1=' &FNCLEVEL	:(RETURN)
F2	OUTPUT = 'in F2=' &FNCLEVEL	:(RETURN)
MAIN	OUTPUT = 'top=' &FNCLEVEL
	F1()
	OUTPUT = 'after=' &FNCLEVEL
END
EOF
cat > "$T/banner_depth.sno" <<'EOF'
	&TRACE = 10
	DEFINE('F(Y)')	:(START)
F	F = N + Y	:(RETURN)
START	N = 5
	TRACE('N', 'ACCESS')
	X = F(1)
	OUTPUT = 'x=' X
END
EOF
cat > "$T/ctl_no_call.sno" <<'EOF'
	OUTPUT = 'top=' &FNCLEVEL
	N = 5
	OUTPUT = 'still=' &FNCLEVEL
END
EOF
rc=0; ran=0
# ⭐ Each 'must' is a line the LIVE ORACLE has to print or the helper refuses rc=2; the grading itself is byte-exact
# over the whole of stdout+stderr in both modes, so these are guards against a silent oracle, not the assertion.
for arm in \
  "manual_repro:inside=1" \
  "nested:in F2=2" \
  "banner_depth:****3******* i N = 5" \
  "ctl_no_call:top=0" ; do
  w="$T/${arm%%:*}.sno"; must="${arm#*:}"
  out="$(cd "$ROOT" && bash ../harness/scripts/util_sno_trace_witness.sh "$w" "$must" 2>&1)"; arc=$?
  [ "$arc" = 2 ] && { printf '%s\n' "$out" | tail -3; echo "⛔ REFUSE(2): could not measure ${arm%%:*}"; exit 2; }
  ran=$((ran + 1)); [ "$arc" = 0 ] || { rc=1; printf '%s\n' "$out" | grep -E '^(FAIL|[<>])' | head -8 | sed "s/^/⛔ RED ${arm%%:*}: /"; }
done
[ "$ran" = 4 ] || { echo "⛔ REFUSE(2): measured $ran of 4 oracle arms"; exit 2; }
# ⛔⭐ THE ISLAND-OFF CONTROL, in m3 because SCRIP_M3_GVA is an m3 knob, on a source with NO TRACE: this is the
# arm that isolates the slim path from anything to do with tracing. It refuses rc=2 unless the island really is
# gone under the knob and really is present without it -- an absence arm that cannot see presence proves nothing.
want="$(timeout -k 5 8s "$O" -bf "$T/nested.sno" </dev/null 2>&1)" || true
[ -n "$want" ] || { echo "⛔ REFUSE(2): the oracle printed nothing for the island-off control"; exit 2; }
got="$(cd "$ROOT" && SCRIP_M3_GVA=0 timeout -k 5 8s ./scrip --run "$T/nested.sno" </dev/null 2>&1)" || true
gotb="$(cd "$ROOT" && timeout -k 5 8s ./scrip --run "$T/nested.sno" </dev/null 2>&1)" || true
if [ "$got" != "$want" ]; then
  rc=1; echo "⛔ RED gva_off_control: with the GVA island off, a DEFINE'd call still does not track &FNCLEVEL"
  diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -8 | sed 's/^/    /'
fi
[ "$gotb" = "$want" ] || { rc=1; echo "⛔ RED gva_on_control: the island-ON spelling of the same source diverges from the oracle"; }
if [ "$got" = "$want" ] && [ "$gotb" = "$want" ]; then
  q="$(cd "$ROOT" && ./scrip --compile --out="$T/n.s" "$T/nested.sno" </dev/null >/dev/null 2>&1 && grep -c '__gva_names' "$T/n.s")" || q=0
  [ "${q:-0}" -gt 0 ] || { echo "⛔ REFUSE(2): the control source emits no GVA island at all, so SCRIP_M3_GVA=0 turns nothing off and this arm cannot discriminate"; exit 2; }
fi
# ⛔ THE INVARIANT IS ASSERTED AT THE SOURCE TOO, because the four oracle arms above only reach the call paths a
# SNOBOL4 program can reach: rt.c must not grow a bare g_rt_k_level move again. Counted, not eyeballed -- every
# ++/-- line carries its mirror, and the count is printed so a future reader sees the population, not a boolean.
src="$ROOT/src/runtime/rt/rt.c"
[ -f "$src" ] || { echo "⛔ REFUSE(2): no $src"; exit 2; }
# ⛔ READ AS STATEMENTS, NOT LINES (the 200-column re-flow, CEO-1565, lays every child statement on its own line, so the mirror is the NEXT statement and no longer shares the move's physical line):
# a move is a  g_rt_k_level++;  or  g_rt_k_level--;  statement and it is mirrored when the statement that follows it, whitespace and newlines skipped, is  rt_k_level_mirror();
read -r mv bare < <(python3 - "$src" <<'PYEOF'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
moves = list(re.finditer(r"g_runtime\.abi\.rt_k_level(\+\+|--);", t))
bare = [m for m in moves if not re.match(r"\s*rt_k_level_mirror\(\);", t[m.end():])]
print(len(moves), len(bare))
for m in bare[:6]:
    sys.stderr.write("    rt.c:%d: %s\n" % (t.count("\n", 0, m.start()) + 1, t.splitlines()[t.count("\n", 0, m.start())].strip()[:120]))
PYEOF
)
[ "$mv" -ge 8 ] || { echo "⛔ REFUSE(2): only $mv g_rt_k_level move line(s) in rt.c -- the level machinery has moved and this arm is grading a file that no longer holds it"; exit 2; }
if [ "$bare" -ne 0 ]; then
  rc=1; echo "⛔ RED bare_level_move: $bare of $mv g_rt_k_level move statement(s) in rt.c are not followed by rt_k_level_mirror():"
fi
[ "$rc" = 0 ] && echo "GATE OK: 4 oracle arms x 2 modes + the island-off control + the source invariant -- &FNCLEVEL tracks a DEFINE'd call on the slim path as well as in the GVA shim, and all $mv g_rt_k_level move statements in rt.c mirror it"
exit "$rc"
