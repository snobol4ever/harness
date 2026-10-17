#!/usr/bin/env python3
"""util_gc_census.py -- THE COLLECTOR GUESSES NOTHING: the census instruments (coo, CEO-813/814/815, 2026-09-17;
row gc-instruments-the-safe-point-census-the-maps-census-and-scrip-gc-coverage-words-scanned-zero-are-wired-gates;
design .github/ARCH-GC-COMPILE-TIME-FRAME-MAPS.md, law RULES.md FACT RULE THE COLLECTOR GUESSES NOTHING).

Five censuses, each a mechanical count printed with its population, each RED until the design lands and each proven
to trip on a planted violation by --selftest (39 arms, the ratchet included):

  conservative   src/runtime/rt/gc_heap.c: call sites of the word walker gc_zeta_frame(, uses of cons_stack, of
                 rt_cas_live_span and of hb_scan_interior (Rule 2, Rule 2b).  Want 0 each.
  allocator      rt_gc_collect( inside rt_gcheap_alloc's body (Rule 3: the allocator never collects).  Want 0.
  safe-points    every ALLOCATING runtime entry the emitter calls has a g_gc_pending poll at its emitted return.  The
                 allocating set is read from the runtime binary's own call graph (objdump: every function that reaches
                 rt_gcheap_alloc), never from a hand list; the emitter's call sites are the literal x86("call", "sym")
                 strings in src/templates and src/emitter; a poll is a g_gc_pending reference (or a helper named in
                 --poll-helper) within --poll-window source lines after the call.  Want unpolled 0 and unresolved 0.
  coverage       a run under SCRIP_GC_STRESS=64 SCRIP_GC_COVERAGE=1 prints [GC-COV] lines; every line must carry BOTH
                 words_scanned=0 (stack and spine words visited without a map, Rule 2) and interior_words=0 (mark-
                 worklist payload words visited by the same sniff, Rule 2b).  A line without a token is RED (the
                 design's field is not there yet); no line at all is rc=2 (no collection ran: not measured).  The two
                 spellings are FROZEN -- the cfo's walker row prints them, this census only counts them.
  callbacks      TWO DIRECTIONS, each with its own denominator, both printed.  INBOUND: every call into the by-name
                 dispatcher (the rt_call_* family) from a runtime frame.  OUTBOUND: every call OUT of the runtime
                 into emitted code through the apply / user-call hook chain -- CEO-836's gdb crash class, where the
                 raw heap `const char *fn` is live across `APPLY_fn(fn, args, nargs)` and comes back reading "\003".
                 The scope is DERIVED (every .c/.h under src/runtime and src/driver), the inbound set is derived by
                 name shape, the OUTBOUND set is DECLARED and says so, and a declared symbol that has vanished from
                 the tree REFUSES rc=2 rather than report a stale zero.  Both must sit inside RT_GC_CALLBACK(
                 (Rule 4; the marker is the cfo's to confirm) -- and whether that marker is DEFINED in the tree at
                 all is printed beside the count, because wrapped=0 with no definition is not progress pending.
                 Want unwrapped 0 on both.
  maps           TWO HALVES, printed and graded separately, because a green slot-kind half beside an absent table would
                 read as if the design existed.  SLOT-KIND: the ceo's util_zls_frame_map_census.py over each language's
                 rungs (token frozen CEO-821), want unkinded=0 and holes=0, with no_layout NAMED beside the number and
                 never folded into it; the wire header past region_end and the spine are NAMED as not censused here
                 (section 2b makes the spine tagged cells, so its census is the tag census, not a hole count).
                 TABLE: section 6.4, from three independent producers per witness -- the frame allocator (--dump-zeta),
                 the emitter (SCRIP_GC_MAPS_REPORT=1, BOTH media) and the assembler text (.Lgcmap_* labels, their
                 prologue leas, the counted __gc_frame_maps table and each map's four decoded quads).  REFUSES rc=2
                 while gc_heap.c defines no rt_gc_frame_maps_install.

rc: 0 every census green; 1 any census red; 2 a census could not measure (missing file, no binary, no collection).
Every count is printed as `CENSUS <name> ... want=...` so a reader re-derives the population, never only the verdict.
"""
import argparse, collections, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "SCRIP"))

CONSERVATIVE_TOKENS = [  # (label, regex, what the design says)
    ("gc_zeta_frame_calls", r"(?<![A-Za-z0-9_])gc_zeta_frame\s*\(", "the word walker (Rule 2: DELETED, not gated)"),
    ("cons_stack_uses", r"(?<![A-Za-z0-9_])cons_stack(?![A-Za-z0-9_])", "the conservative stack scan flag (Rule 2)"),
    ("rt_cas_live_span_uses", r"(?<![A-Za-z0-9_])rt_cas_live_span(?![A-Za-z0-9_])", "the byte scan of the cas span (Rule 2)"),
    ("hb_scan_interior_uses", r"(?<![A-Za-z0-9_])hb_scan_interior(?![A-Za-z0-9_])", "the heap-interior sniff (Rule 2b: typed visitors)"),
]


def strip_comments(src):
    src = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), src, flags=re.S)
    return re.sub(r"//[^\n]*", "", src)


def census_conservative(path, out=print):
    if not os.path.exists(path):
        out(f"CENSUS conservative REFUSED(2): {path} missing"); return 2
    src = strip_comments(open(path, encoding="utf-8", errors="replace").read())
    red = 0
    for label, rx, why in CONSERVATIVE_TOKENS:
        hits = []
        for i, line in enumerate(src.split("\n"), 1):
            for _m in re.finditer(rx, line):
                if label == "gc_zeta_frame_calls" and re.search(r"(static\s+)?(void|long)\s+gc_zeta_frame\s*\(", line):
                    continue   # the definition / prototype is not a call site
                hits.append(i)
        n = len(hits)
        out(f"CENSUS conservative {label}={n} want=0 -- {why}" + (f"; lines {hits[:12]}" if n else ""))
        COUNTS.setdefault("conservative", {})[label] = n
        red += n
    out(f"CENSUS conservative total={red} want=0 {'GREEN' if red == 0 else 'RED'}")
    return 0 if red == 0 else 1


def function_body(src, name):
    """the brace-matched body of C function `name` (first definition), or None"""
    m = re.search(r"(?<![A-Za-z0-9_])" + re.escape(name) + r"\s*\([^;{]*\)\s*\{", src)
    if not m:
        return None
    i = m.end() - 1; depth = 0
    for j in range(i, len(src)):
        if src[j] == "{": depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0:
                return src[i:j + 1]
    return None


COUNTS = {}   # census -> {key: count}; the ratchet reads these, never the printed prose


ALLOCATOR_SPELLINGS = ("c_rt_gcheap_alloc", "rt_gcheap_alloc")


def census_allocator(path, out=print):
    if not os.path.exists(path):
        out(f"CENSUS allocator REFUSED(2): {path} missing"); return 2
    src = strip_comments(open(path, encoding="utf-8", errors="replace").read())
    for name in ALLOCATOR_SPELLINGS:   # the definition carries the c_ prefix today; the call sites do not
        body = function_body(src, name)
        if body is not None:
            break
    if body is None:
        out(f"CENSUS allocator REFUSED(2): none of {ALLOCATOR_SPELLINGS} is defined in {os.path.basename(path)} (renamed? tell the census)"); return 2
    hits = [i for i, line in enumerate(body.split("\n"), 1) if re.search(r"(?<![A-Za-z0-9_])rt_gc_collect\s*\(", line)]
    n = len(hits)
    COUNTS.setdefault("allocator", {})["rt_gc_collect_calls_in_the_allocator"] = n
    out(f"CENSUS allocator rt_gc_collect_calls_inside_{name}={n} want=0 -- Rule 3: the allocator sets g_gc_pending and grows the window, never collects"
        + (f"; body lines {hits}" if n else "") + f" {'GREEN' if n == 0 else 'RED'}")
    return 0 if n == 0 else 1


# ⛔⭐ A TAIL JUMP IS A CALL-GRAPH EDGE AND LEAVING IT OUT UNDERCOUNTED THE ALLOCATING SET BY 99 FUNCTIONS
# (cto 2026-09-18, found while generating the emitter's allocating table, row
# gc-the-emitter-emits-the-poll-not-the-template).  This walk used to record `call` edges only.  The
# hand-written asm allocators in src/runtime/rtx/rtx_alloc.s -- rt_str_alloc and rt_agg_alloc -- reach the
# carve by a TAIL JUMP (`jmp .Lga_armed` on the armed path, `je c_rt_str_alloc` to the C fallback otherwise)
# and never execute a `call rt_gcheap_alloc`, so BOTH of them and everything that reaches the heap only
# through them read as NON-ALLOCATING: 99 functions, the SNOBOL4 string builtins among them (DUPL_fn,
# REVERS_fn, SUBSTR_fn, TRIM_fn, BCHAR_fn, _CHAR_, _COLLECT_, _ITEM_ ...).  Downstream that put 27 emitter
# call sites OUTSIDE THE DENOMINATOR ENTIRELY -- neither polled nor counted unpolled -- in the number the GC
# emergency is steered by.  A tail jump is an edge for exactly the question this census asks: control reaches
# the target, the target may allocate, and it returns past us to OUR caller, so the allocation happens with
# the caller's frame live.  objdump prints a jump to a local label as <fn+0xNN>, and the symbol pattern below
# refuses a '+', so only true inter-function transfers are recorded; a self-edge is dropped.
# ⛔⭐ AND A CONDITIONAL TAIL JUMP IS ONE TOO, AND SO IS A TRANSFER THROUGH THE GOT (cto 2026-09-23, CEO-1224, row
# spine-no-rtccb-veneer-on-any-call-into-the-asm-runtime-the-rtx-abi-preserves-r8-to-r11).  The 09-18 cure above
# named `je c_rt_str_alloc` and then matched `jmp` alone, so an asm entry whose ONLY road to its allocating C twin
# was a CONDITIONAL exit -- VARVAL_fn (jne/jz c_VARVAL_fn), rt_size_d, rt_str_coerce, rt_match_enter, rt_defer_close,
# table_find_pair_d -- read NON-ALLOCATING, and 66 functions with them (every C caller whose only road to the heap
# ran through one of them).  The row that made emitted code call the asm runtime bare turned every such exit into
# a CALL from a local stub (the stub keeps r8-r11), which is how the gap surfaced: the same tree read 66 more
# allocating functions with no change to what allocates.  The same row added calls and tail jumps THROUGH THE GOT
# (RTX_CALL / RTX_JMP, call *slot(%rip)), which objdump labels with the nearest symbol, not the target; the target
# is the GLOB_DAT relocation at that slot, so the walk resolves it through `objdump -R`.  A PLT STUB (a header named
# sym@plt) is not a function a caller names -- its callers are recorded against sym itself -- and its own jump goes
# through the same GLOB_DAT slot when the symbol's address is also taken, so resolving it would enter 44 stubs into the
# set with no return class; the GOT walk skips them.
EDGE_RXS = (re.compile(r"\bcall\s+[0-9a-f]+ <([^>@+]+)"), re.compile(r"\bj[a-z]{1,4}\s+[0-9a-f]+ <([^>@+]+)"))
GOT_EDGE_RX = re.compile(r"\b(?:call|jmp)\s+\*0x[0-9a-f]+\(%rip\)\s+#\s+([0-9a-f]+)\b")

def _got_slots(so):
    """GOT slot address -> the symbol its GLOB_DAT relocation names, from `objdump -R`; {} if it cannot be read"""
    try:
        txt = subprocess.run(["objdump", "-R", so], capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return {}
    slots = {}
    for line in txt.split("\n"):
        m = re.match(r"^([0-9a-f]+)\s+R_X86_64_GLOB_DAT\s+([^\s@]+)", line)
        if m: slots[int(m.group(1), 16)] = m.group(2)
    return slots

def _alloc_reach_from_disasm(txt, seed="rt_gcheap_alloc", got=None):
    """the reverse-reachable set of seed over call AND inter-function jump edges (conditional ones and GOT slots
    included); (set, funcs) or (None, funcs)"""
    fn = None; edges = collections.defaultdict(set); funcs = set()
    for line in txt.split("\n"):
        m = re.match(r"^[0-9a-f]+ <([^>]+)>:$", line)
        if m:
            fn = m.group(1); funcs.add(fn); continue
        if not fn: continue
        for rx in EDGE_RXS:
            m = rx.search(line)
            if m and m.group(1) != fn:
                edges[fn].add(m.group(1))
        if got and "@" not in fn:
            m = GOT_EDGE_RX.search(line)
            if m:
                tgt = got.get(int(m.group(1), 16))
                if tgt and tgt != fn: edges[fn].add(tgt)
    if seed not in funcs:
        return None, funcs
    rev = collections.defaultdict(set)
    for a, bs in edges.items():
        for b in bs:
            rev[b].add(a)
    seen = {seed}; stack = [seed]
    while stack:
        x = stack.pop()
        for y in rev.get(x, ()):
            if y not in seen:
                seen.add(y); stack.append(y)
    return seen, funcs

def allocating_entries_from_binary(so, out=print):
    """every function in the runtime .so whose call graph reaches rt_gcheap_alloc (objdump -d, calls AND tail jumps)"""
    try:
        txt = subprocess.run(["objdump", "-d", "--no-show-raw-insn", so], capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError) as e:
        out(f"CENSUS safe-points REFUSED(2): objdump on {so} failed: {e}"); return None
    seen, funcs = _alloc_reach_from_disasm(txt, got=_got_slots(so))
    if seen is None:
        out(f"CENSUS safe-points REFUSED(2): {so} defines no rt_gcheap_alloc (renamed? tell the census)"); return None
    mod = _linked_module_symbols(so, out=out)
    if mod is None: return None
    seen = {s for s in seen if s not in mod}
    nf = sum(1 for f in funcs if f not in mod)
    out(f"CENSUS safe-points allocating_entries={len(seen)} of {nf} runtime functions reach rt_gcheap_alloc ({so}; {len(mod)} linked-module symbols excluded)")
    return seen


def _nm_names(path):
    """name -> how many times `nm --defined-only` lists it (local symbols may repeat across objects)"""
    txt = subprocess.run(["nm", "--defined-only", path], capture_output=True, text=True, check=True).stdout
    return collections.Counter(p[-1] for p in (l.split() for l in txt.splitlines()) if len(p) >= 3)


def _linked_module_symbols(so, out=print):
    """THE LINKED PARSE-STAGE MODULE IS EMITTED CODE, NOT RUNTIME C (6a3ff25a9 linked out/sc_mod/scparsers.o into the runtime; the
    ceo's CEO-1732). Its 31,000 labels are not runtime functions the emitter calls by name, and the allocating set names only
    those. The module is told apart by the names its own object defines, never by their shape: a .so that links the module
    (it defines scparsers_sc_module) and whose object is unreadable, or a name the module defines that another object in the
    .so also defines, REFUSES by name rather than guessing which one the call graph meant. Empty when no module is linked."""
    try:
        sonames = _nm_names(so)
    except (OSError, subprocess.CalledProcessError) as e:
        out(f"CENSUS safe-points REFUSED(2): nm on {so} failed: {e}"); return None
    if "scparsers_sc_module" not in sonames: return set()
    mo = os.path.join(os.path.dirname(os.path.abspath(so)), "sc_mod", "scparsers.o")
    try:
        mnames = _nm_names(mo)
    except (OSError, subprocess.CalledProcessError) as e:
        out(f"CENSUS safe-points REFUSED(2): {so} links the parse-stage module (scparsers_sc_module) and its object {mo} is not readable ({e}), so its emitted code cannot be told from runtime C"); return None
    both = sorted(n for n, k in mnames.items() if sonames[n] > k)
    if both:
        out(f"CENSUS safe-points REFUSED(2): {len(both)} name(s) are defined by the linked module {mo} AND by another object in {so}: {', '.join(both[:5])}"); return None
    return set(mnames)


CALL_RX = re.compile(r'x86\(\s*"call(?:_rt|_bare)?"\s*,(.*)$')


CALL_HEAD_RX = re.compile(r'x86\(\s*"call(?:_rt|_bare)?"\s*,')


def _call_close(line, m):
    """Index of the ')' that closes the x86( call CALL_RX matched at `m`, or None when the call runs past this line. Quotes are
    honoured. ⛔ WHY (the coo 2026-10-03): CALL_RX's group runs to the END OF THE LINE, so on a line that chains the call with more
    x86() calls the 'arguments' included theirs -- bb_call_pl_leaf.cpp's computed x86("call", sym, ...) "resolved" to mov/rax/rdx/
    cmp/al/je and left the census silently, and a poll later on the call's OWN line was never read."""
    depth, q, k = 1, None, m.start() + line[m.start():].index("(") + 1
    while k < len(line):
        ch = line[k]
        if q:
            if ch == "\\":
                k += 1
            elif ch == q:
                q = None
        elif ch in "\"'":
            q = ch
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return k
        k += 1
    return None

# A COUNT IS NOT COMPARABLE ACROSS A CHANGE OF ITS CRITERION.  Every line here names a sitting in which the census
# started counting something it could not see before, so a reader never reads the step as a regression or a win
# (SUITES.tsv's criterion_changed column, the same rule).  The baseline writer prints them into the file it writes.
CRITERION_CHANGES = [
    "2026-09-23 cto, SCRIP this landing (CEO-1224, row spine-no-rtccb-veneer-on-any-call-into-the-asm-runtime-the-rtx-abi-"
    "preserves-r8-to-r11): safe-points. A CONDITIONAL TAIL EXIT IS A CALL-GRAPH EDGE, AND SO IS A TRANSFER THROUGH A GOT "
    "SLOT. The 09-18 cure made `jmp` an edge and left `je/jne/...` out, so every asm entry whose only road to its allocating C "
    "twin was a conditional exit read NON-ALLOCATING -- VARVAL_fn, rt_size_d, rt_str_coerce, rt_match_enter, rt_defer_close, "
    "table_find_pair_d, rt_cap_open -- and 67 functions with them (the checked-in allocating table 1698 -> 1765, none "
    "removed). allocating_call_sites 230 -> 236, polled 230 -> 232, unpolled 0 -> 4, identity 232 + 0 + 4 == 236, "
    "MEASURED ON THE PARENT TREE 8a2e9bdff (its own binary, this census) BEFORE the row that surfaced it, so the rise is the "
    "instrument getting honest about a standing tree, not a landing going backwards (the CEO-1119 shape; the ratchet refuses "
    "a rise, so the baseline is raised here). THE FOUR, EACH A ROW: bb_match_begin.cpp rt_match_enter, bb_match_defer.cpp and "
    "bb_match_value.cpp rt_defer_close, bb_unop.cpp rt_size_d -- allocating calls with no safe point after them. The same row "
    "made emitted code call the asm runtime bare and turned every such exit into a CALL from a local stub, which is how the "
    "gap surfaced, and it added calls and tail jumps THROUGH THE GOT (RTX_CALL / RTX_JMP), which objdump labels with the "
    "nearest symbol rather than the target: the walk resolves the slot through its GLOB_DAT relocation and skips PLT stubs. "
    "Selftest 65 -> 69 arms (a conditional exit, a GOT slot to the allocator and one to a stranger, a GOT call with no map, a "
    "PLT stub).",
    "2026-09-22 coo, SCRIP this landing (CEO-1147, row instruments-the-safe-point-census-reader-...): safe-points. "
    "FOUR READER DEFECTS, AND THEY CANCELLED ON THE HEADLINE WHILE FOUR INDIVIDUAL SITES WERE WRONG IN BOTH "
    "DIRECTIONS. polled 190 -> 190, partially_polled 0 -> 6, unpolled 63 -> 57, identity 190 + 6 + 57 == 253. "
    "(a) MUTUALLY EXCLUSIVE STATEMENT ARMS: emit.cpp's icn_trace_tap and xa_flat.cpp's xa_icn_trace_tap are an "
    "if/else-if/else chain of allocating hook calls followed by ONE poll; the base predicate read each arm's "
    "SUCCESSOR ARM as a later call and stopped the window, so six sites read UNPOLLED. _stmt_sibling_offsets is "
    "the statement-level twin of _ternary_sibling_offsets, which COO-146 named and did not mechanize. "
    "(b) THE CONDITIONAL SKIP, THE ONLY SPECIES THAT MADE THE NUMBER TOO BIG (ceo, CEO-1132): the guard's `je` is "
    "emitted ABOVE the call and its landing pad BELOW the poll, so a reader looking only BETWEEN them sees nothing "
    "and credits a poll that is stepped over whenever g_trace == 0 -- which is every program that never assigns "
    "&trace. Two sites were credited that way; they are PARTIAL now, not polled. "
    "(c) THE GUARD IS ITSELF CONDITIONAL: IF(kind == 2 || kind == 3 || kind == 5, ... je) in emit.cpp and "
    "IF(kind != 1, ...) in xa_flat.cpp are NOT emitted on the kind == 1 arm, whose poll is unconditional. Reading "
    "(b) without (c) would have condemned two sound arms. "
    "(d) A SIBLING ARM IS NOT A GUARD: _poll_is_guarded matched `else if (kind == 2)` with its plain `if (` test "
    "and called xa_flat.cpp:427 PARTIAL although its poll is unconditional -- the same alternatives-as-sequence "
    "confusion at a FOURTH level. "
    "⭐ MEASURED FROM EMITTED BYTES BEFORE A LINE OF THE READER WAS WRITTEN, and the reader then reproduced the "
    "predicted 190/6/57 independently: `./scrip --compile` on a two-procedure Icon witness shows each kind 2/3 tap "
    "as cmp/je -> hook -> rt_gc_poll_asm -> landing pad (lines 131/142/149/153), and each kind 1 tap as hook -> "
    "rt_gc_poll_asm with no branch at all. `long g_trace = 0` is src/runtime/keywords.c:17. "
    "⛔ partially_polled IS NOW RATCHETED. It was printed, demanded zero by the census header, and watched by "
    "NOTHING; six sites could have become sixty with every gate green. "
    "⛔ AND THE CENSUS NOW REFUSES rc=2 ON A STALE BUILD (ceo CEO-1147 calls this the sharpest of the four): "
    "census_safe_points derives its DENOMINATOR from out/libscrip_rt.so via allocating_entries_from_binary, so an "
    "unbuilt tree does not merely date the verdict, it changes WHICH CALLS ARE COUNTED. Witnessed both ways at the "
    "landing. lib_build_currency.sh is SOURCED, never reimplemented, and there is deliberately no escape hatch.",
    "2026-09-22 coo, SCRIP this landing (CEO-1119, on the coo's measured delta): safe-points. A POLL THAT FOLLOWS "
    "A LATER CALL IS THAT CALL'S SAFE POINT. The base predicate's poll window now stops at the first intervening "
    "emitted call, the stop the expansion-site window has carried since CEO-1116 -- the SAME defect one level up, "
    "held back at COO-142 because it moves the published headline and that is the ceo's call. polled 156 -> 149, "
    "unpolled 97 -> 104 on SCRIP 20424784f. ⭐ THE RISE IS THE INSTRUMENT GETTING HONEST, NOT THE TREE GETTING "
    "WORSE (ceo, CEO-1119, the CEO-935 shape): the ratchet REFUSES a rise by design, so the baseline is raised in "
    "this same landing. This SUPERSEDES the ceo's NEXT MOVE note carried below, which forecast this change -- it "
    "is history now, not a forecast. ⛔ THE MECHANICAL ARM ALONE READS 148, NOT 149, AND THE DIFFERENCE IS THE "
    "WHOLE POINT: a mechanical stop can NOMINATE a site and cannot CONVICT one (the symmetric half of the ceo's "
    "own law that a static reader can reject a site and cannot clear one). Sixteen first nominations, nine thrown "
    "away by hand, seven published. The ninth rejection -- bb_call_value.cpp:130, where the intervening call at "
    ":134 sits inside the ELSE arm opened at :131 -- was named at COO-143 as an unmechanized blind spot rather "
    "than rounded away, and THIS landing mechanizes it: _ternary_sibling_offsets tracks an ARM INDEX PER PAREN "
    "DEPTH, so a line in a different arm of a ternary the site also stands in is an ALTERNATIVE, never a "
    "successor. It replaces the leading-character exemption entirely -- one rule, not two -- and reproduces the "
    "hand-read name set of 104 EXACTLY, name for name, not merely the count. ⛔ TWO EARLIER SHAPES OF THAT RULE "
    "WERE WRONG AND BOTH WERE CAUGHT BY MEASURING AGAINST THE HAND-READ NAMES RATHER THAN AGAINST A COUNT: a "
    "line-granular reader re-nominated the five sites whose '?' is on their own line (bb_iterate.cpp:27/:28/:29, "
    "bb_field_get.cpp:21/:39), and a latching one CLEARED THREE the hand read convicted "
    "(bb_match_capture.cpp:124/:163, bb_rev_assign_var.cpp:19) because it read the arm the site LIVES IN as an arm "
    "the site is excluded from. Five planted selftest arms hold both directions, each proven able to go red "
    "(selftest 47 -> 52 arms). SCRIP_GC_CENSUS_BASE_CALL_STOP=0 reproduces the pre-CEO-1119 reading and was "
    "verified byte-identical on all 97 names.",
    "2026-09-22 coo, SCRIP this landing (CEO-1109, the cto's finding): safe-points. ONE SOURCE CALL LINE IS NOT ONE "
    "EMITTED PATH. The predicate reads SOURCE PROXIMITY while POLLED is a claim about EMITTED CONTROL FLOW, and the "
    "emitter concatenates strings, so a call written once inside a file-local helper or a #define is spliced into "
    "every path that expands that unit. TWO NEW COLUMNS, multi_path_sites and partially_polled, and partially_polled "
    "is NOT counted in polled. ⛔ THE HEADLINE DOES NOT MOVE ON THIS TREE -- 152 of 253 before and after, "
    "partially_polled=0 -- so this is the instrument gaining a verdict it did not have, not a landing and not a "
    "regression. WHAT MOVES IS WHAT IT CAN SEE: 58 of the 253 sites are multi-path and were previously graded by a "
    "window that cannot distinguish one path from four. MEASURED PROOF THAT THE EXPOSURE WAS REAL, not argued: a poll "
    "planted under IF(g_gva_active) in bb_assign_global's comm_var tap reaches TWO of its FOUR expansions, and the old "
    "criterion read it polled=153 unpolled=100 and dropped the site from the worklist; the new one reads it PARTIAL "
    "and leaves polled at 152. ⛔ THE PATH COUNT IS AN UPPER BOUND AND SAYS SO: emit.cpp's icn_trace_tap expands at "
    "six sites but its call lines sit in mutually exclusive caller-selected arms, so the kind==2 call at :2914 is "
    "reached by one of the six. ⛔ AND ONE STOP RULE IS LOAD-BEARING, caught by reading the output rather than by "
    "writing the rule: an expansion-site window stops at the first intervening emitted call, because without it the "
    "reader credited NV_SET_fn's x86_rt_gc_poll_rec_res() to the comm_var tap spliced in above it and reported 2 of 4 "
    "paths polling on a tap the cto had deliberately left unpolled.",
    "2026-09-17 coo, SCRIP e625d1b35 -> this tree: safe-points. (i) A CALL TARGET IS SPELLED AS THE ASSEMBLER SEES IT: "
    "the ASCII-only symbol rule read the 32 emitter literals naming a Greek Byrd port (rt_proc_call_epilogue_GAMMA and "
    "kin) as no literal at all, so unresolved fell 39 -> 7 and two ALLOCATING targets entered the denominator "
    "(allocating_call_sites 202 -> 203). (ii) A POLL BELONGS TO THE CALL'S OWN ROUTINE: the line window walked past the "
    "closing brace and read the next routine's poll, so bb_call_proc_staged.cpp:88 read a FALSE POLLED. unpolled "
    "202 -> 203 IS THE INSTRUMENT GETTING HONEST, NOT A LANDING GOING BACKWARDS -- the same tree, one site that was "
    "never counted before, and it is genuinely unpolled.",
    "2026-09-17 cto, SCRIP 5dd2d79f0, recorded here by the coo: COVERAGE. Every words_scanned / interior_words "
    "reading taken BEFORE that tree was taken through a blindfold and none of them bounds anything: the conservative "
    "sniff gc_zeta_frame started at the address of a char local, three bytes off a word boundary, so it found ZERO "
    "arena-pointing words on the main stack -- measured 0 unaligned against 3, 7, 11, 12 aligned over the same four "
    "collections. A zero from a walker that was mis-started is not a small number, it is NOT A MEASUREMENT, and the "
    "coverage census's own RED=1 is the only reading of that criterion that survives. hq_snocone's decidable test and "
    "the poison-fill arm are decidable on 5dd2d79f0 or later, never before it.",
    "2026-09-17 coo, same sitting: safe-points. THE CENSUS IS TOLD HOW TO READ A COMPUTED TARGET -- array, macro, "
    "chooser and resolver-out-parameter, each named beside the site it resolves. The last 7 UNRESOLVED sites entered "
    "the denominator: unresolved 7 -> 0, allocating_call_sites 203 -> 210, unpolled 203 -> 210. Three of the seven are "
    "the Prolog direct-dispatch registry (dop_direct_fp, 172 allocating targets among 504 literals) and two are the "
    "SNOBOL4 capture opens behind the cap_open_sym() macro. A first, looser chooser rule resolved that macro against "
    "the next routine's literals and read 'none allocating' -- a candidate set that is not the target's is worse than "
    "UNRESOLVED, so the macro form now reads its own replacement text and an arm plants that trap.",
    "2026-09-17 coo, SCRIP this landing: CALLBACKS, ON CEO-836's WORD THAT THE NUMBER IS NOW LOAD-BEARING. The "
    "63 was wrong three ways and the third is the one that mattered. (i) THE SCOPE WAS TWO HAND-NAMED FILES AND "
    "ONE OF THEM HOLDS NO SITE: gen_runtime.c contributes zero, so the census read ONE file while naming two, and "
    "FIVE real sites of the identical class stood outside any denominator, in pattern_match.c, rt/rt.c and "
    "core/core.c. The scope is now DERIVED by walking src/runtime and src/driver -- 86 files. (ii) A "
    "DECLARATION IS NOT A CALL SITE: the filter tested the line's TERMINATOR, so a prototype ending ';' and a "
    "one-line definition ending '}' both counted -- FIFTEEN of the 63 were declarations, including five of the "
    "rt_call_arr_* forwarders at by_name_dispatch.c:5167-5171. The test is now the declarator prefix BEFORE the "
    "name, with the C keywords that may precede a call excluded. (iii) THE CRASH THE NUMBER IS SUPPOSED TO BOUND "
    "WAS NOT IN IT: the regex matched calls TO the dispatcher and never the callback OUT of it, so "
    "by_name_dispatch.c:5260 `out = APPLY_fn(fn, args, nargs);` -- the exact gdb site CEO-836 traced, the raw heap "
    "name pointer live across a call into emitted code -- was outside the census entirely. OUTBOUND is now its own "
    "printed population over a DECLARED set (APPLY_fn, _usercall_hook; rt_chain_enter and rt_chain_enter_v left the tree with CEO-1576) that "
    "REFUSES rc=2 if a named symbol leaves the tree. (iv) RT_GC_CALLBACK IS DEFINED NOWHERE IN src/: wrapped=0 was "
    "never 'nobody has wrapped one yet', and a no-op macro would have taken this census to GREEN with no semantic "
    "change -- the definition's absence is now PRINTED beside the count. THE ARITHMETIC CLOSES: 63 -> 48 on the "
    "same two files once a declaration stopped counting (-15), -> 53 when the scope was derived (+5 real "
    "sites the old scope never opened), and a SECOND key beside it, callbacks.unwrapped_outbound = 13, "
    "which is where by_name_dispatch.c:5260 finally appears. THIS IS THE INSTRUMENT GETTING HONEST, NOT A "
    "LANDING GOING BACKWARDS -- one tree, one sitting, no cure landed and none claimed.",
    "2026-09-17 cto, SCRIP this landing: safe-points. THE POLL SYMBOL IS NOW A FACT OF THE TREE, NOT A FLAG. "
    "Emitted code takes the pending flag by calling rt_gc_poll (the runtime entry added with the Icon allocating-box "
    "polls, F6 step 1b), so rt_gc_poll joins g_gc_pending in the DEFAULT poll spelling; --poll-helper still adds a "
    "landing-local name. No count moved on this criterion alone -- the same tree read 208 unpolled with the helper "
    "named and 208 without it; the 210 -> 208 fall is the two bb_make_list sites this landing polled.",
]

# A CALL TARGET IS SPELLED AS THE ASSEMBLER SEES IT, NOT AS ASCII C.  This tree names its four Byrd ports α β γ ω and
# puts them IN SYMBOL NAMES: rt_proc_call_epilogue_γ is a C function, an emitter literal and a binary symbol.  An
# ASCII-only identifier pattern reads such a literal as NO literal at all, so the site reads UNRESOLVED (or, with an
# ASCII literal beside it on the line, resolves to the wrong candidate set and leaves the graded denominator in
# silence).  Measured 2026-09-17 on SCRIP e625d1b35 by the coo: 32 of the 39 UNRESOLVED sites were plain string
# literals the census could not spell, and two of them -- rt_proc_call_epilogue_named_γ and _ω, at
# src/templates/bb/bb_call_proc_staged.cpp:88 -- REACH rt_gcheap_alloc, so an allocating call site sat outside the
# denominator that grades the poll landings.  The rule below is the binary's: a letter or underscore in ANY alphabet,
# then any run of characters that is not whitespace, a quote, a comma or a parenthesis.
SYM_RX = re.compile(r'"([^\W\d][^\s",()]*)"', re.UNICODE)


# TELLING THE CENSUS ABOUT A COMPUTED TARGET.  Seven emitter call sites choose their target at run time, and a site
# the census cannot read is a site outside its denominator -- so the census would never read GREEN however much poll
# work landed.  Three shapes are DECIDABLE from the source, and only these three; each is named in the output beside
# the site, so a reader sees which rule produced the candidate set and can re-derive it:
#   array    detN_nm[det_nA]  -- a static table of literal symbol names declared in the same file
#   chooser  cap_open_sym()   -- a nullary function whose body returns literal symbol names
#   resolver dsym             -- a variable filled in through the out-parameter of a function named in SYM_RESOLVERS
#                               (dop_direct_fp: the Prolog direct-dispatch registry, ~230 rows of { "$name", ar, "sym" })
# The candidate set is the STRING LITERALS of that table, body or registry -- an OVER-approximation on purpose: a
# literal that names nothing ("$unify") matches no runtime symbol and is harmless, while a missed allocating target
# would be a hole in the denominator.  Anything else stays UNRESOLVED and is printed, never skipped.
SYM_RESOLVERS = ("dop_direct_fp",)

LIT_RX = re.compile(r'"([^"\\\n]*)"')


def _brace_body_literals(text, at):
    """every string literal of the brace-balanced body whose opening brace is at/after `at` (empty if none closes)"""
    o = text.find("{", at)
    if o < 0:
        return []
    depth = 0
    for k in range(o, len(text)):
        if text[k] == "{":
            depth += 1
        elif text[k] == "}":
            depth -= 1
            if depth == 0:
                return LIT_RX.findall(text[o:k])
    return []


def _brace_body(text, o):
    """the text between the brace at o and its match, or "" when the braces do not close"""
    depth = 0
    for k in range(o, len(text)):
        if text[k] == "{":
            depth += 1
        elif text[k] == "}":
            depth -= 1
            if depth == 0:
                return text[o:k]
    return ""


DEF_RX_FMT = r"^[ \t]*(?:static\s+)?(?:inline\s+)?[A-Za-z_][\w \*]*\b%s\s*\([^;{\n]*\)[ \t]*\{"


def _chooser_literals_nested(text, o, depth=0, seen=None):
    """a chooser's literals plus, one level down, the literals of every chooser it calls that is DEFINED in the same
    file (a definition line: a type, the name, its parameter list and the opening brace, at the start of a line --
    never an if-statement that happens to call it, which is the 2026-09-17 mis-resolution shape)"""
    body = _brace_body(text, o)
    lits = LIT_RX.findall(body)
    if depth >= 2:
        return lits
    seen = set(seen or ())
    for callee in sorted(set(re.findall(r"\b([A-Za-z_]\w*)\s*\(", body))):
        if callee in seen:
            continue
        d = re.search(DEF_RX_FMT % re.escape(callee), text, re.M)
        if d and d.end() - 1 != o:
            seen.add(callee)
            lits += _chooser_literals_nested(text, d.end() - 1, depth + 1, seen)
    return lits


def _first_arg(expr):
    """the call's first argument: up to the first comma at paren/bracket depth 0"""
    depth = 0
    for k, c in enumerate(expr):
        if c in "([":
            depth += 1
        elif c in ")]":
            if depth == 0:
                return expr[:k]
            depth -= 1
        elif c == "," and depth == 0:
            return expr[:k]
    return expr


def _top_args(s, k):
    """The comma-separated arguments of the call whose '(' ends at index k-1 of s, at depth 0, quotes honoured; [] when unclosed."""
    out, depth, q, start = [], 0, None, k
    while k < len(s):
        ch = s[k]
        if q:
            if ch == "\\":
                k += 1
            elif ch == q:
                q = None
        elif ch in "\"'":
            q = ch
        elif ch in "([":
            depth += 1
        elif ch in ")]":
            if depth == 0:
                out.append(s[start:k]); return out
            depth -= 1
        elif ch == "," and depth == 0:
            out.append(s[start:k]); start = k + 1
        k += 1
    return []


def _param_literals(own_text, site_line, ident, depth=0, all_text=None):
    """A call target that is a PARAMETER of the function enclosing the site (bb_call_pl_leaf.cpp's pl_cold_call(const char * sym,
    ...) emitting x86("call", sym, ...)): the string literals passed in that position at every call of the function in the same
    file. ([], "") when the site is not in a function, `ident` is not one of its parameters, or no call passes a literal there --
    UNRESOLVED stays the answer, never a guess (the coo 2026-10-03: the site used to 'resolve' to the mnemonics of the x86() calls
    chained after it on its line, and so left the census silently)."""
    for kind, name, first, last in emission_units(own_text):
        if kind != "func" or not (first <= site_line <= last):
            continue
        hd = re.search(r"\b" + re.escape(name) + r"\s*\(", own_text.split("\n")[first - 1])
        if not hd:
            return [], ""
        params = _top_args(own_text, len("\n".join(own_text.split("\n")[:first - 1])) + (1 if first > 1 else 0) + hd.end())
        idx = next((k for k, pa in enumerate(params) if re.search(r"\b" + re.escape(ident) + r"\s*$", pa.strip())), None)
        if idx is None:
            return [], ""
        lits = []
        via = ""
        for c in re.finditer(r"\b" + re.escape(name) + r"\s*\(", own_text):
            if own_text.count("\n", 0, c.start()) + 1 == first:
                continue
            args = _top_args(own_text, c.end())
            if idx < len(args):
                found = LIT_RX.findall(args[idx])
                lits += found
                # the caller passes an IDENTIFIER, not a literal: its candidates are the string literals of that identifier's
                # initializers in the same file (bb_call_fn.cpp's osym = _meth ? "rk_method_open" : ... ? "rk_callwith_open"
                # : "rk_callsame_open", passed to bcfn_method_open_enter(..., osym, ofp); the cto 2026-10-10, CEO-1627). An
                # identifier with no literal initializer in the file resolves to nothing, and UNRESOLVED stays the answer.
                av = args[idx].strip()
                if not found and re.match(r"[A-Za-z_]\w*$", av):
                    for ini in re.finditer(r"\b" + re.escape(av) + r"\s*=\s*([^;]*);", own_text):
                        lits += LIT_RX.findall(ini.group(1))
                        via = f" via the initializers of {av}"
                    # the caller FORWARDS a parameter of its own (bb_call_fn.cpp's cf_open_method(osym, ofp) handing osym on to
                    # bcfn_method_open_enter): the candidates are what ITS callers pass there, one level up, at most three deep
                    if not lits and depth < 3:
                        cl = own_text.count("\n", 0, c.start()) + 1
                        fw, fwrule = _param_literals(own_text, cl, av, depth + 1, all_text)
                        if fw:
                            lits += fw
                            via = f" forwarded from {fwrule}"
                # the caller passes a g_emit FIELD (_.op_call_open_sym): the candidates are the emitter's writes into it
                mfa = re.match(r"_\.(op_[a-z0-9_]+)$", av)
                if not found and mfa and all_text is not None:
                    fl, flrule = _emit_field_literals(mfa.group(1), all_text)
                    if fl:
                        lits += fl
                        via = f" via the {flrule}"
                mc = re.match(r"([A-Za-z_]\w*)\s*\(", av)
                if not found and mc:
                    md = re.search(r"^[ \t]*#[ \t]*define[ \t]+" + re.escape(mc.group(1)) + r"\([^)]*\)(.*(?:\\\n.*)*)$", own_text, re.M)
                    if md:
                        lits += LIT_RX.findall(md.group(1))
                        via = f" via the macro {mc.group(1)}()"
        return (sorted(set(lits)), f"parameter {ident} of {name}(){via}") if lits else ([], "")
    return [], ""


def _rtx_twin_map():
    """leaf -> C twin from rtx_twin_table.inc (RTX_TWIN(kind, ret, leaf, twin, args)): emit_rtx_twin_sym(leaf) is the twin when the leaf has
    one and the leaf otherwise, so a site calling through it may reach either name; {} when the table is absent (a selftest fixture root)."""
    try:
        t = open(os.path.join(ROOT, "src", "templates", "x86", "rtx_twin_table.inc"), encoding="utf-8").read()
    except OSError:
        return {}
    return {m.group(1): m.group(2) for m in re.finditer(r"RTX_TWIN\(\s*\w+\s*,[^,]+,\s*(\w+)\s*,\s*(\w+)\s*,", t)}


def _emit_field_literals(field, all_text):
    """A call target that is a g_emit FIELD (x86("call", _.op_call_sym, ...), hq_templates 2026-10-14, the call plan of ARCH-CALL-FORMS): the
    candidates are what the emitter writes into it -- every `g_emit.<field> = <rhs>;` in the population (src/emitter is in it), each right-hand
    side read by the rules of this file: its literals, a chooser it calls (a function defined in the population whose body returns literals),
    and an identifier a resolver filled (dop_direct_fp(..., &s)). An empty literal is the field's reset, never a candidate."""
    lits = []
    n = 0
    for w in re.finditer(r"g_emit\." + re.escape(field) + r"\s*=\s*([^;]*);", all_text):
        rhs = w.group(1)
        n += 1
        lits += [l for l in LIT_RX.findall(rhs) if l]
        for c in re.finditer(r"\b([A-Za-z_]\w*)\s*\(", rhs):
            name = c.group(1)
            if name in ("uint64_t", "uintptr_t", "void", "long", "int", "strcmp", "IF", "sizeof"):
                continue
            d = re.search(DEF_RX_FMT % re.escape(name), all_text, re.M)
            if d:
                lits += _chooser_literals_nested(all_text, d.end() - 1)
        for ident in set(re.findall(r"(?<![\w.\"])([A-Za-z_]\w*)(?![\w(\"])", rhs)):
            for rv in SYM_RESOLVERS:
                if re.search(re.escape(rv) + r"\s*\([^;]*&\s*" + re.escape(ident) + r"\b", all_text):
                    d = re.search(r"\b" + re.escape(rv) + r"\s*\([^;{]*\)\s*\{", all_text)
                    if d:
                        lits += _brace_body_literals(all_text, d.end() - 1)
    return (sorted(set(lits)), f"emit field {field} ({n} writer(s) in the emitter)") if lits else ([], "")


def resolve_computed(expr, own_text, all_text, site_line=None):
    """(candidates, rule) for a computed call target the census has been told how to read; ([], "") otherwise"""
    e = _first_arg(expr).strip()
    mf = re.match(r"_\.(op_[a-z0-9_]+)\s*$", e)
    if mf:
        lits, rule = _emit_field_literals(mf.group(1), all_text)
        if lits:
            return lits, rule
    mt = re.match(r"emit_rtx_twin_sym\s*\((.*)\)\s*$", e)
    if mt:
        lits, rule = resolve_computed(mt.group(1), own_text, all_text, site_line)
        tw = _rtx_twin_map()
        return (sorted(set(lits) | {tw[x] for x in lits if x in tw}), f"{rule} through emit_rtx_twin_sym()") if lits else ([], "")
    m = re.match(r"([A-Za-z_]\w*)\s*\[", e)
    if m and re.search(r"\b" + m.group(1) + r"\s*\[[^\]]*\]\s*=\s*\{", own_text):
        d = re.search(r"\b" + m.group(1) + r"\s*\[[^\]]*\]\s*=\s*\{", own_text)
        return _brace_body_literals(own_text, d.end() - 1), f"array {m.group(1)}[]"
    m = re.match(r"([A-Za-z_]\w*)\s*\(\s*\)\s*$", e)
    if m:
        # A CHOOSER IS PROVEN AT ITS DEFINITION OR NOT AT ALL.  cap_open_sym() is a #define, not a function, and a
        # pattern loose enough to match the macro line and then run on to the next `{` in the file resolves the site
        # against SOME OTHER routine's literals -- a candidate set that is not the target's is worse than UNRESOLVED.
        # So: the macro form reads its own (backslash-continued) replacement text, and the function form requires the
        # opening brace on the SAME line as the parameter list.
        d = re.search(r"^[ \t]*#[ \t]*define[ \t]+" + m.group(1) + r"\(\)(.*(?:\\\n.*)*)$", own_text, re.M)
        if d:
            return LIT_RX.findall(d.group(1)), f"macro {m.group(1)}()"
        d = re.search(r"\b" + m.group(1) + r"\s*\([^;{\n]*\)[ \t]*\{", own_text)
        if d:
            return _brace_body_literals(own_text, d.end() - 1), f"chooser {m.group(1)}()"
    m = re.match(r"([A-Za-z_]\w*)\s*\(.*\)\s*$", e)
    if m:
        d = re.search(DEF_RX_FMT % re.escape(m.group(1)), own_text, re.M)
        if d:
            return _chooser_literals_nested(own_text, d.end() - 1), f"chooser {m.group(1)}(...)"
        if re.search(r"^[ \t]*extern\b[^;{\n]*\b" + re.escape(m.group(1)) + r"\s*\([^;{\n]*\)\s*;", own_text, re.M):
            ds = list(re.finditer(DEF_RX_FMT % re.escape(m.group(1)), all_text, re.M))
            if len(ds) == 1:
                return _chooser_literals_nested(all_text, ds[0].end() - 1), f"chooser {m.group(1)}(...) [extern, defined once in the set]"
    m = re.match(r"([A-Za-z_]\w*)\s*$", e)
    if m and site_line is not None:
        lits, rule = _param_literals(own_text, site_line, m.group(1), 0, all_text)
        if lits:
            return lits, rule
    if m:
        for rv in SYM_RESOLVERS:
            if re.search(re.escape(rv) + r"\s*\([^;]*&\s*" + m.group(1) + r"\b", own_text):
                d = re.search(r"\b" + re.escape(rv) + r"\s*\([^;{]*\)\s*\{", all_text)
                if d:
                    return _brace_body_literals(all_text, d.end() - 1), f"resolver {rv}()"
    return [], ""


def emitter_call_sites(files):
    """(file, line, [candidate symbols], lines, rule) for every x86("call", ...) in the emitter; a call expression
    whose target is computed is read through resolve_computed and NAMES its rule, and one the census has not been
    told how to read is UNRESOLVED and printed, never skipped."""
    texts = {}
    for f in files:
        try:
            texts[f] = open(f, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
    joined = "\n".join(texts.values())
    sites = []
    for f, text in texts.items():
        lines = text.split("\n")
        for i, line in enumerate(lines, 1):
            m = CALL_RX.search(line)
            if not m:
                continue
            # the OWN arguments of every x86("call") on the line, never the chain of other x86() after them: a line may hold two
            # calls as the arms of one ternary (bb_call_value.cpp:81 and :143 -- exclusive alternatives with one safe point), and
            # both arms' targets are this site's candidates
            parts = []
            for mm in CALL_HEAD_RX.finditer(line):
                _e = _call_close(line, mm)
                parts.append(line[mm.end():_e] if _e is not None else line[mm.end():])
            args = " , ".join(parts)
            syms = SYM_RX.findall(args)
            rule = ""
            if not syms:
                syms, rule = resolve_computed(args, text, joined, site_line=i)
            sites.append((f, i, syms, lines, rule))
    return sites


# ⛔ ONE SOURCE CALL LINE IS NOT ONE EMITTED PATH, AND UNTIL 2026-09-22 THIS CENSUS ASSUMED IT WAS.  The emitter
# builds its output by string concatenation, so a call site written ONCE inside a file-local helper or a #define is
# SPLICED INTO EVERY PATH THAT EXPANDS THAT UNIT.  The poll predicate below reads SOURCE PROXIMITY -- poll text within
# --poll-window lines after the call -- which is a question about the source file, while POLLED is a claim about
# emitted control flow.  Where a unit expands more than once the two come apart, and they come apart in the WORST
# DIRECTION: one poll in the shared body reads the site fully POLLED however many of its paths actually carry it.
# FOUND BY THE cto, NOT BY READING THIS CODE (CEO-1109, relayed by the ceo 2026-09-22): bb_assign_global's comm_var
# tap is ONE x86("call", ...) line spliced into FOUR paths, and at one of them the fresh string is live only in
# rax:rdx and rooted nowhere -- so polling the rooted paths alone would have read the site POLLED with a quarter of
# it still uncollectable.  THEY DECLINED AND LEFT IT UNPOLLED, which is why this is a criterion change and not a
# retraction of somebody's landing.
#
# WHAT THIS READER DOES AND, MORE IMPORTANTLY, WHAT IT DOES NOT.  It finds the FUNCTION or MACRO body that textually
# contains each call site and counts that unit's EXPANSION SITES across the emitter files.  That count is an UPPER
# BOUND on the paths reaching the site, never an exact figure, and the bound is named in the output rather than
# rounded away.  Measured reason, 2026-09-22 by the coo, on emit.cpp's icn_trace_tap: the helper is expanded at six
# sites, but its four call lines sit in MUTUALLY EXCLUSIVE arms selected by the caller's `kind` argument, so the
# kind==2 call at :2914 is reached by exactly ONE of the six.  A reader that followed argument-selected arms would
# say 1; this one says 6 and SAYS THAT IT IS AN UPPER BOUND.
# ⛔ AND THE FIRST VERSION OF THIS READER WAS WRONG IN A WAY WORTH RECORDING, because it is the same error the row
# exists to cure: it took "nearest preceding function definition" as the enclosing unit, which put
# bb_binop_arith.cpp:137 inside rtop_addr_s() -- a function whose name merely appears in the call's ARGUMENT list --
# and reported 32 multi-path sites off that reading.  The site is really inside the inl_tail() MACRO.  Brace depth is
# tracked from column 0 and #define continuations own their lines, so a macro body is a unit and an argument is not.
DEFN_RX = re.compile(r'^[A-Za-z_][\w:<>,\s\*&]*?\b([A-Za-z_]\w*)\s*\(')
PROTO_RX = re.compile(r'^\s*(?:extern\s+|static\s+|inline\s+)*[A-Za-z_][\w:<>,\s\*&]*?\b(\w+)\s*\([^;{]*\)\s*(?:const\s*)?;\s*$')


def emission_units(text):
    """(kind, name, first_line, last_line) for every function body and every #define body in one emitter file.
    Brace depth is counted from the start of the file so a nested block never opens a unit, and a #define owns its
    backslash continuations.  1-based, inclusive."""
    lines = text.split("\n")
    units = []
    depth = 0
    pending = None          # (name, header_line) seen at depth 0, waiting for its opening brace
    open_at = None
    i = 0
    while i < len(lines):
        ln = i + 1
        raw = lines[i]
        if depth == 0 and raw.lstrip().startswith("#define"):
            m = re.match(r'\s*#define\s+(\w+)', raw)
            j = i
            while j < len(lines) and lines[j].rstrip().endswith("\\"):
                j += 1
            if m and j > i:                      # a one-line #define expands to no path of its own
                units.append(("macro", m.group(1), ln, j + 1))
            i = j + 1
            continue
        if depth == 0 and not raw.lstrip().startswith(("#", "//", "/*", "*")):
            m = DEFN_RX.match(raw)
            if m and not PROTO_RX.match(raw):
                pending = (m.group(1), ln)
        before = depth
        for ch in raw:
            if ch == "{":
                if depth == 0 and pending:
                    open_at = pending
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0 and open_at:
                    units.append(("func", open_at[0], open_at[1], ln))
                    open_at = None
                    pending = None
        if depth == before == 0 and raw.strip().endswith(";"):
            pending = None
        i += 1
    return units


def unit_of(units, line):
    """The INNERMOST unit containing `line` -- the narrowest span wins, so a call inside a macro inside a file
    reads the macro."""
    best = None
    for u in units:
        if u[2] <= line <= u[3]:
            if best is None or (u[3] - u[2]) < (best[3] - best[2]):
                best = u
    return best


def expansion_lines(unit, own_file, texts):
    """Line numbers, per file, that EXPAND this unit -- every reference to its name outside its own body and outside
    a bare prototype.  A unit expanded 0 or 1 times emits one path; the emitter's own dispatch of a top-level
    template counts as that one."""
    kind, name, lo, hi = unit
    rx = re.compile(r'\b' + re.escape(name) + r'\s*\(' if kind == "func" else r'\b' + re.escape(name) + r'\b')
    hits = []
    for f, t in texts.items():
        fl = t.split("\n")
        for m in rx.finditer(t):
            ln = t.count("\n", 0, m.start()) + 1
            if f == own_file and lo <= ln <= hi:
                continue                                  # its own body, including recursion
            src = fl[ln - 1]
            stmt = src
            k = ln
            while k < len(fl) and not stmt.rstrip().endswith((";", "{", "}")) and k - ln < 6:
                stmt = stmt + " " + fl[k].strip()
                k += 1
            prefix = src[:m.start() - (t.rfind("\n", 0, m.start()) + 1)]
            wrapped_proto = re.fullmatch(r"\s*(?:extern\s+|static\s+|inline\s+)*[A-Za-z_][\w:<>,\s\*&]*?\s+", prefix) and not prefix.lstrip().startswith("return") and PROTO_RX.match(stmt)
            if PROTO_RX.match(src) or wrapped_proto or src.lstrip().startswith(("#define", "extern ")):
                continue
            hits.append((f, ln))
    return sorted(set(hits))


# ⛔⭐ THE POLL WINDOW IS MEASURED IN EMITTED x86 CALLS, NEVER IN PHYSICAL LINES (the cto's ruling on the cfo's report, 2026-10-03; the
# coo's landing). A whitespace-only reformat of a template -- hq_templates' R4 hygiene, one x86() per line -- splits one source line into
# several and moved three bb_call-family polls out of a 12-LINE window with byte-identical emission (bb_call_fn.cpp unpolled +1,
# bb_call_value.cpp rt_call_apply_gen_h +1, bb_call_pl_leaf.cpp unresolved 0 -> 1). The window after a site is now the source lines that
# together hold POLL_WINDOW_X86 x86-prefixed calls (x86(...), x86_rt_gc_poll(), x86_omega(...) and kin -- operand helpers counted too,
# which is harmless: the count is invariant under any line reflow, which is the whole requirement), capped at WINDOW_LINE_CAP lines;
# the routine and intervening-call stops are unchanged. SCRIP_GC_CENSUS_WINDOW_UNIT=lines reproduces the 12-line reading for an auditor
# comparing across the change; it is an escape hatch, never the default.
X86_TOKEN_RX = re.compile(r"\bx86(?:_[A-Za-z0-9_]+)?\s*\(")
POLL_WINDOW_X86 = int(os.environ.get("SCRIP_GC_CENSUS_WINDOW_X86", "14"))
WINDOW_LINE_CAP = 80


def _window_lines(lines, start, poll_window):
    """The source lines a poll window covers after 0-based index `start`: `poll_window` lines in the legacy unit, else the lines that
    hold POLL_WINDOW_X86 x86 calls (the line that reaches the budget included), never more than WINDOW_LINE_CAP."""
    if os.environ.get("SCRIP_GC_CENSUS_WINDOW_UNIT", "x86") == "lines":
        return lines[start:start + poll_window]
    out, n = [], 0
    for wl in lines[start:start + WINDOW_LINE_CAP]:
        out.append(wl)
        n += len(X86_TOKEN_RX.findall(wl))
        if n >= POLL_WINDOW_X86:
            break
    return out


def _path_window_lines(lines, i):
    """The base window of the call at 1-based line `i`, budgeted on the call's OWN PATH: the lines after it that hold POLL_WINDOW_X86
    x86 tokens, counting none in another arm of a ternary the call stands in (_ternary_sibling_offsets' counts) and none on a line of
    another arm of its if / else chain (_stmt_sibling_offsets), never more than WINDOW_LINE_CAP lines. With no alternative arm in
    reach it is exactly _window_lines."""
    wide = lines[i:i + WINDOW_LINE_CAP]
    counts = []
    _ternary_sibling_offsets(lines, i, wide, counts)
    stmt = _stmt_sibling_offsets(lines, i, wide)
    out, n = [], 0
    for k, wl in enumerate(wide):
        out.append(wl)
        n += 0 if k in stmt else (counts[k] if k < len(counts) else len(X86_TOKEN_RX.findall(wl)))
        if n >= POLL_WINDOW_X86:
            break
    return out


def _window_after(lines, line_no, poll_window):
    """The window after an EXPANSION site, stopped at the first column-0 closing brace or /*--- separator (the coo's
    2026-09-17 rule: a poll belongs to the call's own routine) AND at the first intervening emitted call.
    ⛔ THE SECOND STOP IS NOT DECORATION AND IT WAS CAUGHT BY READING THE OUTPUT, NOT BY WRITING THE RULE.  Without
    it this reader said bb_assign_global.cpp:37 had 2 of 4 expansion sites polling -- and both of those polls were
    x86_rt_gc_poll_rec_res() sitting after a LATER x86("call", "NV_SET_fn", ...) on the same path.  A poll belongs to
    the call it follows, so crediting NV_SET_fn's safe point to the comm_var tap spliced in above it is the very
    source-proximity error this row exists to cure, committed one level up.  The cto's own account -- that they left
    the tap UNPOLLED -- is what the census now reads."""
    w = _window_lines(lines, line_no, poll_window)
    stop = len(w)
    for k, wl in enumerate(w):
        if wl.startswith("}") or wl.startswith("/*---") or CALL_RX.search(wl):
            stop = k
            break
    return w[:stop]


IF_COND_RX = re.compile(r'\bIF\(\s*(.+?)\s*,\s*x86')
REL_RX = re.compile(r'^(.*?)\s*(==|!=)\s*(.+?)\s*$')


def _if_guard(line):
    """(lhs, op, rhs) of an IF(<cond>, x86(...)) compile-time guard on this line, or None.  Deliberately narrow: a
    condition this cannot parse yields None, which leaves the line counted as an intervening call -- the direction
    that NOMINATES a site for a human to read, never the one that silently clears it."""
    m = IF_COND_RX.search(line)
    if not m:
        return None
    r = REL_RX.match(m.group(1))
    return (r.group(1).strip(), r.group(2), r.group(3).strip()) if r else None


def _mutually_exclusive(a, b):
    """⛔ TWO COMPILE-TIME GUARDS THE READER CAN PROVE DISJOINT, AND NOTHING WIDER.  Same left-hand expression, and
    either == against two DIFFERENT constants or ==/!= against the SAME one.  Found by reading the sixteen names the
    first arm printed: bb_unop.cpp 25/26 sit in a four-way IF((int)_.op_ival == TT_MNS/TT_PLS/TT_SIZE/TT_CSET_COMPL)
    chain and :112/113 in a complementary == / != TT_MNS pair, so exactly ONE call of each group is ever emitted and
    the poll below is that one call's safe point.  Anything this cannot prove disjoint stays an intervening call."""
    if not a or not b or a[0] != b[0]:
        return False
    if a[1] == "==" and b[1] == "==":
        return a[2] != b[2]
    return a[2] == b[2]


STMT_ARM_RX = re.compile(r'^\s*\}?\s*else\b')
STMT_OPENS_ARM_RX = re.compile(r'^\s*(\}\s*)?(else\s+if\b|else\b|if\s*\()')
# ⛔ A CONDITIONAL JUMP EMITTED AROUND A POLL, AND ITS SKIP LABEL.  x86("je", sk) ... x86("def", sk) is how this
# tree spells "run this only when the condition holds"; `jmp` is deliberately NOT in the alternation, because an
# UNCONDITIONAL jump over a poll makes it dead rather than partial and deserves its own reading, not this one.
EMIT_JCC_RX = re.compile(r'x86\(\s*"(jne|jnz|jns|jae|jbe|jge|jle|je|jz|jl|jg|ja|jb|js)"\s*,\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)')
EMIT_DEF_RX = re.compile(r'x86\(\s*"def"\s*,\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)')


def _balanced_after(text, open_pos):
    """The text inside the parenthesis opened at `open_pos`, or None when it does not close on this line."""
    d = 0
    for k in range(open_pos, len(text)):
        if text[k] == "(":
            d += 1
        elif text[k] == ")":
            d -= 1
            if d == 0:
                return text[open_pos + 1:k]
    return None


def _stmt_arm_cond(line):
    """The condition text of the C `if (...)` / `else if (...)` arm this line opens, "" for a bare `else`, or None."""
    c, _ = _lit_free(line, None)
    m = re.match(r'^\s*(\}\s*)?(else\s+if|if|else)\b', c)
    if not m:
        return None
    if m.group(2) == "else":
        return ""                                  # a bare else carries no condition and can never be proven disjoint
    o = c.find("(", m.end() - (2 if m.group(2) == "if" else 0))
    o = c.find("(", m.start())
    while o != -1 and o < m.end() - 1:
        o = c.find("(", o + 1)
    return _balanced_after(c, o) if o != -1 else None


def _disjoint_conds(a, b):
    """True when two compile-time condition TEXTS can be PROVEN to never hold together.  Each side is split on `||`
    and every disjunct pair must be provably exclusive by the same narrow rule _mutually_exclusive already uses --
    same left-hand expression, `==` against different constants or `==`/`!=` against the same one.

    ⛔ WIDENED TO DISJUNCTIONS BECAUSE THE REAL GUARD IS ONE (the coo, 2026-09-22): emit.cpp spells the trace guard
    `IF(kind == 2 || kind == 3 || kind == 5, ... x86("je", sk))`, so an arm asking `kind == 1` must be compared
    against all three disjuncts and cleared only when it is exclusive with EVERY one.  Anything unparsed is NOT
    disjoint, which keeps the site in the column that demands a human."""
    if a is None or b is None or a == "" or b == "":
        return False
    pa = [_parse_rel(x) for x in a.split("||")]
    pb = [_parse_rel(x) for x in b.split("||")]
    if any(x is None for x in pa) or any(x is None for x in pb):
        return False
    return all(_mutually_exclusive(x, y) for x in pa for y in pb)


def _parse_rel(text):
    r = REL_RX.match(text.strip())
    return (r.group(1).strip(), r.group(2), r.group(3).strip()) if r else None


def _governing_if_cond(lines, lo, jl, jpos):
    """The condition of the emitter's `IF(cond, ...)` macro still OPEN where the jump at line index `jl`, column
    `jpos` is emitted -- or None when no IF encloses it.  Enclosure is proven by a single paren scan from the unit's
    first line to the jump, never inferred from proximity: an `IF(...)` that has already CLOSED earlier in the same
    expression is not this jump's guard, and mistaking one for the other would exonerate a genuinely skipped poll."""
    q = None
    parts = []
    for j in range(lo, jl):
        c, q = _lit_free(lines[j], q)
        parts.append(c)
    # ⛔ SLICE THE RAW LINE, THEN STRIP -- NEVER THE OTHER WAY ROUND.  `jpos` is a column in the RAW source, and
    # _lit_free SHORTENS the line by emptying every string literal, so slicing the stripped text at a raw column
    # reads PAST the jump and swallows the `))` that closes the guard -- which silently reports NO governing IF and
    # would have re-condemned the two unguarded arms this reader exists to spare.
    c, q = _lit_free(lines[jl][:jpos], q)
    parts.append(c)
    text = "\n".join(parts)
    stack = []
    for k, ch in enumerate(text):
        if ch == "(":
            is_if = k >= 2 and text[k - 2:k] == "IF" and (k < 3 or not (text[k - 3].isalnum() or text[k - 3] == "_"))
            stack.append((k, is_if))
        elif ch == ")" and stack:
            stack.pop()
    for pos, is_if in reversed(stack):
        if not is_if:
            continue
        tail = text[pos + 1:]
        d = 0
        for t, ch in enumerate(tail):              # the condition runs to this IF's own top-level comma
            if ch == "(":
                d += 1
            elif ch == ")":
                d -= 1
            elif ch == "," and d == 0:
                return " ".join(tail[:t].split())
        return " ".join(tail.split())
    return None


POLL_FORM_RX = re.compile(r'\b(x86_rt_gc_poll[A-Za-z0-9_]*)\s*\(')


def _poll_form(line):
    """WHICH poll form this line spells -- the helper's own name, or the raw shapes it lowers to.

    ⛔ THE CENSUS COUNTED POLLED AGAINST UNPOLLED AND NOTHING ELSE, SO SWAPPING ONE FORM FOR ANOTHER READ THE SAME
    NUMBER (the cto, 2026-09-22): their sed round-trip converted five sites it had never analysed and the census read
    177 on the CONTAMINATED tree exactly as on the clean one -- only `git diff` caught it.  A count that cannot tell
    two trees apart is not measuring the difference between them, and the forms are NOT interchangeable: poll_res
    reconstructs a DESCR pair from rax:rdx, the rec_sigma family lowers to rt_gc_point_arr_c instead of rt_gc_poll,
    and a bare poll roots nothing at all.  The histogram is printed beside the count so a swap is visible."""
    m = POLL_FORM_RX.search(line)
    if m:
        return m.group(1)
    if "g_gc_pending" in line:
        return "g_gc_pending (raw lea)"
    if "rt_gc_poll" in line:
        return "rt_gc_poll (raw call)"
    return "unclassified"


def _stmt_sibling_offsets(lines, i, window_lines):
    """Offsets into `window_lines` standing in a DIFFERENT ARM of the same C `if / else if / else` chain as the call
    at 1-based line `i` -- an ALTERNATIVE to the site, never a successor, so such a call must not stop the poll
    window.

    ⛔ THIS IS THE STATEMENT-LEVEL TWIN OF _ternary_sibling_offsets, AND COO-146 NAMED IT WITHOUT MECHANIZING IT.
    The expression-level rule reads `a ? X : Y`; this one reads the same exclusivity spelled as statements, which is
    how emit.cpp's icn_trace_tap and xa_flat.cpp's xa_icn_trace_tap are written: four allocating hook calls in one
    if/else-if/else chain followed by ONE unconditional poll.  Without this rule the first three arms each stop their
    own window at the next arm's call -- reading an ALTERNATIVE as a LATER CALL -- and report UNPOLLED.  MEASURED, not
    argued: `./scrip --compile` on a two-procedure Icon witness emits `call rt_trace_call_hook_f` then
    `call rt_gc_poll_asm` seven lines later with no branch between them, so the kind==1 arm is polled on every path.

    ⛔ DELIBERATELY NARROW AND ONE-DIRECTIONAL IN THE DIRECTION THAT KEEPS A STOP.  Removing a stop is the CLEARING
    direction -- the dangerous one, the one that mints a false POLLED -- so this fires only when the SITE'S OWN LINE
    opens an arm (`if (`, `else if (`, `else`).  A site inside a braced arm body spanning several lines is not seen
    and keeps every stop it had.  The complementary guard reader below then catches an arm whose poll is real in the
    source but jumped over in the emitted bytes, so opening the window here cannot by itself clear a site."""
    site = i - 1
    if site < 0 or site >= len(lines):
        return set()
    if CALL_RX.search(lines[site]) is None:
        return set()
    q = None
    lo = max(0, site - TERNARY_LOOKBACK)
    for j in range(lo, site):                      # carry the quote state in, exactly as the ternary rule does
        _, q = _lit_free(lines[j], q)
    head, q = _lit_free(lines[site], q)
    if not STMT_OPENS_ARM_RX.match(head):
        return set()

    offs = set()
    depth = head.count("{") - head.count("}")
    arm_open = depth > 0 or not head.rstrip().endswith(";")
    sibling = False
    for k, wl in enumerate(window_lines):
        c, q = _lit_free(wl, q)
        if arm_open:                               # still inside an arm: the site's own (successor) or a sibling's
            if sibling:
                offs.add(k)
            depth += c.count("{") - c.count("}")
            if depth <= 0 and re.search(r'[;}]\s*$', c.rstrip()):
                arm_open = False
            continue
        if STMT_ARM_RX.match(c):                   # the chain continues: a new arm, exclusive with the site's
            sibling = True
            offs.add(k)
            depth = c.count("{") - c.count("}")
            arm_open = depth > 0 or not c.rstrip().endswith(";")
            continue
        break                                      # the chain is over; everything below is a genuine successor
    return offs


def _emitted_guard_skips_poll(lines, i, poll_abs):
    """(label, 1-based line of the emitted jump) when a CONDITIONAL JUMP emitted ABOVE the call targets a label
    DEFINED BELOW the poll -- so the emitted poll sits inside the skipped region and executes only when the guard's
    condition holds.  None when no such envelope is provable.

    ⛔ THIS IS THE FOURTH SPECIES OF CENSUS BLINDNESS AND THE ONLY ONE THAT MAKES THE NUMBER TOO BIG (ceo, CEO-1132).
    The other three under-count; this one CREDITS A POLL THAT NEVER RUNS.  The shape is invisible to every reader that
    looks only BETWEEN the call and the poll -- _poll_is_guarded does exactly that -- because the branch is emitted
    ABOVE the call and its landing pad BELOW the poll, so the span between them is perfectly innocent.

    ⛔ MEASURED FROM EMITTED BYTES, NOT FROM THE EMITTER SOURCE (the coo, 2026-09-22, SCRIP built at this landing).
    `./scrip --compile` on a two-procedure Icon witness puts, in EVERY kind 2/3/5 trace tap:
        cmp rax, 0 ; je .Lhelper_α_12_248      <- line 131, the guard on g_trace
        call rt_trace_return_hook              <- line 142, the allocating call
        call rt_gc_poll_asm                    <- line 149, the poll the census was crediting
      .Lhelper_α_12_248:                       <- line 153, the landing pad BELOW the poll
    and `long g_trace = 0` (src/runtime/keywords.c:17) is written only by an explicit &trace assignment
    (builtins/gen_runtime.c:306), so in effectively every program the jump is TAKEN and the poll is stepped over.
    The kind==1 arm carries no guard at all in either file and its poll is unconditional -- the two readings are
    measured from the same assembly file, which is why this rule separates them instead of condemning the whole unit.

    ⛔ THE ERROR IS ONE-DIRECTIONAL THE OTHER WAY FROM THE SIBLING RULE, AND THAT IS DELIBERATE: firing moves a site
    to PARTIAL, which is a DEBT the bar still demands be zero; failing to fire leaves today's reading untouched.  A
    label whose definition this cannot find, or a computed jump target, simply yields None.

    ⛔⭐⭐ THE SECOND CONDITION, AND THE SIX SITES IT GIVES BACK (cto 2026-09-22 late, ceo CEO-1160 overturning
    CEO-1132 for them).  The first cut asked whether the POLL runs on every path and never asked whether the CALL
    does.  Read from the emitted bytes of hb_coexpr_genp_scan.icn, the trace taps are the first instructions of the
    procedure ports recogn_γ and recogn_ω: push rax, push rdx, align-enter, cmp g_trace, je sk, lea rdi, call
    rt_trace_*_hook, call rt_gc_poll_asm, sk: align-leave, pop rdx, pop rax.  The guard sits ABOVE the hook call,
    so the taken path skips the call AND its poll together, and no allocating call precedes the tap in that frame
    (a procedure return is not one).  A safe point is owed only at an allocating call's RETURN: on the non-tracing
    path nothing allocates, on the tracing path the poll dominates the hook's return.  THOSE SIX SITES ARE WHOLE.
    A guard on the PAIR is a guarded allocation with its own poll; the partial shape this rule was written for is a
    jump emitted BETWEEN the call and the poll that lands below the poll -- the poll skipped, the call not.  So the
    jump search now runs from the line after the call to the poll, never above the call.  The cost of the first cut
    was measured before it was withdrawn: it minted a row on the six, hq_icon's 8f26f80a0 cured them into a real
    bug (hb_bignum_length.icn wrong 5 of 5 at stress 1, the fourth conviction of the CEO-1107 shape), and two
    further literal poll_res swaps failed on the same crash.  The selftest plants both shapes: the pair-guard reads
    WHOLE and the between-jump reads PARTIAL, fail-once on the latter."""
    lo, hi = 0, len(lines)
    for j in range(i - 2, -1, -1):                 # the unit above: same boundary style as the poll window
        if lines[j].startswith("}") or lines[j].startswith("/*---"):
            lo = j + 1
            break
    for j in range(poll_abs + 1, len(lines)):
        if lines[j].startswith("}") or lines[j].startswith("/*---"):
            hi = j
            break
    # ⛔ AND THE JUMP MUST ACTUALLY BE EMITTED ON THIS ARM'S PATH, WHICH IS THE HALF A SOURCE READER GETS WRONG.
    # The guard itself is conditional: emit.cpp wraps it `IF(kind == 2 || kind == 3 || kind == 5, ... x86("je", sk))`
    # and xa_flat.cpp wraps it `IF(kind != 1, ...)`.  A call standing in the `kind == 1` arm is therefore NOT jumped
    # over -- measured in the same assembly file that convicted the others: `call rt_trace_call_hook_f` is followed
    # seven lines later by `call rt_gc_poll_asm` with NO branch between them and no landing pad after it.  Condemning
    # that arm would be a false PARTIAL invented by reading the source instead of the bytes.
    arm = _stmt_arm_cond(lines[i - 1])
    jumps = {}
    for j in range(i, poll_abs):
        for m in EMIT_JCC_RX.finditer(lines[j]):
            gov = _governing_if_cond(lines, lo, j, m.start())
            if gov is not None and _disjoint_conds(arm, gov):
                continue                           # this guard is not emitted on the arm the call stands in
            jumps.setdefault(m.group(2), j)
    if not jumps:
        return None
    for j in range(poll_abs + 1, hi):
        for m in EMIT_DEF_RX.finditer(lines[j]):
            if m.group(1) in jumps:
                return (m.group(1), jumps[m.group(1)] + 1)
    return None


def _poll_is_guarded(window_lines, poll_rx, skip=()):
    r"""A poll inside a multi-path unit reaches EVERY path only when nothing selects it.  This tree spells a
    conditional emission `IF(cond, ...)`, so a poll under an IF( -- or under a plain C `if (` -- reaches SOME paths.
    ⛔ THE ERROR IS DELIBERATELY ONE-DIRECTIONAL: an unrecognised guard would report a partial cure as whole, which is
    the defect this row cures, so anything conditional-looking between the call and the poll reads PARTIAL.

    ⛔ AND A SIBLING ARM IS NOT A GUARD ON THE POLL BELOW IT (the coo, 2026-09-22).  `skip` carries the offsets
    _stmt_sibling_offsets/_ternary_sibling_offsets proved are ALTERNATIVES to the call, and an `else if (kind == 2)`
    line matches `\bif\s*\(` exactly as a real guard does.  Counting one made xa_flat.cpp:427 read PARTIAL although
    its poll is unconditional in the emitted bytes -- the same confusion of exclusive arms with sequence that this
    census has now met at four levels, here on the LAST reader that had not been taught it."""
    seen = False
    for k, wl in enumerate(window_lines):
        m = poll_rx.search(wl)
        if m:
            head = wl[:m.start()]
            return seen or "IF(" in head or bool(re.search(r'\bif\s*\(', head))
        if k in skip:
            continue
        if "IF(" in wl or re.search(r'\bif\s*\(', wl):
            seen = True
    return False


def _lit_free(s, q=None):
    """(the line with string/char literal bodies and a // comment removed, the quote state still open at its end).
    ⛔ NOT DECORATION AND MEASURED BEFORE IT WAS WRITTEN: 21 lines under src/templates count differently naive, and
    two of them decide a paren depth -- bb_scan_bal.cpp:61 and :108 hold (long)'(' and :66/:113 hold (long)')', so a
    naive count reads the BALANCE-scanning templates as opening and closing groups that are not there.  The quote
    state is carried across lines because a C string may be split over several, and an unterminated quote swallowing
    the rest of a line is exactly how a depth walk silently desynchronises."""
    out = []; i = 0; n = len(s)
    while i < n:
        c = s[i]
        if q:
            if c == "\\":
                i += 2; continue
            if c == q:
                q = None
            i += 1; continue
        if c in ('"', "'"):
            q = c; i += 1; continue
        if c == "/" and i + 1 < n and s[i + 1] == "/":
            break
        out.append(c); i += 1
    return "".join(out), q


def _paren_delta(s, q=None):
    """(net '(' minus ')' on this line, the quote state still open at its end)."""
    t, q2 = _lit_free(s, q)
    return t.count("(") - t.count(")"), q2


TERNARY_LOOKBACK = 60


def _ternary_sibling_offsets(lines, i, window_lines, counts=None):
    """Offsets into `window_lines` whose emitted call stands in a DIFFERENT ARM of a ternary the call at 1-based line
    `i` also stands in -- an ALTERNATIVE to the site, never a successor to it, so it is not an intervening call and
    must not stop the poll window.

    ⛔ THIS IS THE BLIND SPOT COO-143 NAMED BY HAND RATHER THAN ROUNDING AWAY, AND MECHANIZING IT IS THE WHOLE GAP
    BETWEEN THE MECHANICAL ARM'S 148 AND THE 149 THE ceo PUBLISHED (CEO-1119).  bb_call_value.cpp:130 is the last
    line of the THEN arm of the ternary opened at :126; the ELSE arm opens at :131 with a leading ':' and RUNS ON
    through :134, which carries the call.  A stop keyed on a line's leading character exempts :131 and then trips on
    :134 -- the same confusion of EXCLUSIVE ARMS with SEQUENCE that COO-142 recorded in the expansion-path reader and
    COO-143 recorded in this one, now at its third level.

    THE MODEL IS AN ARM INDEX PER PAREN DEPTH, and it is the third one written: each '?' and each ':' at depth d
    starts the next arm of the ternary living at that depth, and the whole chain `a ? X : b ? Y : Z` is one ternary
    with four arm indices.  The call records the arm it stands in at EVERY depth that has one; a later position is an
    alternative when any of those depths is still open and has moved on to a different arm.  Leaving a depth (a ')'
    below it, or a ';') forgets it, so a fresh ternary reopening at the same depth can never be mistaken for the
    site's own.

    ⛔ TWO EARLIER SHAPES OF THIS RULE WERE WRONG IN THE DIRECTION THAT CLEARS SITES, AND BOTH WERE CAUGHT BY
    MEASURING AGAINST THE HAND-READ NAME SET RATHER THAN AGAINST A COUNT.  (a) A LINE-GRANULAR reader that looked
    only ABOVE the site for its '?' missed all five sites whose '?' is on their OWN line -- bb_iterate.cpp:27, which
    is `+ (key ? x86("call", ...)` with three ':' arms below it, and bb_field_get.cpp:21, where the sibling that
    matters is the OUTER ternary's ':' on the next line at a SHALLOWER depth -- and re-nominated them.  (b) A reader
    that latched an 'in alternative' flag the moment it saw a ':' at an open-arm depth CLEARED THREE SITES A HAND
    READ CONVICTED: at bb_rev_assign_var.cpp:14 the guard's ':' on line 15 opens the arm the site at :19 LIVES IN,
    so every later line is that same arm -- a SUCCESSOR -- and the real intervening call at :26 was being exempted.
    An arm the site is inside is not an arm the site is excluded from.

    ⛔ AND THE WALK IS LITERAL-FREE: bb_scan_bal.cpp holds (long)'(' and (long)')' as CHAR LITERALS, which a naive
    depth count reads as opening and closing the very group this rule is tracking."""
    site = i - 1
    if site < 0 or site >= len(lines):
        return set()
    m = CALL_RX.search(lines[site])
    if m is None:
        return set()

    lo = max(0, site - TERNARY_LOOKBACK)
    for j in range(site - 1, lo - 1, -1):          # never read across a unit boundary
        if lines[j].startswith("}") or lines[j].startswith("/*---"):
            lo = j + 1
            break

    depth = 0
    chain = {}             # paren depth -> index of the ternary arm currently open at that depth
    at_call = {}           # the same, frozen at the call: the arms the SITE stands in
    q = None

    def forget(below):
        for d in [x for x in chain if x > below]:
            chain.pop(d, None)
            at_call.pop(d, None)

    def walk(text):
        nonlocal depth
        for ch in text:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                forget(depth)
            elif ch == ";":
                forget(depth - 1)
            elif ch in "?:":
                chain[depth] = chain.get(depth, 0) + 1

    def alternative():
        return any(d in chain and chain[d] != a for d, a in at_call.items())

    for j in range(lo, site):
        c, q = _lit_free(lines[j], q)
        walk(c)
    head, q = _lit_free(lines[site][:m.start()], q)
    walk(head)
    at_call.update(chain)                          # the arms the site itself stands in
    rest, q = _lit_free(lines[site][m.start():], q)
    walk(rest)

    # ⛔ THE WINDOW'S BUDGET COUNTS ONLY THE SITE'S OWN PATH (the cto 2026-10-08, bb_match_defer.cpp:307): `counts`, when given, gets
    # one entry per window line -- the x86 tokens on it that are NOT in another arm of the site's ternary. The budget of
    # POLL_WINDOW_X86 is a distance in EMITTED code, and an alternative arm is never emitted on the site's path, so its tokens are no
    # distance at all: rt_patv_defer_open_entry heads the first of four arms, the three others hold some 17 x86 calls, and the one
    # shared poll after the ternary's close stood outside a window those arms had spent. One literal-free pass per line serves both
    # readings; the call's split point is never inside a literal, so the walk is the one the two-part reading made.
    off = set()
    for k, wl in enumerate(window_lines):
        c, q2 = _lit_free(wl, q)
        mk = CALL_RX.search(wl)
        cut = len(_lit_free(wl[:mk.start()], q)[0]) if mk else None
        marks = sorted({t.start() for t in X86_TOKEN_RX.finditer(c)} | ({cut} if cut is not None else set()))
        p, own = 0, 0
        for t in marks:
            walk(c[p:t])
            p = t
            alt = alternative()
            if t == cut and alt:
                off.add(k)
            if X86_TOKEN_RX.match(c, t) and not alt:
                own += 1
        walk(c[p:])
        q = q2
        if counts is not None:
            counts.append(own)
    return off


# ⛔⭐ THE COMMON-TAIL POLL, AND IT IS THE FIRST MEASURED SHAPE THAT MAKES THIS COUNT TOO *SMALL* (cfo 2026-09-23,
# CFO-151, chunk B).  Every upper-bound reason the headline names can only INFLATE the number; this one DEFLATES it,
# so the headline's own sentence -- "each of which can only inflate it" -- is true of those three reasons and false
# of the count.
# THE SHAPE: a template whose branches are BRACED BLOCKS -- `if (a) { call X; } else if (b) { call Y; } else { call
# Z; }` with ONE spill and ONE poll BELOW the whole chain -- emits, on every arm, call -> spill -> poll.  The window
# stops at the first intervening emitted call, and the two sibling-arm exemptions above it read TERNARY arms
# (_ternary_sibling_offsets) and single-line `else if` statements (_stmt_sibling_offsets), neither of which is a
# braced block one chain out from the site, so X's window stops at Y and the common tail is never reached.
# MEASURED, NOT ARGUED, on SCRIP 5bcb99a7b: bb_call_fn.cpp:207 reads UNPOLLED at EVERY --poll-window from 12 to 120
# (the knob is INERT on this tree, which is worth knowing on its own), and the EMITTED mode-4 output for
# `p(hello). q(42). main :- p(hello), q(42), write(ok), nl.` is
#     call rt_pl_dop_unify_cs@PLT | 3 rtccb reloads | mov [rbp+64], rax | mov [rbp+72], rdx |
#     cmp al, 104 ; je p$2F1_step | 3 rtccb writebacks | call rt_gc_poll_asm@PLT
# -- the poll is SIX instructions after the call, and [rbp+64] is inside `.Lgcmap_p$2F1`'s `[0 .. 80) GC_LAY_DESCR`
# run (frame_bytes 192, header 80, value_bytes 96, flags GC_FRAME_MAP_LAYOUT), which gc_walk_interior visits by KIND at
# every 16 bytes with no reference to the slot's declared role -- the role text is --dump-zeta commentary and
# frame_layout.c MERGES adjacent same-kind runs, so it cannot survive into the map at all.  :210 and :216 (the
# latter reached with SCRIP_NO_CU=1) are byte-identical in shape.
# ⛔ IT NOMINATES A SITE FOR A HAND READ AND CLEARS NOTHING, and two reasons why are already known: the `je` to
# ω above the tail means the FAIL path skips the poll, so the honest column for those three is partially_polled
# and not polled; and bb_call_fn.cpp:141's ZD arm carries `if (_.op_sb) { ... return s; }` ABOVE its tail, an early
# return no brace-depth reader can see.  Nothing here moves a count, by design -- CEO-1116 set the stop and the
# headline is the ceo's to move.
def _brace_depth_at(lines, lo, hi):
    """depth at the START of each 1-based line in [lo, hi], relative to lo, counted LITERAL-FREE so that a template's
    (long)'{' is a character and not a brace (the same reason _paren_delta exists)."""
    at = {}; d = 0
    for k in range(lo, min(hi, len(lines)) + 1):
        at[k] = d
        for ch in _lit_free(lines[k - 1])[0]:
            if ch == "}":
                d -= 1
            elif ch == "{":
                d += 1
    return at


def _common_tail_poll(lines, i, unit, poll_rx):
    """(poll_line, site_depth, tail_depth, arm_calls) when the poll below this site's whole if/else chain is the
    site's own emitted successor, else None.  THE RULE IS TWO INEQUALITIES AND NO PATTERN MATCH: the poll stands
    STRICTLY SHALLOWER than the call (every arm of the chain closed above it) and EVERY intervening emitted call
    stands STRICTLY DEEPER than the poll (each had to enter a block that closed again before the tail).  Both
    directions are planted in --selftest: the nested braced chain must be NAMED, and a plain successor standing at
    the tail's own depth must NOT be -- that second arm is the one that keeps this from clearing sites in sequence."""
    end = unit[3] if unit and len(unit) > 3 else None
    if end is None:
        end = next((k for k in range(i, len(lines) + 1) if lines[k - 1].startswith("}")), len(lines))
    at = _brace_depth_at(lines, i, end)
    poll = next((k for k in range(i + 1, end + 1) if poll_rx.search(lines[k - 1])), None)
    if poll is None or at.get(poll, 0) >= at.get(i, 0):
        return None
    arm_calls = 0
    for k in range(i + 1, poll):
        if CALL_RX.search(lines[k - 1]) and not poll_rx.search(lines[k - 1]):
            if at.get(k, 0) <= at[poll]:
                return None
            arm_calls += 1
    return (poll, at[i], at[poll], arm_calls)


_NORETURN_CACHE = {}


def declared_noreturn(sym, root=None):
    """True when src/runtime DEFINES `sym` on a line carrying __attribute__((noreturn)) or _Noreturn -- read from the
    tree at census time, never from a hand list, so the exclusion expires with its source (cto 2026-09-23: a call
    that never returns has NO return point, and a poll "after" it is dead bytes that would read POLLED by presence;
    rt_ab_undef_fn_stub is the one such site in the emitter today, bb_call_proc_staged's undefined-function stub)."""
    r = root or ROOT
    if r not in _NORETURN_CACHE:
        found = set()
        base = os.path.join(r, "src", "runtime")
        rx = re.compile(r"(?:__attribute__\s*\(\s*\(\s*noreturn\s*\)\s*\)|_Noreturn)[^;{]*?\b([A-Za-z_][A-Za-z0-9_]*)\s*\(")
        for dp, _dn, fns in os.walk(base):
            for fn in fns:
                if not fn.endswith((".c", ".h")):
                    continue
                try:
                    for ln in open(os.path.join(dp, fn), encoding="utf-8", errors="replace"):
                        for m in rx.finditer(ln):
                            found.add(m.group(1))
                except OSError:
                    pass
        _NORETURN_CACHE[r] = found
    return sym in _NORETURN_CACHE[r]


def census_safe_points(so, emitter_files, poll_window=12, poll_helper="", out=print, allocating=None, list_polled=False):
    if allocating is None:
        allocating = allocating_entries_from_binary(so, out)
        if allocating is None:
            return 2
    sites = emitter_call_sites(emitter_files)
    if not sites:
        out("CENSUS safe-points REFUSED(2): no x86(\"call\", ...) sites found in the emitter files -- wrong tree?"); return 2
    poll_rx = re.compile(r"g_gc_pending|rt_gc_poll" + (("|" + re.escape(poll_helper)) if poll_helper else ""))
    # ⛔⭐ THE BASE WINDOW STOPS AT AN INTERVENING EMITTED CALL, AND SINCE CEO-1119 THAT IS THE CRITERION, NOT A
    # KNOB.  A poll that follows a LATER call is THAT call's safe point, not this one's -- the ceo RULED the
    # reading correct for the expansion window (CEO-1116) and, on the measured delta, for the base predicate
    # (CEO-1119): it takes polled 156 -> 149 and unpolled 97 -> 104 on SCRIP 20424784f.  THE RISE IS THE
    # INSTRUMENT GETTING HONEST, NOT THE TREE GETTING WORSE, and gc_census_baseline.tsv carries that ruling at
    # the file so the next reader meets it there.  SCRIP_GC_CENSUS_BASE_CALL_STOP=0 reproduces the pre-CEO-1119
    # reading for an auditor comparing across the change; it is an escape hatch, never the default.
    base_call_stop = os.environ.get("SCRIP_GC_CENSUS_BASE_CALL_STOP", "1") != "0"
    # ⛔ THE POLL HELPERS ARE A FAMILY AND THE rec FAMILY DOES NOT CALL rt_gc_poll AT ALL (the ceo, CEO-1118).
    # x86_rt_gc_poll{,_res,_rec_sigma,_rec_sigma_word,_rec_sigma_pair,_rec1} all emit a safe point, and the rec forms
    # emit x86("call", "rt_gc_point_arr_c", ...) -- a line that MATCHES CALL_RX and does NOT match poll_rx, so a stop
    # keyed on poll_rx alone would truncate the window AT A POLL and mint the FALSE UNPOLLED the exemption exists to
    # prevent.  MEASURED SCOPE, 2026-09-22 on b335a917e: exactly three such lines exist, x86_asm.h:2228, :2247 and
    # :2261, all of them the helpers' own DEFINITIONS; in the templates the site reads x86_rt_gc_poll_rec_sigma(0),
    # which carries the rt_gc_poll text and is not a CALL_RX line at all.  No nomination moved when this widened --
    # the exposure was latent, not live.  IT IS USED ONLY FOR THE STOP EXEMPTION, NEVER FOR THE POLLED DECISION:
    # widening what counts as a poll would move the published headline, which is not this knob's business.
    stop_poll_rx = re.compile(poll_rx.pattern + r"|rt_gc_point_arr")
    forms = collections.Counter()
    total = alloc_sites = polled = 0; unpolled = []; unresolved = []
    resolved = []
    partial = []; multi = []; tails = []; noreturn_sites = []
    texts = {}
    for f in set(x[0] for x in sites):
        try:
            texts[f] = open(f, encoding="utf-8", errors="replace").read()
        except OSError:
            pass
    units_by_file = {f: emission_units(t) for f, t in texts.items()}
    for f, i, syms, lines, rule in sites:
        total += 1
        if not syms:
            unresolved.append(f"{os.path.relpath(f, ROOT)}:{i}")
            continue
        if rule:
            al = sorted(set(x for x in syms if x in allocating))
            resolved.append(f"{os.path.relpath(f, ROOT)}:{i} via {rule}: {len(syms)} candidate(s), "
                            + (f"{len(al)} allocating: {', '.join(al[:6])}" + (f" ... +{len(al) - 6} more" if len(al) > 6 else "")
                               if al else "none allocating"))
        if not any(s in allocating for s in syms):
            continue
        if all(declared_noreturn(s) for s in syms if s in allocating):
            noreturn_sites.append(f"{os.path.relpath(f, ROOT)}:{i}:{'/'.join(s for s in syms if s in allocating)}")
            continue
        alloc_sites += 1
        # A POLL BELONGS TO THE CALL'S OWN FUNCTION.  The window is source lines after the call, so without a stop it
        # walks out of the emitter routine and reads the NEXT routine's poll as this site's.  Measured 2026-09-17 on
        # SCRIP e625d1b35 by the coo: bb_call_proc_staged.cpp:88 (rt_proc_call_epilogue_named_γ/ω, allocating) read
        # POLLED off the g_gc_pending lea in stage_arg_inline, seven lines below and two functions away -- a false
        # green, the worst direction for this census.  The window stops at the first line that starts a new routine in
        # this tree's style: a column-0 closing brace or a column-0 /*---- separator.
        window_lines = _window_lines(lines, i, poll_window)
        if base_call_stop and os.environ.get("SCRIP_GC_CENSUS_WINDOW_UNIT", "x86") != "lines":
            window_lines = _path_window_lines(lines, i)
        stop = len(window_lines)
        # ⛔ THE SIBLING-ARM REGION, COMPUTED ONCE PER SITE (the blind spot COO-143 named; see
        # _ternary_sibling_offsets).  Offsets here are ALTERNATIVES to the site, not successors, so a call on one of
        # them is not an intervening call.  MEASURED SCOPE on SCRIP 20424784f: this moves EXACTLY ONE site,
        # bb_call_value.cpp:130, which is the whole gap between the mechanical arm's 148 and the hand-read 149 the
        # ceo published (CEO-1119).  Empty unless base_call_stop, so the pre-stop census is untouched by it.
        sibling = _ternary_sibling_offsets(lines, i, window_lines) if base_call_stop else set()
        # ⛔ AND THE SAME EXCLUSIVITY SPELLED AS STATEMENTS, WHICH COO-146 NAMED AND DID NOT MECHANIZE.  See
        # _stmt_sibling_offsets: an `else if` arm is an ALTERNATIVE, never a successor.  MEASURED SCOPE at this
        # landing: it moves the six trace-tap arms in emit.cpp and xa_flat.cpp and nothing else in the tree.
        if base_call_stop:
            sibling = sibling | _stmt_sibling_offsets(lines, i, window_lines)
        for k, wl in enumerate(window_lines):
            if wl.startswith("}") or wl.startswith("/*---"):
                stop = k
                break
            # ⛔ THE SAME DEFECT ONE LEVEL DOWN, AND IT IS MEASURED HERE RATHER THAN ASSUMED.  The expansion-site
            # window (_window_after) has stopped at the first intervening emitted call since 2026-09-22, because a
            # poll that follows a LATER call is that call's safe point and not this one's -- the ceo RULED that
            # reading correct (CEO-1116, 2026-09-22, on the coo's ask).  The BASE window did not carry the stop, so
            # this knob exists to COUNT what adding it would reclassify before anyone moves the published headline.
            # Default OFF: with the variable unset this census is byte-for-byte what it was, which is the whole point
            # of measuring a criterion change instead of landing one.
            # ⛔ AND THE STOP EXEMPTS A LINE THAT CARRIES A POLL, WHICH _window_after DOES NOT: the poll helpers in
            # src/templates/x86/x86_asm.h are THEMSELVES spelled x86("call", "rt_gc_poll_asm", ...), so a stop that
            # broke on any CALL_RX line would exclude the very poll it was looking at and mint a FALSE UNPOLLED --
            # an error in the direction that INFLATES this delta, i.e. that flatters the row measuring it.
            # ⛔ AND THE SECOND EXEMPTION WAS PAID FOR THE SAME WAY, BY READING THE SIXTEEN NAMES THE FIRST ARM
            # PRINTED: a line beginning ":" or "?" is a TERNARY ARM, an ALTERNATIVE to the call above it and not a
            # successor to it, so exactly one of the two is ever emitted and a poll below is the safe point for
            # whichever one that is.  Without this exemption the arm called bb_field_get.cpp:21 unpolled because
            # line 22 is `: x86("call", "icn_field_get", ...)`, the else arm of its own ternary, and bb_iterate.cpp
            # 27/28/29 unpolled off a four-way `key ? ... : lvv ? ... : lv ? ... : ...` chain in which every line is
            # an alternative.  Six of sixteen were this artifact -- the SAME confusion of exclusive arms with
            # sequence that COO-142 recorded in the expansion-path reader, committed again one level down.
            if base_call_stop and CALL_RX.search(wl) and not stop_poll_rx.search(wl) \
                    and k not in sibling \
                    and not _mutually_exclusive(_if_guard(lines[i - 1]), _if_guard(wl)):
                stop = k
                break
        window = "\n".join(window_lines[:stop])
        hit = poll_rx.search(window)
        # ⛔ WHERE the poll is, not merely THAT it is -- the guard reader below needs its line to ask what jumps
        # over it.  window_lines[k] is lines[i + k], the call standing at lines[i - 1].
        poll_abs = None
        if hit:
            for _k, _wl in enumerate(window_lines[:stop]):
                if poll_rx.search(_wl):
                    poll_abs = i + _k
                    break
        guard = _emitted_guard_skips_poll(lines, i, poll_abs) if poll_abs is not None else None
        # ⛔ THE CALL'S OWN LINE, AFTER THE CALL (the coo 2026-10-03): every window starts on the NEXT line, so `x86("call", X) +
        # x86_rt_gc_poll() + x86_omega()` written on one line read UNPOLLED though it emits call -> poll, and the same text split
        # across lines read POLLED -- a reading that moved with layout. The text after the call's closing paren, cut at a later call
        # on the line, is read first; a poll there with no x86("j..") before it is the call's safe point.
        _m0 = CALL_RX.search(lines[i - 1])
        _e0 = _call_close(lines[i - 1], _m0) if _m0 else None
        own = lines[i - 1][_e0 + 1:] if _e0 is not None else ""
        _n0 = CALL_RX.search(own)
        if _n0 and not stop_poll_rx.search(own[_n0.start():]):
            own = own[:_n0.start()]
        own_hit = poll_rx.search(own)
        if own_hit and not re.search(r'x86\(\s*"j', own[:own_hit.start()]):
            hit, poll_abs, guard = own_hit, i - 1, None
        # ⛔ HOW MANY PATHS DOES THIS ONE SOURCE LINE EMIT?  A site inside a unit that expands more than once is
        # spliced into every one of those paths, and a poll in the shared body is not evidence that all of them
        # carry it.  See the block above emission_units for what this bound does and does not claim.
        unit = unit_of(units_by_file.get(f, []), i)
        paths = expansion_lines(unit, f, texts) if unit else []
        npaths = max(1, len(paths))
        tail = _common_tail_poll(lines, i, unit, poll_rx)
        name = f"{os.path.relpath(f, ROOT)}:{i}:{'/'.join(s for s in syms if s in allocating)}" \
               + (f" [{rule}, {len(syms)} candidate(s)]" if rule else "")
        if npaths > 1:
            multi.append(f"{name} in {unit[0]} {unit[1]}() <= {npaths} emitted path(s) at "
                         + ", ".join(f"{os.path.relpath(pf, ROOT)}:{pl}" for pf, pl in paths[:6])
                         + (f" ... +{npaths - 6} more" if npaths > 6 else ""))
        if hit and guard:
            # ⛔ THE POLL IS EMITTED AND IS STEPPED OVER.  Crediting it is the ONE species of this census's blindness
            # that makes the headline TOO BIG (ceo, CEO-1132), so it lands in the column the bar still wants at zero
            # rather than in polled.  The cure is to move the poll below the landing pad, not to change this reader.
            partial.append(f"{name}: the poll is emitted INSIDE a conditional skip -- "
                           f"x86(\"j..\", {guard[0]}) at {os.path.relpath(f, ROOT)}:{guard[1]} jumps PAST it to "
                           f"x86(\"def\", {guard[0]}) below, so it runs only when that guard holds")
        elif not hit and npaths == 1:
            unpolled.append(name)
            if tail:
                tails.append((name, tail))
        elif hit and npaths == 1:
            polled += 1
            forms[_poll_form(lines[poll_abs])] += 1
            if list_polled:
                out(f"  POLLED {name} form={_poll_form(lines[poll_abs])} poll_at={os.path.relpath(f, ROOT)}:{poll_abs + 1}")
        elif not hit:
            # THE OTHER HALF OF THE SAME DEFECT, AND THE ONE A FIXER MEETS FIRST.  The natural cure for the cto's
            # case is to poll the SAFE expansion paths and leave the unrooted one alone -- and then the shared body
            # carries no poll at all, so the old predicate read the site plain UNPOLLED and the partial cure was
            # invisible in the other direction.  Read the expansion sites' own windows: none polled is unpolled, all
            # polled is whole, some polled is PARTIAL and is named with its ratio.
            n_polled = sum(1 for pf, pl in paths
                           if poll_rx.search("\n".join(_window_after(texts[pf].split("\n"), pl, poll_window))))
            if n_polled == 0:
                unpolled.append(name)
                if tail:
                    tails.append((name, tail))
            elif n_polled == len(paths):
                polled += 1
                forms["(polled on every expansion path)"] += 1
            else:
                partial.append(f"{name} in {unit[0]} {unit[1]}(): {n_polled} of {len(paths)} expansion site(s) poll")
        elif _poll_is_guarded(window_lines[:stop], poll_rx, sibling):
            # The poll is selected by something; it reaches SOME of the unit's paths.  A declared partial is honest,
            # a partial counted as whole is DARK wearing a number (ceo, CEO-1109).
            partial.append(f"{name} in {unit[0]} {unit[1]}(): poll is guarded and the unit emits <= {npaths} paths")
        else:
            polled += 1
            forms[_poll_form(lines[poll_abs]) if poll_abs is not None else "unclassified"] += 1
            if list_polled and poll_abs is not None:
                out(f"  POLLED {name} form={_poll_form(lines[poll_abs])} poll_at={os.path.relpath(f, ROOT)}:{poll_abs + 1}")
    out(f"CENSUS safe-points emitter_call_sites={total} allocating_call_sites={alloc_sites} polled={polled} partially_polled={len(partial)} unpolled={len(unpolled)} multi_path_sites={len(multi)} noreturn_sites={len(noreturn_sites)} unresolved={len(unresolved)} want unpolled=0 partially_polled=0 unresolved=0 (poll = g_gc_pending or rt_gc_poll{' or ' + poll_helper if poll_helper else ''} within {poll_window} lines after the call)")
    assert polled + len(partial) + len(unpolled) == alloc_sites, "safe-points: the four columns must partition the denominator"
    out(f"CENSUS safe-points IDENTITY polled + partially_polled + unpolled == allocating_call_sites ({polled} + {len(partial)} + {len(unpolled)} == {alloc_sites})")
    for n in noreturn_sites:
        out(f"  NORETURN {n} -- every allocating candidate is DEFINED __attribute__((noreturn)) in src/runtime: the call has no return point, so no safe point can stand at one; excluded from the denominator and NAMED")
    # ⛔⭐ THE FORM HISTOGRAM, BESIDE THE COUNT AND NOT IN A SEPARATE TOOL (item iv of this census's own row).
    # A polled/unpolled count is BLIND TO A FORM SWAP, which is how a contaminated tree read 177 exactly as the
    # clean one did.  The forms are not interchangeable and the histogram is what makes a swap visible at all.
    out("CENSUS safe-points POLL FORMS over the {} polled site(s): ".format(polled)
        + ("; ".join(f"{k}={v}" for k, v in sorted(forms.items(), key=lambda kv: (-kv[1], kv[0]))) or "none"))
    # ⛔⭐ AND THE HEADLINE NAMES ITS OWN UPPER-BOUND REASONS RATHER THAN LEAVING THEM IN A LEDGER (item: "the
    # headline prints its own three upper-bound reasons").  Two of the four species found on 2026-09-22 are CURED
    # in the reader and are not listed here -- listing a cured reason is how a caveat outlives its cause.  These
    # three are LIVE, and each one can only make the number TOO BIG.
    out("CENSUS safe-points \u26d4 THE COUNT IS AN UPPER BOUND, FOR THREE LIVE REASONS, EACH OF WHICH CAN ONLY "
        "INFLATE IT: (1) PRESENCE, NOT CORRECTNESS (ceo CEO-1133) -- this census reads whether a poll is EMITTED, "
        "never whether it FIRES; the cfo measured x86_rt_gc_poll_res at bb_call_value 67/70 adding ZERO collections "
        "over 818 cells with a name set identical to no poll at all, and a site can be credited POLLED, never fire, "
        "and still be broken by the poll's presence. (2) MULTI-PATH ({} site(s) here): a poll in a body that is "
        "SPLICED INTO SEVERAL emitted paths is not evidence that every path carries it; the path count is itself an "
        "upper bound. (3) LINE PROXIMITY: the window is {} SOURCE LINES after the call, not a control-flow proof, so "
        "a poll separated from its call by an unmodelled branch still reads as that call's safe point -- the "
        "conditional-skip reader closes the one shape of that which was measured, not the class."
        .format(len(multi), poll_window))
    out("CENSUS safe-points MULTI-PATH NOTE (the cto's finding, the coo's reader, 2026-09-22): multi_path_sites counts "
        "allocating call sites written ONCE in a unit that is EXPANDED MORE THAN ONCE, so one source line is spliced "
        "into every one of those paths. THE PATH COUNT IS AN UPPER BOUND, not an exact figure -- emit.cpp's icn_trace_tap "
        "expands at six sites but its call lines sit in mutually exclusive arms selected by the caller, so the kind==5 "
        "call at :2914 is reached by one of the six. "
        "\u26d4 THIS NOTE MISNAMED THAT SITE AS kind==2 UNTIL 2026-09-22 (kind 2 is :2913, rt_trace_return_hook; :2914 "
        "is rt_trace_gen_fail_hook) -- corrected in place by the coo, because an instrument's own prose is read as "
        "evidence and a wrong name in it is a wrong measurement waiting to be quoted. "
        "\u26d4\u2b50 AND partially_polled IS NOW ACTUALLY POPULATED: it read 0 at every site for as long as it existed, "
        "so the sentence promising it protected the headline was TRUE OF THE CODE AND FALSE OF THE READING. Since this "
        "landing a poll emitted INSIDE a conditional skip -- the jump above the call, its landing pad below the poll -- "
        "lands there instead of in polled, which is the one species of this census's blindness that made the number too "
        "BIG (ceo CEO-1132).")
    cap = len(unpolled) if os.environ.get("SCRIP_GC_CENSUS_LIST_ALL") == "1" else 25
    for u in unpolled[:cap]:
        out(f"  UNPOLLED {u}")
    if len(unpolled) > cap:
        out(f"  ... {len(unpolled) - cap} more unpolled -- SCRIP_GC_CENSUS_LIST_ALL=1 prints every one (a count without names cannot be triaged, and 208 sites is a worklist, not a verdict)")
    # ⛔⭐ THE COMMON-TAIL NOMINATIONS, BESIDE THE COUNT AND MOVING NOTHING.  See _common_tail_poll above for the
    # emitted-asm measurement that earned this block and for what a nomination does and does not claim.
    if tails:
        out("CENSUS safe-points \u26d4\u2b50 COMMON-TAIL POLL: {} of the {} UNPOLLED site(s) stand in an if/else chain of "
            "BRACED BLOCKS whose ONE poll sits BELOW the whole chain, so the emitted code for every arm is call -> spill -> "
            "poll while this reader stops at the first intervening ARM's call. THIS IS THE FIRST MEASURED SHAPE THAT MAKES "
            "THE HEADLINE TOO SMALL -- the three upper-bound reasons above can only inflate it, so the count is not a bound "
            "in either direction. \u26d4 IT NOMINATES A SITE FOR A HAND READ AND CLEARS NOTHING: no count moves here, and "
            "the cfo measured the emitted mode-4 output of three of the four POLLED ON THE SUCCESS PATH AND SKIPPED ON THE "
            "FAIL PATH (the `je` to \u03c9 sits above the tail), which is partially_polled and not polled. \u26d4\u26d4 "
            "BEFORE POLLING A SITE NAMED HERE, READ ITS EMITTED ASM: a second poll six instructions after the first moves "
            "this census BY PRESENCE ALONE, which is the class CEO-1169 named one level up.".format(len(tails), len(unpolled)))
        for _name, (_p, _d0, _dp, _nc) in tails:
            out(f"  COMMON-TAIL {_name} -> poll at line {_p} (site depth {_d0}, tail depth {_dp}, {_nc} exclusive-arm call(s) between)")
    _pcap = len(partial) if os.environ.get("SCRIP_GC_CENSUS_LIST_ALL") == "1" else 25
    for u in partial[:_pcap]:
        out(f"  PARTIAL {u}")
    if len(partial) > _pcap:
        out(f"  ... {len(partial) - _pcap} more partially polled -- SCRIP_GC_CENSUS_LIST_ALL=1 prints every one")
    if os.environ.get("SCRIP_GC_CENSUS_LIST_ALL") == "1":
        for u in multi:
            out(f"  MULTI-PATH {u}")
    elif multi:
        out(f"  {len(multi)} MULTI-PATH site(s) -- SCRIP_GC_CENSUS_LIST_ALL=1 names every one with its expansion sites")
    for r in resolved:
        out(f"  RESOLVED {r}")
    for u in unresolved[:10]:
        out(f"  UNRESOLVED {u} (the call target is computed; name it with a literal or tell the census)")
    COUNTS.setdefault("safe-points", {}).update({"unpolled": len(unpolled), "unresolved": len(unresolved),
                                                 "partially_polled": len(partial), "multi_path_sites": len(multi)})
    ok = not unpolled and not unresolved and not partial
    out("CENSUS safe-points NOTE (the cfo, 2026-09-17): A SITE COUNT IS NOT A COVERAGE MEASURE. An Icon allocation loop "
        "reaches NO safe point at all -- the shielded rt_gc_point_arr sites are SNOBOL4 and Prolog by-name dispatch points "
        "and Icon's every-do loop contains none -- so with the allocator silent it collects ONCE (861920 KB RSS) where "
        "origin collected five times (157144 KB). The RATE, collections-per-program on an allocation loop, lives in "
        "test_gate_gc_every_allocating_runtime_entry_returns_to_a_safe_point.sh; read it beside this number, never instead.")
    out(f"CENSUS safe-points {'GREEN' if ok else 'RED'}")
    return 0 if ok else 1


COV_STRESS = "64"   # the census needs collections to HAPPEN, not to be paced hard; 64 keeps the default witness under 2 s

COVERAGE_TOKENS = [  # (token, what it counts; Rule 2 and Rule 2b)
    ("words_scanned", "stack and spine words visited without a map (Rule 2: the collector walks maps, not words)"),
    ("interior_words", "mark-worklist payload words visited by the same sniff (Rule 2b: every heap block kind gets a typed visitor)"),
]


def census_coverage(scrip, program, mode="m3", out=print, env_extra=None, cov_text=None):
    """run `program` under stress + coverage and read the [GC-COV] lines (or grade `cov_text` directly: the selftest)"""
    if cov_text is None:
        if not (scrip and os.path.exists(scrip)):
            out(f"CENSUS coverage REFUSED(2): no scrip binary at {scrip}"); return 2
        env = dict(os.environ); env.update({"SCRIP_GC_STRESS": COV_STRESS, "SCRIP_GC_COVERAGE": "1"}); env.update(env_extra or {})
        try:
            r = subprocess.run([scrip, program], capture_output=True, text=True, env=env, timeout=120, stdin=subprocess.DEVNULL)
        except (OSError, subprocess.TimeoutExpired) as e:
            out(f"CENSUS coverage REFUSED(2): the witness run failed: {e}"); return 2
        cov_text = r.stderr
    lines = [l for l in cov_text.split("\n") if "[GC-COV]" in l]
    if not lines:
        out("CENSUS coverage REFUSED(2): no [GC-COV] line printed -- no collection ran under SCRIP_GC_STRESS=64, nothing measured"); return 2
    red = 0
    for token, why in COVERAGE_TOKENS:
        rx = r"(?<![A-Za-z_])" + token + r"=(\d+)"
        missing = [l for l in lines if not re.search(rx, l)]
        nonzero = [l for l in lines if re.search(r"(?<![A-Za-z_])" + token + r"=([1-9]\d*)", l)]
        out(f"CENSUS coverage gc_cov_lines={len(lines)} without_{token}={len(missing)} {token}_nonzero={len(nonzero)} want 0 and 0 -- {why}")
        for l in (missing[:2] + nonzero[:2]):
            out("  " + l.strip()[:160])
        COUNTS.setdefault("coverage", {})["lines_without_or_nonzero_" + token] = len(missing) + len(nonzero)
        red += len(missing) + len(nonzero)
    COUNTS["coverage"]["red"] = 1 if red else 0
    out(f"CENSUS coverage {'GREEN' if red == 0 else 'RED'} (both tokens over {len(lines)} line(s))")
    return 0 if red == 0 else 1


CALLBACK_RX = re.compile(r"(?<![A-Za-z0-9_])(rt_call_(?:proc_descr|arr[A-Za-z0-9_]*|value[A-Za-z0-9_]*))\s*\(")


def _marker_spans(src, marker):
    """(start, end) offsets of every MARKER( ... ) and MARKER_V( ... ) span, paren-matched -- a call is wrapped only when it lies inside one.
       The _V variant COUNTS (ceo CEO-1104): a VOID callee cannot take the value form at all -- RT_GC_CALLBACK(rt_chain_enter(fn)) is
       `error: variable or field _cb_r declared void`, proven by compiling it -- so a detector blind to _V makes one site permanently
       uncountable and would force a wrap that does not build. Strictly widening: it can only turn UNWRAPPED into WRAPPED where a
       sanctioned wrapper really encloses the call."""
    spans = []
    for m in re.finditer(r"(?<![A-Za-z0-9_])" + re.escape(marker) + r"(?:_V)?\s*\(", src):
        depth = 0
        for j in range(m.end() - 1, len(src)):
            if src[j] == "(":
                depth += 1
            elif src[j] == ")":
                depth -= 1
                if depth == 0:
                    spans.append((m.start(), j))
                    break
    return spans


# A CALLBACK SITE HAS TWO DIRECTIONS AND ONE DENOMINATOR EACH.  INBOUND: a runtime frame calls the by-name
# dispatcher (the rt_call_* family), which runs user code.  OUTBOUND: a runtime frame calls out through the apply /
# user-call hook chain into emitted code.  CEO-836's gdb site is OUTBOUND -- by_name_dispatch.c's
# `out = APPLY_fn(fn, args, nargs);`, where the raw heap `const char *fn` is live across the call and comes back
# reading "\003" -- and no INBOUND count contains it.  Two populations, both printed: one denominator over two
# populations is no denominator over either.
OUTBOUND_SYMS = [
    ("APPLY_fn",         "by_name_dispatch.c's apply path; CEO-836's gdb site holds `const char *fn` across it"),
    ("_usercall_hook",   "the driver hook the runtime reaches emitted code through (driver_hooks.c -> call_user_function -> label_lookup)"),
]
# rt_chain_enter and rt_chain_enter_v (runtime_eval.c's chain entry into emitted code, COO-100) LEFT THE TREE with the
# C->BB deletions of CEO-1576 (row gc-the-five-c-to-bb-entries-outside-rt-c-go-to-zero-the-eval-chain-shims-in-runtime-eval-c-
# and-the-three-riders-in-by-name-dispatch-c, DONE): the box jumps to the address the C returns, so there is no outbound call
# to count. Dropped from the declared set by the cto 2026-10-10 (CEO-1627 routing); with them declared the census REFUSED(2)
# "appear nowhere in the censused scope" and the ratchet read callbacks.unwrapped NOT-MEASURED on origin from 08c00e5b4.
OUTBOUND_RX = re.compile(r"(?<![A-Za-z0-9_])(" + "|".join(re.escape(x) for x, _ in OUTBOUND_SYMS) + r")\s*\(")

# Heads that can legally precede a CALL and would otherwise read as a return type.
_HEAD_KEYWORDS = {"return", "else", "do", "while", "if", "case", "goto", "sizeof", "typeof", "switch", "for", "and", "or", "not"}
_DECL_HEAD_RX = re.compile(r"^\s*(?:(?:static|extern|inline|const|unsigned|signed|struct|union|enum|_Noreturn|__inline__|register|volatile)\s+)*"
                           r"([A-Za-z_][A-Za-z0-9_]*)\s*\**\s*$")


def _is_declaration(src, line_start, match_start):
    """True when this match is a DECLARATION or DEFINITION HEAD rather than a call.

    The terminator is NOT the test.  The earlier rule required the line to end in '{', ')' or ',', so
    `DESCR_t rt_call_arr(const char *fn, int n);` (a prototype, ends ';') and
    `DESCR_t rt_call_arr_bl_sn4(...) { return rt_call_arr_bl_s(...); }` (a one-line definition, ends '}')
    were both counted as CALL SITES -- 13 of the 63 this census reported on 2026-09-17.  What decides it is the
    text BEFORE the name: a declarator prefix (optional storage/qualifier words then one type token and stars),
    and nothing else.  A blank head falls back to the previous non-blank line, for a definition whose return
    type sits on its own line."""
    head = src[line_start:match_start]
    # A DECLARATOR PREFIX BEGINS AT A STATEMENT BOUNDARY, NOT AT THE MARGIN (cfo 2026-09-19, the ceo's CEO-942
    # false positive).  core.c:2382 is `if (!g_user_call_hook) { extern DESCR_t _usercall_hook(const char *name,
    # DESCR_t *args, int nargs); g_user_call_hook = _usercall_hook; }` -- one line holding a BLOCK-LOCAL EXTERN
    # DECLARATION and an assignment of the hook's ADDRESS, and no call at all.  Matching the declarator prefix
    # against the whole line prefix read `if (...) { extern DESCR_t ` as no declarator and counted the
    # declaration's own parenthesis as a way out of the runtime into emitted code.  The statement this match
    # belongs to starts after the last '{', '}' or ';' on the line; a blank statement head there is a call at the
    # start of a statement and NOT a declaration, so it must not fall back to the line above.
    _cut = max(head.rfind("{"), head.rfind("}"), head.rfind(";"))
    if _cut >= 0:
        _stmt = head[_cut + 1:]
        if not _stmt.strip():
            return False
        m = _DECL_HEAD_RX.match(_stmt)
        return bool(m) and m.group(1) not in _HEAD_KEYWORDS
    if head.strip():
        m = _DECL_HEAD_RX.match(head)
        return bool(m) and m.group(1) not in _HEAD_KEYWORDS
    # blank head: the return type may be the line above
    j = line_start - 1
    while j > 0:
        k = src.rfind("\n", 0, j) + 1
        prev = src[k:j]
        if prev.strip():
            m = _DECL_HEAD_RX.match(prev + " ")
            return bool(m) and m.group(1) not in _HEAD_KEYWORDS
        j = k - 1
    return False


def _scan_sites(src, rx, path, marker_spans):
    """(wrapped, [ 'path:line:sym', ... ]) for every non-declaration match of RX"""
    wrapped = 0; unwrapped = []
    for m in rx.finditer(src):
        line_start = src.rfind("\n", 0, m.start()) + 1
        if _is_declaration(src, line_start, m.start()):
            continue
        lineno = src.count("\n", 0, m.start()) + 1
        if any(a <= m.start() <= b for a, b in marker_spans):
            wrapped += 1
        else:
            unwrapped.append(f"{path}:{lineno}:{m.group(1)}")
    return wrapped, unwrapped


def _marker_is_defined(root, marker):
    """Does the marker EXIST as a macro in the tree?  wrapped=0 means two different things and they are not the
    same reading: 'the wrapper exists and nobody has used it' is progress pending, 'the name has no definition'
    is a census whose GREEN nobody can reach by curing anything."""
    rx = re.compile(r"^\s*#\s*define\s+" + re.escape(marker) + r"\b", re.M)
    for d, _sub, fs in os.walk(os.path.join(root, "src")):
        for f in fs:
            if f.endswith((".c", ".h", ".cpp", ".hpp")):
                try:
                    if rx.search(open(os.path.join(d, f), encoding="utf-8", errors="replace").read()):
                        return os.path.relpath(os.path.join(d, f), root)
                except OSError:
                    pass
    return None


def census_callbacks(files, marker="RT_GC_CALLBACK", out=print, root=None):
    present = [f for f in files if os.path.exists(f)]
    if not present:
        out("CENSUS callbacks REFUSED(2): none of the callback files exist"); return 2
    R = root or ROOT
    out(f"CENSUS callbacks SCOPE files={len(present)} (DERIVED by walking the scope, never a hand list -- a file "
        f"added tomorrow enters the denominator by itself); src/templates and src/emitter are EXCLUDED BY NAME: "
        f"a C++ emitter source EMITS a call, it does not hold a pointer across one")
    where = _marker_is_defined(R, marker)
    out(f"CENSUS callbacks marker={marker} defined_in_tree={where or 'NO'}"
        + ("" if where else f" -- so wrapped=0 is NOT 'nobody has wrapped one yet', it is 'the wrapper does not "
                           f"exist': a wrap written today would not compile, and a no-op macro would take this "
                           f"census to GREEN with no semantic change at all"))

    in_sites = in_wrapped = 0; in_unwrapped = []
    out_sites = out_wrapped = 0; out_unwrapped = []
    seen_syms = set()
    for f in present:
        src = strip_comments(open(f, encoding="utf-8", errors="replace").read())
        spans = _marker_spans(src, marker)
        rel = os.path.relpath(f, R)
        w, u = _scan_sites(src, CALLBACK_RX, rel, spans)
        in_wrapped += w; in_unwrapped += u; in_sites += w + len(u)
        w2, u2 = _scan_sites(src, OUTBOUND_RX, rel, spans)
        out_wrapped += w2; out_unwrapped += u2; out_sites += w2 + len(u2)
        for m in OUTBOUND_RX.finditer(src):
            seen_syms.add(m.group(1))

    out(f"CENSUS callbacks INBOUND call_back_sites={in_sites} wrapped_in_{marker}={in_wrapped} "
        f"unwrapped={len(in_unwrapped)} want unwrapped=0 (Rule 4: a runtime frame holds no raw heap pointer across "
        f"a callback into emitted code)")
    _cbcap = len(in_unwrapped) if os.environ.get("SCRIP_GC_CENSUS_LIST_ALL") == "1" else 15
    for u in in_unwrapped[:_cbcap]:
        out(f"  UNWRAPPED-INBOUND {u}")
    if len(in_unwrapped) > _cbcap:
        out(f"  ... {len(in_unwrapped) - _cbcap} more unwrapped INBOUND -- SCRIP_GC_CENSUS_LIST_ALL=1 prints every one (a count without names cannot be triaged; the safe-point list above has honoured this since CEO-1039 and these two did not, ceo CEO-1104)")

    missing = [s for s, _why in OUTBOUND_SYMS if s not in seen_syms]
    out(f"CENSUS callbacks OUTBOUND set=DECLARED({','.join(s for s, _ in OUTBOUND_SYMS)}) -- a DECLARED set is a "
        f"measurement with a stated bound, never a population: it grows when a new way out of the runtime into "
        f"emitted code is found, and each entry carries its evidence")
    for s, why in OUTBOUND_SYMS:
        out(f"  OUTBOUND-SYM {s}: {why}")
    if missing:
        out(f"CENSUS callbacks REFUSED(2): the declared outbound symbol(s) {', '.join(missing)} appear nowhere in "
            f"the censused scope -- renamed or deleted, and a stale enumeration reporting zeros is worse than no "
            f"census (a watermark's command must still describe the tree it runs on)")
        return 2
    out(f"CENSUS callbacks OUTBOUND call_out_sites={out_sites} wrapped_in_{marker}={out_wrapped} "
        f"unwrapped={len(out_unwrapped)} want unwrapped=0 -- this is CEO-836's crash class: the raw heap name "
        f"pointer live across the call")
    _cbcap = len(out_unwrapped) if os.environ.get("SCRIP_GC_CENSUS_LIST_ALL") == "1" else 15
    for u in out_unwrapped[:_cbcap]:
        out(f"  UNWRAPPED-OUTBOUND {u}")
    if len(out_unwrapped) > _cbcap:
        out(f"  ... {len(out_unwrapped) - _cbcap} more unwrapped OUTBOUND -- SCRIP_GC_CENSUS_LIST_ALL=1 prints every one (a count without names cannot be triaged; the safe-point list above has honoured this since CEO-1039 and these two did not, ceo CEO-1104)")

    COUNTS.setdefault("callbacks", {})["unwrapped"] = len(in_unwrapped)
    COUNTS["callbacks"]["unwrapped_outbound"] = len(out_unwrapped)
    red = bool(in_unwrapped or out_unwrapped)
    out(f"CENSUS callbacks {'RED' if red else 'GREEN'}")
    return 1 if red else 0


def callback_scope_files(root):
    """THE DENOMINATOR, DERIVED: every C source and header under src/runtime and src/driver.  The earlier scope was
    two hand-named files -- by_name_dispatch.c and gen_runtime.c -- and gen_runtime.c holds not one site, so the
    census read ONE file while saying two, and 16 sites of the identical class stood in pattern_match.c, rt/rt.c
    and core/core.c outside any denominator (coo, 2026-09-17)."""
    fs = []
    for d in ("src/runtime", "src/driver"):
        dd = os.path.join(root, d)
        for sub, _dirs, names in os.walk(dd):
            for n in sorted(names):
                if n.endswith((".c", ".h")):
                    fs.append(os.path.join(sub, n))
    return sorted(fs)


ZLS_TOOL = "util_zls_frame_map_census.py"          # the ceo's slot-kind base tool (CEO-820)
ZLS_RX = re.compile(r"^ZLS-MAP lang=(\S+) graphs=(\d+) words=(\d+) unkinded=(\d+) holes=(\d+) graded=(\d+) no_layout=(\d+)")
ZLS_KIND_RX = re.compile(r"no_layout_never_emitted=(\d+) no_layout_emitted_no_layout=(\d+) no_layout_unmeasured=(\d+)")
ZLS_LANGS_ALL = ["rebus", "snocone", "pascal", "icon", "raku", "snobol4", "prolog"]   # ~32 s for the seven
ZLS_LANGS_FAST = ["rebus", "snocone", "pascal"]                                       # ~2.7 s; the wired gate's default
GCMAP_RX = re.compile(r"\[GC-MAP\] graph=(\S+) frame_bytes=(\d+) header_bytes=(\d+) value_bytes=(\d+) flags=(\d+)")
MAP_MAGIC = 0x50414D5A   # 'ZMAP', section 6.3
ENTRY_ALIAS = ("pat_flat", "main")   # the mode-3 emitter names the entry graph pat_flat, mode 4 and --dump-zeta name it main
MAPS_SYMBOLS = ("rt_gc_frame_maps_install", "rt_gc_frame_maps")   # section 6.4: the one exported symbol and its reader


def census_maps_slotkind(root, langs, out=print):
    """HALF A -- every word of every graded graph's zls region has a declared kind (the ceo's tool, token frozen CEO-821).
    no_layout entries are NAMED beside the number and never folded into it (CEO-749's rule)."""
    tool = os.path.join(root, "..", "harness", "scripts", ZLS_TOOL)
    if not os.path.exists(tool):
        out(f"CENSUS maps/slot-kind REFUSED(2): no {ZLS_TOOL} at {tool}"); return 2
    red = 0; swept = []; nolayout = 0; graded = 0; never_emitted = 0; emitted_no_layout = 0
    for lang in langs:
        try:
            r = subprocess.run([sys.executable, tool, "--lang", lang], capture_output=True, text=True, timeout=600, stdin=subprocess.DEVNULL)
        except (OSError, subprocess.TimeoutExpired) as e:
            out(f"CENSUS maps/slot-kind REFUSED(2): {ZLS_TOOL} --lang {lang} failed: {e}"); return 2
        m = None
        for line in r.stdout.split("\n"):
            mm = ZLS_RX.match(line.strip())
            if mm:
                m = mm
        if not m:
            out(f"CENSUS maps/slot-kind REFUSED(2): {ZLS_TOOL} --lang {lang} printed no ZLS-MAP line (rc={r.returncode}) -- the token is frozen (CEO-821); a census that parses prose is the defect one level up"); return 2
        _l, graphs, words, unkinded, holes, gr, nl = m.group(1), *(int(x) for x in m.groups()[1:])
        km = ZLS_KIND_RX.search(m.string)
        if not km:
            out(f"CENSUS maps/slot-kind REFUSED(2): lang={lang} printed a ZLS-MAP line without the three kind fields"
                " -- no_layout CONFLATES two populations with OPPOSITE OWNERS (ceo CEO-1025) and an absent field would"
                " read as zero, which is how the conflation looked like a clean split in the first place"); return 2
        never, emitted_nl, unmeasured = (int(x) for x in km.groups())
        if never + emitted_nl + unmeasured != nl:
            out(f"CENSUS maps/slot-kind REFUSED(2): lang={lang} no_layout={nl} but the kinds sum to"
                f" {never + emitted_nl + unmeasured} -- an entry in no bucket vanishes from BOTH owners' work lists"); return 2
        swept.append(lang); graded += gr; nolayout += nl; never_emitted += never; emitted_no_layout += emitted_nl
        bad = unkinded + holes + emitted_nl
        red += bad
        out(f"CENSUS maps/slot-kind lang={lang} graphs={graphs} words={words} unkinded={unkinded} holes={holes} want 0 and 0"
            f" -- graded={gr}, no_layout={nl} NAMED AND UNCOUNTED, split NEVER-EMITTED={never}"
            f" EMITTED-NO-LAYOUT={emitted_nl} UNMEASURED={unmeasured}"
            + ("" if not emitted_nl else "  ⛔ EMITTED-NO-LAYOUT IS THE CORRECTNESS POPULATION AND IT IS RED: those"
               " graphs EMIT, so every leaf boundary in them stores into an unmapped slot BY CONSTRUCTION (cfo's"
               " clause, MODE TENET condition 1). A NEVER-EMITTED entry is a COMPLETENESS debt and gates nothing here")
            + ("" if not bad else "  RED"))
        named = [ln.strip() for ln in r.stdout.split("\n") if ln.startswith("NO-LAYOUT ")]
        for ln in named:
            out("CENSUS maps/slot-kind " + ln)
        if len(named) != nl:
            out(f"CENSUS maps/slot-kind REFUSED(2): lang={lang} counted no_layout={nl} but {ZLS_TOOL} printed {len(named)} NO-LAYOUT line(s)"
                " -- this line has said NAMED AND UNCOUNTED since CEO-749 while printing no name at all (cto 2026-09-20, CTO-96); a census that"
                " claims to name must print the names or refuse, and a count without its names is a work list nobody can pick up"); return 2
        COUNTS.setdefault("maps", {})[f"slotkind_bad_{lang}"] = bad
    out(f"CENSUS maps/slot-kind swept {len(swept)} of {len(ZLS_LANGS_ALL)} language(s) ({', '.join(swept)}); graded={graded} no_layout={nolayout} UNCOUNTED "
        f"(NEVER-EMITTED={never_emitted} a completeness debt that gates nothing here, EMITTED-NO-LAYOUT={emitted_no_layout} the correctness population that does); "
        f"{'GREEN' if red == 0 else 'RED'}"
        + ("" if len(swept) == len(ZLS_LANGS_ALL) else "  -- A PARTIAL SWEEP IS NOT ALL-LANGUAGE COVERAGE: --zls-langs all for the other " + str(len(ZLS_LANGS_ALL) - len(swept))))
    out("CENSUS maps/slot-kind NOT CENSUSED HERE, named: the wire header past region_end (the cto's map cell, section 6.7) and the "
        "spine (section 2b makes it tagged cells, not a map -- its census is the tag census, not a hole count)")
    return 0 if red == 0 else 1


def decode_map_quads(text, label):
    """the four .quad lines under .Lgcmap_<g> (section 6.7c): magic|frame_bytes<<32, header_bytes|flags<<32, name, 0"""
    m = re.search(r"^" + re.escape(label) + r":\s*\n((?:\s*\.quad\s+\S+\s*\n){4})", text, re.M)
    if not m:
        m = re.search(r"^" + re.escape(label) + r":[^\n]*\n((?:[^\n]*\.quad[^\n]*\n){4})", text, re.M)
    if not m:
        return None
    qs = re.findall(r"\.quad\s+(\S+)", m.group(1))
    try:
        q0 = int(qs[0]); q1 = int(qs[1])
    except (ValueError, IndexError):
        return None
    return {"magic": q0 & 0xFFFFFFFF, "frame_bytes": q0 >> 32, "header_bytes": q1 & 0xFFFFFFFF, "flags": q1 >> 32}


GCMAP_LBL_RX = re.compile(r"\[GC-MAP\] graph=(\S+) .*? map=(\S+)")


def read_gcmap_labels(text):
    """graph -> the map label the emitter named (a thunk's label is its assembler-local stem, never its graph name)"""
    return {m.group(1): m.group(2) for m in GCMAP_LBL_RX.finditer(text)}


def read_gcmaps(text):
    d = {}
    for m in GCMAP_RX.finditer(text):
        d[m.group(1)] = {"frame_bytes": int(m.group(2)), "header_bytes": int(m.group(3)), "value_bytes": int(m.group(4)), "flags": int(m.group(5))}
    return d


# THE BLOB-FRAME CLASS MUST BE IN THE WITNESS SET OR THE CENSUS REFUSES (cto 2026-09-17, after their PAT$0 cure was
# built, measured against the SNOBOL4 rungs, cost one entry and was withdrawn under CEO-589).  A stored-pattern
# activation frame presents NO map cell -- ARCH-GC 6.2b states the walk rule for it -- so a table census run over
# witnesses that contain no pattern reads 0 divergences BY NEVER LOOKING, the same shape as words_scanned=0 on a run
# that never collected.  A zero has to be a zero somebody could have failed.
PATTERN_GRAPH_RX = re.compile(r"^(PAT\$|\.LTp\d)")


def blob_class_visible(graph_names):
    """True when the witness set laid out at least one stored-pattern graph, so a 0 here is a measured 0"""
    return any(PATTERN_GRAPH_RX.match(g) for g in graph_names)


def census_maps_table(root, scrip, witnesses, out=print):
    """HALF B -- section 6.4's table, from THREE independent producers per witness: the frame allocator (--dump-zeta),
    the emitter (SCRIP_GC_MAPS_REPORT=1, both media) and the assembler text (.Lgcmap_* labels, their leas, the counted
    __gc_frame_maps table).  The cto's arms (a) one cell per graph naming a map in the table, (b) every map named by
    exactly one prologue, (d) the two media agree field for field."""
    gc = os.path.join(root, "src", "runtime", "rt", "gc_heap.c")
    if not os.path.exists(gc):
        out(f"CENSUS maps/table REFUSED(2): {gc} missing"); return 2
    src = strip_comments(open(gc, encoding="utf-8", errors="replace").read())
    missing = [sym for sym in MAPS_SYMBOLS if not re.search(r"(?<![A-Za-z0-9_])" + sym + r"\s*\(", src)]
    if missing:
        out(f"CENSUS maps/table REFUSED(2): section 6.4's symbol(s) {missing} are not defined in gc_heap.c -- the table does not exist yet; nothing to count"); return 2
    if not (scrip and os.path.exists(scrip)):
        out(f"CENSUS maps/table REFUSED(2): no scrip binary at {scrip}"); return 2
    env = dict(os.environ); env["SCRIP_GC_MAPS_REPORT"] = "1"
    red = 0; total_graphs = 0; all_laid = set()
    for w in witnesses:
        tag = os.path.basename(w)
        if not os.path.exists(w):
            out(f"CENSUS maps/table REFUSED(2): witness {w} missing"); return 2
        try:
            dz = subprocess.run([scrip, "--dump-zeta", w], capture_output=True, text=True, env=env, timeout=120, stdin=subprocess.DEVNULL)
            r3 = subprocess.run([scrip, w], capture_output=True, text=True, env=env, timeout=120, stdin=subprocess.DEVNULL)
            r4 = subprocess.run([scrip, "--compile", w], capture_output=True, text=True, env=env, timeout=120, stdin=subprocess.DEVNULL)
        except (OSError, subprocess.TimeoutExpired) as e:
            out(f"CENSUS maps/table REFUSED(2): {tag}: a reading run failed: {e}"); return 2
        laid = set(re.findall(r"^;\s*graph \d+ '([^']+)'", dz.stdout, re.M))
        m3 = read_gcmaps(r3.stdout + r3.stderr)
        m4 = read_gcmaps(r4.stderr)
        m4lab = read_gcmap_labels(r4.stderr)
        asm = r4.stdout
        labels = set(re.findall(r"^(\.Lgcmap_[A-Za-z0-9_$.]+):", asm, re.M)) - set(re.findall(r"^(\.Lgcmap_[A-Za-z0-9_$.]+_s):", asm, re.M))
        leas = collections.Counter(re.findall(r"#\s*GCANCHOR\s+(\.Lgcmap_[A-Za-z0-9_$.]+)", asm))
        tbl = re.search(r"^__gc_frame_maps:\s*\.quad\s+(\d+)\s*\n((?:\s*\.quad\s+\.Lgcmap_[A-Za-z0-9_$.]+\s*\n)+)", asm, re.M)
        if not (laid and m3 and m4):
            out(f"CENSUS maps/table REFUSED(2): {tag}: a producer printed nothing (dump-zeta graphs={len(laid)} m3 maps={len(m3)} m4 maps={len(m4)}) -- not measured"); return 2
        n_declared = int(tbl.group(1)) if tbl else -1
        entries = re.findall(r"\.quad\s+(\.Lgcmap_[A-Za-z0-9_$.]+)", tbl.group(2)) if tbl else []
        # the one NAMED alias: mode 3's emitter calls the entry graph pat_flat where mode 4 and --dump-zeta call it main
        alias = ENTRY_ALIAS[0] in m3 and ENTRY_ALIAS[0] not in laid and ENTRY_ALIAS[1] in laid
        m3n = dict(m3)
        if alias:
            m3n[ENTRY_ALIAS[1]] = m3n.pop(ENTRY_ALIAS[0])
        bad = []
        for g in sorted(laid):
            if g not in m3n: bad.append(f"graph '{g}' has a frame but NO map cell in mode 3")
            if g not in m4:  bad.append(f"graph '{g}' has a frame but NO map cell in mode 4")
        for g in sorted(set(m3n) | set(m4)):
            if g not in laid: bad.append(f"map cell for '{g}' names a graph the frame allocator never laid out")
            if g in m3n and g in m4 and m3n[g] != m4[g]:
                bad.append(f"graph '{g}' reads {m3n[g]} in mode 3 and {m4[g]} in mode 4 -- the media disagree")
        for g in sorted(m4):
            lab = m4lab.get(g, ".Lgcmap_" + g)
            if lab not in labels: bad.append(f"'{g}' reports a map cell but the .s has no {lab}")
            elif leas[lab] != 1:  bad.append(f"{lab} is anchored by {leas[lab]} prologue note(s), want exactly 1")
            elif lab not in entries: bad.append(f"{lab} is not in the __gc_frame_maps table")
            else:
                q = decode_map_quads(asm, lab)
                if q is None: bad.append(f"{lab}'s four quads do not decode (section 6.3)")
                elif q["magic"] != MAP_MAGIC: bad.append(f"{lab} magic 0x{q['magic']:08X}, want 0x{MAP_MAGIC:08X} 'ZMAP'")
                elif q["frame_bytes"] != m4[g]["frame_bytes"] or q["header_bytes"] != m4[g]["header_bytes"] or q["flags"] != m4[g]["flags"]:
                    bad.append(f"{lab}'s static map {q} contradicts its own reported cell {m4[g]} -- the double-entry fails")
        for lab in sorted(labels - {m4lab.get(g, ".Lgcmap_" + g) for g in m4}):
            bad.append(f"{lab} is emitted but no graph reports a cell for it")
        if n_declared != len(entries): bad.append(f"__gc_frame_maps declares n={n_declared} over {len(entries)} entries")
        total_graphs += len(laid); all_laid |= laid
        out(f"CENSUS maps/table {tag}: graphs_laid_out={len(laid)} map_cells_m3={len(m3)} map_cells_m4={len(m4)} "
            f"asm_maps={len(labels)} table_n={n_declared} entries={len(entries)} divergences={len(bad)} want 0"
            + ("  [NAMED ALIAS: mode 3 calls the entry graph '%s' where mode 4 and --dump-zeta call it '%s'; same fields, compared as one]" % ENTRY_ALIAS if alias else ""))
        for b in bad[:12]:
            out(f"  DIVERGENCE {b}")
        if len(bad) > 12:
            out(f"  ... {len(bad) - 12} more")
        red += len(bad)
    if not blob_class_visible(all_laid):
        out(f"CENSUS maps/table REFUSED(2): {len(witnesses)} witness(es), {total_graphs} graph(s), and NOT ONE stored-pattern "
            "(PAT$...) graph among them -- the blob-frame class (a frame whose map carries a static layout since 2026-09-19, "
            "ARCH-GC 6.2e; before that it presented no cell at all) CANNOT BE SEEN by this witness set, so the divergence count "
            "would be a zero by never looking. Add a pattern-bearing witness.")
        return 2
    blobs = sorted(g for g in all_laid if PATTERN_GRAPH_RX.match(g))
    COUNTS.setdefault("maps", {})["table_divergences"] = red
    # The population goes on its OWN line and the verdict line keeps its shape: the wired gate anchors on the verdict
    # word ending that line, and an instrument that appends to a line another instrument reads by identity breaks it.
    out(f"CENSUS maps/table blob-frame class VISIBLE in this witness set: {len(blobs)} stored-pattern graph(s) -- "
        + ", ".join(blobs[:4]) + (f" ... +{len(blobs) - 4} more" if len(blobs) > 4 else "")
        + " (ARCH-GC 6.2e since 2026-09-19: a blob frame presents a map cell and a static layout, so its map is counted like any other; a 0 here is a measured 0)")
    out(f"CENSUS maps/table {len(witnesses)} witness(es), {total_graphs} graph(s) laid out, {red} divergence(s) {'GREEN' if red == 0 else 'RED'}")
    return 0 if red == 0 else 1


def census_maps(root, scrip, langs, witnesses, out=print):
    """The two halves are printed and graded SEPARATELY on purpose: a green slot-kind half beside an absent table would
    read as if the design existed (section 6's question is the table's, F1's is the cell's)."""
    a = census_maps_slotkind(root, langs, out)
    b = census_maps_table(root, scrip, witnesses, out)
    rc = worst([a, b])
    out(f"CENSUS maps slot-kind={'GREEN' if a == 0 else ('RED' if a == 1 else 'REFUSED(2)')} "
        f"table={'GREEN' if b == 0 else ('RED' if b == 1 else 'REFUSED(2)')} -- {'GREEN' if rc == 0 else ('RED' if rc == 1 else 'REFUSED(2)')}")
    return rc


RATCHET_KEYS = [   # (census, key, is_population) -- a population may only FALL; a verdict may only improve
    ("conservative", "gc_zeta_frame_calls", True),
    ("conservative", "cons_stack_uses", True),
    ("conservative", "rt_cas_live_span_uses", True),
    ("conservative", "hb_scan_interior_uses", True),
    ("allocator", "rt_gc_collect_calls_in_the_allocator", True),
    ("safe-points", "unpolled", True),
    ("safe-points", "partially_polled", True),   # ⛔ ADDED 2026-09-22 (coo): the header has demanded this be ZERO
    ("safe-points", "unresolved", True),         # since it existed, and NOTHING WATCHED IT -- it could grow silently
    ("callbacks", "unwrapped", True),
    ("callbacks", "unwrapped_outbound", True),
    ("coverage", "red", False),
    ("maps", "table_divergences", True),   # the slot-kind keys are per-language and move with --zls-langs, so they are not ratcheted
]


def read_baseline(path):
    base = {}
    if not os.path.exists(path):
        return None
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        f = line.split("\t")
        if len(f) < 3:
            continue
        base[(f[0], f[1])] = int(f[2])
    return base


def ratchet(path, out=print):
    """re-read every count and refuse an INCREASE; a count that FELL is named so the landing lowers the baseline in the
    same sitting -- a ratchet nobody tightens is a ratchet that lets the next regression back in."""
    base = read_baseline(path)
    if base is None:
        out(f"RATCHET REFUSED(2): no baseline at {path}"); return 2
    # The criterion lines the baseline carries are printed WHERE THE NUMBERS ARE COMPARED, not only in the file: a
    # reader who sees 202 -> 203 without them reads a regression that did not happen.
    try:
        for line in open(path, encoding="utf-8"):
            if line.startswith("# CRITERION CHANGED"):
                out("RATCHET " + line.rstrip()[2:])
    except OSError:
        pass
    worse = []; better = []; unmeasured = []
    for census, key, _pop in RATCHET_KEYS:
        want = base.get((census, key))
        got = COUNTS.get(census, {}).get(key)
        if want is None:
            unmeasured.append(f"{census}.{key} (not in the baseline)"); continue
        if got is None:
            unmeasured.append(f"{census}.{key} (the census did not measure it this run)"); continue
        mark = "="
        if got > want:
            worse.append(f"{census}.{key} {want} -> {got}"); mark = "WORSE"
        elif got < want:
            better.append(f"{census}.{key} {want} -> {got}"); mark = "BETTER"
        out(f"RATCHET {census}.{key} baseline={want} now={got} {mark}")
    out(f"population: {len(RATCHET_KEYS)} ratcheted count(s), {len(worse)} worse, {len(better)} better, {len(unmeasured)} not measured")
    for u in unmeasured:
        out(f"  NOT-MEASURED {u}")
    for w in worse:
        out(f"  ⛔ WORSE {w} -- the design moves these to 0; a landing may not add one")
    for b in better:
        out(f"  ⭐ BETTER {b} -- lower the baseline in the landing that earned it ({os.path.relpath(path, ROOT)})")
    if unmeasured:
        out("RATCHET REFUSED(2): a count the baseline names was not measured -- not green"); return 2
    if worse:
        out("RATCHET RED(1): a conservative/unpolled/unwrapped count went UP"); return 1
    if better:
        out("RATCHET RED(1): a count FELL and the baseline still names the old number -- record the win, do not leave the ratchet loose"); return 1
    out("RATCHET GREEN: every ratcheted count is exactly its baseline"); return 0


def worst(rcs):
    return 2 if 2 in rcs else (1 if 1 in rcs else 0)


# THE FLOOR, NOT THE COUNT.  The printed population is COUNTED by ck() as the arms run -- a hand-typed total is a
# number nobody re-derives, and this one read 29 while 27 arms ran.  This floor catches the other direction: an
# arm deleted or skipped makes the selftest REFUSE rc=2 instead of passing with less proof.  A landing that adds
# arms raises it in the same sitting.
ARMS_FLOOR = 39


def _sp_fields(buf):
    """The CENSUS safe-points headline parsed FIELD BY NAME, stopping at the " want " clause -- which repeats
    unpolled=, partially_polled= and unresolved= as TARGETS and would otherwise overwrite the measured values.
    ⛔ WHY THIS EXISTS, AND IT IS THE coo's OWN DEFECT, FOUND 2026-09-22 WHILE MEASURING SOMETHING ELSE: these arms
    asserted on a CONTIGUOUS substring of the headline ("allocating_call_sites=1 polled=1 unpolled=0 unresolved=0"),
    so when COO-142 inserted the partially_polled and multi_path_sites columns BETWEEN those fields on 2026-09-22,
    FIVE ARMS WENT RED IN ONE LANDING AND NOTHING CAUGHT IT -- the row's own gate matches differently and --selftest
    is wired into no blocking set, so no seat meets it in the ordinary course.  A field read by name cannot be broken
    by a later column, and it cannot be satisfied by a PREFIX of a longer number the way the substring
    "allocating_call_sites=1" is satisfied by allocating_call_sites=12."""
    for l in buf:
        if l.startswith("CENSUS safe-points emitter_call_sites="):
            return {k: int(v) for k, v in re.findall(r'(\w+)=(\d+)', l.split(" want ")[0])}
    return {}


def _sp_has(buf, **want):
    f = _sp_fields(buf)
    return bool(f) and all(f.get(k) == v for k, v in want.items())


def selftest():
    """planted violations trip, clean fixtures pass -- the proof each census is an instrument and not a grep that agrees"""
    fails = 0
    arms = 0
    def ck(ok, label):
        nonlocal fails, arms
        arms += 1
        print(("  ok    " if ok else "  FAIL  ") + label)
        if not ok:
            fails += 1
    w = tempfile.mkdtemp(prefix="gc_census_selftest."); __import__("atexit").register(__import__("shutil").rmtree, w, True)
    buf = []
    # THE FOURTH-SPECIES RULE, BOTH SHAPES PLANTED (cto 2026-09-22, CEO-1160): a guard ABOVE the call that lands
    # below the poll skips the PAIR and is WHOLE; a jump emitted BETWEEN the call and the poll is the PARTIAL shape.
    pair = ['/*----*/', 'std::string s = x86("push", "rax") + x86("push", "rdx") + x86_align_call_enter()',
            '    + x86("cmp", "rax", (long)0) + x86("je", sk);',
            's += x86("call", "rt_trace_return_hook", (uint64_t)(uintptr_t)(void *)rt_trace_return_hook);',
            's += x86_rt_gc_poll();',
            's += x86("def", sk) + x86_align_call_leave() + x86("pop", "rdx") + x86("pop", "rax");',
            '}']
    between = ['/*----*/', 'std::string s = x86("push", "rax") + x86("push", "rdx") + x86_align_call_enter();',
               's += x86("call", "rt_trace_return_hook", (uint64_t)(uintptr_t)(void *)rt_trace_return_hook);',
               's += x86("cmp", "rax", (long)0) + x86("je", sk);',
               's += x86_rt_gc_poll();',
               's += x86("def", sk) + x86_align_call_leave() + x86("pop", "rdx") + x86("pop", "rax");',
               '}']
    ck(_emitted_guard_skips_poll(pair, 4, 4) is None,
       "fourth species: a guard ABOVE the call that lands below the poll skips call and poll TOGETHER -- the pair is whole and the rule does not fire (the six trace-tap sites, CEO-1160)")
    ck(_emitted_guard_skips_poll(between, 3, 4) == ("sk", 4),
       "fourth species FAIL-ONCE: a jump emitted BETWEEN the call and the poll that lands below the poll skips the poll alone and reads PARTIAL, named with its label and line")
    # conservative + allocator, on a fixture collector
    clean = "static void gc_zeta_frame(const char *lo, const char *hi);\nvoid *rt_gcheap_alloc(size_t n) {\n  if (over) { g_gc_pending = 1; grow(); }\n  return carve(n);\n}\n/* gc_zeta_frame( in a comment is not a call */\n"
    dirty = "static void gc_zeta_frame(const char *lo, const char *hi);\nvoid *rt_gcheap_alloc(size_t n) {\n  if (over) rt_gc_collect();\n  return carve(n);\n}\nstatic long gc_collect_ex(int cons_stack) { if (cons_stack) gc_zeta_frame(lo, hi); if (hb_scan_interior(t)) gc_zeta_frame(a, b); rt_cas_live_span(0, &b, &n); }\n"
    fc, fd = os.path.join(w, "clean.c"), os.path.join(w, "dirty.c")
    open(fc, "w").write(clean); open(fd, "w").write(dirty)
    buf.clear(); rc = census_conservative(fc, buf.append)
    ck(rc == 0 and "total=0" in buf[-1], "conservative: a clean collector (prototype only, a comment mention) reads total=0 GREEN")
    buf.clear(); rc = census_conservative(fd, buf.append)
    ck(rc == 1 and "gc_zeta_frame_calls=2" in "\n".join(buf) and "cons_stack_uses=2" in "\n".join(buf) and "rt_cas_live_span_uses=1" in "\n".join(buf) and "hb_scan_interior_uses=1" in "\n".join(buf),
       "conservative: planted word-walker calls, cons_stack, rt_cas_live_span and hb_scan_interior are each counted and RED")
    buf.clear(); rc = census_allocator(fc, buf.append)
    ck(rc == 0, "allocator: an allocator that sets g_gc_pending and grows reads 0 GREEN")
    buf.clear(); rc = census_allocator(fd, buf.append)
    ck(rc == 1 and "=1 want=0" in buf[-1], "allocator: a planted rt_gc_collect( inside rt_gcheap_alloc reads 1 RED")
    buf.clear(); rc = census_allocator(os.path.join(w, "nope.c"), buf.append)
    ck(rc == 2, "allocator: a missing file REFUSES rc=2, never green")
    fp = os.path.join(w, "prefixed.c")
    open(fp, "w").write("void *c_rt_gcheap_alloc(uint16_t t, uint64_t n) {\n  if (a) rt_gc_collect();\n  if (b) rt_gc_collect();\n  return carve(n);\n}\n")
    buf.clear(); rc = census_allocator(fp, buf.append)
    ck(rc == 1 and "inside_c_rt_gcheap_alloc=2" in "\n".join(buf) and "body lines" in "\n".join(buf),
       "allocator: the c_-prefixed definition is the one on disk -- two planted sites counted and their body lines named")
    nf = os.path.join(w, "noalloc.c")
    open(nf, "w").write("void *some_other_thing(void) { rt_gc_collect(); return 0; }\n")
    buf.clear(); rc = census_allocator(nf, buf.append)
    ck(rc == 2, "allocator: a file with neither spelling REFUSES rc=2 (a renamed allocator is not a green one)")
    # THE ALLOCATING SET ITSELF, over planted disassembly -- the derivation every other arm's `allocating` set
    # is handed for free, and the one that was wrong for two days (cto 2026-09-18: tail-jump edges).
    DIS_CALL = ("0000000000001000 <rt_gcheap_alloc>:\n    1000:\tret\n"
                "0000000000002000 <caller_by_call>:\n    2000:\tcall   1000 <rt_gcheap_alloc>\n    2005:\tret\n"
                "0000000000003000 <stranger>:\n    3000:\tret\n")
    seen, funcs = _alloc_reach_from_disasm(DIS_CALL)
    ck(seen == {"rt_gcheap_alloc", "caller_by_call"} and "stranger" in funcs,
       f"allocating-set: a direct caller is in the set and an unrelated function is not, got {seen}")
    DIS_JMP = DIS_CALL + ("0000000000004000 <tail_jumper>:\n    4000:\tjmp    1000 <rt_gcheap_alloc>\n"
                          "0000000000005000 <caller_of_tail_jumper>:\n    5000:\tcall   4000 <tail_jumper>\n    5005:\tret\n")
    seen2, _ = _alloc_reach_from_disasm(DIS_JMP)
    ck("tail_jumper" in seen2 and "caller_of_tail_jumper" in seen2,
       "allocating-set PLANTED: a function that reaches the allocator ONLY by a TAIL JUMP is in the set, and so is "
       "its caller. This is the real shape of rt_str_alloc and rt_agg_alloc in rtx_alloc.s, which reach the carve by "
       "`jmp` and never `call` it; with call edges alone they and 99 other functions read NON-ALLOCATING and 27 "
       f"emitter call sites fell outside the denominator entirely. got {sorted(seen2)}")
    seen3, _ = _alloc_reach_from_disasm(
        "0000000000001000 <rt_gcheap_alloc>:\n    1000:\tret\n"
        "0000000000002000 <selfloop>:\n    2000:\tjmp    2004 <selfloop+0x4>\n    2004:\tret\n")
    ck(seen3 == {"rt_gcheap_alloc"},
       f"allocating-set PLANTED: an intra-function jump to a local label (<fn+0xNN>) is NOT an edge -- widening to "
       f"tail jumps must not sweep every looping function into the set, got {seen3}")
    seen5, _ = _alloc_reach_from_disasm(DIS_CALL + ("0000000000006000 <cond_exiter>:\n    6000:\tcmp    $0x2,%dil\n"
                                                     "    6004:\tjne    1000 <rt_gcheap_alloc>\n    6006:\tret\n"))
    ck("cond_exiter" in seen5,
       "allocating-set PLANTED: a function whose ONLY road to the allocator is a CONDITIONAL tail exit is in the set "
       "(cto 2026-09-23: VARVAL_fn, rt_size_d, rt_str_coerce, rt_match_enter, rt_defer_close and table_find_pair_d "
       f"reached their allocating C twins only by jcc, and 66 functions read NON-ALLOCATING), got {sorted(seen5)}")
    DIS_GOT = DIS_CALL + ("0000000000007000 <got_caller>:\n    7000:\tcall   *0x1234(%rip)        # 9000 <stranger+0x6000>\n"
                          "    7006:\tret\n0000000000008000 <got_miss>:\n    8000:\tcall   *0x1234(%rip)        # 9008 <stranger+0x6008>\n"
                          "    8006:\tret\n")
    seen6, _ = _alloc_reach_from_disasm(DIS_GOT, got={0x9000: "rt_gcheap_alloc", 0x9008: "stranger"})
    ck("got_caller" in seen6 and "got_miss" not in seen6,
       "allocating-set PLANTED: a call THROUGH A GOT SLOT is an edge to the symbol the slot's GLOB_DAT relocation names, "
       "never to the nearest symbol objdump prints beside it -- the slot to the allocator is in, the slot to a "
       f"non-allocating function is not, got {sorted(seen6)}")
    seen8, _ = _alloc_reach_from_disasm(DIS_CALL + ("0000000000009100 <rt_gcheap_alloc@plt>:\n    9100:\tjmp    *0x1234(%rip)        # 9000 <stranger+0x6000>\n"),
                                        got={0x9000: "rt_gcheap_alloc"})
    ck("rt_gcheap_alloc@plt" not in seen8,
       f"allocating-set: a PLT stub's own jump through the GOT is not an edge -- the stub is never a callee's name, got {sorted(seen8)}")
    seen7, _ = _alloc_reach_from_disasm(DIS_GOT)
    ck("got_caller" not in seen7,
       f"allocating-set: without the relocation map a GOT call names nothing (the nearest-symbol label is not a target), got {sorted(seen7)}")
    seen4, _ = _alloc_reach_from_disasm("0000000000002000 <only_this>:\n    2000:\tret\n")
    ck(seen4 is None,
       "allocating-set: a binary that defines no rt_gcheap_alloc REFUSES rather than returning an empty set, because "
       "an empty allocating set makes every other census read GREEN while measuring nothing")
    # safe-points on fixture templates with a given allocating set
    tpl_ok = os.path.join(w, "ok.cpp"); tpl_bad = os.path.join(w, "bad.cpp")
    open(tpl_ok, "w").write('std::string a(){ return x86("call", "rt_concat", fp)\n + x86("lea", "r8", "[rip + __]", (uint64_t)&g_gc_pending, "g_gc_pending")\n + x86("test", "eax", "eax"); }\nstd::string b(){ return x86("call", "rt_pure_cmp", fp); }\n')
    open(tpl_bad, "w").write('std::string a(){ return x86("call", "rt_concat", fp)\n + x86("mov", "rax", "rbx"); }\nstd::string c(){ return x86("call", (flag ? name_a : name_b), fp); }\n')
    alloc = {"rt_concat", "rt_gcheap_alloc"}
    tpl_nr = os.path.join(w, "noreturn.cpp"); tpl_nr2 = os.path.join(w, "noreturn2.cpp")
    open(tpl_nr, "w").write('std::string a(){ return x86("call", "rt_ab_undef_fn_stub", fp); }\n')
    open(tpl_nr2, "w").write('std::string a(){ return x86("call", "rt_concat", fp); }\n')
    buf.clear(); rc = census_safe_points("", [tpl_nr], out=buf.append, allocating={"rt_ab_undef_fn_stub", "rt_concat"})
    ck(_sp_has(buf, allocating_call_sites=0, polled=0, unpolled=0) and any("NORETURN " in x and "rt_ab_undef_fn_stub" in x for x in buf) and declared_noreturn("rt_ab_undef_fn_stub"),
       "safe-points NORETURN: a call whose only allocating candidate is DEFINED __attribute__((noreturn)) in src/runtime leaves the denominator and is NAMED (rt_ab_undef_fn_stub)")
    buf.clear(); rc = census_safe_points("", [tpl_nr2], out=buf.append, allocating={"rt_ab_undef_fn_stub", "rt_concat"})
    ck(rc == 1 and _sp_has(buf, allocating_call_sites=1, unpolled=1) and not any("NORETURN " in x for x in buf) and not declared_noreturn("rt_concat"),
       "safe-points NORETURN PLANTED THE OTHER WAY: the same unpolled call to a callee NOT declared noreturn stays in the denominator and reads unpolled")
    buf.clear(); rc = census_safe_points("", [tpl_ok], out=buf.append, allocating=alloc)
    ck(rc == 0 and _sp_has(buf, allocating_call_sites=1, polled=1, unpolled=0, unresolved=0), "safe-points: an allocating call followed by a g_gc_pending poll reads polled, a non-allocating call is not counted")
    buf.clear(); rc = census_safe_points("", [tpl_bad], out=buf.append, allocating=alloc)
    ck(rc == 1 and _sp_has(buf, unpolled=1, unresolved=1) and any("UNPOLLED" in l and "rt_concat" in l for l in buf) and any("UNRESOLVED" in l for l in buf),
       "safe-points: a planted unpolled allocating call and a computed call target are each named and RED")
    # THE WINDOW IS MEASURED IN x86 CALLS (the cto's ruling, 2026-10-03): ONE call, thirteen moves and a poll, written as hq_templates'
    # R4 hygiene writes them (one x86() per line, the poll on line 14) and as the older two-per-line form (7 lines). The x86-unit window
    # reads POLLED on BOTH; the legacy 12-LINE window reads the reflowed form UNPOLLED, which is the move a whitespace-only reformat
    # made on the bb_call family (the cfo's report) -- the control arm proving the unit, not the fixture, decides.
    mv = ['    + x86("mov", "rax", "rbx")'] * 13
    tpl_r4 = os.path.join(w, "reflow_r4.cpp"); tpl_r2 = os.path.join(w, "reflow_r2.cpp")
    open(tpl_r4, "w").write('std::string a(){ return x86("call", "rt_concat", fp)\n' + "\n".join(mv) + '\n    + x86_rt_gc_poll(); }\n')
    open(tpl_r2, "w").write('std::string a(){ return x86("call", "rt_concat", fp)\n'
                            + "\n".join(mv[k] + (" " + mv[k + 1].strip() if k + 1 < 13 else "") for k in range(0, 13, 2))
                            + '\n    + x86_rt_gc_poll(); }\n')
    r4 = []; r2 = []; l4 = []
    census_safe_points("", [tpl_r4], out=r4.append, allocating=alloc); census_safe_points("", [tpl_r2], out=r2.append, allocating=alloc)
    _u = os.environ.get("SCRIP_GC_CENSUS_WINDOW_UNIT"); os.environ["SCRIP_GC_CENSUS_WINDOW_UNIT"] = "lines"
    try:
        census_safe_points("", [tpl_r4], out=l4.append, allocating=alloc)
    finally:
        os.environ.pop("SCRIP_GC_CENSUS_WINDOW_UNIT") if _u is None else os.environ.__setitem__("SCRIP_GC_CENSUS_WINDOW_UNIT", _u)
    ck(_sp_has(r4, allocating_call_sites=1, polled=1, unpolled=0) and _sp_has(r2, allocating_call_sites=1, polled=1, unpolled=0),
       "safe-points WINDOW IN x86 CALLS: one call, thirteen moves and a poll read POLLED both one-x86-per-line (14 lines) and two-per-line (7 lines)")
    ck(_sp_has(l4, allocating_call_sites=1, polled=0, unpolled=1),
       "safe-points WINDOW control: the legacy 12-LINE window reads the one-x86-per-line form UNPOLLED -- the move a whitespace-only reformat made")
    # THE CALL'S OWN LINE, ITS OWN ARGUMENTS, AND A PARAMETER TARGET (the coo 2026-10-03, measured on bb_call_proc_staged.cpp:212 and
    # bb_call_pl_leaf.cpp:72): a poll after the call on the call's own line is its safe point unless a jump stands between; the
    # arguments of x86("call", ...) end at its own closing paren, so a computed target never borrows the mnemonics chained after it;
    # a target that is a parameter of the enclosing function resolves to the literals its callers pass there; and the two arms of a
    # ternary of calls on one line are both the site's candidates.
    t_own = os.path.join(w, "own.cpp"); t_ownj = os.path.join(w, "ownj.cpp"); t_arg = os.path.join(w, "arg.cpp")
    t_par = os.path.join(w, "par.cpp"); t_ter = os.path.join(w, "ter.cpp")
    open(t_own, "w").write('std::string a(){\n    return x86("call", "rt_concat", fp) + x86_rt_gc_poll() + x86_omega();\n}\n')
    open(t_ownj, "w").write('std::string a(){\n    return x86("call", "rt_concat", fp) + x86("je", L) + x86_rt_gc_poll();\n}\n')
    open(t_arg, "w").write('std::string a(){\n    std::string s = x86("call", sym, fp) + x86("mov", "rt_concat", "rbx");\n    return s;\n}\n')
    open(t_par, "w").write('static std::string h(const char * sym, void * fp) {\n    std::string s = x86("call", sym, fp) + x86_rt_gc_poll();\n'
                           '    return s;\n}\nstd::string a(){ return h("rt_concat", fp) + h("rt_gcheap_alloc", fp); }\n')
    open(t_ter, "w").write('std::string a(){\n    return (c ? x86("call", "rt_concat", fp) : x86("call", "rt_gcheap_alloc", fp))\n'
                           '        + x86_rt_gc_poll();\n}\n')
    o1 = []; o2 = []; o3 = []; o4 = []; o5 = []
    census_safe_points("", [t_own], out=o1.append, allocating=alloc); census_safe_points("", [t_ownj], out=o2.append, allocating=alloc)
    census_safe_points("", [t_arg], out=o3.append, allocating=alloc); census_safe_points("", [t_par], out=o4.append, allocating=alloc, list_polled=True)
    census_safe_points("", [t_ter], out=o5.append, allocating=alloc, list_polled=True)
    ck(_sp_has(o1, allocating_call_sites=1, polled=1, unpolled=0),
       "safe-points OWN LINE: call + x86_rt_gc_poll() + omega on ONE line reads POLLED (bb_call_proc_staged.cpp's rt_ab_undef_fn_fail shape)")
    ck(_sp_has(o2, allocating_call_sites=1, polled=0, unpolled=1),
       "safe-points OWN LINE FAIL-ONCE: a jump between the call and the poll on the same line is not credited -- UNPOLLED")
    ck(_sp_has(o3, allocating_call_sites=0, unresolved=1),
       "safe-points OWN ARGUMENTS: x86(\"call\", sym, ...) chained with x86(\"mov\", \"rt_concat\", ...) is UNRESOLVED, never the mov's string")
    ck(_sp_has(o4, allocating_call_sites=1, polled=1, unresolved=0) and any("parameter sym of h()" in x for x in o4),
       "safe-points PARAMETER TARGET: a call on a parameter of its helper resolves to the literals the helper's callers pass there")
    ck(_sp_has(o5, allocating_call_sites=1, polled=1) and any("rt_concat" in x and "rt_gcheap_alloc" in x for x in o5),
       "safe-points TERNARY OF CALLS: both arms of a ternary of x86(\"call\") on one line are the site's candidates")
    # THREE READINGS THE 200-COLUMN RULE AND THE RTX TWINS BROKE (hq_templates 2026-10-14, the ratchet read unresolved 0 -> 5): a helper whose
    # signature wraps over two lines, a caller that passes a function-like macro of the file, and the twin wrapper around a table row.
    t_wr = os.path.join(w, "wr.cpp"); t_mc = os.path.join(w, "mc.cpp"); t_tw = os.path.join(w, "tw.cpp")
    open(t_wr, "w").write('static std::string h(const char * sym,\n                     void * fp)\n{\n    std::string s = x86("call", sym, fp) + x86_rt_gc_poll();\n'
                          '    return s;\n}\nstd::string a(){ return h("rt_concat", fp); }\n')
    open(t_mc, "w").write('#define SYM2(k) ((k) ? "rt_concat" : "rt_gcheap_alloc")\nstatic std::string h(const char * sym, void * fp) {\n'
                          '    std::string s = x86("call", sym, fp) + x86_rt_gc_poll();\n    return s;\n}\nstd::string a(){ return h(SYM2(1), fp); }\n')
    open(t_tw, "w").write('static const struct { const char * name; } tab[] = { {"rt_concat"}, {"rt_gcheap_alloc"} };\n'
                          'std::string a(){\n    return x86("call", emit_rtx_twin_sym(tab[I()].name), fp) + x86_rt_gc_poll();\n}\n')
    o6 = []; o7 = []; o8 = []
    census_safe_points("", [t_wr], out=o6.append, allocating=alloc, list_polled=True)
    census_safe_points("", [t_mc], out=o7.append, allocating=alloc, list_polled=True)
    census_safe_points("", [t_tw], out=o8.append, allocating=alloc, list_polled=True)
    ck(_sp_has(o6, allocating_call_sites=1, polled=1, unresolved=0) and any("parameter sym of h()" in x for x in o6),
       "safe-points WRAPPED SIGNATURE: a helper whose parameter list wraps over two lines still resolves its parameter target to its callers' literals")
    ck(_sp_has(o7, allocating_call_sites=1, polled=1, unresolved=0) and any("via the macro SYM2()" in x and "rt_concat" in x and "rt_gcheap_alloc" in x for x in o7),
       "safe-points MACRO ARGUMENT: a caller passing a function-like macro of the file names the macro's literals as the parameter target's candidates")
    ck(_sp_has(o8, allocating_call_sites=1, polled=1, unresolved=0) and any("through emit_rtx_twin_sym()" in x for x in o8),
       "safe-points TWIN WRAPPER: emit_rtx_twin_sym() around a table row reads as the row's own candidates")
    t_pr = os.path.join(w, "pr.cpp")
    pr_text = 'std::string h(const char * sym,\n              void * fp);\nstd::string h(const char * sym, void * fp) {\n    return x86("call", sym, fp);\n}\nstd::string a(){ return h("rt_concat", fp); }\n'
    open(t_pr, "w").write(pr_text)
    pr_unit = next(u for u in emission_units(pr_text) if u[0] == "func" and u[1] == "h")
    ck(expansion_lines(pr_unit, t_pr, {t_pr: pr_text}) == [(t_pr, 6)],
       "safe-points WRAPPED PROTOTYPE: a prototype whose parameter list wraps over two lines is not an expansion of its function -- only the call is")
    t_fld = os.path.join(w, "fld.cpp"); t_fle = os.path.join(w, "fle.cpp")
    open(t_fld, "w").write('std::string a(){\n    return x86("call", _.op_zz_sym, fp) + x86_rt_gc_poll();\n}\n')
    open(t_fle, "w").write('void zz_prepare(void) {\n    g_emit.op_zz_sym = "";\n    g_emit.op_zz_sym = c ? "rt_concat" : "rt_gcheap_alloc";\n}\n')
    o9 = []
    census_safe_points("", [t_fld, t_fle], out=o9.append, allocating=alloc, list_polled=True)
    ck(_sp_has(o9, allocating_call_sites=1, polled=1, unresolved=0) and any("emit field op_zz_sym" in x and "rt_concat" in x and "rt_gcheap_alloc" in x for x in o9),
       "safe-points EMIT FIELD TARGET: x86(\"call\", _.op_X, ...) resolves to what the emitter writes into g_emit.op_X, its empty reset dropped")
    t_fw = os.path.join(w, "fw.cpp")
    open(t_fw, "w").write('static std::string inner(const char * sym, void * fp) {\n    return x86("call", sym, fp) + x86_rt_gc_poll();\n}\n'
                          'static std::string outer(const char * osym, void * ofp) {\n    return inner(osym, ofp);\n}\n'
                          'std::string a(){ return outer("rt_concat", fp) + outer(_.op_zz_sym, fp); }\n')
    o10 = []
    census_safe_points("", [t_fw, t_fle], out=o10.append, allocating=alloc, list_polled=True)
    ck(_sp_has(o10, allocating_call_sites=1, polled=1, unresolved=0) and any("forwarded from" in x and "rt_concat" in x and "rt_gcheap_alloc" in x for x in o10),
       "safe-points FORWARDED PARAMETER: a helper that hands its own parameter on resolves through its callers, a literal and a g_emit field among them")
    # THE WINDOW'S BUDGET COUNTS ONLY THE SITE'S OWN PATH (the cto 2026-10-08, bb_match_defer.cpp:307): the call heads the first of three
    # ternary arms, the two others hold sixteen x86 tokens, and the one poll follows the ternary's close -- POLLED on every arm. The same
    # sixteen tokens written on the call's own path (the control) still spend the window before the poll -- UNPOLLED.
    mv8 = ['        + x86("mov", "rax", "rbx")'] * 7
    t_arm = os.path.join(w, "arm.cpp"); t_armc = os.path.join(w, "armc.cpp")
    open(t_arm, "w").write('std::string a(){\n    return x86("mov", "rax", "rbx")\n        + (c\n        ? x86("call", "rt_concat", fp)\n        : d\n'
                           '        ? x86("mov", "rax", "rbx")\n' + "\n".join(mv8) + '\n        : x86("mov", "rax", "rbx")\n' + "\n".join(mv8)
                           + ')\n        + x86_rt_gc_poll();\n}\n')
    open(t_armc, "w").write('std::string a(){\n    return x86("call", "rt_concat", fp)\n' + "\n".join(['        + x86("mov", "rax", "rbx")'] * 16)
                            + '\n        + x86_rt_gc_poll();\n}\n')
    o6 = []; o7 = []
    census_safe_points("", [t_arm], out=o6.append, allocating=alloc); census_safe_points("", [t_armc], out=o7.append, allocating=alloc)
    ck(_sp_has(o6, allocating_call_sites=1, polled=1, unpolled=0),
       "safe-points OWN-PATH BUDGET: a call heading one ternary arm, sixteen x86 tokens in the two other arms and one poll after the close reads POLLED")
    ck(_sp_has(o7, allocating_call_sites=1, polled=0, unpolled=1),
       "safe-points OWN-PATH BUDGET control: the same sixteen tokens on the call's own path spend the window before the poll -- UNPOLLED")
    buf.clear(); rc = census_safe_points("", [tpl_bad], out=buf.append, allocating=alloc, poll_helper="gc_poll_here")
    ck(rc == 1, "safe-points: naming a poll helper does not excuse a call that has neither")
    tpl_gk = os.path.join(w, "greek.cpp")
    open(tpl_gk, "w", encoding="utf-8").write('std::string a(){ return x86("call", "rt_epilogue_\u03b3", fp); }\n'
                                              'std::string b(){ return x86("call", flag ? "rt_epilogue_\u03c9" : "rt_pure_cmp", fp); }\n')
    buf.clear(); rc = census_safe_points("", [tpl_gk], out=buf.append, allocating={"rt_epilogue_\u03b3", "rt_epilogue_\u03c9"})
    ck(rc == 1 and _sp_has(buf, allocating_call_sites=2, polled=0, unpolled=2, unresolved=0)
       and any("UNPOLLED" in l and "rt_epilogue_\u03b3" in l for l in buf),
       "safe-points: a call target spelled with a Greek port letter is a LITERAL, counted and named -- never UNRESOLVED (32 of 39 were this, 2026-09-17)")
    ck(read_gcmap_labels("[GC-MAP] graph=PAT$0 frame_bytes=88 header_bytes=16 value_bytes=0 flags=2 map=.Lgcmap_.LTp0\n[GC-MAP] graph=main frame_bytes=64 header_bytes=0 value_bytes=16 flags=9\n") == {"PAT$0": ".Lgcmap_.LTp0"},
       "maps/table: a graph's map label is read from the report, so a thunk whose label is its assembler-local stem joins its own graph; a report with no map= field names no label")
    ck(blob_class_visible({"main", "fn", "PAT$0"}) and blob_class_visible({"main", ".LTp0"}) and not blob_class_visible({"main", "fn", "pattern_helper"}),
       "maps/table: the blob-frame class is VISIBLE only when a stored-pattern graph is in the witness set -- otherwise the census refuses rather than printing a zero by never looking (cto, ARCH-GC 6.2b)")
    tpl_rs = os.path.join(w, "resolved.cpp")
    open(tpl_rs, "w").write(
        'static const char *tbl[3] = { "rt_concat", "rt_pure_cmp", "rt_nope" };\n'
        '#define pick_sym() (flag ? "rt_concat" : "rt_pure_cmp")\n'
        'static const char *chose(void) { if (a) return "rt_concat"; return "rt_pure_cmp"; }\n'
        'void *dop_direct_fp(const char *fn, int64_t n, const char **sym) {\n'
        '  static const struct { const char *nm; const char *sy; } t[] = { { "$u", "rt_concat" }, { "$v", "rt_pure_cmp" }, { 0, 0 } };\n'
        '  return 0;\n'
        '}\n'
        'std::string a(){ return x86("call", tbl[k], fp); }\n'
        'std::string b(){ return x86("call", pick_sym(), fp); }\n'
        'std::string c(){ return x86("call", chose(), fp); }\n'
        'std::string d(){ const char *dsym = 0; void *f = dop_direct_fp(fn, 2, &dsym); return x86("call", dsym, f); }\n'
        'std::string e(){ return x86("call", (flag ? name_a : name_b), fp); }\n')
    buf.clear(); rc = census_safe_points("", [tpl_rs], out=buf.append, allocating=alloc)
    txt = "\n".join(buf)
    ck(rc == 1 and _sp_has(buf, allocating_call_sites=4, polled=0, unpolled=4, unresolved=1)
       and "via array tbl[]" in txt and "via macro pick_sym()" in txt and "via chooser chose()" in txt
       and "via resolver dop_direct_fp()" in txt,
       "safe-points: the four decidable computed-target shapes (array, macro, chooser, resolver out-parameter) each resolve and NAME their rule")
    ck(rc == 1 and any("UNRESOLVED" in l for l in buf),
       "safe-points: a computed target of no decidable shape stays UNRESOLVED beside the four that resolved -- the census does not guess")
    tpl_xd, tpl_xu = os.path.join(w, "extdef.cpp"), os.path.join(w, "extuse.cpp")
    open(tpl_xd, "w").write('const char * baked_sym(int k) { return k == 2 ? "rt_concat" : "rt_pure_cmp"; }\n')
    open(tpl_xu, "w").write('extern "C++" const char * baked_sym(int k);\n'
                            'std::string a(){ return x86("call", baked_sym(_bk), fp); }\n')
    buf.clear(); rc = census_safe_points("", [tpl_xd, tpl_xu], out=buf.append, allocating=alloc)
    txt = "\n".join(buf)
    ck(rc == 1 and _sp_has(buf, allocating_call_sites=1, unpolled=1, unresolved=0) and "via chooser baked_sym(...) [extern, defined once in the set]" in txt,
       "safe-points: a chooser DECLARED extern in the site's file and DEFINED ONCE in the template set resolves at that definition and names the rule")
    tpl_x2 = os.path.join(w, "extdef2.cpp")
    open(tpl_x2, "w").write('const char * baked_sym(int k) { return "rt_nope"; }\n')
    buf.clear(); rc = census_safe_points("", [tpl_xd, tpl_x2, tpl_xu], out=buf.append, allocating=alloc)
    ck(rc == 1 and _sp_has(buf, unresolved=1),
       "safe-points: an extern chooser DEFINED TWICE in the set stays UNRESOLVED -- two candidate sets are a guess, and the census does not guess")
    tpl_tr = os.path.join(w, "macrotrap.cpp")
    open(tpl_tr, "w").write(
        '#define pick_sym() (flag ? "rt_pure_cmp" : "rt_nope")\n'
        'static std::string far_away(void) { return x86("call", "rt_concat", fp); }\n'
        'std::string a(){ return x86("call", pick_sym(), fp); }\n')
    buf.clear(); rc = census_safe_points("", [tpl_tr], out=buf.append, allocating=alloc)
    txt = "\n".join(buf)
    ck(rc == 1 and "via macro pick_sym(): 2 candidate(s), none allocating" in txt and _sp_has(buf, allocating_call_sites=1),
       "safe-points: a macro chooser reads ITS OWN replacement text -- not the literals of the next routine in the file (the mis-resolution of 2026-09-17, which hid two allocating rt_cap_open_plain sites)")
    # ⛔⭐ THE STATEMENT-LEVEL ARMS AND THE CONDITIONAL-SKIP READER (the coo, 2026-09-22, row
    # instruments-the-safe-point-census-reader-...).  Four arms, because the two rules are only correct TOGETHER:
    # opening the window on exclusive arms is the CLEARING direction, and the guard reader is what stops that from
    # minting a false POLLED.  An edit that keeps one and drops the other trips these.
    tpl_arm = os.path.join(w, "arms.cpp")
    open(tpl_arm, "w").write("std::string t(int kind){ std::string s = x86(\"push\", \"rax\");\n    if (kind == 1) s += x86(\"call\", \"rt_concat\", fp);\n    else if (kind == 2) s += x86(\"call\", \"rt_concat\", fp);\n    else s += x86(\"call\", \"rt_concat\", fp);\n    s += x86(\"lea\", \"r8\", \"[rip + __]\", (uint64_t)&g_gc_pending, \"g_gc_pending\");\n    return s;\n}\n")
    buf.clear(); rc = census_safe_points("", [tpl_arm], out=buf.append, allocating=alloc)
    ck(rc == 0 and _sp_has(buf, allocating_call_sites=3, polled=3, partially_polled=0, unpolled=0),
       "safe-points: three allocating calls in ONE if/else-if/else chain share the unconditional poll below it -- an "
       "else-if arm is an ALTERNATIVE, not a later call, so none of the three stops the others' window (COO-146 named "
       "this and did not mechanize it; six real sites read UNPOLLED until it was)")
    tpl_skip = os.path.join(w, "skip.cpp")
    open(tpl_skip, "w").write("std::string g(int kind){ std::string sk = \"L1\";\n    std::string s = x86(\"cmp\", \"rax\", (long)0) + x86(\"je\", sk);\n    if (kind == 1) s += x86(\"call\", \"rt_concat\", fp);\n    else if (kind == 2) s += x86(\"call\", \"rt_concat\", fp);\n    s += x86(\"lea\", \"r8\", \"[rip + __]\", (uint64_t)&g_gc_pending, \"g_gc_pending\");\n    s += x86(\"def\", sk);\n    return s;\n}\n")
    buf.clear(); rc = census_safe_points("", [tpl_skip], out=buf.append, allocating=alloc)
    ck(rc == 0 and _sp_has(buf, allocating_call_sites=2, polled=2, partially_polled=0, unpolled=0)
       and not any(l.lstrip().startswith("PARTIAL") for l in buf),
       "safe-points: a guard ABOVE the calls whose landing pad stands below the poll skips the call AND the poll on "
       "the taken path -- the PAIR is a guarded allocation with its own poll, WHOLE and polled (CEO-1160 overturning "
       "CEO-1132's reading for exactly this shape: the six trace-tap sites, measured from the emitted bytes)")
    tpl_between = os.path.join(w, "between.cpp")
    open(tpl_between, "w").write("std::string g(int kind){ std::string sk = \"L1\";\n    std::string s;\n    if (kind == 1) s += x86(\"call\", \"rt_concat\", fp);\n    else if (kind == 2) s += x86(\"call\", \"rt_concat\", fp);\n    s += x86(\"cmp\", \"rax\", (long)0) + x86(\"je\", sk);\n    s += x86(\"lea\", \"r8\", \"[rip + __]\", (uint64_t)&g_gc_pending, \"g_gc_pending\");\n    s += x86(\"def\", sk);\n    return s;\n}\n")
    buf.clear(); rc = census_safe_points("", [tpl_between], out=buf.append, allocating=alloc)
    ck(rc == 1 and _sp_has(buf, allocating_call_sites=2, polled=0, partially_polled=2, unpolled=0)
       and any("PARTIAL" in l and "conditional skip" in l for l in buf),
       "safe-points FAIL-ONCE: a jump emitted BETWEEN the call and the poll whose landing pad stands below the poll "
       "skips the poll and NOT the call -- the partial shape the fourth-species rule exists for, PARTIAL and named")
    tpl_armskip = os.path.join(w, "armskip.cpp")
    open(tpl_armskip, "w").write("std::string g(int kind){ std::string sk = \"L1\";\n    std::string s = IF(kind == 2 || kind == 3, x86(\"cmp\", \"rax\", (long)0) + x86(\"je\", sk));\n    if (kind == 1) s += x86(\"call\", \"rt_concat\", fp);\n    else if (kind == 2) s += x86(\"call\", \"rt_concat\", fp);\n    s += x86(\"lea\", \"r8\", \"[rip + __]\", (uint64_t)&g_gc_pending, \"g_gc_pending\");\n    s += x86(\"def\", sk);\n    return s;\n}\n")
    buf.clear(); rc = census_safe_points("", [tpl_armskip], out=buf.append, allocating=alloc)
    ck(rc == 0 and _sp_has(buf, allocating_call_sites=2, polled=2, partially_polled=0, unpolled=0),
       "safe-points: a guard ABOVE the calls that is itself conditional (IF(kind == 2 || kind == 3, ... je)) guards "
       "the pair on the arms it is emitted on and nothing on the others -- every arm is WHOLE either way, so the "
       "disjointness of guard and arm decides nothing for a guard above the call (CEO-1160)")
    tpl_else = os.path.join(w, "elsearm.cpp")
    open(tpl_else, "w").write("std::string g(int kind){ std::string sk = \"L1\";\n    std::string s = IF(kind == 2, x86(\"cmp\", \"rax\", (long)0) + x86(\"je\", sk));\n    if (kind == 1) s += x86(\"call\", \"rt_concat\", fp);\n    else s += x86(\"call\", \"rt_concat\", fp);\n    s += x86(\"lea\", \"r8\", \"[rip + __]\", (uint64_t)&g_gc_pending, \"g_gc_pending\");\n    s += x86(\"def\", sk);\n    return s;\n}\n")
    buf.clear(); rc = census_safe_points("", [tpl_else], out=buf.append, allocating=alloc)
    ck(rc == 0 and _sp_has(buf, allocating_call_sites=2, polled=2, partially_polled=0, unpolled=0),
       "safe-points: a BARE else under a guard ABOVE the calls is whole like its siblings -- a pair guard needs no "
       "proof of disjointness because it skips the call with the poll (CEO-1160)")
    # ⛔ ITEM (iv): A FORM SWAP MUST CHANGE THE READING.  The count alone cannot tell two trees apart, which is how a
    # contaminated tree read 177 exactly as the clean one did; the histogram is the column that can.
    tpl_f1 = os.path.join(w, "form1.cpp"); tpl_f2 = os.path.join(w, "form2.cpp")
    open(tpl_f1, "w").write('std::string a(){ return x86("call", "rt_concat", fp)\n + x86_rt_gc_poll(); }\n')
    open(tpl_f2, "w").write('std::string a(){ return x86("call", "rt_concat", fp)\n + x86_rt_gc_poll_res(); }\n')
    buf.clear(); census_safe_points("", [tpl_f1], out=buf.append, allocating=alloc); t1 = "\n".join(buf)
    buf.clear(); census_safe_points("", [tpl_f2], out=buf.append, allocating=alloc); t2 = "\n".join(buf)
    ck("POLL FORMS" in t1 and "x86_rt_gc_poll=1" in t1 and "x86_rt_gc_poll_res=1" in t2
       and _sp_fields(t1.split("\n")).get("polled") == _sp_fields(t2.split("\n")).get("polled"),
       "safe-points: swapping the poll FORM leaves polled identical and CHANGES the form histogram -- the column that "
       "makes the cto's sed round-trip visible, which a polled/unpolled count could not see at all")
    # ⛔ ITEM (iii): THE BUILD-CURRENCY REFUSAL, exercised through main() against a FABRICATED root, so the arm is
    # hermetic and never touches this tree's own mtimes.  rc=2 is "could not measure", never red and never green.
    fake = tempfile.mkdtemp(prefix="gc_census_stale."); __import__("atexit").register(__import__("shutil").rmtree, fake, True)
    os.makedirs(os.path.join(fake, "scripts")); os.makedirs(os.path.join(fake, "src")); os.makedirs(os.path.join(fake, "out"))
    import shutil
    shutil.copy(os.path.join(ROOT, "..", "harness", "scripts", "lib_build_currency.sh"), os.path.join(fake, "scripts"))
    open(os.path.join(fake, "scrip"), "w").write("x"); open(os.path.join(fake, "out", "libscrip_rt.so"), "w").write("x")
    os.utime(os.path.join(fake, "scrip"), (1000, 1000)); os.utime(os.path.join(fake, "out", "libscrip_rt.so"), (1000, 1000))
    open(os.path.join(fake, "src", "newer.c"), "w").write("int x;\n")
    _pr = subprocess.run([sys.executable, os.path.join(ROOT, "..", "harness", "scripts", "util_gc_census.py"), "safe-points",
                          "--root", fake], capture_output=True, text=True)
    ck(_pr.returncode == 2 and "REFUSED-TO-GRADE" in (_pr.stdout + _pr.stderr),
       "safe-points: a binary OLDER than src/ REFUSES rc=2 and measures nothing -- this census derives its "
       "DENOMINATOR from the built runtime, so a stale artifact changes WHICH CALLS ARE COUNTED, and a DONE-WHEN "
       "read GREEN on an uncompiled tree before this refusal existed")
    tpl_xf = os.path.join(w, "crossfn.cpp")
    open(tpl_xf, "w").write('std::string a(){ return x86("call", "rt_concat", fp);\n'
                            '}\n'
                            'std::string b(){ return x86("lea", "r8", "[rip + __]", (uint64_t)&g_gc_pending, "g_gc_pending"); }\n')
    buf.clear(); rc = census_safe_points("", [tpl_xf], out=buf.append, allocating=alloc)
    ck(rc == 1 and _sp_has(buf, allocating_call_sites=1, polled=0, unpolled=1),
       "safe-points: a g_gc_pending poll in the NEXT routine, inside the line window, does NOT make this site polled (the false green of 2026-09-17)")
    # ⛔ THE BASE WINDOW'S INTERVENING-CALL STOP (CEO-1119) AND ITS TWO ARM EXEMPTIONS, PLANTED IN BOTH DIRECTIONS.
    # The stop is the direction that NOMINATES a site, the exemptions are the direction that CLEARS one, so both are
    # planted: a fixture that MUST stop and a fixture that MUST NOT.
    tpl_iv = os.path.join(w, "intervening.cpp")
    open(tpl_iv, "w").write('std::string a(){ return x86("call", "rt_concat", fp)\n'
                            '  + x86("call", "rt_other", fp)\n'
                            '  + x86("lea", "r8", "[rip + __]", (uint64_t)&g_gc_pending, "g_gc_pending");\n'
                            '}\n')
    buf.clear(); rc = census_safe_points("", [tpl_iv], out=buf.append, allocating=alloc)
    ck(rc == 1 and _sp_has(buf, allocating_call_sites=1, polled=0, unpolled=1),
       "safe-points: a poll that sits after a LATER emitted call is THAT call's safe point -- the site above it reads UNPOLLED (the base-window stop, CEO-1119)")
    # ⛔ THE SIBLING ARM SPELLED OVER SEVERAL LINES -- the blind spot COO-143 named by hand rather than rounding away,
    # and the only gap between the mechanical arm's 148 and the 149 the ceo published.  The site is the last line of
    # the THEN arm; the ELSE arm opens with ':' and RUNS ON, carrying the intervening call on its last line.  A stop
    # keyed on the leading character exempts the ':' line and then trips on the one after it.
    tpl_sa = os.path.join(w, "siblingarm.cpp")
    open(tpl_sa, "w").write('std::string a(){ return x86("mov", "rdi", fp)\n'
                            '  + (cond()\n'
                            '  ? x86("mov", "rsi", fp)\n'
                            '  + x86("call", "rt_concat", fp)\n'
                            '  : x86("lea", "rsi", fp)\n'
                            '  + x86("mov32", "ecx", (long)n)\n'
                            '  + (other() ? x86("call", "rt_other", fp) : x86("call", "rt_third", fp)))\n'
                            '  + x86("lea", "r8", "[rip + __]", (uint64_t)&g_gc_pending, "g_gc_pending");\n'
                            '}\n')
    buf.clear(); rc = census_safe_points("", [tpl_sa], out=buf.append, allocating=alloc)
    ck(rc == 0 and _sp_has(buf, allocating_call_sites=1, polled=1, unpolled=0),
       "safe-points: a MULTI-LINE sibling ternary arm is an ALTERNATIVE, not a successor -- its call does not stop the window (bb_call_value.cpp:130, the hand rejection COO-143 mechanized)")
    # ⛔ AND THE EXEMPTION IS PAIRED, NOT A BARE ':' RULE: with no '?' opening the site's own arm, a later ternary's
    # else arm IS a successor (exactly one arm runs after us) and must still stop the window.  Without this arm the
    # sibling rule would clear sites standing in plain sequence -- the direction that needs the most evidence.
    tpl_sq = os.path.join(w, "seqternary.cpp")
    open(tpl_sq, "w").write('std::string a(){ return x86("call", "rt_concat", fp)\n'
                            '  + (cond()\n'
                            '  ? x86("mov", "rsi", fp)\n'
                            '  : x86("call", "rt_other", fp))\n'
                            '  + x86("lea", "r8", "[rip + __]", (uint64_t)&g_gc_pending, "g_gc_pending");\n'
                            '}\n')
    buf.clear(); rc = census_safe_points("", [tpl_sq], out=buf.append, allocating=alloc)
    ck(rc == 1 and _sp_has(buf, allocating_call_sites=1, polled=0, unpolled=1),
       "safe-points: a ':' arm the site does NOT share a '?' with is a successor, not a sibling -- it still stops the window (the unpaired direction)")
    # ⛔ AND THE ARM THE SITE LIVES IN IS NOT AN ARM IT IS EXCLUDED FROM -- the second wrong shape of this rule,
    # which CLEARED THREE SITES A HAND READ CONVICTED (bb_match_capture.cpp:124/:163, bb_rev_assign_var.cpp:19).
    # bb_rev_assign_var.cpp:14 is a guard ternary whose ':' on :15 OPENS the arm the site at :19 stands in, so every
    # line below it is that same arm -- a SUCCESSOR -- and the real intervening call at :26 must still stop.
    tpl_ea = os.path.join(w, "elsearm.cpp")
    open(tpl_ea, "w").write('std::string a(){ return guard()\n'
                            '  ? x86("mov", "rdi", fp)\n'
                            '  : x86("mov", "rsi", fp)\n'
                            '  + x86("call", "rt_concat", fp)\n'
                            '  + x86("call", "rt_other", fp)\n'
                            '  + x86("lea", "r8", "[rip + __]", (uint64_t)&g_gc_pending, "g_gc_pending");\n'
                            '}\n')
    buf.clear(); rc = census_safe_points("", [tpl_ea], out=buf.append, allocating=alloc)
    ck(rc == 1 and _sp_has(buf, allocating_call_sites=1, polled=0, unpolled=1),
       "safe-points: a site standing IN a ':' arm still stops at an intervening call in that same arm -- an arm the site lives in is not one it is excluded from (bb_rev_assign_var.cpp:19)")
    # ⛔⭐ THE COMMON-TAIL NOMINATION, PLANTED IN BOTH DIRECTIONS (cfo, CFO-151).  The named direction is a
    # NESTED braced chain -- the real bb_call_fn.cpp:207 shape, where the intervening call sits in a sibling of the
    # chain ONE OUT from the site's own -- and it must be nominated; the unnamed direction is a plain successor
    # standing at the tail's own depth, which must not be, or this reader would clear sites in sequence.
    tpl_ct = os.path.join(w, "commontail.cpp")
    open(tpl_ct, "w").write('std::string a(){ std::string s = x86("mov", "rdi", fp);\n'
                            '  if (cui()) {\n'
                            '    if (csval()) {\n'
                            '      s += x86("call", "rt_concat", fp);\n'
                            '    } else {\n'
                            '      s += x86("call", "rt_other", fp);\n'
                            '    }\n'
                            '  } else if (dfp()) {\n'
                            '    s += x86("call", "rt_third", fp);\n'
                            '  } else {\n'
                            '    s += x86("call", "rt_fourth", fp);\n'
                            '  }\n'
                            '  s += x86("lea", "r8", "[rip + __]", (uint64_t)&g_gc_pending, "g_gc_pending");\n'
                            '  return s;\n'
                            '}\n')
    buf.clear(); rc = census_safe_points("", [tpl_ct], out=buf.append, allocating=alloc)
    _ct = "\n".join(buf)
    ck(rc == 1 and "COMMON-TAIL POLL:" in _ct and "commontail.cpp:4" in _ct,
       "safe-points: a site in a NESTED braced if/else chain whose ONE poll sits below the whole chain is NOMINATED as a common tail -- the shape bb_call_fn.cpp:207 reads UNPOLLED at every window from 12 to 120 while its emitted asm polls six instructions after the call (cfo, CFO-151)")
    tpl_cs = os.path.join(w, "commontailseq.cpp")
    open(tpl_cs, "w").write('std::string a(){ std::string s = x86("mov", "rdi", fp);\n'
                            '  if (cui()) {\n'
                            '    s += x86("call", "rt_concat", fp);\n'
                            '  }\n'
                            '  s += x86("call", "rt_other", fp);\n'
                            '  s += x86("lea", "r8", "[rip + __]", (uint64_t)&g_gc_pending, "g_gc_pending");\n'
                            '  return s;\n'
                            '}\n')
    buf.clear(); rc = census_safe_points("", [tpl_cs], out=buf.append, allocating=alloc)
    _cs = "\n".join(buf)
    ck(rc == 1 and "COMMON-TAIL POLL:" not in _cs,
       "safe-points: a poll whose only intervening call stands at the TAIL'S OWN DEPTH is that call's safe point, not a common tail -- the nomination declines it (the direction that would clear sites in plain sequence)")
    # ⛔ A CHAR LITERAL IS NOT A PAREN.  bb_scan_bal.cpp:61/:66 and :108/:113 hold (long)'(' and (long)')', and a
    # naive depth count reads them as opening and closing the very group the sibling rule is tracking.
    ck(_paren_delta("+ x86(\"cmp64\", \"rsi\", (long)'(')")[0] == 0
       and _paren_delta("+ x86(\"cmp64\", \"rsi\", (long)')')")[0] == 0
       and _paren_delta('+ (cond()')[0] == 1,
       "safe-points: the arm reader counts parens LITERAL-FREE -- (long)'(' and (long)')' are balanced, not a group")
    # coverage on captured text
    buf.clear(); rc = census_coverage("", "", out=buf.append, cov_text="[GC-COV] ranges=3 words_scanned=0 interior_words=0 pz=1\n[GC-COV] ranges=3 words_scanned=0 interior_words=0 pz=1\n")
    ck(rc == 0, "coverage: every [GC-COV] line carrying words_scanned=0 AND interior_words=0 reads GREEN")
    buf.clear(); rc = census_coverage("", "", out=buf.append, cov_text="[GC-COV] ranges=3 cas_scanned_bytes=0 pz=1 cons_stack=1\n")
    ck(rc == 1 and "without_words_scanned=1" in "\n".join(buf) and "without_interior_words=1" in "\n".join(buf),
       "coverage: today's line (neither field) reads RED on both tokens, never green")
    buf.clear(); rc = census_coverage("", "", out=buf.append, cov_text="[GC-COV] words_scanned=0 interior_words=0\n[GC-COV] words_scanned=7 interior_words=0\n")
    ck(rc == 1 and "words_scanned_nonzero=1" in "\n".join(buf), "coverage: one line with words_scanned=7 among zeros reads RED")
    buf.clear(); rc = census_coverage("", "", out=buf.append, cov_text="[GC-COV] words_scanned=0 interior_words=0\n[GC-COV] words_scanned=0 interior_words=12\n")
    ck(rc == 1 and "interior_words_nonzero=1" in "\n".join(buf), "coverage: a mapped stack with 12 unmapped WORKLIST-INTERIOR words still reads RED (Rule 2b)")
    buf.clear(); rc = census_coverage("", "", out=buf.append, cov_text="[GC-COV] words_scanned=0 pz=1\n")
    ck(rc == 1 and "without_interior_words=1" in "\n".join(buf) and "without_words_scanned=0" in "\n".join(buf),
       "coverage: half the design (words_scanned only, no interior_words) reads RED on the missing token alone")
    buf.clear(); rc = census_coverage("", "", out=buf.append, cov_text="nothing collected\n")
    ck(rc == 2, "coverage: no [GC-COV] line at all REFUSES rc=2 (no collection ran, nothing measured)")
    # callbacks
    cb_ok, cb_bad = os.path.join(w, "cb_ok.c"), os.path.join(w, "cb_bad.c")
    open(cb_ok, "w").write("DESCR_t rt_call_proc_descr(DESCR_t p, int n) {\n  return x;\n}\nstatic void f(void) { DESCR_t r = RT_GC_CALLBACK(rt_call_proc_descr(p, 2)); use(r); }\n")
    open(cb_bad, "w").write("static void f(void) { char *s = raw; DESCR_t r = rt_call_proc_descr(p, 2); use(s); DESCR_t q = RT_GC_CALLBACK(rt_call_value(v)); }\n")
    # every fixture below names the four declared OUTBOUND symbols in a comment-free trailer, so the census's
    # stale-enumeration refusal does not fire on a fixture that simply has no outbound site of its own
    OUTB = "\nstatic void _decl_only(void) { if (0) { APPLY_fn(0,0,0); _usercall_hook(0); _usercall_hook(0); APPLY_fn(0); } }\n"
    open(cb_ok, "a").write(OUTB)
    buf.clear(); rc = census_callbacks([cb_ok], out=buf.append)
    ck(rc == 1 and "INBOUND call_back_sites=1 wrapped_in_RT_GC_CALLBACK=1 unwrapped=0" in "\n".join(buf),
       "callbacks: a definition is not a site; the wrapped INBOUND call reads unwrapped=0 (the fixture's own outbound sites keep it RED)")
    buf.clear(); rc = census_callbacks([cb_bad], out=buf.append)
    ck(rc == 2 and "appear nowhere in the censused scope" in "\n".join(buf),
       "callbacks: a scope in which a DECLARED outbound symbol does not appear REFUSES rc=2 -- a stale enumeration never reports zero")
    open(cb_bad, "a").write(OUTB)
    buf.clear(); rc = census_callbacks([cb_bad], out=buf.append)
    ck(rc == 1 and "INBOUND call_back_sites=2 wrapped_in_RT_GC_CALLBACK=1 unwrapped=1" in "\n".join(buf),
       "callbacks: a planted unwrapped INBOUND call-back is counted and RED beside the wrapped one")
    # (ii) the terminator was never the test -- a prototype ends ';' and a one-line definition ends '}'
    cb_decl = os.path.join(w, "cb_decl.c")
    open(cb_decl, "w").write(
        "DESCR_t rt_call_arr(const char *fn, DESCR_t *a, int n);\n"
        "static DESCR_t rt_call_arr_bl_s(const char *fn, DESCR_t *a, int n, int b);\n"
        "DESCR_t rt_call_arr_bl_sn4(const char *fn, DESCR_t *a, int n, int b) { return rt_call_arr_bl_s(fn, a, n, b); }\n"
        "static DESCR_t\nrt_call_value_gen_h(DESCR_t v)\n{\n  return v;\n}\n" + OUTB)
    buf.clear(); rc = census_callbacks([cb_decl], out=buf.append)
    ck("INBOUND call_back_sites=1 " in "\n".join(buf),
       "callbacks: two prototypes ending ';', a one-line definition ending '}' and a definition whose return type is on its own line contribute exactly ONE site -- the one real inner call")
    # (ii-b) A BLOCK-LOCAL EXTERN SHARING ITS LINE WITH A STATEMENT IS STILL A DECLARATION (cfo 2026-09-19, the
    # ceo's CEO-942 false positive): the declarator prefix is matched from the STATEMENT boundary, not the margin,
    # and a call that starts its own statement after that boundary must still count -- both directions planted.
    cb_stmt = os.path.join(w, "cb_stmt.c")
    open(cb_stmt, "w").write(
        "static void g(void) { if (!hook) { extern DESCR_t _usercall_hook(const char *n, DESCR_t *a, int c); hook = _usercall_hook; } }\n"
        "static void h(void) { int n = 1; extern DESCR_t rt_call_proc_descr(const char *name, int nargs); DESCR_t r = rt_call_proc_descr(\"F\", n); use(r); }\n"
        "static void k(void) { APPLY_fn(0,0,0); }\n"
        "static void m(void) { _usercall_hook(0); APPLY_fn(0); }\n")
    buf.clear(); rc = census_callbacks([cb_stmt], out=buf.append)
    _t = "\n".join(buf)
    ck("INBOUND call_back_sites=1 " in _t and "unwrapped=1" in _t,
       "callbacks: a block-local extern sharing its line with a statement is NOT a site, while the real call after the ';' on that same line IS -- exactly one inbound site over the two lines")
    ck("OUTBOUND call_out_sites=3 " in _t,
       "callbacks: the address-of assignment of an outbound hook beside its own extern declaration is not a way out of the runtime, while the three real outbound calls are counted")
    # (iii) the OUTBOUND direction: CEO-836's gdb site shape
    cb_out = os.path.join(w, "cb_out.c")
    open(cb_out, "w").write(
        "static DESCR_t f(const char *fn, DESCR_t *args, int nargs) {\n"
        "  DESCR_t out = APPLY_fn(fn, args, nargs);\n"
        "  DESCR_t q = RT_GC_CALLBACK(_usercall_hook(fn));\n"
        "  _usercall_hook(fn);\n  APPLY_fn(fn);\n  return out;\n}\n")
    buf.clear(); rc = census_callbacks([cb_out], out=buf.append)
    j = "\n".join(buf)
    ck(rc == 1 and "OUTBOUND call_out_sites=4 wrapped_in_RT_GC_CALLBACK=1 unwrapped=3" in j and "cb_out.c:2:APPLY_fn" in j,
       "callbacks: the OUTBOUND direction counts CEO-836's `out = APPLY_fn(fn, args, nargs);` site, wrapped and unwrapped apart -- and no INBOUND count contains it")
    ck("INBOUND call_back_sites=0" in j,
       "callbacks: that same fixture reads INBOUND 0 -- proof the two directions are two populations and the old single count could not see the crash")
    cb_v = os.path.join(w, "cb_v.c")
    open(cb_v, "w").write(
        "static DESCR_t f(const char *fn, DESCR_t *args, int nargs) {\n"
        "  DESCR_t out = APPLY_fn(fn, args, nargs);\n"
        "  RT_GC_CALLBACK_V(_usercall_hook(fn));\n"
        "  _usercall_hook(fn);\n  APPLY_fn(fn);\n  return out;\n}\n")
    buf.clear(); rc = census_callbacks([cb_v], out=buf.append)
    jv = "\n".join(buf)
    ck(rc == 1 and "OUTBOUND call_out_sites=4 wrapped_in_RT_GC_CALLBACK=1 unwrapped=3" in jv,
       "callbacks: the VOID variant RT_GC_CALLBACK_V counts as a wrap and the three bare calls beside it still count as unwrapped -- a void callee cannot take the value form (RT_GC_CALLBACK(_usercall_hook(fn)) is `_cb_r declared void`, proven by compiling it), so a detector blind to _V leaves that site permanently uncountable (ceo CEO-1104)")
    # (iv) the marker's absence is PRINTED, never read as progress pending
    nodef = os.path.join(w, "nodef"); os.makedirs(os.path.join(nodef, "src"), exist_ok=True)
    buf2 = []; census_callbacks([cb_out], out=buf2.append, root=nodef); jnd = "\n".join(buf2)
    ck("defined_in_tree=NO" in jnd and "would not compile" in jnd,
       "callbacks: a marker with no #define anywhere in src/ is PRINTED as undefined beside wrapped=0 -- proven against a ROOT that has no definition, because RT_GC_CALLBACK now EXISTS in the real tree and this arm asserted its ABSENCE, so it went red the day the wrapper was written (ceo CEO-1104: a self-test must not be keyed on the state the work removes)")
    ck("defined_in_tree=src/runtime/rt/gc_heap.h" in j,
       "callbacks: and against the REAL root the same line NAMES the definition site, so a no-op macro cannot pass as a cure unnoticed -- both directions proven, not one")
    ck("defined_in_tree=" in "\n".join(buf) and "scripts" not in "",
       "callbacks: the marker's definition site is reported on every run, so a no-op macro cannot pass as a cure unnoticed")
    nogc = os.path.join(w, "nomaps"); os.makedirs(os.path.join(nogc, "src", "runtime", "rt"), exist_ok=True)
    open(os.path.join(nogc, "src", "runtime", "rt", "gc_heap.c"), "w").write("void *c_rt_gcheap_alloc(uint16_t t, uint64_t n) { return carve(n); }\n")
    buf.clear(); rc = census_maps_table(nogc, "/nonexistent/scrip", [], buf.append)
    ck(rc == 2 and "are not defined in gc_heap.c" in "\n".join(buf),
       "maps/table: a gc_heap.c without section 6.4's symbol REFUSES rc=2 -- an unbuilt table never reads green")
    buf.clear(); rc = census_maps_slotkind(nogc, ["rebus"], buf.append)
    ck(rc == 2 and "no util_zls_frame_map_census.py" in "\n".join(buf), "maps/slot-kind: a missing base tool REFUSES rc=2, never green")
    ck(decode_map_quads(".Lgcmap_x:\n  .quad 688541224282\n  .quad 4294967296\n  .quad .Lgcmap_x_s\n  .quad 0\n", ".Lgcmap_x")
       == {"magic": 0x50414D5A, "frame_bytes": 160, "header_bytes": 0, "flags": 1},
       "maps/table: the four static quads decode to magic ZMAP, frame_bytes, header_bytes and flags (section 6.3)")
    ck(decode_map_quads(".Lgcmap_y:\n  .quad 1\n  .quad 2\n", ".Lgcmap_y") is None,
       "maps/table: a map with fewer than four quads does not decode, and an undecodable map is a divergence not a pass")
    # the ratchet itself, against a synthetic COUNTS -- no census runs, so the proof costs nothing
    saved = dict(COUNTS)
    try:
        COUNTS.clear()
        for census, key, _pop in RATCHET_KEYS:
            COUNTS.setdefault(census, {})[key] = 7
        bl = os.path.join(w, "base.tsv")
        def write_base(bump=0, drop=None):
            with open(bl, "w") as fh:
                for census, key, _pop in RATCHET_KEYS:
                    if (census, key) == drop:
                        continue
                    fh.write(f"{census}\t{key}\t{7 + (bump if (census, key) == BUMP_KEY else 0)}\t0\n")
        BUMP_KEY = RATCHET_KEYS[0][:2]
        write_base(); buf.clear(); rc = ratchet(bl, buf.append)
        ck(rc == 0 and any(l.startswith("RATCHET GREEN") for l in buf), "ratchet: every count exactly its baseline reads GREEN")
        write_base(bump=-1); buf.clear(); rc = ratchet(bl, buf.append)
        ck(rc == 1 and any("⛔ WORSE" in l for l in buf), "ratchet: a planted INCREASE over the baseline is named and RED")
        write_base(bump=+5); buf.clear(); rc = ratchet(bl, buf.append)
        ck(rc == 1 and any("⭐ BETTER" in l for l in buf), "ratchet: a FALL the baseline has not recorded is RED too -- a loose ratchet lets the regression back in")
        write_base(drop=BUMP_KEY); buf.clear(); rc = ratchet(bl, buf.append)
        ck(rc == 2 and any("NOT-MEASURED" in l for l in buf), "ratchet: a key the baseline does not name REFUSES rc=2, never green")
        buf.clear(); rc = ratchet(os.path.join(w, "no-such-baseline.tsv"), buf.append)
        ck(rc == 2, "ratchet: a missing baseline REFUSES rc=2, never green")
    finally:
        COUNTS.clear(); COUNTS.update(saved)
    print(f"population: {arms} selftest arm(s), {fails} FAIL")
    if arms < ARMS_FLOOR:
        print(f"SELFTEST REFUSED(2): {arms} arm(s) ran, below the recorded floor {ARMS_FLOOR} -- an arm was removed or "
              "skipped, and less proof is not a pass")
        return 2
    print("SELFTEST " + ("PASS" if fails == 0 else "FAIL"))
    return 0 if fails == 0 else 1


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("census", nargs="?", default="all", choices=["all", "conservative", "allocator", "safe-points", "coverage", "callbacks", "maps"])
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--ratchet", default="", help="a baseline TSV (census<TAB>key<TAB>count<TAB>note); refuse an increase, and a fall the baseline has not recorded")
    ap.add_argument("--write-baseline", default="", help="write today's counts as a baseline TSV (the landing that earned the fall runs this)")
    ap.add_argument("--root", default=ROOT)
    ap.add_argument("--poll-window", type=int, default=12,
                    help="lines, read ONLY under SCRIP_GC_CENSUS_WINDOW_UNIT=lines; the default window is SCRIP_GC_CENSUS_WINDOW_X86 x86 calls (14)")
    ap.add_argument("--poll-helper", default="")
    ap.add_argument("--list-polled", action="store_true", help="print one `  POLLED <site> form=<form> poll_at=<template:line>` line per credited site, the join key the bare-poll re-screen (util_gc_safe_point_contract.py --bare-poll) reads")
    ap.add_argument("--zls-langs", default="fast", help="fast (rebus,snocone,pascal ~2.7s), all (the seven, ~32s), or a comma list")
    ap.add_argument("--map-witness", default="", help="comma list of programs the table half reads (default: the two fixtures)")
    ap.add_argument("--callback-marker", default="RT_GC_CALLBACK")
    ap.add_argument("--witness", default="", help="the program the coverage census runs (default: a small allocating SNOBOL4 loop)")
    a = ap.parse_args(argv)
    if a.selftest:
        return selftest()
    R = a.root
    gc = os.path.join(R, "src", "runtime", "rt", "gc_heap.c")
    so = os.path.join(R, "out", "libscrip_rt.so")
    scrip = os.path.join(R, "scrip")
    emitter_files = []
    for d in ("src/templates/bb", "src/templates/xa", "src/templates/x86", "src/emitter"):
        dd = os.path.join(R, d)
        if os.path.isdir(dd):
            emitter_files += [os.path.join(dd, f) for f in sorted(os.listdir(dd)) if f.endswith((".cpp", ".c", ".h"))]
    # ⛔⭐ BUILD CURRENCY FIRST, AND THIS CENSUS WENT NINE DAYS WITHOUT IT.  A DONE-WHEN READ GREEN ON AN UNCOMPILED
    # TREE (the coo, 2026-09-22; ceo CEO-1147 calls it the sharpest of this row's four items).  It is not a courtesy
    # check here: census_safe_points derives its DENOMINATOR from the built runtime -- allocating_entries_from_binary
    # reads out/libscrip_rt.so for the allocating symbol set -- so a stale .so does not merely date the verdict, it
    # silently changes WHICH CALLS ARE COUNTED and hands back a confident number for a program nobody is shipping.
    # The coverage and maps censuses RUN ./scrip outright.  ⛔ SOURCED, NEVER REIMPLEMENTED (CLAUDE.md: lib_* are
    # sourced authorities); a second copy of this rule is how one of them keeps the old rule after the rule changes.
    # ⛔ AND THERE IS DELIBERATELY NO ESCAPE HATCH.  Every other knob in this file has one for an auditor comparing
    # across a criterion change; a bypass HERE would re-admit the exact false green the refusal exists to stop.
    # THE QUESTION IS ASKED OF THE TREE THAT OWNS THE RUNTIME ARTIFACT (cto 2026-09-24, the seventeen-red row): when
    # --root's out/libscrip_rt.so is a SYMLINK into ROOT -- the emitted-paths gate censuses a scratch root that links
    # ROOT's .so and COPIES the templates it doctors, so that root has no ../harness/scripts/ and its copies are newer than any
    # binary by construction, and asked there the check refused every run (rc=2, "census printed no headline") while
    # grading nothing -- the artifacts are ROOT's and ROOT's src is what built them; a scratch whose .so is its own
    # file (this file's selftest plants one with 1970 mtimes beside a newer src/) is asked about itself and refuses.
    _so = os.path.join(R, "out", "libscrip_rt.so")
    _owner = ROOT if (os.path.islink(_so) and os.path.realpath(_so).startswith(os.path.realpath(ROOT) + os.sep)) else R
    bc = subprocess.run(["bash", "-c",
                         'set -e; . "$1/scripts/lib_build_currency.sh"; '
                         'assert_binary_current "$1/scrip" "$1"; assert_so_current "$1/out/libscrip_rt.so" "$1"',
                         "_", _owner], capture_output=True, text=True)
    if bc.returncode != 0:
        sys.stdout.write(bc.stdout)
        sys.stderr.write(bc.stderr)
        print("population: 0 census(es) run -- rc=2 (REFUSED TO MEASURE: the artifacts predate src/; "
              "a census of an unbuilt tree is a statement about a different program, not a stale one)")
        return 2
    for _l in bc.stdout.splitlines():
        if _l.strip():
            print(_l)
    rcs = []
    want = [a.census] if a.census != "all" else ["conservative", "allocator", "safe-points", "coverage", "callbacks", "maps"]
    for c in want:
        if c == "conservative":
            rcs.append(census_conservative(gc))
        elif c == "allocator":
            rcs.append(census_allocator(gc))
        elif c == "safe-points":
            rcs.append(census_safe_points(so, emitter_files, a.poll_window, a.poll_helper, list_polled=a.list_polled))
        elif c == "coverage":
            prog = a.witness
            if not prog:
                _covd = tempfile.mkdtemp(prefix="gc_cov."); __import__("atexit").register(__import__("shutil").rmtree, _covd, True); prog = os.path.join(_covd, "w.sno")
                open(prog, "w").write("        T = TABLE()\n        I = 0\nLOOP    I = I + 1\n        T[I] = DUPL('x', I) 'y' I\n        S = S T[I]\n        LT(I, 300)   :S(LOOP)\n        OUTPUT = SIZE(S)\nEND\n")
            rcs.append(census_coverage(scrip, prog))
        elif c == "callbacks":
            rcs.append(census_callbacks(callback_scope_files(R), a.callback_marker, root=R))
        elif c == "maps":
            langs = ZLS_LANGS_ALL if a.zls_langs == "all" else (ZLS_LANGS_FAST if a.zls_langs == "fast" else [x.strip() for x in a.zls_langs.split(",") if x.strip()])
            wits = [x.strip() for x in a.map_witness.split(",") if x.strip()] or \
                   [os.path.join(R, "scripts", "fixtures", "gc_roots_witness.sno"), os.path.join(R, "scripts", "fixtures", "gc_map_witness.icn")]
            rcs.append(census_maps(R, scrip, langs, wits))
    rc = worst(rcs)
    print(f"population: {len(want)} census(es): {rcs.count(0)} green, {rcs.count(1)} red, {rcs.count(2)} not measured -- rc={rc}")
    if a.write_baseline:
        # ⛔ THIS WRITER USED TO DESTROY THE RECORD IT EXISTS TO KEEP, AND THE PROCEDURE THAT DESTROYS IT IS THE ONE
        # THE GATE PRINTS.  Measured by the coo 2026-09-22 before running it: the file carries FOURTEEN comment lines
        # that CRITERION_CHANGES does not -- every "CRITERION UNCHANGED, COUNT EARNED" note the ceo, cto and cfo wrote
        # by hand across 2026-09-18/19 recording WHOSE landing earned each fall, plus three CRITERION CHANGED entries
        # added to the file and never to the list.  A truncating rewrite drops all fourteen, so any seat following
        # arm (c)'s own instruction ("lower the baseline in the landing that earned it") silently deletes other
        # seats' provenance.  The counts are regenerated; every prior comment line is CARRIED FORWARD.
        header = ["# gc_census_baseline.tsv -- the counts THE COLLECTOR GUESSES NOTHING drives to 0 (coo, CEO-818/819 section 7).",
                  "# Written by `util_gc_census.py all --write-baseline`; every landing that lowers a count rewrites this file",
                  "# in the same sitting -- test_gate_gc_instrument_censuses_are_wired_and_trip.sh reds on an increase AND on an",
                  "# unrecorded fall.  census\tkey\tcount\twant"]
        prior = []
        try:
            with open(a.write_baseline, encoding="utf-8") as fh:
                prior = [l.rstrip("\n") for l in fh if l.startswith("#")]
        except OSError:
            pass
        with open(a.write_baseline, "w", encoding="utf-8") as fh:
            emitted = set(header)
            for h in header:
                fh.write(h + "\n")
            for line in CRITERION_CHANGES:
                l = f"# CRITERION CHANGED {line}"
                fh.write(l + "\n"); emitted.add(l)
            carried = 0
            for l in prior:
                if l not in emitted:
                    fh.write(l + "\n"); emitted.add(l); carried += 1
            for census, key, _pop in RATCHET_KEYS:
                v = COUNTS.get(census, {}).get(key)
                if v is not None:
                    fh.write(f"{census}\t{key}\t{v}\t0\n")
        print(f"baseline written: {a.write_baseline} ({carried} prior comment line(s) carried forward, none dropped)")
    if a.ratchet:
        rrc = ratchet(a.ratchet)
        rc = 2 if 2 in (rc, rrc) else (1 if rrc else rc)
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
