#!/usr/bin/env bash
# lib_paths.sh -- WHERE EACH REPO LIVES, SET ONCE: THE ABSOLUTE MODEL (row harness-corpus-and-harness-live-once-on-disk-one-seat-owns-them, officer_02 2026-11-13; Lon 18:0x
# CST, in the coo's window, verbatim: "So I'm creating /home/corpus and /home/harness for the ENTIRE FLEET to share. So get those scripts fixed."; 18:1x: "a root folder is
# either a SCRIP, snobol4dotnet, or snobol4jvm clone with no siblings ... all shell scripts will change from the SIBLING model to the ABSOLUtE model."). Source it; it exports:
#   S4E_SCRIP    the seat's SCRIP clone: $S4E_SCRIP when set, else the root itself when the root IS a SCRIP clone (it holds src/ and a Makefile), else <root>/SCRIP
#   S4E_CORPUS   $S4E_CORPUS when set, else /home/corpus once it is a checkout (it holds .git), else <root>/corpus
#   S4E_HARNESS  $S4E_HARNESS when set, else /home/harness once it is a checkout, else <root>/harness
#   S4E_GITHUB   $S4E_GITHUB when set, else /home/.github once it is a checkout, else <root>/.github
# <root> is $S4E_HOME, else the root this script sits in. Each falls back to the sibling while its absolute checkout is absent, so sourcing this moves nothing on a
# box that has not moved. harness_paths.py is the same rule for Python; the two agree (bash lib_paths.sh --selftest).
#   bash lib_paths.sh --show       one line, each variable and where it came from (env, root, sibling, one-disk)
#   bash lib_paths.sh --selftest   the environment wins; the siblings with nothing absolute; the root as the SCRIP clone; the one-disk checkouts; Python agrees. LIB_PATHS ok|RED
_s4e_paths_root="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
_s4e_paths_top="${S4E_ONE_DISK_TOP:-/home}"
_s4e_paths_pick() {   # <env value> <one-disk dir> <sibling dir>
    if [ -n "$1" ]; then printf '%s\tenv' "$1"; elif [ -e "$2/.git" ]; then printf '%s\tone-disk' "$2"; else printf '%s\tsibling' "$3"; fi
}
if [ -n "${S4E_SCRIP:-}" ]; then _s4e_scrip_from=env
elif [ -d "$_s4e_paths_root/src" ] && [ -f "$_s4e_paths_root/Makefile" ]; then S4E_SCRIP="$_s4e_paths_root"; _s4e_scrip_from=root
else S4E_SCRIP="$_s4e_paths_root/SCRIP"; _s4e_scrip_from=sibling; fi
IFS=$'\t' read -r S4E_CORPUS _s4e_corpus_from <<< "$(_s4e_paths_pick "${S4E_CORPUS:-}" "$_s4e_paths_top/corpus" "$_s4e_paths_root/corpus")"
IFS=$'\t' read -r S4E_HARNESS _s4e_harness_from <<< "$(_s4e_paths_pick "${S4E_HARNESS:-}" "$_s4e_paths_top/harness" "$_s4e_paths_root/harness")"
IFS=$'\t' read -r S4E_GITHUB _s4e_github_from <<< "$(_s4e_paths_pick "${S4E_GITHUB:-}" "$_s4e_paths_top/.github" "$_s4e_paths_root/.github")"
export S4E_SCRIP S4E_CORPUS S4E_HARNESS S4E_GITHUB
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        --show) echo "S4E_SCRIP=$S4E_SCRIP ($_s4e_scrip_from) S4E_CORPUS=$S4E_CORPUS ($_s4e_corpus_from) S4E_HARNESS=$S4E_HARNESS ($_s4e_harness_from) S4E_GITHUB=$S4E_GITHUB ($_s4e_github_from)"; exit 0 ;;
        --selftest)
            me="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; t="$(mktemp -d "/tmp/s4e/${S4E_SEAT:-paths}/lib-paths.XXXXXX" 2>/dev/null || mktemp -d)"; why=""
            un="env -u S4E_SCRIP -u S4E_CORPUS -u S4E_HARNESS -u S4E_GITHUB"
            o="$(S4E_SCRIP=/x/s S4E_CORPUS=/x/c S4E_HARNESS=/x/h S4E_GITHUB=/x/g bash "$me/lib_paths.sh" --show)"
            [ "$o" = "S4E_SCRIP=/x/s (env) S4E_CORPUS=/x/c (env) S4E_HARNESS=/x/h (env) S4E_GITHUB=/x/g (env)" ] || why="$why arm 1: the environment did not win ($o);"
            o="$($un S4E_ONE_DISK_TOP="$t/none" S4E_HOME=/r bash "$me/lib_paths.sh" --show)"
            [ "$o" = "S4E_SCRIP=/r/SCRIP (sibling) S4E_CORPUS=/r/corpus (sibling) S4E_HARNESS=/r/harness (sibling) S4E_GITHUB=/r/.github (sibling)" ] || why="$why arm 2: with nothing absolute the siblings were not read ($o);"
            mkdir -p "$t/root/src" "$t/corpus/.git" "$t/harness/.git" "$t/.github/.git" && : > "$t/root/Makefile"
            o="$($un S4E_ONE_DISK_TOP="$t" S4E_HOME="$t/root" bash "$me/lib_paths.sh" --show)"
            [ "$o" = "S4E_SCRIP=$t/root (root) S4E_CORPUS=$t/corpus (one-disk) S4E_HARNESS=$t/harness (one-disk) S4E_GITHUB=$t/.github (one-disk)" ] || why="$why arm 3: the root as the SCRIP clone and the one-disk checkouts were not read ($o);"
            p="$($un S4E_ONE_DISK_TOP="$t" S4E_HOME="$t/root" python3 -I "$me/harness_paths.py" --show)"; [ "$p" = "$o" ] || why="$why arm 4: harness_paths.py says '$p';"
            o="$($un S4E_ONE_DISK_TOP="$t/none" S4E_HOME=/r bash "$me/lib_paths.sh" --show)"
            p="$($un S4E_ONE_DISK_TOP="$t/none" S4E_HOME=/r python3 -I "$me/harness_paths.py" --show)"; [ "$p" = "$o" ] || why="$why arm 4: harness_paths.py with nothing absolute says '$p';"
            rm -rf "$t"
            [ -z "$why" ] && { echo "LIB_PATHS ok arms=4 (the environment wins; the siblings with nothing absolute; the root as the SCRIP clone and /home/corpus, /home/harness, /home/.github once each is a checkout; Python and bash agree)"; exit 0; }
            echo "LIB_PATHS RED:$why"; exit 1 ;;
        *) echo "usage: source lib_paths.sh | bash lib_paths.sh --show | --selftest" >&2; exit 2 ;;
    esac
fi
