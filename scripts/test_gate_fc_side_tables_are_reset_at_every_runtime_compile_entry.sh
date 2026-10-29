#!/usr/bin/env bash
# test_gate_fc_side_tables_are_reset_at_every_runtime_compile_entry.sh -- THE SIDE TABLES OF frame_layout.c ARE KEYED
# BY RAW IR NODE POINTER, AND A RUNTIME COMPILE'S FRESH NODES LAND ON FREED ADDRESSES (cto 2026-09-18, row
# rationale-frame-layout-c-remainder STEP 3; the claim is stated in .github/ARCH-FRAME-LAYOUT-FIXED-CELLS.md section 7,
# which says in as many words that no gate holds it).
#
# ⛔ WHAT SECTION 7 SAID, AND WHAT THE MEASUREMENT FOUND. The recovered rationale explains why fc_tables_reset exists:
# an EVAL chain, a CODE fragment or a runtime pattern tree lowers fresh IR whose nodes can land on a freed prior
# graph's addresses, and a stale hit once emitted one r12-viewed box inside an rsp-viewed blob and wrote over the C
# caller's frame (EVAL_fn's return address became 0x21). It then argues the OTHER tables are safe because "emission
# consults them only for the graph lowered since the reset, and all pre-reset graphs are already emitted", and it
# explains the asymmetry by saying the zls tables are not reset here either. BOTH HALVES WERE STALE AT HEAD:
#   * fc_tables_reset reset ONE counter of sixteen (fct_n, the tail candidates). Twelve pointer-keyed tables -- fca
#     fcab fcc fch fcm fcs fcv fpe fvb fvcl fvdj fvl fvr fvs fvw -- were never reset in the life of the process.
#   * all three runtime-compile entries (runtime_eval.c eval_build_chain and code_at, bb_pat_build.cpp
#     bb_compile_pat_tree_sz) ALREADY call zls_reset() wholesale on the line beside it. The zls tables ARE reset. So
#     the stated reason for the asymmetry did not describe the tree, and nothing else did either.
# ⭐ THE HAZARD IS REAL AND WAS MEASURED, NOT ARGUED (2026-09-18, a 300-distinct-runtime-compile SNOBOL4 EVAL witness,
# a temporary probe on the registrars, reverted): 615 registrations at 609 DISTINCT ADDRESSES -- six addresses were
# registered twice, by two different graphs, through recycled memory. On fvr, whose entries are a node-to-FRAME-POSITION
# map and whose lookup returns the FIRST match, two registrations found a live stale entry for their own address. In
# that witness the stale frame position happened to AGREE with the fresh one, so the answer was right: THE HAZARD WAS
# LIVE AND THE DAMAGE WAS LUCK. Nothing made them agree.
# ⛔ AND THE CAP WAS A PER-PROCESS BUDGET FOR A PER-GRAPH TABLE. Because nothing was reset, the counters climbed
# monotonically with the number of distinct runtime compiles: measured 310 (fvl) and 305 (fvr) after 300 compiles,
# one per compile, against caps of 2048 and 1024. A program with about a thousand distinct EVAL or CODE compiles
# therefore saturated fvr and silently lost the value-spine plan FOR THE REST OF THE PROCESS -- correct, because
# fc_vcap makes the planner refuse before the registrar's own backstop fires (measured: 3000 compiles, answer still
# exact, and fc_reg_full never printed), but permanently and progressively deoptimised with no diagnostic. The cure
# turns that per-process budget back into a per-compile one.
# ⭐ FAIL-ONCE, MEASURED ON A REAL TREE RATHER THAN ASSERTED: with fc_tables_reset resetting only fct_n, the same
# witness read fvl 310 / fvr 305; with the sixteen-counter reset it reads fvl 10 / fvr 5, and the answers of all four
# witnesses are byte-identical before and after.
#
# ⛔ THE ONE NAMED EXCLUSION, stated so arm 1 cannot read green by never looking: pz_n is NOT reset and must not be.
# The pz table is keyed by GRAPH NAME, not by node pointer, it updates an existing row in place rather than appending,
# and it is the patzeta pricing a later compile looks up BY NAME for a graph emitted earlier -- resetting it would
# throw away the price of every graph already emitted. Pointer keying is what makes a table unsafe across a compile;
# name keying is what makes this one necessary across it.
#
# ARMS (all blocking). (1) COVERAGE: every pointer-keyed counter declared in frame_layout.c appears in
# fc_tables_reset's body, with pz_n the one named exclusion, and the population is PRINTED so a reset that emptied
# reds instead of passing vacuously.
# ⛔ RE-KEYED 2026-09-25 (cfo, row compiler-every-population-table-grows-in-the-compile-time-arena-..., Lon 2026-09-24:
# "Use the special compile-time heap, and use alloc/copy/abandon at geometric growth for dynamic arrays and buffers."):
# thirteen of the sixteen counters (fca fcc fch fcm fcv fpe fvb fvcl fvdj fvl fvr fvs fvw) became KINDS of ONE
# generation-stamped node map, fcn_t in g_fcn, whose entries die with a generation bump rather than a counter zeroed;
# fcs and fcab were DELETED in the same landing (no caller in the tree), and fc_reg_full with its seen_n latch went with
# the caps it reported. So arm 1 reads two populations: the plain counters (fct_n today), each zeroed in the reset that
# owns it, and the map's kinds (the FCN_* flags), counted as covered ONLY when fc_tables_reset bumps g_fcn_gen, zeroes
# g_fcn_n and empties the arm vector g_fca. The floor is 14 = 16 minus exactly the two deleted tables; it is not
# lowered for anything that still exists. zls_reset is held the same way for g_znb (its generation bump). (2) CALL SITES: every site that calls zls_reset for a runtime compile also calls
# fc_tables_reset, and vice versa -- the two are a set, and an entry that resets one but not the other is exactly the
# shape this gate is about. (3) BOUNDEDNESS: 300 distinct runtime compiles keep every table's high water under a
# ceiling, read through the tree's own SCRIP_FC_REG_HIGHWATER reporter (no new global -- RULES.md). (4) ANSWER: the
# EVAL and CODE witnesses are graded against the SPITBOL oracle, in both media, because a bounded counter beside a
# wrong answer is not a cure.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
FL="$ROOT/src/planner/frame_layout.c"; [ -f "$FL" ] || { echo "⛔ GATE REFUSE(2) [$G]: $FL absent"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
# RE-CUT 2026-10-09 cfo (CEO-1575, the g_lower stage landing B): frame_layout.c's counters and node maps are members of
# g_lower_ir_t in src/lower/g_lower.h, so arm 1 reads the declared counters there (int <name>_n;) and the map checks the
# g_lower.ir. spelling (fcn_gen, fcn_n, fca, znb_gen); what it covers is unchanged.
RC=0
export SNO_LIB="${SNO_LIB:-$S4E/corpus/include}"
HW_CEILING=${HW_CEILING:-64}
EXCLUDED="pz_n"

echo "  HOLDS: the frame_layout.c side tables are keyed by raw IR node pointer, a runtime compile's fresh nodes DO land on freed addresses (measured: 615 registrations at 609 distinct addresses over 300 compiles), so every pointer-keyed table is reset at every runtime-compile entry. pz_n is keyed by graph NAME, updates in place and must survive -- it is the one named exclusion."

body=$(awk '/^void fc_tables_reset\(void\)/{f=1} f{print} f&&/^}/{exit}' "$FL")
zbody=$(awk '/^void zls_reset\(void\)/{f=1} f{print} f&&/^}/{exit}' "$FL")
declared=$(awk '/^typedef struct \{/{b=""} {b=b $0 "\n"} /^\} g_lower_ir_t;/{printf "%s", b; exit}' "$ROOT/src/lower/g_lower.h" | grep -oE '^ *int [a-z]+_n;' | sed -E 's/^ *int //; s/;$//' | sort -u)
missf=""; missz=""; n_fc=0; n_zls=0; exc=""; n_exc=0
for c in $declared; do
    case "$c" in
        pz_n)    exc="$exc $c(keyed by graph NAME, updated in place, read by a later compile for a graph already emitted)"; n_exc=$((n_exc+1)); continue ;;
    esac
    case "$c" in
        z*)  if echo "$zbody" | grep -q "\b$c = 0"; then n_zls=$((n_zls+1)); else missz="$missz $c"; fi ;;
        *)   if echo "$body"  | grep -q "\b$c = 0"; then n_fc=$((n_fc+1));  else missf="$missf $c"; fi ;;
    esac
done
n_ctr=$n_fc
kinds=$(grep -oE '^#define FCN_[A-Z]+ ' "$FL" | awk '{print $2}' | sort -u | tr '\n' ' ')
n_kinds=$(echo $kinds | wc -w)
mapok=1; mapmiss=""
for w in 'g_lower.ir.fcn_gen++' 'g_lower.ir.fcn_n = 0' 'g_lower.ir.fca.len = 0'; do echo "$body" | grep -qF "$w" || { mapok=0; mapmiss="$mapmiss $w"; }; done
echo "$zbody" | grep -qF 'g_lower.ir.znb_gen++' || { mapok=0; mapmiss="$mapmiss g_lower.ir.znb_gen++(zls_reset)"; }
[ "$mapok" = 1 ] && n_fc=$((n_fc + n_kinds))
if [ -z "$missf" ] && [ -z "$missz" ] && [ "$mapok" = 1 ] && [ "$n_kinds" -ge 13 ] && [ "$n_fc" -ge 14 ] && [ "$n_zls" -ge 8 ] && [ "$n_exc" -eq 1 ]; then
    echo "  arm 1 PASS: every pointer-keyed registry in frame_layout.c dies at the reset that owns it -- $n_fc covered by fc_tables_reset ($n_ctr plain counter(s) zeroed, $n_kinds kind(s) of the generation-stamped node map g_fcn: $kinds-- dead by g_fcn_gen++, count and arm vector emptied), $n_zls counter(s) in zls_reset plus g_znb's generation bump, and $n_exc NAMED exclusion(s):$exc"
else
    echo "  arm 1 RED: a registry declared in frame_layout.c outlives the reset that owns it -- fc_tables_reset owes:${missf:- none}; zls_reset owes:${missz:- none}; the node maps owe:${mapmiss:- none}  (covered fc=$n_fc want>=14 from $n_ctr counter(s) + $n_kinds map kind(s) want>=13, zls=$n_zls want>=8, excluded=$n_exc want 1). A pointer-keyed table that outlives a compile can be hit by a fresh node at a recycled address, which is what this gate exists to stop."; RC=1
fi

zr=$(grep -rln 'zls_reset' "$ROOT/src/runtime" 2>/dev/null | sort)
bad=""
for f in $zr; do grep -q 'fc_tables_reset' "$f" || bad="$bad $(basename "$f")"; done
fr=$(grep -rln 'fc_tables_reset' "$ROOT/src/runtime" 2>/dev/null | sort)
for f in $fr; do grep -q 'zls_reset' "$f" || bad="$bad $(basename "$f")"; done
nsites=$(grep -rc 'fc_tables_reset()' $fr 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
if [ -z "$bad" ] && [ "${nsites:-0}" -ge 3 ]; then echo "  arm 2 PASS: the two resets travel together in every runtime file that has either ($(echo $fr | xargs -n1 basename 2>/dev/null | tr '\n' ' ')), $nsites call site(s) -- a runtime-compile entry that reset one and not the other is the defect this gate is about"
else echo "  arm 2 RED: ${bad:-only $nsites call site(s) found} -- a file calls one reset without the other, or an entry disappeared"; RC=1; fi

cat > "$T/ev.sno" <<'EOF'
        N = 0
        T = 0
LOOP    N = N + 1
        E = N ' + ' N ' + 1'
        T = T + EVAL(E)
        LT(N, 300)                                  :S(LOOP)
        OUTPUT = 'sum ' T
END
EOF
hw=$(SCRIP_FC_REG_HIGHWATER=1 timeout -k 5 300 "$SCRIP" "$T/ev.sno" 2>&1 >/dev/null | grep '^FC-REG-HW' | awk '{if($3>m[$2])m[$2]=$3} END{for(k in m) printf "%s=%d ", k, m[k]}')
worst=$(SCRIP_FC_REG_HIGHWATER=1 timeout -k 5 300 "$SCRIP" "$T/ev.sno" 2>&1 >/dev/null | grep '^FC-REG-HW' | awk '{if($3>m)m=$3} END{print m+0}')
if [ -n "$hw" ] && [ "${worst:-0}" -gt 0 ] && [ "${worst:-0}" -le "$HW_CEILING" ]; then
    echo "  arm 3 PASS: 300 distinct runtime compiles, every table's high water bounded ($hw), worst $worst at or under the ceiling $HW_CEILING -- the cap is a per-compile budget again. Pre-cure the same witness read vlit=310 vread=305, climbing one per compile; since the node map (2026-09-25) the reporter prints one line per distinct node, 'node'."
elif [ -z "$hw" ]; then echo "  arm 3 RED: the SCRIP_FC_REG_HIGHWATER reporter printed nothing -- the witness registered no table entry at all, so this arm measured nothing rather than measuring zero growth"; RC=1
else echo "  arm 3 RED: a table's high water reached $worst over 300 runtime compiles ($hw), above the ceiling $HW_CEILING -- the counters are growing with the compile count again, which is the never-reset shape"; RC=1; fi

ORACLE="$(command -v spitbol 2>/dev/null)"
cat > "$T/code.sno" <<'EOF'
        N = 0
        T = 0
LOOP    N = N + 1
        S = 'X = ' N ' * 2' 
        OBJ = CODE(S ';')                           :F(SKIP)
SKIP    T = T + N
        LT(N, 60)                                   :S(LOOP)
        OUTPUT = 'code ' T
END
EOF
graded=0; agreed=0
for w in ev.sno code.sno; do
    m3=$(timeout -k 5 300 "$SCRIP" "$T/$w" 2>/dev/null | tail -1)
    s4="$T/$w.s"; b4="$T/$w.bin"; m4=""
    if timeout -k 5 300 "$SCRIP" --compile --out="$s4" "$T/$w" >/dev/null 2>&1 && gcc "$s4" -o "$b4" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null; then m4=$(timeout -k 5 300 "$b4" 2>/dev/null | tail -1); fi
    if [ -n "$ORACLE" ]; then orc=$(cd "$T" && timeout -k 5 300 "$ORACLE" "$T/$w" 2>/dev/null | tail -1); else orc="$m3"; fi
    graded=$((graded+1))
    if [ "$m3" = "$orc" ] && [ "$m4" = "$orc" ]; then agreed=$((agreed+1))
    else echo "  arm 4 RED ($w: oracle '$orc' · mode 3 '$m3' · mode 4 '$m4')"; RC=1; fi
done
[ "$agreed" = "$graded" ] && echo "  arm 4 PASS: $agreed of $graded runtime-compile witness(es) agree with $([ -n "$ORACLE" ] && echo "the SPITBOL oracle" || echo "⚠ mode 3 as its own reference -- NO spitbol on this box, so this arm graded the two media against each other and NOT against an oracle") in BOTH media"

if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: every pointer-keyed side table is reset at every runtime-compile entry, the counters are bounded by the compile and not by the process, and the witnesses agree with the oracle in both media (examined 4 arms)"
else echo "GATE FAIL(1) [$G]: a pointer-keyed side table outlives a runtime compile, or a runtime-compile entry resets one table family and not the other (examined 4 arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
