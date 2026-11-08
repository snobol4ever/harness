#!/usr/bin/env bash
# test_regenerate_parsers_touches_only_changed_bytes.sh -- the parser regenerator replaces an output only when its bytes differ (officer_05 and senior_08, 2026-11-08).
# Runs the regenerator on a SCRATCH copy (harness/scripts and SCRIP/src/parsers under /tmp/s4e/<seat>), never in the tree it grades.
# rc 0 GREEN: (1) after a regeneration every one of the 11 outputs keeps its mtime and its bytes; (2) a deleted output is restored and ONLY it moves.
# rc 1 RED: names what moved. rc 2 REFUSE: no scratch copy, no generator tools, or no outputs to measure.
S4E_ROOT="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"
[ -f "$S4E_ROOT/harness/scripts/regenerate_parser_and_lexer_from_sources.sh" ] && [ -d "$S4E_ROOT/SCRIP/src/parsers" ] || { echo "REFUSE(2): no regenerator or no SCRIP/src/parsers under $S4E_ROOT"; exit 2; }
d="/tmp/s4e/${S4E_SEAT:-seat}"; mkdir -p "$d" || exit 2
T="$(mktemp -d "$d/regen_probe.XXXXXX")" || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/harness" "$T/SCRIP/src" && cp -a "$S4E_ROOT/harness/scripts" "$T/harness/scripts" && cp -a "$S4E_ROOT/SCRIP/src/parsers" "$T/SCRIP/src/parsers" || { echo "REFUSE(2): cannot build the scratch copy"; exit 2; }
snap() { ( cd "$T/SCRIP/src/parsers" && for f in */*.tab.c */*.tab.h */*.lex.c */lex.*.c; do [ -f "$f" ] && printf '%s %s %s\n' "$(stat -c %Y.%y "$f")" "$(cksum < "$f")" "$f"; done ) | sort -k3; }
a="$(snap)"; n="$(printf '%s\n' "$a" | grep -c .)"
[ "$n" -ge 11 ] || { echo "REFUSE(2): only $n generated outputs in the scratch copy"; exit 2; }
sleep 2
( cd "$T/SCRIP" && timeout -k 5 300 bash ../harness/scripts/regenerate_parser_and_lexer_from_sources.sh < /dev/null > "$T/run1.log" 2>&1 ) || { echo "REFUSE(2): the regenerator failed: $(tail -1 "$T/run1.log")"; exit 2; }
b="$(snap)"
if [ "$a" != "$b" ]; then echo "RED: a regeneration with no source change moved outputs (mtime or bytes):"; diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") | head -6; echo "GATE FAIL [test_regenerate_parsers_touches_only_changed_bytes]"; exit 1; fi
rm -f "$T/SCRIP/src/parsers/pascal/pascal.tab.h"; c="$(snap)"; sleep 2
( cd "$T/SCRIP" && timeout -k 5 300 bash ../harness/scripts/regenerate_parser_and_lexer_from_sources.sh < /dev/null > "$T/run2.log" 2>&1 ) || { echo "REFUSE(2): the regenerator failed on run 2: $(tail -1 "$T/run2.log")"; exit 2; }
e="$(snap)"
moved="$(diff <(printf '%s\n' "$c") <(printf '%s\n' "$e") | grep -c '^>')"
[ -f "$T/SCRIP/src/parsers/pascal/pascal.tab.h" ] || { echo "RED: a deleted output was not restored"; echo "GATE FAIL [test_regenerate_parsers_touches_only_changed_bytes]"; exit 1; }
[ "$moved" = 1 ] || { echo "RED: restoring one deleted output moved $moved entries (want exactly 1)"; echo "GATE FAIL [test_regenerate_parsers_touches_only_changed_bytes]"; exit 1; }
echo "GATE OK [test_regenerate_parsers_touches_only_changed_bytes]: $n outputs kept mtime and bytes; a deleted output came back alone"
exit 0
