#!/usr/bin/env bash
# jcon_selfhost_run.sh -- compile an Icon program with SCRIP-jtran, link with SCRIP-jlink, bundle with the
# JCON Java runtime, and run it on the JVM. This is the end-to-end self-host proof: an Icon program compiled
# by the SCRIP-built JCON translator, executed on real JCON bytecode.
# Mirrors jcon-master/bin/jcont's bytecode+link+run path, substituting SCRIP-built jtran/jlink.
# The .icn input must already be semicolonized (SCRIP requires explicit ';'); pass RAW=1 to semicolonize first.
# Usage: bash ../harness/scripts/jcon_selfhost_run.sh path/to/prog.icn [args...]
#        RAW=1 bash ../harness/scripts/jcon_selfhost_run.sh newline_style.icn
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -euo pipefail

SCRIP=${SCRIP:-$S4A/work/SCRIP}
JCONREPO=${JCONREPO:-$S4A/work/jcon-master/jcon-master}
JT=${JT:-$S4A/jt}
JRTS="$JCONREPO/bin/jcon.zip"
JAVA="java -noverify"
SEMI="$SCRIP/tools/semicolonize_icon.py"

SRC=${1:?usage: jcon_selfhost_run.sh prog.icn [args...]}; shift || true
BASE=$(basename "$SRC" .icn)
MOD='l$'"$BASE"                 # canonical JCON module-class name, e.g. l$hello_t
TDIR="$JT/run_$BASE"

if [ "${RAW:-0}" = "1" ]; then python3 "$SEMI" "$SRC" "$JT/$BASE.icn"; SRC="$JT/$BASE.icn"; fi

rm -rf "$TDIR"; mkdir -p "$TDIR"

echo "== translate: SCRIP-jtran preproc:yylex:parse:ast2ir:bc_File -> .class =="
SCRIP_BETA_ELIDE_OFF=1 "$JT/jtran" preproc "$SRC" : yylex : parse : ast2ir : \
    bc_File -O -class:"$MOD" -dir:"$TDIR/" </dev/null
ls "$TDIR"/*.class >/dev/null 2>&1 || { echo "FAIL: no .class produced"; exit 1; }

echo "== bundle module classes -> $BASE.zip (jcon.ZipMerge) =="
( cd "$TDIR" && $JAVA -cp "$JRTS" jcon.ZipMerge "$JT/$BASE.zip" links *.class )

echo "== link: SCRIP-jlink $BASE $MOD -> $BASE.class =="
rm -f "$TDIR"/*.class
( cd "$TDIR" && "$JT/jlink" "$BASE" "$MOD" )
[ -f "$TDIR/$BASE.class" ] || { echo "FAIL: jlink produced no $BASE.class"; exit 1; }

echo "== manifest + combined.zip (FindFiles + ZipMerge) =="
mkdir -p "$TDIR/META-INF"
printf 'Manifest-Version: 1.0\nMain-Class: %s\nCreated-By: SCRIP-selfhost\n' "$BASE" >"$TDIR/META-INF/MANIFEST.MF"
$JAVA -cp "$JRTS" jcon.FindFiles "" "$JT/$BASE.zip" >"$TDIR/zip.list"
( cd "$TDIR" && $JAVA -cp "$JRTS" jcon.ZipMerge combined.zip META-INF/MANIFEST.MF "$BASE.class" $(cat zip.list) )

echo "== run: java -cp combined.zip:jcon.zip $BASE =="
echo "---- program output ----"
$JAVA -cp "$TDIR/combined.zip:$JRTS" "$BASE" "$@"
echo "---- end output ----"
