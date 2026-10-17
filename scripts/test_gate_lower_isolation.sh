#!/usr/bin/env bash
# test_gate_lower_isolation.sh — parse->lower boundary firewall.
#
# Invariant: src/lower/ must not reach into src/parsers/ except through a
# small, explicit allowlist of headers that contain shared infrastructure
# currently misfiled under parser/.  Every allowlist entry is a known
# misfile with an owning relocation goal; the allowlist is a ratchet, not
# a permanent license.
#
# A future commit may shrink the allowlist (by moving a header out of
# parser/) but must never grow it.  CI will reject any new include
# under src/lower/ that names src/parsers/.
#
# Run: bash ../harness/scripts/test_gate_lower_isolation.sh
set -euo pipefail
# ⛔ THIS GATE MEASURED NOTHING FROM THE src/parser -> src/parsers RENAME UNTIL 2026-10-08 (the cfo found it, the coo cured it):
# its scan read include.*parser/, which no longer matched, and the count `grep | wc -l` failed under pipefail, so set -e ended
# the script at rc 1 with no output. It now reads parsers?/, normalizes every include to parsers/..., and a scan with no match
# counts zero instead of ending the run. The allowlist entries were renamed to the parsers/ spelling and nothing else.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"

# Allowlist: exact include strings currently present under src/lower/.
# Each entry includes a tag describing why it exists and what would
# need to happen to remove it.
#
# Format: one substring per line, matched literally against the
# "include "parser/foo.h"" portion (after the path-prefix is stripped).
ALLOW=(
    # scrip_cc.h: defines STMT_t, CODE_t, LANG_* enums, tree_t helper macros.
    #   This is universal AST/language infrastructure misfiled under
    #   parser/snobol4/ for historical reasons (snobol4 was the first
    #   frontend).  54 files include it tree-wide.
    #   Owning relocation goal: move scrip_cc.h to src/include/scrip_lang.h.
    "parsers/snobol4/scrip_cc.h"

    # icon_lex.h: defines IcnTkKind enum (TK_AUG*, TK_PLUS, TK_MINUS, ...).
    #   lower.c reads these enum values when lowering Icon TT_AUGOP nodes
    #   to SM/BB.  The enum is a lex artifact but its values are used as
    #   stable opcode tags downstream.
    #   Owning relocation goal: extract IcnTkKind to src/include/icon_tk.h.
    "parsers/icon/icon_lex.h"

    # icon_gen.h: relocated to src/runtime/interp/ on 2026-05-20.  Allowlist
    #   entry removed.  The header is pure Icon Byrd-box generator runtime
    #   state (icn_to_state_t, icn_find_state_t, icn_bb_* function decls);
    #   it never belonged under parser/icon/ — no .c file under
    #   src/parsers/ ever included it.

    # raku_driver.h: declares the raku runtime API (raku_match, raku_compile,
    #   raku_grep, raku_capture, raku_meth_register, raku_die, raku_exception,
    #   raku_print_fh, ~20 functions).  These are runtime/builtin functions
    #   that happen to live under parser/raku/ because they were authored
    #   alongside the Raku parser.
    #   Owning relocation goal: split raku_driver.h into raku_parse.h
    #   (frontend-only) and raku_runtime.h (relocated to src/runtime/).
    "parsers/raku/raku_driver.h"

    # term.h, prolog_runtime.h, prolog_atom.h: Prolog runtime data
    #   structures (Term, atom table, unification scaffolding).  Used by
    #   ir_exec.c for Prolog choice-point execution.  Belong under
    #   src/runtime/interp/ alongside pl_runtime.h.
    #   Owning relocation goal: relocate to src/runtime/interp/.
    "parsers/prolog/term.h"
    "parsers/prolog/prolog_runtime.h"
    "parsers/prolog/prolog_atom.h"
)

violations=0
new_violations=()

# Find every include directive under src/lower/ that points into src/parsers/.
while IFS= read -r line; do
    [ -z "$line" ] && continue
    # line is like: src/lower/lower.c:15:#include "../../parser/icon/icon_lex.h"
    file="${line%%:*}"
    rest="${line#*:}"
    lineno="${rest%%:*}"
    # Extract the include path (between quotes or angle brackets).
    inc_path=$(echo "$rest" | sed -E 's/.*include[[:space:]]+["<]([^">]+)[">].*/\1/')
    # Normalize: strip leading ../ chains, keep "parser/..." suffix.
    normalized=$(echo "$inc_path" | sed -E 's|^(\.\./)+||')
    normalized="${normalized#src/}"
    if [[ "$normalized" != parsers/* ]]; then
        continue
    fi

    # Is it allowed?
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
done < <(grep -rnE "include.*parsers?/" src/lower/ 2>/dev/null || true)

# Count expected (allowlisted) entries actually present.
present=$( { grep -rnE "include.*parsers?/" src/lower/ 2>/dev/null || true; } | wc -l)

if [ $violations -gt 0 ]; then
    echo "FAIL parse->lower firewall: $violations new include(s) into src/parsers/ not on allowlist:"
    for v in "${new_violations[@]}"; do echo "  $v"; done
    echo ""
    echo "If the new include is legitimate, add the header to the ALLOW list in"
    echo "this script with a comment explaining why and the relocation plan."
    echo "Prefer moving the header out of src/parsers/ instead."
    exit 1
fi

echo "OK  parse->lower firewall: $present include(s) under src/lower/ into src/parsers/, all allowlisted"
echo "    (allowlist size: ${#ALLOW[@]} entries — see top of script for relocation goals)"
