#!/usr/bin/env bash
# lib_rungs_extract.sh -- THE ONE way a script materializes a witness out of a language's RUNGS flat suite
# (Lon 2026-08-29 one-flat-suite + zero-subfolders rulings: per-family suite files and the tests/snobol4
# subdirs are GONE; every absorbed test lives in tests/snobol4/ALL.{sno,ref,in,csv} side by side).
# A consumer that used to run tests/snobol4/probe/<fam>.sno or a loose pair now asks for entries BY ORIGIN
# (the CSV's provenance column, "<family>__<old-name>") or by CURRENT name, and gets standalone files back.
#   rungs_entry_for_origin <origin>                 -> prints the entry's CURRENT (descriptive) name
#   rungs_extract_origin  <origin> <out_src> [ref]  -> materializes one entry (+.ref) by origin
#   rungs_extract_name    <name>   <out_src> [ref]  -> same, by current name
#   rungs_origins_of_family <family>                -> every origin whose family column matches
# All lookups go through ALL.csv (never a second parser of the suite grammar); extraction goes through
# corpus_suite_harness.py extract (the ONE authority). Missing entry/rungs -> rc=2 REFUSAL, never silence.
# ⛔⭐ MULTI-LANGUAGE (seat03 2026-08-30, HALF-GENERALIZED-CONTRACT CHECK per corpus-suites-
# consolidation.task.md): the extension was hardcoded to .sno, so every function here silently
# assumed SNOBOL4 -- grepped this whole file for the old discriminator before adding RUNGS_EXT,
# per that law. corpus_suite_harness.py's own extract/extract-family commands already detect the
# reader (line vs block) from the file SUFFIX, so the shell side only needed a suffix knob, not a
# second code path. Default stays ".sno" so all 21 existing SNOBOL4 callers are byte-identical;
# icon callers set RUNGS_EXT=.icn (and RUNGS_DIR=$S4E/corpus/tests/icon) before sourcing/calling.
# ⛔⛔⭐ INTERIM PROMOTION PROTOCOL -- READ THIS BEFORE YOU PROMOTE OR RETIRE AN XFAIL MARKER
# (ceo ruling 2026-09-01, routed here by hq_C; the row it was INTERIM until, `optbypass-pin-stable-subset`, is RETIRED.)
#
# ⛔⭐ A MARKER LIVES IN **FOUR** PLACES, NOT THREE -- THIS PARAGRAPH SAID THREE UNTIL 2026-09-06 AND THAT
# OMISSION HAS NOW COST TWO SEATS AND ONE BLOCKING RED ON ORIGIN:
#   (1) the banner in ALL.sno
#   (2) the SAME banner in ALL.ref
#   (3) the reason line in ALL.xfail
#   (4) the `xfail` COLUMN (field 6) of ALL.csv        <-- THE ONE THIS FILE USED TO OMIT
# read_suite compares the .sno and .ref banners and RAISES on a mismatch, so a half-applied promotion of
# (1)+(2) does not degrade -- it makes the rungs suite UNREADABLE. Measured 2026-09-01: corpus 2d75933ec
# dropped ' XFAIL' from ALL.sno and ALL.xfail but not ALL.ref, and every SNOBOL4 board and census on the
# box refused for ~40 minutes until 5eb68cb8 restored the pair.
# ⭐ WHY (4) IS THE DANGEROUS ONE, and why following this file exactly was not enough: (1)-(3) fail LOUDLY
# and immediately -- read_suite raises and names the torn seq. (4) fails SILENTLY in the promoting seat's
# root and reddens `test_gate_xfail_marker_and_index_agree` (BLOCKING) for everyone else. Measured
# 2026-09-06: hq_T promoted two markers in corpus f0262a113, ran read_suite on the result exactly as the
# rule below demands, got rc=0 over 1882 entries, and pushed -- leaving ALL.csv at xfail=1 and the gate
# red on origin at rungs=32 index=34 until hq_P landed 324c5926d. **THE PROOF THE RULE ASKED FOR WAS
# PERFORMED AND PASSED, AND THE PROMOTION WAS STILL INCOMPLETE**, because read_suite does not read ALL.csv.
# ⛔ A verification step that cannot see one of the places it is verifying will certify a half-done job.
#
#   THE RULE: a marker promotion is proven by running read_suite (or the board) ON THE RESULT **and** by
#   re-running test_gate_xfail_marker_and_index_agree.sh, in the SAME COMMIT -- never by the extract alone,
#   and never by read_suite alone, which is blind to place (4).
#

#
# ⭐ THE CHECK COSTS 0.046 s, SO THERE IS NO BUDGET EXCUSE FOR SKIPPING IT (hq_C, measured; the 400-650 s
# board is what people were actually skipping). `list` runs the same read_suite the board does:
#
#     python3 "$S4E_HOME/harness/scripts/corpus_suite_harness.py" list \
#             "$S4E_HOME/corpus/tests/snobol4/ALL.sno" "$S4E_HOME/corpus/tests/snobol4/ALL.ref"
#
# PROVEN BOTH DIRECTIONS on the real tear (hq_C 2026-09-01, not asserted -- run):
#   torn pair  (at 2d75933ec) -> rc=1, "ValueError: family.ref banner mismatch at seq 1678:
#                                       sno='... 1678 user_function_indirect_replace_2'
#                                       ref='... 1678 user_function_indirect_replace_2 XFAIL'"
#   fixed pair (at 5eb68cb8)  -> rc=0, 1726 entries listed
# ⛔ Read the rc, not the tail: a wrong PATH to the harness also exits nonzero and looks identical at a
# glance ("can't open file ..."). That mistake was made while proving this very line.
#
# ✅⛔ THE BYPASS-ARM SECOND CHECK IS RETIRED (hq_T 2026-09-05, ruling R4 lane). It required every promotion to also run
# util_census_optimizer_bypass.py --only <entry> so a promoted entry could not silently push the optbypass watermark up.
# BOTH the tool and test_gate_optbypass_watermark.sh are DELETED: their subject, SCRIP_OPT=0 / SCRIP_ZD=0, was removed by
# Lon's ruling on 2026-09-03 (SCRIP ce199b05e, "the emergency optimizer bypass is gone, not merely retired"), so the arms
# measured the default arm under a different name. A promotion owes the read_suite/board proof above and NOTHING ELSE.
# ⭐ THE ONE LESSON WORTH CARRYING OUT OF IT, now in .github/GOAL-TEST-SUITE-CONSISTENCY.md: a CARRIED MAX watermark is an
# upper bound only under SHRINKAGE. Every entry promoted INTO a graded set brings its own verdict with it, so under GROWTH
# -- the direction this corpus actually moves -- a carried max is not conservative, it is wrong.
_ME_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ME_S4E="${S4E_HOME:-$(cd "$_ME_HERE/../.." && pwd)}"
# ⛔⭐ NO DEFAULT RUNGS (coo 2026-09-16; hq_snocone's witness, hq_pascal's precedent lib_ladder.sh:49; row lib-master-extract-defaults-
# master-dir-to-the-snobol4-master-when-unset-instead-of-refusing). This line used to read RUNGS_DIR from the environment OR ELSE
# default to corpus/tests/snobol4, so a consumer that forgot to set it GRADED THE SNOBOL4 RUNGS AND SAID NOTHING -- entry names
# collide across rung suites, so the wrong-language answer is well-formed and plausible (hq_snocone's named-entry arm read m3=FAIL
# m4=BUILDFAIL on three Snocone entries that were SNOBOL4 entries of the same name). Now: RUNGS_DIR set explicitly is honoured;
# else RUNGS_LANG names the language and the rungs is derived; else REFUSE rc=2 naming both variables. 29 consumers repointed
# with RUNGS_LANG=snobol4 in the same landing.
if [ -z "${RUNGS_DIR:-}" ]; then
  case "${RUNGS_LANG:-}" in
    snobol4) RUNGS_DIR="$_ME_S4E/corpus/tests/snobol4"; RUNGS_EXT="${RUNGS_EXT:-.sno}";;
    icon)    RUNGS_DIR="$_ME_S4E/corpus/tests/icon";    RUNGS_EXT="${RUNGS_EXT:-.icn}";;
    prolog)  RUNGS_DIR="$_ME_S4E/corpus/tests/prolog";  RUNGS_EXT="${RUNGS_EXT:-.pl}";;
    snocone) RUNGS_DIR="$_ME_S4E/corpus/tests/snocone"; RUNGS_EXT="${RUNGS_EXT:-.sc}";;
    pascal)  RUNGS_DIR="$_ME_S4E/corpus/tests/pascal";  RUNGS_EXT="${RUNGS_EXT:-.pas}";;
    raku)    RUNGS_DIR="$_ME_S4E/corpus/tests/raku";    RUNGS_EXT="${RUNGS_EXT:-.raku}";;
    rebus)   RUNGS_DIR="$_ME_S4E/corpus/tests/rebus";   RUNGS_EXT="${RUNGS_EXT:-.reb}";;
    '') echo "⛔ REFUSE(lib_rungs_extract, rc=2): RUNGS_DIR is unset and RUNGS_LANG names no language -- there is no default rungs. Set RUNGS_DIR=<corpus/tests/<lang>> or RUNGS_LANG=<snobol4|icon|prolog|snocone|pascal|raku|rebus> before sourcing (a missing language is a refusal, never a quiet snobol4)." >&2; return 2 2>/dev/null || exit 2;;
    *) echo "⛔ REFUSE(lib_rungs_extract, rc=2): RUNGS_LANG='$RUNGS_LANG' is not a language with a rung suite under corpus/tests/." >&2; return 2 2>/dev/null || exit 2;;
  esac
fi
RUNGS_EXT="${RUNGS_EXT:-.sno}"
RUNGS_SNO="$RUNGS_DIR/ALL$RUNGS_EXT"
RUNGS_REF="$RUNGS_DIR/ALL.ref"
RUNGS_CSV="$RUNGS_DIR/ALL.csv"
_me_refuse() { echo "⛔ REFUSE(lib_rungs_extract): $*" >&2; return 2; }
# ⛔ DERIVE THE EXTENSION FROM RUNGS_SNO, NEVER READ $RUNGS_EXT DIRECTLY OUTSIDE THIS FILE'S OWN
# TOP LEVEL (seat03 2026-08-30). A caller's `RUNGS_DIR=... RUNGS_EXT=... source lib_rungs_extract.sh`
# only exports RUNGS_EXT for the DURATION of that one `source` command -- RUNGS_SNO/RUNGS_DIR get
# baked in correctly (plain assignments made WHILE sourcing, so they persist as ordinary shell vars
# afterward), but a bare $RUNGS_EXT read later, inside a function called on a SEPARATE line, sees it
# unset again and (under a caller's `set -u`) aborts. RUNGS_SNO is always reliable; extract from it.
_me_ext() { local s="$RUNGS_SNO"; printf '%s\n' ".${s##*.}"; }
rungs_entry_for_origin() {
    [ -f "$RUNGS_CSV" ] || { _me_refuse "no rungs CSV at $RUNGS_CSV"; return 2; }
    local n; n=$(awk -F, -v o="$1" '$3==o{print $2; exit}' "$RUNGS_CSV")
    [ -n "$n" ] || { _me_refuse "origin '$1' not in $RUNGS_CSV"; return 2; }
    printf '%s\n' "$n"
}
rungs_origins_of_family() {
    [ -f "$RUNGS_CSV" ] || { _me_refuse "no rungs CSV at $RUNGS_CSV"; return 2; }
    awk -F, -v f="$1" 'NR>1 && $4==f{print $3}' "$RUNGS_CSV"
}
rungs_extract_name() {
    # ⛔⭐ ALWAYS REQUEST --out-in (row suite-harness-xfail-extract-round-trip, seat15 2026-08-30): the
    # harness now REFUSES (rc=3) to extract a stdin-bearing entry without it -- correctly, since a
    # stdin-starved SNOBOL4 program routinely still exits rc=0, so a caller that dropped the field got a
    # clean-looking run of a DIFFERENT witness than the one actually graded. Passing this unconditionally
    # costs nothing for a non-stdin entry (the harness only creates the file when e.stdin is not None) and
    # means every one of this function's 21 existing callers keeps working, transparently, with the correct
    # input from now on instead of a silent wrong answer.
    local name="$1" out="$2" ref="${3:-}"
    [ -f "$RUNGS_SNO" ] && [ -f "$RUNGS_REF" ] || { _me_refuse "rungs pair missing at $RUNGS_SNO"; return 2; }
    local args=("$RUNGS_SNO" "$RUNGS_REF" "$name" "$out" --out-in "${out%.*}.in")
    [ -n "$ref" ] && args+=(--out-ref "$ref")
    # ⛔ THE OLD >/dev/null 2>&1 SWALLOWED THE HARNESS'S OWN REFUSAL REASON, leaving only a generic "failed"
    # -- exactly the message a caller would need to see to learn THIS entry needs --out-in in the first
    # place. Capture stderr, fold it into the refusal instead of discarding it.
    local err
    err=$(python3 "$_ME_HERE/corpus_suite_harness.py" extract "${args[@]}" 2>&1 >/dev/null) || { _me_refuse "extract '$name' failed: $err"; return 2; }
}
rungs_extract_origin() {
    local o="$1" out="$2" ref="${3:-}" n
    n=$(rungs_entry_for_origin "$o") || return 2
    rungs_extract_name "$n" "$out" "$ref"
}
rungs_origins_by_prefix() {
    # ⭐ seat03 2026-08-30: added for absorptions where each source file got its OWN family column
    # (one-file-per-family, e.g. a numbered audit battery) rather than one shared family across many
    # files -- rungs_origins_of_family can't group these, since there is no single family value to
    # match. Matches the CSV's origin column by a literal string PREFIX instead.
    [ -f "$RUNGS_CSV" ] || { _me_refuse "no rungs CSV at $RUNGS_CSV"; return 2; }
    awk -F, -v p="$1" 'NR>1 && index($3,p)==1{print $3}' "$RUNGS_CSV"
}
rungs_extract_origin_prefix() {
    # materialize EVERY entry whose ORIGIN starts with a prefix as loose <old-name>$RUNGS_EXT/.ref
    # pairs into a dir -- the prefix-matching sibling of rungs_extract_family, for the one-family-
    # per-file absorption shape (see rungs_origins_by_prefix above).
    local prefix="$1" dir="$2" o old rc=0
    mkdir -p "$dir" || return 2
    while IFS= read -r o; do
        [ -n "$o" ] || continue
        old="${o#*__}"
        rungs_extract_origin "$o" "$dir/$old$(_me_ext)" "$dir/$old.ref" || rc=2
    done < <(rungs_origins_by_prefix "$prefix")
    return $rc
}
rungs_extract_family() {
    # materialize EVERY entry of one origin-family as loose <old-name>.sno/.ref pairs into a dir --
    # the bridge for gates whose logic iterates per-file the way the old per-family trees did.
    local fam="$1" dir="$2" o n old rc=0
    mkdir -p "$dir" || return 2
    while IFS= read -r o; do
        [ -n "$o" ] || continue
        old="${o#${fam}__}"
        rungs_extract_origin "$o" "$dir/$old$(_me_ext)" "$dir/$old.ref" || rc=2
    done < <(rungs_origins_of_family "$fam")
    return $rc
}
