#!/usr/bin/env bash
# test_gate_gc_icon_allocating_boxes_poll_after_storing_the_result.sh -- an Icon allocating box STORES ITS RESULT to
# its mapped frame cell and then POLLS g_gc_pending at the return, so a collection happens in emitted code with no
# runtime C frame live (.github/ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 7 F6 step 1b, CEO-821; the collector
# guesses nothing, RULES.md FACT RULE, CEO-812).
#
# FAIL-ONCE, MEASURED ON ORIGIN 25282e7a5 (cto, 2026-09-17), the reading the ceo named as this landing's basis:
# `every i := 1 to 4000000 do L := [i, i+1, i+2]` read ONE collection and 861956 KB RSS in mode 3, because
# IR_MAKE_LIST is an emitted box that reaches NO safe point at all -- the shielded rt_gc_point_arr points the frozen
# design keeps are by-name dispatch and string_ops, and an every-do loop over a list constructor enters neither, so
# the pending flag is set inside the first window and nothing takes it until the program ends. With the poll: FIVE
# collections, 161108 KB m3 / 156448 KB m4, answer "done 3" both. The other five Icon allocation shapes measured the
# same sitting (table(), set(), repl(), s1 || s2, s[i:j], a record constructor) are ALREADY bounded through the
# shielded points, which is why this landing is one box and not a sweep: an unmeasured poll is a cost with no reading.
#
# ARMS (all blocking): (0) LIVE -- a value live ONLY in the emitted frame survives the collection the poll takes,
# under SCRIP_GC_STRESS=1 and in an 8 MB window: MEASURED RED BOTH WAYS -- with the poll collecting over the
# conservative entry (cons_stack=1) it SIGSEGVs on poisoned memory, and with gc_zeta_frame left to start at the
# unaligned `char anchor`/`char here` address it SIGSEGVs again, because a sniff that starts 3 bytes off a word
# boundary reads NO stack word correctly (measured: arena-pointing words found from an unaligned start 0, from an
# aligned start 3, 7, 11, 12 on the same four collections). (1) SHAPE, mode 4 -- the emitted .s of the witness shows `call rt_gc_poll` AFTER the two result
# stores that follow `call rt_make_list`, in that order, inside the same box; (2) PLANTED VIOLATION -- the same
# checker run over a copy with the poll deleted must RED, so arm 1 discriminates in both directions; (3) RATE -- the
# churn witness collects more than once and stays under 300 MB with the right answer; (4) BOTH MEDIA AGREE on the
# witness's answer.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
printf 'procedure main()\n   local i, L;\n   every i := 1 to 4000000 do L := [i, i+1, i+2];\n   write("done ", *L);\nend\n' > "$T/churn.icn"
"$SCRIP" --compile "$T/churn.icn" > "$T/churn.s" 2>"$T/compile.err" || { echo "⛔ GATE REFUSE(2) [$G]: mode 4 refused the witness -- $(tail -1 "$T/compile.err")"; exit 2; }
shape() {
    awk '
      /call +rt_make_list/            { seen = 1; stores = 0; next }
      seen && /mov .*qword ptr .*, (rax|rdx)/ { stores++; next }
      seen && /call +rt_gc_poll/      { if (stores >= 2) polled++; seen = 0; next }
      seen && /jmp|^n[0-9]+_/         { seen = 0 }
      END { print polled + 0 }
    ' "$1"
}
sites=$(grep -c 'call  *rt_make_list' "$T/churn.s")
polled=$(shape "$T/churn.s")
if [ "$sites" -ge 1 ] && [ "$polled" = "$sites" ]; then echo "  shape PASS ($polled of $sites rt_make_list returns store the result then call rt_gc_poll, mode 4)"
else echo "  shape FAIL ($polled of $sites rt_make_list returns carry a poll after their result stores -- an Icon allocating box with no safe point at its return)"; RC=1; fi
grep -v 'call  *rt_gc_poll' "$T/churn.s" > "$T/planted.s"
if [ "$(shape "$T/planted.s")" = 0 ]; then echo "  planted PASS (the same checker reads 0 of $sites on a copy with the poll deleted -- arm 1 discriminates in both directions)"
else echo "  planted FAIL (the checker still reads a poll after the poll was deleted -- arm 1 is not measuring)"; RC=1; fi
runs=$(env SCRIP_ZETA_TELEM=1 timeout -k 5 300 "$SCRIP" "$T/churn.icn" 2>&1 >/dev/null | grep -c 'regeneration')
rss=$(/usr/bin/time -f '%M' -o "$T/rss" timeout -k 5 300 "$SCRIP" "$T/churn.icn" >"$T/out" 2>/dev/null; tail -1 "$T/rss")
got=$(cat "$T/out")
if [ "${runs:-0}" -ge 2 ] && [ "${rss:-0}" -lt 307200 ] && [ "$got" = "done 3" ]; then echo "  rate PASS (4M dead lists: $runs collections, RSS ${rss} KB under 300 MB, answer \"$got\" -- origin read 1 collection and 861956 KB)"
else echo "  rate FAIL (4M dead lists: $runs collections, RSS ${rss} KB, answer \"$got\" -- a poll that does not take the pending flag is not a safe point)"; RC=1; fi
gcc -c "$T/churn.s" -o "$T/churn.o" 2>/dev/null && gcc "$T/churn.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/churn.bin" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: the witness would not assemble or link"; exit 2; }
m4=$(timeout -k 5 300 "$T/churn.bin" 2>/dev/null)
if [ "$m4" = "$got" ] && [ "$m4" = "done 3" ]; then echo "  media PASS (mode 3 and mode 4 both answer \"$m4\")"
else echo "  media FAIL (mode 3 \"$got\" vs mode 4 \"$m4\" -- the poll changed an answer)"; RC=1; fi
printf 'procedure main()\n   local i, L;\n   L := [];\n   every i := 1 to 2000 do put(L, [i, i+1, i+2]);\n   write("done ", *L);\nend\n' > "$T/live.icn"
live=$(SCRIP_GC_STRESS=1 timeout -k 5 300 "$SCRIP" "$T/live.icn" 2>/dev/null); lrc=$?
grow=$(SCRIP_HEAP_MB=8 SCRIP_HEAP_MAX_MB=512 timeout -k 5 300 "$SCRIP" "$T/live.icn" 2>/dev/null); grc=$?
if [ "$live" = "done 2000" ] && [ "$lrc" = 0 ] && [ "$grow" = "done 2000" ] && [ "$grc" = 0 ]; then echo "  live PASS (a value that is live ONLY in the emitted frame survives a collection taken at the poll: 2000 lists held by one list, at SCRIP_GC_STRESS=1 and in an 8 MB window)"
else echo "  live FAIL (stress rc=$lrc answer=\"$live\", 8 MB window rc=$grc answer=\"$grow\" -- the collection the poll takes does not see the emitted frame; the sniff over [floor, stack top] must start on an 8-byte boundary and the floor must be the poll's own frame)"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: the Icon list box stores its result then polls, and the collection rate on an allocation loop follows"
else echo "GATE FAIL(1) [$G]: an Icon allocating box reaches no safe point, or the checker stopped discriminating (examined 5 arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
