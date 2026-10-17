#!/usr/bin/env bash
# test_gate_no_raw_asm_producers.sh — RAW PRODUCER ERADICATION (Lon 2026-08-13, in-chat: "Remove all
# 'raw producers', those are INVALID!!!  ALL should be funneled through x86_*() FAMILY of functions.
# And a SMALL family at that.").
#
# RULES.md TEMPLATE-ONLY EMISSION already says it: every x86 instruction — BINARY and TEXT — is
# produced ONLY inside x86(...) encoder internals.  A call site that hands emit_textf/emit_text_n a
# hand-written assembly string is a RAW PRODUCER and is forbidden: it bypasses the encoders, so it
# cannot be re-targeted, cannot be counted, and (since the TAB rung) cannot carry field separators —
# it lands on the sink's legacy whitespace parse and re-introduces exactly the sniffing that rung
# deleted.  THE SINK'S LEGACY PARSE CANNOT BE DELETED UNTIL THIS COUNT REACHES ZERO.
#
# LEGITIMATE (not counted): handing the sink an ALREADY-BUILT string — emit_text_n(s.data(), s.size())
# — which is how every xa_*.cpp template already works, because that string was built by x86().
#
# Usage: bash ../harness/scripts/test_gate_no_raw_asm_producers.sh [--list]
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
LIST=${1:-}
# a raw producer = emit_textf( with a string literal that contains assembly, or emit_text_n of a
# hand-built char buffer.  The sink-call form emit_text_n(<expr>.data(), <expr>.size()) is exempt.
scan() {
  grep -rn 'emit_textf(\|emit_text_n(' src/ --include=*.c --include=*.cpp \
    | grep -v 'emit_text_n([A-Za-z_][A-Za-z0-9_]*\.data()' \
    | grep -v 'void emit_text\|emit_text_raw_n(s\|emit_text_count\|emit_textf_flush\|static void emit_text_raw_n' \
    | grep -v 'if (need < (int) sizeof sb) emit_text_n\|vsnprintf(hb' \
    | grep -vP '^\S+:\d+:\s*(/\*|\*)'
}
n=$(scan | wc -l)
[ "$LIST" = "--list" ] && scan
echo "RAW ASM PRODUCERS: $n"
scan | awk -F: '{print $1}' | sort | uniq -c | sort -rn | sed 's/^/    /'
[ "$n" -eq 0 ] && { echo "GATE GREEN — every assembly byte funnels through x86()"; exit 0; }
echo "GATE RED — $n raw producer(s) remain outside the x86() family"; exit 1
