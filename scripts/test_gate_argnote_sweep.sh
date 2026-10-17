#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_argnote_sweep.sh -- OBJ-NOTE ON-3 ARG-NOTE gate.  Compiles the SNOBOL4 corpus in mode-4 and asserts
# the three annotation invariants the ladder names: (1) ZERO stray '#@' markers survive into a .s -- an unfolded
# marker means the fold missed a chunk boundary; (2) ZERO notes on jump lines -- the GOTO column belongs to the
# jumps, Lon's explicit directive; (3) emit failures held at the pre-existing baseline, so an annotation pass is
# never the thing that broke a program.  Reports the annotation volume so a regression to zero is visible too.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
SCRIP=${SCRIP:-$S4E/SCRIP/scrip}
CORPUS=${CORPUS:-$S4E/corpus}
LIMIT=${LIMIT:-0}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
stray=0; jumpnote=0; emitfail=0; total=0; notes=0; failed=""
JRE='^[[:space:]]+(jmp|je|jne|jg|jl|jge|jle|ja|jb|jae|jbe|js|jns|jz|jnz|jc|jnc|jo|jno|jp|jnp|jecxz|jrcxz)[[:space:]].*#'
# ⚠️⭐ THE RATIONALE BELOW IS RETRACTED LAW, AND THIS PRUNE IS BOTH UNNECESSARY AND ALREADY INERT.  READ THIS FIRST.
# ⭐ WHAT LON ACTUALLY RULED, 2026-08-27, in-chat to CEO, verbatim in substance: "Do not use the lon_cherryholmes folder as runtime tests.  Use them for parser tests
# all day long.  And in fact, all the corpus/programs need work and cannot be converted to tests currently."  Mechanically: PARSER TESTS unrestricted; RUNTIME AND
# SCORED BOARDS no; the whole corpus/programs/ tree (EBNF, lon_cherryholmes, TZ) is not convertible to tests currently.  Reading, compiling, running BY HAND, citing
# and measuring all stay free -- the restriction is solely about installing these programs AS TESTS.  Authority: RULES.md ABSOLUTE RULES, the lon_cherryholmes block.
# ⭐ THIS GATE IS COMPILE-ONLY -- it runs `$SCRIP --compile` and never executes a program -- so it is a PARSER test, and Lon's ruling makes parser use of
# lon_cherryholmes UNRESTRICTED ("use them for parser tests all day long").  Nothing here needs to exclude that tree.
# ⚠️ AND THE PRUNE IS ALREADY INERT: it reads `-path '*/programs/lon' -prune`, which stopped matching when the s272 re-grid renamed the directory to
# lon_cherryholmes/, so the 99 files ALREADY flow through this sweep.  The status quo therefore already matches the ruling; removing the dead prune is a
# BEHAVIOURAL edit and this commit is comment-only by grant (hq_C, ceo), so it is left for an attributed commit of its own.
# ⛔⭐ THE TRAP WORTH CARRYING AWAY: the assertion below was written to RE-CHECK the prune -- but it greps for the SAME stale name the prune uses, so both died
# together and the check reported 0 and read as proof of exclusion while proving nothing.  A GUARD AND ITS OWN CANARY MUST NOT SHARE A FAILURE MODE.
# ⛔ HISTORICAL, SUPERSEDED, KEPT FOR THE RECORD ONLY: THE OFF-LIMITS TREE IS PRUNED BY CONSTRUCTION, NOT SKIPPED IN THE LOOP (RULES.md ABSOLUTE RULE 1; row `scorecard-drop-lon`, s189).  This gate roots at the CORPUS ROOT and
# runs `$SCRIP --compile` on every .sno it finds, so until s189 it COMPILED all 99 programs under corpus/lon on every run -- against a rule whose words are "NEVER RUN,
# NEVER COMPILE ... in any mode, under any harness", and whose second reason is that those files may carry live Personal Access Tokens.  The `-prune` is what the rule asks for
# ("must EXCLUDE this directory by construction rather than by skipping it at run time"); the assertion under it is because a prune is one edit away from being lost and this
# gate's own CORPUS is env-overridable, so the exclusion is RE-CHECKED against the built list rather than trusted.  The assert prints no path from that tree -- only a count.
LIST=$(find "$CORPUS" -path '*/programs/lon' -prune -o -name '*.sno' -print | sort)
nlon=$(printf '%s\n' "$LIST" | grep -c '/programs/lon/' || true); [ "${nlon:-0}" -eq 0 ] || { echo "FAIL  off-limits tree reached: $nlon file(s) under corpus/lon survived the prune (RULES.md ABSOLUTE RULE 1)"; exit 1; }
# ⭐ V2-5 GATE HONESTY: examining nothing must exit UNPROVEN(2), never read as a pass.
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "${SCRIP:-${SCRIP_BIN:-$(dirname "$0")/../../SCRIP/scrip}}" "the scrip compiler"
gate_require "${RT_DIR:-$(dirname "$0")/../../SCRIP/out}/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
for f in $LIST; do
    [ "$LIMIT" -gt 0 ] && [ "$total" -ge "$LIMIT" ] && break
    total=$((total + 1))
    out="$TMP/x.s"
    # ⛔ CWD MATTERS: a program using -INCLUDE names its includes RELATIVE to its own directory, so a sweep
    # that compiles from elsewhere manufactures ~120 phantom "cannot open include" failures and reports them
    # as regressions.  Measured s23d: the naive sweep read 266 fails, the correct one far fewer.
    if ! ( cd "$(dirname "$f")" && timeout -k 5 25 "$SCRIP" --compile "$(basename "$f")" ) > "$out" 2>"$TMP/err"; then
        emitfail=$((emitfail + 1)); failed="$failed $f"; continue
    fi
    s=$(grep -c '^[[:space:]]*#@' "$out" 2>/dev/null); s=${s:-0}
    j=$(grep -cE "$JRE" "$out" 2>/dev/null); j=${j:-0}
    n=$(grep -c '#' "$out" 2>/dev/null); n=${n:-0}
    stray=$((stray + s)); jumpnote=$((jumpnote + j)); notes=$((notes + n))
    if [ "$s" -ne 0 ] || [ "$j" -ne 0 ]; then echo "VIOLATION $f stray=$s jumpnote=$j"; fi
done
echo "programs=$total  emit-refuse=$emitfail  stray-markers=$stray  notes-on-jumps=$jumpnote  notes=$notes"
echo "NOTE: emit-refuse is NOT the watermark and must never be quoted as one -- this sweep walks EVERY .sno in the"
echo "      tree, including CRLF files, include fragments, and programs outside the graded set.  The watermark is"
echo "      xc.sh over corpus/crosscheck (.ref-anchored, both modes).  This number is a TRIPWIRE for the two"
echo "      annotation invariants above, nothing more."
[ -n "$failed" ] && { echo "EMIT-FAIL SET:"; for x in $failed; do echo "  $x"; done; }
if [ "$stray" -eq 0 ] && [ "$jumpnote" -eq 0 ]; then echo "GATE GREEN"; exit 0; fi
echo "GATE RED"; exit 1
