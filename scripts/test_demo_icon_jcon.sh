#!/usr/bin/env bash
# test_demo_icon_jcon.sh -- THE JCON DEMO GATE. Grades the JCON compiler (Icon-in-Icon) as a SCRIP demo.
#
# WHAT JCON IS: Proebsting & Townsend's Icon-to-JVM compiler, written in Icon (corpus/packages/icon/
# jcon-compiler, 9953 lines + 2 generated modules). It is the largest real-world Icon program in the
# corpus, so it is the demo that answers "does SCRIP's Icon front end carry a whole compiler".
#
# ⭐ THE DEMO ENTRIES LINK, THEY DO NOT CONCATENATE. Each corpus/demos/icon/jcon/<name>.icn is a thin
# entry file of `link "<relpath>"` lines, resolved by SCRIP's own icn_resolve_links (src/parsers/icon/
# icon_driver.c:26, 64-file ceiling). This is deliberate: the previous way to build jtran was to hand
# all 18 package files to one command line, which silently merged FOUR `procedure main`s (jtran_main,
# linker, oplexgen, interfacegen) into one program. The link entries name exactly the modules each
# real JCON program is built from, per JCON's own tran/Makefile.
#
# ⛔ THE ORACLE IS BUILT HERE, FROM THE SAME SOURCES, EVERY RUN -- never a checked-in .ref. icont
# links the same module list from the same package dir, so an oracle/SCRIP difference is a SCRIP
# difference and cannot be a source-drift artifact.
#
# ⛔ REFUSES (rc=2) RATHER THAN SKIPPING. A missing icont, an unbuilt scrip, a missing package module
# or a demo entry that will not compile is UNPROVEN, never a pass: a gate that cannot measure must not
# report green (RULES.md; and the `make test` false-green trap this suite exists downstream of).
#
# ⛔ KNOWN-DIFF IS DECLARED IN THE TREE, NOT IN THIS SCRIPT. A demo whose output legitimately does not
# yet match carries <name>.knowndiff beside it, whose first line names the class. Such a row is
# reported KNOWN-DIFF and does not fail the gate -- but a KNOWN-DIFF row that starts MATCHING is
# reported XPASS and DOES fail, so a cure can never land silently and leave a stale marker behind.
#
# EXIT: 0 = every demo matched (or is a declared KNOWN-DIFF still differing).
#       1 = a regression: a demo that should match did not, or a KNOWN-DIFF started passing (XPASS).
#       2 = REFUSED/UNPROVEN: could not build or could not measure.
# USAGE: bash ../harness/scripts/test_demo_icon_jcon.sh [name ...]      (default: every entry in the demo dir)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="$ROOT/out"
D="${JCON_DEMO_DIR:-$S4E/corpus/demos/icon/jcon}"
PKG="${JCON_PKG_DIR:-$S4E/corpus/packages/icon/jcon-compiler}"
TMO="${JCON_TIMEOUT:-600}"

refuse() { echo "⛔ JCON DEMO GATE UNPROVEN(2): $*"; echo "    This is NOT a pass -- the gate could not measure, so it certifies nothing."; exit 2; }

. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "cannot load lib_oracle_flags.sh -- the ONE oracle-path authority."
# ⛔ ARGV COMES FROM THE ONE SHARED READER (lib_icon_ipl_isolation.sh:ipl_argv_read, the NAME.argv sidecar). This gate read a
# NAME.args file until 2026-09-23; hq_V converted jtran.args to jtran.argv on 09-12 (CEO-609) and this reader was not moved,
# so jtran was graded with NO arguments for eleven days -- oracle and SCRIP both printed a usage failure and the row said DIFF.
. "$HERE/lib_icon_ipl_isolation.sh" 2>/dev/null || refuse "cannot load lib_icon_ipl_isolation.sh -- the ONE argv-sidecar reader."
. "$HERE/lib_declared_arena.sh" 2>/dev/null || refuse "cannot load lib_declared_arena.sh -- the ONE declared-size reader."
ICONT="$(icont_bin)" || refuse "the Arizona icont oracle is missing (lib_oracle_flags.sh names the path). ⛔ Do NOT conclude this from \`command -v icont\` -- the oracles are not on PATH."
[ -x "$SCRIP" ] || refuse "scrip is not built at $SCRIP -- run make."
[ -d "$D" ]     || refuse "demo dir missing: $D"
[ -d "$PKG" ]   || refuse "JCON package missing: $PKG"

W="$(mktemp -d "${TMPDIR:-/tmp}/jcondemo.XXXXXX")" || refuse "cannot make a work dir."
# ⭐ demo INPUTS live in corpus/demos/icon/jcon/inputs/ and are staged into the oracle's work dir, so a
# <name>.args line naming inputs/foo.icn resolves identically on all three arms. They are kept OUT of the
# demo dir itself because this gate treats every *.icn there as an ENTRY -- an input file sitting beside
# the entries is picked up as a demo that links no modules (measured, first cut of this gate).
[ -d "$D/inputs" ] && cp -r "$D/inputs" "$W/" 2>/dev/null
trap 'rm -rf "$W"' EXIT

# ---- the modules an entry links, read from the entry itself (the entry IS the manifest) -------
entry_modules() { sed -n 's/^[[:space:]]*link[[:space:]]*"\([^"]*\)".*$/\1/p' "$1" | sed 's|.*/||'; }

WANT="$*"; ROWS=0; BAD=0
printf '%-14s %-8s %-7s %-10s %-10s %s\n' DEMO ORACLE STREAM m3 m4 VERDICT
printf '%s\n' "---------------------------------------------------------------------------"

for E in "$D"/*.icn; do
    [ -f "$E" ] || continue
    N="$(basename "$E" .icn)"
    [ -n "$WANT" ] && ! grep -qw "$N" <<<"$WANT" && continue
    ROWS=$((ROWS+1))
    declare -a ARGV=(); ipl_argv_read "$E" ARGV; arc=$?
    [ "$arc" -eq 2 ] && { echo "⛔ $N: $N.argv is malformed (the reader said why, above) -- FAIL, never run on a guessed argv."; BAD=1; continue; }
    IN=/dev/null; [ -f "$D/$N.stdin" ] && IN="$D/$N.stdin"
    # ⭐ THE DEMO'S DECLARED HEAP AND STACK RIDE BOTH SCRIP COMMAND LINES (ceo CEO-1353, clause 8 (g)(4)): -d<kb>k -s<kb>k from NAME.heap
    # and NAME.stack, after scrip in m3 and leading the binary's argv (before its --) in m4; a demo with none is NAMED, never silent.
    SW="$(declared_switches_beside "$E")" || { echo "⛔ $N: $N.heap or $N.stack is malformed (the reader said why, above) -- FAIL, never run at a guessed size."; BAD=1; continue; }
    declare -a SWA=(); if [ -n "$SW" ]; then read -r -a SWA <<<"$SW"; else echo "    $N: declares no heap and stack beside it -- runs at the shipped default, NAMED (clause 8 (g)(1))"; fi

    # ---- oracle: icont over exactly the modules this entry links ------------------------------
    MODS=""; for m in $(entry_modules "$E"); do
        [ -f "$PKG/$m.icn" ] || { echo "⛔ $N: entry links '$m' but $PKG/$m.icn does not exist."; BAD=1; continue 2; }
        cp "$PKG/$m.icn" "$W/" || refuse "cannot stage $m.icn"; MODS="$MODS $m.icn"; done
    [ -n "$MODS" ] || { echo "⛔ $N: entry links no modules -- nothing to grade."; BAD=1; continue; }
    ( cd "$W" && "$ICONT" -o "$N.oracle" $MODS ) >"$W/$N.icont.log" 2>&1 \
        || { echo "⛔ $N: icont REFUSED to build the oracle (see $W/$N.icont.log) -- UNPROVEN, not a pass."; BAD=1; continue; }
    # ⭐ THE ANSWER IS WHICHEVER STREAM THE PROGRAM ACTUALLY USED. Most demos answer on stdout, but
    # jlink's whole output is a diagnostic on stderr -- comparing stdout only would score it
    # VOID-EMPTY-ORACLE (measured, first cut of this gate) and read as a defect where there is none.
    # The oracle decides the stream once, and all three arms are then compared on that same stream.
    o_out="$(cd "$W" && timeout -k 5 "$TMO" "./$N.oracle" ${ARGV[@]+"${ARGV[@]}"} <"$IN" 2>"$W/$N.oracle.err")"; o_rc=$?
    STREAM=stdout
    if [ -z "$o_out" ] && [ -s "$W/$N.oracle.err" ]; then STREAM=stderr; o_out="$(cat "$W/$N.oracle.err")"; fi

    # ---- SCRIP mode 3 (default --run) ---------------------------------------------------------
    # ⛔ mode 3 needs `--` before PROGRAM args, or the driver reads them as its own flags -- and an
    # unrecognised flag is not diagnosed, it is treated as a FILENAME (scrip: cannot open '...').
    declare -a M3ARGS=(); [ "${#ARGV[@]}" -gt 0 ] && M3ARGS=(-- "${ARGV[@]}")
    if [ "$STREAM" = stderr ]; then m3_out="$(cd "$D" && timeout -k 5 "$TMO" "$SCRIP" ${SWA[@]+"${SWA[@]}"} "$E" ${M3ARGS[@]+"${M3ARGS[@]}"} <"$IN" 2>&1 >/dev/null)"
    else m3_out="$(cd "$D" && timeout -k 5 "$TMO" "$SCRIP" ${SWA[@]+"${SWA[@]}"} "$E" ${M3ARGS[@]+"${M3ARGS[@]}"} <"$IN" 2>"$W/$N.m3.err")"; fi; m3_rc=$?

    # ---- SCRIP mode 4 (--compile -> as -> ld -> run) ------------------------------------------
    m4_out=""; m4_rc=""
    if ( cd "$D" && "$SCRIP" --compile --out="$W/$N.s" "$E" </dev/null ) >"$W/$N.m4c.log" 2>&1 \
       && as --64 -o "$W/$N.o" "$W/$N.s" 2>>"$W/$N.m4c.log" \
       && gcc -no-pie -o "$W/$N.m4bin" "$W/$N.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>>"$W/$N.m4c.log"; then
        if [ "$STREAM" = stderr ]; then m4_out="$(cd "$D" && timeout -k 5 "$TMO" "$W/$N.m4bin" ${SWA[@]+"${SWA[@]}"} ${M3ARGS[@]+"${M3ARGS[@]}"} <"$IN" 2>&1 >/dev/null)"
        else m4_out="$(cd "$D" && timeout -k 5 "$TMO" "$W/$N.m4bin" ${SWA[@]+"${SWA[@]}"} ${M3ARGS[@]+"${M3ARGS[@]}"} <"$IN" 2>/dev/null)"; fi; m4_rc=$?
    else m4_rc="BUILD-ERR"; fi

    # ---- verdict: the ANSWER is the signal ----------------------------------------------------
    KD=""; [ -f "$D/$N.knowndiff" ] && KD="$(head -1 "$D/$N.knowndiff")"
    s3=DIFF; [ "$m3_out" = "$o_out" ] && s3=match
    s4=DIFF; [ "$m4_out" = "$o_out" ] && s4=match
    # ⛔ ORDER MATTERS: an empty oracle voids the row, but a SCRIP build failure is the more
    # informative fact and must not be overwritten by the void (measured -- the first cut printed
    # VOID-EMPTY-ORACLE over jtran's real BUILD-ERR and hid the actual blocker).
    [ -z "$o_out" ] && { s3="VOID-EMPTY-ORACLE"; s4="VOID-EMPTY-ORACLE"; }
    [ "$m3_rc" = "BUILD-ERR" ] && s3=BUILD-ERR
    [ "$m4_rc" = "BUILD-ERR" ] && s4=BUILD-ERR

    if [ "$s3" = match ] && [ "$s4" = match ]; then
        if [ -n "$KD" ]; then V="XPASS -- cure landed, retire $N.knowndiff"; BAD=1
        else V="PASS"; fi
    elif [ -n "$KD" ]; then V="KNOWN-DIFF: $KD"
    else V="FAIL"; BAD=1; fi

    printf '%-14s %-8s %-7s %-10s %-10s %s\n' "$N" "rc=$o_rc" "$STREAM" "$s3" "$s4" "$V"
    # ⭐ EXIT STATUS IS REPORTED, NEVER THE GATE (same posture as bench_triangulate_demos_snobol4.sh:
    # the ANSWER is the correctness signal). But a silent rc divergence is a real defect hiding behind
    # a matching stdout -- jlink matches byte-for-byte on all three arms while SCRIP exits 0 where the
    # oracle exits 1 -- so it is NAMED here rather than dropped.
    { [ "$m3_rc" != "$o_rc" ] || [ "$m4_rc" != "$o_rc" ]; } && [ "$s3" != BUILD-ERR ] && [ "$s4" != BUILD-ERR ] \
        && echo "    ⚠ $N: exit status diverges (oracle=$o_rc m3=$m3_rc m4=$m4_rc) -- reported, not gated."
done

printf '%s\n' "---------------------------------------------------------------------------"
echo "demos graded: $ROWS   oracle: $ICONT   scrip: $SCRIP   RT_OPT=-O0"
[ "$ROWS" -gt 0 ] || refuse "no demo entries matched -- a gate that graded nothing is not a pass."
if [ "$BAD" = 0 ]; then echo "✅ JCON DEMO GATE PASS(0): every graded demo matches the icont/iconx oracle (or is a declared, still-differing KNOWN-DIFF)."; exit 0; fi
echo "⛔ JCON DEMO GATE FAIL(1): at least one demo regressed, XPASSed, or could not be built. Rows above are the evidence."; exit 1
