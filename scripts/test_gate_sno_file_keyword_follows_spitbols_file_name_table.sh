#!/usr/bin/env bash
# test_gate_sno_file_keyword_follows_spitbols_file_name_table.sh -- &FILE, &LINE, &LASTFILE and &LASTLINE around -INCLUDE and
# -LINE answer as sbl -bf in both modes (row snobol4-budne-atn-include-and-line-read-pass-ceo-1812: Budne include and line FAIL in
# both modes on 92893767d). SPITBOL maps statement numbers to file names in one table (r_sfn, sbl.min filnm/newfn/read4): a new
# file name is entered at the next statement's number, and an include's end re-enters the outer name at cmpsn+1 -- right when the
# include's last line is a statement (its end is read by the continuation peek, cmpsn still that statement's), one statement late
# when it is a comment or a control card (read after cmpsn was bumped), so the first outer statement keeps the include's name. A
# blank line is a null statement and takes that name itself; a comment before a -LINE latches nothing. The ref is CUT FROM THE
# ORACLE at run time (sbl -bf in the witness directory), never typed; mode 4 is linked the way the harness grades (PIE, CEO-1536).
# FAIL_ONCE (2026-10-17, the tree before the cure, e92e2acc8, built in a scratch worktree): RED in both modes -- 6 of 9 witnesses
# diverge (cmt, card, inc_inc, inc_line, nested, cmt_line; blank, stmt and blank_after read green there, the old tree latching
# nothing); blank_after guards the null-statement arm and read red on the cure's first draft, which carried the latch past a blank
# line. With the cure 18 of 18 arms equal the oracle.
# rc 0 every witness in both modes equals the oracle / 1 an arm diverged / 2 could not measure (no scrip, runtime or oracle, or the
# oracle printed nothing for a witness).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- the ref is cut from the oracle at run time"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cd "$T" || exit 2
P=' OUTPUT = &FILE ":" &LINE " " &LASTFILE ":" &LASTLINE " " &STNO'
printf '%s\n*c\n' "$P" > i_cmt.sno
printf '%s\n-EJECT\n' "$P" > i_card.sno
printf '%s\n\n' "$P" > i_blank.sno
printf '%s\n' "$P" > i_stmt.sno
printf '%s\n*c\n' "$P" > i_cmt2.sno
printf '%s\n-INCLUDE '"'"'i_cmt.sno'"'"'\n' "$P" > i_nest.sno
printf '%s\n-INCLUDE '"'"'i_cmt.sno'"'"'\n*x\n%s\n%s\nEND\n' "$P" "$P" "$P" > cmt.sno
printf '%s\n-INCLUDE '"'"'i_card.sno'"'"'\n%s\n%s\nEND\n' "$P" "$P" "$P" > card.sno
printf '%s\n-INCLUDE '"'"'i_blank.sno'"'"'\n%s\n%s\nEND\n' "$P" "$P" "$P" > blank.sno
printf '%s\n-INCLUDE '"'"'i_stmt.sno'"'"'\n%s\n%s\nEND\n' "$P" "$P" "$P" > stmt.sno
printf '%s\n-INCLUDE '"'"'i_cmt.sno'"'"'\n-INCLUDE '"'"'i_cmt2.sno'"'"'\n%s\n%s\nEND\n' "$P" "$P" "$P" > inc_inc.sno
printf '%s\n-INCLUDE '"'"'i_cmt.sno'"'"'\n-LINE 5 "foo"\n%s\n%s\nEND\n' "$P" "$P" "$P" > inc_line.sno
printf '%s\n-INCLUDE '"'"'i_nest.sno'"'"'\n%s\n%s\nEND\n' "$P" "$P" "$P" > nested.sno
printf '%s\n-INCLUDE '"'"'i_cmt.sno'"'"'\n\n%s\n%s\nEND\n' "$P" "$P" "$P" > blank_after.sno
printf '%s\n*c\n-LINE 10 "foo"\n%s\n%s\nEND\n' "$P" "$P" "$P" > cmt_line.sno
RC=0; n=0; red=""
for w in cmt card blank stmt inc_inc inc_line nested blank_after cmt_line; do
    timeout -k 5 20s "$SBL" -bf $w.sno < /dev/null > $w.ref 2>&1
    [ -s $w.ref ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for witness $w -- no ref to grade against"; exit 2; }
    SCRIP_SNO_STMTKW=1 timeout -k 5 20s "$SCRIP" $w.sno < /dev/null > $w.m3 2>&1
    if SCRIP_SNO_STMTKW=1 "$SCRIP" --compile -o $w.s $w.sno < /dev/null > $w.c 2>&1 && gcc $w.s -L"$LIBDIR" -lscrip_rt -lm -Wl,-rpath,"$LIBDIR" -o $w.x 2>> $w.c; then
        SCRIP_SNO_STMTKW=1 timeout -k 5 20s ./$w.x < /dev/null > $w.m4 2>&1
    else echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link failed for witness $w: $(grep -m1 . $w.c | cut -c1-160)"; exit 2; fi
    for m in m3 m4; do
        n=$((n+1))
        if cmp -s $w.$m $w.ref; then echo "  $w $m PASS"
        else echo "  $w $m FAIL (first difference: $(diff $w.$m $w.ref | grep -m2 '^[<>]' | tr '\n' ' ' | cut -c1-200))"; RC=1; red="$red $w.$m"; fi
    done
done
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: &FILE/&LINE/&LASTFILE/&LASTLINE around -INCLUDE and -LINE equal sbl -bf in $n of $n arms (9 witnesses x 2 modes)"
else echo "⛔ GATE FAIL(1) [$G]: diverged from sbl -bf:$red"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
