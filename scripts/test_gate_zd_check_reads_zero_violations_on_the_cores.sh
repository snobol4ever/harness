#!/usr/bin/env bash
# test_gate_zd_check_reads_zero_violations_on_the_cores.sh -- THE PLAN IS CONSISTENT ON EVERY MASTER'S CORE (ceo CEO-1830,
# ARCH-ZETA-ONE-COORDINATE.md section 4). For each of the seven masters it extracts every PARTITION.tsv core entry, compiles
# it with SCRIP_ZD_CHECK=1 (mode 4, asm to scratch, nothing linked or run) and sums the verifier's violations: the three edge
# laws in the absolute coordinate and the staging reads across runs with an unknown base. A graph with violations=0 has a
# consistent depth plan; a red program whose graphs read 0 is a template or runtime defect, not a placement one.
# PRINTS one board line per language and a total:
#   ZD_CHECK_BOARD lang=<l> entries=<n> compiled=<c> graphs=<g> violations=<v> worst=<entry:v>
#   ZD_CHECK_TOTAL languages=7 entries=<n> compiled=<c> graphs=<g> violations=<v>
# THE VERDICT COUNTS ONLY GRAPHS IN THE ABSOLUTE COORDINATE (today Prolog and Icon, zd_pl_abs()): a relative graph's count is
# REPORTED beside it, because the verifier does not yet know the SNOBOL4 pattern boxes' conventions (the match frame extra,
# the FENCE release, the match-end restore), so a green language reads false violations there -- measured 2026-10-18 at
# 5c37a2dee: SNOBOL4 65 relative over 25 compiled core entries while every one of them passes; a count that cannot tell a defect
# from the verifier's own gap is a ledger line, never a verdict. As a language gains the absolute coordinate its count enters
# the verdict (ARCH-ZETA-ONE-COORDINATE.md section 5, the ceo's fourth landing). THE RELATIVE COUNTS ARE A RATCHET meanwhile:
# RELATIVE_FLOOR below is each language's relative count at the ceo's cut of hq_zetas's two zd_plan branches (2026-10-18 12:4x CDT:
# snobol4 0, rebus 0, raku 0, pascal 0, snocone 3; was pascal 8, snocone 7 at dda4f93ff), and a language reading above its floor is RED (RELATIVE-OVER-FLOOR) -- a
# planner change that breaks a green language's plan trips here the same tick; a floor may only fall, by editing this table in
# the landing that lowers the count. snocone falls to 0 with hq_zetas's item-1 branch (every graph on the absolute coordinate; an omega
# into MATCH_BEGIN read as the FENCE abort it is, a discard), cut by the ceo with its SCRIP half.
# compiled=<c> below entries=<n> names the core entries the gate could not cut standalone. Until 2026-10-24 that was SNOBOL4's eight
# stdin-carrying entries (porter, claws5, treebank, json and user_function_fence_span_replace_branch_1): the extractor REFUSES an entry
# that carries stdin unless --out-in names where it goes, and the gate passed none, so eight plans went unread (hq_snobol4, CEO-1962);
# the extract now writes the stdin beside the source, compiling reads none of it, and SNOBOL4 compiles 31 of 31.
# rc 0 total violations 0 over every core; rc 1 a violation; rc 2 cannot measure (no scrip, a master without a partition,
# a language whose core compiled 0 entries). --lang <l> limits it to one language (a seat's handful; the board is the coo's).
# Fail-once: ARCH-ZETA-ONE-COORDINATE.md section 4 and the ceo's ledger record the Icon core reading violations at 6d138d652.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" 2>/dev/null && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
CORPUS="$(cd "$HERE/../../corpus" 2>/dev/null && pwd)" || { echo "REFUSE(2): no corpus beside harness"; exit 2; }
[ -x "$SCRIP/scrip" ] || { echo "REFUSE(2): $SCRIP/scrip is not built"; exit 2; }
ONLY=""; while [ $# -gt 0 ]; do case "$1" in --lang) ONLY="$2"; shift;; *) echo "REFUSE(2): unknown argument $1"; exit 2;; esac; shift; done
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_zdcheck.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
declare -A RELATIVE_FLOOR=( [snobol4]=0 [icon]=0 [prolog]=0 [raku]=0 [rebus]=0 [pascal]=0 [snocone]=0 )
rc=0; TN=0; TC=0; TG=0; TV=0; TR=0; NL=0
for pair in snobol4:sno icon:icn prolog:pl raku:raku pascal:pas snocone:sc rebus:reb; do
    lang="${pair%%:*}"; ext="${pair##*:}"
    [ -z "$ONLY" ] || [ "$ONLY" = "$lang" ] || continue
    D="$CORPUS/tests/$lang"
    [ -f "$D/PARTITION.tsv" ] && [ -f "$D/ALL.$ext" ] && [ -f "$D/ALL.ref" ] || { echo "REFUSE(2): $D has no PARTITION.tsv or ALL.$ext"; exit 2; }
    n=0; c=0; g=0; ga=0; v=0; vr=0; worst=""; wv=0
    while IFS=$'\t' read -r entry cls rest; do
        case "$entry" in ''|'#'*|entry) continue;; esac
        [ "$cls" = "core" ] || continue
        n=$((n+1))
        src="$W/$lang.$n.$ext"
        python3 "$HERE/corpus_suite_harness.py" extract "$D/ALL.$ext" "$D/ALL.ref" "$entry" "$src" --out-ref "$W/$lang.$n.ref" --out-in "$W/$lang.$n.in" > /dev/null 2>&1 || continue
        [ -s "$src" ] || continue
        out="$( cd "$SCRIP" && SCRIP_ZD_CHECK=1 timeout -k 2 60 ./scrip --compile --out="$W/$lang.$n.s" "$src" < /dev/null 2>&1 >/dev/null | grep '^\[ZD-CHECK\]' )"
        c=$((c+1))
        eg="$(printf '%s\n' "$out" | grep -c ' violations=')"
        ea="$(printf '%s\n' "$out" | grep -c ' coordinate=absolute ')"
        ev="$(printf '%s\n' "$out" | grep ' coordinate=absolute ' | sed -n 's/.* violations=\([0-9][0-9]*\).*/\1/p' | awk '{s+=$1} END{print s+0}')"
        erl="$(printf '%s\n' "$out" | grep ' coordinate=relative ' | sed -n 's/.* violations=\([0-9][0-9]*\).*/\1/p' | awk '{s+=$1} END{print s+0}')"
        er="$(printf '%s\n' "$out" | grep -c '^\[ZD-CHECK\]   READ ')"
        ev=$((ev+er))
        g=$((g+eg)); ga=$((ga+ea)); v=$((v+ev)); vr=$((vr+erl))
        if [ "$ev" -gt "$wv" ]; then wv=$ev; worst="$entry:$ev"; fi
    done < "$D/PARTITION.tsv"
    [ "$c" -gt 0 ] || { echo "REFUSE(2): $lang core compiled 0 entries of $n"; exit 2; }
    floor="${RELATIVE_FLOOR[$lang]:-0}"; over=0; [ "$vr" -le "$floor" ] || over=1
    echo "ZD_CHECK_BOARD lang=$lang entries=$n compiled=$c graphs=$g absolute=$ga violations=$v worst=${worst:--} relative_reported=$vr relative_floor=$floor$( [ "$over" = 1 ] && echo ' RELATIVE-OVER-FLOOR' )"
    NL=$((NL+1)); TN=$((TN+n)); TC=$((TC+c)); TG=$((TG+g)); TV=$((TV+v)); TR=$((TR+vr))
    [ "$v" -eq 0 ] && [ "$over" = 0 ] || rc=1
done
echo "ZD_CHECK_TOTAL languages=$NL entries=$TN compiled=$TC graphs=$TG violations=$TV relative_reported=$TR"
[ "$rc" -eq 0 ] && echo "GATE OK [zd_check_reads_zero_violations_on_the_cores]: every core graph's depth plan is consistent" || echo "GATE RED [zd_check_reads_zero_violations_on_the_cores]: $TV violation(s) -- the lines above name the worst entry per language; SCRIP_ZD_CHECK=1 ./scrip --compile <entry> prints each edge"
exit $rc
