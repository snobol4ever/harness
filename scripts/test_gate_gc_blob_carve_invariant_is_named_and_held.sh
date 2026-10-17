#!/usr/bin/env bash
# test_gate_gc_blob_carve_invariant_is_named_and_held.sh -- the R-4(b) SNOBOL4 stored-pattern blob frame
# (emit.cpp, "R-4(b) BLOB ACTIVATION FRAME") and the deferred-capture pump that re-enters emitted code at a
# match's end. Row gc-the-blob-frame-interior-takes-one-static-layout-and-its-cross-frame-dependency-is-named
# (cto, 2026-09-19); the earlier criterion (CEO-829 on CEO-824(2)) is superseded by measurement, recorded below.
#
# WHAT THIS GATE USED TO HOLD, AND WHY IT INVERTED. Until 2026-09-19 the carve was a DEPTH CONTRACT: growing it
# by 16, 32 or 48 bytes killed user_function_eval_pos_replace_branch_1 in mode 3 with the emitted program otherwise
# byte-identical, and this gate PLANTED that perturbation and required it to kill. The dependency was then NAMED
# (baton ledger of the row above, GOAL-CTO CTO-83): the match-end box called rt_match_end_all, a C pump that
# CALLED BACK into emitted code (rt_dcap_pump -> rt_sno_dtx_value -> rt_call_proc_descr -> rt_proc_enter) through
# five C frames, so a DEFINE'd function's statements reached that way ran at a depth the emitter never laid out, and its rsp-relative
# frame slots (op_zdepth 0, main-frame offsets) landed wherever the C frames' sizes put them -- on a dead slot when
# green, on the outer match's saved r12 when a -fstack-protector canary made the C frames 80 bytes deeper. The
# carve perturbation moved the same block by the same bytes. That is the whole "depth contract".
#
# LON, 2026-09-19, in-chat, verbatim: "It is disallowed to enter a BB via a C function except the very FIRST one
# inside the SCRIP, the ORIGINAL program invocation." and "If a C function must be called, then it must return the
# data needed for the BB to perform the direct jump, i.e. the C function must return before the BB is jumped into."
# THE CURE: rt_match_end_all is deleted; the match-end box calls rt_dcap_end_ok_open, which RETURNS the entry
# address of the next deferred capture target (0 = done, 1 = strict refuse), the box enters it with its own
# gamma/omega wires exactly as rt_proc_enter did, and rt_dcap_land_gamma/omega finish the capture and return the
# next target. No C frame sits between the match-end box and the body any more.
#
# THE INVARIANT NOW: (1) WITNESS -- user_function_eval_pos_replace_branch_1 matches its ref in both modes.
# (2) THE CARVE IS A SIZE, NOT A DEPTH -- the SAME perturbation that used to kill (+16, +32, +48 bytes,
# SCRIP_BLOB_CARVE_PAD) runs CLEAN and matches the ref in mode 3. A red here means a C frame is back between an
# emitted box and an emitted body, or the body-slot regime moved. (3) CARVE-ONLY -- the perturbed program differs
# from the base only in `sub rsp` immediates, so arm 2 grades the carve and nothing else. (4) THE PUMP SHAPE --
# the emitted match-end of the witness carries `call rt_dcap_end_ok_open`, `call rt_dcap_land_γ` and
# `call rt_dcap_land_ω`, and carries NO `rt_match_end_all`; the checker is proven on a doctored copy of the same
# emission that reintroduces the old symbol and drops the landings, which must FAIL it.
#
# THE FAIL-ONCE THIS GATE CANNOT REPLAY (it needs a runtime rebuild): `git show 0a6f75394:src/ir/descr.h` (a char
# array member in DESCR_t, canaries on) took the witness to SIGSEGV in both modes before the cure and reads green
# in both after it -- measured 2026-09-19, recorded in the row's ledger and CTO-83.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
CORPUS="$S4E/corpus/tests/snobol4"; [ -f "$CORPUS/ALL.sno" ] || { echo "⛔ GATE REFUSE(2) [$G]: no SNOBOL4 rungs at $CORPUS/ALL.sno -- the witness is cut from it"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
export SNO_LIB="${SNO_LIB:-$S4E/corpus/include}"
echo "  INVARIANT: the deferred-capture re-entry at a match's end is BOX-DRIVEN (Lon 2026-09-19: no BB is entered from C after the original program invocation; a C leaf returns the data for the jump) -- so the R-4(b) blob carve is a SIZE, not a depth: +16/+32/+48 bytes on it run clean in mode 3 where they used to kill user_function_eval_pos_replace_branch_1, the emitted match-end carries the pump's open/land calls and no rt_match_end_all, and the witness matches its ref in both modes."
python3 "$HERE/corpus_suite_harness.py" extract "$CORPUS/ALL.sno" "$CORPUS/ALL.ref" user_function_eval_pos_replace_branch_1 "$T/w.sno" --out-ref "$T/w.ref" >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: could not extract the witness entry from the rungs"; exit 2; }
timeout -k 5 60 "$SCRIP" "$T/w.sno" </dev/null > "$T/m3.out" 2>/dev/null; m3rc=$?
"$SCRIP" --compile "$T/w.sno" </dev/null > "$T/base.s" 2>/dev/null && gcc "$T/base.s" -o "$T/w.x" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null
if [ -x "$T/w.x" ]; then timeout -k 5 60 "$T/w.x" </dev/null > "$T/m4.out" 2>/dev/null; m4rc=$?; else m4rc=127; fi
if [ "$m3rc" = 0 ] && [ "$m4rc" = 0 ] && diff -q "$T/m3.out" "$T/w.ref" >/dev/null 2>&1 && diff -q "$T/m4.out" "$T/w.ref" >/dev/null 2>&1; then
    echo "  witness PASS (user_function_eval_pos_replace_branch_1 matches its ref in both modes: $(tr -d '\n' < "$T/w.ref"))"
else echo "  witness FAIL (m3 rc=$m3rc \"$(tail -1 "$T/m3.out" 2>/dev/null)\", m4 rc=$m4rc \"$(tail -1 "$T/m4.out" 2>/dev/null)\", ref \"$(cat "$T/w.ref")\")"; RC=1; fi
pad_bad=0; pad_seen=""
for p in 1 2 3; do
    prc=$(bash -c 'SCRIP_BLOB_CARVE_PAD=$0 timeout -k 5 60 "$1" "$2" </dev/null >"$3" 2>/dev/null; echo $?' "$p" "$SCRIP" "$T/w.sno" "$T/p$p.out" 2>/dev/null)
    if [ "$prc" = 0 ] && diff -q "$T/p$p.out" "$T/w.ref" >/dev/null 2>&1; then pad_seen="$pad_seen pad=$p:ok"; else pad_seen="$pad_seen pad=$p:rc=$prc"; pad_bad=$((pad_bad + 1)); fi
done
if [ "$pad_bad" = 0 ]; then echo "  carve-is-a-size PASS (+16/+32/+48 bytes on the blob carve run clean and match the ref in mode 3 --$pad_seen -- the depth contract that killed this witness until 2026-09-19 is dissolved)"
else echo "  carve-is-a-size FAIL (a perturbed carve kills or miscomputes the witness again --$pad_seen -- a C frame is back between an emitted box and an emitted body, or the body-slot regime moved; see the row's ledger)"; RC=1; fi
SCRIP_BLOB_CARVE_PAD=1 "$SCRIP" --compile "$T/w.sno" </dev/null > "$T/pad.s" 2>/dev/null
d_all=$(diff "$T/base.s" "$T/pad.s" | grep -c '^[<>]'); d_other=$(diff "$T/base.s" "$T/pad.s" | grep '^[<>]' | grep -vc 'sub  *rsp')
if [ "$d_all" -gt 0 ] && [ "$d_other" = 0 ]; then echo "  carve-only PASS (the perturbed program differs from the base in $d_all line(s), every one of them a sub rsp immediate -- arm 2 grades the carve, not a code change)"
else echo "  carve-only FAIL (base vs perturbed differ in $d_all line(s) of which $d_other are not sub rsp -- the knob is changing more than the carve and arm 2 no longer isolates it)"; RC=1; fi
pump_shape_ok() {
    local f="$1"
    grep -qE 'call .*rt_dcap_end_ok_open@' "$f" && grep -qE 'call .*rt_dcap_land_γ@' "$f" && grep -qE 'call .*rt_dcap_land_ω@' "$f" && ! grep -q 'rt_match_end_all' "$f"
}
# the three pump entries are read in EITHER spelling the emitter uses -- `call SYM@PLT` for a C entry and, since
# af1d0e856, `call qword ptr [rip + SYM@GOTPCREL]` for an entry into the asm runtime -- because rt_dcap_end_ok_open
# moved into the asm runtime and the PLT-only grep read open=0 on a tree whose pump was whole (cto 2026-09-24).
grep -v 'rt_dcap_land_' "$T/base.s" > "$T/doctored.s"; echo '                        call             rt_match_end_all@PLT' >> "$T/doctored.s"
if pump_shape_ok "$T/base.s"; then
    if pump_shape_ok "$T/doctored.s"; then echo "  pump-shape FAIL (the checker passed a doctored emission that reintroduces rt_match_end_all and drops the landings -- the arm is inert)"; RC=1
    else echo "  pump-shape PASS (the witness's match-end carries rt_dcap_end_ok_open + rt_dcap_land_γ/ω and no rt_match_end_all; the doctored copy FAILS the same checker, so the arm discriminates)"; fi
else echo "  pump-shape FAIL (the emitted match-end lacks the box-driven pump: open=$(grep -cE 'call .*rt_dcap_end_ok_open@' "$T/base.s") landγ=$(grep -cE 'call .*rt_dcap_land_γ@' "$T/base.s") landω=$(grep -cE 'call .*rt_dcap_land_ω@' "$T/base.s") end_all=$(grep -c 'rt_match_end_all' "$T/base.s"))"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: the capture pump is box-driven, the blob carve is a size and not a depth, and the witness is green in both modes (examined 4 arms, one with a planted violation)"
else echo "GATE FAIL(1) [$G]: a C frame is back between an emitted box and an emitted body, or an arm stopped discriminating (examined 4 arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
