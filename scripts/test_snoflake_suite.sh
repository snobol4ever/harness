#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${SNOFLAKE_SUITE:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/corpus/packages/snobol4/snoflake_suite}" || exit 2
# ⛔ THE STATEMENT INSTRUMENTATION (--stlimit) IS EACH PROGRAM'S OWN compile_args DECLARATION, read per program below (clause 8 (f), CEO-1281): this runner exported SCRIP_SNO_STMTKW=1 for every program until 2026-09-26 (Lon 2026-09-24 16:0x: off by default, never inferred from the source)
# test_snoflake_suite.sh — run Ori Livneh's snoflake fixture suite against SCRIP m3 + m4, plus a
# SPITBOL comparison arm (ARM_SBL=0 to disable).
#
# Suite: corpus/packages/snobol4/snoflake_suite (vendored from github.com/atdt/snoflake test/programs,
# BSD-2-Clause, commit 54f7b801 — see PROVENANCE.md there). Each .sno is a self-describing fixture:
# a header of '*' comment lines carrying @directives, then a program that runs unmodified.
#   @expect (block '* @expect >>>' .. '* <<<' or single-line)  expected output
#   @input  (block)                                            stdin lines
#   @match  exact (default) | substring | error, optional /i   grading mode
#   @nonstandard                                               implementation-defined output
# Block payload strip per upstream test/program-fixture.js: '* <<<' ends, '*' -> empty line,
# '* xxx' -> 'xxx' (exactly the two chars '* ' removed).
#
# ⭐⭐ GRADING IS AGAINST THE ORACLE, NOT AGAINST @expect (ceo CEO-251, 2026-09-04, ruling (a) on hq_B's ask
# `q-snoflake-denominator-vs-the-dialect-law`). A fixture PASSES when SCRIP's output equals `sbl -bf`'s. The
# fixture's own @expect is INFORMATIONAL and is still graded, but only to compute the dialect tally.
# WHY: snoflake tracks SIL 3.11 / CSNOBOL4 and SCRIP follows SPITBOL (RULES.md Semantics), so two thirds of
# this suite's @expect failures were SCRIP agreeing with SPITBOL, i.e. being right. Grading against the oracle
# scores what the law actually requires; the denominator stays 180 and 100% means every fixture matching SPITBOL.
# ⛔ TWO NORMALIZATIONS, BOTH MEASURED, AND THE RULE IS MEANINGLESS WITHOUT THEM:
#   (1) SPITBOL emits its OWN furniture into the compared stream -- banner, `x86-64 <date>`, page headers and a
#       statement listing -- on 56 of these 180 fixtures, driven by `-LIST` control lines INSIDE the fixtures,
#       not by our flags (`-b` already suppresses the signon). Diverted via lib_oracle_flags.sh's
#       sbl_listing_sink_flag (56 -> 0). ⛔ That flag FAILS OPEN: `-o file open error.` in the oracle's output
#       means the listing came back and every comparison is invalid, so this runner REFUSES rc=2 on it rather
#       than scoring the fixture -- a silently re-furnished stream is exactly the false all-FAIL table class.
#   (2) Error TEXT never matches byte-for-byte and never will: SCRIP says
#       `SCRIP: ERROR 248 -- attempted redefinition of system function: SORT` where sbl says
#       `t.sno(40) : ERROR 248 -- attempted redefinition of system function` -- the SAME refusal, with the
#       file/line on one side and the offending name on the other. So errors compare by ERROR NUMBER.
# ⭐ THE DIALECT TALLY is printed beside the score and never folded into it: fixtures that PASS against the
# oracle while FAILING their own @expect, i.e. where SPITBOL itself departs from what snoflake expects.
# @nonstandard fixtures tally as NSTD-PASS/-FAIL and never count in FAIL (implementation-defined output).
#
# ⚠ DIALECT: snoflake tracks SIL 3.11 / CSNOBOL4, NOT SPITBOL. SCRIP follows SPITBOL semantics.
# A FAIL here may be dialect distance, not a defect — check before curing (RULES.md dialect law).
# The @options directive (3 fixtures: case-folding, stlimit) is NOT honored by this runner; those
# fixtures are listed in the OPTS line and their verdicts carry that caveat.
#
# ⛔ A missing suite, compiler, RT, or oracle REFUSES with rc=2 — never skip-as-success
# (FINDING-2026-08-24-hq_C-the-regrid-turned-a-red-board-green.md).
# Exit: 0 iff FAIL3=0 and FAIL4=0 and SKIP(cc)=0 over the printed denominator (verdict = matches the oracle).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; SD="$HERE/../../SCRIP"; ROOT="$(cd "$HERE/../.." && pwd)"   # the root holds its repos as siblings, SCRIP or not
SUITE="${SNOFLAKE_SUITE:-$ROOT/corpus/packages/snobol4/snoflake_suite}"
SCRIP="$SD/scrip"; RT_DIR="$SD/out"; TIMEOUT="${TIMEOUT:-8s}"; ARM_SBL="${ARM_SBL:-1}"; ARM_CSN="${ARM_CSN:-1}"
[ -d "$SUITE" ] || { echo "⛔ REFUSE(rc=2): suite dir missing: $SUITE — a missing corpus is not a green board"; exit 2; }
# ⭐ UNDER A PORT ENGINE THIS RUNNER GRADES THE PORT WITH ITS OWN GRADING (S4E_ENGINE=dotnet|jvm; CEO-1822; Lon 2026-10-18, in-chat to hq_dotnet,
# verbatim: "Get all SNOBOL4 package runners working with snobol4dotnet."): SCRIP is the port's face (one_runner_port_face), the port runner's
# --binaries is the one check, each fixture runs in m3 alone with its declared heap and stack as switches, its rows are keyed snoflake@<engine>
# by the one writer, and no SCRIP score row is written -- the port's row is from-progress. Under scrip every line below reads as it did.
PORT=0; one_runner_is_port && PORT=1
ROWKEY=snoflake; [ "$PORT" = 1 ] && ROWKEY="snoflake@$(one_runner_engine)"
if [ "$PORT" = 1 ]; then SCRIP="$(one_runner_port_face)"; one_runner_port_ready snobol4 || exit 2; else
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2): no scrip binary at $SCRIP — build first (make)"; exit 2; }
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). The line above proves a binary EXISTS; this one proves it is the binary this
# tree describes. ceo's witness, twice on 2026-09-04: a 10:57 binary graded at 14:03 read RED, then GREEN after
# an incremental make -- a vendor board is exactly where that is least visible, because a plausible all-FAIL
# table is this class's normal output. NO LOGIC HERE: util_require_fresh.sh sources gate_require_fresh from
# lib_gate.sh, the ONE authority (hq_B 4c7253e99) -- never a second copy of the staleness rule.
"$HERE/util_require_fresh.sh" --gate test_snoflake_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
[ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ REFUSE(rc=2): no $RT_DIR/libscrip_rt.so"; exit 2; }
fi
. "$HERE/lib_inventory.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_inventory.sh unloadable"; exit 2; }
. "$HERE/lib_progress.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_progress.sh unloadable"; exit 2; }
SBL=""
if [ "$ARM_SBL" = "1" ]; then
    . "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_oracle_flags.sh unloadable and ARM_SBL=1"; exit 2; }
    SBL="$(sbl_correctness_bin)"; SBL_FLAGS="$(sbl_lang_flags)"
    [ -x "$SBL" ] || { echo "⛔ REFUSE(rc=2): oracle absent: $SBL — set ARM_SBL=0 to survey without it"; exit 2; }
fi
CSN=""
if [ "$ARM_CSN" = "1" ]; then
    # ⛔ ASSET ROOT FIRST, WORKSPACE ROOT ONLY AS A FALLBACK (hq_C 2026-08-28).  The original spelling looked ONLY at
    # "$SD/../csnobol4/snobol4" -- INSIDE the seat's workspace root -- which contradicts two standing rules at once:
    # CLAUDE.md's "the oracles are NOT siblings here, they live outside every root" (sbl, icont/iconx and swipl are all
    # reached by asset path), and the handoff law, because handoff_status.sh AUTO-DISCOVERS every top-level directory
    # that is a git repo with an origin remote -- so a csnobol4 clone placed where this line wanted it becomes a
    # PERMANENT handoff blocker the moment it has a local commit, on a remote we do not own.  ⭐ The sibling script
    # build_csnobol4_archive.sh already resolves it as "$S4A/csnobol4" (asset root); this line was the odd one out, and
    # the disagreement was invisible because whoever wrote it had the tree in the one place that worked for them.
    CSN_ASSET="${S4E_ASSETS:-$([ -d "$SD/../x64" ] && echo "$SD/.." || echo /home/resources)}/csnobol4/snobol4"
    if [ -x "$CSN_ASSET" ]; then CSN="$CSN_ASSET"; else CSN="$SD/../csnobol4/snobol4"; fi
    [ -x "$CSN" ] || { echo "⛔ REFUSE(rc=2): csnobol4 absent: $CSN — set ARM_CSN=0 to survey without it (triangulation arm, Lon 2026-08-28)"; exit 2; }
fi
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# ⛔⭐ ARM_SBL=0 IS NO LONGER A SURVEY MODE, IT IS A REFUSAL. Before CEO-251 the oracle was one informational
# arm among four and switching it off cost you a column. It is now THE VERDICT, so with it off every fixture
# would be compared against an empty string and this script would print a full, plausible, entirely FALSE
# all-FAIL table -- the exact class RULES.md and this file's own header warn about. Grading cannot be
# downgraded to a survey by an env var.
[ "$ARM_SBL" = "1" ] || { echo "⛔ REFUSE(rc=2): ARM_SBL=0 but the verdict IS the oracle since CEO-251 -- without sbl there is nothing to grade against, and an ungraded run must never print a board"; exit 2; }
SBL_SINK=""
[ -n "$SBL" ] && { SBL_SINK="$(sbl_listing_sink_flag "$W")" || { echo "⛔ REFUSE(rc=2): no writable listing sink for the oracle -- SPITBOL FAILS OPEN on -o= and would dump its listing back into the compared stream"; exit 2; }; }
# ⭐ SCRIP'S OWN SINK, A SEPARATE FILE FROM THE ORACLE'S (coo-2026-10-01 regression, row snobol4-the-list-control-line-
# prints-no-source-listing...): since SCRIP's -LIST/-NOLIST now produces a listing too (rt_sno_list_d), it has to be
# diverted off the compared stream exactly where the oracle's is, or every fixture with a control line in SUITE
# fails on line 1 of its own listing banner. Never the SAME path as $SBL_SINK -- that file is deleted and re-read
# by the sbl arm's &DUMP recovery (above) and must hold only SPITBOL's own content.
SCRIP_LIST_SINK=""
[ -n "$SBL_SINK" ] && SCRIP_LIST_SINK="$W/scrip_listing.lst"
GIMPEL="$SUITE/gimpel"
# ⛔ ALL ARMS RUN WITH cwd IN SCRATCH, never in a repo tree: OUTPUT unit-I/O associations create
# files named by their third argument (SPITBOL dialect: a FILE SPEC, e.g. '(121A1)') in the cwd,
# which dirties whatever tree the runner happened to be launched from. Copied INCs keep the
# gimpel includes resolvable for the sbl arm, whose include search is cwd-relative.
RUN="$W/run"; mkdir -p "$RUN"; cp -p "$GIMPEL"/*.INC "$GIMPEL"/*.IN "$RUN"/ 2>/dev/null || true
# ⭐ THE DECLARED HEAP AND STACK (Lon 2026-09-23 18:3x; CEO-1167, CEO-1225; wired by the coo on CEO-1229, the SWI runner's pattern):
# each fixture runs in BOTH modes at what its row in ALL.csv declares -- heap_kb, stack_kb, read once through lib_declared_arena.sh,
# the one reader -- and at the shipped default when it declares nothing; a refused cell refuses the board. The oracle runs as before.
# Line 2 hands the guard the same suite this runner grades (SNOFLAKE_SUITE), so a scratch fixture is judged as one.
. "$HERE/lib_declared_arena.sh" || { echo "⛔ REFUSE(rc=2): lib_declared_arena.sh unloadable -- the one reader of a declared heap and stack"; exit 2; }
DECL="$W/declared_memory.tsv"
declared_memory_begin "$SUITE/ALL.csv" "$DECL" || { echo "⛔ REFUSE(rc=2): a declared-memory cell in $SUITE/ALL.csv is refused (named above) -- fix the cell; this board does not grade around it"; exit 2; }
# ⭐ THE PROGRESS DATABASE (CEO-319/331; CEO-383 ruling 2; row snobol4-snoflake-aisnobol-and-dotnet-runners-wired-onto-
# lib-inventory-with-their-sidecars, coo 2026-09-07): ONE ROW PER FIXTURE PER MODE, on the STREAM-EQUAL basis --
# PASS only when SCRIP's stream equals the oracle's byte for byte; an error-number-only match is UNGRADED (this
# runner's own label for it: a narrower instrument, never a pass of the industry-standard suite); a non-matching
# stream is HANG (rc 124) / CRASH (rc >= 128) / FAIL; SKIP when mode 4 could not compile or link; an @nonstandard
# fixture that does not match is UNGRADED (implementation-defined output, the same reason it never counts in FAIL).
# Rows are recorded ONLY for the canonical suite path, or when S4E_PROGRESS_DB names a scratch table (the gates'
# hermetic arm) -- a scratch suite copy never reaches the live table (progress/README.md). The rows are collected
# here and written ONCE at the end through lib_progress.sh, the one writer; a write failure is said aloud and never
# turns a real measurement into a red board.
PROG_ROWS="$W/progress.tsv"; : > "$PROG_ROWS"
CANON_SUITE="$ROOT/corpus/packages/snobol4/snoflake_suite"
PROG_RECORD=0; { [ "$SUITE" = "$CANON_SUITE" ] || [ -n "${S4E_PROGRESS_DB:-}" ]; } && PROG_RECORD=1
ST3=0; ST4=0; BOTH_STREAM=0
# ⭐ THE SPITBOL BASELINE (Lon 2026-09-08, in-chat to ceo: "I just asked how many programs that DO pass SPITBOL, and do NOT
# pass SCRIP"; RULES sec Oracles, the one-oracle FACT RULE): a fixture SPITBOL itself cannot run -- its own stream carries
# ERROR NNN -- is OUTSIDE the baseline and out of the denominator. The suite table states both_modes_pass/baseline. The
# record of the outside set is OUTSIDE_SPITBOL_BASELINE.tsv beside the suite, mirrored by UNGRADABLE.tsv (name, ORACLE_REFUSES, the SPITBOL error and a source
# check per program); the live set is measured every run and any drift between the two is said aloud below.
BASE=0; BASE_BOTH=0; OUTSIDE_N=0; OUTSIDE_LIST=""; OUTSIDE_TSV="$SUITE/OUTSIDE_SPITBOL_BASELINE.tsv"; MIRROR_TSV="$SUITE/UNGRADABLE.tsv"
# ⛔⭐ SPITBOL ALSO REFUSES WITHOUT AN ERROR NUMBER, and the numbered-only test above missed it (ceo
# 2026-09-08, re-measured by the coo at a296d8d04): `sbl -bf` on a source whose only END is the
# lowercase `end` prints `No END statement found in source file(s).` and EXITS 1 -- SPITBOL never runs
# the program, so the fixture is outside the baseline exactly as a numbered refusal is, but it carries
# no `ERROR NNN` for the classifier to key on and sat in the reds as if it were our defect.
# ⛔ THE MATCHER KEYS ON THE MESSAGE, NEVER ON THE rc, and that is deliberate: the coo first recorded
# this refusal as rc=0 by reading `$?` at the end of a PIPELINE (`sbl ... | head`), which reports head's
# status and not the oracle's; the ceo re-measured it as rc=1 the same evening. A matcher built on the
# wrong rc would simply never fire. The message shape is what was actually observed on both files.
# ⛔ MEASURED ONLY: add a pattern here when a run has SHOWN it, never because it seems plausible --
# every pattern here silently moves fixtures OUT of the denominator, which is the direction that
# flatters the board. One pattern per line, each with the date and seat that measured it.
ORACLE_REFUSAL_RE='No END statement found in source file'   # measured 2026-09-08 (ceo, coo)
prog_row() { [ "$PORT" = 1 ] && [ "$2" = m4 ] && return 0; printf 'package\tsnoflake\tsnobol4\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$(progress_row_secs "$2")" "$4" >> "$PROG_ROWS"; }   # secs: ROW_S3/ROW_S4, each mode's own wall (CEO-1676 (c))
verdict_of() { if [ "$1" -eq 124 ]; then echo HANG; elif [ "$1" -ge 128 ]; then echo CRASH; else echo FAIL; fi; }
SCRIP_HASH="$(git -C "$SD" rev-parse --short HEAD 2>/dev/null || echo '?')"
TREE_LABEL="SCRIP $SCRIP_HASH"; [ "$PORT" = 1 ] && TREE_LABEL="engine $(one_runner_port_tree)"
CORP_HASH="$(git -C "$ROOT/corpus" rev-parse --short HEAD 2>/dev/null || echo '?')"
DIA=0; DIAL=""; ORACLE_OUT=""; ORACLE_MEETS_EXPECT=0; P3=0; F3=0; P4=0; F4=0; S4=0; PS=0; FS=0; PC=0; FC=0; N3P=0; N3F=0; N4P=0; N4F=0; NSP=0; NSF=0; NCP=0; NCF=0
FL3=""; FL4=""; FLS=""; FLC=""; OPTS_LIST=""; TOTAL=0
# ⭐ CENSUS (task snobol4-snoflake-pass-census-splits-stream-equality-from-error-number-only-passes,
# hq_P 2026-09-06): splits mode-3 PASS into (a) SE3 -- scrip's stream literally equals the oracle's,
# and (b) EN3 -- equal ONLY via oracle_equal's ERROR-NUMBER fallback (wording never matches, so this
# is UNGRADED-BY-A-NARROWER-INSTRUMENT, not a weaker pass). SE3+EN3 == P3 by construction (every m3
# PASS sets OE_KIND to exactly one of the two before either counter is touched).
SE3=0; EN3=0; ENL3=""
parse_fixture() { # $1=sno -> writes $W/exp $W/inp; echoes "match ic nstd hasinp opts"
    local match=exact ic=0 nstd=0 hasinp=0 opts=0 inblock="" line payload rest
    : > "$W/exp"; : > "$W/inp"; : > "$W/masks"
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in '*'*) ;; *) break;; esac
        if [ -n "$inblock" ]; then
            if [ "$line" = '* <<<' ]; then inblock=""; continue; fi
            if [ "$line" = '*' ]; then payload=""
            elif [ "${line:0:2}" = '* ' ]; then payload="${line:2}"
            else continue; fi
            case "$inblock" in expect) printf '%s\n' "$payload" >> "$W/exp";;
                               input)  printf '%s\n' "$payload" >> "$W/inp";; esac
            continue
        fi
        case "$line" in
            '* @expect >>>'*) inblock=expect;;
            '* @input >>>'*)  inblock=input; hasinp=1;;
            '* @expect '*)    rest="${line#\* @expect }"; rest="${rest#"${rest%%[![:space:]]*}"}"; printf '%s\n' "$rest" >> "$W/exp";;
            '* @match '*)     rest="${line#\* @match }"; rest="${rest#"${rest%%[![:space:]]*}"}"
                              case "$rest" in */i) ic=1; rest="${rest%/i}";; esac; match="$rest";;
            # ⭐⛔ CEO-409 -- THE EXCLUSION IS AT THE LINE, NOT AT THE PROGRAM. A fixture SPITBOL runs clean
            # and we run clean, differing only in a value that belongs to the IMPLEMENTATION rather than to
            # the program (SPITBOL's own free-space count), is neither outside the baseline -- the oracle runs
            # it fine -- nor a legitimate red, because a red asserts a defect and this one can never go green
            # whatever anybody writes, which is A CRITERION THAT CANNOT SAY YES. It stays IN the denominator,
            # graded on every line carrying language semantics, with the one implementation-defined line named,
            # masked and COUNTED. Shape: `* @mask-line <ERE> :: <reason>`. THE REASON IS MANDATORY (guardrail 2:
            # the mask names the line AND the reason, in the fixture beside the data, never in this runner) and
            # a mask without one is REFUSED, not ignored -- see the arming checks at the call site for
            # guardrails 1 and 4. Every masked line is counted and printed beside the board (guardrail 3),
            # because an invisible mask is a machine for hiding reds and a printed one is a measurement.
            '* @mask-line '*) rest="${line#\* @mask-line }"; rest="${rest#"${rest%%[![:space:]]*}"}"
                              printf '%s\n' "$rest" >> "$W/masks";;
            '* @nonstandard'*) nstd=1;;
            '* @options '*)   opts=1;;
        esac
    done < "$1"
    echo "$match $ic $nstd $hasinp $opts"
}
# ⛔ THE GUARDRAILS ARE ENFORCED HERE, NOT TRUSTED TO THE FIXTURE AUTHOR (CEO-409). mask_arm reads
# $W/masks, refuses rc=2 on any mask that (a) carries no reason, or (b) could ever cover an ERROR number
# or a control-flow outcome -- guardrail 4, checked by running the pattern against probe lines rather
# than by reading it, so a clever regex cannot talk its way past. MASK_PATS is newline-joined EREs.
MASK_TOKEN='⟨masked: implementation-defined value, see @mask-line in the fixture⟩'
MASKED_LINES=0; MASKED_FIX=0; MASKED_LIST=""
mask_arm() { # $1=fixture name -> sets MASK_PATS MASK_N ; refuses rc=2 on an unearned mask
    MASK_PATS=""; MASK_N=0
    [ -s "$W/masks" ] || return 0
    local raw pat why probe
    while IFS= read -r raw; do
        [ -n "$raw" ] || continue
        case "$raw" in *' :: '*) ;; *)
            echo "⛔ REFUSE(rc=2): $1 carries a @mask-line with no reason: '$raw'"
            echo "   CEO-409 guardrail 2 -- the mask names the LINE and the REASON, in the fixture, beside the data."
            echo "   Shape: * @mask-line <ERE> :: <why this value belongs to the implementation, and the measurement that showed it>"; exit 2;; esac
        pat="${raw%% :: *}"; why="${raw#* :: }"
        [ -n "$why" ] || { echo "⛔ REFUSE(rc=2): $1 has an empty reason on @mask-line '$pat' (CEO-409 guardrail 2)"; exit 2; }
        for probe in 'ERROR 042 -- attempt to change value of protected variable' 'f.sno(9) : ERROR 248 -- attempted redefinition of system function' 'No END statement found in source file(s).'; do
            if printf '%s\n' "$probe" | grep -qE "$pat"; then
                echo "⛔ REFUSE(rc=2): $1's @mask-line '$pat' also covers a diagnostic the board must never hide:"
                echo "   it matches: $probe"
                echo "   CEO-409 guardrail 4 -- a mask may NEVER cover an ERROR number, a control-flow outcome, or any value computed from the program's own data."; exit 2
            fi
        done
        MASK_PATS="${MASK_PATS}${pat}
"; MASK_N=$((MASK_N+1))
    done < "$W/masks"
    return 0
}
mask_apply() { # $1=stream -> echoes the stream with masked lines replaced by MASK_TOKEN
    if [ "${MASK_N:-0}" = 0 ]; then printf '%s' "$1"; return; fi
    printf '%s' "$1" | awk -v pats="$MASK_PATS" -v tok="$MASK_TOKEN" 'BEGIN{n=split(pats,P,"\n")} {for(i=1;i<=n;i++) if(P[i]!="" && $0 ~ P[i]) {print tok; next} } {print $0}'
}
mask_count() { # $1=oracle stream -> echoes how many of ITS lines the arming masks cover
    if [ "${MASK_N:-0}" = 0 ]; then echo 0; return; fi
    printf '%s' "$1" | awk -v pats="$MASK_PATS" 'BEGIN{n=split(pats,P,"\n")} {for(i=1;i<=n;i++) if(P[i]!="" && $0 ~ P[i]) {c++; next} } END{print c+0}'
}
grade() { # $1=got $2=rc $3=match $4=ic ; expects $W/exp; returns 0 pass
    local got="$1" rc="$2" match="$3" ic="$4" exp; exp="$(cat "$W/exp")"
    if [ "$ic" = 1 ]; then got="$(printf '%s' "$got" | tr '[:upper:]' '[:lower:]')"; exp="$(printf '%s' "$exp" | tr '[:upper:]' '[:lower:]')"; fi
    case "$match" in
        exact)     [ "$got" = "$exp" ];;
        substring) case "$got" in *"$exp"*) true;; *) false;; esac;;
        error)     [ "$rc" != 0 ] || printf '%s' "$got" | grep -qi 'error';;
        *)         false;;
    esac
}
oracle_equal() { # $1=scrip output  $2=oracle output -- equal, or the SAME ERROR NUMBER (wording differs by design)
    # sets OE_KIND=exact|errnum on a 0 return; caller reads it only immediately after, before any
    # other oracle_equal call overwrites it (script is single-threaded/sequential -- see call sites).
    if [ "$1" = "$2" ]; then OE_KIND=exact; return 0; fi
    local ea eb
    ea="$(printf '%s' "$1" | grep -oiE 'ERROR +[0-9]+' | head -1 | grep -oE '[0-9]+')"
    eb="$(printf '%s' "$2" | grep -oiE 'ERROR +[0-9]+' | head -1 | grep -oE '[0-9]+')"
    # ⛔ NUMERIC, NOT STRING: SPITBOL zero-pads to three digits (`ERROR 042`) and SCRIP does not
    # (`Error 42`), so a string compare silently fails every error below 100 while looking correct.
    if [ -n "$ea" ] && [ -n "$eb" ] && [ "$((10#$ea))" = "$((10#$eb))" ]; then OE_KIND=errnum; return 0; fi
    return 1; }
compile_m4() { local sno="$1" out="$2" t rc ca; t="$(mktemp -d)"
    ca="$(declared_compile_args_from_table "$DECL" "$(basename "$sno" .sno)")" || exit 2
    # Same spelling as the m3 and sbl arms (see run_one): mode 4 bakes `&FILE` at COMPILE time, so the
    # staged short name has to be handed to `--compile`, not just to the run.
    cp -pf "$sno" "$RUN/f.sno"
    (cd "$RUN" && SNO_LIB="$GIMPEL" "$SCRIP" --compile $ca f.sno) > "$t/p.s" 2>"$t/compile.err"; rc=$?
    if [ "$rc" -ne 0 ]; then
        # ⭐ snoflake-sixteen-fixtures-pass-mode-3-and-fail-mode-4 (seat01 2026-09-04): a `SCRIP: ERROR N -- ...`
        # here is a GRADED PROGRAM ANSWER, same class as run_one's m3 crash-and-print (header comment (2)
        # above) -- not a toolchain failure. It happens at compile time only because literal top-level DEFINE
        # is prescanned ahead of codegen (lower_snobol4.c), unlike every other SNOBOL4 runtime error, which
        # compiles fine and only raises at execution. Recognize this ONE shape and let oracle_equal grade it
        # by ERROR NUMBER like any other error; anything else (segfault, an unrecognized message, no
        # diagnostic at all) is a real toolchain failure and stays SKIP(cc), rc=1.
        CTERR="$(cat "$t/compile.err")"; rm -rf "$t"
        printf '%s' "$CTERR" | grep -qE '^SCRIP: ERROR [0-9]+ -- ' && return 2
        return 1
    fi
    CTERR=""
    gcc -c "$t/p.s" -o "$t/p.o" 2>/dev/null || { rm -rf "$t"; return 1; }
    gcc "$t/p.o" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$out" 2>/dev/null || { rm -rf "$t"; return 1; }
    rm -rf "$t"; }
run_one() { # $1=cmdkind $2=sno -> sets GOT RC ; input from $W/inp if HASINP
    local inp=/dev/null; [ "$HASINP" = 1 ] && inp="$W/inp"
    case "$1" in
        # ⛔⭐ BOTH ENGINES GET THE SAME SPELLING `f.sno`, and it is a grading bug to hand SCRIP the
        # suite path back (cto 2026-09-08, re-measured by the coo on a 2-line witness at a296d8d04):
        # `&FILE`/`&LASTFILE` are the pathname AS GIVEN in SPITBOL and in SCRIP alike, so with the oracle
        # staged on `f.sno` (below) and SCRIP on the absolute path, every fixture whose output carries
        # either keyword could never match, whatever the compiler did. Measured: `sbl -bf f.sno` and
        # `scrip --run f.sno` both print `FILE=f.sno`; `scrip --run <abspath>` prints the abspath.
        # Identical class to the Arizona runner's cure (SCRIP 3bb0a210c).
        m3)  cp -pf "$2" "$RUN/f.sno"
             local ca; ca="$(declared_compile_args_from_table "$DECL" "$(basename "$2" .sno)")" || exit 2
             local sz=""; [ "$PORT" = 1 ] && { sz="$(declared_switches_from_table "$DECL" "$(basename "$2" .sno)")" || exit 2; }   # a port reads its declared heap and stack as -dNk -sNk, never SCRIP's env
             GOT="$(cd "$RUN" && run_at_declared_table "$DECL" "$(basename "$2" .sno)" -- env SNO_LIB="$GIMPEL" ${SCRIP_LIST_SINK:+SCRIP_SNO_LIST_SINK="$SCRIP_LIST_SINK"} "$TIMEOUT_RETRY" "$TIMEOUT" "$SCRIP" --run $ca $sz f.sno < "$inp" 2>&1)"; RC=$?;;
        m4)  GOT="$(cd "$RUN" && run_at_declared_table "$DECL" "$(basename "$2" .sno)" -- env SNO_LIB="$GIMPEL" ${SCRIP_LIST_SINK:+SCRIP_SNO_LIST_SINK="$SCRIP_LIST_SINK"} "$TIMEOUT_RETRY" "$TIMEOUT" "$W/prog.bin" < "$inp" 2>&1)"; RC=$?;;
        # ⛔⭐ THE ORACLE IS HANDED A SHORT NAME, NEVER THE ABSOLUTE PATH, AND IT IS A GRADING BUG IF YOU
        # "TIDY" THIS BACK (hq_B 2026-09-04, measured). SPITBOL formats its diagnostic as
        # `<path>(<line>) : ERROR <n> -- <text>`, wraps it at column 119 into the LISTING, and spills only
        # the OVERFLOW onto stdout. The listing is diverted by $SBL_SINK, so with the suite's absolute path
        # (73 chars here) the words `ERROR 199` land in the diverted listing and the compared stream
        # receives the bare tail `t trace type`. oracle_equal then finds NO error number, and the fixture
        # is graded FAIL on the LENGTH OF ITS OWN PATHNAME. Measured exactly: 119 characters are lost
        # regardless of message, so a longer path leaves MORE of the tail visible, not less -- the failure
        # gets less suspicious as it gets worse. Staging `f.sno` keeps every diagnostic under the wrap.
        # ⛔⭐ THE TERMINATION DUMP IS RECOVERED FROM THE DIVERTED LISTING (hq_T 2026-09-08, ceo row
        # snobol4-snoflake-runner-routes-the-termination-dump-into-the-listing-sink, on the cto's measurement).
        # $SBL_SINK exists to keep SPITBOL's STATEMENT LISTING out of the compared stream -- SCRIP emits no
        # listing, so grading against one is unfair, and it changes the oracle stream on 83 of these 180
        # fixtures (measured 2026-09-08; this file's header still says 56, an older corpus).
        # ⛔ BUT THE &DUMP TERMINATION DUMP IS NOT A LISTING. It is program-visible output SCRIP DOES produce,
        # and SPITBOL writes it wherever the listing goes -- so the sink swallowed it and dump-ordered graded
        # against an EMPTY oracle stream while SCRIP printed the dump to stdout. Measured: with the sink,
        # stdout is 0 bytes and the 41-line dump is in listing.lst; without it, that dump IS stdout. A fixture
        # failing because the runner hid the oracle's answer is a false red of the worst kind -- it convicts
        # the compiler of the instrument's choice.
        # ⭐ RECOVERED NARROWLY, ON TWO CONDITIONS BOTH KEYED ON MEASURED FACTS, so no other fixture can move:
        # the fixture's own source must SET &DUMP (3 of 180 do), and the tail is taken from the first
        # `dump of ` section header onward -- the dump happens at TERMINATION, so it is always the tail, and
        # everything above it is the listing this sink is here to divert. topological-sort is why the split is
        # positional rather than whole-file: its .lst carries an ERROR 248 diagnostic for 21 lines and THEN
        # the dump, and appending the whole file would re-furnish the stream the sink just cleaned.
        sbl) cp -pf "$2" "$RUN/f.sno"
             rm -f "${SBL_SINK#-o=}.lst"
             GOT="$(cd "$RUN" && "$TIMEOUT_RETRY" "$TIMEOUT" "$SBL" $SBL_FLAGS $SBL_SINK f.sno < "$inp" 2>&1)"; RC=$?
             if grep -qE '&DUMP[[:space:]]*=' "$2" 2>/dev/null; then
                 _lst="${SBL_SINK#-o=}.lst"
                 if [ -s "$_lst" ] && grep -qE '^dump of ' "$_lst"; then
                     # ⛔ THE BLANK LINES IMMEDIATELY ABOVE THE FIRST `dump of ` BELONG TO THE DUMP. SPITBOL
                     # writes three of them, and so does SCRIP -- measured byte-for-byte on dump-ordered --
                     # so a split that starts exactly at the header hands the oracle side three fewer lines
                     # than the compiler's and turns one false red into a different false red.
                     GOT="${GOT}$(awk '/^dump of /{f=1; for(i=1;i<=nb;i++) print ""; nb=0} !f && /^[[:space:]]*$/{nb++; next} !f{nb=0; next} f' "$_lst")"
                 fi
             fi;;
        csn) GOT="$(cd "$RUN" && "$TIMEOUT_RETRY" "$TIMEOUT" "$CSN" "$2" < "$inp" 2>&1)"; RC=$?;;
    esac; }
. "$HERE/lib_rr.sh" && rr_load "$SUITE" || exit 2   # the round robin's seam (CEO-1802/1805/1806): one chunk or a request's entries, rows as each test ends
for sno in "$SUITE"/*.sno; do
    _rrn="$(basename "$sno")"; _rrn="${_rrn%.*}"; rr_admits "$_rrn" || continue; rr_yield "$_rrn" && break; [ "$PROG_RECORD" = 1 ] && rr_flush "$PROG_ROWS"
    [ -e "$sno" ] || { echo "⛔ REFUSE(rc=2): zero fixtures in $SUITE"; exit 2; }
    name="$(basename "$sno" .sno)"; TOTAL=$((TOTAL+1)); ROW_S3=0; ROW_S4=0
    export S4E_TIMEOUT_KEY="$name"   # the unit a retried timeout's stamp names (CEO-1335)
    read -r MATCH IC NSTD HASINP OPTS <<< "$(parse_fixture "$sno")"
    mask_arm "$name"
    [ "$OPTS" = 1 ] && OPTS_LIST="$OPTS_LIST $name"
    run_one sbl "$sno"; ORACLE_OUT="$GOT"
    case "$ORACLE_OUT" in *"-o file open error"*)
        echo "⛔ REFUSE(rc=2): the oracle's listing sink would not open on $name, so SPITBOL dumped its listing"
        echo "   back into the compared stream. Every verdict from here would be against a re-furnished stream."; exit 2;; esac
    OERR="$(printf '%s' "$ORACLE_OUT" | grep -iE 'ERROR +[0-9]+' | head -1 | tr -d '\t' | cut -c1-140)"; OUTSIDE=0
    # a numbered refusal first, then SPITBOL's measured un-numbered ones (see ORACLE_REFUSAL_RE above)
    [ -z "$OERR" ] && OERR="$(printf '%s' "$ORACLE_OUT" | grep -E "$ORACLE_REFUSAL_RE" | head -1 | tr -d '\t' | cut -c1-140)"
    if [ -n "$OERR" ]; then OUTSIDE=1; OUTSIDE_N=$((OUTSIDE_N+1)); OUTSIDE_LIST="${OUTSIDE_LIST}${name}\t${OERR}\n"; else BASE=$((BASE+1)); fi
    # ⛔ OERR IS READ FROM THE UNMASKED STREAM ABOVE, ON PURPOSE: the outside-baseline classification must
    # never be able to see through a mask, and guardrail 4 already refuses a mask that could cover a
    # diagnostic. Only the COMPARISON stream is masked, and only from here down.
    MC=0
    if [ "${MASK_N:-0}" != 0 ]; then
        MC="$(mask_count "$ORACLE_OUT")"
        OLINES="$(printf '%s' "$ORACLE_OUT" | grep -c '' 2>/dev/null || echo 0)"
        if [ "$MC" -gt 0 ] && [ $((MC * 2)) -gt "$OLINES" ]; then
            echo "⛔ REFUSE(rc=2): $name would have $MC of its $OLINES oracle lines masked."
            echo "   CEO-409 guardrail 4 -- when masked lines are the MAJORITY of a fixture's output the fixture is"
            echo "   ungradable and belongs OUTSIDE the baseline, named, not carried in the denominator behind a mask."; exit 2
        fi
        if [ "$MC" -gt 0 ]; then MASKED_LINES=$((MASKED_LINES+MC)); MASKED_FIX=$((MASKED_FIX+1)); MASKED_LIST="$MASKED_LIST $name($MC)"; fi
    fi
    ORACLE_CMP="$(mask_apply "$ORACLE_OUT")"
    if grade "$ORACLE_OUT" "$RC" "$MATCH" "$IC"; then [ "$NSTD" = 1 ] && NSP=$((NSP+1)) || PS=$((PS+1)); ORACLE_MEETS_EXPECT=1
    else [ "$NSTD" = 1 ] && NSF=$((NSF+1)) || { FS=$((FS+1)); FLS="$FLS $name"; }; ORACLE_MEETS_EXPECT=0; fi
    _t0="$(progress_clock)"; run_one m3 "$sno"; M3RC=$RC; M4RC=0; OUT3=""; NOTE3=""; ROW_S3="$(progress_secs_since "$_t0")"
    if oracle_equal "$(mask_apply "$GOT")" "$ORACLE_CMP"; then [ "$NSTD" = 1 ] && N3P=$((N3P+1)) || P3=$((P3+1))
        if [ "$OE_KIND" = exact ]; then OUT3=PASS; else OUT3=UNGRADED; NOTE3="error_number_only: same ERROR number as sbl -bf, stream differs (narrower instrument)"; fi
        if [ "$NSTD" != 1 ]; then
            if [ "$OE_KIND" = exact ]; then SE3=$((SE3+1)); else EN3=$((EN3+1)); ENL3="$ENL3 $name"; fi
        fi
        [ "$ORACLE_MEETS_EXPECT" = 0 ] && { DIA=$((DIA+1)); DIAL="$DIAL $name"; }
    else [ "$NSTD" = 1 ] && N3F=$((N3F+1)) || { F3=$((F3+1)); FL3="$FL3 $name"; }
        OUT3="$(verdict_of "$RC")"; NOTE3="rc=$RC vs sbl -bf"; [ "$NSTD" = 1 ] && { NOTE3="@nonstandard by snoflake's own header, yet SPITBOL runs it, so it is graded in the baseline; $NOTE3"; }; fi
    _t0="$(progress_clock)"; OUT4=""; NOTE4=""; m4rc=3; [ "$PORT" = 1 ] || { compile_m4 "$sno" "$W/prog.bin"; m4rc=$?; }
    if [ "$PORT" = 1 ]; then :   # a port has no mode 4: no compile, no row
    elif [ "$m4rc" -eq 0 ]; then
        run_one m4 "$sno"; M4RC=$RC
        if oracle_equal "$(mask_apply "$GOT")" "$ORACLE_CMP"; then [ "$NSTD" = 1 ] && N4P=$((N4P+1)) || P4=$((P4+1))
            if [ "$OE_KIND" = exact ]; then OUT4=PASS; else OUT4=UNGRADED; NOTE4="error_number_only: same ERROR number as sbl -bf, stream differs (narrower instrument)"; fi
        else [ "$NSTD" = 1 ] && N4F=$((N4F+1)) || { F4=$((F4+1)); FL4="$FL4 $name"; }
            OUT4="$(verdict_of "$RC")"; NOTE4="rc=$RC vs sbl -bf"; [ "$NSTD" = 1 ] && { NOTE4="@nonstandard by snoflake's own header, yet SPITBOL runs it, so it is graded in the baseline; $NOTE4"; }; fi
    elif [ "$m4rc" -eq 2 ]; then
        if oracle_equal "$(mask_apply "$CTERR")" "$ORACLE_CMP"; then [ "$NSTD" = 1 ] && N4P=$((N4P+1)) || P4=$((P4+1))
            if [ "$OE_KIND" = exact ]; then OUT4=PASS; NOTE4="compile-time diagnostic equals sbl -bf"; else OUT4=UNGRADED; NOTE4="error_number_only: compile-time diagnostic carries the oracle ERROR number, stream differs"; fi
        else [ "$NSTD" = 1 ] && N4F=$((N4F+1)) || { F4=$((F4+1)); FL4="$FL4 $name(CTERR)"; }
            OUT4=FAIL; NOTE4="compile-time diagnostic differs from sbl -bf"; [ "$NSTD" = 1 ] && { NOTE4="@nonstandard by snoflake's own header, yet SPITBOL runs it, so it is graded in the baseline; $NOTE4"; }; fi
    else S4=$((S4+1)); FL4="$FL4 $name(CC)"; OUT4=SKIP; NOTE4="mode-4 compile/link failed (cc), no program answer to grade"; fi
    # ⛔ A HANG NEVER COLLAPSES INTO PASS (the verdict ladder; measured on the dotnet runner 2026-09-07, coo): a run
    # that hit the timeout is HANG whatever its stream says at the cut. M3RC/M4RC are the run rcs banked above.
    [ "${M3RC:-0}" -eq 124 ] && { OUT3=HANG; NOTE3="SCRIP hit the $TIMEOUT timeout; $NOTE3"; }
    [ "${M4RC:-0}" -eq 124 ] && { OUT4=HANG; NOTE4="SCRIP hit the $TIMEOUT timeout; $NOTE4"; }
    [ "$OUT3" = PASS ] && ST3=$((ST3+1)); [ "$OUT4" = PASS ] && ST4=$((ST4+1))
    [ "$OUT3" = PASS ] && { [ "$PORT" = 1 ] || [ "$OUT4" = PASS ]; } && BOTH_STREAM=$((BOTH_STREAM+1))   # a port's AND is its one mode
    if [ "$OUTSIDE" = 1 ]; then OUT3=UNGRADED; OUT4=UNGRADED; NOTE3="OUTSIDE_SPITBOL_BASELINE: SPITBOL itself does not run it -- $OERR"; NOTE4="$NOTE3"
    elif [ "$OUT3" = PASS ] && { [ "$PORT" = 1 ] || [ "$OUT4" = PASS ]; }; then BASE_BOTH=$((BASE_BOTH+1)); fi
    ROW_S4="$(progress_secs_since "$_t0")"
    prog_row "$name" m3 "$OUT3" "$NOTE3"; prog_row "$name" m4 "$OUT4" "$NOTE4"
    if [ -n "$CSN" ]; then
        run_one csn "$sno"
        if grade "$GOT" "$RC" "$MATCH" "$IC"; then [ "$NSTD" = 1 ] && NCP=$((NCP+1)) || PC=$((PC+1))
        else [ "$NSTD" = 1 ] && NCF=$((NCF+1)) || { FC=$((FC+1)); FLC="$FLC $name"; }; fi
    fi
done
echo "── snoflake_suite: $TOTAL fixtures · $TREE_LABEL · corpus $CORP_HASH · RT_OPT -O0 · timeout -k 5 $TIMEOUT · graded vs the ORACLE sbl -bf (ceo CEO-251); @expect is informational and drives only the dialect tally"
echo "mode-3 (--run):     PASS=$P3 FAIL=$F3  NSTD $N3P/$((N3P+N3F))  stream_equality=$SE3 error_number_only=$EN3"
echo "mode-4 (--compile): PASS=$P4 FAIL=$F4 SKIP(cc)=$S4  NSTD $N4P/$((N4P+N4F))"
# ⭐ THE SUITE-TABLE READING (ceo-372: the AND per program; CEO-383: the stream-equal basis -- the PASS= counts above
# fold error-number-only matches and are this runner's own label, never the table's number). Over all $TOTAL fixtures.
echo "SNOFLAKE_BOARD total=$TOTAL m3_stream_pass=$ST3 m3_error_number_only=$EN3 m4_stream_pass=$ST4 m4_skip=$S4 both_modes_stream_pass=$BOTH_STREAM nstd=$((N3P+N3F)) -- the suite table states both_modes_stream_pass/$TOTAL"
# ⭐ CEO-409 guardrail 3: A SUITE REPORTING 102 OF 124 ALSO REPORTS HOW MANY LINES IT DECLINED TO GRADE.
# This line is printed whether or not any mask armed -- a zero said out loud is the thing that makes a
# non-zero legible, and it is the difference between a mask that is a measurement and a mask that hides.
echo "MASKED_LINES total=$MASKED_LINES across $MASKED_FIX fixture(s)${MASKED_LIST:+ --$MASKED_LIST} (CEO-409: implementation-defined lines are excluded AT THE LINE, named and counted in the fixture; the fixture stays IN the denominator)"
echo "SNOFLAKE_BASELINE baseline=$BASE both_modes_pass=$BASE_BOTH masked=$MASKED_LINES outside_spitbol_baseline=$OUTSIDE_N of $TOTAL -- THE SUITE TABLE STATES both_modes_pass/baseline (a fixture SPITBOL itself cannot run is outside the baseline and out of the denominator; Lon 2026-09-08)"
if [ "$OUTSIDE_N" -gt 0 ]; then echo "OUTSIDE-SPITBOL-BASELINE ($OUTSIDE_N; name<TAB>SPITBOL's own error):"; printf '%b' "$OUTSIDE_LIST" | sed 's/^/OUTSIDE\t/'; fi
if [ -f "$OUTSIDE_TSV" ]; then
    rec="$(awk -F'\t' 'NF>2 && $1 !~ /^#/{sub(/\.sno$/,"",$1); print $1}' "$OUTSIDE_TSV" | sort)"; live="$(printf '%b' "$OUTSIDE_LIST" | cut -f1 | grep . | sort)"
    stale="$(comm -23 <(printf '%s\n' "$rec") <(printf '%s\n' "$live") | grep . | tr '\n' ' ')"; unrec="$(comm -13 <(printf '%s\n' "$rec") <(printf '%s\n' "$live") | grep . | tr '\n' ' ')"
    [ -n "$stale" ] && echo "⚠ OUTSIDE_SPITBOL_BASELINE.tsv STALE -- recorded as not running in SPITBOL, but SPITBOL ran it clean this run; move it back into the baseline record: $stale"
    [ -n "$unrec" ] && echo "⚠ OUTSIDE_SPITBOL_BASELINE.tsv UNRECORDED -- SPITBOL errors on these and the record does not name them; record each with its error and a source check: $unrec"
    [ -z "$stale$unrec" ] && echo "OUTSIDE_SPITBOL_BASELINE.tsv agrees with the measured outside set ($OUTSIDE_N)"
    if [ -f "$MIRROR_TSV" ]; then mir="$(awk -F'\t' 'NF>2 && $1 !~ /^#/{print $1}' "$MIRROR_TSV" | sort)"; recn="$(awk -F'\t' 'NF>2 && $1 !~ /^#/{print $1}' "$OUTSIDE_TSV" | sort)"
        [ "$mir" = "$recn" ] || echo "⚠ UNGRADABLE.tsv does not mirror OUTSIDE_SPITBOL_BASELINE.tsv row for row -- the lockdown bucket and the record have drifted; edit them together"; fi
else echo "⚠ no OUTSIDE_SPITBOL_BASELINE.tsv beside the suite -- the outside-baseline set above is measured, not yet recorded"; fi
echo "dialect tally (NOT in the score): $DIA fixture(s) pass against SPITBOL while failing their own @expect -- SPITBOL itself departs from what snoflake expects there"
[ -n "$SBL" ] && echo "sbl -bf vs @expect (informational, the dialect measurement): PASS=$PS FAIL=$FS  NSTD $NSP/$((NSP+NSF))"
[ -n "$CSN" ] && echo "csnobol4 (home dialect, triangulation): PASS=$PC FAIL=$FC  NSTD $NCP/$((NCP+NCF))"
# ⭐ THE PACKAGE LOCKDOWN inventory line, via the shared body (lib_inventory.sh) -- never a second copy
# of the arithmetic. Every fixture lands in P3/F3/N3P/N3F (the main loop has no per-fixture skip path),
# so TOTAL is always fully graded against the oracle -- ungradable=0/ungraded=0 by construction, not by
# assumption. EN3 (error-number-only, a narrower comparison than full stream equality) is graded_narrow,
# named per-entry in NARROW.tsv beside the package; everything else that went through full comparison
# (SE3 stream-equal passes, F3 fails, and the NSTD-flagged N3P/N3F) is graded_stream.
INV_PACKAGE=snoflake_suite; INV_DIR="$SUITE"; INV_EXT=".sno"
if ! rr_selected; then   # a chunk grades a part of the package, and the inventory sums the whole shipped package (CEO-1802)
INV_LINE="$(inventory_line "$BASE" 0)"
if [ -n "$INV_LINE" ]; then echo "$INV_LINE"; else echo "⚠ inventory refused (above) -- the board line still stands; the inventory does not" >&2; fi
fi
[ -n "$OPTS_LIST" ] && echo "OPTS not honored:$OPTS_LIST"
[ -n "$ENL3" ] && echo "ERROR-NUMBER-ONLY (m3, ungraded-by-a-narrower-instrument, not a red and not a stream-equal pass):$ENL3"
[ -n "$FL3" ] && echo "FAIL-M3:$FL3"
[ -n "$FL4" ] && echo "FAIL-M4:$FL4"
[ -n "$FLS" ] && echo "FAIL-SBL:$FLS"
[ -n "$FLC" ] && echo "FAIL-CSN:$FLC"
[ -n "$DIAL" ] && echo "DIALECT:$DIAL"
# ⛔⭐ POPULATION FLOOR (row every-board-wrapper-refuses-on-a-zero-population-instead-of-passing-
# vacuously, hq_T 2026-09-04): P3/F3/N3P/N3F all read 0 when "$SUITE"/*.sno matches nothing (an unset
# or wrong $SUITE) -- refuse before the vacuous-clean verdict below can be reached.
"$HERE/util_require_population.sh" --gate test_snoflake_suite "$((P3+F3+N3P+N3F))" 1 "mode-3 gradings under \$SUITE" || exit 2

# ⭐ THE PROGRESS ROWS, written once (see PROG_ROWS above), BEFORE the score row: util_score_row.py's
# own write path requires per-program progress evidence to already exist for this tree (a score without
# it is "DARK wearing a number") -- so this must run first, not after (was after; REFUSED(2) every time
# on a fresh tree, hq_snobol4 2026-09-23, measured).
if [ "$PROG_RECORD" = 1 ]; then
    progress_append_rows_tsv "$PROG_ROWS" || echo "⚠ PROGRESS ROWS NOT RECORDED (writer rc=$? above) -- a run that leaves the table untouched is a defect of that run (progress/README.md), not a red board" >&2
else echo "progress: scratch suite $SUITE -- $(grep -c . "$PROG_ROWS") row(s) NOT recorded (only the canonical suite, or S4E_PROGRESS_DB, records)"; fi
rr_selected && { rr_end "$ROWKEY"; exit 0; }   # a chunk or a request writes its rows and no suite row (CEO-1802)
# ⛔ ONE LEADERBOARD (RULES.md FACT RULE, Lon 2026-09-03 ~16:05). Records what this script just
# measured into .github/SCORE.md; runs nothing itself. Non-fatal: a bookkeeping failure must never
# turn a real measurement into a red board. Matches the other package suites (Arizona/JCON/fpc/GNU/SWI);
# this one and csnobol4_suite's own runner were the two missing it (board-packages-into-make-test-
# reported-then-blocking, seat13 2026-09-03).
if [ "$PORT" = 1 ]; then echo "SCORE.md: the $(one_runner_engine) engine writes no SCRIP row -- its row is util_score_row.py from-progress --suite $ROWKEY (CEO-1822), graded in m3 alone"
elif [ "$SUITE" != "$CANON_SUITE" ]; then echo "SCORE.md: scratch suite $SUITE -- not written (only the canonical suite records the leaderboard)"; else
# ⛔ CEO-749 SHAPE (row snobol4-four-package-rows-leave-their-outside-baseline-programs-out-of-the-denominator-ceo-749): the
# row publishes PASS over SHIPPED = the baseline fixtures plus the $OUTSIDE_N outside the SPITBOL baseline, OUTSIDE=k named and
# stamped through lib_outside_shape.sh. Before this it read $BASE_BOTH/$BASE with 56 programs listed outside.
SHIPPED=$((BASE + OUTSIDE_N))
. "$HERE/lib_outside_shape.sh" || exit 2
# ⛔⭐ CEO-1286 (Lon 2026-09-26): the fixtures NOT IN THE SPITBOL DIALECT (EXCLUDED.tsv) leave the denominator; the fixtures SPITBOL refuses
# for any other cause (lowercase source owed its case conversion, the 370 FORMAT convention, a stack depth, an error test) stay as debt.
EXCL_D_N="$(excluded_in_outside "$SUITE" "$(printf '%b' "$OUTSIDE_LIST" | cut -f1)")" || exit 2; DENOM=$((SHIPPED - EXCL_D_N))
echo "EXCLUDED_NOT_SPITBOL_DIALECT=$EXCL_D_N of this run's outside set leave the denominator ($(excluded_names_count "$SUITE") named in $SUITE/EXCLUDED.tsv; Lon 2026-09-26, CEO-1286): pass over $DENOM"
_cc="${S4E_CRITERION_CHANGED:-}"; [ -n "$_cc" ] || _cc="$(excluded_shape_stamp snoflake "$DENOM" "$OUTSIDE_N" "$EXCL_D_N")" || exit 2
python3 "$HERE/util_score_row.py" write --lang snobol4 --column vendor --suite Snoflake --modes m3,m4 \
    ${_cc:+--criterion-changed "$_cc"} \
    --measurer "${S4E_SEAT:-}" --suite-pass "$BASE_BOTH" --suite-total "$DENOM" --excluded "$EXCL_D_N" \
    --text "both_modes_pass=$BASE_BOTH/$DENOM ($SHIPPED shipped minus EXCLUDED=$EXCL_D_N not in the SPITBOL dialect, EXCLUDED.tsv, CEO-1286) OUTSIDE=$OUTSIDE_N, graded $BASE_BOTH/$BASE · masked_lines=$MASKED_LINES in $MASKED_FIX fixture(s) (CEO-409, excluded at the line, fixture stays in the denominator) · baseline both_modes_pass=$BASE_BOTH/$BASE (the table's reading: fixtures SPITBOL runs clean; $OUTSIDE_N outside the SPITBOL baseline, Lon 2026-09-08) · both_modes_stream_pass=$BOTH_STREAM/$TOTAL (the runner's own label, ceo-372 AND per program on the CEO-383 stream-equal basis) · mode-3 PASS=$P3 FAIL=$F3 NSTD $N3P/$((N3P+N3F)) stream_equality=$SE3 error_number_only=$EN3 · mode-4 PASS=$P4 FAIL=$F4 SKIP(cc)=$S4 NSTD $N4P/$((N4P+N4F))${INV_LINE:+ · $INV_LINE} (\`test_snoflake_suite.sh\`)" \
    || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"
fi

[ "$F3" = 0 ] && [ "$F4" = 0 ] && [ "$S4" = 0 ]
