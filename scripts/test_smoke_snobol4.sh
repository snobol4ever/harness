#!/usr/bin/env bash
# test_smoke_snobol4.sh — SNOBOL4 smoke, modes 3 + 4
# Gate: mode-4 HARD. Mode 3 informational (PASS/FAIL reported, does not block).
# NOTE (2026-06-15): the IR-graph interpreter (mode 2 / --run) was DELETED — the harness no longer invokes it.
# AUTHORS: Lon Jones Cherryholmes · Jeffrey Cooper M.D. · Claude Sonnet 4.6  DATE: 2026-06-08 (de-interp'd 2026-06-15)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${HERE}/../../SCRIP/scrip"
OUTDIR="${HERE}/../../SCRIP/out"
P3=0; F3=0; P4=0; F4=0

run_m3() {
    local label="$1" src="$2" expected="$3"
    local tmp; tmp=$(mktemp /tmp/sno_XXXXXX.sno)
    printf '%s\n' "$src" > "$tmp"
    local actual; actual=$(timeout -k 5 8 "$SCRIP" --run "$tmp" < /dev/null 2>/dev/null)
    rm -f "$tmp"
    if [ "$actual" = "$expected" ]; then
        P3=$((P3+1))
    else
        echo "  FAIL-M3 $label (got: $(printf '%s' "$actual" | head -1))"; F3=$((F3+1))
    fi
}

run_m4() {
    local label="$1" src="$2" expected="$3"
    local tmp; tmp=$(mktemp /tmp/sno_XXXXXX.sno)
    printf '%s\n' "$src" > "$tmp"
    local s o bin
    s=$(mktemp /tmp/sno_XXXXXX.s); o="${s%.s}.o"; bin="${s%.s}.bin"
    local actual
    if timeout -k 5 8 "$SCRIP" --compile --target=x86 "$tmp" < /dev/null > "$s" 2>/dev/null \
       && as "$s" -o "$o" 2>/dev/null \
       && gcc -no-pie "$o" -L"$OUTDIR" -lscrip_rt -Wl,-rpath,"$OUTDIR" \
              -Wl,--allow-shlib-undefined -lm -o "$bin" 2>/dev/null; then
        actual=$(timeout -k 5 8 "$bin" < /dev/null 2>/dev/null)
    else
        actual="<mode4-build-failed>"
    fi
    rm -f "$tmp" "$s" "$o" "$bin"
    if [ "$actual" = "$expected" ]; then
        echo "  PASS $label"; P4=$((P4+1))
    else
        echo "  FAIL $label (got: $(printf '%s' "$actual" | head -1))"; F4=$((F4+1))
    fi
}

run_all() {
    local label="$1" src="$2" expected="$3"
    run_m3 "$label" "$src" "$expected"
    run_m4 "$label" "$src" "$expected"
}

T0=$SECONDS
echo "=== SNOBOL4 smoke (modes 3+4) — mode-4 HARD GATE ==="

run_all "output"  "        OUTPUT = 'hello'
END" "hello"

run_all "concat"  "        OUTPUT = 'ab' 'cd'
END" "abcd"

run_all "arith"   "        OUTPUT = 2 + 3
END" "5"

run_all "pattern" "        S = 'abc'
        S 'b' = 'X'
        OUTPUT = S
END" "aXc"

run_all "goto_s"  "        'x' 'x'  :S(HIT)
        OUTPUT = 'miss'
        :(END)
HIT     OUTPUT = 'hit'
END" "hit"

# ⛔ THE BARE `RETURN` LINE WAS A BUG IN THIS TEST, NOT IN SCRIP (s183, HQ Fable; queue row smoke-define, red since s169).
# It read `DOUBLE  DOUBLE = X + X` / `        RETURN` -- but a bare `RETURN` is NOT a return in SNOBOL4, it is a
# subject-only statement evaluating a variable named RETURN.  A function returns by TRANSFERRING to the RETURN label:
# `:(RETURN)`.  ORACLE RECEIPT, byte-compared with od: on the OLD program the live sbl oracle emits ZERO BYTES and so
# does SCRIP -- BYTE-IDENTICAL, i.e. SCRIP was right and the expectation "42" was the defect, a false red standing on
# the mode-4 HARD GATE for 14 sessions.  On the corrected program both engines emit "42\n" (m3 and m4 both verified).
run_all "define"  "        DEFINE('DOUBLE(X)')
        OUTPUT = DOUBLE(21)
        :(END)
DOUBLE  DOUBLE = X + X    :(RETURN)
END" "42"

run_all "arith_sm" "        OUTPUT = 2 + 3
END" "5"

# CORE ARM (ceo CEO-1952; Lon 2026-10-24: "Let's get better smoke tests for SNOBOL4, it keeps missing a lot."): the hand cases above missed 8 SnoRungs
# core crashes and 105 pattern-shell reds on main that day (521c5afcd, 8eb445d88). The arm grades the SnoRungs PARTITION core -- every distinctive
# feature three times -- plus the FENCE/ARBNO/BAL witnesses that crashed then, through the one extraction authority in BOTH modes, HARD in both, with
# the declared heap, stack, stdin and argv; progress off, so it writes no results row.
FRAGILE="arbno_fence_bal_branch_1 arbno_fence_bal_replace_branch_2 arbno_fence_pos_branch_18 arbno_fence_pos_branch_28 arbno_arb_rpos_replace_branch_1 fence_tab_pos_branch_2 user_function_fence_tab_branch_1 user_function_eval_arbno_replace_branch_2"
CORE_PARTS="core$(for e in $FRAGILE; do printf ',entry:%s' "$e"; done)"
CT="${HERE}/../../corpus/tests/snobol4"
COUT="$(cd "${HERE}/../../SCRIP" && S4E_PROGRESS_OFF=1 SUITE_LIST_ALL=1 S4E_SMOKE_CORE_ARM="test_smoke_snobol4.sh (CEO-1952)" timeout -k 5 300 python3 "${HERE}/corpus_suite_harness.py" run "$CT/ALL.sno" "$CT/ALL.ref" --lang snobol4 --modes m3,m4 --partition "$CORE_PARTS" 2>&1)"
CB="$(printf '%s\n' "$COUT" | grep -m1 '^SUITE_BOARD')"
[ -n "$CB" ] || { printf '%s\n' "$COUT" | tail -3 | sed 's/^/  /'; echo "core arm REFUSE(2): the harness printed no SUITE_BOARD line"; exit 2; }
cv() { printf '%s\n' "$CB" | grep -oE " $1=[0-9]+" | head -1 | cut -d= -f2; }
CN3=$(cv m3_n); CP3=$(cv m3_pass); CN4=$(cv m4_n); CP4=$(cv m4_pass); CF3=$((CN3-CP3)); CF4=$((CN4-CP4))
printf '%s\n' "$COUT" | grep -E '^ +(FAIL|CRASH|HANG|UNPROVEN) m[34] ' | sed 's/^ */  CORE-/'
TT=$((SECONDS-T0))
echo ""
echo "mode-3 (--run):     PASS=$P3 FAIL=$F3"
echo "mode-4 (--compile): PASS=$P4 FAIL=$F4   (HARD GATE)"
echo "core arm (SnoRungs core + $(echo $FRAGILE | wc -w) fragile, $CN4 entries): m3 PASS=$CP3 FAIL=$CF3  m4 PASS=$CP4 FAIL=$CF4   (HARD GATE, both modes)"
echo "PASS=$P4 FAIL=$F4"
printf "TIME TOTAL=%ds\n" "$TT"

[ "$F4" -eq 0 ] && [ "$CF3" -eq 0 ] && [ "$CF4" -eq 0 ]
