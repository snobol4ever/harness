#!/usr/bin/env bash
# LI-FENCE — locks in the language-independent (LI) de-name rung.
# Asserts that NO source-level symbol in src/emitter/** or src/runtime/** carries a
# language tag (sno/icn/pl/prolog/raku/rk/rebus/reb), apart from the documented carve-outs.
# Rename-only rung: this is a STRUCTURAL gate, not a behavioral one.
#
# CARVE-OUTS (deliberately kept — see GOAL-SNOBOL4-BB.md "LI de-name" watermark):
#   * IR_LANG_* / LANG_{SNO,ICN,PL,RAKU}  — the shared-layer language enum (NAMES the language
#     the one-dispatch emitter / one-file lowerer must branch on; not a per-language symbol).
#   * snocone / _snoc* / snoch / snotypes  — Snocone is a DIFFERENT language (sno is a substring).
#   * prologue / epilogue                  — assembly terms, not Prolog.
#   * src/runtime/core/**                  — the SNOBOL runtime LIBRARY (genuine SNOBOL execution
#     model: the NV/keyword tables, the pattern engine, the SNOBOL builtins). Its de-naming is a
#     separate runtime-unification decision (LI-CORE), tracked apart from this rung. (The former
#     universal-init carve-out SNO_INIT_fn was de-named to core_lib_init 2026-06-02 — it inits the
#     shared runtime + builtin ABI for every language, so its language tag was misleading.)
#   * frontend-contract dispatch NAME strings the parser mints and the runtime strcmp-dispatches:
#     ICN_NULL / ICN_CASE_EQ / ICN_SCAN_PUSH / ICN_SCAN_POP / ICN_SWAP* / ICN_GEN_STATE* ,
#     __rk_jct_* / __rk_arr , set_prolog_flag / current_prolog_flag.  Renaming these requires
#     editing the (out-of-scope) language frontends, so they are held here.
#   * sno_parse_string_ast                 — invokes the SNOBOL parser (single-language by nature).
#   * RK_NFA_BB                            — runtime getenv() config-key string (interface, not a symbol).
#   * emitted assembly LABEL-prefix / COMMENT strings ("icn_proc_%s", "sno_flat", "# BOX SNO ...")
#     — generated-output text, not source symbols; changing them would alter emitted symbol/.s text
#     and risks cross-language label collisions. Held (lines carrying s_comment/snprintf label builds).
#   * #include lines that reach parser headers (path contains prolog/raku/etc.).
#   * benign substrings: platform, brk_/BRK_, TT_PL*/TT_SECTION*/SEC_PLUS, template/tmpl,
#     repl_ (replacement), DUPL (duplicate), sample/simple/multiple, *_trail_*/resolve_mark*/MARK_STACK.

set -u
ROOTS="src/emitter src/runtime"
# language-tag tokens, searched as (sub)words inside identifiers
TAG='(_sno|sno_|SNO|_icn|icn_|ICN|Icon|pl_|_pl|PL_|_PL|prolog|Prolog|raku|Raku|RAKU|__rk|_rk_|rk_|RK_|reb_|rebus|REB)'

ALLOW='IR_LANG|LANG_SNO|LANG_ICN|LANG_PL|LANG_RAKU'              # shared language enum
ALLOW="$ALLOW"'|snocone|_snoc|snoch|snotypes|prologue|epilogue'  # other-language / assembly
ALLOW="$ALLOW"'|platform|PLATFORM|\bbrk_|BRK_|TT_PL|TT_SECTION|SEC_PLUS'   # benign substrings
ALLOW="$ALLOW"'|template|tmpl|\brepl_|DUPL|sample|simple|multiple'        # benign substrings
ALLOW="$ALLOW"'|_trail_|resolve_mark|MARK_STACK'                          # clean WAM trail
ALLOW="$ALLOW"'|ICN_NULL|ICN_CASE_EQ|ICN_SCAN_PUSH|ICN_SCAN_POP|ICN_SWAP|ICN_GEN_STATE'  # frontend-contract strings
ALLOW="$ALLOW"'|__rk_jct|__rk_arr|set_prolog_flag|current_prolog_flag'                   # frontend-contract strings
ALLOW="$ALLOW"'|sno_parse_string_ast|RK_NFA_BB'                                          # held single-language/interface
ALLOW="$ALLOW"'|s_comment|icn_proc_|sno_flat'                                            # emitted label/comment strings
ALLOW="$ALLOW"'|#\s*include'                                                             # parser-header includes
# --- held cross-boundary symbols legitimately USED (not defined) in emitter/runtime ---
ALLOW="$ALLOW"'|prolog_atom|prolog_runtime|prolog_driver|prolog_builtin'                 # parser Prolog API
ALLOW="$ALLOW"'|pl_write|pl_writeq|pl_write_canonical|pl_assert_term|pl_univ|pl_functor|pl_arg|pl_term_to_string'  # parser Prolog builtins
ALLOW="$ALLOW"'|Raku_nfa|Raku_match|raku_nfa_|raku_re|raku_nfa_compile'                  # parser Raku NFA API
ALLOW="$ALLOW"'|g_raku_match|g_raku_subject'                                             # driver Raku globals
ALLOW="$ALLOW"'|STAGE2_PL_PRED_TABLE_SIZE'                                               # stage2 contract (contracts-scope)
ALLOW="$ALLOW"'|\bIcon\b|\bProlog\b|\bprolog\b|\braku\b'                                  # English words in diagnostic strings/comments

# core/ is the LI-CORE carve-out — scanned separately, excluded here.
VIOL=$(grep -rnaE "[A-Za-z_]*${TAG}[A-Za-z_]*" $ROOTS \
         --include=*.c --include=*.cpp --include=*.h 2>/dev/null \
       | grep -avE "/core/" \
       | grep -avE "$ALLOW")

N=$(printf '%s' "$VIOL" | grep -c . )
if [ "$N" -eq 0 ]; then
  echo "OK: LI-FENCE holds — no language-tagged source symbols in src/emitter or src/runtime (outside documented carve-outs)."
  exit 0
fi
echo "FAIL: LI-FENCE — $N language-tagged source line(s) found in emitter/runtime (outside carve-outs):"
# ⛔⭐ THE CAP MUST ANNOUNCE ITSELF (hq_B 2026-08-29). This printed 40 lines under a "$N language-tagged
# source line(s)" headline with nothing saying the list was partial -- measured live at N=1623, so 1583
# violations were invisible to every reader. Same class cured the same day in
# test_gate_suite_conversion_complete.sh. A truncation the reader cannot see is not a summary; it is a
# subset in the shape of a whole.
if [ -n "${GATE_LIST_ALL:-}" ]; then
  printf '%s\n' "$VIOL"
else
  printf '%s\n' "$VIOL" | head -40
  [ "$N" -gt 40 ] && {
    echo "     ... and $((N - 40)) MORE NOT SHOWN -- this list is capped at 40; $N above is the true count."
    echo "     Full list: GATE_LIST_ALL=1 bash ../harness/scripts/test_gate_no_lang_names.sh"
  }
fi
echo "--- if any are legitimate (new shared-layer / frontend-contract / assembly term), add them to the ALLOW list in this script with a one-line rationale; otherwise de-name them. ---"
exit 1
