#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐⭐ GATE: no emitted .s may reference a procedure's α ENTRY LABEL that nothing defines.
#
# THE CLASS, twice witnessed, different triggers, same shape:
#   1. hq_P 2026-08-29 — bb_define emitted `lea r9, [rip + <fn>_α]` whenever `_.lbl_t0` was non-null, but
#      `<fn>_α` is DEFINED only when the body is a tiny shim. Any DEFINE'd proc calling INPUT/OUTPUT referenced
#      a label nobody emitted -> `ld: relocation R_X86_64_PC32 against undefined symbol` under PIE.
#      (.github FINDING-2026-08-29-hq_P-alpha-reference-and-definition-gated-on-different-predicates.md)
#   2. seat16 2026-08-30 — forcing the SNO$STMT hook on put ARITH_LOOP_α in the referenced-but-undefined set;
#      a hook prepended to a DEFINE'd function's entry statement, a completely different trigger. (.github ed132985)
# ⛔ A REFERENCE AND ITS DEFINITION MUST BE GATED ON THE SAME PREDICATE. This gate tests that mechanically
# instead of waiting for a linker to say so on whichever program happens to exercise it.
#
# ⭐ WHY NOT JUST LINK IT: the board already compiles+links and folds a link failure into SKIP, not FAIL
# (test_corpus_snobol4.sh:127) -- so this defect can hide behind a green board. This gate reads the ASM and
# refuses, which is also faster and names the symbol instead of a relocation.
#
# ⛔ THE EXEMPTION IS REAL AND MUST NOT BE REMOVED: the driver deliberately emits `.weak <fn>_α` plus
# `<fn>_α@GOTPCREL` for dyn_scope procedures (scrip.c, rt_proc_seal_alpha). That is PIE-safe against an
# undefined weak symbol BY DESIGN -- it resolves to NULL and the runtime copes. So an undefined α is a DEFECT
# only when something references it DIRECTLY (a bare `lea`/`jmp`, no @GOTPCREL). Measured on a cured build:
# helper_α weak=1 got=1 direct_refs=0 -> clean.
# ⛔⭐ THIS GATE WAS VACUOUS ON ITS FIRST RUN AND ITS OWN SELF-TEST CAUGHT IT (hq_P, same session). The
# patterns were written as '..._\xce\xb1:' inside SINGLE QUOTES, where bash does NOT expand \x escapes, so
# grep matched the literal text and found ZERO labels -- and an empty defined-set minus an empty referenced-set
# is empty, which printed "ok" for every witness. It would have passed on a known-broken build. Use the LITERAL
# α below; do not "portability-fix" it back into escapes without re-running the self-test.
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$SELF_DIR/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"; CORPUS="$(cd "$ROOT/../corpus" 2>/dev/null && pwd)" || { echo "⛔ REFUSES (rc=2): no sibling corpus/"; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSES (rc=2): $SCRIP not built -- this is NOT a pass."; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# The witness set: the two known trigger shapes plus whatever the caller names. Kept in-file and tiny so the
# gate cannot go dark when a corpus path moves -- the failure this project keeps paying for.
mk() { printf '%s\n' "$2" > "$W/$1.sno"; }
mk def_input "        DEFINE('helper()instream')                :(helperEnd)
helper  INPUT(.instream, 8)
        helper = 'ok'                             :(RETURN)
helperEnd
        OUTPUT = helper()
END"
mk def_output "        DEFINE('helper(f)outstream')              :(helperEnd)
helper  OUTPUT(.outstream, 8, , f)                :F(FRETURN)
        helper = 'ok'                             :(RETURN)
helperEnd
        OUTPUT = helper('/nonexistent/x')
END"
mk def_plain "        DEFINE('helper(a)')                       :(helperEnd)
helper  helper = a ':'                            :(RETURN)
helperEnd
        OUTPUT = helper('x')
END"
# ⭐⭐ SELF-TEST FIRST — THIS GATE PROVES IT CAN GO RED BEFORE IT IS ALLOWED TO REPORT GREEN.
# A detector that has never fired is indistinguishable from one that cannot fire, and this fleet has now
# catalogued that class repeatedly (a skip-as-success rung harness, a tautological emit gate, and my own
# vacuous 1-byte oracle). So: compile a known-good witness, DELETE one α definition that is directly
# referenced, and require the predicate to catch it. If it does not, the instrument is broken and this exits
# rc=2 -- UNPROVEN -- rather than printing the success shape over a detector that cannot detect.
selftest() {
    local s="$W/def_plain.s" m="$W/selftest.s" lbl
    [ -f "$s" ] || return 1
    lbl=$(grep -oE '^[A-Za-z0-9_]+_α:' "$s" | tr -d ':' | while read -r c; do
              grep -E "\b$c\b" "$s" | grep -qvE "@GOTPCREL|\.weak|^$c:" && { echo "$c"; break; }; done)
    [ -n "$lbl" ] || return 1
    grep -v "^$lbl:" "$s" > "$m"                       # remove ONLY the definition, keep every reference
    grep -oE '^[A-Za-z0-9_]+_α:' "$m" | tr -d ':' | sort -u > "$W/sd.txt"
    grep -oE "\b[A-Za-z0-9_]+_α\b" "$m" | sort -u > "$W/sr.txt"
    comm -13 "$W/sd.txt" "$W/sr.txt" | grep -qx "$lbl" || return 1
    echo "  self-test: removed $lbl's definition -> detector FIRED (the gate can go red)"
    return 0
}
progs=""; for f in "$W"/*.sno; do progs="$progs $f"; done
for extra in "$@"; do [ -f "$extra" ] && progs="$progs $extra"; done
n=0; bad=0
echo "=== UNDEFINED-α GATE — an α reference with no definition and no @GOTPCREL is unlinkable under PIE ==="
printf '  %-26s %-8s %s\n' WITNESS VERDICT "UNDEFINED-AND-DIRECTLY-REFERENCED"
for p in $progs; do
    b="$(basename "$p" .sno)"; s="$W/$b.s"
    SNO_LIB="$CORPUS/include" timeout -k 5 60s "$SCRIP" --compile "$p" > "$s" 2>/dev/null || {
        printf '  %-26s %-8s (compile failed -- NOT graded)\n' "$b" "REFUSE"; bad=1; continue; }
    grep -oE '^[A-Za-z0-9_]+_α:' "$s" | tr -d ':' | sort -u > "$W/d.txt"
    grep -oE "\b[A-Za-z0-9_]+_α\b" "$s" | sort -u > "$W/r.txt"
    hits=""
    for u in $(comm -13 "$W/d.txt" "$W/r.txt"); do
        direct=$(grep -E "\b$u\b" "$s" | grep -vcE "@GOTPCREL|\.weak")
        [ "$direct" -gt 0 ] && hits="$hits $u($direct)"
    done
    n=$((n+1))
    if [ -n "$hits" ]; then printf '  %-26s %-8s %s\n' "$b" "⛔FAIL" "$hits"; bad=1
    else printf '  %-26s %-8s %s\n' "$b" "ok" "-"; fi
done
[ "$n" -gt 0 ] || { echo "⛔ REFUSES (rc=2): zero witnesses graded -- an empty gate is not a green one."; exit 2; }
selftest || { echo "⛔ REFUSES (rc=2): the gate could not prove it detects a planted undefined α."; echo "   An instrument that cannot be made to fail is not evidence -- fix the detector, do not trust this run."; exit 2; }
echo "------------------------------------------------------------"
if [ "$bad" -ne 0 ]; then
    echo "⛔ GATE FAILS: an α entry label is referenced directly but never defined. That object cannot link"
    echo "   under PIE (R_X86_64_PC32 against an undefined symbol), and the SNOBOL4 board would report it as"
    echo "   SKIP, not FAIL. Cure the PREDICATE -- make the reference and the definition agree -- never the symptom."
    exit 1
fi
echo "✅ GATE OK: $n witness(es), zero directly-referenced undefined α labels."
