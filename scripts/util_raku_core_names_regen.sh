#!/usr/bin/env bash
# util_raku_core_names_regen.sh -- re-cut src/parsers/raku/rk_core_names.h from the Raku oracle's own CORE setting.
#   The hand-written syntax checker (src/parsers/raku/rk_syntax.c, row raku-a-new-hand-written-lexer-and-parser-...,
#   Lon 2026-09-26, CEO-1289) needs Rakudo's is_name / is_type answers to parse the way Rakudo does: `my Foo $x`,
#   `sub f(Foo $x)`, `Foo[...]` and `is Foo` all turn on whether Foo names a type. Those answers come from the CORE
#   setting, so the table is cut from the oracle (/usr/bin/raku), never typed: every non-sigiled CORE:: symbol two
#   package levels deep (four under X::, where roast names deep exception types; enum values included, enum stashes
#   not recursed), every CORE routine (&-sigiled) name, the names and routines a `use v6.e.PREVIEW` program's CORE
#   adds (rk_core_e_*, each led by "" so no table is empty), the Unicode name of every character and every
#   name alias Rakudo resolves (rk_uninames, sorted, for \c[NAME] in a string or an operator's name; the algorithmic
#   ideograph families NAME-HEX are decoded in code, not listed) and every named sequence (rk_uniseqs, name -> code
#   points), and every routine `use Test` imports (the
#   undeclared-routine check resolves a bare call against them, as Rakudo's explain_mystery does). The whole word
#   Term is written \124erm (octal T): the
#   Term word-ref ratchet (test_gate_term_wordref_ratchet.sh) counts Prolog's Term representation, and Rakudo's
#   X::Syntax::Term exception names are not that.
# Usage: bash ../harness/scripts/util_raku_core_names_regen.sh     (rc 2 if the oracle is absent or answers nothing)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
RAKU="${RAKU_BIN:-/usr/bin/raku}"
OUT="$ROOT/src/parsers/raku/rk_core_names.h"
[ -x "$RAKU" ] || { echo "⛔ REFUSE rc=2 [util_raku_core_names_regen] -- no oracle at $RAKU"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/names.raku" <<'EOF'
my %seen;
sub walk($stash, $prefix, $depth) {
    for $stash.keys.sort -> $k {
        next if $k ~~ /^<[$@%&!]>/;
        next if $k eq any(<EXPORT EXPORTHOW GLOBALish UNIT SETTING OUTER CALLER DYNAMIC CLIENT LEXICAL OUR MY PROCESS COMPILING SELF CORE>);
        my $name = $prefix ?? "$prefix\::$k" !! $k;
        next if %seen{$name}++;
        say $name;
        next if $depth >= ($name.starts-with('X::') ?? 4 !! 2);
        my $v; try { $v := $stash{$k} };
        next unless $v.DEFINITE.not;
        my $who; try { $who := $v.WHO };
        next unless $who ~~ Stash;
        my @kids = try { $who.keys.grep(* !~~ /^<[$@%&!]>/) };
        next if @kids.elems == 0;
        next if try { $v.^enum_values };
        walk($who, $name, $depth + 1);
    }
}
walk(CORE::, '', 0);
EOF
"$RAKU" "$T/names.raku" 2>/dev/null | LC_ALL=C sort -u > "$T/names.txt"
"$RAKU" -e 'say $_ for CORE::.keys.grep(/^"&"/).map(*.substr(1))' 2>/dev/null | LC_ALL=C sort -u > "$T/routines.txt"
"$RAKU" -e 'use Test; say $_ for MY::.keys.grep(/^"&"/).map(*.substr(1))' 2>/dev/null | LC_ALL=C sort -u > "$T/test.txt"
"$RAKU" -e 'for 0x1..0x10FFFF -> $c { next if 0xD800 <= $c <= 0xDFFF; my $n = $c.uniname; next if $n.starts-with("<"); next if $n ~~ /^["CJK UNIFIED IDEOGRAPH" | "CJK COMPATIBILITY IDEOGRAPH" | "TANGUT IDEOGRAPH" | "KHITAN SMALL SCRIPT CHARACTER" | "NUSHU CHARACTER"] "-" <xdigit>+ $/; say "$n\t$c" }' 2>/dev/null | LC_ALL=C sort -t "$(printf '\t')" -k1,1 -u > "$T/uninames_real.txt"
# aliases and named sequences, each resolved by Rakudo's own uniparse (a real name wins over an alias, as in Rakudo)
{ grep -v '^#' /usr/share/unicode/NameAliases.txt 2>/dev/null | cut -d';' -f2; grep -v '^#' /usr/share/unicode/NamedSequences.txt 2>/dev/null | cut -d';' -f1; } | grep -v '^\s*$' | LC_ALL=C sort -u > "$T/aliases_in.txt"
"$RAKU" -e 'for $*IN.lines -> $n { my $r = try $n.uniparse; next unless $r.defined; say "$n\t" ~ $r.ords.join(",") }' < "$T/aliases_in.txt" 2>/dev/null > "$T/aliases.txt"
cut -f1 "$T/uninames_real.txt" > "$T/real_keys.txt"
awk -F'\t' 'NR==FNR { real[$1]=1; next } !($1 in real) && $2 !~ /,/' "$T/real_keys.txt" "$T/aliases.txt" | cat "$T/uninames_real.txt" - | LC_ALL=C sort -t "$(printf '\t')" -k1,1 -u > "$T/uninames.txt"
awk -F'\t' 'NR==FNR { real[$1]=1; next } !($1 in real) && $2 ~ /,/' "$T/real_keys.txt" "$T/aliases.txt" | LC_ALL=C sort -t "$(printf '\t')" -k1,1 -u > "$T/uniseqs.txt"
{ echo 'use v6.e.PREVIEW;'; cat "$T/names.raku"; } > "$T/names_e.raku"
"$RAKU" "$T/names_e.raku" 2>/dev/null | LC_ALL=C sort -u | LC_ALL=C comm -23 - "$T/names.txt" > "$T/names_e.txt"
"$RAKU" -e 'use v6.e.PREVIEW; say $_ for CORE::.keys.grep(/^"&"/).map(*.substr(1))' 2>/dev/null | LC_ALL=C sort -u | LC_ALL=C comm -23 - "$T/routines.txt" > "$T/routines_e.txt"
[ -s "$T/names.txt" ] && [ -s "$T/routines.txt" ] && [ -s "$T/test.txt" ] && [ -s "$T/uninames.txt" ] || { echo "⛔ REFUSE rc=2 [util_raku_core_names_regen] -- the oracle answered nothing"; exit 2; }
pool_rows() { LC_ALL=C awk -v k="$1" '{ print k "\t" length($0) }' "$2" > "$T/pool.len"; sed 's/\\/\\\\/g; s/"/\\"/g; s/\bTerm\b/\\124erm/g' "$2" | paste "$T/pool.len" -; }
echo "" > "$T/empty.txt"
cut -f1 "$T/uninames.txt" > "$T/uni_n.txt"; cut -f2 "$T/uninames.txt" > "$T/uni_cp.txt"
cat "$T/empty.txt" > "$T/seq_n.txt"; cut -f1 "$T/uniseqs.txt" >> "$T/seq_n.txt"; cat "$T/empty.txt" > "$T/seq_c.txt"; cut -f2 "$T/uniseqs.txt" >> "$T/seq_c.txt"
cat "$T/empty.txt" "$T/names_e.txt" > "$T/en.txt"; cat "$T/empty.txt" "$T/routines_e.txt" > "$T/er.txt"
{
    pool_rows N "$T/names.txt"; pool_rows R "$T/routines.txt"; pool_rows EN "$T/en.txt"; pool_rows ER "$T/er.txt"
    pool_rows U "$T/uni_n.txt"; pool_rows SN "$T/seq_n.txt"; pool_rows SC "$T/seq_c.txt"; pool_rows T "$T/test.txt"
} > "$T/pool.tsv"
LC_ALL=C awk -F'\t' '
    NR == FNR { cp[FNR - 1] = $1; next }
    FNR == 1 { print "#ifndef RK_CORE_NAMES_H"; print "#define RK_CORE_NAMES_H"; print "static const char rk_pool[] ="; off = 0 }
    { print "    \"" $3 "\\0\""; o[$1, n[$1]++] = off; off += $2 + 1 }
    function plain(name, k,    i, line) {
        print "static const unsigned " name "[] = {"; line = "   "
        for (i = 0; i < n[k]; i++) { line = line " " o[k, i] ","; if (i % 16 == 15) { print line; line = "   " } }
        if (line != "   ") print line
        print "};"
    }
    END {
        print "    ;"
        plain("rk_core_names", "N"); plain("rk_core_routines", "R"); plain("rk_core_e_names", "EN"); plain("rk_core_e_routines", "ER")
        print "typedef struct { unsigned name; int cp; } RkUniName;"; print "static const RkUniName rk_uninames[] = {"; line = "   "
        for (i = 0; i < n["U"]; i++) { line = line " { " o["U", i] ", " cp[i] " },"; if (i % 8 == 7) { print line; line = "   " } }
        if (line != "   ") print line
        print "};"
        print "typedef struct { unsigned name; unsigned cps; } RkUniSeq;"; print "static const RkUniSeq rk_uniseqs[] = {"; line = "   "
        for (i = 0; i < n["SN"]; i++) { line = line " { " o["SN", i] ", " o["SC", i] " },"; if (i % 8 == 7) { print line; line = "   " } }
        if (line != "   ") print line
        print "};"
        plain("rk_test_routines", "T")
        print "#endif"
    }' "$T/uni_cp.txt" "$T/pool.tsv" > "$OUT"
echo "rk_core_names.h: $(wc -l < "$T/names.txt") names, $(wc -l < "$T/routines.txt") routines, $(wc -l < "$T/test.txt") Test routines, $(wc -l < "$T/names_e.txt")+$(wc -l < "$T/routines_e.txt") 6.e additions, $(wc -l < "$T/uninames.txt") character names and aliases, $(wc -l < "$T/uniseqs.txt") named sequences, cut from $("$RAKU" --version | head -1)"
