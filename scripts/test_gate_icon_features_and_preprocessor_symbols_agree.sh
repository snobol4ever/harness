#!/usr/bin/env bash
# test_gate_icon_features_and_preprocessor_symbols_agree.sh -- ICON'S FEATURE LIST AND ITS PREPROCESSOR
# SYMBOL TABLE ARE ONE FACT IN TWO FILES, AND UNTIL THIS GATE NOTHING ENFORCED IT.
#
# feats[] in src/runtime/keywords.c is what &features generates.  pre[] in src/parsers/icon/icon_lex.c is
# the set of predefined preprocessor symbols $ifdef sees.  Icon's own test suite CROSS-CHECKS THEM: every
# precheck(_JAVA, "Java") asserts the symbol is defined IFF the feature is present, so the two arrays are
# a single fact spelled in two layers -- runtime and parser -- with no build-time relationship at all.
#
# ⛔ WHY IT EXISTS (cfo 2026-09-08, row icon-feature-list-and-preprocessor-symbol-table-must-agree-and-
# nothing-enforces-it, ceo approved).  Curing the dialect row meant editing feats[] -- dropping "Java",
# adding "keyboard functions".  pre[] was NOT edited, because nothing said it had to be, and SCRIP then
# CONTRADICTED ITSELF OUT LOUD: "error: unexpected predefined symbol for Java" and "error: no predefined
# symbol for keyboard functions".  The ONLY thing that caught it was procedure_record_limit_replace_1, one
# entry buried in an 858-entry board, and it was found by stashing the change and rebuilding to get a
# baseline -- roughly three minutes and a full rebuild to learn what this gate says in a tenth of a second.
#
# ⛔ THE DIRECTION IS ASYMMETRIC, AND THAT IS MEASURED, NOT ASSUMED.  A symbol with no feature is always
# wrong.  A FEATURE WITH NO SYMBOL IS NORMAL: Arizona icont itself reports "environment variables" in
# &features and defines NO _ENVIRONMENT_VARIABLES -- verified live against /home/resources/icon-master on
# 2026-09-08 with a $ifdef probe, alongside _KEYBOARD_FUNCTIONS and _PIPES which it DOES define.  So this
# gate refuses a symbol that names no feature, and merely REPORTS features carrying no symbol.  A gate
# broader than its rule gets disabled by the first person it blocks for a good reason.
#
# Hermetic, no build, ~0.1s.  ICON_FEATS_SRC / ICON_PRE_SRC override either source path so a caller can
# point it at a mutated scratch copy and prove the comparison is real rather than vacuous.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_gate.sh"
GATE_NAME=icon_features_and_preprocessor_symbols_agree
FEATS_SRC="${ICON_FEATS_SRC:-$HERE/../../SCRIP/src/runtime/keywords.c}"
PRE_SRC="${ICON_PRE_SRC:-$HERE/../../SCRIP/src/tools/ipp.icn}"   # the IPP pre-step, JCON's preprocessor in Icon (Lon 2026-09-30, CEO-1366); icon_lex.c carries a twin list until its pass is deleted
PRE_SRC2="${ICON_PRE_SRC2:-$HERE/../../SCRIP/src/parsers/icon/icon_lex.c}"
[ -f "$FEATS_SRC" ] || { echo "GATE REFUSE(2) [$GATE_NAME]: no feature source at $FEATS_SRC -- cannot measure"; exit 2; }
[ -f "$PRE_SRC" ]   || { echo "GATE REFUSE(2) [$GATE_NAME]: no preprocessor source at $PRE_SRC -- cannot measure"; exit 2; }
if [ -f "$PRE_SRC2" ] && grep -q 'pre\[\] = {' "$PRE_SRC2"; then a="$(tr -d '\n' < "$PRE_SRC" | grep -o 'every t\[!\[[^]]*\]\]' | grep -o '"[^"]*"' | tr -d '\n')"; b="$(grep -o 'pre\[\] = {[^}]*}' "$PRE_SRC2" | grep -o '"[^"]*"' | tr -d '\n')"; [ "$a" = "$b" ] || { echo "GATE FAIL(1) [$GATE_NAME]: the pre-step and the lexer twin disagree on the predefined symbols -- $PRE_SRC vs $PRE_SRC2"; exit 1; }; fi
out="$(python3 - "$FEATS_SRC" "$PRE_SRC" <<'PY'
import re, sys
feats_src, pre_src = sys.argv[1], sys.argv[2]
def arr(path, decl):
    txt = open(path, encoding="utf-8", errors="replace").read()
    if path.endswith(".icn"):
        m = re.search(r"every t\[!\[(.*?)\]\] := \"1\"", txt, re.S)
    else:
        m = re.search(re.escape(decl) + r"[^{]*\{(.*?)\}", txt, re.S)
    if not m: return None
    return re.findall(r'"([^"]*)"', m.group(1))
feats = arr(feats_src, "feats[]")
pre   = arr(pre_src,   "pre[]")
if feats is None: print("REFUSE|no feats[] initialiser found in %s" % feats_src); sys.exit(0)
if pre   is None: print("REFUSE|no pre[] initialiser found in %s"   % pre_src);   sys.exit(0)
def norm(s): return re.sub(r"[^A-Z0-9]+", "_", s.upper()).strip("_")
fset = {norm(f): f for f in feats}
orphans, matched = [], []
VERSION_SYMBOLS = {"_V9"}   # Arizona h/features.h: Feature(1, "_V9", 0) -- the version symbol, defined unconditionally, names no feature
for s in pre:
    if s in VERSION_SYMBOLS: continue
    key = norm(s.lstrip("_"))
    (matched if key in fset else orphans).append(s)
missing = [f for k, f in fset.items() if k not in {norm(s.lstrip("_")) for s in pre}]
print("COUNT|%d|%d" % (len(feats), len(pre)))
for s in orphans: print("ORPHAN|%s" % s)
for f in missing: print("NOSYM|%s" % f)
PY
)"
case "$out" in
    REFUSE*) echo "GATE REFUSE(2) [$GATE_NAME]: ${out#REFUSE|} -- the arrays were renamed or reshaped, so this gate is grading nothing; re-read it before trusting a green"; exit 2 ;;
esac
nf="$(printf '%s\n' "$out" | awk -F'|' '/^COUNT/{print $2}')"
np="$(printf '%s\n' "$out" | awk -F'|' '/^COUNT/{print $3}')"
orphans="$(printf '%s\n' "$out" | awk -F'|' '/^ORPHAN/{print $2}')"
nosym="$(printf '%s\n' "$out" | awk -F'|' '/^NOSYM/{print $2}')"
[ -n "$nosym" ] && { echo "  (reported, not a failure -- Arizona does this too, e.g. environment variables) feature(s) with no preprocessor symbol:"; printf '%s\n' "$nosym" | sed 's/^/      /'; }
bad=0
if [ -n "$orphans" ]; then
    bad="$(printf '%s\n' "$orphans" | grep -c .)"
    echo "  ⛔ preprocessor symbol(s) naming NO feature -- \$ifdef would define a symbol &features denies:"
    printf '%s\n' "$orphans" | sed 's/^/      /'
    echo "  Cure: add the feature to feats[] in src/runtime/keywords.c, or drop the symbol from the table in src/tools/ipp.icn (and its twin pre[] in src/parsers/icon/icon_lex.c while that pass exists)."
    echo "  Icon's own suite cross-checks these (precheck(_JAVA, \"Java\")), so a disagreement surfaces as a corpus red far from its cause."
fi
GATE_EXAMINED="$np symbol(s) against $nf feature(s)"
gate_verdict "$bad" "preprocessor symbol(s) that name no feature"
