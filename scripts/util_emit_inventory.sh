#!/usr/bin/env bash
# ../harness/scripts/util_emit_inventory.sh — STRING-CONCAT-ALL SC-0 inventory.
# Classifies every emit_*/s_* symbol in the emitter core/io/sm/bb/str TUs as
# TEXT-BUILDER (convert to return std::string) vs BINARY/RELOC (leave imperative;
# ER-8 territory). Prints a rough call-graph depth so leaves convert first.
# Self-contained per RULES.md. No build required; pure source scan.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SRC="$ROOT/src/emitter"
FILES="emit.cpp emit.h emit_io.c emit_str.cpp"

echo "=== STRING-CONCAT-ALL SC-0 emit_* inventory ==="
echo
echo "## Already returning std::string (leaves — DONE in ER wave):"
grep -hoE "std::string\s+(s_[a-z0-9_]+|emit_[a-z0-9_]+)" $SRC/emit.h 2>/dev/null \
  | sed -E 's/std::string\s+//' | sort -u | sed 's/^/  /'
echo
echo "## TEXT-BUILDER imperative (CONVERT — fprintf/fputs that build code text):"
for f in $FILES; do
  [ -f "$SRC/$f" ] || continue
  awk -v F="$f" '
    /^[[:space:]]*(void|int|const char \*|char \*)[[:space:]]+emit_[a-z0-9_]+[[:space:]]*\(/ {
      fn=$0; sub(/\(.*/,"",fn); gsub(/[[:space:]]+/," ",fn); sub(/.* /,"",fn)
      cur=fn; body=""; depth=0
    }
    cur!="" {
      body=body"\n"$0
      depth += gsub(/{/,"{"); depth -= gsub(/}/,"}")
      if (depth<=0 && body ~ /{/) {
        isbin  = (body ~ /insn_|reloc|emit_byte|emit_u8|emit_u32|fwrite\(/)
        istext = (body ~ /fprintf|fputs/)
        if (istext && !isbin) print "  "cur"  ("F")"
        cur=""
      }
    }
  ' "$SRC/$f"
done | sort -u
echo
echo "## BINARY/RELOC imperative (LEAVE — ER-8 territory):"
grep -hoE "void\s+insn_[a-z0-9_]+" $SRC/../emitter/*.h 2>/dev/null | sed -E 's/void\s+//' | sort -u | head -20 | sed 's/^/  /'
echo "  ...(52 insn_* total)"
echo
echo "## Middle-layer text emitters most-called by templates (convert FIRST in SC-1/3):"
for sym in emit_text_jmp emit_text_label emit_comment emit_directive emit_text_global \
           emit_seq_port_call emit_seq_port_call_rip emit_banner_stno emit_text_stno_banner; do
  # PATH CORRECTED s169 (seat1, gates-dead-paths): was $SRC/{SM,BB,XA}_templates -- all three died in the
  # src reorg, so every symbol below reported "called-in 0 template files" and the inventory was a false zero.
  c=$(grep -rl "\b$sym\b" "$ROOT/src/templates" 2>/dev/null | wc -l)
  printf "  %-26s called-in %s template files\n" "$sym" "$c"
done
echo
echo "## fprintf/fputs/fwrite site count per TU (the ~380 to migrate):"
# emit_core.c / emit_io.c / emit_sm.c / emit_bb.c are all pre-reorg names; the emitter TUs are now
# emit.cpp + emit_str.cpp (s169 seat1, gates-dead-paths).
for f in emit.cpp emit_str.cpp; do
  [ -f "$SRC/$f" ] && printf "  %-16s %s\n" "$f" "$(grep -cE 'fprintf|fputs|fwrite' "$SRC/$f")"
done
