#!/usr/bin/env bash
# lib_fixture_root.sh -- A GATE'S SCRATCH ROOT IS A COPY OF THE REAL LAYOUT, NEVER A LINK FARM (Lon 2026-10-17, in-chat to the ceo,
# verbatim: "Do not EVER use symlinks." · "Use proper absolute and relative paths for things." · "You guarantee the all repos are
# siblings at the same level in their root folder. done and done."; ceo CEO-1820). A gate that doctors one harness script and runs it
# used to stage <dir>/scripts as symlinks beside <dir>/scrip; a moved script finds its siblings by fixed relative paths from its own
# folder (<dir>/harness/scripts/../../SCRIP), so the stage must be the real shape and real files. Source this beside lib_gate.sh.
#
#   fixture_root <dir>          stage <dir>/harness/scripts (a copy of this folder) and <dir>/SCRIP (scrip, Makefile, out/libscrip_rt.so)
#   fixture_root_src <dir>      add a copy of SCRIP/src (16 MB) for a gate that reads the compiler's source
#   fixture_root_corpus <dir>   add a copy of the sibling corpus (for a gate that grades programs from the stage)
# Each returns 0 staged, 2 when the real tree lacks a piece (the caller turns that into COULD NOT MEASURE). The copied scrip keeps its
# RUNPATH to the real out/, so it runs from the stage; the copied out/libscrip_rt.so serves the mode-4 link lines.
fixture_root() {
    local _d="$1" _h _s _f
    _h="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || return 2
    _s="$(cd "$_h/../../SCRIP" 2>/dev/null && pwd)" || return 2
    mkdir -p "$_d/harness/scripts" "$_d/SCRIP/out" || return 2
    cp -r "$_h/." "$_d/harness/scripts/" || return 2
    for _f in scrip Makefile; do [ -e "$_s/$_f" ] && { cp "$_s/$_f" "$_d/SCRIP/$_f" || return 2; }; done
    [ -e "$_s/out/libscrip_rt.so" ] && { cp "$_s/out/libscrip_rt.so" "$_d/SCRIP/out/libscrip_rt.so" || return 2; }
    return 0
}
fixture_root_src() {
    local _d="$1" _s
    _s="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" 2>/dev/null && pwd)" || return 2
    [ -d "$_s/src" ] || return 2
    cp -r "$_s/src" "$_d/SCRIP/src" || return 2
    return 0
}
fixture_root_corpus() {
    local _d="$1" _c
    _c="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../corpus" 2>/dev/null && pwd)" || return 2
    cp -r "$_c" "$_d/corpus" || return 2
    return 0
}
fixture_corpus_light() {
    local _c="$1" _d="$2" _x
    shift 2
    [ -d "$_c" ] || return 2
    mkdir -p "$_d" || return 2
    for _x in include library reference editor_configs "$@"; do
        [ -e "$_c/$_x" ] || continue
        [ -e "$_d/$_x" ] && continue
        mkdir -p "$_d/$(dirname "$_x")" || return 2
        cp -a "$_c/$_x" "$_d/$_x" || return 2
    done
    return 0
}
