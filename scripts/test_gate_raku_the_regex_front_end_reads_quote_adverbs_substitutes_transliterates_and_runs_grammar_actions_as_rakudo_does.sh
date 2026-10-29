#!/usr/bin/env bash
# test_gate_raku_the_regex_front_end_reads_quote_adverbs_substitutes_transliterates_and_runs_grammar_actions_as_rakudo_does.sh -- THE REGEX FRONT END: m:i m:g m:x m:nth m:ov m:c m:p, $var @var <$var> <@var>
# interpolation, s/// S/// with a double-quoted or closure replacement, tr/// TR/// with :c :d :s, lexical and nested grammars and `my regex`, proto token + <sym>, actions with make / .made / .ast,
# Match.caps / .chunks / .Int / .put, <( )> markers, && conjunction, < a b > word lists, **^N (row raku-every-suite-to-100-under-nonet-ceo-1266; follows the rx.c landing 2c4fb2e59).
#
# THE DEFECT, measured over Roast S05 (98 files, run one by one): after rx.c replaced the Pike NFA, 221 of 2138 regex literals the files contain still refused and 10 files never started.
# The front end ignored every quote adverb (`m:i/abc/` printed False, `TR/eox/EOX/` was a string), interpolated nothing, had no s/// or tr///, did not register a grammar below the top level or a
# `my regex`, had no proto candidates, `make`, `.made`, `.caps`, `.chunks`, and `@$/` was an unassigned variable.
# THE CURE: rk_tree.c rk_rq_parse reads WORD ADVERBS DELIM BODY DELIM [BODY2 DELIM] of every regex-like quote (m rx ms mm s S ss Ss tr TR and bare //): regex-level adverbs become the pattern's leading
# `:i :s :r :m ` text, match-level ones (:g :ov :ex :c :p :x :nth :1st) a __rk_rxopts argument list to re_matchx / re_testx; interpolation builds the pattern as a concatenation (__rk_rxq quotes a value,
# __rk_rxalt makes an alternation, __rk_rxsrc / __rk_rxsrcalt compile a string as a regex); s/// is re_subst (the replacement is a string or an anonymous block run per match, with $/ set), tr is
# re_trans; nested grammars hoist like nested classes, `my regex` registers as ::name; `proto token` synthesizes the candidate alternation and `<sym>` the literal; Grammar.parse / subparse take
# :actions and apply it post-order (rk_apply_actions, state in the rk_cbh hold chain); a sub or method with a `$/` parameter reads captures from that parameter.
#
# THE WITNESSES: six master entries, rung 09 (ladder__rung09_regex_*), expected output cut by Rakudo: quote adverbs and interpolation, substitution and transliteration, grammars (nested, lexical,
# proto, actions), Match methods, engine batch 2 (&&, <( )>, word lists, **^N, @<x>= aliases, class assertions), sigspace. Each in m3 and m4, then under SCRIP_GC_STRESS 1 3 5 (actions and a
# per-match replacement block call back into emitted code).
# FAILED ONCE, measured on SCRIP 2c4fb2e59 before the cure: 6 of 6 differ from Rakudo in m3.
#
# EXIT: 0 every witness-mode pair matches; 1 a mismatch or a crash; 2 REFUSED (stale binary, no gcc, no corpus).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_regex_front_end"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
MASTER="$ROOT/../corpus/tests/raku/ALL.raku"; REFS="$ROOT/../corpus/tests/raku/ALL.ref"
[ -f "$MASTER" ] && [ -f "$REFS" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: no master at $MASTER"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
fails=0; GATE_EXAMINED=0
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
for g, full in (('adverbs', 'quote_adverbs_and_interpolation'), ('subst', 'substitution_and_transliteration'), ('grammars', 'grammars_protos_actions_and_lexical_regexes'), ('matchapi', 'match_methods'), ('batch2', 'engine_batch2'), ('sigspace', 'engine_sigspace')):
    n = 'ladder__rung09_regex_%s_agree_with_rakudo' % full
    open('%s/%s.raku' % (sys.argv[3], g), 'w', encoding='utf-8', errors='surrogateescape').write(src[n])
    open('%s/%s.ref' % (sys.argv[3], g), 'w', encoding='utf-8', errors='surrogateescape').write(ref[n])
PY
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile --out="$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-13s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-13s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-13s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-13s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in adverbs subst grammars matchapi batch2 sigspace; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in adverbs subst grammars; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: the regex front end disagrees with Rakudo"
