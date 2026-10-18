#!/usr/bin/env bash
# run_snobol4dotnet.sh -- THE DOTNET ENGINE'S RUNNER (Lon 2026-10-17, to hq_dotnet: "The suite banner should represent the snobol4dotnet
# executable program, not SCRIP." and "hq_dotnet runs them"; ceo CEO-1822). corpus_suite_harness.py run_m3 dispatches here under
# S4E_ENGINE=dotnet, as it calls scrip --run under scrip, and grades what this prints with the same reader, masks, want_rc and refs.
# The calling shape is the one every port runner shares (agreed with hq_jvm's run_snobol4jvm.sh, 2026-10-18):
#
#   run_snobol4dotnet.sh [-dNk] [-sNk] [-u STR] name.sno [-- arg ...]   run one program, cwd its own folder, stdin its input
#   run_snobol4dotnet.sh --binaries [--lang LANG]                       the graded files, driver first, one path per line -- or rc 2
#   run_snobol4dotnet.sh --paths                                        the same paths, checking nothing (the fingerprints read these)
#
# --binaries IS THE ONE CHECK. The harness calls it before the first entry and refuses the board on any non-zero rc, printing this script's
# own line: a language this engine has no front end for (snobol4dotnet runs SNOBOL4 source only -- its Snocone lexer and parser are reached
# by no command line), a build that is missing, a build older than a source of snobol4dotnet, a missing dotnet host. Its paths are the one
# list of this engine's files: the fingerprints, the progress digest and the tree pin (the git toplevel of the driver, the snobol4dotnet
# checkout) all read them. The engine is found beside harness at a FIXED relative path, never through a link or an environment override.
# --paths prints the same list and checks nothing. The fingerprints read it, so a source edited under a running board (which --binaries
# reads as stale) is not mistaken for a moved binary: the measured shape was "start [fa779c77a352 18cffdac938b] end []" and a refused board.
#
# A run's switches are SPITBOL-shaped (declared heap, declared stack, HOST(0)) and snobol4dotnet takes them as SPITBOL does. The language
# flags come from lib_oracle_flags.sh sbl_lang_flags, the one authority the refs were cut under (-bf, no case folding), so the port and its
# refs fold alike by construction. snobol4dotnet takes a program's argv after the source with no separator, as SPITBOL does, so the FIRST
# -- (the one the harness writes after the source) is dropped here and any later one reaches the program.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$(cd "$HERE/../.." && pwd)/snobol4dotnet"
DLL="$ENGINE/Snobol4/bin/Release/net10.0/Snobol4.dll"
RT="$ENGINE/Snobol4/bin/Release/net10.0/Snobol4.Common.dll"
BUILD="dotnet build snobol4dotnet/Snobol4/Snobol4.csproj -c Release"
if [ "${1:-}" = --paths ]; then
    printf '%s\n%s\n' "$DLL" "$RT"
    exit 0
fi
if [ "${1:-}" = --binaries ]; then
    lang=snobol4; [ "${2:-}" = --lang ] && lang="${3:-}"
    [ "$lang" = snobol4 ] || { echo "⛔ run_snobol4dotnet.sh: NO ENGINE for $lang -- snobol4dotnet runs SNOBOL4 source only" >&2; exit 2; }
    command -v dotnet > /dev/null || { echo "⛔ run_snobol4dotnet.sh: the dotnet host is not on PATH" >&2; exit 2; }
    [ -f "$DLL" ] && [ -f "$RT" ] || { echo "⛔ run_snobol4dotnet.sh: snobol4dotnet is not built at $DLL -- $BUILD" >&2; exit 2; }
    # each project's sources against its own output, so a console-only edit that rebuilds Snobol4.dll alone does not read stale forever
    stale="$( { find "$ENGINE/Snobol4.Common" -name '*.cs' -newer "$RT" -not -path '*/obj/*' -not -path '*/bin/*' -print -quit
               find "$ENGINE/Snobol4" -maxdepth 1 -name '*.cs' -newer "$DLL" -print -quit; } 2>/dev/null | head -1)"
    [ -z "$stale" ] || { echo "⛔ run_snobol4dotnet.sh: the build is older than ${stale#"$ENGINE/"} -- $BUILD" >&2; exit 2; }
    printf '%s\n%s\n' "$DLL" "$RT"
    exit 0
fi
# shellcheck source=lib_oracle_flags.sh
. "$HERE/lib_oracle_flags.sh" || exit 2
read -r -a lang_flags <<< "$(sbl_lang_flags)"
args=(); sep=0
for a in "$@"; do
    if [ "$a" = -- ] && [ "$sep" = 0 ]; then sep=1; continue; fi
    args+=("$a")
done
exec dotnet "$DLL" "${lang_flags[@]}" "${args[@]}"
