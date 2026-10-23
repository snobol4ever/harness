#!/usr/bin/env bash
# ../harness/scripts/test_gate_icon_m4_invocation_is_pinned.sh -- THE PROGRAM NAME IS THE SAME IN BOTH MODES: THE BARE STEM.
# DONE-WHEN for row icon-progname-class-one-ref-cannot-be-right-for-both-modes-master-and-jcon (CEO-569), rewritten
# under ceo CEO-624 (2026-09-12) on Lon's word, verbatim: "Why is mode 3 different from mode 4? they were intended to
# be identical."  AUTHORS: Lon Jones Cherryholmes · Claude Fable 5.1   DATE: 2026-09-12 (first version Opus 5, 09-11)
#
# ⭐⭐ THE MEASUREMENT THIS GATE RESTS ON, taken on the ORACLE (Arizona icont/iconx 9.5.25a) and re-taken every run:
#     iconx pn                  -> &progname: pn          (the program invoked by its bare name)
#     ./pn                      -> &progname: ./pn
#     /abs/path/to/pn           -> &progname: /abs/path/to/pn
# &progname is the name the program was INVOKED BY.  CEO-581 let the two modes answer differently because the
# runners invoked them differently (m3 was handed `<stem>.icn`, m4 was run as `./<stem>`) and covered the gap with a
# PER-MODE REF.  CEO-624 closes the gap at its cause instead: THE PROGRAM NAME IS THE SAME STRING IN BOTH MODES.
#   * mode 3: `scrip --run path/<stem>.icn` names the program `path/<stem>` -- the source path with its extension
#     stripped, which is exactly the name icont gives the program it builds from that source;
#   * mode 4: every runner invokes the binary by that same string -- the bare `<stem>`, resolved through PATH (the
#     rungs harness, the jcon runner and the arizona runner all put the binary's directory first on PATH and invoke
#     `<stem>`), so argv[0] is `<stem>` and the oracle under the same invocation (`iconx <stem>`) answers the same;
#   * therefore ONE ref line is right for both modes, cut from the oracle under `iconx <stem>`, and NO per-mode
#     declaration exists at all -- the .moderef mechanism is gone (CEO-1218/1230: one machine in two media, one ref).
#
# ⛔ IT GRADES ON ITS OWN FIXTURES, NEVER ON A BOARD (CEO-547 part 2, ONE RUNNER ONE BOARD): a source-level assertion
# over the three graders, a live round trip on a witness it compiles itself, the one-entry rungs graded THROUGH the
# harness, and the two shipped programs that print &progname extracted and run directly.  No board, no row written.
# With icont unreachable this gate REFUSES rc=2: an instrument that cannot measure refuses.
#
# EXIT: 0 every clause green · 1 a clause is red (the report names which) · 2 REFUSED -- cannot measure.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
HARNESS="$HERE/corpus_suite_harness.py"; JCON="$HERE/test_icon_jcon_suite.sh"; ARIZ="$HERE/test_icon_arizona_suite.sh"
. "$HERE/lib_oracle_flags.sh"
. "$HERE/lib_board_line.sh"      # board_is: a board field is read BY NAME, never by adjacency (CEO-839)
SCRIP="$ROOT/scrip"; RT="$ROOT/out"
for f in "$HARNESS" "$JCON" "$ARIZ"; do [ -f "$f" ] || { echo "REFUSED rc=2: $f is missing -- cannot measure"; exit 2; }; done
[ -x "$SCRIP" ] || { echo "REFUSED rc=2: no $SCRIP -- run make, then re-run"; exit 2; }
command -v gcc >/dev/null 2>&1 || { echo "REFUSED rc=2: no gcc -- cannot build a mode-4 witness"; exit 2; }
RED=0; GREEN=0
say_ok()   { echo "  ok    $*"; GREEN=$((GREEN+1)); }
say_fail() { echo "  FAIL  $*"; RED=$((RED+1)); }

echo "CLAUSE 1 -- every grader invokes the mode-4 binary by its bare stem through PATH (source-level)"
if grep -q 'argv = stdbuf_wrap(paths, \[out_bin.name\])' "$HARNESS" && grep -q 'PATH=str(out_bin.parent) + os.pathsep' "$HARNESS"; then
  say_ok "rungs harness: run_m4 invokes <stem> with the binary's directory first on PATH"
else
  say_fail "rungs harness: run_m4 no longer invokes the bare <stem> through PATH"
fi
if grep -qE 'PATH="\$rundir:\$PATH" .*(timeout|"\$TIMEOUT_RETRY") "\$TIMEOUT" "\$name"' "$JCON"; then
  say_ok "jcon runner: invokes <stem> with the rundir first on PATH"
else
  say_fail "jcon runner: the mode-4 binary is not invoked by its bare stem through PATH"
fi
if grep -qE 'PATH="\$RUNDIR/m4bin:\$SUITE:\$PATH" .*(timeout|"\$TIMEOUT_RETRY") "\$TIMEOUT" "\$name"' "$ARIZ"; then
  say_ok "arizona runner: invokes <stem> by its bare name, its run directory's m4bin first on PATH (the binary never lands in the corpus, coo 2026-10-23)"
else
  say_fail "arizona runner: the mode-4 binary is not invoked by its bare stem through PATH"
fi

echo "CLAUSE 2 -- the live round trip: both modes answer the bare stem, and the unpinned invocation is still observable"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
printf 'procedure main()\n   write("&progname: ", &progname);\nend\n' > "$W/pinwitness.icn"
GOT3="$( cd "$W" && SNO_LIB="$S4E/corpus/include" "$SCRIP" --run pinwitness.icn </dev/null 2>&1 )"
if [ "$GOT3" = "&progname: pinwitness" ]; then say_ok "mode 3: scrip --run pinwitness.icn answers pinwitness (the extension stripped, the path form kept)"
else say_fail "mode 3: expected '&progname: pinwitness', got '$GOT3'"; fi
GOT3D="$( cd "$W" && SNO_LIB="$S4E/corpus/include" "$SCRIP" --run ./pinwitness.icn </dev/null 2>&1 )"
if [ "$GOT3D" = "&progname: ./pinwitness" ]; then say_ok "mode 3: scrip --run ./pinwitness.icn answers ./pinwitness (only the extension goes; the caller's path form is kept, as icont keeps it)"
else say_fail "mode 3: expected '&progname: ./pinwitness' for the ./ form, got '$GOT3D'"; fi
( cd "$W" && SNO_LIB="$S4E/corpus/include" "$SCRIP" --compile pinwitness.icn > p.s 2>/dev/null ) || { echo "REFUSED rc=2: scrip --compile failed on the gate's own witness -- cannot measure"; exit 2; }
gcc -c "$W/p.s" -o "$W/p.o" 2>/dev/null || { echo "REFUSED rc=2: gcc -c failed on the gate's own witness -- cannot measure"; exit 2; }
gcc "$W/p.o" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$W/pinwitness" 2>/dev/null || { echo "REFUSED rc=2: link failed on the gate's own witness -- cannot measure"; exit 2; }
GOT4="$( cd "$W" && PATH="$W:$PATH" pinwitness </dev/null 2>&1 )"
if [ "$GOT4" = "&progname: pinwitness" ]; then say_ok "mode 4: the binary invoked as pinwitness through PATH answers pinwitness -- the same string as mode 3"
else say_fail "mode 4: expected '&progname: pinwitness', got '$GOT4'"; fi
GOTABS="$( cd "$W" && "$W/pinwitness" </dev/null 2>&1 )"
if [ "$GOTABS" = "&progname: $W/pinwitness" ]; then say_ok "fail-once arm: the same binary invoked by its absolute path answers the absolute path, so the bare-name rule is observable and not vacuous"
else say_fail "fail-once arm: the absolute invocation answered '$GOTABS' -- this gate can no longer tell a pinned invocation from an unpinned one"; fi

echo "CLAUSE 3 -- measured through the grading path itself: a one-entry rungs whose ref says <stem> passes BOTH modes"
PW="$W/livepin"; mkdir -p "$PW"
printf '#%s 1 pinwitness\nprocedure main()\n   write("&progname: ",&progname);\nend\n' "-----------------" > "$PW/ALL.icn"
printf '#%s 1 pinwitness\n&progname: pinwitness\n' "-----------------" > "$PW/ALL.ref"
LIVE="$(timeout -k 5 120s python3 "$HARNESS" run --lang icon --modes m3,m4 "$PW/ALL.icn" "$PW/ALL.ref" 2>&1)"
# fields read BY NAME, never by adjacency: 'm3_n=1 m3_pass=1' asserted the board's LAYOUT, and the board
# gained shipped=/outside= once already (CEO-749/772; the same pattern shape left arm 9 of
# test_gate_harness_refusal_is_rc2.sh red for a day over a correct board -- CEO-839).
_lb="$(grep -m1 '^SUITE_BOARD ' <<<"$LIVE")"
if board_is "$_lb" m3_n 1 && board_is "$_lb" m3_pass 1 && board_is "$_lb" m4_n 1 && board_is "$_lb" m4_pass 1; then
  say_ok "LIVE: the harness grades the entry green in m3 AND m4 against ONE ref line -- the rule holds where entries are actually graded"
else
  say_fail "LIVE: the harness does not grade the entry green in both modes against one ref line ($(printf '%s' "$LIVE" | grep -o 'm[34]_pass=[0-9]*' | tr '\n' ' '))"
fi

echo "CLAUSE 4 -- the oracle, re-measured: iconx <stem> answers <stem>, and the shipped refs say exactly that"
ICONT="$(icont_bin)" || { echo "REFUSED rc=2: Arizona icont is unreachable, so the earning measurement cannot be re-taken -- an instrument that cannot measure refuses"; exit 2; }
OD="$W/oracle"; mkdir -p "$OD"; printf 'procedure main()\n   write("   &progname: ",&progname);\nend\n' > "$OD/pn.icn"
( cd "$OD" && "$ICONT" -s pn.icn >/dev/null 2>&1 ) || { echo "REFUSED rc=2: icont could not build the oracle witness -- cannot measure"; exit 2; }
O_BARE="$( cd "$OD" && "$(dirname "$ICONT")/iconx" pn 2>&1 )"; O_DOT="$( cd "$OD" && ./pn 2>&1 )"
if [ "$O_BARE" = "   &progname: pn" ] && [ "$O_DOT" = "   &progname: ./pn" ]; then
  say_ok "oracle: 'iconx pn' answers pn and './pn' answers ./pn -- the name IS the invocation, and the bare invocation is the one every grader now makes"
else
  say_fail "oracle answers forms this gate does not recognise (bare '$O_BARE' · dot '$O_DOT') -- re-measure before trusting any ref that prints &progname"
fi
RUNGS="$S4E/corpus/tests/icon"; JC="$S4E/corpus/packages/icon/jcon_tests"; AZ="$S4E/corpus/packages/icon/arizona_tests/general"
if grep -q '^   &progname: procedure_every_alt_replace_4$' "$RUNGS/ALL.ref"; then say_ok "IcnRungs entry procedure_every_alt_replace_4: the ref line reads the bare stem"; else say_fail "IcnRungs entry procedure_every_alt_replace_4: the ref line does not read the bare stem"; fi
if grep -q '^   &progname: kwds$' "$JC/kwds.ref"; then say_ok "jcon kwds.ref: the ref line reads the bare stem"; else say_fail "jcon kwds.ref: the ref line does not read the bare stem"; fi
if grep -q '^   &progname: kwds$' "$AZ/kwds.ref"; then say_ok "arizona kwds.ref: the ref line reads the bare stem"; else say_fail "arizona kwds.ref: the ref line does not read the bare stem"; fi
n_decl=$(find "$S4E/corpus" -name '*.moderef' -not -path '*/.git/*' 2>/dev/null | wc -l)
if [ "$n_decl" -eq 0 ]; then
  say_ok "no per-mode ref declaration (.moderef) exists anywhere in the corpus -- one ref serves both modes"
else
  say_fail "$n_decl per-mode ref declaration file(s) (.moderef) survive in the corpus: $(find "$S4E/corpus" -name '*.moderef' -not -path '*/.git/*' | head -3 | tr '\n' ' ')"
fi

echo "CLAUSE 5 -- the two shipped programs that print &progname reproduce their refs in BOTH modes, run the way the graders run them"
run_both() {  # <label> <dir> <stem> <ref>
  local label="$1" dir="$2" stem="$3" ref="$4" o3 o4
  o3="$( cd "$dir" && SNO_LIB="$S4E/corpus/include" timeout -k 5 30s "$SCRIP" --run "$stem.icn" </dev/null 2>&1 )"
  if [ "$o3" = "$(cat "$ref")" ]; then say_ok "$label: mode 3 reproduces its ref"; else say_fail "$label: mode 3 differs from its ref on $(diff <(printf '%s\n' "$o3") "$ref" | grep -c '^[<>]') line(s)"; fi
  ( cd "$dir" && SNO_LIB="$S4E/corpus/include" "$SCRIP" --compile "$stem.icn" > "$dir/q.s" 2>/dev/null ) || { say_fail "$label: scrip --compile failed"; return; }
  gcc -c "$dir/q.s" -o "$dir/q.o" 2>/dev/null && gcc "$dir/q.o" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$dir/$stem" 2>/dev/null || { say_fail "$label: build failed"; return; }
  o4="$( cd "$dir" && PATH="$dir:$PATH" timeout -k 5 30s "$stem" </dev/null 2>&1 )"
  if [ "$o4" = "$(cat "$ref")" ]; then say_ok "$label: mode 4 reproduces the SAME ref"; else say_fail "$label: mode 4 differs from its ref on $(diff <(printf '%s\n' "$o4") "$ref" | grep -c '^[<>]') line(s)"; fi
}
EX="$W/e924"; mkdir -p "$EX"
if RUNGS_EXT=.icn RUNGS_DIR="$RUNGS" bash -c "source '$HERE/lib_rungs_extract.sh'; rungs_extract_name procedure_every_alt_replace_4 '$EX/procedure_every_alt_replace_4.icn' '$EX/procedure_every_alt_replace_4.ref'" >/dev/null 2>&1; then
  run_both "IcnRungs entry 924 procedure_every_alt_replace_4" "$EX" procedure_every_alt_replace_4 "$EX/procedure_every_alt_replace_4.ref"
else
  echo "REFUSED rc=2: could not extract entry 924 from the Icon rungs -- cannot measure"; exit 2
fi
KD="$W/kwds"; mkdir -p "$KD"; cp "$JC/kwds.icn" "$KD/"; run_both "jcon kwds" "$KD" kwds "$JC/kwds.ref"

echo
if [ "$RED" -eq 0 ]; then echo "GATE PASS(0) [icon_m4_invocation_is_pinned]: $GREEN/$GREEN checks -- the program name is the bare stem in both modes."; exit 0
else echo "GATE FAIL(1) [icon_m4_invocation_is_pinned]: $RED red of $((RED+GREEN))"; exit 1; fi
