#!/usr/bin/env bash
# test_gate_delimited_aggregate_census_ratchet.sh -- THE DELIMITED-AGGREGATE RATCHET: the population of separator-joined value
# sites in src/ may only fall, and a fall lowers the baseline in the same landing (RULES.md FACT RULE NO DELIMITER-JOINED
# AGGREGATES; Lon 2026-09-28 08:5x CDT, in-chat to hq_pascal, verbatim: "What are seperator bytes? Are you storing data as tag
# delimited strings? Where are you doing that crazy thing?" · "Do not store records like that." · "Get rid of ALL delimited based
# processing like the one I just discovered."; ceo CEO-1349; row instruments-the-delimited-aggregate-census-ratchets-to-zero-..., the cfo).
#
# THE POPULATION is audit_delimited_aggregates_census.py's member sites -- every line where a value is joined by, split on or
# tagged with a separator byte (a control-byte literal or a macro the tree defines as one: SOH, RK_A1, RK_RX, RK_TY, STX, MON_RS,
# MON_US on 2026-09-28), attributed to its file, enclosing function and, inside the by-name dispatcher, the builtin name the
# nearest strcmp(fn, "...") above it names -- counted PER CARRIER (PASCAL, RAKU, REGISTRY_KEY, OTHER) against
# ../harness/scripts/fixtures/delimited/BASELINE.tsv. The NON-MEMBERS are declared in ../harness/scripts/fixtures/delimited/NON_MEMBERS.tsv with their
# reasons (x86_asm.h's TEXT-medium port mark, the monitor's wire separators, rt.c's unloaded-procedure sentinel), printed every
# run and counted separately -- never silently exempt, Lon may overrule any of them; whole-byte tables (eight or more distinct
# byte escapes on one line) are set aside by rule and printed. src/runtime/aggregates.c's \001-tagged registry keys are MEMBERS
# (CEO-1350, the cfo's view adopted): a value serialised into a string with a control byte is the class.
# ⛔ NO BINARY IS READ: this gate is a census of source text and needs no build, so it does not go through util_require_fresh.sh.
#
# ARMS:
#   1 the census's own selftest: every declared form is counted once by carrier, kind and anchor, and the comment, the name string,
#     the whole-byte table, the generated file, the definition and the declared non-member are each refused or set aside by NAME
#   2 the real tree reads EXACTLY the baseline per carrier: above it a separator-joined value landed (make it typed storage, or
#     declare a non-member with its reason for Lon's judgement); below it sites were converted and BASELINE is lowered to the new
#     count IN THE SAME LANDING, so the ratchet keeps the fall
#   3 FAIL-ONCE BUILT IN: a scratch copy of src/ with ONE planted joined-value site reads RED against the baseline, grown by
#     exactly one from the UNPLANTED count in OTHER -- judged against the tree's own count, not against BASELINE+1
#   4 THE NON-MEMBERS ARE CARRIED, NOT HIDDEN: every declared row still matches a line (a row whose site is gone reads STALE and
#     reds), and the report prints each one with its reason, so the exemption is read every run
#   5 THE ANCHOR CLASSIFIER CAN RED: a scratch dispatcher with one site under a __pas_ name and one under an __rk_ name reads
#     PASCAL 1 and RAKU 1, never OTHER
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
C="$ROOT/../harness/scripts/audit_delimited_aggregates_census.py"; B="$ROOT/../harness/scripts/fixtures/delimited/BASELINE.tsv"; NM="$ROOT/../harness/scripts/fixtures/delimited/NON_MEMBERS.tsv"
for f in "$C" "$B" "$NM"; do [ -s "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing $f"; exit 2; }; done
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
if python3 "$C" --selftest > "$T/self.txt" 2>&1; then echo "  arm 1 PASS: $(tail -1 "$T/self.txt" | cut -c1-140)"; else echo "  arm 1 FAIL: the census selftest reds -- $(grep -m1 FAIL "$T/self.txt" | cut -c1-200)"; RC=1; fi
python3 "$C" --dir "$ROOT/src" --non-members "$NM" --baseline "$B" --tsv "$T/real.tsv" > "$T/real.txt" 2>&1; r=$?
head -1 "$T/real.txt" | cut -c1-220
if [ $r -eq 0 ]; then echo "  arm 2 PASS: the tree reads exactly the baseline per carrier -- $(grep -E '^  (PASCAL|RAKU|REGISTRY_KEY|OTHER) +[0-9]+ = baseline' "$T/real.txt" | awk '{printf "%s %s  ", $1, $2}')"
else echo "  arm 2 FAIL: the census does not read the baseline"; grep -E 'RED|LOWER|STALE' "$T/real.txt" | cut -c1-220; RC=1; fi
cnt_other=$(awk -F'\t' 'NR>1 && $4=="OTHER"' "$T/real.tsv" | wc -l)
mkdir -p "$T/plant" && cp -rL "$ROOT/src" "$T/plant/src" && printf 'static char *planted_join(char *buf, const char *a, const char *b) { size_t n = strlen(a); memcpy(buf, a, n); buf[n] = %s; strcpy(buf + n + 1, b); return buf; }\n' "'\\x01'" > "$T/plant/src/runtime/planted_delimited_site.c"
python3 "$C" --dir "$T/plant/src" --non-members "$NM" --baseline "$B" --tsv "$T/plant.tsv" > "$T/plant.txt" 2>&1; pr=$?
p_other=$(awk -F'\t' 'NR>1 && $4=="OTHER"' "$T/plant.tsv" | wc -l)
if [ $pr -eq 1 ] && [ "$p_other" -eq $((cnt_other + 1)) ] && grep -q 'planted_delimited_site.c.*planted_join' "$T/plant.txt"; then echo "  arm 3 PASS: the planted joined-value site reads RED against the baseline, OTHER $cnt_other -> $p_other, named by file and function"
else echo "  arm 3 FAIL: the plant did not red (rc=$pr, OTHER $cnt_other -> $p_other) -- the ratchet cannot see a new separator-joined value"; RC=1; fi
nnm=$(grep -cE '^  [a-z].*:[0-9]+ .* -- ' "$T/real.txt"); nst=$(grep -c 'STALE NON-MEMBER' "$T/real.txt"); ndecl=$(grep -vc '^#\|^$' "$NM")
if [ "$nst" -eq 0 ] && [ "$nnm" -ge "$ndecl" ]; then echo "  arm 4 PASS: $ndecl declared non-member row(s), each still matching a line, $nnm site(s) printed with their reasons (none hidden)"
else echo "  arm 4 FAIL: non-members stale=$nst printed=$nnm declared=$ndecl -- an exemption nobody reads is a hole"; RC=1; fi
mkdir -p "$T/anch/src/runtime" && printf '#define SOH %s\nstatic int script_try_call_builtin_by_name(const char *fn, const char *s) {\n    if (!strcmp(fn, "__pas_rec_get")) { return s[0] == SOH; }\n    if (!strcmp(fn, "__rk_arr_at")) { return strchr(s, SOH) != 0; }\n    return 0;\n}\n' "'\\x01'" > "$T/anch/src/runtime/by_name_dispatch.c"
python3 "$C" --dir "$T/anch/src" --tsv "$T/anch.tsv" > /dev/null 2>&1
a_pas=$(awk -F'\t' 'NR>1 && $4=="PASCAL"' "$T/anch.tsv" | wc -l); a_rk=$(awk -F'\t' 'NR>1 && $4=="RAKU"' "$T/anch.tsv" | wc -l); a_ot=$(awk -F'\t' 'NR>1 && $4=="OTHER"' "$T/anch.tsv" | wc -l)
if [ "$a_pas" -eq 1 ] && [ "$a_rk" -eq 1 ] && [ "$a_ot" -eq 0 ]; then echo "  arm 5 PASS: the anchor classifier attributes a site under __pas_rec_get to PASCAL and under __rk_arr_at to RAKU (PASCAL=$a_pas RAKU=$a_rk OTHER=$a_ot)"
else echo "  arm 5 FAIL: the anchor classifier reads PASCAL=$a_pas RAKU=$a_rk OTHER=$a_ot, want 1 1 0"; RC=1; fi
echo "population: 5 arm(s) graded"
[ $RC -eq 0 ] && echo "GATE PASS [$G]" || echo "GATE FAIL [$G]"
exit $RC
