#!/usr/bin/env bash
# lib_build_currency.sh -- THE ONE AUTHORITY ON "IS THE THING I AM ABOUT TO GRADE ACTUALLY BUILT FROM src/?"
#
# ⛔ WHY THIS EXISTS (hq_B measured 2026-09-03, row stale-binary-preflight-also-covers-out-libscrip-rt-so,
# widened by ceo on the class finding): the stale-binary preflight graded ./scrip against src/ mtimes and said
# NOTHING about out/libscrip_rt.so -- the SHIPPED RUNTIME, which lags src/ exactly as the binary can. A 13:37
# .so against a 14:16 src read `exec_stmt` as STILL EXPORTED when it had already been deleted.
# ⭐ THE DANGEROUS DIRECTION IS THE FALSE GREEN: a stale OLDER .so still exports a symbol that source deleted,
# and hides one that source just added. So every `nm -D` verdict -- the rung batons' Prolog-only-globals arm
# included -- can report a clean surface for a runtime nobody is shipping. That is not a slow instrument, it is
# a confident wrong answer, and nothing printed a timestamp to contradict it.
#
# ⛔ SOURCE THIS, NEVER COPY IT (CLAUDE.md: shared authorities are sourced, never reimplemented). Seven
# nm-grading scripts and the artifacts verifier all call these; a second copy is how one of them keeps the old
# rule after the rule changes.
# RULES batch 14 -- AN INSTRUMENT QUOTES ITS REFERENCE: every refusal below prints BOTH timestamps and the file
# that set the newest one, so the reader can act without re-deriving anything.
s4e_bc_newest_src() {   # $1 = repo root; prints an epoch, or 0 when src/ is unreadable
    local root="$1" n
    [ -d "$root/src" ] || { echo 0; return 0; }
    n="$(find "$root/src" -type f -printf '%T@\n' 2>/dev/null | sort -rn | head -1 | cut -d. -f1)"
    [ -n "$n" ] && echo "$n" || echo 0
}
s4e_bc_newest_src_file() {  # $1 = repo root; prints the path that set the newest mtime (for the refusal text)
    local root="$1"
    [ -d "$root/src" ] || return 0
    find "$root/src" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-
}
s4e_bc_stamp() { date -d "@$1" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "@$1"; }
# ⛔ REFUSES rc=2 -- "I could not measure" -- never rc=1 and never a silent pass. A stale artifact does not make
# the verdict WRONG-BUT-CLOSE, it makes the verdict a statement about a different program.
s4e_bc_assert_current() {   # $1 = artifact path, $2 = human label, $3 = repo root (default: artifact/../..)
    local art="$1" label="$2" root="${3:-}" at newest nf
    [ -n "$root" ] || root="$(cd "$(dirname "$art")/.." 2>/dev/null && pwd)"
    [ -e "$art" ] || { echo "⛔ REFUSED-TO-GRADE (rc=2): $label not built: $art" >&2
                       echo "   cure: cd $root && make pristine" >&2; return 2; }
    at="$(stat -Lc %Y "$art" 2>/dev/null || echo 0)"
    newest="$(s4e_bc_newest_src "$root")"
    if [ "$newest" -le 0 ] 2>/dev/null; then
        echo "  build-currency: UNKNOWN (no src/ timestamps readable under $root) — proceeding" >&2; return 0; fi
    if [ "$at" -lt "$newest" ] 2>/dev/null; then
        nf="$(s4e_bc_newest_src_file "$root")"
        echo "⛔ REFUSED-TO-GRADE (rc=2): THE $label PREDATES src/ — any verdict here describes a build nobody is shipping." >&2
        echo "   $art" >&2
        echo "       built      $(s4e_bc_stamp "$at")   [mtime $at]" >&2
        echo "   newest src/ change $(s4e_bc_stamp "$newest")   [$newest]   $nf" >&2
        echo "   ⛔ The dangerous direction is the FALSE GREEN: a stale older artifact still exports what source" >&2
        echo "      deleted and cannot show what source added, so a clean surface here proves nothing." >&2
        echo "   cure: cd $root && make pristine    ⭐ RULES.md:118 LOOSENED pristine for ordinary landings but kept it" >&2
        echo "        for exactly this case — a fired stale-artifact refusal is one of the three that still owes one." >&2
        return 2
    fi
    echo "  build-currency OK: $label [$at] is at or after the newest src/ change [$newest]"
    return 0
}
# assert_parser_current <lang> [root] -- out/parser_<lang> is at or after every source its object was compiled from: the prerequisites
# make itself recorded in $(OBJ)/parser_<lang>.d (-MMD), or src/tools/parser_main.c alone when there is no .d -- so the cure the refusal
# names, make parsers, is always the one that clears it. ⭐ THE PARSE CODE IS NOT IN THAT BINARY (the coo, measured 2026-10-03 on the
# cfo's report that make never rebuilds out/parser_<lang>): nm reads prolog_compile_parse and its six siblings U there, and ldd binds
# them to out/libscrip_rt.so, so a frontend edit reaches the parser through make and the runtime check; what can go stale is the driver
# parser_main.c and the headers it was compiled against, whose layouts it shares with the runtime.
assert_parser_current() {
    local lang="$1" root="${2:-}" art d deps f at newest=0 nf="" m
    [ -n "$root" ] || root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
    art="$root/out/parser_$lang"
    [ -x "$art" ] || { echo "⛔ REFUSED-TO-GRADE (rc=2): out/parser_$lang not built: $art -- cure: cd $root && make parsers" >&2; return 2; }
    d="${OBJ:-/tmp/si_objs$(printf '%s' "$root" | tr / -)}/parser_$lang.d"
    [ -f "$d" ] && deps="$(awk '{ c = /\\$/; sub(/\\$/, ""); print; if (!c) exit }' "$d" | tr ' ' '\n' | grep -v ':$' | grep .)"
    [ -n "${deps:-}" ] || deps="$root/src/tools/parser_main.c"
    at="$(stat -Lc %Y "$art" 2>/dev/null || echo 0)"
    for f in $deps; do
        [ -e "$f" ] || { echo "⛔ REFUSED-TO-GRADE (rc=2): out/parser_$lang was compiled from $f, which no longer exists -- cure: cd $root && make parsers" >&2; return 2; }
        m="$(stat -Lc %Y "$f")"; [ "$m" -gt "$newest" ] && { newest="$m"; nf="$f"; }
    done
    if [ "$at" -lt "$newest" ]; then
        echo "⛔ REFUSED-TO-GRADE (rc=2): out/parser_$lang PREDATES ITS SOURCE -- built $(s4e_bc_stamp "$at"), $nf changed $(s4e_bc_stamp "$newest") -- cure: cd $root && make parsers" >&2
        return 2
    fi
    return 0
}
# The two named entry points every caller uses. Keep the names; they are cited in batons and DONE-WHENs.
assert_so_current()     { s4e_bc_assert_current "${1:-out/libscrip_rt.so}" "RUNTIME out/libscrip_rt.so" "${2:-}"; }
assert_binary_current() { s4e_bc_assert_current "${1:-./scrip}"            "BINARY scrip"                "${2:-}"; }
