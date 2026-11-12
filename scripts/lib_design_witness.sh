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
    { [ -f "$dir/ALL.$ext" ] && [ -f "$dir/ALL.ref" ]; } || [ -f "$dir/ONE.$ext" ] || [ -f "$dir/MULTI.md" ] || { echo "REFUSE(2) [lib_design_witness]: no container in $dir (ALL.$ext and ALL.ref, or format 2 ONE.$ext or MULTI.md)" >&2; return 2; }
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
