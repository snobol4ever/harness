#!/usr/bin/env bash
# util_census_unrooted_static_gc_pointers.sh -- THE CLASS cto NAMED (2026-09-22, on hq_icon's trace_tab finding
# and hq_snocone's RTCCB spill-slot finding, THIRD INSTANCE THAT HOUR): a static or file-scope C object that
# stores a pointer obtained from the collected GC heap and is never walked by any typed root-visitor. This is
# the ROOT-DOES-NOT-EXIST shape, distinct from the safe-point census (which counts POLLS AT CALL SITES): a
# missing root is invisible to that census by construction, because there is no call site to miss a poll at --
# the pointer just sits in memory nothing ever visits, and the arena reissues its bytes on the next collection.
#
# WHAT THIS IS: a heuristic three-pass grep instrument, not a proof. It (1) lists file-scope `static`
# declarations under src/runtime that are pointers or arrays of a pointer-holding type, (2) checks whether each
# name is ever ASSIGNED from a named GC-heap allocator wrapper in the SAME FILE, (3) checks whether each name
# ever appears inside the BODY of any *_gc_roots-family function (wherever in the tree that function lives).
# A name that is BOTH sourced and unvisited is the population this instrument reports.
#
# ⛔ WHAT IT CANNOT SEE, NAMED RATHER THAN HIDDEN (same discipline as
# test_gate_c_allocators_are_eradicated_and_say_where_they_went.sh's own arm 11 census): sourcing or visiting
# through a HELPER FUNCTION, a MACRO, or a DIFFERENT FILE than the declaration's own is invisible to a same-file
# grep. A name that collides with an unrelated identifier (a local variable, a struct field of the same
# spelling) can print a false negative (looks visited when it is not) or a false positive census entry that a
# reader must still verify by hand -- this script found 286 raw static-shaped lines and roughly 230 of them were
# noise (static FUNCTIONS with a pointer return type, single-letter extraction artifacts, the collector's own
# gc_heap.c bookkeeping, and function-pointer dispatch tables that point at CODE, never at collected data).
# ⭐ SO THIS SCRIPT PRINTS A CANDIDATE LIST FOR A HUMAN (OR A SEAT) TO READ, NOT A VERDICT A GATE CAN FAIL ON.
# Turning it into a gate needs a per-name ALLOWLIST of confirmed-safe statics (ct_*-family allocations, raw
# argv, fixed-size non-pointer buffers, compile-time-only tables written before any user code can run) --
# that allowlist does not exist yet, and building it without running each witness is exactly the "a census
# that counts the wrong population is wrong for every member of it" trap this codebase warns about elsewhere.
#
# Usage: bash ../harness/scripts/util_census_unrooted_static_gc_pointers.sh [src-dir]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
SRCDIR="${1:-src/runtime}"

SRC_FNS='rt_heap_strdup_c|rt_wsb_alloc|rt_heap_alloc_c|rt_pvec_alloc|rt_ws_alloc_descr|rt_pl_struct_alloc|rt_pm_struct_alloc|rt_str_dup|c_rt_str_alloc|c_rt_agg_alloc|rt_gcheap_alloc|rt_wsb_realloc|rt_pvec_realloc'

# ---- pass 0: every *_gc_roots-family function in the whole tree, by file:name -------------------------------
VISITORS="$(grep -rnE '^(void|static void|long|static long) [A-Za-z_]*gc_root[A-Za-z_]*\(' src --include='*.c' \
  | sed -E 's/^([^:]+):([0-9]+):(void|static void|long|static long) ([A-Za-z_]+)\(.*/\1:\4/')"
[ -n "$VISITORS" ] || { echo "REFUSE(2): no *_gc_roots-family function found anywhere under src/ -- the visitor set itself is empty, which means either the tree moved or this grep no longer matches its shape"; exit 2; }
VISITOR_BODY_FILE="$(mktemp)"; trap 'rm -f "$VISITOR_BODY_FILE"' EXIT
: > "$VISITOR_BODY_FILE"
while IFS=: read -r vfile vfn; do
  awk -v fn="$vfn" 'BEGIN{on=0} $0 ~ ("^(void|static void|long|static long)[ \t]+" fn "\\(") {on=1} on{print} on && /^}/{exit}' "$vfile" >> "$VISITOR_BODY_FILE"
done <<<"$VISITORS"
n_visitors=$(printf '%s\n' "$VISITORS" | wc -l)

# ---- POSITIVE CONTROL (cto, 2026-09-22): a reader that only ever reports absence goes quietly blind the
# moment its own matcher stops matching -- a renamed visitor, a pointer reached through a typedef, a table
# declared in a header. Point this census at an object KNOWN to be correctly rooted (core_gc_roots visits
# _udef_types -- verified by hand, not by this script, the day this control was added) and REFUSE rc=2 if the
# census's own visitor-body extraction cannot find it: a broken matcher must never be mistaken for a clean tree.
if ! grep -qw '_udef_types' "$VISITOR_BODY_FILE"; then
  echo "REFUSE(2): positive control failed -- _udef_types is known-rooted (core_gc_roots, src/runtime/core/core.c)"
  echo "    and this census's own visitor-body extraction did not find it. The matcher is broken; every"
  echo "    CANDIDATE line this run would print is unproven, and every absence is unproven too."
  exit 2
fi

# ---- pass 1: candidate file-scope static pointer/array declarations under $SRCDIR ---------------------------
CANDIDATES="$(mktemp)"; trap 'rm -f "$VISITOR_BODY_FILE" "$CANDIDATES"' EXIT
: > "$CANDIDATES"
while IFS= read -r f; do
  grep -nE '^static[[:space:]].*(\*|\[)' "$f" | while IFS=: read -r ln rest; do
    # exclude static FUNCTIONS (a '(' followed eventually by a ')' then '{' on the same line is a definition,
    # never a data declaration) and exclude function-pointer DISPATCH TABLES (name wrapped in "(*name[" --
    # those point at code the linker placed, never at collected data, and are not this class)
    case "$rest" in *'(*'*) continue ;; esac
    case "$rest" in *'{'*')'* ) continue ;; esac
    name="$(printf '%s' "$rest" | grep -oE '[A-Za-z_][A-Za-z0-9_]*\s*(\[|;|=)' | head -1 | grep -oE '[A-Za-z_][A-Za-z0-9_]*')"
    [ -n "$name" ] || continue
    # only names that look like real file-scope identifiers (this codebase's own convention: g_* or _*,
    # length >= 4) -- shorter tokens are overwhelmingly mis-extracted locals/params, not real globals
    case "$name" in g_????*|_????*) ;; *) continue ;; esac
    printf '%s:%s:%s\n' "$f" "$ln" "$name"
  done
done < <(find "$SRCDIR" -maxdepth 2 -name '*.c') | sort -u -t: -k3 >> "$CANDIDATES"
n_cand=$(wc -l < "$CANDIDATES")

# ---- pass 2/3: sourced (same file, direct assignment from a source fn) AND unvisited (name absent from every
#      visitor body) -----------------------------------------------------------------------------------------
sourced_unvisited=0; visited_n=0; not_sourced_n=0
while IFS=: read -r file ln name; do
  if grep -qw "$name" "$VISITOR_BODY_FILE"; then visited_n=$((visited_n+1)); continue; fi
  hit="$(grep -nE "$name(\[[]a-zA-Z0-9_.>[-]*\])?\s*(->|\.)?[a-zA-Z0-9_]*\s*=\s*.*($SRC_FNS)" "$file" | head -1)"
  if [ -n "$hit" ]; then
    sourced_unvisited=$((sourced_unvisited+1))
    printf 'CANDIDATE %s (%s:%s): sourced from a GC-heap allocator in this file and NOT referenced by any of the %d *_gc_roots-family bodies\n' "$name" "$file" "$ln" "$n_visitors"
    printf '    %s\n' "$hit"
  else
    not_sourced_n=$((not_sourced_n+1))
  fi
done < "$CANDIDATES"

echo "------------------------------------------------------------"
echo "positive control: _udef_types (known-rooted) FOUND in the visitor-body blob -- the matcher can see a real root"
echo "population: $SRCDIR, static file-scope pointer/array declarations examined=$n_cand"
echo "  visited by a *_gc_roots-family function (by name, same-file or cross-file)=$visited_n"
echo "  NOT sourced by a same-file direct call to a GC-heap allocator (excluded -- may be a different allocator"
echo "    family, a raw non-heap pointer, a fixed-size buffer, or sourced through an indirection this grep cannot"
echo "    see; needs a human read before being called safe OR unsafe)=$not_sourced_n"
echo "  CONFIRMED CANDIDATES (sourced AND unvisited, by this heuristic)=$sourced_unvisited"
echo "⚠ THIS IS A CENSUS, NOT A GATE: every CONFIRMED CANDIDATE line above still needs its own witness (a program"
echo "  that stores a value there, forces a collection, and reads it back) before it is reported as a live defect."
echo "  A name absent from this list is not proven safe -- see the header for what a same-file grep cannot see."
exit 0
