#!/usr/bin/env bash
# s4e_test_request.sh -- ASK THE coo FOR NAMED TESTS (R-1806; Lon 2026-10-15, verbatim: "The COO will have two work inputs, the round-robin and the
# recently requested from other officers and HQ's."). The coo's loop has exactly two inputs: these requests, served FIRST and oldest first, then its round
# robin. A request names a suite and its tests; the loop grades them one test at a time in both modes on origin HEAD, writes each test's row to the progress
# database tagged req=<your seat>, assembles the suite's row, and telegrams you every verdict. A landing's core-plus-shell check is its lander's request.
#
#   s4e_test_request.sh <suite-key> <entry>...     file a request (the entries as the suite's ALL.csv and PARTITION.tsv name them)
#   s4e_test_request.sh <suite-key> --part P       file a request for a stored part: core, shell:<feature> or chunk:NN
#   s4e_test_request.sh --suites                   the suite keys the loop can grade today, with their tables
#   s4e_test_request.sh --status                   the pending requests, oldest first
#   s4e_test_request.sh --read [--seat S] [--last N]   THE FILER READS ITS OWN VERDICTS (box-scheduler step 24, CTO-496): one VERDICTS line (pending, green, red,
#                                                  returned, dropped, unserved, total, shown) and one line per request, newest first, the last N (default 10) of the seat's
#                                                  requests, pending ones in the queue and graded ones in done/: GREEN and RED carry the served tree and rows, RED the
#                                                  entries whose rc was not 0, RETURNED a request the loop gave back ungraded (the port engines), DROPPED one the coo dropped, UNSERVED one that
#                                                  reached done/ with no served= line. It reads the files the loop wrote; it asks the loop for nothing.
#   s4e_test_request.sh --read --probe             the reader proved on a planted scratch queue (six requests of one seat and a decoy of another); a red probe prints
#                                                  PROBE RED and NO VERDICTS line, so a pipe through grep -q '^VERDICTS ' cannot pass a broken reader
#   s4e_test_request.sh --engine E ...             REFUSED rc 2 for E = dotnet or jvm (R-1912); --engine scrip is the default
#
# THE PORT ENGINES RUN THEIR OWN TESTS (R-1912; Lon 2026-10-22 15:0x, verbatim: "Let HQ-JVM and HQ-DOTNET run their own tests."): MODE LANES
# reads snobol4@dotnet=hq_dotnet and snobol4@jvm, snocone@jvm, rebus@jvm=hq_jvm, and the coo's loop grades no port engine, so --engine dotnet|jvm
# REFUSES at filing, naming the HQ whose lane it is -- a request the loop would only return ungraded a turn later is a dark road (R-1872 reversed).
# EXIT 0 filed (or listed); 2 refused, nothing filed: an unknown suite key, a suite with no master or pkg row, an entry its partition does not name, no seat.
# It runs nothing and builds nothing: the request is one file under /home/resources/postoffice/test_requests/ that the loop picks up between two tests.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQ_DIR="${S4E_TEST_REQUEST_DIR:-/home/resources/postoffice/test_requests}"
. "$HERE/lib_paths.sh"; CORPUS="$S4E_CORPUS"
# THE SUITES A REQUEST MAY NAME ARE THE CYCLE'S OWN (the grader 2026-11-13; skill suites-and-grading 3: a seat's request for any master or package key
# is admitted): every master or pkg row of SUITE_RUNNERS.tsv, its table tests/<lang> for a master and its table column for a pkg, as s4e_cycle.sh
# run_request reads them. The hand list of R-1802 wave 1 is gone. MEASURED: it refused gate_cases_raku and gate_cases_icon, pkg rows the cycle serves,
# so landed cures waited on a reading (the coo 11:3x), and it admitted gnu and prolog-bench-ref, small rows the cycle refuses.
RUNNERS="${S4E_SUITE_RUNNERS:-$HERE/SUITE_RUNNERS.tsv}"
SUITES="$(awk -F'\t' '!/^#/ && ($2 == "master" || $2 == "pkg") { d = ($2 == "master") ? "tests/" $3 : $5; sub(/^corpus\//, "", d); printf "%s|%s ", $1, d }' "$RUNNERS" 2>/dev/null)"
engine=scrip
if [ "${1:-}" = --engine ]; then
  engine="${2:-}"; shift 2 2>/dev/null || shift $#
  case "$engine" in scrip) ;; dotnet|jvm) echo "⛔ TEST REQUEST REFUSED(2): --engine $engine -- the port engines run their own tests (R-1912; Lon: \"Let HQ-JVM and HQ-DOTNET run their own tests.\"): snobol4@$engine is hq_$engine's lane (MODE LANES), graded in its own root under S4E_ENGINE=$engine; the coo grades SCRIP alone -- nothing filed"; exit 2;; *) echo "⛔ TEST REQUEST REFUSED(2): --engine takes scrip, got '$engine' -- nothing filed"; exit 2;; esac
fi
refuse() { echo "⛔ TEST REQUEST REFUSED(2): $* -- nothing filed"; exit 2; }
table_of() { local e; for e in $SUITES; do [ "${e%%|*}" = "$1" ] && { echo "${e#*|}"; return 0; }; done; return 1; }
seat() {
  [ -n "${S4E_SEAT:-}" ] && { echo "$S4E_SEAT"; return; }
  local r; r="$(cd "$HERE/../.." && pwd)"; r="${r##*/claude_}"
  case "$r" in cto|cfo|coo|cao|cqo) echo "$r";; icon|pascal|prolog|raku|snobol4|snocone|templates|runtime|collector|zetas|packages|dotnet|jvm) echo "hq_$r";; *) echo "";; esac
}
# THE VERDICTS A FILER READS (box-scheduler step 24). The loop writes a verdict into the request file it moves to done/: graded=<entry> and rc=<n> pairs, then one
# served=<time> tree=<hash> rc=<overall> rows=<n> line; a request the port-engine rule gives back reads served=returned <time> ungraded; the oldest ones in done/ carry no
# served= line at all. verdict_of prints ONE tab-separated record per request file (no empty field): state id seat suite tree rows entries reds filed.
verdict_of() {
  awk -v id="$(basename "$1" .req)" -v indone="$2" '
    /^seat=/ { seat = substr($0, 6) }
    /^suite=/ { suite = substr($0, 7) }
    /^filed=/ { filed = substr($0, 7) }
    /^entries=/ { ents = split(substr($0, 9), a, " ") }
    /^graded=/ { cur = substr($0, 8) }
    /^rc=/ { if (cur != "" && (substr($0, 4) + 0) != 0) reds = reds (reds == "" ? "" : ",") cur; cur = "" }
    /^served=/ {
      s = $0
      if (match(s, / rc=[0-9]+/)) st = ((substr(s, RSTART + 4, RLENGTH - 4) + 0) == 0) ? "GREEN" : "RED"
      else if (s ~ /DROPPED/) st = "DROPPED"
      else if (s ~ /returned/) st = "RETURNED"
      else st = "UNSERVED"
      if (match(s, /tree=.* rc=/)) tree = substr(s, RSTART + 5, RLENGTH - 9)
      if (match(s, /rows=[0-9]+/)) rows = substr(s, RSTART + 5, RLENGTH - 5)
    }
    END {
      if (st == "") st = (indone == 1) ? "UNSERVED" : "PENDING"
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", st, id, (seat == "" ? "-" : seat), (suite == "" ? "-" : suite), (tree == "" ? "-" : tree), (rows == "" ? "-" : rows), ents + 0, (reds == "" ? "-" : reds), (filed == "" ? "-" : filed)
    }' "$1"
}
refuse_read() { echo "⛔ TEST REQUEST READ REFUSED(2): $*"; exit 2; }
# read_verdicts <queue dir> <seat> <last>: the header counts ALL the seat's requests; the lines show the newest <last>. The file name selects, the seat= line decides (a seat
# named inside another seat's suite key or id cannot leak into the count).
read_verdicts() {
  local dir="$1" me="$2" last="$3" indone path rec st id sseat suite tree rows ents reds filed shown=0 total=0 pend=0 green=0 red=0 ret=0 drop=0 uns=0 out=""
  while IFS=$'\t' read -r indone path; do
    [ -n "$path" ] || continue
    rec="$(verdict_of "$path" "$indone")"
    IFS=$'\t' read -r st id sseat suite tree rows ents reds filed <<<"$rec"
    [ "$sseat" = "$me" ] || continue
    total=$((total + 1))
    case "$st" in PENDING) pend=$((pend + 1));; GREEN) green=$((green + 1));; RED) red=$((red + 1));; RETURNED) ret=$((ret + 1));; DROPPED) drop=$((drop + 1));; *) uns=$((uns + 1));; esac
    [ "$shown" -lt "$last" ] || continue
    shown=$((shown + 1))
    case "$st" in
      PENDING)  out+="PENDING $id suite=$suite entries=$ents filed=$filed"$'\n';;
      GREEN)    out+="GREEN $id suite=$suite tree=$tree rows=$rows"$'\n';;
      RED)      out+="RED $id suite=$suite tree=$tree rows=$rows red=$reds"$'\n';;
      RETURNED) out+="RETURNED $id suite=$suite (given back ungraded: the port engines run their own tests)"$'\n';;
      DROPPED)  out+="DROPPED $id suite=$suite (dropped by the coo without grading)"$'\n';;
      *)        out+="UNSERVED $id suite=$suite (in done/ with no served= line)"$'\n';;
    esac
  done < <( { ls -1 "$dir"/*-"$me"-*.req 2>/dev/null | sed 's/^/0\t/'; ls -1 "$dir"/done/*-"$me"-*.req 2>/dev/null | sed 's/^/1\t/'; } \
            | awk -F'\t' '{ n = split($2, p, "/"); print p[n] "\t" $1 "\t" $2 }' | sort -r | cut -f2- )
  printf 'VERDICTS seat=%s pending=%d green=%d red=%d returned=%d dropped=%d unserved=%d total=%d shown=%d\n' "$me" "$pend" "$green" "$red" "$ret" "$drop" "$uns" "$total" "$shown"
  printf '%s' "$out"
}
read_probe() {
  local d got got2 bad=""
  d="$(mktemp -d "${TMPDIR:-/tmp}/s4e_testreq_read_probe.XXXXXX")" || refuse_read "cannot make a scratch queue"
  mkdir -p "$d/done"
  printf 'seat=probe\nsuite=sno-rungs\ntable=tests/snobol4\nfiled=2026-11-05 10:00:06 CST\nentries=p1 p2 p3\n' > "$d/20261105T100006-probe-sno-rungs-6.req"
  printf 'seat=probe\nsuite=icn-rungs\ntable=tests/icon\nfiled=x\nentries=g1 g2\nsince=x\ngraded=g1\nrc=0\ngraded=g2\nrc=0\nserved=2026-11-05 10:00:05 CST tree=abc1234 rc=0 rows=2\n' > "$d/done/20261105T100005-probe-icn-rungs-5.req"
  printf 'seat=probe\nsuite=pl-rungs\ntable=tests/prolog\nfiled=x\nentries=r1 r2\nsince=x\ngraded=r1\nrc=0\ngraded=r2\nrc=1\nserved=2026-11-05 10:00:04 CST tree=def5678 rc=1 rows=2\n' > "$d/done/20261105T100004-probe-pl-rungs-4.req"
  printf 'seat=probe\nsuite=snc-rungs\ntable=tests/snocone\nfiled=x\nentries=j1\nengine=jvm\nserved=returned 2026-11-05 10:00:03 CST ungraded (CEO-1912: the port engines run their own tests)\n' > "$d/done/20261105T100003-probe-snc-rungs-3.req"
  printf 'seat=probe\nsuite=swi\ntable=packages/prolog/swi_tests\nfiled=x\nentries=w1\n' > "$d/done/20261105T100002-probe-swi-2.req"
  printf 'seat=probe\nsuite=gnu\ntable=packages/prolog/gnu_prolog\nfiled=x\nentries=n1\nserved=2026-11-05 10:00:00 CST DROPPED by the coo: graded elsewhere\n' > "$d/done/20261105T100000-probe-gnu-0.req"
  printf 'seat=other\nsuite=sno-rungs\ntable=tests/snobol4\nfiled=x\nentries=z1\nsince=x\ngraded=z1\nrc=1\nserved=2026-11-05 10:00:01 CST tree=zzz9999 rc=1 rows=1\n' > "$d/done/20261105T100001-other-probe-sno-rungs-1.req"
  got="$(read_verdicts "$d" probe 10)"; got2="$(read_verdicts "$d" probe 2 | sed -n 1p)"; rm -rf "$d"
  grep -qx 'VERDICTS seat=probe pending=1 green=1 red=1 returned=1 dropped=1 unserved=1 total=6 shown=6' <<<"$got" || bad="$bad the header counts"
  [ "$(sed -n 2p <<<"$got")" = "PENDING 20261105T100006-probe-sno-rungs-6 suite=sno-rungs entries=3 filed=2026-11-05 10:00:06 CST" ] || bad="$bad newest-first order or the PENDING line"
  grep -qx 'GREEN 20261105T100005-probe-icn-rungs-5 suite=icn-rungs tree=abc1234 rows=2' <<<"$got" || bad="$bad the GREEN line"
  grep -qx 'RED 20261105T100004-probe-pl-rungs-4 suite=pl-rungs tree=def5678 rows=2 red=r2' <<<"$got" || bad="$bad the RED line naming r2"
  grep -q '^RETURNED 20261105T100003-probe-snc-rungs-3 ' <<<"$got" || bad="$bad the RETURNED line"
  grep -q '^UNSERVED 20261105T100002-probe-swi-2 ' <<<"$got" || bad="$bad the UNSERVED line"
  grep -q '^DROPPED 20261105T100000-probe-gnu-0 ' <<<"$got" || bad="$bad the DROPPED line"
  ! grep -q 'other-probe-sno-rungs-1\|zzz9999' <<<"$got" || bad="$bad a decoy of another seat leaked in"
  [ "$got2" = 'VERDICTS seat=probe pending=1 green=1 red=1 returned=1 dropped=1 unserved=1 total=6 shown=2' ] || bad="$bad --last 2 shows two but counts all six"
  if [ -n "$bad" ]; then echo "PROBE RED: the verdict reader got wrong:$bad"; return 1; fi
  printf '%s\n' "$got"
  echo "PROBE ok: six requests of one seat read back newest first with their states, a decoy of another seat kept out, --last 2 counting all six"
}
read_main() {
  local me="" last=10 probe=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --seat) me="${2:-}"; shift;;
      --last) last="${2:-}"; shift;;
      --probe) probe=1;;
      *) refuse_read "unknown switch $1 (--read takes --seat S, --last N, --probe)";;
    esac
    shift
  done
  case "$last" in ''|*[!0-9]*) refuse_read "--last takes a number, got '$last'";; esac
  [ "$probe" = 1 ] && { read_probe; return $?; }
  [ -n "$me" ] || me="$(seat)"
  [ -n "$me" ] || refuse_read "no seat: set S4E_SEAT, pass --seat S, or run from a seat root /home/claude_<seat>"
  read_verdicts "$REQ_DIR" "$me" "$last"
}
case "${1:-}" in
  --read) shift; read_main "$@"; exit $?;;
  ""|-h|--help) sed -n '2,/^set -uo/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'; exit 0;;
  --suites) for e in $SUITES; do printf '%-16s %s\n' "${e%%|*}" "${e#*|}"; done; exit 0;;
  --status) ls "$REQ_DIR"/*.req 2>/dev/null | while read -r f; do printf '%s  %s test(s) on %s\n' "$(basename "$f" .req)" "$(grep -m1 '^entries=' "$f" | cut -c9- | wc -w)" "$(sed -n 's/^engine=//p' "$f" | grep . || echo scrip)"; done; echo "pending: $(ls "$REQ_DIR"/*.req 2>/dev/null | wc -l)"; exit 0;;
esac
key="$1"; shift
tab="$(table_of "$key")" || refuse "suite key '$key' is no master or pkg row of SUITE_RUNNERS.tsv, so the cycle cannot serve it (s4e_test_request.sh --suites lists the ones it can; a small row is graded by its own runner until it becomes a package)"
P="$CORPUS/$tab/PARTITION.tsv"
# a table with no partition (the benchmarks and the demos, each one chunk by rule): its entries are its program files, by path or stem (R-1812)
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
# ⛔ A REQUEST IS THE HANDFUL (Lon 2026-10-22, in-chat, verbatim: "So when I say one test at a time, I mean one source program at a time.
# Would not any HQ request that only a handful of programs get re-tested at anytime since it will filter based on the feature?"; R-1890/1891,
# R-1677's REPS_CAP): a seat's SCRIP request names at most eight programs -- the feature's representatives (test_feature_reps.sh <lang> <feature>
# --list names them) or the named witnesses of its row; a whole core, shell or chunk is the coo's round robin, never a seat's request. The coo's own
# re-filings are not capped here.
REQUEST_CAP=8
if [ "$who" != coo ] && [ "$n" -gt "$REQUEST_CAP" ]; then
  refuse "$n programs is not a handful: a seat's request names at most $REQUEST_CAP (the feature's representatives: bash ../harness/scripts/test_feature_reps.sh <lang> <feature> --list, or your row's witnesses); a whole ${part:-set} is the coo's round robin (R-1891)"  # one-disk: not a path
fi
mkdir -p "$REQ_DIR" || refuse "cannot create $REQ_DIR"
id="$(date -u +%Y%m%dT%H%M%S)-$who-$key-$$"
tmp="$REQ_DIR/.$id.tmp"
{ echo "seat=$who"; echo "suite=$key"; echo "table=$tab"; echo "filed=$(date '+%F %T %Z')"; echo "entries=$(printf '%s ' $ents | sed 's/ $//')"; } > "$tmp" && mv "$tmp" "$REQ_DIR/$id.req" || refuse "could not write the request"
echo "REQUESTED $id: $n test(s) of $key for $who. The coo's loop grades them ahead of its round robin, one test at a time in both modes, rows tagged req=$who, and telegrams you the verdicts. Pending now: $(ls "$REQ_DIR"/*.req 2>/dev/null | wc -l)."
