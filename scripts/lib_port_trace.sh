#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the SNOBOL4 statement instrumentation (the --stlimit switch; Lon 2026-09-24 16:0x: the feature is off by default and never inferred from the source, the correctness graders turn it on because the oracle always has it)
# lib_port_trace.sh -- THE ONE PORT-TRACE GATE BODY, shared by every language's test_gate_<lang>_port_trace.sh
# (GOAL-TEST-SUITE-CONSISTENCY.md standard point 6; row test-suite-consistency-seven-languages-one-standard,
# hq_T 2026-09-03). Extracted from the PAIR test_gate_pl_port_trace.sh (hq_P 2026-09-02, the only instance that
# existed) and test_gate_sno_port_trace.sh (hq_T, minted alongside this file) -- never from the single example:
# with one instance the seams are a guess, and lib_ladder.sh worked precisely because two near-identical bodies
# could be diffed to prove which tokens actually vary. Measured here: they varied in FOUR tokens and nothing else.
#
# A per-language gate sets four variables and calls port_trace_main "$@":
#   PORTTRACE_LANG      display name used in refusal text       e.g. Prolog
#   PORTTRACE_SUITE     directory under corpus/tests/           e.g. prolog
#   PORTTRACE_EXT       rungs/source extension, leading dot    e.g. .pl
#   PORTTRACE_FAMILIES  default graded families                 e.g. "probe_plz ladder"
#
# ⭐⭐ THE INSTRUMENT IS OURS, NOT THE ORACLE'S (ceo CEO-172, 2026-09-03, on hq_T's measured correction of its
# own ask). SCRIP_PL_TRACE=1 makes x86_port_hook -- installed at the GENERIC x86_jcc/x86_jmp/x86_deflabel port
# sites in src/templates/x86/x86_asm.h that every language's Byrd boxes flow through -- emit one runtime call
# per port (Call=α proceed, Redo=β recede, Exit=γ succeed, Fail=ω concede) printing "(N) D Port: box [-> target]"
# to stderr. ALL SEVEN LANGUAGES ALREADY EMIT IT with zero compiler change, so this gate is reachable for all
# seven, not the three whose oracles happen to have a tracer.
# ⛔ THE FLAG'S NAME IS STILL `SCRIP_PL_TRACE` AND THAT IS A KNOWN RULES.md LANGUAGE-IDENTITY VIOLATION -- a
# language name past the lower boundary, which test_gate_emit_no_lang.sh cannot see because it is an env var,
# not an IR branch (FINDING-2026-09-03-hq_T-all-seven-languages-already-emit-byrd-port-traces-only-the-flag-is-
# named-prolog.md). The rename to SCRIP_PORT_TRACE is a src/ change and is DISPATCHED, not taken here; this body
# reads the env var through PORT_TRACE_ENV below so the rename is one line in one file when it lands.
#
# ⛔⭐ WHAT THE REF ACTUALLY IS, AND THE LABEL IS NOT OPTIONAL: `--cut` writes ALL.trace from SCRIP'S OWN traces.
# That makes every gate over THIS body a SELF-CONSISTENCY REGRESSION PIN -- it proves the port sequence has not
# MOVED, never that it is RIGHT. Say "pinned" in every receipt that quotes one; a self-pin called an oracle diff
# is a false provenance claim, and this file exists partly so that claim is never made by accident.
#
# ⭐⭐ POINT 6 HAS TWO SHAPES, AND THIS BODY IS ONLY THE FIRST. `test_gate_icn_port_trace.sh` (ceo mint
# 2026-09-03, row icon-port-trace-gate-against-ampersand-trace) is a REAL ORACLE DIFF: iconx's `&trace := -1`
# prints one line per user-procedure activation, and that gate normalises it onto the same four Byrd ports and
# grades SCRIP against it. It is DELIBERATELY NOT built on this body and must not be "unified" into it -- its ref
# is one oracle-anchored block rather than a per-mode pair (the reference is what Icon semantics REQUIRE, so it
# cannot vary by mode by construction) and its granularity is procedure-level, not every sub-expression box.
# Folding it in would demote the strongest instrument of the seven to the weakest common shape.
#   SELF-PIN (this body): reachable for ALL SEVEN today, because x86_port_hook is language-blind.
#   ORACLE DIFF: reachable only where the oracle traces AND someone builds the normalisation. Icon: BUILT.
#     Prolog trace/0 and SNOBOL4 &TRACE emit goal/statement events that no one has yet normalised onto the four
#     ports; the Icon gate is the proof that it CAN be done, so those two are UNBUILT, not impossible. Do not
#     write "no oracle diff exists" for them -- write "not built yet", which is what is true.
#
# PER WITNESS, in both modes:
#   (1) KILLSWITCH BOTH WAYS: the mode-4 .s with no env and with the flag =0 are byte-identical; with =1 it differs.
#   (2) NO PERTURBATION: stdout and rc are identical with and without the trace, m3 and m4.
#   (3) THE TRACE MATCHES ITS REF line for line after normalisation: depth column dropped, n<k>_ node numbers
#       stripped (m3 numbers per graph, m4 per program; the ref pins the port SEQUENCE, not the numbering),
#       $2F unmangled to /, and the raw r15= field dropped (a mmap address inherited from the driver, ASLR-random
#       per run). A ref block may be a PREFIX (banner carries total= and prefix=): the first prefix lines are
#       compared AND the total line count must match, so a runaway witness is pinned whole without storing 60k lines.
#   (4) ANSWER column, informational: stdout vs the entry's .ref -- the rungs suite owns answers, this gate owns traces.
# SELECTORS over the ladder family (mutually exclusive; a request naming BOTH REFUSES rc=2 rather than guessing):
#   --to N     grade/cut rungs 0..N CUMULATIVELY.
#   --only N   grade/cut rung N ALONE -- the rung under construction, while the rungs BELOW it are still red.
#              ⭐ THE INSTRUMENT MUST BE ABLE TO ADDRESS THE RUNG BEING BUILT: a cumulative-only gate makes every
#              rung hostage to the reds beneath it, which is precisely backwards for a ladder landing one rung at a time.
# --cut rewrites corpus/tests/<suite>/ALL.trace from the live traces (the ONE way the ref changes; never hand-edit it).
# ⭐ --cut UNDER A SELECTOR IS A MERGE, NEVER A TRUNCATION: the blocks of the graded origins are re-cut and every
#   OTHER block in the ref is kept verbatim, so cutting rung 6 alone cannot silently drop rungs 0-1's refs.
# PRINTS ITS DENOMINATOR. EXIT: 0 every witness matches in both modes; 1 a mismatch, a killswitch or perturbation
# failure; 2 REFUSED (cannot measure) -- a gate that cannot measure never prints the success shape.
PORT_TRACE_ENV="${PORT_TRACE_ENV:-SCRIP_PL_TRACE}"
# ⭐ GATE_NAME is resolved from the CALLER's filename, not this library's: lib_gate.sh derives it from
# BASH_SOURCE[1], which after this indirection would read "lib_port_trace" for every language and put the
# wrong name in every refusal. Pinned here, once, before lib_gate.sh is sourced.
GATE_NAME="${GATE_NAME:-$(basename "${BASH_SOURCE[1]:-gate}" .sh)}"
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT"
. "$HERE/lib_gate.sh"
. "$HERE/lib_declared_arena.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot source lib_declared_arena.sh -- the one reader of a declared heap and stack"; exit 2; }
port_trace_main() {
  # ⛔ SCRIP / RT / T / RUNGS_DIR / RUNGS_EXT ARE DELIBERATELY NOT `local`: `local X` shadows the inherited
  # environment, so `local SCRIP` would make SCRIP=... on the command line silently unreachable and the gate
  # would grade the DEFAULT binary while you pointed it at another -- a green board about the wrong tree.
  # That exact defect was introduced and caught during the lib_ladder.sh extraction; it is not hypothetical.
  : "${PORTTRACE_LANG:?lib_port_trace.sh: PORTTRACE_LANG unset -- the per-language gate must set it}"
  : "${PORTTRACE_SUITE:?lib_port_trace.sh: PORTTRACE_SUITE unset -- the per-language gate must set it}"
  : "${PORTTRACE_EXT:?lib_port_trace.sh: PORTTRACE_EXT unset -- the per-language gate must set it}"
  TO=""; ONLY=""; ARGS=(); while [ $# -gt 0 ]; do case "$1" in --to) TO="${2:-}"; shift 2;; --to=*) TO="${1#--to=}"; shift;; --only) ONLY="${2:-}"; shift 2;; --only=*) ONLY="${1#--only=}"; shift;; *) ARGS+=("$1"); shift;; esac; done; set -- ${ARGS[@]+"${ARGS[@]}"}
  case "$TO" in ""|*[!0-9]*) [ -z "$TO" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: --to wants a rung number, got '$TO'"; exit 2; };; esac
  case "$ONLY" in ""|*[!0-9]*) [ -z "$ONLY" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: --only wants a rung number, got '$ONLY'"; exit 2; };; esac
  # ⛔ TWO SELECTORS NAME TWO DIFFERENT POPULATIONS (cumulative 0..N vs rung N alone) -- REFUSE, never silently prefer one.
  [ -z "$TO" ] || [ -z "$ONLY" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: --to $TO and --only $ONLY name two different populations (cumulative 0..N vs rung N alone) -- pass one, never both"; exit 2; }
  if [ -n "$ONLY" ]; then SELDESC="at rung $ONLY alone"; SELTAG="--only $ONLY"; elif [ -n "$TO" ]; then SELDESC="at or below rung $TO"; SELTAG="--to $TO"; else SELDESC=""; SELTAG="all families"; fi
  CUT=0; for a in "$@"; do [ "$a" = --cut ] && CUT=1; done
  gate_parse_args "$@"
  SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
  RUNGS_DIR="$S4E/corpus/tests/$PORTTRACE_SUITE"; RUNGS_EXT="$PORTTRACE_EXT"; export RUNGS_DIR RUNGS_EXT
  REF="$RUNGS_DIR/ALL.trace"; PREFIX_CAP="${PREFIX_CAP:-400}"; T="${TIMEOUT:-20}"
  gate_require_exec "$SCRIP" "scrip binary"
  gate_require "$RT/libscrip_rt.so" "runtime library"
  # ⛔ THE BINARY IS AS NEW AS src/ OR THE GATE CANNOT MEASURE (cto 2026-09-27 22:1x, from the port-trace bisect under CEO-1343):
  # a worktree whose make had refused rc 2 graded the PREVIOUS tree's binary here and stamped the NEW tree's hash on the
  # verdict -- a reading of nothing wearing a hash. The guard every other gate carries, in the ONE body all seven share.
  [ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
  gate_require "$RUNGS_DIR/ALL$PORTTRACE_EXT" "$PORTTRACE_LANG rungs suite"
  gate_require "$RUNGS_DIR/ALL.csv" "$PORTTRACE_LANG rungs suite index"
  [ "$CUT" = 1 ] || gate_require "$REF" "trace refs (run with --cut to create them)"
  . "$HERE/lib_rungs_extract.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot source lib_rungs_extract.sh"; exit 2; }
  FAMILIES="${FAMILIES:-${PORTTRACE_FAMILIES:-ladder}}"; [ -z "$TO$ONLY" ] || FAMILIES="${FAMILIES_TO:-ladder}"; origins=""
  for fam in $FAMILIES; do o=$(rungs_origins_of_family "$fam") || o=""; [ -n "$o" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no $fam origins in $RUNGS_DIR/ALL.csv -- the witnesses moved; re-point, never skip"; gate_stamp; exit 2; }; origins="$origins $o"; done
  if [ -n "$TO$ONLY" ]; then kept=""; for o in $origins; do nn=$(printf '%s\n' "$o" | sed -nE 's/^ladder__rung0*([0-9]+)_.*/\1/p'); [ -n "$nn" ] || continue
      if [ -n "$ONLY" ]; then [ "$nn" -eq "$ONLY" ] && kept="$kept $o"; else [ "$nn" -le "$TO" ] && kept="$kept $o"; fi; done; origins="$kept"
    # ⛔ AN EMPTY SELECTION IS UNMEASURED, NEVER A PASS -- a rung with no witness must refuse exactly as the ladder runner does.
    [ -n "${origins// /}" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no ladder origins $SELDESC in $RUNGS_DIR/ALL.csv"; gate_stamp; exit 2; }; fi
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; trap 'rm -rf "$W"; exit 143' TERM; trap 'rm -rf "$W"; exit 130' INT; trap 'rm -rf "$W"; exit 129' HUP
  # ⛔⭐ THE WORK DIR IS RELEASED PER ORIGIN, NOT PER RUN (ceo 2026-10-01, Lon: "find out why /tmp keeps filling and fix the root
  # problem"): every origin leaves two asm files, two objects, two linked binaries and six outputs, and a master of ~2000 entries
  # held 3.7 GB in one $W until the run ended -- several seats' sets in flight filled a 63 GB /tmp to 90%. Only the normalised
  # trace and a diff survive an origin; and a TERM/INT/HUP (an arm timeout, a seat's kill) now runs the release too, since bash
  # does not run an EXIT trap when a signal it does not trap kills it -- the 10:00 runs left 6 GB that way.
  porttrace_release() { rm -f "$W/$1.s0" "$W/$1.s0b" "$W/$1.s1" "$W/$1.s0.o" "$W/$1.s1.o" "$W/$1.bin0" "$W/$1.bin1" "$W/$1.m3.out0" "$W/$1.m3.out1" "$W/$1.m4.out0" "$W/$1.m4.out1" "$W/$1.m3.raw" "$W/$1.m4.raw" "$W/$1.cc.err"; }
  # ⛔⭐⭐ THE SOURCE FILENAME IS NORMALISED OUT, AND WITHOUT IT A SELF-PIN CANNOT BE RE-CUT AT ALL
  # (hq_T 2026-09-13, on hq_S's ask; reproduced here before landing). The SNO$STMT/stmt_mark startup
  # preamble minted at lower_snobol4.c:927 carries THE SOURCE FILE NAME as a lit_string operand, so
  # THE SAME PROGRAM, BYTE-IDENTICAL, RUN UNDER TWO DIFFERENT FILENAMES PRODUCED TWO DIFFERENT
  # NORMALISED TRACES. MEASURED on ladder__rung01_arith_divide extracted from the rebus rungs: 58
  # trace lines under each of two names, diff = exactly 4 lines, all of them the basename at node (3)
  # ("(3) Call: lit_string A.reb" vs "... zz_a_much_longer_origin_name_here.reb").
  # ⛔ WHY THAT BLOCKED A RE-CUT RATHER THAN MERELY ANNOYING ONE: rungs_extract_origin materialises
  # every witness under its ORIGIN name, 40-60 characters, so a --cut today would have written refs
  # PINNED TO THE HARNESS'S EXTRACTION BASENAME -- an instrument that reds the first time an origin is
  # renamed, and whose failing line talks about a filename instead of about ports. hq_S stopped and
  # asked rather than re-pin their lane green, which was the right call and is why this is cured in the
  # SHARED body before any language re-cuts.
  # ⭐ THE SUBSTITUTION IS BY THE KNOWN BASENAME, NOT BY A PATTERN OVER lit_string. Blinding every
  # lit_string operand would also blind a witness that legitimately prints a path-shaped string, and
  # anchoring on "the lit_string before call SNO$STMT" needs cross-line lookahead that sed does not
  # have and that would silently stop matching if the preamble grows a node. The gate WROTE the file,
  # so it knows the one string that must not survive: $2 is that basename and only that basename is
  # replaced. A witness that really does print its own filename is normalised too, which is correct --
  # such output IS filename-dependent and must never be pinned.
  norm() { local _bn="${2:-}"; grep -E '^\([0-9]+\) [0-9]+ (Call|Exit|Redo|Fail|Exception): ' "$1" \
    | sed -E 's/^(\([0-9]+\)) [0-9]+ /\1 /; s/\bn[0-9]+_//g; s/\$2F/\//g; s/ r15=0x[0-9a-f]+$//' \
    | { [ -n "$_bn" ] && sed "s@$(printf '%s' "$_bn" | sed 's/[][\\.*^$@/&]/\\&/g')@<SRC>@g" || cat; }; }
  m4build() { [ -s "$1" ] && as --64 -o "$1.o" "$1" 2>/dev/null && gcc -no-pie -o "$2" "$1.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null; }
  refblock() { awk -v o="$1" -v m="$2" '$0 ~ "^%---- " o " " m " " {on=1; next} /^%---- /{on=0} on' "$REF"; }
  refmeta()  { grep -E "^%---- $1 $2 " "$REF" | head -1 | sed -E 's/.* total=([0-9]+) prefix=([0-9]+).*/\1 \2/'; }
  n=0; bad=0; noref=0; ans_ok=0; ans_red=0; declare -a lines
  [ "$CUT" = 1 ] && : > "$W/ALL.trace"
  for o in $origins; do
    # ⛔⭐⭐ THE WITNESS IS MATERIALISED UNDER A SHORT FIXED BASENAME AND EVERY ARM INVOKES IT RELATIVE FROM $W
    # (hq_T 2026-09-13, on hq_S's measurement; the cure below REPLACES hq_T's own 9df862afc, which was correct
    # about the defect and wrong about the shape). The earlier cure normalised THE ORIGIN NAME out of the trace
    # and was proven on a RELATIVE, SHORT witness -- but this body handed $SCRIP an ABSOLUTE path inside a
    # mktemp dir, and the port-hook operand is THE ARGV STRING VERBATIM, truncated to 48 characters by the
    # " %.48s" stem at src/templates/x86/x86_asm.h:1882. So the string that reached the trace was
    # "/tmp/tmp.XXXXXXXXXX/ladder__rung01_arith_divide." -- the volatile tmp component survived, and the
    # basename the substitution was keyed on was CUT MID-NAME and never appeared whole to be replaced.
    # ⛔ HOW IT WOULD HAVE FAILED, WHICH IS THE PART THAT MADE IT URGENT: a --cut reports PASS on its own run
    # (it is comparing the traces it just wrote), and reds on the NEXT invocation when mktemp hands out a
    # different directory. A seat who cut, saw green and pushed would land a permanently red gate having never
    # seen a red -- and since e62070ca8 wired the self-pins into `make test` as REPORTED arms, that red prints
    # for every seat on every run. hq_S measured the exposed class rather than inferring it: rebus, snobol4 and
    # snocone leak the path (2 lines each); icon, pascal, prolog and raku do not. Raku was the one language
    # whose end-to-end re-cut could NOT have surfaced this, which is why hq_T's own proof came back green.
    # ⭐ WHY A SHORT FIXED NAME AND NOT A WIDER SUBSTITUTION: pinning the 48-char prefix would hard-code a
    # truncation width that lives in x86_asm.h and would fail SILENTLY the day it changes (hq_S's ruling, and
    # it is right). Making the operand short and stable instead means the substitution keyed on the known
    # basename -- the design this body already had -- simply works, and nothing here knows about 48.
    n=$((n+1)); srcbn="w$PORTTRACE_EXT"; src="$W/$srcbn"; ref="$W/$o.ref"
    rm -f "$W/$srcbn" "$W/${srcbn%.*}.in"
    rungs_extract_origin "$o" "$src" "$ref" >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot extract $o from the rungs suite"; gate_stamp; exit 2; }
    (cd "$W" && timeout -k 5 "$T" "$SCRIP" --compile -o "$o.s0" "$srcbn" </dev/null >/dev/null 2>"$W/$o.cc.err"); crc=$?; (cd "$W" && env "$PORT_TRACE_ENV=0" timeout -k 5 "$T" "$SCRIP" --compile -o "$o.s0b" "$srcbn" </dev/null >/dev/null 2>&1)
    # ⛔⭐ A WITNESS THAT NEVER COMPILED HAS NOTHING TO TRACE, AND THAT IS NOT A TRACER THAT IS NOT FIRING (row
    # port-trace-zero-lines-check-cannot-tell-a-compile-time-refusal-from-a-tracer-that-is-not-firing; seat09's
    # find, hq_C's ruling, cfo 2026-09-07). The zero-trace-lines check below used to fold THREE causes into one
    # message and rule out only the first ('no ports'): a broken tracer and a program the front end REFUSED
    # (pl_refuse on an un-laddered builtin, rc=2, identical with and without the trace env) read the same, and
    # the gate exit-2'd at the first such origin so every rung above it was wired and never ran. The compile is
    # established FIRST: a refusal is a named RED ROW for that witness, counted in the verdict, and the walk goes
    # on to the next origin; only a witness that compiled and ran yet traced nothing is the instrument's fault.
    if [ "$crc" -ne 0 ] && [ ! -s "$W/$o.s0" ]; then
      bad=$((bad+1)); ccmsg="$(grep -v '^$' "$W/$o.cc.err" | head -1 | cut -c1-140)"
      if [ "$crc" -eq 124 ]; then lines+=("$(printf '%-40s REFUSES AT COMPILE TIME: --compile did not finish within %ss (rc=124) -- nothing was emitted, so there is nothing to trace: a red witness, not a tracer that is not firing' "$o" "$T")")
      else lines+=("$(printf '%-40s REFUSES AT COMPILE TIME (--compile rc=%s: %s) -- nothing was emitted, so there is nothing to trace: a red witness (cure the refusal, or move it out of the graded population with a named reason), not a tracer that is not firing; neither mode is measured for it' "$o" "$crc" "${ccmsg:-no diagnostic on stderr}")"); fi
      porttrace_release "$o"
      continue
    fi
    (cd "$W" && env "$PORT_TRACE_ENV=1" timeout -k 5 "$T" "$SCRIP" --compile -o "$o.s1" "$srcbn" </dev/null >/dev/null 2>&1)
    ks=OK; { cmp -s "$W/$o.s0" "$W/$o.s0b" && [ -s "$W/$o.s0" ] && ! cmp -s "$W/$o.s0" "$W/$o.s1"; } || { ks=FAIL; bad=$((bad+1)); }
    # the m3 arms are the ones that did NOT cd into $W, so they are where the absolute path entered the trace
    # each run at the heap and stack the entry declares: extract writes them beside the witness as w.heap / w.stack, keyed by the
    # witness's own stem (ceo CEO-1353, RULES.md clause 8 (g); the coo 2026-10-03: these four runs passed no declaration)
    psw="$(declared_switches_beside "$src")" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $o: a .heap or .stack sidecar the reader refuses"; gate_stamp; exit 2; }
    (cd "$W" && timeout -k 5 "$T" "$SCRIP" --run $psw "$srcbn" </dev/null >"$W/$o.m3.out0" 2>/dev/null); r30=$?
    (cd "$W" && env "$PORT_TRACE_ENV=1" timeout -k 5 "$T" "$SCRIP" --run $psw "$srcbn" </dev/null >"$W/$o.m3.out1" 2>"$W/$o.m3.raw"); r31=$?
    pert3=OK; { [ "$r30" = "$r31" ] && cmp -s "$W/$o.m3.out0" "$W/$o.m3.out1"; } || { pert3=FAIL; bad=$((bad+1)); }
    pert4=OK; r40=?; r41=?
    if m4build "$W/$o.s0" "$W/$o.bin0" && m4build "$W/$o.s1" "$W/$o.bin1"; then
      timeout -k 5 "$T" "$W/$o.bin0" $psw </dev/null >"$W/$o.m4.out0" 2>/dev/null; r40=$?
      env "$PORT_TRACE_ENV=1" timeout -k 5 "$T" "$W/$o.bin1" $psw </dev/null >"$W/$o.m4.out1" 2>"$W/$o.m4.raw"; r41=$?
      { [ "$r40" = "$r41" ] && cmp -s "$W/$o.m4.out0" "$W/$o.m4.out1"; } || { pert4=FAIL; bad=$((bad+1)); }
    else pert4=NOBUILD; bad=$((bad+1)); : > "$W/$o.m4.raw"; fi
    cmp -s "$W/$o.m3.out0" "$ref" && { ans=ok; ans_ok=$((ans_ok+1)); } || { ans=RED; ans_red=$((ans_red+1)); }
    tr3=?; tr4=?
    for m in m3 m4; do
      norm "$W/$o.$m.raw" "$srcbn" > "$W/$o.$m.norm"; total=$(wc -l < "$W/$o.$m.norm")
      # the m4 twin of the compile-time refusal: a binary that was never built traced nothing, and pert4=NOBUILD already counted it
      if [ "$m" = m4 ] && [ "$pert4" = NOBUILD ]; then tr4="NOBUILD"; continue; fi
      [ "$total" -gt 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $o $m: the witness COMPILED (rc=0) and ran, yet $PORT_TRACE_ENV=1 produced ZERO trace lines -- the instrument is not firing; this is not 'no ports' and not a compile-time refusal (a refusal is a named row, never this message)"; gate_stamp; exit 2; }
      if [ "$CUT" = 1 ]; then
        # ⛔⭐⭐ A CUT REFUSES RATHER THAN BAKE THE VOLATILE WORKDIR INTO A REF. hq_S's procedural ask was
        # "grade a cure by CUTTING AND THEN RE-RUNNING, never by the cut's own verdict" -- which is right, and
        # which is exactly the kind of duty no procedure reliably keeps, because the cut's own run is GREEN by
        # construction: it compares the traces it just wrote. So the instrument enforces it instead. $W is a
        # fresh mktemp dir on every invocation, so any $W component surviving into a normalised line is, by
        # definition, a string that CANNOT match on the next run -- a ref written from it is red forever, and
        # the seat who wrote it never saw a red. This is the one check that can catch that at cut time.
        if grep -qF -- "$W" "$W/$o.$m.norm"; then
          echo "GATE UNPROVEN(2) [$GATE_NAME]: $o $m: --cut REFUSED -- $(grep -cF -- "$W" "$W/$o.$m.norm") normalised line(s) still carry this run's throwaway work directory ($W), so the ref would pin a path that cannot exist on the next invocation and the gate would be RED FOREVER while this cut reported PASS. First such line:"
          grep -nF -- "$W" "$W/$o.$m.norm" | head -1
          echo "  the witness is invoked as the short relative basename '$srcbn' from \$W precisely so the port-hook operand is stable; a path reaching the trace by some OTHER route is a new leak and must be normalised at its source, never pinned"
          gate_stamp; exit 2; fi
        p=$total; [ "$p" -gt "$PREFIX_CAP" ] && p=$PREFIX_CAP
        { echo "%---- $o $m total=$total prefix=$p"; head -n "$p" "$W/$o.$m.norm"; } >> "$W/ALL.trace"; v=CUT
      else
        meta=$(refmeta "$o" "$m"); rt=${meta%% *}; rp=${meta##* }
        # ⛔⭐⭐ NOREF IS A CANNOT-MEASURE, NOT A FAILED CHECK (hq_T 2026-09-11, on the ceo's finding that these
        # gates are wired into no recipe and that icn reads "22 failed checks of 24"). A witness with NO REF BLOCK
        # has never been pinned; the gate learned nothing about it. Counting it into `bad` publishes a backlog that
        # looks like defects and is not one -- MEASURED across all six self-pin gates plus icn: 218 of the failed
        # checks are NOREF, and ZERO witnesses have a wrong answer or a failed killswitch. icn's 22 of 24 is exactly
        # 11 unpinned witnesses x 2 modes; its one pinned witness passes both modes.
        # ⭐ THE TELL THAT THIS IS THE INSTRUMENT AND NOT THE COMPILER: every row reads killswitch=OK perturb=OK
        # answer=ok, and only the trace column speaks. A real port-order regression cannot leave the answer correct
        # in both modes across 130 witnesses.
        # ⭐⭐ AND THE BODY ALREADY KNEW THE DISTINCTION TWO LINES ABOVE: a witness that compiles and emits ZERO
        # trace lines REFUSES rc=2 with "the instrument is not firing; this is not 'no ports'". The same function
        # draws the cannot-measure/fail line correctly for one absence and wrongly for the other. ⛔ A FAIL AND A
        # CANNOT-MEASURE ARE DIFFERENT FACTS -- rc=1 sends a reader hunting a defect in the compiler that is really
        # an unpinned witness. The lane cured this exact shape once already in test_icon_ir_rung_03.sh; it survived
        # here because it was filed as a fact about that script instead of a fact about verdicts.
        if [ -z "$meta" ]; then v=NOREF; noref=$((noref+1))
        elif [ "$rt" != "$total" ]; then v="FAIL(total $total != ref $rt)"; bad=$((bad+1))
        elif ! refblock "$o" "$m" | cmp -s - <(head -n "$rp" "$W/$o.$m.norm"); then v="FAIL(diff within first $rp)"; bad=$((bad+1)); refblock "$o" "$m" | diff - <(head -n "$rp" "$W/$o.$m.norm") | head -6 | sed 's/^/        /' > "$W/$o.$m.diff"
        else v="ok($total)"; fi
      fi
      [ "$m" = m3 ] && tr3="$v" || tr4="$v"
    done
    lines+=("$(printf '%-40s killswitch=%-4s perturb m3=%-4s m4=%-7s trace m3=%-22s m4=%-22s answer=%s' "$o" "$ks" "$pert3" "$pert4" "$tr3" "$tr4" "$ans")")
    for m in m3 m4; do [ -f "$W/$o.$m.diff" ] && lines+=("$(cat "$W/$o.$m.diff")"); done
    porttrace_release "$o"
  done
  printf '%s\n' "${lines[@]}"
  if [ "$CUT" = 1 ]; then
    if [ -n "$TO$ONLY" ] && [ -f "$REF" ]; then
      printf '%s\n' $origins > "$W/graded.txt"
      awk -v gl="$W/graded.txt" 'BEGIN{while ((getline l < gl) > 0) g[l]=1} /^%---- /{keep = !($2 in g)} keep' "$REF" > "$W/kept.trace"
      cat "$W/kept.trace" "$W/ALL.trace" > "$REF"; echo "refs CUT (merged, $SELTAG re-cut, other blocks kept) -> $REF ($(grep -c '^%---- ' "$REF") blocks, prefix cap $PREFIX_CAP)"
    else cp "$W/ALL.trace" "$REF"; echo "refs CUT -> $REF ($(grep -c '^%---- ' "$REF") blocks, prefix cap $PREFIX_CAP)"; fi
  fi
  echo "witnesses=$n ($SELTAG) modes=2 (m3 --run, m4 --compile+as+gcc) . answer ok=$ans_ok red=$ans_red (informational: the rungs suite grades answers) . normalisation: depth dropped, n<k>_ stripped, \$2F->/, r15= dropped"
  # ⛔⭐ A RUNNER THAT GRADED ZERO TRACE CHECKS REFUSES rc=2 RATHER THAN PRINTING THE SUCCESS SHAPE. With
  # NOREF correctly out of `bad`, a gate whose witnesses are ALL unpinned would otherwise report
  # "0 failed checks" -- the cleanest possible green over a measurement that never happened, and strictly
  # worse than the false red it replaces. ⭐ This is the ladder-runner rule of GOAL-TEST-SUITE-CONSISTENCY
  # arriving in the trace family: it prints its denominator, and it refuses when the denominator is zero.
  _pinned=$(( n*2 - noref ))
  if [ "$noref" -gt 0 ]; then
      echo "⛔ $noref of $((n*2)) trace check(s) have NO REF BLOCK and were NOT graded -- unpinned witnesses are a CANNOT-MEASURE, never a failed check. Re-cut with the gate's own CUT mode; until then this gate speaks for $_pinned check(s) only."
  fi
  if [ "$_pinned" -le 0 ]; then
      echo "GATE UNPROVEN(2) [$GATE_NAME]: every one of the $((n*2)) trace check(s) is unpinned (NOREF), so this gate graded NOTHING. A runner that cannot measure must not print a verdict."
      gate_stamp; exit 2
  fi
  echo "trace checks graded=$_pinned of $((n*2)) (unpinned/NOREF=$noref, out of the denominator and named above)"
  GATE_EXAMINED=$((n*2)); gate_verdict "$bad" "failed checks across killswitch/perturbation/trace"
}
