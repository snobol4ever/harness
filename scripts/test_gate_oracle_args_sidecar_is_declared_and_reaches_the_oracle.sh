#!/usr/bin/env bash
# test_gate_oracle_args_sidecar_is_declared_and_reaches_the_oracle.sh -- THE ORACLE'S COMMAND-LINE SIZE IS DECLARED BESIDE THE UNIT AND
# EVERY TOOL THAT RUNS THE UNIT PASSES IT (ceo CEO-1353, RULES.md clause 8 (g)(3): "oracle_args for sbl -d/-s ... the one reader passes it
# whenever the oracle runs live or a ref is cut"; (g)(4): a runner types no size of its own). oracle_env's twin for an oracle sized on its
# command line: <stem>.oracle_args, one line NAME<TAB>SWITCH[ SWITCH], read by lib_declared_arena.sh's declared_oracle_args_beside through
# corpus_suite_harness.oracle_args_declarations -- the one reader.
#   R1-R7  the reader: a declared line echoes its switches; an unadmitted switch (-i), another unit's name, a malformed size, a switch
#          named twice and an empty line each REFUSE rc 2; no sidecar echoes nothing, rc 0.
#   R8-R10 the ruled oracle FLAGS (ORACLE_FLAGS_ADMITTED; CEO-1540, the cto 2026-10-07: prolog_recognizer is graded against swipl
#          --traditional): the flag echoes whole; another spelling of it and a flag named twice REFUSE rc 2.
#   B      the declaration is the oracle's NEED, read behaviourally: a 100000-deep SNOBOL4 recursion dies ERROR 246 under sbl -bf at its
#          default stack and prints its depth under the switches the reader echoes for its sidecar.
#   C      the bootstrap parser chain declares: every bootstrap/parser_<lang>.sc carries .heap and .stack the one reader turns into scrip's
#          -d/-s switches and an .oracle_args it accepts (the coo 2026-10-03: the chain dies ERROR 246 under sbl at its default stack on
#          the snocone, icon and pascal workhorse inputs).
#   W      the ten tools that run the chain (the parse grid and its phase profile since CEO-1485) read the chain's declaration -- each calls the reader on the chain -- and a doctored copy
#          of util_parser_furthest_cursor.sh that types sbl's size again instead of passing it reads RED here (fail once). That no tool
#          types a size is test_gate_no_runner_types_a_size_or_sets_the_window.sh's census.
#   W2     the eight SNOBOL4 tools that run sbl on a unit -- the scorecard (the Gimpel, Budne, AIS and Dotnet engine), the bench-ref
#          minter, the two demo identity boards and, since CEO-1485, the four timing benches (rep loop, bar, campaign probe, demo
#          triangulation) -- pass that unit's declared switches to sbl, and SCRIP's declared sizes where they run
#          it (the coo 2026-10-03: treebank's full input dies ERROR 246 at sbl's default stack; demos/snobol4/treebank/treebank.oracle_args).
# EXIT: 0 every arm holds; 1 an arm is red; 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
G=test_gate_oracle_args_sidecar_is_declared_and_reaches_the_oracle
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: lib_declared_arena.sh unloadable"; exit 2; }
declare -F declared_oracle_args_beside >/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: lib_declared_arena.sh no longer defines declared_oracle_args_beside"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: lib_oracle_flags.sh unloadable"; exit 2; }
SBL="$(sbl_correctness_bin 2>/dev/null)"; SBLF="$(sbl_lang_flags 2>/dev/null)"
[ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no SNOBOL4 oracle"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_oargs.XXXXXX")" || { echo "⛔ GATE REFUSE(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
RED=0; N=0
ok() { N=$((N+1)); echo "  ok   $*"; }
bad() { N=$((N+1)); echo "  FAIL $*"; RED=1; }
rd() { local o rc; o="$(declared_oracle_args_beside "$1" 2>/dev/null)"; rc=$?; printf '%s|%s' "$rc" "$o"; }
: > "$W/u.sno"
printf 'u\t-s64m -d512m\n' > "$W/u.oracle_args"
[ "$(rd "$W/u.sno")" = "0|-s64m -d512m" ] && ok "R1 a declared line echoes its switches" || bad "R1 the reader echoed '$(rd "$W/u.sno")'"
printf 'u\t-i64m\n' > "$W/u.oracle_args"
[ "$(rd "$W/u.sno")" = "2|" ] && ok "R2 a switch outside the admitted list (-i) REFUSES rc 2" || bad "R2 an unadmitted switch read '$(rd "$W/u.sno")'"
printf 'v\t-s64m\n' > "$W/u.oracle_args"
[ "$(rd "$W/u.sno")" = "2|" ] && ok "R3 another unit's name REFUSES rc 2" || bad "R3 another unit's line read '$(rd "$W/u.sno")'"
printf 'u\t-sbig\n' > "$W/u.oracle_args"
[ "$(rd "$W/u.sno")" = "2|" ] && ok "R4 a malformed size REFUSES rc 2" || bad "R4 a malformed size read '$(rd "$W/u.sno")'"
printf 'u\t-s64m -s128m\n' > "$W/u.oracle_args"
[ "$(rd "$W/u.sno")" = "2|" ] && ok "R5 a switch named twice REFUSES rc 2" || bad "R5 a repeated switch read '$(rd "$W/u.sno")'"
printf 'u\t\n' > "$W/u.oracle_args"
[ "$(rd "$W/u.sno")" = "2|" ] && ok "R6 an empty declaration REFUSES rc 2" || bad "R6 an empty declaration read '$(rd "$W/u.sno")'"
rm -f "$W/u.oracle_args"
[ "$(rd "$W/u.sno")" = "0|" ] && ok "R7 no sidecar echoes nothing, rc 0" || bad "R7 no sidecar read '$(rd "$W/u.sno")'"
printf 'u\t--traditional\n' > "$W/u.oracle_args"
[ "$(rd "$W/u.sno")" = "0|--traditional" ] && ok "R8 the ruled oracle flag --traditional (CEO-1540) echoes whole" || bad "R8 the ruled flag read '$(rd "$W/u.sno")'"
printf 'u\t--traditional=true\n' > "$W/u.oracle_args"
[ "$(rd "$W/u.sno")" = "2|" ] && ok "R9 a flag spelled other than its ruling (--traditional=true) REFUSES rc 2" || bad "R9 a misspelled flag read '$(rd "$W/u.sno")'"
printf 'u\t--traditional --traditional\n' > "$W/u.oracle_args"
[ "$(rd "$W/u.sno")" = "2|" ] && ok "R10 a flag named twice REFUSES rc 2" || bad "R10 a repeated flag read '$(rd "$W/u.sno")'"
rm -f "$W/u.oracle_args"

printf "        DEFINE('R(N)')                    :(REND)\nR       R = EQ(N,0) 0                     :S(RETURN)\n        R = R(N - 1) + 1                  :(RETURN)\nREND    OUTPUT = 'depth=' R(100000)\nEND\n" > "$W/deep.sno"
printf 'deep\t-s64m\n' > "$W/deep.oracle_args"
OA="$(declared_oracle_args_beside "$W/deep.sno")" || { echo "⛔ GATE REFUSE(2) [$G]: the reader refused a well-formed fixture"; exit 2; }
d0="$( cd "$W" && timeout -k 5 60 "$SBL" $SBLF deep.sno < /dev/null 2>&1 )"; r0=$?
d1="$( cd "$W" && timeout -k 5 60 "$SBL" $SBLF $OA deep.sno < /dev/null 2>&1 )"; r1=$?
if [ "$r0" -eq 124 ] || [ "$r1" -eq 124 ]; then echo "⛔ GATE REFUSE(2) [$G]: the recursion fixture timed out (default rc=$r0, declared rc=$r1)"; exit 2; fi
if grep -q 'ERROR 246' <<<"$d0" && ! grep -q '^depth=' <<<"$d0" && [ "$d1" = depth=100000 ]; then
  ok "B  at sbl's default stack the recursion dies ERROR 246; under the declared ${OA} it prints depth=100000"
else bad "B  default rc=$r0 '$(tr '\n' ' ' <<<"$d0" | head -c 80)', declared rc=$r1 '$(head -c 80 <<<"$d1")' -- the declaration is not the oracle's need"; fi

cdecl=""; nl=0
for L in snobol4 snocone icon prolog rebus raku pascal; do
  p="$ROOT/bootstrap/parser_$L.sc"; [ -f "$p" ] || { echo "⛔ GATE REFUSE(2) [$G]: no $p"; exit 2; }
  nl=$((nl+1)); sw="$(declared_switches_beside "$p" 2>/dev/null)"; r1=$?; oa="$(declared_oracle_args_beside "$p" 2>/dev/null)"; r2=$?
  { [ "$r1" = 0 ] && [ -n "$sw" ] && [ "$r2" = 0 ] && [ -f "${p%.sc}.oracle_args" ]; } || cdecl="$cdecl parser_$L(scrip '$sw' rc $r1, sbl '$oa' rc $r2)"
done
[ -z "$cdecl" ] && ok "C  all $nl bootstrap parser chains declare scrip's heap and stack and sbl's switches, and the one reader accepts each" \
  || bad "C  a chain's declaration is missing or refused:$cdecl"

# tool <file> <pattern...> -- the tool calls the reader on the chain: every pattern is present
TOOLS=(
  "run_scrip_parser.sh|declared_switches_beside \"\$DRIVER\""
  "run_parser_sync_monitor.sh|declared_oracle_args_beside \"\$PARSER_SC\""
  "util_parser_furthest_cursor.sh|declared_switches_beside \"\$parser\"|declared_oracle_args_beside \"\$parser\"|\"\$SBL\" -bf \$OARGS \"\$twin\"|scrip\" \$SW \"\$twin\""
  "util_parser_sc_grade.sh|declared_switches_beside \"\$B/parser_\$L.sc\"|\"\$BIN\" \$SW < /dev/null"
  "util_parser_speed_c_vs_sc.sh|declared_switches_beside \"\$B/parser_\$L.sc\"|\"\$T/\$L.bin\" \$SW < \"\$f\""
  "util_regen_parser_demos.sh|declared_oracle_args_beside \"\$B/parser_\$L.sc\"|\"\$SBL\" -bf \$OARGS"
  "util_parser_sc_census.py|_harness.heap_declarations(drv)|_harness.stack_declarations(drv)|[scrip] + arena(lang) + [chain]"
  "util_parser_grid.sh|SWS=\"\$(declared_switches_beside \"\$B/parser_\$L.sc\")\"|SWB=\"\$(declared_oracle_args_beside \"\$B/parser_\$L.sc\")\"|\"\$T/\$L.bin\" \$SWS < /dev/null|\"\$SBL\" -bf \$SWB \"\$T/\$L.sno\""
  "util_parser_phase_profile.sh|SW=\"\$(declared_switches_beside \"\$B/parser_\$L.sc\")\""
  "test_bootstrap_parsers.py|_harness.heap_declarations(str(drv))|_harness.oracle_args_declarations(|[str(SBL), \"-bf\"] + sbl_args(lang)|[str(SCRIP)] + scrip_arena(lang)|[str(exe)] + scrip_arena(lang)"
)
wired() { local f="$1"; shift; local p; for p in "$@"; do grep -qF -- "$p" "$f" || return 1; done; return 0; }
unwired=""
for t in "${TOOLS[@]}"; do
  IFS='|' read -r -a parts <<<"$t"; f="$HERE/${parts[0]}"
  [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: ${parts[0]} absent"; exit 2; }
  wired "$f" "${parts[@]:1}" || unwired="$unwired ${parts[0]}"
done
[ -z "$unwired" ] && ok "W  all ${#TOOLS[@]} tools that run the chain pass its declared sizes to scrip and to sbl" || bad "W  a tool no longer passes the chain's declaration:$unwired"
FC="$HERE/util_parser_furthest_cursor.sh"
sed 's/"\$SBL" -bf \$OARGS "\$twin"/"$SBL" -bf -s2000m -d4000m "$twin"/' "$FC" > "$W/doctored.sh"
cmp -s "$FC" "$W/doctored.sh" && { echo "⛔ GATE REFUSE(2) [$G]: the doctoring edit did not apply"; exit 2; }
IFS='|' read -r -a parts <<<"${TOOLS[2]}"
if wired "$W/doctored.sh" "${parts[@]:1}"; then bad "W' a copy that types sbl's size again still reads as wired"; else ok "W' a copy of util_parser_furthest_cursor.sh that types sbl's size again reads RED (fail once)"; fi
SNO_TOOLS=(
  "scorecard_snobol4.sh|oa=\"\$(declared_oracle_args_beside \"\$prog\")\"|\"\$SBL\" \$(sbl_flags) \$oa \"\$prog\"|declared_oracle_args_beside; export"
  "util_mint_bench_refs.sh|oa=\"\$(declared_oracle_args_beside \"\$sno\")\"|\"\$SBL\" \$(sbl_lang_flags) \$oa \"\$sno\""
  "test_demo_full_3way.sh|sw=\"\$(declared_switches_beside \"\$src\")\" && oa=\"\$(declared_oracle_args_beside \"\$src\")\"|\"\$SBL\" \$(sbl_lang_flags) \$oa|--run \$sw \"\$src\"|\"\$W/\$nm.prog\" \$sw"
  'bench_rep_loop_demos_snobol4.sh|SWD="$(declared_switches_beside "$1")" && OAD="$(declared_oracle_args_beside "$1")"|$(sbl_lang_flags) $OAD "$v"|"$SCRIP" $SWD "$v"|"$W/$stem.bin" $SWD|decl_of "$P"'
  "bench_snobol4_bar.sh|SWD=\"\$(declared_switches_beside \"\$P\")\" && OAD=\"\$(declared_oracle_args_beside \"\$P\")\"|best sbl \"\$SBL\" -bf \$OAD \"\$P\"|best m4 \"\$T/d.prog\" \$SWD"
  "bench_snobol4_campaign_probe.sh|ksw=\"\$(declared_switches_beside \"\$K/\$k.sno\")\"|\$(sbl_lang_flags) \$koa \"\$k.sno\"|\"\$W/\$k.bin\" \$ksw|\$(sbl_lang_flags) \$toa treebank.sno|\"\$W/tb.bin\" \$tsw"
  "bench_triangulate_demos_snobol4.sh|SWD=\"\$(declared_switches_beside \"\$P\")\" && OAD=\"\$(declared_oracle_args_beside \"\$P\")\"|\$(sbl_lang_flags) \$OAD \"\$prog\"|--run \$SWD \"\$prog\"|\"\$W/\$stem.prog\" \$SWD"
  "board_sno15_ident.sh|sw=\"\$(declared_switches_beside \"\$src\")\" && oa=\"\$(declared_oracle_args_beside \"\$src\")\"|\"\$SBL\" \$(sbl_lang_flags) \$oa|--run \$sw \"\$src\"|\"\$W/\$nm.prog\" \$sw"
)
unwired=""
for t in "${SNO_TOOLS[@]}"; do
  IFS='|' read -r -a parts <<<"$t"; f="$HERE/${parts[0]}"
  [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: ${parts[0]} absent"; exit 2; }
  wired "$f" "${parts[@]:1}" || unwired="$unwired ${parts[0]}"
done
[ -z "$unwired" ] && ok "W2 all ${#SNO_TOOLS[@]} SNOBOL4 tools that run sbl on a unit pass its declared switches (and SCRIP's declared sizes where they run it)" || bad "W2 a SNOBOL4 tool no longer passes the unit's declaration:$unwired"
echo "population: $N check(s): 10 reader shapes, one oracle recursion, $nl chain declarations, ${#TOOLS[@]} chain tools, one doctored copy, ${#SNO_TOOLS[@]} SNOBOL4 tools"
if [ "$RED" = 0 ]; then echo "✅ GATE PASS [$G]: the oracle's declared switches are read by the one reader, refused when malformed, needed by the oracle, declared by every parser chain and passed by every tool that runs it and by the SNOBOL4 tools"; exit 0; fi
echo "⛔ GATE FAIL [$G]"; exit 1
