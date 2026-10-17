#!/usr/bin/env bash
# test_gate_runtime_isolation.sh — runtime->frontend boundary firewall.
#
# Companion gate to test_gate_lower_isolation.sh.  Where that gate protects
# the parse->lower edge, this one protects the parse->runtime edge.
#
# Invariant: src/runtime/ must not reach into src/parsers/ except through
# a small, explicit allowlist of headers that contain shared infrastructure
# currently misfiled under parser/.  Every allowlist entry is a known
# misfile with an owning relocation goal; the allowlist is a ratchet, not
# a permanent license.
#
# Rationale: a runtime that depends on a frontend is architecturally
# backward — it implies the executor cannot run without the parser linked
# in.  The endgame is that the runtime depends only on the AST + shared
# types (descr, etc.) and the frontends are pluggable producers of AST.
#
# A future commit may shrink the allowlist (by moving a header out of
# parser/) but must never grow it.
#
# Run: bash ../harness/scripts/test_gate_runtime_isolation.sh
set -euo pipefail
# ⛔ THIS GATE MEASURED NOTHING FROM THE src/parser -> src/parsers RENAME UNTIL 2026-10-08 (the cfo found it, the coo cured it):
# its scan read include.*parser/, which no longer matched, and the count `grep | wc -l` failed under pipefail, so set -e ended
# the script at rc 1 with no output. It now reads parsers?/, normalizes every include to parsers/..., and a scan with no match
# counts zero instead of ending the run. The allowlist entries were renamed to the parsers/ spelling and nothing else.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"

ALLOW=(
    # scrip_cc.h: defines STMT_t, CODE_t, LANG_* enums, tree_t helper macros.
    #   Universal AST/language infrastructure misfiled under parser/snobol4/
    #   for historical reasons.  Included by 54 files tree-wide.
    #   Owning relocation goal: move to src/include/scrip_lang.h.
    "parsers/snobol4/scrip_cc.h"

    # The four Prolog "runtime-ish" headers below describe Prolog Term
    # representation, atom interning, unification scaffolding, broker
    # dispatch, and built-in predicate registry.  Their primary clients
    # are src/runtime/interp/pl_runtime.{c,h} (Prolog execution engine)
    # but they currently live under src/parsers/prolog/ alongside the
    # Prolog lexer and parser.  This reflects historical bundling.
    # Owning relocation goal: split src/parsers/prolog/ into
    # src/parsers/prolog/ (lex/parse only) and src/runtime/interp/prolog/
    # (Term, atoms, unify, broker, builtins).
    "parsers/prolog/term.h"
    "parsers/prolog/prolog_runtime.h"
    "parsers/prolog/prolog_atom.h"
    "parsers/prolog/prolog_driver.h"
    "parsers/prolog/prolog_builtin.h"
    "parsers/prolog/pl_broker.h"

    # raku_re.h: Raku regex runtime — match/capture/grep operations.
    #   Pure runtime API misfiled under parser/raku/.
    #   Owning relocation goal: relocate to src/runtime/interp/raku/.
    "parsers/raku/raku_re.h"
)

violations=0
new_violations=()

while IFS= read -r line; do
    [ -z "$line" ] && continue
    file="${line%%:*}"
    rest="${line#*:}"
    lineno="${rest%%:*}"
    inc_path=$(echo "$rest" | sed -E 's/.*include[[:space:]]+["<]([^">]+)[">].*/\1/')
    normalized=$(echo "$inc_path" | sed -E 's|^(\.\./)+||')
    normalized="${normalized#src/}"
    if [[ "$normalized" != parsers/* ]]; then
        continue
    fi
    ok=0
    for allowed in "${ALLOW[@]}"; do
        if [ "$normalized" = "$allowed" ]; then
            ok=1
            break
        fi
    done
    if [ $ok -eq 0 ]; then
        new_violations+=("$file:$lineno: $normalized")
        violations=$((violations + 1))
    fi
done < <(grep -rnE "include.*parsers?/" src/runtime/ 2>/dev/null | grep -v "^Binary file" || true)

present=$( { grep -rnE "include.*parsers?/" src/runtime/ 2>/dev/null || true; } | { grep -v "^Binary file" || true; } | wc -l)

if [ $violations -gt 0 ]; then
    echo "FAIL runtime->frontend firewall: $violations new include(s) not on allowlist:"
    for v in "${new_violations[@]}"; do echo "  $v"; done
    echo ""
    echo "If the new include is legitimate, add the header to the ALLOW list in"
    echo "this script with a comment explaining why and the relocation plan."
    echo "Prefer moving the header out of src/parsers/ instead."
    exit 1
fi

echo "OK  runtime->frontend firewall: $present include(s) under src/runtime/ into src/parsers/, all allowlisted"
echo "    (allowlist size: ${#ALLOW[@]} entries — see top of script for relocation goals)"
