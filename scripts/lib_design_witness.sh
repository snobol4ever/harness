#!/usr/bin/env bash
# lib_design_witness.sh -- A DESIGN WITNESS IS A CONTAINER ENTRY, GRADED BY ENTRY (CIO-24 c, the coo 2026-11-10; row
# tests-layout-the-one-add-a-witness-tool-takes-any-family-and-a-step-harness-grades-an-entry). A step harness (test_design_<plan>_steps.sh)
# sources this in place of its own loose-file grader once its witnesses are entries of their language's master (util_add_ladder_witness.py
# --family PLAN --from PAIR):
#   design_witness_grade LANG ENTRY [MODES]        corpus_suite_harness.py run over corpus/tests/LANG/ALL.<ext> with --partition entry:ENTRY,
#                                                  progress off, MODES default m3; returns its rc (0 PASS, 1 red, 2 cannot measure)
#   design_witness_extract LANG ENTRY DIR          writes DIR/<ENTRY>.<ext>, DIR/<ENTRY>.ref (and DIR/<ENTRY>.in when it reads stdin) for a probe
#                                                  that compiles or dumps the witness's own file; returns the extractor's rc
#   design_witness_has LANG ENTRY                  rc 0 when the master holds ENTRY, 1 when it does not (a witness its language row has not absorbed)
# DESIGN_WITNESS_DIR names another container directory (a gate's scratch copy); DESIGN_WITNESS_TIMEOUT bounds one grade (default 900 s).
_dw_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_dw_root="$(cd "$_dw_here/../.." && pwd)"
_dw_ext() { case "$1" in snobol4) echo sno ;; icon) echo icn ;; prolog) echo pl ;; pascal) echo pas ;; raku) echo raku ;; rebus) echo reb ;; snocone) echo sc ;; *) echo "" ;; esac; }
_dw_dir() { echo "${DESIGN_WITNESS_DIR:-$_dw_root/corpus/tests/$1}"; }
_dw_check() {
    local ext dir; ext="$(_dw_ext "$1")"; dir="$(_dw_dir "$1")"
    [ -n "$ext" ] || { echo "REFUSE(2) [lib_design_witness]: no language $1" >&2; return 2; }
    { [ -f "$dir/ALL.$ext" ] && [ -f "$dir/ALL.ref" ]; } || [ -f "$dir/ONE-LINERS.$ext" ] || [ -f "$dir/MULTI-LINERS.md" ] || { echo "REFUSE(2) [lib_design_witness]: no container in $dir (ALL.$ext and ALL.ref, or format 2 ONE-LINERS.$ext or MULTI-LINERS.md)" >&2; return 2; }
    return 0
}
design_witness_grade() {
    local lang="$1" entry="$2" modes="${3:-m3}" ext dir
    _dw_check "$lang" || return 2
    ext="$(_dw_ext "$lang")"; dir="$(_dw_dir "$lang")"
    ( cd "$_dw_root/SCRIP" && S4E_PROGRESS_OFF=1 timeout -k 10 "${DESIGN_WITNESS_TIMEOUT:-900}" python3 "$_dw_here/corpus_suite_harness.py" run "$dir/ALL.$ext" "$dir/ALL.ref" --lang "$lang" --modes "$modes" --partition "entry:$entry" < /dev/null )
}
design_witness_extract() {
    local lang="$1" entry="$2" out="$3" ext dir
    _dw_check "$lang" || return 2
    ext="$(_dw_ext "$lang")"; dir="$(_dw_dir "$lang")"; mkdir -p "$out" || return 2
    python3 "$_dw_here/corpus_suite_harness.py" extract "$dir/ALL.$ext" "$dir/ALL.ref" "$entry" "$out/$entry.$ext" --out-ref "$out/$entry.ref" --out-in "$out/$entry.in" < /dev/null
}
design_witness_has() {
    local lang="$1" entry="$2" ext dir
    _dw_check "$lang" || return 2
    ext="$(_dw_ext "$lang")"; dir="$(_dw_dir "$lang")"
    python3 "$_dw_here/corpus_suite_harness.py" list "$dir/ALL.$ext" "$dir/ALL.ref" --lang "$lang" 2>/dev/null | grep -qxF -- "$entry"
}
# design_witness_stage PLAN STAGE W...  THE WITNESSES OF A PLAN WHOSE FOLDER LEFT corpus/tests/shared (Lon 2026-11-12 09:2x CST: "It seem
#   $/corpus/tests/shared is an invalid folder."): each W is the entry PLAN__W of its language's master when one holds it (extracted with its stdin
#   and its exit code), else the loose pair corpus/tests/<lang>/PLAN/W.* that its language's consolidation has yet to enter, else the instrument
#   fixture harness/fixtures/PLAN/W.* (a program no oracle answers); STAGE/W.<ext> and W.ref (W.in, W.rc nonzero, every loose sidecar) result, and
#   STAGE/.where names each one's source (W TAB entry LANG | W TAB loose DIR). REFUSES rc 2 on a witness none holds: never a silent skip.
design_witness_stage() {
    local plan="$1" st="$2" w l ext dir found d
    shift 2; mkdir -p "$st" || return 2; : > "$st/.where"
    for l in snobol4 icon prolog pascal raku rebus snocone; do
        ext="$(_dw_ext "$l")"; dir="$(_dw_dir "$l")"
        _dw_check "$l" 2>/dev/null || { : > "$st/.list.$l"; continue; }
        python3 "$_dw_here/corpus_suite_harness.py" list "$dir/ALL.$ext" "$dir/ALL.ref" --lang "$l" < /dev/null > "$st/.list.$l" 2>/dev/null \
            || { echo "REFUSE(2) [lib_design_witness]: the $l master did not list" >&2; return 2; }
    done
    for w in "$@"; do
        found=0
        for l in snobol4 icon prolog pascal raku rebus snocone; do
            grep -qxF -- "${plan}__$w" "$st/.list.$l" || continue
            ext="$(_dw_ext "$l")"; dir="$(_dw_dir "$l")"
            python3 "$_dw_here/corpus_suite_harness.py" extract "$dir/ALL.$ext" "$dir/ALL.ref" "${plan}__$w" "$st/$w.$ext" --out-ref "$st/$w.ref" \
                --out-in "$st/$w.in" --out-rc "$st/$w.rc" < /dev/null > /dev/null 2>&1 \
                || { echo "REFUSE(2) [lib_design_witness]: the entry ${plan}__$w of the $l master did not extract" >&2; return 2; }
            printf '%s\tentry\t%s\n' "$w" "$l" >> "$st/.where"; found=1; break
        done
        [ "$found" = 1 ] && continue
        for d in "$_dw_root"/corpus/tests/*/"$plan" "$_dw_here/../fixtures/$plan"; do
            compgen -G "$d/$w.*" > /dev/null || continue
            cp -r "$d/$w".* "$st/" || return 2
            printf '%s\tloose\t%s\n' "$w" "$(cd "$d" && pwd)" >> "$st/.where"; found=1; break
        done
        [ "$found" = 1 ] || { echo "REFUSE(2) [lib_design_witness]: witness $w of $plan is no entry ${plan}__$w of any master and no loose pair in corpus/tests/*/$plan or harness/fixtures/$plan" >&2; return 2; }
    done
    return 0
}
# design_witness_stage_all PLAN STAGE  every witness of PLAN by design_witness_stage: each entry PLAN__* of a master, each program of a loose folder
#   corpus/tests/<lang>/PLAN, each program of harness/fixtures/PLAN (a plan whose table names its witnesses by a short tag, batch_grader's bg01).
design_witness_stage_all() {
    local plan="$1" st="$2" l ext dir f stems=""
    for l in snobol4 icon prolog pascal raku rebus snocone; do
        ext="$(_dw_ext "$l")"; dir="$(_dw_dir "$l")"
        _dw_check "$l" 2>/dev/null || continue
        stems="$stems $(python3 "$_dw_here/corpus_suite_harness.py" list "$dir/ALL.$ext" "$dir/ALL.ref" --lang "$l" < /dev/null 2>/dev/null | sed -n "s/^${plan}__//p" | tr '\n' ' ')"
    done
    for f in "$_dw_root"/corpus/tests/*/"$plan"/*.{sno,icn,pl,pas,raku,reb,sc} "$_dw_here/../fixtures/$plan"/*.{sno,icn,pl,pas,raku,reb,sc}; do
        [ -f "$f" ] || continue; f="$(basename "$f")"; stems="$stems ${f%.*}"
    done
    stems="$(printf '%s\n' $stems | sort -u | tr '\n' ' ')"
    [ -n "${stems// /}" ] || { echo "REFUSE(2) [lib_design_witness]: $plan has no witness: no entry ${plan}__* and no loose folder" >&2; return 2; }
    design_witness_stage "$plan" "$st" $stems
}
