#!/usr/bin/env bash
# stale-binary preflight -- util_require_fresh.sh is the ONE authority; no second copy of the staleness rule here.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_atom_name_survives_a_collect_mid_operation.sh -- AN ATOM'S NAME, READ INTO A RAW C POINTER, MUST
# STILL BE THAT NAME AFTER A COLLECTION LANDS MID-OPERATION (hq_prolog 2026-09-16, row
# prolog-atom-names-live-in-71-c-locals-that-no-root-scan-sees-so-deleting-pinning-dangles-every-one; cto ruling
# 2026-09-14 on the cure and on what this gate grades; census by hq_V).
#
# ✅ BOTH CLAUSES ARE GREEN AND THIS GATE IS WIRED BLOCKING (hq_prolog 2026-09-20). It spent three days at
# 2 of 3 with clause 2 red for a reason that was never this row's, and the ruling in gate_wiring.tsv said in
# writing to wire it in the landing that cleared that crash. That crash is cleared, so this is that landing.
# Clause 1 grades the PRECONDITION the cto ruled: atom-name storage is OUTSIDE the collected heap. The cto ruled
# option one (storage leaves the heap) over option two (re-read through prolog_atom_name after every point that
# can collect) because option two is a property at 56 call sites that nothing but the next author's memory can
# hold: a claim spanning two sites can be held by a check, a claim spanning fifty-six cannot be held at all.
#
# ⛔⭐ WHAT CLEARED CLAUSE 2, AND IT WAS NOT THIS ROW. Clause 2 grades 20 runs per mode under SCRIP_GC_STRESS=1,
# and that used to trip a SIGSEGV with nothing to do with atom names: the collection point walked g_call_args and
# handed the visitor a word that was not a DESCR. Row prolog-twelve-master-entries-sigsegv-under-gc-stress-in-the-
# call-args-root-walk owned it. It was cured by SCRIP cda82fa66 (cto, CTO-90) -- the DT_N slen==1/slen==2 heap-block
# checks in gc_visit_one -- which is the walker-side exclusion this seat built, measured at 20/20 -> 0/20, and
# REFUSED TO LAND because on that tree a DT_N slen==1 frame reference was the only root reaching that cell whenever
# the pz fast path skipped the machine-stack walk. ⭐ THE REFUSAL WAS RIGHT AND WAS NOT ANSWERED -- it was DISSOLVED
# by SCRIP c6bf8e789, THE E SWITCH, which deleted cons_stack, pz and the seam sweep so gc_collect_ex now calls
# gc_stack_segments unconditionally and the excluded cell is always reached by the stack walk itself. The lesson is
# the schedule's, not the bug's: a blocked row should re-run its DONE-WHEN before re-reading its own analysis,
# because "has my question been answered" and "is my question still the question" have different answers.
#
# ⭐ THE ATTRIBUTION THAT KEPT THE TWO DEFECTS APART WAS MEASURED, NOT INFERRED FROM THE SHAPE: the atom-name cure
# left the crash rate UNCHANGED (queens 20/20 before and after, this witness 4/30 before and 3/30 after -- noise,
# and deliberately not read as an improvement). Two defects that looked alike at the surface were two classes.
#
# ⛔⭐ WHY CLAUSE 2 CANNOT BE THE LEVER, AND THIS IS THE PART WORTH READING. The collector is a SLIDING compactor:
# gc_heap.c memmoves live blocks down and DOES NOT overwrite what it vacates. So a pointer left behind by a move
# keeps reading the OLD BYTES, which are still the correct string until something else is allocated over them. A
# dangling atom-name read therefore returns a PLAUSIBLE answer, and an output comparison -- any number of runs of
# it -- cannot tell that class from a correct one. SCRIP_GC_POISON exists for exactly this: it fills the vacated
# tail with 0xDB after the slide, so a stale pointer into freed space reads garbage instead of the truth.
#
# ⛔ THE POSITIVE CONTROL IS MANDATORY AND A DEAD SWITCH REFUSES rc=2. This row's own history is the reason: its
# first witness was self-identical in every collector configuration with moved=0B everywhere -- a switch that was
# not on, reading exactly like a clean result. Before grading anything this gate asserts, from [ZGC-WALK] and
# [ZGC-POISON] under SCRIP_ZETA_TELEM=1, that blocks really moved AND that vacated space really was filled.
#
# ⛔ THE REF IS CUT FROM swipl AT RUN TIME, NEVER FROM OUR OWN OUTPUT (CEO-753). No swipl, no grade: rc=2.
#
# ⛔ WHAT THE POISON DOES NOT COVER, so the next seat does not over-trust a green: it fills the vacated TAIL only.
# A block that slid DOWN leaves its old address inside the still-live region, where other slid data now sits, so a
# stale pointer there still reads plausible bytes. Poison catches the tail class; it does not catch that one.
# ⭐⛔ --quick RUNS 2 ITERATIONS PER MODE INSTEAD OF 20, AND THE NUMBER IS MEASURED RATHER THAN CHOSEN.
# FAIL-ONCE STUDY, hq_prolog 2026-09-20, on a build with THIS ROW'S CURE REVERTED (prolog_atom.c taking atom-name
# storage back onto the collected heap via rt_heap_strdup_c): the gate goes RED at ITERS=1 -- 1 of 1 runs diverged,
# in BOTH modes, at ITERS=1, 2 and 4 alike. DETECTION IS DETERMINISTIC, NOT PROBABILISTIC.
# ⭐ WHY IT IS DETERMINISTIC NOW WHEN THE 20-RUN DESIGN ASSUMED IT WAS NOT: the 20 runs were specified BEFORE
# SCRIP_GC_POISON existed, when a dangling atom-name read returned the OLD BYTES -- still the correct string until
# something allocated over them -- so only repetition plus luck could catch it. Poison fills the vacated tail with
# 0xDB, so the stale read is GARBAGE on the first run. The poison knob did not make the gate faster; it made the
# REPETITION REDUNDANT, and nobody had gone back to re-derive the iteration count after landing it.
# ⛔ THE COST IS PAID BY THE GREEN RUNS, NOT BY DETECTION: a CORRECT run under SCRIP_GC_STRESS=1 costs ~19.4s, a
# diverging one fails fast (the whole mutated study at ITERS=1/2/4 took 2s, 1s and 2s). So ITERS is almost pure
# cost on a healthy tree and almost no detection value past the first run.
# ⛔ 2 AND NOT 1, DELIBERATELY: one run has no margin at all, and this gate's own history is a witness that ran
# green in every configuration because its switch was dead. Two runs keep a second observation of the positive
# control. ⛔ MEASURED, AND MY OWN EXTRAPOLATION WAS WRONG: I predicted ~80s from 19.4s per run and a ~2s fixed
# cost; --quick actually measures 102/91/92s over three runs at load, so the fixed cost (swipl ref cut, m4 build,
# the telemetry run of the positive control) is ~13s and not ~2s. At ~95s this becomes the joint most expensive
# arm of the blocking set, whose current maximum is 90s -- 1.06x that maximum, against 8.6x for the 778s form.
# ⛔ THE FULL 20-ITERATION FORM IS STILL THE DEFAULT for a hand run and for a collector landing -- pass no flag.
# EXIT: 0 both clauses pass · 1 the precondition is red or a run diverged from the oracle · 2 REFUSED to grade.
# ✅ WIRED BLOCKING in make test / test-sequential as of 2026-09-20. The gate_wiring.tsv RULING that held it
# out EXPIRED WITH ITS NAMED ROW, exactly as that ruling said it would, and the row is closed.
set -uo pipefail
GATE_NAME=test_gate_pl_atom_name_survives_a_collect_mid_operation
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP:-$ROOT/scrip}"; RT_DIR="${RT_DIR:-$ROOT/out}"; SWIPL="${SWIPL:-/usr/bin/swipl}"
ATOMC="$ROOT/src/runtime/rt/prolog_atom.c"
QUICK=0; for a in "$@"; do case "$a" in --quick) QUICK=1 ;; esac; done
ITERS="${ITERS:-$([ "$QUICK" = 1 ] && echo 2 || echo 20)}"; STRESS="${SCRIP_GC_STRESS_VALUE:-1}"; CHURN="${WITNESS_CHURN:-300}"; MODES="${MODES:-m3,m4}"
# ⛔ A STRESSED RUN THAT DOES NOT FINISH IS NOT A DIVERGENCE (hq_prolog 2026-09-24, row prolog-an-atom-name-does-not-survive-a-
# collection-mid-operation-...): the per-run bound was 60 s and scored a kill as a wrong answer. At load 23 one correct m3 run
# measured 38.6/58.8/54.6 s wall and 39.0 s of CPU over 6040 collections (it was ~19.4 s wall on 09-20), so the bound sat ON
# the measurement and the ceo's pass at load 10-45 read RED on a tree where the gate passes 4/4. The bound is now an order of
# magnitude above the measurement, and a run that still hits it REFUSES rc=2 with the load stamped -- never a FAIL.
RUN_TIMEOUT="${RUN_TIMEOUT:-600}"
refuse(){ echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip at $SCRIP -- a missing binary prints a full, plausible, entirely false board"
[ -x "$SWIPL" ] || refuse "no swipl oracle at $SWIPL -- the ref is cut from the oracle at run time or not at all"
[ -f "$ATOMC" ] || refuse "no $ATOMC -- the precondition clause has nothing to read"
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "CLAUSE 1 -- THE PRECONDITION: atom-name storage is outside the collected heap"
# ⛔⭐ THIS CLAUSE IS AN ALLOWLIST AND IT USED TO BE A DENYLIST, WHICH IS THE WHOLE LESSON OF THIS ROW.
# It grepped rt_heap_strdup|rt_heap_alloc|rt_pinned_* and called their ABSENCE a pass. That read CLEAN on a tree
# where the exposure was strictly WORSE, because the storage had moved to rt_heap_strdup_c -- the same heap under
# a different allocator name. A denylist of allocator NAMES cannot answer "is this storage collected", only "is it
# one of the four spellings I thought of", and a new spelling passes it silently. So: resolve the allocator that
# ACTUALLY produces the name pointer, and require it to be on a short list of off-heap sources. An allocator this
# clause cannot resolve REFUSES rc=2 -- it must never be able to report a pass about a line it did not understand.
# ⛔ AND IT IS SCOPED TO THE NAME, NOT THE FILE: prolog_atom.c's TABLES (g_ht, g_atom_names) come from rt_wsb_alloc,
# which IS the collected heap and is CORRECT -- pl_gc_roots visits both blocks and their slots are registered, so
# a slide fixes them up. Only the NAME may not be collected, because a raw C local holds it across operations and
# no root scan sees that local. A file-wide allowlist would red the two table allocations, which are not the bug.
NAMEVAR="$(grep -oE 'g_atom_names\[[A-Za-z_][A-Za-z0-9_]*\][[:space:]]*=[[:space:]]*[A-Za-z_][A-Za-z0-9_]*' "$ATOMC" | head -1 | sed -E 's/.*=[[:space:]]*//')"
[ -n "$NAMEVAR" ] || refuse "cannot find the assignment into g_atom_names[] in $ATOMC -- this clause must never pass on a file it did not parse"
NAMEALLOC="$(grep -oE "\\b$NAMEVAR[[:space:]]*=[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(" "$ATOMC" | head -1 | sed -E 's/.*=[[:space:]]*//; s/[[:space:]]*\($//')"
[ -n "$NAMEALLOC" ] || refuse "found g_atom_names[...] = $NAMEVAR but cannot resolve where $NAMEVAR is allocated -- refusing rather than guessing"
case "$NAMEALLOC" in
    ct_strdup|ct_alloc|strdup|malloc|calloc)
        ck ok "the atom name is allocated by $NAMEALLOC, which is off the collected heap -- a name pointer held in a raw C local cannot be invalidated by a slide" ;;
    pool_strdup)
        # pool_strdup (this file) bump-allocates out of a chunk from rt_slab_region(), which gets its chunks from
        # rt_slab_get() -> ct_alloc() (src/runtime/rt/rt_slab.c) -- a manually-managed, recycled slab pool, never
        # the collected heap. Confirmed 2026-10-01: CLAUSE 2 (byte-equal under SCRIP_GC_STRESS=1 SCRIP_GC_POISON=1,
        # both modes) is green on this same tree, which a dangling-pointer class could not pass by chance.
        ck ok "the atom name is allocated by $NAMEALLOC, which bump-allocates out of rt_slab_region()/ct_alloc() -- off the collected heap, never slid or poisoned" ;;
    *)
        ck no "the atom name is allocated by $NAMEALLOC, which is not on the off-heap allowlist (ct_strdup ct_alloc strdup malloc calloc pool_strdup) -- if $NAMEALLOC is genuinely off-heap, ADD IT HERE with the reason; if it is the collected heap, this row's cure has been reverted" ;;
esac
KEYSRC="$(grep -oE 'g_ht\[[A-Za-z_][A-Za-z0-9_]*\]\.key[[:space:]]*=[[:space:]]*[A-Za-z_][A-Za-z0-9_]*' "$ATOMC" | head -1 | sed -E 's/.*=[[:space:]]*//')"
if [ "$KEYSRC" = "$NAMEVAR" ]; then
    ck ok "the hash key and the table entry are the SAME pointer ($NAMEVAR), so neither can be cured while the other dangles"
else
    ck no "the hash key comes from '$KEYSRC' and the table entry from '$NAMEVAR' -- two storages for one name, and this clause only graded one of them"
fi
W="$(mktemp -d "${TMPDIR:-/tmp}/pl_atom_name.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$W"' EXIT
cat > "$W/w.pl" <<PL
n_atom(N, A) :- number_codes(N, C), atom_codes(A0, C), atom_concat(nm_, A0, A).
churn(0) :- !.
churn(N) :- n_atom(N, A), atom_length(A, L), L > 0, N1 is N - 1, churn(N1).
:- dynamic held/2.
main :-
    churn($CHURN),
    n_atom(11, A), n_atom(22, B),
    functor(T, A, 3), churn($CHURN), functor(T, F, N), write(F/N), nl,
    atom_length(A, LA), churn($CHURN), write(LA), nl,
    atom_chars(B, Cs), churn($CHURN), write(Cs), nl,
    assertz(held(A, B)), churn($CHURN), held(X, Y), write(X-Y), nl,
    findall(Z, member(Z, [A,B,A]), Zs), churn($CHURN), write(Zs), nl,
    sort([B,A,B], Ss), churn($CHURN), write(Ss), nl,
    atom_concat(A, B, AB), churn($CHURN), write(AB), nl,
    T =.. [Hd|_], churn($CHURN), write(Hd), nl,
    ( A @< B -> write(lt) ; write(ge) ), nl,
    atom_codes(A, ACs), churn($CHURN), atom_codes(A2, ACs), write(A2), nl,
    write(A), nl, write(B), nl.
:- initialization(main).
PL
REF="$W/ref.txt"
if ! timeout -k 5 60 "$SWIPL" -q -g true -t halt "$W/w.pl" </dev/null > "$REF" 2>"$W/ref.err"; then
    refuse "the swipl oracle did not run the witness: $(head -3 "$W/ref.err" | tr '\n' ' ')"
fi
[ -s "$REF" ] || refuse "the oracle produced an EMPTY ref -- an empty expectation makes every run trivially pass"
grep -qx 'nm_22' "$REF" || refuse "the oracle's own answer is not the expected shape; witness or oracle changed"
echo "ORACLE REF (swipl, cut at run time): $(tr '\n' ' ' < "$REF")"
echo "POSITIVE CONTROL -- the collector must really move blocks AND really poison what it vacates"
TEL="$(SCRIP_GC_STRESS="$STRESS" SCRIP_GC_POISON=1 SCRIP_ZETA_TELEM=1 timeout -k 5 "$RUN_TIMEOUT" "$SCRIP" "$W/w.pl" </dev/null 2>&1 >/dev/null || true)"
MOVED="$(printf '%s' "$TEL" | grep -oE 'moved=[0-9]+B' | sed 's/[^0-9]//g' | awk '{s+=$1} END{print s+0}')"
VACD="$(printf '%s' "$TEL" | grep -oE 'vacated=[0-9]+B' | sed 's/[^0-9]//g' | awk '{s+=$1} END{print s+0}')"
[ "$MOVED" -gt 0 ] || refuse "moved=${MOVED}B under SCRIP_GC_STRESS=$STRESS -- nothing relocated, so a green below would prove nothing (this row's first witness died exactly here)"
[ "$VACD"  -gt 0 ] || refuse "vacated=${VACD}B under SCRIP_GC_POISON=1 -- the poison never fired, so a stale read would still find its old bytes intact"
echo "  control: moved=${MOVED}B relocated, vacated=${VACD}B filled with 0xDB"
echo "CLAUSE 2 -- THE REGRESSION GUARD: $ITERS runs per mode, byte-equal to the oracle, under stress AND poison"
M4DIR="$W/m4"; mkdir -p "$M4DIR"
m4_build(){
    rm -f "$M4DIR/w.s" "$M4DIR/w.bin"
    timeout -k 5 120 "$SCRIP" --compile -o "$M4DIR/w.s" "$W/w.pl" </dev/null >"$M4DIR/compile.log" 2>&1 || return 1
    [ -s "$M4DIR/w.s" ] || return 1
    timeout -k 5 120 gcc -no-pie "$M4DIR/w.s" -o "$M4DIR/w.bin" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm >>"$M4DIR/compile.log" 2>&1 || return 1
    [ -x "$M4DIR/w.bin" ] || return 1
    return 0
}
run_mode_m3(){ SCRIP_GC_STRESS="$STRESS" SCRIP_GC_POISON=1 timeout -k 5 "$RUN_TIMEOUT" "$SCRIP" "$W/w.pl" </dev/null 2>&1; }
run_mode_m4(){ SCRIP_GC_STRESS="$STRESS" SCRIP_GC_POISON=1 timeout -k 5 "$RUN_TIMEOUT" "$M4DIR/w.bin" </dev/null 2>&1; }
for m in ${MODES//,/ }; do
    if [ "$m" = m4 ]; then
        m4_build || refuse "mode 4 could not build the witness -- refusing rather than grading a stale or absent artifact: $(tail -3 "$M4DIR/compile.log" 2>/dev/null | tr '\n' ' ')"
    fi
    bad=0; first=""
    for i in $(seq 1 "$ITERS"); do
        out="$(run_mode_$m)"; rrc=$?
        [ "$rrc" = 124 ] && refuse "$m run $i did not finish in ${RUN_TIMEOUT}s at load $(cut -d' ' -f1-3 /proc/loadavg) -- a kill is not a divergence"
        if [ "$out" != "$(cat "$REF")" ]; then bad=$((bad+1)); [ -n "$first" ] || first="iter $i: $(printf '%s' "$out" | head -2 | tr '\n' ' ')"; fi
    done
    if [ "$bad" -eq 0 ]; then ck ok "$m: $ITERS/$ITERS runs byte-equal to the swipl ref under SCRIP_GC_STRESS=$STRESS SCRIP_GC_POISON=1"
    else ck no "$m: $bad of $ITERS runs DIVERGED from the swipl ref -- $first"; fi
done
echo "------------------------------------------------------------"
if [ "$fails" -eq 0 ]; then echo "✅ GATE PASS: atom-name storage is outside the collected heap and every raw-pointer site survives a mid-operation collection ($checks check(s))"; exit 0; fi
echo "⛔ GATE FAIL: $fails of $checks check(s) failed"; exit 1
