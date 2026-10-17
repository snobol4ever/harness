#!/usr/bin/env bash
# test_gate_snc_two_nreturn_functions_link_in_m4.sh -- TWO SNOCONE FUNCTIONS THAT BOTH nreturn LINK IN m4 AND ANSWER THE SAME AS m3.
# ⛔ THE MEASURED DEFECT (hq_snocone ask, cfo cure, 2026-09-16, row snocone-two-functions-that-both-nreturn-emit-duplicate-...): the
# emitter's floater labels RETURN/FRETURN/NRETURN were cached in g_flt_lbl and named literally, and the TEXT medium never resets the
# label pool between graphs, so every Snocone function graph emitted into one .s defined the same NRETURN: and RETURN: symbols again
# ("symbol NRETURN is already defined"); the two landings are load-bearing (mov r11, 12 vs 24), so they need distinct names. CURE:
# codegen_flat_chain_body resets the cache per graph and suffixes the floaters with the proc_ family (NRETURN_f); the top-level graph
# keeps the bare names. CONTROL ARM: the SNOBOL4 twin is one graph and must still define exactly ONE bare NRETURN: -- proving the
# suffix reaches proc_ graphs only and single-graph output is untouched. A stale binary REFUSES rc=2.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
bash ../harness/scripts/util_require_fresh.sh >/dev/null 2>&1 || { echo "REFUSES rc=2: stale or missing ./scrip -- run make"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
printf 'function f() { f = 1; nreturn; }\nfunction g() { g = 2; nreturn; }\nOUTPUT = f() g();\n' > "$W/w.sc"
printf '        DEFINE("F()")\n        DEFINE("G()")\n        OUTPUT = F() G()   :(END)\nF       F = 1     :(NRETURN)\nG       G = 2     :(NRETURN)\nEND\n' > "$W/t.sno"
bad=0
m3=$(cd "$W" && timeout -k 5 30 "$ROOT/scrip" w.sc < /dev/null 2>/dev/null); if [ "$m3" = "12" ]; then echo "  m3 PASS: 12"; else echo "  m3 RED: got '$m3'"; bad=1; fi
( cd "$W" && timeout -k 5 30 "$ROOT/scrip" --compile -o w.s w.sc < /dev/null 2>/dev/null && gcc w.s -L "$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o w 2> l.err )
if [ -x "$W/w" ]; then m4=$(cd "$W" && timeout -k 5 30 ./w < /dev/null 2>/dev/null); if [ "$m4" = "12" ]; then echo "  m4 PASS: links and answers 12 ($(grep -c '^NRETURN_[a-z0-9_]*:' "$W/w.s") suffixed NRETURN landings)"; else echo "  m4 RED: linked but answered '$m4'"; bad=1; fi; else echo "  m4 RED: did not link -- $(grep -m1 'defined' "$W/l.err")"; bad=1; fi
( cd "$W" && timeout -k 5 30 "$ROOT/scrip" --compile -o t.s t.sno < /dev/null 2>/dev/null ); n=$(grep -c '^NRETURN:' "$W/t.s" 2>/dev/null); ns=$(grep -c '^NRETURN_' "$W/t.s" 2>/dev/null)
if [ "$n" = "1" ] && [ "$ns" = "0" ]; then echo "  control PASS: the SNOBOL4 twin (one graph) defines exactly one bare NRETURN: and no suffixed one"; else echo "  control RED: SNOBOL4 twin defines $n bare and $ns suffixed NRETURN labels -- the suffix leaked past proc_ graphs or the bare landing is gone"; bad=1; fi
if [ "$bad" -ne 0 ]; then echo "GATE FAIL(1) [snc_two_nreturn_functions_link_in_m4]"; exit 1; fi
echo "GATE PASS(0) [snc_two_nreturn_functions_link_in_m4]: two nreturn functions link and answer 12 in both modes, single-graph SNOBOL4 untouched (3 arms, 0 red)"
