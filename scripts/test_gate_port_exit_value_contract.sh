#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_port_exit_value_contract.sh — THE PORT-EXIT VALUE CONTRACT gate.
# Row: port-exit-value-contract-untagged-rax-forges-dt-fail (hq_P-owned; class triaged by hq_C from
# seat09's Pascal root-cause).  Built by seat02 2026-09-01 as that row's CENSUS+GATE rung.
#
# THE CONTRACT: a procedure-level success exit (`<proc>_γ:` opening `mov rdi, rax` / `mov rsi, rdx`)
# forwards rax:rdx as the procedure's DESCR_t return value, and the caller detects a failed nested
# call with `cmp al, 104` (DT_FAIL = 0x68; DESCR_t.v is uint8_t, so the tag IS rax's low byte).
# EVERY transfer reaching such an exit must therefore arrive with a real DESCR_t in rax:rdx.
# A transfer arriving with an untagged value forges DT_FAIL whenever that value's low byte is 104 —
# a silent, data-dependent (or, for a `lea`'d code address, LINK-LAYOUT-dependent) wrong answer that
# cascades a spurious ω one frame at a time up the entire live call chain.
#
# ⭐ IT IS A GENERATION-TIME CHECK, DELIBERATELY, per the row's DONE-WHEN: the defect is
# data-dependent, so a runtime assert fires only on the inputs that already broke.  This reads the
# emitted mode-4 TEXT and answers the question for every path, including unexercised ones.
# ⛔ MODE-SCOPED (MODES MAY DIVERGE, Lon 2026-08-28): this reads mode-4 TEXT and binds mode 4 only.
#
# Usage: bash ../harness/scripts/test_gate_port_exit_value_contract.sh [--informational] [-- <program>...]
#        SCRIP_PEVC_PROGRAMS="a.pas b.pl"  bash ../harness/scripts/test_gate_port_exit_value_contract.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
GATE_NAME="port-exit-value-contract"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"

SCAN="$HERE/port_exit_value_contract_scan.py"
gate_require_exec "$ROOT/scrip" "the scrip compiler (make -j4 scrip)"
gate_require "$SCAN" "the scan half of this gate"

CORP="$(cd "$ROOT/../corpus" 2>/dev/null && pwd || true)"
# ⛔⭐⭐ AN UNRESOLVABLE *NAMED* WITNESS REFUSES rc=2 -- IT DOES NOT SILENTLY SHRINK THE POPULATION (ceo ruling 2026-09-02,
# GOAL-CEO CEO-151; found by hq_P while curing the demo regen).  This roster used to name `demos/prolog/family.pl`, which has
# not existed since 924bd8bd0 renamed corpus/demo -> corpus/demos (the file is and was `family_prolog.pl`).  The gather was
# `[ -f ... ] && PROGS+=(...)`, so the missing name was DROPPED WITHOUT A WORD and the gate went green over FIVE witnesses
# while reading -- to anyone looking at the roster -- as if it had covered six.  ⛔ NOT A FALSE GREEN: A QUIETLY NARROWED ONE,
# which is worse, because a false green is disbelieved the moment anyone checks and a narrowed one survives every check.
# ⭐ THE LAW (RULES.md § THE INSTRUMENT LAWS, measured vs never ran): a NAMED witness that does not resolve is a measurement
# that NEVER RAN, and an instrument may not report the absence of evidence as evidence of absence.  The old `${#PROGS[@]} -eq 0`
# refusal below only fired when ALL SIX vanished -- it guarded the empty case and left every partial case wide open.
# ⛔ THE DISTINCTION THIS KEEPS: a NAMED witness that will not COMPILE is still excluded-with-a-warning further down, because
# that is a measurement that ran and came back negative.  Unresolvable is not the same as uncompilable, and only the first is
# a refusal: the gate cannot tell the difference between a witness deliberately retired and one lost to a rename, so it stops.
MISSING=()
if [ -n "${SCRIP_PEVC_PROGRAMS:-}" ]; then
    read -r -a NAMED <<< "$SCRIP_PEVC_PROGRAMS"; NAMED_SRC="SCRIP_PEVC_PROGRAMS"; PROGS=()
    for p in "${NAMED[@]}"; do if [ -f "$p" ]; then PROGS+=("$p"); else MISSING+=("$p"); fi; done
else
    NAMED_SRC="this gate's default roster"; PROGS=()
    for p in benchmarks/pascal/quick.pas benchmarks/pascal/queens.pas benchmarks/pascal/perm.pas \
             benchmarks/pascal/fbench.pas demos/prolog/family_prolog.pl benchmarks/icon/tgrlink.icn; do
        if [ -n "$CORP" ] && [ -f "$CORP/$p" ]; then PROGS+=("$CORP/$p"); else MISSING+=("$p"); fi
    done
fi
if [ "${#MISSING[@]}" -ne 0 ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: ${#MISSING[@]} of $(( ${#MISSING[@]} + ${#PROGS[@]} )) named witness(es) in $NAMED_SRC do not resolve (corpus at '${CORP:-?}'):"
    printf '      ⛔ %s\n' "${MISSING[@]}"
    echo "    This is NOT a pass and NOT a smaller board. A NAMED witness that does not resolve is a measurement that NEVER RAN;"
    echo "    certifying the ${#PROGS[@]} that did resolve would report less coverage than the roster claims, silently."
    echo "    Cure: re-point the name (a rename), or delete it from the roster (a retirement) -- both are edits someone must make."
    gate_stamp; exit 2
fi
[ "${#PROGS[@]}" -eq 0 ] && { echo "GATE UNPROVEN(2) [$GATE_NAME]: no witness programs found (corpus at '${CORP:-?}')";
                              echo "    This is NOT a pass. The gate compiled nothing, so it certifies nothing."; gate_stamp; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pevc.XXXXXX")"; trap 'rm -rf "$WORK"' EXIT
ASM=(); BUILT=0
for f in "${PROGS[@]}"; do
    b="$(basename "$f" | tr './' '__')"
    if SCRIP_PORT_EXIT_AUDIT=1 timeout -k 5 60s "$ROOT/scrip" --compile "$f" < /dev/null > "$WORK/$b.s" 2>"$WORK/$b.audit" && [ -s "$WORK/$b.s" ]; then
        ASM+=("$WORK/$b.s"); BUILT=$((BUILT+1))
    else
        echo "   ⚠ could not compile, excluded from the verdict: $f"
    fi
done
[ "$BUILT" -eq 0 ] && { echo "GATE UNPROVEN(2) [$GATE_NAME]: every witness failed to compile";
                        echo "    This is NOT a pass. 'measured and clean' and 'never ran' must not share an output."; gate_stamp; exit 2; }

JSON="$WORK/scan.json"
# ⛔ THE CALL ARM'S ALLOW-LIST, DERIVED FROM SOURCE EVERY RUN (seat03 2026-09-01).  The scanner used to treat
# every `call` as DESCR-returning; measured, 9 of 10 such transfers in this witness set call int-returning
# runtime functions, so the reported violation count was half the real one.  Derived here rather than
# hand-maintained, because a hand list decays and this gate's whole purpose is to not depend on a census
# staying complete.  Fail-closed: the scanner REFUSES if this file is missing or empty.
DFNS="$WORK/descr_fns.txt"
grep -rhoE '\bDESCR_t[[:space:]]+\**[[:space:]]*(rt_|c_rt_|scrip_)[A-Za-z0-9_]+[[:space:]]*\(' \
     "$ROOT/src/runtime/" "$ROOT/src/ir/" 2>/dev/null \
  | sed -E 's/^DESCR_t[[:space:]]*\**[[:space:]]*//; s/[[:space:]]*\($//' | sort -u > "$DFNS"
if [ ! -s "$DFNS" ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: could not derive the DESCR-returning symbol set from src/"
    echo "    This is NOT a pass. With an empty allow-list every call reads as a violation."; gate_stamp; exit 2
fi
echo "   DESCR-returning runtime symbols in the call allow-list: $(wc -l < "$DFNS")"
python3 "$SCAN" "--descr-fns=$DFNS" "${ASM[@]}" > "$JSON" 2>"$WORK/scan.err" || {
    echo "GATE UNPROVEN(2) [$GATE_NAME]: the scanner itself failed"; sed -n '1,10p' "$WORK/scan.err"; gate_stamp; exit 2; }

read -r EXITS XFERS VIOL <<< "$(python3 - "$JSON" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
e=sum(len(f['exits']) for f in r); x=sum(len(f['findings']) for f in r)
v=sum(1 for f in r for y in f['findings'] if y['verdict']=='RAW')
print(e,x,v)
PY
)"
python3 - "$JSON" <<'PY'
import json,sys,collections
r=json.load(open(sys.argv[1]))
c=collections.Counter(y['verdict'] for f in r for y in f['findings'])
print("   programs %d | rax-forwarding procedure exits %d | transfers into them %d"
      % (len(r), sum(len(f['exits']) for f in r), sum(len(f['findings']) for f in r)))
print("   " + "  ".join("%s=%d"%(k,v) for k,v in sorted(c.items())))
for f in r:
    bad=[y for y in f['findings'] if y['verdict']=='RAW']
    if not bad: continue
    print("   ⛔ %s" % f['file'].split('/')[-1])
    for y in bad[:6]:
        print("        line %-7d %-5s -> %-22s %s" % (y['line'],y['mnem'],y['target'],y['detail'][:88]))
    if len(bad)>6: print("        ... and %d more" % (len(bad)-6))
PY

# ⭐⭐ TWO INDEPENDENT INSTRUMENTS MUST AGREE, AND BOTH ARE PRINTED FROM THIS ONE COMMAND (RULES.md
# INSTRUMENT LAWS thirteenth batch: an invariant that lives in the gap between two sites is held by
# neither; a probe that prints both sides turns a future divergence into a run instead of a re-derivation).
#   SIDE A -- the EMITTER's own view: x86_port_hook fires [PORT-EXIT-PROMOTION] under SCRIP_PORT_EXIT_AUDIT=1
#             at the one chokepoint every port transfer passes, when the target IS the chain's own γ label.
#   SIDE B -- the post-hoc TEXT scan above, which finds procedure exits by their `mov rdi, rax` promotion.
# They are derived from completely different evidence, so agreement is real cross-validation and a
# DISAGREEMENT IS ITSELF A FINDING -- it means one of the two has drifted from what the compiler does.
# ⛔⭐ IT IS A SUBSET CHECK, NOT AN EQUALITY, AND THAT ASYMMETRY IS MEASURED RATHER THAN ASSUMED.
# The emitter side is KNOWN INCOMPLETE: `g_emit.flat_lcl_proc` is true for most callable chains but not
# all. Measured 2026-09-01 over this witness set -- emitter 31 vs TEXT 36, the whole gap inside fbench.pas
# (`transitxsurface_γ` 4 + `initialise_γ` 1), two procedures whose γ exits DO marshal rax:rdx but whose
# chains do not carry that flag. Gating on EQUALITY against a known-incomplete instrument would print
# UNPROVEN forever, which is a refusal that has stopped meaning anything.
# ⭐ SO THE DIRECTION IS WHAT MATTERS: the emitter seeing a promotion-site transfer the TEXT scan MISSED is
# a real divergence and refuses (the TEXT scan would have a blind spot in the dangerous direction).
# The reverse is the characterized shortfall above and is reported as coverage, not as a verdict.
AUD=$(cat "$WORK"/*.audit 2>/dev/null | grep -c 'PORT-EXIT-PROMOTION' || true)
printf '   cross-check: emitter chokepoint %s / TEXT scan %s promotion-site transfer(s) -- emitter coverage %s%%\n' \
       "$AUD" "$XFERS" "$([ "${XFERS:-0}" -gt 0 ] 2>/dev/null && echo $(( AUD * 100 / XFERS )) || echo '?')"
if [ "${AUD:-0}" -gt "${XFERS:-0}" ] 2>/dev/null; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: the EMITTER sees $AUD promotion-site transfers but the TEXT scan"
    echo "    found only $XFERS. That is the dangerous direction -- the TEXT scan is missing promotion sites"
    echo "    the compiler itself reports. Reconcile before trusting the contract verdict below."
    gate_stamp; exit 2
fi
# ⛔ the cannot-measure floor: zero exits examined is NOT a clean tree, it is a broken instrument.
gate_floor "$EXITS" 1 "rax-forwarding procedure exits"
gate_verdict "$VIOL" "port exits reached with an unnormalized value in rax (forgeable DT_FAIL)"
