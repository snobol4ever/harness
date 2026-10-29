#!/usr/bin/env bash
# util_act_word_census.sh -- EVERY ACTIVATION-FRAME WORD OF THE PATTERN LANGUAGES, BY ITS CAUSE (the cto, 2026-10-24; Lon 11:4x: "most of those
# SNOBOL4 RBP are due to *DEFERRED_PATTERN and PATTERN_FUNCTION() and are valid. But do go verify each one and see."; CEO-1942: RSP is the default
# home, RBP only for a cell in an unbounded situation; ARCH-THREE-ZETAS-EMISSION 6.1).
# Reads the plan table's act column (scrip --dump-plan --compile) over util_spine_population.sh's programs of the languages that lower to the
# SNOBOL4 match frame (snobol4 snocone rebus raku by default) and tallies, per language, the boxes whose cell lives in the match frame or the blob
# frame by the cause the planner names: deferred_pattern, static_pattern, pattern_function, arbno_iteration, resume_road (unbounded -- valid),
# bounded_arm (an alternation arm's variance), bounded_other (a conservative rule), home (the home pass's frame home, Icon and Prolog), regex_kit (the Raku regex kit's capture block, unbounded by its backtracking run).
#   util_act_word_census.sh [--lang L]... [--names] [--files F...]
# Prints ACT_WORDS lang=<l> boxes=<n> deferred_pattern=<n> static_pattern=<n> pattern_function=<n> arbno_iteration=<n> resume_road=<n> regex_kit=<n>
# bounded_arm=<n> bounded_other=<n> home=<n> unbounded=<n> bounded=<n>, one ACT_WORDS total line, and with --names one ACT_WORD_SITE line per box
# (lang program all kind cause). rc 0 measured, rc 2 could not measure (no binary or no program compiled).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
[ -x "$SCRIP" ] || { echo "ACT_WORDS REFUSE(2): no scrip at $SCRIP"; exit 2; }
LANGS=(); NAMES=0; FILES=()
while [ $# -gt 0 ]; do case "$1" in --lang) LANGS+=("$2"); shift 2;; --names) NAMES=1; shift;; --files) shift; while [ $# -gt 0 ]; do FILES+=("$1"); shift; done;; *) echo "ACT_WORDS REFUSE(2): unknown argument $1"; exit 2;; esac; done
[ ${#LANGS[@]} -gt 0 ] || LANGS=(snobol4 snocone rebus raku)
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
: > "$T/sites"
compiled=0
if [ ${#FILES[@]} -gt 0 ]; then for f in "${FILES[@]}"; do case "$f" in *.sno|*.spt|*.sbl) echo "snobol4 $f";; *.sc) echo "snocone $f";; *.reb) echo "rebus $f";; *.raku) echo "raku $f";; *.icn) echo "icon $f";; *.pl) echo "prolog $f";; *.pas) echo "pascal $f";; esac; done > "$T/pop"
else bash "$HERE/util_spine_population.sh" | awk -v want=" ${LANGS[*]} " 'index(want, " " $1 " ") {print $1, $2}' > "$T/pop"; fi
while read -r lang prog; do
    d="$(dirname "$prog")"; b="$(basename "$prog")"
    if ( cd "$d" && timeout -k 5 300 "$SCRIP" --dump-plan --compile --out=/dev/null "$b" < /dev/null > "$T/dump" 2>/dev/null ); then compiled=$((compiled + 1)); else continue; fi
    awk -v L="$lang" -v P="$b" '$1 == "PLAN_ROW" && $NF != "-" { a = $3; sub(/^all=/, "", a); k = $4; sub(/^kind=/, "", k); print L, P, a, k, $NF }' "$T/dump" | sort -u >> "$T/sites"
done < "$T/pop"
[ "$compiled" -gt 0 ] || { echo "ACT_WORDS REFUSE(2): no program of ${LANGS[*]} compiled"; exit 2; }
[ "$NAMES" = 1 ] && sed 's/^/ACT_WORD_SITE /' "$T/sites"
awk '{ n[$1]++; c[$1 " " $5]++; nt++; ct[$5]++; langs[$1] = 1 }
     function line(l, pre,   u, b) { u = c[l " deferred_pattern"] + c[l " static_pattern"] + c[l " pattern_function"] + c[l " arbno_iteration"] + c[l " resume_road"] + c[l " regex_kit"]; b = c[l " bounded_arm"] + c[l " bounded_other"];
         printf "ACT_WORDS %s boxes=%d deferred_pattern=%d static_pattern=%d pattern_function=%d arbno_iteration=%d resume_road=%d regex_kit=%d bounded_arm=%d bounded_other=%d home=%d unbounded=%d bounded=%d\n", pre, n[l] + 0, c[l " deferred_pattern"] + 0, c[l " static_pattern"] + 0, c[l " pattern_function"] + 0, c[l " arbno_iteration"] + 0, c[l " resume_road"] + 0, c[l " regex_kit"] + 0, c[l " bounded_arm"] + 0, c[l " bounded_other"] + 0, c[l " home"] + 0, u, b }
     END { for (l in langs) line(l, "lang=" l); for (l in langs) { for (k in ct) c["total " k] += c[l " " k]; n["total"] += n[l] } line("total", "total") }' "$T/sites" | sort
echo "ACT_WORDS tree=$(git -C "$HERE/../../SCRIP" rev-parse --short HEAD 2>/dev/null) programs=$(wc -l < "$T/pop") compiled=$compiled"
