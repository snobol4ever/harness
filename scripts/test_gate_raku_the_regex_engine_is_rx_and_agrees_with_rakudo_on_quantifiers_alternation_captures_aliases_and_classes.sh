#!/usr/bin/env bash
# test_gate_raku_the_regex_engine_is_rx_and_agrees_with_rakudo_on_quantifiers_alternation_captures_aliases_and_classes.sh -- THE RAKU REGEX ENGINE IS rx.c, A BACKTRACKING MATCHER OVER RAKU'S OWN SYNTAX
# (row raku-every-suite-to-100-under-nonet-ceo-1266; the biggest measured class of the Roast refusals: 5 percent of a 120-file sample died on `re: compile error`, S05 is 98 files).
#
# THE DEFECT: re.c was a byte-wise Pike NFA behind a text translator (regex_to_engine) and a textual grammar inliner (gram_expand, depth 16). It had no ** n..m, no lazy + or *, no lookaround, no <{ }>, no
# aliases, no nested captures, no UTF-8, no rule recursion; `"foo123" ~~ /(\w+?)(\d+)/` died with `re: compile error: unexpected meta`, `$<x>=(\d+)` with `bad named capture`, and `token word { \w+ }`
# was shadowed by the built-in class of the same name.
# THE CURE: src/runtime/rx.c parses the pattern text a Raku program wrote (the parser hands it over unchanged) to a node tree and matches it by backtracking with continuations; captures are a post-order
# event log that rk_rx_to_match flattens for the old g_match readers and stores whole in the Match block, so rk_match_obj_in builds nested typed Match objects. RxEnv.rule resolves grammar rules at match time.
#
# THE WITNESSES: six master entries (corpus/tests/raku/ALL.raku, rung 09, ladder__rung09_regex_engine_*_agree_with_rakudo), 273 matches whose expected lines were cut by Rakudo (/usr/bin/raku, never from
# SCRIP): basics, quantifiers (greedy / lazy / ** / % / %%), captures (positional, named, aliases $<x>= $0= <x=rule>, nested, quantified, backrefs), classes (<[ ]> algebra, \d \w \s \h \v \n, hex escapes).
# Each is graded in m3 and m4, then again under SCRIP_GC_STRESS 1 3 5 (the event log and the Match tree are built inside one runtime call). Two inline witnesses: a user rule named like a built-in class
# (token word { \w+ } is called by <word>) and Grammar.parse demanding the whole subject.
# FAILED ONCE, measured on SCRIP 5541ba16a before the cure: 6 of 6 master witnesses differ from Rakudo in m3, and both inline witnesses print Nil.
#
# EXIT: 0 every witness-mode pair matches; 1 a mismatch or a crash; 2 REFUSED (stale binary, no gcc, no corpus).
# Usage: bash ../harness/scripts/test_gate_raku_the_regex_engine_is_rx_and_agrees_with_rakudo_on_quantifiers_alternation_captures_aliases_and_classes.sh   (~40s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_regex_engine_is_rx_and_agrees_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
MASTER="$ROOT/../corpus/tests/raku/ALL.raku"; REFS="$ROOT/../corpus/tests/raku/ALL.ref"
[ -f "$MASTER" ] && [ -f "$REFS" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: no master at $MASTER"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
fails=0; GATE_EXAMINED=0
[ ! -e "$ROOT/src/runtime/re.c" ] && grep -q 'runtime/rx.c' "$ROOT/Makefile" || { echo "  FAIL the old engine re.c is still in the tree or rx.c is not in the Makefile"; fails=$((fails + 1)); }
GATE_EXAMINED=$((GATE_EXAMINED + 1))
python3 - "$MASTER" "$REFS" "$W" <<'PY' || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: cannot extract the master entries"; exit 2; }
import re, sys
def split(path):
    d = {}; cur = None; buf = []
    for line in open(path, encoding='utf-8', errors='surrogateescape'):
        m = re.match(r'^#-+ \d+ (\S+)(?: .*)?$', line)
        if m:
            if cur: d[cur] = ''.join(buf)
            cur = m.group(1); buf = []
        else: buf.append(line)
    if cur: d[cur] = ''.join(buf)
    return d
src, ref = split(sys.argv[1]), split(sys.argv[2])
for g in ('basics_1', 'basics_2', 'basics_3', 'quantifiers_1', 'captures_1', 'classes_1'):
    n = 'ladder__rung09_regex_engine_%s_agree_with_rakudo' % g
    open('%s/%s.raku' % (sys.argv[3], g), 'w', encoding='utf-8', errors='surrogateescape').write(src[n])
    open('%s/%s.ref' % (sys.argv[3], g), 'w', encoding='utf-8', errors='surrogateescape').write(ref[n])
PY
cat > "$W/rule.raku" <<'RK'
grammar G { token word { \w+ }; token TOP { <word> } }
say G.parse("hello");
say G.parse("hello world");
grammar H { token word { \w+ }; rule TOP { <word> } }
say H.parse("hello");
RK
cat > "$W/rule.ref" <<'RK'
｢hello｣
 word => ｢hello｣
Nil
｢hello｣
 word => ｢hello｣
RK
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-13s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-13s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-13s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-13s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in basics_1 basics_2 basics_3 quantifiers_1 captures_1 classes_1 rule; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in captures_1 quantifiers_1 rule; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: the regex engine disagrees with Rakudo"
