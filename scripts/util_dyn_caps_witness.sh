#!/usr/bin/env bash
# util_dyn_caps_witness.sh compile|runtime|census -- the criteria of ARCH-DYNAMIC-STORAGE.md (Lon 2026-09-23: no fixed limits).
# compile: the three compile-time witnesses (200 DEFINEs and a 608-entry blob layout vs sbl -bf, 600 predicates vs gprolog) plus zero compiler tables bound
#          by a compile-time population cap in the census; runtime: the 70-argument Icon call vs iconx plus zero runtime tables
#          bound by a runtime population cap; census: the ratchet -- file/static/field declarations may only fall from BASELINE, and the
#          locals a program fills (CEO-1231 stage 2) may only fall from BASELINE_FUNCTION_SCOPE; witness: every LOUD guard's refusal read
#          at its cap+1 by the program ../harness/scripts/fixtures/dyn_caps/WITNESSES.tsv names for it. Every verb first sets aside the compilation
#          units ../harness/scripts/fixtures/dyn_caps/NOT_SHIPPED.tsv declares, each checked against the scrip and libscrip_rt link lines (CEO-1235 (3)).
# rc 0 GREEN, 1 RED, 2 REFUSE (an oracle or the binary missing). The population regexes are the page's § 6 list, spelled once here.
# The GNU Prolog oracle is gplc's native binary, never `"$(gprolog_bin)" --consult-file`: the top level prints a four-line banner and consult's two
# "compiling ..." lines to STDOUT before the program runs, so that arm read 606 lines against a correct 600 and could never go green (cfo 2026-09-23).
set -u
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_oracle_flags.sh"
HERE=$(cd "$(dirname "$0")" && pwd); cd "$HERE/../../SCRIP" || exit 2
. "$HERE/lib_fanout.sh" || { echo "REFUSE(2): ../harness/scripts/lib_fanout.sh is missing -- a census runs serially under nice 19 (CEO-1333) and has no instrument"; exit 2; }
mode=${1:-}; [ -n "$mode" ] || { echo "REFUSE(2): usage: util_dyn_caps_witness.sh compile|runtime|census|witness"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
$(fanout_nice) python3 ../harness/scripts/audit_fixed_caps_census.py --tsv "$T/c.tsv" --no-report > "$T/census.txt" 2>&1 || { echo "REFUSE(2): the census refused -- $(tail -2 "$T/census.txt" | tr '\n' ' ')"; exit 2; }
red=0
# ⭐ NOT SHIPPED (ceo CEO-1235 (3)): ../harness/scripts/fixtures/dyn_caps/NOT_SHIPPED.tsv names the compilation units no program's run reaches (unit
# tests, tools, demos); their rows leave $T/c.tsv before any line below reads it. THE LINK IS THE EVIDENCE: each row is checked against
# make's own RT_PIC_SRCS (what `$(CC) -shared` links into libscrip_rt) and src/driver/scrip.c (the scrip link). A linked file, a header
# or a file the tree no longer has sets nothing aside and reads RED by name, in every verb. DYN_CAPS_NOT_SHIPPED overrides the path.
NS="${DYN_CAPS_NOT_SHIPPED:-../harness/scripts/fixtures/dyn_caps/NOT_SHIPPED.tsv}"; [ -f "$NS" ] || { echo "REFUSE(2): no not-shipped declaration at $NS"; exit 2; }
nsbad=$(awk -F'\t' '!/^#/ && NF && (NF < 2 || $1 == "" || $2 == "")' "$NS")
[ -z "$nsbad" ] || { echo "REFUSE(2): $NS rows that are not file<TAB>reason:"; printf '%s\n' "$nsbad" | cut -c1-160; exit 2; }
[ -f Makefile ] || { echo "REFUSE(2): no Makefile -- the not-shipped rows are checked against its link lines"; exit 2; }
make -s --no-print-directory -f Makefile -f <(printf 'dyn_caps_print_rt_pic_srcs:\n\t@echo $(RT_PIC_SRCS)\n') dyn_caps_print_rt_pic_srcs 2> /dev/null \
  | tr ' ' '\n' | awk -v p="$PWD/" 'index($0, p) == 1 {print substr($0, length(p) + 1)}' > "$T/link"
[ -s "$T/link" ] || { echo "REFUSE(2): make printed no RT_PIC_SRCS under $PWD -- the libscrip_rt link line cannot be read"; exit 2; }
echo src/driver/scrip.c >> "$T/link"
nsred=$(awk -F'\t' 'FNR==NR {ln[$1] = 1; next} !/^#/ && NF >= 2 {f = $1
          if (f in ln) print "  LINKED  " f " -- the scrip or libscrip_rt link line consumes it"
          else if (f !~ /\.(c|cc|cpp|s|S)$/) print "  HEADER  " f " -- not a compilation unit; a header ships wherever a shipped unit includes it"
          else if (system("test -f \"" f "\"") != 0) print "  STALE   " f " -- the tree no longer has it"}' "$T/link" "$NS")
awk -F'\t' '!/^#/ && NF >= 2 {print $1}' "$NS" | sort -u > "$T/ns.all"
printf '%s\n' "$nsred" | awk 'NF >= 2 {print $2}' | sort -u > "$T/ns.bad"
comm -23 "$T/ns.all" "$T/ns.bad" > "$T/ns.ok"
read -r nst nsl nsf <<<"$(awk -F'\t' 'FILENAME==ARGV[1] {ok[$1] = 1; next} FNR>1 && ($1 in ok) {f[$1] = 1
                              if ($3=="file"||$3=="static"||$3=="field"||$3=="arena") t++; else if ($3=="local" && $9=="" && $11!="" && $11 !~ /^B:/) l++}
                            END {n = 0; for (k in f) n++; print t+0, l+0, n+0}' "$T/ns.ok" "$T/c.tsv")"
awk -F'\t' 'FILENAME==ARGV[1] {ok[$1] = 1; next} FNR==1 || !($1 in ok)' "$T/ns.ok" "$T/c.tsv" > "$T/c.kept" && mv "$T/c.kept" "$T/c.tsv"
[ -z "$nsred" ] || { echo "RED: $NS declares a file that ships or does not exist -- nothing of it was set aside; fix the row:"; printf '%s\n' "$nsred"; red=1; }
# ⛔ A CLASS A/B DECLARATION LEAVES THE STILL-BOUND LIST (the cfo's ask 2026-09-27 18:5x, the coo 2026-09-28): the compile and runtime
# verbs listed rows by bound name and never read CLASS_AB.tsv, so a table declared class A (stage2.h's chained hash width, 256, that no
# count of predicates fills) could never leave its list and the umbrella's DONE-WHEN stayed red over a declared row. count_caps now
# drops a (file, name) CLASS_AB.tsv declares, exactly as the census verb drops it from the no-guard line; count_caps_declared names what
# was set aside, so the line reads "still bound: n (k declared class A/B, set aside)" and the ratchet counts are untouched.
_ab_file() { printf '%s' "${DYN_CAPS_CLASS_AB:-../harness/scripts/fixtures/dyn_caps/CLASS_AB.tsv}"; }
count_caps() { awk -F'\t' -v dirs="$1" -v caps="$2" 'FILENAME==ARGV[1] { if ($0 !~ /^#/ && NF>=3) ab[$1 "\t" $2]=1; next } FNR>1 && ($3=="file"||$3=="static"||$3=="field"||$3=="arena") && $1 ~ dirs && $5 ~ caps && !(($1 "\t" $4) in ab) {print "  " $1 ":" $2 " " $4 "[" $5 "]"}' "$(_ab_file)" "$T/c.tsv"; }
count_caps_declared() { awk -F'\t' -v dirs="$1" -v caps="$2" 'FILENAME==ARGV[1] { if ($0 !~ /^#/ && NF>=3) ab[$1 "\t" $2]=$3; next } FNR>1 && ($3=="file"||$3=="static"||$3=="field"||$3=="arena") && $1 ~ dirs && $5 ~ caps && (($1 "\t" $4) in ab) {print "  " $1 ":" $2 " " $4 "[" $5 "] class " ab[$1 "\t" $4]}' "$(_ab_file)" "$T/c.tsv"; }
COMPILE_CAPS='^(SNO_DEF_MAX|SNO_PAT_MAX|SNO_EXPR_MAX|SNO_FZW_MAX|SNO_LOOP_STACK_MAX|MAX_PREDS|PL_BB_TABLE_MAX|PL_INIT_GOALS_MAX|PL_CONSULT_FILES_MAX|FL_MAX_ENTRIES|FL_MAX_FIELDS|FL_MAX_SCOPES|FL_MAX_GRAPHS|ZDP_CAP|BB_PATCH_MAX|SMX_STRTAB_CAP|SMX_CSETTAB_CAP|AB_FNCELL_MAX|XA_BB_EMIT_PAIR_MAX|ZD_NOPS_MAX|FLAT_CHAIN_SET_MAX|FLAT_DATA_LBL_MAX|WASM_STRTAB_MAX|WASM_USERFNS_MAX|STAGE2_LABEL_MAX|STAGE2_PROC_TABLE_MAX|STAGE2_PL_PRED_TABLE_SIZE|STAGE2_FRAME_SLOT_MAX|STAGE2_MOD_MAX|MAX_STATES|MAX_GROUPS|MAX_CAPLOG|RK_GRAM_MAX|SC_DAT_MAX_TYPES|INIT_MAX|SHADOW_MAX|CALL_STACK_MAX)$'
RUNTIME_CAPS='^(CALL_ARGS_MAX|RT_FRAME_STACK_MAX|RT_FRAME_SLOT_MAX|FH_MAX|GLOBAL_MAX|RT_MAX_CAPTURES|VSTACK_MAX|SAVE_MAX|FRAME_STACK_MAX|FRAME_SLOT_MAX|FRAME_DEPTH_MAX|EVERY_GEN_SLOT_MAX|SCAN_STACK_MAX|RT_INITIAL_MAX|RT_DC_FNS_MAX|RT_PROC_LOC_MAX|FIELD_ACCESSOR_MAX|RT_CAS_CAPO_MAX|VAR_BUCKETS|ZSM_N|ZDP_RBP_TAB_N|EXPRESSION_REG_MAX|BB_DCAP_MAX|SEQ_CACHE_MAX|SUSP_GEN_CACHE_MAX|ICN_STACK_MAX|NV_MEMO_N|RT_DCAP_NVCACHE_N)$'
case "$mode" in
compile)
  [ -x ./scrip ] || { echo "REFUSE(2): no ./scrip"; exit 2; }
  python3 ../harness/scripts/util_dyn_caps_gen.py "$T/w" || exit 2
  SBL=/home/resources/x64/bin/sbl; [ -x "$SBL" ] || { echo "REFUSE(2): no SPITBOL oracle at $SBL"; exit 2; }
  "$SBL" -bf "$T/w/defines200.sno" < /dev/null > "$T/a.ref" 2>&1; timeout -k 5 60 ./scrip --run "$T/w/defines200.sno" < /dev/null > "$T/a.out" 2> "$T/a.err"
  if cmp -s "$T/a.ref" "$T/a.out"; then echo "PASS defines200.sno: 200 DEFINEs read $(tr -d '\n' < "$T/a.ref") in both"; else echo "RED defines200.sno: sbl -bf prints $(head -c 40 "$T/a.ref" | tr -d '\n'), scrip prints '$(head -c 40 "$T/a.out" | tr -d '\n')' -- $(head -c 140 "$T/a.err" | tr '\n' ' ')"; red=1; fi
  "$SBL" -bf "$T/w/blobs150.sno" < /dev/null > "$T/d.ref" 2>&1; timeout -k 5 60 ./scrip --run "$T/w/blobs150.sno" < /dev/null > "$T/d.out" 2> "$T/d.err"
  if cmp -s "$T/d.ref" "$T/d.out"; then echo "PASS blobs150.sno: a run-time pattern whose blob layout needs 608 entries reads $(tr -d '\n' < "$T/d.ref") in both"; else echo "RED blobs150.sno: sbl -bf prints $(head -c 40 "$T/d.ref" | tr -d '\n'), scrip prints '$(head -c 40 "$T/d.out" | tr -d '\n')' -- $(head -c 140 "$T/d.err" | tr '\n' ' ')"; red=1; fi
  gplc_bin >/dev/null || exit 2
  ( cd "$T/w" && timeout -k 5 120 "$(gplc_bin)" preds600.pl -o preds600.gp > /dev/null 2>&1 ) || { echo "REFUSE(2): gplc could not compile preds600.pl"; exit 2; }
  timeout -k 5 120 "$T/w/preds600.gp" < /dev/null > "$T/b.ref" 2> /dev/null; timeout -k 5 120 ./scrip --run "$T/w/preds600.pl" < /dev/null > "$T/b.out" 2> "$T/b.err"
  if cmp -s "$T/b.ref" "$T/b.out"; then echo "PASS preds600.pl: 600 predicates, $(wc -l < "$T/b.ref") lines identical to gprolog"; else echo "RED preds600.pl: gprolog prints $(wc -l < "$T/b.ref") lines, scrip $(wc -l < "$T/b.out") -- $(head -c 120 "$T/b.err" | tr '\n' ' ')"; red=1; fi
  L=$(count_caps '^src/(ir|emitter|lower|parsers|driver)/' "$COMPILE_CAPS"); n=$(printf '%s' "$L" | grep -c .); D=$(count_caps_declared '^src/(ir|emitter|lower|parsers|driver)/' "$COMPILE_CAPS"); d=$(printf '%s' "$D" | grep -c .); echo "compile-time tables still bound by a population cap: $n ($d declared class A/B in $(_ab_file), set aside)"; [ "$d" = 0 ] || printf '%s\n' "$D"; [ "$n" = 0 ] || { printf '%s\n' "$L"; red=1; }
  ;;
runtime)
  [ -x ./scrip ] || { echo "REFUSE(2): no ./scrip"; exit 2; }
  python3 ../harness/scripts/util_dyn_caps_gen.py "$T/w" || exit 2
  ICONT=/home/resources/icon-master/bin/icont; [ -x "$ICONT" ] || { echo "REFUSE(2): no icont oracle at $ICONT"; exit 2; }
  ( cd "$T/w" && "$ICONT" -s -o args70x args70.icn > /dev/null 2>&1 && PATH=/home/resources/icon-master/bin:$PATH ./args70x > "$T/c.ref" 2>&1 ) || { echo "REFUSE(2): the oracle could not run args70.icn"; exit 2; }
  timeout -k 5 60 ./scrip --run "$T/w/args70.icn" < /dev/null > "$T/c.out" 2> "$T/c.err"
  if cmp -s "$T/c.ref" "$T/c.out"; then echo "PASS args70.icn: a 70-argument call reads $(tr -d '\n' < "$T/c.ref") in both"; else echo "RED args70.icn: iconx prints $(tr -d '\n' < "$T/c.ref"), scrip prints '$(head -c 40 "$T/c.out" | tr -d '\n')' -- $(head -c 140 "$T/c.err" | tr '\n' ' ')"; red=1; fi
  L=$(count_caps '^src/runtime/' "$RUNTIME_CAPS"); n=$(printf '%s' "$L" | grep -c .); D=$(count_caps_declared '^src/runtime/' "$RUNTIME_CAPS"); d=$(printf '%s' "$D" | grep -c .); echo "runtime tables still bound by a population cap: $n ($d declared class A/B in $(_ab_file), set aside)"; [ "$d" = 0 ] || printf '%s\n' "$D"; [ "$n" = 0 ] || { printf '%s\n' "$L"; red=1; }
  ;;
census)
  B=../harness/scripts/fixtures/dyn_caps/BASELINE; [ -f "$B" ] || { echo "REFUSE(2): no baseline at $B"; exit 2; }
  BF=../harness/scripts/fixtures/dyn_caps/BASELINE_FUNCTION_SCOPE; [ -f "$BF" ] || { echo "REFUSE(2): no function-scope baseline at $BF"; exit 2; }
  # ⭐ THE GUARD LINES READ THE CLASSIFIER (audit_fixed_caps_census.py, CEO-1231): u is every file/static/field table, macro OR literal
  # bound, with no capacity guard at a fill (never compared, or compared only as an index or an iteration) and not read-only; d is
  # every such table whose guard DROPS -- skips, truncates, clamps or fails silently at the cap. A const table is class A by rule and in
  # neither. ⛔ ONE line ends "never compared in its file: N", on purpose: the row's DONE-WHEN greps that suffix, and two lines ending in
  # it would let either one's zero pass the criterion for both.
  [ "$(head -1 "$T/c.tsv" | cut -f8-9,11)" = "$(printf 'guard\tconst\tfill')" ] || { echo "REFUSE(2): the census TSV carries no guard/const/fill columns -- an older census cannot be read by these lines"; exit 2; }
  # ⭐ ARENAS (CEO-1231 (1), stage 2 (b)): the census's scope `arena` rows -- a constant 64 KiB or more from an allocator -- count with the
  # file-scope tables in all three lines below, and CLASS_AB.tsv may declare them (the sigaltstack).
  # ⭐ THE CLASS A/B DECLARATION IS A FIXTURE (ceo CEO-1234 (1)): a table CLASS_AB.tsv names, with the measurement that earned its class,
  # leaves the no-guard and drop lines as a const table does by rule; the ratchet COUNT is unchanged; a row naming a table the tree no
  # longer declares is RED (a stale keep-list is one nobody notices has stopped applying).
  AB="${DYN_CAPS_CLASS_AB:-../harness/scripts/fixtures/dyn_caps/CLASS_AB.tsv}"; [ -f "$AB" ] || { echo "REFUSE(2): no class A/B declaration at $AB"; exit 2; }
  abad=$(awk -F'\t' '!/^#/ && NF && (NF < 4 || ($3 != "A" && $3 != "B") || $4 == "") {print "  line " FNR ": " substr($0, 1, 100)}' "$AB")
  [ -z "$abad" ] || { echo "REFUSE(2): $AB rows that are not file<TAB>name<TAB>A|B<TAB>reason:"; printf '%s\n' "$abad"; exit 2; }
  base=$(cat "$B"); n=$(awk -F'\t' 'NR>1 && ($3=="file"||$3=="static"||$3=="field"||$3=="arena")' "$T/c.tsv" | wc -l)
  u=$(awk -F'\t' 'FILENAME==ARGV[1] {if ($0 !~ /^#/ && NF >= 4) ab[$1 SUBSEP $2] = 1; next} FNR>1 && ($3=="file"||$3=="static"||$3=="field"||$3=="arena") && $8=="NONE" && $9=="" && !(($1 SUBSEP $4) in ab)' "$AB" "$T/c.tsv" | wc -l)
  d=$(awk -F'\t' 'FILENAME==ARGV[1] {if ($0 !~ /^#/ && NF >= 4) ab[$1 SUBSEP $2] = 1; next} FNR>1 && ($3=="file"||$3=="static"||$3=="field"||$3=="arena") && $8=="DROP" && $9=="" && !(($1 SUBSEP $4) in ab)' "$AB" "$T/c.tsv" | wc -l)
  # the TABLES a row declares, not the rows: a row is (file, name), and one name can declare several tables in one file
  # (bb_match_capture.cpp's three b buffers, CEO-1269) -- counting rows printed 23 over 25 declared tables
  nab=$(awk -F'\t' 'FILENAME==ARGV[1] {if ($0 !~ /^#/ && NF >= 4) ab[$1 SUBSEP $2] = 1; next} FNR>1 && ($3=="file"||$3=="static"||$3=="field"||$3=="arena") && (($1 SUBSEP $4) in ab)' "$AB" "$T/c.tsv" | wc -l)
  stale=$(awk -F'\t' 'FNR==NR {if (FNR>1 && ($3=="file"||$3=="static"||$3=="field"||$3=="arena"||($3=="local" && $9=="" && $11!="" && $11 !~ /^B:/))) have[$1 SUBSEP $4] = 1; next} !/^#/ && NF >= 4 && !(($1 SUBSEP $2) in have) {print "  " $1 ":" $2}' "$T/c.tsv" "$AB")
  echo "fixed-bound declarations at file, static or field scope and fixed-size arenas: $n (baseline $base); with no capacity guard at a fill, by a macro or a literal bound -- compared only as an index or an iteration, or never compared in its file: $u"
  echo "guards that drop or truncate at the cap: $d"
  echo "declared class A or B by $AB (out of the two lines above, in the count): $nab table(s); stale declarations: $(printf '%s' "$stale" | grep -c .)"
  echo "set aside as not shipped by $NS, each row checked against the scrip and libscrip_rt link lines: $nst table(s) and $nsl local(s) a program fills, in $nsf of $(grep -c . "$T/ns.all") declared file(s); linked, header or stale declarations: $(printf '%s' "$nsred" | grep -c .)"
  [ -z "$stale" ] || { echo "RED: $AB declares a table the tree no longer declares -- remove the row in the landing that removed the table:"; printf '%s\n' "$stale"; red=1; }
  # ⭐ THE SECOND POPULATION (CEO-1231 (1), stage 2): every local a program's data fills -- the census's fill column names how (COUNTER,
  # CALLEE:f, FORMAT:f, COPY:f, READ:f, PATH:f); B:<why> is fixed by construction and out; const is read-only and out. Unguarded is DROP
  # and NONE together (CEO-1231 (2): a drop is not a guard); guarded is LOUD, which the reader also gives a GROW (the at-cap path
  # allocates). The population is ratcheted like the file-scope one, against its own BASELINE_FUNCTION_SCOPE.
  # ⭐ A LOCAL MAY BE DECLARED (ceo 2026-10-02, the coo's arm-5 ask, ruling (a): gc_audit_b.c's /proc/self/maps buffer buf[16384] is
  # class A): a CLASS_AB.tsv row naming a local a program fills keeps it IN the count, as a declared table stays in its count, and takes
  # it OUT of the guarded, dropping and no-guard terms, printed apart; a row naming a local the tree no longer declares is stale above.
  bf=$(cat "$BF")
  read -r fn fl fd fx fa <<<"$(awk -F'\t' 'FILENAME==ARGV[1] {if ($0 !~ /^#/ && NF >= 4) ab[$1 SUBSEP $2] = 1; next}
                                    FNR>1 && $3=="local" && $9=="" && $11!="" && $11 !~ /^B:/ {n++; if (($1 SUBSEP $4) in ab) a++; else if ($8=="LOUD" || $8=="GROW") l++; else if ($8=="DROP") d++; else x++}
                                    END {print n+0, l+0, d+0, x+0, a+0}' "$AB" "$T/c.tsv")"
  fk=$(awk -F'\t' 'NR>1 && $3=="local" && $11 ~ /^B:/' "$T/c.tsv" | wc -l)
  echo "function-scope arrays a program fills: $fn (baseline $bf) -- guarded by a loud refusal or a growth $fl, dropping at the cap $fd, with no guard $fx, declared class A or B by $AB $fa; fixed by construction and out (class B, read by machine): $fk"
  echo "function-scope arrays a program fills, unguarded: $((fd + fx))"
  if [ "$n" -gt "$base" ]; then echo "RED: the population of fixed tables grew from $base to $n -- a new fixed limit landed; make it dynamic or declare it class A/B on the page and lower nothing"; red=1; elif [ "$n" -lt "$base" ]; then echo "NOTE: $n is below the baseline $base -- lower BASELINE in the same landing (the ratchet only tightens)"; fi
  if [ "$fn" -gt "$bf" ]; then echo "RED: the function-scope population grew from $bf to $fn -- a new fixed local that a program fills landed; make it grow, and list it: python3 ../harness/scripts/audit_fixed_caps_census.py --tsv FILE (column fill)"; red=1; elif [ "$fn" -lt "$bf" ]; then echo "NOTE: the function-scope population $fn is below its baseline $bf -- lower BASELINE_FUNCTION_SCOPE in the same landing"; fi
  ;;
witness)
  # ⭐ THE WITNESS VERB (CEO-1231: the refusal read at cap+1). N = the census's LOUD guards (tables, arenas and the locals a program
  # fills) that CLASS_AB.tsv does not declare; each needs a WITNESSES.tsv row whose program reaches its cap+1 and whose run ends in
  # the row's rc with the row's refusal on stderr. SILENT: the run ended rc 0 past the cap and nothing refused. A row whose guard is no
  # longer LOUD (converted, or never) is STALE and RED. GREEN when K = N, silent 0 and nothing stale -- ⛔ 0 OF 0 IS GREEN (ceo CEO-1235
  # (1): a guard need not remain; every cap converted to growth is the row's end state), so an N of 0 is read only from a census that
  # classified guards at all: a census TSV whose guard column is empty everywhere REFUSES rather than reading a vacuous 0 of 0.
  SB="${SCRIP_BIN:-./scrip}"; [ -x "$SB" ] || { echo "REFUSE(2): no scrip binary at $SB"; exit 2; }
  WT="${DYN_CAPS_WITNESSES:-../harness/scripts/fixtures/dyn_caps/WITNESSES.tsv}"; [ -f "$WT" ] || { echo "REFUSE(2): no witness table at $WT"; exit 2; }
  AB="${DYN_CAPS_CLASS_AB:-../harness/scripts/fixtures/dyn_caps/CLASS_AB.tsv}"; [ -f "$AB" ] || { echo "REFUSE(2): no class A/B declaration at $AB"; exit 2; }
  [ "$(awk -F'\t' 'NR>1 && ($8=="LOUD"||$8=="GROW"||$8=="DROP"||$8=="NONE")' "$T/c.tsv" | wc -l)" -gt 0 ] || { echo "REFUSE(2): the census classified no guard at all -- a 0 of 0 read from it would be vacuous"; exit 2; }
  wbad=$(awk -F'\t' '!/^#/ && NF && (NF < 6 || $5 !~ /^[0-9]+$/ || $6 == "")' "$WT")
  [ -z "$wbad" ] || { echo "REFUSE(2): $WT rows that are not file<TAB>name<TAB>program<TAB>switches<TAB>rc<TAB>refusal:"; printf '%s\n' "$wbad" | cut -c1-160; exit 2; }
  awk -F'\t' 'FILENAME==ARGV[1] {if ($0 !~ /^#/ && NF >= 4) ab[$1 SUBSEP $2] = 1; next} FNR>1 && $8=="LOUD" && $9=="" && !(($1 SUBSEP $4) in ab) &&
      ($3=="file"||$3=="static"||$3=="field"||$3=="arena"||($3=="local" && $11!="" && $11 !~ /^B:/)) {print $1 "\t" $4}' "$AB" "$T/c.tsv" | sort -u > "$T/loud"
  N=$(wc -l < "$T/loud"); K=0; S=0; X=0
  while IFS=$'\t' read -r gf gn; do
    row=$(awk -F'\t' -v f="$gf" -v n="$gn" '!/^#/ && $1==f && $2==n' "$WT" | head -1)
    if [ -z "$row" ]; then echo "  NO WITNESS  $gf:$gn"; continue; fi
    # cut, not read: tab is IFS whitespace, so `read` collapses an EMPTY switches column and shifts every field after it
    prog=$(cut -f3 <<<"$row"); sw=$(cut -f4 <<<"$row"); wrc=$(cut -f5 <<<"$row"); refusal=$(cut -f6 <<<"$row")
    [ -f "$prog" ] || { echo "  NO PROGRAM  $gf:$gn -- $prog is not there"; continue; }
    timeout -k 5 300 "$SB" --run $sw "$prog" < /dev/null > "$T/w.out" 2> "$T/w.err"; rc=$?
    if [ "$rc" = "$wrc" ] && grep -qF -- "$refusal" "$T/w.err"; then K=$((K + 1)); echo "  READ        $gf:$gn rc=$rc: $(grep -F -- "$refusal" "$T/w.err" | head -1 | cut -c1-140)"
    elif [ "$rc" = 0 ]; then S=$((S + 1)); echo "  SILENT      $gf:$gn rc=0 -- the witness ran past the cap and nothing refused: $(head -c 100 "$T/w.out" | tr '\n' ' ')"
    else echo "  UNREAD      $gf:$gn rc=$rc (want $wrc): $(head -c 160 "$T/w.err" | tr '\n' ' ')"; fi
  done < "$T/loud"
  stale=$(awk -F'\t' 'FILENAME==ARGV[1] {have[$1 SUBSEP $2] = 1; next} !/^#/ && NF >= 6 && !(($1 SUBSEP $2) in have) {print "  STALE       " $1 ":" $2 " -- not a LOUD guard of this census"}' "$T/loud" "$WT")
  [ -z "$stale" ] || { printf '%s\n' "$stale"; X=$(printf '%s\n' "$stale" | grep -c .); }
  [ "$N" = 0 ] && echo "  no LOUD guard remains: every cap is converted to growth or declared class A/B (0 of 0 is GREEN, ceo CEO-1235 (1))"
  echo "refusal read at the cap: $K of $N guards, silent: $S"
  { [ "$K" = "$N" ] && [ "$S" = 0 ] && [ "$X" = 0 ]; } || red=1
  ;;
*) echo "REFUSE(2): unknown mode $mode"; exit 2;;
esac
[ "$red" = 0 ] && echo "GREEN [$mode]" || echo "RED [$mode]"
exit $red
