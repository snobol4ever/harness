#!/usr/bin/env bash
# install_system_packages.sh — install system packages needed for snobol4ever development
# Idempotent. Safe to run multiple times.
# Usage: bash ../harness/scripts/install_system_packages.sh
set -euo pipefail
PKGS="build-essential libgmp-dev m4 nasm wabt bison flex gawk"
# NOTE: the ONE unified GC (gc_heap.c) needs no external library (GC-U-4, s67).
# gdb is MANDATORY TOOLING, not a convenience: RULES.md MONITOR-FIRST step (2) IS "gdb breakpoint at the
# bracketed C site with a spin/ignore counter". Without it the prescribed hunt has no middle rung and every
# runtime-half defect ends in a handoff instead of a fix. Installed --no-install-recommends DELIBERATELY:
# gdb Recommends libc-dbg, which breakpoint/register/backtrace work does NOT need, and which is the exact
# package that 404s against a stale index. See the apt-get update note below.
DBG_PKGS="gdb"
# bison/flex on this box are a durable ~/.local install (extracted from their .deb, never dpkg -i'd --
# see .github/FINDING-2026-08-30-hq_C-bison-on-path-could-not-generate-and-every-parser-regen-silently-did-nothing.md),
# so dpkg -s never sees them and this script would apt-get install them, then abort, on every run (no
# root, no passwordless sudo). Prove capability instead of trusting dpkg's blind spot -- same rule the
# gdb liveness check below already applies to itself.
TOOLING_OK=""
if command -v bison >/dev/null 2>&1 && command -v flex >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    if printf '%%%%\nu: ;\n' > "$tmp/g.y" && env -u BISON_PKGDATADIR bison -d -o "$tmp/g.c" "$tmp/g.y" >/dev/null 2>&1 && [ -f "$tmp/g.c" ]; then
        TOOLING_OK="bison flex"
    fi
    rm -rf "$tmp"
fi
MISSING=""
for p in $PKGS $DBG_PKGS; do
    case " $TOOLING_OK " in *" $p "*) continue ;; esac
    dpkg -s "$p" &>/dev/null || MISSING="$MISSING $p"
done
if [ -n "$MISSING" ]; then
    # ⛔ apt-get update FIRST, ALWAYS, BEFORE ANY INSTALL. A container's apt index is baked at image-build
    # time and goes stale; a stale index names package versions the mirror has already superseded and
    # DELETED, so the install 404s on something that is not actually broken. This one missing line cost
    # GOAL-RBP-EARN sessions s33-s39: every seat that ran `apt-get install gdb` hit a 404 on libc6-dbg,
    # concluded gdb was unavailable in this container, and wrote that into the goal file as a fact that
    # later seats inherited. libc6-dbg is not a dependency of gdb (it is a Recommends). `apt-get update`
    # plus --no-install-recommends resolves it in seconds. Do not delete this call to save time.
    apt-get update 2>&1 | tail -2
    for p in $MISSING; do
        case " $DBG_PKGS " in
            *" $p "*) apt-get install -y --no-install-recommends "$p" 2>&1 | tail -2 ;;
            *)        apt-get install -y "$p"                        2>&1 | tail -2 ;;
        esac
    done
    echo "OK  installed:$MISSING"
else
    echo "SKIP all packages already installed"
fi
# Verify the tooling the RULES-prescribed hunt depends on actually runs, rather than assuming the install
# implies a working binary (SYMBOL PRESENCE IS NOT LIVENESS, applied to the toolchain itself).
command -v gdb >/dev/null && echo "OK  gdb $(gdb --version | head -1 | awk '{print $NF}') present" \
                          || echo "WARN gdb MISSING — RULES.md MONITOR-FIRST step (2) is unavailable; say so in your cursor"
