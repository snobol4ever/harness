#!/bin/bash
# test_gate_a_port_answers_in_sbls_voice_and_reads_its_own_exclusions.sh -- THE THREE HARNESS EDITS OF CEO-1864 (the ceo to hq_dotnet 2026-10-21, the six asks
# granted; landed by the coo on CEO-1872, the coo grades the port engines). (1) "Give a mask row an engine qualifier and have the reader skip a scrip-only row
# for another engine." (3) "A port engine's compile-refusal arm compares stdout with sbl's, and yes, exit 231 after a compile error as sbl does" -- with
# CEO-1858 (2), "The error report and compile errors go to stdout, where sbl writes them", the run-time error arm too. (4) "Admit LON_UNICODE_BY_DESIGN in
# lib_excluded.sh only on an engine-keyed list, EXCLUDED.dotnet.tsv beside the package's EXCLUDED.tsv, read only when S4E_ENGINE is dotnet."
# Hermetic, no build, nothing live: scratch mask files, streams, exclusion lists, a scratch corpus and progress DB.
# ARMS: (1) a mask row with engine=scrip is offered under scrip and skipped under S4E_ENGINE=dotnet; an unqualified row is offered to both. (2) a fourth
# column naming no engine, or not engine=NAME, refuses rc 2. (3) gate_port_answer_matches passes sbl's error report on stdout when only its accounting lines
# differ (execution time, memory used and left) and both rcs are sbl's. (4) it fails when the rcs differ (a port exiting 0 where sbl exits 231). (5) it fails
# when a line of the program's answer differs. (6) accounting-shaped lines with no ERROR banner before them are compared, not dropped. (7) lib_excluded.sh
# reads EXCLUDED.dotnet.tsv under S4E_ENGINE=dotnet and not under scrip or jvm. (8) LON_UNICODE_BY_DESIGN is refused rc 2 on EXCLUDED.tsv and on
# EXCLUDED.jvm.tsv. (9) util_score_row.py from-progress leaves a port key's engine list out of its denominator, a name both lists carry counted once in
# Excl, and the SCRIP key reads EXCLUDED.tsv alone. (10) the x64 and x32 runners offer gate_port_answer_matches after SCRIP's arm and only under a port
# engine, and the testpgms compile-refusal arm grades a port by it. (11) the snoflake runner recovers a port's &DUMP termination dump from the
# port's own listing sink, as it recovers sbl's from $SBL_SINK (hq_dotnet 2026-10-22: snobol4dotnet takes the sink as -o= and writes the dump there).
# PROVEN TO FAIL on harness origin 6a20d66 (this gate copied beside its scripts): arms 1, 2, 3, 7, 8, 9 and 10 FAIL (no qualifier: the scrip-only row is
# offered to dotnet and the fourth column is ignored; no gate_port_answer_matches; no engine list is read, so none refuses). Arm 9 alone FAILS on these
# edits with the shared-name dedupe taken out of from-progress (2/2 excluded=3: b counted from both lists).
# Arm 11 FAILS on harness origin 601a389 (no dump_tail: a port's dump stays in its sink and dump-ordered@dotnet read FAIL rc=0 vs sbl -bf).
set -u
H="$(cd "$(dirname "$0")" && pwd)"; G=a_port_answers_in_sbls_voice_and_reads_its_own_exclusions; fail=0; examined=0
for f in corpus_suite_harness.py lib_gate.sh lib_excluded.sh util_score_row.py test_snobol4_spitbol_x64_suite.sh test_snobol4_spitbol_x32_suite.sh test_snobol4_spitbol_testpgms_suite.sh test_snoflake_suite.sh; do
  [ -f "$H/$f" ] || { echo "REFUSE(2) [$G]: no $H/$f"; exit 2; }
done
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
arm() { examined=$((examined+1)); if eval "$2"; then echo "  ok   $1"; else echo "  FAIL $1"; fail=$((fail+1)); fi; }
masks() { env -u S4E_ENGINE ${1:+S4E_ENGINE=$1} python3 -c "import sys; sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h; m = h.read_mask_sidecar(sys.argv[2]); print(' '.join('%s:%d' % (k, len(v)) for k, v in sorted(m.items())))" "$H" "$2" 2>&1; }
mkdir -p "$T/m"; printf 'p\t^x$\tCEO-1293 a kept enhancement the oracle lacks, the reason of a scrip-only row\tengine=scrip\nq\t^y$\tan implementation clock no program computes\n' > "$T/m/ALL.mask"
arm "(1) engine=scrip is SCRIP's row alone; an unqualified row is every engine's" '[ "$(masks "" "$T/m/ALL.ref")" = "p:1 q:1" ] && [ "$(masks dotnet "$T/m/ALL.ref")" = "q:1" ]'
mkdir -p "$T/m2" "$T/m3"; printf 'p\t^x$\ta reason long enough to audit\tengine=nosuch\n' > "$T/m2/ALL.mask"; printf 'p\t^x$\ta reason long enough to audit\tdotnet\n' > "$T/m3/ALL.mask"
masks "" "$T/m2/ALL.ref" > /dev/null; r2a=$?; masks "" "$T/m3/ALL.ref" > /dev/null; r2b=$?
arm "(2) a fourth column naming no engine, or not engine=NAME, refuses rc 2" '[ $r2a = 2 ] && [ $r2b = 2 ]'
. "$H/lib_gate.sh"
pm() {  # pm <file> <ms> <used> <left> [answer]: an sbl-shaped run-time error report on stdout
  printf '%s\n\n\n\nx.sbl(12) : ERROR 235 -- subscripted operand is not table or array\n\n\n\n\n\nin file              x.sbl\nin line              12\nin statement         8\nstmts executed       86\nexecution time msec  %s\nREGENERATIONS        0\nmemory used (bytes)  %s\nmemory left (bytes)  %s\n\n' "${5:-sort by character code}" "$2" "$3" "$4" > "$1"; }
pm "$T/o" 0 23320 1025248; pm "$T/d" 57 41918464 32220409856; pm "$T/e" 0 23320 1025248 "sort by character kode"
arm "(3) sbl's error report on stdout passes when only the accounting differs and both rcs are sbl's" 'gate_port_answer_matches "$T/o" "$T/d" 0 0 && gate_port_answer_matches "$T/o" "$T/d" 231 231'
arm "(4) a port exiting with another rc than sbl's fails" '! gate_port_answer_matches "$T/o" "$T/d" 231 0'
arm "(5) a line of the program's answer that differs fails" '! gate_port_answer_matches "$T/o" "$T/e" 0 0'
printf 'memory used (bytes)  10\n' > "$T/a1"; printf 'memory used (bytes)  11\n' > "$T/a2"
arm "(6) accounting-shaped lines with no ERROR banner before them are compared" '! gate_port_answer_matches "$T/a1" "$T/a2" 0 0'
mkdir -p "$T/x"; ev="$(printf 'e%.0s' $(seq 70))"
printf 'a.sno\tNO_ORACLE_ANSWER\t%s\n' "$ev" > "$T/x/EXCLUDED.tsv"; printf '8bit.sno\tLON_UNICODE_BY_DESIGN\t%s\n' "$ev" > "$T/x/EXCLUDED.dotnet.tsv"
xs() { ( unset S4E_ENGINE; [ -n "$1" ] && export S4E_ENGINE="$1"; . "$H/lib_excluded.sh"; inventory_excluded_names "$2" 2>/dev/null | tr '\n' ' '; exit "${PIPESTATUS[0]}" ); }
arm "(7) EXCLUDED.dotnet.tsv is read under dotnet alone" '[ "$(xs dotnet "$T/x")" = "a.sno 8bit.sno " ] && [ "$(xs "" "$T/x")" = "a.sno " ] && [ "$(xs jvm "$T/x")" = "a.sno " ]'
mkdir -p "$T/y" "$T/z"; printf '8bit.sno\tLON_UNICODE_BY_DESIGN\t%s\n' "$ev" > "$T/y/EXCLUDED.tsv"; cp "$T/x/EXCLUDED.dotnet.tsv" "$T/z/EXCLUDED.jvm.tsv"
xs "" "$T/y" > /dev/null; r8a=$?; xs jvm "$T/z" > /dev/null; r8b=$?
arm "(8) LON_UNICODE_BY_DESIGN refuses rc 2 on EXCLUDED.tsv and on another engine's list" '[ $r8a = 2 ] && [ $r8b = 2 ]'
P="$T/corpus/packages/snobol4/zzpkg"; mkdir -p "$P"
for n in a b c d; do printf "        OUTPUT = '%s'\nEND\n" "$n" > "$P/$n.sno"; done
printf 'rank,entry,origin\n1,a,x\n2,b,x\n3,c,x\n4,d,x\n' > "$P/ALL.csv"
printf 'b.sno\tNO_ORACLE_ANSWER\t%s\n' "$ev" > "$P/EXCLUDED.tsv"; printf 'c.sno\tLON_UNICODE_BY_DESIGN\t%s\nb.sno\tLON_UNICODE_BY_DESIGN\t%s\n' "$ev" "$ev" > "$P/EXCLUDED.dotnet.tsv"
DB="$T/results.tsv"; printf 'ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\tfingerprint\tconfig\n' > "$DB"
row() { printf '2026-10-22T05:00:%02d\tabc1234\tc0ffee0\tcoo\tpackage\t%s\tsnobol4\t%s\t%s\t%s\t1.0\t\t\t\n' "$1" "$2" "$3" "$4" "$5" >> "$DB"; }
row 1 zzpkg@dotnet a m3 PASS; row 2 zzpkg@dotnet c m3 FAIL; row 3 zzpkg@dotnet d m3 PASS
row 4 zzpkg a m3 PASS; row 5 zzpkg a m4 PASS; row 6 zzpkg c m3 PASS; row 7 zzpkg c m4 PASS; row 8 zzpkg d m3 PASS; row 9 zzpkg d m4 PASS
o9a="$(S4E_CORPUS_ROOT="$T/corpus" S4E_PROGRESS_DB="$DB" python3 "$H/util_score_row.py" from-progress --suite zzpkg@dotnet --dry-run 2>&1)"
o9b="$(S4E_CORPUS_ROOT="$T/corpus" S4E_PROGRESS_DB="$DB" python3 "$H/util_score_row.py" from-progress --suite zzpkg --dry-run 2>&1)"
arm "(9) from-progress: zzpkg@dotnet is 2/2 excluded=2 (b once, c by the engine list); zzpkg is 3/3 excluded=1" 'grep -q "would set zzpkg@dotnet -> 2/2 excluded=2 " <<<"$o9a" && grep -q "would set zzpkg -> 3/3 excluded=1 " <<<"$o9b"'
wired() { grep -qF '    gate_oracle_stdout_match "$W/o.cmp" "$W/$1.cmp" "$W/$1.err" "$2" && return 0' "$1" && grep -qF '    [ "$PORT" = 1 ] && gate_port_answer_matches "$W/o.cmp" "$W/$1.cmp" "$rcO" "$2"' "$1"; }
arm "(10) x64 and x32 offer the port arm after SCRIP's and only under a port engine; testpgms grades a port's compile refusal by it" 'wired "$H/test_snobol4_spitbol_x64_suite.sh" && wired "$H/test_snobol4_spitbol_x32_suite.sh" && grep -qF '"'"'&& gate_port_answer_matches "$ora.pm" "$m3.pm" "$orc" "$r3" && _pa=1'"'"' "$H/test_snobol4_spitbol_testpgms_suite.sh"'
arm "(11) snoflake recovers a port's dump from the port's own sink, and sbl's from its sink, by the one dump_tail" 'grep -qF '"'"'[ "$PORT" = 1 ] && [ -n "$SCRIP_LIST_SINK" ] && { GOT="${GOT}$(dump_tail "$2" "$SCRIP_LIST_SINK"; printf .)"'"'"' "$H/test_snoflake_suite.sh" && grep -qF '"'"'GOT="${GOT}$(dump_tail "$2" "${SBL_SINK#-o=}.lst"; printf .)"'"'"' "$H/test_snoflake_suite.sh"'
[ "$fail" = 0 ] || { printf '%s\n' "$o9a" | grep -E 'would set|REFUSE' | head -2; printf '%s\n' "$o9b" | grep -E 'would set|REFUSE' | head -2; }
echo "GATE [$G] examined=$examined failed=$fail"
[ $fail = 0 ] || { echo "RED [$G]"; exit 1; }
echo "PASS [$G]"
