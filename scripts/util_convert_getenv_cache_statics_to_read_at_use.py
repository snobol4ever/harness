#!/usr/bin/env python3
# util_convert_getenv_cache_statics_to_read_at_use.py -- mechanical conversion for ONE shape out of
# the census-function-scope-mutable-statics-under-src row: the `static TYPE name = -1; if (name<0)
# { ...name = getenv(...)... }` lazy-init-cache idiom.
#
# ⛔⛔ SCOPE RE-CUT 2026-09-02: THIS SCRIPT'S DEFAULT `target_offsets()` STILL TARGETS THE COMPILE-TIME
# DIRS (emitter/lower/ir/driver/optimizer/templates/parsers) AND SKIPS src/runtime/ -- THAT POPULATION IS
# NOW ENTIRELY OUT OF SCOPE (ceo ruling, routed hq_B: compile-time working state was never covered by the
# no-new-globals law; see RULES.md line 169's clarification and the task baton's SCOPE RE-CUT). Running
# this script's --apply against compile-time dirs again would rebuild the discarded batch -- don't.
# Salvage record of what was built, verified, and then discarded: /home/resources/postoffice/salvage/
# seat07-census-function-scope-mutable-statics-under-src-compile-time-DISCARDED-2026-09-02.patch
#
# ⛔ AND A CAUTIONARY FINDING FROM THAT DISCARDED RUN, worth keeping even though the population changed:
# every one of the 270 converted sites was independently verified to be a pure textual `static` deletion
# with no other line touched, and the transform's own reasoning (below) held for 269 of them -- but the
# bulk-applied batch still measurably broke SNOBOL4 corpus witness pos_rpos_alt_branch_5 with a
# deterministic runtime ERROR 246 stack overflow, bisected cleanly to this conversion (pre-conversion tree
# 2/2 clean, converted tree 3/3 broken). Root cause not fully traced; plausibly one of bb_match_defer.cpp's
# getenv-cache flags selecting an inconsistent code-generation strategy across that function's two
# compile-time invocations for a self-referential deferred pattern. THE LESSON: "the transform is provably
# safe in isolation" is not the same claim as "270 simultaneous applications of it are safe" -- if this
# script is ever reused (with target_offsets() repointed at a measured-safe runtime population), verify
# each converted batch against the full corpus board before trusting it, not just the sites' own diffs.
#
# The SCOPE GUARD this population split was originally reasoning from still applies to why src/runtime/
# needs care even once in scope: it becomes libscrip_rt.so and is executed by COMPILED PROGRAMS at THEIR
# runtime, where re-reading getenv() on every call is a real cost paid by someone else's program, not a
# one-time compile cost -- "do NOT convert a static that ... is load-bearing in a HOT RUNTIME path just to
# satisfy the census". Generated parser/lexer files (*.tab.c, *.lex.c) and *_test.c fixtures are excluded
# too -- the first because hand-editing generated output is the wrong layer to fix anything in, the second
# because they are not shipped code.
#
# THE TRANSFORM IS DELETION, NOTHING ELSE: `static int _zd = -1; if (_zd < 0) { _zd = ...; }` behaves
# identically with `static` removed -- `_zd` still starts at -1 and the guard still fires and sets it,
# just on every CALL/every loop iteration instead of once ever. That is exactly "read at the point of
# use" (ceo ruling, RULES.md line 169's clarification): the cache bought nothing a board can measure at
# compile time, and removing `static` is a pure storage-duration change, not a logic change -- no other
# text is touched. Each target's exact byte offset comes from util_census_function_scope_statics.py's
# scanner (the SAME instrument this row's census was built and verified on), so this never re-derives
# "where is `static`" by a second, potentially-disagreeing text search.
import sys, os, re

sys.path.insert(0, os.path.dirname(__file__))
import util_census_function_scope_statics as u

GENERATED_SUFFIXES = ('.tab.c', '.lex.c')

def is_getenv_cache(rel, lineno, name, file_lines_cache, root):
    if rel not in file_lines_cache:
        file_lines_cache[rel] = open(os.path.join(root, rel), encoding='utf-8', errors='replace').read().split('\n')
    lines = file_lines_cache[rel]
    window = '\n'.join(lines[max(0, lineno - 1):lineno + 2])
    return 'getenv(' in window and re.search(r'\b' + re.escape(name) + r'\b\s*=', window)

def target_offsets(root):
    results = u.census(root)
    mutable = [r for r in results if r[3].startswith('MUTABLE')]
    file_lines_cache = {}
    by_file = {}          # rel -> {static_offset: (lineno, [names])}
    skipped_runtime = []
    for rel, lineno, name, verdict, decl_text, static_offset in mutable:
        if rel.endswith(GENERATED_SUFFIXES) or '_test.c' in rel:
            continue
        if not is_getenv_cache(rel, lineno, name, file_lines_cache, root):
            continue
        if rel.startswith('runtime' + os.sep) or rel.startswith('runtime/'):
            skipped_runtime.append((rel, lineno, name))
            continue
        # ⛔ BUG FOUND BY THE APPLIER'S OWN SANITY CHECK (first dry run): several comma-joined
        # declarators under ONE `static` keyword -- `static int _zd=-1, _dg=-1, ...;` -- share the
        # SAME static_offset (one keyword, N declarators). Recording one entry per DECLARATOR and
        # then removing "static" once per entry tried to delete the same 6 bytes multiple times;
        # the second attempt landed on text the first removal had already shifted left and refused
        # (loudly, per the two-part-proof discipline -- it never silently corrupted anything).
        # Fix: dedupe by (rel, static_offset) -- one keyword, one removal, regardless of how many
        # names hang off it.
        by_file.setdefault(rel, {}).setdefault(static_offset, (lineno, []))[1].append(name)
    return by_file, skipped_runtime

def apply(root, by_file, dry_run):
    total = 0
    for rel in sorted(by_file):
        path = os.path.join(root, rel)
        raw = open(path, encoding='utf-8', errors='replace').read()
        offsets = sorted(by_file[rel].items(), key=lambda kv: -kv[0])  # descending: edit from the end first
        new = raw
        applied_here = 0
        for static_offset, (lineno, names) in offsets:
            word = new[static_offset:static_offset + 6]
            if word != 'static':
                print(f'⛔ REFUSED {rel}:{lineno} ({",".join(names)}): offset {static_offset} does not read '
                      f'"static" (reads {word!r}) -- unexpected text at this offset. Skipping this site; '
                      f're-run the census fresh and retry.', file=sys.stderr)
                continue
            # Remove "static" plus exactly ONE following space (never a newline/tab -- those carry
            # the surrounding formatting and this codebase's own style is one-space-after-keyword),
            # so `void) { static int on` becomes `void) { int on`, not `void) {  int on` with an
            # orphaned double space. Only ever a single ASCII space qualifies for removal here.
            cut = static_offset + 6
            if cut < len(new) and new[cut] == ' ':
                cut += 1
            new = new[:static_offset] + new[cut:]
            applied_here += 1
        if applied_here:
            total += applied_here
            print(f'{rel}: {applied_here} keyword(s) removed' + (' (dry-run, not written)' if dry_run else ''))
            if not dry_run:
                open(path, 'w', encoding='utf-8').write(new)
    return total

def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', default=os.path.join(os.path.dirname(__file__), '..', 'src'))
    ap.add_argument('--apply', action='store_true', help='write changes (default is dry-run, report only)')
    args = ap.parse_args()
    root = os.path.abspath(args.root)
    by_file, skipped_runtime = target_offsets(root)
    total_decls = sum(len(names) for offs in by_file.values() for lineno, names in offs.values())
    total_keywords = sum(len(offs) for offs in by_file.values())
    print(f'=== getenv-cache -> read-at-use conversion ({"APPLY" if args.apply else "DRY RUN"}) ===')
    print(f'target declarators (compile-time dirs only): {total_decls} '
          f'({total_keywords} distinct `static` keywords) across {len(by_file)} files')
    print(f'skipped (runtime/ -- perf-sensitive, needs individual review, NOT auto-converted): {len(skipped_runtime)}')
    print()
    applied = apply(root, by_file, dry_run=not args.apply)
    print(f'\n{"wrote" if args.apply else "would write"} {applied} site(s)')
    return 0

if __name__ == '__main__':
    sys.exit(main())
