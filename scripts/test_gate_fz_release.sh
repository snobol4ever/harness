#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ../harness/scripts/test_gate_fz_release.sh
# FZ (FENCE0 SELECTIVE RELEASE) GATE -- two independent locks over corpus/probe/fz.
#   LOCK 1 (verdict): every witness, DISARMED (SCRIP_FENCE0_WHACK=0), m3 and m4, byte-equal to its
#           oracle .ref.  s172 FLIPPED THE DEFAULT ON, so this is no longer the shipped arm -- it is
#           the KILLSWITCH RETREAT, and that is exactly why the lock keeps its verdict: an escape
#           hatch nobody tests is not an escape hatch.  Red here means the retreat path rotted.
#   LOCK 2 (verdict): NO OVER-RELEASE.  Re-derives each fence's releasable carve FROM THE EMITTED ASM
#           -- follows the alpha-chain from each match_begin box, sums `sub rsp,N` over the contiguous
#           registered leaf boxes at the frontier, and asserts the fence's own `add rsp,R` never
#           exceeds it.  This is the FZ-1 defect's tripwire (it billed 32 against a 16 carve) and it
#           pins NO golden: it checks the compiler's claim against the compiler's own output.
#   LOCK 5 (verdict): the same armed witnesses on the SECOND depth spelling -- bb_match_replace's
#           non-rbp cursor/end road (SCRIP_MATCH_RBP=0), which reads op_zpat rather than the depth
#           accumulator.  s168 found FZ-3 living there too (fz7 printed `R=Zaaabbbccc` for `R=Zccc`
#           while op_zpat read 48 in BOTH arms), so it gets its own lock; witnesses whose road is
#           already red DISARMED are skipped, because that is not an FZ fact.
#   LOCK 3 (verdict): every witness, ARMED, m3 and m4, byte-equal to its oracle .ref.  This is the
#           FZ-3 tripwire and it replaces the s166 "REPORT (never a verdict)" line, which existed only
#           because the release was invisible to the depth planner and the armed board was therefore
#           expected to be red.  s168 threaded the release through zd_plan's depth accumulator, so the
#           armed board is now expected to be GREEN and a red LOCK 3 means the depth model stopped
#           spending what the cut spends -- exactly the skew that printed `abbb` for `aaabbb`.  It is
#           proven NON-VACUOUS the same way LOCK 2 was: it goes RED on the pre-fix baseline binary.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
RT_DIR="${RT_DIR:-$HERE/../../SCRIP/out}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built"; exit 2; }
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
# ⭐ RE-POINTED 2026-08-29 (seat16, corpus-crosscheck-probe-total-conversion clause 3): corpus/probe/fz/
# is gone -- converted to corpus/tests/snobol4/probe/fz.{sno,ref} (corpus-suites-consolidation format).
# Same idiom as util_zsm_beta_skew_census.sh's ptc-grid re-point: extract every entry via
# corpus_suite_harness.py (the ONE parsing authority) into a scratch dir, then use that as FZ so every
# LOCK below -- including LOCK 2/4's raw-asm regex analysis, which needs standalone files to feed
# `--compile` directly under different env-var arms -- is unchanged. extract() is byte-equal by the
# same law that gated the conversion itself, so this is a pure re-point: verified via a before/after
# full-output diff against the pre-conversion loose-file run (see the conversion commit).
# An explicit FZ override (a caller's own standalone witness dir) is used AS-IS, exactly as before --
# extraction only runs on the default path, so override semantics are unchanged.
if [ -z "${FZ:-}" ]; then
    RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$(dirname "${BASH_SOURCE[0]}")/lib_rungs_extract.sh"   # re-pointed to THE RUNGS (zero-subfolders cutover, ceo s283h): family probe_fz
    FZ="$WORK/fz_src"; mkdir -p "$FZ"
    rungs_extract_family probe_fz "$FZ" || true
fi
[ -d "$FZ" ] && [ -n "$(ls -A "$FZ" 2>/dev/null)" ] || { echo "⛔ REFUSED-TO-GRADE no $FZ (suite missing or extraction failed)"; exit 2; }
rc=0
echo "=== FZ GATE -- LOCK 1: witnesses vs oracle .ref, DISARMED default, both modes ==="
for sno in "$FZ"/*.sno; do
    b=$(basename "$sno" .sno); ref="$FZ/$b.ref"
    [ -f "$ref" ] || { echo "  MISS   $b (no .ref)"; rc=1; continue; }
    m3=$(SCRIP_FENCE0_WHACK=0 timeout -k 5 10s "$SCRIP" --run "$sno" < /dev/null 2>&1)
    ok3=FAIL; [ "$m3" = "$(cat "$ref")" ] && ok3=PASS
    m4=FAIL
    if SCRIP_FENCE0_WHACK=0 timeout -k 5 20s "$SCRIP" --compile "$sno" < /dev/null > "$WORK/$b.s" 2>/dev/null \
       && gcc -no-pie -o "$WORK/$b.bin" "$WORK/$b.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" 2>/dev/null; then
        out=$(timeout -k 5 20s "$WORK/$b.bin" < /dev/null 2>&1); [ "$out" = "$(cat "$ref")" ] && m4=PASS
    fi
    printf '  %-32s m3=%s m4=%s\n' "$b" "$ok3" "$m4"
    [ "$ok3" = PASS ] && [ "$m4" = PASS ] || rc=1
done
echo "=== FZ GATE -- LOCK 2: no over-release (re-derived from emitted asm, ARMED) ==="
for sno in "$FZ"/*.sno; do
    b=$(basename "$sno" .sno)
    SCRIP_FENCE0_WHACK=1 timeout -k 5 20s "$SCRIP" --compile "$sno" < /dev/null > "$WORK/$b.armed.s" 2>/dev/null || { echo "  SKIP   $b (compile failed)"; continue; }
    python3 - "$WORK/$b.armed.s" "$b" <<'PY' || rc=1
import re, sys
path, name = sys.argv[1], sys.argv[2]
LEAF = ('match_span','match_break','match_breakx','match_tab','match_rtab','match_rem','match_bal')
lines = open(path, encoding='utf-8', errors='replace').read().splitlines()
# Parse BOXES: a box opens at `nK_kind_α:` and its ALPHA REGION runs until that box's own beta/gamma/omega
# label or the next box's alpha.  Within the alpha region we take the carve (`sub rsp,N`), the release
# (`add rsp,N` on the alpha line itself) and the FORWARD exit (last `jmp nJ_..._α`).
boxes, cur = {}, None
for ln in lines:
    m = re.match(r'^(n\d+)_([a-z0-9_]+)_(α|β|γ|ω):(.*)$', ln)
    if m:
        lbl, kind, port, rest = m.group(1), m.group(2), m.group(3), m.group(4)
        if port == 'α':
            cur = lbl; boxes[lbl] = dict(kind=kind, sub=0, rel=0, jmp=None)
            a = re.search(r'\badd\s+rsp,\s*(\d+)', rest)
            if a: boxes[lbl]['rel'] = int(a.group(1))
        else:
            cur = None
        body = rest
    else:
        body = ln
    if cur is None: continue
    sm = re.search(r'\bsub\s+rsp,\s*(\d+)', body)
    if sm: boxes[cur]['sub'] += int(sm.group(1))
    jm = re.findall(r'\bjmp\s+(n\d+)_[a-z0-9_]+_α', body)
    if jm: boxes[cur]['jmp'] = jm[-1]
bad, told = 0, set()
for start in [l for l in boxes if boxes[l]['kind'] == 'match_begin']:
    chain, seen, cur, guard = [], set(), boxes[start]['jmp'], 0
    while cur and cur in boxes and cur not in seen and guard < 10000:
        guard += 1; seen.add(cur)
        if boxes[cur]['kind'] == 'match_fence0':
            budget = 0
            for prev in reversed(chain):
                k = boxes[prev]['kind']
                if k.startswith(LEAF): budget += boxes[prev]['sub']; continue
                if boxes[prev]['sub'] == 0: continue
                break
            rel = boxes[cur]['rel']
            if rel > budget:
                bad = 1
                if cur not in told:
                    told.add(cur); print("  OVER-RELEASE %s: %s releases %d but only %d bytes of registered carve stand at the frontier" % (name, cur, rel, budget))
        chain.append(cur); cur = boxes[cur]['jmp']
print("  %-32s %s" % (name, "OK (no fence releases more than its carve)" if not bad else "OVER-RELEASE DETECTED"))
sys.exit(1 if bad else 0)
PY
done
echo "=== FZ GATE -- LOCK 3: witnesses vs oracle .ref, ARMED, both modes (the FZ-3 tripwire) ==="
for sno in "$FZ"/*.sno; do
    b=$(basename "$sno" .sno); ref="$FZ/$b.ref"
    [ -f "$ref" ] || { echo "  MISS   $b (no .ref)"; rc=1; continue; }
    m3=$(SCRIP_FENCE0_WHACK=1 timeout -k 5 10s "$SCRIP" --run "$sno" < /dev/null 2>&1)
    ok3=FAIL; [ "$m3" = "$(cat "$ref")" ] && ok3=PASS
    m4=FAIL
    if SCRIP_FENCE0_WHACK=1 timeout -k 5 20s "$SCRIP" --compile "$sno" < /dev/null > "$WORK/$b.a.s" 2>/dev/null \
       && gcc -no-pie -o "$WORK/$b.a.bin" "$WORK/$b.a.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" 2>/dev/null; then
        out=$(timeout -k 5 20s "$WORK/$b.a.bin" < /dev/null 2>&1); [ "$out" = "$(cat "$ref")" ] && m4=PASS
    fi
    printf '  %-32s m3=%s m4=%s\n' "$b" "$ok3" "$m4"
    [ "$ok3" = PASS ] && [ "$m4" = PASS ] || rc=1
done
echo "=== FZ GATE -- LOCK 4: the cut is visible to the depth planner (armed offsets REBASE) ==="
for sno in "$FZ"/*.sno; do
    b=$(basename "$sno" .sno)
    SCRIP_FENCE0_WHACK=0 timeout -k 5 20s "$SCRIP" --compile "$sno" < /dev/null > "$WORK/$b.d0.s" 2>/dev/null || continue
    SCRIP_FENCE0_WHACK=1 timeout -k 5 20s "$SCRIP" --compile "$sno" < /dev/null > "$WORK/$b.a0.s" 2>/dev/null || continue
    python3 - "$WORK/$b.d0.s" "$WORK/$b.a0.s" "$b" <<'PY' || rc=1
import re, sys
dis, arm, name = open(sys.argv[1]).read().split("\n"), open(sys.argv[2]).read().split("\n"), sys.argv[3]
if len(dis) != len(arm):
    print("  %-32s LINE COUNT MOVED (%d vs %d) -- the arm changed more than the cut" % (name, len(dis), len(arm))); sys.exit(1)
rel = sum(int(m.group(1)) for l in arm for m in [re.search(r"match_fence0_\u03b1:.*add\s+rsp,\s*(\d+)", l)] if m)
reads = sum(1 for a, b in zip(dis, arm) if a != b and "rsp + " in a)
adds  = sum(1 for a, b in zip(dis, arm) if a != b and "match_fence0" in b)
other = sum(1 for a, b in zip(dis, arm) if a != b) - reads - adds
if rel == 0:
    print("  %-32s NO RELEASE (bills 0) -- vacuous for this lock, not an error" % name); sys.exit(0)
if other:
    print("  %-32s ARM MOVED %d LINE(S) THAT ARE NEITHER THE CUT NOR A STAGED OFFSET" % (name, other)); sys.exit(1)
print("  %-32s OK (releases %dB; %d cut line(s), %d staged offset(s) rebased)" % (name, rel, adds, reads)); sys.exit(0)
PY
done
echo "=== FZ GATE -- LOCK 5: the OTHER depth spelling (op_zpat road, SCRIP_MATCH_RBP=0), ARMED ==="
for sno in "$FZ"/*.sno; do
    b=$(basename "$sno" .sno); ref="$FZ/$b.ref"
    [ -f "$ref" ] || continue
    got=$(SCRIP_MATCH_RBP=0 SCRIP_FENCE0_WHACK=1 timeout -k 5 10s "$SCRIP" --run "$sno" < /dev/null 2>&1)
    base=$(SCRIP_MATCH_RBP=0 SCRIP_FENCE0_WHACK=0 timeout -k 5 10s "$SCRIP" --run "$sno" < /dev/null 2>&1)
    if [ "$base" != "$(cat "$ref")" ]; then printf '  %-32s SKIP (this road is red DISARMED too -- not an FZ fact)\n' "$b"; continue; fi
    if [ "$got" = "$(cat "$ref")" ]; then printf '  %-32s PASS\n' "$b"; else printf '  %-32s FAIL (armed diverges on the non-rbp road)\n' "$b"; rc=1; fi
done
[ $rc -eq 0 ] && echo "FZ GATE: GREEN" || echo "FZ GATE: RED"
exit $rc
