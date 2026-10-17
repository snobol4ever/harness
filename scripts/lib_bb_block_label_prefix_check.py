#!/usr/bin/env python3
"""lib_bb_block_label_prefix_check.py -- worker for test_gate_bb_block_label_prefix.sh (row
bb-label-prefix-uniform). See that script's header for the ruling this enforces; this file is the
bracket-and-check walk, kept separate so it stays independently testable
(`python3 lib_bb_block_label_prefix_check.py some.s`, prints violations, exit 0/1).

MERGED DESIGN (seat02 2026-08-29, per hq_P's task-LEDGER ruling "SEAT11 COLLISION ADJUDICATED ... THE
RULING: MERGE, DO NOT PICK"): bracketing/ownership-tracking below is seat11's classify() (recovered at
`git show 57ecf03e:../harness/scripts/test_gate_bb_block_label_prefix.sh`) -- it treats a bareword Greek-suffixed
landing pad with no "n<uid>_" prefix (PATTERN_BT_α, a DEFINE'd proc's own by-name entry point,
bb_define.cpp) as PRESERVING the enclosing box's identity rather than opening a new block. seat05's
original bracketing here treated any "<word>_<greek>" as a new owner and false-flagged 7 labels on the
pattern_bt.sno witness (measured, hq_P: "NO n<digits>_<kind>_<greek> box port opens between n47_define_*
and n48_statement_end_α -- the whole span is one box's output"). seat11's classifier, unmodified, does
NOT enforce a Greek letter on the _as/_af/_ry/_rt/_s<N> port-target families at all (ceo-endorsed
2026-08-29c: these ARE real box-owned gamma/omega jump targets -- emit.cpp node_γ/node_ω assignment at
~3074/3090/1398/3095 -- not siblings of the exempt _bx range-marker), so that requirement is added below
as its OWN independent check, per hq_P's explicit "add seat05's greek requirement ... as a clearly
separated second check" -- not folded into the bracketing walk, so neither arm's logic has to reason
about the other.

⛔ UTF-8 DISCIPLINE (RULES.md INSTRUMENT LAW #15, this row's own census tool header, seat03 2026-08-29):
match on decoded Greek characters, never their UTF-8 byte sequence via an ASCII-only regex -- that class
of bug already cost this row one full false census once.
"""
import re
import sys

GREEK = "αβγω"  # α β γ ω
GREEK_SET = set(GREEK)
LABEL_DEF = re.compile(r'^([^\s:]+):(?:\s|$)')
# A real box port: "n<uid>_<kind>_<greek>" (emit_label_alloc("n%d_%s_<greek>", uid, kind)). kind may
# itself contain underscores ("match_alternate"), so it is everything between the uid and the final
# Greek segment -- NOT split on the kind's own underscores (that produced a phantom "kind='BT'" block on
# an earlier version of this script, caught testing against pattern_bt.sno; PATTERN_BT has no uid prefix
# at all, see BAREWORD_GREEK below).
PORT_LABEL = re.compile(r'^n(\d+)_(.+)_([' + GREEK + r'])$')
BOXFAM = re.compile(r'^n\d+_')                                   # this box's OWN family (_bx/_as/_af/...)
BAREWORD_GREEK = re.compile(r'^[A-Za-z_][A-Za-z0-9_$]*_([' + GREEK + r'])$')
FAMILY_SUFFIX = re.compile(r'_(as|af|ry|rt|s\d+)$')               # the port-target families needing Greek

# Ruled exempt (ceo 2026-08-29b/c, hq_P 2026-08-29 -- mechanism test: "a greek infix names a PORT OF A
# BOX; a label with no owning box has no port, so the infix would not be redundant, it would be FALSE").
# Carried over unchanged from the pre-merge gate's allowlist, same citations -- an allowlist entry is a
# claim, not a convenience; don't add one here without a citation and a task-LEDGER entry.
EXEMPT = [
    (re.compile(r'^n\d+_[A-Za-z0-9_]+_bx$'),
     "box-span ELF .type@function/.size debug marker (emit.cpp bxs[], ~line 2977) -- spans the box's "
     "entire range, never a jump target; ceo-ruled exempt 2026-08-29b"),
    (re.compile(r'^\.S\d+$'),
     "module-level string dedup table (emit.cpp strtab_label) -- shared across boxes, no single owner; "
     "ceo-ruled exempt 2026-08-29b"),
    (re.compile(r'^\.C\d+$'),
     "module-level cset dedup table (emit.cpp csettab_label) -- same as .S<N>; ceo-ruled exempt"),
    (re.compile(r'^(RETURN|FRETURN|NRETURN)$'),
     "per-function shared exit label (emit.cpp emit_floater_label) -- one level above any single box; "
     "ceo-ruled exempt 2026-08-29b"),
    (re.compile(r'^FN__'),
     "function/graph entry point, called from outside the graph -- same class as RETURN-family; "
     "ceo-ruled exempt 2026-08-29b"),
    (re.compile(r'^[A-Za-z_][A-Za-z0-9_$]*_res$'),
     "per-function result-cell label -- same function-level class as RETURN/FN__"),
    (re.compile(r'^(main|module_init|__gva_names)$'),
     "program-level entry/init/table symbols -- same function/module-level class as RETURN/FN__/.S/.C"),
    (re.compile(r'^[A-Za-z_][A-Za-z0-9_$]*_α_body$'),
     "function/graph body-entry label (emit.cpp lbl_α_body, fam is the GRAPH name, ~line 2665) -- one "
     "level above any box"),
    (re.compile(r'^\.Lgvan\d+$'),
     "driver-level GVA name table (src/driver/scrip.c, not any bb_*/xa_*/emit.cpp box loop) -- no owning "
     "box, no port to name; hq_P 2026-08-29, ceo-endorsed"),
    (re.compile(r'^\.Lstartup_(pname|prec|pnames)\d+$'),
     "driver-level per-procedure startup/reflection table (src/driver/scrip.c) -- same ruling as .Lgvan"),
    (re.compile(r'^\.Lseala\d+$'),
     "driver-level rt_proc_seal_alpha startup table (src/driver/scrip.c) -- same ruling as .Lgvan"),
    (re.compile(r'^\.Lgcmap_'),
     "the collector's frame map for a graph or thunk (emit.cpp emit_label_initf \".Lgcmap_%s\", ~line 3292), .quad data emitted "
     "after the graph's omega in the text section -- a MODULE DATUM with no owning box; ceo 2026-09-30, CEO-1380"),
    (re.compile(r'^\.Lgcsites_'),
     "the collector's per-graph site table (emit.cpp emit_gc_sites_data, \".Lgcsites_<fam>_<n>\", ARCH-GC section 13.3), .quad data "
     "emitted after the graph's omega in the text section beside .Lgcmap_ -- a MODULE DATUM with no owning box, CEO-1380's class; cto 2026-10-07"),
    (re.compile(r'^\.Lgcsite_'),
     "a poll site's return-PC marker (x86_asm.h x86_gc_site_adj/x86_gc_site_raw, emit.cpp emit_gc_site_label), a recording label the "
     "site table reads as data and nothing jumps to -- the _bx class (a marker, never a jump target); the unmapped-store census "
     "drops it at parse for the same reason; cto 2026-10-07, after 6ec5871c8 put 95+ of them in this gate's red"),
]
ENTRY = re.compile(r'^(FN__|main$|module_init$|__gva_names$|[A-Za-z_][A-Za-z0-9_$]*_α_body$)')


def exempt(name):
    for pat, _why in EXEMPT:
        if pat.match(name):
            return True
    return False


# .pushsection is a section switch like .section, and .popsection returns to whatever section was pushed from, so the
# walk keeps a stack (cfo 2026-10-02): the statement code map's file-name string .Lstnof<N> sits in a .pushsection .rodata
# interlude inside a box, and before the stack it read as a text label of that box -- one false violation per SNOBOL4 file.
SECTION_DIRECTIVE = re.compile(r'^\s*\.(?:(push)?section\s+(\S+)|(text|data|rodata|bss|previous|popsection))\b')
# The box-span marker "n<uid>_<kind>_bx:" (emit.cpp, the ".type %s, @function" line the flat loop writes ahead of each box)
# opens its box: everything up to its .size is that box's output. A label a box defines AHEAD of its own α port -- the
# statement code map's anchor ".L<kind>_α_<uid>_stno" (emit.cpp emit_stno_mark, written before the template's α) -- is
# read against its own box, not the box before it (cfo 2026-10-02: 59 programs in seven languages, the only labels whose
# verdict moved were the code-map anchors). Still exempt from the naming check: a range marker, never a jump target.
BOX_SPAN = re.compile(r'^n\d+_(.+)_bx$')
# ...and its ".size n<uid>_<kind>_bx, .-n<uid>_<kind>_bx" closes it: the code after it until the next box opens (a graph's
# own beta/gamma/omega and <fam>_res result paths, which restore g_line/g_file under .L<fam>_α_<uid>_<n> labels named for the
# PROCEDURE) is owned by no box, so it is not charged to the box that closed (cto 2026-10-07: generators.icn read eleven such
# labels as line_mark's and call_icon's).
BOX_CLOSE = re.compile(r'^\s*\.size\s+n\d+_.+_bx\s*,')


def classify(name):
    """('anchor', kind) opens a new block; 'preserve' leaves the current owner unchanged; 'reset' clears
    it (genuinely no box owner here); 'data' is content, checked against the current owner."""
    pm = PORT_LABEL.match(name)
    if pm:
        return 'anchor', pm.group(2)
    if BOXFAM.match(name):
        return 'preserve', None            # n<uid>_<kind>_bx/_as/_af/_ry/_rt/_s<N>: already self-owned
    if not name.startswith('.'):
        if BAREWORD_GREEK.match(name):
            return 'preserve', None        # PATTERN_BT_α / Push_γ: a by-name landing pad embedded inside
                                            # the currently-dispatching box's own output (bb_define.cpp
                                            # composes these from the proc name, not the n<uid>_<kind>
                                            # port loop) -- not a new box scope. SEAT11 COLLISION (task
                                            # LEDGER): measured on pattern_bt.s, requiring these to open
                                            # their own block false-flags the enclosing box's real content.
        return 'reset', None               # module_init, a bare proc/label name, ...: no box owner here
    return 'data', None


# One line can hold several statements joined by ';' (GAS's separator; the 4-column formatter joins a jump onto the line before
# it, and a literal cell is ONE line: ".pushsection .data.rel.ro,...; .p2align 3; <cell>: .quad <target>; .popsection", cto
# 2026-10-15, the text-relocation row): walk them in order, outside a quoted string, up to a '#' comment.
def statements(line):
    out, cur, q, esc = [], [], False, False
    for ch in line:
        if q:
            cur.append(ch)
            if esc:
                esc = False
            elif ch == '\\':
                esc = True
            elif ch == '"':
                q = False
        elif ch == '"':
            q = True
            cur.append(ch)
        elif ch == ';':
            out.append(''.join(cur))
            cur = []
        elif ch == '#':
            break
        else:
            cur.append(ch)
    out.append(''.join(cur))
    return out


def check(path):
    violations = []
    greek_missing = []
    owner = None
    n_checked = 0
    in_text = True
    pushed = []

    def section(sm):
        # A label defined in a non-text section is a MODULE DATUM (the thunk record .Lthk_<pat> and the frame map
        # .Lgcmap_<pat> in .data.rel.ro, the label-name table .Llbln<N>, the Icon startup tables .Lstartup_*): it has no
        # owning box, so the Greek infix would be false, not redundant -- the header's own mechanism test. The emitter
        # returns to .text and continues the block it was in, so the owner is kept across the interlude (ceo 2026-09-30,
        # CEO-1380: 59 such labels read as violations after the stored-pattern landings moved the data emission).
        nonlocal in_text
        if sm.group(1):
            pushed.append(in_text)
        if sm.group(3) == 'popsection':
            in_text = pushed.pop() if pushed else True
            return
        sec = (sm.group(2) or sm.group(3) or '').strip()
        in_text = sec in ('text', '.text', 'previous') or sec.startswith('.text')

    def visit(lineno, name):
        nonlocal owner
        if FAMILY_SUFFIX.search(name) and not (GREEK_SET & set(name)):
            greek_missing.append((lineno, name))
        if exempt(name):
            if ENTRY.match(name):
                owner = None
            bm = BOX_SPAN.match(name)
            if bm:
                owner = bm.group(1)
            return
        kind, new_owner = classify(name)
        if kind == 'anchor':
            owner = new_owner
        elif kind == 'reset':
            owner = None
        elif kind == 'data':
            if owner is not None and owner not in name:
                violations.append((lineno, name, owner))
        # 'preserve': owner unchanged, not checked
    with open(path, encoding='utf-8') as f:
        for lineno, line in enumerate(f, 1):
            for si, seg in enumerate(statements(line.rstrip('\n'))):
                if si:
                    seg = seg.lstrip()
                sm = SECTION_DIRECTIVE.match(seg)
                if sm:
                    section(sm)
                    continue
                if in_text and BOX_CLOSE.match(seg):
                    owner = None
                    continue
                m = LABEL_DEF.match(seg)
                if not m:
                    continue
                n_checked += 1
                if in_text:
                    visit(lineno, m.group(1))
                sm = SECTION_DIRECTIVE.match(seg[m.end():])
                if sm:
                    section(sm)             # "label: .pushsection X" defines the label where it stands, THEN switches
    return violations, greek_missing, n_checked


def main(argv):
    if len(argv) != 1:
        print("usage: lib_bb_block_label_prefix_check.py file.s", file=sys.stderr)
        return 2
    violations, greek_missing, n_checked = check(argv[0])
    ok = True
    if violations:
        ok = False
        print(f"⛔ {len(violations)} label(s) inside a block not carrying that block's own owner, in {argv[0]}:", file=sys.stderr)
        for lineno, name, owner in violations[:40]:
            print(f"    line {lineno}: {name}  (inside block owner={owner!r})", file=sys.stderr)
        if len(violations) > 40:
            print(f"    ... and {len(violations) - 40} more", file=sys.stderr)
    if greek_missing:
        ok = False
        print(f"⛔ {len(greek_missing)} port-target label(s) missing a Greek letter (_as/_af/_ry/_rt/_s<N> family, ceo-endorsed 2026-08-29c), in {argv[0]}:", file=sys.stderr)
        for lineno, name in greek_missing[:40]:
            print(f"    line {lineno}: {name}", file=sys.stderr)
        if len(greek_missing) > 40:
            print(f"    ... and {len(greek_missing) - 40} more", file=sys.stderr)
    print(n_checked)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
