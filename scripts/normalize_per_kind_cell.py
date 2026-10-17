#!/usr/bin/env python3
"""normalize_per_kind_cell.py — canonicalize one audit cell file for diff.

Reads stdin (or a single positional file), writes normalized form to stdout.
Normalizations applied (driven by file extension):

  Common to all text backends (.s, .j, .js, .il, .wat):
    - Strip blank lines.
    - Strip comment lines (#-prefixed in GAS, ;-prefixed in IL, //-prefixed in JS,
      ;;-prefixed in WAT, comment-prefixed in Jasmin).
    - Normalize internal node-id suffixes _<digits>_<digits>  →  _S_N (sid/nid drop).
    - Normalize compiler-generated label names .L<digits>  →  .Lxxx.
    - Normalize bare hex addresses 0x<hex 8+>             →  0xADDR.
    - Normalize plain decimal addresses that look like rodata pointers
      (any decimal >= 1_000_000) →  ADDR.   This catches the ival/sval union
      leak (e.g. JS template's make_pat_5398772_41120 → make_pat_ADDR_S_N).

  Binary (.bin):  mask build-variant absolute-address operands via opcode-driven
    (offset, length) spans (see bin_mask_regions).  Two cases: (1) movabs imm64
    (48 B8..BF + 8 bytes) — always an address, zero the 8 imm bytes; (2) mov
    r32,imm32 (B8..BF + 4 bytes, no REX.W) — zero the 4 imm bytes ONLY when the
    value >= 0x100000 (the binary analogue of the text ">=1_000_000 => ADDR"
    rule), so leaked rodata/registry pointers are masked but real small constants
    (arity, opcode tags) survive.  Result: baseline verifies instruction skeleton
    + length + call framing (FF D0) + every real operand, while build-variant
    addresses are neutralized.  The diff script imports bin_mask_regions to do a
    bitwise masked compare (zero both sides over the same spans, then cmp).

The output is what gets committed as the baseline AND what the diff script
compares.  Same script on both sides → no skew.

Usage:
    cat raw.s | normalize_per_kind_cell.py --ext s
    normalize_per_kind_cell.py --ext s raw.s
"""
import re
import sys

# ── extension → list of normalization rules ──────────────────────────────────
# Each rule is (pattern_regex, replacement_string).  Applied in order, line by
# line.  Comment-stripping is handled separately because it's an outright drop.

COMMENT_PREFIX = {
    "s":   "#",      # GAS
    "j":   ";",      # Jasmin (also accepts ; for comments)
    "il":  "//",     # CIL / .NET MSIL
    "js":  "//",     # JavaScript
    "wat": ";;",     # WebAssembly text format
}

# Common patterns (applied after comment stripping)
COMMON_RULES = [
    # sid_nid suffix pairs:  _12345_67890  →  _S_N.
    # The trailing context may be:
    #   - end-of-token (\b)         e.g.  make_pat_5_67890$
    #   - another _word segment     e.g.  alt_0_50208_beta_omega
    #   - dot or colon              e.g.  bb_alt$pat_0_46112.try
    # All three reduce to a (?=_|\b) lookahead.  Using lookahead avoids
    # consuming a separator that would block adjacent matches.
    (re.compile(r"_(\d+)_(\d+)(?=_|\b)"), "_S_N"),
    # GAS / CIL labels: .L1234  →  .Lxxx
    (re.compile(r"\.L\d+"),         ".Lxxx"),
    # hex addresses: 0xdeadbeef (8+ hex digits)  →  0xADDR
    (re.compile(r"0x[0-9a-fA-F]{8,}"), "0xADDR"),
    # large decimal numbers (>= 1_000_000) — likely rodata pointers leaked
    # through the ival/sval union.  Be conservative: only fire for standalone
    # tokens, not for numbers inside larger identifiers.
    (re.compile(r"\b\d{7,}\b"),     "ADDR"),
]


def strip_comments_for(ext, line):
    """Return None if the line is a pure comment, else the line possibly
    stripped of a trailing inline comment.  Quirk: # appears inside x86_text
    BOX banners ('    # BOX LEN(5)') — those rows ARE the diagnostic content,
    so for .s we keep them but strip the literal '#-----…' separator rows."""
    if ext == "s":
        # Drop pure separator rows of just '#---…'
        if re.match(r"^\s*#-+\s*$", line):
            return None
        return line
    prefix = COMMENT_PREFIX.get(ext)
    if not prefix:
        return line
    stripped = line.lstrip()
    if stripped.startswith(prefix):
        return None
    # Inline comment trim — only safe to do for // (JS/IL) and ;; (WAT).
    # Skip GAS/Jasmin to avoid stripping legitimate semicolons in operands.
    if prefix in ("//", ";;"):
        idx = line.find(prefix)
        if idx >= 0:
            return line[:idx].rstrip()
    return line


def normalize_stream(ext, src):
    # Collect all non-comment, non-blank tokens from every line.
    # Apply COMMON_RULES substitutions, then squeeze ALL whitespace
    # (within lines and across line boundaries) to a single space.
    # Output: one single line of space-separated tokens followed by \n.
    # This makes leading indent, trailing spaces, and line breaks irrelevant —
    # only the instruction tokens and their order matter.
    tokens = []
    for raw in src:
        line = raw.rstrip("\n")
        line = strip_comments_for(ext, line)
        if line is None:
            continue
        if not line.strip():
            continue
        for pat, repl in COMMON_RULES:
            line = pat.sub(repl, line)
        tokens.extend(line.split())
    if not tokens:
        return ""
    return " ".join(tokens) + "\n"


def bin_mask_regions(data):
    """Return a list of (offset, length) spans whose bytes are build-variant
    (absolute host addresses baked into x86 binary emission) and must be masked
    before comparison.  Two opcode-driven cases:

      1. movabs <reg>, imm64  — REX.W (0x48) + (0xB8..0xBF) + 8 imm bytes.
         The 8 immediate bytes are always an absolute host pointer (rt-fn ptr,
         string/name ptr).  Mask offset = opcode_pos+2, length = 8.

      2. mov <r32>, imm32      — (0xB8..0xBF) + 4 imm bytes, NOT preceded by a
         REX.W 0x48 (that would be the movabs case above).  The imm32 is USUALLY
         a real constant (arity, opcode tag — all observed <= 0x16), but for a
         few cells it is an address-derived value (observed 0x5ef8fd, ~6.2M) that
         shifts every build.  Mask ONLY when imm32 >= ADDR_THRESHOLD — the binary
         analogue of the text normalizer's ">= 1_000_000 => ADDR" rule.  This
         cleanly separates the leaked pointer from every legitimate small
         constant.  Mask offset = opcode_pos+1, length = 4.
    """
    ADDR_THRESHOLD = 0x100000
    regions = []
    i = 0
    n = len(data)
    while i < n:
        if i + 10 <= n and data[i] == 0x48 and 0xB8 <= data[i + 1] <= 0xBF:
            regions.append((i + 2, 8))
            i += 10
        elif 0xB8 <= data[i] <= 0xBF and i + 5 <= n and (i == 0 or data[i - 1] != 0x48):
            imm = int.from_bytes(data[i + 1:i + 5], "little")
            if imm >= ADDR_THRESHOLD:
                regions.append((i + 1, 4))
            i += 5
        else:
            i += 1
    return regions


def mask_bin(data):
    """Apply bin_mask_regions to a copy of data, zeroing each masked span."""
    out = bytearray(data)
    for off, length in bin_mask_regions(data):
        for k in range(off, off + length):
            out[k] = 0x00
    return out



def main():
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--ext", required=True,
                   help="file extension (without dot): s/j/js/il/wat/bin")
    p.add_argument("path", nargs="?",
                   help="path to read (default: stdin)")
    args = p.parse_args()

    if args.ext == "bin":
        data = sys.stdin.buffer.read() if args.path is None else open(args.path, "rb").read()
        masked = mask_bin(data)
        sys.stdout.buffer.write(bytes(masked))
        return

    if args.path:
        with open(args.path, "r", encoding="utf-8", errors="replace") as f:
            sys.stdout.write(normalize_stream(args.ext, f))
    else:
        sys.stdout.write(normalize_stream(args.ext, sys.stdin))


if __name__ == "__main__":
    main()
