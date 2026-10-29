#!/usr/bin/env bash
# test_demo_icon_jcon_selfhost.sh -- THE JCON SELF-HOST GATE: SCRIP-built jtran compiles JCON's own sources, and every
# class file it writes is byte-identical to what an Arizona-icont-built jtran writes from the same sources.
#
# WHAT IS COMPARED. jtran (JCON's 17-module Icon-to-JVM translator, corpus/packages/icon/jcon-compiler) is built twice
# from the SAME sources on every run: once by Arizona icont (the oracle, Lon 2026-09-23: "Use Arizona Icon"), once by
# SCRIP in mode 4 from the demo's own link manifest (corpus/demos/icon/jcon/jtran.icn). Each is then run over EVERY module
# of the package through the pipeline JCON's own jcont script uses for a bytecode build:
#     preproc M.icn : yylex : parse : ast2ir : optim -O : bc_File -class:lM -dir:DIR/
# and the two output directories are compared file by file, byte for byte. ⛔ NO JVM IS INSTALLED OR RUN, EVER (s121,
# and Lon 2026-09-23: "Worry not about actually running Java Virtual Machine"): a class file is compared as DATA.
#
# ⭐ THE SCRIP-BUILT jtran RUNS AT jtran's DECLARED HEAP AND STACK (ceo CEO-1353, RULES.md clause 8 (g)(4); the coo's census): the words
# declared_switches_beside reads from corpus/demos/icon/jcon/jtran.heap and jtran.stack lead the binary's argv before a --. ⛔ THE
# --heap=window ARM IS RETIRED: it exported SCRIP_HEAP_MB=2048, the collector's WINDOW, so no collection ran over the package and a
# difference could only be an Icon-semantics one (553 of 553 at SCRIP 27650ec66, 2026-09-23). A runner types no size of its own, so
# the one run is the declared one, the collector running as shipped; a difference that is a collector defect is bracketed as one
# (measured 2026-09-23 under the old default arm: irgen.icn exhausted a 4 MB cap after 281 collections, and at 16 MB read a stale
# table pointer in table_icn_nth resuming `every op := !!!t` inside bc_File's co-expression).
# The oracle runs in the environment jtran declares beside itself (jtran.oracle_env: jcont's own COEXPSIZE=1000000 -- every pipeline
# stage is a co-expression, and at iconx's default 18 of the 20 modules die run-time error 302, measured 2026-09-28), every other
# iconx size knob unset.
#
# EXIT: 0 every module's class files byte-identical and every exit status equal; 1 a difference (named per module);
#       2 REFUSED -- could not build or could not measure. A gate that cannot measure never reports green.
# USAGE: bash ../harness/scripts/test_demo_icon_jcon_selfhost.sh [module ...]   (default: every module)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="$ROOT/out"
D="${JCON_DEMO_DIR:-$S4E/corpus/demos/icon/jcon}"
PKG="${JCON_PKG_DIR:-$S4E/corpus/packages/icon/jcon-compiler}"
TMO="${JCON_TIMEOUT:-900}"
WANT=""
for a in "$@"; do case "$a" in --heap=*) echo "⛔ REFUSE(2): $a is retired -- jtran runs at its declared heap and stack (jtran.heap, jtran.stack; CEO-1353)"; exit 2;; *) WANT="$WANT $a";; esac; done
refuse() { echo "⛔ JCON SELF-HOST GATE UNPROVEN(2): $*"; echo "    This is NOT a pass -- the gate could not measure, so it certifies nothing."; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "cannot load lib_oracle_flags.sh -- the ONE oracle-path authority."
ICONT="$(icont_bin)" || refuse "the Arizona icont oracle is missing (lib_oracle_flags.sh names the path)."
[ -x "$SCRIP" ] || refuse "scrip is not built at $SCRIP -- run make."
[ -f "$D/jtran.icn" ] || refuse "the jtran link manifest is missing: $D/jtran.icn"
[ -d "$PKG" ] || refuse "JCON package missing: $PKG"
W="$(mktemp -d "${TMPDIR:-/tmp}/jconself.XXXXXX")" || refuse "cannot make a work dir."
trap 'rm -rf "$W"' EXIT
MODS=$(sed -n 's/^[[:space:]]*link[[:space:]]*"\([^"]*\)".*$/\1/p' "$D/jtran.icn" | sed 's|.*/||')
[ -n "$MODS" ] || refuse "jtran.icn names no modules."
mkdir -p "$W/src" && cp "$PKG"/*.icn "$W/src/" || refuse "cannot stage the package sources."
for m in $MODS; do [ -f "$W/src/$m.icn" ] || refuse "jtran links $m but $PKG/$m.icn does not exist."; done
( cd "$W/src" && "$ICONT" -s -o "$W/jtran_oracle" $(for m in $MODS; do printf '%s.icn ' "$m"; done) ) >"$W/icont.log" 2>&1 \
    || refuse "icont refused to build the oracle jtran: $(tail -2 "$W/icont.log")"
( cd "$D" && "$SCRIP" --compile --out="$W/jtran.s" jtran.icn </dev/null ) >"$W/scrip.log" 2>&1 \
    || refuse "SCRIP could not compile jtran (rc=$?): $(grep -v '^$' "$W/scrip.log" | tail -1 | cut -c1-200)"
as --64 -o "$W/jtran.o" "$W/jtran.s" 2>>"$W/scrip.log" && gcc -no-pie -o "$W/jtran_scrip" "$W/jtran.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>>"$W/scrip.log" \
    || refuse "SCRIP-built jtran did not assemble or link: $(tail -2 "$W/scrip.log")"
. "$HERE/lib_declared_arena.sh" 2>/dev/null || refuse "cannot load lib_declared_arena.sh -- the ONE declared-size reader."
SW="$(declared_switches_beside "$D/jtran.icn")" || refuse "jtran.heap or jtran.stack is malformed (the reader said why above)."
[ -n "$SW" ] || refuse "jtran declares no heap and stack beside it ($D/jtran.heap, jtran.stack) -- a run at the default is not a declared run."
declare -a SWA=(); read -r -a SWA <<<"$SW"
# ⭐ THE ORACLE'S ENVIRONMENT IS DECLARED BESIDE jtran TOO (clause 8 (g)(3)): jtran.oracle_env, read by declared_oracle_env_beside.
OE="$(declared_oracle_env_beside "$D/jtran.icn")" || refuse "jtran.oracle_env is malformed (the reader said why above)."
[ -n "$OE" ] || refuse "jtran declares no oracle environment beside it ($D/jtran.oracle_env) -- the Arizona jtran dies on most modules at iconx's default co-expression size."
declare -a OENV=(); read -r -a OENV <<<"$OE"
printf '%-14s %-18s %-18s %s\n' MODULE ORACLE SCRIP VERDICT
printf '%s\n' "------------------------------------------------------------------------------"
TOT=0; SAME=0; BAD=0; ROWS=0
for f in "$W"/src/*.icn; do
    m="$(basename "$f" .icn)"
    [ -n "$WANT" ] && ! grep -qw "$m" <<<"$WANT" && continue
    ROWS=$((ROWS+1)); mkdir -p "$W/o/$m" "$W/s/$m"
    ( cd "$W/src" && env -u HEAPSIZE -u BLOCKSIZE -u BLKSIZE -u STRSIZE -u MSTKSIZE -u QLSIZE -u COEXPSIZE "${OENV[@]}" timeout -k 5 "$TMO" "$W/jtran_oracle" \
        preproc "$m.icn" : yylex : parse : ast2ir : optim -O : bc_File -class:"l$m" -dir:"$W/o/$m/" ) >/dev/null 2>"$W/o/$m.err"; orc=$?
    ( cd "$W/src" && timeout -k 5 "$TMO" "$W/jtran_scrip" "${SWA[@]}" -- \
        preproc "$m.icn" : yylex : parse : ast2ir : optim -O : bc_File -class:"l$m" -dir:"$W/s/$m/" ) >/dev/null 2>"$W/s/$m.err"; src=$?
    no=$(ls "$W/o/$m" | wc -l); ns=$(ls "$W/s/$m" | wc -l); same=0
    for c in "$W/o/$m"/*; do [ -e "$c" ] || continue; TOT=$((TOT+1)); cmp -s "$c" "$W/s/$m/$(basename "$c")" && { same=$((same+1)); SAME=$((SAME+1)); }; done
    extra=$(comm -13 <(ls "$W/o/$m") <(ls "$W/s/$m") | wc -l)
    if [ "$no" -eq 0 ]; then V="VOID -- the oracle wrote no class file (rc=$orc: $(head -c 120 "$W/o/$m.err"))"; BAD=1
    elif [ "$orc" = "$src" ] && [ "$same" -eq "$no" ] && [ "$extra" -eq 0 ]; then V="IDENTICAL"
    else V="DIFF $same/$no identical, $extra extra, rc $orc vs $src$( [ "$src" -ge 128 ] 2>/dev/null && printf ' -- %s' "$(grep -m1 -o '\[Z[A-Z-]*\][^.]*' "$W/s/$m.err" | cut -c1-110)")"; BAD=1; fi
    printf '%-14s %-18s %-18s %s\n' "$m" "rc=$orc files=$no" "rc=$src files=$ns" "$V"
done
printf '%s\n' "------------------------------------------------------------------------------"
[ "$ROWS" -gt 0 ] || refuse "no module matched -- a gate that graded nothing is not a pass."
echo "JCON_SELFHOST sizes=[$SW] modules=$ROWS class_files_identical=$SAME of $TOT oracle=$ICONT scrip=$SCRIP RT_OPT=-O0"
if [ "$BAD" = 0 ]; then echo "✅ JCON SELF-HOST PASS(0): SCRIP-built jtran wrote every class file byte-identical to the Arizona-built jtran."; exit 0; fi
echo "⛔ JCON SELF-HOST FAIL(1): at least one module differs (rows above)."; exit 1
