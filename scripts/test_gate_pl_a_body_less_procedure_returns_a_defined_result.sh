#!/usr/bin/env bash
# stale-binary preflight -- util_require_fresh.sh is the ONE authority; no second copy of the staleness rule here.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_a_body_less_procedure_returns_a_defined_result.sh -- A PROCEDURE WHOSE BODY IS `true` MUST NOT
# HAND ITS CALLER THE FRAME-MAP ADDRESS AS ITS RESULT (hq_prolog 2026-09-23, CEO-1215; cto-approved cure).
# ⛔⭐ THE DEFECT, MEASURED WITH GDB: emit_gc_map_cell (emit.cpp) loads the activation frame's map with
# `lea rax, [rip + .Lgcmap_<fam>]` and used to leave rax holding it. A body of IR_SUCCEED alone never writes the
# result register, so gamma forwarded that address as the call's result, and the Prolog det call site tests its low
# byte against DT_FAIL (104). An address ending in 0x68 turned a SUCCESS into a FAILURE: the Logtalk grader's
# `'$lgt_cond' :- true.` read "condition false" and ten clause_2 cases plus three assertz_1 cases went UNGRADED in
# mode 4 only. ⭐ LAYOUT-DEPENDENT, which is why the monitor agreed: the same .s linked as PIE, or built traced,
# moves the map labels off the fatal byte. The cure is `mov eax, 0` at the end of emit_gc_map_cell -- the null
# descriptor, a success at every det call site, deterministically.
# THREE ARMS, BOTH MODES. (A) a generated witness: 256 body-less procedures, each called through catch/3 from a det
# site, printing bad(K) for any that reads as failure -- measured before the cure, m4 linked -no-pie: bad(80)
# bad(111) bad(210). (B) the Logtalk clause_2 case program itself (iso_clause_2_01, built by util_logtalk_grade's
# own planner so it tracks the grader), the witness the ceo's row named. (C) STRUCTURAL, LAYOUT-FREE: in every
# witness's mode-4 .s, each frame-map load is followed by `mov eax, 0` before the next instruction that could read
# rax. A behavioural witness is only red when a map address happens to end in 0x68; (C) is red on ANY layout when the
# cure is missing, and its canary proves it can say no.
# ⛔ REFS ARE CUT FROM swipl AT RUN TIME, never from our output (CEO-753); no swipl -> REFUSE rc=2.
# ⛔ mode 4 is linked -no-pie, as every suite grader links it; a PIE link hides the behavioural half.
# EXIT: 0 clean · 1 a violation · 2 UNPROVEN (no binary, no oracle, no witness compiled, a canary not red).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"; SWIPL="${SWIPL:-/usr/bin/swipl}"
LGT="$S4E/corpus/packages/prolog/logtalk_iso"
G=test_gate_pl_a_body_less_procedure_returns_a_defined_result
refuse(){ echo "GATE UNPROVEN(2) [$G]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP"
[ -f "$RT/libscrip_rt.so" ] || refuse "no runtime library at $RT"
[ -x "$SWIPL" ] || refuse "no swipl at $SWIPL -- the refs are cut from it at run time and never from our output"
[ -d "$LGT" ] || refuse "no vendored logtalk_iso suite at $LGT"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
python3 - "$W/a.pl" <<'PY' || refuse "could not generate witness A"
import sys
n = 256
out = [":- initialization(main)."]
out += ["b%d :- true." % i for i in range(n)]
out += ["t%d :- ( catch(b%d, _, fail) -> true ; write(bad(%d)), nl )." % (i, i, i) for i in range(n)]
out.append("main :- " + ", ".join("t%d" % i for i in range(n)) + ", write(done), nl.")
open(sys.argv[1], "w").write("\n".join(out) + "\n")
PY
( cd "$HERE" && python3 - "$W/b.pl" "$LGT" <<'PY' ) || refuse "could not build witness B through util_logtalk_grade's planner"
import sys
import util_logtalk_grade as g
out, root = sys.argv[1], sys.argv[2]
files, bad = g.ex.parse_suite(root)
if bad: sys.exit("parse_suite refused: %r" % (bad[:1],))
sup = g.shim_helpers(); shim = open(g.SHIM, encoding="utf-8").read()
for fc in files:
    if fc.group != "clause_2": continue
    clean, _dropped = g.split_db(fc.db)
    for c in fc.cases:
        if c.name == "iso_clause_2_01":
            p = g.plan_case(c, sup)
            if p.skip_reason: sys.exit("iso_clause_2_01 is not plannable: %s" % p.skip_reason)
            open(out, "w", encoding="utf-8").write(g.program_text(p, clean, shim)); sys.exit(0)
sys.exit("clause_2/iso_clause_2_01 not found in the suite")
PY
fails=0; compiled=0
for w in a b; do
  timeout -k 5 60 "$SWIPL" -q -g true -t halt "$W/$w.pl" </dev/null >"$W/$w.ref" 2>/dev/null || refuse "swipl could not run witness $w"
  [ -s "$W/$w.ref" ] || refuse "swipl printed nothing for witness $w -- an empty ref grades nothing"
  timeout -k 5 60 "$SCRIP" "$W/$w.pl" </dev/null >"$W/$w.m3" 2>/dev/null
  if cmp -s "$W/$w.ref" "$W/$w.m3"; then echo "  ok   $w m3"; else echo "  RED  $w m3: $(head -c 120 "$W/$w.m3" | tr '\n' ' ')"; fails=$((fails+1)); fi
  timeout -k 5 120 "$SCRIP" --compile -o "$W/$w.s" "$W/$w.pl" </dev/null >/dev/null 2>"$W/$w.cerr" && [ -s "$W/$w.s" ] || refuse "mode-4 compile of witness $w failed: $(head -1 "$W/$w.cerr")"
  gcc -m64 -no-pie "$W/$w.s" -o "$W/$w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$W/$w.lerr" || refuse "mode-4 link of witness $w failed: $(head -1 "$W/$w.lerr")"
  compiled=$((compiled+1))
  timeout -k 5 60 "$W/$w.bin" </dev/null >"$W/$w.m4" 2>/dev/null
  if cmp -s "$W/$w.ref" "$W/$w.m4"; then echo "  ok   $w m4"; else echo "  RED  $w m4: $(head -c 120 "$W/$w.m4" | tr '\n' ' ')"; fails=$((fails+1)); fi
done
[ "$compiled" -eq 2 ] || refuse "only $compiled of 2 witnesses compiled"
# (C) every prologue anchor note (`# GCANCHOR .Lgcmap_...`, the zero-byte successor of the old `lea rax, [rip + .Lgcmap_...]` map-cell store, ARCH-GC section 13 STEP B)
# rides the prologue's `mov eax, 0`: the null descriptor a body of IR_SUCCEED alone forwards as its result. The map address can no longer reach rax (no `lea` exists), but the
# register would then hold whatever the caller left in it, so the instruction stays and this arm holds it.
struct(){ awk '/# GCANCHOR \.Lgcmap_/ { n++; if ($0 !~ /mov +eax, 0/) bad++ } END { printf "%d %d\n", n, bad }' "$1"; }
read -r cnr cbad < <(sed -E 's/^([[:space:]]*)mov +eax, 0( +#.*)$/\1nop\2/' "$W/a.s" | tee "$W/canary.s" >/dev/null; struct "$W/canary.s")
[ "${cnr:-0}" -gt 0 ] && [ "${cbad:-0}" -gt 0 ] || refuse "canary: witness A with every anchor's 'mov eax, 0' replaced by a nop did NOT read red (maps=$cnr bad=$cbad) -- an arm that cannot say no certifies nothing"
for w in a b; do
  read -r nmap nbad < <(struct "$W/$w.s")
  [ "${nmap:-0}" -gt 0 ] || refuse "witness $w's .s carries no prologue anchor note -- the structural arm has nothing to examine"
  if [ "$nbad" -eq 0 ]; then echo "  ok   $w structural: $nmap prologue anchors, each riding mov eax, 0"
  else echo "  RED  $w structural: $nbad of $nmap prologue anchors do not ride mov eax, 0"; fails=$((fails+1)); fi
done
echo "canary: every anchor's 'mov eax, 0' replaced by a nop in witness A reads RED ($cbad of $cnr) ok"
if [ "$fails" -eq 0 ]; then echo "GATE PASS(0) [$G]: body-less procedures return a defined result, both modes, 2 witnesses + structural"; exit 0; fi
echo "GATE FAIL(1) [$G]: $fails red arm(s)"; exit 1
