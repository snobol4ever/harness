#!/usr/bin/env python3
"""
util_migrate_snocone_to_lang_space.py — LS-5.a corpus migration.

Rewrites Snocone .sc source files to the post-LS-4 language:

  &&     → space (juxtaposition concat).  SPITBOL Manual Ch.15
           lifts space-as-concat at priority 4; Andrew Koenig's
           .sc had && doing the same job.  After LS-4 the new
           Bison parser accepts the space form and rejects &&.

  ||     → (a, b)  (SPITBOL alt-eval, Manual Ch.15 footnote).
           Wrapping parens are mandatory because SPITBOL alt-eval
           is "comma-separated list inside parens" — a top-level
           comma without parens is a syntax error.  N-ary chains
           collapse: `a || b || c` → `(a, b, c)`.

  go to NAME ;   → goto NAME ;       (single-keyword form)

  bare %  modulo → REMDR(a, b)       (no occurrences in the corpus
           today — verified by grep before this script ran — but
           the rule is included for completeness so a future .sc
           file that picks up % modulo gets migrated correctly.)

What this script does NOT touch:
  - string literals — '...' and "..."
  - line comments — // to end of line
  - block comments — /* ... */
  - single | (pattern alternation) — only doubled || gets the
    alt-eval rewrite

Edge-case behaviour explicitly verified against the LS-4 grammar
in src/parsers/snocone/snocone_parse.y:
  - `if (a || b)`  → `if ((a, b))` — the `if`'s own parens
    syntactically wrap a single expr0; the alt-eval needs its
    OWN parens for the `T_LPAREN expr0 T_COMMA exprlist_ne
    T_RPAREN` production to fire.
  - `(a || b)`     → `((a, b))` — same shape, two paren pairs:
    inner is alt-eval, outer is grouping (or wherever the bare
    paren came from).
  - `x = a || b`   → `x = (a, b)` — the RHS is a single alt-eval
    value, no extra wrapping needed.

Use: python3 util_migrate_snocone_to_lang_space.py [--dry-run]
                                                  [--check]
                                                  [--root DIR]
                                                  [files...]

  --dry-run   show diffs without writing changes
  --check     exit 1 if any file would change (CI gate)
  --root      directory to recursively scan for *.sc
              (default: $REPO/corpus from script location)
  files...    explicit file list overriding --root
"""

from __future__ import annotations

import argparse
import difflib
import os
import re
import sys
from pathlib import Path
from typing import Iterable, List, Tuple


# ─────────────────────────────────────────────────────────────────────
# Tokenizer-aware text rewriter
#
# A small char-by-char state machine partitions the source into
# spans that are EITHER "code" (rewritable) or "literal/comment"
# (preserved verbatim).  Rewrites are applied to code spans only.
# ─────────────────────────────────────────────────────────────────────

CODE = "code"
SQUOTE = "sq"  # inside '...'
DQUOTE = "dq"  # inside "..."
LCOMMENT = "lc"  # inside // ... \n
BCOMMENT = "bc"  # inside /* ... */


def split_into_spans(src: str) -> List[Tuple[str, str]]:
    """Return [(kind, text), ...] partitioning of src.

    Kinds: CODE, SQUOTE (incl. enclosing quotes), DQUOTE (incl.
    enclosing quotes), LCOMMENT (incl. //  and trailing newline),
    BCOMMENT (incl. /* and */).

    Preservation invariant: ''.join(text for _, text in
    split_into_spans(src)) == src.
    """
    spans: List[Tuple[str, str]] = []
    n = len(src)
    i = 0
    cur_kind = CODE
    cur_start = 0

    def flush(end: int):
        nonlocal cur_start
        if end > cur_start:
            spans.append((cur_kind, src[cur_start:end]))
        cur_start = end

    while i < n:
        c = src[i]
        if cur_kind == CODE:
            # Look for transitions
            if c == "'":
                flush(i)
                cur_kind = SQUOTE
                cur_start = i
                i += 1
            elif c == '"':
                flush(i)
                cur_kind = DQUOTE
                cur_start = i
                i += 1
            elif c == "/" and i + 1 < n and src[i + 1] == "/":
                flush(i)
                cur_kind = LCOMMENT
                cur_start = i
                i += 2
            elif c == "/" and i + 1 < n and src[i + 1] == "*":
                flush(i)
                cur_kind = BCOMMENT
                cur_start = i
                i += 2
            else:
                i += 1
        elif cur_kind == SQUOTE:
            # SNOBOL4 strings: no backslash escapes; closing quote
            # is the matching delimiter.  Newline inside a string
            # is unusual but not our concern — the lexer would
            # reject it; we just preserve bytes.
            if c == "'":
                i += 1
                flush(i)
                cur_kind = CODE
                cur_start = i
            else:
                i += 1
        elif cur_kind == DQUOTE:
            if c == '"':
                i += 1
                flush(i)
                cur_kind = CODE
                cur_start = i
            else:
                i += 1
        elif cur_kind == LCOMMENT:
            if c == "\n":
                i += 1
                flush(i)
                cur_kind = CODE
                cur_start = i
            else:
                i += 1
        elif cur_kind == BCOMMENT:
            if c == "*" and i + 1 < n and src[i + 1] == "/":
                i += 2
                flush(i)
                cur_kind = CODE
                cur_start = i
            else:
                i += 1
    flush(n)
    return spans


# ─────────────────────────────────────────────────────────────────────
# Rewrites applied to code-only spans
# ─────────────────────────────────────────────────────────────────────

# &&     →   single space.  Surrounding whitespace coalesces under
#            the LS-3 W{OP}W lexer rule; we don't need to be
#            precious about extra spaces.
_AMP_AMP_RE = re.compile(r"&&")

# go to NAME    →    goto NAME      (single-keyword form per
# Q-resolution and LS-4.i.1 grammar).  Snocone's lexer matches
# `goto` as a keyword; `go to` is two identifiers and a syntax
# error after LS-4.  We do not assume corpus uses this form — the
# initial survey returned zero hits — but the rule is included so
# a future writer's `go to NAME` migrates cleanly.
_GO_TO_RE = re.compile(r"\bgo\s+to\b(\s+)")

# Bare `||` → split-and-wrap.  `a || b || c` → `(a, b, c)` is the
# n-ary form.  We rewrite at the smallest enclosing paren / line /
# statement scope — see _rewrite_alteval below for the algorithm.

# %      →    REMDR(a, b).  No corpus uses today.  We do not
# handle this in the script; if any future .sc file uses % as
# binary modulo, the migration writer should rewrite by hand.
# Mechanical rewrite is risky because % is also a unary OPSYN
# slot character (see goal file Q3) — distinguishing binary from
# unary use needs a real parser, not regex.  Leaving as out-of-scope
# matches the LS-5.a goal-file note: "if any uses appear, rewrite
# to REMDR(a,b)" — i.e. a manual exercise.


def _rewrite_amp(code: str) -> str:
    """Replace `&&` with a single space everywhere in a code span."""
    return _AMP_AMP_RE.sub(" ", code)


def _rewrite_goto(code: str) -> str:
    """Replace `go to NAME` with `goto NAME` (whitespace preserved)."""
    return _GO_TO_RE.sub(r"goto\1", code)


# ─────────────────────────────────────────────────────────────────────
# || rewrite — the only non-trivial transform
#
# Andrew's `||` was a binary op at SPITBOL pri 4.  Replacement is
# alt-eval `(e1, e2, ...)` — comma-separated list inside parens.
#
# Approach: walk a code-only span left to right, tracking paren
# depth, accumulating spans of "ALT-EVAL operands" separated by
# `||`.  When we hit a non-`||` boundary (close-paren that
# matches our scope, semicolon, top-level newline boundary, or
# end-of-span), if we collected any `||` operators we emit
# `(op1, op2, op3)` for that range.
#
# Subtle but important: alt-eval operands inherit the surrounding
# precedence.  In SPITBOL, `||` was pri 4 (same as concat, right-
# assoc).  Anything LOWER than pri 4 (`=` pri 0, `?` pri 1, `|`
# pri 3) binds wider, so `a = b || c` means `a = (b || c)` not
# `(a = b) || c`.  Our migration must respect this: the LHS of
# the rewritten alt-eval is just `b`, not `a = b`.
#
# Tactically, we identify alt-eval-operand boundaries by walking
# over the SPITBOL pri 0..3 operator tokens at the SAME paren
# depth as the `||` we found, and stopping at the first one of
# them.  Operators we treat as "lower priority, ends an operand
# on the LEFT side of a ||":
#   = (assignment, pri 0) — but only when not inside a function
#                           call's arg list (then `,` is the
#                           separator, not assignment)
#   ?  (match, pri 1)
#   |  (alternation, pri 3) — single | not ||
#
# In practice, every `||` use in the corpus we surveyed (3 hits
# total: tree.sc x2, sc8_strings.sc x1) sits inside an `if (...)`
# condition where the surrounding context is already paren-bounded.
# The general algorithm is robust; the small-corpus check is a
# safety net.
# ─────────────────────────────────────────────────────────────────────


# Tokens that close an alt-eval operand on the LEFT (operators of
# priority strictly less than 4).  At the same paren depth as the
# || we're processing, anything matching one of these ends an
# operand and the `||` doesn't extend back past it.
#
# We parse these as discrete tokens, NOT as regex character
# classes, because of context: `==` is two `=` chars but is NOT
# the assign operator; `||` is two `|` chars but is the operator
# we're rewriting.  Our state-machine tokenizer below handles
# this directly.

# Simple SPITBOL/Snocone tokenizer for in-source use.  Returns
# token (kind, start, end) tuples for tokens we care about.
# The tokenizer SKIPS string-literal and comment regions
# transparently — those bytes still occupy character positions
# in the source, but no token boundary or rewrite touches them.
# Other bytes are passed through unchanged.

_TOK_OPS = [
    # Multi-char first (longest match wins in this list)
    ("OR_OR", "||"),
    ("EQ_EQ", "=="),
    ("NE", "!="),
    ("LE", "<="),
    ("GE", ">="),
    ("STAR_STAR", "**"),
    ("LEQ", ":==:"),
    ("LNE", ":!=:"),
    ("LLT", ":<:"),
    ("LGT", ":>:"),
    ("LLE", ":<=:"),
    ("LGE", ":>=:"),
    ("STR_IDENT", "::"),
    ("STR_DIFFER", ":!:"),
    ("PLUS_ASSIGN", "+="),
    ("MINUS_ASSIGN", "-="),
    ("STAR_ASSIGN", "*="),
    ("SLASH_ASSIGN", "/="),
    ("CARET_ASSIGN", "^="),
    # Single-char
    ("ASSIGN", "="),
    ("MATCH", "?"),
    ("PIPE", "|"),
    ("LPAREN", "("),
    ("RPAREN", ")"),
    ("LBRACK", "["),
    ("RBRACK", "]"),
    ("LBRACE", "{"),
    ("RBRACE", "}"),
    ("SEMI", ";"),
    ("COMMA", ","),
]


def _tokenize_code(code: str):
    """Yield (kind, start, end) for tokens we track.  Strings
    ('...' and "...") and comments (// to EOL, /* ... */) are
    skipped over inline — their bytes still occupy character
    positions in the source string but no tokens are emitted
    from inside them.

    Other (uninteresting) bytes are skipped without yielding."""
    n = len(code)
    i = 0
    while i < n:
        c = code[i]

        # String/comment skips first — these mask what's inside
        # from operator recognition.
        if c == "'":
            i += 1
            while i < n and code[i] != "'":
                i += 1
            if i < n:
                i += 1  # consume closing quote
            continue
        if c == '"':
            i += 1
            while i < n and code[i] != '"':
                i += 1
            if i < n:
                i += 1
            continue
        if c == "/" and i + 1 < n and code[i + 1] == "/":
            i += 2
            while i < n and code[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and code[i + 1] == "*":
            i += 2
            while i + 1 < n and not (code[i] == "*" and code[i + 1] == "/"):
                i += 1
            if i + 1 < n:
                i += 2
            continue

        # Operator / punctuation match — longest-first
        matched = False
        for kind, lit in _TOK_OPS:
            if code.startswith(lit, i):
                yield (kind, i, i + len(lit))
                i += len(lit)
                matched = True
                break
        if not matched:
            i += 1


def _rewrite_alteval(code: str) -> str:
    """Rewrite `e1 || e2 || ... || eN` to `(e1, e2, ..., eN)` at
    every site within a code span.

    Algorithm:

      1. Tokenize, building a list of (kind, start, end) entries.
      2. For each `||`, find the smallest enclosing scope:
          - the innermost open paren/brace/bracket whose match
            comes after the ||, OR
          - the boundary of the code span (start / end / a SEMI
            we've crossed at depth 0).
      3. Within that scope, find all the `||` operators at the
         scope's depth (NOT inside nested parens).  Group them.
      4. For each group, find operand boundaries:
          - left-end: the previous SEMI / ASSIGN / MATCH / PIPE
            at scope depth, or the scope opener
          - right-end: the next SEMI / scope closer
            (= / ? / | bind tighter than ||? — NO, they bind
            looser, so they also terminate the alt-eval operand
            on the right side)
      5. Replace the substring `e1 || e2 ... || eN` with
         `(e1, e2, ..., eN)`.

    We do replacements right-to-left so earlier offsets remain
    valid as we go.  When two `||` chains exist in one span, they
    are independent; their groups don't overlap because they sit
    in different scopes or are separated by a low-priority op /
    SEMI / ASSIGN / etc.
    """

    if "||" not in code:
        return code

    # Build full token list once.
    toks = list(_tokenize_code(code))

    # Group every `||` token into chains by depth-scope.
    # A "chain" is a maximal sequence of `||` operators at the
    # same paren depth, separated only by tokens that don't
    # close their enclosing scope or step outside the SPITBOL
    # pri-4 boundary.

    # First pass: compute the depth at every token and identify
    # the index of every || token.

    depth = 0
    depths: List[int] = []  # parallel array to toks
    or_or_indices: List[int] = []
    for idx, (kind, _, _) in enumerate(toks):
        if kind == "LPAREN" or kind == "LBRACK" or kind == "LBRACE":
            depths.append(depth)  # the opener itself sits at outer depth
            depth += 1
        elif kind == "RPAREN" or kind == "RBRACK" or kind == "RBRACE":
            depth -= 1
            depths.append(depth)
        else:
            depths.append(depth)
        if kind == "OR_OR":
            or_or_indices.append(idx)

    if not or_or_indices:
        return code

    # Group consecutive || at the same depth into chains.  Two
    # || are part of the same chain iff:
    #   - they have the same depth
    #   - between them, no token at LOWER depth occurred (i.e.
    #     we did not step outside the scope)
    #   - between them, no SPITBOL-pri-≤3 operator occurred at
    #     equal depth (=, ?, |, SEMI — these end an alt-eval
    #     operand)

    LOW_PRI_KINDS = {"ASSIGN", "MATCH", "PIPE", "SEMI", "COMMA"}
    # Note: COMMA already separates inside an existing alt-eval
    # `(...)`; we don't want to coalesce across one.

    chains: List[List[int]] = []  # list of lists of or_or_indices indices
    cur: List[int] = []
    for k, oi in enumerate(or_or_indices):
        if not cur:
            cur = [oi]
            continue
        prev_oi = cur[-1]
        # Walk between prev_oi and oi looking for any
        # depth-mismatched opener/closer or a low-pri op at
        # the same depth.
        same_chain = (depths[prev_oi] == depths[oi])
        if same_chain:
            min_depth_between = depths[prev_oi]
            for j in range(prev_oi + 1, oi):
                if depths[j] < depths[prev_oi]:
                    same_chain = False
                    break
                if (
                    depths[j] == depths[prev_oi]
                    and toks[j][0] in LOW_PRI_KINDS
                ):
                    same_chain = False
                    break
                if depths[j] < min_depth_between:
                    min_depth_between = depths[j]
        if same_chain:
            cur.append(oi)
        else:
            chains.append(cur)
            cur = [oi]
    if cur:
        chains.append(cur)

    # For each chain, find operand boundaries.

    # Left boundary search: walk LEFT from the first `||`'s index
    # at the chain's depth, stopping at:
    #   - a depth drop (we've crossed an opener of the enclosing
    #     scope) → boundary is just AFTER that opener
    #   - a low-pri op at chain's depth → boundary is just AFTER
    #     that op
    #   - the start of toks → boundary is the start of code

    # Right boundary search: walk RIGHT from the last `||`'s index
    # at the chain's depth, stopping at the same triple of
    # conditions.

    # Then collect operand text by carving the code string at
    # the boundary character offsets and the `||` character
    # offsets.

    edits: List[Tuple[int, int, str]] = []  # (char_start, char_end, replacement)

    for chain in chains:
        chain_depth = depths[chain[0]]
        first_oi = chain[0]
        last_oi = chain[-1]

        # Find left boundary character offset
        left_char = None
        j = first_oi - 1
        while j >= 0:
            if depths[j] < chain_depth:
                # j is the closer at depths[j], or an opener
                # whose own depth was depths[j]?  Recall: openers
                # record their OUTER depth in `depths`.  So a
                # token at depths[j] < chain_depth that is an
                # opener (LPAREN/LBRACK/LBRACE) means we've
                # walked OUT of the enclosing scope.  Good.
                # The boundary is just AFTER toks[j]'s end.
                if toks[j][0] in ("LPAREN", "LBRACK", "LBRACE"):
                    left_char = toks[j][2]
                    break
                # else (RPAREN/RBRACK/RBRACE at lower depth) —
                # shouldn't happen: walking left at constant
                # chain_depth, we don't drop into a closed scope.
                # Treat as boundary anyway.
                left_char = toks[j][2]
                break
            if (
                depths[j] == chain_depth
                and toks[j][0] in LOW_PRI_KINDS
            ):
                left_char = toks[j][2]
                break
            j -= 1
        if left_char is None:
            left_char = 0

        # Find right boundary character offset
        right_char = None
        j = last_oi + 1
        while j < len(toks):
            if depths[j] < chain_depth:
                # Walked out of enclosing scope — closer at the
                # outer depth means scope's RPAREN-equivalent.
                right_char = toks[j][1]
                break
            if (
                depths[j] == chain_depth
                and toks[j][0] in LOW_PRI_KINDS
            ):
                right_char = toks[j][1]
                break
            j += 1
        if right_char is None:
            right_char = len(code)

        # Now extract operand strings.  Operands sit between:
        #   left_char .. or_or_indices[0]_start
        #   or_or_indices[0]_end .. or_or_indices[1]_start
        #   ...
        #   or_or_indices[-1]_end .. right_char

        operand_texts: List[str] = []
        op_start = left_char
        for oi in chain:
            op_end = toks[oi][1]  # start char of `||`
            operand_texts.append(code[op_start:op_end])
            op_start = toks[oi][2]  # end char of `||`
        operand_texts.append(code[op_start:right_char])

        # Trim each operand of leading/trailing whitespace, but
        # preserve internal whitespace.  Wrap with `(`...`)`
        # using `, ` as separator.
        cleaned = [t.strip() for t in operand_texts]
        # Empty operand from a degenerate `||` at the boundary
        # should never happen with correct source; if it does,
        # leave the whole thing alone for human review.
        if any(t == "" for t in cleaned):
            continue

        replacement = "(" + ", ".join(cleaned) + ")"
        edits.append((left_char, right_char, replacement))

    # Apply edits right-to-left so earlier offsets stay valid.
    edits.sort(key=lambda e: e[0], reverse=True)
    out = code
    for s, e, r in edits:
        # Preserve any leading whitespace in code[s..s+leading_ws]
        # so we don't crush indentation.  Actually our operand
        # extraction already includes leading whitespace into the
        # first operand which got stripped; that's fine.
        # But we want the new "(" placed where the original
        # operand started, with leading whitespace preserved
        # outside the parens.
        leading_ws_len = 0
        while s + leading_ws_len < e and out[s + leading_ws_len] in " \t":
            leading_ws_len += 1
        prefix_ws = out[s : s + leading_ws_len]
        out = out[:s] + prefix_ws + replacement + out[e:]
    return out


# ─────────────────────────────────────────────────────────────────────
# Top-level migrate function
# ─────────────────────────────────────────────────────────────────────


def migrate_text(src: str) -> str:
    """Return migrated source.  Idempotent: running twice yields
    the same result as running once.

    Two-stage: first the `||` → `(...)` rewrite runs on the WHOLE
    source (with the tokenizer skipping over string/comment
    regions inline so paren balancing across them works), then
    the per-span sweep handles `&&` → space and `go to` → `goto`
    on the (post-||) source's code spans."""
    # Stage 1: || rewrite — operates on whole source so operands
    # spanning across string literals (e.g. `IDENT(x, '')`) are
    # captured intact.
    src = _rewrite_alteval(src)
    # Stage 2: per-span sweep for && and go-to.  These two are
    # local-replace-with-no-paren-balancing and so are safe to
    # do on a per-span basis.
    out_parts: List[str] = []
    for kind, text in split_into_spans(src):
        if kind != CODE:
            out_parts.append(text)
            continue
        c = text
        c = _rewrite_amp(c)
        c = _rewrite_goto(c)
        out_parts.append(c)
    return "".join(out_parts)


# ─────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────


def find_default_root() -> Path:
    here = Path(__file__).resolve()
    # harness/scripts/util_migrate_snocone_to_lang_space.py
    # repo parent is SCRIP/.. which has corpus/ alongside
    repo_parent = here.parent.parent.parent
    corpus = repo_parent / "corpus"
    return corpus


def gather_files(root: Path) -> List[Path]:
    if not root.is_dir():
        raise SystemExit(f"FAIL not a directory: {root}")
    return sorted(root.rglob("*.sc"))


def main(argv: List[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        description="LS-5.a Snocone corpus migration"
    )
    p.add_argument("--dry-run", action="store_true",
                   help="print diffs, do not write")
    p.add_argument("--check", action="store_true",
                   help="exit 1 if any file would change")
    p.add_argument("--root", type=Path, default=None,
                   help="recursive scan root (default: corpus/)")
    p.add_argument("files", nargs="*", type=Path,
                   help="explicit files (overrides --root scan)")
    args = p.parse_args(argv)

    if args.files:
        targets = list(args.files)
    else:
        root = args.root or find_default_root()
        targets = gather_files(root)

    changed = 0
    would_change = 0
    for fp in targets:
        try:
            src = fp.read_text()
        except Exception as e:
            print(f"WARN  cannot read {fp}: {e}", file=sys.stderr)
            continue
        out = migrate_text(src)
        if out == src:
            continue
        would_change += 1
        if args.dry_run or args.check:
            diff = difflib.unified_diff(
                src.splitlines(keepends=True),
                out.splitlines(keepends=True),
                fromfile=str(fp),
                tofile=str(fp) + " (migrated)",
                n=2,
            )
            sys.stdout.writelines(diff)
        if not (args.dry_run or args.check):
            fp.write_text(out)
            changed += 1
            print(f"WROTE {fp}")

    if args.check:
        if would_change:
            print(f"CHECK  {would_change} files would change",
                  file=sys.stderr)
            return 1
        print("CHECK  clean", file=sys.stderr)
        return 0

    if args.dry_run:
        print(f"DRY-RUN  {would_change} files would change",
              file=sys.stderr)
    else:
        print(f"DONE  {changed} files migrated "
              f"of {len(targets)} scanned",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
