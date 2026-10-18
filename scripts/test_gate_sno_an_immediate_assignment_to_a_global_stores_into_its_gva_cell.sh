#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_an_immediate_assignment_to_a_global_stores_into_its_gva_cell.sh -- AN IMMEDIATE ASSIGNMENT ($ name) WHOSE TARGET IS A
# GVA GLOBAL is emitted as rt_cap_open_gva(cell, saved, cur, name): the emitted code hands the runtime the variable's own GVA cell
# (the same cell NV_CELL_IF_FASTSET_fn would find by name -- a function's local of that name lives in the same cell through the
# name-save, so dynamic scoping is untouched), and the entry allocates the substring, copies it and stores the DESCR without a
# hash lookup, a memo strcmp or the comm_var_active call (ceo 2026-09-24, CEO-1250: porter x4 at the 512 MB arena read
# NV_CELL_IF_FASTSET_fn 7.7% + strcmp 6.7% of cycles under the by-name form; 4.43 G -> 3.76 G instructions on the cure). The entry
# falls back to rt_cap_open_plain (the by-name store, unchanged) whenever an I/O association exists (g_call_fastpath_off), the
# monitor is attached, a TRACE is set or the debug trace is on -- so every observable side effect is the plain path's (a
# TRACE'd target therefore takes the direct entry and the runtime's trace_set_n test sends it down the plain path, where the
# trace line fires). The emitter keeps the by-name form for an I/O-associated name (the GVA collector refuses it) and a protected
# pattern name; a function's LOCAL of the name shares the global's cell (the name-save on entry swaps the cell's value), so the
# direct store is the local's store too. SCRIP_CAP_GVA=0 is the control arm (every site calls rt_cap_open_plain).
# THREE ARMS: (1) the witness's .s carries 10 rt_cap_open_gva sites and 1 rt_cap_open_plain site (the OUTPUT-associated target)
# under the cure, and 0 / 11 under the control arm; (2) the witness -- a pattern
# built at top level and matched inside a function that declares the target local (SPITBOL assigns the local), a pattern built
# inside a function on its own local, an OUTPUT-associated target (the assignment prints), a TRACE'd target (the trace line
# prints), three captures in one statement, a 2000-iteration ARB loop, and an immediate assignment inside a match that then
# fails (the value stays assigned) -- prints the oracle's lines in m3 and m4 under both arms; (3) the emitted call passes the cell
# and the name (the .s carries the name string beside the cell address at every gva site).
# ⛔ `$ ARB` (a protected pattern name) is left out on purpose: SPITBOL leaves ARB alone and continues, SCRIP raises error 42 --
# a pre-existing divergence on both arms, the row snobol4-an-immediate-assignment-to-a-protected-pattern-name-is-error-42-not-silent.
# ⛔ The OUTPUT-associated variable's VALUE is not read back on purpose: SPITBOL both writes the line and keeps the value, SCRIP's
# NV_SET_fn writes the line and drops the value -- a pre-existing divergence on both arms, the row
# snobol4-an-output-associated-variable-loses-the-value-it-was-assigned.
# EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle or binary missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "REFUSED(2): $ROOT/scrip not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/cap.sno" <<'SNO'
        DEFINE('f()loc')                        :(f_end)
f       'xyz' LEN(2) $ loc
        f = 'f:' loc                            :(RETURN)
f_end   DEFINE('g()stem')                       :(g_end)
g       stem = 'g-local'
        'abc' p
        g = 'g:' stem                           :(RETURN)
g_end   OUTPUT(.assoc)
        'hello' LEN(4) $ assoc
        &TRACE = 5
        TRACE('tr')
        'trace' LEN(3) $ tr
        stem = 'global'
        p = LEN(1) $ stem
        OUTPUT = f()
        OUTPUT = g()
        OUTPUT = 'after g: ' stem
        'q' p
        OUTPUT = 'top: ' stem
        s = 'the quick brown fox'
        s BREAK(' ') $ w1 ' ' BREAK(' ') $ w2 ' ' REM $ rest
        OUTPUT = w1 '|' w2 '|' rest
        n = 0
loop    n = LT(n, 2000) n + 1                   :F(done)
        s ARB $ a1 'quick' $ a2 ARB $ a3 RPOS(0) :F(bad)
        t = a2                                  :(loop)
bad     OUTPUT = 'bad'
done    OUTPUT = a1 '|' a2 '|' a3 ' ' n
        s POS(0) SPAN('abcdefghijklmnopqrstuvwxyz') $ w RPOS(0)  :S(no)
        OUTPUT = 'w=' w
no      OUTPUT = 'done ' tr
END
SNO
red=0
"$SBL" $(sbl_lang_flags) "$W/cap.sno" < /dev/null > "$W/cap.ref" 2>&1 || true
[ -s "$W/cap.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
for arm in on off; do
    if [ "$arm" = on ]; then unset SCRIP_CAP_GVA; else export SCRIP_CAP_GVA=0; fi
    ( cd "$W" && "$ROOT/scrip" --compile --stlimit -o "$W/cap_$arm.s" cap.sno < /dev/null > /dev/null 2>&1 ) || { echo "RED: cap.sno did not compile (arm $arm)"; red=1; continue; }
    ng=$(grep -c 'rt_cap_open_gva' "$W/cap_$arm.s"); np=$(grep -c 'rt_cap_open_plain' "$W/cap_$arm.s")
    if [ "$arm" = on ]; then [ "$ng" -eq 10 ] && [ "$np" -eq 1 ] && echo "ok  arm on: 10 gva sites (the function local and the TRACE'd name among them), 1 by-name site (the OUTPUT-associated name)" || { echo "RED arm on: gva=$ng plain=$np (want 10 / 1)"; red=1; }
    else [ "$ng" -eq 0 ] && [ "$np" -eq 11 ] && echo "ok  arm off: 0 gva sites, 11 by-name sites" || { echo "RED arm off: gva=$ng plain=$np (want 0 / 11)"; red=1; }; fi
    ( cd "$W" && timeout -k 5 20 "$ROOT/scrip" --stlimit cap.sno < /dev/null > "$W/cap.$arm.m3" 2>&1 ); cmp -s "$W/cap.$arm.m3" "$W/cap.ref" && echo "ok  m3 arm $arm = oracle" || { echo "RED m3 arm $arm differs from the oracle:"; diff "$W/cap.ref" "$W/cap.$arm.m3" | head -8; red=1; }
    if gcc "$W/cap_$arm.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/cap_$arm.bin" 2>/dev/null; then
        ( cd "$W" && timeout -k 5 20 "./cap_$arm.bin" < /dev/null > "$W/cap.$arm.m4" 2>&1 ); cmp -s "$W/cap.$arm.m4" "$W/cap.ref" && echo "ok  m4 arm $arm = oracle" || { echo "RED m4 arm $arm differs from the oracle:"; diff "$W/cap.ref" "$W/cap.$arm.m4" | head -8; red=1; }
    else echo "RED m4 arm $arm did not link"; red=1; fi
done
unset SCRIP_CAP_GVA
nn=$(grep -B6 'rt_cap_open_gva' "$W/cap_on.s" | grep -c 'lea *rcx, \[rip + \.S')
[ "$nn" -eq 10 ] && echo "ok  every gva site passes the name string beside the cell (10 of 10)" || { echo "RED: $nn of 10 gva sites pass the name string (the fallback path needs it)"; red=1; }
[ "$red" -eq 0 ] && { echo "GATE OK: immediate assignments to GVA globals store into their cell, the by-name sites stay by name, the control arm restores every site, and both arms match the oracle in both modes"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
