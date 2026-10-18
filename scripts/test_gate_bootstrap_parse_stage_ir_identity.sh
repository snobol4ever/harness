#!/usr/bin/env bash
# test_gate_bootstrap_parse_stage_ir_identity.sh -- A CHANGE TO THE PARSE STAGE LEAVES WHAT THE LOWERER AND THE EMITTER MAKE OF EVERY CORPUS PROGRAM EXACTLY AS IT WAS.
# (Lon 2026-10-08 18:4x CDT, CEO-1566: the parse stage of scrip becomes the linked parser_<lang>.sc object; ceo CEO-1571 named this gate, ARCH-PARSER-SC-BOOTSTRAP.md
# section 3.11 defines it, the cfo's review fixed its cost rule.) The tree-for-tree gate omits :line :lline :file :stno :src, which the C parsers attach and the
# lowerers read, so a tree that MATCHes can still lower differently. THIS gate compares what the parse stage's consumers PRODUCE, per corpus file, between a
# PARENT build and the changed build:
#   (a) `scrip --dump-ir FILE`  stdout + rc   -- the shape of every statement graph. It prints STATEMENT_BEGIN/END with an EMPTY payload, so it is blind to
#                                               the statement number, the line and the source text; it proves the shape and nothing more;
#   (b) `scrip --compile -o X.s FILE` the assembly -- which carries the source text of every statement as a comment (:src), a `.loc` line (:line) and the
#                                               statement-number-to-line table (:stno). The assembly is the half that proves the placement.
# Either half alone is insufficient (measured 2026-10-08: two runs of one build are byte-identical, so the comparison is exact).
# THE PARENT IS NEVER REBUILT PER RUN (cfo: a parent build in a scratch worktree is 7 min 19 s at load 20): its outputs are CAPTURED ONCE, from the build that
# stands before the change is made, into SCRIP/out/ir_identity/<git-short-head>/<lang>/ (out/ is untracked build output), and the changed build is compared to a
# captured directory.
# USAGE
#   bash ../harness/scripts/test_gate_bootstrap_parse_stage_ir_identity.sh --capture [--lang snobol4] [--population sample|corpus]   record the CURRENT build as a parent
#   bash ../harness/scripts/test_gate_bootstrap_parse_stage_ir_identity.sh [--against DIR|latest] [--lang snobol4] [--population sample|corpus] [--list-diffs FILE] [--only FILE]   compare the CURRENT build to it
#   bash ../harness/scripts/test_gate_bootstrap_parse_stage_ir_identity.sh --both [--lang snobol4] [--population sample|corpus] [--list-diffs FILE] [--only FILE]   ONE BUILD: every file compiled under SCRIP_PARSE_STAGE=c and again under =sc, the two readings compared (the honest reading; the coo can run it, it sets its own stage)
#   --list-diffs FILE writes EVERY differing corpus-relative path (the console shows the first five); --only FILE re-runs just the paths listed in FILE.
#   A file that times out (GATE_TIMEOUT, default 120 s, a loaded machine) is re-run ALONE at GATE_TIMEOUT_ALONE (900 s) before it counts; one that still times out is recorded as rc=124
#   with empty outputs on both sides, which compare equal -- a timeout is a measurement, never a difference.
# EMBEDDED DATES: a program with a listing header prints the compile wall-clock time into its output (x86-64  Thu Oct  8 21:13:33 2026); both halves are normalised to <DATE> before they are stored or compared, or those files differ from themselves.
# CONTROL ARM: run it against a capture taken from a build of the SAME sources (or a behaviour-neutral change, e.g. a whitespace re-flow); it must read green, or
# it proves nothing. rc 0 = every measured file identical; rc 1 = a difference (the first five are printed with their first differing line); rc 2 = could not
# measure (no scrip, no capture, empty population, a capture taken from another population). Serial, under nice 19 (lib_fanout.sh, CEO-1333). Not wired into
# make test or make preflight: it needs a capture, and its full-corpus pass is minutes, not seconds (preflight's arm ceiling is 5 s); the stage-1 row's DONE-WHEN
# calls it by name once it exists.
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; CORPUS="${CORPUS:-$S4E/corpus}"
refuse() { echo "⛔ GATE REFUSE(2) [$G]: $*"; exit 2; }
MODE=compare; AGAINST=latest; LANGS=snobol4; POP=sample; ONLY=""; DIFFS_OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --capture) MODE=capture ;;
    --both) MODE=both ;;
    --against) AGAINST="${2:-}"; shift ;;
    --lang) LANGS="${2:-}"; shift ;;
    --population) POP="${2:-}"; shift ;;
    --only) ONLY="${2:-}"; shift ;;
    --list-diffs) DIFFS_OUT="${2:-}"; shift ;;
    *) refuse "unknown argument '$1'" ;;
  esac
  shift
done
[ -x "$SCRIP" ] || refuse "no scrip at $SCRIP (make)"
# --no-behaviour: the freshness probe --compiles pinned witnesses and hashes what the build EMITS, and under SCRIP_PARSE_STAGE=sc the emitted
# text legitimately differs from the C stage's -- that difference is exactly what THIS gate measures, so the probe read every =sc compare as "the
# binary moved under a tree that did not" (hq_snocone 2026-10-14: three refusals on three captures, one of them a pristine build). The mtime half stays.
"$HERE/util_require_fresh.sh" --gate "$G" --no-behaviour || exit $?
[ "$POP" = sample ] || [ "$POP" = corpus ] || refuse "population must be sample or corpus"
[ -d "$CORPUS" ] || refuse "no corpus at $CORPUS"
STORE="$ROOT/out/ir_identity"
TMO="${GATE_TIMEOUT:-120}"; TMO_ALONE="${GATE_TIMEOUT_ALONE:-900}"
HEAD_SHORT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo nohead)"
declare -A EXTS=([snobol4]="sno spt sbl" [snocone]="sc" [icon]="icn" [prolog]="pl" [rebus]="reb" [pascal]="pas" [raku]="raku")
files_of() {
  local lang="$1" base="$CORPUS" e args=()
  [ "$POP" = sample ] && base="$CORPUS/benchmarks/$lang"
  [ -d "$base" ] || return 0
  for e in ${EXTS[$lang]}; do args+=(-o -name "*.$e"); done
  find "$base" -type f \( "${args[@]:1}" \) -not -path '*/.git/*' -not -path "$CORPUS/library/*" -not -name 'ALL.*' | LC_ALL=C sort
}
one() {
  local f="$1" out="$2" d b
  d="$(dirname "$f")"; b="$(basename "$f")"
  mkdir -p "$(dirname "$out")"
  ( cd "$d" && export SNO_LIB="$CORPUS/include"
    r=0; timeout -k 5 "$TMO" nice -n 19 "$SCRIP" --dump-ir "$b" < /dev/null > "$out.ir" 2>/dev/null || r=$?
    [ "$r" = 124 ] && { r=0; timeout -k 5 "$TMO_ALONE" nice -n 19 "$SCRIP" --dump-ir "$b" < /dev/null > "$out.ir" 2>/dev/null || r=$?; }
    [ "$r" = 124 ] && : > "$out.ir"
    echo "rc=$r" >> "$out.ir"
    r=0; timeout -k 5 "$TMO" nice -n 19 "$SCRIP" --compile -o "$out.s" "$b" < /dev/null > /dev/null 2>&1 || r=$?
    [ "$r" = 124 ] && { r=0; rm -f "$out.s"; timeout -k 5 "$TMO_ALONE" nice -n 19 "$SCRIP" --compile -o "$out.s" "$b" < /dev/null > /dev/null 2>&1 || r=$?; }
    [ "$r" = 124 ] && rm -f "$out.s"
    echo "rc=$r" > "$out.rc"
    [ -f "$out.s" ] || : > "$out.s"
    sed -E -i "s/[A-Z][a-z]{2} [A-Z][a-z]{2} +[0-9]{1,2} [0-9]{2}:[0-9]{2}:[0-9]{2} [0-9]{4}/<DATE>/g" "$out.ir" "$out.s" )
}
total=0; same=0; diff=0; shown=0
for lang in $LANGS; do
  [ -n "${EXTS[$lang]:-}" ] || refuse "no extension list for language '$lang'"
  mapfile -t FILES < <(files_of "$lang")
  if [ -n "$ONLY" ]; then mapfile -t FILES < <(for f in "${FILES[@]}"; do grep -qxF "${f#$CORPUS/}" "$ONLY" && echo "$f"; done); fi
  [ "${#FILES[@]}" -gt 0 ] || refuse "empty population for $lang ($POP)"
  if [ "$MODE" = capture ]; then
    D="$STORE/$HEAD_SHORT/$lang/$POP"; [ -n "$ONLY" ] || rm -rf "$D"; mkdir -p "$D"
    for f in "${FILES[@]}"; do one "$f" "$D/${f#$CORPUS/}"; total=$((total+1)); done
    printf '%s\n' "$HEAD_SHORT" > "$STORE/LATEST.$lang.$POP"
    echo "CAPTURED $total file(s) of $lang ($POP) from the build at git $HEAD_SHORT into $D"
    continue
  fi
  if [ "$MODE" = both ]; then
    T="$(mktemp -d)" || exit 2; trap 'rm -rf "$T"' EXIT
    for f in "${FILES[@]}"; do
      rel="${f#$CORPUS/}"; total=$((total+1))
      export SCRIP_PARSE_STAGE=c; one "$f" "$T/c/$rel"
      export SCRIP_PARSE_STAGE=sc; one "$f" "$T/sc/$rel"
      if cmp -s "$T/c/$rel.ir" "$T/sc/$rel.ir" && cmp -s "$T/c/$rel.s" "$T/sc/$rel.s" && cmp -s "$T/c/$rel.rc" "$T/sc/$rel.rc"; then same=$((same+1)); rm -f "$T/c/$rel".* "$T/sc/$rel".*; continue; fi
      diff=$((diff+1)); [ -n "$DIFFS_OUT" ] && echo "$rel" >> "$DIFFS_OUT"
      if [ "$shown" -lt 5 ]; then
        shown=$((shown+1)); echo "DIFF $rel"
        for h in ir s rc; do cmp -s "$T/c/$rel.$h" "$T/sc/$rel.$h" || { echo "  first differing $h line (C stage < > module stage):"; diff "$T/c/$rel.$h" "$T/sc/$rel.$h" | sed -n '2p;4p' | cut -c1-160 | sed 's/^/    /'; }; done
      fi
      rm -f "$T/c/$rel".* "$T/sc/$rel".*
    done
    unset SCRIP_PARSE_STAGE; P="one build (C stage captured, module stage compared)"
    continue
  fi
  if [ "$AGAINST" = latest ]; then [ -f "$STORE/LATEST.$lang.$POP" ] || refuse "no capture for $lang ($POP): run with --capture on the PARENT build first"; P="$(cat "$STORE/LATEST.$lang.$POP")"; else P="$AGAINST"; fi
  D="$STORE/$P/$lang/$POP"; [ -d "$D" ] || refuse "no capture directory $D"
  T="$(mktemp -d)" || exit 2; trap 'rm -rf "$T"' EXIT
  for f in "${FILES[@]}"; do
    rel="${f#$CORPUS/}"; total=$((total+1))
    [ -f "$D/$rel.ir" ] || refuse "the capture $D does not hold $rel (a capture of another population?)"
    one "$f" "$T/$rel"
    if cmp -s "$D/$rel.ir" "$T/$rel.ir" && cmp -s "$D/$rel.s" "$T/$rel.s" && cmp -s "$D/$rel.rc" "$T/$rel.rc"; then same=$((same+1)); continue; fi
    diff=$((diff+1)); [ -n "$DIFFS_OUT" ] && echo "$rel" >> "$DIFFS_OUT"
    if [ "$shown" -lt 5 ]; then
      shown=$((shown+1)); echo "DIFF $rel"
      for h in ir s; do cmp -s "$D/$rel.$h" "$T/$rel.$h" || { echo "  first differing $h line:"; diff "$D/$rel.$h" "$T/$rel.$h" | sed -n '2p;4p' | cut -c1-160 | sed 's/^/    /'; }; done
    fi
    rm -f "$T/$rel".*
  done
done
[ "$MODE" = capture ] && exit 0
echo "IR-IDENTITY [$LANGS $POP] against git $P: $total file(s), $same identical, $diff differ"
[ "$total" -gt 0 ] || refuse "nothing was measured"
[ "$diff" -eq 0 ] && { echo "PASS: the parse stage's consumers produce exactly what the parent's produced"; exit 0; }
echo "FAIL: $diff file(s) lower or emit differently from the parent"; exit 1
