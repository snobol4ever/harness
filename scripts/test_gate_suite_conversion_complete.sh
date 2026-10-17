#!/bin/bash
# test_gate_suite_conversion_complete.sh <lang> -- ONE DONE-WHEN authority for the six tests-consolidate-* rows.
#
# ⭐ WHY THIS EXISTS (hq_C ruling 2026-08-27, on seat02's question, corroborated by seat14's measurement).
# The fan-out rows shipped with two independent defects in their DONE-WHENs, and each is trap #1 -- a criterion
# that can never say YES:
#   (1) FOUR of the six (pascal/prolog/rebus/snocone) test `find tests/<lang> -name '*.<ext>' | wc -l -eq 0`.
#       But the SETTLED architecture puts converted suite output INSIDE tests/<lang>/ WITH THE REAL EXTENSION --
#       live proof: corpus/tests/snobol4/crosscheck/patterns.sno, 44KB, pushed. So a successful conversion makes
#       that count go UP, and the criterion is unsatisfiable BY DOING THE WORK CORRECTLY. Measured at ruling
#       time: `find tests/snobol4 -name '*.sno'` = 187, against a criterion demanding 0.
#   (2) The one row that DID exclude the suite subdir hardcoded a keeper allowance (`-le 12`). seat14 then
#       measured the real number: 34 -- all of beauty_suite is STANDALONE-KEEP. A guessed keeper count is a
#       second unsatisfiable criterion wearing a fix's clothing; the keeper set is DISCOVERED by doing the work,
#       so it cannot be a constant known when the row is minted.
#
# THE CRITERION THIS IMPLEMENTS, which needs no guess: every loose program file is EITHER converted (gone from
# the loose tree) OR explicitly declared a keeper in a KEEP.md. Same three-bucket shape as the corpus coverage
# manifest -- converted / declared-kept / nothing-falls-through -- and it is the declaration, not a number, that
# carries the judgment. Do NOT "fix" a red by raising an allowance; declare the file and say why.
#
# ⭐⭐ THE FOURTH BUCKET: DEFERRED-TO-ANOTHER-ROW (PENDING.md) -- hq_B 2026-08-29, on hq_P's catch.
# A ROW-scoped split against a TREE-scoped gate cannot ever go green. tests-consolidate-prolog was split and its
# genuinely-blocked third carved out into tests-consolidate-prolog-pz4-blocked-33; those files are STILL PHYSICALLY
# IN THE TREE, so this gate counts them and the parent's DONE-WHEN is unreachable no matter how much of the
# parent's OWN work is finished. The split bought an honest FREE parent with workable items, not a reachable gate.
# ⛔ KEEP.md IS THE WRONG INSTRUMENT FOR THEM AND USING IT WOULD BE A LIE (hq_P's point, and it is the crux):
# these files are PENDING, not keepers. A keeper declaration says "this stays loose forever, on purpose"; these
# are "this converts later, when a named row unblocks". Filing the second as the first is how a deferral becomes
# permanent silently -- an allowance wearing a declaration's clothes, which is the exact defect above.
# ⛔ SO THE DEFERRAL MUST EXPIRE BY ITSELF, and that is the whole design: a PENDING.md names the OWNING ROW, and
# this gate RESOLVES that row against the live queue every run. Row missing => FAIL (dangling). Row already DONE
# => FAIL (the deferral outlived its reason; convert them now). Only a LIVE row defers. Modelled directly on
# s4e_msg.sh's BLOCKED-ON:/PARKED-AWAITING: self-clearing and its dangling-blocker refusal (2eaca909) -- a block
# recorded against a row that no longer exists is not a block, it is a hiding place.
# ⛔ AND A DEFERRED FILE NEVER READS AS CONVERTED. The verdict line says the tree is NOT fully consolidated and
# names the blocking row(s); this gate certifies THIS ROW'S SCOPE, never the tree's completeness. If the queue
# cannot be read at all, deferrals cannot be verified and the gate REFUSES rc=2 rather than trusting them.
#
# REFUSES rc=2 when it cannot measure -- never skip-as-success.
set -u
LANG_DIR="${1:-}"
[ -n "$LANG_DIR" ] || { echo "REFUSES rc=2: usage: $0 <lang>   (pascal|prolog|rebus|snocone|snobol4|raku|icon)"; exit 2; }
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
TREE="$S4E/corpus/tests/$LANG_DIR"
[ -d "$TREE" ] || { echo "REFUSES rc=2: no such tree: $TREE"; exit 2; }
case "$LANG_DIR" in
  snobol4) EXT='*.sno';;  icon) EXT='*.icn';;   prolog) EXT='*.pl';;
  snocone) EXT='*.sc';;   rebus) EXT='*.reb';;  raku) EXT='*.raku';;  pascal) EXT='*.pas';;
  *) echo "REFUSES rc=2: unknown language '$LANG_DIR' -- add its extension deliberately rather than defaulting"; echo "   to a glob that might match nothing and read as success."; exit 2;;
esac
# ⭐ A converted suite file is EXEMPT WHEREVER IT LIVES, not only under crosscheck/. Two destination conventions
# are in live use -- tests/<lang>/crosscheck/<family>.<ext> (the SNOBOL4 shape) and tests/<lang>/<family>.<ext>
# (the parser-family shape, e.g. tests/raku/parser.raku, tests/rebus/parser.reb) -- and the first draft of this
# gate only knew the first. It therefore counted FINISHED SUITE OUTPUT as unconverted work: raku reported 104
# undeclared on an ALREADY-CONVERTED row. Reported by seat01 2026-08-27; a false red, and the same class of
# defect this gate exists to catch.
# ⛔ The exemption is CONTENT-BASED, deliberately, not a second hand-maintained list of family names or paths:
# a converted file opens with a numbered banner block (comment leader + rule + index + entry name), which the
# harness emits for every language -- "#--- 1 arr_get", "*--- 1 038_pat_literal". Validated at write time to
# match all three live conventions and none of the ordinary loose programs it was tested against.
is_suite_output() {
    head -1 "$1" 2>/dev/null | grep -qE '^[^A-Za-z0-9]*-{10,}[[:space:]]+[0-9]+[[:space:]]+[A-Za-z0-9_]'
}
mapfile -t ALLF < <(find "$TREE" -type f -name "$EXT" -not -path '*/crosscheck/*' 2>/dev/null | sort)
LOOSE=(); SUITEOUT=0
for _f in "${ALLF[@]}"; do
    if is_suite_output "$_f"; then SUITEOUT=$((SUITEOUT+1)); else LOOSE+=("$_f"); fi
done
TOTAL_ANY=$(find "$TREE" -type f -name "$EXT" 2>/dev/null | wc -l)
if [ "$TOTAL_ANY" -eq 0 ]; then
    echo "REFUSES rc=2: zero '$EXT' files anywhere under $TREE -- the extension or the tree moved, so this gate"
    echo "   has gone vacuous. A gate that matches nothing is not a green gate."
    exit 2
fi
echo "suite conversion completeness -- $LANG_DIR -- $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "tree: $TREE   pattern: $EXT   total: $TOTAL_ANY   converted suite output: $SUITEOUT   loose: ${#LOOSE[@]}"
[ "${#LOOSE[@]}" -eq 0 ] && { echo "GATE OK -- nothing loose; every $EXT file lives in the governed suite tree."; exit 0; }
# --- the deferral bucket -----------------------------------------------------------------------------------
PO="${S4E_POST:-/home/resources/postoffice}"
# Resolve a row name against the fleet queue. Echoes LIVE | EXPIRED | DANGLING | UNVERIFIABLE.
# ⛔ UNVERIFIABLE is NOT a pass -- the caller turns it into rc=2, per this gate's own no-skip-as-success rule.
pending_row_state() {
    local _row="$1" _q="$PO/QUEUE.tsv" _d="$PO/QUEUE.done.tsv" _c="$PO/claims/$1.claim"
    [ -r "$_q" ] || { echo UNVERIFIABLE; return; }
    if [ -f "$_c" ] && grep -q '^DONE$' "$_c" 2>/dev/null; then echo EXPIRED; return; fi
    if [ -r "$_d" ] && grep -qP "^[0-9]+\t\Q$_row\E\t" "$_d" 2>/dev/null; then echo EXPIRED; return; fi
    if grep -qP "^[0-9]+\t\Q$_row\E\t" "$_q" 2>/dev/null; then echo LIVE; return; fi
    echo DANGLING
}
# The ROW a PENDING.md speaks for: the first `ROW: <topic>` line. One row per PENDING.md, deliberately --
# a file that needs two owners has not been split yet, and inventing a per-entry syntax here would re-create
# the prose-parsing surface the KEEP.md matcher was just cured of.
pending_row_of() { sed -n 's/^[[:space:]]*ROW:[[:space:]]*\([A-Za-z0-9_.-]\{1,\}\).*$/\1/p' "$1" 2>/dev/null | head -1; }
# ⛔⭐⭐ A PENDING.md DECLARES ONLY WHAT IS LISTED UNDER `## DEFERRED`, AND PROSE ANYWHERE ELSE IS INERT.
# MEASURED THE HARD WAY (hq_B 2026-08-29, on the first real PENDING.md ever written -- my own): I listed all
# 49 loose files in it, 32 deferred plus 17 I was explicitly NOT deferring and was describing in order to
# explain the split. The gate deferred ALL 49 AND WENT GREEN (rc=0). A false green, authored by the person
# who had just written the bucket, in the first hour it existed.
# ⭐ THIS IS KEEP.md's PROSE-MENTION SURFACE, WHICH hq_P CURED ONE LEVEL AND DELIBERATELY LEFT OPEN AT THIS
# ONE -- "prose mention WITHIN the owning directory still counts as a declaration; that surface is left,
# because narrowing it further needs a format change and would break every existing KEEP.md". That reasoning
# is right for KEEP.md and WRONG for PENDING.md, for a reason specific to what each file is for: a KEEP.md
# lists things it keeps, while a PENDING.md inherently wants to DISCUSS the files it is not deferring -- to
# say which are convertible now and why the rest are not. Its most natural content is the exact content that
# breaks it. The surface is not merely open here, it is aimed at the writer.
# ⛔ SO PENDING.md IS STRUCTURED, NOT PROSE. Only `- `/`* ` list items under a `## DEFERRED` heading (up to
# the next `## `) declare anything. There is no migration cost: this format is one session old and has
# exactly one instance in the tree. A NEW format is the one moment when strictness is free -- KEEP.md's
# surface stayed open only because it had already been paid for.
# ⭐ A `## DEFERRED` HEADING MAY NAME ITS OWN ROW: `## DEFERRED <row-topic>`. Bare `## DEFERRED` falls back to
# the file-level `ROW:`. MEASURED NEED (hq_B 2026-08-29, within a day of writing the one-row rule): the 12
# wrong-output prolog files route to THREE different rows -- 11 to the generator-resume-cell row (ASM-confirmed
# by seat03 for 5, by the same discriminator here for 6 more) and 1 to prolog-existence-error-not-catchable-iso,
# which shares neither symbol. The original "one row per PENDING.md" rule was justified as "a file that needs
# two owners has not been split yet" -- true of ONE FILE, and it silently also forbade DIFFERENT FILES having
# different owners, which is the ordinary case. Per-section rows cost one awk field and remove the incentive to
# mis-route a file just to keep the declaration expressible.
# Emits `row<TAB>list-item-text` for every item under any DEFERRED heading; row empty => use the file-level ROW:.
pending_sections() { awk '/^##[[:space:]]+DEFERRED([[:space:]]|$)/{h=$0; sub(/^##[[:space:]]+DEFERRED[[:space:]]*/,"",h); gsub(/[[:space:]]+$/,"",h); row=h; f=1; next} /^##[[:space:]]/{f=0} f&&/^[[:space:]]*[-*][[:space:]]/{print (row==""?"@FILEROW@":row) "\t" $0}' "$1" 2>/dev/null; }
pending_deferred_block() { pending_sections "$1" | cut -f2-; }
mapfile -t KEEPFILES < <(find "$TREE" -type f -name 'KEEP.md' 2>/dev/null)
# ⭐⭐ config/*KEEP.md ALSO DECLARES (seat07 2026-08-30, on the zero-subfolders end state going live for
# real trees). The flat-layout ruling reserves tests/<lang>/config/ for exactly this kind of companion,
# and SNOBOL4's own tree already carries a dozen
# `<prefix>_KEEP.md` files there -- but this gate only ever looked for a literal per-ancestor-directory
# `KEEP.md`, so config/ was invisible to it (MEASURED: `test_gate_suite_conversion_complete.sh snobol4`
# itself reports 95 undeclared today, entirely because its own config/*_KEEP.md files are never read).
# config/ is a FLAT junk-drawer, not a per-family ancestor directory the old walk's directory-scoping
# logic was built for, so every *KEEP.md under it applies tree-wide -- the SAME delimited/unambiguous
# match rule as an ordinary KEEP.md, just checked against every such file rather than one per directory
# level.
mapfile -t CONFIG_KEEPFILES < <(find "$TREE/config" -maxdepth 1 -type f -name '*KEEP.md' 2>/dev/null)
KEEPFILES+=("${CONFIG_KEEPFILES[@]}")
# ⛔⭐⭐ THE DECLARATION CHECK WAS A RAW SUBSTRING TEST OVER EVERY KEEP.md CONCATENATED, AND IT UNDER-COUNTED
# (seat14 2026-08-29, measured; cured here by hq_P). The old form was:
#     DECLARED=$(cat "${KEEPFILES[@]}"); case "$DECLARED" in *"$b"*) : ;; ... esac
# — two independent defects on one line, BOTH of which make the gate report FEWER undeclared files than exist,
# i.e. they push it toward FALSE GREEN:
#   (1) SCOPE WAS DESTROYED. Every KEEP.md in the tree was concatenated, so a KEEP.md in one subdirectory
#       silently declared same-named files anywhere else. MEASURED: writing tests/prolog/KEEP.md to rule on
#       ONE file (plunit.pl) dropped loose-but-undeclared by THREE — frontend/plunit.pl was declared by
#       accident purely through a basename collision.
#   (2) THE MATCH WAS AN UNDELIMITED SUBSTRING, so `foo.pl` matches inside `myfoo.pl`, and any KEEP.md that
#       merely MENTIONS another file's name — to contrast it, exclude it, or cross-reference it, which is a
#       normal and good thing to write in prose — silently declared that file too.
# ⭐ THE CURE KEEPS THE PROSE FORMAT (every real KEEP.md is prose with backticked names; a structured-list
# requirement would invalidate all of them). Instead: a KEEP.md may only declare files in ITS OWN DIRECTORY
# or below it, and the basename must appear DELIMITED — bounded by a non-filename character on each side.
# ⛔ Prose mention WITHIN the owning directory still counts as a declaration; that surface is deliberately
# left, because narrowing it further needs a format change and would break every existing KEEP.md. The
# declaring file is now PRINTED for each kept file, so an accidental declaration is visible instead of silent.
# ⭐ AMBIGUITY IS THE ACTUAL TEST, not path depth. Two rules were tried and BOTH were wrong:
#   bare basename anywhere in any KEEP.md  -> seat14's measured false positive (a root KEEP.md naming
#                                             `plunit.pl` silently declared frontend/plunit.pl too);
#   path relative to the KEEP.md, always   -> a FALSE RED on 66 real files: tests/snocone/ladder/KEEP.md
#                                             legitimately declares ladder/prog/*.sc by bare basename, and
#                                             there is nothing ambiguous about it.
# ⛔ What made seat14's case wrong was not the bare name, it was that the bare name was AMBIGUOUS — two loose
# files shared it and only one was meant. So: a bare basename declares a file only when that basename is
# UNIQUE among the loose files; when two or more share it, the declaration must be written as the path
# relative to the KEEP.md. Unambiguous trees keep working untouched; ambiguous ones must say which they mean.
# ⛔⭐⭐ A DEFERRAL RECORDS INTENT, NOT REACHABILITY (hq_B 2026-08-29, on hq_P + seat05's finding).
# A file can be correctly deferred -- named, reasoned, pointed at a LIVE row -- and simultaneously run by
# NOTHING. The two facts are independent and this gate reported only the first, which made the state read as
# under control. MEASURED WITNESS: tests/prolog/rung31_bridge_catch/{04,05}_*.pl and
# rung38_iso_errors/03_existence_error.pl are all correctly deferred here, and their family runners were
# repointed at the consolidated suite -- which contains ZERO `throw(` and ZERO `existence_error` -- so nothing
# executes them. The board stays green because nothing fails, and nothing fails because nothing runs.
# ⛔ REFERENCING THE FAMILY IS NOT REACHING THE FILE. A consolidated runner names its family and points at
# <family>.pl only; matching the family name would call every orphaned directory file "reachable" and the
# check would certify exactly the state it exists to catch. Match the PATH or the BASENAME, or a runner that
# globs the file's OWN directory -- nothing weaker.
# ⛔ AND A GATE THAT MERELY LISTS A FILE IS NOT A RUNNER: this script and the declaration files are excluded,
# or the census would count its own reading of a name as evidence that something executes it.
# ⭐ SCOPE, stated because the general problem is bigger than what this can check (hq_P's sweep): of 140
# consolidated suites only FIVE still have a directory. Where the loose files are GONE, "is anything running
# this file" has to become "is anything running what this file COVERED" -- a construct check, not a path
# check. This gate answers the path question for files that still exist, which is exactly the population a
# PENDING.md declares. It does NOT answer the construct question, and must not be read as though it does.
gate_reachable() {   # <abs-path> -> rc 0 if some runner reaches it
    local _f="$1" _base _dir _rel
    # ⛔ MATCH RELATIVE TO THE CORPUS ROOT, NOT THE SEAT ROOT. A first version stripped only $S4E, producing
    # "corpus/tests/prolog/x.pl" -- but runners write "$CORPUS/tests/prolog/..." and never the literal
    # "corpus/" prefix, so nothing ever matched and the check reported 44 of 44 deferred files DARK. A census
    # that finds 100% of its population guilty is indicting itself, not the tree; that implausibility is the
    # only reason the bug was caught before it landed as a finding.
    _base="$(basename "$_f")"; _dir="$(dirname "$_f")"
    _rel="${_f#"$S4E"/corpus/}"          # tests/prolog/x.pl  -- the form runners actually spell
    _reldir="${_dir#"$S4E"/corpus/}"
    grep -rlF --include='*.sh' --include='*.py' -e "$_base" -e "$_rel" "$S4E/harness/scripts" 2>/dev/null \
      | grep -v 'test_gate_suite_conversion_complete\.sh' | grep -q . && return 0
    # ⛔⭐ A PER-FILE RUNNER THAT STRIPS THE EXTENSION IS STILL A RUNNER (seat13 2026-09-04, found while proving
    # the fix below actually holds a positive control: fixing arms 2/3 turned rung36_jcon_{genqueen,proto,
    # recogn,var}.icn DARK, but test_icon_ir_rung_36.sh runs each of them explicitly -- `run rung36_jcon_
    # genqueen`, no `.icn` -- so the exact-basename check above never saw it. Delimited (not a bare substring,
    # so "rung36_jcon_scan" does not also match "rung36_jcon_scan2") the same way KEEP.md/PENDING.md entries
    # already are below.
    _stem="${_base%.*}"
    grep -rlE --include='*.sh' --include='*.py' -e "(^|[^A-Za-z0-9_])${_stem}([^A-Za-z0-9_]|\$)" "$S4E/harness/scripts" 2>/dev/null \
      | grep -v 'test_gate_suite_conversion_complete\.sh' | grep -q . && return 0
    # ⛔⭐ ARM 2 WAS A BARE MENTION OF THE OWN DIRECTORY, NOT A REFERENCE THAT COULD REACH THE FILE (seat02
    # measured: a synthetic file named by nobody still cleared, on all seven trees; isolated to this arm, not
    # the ancestor+find arm below). Ten scripts name "tests/icon/" in prose, a KEEP.md/PENDING.md cross-
    # reference, or an unrelated path prefix -- none of that is a runner. Require the directory to be followed
    # by an actual glob wildcard, i.e. a pattern that would match files in it -- nothing weaker. Deliberately
    # NOT reusing the ancestor arm's bare "co-occurring find" heuristic here: checked against this tree, that
    # heuristic also fires on the English word "find" in a comment/echo and on a `find` scoped to unrelated
    # filenames, which would have re-opened the same false-clear this row exists to close.
    # ⛔ THE WILDCARD ALONE IS STILL AMBIGUOUS: `*/corpus/tests/icon/*)` in update_icon_bench_asm.sh is a shell
    # `case` PATTERN testing whether some OTHER path falls under this directory (it's the script's REFUSAL
    # guard for exactly this tree, not a runner) -- textually indistinguishable from a directory glob unless
    # the extension is required too. A real file-enumerating glob names the language extension it wants;
    # a case-arm path guard does not. Require both.
    grep -rlF --include='*.sh' --include='*.py' -e "$_reldir/*${EXT#\*}" "$S4E/harness/scripts" 2>/dev/null \
      | grep -v 'test_gate_suite_conversion_complete\.sh' | grep -q . && return 0
    # ⛔⭐⭐ AN ANCESTOR + A RECURSIVE SWEEP REACHES THIS FILE, AND THE CHECK ABOVE CANNOT SEE IT. Measured
    # 2026-08-30 (hq_B): tests/prolog/coverage/coverage_net_gaps.pl was reported DARK -- "declared against a
    # live row, and executed by nothing" -- and it is file #2 of the 45 that test_corpus_prolog_parser.sh
    # sweeps, which is GREEN and is the manifest's own GATED harness for tests/prolog. That runner names only
    # the TREE ROOT ("$S4E/corpus/tests/prolog") and reaches every subdirectory via `find`. Nothing in the
    # file's own basename, relative path, or own directory appears in any script, so all three greps missed.
    # ⭐ THE GATE WAS RIGHT ABOUT THE POPULATION AND WRONG ABOUT THE MEMBER, WHICH IS THE EXPENSIVE DIRECTION:
    # a false DARK fails a row's DONE-WHEN on a file that is genuinely executed, so the row can never close
    # and the message tells its owner to go fix something that is not broken.
    # ⛔ AND `find` CO-OCCURRENCE IS REQUIRED, not just the ancestor name. A script naming an ancestor and
    # then globbing `"$DIR"/*.pl` at ONE level does NOT reach a subdirectory, and clearing on the name alone
    # would trade a false DARK for a false CLEAR -- the dangerous direction, since a file wrongly declared
    # reachable is exactly the untested-but-managed state this whole check exists to expose.
    # ⚠️ HONEST LIMIT, stated because the next reader will otherwise assume more: this is still TEXTUAL. It
    # proves a script names an ancestor and does recursive discovery somewhere in its body; it does not prove
    # that particular `find` is rooted at that particular ancestor, nor that its -name filter matches this
    # file. Reachability is only truly answerable by asking the runners what they ran. This narrows a
    # measured false positive; it does not make the question sound.
    # ⛔⭐ MEASURED 2026-09-04 (seat13, same baton): the walk stopped short of "corpus" but not of "tests" --
    # one node shallower, and just as tree-wide. Bare "tests" co-occurs with a find-shaped token in 66 scripts
    # across ALL SEVEN languages (confirmed live: e.g. test_gate_argnote_sweep.sh's `find "$CORPUS" ... -name
    # '*.sno'`, SNOBOL4-only and unrelated to an Icon file), so ANY file directly under ANY tests/<lang>/ tree
    # cleared via this arm alone, independent of arm 2 above -- the row's own SCOPE note ruled this arm out;
    # this measurement supersedes that call (recorded in the LEDGER, not silently). Excluded on the same
    # footing as "corpus": "tests/<lang>" (one level deeper) stays a checkable ancestor, unchanged.
    local _anc="$_reldir"
    while [ -n "$_anc" ] && [ "$_anc" != "." ] && [ "$_anc" != "corpus" ] && [ "$_anc" != "tests" ]; do
        _anc="$(dirname "$_anc")"
        [ "$_anc" = "." ] && break
        [ "$_anc" = "tests" ] && break
        while IFS= read -r _cand; do
            [ -n "$_cand" ] || continue
            grep -qE '(^|[^[:alnum:]_])find[[:space:]]' "$_cand" 2>/dev/null && return 0
        done < <(grep -rlF --include='*.sh' --include='*.py' -e "$_anc" "$S4E/harness/scripts" 2>/dev/null \
                 | grep -v 'test_gate_suite_conversion_complete\.sh')
    done
    return 1
}

declare -A _BNC=()
for f in "${LOOSE[@]}"; do _b=$(basename "$f"); _BNC["$_b"]=$(( ${_BNC["$_b"]:-0} + 1 )); done
UND=0; UNDLIST=""; DECLBY=""; AMBIG=0
DEF=0; DEFLIST=""; DEFROWS=""; PBAD=0; PBADLIST=""; PUNV=0; PUNVLIST=""
DARK=0; DARKLIST=""
for f in "${LOOSE[@]}"; do
    b=$(basename "$f"); d=$(dirname "$f"); found=""; via=""
    probe="$d"
    while : ; do
        k="$probe/KEEP.md"
        if [ -f "$k" ]; then
            rel=${f#$probe/}; rre=${rel//./[.]}
            if grep -qE "(^|[^A-Za-z0-9_./-])$rre([^A-Za-z0-9_-]|$)" "$k" 2>/dev/null; then found="$k"; via="path"; break; fi
            if [ "${_BNC[$b]}" -eq 1 ]; then
                bre=${b//./[.]}
                if grep -qE "(^|[^A-Za-z0-9_./-])$bre([^A-Za-z0-9_-]|$)" "$k" 2>/dev/null; then found="$k"; via="name"; break; fi
            fi
        fi
        [ "$probe" = "$TREE" ] && break
        parent=$(dirname "$probe"); [ "$parent" = "$probe" ] && break; probe="$parent"
    done
    # config/*KEEP.md applies tree-wide (see CONFIG_KEEPFILES above) -- checked only once the ordinary
    # per-ancestor walk above found nothing, same delimited/unambiguous rule, relative to TREE (not to
    # config/, since a config/ file describes files sitting flat in TREE, not itself).
    if [ -z "$found" ]; then
        rel=${f#$TREE/}; rre=${rel//./[.]}
        for k in "${CONFIG_KEEPFILES[@]}"; do
            if grep -qE "(^|[^A-Za-z0-9_./-])$rre([^A-Za-z0-9_-]|$)" "$k" 2>/dev/null; then found="$k"; via="path"; break; fi
            if [ "${_BNC[$b]}" -eq 1 ]; then
                bre=${b//./[.]}
                if grep -qE "(^|[^A-Za-z0-9_./-])$bre([^A-Za-z0-9_-]|$)" "$k" 2>/dev/null; then found="$k"; via="name"; break; fi
            fi
        done
    fi
    if [ -n "$found" ]; then DECLBY="$DECLBY\n     ${f#$TREE/}  <-  ${found#$TREE/} (by $via)"
    else
        # Not a keeper. Before calling it undeclared, ask whether a PENDING.md defers it to a live row --
        # SAME directory-scoped walk and SAME delimited/unambiguous matching rules as KEEP.md above, because
        # a second, laxer matcher here would reintroduce exactly the two defects hq_P cured in that one.
        pfound=""; pvia=""; prow=""
        pprobe="$d"
        while : ; do
            pk="$pprobe/PENDING.md"
            if [ -f "$pk" ]; then
                pblk="$(pending_deferred_block "$pk")"
                prel=${f#$pprobe/}; prre=${prel//./[.]}; pbre=${b//./[.]}
                # Walk the sections so the row is taken from the heading that actually lists this file.
                psec=""
                while IFS=$'\t' read -r _row _item; do
                    [ -n "$_item" ] || continue
                    if printf '%s' "$_item" | grep -qE "(^|[^A-Za-z0-9_./-])$prre([^A-Za-z0-9_-]|$)"; then pfound="$pk"; pvia="path"; psec="$_row"; break; fi
                    if [ "${_BNC[$b]}" -eq 1 ] && printf '%s' "$_item" | grep -qE "(^|[^A-Za-z0-9_./-])$pbre([^A-Za-z0-9_-]|$)"; then pfound="$pk"; pvia="name"; psec="$_row"; break; fi
                done < <(pending_sections "$pk")
                if [ -n "$pfound" ]; then
                    # ⛔ @FILEROW@ is the sentinel for a BARE `## DEFERRED` heading, and it is not cosmetic.
                    # An empty first field with IFS=<tab> makes `read` treat the leading tab as leading IFS
                    # whitespace and STRIP it, shifting the list item into the row variable -- so every bare
                    # heading silently stopped deferring, while per-section headings kept working. Caught only
                    # because the bare-heading arm was re-run after adding per-section rows; testing just the
                    # new feature would have shipped a regression that un-declares the common case.
                    if [ -n "$psec" ] && [ "$psec" != "@FILEROW@" ]; then prow="$psec"; else prow="$(pending_row_of "$pk")"; fi
                    break
                fi
                # A PENDING.md with NO `## DEFERRED` block declares nothing at all. Say so once, loudly:
                # silence here would read as "this file is not deferred" and hide a malformed declaration.
                if [ -z "$pblk" ] && [ -z "${_PBLK_WARNED:-}" ]; then
                    echo "note: $pk has no '## DEFERRED' section — it declares nothing; deferrals must be '- ' list items under that heading"
                    _PBLK_WARNED=1
                fi
            fi
            [ "$pprobe" = "$TREE" ] && break
            pparent=$(dirname "$pprobe"); [ "$pparent" = "$pprobe" ] && break; pprobe="$pparent"
        done
        if [ -n "$pfound" ] && [ -z "$prow" ]; then
            PBAD=$((PBAD+1)); PBADLIST="$PBADLIST\n     ${f#$TREE/}  <-  ${pfound#$TREE/}  (NO 'ROW:' LINE -- a deferral must name the row it waits on)"
        elif [ -n "$pfound" ]; then
            st="$(pending_row_state "$prow")"
            case "$st" in
                LIVE)         DEF=$((DEF+1)); DEFROWS="$DEFROWS $prow"
                              if gate_reachable "$f"; then DEFLIST="$DEFLIST\n     ${f#$TREE/}  ->  $prow  (live; by $pvia)"
                              else DARK=$((DARK+1)); DARKLIST="$DARKLIST\n     ${f#$TREE/}  ->  $prow  (deferred to a LIVE row, but NO RUNNER REACHES IT)"; fi;;
                UNVERIFIABLE) PUNV=$((PUNV+1)); PUNVLIST="$PUNVLIST\n     ${f#$TREE/}  ->  $prow  (queue unreadable at $PO)";;
                *)            PBAD=$((PBAD+1)); PBADLIST="$PBADLIST\n     ${f#$TREE/}  ->  $prow  ($st -- deferral is stale, convert these now)";;
            esac
        else
            UND=$((UND+1)); UNDLIST="$UNDLIST\n     ${f#$TREE/}"
            [ "${_BNC[$b]}" -gt 1 ] && AMBIG=$((AMBIG+1))
        fi
    fi
done
[ "$AMBIG" -gt 0 ] && echo "note: $AMBIG undeclared file(s) share a basename with another loose file — declare those by path relative to the KEEP.md, not by bare name"
mapfile -t PENDFILES < <(find "$TREE" -type f -name 'PENDING.md' 2>/dev/null)
DEFROWS_U="$(printf '%s\n' $DEFROWS | grep -v '^$' | sort -u | tr '\n' ' ')"
echo "KEEP.md file(s) found: ${#KEEPFILES[@]}   PENDING.md file(s) found: ${#PENDFILES[@]}"
echo "loose-but-undeclared: $UND   deferred-to-live-row: $DEF   deferred-but-DARK: $DARK   stale-deferral: $PBAD   unverifiable-deferral: $PUNV"
[ "$DEF"  -gt 0 ] && { echo "deferred to another row (NOT converted, NOT keepers -- this gate certifies THIS row's scope, not the tree's completeness):"; printf "$DEFLIST\n" | grep -v '^[[:space:]]*$'; }
# ⛔ A STALE DEFERRAL IS A FAILURE, NOT A NOTE. The row it waits on is gone or already DONE, so nothing will ever
# convert these -- which is precisely the permanent-allowance state PENDING.md exists to make impossible.
# ⛔ DEFERRED-BUT-DARK IS A FAILURE, NOT A NOTE. The file is not "waiting to be converted"; it is not being
# tested at all, and the deferral is what makes that look intentional. Cure: fold its constructs into the
# consolidated suite, or repoint a runner at it -- do NOT delete the declaration to quiet the gate.
if [ "$DARK" -ne 0 ]; then
    echo "GATE FAILED -- $DARK deferred file(s) are DARK: declared against a live row, and executed by nothing:"
    printf "$DARKLIST\n" | grep -v '^[[:space:]]*$'
    echo "     -> a deferral records INTENT, not REACHABILITY. These are not 'not yet converted', they are"
    echo "        UNTESTED, and the declaration is what makes that state look managed."
    echo "     -> fix by folding the constructs into the consolidated suite, or by repointing a runner."
    exit 1
fi
if [ "$PBAD" -ne 0 ]; then
    echo "GATE FAILED -- $PBAD file(s) deferred to a row that is DONE, missing, or unnamed:"
    printf "$PBADLIST\n" | grep -v '^[[:space:]]*$'
    echo "     -> a deferral whose row has landed has outlived its reason: CONVERT these now, or if they are"
    echo "        genuinely permanent, move them to a KEEP.md with a reason. Do not repoint PENDING.md at a"
    echo "        fresh row to keep the gate quiet -- that is the allowance this bucket was built to refuse."
    exit 1
fi
if [ "$UND" -eq 0 ] && [ "$PUNV" -ne 0 ]; then
    echo "REFUSES rc=2: $PUNV deferral(s) name a row but the queue is unreadable at $PO, so they cannot be"
    echo "   verified. An unverified deferral is not a keeper and must never be counted as one."
    printf "$PUNVLIST\n" | grep -v '^[[:space:]]*$'
    exit 2
fi
if [ "$UND" -ne 0 ]; then
    echo "GATE FAILED -- $UND loose file(s) neither converted nor declared as keepers:"
    # ⛔⭐ THE LIST IS CAPPED AND THE CAP MUST ANNOUNCE ITSELF (hq_B 2026-08-29). This printed 19 names under
    # a "44 loose file(s)" headline with nothing saying the list was partial, so a seat working from the
    # printed list fixes what it can see, re-runs, and meets 25 files it was never shown. Same family as
    # `ls | head -5` read as absence, and as `command -v` answering a narrower question than was asked:
    # an instrument that truncates silently reports a subset in the shape of a whole.
    if [ -n "${SUITE_GATE_LIST_ALL:-}${GATE_LIST_ALL:-}" ]; then  # GATE_LIST_ALL is the fleet-wide spelling; SUITE_GATE_LIST_ALL kept as an alias
        printf "$UNDLIST\n" | grep -v '^[[:space:]]*$'
    else
        printf "$UNDLIST\n" | grep -v '^[[:space:]]*$' | head -20
        [ "$UND" -gt 20 ] && {
            echo "     ... and $((UND - 20)) MORE NOT SHOWN -- this list is capped at 20; $UND above is the true count."
            echo "     Full list: SUITE_GATE_LIST_ALL=1 bash ../harness/scripts/test_gate_suite_conversion_complete.sh $LANG_DIR"
        }
    fi
    echo "     -> convert them, or name each in a KEEP.md WITH ITS REASON. Do not raise an allowance."
    exit 1
fi
if [ "$DEF" -gt 0 ]; then
    echo "GATE OK for the tests-consolidate-$LANG_DIR ROW -- $((${#LOOSE[@]} - DEF)) loose file(s) declared STANDALONE-KEEP."
    echo "⛔ THE TREE IS NOT FULLY CONSOLIDATED: $DEF file(s) remain, deferred to live row(s): $DEFROWS_U"
    echo "   This verdict certifies THIS row's scope only. The tree is complete when those rows land and this"
    echo "   gate is re-run with their PENDING.md removed -- at which point a stale deferral would FAIL it."
    exit 0
fi
echo "GATE OK -- ${#LOOSE[@]} loose file(s), all declared STANDALONE-KEEP. Conversion complete for $LANG_DIR."
exit 0
