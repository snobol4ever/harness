#!/usr/bin/env bash
# test_gate_icn_one_reg_frame.sh — ICON STACKLESS ONE-REGISTER FRAME (FACT RULE) — TWO LOCKS.
#
# THE RULE (RULES.md): "all per-box RW in ONE local frame [reg+off]"; read-only locals are IP-relative.
# The corollary the template rules state (GOAL-TEMPLATE-REVAMP ζ-FRAME SCRATCH): a box reaches its storage
# through the frame ACCESSORS — FR/FRQ/FRQB, ZRES/ZLOC/ZOPQ, XSAQ/XSAD, zone_ref — "never movabs a process
# addr, never rip-rel .data".  The accessors are what make BINARY == TEXT and what let a slot be RE-HOMED
# (PF-1a..1d move a seam-crossed cell into the activation frame by changing the accessor's answer, not the
# call sites).  A hand-built operand string is invisible to all of that.
#
# ⛔ LOCK 2 IS NEW, AND LOCK 1 WAS VACUOUS (s247, seat1, rung N-0).  The gate's only test counted
# `(uintptr_t)&(pBB|a0)->(value|counter|state)` — the mode-3 `bb_bin_t` box structs.  THOSE STRUCTS NO LONGER
# EXIST (bb_bin_t was abolished 2026-06-02); the count is 0 and CANNOT BE ANYTHING ELSE, so the gate has been
# certifying a property nothing could violate while `test_gate_icn_var.sh` re-ran it as a HARD lock.  A ratchet
# whose subject has been deleted reports success forever.  Lock 1 is KEPT as a cheap zero-assert (if the
# structs ever return, fail), and Lock 2 measures the LIVE form of the same property.
#
# LOCK 2 — HAND-BUILT MEMORY BASES.  Counts string literals `"[rsp…"` / `"[rbp…"` built inside a template
# instead of asking an accessor.  Measured 22 at s247 (bb_call 4, bb_call_fn 4, bb_make_list 4, xa_flat 7,
# bb_define 3).  ⭐ THIS IS NOT A STYLE COUNT.  The arg-marshalling trio (bb_call / bb_call_fn / bb_make_list)
# hand-builds `[rsp + op_zread[i] + N]` — a RAW FLAT SPINE COORDINATE — where ZOPQ(k,w) would answer with the
# operand's ACTIVATION-FRAME home whenever PF-1c has re-homed it (`op_zread_xf[k]`).  Those sites therefore
# cannot see a re-homed operand: the exact "flat ZLS coordinate vs re-homed cell" defect class the SN4
# campaign spent 2026-08 killing (s129/s130/s177/s184/s189).  The xa_flat sites are the ICN-FR-2 wire header
# and the CLASS-C chain prologue — the pre-wire-stack crossing that rung N-1 deletes.
# ⛔ RATCHET, LOWERED MANUALLY IN THE LANDING COMMIT, NEVER AUTO (parallel seats; RULES.md CONCURRENCY).
# Target 0: reached when N-1 retires the wire header and N-2/N-4 route marshalling through ZOPQ.
# Surface is src/templates/{bb,xa}/*.cpp with COMMENTS STRIPPED (the medium-invisible gate's idiom — spelling-
# independent).  x86_asm.h is EXEMPT BY CONSTRUCTION: it is the encoder, the sanctioned sole producer of
# these strings.  `strstr(t, "[rsp")` is a search NEEDLE, not an emission, and is excluded by name.
# AUTHORS: Lon Jones Cherryholmes · Jeffrey Cooper M.D. · Claude Sonnet · Claude Fable  DATE: 2026-05-30 (relaid 2026-08-21)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${HERE}/../../SCRIP/src"
HANDBUILT_RATCHET="${HANDBUILT_RATCHET:-16}"
rc=0

[ -d "${SRC}/templates" ] || { echo "GATE FAIL(2): census surface ${SRC}/templates does not exist."; exit 2; }
. "${HERE}/lib_gate.sh"
gate_parse_args "$@"
# ⛔⭐ AND THE -d TEST ABOVE IS THE NARROWER QUESTION (coo 2026-09-18, the cto's re-measurement of seat10's list).
# The injection harness creates src/templates EMPTY, so the -d test passed, the *.cpp glob matched nothing, both
# locks scanned zero files, and THIS GATE IS A RATCHET: sites=0 is not greater than the ceiling 22, so it printed
# OK and then printed "RATCHET IMPROVED: 0 < 22 -- lower HANDBUILT_RATCHET in this script to lock the gain in."
# ⛔ THAT IS THE SAME DEFECT THIS FILE'S OWN HEADER NAMES ABOUT LOCK 1 -- "a ratchet whose subject has been
# deleted reports success forever" -- arriving through the population instead of through the subject, and it is
# worse than a silent green because it RECRUITS AN HONEST SEAT into locking in a gain that was never measured.
census_files=0
for _f in "${SRC}"/templates/bb/*.cpp "${SRC}"/templates/xa/*.cpp; do [ -f "$_f" ] && census_files=$((census_files+1)); done
gate_floor "$census_files" 1 "src/templates/{bb,xa}/*.cpp census file(s) -- a ratchet must refuse on an empty population BEFORE it compares against its ceiling"

echo "=== ICON STACKLESS ONE-REGISTER FRAME gate ==="
LEGACY=$(grep -rnoE '\(uintptr_t\)[[:space:]]*&(pBB|a0)->(value|counter|state)' "${SRC}" 2>/dev/null | grep -v _pl_ | grep -c . || true)
echo "LOCK 1 (zero-assert) absolute &pBB/a0->slot immediates: ${LEGACY}  (must be 0; the structs are abolished)"
if [ "${LEGACY}" -gt 0 ]; then
    echo "FAIL: an absolute box-slot address returned — per-box RW must be register-relative through the frame."
    rc=1
fi

# ⛔⭐⭐ AND THE FLOOR ABOVE CAUGHT LOCK 2 SCANNING ZERO FILES ON THE REAL TREE, NOT ONLY UNDER INJECTION (coo
# 2026-09-18).  The glob was "${SRC}"/templates/*.cpp -- but src/templates holds NO .cpp at its top level; they
# live in bb/, xa/ and x86/, and this file's own header states the surface as src/templates/{bb,xa}/*.cpp.  So
# the loop matched nothing, sites stayed 0, and because LOCK 2 IS A RATCHET the gate printed "RATCHET IMPROVED:
# 0 < 22 -- lower HANDBUILT_RATCHET in this script to lock the gain in" ON EVERY RUN SINCE IT WAS WRITTEN.
# ⛔ THE HEADER OF THIS VERY FILE SAYS LOCK 1 WAS VACUOUS BECAUSE ITS SUBJECT HAD BEEN DELETED, AND LOCK 2 WAS
# WRITTEN TO REPLACE IT.  Lock 2 was vacuous too, by a glob that missed the subdirectories -- the same defect
# arriving through the POPULATION instead of through the SUBJECT, in the gate written to cure it.
# ⭐ THE FIRST HONEST READING OVER THE CORRECT SURFACE IS 16 (bb_define 3, xa_flat 13), which is UNDER the old
# ceiling of 22, so nothing is red and no ceiling is raised.  The 22 was never a measurement of this surface
# either -- it was carried from the s247 command -- so the ceiling is set to the measured 16 in this landing
# rather than left naming a number no scan ever produced.  That is recording the win, not yielding to a red.
sites=0
for f in "${SRC}"/templates/bb/*.cpp "${SRC}"/templates/xa/*.cpp; do
    [ -f "$f" ] || continue
    code=$(perl -0777 -pe 's{/\*.*?\*/}{}gs; s{//[^\n]*}{}g' "$f" | grep -v 'strstr(')
    n=$(printf '%s' "$code" | grep -oE '"\[r(sp|bp)[^"]*"' | grep -c . || true)
    [ "$n" -gt 0 ] && { sites=$((sites+n)); printf '    %-32s %d\n' "$(basename "$f")" "$n"; }
done
echo "LOCK 2 (ratchet) hand-built [rsp/[rbp operand strings in templates: ${sites}  (ceiling ${HANDBUILT_RATCHET}, target 0)"
if [ "${sites}" -gt "${HANDBUILT_RATCHET}" ]; then
    echo "FAIL: ${sites} > ceiling ${HANDBUILT_RATCHET} — a memory base was hand-built; ask an accessor (FR/FRQ/ZRES/ZLOC/ZOPQ/XSAQ) instead."
    rc=1
fi
[ "${sites}" -lt "${HANDBUILT_RATCHET}" ] && echo "RATCHET IMPROVED: ${sites} < ${HANDBUILT_RATCHET} — lower HANDBUILT_RATCHET in this script to lock the gain in."
[ "$rc" -eq 0 ] && echo "OK: both locks hold."
exit "$rc"
