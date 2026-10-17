#!/usr/bin/env bash
# lib_build_flags.sh -- THE ONE AUTHORITY for "compile this TU the way the build does" and for "can bison/flex generate here", read from the
# Makefile and the toolchain AT CALL TIME. Sourced by util_style200_oracle.sh, util_style200_oracle_yl.sh and
# regenerate_parser_and_lexer_from_sources.sh. Never hand-copy an -I list: both oracles carried the pre-reorg homes (src/parser/,
# src/contracts, src/machine) for months and graded zero files while printing OK (R5 FINDING, 2026-09-02).
#   build_flags_load [root]         exports BF_CC BF_RT_OPT BF_RT_INCS BF_ZCFLAGS BF_WARN BF_CBASE; rc=2 (REFUSE) if the Makefile yields none
#                                   or RT_INCS names a directory that does not exist (the stale-list class, caught at the source)
#   build_compile_cmd <ext> [rel]   prints compiler + flags for a .c/.cpp/.S/.s TU: the Makefile's four RT pattern rules verbatim minus
#                                   -MMD -MP (dependency side files, no effect on the object); rel=src/driver/scrip.c gets CBASE, as the build does
#   gen_tools_ready                 bison + flex on PATH AND PROVEN to generate (a throwaway grammar each); resolves BISON_PKGDATADIR for the
#                                   rootless ~/.local install; rc=2 otherwise. `command -v bison` once read "present" for a bison that died on
#                                   m4sugar.m4 AFTER printing its conflict summary (hq_C 2026-08-30) -- presence is not the question
#   obj_fingerprint <obj> <out>     the object-identity fingerprint: `objdump -d -r` (instructions WITH relocations -- without -r a call
#                                   retargeted to another function is byte-identical) plus `objdump -s` of EVERY non-debug section (-fPIC
#                                   pointer tables live in .data.rel.local/.data.rel.ro, which a -j .data/.rodata/.bss list never sees)
build_flags_load() {
    local root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)}"
    local db; db="$(make -C "$root" -s -pn buildinfo 2>/dev/null)" || true
    BF_CC="$(printf '%s\n' "$db" | sed -n 's/^CC :\{0,1\}= //p' | head -1)"
    BF_RT_OPT="$(printf '%s\n' "$db" | sed -n 's/^RT_OPT :\{0,1\}= //p' | head -1)"
    BF_RT_INCS="$(printf '%s\n' "$db" | sed -n 's/^RT_INCS :\{0,1\}= //p' | head -1)"
    BF_ZCFLAGS="$(printf '%s\n' "$db" | sed -n 's/^ZCFLAGS :\{0,1\}= //p' | head -1)"
    BF_WARN="$(printf '%s\n' "$db" | sed -n 's/^WARN :\{0,1\}= //p' | head -1)"
    BF_CBASE="$(printf '%s\n' "$db" | sed -n 's/^CBASE :\{0,1\}= //p' | head -1 | sed 's/ -MMD -MP//')"
    [ -n "$BF_CC" ] || BF_CC=gcc
    if [ -z "$BF_RT_INCS" ] || [ -z "$BF_RT_OPT" ]; then
        echo "⛔ REFUSE rc=2 [lib_build_flags]: could not read RT_INCS/RT_OPT from $root/Makefile (make -pn buildinfo printed none)" >&2
        return 2
    fi
    local d
    for d in $BF_RT_INCS; do
        case "$d" in -I*) [ -d "${d#-I}" ] || { echo "⛔ REFUSE rc=2 [lib_build_flags]: Makefile RT_INCS names a directory that does not exist: ${d#-I}" >&2; return 2; };; esac
    done
    export BF_CC BF_RT_OPT BF_RT_INCS BF_ZCFLAGS BF_WARN BF_CBASE
    return 0
}
build_compile_cmd() {
    case "${2:-}" in */driver/scrip.c|src/driver/scrip.c) printf '%s %s -c' "$BF_CC" "$BF_CBASE"; return 0;; esac
    case "$1" in
        c)   printf '%s %s -g %s -fPIC %s %s -c' "$BF_CC" "$BF_RT_OPT" "$BF_WARN" "$BF_RT_INCS" "$BF_ZCFLAGS" ;;
        cpp) printf '%s %s -g %s -fPIC -std=c++17 -finput-charset=UTF-8 %s %s -c' "$BF_CC" "$BF_RT_OPT" "$BF_WARN" "$BF_RT_INCS" "$BF_ZCFLAGS" ;;
        S)   printf '%s %s -g %s -fPIC %s %s -c' "$BF_CC" "$BF_RT_OPT" "$BF_WARN" "$BF_RT_INCS" "$BF_ZCFLAGS" ;;
        s)   printf '%s %s -g %s -fPIC %s %s -x assembler-with-cpp -c' "$BF_CC" "$BF_RT_OPT" "$BF_WARN" "$BF_RT_INCS" "$BF_ZCFLAGS" ;;
        *)   return 1 ;;
    esac
}
gen_tools_ready() {
    local t d tmp
    for t in bison flex; do
        command -v "$t" >/dev/null 2>&1 || { echo "⛔ REFUSE rc=2 [lib_build_flags]: $t is not on PATH (rootless recipe: GOAL-STYLE-200COL.md R4; this machine keeps them in ~/.local/bin)" >&2; return 2; }
    done
    if [ ! -f "$(bison --print-datadir 2>/dev/null)/m4sugar/m4sugar.m4" ]; then
        for d in "${BISON_PKGDATADIR:-}" "$HOME/.local/share/bison" /tmp/flexbison/root/usr/share/bison /tmp/fb/root/usr/share/bison /usr/local/share/bison; do
            [ -n "$d" ] && [ -f "$d/m4sugar/m4sugar.m4" ] && { export BISON_PKGDATADIR="$d"; break; }
        done
    fi
    tmp="$(mktemp -d)"
    printf '%%%%\ns: ;\n' > "$tmp/t.y"; printf '%%%%\n. { }\n' > "$tmp/t.l"
    if ! bison -o "$tmp/t.c" "$tmp/t.y" 2>"$tmp/err" || [ ! -s "$tmp/t.c" ]; then
        echo "⛔ REFUSE rc=2 [lib_build_flags]: bison is on PATH but cannot generate -- $(head -1 "$tmp/err"); point BISON_PKGDATADIR at a dir holding m4sugar/m4sugar.m4" >&2; rm -rf "$tmp"; return 2
    fi
    if ! flex -o "$tmp/l.c" "$tmp/t.l" 2>"$tmp/err" || [ ! -s "$tmp/l.c" ]; then
        echo "⛔ REFUSE rc=2 [lib_build_flags]: flex is on PATH but cannot generate -- $(head -1 "$tmp/err")" >&2; rm -rf "$tmp"; return 2
    fi
    rm -rf "$tmp"
    BF_BISON_VERSION="$(bison --version | head -1 | awk '{print $NF}')"; BF_FLEX_VERSION="$(flex --version | awk '{print $NF}')"
    export BF_BISON_VERSION BF_FLEX_VERSION
    return 0
}
obj_fingerprint() {
    local secs; secs="$(objdump -h "$1" | awk '$2 ~ /^\./ && $2 !~ /^\.debug/ && $2 !~ /^\.rela?\.debug/ {print "-j " $2}' | tr '\n' ' ')"
    { objdump -d -r "$1"; objdump -s $secs "$1"; } | grep -v 'file format' > "$2"
}
