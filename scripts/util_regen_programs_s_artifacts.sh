#!/usr/bin/env bash
# util_regen_programs_s_artifacts.sh — regenerate the mode-4 (--compile) x86 .s artifact
# for every program under corpus/{icon,prolog,rebus}, side-by-side with its
# source, committing ONLY artifacts whose bytes changed.  (snobol4 is covered
# by util_regen_demo_s_artifacts.sh + util_regen_feature_s_artifacts.sh — not swept here.)
#
# WHY (s21x provenance census): icon (276 non-empty .s) and prolog (134)
# carried CURRENT operand spellings but a pre-formatting-change header — one or more
# emitter generations stale, and no script existed to refresh them (benchmarks had
# update_icon_bench_asm.sh; programs had nothing).  Same PHILOSOPHY as the siblings:
# the .s is the HONEST CURRENT compiler output, not a golden; deterministic compiler
# => idempotent, no commit when unchanged.  Zero-byte committed .s (19 icon, 19 prolog:
# past emit-fails) are refreshed when the compiler now succeeds, left when it still fails.
# Usage: util_regen_programs_s_artifacts.sh [RUNG-LABEL] [SUBTREE ...]
#        SUBTREE defaults to "icon prolog rebus".
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
CORPUS="${CORPUS:-$S4E/corpus}"
RUNG="${1:-regen}"; shift 2>/dev/null || true
TREES="${*:-icon prolog rebus}"

[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE  scrip not built: $SCRIP"; exit 2; }
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT   # PER-INVOCATION scratch: the old fixed /tmp/prog_regen.* was shared by every seat root, so two concurrent regens overwrote each other's asm mid-compare (s169 seat2 FINDING §7.5)

emitted=0; changed=0; same=0; efail=0; afail=0
for tree in $TREES; do
    D="$CORPUS/$tree"; [ -d "$D" ] || continue
    case "$tree" in icon) EXT=icn;; prolog) EXT=pl;; rebus) EXT=reb;; *) echo "  SKIP unknown tree $tree"; continue;; esac
    for src in $(find "$D" -name "*.$EXT" | sort); do
        s="${src%.*}.s"; t="$TMPD/prog_regen.s"
        [ -z "$ALL" ] && [ ! -f "$s" ] && continue   # default: refresh EXISTING artifacts only (swi_tests etc. have no .s and are runtime suites, not artifact carriers); ALL=1 to mint new ones
        if timeout -k 5 30 "$SCRIP" --compile "$src" > "$t" 2>/dev/null < /dev/null && [ -s "$t" ]; then
            if gcc -c "$t" -o "$TMPD/prog_regen.o" 2>"$TMPD/prog_regen.aserr"; then
                emitted=$((emitted+1))
                if [ -f "$s" ] && cmp -s "$t" "$s"; then same=$((same+1)); else cp "$t" "$s"; changed=$((changed+1)); fi
            else
                afail=$((afail+1)); echo "  AS-FAIL  ${s#$CORPUS/} : $(head -1 "$TMPD/prog_regen.aserr")"
            fi
        else
            efail=$((efail+1)); echo "  EMIT-FAIL ${s#$CORPUS/} (empty/crash; NOT updated)"
        fi
    done
done
echo "--- programs .s ($TREES): emitted=$emitted changed=$changed unchanged=$same emit-fail=$efail as-fail=$afail ---"

cd "$CORPUS"
for tree in $TREES; do git add "$tree" 2>/dev/null || true; done
if git diff --cached --quiet 2>/dev/null; then
    echo "  No changes — programs .s artifacts already current."
else
    git -c user.name="LCherryholmes" -c user.email="lcherryh@yahoo.com" \
        commit -q -m "programs x86 .s artifacts ($TREES): $RUNG"
    echo "  Committed:"; git show --stat --oneline HEAD | tail -2
fi
