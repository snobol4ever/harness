#!/usr/bin/env bash
# test_gate_no_c_to_bb.sh — NCB-0 gate: enumerate every C→BB transfer outside the sanctioned MAIN sites.
# CONVENTION (GOAL-SNOBOL4-100.md Phase 1 / ARCH-ENGINE.md § ζ Local Storage, Lon s22): mode 3 has exactly ONE
# C→BB transfer — the driver MAIN branch; C runtime helpers are STRICT LEAVES (BB calls C, C returns, C never
# calls/jmps a BB); mode 4 entry is main = the emitted graph. SANCTIONED SITES (excluded below):
#   src/driver/scrip.c        function main            — TWO mutually-exclusive MAIN branches per run
#                                                        (~:1327 general mode-3 entry; ~:1407 SNOBOL4 pat_flat
#                                                        whole-program entry; both `goto run_done`) + the
#                                                        m3_enter_with_rbx asm thunk they route through.
#                                                        [LEDGER NOTE: s22 text said "the driver MAIN branch"
#                                                        singular; ground truth is two exclusive branches of
#                                                        the one MAIN dispatch — one transfer per run either way.]
#   src/runtime/rt/rt_coexpr.c scrip_coexpr_trampoline_entry — sanctioned per-thread MAIN (jmp not call,
#   src/runtime/rt/rt_coexpr.c rt_genp_spine_enter / rt_genp_spine_enter_n2 — the two coroutine spines, the
#     first frame on a fresh coroutine stack with no emitted code beneath them (CEO-970, moved out of rt.c
#     2026-09-20 by the cto so the sanction and the code agree).
#                                                        fresh pthread stack, never returns).
#   src/driver/scrip.c        icn_zf_main_call         — THIRD mutually-exclusive MAIN branch (row
#                                                        c-to-bb-unledgered-scrip-c-57, seat15 2026-08-30):
#                                                        the `_zframe_graph && !_icn_cells_graph` arm, same
#                                                        one-MAIN-per-run dispatch, own raw-asm shim only
#                                                        because it needs register state (r12 from a fixed
#                                                        slab address, esi/r14d zeroed) the other MAIN arms'
#                                                        rt_outer_call helpers don't set up.
# DETECTED SHAPES: (a) member fn-ptr α calls `->fn(fb, 0)` / `->fn((void *)fb, 0)`; (b) bare bb_box_fn β
# resumes `fn((void *)fb, 1)`; (c) inline-asm `call *%rax` into the slab (the EVAL shim); (d) bare MAIN-shape
# `fn(rt_frame(), 0)`; (e) RIDERS — C (non-emitted, non-decl) callers of the V4/V5 trampoline API outside rt.c.
# GROUPING: hits fold into the s22 ledger groups V1..V7 by enclosing function; any hit whose enclosing
# function is unknown lands in UNLEDGERED and is ALWAYS a failure signal worth reading.
# EXIT: default REPORT-ONLY, exit 0 (non-blocking at birth per NCB-0; reports 7). --strict: exit 1 if any
# group remains (flips into Session Setup at NCB-4). Expected count-down: NCB-1 lands → 4, NCB-2 → 1, NCB-3 → 0.
# grep -a THROUGHOUT: several sources (core.c) contain UTF-8 Greek identifiers (Σ, δ) and read as binary.
# AUTHORS: Lon Jones Cherryholmes · Jeffrey Cooper M.D. · Claude   DATE: 2026-07-11 (NCB-0)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; REPO="${HERE}/../../SCRIP"; cd "$REPO" || exit 2
STRICT=1; [ "${1:-}" = "--informational" ] && STRICT=0   # V2-5: strict by default; --strict kept as a no-op alias
[ "${1:-}" = "--strict" ] && STRICT=1
[ "$STRICT" = "0" ] && echo "⛔ --informational: verdict NOT enforced."
# ⭐ V2-5 COVERAGE FLOOR (gate honesty): examining NOTHING must never read the same as examining everything.
. "$HERE/lib_gate.sh"
gate_floor "$(ls "$REPO"/src/emitter/*.c "$REPO"/src/emitter/*.cpp "$REPO"/src/templates/{bb,xa}/*.cpp "$REPO"/src/runtime/*.c 2>/dev/null | wc -l)" 100 "source files under src/ -- an empty tree is UNPROVEN(2), not a pass"


SCAN_DIRS="src/runtime src/driver src/ir src/lower src/parsers src/optimizer"
# ⛔ FALSE-GREEN CURE (row gates-scan-retired-directories-and-report-clean-on-trees-they-never-opened):
# src/machine and src/contracts were merged into src/ir by the 2/3 re-grid (SCRIP d4312e86) and no longer
# exist -- a `find`/`grep` over a missing directory returns no matches, which reads exactly like a clean
# scan, so this gate was silently certifying an unexamined tree. Refuse rather than pass on a scan target
# that cannot be opened, so this class can never present as green again.
for _d in $SCAN_DIRS; do gate_require "$_d" "SCAN_DIRS entry"; done

enclosing_fn() { # file line -> name of enclosing top-level function; a top-level __asm__ block whose .globl symbol sits on the
    # __asm__( line itself is named by that symbol (the driver's rt_outer_call / rt_outer_call_delta0, relocated from rt.c 2026-09-19 by the
    # cfo so that the runtime library holds no MAIN thunk); every other __asm__ block still reads as __asm__ (V6), so the rt.c report is unchanged.
    awk -v n="$2" 'NR<=n && /^[A-Za-z_][A-Za-z0-9_ \*]*\(/ && !/;[ \t]*$/ { f=$0 } END {
        if (f ~ /^__asm__\(/ && match(f, /\.globl [A-Za-z_][A-Za-z0-9_]*/)) { print substr(f, RSTART+7, RLENGTH-7); exit }
        gsub(/\(.*/,"",f); nf=split(f,a,/[ \*]+/); print (nf?a[nf]:"?") }' "$1"
}

RAW=$(mktemp); TMP=$(mktemp); STRIP=$(mktemp -d); trap 'rm -rf "$RAW" "$TMP" "$STRIP"' EXIT
# COMMENT-STRIPPED MIRROR (NCB-1b finding): the shapes below are CODE shapes, but a comment that QUOTES one is
# not a transfer.  s24's own leaf-split comment ("call p->fn(fb, 0)") tripped shape (a) and reported a phantom
# 8th group (UNLEDGERED @ rt.c:716) — a gate that reds on prose would have held NCB-4's --strict red forever.
# util_strip_c_comments.awk blanks comments LINE-PRESERVINGLY (so reported line numbers still index the real
# file) and leaves STRING LITERALS intact (shape (c), the EVAL asm shim, lives inside one).
for f in $(find $SCAN_DIRS -name '*.c' 2>/dev/null); do
    mkdir -p "$STRIP/$(dirname "$f")"; LC_ALL=C awk -f "$HERE/util_strip_c_comments.awk" "$f" > "$STRIP/$f"
done
cd "$STRIP" || exit 2
# (a+b) ANY call through a bb_box_fn pointer — the (fb, entry) signature — whether reached through a struct
# member (`p->fn(fb, 0)`) or a bare local fn-ptr (`fn((void *)fb, 0)`), at EITHER port (entry 0 = α, 1 = β).
# NCB-1b finding: the old pair of shapes keyed on member+entry-0 and bare+entry-1, so a BARE fn-ptr at entry 0
# matched neither — and that is exactly what NCB-1a's leaf split turned rt_call_proc_descr's transfer into
# (rt.c:532, `fn((void *)fb, 0)` off rt_frame_prep).  The gate was BLIND to the very transfer NCB-1b removes:
# the flip would have read 7→7 and proven nothing.  One shape now covers the whole (fb, entry) call space.
grep -rna --include='*.c' -E -e '\bfn\(\(?(void \*\))?fb, *[01]\)' $SCAN_DIRS 2>/dev/null \
    | sed -E 's/^([^:]+):([0-9]+):(.*)$/\1:\2:/' >> "$RAW.tmp1"
grep -rna --include='*.c' -E -e '\bfn\(\(?(void \*\))?fb, *[01]\)' $SCAN_DIRS 2>/dev/null \
    | awk -F: '{ line=$0; sub(/^[^:]+:[0-9]+:/,"",line); tag = (line ~ /->fn\(/) ? "member-fnptr" : "bare-fnptr"; print $1 ":" $2 ":" tag }' >> "$RAW"
rm -f "$RAW.tmp1"
# (c) inline-asm transfer into the slab
grep -rna --include='*.c' -E -e 'call \*%r?ax|call \*%%r?ax|jmp \*%%?rax' $SCAN_DIRS 2>/dev/null | cut -d: -f1,2 | sed 's/$/:asm-shim/' >> "$RAW"
# (d) bare MAIN-shape entries
grep -rna --include='*.c' -E -e 'fn\(rt_frame\(\), 0\)|m3_enter_with_rbx\(' $SCAN_DIRS 2>/dev/null | grep -av 'static void m3_enter_with_rbx' | cut -d: -f1,2 | sed 's/$/:main-shape/' >> "$RAW"
# (e) riders: C callers of the V4/V5 trampoline API outside rt.c (exclude decls) -- counted ONLY WHILE THE API STILL TRANSFERS.
# ⛔ ceo 2026-10-09 (CEO-1576, Lon: "List how many places call into BB's from C. Then stop the show and remove all of them."):
# a rider is a C function that reaches a shim THROUGH rt_proc_call_gen_h or rt_proc_resume_frame_h. Once the body of that API
# function carries no shim call (rt_proc_enter / rt_proc_enter_named / rt_tiny_record_enter / rt_chain_enter), what it does is
# start or resume a coroutine (the sanctioned arm test_gate_c2bb_the_generator_arm_is_a_coroutine_start_not_a_box_entry_from_c.sh
# reads), and its callers ride nothing. The guard reads the body from the tree, never a hand-kept list, so a shim call put back
# into either function re-arms this rule by itself.
for _api in rt_proc_call_gen_h rt_proc_resume_frame_h; do
    _body="$(awk -v f="$_api" '$0 ~ "^DESCR_t " f "\\(" {p=1} p {print} p && /^}/ {exit}' src/runtime/rt/rt.c)"
    if printf '%s\n' "$_body" | grep -qE '\b(rt_proc_enter|rt_proc_enter_named|rt_tiny_record_enter|rt_chain_enter)\('; then
        grep -rna --include='*.c' -E -e "$_api\\(" $SCAN_DIRS 2>/dev/null \
            | grep -av 'src/runtime/rt/rt\.c' | grep -avE ':[ \t]*(extern|DESCR_t) ' | cut -d: -f1,2 | sed 's/$/:rider/' >> "$RAW"
    fi
done
cd "$REPO" || exit 2

while IFS=: read -r f l shape; do
    [ -z "$f" ] && continue
    fn=$(enclosing_fn "$f" "$l")
    case "$f:$fn" in
        src/driver/scrip.c:main|src/driver/scrip.c:m3_enter_with_rbx) continue ;;
        # ⭐ THE MODE-3 ORIGINAL INVOCATION THUNK (cfo 2026-09-19, row gc-rt-c-c-to-bb-entries-leave-no-emitted-code-is-entered-from-c-in-rt-c-
        # except-the-original-invocation): rt_outer_call / rt_outer_call_delta0 are the very transfer RULES.md § NO C→BB ENTRY allows -- main's
        # one entry into the graph -- and they lived in src/runtime/rt/rt.c only because that file held the asm. They are the driver's, beside
        # icn_zf_main_call, so libscrip_rt.so exports no C→BB thunk for the main program at all. m3_enter_with_rbx above no longer exists
        # (kept in the case list as history; a hit can never carry that name).
        src/driver/scrip.c:rt_outer_call|src/driver/scrip.c:rt_outer_call_delta0) continue ;;
        src/runtime/rt/rt_coexpr.c:scrip_coexpr_trampoline_entry) continue ;;
        # ⭐ THE TWO COROUTINE SPINES, SANCTIONED PER CEO-970 AND MOVED HERE BESIDE THEIR TWIN (cto 2026-09-20):
        # rt_genp_spine_enter and rt_genp_spine_enter_n2 are reached ONLY from rt_genp_entry_c, which
        # rt_genp_thread_entry jumps to, which scrip_co_ctx_init installs as the entry on a FRESH COROUTINE
        # STACK -- the first frame on that stack, with no emitted code beneath it.  That is structurally
        # identical to scrip_coexpr_trampoline_entry above, which this gate already sanctions as the per-thread
        # MAIN, and a rule that sanctions one while naming the other reads the file name and not the structure.
        # They lived in rt.c only because that file held the asm; they are the coexpression road's, so the
        # sanction and the code now agree.  ⛔ If Lon's INITIAL START is per-run rather than per-stack, this
        # sanction is withdrawn and the two become conversions on the rt.c seat's row.
        src/runtime/rt/rt_coexpr.c:rt_genp_spine_enter|src/runtime/rt/rt_coexpr.c:rt_genp_spine_enter_n2) continue ;;
        # ⭐ THIRD SANCTIONED MAIN SITE (row c-to-bb-unledgered-scrip-c-57, seat15 2026-08-30): NOT dead
        # Icon scaffolding -- verified actively called (scrip.c main(), the `_zframe_graph &&
        # !_icn_cells_graph` branch) as a THIRD mutually-exclusive MAIN-transfer arm alongside the two
        # already-sanctioned ones, all under the same one-MAIN-per-run dispatch (every arm reaches the
        # same `goto run_done`). It needs its own raw-asm shim rather than routing through
        # rt_outer_call/rt_outer_call_delta0 because it sets up a distinct register state before the
        # `jmp *%rax` (r12 seeded from a fixed slab address, esi/r14d zeroed) that those helpers do not.
        src/driver/scrip.c:icn_zf_main_call) continue ;;
    esac
    echo "$f:$l:$fn:$shape"
done < "$RAW" | sort -t: -k1,1 -k2,2n -u > "$TMP"

ledger_of() { # enclosing function -> ledger group
    case "$1" in
        rt_call_named_proc)                       echo "V1" ;;
        rt_call_proc_direct)                      echo "V2" ;;
        rt_call_named_proc_sl)                    echo "V3" ;;
        rt_call_proc_descr|rt_proc_call_gen|rt_proc_call_gen_h) echo "V4" ;;
        rt_proc_resume_frame|rt_proc_resume_frame_h)            echo "V5" ;;
        rt_eval_run|__asm__|rt_eval_enter_shim)   echo "V6" ;;
        rt_call_value_gen_h|rt_call_value_resume_h|plc_next|rt_pl_goal_gen_h_c)    echo "V7" ;;
        # ⛔⭐ rt_pl_goal_gen_h_c JOINED V7 2026-09-19 (ceo CEO-943), AND IT IS A LEDGER FIX, NOT A NEW TRANSFER: the
        # function has been in the tree since `b4736aa3d` (2026-09-06 11:23, prolog: a meta-call miss raises a REAL ball),
        # so for THIRTEEN DAYS this gate printed it under UNLEDGERED and told every seat "a NEW violation of the one-entry
        # convention -- read it before anything else", which is the loudest line it has.  A ledger that lags the tree spends
        # the gate's credibility: a seat that learns the alarm is stale stops reading the alarm.  It belongs in V7 with the
        # other two RIDERS of by_name_dispatch.c (rt_call_value_gen_h, rt_call_value_resume_h): same file, same shape -- a C
        # rider that stages arguments and tail-returns rt_proc_call_gen_h, entering the box from C -- and the same owner, the
        # ceo's row gc-the-five-c-to-bb-entries-outside-rt-c-go-to-zero.  Its own frame passes the property test of ARCH-GC
        # section 9 (iii): `key` is a local char buffer, the stage happens before the entry and it tail-returns, so nothing
        # stale is read afterwards.  ⛔ UNLEDGERED STAYS THE LOUD CLASS: this line moves ONE known site into its group and
        # weakens nothing -- the gate still counts it, still names it, and STRICT still fails while it exists.
        *)                                        echo "UNLEDGERED" ;;
    esac
}

echo "=== NCB GATE — C→BB transfers outside the sanctioned MAIN sites ==="
echo "    sanctioned: scrip.c:main (2 exclusive MAIN branches through the driver's rt_outer_call / rt_outer_call_delta0 thunks) · rt_coexpr.c:scrip_coexpr_trampoline_entry · scrip.c:icn_zf_main_call (3rd MAIN branch)"
VGRPS=""
UNLEDGERED=0
# ⛔⭐ "NEW" IS A MEASURED WORD, NOT A GUESS (coo 2026-09-23, row instrument-the-no-c-to-bb-gate-reports-a-13-day-old-transfer-
# as-a-new-violation-...). This gate printed rt_pl_goal_gen_h_c as "a NEW violation" for thirteen days while git dated the site to
# b4736aa3d (2026-09-06): the ledger lagged the tree and its loudest line was false. So every UNLEDGERED site now carries the commit
# that LANDED it (the oldest commit whose diff adds its enclosing function's name to that file, `git log -S`) and a verdict against
# the LEDGER'S OWN LAST EDIT (the last commit to this file): NEW only when the site landed after the ledger last changed -- the
# ledger could not have known it -- and LEDGER LAG when it landed before, which is a ledger to fix, not an alarm. With no history to
# read, the site says UNMEASURED and is never called NEW.
NCB_LEDGER_REV="$(git -C "$REPO" log -1 --format='%h' -- ../harness/scripts/test_gate_no_c_to_bb.sh 2>/dev/null)"
NCB_LEDGER_DATE="$(git -C "$REPO" log -1 --format='%cs' -- ../harness/scripts/test_gate_no_c_to_bb.sh 2>/dev/null)"
NCB_NEW=0; NCB_LAG=0; NCB_UNMEASURED=0
landing_of() { # landing_of <file> <function> -> "landed <hash> <date> (<N> day(s) ago) -- NEW: ..." / "-- LEDGER LAG: ..." / "landing UNMEASURED ..."
    local f="$1" fn="$2" rev when age
    rev="$(git -C "$REPO" log --reverse --format='%h' -S"$fn" -- "$f" 2>/dev/null | head -1)"
    if [ -z "$rev" ] || [ -z "$NCB_LEDGER_REV" ]; then
        echo "landing UNMEASURED (no git history names $fn in $f) -- not called NEW"; return
    fi
    when="$(git -C "$REPO" log -1 --format='%cs' "$rev" 2>/dev/null)"
    age=$(( ( $(date -u +%s) - $(git -C "$REPO" log -1 --format='%ct' "$rev" 2>/dev/null) ) / 86400 ))
    if git -C "$REPO" merge-base --is-ancestor "$NCB_LEDGER_REV" "$rev" 2>/dev/null && [ "$rev" != "$NCB_LEDGER_REV" ]; then
        echo "landed $rev $when ($age day(s) ago) -- NEW: after the ledger's last edit $NCB_LEDGER_REV $NCB_LEDGER_DATE"
    else
        echo "landed $rev $when ($age day(s) ago) -- LEDGER LAG: before the ledger's last edit $NCB_LEDGER_REV $NCB_LEDGER_DATE, so the ledger missed it"
    fi
}
for V in V1 V2 V3 V4 V5 V6 V7 UNLEDGERED; do
    VLNS=""
    while IFS=: read -r f l fn shape; do
        [ "$(ledger_of "$fn")" = "$V" ] || continue
        if [ "$V" = UNLEDGERED ]; then
            _land="$(landing_of "$f" "$fn")"   # a subshell: the counts are kept here, in the loop's own shell
            case "$_land" in *"-- NEW:"*) NCB_NEW=$((NCB_NEW+1)) ;; *"LEDGER LAG"*) NCB_LAG=$((NCB_LAG+1)) ;; *) NCB_UNMEASURED=$((NCB_UNMEASURED+1)) ;; esac
            VLNS="${VLNS}    ${f}:${l}  (${fn}, ${shape})  ${_land}"$'\n'
        else VLNS="${VLNS}    ${f}:${l}  (${fn}, ${shape})"$'\n'; fi
    done < "$TMP"
    if [ -n "$VLNS" ]; then
        VGRPS="${VGRPS}${V} "
        echo "${V}:"
        printf '%s' "$VLNS"
        [ "$V" = "UNLEDGERED" ] && UNLEDGERED=1
    fi
done
N=$(echo $VGRPS | wc -w)
echo "LEDGER GROUPS REMAINING: $N   (NCB-1 → 4, NCB-2 → 1, NCB-3 → 0)"
[ "$UNLEDGERED" = "1" ] && echo "⚠ UNLEDGERED C→BB transfer present — $NCB_NEW NEW since the ledger's last edit ($NCB_LEDGER_REV $NCB_LEDGER_DATE), $NCB_LAG LEDGER LAG (landed before it: ledger them), $NCB_UNMEASURED UNMEASURED; read it before anything else."
if [ "$STRICT" = "1" ] && [ "$N" -gt 0 ]; then echo "STRICT: FAIL (convention not yet sealed)"; exit 1; fi
exit 0
