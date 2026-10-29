#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_every_frame_reference_lands_in_a_granted_cell.sh -- EVERY rbp-relative REFERENCE OF A RESUMABLE PROLOG FRAME LANDS INSIDE A CELL THE LAYOUT GRANTS (the cto, ARCH-PROLOG-ACTIVATION-LIFETIME 9.13
# (2) and (3), CEO-2018; the instrument of ARCH-GC-COMPILE-TIME-FRAME-MAPS 17, the one-source-of-truth design: the plan is the collector's map, so a quad the emitter addresses and the plan does not grant is a
# quad the collector cannot see). THE INSTRUMENT is util_frame_refs_land_in_grants.py: it reads the --dump-zeta grant table of a program (the dump's field lines, its vslot lines -- the parameter and goal-variable
# cells -- and the 64-byte entry header below the carve) and measures every literal [rbp+N] in each graph's own FN__ body against it, printing one machine-readable line per ungranted reference:
#   UNGRANTED graph=<g> box=<nNN_kind> off=<N> region_end=<R>
# and the summary `; grants TOTAL graphs=<n> graded=<g> refs=<r> findings=<f>`. This gate runs it over the r/1 prelude+witness program (fixtures/frame_r1_witness.pl, 253 graphs of the Prolog prelude) and six
# Prolog core entries, and PRINTS `FRAME_REFS programs=<p> graphs_graded=<g> refs=<r> ungranted=<u>`. READING, 2026-10-29 at SCRIP 32cd28a02: the seven programs grade 2076 graphs over 83822 references and 0 are ungranted (the fixture alone grades 252 of 253 graphs over 8620 references -- main is the
# root graph, whose carve is not the flat activation frame this instrument reads); before the instrument was taught the vslot lines and the entry header the fixture read 2452. A reference the checker still names is a REAL HOLE and a row of its own with the graph and the offset as its DONE-WHEN, never a reason to weaken this gate. No byte bar anywhere.
# THE NEGATIVE CONTROL (CEO-1680: a proper test, no seam in SCRIP): the same program's dump is read again with every `vslot +192` line removed (the script's own filter) and the checker MUST name ungranted references
# there (133 on the fixture); if it reads 0 it is blind and this gate reads RED. --corrupt skips that damage so the control arm itself reads RED.
# rc 0 held · rc 1 an ungranted reference, or the control did not trip · rc 2 cannot measure (no scrip, no fixture, a program that does not extract or compile, nothing graded)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" 2>/dev/null && pwd)" || { echo "REFUSE(2): no SCRIP beside harness"; exit 2; }
CORPUS="$(cd "$HERE/../../corpus" 2>/dev/null && pwd)" || { echo "REFUSE(2): no corpus beside harness"; exit 2; }
[ -x "$SCRIP/scrip" ] || { echo "REFUSE(2): $SCRIP/scrip is not built"; exit 2; }
FIX="$HERE/fixtures/frame_r1_witness.pl"
[ -f "$FIX" ] || { echo "REFUSE(2): no fixture $FIX"; exit 2; }
CORRUPT=0; [ "${1:-}" = "--corrupt" ] && CORRUPT=1
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_frame_refs.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
D="$CORPUS/tests/prolog"
cp "$FIX" "$W/fixture.pl"
n=1
for entry in catch_throw_ball_is_compound_1 findall_catch_between_1 between_ite_naf_1 dcg_ite_list_replace_1 ladder__rung10_monotonic_tabling_propagates_an_assert_into_its_dependents retract_backtrack_1; do
    python3 "$HERE/corpus_suite_harness.py" extract "$D/ALL.pl" "$D/ALL.ref" "$entry" "$W/e$n.pl" --out-ref "$W/e$n.ref" --out-in "$W/e$n.in" > /dev/null 2>&1 || { echo "REFUSE(2): cannot extract $entry"; exit 2; }
    [ -s "$W/e$n.pl" ] || { echo "REFUSE(2): $entry extracted empty"; exit 2; }
    n=$((n+1))
done
rc=0; P=0; G=0; R=0; U=0
for f in "$W"/fixture.pl "$W"/e[0-9]*.pl; do
    out="$( cd "$SCRIP" && timeout -k 5 300 python3 "$HERE/util_frame_refs_land_in_grants.py" "$f" 2>&1 )"
    tot="$(printf '%s\n' "$out" | grep -E '^; grants TOTAL' | tail -1)"
    [ -n "$tot" ] || { echo "REFUSE(2): the checker printed no TOTAL for $(basename "$f")"; printf '%s\n' "$out" | head -3; exit 2; }
    g="$(printf '%s\n' "$tot" | sed -n 's/.* graded=\([0-9]*\).*/\1/p')"; r="$(printf '%s\n' "$tot" | sed -n 's/.* refs=\([0-9]*\).*/\1/p')"
    [ "${g:-0}" -gt 0 ] || { echo "REFUSE(2): $(basename "$f") graded 0 graphs"; exit 2; }
    u="$(printf '%s\n' "$out" | grep -c '^UNGRANTED ')"
    printf '%s\n' "$out" | grep '^UNGRANTED ' | head -20 | sed "s|^|[$(basename "$f")] |"
    P=$((P+1)); G=$((G+g)); R=$((R+r)); U=$((U+u))
done
echo "FRAME_REFS programs=$P graphs_graded=$G refs=$R ungranted=$U"
[ "$U" -eq 0 ] || { echo "RED: $U references land in no granted cell"; rc=1; }
( cd "$SCRIP" && ./scrip --dump-zeta "$W/fixture.pl" < /dev/null > "$W/z.dump" 2> /dev/null; ./scrip --compile "$W/fixture.pl" < /dev/null > "$W/z.asm" 2> /dev/null )
[ -s "$W/z.dump" ] && [ -s "$W/z.asm" ] || { echo "REFUSE(2): the control's dump or assembly is empty"; exit 2; }
if [ "$CORRUPT" = 1 ]; then cp "$W/z.dump" "$W/zd.dump"; else grep -v 'vslot +192 ' "$W/z.dump" > "$W/zd.dump"; fi
cu="$(python3 "$HERE/util_frame_refs_land_in_grants.py" --zeta "$W/zd.dump" --asm "$W/z.asm" 2>&1 | grep -c '^UNGRANTED ')"
echo "NEGATIVE_CONTROL damaged dump (vslot +192 removed) names $cu ungranted references"
[ "$cu" -gt 0 ] || { echo "RED: the damaged dump reads 0 ungranted references -- the checker is blind"; rc=1; }
[ "$rc" -eq 0 ] && echo "GATE OK [every_frame_reference_lands_in_a_granted_cell]: $R references over $G graphs land in granted cells and the checker names the damage it should" \
    || echo "GATE RED [every_frame_reference_lands_in_a_granted_cell]"
exit $rc
