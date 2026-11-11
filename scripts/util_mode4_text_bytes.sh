#!/usr/bin/env bash
# util_mode4_text_bytes.sh <program> <outdir> -- MODE 4's assembled .text bytes, relocations and .text labels for ONE program (shared-mode-identity piece 2, CTO-489).
# SCRIP/scrip --compile writes the assembly to <outdir>/w.s; as assembles it to w.o; the .text bytes go to text.bin, the relocations to relocs.tsv
# (offset hex, type, symbol) and the .text labels to labels.tsv (offset hex, name). It never links: the question is the assembled bytes before linking.
# One line on success: M4_TEXT bytes=N relocs=R labels=L (rc 0). rc 2 names the step that failed; nothing is read from a stale build.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
refuse() { echo "REFUSE(2) [mode4_text_bytes]: $*"; exit 2; }
prog="${1:-}"; out="${2:-}"
[ -n "$prog" ] && [ -n "$out" ] || refuse "usage: $0 <program> <outdir>"
[ -x "$S4E/SCRIP/scrip" ] || refuse "no SCRIP/scrip at $S4E/SCRIP (build it: make -j8 in SCRIP)"
[ -f "$prog" ] || refuse "no program $prog"
mkdir -p "$out" || refuse "cannot make $out"
timeout -k 5 60 "$S4E/SCRIP/scrip" --compile --out="$out/w.s" "$prog" < /dev/null > "$out/compile.log" 2>&1 || refuse "scrip --compile failed (see $out/compile.log)"
[ -s "$out/w.s" ] || refuse "scrip --compile wrote no assembly"
as --64 "$out/w.s" -o "$out/w.o" > "$out/as.log" 2>&1 || refuse "as failed (see $out/as.log)"
objcopy -O binary --only-section=.text "$out/w.o" "$out/text.bin" || refuse "objcopy failed on $out/w.o"
objdump -r -j .text "$out/w.o" | awk '/^[0-9a-f]+ R_/ {print $1 "\t" $2 "\t" $3}' > "$out/relocs.tsv" || refuse "objdump failed on $out/w.o"
nm -n --defined-only "$out/w.o" | awk '$2 == "t" || $2 == "T" {print $1 "\t" $3}' > "$out/labels.tsv" || refuse "nm failed on $out/w.o"
[ -s "$out/labels.tsv" ] || refuse "no .text label in $out/w.o"
printf 'M4_TEXT bytes=%s relocs=%s labels=%s\n' "$(stat -c %s "$out/text.bin")" "$(wc -l < "$out/relocs.tsv")" "$(wc -l < "$out/labels.tsv")"
exit 0
