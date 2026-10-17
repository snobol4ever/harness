#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_frameless_thunk_carries_its_head_and_lands_omega_at_depth_zero.sh -- STEP 2 OF THE ROW
# stored-pattern-thunks-run-on-the-rsp-spine-when-recede-free-no-rbp-frame-no-map-cell-no-zero-fill (Lon 2026-09-30, in-chat to the
# ceo: "Ensure that pre-compiled patterns do no carry the extra weight of an RBP activation frame when just the RSP spine will
# suffice."; Lon 2026-10-01, in-chat to the cto, ordering this step first). A stored-pattern thunk that runs on the RSP spine alone
# (the default and only road since the SCRIP_BLOB_SPINE switch was deleted) still needs three things its RBP frame used to give it:
#   (1) THE HEAD. The pattern's DTP (rdx at entry) and, under casmark, r12 lived at [rbp-24] and [rbp-32]. A var box reading a
#       snapshot slot (P = SPAN(X) reads X from the pattern's own header) read [rbp-24] of the CALLER's frame, error 188 (span_1).
#       Now the thunk carves its head on the spine as TAGGED cells -- {DT_P, rdx} and {DT_I, r12} -- so the collector sees a DESCR,
#       never a raw word, and the reader addresses rsp at the compile-time depth the zd planner already knows (zd_out).
#   (2) THE GAMMA DEPTH. The gamma tail read the continuation pair at a depth that counted only scratch-cell leaves, 16 where the
#       var and coerce cells made it 48; the gamma depth is now the planner's own depth at every gamma exit, which must agree.
#   (3) THE OMEGA DEPTH. A framed thunk's omega is mov rsp, rbp, so a box could leave carves behind on its way out (POS fails to
#       omega at depth 32 in the ladder's MK pattern); frameless, every omega exit that lands deeper than zero goes through a pad
#       that pops exactly the rest -- its depth less its own carve, the collapsed beta carves and the staged pop.
# Measured on 270cfc43b over the 757-entry pattern-feature slice of the SNOBOL4 master, both modes: 48 entries red under the flag
# that pass on defaults (33 SIGSEGV, 15 rc 1) before; after, the flag arm reads the defaults' 1484 of 1514 entry for entry.
# ONE ROAD. The flag arm (SCRIP_BLOB_SPINE=1 SCRIP_LEAF_FRAME=0) was the whole spine road until both switches were deleted: the
# leaf default went back to the spine at 6b33e24d5 (CEO-1391 (a)), and the frameless thunk became the default when
# test_gate_no_zeta_frame_switches read the two switches red (no env chooses a frame placement); the flip changed the asm of 243
# of 5246 extracted master entries (241 SNOBOL4, 2 Snocone), all of which run as before in both modes.
# THE WITNESS has one statement per class; the oracle is sbl (lib_oracle_flags.sh). The gate grades both modes under the flag and
# on defaults, and checks the .s: a frameless thunk exists and every frameless thunk that reads its head carves it tagged.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; G="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: cannot load lib_oracle_flags.sh"; exit 2; }
SBL="$(sbl_correctness_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: no SPITBOL correctness oracle"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.sno" <<'SNO'
        S = 'ABCDEF'
        X = 'BDF'
        P = SPAN(X)
        S P =
        OUTPUT = S
        DEFINE('MK(C)')                    :(MKEND)
MK      MK = POS(0) SPAN(C) RPOS(0)        :(RETURN)
MKEND
        P1 = MK('a')
        P2 = MK('b')
        OUTPUT = ('aaa' ? P1) ' P1 keeps its argument'
        OUTPUT = ('bbb' ? P2) ' P2 keeps its argument'
        OUTPUT = ('bbb' ? P1) ' P1 must not match bbb'
        OUTPUT = 'after the failing match'
        E = SPAN('a') $ V
        'a+aa' POS(0) *E RPOS(0)           :S(OK)F(NO)
OK      OUTPUT = 'match ' V                :(DONE)
NO      OUTPUT = 'nomatch'
DONE
END
SNO
(cd "$T" && timeout -k 5 20 "$SBL" $(sbl_lang_flags) w.sno < /dev/null > ref 2>&1); [ -s "$T/ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for the witness"; exit 2; }
RC=0
for arm in dfl; do
    E="env"
    (cd "$T" && $E timeout -k 5 20 "$SCRIP" w.sno < /dev/null > "m3.$arm" 2>&1)
    (cd "$T" && $E timeout -k 5 20 "$SCRIP" --compile -o "w.$arm.s" w.sno < /dev/null > "cc.$arm" 2>&1) || { echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile failed ($arm): $(head -1 "$T/cc.$arm" | cut -c1-120)"; exit 2; }
    gcc -m64 "$T/w.$arm.s" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "$T/w.$arm.bin" 2>> "$T/cc.$arm" || { echo "⛔ GATE REFUSE(2) [$G]: mode-4 link failed ($arm)"; exit 2; }
    (cd "$T" && timeout -k 5 20 "./w.$arm.bin" < /dev/null > "m4.$arm" 2>&1)
    for m in m3 m4; do cmp -s "$T/ref" "$T/$m.$arm" && echo "  PASS $arm $m = oracle" || { RC=1; echo "  FAIL $arm $m differs from the oracle: $(diff "$T/ref" "$T/$m.$arm" | grep -m2 '^[<>]' | tr '\n' ' ' | cut -c1-160)"; }; done
done
read -r nfl nhead nbad <<< "$(awk '
/^\.LTp[0-9]+:/ { inth = 1; framed = 0; reads = 0; tagged = 0; first = 1; next }
inth && /mov +rbp, +rsp/ { framed = 1 }
inth && /^\.LTp[0-9]+_α_body:/ { next }
inth && /sub +rsp, +(16|32)$/ && first { first = 0; next }
inth && /mov +qword ptr \[rsp \+ (0|16)\], +8$/ { tagged = 1 }
inth && /mov +rdi, +qword ptr \[rsp \+ [0-9]+\]/ && prevvar { reads = 1 }
inth { prevvar = ($0 ~ /_var_α:/) }
inth && /^\.LTp[0-9]+_ω:/ { if (!framed) { fl++; if (reads) { hd++; if (!tagged) bad++ } } inth = 0 }
END { printf "%d %d %d\n", fl + 0, hd + 0, bad + 0 }' "$T/w.dfl.s")"
[ "$nfl" -ge 1 ] && echo "  PASS the default emits $nfl frameless thunk(s)" || { RC=1; echo "  FAIL the default emits no frameless thunk -- the witness no longer reaches the road"; }
[ "$nhead" -ge 1 ] && [ "$nbad" -eq 0 ] && echo "  PASS $nhead frameless thunk(s) read their head from the spine, every one carved as a tagged DT_P cell" || { RC=1; echo "  FAIL frameless head readers=$nhead, untagged heads=$nbad -- a frameless thunk reads a head it never carved as a cell"; }
[ "$RC" = 0 ] && echo "GATE PASS(0) [$G]: a frameless stored-pattern thunk carries its head as tagged spine cells and lands gamma and omega at their depths, both modes = sbl" || echo "⛔ GATE FAIL(1) [$G]: a frameless thunk lost its head or its depth"
exit $RC
