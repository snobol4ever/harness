#!/usr/bin/env bash
# test_gate_gc_map_table_present_in_both_media.sh -- rung 2 of the compile-time frame maps
# (ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 6, F1; row
# gc-the-compile-time-map-table-is-emitted-beside-the-code-in-both-media-...).
#
# WHAT THIS GATE HOLDS. Rung 1 (CTO-65) gave every activation frame a DT_MAP cell naming a 32-byte
# static map, and gave both media an install path: mode 3 registers each chain's map through
# rt_gc_frame_maps_add as it seals it, mode 4 emits a counted __gc_frame_maps .rodata table that
# main's prologue hands to rt_gc_frame_maps_install_counted. NOTHING READ THE TABLE BACK. The only
# reporter in the tree was SCRIP_GC_MAPS_REPORT, which prints what the EMITTER intended at compile
# time -- it cannot see a table that was emitted and never installed, and it cannot see the two media
# disagreeing. This gate reads the installed table back at RUN time through the one runtime symbol
# rt_gc_frame_maps() (SCRIP_GC_MAPS_DUMP=1) in BOTH media and requires the two readings to agree
# entry for entry.
#
# ⛔ WHAT THE READ-BACK FOUND THE FIRST TIME IT RAN (2026-09-18, cto), which is the whole argument for
# grading the artefact instead of the intent -- TWO cross-media identity divergences, both invisible
# to every instrument that existed:
#   (1) THE ENTRY GRAPH HAD TWO NAMES. The driver emits the program's main flat chain as the literal
#       "pat_flat" in mode 3 (scrip.c) and "main" in mode 4, so one graph's map carried two identities.
#       The fact was already KNOWN and PAPERED OVER in two other places rather than cured: util_gc_census.py
#       carried ENTRY_ALIAS = ("pat_flat", "main"), and emit.cpp tested both spellings. Three copies of
#       one fact, held by memory rather than by a check -- which is the state the INSTRUMENT LAWS exist
#       to end. Cured at the source: the map's graph_name is normalised once, in one named function.
#   (2) THE ASSEMBLER MANGLING LEAKED INTO THE MAP. Mode 4 must pass an assembler-legal prefix, so the
#       driver passes asm_sym_name(pname); mode 3 passes the raw name. The map's graph_name is DATA read
#       by the collector and the census, not a symbol, and it was taking whichever spelling the medium
#       needed: a Prolog program named every one of its ~160 graphs app/3, write/1, =../2 in mode 3 and
#       app$2F3, write$2F1, =..$2F2 in mode 4. Geometry agreed; identity did not. Cured by having the map
#       carry the graph's TRUE name (zls_graph_name_get) in both media while labels keep their mangling.
#   Neither divergence corrupts memory today, because the walker reaches a map through the frame's cell
#   rather than by name. Both make the map LIE about which graph a frame belongs to, and a collector
#   that guesses nothing cannot be built on metadata that does.
#
# ⛔ THE EXCLUSION THIS PARAGRAPH USED TO NAME IS RETIRED (cto, 2026-09-19, row gc-the-blob-frame-interior-takes-one-
# static-layout...): a SNOBOL4 stored-pattern blob frame (emit.cpp R-4(b)) now stores a DT_MAP cell at the bottom of
# its carve and its map carries GC_FRAME_MAP_BLOB plus a static layout of the interior (ARCH-GC section 6.2e), so it
# appears in BOTH media's tables like every other frame graph and this gate's read-back covers it; the layout itself
# is graded by test_gate_gc_the_blob_frame_interior_is_a_static_layout.sh.
#
# ⛔ THE SEVEN-FRONTEND WIDENING (2026-09-18, cto, on the ceo's word CEO-845). The gate shipped with THREE
# witnesses -- Icon, SNOBOL4, Prolog -- and three witnesses cannot see a divergence in the other four frontends.
# That is a blindfold, not a scope: the two divergences this gate FOUND were both properties of the DRIVER and the
# EMITTER, which every frontend passes through, so a fourth one could land in Snocone, Raku, Pascal or Rebus and
# read green here forever. Under ONE RUNNER (CEO-523) a seat may not reach for a board to cover that gap, so the
# gap is covered where it belongs -- in the hermetic gate, with one witness per frontend, all seven read back
# through the same runtime symbol in both media. Measured at the widening: Raku and Pascal carry TWO graphs each
# (main plus a called function), and SNOBOL4, Snocone and Rebus carry exactly ONE, because a DEFINE'd SNOBOL4
# function, a Snocone `function` and a Rebus `function` all lower INTO the program's flat chain rather than into a
# graph of their own. That is why arm 1 prints each witness's population instead of asserting a floor it would
# have to invent: a one-entry table is the truth for a flat-chain frontend, and a ZERO-entry table is still a red.
#
# ARMS (all blocking): (1) PRESENT -- each witness installs a NON-EMPTY table in BOTH media, read back
# through the one runtime symbol; (2) AGREE -- the two readings are identical entry for entry (graph
# name, frame_bytes, header_bytes, flags), across ALL SEVEN frontends; (3) IDENTITY -- the entry graph is
# named "main" in both media and no entry carries the assembler mangling tell ($2F), which is the
# regression guard for the two divergences above; (4) PLANTED -- SCRIP_GC_MAPTAB_PLANT=1 on the mode-4
# compile alone must make the two readings DISAGREE: a guard never seen to fire is not known to hold
# (CEO-554), and if this comes back green the read-back has stopped reading. Arm 4 plants in ALL SEVEN
# frontends, not just the first: a fail-once demonstrated in Icon says nothing about whether the Rebus or
# Pascal read-back discriminates, and an arm that never fired for a frontend has not measured it.
# ⛔⭐ ARM (4) RETIRED UNDER CEO-1680 (cto 2026-10-17; Lon 2026-10-11: no broken code planted so a test can trip): the
# SCRIP_GC_MAPTAB_PLANT seam left emit.cpp (row emit-the-three-emitter-plants-...). Its recorded reading is its fail-once: a mode-4
# compile with frame_bytes perturbed by 16 moved the installed table in every one of the seven frontends. FAIL_ONCE=1 now corrupts the
# mode-4 READING of each witness (its first entry's frame_bytes) and requires arm (2) to red -- the comparison can say no.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
export SNO_LIB="${SNO_LIB:-$S4E/corpus/include}"
echo "  HOLDS: the compile-time frame-map table is emitted beside the code in BOTH media and INSTALLED -- mode 3 registers each sealed chain, mode 4 hands main's prologue a counted __gc_frame_maps .rodata table -- and the table read back at run time through the ONE runtime symbol rt_gc_frame_maps() agrees entry for entry between the two media. A stored-pattern blob frame carries no cell and no map (6.2b) and is excluded from both tables by construction, so this gate prints the population it graded rather than reading zero divergences off an empty table. ONE WITNESS PER FRONTEND, ALL SEVEN -- Icon, SNOBOL4, Prolog, Snocone, Raku, Pascal, Rebus -- because the two divergences this gate found lived in the driver and the emitter, which every frontend passes through."

cat > "$T/a.icn" <<'EOF'
procedure f(a, b)
   return a + b;
end
procedure g(n)
   local s, i;
   s := 0;
   every i := 1 to n do s := s + f(i, 2);
   return s;
end
procedure main()
   write(g(5));
end
EOF
cat > "$T/b.sno" <<'EOF'
        DEFINE('F(X)')                              :(F_END)
F       F = X + 1                                   :(RETURN)
F_END
        S = 'hello world'
        S 'hello' = 'goodbye'                       :F(DONE)
        OUTPUT = S
        OUTPUT = F(41)
DONE
END
EOF
cat > "$T/c.pl" <<'EOF'
app([], L, L).
app([H|T], L, [H|R]) :- app(T, L, R).
:- app([1,2],[3],X), write(X), nl.
EOF
cat > "$T/d.sc" <<'EOF'
function Double(n) {
    Double = n + n; return;
}
OUTPUT = Double(21);
EOF
cat > "$T/e.raku" <<'EOF'
sub add($a, $b) {
    return $a + $b;
}
sub main() {
    my $s = 0;
    for 1..5 { $s = add($s, 2); }
    say($s);
}
EOF
cat > "$T/f.pas" <<'EOF'
program sumloop;
var
  i, s: integer;
function add(a, b: integer): integer;
begin
  add := a + b
end;
begin
  s := 0;
  for i := 1 to 5 do
    s := add(s, 2);
  writeln(s)
end.
EOF
cat > "$T/g.reb" <<'EOF'
function main()
  OUTPUT := 3 + 4
end
EOF

read_m3(){ SCRIP_GC_MAPS_DUMP=1 timeout -k 5 120 "$SCRIP" "$1" </dev/null >/dev/null 2>"$2"; }
read_m4(){ local src="$1" out="$2"; local s="$T/x.s" x="$T/x.bin"; rm -f "$s" "$x"
    timeout -k 5 120 "$SCRIP" --compile -o "$s" "$src" </dev/null >/dev/null 2>&1
    [ -s "$s" ] || return 1
    gcc "$s" -o "$x" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null || return 1
    SCRIP_GC_MAPS_DUMP=1 timeout -k 5 120 "$x" </dev/null >/dev/null 2>"$out"; }
tab(){ grep '^\[GC-MAPTAB\] graph=' "$1" 2>/dev/null | LC_ALL=C sort; }

pop=""
for w in a.icn b.sno c.pl d.sc e.raku f.pas g.reb; do
    src="$T/$w"
    read_m3 "$src" "$T/$w.m3.raw"
    if ! read_m4 "$src" "$T/$w.m4.raw"; then echo "  present FAIL ($w: mode 4 did not compile, link or run -- the table could not be read back)"; RC=1; continue; fi
    tab "$T/$w.m3.raw" > "$T/$w.m3.tab"; tab "$T/$w.m4.raw" > "$T/$w.m4.tab"
    [ "${FAIL_ONCE:-0}" = 1 ] && sed -i '1s/frame_bytes=[0-9]*/frame_bytes=99999/' "$T/$w.m4.tab"
    n3=$(wc -l < "$T/$w.m3.tab"); n4=$(wc -l < "$T/$w.m4.tab")
    if [ "$n3" -gt 0 ] && [ "$n4" -gt 0 ]; then pop="$pop $w:m3=$n3/m4=$n4"
    else echo "  present FAIL ($w: the installed table is EMPTY in a medium -- m3=$n3 m4=$n4 entries. A gate that compared two empty tables would report agreement while measuring nothing)"; RC=1; continue; fi
    d=$(diff "$T/$w.m3.tab" "$T/$w.m4.tab" | grep -c '^[<>]')
    if [ "$d" != 0 ]; then echo "  agree FAIL ($w: the two media disagree in $d line(s) -- the same graph carries different geometry or a different identity in mode 3 and mode 4):"; diff "$T/$w.m3.tab" "$T/$w.m4.tab" | grep '^[<>]' | head -6 | sed 's/^/      /'; RC=1; fi
    for m in m3 m4; do
        grep -q 'graph=main ' "$T/$w.$m.tab" || { echo "  identity FAIL ($w $m: no graph is named \"main\" -- the entry graph's two spellings (mode 3 \"pat_flat\", mode 4 \"main\") were a real divergence and this is its regression guard)"; RC=1; }
        if grep -q '\$2F' "$T/$w.$m.tab"; then echo "  identity FAIL ($w $m: an entry carries the assembler mangling tell \$2F -- the map's graph_name is DATA and must be the graph's true name in both media, not whichever spelling the assembler needed): $(grep -m1 '\$2F' "$T/$w.$m.tab")"; RC=1; fi
    done
done
[ "$RC" = 0 ] && echo "  present/agree/identity PASS (population graded --$pop -- read back through rt_gc_frame_maps() in both media, identical entry for entry, entry graph named main, no mangling in any name)"

echo "  planted RETIRED under CEO-1680: the SCRIP_GC_MAPTAB_PLANT seam left emit.cpp; its recorded reading is the fail-once (header)"

if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: the map table is present and installed in both media and the two readings agree entry for entry (examined 3 arms, the planted arm retired)"
else echo "GATE FAIL(1) [$G]: the compile-time map table diverges between the media, is empty, or the read-back stopped discriminating (examined 3 arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
