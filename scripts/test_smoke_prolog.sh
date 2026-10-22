#!/usr/bin/env bash
# test_smoke_prolog.sh — per-frontend smoke for Prolog, run in ALL THREE modes.
#   mode 2 = --run                   (BB port-graph oracle)  — HARD GATE: must be all-PASS.
#   mode 3 = --run                      (stackless native)      — TRACKED: REFUSED until GZ regrows it.
#   mode 4 = --compile --target=x86     (emit→assemble→link→run via run_prolog_via_x86_backend.sh)
#                                                                — TRACKED: REFUSED until BB-native x86 emit returns.
# GOAL-PROLOG-BB mandates running ALL modes on every smoke (see GOAL "Testing discipline").
# A mode that prints the Stack-Machine-eXcision banner is reported REFUSED (expected mid-Ground-Zero), not FAIL,
# and auto-starts counting PASS/FAIL the moment it emits real output. Exit 0 iff mode 2 is all-PASS.
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet 4.6 · Claude Sonnet  DATE: 2026-05-31
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
SMX_SIG='\[SMX\]'                       # both refuse banners begin with "[SMX]"
P2=0; F2=0; P3=0; F3=0; X3=0; P4=0; F4=0; X4=0; N=0

pl() {
    local label="$1" expected="$2"
    local tmp; tmp=$(mktemp /tmp/pl_XXXXXX.pl)
    cat > "$tmp"
    N=$((N+1))
    local r2 r3 r4

    # mode 2 — --run (HARD GATE)
    local a2; a2=$(timeout -k 5 8 "$SCRIP" --run "$tmp" 2>/dev/null </dev/null)
    if [ "$a2" = "$expected" ]; then r2="m2 PASS"; P2=$((P2+1)); else r2="m2 FAIL"; F2=$((F2+1)); fi

    # mode 3 — --run (tracked; REFUSED until regrown). PL-GZ-1b(d): a program the native blob does not
    # cover executes via the mode-2 interpreter and says so on stderr — output is STILL verified
    # (mismatch = FAIL); a verified fallback counts REFUSED, NOT a native PASS.
    local e3; e3=$(mktemp /tmp/pl_m3err_XXXXXX)
    local o3; o3=$(timeout -k 5 8 "$SCRIP" --run "$tmp" 2>"$e3" </dev/null)
    if grep -q "MODE-3 INTERP-FALLBACK" "$e3"; then
        if [ "$o3" = "$expected" ]; then r3="m3 REFUSED"; X3=$((X3+1)); else r3="m3 FAIL"; F3=$((F3+1)); fi
    elif echo "$o3" | grep -qE "$SMX_SIG"; then r3="m3 REFUSED"; X3=$((X3+1))
    elif [ "$o3" = "$expected" ];        then r3="m3 PASS";    P3=$((P3+1))
    else                                       r3="m3 FAIL";    F3=$((F3+1)); fi
    rm -f "$e3"

    # mode 4 — --compile --target=x86 (tracked; emit→assemble→run when live)
    local e4; e4=$(timeout -k 5 8 "$SCRIP" --compile --target=x86 "$tmp" 2>&1 </dev/null)
    if echo "$e4" | grep -qE "$SMX_SIG"; then
        r4="m4 REFUSED"; X4=$((X4+1))
    else
        local o4; o4=$(timeout -k 5 15 bash "$HERE/run_prolog_via_x86_backend.sh" "$tmp" 2>/dev/null </dev/null)
        if [ "$o4" = "$expected" ]; then r4="m4 PASS"; P4=$((P4+1)); else r4="m4 FAIL"; F4=$((F4+1)); fi
    fi

    rm -f "$tmp"
    printf "  [%-10s] [%-10s] [%-10s] %s\n" "$r2" "$r3" "$r4" "$label"
}

echo "=== Prolog smoke (mode 2 = --run · mode 3 = --run · mode 4 = --compile x86) ==="

pl "write_atom" "hello" << 'EOF'
:- initialization(main).
main :- write(hello), nl.
EOF

pl "unify" "world" << 'EOF'
:- initialization(main).
main :- X = world, write(X), nl.
EOF

pl "arith" "5" << 'EOF'
:- initialization(main).
main :- X is 2 + 3, write(X), nl.
EOF

pl "clause" "$(printf 'a\nb\nc')" << 'EOF'
:- initialization(main).
fact(a). fact(b). fact(c).
main :- fact(X), write(X), nl, fail ; true.
EOF

pl "recursion" "$(printf '3\n2\n1')" << 'EOF'
:- initialization(main).
count(0) :- !.
count(N) :- N > 0, write(N), nl, N1 is N - 1, count(N1).
main :- count(3).
EOF

# a clause ending in a bare disjunction, retried under findall: SIGSEGV from e41bf8a6a to a650ba35a, three days unseen by every smoke and
# core entry (ceo CEO-1864, the cfo's suggestion); the answer is swipl 9.0.4's
pl "clause_ends_in_a_bare_disjunction" "[1,2]" << 'EOF'
:- initialization(main).
cq(X) :- (X = 1 ; X = 2).
main :- findall(X, cq(X), L), write(L), nl.
EOF

echo ""
echo "mode-2 (--run):            PASS=$P2 FAIL=$F2                / $N   (HARD GATE)"
echo "mode-3 (--run):               PASS=$P3 FAIL=$F3 REFUSED=$X3   / $N   (tracked)"
echo "mode-4 (--compile x86):       PASS=$P4 FAIL=$F4 REFUSED=$X4   / $N   (tracked)"
[ "$F2" -eq 0 ]
