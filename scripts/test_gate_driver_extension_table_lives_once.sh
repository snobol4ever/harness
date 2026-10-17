#!/usr/bin/env bash
# test_gate_driver_extension_table_lives_once.sh -- THE CLOSED SOURCE-EXTENSION LIST LIVES ONCE, AND AN
# EXTENSION NOT IN IT REFUSES RATHER THAN SELECTING A PATH.  CEO-604, on hq_U's .sbl finding
# (FINDING-2026-09-12-hq_U-an-unknown-source-extension-selects-a-different-emit-path-instead-of-refusing-
# and-a-passing-ablation-explained-one-program-of-twenty-four.md).
#
# ⛔ WHAT IT COST BEFORE THE RULING.  src/driver/scrip.c spelled the extension set twice and the two
# spellings disagreed: the dispatch knew .sno .sc .reb .spt, the usage string printed .sno/.spt .icn .pl
# .sc .reb and omitted .raku and .pas WHICH THE DRIVER ACCEPTS.  Neither was a refusal path.  `.sbl` --
# SPITBOL's own source extension, and what all 36 files of the reference implementation's own test suite
# are named -- was in neither, so every one of them compiled down a path never meant for it: 24 aborted in
# bb_emit_end on a label='RETURN' that mode 4 resolved fine, thousands of sites from the dispatch that
# caused it, and the first reading of that blamed codegen.  One line fixed it and x64tests went 6/36 to
# 18/36 (SCRIP 35bf3ab90).  ⭐ THE GENERAL FORM IS THIS TREE'S OWN, TWICE OVER IN CLAUDE.md: an
# instrument that RESOLVES a name it cannot recognise instead of REFUSING reports the wrong case as a
# working one -- the seat-identity hook falling through to basename, `command -v icont` answering "is it
# on PATH" read as "does it exist".  This is that defect in the driver.
#
# THE ARMS, all behavioural -- the gate runs the binary and reads what it does, never greps the source.
# A source grep would pass a tree that had two agreeing lists, which is the state this ruling forbids:
# two lists that agree today are one edit from two lists that do not.
#   1  the usage NAMES every extension it accepts: a scratch file of each extension the usage prints is
#      NOT refused with the unknown-extension diagnostic (it may fail for any other reason -- a .pas file
#      full of SNOBOL4 is a parse error, and that is not this gate's business).
#   2  an extension the usage does NOT print is REFUSED rc=2, and the refusal NAMES the list.
#   3  .raku and .pas appear in the usage (CEO-604 names them: they were the measured omission).
#   4  the two readers print the SAME set -- the refusal diagnostic's list and the usage's list are
#      byte-identical, which is what "lives once" means observably.
#   5  a file with NO extension is still SNOBOL4 and is not refused, and a path whose DIRECTORY carries a
#      dot does not have that dot read as the file's extension (`/tmp/dot.dir/prog`).  ⛔ ARM 5 IS NOT
#      DECORATION: the pre-ruling code took strrchr over the WHOLE PATH, so a refusal added without the
#      basename fix would reject every no-extension program under any dotted directory -- a new false
#      refusal introduced by the cure for a false acceptance.
#
# REFUSES rc=2 when it cannot measure (no binary, stale binary, mktemp failure).  Never greps a number it
# did not produce: the accepted set is read from the running binary's own usage output every run.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=driver_extension_table_lives_once
SCRIP="$ROOT/scrip"
"$HERE/util_require_fresh.sh" --gate "test_gate_$G" "$SCRIP" "$ROOT/out/libscrip_rt.so" >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$G]: this tree's binary is stale or unbuilt -- run make"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_extbl.XXXXXX")" || { echo "GATE UNPROVEN(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0; EXAMINED=0
red() { FAIL=$((FAIL+1)); echo "  ⛔ $1"; }
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
UNKNOWN_MARK='unknown source extension'
# THE ACCEPTED SET, READ FROM THE BINARY ITSELF.  `scrip` with no file argument prints usage at rc=1.
"$SCRIP" > "$W/usage.out" 2> "$W/usage.err"
USAGE="$(cat "$W/usage.err" "$W/usage.out")"
# ⛔ EXTRACT EVERY EXTENSION ON THE LINE, NOT THE FIRST.  The table prints three per line, and an
# anchored `^[[:space:]]+\.x` regex silently reads one of each three -- the gate's own first run
# refused with "the usage named 4 extension(s)" over a usage listing eleven.  An instrument that
# answers a narrower question than you think you asked is the very class this gate exists for, so it
# is worth the two lines: scope to the block below the header, then take every token on every line.
ext_set() { sed -n '/inferred from file extension/,$p;/Known extensions:/,$p' | grep -oE '(^|[[:space:]])\.[a-zA-Z][a-zA-Z0-9]*([[:space:]]|$)' | tr -d ' ' | sort -u; }
EXTS="$(printf '%s\n' "$USAGE" | ext_set)"
NEXTS="$(printf '%s\n' "$EXTS" | grep -c .)"
# ⛔ A SET MEMBERSHIP TEST NEEDS THE SET IN THE DELIMITER IT IS WRITTEN IN.  $EXTS is newline-separated;
# `case " $EXTS " in *" $e "*)` therefore matched nothing, and ARM 3 reported .raku and .pas MISSING from
# a usage that ARM 1 had just dispatched both from -- two arms of one gate disagreeing about one string.
# Caught only because the arms overlap; a gate with ARM 3 alone would have reported a cured defect as live.
EXTS_SP=" $(printf '%s ' $EXTS)"
[ "$NEXTS" -ge 5 ] || { echo "GATE UNPROVEN(2) [$G]: the usage named $NEXTS extension(s); it cannot be the one table if it names almost none. Usage was:"; printf '%s\n' "$USAGE" | tail -12; exit 2; }
# ARM 1 -- every extension the usage names actually dispatches.
for e in $EXTS; do
    EXAMINED=$((EXAMINED+1))
    printf 'END\n' > "$W/probe$e"
    out="$("$SCRIP" --run "$W/probe$e" < /dev/null 2>&1)"; rc=$?
    if printf '%s' "$out" | grep -q "$UNKNOWN_MARK"; then
        red "ARM 1 $e is printed in the usage but the dispatch REFUSES it as unknown (rc=$rc) -- the two readers have split again"
    else ok "ARM 1 $e dispatches (rc=$rc, not an unknown-extension refusal)"; fi
done
# ARM 2 -- an extension the usage does not name is refused, rc=2, and the refusal names the list.
for e in .xyz .lgt .cob .txt; do
    case "$EXTS_SP" in *" $e "*) continue;; esac
    EXAMINED=$((EXAMINED+1))
    printf 'END\n' > "$W/probe$e"
    out="$("$SCRIP" --run "$W/probe$e" < /dev/null 2>&1)"; rc=$?
    if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "$UNKNOWN_MARK"; then ok "ARM 2 $e REFUSES rc=2 and names the list"
    else red "ARM 2 $e is in no list yet did not refuse: rc=$rc (want 2), diagnostic: $(printf '%s' "$out" | head -1 | cut -c1-90)"; fi
done
# ARM 3 -- the two extensions CEO-604 names, because they were the measured omission.
for e in .raku .pas; do
    EXAMINED=$((EXAMINED+1))
    case "$EXTS_SP" in *" $e "*) ok "ARM 3 $e appears in the usage";; *) red "ARM 3 $e is accepted by the driver but the usage does not print it -- the exact omission CEO-604 ruled on";; esac
done
# ARM 4 -- ONE TABLE, OBSERVABLY: the refusal's list and the usage's list are the same set.
EXAMINED=$((EXAMINED+1))
printf 'END\n' > "$W/probe.xyz"
rout="$("$SCRIP" --run "$W/probe.xyz" < /dev/null 2>&1)"
REXTS="$(printf '%s\n' "$rout" | ext_set)"
if [ "$REXTS" = "$EXTS" ]; then ok "ARM 4 the refusal diagnostic and the usage print the same $NEXTS extensions -- one table, two readers"
else
    red "ARM 4 the refusal's list and the usage's list differ -- that is two lists again"
    echo "       only in usage:    $(comm -23 <(printf '%s\n' "$EXTS") <(printf '%s\n' "$REXTS") | tr '\n' ' ')"
    echo "       only in refusal:  $(comm -13 <(printf '%s\n' "$EXTS") <(printf '%s\n' "$REXTS") | tr '\n' ' ')"
fi
# ARM 5 -- no extension is SNOBOL4, and a dotted DIRECTORY is not read as the file's extension.
mkdir -p "$W/dot.dir"
printf '\tOUTPUT = "ok"\nEND\n' > "$W/dot.dir/noext"
printf '\tOUTPUT = "ok"\nEND\n' > "$W/plainnoext"
for probe in "$W/plainnoext" "$W/dot.dir/noext"; do
    EXAMINED=$((EXAMINED+1))
    out="$("$SCRIP" --run "$probe" < /dev/null 2>&1)"; rc=$?
    if printf '%s' "$out" | grep -q "$UNKNOWN_MARK"; then
        red "ARM 5 $probe has NO extension and was refused as having an unknown one -- the extension is being taken from the path, not the basename"
    elif [ "$out" = "ok" ]; then ok "ARM 5 $(basename "$(dirname "$probe")")/$(basename "$probe") runs as SNOBOL4 (rc=$rc)"
    else red "ARM 5 $probe did not run as SNOBOL4: rc=$rc, output $(printf '%s' "$out" | head -1 | cut -c1-70)"; fi
done
gate_floor "$EXAMINED" 12 "extension arms (usage set + unknown set + the two named + one-table + no-extension)"
echo "------------------------------------------------------------"
gate_verdict "$FAIL" "arm(s) where the driver's extension list is not one table, or does not refuse what it cannot name"
