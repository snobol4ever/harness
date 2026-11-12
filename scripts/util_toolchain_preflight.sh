#!/usr/bin/env bash
# util_toolchain_preflight.sh -- THE TOOLCHAIN PREFLIGHT (DESIGN-PLAN box-scheduler step 25, worker_10 2026-11-05, CTO-496).
#
# Run it before a build, a grade or a landing: one TOOL line per declared tool says what it proved, and the last line says
# whether this box can build and grade at all. A tool is PROVED by doing its job on a one-line input (gcc compiles and runs a
# program, as and ld link one, nasm assembles, bison generates from a grammar, flex builds a scanner, gdb evaluates an
# expression, sbl -bf runs a one-line program), never by its name resolving: a shadowed or broken binary fails here, in one
# line, instead of as a red deep inside a build or a grade.
#
# THE LIST is the box's own record: harness/scripts/install_system_packages.sh (PKGS, DBG_PKGS) plus the x64 tools built by
# Lon 2026-11-04 (make 4.4.1, GNU parallel) and the SPITBOL oracle. REQUIRED tools fail the preflight (rc 1). OPTIONAL tools are
# declared but read by no build (MEASURED 2026-11-05: the build passed without gmp.h); an absent optional tool is reported with
# the gates that use it and does not fail. The make on PATH is reported beside the make the jobserver joins (util_jobserver.sh
# make, MAKE44), so a 4.3 PATH make reads as a NOTE, never as the build's make.
#
# Paths the box declares may be overridden by env (a plant or a relocated install): PREFLIGHT_MAKE44, PREFLIGHT_PARALLEL,
# PREFLIGHT_SBL. Scratch goes under /tmp/s4e/<seat>/ and is deleted at the verdict.
#
#   bash harness/scripts/util_toolchain_preflight.sh
#     TOOL <name> <REQ|OPT> <ok|MISSING|absent|NOTE> <detail>     one line per tool
#     TOOLCHAIN OK required=<n> optional_absent=<names|none>      rc 0
#     TOOLCHAIN MISSING required=<names> optional_absent=<names>  rc 1
#     TOOLCHAIN UNMEASURED <why>                                  rc 2 (scratch could not be made)
set -u

seat="${S4E_SEAT:-$(id -un)}"
base="${TMPDIR:-/tmp}/s4e/$seat"
mkdir -p "$base" 2>/dev/null || { echo "TOOLCHAIN UNMEASURED no scratch under $base"; exit 2; }
T=$(mktemp -d "$base/toolchain.XXXXXX") || { echo "TOOLCHAIN UNMEASURED mktemp failed under $base"; exit 2; }
trap 'rm -rf "$T"' EXIT
export T

MAKE44="${PREFLIGHT_MAKE44:-/home/resources/x64/bin/make}"
PARALLEL="${PREFLIGHT_PARALLEL:-/home/resources/x64/bin/parallel}"
SBL="${PREFLIGHT_SBL:-/home/resources/x64/bin/sbl}"

req_missing=""; opt_absent=""; n_req=0

# check NAME REQ|OPT PROOF-COMMAND  -- the command must exit 0 and print the tool's version or proof as its LAST line.
check() {
    local name=$1 kind=$2 cmd=$3 out rc last
    out=$(timeout -k 5 60 bash -c "$cmd" 2>&1 < /dev/null); rc=$?
    last=$(printf '%s\n' "$out" | grep -v '^$' | tail -1)
    if [ "$rc" -eq 0 ] && [ -n "$last" ]; then
        printf 'TOOL %-12s %s ok      %s\n' "$name" "$kind" "$last"
        [ "$kind" = REQ ] && n_req=$((n_req + 1))
        return 0
    fi
    [ -n "$last" ] || last="no output (rc=$rc): the tool is not at its declared path or does not run"
    if [ "$kind" = REQ ]; then
        printf 'TOOL %-12s %s MISSING rc=%s %s\n' "$name" "$kind" "$rc" "$(printf '%s' "$last" | cut -c1-120)"
        req_missing="$req_missing $name"
    else
        printf 'TOOL %-12s %s absent  rc=%s %s\n' "$name" "$kind" "$rc" "$(printf '%s' "$last" | cut -c1-120)"
        opt_absent="$opt_absent $name"
    fi
    return 1
}

# The make on PATH against the make the jobserver joins: a note, never a failure.
pathmake=$(make --version 2>/dev/null | head -1)
if printf '%s\n' "$pathmake" | grep -qE 'Make 4\.([4-9]|[1-9][0-9])'; then
    printf 'TOOL %-12s NOTE  make on PATH is 4.4+ (%s)\n' make-path "$pathmake"
else
    printf 'TOOL %-12s NOTE  make on PATH is not 4.4 (%s); the jobserver joins %s\n' make-path "${pathmake:-absent}" "$MAKE44"
fi

check make REQ "[ -x '$MAKE44' ] && v=\$('$MAKE44' --version | head -1) && printf '%s\n' \"\$v\" | grep -qE 'Make 4\.([4-9]|[1-9][0-9])' && printf '%s (jobserver join)\n' \"\$v\""
check gcc REQ 'printf "int main(void){return 0;}\n" > "$T/g.c" && gcc -O0 -o "$T/g" "$T/g.c" && "$T/g" && gcc --version | head -1'
check as REQ 'printf ".globl main\nmain: ret\n" > "$T/a.s" && as -o "$T/a.o" "$T/a.s" && as --version | head -1'
check ld REQ 'ld -o "$T/a" -e main "$T/a.o" && test -x "$T/a" && ld --version | head -1'
check nasm REQ 'printf "bits 64\nnop\n" > "$T/n.asm" && nasm -f elf64 -o "$T/n.o" "$T/n.asm" && test -s "$T/n.o" && nasm -v | head -1'
check m4 REQ 'printf "define(X,ok)X\n" | m4 | grep -qx ok && m4 --version | head -1'
check bison REQ 'printf "%%%%\nu: ;\n" > "$T/g.y" && env -u BISON_PKGDATADIR bison -d -o "$T/g.c" "$T/g.y" && test -s "$T/g.c" && bison --version | head -1'
check flex REQ 'printf "%%%%\n.\n%%%%\n" > "$T/l.l" && flex -o "$T/l.c" "$T/l.l" && test -s "$T/l.c" && flex -V'
check gdb REQ 'gdb --batch -ex "print 1+1" /bin/true 2>/dev/null | grep -qF "\$1 = 2" && gdb --version | head -1'
check python3 REQ 'python3 -c "import sys; assert sys.version_info >= (3, 8); print(sys.version.split()[0])" && python3 --version'
check git REQ 'git --version'
check parallel REQ "[ -x '$PARALLEL' ] && printf '1\n' | '$PARALLEL' --will-cite -j1 echo hi{} | grep -qx hi1 && '$PARALLEL' --version | head -1"
check sbl REQ "[ -x '$SBL' ] && printf '        OUTPUT = \"ok\"\nEND\n' > \"\$T/s.sno\" && timeout -k 5 20 '$SBL' -bf \"\$T/s.sno\" | grep -qx ok && echo 'SPITBOL oracle sbl -bf ran a one-line program: ok'"

check libgmp OPT 'test -f /usr/include/gmp.h && echo "gmp.h present" || { echo "no /usr/include/gmp.h (declared by install_system_packages.sh; no build here reads it)"; false; }'
check wabt OPT 'printf "(module)\n" > "$T/m.wat" && wat2wasm "$T/m.wat" -o "$T/m.wasm" && test -s "$T/m.wasm" && wat2wasm --version | head -1'
check gawk OPT 'printf "x y\n" | gawk "{print \$2}" | grep -qx y && gawk --version | head -1'

n_opt=${opt_absent# }
if [ -n "$req_missing" ]; then
    echo "TOOLCHAIN MISSING required=${req_missing# } optional_absent=${n_opt:-none}"
    exit 1
fi
echo "TOOLCHAIN OK required=$n_req optional_absent=${n_opt:-none}"
exit 0
