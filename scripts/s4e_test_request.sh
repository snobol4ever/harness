#!/usr/bin/env bash
# s4e_test_request.sh -- ASK THE coo FOR NAMED TESTS (ceo CEO-1806; Lon 2026-10-15, verbatim: "The COO will have two work inputs, the round-robin and the
# recently requested from other officers and HQ's."). The coo's loop has exactly two inputs: these requests, served FIRST and oldest first, then its round
# robin. A request names a suite and its tests; the loop grades them one test at a time in both modes on origin HEAD, writes each test's row to the progress
# database tagged req=<your seat>, assembles the suite's row, and telegrams you every verdict. A landing's core-plus-shell check is its lander's request.
#
#   s4e_test_request.sh <suite-key> <entry>...     file a request (the entries as the suite's ALL.csv and PARTITION.tsv name them)
#   s4e_test_request.sh <suite-key> --part P       file a request for a stored part: core, shell:<feature> or chunk:NN
#   s4e_test_request.sh --suites                   the suite keys the loop can grade today, with their tables
#   s4e_test_request.sh --status                   the pending requests, oldest first
#   s4e_test_request.sh --engine E ...             REFUSED rc 2 for E = dotnet or jvm (CEO-1912); --engine scrip is the default
#
# THE PORT ENGINES RUN THEIR OWN TESTS (ceo CEO-1912; Lon 2026-10-22 15:0x, verbatim: "Let HQ-JVM and HQ-DOTNET run their own tests."): MODE LANES
# reads snobol4@dotnet=hq_dotnet and snobol4@jvm, snocone@jvm, rebus@jvm=hq_jvm, and the coo's loop grades no port engine, so --engine dotnet|jvm
# REFUSES at filing, naming the HQ whose lane it is -- a request the loop would only return ungraded a turn later is a dark road (CEO-1872 reversed).
# EXIT 0 filed (or listed); 2 refused, nothing filed: an unknown suite key, a suite not yet in the round robin, an entry its partition does not name, no seat.
# It runs nothing and builds nothing: the request is one file under /home/resources/postoffice/test_requests/ that the loop picks up between two tests.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQ_DIR="${S4E_TEST_REQUEST_DIR:-/home/resources/postoffice/test_requests}"
CORPUS="${S4E_CORPUS:-${S4E_HOME:-$(cd "$HERE/../.." && pwd)}/corpus}"
# THE SUITES IN THE ROUND ROBIN (CEO-1802 wave 1): key|table under corpus. A suite joins this list when its runner grades one chunk and its row assembles.
SUITES="sno-rungs|tests/snobol4 icn-rungs|tests/icon pl-rungs|tests/prolog snc-rungs|tests/snocone reb-rungs|tests/rebus pas-rungs|tests/pascal
raku-rungs|tests/raku puzzles|packages/prolog/puzzles rosetta-prolog|packages/prolog/rosetta-prolog xsb|packages/prolog/xsb_tests
trealla|packages/prolog/trealla_tests rosetta-pascal|packages/pascal/rosetta-pascal testpgms|packages/snobol4/spitbol_testpgms
x64tests|packages/snobol4/spitbol_x64_tests x32tests|packages/snobol4/spitbol_x32_tests dotnet|packages/snobol4/dotnet snoflake|packages/snobol4/snoflake_suite
aisnobol|packages/snobol4/aisnobol ipl|packages/icon/ipl
fpc|packages/pascal/fpc_tests pat|packages/pascal/pat roast|packages/raku/roast inria|packages/prolog/inriasuite gimpel|packages/snobol4/gimpel arizona|packages/icon/arizona_tests swi|packages/prolog/swi_tests logtalk|packages/prolog/logtalk_iso
jcon|packages/icon/jcon_tests csnobol4|packages/snobol4/csnobol4_suite prolog-bench-ref|benchmarks/prolog prolog-demos|demos/prolog scriptix-demos|demos/scriptix
gnu|packages/prolog/gnu_prolog"
# gnu (the cfo 2026-10-17, CEO-1810: the rotation grades it, a request was refused): test_prolog_gnu_suite.sh reads no S4E_CHUNK, so a request grades its whole table (62 entries, about two minutes) and writes its row
engine=scrip
if [ "${1:-}" = --engine ]; then
  engine="${2:-}"; shift 2 2>/dev/null || shift $#
  case "$engine" in scrip) ;; dotnet|jvm) echo "⛔ TEST REQUEST REFUSED(2): --engine $engine -- the port engines run their own tests (ceo CEO-1912; Lon: \"Let HQ-JVM and HQ-DOTNET run their own tests.\"): snobol4@$engine is hq_$engine's lane (MODE LANES), graded in its own root under S4E_ENGINE=$engine; the coo grades SCRIP alone -- nothing filed"; exit 2;; *) echo "⛔ TEST REQUEST REFUSED(2): --engine takes scrip, got '$engine' -- nothing filed"; exit 2;; esac
fi
refuse() { echo "⛔ TEST REQUEST REFUSED(2): $* -- nothing filed"; exit 2; }
table_of() { local e; for e in $SUITES; do [ "${e%%|*}" = "$1" ] && { echo "${e#*|}"; return 0; }; done; return 1; }
seat() {
  [ -n "${S4E_SEAT:-}" ] && { echo "$S4E_SEAT"; return; }
  local r; r="$(cd "$HERE/../.." && pwd)"; r="${r##*/claude_}"
  case "$r" in ceo|cto|cfo|coo) echo "$r";; icon|pascal|prolog|raku|snobol4|snocone|templates|runtime|collector|zetas|packages|dotnet|jvm) echo "hq_$r";; *) echo "";; esac
}
case "${1:-}" in
  ""|-h|--help) sed -n '2,/^set -uo/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'; exit 0;;
  --suites) for e in $SUITES; do printf '%-16s %s\n' "${e%%|*}" "${e#*|}"; done; exit 0;;
  --status) ls "$REQ_DIR"/*.req 2>/dev/null | while read -r f; do printf '%s  %s test(s) on %s\n' "$(basename "$f" .req)" "$(grep -m1 '^entries=' "$f" | cut -c9- | wc -w)" "$(sed -n 's/^engine=//p' "$f" | grep . || echo scrip)"; done; echo "pending: $(ls "$REQ_DIR"/*.req 2>/dev/null | wc -l)"; exit 0;;
esac
key="$1"; shift
tab="$(table_of "$key")" || refuse "suite key '$key' is not in the round robin yet (s4e_test_request.sh --suites lists the ones that are; the rest wait for their runner's chunk seam, CEO-1802 wave 2)"
P="$CORPUS/$tab/PARTITION.tsv"
# a table with no partition (the benchmarks and the demos, each one chunk by rule): its entries are its program files, by path or stem (CEO-1812)
has_file() { [ -f "$CORPUS/$tab/$1" ] || [ -n "$(find "$CORPUS/$tab" -maxdepth 3 -type f -name "$1.*" -print -quit 2>/dev/null)" ]; }
who="$(seat)"; [ -n "$who" ] || refuse "no seat: set S4E_SEAT, or run from a seat root /home/claude_<seat>"
ents=""
if [ "${1:-}" = --part ] && [ ! -f "$P" ]; then refuse "$key has no stored partition at $P: name its programs (a path under $tab, or a stem)"; fi
if [ "${1:-}" = --part ]; then
  part="${2:-}"; [ -n "$part" ] || refuse "--part needs core, shell:<feature> or chunk:NN"
  case "$part" in
    core) ents="$(awk -F'\t' '!/^#/ && $2=="core" {print $1}' "$P")";;
    chunk:*) ents="$(awk -F'\t' -v c="$part" '!/^#/ && $2==c {print $1}' "$P")";;
    shell:*) ents="$(awk -F'\t' -v f="${part#shell:}" '!/^#/ { n = split($4, a, " "); for (i = 1; i <= n; i++) if (a[i] == f) { print $1; break } }' "$P")";;
    *) refuse "--part wants core, shell:<feature> or chunk:NN, got '$part'";;
  esac
  ents="$(printf '%s\n' "$ents" | grep -v '^entry$' | grep .)" || refuse "$part selects no entry of $P"
else
  [ $# -gt 0 ] || refuse "name at least one entry of $key (or --part P)"
  names=""; [ -f "$P" ] && names="$(awk -F'\t' '!/^#/ {print $1}' "$P")"
  for e in "$@"; do
    if [ -f "$P" ]; then grep -qxF -- "$e" <<<"$names" || refuse "$key has no entry '$e' in $P"; else has_file "$e" || refuse "$key has no program '$e' under $tab"; fi
    ents="$ents $e"
  done
fi
n=$(printf '%s\n' $ents | grep -c .)
# ⛔ A REQUEST IS THE HANDFUL (Lon 2026-10-22, in-chat to the ceo, verbatim: "So when I say one test at a time, I mean one source program at a time.
# Would not any HQ request that only a handful of programs get re-tested at anytime since it will filter based on the feature?"; ceo CEO-1890/1891,
# CEO-1677's REPS_CAP): a seat's SCRIP request names at most eight programs -- the feature's representatives (test_feature_reps.sh <lang> <feature>
# --list names them) or the named witnesses of its row; a whole core, shell or chunk is the coo's round robin, never a seat's request. The coo's own
# re-filings are not capped here.
REQUEST_CAP=8
if [ "$who" != coo ] && [ "$n" -gt "$REQUEST_CAP" ]; then
  refuse "$n programs is not a handful: a seat's request names at most $REQUEST_CAP (the feature's representatives: bash ../harness/scripts/test_feature_reps.sh <lang> <feature> --list, or your row's witnesses); a whole ${part:-set} is the coo's round robin (CEO-1891)"
fi
mkdir -p "$REQ_DIR" || refuse "cannot create $REQ_DIR"
id="$(date -u +%Y%m%dT%H%M%S)-$who-$key-$$"
tmp="$REQ_DIR/.$id.tmp"
{ echo "seat=$who"; echo "suite=$key"; echo "table=$tab"; echo "filed=$(date '+%F %T %Z')"; echo "entries=$(printf '%s ' $ents | sed 's/ $//')"; } > "$tmp" && mv "$tmp" "$REQ_DIR/$id.req" || refuse "could not write the request"
echo "REQUESTED $id: $n test(s) of $key for $who. The coo's loop grades them ahead of its round robin, one test at a time in both modes, rows tagged req=$who, and telegrams you the verdicts. Pending now: $(ls "$REQ_DIR"/*.req 2>/dev/null | wc -l)."
