#!/usr/bin/env bash
# util_raku_case_table_regen.sh -- re-cut src/runtime/rk_case_table.h from the Raku oracle's own case mappings.
#   Raku's uc / lc / tc / fc (and tclc, wordcase over them) are Unicode full case mappings -- one code point can map to
#   several (ß.uc is SS, ﬀ.fc is ff, ǉ.tc is ǈ, İ.lc is i + U+0307). The table is cut from the oracle (/usr/bin/raku),
#   never typed: every code point whose .uc, .lc, .tc or .fc differs from itself, each mapping as UTF-8 (NULL where the
#   code point maps to itself), sorted by code point for bsearch, and written by util_raku_case_table_pool.py as one string pool
#   plus 32-bit offsets, so the table costs no load-time relocation. Found by the Roast test ladder's crawl (S32-str/tc.t,
#   fc.t), where the runtime's toupper/tolower answered ASCII only.
# Usage: bash ../harness/scripts/util_raku_case_table_regen.sh     (rc 2 if the oracle is absent or answers nothing)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
RAKU="${RAKU_BIN:-/usr/bin/raku}"
OUT="$ROOT/src/runtime/rk_case_table.h"
[ -x "$RAKU" ] || { echo "⛔ REFUSE rc=2 [util_raku_case_table_regen] -- no oracle at $RAKU"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
"$RAKU" -e '
sub cstr(Str $s) { $s.encode("utf8").list.map({ sprintf("\\%03o", $_) }).join }
for 0..0x10FFFF -> $c {
    next if 0xD800 <= $c <= 0xDFFF;
    my $u = $c.chr;
    my @m = $u.uc, $u.lc, $u.tc, $u.fc;
    next if @m.all eq $u;
    say "    \{ $c, " ~ @m.map({ $_ eq $u ?? "0" !! "\"" ~ cstr($_) ~ "\"" }).join(", ") ~ " },";
}' > "$T/rows.txt" 2>/dev/null
[ -s "$T/rows.txt" ] || { echo "⛔ REFUSE rc=2 [util_raku_case_table_regen] -- the oracle answered nothing"; exit 2; }
python3 "$HERE/util_raku_case_table_pool.py" < "$T/rows.txt" > "$T/table.h" || { echo "⛔ REFUSE rc=2 [util_raku_case_table_regen] -- the pool step refused"; exit 2; }
cp "$T/table.h" "$OUT"
echo "rk_case_table.h: $(wc -l < "$T/rows.txt") code points with a case mapping, cut from $("$RAKU" -v | head -1)"
