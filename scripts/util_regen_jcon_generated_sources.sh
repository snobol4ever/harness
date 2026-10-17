#!/usr/bin/env bash
# util_regen_jcon_generated_sources.sh -- regenerate JCON's two GENERATED modules, do_ops.icn and interface.icn.
#
# ⛔ THIS IS NOT PART OF THE HANDOFF SEQUENCE. RULES.md § Handoff sequence names exactly THREE regen
# scripts and this is not one of them. Run it only when the JCON package's generator sources
# (oplexgen.icn / interfacegen.icn) change upstream -- which is approximately never.
#
# WHY THE TWO FILES EXIST AT ALL. JCON's tran/Makefile builds `jtran` from SEVENTEEN modules, two of
# which are programs' output, not hand-written source:
#     do_ops.icn:    oplexgen     ;  ./oplexgen > do_ops.icn
#     interface.icn: interfacegen ;  ./interfacegen > interface.icn
# ⭐ The corpus carried the 16 hand-written modules and BOTH GENERATORS, but neither generated file
# (measured 2026-09-03, hq_B). The consequence was quiet and expensive: a `jtran` linked from the 15
# modules the package README listed builds and runs, so nothing looked wrong -- but `lexer.icn` calls
# into do_ops at its very first token, so every pipeline past `preproc` died at lexer.icn:14 with
# "procedure or integer expected, offending value: &null". The missing file presented as a lexer bug.
#
# ⛔ THE ORACLE GENERATES, SCRIP DOES NOT -- ON PURPOSE. These two files are INPUTS to the demo that
# grades SCRIP. Generating them with SCRIP would let a SCRIP defect author its own oracle input, and
# the JCON demo would then be grading SCRIP against itself. (It is also not hypothetical: SCRIP's own
# oplexgen emits the same 611 lines in a different key(table) order -- see corpus/demos/icon/jcon/
# oplexgen.knowndiff. Regenerating with SCRIP would silently re-order do_ops.icn.)
#
# ⭐ SEMICOLONS: SCRIP's Icon front end requires explicit `;` and does zero newline processing, while
# the generators emit newline-style Icon. So each generated file goes through the shared
# tools/semicolonize_icon.py -- the same one-time transform the rest of the package had applied -- and
# this script VERIFIES the transform added semicolons and nothing else, by stripping trailing `;` back
# off and requiring a byte-exact match against the generator's own output.
#
# EXIT: 0 = both files regenerated and verified.  2 = REFUSED (oracle missing, generator failed,
#       semicolonizer missing, or the strip-back verification failed -- never a silent half-write).
# USAGE: bash ../harness/scripts/util_regen_jcon_generated_sources.sh [--check]     (--check: verify, do not write)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
PKG="${JCON_PKG_DIR:-$S4E/corpus/packages/icon/jcon-compiler}"
SEMI="$ROOT/tools/semicolonize_icon.py"
CHECK=0; [ "${1:-}" = "--check" ] && CHECK=1

refuse() { echo "⛔ JCON GENERATED-SOURCE REGEN REFUSED(2): $*" >&2; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "cannot load lib_oracle_flags.sh -- the ONE oracle-path authority."
ICONT="$(icont_bin)" || refuse "the Arizona icont oracle is missing. ⛔ Not a \`command -v\` verdict -- the oracles are not on PATH."
[ -d "$PKG" ] || refuse "JCON package missing: $PKG"
[ -f "$SEMI" ] || refuse "tools/semicolonize_icon.py missing -- it is the ONE shared semicolon transform; do not hand-roll another."

W="$(mktemp -d "${TMPDIR:-/tmp}/jcongen.XXXXXX")" || refuse "cannot make a work dir."
trap 'rm -rf "$W"' EXIT
RC=0
regen() {                              # $1=generator stem  $2=output stem
    local gen="$1" out="$2"
    [ -f "$PKG/$gen.icn" ] || { echo "⛔ $gen.icn absent from $PKG -- cannot generate $out.icn."; RC=2; return; }
    cp "$PKG/$gen.icn" "$W/" || { RC=2; return; }
    ( cd "$W" && "$ICONT" -o "$gen" "$gen.icn" ) >"$W/$gen.log" 2>&1 || { echo "⛔ icont could not build $gen (see $W/$gen.log)."; RC=2; return; }
    ( cd "$W" && "./$gen" ) > "$W/$out.raw" 2>"$W/$out.err" || { echo "⛔ $gen ran but exited non-zero; $out.icn NOT written."; RC=2; return; }
    [ -s "$W/$out.raw" ] || { echo "⛔ $gen produced an EMPTY $out.icn -- refusing to write it."; RC=2; return; }
    python3 "$SEMI" "$W/$out.raw" > "$W/$out.semi" 2>"$W/$out.semierr" || { echo "⛔ semicolonize_icon.py failed on $out (see $W/$out.semierr)."; RC=2; return; }
    # ⛔ THE VERIFICATION IS THE POINT: strip trailing ';' back off and require byte equality with the
    # generator's own output. A transform that changed anything else fails HERE, not in a demo diff.
    if ! cmp -s <(sed 's/;[[:space:]]*$//' "$W/$out.semi") <(sed 's/;[[:space:]]*$//' "$W/$out.raw"); then
        echo "⛔ $out: semicolonize changed more than trailing semicolons -- REFUSING to write. Diff the two in $W."; RC=2; return; fi
    { printf '#GEN: produced by JCON'"'"'s own %s.icn, then run through SCRIP'"'"'s\n' "$gen"
      printf '#     tools/semicolonize_icon.py (semicolons only -- verified: stripping trailing ";" restores the\n'
      printf '#     generator'"'"'s byte-exact output, and icont -c gives the same verdict before and after).\n'
      printf '#     Regenerate, do not hand-edit: see ../harness/scripts/util_regen_jcon_generated_sources.sh.\n'
      cat "$W/$out.semi"; } > "$W/$out.final"
    if [ "$CHECK" = 1 ]; then
        if cmp -s "$W/$out.final" "$PKG/$out.icn"; then echo "✅ $out.icn is current."
        else echo "⛔ $out.icn DIFFERS from what its generator produces now."; RC=1; fi
    else
        cp "$W/$out.final" "$PKG/$out.icn" && echo "✅ wrote $PKG/$out.icn ($(wc -l < "$PKG/$out.icn") lines)"
    fi
}
regen oplexgen     do_ops
regen interfacegen interface
[ "$RC" = 0 ] && echo "✅ JCON generated sources are current (oracle: $ICONT)." || echo "⛔ see above -- rc=$RC"
exit $RC
